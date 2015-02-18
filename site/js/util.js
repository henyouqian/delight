
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

var Base64 = {
	// private property
	_keyStr : "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=",

	// public method for encoding
	encode : function (input) {
	    var output = "";
	    var chr1, chr2, chr3, enc1, enc2, enc3, enc4;
	    var i = 0;

	    input = Base64._utf8_encode(input);

	    while (i < input.length) {

	        chr1 = input.charCodeAt(i++);
	        chr2 = input.charCodeAt(i++);
	        chr3 = input.charCodeAt(i++);

	        enc1 = chr1 >> 2;
	        enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
	        enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
	        enc4 = chr3 & 63;

	        if (isNaN(chr2)) {
	            enc3 = enc4 = 64;
	        } else if (isNaN(chr3)) {
	            enc4 = 64;
	        }

	        output = output +
	        Base64._keyStr.charAt(enc1) + Base64._keyStr.charAt(enc2) +
	        Base64._keyStr.charAt(enc3) + Base64._keyStr.charAt(enc4);

	    }

	    return output;
	},

	// public method for decoding
	decode : function (input) {
	    var output = "";
	    var chr1, chr2, chr3;
	    var enc1, enc2, enc3, enc4;
	    var i = 0;

	    input = input.replace(/[^A-Za-z0-9\+\/\=]/g, "");

	    while (i < input.length) {

	        enc1 = Base64._keyStr.indexOf(input.charAt(i++));
	        enc2 = Base64._keyStr.indexOf(input.charAt(i++));
	        enc3 = Base64._keyStr.indexOf(input.charAt(i++));
	        enc4 = Base64._keyStr.indexOf(input.charAt(i++));

	        chr1 = (enc1 << 2) | (enc2 >> 4);
	        chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
	        chr3 = ((enc3 & 3) << 6) | enc4;

	        output = output + String.fromCharCode(chr1);

	        if (enc3 != 64) {
	            output = output + String.fromCharCode(chr2);
	        }
	        if (enc4 != 64) {
	            output = output + String.fromCharCode(chr3);
	        }

	    }

	    output = Base64._utf8_decode(output);

	    return output;

	},

	// private method for UTF-8 encoding
	_utf8_encode : function (string) {
	    string = string.replace(/\r\n/g,"\n");
	    var utftext = "";

	    for (var n = 0; n < string.length; n++) {

	        var c = string.charCodeAt(n);

	        if (c < 128) {
	            utftext += String.fromCharCode(c);
	        }
	        else if((c > 127) && (c < 2048)) {
	            utftext += String.fromCharCode((c >> 6) | 192);
	            utftext += String.fromCharCode((c & 63) | 128);
	        }
	        else {
	            utftext += String.fromCharCode((c >> 12) | 224);
	            utftext += String.fromCharCode(((c >> 6) & 63) | 128);
	            utftext += String.fromCharCode((c & 63) | 128);
	        }

	    }

	    return utftext;
	},

	// private method for UTF-8 decoding
	_utf8_decode : function (utftext) {
	    var string = "";
	    var i = 0;
	    var c = c1 = c2 = 0;

	    while ( i < utftext.length ) {

	        c = utftext.charCodeAt(i);

	        if (c < 128) {
	            string += String.fromCharCode(c);
	            i++;
	        }
	        else if((c > 191) && (c < 224)) {
	            c2 = utftext.charCodeAt(i+1);
	            string += String.fromCharCode(((c & 31) << 6) | (c2 & 63));
	            i += 2;
	        }
	        else {
	            c2 = utftext.charCodeAt(i+1);
	            c3 = utftext.charCodeAt(i+2);
	            string += String.fromCharCode(((c & 15) << 12) | ((c2 & 63) << 6) | (c3 & 63));
	            i += 3;
	        }

	    }
	    return string;
	}
}

function isdef(v) {
	return (typeof(v) != "undefined");
}

// function getUrlParam(name) {
// 	var reg = new RegExp("(^|\\?|&)"+ name +"=([^&]*)(\\s|&|$|#)", "i");  
// 	if (reg.test(decodeURI(location.href))) return unescape(RegExp.$2.replace(/\+/g, " ")); return "";
// };

function getUrlParam(param, url) {
  param = param.replace(/([\[\](){}*?+^$.\\|])/g, "\\$1");
  var regex = new RegExp("[?&]" + param + "=([^&#]*)");
  url   = url || decodeURIComponent(window.location.href);
  var match = regex.exec(url);
  return match ? match[1] : "";
}

function copyObj(obj) {
	return JSON.parse(JSON.stringify(obj))
}

