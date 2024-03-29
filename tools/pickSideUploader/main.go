package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"github.com/golang/glog"
	qiniuconf "github.com/qiniu/api/conf"
	qiniuio "github.com/qiniu/api/io"
	qiniurs "github.com/qiniu/api/rs"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

const (
	USEAGE = "Useage: \n\tpickSideUploader <uploadDir>"
	HOST   = "http://dn-pintugame.qbox.me"

	PACK_JS       = "pack.js"
	PACK_RESP_JS  = "respPack.js"
	EVENT_JS      = "event.js"
	EVENT_RESP_JS = "respEvent.js"
)

var (
	_userToken = ""
	_conf      Conf
	_startId   int
	_limit     int
)

type Conf struct {
	UserName    string
	Password    string
	ServerHost  string
	QiniuBucket string
}

type Image struct {
	File  string
	Key   string
	Title string
	Text  string
}

type Pack struct {
	Id        int64
	Title     string
	Text      string
	Cover     string
	CoverBlur string
	Thumb     string
	Images    []Image
	Tags      []string
}

type Event struct {
	Id            int64
	PackId        int64
	SliderNum     int
	ChallengeSecs [3]int
	QuestionTitle string
	Question      string
	Sides         []string
}

func init() {
	qiniuconf.ACCESS_KEY = "XLlx3EjYfZJ-kYDAmNZhnH109oadlGjrGsb4plVy"
	qiniuconf.SECRET_KEY = "FQfB3pG4UCkQZ3G7Y9JW8az2BN1aDkIJ-7LKVwTJ"

	//conf
	var f *os.File
	var err error

	if f, err = os.Open("conf.json"); err != nil {
		panic(err)
	}
	defer f.Close()

	//json decode
	decoder := json.NewDecoder(f)
	err = decoder.Decode(&_conf)
	if err != nil {
		panic(err)
	}
}

func checkErr(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())
	glog.Infof("start: cpu=%d", runtime.NumCPU())

	flag.Parse()
	if len(flag.Args()) != 1 {
		glog.Errorln(USEAGE)
		return
	}

	workDir := flag.Arg(0)
	if workDir == "" {
		glog.Errorln(USEAGE)
		return
	}

	login()

	os.Chdir(workDir)

	packId := newPack()
	if packId > 0 {
		newEventBuff(packId)
	}
}

