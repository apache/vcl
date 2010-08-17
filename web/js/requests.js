function RPCwrapper(data, CB, dojson) {
	if(dojson) {
		dojo.xhrPost({
			url: 'index.php',
			load: CB,
			handleAs: "json-comment-filtered",
			error: errorHandler,
			content: data,
			timeout: 15000
		});
	}
	else {
		dojo.xhrPost({
			url: 'index.php',
			load: CB,
			error: errorHandler,
			content: data,
			timeout: 15000
		});
	}
}

function generalReqCB(data, ioArgs) {
	eval(data);
	document.body.style.cursor = 'default';
}

function selectEnvironment() {
	var imageid = getSelectValue('imagesel');
	if(maxTimes[imageid])
		setMaxRequestLength(maxTimes[imageid]);
	else
		setMaxRequestLength(defaultMaxTime);
	updateWaitTime(1);
}

function updateWaitTime(cleardesc) {
	var desconly = 0;
	if(cleardesc)
		dojo.byId('imgdesc').innerHTML = '';
	dojo.byId('waittime').innerHTML = '';
	if(! dojo.byId('timenow').checked) {
		dojo.byId('waittime').className = 'hidden';
		desconly = 1;
	}
	if(dojo.byId('openend') &&
	   dojo.byId('openend').checked) {
		dojo.byId('waittime').className = 'hidden';
		desconly = 1;
	}
	var imageid = getSelectValue('imagesel');
	if(dojo.byId('reqlength'))
		var length = dojo.byId('reqlength').value;
	else
		var length = 480;
	var contid = dojo.byId('waitcontinuation').value;
	var data = {continuation: contid,
	            imageid: imageid,
	            length: length,
	            desconly: desconly};
	if(! desconly)
		dojo.byId('waittime').className = 'shown';
	//setLoading();
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function checkValidImage() {
	if(! dijit.byId('imagesel'))
		return;
	if(! dijit.byId('imagesel').isValid()) {
		alert('Please select a valid environment.');
		return false;
	}
	return true;
}

function setMaxRequestLength(minutes) {
	var obj = dojo.byId('reqlength');
	var i;
	var text;
	var newminutes;
	var tmp;
	for(i = obj.length - 1; i >= 0; i--) {
		if(parseInt(obj.options[i].value) > minutes)
			obj.options[i] = null;
	}
	for(i = obj.length - 1; obj.options[i].value < minutes; i++) {
		// if last option is < 60, add 1 hr
		if(parseInt(obj.options[i].value) < 60 &&
			minutes >= 60) {
			text = '1 hour';
			newminutes = 60;
		}
		// if option > 46 hours, add as days
		else if(parseInt(obj.options[i].value) > 2640) {
			var len = parseInt(obj.options[i].value);
			if(len == 2760)
				len = 1440;
			if(len % 1440)
				len = len - (len % 1440);
			else
				len = len + 1440;
			text = len / 1440 + ' days';
			newminutes = len;
			var foo = 'bar';
		}
		// else add in 2 hr chuncks up to max
		else {
			tmp = parseInt(obj.options[i].value);
			if(tmp % 120)
				tmp = tmp - (tmp % 120);
			newminutes = tmp + 120;
			if(newminutes < minutes)
				text = (newminutes / 60) + ' hours';
			else {
				newminutes = minutes;
				tmp = newminutes - (newminutes % 60);
				if(newminutes % 60)
					if(newminutes % 60 < 10)
						text = (tmp / 60) + ':0' + (newminutes % 60) + ' hours';
					else
						text = (tmp / 60) + ':' + (newminutes % 60) + ' hours';
				else
					text = (tmp / 60) + ' hours';
			}
		}
		obj.options[i + 1] = new Option(text, newminutes);
	}
}

function resRefresh() {
	if(! dojo.byId('resRefreshCont'))
		return;
	var contid = dojo.byId('resRefreshCont').value;
	var reqid = dojo.byId('detailreqid').value;
	if(! dijit.byId('resStatusPane')) {
		window.location.reload();
		return;
	}
	/*if(dojo.widget.byId('resStatusPane').windowState == 'minimized')
		var incdetails = 0;
	else*/
		var incdetails = 1;
	var data = {continuation: contid,
	            incdetails: incdetails,
	            reqid: reqid};
	RPCwrapper(data, generalReqCB);
}

function showResStatusPane(reqid) {
	var currdetailid = dojo.byId('detailreqid').value;
	/*if(! dojo.widget.byId('resStatusPane')) {
		window.location.reload();
		return;
	}*/
	var obj = dijit.byId('resStatusPane');
	if(currdetailid != reqid) {
		dojo.byId('detailreqid').value = reqid;
		dojo.byId('resStatusText').innerHTML = 'Loading...';
	}
	var disp = dijit.byId('resStatusPane').domNode.style.visibility;
	if(disp == 'hidden')
		showWindow('resStatusPane');
	if(currdetailid != reqid) {
		if(typeof(refresh_timer) != "undefined")
			clearTimeout(refresh_timer);
		resRefresh();
	}
}

function showWindow(name) {
	var x = mouseX;
	var y = mouseY;
	var obj = dijit.byId(name);
	var coords = obj._naturalState;
	if(coords.t == 0 && coords.l == 0) {
		coords.l = x;
		var newtop = y - (coords.h / 2);
		coords.t = newtop;
		obj.resize(coords);
	}
	obj.show();
}
