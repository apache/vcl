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
var xhrobj;
var blockHide = 0;
var currentOver = '';

function getGroupInfo(cont, groupid) {
	var domid = 'listicon' + groupid;
	currentOver = domid;
	dojo.byId(domid).onmouseover = '';
	xhrobj = dojo.xhrPost({
		url: 'index.php',
		load: showGroupInfo,
		handleAs: "json",
		error: errorHandler,
		content: {continuation: cont,
					 groupid: groupid},
		timeout: 15000
	});
}

function mouseoverHelp() {
	currentOver = 'listicon0';
	var obj = dijit.byId('listicon0tt');
	if(! obj) {
		var tt = new dijit.Tooltip({
		   id: 'listicon0tt',
		   connectId: ['listicon0'],
		   label: 'mouse over icon to<br>display a group&#146;s<br>resources'
		});
		tt.open(dojo.byId('listicon0'));
	}
	else
		obj.open(dojo.byId('listicon0'));
}

function showGroupInfoCancel(groupid) {
	currentOver = '';
	dojo.byId('listicon' + groupid).onmouseout = '';
}

function showGroupInfo(data, ioArgs) {
	var members = data.items.members;
	var domid = 'listicon' + data.items.groupid;
	var tt = new dijit.Tooltip({
		connectId: [domid],
		label: members
	});
	if(currentOver == domid)
		tt.open(dojo.byId(domid));
}
