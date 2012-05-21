/*
* Licensed to the Apache Software Foundation (ASF) under one or more
* contributor license agreements.  See the NOTICE file distributed with
* this work for additional information regarding copyright ownership.
* The ASF licenses this file to You under the Apache License, Version 2.0
* (the "License"); you may not use this file except in compliance with
* the License.  You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
var resSubmitted = 0;
var suggestTimeData = {}
var resbtntxt = '';

function RPCwrapper(data, CB, dojson) {
	if(dojson) {
		dojo.xhrPost({
			url: 'index.php',
			load: CB,
			handleAs: "json",
			error: errorHandler,
			content: data,
			timeout: 30000
		});
	}
	else {
		dojo.xhrPost({
			url: 'index.php',
			load: CB,
			error: errorHandler,
			content: data,
			timeout: 30000
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
	if(! dojo.byId('waittime'))
		return;
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

function showSuggestedTimes() {
	if(dojo.byId('suggestcont').value == 'cluster') {
		alert(_('Times cannot be suggested for cluster reservations'));
		return;
	}
	dijit.byId('suggestedTimes').show();
	dojo.byId('suggestContent').innerHTML = '';
	dojo.removeClass('suggestloading', 'hidden');
	showDijitButton('suggestDlgBtn');
	dijit.byId('suggestDlgCancelBtn').set('label', _('Cancel'));
	var data = {continuation: dojo.byId('suggestcont').value};
	RPCwrapper(data, showSuggestedTimesCB, 1);
	document.body.style.cursor = 'wait';
}

function showSuggestedTimesCB(data, ioArgs) {
	document.body.style.cursor = 'default';
	dojo.addClass('suggestloading', 'hidden');
	dojo.byId('suggestContent').innerHTML = data.items.html;
	if(data.items.status == 'resgone') {
		dijit.byId('suggestedTimes').hide();
		resGone('edit');
		resRefresh();
		return;
	}
	else if(data.items.status == 'error') {
		hideDijitButton('suggestDlgBtn');
		dijit.byId('suggestDlgCancelBtn').set('label', _('Okay'));
		if(dijit.byId('suggestedTimes'))
			recenterDijitDialog('suggestedTimes');
		return;
	}
	else if(data.items.status == 'noextend') {
		dijit.byId('suggestedTimes').hide();
		dojo.byId('editResDlgContent').innerHTML = data.items.html;
		dojo.byId('editResDlgErrMsg').innerHTML = '';
		dijit.byId('editResDlgBtn').set('style', 'display: none');
		dijit.byId('editResCancelBtn').set('label', _('Okay'));
		recenterDijitDialog('editResDlg');
		return;
	}
	recenterDijitDialog('suggestedTimes');
	suggestTimeData = data.items.data;
}

function setSuggestSlot(slot) {
	dojo.byId('selectedslot').value = slot;
	dijit.byId('suggestDlgBtn').set('disabled', false);
}

function useSuggestedSlot() {
	var slot = suggestTimeData[dojo.byId('selectedslot').value];
	dojo.byId('laterradio').checked = true;
	var s = new Date(parseInt(slot['startts'] + '000'));
	dojo.byId('reqday').value = dojox.string.sprintf('%d/%d/%d', s.getMonth() + 1, s.getDate(), s.getFullYear());
	var hm = get12from24(s.getHours());
	dojo.byId('reqhour').value = hm['hour'];
	dojo.byId('reqmeridian').value = hm['meridian'];
	var min = s.getMinutes();
	if(min == 0)
		dojo.byId('reqmin').value = 'zero';
	else
		dojo.byId('reqmin').value = min;
	dojo.byId('reqlength').value = slot['duration'] / 60;
	dojo.byId('waittime').className = 'hidden';
	dijit.byId('suggestedTimes').hide();
	updateWaitTime(0);
}

function selectLater() {
	dojo.byId('laterradio').checked = true;
	if(dojo.byId('newsubmit')) {
		if(resbtntxt != '')
			dojo.byId('newsubmit').value = resbtntxt;
		else
			dojo.byId('newsubmit').value = _('Create Reservation');
	}
	dojo.byId('waittime').innerHTML = '';
}

function selectDuration() {
	if(dojo.byId('durationradio'))
		dojo.byId('durationradio').checked = true;
}

function selectLength() {
	if(dojo.byId('lengthradio'))
		dojo.byId('lengthradio').checked = true;
}

function selectEnding() {
	if(dojo.byId('dateradio'))
		dojo.byId('dateradio').checked = true;
	dijit.byId('editResDlgBtn').set('label', _('Modify Reservation'));
	resetEditResBtn();
}

function setOpenEnd() {
	dojo.byId('openend').checked = true;
	if(! dijit.byId('openenddate').isValid() ||
	   ! dijit.byId('openendtime').isValid()) {
		dojo.byId('enddate').value = '';
		return;
	}
	var d = dijit.byId('openenddate').value;
	var t = dijit.byId('openendtime').value;
	if(d == null || t == null) {
		dojo.byId('enddate').value = '';
		return;
	}
	dojo.byId('enddate').value = dojox.string.sprintf('%d-%02d-%02d %02d:%02d:00',
	                             d.getFullYear(),
	                             (d.getMonth() + 1),
	                             d.getDate(),
	                             t.getHours(),
	                             t.getMinutes());
}

function checkValidImage() {
	if(resSubmitted)
		return false;
	if(dijit.byId('imagesel') && ! dijit.byId('imagesel').isValid()) {
		alert(_('Please select a valid environment.'));
		return false;
	}
	if(dojo.byId('newsubmit').value == _('View Available Times')) {
		showSuggestedTimes();
		return false;
	}
	resSubmitted = 1;
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
			text = '1 ' + _('hour');
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
			text = len / 1440 + ' ' + _('days');
			newminutes = len;
		}
		// else add in 2 hr chuncks up to max
		else {
			tmp = parseInt(obj.options[i].value);
			if(tmp % 120)
				tmp = tmp - (tmp % 120);
			newminutes = tmp + 120;
			if(newminutes < minutes)
				text = (newminutes / 60) + ' ' + _('hours');
			else {
				newminutes = minutes;
				tmp = newminutes - (newminutes % 60);
				if(newminutes % 60)
					if(newminutes % 60 < 10)
						text = (tmp / 60) + ':0' + (newminutes % 60) + ' ' + _('hours');
					else
						text = (tmp / 60) + ':' + (newminutes % 60) + ' ' + _('hours');
				else
					text = (tmp / 60) + ' ' + _('hours');
			}
		}
		obj.options[i + 1] = new Option(text, newminutes);
	}
}

function checkTimeouts() {
	// TODO set nextcheck to 15 once VCL-568 is completed in vcld
	var nextcheck = 16;
	var nodes = dojo.query('.timeoutvalue');
	var tmp = new Date();
	var now = (tmp.getTime() - tmp.getMilliseconds()) / 1000;
	for(var i = 0; i < nodes.length; i++) {
		if(nodes[i].value <= now) {
			resRefresh();
			break;
		}
		else if(nodes[i].value - now < nextcheck)
			nextcheck = nodes[i].value - now;
	}
	check_timeout_timer = setTimeout(checkTimeouts, nextcheck * 1000);
}

function resRefresh() {
	if(! dojo.byId('resRefreshCont'))
		return;
	var contid = dojo.byId('resRefreshCont').value;
	/*if(dojo.widget.byId('resStatusPane').windowState == 'minimized')
		var incdetails = 0;
	else*/
		var incdetails = 1;
	var data = {continuation: contid,
	            incdetails: incdetails};
	if(dojo.byId('detailreqid'))
		data.reqid = dojo.byId('detailreqid').value;
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
		dojo.byId('resStatusText').innerHTML = _('Loading...');
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

