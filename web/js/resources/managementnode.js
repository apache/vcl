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

function ManagementNode() {
	Resource.apply(this, Array.prototype.slice.call(arguments));
	this.selids = [];
	this.selectingall = false;
	this.restype = 'managementnode';
}
ManagementNode.prototype = new Resource();

ManagementNode.prototype.colformatter = function(value, rowIndex, obj) {
	if(obj.field == 'imagelibenable' ||
	   obj.field == 'deleted' ||
	   obj.field == 'nathostenabled') {
		if(value == "0")
			return '<span class="rederrormsg">false</span>';
		if(value == "1")
			return '<span class="ready">true</span>';
	}
	return value;
}

ManagementNode.prototype.nocasesort = function(a, b) {
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

ManagementNode.prototype.comparehostnames = function(a, b) {
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

var resource = new ManagementNode();

function addNewResource(title) {
	dijit.byId('addeditdlg').set('title', title);
	dijit.byId('addeditbtn').set('label', title);
	dojo.byId('editresid').value = 0;
	resetEditResource();
	dijit.byId('nathostenabled').set('checked', false);
	dijit.byId('natpublicipaddress').set('disabled', true);
	dijit.byId('natinternalipaddress').set('disabled', true);
	dijit.byId('addeditdlg').show();
}

function toggleNAThost() {
	if(dijit.byId('nathostenabled').checked) {
		dijit.byId('natpublicipaddress').set('disabled', false);
		dijit.byId('natinternalipaddress').set('disabled', false);
	}
	else {
		dijit.byId('natpublicipaddress').set('disabled', true);
		dijit.byId('natinternalipaddress').set('disabled', true);
	}
}

function inlineEditResourceCB(data, ioArgs) {
	if(data.items.status == 'success') {
		dojo.byId('saveresourcecont').value = data.items.cont;
		dijit.byId('addeditdlg').set('title', data.items.title);
		dijit.byId('addeditbtn').set('label', 'Save Changes');
		dojo.byId('editresid').value = data.items.resid;
		dijit.byId('name').set('value', data.items.data.hostname);
		dijit.byId('owner').set('value', data.items.data.owner);
		dijit.byId('ipaddress').set('value', data.items.data.IPaddress);
		dijit.byId('stateid').set('value', data.items.data.stateid);
		dijit.byId('sysadminemail').set('value', data.items.data.sysadminemail);
		dijit.byId('sharedmailbox').set('value', data.items.data.sharedmailbox);
		dijit.byId('checkininterval').set('value', data.items.data.checkininterval);
		dijit.byId('installpath').set('value', data.items.data.installpath);
		dijit.byId('timeservers').set('value', data.items.data.timeservers);
		dijit.byId('keys').set('value', data.items.data.keys);
		dijit.byId('sshport').set('value', data.items.data.sshport);
		if(parseInt(data.items.data.imagelibenable))
			dijit.byId('imagelibenable').set('value', true);
		else
			dijit.byId('imagelibenable').set('value', false);
		dijit.byId('imagelibgroupid').set('value', data.items.data.imagelibgroupid);
		dijit.byId('imagelibuser').set('value', data.items.data.imagelibuser);
		dijit.byId('imagelibkey').set('value', data.items.data.imagelibkey);
		dijit.byId('publicIPconfig').set('value', data.items.data.publicIPconfig);
		dijit.byId('publicnetmask').set('value', data.items.data.publicnetmask);
		dijit.byId('publicgateway').set('value', data.items.data.publicgateway);
		dijit.byId('publicdnsserver').set('value', data.items.data.publicdnsserver);
		dijit.byId('availablenetworks').set('value', data.items.data.availablenetworks.join(','));
		dijit.byId('federatedauth').set('value', data.items.data.federatedauth);
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

function resetEditResource() {
	var fields = ['name', 'owner', 'ipaddress', 'stateid', 'sysadminemail', 'sharedmailbox', 'checkininterval', 'installpath', 'timeservers', 'keys', 'sshport', 'imagelibenable', 'imagelibgroupid', 'imagelibuser', 'imagelibkey', 'publicIPconfig', 'publicnetmask', 'publicgateway', 'publicdnsserver', 'availablenetworks', 'federatedauth', 'natpublicipaddress', 'natinternalipaddress'];
	for(var i = 0; i < fields.length; i++) {
		dijit.byId(fields[i]).reset();
	}
	dojo.byId('addeditdlgerrmsg').innerHTML = '';
}

function saveResource() {
	var errobj = dojo.byId('addeditdlgerrmsg');
	var fields = ['name', 'owner', 'ipaddress', 'sysadminemail', 'sharedmailbox', 'installpath', 'timeservers', 'keys', 'imagelibuser', 'imagelibkey', 'publicnetmask', 'publicgateway', 'publicdnsserver', 'natpublicipaddress', 'natinternalipaddress'];
	for(var i = 0; i < fields.length; i++) {
		if(! checkValidatedObj(fields[i], errobj))
			return;
	}

	if(dojo.byId('editresid').value == 0)
		var data = {continuation: dojo.byId('addresourcecont').value};
	else
		var data = {continuation: dojo.byId('saveresourcecont').value};

	if(dijit.byId('imagelibenable').get('checked'))
		data['imagelibenable'] = 1;
	else
		data['imagelibenable'] = 0;
	if(data['imagelibenable'] == 1) {
		if(dijit.byId('imagelibuser').get('value') == '') {
			dojo.byId('addeditdlgerrmsg').innerHTML = 'Please fill in Image Library User';
			return;
		}
		if(dijit.byId('imagelibkey').get('value') == '') {
			dojo.byId('addeditdlgerrmsg').innerHTML = 'Please fill in Image Library SSH Identity Key File';
			return;
		}
	}

	data['publicIPconfig'] = dijit.byId('publicIPconfig').get('value');
	if(data['publicIPconfig'] == 'static') {
		if(dijit.byId('publicnetmask').get('value') == '') {
			dojo.byId('addeditdlgerrmsg').innerHTML = 'Please fill in Public Netmask';
			return;
		}
		if(dijit.byId('publicgateway').get('value') == '') {
			dojo.byId('addeditdlgerrmsg').innerHTML = 'Please fill in Public Gateway';
			return;
		}
		if(dijit.byId('publicdnsserver').get('value') == '') {
			dojo.byId('addeditdlgerrmsg').innerHTML = 'Please fill in Public DNS Server';
			return;
		}
	}

	if(! dijit.byId('availablenetworks').get('value').match(/^[0-9\.\/,]*$/)) {
		dojo.byId('addeditdlgerrmsg').innerHTML = 'Invalid entry submitted for Available Public Networks';
		return;
	}

	if(! dijit.byId('federatedauth').get('value').match(/^[-0-9a-zA-Z_\.:;,]*$/)) {
		dojo.byId('addeditdlgerrmsg').innerHTML = 'Invalid entry submitted for Affiliations using Federated Authentication for Linux Images';
		return;
	}

	for(var i = 0; i < fields.length; i++) {
		data[fields[i]] = dijit.byId(fields[i]).get('value');
	}
	data['stateid'] = dijit.byId('stateid').get('value');
	data['checkininterval'] = dijit.byId('checkininterval').get('value');
	data['sshport'] = dijit.byId('sshport').get('value');
	data['imagelibgroupid'] = dijit.byId('imagelibgroupid').get('value');
	data['availablenetworks'] = dijit.byId('availablenetworks').get('value');
	data['federatedauth'] = dijit.byId('federatedauth').get('value');
	data['nathostenabled'] = dijit.byId('nathostenabled').get('value');
	if(data['nathostenabled'] != 1)
		data['nathostenabled'] = 0;

	dijit.byId('addeditbtn').set('disabled', true);
	RPCwrapper(data, saveResourceCB, 1);
}

function saveResourceCB(data, ioArgs) {
	if(data.items.status == 'error') {
		dojo.byId('addeditdlgerrmsg').innerHTML = '<br>' + data.items.msg;
		dijit.byId('addeditbtn').set('disabled', false);
		return;
	}
	else if(data.items.status == 'adderror') {
		alert(data.items.errormsg);
	}
	else if(data.items.status == 'success') {
		if(data.items.action == 'add') {
			if(typeof resourcegrid !== 'undefined') {
				resourcegrid.store.newItem(data.items.data);
				resourcegrid.sort();
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
			resourcegrid.store.fetch({
				query: {id: data.items.data.id},
				onItem: function(item) {
					resourcegrid.store.setValue(item, 'name', data.items.data.hostname);
					resourcegrid.store.setValue(item, 'owner', data.items.data.owner);
					resourcegrid.store.setValue(item, 'IPaddress', data.items.data.IPaddress);
					resourcegrid.store.setValue(item, 'checkininterval', data.items.data.checkininterval);
					resourcegrid.store.setValue(item, 'imagelibenable', data.items.data.imagelibenable);
					resourcegrid.store.setValue(item, 'imagelibgroup', data.items.data.imagelibgroup);
					resourcegrid.store.setValue(item, 'imagelibkey', data.items.data.imagelibkey);
					resourcegrid.store.setValue(item, 'imagelibuser', data.items.data.imagelibuser);
					resourcegrid.store.setValue(item, 'installpath', data.items.data.installpath);
					resourcegrid.store.setValue(item, 'keys', data.items.data.keys);
					resourcegrid.store.setValue(item, 'lastcheckin', data.items.data.lastcheckin);
					resourcegrid.store.setValue(item, 'publicIPconfig', data.items.data.publicIPconfig);
					resourcegrid.store.setValue(item, 'publicdnsserver', data.items.data.publicdnsserver);
					resourcegrid.store.setValue(item, 'publicgateway', data.items.data.publicgateway);
					resourcegrid.store.setValue(item, 'publicnetmask', data.items.data.publicnetmask);
					resourcegrid.store.setValue(item, 'sharedmailbox', data.items.data.sharedmailbox);
					resourcegrid.store.setValue(item, 'sshport', data.items.data.sshport);
					resourcegrid.store.setValue(item, 'state', data.items.data.state);
					resourcegrid.store.setValue(item, 'sysadminemail', data.items.data.sysadminemail);
					resourcegrid.store.setValue(item, 'timeservers', data.items.data.timeservers);
					resourcegrid.store.setValue(item, 'nathostenabled', data.items.data.nathostenabled);
					resourcegrid.store.setValue(item, 'natpublicIPaddress', data.items.data.natpublicIPaddress);
					resourcegrid.store.setValue(item, 'natinternalIPaddress', data.items.data.natinternalIPaddress);
				},
				onComplete: function(items, result) {
					// when call resourcegrid.sort directly, the table contents disappear; not sure why
					setTimeout(function() {resourcegrid.sort();}, 10);
				}
			});
		}
		dijit.byId('addeditdlg').hide();
		resetEditResource();
		setTimeout(function() {dijit.byId('addeditbtn').set('disabled', false);}, 250);
	}
}

function toggleImageLibrary() {
	if(dijit.byId('imagelibenable').checked) {
		dijit.byId('imagelibgroupid').set('disabled', false);
		dijit.byId('imagelibuser').set('disabled', false);
		dijit.byId('imagelibkey').set('disabled', false);
	}
	else {
		dijit.byId('imagelibgroupid').set('disabled', true);
		dijit.byId('imagelibuser').set('disabled', true);
		dijit.byId('imagelibkey').set('disabled', true);
	}
}

function togglePublic() {
	if(dijit.byId('publicIPconfig').get('value') == 'static') {
		dijit.byId('publicnetmask').set('disabled', false);
		dijit.byId('publicgateway').set('disabled', false);
		dijit.byId('publicdnsserver').set('disabled', false);
	}
	else {
		dijit.byId('publicnetmask').set('disabled', true);
		dijit.byId('publicgateway').set('disabled', true);
		dijit.byId('publicdnsserver').set('disabled', true);
	}
}
