(function(){
	addHeader()
	addFooter()

	var lastKey = ""
	var lastScore = 0

	var loadMoreBtn = $("#loadMore")
	loadMoreBtn.hide()

	var $userRow = $(".userRow")

	function searchMore() {
		loadMoreBtn.text("搜索中")
		buttonEnable(loadMoreBtn, false)

		var userName = $("#searchInput").val()
		if (userName == "") {
			return
		}

		var url = HOST + "player/searchUser"
		var data = {
			"UserName": userName,
			"LastKey": lastKey,
			"LastScore": lastScore,
		}
		$.post(url, JSON.stringify(data), function(resp){
			console.log(resp)
			loadMoreBtn.show()
			var players = resp.Players
			if (players.length < resp.Limit) {
				if ($(".resultRows").children().length == 0 && players.length==0) {
					loadMoreBtn.text("什么都没找到")
				} else {
					loadMoreBtn.text("后面没有了")
				}
			} else {
				buttonEnable(loadMoreBtn, true)
				loadMoreBtn.text("更多")
			}
			for (var i in players) {
				var player = players[i]
				var row = $userRow.clone()
				row.css("display", "block")

				//avatar
				var customKey = player.CustomAvatarKey
				var gravatarKey = player.GravatarKey
				var avatarObj = $(".avatar", row)
				if (customKey.length > 0) {
					var url = RES_HOST + customKey
					avatarObj.attr("src", url)
				} else if (gravatarKey.length > 0) {
					avatarObj.attr("src", makeGravatarUrl(gravatarKey, 40))
				}

				//user label
				var labelObj = $(".userNameLabel", row)
				labelObj.text(player.NickName)

				//onclick
				row.attr("userId", player.UserId)
				row.click(function(){
					var userId = $(this).attr("userId")
					window.location.href = "user.html?u="+userId
				})

				//
				$("#resultRows").append(row)
			}
		}, "json")
	}

	$("#searchUser").click(function(){
		$("#resultRows").children().remove()
		searchMore()
	}) //$("#searchUser").click()

	

})()