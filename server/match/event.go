package main

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"github.com/garyburd/redigo/redis"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	//. "github.com/qiniu/api/conf"
	//"github.com/qiniu/api/rs"
	// "io/ioutil"
	"math"
	"math/rand"
	"net/http"
	"strconv"
	"time"
)

const (
	H_EVENT                     = "H_EVENT"
	Z_EVENT                     = "Z_EVENT"
	H_EVENT_PLAYER_RECORD       = "H_EVENT_PLAYER_RECORD"
	RDS_Z_EVENT_LEADERBOARD_PRE = "RDS_Z_EVENT_LEADERBOARD_PRE"
	H_EVENT_RANK                = "H_EVENT_RANK" //key:(uint32)rank value:(uint64)userId
	EVENT_SERIAL                = "EVENT_SERIAL"
	TRY_COST_MONEY              = 100
	TRY_EXPIRE_SECONDS          = 600
	TEAM_CHAMPIONSHIP_ROUND_NUM = 6
	H_EVENT_TEAM_SCORE          = "H_EVENT_TEAM_SCORE"   //subkey:eventId value:map[teamName:string]score:int
	H_EVENT_BETTING_POOL        = "H_EVENT_BETTING_POOL" //subkey:eventId value:map[teamName:string]money:int64
	INIT_GAME_COIN_NUM          = 3
)

var (
	challageRewards = []int{100, 50, 50} //gold, silver, bronze
)

func makeRedisLeaderboardKey(evnetId uint64) string {
	return fmt.Sprintf("%s/%d", RDS_Z_EVENT_LEADERBOARD_PRE, evnetId)
}

func makeHashEventRankKey(eventId uint64) string {
	return fmt.Sprintf("%s/%d", H_EVENT_RANK, eventId)
}

func makeEventPlayerRecordSubkey(eventId uint64, userId uint64) string {
	key := fmt.Sprintf("%d/%d", eventId, userId)
	return key
}

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

	TEAM_NAMES              = []string{"安徽", "澳门", "北京", "重庆", "福建", "甘肃", "广东", "广西", "贵州", "海南", "河北", "黑龙江", "河南", "湖北", "湖南", "江苏", "江西", "吉林", "辽宁", "内蒙古", "宁夏", "青海", "陕西", "山东", "上海", "山西", "四川", "台湾", "天津", "香港", "新疆", "西藏", "云南", "浙江"}
	EVENT_INIT_BETTING_POOL = map[string]int64{}
	INIT_BET_MONEY          = int64(10000)
)

func init() {
	glog.Info("match init")
	for _, teamName := range TEAM_NAMES {
		EVENT_INIT_BETTING_POOL[teamName] = INIT_BET_MONEY
	}
	fmt.Printf("%v", EVENT_INIT_BETTING_POOL)
}

type Event struct {
	Type            string //"PERSONAL_RANK", "TEAM_CHAMPIONSHIP"
	Id              uint64
	PackId          uint64
	BeginTime       int64
	EndTime         int64
	BeginTimeString string
	EndTimeString   string
	HasResult       bool
	Thumb           string
	SliderNum       uint32
	ChallengeSecs   []int
}

type EventPlayerRecord struct {
	PlayerName         string
	TeamName           string
	Secret             string
	SecretExpire       int64
	Trys               uint32
	HighScore          int32
	HighScoreTime      int64
	FinalRank          uint32
	GravatarKey        string
	CustomAvartarKey   string
	Gender             int
	GameCoinNum        int
	ChallangeHighScore int
}

