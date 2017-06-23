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

function generalSiteConfigCB(data, ioArgs) {
	if(data.items.status == 'success') {
		dojo.removeClass(data.items.msgid, 'cfgerror');
		dojo.addClass(data.items.msgid, 'cfgsuccess');
		dojo.byId(data.items.msgid).innerHTML = data.items.msg;
		if('contid' in data.items && 'savecont' in data.items)
			dojo.byId(data.items.contid).value = data.items.savecont;
		if('btn' in data.items)
			dijit.byId(data.items.btn).set('disabled', false);
		if('extrafunc' in data.items) {
			if(data.items.extrafunc.match('\.')) {
				var part1 = data.items.extrafunc.split('.')[0];
				var part2 = data.items.extrafunc.split('.')[1];
				window[part1][part2](data);
			}
			else
				window[data.items.extrafunc](data);
		}
		clearmsg(data.items.msgid, 20);
	}
	else if(data.items.status == 'noaction') {
		dojo.removeClass(data.items.msgid, 'cfgerror');
		dojo.removeClass(data.items.msgid, 'cfgsuccess');
		dojo.byId(data.items.msgid).innerHTML = '';
		if('btn' in data.items)
			dijit.byId(data.items.btn).set('disabled', false);
	}
	else if(data.items.status == 'failed') {
		dojo.removeClass(data.items.msgid, 'cfgsuccess');
		dojo.addClass(data.items.msgid, 'cfgerror');
		dojo.byId(data.items.msgid).innerHTML = data.items.errmsg;
		if('btn' in data.items)
			dijit.byId(data.items.btn).set('disabled', false);
		if('contid' in data.items && 'savecont' in data.items)
			dojo.byId(data.items.contid).value = data.items.savecont;
	}
	else if(data.items.status == 'noaccess') {
		alert(data.items.msg);
	}
}

function clearmsg(id, wait) {
	setTimeout(function() {
		dojo.byId(id).innerHTML = '';
		dojo.removeClass(id, 'cfgerror');
		dojo.removeClass(id, 'cfgsuccess');
	}, wait * 1000);
}

function saveTimeSource() {
	var data = {continuation: dojo.byId('timesourcecont').value,
	            timesource: dijit.byId('timesource').value};
	dijit.byId('timesourcebtn').set('disabled', true);
	RPCwrapper(data, generalSiteConfigCB, 1);
}

function TimeVariable() {}

TimeVariable.prototype.addAffiliationSetting = function() {
	dijit.byId(this.domidbase + 'addbtn').set('disabled', true);
	var data = {continuation: dojo.byId(this.domidbase + 'addcont').value,
	            affilid: dijit.byId(this.domidbase + 'newaffilid').value,
	            value: dijit.byId(this.domidbase + 'newval').value};
	RPCwrapper(data, generalSiteConfigCB, 1);
}

TimeVariable.prototype.addAffiliationSettingCBextra = function(data) {
	var span = document.createElement('span');
	span.setAttribute('id', data.items.id + 'span');
	var label = document.createElement('label');
	label.setAttribute('for', data.items.id);
	label.innerHTML = data.items.affil + ': ';
	span.appendChild(label);
	var span2 = document.createElement('span');
	span2.setAttribute('class', 'labeledform');
	var spinner = new dijit.form.NumberSpinner({
		id: data.items.id,
		required: 'true',
		style: 'width: 70px;',
		value: data.items.value,
		constraints: {min: data.items.minval, max: data.items.maxval},
		smallDelta: 1,
		largeDelta: 10
	}, document.createElement('div'));
	span2.appendChild(spinner.domNode);
	span.appendChild(span2);
	var func = this.deleteAffiliationSetting;
	var domidbase = this.domidbase;
	var btn = new dijit.form.Button({
		id: data.items.id + 'delbtn',
		label: _('Delete'),
		onClick: function() {
			func(data.items.id, domidbase);
		}
	}, document.createElement('div'));
	span.appendChild(btn.domNode);
	span.appendChild(document.createElement('br'));
	dojo.byId(this.domidbase + 'affildiv').appendChild(span);
	dojo.byId('delete' + this.domidbase + 'cont').value = data.items.deletecont;
	dojo.byId(this.domidbase + 'cont').value = data.items.savecont;
	dijit.byId(this.domidbase + 'newaffilid').removeOption({value: data.items.affilid});
	if(dijit.byId(this.domidbase + 'newaffilid').options.length == 0)
		dojo.addClass(this.domidbase + 'adddiv', 'hidden');
	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	keys.push(data.items.id);
	dojo.byId(this.domidbase + 'savekeys').value = keys.join(',');
}

