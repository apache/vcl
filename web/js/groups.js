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
var xhrobj;
var blockHide = 0;
var currentOver = '';

function nocasesort(a, b) {
	var al = a.toLowerCase();
	var bl = b.toLowerCase();
	if(al < bl)
		return -1;
	if(bl < al)
		return 1;
	return 0;
}

function getGroupInfo(groupid) {
	var cont = dojo.byId('jsongroupinfocont').value;
	var domid = 'listicon' + groupid;
	currentOver = domid;
	dojo.byId(domid).onmouseover = '';
	xhrobj = dojo.xhrPost({
		url: 'index.php',
		load: showGroupInfo,
		handleAs: "json",
		error: errorHandler,
		content: {continuation: cont,
		          groupid: groupid},
		timeout: 15000
	});
}

function mouseoverHelp() {
	currentOver = 'listicon0';
	var obj = dijit.byId('listicon0tt');
	if(! obj) {
		var tt = new dijit.Tooltip({
		   id: 'listicon0tt',
		   connectId: ['listicon0'],
		   label: 'mouse over icon to<br>display a group&#146;s<br>resources'
		});
		tt.open(dojo.byId('listicon0'));
	}
	else
		obj.open(dojo.byId('listicon0'));
}

function showGroupInfoCancel(groupid) {
	currentOver = '';
	dojo.byId('listicon' + groupid).onmouseout = '';
}

function showGroupInfo(data, ioArgs) {
	var members = data.items.members;
	var domid = 'listicon' + data.items.groupid;
	var tt = new dijit.Tooltip({
		connectId: [domid],
		label: members
	});
	if(currentOver == domid)
		tt.open(dojo.byId(domid));
}

function fmtUserGroupDeleteBtn(groupid, rowIndex) {
	var rowdata = this.grid.getItem(rowIndex);
	if(rowdata.deletable == 0)
		return '';
	var btn = new dijit.form.Button({
		label: 'Delete',
		onClick: function() {
			confirmDeleteUserGroup(groupid);
		}
	});
	btn._destroyOnRemove = true;
	return btn;
}

function confirmDeleteUserGroup(groupid) {
	var data = {continuation: dojo.byId('deletegroupcont').value,
	            groupid: groupid};
	RPCwrapper(data, confirmDeleteGroupCB, 1);
}

function confirmDeleteGroupCB(data, ioArgs) {
	if(data.items.status == 'nogroup' ||
	   data.items.status == 'noaccess' ||
	   data.items.status == 'inuse') {
		dojo.byId('confirmDeleteHeading').innerHTML = data.items.title;
		dojo.byId('confirmDeleteQuestion').innerHTML = '';
		dojo.byId('confdelcontent').innerHTML = data.items.msg;
		hideDijitButton('deleteBtn');
	}
	else {
		showDijitButton('deleteBtn');
		dojo.byId('confirmDeleteHeading').innerHTML = data.items.title;
		dojo.byId('confirmDeleteQuestion').innerHTML = data.items.question;
		dojo.byId('confdelcontent').innerHTML = data.items.content;
		dojo.byId('submitdeletecont').value = data.items.cont;
	}
	dijit.byId('confirmDeleteDialog').show();
}

function clearHideConfirmDelete() {
	dijit.byId('confirmDeleteDialog').hide();
	dojo.removeClass('deleteBtn', 'hidden');
	dojo.byId('confirmDeleteHeading').innerHTML = '';
	dojo.byId('confirmDeleteQuestion').innerHTML = '';
	dojo.byId('confdelcontent').innerHTML = '';
}

function submitDeleteGroup() {
	var data = {continuation: dojo.byId('submitdeletecont').value};
	RPCwrapper(data, submitDeleteGroupCB, 1);
}

function submitDeleteGroupCB(data, ioArgs) {
	clearHideConfirmDelete();
	if(data.items.type == 'user') {
		usergroupstore.fetchItemByIdentity({
			'identity': data.items.id,
			'onItem': function(item) {
				usergroupstore.deleteItem(item);
			}
		});
	}
	else {
		resourcegroupstore.fetchItemByIdentity({
			'identity': data.items.id,
			'onItem': function(item) {
				resourcegroupstore.deleteItem(item);
			}
		});
	}
}

