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
var toggledRows = new Array();
var toggledCols = new Array();
var mouseX = 0;
var mouseY = 0;
var passvar = 0;

var browser = "";
function setBrowser() {
	browser = navigator.appName;
	if(navigator.appName == 'Netscape') {
		var regex = new RegExp('Safari');
		if(navigator.appVersion.match(regex)) {
			browser = 'Safari';
		}
	}
	else if(navigator.appName == 'Microsoft Internet Explorer') {
		browser = 'IE';
	}
}
setBrowser();

function init() {
	if(typeof(dojo) == 'undefined') {
		setTimeout(init, 250);
		return;
	}
	if(typeof(tzoffset) != undefined && tzoffset == 'unset') {
		var now = new Date();
		var data = {mode: 'AJsetTZoffset',
		            offset: now.getTimezoneOffset()};
		RPCwrapper(data, null, 0);
	}
}

function _(str) {
	if(typeof usenls == 'undefined' ||
	   typeof nlsmessages == 'undefined' ||
	   ! (str in nlsmessages) ||
	   nlsmessages[str] == '')
		return str;
	return nlsmessages[str];
}

Date.prototype.getDayName = function() {
	return [_('Sunday'), _('Monday'), _('Tuesday'), _('Wednesday'), _('Thursday'), _('Friday'), _('Saturday')][this.getDay()];
}

function testJS() {
	if(document.getElementById('testjavascript'))
		document.getElementById('testjavascript').value = '1';
}

function RPCwrapper(data, CB, dojson, timeout) {
	if(typeof timeout === 'undefined')
		timeout = 15000;
	if(dojson) {
		return dojo.xhrPost({
			url: 'index.php',
			load: function(data, ioArgs) {returnCheck(CB, data, ioArgs);},
			//load: CB,
			//handleAs: "json",
			error: errorHandler,
			content: data,
			timeout: timeout
		});
	}
	else {
		return dojo.xhrPost({
			url: 'index.php',
			load: CB,
			error: errorHandler,
			content: data,
			timeout: timeout
		});
	}
}

function returnCheck(CB, data, ioArgs) {
	try {
		var json = dojo.fromJson(data);
	}
	catch(error) {
		if((! data.match(/-- continuationserror --/)) &&
		   (data.match(/<html/) || ! error.message.match(/syntax error/))) {
			alert(_('Error encountered:') + " " + _('Please try again later'));
			return;
		}
		else if(data.match(/-- continuationserror --/)) {
			var i = data.indexOf('<div id="continuationserrormessage');
			i = data.indexOf('>', i) + 2;
			var j = data.indexOf('</div>', i);
			data = data.slice(i, j);
		}
		var div = document.createElement('div');
		div.innerHTML = data;
		var msg = div.textContent || div.innerText || "";
		alert(_('Error encountered:') + '\n\n' + msg);
		return;
	}
	CB(json, ioArgs);
}

Array.prototype.inArray = function(data) {
	for(var i = 0; i < this.length; i++) {
		if(this[i] === data) {
			return true;
		}
	}
	return false;
}

Array.prototype.search = function(data) {
	for (var i = 0; i < this.length; i++) {
		if(this[i] === data) {
			return i;
		}
	}
	return false;
}

function generalCB(data, ioArgs) {
	unsetLoading();
	var regex = new RegExp('^<!DOCTYPE html');
	if(data.match(regex)) {
		var mesg = 'A minor error has occurred. It is probably safe to ' +
		           'ignore. However, if you keep getting this message and ' +
		           'are unable to use VCL, you may contact the ' +
		           'administrators of this site for further assistance.';
		alert(mesg);
		var d = {mode: 'errorrpt',
		         data: data};
		RPCwrapper(d, function(data, ioArgs) {});
		return;
	}
	eval(data);
}

var errorHandler = function(error, ioArgs) {
	/*if(error.name == 'cancel')
		return;
	alert('AJAX Error: ' + error.message + '\nLine ' + error.lineNumber + ' in ' + error.fileName);*/
	//console.log(error);
}

function errorHandler(data, ioArgs) {
	alert('Error encountered while processing AJAX callback');
}

function AJdojoCreate(objid) {
	if(dojo.byId(objid)) {
		dojo.parser.parse(document.getElementById(objid));
	}
}

function setLoading() {
   document.body.style.cursor = 'wait';
	if(dijit.byId('workingDialog'))
		dijit.byId('workingDialog').show();
}

function unsetLoading() {
	document.body.style.cursor = 'default';
	if(dijit.byId('workingDialog'))
		dijit.byId('workingDialog').hide();
}

function updateMouseXY(e) {
	if(e) {
		mouseX = e.pageX;
		mouseY = e.pageY;
	}
	else if(event) {
		mouseX = event.clientX + document.documentElement.scrollLeft;
		mouseY = event.clientY + document.documentElement.scrollTop;
	}
}

function findPosX(obj) {
	var curleft = 0;
	if(obj.offsetParent)
		while(1) {
			curleft += obj.offsetLeft;
			 if(!obj.offsetParent)
				break;
			obj = obj.offsetParent;
		}
	else if(obj.x)
		curleft += obj.x;
	return curleft;
}

function findPosY(obj) {
	var curtop = 0;
	if(obj.offsetParent)
		while(1) {
			curtop += obj.offsetTop;
			if(!obj.offsetParent)
				break;
			obj = obj.offsetParent;
		}
	else if(obj.y)
		curtop += obj.y;
	return curtop;
}

