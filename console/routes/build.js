var fs = require('fs');
var exec = require('child_process').exec;


exports.build = function(req, res) {
	var packageName = req.params.package;
	var git_url = req.params.git_url;
	var commit = req.params.commit;

	// Clone the repo
	// build package
	// build deps
	//

	var checkExecStatus = function(error, stdout, stdin) {
    	if(error) {
			res.send("git clone/pull failed" + error);
		}
	}

	fs.exists(packageName, function (exists) {
		if(exists) {
			exec("git clone " + git_url + " cd " + packageName, checkExecStatus);
		}
		else {
			exec("cd " + packageName + " && git pull", checkExecStatus);
		}

	});
	var message = "Building " + packageName + " from " + git_url + "#" + commit;
	console.log(message);
	res.send(message);
};
