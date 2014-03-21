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
	"sort"
	"time"
)

const (
	Z_EVENT                      = "Z_EVENT"
	H_EVENT                      = "H_EVENT"
	H_EVENT_RESULT               = "H_EVENT_RESULT"
	Z_EVENT_TEAM_LEADERBOARD_PRE = "Z_EVENT_TEAM_LEADERBOARD_PRE"
	H_EVENT_ROUND_TEAM_TOPTEN    = "H_EVENT_ROUND_TEAM_TOPTEN"
	H_EVENT_PLAYER_RECORD        = "H_EVENT_PLAYER_RECORD"
	PUNISH_SCORE                 = 10 * 1000 * 60
	TEAM_CHAMPIONSHIP_ROUND_NUM  = 6
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
	Win   bool
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

		//glog.Info(string(js))
	}

	// glog.Info(events)
	// glog.Info(results)
}

type ByScore []Team

func (a ByScore) Len() int           { return len(a) }
func (a ByScore) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByScore) Less(i, j int) bool { return a[i].Score > a[j].Score }

type ByTime []GameRecord

func (a ByTime) Len() int           { return len(a) }
func (a ByTime) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByTime) Less(i, j int) bool { return a[i].Time < a[j].Time }

func updateRound0(ssdb *ssdb.Client, event *Event, result *EventResult) {
	glog.Info("updateRound0")
	rc := redisPool.Get()
	defer rc.Close()

	round := &result.Rounds[0]
	nextRound := &result.Rounds[1]
	nextRound.Games = make([]Game, 8)
	for iGame, game := range round.Games {
		for iTeam := range game.Teams {
			team := &game.Teams[iTeam]
			team.Win = false
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

				//get score time
				key := fmt.Sprintf("%d/%d", event.Id, playerId)
				resp, err := ssdb.Do("hget", H_EVENT_PLAYER_RECORD, key)
				checkSsdbError(resp, err)
				rcd := EventPlayerRecord{}
				err = json.Unmarshal([]byte(resp[1]), &rcd)
				checkError(err)
				record.Time = rcd.HighScoreTime
			}
			js, err := json.Marshal(topTen)
			checkError(err)

			//save top ten
			key := fmt.Sprintf("%d/%d/%d", event.Id, result.CurrRound, team.Id)
			resp, err := ssdb.Do("hset", H_EVENT_ROUND_TEAM_TOPTEN, key, js)
			checkSsdbError(resp, err)

			//calc score
			scoreSum := int32(0)
			for _, v := range topTen {
				scoreSum += v.Score
			}
			punishScore := PUNISH_SCORE * (10 - len(topTen))
			team.Score = scoreSum - int32(punishScore)
		}

		//pick top 2
		sortedTeams := make([]Team, len(game.Teams))
		copy(sortedTeams, game.Teams)
		sort.Sort(ByScore(sortedTeams))

		//win
		for i, team := range game.Teams {
			if team.Id == sortedTeams[0].Id || team.Id == sortedTeams[1].Id {
				game.Teams[i].Win = true
				continue
			}
		}

		//next round
		nextRoundTeam := make([]Team, 2)
		nextRoundTeam[0] = Team{}
		nextRoundTeam[0].Id = sortedTeams[0].Id
		nextRoundTeam[1] = Team{}
		nextRoundTeam[1].Id = sortedTeams[1].Id

		nextRound.Games[iGame].Teams = nextRoundTeam
	}
	result.CurrRound = 1

}

