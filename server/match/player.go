package main

import (
	"encoding/json"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	//. "github.com/qiniu/api/conf"
	//"github.com/qiniu/api/rs"
	"./ssdb"
	"errors"
	"net/http"
)

const (
	H_PLAYER_INFO    = "H_PLAYER_INFO" //subkey:(int64)userId value:(PlayerInfo)playerInfo
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
	glog.Info("")
}

type PlayerInfo struct {
	NickName        string
	TeamName        string
	Gender          int
	CustomAvatarKey string
	GravatarKey     string
	Money           int64
	BetMax          int
	RewardCache     int64
	Secret          string
	AllowSave       bool
}

func getPlayerInfo(ssdb *ssdb.Client, userId int64) (*PlayerInfo, error) {
	resp, err := ssdb.Do("hget", H_PLAYER_INFO, userId)
	lwutil.CheckSsdbError(resp, err)

	var playerInfo PlayerInfo
	if resp[0] == "not_found" {
		return nil, errors.New("not_found")
	} else {
		err = json.Unmarshal([]byte(resp[1]), &playerInfo)
		lwutil.CheckError(err, "")
	}
	playerInfo.AllowSave = true
	return &playerInfo, nil
}

func savePlayerInfo(ssdb *ssdb.Client, userId int64, playerInfo *PlayerInfo) {
	if !playerInfo.AllowSave {
		lwutil.SendError("err_player_save_locked", "")
	}
	js, err := json.Marshal(playerInfo)
	lwutil.CheckError(err, "")

	resp, err := ssdb.Do("hset", H_PLAYER_INFO, userId, js)
	lwutil.CheckSsdbError(resp, err)
}

func apiGetPlayerInfo(w http.ResponseWriter, r *http.Request) {
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
	playerInfo, err := getPlayerInfo(ssdb, session.Userid)
	lwutil.CheckError(err, "")

	//out
	out := struct {
		*PlayerInfo
		BetCloseBeforeEndSec int
	}{
		playerInfo,
		BET_CLOSE_BEFORE_END_SEC,
	}
	lwutil.WriteResponse(w, out)
}

func apiSetPlayerInfo(w http.ResponseWriter, r *http.Request) {
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
		playerInfo.BetMax = 100
		playerInfo.Money = INIT_MONEY
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
	playerInfo.AllowSave = true
	savePlayerInfo(ssdb, session.Userid, &playerInfo)

	//out
	lwutil.WriteResponse(w, playerInfo)
}

func apiAddRewardFromCache(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//
	playerInfo, err := getPlayerInfo(ssdb, session.Userid)
	lwutil.CheckError(err, "")
	if playerInfo.RewardCache > 0 {
		playerInfo.Money += playerInfo.RewardCache
		playerInfo.RewardCache = 0
		savePlayerInfo(ssdb, session.Userid, playerInfo)
	}

	//out
	out := map[string]interface{}{
		"Money": playerInfo.Money,
	}
	lwutil.WriteResponse(w, out)
}

func regPlayer() {
	http.Handle("/player/getInfo", lwutil.ReqHandler(apiGetPlayerInfo))
	http.Handle("/player/setInfo", lwutil.ReqHandler(apiSetPlayerInfo))
	http.Handle("/player/addRewardFromCache", lwutil.ReqHandler(apiAddRewardFromCache))
}
