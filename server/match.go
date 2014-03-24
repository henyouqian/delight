package main

import (
	"encoding/json"
	"fmt"
	"github.com/garyburd/redigo/redis"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	//. "github.com/qiniu/api/conf"
	//"github.com/qiniu/api/rs"
	// "io/ioutil"
	"math/rand"
	"net/http"
	"strconv"
	"time"
)

func init() {
	glog.Info("match init")
}

const (
	H_EVENT                      = "H_EVENT"
	Z_EVENT                      = "Z_EVENT"
	Z_CLOSED_EVENT               = "Z_CLOSED_EVENT"
	H_EVENT_RESULT               = "H_EVENT_RESULT"
	H_EVENT_PLAYER_RECORD        = "H_EVENT_PLAYER_RECORD"
	Z_EVENT_LEADERBOARD_PRE      = "Z_EVENT_LEADERBOARD_PRE"
	Z_EVENT_TEAM_LEADERBOARD_PRE = "Z_EVENT_TEAM_LEADERBOARD_PRE"
	Z_FREEPLAY_LEADERBOARD_PRE   = "Z_FREEPLAY_LEADERBOARD_PRE"
	H_FREEPLAY_RECORD            = "H_FREEPLAY_RECORD"
	H_EVENT_ROUND_TEAM_TOPTEN    = "H_EVENT_ROUND_TEAM_TOPTEN"
	EVENT_SERIAL                 = "EVENT_SERIAL"
	TRY_COST_MONEY               = 100
	TRY_EXPIRE_SECONDS           = 600
	TEAM_CHAMPIONSHIP_ROUND_NUM  = 6
)

var (
	EVENT_TYPES = map[string]int{
		"PERSONAL_RANK":     1,
		"TEAM_CHAMPIONSHIP": 1,
	}

	TEAM_IDS = []uint32{
		11, 12, 13, 14, 15,
		21, 22, 23,
		31, 32, 33, 34, 35, 36, 37,
		41, 42, 43, 44, 45, 46,
		50, 51, 52, 53, 54,
		61, 62, 63, 64, 65,
		91, 92,
		71,
	}
)

type Event struct {
	Type             string //"PERSONAL_RANK", "TEAM_CHAMPIONSHIP"
	Id               uint64
	PackId           uint64
	TimePointStrings []string
	TimePoints       []int64
}

type EventResult struct {
	EventId   uint64
	CurrRound int
	Rounds    []Round
}

type Round struct {
	Games []Game
}

type Game struct {
	Teams []Team
}

type Team struct {
	Id    uint32
	Score int32
	//TopTen []GameRecord
}

type GameRecord struct {
	PlayerId uint64
	Score    int32
	Time     int64
}

type EventPlayerRecord struct {
	TeamId        uint32
	Secret        string
	SecretExpire  int64
	Trys          uint32
	HighScore     int32
	HighScoreTime int64
}

type FreePlayRecord struct {
	Trys      uint32
	HighScore int32
}

func shuffleArray(src []uint32) []uint32 {
	dest := make([]uint32, len(src))
	rand.Seed(time.Now().UTC().UnixNano())
	perm := rand.Perm(len(src))
	for i, v := range perm {
		dest[v] = src[i]
	}
	return dest
}

