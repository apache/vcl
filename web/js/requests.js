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
if("Notification" in window)
	window.Notification.requestPermission();

var resSubmitted = 0;
var suggestTimeData = {}
var resbtntxt = '';
var waittimetimeout = null;
var durationchanged = 0;
var initialimageset = 0;
var resconfigmapid = 0;
var revisiongrids;
var waittimeobj;
var waittimeh;

/*var profilesstoredata = {
	identifier: 'id',
	label: 'name',
	items: []
}*/

function generalReqCB(data, ioArgs) {
	eval(data);
	document.body.style.cursor = 'default';
}

function initViewRequests(imaging) {
	if(typeof(dijit) == "undefined" ||
	   typeof(dijit.byId) == "undefined" ||
	   typeof(images) == "undefined" ||
	   dojo.byId('limitstart') == null ||
	   (imaging && typeof(dijit.byId('deployimage')) == 'undefined')) {
		setTimeout(function() {initViewRequests(imaging);}, 100);
		return;
	}
	if(dijit.byId('deployimage'))
		setLastImage();
	if(imaging) {
		if(imagingaccess == 0) {
			var btn = new dijit.form.Button({
				label: 'Close'
			});
			var dlg = new dijit.Dialog({
				id: 'noimageaccessdlg',
				title: _('Create / Update an Image'),
				content: _('You do not have access to create or update any images.') + '<br><br>',
				style: 'width: 300px; text-align: center;',
				closable: false
			});
			dojo.style(dijit.byId('noimageaccessdlg').closeButtonNode, 'display', 'none');
			dlg.containerNode.appendChild(btn.domNode);
			dojo.connect(btn, "onClick", function () {dlg.destroy();});
			dlg.show();
		}
		else {
			dojo.byId('imagingrdo').checked = true;
			selectResType();
			dijit.byId('newResDlg').show();
		}
	}
	setTimeout(function() {initialimageset = 1;}, 1);
}

function showNewResDlg() {
	resetNewResDlg();
	if(dojo.byId('basicrdo')) {
		selectResType();
		selectEnvironment();
	}
	if(dijit.byId('newResDlgBtn'))
		dijit.byId('newResDlgBtn').set('disabled', false);
	dijit.byId('newResDlg').show();
}

function resetNewResDlg() {
	if(! dijit.byId('deployimage'))
		return;
	setLastImage();
	dojo.byId('basicrdo').checked = true;
	selectResType();
	//dijit.byId('deployprofileid').reset();
	if(dijit.byId('nousercheck'))
		dijit.byId('nousercheck').reset();
	dijit.byId('deployname').reset();
	resetSelect('deployadmingroup');
	resetSelect('deploylogingroup');
	//dijit.byId('deployfixedMAC').reset();
	//dijit.byId('deploymonitored').reset();
	dijit.byId('deployfixedIP').reset();
	dijit.byId('deploynetmask').reset();
	dijit.byId('deployrouter').reset();
	dijit.byId('deploydns').reset();
	resetSelect('deploystartday');
	resetSelect('deployhour');
	resetSelect('deploymin');
	resetSelect('deploymeridian');
	dojo.byId('startnow').checked = true;
	if(dijit.byId('deploystartdate')) {
		dijit.byId('deploystartdate')._hasBeenBlurred = false;
		dijit.byId('deploystartdate').reset();
	}
	if(dijit.byId('deploystarttime')) {
		dijit.byId('deploystarttime')._hasBeenBlurred = false;
		dijit.byId('deploystarttime').reset();
	}
	if(dijit.byId('deployenddate')) {
		dijit.byId('deployenddate')._hasBeenBlurred = false;
		dijit.byId('deployenddate').reset();
	}
	if(dijit.byId('deployendtime')) {
		dijit.byId('deployendtime')._hasBeenBlurred = false;
		dijit.byId('deployendtime').reset();
	}
	resetSelect('reqlength');
	if(dojo.byId('endduration'))
		setTimeout(function() {
			// have to reset again to clear warning icons
			dijit.byId('deployendtime').reset();
			dijit.byId('deployenddate').reset();
			dojo.byId('endduration').checked = true;
		}, 1);
	dojo.byId('deployerr').innerHTML = '';
}

function setLastImage() {
	var sel = dijit.byId('deployimage');
	sel.set('value', lastimageid);
	checkSelectedInList();
}

