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

function Computer() {
	Resource.apply(this, Array.prototype.slice.call(arguments));
	this.selids = [];
	this.selectingall = false;
	this.restype = 'computer';
}
Computer.prototype = new Resource();

var filterstore;
var filtercbstores = {};
var extrafiltergrid;
var savescroll = 0;
var editobj;
var addedit = 'edit';
var lastselected = {blade: {provisioningid: '', stateid: ''},
                    lab: {provisioningid: '', stateid: ''},
                    virtualmachine: {provisioningid: '', stateid: ''}};
var filterdelay;

String.prototype.ucfirst = function() {
	return this.charAt(0).toUpperCase() + this.slice(1);
}

Computer.prototype.DeleteBtn = function(rscid, rowIndex) {
	var rowdata = this.grid.getItem(rowIndex);
	if(! ('deleted' in rowdata) || rowdata.deleted == '0') {
		var id = 'chkb' + rowdata.id; 
		if(dojo.indexOf(resource.selids, id) != -1)
			var checked = true;
		else
			var checked = false;
		var cb = new dijit.form.CheckBox({
			id: id,
			value: rowdata.id,
			checked: checked,
			onClick: selectRow
		});
		cb._destroyOnRemove = true;
		return cb;
	}
	// resource has deleted set
	return '&nbsp;';
}

Computer.prototype.EditBtn = function(rscid, rowIndex) {
	var rowdata = this.grid.getItem(rowIndex);
	if(! ('deleted' in rowdata) || rowdata.deleted == '0') {
		var btn = new dijit.form.Button({
			label: 'Edit',
			onClick: function() {
				editResource(rscid);
			}
		});
	}
	else {
		var btn = new dijit.form.Button({
			label: 'Undelete',
			onClick: function() {
				toggleDeleteResource(rscid);
			}
		});
	}
	btn._destroyOnRemove = true;
	return btn;
}

Computer.prototype.colformatter = function(value, rowIndex, obj) {
	if(obj.field == 'state') {
		if(value == 'failed')
			return '<span class="rederrormsg">failed</span>';
		if(value == 'available')
			return '<span class="ready">available</span>';
		if(value == 'reloading')
			return '<span class="wait">reloading</span>';
	}
	else if(obj.field == 'notes' && value) {
		return value.replace('@', '<br>').replace(/\n/g, '<br>');
	}
	else if(obj.field == 'deleted' ||
	        obj.field == 'natenabled' ||
	        obj.field == 'nathostenabled') {
		if(value == "0")
			return '<span class="rederrormsg">false</span>';
		if(value == "1")
			return '<span class="ready">true</span>';
	}
	return value;
}

Computer.prototype.toggleResFieldDisplay = function(obj, field) {
	for(var i in resourcegrid.layout.cells) {
		if(resourcegrid.layout.cells[i].field == field) {
			if(obj.checked) {
				resourcegrid.layout.setColumnVisibility(i, true);
				extrafiltergrid.layout.setColumnVisibility(i, true);
			}
			else {
				resourcegrid.layout.setColumnVisibility(i, false);
				extrafiltergrid.layout.setColumnVisibility(i, false);
				delete resourcegrid.query[field];
				resourcegrid.setQuery(resourcegrid.query);
			}
			break;
		}
	}
	this.updateFieldCookie(field, obj.checked);
}

Computer.prototype.GridFilter = function() {
	if(dijit.byId('showdeleted').get('value')) {
		var width = '5.1em';
		var showdeleted = '*';
	}
	else {
		var width = '3em';
		var showdeleted = '0';
	}
	resourcegrid.setCellWidth(1, width);
	resourcegrid.layout.cells[1].view.update();
	extrafiltergrid.setCellWidth(1, width);
	extrafiltergrid.layout.cells[1].view.update();

	var query = resourcegrid.query;
	query['deleted'] = showdeleted;

	resourcegrid.setQuery(query);
}

function filterKeyDown(e) {
	if(e.keyCode == dojo.keys.ENTER) {
		dojo.stopEvent(e);
		dijit.byId('ownercb').focus();
		var focusnext = 0;
		var cells = extrafiltergrid.layout.cells;
		for(var i = 2; i < cells.length; i++) {
			if(focusnext && ! cells[i].hidden) {
				dijit.byId(cells[i].field + 'cb').focus();
				focusnext = 2;
				break;
			}
			if(cells[i].field + 'cb' == e.target.id) {
				focusnext = 1;
				continue;
			}
		}
		if(focusnext == 1)
			dijit.byId(cells[2].field + 'cb').focus();
	}
}

Computer.prototype.Selection = function() {
	// TODO this messes up when all rows have been selected with selectAllRows
	//      and then a row is unselected because this function only handles
	//      rendered rows
	var sel = resourcegrid.selection.selected;
	if(! resource.selectingall) {
		dojo.forEach(resource.selids, function(id) {
			if(dijit.byId(id))
				dijit.byId(id).set('checked', false);
		});
		resource.selids = [];
	}
	for(var i = 0; i < sel.length; i++) {
		if(sel[i]) {
			var comp = resourcegrid.getItem(i);
			if(! resource.selectingall) {
				if(! parseInt(comp.deleted))
					resource.selids.push('chkb' + comp.id);
				else
					resourcegrid.selection.deselect(comp);
			}
			if(dijit.byId('chkb' + comp.id))
				dijit.byId('chkb' + comp.id).set('checked', true);
		}
	}
	if(resource.selids.length != resourcegrid.rowCount)
		dijit.byId('selectallchkb').set('checked', false);
	else
		dijit.byId('selectallchkb').set('checked', true);
}

Computer.prototype.nocasesort = function(a, b) {
	var al = a.toLowerCase();
	var bl = b.toLowerCase();
	if(al.match(/[0-9]/) ||
	   bl.match(/[0-9]/)) {
		return resource.comparehostnames(al, bl);
	}
	if(al < bl)
		return -1;
	if(bl < al)
		return 1;
	return 0;
}

