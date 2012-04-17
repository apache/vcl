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
dojo.provide("vcldojo.TimeTextBoxEnd");
dojo.require('dijit.form.TimeTextBox');
dojo.require('dojo.i18n');
dojo.requireLocalization("vcldojo", "TimeTextBoxEnd");
dojo.declare(
	"vcldojo.TimeTextBoxEnd",
	[dijit.form.TimeTextBox],
	{
		startid: '',
		invalidMessage: '(initial message)',
		isValid: function(isFocused) {
			if(dijit.byId(this.startid)) {
				var start = dijit.byId(this.startid).value;
				if(start !== null && this.value !== null && start >= this.value)
					return false;
			}
			return this.inherited(arguments);
		},
		postCreate: function() {
			var ln = dojo.i18n.getLocalization("vcldojo", "TimeTextBoxEnd");
			this.invalidMessage = ln.invalidMessage;
			this.inherited(arguments);
		}
	}
);