function selectResType() {
	if(dojo.byId('basicrdo').checked || dojo.byId('imagingrdo').checked) {
		dojo.removeClass('limitstart', 'hidden');
		dojo.removeClass('durationend', 'hidden');
		dojo.addClass('whentitleserver', 'hidden');
		//dojo.addClass('deployprofileslist', 'hidden');
		dojo.addClass('nrnamespan', 'hidden');
		dojo.addClass('nrservergroupspan', 'hidden');
		//dojo.addClass('nrmacaddrspan', 'hidden');
		//dojo.addClass('nrmonitoredspan', 'hidden');
		dojo.addClass('nrfixedipdiv2', 'hidden');
		dojo.addClass('anystart', 'hidden');
		dojo.addClass('indefiniteend', 'hidden');
		//hideDijitButton('newResDlgShowConfigBtn'); // finishconfigs
		if(dojo.byId('openend').value == 1) {
			dojo.removeClass('endlbl', 'hidden');
			dojo.removeClass('specifyend', 'hidden');
		}
		else {
			dojo.addClass('endlbl', 'hidden');
			dojo.addClass('specifyend', 'hidden');
		}
		if(dojo.byId('endat') && ! dojo.byId('endat').checked &&
		   dojo.byId('endduration')) {
			dojo.byId('endduration').checked = true;
			delayedUpdateWaitTime(0, 50);
		}
	}
	if(dojo.byId('basicrdo').checked) {
		dijit.byId('deployimage').set('query', {basic: 1, checkout: 1});
		checkSelectedInList();
		if(dijit.byId('nousercheck'))
			dojo.removeClass('nousercheckspan', 'hidden');
		var imageid = getSelectValue('deployimage');
		var item = dijit.byId('deployimage').get('item');
		var max = imagestore.getValue(item, 'maxinitialtime');
		if(max)
			setMaxRequestLength(max);
		else
			setMaxRequestLength(defaultMaxTime);
		dojo.removeClass('whentitlebasic', 'hidden');
		dojo.addClass('whentitleimaging', 'hidden');
		if(! durationchanged)
			dojo.byId('reqlength').value = 60;
	}
	if(dojo.byId('imagingrdo').checked) {
		dijit.byId('deployimage').set('query', {imaging: 1});
		checkSelectedInList();
		setMaxRequestLength(maximaging);
		dojo.removeClass('whentitleimaging', 'hidden');
		dojo.addClass('whentitlebasic', 'hidden');
		if(dijit.byId('nousercheck'))
			dojo.addClass('nousercheckspan', 'hidden');
		if(! durationchanged)
			dojo.byId('reqlength').value = 480;
	}
	if(dojo.byId('serverrdo').checked) {
		dijit.byId('deployimage').set('query', {server: 1, checkout: 1});
		checkSelectedInList();
		if(dijit.byId('nousercheck'))
			dojo.addClass('nousercheckspan', 'hidden');
		dijit.byId('deploystarttime').set('required', true);
		dijit.byId('deploystartdate').set('required', true);
		dojo.addClass('waittime', 'hidden');
		dojo.addClass('deployerr', 'hidden');
		if(dojo.hasClass('anystart', 'hidden') &&
		   dojo.byId('startlater') &&
		   dojo.byId('startlater').checked) {
			delayedUpdateWaitTime(0, 50);
		}
		dojo.addClass('whentitlebasic', 'hidden');
		dojo.addClass('whentitleimaging', 'hidden');
		dojo.addClass('limitstart', 'hidden');
		dojo.addClass('durationend', 'hidden');
		dojo.removeClass('whentitleserver', 'hidden');
		/*if(profilesstore._arrayOfAllItems.length != 0 &&
		   (profilesstore._arrayOfAllItems.length != 1 ||
		   profilesstore._arrayOfAllItems[0].name != _('(New Profile)')))
			dojo.removeClass('deployprofileslist', 'hidden');*/
		dojo.removeClass('nrnamespan', 'hidden');
		dojo.removeClass('nrservergroupspan', 'hidden');
		//dojo.removeClass('nrmacaddrspan', 'hidden');
		//dojo.removeClass('nrmonitoredspan', 'hidden');
		dojo.removeClass('nrfixedipdiv2', 'hidden');
		dojo.removeClass('anystart', 'hidden');
		dojo.removeClass('indefiniteend', 'hidden');
		dojo.removeClass('endlbl', 'hidden');
		dojo.removeClass('specifyend', 'hidden');
		//showDijitButton('newResDlgShowConfigBtn'); // finishconfigs
		if(dojo.byId('endat') && ! dojo.byId('endat').checked) {
			dojo.byId('endindef').checked = true;
			delayedUpdateWaitTime(0, 50);
		}
	}
	resetDeployBtnLabel();
	resizeRecenterDijitDialog('newResDlg');
}

function checkSelectedInList() {
	var sel = dijit.byId('deployimage');
	var q = new Object();
	for(v in sel.query)
		q[v] = sel.query[v];
	q.id = sel.get('value');
	sel.store.fetch({
		query: q,
		onComplete: function(items, request) {
			if(items.length == 0)
				setFirstAvailableImage();
		}
	});
}

function setFirstAvailableImage() {
	var sel = dijit.byId('deployimage');
	sel.store.fetch({
		query: sel.query,
		onItem: function(item, request) {
			sel.set('value', item['id']);
		},
		count: 1
	});
}

function selectEnvironment() {
	if(! initialimageset)
		return;
	var imageid = getSelectValue('deployimage');
	var item = dijit.byId('deployimage').get('item');
	var max = imagestore.getValue(item, 'maxinitialtime');
	if(max)
		setMaxRequestLength(max);
	else
		setMaxRequestLength(defaultMaxTime);
	dijit.byId('deployname').reset();
	delayedUpdateWaitTime(1, 50);
}

function delayedUpdateWaitTime(cleardesc, time) {
	clearTimeout(waittimetimeout);
	waittimetimeout = setTimeout(function() {updateWaitTime(cleardesc);}, time);
}

function updateWaitTime(cleardesc) {
	if(! dojo.byId('waittime'))
		return;
	dojo.addClass('waittime', 'hidden');
	if(! validateDeployInputs()) {
		if(cleardesc) {
			getImageDescription();
			if(dojo.byId('serverrdo').checked)
				configureSystem();
		}
		return;
	}
	dijit.byId('newResDlgBtn').set('disabled', false);
	if(cleardesc)
		dojo.byId('imgdesc').innerHTML = '';
	var data = getDeployData(1);
	data.continuation = dojo.byId('waitcontinuation').value;
	document.body.style.cursor = 'wait';
	/*if(typeof waittimeobj !== 'undefined')
		waittimeobj.cancel();
	waittimeobj = RPCwrapper(data, generalReqCB, 0, 30000);*/
	RPCwrapper(data, generalReqCB, 0, 30000);
	if(dojo.byId('serverrdo').checked)
		configureSystem();
}

