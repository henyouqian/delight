package main

import (
	"encoding/json"
	"fmt"
	"github.com/garyburd/redigo/redis"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	//. "github.com/qiniu/api/conf"
	//"github.com/qiniu/api/rs"
	"net/http"
	"strconv"
	"time"
)

const (
	CURRENT_MATCH              = "currentMatch"
	MATCH_PACK_COMMING_LIST    = "matchPackCommingList"
	H_MATCH                    = "hMatch"
	Z_MATCH                    = "zMatch"
	H_MATCH_RECORD             = "hMatchRecord"
	Z_MATCH_LEADERBOARD_PRE    = "zMatchLeaderboard"
	Z_ZONE_LEADERBOARD_PRE     = "zZoneLeaderboard"
	Z_FREEPLAY_LEADERBOARD_PRE = "zFreePlayLeaderboard"
	H_PACK_MATCH               = "hPackMatch"
	H_FREEPLAY_RECORD          = "hFreePlayRecord"
	MATCH_SERIAL               = "matchSerial"
	MATCH_COST_MONEY           = 100
	MATCH_EXPIRE_SECONDS       = 600
)

type _Match struct {
	Id        uint64
	PackId    uint64
	BeginTime string
	EndTime   string
}

type Match struct {
	Id         uint64
	PackId     uint64
	RoundBegin [6]int64
	CurrRound  int
}

type MatchRecord struct {
	MatchKey       string
	MatchKeyExpire int64
	Trys           uint32
	HighScore      int32
}

type FreePlayRecord struct {
	Trys      uint32
	HighScore int32
}

func getCurrMatch(match *Match) {
	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	resp, err := ssdb.Do("get", CURRENT_MATCH)
	lwutil.CheckSsdbError(resp, err)
	glog.Info(resp[1])
	err = json.Unmarshal([]byte(resp[1]), match)
	lwutil.CheckError(err, "")
}

func getCurrentMatch(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	var match Match
	getCurrMatch(&match)

	//
	out := struct {
		Match
		Now int64
	}{
		match,
		time.Now().Unix(),
	}
	lwutil.WriteResponse(w, out)
}

func setCommingMatchList(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")
	checkAdmin(session)

	//in
	var in []uint32
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//set
	js, err := json.Marshal(in)
	lwutil.CheckError(err, "")
	resp, err := ssdb.Do("set", MATCH_PACK_COMMING_LIST, js)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, in)
}

func getCommingMatchList(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")
	checkAdmin(session)

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get
	var list []uint32
	resp, err := ssdb.Do("get", MATCH_PACK_COMMING_LIST)
	lwutil.CheckSsdbError(resp, err)
	err = json.Unmarshal([]byte(resp[1]), &list)
	lwutil.CheckError(err, "")

	//out
	lwutil.WriteResponse(w, list)
}

func beginMatch(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get current match
	var match Match
	getCurrMatch(&match)

	//check match record exist
	record := MatchRecord{}

	recordKey := fmt.Sprintf("%d/%d", match.Id, session.Userid)
	resp, err := ssdb.Do("hget", H_MATCH_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] == "ok" {
		err = json.Unmarshal([]byte(resp[1]), &record)
		lwutil.CheckError(err, "")
		record.Trys++

		// //spend money
		// moneyStr := _getPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_MONEY)
		// money, err := strconv.ParseUint(moneyStr, 10, 32)
		// lwutil.CheckError(err, "")

		// if money < MATCH_COST_MONEY {
		// 	lwutil.SendError("err_money", "not enough money")
		// }
		// money -= MATCH_COST_MONEY
		// _setPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_MONEY, money)

	} else {
		record.Trys = 1
	}

	//gen match key
	record.MatchKey = lwutil.GenUUID()
	record.MatchKeyExpire = time.Now().Unix() + MATCH_EXPIRE_SECONDS

	//update record
	jsRecord, err := json.Marshal(record)
	resp, err = ssdb.Do("hset", H_MATCH_RECORD, recordKey, jsRecord)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, record)
}

