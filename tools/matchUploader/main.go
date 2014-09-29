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
	// "io"
	"io/ioutil"
	"net/http"
	"os"
	// "os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

const (
	USEAGE = "Useage: \n\tmatchUploader confFile new|del <uploadDir> \n\tor matchUploader confFile img <imageFile>"

	MATCH_JS      = "match.js"
	MATCH_RESP_JS = "respMatch.js"

	QINIU_ACCESS_KEY = "XLlx3EjYfZJ-kYDAmNZhnH109oadlGjrGsb4plVy"
	QINIU_SECRET_KEY = "FQfB3pG4UCkQZ3G7Y9JW8az2BN1aDkIJ-7LKVwTJ"
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

type Match struct {
	Id               int64
	Title            string
	Cover            string
	CoverBlur        string
	Thumb            string
	Images           []Image
	BeginTimeStr     string
	SliderNum        int
	CouponReward     int
	ChallengeSeconds int
	PromoUrl         string
	PromoImage       string
}

func init() {
	qiniuconf.ACCESS_KEY = QINIU_ACCESS_KEY
	qiniuconf.SECRET_KEY = QINIU_SECRET_KEY
}

func checkErr(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())
	glog.Infof("start: cpu=%d", runtime.NumCPU())

	flag.IntVar(&_startId, "startId", 0, "")
	flag.IntVar(&_limit, "limit", 100, "")

	flag.Parse()

	//conf
	confFile := flag.Arg(0)
	if confFile == "" {
		glog.Errorln(USEAGE)
		return
	}

	var f *os.File
	var err error

	if f, err = os.Open(confFile); err != nil {
		panic(err)
	}
	defer f.Close()

	//conf decode
	decoder := json.NewDecoder(f)
	err = decoder.Decode(&_conf)
	if err != nil {
		panic(err)
	}

	workDir := flag.Arg(2)
	if workDir == "" {
		glog.Errorln(USEAGE)
		return
	}

	login()

	os.Chdir(workDir)

	switch flag.Arg(1) {
	case "new":
		newMatch()
	case "del":
		delMatch()
	case "img":
		uploadImage()
	default:
		glog.Errorln(USEAGE)
	}
}

func newMatch() (rPackId int64) {
	var err error

	//check exist
	if _, err := os.Stat(MATCH_RESP_JS); err == nil {
		glog.Errorf("%s exist, uploaded already?", MATCH_RESP_JS)
		return 0
	}

	//
	match := loadMatch()

	//dir walk
	err = filepath.Walk(".", func(path string, f os.FileInfo, err error) error {
		_, fileName := filepath.Split(path)
		parts := strings.Split(fileName, ".")
		if len(parts) > 1 {
			ext := parts[len(parts)-1]
			lower := strings.ToLower(ext)
			if lower == "jpg" || lower == "jpeg" || lower == "gif" || lower == "png" {
				if parts[0] == "thumb" {
					match.Thumb = path
				} else if parts[0] == "cover" {
					match.Cover = path
				} else if parts[0] == "coverBlur" {
					match.CoverBlur = path
				} else if parts[0] == "promo" {
					match.PromoImage = path
				} else {
					key := genImageKey(path)

					//search defined image
					found := false
					for i, img := range match.Images {
						if path == img.File {
							match.Images[i].Key = key
							found = true
							break
						}
					}
					if !found {
						img := Image{}
						img.File = path
						img.Key = key
						match.Images = append(match.Images, img)
					}
				}
			}
		}
		return nil
	})

	//check thumb
	if match.Thumb == "" {
		glog.Errorln("Need thumb")
		return 0
	}

	//check cover
	if match.Cover == "" {
		glog.Errorln("Need cover")
		return 0
	}

	//check cover blur
	if match.CoverBlur == "" {
		glog.Warning("No cover blur")
	}

	//upload to qiniu
	glog.Info("upload begin")

	uploadImgs := match.Images

	///append cover image
	coverKey := genImageKey(match.Cover)
	coverImg := Image{
		File: match.Cover,
		Key:  coverKey,
	}
	uploadImgs = append(uploadImgs, coverImg)
	match.Cover = coverKey

	///append thumb image
	thumbKey := genImageKey(match.Thumb)
	thumbImg := Image{
		File: match.Thumb,
		Key:  thumbKey,
	}
	uploadImgs = append(uploadImgs, thumbImg)
	match.Thumb = thumbKey

	///append coverBlur image
	if len(match.CoverBlur) != 0 {
		coverBlurKey := genImageKey(match.CoverBlur)
		coverBlurImg := Image{
			File: match.CoverBlur,
			Key:  coverBlurKey,
		}
		uploadImgs = append(uploadImgs, coverBlurImg)
		match.CoverBlur = coverBlurKey
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

	//add match to server
	matchjs, err := json.Marshal(match)
	checkErr(err)

	matchBytes := postReq("match/new", matchjs)

	//update respMatch.js
	var respMatch Match
	err = json.Unmarshal(matchBytes, &respMatch)
	checkErr(err)

	//
	matchjs, err = json.Marshal(respMatch)
	checkErr(err)

	//
	buf := bytes.NewBuffer([]byte(""))
	json.Indent(buf, matchjs, "", "\t")

	rewriteFile(MATCH_RESP_JS, buf.Bytes())

	glog.Infof("add match succeed: matchId=%d, server=%s", respMatch.Id, _conf.ServerHost)

	return respMatch.Id
}

func delMatch() {
	var err error

	match := loadRespMatch()
	checkErr(err)

	if match.Id == 0 {
		glog.Fatalln("need match id")
	}

	//send msg to server
	body := fmt.Sprintf(`{
		"Id": %d
	}`, match.Id)
	postReq("match/del", []byte(body))

	glog.Infoln("del ok")
}

func uploadImage() {
	path := flag.Arg(2)
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

func rewriteFile(path string, content []byte) {
	f, err := os.Create(path)
	defer f.Close()
	checkErr(err)

	f.Seek(0, os.SEEK_SET)
	f.Truncate(0)
	f.Write(content)
}

func loadMatch() (match *Match) {
	var f *os.File
	var err error
	if f, err = os.OpenFile(MATCH_JS, os.O_RDWR, 0666); err != nil {
		checkErr(err)
	}
	defer f.Close()

	//json decode
	decoder := json.NewDecoder(f)
	err = decoder.Decode(&match)
	checkErr(err)
	return match
}

func loadRespMatch() (match *Match) {
	var f *os.File
	var err error
	if f, err = os.OpenFile(MATCH_RESP_JS, os.O_RDWR, 0666); err != nil {
		checkErr(err)
	}
	defer f.Close()

	//json decode
	decoder := json.NewDecoder(f)
	err = decoder.Decode(&match)
	checkErr(err)
	return match
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