function validateDeployInputs() {
	if(dijit.byId('deployimage') &&
	   ! checkValidatedObj('deployimage')) {
		dijit.byId('newResDlgBtn').set('disabled', true);
		return false;
	}
	if(dojo.byId('endat') && dojo.byId('endat').checked &&
	   (! dijit.byId('deployenddate').isValid() ||
	   ! dijit.byId('deployendtime').isValid())) {
		dijit.byId('newResDlgBtn').set('disabled', true);
	   if(! checkValidatedObj('deployenddate', 'deployerr') ||
	      ! checkValidatedObj('deployendtime', 'deployerr'))
			return false;
	}
	if(dojo.byId('serverrdo').checked &&
	   dojo.byId('startlater') && dojo.byId('startlater').checked &&
	   (! dijit.byId('deploystartdate').isValid() ||
	   ! dijit.byId('deploystarttime').isValid())) {
		dijit.byId('newResDlgBtn').set('disabled', true);
	   if(! checkValidatedObj('deploystartdate', 'deployerr') ||
	      ! checkValidatedObj('deploystarttime', 'deployerr'))
			return false;
	}
	if(dojo.byId('serverrdo').checked &&
	   dijit.byId('deployfixedIP') &&
	   ! checkValidatedObj('deployfixedIP', 'deployerr')) {
		return false;
	}
	var now = new Date();
	now.setMilliseconds(0);
	var nowts = parseInt(now.getTime() / 1000);
	if(dojo.byId('startlater').checked) {
		if(dojo.byId('serverrdo').checked) {
			var start = dijit.byId('deploystartdate').get('value');
			var time = dijit.byId('deploystarttime').get('value');
			start.setHours(time.getHours());
			start.setMinutes(time.getMinutes());
			var teststart = parseInt(start.getTime() / 1000);
			if(start < now) {
				dojo.byId('deployerr').innerHTML = _('The start day and time must be in the future.');
				dojo.removeClass('deployerr', 'hidden');
				dijit.byId('newResDlgBtn').set('disabled', true);
				return false;
			}
		}
		else {
			var tmp = dojo.byId('deploystartday').value;
			var teststart = new Date(tmp * 1000);
			var hour = parseInt(dojo.byId('deployhour').value);
			var m = dojo.byId('deploymeridian').value;
			if(m == 'pm' && hour < 12)
				hour += 12;
			else if(m == 'am' && hour == 12)
				hour = 0;
			teststart.setHours(hour);
			teststart.setMinutes(dojo.byId('deploymin').value);
			teststart.setSeconds(0);
			if(teststart < now) {
				dojo.byId('deployerr').innerHTML = _('The start day and time must be in the future.');
				dojo.removeClass('deployerr', 'hidden');
				dijit.byId('newResDlgBtn').set('disabled', true);
				return false;
			}
			teststart = parseInt(teststart.getTime() / 1000);
		}
	}
	if(dojo.byId('endat') && dojo.byId('endat').checked) {
		var end = dijit.byId('deployenddate').get('value');
		var time = dijit.byId('deployendtime').get('value');
		end.setHours(time.getHours());
		end.setMinutes(time.getMinutes());
		var endts = parseInt(end.getTime() / 1000);
		if(nowts + 1800 > endts) {
			dojo.byId('deployerr').innerHTML = _('The end time must be at least 30 minutes in the future.');
			dojo.removeClass('deployerr', 'hidden');
			dijit.byId('newResDlgBtn').set('disabled', true);
			return false;
		}
		if(dojo.byId('startnow').checked) {
			var teststart = new Date();
			teststart.setMilliseconds(0);
			teststart = parseInt(teststart.getTime() / 1000);
		}
		if(teststart > endts) {
			dojo.byId('deployerr').innerHTML = _('The end time must be after the start time.');
			dojo.removeClass('deployerr', 'hidden');
			dijit.byId('newResDlgBtn').set('disabled', true);
			return false;
		}
		if(teststart + 1800 > endts) {
			dojo.byId('deployerr').innerHTML = _('The end time is too close to the start time.');
			dojo.removeClass('deployerr', 'hidden');
			dijit.byId('newResDlgBtn').set('disabled', true);
			return false;
		}
	}
	if(! dojo.byId('serverrdo').checked)
		return true;

	if(! checkValidatedObj('deployname', 'deployerr') ||
	   ! checkValidatedObj('deployadmingroup', 'deployerr') ||
	   ! checkValidatedObj('deploylogingroup', 'deployerr') ||
	   //! checkValidatedObj('deployfixedMAC', 'deployerr') ||
	   ! checkValidatedObj('deploynetmask', 'deployerr') ||
	   ! checkValidatedObj('deployrouter', 'deployerr') ||
	   ! checkValidatedObj('deploydns', 'deployerr'))
		return false;
	return true;
}

function getDeployData(waitonly) {
	var data = {imageid: getSelectValue('deployimage')}
	if(dojo.byId('startlater').checked) {
		if(dojo.byId('serverrdo').checked) {
			var start = dijit.byId('deploystartdate').get('value');
			var time = dijit.byId('deploystarttime').get('value');
			start.setHours(time.getHours());
			start.setMinutes(time.getMinutes());
			data.start = parseInt(start.getTime() / 1000);
		}
		else {
			var tmp = dojo.byId('deploystartday').value;
			tmp = new Date(tmp * 1000);
			var offset = tmp.getTimezoneOffset() * 60000;
			var date = new Date(tmp.getTime() + offset);
			var hour = parseInt(dojo.byId('deployhour').value);
			var m = dojo.byId('deploymeridian').value;
			if(m == 'pm' && hour < 12)
				hour += 12;
			else if(m == 'am' && hour == 12)
				hour = 0;
			date.setHours(hour);
			date.setMinutes(dojo.byId('deploymin').value);
			date.setSeconds(0);
			data.start = parseInt(date.getTime() / 1000);
		}
	}
	else {
		data.start = 'zero';
	}
	if(dojo.byId('endindef') && dojo.byId('endindef').checked) {
		data.ending = 'indefinite';
	}
	else if(dojo.byId('endat') && dojo.byId('endat').checked) {
		data.ending = 'endat';
		var end = dijit.byId('deployenddate').get('value');
		var time = dijit.byId('deployendtime').get('value');
		end.setHours(time.getHours());
		end.setMinutes(time.getMinutes());
		data.end = parseInt(end.getTime() / 1000);
	}
	else {
		data.ending = 'duration';
		data.duration = dojo.byId('reqlength').value;
	}
	if(dojo.byId('basicrdo').checked)
		data.type = 'basic';
	else if(dojo.byId('imagingrdo').checked)
		data.type = 'imaging';
	else if(dojo.byId('serverrdo').checked)
		data.type = 'server';
	if(dojo.byId('serverrdo').checked &&
	   dijit.byId('deployfixedIP') &&
	   dijit.byId('deployfixedIP').get('value') != '') {
		data.fixedIP = dijit.byId('deployfixedIP').get('value');
	}
	if(waitonly)
		return data;

	// finishconfigs
	/*if(dojo.byId('serverrdo').checked)
		data.configdata = getConfigData();*/
	if(dijit.byId('nousercheck') && dijit.byId('nousercheck').get('value') == 1)
		data.nousercheck = 1;
	else
		data.nousercheck = 0;
	//data.profileid = dojo.byId('appliedprofileid').value;
	data.name = dijit.byId('deployname').get('value');
	data.admingroupid = getSelectValue('deployadmingroup');
	data.logingroupid = getSelectValue('deploylogingroup');
	data.ipaddr = dijit.byId('deployfixedIP').get('value');
	if(data.ipaddr != '') {
		data.netmask = dijit.byId('deploynetmask').get('value');
		data.router = dijit.byId('deployrouter').get('value');
		data.dns = dijit.byId('deploydns').get('value');
	}
	else {
		data.netmask = '';
		data.router = '';
		data.dns = '';
	}
	/*data.macaddr = dijit.byId('deployfixedMAC').get('value');
	if(dijit.byId('deploymonitored').get('value') == 'on')
		data.monitored = 1;
	else
		data.monitored = 0;*/
	return data;
}

