// Copyright 2013 The Go-IMAP Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/mail"
	"strconv"
	"strings"
	"time"

	"github.com/famz/RFC2047"
	"github.com/golang/glog"
	"github.com/mxk/go-imap/imap"
)

const (
	// Addr = "imap.gmail.com:993"
	// User = "henyouqian@gmail.com"
	// Pass = "nmmgblzksn"
	// MBox = "INBOX"

	// Addr = "imap.qq.com:993"
	// User = "madeingermany@qq.com"
	// Pass = "nmmgbnmmgb"
	// MBox = "z"

	Addr = "imap.163.com:993"
	User = "15921062294@163.com"
	Pass = "Nmmgb808313"
	MBox = "z"

	AMAZON_EMAIL    = "gc-orders@gc.email.amazon.cn"
	PROVIDER_AMAZON = "amazon"

	ADMIN_ACCOUNT  = "henyouqian@gmail.com"
	ADMIN_PASSWORD = "Nmmgb808313"
	SLD_SERVER_URL = "http://localhost:9998/"
	// SLD_SERVER_URL = "http://sld.pintugame.com/"

)

type Ecard struct {
	Provider string
	RmbPrice float32
	Code     string
}

var (
	_userToken = ""
	_conf      Conf
	_startId   int
	_limit     int
)

type Conf struct {
	UserName   string
	Password   string
	ServerHost string
}

func main() {
	flag.Parse()

	//
	_conf.UserName = ADMIN_ACCOUNT
	_conf.Password = ADMIN_PASSWORD
	_conf.ServerHost = SLD_SERVER_URL

	glog.Info("starting..........")
	// imap.DefaultLogger = log.New(os.Stdout, "", 0)
	// imap.DefaultLogMask = imap.LogConn | imap.LogRaw

	c := Dial(Addr)
	defer func() { ReportOK(c.Logout(30 * time.Second)) }()

	// if c.Caps["STARTTLS"] {
	// 	ReportOK(c.StartTLS(nil))
	// }

	if c.Caps["ID"] {
		ReportOK(c.ID("name", "goimap"))
	}

	// ReportOK(c.Noop())
	ReportOK(Login(c, User, Pass))

	if c.Caps["QUOTA"] {
		ReportOK(c.GetQuotaRoot("INBOX"))
	}

	cmd := ReportOK(c.List("", "%"))

	// glog.Info("\nTop-level mailboxes:")
	// for _, rsp := range cmd.Data {
	// 	glog.Info("|--", rsp.MailboxInfo())
	// }

	c.Select(MBox, false)
	msgId := int(c.Mailbox.Messages)
	batchNum := 4

	glog.Info(msgId)

	ecards := make([]Ecard, 0)

	for true {
		if msgId <= 0 {
			break
		}

		set, _ := imap.NewSeqSet("")
		msgIdMin := msgId - batchNum + 1
		if msgIdMin < 1 {
			msgIdMin = 1
		}

		set.AddRange(uint32(msgIdMin), uint32(msgId))
		msgId = msgIdMin - 1

		bodySet, _ := imap.NewSeqSet("")

		//header
		cmd, _ = c.Fetch(set, "RFC822.HEADER")

		for cmd.InProgress() {
			// Wait for the next response (no timeout)
			c.Recv(-1)

			// Process command data
			// for i := len(cmd.Data) - 1; i >= 0; i-- {
			for i := 0; i < len(cmd.Data); i++ {
				rsp := cmd.Data[i]
				header := imap.AsBytes(rsp.MessageInfo().Attrs["RFC822.HEADER"])

				if msg, _ := mail.ReadMessage(bytes.NewReader(header)); msg != nil {
					from := msg.Header.Get("From")
					subject := msg.Header.Get("Subject")
					subject = RFC2047.Decode(subject)
					// glog.Info(subject)
					if strings.Contains(from, AMAZON_EMAIL) {
						bodySet.AddNum(rsp.MessageInfo().Seq)
					}
				}
			}

			cmd.Data = nil

			// Process unilateral server data
			for _, rsp := range c.Data {
				fmt.Println("Server data:", rsp)
			}
			c.Data = nil
		}

		//body
		cmd, _ = c.Fetch(bodySet, "BODY[]")
		ecardsBuff := make([]Ecard, 0)
		for cmd.InProgress() {
			// Wait for the next response (no timeout)
			c.Recv(-1)

			// Process command data
			for _, rsp := range cmd.Data {
				body := imap.AsBytes(rsp.MessageInfo().Attrs["BODY[]"])

				msg, err := mail.ReadMessage(bytes.NewReader(body))
				if msg != nil {
					from := msg.Header.Get("From")

					//amazon
					if strings.Contains(from, AMAZON_EMAIL) {
						bts, _ := ioutil.ReadAll(msg.Body)
						str := string(bts)

						yen := "=EF=BF=A5"
						priceIdx := strings.Index(str, yen)
						priceStr := str[priceIdx+len(yen):]
						priceIdx = strings.Index(priceStr, "\n")
						priceStr = priceStr[0 : priceIdx-1]
						price, _ := strconv.ParseFloat(priceStr, 32)

						strs := strings.Split(str, "Claim code ")
						code := strs[1]
						n := strings.Index(code, "\n")
						code = code[0 : n-1]

						// expireIdx := strings.Index(str, yen)

						var ecard Ecard
						ecard.Provider = PROVIDER_AMAZON
						ecard.RmbPrice = float32(price)
						ecard.Code = code
						ecardsBuff = append(ecardsBuff, ecard)
					}
				}
				if err != nil {
					glog.Errorln(err)
				}

			}
			cmd.Data = nil

			// Process unilateral server data
			for _, rsp := range c.Data {
				fmt.Println("Server data:", rsp)
			}
			c.Data = nil
		}

		//ecardsBuff to ecards
		n := len(ecardsBuff)
		for i, _ := range ecardsBuff {
			ecard := ecardsBuff[n-i-1]
			ecards = append(ecards, ecard)
		}
	}

	// //just for test
	// ecards = []Ecard{
	// 	{PROVIDER_AMAZON, 10, "5"},
	// 	{PROVIDER_AMAZON, 10, "6"},
	// 	{PROVIDER_AMAZON, 10, "7"},
	// }

	//print
	js, err := json.MarshalIndent(ecards, "", "\t")
	checkErr(err)
	glog.Info(string(js))

	return

	//add to server
	if len(ecards) > 0 {
		loginSldServer()
	}
	for _, ecard := range ecards {
		glog.Info(ecard)

		continue

		body := map[string]interface{}{
			"Provider": ecard.Provider,
			"RmbPrice": ecard.RmbPrice,
			"Code":     ecard.Code,
		}

		js, err := json.Marshal(body)
		checkErr(err)

		bytes, err := postReq("store/addEcard", js)

		if err != nil {
			respMap := map[string]interface{}{}
			err = json.Unmarshal(bytes, &respMap)
			checkErr(err)
			glog.Error("add err: ", respMap)
		} else {
			glog.Info("add ok: ", ecard)
		}
	}
}

