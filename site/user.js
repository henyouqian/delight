$().ready(function() {
	addHeader()
	addFooter()
	moveTaobaoAds()

	var matchNum = 0
	var limit = 9
	var pageNum = 1
	var currPage = -100
	var followed = false

	var userId = parseInt(getUrlParam("u"))
	var userName = ""

	var contentElem = $("#content")
	var enterMatchId = 0
	var _matches = {}
	var packs = {}

	function loadPage(pageIndex, saveHistory) {
		// if (pageIndex == currPage) {
		// 	return
		// }

		contentElem.empty()

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
				_matches[match.Id] = match

				var cardElem = $("#template>.card").clone()
				contentElem.append(cardElem)

				var thumbRoot = $(".thumbRoot", cardElem)
				var locked = isLocked(match.Id)
				for (var iThumb in match.Thumbs) {
					var thumbKey = match.Thumbs[iThumb]
					var thumbElem = $("#template>.thumb").clone()
					var thumbUrl = RES_HOST + thumbKey
					$("img", thumbElem).attr("src", thumbUrl)
					thumbRoot.append(thumbElem)
					thumbElem.attr("matchId", match.Id)
					thumbElem.attr("index", iThumb)

					var lockerElem = $('<div class="locker" matchId="'+match.Id+'" style="position:absolute;top:0px;left:-6px;top:2px;"><img src="res/locker.png" style="width:17px;height:20px;"></div>')
					thumbElem.append(lockerElem)
					if (locked) {
						lockerElem.show()
					} else {
						lockerElem.hide()
					}

					thumbElem.click(function(a) {
						var thumbElem = $(this)
						var matchId = thumbElem.attr("matchId")
						enterMatchId = matchId
						if (isLocked(matchId)) {
							$('#thumbModal').modal('show')
							return
						}


						var index = parseInt(thumbElem.attr("index"))
						var match = _matches[matchId]
						var pack = packs[match.PackId]
						if (!pack) {
							var url = "pack/get"
							var data = {
								"Id": match.PackId
							}
							$(".hudBgFrame").fadeIn()
							post(url, data, function(resp){
								$(".hudBgFrame").fadeOut()
								var pack = resp
								packs[pack.Id] = pack
								showImage(pack, index)
							})
						} else {
							showImage(pack, index)
						}

					})
				}
				var playButton = $(".playButton", cardElem)
				playButton[0].matchId = match.Id
				playButton.click(function(){
					window.location.href = GAME_DIR+'?matchId='+$(this)[0].matchId
				})


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

	$(".playConfirmButton").click(function(){
		$('#thumbModal').modal('hide')
		window.location.href = GAME_DIR+'?matchId='+enterMatchId
	})

	function showImage(pack, thumbIndex) {
		var images = pack.Images
		var items = []
		for (var i in images) {
			var image = images[i]
			var item = {}
			if (image.Url.length > 0) {
				item.src = image.Url
			} else {
				item.src = RES_HOST + image.Key
			}
			item.w = image.W
			item.h = image.H
			items.push(item)
		}


		//photoswipe
		var pswpElement = document.querySelectorAll('.pswp')[0];

		// define options (if needed)
		var options = {
			index: thumbIndex
		};

		// Initializes and opens PhotoSwipe
		var gallery = new PhotoSwipe( pswpElement, PhotoSwipeUI_Default, items, options);
		gallery.init();

		//photo swipe gif fix
		var iOSv;
		if (/iP(hone|od|ad)/.test(navigator.platform)) {
			iOSv = (navigator.appVersion).match(/OS (\d+)_(\d+)_?(\d+)?/);
			iOSv = parseInt(iOSv[1], 10);
		}

		if(iOSv >= 8) {
			gallery.listen('afterChange', function() {
				if(gallery.currItem.src.indexOf('.gif') > 0) {
					var currHolder = gallery.itemHolders[1];
					if(currHolder && currHolder.el) {
						var imgs = currHolder.el.getElementsByClassName('pswp__img');
						if(imgs.length) {
							var img = imgs[imgs.length - 1];
							// toggle opacity on gif IMG
							img.style.opacity = img.style.opacity == 0.99999 ? 1 : 0.99999;
						}

					}
				}
			});
		}
	}

	// window.onload = function() {
	// 	window.onpageshow()
	// }
	
})