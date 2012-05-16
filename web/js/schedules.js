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
var scheduleTimeData = {
	identifier: 'id',
	items: []
}

function RPCwrapper(data, CB, dojson) {
	if(dojson) {
		dojo.xhrPost({
			url: 'index.php',
			load: CB,
			handleAs: "json",
			error: errorHandler,
			content: data,
			timeout: 15000
		});
	}
	else {
		dojo.xhrPost({
			url: 'index.php',
			load: CB,
			error: errorHandler,
			content: data,
			timeout: 15000
		});
	}
}

function generalReqCB(data, ioArgs) {
	eval(data);
	document.body.style.cursor = 'default';
}

function populateTimeStore(cont) {
	RPCwrapper({continuation: cont}, populateTimeStoreCB, 1);
}

function populateTimeStoreCB(data, ioArgs) {
	if(data.items.error) {
		alert(data.items.error);
		return;
	}
	var store = scheduleStore;
	if(! store.nextid)
		store.nextid = 0;
	for(var i = 0; i < data.items.length; i++) {
		var id = store.nextid + 1;
		store.nextid = id;
		var sday = new Date(0);
		sday.setFullYear(2000);
		sday.setMonth(9);
		sday.setDate(data.items[i].sday + 1);
		sday.setHours(Math.floor(data.items[i].smin / 60));
		sday.setMinutes(data.items[i].smin % 60);
		var eday = new Date(0);
		eday.setFullYear(2000);
		eday.setMonth(9);
		if(data.items[i].eday == 0 && 
		   data.items[i].emin == 0) {
			eday.setDate(data.items[i].eday + 8);
			eday.setHours(Math.floor(data.items[i].emin / 60));
			eday.setMinutes(data.items[i].emin % 60);
		}
		else {
			eday.setDate(data.items[i].eday + 1);
			eday.setHours(Math.floor(data.items[i].emin / 60));
			eday.setMinutes(data.items[i].emin % 60);
		}
		var btn = new dijit.form.Button({
			label: "Remove",
			onClick: createRemoveFunc(removeTime, id)
		});
		store.newItem({id: id, startday: sday, endday: eday, remove: btn});
	}
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

function addTime() {
	var endday = parseInt(dojo.byId('endday').value);
	var endtimeobj = dijit.byId('endtime').value;
	if(dojo.byId('startday').value != 0 &&
	   endday == 0 &&
	   (endtimeobj.getHours() != 0 ||
	   endtimeobj.getMinutes() != 0)) {
		alert("If the start day is not Sunday, the end day cannot\nbe Sunday with a time later than 12:00 AM.");
		return;
	}
	var sday = new Date(0);
	sday.setFullYear(2000);
	sday.setMonth(9);
	sday.setDate(parseInt(dojo.byId('startday').value) + 1);
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
	if(hour == 12)
		return dojox.string.sprintf('12:%02d PM', min);
	if(hour == 0)
		return dojox.string.sprintf('12:%02d AM', min);
	if(parseInt(hour / 12))
		return dojox.string.sprintf('%d:%02d PM', hour % 12, min);
	return dojox.string.sprintf('%d:%02d AM', hour, min);
}

function saveTimes(cont) {
	var times = new Array();
	var items = scheduleStore._arrayOfAllItems;
	for(var i = 0; i < items.length; i++) {
		if(items[i] == null)
			continue;
		var start = minuteInWeek(items[i].startday[0]);
		var end = minuteInWeek(items[i].endday[0]);
		times.push(dojox.string.sprintf('%d:%d', start, end));
	}
	var data = {continuation: cont,
	            times: times.join(',')};
	dijit.byId('saveTimesBtn').attr('disabled', true);
	document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function minuteInWeek(val) {
	var min = val.getMinutes();
	min += val.getHours() * 60;
	min += (val.getDate() - 1) * 1440;
	return min;
}
