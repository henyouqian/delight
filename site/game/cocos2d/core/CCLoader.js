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

/**
 * resource type
 * @constant
 * @type Object
 */
cc.RESOURCE_TYPE = {
    "IMAGE": ["png", "jpg", "bmp","jpeg","gif", "JPG"],
    "SOUND": ["mp3", "ogg", "wav", "mp4", "m4a"],
    "XML": ["plist", "xml", "fnt", "tmx", "tsx"],
    "BINARY": ["ccbi"],
    "FONT": "FONT",
    "TEXT":["txt", "vsh", "fsh","json", "ExportJson"],
    "UNKNOW": []
};

/**
 * A class to pre-load resources before engine start game main loop.
 * @class
 * @extends cc.Scene
 */
cc.Loader = cc.Class.extend(/** @lends cc.Loader# */{
    _curNumber: 0,
    _totalNumber: 0,
    _loadedNumber: 0,
    _resouces: null,
    _animationInterval: 1 / 60,
    _interval: null,
    _isAsync: false,

    /**
     * Constructor
     */
    ctor: function () {
        this._resouces = [];
    },

    /**
     * init with resources
     * @param {Array} resources
     * @param {Function|String} selector
     * @param {Object} target
     */
    initWithResources: function (resources, selector, target) {
        if(!resources){
            console.log("resources should not null");
            return;
        }

        if (selector) {
            this._selector = selector;
            this._target = target;
        }

        if ((resources != this._resouces) || (this._curNumber == 0)) {
            this._curNumber = 0;
            this._loadedNumber = 0;
            if (resources[0] instanceof Array) {
                for (var i = 0; i < resources.length; i++) {
                    var each = resources[i];
                    this._resouces = this._resouces.concat(each);
                }
            } else
                this._resouces = resources;
            this._totalNumber = this._resouces.length;
        }

        //load resources
        this._schedulePreload();
    },

    setAsync: function (isAsync) {
        this._isAsync = isAsync;
    },

    /**
     * Callback when a resource file load failed.
     * @example
     * //example
     * cc.Loader.getInstance().onResLoaded();
     */
    onResLoadingErr: function (name) {
        this._loadedNumber++;
        cc.log("cocos2d:Failed loading resource: " + name);
    },

    /**
     * Callback when a resource file loaded.
     * @example
     * //example
     * cc.Loader.getInstance().onResLoaded();
     */
    onResLoaded: function () {
        this._loadedNumber++;
    },

    /**
     * Get loading percentage
     * @return {Number}
     * @example
     * //example
     * cc.log(cc.Loader.getInstance().getPercentage() + "%");
     */
    getPercentage: function () {
        var percent = 0;
        if (this._totalNumber == 0) {
            percent = 100;
        } else {
            percent = (0 | (this._loadedNumber / this._totalNumber * 100));
        }
        return percent;
    },

    /**
     * release resources from a list
     * @param resources
     */
    releaseResources: function (resources) {
        if (resources && resources.length > 0) {
            var sharedTextureCache = cc.TextureCache.getInstance();
            var sharedEngine = cc.AudioEngine ? cc.AudioEngine.getInstance() : null;
            var sharedParser = cc.SAXParser.getInstance();
            var sharedFileUtils = cc.FileUtils.getInstance();

            var resInfo;
            for (var i = 0; i < resources.length; i++) {
                resInfo = resources[i];
                var type = this._getResType(resInfo);
                switch (type) {
                    case "IMAGE":
                        sharedTextureCache.removeTextureForKey(resInfo.src);
                        break;
                    case "SOUND":
                        if(!sharedEngine) throw "Can not find AudioEngine! Install it, please.";
                        sharedEngine.unloadEffect(resInfo.src);
                        break;
                    case "XML":
                        sharedParser.unloadPlist(resInfo.src);
                        break;
                    case "BINARY":
                        sharedFileUtils.unloadBinaryFileData(resInfo.src);
                        break;
                    case "TEXT":
                        sharedFileUtils.unloadTextFileData(resInfo.src);
                        break;
                    case "FONT":
                        this._unregisterFaceFont(resInfo);
                        break;
                    default:
                        throw "cocos2d:unknown filename extension: " + type;
                        break;
                }
            }
        }
    },

    _preload: function () {
        this._updatePercent();
        if (this._isAsync) {
            var frameRate = cc.Director.getInstance()._frameRate;
            if (frameRate != null && frameRate < 20) {
                cc.log("cocos2d: frame rate less than 20 fps, skip frame.");
                return;
            }
        }

        if (this._curNumber < this._totalNumber) {
            this._loadOneResource();
            this._curNumber++;
        }
    },

    _loadOneResource: function () {
        var sharedTextureCache = cc.TextureCache.getInstance();
        var sharedEngine = cc.AudioEngine ? cc.AudioEngine.getInstance() : null;
        var sharedParser = cc.SAXParser.getInstance();
        var sharedFileUtils = cc.FileUtils.getInstance();

        var resInfo = this._resouces[this._curNumber];
        var type = this._getResType(resInfo);
        switch (type) {
            case "IMAGE":
                sharedTextureCache.addImage(resInfo.src);
                break;
            case "SOUND":
                if(!sharedEngine) throw "Can not find AudioEngine! Install it, please.";
                sharedEngine.preloadSound(resInfo.src);
                break;
            case "XML":
                sharedParser.preloadPlist(resInfo.src);
                break;
            case "BINARY":
                sharedFileUtils.preloadBinaryFileData(resInfo.src);
                break;
            case "TEXT" :
                sharedFileUtils.preloadTextFileData(resInfo.src);
                break;
            case "FONT":
                this._registerFaceFont(resInfo);
                break;
            default:
                // throw "cocos2d:unknown filename extension: " + type;
                sharedTextureCache.addImage(resInfo.src);
                break;
        }
    },

    _schedulePreload: function () {
        var _self = this;
        this._interval = setInterval(function () {
            _self._preload();
        }, this._animationInterval * 1000);
    },

    _unschedulePreload: function () {
        clearInterval(this._interval);
    },

    _getResType: function (resInfo) {
        var isFont = resInfo.fontName;
        if (isFont != null) {
            return cc.RESOURCE_TYPE["FONT"];
        } else {
            var src = resInfo.src;
            var ext = src.substring(src.lastIndexOf(".") + 1, src.length);

            var index = ext.indexOf("?");
            if(index > 0) ext = ext.substring(0, index);

            for (var resType in cc.RESOURCE_TYPE) {
                if (cc.RESOURCE_TYPE[resType].indexOf(ext) != -1) {
                    return resType;
                }
            }
            return ext;
        }
    },

    _updatePercent: function () {
        var percent = this.getPercentage();

        if (percent >= 100) {
            this._unschedulePreload();
            this._complete();
        }
    },

    _complete: function () {
        if (this._target && (typeof(this._selector) == "string")) {
            this._target[this._selector](this);
        } else if (this._target && (typeof(this._selector) == "function")) {
            this._selector.call(this._target, this);
        } else {
            this._selector(this);
        }

        this._curNumber = 0;
        this._loadedNumber = 0;
        this._totalNumber = 0;
    },

    _registerFaceFont: function (fontRes) {
        var srcArr = fontRes.src;
        var fileUtils = cc.FileUtils.getInstance();
        if (srcArr && srcArr.length > 0) {
            var fontStyle = document.createElement("style");
            fontStyle.type = "text/css";
            document.body.appendChild(fontStyle);

            var fontStr = "@font-face { font-family:" + fontRes.fontName + "; src:";
            for (var i = 0; i < srcArr.length; i++) {
                fontStr += "url('" + fileUtils.fullPathForFilename(encodeURI(srcArr[i].src)) + "') format('" + srcArr[i].type + "')";
                fontStr += (i == (srcArr.length - 1)) ? ";" : ",";
            }
            fontStyle.textContent += fontStr + "};";

            //preload
            //<div style="font-family: PressStart;">.</div>
            var preloadDiv = document.createElement("div");
            preloadDiv.style.fontFamily = fontRes.fontName;
            preloadDiv.innerHTML = ".";
            preloadDiv.style.position = "absolute";
            preloadDiv.style.left = "-100px";
            preloadDiv.style.top = "-100px";
            document.body.appendChild(preloadDiv);
        }
        cc.Loader.getInstance().onResLoaded();
    },

    _unregisterFaceFont: function (fontRes) {
        //todo remove style
    }
});