TimeVariable.prototype.saveSettings = function() {
	var data = {continuation: dojo.byId(this.domidbase + 'cont').value};
	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	for(var i = 0; i < keys.length; i++) {
		if(! checkValidatedObj(keys[i])) {
			dijit.byId(keys[i]).focus();
			return;
		}
		data[keys[i]] = dijit.byId(keys[i]).get('value');
	}
	dijit.byId(this.domidbase + 'btn').set('disabled', true);
	RPCwrapper(data, generalSiteConfigCB, 1);
}

TimeVariable.prototype.deleteAffiliationSetting = function(key, domidbase) {
	var data = {key: key,
	            continuation: dojo.byId('delete' + domidbase + 'cont').value};
	RPCwrapper(data, generalSiteConfigCB, 1);
}

TimeVariable.prototype.deleteAffiliationSettingCBextra = function(data) {
	dijit.byId(data.items.delid).destroy();
	dijit.byId(data.items.delid + 'delbtn').destroy();
	dojo.destroy(data.items.delid + 'span');
	dijit.byId(this.domidbase + 'newaffilid').addOption({value: data.items.affilid, label: data.items.affil});
	dojo.removeClass(this.domidbase + 'adddiv', 'hidden');
	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	var newkeys = new Array();
	for(var i = 0; i < keys.length; i++) {
		if(keys[i] != data.items.delid)
			newkeys.push(keys[i]);
	}
	dojo.byId(this.domidbase + 'savekeys').value = newkeys.join(',');
	dojo.byId(this.domidbase + 'cont').value = data.items.savecont;
}

function connectedUserCheck() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'connectedusercheck';
}
connectedUserCheck.prototype = new TimeVariable();
var connectedUserCheck = new connectedUserCheck();

function acknowledge() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'acknowledge';
}
acknowledge.prototype = new TimeVariable();
var acknowledge = new acknowledge();

function initialconnecttimeout() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'initialconnecttimeout';
}
initialconnecttimeout.prototype = new TimeVariable();
var initialconnecttimeout = new initialconnecttimeout();

function reconnecttimeout() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'reconnecttimeout';
}
reconnecttimeout.prototype = new TimeVariable();
var reconnecttimeout = new reconnecttimeout();

function generalInuse() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'generalinuse';
}
generalInuse.prototype = new TimeVariable();
var generalInuse = new generalInuse();

function serverInuse() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'serverinuse';
}
serverInuse.prototype = new TimeVariable();
var serverInuse = new serverInuse();

function clusterInuse() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'clusterinuse';
}
clusterInuse.prototype = new TimeVariable();
var clusterInuse = new clusterInuse();

function generalEndNotice1() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'generalendnotice1';
}
generalEndNotice1.prototype = new TimeVariable();
var generalEndNotice1 = new generalEndNotice1();

function generalEndNotice2() {
	TimeVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'generalendnotice2';
}
generalEndNotice2.prototype = new TimeVariable();
var generalEndNotice2 = new generalEndNotice2();

function AffilTextVariable() {}

