package main

import (
	"encoding/json"
	"flag"
	"github.com/golang/glog"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

const (
	USEAGE = "Useage: packUploader new|update uploadDir"
)

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
	case "update":
		updatePack()
	default:
		glog.Errorln(USEAGE)
	}
}

func newPack() {
	var err error

	var f *os.File
	if f, err = os.Open("pack.js"); err != nil {
		glog.Errorf("Open pack.js error: err=%s", err.Error())
		return
	}
	defer f.Close()

	//json decode
	decoder := json.NewDecoder(f)
	pack := struct {
		Title string
		Text  string
		Cover string
		Icon  string
	}{}
	if err = decoder.Decode(&pack); err != nil {
		glog.Errorf("pack.js decode failed: err=%s", err.Error())
		return
	}

	//dir walk
	imgPaths := make([]string, 0, 0)
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
					imgPaths = append(imgPaths, path)
				}
			}
		}
		return nil
	})

	if pack.Icon == "" {
		glog.Errorln("Need icon")
		return
	}

	glog.Infoln(pack)
	glog.Infoln(imgPaths)
}

func updatePack() {

}
