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
var currvms = '';
var curprofileid = '';
var fromok = 0;
var allvms = '';
var curprofile = '';

function getVMHostData(cont) {
	var hostid = dojo.byId('vmhostid').value;
	document.body.style.cursor = 'wait';
	dijit.byId('messages').hide();
	dojo.byId('vmhostdata').className = 'hidden';
	dojo.byId('movevms').className = 'hidden';
	dojo.byId('vmstate').innerHTML = '';

	var selobj1 = dojo.byId('currvms');
	for(var i = selobj1.options.length - 1; i >= 0; i--) {
		selobj1.remove(i);
	}
	var selobj2 = dojo.byId('freevms');
	for(i = selobj2.options.length - 1; i >= 0; i--) {
		selobj2.remove(i);
	}
	var selobj3 = dojo.byId('movevmssel');
	for(i = selobj3.options.length - 1; i >= 0; i--) {
		selobj3.remove(i);
	}

	dojo.xhrPost({
		url: 'index.php',
		load: VMHostDataCB,
		handleAs: "json",
		error: errorHandler,
		content: {continuation: cont,
					 vmhostid: hostid},
		timeout: 15000
	});
}

function VMHostDataCB(data, ioArgs) {
	if(data.items.failed) {
		alert('You do not have access to manage this host.');
		document.body.style.cursor = 'default';
		return;
	}
	dojo.byId('vmhostdata').className = 'shown';

	curprofileid = data.items.profileid;

	// leave this block for allowing changing of profiles later
	/*var selobj = dojo.byId('vmprofileid');
	for(var i = 0; i < selobj.options.length; i++) {
		if(selobj.options[i].value == data.items.profile.id) {
			selobj.selectedIndex = i;
			break;
		}
	}*/
	var profile = data.items.profile;
	var obj = dijit.byId('vmprofile');
	obj.setTitle(profile.profilename);
	var ct = '<table>';
	ct += '<tr><th align=right>Image:</th><td>' + profile.image + '</td></tr>';
	ct += '<tr><th align=right>Resource Path:</th><td>' + profile.resourcepath + '</td></tr>';
	ct += '<tr><th align=right>Folder Path:</th><td>' + profile.folderpath + '</td></tr>';
	ct += '<tr><th align=right>Repository Path:</th><td>' + profile.repositorypath + '</td></tr>';
	ct += '<tr><th align=right>Repository Image Type:</th><td>' + profile.repositoryimagetype + '</td></tr>';
	ct += '<tr><th align=right>Virtual Disk Path:</th><td>' + profile.datastorepath + '</td></tr>';
	ct += '<tr><th align=right>Virtual Disk Image Type:</th><td>' + profile.datastoreimagetype + '</td></tr>';
	ct += '<tr><th align=right>Virtual Disk Mode:</th><td>' + profile.vmdisk + '</td></tr>';
	ct += '<tr><th align=right>VM Working Directory Path:</th><td>' + profile.vmpath + '</td>';
	ct += '<tr><th align=right>VM Network 0:</th><td>' + profile.virtualswitch0 + '</td></tr>';
	ct += '<tr><th align=right>VM Network 1:</th><td>' + profile.virtualswitch1 + '</td></tr>';
	ct += '<tr><th align=right>VM Network 2:</th><td>' + profile.virtualswitch2 + '</td></tr>';
	ct += '<tr><th align=right>VM Network 3:</th><td>' + profile.virtualswitch3 + '</td></tr>';
	ct += '</table>';
	ct += '</table>';
	ct += '</table>';
	obj.setContent(ct);
	if(obj.open)
		obj.toggle();

	allvms = data.items.allvms;
	currvms = data.items.currvms;

	var inobj = dojo.byId('currvms');
	for(var i = 0; i < data.items.currvms.length; i++) {
		inobj.options[inobj.options.length] = new Option(data.items.currvms[i].name, data.items.currvms[i].id);
	}
	dojo.byId('assignedcnt').innerHTML = dojo.byId('currvms').options.length;
	var outobj = dojo.byId('freevms');
	for(var i = 0; i < data.items.freevms.length; i++) {
		outobj.options[outobj.options.length] = new Option(data.items.freevms[i].name, data.items.freevms[i].id);
	}
	if(data.items.noaccess.length) {
		dojo.removeClass('noaccessdiv', 'hidden');
		var tmp = new Array();
		for(var i = 0; i < data.items.noaccess.length; i++) {
			tmp.push(data.items.noaccess[i].name);
		}
		dojo.byId('noaccess').innerHTML = tmp.join('<br>');
	}
	else {
		dojo.addClass('noaccessdiv', 'hidden');
		dojo.byId('noaccess').innerHTML = '';
	}

	if(data.items.movevms.length) {
		dojo.byId('movevms').className = 'shown';
		obj = dojo.byId('movevmssel');
		var movevms = data.items.movevms;
		for(var i = 0; i < movevms.length; i++) {
			var label = movevms[i]['hostname'] + ' (' + movevms[i]['time'] + ')';
			obj.options[obj.options.length] = new Option(label, data.items.movevms[i].id);
		}
	}

	//dojo.byId('changevmcont').value = data.items.continuation;

	document.body.style.cursor = 'default';
}

