(function(){
    var userId = parseInt(getUrlParam("userId"))
    var userName = localStorage.userName
    var type = parseInt(getUrlParam("type"))
    var lastKey = 0
    var lastScore = 0
    var limit = 30

    if (isdef(userName) && userName.length > 0) {
        if (type == 0) {
            $("#brand").text(userName+"的关注")
        } else {
            $("#brand").text(userName+"的粉丝")
        }
    }

    var url = HOST + "player/web/followList"
    var data = {
        "Type": type,
        "UserId": userId,
        "LastKey": lastKey,
        "LastScore": lastScore,
        "Limit" :limit,
    }
    $.post(url, JSON.stringify(data), function(resp){
        console.log(resp)
    })
})()