Computer.prototype.comparehostnames = function(a, b) {
	// get hostname
	var tmp = a.split('.');
	var h1 = tmp.shift();
	var letters1 = h1.replace(/([^a-zA-Z])/g, '');

	tmp = b.split('.');
	var h2 = tmp.shift();
	var letters2 = h2.replace(/([^a-zA-Z])/g, '');

	// if non-numeric part is different, return based on that
	cmp = letters1.localeCompare(letters2);
	if(cmp)
		return cmp;

	// at this point, the only difference is in the numbers
	var digits1 = h1.replace(/([^\d-])/g, '');
	var digits1Arr = digits1.split('-');
	var digits2 = h2.replace(/([^\d-])/g, '');
	var digits2Arr = digits2.split('-');

	var len1 = digits1Arr.length;
	var len2 = digits2Arr.length;
	for(var i = 0; i < len1 && i < len2; i++) {
		if(parseInt(digits1Arr[i]) < parseInt(digits2Arr[i]))
			return -1;
		else if(parseInt(digits1Arr[i]) > parseInt(digits2Arr[i]))
			return 1;
	}

	return 0;
}

var resource = new Computer();

function initPage() {
	if(dojo.byId('reloadpageurl'))
		return;
	document.body.style.cursor = 'wait';
	if(! ('resourcegrid' in window)) {
		setTimeout(function() {
			initPage();
		}, 100);
		return;
	}
	else {
		document.body.style.cursor = 'default';
		buildExtraFilters();
		
		// set width of first column
		resourcegrid.setCellWidth(0, '21px');
		resourcegrid.layout.cells[0].view.update();

		// connect selection
		dojo.connect(resourcegrid, 'onSelectionChanged', this, resource.Selection);

		// hide resource name filter
		dojo.addClass('namefilter', 'hidden');

		// connect scrolling stuff
		dojo.connect(resourcegrid, 'postrender', setScroll);
		dojo.connect(resourcegrid.views.views[0].scrollboxNode, 'onscroll', saveScroll);

		// select all computer groups
		for(var i = 0; i < dojo.byId('filtercompgroups').options.length; i++) {
			dojo.byId('filtercompgroups').options[i].selected = true;
		}

		// confirm new nathost button
		if(dijit.byId('newnathostid').options.length == 0)
			dijit.byId('newnathostbtn').set('disabled', true);

		clearTimeout(filterdelay);

		if(! resourcestore.comparatorMap) {
			resourcestore.comparatorMap = {};
		}
		resourcestore.comparatorMap['ram'] = resource.nocasesort;
		resourcestore.comparatorMap['procnumber'] = resource.nocasesort;
		resourcestore.comparatorMap['procspeed'] = resource.nocasesort;
		resourcestore.comparatorMap['network'] = resource.nocasesort;

		dojo.connect(resourcegrid, '_onFetchComplete', function() {dojo.byId('computercount').innerHTML = 'Computers in table: ' + resourcegrid.rowCount;});
	}
}

function selectRow(e) {
	var id = this.id.replace('chkb', '');
	if(this.checked) {
		resource.selids.push(this.id);
		resourcestore.fetchItemByIdentity({
			identity: id,
			onItem: function(item, req) {
				resourcegrid.selection.addToSelection(resourcegrid.getItemIndex(item));
			}
		});
	}
	else {
		var index = resource.selids.indexOf(id);
		if(index > -1)
			resource.selids.splice(index, 1);
		resourcestore.fetchItemByIdentity({
			identity: id,
			onItem: function(item, req) {
				resourcegrid.selection.deselect(resourcegrid.getItemIndex(item));
			}
		});
	}
	dojo.stopEvent(e);
}

function selectAllRows() {
	resourcestore.fetch({
		query: resourcegrid.query,
		onComplete: function(items, request) {
			resource.selectingall = true;
			if(resource.selids.length) {
				dojo.forEach(resource.selids, function(id) {
					if(dijit.byId(id))
						dijit.byId(id).set('checked', false);
				});
				resource.selids = [];
				resourcegrid.selection.clear();
				dijit.byId('selectallchkb').set('checked', false);
			}
			else {
				resource.selids = [];
				dojo.forEach(items, function(item) {
					if(! parseInt(item.deleted)) {
						resource.selids.push('chkb' + item.id);
						resourcegrid.selection.addToSelection(resourcegrid.getItemIndex(item));
					}
				})
				dijit.byId('selectallchkb').set('checked', true);
			}
			resource.selectingall = false;
		}
	});
}

