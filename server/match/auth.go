package main

import (
	"encoding/json"
	"fmt"
	// "github.com/garyburd/redigo/redis"
	"./ssdb"
	// "encoding/base64"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	"net/http"
	// "net/mail"
	// "net/smtp"
	"strconv"
	"strings"
	"time"
)

const (
	PASSWORD_SALT      = "liwei"
	SESSION_LIFE_SEC   = 60 * 60 * 24 * 7
	SESSION_UPDATE_SEC = 60 * 60
	H_ACCOUNT          = "H_ACCOUNT"
	H_NAME_ACCONT      = "H_NAME_ACCONT"
	H_SESSION          = "H_SESSION"        //key:token, value:session
	H_USER_TOKEN       = "H_USER_TOKEN"     //key:appid/userid, value:token
	K_RESET_PASSWORD   = "K_RESET_PASSWORD" //key:K_RESET_PASSWORD/<resetKey> value:accountEmail
	RESET_PASSWORD_TTL = 60 * 60
)

var (
	ADMIN_SET = map[string]bool{"henyouqian": true}
)

type Session struct {
	Userid   int64
	Username string
	Born     time.Time
	Appid    int
}

type Account struct {
	Username     string
	Password     string
	RegisterTime string
}

func init() {
	glog.Infoln("auth init")
}

func newSession(w http.ResponseWriter, userid int64, username string, appid int, ssdb *ssdb.Client) (usertoken string) {
	var err error
	if ssdb == nil {
		ssdb, err = ssdbAuthPool.Get()
		lwutil.CheckError(err, "")
		defer ssdb.Close()
	}

	tokenKey := fmt.Sprintf("%s/%d/%d", H_USER_TOKEN, appid, userid)
	resp, err := ssdb.Do("get", tokenKey)
	if resp[0] == "ok" {
		sessionKey := fmt.Sprintf("%s/%s", H_SESSION, resp[1])
		ssdb.Do("del", tokenKey)
		ssdb.Do("del", sessionKey)
	}

	usertoken = lwutil.GenUUID()
	sessionKey := fmt.Sprintf("%s/%s", H_SESSION, usertoken)

	session := Session{userid, username, time.Now(), appid}
	js, err := json.Marshal(session)
	lwutil.CheckError(err, "")

	resp, err = ssdb.Do("setx", sessionKey, js, SESSION_LIFE_SEC)
	lwutil.CheckSsdbError(resp, err)
	resp, err = ssdb.Do("setx", tokenKey, usertoken, SESSION_LIFE_SEC)
	lwutil.CheckSsdbError(resp, err)

	// cookie
	http.SetCookie(w, &http.Cookie{Name: "usertoken", Value: usertoken, MaxAge: SESSION_LIFE_SEC, Path: "/"})

	return usertoken
}

func checkAdmin(session *Session) {
	if !ADMIN_SET[session.Username] {
		lwutil.SendError("err_denied", "")
	}
}

func isAdmin(username string) bool {
	return ADMIN_SET[username]
}

func findSession(w http.ResponseWriter, r *http.Request, ssdb *ssdb.Client) (*Session, error) {
	var err error
	if ssdb == nil {
		ssdb, err = ssdbAuthPool.Get()
		lwutil.CheckError(err, "")
		defer ssdb.Close()
	}

	usertokenCookie, err := r.Cookie("usertoken")
	if err != nil {
		return nil, lwutil.NewErr(err)
	}
	usertoken := usertokenCookie.Value

	sessionKey := fmt.Sprintf("%s/%s", H_SESSION, usertoken)
	resp, err := ssdb.Do("get", sessionKey)
	if err != nil {
		return nil, lwutil.NewErr(err)
	}
	if resp[0] != "ok" {
		return nil, lwutil.NewErrStr(resp[0])
	}

	var session Session
	err = json.Unmarshal([]byte(resp[1]), &session)
	lwutil.CheckError(err, "")

	//update session
	dt := time.Now().Sub(session.Born)
	if dt > SESSION_UPDATE_SEC*time.Second {
		newSession(w, session.Userid, session.Username, session.Appid, ssdb)
	}

	return &session, nil
}

func apiAuthRegister(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbAuthPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	// in
	var in Account
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	if in.Username == "" || in.Password == "" {
		lwutil.SendError("err_input", "")
	}

	in.Password = lwutil.Sha224(in.Password + PASSWORD_SALT)

	//check exist
	rName, err := ssdb.Do("hexists", H_NAME_ACCONT, in.Username)
	lwutil.CheckError(err, "")
	if rName[1] == "1" {
		lwutil.SendError("err_exist", "account already exists")
	}

	//add account
	id := GenSerial(ssdb, "account")
	js, err := json.Marshal(in)
	lwutil.CheckError(err, "")
	_, err = ssdb.Do("hset", H_ACCOUNT, id, js)
	lwutil.CheckError(err, "")

	_, err = ssdb.Do("hset", H_NAME_ACCONT, in.Username, id)
	lwutil.CheckError(err, "")

	// reply
	reply := struct {
		Userid int64
	}{id}
	lwutil.WriteResponse(w, reply)
}