function showVMstate() {
	var selobj = dojo.byId('currvms');
	var cnt = 0;
	var state = '';
	for(var i = 0; i < selobj.options.length; i++) {
		if(selobj.options[i].selected) {
			cnt++;
			state = currvms[i].state;
		}
	}
	if(cnt == 1)
		dojo.byId('vmstate').innerHTML = state;
	else
		dojo.byId('vmstate').innerHTML = '';
}

function vmToHost(cont) {
	document.body.style.cursor = 'wait';
	var hostid = dojo.byId('vmhostid').value;

	var obj = dojo.byId('freevms');
	var listids = new Array();
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected) {
			listids.push(obj.options[i].value);
		}
	}

	if(listids.length == 0) {
		document.body.style.cursor = 'default';
		return;
	}

	dojo.xhrPost({
		url: 'index.php',
		load: vmToHostCB,
		handleAs: "json",
		error: errorHandler,
		content: {continuation: cont,
					 listids: listids.join(','),
					 hostid: hostid},
		timeout: 15000
	});
}

function vmToHostCB(data, ioArgs) {
	if(data.items.failed) {
		if(data.items.failed == 'nohostaccess')
			alert('You do not have access to manage this VM host.');
		document.body.style.cursor = 'default';
		return;
	}
	/*
	for each vmid sent back we
		search through allvms until we find it keeping track of the previous item with inout == 1
		we set allvms[vmid].inout to 1
		we find the previous item in the select.options array
		we insert a new option right after that one
	*/
	var vms = data.items.vms;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	var fails = data.items.fails;
	var obj = dojo.byId('freevms');
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected) {
			var remove = 1;
			for(var j = 0; j < fails.length; j++) {
				if(obj.options[i].value == fails[j].id) {
					obj.options[i].selected = false;
					remove = 0;
					break;
				}
			}
			if(remove)
				obj.remove(i);
		}
	}
	var obj = dojo.byId('currvms');
	for(var i = 0; i < vms.length; i++) {
		var lastid = -1;
		for(var j = 0; j < allvms.length; j++) {
			if(allvms[j].id == vms[i].id) {
				allvms[j].inout = addrem;
				if(lastid < 0) {
					if(addrem)
						currvms.splice(0, 0, vms[i]);
					var before = obj.options[0];
					var newoption = new Option(allvms[j].name, allvms[j].id);
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
							if(addrem)
								currvms.splice(0, 0, vms[i]);
							var before = obj.options[k + 1];
							var newoption = new Option(allvms[j].name, allvms[j].id);
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
			if(allvms[j].inout == addrem)
				lastid = allvms[j].id;
		}
	}
	dojo.byId('assignedcnt').innerHTML = dojo.byId('currvms').options.length;
	document.body.style.cursor = 'default';
	if(fails.length) {
		var msg = '';
		var msg1 = 'There was a problem that prevented the following\n'
		         + 'VM(s) from being added to the host:\n\n';
		var msg2 = 'You do not have access to add the following vm(s):\n\n';
		var msg3 = ''; // problem
		var msg4 = ''; // no access
		for(var i = 0; i < fails.length; i++) {
			if(fails[i].reason == 'noaccess')
				msg4 += fails[i].name + '\n';
			else
				msg3 += fails[i].name + '\n';
		}
		if(msg3 != '')
			msg += msg1 + msg3 + '\n';
		if(msg4 != '')
			msg += msg2 + msg4 + '\n';
		alert(msg);
	}
}

function vmFromHost(cont) {
	document.body.style.cursor = 'wait';
	var hostid = dojo.byId('vmhostid').value;

	var obj = dojo.byId('currvms');
	var listids = new Array();
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected)
			listids.push(obj.options[i].value);
	}

	if(listids.length == 0) {
		document.body.style.cursor = 'default';
		return;
	}
	dojo.xhrPost({
		url: 'index.php',
		load: vmFromHostCB,
		handleAs: "json",
		error: errorHandler,
		content: {continuation: cont,
					 listids: listids.join(','),
					 hostid: hostid},
		timeout: 15000
	});
}

