(function(){
	addHeader()
	addFooter()
	moveTaobaoAds()

	var matchNum = 0
	var limit = 30
	var pageNum = 1
	var currPage = -100

	var userId = parseInt(getUrlParam("u"))
	var userName = ""

	var _matches = {};

	function loadPage(pageIndex) {
		// if (pageIndex == currPage) {
		// 	return
		// }
		console.log("loadPage:", pageIndex)

		$("#thumbRoot").empty()

		var url = HOST + "match/web/listUserQ"
		var data = {
			"UserId": userId,
			"Offset": pageIndex*limit,
			"Limit": limit
		}
		
		$.post(url, JSON.stringify(data), function(resp){
			var matches = resp.Matches
			matchNum = resp.MatchNum
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
				if (!isdef(localStorage["matchPlayed/"+match.Id])) {
					lockerElem.show()
				} else {
					lockerElem.hide()
				}

				_matches[match.Id] = match
			}
			
			localStorage.matches = JSON.stringify(_matches)

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
				loadPage(pageNum-1)
				return
			} else {
				var newURL = window.location.href.split('#')[0] + '#&page=' +  currPage;
				window.location.assign(newURL)
			}
			
		}, "json")
	}

	//get player info
	var fanNum = 0
	var followNum = 0

	var url = HOST + "player/web/getInfo"
	var data = {
		"UserId": userId,
	}
	$.post(url, JSON.stringify(data), function(resp) {
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
		
		// var newURL = window.location.href.split('#')[0] + '#&page=' + (pageNum-1);
		// window.location.replace(newURL)
		loadPage(pageIndex)
	}, "json")

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
		loadPage(currPage-1)
		// var newURL = window.location.href.split('#')[0] + '#&page=' + (currPage-1);
		// window.location.assign(newURL)

	})
	$(".next").click(function(){
		if (currPage == pageNum - 1) {
			return
		}
		loadPage(currPage+1)
		// var newURL = window.location.href.split('#')[0] + '#&page=' + (currPage+1);
		// window.location.assign(newURL)
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
		loadPage(pageIndex)
	}

	window.onpageshow = function() {
		var lockerElems = $(".locker")
		lockerElems.each(function(i, v){
			var elem = $(v)
			var matchId = elem.attr("matchId")
			if (!isdef(localStorage["matchPlayed/"+matchId])) {
				elem.show()
			} else {
				elem.hide()
			}
		})
	};

	window.onload = function() {
		window.onpageshow()
	}
	
})();