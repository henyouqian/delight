package main

import (
	// "encoding/json"
	"fmt"
	"github.com/henyouqian/lwutil"
	//. "github.com/qiniu/api/conf"
	//"github.com/qiniu/api/rs"
	"./ssdb"
	"net/http"
	"strconv"
	//"strings"
	//"time"
)

const (
	H_PLAYER_INFO_PRE = "H_PLAYER_INFO_PRE"
	INIT_MONEY        = 500
	FLD_PLAYER_MONEY  = "money"
	FLD_PLAYER_TEAM   = "team"
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
	Money uint32
	Team  uint32
}

func makePlayerInfoKey(playerId uint64) string {
	return fmt.Sprintf("%s/%d", H_PLAYER_INFO_PRE, playerId)
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
	key := makePlayerInfoKey(session.Userid)
	resp, err := ssdb.Do("multi_hget", key, FLD_PLAYER_MONEY, FLD_PLAYER_TEAM)
	lwutil.CheckError(err, "err_ssdb")

	var info PlayerInfo
	if resp[0] == "not_found" || len(resp) < 5 {
		info.Money = INIT_MONEY
		info.Team = 0

		resp, err := ssdb.Do("multi_hset", key, FLD_PLAYER_MONEY, INIT_MONEY,
			FLD_PLAYER_TEAM, 0)
		lwutil.CheckSsdbError(resp, err)
	} else {
		money, err := strconv.ParseUint(resp[2], 10, 32)
		lwutil.CheckError(err, "")
		team, err := strconv.ParseUint(resp[4], 10, 32)
		lwutil.CheckError(err, "")
		info.Money = uint32(money)
		info.Team = uint32(team)
	}

	//out
	lwutil.WriteResponse(w, info)
}

func getPlayerInfoField(ssdb *ssdb.Client, userId uint64, field string) (string, error) {
	key := makePlayerInfoKey(userId)
	resp, err := ssdb.Do("hget", key, field)
	if err != nil {
		return "", err
	}
	if resp[0] != "ok" {
		return "", lwutil.NewErrStr(resp[0])
	}

	return resp[1], err
}

func setPlayerInfoField(ssdb *ssdb.Client, userId uint64, field string, value interface{}) {
	key := makePlayerInfoKey(userId)
	resp, err := ssdb.Do("hset", key, field, value)
	lwutil.CheckSsdbError(resp, err)
}

func setPlayerTeam(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		TeamId uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if _, ok := TEAM_MAP[in.TeamId]; ok == false {
		lwutil.SendError("err_team", "")
	}

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//set
	key := makePlayerInfoKey(session.Userid)
	_, err = ssdb.Do("hset", key, FLD_PLAYER_TEAM, in.TeamId)
	lwutil.CheckError(err, "err_ssdb")

	//out
	lwutil.WriteResponse(w, in)
}

func regPlayer() {
	http.Handle("/player/getInfo", lwutil.ReqHandler(getPlayerInfo))
	http.Handle("/player/setTeam", lwutil.ReqHandler(setPlayerTeam))
}
