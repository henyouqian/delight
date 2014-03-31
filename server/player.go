package main

import (
	"encoding/json"
	// "fmt"
	"github.com/henyouqian/lwutil"
	//. "github.com/qiniu/api/conf"
	//"github.com/qiniu/api/rs"
	"./ssdb"
	"net/http"
	// "strconv"
	//"strings"
	//"time"
)

const (
	H_PLAYER_INFO    = "H_PLAYER_INFO"
	INIT_MONEY       = 500
	FLD_PLAYER_MONEY = "money"
	FLD_PLAYER_TEAM  = "team"
)

var (
	TEAM_MAP = make(map[uint32]bool)
)

func init() {
	for _, v := range TEAM_IDS {
		TEAM_MAP[v] = true
	}
}

type PlayerInfo struct {
	Name   string
	TeamId uint32
}

func _getPlayerInfo(ssdb *ssdb.Client, session *Session, playerInfo *PlayerInfo) {
	resp, err := ssdb.Do("hget", H_PLAYER_INFO, session.Userid)
	lwutil.CheckError(err, "err_ssdb")

	if resp[0] == "not_found" {
		playerInfo.Name = session.Username
		playerInfo.TeamId = 0

		js, err := json.Marshal(playerInfo)
		lwutil.CheckError(err, "")
		resp, err := ssdb.Do("hset", H_PLAYER_INFO, session.Userid, js)
		lwutil.CheckSsdbError(resp, err)
	} else {
		err = json.Unmarshal([]byte(resp[1]), &playerInfo)
		lwutil.CheckError(err, "")
	}
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
	var playerInfo PlayerInfo
	_getPlayerInfo(ssdb, session, &playerInfo)

	//out
	lwutil.WriteResponse(w, playerInfo)
}

func setPlayerInfo(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in PlayerInfo
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if TEAM_MAP[in.TeamId] == false {
		lwutil.SendError("err_team", "")
	}

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get player info
	if in.Name == "" || in.TeamId == 0 {
		var playerInfo PlayerInfo
		_getPlayerInfo(ssdb, session, &playerInfo)

		if in.Name == "" {
			in.Name = playerInfo.Name
		}
		if in.TeamId == 0 {
			in.TeamId = playerInfo.TeamId
		}
	}

	//set
	js, err := json.Marshal(in)
	resp, err := ssdb.Do("hset", H_PLAYER_INFO, session.Userid, js)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, in)
}

func regPlayer() {
	http.Handle("/player/getInfo", lwutil.ReqHandler(getPlayerInfo))
	http.Handle("/player/setInfo", lwutil.ReqHandler(setPlayerInfo))
}
