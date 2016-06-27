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

function Schedule() {
	Resource.apply(this, Array.prototype.slice.call(arguments));
	this.restype = 'schedule';
}
Schedule.prototype = new Resource();

var resource = new Schedule();

var scheduleTimeData = {
	identifier: 'id',
	items: []
}

function addNewResource(title) {
	dijit.byId('addeditdlg').set('title', title);
	dijit.byId('addeditbtn').set('label', title);
	dojo.byId('editresid').value = 0;
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

		if(! scheduleStore.nextid)
			scheduleStore.nextid = 0;
		var times = data.items.data.times;
		for(var i = 0; i < times.length; i++) {
			var id = ++scheduleStore.nextid;
			var btn = new dijit.form.Button({
				label: "Remove",
				onClick: createRemoveFunc(removeTime, id)
			});
			var sday = new Date(0);
			var day = Math.floor(times[i].start / 1440);
			var minutes = Math.floor(times[i].start - (day * 1440));
			sday.setFullYear(2000);
			sday.setMonth(9);
			sday.setDate(day + 1);
			sday.setHours(Math.floor(minutes / 60));
			sday.setMinutes(minutes % 60);
			var eday = new Date(0);
			day = Math.floor(times[i].end / 1440);
			minutes = Math.floor(times[i].end - (day * 1440));
			eday.setFullYear(2000);
			eday.setMonth(9);
			eday.setDate(day + 1);
			eday.setHours(Math.floor(minutes / 60));
			eday.setMinutes(minutes % 60);
			scheduleStore.newItem({id: id, startday: sday, endday: eday, remove: btn});
		}
		setTimeout(function() {scheduleGrid.sort();}, 10);

		dijit.byId('addeditdlg').show();
	}
	else if(data.items.status == 'noaccess') {
		alert('Access denied to edit this item');
	}
}

function addEditDlgHide() {
	dijit.byId('addeditdlg').hide();
	dijit.byId('name').reset();
	dijit.byId('owner').reset();
	dojo.byId('addeditdlgerrmsg').innerHTML = '';
	dijit.byId('startday').reset();
	dijit.byId('starttime').reset();
	dijit.byId('endday').reset();
	dijit.byId('endtime').reset();
	scheduleStore.fetch({
		query: {id: '*'},
		onItem: function(item) {
			scheduleStore.deleteItem(item);
		}
	});
	var newstore = new dojo.data.ItemFileWriteStore({
		data: {
			identifier: 'id',
		 	items: []
		}
	});
	var oldstore = scheduleStore;
	scheduleStore = newstore;
	scheduleGrid.setStore(scheduleStore);
	if(scheduleStore.nextid)
		scheduleStore.nextid = 0;
}

function saveResource() {
	var submitbtn = dijit.byId('addeditbtn');
	var errobj = dojo.byId('addeditdlgerrmsg');
	if(! checkValidatedObj('name', errobj))
		return;
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

	var times = new Array();
	var items = scheduleStore._arrayOfAllItems;
	for(var i = 0; i < items.length; i++) {
		if(items[i] == null)
			continue;
		var start = minuteInWeek(items[i].startday[0]);
		var end = minuteInWeek(items[i].endday[0]);
		times.push(dojox.string.sprintf('%d:%d', start, end));
	}
	if(times.length == 0) {
		dojo.byId('addeditdlgerrmsg').innerHTML = "You must have at least one entry for the schedule's times.";
		return;
	}

	if(dojo.byId('editresid').value == 0)
		var data = {continuation: dojo.byId('addresourcecont').value};
	else
		var data = {continuation: dojo.byId('saveresourcecont').value};

	data['name'] = dijit.byId('name').get('value');
	data['owner'] = dijit.byId('owner').get('value');
	data['times'] = times.join(',');

	submitbtn.set('disabled', true);
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
					resourcegrid.store.setValue(item, 'name', data.items.data.name);
					resourcegrid.store.setValue(item, 'owner', data.items.data.owner);
				},
				onComplete: function(items, result) {
					// when call resourcegrid.sort directly, the table contents disappear; not sure why
					setTimeout(function() {resourcegrid.sort();}, 10);
				}
			});
		}
		addEditDlgHide();
		setTimeout(function() {dijit.byId('addeditbtn').set('disabled', false);}, 250);
	}
}

function addTime() {
	if(! checkValidatedObj('starttime'))
		return;
	if(! checkValidatedObj('endtime'))
		return;
	var endday = parseInt(dijit.byId('endday').value);
	var endtimeobj = dijit.byId('endtime').value;
	if(dijit.byId('startday').value != 0 &&
	   endday == 0 &&
	   (endtimeobj.getHours() != 0 ||
	   endtimeobj.getMinutes() != 0)) {
		alert("If the start day is not Sunday, the end day cannot\nbe Sunday with a time later than 12:00 AM.");
		return;
	}
	var sday = new Date(0);
	sday.setFullYear(2000);
	sday.setMonth(9);
	sday.setDate(parseInt(dijit.byId('startday').value) + 1);
	sday.setHours(dijit.byId('starttime').value.getHours());
	sday.setMinutes(dijit.byId('starttime').value.getMinutes());
	var eday = new Date(0);
	eday.setFullYear(2000);
	eday.setMonth(9);
	if(endday == 0 && 
	   endtimeobj.getHours() == 0 &&
		endtimeobj.getMinutes() == 0) {
		eday.setDate(endday + 8);
		eday.setHours(endtimeobj.getHours());
		eday.setMinutes(endtimeobj.getMinutes());
	}
	else {
		eday.setDate(endday + 1);
		eday.setHours(endtimeobj.getHours());
		eday.setMinutes(endtimeobj.getMinutes());
	}

	if(eday < sday) {
		alert('The ending day/time cannot be earlier than the starting day/time');
		return;
	}

	var items = scheduleStore._arrayOfAllItems;
	for(var i = 0; i < items.length; i++) {
		if(items[i] == null)
			continue;
		if(sday < items[i].endday[0] && eday > items[i].startday[0]) {
			alert("The submitted days/times overlap with\nan existing set of days/times.");
			return;
		}
	}

	if(! scheduleStore.nextid)
		scheduleStore.nextid = 0;
	var id = ++scheduleStore.nextid;
	var btn = new dijit.form.Button({
		label: "Remove",
		onClick: createRemoveFunc(removeTime, id)
	});
	scheduleStore.newItem({id: id, startday: sday, endday: eday, remove: btn});
	scheduleGrid.sort();
}

function createRemoveFunc(func, id) {
	return function() {func(id);}
}

function removeTime(id) {
	scheduleStore.fetch({
		query: {id: id},
	   onItem: function(item) {
			scheduleStore.deleteItem(item);
		}
	});
}

function formatDay(val) {
	return getDay(val.getDay());
}

function formatTime(val) {
	return getTime(val);
}

function getDay(day) {
	var days = new Array('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
	return days[day];
}

function getTime(obj) {
	var hour = obj.getHours();
	var min = obj.getMinutes();
	var tz = dojo.byId('timezonevalue').value;
	if(hour == 12)
		return dojox.string.sprintf('12:%02d PM %s', min, tz);
	if(hour == 0)
		return dojox.string.sprintf('12:%02d AM %s', min, tz);
	if(parseInt(hour / 12))
		return dojox.string.sprintf('%d:%02d PM %s', hour % 12, min, tz);
	return dojox.string.sprintf('%d:%02d AM %s', hour, min, tz);
}

function minuteInWeek(val) {
	var min = val.getMinutes();
	min += val.getHours() * 60;
	min += (val.getDate() - 1) * 1440;
	return min;
}
