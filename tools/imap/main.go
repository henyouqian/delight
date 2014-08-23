// Copyright 2013 The Go-IMAP Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"flag"
	"fmt"
	"io/ioutil"
	// "log"
	"net/mail"
	// "os"
	"strings"
	"time"

	"github.com/golang/glog"
	"github.com/mxk/go-imap/imap"
)

const (
	// Addr = "imap.gmail.com:993"
	// User = "henyouqian@gmail.com"
	// Pass = "nmmgblzksn"
	// MBox = "INBOX"

	Addr = "imap.qq.com:993"
	User = "madeingermany@qq.com"
	Pass = "nmmgbnmmgb"
	MBox = "INBOX"
)

const Msg = `
Subject: GoIMAP
From: GoIMAP <goimap@example.org>

hello, world

`

func main() {
	flag.Parse()

	glog.Info("starting..........")
	// imap.DefaultLogger = log.New(os.Stdout, "", 0)
	// imap.DefaultLogMask = imap.LogConn | imap.LogRaw

	c := Dial(Addr)
	defer func() { ReportOK(c.Logout(30 * time.Second)) }()

	if c.Caps["STARTTLS"] {
		ReportOK(c.StartTLS(nil))
	}

	if c.Caps["ID"] {
		ReportOK(c.ID("name", "goimap"))
	}

	// ReportOK(c.Noop())
	ReportOK(Login(c, User, Pass))

	if c.Caps["QUOTA"] {
		ReportOK(c.GetQuotaRoot("INBOX"))
	}

	cmd := ReportOK(c.List("", ""))
	// delim := cmd.Data[0].MailboxInfo().Delim

	fmt.Println("\nTop-level mailboxes:")
	for _, rsp := range cmd.Data {
		fmt.Println("|--", rsp.MailboxInfo())
	}

	c.Select("INBOX", false)
	fmt.Print("\nMailbox status:\n", c.Mailbox)

	fmt.Printf("Msgs: %d\n", c.Mailbox.Messages)

	// Fetch the headers of the 10 most recent messages
	set, _ := imap.NewSeqSet("")
	if c.Mailbox.Messages >= 10 {
		set.AddRange(c.Mailbox.Messages-9, c.Mailbox.Messages)
	} else {
		set.Add("1:*")
	}

	//header
	bodySet, _ := imap.NewSeqSet("")
	cmd, _ = c.Fetch(set, "RFC822.HEADER")
	for cmd.InProgress() {
		// Wait for the next response (no timeout)
		c.Recv(-1)

		// Process command data
		for _, rsp := range cmd.Data {
			header := imap.AsBytes(rsp.MessageInfo().Attrs["RFC822.HEADER"])

			if msg, _ := mail.ReadMessage(bytes.NewReader(header)); msg != nil {
				from := msg.Header.Get("From")
				if strings.Contains(from, "gc-orders@gc.email.amazon.cn") {
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

	for cmd.InProgress() {
		// Wait for the next response (no timeout)
		c.Recv(-1)

		// Process command data
		for _, rsp := range cmd.Data {
			body := imap.AsBytes(rsp.MessageInfo().Attrs["BODY[]"])
			// glog.Info(string(body))

			msg, err := mail.ReadMessage(bytes.NewReader(body))
			if msg != nil {
				// glog.Info(msg)
				from := msg.Header.Get("From")
				if strings.Contains(from, "gc-orders@gc.email.amazon.cn") {
					bts, _ := ioutil.ReadAll(msg.Body)
					str := string(bts)

					yen := "=EF=BF=A5"
					priceIdx := strings.Index(str, yen)
					priceStr := str[priceIdx+len(yen):]
					priceIdx = strings.Index(priceStr, "\n")
					priceStr = priceStr[0:priceIdx]
					glog.Info("price: ", priceStr)

					strs := strings.Split(str, "Claim code ")
					code := strs[1]
					n := strings.Index(code, "\n")
					code = code[0:n]
					glog.Info("code: ", code)
				}
			}
			if err != nil {
				glog.Errorln(err)
			}

			// header := imap.AsBytes(rsp.MessageInfo().Attrs["RFC822.HEADER"])

			// if msg, _ := mail.ReadMessage(bytes.NewReader(header)); msg != nil {
			// 	fmt.Println("|--", msg.Header.Get("Subject"))
			// 	fmt.Println("|--", msg.Header.Get("From"))

			// 	bts, _ := ioutil.ReadAll(msg.Body)
			// 	fmt.Println("|--", string(bts))
			// }
		}
		cmd.Data = nil

		// Process unilateral server data
		for _, rsp := range c.Data {
			fmt.Println("Server data:", rsp)
		}
		c.Data = nil
	}

	// Check command completion status
	if rsp, err := cmd.Result(imap.OK); err != nil {
		if err == imap.ErrAborted {
			fmt.Println("Fetch command aborted")
		} else {
			fmt.Println("Fetch error:", rsp.Info)
		}
	}

	// mbox := MBox + delim + "Demo1"
	// if cmd, err := imap.Wait(c.Create(mbox)); err != nil {
	// 	if rsp, ok := err.(imap.ResponseError); ok && rsp.Status == imap.NO {
	// 		ReportOK(c.Delete(mbox))
	// 	}
	// 	ReportOK(c.Create(mbox))
	// } else {
	// 	ReportOK(cmd, err)
	// }
	// ReportOK(c.List("", MBox))
	// ReportOK(c.List("", mbox))
	// ReportOK(c.Rename(mbox, mbox+"2"))
	// ReportOK(c.Rename(mbox+"2", mbox))
	// ReportOK(c.Subscribe(mbox))
	// ReportOK(c.Unsubscribe(mbox))
	// ReportOK(c.Status(mbox))
	// ReportOK(c.Delete(mbox))

	// ReportOK(c.Create(mbox))
	// ReportOK(c.Select(mbox, true))
	// ReportOK(c.Close(false))

	// msg := []byte(strings.Replace(Msg[1:], "\n", "\r\n", -1))
	// ReportOK(c.Append(mbox, nil, nil, imap.NewLiteral(msg)))

	// ReportOK(c.Select(mbox, false))
	// ReportOK(c.Check())

	// fmt.Println(c.Mailbox)

	// cmd = ReportOK(c.UIDSearch("SUBJECT", c.Quote("GoIMAP")))
	// set, _ := imap.NewSeqSet("")
	// set.AddNum(cmd.Data[0].SearchResults()...)

	// ReportOK(c.Fetch(set, "FLAGS", "INTERNALDATE", "RFC822.SIZE", "BODY[]"))
	// ReportOK(c.UIDStore(set, "+FLAGS.SILENT", imap.NewFlagSet(`\Deleted`)))
	// ReportOK(c.Expunge(nil))
	// ReportOK(c.UIDSearch("SUBJECT", c.Quote("GoIMAP")))

	// fmt.Println(c.Mailbox)

	// ReportOK(c.Close(true))
	// ReportOK(c.Delete(mbox))
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
	var rsp *imap.Response
	if cmd == nil {
		fmt.Printf("--- ??? ---\n%v\n\n", err)
		panic(err)
	} else if err == nil {
		rsp, err = cmd.Result(imap.OK)
	}
	if err != nil {
		fmt.Printf("--- %s ---\n%v\n\n", cmd.Name(true), err)
		panic(err)
	}
	c := cmd.Client()
	fmt.Printf("--- %s ---\n"+
		"%d command response(s), %d unilateral response(s)\n"+
		"%s %s\n\n",
		cmd.Name(true), len(cmd.Data), len(c.Data), rsp.Status, rsp.Info)
	c.Data = nil
	return cmd
}
