(function(){

	var action = localStorage.action
	
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

	url = HOST + url+ "?usertoken=" + localStorage.usertoken
	$.post(url, JSON.stringify(data), function(resp) {
			
		}, "json")

	// post(url, data, function(resp){
	// 	console.log(url)
	// 	console.log(resp)
	// })
	
})()