AffilTextVariable.prototype.addAffiliationSetting = function() {
	dijit.byId(this.domidbase + 'addbtn').set('disabled', true);
	var data = {continuation: dojo.byId(this.domidbase + 'addcont').value,
	            affilid: dijit.byId(this.domidbase + 'newaffilid').value,
	            value: dijit.byId(this.domidbase + 'newval').value};
	RPCwrapper(data, generalSiteConfigCB, 1);
}

AffilTextVariable.prototype.addAffiliationSettingCBextra = function(data) {
	var span = document.createElement('span');
	span.setAttribute('id', data.items.id + 'span');
	var label = document.createElement('label');
	label.setAttribute('for', data.items.id);
	label.innerHTML = data.items.affil + ': ';
	span.appendChild(label);
	var span2 = document.createElement('span');
	span2.setAttribute('class', 'labeledform');
	if(data.items.vartype == 'text') {
		var input = new dijit.form.ValidationTextBox({
			id: data.items.id,
			required: 'true',
			style: 'width: ' + data.items.width,
			value: data.items.value,
			regExp: data.items.constraints,
			invalidMessage: data.items.invalidmsg
		}, document.createElement('div'));
	}
	else if(data.items.vartype == 'selectonly') {
		var options = [];
		var i = 0;
		for(var key in data.items.constraints) {
			options[i] = {label: key, value: key};
			if(key == data.items.value)
				options[i].selected = true;
			i += 1;
		}
		var input = new dijit.form.Select({
			id: data.items.id,
			required: 'true',
			style: 'width: ' + data.items.width,
			options: options
		}, document.createElement('div'));
	}
	span2.appendChild(input.domNode);
	span.appendChild(span2);
	if(data.items.allowdelete) {
		var func = this.deleteAffiliationSetting;
		var domidbase = this.domidbase;
		var btn = new dijit.form.Button({
			id: data.items.id + 'delbtn',
			label: _('Delete'),
			onClick: function() {
				func(data.items.id, domidbase);
			}
		}, document.createElement('div'));
		span.appendChild(btn.domNode);
	}
	span.appendChild(document.createElement('br'));
	dojo.byId(this.domidbase + 'affildiv').appendChild(span);
	dijit.byId(this.domidbase + 'newval').reset();
	dojo.byId('delete' + this.domidbase + 'cont').value = data.items.deletecont;
	dojo.byId(this.domidbase + 'cont').value = data.items.savecont;
	dijit.byId(this.domidbase + 'newaffilid').removeOption({value: data.items.affilid});
	if(dijit.byId(this.domidbase + 'newaffilid').options.length == 0)
		dojo.addClass(this.domidbase + 'adddiv', 'hidden');
	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	if(keys.length == 1 && keys[0] == '')
		keys[0] = data.items.id;
	else
		keys.push(data.items.id);
	dojo.byId(this.domidbase + 'savekeys').value = keys.join(',');
}

AffilTextVariable.prototype.saveSettings = function() {
	var data = {continuation: dojo.byId(this.domidbase + 'cont').value};
	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	for(var i = 0; i < keys.length; i++) {
		if(! checkValidatedObj(keys[i])) {
			dijit.byId(keys[i]).focus();
			return;
		}
		var newval = dijit.byId(keys[i]).get('value');
		if(newval === 0)
			data[keys[i]] = 'zero';
		else
			data[keys[i]] = newval;
	}
	dijit.byId(this.domidbase + 'btn').set('disabled', true);
	RPCwrapper(data, generalSiteConfigCB, 1);
}

AffilTextVariable.prototype.deleteAffiliationSetting = function(affilid, domidbase) {
	var data = {affilid: affilid,
	            continuation: dojo.byId('delete' + domidbase + 'cont').value};
	RPCwrapper(data, generalSiteConfigCB, 1);
}

