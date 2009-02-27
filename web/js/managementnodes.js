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
var timeout = 0;

function showHelp(msg, id) {
	if(timeout)
		clearTimeout(timeout);
	var obj = document.getElementById(id);
	var x = findPosX(obj);
	var y = findPosY(obj) - 10;
	obj = document.getElementById('helpbox');
	obj.innerHTML = msg;
	obj.style.left = x + "px";
	obj.style.top = y + "px";
	obj.style.zIndex = 10;
}

function clearHelpbox() {
	if(timeout)
		clearTimeout(timeout);
	timeout = setTimeout(function() {clearHelpbox2(1);}, 50);
}

function clearHelpbox2(fromicon) {
	if(fromicon && blockHide)
		return;
	blockHide = 0;
	var obj = document.getElementById('helpbox');
	obj.innerHTML = '';
	obj.style.zIndex = -10;
}

function blockClear() {
	blockHide = 1;
}

function toggleImageLibrary() {
	var obj = document.getElementById('imagelibenable');
	if(obj.checked) {
		document.getElementById('imagelibgroupid').disabled = false;
		obj = document.getElementById('imagelibuser');
		obj.disabled = false;
		if(obj.value == 'NULL')
			obj.value = '';
		obj = document.getElementById('imagelibkey');
		obj.disabled = false;
		if(obj.value == 'NULL')
			obj.value = '';
	}
	else {
		document.getElementById('imagelibgroupid').disabled = true;
		document.getElementById('imagelibuser').disabled = true;
		document.getElementById('imagelibkey').disabled = true;
	}
}
