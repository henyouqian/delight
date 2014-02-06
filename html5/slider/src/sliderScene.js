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

var SliderLayer = cc.Layer.extend({
    _sliderNum:8,
    _sliderH:0.0,
    _sliderX0:0,
    _sliderY0:0,
    _texUrl:"",
    _sliders:[],
    _isCompleted:false,
    MOVE_DURATION:0.1,
    init:function () {
        //////////////////////////////
        // 1. super init first
        this._super();
        //this._texUrl = "res/CloseSelected.png"
        //this._texUrl = "http://slider.qiniudn.com/71B4B2E1F31E1ED0CB8C59E63B0E137B_B1280_1280_680_800.jpeg"
        this._texUrl = "http://slider.qiniudn.com/%E6%A8%8B%E5%8F%A3%E5%8F%AF%E5%8D%97%E5%AD%90/img140.JPG"
        var sprite = cc.Sprite.create(this._texUrl);
        if (sprite.textureLoaded()) {
            this.resetNow(sprite)
        } else {
            var target = this
            sprite.addLoadedEventListener(function(spt) {
                target.resetNow(spt)
            }, 0)
        }

        //
        this.setTouchEnabled(true);
        return true;
    },
    resetNow:function(sprite) {
        var winSize = cc.Director.getInstance().getWinSize();
        // sprite.setPosition(winSize.width / 2, winSize.height / 2);
        // this.addChild(sprite, 0);  

        var texSize = sprite.getContentSize();
        cc.log(sprite)

        //scale
        var scaleW = winSize.width / texSize.width;
        var scaleH = winSize.height/ texSize.height;
        if (texSize.width > texSize.height) {
            scaleW = winSize.width / texSize.height;
            scaleH = winSize.height/ texSize.width;
        }
        var scale = Math.max(scaleW, scaleH);

        //sliders
        var idxVec = [4, 7, 3, 5, 2, 1, 6, 0]
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
                this.addChild(spt, 0);

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
                this.addChild(spt, 0);

                this._sliders.push({
                    sprite:spt,
                    idx:idxVec[i],
                    touch:null
                })
            }
        }
    },
    onTouchesBegan:function (touches, event) {
        var touch = touches[0];
    
        if (this._isCompleted) {
            return;
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
            //cc.AudioEngine.getInstance().playEffect("res/audio/tik.mp3");
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
                //break;
            }
            if (slider.idx != i) {
                complete = false;
            }
        }
        if (this._isCompleted == false && complete == true) {
            //SimpleAudioEngine::getInstance()->playEffect("audio/success.mp3");
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

