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
var profilesstoredata = {
	identifier: 'id',
	label: 'name',
	items: []
}
var allprofiles = '';
var allgroups = '';

function generalReqCB(data, ioArgs) {
	eval(data);
	document.body.style.cursor = 'default';
}

function selectProfileChanged() {
	if(dijit.byId('profileid').get('value') == 70000)
		return;
	dojo.addClass('serverprofiledata', 'hidden');
	dijit.byId('fetchProfilesBtn').set('disabled', false);
	dijit.byId('delProfilesBtn').set('disabled', false);
	if(dijit.byId('profileid').getOptions(0) &&
	   dijit.byId('profileid').getOptions(0).value == 70000)
		dijit.byId('profileid').setStore(profilesstore, '', {query: {id:new RegExp("^(?:(?!70000).)*$"),access:'admin'}});
}

function newServerProfile(cont) {
	dijit.byId('profileid').setStore(profilesstore, '', {query: {id: '*',access:'admin'}});
	dijit.byId('profileid').set('value', '70000');
	clearProfileItems();
	dijit.byId('fetchProfilesBtn').set('disabled', true);
	dijit.byId('delProfilesBtn').set('disabled', true);
	dojo.removeClass('serverprofiledata', 'hidden');
}

function clearProfileItems() {
	dijit.byId('profilename').set('value', '');
	dijit.byId('profiledesc').set('value', '');
	dijit.byId('profileimage').reset();
	dijit.byId('profilefixedIP').set('value', '');
	//dijit.byId('profilefixedMAC').set('value', '');
	if(dijit.byId('profileadmingroup'))
		dijit.byId('profileadmingroup').reset();
	else
		dojo.byId('profileadmingroup').value = 0;
	if(dijit.byId('profilelogingroup'))
		dijit.byId('profilelogingroup').reset();
	else
		dojo.byId('profilelogingroup').value = 0;
	dijit.byId('profilemonitored').reset();
}

function saveServerProfile(cont) {
	if((dijit.byId('profileimage') && ! dijit.byId('profileimage').isValid()) ||
	   (dijit.byId('profileadmingroup') && ! dijit.byId('profileadmingroup').isValid()) ||
	   (dijit.byId('profilelogingroup') && ! dijit.byId('profilelogingroup').isValid()) ||
	   ! dijit.byId('profilefixedIP').isValid() /*||
	   ! dijit.byId('profilefixedMAC').isValid()*/) {
		alert('Please correct the fields with invalid input');
		return;
	}
	dijit.byId('saveProfilesBtn').set('label', 'Working...');
	dijit.byId('saveProfilesBtn').set('disabled', true);
	if(dijit.byId('profileimage'))
		var imageid = dijit.byId('profileimage').get('value');
	else
		var imageid = dojo.byId('profileimage').value;
	if(dijit.byId('profileadmingroup'))
		var admingroupid = dijit.byId('profileadmingroup').get('value');
	else
		var admingroupid = dojo.byId('profileadmingroup').value;
	if(dijit.byId('profilelogingroup'))
		var logingroupid = dijit.byId('profilelogingroup').get('value');
	else
		var logingroupid = dojo.byId('profilelogingroup').value;
	var data = {continuation: cont,
	            id: dijit.byId('profileid').get('value'),
	            name: dijit.byId('profilename').get('value'),
	            desc: dijit.byId('profiledesc').get('value'),
	            imageid: imageid,
	            //fixedMAC: dijit.byId('profilefixedMAC').get('value'),
	            admingroupid: admingroupid,
	            logingroupid: logingroupid,
	            monitored: dijit.byId('profilemonitored').get('value'),
	            fixedIP: dijit.byId('profilefixedIP').get('value'),
	            netmask: dijit.byId('profilenetmask').get('value'),
	            router: dijit.byId('profilerouter').get('value'),
	            dns: dijit.byId('profiledns').get('value')};
	RPCwrapper(data, saveServerProfileCB, 1);
}