function vmFromHostCB(data, ioArgs) {
	if(data.items.failed) {
		alert('You do not have access to manage this VM host.');
		document.body.style.cursor = 'default';
		return;
	}
	/*
	for each vmid sent back we
		search through allvms until we find it keeping track of the previous item with inout == 1
		we set allvms[vmid].inout to 1
		we find the previous item in the select.options array
		we insert a new option right after that one
	*/
	var vms = data.items.vms;
	var addrem = data.items.addrem; // 1 for add, 0 for rem
	var checks = data.items.checks;
	var fails = data.items.fails;
	var obj = dojo.byId('currvms');
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected) {
			var remove = 1;
			for(var j = 0; j < checks.length; j++) {
				if(obj.options[i].value == checks[j].id) {
					obj.options[i].selected = false;
					remove = 0;
					break;
				}
			}
			for(var j = 0; j < fails.length; j++) {
				if(obj.options[i].value == fails[j].id) {
					obj.options[i].selected = false;
					remove = 0;
					break;
				}
			}
			if(remove) {
				obj.remove(i);
				dojo.byId('vmstate').innerHTML = '';
				currvms.splice(i, 1);
			}
		}
	}
	for(var i = 0; i < vms.length; i++) {
		for(var j = 0; j < allvms.length; j++) {
			if(allvms[j].id == vms[i].id) {
				allvms.splice(j, 1);
				break;
			}
		}
	}

	if(data.items.vms.length) {
		dojo.byId('movevms').className = 'shown';
		obj = dojo.byId('movevmssel');
		var vms = data.items.vms;
		for(var i = 0; i < vms.length; i++) {
			var label = vms[i]['hostname'] + ' (' + vms[i]['time'] + ')';
			obj.options[obj.options.length] = new Option(label, data.items.vms[i].reqid);
		}
	}

	if(fails.length) {
		var msg1 = '';
		var msg2 = '';
		for(var i = 0; i < fails.length; i++) {
			if(fails[i].reason == 'noaccess')
				msg1 += fails[i].name + '\n';
			else if(fails[i].reason == 'nomgtnode')
				msg2 += fails[i].name + '\n';
		}
		if(msg1.length)
			alert('You do not have access to remove the following vm(s):\n\n' + msg1);
		if(msg2.length)
			alert('The following vms could not be removed because no management node was available for them:\n\n' + msg2);
	}

	var checks = data.items.checks;
	if(checks.length) {
		var content = 'The following computer(s) have reservations on them that cannot be<br>'
		            + 'moved.  Click <strong>Move Later</strong> to move the computer(s) off of the host<br>'
		            + 'at the listed time(s) or click <strong>Cancel</strong> to leave the computer(s) on<br>'
		            + 'the host:<br><br>';
		for(var i = 0; i < checks.length; i++) {
			content += 'computer: ' + checks[i].hostname + '<br>';
			content += 'free at: ' + checks[i].end + '<br><br>';
		}
		var func = function() {vmFromHostDelayed(data.items.cont);};
		setMessageWindow('Delayed Move', 'Move Later', content, func);
	}
	dojo.byId('assignedcnt').innerHTML = dojo.byId('currvms').options.length;
	document.body.style.cursor = 'default';
}