func (record *EventPlayerRecord) init(playerInfo *PlayerInfo) {
	record.Trys = 0
	record.PlayerName = playerInfo.NickName
	record.TeamName = playerInfo.TeamName
	record.GravatarKey = playerInfo.GravatarKey
	record.CustomAvartarKey = playerInfo.CustomAvatarKey
	record.GameCoinNum = INIT_GAME_COIN_NUM
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
	event.HasResult = false

	//fill TimePoints
	now := lwutil.GetRedisTimeUnix()

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

	//sliderNum
	if event.SliderNum == 0 {
		event.SliderNum = 6
	} else if event.SliderNum > 10 {
		event.SliderNum = 10
	}

	// //check pack
	// resp, err := ssdb.Do("hexists", H_PACK, event.PackId)
	// lwutil.CheckSsdbError(resp, err)
	// if resp[1] == "0" {
	// 	lwutil.SendError("err_pack", "pack not exist")
	// }

	//get pack
	resp, err := ssdb.Do("hget", H_PACK, event.PackId)
	lwutil.CheckSsdbError(resp, err)
	var pack Pack
	err = json.Unmarshal([]byte(resp[1]), &pack)
	lwutil.CheckError(err, "")
	event.Thumb = pack.Thumb

	//gen serial
	event.Id = GenSerial(ssdb, EVENT_SERIAL)

	//save to ssdb
	js, err := json.Marshal(event)
	lwutil.CheckError(err, "")
	resp, err = ssdb.Do("hset", H_EVENT, event.Id, js)
	lwutil.CheckSsdbError(resp, err)

	//resp, err = ssdb.Do("zset", Z_EVENT, event.Id, event.EndTime)
	resp, err = ssdb.Do("zset", Z_EVENT, event.Id, event.Id)
	lwutil.CheckSsdbError(resp, err)

	//init betting pool
	js, err = json.Marshal(EVENT_INIT_BETTING_POOL)
	lwutil.CheckError(err, "")
	resp, err = ssdb.Do("hset", H_EVENT_BETTING_POOL, event.Id, js)
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
	if in.Limit > 50 {
		in.Limit = 50
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
	if len(resp) == 0 {
		lwutil.SendError("err_not_found", "")
	}

	//multi_hget
	keyNum := len(resp) / 2
	cmds := make([]interface{}, keyNum+2)
	cmds[0] = "multi_hget"
	cmds[1] = H_EVENT
	for i := 0; i < keyNum; i++ {
		cmds[2+i] = resp[i*2]
	}
	resp, err = ssdb.Do(cmds...)
	lwutil.CheckSsdbError(resp, err)
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

func getEvent(w http.ResponseWriter, r *http.Request) {
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
		EventId uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//hget
	resp, err := ssdb.Do("hget", H_EVENT, in.EventId)
	lwutil.CheckSsdbError(resp, err)

	//out
	out := Event{}
	err = json.Unmarshal([]byte(resp[1]), &out)
	lwutil.CheckError(err, "")

	lwutil.WriteResponse(w, out)
}

func getUserPlay(w http.ResponseWriter, r *http.Request) {
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
		UserId  uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	if in.UserId == 0 {
		in.UserId = session.Userid
	}

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//get rank
	eventLbLey := makeRedisLeaderboardKey(in.EventId)
	rc.Send("ZREVRANK", eventLbLey, in.UserId)
	rc.Send("ZCARD", eventLbLey)
	err = rc.Flush()
	lwutil.CheckError(err, "")
	rank, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")
	rankNum, err := _redisInt(rc.Receive())
	lwutil.CheckError(err, "")

	//
	type Out struct {
		HighScore          int32
		Trys               uint32
		Rank               uint32
		RankNum            uint32
		GameCoinNum        int
		ChallangeHighScore int
	}

	//
	recordKey := makeEventPlayerRecordSubkey(in.EventId, in.UserId)
	resp, err := ssdb.Do("hget", H_EVENT_PLAYER_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		out := Out{}
		out.GameCoinNum = INIT_GAME_COIN_NUM
		lwutil.WriteResponse(w, out)
		return
	}

	record := EventPlayerRecord{}
	err = json.Unmarshal([]byte(resp[1]), &record)
	lwutil.CheckError(err, "")

	//out
	out := Out{
		record.HighScore,
		record.Trys,
		uint32(rank + 1),
		uint32(rankNum),
		record.GameCoinNum,
		record.ChallangeHighScore,
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
	now := lwutil.GetRedisTimeUnix()

	if now < event.BeginTime || now >= event.EndTime || event.HasResult {
		lwutil.SendError("err_time", "event not running")
	}

	//get event player record
	key := makeEventPlayerRecordSubkey(in.EventId, session.Userid)
	resp, err = ssdb.Do("hget", H_EVENT_PLAYER_RECORD, key)
	lwutil.CheckError(err, "")
	record := EventPlayerRecord{}
	if resp[0] == "ok" {
		err = json.Unmarshal([]byte(resp[1]), &record)
		lwutil.CheckError(err, "")
		record.Trys++

		if record.GameCoinNum <= 0 {
			lwutil.SendError("err_game_coin", "")
		}
		record.GameCoinNum--
	} else {
		var playerInfo PlayerInfo
		getPlayer(ssdb, session.Userid, &playerInfo)
		lwutil.CheckError(err, "")
		record.init(&playerInfo)
		record.GameCoinNum--
		record.Trys++
	}

	//gen secret
	record.Secret = lwutil.GenUUID()
	record.SecretExpire = lwutil.GetRedisTimeUnix() + TRY_EXPIRE_SECONDS

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
		EventId  uint64
		Secret   string
		Score    int32
		Checksum string
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//checksum
	checksum := fmt.Sprintf("%s+%d9d7a", in.Secret, in.Score*in.Score)
	hasher := sha1.New()
	hasher.Write([]byte(checksum))
	checksum = hex.EncodeToString(hasher.Sum(nil))
	if in.Checksum != checksum {
		lwutil.SendError("err_checksum", checksum)
	}

	//check event record
	now := lwutil.GetRedisTimeUnix()
	recordKey := makeEventPlayerRecordSubkey(in.EventId, session.Userid)
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
	if now > record.SecretExpire {
		lwutil.SendError("err_expired", "secret expired")
	}

	//clear secret
	record.SecretExpire = 0

	//update score
	scoreUpdate := false
	if record.Trys == 1 || record.HighScore == 0 {
		record.HighScore = in.Score
		record.HighScoreTime = now
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
	eventLbLey := makeRedisLeaderboardKey(in.EventId)
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

	//recaculate team score
	if scoreUpdate && rank <= 100 {
		resp, err := ssdb.Do("hget", H_EVENT, in.EventId)
		lwutil.CheckSsdbError(resp, err)
		var event Event
		err = json.Unmarshal([]byte(resp[1]), &event)
		lwutil.CheckError(err, "")
		if event.HasResult == false {
			//redis
			rc := redisPool.Get()
			defer rc.Close()

			//get ranks from redis
			eventLbLey := makeRedisLeaderboardKey(in.EventId)
			values, err := redis.Values(rc.Do("ZREVRANGE", eventLbLey, 0, 99))
			lwutil.CheckError(err, "")

			num := len(values)
			userIds := make([]uint64, 0, 100)
			if num > 0 {
				cmds := make([]interface{}, 0, num+2)
				cmds = append(cmds, "multi_hget")
				cmds = append(cmds, H_EVENT_PLAYER_RECORD)

				for i := 0; i < num; i++ {
					userId, err := redisUint64(values[i], nil)
					lwutil.CheckError(err, "")
					userIds = append(userIds, userId)
					recordKey := makeEventPlayerRecordSubkey(in.EventId, userId)
					cmds = append(cmds, recordKey)
				}

				//get event player record
				resp, err = ssdb.Do(cmds...)
				lwutil.CheckSsdbError(resp, err)
				resp = resp[1:]

				if num*2 != len(resp) {
					lwutil.SendError("err_data_missing", "")
				}
				var record EventPlayerRecord
				scoreMap := make(map[string]uint32)
				for i := range userIds {
					err = json.Unmarshal([]byte(resp[i*2+1]), &record)
					lwutil.CheckError(err, "")
					score := scoreMap[record.TeamName]
					score += (uint32)(100 - i)
					if i == 0 {
						score += 50
					}
					scoreMap[record.TeamName] = score
				}
				// glog.Info(scoreMap)

				js, err := json.Marshal(scoreMap)
				lwutil.CheckError(err, "")

				resp, err := ssdb.Do("hset", H_EVENT_TEAM_SCORE, in.EventId, js)
				// glog.Info(string(js))
				lwutil.CheckSsdbError(resp, err)
			}
		}
	}

	//out
	out := struct {
		Rank    uint32
		RankNum uint32
	}{
		uint32(rank + 1),
		uint32(rankNum),
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

	if in.Limit > 30 {
		in.Limit = 30
	}

	//check event id
	resp, err := ssdb.Do("hget", H_EVENT, in.EventId)
	lwutil.CheckSsdbError(resp, err)
	var event Event
	err = json.Unmarshal([]byte(resp[1]), &event)
	lwutil.CheckError(err, "")

	//RankInfo
	type RankInfo struct {
		Rank        uint32
		UserId      uint64
		NickName    string
		TeamName    string
		GravatarKey string
		Score       int32
		Time        int64
		Trys        uint32
	}

	type Out struct {
		EventId uint64
		Ranks   []RankInfo
	}

	//get ranks
	var ranks []RankInfo

	if event.HasResult {
		cmds := make([]interface{}, in.Limit+2)
		cmds[0] = "multi_hget"
		cmds[1] = makeHashEventRankKey(event.Id)
		for i := uint32(0); i < in.Limit; i++ {
			rank := i + in.Offset + 1
			cmds[i+2] = rank
		}

		resp, err := ssdb.Do(cmds...)
		lwutil.CheckSsdbError(resp, err)
		resp = resp[1:]

		num := len(resp) / 2
		ranks = make([]RankInfo, num)

		for i := 0; i < num; i++ {
			rank, err := strconv.ParseUint(resp[i*2], 10, 32)
			lwutil.CheckError(err, "")
			ranks[i].Rank = uint32(rank)
			ranks[i].UserId, err = strconv.ParseUint(resp[i*2+1], 10, 64)
			lwutil.CheckError(err, "")
		}

	} else {
		//redis
		rc := redisPool.Get()
		defer rc.Close()

		//get ranks from redis
		eventLbLey := makeRedisLeaderboardKey(in.EventId)
		values, err := redis.Values(rc.Do("ZREVRANGE", eventLbLey, in.Offset, in.Offset+in.Limit-1))
		lwutil.CheckError(err, "")

		num := len(values)
		if num > 0 {
			ranks = make([]RankInfo, num)

			currRank := in.Offset + 1
			for i := 0; i < num; i++ {
				ranks[i].Rank = currRank
				currRank++
				ranks[i].UserId, err = redisUint64(values[i], nil)
				lwutil.CheckError(err, "")
			}
		}
	}

	num := len(ranks)
	if num == 0 {
		out := Out{
			in.EventId,
			[]RankInfo{},
		}
		lwutil.WriteResponse(w, out)
		return
	}

	//get event player record
	cmds := make([]interface{}, 0, num+2)
	cmds = append(cmds, "multi_hget")
	cmds = append(cmds, H_EVENT_PLAYER_RECORD)
	for _, rank := range ranks {
		recordKey := makeEventPlayerRecordSubkey(in.EventId, rank.UserId)
		cmds = append(cmds, recordKey)
	}
	resp, err = ssdb.Do(cmds...)
	lwutil.CheckSsdbError(resp, err)
	resp = resp[1:]

	if num*2 != len(resp) {
		lwutil.SendError("err_data_missing", "")
	}
	var record EventPlayerRecord
	for i := range ranks {
		err = json.Unmarshal([]byte(resp[i*2+1]), &record)
		lwutil.CheckError(err, "")
		ranks[i].Score = record.HighScore
		ranks[i].NickName = record.PlayerName
		ranks[i].Time = record.HighScoreTime
		ranks[i].Trys = record.Trys
		ranks[i].TeamName = record.TeamName
		ranks[i].GravatarKey = record.GravatarKey
	}

	//out
	out := Out{
		in.EventId,
		ranks,
	}

	lwutil.WriteResponse(w, out)
}

func getBetInfos(w http.ResponseWriter, r *http.Request) {

}

func submitChallangeScore(w http.ResponseWriter, r *http.Request) {
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
		EventId  uint64
		Score    int
		Checksum string
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//checksum
	checksum := fmt.Sprintf("zzzz%d9d7a", in.Score*in.Score)
	hasher := sha1.New()
	hasher.Write([]byte(checksum))
	checksum = hex.EncodeToString(hasher.Sum(nil))
	if in.Checksum != checksum {
		lwutil.SendError("err_checksum", checksum)
	}

	//check event record
	recordKey := makeEventPlayerRecordSubkey(in.EventId, session.Userid)
	resp, err := ssdb.Do("hget", H_EVENT_PLAYER_RECORD, recordKey)
	lwutil.CheckError(err, "")

	record := EventPlayerRecord{}
	if resp[0] != "ok" {
		var playerInfo PlayerInfo
		getPlayer(ssdb, session.Userid, &playerInfo)
		lwutil.CheckError(err, "")
		record.init(&playerInfo)
	} else {
		err = json.Unmarshal([]byte(resp[1]), &record)
		lwutil.CheckError(err, "")
	}

	//update score
	scoreUpdate := false
	reward := 0
	oldScore := record.ChallangeHighScore
	if record.ChallangeHighScore == 0 {
		record.ChallangeHighScore = in.Score
		scoreUpdate = true
	} else {
		if in.Score > record.ChallangeHighScore {
			record.ChallangeHighScore = in.Score
			scoreUpdate = true
		}
	}

	//
	if scoreUpdate {
		if oldScore == 0 {
			oldScore = math.MinInt32
		}

		//get event
		resp, err := ssdb.Do("hget", H_EVENT, in.EventId)
		lwutil.CheckSsdbError(resp, err)

		event := Event{}
		err = json.Unmarshal([]byte(resp[1]), &event)
		lwutil.CheckError(err, "")

		for i, sec := range event.ChallengeSecs {
			refScore := -int(sec * 1000)
			if refScore > oldScore && refScore <= in.Score {
				reward += challageRewards[i]
			}
		}
	}

	//save record
	if scoreUpdate {
		jsRecord, err := json.Marshal(record)
		resp, err = ssdb.Do("hset", H_EVENT_PLAYER_RECORD, recordKey, jsRecord)
		lwutil.CheckSsdbError(resp, err)
	}

	//add money
	newMoney := 0
	if reward > 0 {
		var playerInfo PlayerInfo
		getPlayer(ssdb, session.Userid, &playerInfo)
		playerInfo.Money += reward
		savePlayer(ssdb, session.Userid, &playerInfo)
		newMoney = playerInfo.Money
	}

	//out
	out := struct {
		Reward   int
		NewMoney int
	}{
		reward,
		newMoney,
	}

	//out
	lwutil.WriteResponse(w, out)
}

func regMatch() {
	http.Handle("/event/new", lwutil.ReqHandler(newEvent))
	http.Handle("/event/del", lwutil.ReqHandler(delEvent))
	http.Handle("/event/list", lwutil.ReqHandler(listEvent))
	http.Handle("/event/get", lwutil.ReqHandler(getEvent))
	http.Handle("/event/getUserPlay", lwutil.ReqHandler(getUserPlay))
	http.Handle("/event/playBegin", lwutil.ReqHandler(playBegin))
	http.Handle("/event/playEnd", lwutil.ReqHandler(playEnd))
	http.Handle("/event/getRanks", lwutil.ReqHandler(getRanks))
	http.Handle("/event/getBetInfos", lwutil.ReqHandler(getBetInfos))
	http.Handle("/event/submitChallangeScore", lwutil.ReqHandler(submitChallangeScore))

}