function saveServerProfileCB(data, ioArgs) {
	dijit.byId('saveProfilesBtn').set('label', 'Save Profile');
	dijit.byId('saveProfilesBtn').set('disabled', false);
	if(data.items.error) {
		alert(data.items.msg);
		return;
	}
	var selobj = dijit.byId('profileid');
	selobj.setStore(profilesstore, '', {query: {id:new RegExp("^(?:(?!70000).)*$"),access:'admin'}});
	if(data.items.newprofile == 1) {
		dojo.removeClass('serverprofiledata', 'hidden');
		if(allprofiles.length == 0)
			dojo.removeClass('profileslist', 'hidden');
		profilesstore.newItem({id: data.items.id,
		                       name: data.items.name,
		                       access: data.items.access,
		                       desc: data.items.desc});
		selobj.set('value', data.items.id);
		getProfiles();
	}
	else {
		if(dijit.byId('deployprofileid').get('value') == data.items.id) {
			var desc = data.items.desc;
			if(data.items.desc == '') {
				desc = '(No description)';
			}
			dojo.byId('deploydesc').innerHTML = desc;
		}
		var items = profilesstore.fetch({
			query: {id: data.items.id},
			newname: data.items.name,
			newdesc: data.items.desc,
			onItem: function(item, request) {
				profilesstore.setValue(item, 'desc', request.newdesc);
				if(profilesstore.getValue(item, 'name') != request.newname) {
					profilesstore.setValue(item, 'name', request.newname);
					getProfiles();
				}
			}
		});
	}
	dojo.removeClass('savestatus', 'hidden');
	dijit.byId('fetchProfilesBtn').set('disabled', false);
	dijit.byId('delProfilesBtn').set('disabled', false);
	setTimeout(clearSaveStatus, 10000);
}

function getServerProfileDataManageCB(data, ioArgs) {
	document.body.style.cursor = 'default';
	dijit.byId('fetchProfilesBtn').set('label', 'Configure Profile');
	dijit.byId('fetchProfilesBtn').set('disabled', false);
	if(data.items.error) {
		alert('You do not have access to modify this server profile.');
		return;
	}
	clearProfileItems();
	dijit.byId('profilename').set('value', data.items.name);
	dijit.byId('profiledesc').set('value', data.items.description);
	dijit.byId('profileimage').set('value', data.items.imageid);
	//dijit.byId('profilefixedMAC').set('value', data.items.fixedMAC);
	if(dijit.byId('profileadmingroup'))
		dijit.byId('profileadmingroup').set('value', data.items.admingroupid);
	else
		dojo.byId('profileadmingroup').value = data.items.admingroupid;
	if(dijit.byId('profilelogingroup'))
		dijit.byId('profilelogingroup').set('value', data.items.logingroupid);
	else
		dojo.byId('profilelogingroup').value = data.items.logingroupid;
	dijit.byId('profilemonitored').set('value', parseInt(data.items.monitored));
	dijit.byId('profilefixedIP').set('value', data.items.fixedIP);
	if(dijit.byId('profilefixedIP').isValid() && dijit.byId('profilefixedIP') != '') {
		dijit.byId('profilenetmask').set('value', data.items.netmask);
		dijit.byId('profilerouter').set('value', data.items.router);
		dijit.byId('profiledns').set('value', data.items.dns);
		dijit.byId('profilenetmask').set('disabled', false);
		dijit.byId('profilerouter').set('disabled', false);
		dijit.byId('profiledns').set('disabled', false);
	}
	else {
		dijit.byId('profilenetmask').set('value', '');
		dijit.byId('profilerouter').set('value', '');
		dijit.byId('profiledns').set('value', '');
		dijit.byId('profilenetmask').set('disabled', true);
		dijit.byId('profilerouter').set('disabled', true);
		dijit.byId('profiledns').set('disabled', true);
	}
	dojo.removeClass('serverprofiledata', 'hidden');
}

function confirmDelServerProfile(cont) {
	dojo.byId('delcont').value = cont;
	dijit.byId('confirmDeleteProfile').show();
}

function delServerProfile() {
	if(allprofiles.length == 1)
		dojo.addClass('profileslist', 'hidden');
	dijit.byId('confirmDeleteProfile').hide();
	var data = {continuation: dojo.byId('delcont').value,
	            id: dijit.byId('profileid').get('value')};
	RPCwrapper(data, delServerProfileCB, 1);
}

