$().ready(function() {
	addHeader()
	addFooter()
	moveTaobaoAds()

	var matchNum = 0
	var limit = 27
	var pageNum = 1
	var currPage = -100
	var followed = false

	var userId = parseInt(getUrlParam("u"))
	var userName = ""

	var _matches = {};

	function loadPage(pageIndex, saveHistory) {
		// if (pageIndex == currPage) {
		// 	return
		// }

		$("#thumbRoot").empty()

		var url = "match/web/listUserQ"
		var data = {
			"UserId": userId,
			"Offset": pageIndex*limit,
			"Limit": limit
		}
		
		post(url, data, function(resp){
			console.log(resp)
			var matches = resp.Matches
			matchNum = resp.MatchNum
			var playedMatchMap = resp.PlayedMatchMap
			savePlayedMap(playedMatchMap)

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
				if (isLocked(match.Id, playedMatchMap)) {
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
		"UserId": userId,
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

		//follow button
		followed = resp.Followed
		var followButton = $("#followButton")
		followButton.removeClass("btn-warning btn-info")

		if (followed) {
			followButton.addClass("btn-warning")
			followButton.text("取消关注")
		} else {
			followButton.addClass("btn-info")
			followButton.text("关注")
		}
		
		followButton.show()

		//
		var pageIndex = getPageIndexFromUrl()
		loadPage(pageIndex, true)
		// alert("onGetPlayerInfo")
	})

	$("#follow").click(function(){
		if (followNum == 0) {
			return
		}
		window.location.href = encodeURI("follow.html?type=0&userId="+userId+"&userName="+userName)
	})
	$("#fan").click(function(){
		if (fanNum == 0) {
			return
		}
		window.location.href = encodeURI("follow.html?type=1&userId="+userId+"&userName="+userName)
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

	$("#followButton").click(function(){
		var url = "player/follow"
		if (followed) {
			url = "player/unfollow"
		}
		var data = {
			"UserId":userId
		}
		post(url, data, function(resp){
			followed = resp.Follow
			myFollowNum = resp.FollowNum
			fanNum = resp.FanNum
			// $("#follow").text("关注："+followNum)
			$("#fan").text("粉丝："+fanNum)

			var followButton = $("#followButton")
			followButton.removeClass("btn-warning btn-info")
			if (followed) {
				followButton.addClass("btn-warning")
				followButton.text("取消关注")
			} else {
				followButton.addClass("btn-info")
				followButton.text("关注")
			}
		}, function(resp){
			alert(resp.Error)
		})
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
		var playedMatchMap = getPlayedMap()

		var str = ""
		for (var k in playedMatchMap) {
			str += k + ","
		}
		// alert(str)
		
		lockerElems.each(function(){
			var elem = $(this)
			var matchId = parseInt(elem.attr("matchId"))
			if (isLocked(matchId, playedMatchMap)) {
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