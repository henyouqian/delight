package main

import (
	"flag"
	// "fmt"
	"encoding/json"
	"github.com/golang/glog"
	"runtime"
	"sync"
	"time"
)

const (
	CURRENT_MATCH           = "currentMatch"
	NEXT_MATCH              = "nextMatch"
	CURRENT_MATCH_RESULT    = "currentMatchResult"
	MATCH_PACK_COMMING_LIST = "matchPackCommingList"
	H_MATCH                 = "hMatch"
	MATCH_SERIAL            = "matchSerial"
)

type Match struct {
	Id         uint64
	PackId     uint64
	RoundBegin [6]int64
	CurrRound  int
}

type MatchSchedule struct {
	Round0 [34]uint32
	Round1 [16]uint32
	Round2 [8]uint32
	Round3 [4]uint32
	Round4 [4]uint32
	Round5 [3]uint32
}

type RoundResult struct {
	Zone1        uint32
	Zone2        uint32
	Score1       uint32
	Score2       uint32
	winnerZone   uint32
	MatchResults []struct {
		Player1 uint32
		player2 uint32
		Score1  int32
		Score2  int32
	}
}

var (
	ZONE_VEC = []uint32{
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

func newMatch(genTime time.Time) Match {
	//ssdb
	ssdb, err := ssdbPool.Get()
	checkError(err)
	defer ssdb.Close()

	//get comming list
	var list []uint64
	resp, err := ssdb.Do("get", MATCH_PACK_COMMING_LIST)
	checkSsdbError(resp, err)
	err = json.Unmarshal([]byte(resp[1]), &list)
	checkError(err)

	if len(list) == 0 {
		glog.Fatal("match comming list empty")
	}
	packId := list[0]
	list = list[1:]
	js, err := json.Marshal(list)
	checkError(err)
	resp, err = ssdb.Do("set", MATCH_PACK_COMMING_LIST, js)
	checkSsdbError(resp, err)

	//
	var match Match

	//match info
	match.Id = genSerial(ssdb, MATCH_SERIAL)
	match.PackId = packId
	match.CurrRound = -1
	t := genTime
	// h := t.Hour()
	// if h >= 8 && h < 15 {
	// 	//later match
	// 	match.RoundBegin[0] = time.Date(t.Year(), t.Month(), t.Day(), 15, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[1] = time.Date(t.Year(), t.Month(), t.Day(), 19, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[2] = time.Date(t.Year(), t.Month(), t.Day(), 19, 30, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[3] = time.Date(t.Year(), t.Month(), t.Day(), 20, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[4] = time.Date(t.Year(), t.Month(), t.Day(), 20, 30, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[5] = time.Date(t.Year(), t.Month(), t.Day(), 21, 0, 0, 0, time.Local).Unix()
	// } else if h >= 15 {
	// 	t = t.AddDate(0, 0, 1)
	// 	match.RoundBegin[0] = time.Date(t.Year(), t.Month(), t.Day(), 7, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[1] = time.Date(t.Year(), t.Month(), t.Day(), 11, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[2] = time.Date(t.Year(), t.Month(), t.Day(), 11, 30, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[3] = time.Date(t.Year(), t.Month(), t.Day(), 12, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[4] = time.Date(t.Year(), t.Month(), t.Day(), 12, 30, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[5] = time.Date(t.Year(), t.Month(), t.Day(), 13, 0, 0, 0, time.Local).Unix()
	// } else {
	// 	match.RoundBegin[0] = time.Date(t.Year(), t.Month(), t.Day(), 7, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[1] = time.Date(t.Year(), t.Month(), t.Day(), 11, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[2] = time.Date(t.Year(), t.Month(), t.Day(), 11, 30, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[3] = time.Date(t.Year(), t.Month(), t.Day(), 12, 0, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[4] = time.Date(t.Year(), t.Month(), t.Day(), 12, 30, 0, 0, time.Local).Unix()
	// 	match.RoundBegin[5] = time.Date(t.Year(), t.Month(), t.Day(), 13, 0, 0, 0, time.Local).Unix()
	// }

	minT := time.Now().Add(time.Second * 21)
	if t.Before(minT) {
		t = minT
	}
	match.RoundBegin[0] = t.Add(time.Second * 3).Unix()
	match.RoundBegin[1] = t.Add(time.Second * 6).Unix()
	match.RoundBegin[2] = t.Add(time.Second * 9).Unix()
	match.RoundBegin[3] = t.Add(time.Second * 12).Unix()
	match.RoundBegin[4] = t.Add(time.Second * 15).Unix()
	match.RoundBegin[5] = t.Add(time.Second * 18).Unix()

	//match schedule
	var matchSchedule MatchSchedule
	randZone := shuffleArray(ZONE_VEC)
	if len(randZone) != len(matchSchedule.Round0) {
		glog.Fatalln("len(randZone) != len(matchSchedule.Round0)")
	}
	for i, v := range randZone {
		matchSchedule.Round0[i] = v
	}

	js, err = json.Marshal(matchSchedule)
	resp, err = ssdb.Do("set", CURRENT_MATCH_RESULT, js)
	checkSsdbError(resp, err)
	glog.Infoln(string(js))

	return match
}

func initMatch() {
	//ssdb
	ssdb, err := ssdbPool.Get()
	checkError(err)
	defer ssdb.Close()

	//check current match
	resp, err := ssdb.Do("get", CURRENT_MATCH)
	checkError(err)
	if resp[0] != "ok" {
		//new current match
		currMatch := newMatch(time.Now())
		js, err := json.Marshal(currMatch)
		resp, err := ssdb.Do("set", CURRENT_MATCH, js)
		checkSsdbError(resp, err)

		glog.Infoln("currMatch: ", currMatch.PackId)

		//new next match
		nextMatch := newMatch(time.Unix(currMatch.RoundBegin[5], 0))
		js, err = json.Marshal(nextMatch)
		resp, err = ssdb.Do("set", NEXT_MATCH, js)
		checkSsdbError(resp, err)

		glog.Infoln("nextMatch: ", nextMatch.PackId)
	} else {
		var currMatch Match
		err = json.Unmarshal([]byte(resp[1]), &currMatch)
		checkError(err)

		resp, err = ssdb.Do("get", NEXT_MATCH)
		var nextMatch Match
		err = json.Unmarshal([]byte(resp[1]), &nextMatch)
		checkError(err)

		if currMatch.Id == nextMatch.Id {
			//new next match
			nextMatch := newMatch(time.Unix(currMatch.RoundBegin[len(currMatch.RoundBegin)-1], 0))
			js, err := json.Marshal(nextMatch)
			resp, err = ssdb.Do("set", NEXT_MATCH, js)
			checkSsdbError(resp, err)
		}
	}
}

func updateRound() {
	glog.Infoln("")
	glog.Infoln("updateRound begin")

	//ssdb
	ssdb, err := ssdbPool.Get()
	checkError(err)
	defer ssdb.Close()

	//get match
	resp, err := ssdb.Do("get", CURRENT_MATCH)
	var currMatch Match
	err = json.Unmarshal([]byte(resp[1]), &currMatch)
	checkError(err)
	glog.Infof("currMatch: packId=%d, round=%d", currMatch.PackId, currMatch.CurrRound)

	resp, err = ssdb.Do("get", NEXT_MATCH)
	var nextMatch Match
	err = json.Unmarshal([]byte(resp[1]), &nextMatch)
	checkError(err)
	glog.Infof("nextMatch: packId=%d, round=%d", nextMatch.PackId, nextMatch.CurrRound)

	//
	isFinalRound := currMatch.CurrRound == len(currMatch.RoundBegin)-1
	var nextRoundBegin int64
	if isFinalRound {
		nextRoundBegin = nextMatch.RoundBegin[0]
	} else {
		nextRoundBegin = currMatch.RoundBegin[currMatch.CurrRound+1]
	}

	//check if passed the time point
	nowUnix := time.Now().Unix()
	if nowUnix < nextRoundBegin {
		durationToNext := time.Second * time.Duration(nextRoundBegin-nowUnix+1)
		time.AfterFunc(durationToNext, updateRound)
		glog.Infoln("no need update: schedule updateRound: duration=", durationToNext)
		return
	}

	//change round
	currMatch.CurrRound++
	switch currMatch.CurrRound {
	case 0:
		glog.Infoln("round0 begin")
	case 1:
		glog.Infoln("round1 begin")

	case 2:
		glog.Infoln("round2 begin")
	case 3:
		glog.Infoln("round3 begin")
	case 4:
		glog.Infoln("round4 begin")
	case 5:
		glog.Infoln("round5 begin")
	case 6:
		glog.Infoln("round6 begin")
	}

	//change to next match?
	if !isFinalRound {
		js, err := json.Marshal(currMatch)
		resp, err = ssdb.Do("set", CURRENT_MATCH, js)
		checkSsdbError(resp, err)
	} else {
		currMatch = nextMatch
		js, err := json.Marshal(currMatch)
		resp, err = ssdb.Do("set", CURRENT_MATCH, js)
		checkSsdbError(resp, err)

		nextMatch := newMatch(time.Unix(currMatch.RoundBegin[5], 0))
		js, err = json.Marshal(nextMatch)
		resp, err = ssdb.Do("set", NEXT_MATCH, js)
		checkSsdbError(resp, err)
		glog.Infof("next match: %d,%d", currMatch.PackId, nextMatch.PackId)
	}

	//
	isFinalRound = currMatch.CurrRound == len(currMatch.RoundBegin)-1
	if isFinalRound {
		nextRoundBegin = nextMatch.RoundBegin[0]
	} else {
		nextRoundBegin = currMatch.RoundBegin[currMatch.CurrRound+1]
	}
	durationToNext := time.Second * time.Duration(nextRoundBegin-nowUnix+1)
	time.AfterFunc(durationToNext, updateRound)
	glog.Infoln("schedule updateRound: duration=", durationToNext)
}

func main() {
	flag.Parse()
	runtime.GOMAXPROCS(1)
	glog.Infof("Booker running")

	var w sync.WaitGroup

	initMatch()
	updateRound()

	//
	w.Add(1)
	w.Wait()
}
