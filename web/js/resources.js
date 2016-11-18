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

function Resource() {
	this.restype = 'resource';
}

Resource.prototype.DeleteBtn = function(rscid, rowIndex) {
	var rowdata = this.grid.getItem(rowIndex);
	if(! ('deleted' in rowdata) || rowdata.deleted == '0')
		var label = _('Delete');
	else
		var label = _('Undelete');
	var btn = new dijit.form.Button({
		label: label,
		onClick: function() {
			toggleDeleteResource(rscid);
		}
	});
	btn._destroyOnRemove = true;
	return btn;
}

Resource.prototype.EditBtn = function(rscid, rowIndex) {
	var rowdata = this.grid.getItem(rowIndex);
	if(! ('deleted' in rowdata) || rowdata.deleted == '0')
		var disable = false;
	else
		var disable = true;
	var btn = new dijit.form.Button({
		label: _('Edit'),
		disabled: disable,
		onClick: function() {
			editResource(rscid);
		}
	});
	btn._destroyOnRemove = true;
	return btn;
}

Resource.prototype.colformatter = function(value, rowIndex, obj) {
	return value;
}

Resource.prototype.GridFilter = function() {
	var name = '.*';
	if(dijit.byId('namefilter') && dijit.byId('namefilter').get('value').length)
		name += dijit.byId('namefilter').get('value') + '.*';
	if(! dijit.byId('showdeleted')) {
		resourcegrid.setQuery({name: new RegExp(name, 'i')});
		return;
	}
	if(dijit.byId('showdeleted').get('value'))
		var deleted = '*';
	else
		var deleted = '0';
	resourcegrid.setQuery({name: new RegExp(name, 'i'),
	                       deleted: deleted});
}

Resource.prototype.addRemItem = function(contid, objid1, objid2) {
	// TODO check for selection on other tabs and update if needed
	var obj = dojo.byId(objid1);
	var id = obj.options[obj.selectedIndex].value;

	obj = window[objid2];
	var items = obj.selection.getSelected();
	var listids = "";
	for(var i = 0; i < items.length; i++) {
		listids = listids + ',' + items[i].id;
	}
	if(listids == "")
		return;
	document.body.style.cursor = 'wait';
	var data = {continuation: dojo.byId(contid).value,
	            listids: listids,
	            id: id};
	RPCwrapper(data, this.addRemItemCB, 1);
}

Resource.prototype.addRemItemCB = function(data, ioArgs) {
	if(data.items.status == 'success') {
		window[data.items.inselobj].selection.clear();
		window[data.items.outselobj].selection.clear();
		var store = window[data.items.inselobj].store;
		store.fetch({query: {id:new RegExp(data.items.regids)},
			onItem: function(item, request) {
				if(item.inout[0] == 0)
					store.setValue(item, 'inout', 1);
				else
					store.setValue(item, 'inout', 0);
			},
			onComplete: function(item, request) {
				setTimeout(function() {
					// TODO maintain scroll position
					window[data.items.inselobj].setQuery({inout: 1});
					window[data.items.outselobj].setQuery({inout: 0});
				}, 1);
			}
		});
	}
	else if(data.items.status == 'noaccess') {
		alert(_('You do not have access to the submitted resource or group'));
	}
	document.body.style.cursor = 'default';
}

Resource.prototype.toggleResFieldDisplay = function(obj, field) {
	for(var i in resourcegrid.layout.cells) {
		if(resourcegrid.layout.cells[i].field == field) {
			if(obj.checked)
				resourcegrid.layout.setColumnVisibility(i, true);
			else
				resourcegrid.layout.setColumnVisibility(i, false);
			break;
		}
	}
	this.updateFieldCookie(field, obj.checked);
}

Resource.prototype.updateFieldCookie = function(field, selected) {
	var data = dojo.cookie(this.restype + 'selfields');
	if(typeof data === 'undefined') {
		if(selected)
			dojo.cookie(this.restype + 'selfields', field + ':1', {expires: 365});
		else
			dojo.cookie(this.restype + 'selfields', field + ':0', {expires: 365});
	}
	else {
		var items = data.split('|');
		for(var i = 0; i < items.length; i++) {
			var pair = items[i].split(':');
			if(pair[0] == field) {
				if(selected)
					items[i] = field + ':1';
				else
					items[i] = field + ':0';
				break;
			}
		}
		if(i == items.length) {
			if(selected)
				items.push(field + ':1');
			else
				items.push(field + ':0');
		}
		data = items.join('|');
		dojo.cookie(this.restype + 'selfields', data, {expires: 365});
	}
}