func newPack() (rPackId int64) {
	var err error

	//check exist
	if _, err := os.Stat(PACK_RESP_JS); err == nil {
		glog.Errorf("%s exist, uploaded already?", PACK_RESP_JS)
		return 0
	}

	//
	pack := Pack{}
	err = loadPack(&pack)
	checkErr(err)
	packRaw := pack

	if pack.Title == "" {
		glog.Errorln("need title")
		return 0
	}

	//check image file exist
	for _, img := range pack.Images {
		if _, err := os.Stat(img.File); os.IsNotExist(err) {
			glog.Errorf("no such file: file=%s", img.File)
			return 0
		}
	}

	//dir walk
	err = filepath.Walk(".", func(path string, f os.FileInfo, err error) error {
		_, fileName := filepath.Split(path)
		parts := strings.Split(fileName, ".")
		if len(parts) > 1 {
			ext := parts[len(parts)-1]
			lower := strings.ToLower(ext)
			if lower == "jpg" || lower == "jpeg" || lower == "gif" || lower == "png" {
				if parts[0] == "thumb" {
					pack.Thumb = path
				} else if parts[0] == "cover" {
					pack.Cover = path
				} else if parts[0] == "coverBlur" {
					pack.CoverBlur = path
				} else {
					key := genImageKey(path)

					//search defined image
					found := false
					for i, img := range pack.Images {
						if path == img.File {
							pack.Images[i].Key = key
							found = true
							break
						}
					}
					if !found {
						img := Image{}
						img.File = path
						img.Key = key
						pack.Images = append(pack.Images, img)
					}
				}
			}
		}
		return nil
	})

	//check thumb
	if pack.Thumb == "" {
		glog.Errorln("Need thumb")
		return 0
	}

	//check cover
	if pack.Cover == "" {
		glog.Errorln("Need cover")
		return 0
	}

	//check cover blur
	if pack.CoverBlur == "" {
		glog.Warning("No cover blur")
	}

	//upload to qiniu
	glog.Info("upload begin")

	uploadImgs := pack.Images

	///append cover image
	coverKey := genImageKey(pack.Cover)
	coverImg := Image{
		File: pack.Cover,
		Key:  coverKey,
	}
	uploadImgs = append(uploadImgs, coverImg)
	pack.Cover = coverKey

	///append thumb image
	thumbKey := genImageKey(pack.Thumb)
	thumbImg := Image{
		File: pack.Thumb,
		Key:  thumbKey,
	}
	uploadImgs = append(uploadImgs, thumbImg)
	pack.Thumb = thumbKey

	///append coverBlur image
	if len(pack.CoverBlur) != 0 {
		coverBlurKey := genImageKey(pack.CoverBlur)
		coverBlurImg := Image{
			File: pack.CoverBlur,
			Key:  coverBlurKey,
		}
		uploadImgs = append(uploadImgs, coverBlurImg)
		pack.CoverBlur = coverBlurKey
	}

	///upload
	rsCli := qiniurs.New(nil)
	imgNum := len(uploadImgs)
	entryPathes := make([]qiniurs.EntryPath, imgNum)
	imgExists := make([]bool, imgNum)
	for i, img := range uploadImgs {
		entryPathes[i].Bucket = _conf.QiniuBucket
		entryPathes[i].Key = img.Key
		imgExists[i] = false
	}
	var batchStatRets []qiniurs.BatchStatItemRet
	batchStatRets, _ = rsCli.BatchStat(nil, entryPathes)

	for i, item := range batchStatRets {
		if item.Code == 200 {
			imgExists[i] = true
		}
	}

	///gen token
	putPolicy := qiniurs.PutPolicy{
		Scope: _conf.QiniuBucket,
	}
	token := putPolicy.Token(nil)

	///upload images
	for i, img := range uploadImgs {
		if imgExists[i] {
			glog.Infof("image exist: %s", img.File)
			continue
		}
		var ret qiniuio.PutRet
		err = qiniuio.PutFile(nil, &ret, token, img.Key, img.File, nil)
		checkErr(err)
		glog.Infof("upload image ok: %s", img.File)
	}

	glog.Info("upload complete")

	//add new pack to server
	packjs, err := json.Marshal(pack)
	checkErr(err)

	packBytes := postReq("pack/new", packjs)

	//update pack.js
	var dwpack Pack
	err = json.Unmarshal(packBytes, &dwpack)
	checkErr(err)

	packRaw.Id = dwpack.Id

	//packjs, err = json.Marshal(packRaw)
	packjs, err = json.Marshal(dwpack)
	checkErr(err)

	//
	buf := bytes.NewBuffer([]byte(""))
	json.Indent(buf, packjs, "", "\t")

	rewriteFile(PACK_RESP_JS, buf.Bytes())

	glog.Infof("add pack succeed: packId=%d, server=%s", packRaw.Id, _conf.ServerHost)

	return packRaw.Id
}

func newEventBuff(packId int64) {
	//check exist
	if _, err := os.Stat(EVENT_RESP_JS); err == nil {
		glog.Errorf("%s exist, uploaded already?", EVENT_RESP_JS)
		return
	}

	event, err := loadEvent()
	checkErr(err)
	event.PackId = packId

	js, err := json.Marshal(event)
	checkErr(err)
	resp := postReq("pickSide/buffAdd", js)

	//save to eventResp.js
	buf := bytes.NewBuffer([]byte(""))
	json.Indent(buf, resp, "", "\t")

	rewriteFile(EVENT_RESP_JS, buf.Bytes())

	glog.Infof("new pickSide buff succeed:server=%s", _conf.ServerHost)
}

