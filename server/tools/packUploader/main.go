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
	USEAGE = "Useage: \n\tpackUploader new|del|update <uploadDir>\n\tpackUploader image <imagePath>"
)

var (
	_userToken = ""
	_conf      Conf
)

type Conf struct {
	UserName    string
	Password    string
	ServerHost  string
	QiniuBucket string
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

	workDir := flag.Arg(1)
	if workDir == "" {
		glog.Errorln(USEAGE)
		return
	}

	login()

	os.Chdir(workDir)

	switch flag.Arg(0) {
	case "new":
		newPack()
	case "del":
		delPack()
	case "update":
		updatePack()
	case "image":
		uploadImage()
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
	Id        uint64
	Title     string
	Text      string
	Cover     string
	CoverBlur string
	Thumb     string
	Images    []Image
	Tags      []string
}

type Account struct {
	Name     string
	Password string
}

func upload() {

}

func newPack() {
	var err error

	pack := Pack{}
	err = loadPack(&pack)
	checkErr(err)
	packRaw := pack

	if pack.Title == "" {
		glog.Errorln("need title")
		return
	}

	if pack.Id != 0 {
		glog.Errorln("Pack already uploaded?")
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
		return
	}

	//check cover
	if pack.Cover == "" {
		glog.Errorln("Need cover")
		return
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

	glog.Infof("add pack succeed: packId=%d", packRaw.Id)
}

func delPack() {
	var err error

	pack := Pack{}
	err = loadPack(&pack)
	checkErr(err)

	if pack.Id == 0 {
		glog.Fatalln("need pack id")
	}

	//send msg to server
	body := fmt.Sprintf(`{
		"Id": %d
	}`, pack.Id)
	postReq("pack/del", []byte(body))

	glog.Infoln("del ok")
}

func updatePack() {
	var err error

	pack := Pack{}
	err = loadPack(&pack)
	checkErr(err)
	packRaw := pack

	if pack.Title == "" {
		glog.Errorln("need title")
		return
	}

	if pack.Id == 0 {
		glog.Errorln("Pack not uploaded? Use new to create a pack.")
		return
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
		return
	}

	//check cover
	if pack.Cover == "" {
		glog.Errorln("Need cover")
		return
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

	//update pack to server
	packjs, err := json.Marshal(pack)
	checkErr(err)

	packBytes := postReq("pack/mod", packjs)

	//update pack.js
	var dwpack Pack
	err = json.Unmarshal(packBytes, &dwpack)
	checkErr(err)

	packRaw.Id = dwpack.Id

	//packjs, err = json.Marshal(packRaw)
	packjs, err = json.Marshal(dwpack)
	checkErr(err)

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

	glog.Infof("update pack succeed: packId=%d", packRaw.Id)
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
	err = decoder.Decode(&pack)
	checkErr(err)
	return nil
}

func loadAccount(account *Account) {
	var f *os.File
	var err error
	if f, err = os.Open("account.json"); err != nil {
		glog.Infoln("not found account.json, use admin")
		account.Name = _conf.UserName
		account.Password = _conf.Password
		return
	}
	defer f.Close()

	//json decode
	decoder := json.NewDecoder(f)
	err = decoder.Decode(&account)
	checkErr(err)

	glog.Infof("account: %s", account.Name)
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

	var account Account
	loadAccount(&account)

	url := _conf.ServerHost + "auth/login"
	body := fmt.Sprintf(`{
	    "Username": "%s",
	    "Password": "%s"
	}`, account.Name, account.Password)

	resp, err := client.Post(url, "application/json", bytes.NewReader([]byte(body)))
	checkErr(err)
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		glog.Fatalf("Login Error: username=%s", account.Name)
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