function vmFromHostDelayed(cont) {
	dojo.xhrPost({
		url: 'index.php',
		load: reloadVMhostCB,
		handleAs: "json",
		error: errorHandler,
		content: {continuation: cont},
		timeout: 15000
	});
}

function reloadVMhostCB(data, ioArgs) {
	if(data.items.failed) {
		alert('You do not have access to manage this VM host.');
		document.body.style.cursor = 'default';
		return;
	}
	if(data.items.fails.length) {
		var msg1 = '';
		var msg2 = '';
		for(var i = 0; i < data.items.fails.length; i++) {
			if(data.items.fails[i].reason == 'noaccess')
				msg1 += data.items.fails[i].name + '\n';
			else if(data.items.fails[i].reason == 'nomgtnode')
				msg2 += data.items.fails[i].name + '\n';
		}
		if(msg1.length)
			alert('You do not have access to remove the following vm(s):\n\n' + msg1);
		if(msg2.length)
			alert('No management node was available to move the following VMs off of this host; therefore, nothing will be done at this time:\n\n' + msg2);
	}
	if(data.items.msg == 'SUCCESS')
		getVMHostData(data.items.cont);
	else
		document.body.style.cursor = 'default';
}

function setMessageWindow(title, okbtntext, content, submitFunc) {
	obj = dijit.byId('messages');
	obj.titleNode.innerHTML = title;
	dojo.byId('messagestext').innerHTML = content;
	dojo.byId('messagesokbtn').innerHTML = okbtntext;
	dojo.byId('messagesokbtn').onclick = submitFunc;
	obj.show();
}

function cancelVMmove(cont) {
	document.body.style.cursor = 'wait';
	var hostid = dojo.byId('vmhostid').value;

	var obj = dojo.byId('movevmssel');
	var listids = new Array();
	for(var i = obj.options.length - 1; i >= 0; i--) {
		if(obj.options[i].selected)
			listids.push(obj.options[i].value);
	}

	if(listids.length == 0) {
		document.body.style.cursor = 'default';
		return;
	}
	dojo.xhrPost({
		url: 'index.php',
		load: reloadVMhostCB,
		handleAs: "json",
		error: errorHandler,
		content: {continuation: cont,
					 listids: listids.join(','),
					 hostid: hostid},
		timeout: 15000
	});
}

function getVMprofileData(cont) {
	document.body.style.cursor = 'wait';
	dojo.byId('vmprofiledata').className = 'hidden';
	var profileid = dojo.byId('profileid').value;

	dojo.xhrPost({
		url: 'index.php',
		load: getVMprofileDataCB,
		handleAs: "json",
		error: errorHandler,
		content: {continuation: cont,
					 profileid: profileid},
		timeout: 15000
	});
}

