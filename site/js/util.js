
//=====================================================
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

function delCookie(c_name){
    setCookie(c_name, 0, -1);
}

//=====================================================
//requestAnimationFrame & cancelAnimationFrame
(function() {
    var lastTime = 0;
    var vendors = ['ms', 'moz', 'webkit', 'o'];
    for(var x = 0; x < vendors.length && !window.requestAnimationFrame; ++x) {
        window.requestAnimationFrame = window[vendors[x]+'RequestAnimationFrame'];
        window.cancelAnimationFrame = 
          window[vendors[x]+'CancelAnimationFrame'] || window[vendors[x]+'CancelRequestAnimationFrame'];
    }
 
    if (!window.requestAnimationFrame)
        window.requestAnimationFrame = function(callback, element) {
            var currTime = new Date().getTime();
            var timeToCall = Math.max(0, 16 - (currTime - lastTime));
            var id = window.setTimeout(function() { callback(currTime + timeToCall); }, 
              timeToCall);
            lastTime = currTime + timeToCall;
            return id;
        };
 
    if (!window.cancelAnimationFrame)
        window.cancelAnimationFrame = function(id) {
            clearTimeout(id);
        };
}());

//=====================================================
//unbase64
var _keyStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

/* will return a  Uint8Array type */
function unbase64(input) {
    //get last chars to see if are valid
    var lkey1 = this._keyStr.indexOf(input.charAt(input.length-1));
    var lkey2 = this._keyStr.indexOf(input.charAt(input.length-2));

    var bytes = (input.length/4) * 3;
    if (lkey1 == 64) bytes--; //padding chars, so skip
    if (lkey2 == 64) bytes--; //padding chars, so skip

    var uarray;
    var chr1, chr2, chr3;
    var enc1, enc2, enc3, enc4;
    var i = 0;
    var j = 0;

    uarray = new Uint8Array(bytes);

    input = input.replace(/[^A-Za-z0-9\+\/\=]/g, "");

    for (i=0; i<bytes; i+=3) {  
        //get the 3 octects in 4 ascii chars
        enc1 = this._keyStr.indexOf(input.charAt(j++));
        enc2 = this._keyStr.indexOf(input.charAt(j++));
        enc3 = this._keyStr.indexOf(input.charAt(j++));
        enc4 = this._keyStr.indexOf(input.charAt(j++));

        chr1 = (enc1 << 2) | (enc2 >> 4);
        chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
        chr3 = ((enc3 & 3) << 6) | enc4;

        uarray[i] = chr1;           
        if (enc3 != 64) uarray[i+1] = chr2;
        if (enc4 != 64) uarray[i+2] = chr3;
    }

    return uarray;  
}

function isdef(v) {
    return (typeof(v) != "undefined");
}

function getUrlParam(name) {
    var reg = new RegExp("(^|\\?|&)"+ name +"=([^&]*)(\\s|&|$)", "i");  
    if (reg.test(decodeURI(location.href))) return unescape(RegExp.$2.replace(/\+/g, " ")); return "";
};
// function getUrlParam(paramName) {
//     paramValue = "";
//     var isFound = false;
//     var 
//     if (this.location.search.indexOf("?") == 0 && this.location.search.indexOf("=") > 1) {
//         arrSource = unescape(this.location.search).substring(1, this.location.search.length).split("&");
//         i = 0;
//         while (i < arrSource.length && !isFound) {
//             if (arrSource[i].indexOf("=") > 0) {
//                 if (arrSource[i].split("=")[0].toLowerCase() == paramName.toLowerCase()) {
//                     paramValue = arrSource[i].split("=")[1];
//                     isFound = true;
//                 }
//             }
//             i++;
//         }
//     }
//     return paramValue;
// }

function copyObj(obj) {
    return JSON.parse(JSON.stringify(obj))
}

function saveObj(key, obj) {
    window.localStorage[key] = JSON.stringify(obj)
}

function loadObj(key) {
    JSON.parse(window.localStorage[key])
}

var HOST = "http://sld.pintugame.com/"
// var HOST = "http://localhost:9998/"
var RES_HOST = "http://dn-pintuuserupload.qbox.me/"
var GAME_DIR = "game/index.html"
var WINXIN_SPPSTORE_DIR = "weixin2appstore.html"
var APPSTORE_URL = "https://itunes.apple.com/cn/app/man-pin-de/id923531990?l=zh&ls=1&mt=8"


function makeGravatarUrl(key, size) {
    var url = "http://en.gravatar.com/avatar/"+key+"?d=identicon&s="+size
    return url
}

function isWeixin(){
    var ua = navigator.userAgent.toLowerCase();
    if(ua.match(/MicroMessenger/i)=="micromessenger") {
        return true;
    } else {
        return false;
    }
}

function addHeader() {
    $("body").prepend('<nav class="navbar navbar-default navbar-fixed-top" role="navigation">\
            <div class="container">\
                <div class="navbar-header">\
                    <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar" aria-expanded="t ru" aria-controls="navbar">\
                        <span class="sr-only">Toggle navigation</span>\
                        <span class="icon-bar"></span>\
                        <span class="icon-bar"></span>\
                        <span class="icon-bar"></span>\
                    </button>\
                    <a class="navbar-brand" href="#">蛮拼的</a>\
                </div>\
                <div id="navbar" class="collapse navbar-collapse">\
                    <ul class="nav navbar-nav">\
                        <li><a href="search.html">搜索</a></li>\
                        <li><a href="#" class="appStoreLink">下载iPhone客户端</a></li>\
                    </ul>\
                </div>\
            </div>\
        </nav>')
}

function addFooter() {
    $("body").append('<br><footer style="color:#ccc;text-align:center;">\
            <a><img class="appStoreLink" src="res/appStore.png" style="width:100%;max-width:140px;margin-right:10px;"></a>\
            浙ICP备15000079号\
        </footer><br>')

    $(".appStoreLink").click(function() {
        if (isWeixin()) {
            window.location.href = WINXIN_SPPSTORE_DIR
        } else {
            window.location.href = APPSTORE_URL
        }
        // setTimeout(function(){
        //     window.location.href = WINXIN_SPPSTORE_DIR
        // }, 500)
    })
}


