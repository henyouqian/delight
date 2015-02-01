$().ready(function() {
	addHeader()
	addFooter()
	setTitle("频道推荐")

	var url = "channel/list"
	var data = {
		"UserId": 0,
	}

	post(url, data, function(resp){
		console.log(resp)
		var channels = resp.Channels
		var thumbMap = resp.ThumbMap
		var tagsContainer = $("#tagsContainer")
		for (var i in channels) {
			var channel = channels[i]
			console.log(channel)
			var name = channel[0]
			var thumb = channel[1]
			if (name in thumbMap) {
				thumb = thumbMap[name]
			}

			var elemThumb = $("#template .chanThumb").clone()
			$("img", elemThumb).attr("src", RES_HOST+thumb)
			$("a", elemThumb).text(name)
			tagsContainer.append(elemThumb)

			elemThumb[0].name = name
			elemThumb.click(function(){
				window.location.href = "channel.html?name="+$(this)[0].name
			})
		}
	})
	
})