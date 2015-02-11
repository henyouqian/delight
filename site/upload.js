$().ready(function() {
	checkAuth()

	addHeader()
	addFooter()

	var _uptoken = ""
	var _privateUptoken = ""
	var _descShow = true
	var _loadedThumbs = []
	var _loadedImages = []

	$("#selectImageButton").click(function(){
		if (isMobile() && _descShow) {
			alert("\n1.请选择3-9张图片。\n2.选完图可能有明显延迟(好几秒)，请耐心等待。\n3.图片太大太多会很慢甚至使浏览器崩溃，建议缩小图片或使用App版本/桌面浏览器上传。")
			_descShow = false
		}

		$("#thumbRoot").empty()

		_loadedThumbs = []

		$("#imgInput").trigger("click");
	})

	$("#imgInput").change(function(e) {
		if (e.target.files.length < 3) {
			alert("\n图片太少，请选择3-9张图片。")
			return
		}

		_loadedImages = new Array()

		$("#loading-text").text("处理中...")
		$(".hudBgFrame").show()

		var filesToDo = e.target.files.length
		var limit = 9
		if (filesToDo > limit) {
			filesToDo = limit
		}
		filesToDo *= 2
		
		var l = e.target.files.length
		$.each(e.target.files, function(i, file) {
			if (i >= limit) {
				return
			}

			var reader = new FileReader();
			reader.onloadend = function(e) {
				var dataURL = e.target.result;
				var img = new Image();
				img.onload = function(e) {
					$(img).exifLoadFromDataURL(function() {

						var width = img.width
						var height = img.height
						var needResize = false
						if (img.width > img.height) {
							if (img.width > 700) {
								width = 600
								height = 0
								needResize = true
							}
						} else {
							if (img.height > 700) {
								height = 600
								width = 0
								needResize = true
							}
						}

						if (needResize) {
							$.canvasResize(file, img, {
								width: width,
								height: height,
								crop: false,
								quality: 80,
								//rotate: 90,
								callback: function(data, width, height) {
									_loadedImages[i] = {data:data, width:width, height:height}
									filesToDo--;
									if (filesToDo == 0) {
										$(".hudBgFrame").fadeOut(1000)
										onAllLoad()
									}
								}
							})
						} else {
							_loadedImages[i] = {data:dataURL, width:width, height:height}
							filesToDo--;
							if (filesToDo == 0) {
								$(".hudBgFrame").fadeOut(1000)
								onAllLoad()
							}
						}

						//gen thumb
						$.canvasResize(file, img, {
							width: 200,
							height: 200,
							crop: true,
							quality: 80,
							//rotate: 90,
							callback: function(data, width, height) {
								_loadedThumbs[i] = {data:data, width:width, height:height}
								filesToDo--;
								if (filesToDo == 0) {
									$(".hudBgFrame").fadeOut(1000)
									onAllLoad()
								}
							}
						})

						function onAllLoad() {
							for (var i in _loadedImages) {
								var loadedImage = _loadedImages[i]
								var thumbDiv = $("#template>.thumbDiv").clone()
								$("img", thumbDiv).attr("src", loadedImage.data)
								$("#thumbRoot").append(thumbDiv)
								thumbDiv.hide().fadeIn(1000)
							}
							$("#uploadButton").show()
						}
						
					})
				}
				img.src = dataURL;
			}
			reader.readAsDataURL(file);
		})
	})

	function putb64(uptoken, data, onFinish){
		var url = "http://up.qiniu.com/putb64/-1"; 
		var xhr = new XMLHttpRequest();
		
		xhr.onreadystatechange=function(){
			// if (xhr.readyState==4){
			// 	document.getElementById("myDiv").innerHTML=xhr.responseText;
			// }
			if (xhr.readyState == 4) {
				onFinish(xhr)
			}
		}
		xhr.open("POST", url, true); 
		xhr.setRequestHeader("Content-Type", "application/octet-stream"); 
		xhr.setRequestHeader("Authorization", "UpToken "+uptoken); 
		xhr.send(data);
	}

	var uploadButton = $("#uploadButton")

	uploadButton.click(function() {
		var sliderNum = parseInt($("#sliderNumInput").val())
		if (sliderNum < 3 || sliderNum > 8) {
			alert("拼图块数必须在3-8之间")
			return
		}

		var coverIndex = parseInt($("#coverIndexInput").val())
		if (coverIndex < 1 || coverIndex > _loadedThumbs.length) {
			alert("封面索引必须在1-"+_loadedImages.length+"之间")
			return
		}

		var r=confirm("确定发布吗？")
		if (r==true) {
			if (_loadedThumbs.length == 0 || _loadedImages.length == 0) {
				alert("请先选择图片")
				$(this).hide()
				return
			}

			uploadButton.button('loading')
			$("#loading-text").text("获取上传许可")
			$(".hudBgFrame").show()

			var url = "player/getPrivateUptoken"
			post(url, null, function(resp){
				_uptoken = resp.Token
				_privateUptoken = resp.PrivateToken
				
				var images = $("#thumbRoot").children()
				var totalNum = _loadedImages.length + _loadedThumbs.length + 1
				var uploadedNum = 0
				var thumbMap = {}
				var match = {}
				match.Thumbs = []
				match.Images = []

				$("#loading-text").text("上传中(0/"+totalNum+")")

				$.each(_loadedImages, function(index, loadedImage) {
					var d = loadedImage.data.split(",")
					var data = d[1]

					putb64(_privateUptoken, data, function(xhr) {
						resp = JSON.parse(xhr.responseText)
						if (xhr.status == 200) {
							match.Images[index] = {Key:resp.key, W:loadedImage.width, H:loadedImage.height}
							uploadedNum++
							$("#loading-text").text("上传中("+uploadedNum+"/"+totalNum+")")
							if (uploadedNum == totalNum) {
								$(".hudBgFrame").fadeOut(1000)
								onUploadFinish()
								uploadButton.button('reset')
								return
							}
						} else {
							alert("上传失败")
							$(".hudBgFrame").fadeOut(1000)
							uploadButton.button('reset')
							return
						}
					})
				});

				$.each(_loadedThumbs, function(index, loadedThumb) {
					var d = loadedThumb.data.split(",")
					var data = d[1]
					putb64(_uptoken, data, function(xhr) {
						resp = JSON.parse(xhr.responseText)
						if (xhr.status == 200) {
							match.Thumbs[index] = resp.key
							uploadedNum++
							$("#loading-text").text("上传中("+uploadedNum+"/"+totalNum+")")
							if (uploadedNum == totalNum) {
								$(".hudBgFrame").fadeOut(1000)
								onUploadFinish()
								uploadButton.button('reset')
								return
							}
						} else {
							alert("上传失败")
							$(".hudBgFrame").fadeOut(1000)
							uploadButton.button('reset')
							return
						}
					})
				});

				function uploadCover() {
					var d = _loadedImages[coverIndex-1].data.split(",")
					var data = d[1]

					putb64(_uptoken, data, function(xhr) {
						resp = JSON.parse(xhr.responseText)
						if (xhr.status == 200) {
							match.Cover = resp.key
							match.CoverBlur = match.Cover
							uploadedNum++
							$("#loading-text").text("上传中("+uploadedNum+"/"+totalNum+")")
							if (uploadedNum == totalNum) {
								$(".hudBgFrame").fadeOut(1000)
								onUploadFinish()
								return
							}

						} else {
							alert("上传失败")
							$(".hudBgFrame").fadeOut(1000)
							return
						}
					})
				}
				uploadCover()

				function onUploadFinish() {
					$(".hudBgFrame").hide()
					var coverIndex = parseInt($("#coverIndexInput").val())-1
					match.Thumb = match.Thumbs[coverIndex]
					match.SliderNum = sliderNum
					// match.Private = $("#privateCb")[0].checked
					match.Private = true

					var url = "match/new"
					post(url, match, function(resp){
						alert("发布成功")
						lscache.set("matchPublished", 1)
						window.history.go(-1)
					}, function(resp) {
						if (resp.Error == "err_match_repeat") {
							alert("发布失败：请检查拼图包是否重复发布")
						} else {
							alert("发布失败")
						}
						
						uploadButton.button('reset')
					})
				}
			})
		}

	})
})