function delServerProfileCB(data, ioArgs) {
	if(data.items.error) {
		alert(data.items.msg);
		return;
	}
	clearProfileItems();
	dojo.addClass('serverprofiledata', 'hidden');
	profilesstore.fetch({
		query: {id: data.items.id},
		onItem: function(item, request) {
			profilesstore.deleteItem(item);
			dijit.byId('deployprofileid').removeOption({value: item.id[0]});
			dijit.byId('profileid').removeOption({value: item.id[0]});
			dijit.byId('profiles').removeOption({value: item.id[0]});
		}
	});
	getProfiles();
}

function clearSaveStatus() {
	dojo.addClass('savestatus', 'hidden');
}

function getGroups() {
	document.body.style.cursor = 'wait';
	var selobj = dojo.byId('ingroups');
	for(var i = selobj.options.length - 1; i >= 0; i--) {
		selobj.remove(i);
	}
	selobj = dojo.byId('outgroups');
	for(i = selobj.options.length - 1; i >= 0; i--) {
		selobj.remove(i);
	}

	var profileid = dijit.byId('profiles').get('value');
	if(profileid == '') {
		document.body.style.cursor = 'default';
		return;
	}
	profilesstore.fetch({
		query: {id: profileid},
		onItem: function(item, request) {
			dojo.byId('inprofilename').innerHTML = item.name;
			dojo.byId('outprofilename').innerHTML = item.name;
		}
	});

	var data = {continuation: dojo.byId('grpcont').value,
	            profileid: profileid};

	RPCwrapper(data, getGroupsCB, 1);
}

function getGroupsCB(data, ioArgs) {
	var obj = dojo.byId('ingroups');
	for(var i = 0; i < data.items.ingroups.length; i++) {
		obj.options[obj.options.length] = new Option(data.items.ingroups[i].name, data.items.ingroups[i].id);
	}
	obj = dojo.byId('outgroups');
	for(var i = 0; i < data.items.outgroups.length; i++) {
		obj.options[obj.options.length] = new Option(data.items.outgroups[i].name, data.items.outgroups[i].id);
	}
	allgroups = data.items.all;
	dojo.removeClass('groupsdiv', 'hidden');
	document.body.style.cursor = 'default';
}

function getProfiles() {
	var selobj = dojo.byId('inprofiles');
	if(! selobj)
		return;
	document.body.style.cursor = 'wait';
	for(var i = selobj.options.length - 1; i >= 0; i--) {
		selobj.remove(i);
	}
	selobj = dojo.byId('outprofiles');
	for(i = selobj.options.length - 1; i >= 0; i--) {
		selobj.remove(i);
	}

	var obj = dijit.byId('profileGroups');
	if(! obj)
		return;
	if(obj.options.length) {
		var groupname = obj.getOptions(dijit.byId('profileGroups').get('value')).label;
		dojo.byId('ingroupname').innerHTML = groupname;
		dojo.byId('outgroupname').innerHTML = groupname;
	}

	var data = {continuation: dojo.byId('profilecont').value,
	            groupid: dijit.byId('profileGroups').get('value')};

	RPCwrapper(data, getProfilesCB, 1);
}

function getProfilesCB(data, ioArgs) {
	var obj = document.getElementById('inprofiles');
	for(var i = 0; i < data.items.inprofiles.length; i++) {
		obj.options[obj.options.length] = new Option(data.items.inprofiles[i].name, data.items.inprofiles[i].id);
	}
	obj = document.getElementById('outprofiles');
	for(var i = 0; i < data.items.outprofiles.length; i++) {
		obj.options[obj.options.length] = new Option(data.items.outprofiles[i].name, data.items.outprofiles[i].id);
	}
	allprofiles = data.items.all;
	if(allprofiles.length == 0) {
		dojo.addClass('profileslist', 'hidden');
		dojo.addClass('groupprofilesspan', 'hidden');
		dojo.removeClass('noprofilegroupsspan', 'hidden');
	}
	else {
		dojo.removeClass('profileslist', 'hidden');
		if(dijit.byId('profileGroups').options.length) {
			dojo.removeClass('groupprofilesspan', 'hidden');
			dojo.addClass('noprofilegroupsspan', 'hidden');
		}
	}
	dojo.removeClass('profilesdiv', 'hidden');
	document.body.style.cursor = 'default';
}