func apiAuthLogin(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbAuthPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	// logout if already login
	// session, err := findSession(w, r, nil)
	// if err == nil {
	// 	usertokenCookie, err := r.Cookie("usertoken")
	// 	if err == nil {
	// 		usertoken := usertokenCookie.Value
	// 		rc.Send("del", fmt.Sprintf("sessions/%s", usertoken))
	// 		rc.Send("del", fmt.Sprintf("usertokens/%d+%d", session.Userid, session.Appid))
	// 		err = rc.Flush()
	// 		lwutil.CheckError(err, "")
	// 	}
	// }

	// input
	var in struct {
		Username  string
		Password  string
		Appsecret string
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	if in.Username == "" || in.Password == "" {
		lwutil.SendError("err_input", "")
	}

	pwsha := lwutil.Sha224(in.Password + PASSWORD_SALT)

	// get userid
	resp, err := ssdb.Do("hget", H_NAME_ACCONT, in.Username)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		lwutil.SendError("err_not_match", "name and password not match")
	}
	userId, err := strconv.ParseInt(resp[1], 10, 64)
	lwutil.CheckError(err, "")

	resp, err = ssdb.Do("hget", H_ACCOUNT, userId)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		lwutil.SendError("err_internal", "account not exist")
	}
	var account Account
	err = json.Unmarshal([]byte(resp[1]), &account)
	lwutil.CheckError(err, "")

	if account.Password != pwsha {
		lwutil.SendError("err_not_match", "name and password not match")
	}

	// get appid
	appid := 0
	// if in.Appsecret != "" {
	// 	row = authDB.QueryRow("SELECT id FROM apps WHERE secret=?", in.Appsecret)
	// 	err = row.Scan(&appid)
	// 	lwutil.CheckError(err, "err_app_secret")
	// }

	// new session
	usertoken := newSession(w, userId, in.Username, appid, ssdb)

	// reply
	out := struct {
		Token  string
		Now    int64
		UserId int64
	}{
		usertoken,
		lwutil.GetRedisTimeUnix(),
		userId,
	}
	lwutil.WriteResponse(w, out)
}

func apiAuthLogout(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbAuthPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//find user token
	usertokenCookie, err := r.Cookie("usertoken")
	lwutil.CheckError(err, "err_already_logout")
	usertoken := usertokenCookie.Value

	//get session
	sessionKey := fmt.Sprintf("%s/%s", H_SESSION, usertoken)
	resp, err := ssdb.Do("get", sessionKey)
	if err != nil || resp[0] != "ok" {
		lwutil.SendError("err_already_logout", "")
	}

	var session Session
	err = json.Unmarshal([]byte(resp[1]), &session)
	lwutil.CheckError(err, "")

	//del
	tokenKey := fmt.Sprintf("%s/%d/%d", H_USER_TOKEN, session.Appid, session.Userid)
	ssdb.Do("del", tokenKey)
	ssdb.Do("del", sessionKey)

	// reply
	lwutil.WriteResponse(w, "logout")
}

