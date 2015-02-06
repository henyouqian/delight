$().ready(function() {
	addHeader()
	addFooter()
	
	//move ads
	var iframe = $("iframe")
	if (iframe) {
		var div = iframe.parent().parent()
		div.detach()
		$("#loadMore").before(div)
	}
	
	var channelName = getUrlParam("name")
	if (!channelName) {
		alert("缺少name参数！")
		return
	}

	setTitle("#"+channelName)

	var unlikedText = "喜欢"
	var privateUnlikedText = "私藏"
	var likedText = "已喜欢"
	var privateLikedText = "已私藏"
	var unlikedColor = "#5bc0de"
	var likedColor = "#f0ad4e"

	var lastKey = ""
	var lastScore = ""
	var ownerMap = {}
	var matches = {}
	var packs = {}
	var enterMatchId = 0
	var limit = 10

	var loadMoreBtn = $("#loadMore")

	var likePlayInfo = null
	var _likeButton = null
	var likeMatchId = 0

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

			if (resp.Matches.length < limit) {
				buttonEnable(loadMoreBtn, false)
				loadMoreBtn.text("后面没有了")
			}
			resp.Matches.length < limit

			var contentElem = $("#content")
			for (var i in resp.Matches) {
				var match = resp.Matches[i]
				matches[match.Id] = match
				var cardElem = $("#template>.card").clone()
				$.extend(ownerMap, resp.OwnerMap)

				contentElem.append(cardElem)
				var userNameElem = $(".userName", cardElem)
				userNameElem.text(match.OwnerName)
				userNameElem.attr("href", "user.html?u="+match.OwnerId)

				var avatar = $(".avatar", cardElem)
				avatar[0].href = "user.html?u="+match.OwnerId
				avatar.click(function(){
					window.location.href = $(this)[0].href
				})

				if (match.OwnerId in ownerMap) {
					var owner = ownerMap[""+match.OwnerId]

					var url = getPlayerAvatarUrl(owner)
					$(".avatar", cardElem).attr("src", url)
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
					alert("暂未实现:matchId="+$(this)[0].matchId)
					// window.location.href = GAME_DIR+'?matchId='+$(this)[0].matchId
				})

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
			}
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