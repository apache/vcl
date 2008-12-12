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

function getGroupInfo(cont, groupid) {
	xhrobj = dojo.xhrPost({
		url: 'index.php',
		load: showGroupInfo,
		handleAs: "json-comment-filtered",
		error: errorHandler,
		content: {continuation: cont,
					 groupid: groupid,
					 mousex: mouseX,
					 mousey: mouseY},
		timeout: 15000
	});
}

function mouseoverHelp() {
	var data = [];
	data['items'] = [];
	data['items']['members'] = [];
	data['items']['members'][0] = 'mouse over icon to<br>display a group&#146;s<br>resources';
	data['items']['x'] = mouseX;
	data['items']['y'] = mouseY;
	showGroupInfo(data);
}

function showGroupInfo(data, ioArgs) {
	var members = data.items.members;
	var mx = data.items.x;
	var my = data.items.y;
	var text = "";
	for(var i = 0; i < members.length; i++) {
		text = text + members[i] + '<br>';
	}
	var obj = document.getElementById('content');
	var x = findPosX(obj);
	var y = findPosY(obj);
	obj = document.getElementById('listitems');
	obj.innerHTML = text;
	//if(browser == 'IE') {
		var a = mx - obj.clientWidth - 2;
		var b = my - (obj.clientHeight / 2);
	/*}
	else {
		var a = mx - x - obj.clientWidth;
		var b = my - y - obj.clientHeight;
	}*/
	obj.style.left = a + "px";
	obj.style.top = b + "px";
	obj.style.zIndex = 10;
}

function clearGroupPopups() {
	setTimeout(function() {clearGroupPopups2(1);}, 50);
}

function clearGroupPopups2(fromicon) {
	if(xhrobj)
		xhrobj.ioArgs.xhr.abort();
	if(fromicon && blockHide)
		return;
	blockHide = 0;
	var obj = document.getElementById('listitems');
	obj.innerHTML = '';
	obj.style.zIndex = -10;
}

function blockClear() {
	blockHide = 1;
}
