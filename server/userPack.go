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
	// "strings"
)

const (
	USER_PACK_BUCKET = "slideruserpack"
	H_USERPACK       = "hUserPack"    //key:packid, value:packData
	H_USEROWNPACK    = "hUserOwnPack" //key:userid, value:[]packid
)

func init() {
	ACCESS_KEY = "XLlx3EjYfZJ-kYDAmNZhnH109oadlGjrGsb4plVy"
	SECRET_KEY = "FQfB3pG4UCkQZ3G7Y9JW8az2BN1aDkIJ-7LKVwTJ"
}

func getUploadToken(w http.ResponseWriter, r *http.Request) {
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

func newUserPack(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in Pack
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	in.AuthorId = session.Userid

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//gen packid
	resp, err := ssdb.Do("hincr", H_SERIAL, "userPack", 1)
	lwutil.CheckSsdbError(resp, err)
	in.Id, _ = strconv.ParseUint(resp[1], 10, 32)

	//update user own pack
	packIds := make([]uint64, 0, 0)
	resp, err = ssdb.Do("hget", H_USEROWNPACK, session.Userid)
	lwutil.CheckError(err, "")
	if resp[0] == "ok" {
		err = json.Unmarshal([]byte(resp[1]), &packIds)
		lwutil.CheckError(err, "")
	}
	packIds = append(packIds, in.Id)
	jsPackIds, _ := json.Marshal(&packIds)
	resp, err = ssdb.Do("hset", H_USEROWNPACK, session.Userid, jsPackIds)
	lwutil.CheckSsdbError(resp, err)

	//save to ssdb
	jsPack, _ := json.Marshal(&in)
	resp, err = ssdb.Do("hset", H_USERPACK, in.Id, jsPack)
	lwutil.CheckSsdbError(resp, err)

	//out
	lwutil.WriteResponse(w, &in)
}

func getUserPack(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//in
	var in struct {
		Id uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	resp, err := ssdb.Do("hget", H_USERPACK, in.Id)
	lwutil.CheckSsdbError(resp, err)

	var pack Pack
	err = json.Unmarshal([]byte(resp[1]), &pack)
	lwutil.CheckError(err, "")

	//out
	lwutil.WriteResponse(w, &pack)
}

func getUserOwnPack(w http.ResponseWriter, r *http.Request) {
	var err error
	lwutil.CheckMathod(r, "POST")

	//session
	session, err := findSession(w, r, nil)
	lwutil.CheckError(err, "err_auth")

	//in
	var in struct {
		UserId uint64
	}
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")
	if in.UserId == 0 {
		in.UserId = session.Userid
	}

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//get own
	resp, err := ssdb.Do("hget", H_USEROWNPACK, in.UserId)
	lwutil.CheckError(err, "")
	if resp[0] == "ok" {
		w.Write([]byte(resp[1]))
	} else {
		w.Write([]byte("[]"))
	}
}

func regUserPack() {
	http.Handle("/userPack/getUploadToken", lwutil.ReqHandler(getUploadToken))
	http.Handle("/userPack/new", lwutil.ReqHandler(newUserPack))
	http.Handle("/userPack/get", lwutil.ReqHandler(getUserPack))
	http.Handle("/userPack/own", lwutil.ReqHandler(getUserOwnPack))
}
