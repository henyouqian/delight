package main

import (
	"encoding/json"
	"fmt"
	"github.com/garyburd/redigo/redis"
	// "github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	//. "github.com/qiniu/api/conf"
	//"github.com/qiniu/api/rs"
	"net/http"
	//"strconv"
	"time"
)

const (
	H_MATCH                 = "hMatch"
	Z_MATCH                 = "zMatch"
	H_MATCH_RECORD          = "hMatchRecord"
	Z_MATCH_LEADERBOARD_PRE = "zMatchLeaderboard"
	H_PACK_MATCH            = "hPackMatch"
	MATCH_SERIAL            = "matchSerial"
	MATCH_COST_MONEY        = 100
	MATCH_EXPIRE_SECONDS    = 600
)

type Match struct {
	Id        uint64
	PackId    uint64
	BeginTime string
	EndTime   string
}

type MatchRecord struct {
	MatchId        uint64
	Trys           uint32
	MatchKey       string
	MatchKeyExpire int64
	HighScore      int32
}

func newMatch(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")
	checkAdmin(session)

	//in
	var match Match
	err = lwutil.DecodeRequestBody(r, &match)
	lwutil.CheckError(err, "err_decode_body")

	//check time
	timeBegin, err := time.ParseInLocation("2006-01-02T15:04", match.BeginTime, time.Local)
	lwutil.CheckError(err, "")
	timeEnd, err := time.ParseInLocation("2006-01-02T15:04", match.EndTime, time.Local)
	lwutil.CheckError(err, "")
	dur := timeEnd.Sub(timeBegin)
	if dur.Minutes() < 10 {
		lwutil.SendError("err_time", "match duration < 10 minutes")
	}
	if timeBegin.Before(time.Now()) {
		lwutil.SendError("err_time", "match begin time is smaller than now")
	}

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//check pack id
	resp, err := ssdb.Do("hexists", H_PACK, match.PackId)
	lwutil.CheckSsdbError(resp, err)
	if resp[1] != "1" {
		lwutil.SendError("err_not_found", "pack not found")
	}

	//check pack repeat
	resp, err = ssdb.Do("hexists", H_PACK_MATCH, match.PackId)
	lwutil.CheckSsdbError(resp, err)
	if resp[1] == "1" {
		lwutil.SendError("err_repeat", "pack repeat")
	}

	//gen id
	match.Id, err = GenSerial(ssdb, MATCH_SERIAL)
	lwutil.CheckError(err, "")

	//add to hash
	jsMatch, _ := json.Marshal(&match)
	resp, err = ssdb.Do("hset", H_MATCH, match.Id, jsMatch)
	lwutil.CheckSsdbError(resp, err)

	//add to zset
	resp, err = ssdb.Do("zset", Z_MATCH, match.Id, match.Id)
	lwutil.CheckSsdbError(resp, err)

	//add to exist hash
	resp, err = ssdb.Do("hset", H_PACK_MATCH, match.PackId, match.Id)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, match)
}

func delMatch(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		Id uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get match
	resp, err := ssdb.Do("hget", H_MATCH, in.Id)
	lwutil.CheckSsdbError(resp, err)
	var match Match
	err = json.Unmarshal([]byte(resp[1]), &match)
	lwutil.CheckError(err, "")

	resp, err = ssdb.Do("hdel", H_MATCH, match.Id)
	lwutil.CheckSsdbError(resp, err)

	resp, err = ssdb.Do("zdel", Z_MATCH, match.Id)
	lwutil.CheckSsdbError(resp, err)

	resp, err = ssdb.Do("hdel", H_PACK_MATCH, match.PackId)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, match)
}

