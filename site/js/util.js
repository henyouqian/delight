
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
    if (reg.test(location.href)) return unescape(RegExp.$2.replace(/\+/g, " ")); return "";
};

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
var APPSTORE_URL = "https://itunes.apple.com/cn/app/man-pin-de/id923531990?l=zh&ls=1&mt=8"

function makeGravatarUrl(key, size) {
    var url = "http://en.gravatar.com/avatar/"+key+"?d=identicon&s="+size
    return url
}

(function() {
    $("body").append('<br><footer style="color:#ccc;text-align:center;">\
            <a><img id="appStoreLink" src="res/appStore.png" style="width:100%;max-width:140px;margin-right:10px;"></a>\
            浙ICP备15000079号\
        </footer><br>')

    $("#appStoreLink").click(function() {
        setTimeout(function(){
            alert('如不能自动跳转至App Store(苹果应用商店)，请点击右上"三个点"按钮，选择在Safari中打开，然后在Safari的页面中点击此App Store按钮。或直接至App Store搜索《蛮拼的》')
        }, 1000)
        window.location.href = APPSTORE_URL
    })
}())


