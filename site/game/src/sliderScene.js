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
var APP_STORE_URL = "https://itunes.apple.com/cn/app/man-pin-de/id923531990?l=zh&ls=1&mt=8"
var USER_NAME = "userName"

var DOT_Y = 940

var gMyScore = ""

//cookie
function getCookie(c_name) {
    if (document.cookie.length>0) {
        c_start=document.cookie.indexOf(c_name + "=");
        if (c_start!=-1) {
            c_start=c_start + c_name.length+1;
            c_end=document.cookie.indexOf(";",c_start);
            if (c_end==-1) c_end=document.cookie.length;
            return unescape(document.cookie.substring(c_start,c_end))
        }
    }
    return "";
}

function setCookie(c_name,value,expiredays) {
    var exdate = new Date();
    exdate.setDate(exdate.getDate()+expiredays);
    document.cookie=c_name+ "=" +escape(value)+
        ((expiredays==null) ? "" : ";expires="+exdate.toGMTString());
}

function shuffle(o){ //v1.0
    for(var j, x, i = o.length; i; j = Math.floor(Math.random() * i), x = o[--i], o[i] = o[j], o[j] = x);
    return o;
};

function padLeft(str,lenght){ 
    if(str.length >= lenght) 
        return str; 
    else 
        return padLeft("0" +str,lenght); 
} 

function msecToStr(msec) {
    var s = Math.floor(msec/1000)
    var min = Math.floor(s / 60)
    var sec = padLeft(s%60+"", 2)
    var ms = padLeft(msec%1000+"", 3)

    return min + ":" + sec + "." + ms
}

function showDownLoadDesc() {
    alert("如无法跳转到App Store(苹果应用商店)。请在App Store中搜索《蛮拼的》下载，谢谢。")
}

function updateWeixin() {
    if (typeof(WeixinJSBridge) == "undefined") {
        return
    }

    try {


    var imgUrl = g_thumbUrl;
    var lineLink = window.location.href;
    var descContent = "好玩爽快的拼图游戏，小伙伴们拼起来！";
    var shareTitle = '《蛮拼的》';
    var appid = 'wxa959a211a5061fb6';

    if (gMyScore != "") {
        descContent = "我只用了"+gMyScore+"就完成了比赛，敢来挑战么？"
    }

    function shareFriend() {
        WeixinJSBridge.invoke('sendAppMessage',{
            "appid": appid,
            "img_url": imgUrl,
            "img_width": "200",
            "img_height": "200",
            "link": lineLink,
            "desc": descContent,
            "title": shareTitle
        }, function(res) {
            //_report('send_msg', res.err_msg);
        })
    }
    function shareTimeline() {
        WeixinJSBridge.invoke('shareTimeline',{
            "img_url": imgUrl,
            "img_width": "200",
            "img_height": "200",
            "link": lineLink,
            "desc": descContent,
            "title": shareTitle
        }, function(res) {
               //_report('timeline', res.err_msg);
        });
    }
    function shareWeibo() {
        WeixinJSBridge.invoke('shareWeibo',{
            "content": descContent,
            "url": lineLink
        }, function(res) {
            //_report('weibo', res.err_msg);
        });
    }
    
    WeixinJSBridge.on('menu:share:appmessage', function(argv){
        shareFriend();
    });
    // 分享到朋友圈
    WeixinJSBridge.on('menu:share:timeline', function(argv){
        shareTimeline();
    });
    // 分享到微博
    WeixinJSBridge.on('menu:share:weibo', function(argv){
        shareWeibo();
    });

    } catch(err) {
        txt="There was an error on this page.\n\n";
        txt+="Error description: " + err.message + "\n\n";
        txt+="Click OK to continue.\n\n";
        alert(txt);
    }
}

