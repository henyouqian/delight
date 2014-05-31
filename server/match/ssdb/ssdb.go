package ssdb

import (
	"bytes"
	"container/list"
	"fmt"
	"net"
	"strconv"
	"sync"
	"time"
)

type Pool struct {
	Ip      string
	Port    int
	MaxIdle uint32
	TimeOut time.Duration

	mu          sync.Mutex
	idleClients list.List
}

func NewPool(ip string, port int, maxIdel uint32, timeOutSec uint32) *Pool {
	pool := Pool{
		Ip:      ip,
		Port:    port,
		MaxIdle: maxIdel,
		TimeOut: time.Duration(timeOutSec) * time.Second,
	}
	pool.idleClients.Init()
	return &pool
}

func (self *Pool) Get() (*Client, error) {
	self.mu.Lock()
	for self.idleClients.Len() > 0 {
		e := self.idleClients.Front()
		if e != nil {
			self.idleClients.Remove(e)
			c := e.Value.(*Client)
			if time.Now().Before(c.timeOut) {
				self.mu.Unlock()
				return e.Value.(*Client), nil
			} else {
				c.sock.Close()
			}
		} else {
			break
		}
	}

	self.mu.Unlock()

	//create new
	client, err := Connect(self.Ip, self.Port, self)

	if err != nil {
		return nil, err
	}

	return client, nil
}

func (self *Pool) Put(client *Client) {
	self.mu.Lock()
	client.timeOut = time.Now().Add(self.TimeOut)
	self.idleClients.PushBack(client)
	if self.idleClients.Len() > int(self.MaxIdle) {
		e := self.idleClients.Front()
		e.Value.(*Client).sock.Close()
		self.idleClients.Remove(e)
	}
	self.mu.Unlock()
}

type Client struct {
	sock     *net.TCPConn
	recv_buf bytes.Buffer
	pool     *Pool
	err      error
	timeOut  time.Time
}

func (self *Client) Close() error {
	if self.err != nil {
		return self.sock.Close()
	} else {
		self.pool.Put(self)
		return nil
	}
}

func Connect(ip string, port int, pool *Pool) (*Client, error) {
	addr, err := net.ResolveTCPAddr("tcp", fmt.Sprintf("%s:%d", ip, port))
	if err != nil {
		return nil, err
	}
	sock, err := net.DialTCP("tcp", nil, addr)
	if err != nil {
		return nil, err
	}
	var c Client
	c.sock = sock
	c.pool = pool
	return &c, nil
}

func (c *Client) Do(args ...interface{}) (_ []string, rErr error) {
	defer func() {
		if rErr != nil {
			c.err = rErr
		}
	}()

	err := c.send(args)
	if err != nil {
		return nil, err
	}
	resp, err := c.recv()
	return resp, err
}

func (c *Client) Set(key string, val string) (_ interface{}, rErr error) {
	defer func() {
		if rErr != nil {
			c.err = rErr
		}
	}()

	resp, err := c.Do("set", key, val)
	if err != nil {
		return nil, err
	}
	if len(resp) == 1 && resp[0] == "ok" {
		return true, nil
	}
	return nil, fmt.Errorf("bad response")
}

// TODO: Will somebody write addition semantic methods?
func (c *Client) Get(key string) (_ interface{}, rErr error) {
	defer func() {
		if rErr != nil {
			c.err = rErr
		}
	}()

	resp, err := c.Do("get", key)
	if err != nil {
		return nil, err
	}
	if len(resp) == 2 && resp[0] == "ok" {
		return resp[1], nil
	}
	if resp[0] == "not_found" {
		return nil, nil
	}
	return nil, fmt.Errorf("bad response")
}

func (c *Client) Del(key string) (_ interface{}, rErr error) {
	defer func() {
		if rErr != nil {
			c.err = rErr
		}
	}()

	resp, err := c.Do("del", key)
	if err != nil {
		return nil, err
	}
	if len(resp) == 1 && resp[0] == "ok" {
		return true, nil
	}
	return nil, fmt.Errorf("bad response")
}

func (c *Client) send(args []interface{}) (rErr error) {
	defer func() {
		if rErr != nil {
			c.err = rErr
		}
	}()

	var buf bytes.Buffer
	for _, arg := range args {
		var s string
		switch arg := arg.(type) {
		case string:
			s = arg
		case []byte:
			s = string(arg)
		case int, int8, int16, int32, int64:
			s = fmt.Sprintf("%d", arg)
		case uint, uint8, uint16, uint32, uint64:
			s = fmt.Sprintf("%d", arg)
		case float32, float64:
			s = fmt.Sprintf("%f", arg)
		case bool:
			if arg {
				s = "1"
			} else {
				s = "0"
			}
		case nil:
			s = ""
		default:
			return fmt.Errorf("bad arguments")
		}
		buf.WriteString(fmt.Sprintf("%d", len(s)))
		buf.WriteByte('\n')
		buf.WriteString(s)
		buf.WriteByte('\n')
	}
	buf.WriteByte('\n')
	_, err := c.sock.Write(buf.Bytes())
	return err
}

func (c *Client) recv() (_ []string, rErr error) {
	defer func() {
		if rErr != nil {
			c.err = rErr
		}
	}()

	var tmp [8192]byte
	for {
		n, err := c.sock.Read(tmp[0:])
		if err != nil {
			return nil, err
		}
		c.recv_buf.Write(tmp[0:n])
		resp := c.parse()
		if resp == nil || len(resp) > 0 {
			return resp, nil
		}
	}
}

func (c *Client) parse() []string {
	resp := []string{}
	buf := c.recv_buf.Bytes()
	var idx, offset int
	idx = 0
	offset = 0

	for {
		idx = bytes.IndexByte(buf[offset:], '\n')
		if idx == -1 {
			break
		}
		p := buf[offset : offset+idx]
		offset += idx + 1
		//fmt.Printf("> [%s]\n", p);
		if len(p) == 0 || (len(p) == 1 && p[0] == '\r') {
			if len(resp) == 0 {
				continue
			} else {
				c.recv_buf.Next(offset)
				return resp
			}
		}

		size, err := strconv.Atoi(string(p))
		if err != nil || size < 0 {
			return nil
		}
		if offset+size >= c.recv_buf.Len() {
			break
		}

		v := buf[offset : offset+size]
		resp = append(resp, string(v))
		offset += size + 1
	}

	return []string{}
}