function getConfigData() {
	var configdata = [];
	var tmp = configlist.store._getItemsArray();
	for(var i = 0; i < tmp.length; i++) {
		var cfg = '';
		var ids = tmp[i]['id'][0].split('/');
		cfg  = '"' + tmp[i]['id'];
		cfg += '":{"id":"' + tmp[i]['id'];
		cfg += '","applied":"' + tmp[i]['applied'];
		if(parseInt(ids[1]) < 0) {
			cfg += '","configid":"' + tmp[i]['configid'];
			cfg += '","configstageid":"' + tmp[i]['configstageid'];
			cfg += '","imageid":"' + tmp[i]['imageid'];
		}
		cfg += '"}';
		configdata.push(cfg);
	}
	var allcfgs = configdata.join(',');

	var configvardata = [];
	var tmp = dijit.byId('configvariables').store._getItemsArray();
	for(var i = 0; i < tmp.length; i++) {
		var cfgvar = '';
		cfgvar  = '"' + tmp[i]['id'];
		cfgvar += '":{"id":"' + tmp[i]['id'];
		cfgvar += '","value":"' + tmp[i]['defaultvalue'][0].replace(/\n/g, '\\n');
		cfgvar += '"}';
		configvardata.push(cfgvar);
	}
	var allcfgvars = configvardata.join(',');
	return '{"configs":{' + allcfgs + '},"configvars":{' + allcfgvars + '}}';
	//return '{"configs":{' + allcfgs + '}}';
}

function getImageDescription() {
	if(dijit.byId('deployimage') &&
	   ! checkValidatedObj('deployimage'))
		return;
	dojo.byId('imgdesc').innerHTML = '';
	var data = {continuation: dojo.byId('waitcontinuation').value,
	            desconly: 1,
	            imageid: getSelectValue('deployimage')}
	RPCwrapper(data, generalReqCB, 0, 30000);
}

