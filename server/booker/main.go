package main

import (
	"../ssdb"
	"encoding/json"
	"flag"
	"fmt"
	"github.com/garyburd/redigo/redis"
	"github.com/golang/glog"
	"runtime"
	// "strconv"
	"time"
)

const (
	Z_EVENT                      = "Z_EVENT"
	H_EVENT                      = "H_EVENT"
	H_EVENT_RESULT               = "H_EVENT_RESULT"
	Z_EVENT_TEAM_LEADERBOARD_PRE = "Z_EVENT_TEAM_LEADERBOARD_PRE"
	H_EVENT_ROUND_TEAM_TOPTEN    = "H_EVENT_ROUND_TEAM_TOPTEN"
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
	Id     uint32
	Score  int32
	TopTen []GameRecord
}

type GameRecord struct {
	PlayerId uint64
	Score    int32
}

func handleError() {
	if r := recover(); r != nil {
		glog.Errorln(r)
	}
}

func update() {
	defer handleError()

	//ssdb
	ssdb, err := ssdbPool.Get()
	checkError(err)
	defer ssdb.Close()

	//get not finish events
	resp, err := ssdb.Do("zkeys", Z_EVENT, "", "", "", 20)
	checkSsdbError(resp, err)
	eventStrs := resp[1:]

	cmd := make([]interface{}, len(eventStrs)+2)
	cmd[0] = "multi_hget"
	cmd[1] = H_EVENT
	for i, v := range eventStrs {
		cmd[i+2] = v
	}
	resp, err = ssdb.Do(cmd...)
	checkSsdbError(resp, err)

	resp = resp[1:]
	eventNum := len(resp) / 2
	events := make([]Event, eventNum)
	for i := 0; i < eventNum; i++ {
		err = json.Unmarshal([]byte(resp[i*2+1]), &events[i])
		checkError(err)
	}

	//get not finish event results
	cmd = make([]interface{}, len(eventStrs)+2)
	cmd[0] = "multi_hget"
	cmd[1] = H_EVENT_RESULT
	for i, v := range eventStrs {
		cmd[i+2] = v
	}
	resp, err = ssdb.Do(cmd...)
	checkSsdbError(resp, err)

	resp = resp[1:]
	resultNum := len(resp) / 2
	results := make([]EventResult, resultNum)
	for i := 0; i < resultNum; i++ {
		err = json.Unmarshal([]byte(resp[i*2+1]), &results[i])
		checkError(err)
	}

	if eventNum != resultNum {
		panic("eventNum != resultNum")
	}

	for i, _ := range events {
		event := events[i]
		result := results[i]
		if event.Id != result.EventId {
			panic("event.Id != result.EventId")
		}
		// if time.Now().Unix() >= event.TimePoints[result.CurrRound+1] {
		// 	//update round
		// 	if result.CurrRound == 0 {
		// 		updateRound0(ssdb, &event, &result)
		// 	} else {
		// 		updateRound(ssdb, &event, &result)
		// 	}
		// }

		// test: force update
		updateRound0(ssdb, &event, &result)
		js, err := json.Marshal(result)
		checkError(err)
		resp, err = ssdb.Do("hset", H_EVENT_RESULT, event.Id, js)
		checkSsdbError(resp, err)
	}

	// glog.Info(events)
	// glog.Info(results)
}

func updateRound0(ssdb *ssdb.Client, event *Event, result *EventResult) {
	glog.Info("updateRound0")
	rc := redisPool.Get()
	defer rc.Close()

	round := &result.Rounds[result.CurrRound]
	for _, game := range round.Games {
		for iTeam := range game.Teams {
			team := &game.Teams[iTeam]
			//get top ten of the team
			teamLbKey := fmt.Sprintf("%s/%d/%d", Z_EVENT_TEAM_LEADERBOARD_PRE, event.Id, team.Id)

			reply, err := rc.Do("ZREVRANGE", teamLbKey, 0, 10, "WITHSCORES")
			values, err := redis.Values(reply, err)
			checkError(err)

			topTen := make([]GameRecord, len(values)/2)
			for iRecord := range topTen {
				record := &topTen[iRecord]
				playerId, err := redis.Int64(values[iRecord*2], nil)
				checkError(err)
				score, err := redis.Int64(values[iRecord*2+1], nil)
				checkError(err)
				record.PlayerId = uint64(playerId)
				record.Score = int32(score)
			}
			js, err := json.Marshal(topTen)
			checkError(err)
			key := fmt.Sprintf("%d/%d/%d", event.Id, result.CurrRound, team.Id)
			resp, err := ssdb.Do("hset", H_EVENT_ROUND_TEAM_TOPTEN, key, js)
			checkSsdbError(resp, err)

			glog.Info(string(js))
		}
	}
	// round := result.Rounds[result.CurrRound]
	// for _, v := range round {
	// 	teamScores := make([][]int32, len(v.PlayerOrTeamIds))
	// 	for i, teamId := range v.PlayerOrTeamIds {
	// 		//get top ten of the team
	// 		teamLbKey := fmt.Sprintf("%s/%d/%d", Z_EVENT_TEAM_LEADERBOARD_PRE, event.Id, teamId)
	// 		topScoreNum := 10
	// 		resp, err := ssdb.Do("zrscan", teamLbKey, "", "", "", topScoreNum)
	// 		checkSsdbError(resp, err)
	// 		resp = resp[1:]

	// 		scoreSum := int32(0)
	// 		scoreNum := 0
	// 		for i, v := range resp {
	// 			if i%2 == 1 {
	// 				score, err := strconv.ParseInt(resp[i], 10, 32)
	// 				checkError(err)
	// 				scoreSum += int32(score)
	// 				scoreNum++
	// 			}
	// 		}
	// 		if scoreNum == 0 {
	// 			scoreSum = 0
	// 		}
	// 	}
	// }

	// result.CurrRound++
}

func updateRound(ssdb *ssdb.Client, event *Event, result *EventResult) {

}

func main() {
	flag.Parse()
	runtime.GOMAXPROCS(1)
	glog.Infof("Booker running")

	for true {
		update()

		//sleep to next minute
		now := time.Now()
		t := now.Add(time.Minute + time.Second)
		to := time.Date(t.Year(), t.Month(), t.Day(), t.Hour(), t.Minute(), 0, 0, time.Local)
		dt := to.Sub(now)
		//dt = time.Second
		time.Sleep(dt)
	}
}
