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

function Config() {
	Resource.apply(this, Array.prototype.slice.call(arguments));
	this.restype = 'config';
}
Config.prototype = new Resource();

var resource = new Config();

var cfgvartimeout = null;
var nocfgvarupdates = 1;
var newcfgvarid = 15000001;
var newsubimageid = 15000001;

function addNewResource(title) {
	dijit.byId('addeditdlg').set('title', title);
	dijit.byId('addeditbtn').set('label', title);
	dojo.removeClass('configvariables', 'hidden');
	dojo.addClass('editcfgvardiv', 'hidden');
	dojo.byId('editresid').value = 0;
	configSetType();
	dijit.byId('type').set('disabled', false);
	dijit.byId('name').reset();
	dijit.byId('owner').reset();
	dijit.byId('optionalchk').reset();
	dijit.byId('subimageid').reset();
	var newdata = {
		identifier: 'id',
		label: 'name',
		items: []
	}
	var newstore = new dojo.data.ItemFileWriteStore({data: newdata});
	newstore.comparatorMap = {'name': caselessSort};
	subimagegrid.setStore(newstore);
	dijit.byId('vlanid').reset();
	resetCfgVarFields();
	dojo.byId('data').value = '';
	dojo.byId('addeditdlgerrmsg').innerHTML = '';
	var vardata = {identifier: 'id', label: 'name', items: []};
	newstore = new dojo.data.ItemFileWriteStore({data: vardata});
	var oldstore = configvariablegrid.store;
	configvariablegrid.setStore(newstore);
	delete oldstore;
	dijit.byId('addeditdlg').show();
}

function inlineEditResourceCB(data, ioArgs) {
	if(data.items.status == 'success') {
		dojo.byId('saveresourcecont').value = data.items.cont;
		dijit.byId('addeditdlg').set('title', data.items.title);
		dijit.byId('addeditbtn').set('label', 'Save Changes');
		dojo.byId('editresid').value = data.items.resid;
		dijit.byId('type').set('value', data.items.data.configtypeid);
		dijit.byId('type').set('disabled', true);
		configSetType();
		dijit.byId('name').set('value', data.items.data.name);
		dijit.byId('owner').set('value', data.items.data.owner);
		var vars = data.items.data.variables;
		if(data.items.data.optional == 0)
			dijit.byId('optionalchk').set('checked', false);
		else
			dijit.byId('optionalchk').set('checked', true);
		if(data.items.data.configtype == 'Cluster') {
			nocfgvarupdates = 1;
			var vardata = {identifier: 'id', label: 'name', items: vars};
			var newstore = new dojo.data.ItemFileWriteStore({data: vardata});
			newstore.comparatorMap = {'name': caselessSort};
			var oldstore = subimagegrid.store;
			subimagegrid.setStore(newstore);
			if(subimagegrid.selection.selectedIndex >= 0)
				subimagegrid.selection.setSelected(subimagegrid.selection.selectedIndex, false);
			subimagegrid.selection.lastindex = -1;
			subimagegrid.setQuery({deleted: '0'});
			setTimeout(function() {subimagegrid.update();}, 1);
			delete oldstore;
		}
		else if(data.items.data.configtype == 'VLAN') {
			nocfgvarupdates = 1;
			dijit.byId('vlanid').set('value', data.items.data.data);
		}
		else {
			nocfgvarupdates = 0;
			dojo.byId('data').value = data.items.data.data;
			resetCfgVarFields();
			var vardata = {identifier: 'id', label: 'name', items: vars};
			var newstore = new dojo.data.ItemFileWriteStore({data: vardata});
			var oldstore = configvariablegrid.store;
			configvariablegrid.setStore(newstore);
			if(configvariablegrid.selection.selectedIndex >= 0)
				configvariablegrid.selection.setSelected(configvariablegrid.selection.selectedIndex, false);
			configvariablegrid.selection.lastindex = -1;
			setTimeout(function() {configvariablegrid.update();}, 1);
			delete oldstore;
		}
		dijit.byId('addeditdlg').show();
	}
	else if(data.items.status == 'noaccess') {
		alert('Access denied to edit this item');
	}
}