var SliderLayer = cc.Layer.extend({
    _imgIdx:0,
    _sliderNum:6,
    _sliderH:0.0,
    _sliderX0:0,
    _sliderY0:0,
    _texUrl:"",
    _sliderGroup:null,
    _sliders:[],
    _isCompleted:false,
    _touch:null,
    _imgShuffleIdxs:[],
    _btn:null,
    _resultView:null,
    _beginTime:0,
    _timeLabel:null,
    _nameLabel:null,
    _scoreLabel:null,
    _startView:null,
    _startNameLabel:null,
    _startScoreLabel:null,
    _titleLabel:null,
    _adviceLabel:null,
    _dot:null,
    MOVE_DURATION:0.1,
    init:function () {
        //////////////////////////////
        // 1. super init first
        this._super()
        this._sliderNum = g_socialPack.SliderNum

        updateWeixin()
        
        //shuffle image idx
        for (var i = 0; i < g_imageUrls.length; i++) {
            this._imgShuffleIdxs.push(i)
        }
        this._imgShuffleIdxs = shuffle(this._imgShuffleIdxs)

        //
        this.setTouchEnabled(true)

        var winSize = cc.Director.getInstance().getWinSize();

        this._btn = cc.Sprite.create("res/nextBtn.png")
        this.addChild(this._btn, 10);
        this._btn.setPosition(winSize.width-100, 100)
        this._btn.setScale(0.6, 0.6)
        this._btn.setOpacity(200)

        this._sliderGroup = cc.Layer.create()
        this.addChild(this._sliderGroup, 0)

        // cc.AudioEngine.getInstance().preloadEffect("res/success.mp3");
        // cc.AudioEngine.getInstance().preloadEffect("res/tink.mp3");
        // cc.AudioEngine.getInstance().preloadEffect("res/finish.mp3");

        this._resultView = cc.LayerColor.create(new cc.Color3B(40,40,40), winSize.width+20, winSize.height+20)
        this.addChild(this._resultView, 200)
        this._resultView.setOpacity(220)

        //xxx
        this._resultView.setVisible(false)

        //retry
        var sptRetry1 = cc.Sprite.create("res/retry1.png")
        var sptRetry2 = cc.Sprite.create("res/retry2.png")
        var retry = cc.MenuItemSprite.create(sptRetry1, sptRetry2, null, function () {
            this._imgShuffleIdxs = shuffle(this._imgShuffleIdxs)
            this._resultView.setVisible(false)
            var d = new Date();
            this._beginTime = d.getTime()
            this.reset(0)
        },this);

        retry.setScale(0.7, 0.7)
        retry.setOpacity(120)
        retry.setPosition(cc.p(0, -360));
        

        //more
        var sptMore1 = cc.Sprite.create("res/back1.png")
        var sptMore2 = cc.Sprite.create("res/back2.png")
        var more = cc.MenuItemSprite.create(sptMore1, sptMore2, null, function () {
            // document.location.href = MATCH_LIST_URL
            window.history.back(-1);
        },this);

        var moreScale = 0.5

        more.setScale(moreScale, moreScale)
        more.setOpacity(120)
        more.setPosition(cc.p(-250, -360));

        var menu = cc.Menu.create(retry, more);
        this._resultView.addChild(menu, 1);

        //rename
        var sptRename1 = cc.Sprite.create("res/rename1.png")
        var sptRename2 = cc.Sprite.create("res/rename2.png")
        var renameItem = cc.MenuItemSprite.create(sptRename1, sptRename2, null, function () {
            showRename = function() {
                var userName = getCookie(USER_NAME)
                userName = prompt("请输入您的名字以便于提交成绩", userName);
                if (userName != null && userName != "") {
                    setCookie(USER_NAME, userName, 30)
                    console.log(userName)
                }
            }
            setTimeout("showRename()",100)
        },this);

        renameItem.setScale(0.4, 0.4)

        var menuRename = cc.Menu.create(renameItem)
        this._resultView.addChild(menuRename, 0)
        menuRename.setPosition(cc.p(70, 880))
        menuRename.setOpacity(120)

        //invite
        var inviteLabel = cc.LabelTTF.create("邀请朋友", "Arial", 24, new cc.Size(300, 100), cc.TEXT_ALIGNMENT_LEFT, cc.TEXT_ALIGNMENT_CENTER)
        inviteLabel.setPosition(winSize.width-20, 880)
        this._resultView.addChild(inviteLabel, 1)

        var x = winSize.width+75
        var fingerLabel = cc.LabelTTF.create("☝︎", "Arial", 52, new cc.Size(300, 100), cc.TEXT_ALIGNMENT_LEFT, cc.TEXT_ALIGNMENT_CENTER)
        fingerLabel.setPosition(x, 880)
        this._resultView.addChild(fingerLabel, 1)

        var moveTo = cc.MoveTo.create(0.3, cc.p(x, 960));
        var ease = cc.EaseSineIn.create(moveTo);
        var moveBack = cc.MoveTo.create(0.4, cc.p(x, 880));
        var easeBack = cc.EaseSineOut.create(moveBack);
        var seq = cc.Sequence.create([ease, easeBack])
        var repeat = cc.RepeatForever.create(seq)
        fingerLabel.stopAllActions();
        fingerLabel.runAction(repeat);


        //app store
        var spt1 = cc.Sprite.create("res/appStore1.png")
        var spt2 = cc.Sprite.create("res/appStore2.png")

        var appStore = cc.MenuItemSprite.create(spt1, spt2, null, function () {
             window.location.href = APP_STORE_URL
             setTimeout("showDownLoadDesc()",1000)
        },this);

        var menu2 = cc.Menu.create(appStore);
        // menu.alignItemsVerticallyWithPadding(10);
        menu2.setPosition(cc.p(winSize.width-180, 100));
        // this._resultView.addChild(menu2, 0);

        //time label
        this._timeLabel = cc.LabelTTF.create("0:00.000", "Arial", 60, new cc.Size(300, 100), cc.TEXT_ALIGNMENT_CENTER, cc.TEXT_ALIGNMENT_CENTER)
        this._timeLabel.setColor(new cc.Color3B(255, 197, 131))
        this._timeLabel.setPosition(winSize.width / 2, 780)
        this._resultView.addChild(this._timeLabel, 1)

        //name lebel
        var y = 420
        this._nameLabel = cc.LabelTTF.create("", "Arial", 40, new cc.Size(300, 600), cc.TEXT_ALIGNMENT_LEFT, cc.TEXT_ALIGNMENT_TOP)
        this._nameLabel.setPosition(230, y)
        this._nameLabel.setString("AA\nbb\ncc\nddd\neee\nff\nAA\nbb\ncc\nddd")
        this._resultView.addChild(this._nameLabel, 1)

        //score lebel
        this._scoreLabel = cc.LabelTTF.create("", "Arial", 40, new cc.Size(300, 600), cc.TEXT_ALIGNMENT_RIGHT, cc.TEXT_ALIGNMENT_TOP)
        this._scoreLabel.setPosition(420, y)
        this._scoreLabel.setString("2:45.432\n2:45.432\n2:45.432\n2:45.432\n2:45.432\n2:45.432\n2:45.432\n2:45.432\n2:45.432\n2:45.432\n")
        this._resultView.addChild(this._scoreLabel, 1)

        //
        var nameString = ""
        var scoreString = ""
        for (var i in g_socialPack.Ranks) {
            var rank = parseInt(i) + 1
            if (i == 9) {
                nameString += rank + ". " + g_socialPack.Ranks[i].Name + "\n"
            } else {
                nameString += rank + ".   " + g_socialPack.Ranks[i].Name + "\n"
            }
            
            var msec = g_socialPack.Ranks[i].Msec
            var s = Math.floor(msec/1000)
            var min = Math.floor(s / 60)
            var sec = padLeft(s%60+"", 2)
            var ms = padLeft(msec%1000+"", 3)

            scoreString += min + ":" + sec + "." + ms + "\n"
        }
        this._nameLabel.setString(nameString)
        this._scoreLabel.setString(scoreString)

        //start view
        this._startView = cc.LayerColor.create(new cc.Color3B(0,0,0), winSize.width, winSize.height);
        this.addChild(this._startView, 20)

        //xxx
        // this._startView.setVisible(false)

        var bg = cc.Sprite.create(g_bgUrl)
        this._startView.addChild(bg, 0)
        bg.setPosition(320, 480)

        var sz = bg.getContentSize();
        var scaleW = winSize.width/sz.width
        var scaleH = winSize.height/sz.height
        if (scaleW >= scaleH) {
            bg.setScale(scaleW)
        } else {
            bg.setScale(scaleH)
        }

        //cover
        var cover = cc.LayerColor.create(new cc.Color3B(40,40,40), winSize.width+20, winSize.height+20)
        this._startView.addChild(cover, 0)
        cover.setOpacity(200)
        
        //start button
        var sptStart1 = cc.Sprite.create("res/start1.png")
        var sptStart2 = cc.Sprite.create("res/start2.png")
        var start = cc.MenuItemSprite.create(sptStart1, sptStart2, null, function () {
            var d = new Date();
            this._beginTime = d.getTime()
            this._startView.setVisible(false)
            // document.location.href = "ads.html"
        },this);
        start.setScale(0.7, 0.7)
        start.setOpacity(120)
        start.setPosition(cc.p(0, -360));

        //more
        sptMore1 = cc.Sprite.create("res/back1.png")
        sptMore2 = cc.Sprite.create("res/back2.png")
        more = cc.MenuItemSprite.create(sptMore1, sptMore2, null, function () {
            // document.location.href = MATCH_LIST_URL
            window.history.back(-1);
        },this);

        more.setScale(moreScale, moreScale)
        more.setOpacity(120)
        more.setPosition(cc.p(-250, -360));

        var startMenu = cc.Menu.create(start, more);
        this._startView.addChild(startMenu, 1);

        // menuMore = cc.Menu.create(more)
        // this._startView.addChild(menuMore, 1)
        // menuMore.setPosition(cc.p(200, 140))
        // menuMore.setOpacity(120)

        //name label
        var y = 420
        this._startNameLabel = cc.LabelTTF.create("", "Arial", 36, new cc.Size(300, 600), cc.TEXT_ALIGNMENT_LEFT, cc.TEXT_ALIGNMENT_TOP)
        this._startNameLabel.setPosition(230, y)
        this._startView.addChild(this._startNameLabel, 1)

        //score label
        this._startScoreLabel = cc.LabelTTF.create("", "Arial", 36, new cc.Size(300, 600), cc.TEXT_ALIGNMENT_RIGHT, cc.TEXT_ALIGNMENT_TOP)
        this._startScoreLabel.setPosition(420, y)
        this._startView.addChild(this._startScoreLabel, 1)

        //title label
        this._titleLabel = cc.LabelTTF.create("", "Arial", 40, new cc.Size(600, 100), cc.TEXT_ALIGNMENT_CENTER, cc.TEXT_ALIGNMENT_TOP)
        this._titleLabel.setPosition(winSize.width/2, 820)
        this._titleLabel.setString(g_socialPack.Pack.Title)
        this._titleLabel.setColor(new cc.Color3B(255, 197, 131))
        this._startView.addChild(this._titleLabel, 1)

        //title label
        this._adviceLabel = cc.LabelTTF.create("", "Arial", 24, new cc.Size(600, 100), cc.TEXT_ALIGNMENT_LEFT, cc.TEXT_ALIGNMENT_TOP)
        this._adviceLabel.setPosition(winSize.width/2, 870)
        this._adviceLabel.setString("建议锁定屏幕旋转再进行游戏")
        this._adviceLabel.setColor(new cc.Color3B(244, 75, 116))
        this._startView.addChild(this._adviceLabel, 1)

        //app store
        var spt1 = cc.Sprite.create("res/appStore1.png")
        var spt2 = cc.Sprite.create("res/appStore2.png")

        var appStore = cc.MenuItemSprite.create(spt1, spt2, null, function () {
             window.location.href = APP_STORE_URL
             setTimeout("showDownLoadDesc()",1000)
        },this);

        var menuAppStore = cc.Menu.create(appStore);
        // menu.alignItemsVerticallyWithPadding(10);
        menuAppStore.setPosition(cc.p(winSize.width-180, 140));
        // this._startView.addChild(menuAppStore, 0);


        //rank
        var nameString = ""
        var scoreString = ""
        var userName = getCookie(USER_NAME)
        for (var i in g_socialPack.Ranks) {
            var rank = parseInt(i) + 1
            var name = g_socialPack.Ranks[i].Name
            if (i == 9) {
                nameString += rank + ". " + name + "\n"
            } else {
                nameString += rank + ".   " + name + "\n"
            }

            var timeStr = msecToStr(g_socialPack.Ranks[i].Msec)
            if (name == userName) {
                gMyScore = timeStr
                scoreString += "* "
                updateWeixin()
            }
            scoreString += timeStr + "\n"
        }
        this._startNameLabel.setString(nameString)
        this._startScoreLabel.setString(scoreString)

        //dots
        var num = g_imageUrls.length
        var dx = winSize.width/num
        var x = dx/2
        for (var i = 0; i < num; i++) {
            var dot = cc.Sprite.create("res/dot24.png")
            this.addChild(dot, 100)
            dot.setPosition(x, DOT_Y)
            dot.setOpacity(100)
            x += dx
        }

        this._dot = cc.Sprite.create("res/dot24.png")
        this.addChild(this._dot, 101)
        this._dot.setPosition(dx/2, DOT_Y)
        
        //
        this.reset(0)

        //
        // if (g_conn) {
        //     msg = {"Type":"ready"}
        //     g_conn.send(JSON.stringify(msg))
        // }

        return true;
    },
    reset:function(imgIdx) {
        this._imgIdx = imgIdx

        //clean
        this._isCompleted = false
        this._sliders = []
        this._touch = null
        this._sliderGroup.removeAllChildren()
        this._btn.setVisible(false)

        //setup
        this._texUrl = g_imageUrls[this._imgShuffleIdxs[imgIdx]]
        var sprite = cc.Sprite.create(this._texUrl)
        if (sprite.textureLoaded()) {
            this.resetNow(sprite)
        } else {
            var target = this
            sprite.addLoadedEventListener(function(spt) {
                target.resetNow(spt)
            }, 0)
        }

        //dot
        var winSize = cc.Director.getInstance().getWinSize();
        var num = g_imageUrls.length
        var dx = winSize.width/num

        var x = dx/2+imgIdx*dx
        var moveTo = cc.MoveTo.create(0.2, cc.p(x, DOT_Y));
        var ease = cc.EaseSineInOut.create(moveTo);
        this._dot.stopAllActions();
        this._dot.runAction(ease);

        // this._dot.setPosition(dx/2+imgIdx*dx, 940)
    },
    resetNow:function(sprite) {
        var winSize = cc.Director.getInstance().getWinSize();
        // sprite.setPosition(winSize.width / 2, winSize.height / 2);
        // this.addChild(sprite, 0);  

        var texSize = sprite.getContentSize();

        //scale
        var scaleW = winSize.width / texSize.width;
        var scaleH = winSize.height/ texSize.height;
        if (texSize.width > texSize.height) {
            scaleW = winSize.width / texSize.height;
            scaleH = winSize.height/ texSize.width;
        }
        var scale = Math.max(scaleW, scaleH);

        
        //shuffle
        var idxVec = []
        for (var i = 0; i < this._sliderNum; i++) {
            idxVec.push(i)
        }
        idxVec = shuffle(idxVec)
        for (var i = 0; i < this._sliderNum; i++) {
            if (i != this._sliderNum - 1) {
                if (idxVec[i] + 1 == idxVec[i+1]) {
                    var tmp = idxVec[i]
                    idxVec[i] = idxVec[i+1]
                    idxVec[i+1] = tmp
                }
            }
        }

        //sliders
        var uvW = 0;
        var uvH = 0;
        var uvX = 0;
        var uvY = 0;
        if (texSize.width <= texSize.height) {
            if (texSize.width/texSize.height <= winSize.width/winSize.height) { //slim
                uvW = texSize.width;
                uvH = uvW * (winSize.height/winSize.width);
                uvY = (texSize.height - uvH) * .5;
            } else {    //fat
                uvH = texSize.height;
                uvW = uvH * (winSize.width/winSize.height);
                uvX = (texSize.width - uvW) * .5;
            }
            var uvy = uvY;
            var uvh = uvH / this._sliderNum;
            this._sliderH = winSize.height / this._sliderNum;
            this._sliderX0 = winSize.width * .5;
            this._sliderY0 = winSize.height - this._sliderH * .5;
            
            for (var i = 0; i < this._sliderNum; ++i) {
                uvy = uvY+uvh*idxVec[i];
                var spt = cc.Sprite.create(this._texUrl, cc.rect(uvX, uvy, uvW, uvh));
                var y = this._sliderY0 - i * this._sliderH;
                spt.setPosition(this._sliderX0, y);
                
                spt.setScale(scale*1.01);
                this._sliderGroup.addChild(spt, 0);

                this._sliders.push({
                    sprite:spt,
                    idx:idxVec[i],
                    touch:null
                })
            }
        } else {
            rotRight = true;
            if (texSize.width/texSize.height <= winSize.height/winSize.width) { //slim
                uvW = texSize.width;
                uvH = uvW * (winSize.width/winSize.height);
                uvY = (texSize.height - uvH) * .5;
            } else { //fat
                uvH = texSize.height;
                uvW = uvH * (winSize.height/winSize.width);
                uvX = (texSize.width - uvW) * .5;
            }
            var uvx = uvX;
            var uvw = uvW / this._sliderNum;
            this._sliderH = winSize.height / this._sliderNum;
            this._sliderX0 = winSize.width * .5;
            this._sliderY0 = winSize.height - this._sliderH * .5;
            for (var i = 0; i < this._sliderNum; ++i) {
                uvx = uvX+uvw*idxVec[i];
                var spt = cc.Sprite.create(this._texUrl, cc.rect(uvx, uvY, uvw, uvH));
                
                var y = this._sliderY0 - i * this._sliderH;
                spt.setPosition(this._sliderX0, y);
                spt.setRotation(90);
                
                spt.setScale(scale);
                this._sliderGroup.addChild(spt, 0);

                this._sliders.push({
                    sprite:spt,
                    idx:idxVec[i],
                    touch:null
                })
            }
        }
    },
    onTouchesBegan:function (touches, event) {
        if (this._touch || this._startView.isVisible()) {
            return
        }

        var touch = touches[0]
        this._touch = touch

        if (this._isCompleted) {
            if (this._imgIdx < g_imageUrls.length-1) {
                this.reset(this._imgIdx + 1)
            }
            return
        }
        for (var i = 0; i < this._sliders.length; i++) {
            var slider = this._sliders[i]
            var inRect = cc.rectContainsPoint(slider.sprite.getBoundingBox(), touch.getLocation())
            if (!slider.touch && inRect) {
                this._sliders[i].touch = touch;
                this._sliders[i].sprite.setZOrder(1);
                this._sliders[i].sprite.stopAllActions();
                break;
            }
        }
    },
    onTouchesMoved:function (touches, event) {
        if (this._startView.isVisible()) {
            return
        }
        var touch = touches[0];
        var resort = false;
        for (var i = 0; i < this._sliders.length; i++) {
            var slider = this._sliders[i]
            if (slider.touch && slider.touch == touch) {
                var y = slider.sprite.getPositionY()+touch.getDelta().y;
                slider.sprite.setPositionY(y);
                var toI = Math.round((this._sliderY0-y)/this._sliderH);
                toI = Math.max(0, Math.min(this._sliderNum-1, toI));
                if (toI != i) {
                    resort = true;
                    this._sliders.splice(i, 1);
                    this._sliders.splice(toI, 0, slider);
                }
                break;
            }
        }
        if (resort) {
            // cc.AudioEngine.getInstance().playEffect("res/tink.mp3");
            for (var i = 0; i < this._sliders.length; i++) {
                var slider = this._sliders[i]
                var y = this._sliderY0 - i * this._sliderH;
                if (!slider.touch && slider.sprite.getPositionY() != y) {
                    var moveTo = cc.MoveTo.create(this.MOVE_DURATION, cc.p(this._sliderX0, y));
                    var easeOut = cc.EaseSineOut.create(moveTo);
                    slider.sprite.stopAllActions();
                    slider.sprite.runAction(easeOut);
                }
            }
        }
    },
    onTouchesEnded:function (touches, event) {
        if (this._sliders.length == 0) {
            return;
        }
        var touch = touches[0];
        if (this._touch != touch) {
            return
        }
        this._touch = null
        var complete = true;
        for (var i = 0; i < this._sliders.length; i++) {
            var slider = this._sliders[i]
            if (slider.touch && slider.touch == touch) {
                slider.touch = null;
                slider.sprite.setZOrder(0);
                
                var y = this._sliderY0 - i * this._sliderH;
                var moveTo = cc.MoveTo.create(this.MOVE_DURATION, cc.p(this._sliderX0, y));
                var easeOut = cc.EaseSineInOut.create(moveTo);
                slider.sprite.stopAllActions();
                slider.sprite.runAction(easeOut);
            }
            if (slider.idx != i) {
                complete = false;
            }
        }
        if (this._isCompleted == false && complete == true) {
            
            if (this._imgIdx < g_imageUrls.length-1) {
                this.onPageFinish()
            } else {
                this.onFinish()
            }
        }
        this._isCompleted = complete;
    },
    onTouchesCancelled:function (touches, event) {
        console.log("onTouchesCancelled");
    },
    onPageFinish: function() {
        // cc.AudioEngine.getInstance().playEffect("res/success.mp3");
        this._btn.setVisible(true)
        // if (g_conn) {
        //     msg = {"Type":"progress", "CompleteNum":this._imgIdx+1}
        //     g_conn.send(JSON.stringify(msg))
        // }
    },
    onFinish: function () {
        localStorage["matchPlayed/"+g_key] = 1
        //
        this._resultView.setVisible(true)
        this._resultView.setOpacity(0)
        var fadeto = cc.FadeTo.create(0.4, 200)
        var ease = cc.EaseSineOut.create(fadeto)
        this._resultView.runAction(ease)
        // cc.AudioEngine.getInstance().playEffect("res/finish.mp3");

        var d = new Date()
        var t = d.getTime()
        var mSec = t - this._beginTime
        this._timeLabel.setString(msecToStr(mSec))

        var self = this

        setTimeout(function(){
            //getUserName
            var userName = getCookie(USER_NAME)
            userName = ""
            while (userName == "" || userName==null) {
                userName = prompt("请输入您的名字以便于提交成绩");
                if (userName != null) {
                    setCookie(USER_NAME, userName, 30)
                }
            }

            if (g_key) {
                //submit
                var url = HOST + "social/play"
                var data = {
                    "Key": g_key,
                    "CheckSum": "xxxx",
                    "UserName": userName,
                    "Msec": mSec
                }
                $.post(url, JSON.stringify(data), function(resp){
                    console.log(resp)
                    var nameString = ""
                    var scoreString = ""
                    for (var i in resp.Ranks) {
                        var rank = parseInt(i) + 1
                        var name = resp.Ranks[i].Name
                        if (i == 9) {
                            nameString += rank + ". " + name + "\n"
                        } else {
                            nameString += rank + ".   " + name + "\n"
                        }

                        var timeStr = msecToStr(resp.Ranks[i].Msec)
                        if (name == data.UserName) {
                            gMyScore = timeStr
                            scoreString += "* "
                            updateWeixin()
                        }
                        scoreString += timeStr + "\n"
                    }
                    self._nameLabel.setString(nameString)
                    self._scoreLabel.setString(scoreString)

                }, "json")
            }
        }, 1000)
    }
});

var SliderScene = cc.Scene.extend({
    onEnter:function () {
        this._super();
        var layer = new SliderLayer();
        layer.init();
        this.addChild(layer);
    }
});

// g_procMap.start = function(msg) {
//     console.log("onStart")
// }
