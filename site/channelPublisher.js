$().ready(function() {
	addHeader()
	addFooter()

	var loadingLabel = $("#loadingLabel")

	var channelName = getUrlParam("name")
	if (channelName == "") {
		loadingLabel.text("param error")
		return
	}
	
	var url = "channel/listUser"
	var data = {
		ChannelName: channelName,
	}

	post(url, data, function(resp){
		loadingLabel.hide()

		var userRows = $("#userRows")
		$(resp.Players).each(function(i, player){
			console.log(player)
			var userRow = $("#template>.userRow").clone()
			userRows.append(userRow)

			var avatar = userRow.find(".avatar40")
			var url = getPlayerAvatarUrl(player, 40)
			avatar.attr("src", url)

			var userName = userRow.find(".userNameLabel")
			userName.text(player.NickName)

			userRow.find("a").attr("href", "user.html?u="+player.UserId)
		})
	}, function(resp){
		loadingLabel.text(resp.Error)
	})
	
})