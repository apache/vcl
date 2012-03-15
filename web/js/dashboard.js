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
	setTimeout(updateDashboard, 15000);
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

function timestampToTime(val) {
	if(! dijit.byId('reschart').chart.labeldata)
		return '';
	else
		var data = dijit.byId('reschart').chart.labeldata;
	return data[val]['text'];
}
