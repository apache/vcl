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

function generateGraphs() {
	var cont = dojo.byId('statdaycont').value;
	RPCwrapper({continuation: cont}, generateColGraphsCB, 1, 300000);
	var cont = dojo.byId('statreshourcont').value;
	RPCwrapper({continuation: cont}, generateHourGraphsCB, 1, 300000);
	if(dojo.byId('statconcurrescont')) {
		var cont = dojo.byId('statconcurrescont').value;
		RPCwrapper({continuation: cont}, generateColGraphsCB, 1, 300000);
	}
	if(dojo.byId('statconcurbladecont')) {
		var cont = dojo.byId('statconcurbladecont').value;
		RPCwrapper({continuation: cont}, generateColGraphsCB, 1, 300000);
	}
	if(dojo.byId('statconcurvmcont')) {
		var cont = dojo.byId('statconcurvmcont').value;
		RPCwrapper({continuation: cont}, generateColGraphsCB, 1, 300000);
	}
}

function generateColGraphsCB(data, ioArgs) {
	if(data.items.nodata) {
		dojo.byId(data.items.id).innerHTML = data.items.nodata;
		dojo.removeClass(data.items.id, 'statgraph');
		return;
	}
	dojo.byId(data.items.id).innerHTML = '';
	var graph = new dojox.charting.Chart2D(data.items.id);
	if(data.items.maxy <= 50)
		var majortick = 10;
	else if(data.items.maxy <= 200)
		var majortick = 25;
	else if(data.items.maxy <= 400)
		var majortick = 50;
	else if(data.items.maxy <= 600)
		var majortick = 100;
	else if(data.items.maxy <= 1000)
		var majortick = 200;
	else {
		var majortick = data.items.maxy / 10;
		majortick = (majortick - (majortick % 200)) || 200;
	}
	graph.setTheme(dojox.charting.themes.ThreeD);
	if(data.items.points.length < 10)
		var gap = 6;
	else if(data.items.points.length < 20)
		var gap = 3;
	else if(data.items.points.length < 50)
		var gap = 2;
	else
		var gap = 0;
	var xtickstep = parseInt(data.items.xlabels.length / 10) || 1;
	graph.addAxis("x", {
		includeZero: false,
		labels: data.items.xlabels,
		rotation: -90,
		minorTicks: false,
		font: 'normal normal normal 11px verdana',
		majorTickStep: xtickstep
	});
	graph.addAxis('y', {
		vertical: true,
		fixUpper: "major",
		includeZero: true,
		minorTicks: true,
		minorLabels: false,
		majorTickStep: majortick,
		minorTickStep: majortick / 2
	});
	graph.addPlot('default', {type: "Columns", gap: gap});
	graph.addPlot('Grid', {type: 'Grid', hMajorLines: true, vMajorLines: false});
	graph.addSeries("Main", data.items.points, {stroke: {width: 1}});
	var a = new dojox.charting.action2d.Tooltip(graph);
	graph.render();
}

function generateHourGraphsCB(data, ioArgs) {
	dojo.byId(data.items.id).innerHTML = '';
	var graph = new dojox.charting.Chart2D(data.items.id);
	if(data.items.maxy <= 50)
		var majortick = 5;
	else if(data.items.maxy <= 100)
		var majortick = 10;
	else if(data.items.maxy <= 200)
		var majortick = 20;
	else {
		var majortick = data.items.maxy / 10;
		majortick = (majortick - (majortick % 100)) || 100;
	}
	graph.setTheme(dojox.charting.themes.ThreeD);
	graph.addAxis("x", {
		includeZero: true,
		labels: data.items.points,
		rotation: -90,
		minorTicks: false,
		font: 'normal normal normal 11px verdana',
		majorTickStep: 2
	});
	graph.addAxis('y', {
		vertical: true,
		fixUpper: "major",
		includeZero: true,
		minorTicks: true,
		minorLabels: false,
		majorTickStep: majortick,
		minorTickStep: majortick / 5
	});
	graph.addPlot('default', {markers: true});
	graph.addPlot('Grid', {type: 'Grid', hMajorLines: true, vMajorLines: false});
	graph.addSeries("Main", data.items.points);
	var a = new dojox.charting.action2d.Tooltip(graph);
	var a = new dojox.charting.action2d.Magnify(graph);
	graph.render();
}
