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

function testJS() {
	if(document.getElementById('testjavascript'))
		document.getElementById('testjavascript').value = '1';
}

function fixButtons2() {
	var btns = new Array('addNodeBtn',
	                     'deleteNodeBtn',
	                     'userPrivBtn',
	                     'addUserBtn',
	                     'groupPrivBtn',
	                     'addGroupBtn',
	                     'resourcePrivBtn',
	                     'addResourceBtn',
	                     'submitAddUserBtn',
	                     'cancelAddUserBtn',
	                     'submitAddGroupBtn',
	                     'cancelAddGroupBtn',
	                     'submitAddNodeBtn',
	                     'cancelAddNodeBtn',
	                     'submitDeleteNodeBtn',
	                     'cancelDeleteNodeBtn'
								);
	var obj;
	for(var i = 0; i < btns.length; i++) {
		obj = dojo.widget.byId(btns[i]);
		if(obj) {
			obj.domNode.style.zoom = 1;
			obj.domNode.style.zoom = "";
		}
	}
}

function initPrivTree() {
	var obj = dojo.widget.byId('privTree');
	if(obj) {
		dojo.event.topic.subscribe("nodeSelected",
			function(message) {nodeSelect(message.node);}
		);
		dojo.event.topic.subscribe(obj.eventNames['expand'],
		                          treeListener, 'nodeExpand');
		var selectedNodeId = dojo.io.cookie.get('VCLACTIVENODE');
		var selectedNode = dojo.widget.byId(selectedNodeId);
		setSelectedPrivNode(selectedNodeId);
		var selector = dojo.widget.byId('treeSelector');
		dojo.event.connect('before', selector, 'onCollapse', treeListener, 'nodeCollapse');
	}
}

function checkAllCompUtils() {
	var count = 0;
	var obj;
	while(obj = document.getElementById('comp' + count)) {
		obj.checked = true;
		document.getElementById('compid' + count).className = 'hlrow';
		toggledRows['compid' + count] = 1;
		count++;
	}
	return true;
}

function uncheckAllCompUtils() {
	var count = 0;
	var obj;
	while(obj = document.getElementById('comp' + count)) {
		obj.checked = false;
		document.getElementById('compid' + count).className = '';
		toggledRows['compid' + count] = 0;
		count++;
	}
	return true;
}

function reloadComputerSubmit() {
	var formobj = document.getElementById('utilform');
	var obj = document.getElementById('continuation');
	var contobj = document.getElementById('reloadcont');
	obj.value = contobj.value;
	formobj.submit();
}

function compStateChangeSubmit() {
	var formobj = document.getElementById('utilform');
	var obj = document.getElementById('continuation');
	var contobj = document.getElementById('statecont');
	obj.value = contobj.value;
	formobj.submit();
}

