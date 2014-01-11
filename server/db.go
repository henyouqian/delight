package main

import (
	"database/sql"
	"fmt"
	"github.com/garyburd/redigo/redis"
	_ "github.com/go-sql-driver/mysql"
	//"github.com/henyouqian/lwutil"
	"time"
)

var (
	redisPool     *redis.Pool
	authRedisPool *redis.Pool
	authDB        *sql.DB
	packDB        *sql.DB
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
	authRedisPool = &redis.Pool{
		MaxIdle:     10,
		MaxActive:   0,
		IdleTimeout: 240 * time.Second,
		Dial: func() (redis.Conn, error) {
			c, err := redis.Dial("tcp", "localhost:6379")
			if err != nil {
				return nil, err
			}
			c.Do("SELECT", 10)
			return c, err
		},
	}

	authDB = opendb("auth_db")
	authDB.SetMaxIdleConns(10)

	packDB = opendb("pack_db")
	packDB.SetMaxIdleConns(10)
}

func opendb(dbname string) *sql.DB {
	db, err := sql.Open("mysql", fmt.Sprintf("root@/%s?parseTime=true", dbname))
	if err != nil {
		panic(err)
	}
	return db
}