func newEvent(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")
	checkAdmin(session)

	//in
	var event Event
	err = lwutil.DecodeRequestBody(r, &event)
	lwutil.CheckError(err, "err_decode_body")
	if _, ok := EVENT_TYPES[event.Type]; ok == false {
		lwutil.SendError("err_match_type", "")
	}
	switch event.Type {
	case "PERSONAL_RANK":
		if len(event.TimePointStrings) != 2 {
			lwutil.SendError("err_timepoint_num", "len(event.TimePointStrings) != 2")
		}
	case "TEAM_CHAMPIONSHIP":
		if len(event.TimePointStrings) != TEAM_CHAMPIONSHIP_ROUND_NUM {
			lwutil.SendError("err_timepoint_num", "len(event.TimePointStrings) != 6")
		}
	}

	//fill TimePoints
	now := time.Now().Unix()
	event.TimePoints = make([]int64, len(event.TimePointStrings))
	for i, v := range event.TimePointStrings {
		t, err := time.ParseInLocation("2006-01-02T15:04", v, time.Local)
		lwutil.CheckError(err, "")
		event.TimePoints[i] = t.Unix()
		if event.TimePoints[i] < now {
			lwutil.SendError("err_time_points", "timePoints must larger than now")
		}
	}

	//check timePotins
	tp := event.TimePoints[0]
	for i := 1; i < len(event.TimePoints); i++ {
		if tp >= event.TimePoints[i] {
			lwutil.SendError("err_time_points", fmt.Sprintf("timePoints must order by asc. TimePoints=%v", event.TimePoints))
		}
		tp = event.TimePoints[i]
	}

	//gen serial
	event.Id = GenSerial(ssdb, EVENT_SERIAL)

	//save to ssdb
	js, err := json.Marshal(event)
	resp, err := ssdb.Do("hset", H_EVENT, event.Id, js)
	lwutil.CheckSsdbError(resp, err)

	resp, err = ssdb.Do("zset", Z_EVENT, event.Id, event.TimePoints[0])
	lwutil.CheckSsdbError(resp, err)

	//init first round
	eventResult := EventResult{
		EventId:   event.Id,
		CurrRound: 0,
	}
	eventResult.Rounds = make([]Round, TEAM_CHAMPIONSHIP_ROUND_NUM)
	eventResult.Rounds[0].Games = make([]Game, 8)
	teamIds := shuffleArray(TEAM_IDS)
	for i, _ := range eventResult.Rounds[0].Games {
		teams := make([]Team, 4)
		for j := 0; j < 4; j++ {
			teams[j].Id = teamIds[i*4+j]
		}
		switch i {
		case 6:
			teams = append(teams, Team{Id: teamIds[len(teamIds)-2]})
		case 7:
			teams = append(teams, Team{Id: teamIds[len(teamIds)-1]})
		}
		eventResult.Rounds[0].Games[i].Teams = teams
	}

	//save event result
	js, err = json.Marshal(eventResult)
	resp, err = ssdb.Do("hset", H_EVENT_RESULT, event.Id, js)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, event)
}

func delEvent(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")
	checkAdmin(session)

	//in
	var in struct {
		EventId uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//del
	resp, err := ssdb.Do("zdel", Z_EVENT, in.EventId)
	lwutil.CheckSsdbError(resp, err)
	resp, err = ssdb.Do("hdel", H_EVENT, in.EventId)
	lwutil.CheckSsdbError(resp, err)
	resp, err = ssdb.Do("hdel", H_EVENT_RESULT, in.EventId)
	lwutil.CheckSsdbError(resp, err)

	lwutil.WriteResponse(w, in)
}

func listEvent(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//session
	_, err = findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		StartId uint32
		Limit   uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if in.Limit > 20 {
		in.Limit = 20
	}

	var startId interface{}
	if in.StartId == 0 {
		startId = ""
	} else {
		startId = in.StartId
	}

	//zrscan
	resp, err := ssdb.Do("zrscan", Z_EVENT, startId, "", "", in.Limit)
	lwutil.CheckSsdbError(resp, err)
	resp = resp[1:]

	//multi_hget
	keyNum := len(resp) / 2
	cmds := make([]interface{}, keyNum+2)
	cmds[0] = "multi_hget"
	cmds[1] = H_EVENT
	for i := 0; i < keyNum; i++ {
		cmds[2+i] = resp[i*2]
	}
	resp, err = ssdb.Do(cmds...)
	resp = resp[1:]

	//out
	eventNum := len(resp) / 2
	out := make([]Event, eventNum)
	for i := 0; i < eventNum; i++ {
		err = json.Unmarshal([]byte(resp[i*2+1]), &out[i])
		lwutil.CheckError(err, "")
	}

	lwutil.WriteResponse(w, out)
}

func listClosedEvent(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//session
	_, err = findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		StartId uint32
		Limit   uint32
	}

	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if in.Limit > 20 {
		in.Limit = 20
	}

	var startId interface{}
	if in.StartId == 0 {
		startId = ""
	} else {
		startId = in.StartId
	}

	//zrscan
	resp, err := ssdb.Do("zrscan", Z_CLOSED_EVENT, startId, "", "", in.Limit)
	lwutil.CheckSsdbError(resp, err)
	resp = resp[1:]

	//multi_hget
	keyNum := len(resp) / 2
	cmds := make([]interface{}, keyNum+2)
	cmds[0] = "multi_hget"
	cmds[1] = H_EVENT
	for i := 0; i < keyNum; i++ {
		cmds[2+i] = resp[i*2]
	}
	resp, err = ssdb.Do(cmds...)
	resp = resp[1:]

	//out
	eventNum := len(resp) / 2
	out := make([]Event, eventNum)
	for i := 0; i < eventNum; i++ {
		err = json.Unmarshal([]byte(resp[i*2+1]), &out[i])
		lwutil.CheckError(err, "")
	}

	lwutil.WriteResponse(w, out)
}

