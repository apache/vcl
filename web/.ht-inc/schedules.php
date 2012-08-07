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

/// signifies an error with the submitted name
define("SCHNAMEERR", 1);
/// signifies an error with the submitted owner
define("SCHOWNERERR", 1 << 1);
/// signifies an error where 2 submitted time periods overlap
define("OVERLAPERR", 1 << 2);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewSchedules()
///
/// \brief prints a page to view schedule information
///
////////////////////////////////////////////////////////////////////////////////
function viewSchedules() {
	global $user, $mode;
	$schedules = getSchedules();
	$tmp = getUserResources(array("groupAdmin"), array("administer"), 1);
	$schedulegroups = $tmp["schedule"];
	$schedulemembership = getResourceGroupMemberships("schedule");
	$resources = getUserResources(array("scheduleAdmin"), array("administer"));
	$userScheduleIDs = array_keys($resources["schedule"]);

	print "<H2>Schedules</H2>\n";
	if($mode == "submitEditSchedule") {
		print "<font color=\"#008000\">Schedule successfully updated";
		print "</font><br><br>\n";
	}
	if($mode == "submitDeleteSchedule") {
		print "<font color=\"#008000\">Schedule successfully deleted";
		print "</font><br><br>\n";
	}
	print "<TABLE border=1 id=layouttable summary=\"list of schedules\">\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TD></TD>\n";
	print "    <TH>Name</TH>\n";
	print "    <TH>Owner</TH>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "    <TD></TD>\n";
	print "    <TD><INPUT type=submit value=Add></TD>\n";
	print "    <TD><INPUT type=text name=name maxlength=25 size=10></TD>\n";
	print "    <TD><INPUT type=text name=owner size=15 value=\"";
	print "{$user["unityid"]}@{$user['affiliation']}\"></TD>\n";
	$cont = addContinuationsEntry('confirmAddSchedule');
	print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "    </FORM>\n";
	print "  </TR>\n";

	foreach(array_keys($schedules) as $id) {
		if(! in_array($id, $userScheduleIDs))
			continue;
		print "  <TR>\n";
		print "    <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('scheduleid' => $id);
		$cont = addContinuationsEntry('confirmDeleteSchedule', $cdata);
		print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "    <TD>\n";
		print "      <INPUT type=submit value=Delete>\n";
		print "    </TD>\n";
		print "    </FORM>\n";
		print "    <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('scheduleid' => $id);
		$cont = addContinuationsEntry('editSchedule', $cdata);
		print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "    <TD>\n";
		print "      <INPUT type=submit value=Edit>\n";
		print "    </TD>\n";
		print "    </FORM>\n";
		print "    <TD>" . $schedules[$id]["name"] . "</TD>\n";
		print "    <TD>" . $schedules[$id]["owner"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";

	$resources = getUserResources(array("scheduleAdmin"), 
	                              array("manageGroup"));
	$tmp = getUserResources(array("scheduleAdmin"), 
	                              array("manageGroup"), 1);
	$schedulegroups = $tmp["schedule"];
	uasort($resources["schedule"], "sortKeepIndex");
	uasort($schedulegroups, "sortKeepIndex");
	if(count($resources["schedule"])) {
		print "<br><br>\n";
		print "<A name=\"grouping\"></a>\n";
		print "<H2>Schedule Grouping</H2>\n";
		if($mode == "submitScheduleGroups") {
			print "<font color=\"#008000\">Schedule groups successfully updated";
			print "</font><br><br>\n";
		}
		print "<FORM action=\"" . BASEURL . SCRIPT . "#grouping\" method=post>\n";
		print "<TABLE border=1 id=layouttable summary=\"\">\n";
		print "  <TR>\n";
		print "    <TH rowspan=2>Schedules</TH>\n";
		print "    <TH colspan=" . count($schedulegroups) . ">Groups</TH>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		foreach($schedulegroups as $group) {
			print "    <TH>$group</TH>\n";
		}
		print "  </TR>\n";
		$count = 1;
		foreach($resources["schedule"] as $scheduleid => $schedule) {
			if($count % 18 == 0) {
				print "  <TR>\n";
				print "    <TH><img src=images/blank.gif></TH>\n";
				foreach($schedulegroups as $group) {
					print "    <TH>$group</TH>\n";
				}
				print "  </TR>\n";
			}
			print "  <TR>\n";
			print "    <TH align=right>$schedule</TH>\n";
			foreach(array_keys($schedulegroups) as $groupid) {
				$name = "schedulegroup[" . $scheduleid . ":" . $groupid . "]";
				if(array_key_exists($scheduleid, $schedulemembership["schedule"]) &&
					in_array($groupid, $schedulemembership["schedule"][$scheduleid])) {
					$checked = "checked";
				}
				else {
					$checked = "";
				}
				print "    <TD align=center>\n";
				print "      <INPUT type=checkbox name=\"$name\" $checked>\n";
				print "    </TD>\n";
			}
			print "  </TR>\n";
			$count++;
		}
		print "</TABLE>\n";
		$cont = addContinuationsEntry('submitScheduleGroups', array(), SECINDAY, 1, 0);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=\"Submit Changes\">\n";
		print "<INPUT type=reset value=Reset>\n";
		print "</FORM>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editOrAddSchedule($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a form for editing a schedule
///
////////////////////////////////////////////////////////////////////////////////
function editOrAddSchedule($state) {
	global $submitErr, $mode, $submitErrMsg, $days;

	$schedules = getSchedules();

	$newcont = 0;
	if($submitErr || $mode == "submitAddSchedule") {
		$data = processScheduleInput(0);
		$newcont = 1; # continuation to get here was deleted; so, we'll need to set
		              #   deletefromself true this time
	}
	else {
		$data["scheduleid"] = getContinuationVar("scheduleid");
		$id = $data["scheduleid"];
		$data["name"] = $schedules[$id]["name"];
		$data["owner"] = $schedules[$id]["owner"];
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<DIV align=center>\n";
	if($state) {
		print "<H2>Add Schedule</H2>\n";
	}
	else {
		print "<H2>Edit Schedule</H2>\n";
	}
	if($mode == "submitAddSchedule") {
		print "<font color=\"#008000\">Schedule successfully added";
		print "</font><br><br>\n";
		print "Now you must add start and end times for the schedule<br>\n";
	}
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Name:</TH>\n";
	print "    <TD><INPUT type=text name=name value=\"" . $data["name"] . "\" ";
	print "maxlength=25></TD>\n";
	print "    <TD>";
	if($mode == "confirmAddSchedule" || $mode == "confirmEditSchedule")
		printSubmitErr(SCHNAMEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD><INPUT type=text name=owner value=\"";
	print $data["owner"] . "\"></TD>\n";
	print "    <TD>";
	if($mode == "confirmAddSchedule" || $mode == "confirmEditSchedule")
		printSubmitErr(SCHOWNERERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	if($state) {
		$cont = addContinuationsEntry('confirmAddSchedule', array(), SECINDAY, 0, 1, 1);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=\"Confirm Schedule\">\n";
	}
	else {
		$cdata = array('scheduleid' => $data['scheduleid']);
		if($newcont)
			$cont = addContinuationsEntry('confirmEditSchedule', $cdata);
		else
			$cont = addContinuationsEntry('confirmEditSchedule', $cdata, SECINDAY, 0, 1, 1);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=\"Confirm Changes\">\n";
	}
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=viewSchedules>\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "</div>\n";
	if($state)
		return;
	print "The start and end day/times are based on a week's time period with ";
	print "the start/end point being 'Sunday 12:00&nbsp;am'. i.e. The earliest ";
	print "start day/time is 'Sunday 12:00&nbsp;am' and the latest end day/";
	print "time is 'Sunday 12:00&nbsp;am'<br><br>\n";


	print "Start:";
	printSelectInput('startday', $days, -1, 0, 0, 'startday');
	print "<input type=\"text\" id=\"starttime\" dojoType=\"dijit.form.TimeTextBox\" ";
	print "required=\"true\" />\n";
	print "End:";
	printSelectInput('endday', $days, -1, 0, 0, 'endday');
	print "<input type=\"text\" id=\"endtime\" dojoType=\"dijit.form.TimeTextBox\" ";
	print "required=\"true\" />\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\" ";
	print "id=\"addTimeBtn\">\n";
	print "  Add\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    addTime();\n";
	print "  </script>\n";
	print "</button>\n";
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"scheduleStore\" ";
	print "data=\"scheduleTimeData\"></div>\n";
	print "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"scheduleGrid\" sortInfo=1 ";
	print "store=\"scheduleStore\" style=\"width: 524px; height: 165px;\">\n";
	print "<thead>\n";
	print "<tr>\n";
	print "<th field=\"startday\" width=\"94px\" formatter=\"formatDay\">Start Day</th>\n";
	print "<th field=\"startday\" width=\"94px\" formatter=\"formatTime\">Start Time</th>\n";
	print "<th field=\"endday\" width=\"94px\" formatter=\"formatDay\">End Day</th>\n";
	print "<th field=\"endday\" width=\"94px\" formatter=\"formatTime\">End Time</th>\n";
	print "<th field=\"remove\" width=\"80px\">Remove</th>\n";
	print "</tr>\n";
	print "</thead>\n";
	print "</table>\n";

	print "<div align=\"center\">\n";
	print "<div id=\"savestatus\"></div>\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\" id=\"saveTimesBtn\">\n";
	print "  Save Schedule Times\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$cdata = array('id' => $data['scheduleid']);
	$cont = addContinuationsEntry('AJsaveScheduleTimes', $cdata);
	print "    saveTimes('$cont');\n";
	print "  </script>\n";
	print "</button>\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmEditOrAddSchedule($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a form for confirming changes to a schedule
///
////////////////////////////////////////////////////////////////////////////////
function confirmEditOrAddSchedule($state) {
	global $submitErr;

	$data = processScheduleInput();

	if($submitErr) {
		editOrAddSchedule($state);
		return;
	}

	if($state) {
		$nextmode = "submitAddSchedule";
		$title = "Add Schedule";
		$question = "Add the following schedule?";
	}
	else {
		$nextmode = "submitEditSchedule";
		$title = "Edit Schedule";
		$question = "Submit changes to the schedule?";
	}

	$days = array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
	              "Friday", "Saturday");

	print "<DIV align=center>\n";
	print "<H2>$title</H2>\n";
	print "$question<br><br>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Name:</TH>\n";
	print "    <TD>" . $data["name"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>" . $data["owner"] . "</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('name' => $data['name'],
	               'owner' => $data['owner']);
	if(! empty($data['scheduleid']))
		$cdata['scheduleid'] = $data['scheduleid'];
	$cont = addContinuationsEntry($nextmode, $cdata, SECINDAY, 0, 0, 1);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=viewSchedules>\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
    print "</DIV>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditSchedule()
///
/// \brief submits changes to schedule and notifies user
///
////////////////////////////////////////////////////////////////////////////////
function submitEditSchedule() {
	$data = processScheduleInput(0);
	updateSchedule($data);
	viewSchedules();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddSchedule()
///
/// \brief adds the schedule and notifies user
///
////////////////////////////////////////////////////////////////////////////////
function submitAddSchedule() {
	$data = processScheduleInput(0);
	if($id = addSchedule($data)) {
		$_POST["scheduleid"] = $id;
		$_SESSION['userresources'] = array();
		editOrAddSchedule(0);
	}
	else {
		abort(10);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJgetScheduleTimesData()
///
/// \brief gets start/end times for a schedule and sends in JSON format
///
////////////////////////////////////////////////////////////////////////////////
function AJgetScheduleTimesData() {
	$id = getContinuationVar('id');
	$query = "SELECT start, "
	       .        "end "
	       . "FROM scheduletimes "
	       . "WHERE scheduleid = $id "
	       . "ORDER BY start";
	$qh = doQuery($query, 101);
	$times = array();
	while($row = mysql_fetch_assoc($qh)) {
		$smin = $row['start'] % 1440;
		$sday = (int)($row['start'] / 1440);
		if($sday > 6)
			$sday = 0;
		$emin = $row['end'] % 1440;
		$eday = (int)($row['end'] / 1440);
		if($eday > 6)
			$eday = 0;
		$times[] = array('smin' => $smin,
		                 'sday' => $sday,
		                 'emin' => $emin,
		                 'eday' => $eday);
	}
	sendJSON($times);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteSchedule()
///
/// \brief prints a form to confirm the deletion of a schedule
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteSchedule() {
	$scheduleid = getContinuationVar("scheduleid");
	$schedules = getSchedules();
	$days = array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
	              "Friday", "Saturday");

	$name = $schedules[$scheduleid]["name"];
	$owner = $schedules[$scheduleid]["owner"];

	print "<DIV align=center>\n";
	print "<H2>Delete Schedule</H2>\n";
	print "Delete the following schedule?<br><br>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Name:</TH>\n";
	print "    <TD>$name</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>$owner</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	if(count($schedules[$scheduleid]["times"])) {
		print "<TABLE>\n";
		print "  <TR>\n";
		print "    <TH>Start</TH>\n";
		print "    <TD>&nbsp;</TD>\n";
		print "    <TH>End</TH>\n";
		print "  <TR>\n";
		foreach($schedules[$scheduleid]["times"] as $time) {
			print "  <TR>\n";
			print "    <TD>" . minToDaytime($time["start"]) . "</TD>\n";
			print "    <TD>&nbsp;</TD>\n";
			print "    <TD>" . minToDaytime($time["end"]) . "</TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
	}
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('scheduleid' => $scheduleid);
	$cont = addContinuationsEntry('submitDeleteSchedule', $cdata, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=viewSchedules>\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
    print "</DIV>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteSchedule()
///
/// \brief deletes a schedule from the database and notifies the user
///
////////////////////////////////////////////////////////////////////////////////
function submitDeleteSchedule() {
	$scheduleid = getContinuationVar("scheduleid");
	doQuery("DELETE FROM schedule WHERE id = $scheduleid", 210);
	doQuery("DELETE FROM scheduletimes WHERE scheduleid = $scheduleid", 210);
	doQuery("DELETE FROM resource WHERE resourcetypeid = 15 AND subid = $scheduleid", 210);
	$_SESSION['userresources'] = array();
	$_SESSION['usersessiondata'] = array();
	viewSchedules();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitScheduleGroups()
///
/// \brief updates schedule groupings
///
////////////////////////////////////////////////////////////////////////////////
function submitScheduleGroups() {
	$groupinput = processInputVar("schedulegroup", ARG_MULTINUMERIC);

	$schedules = getSchedules();

	# build an array of memberships currently in the db
	$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"), 1);
	$schedulegroupsIDs = array_keys($tmp["schedule"]);  // ids of groups that user can administer
	$resources = getUserResources(array("scheduleAdmin"), 
	                              array("manageGroup"), 0, 0);
	$userScheduleIDs = array_keys($resources["schedule"]); // ids of schedules that user can administer
	$schedulemembership = getResourceGroupMemberships("schedule");
	$baseschedulegroups = $schedulemembership["schedule"]; // all schedule group memberships
	$schedulegroups = array();
	foreach(array_keys($baseschedulegroups) as $scheduleid) {
		if(in_array($scheduleid, $userScheduleIDs)) {
			foreach($baseschedulegroups[$scheduleid] as $grpid) {
				if(in_array($grpid, $schedulegroupsIDs)) {
					if(array_key_exists($scheduleid, $schedulegroups))
						array_push($schedulegroups[$scheduleid], $grpid);
					else
						$schedulegroups[$scheduleid] = array($grpid);
				}
			}
		}
	}

	# build an array of posted in memberships
	$newmembers = array();
	foreach(array_keys($groupinput) as $key) {
		list($scheduleid, $grpid) = explode(':', $key);
		if(array_key_exists($scheduleid, $newmembers)) {
			array_push($newmembers[$scheduleid], $grpid);
		}
		else {
			$newmembers[$scheduleid] = array($grpid);
		}
	}

	$adds = array();
	$removes = array();
	foreach(array_keys($schedules) as $scheduleid) {
		$id = $schedules[$scheduleid]["resourceid"];
		// if $scheduleids not in $userScheduleIds, don't bother with it
		if(! in_array($scheduleid, $userScheduleIDs))
			continue;
		// if $scheduleid is not in $newmembers or $schedulegroups, do nothing
		if(! array_key_exists($scheduleid, $newmembers) &&
		   ! array_key_exists($scheduleid, $schedulegroups)) {
			continue;
		}
		// check that $scheduleid is in $newmembers, if not, remove it from all groups
		if(! array_key_exists($scheduleid, $newmembers)) {
			$removes[$id] = $schedulegroups[$scheduleid];
			continue;
		}
		// check that $scheduleid is in $schedulegroups, if not, add all groups in
		// $newmembers
		if(! array_key_exists($scheduleid, $schedulegroups)) {
			$adds[$id] = $newmembers[$scheduleid];
			continue;
		}
		// adds are groupids that are in $newmembers, but not in $schedulegroups
		$adds[$id] = array_diff($newmembers[$scheduleid], $schedulegroups[$scheduleid]);
		if(count($adds[$id]) == 0) {
			unset($adds[$id]); 
		}
		// removes are groupids that are in $schedulegroups, but not in $newmembers
		$removes[$id] = array_diff($schedulegroups[$scheduleid], $newmembers[$scheduleid]);
		if(count($removes[$id]) == 0) {
			unset($removes[$id]);
		}
	}

	foreach(array_keys($adds) as $scheduleid) {
		foreach($adds[$scheduleid] as $grpid) {
			$query = "INSERT INTO resourcegroupmembers "
					 . "(resourceid, resourcegroupid) "
			       . "VALUES ($scheduleid, $grpid)";
			doQuery($query, 291);
		}
	}

	foreach(array_keys($removes) as $scheduleid) {
		foreach($removes[$scheduleid] as $grpid) {
			$query = "DELETE FROM resourcegroupmembers "
					 . "WHERE resourceid = $scheduleid AND "
					 .       "resourcegroupid = $grpid";
			doQuery($query, 292);
		}
	}

	viewSchedules();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processScheduleInput($checks)
///
/// \param $checks - (optional) 1 to perform validation, 0 not to
///
/// \return an array with the following indexes:\n
/// scheduleid, name, owner
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processScheduleInput($checks=1) {
	global $submitErr, $submitErrMsg;
	$return = array();
	$return["scheduleid"] = getContinuationVar("scheduleid", processInputVar("scheduleid" , ARG_NUMERIC));
	$return["name"] = getContinuationVar("name", processInputVar("name", ARG_STRING));
	$return["owner"] = getContinuationVar("owner", processInputVar("owner", ARG_STRING));

	if(! $checks)
		return $return;
	
	if(strlen($return["name"]) > 25 || strlen($return["name"]) < 2) {
	   $submitErr |= SCHNAMEERR;
	   $submitErrMsg[SCHNAMEERR] = "Name must be from 2 to 30 characters";
	}
	if(! ($submitErr & SCHNAMEERR) && 
	   checkForScheduleName($return["name"], $return["scheduleid"])) {
	   $submitErr |= SCHNAMEERR;
	   $submitErrMsg[SCHNAMEERR] = "A schedule already exists with this name.";
	}
	if(! validateUserid($return["owner"])) {
	   $submitErr |= SCHOWNERERR;
	   $submitErrMsg[SCHOWNERERR] = "The submitted unity ID is invalid.";
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForScheduleName($name, $id)
///
/// \param $name - the name of a schedule
/// \param $id - id of a schedule to ignore
///
/// \return 1 if $name is already in the schedule table, 0 if not
///
/// \brief checks for $name being in the schedule table except for $id
///
////////////////////////////////////////////////////////////////////////////////
function checkForScheduleName($name, $id) {
	$query = "SELECT id FROM schedule "
	       . "WHERE name = '$name'";
	
	if(! empty($id))
		$query .= " AND id != $id";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateSchedule($data)
///
/// \param $data - an array returned from processScheduleInput
///
/// \return number of rows affected by the update\n
/// \b NOTE: mysql reports that no rows were affected if none of the fields
/// were actually changed even if the update matched a row
///
/// \brief performs a query to update the schedule with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function updateSchedule($data) {
	$ownerid = getUserlistID($data['owner']);
	$query = "UPDATE schedule "
	       . "SET name = '{$data['name']}', "
	       .     "ownerid = $ownerid "
	       . "WHERE id = {$data['scheduleid']}";
	$qh = doQuery($query, 215);
	return mysql_affected_rows($GLOBALS['mysql_link_vcl']);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addSchedule($data)
///
/// \param $data - an array returned from processScheduleInput
///
/// \return number of rows affected by the insert\n
///
/// \brief performs a query to insert the schedule with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function addSchedule($data) {
	$ownerid = getUserlistID($data['owner']);
	$query = "INSERT INTO schedule "
	       .         "(name, "
	       .         "ownerid) "
	       . "VALUES ('{$data['name']}', "
	       .         "$ownerid)";
	doQuery($query, 220);
	$affectedrows = mysql_affected_rows($GLOBALS['mysql_link_vcl']);

	$qh = doQuery("SELECT LAST_INSERT_ID() FROM schedule", 221);
	if(! $row = mysql_fetch_row($qh)) {
		abort(222);
	}
	$query = "INSERT INTO resource "
			 .        "(resourcetypeid, "
			 .        "subid) "
			 . "VALUES (15, "
			 .         "{$row[0]})";
	doQuery($query, 223);
	return $row[0];
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsaveScheduleTimes()
///
/// \brief saves the submitted time for the schedule and notifies the user
///
////////////////////////////////////////////////////////////////////////////////
function AJsaveScheduleTimes() {
	$id = getContinuationVar('id');
	$tmp = processInputVar('times', ARG_STRING);
	if(! preg_match('/^([0-9]+:[0-9]+,)*([0-9]+:[0-9]+){1}$/', $tmp)) {
		print "alert('invalid data submitted');";
		return;
	}
	$times = explode(',', $tmp);
	$newtimes = array();
	$qvals = array();
	foreach($times as $pair) {
		list($start, $end) = explode(':', $pair);
		foreach($newtimes as $check) {
			if($start < $check['end'] && $end > $check['start']) {
				print "alert('Two sets of times are overlapping;\nplease correct and save again.');";
				return;
			}
		}
		$newtimes[] = array('start' => $start, 'end' => $end);
		$qvals[] = "($id, $start, $end)";
	}
	$query = "DELETE FROM scheduletimes WHERE scheduleid = $id";
	doQuery($query, 101);
	$allvals = implode(',', $qvals);
	$query = "INSERT INTO scheduletimes "
	       .        "(scheduleid, start, end) "
			 . "VALUES $allvals";
	doQuery($query, 101);
	print "dijit.byId('saveTimesBtn').attr('disabled', false);";
	print "dojo.byId('savestatus').innerHTML = 'Schedule times successfully saved';";
	print "setTimeout(function() {dojo.byId('savestatus').innerHTML = '';}, 8000);";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn daytimeToMin($day, $time, $startend)
///
/// \param $day - number of day of week (0-6) with 0 being Sunday
/// \param $time - time of day in 'HH:MM mm' format
/// \param $startend - "start" or "end" - need to know if 12:00 am on Sunday
/// is a the beginning of the week or end of the week
///
/// \return minute of the week
///
/// \brief computes minute of the week from the input params - if Sunday at
/// 12:00 am, return 0 if $startend == "start" or 10080 if $startend == "end"
///
////////////////////////////////////////////////////////////////////////////////
function daytimeToMin($day, $time, $startend) {
	if(! preg_match('/^(((0)?([1-9]))|(1([0-2]))):([0-5][0-9]) ((am)|(pm))/', $time))
		return -1;
	list($hour, $other) = explode(':', $time);
	list($min, $meridian) = explode(' ', $other);
	if($meridian == "am" && $hour == 12) {
		if($startend == "end" && $day == 0 && $min == 0)
			$day = 7;
		$hour = 0;
	}
	elseif($meridian == "pm" && $hour != 12) {
		$hour += 12;
	}
	return (($hour * 60) + $min) + ($day * 1440);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn minToDaytime($min)
///
/// \param $min - minute of the week
///
/// \return day of week and time of day
///
/// \brief calculates day of week and time of day from $min and returns a
/// nicely formatted string of "Weekday&nbsp;HH:MM am/pm"
///
////////////////////////////////////////////////////////////////////////////////
function minToDaytime($min) {
	$days = array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
	              "Friday", "Saturday");
	$time = minuteToTime($min % 1440);
	if((int)($min / 1440) == 0) {
		$day = 0;
	}
	elseif((int)($min / 1440) == 1) {
		$day = 1;
	}
	elseif((int)($min / 1440) == 2) {
		$day = 2;
	}
	elseif((int)($min / 1440) == 3) {
		$day = 3;
	}
	elseif((int)($min / 1440) == 4) {
		$day = 4;
	}
	elseif((int)($min / 1440) == 5) {
		$day = 5;
	}
	elseif((int)($min / 1440) == 6) {
		$day = 6;
	}
	elseif((int)($min / 1440) > 6) {
		$day = 0;
	}
	return $days[$day] . "&nbsp;$time";
}

?>