AffilTextVariable.prototype.deleteAffiliationSettingCBextra = function(data) {
	dijit.byId(data.items.delid).destroy();
	dijit.byId(data.items.delid + 'delbtn').destroy();
	dojo.destroy(data.items.delid + 'span');
	dijit.byId(this.domidbase + 'newaffilid').addOption({value: data.items.affilid, label: data.items.affil});
	dojo.removeClass(this.domidbase + 'adddiv', 'hidden');
	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	var newkeys = new Array();
	for(var i = 0; i < keys.length; i++) {
		if(keys[i] != data.items.delid)
			newkeys.push(keys[i]);
	}
	dojo.byId(this.domidbase + 'savekeys').value = newkeys.join(',');
	dojo.byId('delete' + this.domidbase + 'cont').value = data.items.delcont;
}

function affilhelpaddr() {
	AffilTextVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'affilhelpaddr';
}
affilhelpaddr.prototype = new AffilTextVariable();
var affilhelpaddr = new affilhelpaddr();

function affilwebaddr() {
	AffilTextVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'affilwebaddr';
}
affilwebaddr.prototype = new AffilTextVariable();
var affilwebaddr = new affilwebaddr();

function affilkmsserver() {
	AffilTextVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'affilkmsserver';
}
affilkmsserver.prototype = new AffilTextVariable();
var affilkmsserver = new affilkmsserver();

function affiltheme() {
	AffilTextVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'affiltheme';
}
affiltheme.prototype = new AffilTextVariable();
var affiltheme = new affiltheme();

function affilshibonly() {
	AffilTextVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'affilshibonly';
}
affilshibonly.prototype = new AffilTextVariable();
var affilshibonly = new affilshibonly();

function affilshibname() {
	AffilTextVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'affilshibname';
}
affilshibname.prototype = new AffilTextVariable();
var affilshibname = new affilshibname();

function GlobalSingleVariable() {}

GlobalSingleVariable.prototype.saveSettings = function() {
	var data = {continuation: dojo.byId(this.domidbase + 'cont').value};
	if('checked' in dijit.byId(this.domidbase)) {
		if(dijit.byId(this.domidbase).checked)
			data.newval = dijit.byId(this.domidbase).value;
		else
			data.newval = 0;
	}
	else
		data.newval = dijit.byId(this.domidbase).value;
	dijit.byId(this.domidbase + 'btn').set('disabled', true);
	RPCwrapper(data, generalSiteConfigCB, 1);
}

function userPasswordLength() {
	GlobalSingleVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'userpasswordlength';
}
userPasswordLength.prototype = new GlobalSingleVariable();
var userPasswordLength = new userPasswordLength();

function userPasswordSpecialChar() {
	GlobalSingleVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'userpasswordspchar';
}
userPasswordSpecialChar.prototype = new GlobalSingleVariable();
var userPasswordSpecialChar = new userPasswordSpecialChar();

function natPortRange() {
	GlobalSingleVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'natportrange';
}
natPortRange.prototype = new GlobalSingleVariable();
var natPortRange = new natPortRange();