func rewriteFile(path string, content []byte) {
	f, err := os.Create(path)
	defer f.Close()
	checkErr(err)

	f.Seek(0, os.SEEK_SET)
	f.Truncate(0)
	f.Write(content)
}

func loadPack(pack *Pack) (err error) {
	var f *os.File
	if f, err = os.OpenFile(PACK_JS, os.O_RDWR, 0666); err != nil {
		glog.Errorf("Open %s error: err=%s", PACK_JS, err.Error())
		return err
	}
	defer f.Close()

	//json decode
	decoder := json.NewDecoder(f)
	err = decoder.Decode(&pack)
	checkErr(err)
	return nil
}

func loadPackResp(pack *Pack) (err error) {
	var f *os.File
	if f, err = os.OpenFile(PACK_RESP_JS, os.O_RDWR, 0666); err != nil {
		glog.Errorf("Open %s error: err=%s", PACK_RESP_JS, err.Error())
		return err
	}
	defer f.Close()

	//json decode
	decoder := json.NewDecoder(f)
	err = decoder.Decode(&pack)
	checkErr(err)
	return nil
}

func loadEvent() (rEvent *Event, rErr error) {
	var f *os.File
	var err error
	if f, err = os.OpenFile("event.js", os.O_RDWR, 0666); err != nil {
		glog.Errorf("Open event.js error: err=%s", err.Error())
		return nil, err
	}
	defer f.Close()

	event := new(Event)

	//json decode
	decoder := json.NewDecoder(f)
	err = decoder.Decode(event)
	checkErr(err)
	return event, nil
}

func uploadImage() {
	path := flag.Arg(1)
	key := genImageKey(path)

	glog.Infof("key=%s", key)

	//gen token
	putPolicy := qiniurs.PutPolicy{
		Scope: _conf.QiniuBucket,
	}
	token := putPolicy.Token(nil)

	//upload
	var ret qiniuio.PutRet
	err := qiniuio.PutFile(nil, &ret, token, key, path, nil)
	checkErr(err)
	glog.Infof("upload image ok: path=%s", path)
}

func login() {
	client := &http.Client{}

	url := _conf.ServerHost + "auth/login"
	body := fmt.Sprintf(`{
	    "Username": "%s",
	    "Password": "%s"
	}`, _conf.UserName, _conf.Password)

	resp, err := client.Post(url, "application/json", bytes.NewReader([]byte(body)))
	checkErr(err)
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		glog.Fatalf("Login Error: username=%s", _conf.UserName)
		//glog.Fatalf("login error: resp.StatusCode != 200, =%d, url=%s", resp.StatusCode, url)
	}
	bts, err := ioutil.ReadAll(resp.Body)
	checkErr(err)

	msg := struct {
		Token string
	}{}
	err = json.Unmarshal(bts, &msg)
	checkErr(err)
	_userToken = msg.Token
}

func postReq(partialUrl string, body []byte) (respBytes []byte) {
	url := _conf.ServerHost + partialUrl

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	req.AddCookie(&http.Cookie{Name: "usertoken", Value: _userToken})

	client := &http.Client{}
	resp, err := client.Do(req)
	checkErr(err)
	defer resp.Body.Close()
	respBytes, _ = ioutil.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		glog.Errorf("resp.StatusCode != 200, =%d, url=%s", resp.StatusCode, url)
		glog.Errorf("resp = %s", string(respBytes))
		os.Exit(1)
	}
	return respBytes
}

func genImageKey(inFileName string) (outFileName string) {
	data, err := ioutil.ReadFile(inFileName)
	checkErr(err)
	h := sha1.New()
	h.Write(data)
	shaBytes := h.Sum(nil)

	ext := filepath.Ext(inFileName)
	ext = strings.ToLower(ext)
	if ext == "jpeg" {
		ext = "jpg"
	}
	outFileName = base64.URLEncoding.EncodeToString(shaBytes) + ext
	return
}
