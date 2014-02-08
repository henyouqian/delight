package main

import (
	// "encoding/json"
	"fmt"
	// "github.com/garyburd/redigo/redis"
	// "github.com/golang/glog"
	"github.com/henyouqian/lwutil"
	. "github.com/qiniu/api/conf"
	"github.com/qiniu/api/rs"
	"net/http"
	// "strconv"
	// "strings"
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
		scope := fmt.Sprintf("slideruserpack:%s", v)
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

func regUserPack() {
	http.Handle("/userPack/getUploadToken", lwutil.ReqHandler(getUploadToken))
}