function GlobalMultiVariable() {}
GlobalMultiVariable.prototype.saveSettings = function() {
	var data = {continuation: dojo.byId(this.domidbase + 'cont').value};

	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	for(var i = 0; i < keys.length; i++) {
		if('checked' in dijit.byId(keys[i])) {
			if(dijit.byId(keys[i]).checked)
				data[keys[i]] = dijit.byId(keys[i]).value;
			else
				data[keys[i]] = 0;
		}
		else {
			if(! checkValidatedObj(keys[i])) {
				dijit.byId(keys[i]).focus();
				return;
			}
			data[keys[i]] = dijit.byId(keys[i]).get('value');
		}
	}
	dijit.byId(this.domidbase + 'btn').set('disabled', true);
	RPCwrapper(data, generalSiteConfigCB, 1);
}
GlobalMultiVariable.prototype.addNewMultiVal = function() {
	var data = {continuation: dojo.byId(this.domidbase + 'addcont').value,
	            multivalid: dijit.byId(this.domidbase + 'newmultivalid').get('value'),
	            multival: dijit.byId(this.domidbase + 'newmultival').get('value')};
	dijit.byId(this.domidbase + 'addbtn').set('disabled', true);
	RPCwrapper(data, generalSiteConfigCB, 1);
}
GlobalMultiVariable.prototype.addNewMultiValCBextra = function(data) {
	var span = document.createElement('span');
	span.setAttribute('id', data.items.addid + 'wrapspan');
	var label = document.createElement('label');
	label.setAttribute('for', data.items.addid);
	label.innerHTML = data.items.addname + ': ';
	span.appendChild(label);
	var span2 = document.createElement('span');
	span2.setAttribute('class', 'labeledform');
	var text = new dijit.form.ValidationTextBox({
		id: data.items.addid,
		required: 'true',
		style: 'width: 400px;',
		value: data.items.addval,
		regExp: data.items.regexp,
		invalidMessage: data.items.invalidmsg
	}, document.createElement('div'));
	span2.appendChild(text.domNode);
	span.appendChild(span2);
	var func = this.deleteMultiVal;
	var domidbase = this.domidbase;
	var btn = new dijit.form.Button({
		id: data.items.addid + 'delbtn',
		label: _('Delete'),
		onClick: function() {
			func(data.items.delkey, domidbase);
		}
	}, document.createElement('div'));
	span.appendChild(btn.domNode);
	span.appendChild(document.createElement('br'));
	dojo.byId(this.domidbase + 'multivalspan').appendChild(span);
	dijit.byId(this.domidbase + 'newmultival').set('value', '');
	dijit.byId(this.domidbase + 'newmultivalid').removeOption({value: data.items.delkey});
	if(dijit.byId(this.domidbase + 'newmultivalid').options.length == 0)
		dojo.addClass(this.domidbase + 'multivalnewspan', 'hidden');
	dojo.byId(this.domidbase + 'addcont').value = data.items.addcont;
	dojo.byId('delete' + this.domidbase + 'cont').value = data.items.delcont;
	dojo.byId(this.domidbase + 'cont').value = data.items.savecont;
	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	if(keys[0] == '')
		keys[0] = data.items.addid;
	else
		keys.push(data.items.addid);
	dojo.byId(this.domidbase + 'savekeys').value = keys.join(',');
	dijit.byId(this.domidbase + 'addbtn').set('disabled', false);
}
GlobalMultiVariable.prototype.deleteMultiVal = function(key, domidbase) {
	var data = {key: key,
	            continuation: dojo.byId('delete' + domidbase + 'cont').value};
	RPCwrapper(data, generalSiteConfigCB, 1);
}
GlobalMultiVariable.prototype.deleteMultiValCBextra = function(data) {
	dijit.byId(data.items.delid).destroy();
	dijit.byId(data.items.delid + 'delbtn').destroy();
	dojo.destroy(data.items.delid + 'wrapspan');
	dijit.byId(this.domidbase + 'newmultivalid').addOption({value: data.items.addid, label: data.items.addname});
	var keys = dojo.byId(this.domidbase + 'savekeys').value.split(',');
	var newkeys = new Array();
	for(var i = 0; i < keys.length; i++) {
		if(keys[i] != data.items.delid)
			newkeys.push(keys[i]);
	}
	dojo.byId(this.domidbase + 'savekeys').value = newkeys.join(',');
	dojo.removeClass(this.domidbase + 'multivalnewspan', 'hidden');
	dojo.byId(this.domidbase + 'cont').value = data.items.savecont;
}
GlobalMultiVariable.prototype.saveCBextra = function(data) {
	dojo.byId(this.domidbase + 'cont').value = data.items.savecont;
}

function nfsmount() {
	GlobalMultiVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'nfsmount';
}
nfsmount.prototype = new GlobalMultiVariable();
var nfsmount = new nfsmount();

