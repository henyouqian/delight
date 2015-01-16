(function(){

    $("#storeLink").attr("href", APPSTORE_URL)

    var matchId = parseInt(getUrlParam("key"))
    var packId = 0
    var playerId = 0

    var url = HOST + "match/web/get"
    var data = {
        "MatchId": matchId
    }

    $("#playGame").prop('disabled', true)

    $.post(url, JSON.stringify(data), function(resp){
        var match = resp["Match"]
        var pack = resp["Pack"]
        var player = resp["Player"]

        if(match.Title.length > 0) {
            $(".navbar-brand").text(match.Title)
        }

        playerId = player.UserId
        $("#userName").text(player.NickName)
        var customKey = player.CustomAvatarKey
        var gravatarKey = player.GravatarKey
        if (customKey.length > 0) {
            var url = RES_HOST + customKey
            $("#avatar").prop("src", url)
        } else if (gravatarKey.length > 0) {
            var url = "http://en.gravatar.com/avatar/"+gravatarKey+"?d=identicon&s=64"
            $("#avatar").prop("src", url)
        }

        var thumbs = pack.Thumbs
        var thumbUrls = []
        if (thumbs == null) {
            thumbs = []
            for (var i in pack.Images) {
                var image = pack.Images[i]
                if (image.Url.length > 0) {
                    thumbUrls.push(image.Url)
                } else {
                    thumbUrls.push(RES_HOST + image.Key)
                }
            }
        } else {
            for (var i in thumbs) {
                var thumbUrl = RES_HOST + thumbs[i]
                thumbUrls.push(thumbUrl)
            }
        }
        for (var i in thumbUrls) {
            var thumbUrl = thumbUrls[i]
            $("#thumbRoot").append( '\
                    <div class="thumbnail thumb" index='+i+'>\
                        <img src="' + thumbUrl +'">\
                    </div>\
                ' );
        }
        $("#playGame").prop('disabled', false)

        $(".thumb").click(function(a) {
            if (!isdef(localStorage["matchPlayed/"+matchId])) {
                $('#thumbModal').modal('show')
                return
            }
            
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
                index: $(this).attr("index")
            };

            // Initializes and opens PhotoSwipe
            var gallery = new PhotoSwipe( pswpElement, PhotoSwipeUI_Default, items, options);
            gallery.init();
        })

        // packId = pack.Id
        // //
        // url = HOST + "social/newPack"
        // var data = {
        //     "PackId":    packId,
        //     "SliderNum": match.SliderNum
        // }
        // var gameKey = ""
        // $.post(url, JSON.stringify(data), function(resp){
        //     gameKey = resp.Key
        //     $("#playGame").prop('disabled', false)
        // })

    }, "json")

    $("#userRow").click(function() {
        var url = "user.html?u="+playerId
        window.location.href = url
    })

    $(".playGame").click(function() {
        console.log("xxx")
        var url = HTML5_HOST+'index.html?key='+matchId
        window.location.href = url
    })


})()