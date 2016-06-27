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
var timeout = null;
var ownervalid = true;

var blockFormAddWeeklyData = {
	identifier: 'id',
	items: []
}

var blockFormAddMonthlyData = {
	identifier: 'id',
	items: []
}

var blockFormAddListData = {
	identifier: 'id',
	items: []
}

var usagechart = null;

function generalReqCB(data, ioArgs) {
	eval(data);
	document.body.style.cursor = 'default';
}

function populateBlockStore(cont) {
	RPCwrapper({continuation: cont}, populateBlockStoreCB, 1);
}

function populateBlockStoreCB(data, ioArgs) {
	if(data.items.error) {
		alert(data.items.error);
		return;
	}
	if(data.items.type == 'weekly' || data.items.type == 'monthly') {
		if(data.items.type == 'weekly') {
			var store = requestBlockAddWeeklyStore;
			var grid = requestBlockAddWeeklyGrid;
			var rmfunc = blockFormRemoveWeeklyTime;
		}
		else {
			var store = requestBlockAddMonthlyStore;
			var grid = requestBlockAddMonthlyGrid;
			var rmfunc = blockFormRemoveMonthlyTime;
		}
		if(! store.nextid)
			store.nextid = 0;
		for(var i = 0; i < data.items.starths.length; i++) {
			var id = store.nextid + 1;
			store.nextid = id;
			var start = dojox.string.sprintf('%02d%02d%02d%02d',
			            data.items.starths[i],
			            data.items.startms[i],
			            data.items.endhs[i],
			            data.items.endms[i]);
			var start2 = new Date(0);
			start2.setHours(data.items.starths[i]);
			start2.setMinutes(data.items.startms[i]);
			var end = new Date(0);
			end.setHours(data.items.endhs[i]);
			end.setMinutes(data.items.endms[i]);
			var btn = new dijit.form.Button({
				label: _("Remove"),
				onClick: createRemoveFunc(rmfunc, id)
			});
			store.newItem({id: id, start: start, start2: start2, end: end, remove: btn});
		}
		grid.sort();
	}
	else if(data.items.type == 'list') {
		var store = requestBlockAddListStore;
		var grid = requestBlockAddListGrid;
		if(! store.nextid)
			store.nextid = 0;
		for(var i = 0; i < data.items.starths.length; i++) {
			var id = store.nextid + 1;
			store.nextid = id;
			var date1 = dojox.string.sprintf('%d%02d%02d%02d%02d%02d%02d',
			            data.items.years[i],
			            data.items.months[i],
			            data.items.days[i],
			            data.items.starths[i],
			            data.items.startms[i],
			            data.items.endhs[i],
			            data.items.endms[i]);

			var date2 = new Date(0);
			date2.setDate(data.items.days[i]);
			date2.setFullYear(data.items.years[i]);
			date2.setMonth(data.items.months[i] - 1);
			var start = new Date(0);
			start.setHours(data.items.starths[i]);
			start.setMinutes(data.items.startms[i]);
			var end = new Date(0);
			end.setHours(data.items.endhs[i]);
			end.setMinutes(data.items.endms[i]);
			var btn = new dijit.form.Button({
				label: _("Remove"),
				onClick: createRemoveFunc(blockFormRemoveListSlot, id)
			});
			store.newItem({id: id, date1: date1, date2: date2, start: start, end: end, remove: btn});
		}
		grid.sort();
	}
}

function createRemoveFunc(func, id) {
	return function() {func(id);}
}

function updateBlockStatus() {
	var data = {continuation: dojo.byId('updatecont').value};
	RPCwrapper(data, updateBlockStatusCB, 1);
}

function updateBlockStatusCB(data, ioArgs) {
	if(data.items.status && data.items.status == 'gone') {
		dojo.byId('statusdiv').innerHTML = _('The selected Block Request no longer exists.');
		return;
	}
	dojo.byId('available').innerHTML = data.items.available;
	dojo.byId('reloading').innerHTML = data.items.reloading;
	dojo.byId('used').innerHTML = data.items.used;
	dojo.byId('failed').innerHTML = data.items.failed;
	setTimeout(updateBlockStatus, 30000);
}

function blockFormChangeTab(tab) {
	if(tab == 'list')
		dijit.byId('timeTypeContainer').selectChild(dijit.byId('listtab'));
	else if(tab == 'weekly')
		dijit.byId('timeTypeContainer').selectChild(dijit.byId('weeklytab'));
	else if(tab == 'monthly')
		dijit.byId('timeTypeContainer').selectChild(dijit.byId('monthlytab'));
}

function blockFormWeeklyAddBtnCheck(isstart) {
	var startobj = dijit.byId('weeklyaddstart');
	var endobj = dijit.byId('weeklyaddend');
	if(isstart)
		endobj.validate();
	if(startobj.isValid() && endobj.isValid())
		dijit.byId('requestBlockWeeklyAddBtn').attr('disabled', false);
	else
		dijit.byId('requestBlockWeeklyAddBtn').attr('disabled', true);
}

function blockFormMonthlyAddBtnCheck(isstart) {
	var startobj = dijit.byId('monthlyaddstart');
	var endobj = dijit.byId('monthlyaddend');
	if(isstart)
		endobj.validate();
	if(startobj.isValid() && endobj.isValid())
		dijit.byId('requestBlockMonthlyAddBtn').attr('disabled', false);
	else
		dijit.byId('requestBlockMonthlyAddBtn').attr('disabled', true);
}

function blockFormListAddBtnCheck() {
	var dateobj = dijit.byId('listadddate');
	var startobj = dijit.byId('listaddstart');
	var endobj = dijit.byId('listaddend');
	if(dateobj.isValid() && startobj.isValid() && endobj.isValid())
		dijit.byId('requestBlockListAddBtn').attr('disabled', false);
	else
		dijit.byId('requestBlockListAddBtn').attr('disabled', true);
}

function blockFormAddWeeklyTime() {
	var startobj = dijit.byId('weeklyaddstart');
	var endobj = dijit.byId('weeklyaddend');
	if(! startobj.isValid() || ! endobj.isValid())
		return;

	var s = startobj.value;
	var end = endobj.value;
	var start = dojox.string.sprintf('%02d%02d%02d%02d',
	            s.getHours(),
	            s.getMinutes(),
	            end.getHours(),
	            end.getMinutes());

	var tmp = s;
	tmp.setFullYear(2000, 0, 1);
	var startts = tmp.getTime();
	tmp = end;
	tmp.setFullYear(2000, 0, 1);
	var endts = tmp.getTime();
	var items = requestBlockAddWeeklyStore._getItemsArray();
	var len = items.length;
	for(var i = 0; i < len; i++) {
		var testend = items[i].end[0];
		testend.setFullYear(2000, 0, 1);
		testend = testend.getTime();
		var teststart = items[i].start2[0];
		teststart.setFullYear(2000, 0, 1);
		teststart = teststart.getTime();
		if(startts < testend &&
		   endts > teststart) {
			alert(_('These times overlap with an existing time slot'));
			return;
		}
	}

	if(! requestBlockAddWeeklyStore.nextid)
		requestBlockAddWeeklyStore.nextid = 0;
	var id = requestBlockAddWeeklyStore.nextid + 1;
	requestBlockAddWeeklyStore.nextid = id;

	var btn = new dijit.form.Button({
		label: _("Remove"),
		onClick: function() {blockFormRemoveWeeklyTime(id);}
	});
	requestBlockAddWeeklyStore.newItem({id: id, start: start, start2: s, end: end, remove: btn});
	requestBlockAddWeeklyGrid.sort();
}

