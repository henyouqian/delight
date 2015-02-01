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

	var lastKey = ""
	var lastScore = ""
	var ownerMap = {}
	var matches = {}
	var packs = {}
	var enterMatchId = 0

	function moreMatch() {
		var url = "channel/listMatch"
		var data = {
			"ChannelName": channelName,
			"Key": lastKey,
			"Score": lastScore,
		}

		post(url, data, function(resp){
			console.log(resp)
			lastKey = resp.LastKey
			lastScore = resp.LaseScore

			var playedMatchIdMap = getPlayedMap()
			$.extend(playedMatchIdMap, resp.PlayedMatchIds)
			savePlayedMap()

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
					window.location.href = GAME_DIR+'?key='+$(this)[0].matchId
				})
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
			console.log(item)
			items.push(item)
		}


		//photoswipe
		var pswpElement = document.querySelectorAll('.pswp')[0];

		// define options (if needed)
		var options = {
			index: thumbIndex
		};
		console.log(items)
		console.log(options)

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
		window.location.href = GAME_DIR+'?key='+enterMatchId
	})

	window.onpageshow = function() {
		var lockerElems = $(".locker")
		var playedMatchIdMap = getPlayedMap()
		
		lockerElems.each(function(){
			var elem = $(this)
			var matchId = parseInt(elem.attr("matchId"))
			if (!(matchId in playedMatchIdMap)) {
				elem.show()
			} else {
				elem.hide()
			}
		})
	};
})