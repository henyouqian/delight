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
	H_USERPACK       = "hUserPack"
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
	// _, err := findSession(w, r, nil)
	// lwutil.CheckError(err, "err_auth")

	//in
	var in Pack
	err = lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

	//ssdb
	ssdb, err := ssdbPool.Get()
	lwutil.CheckError(err, "")
	defer ssdb.Close()

	//gen packid
	resp, err := ssdb.Do("hincr", H_SERIAL, "userPack", 1)
	lwutil.CheckSsdbError(resp, err)
	in.Id, _ = strconv.ParseUint(resp[1], 10, 32)

	//save to ssdb
	jsPack, _ := json.Marshal(&in)
	resp, err = ssdb.Do("hset", in.Id, H_USERPACK, jsPack)
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

	resp, err := ssdb.Do("hget", in.Id, H_USERPACK, in.Id)
	lwutil.CheckSsdbError(resp, err)

	var pack Pack
	err = json.Unmarshal([]byte(resp[1]), &pack)
	lwutil.CheckError(err, "")

	//out
	lwutil.WriteResponse(w, &pack)
}

func regUserPack() {
	http.Handle("/userPack/getUploadToken", lwutil.ReqHandler(getUploadToken))
	http.Handle("/userPack/newPack", lwutil.ReqHandler(newUserPack))
	http.Handle("/userPack/get", lwutil.ReqHandler(getUserPack))
}