func Dial(addr string) (c *imap.Client) {
	var err error
	if strings.HasSuffix(addr, ":993") {
		c, err = imap.DialTLS(addr, nil)
	} else {
		c, err = imap.Dial(addr)
	}
	if err != nil {
		panic(err)
	}
	return c
}

func Login(c *imap.Client, user, pass string) (cmd *imap.Command, err error) {
	defer c.SetLogMask(Sensitive(c, "LOGIN"))
	return c.Login(user, pass)
}

func Sensitive(c *imap.Client, action string) imap.LogMask {
	mask := c.SetLogMask(imap.LogConn)
	hide := imap.LogCmd | imap.LogRaw
	if mask&hide != 0 {
		c.Logln(imap.LogConn, "Raw logging disabled during", action)
	}
	c.SetLogMask(mask &^ hide)
	return mask
}

func ReportOK(cmd *imap.Command, err error) *imap.Command {
	// var rsp *imap.Response
	if cmd == nil {
		// fmt.Printf("--- ??? ---\n%v\n\n", err)
		panic(err)
	} else if err == nil {
		// rsp, err = cmd.Result(imap.OK)
	}
	if err != nil {
		// fmt.Printf("--- %s ---\n%v\n\n", cmd.Name(true), err)
		panic(err)
	}
	c := cmd.Client()
	// fmt.Printf("--- %s ---\n"+
	// 	"%d command response(s), %d unilateral response(s)\n"+
	// 	"%s %s\n\n",
	// 	cmd.Name(true), len(cmd.Data), len(c.Data), rsp.Status, rsp.Info)

	cmd.Result(imap.OK)
	c.Data = nil
	return cmd
}

func checkErr(err error) {
	if err != nil {
		panic(err)
	}
}

func loginSldServer() {
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

func postReq(partialUrl string, body []byte) (respBytes []byte, err error) {
	url := _conf.ServerHost + partialUrl

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	req.AddCookie(&http.Cookie{Name: "usertoken", Value: _userToken})

	client := &http.Client{}
	resp, err := client.Do(req)
	checkErr(err)
	defer resp.Body.Close()
	respBytes, _ = ioutil.ReadAll(resp.Body)

	if resp.StatusCode != 200 {
		return respBytes, fmt.Errorf("resp.StatusCode != 200, =%d, url=%s", resp.StatusCode, url)
	}
	return respBytes, nil
}

func makeEcardTypeKey(provider string, price int) string {
	return fmt.Sprintf("%s/%d", provider, price)
}
