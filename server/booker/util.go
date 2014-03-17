package main

import (
	// "fmt"
	// "github.com/golang/glog"
	//"github.com/henyouqian/lwutil"
	// "encoding/json"
	// "net/http"
	"../ssdb"
	"github.com/garyburd/redigo/redis"
	"math/rand"
	"strconv"
	"time"
)

var (
	redisPool *redis.Pool
	ssdbPool  *ssdb.Pool
)

func init() {
	redisPool = &redis.Pool{
		MaxIdle:     20,
		MaxActive:   0,
		IdleTimeout: 240 * time.Second,
		Dial: func() (redis.Conn, error) {
			c, err := redis.Dial("tcp", "localhost:6379")
			if err != nil {
				return nil, err
			}
			return c, err
		},
	}

	ssdbPool = ssdb.NewPool("localhost", 9876, 10, 60)
}

func checkError(err error) {
	if err != nil {
		panic(err)
	}
}

func checkSsdbError(resp []string, err error) {
	if err != nil {
		panic(err)
	} else if resp[0] != "ok" {
		panic(resp[0])
	}
}

func genSerial(ssdb *ssdb.Client, key string) (serial uint64) {
	resp, err := ssdb.Do("hincr", "hSerial", key, 1)
	checkSsdbError(resp, err)

	serial, err = strconv.ParseUint(resp[1], 10, 64)
	checkError(err)
	return
}

func shuffleArray(src []uint32) []uint32 {
	dest := make([]uint32, len(src))
	rand.Seed(time.Now().UTC().UnixNano())
	perm := rand.Perm(len(src))
	for i, v := range perm {
		dest[v] = src[i]
	}
	return dest
}