function getVMprofileDataCB(data, ioArgs) {
	if(data.items.failed) {
		alert('You do not have access to manage this vm profile.');
		document.body.style.cursor = 'default';
		return;
	}
	curprofile = data.items.profile;

	var obj = dijit.byId('pimage');
	var store = new dojo.data.ItemFileReadStore({data: data.items.images});
	obj.store = store;
	if(curprofile.imageid != 0)
		obj.setValue(curprofile.imageid);

	var obj = dijit.byId('pvmdisk');
	var store = new dojo.data.ItemFileReadStore({data: data.items.vmdisk});
	obj.store = store;
	if(curprofile.vmdisk != 0)
		obj.setValue(curprofile.vmdisk);

	dijit.byId('pname').noValueIndicator = '(empty)';
	dijit.byId('presourcepath').noValueIndicator = '(empty)';
	dijit.byId('pfolderpath').noValueIndicator = '(empty)';
	dijit.byId('prepositorypath').noValueIndicator = '(empty)';
	dijit.byId('pdspath').noValueIndicator = '(empty)';
	dijit.byId('pvmpath').noValueIndicator = '(empty)';
	dijit.byId('pvs0').noValueIndicator = '(empty)';
	dijit.byId('pvs1').noValueIndicator = '(empty)';
	dijit.byId('pvs2').noValueIndicator = '(empty)';
	dijit.byId('pvs3').noValueIndicator = '(empty)';
	dijit.byId('pusername').noValueIndicator = '(empty)';

	dijit.byId('pname').setValue(curprofile.profilename);
	dijit.byId('presourcepath').setValue(curprofile.resourcepath);
	dijit.byId('pfolderpath').setValue(curprofile.folderpath);
	dijit.byId('prepositorypath').setValue(curprofile.repositorypath);
	dijit.byId('prepositoryimgtype').setValue(curprofile.repositoryimagetypeid);
	dijit.byId('pdspath').setValue(curprofile.datastorepath);
	dijit.byId('pdatastoreimgtype').setValue(curprofile.datastoreimagetypeid);
	dijit.byId('pvmpath').setValue(curprofile.vmpath);
	dijit.byId('pvs0').setValue(curprofile.virtualswitch0);
	dijit.byId('pvs1').setValue(curprofile.virtualswitch1);
	dijit.byId('pvs2').setValue(curprofile.virtualswitch2);
	dijit.byId('pvs3').setValue(curprofile.virtualswitch3);
	dijit.byId('pusername').setValue(curprofile.username);
	dijit.byId('pgenmac0').setValue(curprofile.eth0generated);
	dijit.byId('pgenmac1').setValue(curprofile.eth1generated);
	if(curprofile.pwdlength == 0) {
		dojo.byId('ppassword').value = '';
		dojo.byId('ppwdconfirm').value = '';
	}
	else {
		dojo.byId('ppassword').value = '********';
		dojo.byId('ppwdconfirm').value = 'xxxxxxxx';
	}
	dojo.byId('ppwdmatch').innerHTML = '';
	dojo.byId('vmprofiledata').className = 'shown';
	document.body.style.cursor = 'default';
}

function newProfile(cont) {
	var title = 'Create New Profile';
	var btn = 'Create Profile';
	var content = 'Enter name of new profile:<br>'
	            + '<input type=text id=newprofile><br>'
	            + '<font color=red><em><span id=nperrormsg></span></em></font><br>';
	var func = function() {
		var newname = dojo.byId('newprofile').value;
		var regex = new RegExp('^[-A-Za-z0-9:\(\)# ]{3,56}$');
		if(! newname.match(regex)) {
			alert('Name must be between 3 and 56 characters\nand can only include letters, numbers,\nspaces, and these characters -:()#');
			return;
		}
		document.body.style.cursor = 'wait';
		dojo.xhrPost({
			url: 'index.php',
			load: newProfileCB,
			handleAs: "json",
			error: errorHandler,
			content: {continuation: cont,
						 newname: newname},
			timeout: 15000
		});
	};
	setMessageWindow(title, btn, content, func);
}

function newProfileCB(data, ioArgs) {
	if(data.items.failed) {
		document.body.style.cursor = 'default';
		dojo.byId('nperrormsg').innerHTML =
		   'A profile with this name already exists';
		return;
	}
	dijit.byId('messages').hide();
	alert('Be sure to finish configuring this profile');
	var obj = dojo.byId('profileid');
	obj.options[obj.options.length] = new Option(data.items.profile.profilename, data.items.profile.id);
	obj.options[obj.options.length - 1].selected = true;
	dojo.removeClass('selectprofilediv', 'hidden');
	// TODO insert new entry in correct order
	getVMprofileDataCB(data, ioArgs);
}

