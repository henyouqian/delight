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
	H_EVENT                     = "H_EVENT"
	Z_EVENT                     = "Z_EVENT"
	H_EVENT_PLAYER_RECORD       = "H_EVENT_PLAYER_RECORD"
	RDS_Z_EVENT_LEADERBOARD_PRE = "RDS_Z_EVENT_LEADERBOARD_PRE"
	H_EVENT_RANK                = "H_EVENT_RANK" //key:(uint32)rank value:(uint64)userId
	EVENT_SERIAL                = "EVENT_SERIAL"
	TRY_COST_MONEY              = 100
	TRY_EXPIRE_SECONDS          = 600
	TEAM_CHAMPIONSHIP_ROUND_NUM = 6
	H_EVENT_TEAM_SCORE          = "H_EVENT_TEAM_SCORE" //key:evnetId value:map[string(teamName)]uint32(score)
)

func makeRedisLeaderboardKey(evnetId uint64) string {
	return fmt.Sprintf("%s/%d", RDS_Z_EVENT_LEADERBOARD_PRE, evnetId)
}

func makeHashEventRankKey(eventId uint64) string {
	return fmt.Sprintf("%s/%d", H_EVENT_RANK, eventId)
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
)

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
}

type EventPlayerRecord struct {
	PlayerName       string
	TeamName         string
	Secret           string
	SecretExpire     int64
	Trys             uint32
	HighScore        int32
	HighScoreTime    int64
	FinalRank        uint32
	GravatarKey      string
	CustomAvartarKey string
	Gender           int
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
	resp, err = ssdb.Do("hset", H_EVENT, event.Id, js)
	lwutil.CheckSsdbError(resp, err)

	//resp, err = ssdb.Do("zset", Z_EVENT, event.Id, event.EndTime)
	resp, err = ssdb.Do("zset", Z_EVENT, event.Id, event.Id)
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
		HighScore int32
		Trys      uint32
		Rank      uint32
		RankNum   uint32
	}

	//
	recordKey := fmt.Sprintf("%d/%d", in.EventId, in.UserId)
	resp, err := ssdb.Do("hget", H_EVENT_PLAYER_RECORD, recordKey)
	lwutil.CheckError(err, "")
	if resp[0] != "ok" {
		out := Out{
			int32(0),
			uint32(0),
			uint32(0),
			uint32(0),
		}
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
	if now < event.BeginTime || now >= event.EndTime || event.HasResult {
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
		lwutil.CheckError(err, "")
		record.PlayerName = playerInfo.NickName
		record.TeamName = playerInfo.TeamName
		record.GravatarKey = playerInfo.GravatarKey
		record.CustomAvartarKey = playerInfo.CustomAvatarKey
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
					recordKey := fmt.Sprintf("%d/%d", in.EventId, userId)
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
				glog.Info(scoreMap)

				js, err := json.Marshal(scoreMap)
				lwutil.CheckError(err, "")

				resp, err := ssdb.Do("hset", H_EVENT_TEAM_SCORE, in.EventId, js)
				glog.Info(string(js))
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
		recordKey := fmt.Sprintf("%d/%d", in.EventId, rank.UserId)
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

func getActivities(w http.ResponseWriter, r *http.Request) {
	//var err error
	lwutil.CheckMathod(r, "POST")

	comments := []Comment{
		Comment{45323, 1, 1, "Ezra", "3", "北京", "The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.\n\nThe quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog.The quick brown fox jumps over the lazy dog."},
		Comment{5424, 2, 1, "brian.clear", "4", "美国", `label.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17];`},
		Comment{2452, 44, 1, "Alladinian", "6", "上海", "Try this!"},
		Comment{4562435, 345, 1, "Proveme007", "7", "福建", "gogogo!"},
		Comment{23452, 743, 1, "samfisher", "8", "山东", `implement scrollViewDidScroll: and check contentOffset in that for reaching the end`},
		Comment{233452, 7523, 1, "很有钱", "9", "浙江", `赞同第一名的答案。痛经这个事情，每个人先天体质不一样没办法，但是其实很大一部分是坏的作息饮食习惯，和身体虚弱导致的。最管用的根治方法就是规律作息，多运动。我原来有朋友超级痛，走在路上会忽然痛到回不了家那种。后来去了军队，每天熄灯早起，天天搞体能，随意武装越野五公里，扳手腕偶尔能赢我。那会一点都不疼，经期生龙活虎嗷嗷叫。后来去文职机关了，老毛病又回来了。
吃上面尽量少吃凉的，西瓜山竹什么的注意控制。能早睡就早睡。慢慢养成规律运动的习惯。坚持下来会显著改善的。那些贴的吃的涂得中药西药都不治本。止疼针止疼片实在没办法可以用，但是到了那一步了就真心要注意了。
正能量的总结：多运动多早睡，生活更美好。实际观察爱运动身体好的女生痛的程度和概率远远小于水瓶盖扭不开八百米走完的女生。

—————————真答案分割线————————
大家都知道运动有效，可是大多数时候是做不到的。谁愿意天天被人催着去坚持锻炼，去早睡，这也不吃那也不吃。能不能做到其实看女生自己，男朋友能起到作用有限。。。反正我能力不足，潜移默化常年失败，这事真那么容易那也不会有那么多整天分享各种郑多燕啦腹肌撕裂者啦实际从来不会认真去坚持的人啦。
所以呢，碰见女朋友痛呢，悄悄叹口气，安静陪着，要热水给热水要荷包蛋做荷包蛋想吃啥去买啥要帮揉就揉不要就乖乖呆着不要烦她，



然后努力忍住不要借机教育要规律生活多运动（更不能嘲笑说平时不努力现在徒伤悲！切记切记！）就好啦～`},
	}

	//out
	lwutil.WriteResponse(w, &comments)
}

func getBetInfos(w http.ResponseWriter, r *http.Request) {

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
	http.Handle("/event/getActivities", lwutil.ReqHandler(getActivities))
}
