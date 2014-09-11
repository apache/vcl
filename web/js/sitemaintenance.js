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

function generalReqCB(data, ioArgs) {
	eval(data);
	document.body.style.cursor = 'default';
}

function showAddSiteMaintenance(cont) {
	dijit.byId('editDialog').attr('title', 'Add Site Maintenance');
	dojo.byId('editheader').innerHTML = 'Add Site Maintenance';
	dojo.byId('edittext').innerHTML = 'Fill in the following items and click <b>Create Site Maintenance</b>';
	dijit.byId('editsubmitbtn').attr('label', 'Create Site Maintenance');
	dijit.byId('editsubmitbtn').attr('disable', 'false');
	dijit.byId('hoursahead').attr('value', 168);
	dojo.byId('submitcont').value = cont;
	dijit.byId('editDialog').show();
}

function showEditSiteMaintenance(cont) {
	document.body.style.cursor = 'wait';
	RPCwrapper({continuation: cont}, showEditSiteMaintenanceCB, 1);
}

function showEditSiteMaintenanceCB(data, ioArgs) {
	dijit.byId('editDialog').attr('title', 'Edit Site Maintenance Entry');
	dojo.byId('editheader').innerHTML = 'Edit Site Maintenance Entry';
	dojo.byId('edittext').innerHTML = 'Adjust in the following items and click <b>Save Changes</b>';
	dijit.byId('editsubmitbtn').attr('label', 'Save Changes');
	dijit.byId('editsubmitbtn').attr('disable', 'false');

	var start = new Date(data.items.start);
	var end = new Date(data.items.end);
	dijit.byId('starttime').attr('value', start);
	dijit.byId('startdate').attr('value', start);
	dijit.byId('endtime').attr('value', end);
	dijit.byId('enddate').attr('value', end);
	dijit.byId('hoursahead').attr('value', data.items.hoursahead);
	updateDaysHours(data.items.hoursahead);
	dijit.byId('allowreservations').attr('value', data.items.allowreservations);
	dijit.byId('reason').attr('value', data.items.reason);
	dijit.byId('usermessage').attr('value', data.items.usermessage);
	dojo.byId('submitcont').value = data.items.cont;

	dijit.byId('editDialog').show();
	document.body.style.cursor = 'default';
}

function updateDaysHours(val) {
	var days = Math.floor(val / 24);
	var hours = val % 24;
	var text = days + " days, " + hours;
	if(hours == 1)
		text += " hour";
	else
		text += " hours";
	dojo.byId('dayshours').innerHTML = text;
	return val;
}

function editSubmit() {
	if(! dijit.byId('starttime').isValid() || ! dijit.byId('startdate')) {
		dijit.byId('starttime')._hasBeenBlurred = true;
		dijit.byId('starttime').validate();
		dijit.byId('startdate')._hasBeenBlurred = true;
		dijit.byId('startdate').validate();
		alert('Please specify a valid start time and date');
		return;
	}
	if(! dijit.byId('endtime').isValid() || ! dijit.byId('enddate')) {
		dijit.byId('endtime')._hasBeenBlurred = true;
		dijit.byId('endtime').validate();
		dijit.byId('enddate')._hasBeenBlurred = true;
		dijit.byId('enddate').validate();
		alert('Please specify a valid end time and date');
		return;
	}
	if(! dijit.byId('hoursahead').isValid()) {
		alert('Please specify a valid number of hours ahead');
		return;
	}
	if(dijit.byId('usermessage').attr('value').length == 0) {
		alert('Please fill in something for the User Message');
		return;
	}
	var start = dijit.byId('startdate').value;
	var tmp = dijit.byId('starttime').value;
	start.setHours(tmp.getHours());
	start.setMinutes(tmp.getMinutes());
	start.setSeconds(tmp.getSeconds());
	start.setMilliseconds(0);
	var now = new Date();
	if(start < now) {
		alert('The start time and date must be later than the current time.');
		return;
	}
	var end = dijit.byId('enddate').value;
	var tmp = dijit.byId('endtime').value;
	end.setHours(tmp.getHours());
	end.setMinutes(tmp.getMinutes());
	end.setSeconds(tmp.getSeconds());
	end.setMilliseconds(0);
	if(end <= start) {
		alert('The end time and date must be later than the start time and date.');
		return;
	}
	var numstart = dojox.string.sprintf('%04d%02d%02d%02d%02d', start.getFullYear(),
	                                    start.getMonth() + 1, start.getDate(),
	                                    start.getHours(), start.getMinutes());
	var numend = dojox.string.sprintf('%04d%02d%02d%02d%02d', end.getFullYear(),
	                                  end.getMonth() + 1, end.getDate(),
	                                  end.getHours(), end.getMinutes());
	var data = {continuation: dojo.byId('submitcont').value,
	            start: numstart,
	            end: numend,
	            hoursahead: dijit.byId('hoursahead').attr('value'),
	            allowreservations: dijit.byId('allowreservations').value,
	            reason: dijit.byId('reason').attr('value'),
	            usermessage: dijit.byId('usermessage').attr('value')};
	document.body.style.cursor = 'wait';
	dijit.byId('editsubmitbtn').attr('disable', 'true');
	RPCwrapper(data, generalReqCB);
}

function clearEdit() {
	dijit.byId('editDialog').hide();
	dijit.byId('editDialog').attr('title', '');
	dojo.byId('editheader').innerHTML = '';
	dojo.byId('edittext').innerHTML = '';
	dijit.byId('editsubmitbtn').attr('label', '');
	dijit.byId('editsubmitbtn').attr('disable', 'false');
	dijit.byId('hoursahead').attr('value', 168);
	dojo.byId('dayshours').innerHTML = '';
	dojo.byId('submitcont').value = '';
}

function confirmDeleteSiteMaintenance(cont) {
	document.body.style.cursor = 'wait';
	RPCwrapper({continuation: cont}, confirmDeleteSiteMaintenanceCB, 1);
}

function confirmDeleteSiteMaintenanceCB(data, ioArgs) {
	dojo.byId('start').innerHTML = data.items.start;
	dojo.byId('end').innerHTML = data.items.end;
	dojo.byId('owner').innerHTML = data.items.owner;
	dojo.byId('created').innerHTML = data.items.created;
	dojo.byId('informhoursahead').innerHTML = data.items.hoursahead;
	dojo.byId('delallowreservations').innerHTML = data.items.allowreservations;
	dojo.byId('delreason').innerHTML = data.items.reason;
	dojo.byId('delusermessage').innerHTML = data.items.usermessage;
	dojo.byId('delsubmitcont').value = data.items.cont;

	dijit.byId('confirmDialog').show();
	document.body.style.cursor = 'default';
}

function deleteSiteMaintenance() {
	var cont = dojo.byId('delsubmitcont').value;
	document.body.style.cursor = 'wait';
	RPCwrapper({continuation: cont}, generalReqCB);
}
