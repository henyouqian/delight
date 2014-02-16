package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"errors"
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
	USEAGE         = "Useage: packUploader new|del|update uploadDir"
	BUCKET         = "sliderpack"
	SERVER_HOST    = "http://localhost:9999/"
	ADMIN_NAME     = "aa"
	ADMIN_PASSWORD = "aa"
)

var (
	_userToken = ""
)

func init() {
	qiniuconf.ACCESS_KEY = "XLlx3EjYfZJ-kYDAmNZhnH109oadlGjrGsb4plVy"
	qiniuconf.SECRET_KEY = "FQfB3pG4UCkQZ3G7Y9JW8az2BN1aDkIJ-7LKVwTJ"
}

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())
	glog.Infof("start: cpu=%d", runtime.NumCPU())

	flag.Parse()

	workDir := flag.Arg(1)
	if workDir == "" {
		glog.Errorln(USEAGE)
		return
	}

	os.Chdir(workDir)

	switch flag.Arg(0) {
	case "new":
		newPack()
	case "del":
		delPack()
	case "update":
		updatePack()
	default:
		glog.Errorln(USEAGE)
	}
}

type Image struct {
	File  string
	Key   string
	Title string
	Text  string
}
type Pack struct {
	Id     uint64
	Title  string
	Text   string
	Cover  string
	Icon   string
	Images []Image
}

func newPack() {
	var err error

	pack := Pack{}
	err = loadPack(&pack)
	if err != nil {
		glog.Errorf("loadPack failed: err=%s", err.Error())
		return
	}
	packRaw := pack

	if pack.Title == "" {
		glog.Errorln("need title")
		return
	}

	//check image file exist
	for _, img := range pack.Images {
		if _, err := os.Stat(img.File); os.IsNotExist(err) {
			glog.Errorf("no such file: file=%s", img.File)
			return
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
				if parts[0] == "icon" {
					pack.Icon = path
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

	//check icon
	if pack.Icon == "" {
		glog.Errorln("Need icon")
		return
	}

	//gen icon key
	iconKey := genImageKey(pack.Icon)

	//check cover
	if pack.Cover == "" {
		glog.Errorln("Need cover")
		return
	}

	//upload to qiniu
	glog.Info("upload begin")

	///check file exists
	uploadImgs := pack.Images
	iconImg := Image{
		File: pack.Icon,
		Key:  iconKey,
	}
	uploadImgs = append(uploadImgs, iconImg)

	rsCli := qiniurs.New(nil)
	imgNum := len(uploadImgs)
	entryPathes := make([]qiniurs.EntryPath, imgNum)
	imgExists := make([]bool, imgNum)
	for i, img := range uploadImgs {
		entryPathes[i].Bucket = BUCKET
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
		Scope: BUCKET,
	}
	token := putPolicy.Token(nil)

	// ///upload icon
	// var ret qiniuio.PutRet
	// if err = qiniuio.PutFile(nil, &ret, token, iconKey, pack.Icon, nil); err != nil {
	// 	panic(err)
	// }
	// glog.Infof("upload icon ok: %s", pack.Icon)

	///upload images
	for i, img := range uploadImgs {
		if imgExists[i] {
			glog.Infof("image exist: %s", img.File)
			continue
		}
		var ret qiniuio.PutRet
		if err = qiniuio.PutFile(nil, &ret, token, img.Key, img.File, nil); err != nil {
			panic(err)
		}
		glog.Infof("upload image ok: %s", img.File)
	}

	glog.Info("upload complete")

	//login
	login()

	//add new pack to server
	pack.Icon = iconKey
	pack.Cover = genImageKey(pack.Cover)

	packjs, err := json.Marshal(pack)
	if err != nil {
		panic(err)
	}

	packBytes := postReq("pack/new", packjs)

	//update pack.js
	var dwpack Pack
	err = json.Unmarshal(packBytes, &dwpack)
	if err != nil {
		panic(err)
	}

	packRaw.Id = dwpack.Id

	packjs, err = json.Marshal(packRaw)
	if err != nil {
		panic(err)
	}

	var f *os.File
	if f, err = os.OpenFile("pack.js", os.O_RDWR, 0666); err != nil {
		glog.Errorf("Open pack.js error: err=%s", err.Error())
		return
	}
	defer f.Close()

	f.Seek(0, os.SEEK_SET)
	f.Truncate(0)
	buf := bytes.NewBuffer([]byte(""))
	json.Indent(buf, packjs, "", "\t")
	f.Write(buf.Bytes())

	glog.Infoln("add pack succeed")
}

func delPack() {
	var err error

	pack := Pack{}
	err = loadPack(&pack)
	if err != nil {
		glog.Errorf("loadPack failed: err=%s", err.Error())
		return
	}

	login()

	//send msg to server
	body := fmt.Sprintf(`{
		"PackId": %d
	}`, pack.Id)
	postReq("pack/del", []byte(body))

	glog.Infoln("del ok")
}

func updatePack() {

}

func loadPack(pack *Pack) (err error) {
	var f *os.File
	if f, err = os.OpenFile("pack.js", os.O_RDWR, 0666); err != nil {
		glog.Errorf("Open pack.js error: err=%s", err.Error())
		return err
	}
	defer f.Close()

	//json decode
	decoder := json.NewDecoder(f)
	if err = decoder.Decode(&pack); err != nil {
		glog.Errorf("pack.js decode failed: err=%s", err.Error())
		return err
	}
	return nil
}

func login() {
	client := &http.Client{}

	url := SERVER_HOST + "auth/login"
	body := fmt.Sprintf(`{
	    "Username": "%s",
	    "Password": "%s"
	}`, ADMIN_NAME, ADMIN_PASSWORD)

	resp, err := client.Post(url, "application/json", bytes.NewReader([]byte(body)))
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		glog.Errorf("resp.StatusCode != 200, =%d, url=%s", resp.StatusCode, url)
		panic(errors.New("login error"))
	}
	tk, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}
	_userToken = string(tk)
	_userToken = _userToken[1 : len(_userToken)-2]
}

func postReq(partialUrl string, body []byte) (respBytes []byte) {
	url := SERVER_HOST + partialUrl

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	req.AddCookie(&http.Cookie{Name: "usertoken", Value: _userToken})

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
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
	if err != nil {
		panic(err)
	}
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
