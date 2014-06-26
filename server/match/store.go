package main

import (
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
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

	iapProducts = map[string]int{
		"com.lw.sld.coin6":   600,
		"com.lw.sld.coin30":  3000 + 300,
		"com.lw.sld.coin68":  6800 + 1000,
		"com.lw.sld.coin128": 12800 + 2500,
		"com.lw.sld.coin328": 32800 + 10000,
		"com.lw.sld.coin588": 58800 + 25000,
	}
)

func glogStore() {
	glog.Info("")
}

func apiListGameCoinPack(w http.ResponseWriter, r *http.Request) {
	out := struct {
		GameCoinPacks []GameCoinPack
	}{
		GameCoinPacks: gameCoinPacks,
	}
	lwutil.WriteResponse(w, out)
}

func apiBuyGameCoin(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		EventId        int64
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
	playerInfo, err := getPlayerInfo(ssdb, session.Userid)
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
	playerInfo.Money -= int64(gameCoinPack.Price)

	//save player info
	savePlayerInfo(ssdb, session.Userid, playerInfo)

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

func apiListIapProductId(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	out := make([]string, len(iapProducts))
	i := 0
	for k, _ := range iapProducts {
		out[i] = k
		i++
	}

	lwutil.WriteResponse(w, out)
}

func apiGetIapSecret(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//player
	playerInfo, err := getPlayerInfo(ssdb, session.Userid)
	lwutil.CheckError(err, "")
	playerInfo.Secret = lwutil.GenUUID()
	savePlayerInfo(ssdb, session.Userid, playerInfo)

	//out
	out := map[string]string{
		"Secret": playerInfo.Secret,
	}
	lwutil.WriteResponse(w, out)
}

func apiBuyIap(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//in
	var in struct {
		ProductId string
		Checksum  string
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	addMoney, exist := iapProducts[in.ProductId]
	if !exist {
		lwutil.SendError("err_product_id", "")
	}

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//get player info
	playerInfo, err := getPlayerInfo(ssdb, session.Userid)
	lwutil.CheckError(err, "")

	//check checksum
	if playerInfo.Secret == "" {
		lwutil.SendError("err_secret", "")
	}
	checksum := fmt.Sprintf("%s%d%s,", playerInfo.Secret, session.Userid, session.Username)
	hasher := sha1.New()
	hasher.Write([]byte(checksum))
	checksum = hex.EncodeToString(hasher.Sum(nil))
	if in.Checksum != checksum {
		lwutil.SendError("err_checksum", checksum)
	}

	//set money
	playerInfo.Money += int64(addMoney)
	playerInfo.Secret = ""
	savePlayerInfo(ssdb, session.Userid, playerInfo)

	//out
	out := map[string]int64{
		"AddMoney": int64(addMoney),
		"Money":    playerInfo.Money,
	}
	lwutil.WriteResponse(w, out)
}

func regStore() {
	http.Handle("/store/listGameCoinPack", lwutil.ReqHandler(apiListGameCoinPack))
	http.Handle("/store/buyGameCoin", lwutil.ReqHandler(apiBuyGameCoin))
	http.Handle("/store/listIapProductId", lwutil.ReqHandler(apiListIapProductId))
	http.Handle("/store/getIapSecret", lwutil.ReqHandler(apiGetIapSecret))
	http.Handle("/store/buyIap", lwutil.ReqHandler(apiBuyIap))
}