function saveResource() {
	if(! updateConfigVariable())
		return;
	var submitbtn = dijit.byId('addeditbtn');
	var errobj = dojo.byId('addeditdlgerrmsg');
	if(! checkValidatedObj('name', errobj))
		return;
	/*if(! dijit.byId('owner')._hasBeenBlurred && dijit.byId('owner').get('value') == '') {
		dijit.byId('owner')._hasBeenBlurred = true;
		dijit.byId('owner').validate();
		submitbtn.set('disabled', true);
		setTimeout(function() {
			saveResource();
			submitbtn.set('disabled', false);
		}, 1000);
		return;
	}*/
	if(ownerchecking) {
		submitbtn.set('disabled', true);
		setTimeout(function() {
			saveResource();
			submitbtn.set('disabled', false);
		}, 1000);
		return;
	}
	if(! checkValidatedObj('owner', errobj))
		return;
	if(dojo.byId('editresid').value == 0)
		var data = {continuation: dojo.byId('addresourcecont').value};
	else
		var data = {continuation: dojo.byId('saveresourcecont').value};
	var type = dijit.byId('type').get('displayedValue');
	if(! dojo.hasClass('configdatadiv', 'hidden')) {
		if(dojo.byId('data').value == '') {
			var typename = dojo.byId('datalabel').innerHTML;
			errobj.innerHTML = typename + ' cannot be empty';
			return;
		}
		data['data'] = dojo.byId('data').value;
		data['configvariables'] = serializeConfigVars();
	}
	if(type == 'Cluster') {
		data['subimages'] = serializeConfigSubimages();
		if(data['subimages'] == '') {
			errobj.innerHTML = 'No subimages assigned';
			return;
		}
	}
	else if(type == 'VLAN') {
		if(! checkValidatedObj('vlanid', errobj))
			return;
		data['vlanid'] = dijit.byId('vlanid').get('value');
	}
	data['typeid'] = dijit.byId('type').get('value');
	data['name'] = dijit.byId('name').get('value');
	data['owner'] = dijit.byId('owner').get('value');
	if(dijit.byId('optionalchk').checked)
		data['optional'] = 1;
	else
		data['optional'] = 0;
	submitbtn.set('disabled', true);
	RPCwrapper(data, saveResourceCB, 1);
}

function saveResourceCB(data, ioArgs) {
	if(data.items.status == 'error') {
		if(data.items.msg == 'cannot be empty')
			data.items.msg = dojo.byId('datalabel').innerHTML + ' cannot be empty';
		dojo.byId('addeditdlgerrmsg').innerHTML = data.items.msg;
		dijit.byId('addeditbtn').set('disabled', false);
		return;
	}
	else if(data.items.status == 'success') {
		if(data.items.action == 'add') {
			resourcegrid.store.newItem(data.items.item);
			resourcegrid.sort();
		}
		else {
			resourcegrid.store.fetch({
				query: {id: data.items.data.id},
				onItem: function(item) {
					resourcegrid.store.setValue(item, 'name', data.items.data.name);
					resourcegrid.store.setValue(item, 'owner', data.items.data.owner);
					resourcegrid.store.setValue(item, 'data', data.items.data.data);
					resourcegrid.store.setValue(item, 'optional', data.items.data.optional);
				},
				onComplete: function(items, result) {
					// when call resourcegrid.sort directly, the table contents disappear; not sure why
					setTimeout(function() {resourcegrid.sort();}, 10);
				}
			});
		}
		dijit.byId('type').reset();
		dijit.byId('name').reset();
		dijit.byId('owner').reset();
		dijit.byId('optionalchk').reset();
		dijit.byId('subimageid').reset();
		dijit.byId('vlanid').reset();
		dojo.byId('data').value = '';
		dojo.byId('addeditdlgerrmsg').innerHTML = '';
		dijit.byId('addeditdlg').hide();
		setTimeout(function() {dijit.byId('addeditbtn').set('disabled', false);}, 250);
	}
}

// --------------------------------------

function resetCfgVarFields() {
	dojo.byId('varid').value = '';
	dijit.byId('varname').reset();
	dijit.byId('varidentifier').reset();
	dijit.byId('cfgvartype').reset();
	setCfgVarType(1);
	resetCfgVarTypeValues();
	dijit.byId('varrequired').reset();
	dijit.byId('varask').reset();
	dojo.addClass('editcfgvardiv', 'hidden');
}

function resetCfgVarTypeValues() {
	var options = dijit.byId('cfgvartype').options;
	for(var i = 0; i < options.length; i++)
		dijit.byId('vartype' + options[i].label).reset();
}