function fmtUserGroupEditBtn(groupid, rowIndex) {
	var btn = new dijit.form.Button({
		label: 'Edit',
		onClick: function() {
			editUserGroup(groupid);
		}
	});
	btn._destroyOnRemove = true;
	return btn;
}

function editUserGroup(groupid) {
	// call url with continuation, groupid
	var cont = dojo.byId('editgroupcont').value;
	window.location.href = 'index.php?continuation=' + cont + '&groupid=' + groupid;
}

function usergroupGridFilter() {
	var name = '.*';
	if(dojo.byId('namefilter') && dojo.byId('namefilter').value.length)
		name += dojo.byId('namefilter').value + '.*';

	var affilid = dijit.byId('affiliationfilter').get('value');
	if(affilid == 0)
		affilid = '*';

	var owner = dijit.byId('ownerfilter').get('value');
	if(owner == 'all')
		owner = '*';

	var query = new Array();
	if(! dijit.byId('shownormal') &&
	   ! dijit.byId('showfederated') &&
	   ! dijit.byId('showcourseroll')) {
		query.push('.*');
	}
	else {
		if(dijit.byId('shownormal').get('value'))
			query.push('normal');
		if(dijit.byId('showfederated').get('value'))
			query.push('federated');
		if(dijit.byId('showcourseroll').get('value'))
			query.push('courseroll');
	}
	var type = query.join('|');
	if(query.length == 0)
		type = 'foo';

	var editid = dijit.byId('editgroupfilter').get('value');
	if(editid == 0)
		editid = '*';
	if(editid == -1)
		editid = 'NULL';

	usergroupgrid.setQuery({type: new RegExp(type),
	                        owner: owner,
	                        name: new RegExp(name, 'i'),
	                        groupaffiliationid: affilid,
	                        editgroupid: editid});
}

function buildUserFilterStores() {
	if(typeof usergroupstore === 'undefined' ||
	   ! usergroupstore._loadFinished) {
		setTimeout(buildUserFilterStores, 500);
		return;
	}
	usergroupstore.affiliations = new Object();
	usergroupstore.owners = new Object();
	usergroupstore.editgroups = new Object();
	usergroupstore.fetch({query: {id: '*'},
		onItem: function(item) {
			var affilid = usergroupstore.getValue(item, 'groupaffiliationid');
			var affil = usergroupstore.getValue(item, 'groupaffiliation');
			usergroupstore.affiliations[affilid] = affil;
			var owner = usergroupstore.getValue(item, 'owner');
			usergroupstore.owners[owner] = owner;
			var editid = usergroupstore.getValue(item, 'editgroupid');
			var edit = usergroupstore.getValue(item, 'editgroup');
			if(edit != 'None')
				usergroupstore.editgroups[editid] = edit;
		},
		onComplete: function() {
			var cnt = 0;
			for(var p in usergroupstore.owners) {
				if(usergroupstore.owners.hasOwnProperty(p))
					cnt = 1;
					break;
			}
			if(cnt == 0) {
				dojo.byId('usergroupcontainer').innerHTML = "You do not have access to any user groups.";
				return;
			}
			var newitem = {};
			newitem = {'id': '0', 'name': ' Any'};
			affiliationstore.newItem(newitem);
			for(affilid in usergroupstore.affiliations) {
				newitem = {'id': affilid, 'name': usergroupstore.affiliations[affilid]};
				affiliationstore.newItem(newitem);
			}
			dijit.byId('affiliationfilter').setStore(affiliationstore, '', {query: {id: '*'}});
			delete usergroupstore.affiliations;

			var newitem = {};
			newitem = {'id': 'all', 'name': ' Any'};
			ownerstore.newItem(newitem);
			for(owner in usergroupstore.owners) {
				newitem = {'id': owner, 'name': owner};
				ownerstore.newItem(newitem);
			}
			dijit.byId('ownerfilter').setStore(ownerstore, '', {query: {id: '*'}});
			delete usergroupstore.owners;

			newitem = {'id': '0', 'name': ' Any'};
			editgroupstore.newItem(newitem);
			newitem = {'id': '-1', 'name': ' None'};
			editgroupstore.newItem(newitem);
			for(editid in usergroupstore.editgroups) {
				newitem = {'id': editid, 'name': usergroupstore.editgroups[editid]};
				editgroupstore.newItem(newitem);
			}
			dijit.byId('editgroupfilter').setStore(editgroupstore, '', {query: {id: '*'}});
			delete usergroupstore.editgroups;
		}
	});
}

