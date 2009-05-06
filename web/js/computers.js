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
var allcomps = '';
var allgroups = '';
var allcompgroups = '';

function addRemItem(cont, objid1, objid2, cb) {
   document.body.style.cursor = 'wait';
	var obj = document.getElementById(objid1);
	var id = obj.options[obj.selectedIndex].value;

	obj = document.getElementById(objid2);
	var listids = "";
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected) {
			listids = listids + ',' + obj.options[i].value;
			obj.remove(i);
		}
	}
	if(listids == "")
		return;
	dojo.xhrPost({
		url: 'index.php',
		load: cb,
		handleAs: "json-comment-filtered",
		error: errorHandler,
		content: {continuation: cont,
					 listids: listids,
					 id: id},
		timeout: 15000
	});
}

function addRemGroup2(data, ioArgs) {
	/*
	for each compid sent back we
		search through allcomps until we find it keeping track of the previous item with inout == 1
		we set allcomps[compid].inout to 1
		we find the previous item in the select.options array
		we insert a new option right after that one
	*/
	var comps = data.items.comps;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	if(addrem)
		var obj = document.getElementById('incomps');
	else
		var obj = document.getElementById('outcomps');
	for(var i = 0; i < comps.length; i++) {
		var lastid = -1;
		for(var j = 0; j < allcomps.length; j++) {
			if(allcomps[j].id == comps[i]) {
				if(addrem == 1)
					allcomps[j].inout = 1;
				else
					allcomps[j].inout = 0;
				if(lastid < 0) {
					var before = obj.options[0];
					var newoption = new Option(allcomps[j].name, allcomps[j].id);
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
							var newoption = new Option(allcomps[j].name, allcomps[j].id);
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
			if(allcomps[j].inout == addrem)
				lastid = allcomps[j].id;
		}
	}
	document.body.style.cursor = 'default';
}

function addRemComp2(data, ioArgs) {
	var groups = data.items.groups;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	if(addrem)
		var obj = document.getElementById('ingroups');
	else
		var obj = document.getElementById('outgroups');
	for(var i = 0; i < groups.length; i++) {
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
	document.body.style.cursor = 'default';
}

function getCompsButton() {
   document.body.style.cursor = 'wait';
	var selobj1 = document.getElementById('incomps');
	for(var i = selobj1.options.length - 1; i >= 0; i--) {
		selobj1.remove(i);
	}
	var selobj2 = document.getElementById('outcomps');
	for(i = selobj2.options.length - 1; i >= 0; i--) {
		selobj2.remove(i);
	}
	var obj = document.getElementById('compGroups');
	var groupid = obj.options[obj.selectedIndex].value;
	var groupname = obj.options[obj.selectedIndex].text;

	obj = document.getElementById('ingroupname').innerHTML = groupname;
	obj = document.getElementById('outgroupname').innerHTML = groupname;

	obj = document.getElementById('compcont');

	dojo.xhrPost({
		url: 'index.php',
		handleAs: "json-comment-filtered",
		load: compsCallback,
		error: errorHandler,
		content: {continuation: obj.value,
					 groupid: groupid},
		timeout: 15000
	});
}

function compsCallback(data, ioArgs) {
	var inobj = document.getElementById('incomps');
	for(var i = 0; i < data.items.incomps.length; i++) {
		inobj.options[inobj.options.length] = new Option(data.items.incomps[i].name, data.items.incomps[i].id);
	}
	var outobj = document.getElementById('outcomps');
	for(var i = 0; i < data.items.outcomps.length; i++) {
		outobj.options[outobj.options.length] = new Option(data.items.outcomps[i].name, data.items.outcomps[i].id);
	}
	allcomps = data.items.all;
	document.body.style.cursor = 'default';
}

function getGroupsButton() {
   document.body.style.cursor = 'wait';
	var selobj1 = document.getElementById('ingroups');
	for(var i = selobj1.options.length - 1; i >= 0; i--) {
		selobj1.remove(i);
	}
	var selobj2 = document.getElementById('outgroups');
	for(i = selobj2.options.length - 1; i >= 0; i--) {
		selobj2.remove(i);
	}
	var obj = document.getElementById('comps');
	var compid = obj.options[obj.selectedIndex].value;
	var compname = obj.options[obj.selectedIndex].text;

	obj = document.getElementById('incompname').innerHTML = compname;
	obj = document.getElementById('outcompname').innerHTML = compname;

	obj = document.getElementById('grpcont');

	dojo.xhrPost({
		url: 'index.php',
		handleAs: "json-comment-filtered",
		load: groupsCallback,
		error: errorHandler,
		content: {continuation: obj.value,
					 compid: compid},
		timeout: 15000
	});
}

function groupsCallback(data, ioArgs) {
	var inobj = document.getElementById('ingroups');
	for(var i = 0; i < data.items.ingroups.length; i++) {
		inobj.options[inobj.options.length] = new Option(data.items.ingroups[i].name, data.items.ingroups[i].id);
	}
	var outobj = document.getElementById('outgroups');
	for(var i = 0; i < data.items.outgroups.length; i++) {
		outobj.options[outobj.options.length] = new Option(data.items.outgroups[i].name, data.items.outgroups[i].id);
	}
	allgroups = data.items.all;
	document.body.style.cursor = 'default';
}
