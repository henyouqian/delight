package main

import (
	"fmt"
	"github.com/golang/glog"
	"net/http"
	"runtime"
)

func init() {

}

func staticFile(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, r.URL.Path[1:])
}

func main() {
	http.HandleFunc("/", staticFile)

	runtime.GOMAXPROCS(runtime.NumCPU())

	port := 7777
	glog.Infof("Server running: cpu=%d, port=%d", runtime.NumCPU(), port)
	glog.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", port), nil))
}
