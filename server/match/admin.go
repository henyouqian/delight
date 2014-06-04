package main

import (
	// "encoding/json"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	"net/http"
	"strconv"
)

func glogAdmin() {
	glog.Info("")
}

func addMoney(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	ssdbAuth, err := ssdbAuthPool.Get()
	lwutil.CheckError(err, "")
	defer ssdbAuth.Close()

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	checkAdmin(session)

	//in
	var in struct {
		UserId   uint64
		UserName string
		AddMoney uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	var playerInfo PlayerInfo

	//get userid
	userId := in.UserId
	if userId == 0 {
		resp, err := ssdbAuth.Do("hget", H_NAME_ACCONT, in.UserName)
		lwutil.CheckError(err, "")
		if resp[0] != "ok" {
			lwutil.SendError("err_not_match", "name and password not match")
		}
		userId, err = strconv.ParseUint(resp[1], 10, 64)
		lwutil.CheckError(err, "")
	}

	err = getPlayer(ssdb, userId, &playerInfo)
	lwutil.CheckError(err, "")
	playerInfo.Money += in.AddMoney
	savePlayer(ssdb, userId, &playerInfo)

	//out
	lwutil.WriteResponse(w, playerInfo)
}

func regAdmin() {
	http.Handle("/admin/addMoney", lwutil.ReqHandler(addMoney))
}