function blockFormAddMonthlyTime() {
	var startobj = dijit.byId('monthlyaddstart');
	var endobj = dijit.byId('monthlyaddend');
	if(! startobj.isValid() || ! endobj.isValid())
		return;

	var s = startobj.value;
	var end = endobj.value;
	var start = dojox.string.sprintf('%02d%02d%02d%02d',
	            s.getHours(),
	            s.getMinutes(),
	            end.getHours(),
	            end.getMinutes());

	var startts = s.getTime();
	var endts = end.getTime();
	var items = requestBlockAddMonthlyStore._getItemsArray();
	var len = items.length;
	for(var i = 0; i < len; i++) {
		if(startts < items[i].end[0].getTime() &&
		   endts > items[i].start2[0].getTime()) {
			alert(_('These times overlap with an existing time slot'));
			return;
		}
	}

	if(! requestBlockAddMonthlyStore.nextid)
		requestBlockAddMonthlyStore.nextid = 0;
	var id = requestBlockAddMonthlyStore.nextid + 1;
	requestBlockAddMonthlyStore.nextid = id;

	var btn = new dijit.form.Button({
		label: _("Remove"),
		onClick: function() {blockFormRemoveMonthlyTime(id);}
	});
	requestBlockAddMonthlyStore.newItem({id: id, start: start, start2: s, end: end, remove: btn});
	requestBlockAddMonthlyGrid.sort();
}

function blockFormAddListSlot() {
	var dateobj = dijit.byId('listadddate');
	var startobj = dijit.byId('listaddstart');
	var endobj = dijit.byId('listaddend');
	if(! dateobj.isValid() || ! startobj.isValid() || ! endobj.isValid())
		return;
	var today = new Date(dojo.byId('nowtimestamp').value * 1000);
	today.setHours(0);
	today.setMinutes(0);
	today.setSeconds(0);
	today.setMilliseconds(0);
	if(dateobj.value < today) {
		alert(_('The date must be today or later'));
		return;
	}

	var d = dateobj.value;
	var start = startobj.value;
	var end = endobj.value;

	var date1 = dojox.string.sprintf('%d%02d%02d%02d%02d%02d%02d',
	            d.getFullYear(),
	            (d.getMonth() + 1),
	            d.getDate(),
	            start.getHours(),
	            start.getMinutes(),
	            end.getHours(),
	            end.getMinutes());

	var startts = d.getTime() + start.getTime();
	var endts = d.getTime() + end.getTime();
	var items = requestBlockAddListStore._getItemsArray();
	var len = items.length;
	for(var i = 0; i < len; i++) {
		var checkstart = items[i].date2[0].getTime() + items[i].start[0].getTime();
		var checkend = items[i].date2[0].getTime() + items[i].end[0].getTime();
		if(startts < checkend &&
		   endts > checkstart) {
			alert(_('The date and times overlap with an existing time slot'));
			return;
		}
	}

	if(! requestBlockAddListStore.nextid)
		requestBlockAddListStore.nextid = 0;
	var id = requestBlockAddListStore.nextid + 1;
	requestBlockAddListStore.nextid = id;

	var btn = new dijit.form.Button({
		label: _("Remove"),
		onClick: function() {blockFormRemoveListSlot(id);}
	});
	requestBlockAddListStore.newItem({id: id, date1: date1, date2: d, start: start, end: end, remove: btn});
	requestBlockAddListGrid.sort();
}

function blockFormRemoveWeeklyTime(id) {
	requestBlockAddWeeklyStore.fetch({
		query: {id: id},
	   onItem: function(item) {
			requestBlockAddWeeklyStore.deleteItem(item);
		}
	});
}

function blockFormRemoveMonthlyTime(id) {
	requestBlockAddMonthlyStore.fetch({
		query: {id: id},
	   onItem: function(item) {
			requestBlockAddMonthlyStore.deleteItem(item);
		}
	});
}

function blockFormRemoveListSlot(id) {
	requestBlockAddListStore.fetch({
		query: {id: id},
	   onItem: function(item) {
			requestBlockAddListStore.deleteItem(item);
		}
	});
}

function blockFormConfirm(mode) {
	if(! dijit.byId('machinecnt').isValid() ||
	   (dijit.byId('imagesel') && ! dijit.byId('imagesel').isValid()) ||
	   (dijit.byId('groupsel') && ! dijit.byId('groupsel').isValid()) ||
		(dijit.byId('brname') && ! dijit.byId('brname').isValid()) ||
		(dijit.byId('browner') && ! dijit.byId('browner').isValid())) {
		alert(_('Please fix invalid values before submitting.'));
		return;
	}
	var weekly = dojo.byId('weeklyradio');
	var monthly = dojo.byId('monthlyradio');
	var list = dojo.byId('listradio');
	if(weekly.checked)
		blockFormVerifyWeekly(mode);
	else if(monthly.checked)
		blockFormVerifyMonthly(mode);
	else if(list.checked)
		blockFormVerifyList(mode);
}

function blockFormSubmit(mode) {
	var weekly = dojo.byId('weeklyradio');
	var monthly = dojo.byId('monthlyradio');
	var list = dojo.byId('listradio');
	if(weekly.checked)
		blockFormSubmitWeekly(mode);
	else if(monthly.checked)
		blockFormSubmitMonthly(mode);
	else if(list.checked)
		blockFormSubmitList(mode);
}