function setCfgVarType(noupdate) {
	if(typeof noupdate === 'undefined')
		noupdate = 0;
	var type = dijit.byId('cfgvartype').get('displayedValue');
	var options = dijit.byId('cfgvartype').options;
	for(var i = 0; i < options.length; i++) {
		var t = options[i].label;
		dojo.addClass('vartype' + t + 'span', 'hidden');
	}
	dojo.removeClass('vartype' + type + 'span', 'hidden');
	if(noupdate)
		return;
	updateConfigVariable();
}

function configVarAllowSelection(row) {
	if(row == configvariablegrid.selection.lastindex)
		return true;
	if(! updateConfigVariable()) {
		setTimeout(function() {
			configvariablegrid.selection.setSelected(configvariablegrid.selection.lastindex, true);
		}, 1);
		return false;
	}
}

function configVarSelected(row) {
	if(! updateConfigVariable())
		return;
	dojo.removeClass('editcfgvardiv', 'hidden');
	var item = configvariablegrid.getItem(row);
	if(! item)
		return;
	nocfgvarupdates = 1;
	if(item.deleted == 1) {
		dojo.addClass('editcfgvardiv', 'hidden');
		dojo.removeClass('undeletecfgvardiv', 'hidden');
	}
	else {
		dojo.addClass('undeletecfgvardiv', 'hidden');
		dojo.removeClass('editcfgvardiv', 'hidden');
	}
	dijit.byId('deletecfgvarbtn').set('disabled', false);
	dojo.byId('varid').value = item.id;
	dijit.byId('varname').set('value', item.name);
	dijit.byId('varidentifier').set('value', item.identifier);
	resetCfgVarTypeValues();
	dijit.byId('cfgvartype').set('value', parseInt(item.datatypeid));
	var type = dijit.byId('cfgvartype').get('displayedValue');
	if(type == 'text')
		dijit.byId('vartypetext').set('value', new String(item.defaultvalue));
	else
		dijit.byId('vartype' + type).set('value', item.defaultvalue);
	setCfgVarType();
	if(item.required == 1)
		dijit.byId('varrequired').set('checked', true);
	else
		dijit.byId('varrequired').set('checked', false);
	if(item.ask == 1)
		dijit.byId('varask').set('checked', true);
	else
		dijit.byId('varask').set('checked', false);
	configvariablegrid.selection.lastindex = row;
	nocfgvarupdates = 0;
}

function addCfgSubimage() {
	var min = new dijit.form.NumberSpinner({
		value: 1,
		smallDelta: 1,
		constraints: {min: 1, max: 5000, places: 0},
		style: 'width: 40px'
	});
	var item = {id: newsubimageid,
	            imageid: dijit.byId('subimageid').get('value'),
	            name: dijit.byId('subimageid').get('displayedValue'),
	            min: 1,
	            max: 1,
	            deleted: '0'};
	subimagegrid.store.newItem(item);
	subimagegrid.sort();
	setTimeout(function() {
		if(subimagegrid.selection.selectedIndex >= 0)
			subimagegrid.selection.setSelected(subimagegrid.selection.selectedIndex, false);
		// TODO fix problem of another row being highlighted due to being the focused row
		for(var i = 0, last = subimagegrid.rowCount; i < last; i++) {
			if((subimagegrid.getItem(i)) && subimagegrid.getItem(i).id == newsubimageid) {
				subimagegrid.selection.setSelected(i, true);
				break;
			}
		}
		newsubimageid++;
		subimagegrid.scrollToRow(subimagegrid.selection.selectedIndex);
		subimagegrid.update();
	}, 1);
}

function removeSubimages() {
	var items = subimagegrid.selection.getSelected();
	for(var i = 0; i < items.length; i++) {
		subimagegrid.store.fetch({
			query: {id: items[i].id[0]},
			onItem: function(item) {
				subimagegrid.store.setValue(item, 'deleted', '1');
			}
		});
	}
	subimagegrid.selection.clear();
	subimagegrid.sort();
}