function buildExtraFilters() {
	// create grid layout
	var obj = {};
	var layout = [];
	var cells = resourcegrid.layout.cells;
	for(var i = 0; i < cells.length; i++) {
		var litem = {};
		obj[cells[i].field] = '';
		litem['field'] = cells[i].field;
		if(cells[i].field == 'id')
			litem['name'] = '&nbsp;';
		else
			litem['name'] = cells[i].name;
		litem['hidden'] = cells[i].hidden;
		if(i == 0)
			litem['width'] = '21px';
		else if(typeof cells[i].width != 'undefined')
			litem['width'] = cells[i].width;
		litem['editable'] = false;
		if(i == 0) {
			litem['formatter'] = function(value, index, item) {
				var cb = new dijit.form.CheckBox({
					id: 'selectallchkb',
					checked: false,
					onClick: selectAllRows,
					_destroyOnRemove: true
				});
				return cb;
			}
		}
		if(i == 1) {
			litem['formatter'] = function(value, index, item) {
				item.customStyles.push('background-color: #e8e8e8');
				item.customStyles.push('border: 1px solid black');
				item.customStyles.push('text-align: center');
				return '<span id=\"applyextrafilters\">Apply</span>';
			}
		}
		else if(i > 1) {
			litem['formatter'] = function(value, index, item) {
				if(dijit.byId(item.field + 'cb'))
					return dijit.byId(item.field + 'cb');
				if(item.field in filtercbstores)
					var store = filtercbstores[item.field];
				else
					var store = dojo.data.ItemFileReadStore({});
				var cb = new dijit.form.ComboBox({
					selectOnClick: true,
					store: store,
					id: item.field + "cb",
					required: false,
					query: {id: '*'},
					onChange: applyExtraFilters,
					field: item.field,
					queryExpr: '*${0}*',
					autoComplete: false,
					labelFunc: cbformatter,
					labelType: 'html',
					searchAttr: 'value',
					fetchProperties: {sort: [{attribute:"value"}]}
				});
				if(typeof item.width != 'undefined') {
					if(item.width.match(/px/))
						var newwidth = (parseInt(item.width) - 11) + 'px';
					else
						var newwidth = (parseInt(item.width) - 0.6) + 'em';
					cb.set('style', {width: newwidth});
				}
				else if(typeof item.unitWidth != 'undefined') {
					if(item.unitWidth.match(/px/))
						var newwidth = (parseInt(item.unitWidth) - 11) + 'px';
					else
						var newwidth = (parseInt(item.unitWidth) - 0.6) + 'em';
					cb.set('style', {width: newwidth});
				}
				return cb;
			};
		}
		layout.push(litem);
	}
	var data = {items: [obj]};
	filterstore = new dojo.data.ItemFileReadStore({data: data});
	extrafiltergrid = new dojox.grid.DataGrid({
		query: {name: '*'},
		store: filterstore,
		structure: layout,
		canSort: function() {return false;},
		onCellClick: combofocus,
		autoWidth: true
	}, document.createElement('div'));
	dojo.byId('extrafiltersdiv').appendChild(extrafiltergrid.domNode);
	extrafiltergrid.startup();
	var cells = extrafiltergrid.layout.cells;
	for(var i = 2; i < cells.length; i++) {
		dojo.connect(dijit.byId(cells[i].field + 'cb'), 'onKeyDown', null, filterKeyDown);
	}

	// create stores for comboboxes
	resourcestore.fetch({
		onComplete: function(items, request) {
			var data = {};
			var seen = {};
			var cells = resourcegrid.layout.cells;
			dojo.forEach(items, function(item) {
				for(var i = 0; i < cells.length; i++) {
					if(cells[i].field == 'id')
						continue;
					var field = cells[i].field;
					if(! (field in seen)) {
						seen[field] = [];
						data[field] = [];
					}
					if(dojo.indexOf(seen[field], item[field]) == -1) {
						seen[field].push(item[field].toString());
						data[field].push({id: item.id.toString(), value: item[cells[i].field].toString()});
					}
				}
			});
			for(var i = 0; i < cells.length; i++) {
				if(cells[i].field == 'id')
					continue;
				var field = cells[i].field;
				var store = new dojo.data.ItemFileReadStore({data: {identifier:'id', label:'value', items: data[field]}});
				filtercbstores[field] = store;
				dijit.byId(field + 'cb').set('store', store);
			}
		}
	});
}

function cbformatter(item, store) {
	var comp = new Computer();
	return comp.colformatter(store.getValue(item, 'value'), '', this);
}

function combofocus(obj) {
	if(dijit.byId(obj.cell.field + "cb"))
		dijit.byId(obj.cell.field + "cb").focus();
}

function applyExtraFilters(value) {
	delete resourcegrid.query[this.field];
	value = value.replace('(', '\\(');
	value = value.replace(')', '\\)');
	if(this.field == 'state' && value == 'inuse')
		resourcegrid.query[this.field] = value;
	else if(value != '')
		resourcegrid.query[this.field] = new RegExp('.*' + value + '.*', 'i');
	resourcegrid.setQuery(resourcegrid.query);

	dojo.byId('computercount').innerHTML = 'Computers in table: ' + resourcegrid.rowCount;

	var savelist = resource.selids;
	resourcegrid.selection.clear();
	var newselids = [];
	for(var i = 0; i < resourcegrid.rowCount; i++) {
		var row = resourcegrid.getItem(i);
		if(! row)
			continue;
		var id = 'chkb' + row.id;
		if(dojo.indexOf(savelist, id) != -1) {
			newselids.push(id);
			resourcegrid.selection.addToSelection(resourcegrid.getItemIndex(row));
			dijit.byId(id).set('checked', true);
		}
	}
	resourcegrid.selids = newselids;
}

function addNewResource(title) {
	if(dijit.byId('scheduleid').options.length == 0) {
		dijit.byId('noschedulenoadd').show();
		return;
	}
	dijit.byId('mode').set('value', 'single');
	addedit = 'add';
	resetEditResource();
	dijit.byId('type').reset();
	selectType();
	dijit.byId('addeditdlg').set('title', title);
	dijit.byId('addeditbtn').set('label', title);
	dojo.byId('editresid').value = 0;
	dojo.removeClass('singlemultiplediv', 'hidden');
	dojo.addClass('notesspan', 'hidden');
	dojo.addClass('vmprofilespan', 'hidden');
	dojo.addClass('curimgspan', 'hidden');
	dojo.addClass('compidspan', 'hidden');
	dijit.byId('nathostid').set('disabled', true);
	dijit.byId('nathostenabled').set('checked', false);
	dijit.byId('natpublicipaddress').set('disabled', true);
	dijit.byId('natinternalipaddress').set('disabled', true);
	dijit.byId('addeditdlg').show();
}

function toggleSingleMultiple() {
	if(dijit.byId('mode').get('value') == 'single')
		toggleAddSingle();
	else
		toggleAddMultiple();
}

function toggleAddSingle() {
	dojo.addClass('multiplenotediv', 'hidden');
	dojo.addClass('startenddiv', 'hidden');
	dojo.addClass('multiipmacdiv', 'hidden');
	dojo.removeClass('singleipmacdiv', 'hidden');
	dojo.removeClass('nathost', 'hidden');
	dijit.byId('name').set('regExp', '^([a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,35})$');
	dijit.byId('addeditbtn').setLabel('Add Computer');
	recenterDijitDialog('addeditdlg');
}

function toggleAddMultiple() {
	dojo.removeClass('multiplenotediv', 'hidden');
	dojo.removeClass('startenddiv', 'hidden');
	dojo.removeClass('multiipmacdiv', 'hidden');
	dojo.addClass('singleipmacdiv', 'hidden');
	dojo.addClass('nathost', 'hidden');
	dijit.byId('name').set('regExp', '^([a-zA-Z0-9_%][-a-zA-Z0-9_\.%]{1,35})$');
	dijit.byId('addeditbtn').setLabel('Add Computers');
	recenterDijitDialog('addeditdlg');
}

