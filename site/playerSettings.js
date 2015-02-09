$().ready(function() {
	addFooter()

	var _avatarChanged = false
	var _avatarKey = ""

	//get uptoken
	var url = "player/getUptoken"
	post(url, null, function(resp){
		console.log(resp)
		
		uptoken = resp.Token

		var uploader = Qiniu.uploader({
		    runtimes: 'html5,html4',    //上传模式,依次退化
		    browse_button: "albumButton",       //上传选择的点选按钮，**必需**
		    // uptoken_url: '/token',
		        //Ajax请求upToken的Url，**强烈建议设置**（服务端提供）
		    uptoken : uptoken,
		        //若未指定uptoken_url,则必须指定 uptoken ,uptoken由其他程序生成
		    unique_names: true,
		        // 默认 false，key为文件名。若开启该选项，SDK会为每个文件自动生成key（文件名）
		    // save_key: true,
		        // 默认 false。若在服务端生成uptoken的上传策略中指定了 `sava_key`，则开启，SDK在前端将不对key进行任何处理
		    domain: 'http://7mnmkp.com1.z0.glb.clouddn.com/',
		        //bucket 域名，下载资源时用到，**必需**
		    container: 'pickButtonContainer',           //上传区域DOM ID，默认是browser_button的父元素，
		    multi_selection: false,
		    max_file_size: '5mb',           //最大文件体积限制
		    flash_swf_url: 'js/Moxie.swf',  //引入flash,相对路径
		    max_retries: 3,                   //上传失败最大重试次数
		    dragdrop: false,                   //开启可拖曳上传
		    // drop_element: 'container',        //拖曳上传区域元素的ID，拖曳文件或文件夹后可触发上传
		    chunk_size: '4mb',                //分块上传时，每片的体积
		    auto_start: true,                 //选择文件后自动上传，若关闭需要自己绑定事件触发上传
		    resize:{width : 200, height : 200, quality : 100, crop: true},
		    init: {
		        'FilesAdded': function(up, files) {
		            plupload.each(files, function(file) {
		                console.log(file)
		            });
		            $("#loading-text").text("头像处理中")
		            $(".hudBgFrame").fadeIn()
		        },
		        'BeforeUpload': function(up, file) {
		               // 每个文件上传前,处理相关的事情
		               console.log(file)
		        },
		        'UploadProgress': function(up, file) {
		               // 每个文件上传时,处理相关的事情
		               console.log("UploadProgress:", file)
		        },
		        'FileUploaded': function(up, file, info) {
		        	var infoObj = JSON.parse(info)
		   //      	var imgLink = Qiniu.imageView2({
					//    mode: 1,  // 缩略模式，共6种[0-5]
					//    w: 200,   // 具体含义由缩略模式决定
					//    h: 200,   // 具体含义由缩略模式决定
					//    q: 80,   // 新图的图像质量，取值范围：1-100
					//    format: 'jpg'  // 新图的输出格式，取值范围：jpg，gif，png，webp等
					// }, infoObj.key);

		        	_avatarKey = infoObj.key
					$("#avatar").attr("src", RES_HOST+infoObj.key)

					console.log(_avatarKey)


		               // 每个文件上传成功后,处理相关的事情
		               // 其中 info 是文件上传成功后，服务端返回的json，形式如
		               // {
		               //    "hash": "Fh8xVqod2MQ1mocfI4S4KpRL6D98",
		               //    "key": "gogopher.jpg"
		               //  }
		               // 参考http://developer.qiniu.com/docs/v6/api/overview/up/response/simple-response.html
		               // var domain = up.getOption('domain');
		               // var res = parseJSON(info);
		               // var sourceLink = domain + res.key; 获取上传成功后的文件的Url
		        },
		        'Error': function(up, err, errTip) {
		               //上传出错时,处理相关的事情
		               $(".hudBgFrame").fadeOut()
		        },
		        'UploadComplete': function() {
		               //队列文件处理完毕后,处理相关的事情
		               $(".hudBgFrame").fadeOut()
		        }
		    }
		});

	}, function(resp){
		alert("获取uptoken出错")
	})

	var _player = lscache.get("player")
	if (_player == null) {
		alert("没有用户信息")
		return
	}
	_avatarKey = _player.CustomAvatarKey

	$("#nicknameInput").val(_player.NickName)

	var url = getPlayerAvatarUrl(_player, 72)
	$("#avatar").attr("src", url)
	
	$("#cancelButton").click(function(){
		window.history.go(-1)
	})
	$("#saveButton").click(function(){
		var nickname = $("#nicknameInput").val()

		if (nickname.length == 0) {
			alert("请填写昵称。")
			return
		}
		if (!_avatarKey && nickname == _player.NickName) {
			alert("没做任何改动。")
			return
		}
		var gravatarKey = _player.GravatarKey
		if (_avatarKey) {
			gravatarKey = ""
		}
		var url = "player/setInfo"
		var data = {
			NickName        :nickname,
			GravatarKey     :gravatarKey,
			CustomAvatarKey :_avatarKey,
			TeamName        :_player.TeamName,
			Email           :_player.Email,
			Gender          :_player.Gender,
		}
		$("#loading-text").text("保存中")
		$(".hudBgFrame").fadeIn()
		post(url, data, function(resp){
			$(".hudBgFrame").fadeOut()
			console.log(resp)
			_player = resp
			lscache.set("player", _player)
			setTimeout(function(){window.history.go(-1)}, 1400)
		}, function(resp){
			$(".hudBgFrame").fadeOut()
			if (resp.Error == "err_name_taken") {
				alert("昵称已被使用，请换一个")
			} else {
				alert("保存失败")
			}
		})
	})

	// $("#albumButton").click(function(){
	// 	$("#imgInput").trigger("click");
	// })

	// $("#imgInput").change(function(e) {
	// 	_avatarChanged = true
	// 	var file = e.target.files[0];

	// 	var reader = new FileReader();
	// 	reader.onloadend = function(e) {
	// 		var dataURL = e.target.result;
	// 		// console.log(dataURL)
	// 		var img = new Image();
	// 		img.onload = function(e) {
	// 			$(img).exifLoadFromDataURL(function() {
	// 				console.log("size:", img.width, ",", img.height)

	// 				var width = img.width
	// 				var height = img.height
	// 				var needResize = false
	// 				if (width != 200 && height != 200) {
	// 					needResize = true
	// 					width = 200
	// 					height = 200
	// 				}

	// 				if (needResize) {
	// 					$.canvasResize(file, img, {
	// 						width: width,
	// 						height: height,
	// 						crop: true,
	// 						quality: 80,
	// 						//rotate: 90,
	// 						callback: function(data, width, height) {
	// 							console.log("resized")
	// 							doImg(data, width, height)
	// 						}
	// 					})
	// 				} else {
	// 					doImg(dataURL, width, height)
	// 				}

	// 				function doImg(data, width, height) {
	// 					$("#avatar").attr("src", data)
	// 				}
	// 			})
	// 		}
	// 		img.src = dataURL;
	// 	}
	// 	reader.readAsDataURL(file);
	// })

})