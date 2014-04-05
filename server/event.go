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
	"strings"
	"time"
)

func init() {
	glog.Info("match init")
}

const (
	H_EVENT                      = "H_EVENT"
	Z_EVENT                      = "Z_EVENT"
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
	Type            string //"PERSONAL_RANK", "TEAM_CHAMPIONSHIP"
	Id              uint64
	PackId          uint64
	BeginTime       int64
	EndTime         int64
	BeginTimeString string
	EndTimeString   string
	IsFinished      bool
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
	PlayerId   uint64
	PlayerName string
	Score      int32
	Time       int64
}

type EventPlayerRecord struct {
	PlayerName    string
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
	event.IsFinished = false

	//fill TimePoints
	now := time.Now().Unix()

	t, err := time.ParseInLocation("2006-01-02T15:04", event.BeginTimeString, time.Local)
	lwutil.CheckError(err, "")
	event.BeginTime = t.Unix()
	if event.BeginTime < now {
		lwutil.SendError("err_time", "BeginTime must larger than now")
	}

	t, err = time.ParseInLocation("2006-01-02T15:04", event.EndTimeString, time.Local)
	lwutil.CheckError(err, "")
	event.EndTime = t.Unix()
	if event.EndTime < now {
		lwutil.SendError("err_time", "EndTime must larger than now")
	}

	//check timePotins
	if event.BeginTime >= event.EndTime {
		lwutil.SendError("err_time", "event.BeginTime >= event.EndTime")
	}

	//check pack
	resp, err := ssdb.Do("hexists", H_PACK, event.PackId)
	lwutil.CheckSsdbError(resp, err)
	if resp[1] == "0" {
		lwutil.SendError("err_pack", "pack not exist")
	}

	//gen serial
	event.Id = GenSerial(ssdb, EVENT_SERIAL)

	//save to ssdb
	js, err := json.Marshal(event)
	resp, err = ssdb.Do("hset", H_EVENT, event.Id, js)
	lwutil.CheckSsdbError(resp, err)

	resp, err = ssdb.Do("zset", Z_EVENT, event.Id, event.EndTime)
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

func getMyResult(w http.ResponseWriter, r *http.Request) {
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

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//get rank
	eventLbLey := fmt.Sprintf("%s/%d", Z_EVENT_LEADERBOARD_PRE, in.EventId)
	rc.Send("ZREVRANK", eventLbLey, session.Userid)
	rc.Send("ZCARD", eventLbLey)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	rank, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")
	rankNum, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")

	//
	recordKey := fmt.Sprintf("%d/%d", in.EventId, session.Userid)
	resp, err := ssdb.Do("hget", H_EVENT_PLAYER_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		lwutil.SendError("err_not_played", fmt.Sprintf("event not played: recordKey=%s", recordKey))
	}

	record := EventPlayerRecord{}
	err = json.Unmarshal([]byte(resp[1]), &record)
	lwutil.CheckError(err, "")

	//team leaderboard
	teamLbKey := fmt.Sprintf("%s/%d/%d", Z_EVENT_TEAM_LEADERBOARD_PRE, in.EventId, record.TeamId)

	//get rank in team
	rc.Send("ZREVRANK", teamLbKey, session.Userid)
	rc.Send("ZCARD", teamLbKey)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	teamRank, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")
	teamRankNum, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")

	//out
	out := struct {
		HighScore   int32
		TeamId      uint32
		Trys        uint32
		Rank        uint32
		RankNum     uint32
		TeamRank    uint32
		TeamRankNum uint32
	}{
		record.HighScore,
		record.TeamId,
		record.Trys,
		uint32(rank + 1),
		uint32(rankNum),
		uint32(teamRank + 1),
		uint32(teamRankNum),
	}

	//out
	lwutil.WriteResponse(w, out)
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
	if now < event.BeginTime || now >= event.EndTime {
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

		var playerInfo PlayerInfo
		_getPlayerInfo(ssdb, session, &playerInfo)

		teamId := playerInfo.TeamId
		lwutil.CheckError(err, "")
		if TEAM_MAP[teamId] == false {
			lwutil.SendError("err_team", fmt.Sprintf("invalid team id: %d", teamId))
		}
		record.TeamId = teamId
		record.PlayerName = playerInfo.Name
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

	//get rank in team
	rc.Send("ZREVRANK", teamLbKey, session.Userid)
	rc.Send("ZCARD", teamLbKey)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	teamRank, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")
	teamRankNum, err := redis.Int(rc.Receive())
	lwutil.CheckError(err, "")

	//out
	out := struct {
		Rank        uint32
		RankNum     uint32
		TeamRank    uint32
		TeamRankNum uint32
	}{
		uint32(rank + 1),
		uint32(rankNum),
		uint32(teamRank + 1),
		uint32(teamRankNum),
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
		TeamIds  []uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	teamNum := len(in.TeamIds)
	if teamNum == 0 {
		lwutil.SendError("err_decode_body", "need TeamIds []uint64")
	}
	if teamNum > 5 {
		in.TeamIds = in.TeamIds[:5]
	}

	cmds := []interface{}{
		"multi_hget",
		H_EVENT_ROUND_TEAM_TOPTEN,
	}
	for _, v := range in.TeamIds {
		key := fmt.Sprintf("%d/%d/%d", in.EventId, in.RoundIdx, v)
		cmds = append(cmds, key)
	}

	resp, err := ssdb.Do(cmds...)
	lwutil.CheckSsdbError(resp, err)

	//out
	resp = resp[1:]
	out := struct {
		EventId  uint64
		RoundIdx uint32
		Top10s   []interface{}
	}{
		in.EventId,
		in.RoundIdx,
		make([]interface{}, 0, teamNum),
	}
	for i := 0; i < len(resp)/2; i++ {
		key := resp[i*2]
		teamIdStr := strings.Split(key, "/")[2]
		teamIdRaw, err := strconv.ParseUint(teamIdStr, 10, 32)
		lwutil.CheckError(err, "")
		elem := struct {
			TeamId      uint32
			GameRecords []GameRecord
		}{
			uint32(teamIdRaw),
			make([]GameRecord, 0, 10),
		}
		err = json.Unmarshal([]byte(resp[i*2+1]), &elem.GameRecords)
		lwutil.CheckError(err, resp[i*2+1])
		out.Top10s = append(out.Top10s, elem)
	}

	lwutil.WriteResponse(w, out)
}

func getRanks(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//in
	var in struct {
		EventId uint64
		Offset  uint32
		Limit   uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	if in.Limit > 20 {
		in.Limit = 20
	}

	//check event id
	resp, err := ssdb.Do("hget", H_EVENT, in.EventId)
	lwutil.CheckSsdbError(resp, err)
	var event Event
	err = json.Unmarshal([]byte(resp[1]), &event)
	lwutil.CheckError(err, "")
	if event.IsFinished {
		lwutil.SendError("err_event_finished", fmt.Sprintf("eventId=%d", in.EventId))
	}

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//get rank
	eventLbLey := fmt.Sprintf("%s/%d", Z_EVENT_LEADERBOARD_PRE, in.EventId)
	values, err := redis.Values(rc.Do("ZREVRANGE", eventLbLey, in.Offset, in.Offset+in.Limit-1, "WITHSCORES"))
	lwutil.CheckError(err, "")

	num := len(values) / 2
	userIds := make([]uint64, num)
	scores := make([]int32, num)
	for i, v := range values {
		if i%2 == 0 {
			userIds[i/2], err = redisUint64(v, nil)
			lwutil.CheckError(err, "")
		} else {
			scores[i/2], err = redisInt32(v, nil)
			lwutil.CheckError(err, "")
		}
	}

	out := struct {
		EventId uint64
		UserIds []uint64
		Scores  []int32
	}{
		in.EventId,
		userIds,
		scores,
	}

	lwutil.WriteResponse(w, out)
}

func regMatch() {
	http.Handle("/event/new", lwutil.ReqHandler(newEvent))
	http.Handle("/event/del", lwutil.ReqHandler(delEvent))
	http.Handle("/event/list", lwutil.ReqHandler(listEvent))
	http.Handle("/event/getResult", lwutil.ReqHandler(getEventResult))
	http.Handle("/event/getMyResult", lwutil.ReqHandler(getMyResult))
	http.Handle("/event/playBegin", lwutil.ReqHandler(playBegin))
	http.Handle("/event/playEnd", lwutil.ReqHandler(playEnd))
	http.Handle("/event/topTen", lwutil.ReqHandler(getTopTen))
	http.Handle("/event/getRanks", lwutil.ReqHandler(getRanks))
}