/**
 * Preload resources in the background
 * @param {Array} resources
 * @param {Function|String} selector
 * @param {Object} target
 * @return {cc.Loader}
 * @example
 * //example
 * var g_mainmenu = [
 *    {src:"res/hello.png"},
 *    {src:"res/hello.plist"},
 *
 *    {src:"res/logo.png"},
 *    {src:"res/btn.png"},
 *
 *    {src:"res/boom.mp3"},
 * ]
 *
 * var g_level = [
 *    {src:"res/level01.png"},
 *    {src:"res/level02.png"},
 *    {src:"res/level03.png"}
 * ]
 *
 * //load a list of resources
 * cc.Loader.preload(g_mainmenu, this.startGame, this);
 *
 * //load multi lists of resources
 * cc.Loader.preload([g_mainmenu,g_level], this.startGame, this);
 */
cc.Loader.preload = function (resources, selector, target) {
    if (!this._instance) {
        this._instance = new cc.Loader();
    }
    this._instance.initWithResources(resources, selector, target);
    return this._instance;
};

/**
 * Preload resources async
 * @param {Array} resources
 * @param {Function|String} selector
 * @param {Object} target
 * @return {cc.Loader}
 */
cc.Loader.preloadAsync = function (resources, selector, target) {
    if (!this._instance) {
        this._instance = new cc.Loader();
    }
    this._instance.setAsync(true);
    this._instance.initWithResources(resources, selector, target);
    return this._instance;
};

