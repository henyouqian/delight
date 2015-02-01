$().ready(function() {
	checkAuth()

	addHeader()
	addFooter()

	var descShow = true

	$("#selectImageButton").click(function(){
		if (isMobile() && descShow) {
			alert("\n1.请选择4-9张图片。\n2.选完图可能有明显延迟(好几秒)，请耐心等待。\n3.建议用手机应用或桌面浏览器上传。")
			descShow = false
		}
		$("#imgInput").trigger("click");
		$("#thumbRoot").empty()
	})

	$("#imgInput").change(function(e) {
		if (e.target.files.length < 4) {
			alert("\n图片太少，请选择4-9张图片。")
			return
		}

		$(".hudBgFrame").show()

		var filesToDo = e.target.files.length
		var limit = 9
		if (filesToDo > limit) {
			filesToDo = limit
		}
		
		for (var i in e.target.files) {
			var file = e.target.files[i];
			if (i >= limit) {
				return
			}

			var reader = new FileReader();
			reader.onloadend = function(e) {
				var dataURL = e.target.result;
				// console.log(dataURL)
				var img = new Image();
				img.onload = function(e) {
					$(img).exifLoadFromDataURL(function() {
						console.log("size:", img.width, ",", img.height)

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

						if (false && needResize) {
							$.canvasResize(file, img, {
								width: width,
								height: height,
								crop: false,
								quality: 80,
								//rotate: 90,
								callback: function(data, width, height) {
									console.log("resized")
									doImg(data, width, height)
								}
							})
						} else {
							doImg(dataURL, width, height)
						}

						function doImg(data, width, height) {
							// console.log("msize:", width, ",", height)
							// $("#thumbImg").attr('src', data);

							var thumbDiv = $("#template>.thumbDiv").clone()
			                $("img", thumbDiv).attr("src", data)
			                $("#thumbRoot").append(thumbDiv)
			                thumbDiv.hide().fadeIn(1000)
			                
			                filesToDo--;
			                if (filesToDo == 0) {
			                	$(".hudBgFrame").fadeOut(1000)
			                	
			                }
						}
					})
				}
				img.src = dataURL;
			}
			reader.readAsDataURL(file);
		}
	})
})