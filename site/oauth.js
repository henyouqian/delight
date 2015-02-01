(function(){

	var action = lscache.get("action")
	
	var url = ""
	if (action == "bind") {
		url = "auth/weiboBind"
	} else if (action == "login"){
		url = "auth/weiboLogin"
	} else {
		alert("no param action")
		return
	}

	var code = getUrlParam("code")
	if (!code) {
		alert("no param code")
		return
	}

	var data = {
		"Code":code
	}

	post(url, data, function(resp){
		lscache.set("accountType", "weibo")
		lscache.set("userName", resp.Player.NickName)
		
		var returnUrl = lscache.get("returnUrl")
		if (returnUrl) {
			lscache.remove("returnUrl")
			window.location.href = returnUrl
		} else {
			window.location.href = "account.html"
		}
	}, function(resp){
		if (resp.Error == "err_weibo_account_using") {
			$("#output").text("此微博账号已被绑定，请换其他微博账号绑定或直接用此微博账号登陆。")
		} if (resp.Error == "err_weibo_no_account") {
			$("#output").text("此微博账号未被绑定。")
		} else {
			$("#output").text("错误："+resp.Error)
		}
		$("#back").show()
	})

	$("#back").click(function(){
		window.history.go(-2)
	})
	
})()