/**
 * Release the resources from a list
 * @param {Array} resources
 */
cc.Loader.purgeCachedData = function (resources) {
    if (this._instance) {
        this._instance.releaseResources(resources);
    }
};

/**
 * Returns a shared instance of the loader
 * @function
 * @return {cc.Loader}
 */
cc.Loader.getInstance = function () {
    if (!this._instance) {
        this._instance = new cc.Loader();
    }
    return this._instance;
};

cc.Loader._instance = null;


/**
 * Used to display the loading screen
 * @class
 * @extends cc.Scene
 */
cc.LoaderScene = cc.Scene.extend(/** @lends cc.LoaderScene# */{
    _logo: null,
    _logoTexture: null,
    _texture2d: null,
    _bgLayer: null,
    _label: null,
    _winSize:null,

    /**
     * Constructor
     */
    ctor: function () {
        cc.Scene.prototype.ctor.call(this);
        this._winSize = cc.Director.getInstance().getWinSize();
    },
    init:function(){
        cc.Scene.prototype.init.call(this);

        //logo
        var logoWidth = 100;
        var logoHeight = 100;
        var centerPos = cc.p(this._winSize.width / 2, this._winSize.height / 2);

        this._logoTexture = new Image();
        var _this = this;
        this._logoTexture.addEventListener("load", function () {
            _this._initStage(centerPos);
            this.removeEventListener('load', arguments.callee, false);
        });
        //this._logoTexture.src = "data:image/gif;base64,R0lGODlhgALAA4cAMYQuXGyapIxqVLRofLybe7Te7LSEYNS2l7RGgHSKjGy+1NyEvOyazNRoqbRYhryqkJSinIRmjKSDZmywyMzq9LSGrPy35dR3s8xZm7RmlNSejOzGp/SExIxOZLSObHyFpryihOzOsbROjJTP5ISanJxqTNzCnNStiJxnl7xYlJxOgGSmvORutMSUbHyyvMRonOS9m9yOweyu1IR8oPTXu+z3/OR5t4SUjMRQkKRajLR6XHSOkITJ3NRxrmy40fSQzrSWeMRwjGyevMyceYyKtMxfo8ylgZx2XNSykbRelNy+nsyGlIxyVMSdgcSCiLRKh+yFxMyri9zw9Nt+tPTSs6TW5JxWhJxCdMTl7dy3lPSi1LRifIRwmHyKqKxKhGyOpHzE3KyNbnSuyvzA5dx5tOzKrPSKzMSjg7xPksxop/yt4pR2pMxOlLR+dNxvsLyWd8RfmnSir7RudLyehNyKvNxqrKysnNRanLSRdKxmdOTDo9yuhKR2pHSqwuyOxIx6oPzavoRabHxGbKyCrNSWlJRyWJRijMSOvIRaRHyQtMyGtHSCpJymnKx9XIR6dHSWtPz+/JyGtPyb13ycvMySjMRypNxerLxupMSCtKxqnKxFfJRunJR6bIyqrJRmlNSmiKR+ZLyKfGSWtLRCjIw2ZJRuVLiKZJxyVORytHy2vKRilIzO4vyW1GyivOT2/NSKvGyKpJzW5HSWnKyGXHS4yLx9frxyhOR+vPyy5OyKxHSapNyykbxKkfyKzNymlGyWpJRmTLxqhHTC3OSCvLxWjMSslLxqjISGrKRmnMRXmqRKgOxqvISutOSRxKxdlPyOzNRipOTy9aza6Mzm9Pyk3LyOfMxuqLxGlLzi7NTs9MxapJzS5KRtTNSulMSSfOS+pPT6/MRQnLR+bIzK3HSavJSOtMymjMyulPTSvKRGdNy5nMSmjLxOnMRepOTGrIx+rISStNSCtPSa1IxmjryGtLyOZKR2VLxenISKrPTKrMSKhOxyvHSivnSKrGyatGymvCwAAAAAgALAAwcI/gAVCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPHjyBDihxJsqTJkyhTqlzJsqXLlzBjypxJs6bNmzhz6tzJs6fPn0CDCh1KtKjRo0iTKl3KtKnTp1CjSp1KtarVq1izat3KtavXr2DDih1LtqzZs2jTql3Ltq3bt3Djyp1Lt67du3jz6t3Lt6/fv4ADCx5MuLDhw4gTK17MuLHjx5AjS55MubLly5gza97MubPnz6BDix5NurTp06hTq17NurXr17Bjy55Nu7bt27hz697Nu7fv38CDCx9OvLjx48iTK1/OvLnz59CjS59Ovbr169iza9/Ovbv37+DD/osfT768+fPo06tfz769+/fw48ufT7++/fv48+vfz7+///8ABijggAQWaOCBCCao4IIMNujggxBGKOGEFFZo4YUYZqjhhhx26OGHIIYo4ogklmjiiSimqOKKLLbo4oswxijjjDTWaOONOOao44489ujjj0AGKeSQRBZp5JFIJqnkkkw26eSTUEYp5ZRUVmnllVhmqeWWXHbp5ZdghinmmGSWaeaZaKap5ppstunmm3DGKeecdNZp55145qnnnnz26eefgAYq6KCEFmrooYgmquiijDbq6KOQRirppJRWaumlmGaq6aacdurpp6CGKuqopJZq6qmopqrqqqy26uqr/rDGKuustNZq66245qrrrrz26uuvwAYr7LDEFmvsscgmq+yyzDbr7LPQRivttNRWa+212Gar7bbcduvtt+CGK+645JZr7rnopqvuuuy26+678MYr77z01mvvvfjmq+++/Pbr778AByzwwAQXbPDBCCes8MIMN+zwwxBHLPHEFFds8cUYZ6zxxhx37PHHIIcs8sgkl2zyySinrPLKLLfs8sswxyzzzDTXbPPNOOes88489+zzz0AHLfTQ8vmQwzJmqKHGD/tYEg7RMrXSjhnUjGEBK2aw8DTUMH3gBitqWM0KFG5szbVLm3AgiQVjqPEM2WafvdIESZghyRhjUPMD/hQ98OLoCNFgMVIV24ywSk3CBF6ANDwI9k8KSVstiRm3NDCKMIwWAMnmVYgEzuaQjCARDzU0/tHnmxcgmA/vuBH21VDYkAYCjQojBeimfxRN6hKBUQMk4Gxz+uZSiIR5RccnlcghaugdexGjOCrM75AUD1I2m48Tke2gQyKNR67wHlI04EQjBQUUYKG++tisj8U0FGQjBfmQ5I6UMBMM0swF1rSjCQCP4gHohPcR7NUPItwDXTYI2BBsjCB5Cdmd9xQygmksrnMSmUb3NsjBDkIQKRNQhAWGEYEvfEEUf5KGFKaBBWwU4IXSiKEMpVEFFW4O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hLix0EzK6BDYmaRUaxA8MGU1IAyUV0xbe0Vde1FSKhAc5Y8d2q9DuBHqsJFt6w6yOIskKgEgWI5sCJXyugs3Wg/csAN+iyifJKHUE7kGIYZo63K/SgFphxDjgD2mCQabmnmMVno7e4Vl+7zQSz3QOhDctbkC/qFH4chd34hjHSGYhLmeMKAEWYCyYSABUbCRH0l+9QkD6oAERtAEtJsAjIKASjsQhAakLlVJWlUD1hsRRCkS3DW93Nm5CjACPSRWc1oDCygMwdYR37ABbgsDMBCzRlAPEgAKJ3CuJasHErwLa9oCBgAMttsoYKA5TgsGOQgO21lnYDi805idSEE9pikQctRGP5EFOGyjRnAG9TALpSAAUaAEbyvB7JsFNtoELWAKjVACiDCDkJJGNAEGTgoURsu7cnPFWJzFWrzFXNzFXvzFYBzGYjzGZFzGZnzGaJzGarzGbNzGbvzGcBzHcjzHdFzHdnzHeJzHerzHfNzHfvzH/oAcyII8yIRcyIZ8yIicyIq8yIzcyI78yJAcyZI8yZRcyZZ8yZicyZq8yZzcyZ78yaAcyqI8yqRcyqZ8yqicyqq8yqzcyq78yrAcy7I8y7Rcy7Z8y7icy7q8y7zcy778y8AczMI8zMRczMZ8zMiczMq8zMzczM78zNAczdI8zdRczdZ8zdiczdq8zdzczd78zeAczuI8zuRczuZ8zuiczuq8zuzczu78zvAcz/I8z/Rcz/Z8z/icz/q8z/zcz/78zwAd0AI90ARd0AZ90Aid0Aq90Azd0A790BAd0RI90RRd0RZ90Rid0Rq90Rzd0R790SAd0iI90iRd0iZ90iid/tIqvdIs3dIu/dIwHdMyPdM0XdM2fdM4ndM6vdM83dM+/dNAHdRCPdREXdRGfdRIndRKvdRM3dRO/dRQHdVSPdVUXdVWfdVYndVavdVc3dVe/dVgHdZiPdZkXdZmfdZondZqvdZs3dZu/dZwHddyPdd0Xdd2fdd4ndd6vdd83dd+/deAHdiCPdiEXdiGfdiIndiKvdiM3diO/diQHdmSPdmUXdmWfdmYndmavdmc3dme/dmgHdqiPdqkXdqmfdqondqqvdqs3dqu/dqwHduyPdu0Xdu2fdu4ndu6vdu83du+/dvAHdzCPdzEXdzGfdzIndzKvdzM3dzO/dzQHd3Ssz3d1F3d1n3d2J3d2r3d3N3d3v3d4B3e4j3e5F3e5n3e6J3e6r3e7N3e7v3e8B3f8j3f9F3f9n3f+J3f+r3f/N3f/v3fAB7gAj7gBF7gBn7gCJ7gCr7gDN7gDv7gEB7hEj7hFF7hFn7hGJ7hGr7hHN7hHv7hIB7iIj7iJF7iJn7iKJ7iKr7iLN7iLv7iMB7jMj7jNF7jNn7jOJ7jOr7jPN7jPv7jQB7kQj7kRF7kRn7kIx4QADs=";
        this._logoTexture.src = ""
        this._logoTexture.width = logoWidth;
        this._logoTexture.height = logoHeight;

        // bg
        this._bgLayer = cc.LayerColor.create(cc.c4(75, 193, 215, 255));
        this._bgLayer.setPosition(0, 0);
        this.addChild(this._bgLayer, 0);

        //loading percent
        this._label = cc.LabelTTF.create("Loading... 0%", "Arial", 30);
        this._label.setColor(cc.c3(240, 240, 240));
        this._label.setPosition(cc.pAdd(centerPos, cc.p(0, -logoHeight / 2 - 200)));
        this._bgLayer.addChild(this._label, 100);

        //title
        title = cc.LabelTTF.create("二店长出品 💅", "Arial", 50);
        title.setColor(cc.c3(240, 240, 240));
        title.setPosition(cc.pAdd(centerPos, cc.p(0, -logoHeight / 2 + 300)));
        this._bgLayer.addChild(title, 100);
    },

    _initStage: function (centerPos) {
        this._texture2d = new cc.Texture2D();
        this._texture2d.initWithElement(this._logoTexture);
        this._texture2d.handleLoadedTexture();
        this._logo = cc.Sprite.createWithTexture(this._texture2d);
        this._logo.setScale(cc.CONTENT_SCALE_FACTOR());
        this._logo.setPosition(centerPos);
        this._bgLayer.addChild(this._logo, 10);
    },

    onEnter: function () {
        cc.Node.prototype.onEnter.call(this);
        this.schedule(this._startLoading, 0.3);
    },

    onExit: function () {
        cc.Node.prototype.onExit.call(this);
        var tmpStr = "Loading... 0%";
        this._label.setString(tmpStr);
    },

    /**
     * init with resources
     * @param {Array} resources
     * @param {Function|String} selector
     * @param {Object} target
     */
    initWithResources: function (resources, selector, target) {
        this.resources = resources;
        this.selector = selector;
        this.target = target;
    },

    _startLoading: function () {
        this.unschedule(this._startLoading);
        cc.Loader.preload(this.resources, this.selector, this.target);
        this.schedule(this._updatePercent);
    },

    _updatePercent: function () {
        var percent = cc.Loader.getInstance().getPercentage();
        var tmpStr = "Loading... " + percent + "%";
        this._label.setString(tmpStr);

        if (percent >= 100)
            this.unschedule(this._updatePercent);
    }
});