function toggleNAT(chkid, selid) {
	if(dijit.byId(chkid).checked) {
		dijit.byId(selid).set('disabled', false);
	}
	else {
		dijit.byId(selid).set('disabled', true);
	}
	if(chkid == 'natenabled' &&
	   dijit.byId(chkid).checked &&
	   dijit.byId('nathostenabled').checked) {
		dijit.byId('nathostenabled').set('checked', false);
	}
}

function toggleNAThost() {
	if(dijit.byId('nathostenabled').checked) {
		if(dijit.byId('natenabled').checked)
			dijit.byId('natenabled').set('checked', false);
		dijit.byId('natpublicipaddress').set('disabled', false);
		dijit.byId('natinternalipaddress').set('disabled', false);
	}
	else {
		dijit.byId('natpublicipaddress').set('disabled', true);
		dijit.byId('natinternalipaddress').set('disabled', true);
	}
}

function inlineEditResourceCB(data, ioArgs) {
	dojo.addClass('singlemultiplediv', 'hidden');
	toggleAddSingle();
	if(data.items.status == 'success') {
		addedit = 'edit';
		editobj = data.items.data;
		dojo.addClass('cancelvmhostinuseokdiv', 'hidden');
		if(data.items.showcancel) {
			dojo.removeClass('cancelvmhostinusediv', 'hidden');
			dojo.byId('tohostcancelcont').value = data.items.tohostcancelcont;
			if(data.items.tohostfuture) {
				dojo.addClass('tohostnowspan', 'hidden');
				dojo.removeClass('tohostfuturespan', 'hidden');
				dojo.byId('tohostfuturetimespan').innerHTML = data.items.tohoststart;
			}
			else {
				dojo.removeClass('tohostnowspan', 'hidden');
				dojo.addClass('tohostfuturespan', 'hidden');
			}
		}
		else {
			dojo.addClass('cancelvmhostinusediv', 'hidden');
		}
		dijit.byId('type').set('value', data.items.data.type);
		selectType();
		dijit.byId('provisioningid').set('value', data.items.data.provisioningid);
		selectProvisioning();
		lastselected[data.items.data.type]['provisioningid'] = data.items.data.provisioningid;
		dijit.byId('stateid').set('value', data.items.data.stateid);
		lastselected[data.items.data.type]['stateid'] = data.items.data.stateid;
		dojo.byId('saveresourcecont').value = data.items.cont;
		dijit.byId('addeditdlg').set('title', data.items.title);
		dijit.byId('addeditbtn').set('label', 'Save Changes');
		dijit.byId('addeditbtn').set('disabled', false);
		dojo.byId('editresid').value = data.items.resid;
		dijit.byId('name').set('value', data.items.data.hostname);
		dijit.byId('owner').set('value', data.items.data.owner);
		dijit.byId('ipaddress').set('value', data.items.data.IPaddress);
		dijit.byId('privateipaddress').set('value', data.items.data.privateIPaddress);
		dijit.byId('publicmac').set('value', data.items.data.eth1macaddress);
		dijit.byId('privatemac').set('value', data.items.data.eth0macaddress);
		if('notes' in data.items.data && data.items.data.notes) {
			if(data.items.data.notes.match(/@/))
				dijit.byId('notes').set('value', data.items.data.notes.split('@')[1]);
			else
				dijit.byId('notes').set('value', data.items.data.notes);
		}
		dijit.byId('vmprofileid').set('value', data.items.data.vmprofileid);
		dijit.byId('platformid').set('value', data.items.data.platformid);
		dijit.byId('scheduleid').set('value', data.items.data.scheduleid);
		dojo.byId('curimg').innerHTML = data.items.data.currentimg;
		dijit.byId('ram').set('value', data.items.data.ram);
		dijit.byId('cores').set('value', data.items.data.procnumber);
		dijit.byId('procspeed').set('value', data.items.data.procspeed);
		dijit.byId('network').set('value', data.items.data.network);
		dijit.byId('predictivemoduleid').set('value', data.items.data.predictivemoduleid);
		dojo.byId('compid').innerHTML = data.items.data.id;
		dijit.byId('location').set('value', data.items.data.location);
		if(data.items.data.natenabled == 1) {
			dijit.byId('natenabled').set('checked', true);
			dijit.byId('nathostid').set('disabled', false);
			dijit.byId('nathostid').set('value', data.items.data.nathostid);
		}
		else {
			dijit.byId('natenabled').set('checked', false);
			dijit.byId('nathostid').set('disabled', true);
		}
		if(data.items.data.nathostenabled == 1) {
			dijit.byId('nathostenabled').set('checked', true);
			dijit.byId('natpublicipaddress').set('disabled', false);
			dijit.byId('natinternalipaddress').set('disabled', false);
			dijit.byId('natpublicipaddress').set('value', data.items.data.natpublicIPaddress);
			dijit.byId('natinternalipaddress').set('value', data.items.data.natinternalIPaddress);
		}
		else {
			dijit.byId('nathostenabled').set('checked', false);
			dijit.byId('natpublicipaddress').set('disabled', true);
			dijit.byId('natinternalipaddress').set('disabled', true);
			dijit.byId('natpublicipaddress').set('value', '');
			dijit.byId('natinternalipaddress').set('value', '');
		}
		dojo.byId('addeditdlgerrmsg').innerHTML = '';
		dijit.byId('addeditdlg').show();
	}
	else if(data.items.status == 'noaccess') {
		alert('Access denied to edit this item');
	}
}

