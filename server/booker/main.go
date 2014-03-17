package main

import (
	"flag"
	// "fmt"
	"encoding/json"
	"github.com/golang/glog"
	"runtime"
	"time"
)

const (
	Z_EVENT        = "Z_EVENT"
	H_EVENT        = "H_EVENT"
	H_EVENT_RESULT = "H_EVENT_RESULT"
)

type Event struct {
	Type             string //"PERSONAL_RANK", "TEAM_CHAMPIONSHIP"
	Id               uint64
	PackId           uint64
	TimePointStrings []string
	TimePoints       []int64
}

type Game struct {
	PlayerOrTeamIds []uint32
	Scores          []int32
	Winners         []uint32
}

type Round []Game

type EventResult struct {
	EventId   uint64
	CurrRound int
	Rounds    []Round
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

	}

	glog.Info(events)
	glog.Info(results)
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
