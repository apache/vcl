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

var refreshtimer;

function generalReqCB(data, ioArgs) {
	eval(data);
	document.body.style.cursor = 'default';
}

function updateDashboard() {
	var data = {continuation: dojo.byId('updatecont').value};
	if(dojo.byId('affilid'))
		data['affilid'] = dojo.byId('affilid').value;
	RPCwrapper(data, updateDashboardCB, 1);
}

function updateDashboardCB(data, ioArgs) {
	dojo.byId('updatecont').value = data.items.cont;
	updateStatus(data.items.status);
	updateTopImages(data.items.topimages);
	updateTopLongImages(data.items.toplongimages);
	updateTopPastImages(data.items.toppastimages);
	updateTopFailed(data.items.topfailed);
	updateTopFailedComputers(data.items.topfailedcomputers);
	updateResChart(data.items.reschart);
	updateBlockAllocation(data.items.blockallocation);
	if(dojo.byId('newreservations'))
		updateNewReservations(data.items.newreservations);
	if(dojo.byId('failedimaging'))
		updateFailedImaging(data.items.failedimaging);
	clearTimeout(refreshtimer);
	refreshtimer = setTimeout(updateDashboard, 15000);
	updateManagementNodes(data.items.managementnodes);
}

function updateStatus(data) {
	var obj = dojo.byId('status');
	var txt = '<table>';
	for(var i = 0; i < data.length; i++) {
		txt += '<tr><th align="right">'
		if(data[i].tooltip) {
			txt += '<span id="status' + i + '">'
			    + data[i].key
			    + '</span>'
			    + '</th><td>'
			    + data[i].val
			    + '</td></tr>';
		}
		else {
			txt += data[i].key
			    + '</th><td>'
			    + data[i].val
			    + '</td></tr>';
		}
	}
	txt += '</table>';
	obj.innerHTML = txt;
	for(var i = 0; i < data.length; i++) {
		if(data[i].tooltip) {
			var tt = new dijit.Tooltip({
				connectId: ['status' + i],
				label: data[i].tooltip
			});
		}
	}
}

function updateTopImages(data) {
	var obj = dojo.byId('topimages');
	if(data.length == 0) {
		obj.innerHTML = 'No recent reservations';
		return;
	}
	var txt = '<table>';
	for(var i = 0; i < data.length; i++) {
		txt += '<tr><th align="right">'
		    + data[i].prettyname
		    + '</th><td>'
		    + data[i].count
		    + '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
}

function updateTopLongImages(data) {
	var obj = dojo.byId('toplongimages');
	if(data.length == 0) {
		obj.innerHTML = 'No recent reservations';
		return;
	}
	var txt = '<table>';
	for(var i = 0; i < data.length; i++) {
		txt += '<tr><th align="right">'
		    + data[i].prettyname
		    + '</th><td>'
		    + data[i].count
		    + '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
}

function updateTopPastImages(data) {
	var obj = dojo.byId('toppastimages');
	if(data.length == 0) {
		obj.innerHTML = 'No recent reservations';
		return;
	}
	var txt = '<table>';
	for(var i = 0; i < data.length; i++) {
		txt += '<tr><th align="right">'
		    + data[i].prettyname
		    + '</th><td>'
		    + data[i].count
		    + '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
}

function updateTopFailed(data) {
	var obj = dojo.byId('topfailed');
	if(data.length == 0) {
		obj.innerHTML = 'No recent reservations';
		return;
	}
	var txt = '<table>';
	txt += '<tr><th align="right">'
	txt += 'Image</th><th>User</th><th>Reload</th></tr>'
	for(var i = 0; i < data.length; i++) {
		txt += '<tr><th align="right">'
		    + data[i].prettyname
		    + '</th><td>'
		    + data[i].count
		    + '</td><td>'
		    + data[i].reloadcount
		    + '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
}

function updateTopFailedComputers(data) {
	var obj = dojo.byId('topfailedcomputers');
	if(data.length == 0) {
		obj.innerHTML = 'No recent reservations';
		return;
	}
	var txt = '<table>';
	for(var i = 0; i < data.length; i++) {
		txt += '<tr><th align="right">'
		    + data[i].hostname
		    + '</th><td>'
		    + data[i].count
		    + '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
}

function updateBlockAllocation(data) {
	var obj = dojo.byId('blockallocation');
	var txt = '<table>';
	for(var i = 0; i < data.length; i++) {
		txt += '<tr><th align="right">'
		    + data[i].title
		    + '</th><td>'
		    + data[i].val
		    + '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
}

function updateResChart(data) {
	var graph = dijit.byId('reschart').chart;
	graph.updateSeries('Main', data.points);
	graph.labeldata = data.points;
	graph.render();
}

function updateNewReservations(data) {
	var obj = dojo.byId('newreservations');
	var txt = '<table>';
	txt += '<tr>'
	    +  '<th>Start</th>'
	    +  '<th>ReqID</th>'
	    +  '<th>User</th>'
	    +  '<th>Computer</th>'
	    +  '<th>States</th>'
	    +  '<th>Image</th>'
	    +  '<th>Install Type</th>'
	    +  '<th>Management Node</th>'
	    +  '</tr>';
	for(var i = 0; i < data.length; i++) {
		if(i % 2)
			txt += '<tr style=\"background-color: #D8D8D8;\">';
		else
			txt += '<tr style=\"background-color: #EEEEEE;\">';
		txt += '<td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].start
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].id
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].user
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].computer
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].state
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].image
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].installtype
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].managementnode
		    + '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
}