func endMatch(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		MatchKey string
		Score    int32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get current match
	var match Match
	getCurrMatch(&match)

	//check match record
	record := MatchRecord{}

	recordKey := fmt.Sprintf("%d/%d", match.Id, session.Userid)
	resp, err := ssdb.Do("hget", H_MATCH_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		lwutil.SendError("err_not_found", "match record not found")
	}

	err = json.Unmarshal([]byte(resp[1]), &record)
	lwutil.CheckError(err, "")
	if record.MatchKey != in.MatchKey {
		lwutil.SendError("err_not_match", "matchKey not match")
	}
	if time.Now().Unix() > record.MatchKeyExpire {
		lwutil.SendError("err_expired", "matchKey expired")
	}

	//clear record
	record.MatchKeyExpire = 0

	//update score
	scoreUpdate := false
	if record.Trys == 1 {
		record.HighScore = in.Score
		scoreUpdate = true
	} else {
		if in.Score > record.HighScore {
			record.HighScore = in.Score
			scoreUpdate = true
		}
	}

	//save record
	jsRecord, err := json.Marshal(record)
	resp, err = ssdb.Do("hset", H_MATCH_RECORD, recordKey, jsRecord)
	lwutil.CheckSsdbError(resp, err)

	//redis
	rc := authRedisPool.Get()
	defer rc.Close()

	//leaderboard
	leaderBoardName := fmt.Sprintf("%s/%d", Z_MATCH_LEADERBOARD_PRE, match.Id)
	if scoreUpdate {
		// resp, err = ssdb.Do("zset", leaderBoardName, session.Userid, record.HighScore)
		// lwutil.CheckSsdbError(resp, err)
		_, err = rc.Do("ZADD", leaderBoardName, record.HighScore, session.Userid)
		lwutil.CheckError(err, "")
	}

	//get rank
	rc.Send("ZREVRANK", leaderBoardName, session.Userid)
	rc.Send("ZCARD", leaderBoardName)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	rank, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")
	rankNum, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")

	//zone leaderboard
	zoneStr := _getPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_ZONE)
	zone, err := strconv.ParseUint(zoneStr, 10, 32)
	lwutil.CheckError(err, "")
	zoneLeaderboardKey := fmt.Sprintf("%s/%d/%d", Z_ZONE_LEADERBOARD_PRE, match.Id, zone)

	if scoreUpdate {
		_, err = rc.Do("ZADD", zoneLeaderboardKey, record.HighScore, session.Userid)
		lwutil.CheckError(err, "")
	}

	//get rank in zone
	rc.Send("ZREVRANK", zoneLeaderboardKey, session.Userid)
	rc.Send("ZCARD", zoneLeaderboardKey)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	zoneRank, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")
	zoneRankNum, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")

	//out
	out := struct {
		Rank        uint32
		RankNum     uint32
		ZoneRank    uint32
		ZoneRankNum uint32
	}{
		uint32(rank + 1),
		uint32(rankNum),
		uint32(zoneRank + 1),
		uint32(zoneRankNum),
	}

	//out
	lwutil.WriteResponse(w, out)
}

func matchFreePlay(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		MatchId uint64
		Score   int32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//check match
	resp, err := ssdb.Do("hexists", H_MATCH, in.MatchId)
	lwutil.CheckSsdbError(resp, err)
	if resp[1] != "1" {
		lwutil.SendError("err_not_found", "match not found")
	}

	//check free play record
	record := FreePlayRecord{}

	recordKey := fmt.Sprintf("%d/%d", in.MatchId, session.Userid)
	resp, err = ssdb.Do("hget", H_FREEPLAY_RECORD, recordKey)
	lwutil.CheckError(err, "")
	scoreUpdate := false
	if resp[0] != "ok" {
		record.HighScore = in.Score
		record.Trys = 1
		scoreUpdate = true
	} else {
		err = json.Unmarshal([]byte(resp[1]), &record)
		lwutil.CheckError(err, "")
		if in.Score > record.HighScore {
			record.HighScore = in.Score
			scoreUpdate = true
		}
		record.Trys++
	}

	//save record
	jsRecord, err := json.Marshal(record)
	resp, err = ssdb.Do("hset", H_FREEPLAY_RECORD, recordKey, jsRecord)
	lwutil.CheckSsdbError(resp, err)

	//redis
	rc := authRedisPool.Get()
	defer rc.Close()

	//leaderboard
	leaderBoardName := fmt.Sprintf("%s/%d", Z_FREEPLAY_LEADERBOARD_PRE, in.MatchId)
	if scoreUpdate {
		_, err = rc.Do("ZADD", leaderBoardName, record.HighScore, session.Userid)
		lwutil.CheckError(err, "")
	}

	//get rank
	rc.Send("ZREVRANK", leaderBoardName, session.Userid)
	rc.Send("ZCARD", leaderBoardName)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	rank, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")
	rankNum, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")

	//out
	out := struct {
		Rank    uint32
		RankNum uint32
		Trys    uint32
	}{
		uint32(rank + 1),
		uint32(rankNum),
		record.Trys,
	}

	//out
	lwutil.WriteResponse(w, out)
}