function selectType() {
	var type = dijit.byId('type').get('value');
	var obj = dijit.byId('provisioningid');
	obj.options = [];
	dojo.forEach(options[type]['provisioning'], function(prov) {
		obj.addOption(prov);
	});
	dijit.byId('provisioningid').set('value', lastselected[type]['provisioningid']);
	var obj = dijit.byId('stateid');
	obj.options = [];
	if(addedit == 'edit') {
		if(type == 'virtualmachine' && parseInt(editobj.vmhostid) > 0 &&
		   editobj.state != 'available')
			obj.addOption({value: '2', label: 'available'});
		obj.addOption({value: editobj.stateid, label: editobj.state});
	}
	dojo.forEach(options[type]['states'], function(state) {
		if(addedit == 'edit' && state.value == editobj.stateid)
			return;
		if(addedit == 'add' && state.label == 'vmhostinuse' &&
	      dijit.byId('provisioningid').attr('displayedValue') != 'None')
			return;
		obj.addOption({value: state.value, label: state.label});
	});
	dijit.byId('stateid').set('value', lastselected[type]['stateid']);
	if(type == 'blade' &&
	   dijit.byId('provisioningid').attr('displayedValue') == 'None' &&
	   dijit.byId('stateid').attr('displayedValue') == 'vmhostinuse')
		dojo.removeClass('vmprofilespan', 'hidden');
	else if(dijit.byId('stateid').attr('displayedValue') != 'vmhostinuse')
		dojo.addClass('vmprofilespan', 'hidden');
	if(addedit == 'edit' && dijit.byId('stateid').attr('displayedValue') == 'maintenance')
		dojo.removeClass('notesspan', 'hidden');
	else
		dojo.addClass('notesspan', 'hidden');
}

function selectProvisioning() {
	lastselected[dijit.byId('type').get('value')]['provisioningid'] = dijit.byId('provisioningid').get('value');
	var obj = dijit.byId('stateid');
	obj.options = [];
	if(addedit == 'edit') {
		if(dijit.byId('type').get('value') == 'virtualmachine' &&
		   parseInt(editobj.vmhostid) > 0 &&
		   editobj.state != 'available')
			obj.addOption({value: '2', label: 'available'});
		var addedexisting = false;
	}
	dojo.forEach(options[dijit.byId('type').get('value')]['states'], function(state) {
		if(((dijit.byId('type').get('value') == 'blade' &&
		   dijit.byId('provisioningid').attr('displayedValue') == 'None') ||
		   (addedit == 'add' && dijit.byId('type').get('value') == 'virtualmachine')) &&
		   state.label == 'available')
			return;
		if(addedit == 'add' && state.label == 'vmhostinuse' &&
	      dijit.byId('provisioningid').attr('displayedValue') != 'None')
			return;
		if(addedit == 'edit' && state.value == editobj.stateid)
			addedexisting = true;
		obj.addOption({value: state.value, label: state.label});
	});
	if(addedit == 'edit' && ! addedexisting)
		obj.addOption({value: editobj.stateid, label: editobj.state});
	dijit.byId('stateid').set('value', lastselected[dijit.byId('type').get('value')]['stateid']);
}

function selectState() {
	lastselected[dijit.byId('type').get('value')]['stateid'] = dijit.byId('stateid').get('value');
	if(dijit.byId('type').get('value') == 'blade' &&
	   dijit.byId('stateid').attr('displayedValue') == 'vmhostinuse')
		dojo.removeClass('vmprofilespan', 'hidden');
	else if(dijit.byId('stateid').attr('displayedValue') != 'vmhostinuse')
		dojo.addClass('vmprofilespan', 'hidden');
	if(addedit == 'edit' && dijit.byId('stateid').attr('displayedValue') == 'maintenance')
		dojo.removeClass('notesspan', 'hidden');
	else
		dojo.addClass('notesspan', 'hidden');
}

function resetEditResource() {
	var fields = ['name', 'owner', 'type', 'ipaddress', 'privateipaddress',
	              'publicmac', 'privatemac', 'provisioningid', 'stateid',
	              'vmprofileid', 'platformid', 'scheduleid', 'ram', 'cores',
	              'procspeed', 'network', 'location', 'startnum', 'endnum',
	              'startpubipaddress', 'endpubipaddress', 'startprivipaddress',
	              'endprivipaddress', 'startmac', 'notes', 'predictivemoduleid',
	              'natpublicipaddress', 'natinternalipaddress'];
	for(var i = 0; i < fields.length; i++) {
		dijit.byId(fields[i]).reset();
	}
	dojo.byId('curimg').innerHTML = '';
	dojo.byId('compid').innerHTML = '';
	dojo.byId('addeditdlgerrmsg').innerHTML = '';
	dojo.removeClass('notesspan', 'hidden');
	dojo.removeClass('vmprofilespan', 'hidden');
	dojo.removeClass('curimgspan', 'hidden');
	dojo.removeClass('compidspan', 'hidden');
	dijit.byId('natenabled').set('checked', false);
	dijit.byId('nathostid').set('disabled', true);
}

