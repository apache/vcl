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
	var data = {continuation: cont,
	            listids: listids,
	            id: id};
	RPCwrapper(data, cb, 1);
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

	var data = {continuation: obj.value,
	            groupid: groupid};
	RPCwrapper(data, imagesCallback, 1);
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

	var data = {continuation: obj.value,
	            imageid: imageid};
	RPCwrapper(data, groupsCallback, 1);
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

	var data = {continuation: obj.value,
	            imagegrpid: imagegrpid};
	RPCwrapper(data, mapCompGroupsCB, 1);
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

	var data = {continuation: obj.value,
	            compgrpid: compgrpid};
	RPCwrapper(data, mapImgGroupsCB, 1);
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
	RPCwrapper({continuation: cont}, generalCB);
}

function updateRevisionComments(id, cont) {
   document.body.style.cursor = 'wait';
	var data = {continuation: obj.value,
	            comments: dijit.byId(id).value};
	RPCwrapper(data, updateRevisionCommentsCB, 1);
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
	var data = {continuation: cont,
	            checkedids: checkedids};
	RPCwrapper(data, deleteRevisionsCB, 1);
}

function deleteRevisionsCB(data, ioArgs) {
	var obj = document.getElementById('revisiondiv');
	obj.innerHTML = data.items.html;
}

function addSubimage() {
	dijit.byId('addbtn').attr('label', 'Working...');
	var data = {continuation: dojo.byId('addsubimagecont').value,
	            imageid: dijit.byId('addsubimagesel').value};
	RPCwrapper(data, addSubimageCB, 1);
}

function addSubimageCB(data, ioArgs) {
	if(data.items.error) {
		dijit.byId('addbtn').attr('label', 'Add Subimage');
		alert(data.items.msg);
		return;
	}
	var obj = dojo.byId('cursubimagesel');
	if(obj.options[0].text == '(None)') {
		obj.disabled = false;
		obj.remove(0);
	}
	dojo.byId('addsubimagecont').value = data.items.addcont;
	dojo.byId('remsubimagecont').value = data.items.remcont;
	var index = obj.options.length;
	obj.options[index] = new Option(data.items.name, data.items.newid, false, false);
	sortSelect(obj);
	dojo.byId('subimgcnt').innerHTML = obj.options.length;
	dijit.byId('addbtn').attr('label', 'Add Subimage');
}

function remSubimages() {
	var obj = dojo.byId('cursubimagesel');
	var imgids = new Array();
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected)
			imgids.push(obj.options[i].value);
	}
	if(! imgids.length)
		return;
	var ids = imgids.join(',');
	dijit.byId('rembtn').attr('label', 'Working...');
	var data = {continuation: dojo.byId('remsubimagecont').value,
	            imageids: ids};
	RPCwrapper(data, remSubimagesCB, 1);
}

function remSubimagesCB(data, ioArgs) {
	if(data.items.error) {
		dijit.byId('rembtn').attr('label', 'Remove Selected Subimage(s)');
		alert(data.items.msg);
		return;
	}
	var obj = dojo.byId('cursubimagesel');
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected)
			obj.remove(i);
	}
	if(! obj.options.length) {
		obj.disabled = true;
		obj.options[0] = new Option('(None)', 'none', false, false);
		dojo.byId('subimgcnt').innerHTML = 0;
	}
	else
		dojo.byId('subimgcnt').innerHTML = obj.options.length;
	dojo.byId('addsubimagecont').value = data.items.addcont;
	dojo.byId('remsubimagecont').value = data.items.remcont;
	dijit.byId('rembtn').attr('label', 'Remove Selected Subimage(s)');
}

function updateCurrentConMethods() {
	var tmp = dijit.byId('addcmsel').get('value');
	if(tmp == '') {
		dijit.byId('addcmsel').set('disabled', true);
		dijit.byId('addcmbtn').set('disabled', true);
	}
	else {
		dijit.byId('addcmsel').set('disabled', false);
		dijit.byId('addcmbtn').set('disabled', false);
	}
	// update list of current methods
	var obj = dojo.byId('curmethodsel');
	for(var i = obj.options.length - 1; i >= 0; i--)
		obj.remove(i);
	cmstore.fetch({
		query: {active: 1},
		onItem: function(item) {
			var obj = dojo.byId('curmethodsel').options;
			obj[obj.length] = new Option(item.display[0], item.name[0], false, false);
		},
		onComplete: function() {
			sortSelect(dojo.byId('curmethodsel'));
			updateConnectionMethodList();
		}
	});
}