function blockFormVerifyWeekly(mode) {
	if(! dijit.byId('wkfirstdate').isValid()) {
		dijit.byId('wkfirstdate')._hasBeenBlurred = true;
		dijit.byId('wkfirstdate').validate();
		alert(_('Please fill in First Date of Usage'));
		return;
	}
	if(! dijit.byId('wklastdate').isValid()) {
		dijit.byId('wklastdate')._hasBeenBlurred = true;
		dijit.byId('wklastdate').validate();
		alert(_('Please fill in Last Date of Usage'));
		return;
	}
	var today = new Date();
	today.setHours(0);
	today.setMinutes(0);
	today.setSeconds(0);
	today.setMilliseconds(0);
	if(pagemode != 'edit' && dijit.byId('wkfirstdate').value < today) {
		alert(_('The First Date of Usage must be today or later'));
		return;
	}
	if(pagemode != 'edit' && dijit.byId('wklastdate').value < dijit.byId('wkfirstdate').value) {
		alert(_('The Last Date of Usage must be the same or later than the First Date of Usage'));
		return;
	}
	if(pagemode == 'edit' && dijit.byId('wklastdate').value < today) {
		alert(_('The Last Date of Usage must be today or later'));
		return;
	}
	var days = new Array();
	if(dojo.byId('wdays0').checked)
		days.push(_('Sunday'));
	if(dojo.byId('wdays1').checked)
		days.push(_('Monday'));
	if(dojo.byId('wdays2').checked)
		days.push(_('Tuesday'));
	if(dojo.byId('wdays3').checked)
		days.push(_('Wednesday'));
	if(dojo.byId('wdays4').checked)
		days.push(_('Thursday'));
	if(dojo.byId('wdays5').checked)
		days.push(_('Friday'));
	if(dojo.byId('wdays6').checked)
		days.push(_('Saturday'));
	if(days.length == 0) {
		alert(_('At least one day must be checked when using "Repeating Weekly"'));
		return;
	}
	var len = requestBlockAddWeeklyStore._getItemsArray().length;
	if(len == 0) {
		alert(_('At least one start/end combination must be entered when using "Repeating Weekly"'));
		return;
	}
	if(dijit.byId('groupsel'))
		var groupselobj = dijit.byId('groupsel');
	else
		var groupselobj = dojo.byId('groupsel');
	if(mode == 'request' && groupselobj.value == 0 &&
	   dijit.byId('comments').value.length == 0) {
		alert(_('When submitting "(group not listed)" as the user group, information must be included in the comments about what group needs to be created.'));
		return;
	}
	if(mode != 'request') {
		dojo.byId('confnametitle').innerHTML = _('Name:');
		dojo.byId('confname').innerHTML = dijit.byId('brname').textbox.value;
		dojo.byId('confownertitle').innerHTML = _('Owner:');
		dojo.byId('confowner').innerHTML = dijit.byId('browner').textbox.value;
	}
	dojo.byId('confimage').innerHTML = getSelectText('imagesel');
	dojo.byId('confseats').innerHTML = dijit.byId('machinecnt').value;
	if(groupselobj.value == 0)
		dojo.byId('confgroup').innerHTML = _('specified in comments');
	else
		dojo.byId('confgroup').innerHTML = getSelectText('groupsel');
	dojo.byId('confrepeat').innerHTML = _('Weekly');
	dojo.byId('conftitle1').innerHTML = _('First Date:');
	dojo.byId('confvalue1').innerHTML = dijit.byId('wkfirstdate').getDisplayedValue();
	dojo.byId('conftitle2').innerHTML = _('Last Date:');
	dojo.byId('confvalue2').innerHTML = dijit.byId('wklastdate').getDisplayedValue();
	dojo.byId('conftitle3').innerHTML = _('Repeating on these days:');
	dojo.byId('confvalue3').innerHTML = days.join('<br>');
	var times = new Array();
	var items = requestBlockAddWeeklyStore._getItemsArray();
	for(var i = 0; i < len; i++) {
		var item = new Object();
		item.key = items[i].start[0];
		item.val = timeFromTextBox(items[i].start2[0]) + ' - ' + timeFromTextBox(items[i].end[0]);
		times.push(item);
	}
	times.sort(sortTimeArray);
	var times2 = new Array();
	for(i = 0; i < len; i++)
		times2.push(times[i].val);
	dojo.byId('conftitle4').innerHTML = _('During these times:');
	dojo.byId('confvalue4').innerHTML = times2.join('<br>');
	if(dijit.byId('comments') && dijit.byId('comments').value.length)
		dojo.removeClass('commentsnote', 'hidden');
	dijit.byId('confirmDialog').show();
}

