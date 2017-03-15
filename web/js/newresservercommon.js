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

function checkFixedSet(page) {
	var obj = dijit.byId(page + 'fixedIP');
	if(obj.get('value') != '' && obj.isValid()) {
		dijit.byId(page + 'netmask').set('disabled', false);
		dijit.byId(page + 'router').set('disabled', false);
		dijit.byId(page + 'dns').set('disabled', false);
		fetchRouterDNS(page);
		if(page == 'deploy')
			delayedUpdateWaitTime();
	}
	else {
		dijit.byId(page + 'netmask').set('disabled', true);
		dijit.byId(page + 'router').set('disabled', true);
		dijit.byId(page + 'dns').set('disabled', true);
	}
}

function fetchRouterDNS(page) {
	if(! dijit.byId(page + 'fixedIP').isValid() ||
	   ! dijit.byId(page + 'netmask').isValid() ||
	   dijit.byId(page + 'fixedIP').get('value') == '' ||
	   dijit.byId(page + 'netmask').get('value') == '' ||
	   (dijit.byId(page + 'router').get('value') != '' &&
	    dijit.byId(page + 'dns').get('value') != ''))
		return;
	data = {continuation: dojo.byId('fetchrouterdns').value,
	        ipaddr: dijit.byId(page + 'fixedIP').get('value'),
	        netmask: dijit.byId(page + 'netmask').get('value'),
	        page: page};
	RPCwrapper(data, fetchRouterDNSCB, 1);
}

function fetchRouterDNSCB(data, ioArgs) {
	if(data.items.status == 'success') {
		if(dijit.byId(data.items.page + 'router').get('value') == '')
			dijit.byId(data.items.page + 'router').set('value', data.items.router);
		if(dijit.byId(data.items.page + 'dns').get('value') == '')
			dijit.byId(data.items.page + 'dns').set('value', data.items.dns);
	}
}

function validateNetmask(val) {
	var regex = new RegExp("^[1]+0[^1]+$");
	var d = val.split('.');
	var bnetmask = 256 * ((256 * (256 * +d[0] + +d[1])) + +d[2]) + +d[3];
	//var nmstring = dojox.string.sprintf('%032b', bnetmask);
	var nmstring = int2bstr(bnetmask);
	if(regex.test(nmstring))
		return true;
	return false;
}

function int2bstr(a) {
	var b = '';
	var c = a;
	while(c > 0) {
		if(c % 2 == 0)
			b = '0' + b;
		else
			b = '1' + b;
		c = parseInt(c / 2);
	}
	var len = b.length;
	while(len < 32) {
		b = '0' + b;
		len++;
	}
	return b;
}

/*function populateProfileStore(cont) {
	if(typeof(offsetreloading) != 'undefined' && offsetreloading == 1)
		return;
	RPCwrapper({continuation: cont}, populateProfileStoreCB, 1);
}

function populateProfileStoreCB(data, ioArgs) {
	if(typeof(profilesstore) == "undefined")
		return;
	var store = profilesstore;
	for(var i = 0; i < data.items.length; i++) {
		store.newItem({id: data.items[i].id, name: data.items[i].name, desc: data.items[i].desc, access: data.items[i].access});
	}
	if(dijit.byId('deployprofileid'))
		dijit.byId('deployprofileid').setStore(profilesstore, '', {query: {id:new RegExp("^(?:(?!70000).)*$")}});
	if(dijit.byId('profileid'))
		dijit.byId('profileid').setStore(profilesstore, '', {query: {id:new RegExp("^(?:(?!70000).)*$"),access:'admin'}});
	if(dijit.byId('profiles'))
		dijit.byId('profiles').setStore(profilesstore, '', {query: {id:new RegExp("^(?:(?!70000).)*$"),access:'admin'}});
	if(dojo.byId('ingroups'))
		getGroups();
}

function deployProfileChanged() {
	profilesstore.fetch({
		query: {id: dijit.byId('deployprofileid').get('value')},
		onItem: function(item, request) {
			var desc = profilesstore.getValue(item, 'desc');
			if(desc == '') {
				desc = _('(No description)');
			}
			dojo.byId('deploydesc').innerHTML = desc;
		}
	});
}

function getServerProfileData(cont, id, cb) {
	if(id == 'profileid') {
		dijit.byId('fetchProfilesBtn').set('label', _('Working...'));
		dijit.byId('fetchProfilesBtn').set('disabled', true);
	}
	var data = {continuation: cont,
	            id: dijit.byId(id).get('value')};
	RPCwrapper(data, cb, 1);
	document.body.style.cursor = 'wait';
}

function getServerProfileDataDeployCB(data, ioArgs) {
	document.body.style.cursor = 'default';
	if(data.items.error) {
		alert(_('You do not have access to apply this server profile.'));
		return;
	}
	dojo.byId('appliedprofileid').value = data.items.id;
	dijit.byId('deployimage').set('value', data.items.imageid);
	setTimeout(function() {dijit.byId('deployname').set('value', data.items.name);}, 1); // want this to occur after selectEnvironment is called due to deployimage being set
	dijit.byId('deploynetmask').set('value', data.items.netmask);
	dijit.byId('deployrouter').set('value', data.items.router);
	dijit.byId('deploydns').set('value', data.items.dns);
	//dijit.byId('deployfixedMAC').set('value', data.items.fixedMAC);
	if(dijit.byId('deployadmingroup'))
		dijit.byId('deployadmingroup').set('value', data.items.admingroupid);
	else
		dojo.byId('deployadmingroup').value = data.items.admingroupid;
	if(dijit.byId('deploylogingroup'))
		dijit.byId('deploylogingroup').set('value', data.items.logingroupid);
	else
		dojo.byId('deploylogingroup').value = data.items.logingroupid;
	//dijit.byId('deploymonitored').set('value', parseInt(data.items.monitored));
	dijit.byId('deployfixedIP').set('value', data.items.fixedIP);
	if(dijit.byId('deployfixedIP').isValid() && dijit.byId('deployfixedIP').get('value') != '') {
		dijit.byId('deploynetmask').set('value', data.items.netmask);
		dijit.byId('deployrouter').set('value', data.items.router);
		dijit.byId('deploydns').set('value', data.items.dns);
		dijit.byId('deploynetmask').set('disabled', false);
		dijit.byId('deployrouter').set('disabled', false);
		dijit.byId('deploydns').set('disabled', false);
	}
	else {
		dijit.byId('deploynetmask').set('value', '');
		dijit.byId('deployrouter').set('value', '');
		dijit.byId('deploydns').set('value', '');
		dijit.byId('deploynetmask').set('disabled', true);
		dijit.byId('deployrouter').set('disabled', true);
		dijit.byId('deploydns').set('disabled', true);
	}
}*/
