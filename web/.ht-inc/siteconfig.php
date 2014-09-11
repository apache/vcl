<?php
/*
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn siteconfig()
///
/// \brief prints a page of site configuration options
///
////////////////////////////////////////////////////////////////////////////////
function siteconfig() {
	$h = '';
	$h .= "<h2>Site Configuration</h2>\n";

	$globalopts = 0;
	if(checkUserHasPerm('Site Configuration (global)'))
		$globalopts = 1;

	$h .= "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	$h .= "     doLayout=\"false\">\n";

	$h .= generalOptions($globalopts);

	$h .= "</div>\n"; # mainTabContainer

	print $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn generalOptions()
///
/// \brief prints a page of site configuration options
///
////////////////////////////////////////////////////////////////////////////////
function generalOptions($globalopts) {
	$h = '';
	$h .= "<div id=\"globalopts\" dojoType=\"dijit.layout.ContentPane\" title=\"Global Options\">\n";
	$h .= timeSourceHTML($globalopts);
	$h .= connectedUserCheckHTML($globalopts);
	$h .= "</div>\n";
	return $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn 
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function timeSourceHTML($globalopts) {
	$h  = "<div class=\"configwidget\">\n";
	$h .= "<h3>Time Source</h3>\n";
	$h .= "<span class=\"siteconfigdesc\">\n";
	$h .= "Set the default list of time servers to be used on installed nodes. These can be overridden for each management node under the settings for a given management node. Separate hostnames using a comma (,).<br><br>\n";
	$h .= "</span>\n";
	$val = getVariable('timesource|global', '', 1);
	# TODO start here 2 - decide on text or textarea; if text, fix regexp; if textarea, remove regexp
	$h .= labeledFormItem('timesource', 'Time Servers', 'text', $val['regexp'], '', $val['value']);
	$h .= "<div id=\"timesourcemsg\"></div>\n";
	$h .= dijitButton('timesourcebtn', 'Submit Changes', "saveTimeSource();", 1);
	$cont = addContinuationsEntry('AJupdateTimeSource', array('origval' => $val));
	$h .= "<input type=hidden id=timesourcecont value=\"$cont\">\n";
	$h .= "</div>\n";
	return $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn 
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateTimeSource() {
	if(! checkUserHasPerm('Site Configuration (global)')) {
		$arr = array('status' => 'noaccess',
		             'msg' => _('You do not have access to set the global Time Server setting.'));
		sendJSON($arr);
		return;
	}
	$origval = getContinuationVar('origval');
	$val = processInputVar('timesource', ARG_STRING);
	$val = preg_replace('/\s+/', '', $val);
	if($origval != $val) {
		$servers = explode(',', $val);
		foreach($servers as $key => $server) {
			if($server == '') {
				unset($servers[$key]);
				continue;
			}
			if(! preg_match('/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/', $server)) {
				$arr = array('status' => 'failed',
				             'msgid' => 'timesourcemsg',
				             'btn' => 'timesourcebtn',
				             'errmsg' => _('Invalid server(s) specified.'));
				sendJSON($arr);
				return;
			}
		}
		$newval = implode(',', $servers);
		setVariable('timesource|global', $newval);
	}
	$arr = array('status' => 'success',
	             'msgid' => 'timesourcemsg',
	             'btn' => 'timesourcebtn',
	             'msg' => _('Time Server successfully updated'));
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn 
///
/// \brief Image
///
////////////////////////////////////////////////////////////////////////////////
function connectedUserCheckHTML($globalopts) {
	$data = getVariablesRegex('^ignore_connections_gte.*');
	$h  = "<div class=\"configwidget\" style=\"width: 48%;\">\n";
	$h .= "<h3>Connected User Check</h3>\n";
	$h .= "<span class=\"siteconfigdesc\">\n";
	$h .= "Perform checks to time out reservations if a reservation duration is less than the specified value (minutes).<br><br>\n";
	$h .= "</span>\n";
	$origvals = array();
	if(empty($data)) {
		$val = 1440;
		$h .= labeledFormItem('ignore_connections_gte', 'global', 'text', '', 1, $val);
		$origvals['ignore_connections_gte'] = array('id' => 'ignore_connections_gte', 'val' => $val);
	}
	else {
		$extra = array('smallDelta' => 60, 'largeDelta' => 240);
		foreach($data as $prekey => $val) {
			$key = str_replace('|', '_', $prekey);
			$tmp = explode('|', $prekey);
			if(count($tmp) > 1)
				$label = $tmp[1];
			else
				$label = 'global';
			$h .= labeledFormItem($key, $label, 'spinner', '{min:0, max:10080}', 1, $val, '', '', $extra, '', '', 0);
			# TODO start here, make delete button work, add a way to add exception for other affiliations
			if($key != 'ignore_connections_gte')
				$h .= dijitButton("{$key}delbtn", "Delete", "deleteConnectedUserCheck('$key');") . "<br>\n";
			else
				$h .= "<br>\n";
			$origvals[$prekey] = array('id' => $key, 'val' => $val);
		}
	}
	$h .= dijitButton('connectedusercheckbtn', 'Submit Changes', "saveConnectedUserCheck();", 1);
	$cont = addContinuationsEntry('AJupdateConnectedUserCheck', array('origvals' => $origvals));
	$h .= "<input type=hidden id=connectedusercheckcont value=\"$cont\">\n";
	$h .= "</div>\n";
	return $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn 
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateConnectedUserCheck() {
	if(! checkUserHasPerm('Site Configuration (global)') &&
	   ! checkUserHasPerm('Site Configuration (affiliaton only)')) {
		$arr = array('status' => 'noaccess',
		             'msg' => _('You do not have access to modify the Connected User Check settings.'));
		sendJSON($arr);
		return;
	}





	# TODO copied from AJupdateTimeSource
	/*$origvals = getContinuationVar('origvals');
	$val = processInputVar('timesource', ARG_STRING);
	$val = preg_replace('/\s+/', '', $val);
	if($origval != $val) {
		$servers = explode(',', $val);
		foreach($servers as $key => $server) {
			if($server == '') {
				unset($servers[$key]);
				continue;
			}
			if(! preg_match('/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/', $server)) {
				$arr = array('status' => 'failed',
				             'msgid' => 'timesourcemsg',
				             'btn' => 'timesourcebtn',
				             'errmsg' => _('Invalid server(s) specified.'));
				sendJSON($arr);
				return;
			}
		}
		$newval = implode(',', $servers);
		setVariable('timesource|global', $newval);
	}
	$arr = array('status' => 'success',
	             'msgid' => 'timesourcemsg',
	             'btn' => 'timesourcebtn',
	             'msg' => _('Time Server successfully updated'));
	sendJSON($arr);*/
}

?>
