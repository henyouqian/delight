package main

import (
	"encoding/json"
	"fmt"
	"github.com/garyburd/redigo/redis"
	"github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	"math"
	"net/http"
)

const (
	hkey        = "h_packs"
	zkey        = "z_packs"
	autoIncrFld = "autoIncr"
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

func _useGlog() {
	glog.Info("")
}

func add(w http.ResponseWriter, r *http.Request) {
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

func del(w http.ResponseWriter, r *http.Request) {
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

func edit(w http.ResponseWriter, r *http.Request) {
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

func count(w http.ResponseWriter, r *http.Request) {
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

func list(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		FromId uint32
		Limit  uint32
	}
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	if in.FromId == 0 {
		in.FromId = math.MaxUint32
	}
	if in.Limit > 16 {
		in.Limit = 16
	}

	//query from db
	rows, err := packDB.Query("SELECT id, date, title, icon, cover, text, images FROM packs WHERE id<=? ORDER BY id DESC LIMIT ?", in.FromId, in.Limit)
	lwutil.CheckError(err, "")

	type Pack struct {
		Id     uint32
		Date   string
		Icon   string
		Title  string
		Cover  string
		Text   string
		Images string
	}
	packs := make([]Pack, 0, in.Limit)
	for rows.Next() {
		var pack Pack
		err = rows.Scan(&pack.Id, &pack.Date, &pack.Title, &pack.Icon, &pack.Cover, &pack.Text, &pack.Images)
		lwutil.CheckError(err, "")
		packs = append(packs, pack)
	}

	//out
	lwutil.WriteResponse(w, packs)
}

func get(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	rc := redisPool.Get()
	defer rc.Close()

	//in
	var in struct {
		Offset uint32
		Limit  uint32
	}
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if in.Limit > 30 {
		in.Limit = 30
	}

	//
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

	packs := make([]Pack, 0, 10)
	for _, js := range packsJs {
		var pack Pack
		bjs, err := redis.Bytes(js, nil)
		lwutil.CheckError(err, "")
		err = json.Unmarshal(bjs, &pack)
		lwutil.CheckError(err, "")
		packs = append(packs, pack)
	}

	//out
	out := struct {
		Packs   []Pack
		PackNum uint32
	}{
		packs,
		packNum,
	}
	lwutil.WriteResponse(w, &out)
}

func getContent(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		PackId uint32
	}
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//query from db
	row := packDB.QueryRow("SELECT images FROM packs WHERE id=?", in.PackId)
	var strImg []byte
	err = row.Scan(&strImg)
	lwutil.CheckError(err, "")

	type Image struct {
		Url   string
		Title string
		Text  string
	}
	var images []Image
	json.Unmarshal(strImg, &images)

	//out
	out := struct {
		Images []Image
	}{images}
	lwutil.WriteResponse(w, out)
}

func regPack() {
	http.Handle("/pack/add", lwutil.ReqHandler(add))
	http.Handle("/pack/edit", lwutil.ReqHandler(edit))
	http.Handle("/pack/del", lwutil.ReqHandler(del))
	http.Handle("/pack/get", lwutil.ReqHandler(get))
	http.Handle("/pack/count", lwutil.ReqHandler(count))
	http.Handle("/pack/list", lwutil.ReqHandler(list))
	http.Handle("/pack/getContent", lwutil.ReqHandler(getContent))
}
