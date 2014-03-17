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
	TEAM_MAP = map[uint32]int{
		11: 1, 12: 1, 13: 1, 14: 1, 15: 1,
		21: 1, 22: 1, 23: 1,
		31: 1, 32: 1, 33: 1, 34: 1, 35: 1, 36: 1, 37: 1,
		41: 1, 42: 1, 43: 1, 44: 1, 45: 1, 46: 1,
		50: 1, 51: 1, 52: 1, 53: 1, 54: 1,
		61: 1, 62: 1, 63: 1, 64: 1, 65: 1,
		91: 1, 92: 1,
		71: 1,
	}
)

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

func getPlayerInfoField(ssdb *ssdb.Client, userId uint64, field string) string {
	key := makePlayerInfoKey(userId)
	resp, err := ssdb.Do("hget", key, field)
	lwutil.CheckSsdbError(resp, err)

	return resp[1]
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
