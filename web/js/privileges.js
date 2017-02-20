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
var currentOver = '';
var saveMoveNode = 0;
var moveitem;
var nomove = 0;
var dragnode = {hoverid: 0, dragid: 0, startX: 0, startY: 0};
var mouseontree = 0;
var dragging = 0;
var nodedropdata = 0;

function moveData() {
	this.oldparentid = '';
	this.oldparentobj = '';
	this.oldparentset = 0;
	this.newparentid = '';
	this.newparentobj = '';
	this.newparentset = 0;
	this.moveid = '';
	this.moveobj = '';
	this.moveset = 0;
}

function generalPrivCB(data, ioArgs) {
	eval(data);
	unsetLoading2();
}

function setLoading2(duration) {
	dijit.byId('workingDialog').duration = duration;
   document.body.style.cursor = 'wait';
	if(dijit.byId('workingDialog')) {
		var obj = dijit.byId('workingDialog');
		obj.show();
	}
}

function unsetLoading2() {
	document.body.style.cursor = 'default';
	if(dijit.byId('workingDialog'))
		dijit.byId('workingDialog').hide();
}

function nodeSelect(node) {
	/* for some reason, _onLabelFocus does not get set up for tree nodes by
	 * Safari; so, we perform the same operations here */
	if(dojo.isSafari) {
		node.tree._onNodeFocus(node);
	}
	var nodeid = node.item.name;
	if(nodeid != parseInt(nodeid))
		return;
	var nodename = node.item.display;
	var tree = dijit.byId('privtree');
	tree.lastFocused = node;
	updateNodeLabels(nodename);
	setLoading2(250);
	dojo.cookie('VCLACTIVENODE', nodeid, {expires: 365, path: '/', domain: cookiedomain});
	var obj = dojo.byId('nodecont');
	var data = {continuation: obj.value,
		        node: nodeid};
	RPCwrapper(data, generalPrivCB, 0);
}

function mouseDown(evt) {
	dragging = 1;
	dragnode.dragid = dragnode.hoverid;
	dragnode.startX = mouseX;
	dragnode.startY = mouseY;
}

function mouseRelease(evt) {
	if(typeof nodedropdata == 'number')
		return;
	if(dragging == 0)
		return;
	dragging = 0;
	if(mouseX == dragnode.startX && mouseY == dragnode.startY)
		return;
	if(nodedropdata[dragnode.dragid] == 0 || nodedropdata[dragnode.hoverid] == 0 || mouseontree == 0)
		setSelected(dijit.byId('privtree').lastFocused.item.name[0]);
}

function initDropData() {
	if(dijit.byId('addNodeBtn'))
		dijit.byId('addNodeBtn').set('disabled', false);
	dojo.addClass('ddloading', 'hidden');
}

