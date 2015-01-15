(function(){
    function getUrlParam(name) {
        var reg = new RegExp("(^|\\?|&)"+ name +"=([^&]*)(\\s|&|$)", "i");  
        if (reg.test(location.href)) return unescape(RegExp.$2.replace(/\+/g, " ")); return "";
    };

    var matchId = parseInt(getUrlParam("id"))
    var packId = 0

    var url = HOST + "match/web/get"
    var data = {
        "MatchId": matchId
    }

    $("#playGame").prop('disabled', true)

    $.post(url, JSON.stringify(data), function(resp){
        var match = resp["Match"]
        var pack = resp["Pack"]
        var player = resp["Player"]
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
                    <div class="thumbnail thumb">\
                        <img src="' + thumbUrl +'">\
                    </div>\
                ' );
        }
        $("#playGame").prop('disabled', false)

        $(".thumb").click(function(a) {
            console.log(a)

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
                item.w = 400
                item.h = 500
                console.log(item)
                items.push(item)
            }

            //photoswipe
            var pswpElement = document.querySelectorAll('.pswp')[0];

            // define options (if needed)
            var options = {
                // optionName: 'option value'
                // for example:
                index: 0 // start at first slide
            };

            // Initializes and opens PhotoSwipe
            var gallery = new PhotoSwipe( pswpElement, PhotoSwipeUI_Default, items, options);
            console.log(pswpElement)
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
        alert("aaa")
    })

    $("#playGame").click(function() {
        var url = HTML5_HOST+'index.html?key=' + matchId
        alert(url)
        window.location.href = url
    })

})()