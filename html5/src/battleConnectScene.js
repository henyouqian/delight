/****************************************************************************
 Copyright (c) 2010-2012 cocos2d-x.org
 Copyright (c) 2008-2010 Ricardo Quesada
 Copyright (c) 2011      Zynga Inc.

 http://www.cocos2d-x.org

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ****************************************************************************/

var g_conn = null
var g_procMap = {}

var BattleConnectLayer = cc.Layer.extend({
    _startBtn:null,
    init:function () {
        this._super()
        
        //
        this.setTouchEnabled(true)

        var winSize = cc.Director.getInstance().getWinSize();

        //retry
        var spt1 = cc.Sprite.create("res/start1.png")
        var spt2 = cc.Sprite.create("res/start2.png")
        this._startBtn = cc.MenuItemSprite.create(spt1, spt2, null, function () {
            this.onStartButton()
        },this);
        this._startBtn.setPosition(cc.p(70, 100))
        this._startBtn.setScale(0.6, 0.6)
        this._startBtn.setOpacity(120)

        var menuRetry = cc.Menu.create(this._startBtn)
        menuRetry.setPosition(cc.p(0, 0))
        this.addChild(menuRetry, 0)
        
        // menuRetry.setOpacity(120)

        return true;
    },
    onTouchesBegan:function (touches, event) {
        
    },
    onTouchesMoved:function (touches, event) {
        
    },
    onTouchesEnded:function (touches, event) {
        
    },
    onTouchesCancelled:function (touches, event) {
        console.log("onTouchesCancelled");
    },
    onStartButton:function () {
        if (window["WebSocket"]) {

            if (g_conn != null) {
                g_conn.close()
            }
            g_conn = new WebSocket(WEBSOCKET_URL);
            g_conn.onclose = function(evt) {
                g_conn = null
                console.log("Connection closed")
            }
            g_conn.onopen = function(evt) {
                console.log("Connection opened")
            }
            g_conn.onmessage = function(evt) {
                msg = JSON.parse(evt.data)
                if (msg.Type in g_procMap) {
                    (g_procMap[msg.Type])(msg)
                } else {
                    console.log("Msg unproc:", evt.data)
                }
            }
            console.log(g_conn)
        } else {
            console.log("Your browser does not support WebSockets")
        }

        //
        // this._startBtn.setEnabled(false)

        // var body = {
        //     "Key": g_key
        // }
        
        // var url = HOST + "social/getPack"
        // $.post(url, JSON.stringify(body), function(resp){
        //     var reses = []
        //     g_imageUrls = []
        //     g_socialPack = resp
        //     var images = resp.Pack.Images
        //     for (var i in images) {
        //         var image = images[i]
        //         var url = QINIU_HOST+image.Key
        //         reses.push({src:url})
        //         g_imageUrls.push(url)
        //     }
        //     g_bgUrl = QINIU_HOST+resp.Pack.CoverBlur
        //     reses.push({src:g_bgUrl})

        //     g_thumbUrl = QINIU_HOST+resp.Pack.Thumb

        //     cc.LoaderScene.preload(reses, function () {
        //         cc.Director.getInstance().replaceScene(new SliderScene);
        //     }, g_app);

        // }, "json")
    }
});

var BattleConnectScene = cc.Scene.extend({
    onEnter:function () {
        this._super();
        var layer = new BattleConnectLayer();
        layer.init();
        this.addChild(layer);
    }
});

g_procMap.connected = function(msg) {
    if (!localStorage.nickName) {
        var nickName = prompt("请输入您的昵称");
        if (nickName.length > 0) {
            localStorage.nickName = nickName
        }
    }

    msg = {"Type":"simplePair", "NickName":localStorage.nickName}
    g_conn.send(JSON.stringify(msg))
}

g_procMap.pairing = function(msg) {
    console.log("onPairing")
}

g_procMap.paired = function(msg) {
    console.log("onPaired")

    var reses = []
    g_imageUrls = []
    g_socialPack = msg
    g_socialPack.SliderNum = 3
    var images = msg.Pack.Images
    for (var i in images) {
        var image = images[i]
        var url = QINIU_HOST+image.Key
        reses.push({src:url})
        g_imageUrls.push(url)
    }
    g_bgUrl = QINIU_HOST+msg.Pack.CoverBlur
    reses.push({src:g_bgUrl})

    g_thumbUrl = QINIU_HOST+msg.Pack.Thumb

    cc.LoaderScene.preload(reses, function () {
        cc.Director.getInstance().replaceScene(new SliderScene);
    }, g_app);
}

