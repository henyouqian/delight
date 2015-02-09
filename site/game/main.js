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
var HOST = "http://sld.pintugame.com/"
// var HOST = "http://localhost:9998/"
if (window.location.hostname == "localhost" || window.location.hostname == "192.168.2.55" || window.location.hostname == "192.168.1.43") {
    HOST = "http://"+window.location.hostname+":9998/"
}
var QINIU_HOST = "http://dn-pintuuserupload.qbox.me/"
var WEBSOCKET_URL = "ws://127.0.0.1:8080/ws"

var g_match = null

function getUrlParam(name) {
    var reg = new RegExp("(^|\\?|&)"+ name +"=([^&]*)(\\s|&|$)", "i");  
    if (reg.test(location.href)) return unescape(RegExp.$2.replace(/\+/g, " ")); return "";
};

var cocos2dApp = cc.Application.extend({
    config:document['ccConfig'],
    ctor:function (scene) {
        this._super();
        this.startScene = scene;
        cc.COCOS2D_DEBUG = this.config['COCOS2D_DEBUG'];
        cc.initDebugSetting();
        cc.setup(this.config['tag']);
        cc.AppController.shareAppController().didFinishLaunchingWithOptions();
    },
    applicationDidFinishLaunching:function () {
        $.ajaxSettings.cache = false
        $.ajaxSettings.crossDomain = true
        $.ajaxSettings.dataType = 'json'
        $.ajaxSettings.xhrFields = {
            withCredentials: true
        }
        

        if(cc.RenderDoesnotSupport()){
            //show Information to user
            alert("Browser doesn't support WebGL");
            return false;
        }
        // initialize director
        var director = cc.Director.getInstance();

        cc.EGLView.getInstance().resizeWithBrowserSize(true);
        cc.EGLView.getInstance().setDesignResolutionSize(640, 960, cc.RESOLUTION_POLICY.SHOW_ALL);

        // turn on display FPS
        director.setDisplayStats(this.config['showFPS']);

        // set FPS. the default value is 1.0/60 if you don't call this
        director.setAnimationInterval(1.0 / this.config['frameRate']);

        //
        cc.AudioEngine.getInstance().init("mp3,ogg,wav");

        //load packs
        //var key = parseInt(getUrlParam("key")) 
        var key = getUrlParam("key")
        var battle = getUrlParam("battle")
        var matchId = parseInt(getUrlParam("matchId")) 

        var app = this
        g_key = key

        if (matchId > 0) {
            var body = {
                "MatchId": matchId
            }
            
            var url = HOST + "social/getMatch"
            $.post(url, JSON.stringify(body), function(resp){
                g_match = resp.Match
                g_pack = resp.Pack 
                g_ranks = resp.Ranks
                g_sliderNum = g_match.SliderNum
                var reses = []
                g_imageUrls = []
                var images = resp.Pack.Images
                for (var i in images) {
                    var image = images[i]
                    var url = QINIU_HOST+image.Key
                    if (("Url" in image) && image.Url.length > 0 ) {
                        url = image.Url
                    }
                    reses.push({src:url})
                    g_imageUrls.push(url)
                }
                g_bgUrl = QINIU_HOST+resp.Pack.CoverBlur
                reses.push({src:g_bgUrl})

                g_thumbUrl = QINIU_HOST+resp.Pack.Thumb

                cc.LoaderScene.preload(reses, function () {
                    director.replaceScene(new app.startScene());
                }, app);

            }, "json")
        } else if (battle == "") {
            var body = {
                "Key": key
            }
            
            var url = HOST + "social/getPack"
            $.post(url, JSON.stringify(body), function(resp){
                var reses = []
                g_imageUrls = []
                g_socialPack = resp
                g_pack = resp.Pack
                g_ranks = resp.Ranks
                g_sliderNum = resp.SliderNum
                var images = resp.Pack.Images
                for (var i in images) {
                    var image = images[i]
                    var url = QINIU_HOST+image.Key
                    if (("Url" in image) && image.Url.length > 0 ) {
                        url = image.Url
                    }
                    reses.push({src:url})
                    g_imageUrls.push(url)
                }
                g_bgUrl = QINIU_HOST+resp.Pack.CoverBlur
                reses.push({src:g_bgUrl})

                g_thumbUrl = QINIU_HOST+resp.Pack.Thumb

                cc.LoaderScene.preload(reses, function () {
                    director.replaceScene(new app.startScene());
                }, app);

            }, "json")
        } else {
            cc.LoaderScene.preload([], function () {
                director.replaceScene(new app.startScene());
            }, app);
        }

        return true;
    }
});

var g_app
var g_isBattle = getUrlParam("battle")
if (g_isBattle == "") {
    g_app = new cocos2dApp(SliderScene);
} else {
    g_app = new cocos2dApp(BattleConnectScene);
}