function addRemItem(cont, objid1, objid2, cb) {
	var id = dijit.byId(objid1).get('value');

	var obj = dojo.byId(objid2);
	var listids = "";
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected) {
			listids = listids + ',' + obj.options[i].value;
			obj.remove(i);
		}
	}
	if(listids == "")
		return;
	document.body.style.cursor = 'wait';
	var data = {continuation: cont,
	            listids: listids,
	            id: id};
	RPCwrapper(data, cb, 1);
}

function addRemGroupCB(data, ioArgs) {
	/*
	for each profileid sent back we
		search through allprofiles until we find it keeping track of the previous item with inout == 1
		we set allprofiles[profileid].inout to 1
		we find the previous item in the select.options array
		we insert a new option right after that one
	*/
	var byprofileselid = dijit.byId('profiles').get('value');
	var reloadbyprofile = 0;
	var profiles = data.items.profiles;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	if(addrem == 0 && data.items.removedaccess == 1) {
		var searchids = data.items.remprofileids.join('|');
		var regex = new RegExp("(" + searchids + ")");
		for(var i = profiles.length; i >= 0; i--) {
			if(regex.test(allprofiles[i].id)) {
				allprofiles.splice(i, 1);
			}
		}
		profilesstore.fetch({
			query: {id: regex},
			onItem: function(item, request) {
				profilesstore.deleteItem(item);
				dijit.byId('profileid').removeOption({value: item.id[0]});
				dijit.byId('profiles').removeOption({value: item.id[0]});
			}
		});
	}
	if(addrem)
		var obj = document.getElementById('inprofiles');
	else
		var obj = document.getElementById('outprofiles');
	for(var i = 0; i < profiles.length; i++) {
		if(profiles[i] == byprofileselid )
			reloadbyprofile = 1;
		var lastid = -1;
		for(var j = 0; j < allprofiles.length; j++) {
			if(allprofiles[j].id == profiles[i]) {
				if(addrem == 1)
					allprofiles[j].inout = 1;
				else
					allprofiles[j].inout = 0;
				if(lastid < 0) {
					var before = obj.options[0];
					var newoption = new Option(allprofiles[j].name, allprofiles[j].id);
					try {
						obj.add(newoption, before);
					}
					catch(ex) {
						obj.add(newoption, 0);
					}
					break;
				}
				else {
					for(var k = 0; k < obj.options.length; k++) {
						if(obj.options[k].value == lastid) {
							var before = obj.options[k + 1];
							var newoption = new Option(allprofiles[j].name, allprofiles[j].id);
							if(before)
								try {
									obj.add(newoption, before);
								}
								catch(ex) {
									obj.add(newoption, k + 1);
								}
							else
								obj.options[obj.options.length] = newoption;
							break;
						}
					}
				}
				break;
			}
			if(allprofiles[j].inout == addrem)
				lastid = allprofiles[j].id;
		}
	}
	document.body.style.cursor = 'default';
	if(reloadbyprofile)
		getGroups();
}

function addRemProfileCB(data, ioArgs) {
	var bygroupselid = dijit.byId('profileGroups').get('value');
	var reloadbygroup = 0;
	var groups = data.items.groups;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	if(addrem)
		var obj = dojo.byId('ingroups');
	else
		var obj = dojo.byId('outgroups');
	for(var i = 0; i < groups.length; i++) {
		if(groups[i] == bygroupselid )
			reloadbygroup = 1;
		var lastid = -1;
		for(var j = 0; j < allgroups.length; j++) {
			if(allgroups[j].id == groups[i]) {
				if(addrem == 1)
					allgroups[j].inout = 1;
				else
					allgroups[j].inout = 0;
				if(lastid < 0) {
					var before = obj.options[0];
					var newoption = new Option(allgroups[j].name, allgroups[j].id);
					try {
						obj.add(newoption, before);
					}
					catch(ex) {
						obj.add(newoption, 0);
					}
					break;
				}
				else {
					for(var k = 0; k < obj.options.length; k++) {
						if(obj.options[k].value == lastid) {
							var before = obj.options[k + 1];
							var newoption = new Option(allgroups[j].name, allgroups[j].id);
							if(before)
								try {
									obj.add(newoption, before);
								}
								catch(ex) {
									obj.add(newoption, k + 1);
								}
							else
								obj.options[obj.options.length] = newoption;
							break;
						}
					}
				}
				break;
			}
			if(allgroups[j].inout == addrem) {
				lastid = allgroups[j].id;
			}
		}
	}
	if(addrem == 0 && data.items.removedaccess == 1) {
		profilesstore.fetch({
			query: {id: data.items.profileid},
			onItem: function(item, request) {
				profilesstore.deleteItem(item);
				dijit.byId('profileid').removeOption({value: item.id[0]});
				dijit.byId('profiles').removeOption({value: item.id[0]});
				dojo.addClass('groupsdiv', 'hidden');
				getProfiles();
			}
		});
	}
	document.body.style.cursor = 'default';
	if(reloadbygroup)
		getProfiles();
}

