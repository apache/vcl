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

function ADdomain() {
	Resource.apply(this, Array.prototype.slice.call(arguments));
	this.restype = 'addomain';
}
ADdomain.prototype = new Resource();

var resource = new ADdomain();

function addNewResource(title) {
	dijit.byId('addeditdlg').set('title', title);
	dijit.byId('addeditbtn').set('label', title);
	dojo.byId('editresid').value = 0;
	resetEditResource();
	dijit.byId('password').set('value', '');
	dijit.byId('password2').set('value', '');
	dijit.byId('addeditdlg').show();
}

function inlineEditResourceCB(data, ioArgs) {
	if(data.items.status == 'success') {
		dojo.byId('saveresourcecont').value = data.items.cont;
		dijit.byId('addeditdlg').set('title', data.items.title);
		dijit.byId('addeditbtn').set('label', 'Save Changes');
		dojo.byId('editresid').value = data.items.rscid;
		dijit.byId('name').set('value', data.items.data.name);
		dijit.byId('owner').set('value', data.items.data.owner);

		dijit.byId('domaindnsname').set('value', data.items.data.domaindnsname);
		dijit.byId('username').set('value', data.items.data.username);
		dijit.byId('dnsservers').set('value', data.items.data.dnsservers);

		dijit.byId('password').set('value', '********');
		dijit.byId('password2').set('value', 'xxxxxxxx');

		dojo.byId('addeditdlgerrmsg').innerHTML = '';
		dijit.byId('addeditdlg').show();
	}
	else if(data.items.status == 'noaccess') {
		alert('Access denied to edit this item');
	}
}

function resetEditResource() {
	var fields = ['name', 'owner', 'domaindnsname', 'username', 'password', 'password2', 'dnsservers'];
	for(var i = 0; i < fields.length; i++) {
		dijit.byId(fields[i]).reset();
	}
	dojo.byId('addeditdlgerrmsg').innerHTML = '';
}

function saveResource() {
	var errobj = dojo.byId('addeditdlgerrmsg');
	var fields = ['name', 'owner', 'domaindnsname', 'username', 'password', 'password2', 'dnsservers'];

	if(dojo.byId('editresid').value == 0)
		var data = {continuation: dojo.byId('addresourcecont').value};
	else
		var data = {continuation: dojo.byId('saveresourcecont').value};

	for(var i = 0; i < fields.length; i++) {
		if(! checkValidatedObj(fields[i], errobj))
			return;
		data[fields[i]] = dijit.byId(fields[i]).get('value');
	}
	if(dojo.byId('editresid').value != 0 &&
	   dijit.byId('password').get('value') == '********' &&
	   dijit.byId('password2').get('value') == 'xxxxxxxx') {
		data['password'] = '';
		data['password2'] = '';
	}
	else if(dijit.byId('password').get('value') != dijit.byId('password2').get('value')) {
		dojo.byId('addeditdlgerrmsg').innerHTML = _('Passwords do not match');
		return;
	}

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
					var fields = ['name', 'owner', 'domaindnsname', 'username','dnsservers'];
					for(var i = 0; i < fields.length; i++) {
						dijit.byId(fields[i]).reset();
						resourcegrid.store.setValue(item, fields[i], data.items.data[fields[i]]);
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
		setTimeout(function() {dijit.byId('addeditbtn').set('disabled', false);}, 250);
	}
}