function addNewConfigVar() {
	if(! updateConfigVariable()) {
		return;
	}
	var item = {id: newcfgvarid,
	            name: 'new variable',
	            identifier: '',
	            datatypeid: '1',
	            defaultvalue: 0,
	            required: 0,
	            ask: 1,
	            deleted: 0,
	            configid: dojo.byId('editresid').value};
	configvariablegrid.store.newItem(item);
	configvariablegrid.sort();
	setTimeout(function() {
		if(configvariablegrid.selection.selectedIndex >= 0)
			configvariablegrid.selection.setSelected(configvariablegrid.selection.selectedIndex, false);
		// TODO fix problem of another row being highlighted due to being the focused row
		for(var i = 0, last = configvariablegrid.rowCount; i < last; i++) {
			if((configvariablegrid.getItem(i)) && configvariablegrid.getItem(i).id == newcfgvarid) {
				configvariablegrid.selection.setSelected(i, true);
				break;
			}
		}
		newcfgvarid++;
		configvariablegrid.scrollToRow(configvariablegrid.selection.selectedIndex);
		configvariablegrid.update();
	}, 1);
}

function updateConfigVariable() {
	if(nocfgvarupdates)
		return 1;
	if(dojo.hasClass('editcfgvardiv', 'hidden'))
		return 1;
	var varid = dojo.byId('varid').value;
	if(varid == '')
		return 1;
	if(! checkValidatedObj('varname', null))
		return 0;
	if(! checkValidatedObj('varidentifier', null))
		return 0;
	var name = dijit.byId('varname').get('value');
	var identifier = dijit.byId('varidentifier').get('value');
	var type = dijit.byId('cfgvartype').get('displayedValue');
	var typeid = dijit.byId('cfgvartype').get('value');
	if(type == 'bool') {
		var defaultvalue = dijit.byId('vartypebool').get('value');
	}
	else if(type == 'text') {
		var defaultvalue = dijit.byId('vartypetext').get('value');
	}
	else {
		if(! checkValidatedObj('vartype' + type, null))
			return 0;
		var defaultvalue = dijit.byId('vartype' + type).get('value');
	}
	if(dijit.byId('varrequired').get('checked'))
		var required = 1;
	else
		var required = 0;
	if(dijit.byId('varask').get('checked'))
		var ask = 1;
	else
		var ask = 0;
	configvariablegrid.store.fetch({
		query: {id: varid},
		onItem: function(item) {
			var store = configvariablegrid.store;
			store.setValue(item, 'name', name);
			store.setValue(item, 'identifier', identifier);
			store.setValue(item, 'datatypeid', typeid);
			store.setValue(item, 'defaultvalue', defaultvalue);
			store.setValue(item, 'required', required);
			store.setValue(item, 'ask', ask);
		}
	});
	return 1;
}

function delayedUpdateConfigVariable() {
	clearTimeout(cfgvartimeout);
	cfgvartimeout = setTimeout(updateConfigVariable, 1000);
}

function deleteConfigVariable() {
	if(dojo.byId('varid').value == '')
		return;
	dojo.addClass('editcfgvardiv', 'hidden');
	dojo.removeClass('undeletecfgvardiv', 'hidden');
	configvariablegrid.store.fetch({
		query: {id: dojo.byId('varid').value},
		onItem: function(item) {
			var store = configvariablegrid.store;
			store.setValue(item, 'deleted', 1);
		}
	});
}

function undeleteConfigVariable() {
	if(dojo.byId('varid').value == '')
		return;
	var node = configvariablegrid.views.views[0].getCellNode(configvariablegrid.selection.selectedIndex, 0);
	dojo.removeClass(node, 'strikethrough');
	dojo.addClass('undeletecfgvardiv', 'hidden');
	dojo.removeClass('editcfgvardiv', 'hidden');
	configvariablegrid.store.fetch({
		query: {id: dojo.byId('varid').value},
		onItem: function(item) {
			var store = configvariablegrid.store;
			store.setValue(item, 'deleted', 0);
		}
	});
}

function configVarListStyle(row) {
	var item = configvariablegrid.getItem(row.index);
	if(item) {
		var deleted = configvariablegrid.store.getValue(item, 'deleted');
		if(deleted == 1)
			row.customClasses += ' strikethrough';
	}
	configvariablegrid.focus.styleRow(row);
	configvariablegrid.edit.styleRow(row);
}

function addStrikethrough() {
	var node = configvariablegrid.views.views[0].getCellNode(configvariablegrid.selection.selectedIndex, 0);
	dojo.addClass(node, 'strikethrough');
}

