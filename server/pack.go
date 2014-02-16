package main

import (
	"encoding/json"
	"fmt"
	// "github.com/garyburd/redigo/redis"
	// "github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	. "github.com/qiniu/api/conf"
	"github.com/qiniu/api/rs"
	"net/http"
	"strconv"
)

const (
	ADMIN_USERID     = uint64(1)
	USER_PACK_BUCKET = "sliderpack"
	H_PACK           = "hPack"     //key:packId, value:packData
	Z_USER_PACK_PRE  = "zUserPack" //name:Z_USER_PACK_PRE/userId, key:packid, score:packid
)

type Image struct {
	File  string
	Key   string
	Title string
	Text  string
}

type Pack struct {
	Id       uint64
	AuthorId uint64
	Time     string
	Title    string
	Text     string
	Thumb    string
	Cover    string
	Images   []Image
}

func init() {
	ACCESS_KEY = "XLlx3EjYfZJ-kYDAmNZhnH109oadlGjrGsb4plVy"
	SECRET_KEY = "FQfB3pG4UCkQZ3G7Y9JW8az2BN1aDkIJ-7LKVwTJ"
}

func getUptoken(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	//in
	var in []string
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	inLen := len(in)
	type outElem struct {
		Key   string
		Token string
	}
	out := make([]outElem, inLen, inLen)
	for i, v := range in {
		scope := fmt.Sprintf("%s:%s", USER_PACK_BUCKET, v)
		putPolicy := rs.PutPolicy{
			Scope: scope,
		}
		out[i] = outElem{
			in[i],
			putPolicy.Token(nil),
		}
	}

	//out
	lwutil.WriteResponse(w, &out)
}

func newPack(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var pack Pack
	err = lwutil.DecodeRequestBody(r, &pack)
	lwutil.CheckError(err, "err_decode_body")
	pack.AuthorId = session.Userid

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//check pack exist if provide packId
	if pack.Id != 0 {
		resp, err := ssdb.Do("hexists", H_PACK, pack.Id)
		lwutil.CheckSsdbError(resp, err)
		if resp[1] == "1" {
			lwutil.SendError("err_exist", "pack already exist")
		}
	} else {
		//gen packid
		resp, err := ssdb.Do("hincr", H_SERIAL, "userPack", 1)
		lwutil.CheckSsdbError(resp, err)
		pack.Id, _ = strconv.ParseUint(resp[1], 10, 32)
	}

	//add to hash
	jsPack, _ := json.Marshal(&pack)
	resp, err := ssdb.Do("hset", H_PACK, pack.Id, jsPack)
	lwutil.CheckSsdbError(resp, err)

	//add to user pack zset
	name := fmt.Sprintf("%s/%d", Z_USER_PACK_PRE, session.Userid)
	resp, err = ssdb.Do("zset", name, pack.Id, pack.Id)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, pack)
}

func listPack(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		UserId  uint64
		StartId uint32
		Limit   uint32
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if in.UserId == 0 {
		in.UserId = ADMIN_USERID
	}
	if in.UserId > 60 {
		in.UserId = 60
	}

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get keys
	name := fmt.Sprintf("%s/%d", Z_USER_PACK_PRE, in.UserId)
	resp, err := ssdb.Do("zkeys", name, in.StartId, in.StartId, "", in.Limit)
	lwutil.CheckSsdbError(resp, err)

	if len(resp) == 1 {
		lwutil.SendError("err_not_found", "")
	}

	//get packs
	args := make([]interface{}, len(resp)+1)
	args[0] = "multi_hget"
	args[1] = H_PACK
	for i, _ := range args {
		if i >= 2 {
			args[i] = resp[i-1]
		}
	}
	resp, err = ssdb.Do(args...)
	lwutil.CheckSsdbError(resp, err)
	resp = resp[1:]

	packs := make([]Pack, len(resp)/2)
	for i, _ := range packs {
		packjs := resp[i*2+1]
		err = json.Unmarshal([]byte(packjs), &packs[i])
		lwutil.CheckError(err, "")
	}

	//out
	lwutil.WriteResponse(w, &packs)
}

func delPack(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		PackId uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//check owner
	name := fmt.Sprintf("%s/%d", Z_USER_PACK_PRE, session.Userid)
	resp, err := ssdb.Do("zexists", name, in.PackId)
	lwutil.CheckSsdbError(resp, err)
	if resp[1] == "0" {
		lwutil.SendError("err_not_exist", fmt.Sprintf("not own the pack: userId=%d, packId=%d", session.Userid, in.PackId))
	}
	resp, err = ssdb.Do("zdel", name, in.PackId)
	lwutil.CheckSsdbError(resp, err)
	resp, err = ssdb.Do("hdel", H_PACK, in.PackId)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, in)
}

func regPack() {
	http.Handle("/pack/getUptoken", lwutil.ReqHandler(getUptoken))
	http.Handle("/pack/new", lwutil.ReqHandler(newPack))
	http.Handle("/pack/list", lwutil.ReqHandler(listPack))
	http.Handle("/pack/del", lwutil.ReqHandler(delPack))
}