func listMatch(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		StartMatchId uint64
		Limit        uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//
	var start interface{}
	if in.StartMatchId == 0 {
		start = ""
	} else {
		start = in.StartMatchId
	}

	resp, err := ssdb.Do("zrscan", Z_MATCH, start, start, "", in.Limit)
	lwutil.CheckSsdbError(resp, err)

	if len(resp) == 1 {
		lwutil.SendError("err_not_found", fmt.Sprintf("in:%+v", in))
	}

	//get matches
	resp = resp[1:]
	matchNum := (len(resp)) / 2
	args := make([]interface{}, matchNum+2)
	args[0] = "multi_hget"
	args[1] = H_MATCH
	for i, _ := range args {
		if i >= 2 {
			args[i] = resp[(i-2)*2]
		}
	}
	resp, err = ssdb.Do(args...)
	lwutil.CheckSsdbError(resp, err)
	resp = resp[1:]

	matches := make([]Match, len(resp)/2)
	for i, _ := range matches {
		js := resp[i*2+1]
		err = json.Unmarshal([]byte(js), &matches[i])
		lwutil.CheckError(err, "")
	}

	//get packs
	args = make([]interface{}, len(matches)+2)
	args[0] = "multi_hget"
	args[1] = H_PACK
	for i, _ := range args {
		if i >= 2 {
			args[i] = matches[i-2].Id
		}
	}
	resp, err = ssdb.Do(args...)
	lwutil.CheckSsdbError(resp, err)
	resp = resp[1:]

	packs := make([]Pack, len(resp)/2)
	for i, _ := range packs {
		packjs := resp[i*2+1]
		err = json.Unmarshal([]byte(packjs), &packs[i])
		lwutil.CheckError(err, "")
		if packs[i].Tags == nil {
			packs[i].Tags = make([]string, 0)
		}
	}

	//out
	type OutMatch struct {
		Id        uint64
		BeginTime string
		EndTime   string
		Pack      Pack
	}
	out := make([]OutMatch, len(matches))
	for i, v := range matches {
		out[i].Id = v.Id
		out[i].BeginTime = v.BeginTime
		out[i].EndTime = v.EndTime
		out[i].Pack = packs[i]
	}

	//out
	lwutil.WriteResponse(w, &out)
}

func beginMatch(w http.ResponseWriter, r *http.Request) {
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

	//check match exist
	resp, err := ssdb.Do("hexists", H_MATCH, in.MatchId)
	lwutil.CheckSsdbError(resp, err)
	if resp[1] != "1" {
		lwutil.SendError("err_not_found", "match not found")
	}

	//check match record exist
	record := MatchRecord{}
	record.MatchId = in.MatchId

	recordKey := fmt.Sprintf("%d/%d", in.MatchId, session.Userid)
	resp, err = ssdb.Do("hget", H_MATCH_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] == "ok" {
		err = json.Unmarshal([]byte(resp[1]), &record)
		lwutil.CheckError(err, "")
		record.Trys++

		//spend money
		var playerData PlayerData
		_getPlayerInfo(ssdb, session.Userid, &playerData)
		if playerData.Money < MATCH_COST_MONEY {
			lwutil.SendError("err_money", "not enough money")
		}
		playerData.Money -= MATCH_COST_MONEY
		_setPlayerInfo(ssdb, session.Userid, &playerData)

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
		MatchId  uint64
		MatchKey string
		Score    int32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//check match record
	record := MatchRecord{}

	recordKey := fmt.Sprintf("%d/%d", in.MatchId, session.Userid)
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
	leaderBoardName := fmt.Sprintf("%s/%d", Z_MATCH_LEADERBOARD_PRE, in.MatchId)
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

	//out
	out := struct {
		Rank     uint32
		RankNum  uint32
		BeatRate float32
	}{
		uint32(rank + 1),
		uint32(rankNum),
		float32(rankNum-rank-1) / float32(rankNum-1),
	}

	//out
	lwutil.WriteResponse(w, out)
}

func regMatch() {
	http.Handle("/match/new", lwutil.ReqHandler(newMatch))
	http.Handle("/match/del", lwutil.ReqHandler(delMatch))
	http.Handle("/match/list", lwutil.ReqHandler(listMatch))
	http.Handle("/match/begin", lwutil.ReqHandler(beginMatch))
	http.Handle("/match/end", lwutil.ReqHandler(endMatch))
}
