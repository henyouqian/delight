(function(){
    var lastMatchId
    var lastScore

    var api = "match/listUserWeb"

    var url = HOST + api
    var limit = 6
    var userId = parseInt(getUrlParam("u"))
    var data = {
        "UserId": userId,
        "StartId": 0,
        "LastScore": 0,
        "Limit": limit
    }

    var _matches = {};

    var onMatchList = function(resp){
        var matches = resp.Matches
        for (var i in matches) {
            var match = matches[i]
            var thumbUrl = RES_HOST + match.Thumb
            // $("#thumbRoot").append( '\
            //     <div class="col-xs-4 col-sm-3 col-md-2">\
            //         <a href="'+HTML5_HOST+'index.html?key=' + match.Id + '" class="thumbnail thumb">\
            //             <img src="' + thumbUrl +'">\
            //         </a>\
            //     </div>\
            //     ' );
 
            $("#thumbRoot").append( '\
                <div class="width3">\
                    <a href="match.html?id=' + match.Id + '" class="thumbnail thumb">\
                        <img src="' + thumbUrl +'">\
                    </a>\
                </div>\
                ' );

            lastScore = resp.LastScore
            lastMatchId = match.Id
            _matches[match.Id] = match
        }
        if (matches.length < limit) {
            $("#loadMore").text("后面没有了")
            $("#loadMore").prop('class', "btn btn-default btn-block")
        } else {
            $("#loadMore").prop('disabled', false)
        }
        
        localStorage.matches = JSON.stringify(_matches)
    }

    //listUserWeb
    $("#loadMore").prop('disabled', true)
    $.post(url, JSON.stringify(data), onMatchList, "json")

    //get player info
    url = HOST + "player/getInfoWeb"
    data = {
        "UserId": userId,
    }
    $.post(url, JSON.stringify(data), function(resp) {
        var nickName = resp["NickName"]
        var customKey = resp["CustomAvatarKey"]
        var gravatarKey = resp["GravatarKey"]
        var fanNum = resp["FanNum"]
        var followNum = resp["FollowNum"]
        $("#userName").text(nickName)
        if (customKey.length > 0) {
            var url = RES_HOST + customKey
            $("#avatar").prop("src", url)
        } else if (gravatarKey.length > 0) {
            alert(gravatarKey)
        }
        $("#follow").text("关注："+followNum)
        $("#fan").text("粉丝："+fanNum)
    }, "json")
    
    $("#loadMore").click(function() {
        var url = HOST + api
        var data = {
            "UserId": parseInt(getUrlParam("u")),
            "StartId": lastMatchId,
            "LastScore": lastScore,
            "Limit": limit
        }

        $("#loadMore").prop('disabled', true)

        $.post(url, JSON.stringify(data), onMatchList, "json")
    });
    
})();