Resource.prototype.nocasesort = function(a, b) {
	var al = a.toLowerCase();
	var bl = b.toLowerCase();
	if(al < bl)
		return -1;
	if(bl < al)
		return 1;
	return 0;
}

var resource = new Resource();

var timeout = null;
var ownervalid = false;
var ownerchecking = false;

var resourcetogroupsdata = {
	identifier: 'id',
	label: 'name',
	items: [{id: 1, name: 'foo1'},{id:2,name:'foo2'}]
}

var grouptoresourcesdata = {
	identifier: 'id',
	label: 'name',
	items: []
}

var mapbyresgroupdata = {
	identifier: 'id',
	label: 'name',
	items: []
}

var mapbymaptogroupdata = {
	identifier: 'id',
	label: 'name',
	items: []
}

var resourcetogroupsstore;
var grouptoresourcesstore;
var mapbyresgroupstore;
var mapbymaptogroupstore;

function initViewResources() {
	if(typeof resourcestore === 'undefined') {
		setTimeout(initViewResources, 100);
		return;
	}
	if(! resourcestore.comparatorMap) {
	   resourcestore.comparatorMap = {};
	}
	resourcestore.comparatorMap['name'] = resource.nocasesort;
	setTimeout(function() {resourcegrid.sort();}, 100);
}

function toggleCmapFieldDisplay(obj, field) {
	for(var i in configmapgrid.layout.cells) {
		if(configmapgrid.layout.cells[i].field == field) {
			if(obj.checked)
				configmapgrid.layout.setColumnVisibility(i, true);
			else
				configmapgrid.layout.setColumnVisibility(i, false);
			break;
		}
	}
}

function toggleDeleteResource(rscid) {
	var data = {continuation: dojo.byId('deleteresourcecont').value,
	            rscid: rscid};
	RPCwrapper(data, toggleDeleteResourceCB, 1);
}

function toggleDeleteResourceCB(data, ioArgs) {
	if(data.items.status == 'success') {
		dijit.byId('toggleDeleteDialog').set('title', data.items.title);
		dojo.byId('toggleDeleteHeading').innerHTML = data.items.title;
		dojo.byId('toggleDeleteQuestion').innerHTML = data.items.question;
		dojo.byId('toggleDeleteBtn').innerHTML = data.items.btntxt;
		var txt = '<table>';
		for(var i = 0; i < data.items.fields.length; i++) {
			var item = data.items.fields[i];
			txt += '<tr><th align="right">'
			txt += item.name
			    + ':</th><td>'
			    + resource.colformatter(item.value, '', item) 
			    + '</td></tr>';
		}
		txt += '</table>';
		dojo.byId('confdelrescontent').innerHTML = txt + data.items.html;
		dojo.byId('submitdeletecont').value = data.items.cont;
		dijit.byId('toggleDeleteDialog').show();
	}
	else if(data.items.status == 'noaccess') {
		alert(data.items.msg);
	}
	else if(data.items.status == 'inuse') {
		var btn = new dijit.form.Button({
			label: 'Close'
		});
		var div = document.createElement('DIV');
		div.style = 'text-align: center;';
		var dlg = new dijit.Dialog({
			id: 'resourceinusedlg',
			title: _('Resource In Use'),
			content: data.items.msg,
			style: 'width: 400px;',
			autofocus: false,
			hide: function() {this.destroy();}
		});
		div.appendChild(btn.domNode);
		dlg.containerNode.appendChild(div);
		dojo.connect(btn, "onClick", function () {dlg.destroy();});
		dlg.show();
	}
}

function submitToggleDeleteResource() {
	var data = {continuation: dojo.byId('submitdeletecont').value};
	RPCwrapper(data, submitToggleDeleteResourceCB, 1);
}

function submitToggleDeleteResourceCB(data, ioArgs) {
	if(data.items.status == 'error') {
		alert(_('Problem encountered while attempting to delete resource. Please contact a system administrator.'));
		return;
	}
	else if(data.items.status == 'success') {
		resourcegrid.store.fetch({query: {id: data.items.rscid}, onComplete:
			function(items, request) {
				if(! dijit.byId('showdeleted')) {
					resourcestore.deleteItem(items[0]);
				}
				else {
					var newval = (parseInt(items[0]['deleted']) + 1) % 2;
					resourcestore.setValue(items[0], 'deleted', newval);
				}
				resourcegrid.update();
				// TODO maintain scroll position
				resource.GridFilter();
			}
		});
		clearHideConfirmDelete();
	}
}

function editResource(rscid) {
	var data = {continuation: dojo.byId('editresourcecont').value,
	           inline: 0,
	           rscid: rscid};
	data['inline'] = 1;
	RPCwrapper(data, inlineEditResourceCB, 1);
}

