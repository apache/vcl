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

function togglePublic() {
	if(dojo.byId('publicIPconfig').value == 'static') {
		dojo.byId('publicnetmask').disabled = false;
		dojo.byId('publicgateway').disabled = false;
		dojo.byId('publicdnsserver').disabled = false;
	}
	else {
		dojo.byId('publicnetmask').disabled = true;
		dojo.byId('publicgateway').disabled = true;
		dojo.byId('publicdnsserver').disabled = true;
	}
}