function affiliation() {
	GlobalMultiVariable.apply(this, Array.prototype.slice.call(arguments));
	this.domidbase = 'affiliation';
	this.addNewMultiVal = function() {
		var data = {continuation: dojo.byId(this.domidbase + 'addcont').value,
		            multival: dijit.byId(this.domidbase + 'newmultival').get('value')};
		dijit.byId(this.domidbase + 'addbtn').set('disabled', true);
		RPCwrapper(data, generalSiteConfigCB, 1);
	}
	this.deleteMultiVal = function(key, domidbase) {
		var affil = dijit.byId(this.domidbase + '|' + key).get('_resetValue');
		dojo.byId('delaffilkey').value = key;
		this.showDelete(affil);
	}
	this.deleteMultiValSubmit = function() {
		var data = {key: dojo.byId('delaffilkey').value,
		            continuation: dojo.byId('delete' + this.domidbase + 'cont').value};
		RPCwrapper(data, generalSiteConfigCB, 1);
		setTimeout(this.hideDelete, 300);
	}
	this.pagerefresh = function(data) {
		window.location.reload(false);
	}
	this.deleteMultiValCBextra = function(data) {
		dijit.byId(data.items.delid).destroy();
		dijit.byId(data.items.delid + 'delbtn').destroy();
		dojo.destroy(data.items.delid + 'wrapspan');
		window.location.reload(false);
	}
	this.showDelete = function(affil) {
		dojo.byId('affilconfirmname').innerHTML = affil;
		dojo.byId('siteconfigconfirmoverlay').style.display = 'block';
		dojo.byId('affiliationconfirmbox').style.display = 'block';
		var dialog = dojo.byId('affiliationconfirmbox');
		var overlay = dojo.byId('siteconfigconfirmoverlay');
		dialog.style.top = (overlay.offsetHeight/2) - (dialog.offsetHeight/2) + 'px';
		dialog.style.left = (overlay.offsetWidth/2) - (dialog.offsetWidth/2) + 'px';
	}
	this.hideDelete = function() {
		dojo.byId('siteconfigconfirmoverlay').style.display = 'none';
		dojo.byId('affiliationconfirmbox').style.display = 'none';
		dojo.byId('affilconfirmname').innerHTML = '';
	}
}
affiliation.prototype = new GlobalMultiVariable();
var affiliation = new affiliation();