func apiAuthLoginInfo(w http.ResponseWriter, r *http.Request) {
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

// func authNewApp(w http.ResponseWriter, r *http.Request) {
// 	lwutil.CheckMathod(r, "POST")

// 	session, err := findSession(w, r, nil)
// 	lwutil.CheckError(err, "err_auth")
// 	checkAdmin(session)

// 	// input
// 	var input struct {
// 		Name string
// 	}
// 	err = lwutil.DecodeRequestBody(r, &input)
// 	lwutil.CheckError(err, "err_decode_body")

// 	if input.Name == "" {
// 		lwutil.SendError("err_input", "input.Name empty")
// 	}

// 	// db
// 	stmt, err := authDB.Prepare("INSERT INTO apps (name, secret) VALUES (?, ?)")
// 	lwutil.CheckError(err, "")

// 	secret := lwutil.GenUUID()
// 	_, err = stmt.Exec(input.Name, secret)
// 	lwutil.CheckError(err, "err_name_exists")

// 	// reply
// 	reply := struct {
// 		Name   string
// 		Secret string
// 	}{input.Name, secret}
// 	lwutil.WriteResponse(w, reply)
// }

// func authListApp(w http.ResponseWriter, r *http.Request) {
// 	lwutil.CheckMathod(r, "POST")

// 	session, err := findSession(w, r, nil)
// 	lwutil.CheckError(err, "err_auth")
// 	checkAdmin(session)

// 	// db
// 	rows, err := authDB.Query("SELECT name, secret FROM apps")
// 	lwutil.CheckError(err, "")

// 	type App struct {
// 		Name   string
// 		Secret string
// 	}

// 	apps := make([]App, 0, 16)
// 	var app App
// 	for rows.Next() {
// 		err = rows.Scan(&app.Name, &app.Secret)
// 		lwutil.CheckError(err, "")
// 		apps = append(apps, app)
// 	}

// 	lwutil.WriteResponse(w, apps)
// }

func apiForgotPassword(w http.ResponseWriter, r *http.Request) {
	var err error

	//in
	var in struct {
		Email string
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	ssdb, err := ssdbAuthPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//check account exist
	resp, err := ssdb.Do("hget", H_NAME_ACCONT, in.Email)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		lwutil.SendError("err_not_exist", "account not exist")
	}

	//gen reset key
	resetKey := lwutil.GenUUID()
	key := fmt.Sprintf("K_RESET_PASSWORD/%s", resetKey)
	resp, err = ssdb.Do("setx", key, in.Email, RESET_PASSWORD_TTL)
	lwutil.CheckError(err, "")

	//
	// body := fmt.Sprintf("请进入以下网址重设《全国拼图大奖赛》密码. \nhttp://pintugame.com/sld/resetpassword?key=%s", resetKey)

	// //email
	// b64 := base64.NewEncoding("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

	// // host := "smtp.qq.com"
	// // email := "103638667@qq.com"
	// // password := "nmmgbnmmgb"
	// host := "mail.pintugame.com"
	// email := "resetpassword1@pintugame.com"
	// password := "Nmmgb808313"
	// toEmail := in.Email

	// from := mail.Address{"全国拼图大奖赛", email}
	// to := mail.Address{"亲爱的《全国拼图大奖赛》用户", toEmail}

	// header := make(map[string]string)
	// header["From"] = from.String()
	// header["To"] = to.String()
	// header["Subject"] = fmt.Sprintf("=?UTF-8?B?%s?=", b64.EncodeToString([]byte("《全国拼图大奖赛》密码重设")))
	// header["MIME-Version"] = "1.0"
	// header["Content-Type"] = "text/html; charset=UTF-8"
	// header["Content-Transfer-Encoding"] = "base64"

	// message := ""
	// for k, v := range header {
	// 	message += fmt.Sprintf("%s: %s\r\n", k, v)
	// }
	// message += "\r\n" + b64.EncodeToString([]byte(body))

	// auth := smtp.PlainAuth(
	// 	"",
	// 	email,
	// 	password,
	// 	host,
	// )

	// err = smtp.SendMail(
	// 	host+":25",
	// 	auth,
	// 	email,
	// 	[]string{to.Address},
	// 	[]byte(message),
	// )

	host := "mail.pintugame.com"
	from := "resetpassword@pintugame.com"
	password := "Nmmgb808313"
	to := in.Email

	auth := lwutil.LoginAuth(
		from,
		password,
		host,
	)

	//auth := LoginAuth(
	//	"applesabi@126.com",
	//	"smtpceshi",
	//	"smtp.126.com",
	//)

	ctype := fmt.Sprintf("Content-Type: %s; charset=%s", "text/html", "utf-8")
	msg := fmt.Sprintf("To: %s\r\nCc: %s\r\nFrom: %s\r\nSubject: %s\r\n%s\r\n\r\n%s", "<TTT>trywen@qq.com", "", "TRY<trywen001@126.com>", "Hello", ctype, "<html><body>Hello Hello</body></html>")

	err = lwutil.SendMail(
		host+":25",
		auth,
		from,
		[]string{to},
		[]byte(msg),
	)
	lwutil.CheckError(err, "")
}

func apiSsdbTest(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	ssdb, err := ssdbAuthPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	var in string
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	strs := strings.Split(in, ",")

	intfs := make([]interface{}, len(strs))
	for i, v := range strs {
		intfs[i] = interface{}(v)
	}
	res, err := ssdb.Do(intfs...)
	// lwutil.CheckError(err, "")
	lwutil.CheckSsdbError(res, err)

	lwutil.WriteResponse(w, res)
}

func regAuth() {
	http.Handle("/auth/login", lwutil.ReqHandler(apiAuthLogin))
	http.Handle("/auth/logout", lwutil.ReqHandler(apiAuthLogout))
	http.Handle("/auth/register", lwutil.ReqHandler(apiAuthRegister))
	http.Handle("/auth/info", lwutil.ReqHandler(apiAuthLoginInfo))
	http.Handle("/auth/forgotPassword", lwutil.ReqHandler(apiForgotPassword))
	http.Handle("/auth/ssdbTest", lwutil.ReqHandler(apiSsdbTest))
}