function submitDeploy() {
	var cont = dojo.byId('deploycont').value;
	if((dijit.byId('deployimage') && ! dijit.byId('deployimage').isValid()) ||
	   (dijit.byId('deployadmingroup') && ! dijit.byId('deployadmingroup').isValid()) ||
	   (dijit.byId('deploylogingroup') && ! dijit.byId('deploylogingroup').isValid())) {
		alert('Please correct the fields with invalid input');
		return;
	}
	if(dojo.byId('startlater').checked &&
	   (! dijit.byId('deploystarttime').isValid() ||
	   ! dijit.byId('deploystartdate').isValid())) {
		dijit.byId('deploystarttime')._hasBeenBlurred = true;
		dijit.byId('deploystarttime').validate();
		dijit.byId('deploystartdate')._hasBeenBlurred = true;
		dijit.byId('deploystartdate').validate();
		alert('Please correct the fields with invalid input');
		return;
	}
	if(dojo.byId('endat').checked &&
	   (! dijit.byId('deployendtime').isValid() ||
	   ! dijit.byId('deployenddate').isValid())) {
		dijit.byId('deployendtime')._hasBeenBlurred = true;
		dijit.byId('deployendtime').validate();
		dijit.byId('deployenddate')._hasBeenBlurred = true;
		dijit.byId('deployenddate').validate();
		alert('Please correct the fields with invalid input');
		return;
	}
	if(dojo.byId('startlater').checked) {
		var today = new Date();
		today.setMilliseconds(0);
		var testday = dijit.byId('deploystartdate').get('value');
		var tmp = dijit.byId('deploystarttime').get('value');
		testday.setHours(tmp.getHours());
		testday.setMinutes(tmp.getMinutes());
		testday.setSeconds(tmp.getSeconds());
		testday.setMilliseconds(tmp.getMilliseconds());
		if(testday < today) {
			alert('The starting time and date must be in the future.');
			return;
		}
	}
	if(dojo.byId('endat').checked) {
		if(dojo.byId('startlater').checked) {
			var teststart = dijit.byId('deploystartdate').get('value');
			var tmp = dijit.byId('deploystarttime').get('value');
			teststart.setHours(tmp.getHours());
			teststart.setMinutes(tmp.getMinutes());
			teststart.setSeconds(tmp.getSeconds());
			teststart.setMilliseconds(tmp.getMilliseconds());
		}
		else {
			var teststart = new Date();
			teststart.setMilliseconds(0);
		}
		var testend = dijit.byId('deployenddate').get('value');
		var tmp = dijit.byId('deployendtime').get('value');
		testend.setHours(tmp.getHours());
		testend.setMinutes(tmp.getMinutes());
		testend.setSeconds(tmp.getSeconds());
		testend.setMilliseconds(tmp.getMilliseconds());
		if(testend <= teststart) {
			alert('The ending time and date must be later than the starting time and date.');
			return;
		}
	}
	if(dijit.byId('deploybtn').get('label') == 'View Available Times') {
		dijit.byId('suggestDlgBtn').set('disabled', true);
		showSuggestedTimes();
		return;
	}
	var data = {continuation: cont,
	            profileid: dojo.byId('appliedprofileid').value};
	data.name = dijit.byId('deployname').get('value');
	if(dijit.byId('deployimage'))
		data.imageid = dijit.byId('deployimage').get('value');
	else
		data.imageid = dojo.byId('deployimage').value;
	if(dijit.byId('deployadmingroup'))
		data.admingroupid = dijit.byId('deployadmingroup').get('value');
	else
		data.admingroupid = dojo.byId('deployadmingroup').value;
	if(dijit.byId('deploylogingroup'))
		data.logingroupid = dijit.byId('deploylogingroup').get('value');
	else
		data.logingroupid = dojo.byId('deploylogingroup').value;
	data.ipaddr = dijit.byId('deployfixedIP').get('value');
	if(data.ipaddr != '') {
		data.netmask = dijit.byId('deploynetmask').get('value');
		data.router = dijit.byId('deployrouter').get('value');
		data.dns = dijit.byId('deploydns').get('value');
	}
	else {
		data.netmask = '';
		data.router = '';
		data.dns = '';
	}
	//data.macaddr = dijit.byId('deployfixedMAC').get('value');
	/*if(dijit.byId('deploymonitored').get('value') == 'on')
		data.monitored = 1;
	else
		data.monitored = 0;*/
	if(dojo.byId('startnow').checked) {
		data.startmode = 0;
	}
	if(dojo.byId('startlater').checked) {
		data.startmode = 1;
		var time = dijit.byId('deploystarttime').get('value');
		var date = dijit.byId('deploystartdate').get('value');
		data.start = dojox.string.sprintf('%d%02d%02d%02d%02d',
		                                  date.getFullYear(),
		                                  date.getMonth() + 1,
		                                  date.getDate(),
		                                  time.getHours(),
		                                  time.getMinutes());
	}
	if(dojo.byId('endindef').checked) {
		data.endmode = 0;
	}
	if(dojo.byId('endat').checked) {
		data.endmode = 1;
		var time = dijit.byId('deployendtime').get('value');
		var date = dijit.byId('deployenddate').get('value');
		data.end = dojox.string.sprintf('%d%02d%02d%02d%02d',
		                                date.getFullYear(),
		                                date.getMonth() + 1,
		                                date.getDate(),
		                                time.getHours(),
		                                time.getMinutes());
	}
	dijit.byId('deploybtn').set('label', 'Working...');
	dijit.byId('deploybtn').set('disabled', true);
	RPCwrapper(data, submitDeployCB, 1);
}