function showScriptOnly() {
	if(!document.styleSheets)
		return;
	var cssobj = new Array();
	if(document.styleSheets[0].cssRules)  // Standards Compliant
		cssobj = document.styleSheets[0].cssRules;
	else
		cssobj = document.styleSheets[0].rules;  // IE 
	var stop = 0;
	for(var i = 0; i < cssobj.length; i++) {
		if(cssobj[i].selectorText) {
			if(cssobj[i].selectorText.toLowerCase() == '.scriptonly') {
				//cssobj[i].style.display = "inline";
				cssobj[i].style.cssText = "display: inline;";
				stop++;
			}
			if(cssobj[i].selectorText.toLowerCase() == '.scriptoff') {
				cssobj[i].style.cssText = "display: none;";
				stop++;
			}
			if(stop > 1)
				return;
		}
	}
}

function showGroupInfo(data, ioArgs) {
   var members = data.items.members;
   var mx = data.items.x;
   var my = data.items.y;
   var text = "";
   for(var i = 0; i < members.length; i++) {
      text = text + members[i] + '<br>';
   }
   var obj = document.getElementById('content');
   var x = findPosX(obj);
   var y = findPosY(obj);
   obj = document.getElementById('listitems');
   obj.innerHTML = text;
   obj.style.left = mx - x - obj.clientWidth;
   obj.style.top = my - y - obj.clientWidth;
   obj.style.zIndex = 10;
}

function checkNewLocalPassword() {
	var pwd1 = document.getElementById('newpassword');
	var pwd2 = document.getElementById('confirmpassword');
	var stat = document.getElementById('pwdstatus');
	if(pwd1.value == "" && pwd2.value == "") {
		stat.innerHTML = '';
	}
	else if(pwd1.value == pwd2.value) {
		stat.innerHTML = '<font color="#008000">' + _('match') + '</font>';
	}
	else {
		stat.innerHTML = '<font color="red">' + _('no match') + '</font>';
	}
}

function sortSelect(selobj) {
	var values = new Array();
	var texts = new Array();
	for(var i = 0; i < selobj.options.length; i++) {
		values[selobj.options[i].text] = selobj.options[i].value;
		texts[i] = selobj.options[i].text;
	}
	texts.sort(ignoreCaseSort);
	for(var i = 0; i < selobj.options.length; i++) {
		selobj.options[i].text = texts[i];
		selobj.options[i].value = values[texts[i]];
	}
}

function ignoreCaseSort(a, b) {
	a = a.toLowerCase();
	b = b.toLowerCase();
	if(a > b)
		return 1;
	if(a < b)
		return -1;
	return 0;
}

function getSelectText(objid) {
	if(dijit.byId(objid))
		return dijit.byId(objid).textbox.value;
	var obj = dojo.byId(objid);
	return obj.options[obj.selectedIndex].text;
}

function getSelectValue(objid) {
	if(dijit.byId(objid))
		return dijit.byId(objid).value;
	return dojo.byId(objid).value;
}

function get12from24(hour) {
	if(hour == 0)
		return {hour: 12, meridian: 'am'};
	if(hour < 12)
		return {hour: hour, meridian: 'am'};
	if(hour == 12)
		return {hour: hour, meridian: 'pm'};
	return {hour: hour - 12, meridian: 'pm'};
}

function hideDijitButton(id) {
	dojo.style(dijit.byId(id).domNode, {
		display: 'none'
	});
}

function showDijitButton(id) {
	dojo.style(dijit.byId(id).domNode, {
		display: 'inline'
	});
}

function recenterDijitDialog(id) {
	if(dijit.byId(id)._relativePosition)
		delete dijit.byId(id)._relativePosition;
	dijit.byId(id)._position();
}

function resizeRecenterDijitDialog(id) {
	// taken from Dialog.js _size function
	/*var d = dijit.byId(id);
	var mb = dojo._getMarginSize(d.domNode);
	var viewport = dojo.window.getBox();
	if(mb.h >= viewport.h) {
		// Reduce size of dialog contents so that dialog fits in viewport
		var h = Math.min(mb.h, Math.floor(viewport.h * 0.75));
		dojo.style(d.containerNode, {
			height: h + "px",
			overflow: "auto",
			position: "relative"	// workaround IE bug moving scrollbar or dragging dialog
		});
	}*/
	dijit.byId(id)._size();
	recenterDijitDialog(id);
}

function checkValidatedObj(objid, errobj) {
	if(dijit.byId(objid) && ! dijit.byId(objid).get('disabled') &&
	   'isValid' in dijit.byId(objid) && ! dijit.byId(objid).isValid()) {
		dijit.byId(objid)._hasBeenBlurred = true;
		dijit.byId(objid).validate();
		//dijit.byId(objid).focus();
		if(typeof errobj == 'string') {
			if(dijit.byId(errobj))
				dijit.byId(errobj).set('value', '');
			else if(dojo.byId(errobj))
				dojo.byId(errobj).innerHTML = '';
			else
				errobj = null;
		}
		if(errobj !== null && typeof errobj != 'undefined')
			errobj.innerHTML = '';
		return 0;
	}
	return 1;
}

function resetSelect(objid) {
	if(dijit.byId(objid)) {
		dijit.byId(objid).reset();
		return;
	}
	var obj = dojo.byId(objid);
	var found = 0;
	for(var i = 0; i < obj.options.length; i++) {
		if(obj.options[i].defaultSelected) {
			obj.selectedIndex = i;
			found = 1;
		}
	}
	if(! found)
		obj.selectedIndex = 0;
}