function updateFailedImaging(data) {
	var obj = dojo.byId('failedimaging');
	var txt = '<table>';
	txt += '<tr>'
	    +  '<td></td>'
	    +  '<th>Start</th>'
	    +  '<th>ReqID</th>'
	    +  '<th>Computer</th>'
	    +  '<th>VM Host</th>'
	    +  '<th>Image</th>'
	    +  '<th>Owner</th>'
	    +  '<th>Management Node</th>'
	    +  '<th>Comments</th>'
	    +  '</tr>';
	for(var i = 0; i < data.length; i++) {
		if(i % 2)
			txt += '<tr style=\"background-color: #D8D8D8;\">';
		else
			txt += '<tr style=\"background-color: #EEEEEE;\">';
		txt += '<td style=\"padding: 1px; border-right: 1px solid;\">'
		    + '<button id=\"imgbtn' + data[i].id + '\" type=\"button\"></button>'
		    + '<input type=\"hidden\" id=\"iptimgbtn' + data[i].id + '\">'
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].start
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].id
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].computer
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].vmhost
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].image
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    //+ data[i].installtype
		    + data[i].owner
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].managementnode
		    + '</td><td style=\"padding: 1px; border-right: 1px solid;\">'
		    + data[i].revisioncomments
		    + '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
	for(var i = 0; i < data.length; i++) {
		var btnid = 'imgbtn' + data[i].id
		if(dijit.byId(btnid))
			dijit.byId(btnid).destroy(true);
		dojo.byId('ipt' + btnid).value = data[i].contid;
		var btn = new dijit.form.Button({
			label: "Restart Imaging",
			onClick: function() {
				var contid = dojo.byId('ipt' + this.id).value;
				RPCwrapper({continuation: contid}, restartImagingCB, 1);
			}
		}, btnid);
	}
}

function updateManagementNodes(data) {
	var obj = dojo.byId('managementnodes');
	var txt = '<table>';
	txt += '<tr>'
	    +  '<td></td>'
	    +  '<th>Time Since<br>Check-in</th>'
	    +  '<th>Reservations<br>Processing</th>'
	    +  '</tr>';
	for(var i = 0; i < data.length; i++) {
		txt += '<tr><th align="right">'
		if(data[i].stateid == 10)
			txt += '<span class=dashmnmaint>'
			    +  '[ ' + data[i].hostname
			    + ' ]</span></th><td>';
		else
			txt += data[i].hostname
			    + '</th><td>';
		if(data[i].checkin == null)
			txt += '<span>never'
		else if(data[i].checkin < 60)
			txt += '<span class="ready">'
			    + data[i].checkin
			    + ' second(s)';
		else if(data[i].checkin < 120)
			txt += '<span class="wait">'
			    + data[i].checkin
			    + ' seconds';
		else if(data[i].checkin < 86400) {
			txt += '<span class="rederrormsg">';
			if(data[i].checkin < 3600)
				txt += secToMin(data[i].checkin);
			else
				txt += secToHour(data[i].checkin);
		}
		else
			txt += '<span class="rederrormsg">&gt; 24 hours';
		txt += '</span></td><td>'
		    +  data[i].processing
		    +  '</td></tr>';
	}
	txt += '</table>';
	obj.innerHTML = txt;
}

function restartImagingCB(data, ioArgs) {
	if(data.items.status == 'noaccess') {
		alert('You do not have access to restart the imaging process for this reservation');
		return;
	}
	else if(data.items.status == 'wrongstate') {
		alert('The state of this reservation changed and is no longer valid for restarting the reservation');
		return;
	}
	clearTimeout(refreshtimer);
	updateDashboard();
}

function timestampToTime(val) {
	if(! dijit.byId('reschart').chart.labeldata)
		return '';
	else
		var data = dijit.byId('reschart').chart.labeldata;
	return data[val]['text'];
}

function secToMin(time) {
	var min = parseInt(time / 60);
	var sec = time - (min * 60);
	return dojox.string.sprintf('%d:%02d minute(s)', min, sec);
}

function secToHour(time) {
	var hour = parseInt(time / 3600);
	var min = parseInt((time - (hour * 3600)) / 60);
	return dojox.string.sprintf('%d:%02d hour(s)', hour, min);
}