func _redisInt(reply interface{}, err error) (int, error) {
	v, err := redis.Int(reply, err)
	if err == redis.ErrNil {
		return -1, nil
	} else {
		return v, err
	}
}

func matchInfo(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		MatchId uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get current match
	var match Match
	getCurrMatch(&match)

	if in.MatchId == 0 {
		in.MatchId = match.Id
	}

	//free play record
	freePlayRecord := FreePlayRecord{}
	recordKey := fmt.Sprintf("%d/%d", in.MatchId, session.Userid)
	resp, err := ssdb.Do("hget", H_FREEPLAY_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		freePlayRecord.HighScore = 0
		freePlayRecord.Trys = 0
	} else {
		err = json.Unmarshal([]byte(resp[1]), &freePlayRecord)
		lwutil.CheckError(err, "")
	}

	//match record
	matchRecord := MatchRecord{}
	recordKey = fmt.Sprintf("%d/%d", in.MatchId, session.Userid)
	resp, err = ssdb.Do("hget", H_MATCH_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		matchRecord.HighScore = 0
		matchRecord.Trys = 0
	} else {
		err = json.Unmarshal([]byte(resp[1]), &matchRecord)
		lwutil.CheckError(err, "")
	}

	//redis
	rc := authRedisPool.Get()
	defer rc.Close()

	//leaderboard
	freePlayLeaderBoardName := fmt.Sprintf("%s/%d", Z_FREEPLAY_LEADERBOARD_PRE, in.MatchId)
	matchLeaderBoardName := fmt.Sprintf("%s/%d", Z_MATCH_LEADERBOARD_PRE, in.MatchId)

	//get rank
	rc.Send("ZREVRANK", freePlayLeaderBoardName, session.Userid)
	rc.Send("ZCARD", freePlayLeaderBoardName)
	rc.Send("ZREVRANK", matchLeaderBoardName, session.Userid)
	rc.Send("ZCARD", matchLeaderBoardName)
	err = rc.Flush()
	lwutil.CheckError(err, "")

	fRank, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")
	fRankNum, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")
	mRank, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")
	mRankNum, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")

	//get rank in zone
	zoneStr := _getPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_ZONE)
	zone, err := strconv.ParseUint(zoneStr, 10, 32)
	lwutil.CheckError(err, "")
	zoneLeaderboardKey := fmt.Sprintf("%s/%d/%d", Z_ZONE_LEADERBOARD_PRE, match.Id, zone)

	rc.Send("ZREVRANK", zoneLeaderboardKey, session.Userid)
	rc.Send("ZCARD", zoneLeaderboardKey)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	zoneRank, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")
	zoneRankNum, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")

	//out
	out := struct {
		FreePlayRank      uint32
		FreePlayRankNum   uint32
		FreePlayTrys      uint32
		FreePlayHighScore int32
		MatchRank         uint32
		MatchRankNum      uint32
		MatchTrys         uint32
		MatchHighScore    int32
		ZoneRank          uint32
		ZoneRankNum       uint32
	}{
		uint32(fRank + 1),
		uint32(fRankNum),
		freePlayRecord.Trys,
		freePlayRecord.HighScore,
		uint32(mRank + 1),
		uint32(mRankNum),
		matchRecord.Trys,
		matchRecord.HighScore,
		uint32(zoneRank + 1),
		uint32(zoneRankNum),
	}

	lwutil.WriteResponse(w, out)
}

func regMatch() {
	http.Handle("/match/getCurrent", lwutil.ReqHandler(getCurrentMatch))
	http.Handle("/match/setCommingList", lwutil.ReqHandler(setCommingMatchList))
	http.Handle("/match/getCommingList", lwutil.ReqHandler(getCommingMatchList))
	http.Handle("/match/begin", lwutil.ReqHandler(beginMatch))
	http.Handle("/match/end", lwutil.ReqHandler(endMatch))
	http.Handle("/match/freePlay", lwutil.ReqHandler(matchFreePlay))
	http.Handle("/match/info", lwutil.ReqHandler(matchInfo))
}