function blockFormSubmitWeekly(mode) {
	var days = new Array();
	if(dojo.byId('wdays0').checked)
		days.push(0);
	if(dojo.byId('wdays1').checked)
		days.push(1);
	if(dojo.byId('wdays2').checked)
		days.push(2);
	if(dojo.byId('wdays3').checked)
		days.push(3);
	if(dojo.byId('wdays4').checked)
		days.push(4);
	if(dojo.byId('wdays5').checked)
		days.push(5);
	if(dojo.byId('wdays6').checked)
		days.push(6);
	var times = new Array();
	var items = requestBlockAddWeeklyStore._getItemsArray();
	var len = items.length;
	var a = '';
	for(var i = 0; i < len; i++) {
		a = dojox.string.sprintf('%02d:%02d|%02d:%02d',
		                         items[i].start2[0].getHours(),
		                         items[i].start2[0].getMinutes(),
		                         items[i].end[0].getHours(),
		                         items[i].end[0].getMinutes());
		times.push(a);
	}
	var alltimes = times.join(',');
	var imageid = getSelectValue('imagesel');
	var seats = dijit.byId('machinecnt').value;
	var groupid = getSelectValue('groupsel');
	var obj = dijit.byId('wkfirstdate').value;
	var startdate = dojox.string.sprintf('%d%02d%02d',
	                obj.getFullYear(),
	                (obj.getMonth() + 1),
	                obj.getDate());
	obj = dijit.byId('wklastdate').value;
	var enddate = dojox.string.sprintf('%d%02d%02d',
	              obj.getFullYear(),
	              (obj.getMonth() + 1),
	              obj.getDate());
	var days2 = days.join(',');
	var data = {continuation: dojo.byId('submitcont').value,
	            imageid: imageid,
	            seats: seats,
	            groupid: groupid,
	            type: 'weekly',
	            startdate: startdate,
	            enddate: enddate,
	            times: alltimes,
	            days: days2};
	if(dojo.byId('submitcont2').value != '')
		data.continuation = dojo.byId('submitcont2').value;
	if(mode != 'request') {
		data.name = dijit.byId('brname').value;
		data.owner = dijit.byId('browner').value;
	}
	else
		data.comments = dijit.byId('comments').value;
	document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function blockFormVerifyMonthly(mode) {
	if(! dijit.byId('mnfirstdate').isValid()) {
		dijit.byId('mnfirstdate')._hasBeenBlurred = true;
		dijit.byId('mnfirstdate').validate();
		alert(_('Please fill in First Date of Usage'));
		return;
	}
	if(! dijit.byId('mnlastdate').isValid()) {
		dijit.byId('mnlastdate')._hasBeenBlurred = true;
		dijit.byId('mnlastdate').validate();
		alert(_('Please fill in Last Date of Usage'));
		return;
	}
	var today = new Date();
	today.setHours(0);
	today.setMinutes(0);
	today.setSeconds(0);
	today.setMilliseconds(0);
	if(pagemode != 'edit' && dijit.byId('mnfirstdate').value < today) {
		alert(_('The First Date of Usage must be today or later'));
		return;
	}
	if(pagemode != 'edit' && dijit.byId('mnlastdate').value < dijit.byId('mnfirstdate').value) {
		alert(_('The Last Date of Usage must be the same or later than the First Date of Usage'));
		return;
	}
	if(pagemode == 'edit' && dijit.byId('mnlastdate').value < today) {
		alert(_('The Last Date of Usage must be today or later'));
		return;
	}
	var len = requestBlockAddMonthlyStore._getItemsArray().length;
	if(len == 0) {
		alert(_('At least one start/end combination must be entered when using "Repeating Monthly"'));
		return;
	}
	if(dijit.byId('groupsel'))
		var groupselobj = dijit.byId('groupsel');
	else
		var groupselobj = dojo.byId('groupsel');
	if(mode == 'request' && groupselobj.value == 0 &&
	   dijit.byId('comments').value.length == 0) {
		alert(_('When submitting "(group not listed)" as the user group, information must be included in the comments about what group needs to be created.'));
		return;
	}
	if(mode != 'request') {
		dojo.byId('confnametitle').innerHTML = _('Name:');
		dojo.byId('confname').innerHTML = dijit.byId('brname').textbox.value;
		dojo.byId('confownertitle').innerHTML = _('Owner:');
		dojo.byId('confowner').innerHTML = dijit.byId('browner').textbox.value;
	}
	dojo.byId('confimage').innerHTML = getSelectText('imagesel');
	dojo.byId('confseats').innerHTML = dijit.byId('machinecnt').value;
	if(groupselobj.value == 0)
		dojo.byId('confgroup').innerHTML = _('specified in comments');
	else
		dojo.byId('confgroup').innerHTML = getSelectText('groupsel');
	dojo.byId('confrepeat').innerHTML = _('Monthly');
	dojo.byId('conftitle1').innerHTML = _('First Date:');
	dojo.byId('confvalue1').innerHTML = dijit.byId('mnfirstdate').getDisplayedValue();
	dojo.byId('conftitle2').innerHTML = _('Last Date:');
	dojo.byId('confvalue2').innerHTML = dijit.byId('mnlastdate').getDisplayedValue();
	dojo.byId('conftitle3').innerHTML = _('Repeat on:');
	var obj = dojo.byId('mnweeknum');
	var date1 = obj.options[obj.selectedIndex].text;
	obj = dojo.byId('mnday');
	date1 += " " + obj.options[obj.selectedIndex].text;
	dojo.byId('confvalue3').innerHTML = date1 + ' ' + _("of each month");
	var times = new Array();
	var items = requestBlockAddMonthlyStore._getItemsArray();
	for(var i = 0; i < len; i++) {
		var item = new Object();
		item.key = items[i].start[0];
		item.val = timeFromTextBox(items[i].start2[0]) + ' - ' + timeFromTextBox(items[i].end[0]);
		times.push(item);
	}
	times.sort(sortTimeArray);
	var times2 = new Array();
	for(i = 0; i < len; i++)
		times2.push(times[i].val);
	dojo.byId('conftitle4').innerHTML = _('During these times:');
	dojo.byId('confvalue4').innerHTML = times2.join('<br>');
	if(dijit.byId('comments') && dijit.byId('comments').value.length)
		dojo.removeClass('commentsnote', 'hidden');
	dijit.byId('confirmDialog').show();
}

function blockFormSubmitMonthly(mode) {
	var obj = dojo.byId('mnweeknum');
	var weeknum = obj.options[obj.selectedIndex].value;
	obj = dojo.byId('mnday');
	var day = obj.options[obj.selectedIndex].value;
	var times = new Array();
	var items = requestBlockAddMonthlyStore._getItemsArray();
	var len = items.length;
	var a = '';
	var b = '';
	for(var i = 0; i < len; i++) {
		a = items[i].start2[0].getHours() + ':' + items[i].start2[0].getMinutes();
		b = items[i].end[0].getHours() + ':' + items[i].end[0].getMinutes();
		times.push(a + '|' + b);
	}
	var alltimes = times.join(',');
	var imageid = getSelectValue('imagesel');
	var seats = dijit.byId('machinecnt').value;
	var groupid = getSelectValue('groupsel');
	var obj = dijit.byId('mnfirstdate').value;
	var startdate = dojox.string.sprintf('%d%02d%02d',
	                obj.getFullYear(),
	                (obj.getMonth() + 1),
	                obj.getDate());
	obj = dijit.byId('mnlastdate').value;
	var enddate = dojox.string.sprintf('%d%02d%02d',
	              obj.getFullYear(),
	              (obj.getMonth() + 1),
	              obj.getDate());
	var data = {continuation: dojo.byId('submitcont').value,
	            imageid: imageid,
	            seats: seats,
	            groupid: groupid,
	            type: 'monthly',
	            startdate: startdate,
	            enddate: enddate,
	            weeknum: weeknum,
	            day: day,
	            times: alltimes};
	if(dojo.byId('submitcont2').value != '')
		data.continuation = dojo.byId('submitcont2').value;
	if(mode != 'request') {
		data.name = dijit.byId('brname').value;
		data.owner = dijit.byId('browner').value;
	}
	else
		data.comments = dijit.byId('comments').value;
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function blockFormVerifyList(mode) {
	var len = requestBlockAddListStore._getItemsArray().length;
	if(len == 0) {
		alert(_('At least one date/start/end combination must be entered when using "List of Dates/Times"'));
		return;
	}
	if(dijit.byId('groupsel'))
		var groupselobj = dijit.byId('groupsel');
	else
		var groupselobj = dojo.byId('groupsel');
	if(groupselobj.value == 0 && dijit.byId('comments').value.length == 0) {
		alert(_('When submitting "(group not listed)" as the user group, information must be included in the comments about what group needs to be created.'));
		return;
	}
	if(mode != 'request') {
		dojo.byId('confnametitle').innerHTML = _('Name:');
		dojo.byId('confname').innerHTML = dijit.byId('brname').textbox.value;
		dojo.byId('confownertitle').innerHTML = _('Owner:');
		dojo.byId('confowner').innerHTML = dijit.byId('browner').textbox.value;
	}
	dojo.byId('confimage').innerHTML = getSelectText('imagesel');
	dojo.byId('confseats').innerHTML = dijit.byId('machinecnt').value;
	if(groupselobj.value == 0)
		dojo.byId('confgroup').innerHTML = _('specified in comments');
	else
		dojo.byId('confgroup').innerHTML = getSelectText('groupsel');
	dojo.byId('confrepeat').innerHTML = _('List of Dates/Times');
	dojo.byId('conftitle1').innerHTML = _('Repeat on:');
	var slots = new Array();
	var items = requestBlockAddListStore._getItemsArray();
	var date1 = '';
	var start = '';
	var end = '';
	for(var i = 0; i < len; i++) {
		var item = new Object();
		date1 = gridDateTimePrimary(items[i].date1[0]);
		start = timeFromTextBox(items[i].start[0]);
		end = timeFromTextBox(items[i].end[0]);
		item.key = items[i].date1[0];
		item.value = date1 + ' ' + start + ' - ' + end;
		slots.push(item);
	}
	slots.sort(sortTimeArray);
	var slots2 = new Array();
	for(i = 0; i < len; i++)
		slots2.push(slots[i].value);
	dojo.byId('confvalue1').innerHTML = slots2.join('<br>');
	if(dijit.byId('comments') && dijit.byId('comments').value.length)
		dojo.removeClass('commentsnote', 'hidden');
	dijit.byId('confirmDialog').show();
}

function blockFormSubmitList(mode) {
	var slots = new Array();
	var items = requestBlockAddListStore._getItemsArray();
	var date1 = '';
	var start = '';
	var end = '';
	var len = items.length;
	for(var i = 0; i < len; i++) {
		date1 = items[i].date1[0].substr(0, 8);
		start = items[i].date1[0].substr(8, 2) + ':' + items[i].date1[0].substr(10, 2);
		end = items[i].date1[0].substr(12, 2) + ':' + items[i].date1[0].substr(14, 2);
		slots.push(date1 + '|' + start + '|' + end);
	}
	var allslots = slots.join(',');
	var imageid = getSelectValue('imagesel');
	var seats = dijit.byId('machinecnt').value;
	var groupid = getSelectValue('groupsel');
	var data = {continuation: dojo.byId('submitcont').value,
	            imageid: imageid,
	            seats: seats,
	            groupid: groupid,
	            type: 'list',
	            slots: allslots};
	if(dojo.byId('submitcont2').value != '')
		data.continuation = dojo.byId('submitcont2').value;
	if(mode != 'request') {
		data.name = dijit.byId('brname').value;
		data.owner = dijit.byId('browner').value;
	}
	else
		data.comments = dijit.byId('comments').value;
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function clearHideConfirmForm() {
	dijit.byId('confirmDialog').hide();
	dojo.byId('confnametitle').innerHTML = '';
	dojo.byId('confname').innerHTML = '';
	dojo.byId('confowner').innerHTML = '';
	dojo.byId('confimage').innerHTML = '';
	dojo.byId('confseats').innerHTML = '';
	dojo.byId('confgroup').innerHTML = '';
	dojo.byId('confrepeat').innerHTML = '';
	dojo.byId('conftitle1').innerHTML = '';
	dojo.byId('confvalue1').innerHTML = '';
	dojo.byId('conftitle2').innerHTML = '';
	dojo.byId('confvalue2').innerHTML = '';
	dojo.byId('conftitle3').innerHTML = '';
	dojo.byId('confvalue3').innerHTML = '';
	dojo.byId('conftitle4').innerHTML = '';
	dojo.byId('confvalue4').innerHTML = '';
	dojo.addClass('commentsnote', 'hidden');
}

function clearHideConfirmDelete() {
	dijit.byId('confirmDialog').hide();
	dojo.byId('confname').innerHTML = '';
	dojo.byId('confowner').innerHTML = '';
	dojo.byId('confimage').innerHTML = '';
	dojo.byId('confseats').innerHTML = '';
	dojo.byId('confgroup').innerHTML = '';
	dojo.byId('confrepeat').innerHTML = '';
	dojo.byId('conftitle1').innerHTML = '';
	dojo.byId('confvalue1').innerHTML = '';
	dojo.byId('conftitle2').innerHTML = '';
	dojo.byId('confvalue2').innerHTML = '';
	dojo.byId('conftitle3').innerHTML = '';
	dojo.byId('confvalue3').innerHTML = '';
	dojo.byId('conftitle4').innerHTML = '';
	dojo.byId('confvalue4').innerHTML = '';
}

function clearHideView() {
	dijit.byId('viewDialog').hide();
	dojo.byId('confname').innerHTML = '';
	dojo.byId('confowner').innerHTML = '';
	dojo.byId('confimage').innerHTML = '';
	dojo.byId('confseats').innerHTML = '';
	dojo.byId('confgroup').innerHTML = '';
	dojo.byId('confrepeat').innerHTML = '';
	dojo.byId('conftitle1').innerHTML = '';
	dojo.byId('confvalue1').innerHTML = '';
	dojo.byId('conftitle2').innerHTML = '';
	dojo.byId('confvalue2').innerHTML = '';
	dojo.byId('conftitle3').innerHTML = '';
	dojo.byId('confvalue3').innerHTML = '';
	dojo.byId('conftitle4').innerHTML = '';
	dojo.byId('confvalue4').innerHTML = '';
}

function clearHideConfirmAccept() {
	dijit.byId('acceptDialog').hide();
	dojo.byId('acceptimage').innerHTML = '';
	dojo.byId('acceptseats').innerHTML = '';
	dojo.byId('acceptgroup').innerHTML = '';
	dojo.byId('acceptrepeat').innerHTML = '';
	dojo.byId('accepttitle1').innerHTML = '';
	dojo.byId('acceptvalue1').innerHTML = '';
	dojo.byId('accepttitle2').innerHTML = '';
	dojo.byId('acceptvalue2').innerHTML = '';
	dojo.byId('accepttitle3').innerHTML = '';
	dojo.byId('acceptvalue3').innerHTML = '';
	dojo.byId('accepttitle4').innerHTML = '';
	dojo.byId('acceptvalue4').innerHTML = '';
	dojo.byId('accepttitle5').innerHTML = '';
	dojo.byId('acceptvalue5').innerHTML = '';
	if(dijit.byId('groupsel'))
		dijit.byId('groupsel').attr('displayedValue', dijit.byId('groupsel').focusNode.defaultValue);
	else
		dojo.byId('groupsel').value = 0;
	dojo.byId('brname').value = '';
	dojo.byId('acceptemailuser').innerHTML = '';
	dijit.byId('acceptemailtext').attr('value', '');
}

function clearHideConfirmReject() {
	dijit.byId('rejectDialog').hide();
	dojo.byId('rejectimage').innerHTML = '';
	dojo.byId('rejectseats').innerHTML = '';
	dojo.byId('rejectgroup').innerHTML = '';
	dojo.byId('rejectrepeat').innerHTML = '';
	dojo.byId('rejecttitle1').innerHTML = '';
	dojo.byId('rejectvalue1').innerHTML = '';
	dojo.byId('rejecttitle2').innerHTML = '';
	dojo.byId('rejectvalue2').innerHTML = '';
	dojo.byId('rejecttitle3').innerHTML = '';
	dojo.byId('rejectvalue3').innerHTML = '';
	dojo.byId('rejecttitle4').innerHTML = '';
	dojo.byId('rejectvalue4').innerHTML = '';
	dojo.byId('rejecttitle5').innerHTML = '';
	dojo.byId('rejectvalue5').innerHTML = '';
	dojo.byId('rejectemailuser').innerHTML = '';
	dijit.byId('rejectemailtext').attr('value', '');
}

function deleteBlockConfirm(cont) {
	var data = {continuation: cont};
   document.body.style.cursor = 'wait';
	RPCwrapper(data, deleteBlockConfirmCB, 1);
}

function deleteBlockConfirmCB(data, ioArgs) {
	if(data.items.repeating == 'weekly') {
		dojo.byId('confname').innerHTML = data.items.name;
		dojo.byId('confowner').innerHTML = data.items.owner;
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confrepeat').innerHTML = _('Weekly');
		dojo.byId('conftitle1').innerHTML = _('First Date:');
		dojo.byId('confvalue1').innerHTML = data.items.startdate;
		dojo.byId('conftitle2').innerHTML = _('Last Date:');
		dojo.byId('confvalue2').innerHTML = data.items.lastdate;
		dojo.byId('conftitle3').innerHTML = _('Repeating on these days:');
		dojo.byId('confvalue3').innerHTML = data.items.days.join('<br>');
		dojo.byId('conftitle4').innerHTML = _('During these times:');
		dojo.byId('confvalue4').innerHTML = data.items.times.join('<br>');
	}
	else if(data.items.repeating == 'monthly') {
		dojo.byId('confname').innerHTML = data.items.name;
		dojo.byId('confowner').innerHTML = data.items.owner;
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confrepeat').innerHTML = _('Monthly');
		dojo.byId('conftitle1').innerHTML = _('First Date:');
		dojo.byId('confvalue1').innerHTML = data.items.startdate;
		dojo.byId('conftitle2').innerHTML = _('Last Date:');
		dojo.byId('confvalue2').innerHTML = data.items.lastdate;
		dojo.byId('conftitle3').innerHTML = _('Repeat on:');
		dojo.byId('confvalue3').innerHTML = data.items.date1 + ' ' + _("of each month");
		dojo.byId('conftitle4').innerHTML = _('During these times:');
		dojo.byId('confvalue4').innerHTML = data.items.times.join('<br>');
	}
	else if(data.items.repeating == 'list') {
		dojo.byId('confname').innerHTML = data.items.name;
		dojo.byId('confowner').innerHTML = data.items.owner;
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confrepeat').innerHTML = _('List of Dates/Times');
		dojo.byId('conftitle1').innerHTML = _('Repeat on:');
		dojo.byId('confvalue1').innerHTML = data.items.slots.join('<br>');
	}
	dojo.byId('submitdeletecont').value = data.items.cont;
	document.body.style.cursor = 'default';
	dijit.byId('confirmDialog').show();
}

function deleteBlockSubmit() {
	var cont = dojo.byId('submitdeletecont').value;
	var data = {continuation: cont};
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function viewBlockAllocation(cont) {
	var data = {continuation: cont};
   document.body.style.cursor = 'wait';
	RPCwrapper(data, viewBlockAllocationCB, 1);
}

function viewBlockAllocationCB(data, ioArgs) {
	if(data.items.repeating == 'weekly') {
		dojo.byId('confname').innerHTML = data.items.name;
		dojo.byId('confowner').innerHTML = data.items.owner;
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confrepeat').innerHTML = _('Weekly');
		dojo.byId('conftitle1').innerHTML = _('First Date:');
		dojo.byId('confvalue1').innerHTML = data.items.startdate;
		dojo.byId('conftitle2').innerHTML = _('Last Date:');
		dojo.byId('confvalue2').innerHTML = data.items.lastdate;
		dojo.byId('conftitle3').innerHTML = _('Repeating on these days:');
		dojo.byId('confvalue3').innerHTML = data.items.days.join('<br>');
		dojo.byId('conftitle4').innerHTML = _('During these times:');
		dojo.byId('confvalue4').innerHTML = data.items.times.join('<br>');
	}
	else if(data.items.repeating == 'monthly') {
		dojo.byId('confname').innerHTML = data.items.name;
		dojo.byId('confowner').innerHTML = data.items.owner;
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confrepeat').innerHTML = _('Monthly');
		dojo.byId('conftitle1').innerHTML = _('First Date:');
		dojo.byId('confvalue1').innerHTML = data.items.startdate;
		dojo.byId('conftitle2').innerHTML = _('Last Date:');
		dojo.byId('confvalue2').innerHTML = data.items.lastdate;
		dojo.byId('conftitle3').innerHTML = _('Repeat on:');
		dojo.byId('confvalue3').innerHTML = data.items.date1 + ' ' + _("of each month");
		dojo.byId('conftitle4').innerHTML = _('During these times:');
		dojo.byId('confvalue4').innerHTML = data.items.times.join('<br>');
	}
	else if(data.items.repeating == 'list') {
		dojo.byId('confname').innerHTML = data.items.name;
		dojo.byId('confowner').innerHTML = data.items.owner;
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confrepeat').innerHTML = _('List of Dates/Times');
		dojo.byId('conftitle1').innerHTML = _('Repeat on:');
		dojo.byId('confvalue1').innerHTML = data.items.slots.join('<br>');
	}
	document.body.style.cursor = 'default';
	dijit.byId('viewDialog').show();
}

function acceptBlockConfirm(cont) {
	var data = {continuation: cont};
   document.body.style.cursor = 'wait';
	RPCwrapper(data, acceptBlockConfirmCB, 1);
}

function acceptBlockConfirmCB(data, ioArgs) {
	dojo.byId('acceptimage').innerHTML = data.items.image;
	dojo.byId('acceptseats').innerHTML = data.items.seats;
	if(data.items.usergroup == null) {
		dojo.addClass('staticusergroup', 'hidden');
		dojo.removeClass('editusergroup', 'hidden');
	}
	else {
		dojo.addClass('editusergroup', 'hidden');
		dojo.removeClass('staticusergroup', 'hidden');
		dojo.byId('acceptgroup').innerHTML = data.items.usergroup;
	}
	if('warnmsg' in data.items && data.items.warnmsg != '') {
		dojo.removeClass('warnmsgtr', 'hidden');
		dojo.byId('warnmsg').innerHTML = data.items.warnmsg;
	}
	else {
		dojo.addClass('warnmsgtr', 'hidden');
		dojo.byId('warnmsg').innerHTML = '';
	}
	if(data.items.validemail) {
		dojo.removeClass('acceptemailblock', 'hidden');
		dojo.addClass('acceptemailwarning', 'hidden');
		dojo.byId('acceptemailuser').innerHTML = data.items.emailuser;
		dijit.byId('acceptemailtext').attr('value', data.items.email);
	}
	else {
		dojo.addClass('acceptemailblock', 'hidden');
		dojo.removeClass('acceptemailwarning', 'hidden');
	}
	if(data.items.repeating == 'weekly') {
		dojo.byId('acceptrepeat').innerHTML = _('Weekly');
		dojo.byId('accepttitle1').innerHTML = _('First Date:');
		dojo.byId('acceptvalue1').innerHTML = data.items.startdate;
		dojo.byId('accepttitle2').innerHTML = _('Last Date:');
		dojo.byId('acceptvalue2').innerHTML = data.items.lastdate;
		dojo.byId('accepttitle3').innerHTML = _('Repeating on these days:');
		dojo.byId('acceptvalue3').innerHTML = data.items.days.join('<br>');
		dojo.byId('accepttitle4').innerHTML = _('During these times:');
		dojo.byId('acceptvalue4').innerHTML = data.items.times.join('<br>');
		dojo.byId('accepttitle5').innerHTML = _('User Submitted Comments:');
		dojo.byId('acceptvalue5').innerHTML = data.items.comments;
	}
	else if(data.items.repeating == 'monthly') {
		dojo.byId('acceptrepeat').innerHTML = _('Monthly');
		dojo.byId('accepttitle1').innerHTML = _('First Date:');
		dojo.byId('acceptvalue1').innerHTML = data.items.startdate;
		dojo.byId('accepttitle2').innerHTML = _('Last Date:');
		dojo.byId('acceptvalue2').innerHTML = data.items.lastdate;
		dojo.byId('accepttitle3').innerHTML = _('Repeat on:');
		dojo.byId('acceptvalue3').innerHTML = data.items.date1 + ' ' + _("of each month");
		dojo.byId('accepttitle4').innerHTML = _('During these times:');
		dojo.byId('acceptvalue4').innerHTML = data.items.times.join('<br>');
		dojo.byId('accepttitle5').innerHTML = _('User Submitted Comments:');
		dojo.byId('acceptvalue5').innerHTML = data.items.comments;
	}
	else if(data.items.repeating == 'list') {
		dojo.byId('acceptrepeat').innerHTML = _('List of Dates/Times');
		dojo.byId('accepttitle1').innerHTML = _('Repeat on:');
		dojo.byId('acceptvalue1').innerHTML = data.items.slots.join('<br>');
		dojo.byId('accepttitle2').innerHTML = _('User Submitted Comments:');
		dojo.byId('acceptvalue2').innerHTML = data.items.comments;
	}
	dojo.byId('submitacceptcont').value = data.items.cont;
	document.body.style.cursor = 'default';
	dijit.byId('acceptDialog').show();
}

function acceptBlockSubmit() {
	var cont = dojo.byId('submitacceptcont').value;
	var data = {continuation: cont,
	            groupid: getSelectValue('groupsel'),
	            brname: dijit.byId('brname').value,
	            emailtext: dijit.byId('acceptemailtext').attr('value')};
	if(dojo.byId('submitacceptcont2').value != '')
		data.continuation = dojo.byId('submitacceptcont2').value;
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function rejectBlockConfirm(cont) {
	var data = {continuation: cont};
   document.body.style.cursor = 'wait';
	RPCwrapper(data, rejectBlockConfirmCB, 1);
}

function rejectBlockConfirmCB(data, ioArgs) {
	dojo.byId('rejectimage').innerHTML = data.items.image;
	dojo.byId('rejectseats').innerHTML = data.items.seats;
	if(data.items.usergroup == null)
		dojo.addClass('staticusergroup', 'hidden');
	else {
		dojo.removeClass('staticusergroup', 'hidden');
		dojo.byId('rejectgroup').innerHTML = data.items.usergroup;
	}
	if(data.items.validemail) {
		dojo.removeClass('rejectemailblock', 'hidden');
		dojo.addClass('rejectemailwarning', 'hidden');
		dojo.byId('rejectemailuser').innerHTML = data.items.emailuser;
		dijit.byId('rejectemailtext').attr('value', data.items.email);
	}
	else {
		dojo.addClass('rejectemailblock', 'hidden');
		dojo.removeClass('rejectemailwarning', 'hidden');
	}
	if(data.items.repeating == 'weekly') {
		dojo.byId('rejectrepeat').innerHTML = _('Weekly');
		dojo.byId('rejecttitle1').innerHTML = _('First Date:');
		dojo.byId('rejectvalue1').innerHTML = data.items.startdate;
		dojo.byId('rejecttitle2').innerHTML = _('Last Date:');
		dojo.byId('rejectvalue2').innerHTML = data.items.lastdate;
		dojo.byId('rejecttitle3').innerHTML = _('Repeating on these days:');
		dojo.byId('rejectvalue3').innerHTML = data.items.days.join('<br>');
		dojo.byId('rejecttitle4').innerHTML = _('During these times:');
		dojo.byId('rejectvalue4').innerHTML = data.items.times.join('<br>');
		dojo.byId('rejecttitle5').innerHTML = _('User Submitted Comments:');
		dojo.byId('rejectvalue5').innerHTML = data.items.comments;
	}
	else if(data.items.repeating == 'monthly') {
		dojo.byId('rejectrepeat').innerHTML = _('Monthly');
		dojo.byId('rejecttitle1').innerHTML = _('First Date:');
		dojo.byId('rejectvalue1').innerHTML = data.items.startdate;
		dojo.byId('rejecttitle2').innerHTML = _('Last Date:');
		dojo.byId('rejectvalue2').innerHTML = data.items.lastdate;
		dojo.byId('rejecttitle3').innerHTML = _('Repeat on:');
		dojo.byId('rejectvalue3').innerHTML = data.items.date1 + ' ' + _("of each month");
		dojo.byId('rejecttitle4').innerHTML = _('During these times:');
		dojo.byId('rejectvalue4').innerHTML = data.items.times.join('<br>');
		dojo.byId('rejecttitle5').innerHTML = _('User Submitted Comments:');
		dojo.byId('rejectvalue5').innerHTML = data.items.comments;
	}
	else if(data.items.repeating == 'list') {
		dojo.byId('rejectrepeat').innerHTML = _('List of Dates/Times');
		dojo.byId('rejecttitle1').innerHTML = _('Repeat on:');
		dojo.byId('rejectvalue1').innerHTML = data.items.slots.join('<br>');
		dojo.byId('rejecttitle2').innerHTML = _('User Submitted Comments:');
		dojo.byId('rejectvalue2').innerHTML = data.items.comments;
	}
	dojo.byId('submitrejectcont').value = data.items.cont;
	document.body.style.cursor = 'default';
	dijit.byId('rejectDialog').show();
}

function rejectBlockSubmit() {
	var cont = dojo.byId('submitrejectcont').value;
	var data = {continuation: cont,
	            groupid: getSelectValue('groupsel'),
	            brname: dijit.byId('brname').value,
	            emailtext: dijit.byId('rejectemailtext').attr('value')};
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function sortTimeArray(a, b) {
	if(a.key < b.key)
		return -1;
	return 1;
}

function gridDateTimePrimary(val) {
	return val.substr(4, 2) + '/' + val.substr(6, 2) + '/' + val.substr(0, 4) + ' ' + dojo.byId('timezone').value;
}

function gridTimePrimary(val) {
	var hour = parseInt(val.substr(0, 2), 10);
	var min = parseInt(val.substr(2, 2), 10);
	return formatHourMin(hour, min) + ' ' + dojo.byId('timezone').value;
}

function timeFromTextBox(time) {
	var hour = time.getHours();
	var min = time.getMinutes();
	return formatHourMin(hour, min) + ' ' + dojo.byId('timezone').value;
}

function formatHourMin(hour, min) {
	if(min < 10)
		min = "0" + min;
	if(hour == 0)
		return 12 + ":" + min + " AM";
	if(hour < 12)
		return hour + ":" + min + " AM";
	if(hour == 12)
		return 12 + ":" + min + " PM";
	return (hour - 12) + ":" + min + " PM";
}

function viewBlockTimes(cont) {
	var data = {continuation: cont};
	document.body.style.cursor = 'wait';
	RPCwrapper(data, viewBlockTimesCB, 1);
}

function viewBlockTimesCB(data, ioArgs) {
	document.body.style.cursor = 'default';
	var cont = data.items.cont;
	dojo.byId('toggletimecont').value = cont;
	var items = data.items.items;
	for(var i = 0; i < items.length; i++) {
		if(items[i].skip == 0)
			var label = _('Skip');
		else
			var label = _('Use');
		var btn = new dijit.form.Button({
			label: label,
			onClick: createRemoveFunc(toggleBlockTime, items[i].id)
		});
		items[i].delbtn = btn;
	}
	var newdata = new Object;
	newdata.items = items;
	var newstore = new dojo.data.ItemFileWriteStore({data: newdata});
	var oldstore = blockTimesGrid.store;
	blockTimesGrid.setStore(newstore);
	if(oldstore)
		delete oldstore;
	dijit.byId('viewtimesDialog').show();
	blockTimesGrid.render();
}

function toggleBlockTime(id) {
	var cont = dojo.byId('toggletimecont').value;
	var data = {blocktimeid: id,
	            continuation: cont};
	document.body.style.cursor = 'wait';
	RPCwrapper(data, toggleBlockTimeCB, 1);
}

function toggleBlockTimeCB(data, ioArgs) {
	document.body.style.cursor = 'default';
	if(data.items.error) {
		alert(data.items.error);
		return;
	}
	blockTimesGrid.store.fetch({query: {id: data.items.timeid}, onComplete:
			function(items, request) {
				items[0].skip[0] = data.items.newval;
				if(data.items.newval == 1)
					items[0].delbtn[0].setLabel(_('Use'));
				else
					items[0].delbtn[0].setLabel(_('Skip'));
				blockTimesGrid.update();
			}
	});
}

function blockTimeRowStyle(row) {
	var item = blockTimesGrid.getItem(row.index);
	if(item) {
	  var skip = blockTimesGrid.store.getValue(item, 'skip');
	  if(skip == 1)
	    row.customStyles += "background-color: red;";
	}
	blockTimesGrid.focus.styleRow(row);
	blockTimesGrid.edit.styleRow(row);
}

function blockTimesGridDate(val) {
	var year = val.substr(0, 4);
	var month = val.substr(5, 2);
	var day = val.substr(8, 2);
	return dojox.string.sprintf('%s/%s/%s', month, day, year);
}

function blockTimesGridStart(val) {
	var hour = parseInt(val.substr(11, 2), 10);
	var min = parseInt(val.substr(14, 2), 10);
	return formatHourMin(hour, min) + ' ' + dojo.byId('timezone').value;
}

function blockTimesGridEnd(val) {
	var hour = parseInt(val.substr(11, 2), 10);
	var min = parseInt(val.substr(14, 2), 10);
	return formatHourMin(hour, min) + ' ' + dojo.byId('timezone').value;
}

function ownerFocus() {
	if(! dijit.byId('browner')._hasBeenBlurred)
		dijit.byId('browner')._hasBeenBlurred = true;
}

function checkOwner(val, constraints) {
	if(! dijit.byId('browner')._hasBeenBlurred)
		return true;
	if(timeout != null)
		clearTimeout(timeout);
	timeout = setTimeout(checkOwner2, 700);
	return ownervalid;
}

function checkOwner2() {
	var data = {user: dijit.byId('browner').textbox.value,
	            continuation: dojo.byId('valuseridcont').value};
	RPCwrapper(data, checkOwnerCB, 1);
}

function checkOwnerCB(data, ioArgs) {
	var obj = dijit.byId('browner');
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
}

function updateAllocatedMachines() {
	var d = dijit.byId('chartstartdate').value;
	var t = dijit.byId('chartstarttime').value;
	var date1 = dojox.string.sprintf('%d-%02d-%02d %02d:%02d',
	            d.getFullYear(),
	            (d.getMonth() + 1),
	            d.getDate(),
	            t.getHours(),
	            t.getMinutes());
	var cont = dojo.byId('updatecont').value;
	RPCwrapper({continuation: cont, start: date1}, updateAllocatedMachinesCB, 1);
}

function updateAllocatedMachinesCB(data, ioArgs) {
	dojo.byId('updatecont').value = data.items.cont;
	var graph = dijit.byId('allocatedBareMachines').chart;
	graph.updateSeries('Main', data.items.bare.points);
	graph.labeldata = data.items.bare.points;
	graph.render();
	var graph = dijit.byId('allocatedVirtualMachines').chart;
	graph.updateSeries('Main', data.items.virtual.points);
	graph.labeldata = data.items.virtual.points;
	graph.render();
	if(data.items.bare.total != 0)
		dojo.byId('totalbare').innerHTML = _('Total online:') + ' ' + data.items.bare.total;
	else
		dojo.byId('totalbare').innerHTML = '';
	if(data.items.virtual.total != 0)
		dojo.byId('totalvirtual').innerHTML = _('Total online:') + ' ' + data.items.virtual.total;
	else
		dojo.byId('totalvirtual').innerHTML = '';
	dojo.byId('allocatedBareMachines').style.height = '320px';
	dojo.byId('allocatedBareMachines').childNodes[0].attributes[1].nodeValue = '320';
	dojo.byId('allocatedVirtualMachines').style.height = '320px';
	dojo.byId('allocatedVirtualMachines').childNodes[0].attributes[1].nodeValue = '320';
}

function timestampToTimeBare(val) {
	if(! dijit.byId('allocatedBareMachines').chart.labeldata)
		return '';
	else
		var data = dijit.byId('allocatedBareMachines').chart.labeldata;
	return data[val]['text'];
}

function timestampToTimeVirtual(val) {
	if(! dijit.byId('allocatedVirtualMachines').chart.labeldata)
		return '';
	else
		var data = dijit.byId('allocatedVirtualMachines').chart.labeldata;
	return data[val]['text'];
}

function machinecntfilter(val) {
	return parseInt(val);
}

function viewBlockUsage(blockid) {
	var cont = dojo.byId('viewblockusagecont').value;
	RPCwrapper({continuation: cont, blockid: blockid}, viewBlockUsageCB, 1);
}

function viewBlockUsageCB(data, ioArgs) {
	if(data.items.status == 'success') {
		if(usagechart)
			usagechart.destroy();
		usagechart = new dojox.charting.Chart2D('blockusagechartdiv');
		usagechart.setTheme(dojox.charting.themes.ThreeD);
		var xtickstep = parseInt(data.items.usage.xlabels.length / 10) || 1;
		usagechart.addAxis("x", {
			includeZero: false,
			labels: data.items.usage.xlabels,
			rotation: -90,
			minorTicks: false,
			font: 'normal normal normal 11px verdana',
			majorTickStep: xtickstep
		});
		usagechart.addAxis('y', {
			vertical: true,
			max: 100,
			includeZero: true,
			minorTicks: true,
			minorLabels: false,
			majorTickStep: 20,
			minorTickStep: 10
		});
		usagechart.addPlot('default', {type: "Columns", gap: 1});
		usagechart.addPlot('Grid', {type: 'Grid', hMajorLines: true, vMajorLines: false});
		usagechart.addSeries("Main", data.items.usage.points, {stroke: {width: 1}});
		var a = new dojox.charting.action2d.Tooltip(usagechart);
		usagechart.render();
		dojo.addClass('blockusageemptydiv', 'hidden');
		dojo.removeClass('blockusagechartdiv', 'hidden');
		dijit.byId('viewUsageDialog').show();
	}
	else if(data.items.status == 'empty') {
		dojo.addClass('blockusagechartdiv', 'hidden');
		dojo.removeClass('blockusageemptydiv', 'hidden');
		dijit.byId('viewUsageDialog').show();
	}
}

function clearCont2() {
	if(dojo.byId('submitcont2'))
		dojo.byId('submitcont2').value = '';
	if(dojo.byId('submitacceptcont2'))
		dojo.byId('submitacceptcont2').value = '';
}
