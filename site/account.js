
(function(){
	addHeader()
	addFooter()

	var WEIBO_APP_ID = 2485478034
	var WEIBO_REDICRCT_URI = "http://localhost:7777/oauth.html"
	
	$("#createTmpAccount").click(function(){
		var url = HOST + "auth/registerTmp"
		var data = {}
		$.post(url, function(resp) {
			localStorage.usertoken = resp.Token
			localStorage.uuid = resp.UUID

			$("#loginInfo").text("创建 userId:"+resp.UserId+" nickName:"+resp.Player.NickName)
		}, "json")
	})

	$("#tmpAccountLogin").click(function(){
		if (!isdef(localStorage.uuid)) {
			alert("no uuid")
			return
		}
		// var url = HOST + "auth/loginTmp"
		// var data = {
		// 	"UUID": localStorage.uuid,
		// }
		// $.post(url, JSON.stringify(data), function(resp) {
		// 	localStorage.usertoken = resp.Token
		// 	$("#loginInfo").text("临时账号 userId:"+resp.UserId+" nickName:"+resp.Player.NickName)
		// }, "json")
		var url = "auth/loginTmp"
		var data = {
			"UUID": localStorage.uuid,
		}
		post(url, data, function(resp, textStatus, jqXHR){
			console.log(textStatus)
			console.log(jqXHR)
			localStorage.usertoken = resp.Token
			$("#loginInfo").text("临时账号 userId:"+resp.UserId+" nickName:"+resp.Player.NickName)
		})
	})

	$("#weiboBind").click(function(){
		localStorage.action = "bind"
		window.location.href = "https://api.weibo.com/oauth2/authorize?client_id="+WEIBO_APP_ID+"&response_type=code&redirect_uri="+WEIBO_REDICRCT_URI+"&forcelogin=true"
	})

	$("#weiboLogin").click(function(){
		localStorage.action = "login"
		window.location.href = "https://api.weibo.com/oauth2/authorize?client_id="+WEIBO_APP_ID+"&response_type=code&redirect_uri="+WEIBO_REDICRCT_URI
	})

	$("#weiboLogout").click(function(){
		WB2.logout(function() {
		    alert("logout")
		});
	})


	// var url = HOST + "player/getInfo"
	// var data = {
	// 	"UserId":0
	// }
	// post(url, data, function(resp) {
	// 	console.log(resp)
	// })
	
})()