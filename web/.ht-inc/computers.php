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

/// signifies an error with the submitted IP address (or start IP address)
define("IPADDRERR", 1);
/// signifies an error with the submitted RAM
define("RAMERR", 1 << 1);
/// signifies an error with the submitted processor speed
define("PROCSPEEDERR", 1 << 2);
/// signifies an error with the submitted hostname
define("HOSTNAMEERR", 1 << 3);
/// signifies an error with the submitted end IP address
define("IPADDRERR2", 1 << 4);
/// signifies an error with the submitted start host value
define("STARTHOSTVALERR", 1 << 5);
/// signifies an error with the submitted end host value
define("ENDHOSTVALERR", 1 << 6);
/// signifies an error with the submitted owner
define("OWNERERR", 1 << 7);
/// signifies an error with the submitted start private IP address
define("IPADDRERR3", 1 << 8);
/// signifies an error with the submitted end private IP address
define("IPADDRERR4", 1 << 9);
/// signifies an error with the submitted start mac address or public mac address
define("MACADDRERR", 1 << 10);
/// signifies an error with the submitted machine type/state combination
define("VMAVAILERR", 1 << 11);
/// signifies an error with the submitted private mac address
define("MACADDRERR2", 1 << 12);
/// signifies an error about moving node to vmhostinuse state
define("VMHOSTINUSEERR", 1 << 13);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectComputers()
///
/// \brief prints a form to select which computers to view
///
////////////////////////////////////////////////////////////////////////////////
function selectComputers() {
	global $user;
	$test = getComputers();
	if(empty($test)) {
		addComputerPrompt();
		return;
	}

	$data = getUserComputerMetaData();

	# get a list of computer groups user can manage
	$tmp = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	$computergroups = $tmp["computer"];
	if((empty($data["platforms"]) || empty($data["schedules"])) &&
	   empty($computergroups)) {
		print "<H2>Computers</H2>\n";
		print "You do not have access to manage any computers.<br>\n";
		return;
	}

	$platform_cnt = count($data["platforms"]);
	$schedule_cnt = count($data["schedules"]);

	# get a count of schedules user can manage
	$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"));
	$scheduleAdminCnt = count($tmp['schedule']);

	# get a list of computers user can manage
	$tmp = getUserResources(array("computerAdmin"), array("administer"));
	$computers = $tmp["computer"];

	print "<H2 align=center>Computers</H2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array();
	if($platform_cnt > 1 || $schedule_cnt > 1) {
		print "Select the criteria for the computers you want to view:\n";

		print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
		print "     style=\"width:300px;height:275px\">\n";
		# by groups
		$size = count($computergroups);
		if($size > 13)
			$size = 13;
		print "<div id=\"groups\" dojoType=\"dijit.layout.ContentPane\" ";
		print "title=\"Computer Groups\" align=center selected=\"true\">\n";
		printSelectInput("groups[]", $computergroups, -1, 0, 1, '', "size=$size");
		print "</div>\n";
		# by platform/schedule
		print "<div id=\"platsch\" dojoType=\"dijit.layout.ContentPane\" title=\"Platforms/Schedules\">\n";
		print "<TABLE summary=\"\">\n";
		print "  <TR>\n";
		if($platform_cnt > 1)
			print "    <TH>Platforms:</TH>\n";
		if($schedule_cnt > 1)
			print "    <TH>Schedules:</TH>\n";
		print "  </TR>\n";
		print "  <TR valign=top>\n";
		if($platform_cnt > 1) {
			print "    <TD>\n";
			printSelectInput("platforms[]", $data["platforms"], -1, 0, 1);
			print "    </TD>\n";
		}
		else {
			$tmp = array_keys($data["platforms"]);
			$platform_key = $tmp[0];
			$cdata['platforms'] = array($platform_key);
		}
		if($schedule_cnt > 1) {
			print "    <TD>\n";
			printSelectInput("schedules[]", $data["schedules"], -1, 0, 1, '', 'size=11');
			print "    </TD>\n";
		}
		else {
			$tmp = array_keys($data["schedules"]);
			$schedule_key = $tmp[0];
			$cdata['schedules'] = array($schedule_key);
		}
		print "  </TR>\n";
		print "</TABLE>\n";
		print "</div>\n";
		print "</div><br>\n";

	}
	else {
		$size = count($computergroups);
		if($size > 1) {
			if($size > 13)
				$size = 13;
			print "Select the computer groups you want to view:<br>\n";
			print "<small>(do not select any to view all computers to which you have access)</small><br>\n";
			printSelectInput("groups[]", $computergroups, -1, 0, 1, '', "size=$size");
			print "<br><br>\n";
		}
		$tmp = array_keys($data["platforms"]);
		$platform_key = $tmp[0];
		$cdata['platforms'] = array($platform_key);
		$tmp = array_keys($data["schedules"]);
		$schedule_key = $tmp[0];
		$cdata['schedules'] = array($schedule_key);
	}
	if(count($computergroups)) {
		$cont = addContinuationsEntry('viewComputerGroups', $cdata);
		print "<INPUT type=radio id=editcomp name=continuation value=\"$cont\">\n";
		print "<label for=editcomp>Edit Computer Grouping</label><br><br>\n";
	}
	if(count($computers)) {
		$cont = addContinuationsEntry('computerUtilities', $cdata);
		print "<INPUT type=radio id=computil name=continuation value=\"$cont\" checked>\n";
		print "<label for=computil>Computer Utilities</label><br><br>\n";
	}
	if($scheduleAdminCnt) {
		$cont = addContinuationsEntry('viewComputers', $cdata);
		print "<INPUT type=radio id=viewcomp name=continuation value=\"$cont\">";
		print "<label for=viewcomp>Edit Computer Information:</label>\n";
		print "<TABLE>\n";
		print "  <TR nowrap>\n";
		print "    <TD rowspan=9><img src=\"images/blank.gif\" width=20></TD>\n";
		print "    <TD><INPUT type=checkbox id=showhostname name=showhostname ";
		print "value=1 checked><label for=showhostname>Hostname</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=shownextimage name=";
		print "shownextimage value=1><label for=shownextimage>";
		print "Next Image</TD>\n";
		print "  </TR>\n";
		print "  <TR nowrap>\n";
		print "    <TD><INPUT type=checkbox id=showipaddress name=showipaddress ";
		print "value=1 checked><label for=showipaddress>IP Address</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=showram name=showram value=1>";
		print "<label for=showram>RAM</label></TD>\n";
		print "  </TR>\n";
		print "  <TR nowrap>\n";
		print "    <TD><INPUT type=checkbox id=showstate name=showstate value=1 ";
		print "checked><label for=showstate>State</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=showprocnumber name=showprocnumber ";
		print "value=1><label for=showprocnumber>No. Cores</label></TD>\n";
		print "  </TR>\n";
		print "  <TR nowrap>\n";
		print "    <TD><INPUT type=checkbox id=showcurrentimage name=";
		print "showcurrentimage value=1 checked><label for=showcurrentimage>";
		print "Current Image</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=showprocspeed name=showprocspeed ";
		print "value=1><label for=showprocspeed>Processor Speed</label></TD>\n";
		print "  </TR>\n";
		print "  <TR nowrap>\n";
		print "    <TD><INPUT type=checkbox id=showowner name=showowner value=1>";
		print "<label for=showowner>Owner</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=shownetwork name=shownetwork ";
		print "value=1><label for=shownetwork>Network Speed</label></TD>\n";
		print "  </TR>\n";
		print "  <TR nowrap>\n";
		print "    <TD><INPUT type=checkbox id=showplatform name=showplatform ";
		print "value=1 checked><label for=showplatform>Platform</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=showcomputerid name=showcomputerid ";
		print "value=1><label for=showcomputerid>Computer ID</label></TD>\n";
		print "  </TR>\n";
		print "  <TR nowrap>\n";
		print "    <TD><INPUT type=checkbox id=showschedule name=showschedule ";
		print "value=1 checked><label for=showschedule>Schedule</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=showtype name=showtype value=1>";
		print "<label for=showtype>Type</label></TD>\n";
		print "  </TR>\n";
		print "  <TR nowrap>\n";
		print "    <TD><INPUT type=checkbox id=shownotes name=shownotes value=1>";
		print "<label for=shownotes>Notes</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=showcounts name=showcounts value=1>";
		print "<label for=showcounts>No. Reservations</label></TD>\n";
		print "  </TR>\n";
		print "  <TR nowrap>\n";
		print "    <TD><INPUT type=checkbox id=showprovisioning ";
		print "name=showprovisioning value=1>";
		print "<label for=showprovisioning>Provisioning Engine</label></TD>\n";
		print "    <TD><INPUT type=checkbox id=showlocation name=showlocation ";
		print "value=1><label for=showlocation>Location</label></TD>\n";
		print "  </TR>\n";
		print "</TABLE>\n";
	}
	print "<INPUT type=submit value=Submit>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewComputers($showall)
///
/// \param $showall - (optional) show all computer columns reguardless of what
/// was checked
///
/// \brief prints out information about the computers in the db
///
////////////////////////////////////////////////////////////////////////////////
function viewComputers($showall=0) {
	global $user, $mode;
	$data = processComputerInput();
	if(empty($data['groups']))
		$bygroups = 0;
	else {
		$bygroups = 1;
		$compidlist = getCompIdList($data['groups']);
	}

	if($data["showdeleted"]) {
		$computers = getComputers(1, 1);
		$resources = getUserResources(array("computerAdmin"), 
		                              array("administer"), 0, 1);
	}
	else {
		$computers = getComputers(1);
		$resources = getUserResources(array("computerAdmin"), array("administer"));
	}
	if($data["showcounts"])
		getComputerCounts($computers);
	$userCompIDs = array_keys($resources["computer"]);
	$states = array("2" => "available",
	                "10" => "maintenance",
	                "20" => "vmhostinuse");
	$platforms = getPlatforms();
	$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"));
	$schedules = $tmp["schedule"];
	$allschedules = getSchedules();
	$images = getImages(1);
	$provisioning = getProvisioning();

	if($mode == "viewComputers")
		print "<H2>Computers</H2>\n";
	elseif($mode == "submitEditComputer" || $mode == "computerAddedMaintenceNote") {
		print "<H2>Edit Computer</H2>\n";
		print "<font color=\"#008000\">computer successfully updated</font><br><br>\n";
	}
	elseif($mode == "submitDeleteComputer") {
		print "<H2>Delete Computer</H2>\n";
		$deleted = getContinuationVar("deleted");
		if($deleted) {
			print "<font color=\"#008000\">computer successfully restored to the normal ";
			print "state</font><br><br>\n";
		}
		else {
			print "<font color=\"#008000\">computer successfully set to the deleted ";
			print "state</font><br><br>\n";
		}
	}
	elseif($mode == "submitAddComputer") {
		print "<H2>Add Computer</H2>\n";
		print "<font color=\"#008000\">computer successfully added</font><br><br>\n";
	}
	if(! count($schedules)) {
		print "You don't have access to manage any schedules.  You must be able ";
		print "to manage at least one schedule before you can manage computers.";
		print "<br>\n";
		return;
	}

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post style=\"display: inline\">\n";
	print "<INPUT type=submit value=\"Add Single Computer\">\n";
	$cdata = getComputerSelection($data);
	$cdata['states'] = $states;
	$cont = addContinuationsEntry('addComputer', $cdata);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM>\n";

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post style=\"display: inline\">\n";
	print "<INPUT type=submit value=\"Add Multiple Computers\">\n";
	$cdata = getComputerSelection($data);
	$cdata['states'] = $states;
	$cont = addContinuationsEntry('bulkAddComputer', $cdata);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM><br><br>\n";

	print "<TABLE border=1 id=layouttable>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TD></TD>\n";
	if($data["showhostname"] || $showall)
		print "    <TH>Hostname</TH>\n";
	if($data["showipaddress"] || $showall)
		print "    <TH>IP Address</TH>\n";
	if($data["showstate"] || $showall)
		print "    <TH>State</TH>\n";
	if($data["showowner"] || $showall)
		print "    <TH>Owner</TH>\n";
	if($data["showplatform"] || $showall)
		print "    <TH>Platform</TH>\n";
	if($data["showschedule"] || $showall)
		print "    <TH>Schedule</TH>\n";
	if($data["showcurrentimage"] || $showall)
		print "    <TH>Current Image</TH>\n";
	if($data["shownextimage"] || $showall)
		print "    <TH>Next Image</TH>\n";
	if($data["showram"] || $showall)
		print "    <TH>RAM(MB)</TH>\n";
	if($data["showprocnumber"] || $showall)
		print "    <TH>No. Cores</TH>\n";
	if($data["showprocspeed"] || $showall)
		print "    <TH>Processor Speed(MHz)</TH>\n";
	if($data["shownetwork"] || $showall)
		print "    <TH>Network Speed(Mbps)</TH>\n";
	if($data["showcomputerid"] || $showall)
		print "    <TH>Computer ID</TH>\n";
	if($data["showtype"] || $showall)
		print "    <TH>Type</TH>\n";
	if($data["showprovisioning"] || $showall)
		print "    <TH>Provisioning Engine</TH>\n";
	if($data["showdeleted"])
		print "    <TH>Deleted</TH>\n";
	if($data["shownotes"] || $showall)
		print "    <TH>Notes</TH>\n";
	if($data["showcounts"] || $showall)
		print "    <TH>No. of Reservations</TH>\n";
	if($data["showlocation"] || $showall)
		print "    <TH>Location</TH>\n";
	print "  </TR>\n";
	$count = 0;
	foreach(array_keys($computers) as $id) {
		if($bygroups) {
			if(! array_key_exists($id, $compidlist))
				continue;
		}
		elseif(! in_array($computers[$id]["platformid"], $data["platforms"]) ||
		   ! in_array($computers[$id]["scheduleid"], $data["schedules"])) 
			continue;
		if(! in_array($id, $userCompIDs)) {
			continue;
		}
		print "  <TR align=center>\n";
		print "    <TD align=center>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = $data;
		$cdata['compid'] = $id;
		$cont = addContinuationsEntry('confirmDeleteComputer', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		if($data["showdeleted"] && $computers[$id]["deleted"])
			print "      <INPUT type=submit value=Undelete>\n";
		else
			print "      <INPUT type=submit value=Delete>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = $data;
		$cdata['compid'] = $id;
		$cont = addContinuationsEntry('editComputer', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		if($computers[$id]["deleted"] == 0)
			print "      <INPUT type=submit value=Edit>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		if($data["showhostname"])
			print "    <TD>" . $computers[$id]["hostname"] . "</TD>\n";
		if($data["showipaddress"])
			print "    <TD>" . $computers[$id]["IPaddress"] . "</TD>\n";
		if($data["showstate"])
			print "    <TD>" . $computers[$id]["state"] . "</TD>\n";
		if($data["showowner"])
			print "    <TD>" . $computers[$id]["owner"] . "</TD>\n";
		if($data["showplatform"]) {
			print "    <TD>" . $platforms[$computers[$id]["platformid"]];
			print "</TD>\n";
		}
		if($data["showschedule"]) {
			print "    <TD>" . $allschedules[$computers[$id]["scheduleid"]]["name"];
			print "</TD>\n";
		}
		if($data["showcurrentimage"]) {
			print "    <TD>" . $images[$computers[$id]["currentimgid"]]["prettyname"];
			print "</TD>\n";
		}
		if($data["shownextimage"]) {
			if($computers[$id]['nextimgid'])
				$next = $images[$computers[$id]["nextimgid"]]["prettyname"];
			else
				$next = "(selected&nbsp;by&nbsp;system)";
			print "    <TD>$next</TD>\n";
		}
		if($data["showram"])
			print "    <TD>" . $computers[$id]["ram"] . "</TD>\n";
		if($data["showprocnumber"])
			print "    <TD>" . $computers[$id]["procnumber"] . "</TD>\n";
		if($data["showprocspeed"])
			print "    <TD>" . $computers[$id]["procspeed"] . "</TD>\n";
		if($data["shownetwork"])
			print "    <TD>" . $computers[$id]["network"] . "</TD>\n";
		if($data["showcomputerid"])
			print "    <TD>$id</TD>\n";
		if($data["showtype"])
			print "    <TD>" . $computers[$id]["type"] . "</TD>\n";
		if($data["showprovisioning"])
			print "    <TD>" . $computers[$id]["provisioning"] . "</TD>\n";
		if($data["showdeleted"]) {
			if($computers[$id]["deleted"])
				print "    <TD>yes</TD>\n";
			else
				print "    <TD>no</TD>\n";
		}
		if($data["shownotes"])
			if(empty($computers[$id]["notes"]))
				print "    <TD>&nbsp;</TD>\n";
			else {
				print "    <TD>" . str_replace('@', '<br>', $computers[$id]["notes"]);
				print "</TD>\n";
			}
		if($data["showcounts"])
			print "    <TD>{$computers[$id]["counts"]}</TD>\n";
		if($data["showlocation"])
			print "    <TD>{$computers[$id]["location"]}</TD>\n";
		print "  </TR>\n";
		$count++;
	}
	print "</TABLE>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = processComputerInput2();
	if($data["showdeleted"]) {
		$cdata['showdeleted'] = 0;
		print "<INPUT type=submit value=\"Hide Deleted Computers\">\n";
	}
	else {
		$cdata['showdeleted'] = 1;
		print "<INPUT type=submit value=\"Include Deleted Computers\">\n";
	}
	$cont = addContinuationsEntry('viewComputers', $cdata);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM>\n";
	print "<br>$count computers found<br>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addComputerPrompt()
///
/// \brief prints a page to add computers when there are none in the db
///
////////////////////////////////////////////////////////////////////////////////
function addComputerPrompt() {
	print "<h2>Add Computers</h2>\n";
	print "There are currently no computers in the VCL database. Would you like ";
	print "to add a single computer or add multiple computers in bulk? To add ";
	print "them in bulk, they'll need to have contiguous IP addresses and have ";
	print "hostnames that only differ by a number in the hostname with those ";
	print "numbers being contiguous.<br><br>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('nocomps' => 1);
	$cont = addContinuationsEntry('addComputer', $cdata);
	print "<INPUT type=radio name=continuation value=\"$cont\">\n";
	print "<label for=editcomp>Add Single Computer</label><br>\n";
	$cont = addContinuationsEntry('bulkAddComputer');
	print "<INPUT type=radio name=continuation value=\"$cont\">\n";
	print "<label for=editcomp>Add Multiple Computers</label><br><br>\n";
	print "<INPUT type=submit value=Submit>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editOrAddComputer($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a page to edit a given comptuer
///
////////////////////////////////////////////////////////////////////////////////
function editOrAddComputer($state) {
	global $submitErr, $submitErrMsg, $mode;
	$data2 = processComputerInput2();

	$computers = getComputers();

	$nocomps = getContinuationVar('nocomps', 0);
	if($submitErr) {
		$data = processComputerInput();
	}
	elseif($nocomps || $state == 1) {
		$data = array();
		$data["ipaddress"] = '';
		$data["pripaddress"] = '';
		$data["eth0macaddress"] = '';
		$data["eth1macaddress"] = '';
		$data["stateid"] = '';
		$data["owner"] = '';
		$data["platformid"] = '';
		$data["scheduleid"] = '';
		$data["currentimgid"] = '';
		$data["ram"] = '';
		$data["numprocs"] = '1';
		$data["procspeed"] = '';
		$data["network"] = '1000';
		$data["hostname"] = '';
		$data["type"] = 'blade';
		$data["notes"] = '';
		$data["computergroup"] = array();
		$data["provisioningid"] = '';
		$data["location"] = '';
		$data["vmprofileid"] = '';
	}
	else {
		$data["compid"] = getContinuationVar("compid");
		$id = $data["compid"];
		$data["ipaddress"] = $computers[$id]["IPaddress"];
		$data["pripaddress"] = $computers[$id]["privateIPaddress"];
		$data["eth0macaddress"] = $computers[$id]["eth0macaddress"];
		$data["eth1macaddress"] = $computers[$id]["eth1macaddress"];
		$data["stateid"] = $computers[$id]["stateid"];
		$data["owner"] = $computers[$id]["owner"];
		$data["platformid"] = $computers[$id]["platformid"];
		$data["scheduleid"] = $computers[$id]["scheduleid"];
		$data["currentimgid"] = $computers[$id]["currentimgid"];
		$data["ram"] = $computers[$id]["ram"];
		$data["numprocs"] = $computers[$id]["procnumber"];
		$data["procspeed"] = $computers[$id]["procspeed"];
		$data["network"] = $computers[$id]["network"];
		$data["hostname"] = $computers[$id]["hostname"];
		$data["type"] = $computers[$id]["type"];
		$data["notes"] = $computers[$id]["notes"];
		$data["provisioningid"] = $computers[$id]["provisioningid"];
		$data["location"] = $computers[$id]["location"];
		$data["vmprofileid"] = $computers[$id]['vmprofileid'];
	}
	
	$tmpstates = getStates();
	if($data["stateid"] && array_key_exists($data['stateid'], $tmpstates)) {
		$states = array($data["stateid"] => $tmpstates[$data["stateid"]],
		                2 => "available",
		                10 => "maintenance",
		                20 => "vmhostinuse");
	}
	else
		$states = array(2 => "available",
		                10 => "maintenance",
		                20 => "vmhostinuse");
	# check for reservation to move computer to vmhostinuse
	$tovmhostinuse = 0;
	if($state == 0 && $computers[$data['compid']]['stateid'] != 20) {
		$query = "SELECT UNIX_TIMESTAMP(rq.start) AS start "
		       . "FROM request rq, "
		       .      "reservation rs, "
		       .      "state ls, "
		       .      "state cs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid = {$data['compid']} AND "
		       .       "rq.laststateid = ls.id AND "
		       .       "rq.stateid = cs.id AND "
		       .       "ls.name = 'tovmhostinuse' AND "
		       .       "cs.name NOT IN ('failed', 'maintenance', 'complete', 'deleted') AND "
		       .       "rq.end > NOW() "
		       . "ORDER BY rq.start "
		       . "LIMIT 1";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh))
			$tovmhostinuse = $row['start'];
	}
	print "<script type=\"text/javascript\">\n";
	if($state)
		print "var startstate = 'maintenance';\n";
	else
		print "var startstate = '{$computers[$data['compid']]['state']}';\n";
	$tmp = array();
	foreach($states as $id => $val)
		$tmp[] = "{value: '$id', label: '$val'}";
	print "var allowedstates = [";
	print implode(',', $tmp);
	print "];\n";
	$data2['states'] = $states;
	$platforms = getPlatforms();
	$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"));
	$schedules = $tmp["schedule"];
	$allschedules = getSchedules();
	$images = getImages();
	$profiles = getVMProfiles();
	$data2['profiles'] = $profiles;
	$provisioning = getProvisioning();
	$showprovisioning = array();
	$allowedprovisioning = array();
	foreach($provisioning as $id => $val) {
		if($val['name'] == 'lab') {
			$allowedprovisioning['lab'][] = array('id' => $id, 'name' => $val['prettyname']);
			if($data['type'] == 'lab')
				$showprovisioning[$id] = $val['prettyname'];
		}
		elseif(preg_match('/^xcat/i', $val['name']) || $val['name'] == 'none') {
			$allowedprovisioning['blade'][] = array('id' => $id, 'name' => $val['prettyname']);
			if($data['type'] == 'blade')
				$showprovisioning[$id] = $val['prettyname'];
		}
		else {
			$allowedprovisioning['virtualmachine'][] = array('id' => $id, 'name' => $val['prettyname']);
			if($data['type'] == 'virtualmachine')
				$showprovisioning[$id] = $val['prettyname'];
		}
	}
	$allowedprovisioning['lab']['length'] = count($allowedprovisioning['lab']);
	$allowedprovisioning['blade']['length'] = count($allowedprovisioning['blade']);
	$allowedprovisioning['virtualmachine']['length'] = count($allowedprovisioning['virtualmachine']);
	if($state)
		print "var provval = {$allowedprovisioning['blade'][0]['id']};\n";
	else
		print "var provval = {$data['provisioningid']};\n";
	print "var allowedprovs = " . json_encode($allowedprovisioning) . ";\n";
	print "</script>\n";

	if($state) {
		print "<H2>Add Computer</H2>\n";
	}
	else {
		print "<H2>Edit Computer</H2>\n";

		if($mode == 'submitDeleteComputer') {
			$changehostname = getContinuationVar('changehostname', 0);
			$seteth0null = getContinuationVar('seteth0null', 0);
			$seteth1null = getContinuationVar('seteth1null', 0);
			if($changehostname) {
				$submitErr |= HOSTNAMEERR;
				$submitErrMsg[HOSTNAMEERR] = '-UNDELETED-id was added to the end of the hostname due to an existing computer with the same hostname';
			}
			if($seteth0null) {
				$oldeth0addr = getContinuationVar('oldeth0addr');
				$submitErr |= MACADDRERR2;
				$submitErrMsg[MACADDRERR2] = "This address was set to NULL due to a conflict with another computer. The address was $oldeth0addr";
			}
			if($seteth1null) {
				$oldeth1addr = getContinuationVar('oldeth1addr');
				$submitErr |= MACADDRERR;
				$submitErrMsg[MACADDRERR] = "This address was set to NULL due to a conflict with another computer. The address was $oldeth1addr";
			}
		}

		if($tovmhostinuse) {
			print "<div class=\"highlightnoticewarn\" id=\"cancelvmhostinusediv\">\n";
			$nicestart = date('g:i A \o\n l, F jS, Y', $tovmhostinuse);
			if($tovmhostinuse > time())
				print "NOTICE: This computer is scheduled to start being reloaded as a vmhost at $nicestart. You may cancel this scheduled reload by clicking the button below.<br><br>\n";
			else
				print "NOTICE: This computer is currently being reloaded as a vmhost. You may cancel this process by clicking on the button below. After canceling the reload, it may take several minutes for the cancellation process to complete.<br><br>\n";
			print "<button dojoType=\"dijit.form.Button\">\n";
			print "	Cancel Scheduled Reload\n";
			print "	<script type=\"dojo/method\" event=onClick>\n";
			$cdata = array('compid' => $data['compid']);
			$cont = addContinuationsEntry('AJcanceltovmhostinuse', $cdata, 300, 1, 0);
			print "		cancelScheduledtovmhostinuse('$cont');\n";
			print "	</script>\n";
			print "</button>\n";
			print "</div>\n";
		}
	}
	if($submitErr & VMHOSTINUSEERR) {
		print "<div class=\"highlightnoticewarn\">\n";
		print $submitErrMsg[VMHOSTINUSEERR];
		print "</div>\n";
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname*:</TH>\n";
	print "    <TD><INPUT type=text name=hostname maxlength=36 value=";
	print $data["hostname"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(HOSTNAMEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Type:</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("blade" => "blade", "lab" => "lab", "virtualmachine" => "virtualmachine");
	printSelectInput('type', $tmpArr, $data['type'], 0, 0, 'type', 'dojoType="dijit.form.Select" onChange="editComputerSelectType(0);"');
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Public IP Address*:</TH>\n";
	print "    <TD><INPUT type=text name=ipaddress maxlength=15 value=\"";
	print $data["ipaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Private IP Address:</TH>\n";
	print "    <TD><INPUT type=text name=pripaddress maxlength=15 value=\"";
	print $data["pripaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR2);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Public MAC Address:</TH>\n";
	print "    <TD><INPUT type=text name=eth1macaddress maxlength=17 value=\"";
	print $data["eth1macaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(MACADDRERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Private MAC Address:</TH>\n";
	print "    <TD><INPUT type=text name=eth0macaddress maxlength=17 value=\"";
	print $data["eth0macaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(MACADDRERR2);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Provisioning Engine:</TH>\n";
	print "    <TD>\n";
	printSelectInput("provisioningid", $showprovisioning, $data["provisioningid"], 0, 0, 'provisioningid', 'dojoType="dijit.form.Select" onChange="editComputerSelectType(1);"');
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>State:</TH>\n";
	print "    <TD>\n";
	if(($state == 1 && ($data['provisioningid'] == '' ||
	   $provisioning[$data['provisioningid']]['name'] == 'none')) ||
	   ($state == 0 && ($computers[$data['compid']]['provisioning'] == 'None' ||
	   ($data['type'] == 'virtualmachine' && $data['stateid'] != 2)) ||
	   ($data['type'] == 'virtualmachine' && $computers[$data['compid']]['vmhostid'] == '')))
		unset_by_val('available', $states);
	if($state == 0 && $computers[$data['compid']]['type'] == 'virtualmachine')
		unset_by_val('vmhostinuse', $states);
	printSelectInput('stateid', $states, $data['stateid'], 0, 0, 'stateid', 'dojoType="dijit.form.Select" onChange="editComputerSelectState();"');
	print "    </TD>\n";
	print "    <TD>";
	printSubmitErr(VMAVAILERR);
	print "</TD>\n";
	print "  </TR>\n";
	if($data['stateid'] == 20)
		print "  <TR id=\"vmhostprofiletr\">\n";
	else
		print "  <TR id=\"vmhostprofiletr\" class=\"hidden\">\n";
	print "    <TH align=right>VM Host Profile:</TH>\n";
	print "    <TD>\n";
	printSelectInput("vmprofileid", $profiles, $data["vmprofileid"], 0, 0, 'vmprofileid', 'dojoType="dijit.form.Select"');
	print "    </TD>\n";
	print "    <TD></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner*:</TH>\n";
	print "    <TD><INPUT type=text name=owner value=\"";
	print $data["owner"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(OWNERERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Platform:</TH>\n";
	print "    <TD>\n";
	printSelectInput("platformid", $platforms, $data["platformid"], 0, 0, 'platformid', 'dojoType="dijit.form.Select"');
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR colspan=2>\n";
	print "    <TH align=right>Schedule:</TH>\n";
	print "    <TD>\n";
	if($data["scheduleid"] != "") {
		if(! array_key_exists($data["scheduleid"], $schedules)) {
			$schedules[$data["scheduleid"]] =
			      $allschedules[$data["scheduleid"]]["name"];
			uasort($schedules, "sortKeepIndex");
		}
		printSelectInput("scheduleid", $schedules, $data["scheduleid"], 0, 0, 'scheduleid', 'dojoType="dijit.form.Select"');
	}
	else
		printSelectInput("scheduleid", $schedules, '', 0, 0, 'scheduleid', 'dojoType="dijit.form.Select"');
	print "    </TD>\n";
	print "  </TR>\n";
	if(! $state) {
		print "  <TR>\n";
		print "    <TH align=right>Current Image:</TH>\n";
		print "    <TD>" . $images[$data["currentimgid"]]["prettyname"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>RAM (MB)*:</TH>\n";
	print "    <TD><INPUT type=text name=ram maxlength=7 value=";
	print $data["ram"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(RAMERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>No. Cores:</TH>\n";
	print "    <TD>\n";
	print "      <input dojoType=\"dijit.form.NumberSpinner\"\n";
	print "             constraints=\"{min:1,max:255}\"\n";
	print "             maxlength=\"3\"\n";
	print "             id=\"numprocs\"\n";
	print "             name=\"numprocs\"\n";
	print "             value=\"{$data['numprocs']}\"\n";
	print "             style=\"width: 40px;\">\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Processor Speed (MHz)*:</TH>\n";
	print "    <TD><INPUT type=text name=procspeed maxlength=5 value=";
	print $data["procspeed"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(PROCSPEEDERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Network Speed (Mbps):</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("10" => "10", "100" => "100", "1000" => "1000", "10000" => "10000");
	printSelectInput("network", $tmpArr, $data["network"], 0, 0, 'network', 'dojoType="dijit.form.Select"');
	print "    </TD>\n";
	print "  </TR>\n";
	if(! $state) {
		print "  <TR>\n";
		print "    <TH align=right>Compter ID:</TH>\n";
		print "    <TD>" . $data["compid"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Physical Location:</TH>\n";
	print "    <TD><INPUT type=text name=location id=location value=";
	print "\"{$data["location"]}\"></TD>\n";
	print "    <TD></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	if($state) {
		$tmp = getUserResources(array("computerAdmin"),
		                        array("manageGroup"), 1);
		$computergroups = $tmp["computer"];
		uasort($computergroups, "sortKeepIndex");
		print "<H3>Computer Groups</H3>";
		print "<TABLE border=1>\n";
		print "  <TR>\n";
		foreach($computergroups as $group) {
			print "    <TH>$group</TH>\n";
		}
		print "  </TR>\n";
		print "  <TR>\n";
		foreach(array_keys($computergroups) as $groupid) {
			$name = "computergroup[$groupid]";
			if(array_key_exists($groupid, $data["computergroup"]))
				$checked = "checked";
			else
				$checked = "";
			print "    <TD align=center>\n";
			print "      <INPUT type=checkbox name=\"$name\" value=1 $checked>\n";
			print "    </TD>\n";
		}
		print "  </TR>\n";
		print "</TABLE>\n";
	}
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	$data2['provisioning'] = $provisioning;
	if($state) {
		$cont = addContinuationsEntry('confirmAddComputer', $data2, SECINDAY, 0, 1, 1);
		print "      <INPUT type=submit value=\"Confirm Computer\">\n";
	}
	else {
		$data2['currentimgid'] = $data['currentimgid'];
		$data2['compid'] = $data['compid'];
		if($submitErr & VMHOSTINUSEERR)
			$data2['allowvmhostinuse'] = 1;
		else
			$data2['allowvmhostinuse'] = 0;
		if($mode == 'submitDeleteComputer') {
			$data2['skipmaintenancenote'] = 1;
			$cont = addContinuationsEntry('confirmEditComputer', $data2, SECINDAY);
		}
		else
			$cont = addContinuationsEntry('confirmEditComputer', $data2, SECINDAY, 0);
		print "      <INPUT type=submit value=\"Confirm Changes\">\n";
	}
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewComputers', $data2);
	print "      <INPUT type=hidden name=continuation value=\"$cont=\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmEditOrAddComputer($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief checks for valid input and allows user to confirm the edit/add
///
////////////////////////////////////////////////////////////////////////////////
function confirmEditOrAddComputer($state) {
	global $submitErr, $submitErrMsg;

	$data = processComputerInput();
	$skipmaintenancenote = getContinuationVar('skipmaintenancenote', 0);

	if($submitErr) {
		editOrAddComputer($state);
		return;
	}

	$warnend = '';
	if($state == 0) {
		$data['reloadstart'] = 0;
		$compdata = getComputers(0, 0, $data['compid']);
		if($data['stateid'] == 20 &&
			$compdata[$data['compid']]['stateid'] != 20) {
			$compid = $data['compid'];
			$end = 0;
			moveReservationsOffComputer($compid);
			# get end time of last reservation
			$end = getCompFinalReservationTime($compid);
			$data['reloadstart'] = $end;
			$allowvmhostinuse = getContinuationVar('allowvmhostinuse', 0);
			if($end && ! $allowvmhostinuse) {
				$submitErr |= VMHOSTINUSEERR;
				$end = date('n/j/y g:i a', $end);
				if($data['deploymode'] == 1)
					$submitErrMsg[VMHOSTINUSEERR] = "This node currently has reservations that will not end until $end. Clicking Confirm Changes again will cause this node to be reloaded as a vmhost at $end.";
				else
					$submitErrMsg[VMHOSTINUSEERR] = "This computer is currently allocated until $end and cannot be converted to a VM host until then. Clicking Confirm Changes again will cause the computer to be placed into the maintenance state at $end.  VCL will then prevent it from being used beyond $end. Confirming changes will do that now, or you can simply try this process again after $end. If you schedule it to be placed into maintenance, you will still need to edit this computer again to change it to the vmhostinuse state sometime after $end.<br>\n";
				editOrAddComputer(0);
				return;
			}
			if($end)
				$warnend = date('n/j/y g:i a', $end);
		}
	}

	if($state) {
		$data["currentimgid"] = "";
		$data["compid"] = "";
		$nextmode = "submitAddComputer";
		$title = "Add Computer";
		$question = "Submit the following new computer?";
		if($data['stateid'] != '20')
			$data['vmprofileid'] = '';
	}
	else {
		if($data['type'] == 'virtualmachine')
			$data['location'] = '';
		$nextmode = "submitEditComputer";
		$title = "Edit Computer";
		$question = "Submit the following changes?";
	}

	print "<H2>$title</H2>\n";
	print "<H3>$question</H3>\n";
	if(! $state && ! empty($warnend)) {
		print "<div class=\"highlightnoticewarn\">\n";
		if($data['deploymode'] == 1)
			print "Clicking Submit will cause a reservation to be created to deploy this node as a VM Host at $warnend. It will remain in the current state until that time.\n";
		else
			print "Clicking Submit will cause a reservation to be created to place this node in the maintenance state at $warnend. It will remain in the current state until that time.\n";
		print "</div>\n";
	}
	printComputerInfo($data["pripaddress"],
	                  $data["ipaddress"],
	                  $data["eth0macaddress"],
	                  $data["eth1macaddress"],
	                  $data["stateid"],
	                  $data["owner"],
	                  $data["platformid"],
	                  $data["scheduleid"],
	                  $data["currentimgid"],
	                  $data["ram"],
	                  $data["numprocs"],
	                  $data["procspeed"],
	                  $data["network"],
	                  $data["hostname"],
	                  $data["compid"],
	                  $data["type"],
	                  $data["provisioningid"],
	                  $data["location"],
	                  $data["vmprofileid"],
	                  $data["deploymode"]);
	if($state) {
		$tmp = getUserResources(array("computerAdmin"),
		                        array("manageGroup"), 1);
		$computergroups = $tmp["computer"];
		uasort($computergroups, "sortKeepIndex");
		print "<H3>Computer Groups</H3>";
		print "<TABLE border=1>\n";
		print "  <TR>\n";
		foreach($computergroups as $group) {
			print "    <TH>$group</TH>\n";
		}
		print "  </TR>\n";
		print "  <TR>\n";
		foreach(array_keys($computergroups) as $groupid) {
			if(array_key_exists($groupid, $data["computergroup"]))
				$checked = "src=images/x.png alt=selected";
			else 
				$checked = "src=images/blank.gif alt=unselected";
			print "    <TD align=center>\n";
			print "      <img $checked>\n";
			print "    </TD>\n";
		}
		print "  </TR>\n";
		print "</TABLE>\n";
	}
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	if(! $state && $data['stateid'] == 10 && ! $skipmaintenancenote)
		$cont = addContinuationsEntry('computerAddMaintenanceNote', $data, SECINDAY, 0);
	else {
		$data['provisioning'] = getContinuationVar('provisioning');
		$cont = addContinuationsEntry($nextmode, $data, SECINDAY, 0, 0);
	}
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewComputers', $data);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditComputer()
///
/// \brief updates submitted information for specified computer
///
////////////////////////////////////////////////////////////////////////////////
function submitEditComputer() {
	global $mode, $user;
	$data = processComputerInput();
	$compdata = getComputers(0, 0, $data["compid"]);
	$compid = $data['compid'];
	$profileid = $data['vmprofileid'];
	# maintenance to maintenance
	if($compdata[$compid]["stateid"] == 10 &&
	   $data["stateid"] == 10) {
		// possibly update notes with new text
		$testdata = explode('@', $compdata[$compid]["notes"]);
		if(count($testdata) != 2)
			$testdata[1] = "";
		if($testdata[1] == $data["notes"]) 
			// don't update the notes field
			$data["notes"] = $compdata[$compid]["notes"];
		else {
			if(get_magic_quotes_gpc())
				$data['notes'] = stripslashes($data['notes']);
			$data['notes'] = mysql_real_escape_string($data['notes']);
			// update user, timestamp, and text
			$data["notes"] = $user["unityid"] . " " . unixToDatetime(time()) . "@"
		                  . $data["notes"];
		}
	}
	# available or failed to maintenance
	elseif(($compdata[$compid]["stateid"] == 2 ||
	   $compdata[$compid]["stateid"] == 5) &&
	   $data["stateid"] == 10) {
		// set notes to new data
		if(get_magic_quotes_gpc())
			$data['notes'] = stripslashes($data['notes']);
		$data['notes'] = mysql_real_escape_string($data['notes']);
		$data["notes"] = $user["unityid"] . " " . unixToDatetime(time()) . "@"
		               . $data["notes"];
	}
	# maintenance or failed to available
	elseif(($compdata[$compid]["stateid"] == 10 ||
	   $compdata[$compid]["stateid"] == 5) &&
	   $data["stateid"] == 2) {
		$data["notes"] = "";
	}
	# anything to vmhostinuse
	elseif($compdata[$compid]["stateid"] != 20 && $data["stateid"] == 20) {
		$data["notes"] = "";
		moveReservationsOffComputer($compid);
		$knownreloadstart = getContinuationVar('reloadstart');
		$delayed = 0;
		# get end time of last reservation
		$reloadstart = getCompFinalReservationTime($compid);
		if($data['deploymode'] == 1) {
			# VCL deployed
			if($reloadstart > 0 && $knownreloadstart == 0) {
				print "<H2>Edit Computer</H2>\n";
				$end = date('n/j/y g:i a', $reloadstart);
				unset($data['stateid']);
				$cnt = updateComputer($data);
				if($cnt) {
					print "Changes to this computer's information were successfully ";
					print "saved. However, this ";
				}
				else
					print "This ";
				print "computer is currently allocated until $end. So, it cannot ";
				print "be converted to a VM host server until then. Do you ";
				print "want to schedule VCL to convert it to a VM host server at ";
				print "$end, or wait and initiate this process again later?<br><br>\n";
				print "<table>\n";
				print "  <tr>\n";
				print "    <td>\n";
				print "      <form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cdata = $data;
				$cdata['maintenanceonly'] = 0;
				$cdata['scheduletime'] = $reloadstart;
				$cont = addContinuationsEntry('submitComputerVMHostLater', $cdata, SECINDAY, 1, 0);
				print "      <input type=hidden name=continuation value=\"$cont\">\n";
				print "      <input type=submit value=\"Schedule Later Conversion\">\n";
				print "      </form>\n";
				print "    </td>\n";
				print "    <td>\n";
				print "      <form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cont = addContinuationsEntry('viewComputers', $data);
				print "      <input type=hidden name=continuation value=\"$cont\">\n";
				print "      <input type=submit value=\"Cancel and Initiate Later\">\n";
				print "      </form>\n";
				print "    </td>\n";
				print "  </tr>\n";
				print "</table>\n";
				return;
			}
			else {
				# change to vmhostinuse state
				# create a reload reservation to load machine with image
				#   corresponding to selected vm profile
				$vclreloadid = getUserlistID('vclreload@Local');
				$profiles = getVMProfiles();
				$imagerevisionid = getProductionRevisionid($profiles[$profileid]['imageid']);
				if($reloadstart)
					$start = $reloadstart;
				else
					$start = getReloadStartTime();
				$end = $start + SECINYEAR; # don't want anyone making a future reservation for this machine
				$start = unixToDatetime($start);
				$end = unixToDatetime($end);
				unset($data['stateid']);
				if(! (simpleAddRequest($compid, $profiles[$profileid]['imageid'],
				                    $imagerevisionid, $start, $end, 21, $vclreloadid))) {
					$cnt = updateComputer($data);
					print "<H2>Edit Computer</H2>\n";
					print "An error was encountered while trying to convert this ";
					print "computer to a VM host server.<br><br>\n";
					if($cnt) {
						print "Other changes you made to this computer's information ";
						print "were saved successfully.<br>\n";
					}
					return;
				}

				# check for existing vmhost entry
				$query = "SELECT id, "
				       .        "vmprofileid "
				       . "FROM vmhost "
				       . "WHERE computerid = $compid";
				$qh = doQuery($query, 101);
				if($row = mysql_fetch_assoc($qh)) {
					if($row['vmprofileid'] != $profileid) {
						# update vmprofile
						$query = "UPDATE vmhost "
						       . "SET vmprofileid = $profileid "
						       . "WHERE id = {$row['id']}";
						doQuery($query, 101);
					}
				}
				else {
					# create vmhost entry
					$query = "INSERT INTO vmhost "
					       .        "(computerid, "
					       .        "vmlimit, "
					       .        "vmprofileid) "
					       . "VALUES ($compid, "
					       .        "2, "
					       .        "$profileid)";
					doQuery($query, 101);
				}

				if($knownreloadstart > 0 && $reloadstart > $knownreloadstart) {
					print "<H2>Edit Computer</H2>\n";
					$end = date('n/j/y g:i a', $reloadstart);
					unset($data['stateid']);
					$cnt = updateComputer($data);
					if($cnt) {
						print "Changes to this computer's information were successfully ";
						print "saved.<br><br>\n";
					}
					print "Reload reservation successfully created.<br><br>\n";
					print "<strong>NOTE: The end of the last reservation for the computer changed ";
					print "from the previous page. The computer will now be ";
					print "reloaded at $end.</strong>";
					return;
				}
			}
		}
		else {
			# manually installed
			if($reloadstart > 0 && $knownreloadstart == 0) {
				# notify that need to try after $reloadstart
				$end = date('n/j/y g:i a', $reloadstart);
				print "<H2>Edit Computer</H2>\n";
				unset($data['stateid']);
				$cnt = updateComputer($data);
				if($cnt) {
					print "Changes to this computer's information were successfully ";
					print "saved. However, this ";
				}
				else
					print "This ";
				print "computer is currently allocated until $end and cannot ";
				print "be converted to a VM host until then. If you schedule the ";
				print "computer to be placed into the maintenance state at $end, ";
				print "VCL will prevent it from being used beyond $end. You can ";
				print "select to do that now, or you can simply try this process ";
				print "again after $end. If you schedule it to be placed into ";
				print "maintenance, you will still need to edit this computer again ";
				print "to change it to the vmhostinuse state sometime after $end.<br><br>\n";
				print "<table>\n";
				print "  <tr>\n";
				print "    <td>\n";
				print "      <form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cdata = $data;
				$cdata['maintenanceonly'] = 1;
				$cdata['scheduletime'] = $reloadstart;
				$cont = addContinuationsEntry('submitComputerVMHostLater', $cdata, SECINDAY, 1, 0);
				print "      <input type=hidden name=continuation value=\"$cont\">\n";
				print "      <input type=submit value=\"Schedule Maintenance State\">\n";
				print "      </form>\n";
				print "    </td>\n";
				print "    <td>\n";
				print "      <form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cont = addContinuationsEntry('viewComputers', $data);
				print "      <input type=hidden name=continuation value=\"$cont\">\n";
				print "      <input type=submit value=\"Cancel and Initiate Later\">\n";
				print "      </form>\n";
				print "    </td>\n";
				print "  </tr>\n";
				print "</table>\n";
				return;
			}
			elseif($reloadstart > 0) {
				$vclreloadid = getUserlistID('vclreload@Local');
				$end = $reloadstart + SECINYEAR; # don't want anyone making a future reservation for this machine
				$startdt = unixToDatetime($reloadstart);
				$enddt = unixToDatetime($end);
				$imageid = getImageId('noimage');
				$imagerevisionid = getProductionRevisionid($imageid);
				if(! (simpleAddRequest($compid, $imageid, $imagerevisionid, $startdt, $enddt,
				                       18, $vclreloadid))) {
					unset($data['stateid']);
					$cnt = updateComputer($data);
					print "<H2>Edit Computer</H2>\n";
					print "An error was encountered while trying to convert this ";
					print "computer to a VM host server.<br><br>\n";
					if($cnt) {
						print "Other changes you made to this computer's information ";
						print "were saved successfully.<br>\n";
					}
					return;
				}
				print "<H2>Edit Computer</H2>\n";
				$end = date('n/j/y g:i a', $reloadstart);
				unset($data['stateid']);
				$cnt = updateComputer($data);
				if($cnt) {
					print "Changes to this computer's information were successfully ";
					print "saved.<br><br>\n";
				}
				print "Maintenance reservation successfully created.<br><br>\n";
				if($reloadstart > $knownreloadstart) {
					print "<strong>NOTE: The end of the last reservation for the computer changed ";
					print "from the previous page. The computer will now be ";
					print "placed into the maintenance state at $end.</strong>";
				}
				return;
			}
			else {
				# set to vmhostinuse
				# check for existing vmhost entry
				$query = "SELECT id, "
				       .        "vmprofileid "
				       . "FROM vmhost "
				       . "WHERE computerid = $compid";
				$qh = doQuery($query, 101);
				if($row = mysql_fetch_assoc($qh)) {
					if($row['vmprofileid'] != $profileid) {
						# update vmprofile
						$query = "UPDATE vmhost "
						       . "SET vmprofileid = $profileid "
						       . "WHERE id = {$row['id']}";
						doQuery($query, 101);
					}
				}
				else {
					# create vmhost entry
					$query = "INSERT INTO vmhost "
					       .        "(computerid, "
					       .        "vmlimit, "
					       .        "vmprofileid) "
					       . "VALUES ($compid, "
					       .        "2, "
					       .        "$profileid)";
					doQuery($query, 101);
				}
				if($reloadstart == 0 && $knownreloadstart > 0) {
					print "<H2>Edit Computer</H2>\n";
					$cnt = updateComputer($data);
					if($cnt) {
						print "Changes to this computer's information were successfully ";
						print "saved.<br><br>\n";
					}
					print "<strong>NOTE: Reservations for this computer completed since the previous page. The computer has now been placed into the vmhostinuse state.</strong>\n";
					return;
				}
			}
		}
	}
	elseif($compdata[$compid]["stateid"] == 20 && $data["stateid"] == 20 &&
	      ($profileid != $compdata[$compid]['vmprofileid'])) {
		# check for assigned VMs
		$query = "SELECT COUNT(c.id) AS cnt "
		       . "FROM computer c, "
		       .      "vmhost v "
		       . "WHERE v.computerid = $compid AND "
		       .       "c.vmhostid = v.id";
		$qh = doQuery($query);
		$row = mysql_fetch_assoc($qh);
		if($row['cnt'] > 0) {
			print "<H2>Edit Computer</H2>\n";
			unset($data['stateid']);
			$cnt = updateComputer($data);
			if($cnt) {
				print "Changes to this computer's information were successfully ";
				print "saved. However, there ";
			}
			else
				print "There ";
			print "are currently VMs assigned to this VM host. You must remove ";
			print "all VMs from the host before changing it to a different VM Host ";
			print "Profile.\n";
			return;
		}
		if($data['deploymode'] == 1) {
			# reload with new profile
			$vclreloadid = getUserlistID('vclreload@Local');
			$profiles = getVMProfiles();
			$imagerevisionid = getProductionRevisionid($profiles[$profileid]['imageid']);
			$start = getReloadStartTime();
			$end = $start + SECINYEAR; # don't want anyone making a future reservation for this machine
			$start = unixToDatetime($start);
			$end = unixToDatetime($end);
			if(! (simpleAddRequest($compid, $profiles[$profileid]['imageid'],
			      $imagerevisionid, $start, $end, 21, $vclreloadid))) {
				unset($data['stateid']);
				$cnt = updateComputer($data);
				print "<H2>Edit Computer</H2>\n";
				print "An error was encountered while trying to convert this ";
				print "computer to the new VM Host Profile.<br><br>\n";
				if($cnt) {
					print "Other changes you made to this computer's information ";
					print "were saved successfully.<br>\n";
				}
				return;
			}
			# set computer to reserved state
			$query = "UPDATE computer "
			       . "SET stateid = (SELECT id "
			       .                "FROM state "
			       .                "WHERE name = 'reserved') "
			       . "WHERE id = $compid";
			doQuery($query);
		}
		# update vmprofile
		$query = "SELECT id "
		       . "FROM vmhost "
		       . "WHERE computerid = $compid";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh)) {
			$query = "UPDATE vmhost "
			       . "SET vmprofileid = $profileid "
			       . "WHERE id = {$row['id']}";
			doQuery($query, 101);
		}
	}
	updateComputer($data);
	viewComputers();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn computerAddMaintenanceNote($data)
///
/// \param $data - array returned from processComputerInput
///
/// \brief prints a page asking user to enter a reason for placing a computer
/// in maintenance state
///
////////////////////////////////////////////////////////////////////////////////
function computerAddMaintenanceNote() {
	$data = processComputerInput();
	unset($data['notes']);
	$compdata = getComputers(0, 0, $data["compid"]);
	$notes = explode('@', $compdata[$data["compid"]]["notes"]);
	if(count($notes) != 2)
		$notes[1] = "";
	print "<DIV align=center>\n";
	print "<H2>Edit Computer</H2>\n";
	print "Why are you placing this computer in the maintenance state?\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TEXTAREA name=notes rows=4 cols=35>{$notes[1]}</TEXTAREA>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD><INPUT type=submit value=Submit></TD>\n";
	$cont = addContinuationsEntry('submitEditComputer', $data, SECINDAY, 0, 0);
	print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "    </FORM>\n";
	print "    <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "    <TD><INPUT type=submit value=Cancel></TD>\n";
	$cont = addContinuationsEntry('viewComputers', $data);
	print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "    </FORM>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
    print "</DIV>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJcanceltovmhostinuse()
///
/// \brief cancels any reservations to place the computer in the vmhostinuse
/// state
///
////////////////////////////////////////////////////////////////////////////////
function AJcanceltovmhostinuse() {
	global $mysql_link_vcl;
	$compid = getContinuationVar('compid');
	$type = 'none';
	$query = "DELETE FROM request "
	       . "WHERE start > NOW() AND "
	       .       "stateid = 21 AND "
	       .       "id IN (SELECT requestid "
	       .              "FROM reservation "
	       .              "WHERE computerid = $compid)";
	doQuery($query);
	if(mysql_affected_rows($mysql_link_vcl))
		$type = 'future';
	$query = "UPDATE request rq, "
	       .         "reservation rs, "
	       .         "state ls "
	       . "SET rq.stateid = 1 "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "rs.computerid = $compid AND "
	       .       "rq.start <= NOW() AND "
	       .       "rq.laststateid = ls.id AND "
	       .       "ls.name = 'tovmhostinuse'";
	doQuery($query);
	if(mysql_affected_rows($mysql_link_vcl))
		$type = 'current';
	$query = "SELECT rq.start "
	       . "FROM request rq, "
	       .      "reservation rs, "
	       .      "state ls, "
	       .      "state cs "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "rs.computerid = $compid AND "
	       .       "rq.laststateid = ls.id AND "
	       .       "rq.stateid = cs.id AND "
	       .       "ls.name = 'tovmhostinuse' AND "
	       .       "cs.name NOT IN ('failed', 'maintenance', 'complete', 'deleted') AND "
	       .       "rq.end > NOW() "
	       . "ORDER BY rq.start";
	$qh = doQuery($query);
	if(mysql_num_rows($qh))
		$arr = array('status' => 'failed');
	else {
		if($type == 'now')
			$msg = "The reservation currently being processed to place this "
			     . "computer in the vmhostinuse state has been flagged for "
			     . "deletion. As soon as the deletion can be processed, the "
			     . "computer will be set to the available state.";
		else
			$msg = "The reservation scheduled to place this computer in the "
			     . "vmhostinuse state has been deleted.";
		$arr = array('status' => 'success', 'msg' => $msg);
	}
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddComputer()
///
/// \brief adds a new computer with the submitted information
///
////////////////////////////////////////////////////////////////////////////////
function submitAddComputer() {
	$data = processComputerInput();
	addComputer($data);
	clearPrivCache();
	viewComputers();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitComputerVMHostLater()
///
/// \brief schedules a computer to be converted to vmhostinuse state at a future
/// time
///
////////////////////////////////////////////////////////////////////////////////
function submitComputerVMHostLater() {
	$data = getContinuationVar();
	$delayed = 0;
	$compid = $data['compid'];
	$start = $data['scheduletime'];
	moveReservationsOffComputer($compid);
	$tmp = getCompFinalReservationTime($compid);
	if($tmp > $data['scheduletime']) {
		$delayed = 1;
		$start = $tmp;
	}
	# create a reload reservation to load machine with image
	#   corresponding to selected vm profile
	$vclreloadid = getUserlistID('vclreload@Local');
	$end = $start + SECINYEAR; # don't want anyone making a future reservation for this machine
	$startdt = unixToDatetime($start);
	$end = unixToDatetime($end);
	if($data['maintenanceonly']) {
		$imageid = getImageId('noimage');
		$imagerevisionid = getProductionRevisionid($imageid);
		if(! (simpleAddRequest($compid, $imageid, $imagerevisionid, $startdt, $end,
		                       18, $vclreloadid))) {
			print "<H2>Edit Computer</H2>\n";
			print "An error was encountered while trying to schedule this ";
			print "computer for the maintenance state. Please try again later.\n";
			return;
		}
	}
	else {
		$profiles = getVMProfiles();
		$imagerevisionid = getProductionRevisionid($profiles[$data['vmprofileid']]['imageid']);
		if(! (simpleAddRequest($compid, $profiles[$data['vmprofileid']]['imageid'],
		                       $imagerevisionid, $startdt, $end, 21, $vclreloadid))) {
			print "<H2>Edit Computer</H2>\n";
			print "An error was encountered while trying to convert this ";
			print "computer to a VM host server. Please try again later.\n";
			return;
		}

		# check for existing vmhost entry
		$query = "SELECT id, "
		       .        "vmprofileid "
		       . "FROM vmhost "
		       . "WHERE computerid = $compid";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh)) {
			if($row['vmprofileid'] != $data['vmprofileid']) {
				# update vmprofile
				$query = "UPDATE vmhost "
				       . "SET vmprofileid = $profileid "
				       . "WHERE id = {$row['id']}";
				doQuery($query, 101);
			}
		}
		else {
			# create vmhost entry
			$query = "INSERT INTO vmhost "
			       .        "(computerid, "
			       .        "vmlimit, "
			       .        "vmprofileid) "
			       . "VALUES ($compid, "
			       .        "2, "
			       .        "$profileid)";
			doQuery($query, 101);
		}
	}
	print "<H2>Edit Computer</H2>\n";
	$schtime = date('n/j/y g:i a', $start);
	if($delayed) {
		print "<strong>NOTE: The end time for the final reservation for this ";
		print "computer changed from what was previously reported.</strong>";
		print "<br><br>\n";
	}
	if($data['maintenanceonly']) {
		print "The computer has been scheduled to be placed into the maintenance ";
		print "state at $schtime.";
	}
	else {
		print "The computer has been scheduled to be converted to a VM host at ";
		print "$schtime.";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteComputer()
///
/// \brief prints a confirmation page about deleteing a computer
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteComputer() {
	$data = processComputerInput(0);
	$computers = getComputers(0, 1);

	$compid = $data["compid"];

	if($computers[$compid]["deleted"]) {
		$deleted = 1;
		$title = "Undelete Computer";
		$question = "Undelete the following computer?";
		$button = "Undelete";
	}
	else {
		$deleted = 0;
		$title = "Delete Computer";
		$question = "Delete the following computer?";
		$button = "Delete";
	}

	print "<DIV align=center>\n";
	print "<H2>$title</H2>\n";
	print "<H3>$question</H3>\n";
	printComputerInfo($computers[$compid]["privateIPaddress"],
	                  $computers[$compid]["IPaddress"],
	                  $computers[$compid]["eth0macaddress"],
	                  $computers[$compid]["eth1macaddress"],
	                  $computers[$compid]["stateid"],
	                  $computers[$compid]["owner"],
	                  $computers[$compid]["platformid"],
	                  $computers[$compid]["scheduleid"],
	                  $computers[$compid]["currentimgid"],
	                  $computers[$compid]["ram"],
	                  $computers[$compid]["procnumber"],
	                  $computers[$compid]["procspeed"],
	                  $computers[$compid]["network"],
	                  $computers[$compid]["hostname"],
	                  $compid,
	                  $computers[$compid]["type"],
	                  $computers[$compid]["provisioningid"],
	                  $computers[$compid]["location"]);
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = $data;
	$cdata['deleted'] = $deleted;
	$cdata['compid'] = $compid;
	if($deleted) {
		# check for duplicate hostname
		$query = "SELECT id "
		       . "FROM computer "
		       . "WHERE hostname = '{$computers[$compid]['hostname']}' AND "
		       .       "id != $compid AND "
		       .       "deleted = 0";
		$qh = doQuery($query);
		if(mysql_num_rows($qh))
			$cdata['changehostname'] = 1;

		# check for duplicate eth0macaddress
		$query = "SELECT id "
		       . "FROM computer "
		       . "WHERE eth0macaddress = '{$computers[$compid]['eth0macaddress']}' AND "
		       .       "id != $compid AND "
		       .       "deleted = 0";
		$qh = doQuery($query);
		if(mysql_num_rows($qh)) {
			$cdata['seteth0null'] = 1;
			$cdata['oldeth0addr'] = $computers[$compid]['eth0macaddress'];
		}

		# check for duplicate eth1macaddress
		$query = "SELECT id "
		       . "FROM computer "
		       . "WHERE eth1macaddress = '{$computers[$compid]['eth1macaddress']}' AND "
		       .       "id != $compid AND "
		       .       "deleted = 0";
		$qh = doQuery($query);
		if(mysql_num_rows($qh)) {
			$cdata['seteth1null'] = 1;
			$cdata['oldeth1addr'] = $computers[$compid]['eth1macaddress'];
		}
	}
	$cont = addContinuationsEntry('submitDeleteComputer', $cdata, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=$button>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewComputers', $data);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
    print "</DIV>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteComputer()
///
/// \brief deletes a computer from the database and notifies the user
///
////////////////////////////////////////////////////////////////////////////////
function submitDeleteComputer() {
	$compid = getContinuationVar("compid");
	$deleted = getContinuationVar("deleted");
	$compdata = getComputers(0, 1, $compid);
	$changehostname = 0;
	$seteth0null = 0;
	$seteth1null = 0;
	if($deleted) {
		$changehostname = getContinuationVar('changehostname', 0);
		$seteth0null = getContinuationVar('seteth0null', 0);
		$seteth1null = getContinuationVar('seteth1null', 0);

		$query = "UPDATE computer "
		       . "SET deleted = 0, "
		       .     "datedeleted = '0000-00-00 00:00:00' ";
		if($changehostname)
		   $query .= ", hostname = '{$compdata[$compid]['hostname']}-UNDELETED-$compid' ";
		if($compdata[$compid]['type'] == 'virtualmachine')
			$query .= ", stateid = 10 ";
		if($seteth0null)
			$query .= ", eth0macaddress = NULL ";
		if($seteth1null)
			$query .= ", eth1macaddress = NULL ";
		$query .= "WHERE id = $compid";
		$qh = doQuery($query, 190);
	}
	else {
		$newhostname = preg_replace('/-UNDELETED-[0-9]+$/', '', $compdata[$compid]['hostname']);
		$query = "UPDATE computer "
		       . "SET deleted = 1, "
		       .     "datedeleted = NOW(), "
		       .     "vmhostid = NULL, "
		       .     "hostname = '$newhostname' "
		       . "WHERE id = $compid";
		$qh = doQuery($query, 191);
	}
	$_SESSION['userresources'] = array();
	if($changehostname || $seteth0null || $seteth1null) {
		editOrAddComputer(0);
		return;
	}
	viewComputers();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn bulkAddComputer()
///
/// \brief prints a form for adding a block of computers
///
////////////////////////////////////////////////////////////////////////////////
function bulkAddComputer() {
	global $submitErr;

	$data = processBulkComputerInput(0);
	$data2 = processComputerInput2(); //yes, this is somewhat redundant, but it
	                                  // makes things easier later

	$states = array("2" => "available",
	                "10" => "maintenance",
	                "20" => "vmhostinuse");
	print "<script type=\"text/javascript\">\n";
	$tmp = array();
	foreach($states as $id => $val)
		$tmp[] = "{value: '$id', label: '$val'}";
	print "var allowedstates = [";
	print implode(',', $tmp);
	print "];\n";
	print "var startstate = 'maintenance';\n";
	$platforms = getPlatforms();
	$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"));
	$schedules = $tmp["schedule"];
	$images = getImages();
	$profiles = getVMProfiles();
	$data2['profiles'] = $profiles;
	$provisioning = getProvisioning();
	$showprovisioning = array();
	$allowedprovisioning = array();
	foreach($provisioning as $id => $val) {
		if($val['name'] == 'lab') {
			$allowedprovisioning['lab'][] = array('id' => $id, 'name' => $val['prettyname']);
			if($data['type'] == 'lab')
				$showprovisioning[$id] = $val['prettyname'];
		}
		elseif(preg_match('/^xcat/i', $val['name']) || $val['name'] == 'none') {
			$allowedprovisioning['blade'][] = array('id' => $id, 'name' => $val['prettyname']);
			if($data['type'] == 'blade')
				$showprovisioning[$id] = $val['prettyname'];
		}
		else {
			$allowedprovisioning['virtualmachine'][] = array('id' => $id, 'name' => $val['prettyname']);
			if($data['type'] == 'virtualmachine')
				$showprovisioning[$id] = $val['prettyname'];
		}
	}
	print "var provval = {$allowedprovisioning['blade'][0]['id']};\n";
	$allowedprovisioning['lab']['length'] = count($allowedprovisioning['lab']);
	$allowedprovisioning['blade']['length'] = count($allowedprovisioning['blade']);
	$allowedprovisioning['virtualmachine']['length'] = count($allowedprovisioning['virtualmachine']);
	print "var allowedprovs = " . json_encode($allowedprovisioning) . ";\n";
	print "</script>\n";

	print "<H2>Add Multiple Computers</H2>\n";
	print "<div>\n";
	print "<div style=\"width: 600px;\">\n";
	print "<b>NOTE</b>: 'Start IP' and 'End IP' can only differ in the number ";
	print "after the last '.'. The hostnames will be generated from the ";
	print "'Hostname' field. The hostnames for each computer can only differ ";
	print "by the value of a number in the first part of the hostname. Place ";
	print "a '%' character in the 'Hostname' field where that number will be. ";
	print "Then fill in 'Start value' and 'End value' with the first and last ";
	print "values to be used in the hostname.<br><br>";
	print "Required text fields are noted with *<br><br>\n";
	print "</div>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname*:</TH>\n";
	print "    <TD><INPUT type=text name=hostname maxlength=36 value=";
	print $data["hostname"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(HOSTNAMEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Start value*:</TH>\n";
	print "    <TD><INPUT type=text name=starthostval maxlength=8 value=";
	print $data["starthostval"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(STARTHOSTVALERR);
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>End value*:</TH>\n";
	print "    <TD><INPUT type=text name=endhostval maxlength=8 value=";
	print $data["endhostval"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(ENDHOSTVALERR);
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Type:</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("blade" => "blade", "lab" => "lab", "virtualmachine" => "virtualmachine");
	printSelectInput('type', $tmpArr, $data['type'], 0, 0, 'type', 'dojoType="dijit.form.Select" onChange="editComputerSelectType(0);"');
	print "    </TD>\n";
	print "  </TR>\n";

	print "  <TR>\n";
	print "    <TH align=right nowrap>Start Public IP Address*:</TH>\n";
	print "    <TD><INPUT type=text name=startipaddress maxlength=15 value=\"";
	print $data["startipaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>End Public IP Address*:</TH>\n";
	print "    <TD><INPUT type=text name=endipaddress maxlength=15 value=\"";
	print $data["endipaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR2);
	print "</TD>\n";
	print "  </TR>\n";

	print "  <TR>\n";
	print "    <TH align=right nowrap>Start Private IP Address:</TH>\n";
	print "    <TD><INPUT type=text name=startpripaddress maxlength=15 value=\"";
	print $data["startpripaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR3);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>End Private IP Address:</TH>\n";
	print "    <TD><INPUT type=text name=endpripaddress maxlength=15 value=\"";
	print $data["endpripaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR4);
	print "</TD>\n";
	print "  </TR>\n";

	print "  <TR>\n";
	print "    <TH align=right nowrap>Start MAC Address:</TH>\n";
	print "    <TD><INPUT type=text name=startmac maxlength=17 value=\"";
	print $data["startmac"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(MACADDRERR);
	print "</TD>\n";
	print "  </TR>\n";

	print "  <TR>\n";
	print "    <TH align=right nowrap>Provisioning Engine:</TH>\n";
	print "    <TD>\n";
	printSelectInput("provisioningid", $showprovisioning, $data["provisioningid"], 0, 0, 'provisioningid', 'dojoType="dijit.form.Select" onChange="editComputerSelectType(1);"');
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>State:</TH>\n";
	print "    <TD>\n";
	if($submitErr && $data['type'] == 'virtualmachine')
		$states = array('10' => 'maintenance');
	if($data['provisioningid'] == '' || $provisioning[$data['provisioningid']]['name'] == 'none')
		unset_by_val('available', $states);
	printSelectInput('stateid', $states, $data['stateid'], 0, 0, 'stateid', 'dojoType="dijit.form.Select" onChange="editComputerSelectState();"');
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR id=\"vmhostprofiletr\" class=\"hidden\">\n";
	print "    <TH align=right>VM Host Profile:</TH>\n";
	print "    <TD>\n";
	printSelectInput("vmprofileid", $profiles, $data["vmprofileid"], 0, 0, 'vmprofileid', 'dojoType="dijit.form.Select"');
	print "    </TD>\n";
	print "    <TD></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Owner*:</TH>\n";
	print "    <TD><INPUT type=text name=owner maxlength=80 value=\"";
	print $data["owner"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(OWNERERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Platform:</TH>\n";
	print "    <TD>\n";
	printSelectInput("platformid", $platforms, $data["platformid"], 0, 0, 'platformid', 'dojoType="dijit.form.Select"');
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Schedule:</TH>\n";
	print "    <TD>\n";
	printSelectInput("scheduleid", $schedules, $data["scheduleid"], 0, 0, 'scheduleid', 'dojoType="dijit.form.Select"');
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>RAM (MB)*:</TH>\n";
	print "    <TD><INPUT type=text name=ram maxlength=7 value=";
	print $data["ram"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(RAMERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>No. Cores:</TH>\n";
	print "    <TD>\n";
	print "      <input dojoType=\"dijit.form.NumberSpinner\"\n";
	print "             constraints=\"{min:1,max:255}\"\n";
	print "             maxlength=\"3\"\n";
	print "             id=\"numprocs\"\n";
	print "             name=\"numprocs\"\n";
	print "             value=\"{$data['numprocs']}\"\n";
	print "             style=\"width: 40px;\">\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Processor Speed (MHz)*:</TH>\n";
	print "    <TD><INPUT type=text name=procspeed maxlength=5 value=";
	print $data["procspeed"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(PROCSPEEDERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Network Speed&nbsp;(Mbps):</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("10" => "10", "100" => "100", "1000" => "1000", "10000" => "10000");
	printSelectInput("network", $tmpArr, $data["network"], 0, 0, 'network', 'dojoType="dijit.form.Select"');
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Physical Location:</TH>\n";
	print "    <TD><INPUT type=text name=location id=location value=";
	print "\"{$data["location"]}\"></TD>\n";
	print "    <TD></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	$tmp = getUserResources(array("computerAdmin"),
	                        array("manageGroup"), 1);
	$computergroups = $tmp["computer"];
	print "<H3>Computer Groups</H3>";
	print "<TABLE border=1>\n";
	print "  <TR>\n";
	foreach($computergroups as $group) {
		print "    <TH>$group</TH>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	foreach(array_keys($computergroups) as $groupid) {
		$name = "computergroup[$groupid]";
		if(array_key_exists($groupid, $data["computergroup"]))
			$checked = "checked";
		else
			$checked = "";
		print "    <TD align=center>\n";
		print "      <INPUT type=checkbox name=\"$name\" value=1 $checked>\n";
		print "    </TD>\n";
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	$cont = addContinuationsEntry('confirmAddBulkComputers', $data2, SECINDAY, 0, 1, 1);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=\"Confirm Computers\">\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewComputers', $data2);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
    print "</DIV>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmAddBulkComputers()
///
/// \brief checks for valid input and allows user to confirm the bulk add
///
////////////////////////////////////////////////////////////////////////////////
function confirmAddBulkComputers() {
	global $submitErr;

	$data = processBulkComputerInput();

	if($submitErr) {
		bulkAddComputer();
		return;
	}

	print "<H2>Add Multiple Computers</H2>\n";
	print "<H3>Add the following comptuers?</H3>\n";

	$states = getStates();
	$platforms = getPlatforms();
	$schedules = getSchedules();
	$images = getImages();
	$provisioning = getProvisioning();

	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostnames:</TH>\n";
	$first = str_replace('%', $data["starthostval"], $data["hostname"]);
	$last = str_replace('%', $data["endhostval"], $data["hostname"]);
	print "    <TD>$first - $last</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Type:</TH>\n";
	print "    <TD>" . $data["type"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>IP Addresses:</TH>\n";
	print "    <TD>" . $data["startipaddress"] . " - ";
	print $data["endipaddress"] . "</TD>\n";
	print "  </TR>\n";
	if(! empty($data['startpripaddress'])) {
		print "  <TR>\n";
		print "    <TH align=right nowrap>Private IP Addresses:</TH>\n";
		print "    <TD>" . $data["startpripaddress"] . " - ";
		print $data["endpripaddress"] . "</TD>\n";
		print "  </TR>\n";
	}
	if(! empty($data['macs'])) {
		$end = $data['count'] * 2 - 1;
		print "  <TR>\n";
		print "    <TH align=right nowrap>MAC Addresses:</TH>\n";
		print "    <TD>{$data['macs'][0]} - {$data['macs'][$end]} (2 for each machine)</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Provisioning Engine:</TH>\n";
	print "    <TD>" . $provisioning[$data["provisioningid"]]['prettyname'] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>State:</TH>\n";
	print "    <TD>" . $states[$data["stateid"]] . "</TD>\n";
	print "  </TR>\n";
	if(! empty($data['vmprofileid'])) {
		print "  <TR>\n";
		print "    <TH align=right>VM Host Profile:</TH>\n";
		print "    <TD>{$data['profiles'][$data['vmprofileid']]['profilename']}</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>" . $data["owner"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Platform:</TH>\n";
	print "    <TD>" . $platforms[$data["platformid"]] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Schedule:</TH>\n";
	print "    <TD>" . $schedules[$data["scheduleid"]]["name"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>RAM (MB):</TH>\n";
	print "    <TD>" . $data["ram"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>No. Cores:</TH>\n";
	print "    <TD>" . $data["numprocs"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Processor Speed (MHz):</TH>\n";
	print "    <TD>" . $data["procspeed"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Network Speed (Mbps):</TH>\n";
	print "    <TD>" . $data["network"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Location:</TH>\n";
	print "    <TD>{$data['location']}</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	$tmp = getUserResources(array("computerAdmin"),
	                        array("manageGroup"), 1);
	$computergroups = $tmp["computer"];
	print "<H3>Computer Groups</H3>";
	print "<TABLE border=1>\n";
	print "  <TR>\n";
	foreach($computergroups as $group) {
		print "    <TH>$group</TH>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	foreach(array_keys($computergroups) as $groupid) {
		if(array_key_exists($groupid, $data["computergroup"]))
			$checked = "src=images/x.png alt=selected";
		else 
			$checked = "src=images/blank.gif alt=unselected";
		print "    <TD align=center>\n";
		print "      <img $checked>\n";
		print "    </TD>\n";
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('submitAddBulkComputers', $data, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewComputers', $data);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddBulkComputers()
///
/// \brief submits the computers and notifies the user
///
////////////////////////////////////////////////////////////////////////////////
function submitAddBulkComputers() {
	global $mysql_link_vcl;

	$data = processBulkComputerInput(0);
	$ownerid = getUserlistID($data["owner"]);

	$tmpArr = explode('.', $data["startipaddress"]);
	$startip = $tmpArr[3];
	$tmpArr = explode('.', $data["endipaddress"]);
	$endip = $tmpArr[3];
	array_pop($tmpArr);
	$baseaddr = implode('.', $tmpArr);

	$dopr = 0;
	if(! empty($data['startpripaddress'])) {
		$dopr = 1;
		$tmpArr = explode('.', $data["startpripaddress"]);
		$startprip = $tmpArr[3];
		$tmpArr = explode('.', $data["endpripaddress"]);
		$endprip = $tmpArr[3];
		array_pop($tmpArr);
		$basepraddr = implode('.', $tmpArr);
	}
	$domacs = 0;
	if(! empty($data['macs'])) {
		$domacs = 1;
		$maccnt = 0;
	}

	$doloc = 0;
	if($data['location'] != '') {
		$doloc = 1;
		$location = $data['location'];
		if(get_magic_quotes_gpc())
			$location = stripslashes($location);
		$location = mysql_real_escape_string($location);
	}

	$dhcpdata = array();
	$count = 0;
	$addedrows = 0;
	$noimageid = getImageId('noimage');
	$noimagerevisionid = getProductionRevisionid($noimageid);
	for($i = $startip, $j = $data["starthostval"]; $i <= $endip; $i++, $j++, $count++) {
		$hostname = str_replace('%', $j, $data["hostname"]);
		$ipaddress = $baseaddr . ".$i";
		$dhcpdata[$count] = array('hostname' => $hostname);
		if($dopr) {
			$pripaddress = $basepraddr . '.' . $startprip++;
			$dhcpdata[$count]['prip'] = $pripaddress;
		}
		if($domacs) {
			$eth0 = $data['macs'][$maccnt++];
			$eth1 = $data['macs'][$maccnt++];
			$dhcpdata[$count]['eth0mac'] = $eth0;
		}
		$query = "INSERT INTO computer "
		       .        "(stateid, "
		       .        "ownerid, "
		       .        "platformid, "
		       .        "provisioningid, "
		       .        "scheduleid, "
		       .        "currentimageid, "
		       .        "imagerevisionid, "
		       .        "RAM, "
		       .        "procnumber, "
		       .        "procspeed, "
		       .        "network, "
		       .        "hostname, "
		       .        "IPaddress, ";
		if($dopr)
			$query .=    "privateIPaddress, ";
		if($domacs)
			$query .=    "eth0macaddress, "
			       .     "eth1macaddress, ";
		if($doloc)
			$query .=    "location, ";
		$query .=       "type) "
		       . "VALUES ({$data['stateid']}, "
		       .         "$ownerid, "
		       .         "{$data['platformid']}, "
		       .         "{$data['provisioningid']}, "
		       .         "{$data['scheduleid']}, "
		       .         "$noimageid, "
		       .         "$noimagerevisionid, "
		       .         "{$data['ram']}, "
		       .         "{$data['numprocs']}, "
		       .         "{$data['procspeed']}, "
		       .         "{$data['network']}, "
		       .         "'$hostname', "
		       .         "'$ipaddress', ";
		if($dopr)
			$query .=     "'$pripaddress', ";
		if($domacs)
			$query .=     "'$eth0', "
			       .      "'$eth1', ";
		if($doloc)
			$query .=     "'$location', ";
		$query .=        "'{$data['type']}')";
		$qh = doQuery($query, 235);
		$addedrows += mysql_affected_rows($mysql_link_vcl);
		$compid = dbLastInsertID();

		$query = "INSERT INTO resource "
		       .        "(resourcetypeid, "
		       .        "subid) "
		       . "VALUES (12, "
		       .         "$compid)";
		doQuery($query, 238);
		$resid = dbLastInsertID();

		// add computer into selected groups
		if(! empty($data['computergroup'])) {
			$vals = array();
			foreach(array_keys($data["computergroup"]) as $groupid)
				$vals[] = "($resid, $groupid)";
			$allvals = implode(',', $vals);
			$query = "INSERT INTO resourcegroupmembers "
		          .        "(resourceid, "
		          .        "resourcegroupid) "
		          . "VALUES $allvals";
			doQuery($query, 101);
		}

		if($data['stateid'] == 20) {
			# create vmhost entry
			$query = "INSERT INTO vmhost "
			       .        "(computerid, "
			       .        "vmlimit, "
			       .        "vmprofileid) "
			       . "VALUES ($compid, "
			       .        "2, "
			       .        "{$data['vmprofileid']})";
			doQuery($query, 101);
		}
	}
	print "<DIV align=center>\n";
	print "<H2>Add Multiple Computers</H2>\n";
	if($count == $addedrows)
		print "The computers were added successfully.<br><br>\n";
	else
		print $count - $addedrows . " computers failed to get added<br><br>\n";
	print "</div>\n";
	print "You can download data for /etc/hosts and dhcpd.conf or dhcpd.leases from the Computer Utilities page.\n";
	clearPrivCache();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewComputerGroups()
///
/// \brief prints a form for editing computer groups
///
////////////////////////////////////////////////////////////////////////////////
function viewComputerGroups() {
	global $mode;
	$platforminput = getContinuationVar('platforms', processInputVar("platforms", ARG_MULTINUMERIC));
	$scheduleinput = getContinuationVar("schedules", processInputVar("schedules", ARG_MULTINUMERIC));
	$groups = processInputVar('groups', ARG_MULTINUMERIC);

	$computers = getComputers(1);
	$tmp = getUserResources(array("computerAdmin"),
	                        array("manageGroup"), 1);
	$computergroups = $tmp["computer"];
	$computermembership = getResourceGroupMemberships("computer");
	$resources = getUserResources(array("computerAdmin"), array("manageGroup"));
	uasort($resources["computer"], "sortKeepIndex");

	if($mode == 'submitComputerGroups')
		$gridSelected = "selected=\"true\"";
	else
		$gridSelected = "";

	print "<H3>Computer Groups</H3>\n";
	print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	print "     style=\"width:800px;height:600px\">\n";

	# by computer tab
	print "<div id=\"resource\" dojoType=\"dijit.layout.ContentPane\" title=\"By Computer\">\n";
	print "Select a computer and click \"Get Groups\" to see all of the groups ";
	print "it is in. Then,<br>select a group it is in and click the Remove ";
	print "button to remove it from that group,<br>or select a group it is not ";
	print "in and click the Add button to add it to that group.<br><br>\n";
	print "Computer:<select name=comps id=comps>\n";
	# build list of computers
	foreach($resources["computer"] as $compid => $computer) {
		print "<option value=$compid>$computer</option>\n";
	}
	print "</select>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchGrpsButton\">\n";
	print "	Get Groups\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getGroupsButton();\n";
	print "	</script>\n";
	print "</button>\n";
	print "<table><tbody><tr>\n";
	# select for groups image is in
	print "<td valign=top>\n";
	print "Groups <span style=\"font-weight: bold;\" id=incompname></span> is in:<br>\n";
	print "<select name=ingroups multiple id=ingroups size=20>\n";
	print "</select>\n";
	print "</td>\n";
	# transfer buttons
	print "<td style=\"vertical-align: middle;\">\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"addBtn1\">\n";
	print "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJaddGroupToComp');
	print "		addRemItem('$cont', 'comps', 'outgroups', addRemComp2);\n";
	print "	</script>\n";
	print "</button>\n";
	print "<br>\n";
	print "<br>\n";
	print "<br>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"remBtn1\">\n";
	print "	<div style=\"width: 50px;\">Remove-&gt;</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJremGroupFromComp');
	print "		addRemItem('$cont', 'comps', 'ingroups', addRemComp2);\n";
	print "	</script>\n";
	print "</button>\n";
	print "</td>\n";
	# select for groups computer is not in
	print "<td valign=top>\n";
	print "Groups <span style=\"font-weight: bold;\" id=outcompname></span> is not in:<br>\n";
	print "<select name=outgroups multiple id=outgroups size=20>\n";
	print "</select>\n";
	print "</td>\n";
	print "</tr><tbody/></table>\n";
	print "</div>\n";

	# by group tab
	print "<div id=\"group\" dojoType=\"dijit.layout.ContentPane\" title=\"By Group\">\n";
	print "Select a group and click \"Get Computers\" to see all of the computers ";
	print "in it. Then,<br>select a computer in it and click the Remove ";
	print "button to remove it from the group,<br>or select a computer that is not ";
	print "in it and click the Add button to add it to the group.<br><br>\n";
	print "Group:<select name=compGroups id=compGroups>\n";
	# build list of groups
	foreach($computergroups as $id => $group) {
		print "<option value=$id>$group</option>\n";
	}
	print "</select>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchCompsButton\">\n";
	print "	Get Computers\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getCompsButton();\n";
	print "	</script>\n";
	print "</button>\n";
	print "<table><tbody><tr>\n";
	# select for images in group
	print "<td valign=top>\n";
	print "Computers in <span style=\"font-weight: bold;\" id=ingroupname></span>:<br>\n";
	print "<select name=incomps multiple id=incomps size=20>\n";
	print "</select>\n";
	print "</td>\n";
	# transfer buttons
	print "<td style=\"vertical-align: middle;\">\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"addBtn2\">\n";
	print "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJaddCompToGroup');
	print "		addRemItem('$cont', 'compGroups', 'outcomps', addRemGroup2);\n";
	print "	</script>\n";
	print "</button>\n";
	print "<br>\n";
	print "<br>\n";
	print "<br>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"remBtn2\">\n";
	print "	<div style=\"width: 50px;\">Remove-&gt;</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJremCompFromGroup');
	print "		addRemItem('$cont', 'compGroups', 'incomps', addRemGroup2);\n";
	print "	</script>\n";
	print "</button>\n";
	print "</td>\n";
	# computers not in group select
	print "<td valign=top>\n";
	print "Computers not in <span style=\"font-weight: bold;\" id=outgroupname></span>:<br>\n";
	print "<select name=outcomps multiple id=outcomps size=20>\n";
	print "</select>\n";
	print "</td>\n";
	print "</tr><tbody/></table>\n";
	print "</div>\n";

	# grid tab
	if(empty($gridSelected)) {
		$cdata = array('platforms' => $platforminput,
		               'schedules' => $scheduleinput,
		               'groups' => $groups);
	}
	else {
		$cdata = array('platforms' => getContinuationVar("platforms"),
		               'schedules' => getContinuationVar("schedules"),
		               'groups' => getContinuationVar("groups"));
	}
	$cont = addContinuationsEntry('compGroupingGrid', $cdata);
	$loadingmsg = "<span class=dijitContentPaneLoading>Loading page (this may take a really long time)</span>";
	print "<a jsId=\"checkboxpane\" dojoType=\"dijit.layout.LinkPane\"\n";
	print "   href=\"index.php?continuation=$cont\"\n";
	print "   loadingMessage=\"$loadingmsg\" $gridSelected>\n";
	print "   Checkbox Grid</a>\n";

	print "</div>\n"; # end of main tab container
	$cont = addContinuationsEntry('jsonCompGroupingComps');
	print "<input type=hidden id=compcont value=\"$cont\">\n";
	$cont = addContinuationsEntry('jsonCompGroupingGroups');
	print "<input type=hidden id=grpcont value=\"$cont\">\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn compGroupingGrid()
///
/// \brief prints a page to view and modify computer grouping
///
////////////////////////////////////////////////////////////////////////////////
function compGroupingGrid() {
	global $mode;
	$platforminput = getContinuationVar('platforms');
	$scheduleinput = getContinuationVar('schedules');
	$groups = getContinuationVar('groups');
	if(empty($groups)) {
		if(empty($platforminput) && empty($scheduleinput)) {
			print "No criteria selected to determine which computers to display.  Please go back<br>\n";
			print "to the <strong>Manage Computers</strong> page and select either a set of platforms<br>\n";
			print "and schedules or at least one computer group.<br>\n";
			return;
		}
		$bygroups = 0;
		$compidlist = array();
	}
	else {
		$bygroups = 1;
		$compidlist = getCompIdList($groups);
	}

	$computers = getComputers(1);
	$tmp = getUserResources(array("computerAdmin"),
	                        array("manageGroup"), 1);
	$computergroups = $tmp["computer"];
	$computermembership = getResourceGroupMemberships("computer");
	$resources = getUserResources(array("computerAdmin"), array("manageGroup"));
	uasort($resources["computer"], "sortKeepIndex");

	if($mode == "submitComputerGroups") {
		print "<font color=\"#008000\">Computer groups successfully updated";
		print "</font><br><br>\n";
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE border=1 id=layouttable summary=\"\">\n";
	print "  <col>\n";
	if($bygroups) {
		foreach($groups as $id) {
			print "  <col id=compgrp$id>\n";
		}
	}
	else {
		foreach(array_keys($computergroups) as $id) {
			print "  <col id=compgrp$id>\n";
		}
	}
	print "  <TR>\n";
	print "    <TH rowspan=2>Hostname</TH>\n";
	if($bygroups)
		print "    <TH class=nohlcol colspan=" . count($groups) . ">Groups</TH>\n";
	else
		print "    <TH class=nohlcol colspan=" . count($computergroups) . ">Groups</TH>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	if($bygroups) {
		foreach($groups as $id) {
			print "    <TH onclick=\"toggleColSelect('compgrp$id');\">{$computergroups[$id]}</TH>\n";
		}
	}
	else {
		foreach($computergroups as $id => $group) {
			print "    <TH onclick=\"toggleColSelect('compgrp$id');\">$group</TH>\n";
		}
	}
	print "  </TR>\n";
	$count = 1;
	foreach($resources["computer"] as $compid => $computer) {
		if($bygroups) {
			if(! array_key_exists($compid, $compidlist))
				continue;
		}
		else {
			if(! in_array($computers[$compid]["platformid"], $platforminput) ||
			   ! in_array($computers[$compid]["scheduleid"], $scheduleinput)) {
				continue;
			}
		}
		if($bygroups)
			$items = $groups;
		else
			$items = array_keys($computergroups);
		if($count % 20 == 0) {
			print "  <TR>\n";
			print "    <TH><img src=images/blank.gif></TH>\n";
			foreach($items as $id) {
				print "    <TH onclick=\"toggleColSelect('compgrp$id');\">{$computergroups[$id]}</TH>\n";
			}
			print "  </TR>\n";
		}
		print "  <TR id=compid$compid>\n";
		print "    <TH align=right onclick=\"toggleRowSelect('compid$compid');\">$computer</TH>\n";
		foreach($items as $groupid) {
			$name = "computergroup[" . $compid . ":" . $groupid . "]";
			if(array_key_exists($compid, $computermembership["computer"]) &&
			   in_array($groupid, $computermembership["computer"][$compid])) {
				$checked = "checked";
				$value = 1;
			}
			else {
				$checked = "";
				$value = 2;
			}
			print "    <TD align=center>\n";
			print "      <INPUT type=checkbox name=\"$name\" value=$value ";
			print "$checked>\n";
			print "    </TD>\n";
		}
		print "  </TR>\n";
		$count++;
	}
	print "</TABLE>\n";
	if($count > 1) {
		print "<INPUT type=submit value=\"Submit Changes\">\n";
		print "<INPUT type=reset value=Reset>\n";
		$cdata = array('platforms' => $platforminput,
		               'schedules' => $scheduleinput,
		               'groups' => $groups,
		               'compidlist' => $compidlist);
		# set a short timeout because this is a "last one in wins" page
		$cont = addContinuationsEntry('submitComputerGroups', $cdata, 300, 0, 0, 1);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	}
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitComputerGroups()
///
/// \brief updates computer groupings and notifies user
///
////////////////////////////////////////////////////////////////////////////////
function submitComputerGroups() {
	$platforminput = getContinuationVar("platforms");
	$scheduleinput = getContinuationVar("schedules");
	$groups = getContinuationVar("groups");
	$compidlist = getContinuationVar('compidlist');
	$groupinput = processInputVar("computergroup", ARG_MULTINUMERIC);

	if(empty($groups))
		$bygroups = 0;
	else
		$bygroups = 1;

	$computers = getComputers();

	# build an array of memberships currently in the db
	$tmp = getUserResources(array("groupAdmin"), array("manageGroup"), 1);
	$computergroupsIDs = array_keys($tmp["computer"]);  // ids of groups that user can manage
	$resources = getUserResources(array("computerAdmin"), 
	                              array("manageGroup"));
	$userCompIDs = array_keys($resources["computer"]); // ids of computers that user can manage
	$computermembership = getResourceGroupMemberships("computer");
	$basecomputergroups = $computermembership["computer"]; // all computer group memberships
	$computergroups = array();
	foreach(array_keys($basecomputergroups) as $compid) {
		if(in_array($compid, $userCompIDs)) {
			foreach($basecomputergroups[$compid] as $grpid) {
				if($bygroups && ! in_array($grpid, $groups))
					continue;
				if(in_array($grpid, $computergroupsIDs)) {
					if(array_key_exists($compid, $computergroups))
						array_push($computergroups[$compid], $grpid);
					else
						$computergroups[$compid] = array($grpid);
				}
			}
		}
	}

	$newmembers = array();
	foreach(array_keys($groupinput) as $key) {
		list($compid, $grpid) = explode(':', $key);
		if(array_key_exists($compid, $newmembers)) {
			array_push($newmembers[$compid], $grpid);
		}
		else {
			$newmembers[$compid] = array($grpid);
		}
	}

	$adds = array();
	$removes = array();
	foreach(array_keys($computers) as $compid) {
		if($bygroups) {
			if(! array_key_exists($compid, $compidlist))
				continue;
		}
		else {
			if(! in_array($computers[$compid]["platformid"], $platforminput) ||
			   ! in_array($computers[$compid]["scheduleid"], $scheduleinput))
				continue;
		}
		if(! array_key_exists($compid, $newmembers) &&
			! array_key_exists($compid, $computergroups)) {
			continue;
		}
		$id = $computers[$compid]["resourceid"];
		// check that $compid is in $newmembers, if not, remove it from all groups
		if(! array_key_exists($compid, $newmembers)) {
			$removes[$id] = $computergroups[$compid];
			continue;
		}
		// check that $compid is in $computergroups, if not, add all groups
		// in $newmembers
		if(! array_key_exists($compid, $computergroups)) {
			$adds[$id] = $newmembers[$compid];
			continue;
		}
		// adds are groupids that are in $newmembers, but not in $computergroups
		$adds[$id] = array_diff($newmembers[$compid], $computergroups[$compid]);
		if(count($adds[$id]) == 0) {
			unset($adds[$id]); 
		}
		// removes are groupids that are in $computergroups, but not in 
		// $newmembers
		$removes[$id] = array_diff($computergroups[$compid], $newmembers[$compid]);
		if(count($removes[$id]) == 0) {
			unset($removes[$id]);
		}
	}

	foreach(array_keys($adds) as $compid) {
		foreach($adds[$compid] as $grpid) {
			$query = "INSERT INTO resourcegroupmembers "
					 . "(resourceid, resourcegroupid) "
			       . "VALUES ($compid, $grpid)";
			doQuery($query, 285);
		}
	}

	foreach(array_keys($removes) as $compid) {
		foreach($removes[$compid] as $grpid) {
			$query = "DELETE FROM resourcegroupmembers "
					 . "WHERE resourceid = $compid AND "
					 .       "resourcegroupid = $grpid";
			doQuery($query, 286);
		}
	}

	viewComputerGroups();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn computerUtilities()
///
/// \brief prints a page for selecting multiple computers and then choosing from
/// a few utility type functions to operate on the selected computers
///
////////////////////////////////////////////////////////////////////////////////
function computerUtilities() {
	global $user, $mode, $skin;
	$data = processComputerInput(0);
	if(empty($data['groups']))
		$bygroups = 0;
	else {
		$bygroups = 1;
		$compidlist = getCompIdList($data['groups']);
	}
	$computers = getComputers(1);
	$resources = getUserResources(array("computerAdmin"), array("administer"));
	$userCompIDs = array_keys($resources["computer"]);
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$platforms = getPlatforms();
	$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"));
	$schedules = $tmp["schedule"];
	$allschedules = getSchedules();
	$images = getImages(1);

	print "<H2>Computer Utilities</H2>\n";
	print "<FORM dojoType=\"dijit.form.Form\" action=\"" . BASEURL . SCRIPT . "\" method=post id=utilform>\n";
	print "<TABLE border=1 id=layouttable summary=\"information about selected computers\">\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH>Hostname</TH>\n";
	print "    <TH>IP Address</TH>\n";
	print "    <TH>State</TH>\n";
	print "    <TH>Owner</TH>\n";
	#print "    <TH>Platform</TH>\n";
	print "    <TH>Schedule</TH>\n";
	print "    <TH>Current Image</TH>\n";
	print "    <TH>Next Image</TH>\n";
	print "    <TH>VM Host</TH>\n";
	/*print "    <TH>RAM(MB)</TH>\n";
	print "    <TH>No. Cores</TH>\n";
	print "    <TH>Processor Speed(MHz)</TH>\n";
	print "    <TH>Network Speed(Mbps)</TH>\n";
	print "    <TH>Computer ID</TH>\n";
	print "    <TH>Type</TH>\n";
	print "    <TH>No. of Reservations</TH>\n";*/
	print "    <TH>Notes</TH>\n";
	print "  </TR>\n";
	$count = 0;

	$statecolor = array(
	   'available' => '#008000',
		'reloading' => '#e58304',
	   'failed' => 'red'
	);

	$dispcompids = array();

	foreach(array_keys($computers) as $id) {
		if($bygroups) {
			if(! array_key_exists($id, $compidlist))
				continue;
		}
		elseif(! in_array($computers[$id]["platformid"], $data["platforms"]) ||
		   ! in_array($computers[$id]["scheduleid"], $data["schedules"])) 
			continue;
		if(! in_array($id, $userCompIDs)) {
			continue;
		}
		$dispcompids[] = $id;
		print "  <TR align=center id=compid$count>\n";
		print "    <TD><INPUT type=checkbox name=computerids[] value=$id ";
		print "id=comp$count onclick=\"toggleRowSelect('compid$count');\"></TD>\n";
		print "    <TD>" . $computers[$id]["hostname"] . "</TD>\n";
		print "    <TD>" . $computers[$id]["IPaddress"] . "</TD>\n";
		if(isset($statecolor[$computers[$id]['state']]))
			print "    <TD><font color={$statecolor[$computers[$id]['state']]}>{$computers[$id]["state"]}</font></TD>\n";
		else
			print "    <TD>" . $computers[$id]["state"] . "</TD>\n";
		print "    <TD>" . $computers[$id]["owner"] . "</TD>\n";
		#print "    <TD>{$platforms[$computers[$id]["platformid"]]}</TD>\n";
		print "    <TD>{$allschedules[$computers[$id]["scheduleid"]]["name"]}</TD>\n";
		print "    <TD>{$images[$computers[$id]["currentimgid"]]["prettyname"]}</TD>\n";
		if($computers[$id]["nextimgid"])
			print "    <TD>{$images[$computers[$id]["nextimgid"]]["prettyname"]}</TD>\n";
		else
			print "    <TD>(selected&nbsp;by&nbsp;system)</TD>\n";
		if(is_null($computers[$id]['vmhost']))
			print "    <TD>N/A</TD>\n";
		else
			print "    <TD>" . $computers[$id]["vmhost"] . "</TD>\n";
		/*print "    <TD>" . $computers[$id]["ram"] . "</TD>\n";
		print "    <TD>" . $computers[$id]["procnumber"] . "</TD>\n";
		print "    <TD>" . $computers[$id]["procspeed"] . "</TD>\n";
		print "    <TD>" . $computers[$id]["network"] . "</TD>\n";
		print "    <TD>$id</TD>\n";
		print "    <TD>" . $computers[$id]["type"] . "</TD>\n";*/
		if(empty($computers[$id]["notes"]))
			print "    <TD>&nbsp;</TD>\n";
		else {
			print "    <TD>" . str_replace('@', '<br>', $computers[$id]["notes"]);
			print "</TD>\n";
		}
		print "  </TR>\n";
		$count++;
	}
	print "</TABLE>\n";
	if($count == 0) {
		print "<br>0 computers found<br>\n";
		return;
	}
	print "<a href=# onclick=\"if(checkAllCompUtils()) return false;\">Check All</a> / \n";
	print "<a href=# onclick=\"if(uncheckAllCompUtils()) return false;\">Uncheck All</a><br>\n";
	print "<TABLE>\n";
	if(count($resources['image'])) {
		print "  <TR>\n";
		print "    <TD>Reload selected computers with this image:</TD>";
		print "    <TD>\n";
		printSelectInput("imageid", $resources["image"], -1, 1);
		print "    </TD>\n";
		print "    <TD><INPUT type=button onclick=reloadComputerSubmit(); value=\"Confirm Reload\"></TD>";
		$cont = addContinuationsEntry('reloadComputers', array(), SECINDAY, 0);
		print "    <INPUT type=hidden id=reloadcont value=\"$cont\">\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TD>Change state of or delete selected computers:</TD>";
	$states = array("2" => "available",
	                "23" => "hpc",
	                "10" => "maintenance",
	                "20" => "convert to vmhostinuse",
	                "999" => "DELETE");
	print "    <TD colspan=2>\n";
	printSelectInput("stateid", $states);
	print "    <INPUT type=button onclick=\"compStateChangeSubmit();\" value=\"Confirm Change\">";
	print "    </TD>\n";
	$cont = addContinuationsEntry('compStateChange', array(), SECINDAY, 0);
	print "    <INPUT type=hidden id=statecont value=\"$cont\">\n";
	print "  </TR>\n";
	if(count($schedules)) {
		print "  <TR>\n";
		print "    <TD>Change schedule of selected computers to:</TD>";

		uasort($schedules, "sortKeepIndex");

		print "    <TD colspan=2>\n";
		printSelectInput("scheduleid", $schedules);
		print "    <INPUT type=button onclick=compScheduleChangeSubmit(); ";
		print "value=\"Confirm Schedule Change\">";
		print "    </TD>\n";
		$cont = addContinuationsEntry('compScheduleChange', array(), SECINDAY, 0);
		print "    <INPUT type=hidden id=schcont value=\"$cont\">\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TD>For selected computers, generate computer data for:</TD>";
	print "    <TD>\n";
	$tmp = array('dhcpd' => 'dhcpd', 'hosts' => '/etc/hosts');
	printSelectInput('generatetype', $tmp, -1, 0, 0, 'generatetype');
	print "    <INPUT type=button onclick=\"generateCompData();\" value=\"Generate Data\">";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<INPUT type=\"hidden\" name=\"continuation\" id=\"utilformcont\">\n";
	print "</FORM>\n";

	print "<br>$count computers found<br>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "      id=\"utildialog\"\n";
	print "      title=\"Generate Data\"\n";
	print "      duration=250\n";
	print "      draggable=true>\n";
	print "   <div id=\"utilerror\" style=\"text-align: center\" ";
	print "class=\"hidden rederrormsg\"></div>\n";
	print "   <div class=\"hidden\" id=\"mgmtipdiv\">\n";
	print "     Enter Management Node Private IP Address:<br>\n";
	print "     <input type=\"text\" id=\"mnip\">\n";
	print "     <button id=\"gendhcpbtn\" dojoType=\"dijit.form.Button\">\n";
	print "     Generate Data\n";
	print "     <script type=\"dojo/method\" event=\"onClick\">\n";
	print "       generateDHCPDdata();\n";
	print "     </script>\n";
	print "     </button>\n";
	print "   </div>\n";
	print "   <div id=\"utilloading\" style=\"text-align: center\" class=\"hidden\">";
	print "<img src=\"themes/$skin/css/dojo/images/loading.gif\" ";
	print "style=\"vertical-align: middle;\"> Loading...</div>\n";
	print "   <div id=\"utilcontent\"></div>\n";
	$cdata = array('dispcompids' => $dispcompids);
	$cont = addContinuationsEntry('AJgenerateUtilData', $cdata, SECINDAY);
	print "   <input type=\"hidden\" id=\"utilcont\" value=\"$cont\">\n";
	print "   <div align=\"center\">\n";
	print "   <button id=\"utilcancel\" dojoType=\"dijit.form.Button\">\n";
	print "     Close\n";
	print "	   <script type=\"dojo/method\" event=\"onClick\">\n";
	print "       dijit.byId('utildialog').hide();\n";
	print "     </script>\n";
	print "   </button>\n";
	print "   </div>\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn reloadComputers()
///
/// \brief confirms reloading submitted computers with the selected image
///
////////////////////////////////////////////////////////////////////////////////
function reloadComputers() {
	global $user;
	$data = processComputerInput3();
	$computers = getComputers(1);
	$imagedata = getImages(0, $data['imageid']);
	$reloadnow = array();
	$reloadasap = array();
	$noreload = array();
	foreach($data['computerids'] as $compid) {
		switch($computers[$compid]['state']) {
		case "available":
		case "failed":
		case "reloading":
			array_push($reloadnow, $compid);
			break;
		case "inuse":
		case "timeout":
		case "reserved":
			array_push($reloadasap, $compid);
			break;
		case "maintenance":
			array_push($noreload, $compid);
			break;
		default:
			array_push($noreload, $compid);
			break;
		}
	}
	print "<H2>Reload Computers</H2>\n";
	if(count($reloadnow)) {
		print "The following computers will be immediately reloaded with ";
		print "{$imagedata[$data['imageid']]['prettyname']}:<br>\n";
		print "<TABLE>\n";
		foreach($reloadnow as $compid) {
			print "  <TR>\n";
			print "    <TD><font color=\"#008000\">{$computers[$compid]['hostname']}</font></TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
		print "<br>\n";
	}

	if(count($reloadasap)) {
		print "The following computers are currently in use and will be ";
		print "reloaded with {$imagedata[$data['imageid']]['prettyname']} at the end ";
		print "of the user's reservation:<br>\n";
		print "<TABLE>\n";
		foreach($reloadasap as $compid) {
			print "  <TR>\n";
			print "    <TD><font color=\"ff8c00\">{$computers[$compid]['hostname']}</font></TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
		print "<br>\n";
	}

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<INPUT type=submit value=\"Reload Computers\"><br>\n";
	$data['imagename'] = $imagedata[$data['imageid']]['prettyname'];
	$cont = addContinuationsEntry('submitReloadComputers', $data, SECINDAY, 0, 0);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM>\n";

	if(count($noreload)) {
		print "The following computers are currently in the maintenance ";
		print "state and therefore will have nothing done to them:<br>\n";
		print "<TABLE>\n";
		foreach($noreload as $compid) {
			print "  <TR>\n";
			print "    <TD><font color=\"#ff0000\">{$computers[$compid]['hostname']}</font></TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
		print "<br>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitReloadComputers()
///
/// \brief configures system to reloaded submitted computers with submitted
/// image
///
////////////////////////////////////////////////////////////////////////////////
function submitReloadComputers() {
	$data = getContinuationVar();

	$start = getReloadStartTime();
	$end = $start + 1200; // + 20 minutes
	$startstamp = unixToDatetime($start);
	$endstamp = unixToDatetime($end);
	$imagerevisionid = getProductionRevisionid($data['imageid']);

	// get semaphore lock
	if(! semLock())
		abort(3);
	$computers = getComputers(1);
	$reloadnow = array();
	$reloadasap = array();
	foreach($data['computerids'] as $compid) {
		switch($computers[$compid]['state']) {
		case "available":
		case "failed":
			array_push($reloadnow, $compid);
			break;
		case "reload":
		case "reloading":
		case "inuse":
		case "timeout":
		case "reserved":
			array_push($reloadasap, $compid);
			break;
		}
	}
	$vclreloadid = getUserlistID('vclreload@Local');
	$fails = array();
	$passes = array();
	foreach($reloadnow as $compid) {
		if(simpleAddRequest($compid, $data['imageid'], $imagerevisionid, $startstamp, $endstamp, 19, $vclreloadid))
			$passes[] = $compid;
		else
			$fails[] = $compid;
	}
	// release semaphore lock
	semUnlock();

	if(count($reloadasap)) {
		$compids = implode(',', $reloadasap);
		$query = "UPDATE computer "
		       . "SET nextimageid = {$data['imageid']} "
		       . "WHERE id IN ($compids)";
		doQuery($query, 101);
	}
	print "<H2>Reload Computers</H2>\n";
	if(count($passes)) {
		print "The following computers are being immediately reloaded with ";
		print "{$data['imagename']}:<br>\n";
		foreach($passes as $compid)
			print "<font color=\"#008000\">{$computers[$compid]['hostname']}</font><br>\n";
	}
	if(count($reloadasap)) {
		if(count($passes))
			print "<br>";
		print "The following computers will be reloaded with ";
		print "{$data['imagename']} after their current reservations are over:<br>\n";
		foreach($reloadasap as $compid)
			print "<font color=\"ff8c00\">{$computers[$compid]['hostname']}</font><br>\n";
	}
	if(count($fails)) {
		if(count($passes) || count($reloadasap))
			print "<br>";
		print "No functional management node was found for the following ";
		print "computers. They could not be reloaded at this time:<br>\n";
		foreach($fails as $compid)
			print "<font color=\"ff0000\">{$computers[$compid]['hostname']}</font><br>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn compStateChange()
///
/// \brief confirms changing computers to selected state, and if new state is
/// maintenance, asks for reason
///
////////////////////////////////////////////////////////////////////////////////
function compStateChange() {
	global $submitErr;
	print "<H2>Change State of Computers</H2>\n";
	$data = processComputerInput3();
	$computers = getComputers(1);
	if($data['stateid'] == 10) {
		$notes = explode('@', $data['notes']);
		if(count($notes) != 2)
			$notes[1] = "";
	}
	if($data['stateid'] == 2) {
		print "You are about to place the following computers into the ";
		print "available state:\n";
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	}
	elseif($data['stateid'] == 10) {
		print "Please enter a reason you are changing the following computers to ";
		print "the maintenance state:<br><br>\n";
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "<TEXTAREA name=notes rows=4 cols=35>{$notes[1]}</TEXTAREA><br>\n";
		print "<br>Selected computers:\n";
	}
	elseif($data['stateid'] == 20) {
		$profiles = getVMProfiles();
		$data['profiles'] = $profiles;
		print "Select a VM Host Profile and then click <strong>Submit</strong>\n";
		print "to place the computers into the vmhostinuse state:<br><br>\n";
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "<select name=\"profileid\">\n";
		foreach($profiles as $id => $profile)
			print "<option value=\"$id\">{$profile['profilename']}</option>\n";
		print "</select><br><br>\n";
		print "<br><br>\n";
	}
	elseif($data['stateid'] == 23) {
		print "You are about to place the following computers into the ";
		print "hpc state:\n";
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	}
	elseif($data['stateid'] == 999) {
		print "You are about to <font color=\"FF0000\">DELETE</font> the following computers";
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	}

	$cont = addContinuationsEntry('submitCompStateChange', $data, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<TABLE>\n";
	foreach($data['computerids'] as $compid) {
		print "  <TR>\n";
		#print "    <TD><font color=\"#008000\">{$computers[$compid]['hostname']}</font></TD>\n";
		print "    <TD>{$computers[$compid]['hostname']}</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "<br>\n";
	print "<INPUT type=submit value=Submit>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitCompStateChange()
///
/// \brief configures system to put submitted computers in submitted state
///
////////////////////////////////////////////////////////////////////////////////
function submitCompStateChange() {
	global $user;
	print "<H2>Change State of Computers</H2>\n";
	$data = getContinuationVar();
	$computers = getComputers(1);
	# switching to available
	if($data['stateid'] == 2) {
		$compids = implode(',', $data['computerids']);
		$query = "UPDATE computer "
		       . "SET stateid = 2, "
		       .     "notes = '' "
		       . "WHERE id IN ($compids)";
		doQuery($query, 101);
		print "The following computers were changed to the available state:\n";
		print "<TABLE>\n";
		foreach($data['computerids'] as $compid) {
			print "  <TR>\n";
			print "    <TD>{$computers[$compid]['hostname']}</TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
	}
	# switching to maintenance
	elseif($data['stateid'] == 10) {
		$data['notes'] = processInputVar('notes', ARG_STRING);
		if(get_magic_quotes_gpc())
			$data['notes'] = stripslashes($data['notes']);
		$data['notes'] = mysql_real_escape_string($data['notes']);
		$data["notes"] = $user["unityid"] . " " . unixToDatetime(time()) . "@"
		               . $data["notes"];
		$vclreloadid = getUserlistID('vclreload@Local');
		$imageid = getImageId('noimage');
		$imagerevisionid = getProductionRevisionid($imageid);
		$noaction = array();
		$changenow = array();
		$changeasap = array();
		$changetimes = array();
		$changetimes2 = array();
		foreach($data['computerids'] as $compid) {
			if($computers[$compid]['state'] == 'maintenance')
				array_push($noaction, $compid);
			else
				array_push($changeasap, $compid);
		}
		$passes = array();
		$fails = array();
		$blockallocs = array();
		$blockfails = array();
		// get semaphore lock
		if(! semLock())
			abort(3);
		foreach($changeasap as $compid) {
			# try to move future reservations off of computer
			moveReservationsOffComputer($compid);
			# get end time of last reservation
			$query = "SELECT rq.end "
			       . "FROM request rq, "
			       .      "reservation rs "
			       . "WHERE rs.requestid = rq.id AND "
			       .       "rs.computerid = $compid AND "
			       .       "rq.stateid NOT IN (1,5,12) "
			       . "ORDER BY end DESC "
			       . "LIMIT 1";
			$qh = doQuery($query, 101);
			$query2 = "SELECT t.end "
			        . "FROM blockComputers c, "
			        .      "blockTimes t "
			        . "WHERE c.computerid = $compid AND "
			        .       "c.blockTimeid = t.id AND "
			        .       "t.end > NOW() "
			        . "ORDER BY t.end DESC "
			        . "LIMIT 1";
			$qh2 = doQuery($query2, 101);
			# create a really long reservation starting at that time in state tomaintenance
			if($row = mysql_fetch_assoc($qh)) {
				$start = $row['end'];
				$changetimes[$compid] = $start;
				$end = datetimeToUnix($start) + SECINWEEK; // hopefully keep future reservations off of it
				$end = unixToDatetime($end);
				if(simpleAddRequest($compid, $imageid, $imagerevisionid, $start, $end, 18, $vclreloadid))
					$passes[] = $compid;
				else
					$fails[] = $compid;
			}
			// if part of a block allocation, create a really long reservation
			#   starting at the block allocation end time in state tomaintenance
			elseif($row = mysql_fetch_assoc($qh2)) {
				$start = $row['end'];
				$changetimes2[$compid] = $start;
				$end = datetimeToUnix($start) + SECINWEEK; // hopefully keep future reservations off of it
				$end = unixToDatetime($end);
				if(simpleAddRequest($compid, $imageid, $imagerevisionid, $start, $end, 18, $vclreloadid))
					$blockallocs[] = $compid;
				else
					$blockfails[] = $compid;
			}
			# change to maintenance state and save in $changenow
			// if we wait and put them all in maintenance at the same time,
			# we may end up moving reservations to the computer later in the
			# loop
			else {
				$query = "UPDATE computer "
				       . "SET stateid = 10, "
				       .     "notes = '{$data['notes']}' "
				       . "WHERE id = $compid";
				doQuery($query, 101);
				unset_by_val($compid, $changeasap);
				array_push($changenow, $compid);
			}
		}
		// release semaphore lock
		semUnlock();
		if(count($noaction) || count($changeasap)) {
			$comparr = array_merge($noaction, $changeasap);
			$compids = implode(',', $comparr);
			$query = "UPDATE computer "
			       . "SET notes = '{$data['notes']}' "
			       . "WHERE id IN ($compids)";
			doQuery($query, 101);
		}
		if(count($changenow)) {
			print "The following computers were immediately placed into the ";
			print "maintenance state:\n";
			print "<TABLE>\n";
			foreach($changenow as $compid) {
				print "  <TR>\n";
				print "    <TD><font color=\"#008000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($passes)) {
			print "The following computers currently have reservations on them ";
			print "and will be placed in the maintenance state at the time listed ";
			print "for each computer:\n";
			print "<TABLE>\n";
			print "  <TR>\n";
			print "    <TH>Computer</TH>\n";
			print "    <TH>Maintenance time</TH>\n";
			print "  </TR>\n";
			foreach($passes as $compid) {
				print "  <TR>\n";
				print "    <TD align=center><font color=\"ff8c00\">{$computers[$compid]['hostname']}</font></TD>\n";
				$time = date('n/j/y g:i a', datetimeToUnix($changetimes[$compid]));
				print "    <TD align=center>$time</TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($fails)) {
			print "The following computers currently have reservations on them ";
			print "but no functional management node was found for them. Nothing will ";
			print "be done with them at this time:\n";
			print "<TABLE>\n";
			foreach($fails as $compid) {
				print "  <TR>\n";
				print "    <TD align=center><font color=\"ff0000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($blockallocs)) {
			print "The following computers are part of an upcoming block allocation ";
			print "and will be placed in the maintenance state at the time listed ";
			print "for each computer:\n";
			print "<TABLE>\n";
			print "  <TR>\n";
			print "    <TH>Computer</TH>\n";
			print "    <TH>Maintenance time</TH>\n";
			print "  </TR>\n";
			foreach($blockallocs as $compid) {
				print "  <TR>\n";
				print "    <TD align=center><font color=\"ff8c00\">{$computers[$compid]['hostname']}</font></TD>\n";
				$time = date('n/j/y g:i a', datetimeToUnix($changetimes2[$compid]));
				print "    <TD align=center>$time</TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($blockfails)) {
			print "The following computers currently have reservations on them ";
			print "but no functional management node was found for them. Nothing will ";
			print "be done with them at this time:\n";
			print "<TABLE>\n";
			foreach($blockfails as $compid) {
				print "  <TR>\n";
				print "    <TD align=center><font color=\"ff0000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($noaction)) {
			print "The following computers were already in the maintenance ";
			print "state and had their notes on being in the maintenance state ";
			print "updated:\n";
			print "<TABLE>\n";
			foreach($noaction as $compid) {
				print "  <TR>\n";
				print "    <TD>{$computers[$compid]['hostname']}</TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
	}
	# switching to vmhostinuse
	elseif($data['stateid'] == 20) {
		$profileid = processInputVar('profileid', ARG_NUMERIC);
		if(! array_key_exists($profileid, $data['profiles'])) {
			$keys = array_keys($data['profiles']);
			$profileid = $keys[0];
		}
		$vclreloadid = getUserlistID('vclreload@Local');
		$imagerevisionid = getProductionRevisionid($data['profiles'][$profileid]['imageid']);
		$noaction = array();
		$changenow = array();
		$changeasap = array();
		$blockalloc = array();
		$changetimes = array();
		$fails = array();
		foreach($data['computerids'] as $compid) {
			if($computers[$compid]['state'] == 'vmhostinuse')
				array_push($noaction, $compid);
			else
				array_push($changeasap, $compid);
		}
		// get semaphore lock
		if(! semLock())
			abort(3);
		foreach($changeasap as $compid) {
			moveReservationsOffComputer($compid);
			# get end time of last reservation
			$query = "SELECT rq.end "
			       . "FROM request rq, "
			       .      "reservation rs "
			       . "WHERE rs.requestid = rq.id AND "
			       .       "rs.computerid = $compid AND "
			       .       "rq.stateid NOT IN (1,5,12) "
			       . "ORDER BY end DESC "
			       . "LIMIT 1";
			$qh = doQuery($query, 101);
			$query2 = "SELECT c.computerid "
			        . "FROM blockComputers c, "
			        .      "blockTimes t "
			        . "WHERE c.computerid = $compid AND "
			        .       "c.blockTimeid = t.id AND "
			        .       "t.end > NOW()";
			$qh2 = doQuery($query2, 101);
			if($row = mysql_fetch_assoc($qh)) {
				// if there is a reservation, leave in $changeasap so we can
				#   notify that we can't change this one
			}
			// if computer allocated to block allocation remove from $changeasap
			#    and add to $blockalloc
			elseif($row = mysql_fetch_assoc($qh2)) {
				unset_by_val($compid, $changeasap);
				$blockalloc[] = $compid;
			}
			# change to vmhostinuse state and save in $changenow
			// if we wait and put them all in vmhostinuse at the same time,
			# we may end up moving reservations to the computer later in the
			# loop
			else {
				# create a reload reservation to load machine with image
				#   corresponding to selected vm profile
				$start = getReloadStartTime();
				$end = $start + SECINYEAR; # don't want anyone making a future reservation for this machine
				$start = unixToDatetime($start);
				$end = unixToDatetime($end);
				if(simpleAddRequest($compid, $data['profiles'][$profileid]['imageid'],
				                    $imagerevisionid, $start, $end, 21, $vclreloadid)) {
					$changenow[] = $compid;
				}
				else
					$fails[] = $compid;
				unset_by_val($compid, $changeasap);

				# check for existing vmhost entry
				$query = "SELECT id, "
				       .        "vmprofileid "
				       . "FROM vmhost "
				       . "WHERE computerid = $compid";
				$qh = doQuery($query, 101);
				if($row = mysql_fetch_assoc($qh)) {
					if($row['vmprofileid'] != $profileid) {
						# update vmprofile
						$query = "UPDATE vmhost "
						       . "SET vmprofileid = $profileid "
						       . "WHERE id = {$row['id']}";
						doQuery($query, 101);
					}
				}
				else {
					# create vmhost entry
					$query = "INSERT INTO vmhost "
					       .        "(computerid, "
					       .        "vmlimit, "
					       .        "vmprofileid) "
					       . "VALUES ($compid, "
					       .        "2, "
					       .        "$profileid)";
					doQuery($query, 101);
				}
			}
		}
		// release semaphore lock
		semUnlock();
		if(count($changenow)) {
			print "The following computers were placed into the ";
			print "vmhostinuse state:\n";
			print "<TABLE>\n";
			foreach($changenow as $compid) {
				print "  <TR>\n";
				print "    <TD><font color=\"#008000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($fails)) {
			print "The following computers had no reservations on them but no ";
			print "functional management node was found to reload them with the ";
			print "VM host image. Nothing will be done with them at this time:\n";
			print "<TABLE>\n";
			foreach($fails as $compid) {
				print "  <TR>\n";
				print "    <TD align=center><font color=\"ff0000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($changeasap)) {
			print "The following computers currently have reservations on them ";
			print "and cannot be placed in the vmhostinuse state at this time:\n";
			print "<TABLE>\n";
			foreach($changeasap as $compid) {
				print "  <TR>\n";
				print "    <TD><font color=\"ff0000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($blockalloc)) {
			print "The following computers are part of an upcoming block allocation ";
			print "and cannot be placed in the vmhostinuse state at this time:\n";
			print "<TABLE>\n";
			foreach($blockalloc as $compid) {
				print "  <TR>\n";
				print "    <TD><font color=\"ff0000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($noaction)) {
			print "The following computers were already in the vmhostinuse ";
			print "state:\n";
			print "<TABLE>\n";
			foreach($noaction as $compid) {
				print "  <TR>\n";
				print "    <TD>{$computers[$compid]['hostname']}</TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
	}
	# switching to hpc
	elseif($data['stateid'] == 23) {
		$noaction = array();
		$changenow = array();
		$changeasap = array();
		$blockalloc = array();
		$changetimes = array();
		foreach($data['computerids'] as $compid) {
			if($computers[$compid]['state'] == 'hpc')
				array_push($noaction, $compid);
			else
				array_push($changeasap, $compid);
		}
		if(! semLock())
			abort(3);
		foreach($changeasap as $compid) {
			moveReservationsOffComputer($compid);
			# get end time of last reservation
			$query = "SELECT rq.end "
			       . "FROM request rq, "
			       .      "reservation rs "
			       . "WHERE rs.requestid = rq.id AND "
			       .       "rs.computerid = $compid AND "
			       .       "rq.stateid NOT IN (1,5,12) "
			       . "ORDER BY end DESC "
			       . "LIMIT 1";
			$qh = doQuery($query, 101);
			$query2 = "SELECT c.computerid "
			        . "FROM blockComputers c, "
			        .      "blockTimes t "
			        . "WHERE c.computerid = $compid AND "
			        .       "c.blockTimeid = t.id AND "
			        .       "t.end > NOW()";
			$qh2 = doQuery($query2, 101);
			if($row = mysql_fetch_assoc($qh)) {
				// if there is a reservation, leave in $changeasap so we can
				#   notify that we can't change this one
			}
			// if computer allocated to block allocation remove from $changeasap
			#    and add to $blockalloc
			elseif($row = mysql_fetch_assoc($qh2)) {
				unset_by_val($compid, $changeasap);
				$blockalloc[] = $compid;
			}
			# change to hpc state and save in $changenow
			// if we wait and put them all in hpc at the same time,
			# we may end up moving reservations to the computer later in the
			# loop
			else {
				$query = "UPDATE computer "
				       . "SET stateid = 23 "
				       . "WHERE id = $compid";
				doQuery($query, 101);
				unset_by_val($compid, $changeasap);
				array_push($changenow, $compid);
			}
		}
		// release semaphore lock
		semUnlock();
		if(count($changenow)) {
			print "The following computers were placed into the ";
			print "hpc state:\n";
			print "<TABLE>\n";
			foreach($changenow as $compid) {
				print "  <TR>\n";
				print "    <TD><font color=\"#008000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($changeasap)) {
			print "The following computers currently have reservations on them ";
			print "and cannot be placed in the hpc state at this time:\n";
			print "<TABLE>\n";
			foreach($changeasap as $compid) {
				print "  <TR>\n";
				print "    <TD><font color=\"ff0000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($blockalloc)) {
			print "The following computers are part of an upcoming block allocation ";
			print "and cannot be placed in the hpc state at this time:\n";
			print "<TABLE>\n";
			foreach($blockalloc as $compid) {
				print "  <TR>\n";
				print "    <TD><font color=\"ff0000\">{$computers[$compid]['hostname']}</font></TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
		if(count($noaction)) {
			print "The following computers were already in the hpc ";
			print "state:\n";
			print "<TABLE>\n";
			foreach($noaction as $compid) {
				print "  <TR>\n";
				print "    <TD>{$computers[$compid]['hostname']}</TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
			print "<br>\n";
		}
	}
	# set to deleted
	elseif($data['stateid'] == 999) {
		$compids = implode(',', $data['computerids']);
		$query = "UPDATE computer "
		       . "SET deleted = 1, "
		       .     "datedeleted = NOW(), "
		       .     "hostname = REPLACE(hostname, CONCAT('-UNDELETED-', id), ''), "
		       .     "vmhostid = NULL "
		       . "WHERE id IN ($compids)";
		doQuery($query, 999);
		print "The following computers were deleted:\n";
		print "<TABLE>\n";
		foreach($data['computerids'] as $compid) {
			print "  <TR>\n";
			print "    <TD>{$computers[$compid]['hostname']}</TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
	}
	else
		abort(50);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn compScheduleChange()
///
/// \brief confirms changing computers to selected schedule
///
////////////////////////////////////////////////////////////////////////////////
function compScheduleChange() {
	global $submitErr;
	print "<H2>Change Schedule of Computers</H2>\n";
	$data = processComputerInput3();
	$computers = getComputers(1);
	$schedules = getSchedules();
	print "You are about to place the following computer(s) into schedule ";
	print "<strong><big>{$schedules[$data['scheduleid']]['name']}</big></strong>";
	print ".<br><strong>Note:</strong> ";
	print "This will not affect reservations currently on the computer(s).  It ";
	print "will only affect new reservations made on the computer(s).<br>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('scheduleid' => $data['scheduleid'],
	               'schedule' => $schedules[$data['scheduleid']]['name'],
	               'computerids' => $data['computerids']);
	$cont = addContinuationsEntry('submitCompScheduleChange', $cdata, SECINDAY, 1, 0);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<TABLE>\n";
	foreach($data['computerids'] as $compid) {
		print "  <TR>\n";
		print "    <TD>{$computers[$compid]['hostname']}</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "<INPUT type=submit value=Submit>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitCompScheduleChange()
///
/// \brief configures system to put submitted computers in submitted state
///
////////////////////////////////////////////////////////////////////////////////
function submitCompScheduleChange() {
	global $user;
	print "<H2>Change Schedule of Computers</H2>\n";
	$data = getContinuationVar();
	$computers = getComputers(1);
	$compids = implode(',', $data['computerids']);
	$query = "UPDATE computer "
	       . "SET scheduleid = {$data['scheduleid']} "
	       . "WHERE id IN ($compids)";
	doQuery($query, 101);
	print "The schedule for the following computer(s) was set to ";
	print "{$data['schedule']}:<br>\n";
	print "<TABLE>\n";
	foreach($data['computerids'] as $compid) {
		print "  <TR>\n";
		print "    <TD>{$computers[$compid]['hostname']}</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processComputerInput($checks)
///
/// \param $checks - (optional) 1 to perform validation, 0 not to
///
/// \return an array with the following keys:\n
/// bulk, ipaddress, stateid, platformid, scheduleid, currentimgid,
/// ram, numprocs, procspeed, network, hostname, compid, type
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processComputerInput($checks=1) {
	global $submitErr, $submitErrMsg, $mode;
	$return = processComputerInput2();

	$return["bulk"] = getContinuationVar("bulk", processInputVar("bulk", ARG_NUMERIC));
	$return["ipaddress"] = getContinuationVar("ipaddress", processInputVar("ipaddress", ARG_STRING, NULL, 1));
	$return["pripaddress"] = getContinuationVar("pripaddress", processInputVar("pripaddress", ARG_STRING, NULL, 1));
	$return["eth0macaddress"] = getContinuationVar("eth0macaddress", processInputVar("eth0macaddress", ARG_STRING, NULL, 1));
	$return["eth1macaddress"] = getContinuationVar("eth1macaddress", processInputVar("eth1macaddress", ARG_STRING, NULL, 1));
	$return["stateid"] = getContinuationVar("stateid", processInputVar("stateid", ARG_NUMERIC));
	$return["owner"] = getContinuationVar("owner", processInputVar("owner", ARG_STRING, NULL, 1));
	$return["platformid"] = getContinuationVar("platformid", processInputVar("platformid", ARG_NUMERIC));
	$return["scheduleid"] = getContinuationVar("scheduleid", processInputVar("scheduleid", ARG_NUMERIC));
	$return["currentimgid"] = getContinuationVar("currentimgid", processInputVar("currentimgid", ARG_NUMERIC));
	$return["ram"] = getContinuationVar("ram", processInputVar("ram", ARG_NUMERIC, NULL, 1));
	$return["numprocs"] = getContinuationVar("numprocs", processInputVar("numprocs", ARG_NUMERIC, 1));
	$return["procspeed"] = getContinuationVar("procspeed", processInputVar("procspeed", ARG_NUMERIC, NULL, 1));
	$return["network"] = getContinuationVar("network", processInputVar("network", ARG_NUMERIC));
	$return["hostname"] = getContinuationVar("hostname", processInputVar("hostname", ARG_STRING, NULL, 1));
	$return["compid"] = getContinuationVar("compid", processInputVar("compid", ARG_NUMERIC));
	$return["type"] = getContinuationVar("type", processInputVar("type", ARG_STRING, "blade"));
	$return["provisioningid"] = getContinuationVar("provisioningid", processInputVar("provisioningid", ARG_NUMERIC));
	$return["notes"] = getContinuationVar("notes", processInputVar("notes", ARG_STRING));
	$return["computergroup"] = getContinuationVar("computergroup", processInputVar("computergroup", ARG_MULTINUMERIC));
	$return["showcounts"] = getContinuationVar("showcounts", processInputVar("showcounts", ARG_NUMERIC));
	$return["location"] = getContinuationVar('location', processInputVar('location', ARG_STRING));
	$return["vmprofileid"] = getContinuationVar('vmprofileid', processInputVar('vmprofileid', ARG_NUMERIC));
	$return["showdeleted"] = getContinuationVar('showdeleted', 0);
	$return['states'] = getContinuationVar('states');
	$return['profiles'] = getContinuationVar('profiles', array());

	if(! $checks) {
		return $return;
	}

	$ipaddressArr = explode('.', $return["ipaddress"]);
	if(! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $return["ipaddress"]) ||
		$ipaddressArr[0] < 1 || $ipaddressArr[0] > 255 ||
		$ipaddressArr[1] < 0 || $ipaddressArr[1] > 255 ||
		$ipaddressArr[2] < 0 || $ipaddressArr[2] > 255 ||
		$ipaddressArr[3] < 0 || $ipaddressArr[3] > 255) {
	   $submitErr |= IPADDRERR;
	   $submitErrMsg[IPADDRERR] = "Invalid IP address. Must be w.x.y.z with each of "
		                         . "w, x, y, and z being between 1 and 255 (inclusive)";
	}
	$pripaddressArr = explode('.', $return["pripaddress"]);
	if(strlen($return['pripaddress']) &&
	   (! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $return["pripaddress"]) ||
		$pripaddressArr[0] < 1 || $pripaddressArr[0] > 255 ||
		$pripaddressArr[1] < 0 || $pripaddressArr[1] > 255 ||
		$pripaddressArr[2] < 0 || $pripaddressArr[2] > 255 ||
		$pripaddressArr[3] < 0 || $pripaddressArr[3] > 255)) {
	   $submitErr |= IPADDRERR2;
	   $submitErrMsg[IPADDRERR2] = "Invalid IP address. Must be w.x.y.z with each of "
		                          . "w, x, y, and z being between 1 and 255 (inclusive)";
	}
	if(strlen($return['eth0macaddress']) &&
	   ! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $return["eth0macaddress"])) {
		$submitErr |= MACADDRERR2;
		$submitErrMsg[MACADDRERR2] = "Invalid MAC address.  Must be XX:XX:XX:XX:XX:XX "
		                           . "with each pair of XX being from 00 to FF (inclusive)";
	}
	if(! ($submitErr & MACADDRERR2) &&
	   checkForMACaddress($return['eth0macaddress'], 0, $return['compid'])) {
	   $submitErr |= MACADDRERR2;
	   $submitErrMsg[MACADDRERR2] = "There is already a computer with this MAC address.";
	}
	if(strlen($return['eth1macaddress']) &&
	   ! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $return["eth1macaddress"])) {
		$submitErr |= MACADDRERR;
		$submitErrMsg[MACADDRERR] = "Invalid MAC address.  Must be XX:XX:XX:XX:XX:XX "
		                          . "with each pair of XX being from 00 to FF (inclusive)";
	}
	if(! ($submitErr & MACADDRERR) &&
	   checkForMACaddress($return['eth1macaddress'], 1, $return['compid'])) {
	   $submitErr |= MACADDRERR;
	   $submitErrMsg[MACADDRERR] = "There is already a computer with this MAC address.";
	}
	/*if(! ($submitErr & IPADDRERR) && 
	   checkForIPaddress($return["ipaddress"], $return["compid"])) {
	   $submitErr |= IPADDRERR;
	   $submitErrMsg[IPADDRERR] = "There is already a computer with this IP address.";
	}*/
	if($return["ram"] < 32 || $return["ram"] > 8388607) {
	   $submitErr |= RAMERR;
	   $submitErrMsg[RAMERR] = "RAM must be between 32 and 8388607";
	}
	if($return["procspeed"] < 500 || $return["procspeed"] > 20000) {
	   $submitErr |= PROCSPEEDERR;
	   $submitErrMsg[PROCSPEEDERR] = "Processor Speed must be between 500 and 20000";
	}
	if(! preg_match('/^[a-zA-Z0-9_][-a-zA-Z0-9_.]{1,35}$/', $return["hostname"])) {
	   $submitErr |= HOSTNAMEERR;
	   $submitErrMsg[HOSTNAMEERR] = "Hostname must be <= 36 characters";
	}
	if(! ($submitErr & HOSTNAMEERR) && 
	   checkForHostname($return["hostname"], $return["compid"])) {
	   $submitErr |= HOSTNAMEERR;
	   $submitErrMsg[HOSTNAMEERR] = "There is already a computer with this hostname.";
	}
	if($mode != 'viewComputers' && ! validateUserid($return["owner"])) {
	   $submitErr |= OWNERERR;
	   $submitErrMsg[OWNERERR] = "Submitted ID is not valid";
	}
	if($return['type'] != 'blade' && $return['type'] != 'lab' && $return['type'] != 'virtualmachine')
		$return['type'] = 'blade';
	if($return['stateid'] != '' && ! array_key_exists($return['stateid'], $return['states']))
	   $submitErr |= 1 << 15;
	if($mode == 'confirmAddComputer' &&
	   $return['type'] == 'virtualmachine' && $return['stateid'] != 10) {
	   $submitErr |= VMAVAILERR;
	   $submitErrMsg[VMAVAILERR] = "Virtual machines can only be added in the maintenance state.";
	}
	if(! empty($return['vmprofileid']) && ! array_key_exists($return['vmprofileid'], $return['profiles'])) {
		$keys = array_keys($return['profiles']);
		$return['vmprofileid'] = array_shift($keys);
	}

	$provs = getContinuationVar('provisioning');
	if(is_array($provs) &&
	   array_key_exists($return['provisioningid'], $provs) &&
	   $provs[$return['provisioningid']]['name'] == 'none')
		$return['deploymode'] = 0;
	else
		$return['deploymode'] = 1;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processComputerInput2()
///
/// \return an array with the following keys:\n
/// platforms, schedules, showhostname, shownextimage, showipaddress, showram,
/// showstate, showprocnumber, showdepartment, showprocspeed, showplatform,
/// shownetwork, showschedule, showcomputerid, showcurrentimage, showtype,
/// showprovisioning
///
/// \brief processes platforms, schedules, and all of the flags for
/// what data to show
///
////////////////////////////////////////////////////////////////////////////////
function processComputerInput2() {
	$return = array();

	$return["platforms"] = getContinuationVar('platforms', processInputVar("platforms", ARG_MULTINUMERIC));
	$return["schedules"] = getContinuationVar('schedules', processInputVar("schedules", ARG_MULTINUMERIC));
	$return["groups"] = getContinuationVar('groups', processInputVar("groups", ARG_MULTINUMERIC));
	$return["showhostname"] = getContinuationVar('showhostname', processInputVar("showhostname", ARG_NUMERIC, 0));
	$return["shownextimage"] = getContinuationVar('shownextimage', processInputVar("shownextimage", ARG_NUMERIC, 0));
	$return["showipaddress"] = getContinuationVar('showipaddress', processInputVar("showipaddress", ARG_NUMERIC, 0));
	$return["showram"] = getContinuationVar('showram', processInputVar("showram", ARG_NUMERIC, 0));
	$return["showstate"] = getContinuationVar('showstate', processInputVar("showstate", ARG_NUMERIC, 0));
	$return["showprocnumber"] = getContinuationVar('showprocnumber', processInputVar("showprocnumber", ARG_NUMERIC, 0));
	$return["showdepartment"] = getContinuationVar('showdepartment', processInputVar("showdepartment", ARG_NUMERIC, 0));
	$return["showowner"] = getContinuationVar('showowner', processInputVar("showowner", ARG_NUMERIC, 0));
	$return["showprocspeed"] = getContinuationVar('showprocspeed', processInputVar("showprocspeed", ARG_NUMERIC, 0));
	$return["showplatform"] = getContinuationVar('showplatform', processInputVar("showplatform", ARG_NUMERIC, 0));
	$return["shownetwork"] = getContinuationVar('shownetwork', processInputVar("shownetwork", ARG_NUMERIC, 0));
	$return["showschedule"] = getContinuationVar('showschedule', processInputVar("showschedule", ARG_NUMERIC, 0));
	$return["showcomputerid"] = getContinuationVar('showcomputerid', processInputVar("showcomputerid", ARG_NUMERIC, 0));
	$return["showcurrentimage"] = getContinuationVar('showcurrentimage', processInputVar("showcurrentimage", ARG_NUMERIC, 0));
	$return["showtype"] = getContinuationVar('showtype', processInputVar("showtype", ARG_NUMERIC, 0));
	$return["showprovisioning"] = getContinuationVar('showprovisioning', processInputVar("showprovisioning", ARG_NUMERIC, 0));
	$return["shownotes"] = getContinuationVar('shownotes', processInputVar("shownotes", ARG_NUMERIC, 0));
	$return["showcounts"] = getContinuationVar('showcounts', processInputVar("showcounts", ARG_NUMERIC, 0));
	$return["showlocation"] = getContinuationVar('showlocation', processInputVar("showlocation", ARG_NUMERIC, 0));
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processComputerInput3()
///
/// \return an array with the following indexes:\n
/// notes, imageid, stateid, computerids
///
/// \brief processes input for computer utilities pages
///
////////////////////////////////////////////////////////////////////////////////
function processComputerInput3() {
	global $submitErr, $submitErrMsg;
	$compids = getContinuationVar("computerids", processInputVar('computerids', ARG_MULTINUMERIC));
	$return['notes'] = getContinuationVar("notes", processInputVar('notes', ARG_STRING));
	$return['imageid'] = getContinuationVar("imageid", processInputVar('imageid', ARG_NUMERIC));
	$return['stateid'] = getContinuationVar("stateid", processInputVar('stateid', ARG_NUMERIC));
	$return['scheduleid'] = getContinuationVar("scheduleid", processInputVar('scheduleid', ARG_NUMERIC));
	$resources = getUserResources(array("computerAdmin"), array("administer"));
	$userCompIDs = array_keys($resources["computer"]);
	$remove = array_diff($compids, $userCompIDs);
	$return['computerids'] = array_diff($compids, $remove);
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processBulkComputerInput($checks)
///
/// \param $checks - (optional) 1 to perform validation, 0 not to
///
/// \return an array with the following indexes:\n
/// startipaddress, endipaddress, starthostval, endhostval, stateid,
/// platformid, scheduleid, ram, numprocs, procspeed, network,
/// hostname, type, count (0 if any errors found)
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processBulkComputerInput($checks=1) {
	global $submitErr, $submitErrMsg;
	$return = processComputerInput2();
	$ipaddress = getContinuationVar("ipaddress", processInputVar("ipaddress", ARG_STRING, NULL, 1));
	if(! empty($ipaddress)) {
		$return["startipaddress"] = $ipaddress;
		$tmp = $ipaddress;
		$tmpArr = explode('.', $tmp);
		array_pop($tmpArr);
		$return["endipaddress"] = implode('.', $tmpArr);
		$return["starthostval"] = "";
		$return["endhostval"] = "";
	}
	else {
		$return["startipaddress"] = getContinuationVar("startipaddress", processInputVar("startipaddress", ARG_STRING, NULL, 1));
		$return["endipaddress"] = getContinuationVar("endipaddress", processInputVar("endipaddress", ARG_STRING, NULL, 1));
		$return["starthostval"] = getContinuationVar("starthostval", processInputVar("starthostval", ARG_NUMERIC, NULL, 1));
		$return["endhostval"] = getContinuationVar("endhostval", processInputVar("endhostval", ARG_NUMERIC, NULL, 1));
	}
	$return["startpripaddress"] = getContinuationVar("startpripaddress", processInputVar("startpripaddress", ARG_STRING, NULL, 1));
	$return["endpripaddress"] = getContinuationVar("endpripaddress", processInputVar("endpripaddress", ARG_STRING, NULL, 1));
	$return["startmac"] = getContinuationVar("startmac", processInputVar("startmac", ARG_STRING, NULL, 1));

	$return["stateid"] = getContinuationVar("stateid", processInputVar("stateid", ARG_NUMERIC));
	$return["owner"] = getContinuationVar("owner", processInputVar("owner", ARG_STRING, NULL, 1));
	$return["platformid"] = getContinuationVar("platformid", processInputVar("platformid", ARG_NUMERIC));
	$return["scheduleid"] = getContinuationVar("scheduleid", processInputVar("scheduleid", ARG_NUMERIC));
	$return["ram"] = getContinuationVar("ram", processInputVar("ram", ARG_NUMERIC, NULL, 1));
	$return["numprocs"] = getContinuationVar("numprocs", processInputVar("numprocs", ARG_NUMERIC, 1));
	$return["procspeed"] = getContinuationVar("procspeed", processInputVar("procspeed", ARG_NUMERIC, NULL, 1));
	$return["network"] = getContinuationVar("network", processInputVar("network", ARG_NUMERIC, 1000));
	$return["hostname"] = getContinuationVar("hostname", processInputVar("hostname", ARG_STRING, NULL, 1));
	$return["type"] = getContinuationVar("type", processInputVar("type", ARG_STRING, 'blade'));
	$return["provisioningid"] = getContinuationVar("provisioningid", processInputVar("provisioningid", ARG_NUMERIC));
	$return["location"] = getContinuationVar("location", processInputVar("location", ARG_STRING));
	$return["computergroup"] = getContinuationVar("computergroup", processInputVar("computergroup", ARG_MULTINUMERIC));
	$return['macs'] = getContinuationVar('macs', array());
	$return["vmprofileid"] = getContinuationVar("vmprofileid", processInputVar("vmprofileid", ARG_NUMERIC));
	$return["profiles"] = getContinuationVar("profiles", array());

	if(! $checks) {
		return $return;
	}

	$startaddrArr = explode('.', $return["startipaddress"]);
	if(! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $return["startipaddress"]) ||
		$startaddrArr[0] < 1 || $startaddrArr[0] > 255 ||
		$startaddrArr[1] < 0 || $startaddrArr[1] > 255 ||
		$startaddrArr[2] < 0 || $startaddrArr[2] > 255 ||
		$startaddrArr[3] < 1 || $startaddrArr[3] > 255) {
	   $submitErr |= IPADDRERR;
	   $submitErrMsg[IPADDRERR] = "Invalid IP address. Must be w.x.y.z with each of "
		                         . "w, x, y, and z being between 1 and 255 (inclusive)";
	}
	$endaddrArr = explode('.', $return["endipaddress"]);
	if(! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $return["endipaddress"]) ||
		$endaddrArr[0] < 1 || $endaddrArr[0] > 255 ||
		$endaddrArr[1] < 0 || $endaddrArr[1] > 255 ||
		$endaddrArr[2] < 0 || $endaddrArr[2] > 255 ||
		$endaddrArr[3] < 1 || $endaddrArr[3] > 255) {
	   $submitErr |= IPADDRERR2;
	   $submitErrMsg[IPADDRERR2] = "Invalid IP address. Must be w.x.y.z with each of "
		                          . "w, x, y, and z being between 1 and 255 (inclusive)";
	}
	$endpraddrArr = array();
	if(! empty($return['startpripaddress']) ||
		! empty($return['endpripaddress'])) {
		$startpraddrArr = explode('.', $return["startpripaddress"]);
		if(! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $return["startpripaddress"]) ||
			$startpraddrArr[0] < 1 || $startpraddrArr[0] > 255 ||
			$startpraddrArr[1] < 0 || $startpraddrArr[1] > 255 ||
			$startpraddrArr[2] < 0 || $startpraddrArr[2] > 255 ||
			$startpraddrArr[3] < 1 || $startpraddrArr[3] > 255) {
			$submitErr |= IPADDRERR3;
			$submitErrMsg[IPADDRERR3] = "Invalid IP address. Must be w.x.y.z with each of "
			                          . "w, x, y, and z being between 1 and 255 (inclusive)";
		}
		$endpraddrArr = explode('.', $return["endpripaddress"]);
		if(! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $return["endpripaddress"]) ||
			$endpraddrArr[0] < 1 || $endpraddrArr[0] > 255 ||
			$endpraddrArr[1] < 0 || $endpraddrArr[1] > 255 ||
			$endpraddrArr[2] < 0 || $endpraddrArr[2] > 255 ||
			$endpraddrArr[3] < 1 || $endpraddrArr[3] > 255) {
			$submitErr |= IPADDRERR4;
			$submitErrMsg[IPADDRERR4] = "Invalid IP address. Must be w.x.y.z with each of "
			                          . "w, x, y, and z being between 1 and 255 (inclusive)";
		}
	}
	if(! empty($return['startmac'])) {
		if(! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $return["startmac"])) {
			$submitErr |= MACADDRERR;
			$submitErrMsg[MACADDRERR] = "Invalid MAC address.  Must be XX:XX:XX:XX:XX:XX "
			                          . "with each pair of XX being from 00 to FF (inclusive)";
		}
		elseif(! $submitErr) {
			$tmp = explode(':', $return['startmac']);
			$topdec = hexdec($tmp[0] . $tmp[1] . $tmp[2]);
			$botdec = hexdec($tmp[3] . $tmp[4] . $tmp[5]);
			$topmac = "{$tmp[0]}:{$tmp[1]}:{$tmp[2]}";
			$topplus = implode(':', str_split(dechex($topdec + 1), 2));
			$start = $botdec;
			$return['macs'] = array();
			$eth0macs = array();
			$eth1macs = array();
			$toggle = 0;
			$end = $start + (($endaddrArr[3] - $startaddrArr[3] + 1) * 2);
			for($i = $start; $i < $end; $i++) {
				if($i > 16777215) {
					$val = $i - 16777216;
					$tmp = sprintf('%06x', $val);
					$tmp2 = str_split($tmp, 2);
					$return['macs'][] = $topplus . ':' . implode(':', $tmp2);
				}
				else {
					$tmp = sprintf('%06x', $i);
					$tmp2 = str_split($tmp, 2);
					$return['macs'][] = $topmac . ':' . implode(':', $tmp2);
				}
				if($toggle % 2)
					$eth1macs[] = $topmac . ':' . implode(':', $tmp2);
				else
					$eth0macs[] = $topmac . ':' . implode(':', $tmp2);
				$toggle++;
			}
			$ineth0s = implode("','", $eth0macs);
			$ineth1s = implode("','", $eth1macs);
			$query = "SELECT id "
			       . "FROM computer "
			       . "WHERE eth0macaddress IN ('$ineth0s') OR "
			       .       "eth1macaddress IN ('$ineth1s')";
			$qh = doQuery($query);
			if(mysql_num_rows($qh)) {
				$submitErr |= MACADDRERR;
				$submitErrMsg[MACADDRERR] = "The specified starting MAC address "
				                          . "combined with the number of computers "
				                          . "entered will result in a MAC address "
				                          . "already assigned to another computer.";
			}
			elseif($i > 16777215 && $topdec == 16777215) {
				$submitErr |= MACADDRERR;
				$submitErrMsg[MACADDRERR] = "Starting MAC address too large for given "
				                          . "given number of machines";
			}
		}
	}
	if($return["ram"] < 32 || $return["ram"] > 512000) {
	   $submitErr |= RAMERR;
	   $submitErrMsg[RAMERR] = "RAM must be between 32 and 512000";
	}
	if($return["procspeed"] < 500 || $return["procspeed"] > 20000) {
	   $submitErr |= PROCSPEEDERR;
	   $submitErrMsg[PROCSPEEDERR] = "Processor Speed must be between 500 and 20000";
	}
	if(! preg_match('/^[a-zA-Z0-9_%][-a-zA-Z0-9_.%]{1,35}$/', $return["hostname"])) {
	   $submitErr |= HOSTNAMEERR;
	   $submitErrMsg[HOSTNAMEERR] = "Hostname must be <= 36 characters";
	}

	if(! ($submitErr & HOSTNAMEERR)) {
		$checkhosts = array();
		for($i = $return["starthostval"]; $i <= $return["endhostval"]; $i++) {
			$checkhosts[] = str_replace('%', $i, $return["hostname"]);
		}
		$allhosts = implode("','", $checkhosts);
		$query = "SELECT hostname FROM computer "
		       . "WHERE hostname IN ('$allhosts') AND "
		       .       "deleted = 0";
		$qh = doQuery($query);
		$exists = array();
		while($row = mysql_fetch_assoc($qh))
			$exists[] = $row['hostname'];
		if(count($exists)) {
			$hosts = implode(', ', $exists);
			$submitErr |= HOSTNAMEERR;
			$submitErrMsg[HOSTNAMEERR] = "There are already computers with these hostnames: $hosts";
		}
	}


	if(empty($return["starthostval"]) && $return["starthostval"] != 0) {
	   $submitErr |= STARTHOSTVALERR;
	   $submitErrMsg[STARTHOSTVALERR] = "Start value can only be numeric.";
	}
	if(empty($return["endhostval"]) && $return["endhostval"] != 0) {
	   $submitErr |= ENDHOSTVALERR;
	   $submitErrMsg[ENDHOSTVALERR] = "End value can only be numeric.";
	}
	if(! ($submitErr & IPADDRERR2 || $submitErr & ENDHOSTVALERR) && 
		($endaddrArr[3] - $startaddrArr[3] != $return["endhostval"] - $return["starthostval"])) {
		$numipaddrs = $endaddrArr[3] - $startaddrArr[3] + 1;
		$numhostnames = $return["endhostval"] - $return["starthostval"] + 1;
	   $submitErr |= IPADDRERR2;
	   $submitErrMsg[IPADDRERR2] = "The number of IP addresses ($numipaddrs) "
		      . "does not match the number of hostnames ($numhostnames).";
	   $submitErr |= ENDHOSTVALERR;
	   $submitErrMsg[ENDHOSTVALERR] = $submitErrMsg[IPADDRERR2];
	}
	if(! empty($return['startpripaddress']) && ! empty($return['endpripaddress']) &&
	   (! ($submitErr & IPADDRERR4) && 
	   ! empty($endpraddrArr) &&
		($return["endhostval"] - $return["starthostval"] != $endpraddrArr[3] - $startpraddrArr[3]))) {
		$numpraddrs = $endpraddrArr[3] - $startpraddrArr[3] + 1;
		$numhostnames = $return["endhostval"] - $return["starthostval"] + 1;

	   $submitErr |= IPADDRERR4;
	   $submitErrMsg[IPADDRERR4] = "The number of private IP addresses ($numpraddrs) "
		      . "does not match the number of hostnames ($numhostnames).";
		if(! ($submitErr & ENDHOSTVALERR)) {
			$submitErr |= ENDHOSTVALERR;
			$submitErrMsg[ENDHOSTVALERR] = $submitErrMsg[IPADDRERR4];
		}
	}
	if(! empty($return['vmprofileid']) && ! array_key_exists($return['vmprofileid'], $return['profiles'])) {
		$keys = array_keys($return['profiles']);
		$return['vmprofileid'] = array_shift($keys);
	}
	if(! validateUserid($return["owner"])) {
	   $submitErr |= OWNERERR;
	   $submitErrMsg[OWNERERR] = "Submitted ID is not valid";
	}
	$return['count'] = 0;
	if(! $submitErr)
		$return['count'] = $endaddrArr[3] - $startaddrArr[3] + 1;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForHostname($hostname, $compid)
///
/// \param $hostname - a computer hostname
/// \param $compid - a computer id to ignore
///
/// \return 1 if $hostname is already in the computer table, 0 if not
///
/// \brief checks for $hostname being somewhere in the computer table except
/// for $compid
///
////////////////////////////////////////////////////////////////////////////////
function checkForHostname($hostname, $compid) {
	$query = "SELECT id FROM computer "
	       . "WHERE hostname = '$hostname' AND "
	       .       "deleted = 0";
	if(! empty($compid))
		$query .= " AND id != $compid";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForMACaddress($mac, $num, $compid)
///
/// \param $mac - computer mac address
/// \param $num - which mac address to check - 0 or 1
/// \param $compid - a computer id to ignore
///
/// \return 1 if $mac/$num is already in the computer table, 0 if not
///
/// \brief checks for $mac being somewhere in the computer table except
/// for $compid
///
////////////////////////////////////////////////////////////////////////////////
function checkForMACaddress($mac, $num, $compid) {
	if($num == 0)
		$field = 'eth0macaddress';
	else
		$field = 'eth1macaddress';
	$query = "SELECT id FROM computer "
	       . "WHERE $field = '$mac' AND "
	       .       "deleted = 0";
	if(! empty($compid))
		$query .= " AND id != $compid";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForIPaddress($ipaddress, $compid)
///
/// \param $ipaddress - a computer ip address
/// \param $compid - a computer id to ignore
///
/// \return 1 if $ipaddress is already in the computer table, 0 if not
///
/// \brief checks for $ipaddress being somewhere in the computer table except
/// for $compid
///
////////////////////////////////////////////////////////////////////////////////
function checkForIPaddress($ipaddress, $compid) {
	$query = "SELECT id FROM computer "
	       . "WHERE IPaddress = '$ipaddress'";
	if(! empty($compid))
		$query .= " AND id != $compid";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getCompIdList($groups)
///
/// \param $groups - an array of computer group ids
///
/// \return an array where each key is a computer id and each value is 1
///
/// \brief builds a list of computer ids that are either in $groups or are not
/// in any groups but owned by the logged in user
///
////////////////////////////////////////////////////////////////////////////////
function getCompIdList($groups) {
	global $user;
	$inlist = implode(',', $groups);
	$query = "SELECT DISTINCT r.subid as compid "
	       . "FROM resource r, "
	       .      "resourcegroupmembers rgm "
	       . "WHERE r.id = rgm.resourceid AND "
	       .       "rgm.resourcegroupid IN ($inlist)";
	$qh = doQuery($query, 101);
	$compidlist = array();
	while($row = mysql_fetch_assoc($qh))
		$compidlist[$row['compid']] = 1;
	$query = "SELECT id "
	       . "FROM computer "
	       . "WHERE ownerid = {$user['id']} AND "
	       .       "id NOT IN (SELECT r.subid "
	       .                  "FROM resource r, "
	       .                        "resourcegroupmembers rgm "
	       .                  "WHERE r.id = rgm.resourceid AND "
	       .                        "r.resourcetypeid = 12)";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$compidlist[$row['id']] = 1;
	return $compidlist;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateComputer($data)
///
/// \param $data - an array with the following indexes:\n
/// ipaddress, stateid, platformid, scheduleid,
/// ram, numprocs, procspeed, network, hostname, compid, type
///
/// \return number of rows affected by the update\n
/// \b NOTE: mysql reports that no rows were affected if none of the fields
/// were actually changed even if the update matched a row
///
/// \brief performs a query to update the computer with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function updateComputer($data) {
	$ownerid = getUserlistID($data['owner']);
	if($data['eth0macaddress'] == '')
		$eth0 = 'NULL';
	else
		$eth0 = "'{$data['eth0macaddress']}'";
	if($data['eth1macaddress'] == '')
		$eth1 = 'NULL';
	else
		$eth1 = "'{$data['eth1macaddress']}'";
	if($data['pripaddress'] == '')
		$privateip = 'NULL';
	else
		$privateip = "'{$data['pripaddress']}'";
	if($data['location'] == '')
		$location = 'NULL';
	else {
		$location = $data['location'];
		if(get_magic_quotes_gpc())
			$location = stripslashes($location);
		$location = mysql_real_escape_string($location);
		$location = "'$location'";
	}
	$query = "UPDATE computer "
	       . "SET ownerid = $ownerid, ";
	if(array_key_exists('stateid', $data))
		$query .= "stateid = {$data['stateid']}, ";
	$query .=    "platformid = {$data['platformid']}, "
	       .     "scheduleid = {$data['scheduleid']}, "
	       .     "RAM = {$data['ram']}, "
	       .     "procnumber = {$data['numprocs']}, "
	       .     "procspeed = {$data['procspeed']}, "
	       .     "network = {$data['network']}, "
	       .     "hostname = '{$data['hostname']}', "
	       .     "IPaddress = '{$data['ipaddress']}', "
	       .     "privateIPaddress = $privateip, "
	       .     "eth0macaddress = $eth0, "
	       .     "eth1macaddress = $eth1, "
	       .     "type = '{$data['type']}', "
	       .     "provisioningid = {$data['provisioningid']}, "
	       .     "notes = '{$data['notes']}', "
	       .     "location = $location "
	       . "WHERE id = {$data['compid']}";
	$qh = doQuery($query, 185);
	return mysql_affected_rows($GLOBALS['mysql_link_vcl']);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addComputer($data)
///
/// \param $data - an array with the following indexes:\n
/// ipaddress, stateid, platformid, scheduleid,
/// ram, numprocs, procspeed, network, hostname, type
///
/// \brief adds a computer to the computer table
///
////////////////////////////////////////////////////////////////////////////////
function addComputer($data) {
	global $user;
	$ownerid = getUserlistID($data['owner']);
	if($data['stateid'] == 10) {
		$now = unixToDatetime(time());
		$notes = "'{$user['unityid']} $now@in maintenance state when added to database'";
	}
	else
		$notes = 'NULL';
	if($data['eth0macaddress'] == '')
		$eth0 = 'NULL';
	else
		$eth0 = "'{$data['eth0macaddress']}'";
	if($data['eth1macaddress'] == '')
		$eth1 = 'NULL';
	else
		$eth1 = "'{$data['eth1macaddress']}'";
	if($data['pripaddress'] == '')
		$privateip = 'NULL';
	else
		$privateip = "'{$data['pripaddress']}'";
	if($data['location'] == '')
		$location = 'NULL';
	else {
		$location = $data['location'];
		if(get_magic_quotes_gpc())
			$location = stripslashes($location);
		$location = mysql_real_escape_string($location);
		$location = "'$location'";
	}
	$noimageid = getImageId('noimage');
	$noimagerevisionid = getProductionRevisionid($noimageid);
	$query = "INSERT INTO computer "
	       .        "(stateid, "
	       .        "ownerid, "
	       .        "platformid, "
	       .        "scheduleid, "
	       .        "currentimageid, "
	       .        "imagerevisionid, "
	       .        "RAM, "
	       .        "procnumber, "
	       .        "procspeed, "
	       .        "network, "
	       .        "hostname, "
	       .        "IPaddress, "
	       .        "privateIPaddress, "
	       .        "eth0macaddress, "
	       .        "eth1macaddress, "
	       .        "type, "
	       .        "notes, "
	       .        "provisioningid, "
	       .        "location) "
	       . "VALUES ({$data['stateid']}, "
	       .         "$ownerid, "
	       .         "{$data['platformid']}, "
	       .         "{$data['scheduleid']}, "
	       .         "$noimageid, "
	       .         "$noimagerevisionid, "
	       .         "{$data['ram']}, "
	       .         "{$data['numprocs']}, "
	       .         "{$data['procspeed']}, "
	       .         "{$data['network']}, "
	       .         "'{$data['hostname']}', "
	       .         "'{$data['ipaddress']}', "
	       .         "$privateip, "
	       .         "$eth0, "
	       .         "$eth1, "
	       .         "'{$data['type']}', "
	       .         "$notes, "
	       .         "'{$data['provisioningid']}', "
	       .         "$location)";
	doQuery($query, 195);
	$compid = dbLastInsertID();

	$query = "INSERT INTO resource "
			 .        "(resourcetypeid, "
			 .        "subid) "
			 . "VALUES (12, "
			 .         "$compid)";
	doQuery($query, 198);
	$resid = dbLastInsertID();

	// add computer into selected groups
	if(! empty($data['computergroup'])) {
		$vals = array();
		foreach(array_keys($data['computergroup']) as $groupid)
			$vals[] = "($resid, $groupid)";
		$allvals = implode(',', $vals);
		$query = "INSERT INTO resourcegroupmembers "
		       .        "(resourceid, "
		       .        "resourcegroupid) "
		       . "VALUES $allvals";
		doQuery($query, 101);
	}

	if($data['stateid'] == 20) {
		# create vmhost entry
		$query = "INSERT INTO vmhost "
		       .        "(computerid, "
		       .        "vmlimit, "
		       .        "vmprofileid) "
		       . "VALUES ($compid, "
		       .        "2, "
		       .        "{$data['vmprofileid']})";
		doQuery($query, 101);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printComputerInfo($pripaddress, $ipaddress, $eth0macaddress,
///                       $eth1macaddress, $stateid, $owner, $platformid,
///                       $scheduleid, $currentimgid, $ram, $numprocs,
///                       $procspeed, $network,  $hostname, $compid, $type,
///                       $provisioningid, $location, $vmprofileid='',
///                       $deploymode='')
///
/// \param $pripaddress - private IP address of computer
/// \param $ipaddress - public IP address of computer
/// \param $eth0macaddress - private MAC address
/// \param $eth1macaddress - public MAC address
/// \param $stateid - stateid of computer
/// \param $owner - owner of computer
/// \param $platformid - platformid of computer
/// \param $scheduleid - scheduleid of computer
/// \param $currentimgid - current imageid of computer
/// \param $ram - ram in MB of computer
/// \param $numprocs - number of processors in computer
/// \param $procspeed - processor speed of computer
/// \param $network - network speed of computer's NIC in MBbps
/// \param $hostname - hostname of computer
/// \param $compid - id of computer from computer table
/// \param $type - type of computer (blade or lab)
/// \param $provisioningid - id of provisioning engine
/// \param $location - location of computer
/// \param $vmprofileid - (optional) id of vmprofile if node is in vmhostinuse
/// state
/// \param $deploymode - (optional) 0 to print that node will be manually
/// installed with hypervisor, 1 to print that it will be automatically
/// installed
///
/// \brief prints a table of information about the computer
///
////////////////////////////////////////////////////////////////////////////////
function printComputerInfo($pripaddress, $ipaddress, $eth0macaddress,
                           $eth1macaddress, $stateid, $owner, $platformid,
                           $scheduleid, $currentimgid, $ram, $numprocs,
                           $procspeed, $network, $hostname, $compid, $type,
                           $provisioningid, $location, $vmprofileid='',
                           $deploymode='') {

	$states = getStates();
	$platforms = getPlatforms();
	$schedules = getSchedules();
	$images = getImages();
	$provisioning = getProvisioning();
	if(! empty($vmprofileid))
		$profiles = getVMProfiles();

	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname:</TH>\n";
	print "    <TD>$hostname</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Type:</TH>\n";
	print "    <TD>$type</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Public IP Address:</TH>\n";
	print "    <TD>$ipaddress</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Private IP Address:</TH>\n";
	print "    <TD>$pripaddress</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Public MAC Address:</TH>\n";
	print "    <TD>$eth1macaddress</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Private MAC Address:</TH>\n";
	print "    <TD>$eth0macaddress</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Provisioning Engine:</TH>\n";
	print "    <TD>" . $provisioning[$provisioningid]['prettyname'] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>State:</TH>\n";
	print "    <TD>" . $states[$stateid] . "</TD>\n";
	print "  </TR>\n";
	if(! empty($vmprofileid)) {
		print "  <TR>\n";
		print "    <TH align=right>VM Host Profile:</TH>\n";
		print "    <TD>{$profiles[$vmprofileid]['profilename']}</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>$owner</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Platform:</TH>\n";
	print "    <TD>" . $platforms[$platformid] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Schedule:</TH>\n";
	print "    <TD>" . $schedules[$scheduleid]["name"] . "</TD>\n";
	print "  </TR>\n";
	if(! empty($currentimgid)) {
		print "  <TR>\n";
		print "    <TH align=right nowrap>Current Image:</TH>\n";
		print "    <TD>" . $images[$currentimgid]["prettyname"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>RAM (MB):</TH>\n";
	print "    <TD>$ram</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>No. Cores:</TH>\n";
	print "    <TD>$numprocs</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Processor Speed (MHz):</TH>\n";
	print "    <TD>$procspeed</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Network Speed (Mbps):</TH>\n";
	print "    <TD>$network</TD>\n";
	print "  </TR>\n";
	if(! empty($compid)) {
		print "  <TR>\n";
		print "    <TH align=right nowrap>Computer ID:</TH>\n";
		print "    <TD>$compid</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Location:</TH>\n";
	print "    <TD>$location</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getComputerSelection($data)
///
/// \param $data - array of data as returned from processComputerInput
///
/// \return an array of data to be passed to addContinuationsEntry
///
/// \brief returns only the selection data from $data
///
////////////////////////////////////////////////////////////////////////////////
function getComputerSelection($data) {
	$ret = array();
	$ret['platforms'] = $data['platforms'];
	$ret['schedules'] = $data['schedules'];
	$ret['groups'] = $data['groups'];
	$keys = array("showhostname", "shownextimage", "showipaddress",
	              "showram", "showstate", "showprocnumber", "showdepartment",
	              "showowner", "showprocspeed", "showplatform", "shownetwork",
	              "showschedule", "showcomputerid", "showcurrentimage",
	              "showtype", "showdeleted", "shownotes", "showcounts",
	              "showprovisioning", "showlocation");
	foreach($keys as $key)
		$ret[$key] = $data[$key];
	return $ret;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonCompGroupingComps()
///
/// \brief accepts a groupid via form input and prints a json array with 3
/// arrays: an array of computers that are in the group, an array of computers
/// not in it, and an array of all computers user has access to
///
////////////////////////////////////////////////////////////////////////////////
function jsonCompGroupingComps() {
	$groupid = processInputVar('groupid', ARG_NUMERIC);
	$groups = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($groupid, $groups['computer'])) {
		$arr = array('incomps' => array(), 'outcomps' => array(), 'all' => array());
		sendJSON($arr);
		return;
	}

	$resources = getUserResources(array('computerAdmin'), array('manageGroup'));
	uasort($resources['computer'], 'sortKeepIndex');
	$memberships = getResourceGroupMemberships('computer');
	$all = array();
	$in = array();
	$out = array();
	foreach($resources['computer'] as $id => $comp) {
		if(array_key_exists($id, $memberships['computer']) && 
			in_array($groupid, $memberships['computer'][$id])) {
			$all[] = array('inout' => 1, 'id' => $id, 'name' => $comp);
			$in[] = array('name' => $comp, 'id' => $id);
		}
		else {
			$all[] = array('inout' => 0, 'id' => $id, 'name' => $comp);
			$out[] = array('name' => $comp, 'id' => $id);
		}
	}
	$arr = array('incomps' => $in, 'outcomps' => $out, 'all' => $all);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonCompGroupingGroups()
///
/// \brief accepts a computer id via form input and prints a json array with 3
/// arrays: an array of groups that the computer is in, an array of groups it
/// is not in and an array of all groups user has access to
///
////////////////////////////////////////////////////////////////////////////////
function jsonCompGroupingGroups() {
	$compid = processInputVar('compid', ARG_NUMERIC);
	$resources = getUserResources(array("computerAdmin"), array("manageGroup"));
	if(! array_key_exists($compid, $resources['computer'])) {
		$arr = array('ingroups' => array(), 'outgroups' => array(), 'all' => array());
		sendJSON($arr);
		return;
	}
	$groups = getUserResources(array('computerAdmin'), array('manageGroup'), 1);
	$memberships = getResourceGroupMemberships('computer');
	$in = array();
	$out = array();
	$all = array();
	foreach($groups['computer'] as $id => $group) {
		if(array_key_exists($compid, $memberships['computer']) && 
			in_array($id, $memberships['computer'][$compid])) {
			$all[] = array('inout' => 1, 'id' => $id, 'name' => $group);
			$in[] = array('name' => $group, 'id' => $id);
		}
		else {
			$all[] = array('inout' => 0, 'id' => $id, 'name' => $group);
			$out[] = array('name' => $group, 'id' => $id);
		}
	}
	$arr = array('ingroups' => $in, 'outgroups' => $out, 'all' => $all);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJaddCompToGroup()
///
/// \brief accepts a groupid and a comma delimited list of computer ids to be
/// added to the group; adds them and returns an array of computer ids that were
/// added
///
////////////////////////////////////////////////////////////////////////////////
function AJaddCompToGroup() {
	$groupid = processInputVar('id', ARG_NUMERIC);
	$groups = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($groupid, $groups['computer'])) {
		$arr = array('comps' => array(), 'addrem' => 1);
		sendJSON($arr);
		return;
	}

	$resources = getUserResources(array("computerAdmin"), array("manageGroup"));
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$compids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $resources['computer'])) {
			$arr = array('comps' => array(), 'addrem' => 1);
			sendJSON($arr);
			return;
		}
		$compids[] = $id;
	}

	$allcomps = getComputers();
	$adds = array();
	foreach($compids as $id) {
		$adds[] = "({$allcomps[$id]['resourceid']}, $groupid)";
	}
	$query = "INSERT IGNORE INTO resourcegroupmembers "
			 . "(resourceid, resourcegroupid) VALUES ";
	$query .= implode(',', $adds);
	doQuery($query, 287);
	$_SESSION['userresources'] = array();
	$arr = array('comps' => $compids, 'addrem' => 1);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJremCompFromGroup()
///
/// \brief accepts a groupid and a comma delimited list of computer ids to be
/// removed from the group; removes them and returns an array of computer ids 
/// that were removed
///
////////////////////////////////////////////////////////////////////////////////
function AJremCompFromGroup() {
	$groupid = processInputVar('id', ARG_NUMERIC);
	$groups = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($groupid, $groups['computer'])) {
		$arr = array('comps' => array(), 'addrem' => 0);
		sendJSON($arr);
		return;
	}

	$resources = getUserResources(array("computerAdmin"), array("manageGroup"));
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$compids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $resources['computer'])) {
			$arr = array('comps' => array(), 'addrem' => 0, 'id' => $id, 'extra' => $resources['computer']);
			sendJSON($arr);
			return;
		}
		$compids[] = $id;
	}

	$allcomps = getComputers();
	foreach($compids as $id) {
		$query = "DELETE FROM resourcegroupmembers "
				 . "WHERE resourceid = {$allcomps[$id]['resourceid']} AND "
				 .       "resourcegroupid = $groupid";
		doQuery($query, 288);
	}
	$_SESSION['userresources'] = array();
	$arr = array('comps' => $compids, 'addrem' => 0);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJaddGroupToComp()
///
/// \brief accepts a computer id and a comma delimited list of group ids that
/// the computer should be added to; adds it to them and returns an array of
/// groups it was added to
///
////////////////////////////////////////////////////////////////////////////////
function AJaddGroupToComp() {
	$compid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("computerAdmin"), array("manageGroup"));
	if(! array_key_exists($compid, $resources['computer'])) {
		$arr = array('groups' => array(), 'addrem' => 1);
		sendJSON($arr);
		return;
	}

	$groups = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$groupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $groups['computer'])) {
			$arr = array('groups' => array(), 'addrem' => 1);
			sendJSON($arr);
			return;
		}
		$groupids[] = $id;
	}

	$comp = getComputers(0, $compid);
	$adds = array();
	foreach($groupids as $id) {
		$adds[] = "({$comp[$compid]['resourceid']}, $id)";
	}
	$query = "INSERT IGNORE INTO resourcegroupmembers "
			 . "(resourceid, resourcegroupid) VALUES ";
	$query .= implode(',', $adds);
	doQuery($query, 101);
	$_SESSION['userresources'] = array();
	$arr = array('groups' => $groupids, 'addrem' => 1);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJremGroupFromComp()
///
/// \brief accepts a computer id and a comma delimited list of group ids that
/// the computer should be removed from; removes it from them and returns an 
/// array of groups it was removed from
///
////////////////////////////////////////////////////////////////////////////////
function AJremGroupFromComp() {
	$compid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("computerAdmin"), array("manageGroup"));
	if(! array_key_exists($compid, $resources['computer'])) {
		$arr = array('groups' => array(), 'addrem' => 0);
		sendJSON($arr);
		return;
	}

	$groups = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$groupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $groups['computer'])) {
			$arr = array('groups' => array(), 'addrem' => 0);
			sendJSON($arr);
			return;
		}
		$groupids[] = $id;
	}

	$comp = getComputers(0, $compid);
	foreach($groupids as $id) {
		$query = "DELETE FROM resourcegroupmembers "
				 . "WHERE resourceid = {$comp[$compid]['resourceid']} AND "
				 .       "resourcegroupid = $id";
		doQuery($query, 288);
	}
	$_SESSION['userresources'] = array();
	$arr = array('groups' => $groupids, 'addrem' => 0);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJgenerateUtilData()
///
/// \brief generates /etc/hosts or dhcpd.conf and dhcpd.leases for submitted
/// computer
///
////////////////////////////////////////////////////////////////////////////////
function AJgenerateUtilData() {
	$mnip = processInputVar('mnip', ARG_STRING);
	if(empty($mnip))
		$method = 'hosts';
	else {
		$method = 'dhcpd';
		$octets = explode('.', $mnip);
		if(! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $mnip) ||
		   $octets[0] < 1 || $octets[0] > 255 ||
		   $octets[1] < 0 || $octets[1] > 255 ||
		   $octets[2] < 0 || $octets[2] > 255 ||
		   $octets[3] < 0 || $octets[3] > 255) {
			sendJSON(array('status' => 'error', 'errmsg' => 'invalid IP address submitted'));
			return;
		}
		$hexmnip = sprintf('%02x:%02x:%02x:%02x', $octets[0], $octets[1], $octets[2], $octets[3]);
	}
	$dispcompids = getContinuationVar('dispcompids');
	$compids = processInputVar('compids', ARG_STRING);
	if(! preg_match('/[0-9,]*/', $compids)) {
		sendJSON(array('status' => 'error', 'errmsg' => 'invalid data submitted'));
		return;
	}
	$compids = explode(',', $compids);
	$others = array_diff($compids, $dispcompids);
	if(! empty($others)) {
		$arr = array('status' => 'error',
		             'errmsg' => 'invalid computer id submitted');
		sendJSON($arr);
		return;
	}
	$comps = getComputers(1);
	$noips = array();
	$hosts = '';
	$dhcpd = '';
	$leases = '';
	foreach($compids as $id) {
		if($method == 'hosts') {
			if(! empty($comps[$id]['privateIPaddress']))
				$hosts .= "{$comps[$id]['privateIPaddress']}\t{$comps[$id]['hostname']}\n";
			else
				$noips[] = $comps[$id]['hostname'];
		}
		else {
			if(! empty($comps[$id]['privateIPaddress']) &&
			   ! empty($comps[$id]['eth0macaddress'])) {
				$tmp = explode('.', $comps[$id]['hostname']);
				$dhcpd .= "\t\thost {$tmp[0]} {\n";
				$dhcpd .= "\t\t\toption host-name \"{$tmp[0]}\";\n";
				$dhcpd .= "\t\t\thardware ethernet {$comps[$id]['eth0macaddress']};\n";
				$dhcpd .= "\t\t\tfixed-address {$comps[$id]['privateIPaddress']};\n";
				$dhcpd .= "\t\t\tfilename \"/tftpboot/pxelinux.0\";\n";
				$dhcpd .= "\t\t\toption dhcp-server-identifier $mnip;\n";
				$dhcpd .= "\t\t\tnext-server $mnip;\n";
				$dhcpd .= "\t\t}\n\n";

				$leases .= "host {$tmp[0]} {\n";
				$leases .= "\tdynamic;\n";
				$leases .= "\thardware ethernet {$comps[$id]['eth0macaddress']};\n";
				$leases .= "\tfixed-address {$comps[$id]['privateIPaddress']};\n";
				$leases .= "\tsupersede server.ddns-hostname = \"{$tmp[0]}\";\n";
				$leases .= "\tsupersede host-name = \"{$tmp[0]}\";\n";
				$leases .= "\tif option vendor-class-identifier = \"ScaleMP\" {\n";
				$leases .= "\t\tsupersede server.filename = \"vsmp/pxelinux.0\";\n";
				$leases .= "\t} else {\n";
				$leases .= "\t\tsupersede server.filename = \"pxelinux.0\";\n";
				$leases .= "\t}\n";
				$leases .= "\tsupersede server.next-server = $hexmnip;\n";
				$leases .= "}\n";
			}
			else
				$noips[] = $comps[$id]['hostname'];
		}
	}
	$h = '';
	if(! empty($noips)) {
		if($method == 'hosts')
			$h .= "The following computers did not have private IP address entries:<br>";
		else
			$h .= "The following computers did not have private IP address or private MAC entries:<br>";
		$h .= "<pre>";
		$h .= implode("\n", $noips);
		$h .= "</pre>";
	}
	if(! empty($hosts) && $method == 'hosts') {
		$h .= "Data to be added to /etc/hosts:<br>";
		$h .= "<pre>$hosts</pre>";
	}
	elseif(! empty($dhcpd) && $method == 'dhcpd') {
		$h .= "Data to be added to dhcpd.conf:<br>";
		$h .= "<pre>$dhcpd</pre>";
		$h .= "Data to be added to dhcpd.leases:<br>";
		$h .= "<pre>$leases</pre>";
	}
	$arr = array('status' => 'success',
	             'html' => $h);
	sendJSON($arr);
}

?>