var HOST = "http://sld.pintugame.com/"
var RES_HOST = "http://dn-pintuuserupload.qbox.me/"
var GAME_DIR = "game/index.html"
var WINXIN_APPSTORE_DIR = "weixin2appstore.html"
var APPSTORE_URL = "https://itunes.apple.com/cn/app/man-pin-de/id923531990?l=zh&ls=1&mt=8"


function makeGravatarUrl(key, size) {
	var url = "http://en.gravatar.com/avatar/"+key+"?d=identicon&s="+size
	return url
}

function getPlayerAvatarUrl(player, size) {
	var customKey = player.CustomAvatarKey
	var gravatarKey = player.GravatarKey
	return getAvatarUrl(customKey, gravatarKey, size)
}

function getAvatarUrl(avatar, gravatar, gravatarSize) {
	if (avatar.length > 0) {
		return RES_HOST + avatar
	} else if (gravatar.length > 0) {
		if (gravatarSize) {
			return makeGravatarUrl(gravatar, gravatarSize)
		} else {
			return makeGravatarUrl(gravatar, 40)
		}
	}
	return ""
}

function isWeixin(){
	var ua = navigator.userAgent.toLowerCase();
	if(ua.match(/MicroMessenger/i)=="micromessenger") {
		return true;
	} else {
		return false;
	}
}

function isMobile(){
	return /Android|webOS|iPhone|iPad|iPod|MicroMessenger|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
}

function setTitle(title) {
	$(".navbar-brand").text(title)
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
					<a id="brand" class="navbar-brand" href="#">慢慢拼</a>\
				</div>\
				<div id="navbar" class="collapse navbar-collapse">\
					<ul class="nav navbar-nav">\
						<li><a href="user.html?u=0">我的主页</a></li>\
						<li><a href="channelHub.html">分类推荐</a></li>\
						<li><a href="search.html">搜索</a></li>\
						<li><a id="menuAccount" href="account.html">账号</a></li>\
					</ul>\
				</div>\
			</div>\
		</nav>')

	var menuAccount = $("#menuAccount")
	if (lscache.get("accountType")) {
		var player = lscache.get("player")
		if (player) {
			menuAccount.text("账号（"+player.NickName+"  ID:"+player.UserId+"）")
		} else {
			menuAccount.text("账号")
		}
	} else {
		menuAccount.text("账号（未登录）")
	}
}

function addFooter() {
	$("body").append('<br><footer style="color:#ccc;text-align:center;">\
			<a><img class="appStoreLink" src="res/appStore.png" style="width:100%;max-width:140px;margin-right:10px;"></a>\
			浙ICP备15000079号\
		</footer><br>')

	$(".appStoreLink").click(function() {
		if (isWeixin()) {
			window.location.href = WINXIN_APPSTORE_DIR
		} else {
			window.location.href = APPSTORE_URL
		}
	})
}

function buttonEnable(button, enable) {
	button.prop('disabled', !enable)
	if (enable) {
		button.removeClass("btn-default")
		button.addClass("btn-info")
	} else {
		button.removeClass("btn-info")
		button.addClass("btn-default")
	}
}

function moveTaobaoAds() {
	$(document).ready(function(){
		var iframe = $("iframe")
		if (iframe) {
			var div = iframe.parent().parent()
			div.detach()
			$("#content").after(div)
		}
	})
}

function checkAuth() {
	if (lscache.get("accountType") == null) {
		lscache.set("returnUrl", window.location.href)
		window.location.href = "account.html"
	}
}

function post(url, data, func, errFunc) {
	if (url.indexOf("auth/") < 0) {
		checkAuth()
	}

	var idx = url.indexOf("?")
	if (idx == -1) {
		url = HOST + url + "?nocache=" + getTime()
	} else {
		url = HOST + url + "&nocache=" + getTime()
	}
	
	return $.post(url, JSON.stringify(data), function(resp, textStatus, jqXHR){
		func(resp, textStatus, jqXHR)
	}, "json")
	.error(function(xhr){
		var resp = xhr.responseJSON
		console.log(resp)
		if (isdef(resp.Error) && resp.Error == "err_auth") {
			if (window.location.pathname != "/account.html") {
				lscache.set("returnUrl", window.location.href)
				lscache.remove("player")
				window.location.href = "account.html"
			}
		} else {
			if (errFunc) {
				errFunc(resp)
			}
		}
	})
}

function rbPost(url, data, func, errFunc) {
	var idx = url.indexOf("?")
	if (idx == -1) {
		url = HOST + url + "?nocache=" + getTime()
	} else {
		url = HOST + url + "&nocache=" + getTime()
	}

	data.Secret = _secret
	return $.post(url, JSON.stringify(data), function(resp, textStatus, jqXHR){
		func(resp, textStatus, jqXHR)
	}, "json")
	.error(function(xhr){
		var resp = xhr.responseJSON
		console.log(resp)
		if (errFunc) {
			errFunc(resp)
		}
	})
}