function submitDeployCB(data, ioArgs) {
	if(data.items.error) {
		dojo.byId('deployerr').innerHTML = data.items.msg;
		dojo.removeClass('deployerr', 'hidden');
		dojo.byId('deploycont').value = data.items.cont;
		dijit.byId('deploybtn').set('disabled', false);
		if(data.items.error == 2) {
			dijit.byId('deploybtn').set('label', 'View Available Times');
			dojo.byId('suggestcont').value = data.items.sugcont;
		}
		else
			dijit.byId('deploybtn').set('label', 'Deploy Server');
		return;
	}
	if(data.items.success) {
		window.location.href = data.items.redirecturl;
	}
}

function useSuggestedDeploySlot() {
	var slot = suggestTimeData[dojo.byId('selectedslot').value];
	dojo.byId('startlater').checked = true;
	var tmp = parseInt(slot['startts'] + '000');
	var s = new Date(tmp);
	var e = new Date(tmp + parseInt(slot['duration'] + '000'));
	dijit.byId('deploystartdate').set('value', s);
	dijit.byId('deploystarttime').set('value', s);

	var testend = new Date(2038, 0, 1, 0, 0, 0, 0);
	if(e >= testend) {
		dojo.byId('endindef').checked = true;
	}
	else {
		dojo.byId('endat').checked = true;
		dijit.byId('deployenddate').set('value', e);
		dijit.byId('deployendtime').set('value', e);
	}

	//dojo.byId('waittime').className = 'hidden';
	dijit.byId('suggestedTimes').hide();
	dijit.byId('deploybtn').set('label', 'Shake &amp; Bake Server');
	dojo.addClass('deployerr', 'hidden');
	//updateWaitTime(0);
}
