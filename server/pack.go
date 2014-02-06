package main

import (
	"encoding/json"
	"fmt"
	"github.com/garyburd/redigo/redis"
	// "github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	"net/http"
	"strconv"
	"strings"
)

const (
	hkey            = "h_packs"
	zkey            = "z_packs"
	hPlayerPackStar = "h_palyerPackStar"
)

type Image struct {
	Url   string
	Title string
	Text  string
}

type Pack struct {
	Id     uint32
	Date   string
	Title  string
	Text   string
	Icon   string
	Cover  string
	Images []Image
}

func addPack(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//in
	var in Pack
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//save to redis
	rc := redisPool.Get()
	defer rc.Close()

	if in.Id == 0 {
		ids, err := redis.Values(rc.Do("ZREVRANGE", zkey, 0, 1))
		lwutil.CheckError(err, "")
		maxId := 0
		if len(ids) > 0 {
			maxId, err = redis.Int(ids[0], nil)
			lwutil.CheckError(err, "")
		}
		in.Id = uint32(maxId + 1)
	} else {
		//check exist
		exists, err := redis.Bool(rc.Do("HEXISTS", hkey, in.Id))
		lwutil.CheckError(err, "")
		if exists {
			lwutil.SendError("err_already_exists", fmt.Sprintf("pack already exists: id=%d", in.Id))
		}
	}

	rc.Send("ZADD", zkey, in.Id, in.Id)
	value, err := json.Marshal(&in)
	lwutil.CheckError(err, "")
	rc.Send("HSET", hkey, in.Id, value)
	err = rc.Flush()
	lwutil.CheckError(err, "")

	//out
	out := struct {
		Id uint32
	}{in.Id}
	lwutil.WriteResponse(w, &out)
}

func delPack(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		Id uint32
	}
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//check exist
	exists, err := redis.Bool(rc.Do("HEXISTS", hkey, in.Id))
	lwutil.CheckError(err, "")
	if !exists {
		lwutil.SendError("err_not_exists", fmt.Sprintf("pack not exists: id=%d", in.Id))
	}

	//delete
	rc.Send("ZREM", zkey, in.Id)
	rc.Send("HDEL", hkey, in.Id)
	err = rc.Flush()
	lwutil.CheckError(err, "")

	//out
	out := struct {
		Id uint32
	}{in.Id}
	lwutil.WriteResponse(w, &out)
}

func editPack(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//in
	var in Pack
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//edit
	exists, err := redis.Bool(rc.Do("HEXISTS", hkey, in.Id))
	lwutil.CheckError(err, "")
	if !exists {
		lwutil.SendError("err_not_exists", fmt.Sprintf("pack not exists: id=%d", in.Id))
	}
	rc.Send("ZADD", zkey, in.Id, in.Id)
	value, err := json.Marshal(&in)
	lwutil.CheckError(err, "")
	rc.Send("HSET", hkey, in.Id, value)
	err = rc.Flush()
	lwutil.CheckError(err, "")

	//out
	out := struct {
		Id uint32
	}{in.Id}
	lwutil.WriteResponse(w, &out)
}

func countPack(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	rc := redisPool.Get()
	defer rc.Close()

	packCount, err := redis.Int(rc.Do("ZCARD", zkey))
	lwutil.CheckError(err, "")

	//out
	out := struct {
		PackCount uint32
	}{
		uint32(packCount),
	}
	lwutil.WriteResponse(w, &out)
}

func listPack(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//in
	var in struct {
		Offset uint32
		Limit  uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if in.Limit > 30 {
		in.Limit = 30
	}

	//pack info
	_packNum, err := redis.Int(rc.Do("ZCARD", zkey))
	lwutil.CheckError(err, "")
	packNum := uint32(_packNum)

	imgStart := in.Offset
	imgStop := imgStart + in.Limit
	ids, err := redis.Values(rc.Do("ZRANGE", zkey, imgStart, imgStop))
	lwutil.CheckError(err, "")
	if len(ids) == 0 {
		lwutil.SendError("err_page", "page out of range")
	}

	args := make([]interface{}, 0, 10)
	args = append(args, hkey)
	for _, id := range ids {
		args = append(args, id)
	}

	packsJs, err := redis.Values(rc.Do("HMGET", args...))
	lwutil.CheckError(err, "")

	type _Pack struct {
		Pack
		Star uint8
	}

	packs := make([]_Pack, 0, 10)
	starMap := make(map[uint32]int) //packId => index of packs
	for i, js := range packsJs {
		var pack _Pack
		bjs, err := redis.Bytes(js, nil)
		lwutil.CheckError(err, "")
		err = json.Unmarshal(bjs, &pack)
		lwutil.CheckError(err, "")
		packs = append(packs, pack)
		starMap[pack.Id] = i
	}

	//player star
	starMsg := make([]interface{}, 0, 10)
	starMsg = append(starMsg, "multi_hget", hPlayerPackStar)
	for _, packId := range ids {
		key := fmt.Sprintf("%d/%s", session.Userid, packId)
		starMsg = append(starMsg, key)
	}
	resp, err := ssdb.Do(starMsg...)
	lwutil.CheckSsdbError(resp, err)
	for i := 1; i < len(resp); i += 2 {
		strs := strings.Split(resp[i], "/")
		starNum, err := strconv.ParseUint(resp[i+1], 10, 8)
		lwutil.CheckError(err, "")

		packId, err := strconv.ParseUint(strs[1], 10, 32)
		lwutil.CheckError(err, "")
		if idx, ok := starMap[uint32(packId)]; ok {
			packs[idx].Star = uint8(starNum)
		}
	}

	//out
	out := map[string]interface{}{
		"Packs":   packs,
		"PackNum": packNum,
	}
	lwutil.WriteResponse(w, &out)
}

func getPack(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//redis
	rc := redisPool.Get()
	defer rc.Close()

	//in
	var in struct {
		Id uint32
	}
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	packJs, err := redis.Bytes(rc.Do("HGET", hkey, in.Id))
	lwutil.CheckError(err, "")

	var pack Pack
	bjs, err := redis.Bytes(packJs, nil)
	lwutil.CheckError(err, "")
	err = json.Unmarshal(bjs, &pack)
	lwutil.CheckError(err, "")

	//out
	lwutil.WriteResponse(w, &pack)
}

func setPackStar(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//in
	var in struct {
		PackId uint32
		Star   uint8
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if in.Star > 3 {
		lwutil.SendError("err_star_num", "star must between (0, 3)")
	}

	//ssdb
	key := fmt.Sprintf("%d/%d", session.Userid, in.PackId)
	resp, err := ssdb.Do("hset", hPlayerPackStar, key, in.Star)
	lwutil.CheckSsdbError(resp, err)

	lwutil.WriteResponse(w, "ok")
}

func regPack() {
	http.Handle("/pack/add", lwutil.ReqHandler(addPack))
	http.Handle("/pack/edit", lwutil.ReqHandler(editPack))
	http.Handle("/pack/del", lwutil.ReqHandler(delPack))
	http.Handle("/pack/list", lwutil.ReqHandler(listPack))
	http.Handle("/pack/get", lwutil.ReqHandler(getPack))
	http.Handle("/pack/count", lwutil.ReqHandler(countPack))
	http.Handle("/pack/setStar", lwutil.ReqHandler(setPackStar))
}
