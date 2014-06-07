package main

import (
	"encoding/json"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	"net/http"
)

type GameCoinPack struct {
	Price   int
	CoinNum int
}

var (
	gameCoinPacks = []GameCoinPack{
		{50, 1},
		{100, 3},
		{150, 5},
		{250, 10},
	}
)

func glogStore() {
	glog.Info("")
}

func listGameCoinPack(w http.ResponseWriter, r *http.Request) {
	out := struct {
		GameCoinPacks []GameCoinPack
	}{
		GameCoinPacks: gameCoinPacks,
	}
	lwutil.WriteResponse(w, out)
}

func buyGameCoin(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		EventId        uint64
		GameCoinPackId int
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	if in.GameCoinPackId < 0 || in.GameCoinPackId >= len(gameCoinPacks) {
		lwutil.SendError("err_game_coin_id", "")
	}

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//
	var gameCoinPack GameCoinPack
	gameCoinPack = gameCoinPacks[in.GameCoinPackId]

	//get event info
	resp, err := ssdb.Do("hget", H_EVENT, in.EventId)
	if resp[0] == "not_found" {
		lwutil.SendError("err_event_id", "")
	}
	lwutil.CheckSsdbError(resp, err)

	event := Event{}
	err = json.Unmarshal([]byte(resp[1]), &event)

	now := lwutil.GetRedisTimeUnix()
	if event.HasResult || now >= event.EndTime {
		lwutil.SendError("err_event_closed", "")
	}

	//player
	var playerInfo PlayerInfo
	err = getPlayer(ssdb, session.Userid, &playerInfo)
	lwutil.CheckError(err, "")

	//check money
	if int(playerInfo.Money) < gameCoinPack.Price {
		lwutil.SendError("err_money", "")
	}

	//get record
	recordKey := makeEventPlayerRecordSubkey(in.EventId, session.Userid)
	resp, err = ssdb.Do("hget", H_EVENT_PLAYER_RECORD, recordKey)
	lwutil.CheckSsdbError(resp, err)

	record := EventPlayerRecord{}
	err = json.Unmarshal([]byte(resp[1]), &record)
	lwutil.CheckError(err, "")

	//set game coin number
	record.GameCoinNum += gameCoinPack.CoinNum

	//save game coin
	js, err := json.Marshal(record)
	lwutil.CheckError(err, "")
	resp, err = ssdb.Do("hset", H_EVENT_PLAYER_RECORD, recordKey, js)
	lwutil.CheckSsdbError(resp, err)

	//spend money
	playerInfo.Money -= gameCoinPack.Price

	//save player info
	savePlayer(ssdb, session.Userid, &playerInfo)

	//out
	out := struct {
		Money       int
		GameCoinNum int
	}{
		int(playerInfo.Money),
		record.GameCoinNum,
	}
	lwutil.WriteResponse(w, out)
}

func regStore() {
	http.Handle("/store/listGameCoinPack", lwutil.ReqHandler(listGameCoinPack))
	http.Handle("/store/buyGameCoin", lwutil.ReqHandler(buyGameCoin))
}
