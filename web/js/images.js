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
var allimages = '';
var allgroups = '';
var allcompgroups = '';
var allimggroups = '';

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
	for each imageid sent back we
		search through allimages until we find it keeping track of the previous item with inout == 1
		we set allimages[imageid].inout to 1
		we find the previous item in the select.options array
		we insert a new option right after that one
	*/
	var images = data.items.images;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	if(addrem)
		var obj = document.getElementById('inimages');
	else
		var obj = document.getElementById('outimages');
	for(var i = 0; i < images.length; i++) {
		var lastid = -1;
		for(var j = 0; j < allimages.length; j++) {
			if(allimages[j].id == images[i]) {
				if(addrem == 1)
					allimages[j].inout = 1;
				else
					allimages[j].inout = 0;
				if(lastid < 0) {
					var before = obj.options[0];
					var newoption = new Option(allimages[j].name, allimages[j].id);
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
							var newoption = new Option(allimages[j].name, allimages[j].id);
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
			if(allimages[j].inout == addrem)
				lastid = allimages[j].id;
		}
	}
	document.body.style.cursor = 'default';
}

function addRemImage2(data, ioArgs) {
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

function addRemCompGrpImgGrp(data, ioArgs) {
	var groups = data.items.groups;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	if(addrem)
		var obj = document.getElementById('incompgroups');
	else
		var obj = document.getElementById('outcompgroups');
	for(var i = 0; i < groups.length; i++) {
		var lastid = -1;
		for(var j = 0; j < allcompgroups.length; j++) {
			if(allcompgroups[j].id == groups[i]) {
				if(addrem == 1)
					allcompgroups[j].inout = 1;
				else
					allcompgroups[j].inout = 0;
				if(lastid < 0) {
					var before = obj.options[0];
					var newoption = new Option(allcompgroups[j].name, allcompgroups[j].id);
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
							var newoption = new Option(allcompgroups[j].name, allcompgroups[j].id);
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
			if(allcompgroups[j].inout == addrem) {
				lastid = allcompgroups[j].id;
			}
		}
	}
	document.body.style.cursor = 'default';
}

function addRemImgGrpCompGrp(data, ioArgs) {
	var groups = data.items.groups;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	if(addrem)
		var obj = document.getElementById('inimggroups');
	else
		var obj = document.getElementById('outimggroups');
	for(var i = 0; i < groups.length; i++) {
		var lastid = -1;
		for(var j = 0; j < allimggroups.length; j++) {
			if(allimggroups[j].id == groups[i]) {
				if(addrem == 1)
					allimggroups[j].inout = 1;
				else
					allimggroups[j].inout = 0;
				if(lastid < 0) {
					var before = obj.options[0];
					var newoption = new Option(allimggroups[j].name, allimggroups[j].id);
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
							var newoption = new Option(allimggroups[j].name, allimggroups[j].id);
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
			if(allimggroups[j].inout == addrem) {
				lastid = allimggroups[j].id;
			}
		}
	}
	document.body.style.cursor = 'default';
}

function getImagesButton() {
   document.body.style.cursor = 'wait';
	var selobj1 = document.getElementById('inimages');
	for(var i = selobj1.options.length - 1; i >= 0; i--) {
		selobj1.remove(i);
	}
	var selobj2 = document.getElementById('outimages');
	for(i = selobj2.options.length - 1; i >= 0; i--) {
		selobj2.remove(i);
	}
	var obj = document.getElementById('imgGroups');
	var groupid = obj.options[obj.selectedIndex].value;
	var groupname = obj.options[obj.selectedIndex].text;

	obj = document.getElementById('ingroupname').innerHTML = groupname;
	obj = document.getElementById('outgroupname').innerHTML = groupname;

	obj = document.getElementById('imgcont');

	dojo.xhrPost({
		url: 'index.php',
		handleAs: "json-comment-filtered",
		load: imagesCallback,
		error: errorHandler,
		content: {continuation: obj.value,
					 groupid: groupid},
		timeout: 15000
	});
}

function imagesCallback(data, ioArgs) {
	var inobj = document.getElementById('inimages');
	for(var i = 0; i < data.items.inimages.length; i++) {
		inobj.options[inobj.options.length] = new Option(data.items.inimages[i].name, data.items.inimages[i].id);
	}
	var outobj = document.getElementById('outimages');
	for(var i = 0; i < data.items.outimages.length; i++) {
		outobj.options[outobj.options.length] = new Option(data.items.outimages[i].name, data.items.outimages[i].id);
	}
	allimages = data.items.all;
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
	var obj = document.getElementById('images');
	var imageid = obj.options[obj.selectedIndex].value;
	var imagename = obj.options[obj.selectedIndex].text;

	obj = document.getElementById('inimagename').innerHTML = imagename;
	obj = document.getElementById('outimagename').innerHTML = imagename;

	obj = document.getElementById('grpcont');

	dojo.xhrPost({
		url: 'index.php',
		handleAs: "json-comment-filtered",
		load: groupsCallback,
		error: errorHandler,
		content: {continuation: obj.value,
					 imageid: imageid},
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

function getMapCompGroupsButton() {
   document.body.style.cursor = 'wait';
	var selobj1 = document.getElementById('incompgroups');
	for(var i = selobj1.options.length - 1; i >= 0; i--) {
		selobj1.remove(i);
	}
	var selobj2 = document.getElementById('outcompgroups');
	for(i = selobj2.options.length - 1; i >= 0; i--) {
		selobj2.remove(i);
	}
	var obj = document.getElementById('imagegrps');
	var imagegrpid = obj.options[obj.selectedIndex].value;
	var imagegrpname = obj.options[obj.selectedIndex].text;

	obj = document.getElementById('inimagegrpname').innerHTML = imagegrpname;
	obj = document.getElementById('outimagegrpname').innerHTML = imagegrpname;

	obj = document.getElementById('compcont');

	dojo.xhrPost({
		url: 'index.php',
		handleAs: "json-comment-filtered",
		load: mapCompGroupsCB,
		error: errorHandler,
		content: {continuation: obj.value,
					 imagegrpid: imagegrpid},
		timeout: 15000
	});
}

function mapCompGroupsCB(data, ioArgs) {
	var inobj = document.getElementById('incompgroups');
	for(var i = 0; i < data.items.ingroups.length; i++) {
		inobj.options[inobj.options.length] = new Option(data.items.ingroups[i].name, data.items.ingroups[i].id);
	}
	var outobj = document.getElementById('outcompgroups');
	for(var i = 0; i < data.items.outgroups.length; i++) {
		outobj.options[outobj.options.length] = new Option(data.items.outgroups[i].name, data.items.outgroups[i].id);
	}
	allcompgroups = data.items.all;
	document.body.style.cursor = 'default';
}

function getMapImgGroupsButton() {
   document.body.style.cursor = 'wait';
	var selobj1 = document.getElementById('inimggroups');
	for(var i = selobj1.options.length - 1; i >= 0; i--) {
		selobj1.remove(i);
	}
	var selobj2 = document.getElementById('outimggroups');
	for(i = selobj2.options.length - 1; i >= 0; i--) {
		selobj2.remove(i);
	}
	var obj = document.getElementById('compgroups');
	var compgrpid = obj.options[obj.selectedIndex].value;
	var compgrpname = obj.options[obj.selectedIndex].text;

	obj = document.getElementById('incompgroupname').innerHTML = compgrpname;
	obj = document.getElementById('outcompgroupname').innerHTML = compgrpname;

	obj = document.getElementById('imgcont');

	dojo.xhrPost({
		url: 'index.php',
		handleAs: "json-comment-filtered",
		load: mapImgGroupsCB,
		error: errorHandler,
		content: {continuation: obj.value,
					 compgrpid: compgrpid},
		timeout: 15000
	});
}

function mapImgGroupsCB(data, ioArgs) {
	var inobj = document.getElementById('inimggroups');
	for(var i = 0; i < data.items.ingroups.length; i++) {
		inobj.options[inobj.options.length] = new Option(data.items.ingroups[i].name, data.items.ingroups[i].id);
	}
	var outobj = document.getElementById('outimggroups');
	for(var i = 0; i < data.items.outgroups.length; i++) {
		outobj.options[outobj.options.length] = new Option(data.items.outgroups[i].name, data.items.outgroups[i].id);
	}
	allimggroups = data.items.all;
	document.body.style.cursor = 'default';
}

function generalCB(data, ioArgs) {
	document.body.style.cursor = 'default';
}

function updateRevisionProduction(cont) {
   document.body.style.cursor = 'wait';
	dojo.xhrPost({
		url: 'index.php',
		load: generalCB,
		error: errorHandler,
		content: {continuation: cont},
		timeout: 15000
	});
}

function updateRevisionComments(id, cont) {
   document.body.style.cursor = 'wait';
	var comments = dijit.byId(id).value;
	dojo.xhrPost({
		url: 'index.php',
		handleAs: "json-comment-filtered",
		load: updateRevisionCommentsCB,
		error: errorHandler,
		content: {continuation: cont,
					 comments: comments},
		timeout: 15000
	});
}

function updateRevisionCommentsCB(data, ioArgs) {
	var obj = dijit.byId('comments' + data.items.id);
	obj.setValue(data.items.comments);
	document.body.style.cursor = 'default';
}

function deleteRevisions(cont, idlist) {
	var ids = idlist.split(',');
	var checkedids = new Array();
	for(var i = 0; i < ids.length; i++) {
		var id = ids[i];
		var obj = document.getElementById('chkrev' + id);
		var obj2 = document.getElementById('radrev' + id);
		if(obj.checked) {
			if(obj2.checked) {
				alert('You cannot delete the production revision.');
				return;
			}
			checkedids.push(id);
		}
	}
	if(checkedids.length == 0)
		return;
	checkedids = checkedids.join(',');
	dojo.xhrPost({
		url: 'index.php',
		handleAs: "json-comment-filtered",
		load: deleteRevisionsCB,
		error: errorHandler,
		content: {continuation: cont,
					 checkedids: checkedids},
		timeout: 15000
	});
}

function deleteRevisionsCB(data, ioArgs) {
	var obj = document.getElementById('revisiondiv');
	obj.innerHTML = data.items.html;
}
