$().ready(function() {
	var userId = parseInt(getUrlParam("userId"))
	if (userId == 0) {
		return
	}
	var userName = getUrlParam("userName")
	var gravatar = getUrlParam("gravatar")
	var avatar = getUrlParam("avatar")

	var lastKey = ""
	var lastScore = ""
	var matches = {}
	var packs = {}
	var limit = 10
	var privatePublish = false

	var loadMoreBtn = $("#loadMore")

	loadMoreBtn.click(function() {
		moreMatch()
	})

	
	var avatarUrl = getAvatarUrl(avatar, gravatar, 40)
	console.log(avatarUrl)
	$(".avatar40").attr("src", avatarUrl)
	$(".userNameLabel").text(userName)

	function moreMatch() {
		var url = "tumblr/listPublishQueue"
		var data = {
			"UserId": userId,
			"Key": lastKey,
			"Score": lastScore,
			"Limit": limit,
		}

		rbPost(url, data, function(resp) {
			console.log(resp)
			lastKey = resp.LastKey
			lastScore = resp.LaseScore

			if (resp.Matches.length < limit) {
				buttonEnable(loadMoreBtn, false)
				loadMoreBtn.text("后面没有了")
			}
			resp.Matches.length < limit

			var contentElem = $("#content")
			$(resp.Matches).each(function(i, match){
				matches[match.Id] = match

				var cardElem = $("#template>.card").clone()
				contentElem.append(cardElem)

				var thumbRoot = $(".thumbRoot", cardElem)

				$(match.Thumbs).each(function(iThumb, thumbKey) {
					var thumbKey = match.Thumbs[iThumb]
					var thumbElem = $("#template>.thumb").clone()
					var thumbUrl = RES_HOST + thumbKey
					$("img", thumbElem).attr("src", thumbUrl)
					thumbRoot.append(thumbElem)
					thumbElem.attr("matchId", match.Id)
					thumbElem.attr("index", iThumb)

					thumbElem.click(function(a) {
						var thumbElem = $(this)
						var matchId = thumbElem.attr("matchId")
			
						var index = parseInt(thumbElem.attr("index"))
						var match = matches[matchId]
						var pack = packs[match.PackId]
						if (!pack) {
							var url = "pack/get"
							var data = {
								"Id": match.PackId
							}
							$(".hudBgFrame").fadeIn()
							rbPost(url, data, function(resp) {
								$(".hudBgFrame").fadeOut()
								var pack = resp
								packs[pack.Id] = pack
								showImage(pack, index)
							})
						} else {
							showImage(pack, index)
						}
					})
				})

				
				cardElem.find(".publishButton").click(function() {
					// $("#publishModalLabel").text("确定发布吗？")
					// privatePublish = false
					// $("#publishModal").modal("show")

					var b = confirm("确定发布吗？") 
					if (b) {
						publishFromQueue(false)
					}
				})

				cardElem.find(".privatePublishButton").click(function() {
					// $("#publishModalLabel").text("确定私发吗？")
					// privatePublish = true
					// $("#publishModal").modal("show")

					var b = confirm("确定私发吗？") 
					if (b) {
						publishFromQueue(true)
					}
				})

				//sliderNum input
				var sliderNumInput = cardElem.find(".sliderNumInput")
				sliderNumInput.val(match.SliderNum)

				function publishFromQueue(privatePublish) {
					var url = "tumblr/publishFromQueue"
					var sliderNum = parseInt(sliderNumInput.val())
					if (sliderNum < 3 || sliderNum > 8) {
						alert("wrong sliderNum")
						return
					}
					var data = {
						MatchId: match.Id,
						Private: privatePublish,
						SliderNum: sliderNum,
					}
					rbPost(url, data, function(resp){
						cardElem.remove()
					}, function(resp){
						alert(resp.Error)
					})
				}
			})
		})
	}
	moreMatch()

	$("#publishConfirmButton").click(function() {
		$("#publishModal").modal("hide")
		if (privatePublish) {
			alert("privatePublish")
		} else {
			alert("publish")
		}
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
		var gallery = new PhotoSwipe(pswpElement, PhotoSwipeUI_Default, items, options);
		gallery.init();

		//photo swipe gif fix
		var iOSv;
		if (/iP(hone|od|ad)/.test(navigator.platform)) {
			iOSv = (navigator.appVersion).match(/OS (\d+)_(\d+)_?(\d+)?/);
			iOSv = parseInt(iOSv[1], 10);
		}

		if (iOSv >= 8) {
			gallery.listen('afterChange', function() {
				if (gallery.currItem.src.indexOf('.gif') > 0) {
					var currHolder = gallery.itemHolders[1];
					if (currHolder && currHolder.el) {
						var imgs = currHolder.el.getElementsByClassName('pswp__img');
						if (imgs.length) {
							var img = imgs[imgs.length - 1];
							// toggle opacity on gif IMG
							img.style.opacity = img.style.opacity == 0.99999 ? 1 : 0.99999;
						}

					}
				}
			});
		}
	}

})