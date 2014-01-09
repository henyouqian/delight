package main

import (
	//"github.com/garyburd/redigo/redis"
	"encoding/json"
	"github.com/henyouqian/lwutil"
	//"github.com/golang/glog"
	"math"
	"net/http"
)

func listToday(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	rc := redisPool.Get()
	defer rc.Close()

	//get time
	currTime := lwutil.GetRedisTime()

	//out
	out := struct {
		Time int64
	}{currTime.Unix()}
	lwutil.WriteResponse(w, out)
}

func list(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	rc := redisPool.Get()
	defer rc.Close()

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

func listPage(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	rc := redisPool.Get()
	defer rc.Close()

	//in
	var in struct {
		Page       uint32
		NumPerPage uint32
	}
	err := lwutil.DecodeRequestBody(r, &in)
	lwutil.CheckError(err, "err_decode_body")

}

func getContent(w http.ResponseWriter, r *http.Request) {
	lwutil.CheckMathod(r, "POST")

	rc := redisPool.Get()
	defer rc.Close()

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
	http.Handle("/pack/listToday", lwutil.ReqHandler(listToday))
	http.Handle("/pack/list", lwutil.ReqHandler(list))
	http.Handle("/pack/getContent", lwutil.ReqHandler(getContent))
}