function checkFirstAdd() {
	if(typeof resourcegrid !== 'undefined')
		return;
	window.location.href = dojo.byId('reloadpageurl').value;
}

function caselessSort(a, b) {
	return a.toLowerCase().localeCompare(b.toLowerCase());
}

function clearHideConfirmDelete() {
	dijit.byId('toggleDeleteDialog').hide();
	dojo.byId('confdelrescontent').innerHTML = '';
}

/*function finishUnselect(id) {
	var obj = dijit.byId(id);
	for(var i = 0; i < obj.options.length; i++) {
		if(obj.options[i].selected)
			return;
	}
	dojo.query("[widgetid='" + id + "'] > div > div").forEach(
		function(node, index, nodelist) {
			dojo.removeClass(node, 'dojoxMultiSelectSelectedOption');
		}
	);
}*/

function editGroupMapInit() {
	// getImagesButton getGroupsButton getMapCompGroupsButton getMapImgGroupsButton
	if(dijit.byId('groupbyresourcediv'))
		populateLists('resources', 'ingroups', 'inresourcename', 'outresourcename', 'resgroupinggroupscont');
	if(dijit.byId('groupbygroupdiv'))
		populateLists('resgroups', 'inresources', 'ingroupname', 'outgroupname', 'resgroupingresourcescont');
	if(dojo.byId('domapping').value == '1') {
		if(dijit.byId('mapbyresgroupdiv'))
			populateLists('groups', 'inmapgroups', 'inmapgroupname', 'outmapgroupname', 'mapbyresgroupcont');
		if(dijit.byId('mapbymaptogroupdiv'))
			populateLists('maptogroups', 'inmaptogroups', 'inmaptogroupname', 'outmaptogroupname', 'mapbymaptogroupcont');
	}
}

function populateLists(selobj, inselobj, intitle, outtitle, cont) {
	document.body.style.cursor = 'wait';
	if(! (inselobj in window)) {
		setTimeout(function() {
			populateLists(selobj, inselobj, intitle, outtitle, cont);
		}, 100);
		return;
	}
	var obj = dojo.byId(selobj);
	var id = obj.options[obj.selectedIndex].value;
	var resname = obj.options[obj.selectedIndex].text;

	dojo.byId(intitle).innerHTML = resname;
	dojo.byId(outtitle).innerHTML = resname;

	var data = {continuation: dojo.byId(cont).value,
	            id: id};
	RPCwrapper(data, populateListsCB, 1);
}

function populateListsCB(data, ioArgs) {
	if(data.items.status == 'noaccess') {
		document.body.style.cursor = 'default';
		alert(_('You do not have access to the submitted resource or group'));
		return;
	}
	var oldstore = window[data.items.intitle].store;
	var items = data.items.items;
	var newdata = {
		identifier: 'id',
		label: 'name',
		items: data.items.items
	}
	var newstore = new dojo.data.ItemFileWriteStore({data: newdata});
	if(! newstore.comparatorMap)
		newstore.comparatorMap = {};
	newstore.comparatorMap['name'] = resource.nocasesort;
	window[data.items.intitle].selection.clear();
	window[data.items.outtitle].selection.clear();
	window[data.items.intitle].setStore(newstore);
	window[data.items.outtitle].setStore(newstore);
	window[data.items.intitle].setQuery({inout: 1});
	window[data.items.outtitle].setQuery({inout: 0});
	delete oldstore;
	document.body.style.cursor = 'default';
}

function setOwnerChecking() {
	ownerchecking = true;
}

function checkOwner(val, constraints) {
	if(! dijit.byId('owner')._hasBeenBlurred)
		return true;
	if(timeout != null)
		clearTimeout(timeout);
	timeout = setTimeout(checkOwner2, 700);
	return ownervalid;
}

function checkOwner2() {
	ownerchecking = true;
	var data = {user: dijit.byId('owner').textbox.value,
	            continuation: dojo.byId('valuseridcont').value};
	RPCwrapper(data, checkOwnerCB, 1);
}

function checkOwnerCB(data, ioArgs) {
	var obj = dijit.byId('owner');
	if(data.items.status && data.items.status == 'invalid') {
		obj.attr('state', 'Error');
		obj._setStateClass();
		obj.displayMessage(obj.getErrorMessage('Unknown user'));
		ownervalid = false;
	}
	else {
		obj.attr('state', 'Normal');
		obj._setStateClass();
		obj.displayMessage(null);
		ownervalid = true;
	}
	ownerchecking = false;
}


