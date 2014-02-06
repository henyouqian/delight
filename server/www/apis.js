function Controller($scope, $http) {
	$scope.apilists = [
		{
			"tab":"auth",
			"path":"auth",
			"apis":[
				{
					"name": "login",
					"method": "POST",
					"data": {"Username":"admin", "Password":"admin", "Appsecret":"I3iKFfHISplalqqVvOsCcA=="}
				},{
					"name": "logout",
					"method": "POST",
					"data": ""
				},{
					"name": "info",
					"method": "POST",
					"data": ""
				},{
					"name": "register",
					"method": "POST",
					"data": {"Username":"?", "Password":"?"}
				},{
					"name": "ssdbTest",
					"method": "POST",
					"data": ""
				},
			] 
		},
		{
			"tab":"pack",
			"path":"pack",
			"apis":[
				{
					"name": "add",
					"method": "POST",
					"data": {
						"Date":"2014-99-99",
						"Title":"",
						"Text":"",
						"Icon":"http://",
						"Cover":"http://",
						"Images":[
							{
								"Url": "http://",
								"Title": "",
								"Text": ""
							},{
								"Url": "http://",
								"Title": "",
								"Text": ""
							},
						]
					}
				},{
					"name": "edit",
					"method": "POST",
					"data": {
						"Id":999,
						"Date":"2014-99-99",
						"Title":"",
						"Text":"",
						"Icon":"http://",
						"Cover":"http://",
						"Images":[
							{
								"Url": "http://",
								"Title": "",
								"Text": ""
							},{
								"Url": "http://",
								"Title": "",
								"Text": ""
							},
						]
					}
				},{
					"name": "del",
					"method": "POST",
					"data": {
						"Id":999,
					}
				},{
					"name": "count",
					"method": "POST",
					"data": ""
				},{
					"name": "get",
					"method": "POST",
					"data": {"Offset":0, "Limit":12}
				},{
					"name": "setStar",
					"method": "POST",
					"data": {"PackId":1, "Star":1}
				},
			] 
		},
	]

	var sendCodeMirror = CodeMirror.fromTextArea(sendTextArea, 
		{
			theme: "elegant",
		}
	);
	var recvCodeMirror = CodeMirror.fromTextArea(recvTextArea, 
		{
			theme: "elegant",
		}
	);

	sendCodeMirror.setSize("100%", 500)
	recvCodeMirror.setSize("100%", 500)
	sendCodeMirror.addKeyMap({
		"Ctrl-,": function(cm) {
			var hisList = inputHistory[$scope.currUrl]
			if (isdef(hisList)) {
				var idx = Math.max(0, Math.min(hisList.length-1, inputHisIdx-1))
				if (inputHisIdx != idx) {
					inputHisIdx = idx
					sendCodeMirror.doc.setValue(hisList[inputHisIdx][0])
					recvCodeMirror.doc.setValue(hisList[inputHisIdx][1])
				}
			}
		},
		"Ctrl-.": function(cm) {
			var hisList = inputHistory[$scope.currUrl]
			if (isdef(hisList)) {
				var idx = Math.max(0, Math.min(hisList.length-1, inputHisIdx+1))
				if (inputHisIdx != idx) {
					inputHisIdx = idx
					sendCodeMirror.doc.setValue(hisList[inputHisIdx][0])
					recvCodeMirror.doc.setValue(hisList[inputHisIdx][1])
				}
			}
		},
		"Esc":function(cm) {
			var api = $scope.currApi
			if (api && api.data) {
				sendCodeMirror.doc.setValue(JSON.stringify(api.data, null, '\t'))
			} else {
				sendCodeMirror.doc.setValue("")
			}
			recvCodeMirror.doc.setValue("")
		}
	}) 

	CodeMirror.signal(sendCodeMirror, "keydown", 2)

	var inputHistory = {}
	var sendInput = ""
	var sendUrl=""
	var inputHisIdx = 0

	$scope.currApi = null

	$scope.onApiClick = function(api, path) {
		if ($scope.currApi != api) {
			$("#btn-send").removeAttr("disabled")
			$scope.currApi = api
			$scope.currUrl = path+"/"+$scope.currApi.name
			inputHisIdx = 0
			var hisList = inputHistory[$scope.currUrl]
			if (isdef(hisList)) {
				inputHisIdx = hisList.length-1
				sendCodeMirror.doc.setValue(hisList[inputHisIdx][0])
				recvCodeMirror.doc.setValue(hisList[inputHisIdx][1])
			} else {
				if (api.data) {
					sendCodeMirror.doc.setValue(JSON.stringify(api.data, null, '\t'))
				}else{
					sendCodeMirror.doc.setValue("")
				}
				recvCodeMirror.doc.setValue("")
			}
		}
		sendCodeMirror.focus()
	}

	$scope.queryTick = 0
	var lastHisText = ""
	$scope.send = function() {
		var input = sendCodeMirror.doc.getValue()
		var inputText = input
		if (input) {
			try {
				input = JSON.parse(input)
			} catch(err) {
				alert("parse json error")
				return
			}	
		}

		var onReceive = function(json) {
			printQueryTick()
			var replyText = JSON.stringify(json, null, '\t')
			recvCodeMirror.doc.setValue(replyText)

			//history
			if (isdef(inputHistory[sendUrl])) {
				var inHisList = inputHistory[sendUrl]
				if (inHisList[inHisList.length-1] != sendInput) {
					inputHistory[sendUrl].push([sendInput, replyText])
				}
			} else {
				inputHistory[sendUrl] = [[sendInput, replyText]]
			}
			inputHisIdx = inputHistory[sendUrl].length-1
	
			sendCodeMirror.focus()
		}

		var onFail = function(obj) {
			printQueryTick()
			var t = JSON.stringify(obj.responseJSON, null, '\t')
			if (isdef(t))
				t = t.replace(/\\n/g, "\n")
			if (isdef(t))
				t = t.replace(/\\t/g, "  ")
			var text = obj.status + ":" + obj.statusText + "\n\n" + t
			recvCodeMirror.doc.setValue(text)
		}

		function printQueryTick() {
			$scope.$apply(function(){
				$scope.queryTick = Math.round(window.performance.now() - t)
			});
		}

		sendInput = inputText
		sendUrl = $scope.currUrl
		var url = "/"+sendUrl
		var t = window.performance.now()
		if ($scope.currApi.method == "GET") {
			$.getJSON(url, input, onReceive)
			.fail(onFail)
		}else if ($scope.currApi.method == "POST") {
			$.post(url, sendCodeMirror.doc.getValue(), onReceive, "json")
			.fail(onFail)
		}
	}
}



