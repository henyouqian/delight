package main

import (
	"encoding/json"
	"fmt"
	"github.com/garyburd/redigo/redis"
	//"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	"net/http"
	"time"
)

const (
	passwordSalt        = "liwei"
	sessionLifeSecond   = 60 * 60 * 24 * 7
	sessionUpdateSecond = 60 * 60
)

type Session struct {
	Userid   uint64
	Username string
	Born     time.Time
	Appid    uint32
}

func newSession(w http.ResponseWriter, userid uint64, username string, appid uint32, rc redis.Conn) (usertoken string, err error) {
	if rc == nil {
		rc = redisPool.Get()
		defer rc.Close()
	}
	usertoken = ""
	usertokenRaw, err := rc.Do("get", fmt.Sprintf("usertokens/%d+%d", userid, appid))
	lwutil.CheckError(err, "")
	if usertokenRaw != nil {
		if usertoken, err := redis.String(usertokenRaw, err); err != nil {
			return usertoken, lwutil.NewErr(err)
		}
		rc.Do("del", fmt.Sprintf("sessions/%s", usertoken))
	}

	usertoken = lwutil.GenUUID()

	session := Session{userid, username, time.Now(), appid}
	jsonSession, err := json.Marshal(session)
	if err != nil {
		return usertoken, lwutil.NewErr(err)
	}

	rc.Send("setex", fmt.Sprintf("sessions/%s", usertoken), sessionLifeSecond, jsonSession)
	rc.Send("setex", fmt.Sprintf("usertokens/%d+%d", userid, appid), sessionLifeSecond, usertoken)
	rc.Flush()
	for i := 0; i < 2; i++ {
		if _, err = rc.Receive(); err != nil {
			return usertoken, lwutil.NewErr(err)
		}
	}

	// cookie
	http.SetCookie(w, &http.Cookie{Name: "usertoken", Value: usertoken, MaxAge: sessionLifeSecond, Path: "/"})

	return usertoken, err
}

func checkAdmin(session *Session) {
	if session.Username != "admin" {
		lwutil.SendError("err_denied", "")
	}
}

func findSession(w http.ResponseWriter, r *http.Request, rc redis.Conn) (*Session, error) {
	session := new(Session)

	usertokenCookie, err := r.Cookie("usertoken")
	if err != nil {
		return session, lwutil.NewErr(err)
	}
	usertoken := usertokenCookie.Value

	//redis
	if rc == nil {
		rc = redisPool.Get()
		defer rc.Close()
	}

	sessionBytes, err := redis.Bytes(rc.Do("get", fmt.Sprintf("sessions/%s", usertoken)))
	if err != nil {
		return session, lwutil.NewErr(err)
	}

	err = json.Unmarshal(sessionBytes, session)
	lwutil.CheckError(err, "")

	//update session
	dt := time.Now().Sub(session.Born)
	if dt > sessionUpdateSecond*time.Second {
		newSession(w, session.Userid, session.Username, session.Appid, rc)
	}

	return session, nil
}

func authRegister(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	// in
	var in struct {
		Username      string
		Password      string
		CountryAlpha2 string
		SignCode      uint32
	}

	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	if in.Username == "" || in.Password == "" {
		lwutil.SendError("err_input", "")
	}

	pwsha := lwutil.Sha224(in.Password + passwordSalt)

	// insert into db
	res, err := authDB.Exec("INSERT INTO user_accounts (username, password, countryAlpha2, signCode) VALUES (?, ?, ?, ?)",
		in.Username, pwsha, in.CountryAlpha2, in.SignCode)
	lwutil.CheckError(err, "err_account_exists")

	id, err := res.LastInsertId()
	lwutil.CheckError(err, "")

	// reply
	reply := struct {
		Userid int64
	}{id}
	lwutil.WriteResponse(w, reply)
}

func authLogin(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	// input
	var input struct {
		Username  string
		Password  string
		Appsecret string
	}
	err := lwutil.DecodeRequestBody(r, &input)
	lwutil.CheckError(err, "err_decode_body")

	if input.Username == "" || input.Password == "" {
		lwutil.SendError("err_input", "")
	}

	pwsha := lwutil.Sha224(input.Password + passwordSalt)

	// get userid
	row := authDB.QueryRow("SELECT id, countryAlpha2, signCode FROM user_accounts WHERE username=? AND password=?", input.Username, pwsha)
	var userid uint64
	var countryAlpha2 string
	var signCode uint32
	err = row.Scan(&userid, &countryAlpha2, &signCode)
	lwutil.CheckError(err, "err_not_match")

	// get appid
	appid := uint32(0)
	if input.Appsecret != "" {
		row = authDB.QueryRow("SELECT id FROM apps WHERE secret=?", input.Appsecret)
		err = row.Scan(&appid)
		lwutil.CheckError(err, "err_app_secret")
	}

	// new session
	rc := redisPool.Get()
	defer rc.Close()

	usertoken, err := newSession(w, userid, input.Username, appid, rc)
	lwutil.CheckError(err, "")

	// reply
	lwutil.WriteResponse(w, usertoken)
}

func authLogout(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	rc := redisPool.Get()
	defer rc.Close()

	session, err := findSession(w, r, rc)
	lwutil.CheckError(err, "err_already_logout")

	usertokenCookie, err := r.Cookie("usertoken")
	lwutil.CheckError(err, "err_already_logout")
	usertoken := usertokenCookie.Value

	rc.Send("del", fmt.Sprintf("sessions/%s", usertoken))
	rc.Send("del", fmt.Sprintf("usertokens/%d+%d", session.Userid, session.Appid))
	rc.Flush()
	for i := 0; i < 2; i++ {
		_, err = rc.Receive()
		lwutil.CheckError(err, "")
	}

	// reply
	lwutil.WriteResponse(w, "logout")
}

func authNewApp(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")
	checkAdmin(session)

	// input
	var input struct {
		Name string
	}
	err = lwutil.DecodeRequestBody(r, &input)
	lwutil.CheckError(err, "err_decode_body")

	if input.Name == "" {
		lwutil.SendError("err_input", "input.Name empty")
	}

	// db
	stmt, err := authDB.Prepare("INSERT INTO apps (name, secret) VALUES (?, ?)")
	lwutil.CheckError(err, "")

	secret := lwutil.GenUUID()
	_, err = stmt.Exec(input.Name, secret)
	lwutil.CheckError(err, "err_name_exists")

	// reply
	reply := struct {
		Name   string
		Secret string
	}{input.Name, secret}
	lwutil.WriteResponse(w, reply)
}

func authListApp(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")
	checkAdmin(session)

	// db
	rows, err := authDB.Query("SELECT name, secret FROM apps")
	lwutil.CheckError(err, "")

	type App struct {
		Name   string
		Secret string
	}

	apps := make([]App, 0, 16)
	var app App
	for rows.Next() {
		err = rows.Scan(&app.Name, &app.Secret)
		lwutil.CheckError(err, "")
		apps = append(apps, app)
	}

	lwutil.WriteResponse(w, apps)
}

func authLoginInfo(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//
	usertokenCookie, err := r.Cookie("usertoken")
	usertoken := usertokenCookie.Value

	//
	reply := struct {
		Session   *Session
		UserToken string
	}{session, usertoken}

	lwutil.WriteResponse(w, reply)
}

func regAuth() {
	http.Handle("/auth/login", lwutil.ReqHandler(authLogin))
	http.Handle("/auth/logout", lwutil.ReqHandler(authLogout))
	http.Handle("/auth/register", lwutil.ReqHandler(authRegister))
	http.Handle("/auth/info", lwutil.ReqHandler(authLoginInfo))
}