function serializeConfigVars() {
	var cfgvars = [];
	var tmp = configvariablegrid.store._getItemsArray();
	for(var i = 0; i < tmp.length; i++) {
		if(tmp[i]['deleted'] == 1 && tmp[i]['id'] > 15000000)
			continue;
		var myvar = '';
		myvar  = '"' + tmp[i]['id'];
		myvar += '":{"id":"' + tmp[i]['id'];
		myvar += '","name":"' + tmp[i]['name'];
		myvar += '","identifier":"' + tmp[i]['identifier'];
		myvar += '","datatypeid":"' + tmp[i]['datatypeid'];
		var datatype = getCfgVarType(tmp[i]['datatypeid']);
		if(datatype == 'text')
			myvar += '","defaultvalue":"' + tmp[i]['defaultvalue'][0].replace(/\n/g, '\\n');
		else
			myvar += '","defaultvalue":"' + tmp[i]['defaultvalue'];
		myvar += '","required":"' + tmp[i]['required'];
		myvar += '","ask":"' + tmp[i]['ask'];
		myvar += '","deleted":"' + tmp[i]['deleted'];
		myvar += '"}';
		cfgvars.push(myvar);
	}
	var all = cfgvars.join(',');
	return '{"items":{' + all + '}}';
}

function serializeConfigSubimages() {
	var subimages = [];
	var tmp = subimagegrid.store._getItemsArray();
	if(tmp.length == 0)
		return '';
	for(var i = 0; i < tmp.length; i++) {
		if(tmp[i]['deleted'] == 1 && tmp[i]['id'] > 15000000)
			continue;
		var myvar = '';
		myvar  = '"' + tmp[i]['id'];
		myvar += '":{"id":"' + tmp[i]['id'];
		myvar += '","imageid":"' + tmp[i]['imageid'];
		myvar += '","min":"' + tmp[i]['min'];
		myvar += '","max":"' + tmp[i]['max'];
		myvar += '","deleted":"' + tmp[i]['deleted'];
		myvar += '"}';
		subimages.push(myvar);
	}
	var all = subimages.join(',');
	return '{"items":{' + all + '}}';
}

function getCfgVarType(id) {
	var options = dijit.byId('cfgvartype').options;
	for(var i = 0; i < options.length; i++) {
		if(options[i].value == id)
			return options[i].label;
	}
}

function configSetType() {
	var type = dijit.byId('type').get('displayedValue');
	dojo.removeClass('configdatadiv', 'hidden');
	dojo.removeClass('configvariables', 'hidden');
	dojo.addClass('subimageextradiv', 'hidden');
	dojo.addClass('vlanextradiv', 'hidden');
	dojo.byId('datalabel').innerHTML = type;
	if(type == 'Cluster') { // TODO - might need to be updated
		dojo.addClass('configdatadiv', 'hidden');
		dojo.addClass('configvariables', 'hidden');
		dojo.removeClass('subimageextradiv', 'hidden');
		dojo.addClass('vlanextradiv', 'hidden');
	}
	else if(type == 'VLAN') {
		dojo.addClass('configdatadiv', 'hidden');
		dojo.addClass('configvariables', 'hidden');
		dojo.addClass('subimageextradiv', 'hidden');
		dojo.removeClass('vlanextradiv', 'hidden');
	}
	recenterDijitDialog('addeditdlg');
}

function fmtConfigMapDeleteBtn(configmapid, rowIndex) {
	var btn = new dijit.form.Button({
		label: 'Delete',
		onClick: function() {
			deleteConfigMapping(configmapid);
		}
	});
	btn._destroyOnRemove = true;
	return btn;
}

function fmtConfigMapEditBtn(configmapid, rowIndex) {
	var btn = new dijit.form.Button({
		label: 'Edit',
		onClick: function() {
			editConfigMapping(configmapid);
		}
	});
	btn._destroyOnRemove = true;
	return btn;
}

function deleteConfigMapping(configmapid) {
	var data = {configmapid: configmapid,
	            continuation: dojo.byId('deletecfgmapcont').value};
	RPCwrapper(data, deleteConfigMappingCB, 1);
}

function deleteConfigMappingCB(data, ioArgs) {
	// TODO handle errors
	if(data.items.status == 'success') {
		dojo.byId('delcfgmapdlgcontent').innerHTML = data.items.html;
		dojo.byId('submitdeletecfgmapcont').value = data.items.cont;
		dijit.byId('delcfgmapdlg').show();
	}
	else if(data.items.status == 'notfound') {
		alert("Error occurred: Config mapping not found");
	}
}

