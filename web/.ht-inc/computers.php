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
/// signifies an error with the submitted start mac address
define("MACADDRERR", 1 << 10);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectComputers()
///
/// \brief prints a form to select which computers to view
///
////////////////////////////////////////////////////////////////////////////////
function selectComputers() {
	global $viewmode, $user;
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
		# by platform/schedule
		print "<div id=\"platsch\" dojoType=\"dijit.layout.ContentPane\" title=\"Platforms/Schedules\">\n";
		print "<TABLE id=layouttable summary=\"\">\n";
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
		# by groups
		$size = count($computergroups);
		if($size > 13)
			$size = 13;
		print "<div id=\"groups\" dojoType=\"dijit.layout.ContentPane\" ";
		print "title=\"Computer Groups\" align=center selected=\"true\">\n";
		printSelectInput("groups[]", $computergroups, -1, 0, 1, '', "size=$size");
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
		print "value=1><label for=showprocnumber>No. Processors</label></TD>\n";
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
		print "    <TD></TD>\n";
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
	                "10" => "maintenance");
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
		print "<font color=\"#008000\">computer successfully updated</font>\n";
	}
	elseif($mode == "submitDeleteComputer") {
		print "<H2>Delete Computer</H2>\n";
		$deleted = getContinuationVar("deleted");
		if($deleted) {
			print "<font color=\"#008000\">computer successfully restored to the normal ";
			print "state</font>\n";
		}
		else {
			print "<font color=\"#008000\">computer successfully set to the deleted ";
			print "state</font>\n";
		}
	}
	elseif($mode == "submitAddComputer") {
		print "<H2>Add Computer</H2>\n";
		print "<font color=\"#008000\">computer successfully added</font>\n";
	}
	if(! count($schedules)) {
		print "You don't have access to manage any schedules.  You must be able ";
		print "to manage at least one schedule before you can manage computers.";
		print "<br>\n";
		return;
	}
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
		print "    <TH>No. Processors</TH>\n";
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
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "    <TD align=center>Add&nbsp;Multiple?";
	print "<INPUT type=checkbox name=bulk value=1></TD>\n";
	print "    <TD>\n";
	print "      <INPUT type=submit value=Add>\n";
	print "    </TD>\n";
	if($data["showhostname"] || $showall)
		print "    <TD><INPUT type=text name=hostname maxlength=36></TD>\n";
	if($data["showipaddress"] || $showall) {
		print "    <TD><INPUT type=text name=ipaddress size=14 maxlength=14>";
		print "</TD>\n";
	}
	if($data["showstate"] || $showall) {
		print "    <TD>\n";
		printSelectInput("stateid", $states, 2);
		print "    </TD>\n";
	}
	if($data["showowner"] || $showall) {
		print "    <TD><INPUT type=text name=owner size=15 value=\"";
		print "{$user["unityid"]}@{$user['affiliation']}\"></TD>\n";
	}
	if($data["showplatform"] || $showall) {
		print "    <TD>\n";
		printSelectInput("platformid", $platforms);
		print "    </TD>\n";
	}
	if($data["showschedule"] || $showall) {
		print "    <TD>\n";
		printSelectInput("scheduleid", $schedules);
		print "    </TD>\n";
	}
	if($data["showcurrentimage"] || $showall)
		print "    <TD><img src=\"images/blank.gif\" width=190 height=1></TD>\n";
	if($data["shownextimage"] || $showall)
		print "    <TD></TD>\n";
	if($data["showram"] || $showall)
		print "    <TD><INPUT type=text name=ram size=5 maxlength=5></TD>\n";
	if($data["showprocnumber"] || $showall) {
		print "    <TD>\n";
		printSelectInput("numprocs", 
		   array("1" => "1", "2" => "2", "4" => "4", "8" => "8"));
		print "    </TD>\n";
	}
	if($data["showprocspeed"] || $showall) {
		print "    <TD><INPUT type=text name=procspeed size=5 maxlength=5>";
		print "</TD>\n";
	}
	if($data["shownetwork"] || $showall) {
		print "    <TD>\n";
		printSelectInput("network", 
		   array("10" => "10", "100" => "100", "1000" => "1000"));
		print "    </TD>\n";
	}
	if($data["showcomputerid"] || $showall)
		print "    <TD></TD>\n";
	if($data["showtype"] || $showall) {
		print "    <TD>\n";
		printSelectInput("type", array("blade" => "blade", "lab" => "lab"), "lab");
		print "    </TD>\n";
	}
	if($data["showprovisioning"] || $showall) {
		print "    <TD>\n";
		printSelectInput("provisioningid", $provisioning);
		print "    </TD>\n";
	}
	if($data["showdeleted"])
		print "    <TD align=center>N/A</TD>\n";
	if($data["shownotes"])
		print "    <TD>&nbsp;</TD>\n";
	if($data["showcounts"])
		print "    <TD>&nbsp;</TD>\n";
	$cdata = getComputerSelection($data);
	$cont = addContinuationsEntry('confirmAddComputer', $cdata);
	print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "    </FORM>\n";
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
	global $submitErr;
	$data2 = processComputerInput2();

	$computers = getComputers();

	$nocomps = getContinuationVar('nocomps', 0);
	if($submitErr) {
		$data = processComputerInput();
	}
	elseif($nocomps) {
		$data["ipaddress"] = '';
		$data["stateid"] = '';
		$data["deptid"] = '';
		$data["owner"] = '';
		$data["platformid"] = '';
		$data["scheduleid"] = '';
		$data["currentimgid"] = '';
		$data["ram"] = '';
		$data["numprocs"] = '';
		$data["procspeed"] = '';
		$data["network"] = '';
		$data["hostname"] = '';
		$data["type"] = '';
		$data["notes"] = '';
		$data["computergroup"] = array();
		$data["provisioningid"] = '';
	}
	else {
		$data["compid"] = getContinuationVar("compid");
		$id = $data["compid"];
		$data["ipaddress"] = $computers[$id]["IPaddress"];
		$data["stateid"] = $computers[$id]["stateid"];
		$data["deptid"] = $computers[$id]["deptid"];
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
	}
	
	$tmpstates = getStates();
	if($data["stateid"]) {
		$states = array($data["stateid"] => $tmpstates[$data["stateid"]],
		                2 => "available",
		                10 => "maintenance");
	}
	else {
		$states = array(2 => "available",
		                10 => "maintenance");
	}
	$platforms = getPlatforms();
	$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"));
	$schedules = $tmp["schedule"];
	$allschedules = getSchedules();
	$images = getImages();
	$provisioning = getProvisioning();

	if($state) {
		print "<H2>Add Computer</H2>\n";
	}
	else {
		print "<H2>Edit Computer</H2>\n";
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname:</TH>\n";
	print "    <TD><INPUT type=text name=hostname maxlength=36 value=";
	print $data["hostname"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(HOSTNAMEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>IP Address:</TH>\n";
	print "    <TD><INPUT type=text name=ipaddress maxlength=14 value=\"";
	print $data["ipaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>State:</TH>\n";
	print "    <TD>\n";
	printSelectInput("stateid", $states, $data["stateid"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD><INPUT type=text name=owner value=\"";
	print $data["owner"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(OWNERERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Platform:</TH>\n";
	print "    <TD>\n";
	printSelectInput("platformid", $platforms, $data["platformid"]);
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
		printSelectInput("scheduleid", $schedules, $data["scheduleid"]);
	}
	else
		printSelectInput("scheduleid", $schedules);
	print "    </TD>\n";
	print "  </TR>\n";
	if(! $state) {
		print "  <TR>\n";
		print "    <TH align=right>Current Image:</TH>\n";
		print "    <TD>" . $images[$data["currentimgid"]]["prettyname"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>RAM (MB):</TH>\n";
	print "    <TD><INPUT type=text name=ram maxlength=5 value=";
	print $data["ram"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(RAMERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>No. Processors:</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("1" => "1", "2" => "2", "4" => "4", "8" => "8");
	printSelectInput("numprocs", $tmpArr, $data["numprocs"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Processor Speed (MHz):</TH>\n";
	print "    <TD><INPUT type=text name=procspeed maxlength=5 value=";
	print $data["procspeed"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(PROCSPEEDERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Network Speed (Mbps):</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("10" => "10", "100" => "100", "1000" => "1000");
	printSelectInput("network", $tmpArr, $data["network"]);
	print "    </TD>\n";
	print "  </TR>\n";
	if(! $state) {
		print "  <TR>\n";
		print "    <TH align=right>Compter ID:</TH>\n";
		print "    <TD>" . $data["compid"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Type:</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("blade" => "blade", "lab" => "lab", "virtualmachine" => "virtualmachine");
	printSelectInput("type", $tmpArr, $data["type"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Provisioning Engine:</TH>\n";
	print "    <TD>\n";
	printSelectInput("provisioningid", $provisioning, $data["provisioningid"]);
	print "    </TD>\n";
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
	if($state) {
		$cont = addContinuationsEntry('confirmAddComputer', $data2, SECINDAY, 0, 1, 1);
		print "      <INPUT type=submit value=\"Confirm Computer\">\n";
	}
	else {
		$data2['currentimgid'] = $data['currentimgid'];
		$data2['compid'] = $data['compid'];
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
	global $submitErr;

	$data = processComputerInput();
	
	if($data["bulk"]) {
		$submitErr = 0;
		bulkAddComputer();
		return;
	}

	if($submitErr) {
		editOrAddComputer($state);
		return;
	}

	if($state) {
		$data["currentimgid"] = "";
		$data["compid"] = "";
		$nextmode = "submitAddComputer";
		$title = "Add Computer";
		$question = "Submit the following new computer?";
	}
	else {
		$nextmode = "submitEditComputer";
		$title = "Edit Computer";
		$question = "Submit the following changes?";
	}

	print "<H2>$title</H2>\n";
	print "<H3>$question</H3>\n";
	printComputerInfo($data["ipaddress"],
	                  $data["stateid"],
	                  $data["deptid"],
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
	                  $data["provisioningid"]);
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
	if($data['stateid'] == 10)
		$cont = addContinuationsEntry('computerAddMaintenanceNote', $data, SECINDAY, 0);
	else
		$cont = addContinuationsEntry($nextmode, $data, SECINDAY, 0, 0);
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
	# maintenance to maintenance
	if($compdata[$data["compid"]]["stateid"] == 10 &&
	   $data["stateid"] == 10) {
		// possibly update notes with new text
		$testdata = explode('@', $compdata[$data["compid"]]["notes"]);
		if(count($testdata) != 2)
			$testdata[1] = "";
		if($testdata[1] == $data["notes"]) 
			// don't update the notes field
			$data["notes"] = $compdata[$data["compid"]]["notes"];
		else
			// update user, timestamp, and text
			$data["notes"] = $user["unityid"] . " " . unixToDatetime(time()) . "@"
		                  . $data["notes"];
	}
	# available or failed to maintenance
	if(($compdata[$data["compid"]]["stateid"] == 2 ||
	   $compdata[$data["compid"]]["stateid"] == 5) &&
	   $data["stateid"] == 10) {
		// set notes to new data
		$data["notes"] = $user["unityid"] . " " . unixToDatetime(time()) . "@"
		               . $data["notes"];
	}
	# maintenance or failed to available
	if(($compdata[$data["compid"]]["stateid"] == 10 ||
	   $compdata[$data["compid"]]["stateid"] == 5) &&
	   $data["stateid"] == 2) {
		$data["notes"] = "";
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
	$compdata = getComputers(0, 0, $data["compid"]);
	$notes = explode('@', $compdata[$data["compid"]]["notes"]);
	if(count($notes) != 2)
		$notes[1] = "";
	print "<DIV align=center>\n";
	print "<H2>Edit Computer</H2>\n";
	print "Why are placing this computer in the maintenance state?\n";
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
	#print "<H2>Add Computer</H2>\n";
	#print "The computer has been added.";
	clearPrivCache();
	viewComputers();
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
	printComputerInfo($computers[$compid]["IPaddress"],
	                  $computers[$compid]["stateid"],
	                  $computers[$compid]["deptid"],
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
	                  $computers[$compid]["provisioningid"]);
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = $data;
	$cdata['deleted'] = $deleted;
	$cdata['compid'] = $compid;
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
	if($deleted) {
		$query = "UPDATE computer "
				 . "SET deleted = 0 "
				 . "WHERE id = $compid";
		$qh = doQuery($query, 190);
	}
	else {
		$query = "UPDATE computer "
				 . "SET deleted = 1 "
				 . "WHERE id = $compid";
		$qh = doQuery($query, 191);
	}
	$_SESSION['userresources'] = array();
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
	global $submitErr, $viewmode;

	$data = processBulkComputerInput(0);
	$data2 = processComputerInput2(); //yes, this is somewhat redundant, but it
	                                  // makes things easier later

	$states = array("2" => "available",
	                "10" => "maintenance");
	$platforms = getPlatforms();
	$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"));
	$schedules = $tmp["schedule"];
	$images = getImages();
	$provisioning = getProvisioning();

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
	print "    <TH align=right nowrap>Start IP Address*:</TH>\n";
	print "    <TD><INPUT type=text name=startipaddress maxlength=14 value=\"";
	print $data["startipaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>End IP Address*:</TH>\n";
	print "    <TD><INPUT type=text name=endipaddress maxlength=14 value=\"";
	print $data["endipaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR2);
	print "</TD>\n";
	print "  </TR>\n";

	print "  <TR>\n";
	print "    <TH align=right nowrap>Start private IP Address:</TH>\n";
	print "    <TD><INPUT type=text name=startpripaddress maxlength=14 value=\"";
	print $data["startpripaddress"] . "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRERR3);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>End private IP Address:</TH>\n";
	print "    <TD><INPUT type=text name=endpripaddress maxlength=14 value=\"";
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
	print "    <TH align=right nowrap>State:</TH>\n";
	print "    <TD>\n";
	printSelectInput("stateid", $states, $data["stateid"]);
	print "    </TD>\n";
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
	printSelectInput("platformid", $platforms, $data["platformid"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Schedule:</TH>\n";
	print "    <TD>\n";
	printSelectInput("scheduleid", $schedules, $data["scheduleid"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>RAM (MB)*:</TH>\n";
	print "    <TD><INPUT type=text name=ram maxlength=5 value=";
	print $data["ram"] . "></TD>\n";
	print "    <TD>";
	printSubmitErr(RAMERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>No. Processors:</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("1" => "1", "2" => "2", "4" => "4", "8" => "8");
	printSelectInput("numprocs", $tmpArr, $data["numprocs"]);
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
	$tmpArr = array("10" => "10", "100" => "100", "1000" => "1000");
	printSelectInput("network", $tmpArr, $data["network"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Type:</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("blade" => "blade", "lab" => "lab", "virtualmachine" => "virtualmachine");
	printSelectInput("type", $tmpArr, $data["type"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Provisioning Engine:</TH>\n";
	print "    <TD>\n";
	printSelectInput("provisioningid", $provisioning, $data["provisioningid"]);
	print "    </TD>\n";
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
	print "    <TH align=right nowrap>IP Addresses:</TH>\n";
	print "    <TD>" . $data["startipaddress"] . " - ";
	print $data["endipaddress"] . "</TD>\n";
	print "  </TR>\n";
	if(! empty($data['startpraddress'])) {
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
	print "    <TH align=right>State:</TH>\n";
	print "    <TD>" . $states[$data["stateid"]] . "</TD>\n";
	print "  </TR>\n";
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
	print "    <TH align=right nowrap>No. Processors:</TH>\n";
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
	print "    <TH align=right>Type:</TH>\n";
	print "    <TD>" . $data["type"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Provisioning Engine:</TH>\n";
	print "    <TD>" . $provisioning[$data["provisioningid"]]['prettyname'] . "</TD>\n";
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

	$dhcpdata = array();
	$count = 0;
	$addedrows = 0;
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
		$query .=       "type) "
		       . "VALUES ({$data["stateid"]}, "
		       .         "$ownerid, "
		       .         "{$data["platformid"]}, "
		       .         "{$data["provisioningid"]}, "
		       .         "{$data["scheduleid"]}, "
		       .         "4, "
		       .         "{$data["ram"]}, "
		       .         "{$data["numprocs"]}, "
		       .         "{$data["procspeed"]}, "
		       .         "{$data["network"]}, "
		       .         "'$hostname', "
		       .         "'$ipaddress', ";
		if($dopr)
			$query .=     "'$pripaddress', ";
		if($domacs)
			$query .=     "'$eth0', "
			       .      "'$eth1', ";
		$query .=        "'{$data["type"]}')";
		$qh = doQuery($query, 235);
		$addedrows += mysql_affected_rows($mysql_link_vcl);
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM computer", 236);
		if(! $row = mysql_fetch_row($qh)) {
			abort(237);
		}
		$query = "INSERT INTO resource "
		       .        "(resourcetypeid, "
		       .        "subid) "
		       . "VALUES (12, "
		       .         $row[0] . ")";
		doQuery($query, 238);

		// add computer into selected groups
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM resource", 101);
		if(! $row = mysql_fetch_row($qh)) {
			abort(237);
		}

		foreach(array_keys($data["computergroup"]) as $groupid) {
			$query = "INSERT INTO resourcegroupmembers "
		          .        "(resourceid, "
		          .        "resourcegroupid) "
		          . "VALUES ({$row[0]}, "
		          .        "$groupid)";
			doQuery($query, 101);
		}
	}
	print "<DIV align=center>\n";
	print "<H2>Add Multiple Computers</H2>\n";
	if($count == $addedrows) {
		print "The computers were added successfully.<br><br>\n";
	}
	else {
		print $count - $addedrows . " computers failed to get added<br><br>\n";
	}
	print "</div>\n";
	if($domacs)
		generateDhcpForm($dhcpdata);
	clearPrivCache();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn generateDhcpForm($data)
///
/// \brief prints a form for entering an ip address for a management node so
/// that data for a dhcpd.conf file can be generated
///
////////////////////////////////////////////////////////////////////////////////
function generateDhcpForm($data) {
	global $submitErr;
	$mnipaddr = processInputVar('mnipaddr', ARG_STRING, "");
	print "<div>\n";
	print "<h3>Generate Data for dhcpd.conf File (Optional)</h3>\n";
	print "<form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "Enter the private address for the management node<br>";
	print "on which the data will be used:<br>\n";
	print "<INPUT type=text name=mnipaddr value=\"$mnipaddr\" maxlength=15>\n";
	printSubmitErr(IPADDRERR);
	print "<br>\n";
	print "<input type=submit value=\"Download Data\">\n";
	$cont = addContinuationsEntry('generateDHCP', $data, SECINDAY, 1, 0);
	print "<input type=hidden name=continuation value=\"$cont\">\n";
	print "</form>\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn generateDHCP()
///
/// \brief prints content for a dhcpd.conf file from saved continuation data
///
////////////////////////////////////////////////////////////////////////////////
function generateDHCP() {
	global $submitErr, $submitErrMsg, $HTMLheader, $printedHTMLheader;
	$mnipaddr = processInputVar('mnipaddr', ARG_STRING);
	$data = getContinuationVar();
	$addrArr = explode('.', $mnipaddr);
	if(! ereg('^(([0-9]){1,3}\.){3}([0-9]){1,3}$', $mnipaddr) ||
		$addrArr[0] < 1 || $addrArr[0] > 255 ||
		$addrArr[1] < 0 || $addrArr[1] > 255 ||
		$addrArr[2] < 0 || $addrArr[2] > 255 ||
		$addrArr[3] < 1 || $addrArr[3] > 255) {
	   $submitErr |= IPADDRERR;
	   $submitErrMsg[IPADDRERR] = "Invalid IP address. Must be w.x.y.z with each of "
		                         . "w, x, y, and z being between 1 and 255 (inclusive)";
		print $HTMLheader;
		$printedHTMLheader = 1;
		generateDhcpForm($data);
		print getFooter();
		return;
	}
	header("Content-type: text/plain");
	header("Content-Disposition: inline; filename=\"dhcpdata.txt\"");
	foreach($data as $comp) {
		$tmp = explode('.', $comp['hostname']);
		print "\t\thost {$tmp[0]} {\n";
		print "\t\t\toption host-name \"{$tmp[0]}\";\n";
		print "\t\t\thardware ethernet {$comp['eth0mac']};\n";
		print "\t\t\tfixed-address {$comp['prip']};\n";
		print "\t\t\tfilename \"/tftpboot/pxelinux.0\";\n";
		print "\t\t\toption dhcp-server-identifier $mnipaddr;\n";
		print "\t\t\tnext-server $mnipaddr;\n";
		print "\t\t}\n\n";
	}
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
	print "<TABLE border=1>\n";
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
	global $user, $mode;
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
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post id=utilform>\n";
	print "<TABLE border=1>\n";
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
	print "    <TH>No. Processors</TH>\n";
	print "    <TH>Processor Speed(MHz)</TH>\n";
	print "    <TH>Network Speed(Mbps)</TH>\n";
	print "    <TH>Computer ID</TH>\n";
	print "    <TH>Type</TH>\n";
	print "    <TH>No. of Reservations</TH>\n";*/
	print "    <TH>Notes</TH>\n";
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
		print "  <TR align=center id=compid$count>\n";
		print "    <TD><INPUT type=checkbox name=computerids[] value=$id ";
		print "id=comp$count onclick=\"toggleRowSelect('compid$count');\"></TD>\n";
		print "    <TD>" . $computers[$id]["hostname"] . "</TD>\n";
		print "    <TD>" . $computers[$id]["IPaddress"] . "</TD>\n";
		if($computers[$id]['state'] == 'failed')
			print "    <TD><font color=red>{$computers[$id]["state"]}</font></TD>\n";
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
	print "    <TD>Change state of selected computers to:</TD>";
	$states = array("2" => "available",
	                "23" => "hpc",
	                "10" => "maintenance",
	                "20" => "vmhostinuse");
	print "    <TD colspan=2>\n";
	printSelectInput("stateid", $states);
	print "    <INPUT type=button onclick=compStateChangeSubmit(); value=\"Confirm State Change\">";
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
	print "</TABLE>\n";
	print "<INPUT type=hidden name=continuation id=continuation>\n";
	print "</FORM>\n";
	print "<br>$count computers found<br>\n";
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
		printSelectInput('profileid', $profiles);
		print "<br><br>\n";
	}
	elseif($data['stateid'] == 23) {
		print "You are about to place the following computers into the ";
		print "hpc state:\n";
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
		$data['notes'] = mysql_escape_string($data['notes']);
		$data["notes"] = $user["unityid"] . " " . unixToDatetime(time()) . "@"
		               . $data["notes"];
		$vclreloadid = getUserlistID('vclreload@Local');
		// get semaphore lock
		if(! semLock())
			abort(3);
		$noaction = array();
		$changenow = array();
		$changeasap = array();
		$changetimes = array();
		foreach($data['computerids'] as $compid) {
			if($computers[$compid]['state'] == 'maintenance')
				array_push($noaction, $compid);
			else
				array_push($changeasap, $compid);
		}
		$passes = array();
		$fails = array();
		foreach($changeasap as $compid) {
			# TODO what about blockComputers?
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
			# create a really long reservation starting at that time in state tomaintenance
			if($row = mysql_fetch_assoc($qh)) {
				$start = $row['end'];
				$changetimes[$compid] = $start;
				$end = datetimeToUnix($start) + SECINWEEK; // hopefully keep future reservations off of it
				$end = unixToDatetime($end);
				if(simpleAddRequest($compid, 4, 3, $start, $end, 18, $vclreloadid))
					$passes[] = $compid;
				else
					$fails[] = $compid;
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
			print "but no functional management node was found for them. Nothing ";
			print "be done with them at this time:\n";
			print "<TABLE>\n";
			print "  <TR>\n";
			print "    <TH>Computer</TH>\n";
			print "  </TR>\n";
			foreach($passes as $compid) {
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
		$noaction = array();
		$changenow = array();
		$changeasap = array();
		$changetimes = array();
		foreach($data['computerids'] as $compid) {
			if($computers[$compid]['state'] == 'vmhostinuse')
				array_push($noaction, $compid);
			else
				array_push($changeasap, $compid);
		}
		if(! semLock())
			abort(3);
		foreach($changeasap as $compid) {
			# TODO what about blockComputers?
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
			if($row = mysql_fetch_assoc($qh)) {
				// if there is a reservation, leave in $changeasap so we can
				#   notify that we can't change this one
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
				$imagerevisionid = getProductionRevisionid($data['profiles'][$profileid]['imageid']);
				$vclreloadid = getUserlistID('vclreload@Local');
				simpleAddRequest($compid, $data['profiles'][$profileid]['imageid'],
				                 $imagerevisionid, $start, $end, 21, $vclreloadid);
				unset_by_val($compid, $changeasap);
				array_push($changenow, $compid);

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
			# TODO what about blockComputers?
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
			if($row = mysql_fetch_assoc($qh)) {
				// if there is a reservation, leave in $changeasap so we can
				#   notify that we can't change this one
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
/// bulk, ipaddress, stateid, deptid, platformid, scheduleid, currentimgid,
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
	$return["ipaddress"] = getContinuationVar("ipaddress", processInputVar("ipaddress", ARG_STRING));
	$return["stateid"] = getContinuationVar("stateid", processInputVar("stateid", ARG_NUMERIC));
	$return["deptid"] = getContinuationVar("deptid", processInputVar("deptid", ARG_NUMERIC));
	$return["owner"] = getContinuationVar("owner", processInputVar("owner", ARG_STRING));
	$return["platformid"] = getContinuationVar("platformid", processInputVar("platformid", ARG_NUMERIC));
	$return["scheduleid"] = getContinuationVar("scheduleid", processInputVar("scheduleid", ARG_NUMERIC));
	$return["currentimgid"] = getContinuationVar("currentimgid", processInputVar("currentimgid", ARG_NUMERIC));
	$return["ram"] = getContinuationVar("ram", processInputVar("ram", ARG_NUMERIC));
	$return["numprocs"] = getContinuationVar("numprocs", processInputVar("numprocs", ARG_NUMERIC));
	$return["procspeed"] = getContinuationVar("procspeed", processInputVar("procspeed", ARG_NUMERIC));
	$return["network"] = getContinuationVar("network", processInputVar("network", ARG_NUMERIC));
	$return["hostname"] = getContinuationVar("hostname", processInputVar("hostname", ARG_STRING));
	$return["compid"] = getContinuationVar("compid", processInputVar("compid", ARG_NUMERIC));
	$return["type"] = getContinuationVar("type", processInputVar("type", ARG_STRING, "lab"));
	$return["provisioningid"] = getContinuationVar("provisioningid", processInputVar("provisioningid", ARG_NUMERIC));
	$return["notes"] = getContinuationVar("notes", processInputVar("notes", ARG_STRING));
	$return["computergroup"] = getContinuationVar("computergroup", processInputVar("computergroup", ARG_MULTINUMERIC));
	$return["showcounts"] = getContinuationVar("showcounts", processInputVar("showcounts", ARG_NUMERIC));
	$return["showdeleted"] = getContinuationVar('showdeleted', 0);

	if(! $checks) {
		return $return;
	}

	$ipaddressArr = explode('.', $return["ipaddress"]);
	if(! ereg('^(([0-9]){1,3}\.){3}([0-9]){1,3}$', $return["ipaddress"]) ||
		$ipaddressArr[0] < 1 || $ipaddressArr[0] > 255 ||
		$ipaddressArr[1] < 0 || $ipaddressArr[1] > 255 ||
		$ipaddressArr[2] < 0 || $ipaddressArr[2] > 255 ||
		$ipaddressArr[3] < 1 || $ipaddressArr[3] > 255) {
	   $submitErr |= IPADDRERR;
	   $submitErrMsg[IPADDRERR] = "Invalid IP address. Must be w.x.y.z with each of "
		                         . "w, x, y, and z being between 1 and 255 (inclusive)";
	}
	/*if(! ($submitErr & IPADDRERR) && 
	   checkForIPaddress($return["ipaddress"], $return["compid"])) {
	   $submitErr |= IPADDRERR;
	   $submitErrMsg[IPADDRERR] = "There is already a computer with this IP address.";
	}*/
	if($return["ram"] < 32 || $return["ram"] > 20480) {
	   $submitErr |= RAMERR;
	   $submitErrMsg[RAMERR] = "RAM must be between 32 and 20480";
	}
	if($return["procspeed"] < 500 || $return["procspeed"] > 20000) {
	   $submitErr |= PROCSPEEDERR;
	   $submitErrMsg[PROCSPEEDERR] = "Processor Speed must be between 500 and 20000";
	}
	if(! ereg('^[a-zA-Z0-9_][-a-zA-Z0-9_.]{1,35}$', $return["hostname"])) {
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
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processComputerInput2()
///
/// \return an array with the following keys:\n
/// depts, platforms, schedules, showhostname, shownextimage, 
/// showipaddress, showram, showstate, showprocnumber, showdepartment,
/// showprocspeed, showplatform, shownetwork, showschedule, showcomputerid,
/// showcurrentimage, showtype, showprovisioning
///
/// \brief processes depts, platforms, schedules, and all of the flags for
/// what data to show
///
////////////////////////////////////////////////////////////////////////////////
function processComputerInput2() {
	$return = array();

	$return["depts"] = getContinuationVar('depts', processInputVar("depts", ARG_MULTINUMERIC));
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
/// startipaddress, endipaddress, starthostval, endhostval, stateid, deptid,
/// platformid, scheduleid, ram, numprocs, procspeed, network,
/// hostname, type, count (0 if any errors found)
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processBulkComputerInput($checks=1) {
	global $submitErr, $submitErrMsg, $viewmode;
	$return = processComputerInput2();
	$ipaddress = getContinuationVar("ipaddress", processInputVar("ipaddress", ARG_STRING));
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
		$return["startipaddress"] = getContinuationVar("startipaddress", processInputVar("startipaddress", ARG_STRING));
		$return["endipaddress"] = getContinuationVar("endipaddress", processInputVar("endipaddress", ARG_STRING));
		$return["starthostval"] = getContinuationVar("starthostval", processInputVar("starthostval", ARG_NUMERIC));
		$return["endhostval"] = getContinuationVar("endhostval", processInputVar("endhostval", ARG_NUMERIC));
	}
	$return["startpripaddress"] = getContinuationVar("startpripaddress", processInputVar("startpripaddress", ARG_STRING));
	$return["endpripaddress"] = getContinuationVar("endpripaddress", processInputVar("endpripaddress", ARG_STRING));
	$return["startmac"] = getContinuationVar("startmac", processInputVar("startmac", ARG_STRING));

	$return["stateid"] = getContinuationVar("stateid", processInputVar("stateid", ARG_NUMERIC));
	$return["deptid"] = getContinuationVar("deptid", processInputVar("deptid", ARG_NUMERIC));
	$return["owner"] = getContinuationVar("owner", processInputVar("owner", ARG_STRING));
	$return["platformid"] = getContinuationVar("platformid", processInputVar("platformid", ARG_NUMERIC));
	$return["scheduleid"] = getContinuationVar("scheduleid", processInputVar("scheduleid", ARG_NUMERIC));
	$return["ram"] = getContinuationVar("ram", processInputVar("ram", ARG_NUMERIC));
	$return["numprocs"] = getContinuationVar("numprocs", processInputVar("numprocs", ARG_NUMERIC));
	$return["procspeed"] = getContinuationVar("procspeed", processInputVar("procspeed", ARG_NUMERIC));
	$return["network"] = getContinuationVar("network", processInputVar("network", ARG_NUMERIC));
	$return["hostname"] = getContinuationVar("hostname", processInputVar("hostname", ARG_STRING));
	$return["type"] = getContinuationVar("type", processInputVar("type", ARG_STRING));
	$return["provisioningid"] = getContinuationVar("provisioningid", processInputVar("provisioningid", ARG_NUMERIC));
	$return["computergroup"] = getContinuationVar("computergroup", processInputVar("computergroup", ARG_MULTINUMERIC));
	$return['macs'] = getContinuationVar('macs', array());

	if(! $checks) {
		return $return;
	}

	$startaddrArr = explode('.', $return["startipaddress"]);
	if(! ereg('^(([0-9]){1,3}\.){3}([0-9]){1,3}$', $return["startipaddress"]) ||
		$startaddrArr[0] < 1 || $startaddrArr[0] > 255 ||
		$startaddrArr[1] < 0 || $startaddrArr[1] > 255 ||
		$startaddrArr[2] < 0 || $startaddrArr[2] > 255 ||
		$startaddrArr[3] < 1 || $startaddrArr[3] > 255) {
	   $submitErr |= IPADDRERR;
	   $submitErrMsg[IPADDRERR] = "Invalid IP address. Must be w.x.y.z with each of "
		                         . "w, x, y, and z being between 1 and 255 (inclusive)";
	}
	$endaddrArr = explode('.', $return["endipaddress"]);
	if(! ereg('^(([0-9]){1,3}\.){3}([0-9]){1,3}$', $return["endipaddress"]) ||
		$endaddrArr[0] < 1 || $endaddrArr[0] > 255 ||
		$endaddrArr[1] < 0 || $endaddrArr[1] > 255 ||
		$endaddrArr[2] < 0 || $endaddrArr[2] > 255 ||
		$endaddrArr[3] < 1 || $endaddrArr[3] > 255) {
	   $submitErr |= IPADDRERR2;
	   $submitErrMsg[IPADDRERR2] = "Invalid IP address. Must be w.x.y.z with each of "
		                          . "w, x, y, and z being between 1 and 255 (inclusive)";
	}
	$endpraddrArr = array();
	if($viewmode == ADMIN_DEVELOPER) {
		if(! empty($return['startpripaddress']) ||
		   ! empty($return['endpripaddress'])) {
			$startpraddrArr = explode('.', $return["startpripaddress"]);
			if(! ereg('^(([0-9]){1,3}\.){3}([0-9]){1,3}$', $return["startpripaddress"]) ||
				$startpraddrArr[0] < 1 || $startpraddrArr[0] > 255 ||
				$startpraddrArr[1] < 0 || $startpraddrArr[1] > 255 ||
				$startpraddrArr[2] < 0 || $startpraddrArr[2] > 255 ||
				$startpraddrArr[3] < 1 || $startpraddrArr[3] > 255) {
				$submitErr |= IPADDRERR3;
				$submitErrMsg[IPADDRERR3] = "Invalid IP address. Must be w.x.y.z with each of "
				                          . "w, x, y, and z being between 1 and 255 (inclusive)";
			}
			$endpraddrArr = explode('.', $return["endpripaddress"]);
			if(! ereg('^(([0-9]){1,3}\.){3}([0-9]){1,3}$', $return["endpripaddress"]) ||
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
		   if(! ereg('^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$', $return["startmac"])) {
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
				}
				if($i > 16777215 && $topdec == 16777215) {
					$submitErr |= MACADDRERR;
					$submitErrMsg[MACADDRERR] = "Starting MAC address too large for given "
					                          . "given number of machines";
				}
			}
		}
	}
	if($return["ram"] < 32 || $return["ram"] > 20480) {
	   $submitErr |= RAMERR;
	   $submitErrMsg[RAMERR] = "RAM must be between 32 and 20480";
	}
	if($return["procspeed"] < 500 || $return["procspeed"] > 20000) {
	   $submitErr |= PROCSPEEDERR;
	   $submitErrMsg[PROCSPEEDERR] = "Processor Speed must be between 500 and 20000";
	}
	if(! ereg('^[a-zA-Z0-9_%][-a-zA-Z0-9_.%]{1,35}$', $return["hostname"])) {
	   $submitErr |= HOSTNAMEERR;
	   $submitErrMsg[HOSTNAMEERR] = "Hostname must be <= 36 characters";
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
	   $submitErrMsg[ENDHOSTVALERR] = "The number of IP addresses ($numipaddrs) "
		      . "does not match the number of hostnames ($numhostnames).";
	}
	if($viewmode == ADMIN_DEVELOPER &&
	   ! empty($return['startpripaddress']) && ! empty($return['endpripaddress']) &&
	   (! ($submitErr & IPADDRERR2 || $submitErr & IPADDRERR4) && 
	   ! empty($endpraddrArr) &&
		($endaddrArr[3] - $startaddrArr[3] != $endpraddrArr[3] - $startpraddrArr[3]))) {
		$numpubaddrs = $endaddrArr[3] - $startaddrArr[3] + 1;
		$numpraddrs = $endpraddrArr[3] - $startpraddrArr[3] + 1;
	   $submitErr |= IPADDRERR2;
	   $submitErrMsg[IPADDRERR2] = "The number of public IP addresses ($numpubaddrs) "
		      . "does not match the number of private IP addresses ($numpraddrs).";
	   $submitErr |= IPADDRERR4;
	   $submitErrMsg[IPADDRERR4] = $submitErrMsg[IPADDRERR2];
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
	       . "WHERE hostname = '$hostname'";
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
/// ipaddress, stateid, deptid, platformid, scheduleid,
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
	$ownerid = getUserlistID($data["owner"]);
	$query = "UPDATE computer "
	       . "SET stateid = {$data["stateid"]}, "
	       /*.     "deptid = " . $data["deptid"] . ", "*/
	       .     "ownerid = $ownerid, "
	       .     "platformid = {$data["platformid"]}, "
	       .     "scheduleid = {$data["scheduleid"]}, "
	       .     "RAM = {$data["ram"]}, "
	       .     "procnumber = {$data["numprocs"]}, "
	       .     "procspeed = {$data["procspeed"]}, "
	       .     "network = {$data["network"]}, "
	       .     "hostname = '{$data["hostname"]}', "
	       .     "IPaddress = '{$data["ipaddress"]}', "
	       .     "type = '{$data["type"]}', "
	       .     "provisioningid = {$data["provisioningid"]}, "
	       .     "notes = '{$data["notes"]}' "
	       . "WHERE id = {$data["compid"]}";
	$qh = doQuery($query, 185);
	return mysql_affected_rows($GLOBALS["mysql_link_vcl"]);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addComputer($data)
///
/// \param $data - an array with the following indexes:\n
/// ipaddress, stateid, deptid, platformid, scheduleid,
/// ram, numprocs, procspeed, network, hostname, type
///
/// \brief adds a computer to the computer table
///
////////////////////////////////////////////////////////////////////////////////
function addComputer($data) {
	$ownerid = getUserlistID($data["owner"]);
	$query = "INSERT INTO computer "
	       .        "(stateid, "
	       .        "ownerid, "
	       .        "platformid, "
	       .        "scheduleid, "
	       .        "currentimageid, "
	       .        "RAM, "
	       .        "procnumber, "
	       .        "procspeed, "
	       .        "network, "
	       .        "hostname, "
	       .        "IPaddress, "
	       .        "type, "
	       .        "provisioningid) "
	       . "VALUES (" . $data["stateid"] . ", "
	       .         "$ownerid, "
	       .         $data["platformid"] . ", "
	       .         $data["scheduleid"] . ", "
	       .         "4, "
	       .         $data["ram"] . ", "
	       .         $data["numprocs"] . ", "
	       .         $data["procspeed"] . ", "
	       .         $data["network"] . ", "
	       .         "'" . $data["hostname"] . "', "
	       .         "'" . $data["ipaddress"] . "', "
	       .         "'" . $data["type"] . "', "
	       .         "'" . $data["provisioningid"] . "')";
	doQuery($query, 195);

	$qh = doQuery("SELECT LAST_INSERT_ID() FROM computer", 196);
	if(! $row = mysql_fetch_row($qh)) {
		abort(197);
	}
	$query = "INSERT INTO resource "
			 .        "(resourcetypeid, "
			 .        "subid) "
			 . "VALUES (12, "
			 .         $row[0] . ")";
	doQuery($query, 198);

	// add computer into selected groups
	$qh = doQuery("SELECT LAST_INSERT_ID() FROM resource", 101);
	if(! $row = mysql_fetch_row($qh)) {
		abort(197);
	}

	foreach(array_keys($data["computergroup"]) as $groupid) {
		$query = "INSERT INTO resourcegroupmembers "
		       .        "(resourceid, "
		       .        "resourcegroupid) "
		       . "VALUES ({$row[0]}, "
		       .        "$groupid)";
		doQuery($query, 101);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printComputerInfo($ipaddress, $stateid, $deptid, $owner,
///                                $platformid, $scheduleid, $currentimgid,
///                                $ram, $numprocs, $procspeed,
///                                $network,  $hostname, $compid, $type,
///                                $provisioningid)
///
/// \param $ipaddress -  IP address of computer
/// \param $stateid - stateid of computer
/// \param $deptid - departmentid of computer
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
///
/// \brief prints a table of information about the computer
///
////////////////////////////////////////////////////////////////////////////////
function printComputerInfo($ipaddress, $stateid, $deptid, $owner, $platformid,
                           $scheduleid, $currentimgid, $ram, $numprocs,
                           $procspeed, $network, $hostname, $compid, $type,
                           $provisioningid) {

	$states = getStates();
	$platforms = getPlatforms();
	$schedules = getSchedules();
	$images = getImages();
	$provisioning = getProvisioning();

	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname:</TH>\n";
	print "    <TD>$hostname</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>IP&nbsp;Address:</TH>\n";
	print "    <TD>$ipaddress</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>State:</TH>\n";
	print "    <TD>" . $states[$stateid] . "</TD>\n";
	print "  </TR>\n";
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
		print "    <TH align=right>Current&nbsp;Image:</TH>\n";
		print "    <TD>" . $images[$currentimgid]["prettyname"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>RAM (MB):</TH>\n";
	print "    <TD>$ram</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>No.&nbsp;Processors:</TH>\n";
	print "    <TD>$numprocs</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Processor&nbsp;Speed&nbsp;(MHz):</TH>\n";
	print "    <TD>$procspeed</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Network&nbsp;Speed&nbsp;(Mbps):</TH>\n";
	print "    <TD>$network</TD>\n";
	print "  </TR>\n";
	if(! empty($compid)) {
		print "  <TR>\n";
		print "    <TH align=right>Computer&nbsp;ID:</TH>\n";
		print "    <TD>$compid</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Type:</TH>\n";
	print "    <TD>$type</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Provisioning Engine:</TH>\n";
	print "    <TD>" . $provisioning[$provisioningid]['prettyname'] . "</TD>\n";
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
	              "showprovisioning");
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
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
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
	print '/*{"items":' . json_encode($arr) . '}*/';
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
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
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
	print '/*{"items":' . json_encode($arr) . '}*/';
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
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
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
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
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
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
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
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
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
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
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
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
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
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
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
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
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
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
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
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
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
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
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
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

?>