function compScheduleChangeSubmit() {
	var formobj = document.getElementById('utilform');
	var obj = document.getElementById('continuation');
	var contobj = document.getElementById('schcont');
	obj.value = contobj.value;
	formobj.submit();
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

function checkSelectParent(message) {
	var node = message.source;
	var selector = dojo.widget.byId('treeSelector');
	if(! selector.selectedNode)
		return;
	var parent = selector.selectedNode.parent;
	while(parent !== node && parent.isTreeNode) {
		parent = parent.parent;
	}
	if(parent === node)
		selector.select(message);
}

function hidePrivileges() {
   //dojo.lfx.fadeHide(dojo.byId('nodePerms'), 200).play();
}

function showPrivileges() {
   //dojo.lfx.fadeShow(dojo.byId('nodePerms'), 300).play();
}

function showAddNodePane() {
	showWindow('addNodePane');
}

function showDeleteNodeDialog() {
	dojo.widget.byId('deleteDialog').show();
}

function showAddUserPane() {
	showWindow('addUserPane');
}

function showAddUserGroupPane() {
	showWindow('addUserGroupPane');
}

function showAddResourceGroupPane() {
	showWindow('addResourceGroupPane');
}

function showResStatusPane(reqid) {
	var currdetailid = dojo.byId('detailreqid').value;
	if(! dojo.widget.byId('resStatusPane')) {
		window.location.reload();
		return;
	}
	var windowstate = dojo.widget.byId('resStatusPane').windowState;
	if(currdetailid != reqid) {
		dojo.byId('detailreqid').value = reqid;
		dojo.byId('resStatusText').innerHTML = 'Loading...';
	}
	if( windowstate == 'minimized' || currdetailid != reqid) {
		if(typeof(refresh_timer) != "undefined")
			clearTimeout(refresh_timer);
		if(windowstate == 'minimized')
			showWindow('resStatusPane');
		resRefresh();
	}
}

function hideResStatusPane() {
	dojo.widget.byId('resStatusPane').minimizeWindow();
}

/*function showWindow(name, offset, leftdist) {
	var obj = dojo.widget.byId(name);
	obj[name].style.position = 'absolute';
	if(leftdist == null)
		obj[name].style.left = 30;
	else
		obj[name].style.left = leftdist;
	obj.restoreWindow();
	//var offset = dojo.byId('offset').value;
	obj[name].style.top = mouseY - offset;
}*/

function showWindow(name) {
	var x = mouseX;
	var y = mouseY;
	var obj = dojo.widget.byId(name);
	obj.domNode.style.position = 'absolute';
	obj.domNode.style.left = x + 'px';
	var newtop = y - (parseInt(obj.domNode.style.height) / 2);
	if(newtop < 0)
		newtop = 0;
	obj.domNode.style.top = newtop + 'px';
	obj.restoreWindow();
}

var genericCB = function(type, data, evt) {
	unsetLoading();
	var regex = new RegExp('^<!DOCTYPE html');
	if(data.match(regex)) {
		var mesg = 'A minor error has occurred. It is probably safe to ' +
		           'ignore. However, if you keep getting this message and ' +
		           'are unable to use VCL, you may contact vcl_help@ncsu.edu ' +
		           'for further assistance.';
		alert(mesg);
		var d = {mode: 'errorrpt',
		         data: data};
		RPCwrapper(d, function(type, data, evt) {});
		return;
	}
	eval(data);
}

var errorHandler = function(type, error, data) {
	alert('error occurred' + error.message + data.responseText);
}

function nodeSelect(node) {
   var nodeid = node.widgetId;
   var nodename = node.title;
   dojo.byId('addPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
   dojo.byId('addGroupPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
   dojo.byId('addResourceGroupPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
   dojo.byId('addChildNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
   dojo.byId('deleteNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	setLoading();
   if(dojo.byId('activeNodeAdd'))
      dojo.byId('activeNodeAdd').value = nodeid;
   if(dojo.byId('activeNodeDel'))
      dojo.byId('activeNodeDel').value = nodeid;
   hidePrivileges();
   dojo.io.cookie.set('VCLACTIVENODE', nodeid, 365, '/', cookiedomain);
	var obj = document.getElementById('nodecont');
	var data = {continuation: obj.value,
	            node: nodeid};
	RPCwrapper(data, genericCB);
}

function refreshPerms() {
   setLoading();
	var selector = dojo.widget.byId('treeSelector');
	var nodeid = selector.selectedNode.widgetId;
	dojo.widget.byId('addUserPane').minimizeWindow();
   hidePrivileges();
	var obj = document.getElementById('nodecont');
	var data = {continuation: obj.value,
	            node: nodeid};
	RPCwrapper(data, genericCB);
}

function submitAddUser() {
	dojo.byId('addUserPrivStatus').innerHTML = '';
	var obj = dojo.byId('newuser');
	var userid = obj.value;
	if(! userid.length)
		return;
	var perms = new Array();
	obj = dojo.widget.byId('blockchk');
	if(obj.checked)
		perms.push('block');
	for(var i = 0; obj = dojo.widget.byId('userck0:' + i); i++) {
		if(obj.checked)
			perms.push(obj.name);
	}
	var perms2 = perms.join(':', perms);
	var selector = dojo.widget.byId('treeSelector');
	var contid = dojo.byId('addusercont').value;
	var data = {continuation: contid,
	            perms: perms2,
	            newuser: userid,
	            activeNode: selector.selectedNode.widgetId};
   setLoading();
	RPCwrapper(data, genericCB);
}

function addUserPaneHide() {
	dojo.byId('addUserPrivStatus').innerHTML = '';
	dojo.byId('newuser').value = '';
	dojo.widget.byId('addUserPane').minimizeWindow();
	var obj = dojo.widget.byId('blockchk');
	if(obj.checked) {
		obj.checked = false;
		obj._setInfo();
	}
	for(var i = 0; obj = dojo.widget.byId('userck0:' + i); i++) {
		if(obj.checked) {
			obj.checked = false;
			obj._setInfo();
		}
	}
}

function submitAddUserGroup() {
	dojo.byId('addUserGroupPrivStatus').innerHTML = '';
	var obj = dojo.byId('newgroupid');
	var groupid = obj.value;
	if(! groupid.length)
		return;
	var perms = new Array();
	obj = dojo.widget.byId('blockgrpchk');
	if(obj.checked)
		perms.push('block');
	for(var i = 0; obj = dojo.widget.byId('usergrpck0:' + i); i++) {
		if(obj.checked)
			perms.push(obj.name);
	}
	var perms2 = perms.join(':', perms);
	var selector = dojo.widget.byId('treeSelector');
	var contid = dojo.byId('addusergroupcont').value;
	var data = {continuation: contid,
	            perms: perms2,
	            newgroupid: groupid,
	            activeNode: selector.selectedNode.widgetId};
   setLoading();
	RPCwrapper(data, genericCB);
}

function addUserGroupPaneHide() {
	dojo.byId('addUserGroupPrivStatus').innerHTML = '';
	dojo.byId('newgroupid').value = '';
	dojo.widget.byId('addUserGroupPane').minimizeWindow();
	var obj = dojo.widget.byId('blockgrpchk');
	if(obj.checked) {
		obj.checked = false;
		obj._setInfo();
	}
	for(var i = 0; obj = dojo.widget.byId('usergrpck0:' + i); i++) {
		if(obj.checked) {
			obj.checked = false;
			obj._setInfo();
		}
	}
}

function privChange(checked, row, col, type) {
	var objname = 'ck' + row + ':' + col;
	var obj = dojo.widget.byId(objname);
	if(obj.disabled)
		return;
	var nameArr = obj.name.split('[');
	nameArr = nameArr[1].split(']');
	nameArr = nameArr[0].split(':');
	if(type == 1)
		var contid = dojo.byId('changeuserprivcont').value;
	else if(type == 2)
		var contid = dojo.byId('changeusergroupprivcont').value;
	else if(type == 3)
		var contid = dojo.byId('changeresourceprivcont').value;
	var selector = dojo.widget.byId('treeSelector');
	var data = {continuation: contid,
	            activeNode: selector.selectedNode.widgetId,
	            item: nameArr[0],
	            priv: nameArr[1],
	            value: checked};
	setLoading();
	RPCwrapper(data, genericCB);
}

function submitUserPrivChanges() {
	var allusers = dojo.byId('allusers').value;
	var selector = dojo.widget.byId('treeSelector');
	var contid = dojo.byId('changeuserprivcont').value;
	var data = {continuation: contid,
	            activeNode: selector.selectedNode.widgetId,
	            allusers: allusers};
	var obj;
	var name;
	var nameArr;
	obj = dojo.byId('lastUserNum');
	if(obj) {
		var lastid = obj.innerHTML;
		for(var j = 0; j <= lastid; j++) {
			obj = dojo.byId('ck' + j + ':block');
			if(obj.checked) {
				nameArr = obj.name.split('[');
				nameArr = nameArr[1].split(']');
				data["privrow[" + nameArr[0] + "]"] = 1;
			}
			for(var i = 0; obj = dojo.byId('ck' + j + ':' + i); i++) {
				if(obj.checked) {
					nameArr = obj.name.split('[');
					nameArr = nameArr[1].split(']');
					data["privrow[" + nameArr[0] + "]"] = 1;
				}
			}
		}
		setLoading();
		RPCwrapper(data, genericCB);
	}
}

function submitUserGroupPrivChanges() {
	var allgroups = dojo.byId('allgroups').value;
	var selector = dojo.widget.byId('treeSelector');
	var contid = dojo.byId('changeusergroupprivscont').value;
	var data = {continuation: contid,
	            activeNode: selector.selectedNode.widgetId,
	            allgroups: allgroups};
	var obj;
	var obj2;
	var name;
	var nameArr;
	obj = dojo.byId('firstUserGroupNum');
	obj2 = dojo.byId('lastUserGroupNum');
	if(obj) {
		var firstid = obj.innerHTML;
		var lastid = obj2.innerHTML;
		for(var j = firstid; j <= lastid; j++) {
			obj = dojo.byId('ck' + j + ':block');
			if(obj.checked) {
				nameArr = obj.name.split('[');
				nameArr = nameArr[1].split(']');
				data["privrow[" + nameArr[0] + "]"] = 1;
			}
			for(var i = 0; obj = dojo.byId('ck' + j + ':' + i); i++) {
				if(obj.checked) {
					nameArr = obj.name.split('[');
					nameArr = nameArr[1].split(']');
					data["privrow[" + nameArr[0] + "]"] = 1;
				}
			}
		}
		setLoading();
		RPCwrapper(data, genericCB);
	}
}

function submitResourceGroupPrivChanges() {
	// FIXME - this needs to be replaced by using ajax to submit changes
	//    as checkboxes are clicked
}

function submitAddResourceGroup() {
	dojo.byId('addResourceGroupPrivStatus').innerHTML = '';
	var obj = dojo.byId('newresourcegroupid');
	var groupid = obj.value;
	if(! groupid.length)
		return;
	var perms = new Array();
	obj = dojo.widget.byId('blockresgrpck');
	if(obj.checked)
		perms.push('block');
	obj = dojo.widget.byId('resgrpck0:0');
	if(obj.checked)
		perms.push('cascade');
	for(var i = 1; obj = dojo.widget.byId('resgrpck0:' + i); i++) {
		if(obj.checked)
			perms.push(obj.name);
	}
	var perms2 = perms.join(':', perms);
	var selector = dojo.widget.byId('treeSelector');
	var contid = dojo.byId('addresourcegroupcont').value;
	var data = {continuation: contid,
	            perms: perms2,
	            newgroupid: groupid,
	            activeNode: selector.selectedNode.widgetId};
   setLoading();
	RPCwrapper(data, genericCB);
}

function addResourceGroupPaneHide() {
	dojo.byId('addResourceGroupPrivStatus').innerHTML = '';
	dojo.byId('newresourcegroupid').value = '';
	dojo.widget.byId('addResourceGroupPane').minimizeWindow();
	var obj = dojo.widget.byId('blockresgrpck');
	if(obj.checked) {
		obj.checked = false;
		obj._setInfo();
	}
	for(var i = 0; obj = dojo.widget.byId('resgrpck0:' + i); i++) {
		if(obj.checked) {
			obj.checked = false;
			obj._setInfo();
		}
	}
}

function AJdojoCreate(objid) {
	if(dojo.byId(objid)) {
		var parseObj = new dojo.xml.Parse();
		var newObjs = parseObj.parseElement(dojo.byId(objid), null, true);
		dojo.widget.getParser().createComponents(newObjs);
	}
}

function changeCascadedRights(checked, row, count, fromclick, type) {
	var i;
	var objname;
	var color;
	var value;
	var obj;
	var obj2;
	var namearr;
	for(i = 1; i < count; i++) {
		objname = "ck" + row + ":" + i;
		obj = dojo.widget.byId(objname);
		if(! obj)
			continue;
		if(checked) {
			value = obj.value;
			if(value != 'single') {
				objname = "cell" + row + ":" + i;
				obj2 = dojo.byId(objname);
				if(! obj2)
					continue;
				obj2.bgColor = '#FFFFFF';
				if(value == 'cascade') {
					objname = "ck" + row + ":" + i;
					obj = dojo.widget.byId(objname)
					obj.checked = false;
					obj._setInfo();
				}
			}
		}
		else {
			value = obj.value;
			if(value == 'single') {
				obj.checked = true;
				obj._setInfo();
			}
			else if(value == 'cascadesingle' || value == 'cascade') {
				obj.checked = true;
				obj._setInfo();
				objname = "cell" + row + ":" + i;
				obj2 = dojo.byId(objname);
				if(! obj2)
					continue;
				obj2.bgColor = '#008000';
			}
		}
	}
	if(fromclick)
		privChange(checked, row, 'block', type);
}

function nodeCheck(checked, row, col, type) {
	var objname;
	var color;
	var obj;
	var nameArr;
	objname = "cell" + row + ":" + col;
	color = document.getElementById(objname).bgColor;
	if(color == '#008000') {
		objname = "ck" + row + ":" + col;
		obj = dojo.widget.byId(objname);
		obj.checked = true;
		obj._setInfo();
	}
	else {
		privChange(checked, row, col, type);
	}
}

function submitAddChildNode() {
	dojo.byId('addChildNodeStatus').innerHTML = '';
	var obj = dojo.byId('childNodeName');
	var newnode = obj.value;
	if(! newnode.length)
		return;
	var selector = dojo.widget.byId('treeSelector');
	var contid = dojo.byId('addchildcont').value;
	var data = {continuation: contid,
	            newnode: newnode,
	            activeNode: selector.selectedNode.widgetId};
   setLoading();
	RPCwrapper(data, genericCB);
}

function deleteNode() {
	var selector = dojo.widget.byId('treeSelector');
	var contid = dojo.byId('delchildcont').value;
	var data = {continuation: contid,
	            activeNode: selector.selectedNode.widgetId};
	dojo.widget.byId('deleteDialog').hide();
   setLoading();
	RPCwrapper(data, genericCB);
}

function addNodePaneHide() {
	dojo.byId('addChildNodeStatus').innerHTML = '';
	dojo.byId('childNodeName').value = '';
	dojo.widget.byId('addNodePane').minimizeWindow();
}

function addChildNode(name, id) {
	var selector = dojo.widget.byId('treeSelector');
	var selectedNode = selector.selectedNode;
	var newnode = dojo.widget.createWidget("TreeNode", {title: name, widgetId: id});
	selectedNode.addChild(newnode);
	addNodePaneHide();
}

function setLoading() {
   document.body.style.cursor = 'wait';
	if(dojo.widget.byId('workingDialog'))
		dojo.widget.byId('workingDialog').show();
}

function unsetLoading() {
	document.body.style.cursor = 'default';
	if(dojo.widget.byId('workingDialog'))
		dojo.widget.byId('workingDialog').hide();
}

function setSelectedPrivNode(nodeid) {
	var selectedNode = dojo.widget.byId(nodeid);
	if(! selectedNode)
		selectedNode = dojo.widget.byId('3');
	selectedNode.markSelected();
	var selector = dojo.widget.byId('treeSelector');
	selector.selectedNode = selectedNode;
	var nodename = selectedNode.title;
	dojo.byId('addPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('addChildNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('deleteNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
   dojo.io.cookie.set('VCLACTIVENODE', nodeid, 365, '/', cookiedomain);
}

function submitAddResource() {
	dojo.byId('addResourceMode').value = 'changeResourcePrivs';
	dojo.byId('resourceForm').submit();
}

/*function submitAddResourcePriv() {
	dojo.byId('addResourceMode').value = 'addResourcePriv';
	dojo.byId('resourceForm').submit();
}*/

function toggleRowSelect(id) {
	var row = document.getElementById(id);
	if(toggledRows[id] && toggledRows[id] == 1) {
		row.className = '';
		toggledRows[id] = 0;
	}
	else {
		row.className = 'hlrow';
		toggledRows[id] = 1;
	}
}

function toggleColSelect(id) {
	var col = document.getElementById(id);
	if(toggledCols[id] && toggledCols[id] == 1) {
		col.className = '';
		toggledCols[id] = 0;
	}
	else {
		col.className = 'hlcol';
		toggledCols[id] = 1;
	}
}

function selectEnvironment() {
	var imageid = dojo.byId('imagesel').value;
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
		if(dojo.byId('newsubmit'))
			dojo.byId('newsubmit').value = 'Create Reservation';
		//return;
		desconly = 1;
	}
	if(dojo.byId('openend') &&
	   dojo.byId('openend').checked) {
		dojo.byId('waittime').className = 'hidden';
		dojo.byId('newsubmit').value = 'Create Reservation';
		//return;
		desconly = 1;
	}
	var imageid = dojo.byId('imagesel').value;
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
	setLoading();
	RPCwrapper(data, genericCB);
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

function resRefresh() {
	if(! dojo.byId('resRefreshCont'))
		return;
	var contid = dojo.byId('resRefreshCont').value;
	var reqid = dojo.byId('detailreqid').value;
	if(! dojo.widget.byId('resStatusPane')) {
		window.location.reload();
		return;
	}
	if(dojo.widget.byId('resStatusPane').windowState == 'minimized') {
		var incdetails = 0;
	}
	else {
		var incdetails = 1;
	}
	var data = {continuation: contid,
	            incdetails: incdetails,
	            reqid: reqid};
	RPCwrapper(data, genericCB);
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
