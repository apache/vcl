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

function generalPrivCB(data, ioArgs) {
	eval(data);
	unsetLoading2();
}

function setLoading2(duration) {
	dijit.byId('workingDialog').duration = duration;
   document.body.style.cursor = 'wait';
	if(dijit.byId('workingDialog')) {
		var obj = dijit.byId('workingDialog');
		//dojo.addClass(obj.titleBar, 'hidden');
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
		//dojo.addClass(node.labelNode, "dijitTreeLabelFocused");
		node.tree._onNodeFocus(node);
	}
	var nodeid = node.item.name;
	if(nodeid != parseInt(nodeid))
		return;
	var nodename = node.item.display;
	var tree = dijit.byId('privtree');
	if(tree.lastLabel)
		dojo.removeClass(tree.lastLabel, 'privtreeselected');
	tree.lastLabel = node.labelNode;
	dojo.addClass(node.labelNode, 'privtreeselected');
	updateNodeLabels(nodename);
	setLoading2(250);
	/*if(dojo.byId('activeNodeAdd'))
		dojo.byId('activeNodeAdd').value = nodeid;
	if(dojo.byId('activeNodeDel'))
		dojo.byId('activeNodeDel').value = nodeid;*/
	dojo.cookie('VCLACTIVENODE', nodeid, {expires: 365, path: '/', domain: cookiedomain});
	var obj = dojo.byId('nodecont');
	var data = {continuation: obj.value,
		        node: nodeid};
	RPCwrapper(data, generalPrivCB, 0);
}

function updateNodeLabels(nodename) {
	dojo.byId('addPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('addGroupPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('addResourceGroupPaneNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('addChildNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('deleteNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
	dojo.byId('renameNodeName').innerHTML = 'Node: <strong>' + nodename + '</strong>';
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
		var children = tree.rootNode.getChildren();
		var fc = children[0];
		if(fc !== tree._itemNodesMap[id][0]) {
			fc.setSelected(false);
		}
		tree._onNodeFocus(tree._itemNodesMap[id][0]);
		tree.lastLabel = tree._itemNodesMap[id][0].labelNode;
		dojo.addClass(tree._itemNodesMap[id][0].labelNode, 'privtreeselected');
		tree.lastFocused = tree._itemNodesMap[id][0];
		var nodename = tree.lastLabel.innerHTML;
		updateNodeLabels(nodename);
	}
	else if(tree._itemNodesMap &&
	        tree.model.root.children &&
	        tree._itemNodesMap[tree.model.root.children[0].name[0]]) {
		var pnodeids = new Array();
		var node = tree.store._itemsByIdentity[id];
		while(node._RRM) {
			for(var pid in node._RRM) {
				pnodeids.push(pid);
				node = tree.store._itemsByIdentity[pid];
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

function addChildNode(name, id) {
	var tree = dijit.byId('privtree');
	var store = tree.store;
	// determine selected node
	var parentnode = tree.lastFocused.item;
	// add new node to selected node
	var nodedata = {name: id, display: name};
	var parentdata = {parent: parentnode, attribute: 'children'};
	var newnode = store.newItem(nodedata, parentdata);

	// hide addNodePane
	dojo.byId('childNodeName').value = '';
	dojo.byId('addChildNodeStatus').innerHTML = '';
	setTimeout(function() {dijit.byId('addNodePane').hide();}, 100);
	
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
	var store = tree.store;
	dojo.addClass(tree._itemNodesMap[nodeid][0].labelNode, 'privtreeselected');
	tree.lastLabel = tree._itemNodesMap[nodeid][0].labelNode;
	tree.lastLabel.focus();
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

function removeNodesFromTree(idlist) {
	var tree = dijit.byId('privtree');
	var ids = idlist.split(',');
	for(var i in ids) {
		tree.store.fetchItemByIdentity({
			identity: ids[i],
			onItem: removeNodesFromTreeCB
		});
	}
}

function removeNodesFromTreeCB(item, request) {
	if(item) {
		var tree = dijit.byId('privtree');
		tree.store.deleteItem(item);
	}
}

function renameNode() {
	var tree = dijit.byId('privtree');
	var contid = dojo.byId('renamecont').value;
	var newname = dojo.byId('newNodeName').value;
	var curname = tree.lastFocused.item.display[0];
	if(! newname.length)
		return;
	if(newname == tree.lastFocused.item.display[0]) {
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
	tree.store.fetchItemByIdentity({
		identity: nodeid,
		onItem: function(item, request) {
			var tree = dijit.byId('privtree');
			var store = tree.store;
			store.setValue(item, 'display', newname);
			dojo.addClass(tree.lastLabel, 'privtreeselected');
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
	var color = dojo.byId(objname).bgColor;
	if(color == '#008000') {
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
	var color;
	var value;
	var obj;
	var obj2;
	var namearr;
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
				obj2.bgColor = '#FFFFFF';
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
				obj2.bgColor = '#008000';
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