func getEventResult(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//session
	_, err = findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		EventId uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	resp, err := ssdb.Do("hget", H_EVENT_RESULT, in.EventId)
	lwutil.CheckSsdbError(resp, err)

	out := resp[1]

	w.Write([]byte(out))
}

func playBegin(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		EventId uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//get event
	resp, err := ssdb.Do("hget", H_EVENT, in.EventId)
	lwutil.CheckSsdbError(resp, err)
	var event Event
	err = json.Unmarshal([]byte(resp[1]), &event)
	lwutil.CheckError(err, "")
	now := time.Now().Unix()
	if now < event.TimePoints[0] || now >= event.TimePoints[len(event.TimePoints)-1] {
		lwutil.SendError("err_time", "event not running")
	}

	//get event player record
	key := fmt.Sprintf("%d/%d", in.EventId, session.Userid)
	resp, err = ssdb.Do("hget", H_EVENT_PLAYER_RECORD, key)
	lwutil.CheckError(err, "")
	record := EventPlayerRecord{}
	if resp[0] == "ok" {
		err = json.Unmarshal([]byte(resp[1]), &record)
		lwutil.CheckError(err, "")
		record.Trys++
	} else {
		record.Trys = 1
		teamIdStr, err := getPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_TEAM)
		lwutil.CheckError(err, "err_player_team")
		teamId, err := strconv.ParseUint(teamIdStr, 10, 32)
		lwutil.CheckError(err, "")
		record.TeamId = uint32(teamId)
	}

	//gen secret
	record.Secret = lwutil.GenUUID()
	record.SecretExpire = time.Now().Unix() + TRY_EXPIRE_SECONDS

	//update record
	js, err := json.Marshal(record)
	resp, err = ssdb.Do("hset", H_EVENT_PLAYER_RECORD, key, js)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, record)
}

