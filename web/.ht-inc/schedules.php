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
	print "<TABLE border=1>\n";
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
		print "<TABLE border=1>\n";
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
	global $submitErr, $mode, $submitErrMsg;

	$schedules = getSchedules();
	$days = array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
	              "Friday", "Saturday");

	$newcont = 0;
	if($submitErr || $mode == "submitScheduleTime" || $mode == "submitAddSchedule") {
		$data = processScheduleInput(0);
		$newcont = 1; # continuation to get here was deleted; so, we'll need to set
		              #   deletefromself true this time
	}
	else {
		$data["scheduleid"] = getContinuationVar("scheduleid");
		$id = $data["scheduleid"];
		$data["name"] = $schedules[$id]["name"];
		$data["owner"] = $schedules[$id]["owner"];
		$data["submode"] = processInputVar("submode", ARG_STRING);
	}
	$schedules = getSchedules();
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
	if($state)
		return;
	print "The start and end day/times are based on a week's time period with ";
	print "the start/end point being 'Sunday 12:00&nbsp;am'. i.e. The earliest ";
	print "start day/time is 'Sunday 12:00&nbsp;am' and the latest end day/";
	print "time is 'Sunday 12:00&nbsp;am'<br><br>\n";
	if(! $submitErr && $mode == "submitScheduleTime" && $data["submode"] == "Save changes") {
		print "<font color=green>Changes saved</font><br>\n";
	}
	printSubmitErr(OVERLAPERR);
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH>Start</TH>\n";
	print "    <TD></TD>\n";
	print "    <TH>End</TH>\n";
	print "    <TD></TD>\n";
	print "  </TR>\n";
	$addrow = 0;
	if($mode == "submitScheduleTime") {
		$addrow = 1;
	}
	print "<TR><TD colspan=5>";
	print "</TD></TR>\n";
	$doaddrow = 0;
	if($mode == "submitScheduleTime") {
		if($data["selrow"] == "")
			$end = $data["count"];
		elseif($data["submode"] == "Insert before selected row") {
			$doaddrow = 1;
			$addrow = $data["selrow"];
			$end = $data["count"] + 1;
		}
		elseif($data["submode"] == "Insert after selected row") {
			$doaddrow = 1;
			$addrow = $data["selrow"] + 1;
			$end = $data["count"] + 1;
		}
		else
			$end = $data["count"];
	}
	else
		$end = count($schedules[$data["scheduleid"]]["times"]);
	if($end == 0) {
		$doaddrow = 1;
		$addrow = 0;
		$end = 1;
	}
	reset($schedules[$data["scheduleid"]]["times"]);
	$index = 0;
	for($count = 0; $count < $end; $count++) {
		// if mode == submitScheduleTime, print submitted times
		if($mode == "submitScheduleTime") {
			if($doaddrow && $count == $addrow) {
				$startday = "";
				$starttime = "";
				$endday = "";
				$endtime = "";
				$doaddrow = 0;
				$index--;
			}
			else {
				$startday = $data["startDay"][$index];
				$starttime = $data["startTime"][$index];
				$endday = $data["endDay"][$index];
				$endtime = $data["endTime"][$index];
			}
			print "  <TR>\n";
			print "    <TD align=right><INPUT type=radio name=selrow value=$count></TD>\n";
			printStartEndTimeForm2($startday, $starttime, $count, "start");
			print "    <TD>&nbsp;&nbsp;</TD>\n";
			printStartEndTimeForm2($endday, $endtime, $count, "end");
		}
		// otherwise, print times from database
		else {
			$time = current($schedules[$data["scheduleid"]]["times"]);
			print "  <TR>\n";
			print "    <TD align=right><INPUT type=radio name=selrow value=$count></TD>\n";
			printStartEndTimeForm($time["start"], $count, "start");
			print "    <TD>&nbsp;&nbsp;</TD>\n";
			printStartEndTimeForm($time["end"], $count, "end");
			next($schedules[$data["scheduleid"]]["times"]);
		}
		print "    <TD width=70>";
		if($data["submode"] == "Save changes")
			printSubmitErr(1 << $count);
		print "</TD>";
		print "  </TR>\n";
		$index++;
	}
	$colspan = 5;
	print "  <TR>\n";
	print "    <TD align=center colspan=$colspan><INPUT type=submit name=submode value=\"Delete selected row\"></TD>\n";
	print "  <TR>\n";
	print "  </TR>\n";
	print "    <TD align=center colspan=$colspan><INPUT type=submit name=submode value=\"Insert before selected row\"></TD>\n";
	print "  <TR>\n";
	print "  </TR>\n";
	print "    <TD align=center colspan=$colspan><INPUT type=submit name=submode value=\"Insert after selected row\"></TD>\n";
	print "  <TR>\n";
	print "  </TR>\n";
	print "    <TD align=center colspan=$colspan><INPUT type=submit name=submode value=\"Save changes\"></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	$cdata = array('scheduleid' => $data['scheduleid'],
	               'count' => $count,
	               'name' => $data['name'],
	               'owner' => $data['owner']);
	if($newcont)
		$cont = addContinuationsEntry('submitScheduleTime', $cdata, SECINDAY, 1, 0);
	else
		$cont = addContinuationsEntry('submitScheduleTime', $cdata, SECINDAY, 0, 0);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM>\n";
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
	$tmp = getUserResources(array("groupAdmin"), array("administer"), 1);
	$schedulegroupsIDs = array_keys($tmp["schedule"]);  // ids of groups that user can administer
	$resources = getUserResources(array("scheduleAdmin"), 
	                              array("administer"), 0, 0);
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
/// scheduleid, name, owner, submode, selrow, count, startDay, startTime,
/// endDay, endTime
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processScheduleInput($checks=1) {
	global $submitErr, $submitErrMsg;
	$return = array();
	$return["start"] = array();
	$return["end"] = array();

	$return["scheduleid"] = getContinuationVar("scheduleid", processInputVar("scheduleid" , ARG_NUMERIC));
	$return["name"] = getContinuationVar("name", processInputVar("name", ARG_STRING));
	$return["owner"] = getContinuationVar("owner", processInputVar("owner", ARG_STRING));
	$return["submode"] = processInputVar("submode", ARG_STRING);
	$return["selrow"] = processInputVar("selrow", ARG_NUMERIC);
	$return["count"] = getContinuationVar("count", processInputVar("count", ARG_NUMERIC, 0));
	$return["startDay"] = processInputVar("startDay", ARG_MULTINUMERIC);
	$return["startTime"] = processInputVar("startTime", ARG_MULTISTRING);
	$return["endDay"] = processInputVar("endDay", ARG_MULTINUMERIC);
	$return["endTime"] = processInputVar("endTime", ARG_MULTISTRING);

	if(! $checks) {
		return $return;
	}
	
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
	for($i = 0; $i < $return["count"]; $i++) {
		if((! ereg('^((0?[1-9])|(1[0-2])):([0-5][0-9]) (am|pm)$', $return["startTime"][$i])) ||
		   (! ereg('^((0?[1-9])|(1[0-2])):([0-5][0-9]) (am|pm)$', $return["endTime"][$i]))) {
			$submitErr |= (1 << $i);
			$submitErrMsg[1 << $i] = "Time must be of the form [H]H:MM&nbsp;am/pm";
		}
		elseif(daytimeToMin($return["startDay"][$i], $return["startTime"][$i], "start") >=
		       daytimeToMin($return["endDay"][$i], $return["endTime"][$i], "end")) {
			$submitErr |= (1 << $i);
			$submitErrMsg[1 << $i] = "The start day/time must be before the end day/time";
		}
	}
	for($i = 0; $i < $return["count"] - 1; $i++) {
		for($j = $i + 1; $j < $return["count"]; $j++) {
			if(daytimeToMin($return["startDay"][$i], $return["startTime"][$i], "start") <
			   daytimeToMin($return["endDay"][$j], $return["endTime"][$j], "end") &&
			   daytimeToMin($return["endDay"][$i], $return["endTime"][$i], "end") >
			   daytimeToMin($return["startDay"][$j], $return["startTime"][$j], "start")) {
				$submitErr |= OVERLAPERR;
				$submitErrMsg[OVERLAPERR] = "At least 2 of the time periods overlap. Please combine them into a single entry.";
				break(2);
			}
		}
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
	$ownerid = getUserlistID($data["owner"]);
	$query = "UPDATE schedule "
	       . "SET name = '" . $data["name"] . "', "
	       .     "ownerid = $ownerid "
	       . "WHERE id = " . $data["scheduleid"];
	$qh = doQuery($query, 215);
	return mysql_affected_rows($GLOBALS["mysql_link_vcl"]);
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
	$ownerid = getUserlistID($data["owner"]);
	$query = "INSERT INTO schedule "
	       .         "(name, "
	       .         "ownerid) "
	       . "VALUES ('" . $data["name"] . "', "
	       .         "$ownerid)";
	doQuery($query, 220);
	$affectedrows = mysql_affected_rows($GLOBALS["mysql_link_vcl"]);

	$qh = doQuery("SELECT LAST_INSERT_ID() FROM schedule", 221);
	if(! $row = mysql_fetch_row($qh)) {
		abort(222);
	}
	$query = "INSERT INTO resource "
			 .        "(resourcetypeid, "
			 .        "subid) "
			 . "VALUES (15, "
			 .         $row[0] . ")";
	doQuery($query, 223);
	return $row[0];
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printStartEndTimeForm($min, $count, $startend)
///
/// \param $min - minute in the week, pass empty string to get an empty text
/// entry field
/// \param $count - counter value - used to keep track of which row this is
/// \param $startend - "start" or "end"
///
/// \brief prints a select input for the day of week and a text entry field
/// for the time to be entered
///
////////////////////////////////////////////////////////////////////////////////
function printStartEndTimeForm($min, $count, $startend) {
	$days = array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
	              "Friday", "Saturday");
	if($min == "") {
		print "    <TD>\n";
		printSelectInput("$startend" . "Day[$count]", $days);
		$name = $startend . "Time[$count]";
		print "      <INPUT type=text name=$name size=8 mazlength=8>\n";
		print "    </TD>\n";
		return;
	}
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
	print "    <TD>\n";
	printSelectInput("$startend" . "Day[$count]", $days, $day);
	$name = $startend . "Time[$count]";
	print "      <INPUT type=text name=$name value=\"$time\" size=8 maxlength=8>\n";
	print "    </TD>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printStartEndTimeForm2($day, $time, $count, $startend)
///
/// \param $day - numeric day of week with Sunday being 0
/// \param $time - time of day in string format HH:MM am/pm
/// \param $count - counter value - used to keep track of which row this is
/// \param $startend - "start" or "end"
///
/// \brief prints a select input for the day of week and a text entry field
/// for the time to be entered
///
////////////////////////////////////////////////////////////////////////////////
function printStartEndTimeForm2($day, $time, $count, $startend) {
	$days = array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
	              "Friday", "Saturday");
	print "    <TD>\n";
	printSelectInput("$startend" . "Day[$count]", $days, $day);
	$name = $startend . "Time[$count]";
	print "      <INPUT type=text name=$name value=\"$time\" size=8 maxlength=8>\n";
	print "    </TD>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitScheduleTime()
///
/// \brief handles submitting date/time form for schedule times and calls
/// editOrAddSchedule(0) again
///
////////////////////////////////////////////////////////////////////////////////
function submitScheduleTime() {
	global $submitErr, $contdata;

	if($_POST["submode"] == "Save changes") {
		$data = processScheduleInput(1);
		if($submitErr) {
			editOrAddSchedule(0);
			return;
		}
	}
	else {
		$data = processScheduleInput(0);
		if($data["selrow"] == "") {
			editOrAddSchedule(0);
			return;
		}
	}

	if($data["submode"] == "Delete selected row") {
		// delete entry from db
		$start = daytimeToMin($data["startDay"][$data["selrow"]], $data["startTime"][$data["selrow"]], "start");
		$end = daytimeToMin($data["endDay"][$data["selrow"]], $data["endTime"][$data["selrow"]], "end");
		$query = "DELETE FROM scheduletimes "
		       . "WHERE scheduleid = {$data["scheduleid"]} AND "
		       .       "start = $start AND "
		       .       "end = $end";
		doQuery($query, 101);
		// decrease all values by 1 that are > deleted row
		for($i = 0; $i < $data["count"] - 1; $i++) {
			if($i >= $data["selrow"]) {
				$_POST["startDay"][$i] = $_POST["startDay"][$i + 1];
				$_POST["startTime"][$i] = $_POST["startTime"][$i + 1];
				$_POST["endDay"][$i] = $_POST["endDay"][$i + 1];
				$_POST["endTime"][$i] = $_POST["endTime"][$i + 1];
			}
		}
		unset($_POST["startDay"][$i]);
		unset($_POST["startTime"][$i]);
		unset($_POST["endDay"][$i]);
		unset($_POST["endTime"][$i]);
		$contdata["count"]--;
		editOrAddSchedule(0);
	}
	elseif($data["submode"] == "Insert before selected row") {
		editOrAddSchedule(0);
	}
	elseif($data["submode"] == "Insert after selected row") {
		editOrAddSchedule(0);
	}
	elseif($data["submode"] == "Save changes") {
		$query = "DELETE FROM scheduletimes WHERE scheduleid = {$data["scheduleid"]}";
		doQuery($query, 101);
		for($i = 0; $i < $data["count"]; $i++) {
			$start = daytimeToMin($data["startDay"][$i], $data["startTime"][$i], "start");
			$end = daytimeToMin($data["endDay"][$i], $data["endTime"][$i], "end");
			$query = "INSERT INTO scheduletimes "
			       .        "(scheduleid, "
			       .        "start, "
			       .        "end) "
			       . "VALUES ({$data["scheduleid"]}, "
			       .        "$start, "
			       .        "$end)";
			doQuery($query, 101);
		}
		editOrAddSchedule(0);
	}
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
	if(! ereg('^(((0)?([1-9]))|(1([0-2]))):([0-5][0-9]) ((am)|(pm))', $time))
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
