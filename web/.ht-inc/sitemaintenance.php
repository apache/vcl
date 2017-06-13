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

/**
 * \file
 */

////////////////////////////////////////////////////////////////////////////////
///
/// \fn siteMaintenance()
///
/// \brief prints a page for managing site maintenance
///
////////////////////////////////////////////////////////////////////////////////
function siteMaintenance() {
	$update = getContinuationVar('update', 0);
	$items = getMaintItems();

	$rt = '';
	if(! $update) {
		$rt .= "<h2>Site Maintenance</h2>\n";
		$rt .= "<div id=\"maintenancediv\">\n";
	}
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= "  Schedule Site Maintenance\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$cont = addContinuationsEntry('AJcreateSiteMaintenance', array('update' => 1));
	$rt .= "    showAddSiteMaintenance('$cont');\n";
	$rt .= "  </script>\n";
	$rt .= "</button><br>\n";
	if(count($items)) {
		$rt .= "<table>\n";
		$rt .= "<tr>\n";
		$rt .= "<td colspan=2></td>\n";
		$rt .= "<th style=\"vertical-align: bottom;\">Start</th>\n";
		$rt .= "<th style=\"vertical-align: bottom;\">End</th>\n";
		$rt .= "<th style=\"vertical-align: bottom;\">Owner</th>\n";
		$rt .= "<th style=\"vertical-align: bottom;\">Created</th>\n";
		$rt .= "<th style=\"vertical-align: bottom;\">Reason <small>(hover for more)</small></th>\n";
		$rt .= "<th style=\"vertical-align: bottom;\">User Message <small>(hover for more)</small></th>\n";
		$rt .= "<th style=\"vertical-align: bottom;\">Inform Hours Ahead</th>\n";
		$rt .= "<th style=\"vertical-align: bottom;\">Allow Reservations</th>\n";
		$rt .= "</tr>\n";
		foreach($items as $item) {
			$tmp = datetimeToUnix($item['start']);
			$start = date('g:i&\n\b\s\p;A n/j/Y', $tmp);
			$tmp = datetimeToUnix($item['end']);
			$end = date('g:i&\n\b\s\p;A n/j/Y', $tmp);
			$tmp = datetimeToUnix($item['created']);
			$created = date('g:i&\n\b\s\p;A n/j/Y', $tmp);
			$rt .= "<tr>\n";
			$rt .= "<td>\n";
			$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
			$rt .= "  Edit\n";
			$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
			$data = array('id' => $item['id']);
			$cont = addContinuationsEntry('AJgetSiteMaintenanceData', $data);
			$rt .= "    showEditSiteMaintenance('$cont');\n";
			$rt .= "  </script>\n";
			$rt .= "</button>\n";
			$rt .= "</td>\n";
			$rt .= "<td>\n";
			$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
			$rt .= "  Delete\n";
			$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
			$cont = addContinuationsEntry('AJgetDelSiteMaintenanceData', $data);
			$rt .= "    confirmDeleteSiteMaintenance('$cont');\n";
			$rt .= "  </script>\n";
			$rt .= "</button>\n";
			$rt .= "</td>\n";
			$rt .= "<td align=center>$start</td>\n";
			$rt .= "<td align=center>$end</td>\n";
			$rt .= "<td align=center>{$item['owner']}</td>\n";
			$rt .= "<td align=center>$created</td>\n";
			if(strlen($item['reason']) < 30)
				$rt .= "<td align=center>{$item['reason']}</td>\n";
			else {
				$rt .= "<td align=center>\n";
				$reason = substr($item['reason'], 0, 30) . '...';
				$rt .= "  <span id=\"morereason\">$reason</span>\n";
				$rt .= "  <div dojoType=\"dijit.Tooltip\" connectId=\"morereason\">\n";
				$reason = preg_replace("/(.{1,50}([ \n]|$))/", '\1<br>', $item['reason']);
				$reason = preg_replace("/\n<br>\n/", "<br><br>\n", $reason);
				$rt .= "$reason</div>\n";
				$rt .= "</td>\n";
			}
			if(strlen($item['usermessage']) < 30)
				$rt .= "<td align=center>{$item['usermessage']}</td>\n";
			else {
				$rt .= "<td align=center>\n";
				$msg = substr($item['usermessage'], 0, 30) . '...';
				$rt .= "  <span id=\"moreusermsg\">$msg</span>\n";
				$rt .= "  <div dojoType=\"dijit.Tooltip\" connectId=\"moreusermsg\">\n";
				$msg = preg_replace("/(.{1,50}([ \n]|$))/", "\1<br>", $item['usermessage']);
				$msg = preg_replace('/\n<br>\n/', "<br><br>\n", $msg);
				$rt .=  "$msg</div>\n";
				$rt .= "</td>\n";
			}
			$hours = $item['informhoursahead'] % 24;
			if($hours == 1)
				$hours = (int)($item['informhoursahead'] / 24) . " days, 1 hour";
			else
				$hours = (int)($item['informhoursahead'] / 24) . " days, $hours hours";
			$rt .= "<td align=center>$hours</td>\n";
			if($item['allowreservations'])
				$rt .= "<td align=center>Yes</td>\n";
			else
				$rt .= "<td align=center>No</td>\n";
			$rt .= "</tr>\n";
		}
		$rt .= "</table>\n";
	}
	if($update) {
		$send = str_replace("\n", '', $rt);
		$send = str_replace("'", "\'", $send);
		$send = preg_replace("/>\s*</", "><", $send);
		print setAttribute('maintenancediv', 'innerHTML', $send);
		print "AJdojoCreate('maintenancediv');";
		return;
	}
	print $rt;
	print "</div>\n"; # end maintenancediv

	print "<div id=\"editDialog\" dojoType=\"dijit.Dialog\" autofocus=\"false\">\n";
	print "<h2><span id=\"editheader\"></span></h2>\n";
	print "<span id=\"edittext\"></span><br><br>\n";
	print "<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <th align=\"right\">Start:</th>\n";
	print "    <td>\n";
	print "      <div type=\"text\" id=\"starttime\" dojoType=\"dijit.form.TimeTextBox\" ";
	print "required=\"true\" style=\"width: 80px\"></div>\n";
	print "      <div type=\"text\" id=\"startdate\" dojoType=\"dijit.form.DateTextBox\" ";
	print "required=\"true\" style=\"width: 100px\"></div>\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\">End:</th>\n";
	print "    <td>\n";
	print "      <div type=\"text\" id=\"endtime\" dojoType=\"dijit.form.TimeTextBox\" ";
	print "required=\"true\" style=\"width: 80px\"></div>\n";
	print "      <div type=\"text\" id=\"enddate\" dojoType=\"dijit.form.DateTextBox\" ";
	print "required=\"true\" style=\"width: 100px\"></div>\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr valign=\"top\">\n";
	print "    <th align=\"right\">Inform Hours Ahead:</th>\n";
	print "    <td>\n";
	print "      <input dojoType=\"dijit.form.NumberSpinner\"\n";
	print "             constraints=\"{min:1,max:65535}\"\n";
	print "             maxlength=\"3\"\n";
	print "             id=\"hoursahead\"\n";
	print "             format=\"updateDaysHours\"\n";
	print "             required=\"true\"\n";
	print "             style=\"width: 70px\">\n";
	print "      <span id=dayshours></span>\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr valign=\"top\">\n";
	print "    <th align=\"right\">Allow Reservations:</th>\n";
	print "    <td>\n";
	print "      <select id=allowreservations dojoType=\"dijit.form.Select\">";
	print "        <option value=\"1\">Yes</option>\n";
	print "        <option value=\"0\">No</option>\n";
	print "      </select>\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "</table>\n";
	print "<b>Reason</b> (this is not displayed to any users and is just for your records):<br>\n";
	print "<textarea id=\"reason\" dojoType=\"dijit.form.Textarea\" style=\"width: 400px;\">\n";
	print "</textarea><br>\n";
	print "<b>User Message</b> (this will be displayed on the site during the maintenance window):<br>\n";
	print "<textarea id=\"usermessage\" dojoType=\"dijit.form.Textarea\" style=\"width: 400px;\">\n";
	print "</textarea>\n";
	print "<input type=\"hidden\" id=\"submitcont\">\n";
	print "<div align=\"center\">\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\" id=\"editsubmitbtn\">\n";
	print "  Save Changes\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    editSubmit();\n";
	print "  </script>\n";
	print "</button>\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	print "  Cancel\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    clearEdit();\n";
	print "  </script>\n";
	print "</button>\n";
	print "</div>\n";
	print "</div>\n"; # edit dialog

	print "<div id=\"confirmDialog\" dojoType=\"dijit.Dialog\" title=\"Delete Site Maintenance\">\n";
	print "<h2>Delete Site Maintenance</h2>\n";
	print "Click <b>Delete Entry</b> to delete this site maintenance entry<br><br>\n";
	print "<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <th align=\"right\">Start:</th>\n";
	print "    <td><span id=\"start\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\">End:</th>\n";
	print "    <td><span id=\"end\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\">Owner:</th>\n";
	print "    <td><span id=\"owner\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\">Created:</th>\n";
	print "    <td><span id=\"created\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr valign=\"top\">\n";
	print "    <th align=\"right\">Inform Hours Ahead:</th>\n";
	print "    <td><span id=\"informhoursahead\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr valign=\"top\">\n";
	print "    <th align=\"right\">Allow Reservations:</th>\n";
	print "    <td><span id=\"delallowreservations\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr valign=top>\n";
	print "    <th align=\"right\">Reason:</th>\n";
	print "    <td><span id=\"delreason\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr valign=top>\n";
	print "    <th align=\"right\">User Message:</th>\n";
	print "    <td><span id=\"delusermessage\"></span></td>\n";
	print "  </tr>\n";
	print "</table>\n";
	print "<input type=\"hidden\" id=\"delsubmitcont\">\n";
	print "<div align=\"center\">\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	print "  Delete Entry\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    deleteSiteMaintenance();\n";
	print "  </script>\n";
	print "</button>\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	print "  Cancel\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    dijit.byId('confirmDialog').hide();\n";
	print "  </script>\n";
	print "</button>\n";
	print "</div>\n";
	print "</div>\n"; # confirm dialog
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJcreateSiteMaintenance()
///
/// \brief creates an file in the maintenance directory, creates an entry in
/// the sitemaintenance table and does a javascript page reload
///
////////////////////////////////////////////////////////////////////////////////
function AJcreateSiteMaintenance() {
	global $user;
	$data = processSiteMaintenanceInput();
	if($data['err'])
		return;

	if(! writeMaintenanceFile($data['startts'], $data['endts'], $data['usermessage'])) {
		print "alert('Failed to create maintenance file on web server.\\n";
		print "Please have sysadmin check permissions on maintenance directory.');\n";
		return;
	}

	$reason = mysql_real_escape_string($data['reason']);
	$usermessage = mysql_real_escape_string($data['usermessage']);
	$query = "INSERT INTO sitemaintenance "
	       .        "(start, "
	       .        "end, "
	       .        "ownerid, "
	       .        "created, "
	       .        "reason, "
	       .        "usermessage, "
	       .        "informhoursahead, "
	       .        "allowreservations) "
	       . "VALUES "
	       .        "('{$data['startdt']}', "
	       .        "'{$data['enddt']}', "
	       .        "{$user['id']}, "
	       .        "NOW(), "
	       .        "'$reason', "
	       .        "'$usermessage', "
	       .        "{$data['hoursahead']}, "
	       .        "{$data['allowreservations']})";
	doQuery($query, 101);
	$_SESSION['usersessiondata'] = array();
	print "window.location.href = '" . BASEURL . SCRIPT . "?mode=siteMaintenance';";
	#print "clearEdit();";
	#siteMaintenance();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJgetSiteMaintenanceData()
///
/// \brief gets info about a sitemaintenance entry and returns it in JSON format
///
////////////////////////////////////////////////////////////////////////////////
function AJgetSiteMaintenanceData() {
	$id = getContinuationVar('id');
	$tmp = getMaintItems($id);
	$data = $tmp[$id];
	$start = datetimeToUnix($data['start']) * 1000;
	$end = datetimeToUnix($data['end']) * 1000;
	$cdata = array('id' => $id,
	               'update' => 1);
	$cont = addContinuationsEntry('AJeditSiteMaintenance', $cdata,
	                              SECINDAY, 1, 0);
	$arr = array('start' => $start,
	             'end' => $end,
	             'hoursahead' => $data['informhoursahead'],
	             'allowreservations' => $data['allowreservations'],
	             'reason' => $data['reason'],
	             'usermessage' => $data['usermessage'],
	             'cont' => $cont);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJgetDelSiteMaintenanceData()
///
/// \brief gets info about a sitemaintenance entry to be displayed on the
/// confirm delete dialog and returns it in JSON format
///
////////////////////////////////////////////////////////////////////////////////
function AJgetDelSiteMaintenanceData() {
	$id = getContinuationVar('id');
	$tmp = getMaintItems($id);
	$data = $tmp[$id];
	$cdata = array('id' => $id,
	               'update' => 1,
	               'start' => datetimeToUnix($data['start']));
	$cont = addContinuationsEntry('AJdeleteSiteMaintenance', $cdata,
	                              SECINDAY, 1, 0);
	$tmp = datetimeToUnix($data['start']);
	$start = date('g:i A, n/j/Y', $tmp);
	$tmp = datetimeToUnix($data['end']);
	$end = date('g:i A, n/j/Y', $tmp);
	$tmp = datetimeToUnix($data['created']);
	$created = date('g:i A, n/j/Y', $tmp);
	$hours = $data['informhoursahead'] % 24;
	if($hours == 1)
		$hours = (int)($data['informhoursahead'] / 24) . " days, 1 hour";
	else
		$hours = (int)($data['informhoursahead'] / 24) . " days, $hours hours";
	$hours = "{$data['informhoursahead']} ($hours)";
	if($data['allowreservations'])
		$allowres = 'Yes';
	else
		$allowres = 'No';
	$reason = preg_replace("/(.{1,50}([ \n]|$))/", '\1<br>', $data['reason']);
	$reason = preg_replace('/\n<br>\n/', "<br><br>\n", $reason);
	$usermsg = preg_replace("/(.{1,50}([ \n]|$))/", '\1<br>', $data['usermessage']);
	$usermsg = preg_replace('/\n<br>\n/', "<br><br>\n", $usermsg);
	$arr = array('start' => $start,
	             'end' => $end,
	             'owner' => $data['owner'],
	             'created' => $created,
	             'hoursahead' => $hours,
	             'allowreservations' => $allowres,
	             'reason' => $reason,
	             'usermessage' => $usermsg,
	             'cont' => $cont);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJeditSiteMaintenance()
///
/// \brief removes/adds file in maintenances directory and updates entry in
/// sitemaintenance table
///
////////////////////////////////////////////////////////////////////////////////
function AJeditSiteMaintenance() {
	global $user;
	$id = getContinuationVar('id');
	$data = processSiteMaintenanceInput();

	$olddata = getMaintItems($id);
	$start = datetimeToUnix($olddata[$id]['start']);
	if(! deleteMaintenanceFile($start) ||
	   ! writeMaintenanceFile($data['startts'], $data['endts'], $data['usermessage'])) {
		print "alert('Failed to modify maintenance file on web server.\\n";
		print "Please have sysadmin check permissions on maintenance directory.');\n";
		print "dijit.byId('confirmDialog').hide();";
		$data['err'] = 1;
	}
	if($data['err']) {
		$data = array('id' => $id,
		              'update' => 1);
		$cont = addContinuationsEntry('AJeditSiteMaintenance', $data,
		                              SECINDAY, 1, 0);
		print "dojo.byId('submitcont').value = '$cont';";
		return;
	}

	$reason = mysql_real_escape_string($data['reason']);
	$usermessage = mysql_real_escape_string($data['usermessage']);
	$query = "UPDATE sitemaintenance "
	       . "SET start = '{$data['startdt']}', "
	       .     "end = '{$data['enddt']}', "
	       .     "ownerid = {$user['id']}, "
	       .     "created = NOW(), "
	       .     "reason = '$reason', "
	       .     "usermessage = '$usermessage', "
	       .     "informhoursahead = {$data['hoursahead']}, "
	       .     "allowreservations = {$data['allowreservations']} "
	       . "WHERE id = $id";
	doQuery($query, 101);
	$_SESSION['usersessiondata'] = array();
	print "window.location.href = '" . BASEURL . SCRIPT . "?mode=siteMaintenance';";
	#print "clearEdit();";
	#siteMaintenance();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processSiteMaintenanceInput()
///
/// \return array with these keys:\n
/// \b hoursahead - corresponds to sitemaintenance table\n
/// \b allowreservations - corresponds to sitemaintenance table\n
/// \b reason - corresponds to sitemaintenance table\n
/// \b usermessage - corresponds to sitemaintenance table\n
/// \b startdt - datetime format for start of maintenance\n
/// \b startts - unix timestamp format for start of maintenance\n
/// \b enddt - datetime format for end of maintenance\n
/// \b endts - unix timestamp format for end of maintenance\n
/// \b err - whether or not an entry was found to be invalid
///
/// \brief validates form data for site maintenance items
///
////////////////////////////////////////////////////////////////////////////////
function processSiteMaintenanceInput() {
	$start = processInputVar('start', ARG_NUMERIC);
	$end = processInputVar('end', ARG_NUMERIC);
	$data['hoursahead'] = processInputVar('hoursahead', ARG_NUMERIC);
	$data['allowreservations'] = processInputVar('allowreservations', ARG_NUMERIC);
	$data['reason'] = processInputVar('reason', ARG_STRING);
	$data['usermessage'] = processInputVar('usermessage', ARG_STRING);

	$err = 0;

	$now = time();
	$data['startdt'] = numdatetimeToDatetime($start . '00');
	$data['startts'] = datetimeToUnix($data['startdt']);
	$data['enddt'] = numdatetimeToDatetime($end . '00');
	$data['endts'] = datetimeToUnix($data['enddt']);

	$reg = "/^[-0-9a-zA-Z\.,\?:;_@!#\(\)\n ]+$/";
	if(! preg_match($reg, $data['reason'])) {
		$errmsg = "Reason can only contain letters, numbers, spaces,\\nand these characters: . , ? : ; - _ @ ! # ( )";
		$err = 1;
	}
	if(! preg_match($reg, $data['usermessage'])) {
		$errmsg = "User Message can only contain letters, numbers, spaces,\\nand these characters: . , ? : ; - _ @ ! # ( )";
		$err = 1;
	}
	if(! $err && $data['startts'] < $now) {
		$errmsg = 'The start time and date must be later than the current time.';
		$err = 1;
	}
	if(! $err && $data['endts'] <= $data['startts']) {
		$errmsg = 'The end time and date must be later than the start time and date.';
		$err = 1;
	}
	if(! $err && $data['hoursahead'] < 1) {
		$errmsg = 'Inform Hours Ahead must be at least 1.';
		$err = 1;
	}
	if(! $err && $data['hoursahead'] > 65535) {
		$errmsg = 'Inform Hours Ahead must be less than 65536.';
		$err = 1;
	}
	if(! $err && ($data['allowreservations'] != 0 && $data['allowreservations'] != 1))
		$data['allowreservations'] = 0;
	if(! $err && ! preg_match('/[A-Za-z]{2,}/', $data['usermessage'])) {
		$errmsg = 'Something must be filled in for the User Message.';
		$err = 1;
	}
	if($err)
		print "alert('$errmsg');";
	$data['err'] = $err;
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJdeleteSiteMaintenance()
///
/// \brief removes file from maintenance directory and deletes entry from
/// sitemaintenance table
///
////////////////////////////////////////////////////////////////////////////////
function AJdeleteSiteMaintenance() {
	$id = getContinuationVar('id');
	$start = getContinuationVar('start');
	if(! deleteMaintenanceFile($start)) {
		print "alert('Failed to delete maintenance file on web server.\\n";
		print "Please have sysadmin check permissions on maintenance directory.');\n";
		print "dijit.byId('confirmDialog').hide();";
		return;
	}
	$query = "DELETE FROM sitemaintenance WHERE id = $id";
	doQuery($query, 101);
	$_SESSION['usersessiondata'] = array();
	print "window.location.href = '" . BASEURL . SCRIPT . "?mode=siteMaintenance';";
	#print "dijit.byId('confirmDialog').hide();";
	#siteMaintenance();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn writeMaintenanceFile($start, $end, $msg)
///
/// \param $start - start time of maintenance entry in unix timestamp format
/// \param $end - end time of maintenance entry in unix timestamp format
/// \param $msg - user message for maintenance entry
///
/// \return true if file created; false if not
///
/// \brief creates a file in the maintenance directory
///
////////////////////////////////////////////////////////////////////////////////
function writeMaintenanceFile($start, $end, $msg) {
	$name = date('YmdHi', $start);
	$reg = "|" . SCRIPT . "$|";
	$file = preg_replace($reg, '', $_SERVER['SCRIPT_FILENAME']);
	$file .= "/.ht-inc/maintenance/$name";
	if(! $fh = fopen($file, 'w')) {
		return false;
	}
	$globaltheme = getAffiliationTheme(0);
	fwrite($fh, "THEME=$globaltheme\n");
	$numend = date('YmdHi', $end);
	fwrite($fh, "END=$numend\n");
	fwrite($fh, "$msg\n");
	fclose($fh);
	return true;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deleteMaintenanceFile($start)
///
/// \param $start - start time of maintenance entry in unix timestamp format
///
/// \return true if file deleted; false if not
///
/// \brief removes a file from the maintenance directory
///
////////////////////////////////////////////////////////////////////////////////
function deleteMaintenanceFile($start) {
	$name = date('YmdHi', $start);
	$reg = "|" . SCRIPT . "$|";
	$file = preg_replace($reg, '', $_SERVER['SCRIPT_FILENAME']);
	$file .= "/.ht-inc/maintenance/$name";
	if(! file_exists($file))
		return true;
	if(! @unlink($file))
		return false;
	return true;
}

?>