func playEnd(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		EventId uint64
		Secret  string
		Score   int32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//check event record
	recordKey := fmt.Sprintf("%d/%d", in.EventId, session.Userid)
	resp, err := ssdb.Do("hget", H_EVENT_PLAYER_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		lwutil.SendError("err_not_found", "event record not found")
	}

	record := EventPlayerRecord{}
	err = json.Unmarshal([]byte(resp[1]), &record)
	lwutil.CheckError(err, "")
	if record.Secret != in.Secret {
		lwutil.SendError("err_not_match", "Secret not match")
	}
	if time.Now().Unix() > record.SecretExpire {
		lwutil.SendError("err_expired", "secret expired")
	}

	//clear secret
	record.SecretExpire = 0

	//update score
	scoreUpdate := false
	if record.Trys == 1 || record.HighScore == 0 {
		record.HighScore = in.Score
		record.HighScoreTime = time.Now().Unix()
		scoreUpdate = true
	} else {
		if in.Score > record.HighScore {
			record.HighScore = in.Score
			scoreUpdate = true
		}
	}

	//save record
	jsRecord, err := json.Marshal(record)
	resp, err = ssdb.Do("hset", H_EVENT_PLAYER_RECORD, recordKey, jsRecord)
	lwutil.CheckSsdbError(resp, err)

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//event leaderboard
	eventLbLey := fmt.Sprintf("%s/%d", Z_EVENT_LEADERBOARD_PRE, in.EventId)
	if scoreUpdate {
		_, err = rc.Do("ZADD", eventLbLey, record.HighScore, session.Userid)
		lwutil.CheckError(err, "")
	}

	//get rank
	rc.Send("ZREVRANK", eventLbLey, session.Userid)
	rc.Send("ZCARD", eventLbLey)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	rank, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")
	rankNum, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")

	//team leaderboard
	teamLbKey := fmt.Sprintf("%s/%d/%d", Z_EVENT_TEAM_LEADERBOARD_PRE, in.EventId, record.TeamId)
	if scoreUpdate {
		_, err = rc.Do("ZADD", teamLbKey, record.HighScore, session.Userid)
		lwutil.CheckError(err, "")
	}

	//get rank in zone
	rc.Send("ZREVRANK", teamLbKey, session.Userid)
	rc.Send("ZCARD", teamLbKey)
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

// func beginMatch(w http.ResponseWriter, r *http.Request) {
// 	var err error
// 	lwutil.CheckMathod(r, "POST")

// 	//session
// 	session, err := findSession(w, r, nil)
// 	lwutil.CheckError(err, "err_auth")

// 	//ssdb
// 	ssdb, err := ssdbPool.Get()
// 	lwutil.CheckError(err, "")
// 	defer ssdb.Close()

// 	//get current match
// 	var match Match
// 	getCurrMatch(&match)

// 	//check match record exist
// 	record := MatchRecord{}

// 	recordKey := fmt.Sprintf("%d/%d", match.Id, session.Userid)
// 	resp, err := ssdb.Do("hget", H_EVENT_RECORD, recordKey)
// 	lwutil.CheckError(err, "")
// 	if resp[0] == "ok" {
// 		err = json.Unmarshal([]byte(resp[1]), &record)
// 		lwutil.CheckError(err, "")
// 		record.Trys++

// 		// //spend money
// 		// moneyStr := _getPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_MONEY)
// 		// money, err := strconv.ParseUint(moneyStr, 10, 32)
// 		// lwutil.CheckError(err, "")

// 		// if money < MATCH_COST_MONEY {
// 		// 	lwutil.SendError("err_money", "not enough money")
// 		// }
// 		// money -= MATCH_COST_MONEY
// 		// _setPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_MONEY, money)

// 	} else {
// 		record.Trys = 1
// 	}

// 	//gen match key
// 	record.MatchKey = lwutil.GenUUID()
// 	record.MatchKeyExpire = time.Now().Unix() + MATCH_EXPIRE_SECONDS

// 	//update record
// 	jsRecord, err := json.Marshal(record)
// 	resp, err = ssdb.Do("hset", H_EVENT_RECORD, recordKey, jsRecord)
// 	lwutil.CheckSsdbError(resp, err)

// 	//out
// 	lwutil.WriteResponse(w, record)
// }

// func endMatch(w http.ResponseWriter, r *http.Request) {
// 	var err error
// 	lwutil.CheckMathod(r, "POST")

// 	//session
// 	session, err := findSession(w, r, nil)
// 	lwutil.CheckError(err, "err_auth")

// 	//in
// 	var in struct {
// 		MatchKey string
// 		Score    int32
// 	}
// 	err = lwutil.DecodeRequestBody(r, &in)
// 	lwutil.CheckError(err, "err_decode_body")

// 	//ssdb
// 	ssdb, err := ssdbPool.Get()
// 	lwutil.CheckError(err, "")
// 	defer ssdb.Close()

// 	//get current match
// 	var match Match
// 	getCurrMatch(&match)

// 	//check match record
// 	record := MatchRecord{}

// 	recordKey := fmt.Sprintf("%d/%d", match.Id, session.Userid)
// 	resp, err := ssdb.Do("hget", H_EVENT_RECORD, recordKey)
// 	lwutil.CheckError(err, "")
// 	if resp[0] != "ok" {
// 		lwutil.SendError("err_not_found", "match record not found")
// 	}

// 	err = json.Unmarshal([]byte(resp[1]), &record)
// 	lwutil.CheckError(err, "")
// 	if record.MatchKey != in.MatchKey {
// 		lwutil.SendError("err_not_match", "matchKey not match")
// 	}
// 	if time.Now().Unix() > record.MatchKeyExpire {
// 		lwutil.SendError("err_expired", "matchKey expired")
// 	}

// 	//clear record
// 	record.MatchKeyExpire = 0

// 	//update score
// 	scoreUpdate := false
// 	if record.Trys == 1 {
// 		record.HighScore = in.Score
// 		scoreUpdate = true
// 	} else {
// 		if in.Score > record.HighScore {
// 			record.HighScore = in.Score
// 			scoreUpdate = true
// 		}
// 	}

// 	//save record
// 	jsRecord, err := json.Marshal(record)
// 	resp, err = ssdb.Do("hset", H_EVENT_RECORD, recordKey, jsRecord)
// 	lwutil.CheckSsdbError(resp, err)

// 	//redis
// 	rc := redisPool.Get()
// 	defer rc.Close()

// 	//leaderboard
// 	leaderBoardName := fmt.Sprintf("%s/%d", Z_EVENT_LEADERBOARD_PRE, match.Id)
// 	if scoreUpdate {
// 		// resp, err = ssdb.Do("zset", leaderBoardName, session.Userid, record.HighScore)
// 		// lwutil.CheckSsdbError(resp, err)
// 		_, err = rc.Do("ZADD", leaderBoardName, record.HighScore, session.Userid)
// 		lwutil.CheckError(err, "")
// 	}

// 	//get rank
// 	rc.Send("ZREVRANK", leaderBoardName, session.Userid)
// 	rc.Send("ZCARD", leaderBoardName)
// 	err = rc.Flush()
// 	lwutil.CheckError(err, "")
// 	rank, err := redis.Int(rc.Receive())
// 	lwutil.CheckError(err, "")
// 	rankNum, err := redis.Int(rc.Receive())
// 	lwutil.CheckError(err, "")

// 	//zone leaderboard
// 	zoneStr := _getPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_ZONE)
// 	zone, err := strconv.ParseUint(zoneStr, 10, 32)
// 	lwutil.CheckError(err, "")
// 	zoneLeaderboardKey := fmt.Sprintf("%s/%d/%d", Z_ZONE_LEADERBOARD_PRE, match.Id, zone)

// 	if scoreUpdate {
// 		_, err = rc.Do("ZADD", zoneLeaderboardKey, record.HighScore, session.Userid)
// 		lwutil.CheckError(err, "")
// 	}

// 	//get rank in zone
// 	rc.Send("ZREVRANK", zoneLeaderboardKey, session.Userid)
// 	rc.Send("ZCARD", zoneLeaderboardKey)
// 	err = rc.Flush()
// 	lwutil.CheckError(err, "")
// 	zoneRank, err := redis.Int(rc.Receive())
// 	lwutil.CheckError(err, "")
// 	zoneRankNum, err := redis.Int(rc.Receive())
// 	lwutil.CheckError(err, "")

// 	//out
// 	out := struct {
// 		Rank        uint32
// 		RankNum     uint32
// 		ZoneRank    uint32
// 		ZoneRankNum uint32
// 	}{
// 		uint32(rank + 1),
// 		uint32(rankNum),
// 		uint32(zoneRank + 1),
// 		uint32(zoneRankNum),
// 	}

// 	//out
// 	lwutil.WriteResponse(w, out)
// }

func matchFreePlay(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

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

	//check match
	resp, err := ssdb.Do("hexists", H_EVENT, in.MatchId)
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
	rc := redisPool.Get()
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

// func matchInfo(w http.ResponseWriter, r *http.Request) {
// 	var err error
// 	lwutil.CheckMathod(r, "POST")

// 	//session
// 	session, err := findSession(w, r, nil)
// 	lwutil.CheckError(err, "err_auth")

// 	//in
// 	var in struct {
// 		MatchId uint64
// 	}
// 	err = lwutil.DecodeRequestBody(r, &in)
// 	lwutil.CheckError(err, "err_decode_body")

// 	//ssdb
// 	ssdb, err := ssdbPool.Get()
// 	lwutil.CheckError(err, "")
// 	defer ssdb.Close()

// 	//get current match
// 	var match Match
// 	getCurrMatch(&match)

// 	if in.MatchId == 0 {
// 		in.MatchId = match.Id
// 	}

// 	//free play record
// 	freePlayRecord := FreePlayRecord{}
// 	recordKey := fmt.Sprintf("%d/%d", in.MatchId, session.Userid)
// 	resp, err := ssdb.Do("hget", H_FREEPLAY_RECORD, recordKey)
// 	lwutil.CheckError(err, "")
// 	if resp[0] != "ok" {
// 		freePlayRecord.HighScore = 0
// 		freePlayRecord.Trys = 0
// 	} else {
// 		err = json.Unmarshal([]byte(resp[1]), &freePlayRecord)
// 		lwutil.CheckError(err, "")
// 	}

// 	//match record
// 	matchRecord := MatchRecord{}
// 	recordKey = fmt.Sprintf("%d/%d", in.MatchId, session.Userid)
// 	resp, err = ssdb.Do("hget", H_EVENT_RECORD, recordKey)
// 	lwutil.CheckError(err, "")
// 	if resp[0] != "ok" {
// 		matchRecord.HighScore = 0
// 		matchRecord.Trys = 0
// 	} else {
// 		err = json.Unmarshal([]byte(resp[1]), &matchRecord)
// 		lwutil.CheckError(err, "")
// 	}

// 	//redis
// 	rc := redisPool.Get()
// 	defer rc.Close()

// 	//leaderboard
// 	freePlayLeaderBoardName := fmt.Sprintf("%s/%d", Z_FREEPLAY_LEADERBOARD_PRE, in.MatchId)
// 	matchLeaderBoardName := fmt.Sprintf("%s/%d", Z_EVENT_LEADERBOARD_PRE, in.MatchId)

// 	//get rank
// 	rc.Send("ZREVRANK", freePlayLeaderBoardName, session.Userid)
// 	rc.Send("ZCARD", freePlayLeaderBoardName)
// 	rc.Send("ZREVRANK", matchLeaderBoardName, session.Userid)
// 	rc.Send("ZCARD", matchLeaderBoardName)
// 	err = rc.Flush()
// 	lwutil.CheckError(err, "")

// 	fRank, err := _redisInt(rc.Receive())
// 	lwutil.CheckError(err, "")
// 	fRankNum, err := _redisInt(rc.Receive())
// 	lwutil.CheckError(err, "")
// 	mRank, err := _redisInt(rc.Receive())
// 	lwutil.CheckError(err, "")
// 	mRankNum, err := _redisInt(rc.Receive())
// 	lwutil.CheckError(err, "")

// 	//get rank in zone
// 	zoneStr := _getPlayerInfoField(ssdb, session.Userid, FLD_PLAYER_ZONE)
// 	zone, err := strconv.ParseUint(zoneStr, 10, 32)
// 	lwutil.CheckError(err, "")
// 	zoneLeaderboardKey := fmt.Sprintf("%s/%d/%d", Z_ZONE_LEADERBOARD_PRE, match.Id, zone)

// 	rc.Send("ZREVRANK", zoneLeaderboardKey, session.Userid)
// 	rc.Send("ZCARD", zoneLeaderboardKey)
// 	err = rc.Flush()
// 	lwutil.CheckError(err, "")
// 	zoneRank, err := redis.Int(rc.Receive())
// 	lwutil.CheckError(err, "")
// 	zoneRankNum, err := redis.Int(rc.Receive())
// 	lwutil.CheckError(err, "")

// 	//out
// 	out := struct {
// 		FreePlayRank      uint32
// 		FreePlayRankNum   uint32
// 		FreePlayTrys      uint32
// 		FreePlayHighScore int32
// 		MatchRank         uint32
// 		MatchRankNum      uint32
// 		©rys         uint32
// 		MatchHighScore    int32
// 		ZoneRank          uint32
// 		ZoneRankNum       uint32
// 	}{
// 		uint32(fRank + 1),
// 		uint32(fRankNum),
// 		freePlayRecord.Trys,
// 		freePlayRecord.HighScore,
// 		uint32(mRank + 1),
// 		uint32(mRankNum),
// 		matchRecord.Trys,
// 		matchRecord.HighScore,
// 		uint32(zoneRank + 1),
// 		uint32(zoneRankNum),
// 	}

// 	lwutil.WriteResponse(w, out)
// }

func getTopTen(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//in
	var in struct {
		EventId  uint64
		RoundIdx uint32
		TeamId   uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	key := fmt.Sprintf("%d/%d/%d", in.EventId, in.RoundIdx, in.TeamId)
	resp, err := ssdb.Do("hget", H_EVENT_ROUND_TEAM_TOPTEN, key)
	lwutil.CheckSsdbError(resp, err)

	//out
	out := struct {
		EventId     uint64
		RoundIdx    uint32
		TeamId      uint64
		GameRecords []GameRecord
	}{
		in.EventId,
		in.RoundIdx,
		in.TeamId,
		make([]GameRecord, 0, 10),
	}
	err = json.Unmarshal([]byte(resp[1]), &out.GameRecords)
	lwutil.CheckError(err, "")
	lwutil.WriteResponse(w, out)
}

func regMatch() {
	http.Handle("/match/newEvent", lwutil.ReqHandler(newEvent))
	http.Handle("/match/delEvent", lwutil.ReqHandler(delEvent))
	http.Handle("/match/listEvent", lwutil.ReqHandler(listEvent))
	http.Handle("/match/listClosedEvent", lwutil.ReqHandler(listClosedEvent))
	http.Handle("/match/getEventResult", lwutil.ReqHandler(getEventResult))
	http.Handle("/match/playBegin", lwutil.ReqHandler(playBegin))
	http.Handle("/match/playEnd", lwutil.ReqHandler(playEnd))
	http.Handle("/match/freePlay", lwutil.ReqHandler(matchFreePlay))
	http.Handle("/match/topTen", lwutil.ReqHandler(getTopTen))
	// http.Handle("/match/info", lwutil.ReqHandler(matchInfo))
}