function messages() {
	var items;
	var timer;
	var validatecnt;
	var invalids;
	this.init();
}
messages.prototype.init = function() {
	if(typeof dijit !== 'object' || dijit.byId('messagesselid') === undefined) {
		if('init' in messages)
			setTimeout(messages.init, 500);
		else
			setTimeout(messages.prototype.init, 500);
		return;
	}
	messages.setContents(1);
	messages.invalids = new Object();
	setTimeout(function() {
		messages.validatecnt = 1;
		messages.validatePoll();
	}, 1000);
}
messages.prototype.validateContent = function() {
	var subj = dijit.byId('messagessubject').get('value');
	if(! this.checkBalancedBrackets(subj)) {
		dojo.addClass('messagesmsg', 'cfgerror');
		dojo.removeClass('messagesmsg', 'cfgsuccess');
		dojo.byId('messagesmsg').innerHTML = _('Unmatched or empty brackets ( [ and ] ) in subject');
		return false;
	}
	var body = dijit.byId('messagesbody').get('value');
	if(! this.checkBalancedBrackets(body)) {
		dojo.addClass('messagesmsg', 'cfgerror');
		dojo.removeClass('messagesmsg', 'cfgsuccess');
		dojo.byId('messagesmsg').innerHTML = _('Unmatched or empty brackets ( [ and ] ) in message');
		return false;
	}
	var shortmsg = dijit.byId('messagesshortmsg').get('value');
	if(! this.checkBalancedBrackets(shortmsg)) {
		dojo.addClass('messagesmsg', 'cfgerror');
		dojo.removeClass('messagesmsg', 'cfgsuccess');
		dojo.byId('messagesmsg').innerHTML = _('Unmatched or empty brackets ( [ and ] ) in short message');
		return false;
	}
	return true;
}
messages.prototype.checkBalancedBrackets = function(string) {
	var len = string.length;
	var inBracket = 0;
	var hasContent = 0;
	for(var i = 0; i < len; i++) {
		var ch = string.charAt(i);
		switch(ch) {
			case '[':
				if(inBracket)
					return false;
				inBracket = 1;
				hasContent = 0;
				break;
			case ']':
				if(! hasContent)
					return false;
				inBracket = 0;
				hasContent = 0;
				break;
			default:
				if(inBracket)
					hasContent = 1;
		}
	}
	if(inBracket)
		return false;
	return true;
}
messages.prototype.setContents = function(clearmsg) {
	if(messages.items === undefined) {
		messages.items = JSON.parse(document.getElementById('messagesdata').innerHTML);
	}
	var msgkey = dijit.byId('messagesselid').get('value');
	var msgkeyparts = msgkey.split('|');
	if(msgkeyparts[0] == 'adminmessage') {
		dijit.byId('messagesaffilid').set('displayedValue', 'Global');
		dijit.byId('messagesaffilid').set('disabled', true);
	}
	else {
		dijit.byId('messagesaffilid').set('disabled', false);
	}
	var affil = dijit.byId('messagesaffilid').get('displayedValue');
	var key = msgkey + '|' + affil;
	if(affil == 'Global' || ! (affil in messages.items[msgkey])) {
		// use default
		dijit.byId('messagesdelbtn').set('disabled', true);
		var item = messages.items[msgkey]['Global'];
		if(affil == 'Global') {
			dojo.addClass('defaultmessagesdiv', 'hidden');
		}
		else {
			dojo.removeClass('defaultmessagesdiv', 'hidden');
		}
	}
	else {
		// use affil specific msg
		dijit.byId('messagesdelbtn').set('disabled', false);
		var item = messages.items[msgkey][affil];
		dojo.addClass('defaultmessagesdiv', 'hidden');
	}
	var affiltype;
	if(affil == 'Global') {
		affiltype = 'Default message for any affiliation';
	}
	else {
		affiltype = 'Message for ' + affil + ' affiliation';
	}
	dojo.byId('messagesaffil').innerHTML = affiltype;
	dijit.byId('messagessubject').set('value', item['subject']);
	dijit.byId('messagesbody').set('value', item['message']);
	if('short_message' in item)
		dijit.byId('messagesshortmsg').set('value', item['short_message']);
	else
		dijit.byId('messagesshortmsg').set('value', '');
	if(clearmsg) {
		dojo.removeClass('messagesmsg', 'cfgerror');
		dojo.removeClass('messagesmsg', 'cfgsuccess');
		dojo.byId('messagesmsg').innerHTML = '';
	}
}
messages.prototype.confirmdeletemsg = function() {
	var affil = dijit.byId('messagesaffilid').get('displayedValue');
	if(affil == 'Global')
		return;
	var key = dijit.byId('messagesselid').get('value');
	var keyparts = key.split('|');
	dojo.byId('deleteMsgAffil').innerHTML = affil;
	dojo.byId('deleteMsgCategory').innerHTML = keyparts[0];
	dojo.byId('deleteMsgType').innerHTML = keyparts[1];
	dijit.byId('deleteMessageDlg').show();
}
messages.prototype.deletemsg = function() {
	dijit.byId('messagesdelbtn').set('disabled', true);
	dijit.byId('messagesselid').set('disabled', true);
	dijit.byId('messagesaffilid').set('disabled', true);
	var data = {key: dijit.byId('messagesselid').get('value'),
	            affilid: dijit.byId('messagesaffilid').get('value'),
	            continuation: dojo.byId('deletemessagescont').value};
	RPCwrapper(data, generalSiteConfigCB, 1);
}
messages.prototype.deleteMessagesCBextra = function(data) {
	dijit.byId('messagesselid').set('disabled', false);
	dijit.byId('messagesaffilid').set('disabled', false);
	delete messages.items[data.items.key][data.items.affil];
	dijit.byId('deleteMessageDlg').hide();
	messages.setContents(0);
}
messages.prototype.savemsg = function() {
	if(! this.validateContent()) {
		return;
	}
	var invalidkey = dijit.byId('messagesselid').get('value') + '|' + dijit.byId('messagesaffilid').get('displayedValue');
	if('invalidkey' in this.invalids) {
		this.invalids.splice(invalidkey, 1);
		this.updateInvalidContent();
	}
	dijit.byId('messagessavebtn').set('disabled', true);
	dijit.byId('messagesselid').set('disabled', true);
	dijit.byId('messagesaffilid').set('disabled', true);
	var data = {key: dijit.byId('messagesselid').get('value'),
	            affilid: dijit.byId('messagesaffilid').get('value'), 
	            subject: dijit.byId('messagessubject').get('value'), 
	            body:  dijit.byId('messagesbody').get('value'),
	            shortmsg:  dijit.byId('messagesshortmsg').get('value'),
	            continuation: dojo.byId('savemessagescont').value};
	RPCwrapper(data, generalSiteConfigCB, 1);
}
messages.prototype.saveMessagesCBextra = function(data) {
	dijit.byId('messagesselid').set('disabled', false);
	dijit.byId('messagesaffilid').set('disabled', false);
	messages.items[data.items.key][data.items.affil] = new Object();
	messages.items[data.items.key][data.items.affil]['name'] = data.items.name;
	messages.items[data.items.key][data.items.affil]['subject'] = data.items.subject;
	messages.items[data.items.key][data.items.affil]['message'] = data.items.body;
	messages.items[data.items.key][data.items.affil]['short_message'] = data.items.shortmsg;
	dijit.byId('deleteMessageDlg').hide();
	messages.setContents(0);
	messages.startValidatePoll();
}
messages.prototype.validatePoll = function() {
	var data = {continuation: dojo.byId('validatemessagespollcont').value};
	RPCwrapper(data, this.validatePollCB, 1);
	this.validatecnt--;
}
messages.prototype.validatePollCB = function(data, ioArgs) {
	if(data.items.status == 'invalid') {
		messages.invalids = data.items.values;
		messages.updateInvalidContent();
	}
	else {
		messages.invalids = new Object();
		dijit.byId('invalidmsgfieldspane').hide();
	}
	clearTimeout(this.timer);
	if(messages.validatecnt <= 0)
		return;
	messages.timer = setTimeout(function() {
		messages.validatePoll();
	}, 1000);
}
messages.prototype.startValidatePoll = function() {
	this.validatecnt = 60;
	this.validatePoll();
}
messages.prototype.stopValidatePoll = function() {
	clearTimeout(messages.timer);
}
messages.prototype.updateInvalidContent = function() {
	var msg = '';
	for(key in this.invalids) {
		var parts = key.split('|');
		var item = this.invalids[key];
		if(parts.length == 2) {
			msg += 'Message: ' + parts[0] + ' -&gt; ' + parts[1] + '<br>';
		}
		else {
			msg += 'Affiliation: ' + parts[2] + '<br>';
			msg += 'Message: ' + parts[0] + ' -&gt; ' + parts[1] + '<br>';
		}

		for(key in item) {
			if(item === undefined)
				continue;
			msg += key + ":<br>";
			for(var i = 0; i < item[key].length; i++) {
				msg += '&nbsp;&nbsp;' + item[key][i] + '<br>';
			}
		}
		msg += '<br>';
	}
	dojo.byId('invalidmsgfieldcontent').innerHTML = msg;
	if(dijit.byId('invalidmsgfieldspane').domNode.style.visibility != 'visible')
		dijit.byId('invalidmsgfieldspane').show();
}
var messages = new messages();
