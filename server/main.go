package main

import (
	"flag"
	"fmt"
	"github.com/golang/glog"
	//"github.com/henyouqian/lwutil"
	"net/http"
	"runtime"
)

func staticFile(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, r.URL.Path[1:])
}

func html5(w http.ResponseWriter, r *http.Request) {
	url := fmt.Sprintf("%s%s", "..", r.URL.Path)
	http.ServeFile(w, r, url)
	//lwutil.WriteResponse(w, url)
}

func main() {
	var port int
	flag.IntVar(&port, "port", 9999, "server port")
	flag.Parse()

	http.HandleFunc("/www/", staticFile)
	http.HandleFunc("/html5/", html5)
	regAuth()
	regPack()
	regCollection()
	regPlayer()
	regMatch()

	runtime.GOMAXPROCS(runtime.NumCPU())

	glog.Infof("Server running: cpu=%d, port=%d", runtime.NumCPU(), port)
	glog.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", port), nil))
}
