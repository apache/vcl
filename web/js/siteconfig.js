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
	else if(data.items.status == 'failed') {
		dojo.removeClass(data.items.msgid, 'cfgsuccess');
		dojo.addClass(data.items.msgid, 'cfgerror');
		dojo.byId(data.items.msgid).innerHTML = data.items.errmsg;
		if('btn' in data.items)
			dijit.byId(data.items.btn).set('disabled', false);
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
		label: i('Delete'),
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
