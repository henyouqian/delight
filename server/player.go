package main

import (
	"encoding/json"
	//"fmt"
	"github.com/henyouqian/lwutil"
	//. "github.com/qiniu/api/conf"
	//"github.com/qiniu/api/rs"
	"./ssdb"
	"net/http"
	//"strconv"
	//"strings"
	//"time"
)

const (
	H_PLAYER   = "h_player"
	INIT_MONEY = 500
)

type PlayerData struct {
	Money uint32
}

func _getPlayerInfo(ssdb *ssdb.Client, userId uint64, data *PlayerData) {
	resp, err := ssdb.Do("hget", H_PLAYER, userId)
	lwutil.CheckSsdbError(resp, err)

	err = json.Unmarshal([]byte(resp[1]), data)
	lwutil.CheckError(err, "")
}

func _setPlayerInfo(ssdb *ssdb.Client, userId uint64, data *PlayerData) {
	js, err := json.Marshal(data)
	lwutil.CheckError(err, "")
	resp, err := ssdb.Do("hset", H_PLAYER, userId, js)
	lwutil.CheckSsdbError(resp, err)
}

func getPlayerInfo(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get info
	resp, err := ssdb.Do("hget", H_PLAYER, session.Userid)
	lwutil.CheckError(err, "err_ssdb")
	var data PlayerData
	if resp[0] == "not_found" {
		data.Money = INIT_MONEY

		js, err := json.Marshal(data)
		resp, err := ssdb.Do("hset", H_PLAYER, session.Userid, js)
		lwutil.CheckSsdbError(resp, err)
		w.Write([]byte(js))
	} else {
		w.Write([]byte(resp[1]))
	}
}

func regPlayer() {
	http.Handle("/player/getInfo", lwutil.ReqHandler(getPlayerInfo))
}
