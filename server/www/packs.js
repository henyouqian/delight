function Controller($scope, $http) {
	var addPackTemplate = {
		"icon":"",
		"cover":"",
		"images":[
			{
				"url":""
			}
		]
	}

	addPackCodeMirror = CodeMirror.fromTextArea(
		addPackTextArea, 
		{
			theme: "elegant",
		}
	)

	editPackCodeMirror = CodeMirror.fromTextArea(
		editPackTextArea, 
		{
			theme: "elegant",
		}
	)

	$scope.addPackDlg = function() {
		$('#addModal').modal({})
		console.log(addPackCodeMirror)
		addPackCodeMirror.doc.setValue(JSON.stringify(addPackTemplate, null, '\t'))
		setTimeout("addPackCodeMirror.refresh()",500);
		
	}

	$scope.addPack = function() {
		var input = addPackCodeMirror.doc.getValue()
		var inputText = input
		if (input) {
			try {
				input = JSON.parse(input)
			} catch(err) {
				alert("parse json error")
				return
			}
		}
		$('#addModal').modal('hide')
	}

	$scope.editPackDlg = function(pack) {
		$('#editModal').modal({})
		var pk = pack
		delete pk.Star
		delete pk.$$hashKey
		editPackCodeMirror.doc.setValue(JSON.stringify(pk, null, '\t'))
		setTimeout("editPackCodeMirror.refresh()",500);
	}

	$scope.editPack = function() {
		var input = editPackCodeMirror.doc.getValue()
		var jsInput
		if (input) {
			try {
				jsInput = JSON.parse(input)
			} catch(err) {
				alert("parse json error")
				return
			}
			$.post('/pack/edit',
				input,
				function(json){
					$scope.$apply(function(){
						for (var i = 0; i < $scope.packs.length; ++i) {
							if ($scope.packs[i].Id == jsInput.Id) {
								$scope.packs[i] = jsInput
								return;
							}
						}
					})
				}
			)
			.fail(function(json) {
				alert("error");
				console.log(json)
			})
			.always(function() {
				$('#editModal').modal('hide')
			})
		}
	}

	//get packs
	var data = JSON.stringify({
		"Offset": 0,
		"Limit": 12
	})
	$.post('/pack/get',
		data,
		function(json){
			$scope.$apply(function(){
				$scope.packs = JSON.parse(json).Packs
			});
		}
	)
}