function submitDeleteConfigMapping() {
	var data = {continuation: dojo.byId('submitdeletecfgmapcont').value};
	RPCwrapper(data, submitDeleteConfigMappingCB, 1);
}

function submitDeleteConfigMappingCB(data, ioArgs) {
	// TODO handle errors
	if(data.items.status == 'success') {
		dijit.byId('delcfgmapdlg').hide();
		dojo.byId('delcfgmapdlgcontent').innerHTML = '';
		dojo.byId('submitdeletecfgmapcont').value = '';
		configmapgrid.store.fetch({
			query: {id: data.items.configmapid},
			onItem: function(item) {
				configmapgrid.store.deleteItem(item);
			}
		});
	}
}

function editConfigMapping(configmapid) {
	dojo.byId('editcfgmapid').value = configmapid;
	var data = {configmapid: configmapid,
	            continuation: dojo.byId('editcfgmapcont').value};
	RPCwrapper(data, editConfigMappingCB, 1);
}

function editConfigMappingCB(data, ioArgs) {
	dojo.byId('savecfgmapcont').value = data.items.cont;
	dijit.byId('addeditcfgmapdlg').set('title', 'Edit Config Mapping');
	dijit.byId('addeditcfgmapbtn').set('label', 'Save Changes');
	dijit.byId('config')._lastValueReported = data.items.data.configid;
	dijit.byId('config').set('value', data.items.data.configid, false);
	if(data.items.data.configtype == 'Cluster')
		dijit.byId('maptype').setStore(maptypestore, '', {query: {clusterok: '1'}});
	else
		dijit.byId('maptype').setStore(maptypestore, '', {query: {id: '*'}});
	dijit.byId('maptype').set('value', data.items.data.configmaptypeid);
	dijit.byId('affil').set('value', data.items.data.affiliationid);
	dijit.byId('stage').set('value', data.items.data.stageid);
	if(data.items.data.prettyconfigmaptype == 'Image')
		dijit.byId('image').set('value', data.items.data.subid);
	else if(data.items.data.prettyconfigmaptype == 'OS Type')
		dijit.byId('ostype').set('value', data.items.data.subid);
	else if(data.items.data.prettyconfigmaptype == 'OS')
		dijit.byId('os').set('value', data.items.data.subid);
	else if(data.items.data.prettyconfigmaptype == 'Config')
		dijit.byId('mapconfig').set('value', data.items.data.subid);
	else if(data.items.data.prettyconfigmaptype == 'Subimage')
		dijit.byId('configsubimage').set('value', data.items.data.subid);
	else if(data.items.data.prettyconfigmaptype == 'Management Node')
		dijit.byId('managementnode').set('value', data.items.data.subid);
	editConfigMapSetMapType();
	dijit.byId('addeditcfgmapdlg').show();
}

function configMapSetConfig() {
	var id = dijit.byId('config').get('value');
	mapconfigliststore.fetch({
		query: {id: id},
		onItem: function(item) {
			if(item.stage[0] === null)
				dojo.removeClass('stagediv', 'hidden');
			else
				dojo.addClass('stagediv', 'hidden');
			dojo.byId('mapconfigtype').innerHTML = item.configtype;
			var queryobj = dijit.byId('maptype').params.query;
			if(item.configtype == 'Cluster') {
				//if(typeof queryobj.clusterid === 'undefined')
					dijit.byId('maptype').setStore(maptypestore, '', {query: {clusterok: '1'}});
			}
			else {
				//if(typeof queryobj.id === 'undefined')
					dijit.byId('maptype').setStore(maptypestore, '', {query: {id: '*'}});
			}
		}
	});
}

function editConfigMapSetMapType() {
	var maptype = dijit.byId('maptype').get('displayedValue');
	dojo.addClass('imagetypediv', 'hidden');
	dojo.addClass('ostypediv', 'hidden');
	dojo.addClass('osdiv', 'hidden');
	dojo.addClass('configdiv', 'hidden');
	dojo.addClass('configsubimagediv', 'hidden');
	dojo.addClass('managementnodediv', 'hidden');
	if(maptype == 'Image')
		dojo.removeClass('imagetypediv', 'hidden');
	else if(maptype == 'OS Type')
		dojo.removeClass('ostypediv', 'hidden');
	else if(maptype == 'OS')
		dojo.removeClass('osdiv', 'hidden');
	else if(maptype == 'Config')
		dojo.removeClass('configdiv', 'hidden');
	else if(maptype == 'Subimage')
		dojo.removeClass('configsubimagediv', 'hidden');
	else if(maptype == 'Management Node')
		dojo.removeClass('managementnodediv', 'hidden');
}