func updateRound(ssdb *ssdb.Client, event *Event, result *EventResult) {
	glog.Info("updateRound")
	rc := redisPool.Get()
	defer rc.Close()

	round := &result.Rounds[result.CurrRound]

	hasNextRound := result.CurrRound < TEAM_CHAMPIONSHIP_ROUND_NUM-1
	var nextRound *Round
	if hasNextRound {
		nextRound = &result.Rounds[result.CurrRound+1]
		switch result.CurrRound {
		case 0, TEAM_CHAMPIONSHIP_ROUND_NUM - 2:
			nextRound.Games = make([]Game, len(round.Games))
		case TEAM_CHAMPIONSHIP_ROUND_NUM - 1:

		default:
			nextRound.Games = make([]Game, len(round.Games)/2)
		}

		for i := range nextRound.Games {
			nextRound.Games[i].Teams = make([]Team, 2)
		}
	}

	for iGame, game := range round.Games {
		topTens := make([][]GameRecord, len(game.Teams))
		for iTeam := range game.Teams {
			team := &game.Teams[iTeam]
			team.Win = false
			team.Score = 0
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

				//get score time
				key := fmt.Sprintf("%d/%d", event.Id, playerId)
				resp, err := ssdb.Do("hget", H_EVENT_PLAYER_RECORD, key)
				checkSsdbError(resp, err)
				rcd := EventPlayerRecord{}
				err = json.Unmarshal([]byte(resp[1]), &rcd)
				checkError(err)
				record.Time = rcd.HighScoreTime
			}
			js, err := json.Marshal(topTen)
			checkError(err)
			topTens = append(topTens, topTen)

			//save top ten
			key := fmt.Sprintf("%d/%d/%d", event.Id, result.CurrRound, team.Id)
			resp, err := ssdb.Do("hset", H_EVENT_ROUND_TEAM_TOPTEN, key, js)
			checkSsdbError(resp, err)

			//calc score if round == 0
			if result.CurrRound == 0 {
				scoreSum := int32(0)
				for _, v := range topTen {
					scoreSum += v.Score
				}
				punishScore := PUNISH_SCORE * (10 - len(topTen))
				team.Score = scoreSum - int32(punishScore)
			}
		}

		//calc score if round > 0
		if result.CurrRound > 0 {
			if len(topTens) != 2 {
				panic("topTens != 2")
			}

			//resort top ten by time
			for i := range topTens {
				sort.Sort(ByTime(topTens[i]))
			}

			//calc score
			for i := 0; i < 10; i++ {
				maxScore := topTens[0][i].Score
				for _, topTen := range topTens {
					if topTen[i].Score > maxScore {
						maxScore = topTen[i].Score
					}
				}
				for iTeam, topTen := range topTens {
					team := &game.Teams[iTeam]
					if topTen[i].Score == maxScore {
						team.Score += 1
					}
				}
			}

			//if draw
			if game.Teams[0].Score == game.Teams[1].Score {
				for i := 0; i < 10; i++ {
					if topTens[0][i].Score > topTens[1][i].Score {
						game.Teams[0].Score++
						break
					} else if topTens[0][i].Score < topTens[1][i].Score {
						game.Teams[1].Score++
						break
					}
				}
			}
			var winnerTeamId, loserTeamId uint32
			if game.Teams[0].Score >= game.Teams[1].Score {
				game.Teams[0].Win = true
				winnerTeamId = game.Teams[0].Id
				loserTeamId = game.Teams[1].Id
			} else {
				game.Teams[1].Win = true
				winnerTeamId = game.Teams[1].Id
				loserTeamId = game.Teams[0].Id
			}

			//next round
			if result.CurrRound == TEAM_CHAMPIONSHIP_ROUND_NUM-2 {
				nextRound.Games[0].Teams[iGame].Id = winnerTeamId
				nextRound.Games[1].Teams[iGame].Id = loserTeamId
			} else {
				nextRound.Games[iGame/2].Teams[iGame%2].Id = winnerTeamId
			}

		} else {
			//pick top 1
			sortedTeams := make([]Team, len(game.Teams))
			copy(sortedTeams, game.Teams)
			sort.Sort(ByScore(sortedTeams))

			//win
			for i, team := range game.Teams {
				if team.Id == sortedTeams[0].Id {
					game.Teams[i].Win = true
					continue
				}
			}

			//next round
			nextRound.Games[iGame].Teams[0].Id = sortedTeams[0].Id
			nextRound.Games[iGame].Teams[1].Id = sortedTeams[1].Id
		}

	}
	result.CurrRound++
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
