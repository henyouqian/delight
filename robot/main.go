package main

import (
	"fmt"
	"github.com/golang/glog"
	// "github.com/henyouqian/lwutil"
	"bytes"
	"encoding/json"
	"flag"
	"io/ioutil"
	"math/rand"
	"net/http"
	"runtime"
	// "sync"
	"time"
)

const (
	PASSWORD = "aaa"
	HOST     = "http://localhost:9999"
)

var (
	TEAM_IDS = []uint32{
		11, 12, 13, 14, 15,
		21, 22, 23,
		31, 32, 33, 34, 35, 36, 37,
		41, 42, 43, 44, 45, 46,
		50, 51, 52, 53, 54,
		61, 62, 63, 64, 65,
		91, 92,
		71,
	}
)

func checkErr(err error) {
	if err != nil {
		glog.Fatalln(err)
	}
}

func register(userName string) {
	url := HOST + "/auth/register"

	body := struct {
		Username string
		Password string
	}{
		userName,
		PASSWORD,
	}
	bodyjs, err := json.Marshal(body)
	checkErr(err)
	resp, err := http.Post(url, "application/json", bytes.NewReader(bodyjs))
	checkErr(err)
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		glog.Errorf("register error: username=%s", userName)
		return
	}
	_, err = ioutil.ReadAll(resp.Body)
	checkErr(err)
	glog.Infof("register ok: %s", userName)
}

func login(userName string) *http.Cookie {
	url := HOST + "/auth/login"
	loginBody := struct {
		Username string
		Password string
	}{
		userName,
		PASSWORD,
	}
	loginBodyJs, err := json.Marshal(loginBody)
	checkErr(err)
	resp, err := http.Post(url, "application/json", bytes.NewReader(loginBodyJs))
	checkErr(err)
	defer resp.Body.Close()
	cookies := resp.Cookies()
	return cookies[0]
}

func post(userName string, url string, body []byte) (resp *http.Response) {
	cookie := login(userName)

	client := &http.Client{}
	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	checkErr(err)
	req.AddCookie(cookie)

	resp, err = client.Do(req)
	checkErr(err)
	return
}

func freePlay(userName string, matchId uint32, minScore int32, maxScore int32) {
	//free play
	url := HOST + "/match/freePlay"
	score := minScore + int32(rand.Int())%(maxScore-minScore)
	body := struct {
		MatchId uint32
		Score   int32
	}{
		matchId,
		score,
	}
	bodyjs, err := json.Marshal(body)
	checkErr(err)

	_resp := post(userName, url, bodyjs)
	defer _resp.Body.Close()

	resp, err := ioutil.ReadAll(_resp.Body)
	glog.Info(string(resp))
}

func play(userName string, eventId uint64, minScore int32, maxScore int32) {
	//playBegin
	url := HOST + "/event/playBegin"
	body := struct {
		EventId uint64
	}{
		eventId,
	}
	bodyjs, err := json.Marshal(body)
	checkErr(err)

	_resp := post(userName, url, bodyjs)
	defer _resp.Body.Close()

	resp, err := ioutil.ReadAll(_resp.Body)
	checkErr(err)

	if _resp.StatusCode != 200 {
		glog.Fatalf("http code=%d, body=%s", _resp.StatusCode, string(resp))
	}

	secret := struct {
		Secret string
	}{}
	err = json.Unmarshal(resp, &secret)
	checkErr(err)

	//playEnd
	url = HOST + "/event/playEnd"
	score := minScore + int32(rand.Int())%(maxScore-minScore)
	playEndBody := struct {
		EventId uint64
		Secret  string
		Score   int32
	}{
		eventId,
		secret.Secret,
		score,
	}
	bodyjs, err = json.Marshal(playEndBody)
	checkErr(err)

	_resp = post(userName, url, bodyjs)
	defer _resp.Body.Close()
	resp, err = ioutil.ReadAll(_resp.Body)
	checkErr(err)
	glog.Info(string(resp))
}

func setInfo(userName string) {
	url := HOST + "/player/setInfo"
	teamId := TEAM_IDS[rand.Int()%len(TEAM_IDS)]

	body := struct {
		TeamId uint32
	}{
		teamId,
	}
	bodyjs, err := json.Marshal(body)
	checkErr(err)

	_resp := post(userName, url, bodyjs)
	defer _resp.Body.Close()

	resp, err := ioutil.ReadAll(_resp.Body)
	glog.Info(string(resp))
}

func main() {
	flag.Parse()
	runtime.GOMAXPROCS(runtime.NumCPU())

	glog.Infof("Robot running: cpu=%d", runtime.NumCPU())

	rand.Seed(time.Now().UnixNano())

	for i := 0; i < 1000; i++ {
		username := fmt.Sprintf("test%d", i)
		//register(username)
		//setInfo(username)
		play(username, 10, -1000*60, -1000*10)
	}

	// var w sync.WaitGroup
	// w.Add(1)
	// w.Wait()
}