function fmtResourceGroupDeleteBtn(groupid, rowIndex) {
	var rowdata = this.grid.getItem(rowIndex);
	if(rowdata.deletable == 0)
		return '';
	var btn = new dijit.form.Button({
		label: 'Delete',
		onClick: function() {
			confirmDeleteResourceGroup(groupid);
		}
	});
	btn._destroyOnRemove = true;
	return btn;
}

function confirmDeleteResourceGroup(groupid) {
	var data = {continuation: dojo.byId('deleteresgroupcont').value,
	            groupid: groupid};
	RPCwrapper(data, confirmDeleteGroupCB, 1);
}

function fmtResourceGroupEditBtn(groupid, rowIndex) {
	var btn = new dijit.form.Button({
		label: 'Edit',
		onClick: function() {
			editResourceGroup(groupid);
		}
	});
	btn._destroyOnRemove = true;
	return btn;
}

function editResourceGroup(groupid) {
	// call url with continuation, groupid
	var cont = dojo.byId('editresgroupcont').value;
	window.location.href = 'index.php?continuation=' + cont + '&groupid=' + groupid;
}

function fmtGroupInfo(groupid, rowIndex) {
	var str = '<a onmouseover="getGroupInfo(' + groupid + ');" '
	        + 'onmouseout="showGroupInfoCancel(' + groupid + ');" '
	        + 'id=listicon' + groupid + '><img alt="mouseover for list of '
	        + 'resources in the group" title="" src="images/list.gif"></a>';
	return str;
}

function resourcegroupGridFilter() {
	var name = '.*';
	if(dojo.byId('resnamefilter') && dojo.byId('resnamefilter').value.length)
		name += dojo.byId('resnamefilter').value + '.*';

	var query = new Array();
	var nodes = dojo.query('label', dojo.byId('resourcetypes'));
	for(var i = 0; i < nodes.length; i++) {
		var showtype = 'show' + nodes[i].innerHTML;
		if(dijit.byId(showtype) && dijit.byId(showtype).get('value'))
			query.push(nodes[i].innerHTML);
	}
	var restype = query.join('|');
	if(query.length == 0)
		restype = 'foo';

	var owninggroupid = dijit.byId('owninggroupfilter').get('value');
	if(owninggroupid == 0)
		owninggroupid = '*';

	resourcegroupgrid.setQuery({type: new RegExp(restype),
	                            name: new RegExp(name, 'i'),
	                            owninggroupid: owninggroupid});
}

function buildResourceFilterStores() {
	if(typeof resourcegroupstore === 'undefined' ||
	   ! resourcegroupstore._loadFinished) {
		setTimeout(buildResourceFilterStores, 500);
		return;
	}
	resourcegroupstore.ownergroups = new Object();
	resourcegroupstore.fetch({
		query: {id: '*'},
		onItem: function(item) {
			var ownerid = resourcegroupstore.getValue(item, 'owninggroupid');
			var owner = resourcegroupstore.getValue(item, 'owninggroup');
			resourcegroupstore.ownergroups[ownerid] = owner;
		},
		onComplete: function() {
			var cnt = 0;
			for(var p in resourcegroupstore.ownergroups) {
				if(resourcegroupstore.ownergroups.hasOwnProperty(p))
					cnt = 1;
					break;
			}
			if(cnt == 0) {
				dojo.byId('resourcegroupcontainer').innerHTML = "You do not have access to any resource groups.";
				return;
			}
			var newitem = {};
			newitem = {'id': '0', 'name': ' Any'};
			owninggroupstore.newItem(newitem);
			for(ownerid in resourcegroupstore.ownergroups) {
				newitem = {'id': ownerid, 'name': resourcegroupstore.ownergroups[ownerid]};
				owninggroupstore.newItem(newitem);
				dijit.byId('owninggroupfilter').setStore(owninggroupstore, '', {query: {id: '*'}});
			}
		}
	});
}

function fmtDuration(len, rowIndex, cell) {
	var rowdata = this.grid.getItem(rowIndex);
	var field = cell.field + 'disp';
	return rowdata[field];
}