/**
 * Preload multi scene resources.
 * @param {Array} resources
 * @param {Function|String} selector
 * @param {Object} target
 * @return {cc.LoaderScene}
 * @example
 * //example
 * var g_mainmenu = [
 *    {src:"res/hello.png"},
 *    {src:"res/hello.plist"},
 *
 *    {src:"res/logo.png"},
 *    {src:"res/btn.png"},
 *
 *    {src:"res/boom.mp3"},
 * ]
 *
 * var g_level = [
 *    {src:"res/level01.png"},
 *    {src:"res/level02.png"},
 *    {src:"res/level03.png"}
 * ]
 *
 * //load a list of resources
 * cc.LoaderScene.preload(g_mainmenu, this.startGame, this);
 *
 * //load multi lists of resources
 * cc.LoaderScene.preload([g_mainmenu,g_level], this.startGame, this);
 */
cc.LoaderScene.preload = function (resources, selector, target) {
    if (!this._instance) {
        this._instance = new cc.LoaderScene();
        this._instance.init();
    }

    this._instance.initWithResources(resources, selector, target);

    var director = cc.Director.getInstance();
    if (director.getRunningScene()) {
        director.replaceScene(this._instance);
    } else {
        director.runWithScene(this._instance);
    }

    return this._instance;
};
