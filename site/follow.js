(function(){
    addHeader()
    addFooter()
    
    var userId = parseInt(getUrlParam("userId"))
    var userName = getUrlParam("userName")
    var type = parseInt(getUrlParam("type"))
    var lastKey = 0
    var lastScore = 0
    var limit = 30

    var userRow = $(".userRow")

    if (isdef(userName) && userName.length > 0) {
        if (type == 0) {
            $("#brand").text(userName+"的关注")
        } else {
            $("#brand").text(userName+"的粉丝")
        }
    }

    //
    function loadMore() {
        $("#loadMore").prop('disabled', true)
        var url = HOST + "player/web/followList"
        var data = {
            "Type": type,
            "UserId": userId,
            "LastKey": lastKey,
            "LastScore": lastScore,
            "Limit" :limit,
        }
        $.post(url, JSON.stringify(data), function(resp){
            // console.log(resp)
            var players = resp.PlayerInfoLites
            lastKey = resp.LastKey
            lastScore = resp.LastScore

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

            if (players.length < limit) {
                $("#loadMore").text("后面没有了")
                $("#loadMore").prop('class', "btn btn-default btn-block btn-lg")
            } else {
                $("#loadMore").prop('disabled', false)
            }
        }, "json")
    }

    $("#loadMore").click(loadMore)
    loadMore()



    //loadmore
})()