function saveResource() {
	var errobj = dojo.byId('addeditdlgerrmsg');
	if(addedit == 'edit' || dijit.byId('mode').get('value') == 'single')
		var fields = ['name', 'owner', 'ipaddress', 'privateipaddress', 'publicmac',
		              'privatemac', 'ram', 'cores', 'procspeed', 'location',
		              'natpublicipaddress', 'natinternalipaddress'];
	else
		var fields = ['name', 'startnum', 'endnum', 'owner', 'startpubipaddress',
		              'endpubipaddress', 'startprivipaddress', 'endprivipaddress',
		              'startmac', 'ram', 'cores', 'procspeed', 'location',
		              'natpublicipaddress', 'natinternalipaddress'];
	for(var i = 0; i < fields.length; i++) {
		if(! checkValidatedObj(fields[i], errobj))
			return;
	}

	if(addedit == 'add')
		var data = {continuation: dojo.byId('addresourcecont').value};
	else
		var data = {continuation: dojo.byId('saveresourcecont').value};

	if(addedit == 'edit' && dijit.byId('stateid').attr('displayedValue') == 'maintenance') {
		if(! dijit.byId('notes').get('value').match(/^([-a-zA-Z0-9_\. ,#\(\)=\+:;]{0,5000})$/)) {
			errobj.innerHTML = "Maintenance reason can be up to 5000 characters long and may only<br>contain letters, numbers, spaces and these characters: - , . _ # ( ) = + : ;";
			return;
		}
		else
			data['notes'] = dijit.byId('notes').get('value');
	}
	else
		data['notes'] = '';

	for(var i = 0; i < fields.length; i++) {
		data[fields[i]] = dijit.byId(fields[i]).get('value');
	}
	data['type'] = dijit.byId('type').get('value');
	data['provisioningid'] = dijit.byId('provisioningid').get('value');
	data['stateid'] = dijit.byId('stateid').get('value');
	data['vmprofileid'] = dijit.byId('vmprofileid').get('value');
	data['platformid'] = dijit.byId('platformid').get('value');
	data['scheduleid'] = dijit.byId('scheduleid').get('value');
	data['network'] = dijit.byId('network').get('value');
	data['predictivemoduleid'] = dijit.byId('predictivemoduleid').get('value');
	data['natenabled'] = dijit.byId('natenabled').get('value');
	if(data['natenabled'] == 1)
		data['nathostid'] = dijit.byId('nathostid').get('value');
	else {
		data['natenabled'] = 0;
		data['nathostid'] = 0;
	}
	data['nathostenabled'] = dijit.byId('nathostenabled').get('value');
	if(data['nathostenabled'] == 1) {
		if(data['natenabled'] == 1) {
			errobj.innerHTML = "Connect Using NAT and Use as NAT Host cannot both be checked";
			return;
		}
	}
	else
		data['nathostenabled'] = 0;
	data['addmode'] = dijit.byId('mode').get('value');

	dijit.byId('addeditbtn').set('disabled', true);
	RPCwrapper(data, saveResourceCB, 1);
}

function saveResourceCB(data, ioArgs) {
	if(data.items.status == 'error') {
		dojo.byId('addeditdlgerrmsg').innerHTML = '<br>' + data.items.msg;
		dijit.byId('addeditbtn').set('disabled', false);
	}
	else if(data.items.status == 'adderror') {
		alert(data.items.errormsg);
	}
	else if(data.items.status == 'success') {
		if(data.items.action == 'add') {
			if(data.items.addmode == 'single') {
				if(typeof resourcegrid !== 'undefined') {
					resourcegrid.store.newItem(data.items.data);
					resourcegrid.sort();
					if(data.items.data.nathostenabled) {
						dijit.byId('nathostid').addOption({label: data.items.data.hostname, value: data.items.data.nathostenabledid});
						dijit.byId('newnathostid').addOption({label: data.items.data.hostname, value: data.items.data.nathostenabledid});
						dijit.byId('newnathostbtn').set('disabled', false);
					}
				}
				dojo.forEach(dijit.findWidgets(dojo.byId('groupdlgcontent')), function(w) {
					w.destroyRecursive();
				});
				if(data.items.nogroups == 0) {
					dojo.byId('groupdlgcontent').innerHTML = data.items.groupingHTML;
					AJdojoCreate('groupdlgcontent');
					dojo.byId('resources').value = data.items.data.id;
					populateLists('resources', 'ingroups', 'inresourcename', 'outresourcename', 'resgroupinggroupscont');
					dijit.byId('groupdlg').show();
					dijit.byId('groupingnote').show();
				}
			}
			else {
				if(typeof resourcegrid !== 'undefined') {
					for(var i = 0; i < data.items.data.length; i++) {
						resourcegrid.store.newItem(data.items.data[i]);
					}
					resourcegrid.sort();
				}
				dojo.forEach(dijit.findWidgets(dojo.byId('groupdlgcontent')), function(w) {
					w.destroyRecursive();
				});
				if(data.items.nogroups == 0) {
					dojo.byId('groupdlgcontent').innerHTML = data.items.groupingHTML;
					dojo.byId('groupbyresourcedesc').innerHTML = data.items.grouphelp;
					dojo.addClass('groupbyresourcesel', 'hidden');
					AJdojoCreate('groupdlgcontent');
					dojo.byId('resources').value = data.items.data[0].id;
					populateLists('resources', 'ingroups', 'inresourcename', 'outresourcename', 'resgroupinggroupscont');
					dojo.byId('inresourcename').innerHTML = 'new computer set';
					dojo.byId('outresourcename').innerHTML = 'new computer set';
					dojo.byId('addgrpcont').value = data.items.addcont;
					dojo.byId('remgrpcont').value = data.items.remcont;
					dijit.byId('groupdlg').show();
					dijit.byId('groupingnote').show();
				}
			}
		}
		else {
			resourcegrid.store.fetch({
				query: {id: data.items.data.id},
				onItem: function(item) {
					var washost = resourcegrid.store.getValue(item, 'nathostenabled');
					resourcegrid.store.setValue(item, 'name', data.items.data.hostname);
					resourcegrid.store.setValue(item, 'owner', data.items.data.owner);
					resourcegrid.store.setValue(item, 'state', data.items.data.state);
					resourcegrid.store.setValue(item, 'platform', data.items.data.platform);
					resourcegrid.store.setValue(item, 'schedule', data.items.data.schedule);
					resourcegrid.store.setValue(item, 'currentimg', data.items.data.currentimg);
					resourcegrid.store.setValue(item, 'imagerevision', data.items.data.imagerevision);
					resourcegrid.store.setValue(item, 'nextimg', data.items.data.nextimg);
					resourcegrid.store.setValue(item, 'ram', data.items.data.ram);
					resourcegrid.store.setValue(item, 'procnumber', data.items.data.procnumber);
					resourcegrid.store.setValue(item, 'procspeed', data.items.data.procspeed);
					resourcegrid.store.setValue(item, 'network', data.items.data.network);
					resourcegrid.store.setValue(item, 'IPaddress', data.items.data.IPaddress);
					resourcegrid.store.setValue(item, 'privateIPaddress', data.items.data.privateIPaddress);
					resourcegrid.store.setValue(item, 'eth0macaddress', data.items.data.eth0macaddress);
					resourcegrid.store.setValue(item, 'eth1macaddress', data.items.data.eth1macaddress);
					resourcegrid.store.setValue(item, 'type', data.items.data.type);
					resourcegrid.store.setValue(item, 'deleted', data.items.data.deleted);
					resourcegrid.store.setValue(item, 'notes', data.items.data.notes);
					resourcegrid.store.setValue(item, 'vmhost', data.items.data.vmhost);
					resourcegrid.store.setValue(item, 'predictivemodule', data.items.data.predictivemodule);
					resourcegrid.store.setValue(item, 'location', data.items.data.location);
					resourcegrid.store.setValue(item, 'provisioning', data.items.data.provisioning);
					resourcegrid.store.setValue(item, 'natenabled', data.items.data.natenabled);
					resourcegrid.store.setValue(item, 'nathost', data.items.data.nathost);
					resourcegrid.store.setValue(item, 'nathostenabled', data.items.data.nathostenabled);
					resourcegrid.store.setValue(item, 'natpublicIPaddress', data.items.data.natpublicIPaddress);
					resourcegrid.store.setValue(item, 'natinternalIPaddress', data.items.data.natinternalIPaddress);
					if(data.items.data.nathostenabled) {
						if(washost == 0) {
							dijit.byId('nathostid').addOption({label: data.items.data.hostname, value: data.items.data.nathostenabledid});
							dijit.byId('newnathostid').addOption({label: data.items.data.hostname, value: data.items.data.nathostenabledid});
							dijit.byId('newnathostbtn').set('disabled', false);
						}
					}
					else {
						dijit.byId('nathostid').options.forEach(
							function(node, index, nodelist) {
								if(node.label == data.items.data.hostname)
									dijit.byId('nathostid').removeOption({value: node.value});
							}
						);
						dijit.byId('newnathostid').options.forEach(
							function(node, index, nodelist) {
								if(node.label == data.items.data.hostname)
									dijit.byId('newnathostid').removeOption({value: node.value});
								if(dijit.byId('newnathostid').options.length == 0)
									dijit.byId('newnathostbtn').set('disabled', true);
							}
						);
					}
				},
				onComplete: function(items, result) {
					// when call resourcegrid.sort directly, the table contents disappear; not sure why
					setTimeout(function() {resourcegrid.sort();}, 10);
				}
			});
		}
		dijit.byId('addeditdlg').hide();
		resetEditResource();
		if('promptuser' in data.items) {
			dijit.byId('confirmactiondlg').set('title', data.items.title);
			dijit.byId('submitactionbtn').setLabel(data.items.btntxt);
			dojo.removeClass('submitactionbtnspan', 'hidden');
			dijit.byId('actionmsg').set('content', data.items.msg);
			dojo.byId('submitcont').value = data.items.cont;
			dijit.byId('confirmactiondlg').show();
		}
		else if('promptuserfail' in data.items) {
			dijit.byId('confirmactiondlg').set('title', data.items.title);
			dojo.addClass('submitactionbtnspan', 'hidden');
			dijit.byId('cancelactionbtn').setLabel('Close');
			dijit.byId('actionmsg').set('content', data.items.msg);
			dijit.byId('confirmactiondlg').show();
		}
		else if('multirefresh' in data.items) {
			refreshcompdata(data.items.multirefresh);
		}
		else
			setTimeout(function() {dijit.byId('addeditbtn').set('disabled', false);}, 250);
	}
}

function cancelScheduledtovmhostinuse() {
	var data = {continuation: dojo.byId('tohostcancelcont').value};
	RPCwrapper(data, cancelScheduledtovmhostinuseCB, 1);
}

function cancelScheduledtovmhostinuseCB(data, ioArgs) {
	if(data.items.status == 'success') {
		dojo.byId('cancelvmhostinuseokdiv').innerHTML = data.items.msg;
		dojo.addClass('cancelvmhostinusediv', 'hidden');
		dojo.removeClass('cancelvmhostinuseokdiv', 'hidden');
	}
	else if(data.items.status == 'failed') {
		dojo.byId('cancelvmhostinusediv').innerHTML = "An error was encountered that prevented the reservation to place this computer in the vmhostinuse state from being deleted.";
	}
}

function confirmReload() {
	var data = {continuation: dojo.byId('reloadcont').value,
	            imageid: dijit.byId('reloadimageid').get('value')};
	confirmAction(data);
}

function confirmDelete() {
	var data = {continuation: dojo.byId('deletecont').value};
	confirmAction(data);
}

function confirmStateChange() {
	var data = {continuation: dojo.byId('statechangecont').value,
	            stateid: dijit.byId('newstateid').get('value')};
	confirmAction(data);
}

function confirmScheduleChange() {
	var data = {continuation: dojo.byId('schedulecont').value,
	            schid: dijit.byId('newscheduleid').get('value')};
	confirmAction(data);
}

function confirmProvisioningChange() {
	var data = {continuation: dojo.byId('provisioningchangecont').value,
	            provisioningid: dijit.byId('newprovisioningid').get('value')};
	confirmAction(data);
}

function confirmPredictiveModuleChange() {
	var data = {continuation: dojo.byId('predictivemodulechangecont').value,
	            predictivemoduleid: dijit.byId('newpredictivemoduleid').get('value')};
	confirmAction(data);
}

function confirmNATchange() {
	if(dijit.byId('newnathostid').options.length == 0)
		return;
	var data = {continuation: dojo.byId('natchangecont').value};
	if(dijit.byId('newnatenabled').get('value') == 1) {
		data['natenabled'] = 1;
		data['nathostid'] = dijit.byId('newnathostid').get('value');
	}
	else {
		data['natenabled'] = 0;
		data['nathostid'] = 0;
	}
	confirmAction(data);
}

function generateDHCPdata(type) {
	var data = {continuation: dojo.byId(type + 'dhcpcont').value,
	            type: type};
	if(dijit.byId('mnprivipaddr'))
		data['mnip'] = dijit.byId('mnprivipaddr').get('value');
	if(type == 'private') {
		if(dojo.byId('preth0rdo').checked)
			data['nic'] = 'eth0';
		else
			data['nic'] = 'eth1';
	}
	else {
		if(dojo.byId('pueth0rdo').checked)
			data['nic'] = 'eth0';
		else
			data['nic'] = 'eth1';
	}
	confirmAction(data);
}

function hostsData() {
	var data = {continuation: dojo.byId('hostsdatacont').value};
	confirmAction(data);
}

function showReservations() {
	var data = {continuation: dojo.byId('showreservationscont').value};
	confirmAction(data);
}

function showReservationHistory() {
	var compids = [];
	dojo.forEach(resource.selids, function(id) {
		compids.push(id.replace('chkb', ''));
	});
	if(compids.length > 3) {
		alert('Due to the load this can introduce on the database server, only a maximum of 3 computers can be selected for viewing Reservation History.');
		return;
	}
	var data = {continuation: dojo.byId('showreservationhistorycont').value};
	confirmAction(data);
}

function confirmAction(data) {
	dijit.popup.close(dijit.byId('actionmenu'));
	var compids = [];
	dojo.forEach(resource.selids, function(id) {
		compids.push(id.replace('chkb', ''));
	});
	if(compids.length == 0) {
		alert('No computers selected');
		return;
	}
	data['compids[]'] = compids;
	RPCwrapper(data, confirmActionCB, 1);
}

function confirmActionCB(data, ioArgs) {
	if(data.items.status == 'error') {
		dijit.byId('confirmactiondlg').set('title', 'Error');
		dijit.byId('cancelactionbtn').setLabel('Close');
		dojo.addClass('submitactionbtnspan', 'hidden');
		dijit.byId('actionmsg').set('content', data.items.errormsg);
		dijit.byId('confirmactiondlg').show();
	}
	else if(data.items.status == 'success') {
		dijit.byId('confirmactiondlg').set('title', data.items.title);
		dijit.byId('submitactionbtn').setLabel(data.items.btntxt);
		dijit.byId('actionmsg').set('content', data.items.actionmsg);
		//AJdojoCreate('actionmsg');
		if('complist' in data.items)
			dojo.byId('complist').innerHTML = data.items.complist;
		dojo.byId('submitcont').value = data.items.cont;
		if('disablesubmit' in data.items && data.items.disablesubmit == 1)
			dijit.byId('submitactionbtn').set('disabled', true);
		dijit.byId('confirmactiondlg').show();
	}
	else if(data.items.status == 'onestep') {
		dijit.byId('confirmactiondlg').set('title', data.items.title);
		dijit.byId('cancelactionbtn').setLabel('Close');
		dojo.addClass('submitactionbtnspan', 'hidden');
		dijit.byId('actionmsg').set('content', data.items.actionmsg);
		//AJdojoCreate('actionmsg');
		if('complist' in data.items)
			dojo.byId('complist').innerHTML = data.items.complist;
		dijit.byId('confirmactiondlg').show();
	}
}

function cancelAction() {
	dijit.byId('confirmactiondlg').hide();
	dijit.byId('confirmactiondlg').set('title', '');
	dijit.byId('actionmsg').set('content', '');
	dojo.byId('complist').innerHTML = '';
	dijit.byId('submitactionbtn').setLabel('Submit');
	dijit.byId('submitactionbtn').set('disabled', false);
	dojo.removeClass('submitactionbtnspan', 'hidden');
	dijit.byId('cancelactionbtn').setLabel('Cancel');
}

function submitAction() {
	var data = {continuation: dojo.byId('submitcont').value};
	if(dijit.byId('utilnotes'))
		data['notes'] = dijit.byId('utilnotes').get('value');
	if(dijit.byId('profileid'))
		data['profileid'] = dijit.byId('profileid').get('value');
	if(dojo.byId('modedirect')) {
		if(dojo.byId('modedirect').checked)
			data['mode'] = 'direct';
		else
			data['mode'] = 'reload';
	}
	RPCwrapper(data, submitActionCB, 1);
}

function submitActionCB(data, ioArgs) {
	if(data.items.status == 'error') {
		dijit.byId('confirmactiondlg').set('title', 'Error');
		dijit.byId('cancelactionbtn').setLabel('Close');
		dojo.addClass('submitactionbtnspan', 'hidden');
		dijit.byId('actionmsg').set('content', data.items.errormsg);
		dojo.byId('complist').innerHTML = '';
		dijit.byId('confirmactiondlg').show();
		return;
	}
	if(('clearselection' in data.items && data.items.clearselection == 1) ||
	   (dijit.byId('statecb').value != '' && data.items.newstate != dijit.byId('statecb').value))
		resourcegrid.selection.clear();
	if('refreshcount' in data.items && parseInt(data.items.refreshcount) > 0) {
		var cnt = parseInt(data.items.refreshcount) - 1;
		refreshcompdata(cnt);
	}
	dijit.byId('confirmactiondlg').set('title', data.items.title);
	dijit.byId('cancelactionbtn').setLabel('Close');
	dojo.addClass('submitactionbtnspan', 'hidden');
	dijit.byId('actionmsg').set('content', data.items.msg);
	dojo.byId('complist').innerHTML = '';
	dojo.byId('submitcont').value = '';
	recenterDijitDialog('confirmactiondlg');
}

function refreshcompdata(refreshcount) {
	var url = resourcestore.url;
	resourcestore.close();
	resourcestore = new dojo.data.ItemFileWriteStore({url: url});
	resourcestore.comparatorMap = {name: resource.nocasesort,
	                               procnumber: resource.nocasesort,
	                               procspeed: resource.nocasesort,
	                               network: resource.nocasesort,
	                               ram: resource.nocasesort};
	resourcestore.fetch();
	savescroll = resourcegrid.scrollTop;
	resourcegrid.setStore(resourcestore, resourcegrid.query);
	if(refreshcount)
		setTimeout(function() {refreshcompdata(--refreshcount);}, 5000);
}

function setScroll() {
	if(savescroll != 0)
		resourcegrid.scrollTo(savescroll);
}

function saveScroll(scrollobj) {
	if(resourcegrid.scrollTop != 0)
		savescroll = 0;
}

function delayedCompGroupFilterSelection() {
	if(filterdelay)
		clearTimeout(filterdelay);
	filterdelay = setTimeout(compGroupFilterSelection, 1500);
}

function compGroupFilterSelection() {
	var selected = new Array();
	var selobj = dojo.byId('filtercompgroups');
	for(var i = 0; i < selobj.options.length; i++) {
		if(selobj.options[i].selected)
			selected.push(selobj.options[i].value);
	}
	var data = {groupids: selected.join(','),
	            continuation: dojo.byId('filtercompgroupscont').value};
	RPCwrapper(data, compGroupFilterSelectionCB, 1);
}

function compGroupFilterSelectionCB(data, ioArgs) {
	if(data.items.status == 'error') {
		alert(data.items.errormsg);
		return;
	}
	var query = resourcegrid.query;
	query['id'] = new RegExp(data.items.regids);

	resourcegrid.setQuery(query);

	dojo.byId('computercount').innerHTML = 'Computers in table: ' + resourcegrid.rowCount;
}
