$().ready(function() {
	addHeader()
	addFooter()

	setTitle("账号")

	$("#buttons").children().each(function(){
		$(this).hide()
	})
	$("#buttons").show()

	var WEIBO_APP_ID = 2485478034
	var WEIBO_REDICRCT_URI = location.origin+"/oauth.html"
	
	$("#createTmpAccount").click(function(){
		var url = HOST + "auth/registerTmp"
		var data = {}
		$.post(url, function(resp) {
			lscache.set("uuid", resp.UUID)
			lscache.set("userName", resp.Player.NickName)
			lscache.set("userId", resp.UserId)
			// $("#loginInfo").text("创建 userId:"+resp.UserId+" nickName:"+resp.Player.NickName)

			lscache.set("accountType", "tmp")
			var returnUrl = lscache.get("returnUrl")
			if (returnUrl) {
				lscache.remove("returnUrl")
				window.location.href = returnUrl
			} else {
				location.reload()
			}
		}, "json")
	})

	$("#tmpAccountLogin").click(function(){
		var uuid = lscache.get("uuid")
		if (uuid == null) {
			alert("no uuid")
			return
		}
		var url = "auth/loginTmp"
		var data = {
			"UUID": uuid,
		}
		post(url, data, function(resp){
			lscache.set("accountType", "tmp")
			lscache.set("userName", resp.Player.NickName)
			lscache.set("userId", resp.UserId)

			var returnUrl = lscache.get("returnUrl")
			if (returnUrl) {
				lscache.remove("returnUrl")
				window.location.href = returnUrl
			} else {
				location.reload()
			}
		}, function(resp) {
			lscache.remove("uuid")
			location.reload()
		})
	})

	$("#weiboBind").click(function(){
		lscache.set("action", "bind")
		window.location.href = "https://api.weibo.com/oauth2/authorize?client_id="+WEIBO_APP_ID+"&response_type=code&redirect_uri="+WEIBO_REDICRCT_URI+"&forcelogin=true"
	})

	$("#weiboLogin").click(function(){
		lscache.set("action", "login")
		window.location.href = "https://api.weibo.com/oauth2/authorize?client_id="+WEIBO_APP_ID+"&response_type=code&redirect_uri="+WEIBO_REDICRCT_URI
	})

	$("#weiboChangeAccount").click(function(){
		var uuid = lscache.get("uuid")
		if (uuid) {
			$('#weiboChangeAccountModal').modal('show')
		} else {
			doWeiboChangeAccount()
		}
	})

	$("#weiboChangeAccountConfirm").click(function(){
		doWeiboChangeAccount()
	})

	function doWeiboChangeAccount() {
		lscache.set("action", "login")
		window.location.href = "https://api.weibo.com/oauth2/authorize?client_id="+WEIBO_APP_ID+"&response_type=code&redirect_uri="+WEIBO_REDICRCT_URI+"&forcelogin=true"
	}

	$("#logout").click(function(){
		$('#logoutModal').modal('show')
	})
	$("#logoutConfirm").click(function(){
		$('#logoutModal').modal('hide')
		delCookie("usertoken")
		lscache.remove("accountType")
		lscache.remove("userName")
		location.reload()
	})

	function setPlayerInfo(player) {
		$("#userRow").show()
		
		//avatar
		var customKey = player.CustomAvatarKey
		var gravatarKey = player.GravatarKey
		var avatarObj = $("#avatar")
		if (customKey.length > 0) {
			var url = RES_HOST + customKey
			avatarObj.attr("src", url)
		} else if (gravatarKey.length > 0) {
			avatarObj.attr("src", makeGravatarUrl(gravatarKey, 40))
		}

		//user name
		$("#userName").text(player.NickName)
		lscache.set("userName", player.NickName)
	}

	
	if (!lscache.get("accountType")) {
		onNotLogin()
	} else {
		var url = "player/getInfo"
		var data = {
			"UserId":0
		}
		post(url, data, function(resp) { //logged in
			console.log(resp)
			var player = resp
			setPlayerInfo(player)

			//show buttons
			$("#weiboChangeAccount").show();
			$("#logout").show();

			var accountType = lscache.get("accountType")
			if (accountType=="tmp") {
				$("#weiboBind").show();
			}

		}).error(function(){ //not login
			onNotLogin()
		})
	}
	

	function onNotLogin() {
		$("#userRow").hide()

		var uuid = lscache.get("uuid")
		if (!uuid) {
			$("#createTmpAccount").show();
		} else {
			$("#tmpAccountLogin").show();
		}
		//show buttons
		$("#weiboLogin").show();
	}
	
})