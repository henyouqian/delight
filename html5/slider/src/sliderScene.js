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
function shuffle(o){ //v1.0
    for(var j, x, i = o.length; i; j = Math.floor(Math.random() * i), x = o[--i], o[i] = o[j], o[j] = x);
    return o;
};

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
    _label:null,
    MOVE_DURATION:0.1,
    init:function () {
        //////////////////////////////
        // 1. super init first
        this._super()
        this._sliderNum = g_socialPack.SliderNum
        this._sliderNum = 3
        
        //shuffle image idx
        for (var i = 0; i < g_imageUrls.length; i++) {
            this._imgShuffleIdxs.push(i)
        }
        this._imgShuffleIdxs = shuffle(this._imgShuffleIdxs)

        //
        this.setTouchEnabled(true)

        var winSize = cc.Director.getInstance().getWinSize();

        this._btn = cc.Sprite.create("res/nextBtn.png")
        this.addChild(this._btn, 100);
        this._btn.setPosition(winSize.width-100, 100)
        this._btn.setScale(0.7, 0.7)
        this._btn.setColor(new cc.Color3B(255,0,0))
        this._btn.setOpacity(200)

        this._sliderGroup = cc.Layer.create()
        this.addChild(this._sliderGroup, 0)

        cc.AudioEngine.getInstance().preloadEffect("res/success.mp3");
        cc.AudioEngine.getInstance().preloadEffect("res/tink.mp3");
        cc.AudioEngine.getInstance().preloadEffect("res/finish.mp3");

        // this._label = cc.LabelTTF.create("Next", "Arial", 40, new cc.Size(100, 100), cc.TEXT_ALIGNMENT_CENTER, cc.TEXT_ALIGNMENT_CENTER)
        // this._label.setColor(new cc.Color3B(0, 0, 0))
        // this._btn.addChild(this._label, 1111)

        this.reset(0)

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
        if (this._touch) {
            return
        }

        var touch = touches[0]
        this._touch = touch

        if (this._isCompleted) {
            if (this._imgIdx < g_imageUrls.length-1) {
                this.reset(this._imgIdx + 1)
            } else {
                window.location.href = "http://baidu.com"
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
            cc.AudioEngine.getInstance().playEffect("res/tink.mp3");
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
                // this.reset(this._imgIdx + 1)
                this._btn.setVisible(true)
                cc.AudioEngine.getInstance().playEffect("res/success.mp3");
            } else {
                cc.AudioEngine.getInstance().playEffect("res/finish.mp3");
            }
        }
        this._isCompleted = complete;
    },
    onTouchesCancelled:function (touches, event) {
        console.log("onTouchesCancelled");
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