function delProfile(cont) {
	var title = 'Delete Profile';
	var btn = 'Delete Profile';
	var content = "Delete the following profile?<br>";
	content += "<table summary=\"\">";
	content += "<tr>";
	content += "<th align=right>Name:</th>";
	content += "<td>" + curprofile.profilename + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Image:</th>";
	content += "<td>" + curprofile.image + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Resource Path:</th>";
	content += "<td>" + curprofile.resourcepath + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Folder Path:</th>";
	content += "<td>" + curprofile.folderpath + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Repository Path:</th>";
	content += "<td>" + curprofile.repositorypath + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Repository Image Type:</th>";
	content += "<td>" + curprofile.repositoryimagetype + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Virtual Disk Path:</th>";
	content += "<td>" + curprofile.datastorepath + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Virtual Disk Image Type:</th>";
	content += "<td>" + curprofile.datastoreimagetype + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Virtual Disk Mode:</th>";
	content += "<td>" + curprofile.vmdisk + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>VM Working Directory Path:</th>";
	content += "<td>" + curprofile.vmpath + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>VM Network 0:</th>";
	content += "<td>" + curprofile.virtualswitch0 + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>VM Network 1:</th>";
	content += "<td>" + curprofile.virtualswitch1 + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>VM Network 2:</th>";
	content += "<td>" + curprofile.virtualswitch2 + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>VM Network 3:</th>";
	content += "<td>" + curprofile.virtualswitch3 + "</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Generate eth0 MAC:</th>";
	if(curprofile.eth0generated == 0)
		content += "<td>No</td>";
	else
		content += "<td>Yes</td>";
	content += "</tr>";
	content += "<tr>";
	content += "<th align=right>Generate eth1 MAC:</th>";
	if(curprofile.eth1generated == 0)
		content += "<td>No</td>";
	else
		content += "<td>Yes</td>";
	content += "</tr>";
	content += "</table>";
	var func = function() {
		var profileid = dojo.byId('profileid').value;
		if(profileid == curprofileid)
			dojo.byId('vmhostdata').className = 'hidden';
		document.body.style.cursor = 'wait';
		dojo.xhrPost({
			url: 'index.php',
			load: delProfileCB,
			handleAs: "json",
			error: errorHandler,
			content: {continuation: cont,
						 profileid: profileid},
			timeout: 15000
		});
	};
	setMessageWindow(title, btn, content, func);
}

function delProfileCB(data, ioArgs) {
	if(data.items.failed) {
		if(data.items.failed == 'noaccess') {
			alert('You do not have access to manage this vm profile.');
		}
		else if(data.items.failed == 'inuse') {
			alert('This profile is currently in use on a vmhost. You must reload\nthe host with another profile to delete this one.');
		}
		dijit.byId('messages').hide();
		document.body.style.cursor = 'default';
		return;
	}
	dijit.byId('messages').hide();
	var obj = dojo.byId('profileid');
	obj.remove(obj.selectedIndex);
	dojo.byId('vmprofiledata').className = 'hidden';
	if(obj.options.length == 0)
		dojo.addClass('selectprofilediv', 'hidden');
	document.body.style.cursor = 'default';
}

function updateProfile(id, field) {
	dojo.removeClass('selectprofilediv', 'hidden');
	if(dijit.byId(id))
		var newvalue = dijit.byId(id).value;
	else
		var newvalue = dojo.byId(id).value;
	if(curprofile[field] == newvalue && field != 'password')
		return;
	if(field == 'password') {
		if(dojo.byId('ppassword').value == '********' &&
		   dojo.byId('ppwdconfirm').value == 'xxxxxxxx') {
			dojo.byId('savestatus').innerHTML = '(No change)';
			setTimeout(function() {dojo.byId('savestatus').innerHTML = '';}, 3000);
			return;
		}
		dojo.byId('savestatus').innerHTML = 'Saving...';
	}
	document.body.style.cursor = 'wait';
	
	var profileid = dojo.byId('profileid').value;
	var cont = dojo.byId('pcont').value;
	if(profileid == curprofileid)
		dojo.byId('vmhostdata').className = 'hidden';

	dojo.xhrPost({
		url: 'index.php',
		load: updateProfileCB,
		error: errorHandler,
		content: {continuation: cont,
					 profileid: profileid,
					 item: field,
					 newvalue: newvalue},
		timeout: 15000
	});
}

function updateProfileCB(data, ioArgs) {
	eval(data);
	document.body.style.cursor = 'default';
}

function checkProfilePassword() {
	var pobj = dojo.byId('ppassword');
	var cobj = dojo.byId('ppwdconfirm');
	var mobj = dojo.byId('ppwdmatch');

	if(pobj.value == "" && cobj.value == "") {
		mobj.innerHTML = '';
	}
	else if(pobj.value == cobj.value) {
		mobj.innerHTML = '<font color="#008000">match</font>';
	}
	else {
		mobj.innerHTML = '<font color="red">no match</font>';
	}
}