function endReservation(cont) {
	RPCwrapper({continuation: cont}, endReservationCB, 1);
}

function endReservationCB(data, ioArgs) {
	if(data.items.error) {
		alert(data.items.msg);
		return;
	}
	dojo.byId('endrescont').value = data.items.cont;
	dojo.byId('endresid').value = data.items.requestid;
	dojo.byId('endResDlgContent').innerHTML = data.items.content;
	dijit.byId('endResDlgBtn').set('label', data.items.btntxt);
	dijit.byId('endResDlg').show();
}

function submitDeleteReservation() {
	if(dojo.byId('radioprod')) {
		if(dojo.byId('radioprod').checked) {
			var cont = dojo.byId('radioprod').value;
			RPCwrapper({continuation: cont}, endReservationCB, 1);
			return;
		}
		else if(dojo.byId('radioend').checked)
			var data = {continuation: dojo.byId('radioend').value};
		else
			return;
	}
	else {
		var data = {continuation: dojo.byId('endrescont').value};
	}
	dojo.byId('endResDlgContent').innerHTML = '';
	dijit.byId('endResDlg').hide();
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function removeReservation(cont) {
	RPCwrapper({continuation: cont}, removeReservationCB, 1);
}

function removeReservationCB(data, ioArgs) {
	if(data.items.error) {
		alert(data.items.msg);
		if(data.items.error == 2)
			window.location.href = data.items.url;
		return;
	}
	dojo.byId('remrescont').value = data.items.cont;
	dojo.byId('remResDlgContent').innerHTML = data.items.content;
	dijit.byId('remResDlg').show();
}

function submitRemoveReservation() {
	var data = {continuation: dojo.byId('remrescont').value};
	dojo.byId('remResDlgContent').innerHTML = '';
	dijit.byId('remResDlg').hide();
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function editReservation(cont) {
   document.body.style.cursor = 'wait';
	RPCwrapper({continuation: cont}, editReservationCB, 1);
}

function editReservationCB(data, ioArgs) {
	if(data.items.status == 'resgone') {
		document.body.style.cursor = 'default';
		dijit.byId('editResDlg').show();
		resGone('edit');
		resRefresh();
		return;
	}
	dojo.byId('editResDlgContent').innerHTML = data.items.html;
	dojo.byId('editResDlgErrMsg').innerHTML = '';
	AJdojoCreate('editResDlgContent');
	if(data.items.status == 'nomodify') {
		dijit.byId('editResDlgBtn').set('style', 'display: none');
		dijit.byId('editResCancelBtn').set('label', _('Okay'));
	}
	else {
		dijit.byId('editResDlgBtn').set('style', 'display: inline');
		dijit.byId('editResCancelBtn').set('label', _('Cancel'));
		dojo.byId('editrescont').value = data.items.cont;
		dojo.byId('editresid').value = data.items.requestid;
	}
	dijit.byId('editResDlg').show();
   document.body.style.cursor = 'default';
}

function hideEditResDlg() {
	if(dijit.byId('day'))
		dijit.byId('day').destroy();
	if(dijit.byId('editstarttime'))
		dijit.byId('editstarttime').destroy();
	if(dijit.byId('length'))
		dijit.byId('length').destroy();
	if(dijit.byId('openenddate'))
		dijit.byId('openenddate').destroy();
	if(dijit.byId('openendtime'))
		dijit.byId('openendtime').destroy();
	if(dijit.byId('servername'))
		dijit.byId('servername').destroy();
	if(dijit.byId('admingrpsel'))
		dijit.byId('admingrpsel').destroy();
	if(dijit.byId('logingrpsel'))
		dijit.byId('logingrpsel').destroy();
	dojo.byId('editResDlgErrMsg').innerHTML = '';
	dojo.byId('editrescont').value = '';
	dojo.byId('editresid').value = '';
	resetEditResBtn();
}

function resetEditResBtn() {
	dojo.byId('editResDlgErrMsg').innerHTML = '';
	dijit.byId('editResDlgBtn').set('label', _('Modify Reservation'));
}

function editResOpenEnd() {
	if(! dijit.byId('openenddate').isValid() ||
	   ! dijit.byId('openendtime').isValid()) {
		dojo.byId('enddate').value = '';
		return;
	}
	var d = dijit.byId('openenddate').value;
	var t = dijit.byId('openendtime').value;
	if(d == null || t == null) {
		dojo.byId('enddate').value = '';
		return;
	}
	dojo.byId('enddate').value = dojox.string.sprintf('%d-%02d-%02d %02d:%02d:00',
	                             d.getFullYear(),
	                             (d.getMonth() + 1),
	                             d.getDate(),
	                             t.getHours(),
	                             t.getMinutes());
}

function useSuggestedEditSlot() {
	var slot = suggestTimeData[dojo.byId('selectedslot').value];
	var tmp = parseInt(slot['startts'] + '000');
	var s = new Date(tmp);
	if(slot['startts'] == dojo.byId('selectedslot').value)
		var e = new Date(tmp + parseInt(slot['duration'] + '000'));
	else
		var e = new Date(parseInt(dojo.byId('selectedslot').value + '000'));
	var testend = new Date(2038, 0, 1, 0, 0, 0, 0);
	if(dijit.byId('day')) {
		var day = dojox.string.sprintf('%d%02d%02d', s.getFullYear(), s.getMonth() + 1, s.getDate());
		dijit.byId('day').set('value', day);
	}
	if(dijit.byId('editstarttime'))
		dijit.byId('editstarttime').set('value', s);
	if(! dojo.byId('indefiniteradio') || e < testend) {
		if(dijit.byId('openenddate'))
			dijit.byId('openenddate').set('value', e);
		if(dijit.byId('openendtime'))
			dijit.byId('openendtime').set('value', e);
	}

	var len = slot['duration'] / 60; 
	if(dojo.byId('indefiniteradio') && e >= testend) {
		dojo.byId('indefiniteradio').checked = true;
	}
	else if(dijit.byId('length') && dijit.byId('length').getOptions(len.toString())) {
		dijit.byId('length').set('value', len);
		if(dojo.byId('lengthradio'))
			dojo.byId('lengthradio').checked = true;
	}
	else if(dojo.byId('dateradio')) {
		dojo.byId('dateradio').checked = true;
	}

	dijit.byId('suggestedTimes').hide();
}

function submitEditReservation() {
	if(dijit.byId('editResDlgBtn').get('label') == _('View Available Times')) {
		dijit.byId('suggestDlgBtn').set('disabled', true);
		showDijitButton('suggestDlgBtn');
		dijit.byId('suggestDlgCancelBtn').set('label', _('Cancel'));
		showSuggestedTimes();
		return;
	}
	var cont = dojo.byId('editrescont').value;
	var data = {continuation: cont};
	if(dijit.byId('day'))
		data.day = dijit.byId('day').value;
	if(dijit.byId('editstarttime')) {
		var t = dijit.byId('editstarttime').value;
		data.starttime = dojox.string.sprintf('%02d%02d', 
		                                      t.getHours(),
		                                      t.getMinutes());
		var tmp = dijit.byId('day').value.match(/([0-9]{4})([0-9]{2})([0-9]{2})/);
		var teststart = new Date(tmp[1], tmp[2] - 1, tmp[3], t.getHours(), t.getMinutes(), 0, 0);
	}
	if(dijit.byId('servername'))
		data.servername = dijit.byId('servername').get('value');
	if(dijit.byId('admingrpsel')) {
		data.admingroupid = dijit.byId('admingrpsel').get('value');
		data.logingroupid = dijit.byId('logingrpsel').get('value');
	}
	else if(dojo.byId('admingrpsel')) {
		data.admingroupid = dojo.byId('admingrpsel').value;
		data.logingroupid = dojo.byId('logingrpsel').value;
	}
	if((! dojo.byId('dateradio') && ! dojo.byId('indefiniteradio') && dijit.byId('length')) ||
	   (dojo.byId('lengthradio') && dojo.byId('lengthradio').checked)) {
		data.length = dijit.byId('length').value;
		data.endmode = 'length';
	}
	else if((dojo.byId('dateradio') && dojo.byId('dateradio').checked) ||
	        (dijit.byId('openenddate') && ! dojo.byId('indefiniteradio')) || 
	        (dijit.byId('openenddate') && dojo.byId('indefiniteradio') && ! dojo.byId('indefiniteradio').checked)) {
		var d = dijit.byId('openenddate').value;
		var t = dijit.byId('openendtime').value;
		data.ending = dojox.string.sprintf('%d%02d%02d%02d%02d',
		              d.getFullYear(),
		              (d.getMonth() + 1),
		              d.getDate(),
		              t.getHours(),
		              t.getMinutes());
		data.endmode = 'ending';
		var testend = new Date(d.getFullYear(), d.getMonth(), d.getDate(), t.getHours(), t.getMinutes(), 0, 0);
		if(dijit.byId('editstarttime') && testend <= teststart) {
			dojo.byId('editResDlgErrMsg').innerHTML = _("The end time must be later than the start time.");
			return;
		}
	}
	else {
		data.endmode = 'indefinite';
	}
	document.body.style.cursor = 'wait';
	RPCwrapper(data, submitEditReservationCB, 1);
}

function submitEditReservationCB(data, ioArgs) {
   document.body.style.cursor = 'default';
	if(data.items.status == 'error') {
		dojo.byId('editResDlgErrMsg').innerHTML = data.items.errmsg;
		dojo.byId('editrescont').value = data.items.cont;
		dojo.byId('editresid').value = '';
		return;
	}
	else if(data.items.status == 'norequest') {
		dojo.byId('editResDlgContent').innerHTML = data.items.html;
		dojo.byId('editResDlgErrMsg').innerHTML = '';
		dijit.byId('editResDlgBtn').set('style', 'display: none');
		dijit.byId('editResCancelBtn').set('label', _('Okay'));
		resRefresh();
		return;
	}
	else if(data.items.status == 'conflict') {
		dojo.byId('editResDlgErrMsg').innerHTML = data.items.errmsg;
		dojo.byId('editrescont').value = data.items.cont;
		//dojo.byId('editresid').value = '';
		dojo.byId('suggestcont').value = data.items.sugcont;
		dijit.byId('editResDlgBtn').set('label', _('View Available Times'));
		return;
	}
	else if(data.items.status == 'unavailable') {
		dojo.byId('editResDlgErrMsg').innerHTML = data.items.errmsg;
		dojo.byId('editrescont').value = data.items.cont;
		dojo.byId('editresid').value = '';
		return;
	}
	dijit.byId('editResDlg').hide();
	resRefresh();
}

function checkResGone(reqids) {
	var editresid = dojo.byId('editresid').value;
	if(editresid == '')
		return;
	for(var i = 0; i < reqids.length; i++) {
		if(editresid == reqids[i])
			return;
	}
	resGone('edit');
}

function resGone(type) {
	if(type == 'edit') {
		dojo.byId('editResDlgContent').innerHTML = _('The reservation you selected<br>to edit has expired.<br><br>');
	}
	else if(type == 'reboot') {
		dojo.byId('editResDlgContent').innerHTML = _('The reservation you selected<br>to reboot has expired.<br><br>');
	}
	else if(type == 'reinstall') {
		dojo.byId('editResDlgContent').innerHTML = _('The reservation you selected<br>to reinstall has expired.<br><br>');
	}
	dojo.byId('editresid').value = '';
	dojo.byId('editResDlgErrMsg').innerHTML = '';
	dijit.byId('editResDlgBtn').set('style', 'display: none');
	dijit.byId('editResCancelBtn').set('label', _('Okay'));
	recenterDijitDialog('editResDlg');
}

function hideRebootResDlg() {
	dojo.byId('softreboot').checked = true;
	dojo.byId('rebootrescont').value = '';
	dojo.byId('rebootResDlgErrMsg').innerHTML = '';
}

function rebootRequest(cont) {
	dojo.byId('rebootrescont').value = cont;
	dijit.byId('rebootdlg').show();
}

function submitRebootReservation() {
	var data = {continuation: dojo.byId('rebootrescont').value};
	document.body.style.cursor = 'wait';
	if(dojo.byId('hardreboot').checked)
		data.reboottype = 1;
	else
		data.reboottype = 0;
	dijit.byId('rebootdlg').hide();
	RPCwrapper(data, generalReqCB);
}

function hideReinstallResDlg() {
	dojo.addClass('reinstallbtns', 'hidden');
	dojo.byId('reinstallResDlgContent').innerHTML = '';
	dojo.byId('reinstallResDlgErrMsg').innerHTML = '';
	dojo.byId('reinstallrescont').value = '';
}

function showReinstallRequest(cont) {
	dojo.removeClass('reinstallloading', 'hidden');
	dijit.byId('reinstalldlg').show();
	var data = {continuation: cont};
	RPCwrapper(data, showReinstallRequestCB, 1);
	document.body.style.cursor = 'wait';
}

function showReinstallRequestCB(data, ioArgs) {
	document.body.style.cursor = 'default';
	if(data.items.status == 'resgone') {
		dijit.byId('reinstalldlg').hide();
		resGone('reinstall');
		dijit.byId('editResDlg').show();
		setTimeout(resRefresh, 1500);
		return;
	}
	dojo.addClass('reinstallloading', 'hidden');
	dojo.removeClass('reinstallbtns', 'hidden');
	dojo.byId('reinstallrescont').value = data.items.cont;
	dojo.byId('reinstallResDlgContent').innerHTML = data.items.txt;
	recenterDijitDialog('reinstalldlg');
}

function submitReinstallReservation() {
	var data = {continuation: dojo.byId('reinstallrescont').value};
	var inputs = document.getElementsByName('revisionid');
	for(var i = 0; i < inputs.length; i++) {
		if(inputs[i].checked) {
			data.revisionid = inputs[i].value;
			break;
		}
	}
	document.body.style.cursor = 'wait';
	RPCwrapper(data, submitReinstallReservationCB, 1);
}

function submitReinstallReservationCB(data, ioArgs) {
	document.body.style.cursor = 'default';
	if(data.items.status == 'resgone') {
		dijit.byId('reinstalldlg').hide();
		resGone('reinstall');
		dijit.byId('editResDlg').show();
		setTimeout(resRefresh, 1500);
		return;
	}
	if(data.items.status == 'invalidrevisionid') {
		dojo.byId('reinstallResDlgErrMsg').innerHTML = _('An invalid version was submitted.');
		dojo.byId('reinstallrescont').value = data.items.cont;
		return;
	}
	if(data.items.status == 'success') {
		dijit.byId('reinstalldlg').hide();
		resRefresh();
	}
}

function checkConnectTimeout() {
	var nextcheck = 15;
	if(! dojo.byId('timeoutvalue'))
		return;
	var timeout = dojo.byId('timeoutvalue').value;
	var tmp = new Date();
	var now = (tmp.getTime() - tmp.getMilliseconds()) / 1000;
	if(timeout <= now) {
		var cont = dojo.byId('refreshcont').value;
		RPCwrapper({continuation: cont}, checkConnectTimeoutCB, 1);
		return;
	}
	else if(timeout - now < nextcheck) {
		nextcheck = timeout - now;
	}
	setTimeout(checkConnectTimeout, nextcheck * 1000);
}

function checkConnectTimeoutCB(data, ioArgs) {
	if(data.items.status == 'timeout') {
		dijit.byId('timeoutdlg').show();
		return;
	}
	else if(data.items.status == 'inuse') {
		setTimeout(checkConnectTimeout, 300000);
	}
}

function showRDPbutton() {
	// submitted by Gerhard Harti from ODU
	if(! dojo.byId('counterdiv') || ! dojo.byId('connectdiv'))
		return;
	var timeInterval = 2;
	if(typeof timeInterval === 'undefined' || parseInt(timeInterval) <= 0) {
		timeInterval = 1
	}
	dojo.addClass('connectdiv', 'hidden');
	dojo.removeClass('counterdiv', 'hidden');
	if(timeInterval == 1)
		dojo.byId('counterdiv').innerHTML = _(' Ready to connect in ') + timeInterval + _(' second');
	else
		dojo.byId('counterdiv').innerHTML = _(' Ready to connect in ') + timeInterval + _(' seconds');
	var si = setInterval(function() {
		if(timeInterval === 0) {
			clearInterval(si);
		} else {
			timeInterval--;
			if(timeInterval !== 0) {
				if(timeInterval == 1)
					dojo.byId('counterdiv').innerHTML = _(' Ready to connect in ') + timeInterval + _(' second');
				else
					dojo.byId('counterdiv').innerHTML = _(' Ready to connect in ') + timeInterval + _(' seconds');
			} else {
				dojo.addClass('counterdiv', 'hidden');
				dojo.removeClass('connectdiv', 'hidden');
			}
		}
	}, 1000);
}
