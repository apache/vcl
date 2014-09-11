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

function generalSiteConfigCB(data, ioArgs) {
	if(data.items.status == 'success') {
		dojo.removeClass(data.items.msgid, 'cfgerror');
		dojo.addClass(data.items.msgid, 'cfgsuccess');
		dojo.byId(data.items.msgid).innerHTML = data.items.msg;
		dijit.byId(data.items.btn).set('disabled', false);
		clearmsg(data.items.msgid, 20);
	}
	else if(data.items.status == 'failed') {
		dojo.removeClass(data.items.msgid, 'cfgsuccess');
		dojo.addClass(data.items.msgid, 'cfgerror');
		dojo.byId(data.items.msgid).innerHTML = data.items.errmsg;
		dijit.byId(data.items.btn).set('disabled', false);
		//clearmsg(data.items.msgid, 20);
	}
	else if(data.items.status == 'noaccess') {
		alert(data.items.msg);
	}
}

function clearmsg(id, wait) {
	setTimeout(function() {
		dojo.byId(id).innerHTML = '';
		dojo.removeClass(id, 'cfgerror');
		dojo.removeClass(id, 'cfgsuccess');
	}, wait * 1000);
}

function saveTimeSource() {
	var data = {continuation: dojo.byId('timesourcecont').value,
	            timesource: dijit.byId('timesource').value};
	dijit.byId('timesourcebtn').set('disabled', true);
	RPCwrapper(data, generalSiteConfigCB, 1);
}

function saveConnectedUserCheck() {
}
