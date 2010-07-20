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
				label: "Remove",
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
			// todo finish this
			var start = new Date(0);
			start.setHours(data.items.starths[i]);
			start.setMinutes(data.items.startms[i]);
			var end = new Date(0);
			end.setHours(data.items.endhs[i]);
			end.setMinutes(data.items.endms[i]);
			var btn = new dijit.form.Button({
				label: "Remove",
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
		dojo.byId('statusdiv').innerHTML = 'The selected Block Request no longer exists.';
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

	var startts = s.getTime();
	var endts = end.getTime();
	var items = requestBlockAddWeeklyStore._getItemsArray();
	var len = items.length;
	for(var i = 0; i < len; i++) {
		if(startts < items[i].end[0].getTime() &&
		   endts > items[i].start2[0].getTime()) {
			alert('These times overlap with an existing time slot');
			return;
		}
	}

	if(! requestBlockAddWeeklyStore.nextid)
		requestBlockAddWeeklyStore.nextid = 0;
	var id = requestBlockAddWeeklyStore.nextid + 1;
	requestBlockAddWeeklyStore.nextid = id;

	var btn = new dijit.form.Button({
		label: "Remove",
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
			alert('These times overlap with an existing time slot');
			return;
		}
	}

	if(! requestBlockAddMonthlyStore.nextid)
		requestBlockAddMonthlyStore.nextid = 0;
	var id = requestBlockAddMonthlyStore.nextid + 1;
	requestBlockAddMonthlyStore.nextid = id;

	var btn = new dijit.form.Button({
		label: "Remove",
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
	var today = new Date();
	today.setHours(0);
	today.setMinutes(0);
	today.setSeconds(0);
	today.setMilliseconds(0);
	if(dateobj.value < today) {
		alert('The date must be today or later');
		return;
	}

	var d = dateobj.value;
	var start = startobj.value;
	var end = endobj.value;

	var year = d.getYear();
	if(year < 100)
		year = "20" + year;
	else
		year = 1900 + year;
	var date1 = dojox.string.sprintf('%d%02d%02d%02d%02d%02d%02d',
	            year,
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
			alert('The date and times overlap with an existing time slot');
			return;
		}
	}

	if(! requestBlockAddListStore.nextid)
		requestBlockAddListStore.nextid = 0;
	var id = requestBlockAddListStore.nextid + 1;
	requestBlockAddListStore.nextid = id;

	var btn = new dijit.form.Button({
		label: "Remove",
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
	   ! dijit.byId('imagesel').isValid() ||
	   ! dijit.byId('groupsel').isValid() ||
		(dijit.byId('brname') && ! dijit.byId('brname').isValid())) {
		alert('Please fix invalid values before submitting.');
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
		alert('Please fill in First Date of Usage');
		return;
	}
	if(! dijit.byId('wklastdate').isValid()) {
		dijit.byId('wklastdate')._hasBeenBlurred = true;
		dijit.byId('wklastdate').validate();
		alert('Please fill in Last Date of Usage');
		return;
	}
	var today = new Date();
	today.setHours(0);
	today.setMinutes(0);
	today.setSeconds(0);
	today.setMilliseconds(0);
	if(dijit.byId('wkfirstdate').value < today) {
		alert('The First Date of Usage must be today or later');
		return;
	}
	if(dijit.byId('wklastdate').value < dijit.byId('wkfirstdate').value) {
		alert('The Last Date of Usage must be the same or later than the First Date of Usage');
		return;
	}
	var days = new Array();
	if(dojo.byId('wdaysSunday').checked)
		days.push('Sunday');
	if(dojo.byId('wdaysMonday').checked)
		days.push('Monday');
	if(dojo.byId('wdaysTuesday').checked)
		days.push('Tuesday');
	if(dojo.byId('wdaysWednesday').checked)
		days.push('Wednesday');
	if(dojo.byId('wdaysThursday').checked)
		days.push('Thursday');
	if(dojo.byId('wdaysFriday').checked)
		days.push('Friday');
	if(dojo.byId('wdaysSaturday').checked)
		days.push('Saturday');
	if(days.length == 0) {
		alert('At least one day must be checked when using "Repeating Weekly"');
		return;
	}
	var len = requestBlockAddWeeklyStore._getItemsArray().length;
	if(len == 0) {
		alert('At least one start/end combination must be entered when using "Repeating Weekly"');
		return;
	}
	if(mode == 'request' && dijit.byId('groupsel').value == 0 &&
	   dijit.byId('comments').value.length == 0) {
		alert('When submitting "(group not listed)" as the user group, information must be included in the comments about what group needs to be created.');
		return;
	}
	if(mode != 'request') {
		dojo.byId('confnametitle').innerHTML = 'Name:';
		dojo.byId('confname').innerHTML = dijit.byId('brname').textbox.value;
	}
	dojo.byId('confimage').innerHTML = dijit.byId('imagesel').textbox.value;
	dojo.byId('confseats').innerHTML = dijit.byId('machinecnt').value;
	if(dijit.byId('groupsel').value == 0)
		dojo.byId('confgroup').innerHTML = 'specified in comments';
	else
		dojo.byId('confgroup').innerHTML = dijit.byId('groupsel').textbox.value;
	if(mode != 'request') {
		dojo.byId('confadmintitle').innerHTML = 'Managing User Group:';
		dojo.byId('confadmingroup').innerHTML = dijit.byId('admingroupsel').textbox.value;
	}
	dojo.byId('confrepeat').innerHTML = 'Weekly';
	dojo.byId('conftitle1').innerHTML = 'First Date:';
	dojo.byId('confvalue1').innerHTML = dijit.byId('wkfirstdate').getDisplayedValue();
	dojo.byId('conftitle2').innerHTML = 'Last Date:';
	dojo.byId('confvalue2').innerHTML = dijit.byId('wklastdate').getDisplayedValue();
	dojo.byId('conftitle3').innerHTML = 'Repeating on these days:';
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
	dojo.byId('conftitle4').innerHTML = 'During these times:';
	dojo.byId('confvalue4').innerHTML = times2.join('<br>');
	if(dijit.byId('comments') && dijit.byId('comments').value.length)
		dojo.removeClass('commentsnote', 'hidden');
	dijit.byId('confirmDialog').show();
}

function blockFormSubmitWeekly(mode) {
	var days = new Array();
	if(dojo.byId('wdaysSunday').checked)
		days.push(0);
	if(dojo.byId('wdaysMonday').checked)
		days.push(1);
	if(dojo.byId('wdaysTuesday').checked)
		days.push(2);
	if(dojo.byId('wdaysWednesday').checked)
		days.push(3);
	if(dojo.byId('wdaysThursday').checked)
		days.push(4);
	if(dojo.byId('wdaysFriday').checked)
		days.push(5);
	if(dojo.byId('wdaysSaturday').checked)
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
	var imageid = dijit.byId('imagesel').value;
	var seats = dijit.byId('machinecnt').value;
	var groupid = dijit.byId('groupsel').value;
	var obj = dijit.byId('wkfirstdate').value;
	var year = obj.getYear();
	if(year < 100)
		year = "20" + year;
	else
		year = 1900 + year;
	var startdate = dojox.string.sprintf('%d%02d%02d',
	                year,
	                (obj.getMonth() + 1),
	                obj.getDate());
	obj = dijit.byId('wklastdate').value;
	year = obj.getYear();
	if(year < 100)
		year = "20" + year;
	else
		year = 1900 + year;
	var enddate = dojox.string.sprintf('%d%02d%02d',
	              year,
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
	if(mode != 'request') {
		data.name = dijit.byId('brname').value;
		data.admingroupid = dijit.byId('admingroupsel').value;
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
		alert('Please fill in First Date of Usage');
		return;
	}
	if(! dijit.byId('mnlastdate').isValid()) {
		dijit.byId('mnlastdate')._hasBeenBlurred = true;
		dijit.byId('mnlastdate').validate();
		alert('Please fill in Last Date of Usage');
		return;
	}
	var today = new Date();
	today.setHours(0);
	today.setMinutes(0);
	today.setSeconds(0);
	today.setMilliseconds(0);
	if(dijit.byId('mnfirstdate').value < today) {
		alert('The First Date of Usage must be today or later');
		return;
	}
	if(dijit.byId('mnlastdate').value < dijit.byId('mnfirstdate').value) {
		alert('The Last Date of Usage must be the same or later than the First Date of Usage');
		return;
	}
	var len = requestBlockAddMonthlyStore._getItemsArray().length;
	if(len == 0) {
		alert('At least one start/end combination must be entered when using "Repeating Monthly"');
		return;
	}
	if(mode == 'request' && dijit.byId('groupsel').value == 0 &&
	   dijit.byId('comments').value.length == 0) {
		alert('When submitting "(group not listed)" as the user group, information must be included in the comments about what group needs to be created.');
		return;
	}
	if(mode != 'request') {
		dojo.byId('confnametitle').innerHTML = 'Name:';
		dojo.byId('confname').innerHTML = dijit.byId('brname').textbox.value;
	}
	dojo.byId('confimage').innerHTML = dijit.byId('imagesel').textbox.value;
	dojo.byId('confseats').innerHTML = dijit.byId('machinecnt').value;
	if(dijit.byId('groupsel').value == 0)
		dojo.byId('confgroup').innerHTML = 'specified in comments';
	else
		dojo.byId('confgroup').innerHTML = dijit.byId('groupsel').textbox.value;
	if(mode != 'request') {
		dojo.byId('confadmintitle').innerHTML = 'Managing User Group:';
		dojo.byId('confadmingroup').innerHTML = dijit.byId('admingroupsel').textbox.value;
	}
	dojo.byId('confrepeat').innerHTML = 'Monthly';
	dojo.byId('conftitle1').innerHTML = 'First Date:';
	dojo.byId('confvalue1').innerHTML = dijit.byId('mnfirstdate').getDisplayedValue();
	dojo.byId('conftitle2').innerHTML = 'Last Date:';
	dojo.byId('confvalue2').innerHTML = dijit.byId('mnlastdate').getDisplayedValue();
	dojo.byId('conftitle3').innerHTML = 'Repeat on:';
	var obj = dojo.byId('mnweeknum');
	var date1 = obj.options[obj.selectedIndex].text;
	obj = dojo.byId('mnday');
	date1 += " " + obj.options[obj.selectedIndex].text;
	dojo.byId('confvalue3').innerHTML = date1 + " of each month";
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
	dojo.byId('conftitle4').innerHTML = 'During these times:';
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
	var imageid = dijit.byId('imagesel').value;
	var seats = dijit.byId('machinecnt').value;
	var groupid = dijit.byId('groupsel').value;
	var obj = dijit.byId('mnfirstdate').value;
	var year = obj.getYear();
	if(year < 100)
		year = "20" + year;
	else
		year = 1900 + year;
	var startdate = dojox.string.sprintf('%d%02d%02d',
	                year,
	                (obj.getMonth() + 1),
	                obj.getDate());
	obj = dijit.byId('mnlastdate').value;
	year = obj.getYear();
	if(year < 100)
		year = "20" + year;
	else
		year = 1900 + year;
	var enddate = dojox.string.sprintf('%d%02d%02d',
	              year,
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
	if(mode != 'request') {
		data.name = dijit.byId('brname').value;
		data.admingroupid = dijit.byId('admingroupsel').value;
	}
	else
		data.comments = dijit.byId('comments').value;
   document.body.style.cursor = 'wait';
	RPCwrapper(data, generalReqCB);
}

function blockFormVerifyList(mode) {
	var len = requestBlockAddListStore._getItemsArray().length;
	if(len == 0) {
		alert('At least one date/start/end combination must be entered when using "List of Dates/Times"');
		return;
	}
	if(dijit.byId('groupsel').value == 0 && dijit.byId('comments').value.length == 0) {
		alert('When submitting "(group not listed)" as the user group, information must be included in the comments about what group needs to be created.');
		return;
	}
	if(mode != 'request') {
		dojo.byId('confnametitle').innerHTML = 'Name:';
		dojo.byId('confname').innerHTML = dijit.byId('brname').textbox.value;
	}
	dojo.byId('confimage').innerHTML = dijit.byId('imagesel').textbox.value;
	dojo.byId('confseats').innerHTML = dijit.byId('machinecnt').value;
	if(dijit.byId('groupsel').value == 0)
		dojo.byId('confgroup').innerHTML = 'specified in comments';
	else
		dojo.byId('confgroup').innerHTML = dijit.byId('groupsel').textbox.value;
	if(mode != 'request') {
		dojo.byId('confadmintitle').innerHTML = 'Managing User Group:';
		dojo.byId('confadmingroup').innerHTML = dijit.byId('admingroupsel').textbox.value;
	}
	dojo.byId('confrepeat').innerHTML = 'List of Dates/Times';
	dojo.byId('conftitle1').innerHTML = 'Repeat on:';
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
	var imageid = dijit.byId('imagesel').value;
	var seats = dijit.byId('machinecnt').value;
	var groupid = dijit.byId('groupsel').value;
	var data = {continuation: dojo.byId('submitcont').value,
	            imageid: imageid,
	            seats: seats,
	            groupid: groupid,
	            type: 'list',
	            slots: allslots};
	if(mode != 'request') {
		data.name = dijit.byId('brname').value;
		data.admingroupid = dijit.byId('admingroupsel').value;
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
	dojo.byId('confimage').innerHTML = '';
	dojo.byId('confseats').innerHTML = '';
	dojo.byId('confgroup').innerHTML = '';
	dojo.byId('confadmintitle').innerHTML = '';
	dojo.byId('confadmingroup').innerHTML = '';
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
	dojo.byId('confimage').innerHTML = '';
	dojo.byId('confseats').innerHTML = '';
	dojo.byId('confgroup').innerHTML = '';
	dojo.byId('confadmingroup').innerHTML = '';
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
	dijit.byId('groupsel').attr('displayedValue', dijit.byId('groupsel').focusNode.defaultValue);
	dojo.byId('brname').value = '';
	dijit.byId('admingroupsel').attr('displayedValue', 'None (owner only)');
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
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confadmingroup').innerHTML = data.items.admingroup;
		dojo.byId('confrepeat').innerHTML = 'Weekly';
		dojo.byId('conftitle1').innerHTML = 'First Date:';
		dojo.byId('confvalue1').innerHTML = data.items.startdate;
		dojo.byId('conftitle2').innerHTML = 'Last Date:';
		dojo.byId('confvalue2').innerHTML = data.items.lastdate;
		dojo.byId('conftitle3').innerHTML = 'Repeating on these days:';
		dojo.byId('confvalue3').innerHTML = data.items.days.join('<br>');
		dojo.byId('conftitle4').innerHTML = 'During these times:';
		dojo.byId('confvalue4').innerHTML = data.items.times.join('<br>');
	}
	else if(data.items.repeating == 'monthly') {
		dojo.byId('confname').innerHTML = data.items.name;
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confadmingroup').innerHTML = data.items.admingroup;
		dojo.byId('confrepeat').innerHTML = 'Monthly';
		dojo.byId('conftitle1').innerHTML = 'First Date:';
		dojo.byId('confvalue1').innerHTML = data.items.startdate;
		dojo.byId('conftitle2').innerHTML = 'Last Date:';
		dojo.byId('confvalue2').innerHTML = data.items.lastdate;
		dojo.byId('conftitle3').innerHTML = 'Repeat on:';
		dojo.byId('confvalue3').innerHTML = data.items.date1 + " of each month";
		dojo.byId('conftitle4').innerHTML = 'During these times:';
		dojo.byId('confvalue4').innerHTML = data.items.times.join('<br>');
	}
	else if(data.items.repeating == 'list') {
		dojo.byId('confname').innerHTML = data.items.name;
		dojo.byId('confimage').innerHTML = data.items.image;
		dojo.byId('confseats').innerHTML = data.items.seats;
		dojo.byId('confgroup').innerHTML = data.items.usergroup;
		dojo.byId('confadmingroup').innerHTML = data.items.admingroup;
		dojo.byId('confrepeat').innerHTML = 'List of Dates/Times';
		dojo.byId('conftitle1').innerHTML = 'Repeat on:';
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
		dojo.byId('acceptrepeat').innerHTML = 'Weekly';
		dojo.byId('accepttitle1').innerHTML = 'First Date:';
		dojo.byId('acceptvalue1').innerHTML = data.items.startdate;
		dojo.byId('accepttitle2').innerHTML = 'Last Date:';
		dojo.byId('acceptvalue2').innerHTML = data.items.lastdate;
		dojo.byId('accepttitle3').innerHTML = 'Repeating on these days:';
		dojo.byId('acceptvalue3').innerHTML = data.items.days.join('<br>');
		dojo.byId('accepttitle4').innerHTML = 'During these times:';
		dojo.byId('acceptvalue4').innerHTML = data.items.times.join('<br>');
		dojo.byId('accepttitle5').innerHTML = 'User Submitted Comments:';
		dojo.byId('acceptvalue5').innerHTML = data.items.comments;
	}
	else if(data.items.repeating == 'monthly') {
		dojo.byId('acceptrepeat').innerHTML = 'Monthly';
		dojo.byId('accepttitle1').innerHTML = 'First Date:';
		dojo.byId('acceptvalue1').innerHTML = data.items.startdate;
		dojo.byId('accepttitle2').innerHTML = 'Last Date:';
		dojo.byId('acceptvalue2').innerHTML = data.items.lastdate;
		dojo.byId('accepttitle3').innerHTML = 'Repeat on:';
		dojo.byId('acceptvalue3').innerHTML = data.items.date1 + " of each month";
		dojo.byId('accepttitle4').innerHTML = 'During these times:';
		dojo.byId('acceptvalue4').innerHTML = data.items.times.join('<br>');
		dojo.byId('accepttitle5').innerHTML = 'User Submitted Comments:';
		dojo.byId('acceptvalue5').innerHTML = data.items.comments;
	}
	else if(data.items.repeating == 'list') {
		dojo.byId('acceptrepeat').innerHTML = 'List of Dates/Times';
		dojo.byId('accepttitle1').innerHTML = 'Repeat on:';
		dojo.byId('acceptvalue1').innerHTML = data.items.slots.join('<br>');
		dojo.byId('accepttitle2').innerHTML = 'User Submitted Comments:';
		dojo.byId('acceptvalue2').innerHTML = data.items.comments;
	}
	dojo.byId('submitacceptcont').value = data.items.cont;
	document.body.style.cursor = 'default';
	dijit.byId('acceptDialog').show();
}

function acceptBlockSubmit() {
	var cont = dojo.byId('submitacceptcont').value;
	var data = {continuation: cont,
	            groupid: dijit.byId('groupsel').value,
	            brname: dijit.byId('brname').value,
	            admingroupid: dijit.byId('admingroupsel').value,
	            emailtext: dijit.byId('acceptemailtext').attr('value')};
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
		dojo.byId('rejectrepeat').innerHTML = 'Weekly';
		dojo.byId('rejecttitle1').innerHTML = 'First Date:';
		dojo.byId('rejectvalue1').innerHTML = data.items.startdate;
		dojo.byId('rejecttitle2').innerHTML = 'Last Date:';
		dojo.byId('rejectvalue2').innerHTML = data.items.lastdate;
		dojo.byId('rejecttitle3').innerHTML = 'Repeating on these days:';
		dojo.byId('rejectvalue3').innerHTML = data.items.days.join('<br>');
		dojo.byId('rejecttitle4').innerHTML = 'During these times:';
		dojo.byId('rejectvalue4').innerHTML = data.items.times.join('<br>');
		dojo.byId('rejecttitle5').innerHTML = 'User Submitted Comments:';
		dojo.byId('rejectvalue5').innerHTML = data.items.comments;
	}
	else if(data.items.repeating == 'monthly') {
		dojo.byId('rejectrepeat').innerHTML = 'Monthly';
		dojo.byId('rejecttitle1').innerHTML = 'First Date:';
		dojo.byId('rejectvalue1').innerHTML = data.items.startdate;
		dojo.byId('rejecttitle2').innerHTML = 'Last Date:';
		dojo.byId('rejectvalue2').innerHTML = data.items.lastdate;
		dojo.byId('rejecttitle3').innerHTML = 'Repeat on:';
		dojo.byId('rejectvalue3').innerHTML = data.items.date1 + " of each month";
		dojo.byId('rejecttitle4').innerHTML = 'During these times:';
		dojo.byId('rejectvalue4').innerHTML = data.items.times.join('<br>');
		dojo.byId('rejecttitle5').innerHTML = 'User Submitted Comments:';
		dojo.byId('rejectvalue5').innerHTML = data.items.comments;
	}
	else if(data.items.repeating == 'list') {
		dojo.byId('rejectrepeat').innerHTML = 'List of Dates/Times';
		dojo.byId('rejecttitle1').innerHTML = 'Repeat on:';
		dojo.byId('rejectvalue1').innerHTML = data.items.slots.join('<br>');
		dojo.byId('rejecttitle2').innerHTML = 'User Submitted Comments:';
		dojo.byId('rejectvalue2').innerHTML = data.items.comments;
	}
	dojo.byId('submitrejectcont').value = data.items.cont;
	document.body.style.cursor = 'default';
	dijit.byId('rejectDialog').show();
}

function rejectBlockSubmit() {
	var cont = dojo.byId('submitrejectcont').value;
	var data = {continuation: cont,
	            groupid: dijit.byId('groupsel').value,
	            brname: dijit.byId('brname').value,
	            admingroupid: dijit.byId('admingroupsel').value,
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
	return val.substr(4, 2) + '/' + val.substr(6, 2) + '/' + val.substr(0, 4);
}

function gridTimePrimary(val) {
	var hour = parseInt(val.substr(0, 2), 10);
	var min = parseInt(val.substr(2, 2), 10);
	return formatHourMin(hour, min);
}

function timeFromTextBox(time) {
	var hour = time.getHours();
	var min = time.getMinutes();
	return formatHourMin(hour, min);
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