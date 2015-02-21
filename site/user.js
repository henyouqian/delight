$().ready(function() {
	addHeader()
	addFooter()
	moveTaobaoAds()
	setTitle("我的")

	var unlikedText = "喜欢"
	var likedText = "已喜欢"
	var privateUnlikedText = "私藏"
	var privateLikedText = "已私藏"
	var unlikedColor = "#5bc0de"
	var likedColor = "#f0ad4e"

	var matchNum = 0
	var limit = 9
	var pageNum = 1
	var currPage = -100
	var followed = false
	var firstLoad = true

	var userId = parseInt(getUrlParam("u"))
	if (userId == 0) {
		userId = parseInt(lscache.get("userId"))
	}
	var userName = ""
	var isMe = false
	if (userId == parseInt(lscache.get("userId"))) {
		isMe = true
	}

	var contentElem = $("#content")
	var enterMatchId = 0
	var _matches = {}
	var packs = {}
	var ownerMap = {}
	var currType = -1
	var _typePageMap = {}
	var matchExMap = {}

	var likePlayInfo = null
	var _likeButton = null
	var likeMatchId = 0

	var publishButton = $("#publishButton")
	if (isMe) {
		publishButton.show()
	}
	publishButton.click(function() {
		window.location.href = "upload.html"
	})

	$("#tab>li").click(function() {
		if ($(this).hasClass("active")) {
			return
		}
		$("#tab>li").removeClass("active")
		$(this).addClass("active")

		_typePageMap[currType] = currPage
		var typeIndex = parseInt($(this).attr("type"))
		var pageIndex = _typePageMap[typeIndex]
		if (!isdef(pageIndex)) {
			pageIndex = -1
		}

		loadPage(typeIndex, pageIndex)
	})

	if (isMe) {
		$("#privateTab").show()
	} else {
		$("#privateTab").hide()
	}
	
	function loadPage(typeIndex, pageIndex) {
		if (pageIndex == currPage && typeIndex == currType) {
			return
		}

		currType = typeIndex

		var lis = $("#tab>li")
		lis.removeClass("active")
		$("#tab>li[type="+currType+"]").addClass("active")

		contentElem.empty()

		var url = "match/web/listUserQ"
		var data = {
			"Type": currType,
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
			$.extend(ownerMap, resp.OwnerMap)
			matchExMap = resp.MatchExMap

			if (pageIndex < 0) {
				var nMatch = matchNum % limit
				matches = matches.slice(-nMatch)
			}

			matches.reverse()

			for (var i in matches) {
				var match = matches[i]
				_matches[match.Id] = match

				var cardElem = $("#template>.card").clone()
				contentElem.append(cardElem)

				//userDiv
				var userDiv = cardElem.find(".userDiv")
				if (match.OwnerId == userId) {
					userDiv.hide()
				} else {
					userDiv.show()

					var userNameElem = userDiv.find(".userName")
					userNameElem.text(match.OwnerName)
					userNameElem.attr("href", "user.html?u="+match.OwnerId)

					var avatar = userDiv.find(".avatarSm")
					avatar[0].href = "user.html?u="+match.OwnerId
					avatar.click(function(){
						window.location.href = $(this)[0].href
					})

					if (match.OwnerId in ownerMap) {
						var owner = ownerMap[""+match.OwnerId]
						var url = getPlayerAvatarUrl(owner)
						avatar.attr("src", url)
					}
				}

				//playTimesLable
				var playTimesLabel = cardElem.find(".playTimesLabel")
				var matchIdStr = match.Id.toString()
				var playTimes = 0
				if (matchIdStr in matchExMap) {
					playTimes = matchExMap[matchIdStr].PlayTimes
				} else {
					playTimes = 0
				}
				if (playTimes == 0) {
					playTimesLabel.text("暂无记录")
				} else {
					playTimesLabel.text("已拼"+playTimes+"次")
				}

				//thumbs
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

				var likeButton = $(".likeButton", cardElem)
				likeButton[0].matchId = match.Id
				likeButton.click(function(){
					var matchId = $(this)[0].matchId
					var playInfo = playedMatchMap[matchId]

					var modal = $("#likeModal")
					var title = modal.find("#likeModalLabel")
					if (playInfo.Liked) {
						title.text("取消喜欢这组拼图吗？")
					} else {
						title.text("喜欢这组拼图吗？")
					}

					likePlayInfo = playInfo
					_likeButton = $(this)
					likeMatchId = matchId

					modal.modal("show")
				})
				
				var privateButton = $(".privateButton", cardElem)
				privateButton[0].matchId = match.Id
				privateButton.click(function(){
					var matchId = $(this)[0].matchId
					var playInfo = playedMatchMap[matchId]

					var modal = $("#privateLikeModal")
					var title = modal.find("#privateLikeModalLabel")
					if (playInfo.PrivateLiked) {
						title.text("取消私藏这组拼图吗？")
					} else {
						title.text("私藏这组拼图吗？")
					}

					likePlayInfo = playInfo
					_likeButton = $(this)
					likeMatchId = matchId

					modal.modal("show")
				})

				var me = lscache.get("player")
				if (match.OwnerId == me.UserId) {
					likeButton.hide()
					privateButton.hide()
				}

				var playInfo = playedMatchMap[match.Id]
				if (isdef(playInfo)) {
					if (playInfo.Liked) {
						likeButton.text(likedText)
						likeButton.css("color", likedColor)
					} else {
						likeButton.text(unlikedText)
						likeButton.css("color", unlikedColor)
					}
					if (playInfo.PrivateLiked) {
						privateButton.text(privateLikedText)
						privateButton.css("color", likedColor)
					} else {
						privateButton.text(privateUnlikedText)
						privateButton.css("color", unlikedColor)
					}
				} else {
					playedMatchMap[match.Id] = {
						Played:false,
						Liked:false,
						PrivateLiked:false,
					}
				}


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
			if (currPage < 0) {
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

			var newURL = window.location.href.split('#')[0]+"#&type="+currType+'&page='+currPage;
			window.location.replace(newURL)

			//check page
			// if (currPage >= pageNum) {
			// 	// var newURL = window.location.href.split('#')[0] + '#&page=' + (pageNum-1);
			// 	loadPage(pageNum-1, false)
			// 	return
			// } else {
			// 	var newURL = window.location.href.split('#')[0] + '#&page=' +  currPage;
			// 	if (saveHistory && !firstLoad) {
			// 		window.location.assign(newURL)
			// 	} else {
			// 		window.location.replace(newURL)
			// 	}
			// 	if (firstLoad) {
			// 		firstLoad = false
			// 	}

			// 	$("title").text(userName+"(页"+(getPageIndexFromUrl()+1)+")")
			// }
			
		})
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
		var pageIndex = getPageIndexFromUrl()
		var typeIndex = getTypeFromUrl()
		if (lscache.get("matchPublished")) {
			pageIndex = -1
			typeIndex = 0
			lscache.remove("matchPublished")
		}
		loadPage(typeIndex ,pageIndex)

		var nickName = resp.NickName
		var customKey = resp.CustomAvatarKey
		var gravatarKey = resp.GravatarKey
		matchNum = resp.MatchNum

		fanNum = resp["FanNum"]
		followNum = resp["FollowNum"]
		userName = nickName
		var isSelf = lscache.get("userId") == userId.toString()
		if (isSelf) {
			$("#userName").text(nickName+"(我)")
			$("title").text("我的主页")
		} else {
			$("#userName").text(nickName)
			$("title").text(userName+"的主页")
		}


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

		if (!isSelf) {
			followButton.show()
		}

		//
		// var pageIndex = getPageIndexFromUrl()
		// loadPage(pageIndex, true)
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
		loadPage(currType, currPage-1)
		$(this).removeClass("active")
	})
	$(".next").click(function(){
		if (currPage == pageNum - 1) {
			return
		}
		loadPage(currType, currPage+1)
		$(this).removeClass("active")
	})

	$("#followButton").click(function(){
		if (followed) {
			$("#followModal").modal("show")
		} else {
			doFollow()
		}
	})

	$("#confirmFollowButton").click(function() {
		$("#followModal").modal("hide")
		doFollow()
	})

	function doFollow() {
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
	}

	$(".pageButton").click(function(){
		var input = $("#pageInput")
		input.val("")
		input.attr("placeholder", "请输入跳转页码（"+1+"-"+pageNum+"）")
		input.trigger("focusin");
		$("#pageModal").modal("show")
	})

	$('#pageModal').on('shown.bs.modal', function () {
		$('#pageInput').focus()
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
			loadPage(currType, pageIdx)
		} else {
			input.val("")
			input.attr("placeholder", "输入错误，请输入跳转页码（"+1+"-"+pageNum+"）")
		}
		
	})

	function getPageIndexFromUrl() {
		var pageIndex = getUrlParam("page")
		if (pageIndex == "") {
			pageIndex = -1
		} else {
			pageIndex = parseInt(pageIndex)
		}
		return pageIndex
	}
	function getTypeFromUrl() {
		var type = getUrlParam("type")
		if (type == "") {
			type = 0
		} else {
			type = parseInt(type)
		}
		return type
	}

	window.onhashchange = function(){
		var pageIndex = getPageIndexFromUrl()
		var typeIndex = getTypeFromUrl()
		loadPage(typeIndex, pageIndex)
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

	$("#confirmLikeButton").click(function(){
		$("#likeModal").modal("hide")
		// var matchId = $(this)[0].matchId
		var playInfo = likePlayInfo

		var url = "match/like"
		if (playInfo.Liked) {
			url = "match/unlike"
		}
		var data = {
			"MatchId": likeMatchId
		}
		var button = _likeButton
		post(url, data, function(resp){
			playInfo.Liked = !playInfo.Liked

			if (playInfo.Liked) {
				button.text(likedText)
				button.css("color", likedColor)
			} else {
				button.text(unlikedText)
				button.css("color", unlikedColor)
			}

		}, function(resp) {
			alert("like error")
		})
	})

	$("#confirmPrivateLikeButton").click(function(){
		$("#privateLikeModal").modal("hide")
		// var matchId = $(this)[0].matchId
		var playInfo = likePlayInfo

		var url = "match/privateLike"
		if (playInfo.PrivateLiked) {
			url = "match/privateUnlike"
		}
		var data = {
			"MatchId": likeMatchId
		}
		var button = _likeButton
		post(url, data, function(resp){
			playInfo.PrivateLiked = !playInfo.PrivateLiked

			if (playInfo.PrivateLiked) {
				button.text(privateLikedText)
				button.css("color", likedColor)
			} else {
				button.text(privateUnlikedText)
				button.css("color", unlikedColor)
			}

		}, function(resp) {
			alert("like error")
		})
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

	// iOS check...ugly but necessary
	if( navigator.userAgent.match(/iPhone|iPad|iPod/i) ) {
		$('#pageModal').on('show.bs.modal', function() {
			// Position modal absolute and bump it down to the scrollPosition
			$(this)
				.css({
					position: 'absolute',
					marginTop: $(window).scrollTop() + 'px',
					bottom: 'auto'
				});
			// Position backdrop absolute and make it span the entire page
			//
			// Also dirty, but we need to tap into the backdrop after Boostrap 
			// positions it but before transitions finish.
			//
			setTimeout( function() {
				$('.modal-backdrop').css({
					position: 'absolute', 
					top: 0, 
					left: 0,
					width: '100%',
					height: Math.max(
						document.body.scrollHeight, document.documentElement.scrollHeight,
						document.body.offsetHeight, document.documentElement.offsetHeight,
						document.body.clientHeight, document.documentElement.clientHeight
					) + 'px'
				});
			}, 0);
		});
	}
	
})