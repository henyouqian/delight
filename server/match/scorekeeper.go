package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/garyburd/redigo/redis"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	"runtime"
	"time"
)

func init() {
	glog.Infoln("scorekeeper init")
}

func checkError(err error) {
	if err != nil {
		_, file, line, _ := runtime.Caller(1)
		e := fmt.Sprintf("[%s:%d]%v", file, line, err)
		panic(e)
	}
}

func checkSsdbError(resp []string, err error) {
	if resp[0] != "ok" {
		err = errors.New(fmt.Sprintf("ssdb error: %s", resp[0]))
	}
	if err != nil {
		_, file, line, _ := runtime.Caller(1)
		e := fmt.Sprintf("[%s:%d]%v", file, line, err)
		panic(e)
	}
}

func handleError() {
	if r := recover(); r != nil {
		_, file, line, _ := runtime.Caller(2)
		glog.Error(r, file, line)

		buf := make([]byte, 2048)
		runtime.Stack(buf, false)
		glog.Errorf("%s", buf)
	}
}

func calcReward(rank int) (reward int) {
	return 0
}

func scoreKeeper() {
	defer handleError()

	//ssdb
	ssdb, err := ssdbPool.Get()
	checkError(err)
	defer ssdb.Close()

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//zrscan
	resp, err := ssdb.Do("zrscan", Z_EVENT, "", "", "", 20)
	checkSsdbError(resp, err)
	resp = resp[1:]
	if len(resp) == 0 {
		return
	}

	//multi_hget
	keyNum := len(resp) / 2
	cmds := make([]interface{}, keyNum+2)
	cmds[0] = "multi_hget"
	cmds[1] = H_EVENT
	for i := 0; i < keyNum; i++ {
		cmds[2+i] = resp[i*2]
	}
	eventResp, err := ssdb.Do(cmds...)
	checkSsdbError(eventResp, err)
	eventResp = eventResp[1:]

	eventNum := len(eventResp) / 2
	for i := 0; i < eventNum; i++ {
		var event Event
		err = json.Unmarshal([]byte(eventResp[i*2+1]), &event)
		checkError(err)

		now := lwutil.GetRedisTimeUnix()
		if event.HasResult || now < event.EndTime {
			continue
		}

		glog.Infof("event begin: id=%d", event.Id)

		//get ranks
		eventLbLey := makeRedisLeaderboardKey(event.Id)
		rankNum, err := redis.Int(rc.Do("ZCARD", eventLbLey))
		checkError(err)
		numPerBatch := 1000
		currRank := 1
		for iBatch := 0; iBatch < rankNum/numPerBatch+1; iBatch++ {
			offset := iBatch * numPerBatch
			values, err := redis.Values(rc.Do("ZREVRANGE", eventLbLey, offset, offset+numPerBatch-1, "WITHSCORES"))
			checkError(err)

			num := len(values) / 2
			if num == 0 {
				continue
			}

			for i := 0; i < num; i++ {
				rank := currRank
				currRank++
				userId, err := redisUint64(values[i*2], nil)
				checkError(err)
				// score, err := redisInt32(values[i*2+1], nil)
				// checkError(err)

				//set to event player record
				recordKey := fmt.Sprintf("%d/%d", event.Id, userId)
				resp, err := ssdb.Do("hget", H_EVENT_PLAYER_RECORD, recordKey)
				checkSsdbError(resp, err)
				record := EventPlayerRecord{}
				err = json.Unmarshal([]byte(resp[1]), &record)
				checkError(err)
				record.FinalRank = rank
				js, err := json.Marshal(record)
				checkError(err)
				resp, err = ssdb.Do("hset", H_EVENT_PLAYER_RECORD, recordKey, js)
				checkSsdbError(resp, err)

				//save to H_EVENT_RANK
				key := makeHashEventRankKey(event.Id)
				resp, err = ssdb.Do("hset", key, rank, userId)
				checkSsdbError(resp, err)
			}
		}

		//event finished
		event.HasResult = true
		jsEvent, err := json.Marshal(event)
		checkError(err)
		resp, err = ssdb.Do("hset", H_EVENT, event.Id, jsEvent)
		checkSsdbError(resp, err)

		//del redis leaderboard
		_, err = rc.Do("del", eventLbLey)
		checkError(err)

		glog.Infof("event end")
	}
}

func scoreKeeperMain() {
	glog.Info("scorekeeper start")
	for true {
		go scoreKeeper()

		//sleep to next minute
		now := time.Now()

		t := now.Add(time.Minute + time.Second)
		to := time.Date(t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), 0, 0, time.Local)
		dt := to.Sub(now)
		//dt = time.Second
		time.Sleep(dt)
	}
}
