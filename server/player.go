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
	"errors"
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
	NickName        string
	TeamName        string
	Gender          uint
	CustomAvatarKey string
	GravatarKey     string
	Level           uint32
	Exp             uint32
	Money           int64
}

func _getPlayerInfo(ssdb *ssdb.Client, session *Session, playerInfo *PlayerInfo) (err error) {
	resp, err := ssdb.Do("hget", H_PLAYER_INFO, session.Userid)
	lwutil.CheckError(err, "err_ssdb")

	if resp[0] == "not_found" {
		return errors.New("not_found")
	} else {
		err = json.Unmarshal([]byte(resp[1]), &playerInfo)
		lwutil.CheckError(err, "")
	}
	return nil
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
	err = _getPlayerInfo(ssdb, session, &playerInfo)
	lwutil.CheckError(err, "")

	//out
	out := struct {
		PlayerInfo
		//Now int64
	}{
		playerInfo,
		//time.Now().Unix(),
	}
	lwutil.WriteResponse(w, out)
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
	if in.Gender > 2 {
		lwutil.SendError("err_gender", "")
	}

	stringLimit(&in.NickName, 40)
	stringLimit(&in.GravatarKey, 20)
	stringLimit(&in.CustomAvatarKey, 60)
	stringLimit(&in.TeamName, 40)

	//check playerInfo
	if in.NickName == "" || in.TeamName == "" || (in.GravatarKey == "" && in.CustomAvatarKey == "") {
		lwutil.SendError("err_info_incomplete", "")
	}

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//check player info exist
	var playerInfo PlayerInfo
	resp, err := ssdb.Do("hget", H_PLAYER_INFO, session.Userid)
	if resp[0] == "not_found" {
		//set default value
		playerInfo = in
		playerInfo.Level = 1
		playerInfo.Exp = 0
		playerInfo.Money = 1000
	} else {
		err = json.Unmarshal([]byte(resp[1]), &playerInfo)
		lwutil.CheckError(err, "")
		if len(in.NickName) > 0 {
			playerInfo.NickName = in.NickName
		}
		if len(in.GravatarKey) > 0 {
			playerInfo.GravatarKey = in.GravatarKey
		}
		if len(in.CustomAvatarKey) > 0 {
			playerInfo.CustomAvatarKey = in.CustomAvatarKey
		}
		if len(in.TeamName) > 0 {
			playerInfo.TeamName = in.TeamName
		}
		playerInfo.Gender = in.Gender
	}

	//set
	js, err := json.Marshal(playerInfo)
	resp, err = ssdb.Do("hset", H_PLAYER_INFO, session.Userid, js)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, playerInfo)
}

func regPlayer() {
	http.Handle("/player/getInfo", lwutil.ReqHandler(getPlayerInfo))
	http.Handle("/player/setInfo", lwutil.ReqHandler(setPlayerInfo))
}
