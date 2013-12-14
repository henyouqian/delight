package main

import (
	//"github.com/garyburd/redigo/redis"
	"github.com/henyouqian/lwutil"
	"net/http"
)

func dig(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	rc := redisPool.Get()
	defer rc.Close()

	session, err := findSession(w, r, rc)
	lwutil.CheckError(err, "err_auth")

	appid := session.Appid
	if appid == 0 {
		lwutil.SendError("err_auth", "Please login with app secret")
	}

	// in
	var in struct {
		MatchId uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	// out
	out := struct {
		Rank  int64
		Score int64
	}{1, 2}
	lwutil.WriteResponse(w, out)
}

func regDig() {
	http.Handle("/dig/dig", lwutil.ReqHandler(dig))
}
