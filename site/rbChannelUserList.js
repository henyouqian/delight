(function(){
    var channelName = getUrlParam("name")
    var limit = 100

    var userRow = $(".userRow")

    $("#title").text("#"+channelName)

    //
    function loadList() {
        var url = "channel/listUser"
        var data = {
            "ChannelName": channelName,
        }
        post(url, data, function(resp){
            // console.log(resp)
            var players = resp.Players

            for (var i in players) {
                var player = players[i]
                var row = userRow.clone()
                row.show()

                //avatar
                var customKey = player.CustomAvatarKey
                var gravatarKey = player.GravatarKey
                var avatarObj = $(".avatar40", row)
                if (customKey.length > 0) {
                    var url = RES_HOST + customKey
                    avatarObj.attr("src", url)
                } else if (gravatarKey.length > 0) {
                    avatarObj.attr("src", makeGravatarUrl(gravatarKey, 40))
                }

                //user label
                var labelObj = $(".userNameLabel", row)
                labelObj.text(player.NickName)
                row.attr("userId", player.UserId)

                //onclick
                row.click(function(){
                    window.location.href = "user.html?u="+$(this).attr("userId")
                })

                //
                $("#userRows").append(row)
            }
        })
    }
    loadList()



    //loadmore
})()