package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/golang/glog"
	"time"
)

func init() {
	glog.Infoln("scorekeeper init")
}

func checkError(err error) {
	if err != nil {
		panic(err)
	}
}

func checkSsdbError(resp []string, err error) {
	if err != nil {
		panic(err)
	}
	if resp[0] != "ok" {
		err := errors.New(fmt.Sprintf("ssdb error: %s", resp[0]))
		panic(err)
	}
}

func handleError() {
	if r := recover(); r != nil {
		glog.Errorln(r)
	}
}

func scoreKeeper() {
	defer handleError()

	//ssdb
	ssdb, err := ssdbPool.Get()
	checkError(err)
	defer ssdb.Close()

	//zrscan
	resp, err := ssdb.Do("zrscan", Z_EVENT, "", "", "", 10)
	checkSsdbError(resp, err)
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
	checkSsdbError(resp, err)
	resp = resp[1:]

	eventNum := len(resp) / 2
	events := make([]Event, eventNum)
	for i := 0; i < eventNum; i++ {
		err = json.Unmarshal([]byte(resp[i*2+1]), &events[i])
		checkError(err)
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
