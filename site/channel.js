$().ready(function() {
	addHeader()
	addFooter()
	moveTaobaoAds()
	
	var channelName = getUrlParam("name")
	if (!channelName) {
		alert("缺少name参数！")
		return
	}

	setTitle("#"+channelName)

	var privateUnlikedText = "私藏"
	var privateLikedText = "已私藏"
	var unlikedColor = "#5bc0de"
	var likedColor = "#f0ad4e"

	var lastKey = ""
	var lastScore = ""
	var ownerMap = {}
	var matches = {}
	var matchExMap = {}
	var packs = {}
	var enterMatchId = 0
	var limit = 10

	var loadMoreBtn = $("#loadMore")

	var likePlayInfo = null
	var _likeButton = null
	var likeMatchId = 0

	$("#publisherList").click(function() {
		window.location.href = "channelPublisher.html?name=" + channelName
	})

	loadMoreBtn.click(function(){
		moreMatch()
	})

	function moreMatch() {
		var url = "channel/listMatch"
		var data = {
			"ChannelName": channelName,
			"Key": lastKey,
			"Score": lastScore,
			"Limit": limit,
		}

		post(url, data, function(resp){
			console.log(resp)
			lastKey = resp.LastKey
			lastScore = resp.LaseScore
			var playedMatchMap = resp.PlayedMatchMap
			savePlayedMap(playedMatchMap)
			matchExMap = resp.MatchExMap

			if (resp.Matches.length < limit) {
				buttonEnable(loadMoreBtn, false)
				loadMoreBtn.text("后面没有了")
			}
			resp.Matches.length < limit

			var contentElem = $("#content")
			$(resp.Matches).each(function(i, match) {
				var match = resp.Matches[i]
				matches[match.Id] = match
				var cardElem = $("#template>.card").clone()
				$.extend(ownerMap, resp.OwnerMap)

				contentElem.append(cardElem)
				var userNameElem = $(".userName", cardElem)
				userNameElem.text(match.OwnerName)
				userNameElem.attr("href", "user.html?u="+match.OwnerId)

				var avatar = cardElem.find(".avatarSm")
				avatar[0].href = "user.html?u="+match.OwnerId
				avatar.click(function(){
					window.location.href = $(this)[0].href
				})

				if (match.OwnerId in ownerMap) {
					var owner = ownerMap[""+match.OwnerId]
					var url = getPlayerAvatarUrl(owner)
					avatar.attr("src", url)
				}

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
						var match = matches[matchId]
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
					modal.modal("show")
					likeMatchId = matchId
				})
				
				var privateButton = $(".privateButton", cardElem)
				privateButton.click(function(){
					var matchId = match.Id
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

				var playInfo = playedMatchMap[match.Id]
				if (isdef(playInfo)) {
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
			})
		})
	}
	moreMatch()

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

	$(".playConfirmButton").click(function(){
		$('#thumbModal').modal('hide')
		window.location.href = GAME_DIR+'?matchId='+enterMatchId
	})

	$("#confirmLikeButton").click(function(){
		$("#likeModal").modal("hide")
		var url = "match/like"
		var data = {
			"MatchId": likeMatchId
		}
		post(url, data, function(resp){
			$("#repostSuccessModal").modal("show")
		}, function(resp) {
			alert("like error")
		})
	})

	$("#confirmPrivateLikeButton").click(function(){
		$("#privateLikeModal").modal("hide")
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

	window.onpageshow = function() {
		var lockerElems = $(".locker")
		
		lockerElems.each(function(){
			var elem = $(this)
			var matchId = parseInt(elem.attr("matchId"))
			if (isLocked(matchId)) {
				elem.show()
			} else {
				elem.hide()
			}
		})
	};
})