function getPlayedMap() {
	var m = lscache.get("playedMatchMap")
	if (!isdef(m) || m == null ) {
		m = {}
	}
	return m
}

function extendPlayedMap(playedMap) {
	var oldMap = getPlayedMap()
	if (typeof(playedMap) == "object") {
		playedMap = $.extend(oldMap, playedMap)
		lscache.set("playedMatchMap", playedMap)
		return playedMap
	}
	return oldMap
}

function savePlayedMap(playedMap) {
	if (typeof(playedMap) == "object") {
		lscache.set("playedMatchMap", playedMap)
	}
}

function isLocked(matchId, playedMatchMap) {
	matchId = matchId.toString()
	if (!playedMatchMap) {
		playedMatchMap = getPlayedMap()
	}
	if (!playedMatchMap) {
		return true
	}
	if (matchId in playedMatchMap) {
		if (playedMatchMap[matchId].Played) {
			return false
		}
	}
	return true
}

function getTime() {
	var d=new Date()
	return d.getTime()
}

function dataURItoBlob(dataURI) {
    var byteString = atob(dataURI.split(',')[1]);
    var ab = new ArrayBuffer(byteString.length);
    var ia = new Uint8Array(ab);
    for (var i = 0; i < byteString.length; i++) {
        ia[i] = byteString.charCodeAt(i);
    }
    return new Blob([ab], { type: 'image/jpeg' });
}


(function(){
	if (window.location.hostname == "localhost" || window.location.hostname == "192.168.2.55" || window.location.hostname == "192.168.1.43") {
	    HOST = "http://"+window.location.hostname+":9998/"
	}

	$.ajaxSetup({
	  	cache: false,
		crossDomain: true,
		dataType: 'json',
		xhrFields: {
			withCredentials: true
		}
	});
})()

//lscache
!function(a,b){"function"==typeof define&&define.amd?define([],b):"undefined"!=typeof module&&module.exports?module.exports=b():a.lscache=b()}(this,function(){function a(){var a="__lscachetest__",c=a;if(void 0!==m)return m;try{g(a,c),h(a),m=!0}catch(d){m=b(d)?!0:!1}return m}function b(a){return a&&"QUOTA_EXCEEDED_ERR"===a.name||"NS_ERROR_DOM_QUOTA_REACHED"===a.name||"QuotaExceededError"===a.name?!0:!1}function c(){return void 0===n&&(n=null!=window.JSON),n}function d(a){return a+p}function e(){return Math.floor((new Date).getTime()/r)}function f(a){return localStorage.getItem(o+t+a)}function g(a,b){localStorage.removeItem(o+t+a),localStorage.setItem(o+t+a,b)}function h(a){localStorage.removeItem(o+t+a)}function i(a){for(var b=new RegExp("^"+o+t+"(.*)"),c=localStorage.length-1;c>=0;--c){var e=localStorage.key(c);e=e&&e.match(b),e=e&&e[1],e&&e.indexOf(p)<0&&a(e,d(e))}}function j(a){var b=d(a);h(a),h(b)}function k(a){var b=d(a),c=f(b);if(c){var g=parseInt(c,q);if(e()>=g)return h(a),h(b),!0}}function l(a,b){u&&"console"in window&&"function"==typeof window.console.warn&&(window.console.warn("lscache - "+a),b&&window.console.warn("lscache - The error was: "+b.message))}var m,n,o="lscache-",p="-cacheexpiration",q=10,r=6e4,s=Math.floor(864e13/r),t="",u=!1,v={set:function(k,m,n){if(a()){if("string"!=typeof m){if(!c())return;try{m=JSON.stringify(m)}catch(o){return}}try{g(k,m)}catch(o){if(!b(o))return void l("Could not add item with key '"+k+"'",o);var p,r=[];i(function(a,b){var c=f(b);c=c?parseInt(c,q):s,r.push({key:a,size:(f(a)||"").length,expiration:c})}),r.sort(function(a,b){return b.expiration-a.expiration});for(var t=(m||"").length;r.length&&t>0;)p=r.pop(),l("Cache is full, removing item with key '"+k+"'"),j(p.key),t-=p.size;try{g(k,m)}catch(o){return void l("Could not add item with key '"+k+"', perhaps it's too big?",o)}}n?g(d(k),(e()+n).toString(q)):h(d(k))}},get:function(b){if(!a())return null;if(k(b))return null;var d=f(b);if(!d||!c())return d;try{return JSON.parse(d)}catch(e){return d}},remove:function(b){a()&&j(b)},supported:function(){return a()},flush:function(){a()&&i(function(a){j(a)})},flushExpired:function(){a()&&i(function(a){k(a)})},setBucket:function(a){t=a},resetBucket:function(){t=""},enableWarnings:function(a){u=a}};return v});