function addConfigMapping() {
	dojo.byId('editcfgmapid').value = 0;
	dijit.byId('addeditcfgmapdlg').set('title', 'Add Config Mapping');
	dijit.byId('addeditcfgmapbtn').set('label', 'Add Config Mapping');
	resetConfigMappingFields();
	editConfigMapSetMapType();
	dijit.byId('addeditcfgmapdlg').show();
}

function saveConfigMapping() {
	var errobj = dojo.byId('addeditcfgmapdlgerrmsg');
	if(! checkValidatedObj('config', errobj))
		return;
	var maptype = dijit.byId('maptype').get('displayedValue');
	if((maptype == 'Image' && ! checkValidatedObj('image', errobj)) ||
	   (maptype == 'OS Type' && ! checkValidatedObj('ostype', errobj)) ||
	   (maptype == 'OS' && ! checkValidatedObj('os', errobj)) ||
	   (maptype == 'Config' && ! checkValidatedObj('mapconfig', errobj)) ||
	   (maptype == 'Subimage' && ! checkValidatedObj('configsubimage', errobj)) ||
	   (maptype == 'Management Node' && ! checkValidatedObj('managementnode', errobj)))
		return;
	if(! checkValidatedObj('affil', errobj) ||
	   ! checkValidatedObj('stage', errobj))
		return;

	var data = {configmapid: dojo.byId('editcfgmapid').value,
	            configid: dijit.byId('config').get('value'),
	            maptypeid: dijit.byId('maptype').get('value'),
	            affiliationid: dijit.byId('affil').get('value'),
	            stageid: dijit.byId('stage').get('value')};
	if(dijit.byId('addeditcfgmapbtn').get('label') == 'Add Config Mapping')
		data.continuation = dojo.byId('addcfgmapcont').value;
	else
		data.continuation = dojo.byId('savecfgmapcont').value;
	if(maptype == 'Image')
		data.subid = dijit.byId('image').get('value');
	else if(maptype == 'OS Type')
		data.subid = dijit.byId('ostype').get('value');
	else if(maptype == 'OS')
		data.subid = dijit.byId('os').get('value');
	else if(maptype == 'Config')
		data.subid = dijit.byId('mapconfig').get('value');
	else if(maptype == 'Subimage')
		data.subid = dijit.byId('configsubimage').get('value');
	else if(maptype == 'Management Node')
		data.subid = dijit.byId('managementnode').get('value');
	dijit.byId('addeditcfgmapbtn').set('disabled', true);
	RPCwrapper(data, saveConfigMappingCB, 1);
}

function saveConfigMappingCB(data, ioArgs) {
	if(data.items.status == 'error') {
		dojo.byId('addeditcfgmapdlgerrmsg').innerHTML = data.items.msg;
		dijit.byId('addeditcfgmapbtn').set('disabled', false);
	}
	else if(data.items.status == 'success') {
		if(data.items.action == 'add') {
			configmapgrid.store.newItem(data.items.item);
			configmapgrid.sort();
		}
		else {
			configmapgrid.store.fetch({
				query: {id: data.items.data.id},
				onItem: function(item) {
					for(var key in data.items.data) {
						if(key == 'id')
							continue;
						configmapgrid.store.setValue(item, key, data.items.data[key]);
					}
				},
				onComplete: function(items, result) {
					// when call resourcegrid.sort directly, the table contents disappear; not sure why
					setTimeout(function() {configmapgrid.sort();}, 10);
				}
			});
		}
		dijit.byId('addeditcfgmapdlg').hide();
		resetConfigMappingFields();
		setTimeout(function() {dijit.byId('addeditcfgmapbtn').set('disabled', false)}, 250);
	}
}

function resetConfigMappingFields() {
	dijit.byId('config').reset();
	dijit.byId('maptype').reset();
	dijit.byId('image').reset();
	dijit.byId('ostype').reset();
	dijit.byId('os').reset();
	dijit.byId('mapconfig').reset();
	dijit.byId('configsubimage').reset();
	dijit.byId('managementnode').reset();
	dijit.byId('affil').reset();
	dijit.byId('stage').reset();
	dojo.byId('addeditcfgmapdlgerrmsg').innerHTML = '';
}