function selectConMethodRevision(url) {
	var revid = dijit.byId('conmethodrevid').get('value');
	dijit.byId('addcmsel').set('disabled', true);
	dijit.byId('addcmbtn').set('disabled', true);
	var oldstore = cmstore;
	cmstore = new dojo.data.ItemFileWriteStore({url: url + '&revid=' + revid});
	dijit.byId('addcmsel').setStore(cmstore, '', {query: {active: 0}});
}

function addConnectMethod() {
	cmstore.fetch({
		query: {name: dijit.byId('addcmsel').value},
		onItem: addConnectMethod2
	});
}

function addConnectMethod2(item) {
	if(cmstore.getValue(item, 'autoprovisioned') == 0) {
		dojo.byId('autoconfirmcontent').innerHTML = cmstore.getValue(item, 'display');
		dijit.byId('autoconfirmdlg').show();
		return;
	}
	addConnectMethod3();
}

function addConnectMethod3() {
	dojo.byId('cmerror').innerHTML = '';
	dijit.byId('addcmbtn').attr('label', 'Working...');
	var data = {continuation: dojo.byId('addcmcont').value,
	            newid: dijit.byId('addcmsel').value};
	if(dijit.byId('conmethodrevid'))
		data.revid = dijit.byId('conmethodrevid').get('value');
	else
		data.revid = 0;
	RPCwrapper(data, addConnectMethodCB, 1);
}

function addConnectMethodCB(data, ioArgs) {
	if(data.items.error) {
		dijit.byId('addcmbtn').attr('label', 'Add Method');
		alert(data.items.msg);
		return;
	}
	cmstore.fetch({
		query: {name: data.items.newid},
		onItem: function(item) {
			cmstore.setValue(item, 'active', 1);
		}
	});
	dijit.byId('addcmsel').setStore(cmstore, '', {query: {active: 0}});
	dojo.byId('addcmcont').value = data.items.addcont;
	dojo.byId('remcmcont').value = data.items.remcont;
	dijit.byId('addcmbtn').attr('label', 'Add Method');
}

function remConnectMethod() {
	var obj = dojo.byId('curmethodsel');
	var cmids = new Array();
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected)
			cmids.push(obj.options[i].value);
	}
	if(! cmids.length)
		return;
	if(cmids.length == obj.options.length) {
		dojo.byId('cmerror').innerHTML = 'There must be at least one item in Current Methods';
		setTimeout(function() {dojo.byId('cmerror').innerHTML = '';}, 20000);
		return;
	}
	var ids = cmids.join(',');
	dijit.byId('remcmbtn').attr('label', 'Working...');
	var data = {continuation: dojo.byId('remcmcont').value,
	            ids: ids};
	if(dijit.byId('conmethodrevid'))
		data.revid = dijit.byId('conmethodrevid').get('value');
	else
		data.revid = 0;
	RPCwrapper(data, remConnectMethodCB, 1);
}

function remConnectMethodCB(data, ioArgs) {
	if(dijit.byId('addcmsel').get('disabled')) {
		dijit.byId('addcmsel').set('disabled', false);
		dijit.byId('addcmbtn').set('disabled', false);
	}
	if(data.items.error) {
		dijit.byId('rembtn').attr('label', 'Remove Selected Methods');
		alert(data.items.msg);
		return;
	}
	var obj = dojo.byId('curmethodsel');
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected) {
			cmstore.fetch({
				query: {name: obj.options[i].value},
				onItem: function(item) {
					cmstore.setValue(item, 'active', 0);
				}
			});
			obj.remove(i);
		}
	}
	dijit.byId('addcmsel').setStore(cmstore, '', {query: {active: 0}});
	dojo.byId('addcmcont').value = data.items.addcont;
	dojo.byId('remcmcont').value = data.items.remcont;
	updateConnectionMethodList();
	dijit.byId('remcmbtn').attr('label', 'Remove Selected Methods');
}

function updateConnectionMethodList() {
	var options = dojo.byId('curmethodsel').options;
	var items = new Array();
	var ids = new Array();
	for(var i = 0; i < options.length; i++) {
		items.push(options[i].text);
		ids.push(options[i].value);
	}
	dojo.byId('connectmethodlist').innerHTML = items.join('<br>');
	if(dojo.byId('connectmethodids'))
		dojo.byId('connectmethodids').value = ids.join(',');
}