function showSuggestedTimes() {
	if(dojo.byId('suggestcont').value == 'cluster') {
		alert(_('Times cannot be suggested for cluster reservations'));
		return;
	}
	dijit.byId('suggestedTimes').show();
	dojo.byId('suggestContent').innerHTML = '';
	dojo.removeClass('suggestloading', 'hidden');
	dijit.byId('suggestDlgBtn').set('disabled', true);
	showDijitButton('suggestDlgBtn');
	dijit.byId('suggestDlgCancelBtn').set('label', _('Cancel'));
	var data = {continuation: dojo.byId('suggestcont').value};
	RPCwrapper(data, showSuggestedTimesCB, 1, 30000);
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
		dojo.byId('editResDlgPartialMsg').innerHTML = '';
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

function useSuggestedEditSlot() {
	var slot = suggestTimeData[dojo.byId('selectedslot').value];
	var start = parseInt(slot['startts'] + '000');
	var s = new Date(start);
	if(slot['startts'] == dojo.byId('selectedslot').value)
		var e = new Date(start + parseInt(slot['duration'] + '000'));
	else
		var e = new Date(parseInt(dojo.byId('selectedslot').value + '000'));
	var testend = new Date(2038, 0, 1, 0, 0, 0, 0);
	if(dojo.byId('deploystartday')) {
		var sel = dojo.byId('deploystartday');
		for(var i = 0; i < sel.options.length; i++) {
			if(s.getDayName() == sel.options[i].innerHTML) {
				sel.value = sel.options[i].value;
				break;
			}
		}
		var hour = s.getHours();
		if(hour == 0) {
			dojo.byId('deployhour').value = 12;
			dojo.byId('deploymeridian').value = 'am';
		}
		else if(hour == 12) {
			dojo.byId('deployhour').value = 12;
			dojo.byId('deploymeridian').value = 'pm';
		}
		else if(hour > 12) {
			dojo.byId('deployhour').value = hour - 12;
			dojo.byId('deploymeridian').value = 'pm';
		}
		else {
			dojo.byId('deployhour').value = hour;
			dojo.byId('deploymeridian').value = 'am';
		}
		dojo.byId('deploymin').value = s.getMinutes();
		dojo.byId('startlater').checked = true;
	}
	if(dojo.byId('endduration') && dojo.byId('endduration').checked)
		dojo.byId('reqlength').value = parseInt(slot['duration'] / 60);
	if(dojo.byId('endat') && dojo.byId('endat').checked) {
		dijit.byId('deployenddate').set('value', e);
		dijit.byId('deployendtime').set('value', e);
	}
	if(dojo.byId('startlater') && dojo.byId('startlater').checked) {
		dijit.byId('deploystartdate').set('value', s);
		dijit.byId('deploystarttime').set('value', s);
	}
	dijit.byId('suggestedTimes').hide();
	delayedUpdateWaitTime(0, 50);
}

function selectLater() {
	dojo.byId('laterradio').checked = true;
	if(dijit.byId('newResDlgBtn')) {
		if(resbtntxt != '')
			dijit.byId('newResDlgBtn').set('label', resbtntxt);
		else
			dijit.byId('newResDlgBtn').set('label', _('Create Reservation'));
	}
	dojo.addClass('waittime', 'hidden');
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

function setStartNow() {
	dijit.byId('deploystarttime').set('required', false);
	dijit.byId('deploystartdate').set('required', false);
	dojo.addClass('waittime', 'hidden');
	dojo.addClass('deployerr', 'hidden');
	delayedUpdateWaitTime(0, 1000);
	resetDeployBtnLabel();
}

function setStartLater() {
	dojo.byId('startlater').checked = true;
	if(dojo.byId('basicrdo').checked) {
		dijit.byId('deploystarttime').set('required', false);
		dijit.byId('deploystartdate').set('required', false);
	}
	else {
		dijit.byId('deploystarttime').set('required', true);
		dijit.byId('deploystartdate').set('required', true);
	}
	dojo.addClass('deployerr', 'hidden');
	dojo.addClass('waittime', 'hidden');
	delayedUpdateWaitTime(0, 1000);
	resetDeployBtnLabel();
}

function durationChange() {
	durationchanged = 1;
}

function setEndDuration() {
	if(dojo.byId('endduration'))
		dojo.byId('endduration').checked = true;
	dijit.byId('deployendtime').set('required', false);
	dijit.byId('deployenddate').set('required', false);
	dojo.addClass('deployerr', 'hidden');
	dojo.addClass('waittime', 'hidden');
	delayedUpdateWaitTime(0, 1000);
	resetDeployBtnLabel();
}

function setEndIndef() {
	dijit.byId('deployendtime').set('required', false);
	dijit.byId('deployenddate').set('required', false);
	dojo.addClass('deployerr', 'hidden');
	dojo.addClass('waittime', 'hidden');
	delayedUpdateWaitTime(0, 1000);
	resetDeployBtnLabel();
}

function setEndAt() {
	dojo.byId('endat').checked = true;
	dijit.byId('deployendtime').set('required', true);
	dijit.byId('deployenddate').set('required', true);
	dojo.addClass('deployerr', 'hidden');
	dojo.addClass('waittime', 'hidden');
	delayedUpdateWaitTime(0, 1000);
	resetDeployBtnLabel();
}

function resetDeployBtnLabel() {
	if(dojo.byId('basicrdo').checked)
		dijit.byId('newResDlgBtn').set('label', _("Create Reservation"));
	if(dojo.byId('imagingrdo').checked)
		dijit.byId('newResDlgBtn').set('label', _("Create Imaging Reservation"));
	if(dojo.byId('serverrdo').checked)
		dijit.byId('newResDlgBtn').set('label', _("Deploy Server"));
}

function checkValidImage() {
	if(resSubmitted)
		return false;
	if(dijit.byId('deployimage') && ! dijit.byId('deployimage').isValid()) {
		alert(_('Please select a valid environment.'));
		return false;
	}
	if(dijit.byId('newResDlgBtn').get('label') == _('View Available Times')) {
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
	var saveduration = obj.options[obj.selectedIndex].value;
	var saveindex = obj.selectedIndex;
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
		// if option > 45 days, add as weeks
		else if(parseInt(obj.options[i].value) > 64700) {
			var len = parseInt(obj.options[i].value);
			if(len == 64800)
				len = 60480;
			if(len % 10080)
				len = len - (len % 10080);
			else
				len = len + 10080;
			text = len / 10080 + ' ' + _('weeks');
			newminutes = len;
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
	if(saveindex > i)
		obj.value = minutes;
	else
		obj.value = saveduration;
}

function configureSystem() {
	return; // finishconfigs
	var data = {continuation: dojo.byId('configcont').value,
	            imageid: getSelectValue('deployimage')};
	RPCwrapper(data, configureSystemCB, 1, 30000);
}

function configureSystemCB(data, ioArgs) {
	var vardata = {identifier: 'id', label: 'name', items: data.items.configs};
	var newstore = new dojo.data.ItemFileWriteStore({data: vardata});
	var oldstore = configlist.store;
	configlist.setStore(newstore);
	delete oldstore;

	var vardata2 = {identifier: 'id', label: 'name', items: data.items.variables};
	var newstore2 = new dojo.data.ItemFileWriteStore({data: vardata2});
	oldstore = dijit.byId('configvariables').store;
	dijit.byId('configvariables').setStore(newstore2, '', {query: {id: ''}});
	delete oldstore;
	
	// finishconfigs
	/*if(data.items.configs.length == 0)
		dijit.byId('newResDlgShowConfigBtn').set('disabled', true);
	else
		dijit.byId('newResDlgShowConfigBtn').set('disabled', false);*/

	if(dijit.byId('clustertree'))
		dijit.byId('clustertree').destroy();
	if(data.items.cluster) {
		dojo.removeClass('clusterdiv', 'hidden');
		var treedata = {identifier: 'id', label: 'image', items: data.items.subimages};
		var store = new dojo.data.ItemFileReadStore({data: treedata});
		var model = new dijit.tree.ForestStoreModel({
			store: store,
			query: {id: '*'},
			rootId: 'root',
			rootLabel: dijit.byId('deployimage').attr('displayedValue'),
			childrenAttrs: ['children']
		});
		var div = document.createElement('div');
		dojo.byId('treeparent').appendChild(div);
		var tree = dijit.Tree({model: model, id: 'clustertree', onClick: subimageSelected}, div);
	}
	else {
		dojo.addClass('clusterdiv', 'hidden');
	}
}

function showConfigureSystem() {
	if(dojo.hasClass('clusterdiv', 'hidden'))
		setTimeout(function() {configlist.setQuery({id: '*'});}, 1);
	else
		setTimeout(function() {
			configlist.setQuery({id: '0/*', cluster: 0});
			var tree = dijit.byId('clustertree');
			tree.attr('path', ['root']);
			var node = tree._itemNodesMap['root'];
			tree.focusNode(node[0]);
		}, 1);
	dojo.addClass('configdatadiv', 'hidden');
	dijit.byId('newResConfigDlg').show();
}

function closeConfigureSystem() {
	dijit.byId('newResConfigDlg').hide();
	saveSelectedConfig();
	if(configlist.selection.selectedIndex >= 0)
		configlist.selection.setSelected(configlist.selection.selectedIndex, false);
	dojo.byId('configtype').innerHTML = '';
	dojo.byId('configapplychk').checked = false;
	dojo.byId('configkey').innerHTML = '';
	dijit.byId('configvalueint').reset();
	dijit.byId('configvaluefloat').reset();
	dijit.byId('configvaluestring').reset();
	dijit.byId('configvaluetext').reset();
	dojo.addClass('configvalint', 'hidden');
	dojo.removeClass('configvalstring', 'hidden');
	dijit.byId('configvariables').setStore(dijit.byId('configvariables').store, '', {query: {configid: ''}});
}

function subimageSelected(item) {
	if(item.id == 'root')
		var searchid = 0;
	else
		var searchid = item.id[0];
	configlist.setQuery({id: searchid + '/*', cluster: 0});
	configlist.selection.clear();
	dojo.byId('configtype').innerHTML = '';
	dojo.byId('configapplychk').checked = false;
	dojo.addClass('configdatadiv', 'hidden');
}

function addReservationConfig() {
	var item = dijit.byId('addconfigsel').get('item');
	var newitem = {};
	var node = dijit.byId('clustertree').selectedItem;
	if(node.id == 'root') {
		var subimageid = 0;
		var imageid = dijit.byId('deployimage').value;
	}
	else {
		var subimageid = node.id[0];
		var imageid = node.childimageid[0];
	}
	newitem.configmaptype = 'Reservation';
	resconfigmapid--;
	//newitem.configmaptypeid = '5'; // TODO rather not hard code this
	newitem.configid = item.id;
	newitem.id = subimageid + '/' + resconfigmapid;
	newitem.config = item.name;
	newitem.configdata = item.data;
	newitem.subid = 1;
	newitem.affiliationid = 1;
	newitem.affiliation = '';
	newitem.configstageid = 1; // TODO set this from another select object
	newitem.configstage = '';
	newitem.subimageid = null;
	newitem.configsubimageid = null;
	newitem.disabled = 0;
	newitem.configmapid = resconfigmapid;
	newitem.cluster = 0;
	newitem.applied = true;
	newitem.configdata = item.data;
	newitem.ownerid = item.ownerid;
	newitem.owner = item.owner;
	newitem.configtype = item.configtype;
	newitem.configtypeid = item.configtypeid;
	newitem.imageid = imageid;
	configlist.store.newItem(newitem);
	setTimeout(function() {configlist.setQuery({id: subimageid + '/*', cluster: 0});}, 1);
	for(var i = 0; i < item.variables.length; i++) {
		var fromvar = item.variables[i];
		var newvar = {};
		newvar.id =  newitem.id + '/' + fromvar.id; // configid/configvariableid - configid is of form configsubimageid/configmapid
		newvar.name = fromvar.name;
		newvar.description = '';
		newvar.configid = fromvar.configid;
		newvar.type = '';
		newvar.datatype = fromvar.datatype;
		newvar.datatypeid = fromvar.datatypeid;
		newvar.defaultvalue = fromvar.defaultvalue;
		newvar.required = fromvar.required;
		newvar.identifier = fromvar.identifier;
		newvar.ask = parseInt(fromvar.ask);
		dijit.byId('configvariables').store.newItem(newvar);
	}
}

function configSelected(rowIndex) {
	var item = configlist.getItem(rowIndex);
	var store = configlist.store;
	dojo.byId('configtype').innerHTML = store.getValue(item, 'configtype');
	var optional = store.getValue(item, 'optional');
	if(! optional) {
		dojo.byId('configapplychk').checked = true;
		dojo.byId('configapplychk').disabled = true;
	}
	else {
		dojo.byId('configapplychk').disabled = false;
		if(store.getValue(item, 'applied'))
			dojo.byId('configapplychk').checked = true;
		else
			dojo.byId('configapplychk').checked = false;
	}

	var configtype = store.getValue(item, 'configtype');
	if(configtype == 'VLAN' || configtype == 'Cluster')
		dojo.addClass('configdatadiv', 'hidden');
	else {
		dijit.byId('viewconfigdatabtn').set('disabled', false);
		dijit.byId('configvariables').set('disabled', false);
		dijit.byId('configvariables').setStore(dijit.byId('configvariables').store, '', {query: {id: store.getValue(item, 'id') + '/*', ask: 1}});
		if(dijit.byId('configvariables').options.length)
			dojo.removeClass('configvariablediv', 'hidden');
		else
			dojo.addClass('configvariablediv', 'hidden');
		dojo.removeClass('configdatadiv', 'hidden');
	}
}

function setApplyConfig() {
	var item = configlist.getItem(configlist.selection.selectedIndex);
	var store = configlist.store;
	if(dojo.byId('configapplychk').checked)
		store.setValue(item, 'applied', true);
	else
		store.setValue(item, 'applied', false);
}

function showConfigData() {
	var item = configlist.getItem(configlist.selection.selectedIndex);
	var store = configlist.store;
	var data = store.getValue(item, 'configdata');
	dijit.byId('configdatadlg').set('content', data.replace(/\n/g, "<br>"));
}

function selectConfigVariable() {
	var store = dijit.byId('configvariables').store;
	store.fetch({
		query: {id: dijit.byId('configvariables').get('value')},
		onItem: function(item, request) {
			dojo.byId('configkey').innerHTML = store.getValue(item, 'identifier');
			var type = store.getValue(item, 'datatype');
			var value = store.getValue(item, 'defaultvalue');
			dojo.addClass('configvalbool', 'hidden');
			dojo.addClass('configvalint', 'hidden');
			dojo.addClass('configvalfloat', 'hidden');
			dojo.addClass('configvalstring', 'hidden');
			dojo.addClass('configvaltext', 'hidden');
			dojo.removeClass('configval' + type, 'hidden');
			dijit.byId('configvalue' + type).set('value', value);
			if(store.getValue(item, 'required'))
				dojo.byId('configrequired').innerHTML = 'yes';
			else
				dojo.byId('configrequired').innerHTML = 'no';
		}
	});
}

function saveSelectedConfig() {
	if(configlist.selection.selectedIndex < 0)
		return;
	var item = configlist.getItem(configlist.selection.selectedIndex);
	var store = configlist.store;
	if(store.getValue(item, 'optional') && dojo.byId('configapplychk').checked)
		store.setValue(item, 'applied', true);
}

function saveSelectedConfigVar() {
	var store = dijit.byId('configvariables').store;
	store.fetch({
		query: {id: dijit.byId('configvariables').get('value')},
		onItem: function(item, request) {
			var type = store.getValue(item, 'datatype');
			store.setValue(item, 'defaultvalue', dijit.byId('configvalue' + type).get('value'));
		}
	});
}

function promptRevisions() {
	document.body.style.cursor = 'wait';
	var item = dijit.byId('deployimage').get('item');
	var imageid = imagestore.getValue(item, 'id');
	if(dijit.byId('imageRevisionDlg'))
		dijit.byId('imageRevisionDlg').destroyRecursive();
	var divall = document.createElement('div');
	var div1 = document.createElement('div');
	div1.innerHTML = _("There are multiple versions of this environment available.") + "<br>" +
		              _("Please select the version you would like to check out:");
	divall.appendChild(div1);
	var div2 = document.createElement('div');
	div2.id = 'imageRevisionContent';
	div2.style.height = "85%";
	div2.style.width = "88%";
	div2.style.overflow = "auto";
	divall.appendChild(div2);
	var div3 = document.createElement('div');
	div3.style.textAlign = "center";
	var btn1 = new dijit.form.Button({
		id: 'imageRevBtn',
		label: dijit.byId('newResDlgBtn').label,
	}, document.createElement('div'));
	dojo.connect(btn1, 'onClick', submitNewReservation);
	div3.appendChild(btn1.domNode);
	var btn2 = new dijit.form.Button({
		label: _('Cancel'),
	}, document.createElement('div'));
	dojo.connect(btn2, 'onClick', function() {dijit.byId('imageRevisionDlg').hide();});
	div3.appendChild(btn2.domNode);
	divall.appendChild(div3);
	var dlg = new dijit.Dialog({
		id: 'imageRevisionDlg',
		title: _('Select Image Revisions'),
		content: divall,
		width: "50%",
		style: "width: 50%",
		autofocus: false
	});
	detailimagestore.get(imageid).then(promptRevisionsCB);
}

function promptRevisionsCB(item) {
	revisiongrids = new Array();
	addRevisionSelection(item);
	if(! dojo.byId('imagingrdo').checked &&
	   item.imagemetaid != null &&
   	item.subimages.length) {
		for(var i = 0; i < item.subimages.length; i++) {
			detailimagestore.get(item.subimages[i]).then(function(item) {addRevisionSelection(item);});
		}
	}
	dijit.byId('newResDlgBtn').set('disabled', false);
	if(! dojo.byId('imagingrdo').checked &&
	   item.imagemetaid != null &&
   	item.subimages.length)
		setTimeout(function() {showRevisionDlg(item.subimages.length + 1);}, 100);
	else
		showRevisionDlg(1);
}

function addRevisionSelection(item) {
	var mstore = new dojo.store.Memory({data: item.imagerevision});
	var wrapper = new dojo.data.ObjectStore({objectStore: mstore});
	var layout = [
		{field: 'revision', name: _('Revision'), width: '60px'},
		{field: 'user', name: _('User'), width: '130px'},
		{field: 'prettydate', name: _('Created'), width: '110px'},
		{field: 'production', name: _('Production'), width: '60px'}
	];
	var div = document.createElement('div');
	div.style.width = "100%";
	var grid = new dojox.grid.DataGrid(
		{
			store: wrapper,
			structure: layout,
			autoHeight: true
		},
		div
	);
	grid.startup();
	var node = document.createElement('b');
	node.innerHTML = '<br><big>' + item.prettyname + ':</big>';
	dojo.byId('imageRevisionContent').appendChild(node);
	dojo.byId('imageRevisionContent').appendChild(grid.domNode);
	grid.render();
	var newobj = new Object();
	newobj.grid = grid;
	newobj.imageid = item.id;
	revisiongrids.push(newobj);
}

function showRevisionDlg(count) {
	if(revisiongrids.length == count) {
		var waiting = 0;
		for(var i = 0; i < count; i++) {
			revisiongrids[i].grid.render();
			if(! revisiongrids[i].grid._isLoaded) {
				waiting = 1;
				break;
			}
		}
		if(! waiting) {
			document.body.style.cursor = 'default';
			dijit.byId('imageRevisionDlg').show();
			dijit.byId('imageRevisionDlg').domNode.childNodes[3].style.width = "96%";
			return;
		}
	}
	setTimeout(function() {showRevisionDlg(count);}, 100);
}

function submitNewReservation() {
	if(! validateDeployInputs()) {
		return;
	}
	if(dijit.byId('newResDlgBtn').get('label') == _('View Available Times')) {
		showSuggestedTimes();
		return;
	}
	if(! dijit.byId('imageRevisionDlg') || ! dijit.byId('imageRevisionDlg').open) {
		var item = dijit.byId('deployimage').get('item');
		if(imagestore.getValue(item, 'revisions')) {
			dijit.byId('newResDlgBtn').set('disabled', true);
			promptRevisions();
			return;
		}
	}
	var data = getDeployData(0);
	if(dijit.byId('imageRevisionDlg') && dijit.byId('imageRevisionDlg').open) {
		revids = new Array();
		for(var i = 0; i < revisiongrids.length; i++) {
			var sel = revisiongrids[i].grid.selection.getSelected();
			if(sel.length)
				revids.push(sel[0].id);
			else
				revids.push(0);
		}
		data.revisionid = revids.join(':');
		dijit.byId('imageRevBtn').set('label', _('Working...'));
		dijit.byId('imageRevBtn').set('disabled', true);
	}
	else {
		dijit.byId('newResDlgBtn').set('disabled', true);
	}
	data.continuation = dojo.byId('deploycont').value;
	RPCwrapper(data, submitNewReservationCB, 1, 30000);
}

function submitNewReservationCB(data, ioArgs) {
	if(dijit.byId('imageRevisionDlg') && dijit.byId('imageRevisionDlg').open) {
		dijit.byId('imageRevisionDlg').hide();
		dojo.byId('imageRevisionContent').innerHTML = '';
		dijit.byId('imageRevBtn').set('label', dijit.byId('newResDlgBtn').label);
		dijit.byId('imageRevBtn').set('disabled', false);
	}
	dijit.byId('newResDlgBtn').set('disabled', false);
	if(data.items.err == 1) {
		dojo.removeClass('deployerr', 'hidden');
		dojo.byId('deployerr').innerHTML = data.items.errmsg;
		dojo.byId('waittime').innerHTML = '';
		return;
	}
	else if(data.items.err == 2) {
		delayedUpdateWaitTime(0, 50);
		return;
	}
	else if(data.items.err == 0) {
		resRefresh();
		dijit.byId('newResDlg').hide();
	}
}

function checkTimeouts() {
	var nextcheck = 15;
	var nodes = dojo.query('.timeoutvalue');
	var tmp = new Date();
	var now = (tmp.getTime() - tmp.getMilliseconds()) / 1000;
	for(var i = 0; i < nodes.length; i++) {
		var testval = parseInt(nodes[i].value);
		if(testval <= now) {
			nodes[i].parentNode.removeChild(nodes[i]);
			resRefresh();
			break;
		}
		else if(testval - now < nextcheck)
			nextcheck = testval - now;
	}
	if(nodes.length == 0)
		nextcheck = 60;
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
	if(dojo.byId('detailreqid') && dojo.byId('detailreqid').value != 0)
		data.reqid = dojo.byId('detailreqid').value;
	else
		data.incdetails = 0;
	RPCwrapper(data, generalReqCB, 0, 30000);
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

function notifyResReady(names) {
	if(! ("Notification" in window) || ! Notification.permission) {
		//console.log('notifications not supported');
		return;
	}
	var note = new Notification("VCL Reservations ready", { tag: 'reqready', body: names });
}

function connectRequest(cont) {
	RPCwrapper({continuation: cont}, connectRequestCB, 1);
}

function connectRequestCB(data, ioArgs) {
	dijit.byId('connectDlgContent').set('content', data.items.html);
	if('timeoutid' in data.items)
		dojo.byId(data.items.timeoutid).value = data.items.timeout;
	dijit.byId('connectDlg').show();
	if('refresh' in data.items && data.items.refresh == 1)
		resRefresh();
	else
		setTimeout(checkConnectTimeout, 15000);
}

function endReservation(cont) {
	if(dojo.byId('deletecontholder'))
		dojo.byId('deletecontholder').value = cont;
	RPCwrapper({continuation: cont}, endReservationCB, 1, 30000);
}

function endServerReservation() {
	dijit.byId('serverDeleteDlgBtn').set('disabled', true);
	var data = {continuation: dojo.byId('deletecontholder').value,
	            skipconfirm: 1};
	RPCwrapper(data, endReservationCB, 1, 30000);
}

function endReservationCB(data, ioArgs) {
	if(data.items.error) {
		alert(data.items.msg);
		if('refresh' in data.items && data.items.refresh)
			setTimeout(resRefresh, 800);
		return;
	}
	if(data.items.status == 'serverconfirm') {
		dijit.byId('serverDeleteDlgBtn').set('disabled', false);
		dijit.byId('serverdeletedlg').show();
		return;
	}
	if(dijit.byId('serverdeletedlg') && 
	   dijit.byId('serverdeletedlg').open) {
		dijit.byId('serverdeletedlg').hide();
		dijit.byId('serverDeleteDlgBtn').set('disabled', false);
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
			RPCwrapper({continuation: cont}, endReservationCB, 1, 30000);
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
	RPCwrapper(data, generalReqCB, 0, 30000);
}

function removeReservation(cont) {
	RPCwrapper({continuation: cont}, removeReservationCB, 1, 30000);
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
	RPCwrapper(data, generalReqCB, 0, 30000);
}

function editReservation(cont) {
   document.body.style.cursor = 'wait';
	RPCwrapper({continuation: cont}, editReservationCB, 1, 30000);
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
	dojo.byId('editResDlgPartialMsg').innerHTML = '';
	dojo.byId('editResDlgErrMsg').innerHTML = '';
	AJdojoCreate('editResDlgContent');
	if(data.items.status == 'nomodify') {
		dijit.byId('editResDlgBtn').set('style', 'display: none');
		dijit.byId('editResCancelBtn').set('label', _('Okay'));
	}
	else if(data.items.status == 'noindefinite') {
		dijit.byId('editResDlgBtn').set('style', 'display: inline');
		dijit.byId('editResCancelBtn').set('label', _('Cancel'));
		dojo.byId('editrescont').value = data.items.cont;
		dojo.byId('editresid').value = data.items.requestid;
		if(dojo.byId('indefinitelabel'))
			dojo.addClass('indefinitelabel', 'disabledlabel');
		if(dojo.byId('indefiniteradio'))
			dojo.byId('indefiniteradio').disabled = true;
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
	if(dijit.byId('newnousercheck'))
		dijit.byId('newnousercheck').destroy();
	dojo.byId('editResDlgPartialMsg').innerHTML = '';
	dojo.byId('editResDlgErrMsg').innerHTML = '';
	dojo.byId('editrescont').value = '';
	dojo.byId('editresid').value = '';
	resetEditResBtn();
}

function resetEditResBtn() {
	dojo.byId('editResDlgPartialMsg').innerHTML = '';
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
		var now = new Date();
		if(teststart < now) {
			dojo.byId('editResDlgErrMsg').innerHTML = _("The submitted start time is in the past.");
			return;
		}
	}
	if(dijit.byId('newnousercheck') && dijit.byId('newnousercheck').get('value') == 1)
		data.newnousercheck = 1;
	else
		data.newnousercheck = 0;
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
	RPCwrapper(data, submitEditReservationCB, 1, 30000);
}

function submitEditReservationCB(data, ioArgs) {
   document.body.style.cursor = 'default';
	if(data.items.status != 'success' && 'partialupdate' in data.items) {
		dojo.byId('editResDlgPartialMsg').innerHTML = '<br>' + data.items.partialupdate + '<br><br>';
		resRefresh();
	}
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
	if(editresid == '' || editresid == 'undefined')
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
	dojo.byId('editResDlgPartialMsg').innerHTML = '';
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
	RPCwrapper(data, generalReqCB, 0, 30000);
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
	RPCwrapper(data, showReinstallRequestCB, 1, 30000);
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
	RPCwrapper(data, submitReinstallReservationCB, 1, 30000);
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
	if(! dojo.byId('connecttimeout'))
		return;
	var timeout = parseInt(dojo.byId('connecttimeout').value);
	if(timeout == 0)
		return;
	var tmp = new Date();
	var now = (tmp.getTime() - tmp.getMilliseconds()) / 1000;
	if(timeout <= now) {
		dojo.byId('connecttimeout').value = 0;
		var cont = dojo.byId('refreshcont').value;
		RPCwrapper({continuation: cont}, checkConnectTimeoutCB, 1, 30000);
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

function previewClickThrough() {
	RPCwrapper({continuation: dojo.byId('previewclickthroughcont').value},
	            previewClickThroughCB, 1);
	return false;
}

function previewClickThroughCB(data, ioArgs) {
	dojo.byId('clickthroughPreviewDlgContent').innerHTML = data.items.text;
	dijit.byId('clickthroughpreviewdlg').show();
}
