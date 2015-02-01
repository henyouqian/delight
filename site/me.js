$().ready(function() {
	addHeader()
	addFooter()
	setTitle("我的主页")
	moveTaobaoAds()

	var matchNum = 0
	var limit = 30
	var pageNum = 1
	var currPage = -100
	var followed = false

	var userName = ""

	var _matches = {};

	function isLocked(matchId, playedMatchIdMap) {
		if (!playedMatchIdMap) {
			playedMatchIdMap = getPlayedMap()
		}
		if (!playedMatchIdMap) {
			return true
		}
		return !(matchId in playedMatchIdMap)
	}

	function loadPage(pageIndex, saveHistory) {
		// if (pageIndex == currPage) {
		// 	return
		// }

		$("#thumbRoot").empty()

		var url = "match/web/listUserQ"
		var data = {
			"UserId": 0,
			"Offset": pageIndex*limit,
			"Limit": limit
		}
		
		post(url, data, function(resp){
			var matches = resp.Matches
			matchNum = resp.MatchNum
			var playedMatchIds = resp.PlayedMatchIds
			var playedMatchIdMap = {}
			for (var i in playedMatchIds) {
				id = playedMatchIds[i]
				playedMatchIdMap[id] = true
			}
			savePlayedMap(playedMatchIdMap)

			var str = "savePlayedMap:"
			for (var k in playedMatchIdMap) {
				str += k + ","
			}
			// alert(str)


			if (pageIndex < 0) {
				var nMatch = matchNum % limit
				matches = matches.slice(-nMatch)
			}

			for (var i in matches) {
				var match = matches[i]
				var thumbUrl = RES_HOST + match.Thumb
	 
				var thumbElem = $('\
					<div class="thumbnail thumb packThumb" style="position:relative;">\
						<a href="match.html?key=' + match.Id + '">\
							<img src="' + thumbUrl +'">\
						</a>\
					</div>\
					')
				$("#thumbRoot").append(thumbElem);
				var lockerElem = $('<div class="locker" matchId="'+match.Id+'" style="position:absolute;top:0px;left:-2px;top:3px;"><img src="res/locker.png" style="width:17px;height:20px;"></div>')
				thumbElem.append(lockerElem)
				if (isLocked(match.Id, playedMatchIdMap)) {
					lockerElem.show()
				} else {
					lockerElem.hide()
				}

				_matches[match.Id] = match
			}

			//page
			pageNum = 1
			if (matchNum > 0) {
				pageNum = Math.floor((matchNum-1) / limit) + 1
			}
			currPage = pageIndex
			if (currPage == -1) {
				currPage = pageNum - 1
			}
			$(".pageButton").text((currPage+1)+"/"+pageNum)

			//
			if (currPage == 0) {
				$(".previous").addClass("disabled")
			} else {
				$(".previous").removeClass("disabled")
			}
			if (currPage == pageNum - 1) {
				$(".next").addClass("disabled")
			} else {
				$(".next").removeClass("disabled")
			}

			//check page
			if (currPage >= pageNum) {
				var newURL = window.location.href.split('#')[0] + '#&page=' + (pageNum-1);
				loadPage(pageNum-1, false)
				return
			} else {
				var newURL = window.location.href.split('#')[0] + '#&page=' +  currPage;
				if (saveHistory && currPage != pageNum-1) {
					window.location.assign(newURL)
				} else {
					window.location.replace(newURL)
				}
			}
			
		}, "json")
	}

	//get player info
	var fanNum = 0
	var followNum = 0

	var url = "player/web/getInfo"
	var data = {
		"UserId": 0,
	}

	post(url, data, function(resp){
		console.log(resp)
		var nickName = resp.NickName
		var customKey = resp.CustomAvatarKey
		var gravatarKey = resp.GravatarKey
		matchNum = resp.MatchNum

		fanNum = resp["FanNum"]
		followNum = resp["FollowNum"]
		userName = nickName
		$("#userName").text(nickName)

		if (customKey.length > 0) {
			var url = RES_HOST + customKey
			$("#avatar").prop("src", url)
		} else if (gravatarKey.length > 0) {
			$("#avatar").attr("src", makeGravatarUrl(gravatarKey, 64))
		}
		$("#follow").text("关注："+followNum)
		$("#fan").text("粉丝："+fanNum)

		//
		var pageIndex = getPageIndexFromUrl()
		loadPage(pageIndex, true)
		// alert("onGetPlayerInfo")
	})

	$("#follow").click(function(){
		if (followNum == 0) {
			return
		}
		window.location.href = encodeURI("follow.html?type=0&userId=0&userName="+userName)
	})
	$("#fan").click(function(){
		if (fanNum == 0) {
			return
		}
		window.location.href = encodeURI("follow.html?type=1&userId=0&userName="+userName)
	})

	$(".previous").click(function(){
		if (currPage == 0) {
			return
		}
		loadPage(currPage-1,true)
		// var newURL = window.location.href.split('#')[0] + '#&page=' + (currPage-1);
		// window.location.assign(newURL)

	})
	$(".next").click(function(){
		if (currPage == pageNum - 1) {
			return
		}
		loadPage(currPage+1,true)
		// var newURL = window.location.href.split('#')[0] + '#&page=' + (currPage+1);
		// window.location.assign(newURL)
	})

	$(".pageButton").click(function(){
		var input = $("#pageInput")
		input.val("")
		input.attr("placeholder", "请输入跳转页码（"+1+"-"+pageNum+"）")
		input[0].focus()
		$("#pageModal").modal("show")
	})

	$("#gotoPage").click(function(){
		var input = $("#pageInput")
		if (input.val() == "") {
			return
		}
		var pageIdx = parseInt(input.val())-1
		if (pageIdx == currPage) {
			$("#pageModal").modal("hide")
		} else if (pageIdx >= 0 && pageIdx < pageNum) {
			$("#pageModal").modal("hide")
			loadPage(pageIdx,true)
		} else {
			input.val("")
			input.attr("placeholder", "输入错误，请输入跳转页码（"+1+"-"+pageNum+"）")
		}
		
	})

	function getPageIndexFromUrl() {
		var pageIndex = getUrlParam("page")
		if (pageIndex == "") {
			pageNum = 1
			if (matchNum > 0) {
				pageNum = Math.floor((matchNum-1) / limit) + 1
			}
			pageIndex = pageNum-1
		} else {
			pageIndex = parseInt(pageIndex)
		}
		return pageIndex
	}

	window.onhashchange = function(){
		var pageIndex = getPageIndexFromUrl()
		loadPage(pageIndex, false)
		// alert("onHashChange")
	}

	window.onpageshow = function() {
		var lockerElems = $(".locker")
		var playedMatchIdMap = getPlayedMap()

		var str = ""
		for (var k in playedMatchIdMap) {
			str += k + ","
		}
		// alert(str)
		
		lockerElems.each(function(){
			var elem = $(this)
			var matchId = parseInt(elem.attr("matchId"))
			if (isLocked(matchId, playedMatchIdMap)) {
				elem.show()
			} else {
				elem.hide()
			}
		})
	};

	// window.onload = function() {
	// 	window.onpageshow()
	// }
	
})