function updateNodeLabels(nodename) {
	dojo.byId('addPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('addGroupPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('addResourceGroupPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('addChildNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('deleteNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('renameNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dijit.byId('newNodeName').set('value', nodename);
}

function isChildFocused(focusid, nodes) {
	for(var i in nodes) {
		if(nodes[i].name == focusid)
			return 1;
		else if(nodes[i].children)
			if(isChildFocused(focusid, nodes[i].children))
				return 1;
	}
	return 0;
}

function showPrivPane(name) {
	dijit.byId(name).show();
}

function focusFirstNode(id) {
	var tree = dijit.byId('privtree');
	if(tree._itemNodesMap && tree._itemNodesMap[id]) {
		refreshNodeDropData();
		setSelected(id);
		updateNodeLabels(tree._itemNodesMap[id][0].label);
		tree.lastFocused = tree._itemNodesMap[id][0];
	}
	else if(tree._itemNodesMap &&
	        tree.model.root.children &&
	        tree._itemNodesMap[tree.model.root.children[0].name[0]]) {
		var pnodeids = new Array();
		var node = tree.model.store._itemsByIdentity[id];
		while(node._RRM) {
			for(var pid in node._RRM) {
				pnodeids.push(pid);
				node = tree.model.store._itemsByIdentity[pid];
			}
		}
		var pid;
		while(pid = pnodeids.pop()) {
			var pnode = tree._itemNodesMap[pid][0];
			tree._expandNode(pnode);
		}
		setTimeout(function() {focusFirstNode(id);}, 10);
	}
	else {
		setTimeout(function() {focusFirstNode(id);}, 500);
	}
}

function submitAddChildNode() {
	dojo.byId('addChildNodeStatus').innerHTML = '';
	var obj = dojo.byId('childNodeName');
	var newnode = obj.value;
	if(! newnode.length)
		return;
	var contid = dojo.byId('addchildcont').value;
	var tree = dijit.byId('privtree');
	var data = {continuation: contid,
	            newnode: newnode,
	            activeNode: tree.lastFocused.item.name[0]};
	setLoading2(150);
	RPCwrapper(data, generalPrivCB, 0);
}

function addChildNode(name, id, parentid) {
	var tree = dijit.byId('privtree');
	var store = tree.model.store;
	// determine selected node
	var parentnode = tree.lastFocused.item;
	// add new node to selected node
	var nodedata = {name: id, display: name, parent: parentid};
	var parentdata = {parent: parentnode, attribute: 'children'};
	var newnode = store.newItem(nodedata, parentdata);
	var parentitem = tree._itemNodesMap[parentid][0].item;
	positionNode(newnode, parentitem);

	// hide addNodePane
	dojo.byId('childNodeName').value = '';
	dojo.byId('addChildNodeStatus').innerHTML = '';
	setTimeout(function() {dijit.byId('addNodePane').hide();}, 100);
	nodedropdata[id] = 1;
}

function positionNode(node, parent) {
	var index = 0;
	var decr = 0;
	for(var i = 0; i < parent.children.length; i++) {
		if(node.display[0].localeCompare(parent.children[i].display[0]) == 0)
			decr = 1;
		if(node.display[0].localeCompare(parent.children[i].display[0]) == -1)
			break;
	}
	index = i;
	if(decr)
		index--;
	nomove = 1;
	nodemodel.pasteItem(node, parent, parent, 0, index);
	nomove = 0;
}

function deleteNodes() {
	var tree = dijit.byId('privtree');
	var contid = dojo.byId('delchildcont').value;
	var data = {continuation: contid,
	            activeNode: tree.lastFocused.item.name[0]};
	RPCwrapper(data, generalPrivCB, 0);
}

function setSelectedPrivNode(nodeid) {
	var tree = dijit.byId('privtree');
	var store = tree.model.store;
	setSelected(nodeid);
	tree.lastFocused = tree._itemNodesMap[nodeid][0];
	updateNodeLabels(tree.lastFocused.label);
	setLoading2(250);
	dojo.cookie('VCLACTIVENODE', nodeid, {expires: 365, path: '/', domain: cookiedomain});
	var obj = dojo.byId('nodecont');
	var nodeid = tree.lastFocused.item.name;
	var data = {continuation: obj.value,
		        node: nodeid};
	RPCwrapper(data, generalPrivCB, 0);
}

function removeNodesFromTree(idlist, deleteid) {
	var tree = dijit.byId('privtree');
	var ids = idlist.split(',');
	for(var i in ids) {
		if(typeof(moveitem) !== 'undefined' &&
		   ids[i] == moveitem.oldparentid) {
			moveitem = undefined;
			dijit.byId('revertMoveNodeBtn').set('disabled', true);
		}
	}
	tree.model.store.fetchItemByIdentity({
		identity: deleteid,
		onItem: removeNodesFromTreeCB
	});
}

function removeNodesFromTreeCB(item, request) {
	if(item) {
		var tree = dijit.byId('privtree');
		nomove = 1;
		tree.model.store.deleteItem(item);
		nomove = 0;
	}
}

function renameNode() {
	var tree = dijit.byId('privtree');
	var contid = dojo.byId('renamecont').value;
	dijit.byId('submitRenameNodeBtn').focus();
	var newname = dijit.byId('newNodeName').value;
	var curname = tree.lastFocused.item.display[0];
	if(! newname.length)
		return;
	if(newname == curname) {
		dijit.byId('newNodeName').focus();
		dojo.byId('renameNodeStatus').innerHTML = 'You must enter a different name';
		return;
	}
	var data = {continuation: contid,
	            newname: newname,
	            activeNode: tree.lastFocused.item.name[0]};
	RPCwrapper(data, renameNodeCB, 1);
}

function renameNodeCB(data, ioArgs) {
	if(data.items.error) {
		if(data.items.error == 1) {
			alert(data.items.message);
			clearRenameBox();
			return;
		}
		else if(data.items.error == 2) {
			dojo.byId('renameNodeStatus').innerHTML = data.items.message;
			return;
		}
	}
	var newname = data.items.newname;
	var nodeid = data.items.node;
	var tree = dijit.byId('privtree');
	tree.model.store.fetchItemByIdentity({
		identity: nodeid,
		onItem: function(item, request) {
			var tree = dijit.byId('privtree');
			var store = tree.model.store;
			nomove = 1;
			store.setValue(item, 'display', newname);
			nomove = 0;
			setTimeout(function() {
				var parentitem = tree._itemNodesMap[item.parent[0]][0].item;
				positionNode(item, parentitem);
			}, 500);
		}
	});
	clearRenameBox();
	updateNodeLabels(newname);
}

function clearRenameBox() {
	dojo.byId('newNodeName').value = '';
	dojo.byId('renameNodeStatus').innerHTML = '';
	dijit.byId('renameDialog').hide();
}

function refreshPerms() {
   setLoading2(250);
	var tree = dijit.byId('privtree');
	var cont = dojo.byId('nodecont').value;
	var data = {continuation: cont,
	            node: tree.lastFocused.item.name[0]};
	RPCwrapper(data, generalPrivCB, 0);
}

function privChange(checked, row, col, type) {
	var objname = 'ck' + row + ':' + col;
	var obj = dijit.byId(objname);
	if(obj.disabled)
		return;
	var nameArr = obj.name.split('[');
	nameArr = nameArr[1].split(']');
	nameArr = nameArr[0].split(':');
	if(! checked && obj.value == 'single')
		obj.value = '';
	if(! checked && obj.value == 'cascadesingle')
		obj.value = 'cascade';
	else if(checked && obj.value == '')
		obj.value = 'single';
	else if(checked && obj.value == 'cascade')
		obj.value = 'cascadesingle';
	if(type == 1)
		var contid = dojo.byId('changeuserprivcont').value;
	else if(type == 2)
		var contid = dojo.byId('changeusergroupprivcont').value;
	else if(type == 3)
		var contid = dojo.byId('changeresourceprivcont').value;
	var tree = dijit.byId('privtree');
	var data = {continuation: contid,
	            activeNode: tree.lastFocused.item.name[0],
	            item: nameArr[0],
	            priv: nameArr[1],
	            value: checked};
	setLoading2(50);
	RPCwrapper(data, generalPrivCB, 0);
}

function nodeCheck(checked, row, col, type) {
	var objname = "cell" + row + ":" + col;
	if(dojo.hasClass(objname, 'privCascade')) {
		objname = "ck" + row + ":" + col;
		var obj = dijit.byId(objname);
		obj.setAttribute('checked', true);
	}
	else {
		privChange(checked, row, col, type);
	}
}

function changeCascadedRights(checked, row, count, fromclick, type) {
	var i;
	var objname;
	var value;
	var obj;
	var obj2;
	for(i = 1; i < count; i++) {
		objname = "ck" + row + ":" + i;
		obj = dijit.byId(objname);
		if(! obj)
			continue;
		value = obj.value;
		if(checked) {
			if(value != 'single') {
				objname = "cell" + row + ":" + i;
				obj2 = dojo.byId(objname);
				if(! obj2)
					continue;
				dojo.removeClass(objname, 'privCascade');
				if(value == 'cascade') {
					objname = "ck" + row + ":" + i;
					obj = dijit.byId(objname)
					obj.setAttribute('checked', false);
				}
			}
		}
		else {
			if(value == 'single')
				obj.setAttribute('checked', true);
			else if(value == 'cascadesingle' || value == 'cascade') {
				obj.setAttribute('checked', true);
				objname = "cell" + row + ":" + i;
				obj2 = dojo.byId(objname);
				if(! obj2)
					continue;
				dojo.addClass(objname, 'privCascade');
			}
		}
	}
	if(fromclick)
		privChange(checked, row, 'block', type);
}

function addUserPaneHide() {
	dijit.byId('addUserPane').hide();
	var workingobj = dijit.byId('workingDialog');
	dojo.connect(workingobj._fadeOut, 'onEnd', dijit.byId('addUserPane'), 'hide');
	dojo.byId('addUserPrivStatus').innerHTML = '';
	dojo.byId('newuser').value = '';
	var obj = dijit.byId('blockchk');
	if(obj.checked)
		obj.setAttribute('checked', false);
	for(var i = 0; obj = dijit.byId('userck0:' + i); i++) {
		if(obj.checked)
			obj.setAttribute('checked', false);
	}
}

function submitAddUser() {
	dojo.byId('addUserPrivStatus').innerHTML = '';
	var userid = dojo.byId('newuser').value;
	if(! userid.length)
		return;
	var perms = new Array();
	var obj = dijit.byId('blockchk');
	if(obj.checked)
		perms.push('block');
	for(var i = 0; obj = dijit.byId('userck0:' + i); i++) {
		if(obj.checked)
			perms.push(obj.name);
	}
	var perms2 = perms.join(':', perms);
	var contid = dojo.byId('addusercont').value;
	var tree = dijit.byId('privtree');
	var data = {continuation: contid,
	            perms: perms2,
	            newuser: userid,
	            activeNode: tree.lastFocused.item.name[0]};
   setLoading2(250);
	RPCwrapper(data, generalPrivCB, 0);
}

function addUserGroupPaneHide() {
	dijit.byId('addUserGroupPane').hide();
	var workingobj = dijit.byId('workingDialog');
	dojo.connect(workingobj._fadeOut, 'onEnd', dijit.byId('addUserGroupPane'), 'hide');
	dojo.byId('addUserGroupPrivStatus').innerHTML = '';
	dojo.byId('newgroupid').value = '';
	var obj = dijit.byId('blockgrpchk');
	if(obj.checked)
		obj.setAttribute('checked', false);
	for(var i = 0; obj = dijit.byId('usergrpck0:' + i); i++) {
		if(obj.checked)
			obj.setAttribute('checked', false);
	}
}

function submitAddUserGroup() {
	dojo.byId('addUserGroupPrivStatus').innerHTML = '';
	var groupid = dojo.byId('newgroupid').value;
	if(! groupid.length)
		return;
	var perms = new Array();
	var obj = dijit.byId('blockgrpchk');
	if(obj.checked)
		perms.push('block');
	obj = dijit.byId('usergrpck0:0');
	if(obj.checked)
		perms.push('cascade');
	for(var i = 1; obj = dijit.byId('usergrpck0:' + i); i++) {
		if(obj.checked)
			perms.push(obj.name);
	}
	var perms2 = perms.join(':', perms);
	var contid = dojo.byId('addusergroupcont').value;
	var tree = dijit.byId('privtree');
	var data = {continuation: contid,
	            perms: perms2,
	            newgroupid: groupid,
	            activeNode: tree.lastFocused.item.name[0]};
   setLoading2(250);
	RPCwrapper(data, generalPrivCB, 0);
}

function addResourceGroupPaneHide() {
	dijit.byId('addResourceGroupPane').hide();
	var workingobj = dijit.byId('workingDialog');
	dojo.connect(workingobj._fadeOut, 'onEnd', dijit.byId('addResourceGroupPane'), 'hide');
	dojo.byId('addResourceGroupPrivStatus').innerHTML = '';
	dojo.byId('newresourcegroupid').value = '';
	var obj = dijit.byId('blockresgrpck');
	if(obj.checked)
		obj.setAttribute('checked', false);
	for(var i = 0; obj = dijit.byId('resgrpck0:' + i); i++) {
		if(obj.checked)
			obj.setAttribute('checked', false);
	}
}

function submitAddResourceGroup() {
	dojo.byId('addResourceGroupPrivStatus').innerHTML = '';
	var groupid = dojo.byId('newresourcegroupid').value;
	if(! groupid.length)
		return;
	var perms = new Array();
	var obj = dijit.byId('blockresgrpck');
	if(obj.checked)
		perms.push('block');
	obj = dijit.byId('resgrpck0:0');
	if(obj.checked)
		perms.push('cascade');
	for(var i = 1; obj = dijit.byId('resgrpck0:' + i); i++) {
		if(obj.checked)
			perms.push(obj.name);
	}
	var perms2 = perms.join(':', perms);
	var contid = dojo.byId('addresourcegroupcont').value;
	var tree = dijit.byId('privtree');
	var data = {continuation: contid,
	            perms: perms2,
	            newgroupid: groupid,
	            activeNode: tree.lastFocused.item.name[0]};
   setLoading2(250);
	RPCwrapper(data, generalPrivCB, 0);
}

function getGroupMembers(resid, domid, cont) {
	currentOver = domid;
	dojo.byId(domid).onmouseover = '';
	var contid = dojo.byId(cont).value;
	var data = {continuation: contid,
	            groupid: resid,
	            domid: domid};
	RPCwrapper(data, groupMembersCB, 1);
}

function getGroupMembersCancel(domid) {
	currentOver = '';
	dojo.byId(domid).onmouseout = '';
}

function groupMembersCB(data, ioArgs) {
	var members = data.items.members;
	var domid = data.items.domid;
	var tt = new dijit.Tooltip({
		connectId: [domid],
		label: members
	});
	if(currentOver == domid)
		tt.open(dojo.byId(domid));
}

function selectUserGroup(cont) {
	var data = {continuation: cont,
	            groupid: dojo.byId('editusergroupid').value};
	RPCwrapper(data, selectUserGroupCB, 1);
}

function selectUserGroupCB(data, ioArgs) {
	if(data.items.failed) {
		alert('You are not authorized to manage this group');
		return;
	}
	dojo.removeClass('usergroupprivs', 'groupprivshidden');
	dijit.byId('usergroupcopyprivsbtn').setAttribute('disabled', false);
	dijit.byId('usergroupsaveprivsbtn').setAttribute('disabled', false);
	var items = dojo.query('#usergroupprivs input[type=checkbox]');
	for(var i = 0; i < items.length; i++) {
		dijit.byId(items[i].id).setAttribute('checked', false);
	}
	for(var i = 0; i < data.items.perms.length; i++) {
		obj = dijit.byId('grouptype' + data.items.perms[i]);
		obj.setAttribute('checked', true);
	}
}

function showUserGroupPrivHelp(help, id) {
	dojo.byId('groupprivhelp').innerHTML = help;
	dojo.addClass('grouptypespan' + id, 'hlperm');
}

function clearUserGroupPrivHelp(id) {
	dojo.byId('groupprivhelp').innerHTML = '';
	dojo.removeClass('grouptypespan' + id, 'hlperm');
}

function copyUserGroupPrivs(cont) {
	var data = {continuation: cont,
	            groupid: dojo.byId('copyusergroupid').value};
	RPCwrapper(data, copyUserGroupPrivsCB, 1);
}

function copyUserGroupPrivsCB(data, ioArgs) {
	if(data.items.failed) {
		alert('You are not authorized to manage this group');
		return;
	}
	var items = dojo.query('#usergroupprivs input[type=checkbox]');
	for(var i = 0; i < items.length; i++) {
		dijit.byId(items[i].id).setAttribute('checked', false);
	}
	for(var i = 0; i < data.items.perms.length; i++) {
		obj = dijit.byId('grouptype' + data.items.perms[i]);
		obj.setAttribute('checked', true);
	}
}

function saveUserGroupPrivs(cont) {
	var permids = new Array();
	var items = dojo.query('#usergroupprivs input[type=checkbox]:checked');
	for(var i = 0; i < items.length; i++) {
		permids.push(items[i].name);
	}
	var permids2 = permids.join(',');
	var data = {continuation: cont,
	            permids: permids2,
	            groupid: dojo.byId('editusergroupid').value};
	RPCwrapper(data, saveUserGroupPrivsCB, 1);
}

function saveUserGroupPrivsCB(data, ioArgs) {
	if(data.items.failed) {
		dojo.byId('userpermsubmitstatus').innerHTML = "Failed to save permissions: " + data.items.failed;
		dojo.addClass('userpermsubmitstatus', 'statusfailed');
	}
	else if(data.items.success) {
		dojo.byId('userpermsubmitstatus').innerHTML = "Permissions successfully saved";
		dojo.addClass('userpermsubmitstatus', 'statussuccess');
	}
	setTimeout(clearUserPrivStatus, 10000);
}

function clearUserPrivStatus() {
	dojo.byId('userpermsubmitstatus').innerHTML = "";
	dojo.removeClass('userpermsubmitstatus', 'statussuccess');
	dojo.removeClass('userpermsubmitstatus', 'statusfailed');
}

function hideUserGroupPrivs() {
	dojo.addClass('usergroupprivs', 'groupprivshidden');
	dijit.byId('usergroupcopyprivsbtn').setAttribute('disabled', true);
	dijit.byId('usergroupsaveprivsbtn').setAttribute('disabled', true);
}

function moveNode(node) {
	if(nomove)
		return;
	if(saveMoveNode == 0) {
		saveMoveNode = node.name[0];
		return;
	}
	var node1 = saveMoveNode;
	var node2 = node.name[0];
	if(node1 == node2) {
		var tree = dijit.byId('privtree');
		var nodeitem = tree._itemNodesMap[dragnode.dragid][0].item;
		var parentid = nodeitem.parent[0];
		var parentitem = tree._itemNodesMap[parentid][0].item;
		positionNode(nodeitem, parentitem);
		if(nodeitem != tree.lastFocused.item)
			setSelected(tree.lastFocused.item.name[0]);
		saveMoveNode = 0;
		return;
	}

	var tree = dijit.byId('privtree');
	var moveid = dragnode.dragid;
	var oldparentid = tree._itemNodesMap[dragnode.dragid][0].item.parent[0];
	if(oldparentid == node1)
		var newparentid = node2;
	else
		var newparentid = node1;

	var nodeitem = tree._itemNodesMap[moveid][0].item;
	var parentitem = tree._itemNodesMap[newparentid][0].item;
	positionNode(nodeitem, parentitem);

	var movename = nodeitem.display[0];
	for(var i = 0; i < parentitem.children.length; i++) {
		var child = parentitem.children[i];
		if(movename == child.display[0] && newparentid == child.parent[0]) {
			var oldparentitem = tree._itemNodesMap[oldparentid][0].item;
			nomove = 1;
			nodemodel.pasteItem(nodeitem, parentitem, oldparentitem, 0, 0);
			positionNode(nodeitem, oldparentitem);
			nomove = 0;
			alert('Another node with the same name and parent as the node being moved already exists.');
			saveMoveNode = 0;
			return;
		}
	}

	var data = {continuation: dojo.byId('movenodecont').value,
	            moveid: moveid,
	            oldparentid: oldparentid,
	            newparentid: newparentid}
	RPCwrapper(data, moveNodeCB, 1);
	saveMoveNode = 0;
}

function moveNodeCB(data, ioArgs) {
	moveitem = new moveData();
	moveitem.moveid = data.items.moveid;
	moveitem.oldparentid = data.items.oldparentid;
	moveitem.newparentid = data.items.newparentid;
	if(data.items.status == 'invaliddata') {
		alert('Error: invalid data submitted');
		revertNodeMove();
		return;
	}
	else if(data.items.status == 'noaccess') {
		alert('You do not have access to move the selected nodes to the selected location.');
		revertNodeMove();
		return;
	}
	else if(data.items.status == 'collision') {
		alert('Another node with the same name and parent as the node being moved already exists.');
		revertNodeMove();
		return;
	}
	else if(data.items.status == 'nochange') {
		return;
	}
	dojo.byId('revertmovenodecont').value = data.items.revertcont;
	dojo.byId('moveNodeName').innerHTML = data.items.movename;
	dojo.byId('moveNodeOldParentName').innerHTML = data.items.oldparent;
	dojo.byId('moveNodeNewParentName').innerHTML = data.items.newparent;
	dojo.byId('movenodesubmitcont').value = data.items.continuation;
	dijit.byId('moveDialog').show();
}

function submitMoveNode() {
	var data = {continuation: dojo.byId('movenodesubmitcont').value};
	RPCwrapper(data, submitMoveNodeCB, 1);
}

function submitMoveNodeCB(data, ioArgs) {
	dijit.byId('moveDialog').hide();
	dijit.byId('revertMoveNodeBtn').set('disabled', false);
	nodestore.fetchItemByIdentity({
		identity: moveitem.moveid,
		onItem: function(item, request) {
			nomove = 1;
			dijit.byId('privtree').model.store.setValue(item, 'parent', data.items.newparentid);
			nomove = 0;
			var selnode = dijit.byId('privtree').selectedNode;
			if(selnode.item == item) {
				nodeSelect(selnode);
			}
		}
	});
	refreshNodeDropData();
}

function submitRevertMoveNode() {
	var data = {continuation: dojo.byId('revertmovenodecont').value};
	RPCwrapper(data, submitRevertMoveNodeCB, 1);
}

function submitRevertMoveNodeCB(data, ioArgs) {
	revertNodeMove();
	dijit.byId('revertMoveNodeDlg').hide();
	dijit.byId('revertMoveNodeBtn').set('disabled', true);
	moveitem = undefined;
	refreshNodeDropData();
}

function revertNodeMove() {
	nodestore.fetchItemByIdentity({
		identity: moveitem.moveid,
		onItem: function(item, request) {
			revertNodeMoveCB('movenode', item);
		}
	});
	nodestore.fetchItemByIdentity({
		identity: moveitem.oldparentid,
		onItem: function(item, request) {
			revertNodeMoveCB('oldparent', item);
		}
	});
	nodestore.fetchItemByIdentity({
		identity: moveitem.newparentid,
		onItem: function(item, request) {
			revertNodeMoveCB('newparent', item);
		}
	});
}

function revertNodeMoveCB(type, item) {
	if(type == 'movenode') {
		moveitem.moveobj = item;
		moveitem.moveset = 1;
	}
	else if(type == 'oldparent') {
		moveitem.oldparentobj = item;
		moveitem.oldparentset = 1;
	}
	else if(type == 'newparent') {
		moveitem.newparentobj = item;
		moveitem.newparentset = 1;
	}
	if(moveitem.oldparentset == 1 &&
	   moveitem.newparentset == 1 &&
	   moveitem.moveset == 1) {
		var index = -1;
		if('children' in moveitem.oldparentobj) {
			for(var i = 0; i < moveitem.oldparentobj.children.length; i++) {
				if(moveitem.moveobj.display[0].localeCompare(moveitem.oldparentobj.children[i].display[0]) == -1) {
					break;
				}
			}
		}
		index = i;
		nomove = 1;
		nodemodel.pasteItem(moveitem.moveobj, moveitem.newparentobj, moveitem.oldparentobj, 0, index);
		dijit.byId('privtree').model.store.setValue(moveitem.moveobj, 'parent', moveitem.oldparentobj.name[0]);
		nodeSelect(dijit.byId('privtree')._itemNodesMap[moveitem.moveobj.name[0]][0]);
		nomove = 0;
	}
}

function setSelected(nodeid) {
	var tree = dijit.byId('privtree');
	var selpath = [];
	while(typeof(tree._itemNodesMap[nodeid]) !== 'undefined') {
		selpath.unshift(tree._itemNodesMap[nodeid][0].item);
		nodeid = tree._itemNodesMap[nodeid][0].item.parent[0];
	}
	selpath.unshift(tree.model.root);
	tree.attr('path', selpath);
}

function checkCanMove(tree, domnodes) {
	if(typeof nodedropdata == 'number')
		return false;
	var node = dijit.getEnclosingWidget(domnodes[0]);
	var nodeid = node.item.name[0];
	if(nodedropdata[nodeid] == 0)
		return false;
	return true;
}

function checkNodeDrop(domnode, tree, position) {
	if(typeof nodedropdata == 'number')
		return false;
	var node = dijit.getEnclosingWidget(domnode);
	var nodeid = node.item.name[0];
	if(nodedropdata[nodeid] == 0)
		return false;
	return true;
}

function refreshNodeDropData() {
	var data = {continuation: dojo.byId('refreshnodedropdatacont').value};
	RPCwrapper(data, generalPrivCB, 0, 60000);
}
