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
define("IDNAMEERR", 1);
/// signifies an error with the submitted group name
define("GRPNAMEERR", 1 << 1);
/// signifies an error with the submitted owner
define("GRPOWNER", 1 << 2);
/// signifies an error with the submitted initial max time
define("INITIALMAXERR", 1 << 3);
/// signifies an error with the submitted total max time
define("TOTALMAXERR", 1 << 4);
/// signifies an error with the submitted max extend time
define("MAXEXTENDERR", 1 << 5);
/// signifies an error with the submitted max overlapping reservations
define("MAXOVERLAPERR", 1 << 6);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewGroups()
///
/// \brief prints a page to view group information
///
////////////////////////////////////////////////////////////////////////////////
function viewGroups() {
	global $viewmode, $user, $mode;
	$modetype = getContinuationVar("type");

	$usergroups = getUserGroups(1);
	unset($usergroups[82]);  // remove None group
	if($user['showallgroups'])
		$affilusergroups = $usergroups;
	else
		$affilusergroups = getUserGroups(1, $user['affiliationid']);
	$resourcetypes = getTypes("resources");
	$resourcegroups = getResourceGroups();
	$resources = array();
	$userresources = getUserResources(array("groupAdmin"), 
	                                  array("manageGroup"), 1);
	foreach(array_keys($userresources) as $type) {
		foreach($userresources[$type] as $id => $group) {
			if(array_key_exists($id, $resourcegroups)) { // have to make sure it exists in case something was deleted from the session priv cache
				$resources[$id]["type"] = $type;
				$resources[$id]["name"] = $group;
				$resources[$id]["owner"] = $resourcegroups[$id]["owner"];
			}
		}
	}

	print "<H2>User Groups</H2>\n";
	if($modetype == "user") {
		if($mode == "submitAddGroup") {
			print "<font color=\"#008000\">User group successfully added";
			print "</font><br><br>\n";
		}
		elseif($mode == "submitDeleteGroup") {
			print "<font color=\"#008000\">User group successfully deleted";
			print "</font><br><br>\n";
		}
		elseif($mode == "submitEditGroup") {
			print "<font color=\"#008000\">User group successfully updated";
			print "</font><br><br>\n";
		}
	}
	print "<TABLE class=usergrouptable border=1>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TD></TD>\n";
	print "    <TH>Name</TH>\n";
	print "    <TH>Owner</TH>\n";
	print "    <TH>Editable by</TH>\n";
	print "    <TH>Initial Max Time (minutes)</TH>\n";
	print "    <TH>Total Max Time (minutes)</TH>\n";
	print "    <TH>Max Extend Time (minutes)</TH>\n";
	if($viewmode == ADMIN_DEVELOPER)
		print "    <TH>Max Overlapping Reservations</TH>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "    <TD></TD>\n";
	print "    <TD><INPUT type=submit value=Add></TD>\n";
	if($user['showallgroups']) {
		$affils = getAffiliations();
		print "    <TD nowrap><INPUT type=text name=name maxlength=30 size=10>";
		print "@";
		printSelectInput("affiliationid", $affils, $user['affiliationid']);
	}
	else
		print "    <TD nowrap><INPUT type=text name=name maxlength=30 size=20>";
	print "</TD>\n";
	print "    <TD><INPUT type=text name=owner size=15></TD>\n";
	print "    <TD>\n";
	printSelectInput("editgroupid", $affilusergroups, 82);
	print "    </TD>\n";
	print "    <TD><INPUT type=text name=initialmax maxlength=4 size=4 ";
	print "value=240></TD>\n";
	print "    <TD><INPUT type=text name=totalmax maxlength=4 size=4 value=360>";
	print "</TD>\n";
	print "    <TD><INPUT type=text name=maxextend maxlength=4 size=4 value=30>";
	print "</TD>\n";
	if($viewmode == ADMIN_DEVELOPER) {
		print "    <TD><INPUT type=text name=overlap maxlength=4 size=4 value=0>";
		print "</TD>\n";
	}
	$cont = addContinuationsEntry('submitAddGroup', array('type' => 'user'));
	print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "    </FORM>\n";
	print "  </TR>\n";
	$dispUserGrpIDs = array();
	foreach(array_keys($usergroups) as $id) {
		if($usergroups[$id]["name"] == " None")
			continue;
		# figure out if user is owner or in editor group
		$owner = 0;
		$editor = 0;
		if($usergroups[$id]["ownerid"] == $user["id"])
			$owner = 1;
		if(array_key_exists("editgroup", $usergroups[$id]) &&
		   in_array($usergroups[$id]["editgroup"], $user["groups"]))
			$editor = 1;
		if(! $owner && ! $editor)
			continue;
		if($user['showallgroups'])
			$dispUserGrpIDs[$id] = $usergroups[$id]['name'];
		elseif($usergroups[$id]['groupaffiliation'] == $user['affiliation'] &&
		   array_key_exists($id, $affilusergroups))
			$dispUserGrpIDs[$id] = $affilusergroups[$id]['name'];
		print "  <TR>\n";
		print "    <TD>\n";
		if($owner) {
			print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>";
			$cdata = array('type' => 'user',
			               'groupid' => $id);
			$cont = addContinuationsEntry('confirmDeleteGroup', $cdata);
			print "      <INPUT type=hidden name=continuation value=\"$cont\">";
			print "      <INPUT type=submit value=Delete>";
			print "      </FORM>";
		}
		print "    </TD>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('type' => 'user',
		               'groupid' => $id,
		               'isowner' => $owner);
		$cont = addContinuationsEntry('editGroup', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=Edit>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD valign=bottom>{$usergroups[$id]["name"]}</TD>\n";
		print "    <TD>{$usergroups[$id]["owner"]}</TD>\n";
		print "    <TD>{$usergroups[$id]["editgroup"]}@";
		print "{$usergroups[$id]['editgroupaffiliation']}</TD>\n";
		print "    <TD align=center>{$usergroups[$id]["initialmaxtime"]}</TD>\n";
		print "    <TD align=center>{$usergroups[$id]["totalmaxtime"]}</TD>\n";
		print "    <TD align=center>{$usergroups[$id]["maxextendtime"]}</TD>\n";
		if($viewmode == ADMIN_DEVELOPER)
			print "    <TD align=center>{$usergroups[$id]["overlapResCount"]}</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";

	print "<a name=resources></a>\n";
	print "<H2>Resource Groups</H2>\n";
	if($modetype == "resource") {
		if($mode == "submitAddGroup") {
			print "<font color=\"#008000\">Resource group successfully added";
			print "</font><br><br>\n";
		}
		elseif($mode == "submitDeleteGroup") {
			print "<font color=\"#008000\">Resource group successfully deleted";
			print "</font><br><br>\n";
		}
		elseif($mode == "submitEditGroup") {
			print "<font color=\"#008000\">Resource group successfully updated";
			print "</font><br><br>\n";
		}
	}
	print "<TABLE class=resourcegrouptable border=1>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TD></TD>\n";
	print "    <TH>Type</TH>\n";
	print "    <TH>Name</TH>\n";
	print "    <TH>Owning User Group</TH>\n";
	print "    <TD><a onmouseover=\"mouseoverHelp();\" ";
	print "onmouseout=\"clearGroupPopups();\">";
	print "<img alt=\"\" src=\"images/list.gif\"></a></TD>\n";
	print "  </TR>\n";
	if(! empty($dispUserGrpIDs)) {
		print "  <TR>\n";
		print "    <FORM action=\"" . BASEURL . SCRIPT . "#resources\" method=post>\n";
		print "    <TD></TD>\n";
		print "    <TD><INPUT type=submit value=Add></TD>\n";
		print "    <TD>\n";
		printSelectInput("resourcetypeid", $resourcetypes["resources"]);
		print "    </TD>\n";
		print "    <TD><INPUT type=text name=name maxlength=30 size=10></TD>\n";
		print "    <TD>\n";
		# remove the "None" group
		unset($usergroups[82]);
		# find a custom group the user is in and make it the default
		$defaultgroupkey = "";
		foreach(array_keys($user["groups"]) as $grpid) {
			if(array_key_exists($grpid, $usergroups)) {
				$defaultgroupkey = $grpid;
				break;
			}
		}
		printSelectInput("ownergroup", $dispUserGrpIDs, $defaultgroupkey);
		print "    </TD>\n";
		$cdata = array('type' => 'resource'/*,
		               'dispUserGrpIDs' => $dispUserGrpIDs*/);
		$cont = addContinuationsEntry('submitAddGroup', $cdata);
		print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "    </FORM>\n";
		print "  </TR>\n";
	}
	$jscont = addContinuationsEntry('jsonGetGroupInfo');
	foreach(array_keys($resources) as $id) {
		print "  <TR>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('type' => 'resource',
		               'groupid' => $id);
		$cont = addContinuationsEntry('confirmDeleteGroup', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=Delete>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('type' => 'resource',
		               'groupid' => $id,
		               'dispUserGrpIDs' => $dispUserGrpIDs);
		$cont = addContinuationsEntry('editGroup', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=Edit>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD>" . $resources[$id]["type"] . "</TD>\n";
		print "    <TD>" . $resources[$id]["name"] . "</TD>\n";
		print "    <TD>" . $resources[$id]["owner"] . "</TD>\n";
		print "    <TD><a onmouseover=\"getGroupInfo('$jscont', $id);\" ";
		print "onmouseout=\"clearGroupPopups();\">";
		print "<img alt=\"mouseover for list of resources in the group\" ";
		print "title=\"\" src=\"images/list.gif\"></a></TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "<div id=listitems onmouseover=\"blockClear();\" onmouseout=\"clearGroupPopups2(0);\"></div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editOrAddGroup($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a form for editing a group
///
////////////////////////////////////////////////////////////////////////////////
function editOrAddGroup($state) {
	global $submitErr, $user, $mode, $viewmode;

	$usergroups = getUserGroups(1);
	if($user['showallgroups'])
		$affilusergroups = $usergroups;
	else
		$affilusergroups = getUserGroups(1, $user['affiliationid']);
	$resourcegroups = getResourceGroups();
	$affils = getAffiliations();
	$resourcetypes = getTypes("resources");

	if($submitErr) {
		$data = processGroupInput(0);
		$newuser = processInputVar("newuser", ARG_STRING);
		if($mode == "submitEditGroup") {
			$id = $data["groupid"];
			if($data["type"] == "resource") {
				list($grouptype, $junk) = explode('/', $resourcegroups[$id]["name"]);
				$ownerid = $resourcegroups[$id]["ownerid"];
			}
		}
		else {
			if($data["type"] == "resource") {
				if($state)
					$grouptype = $resourcetypes['resources'][$data['resourcetypeid']];
				else
					list($grouptype, $junk) =
					      explode('/', $resourcegroups[$data['groupid']]["name"]);
				$ownerid = $data["ownergroup"];
			}
			else {
				$selectAffil = getContinuationVar('selectAffil');
				if(empty($selectAffil) && $user['showallgroups'])
						$selectAffil = 1;
			}
		}
	}
	else {
		$newuser = processInputVar("newuser", ARG_STRING);
		$data["groupid"] = getContinuationVar("groupid");
		$data["type"] = getContinuationVar("type");
		$data["isowner"] = getContinuationVar("isowner");
		$id = $data["groupid"];
		if($data["type"] == "user") {
			$data["name"] = $usergroups[$id]["name"];
			$data["affiliationid"] = $usergroups[$id]["groupaffiliationid"];
			$data["owner"] = $usergroups[$id]["owner"];
			$data["editgroupid"] = $usergroups[$id]["editgroupid"];
			$data["initialmax"] = $usergroups[$id]["initialmaxtime"];
			$data["totalmax"] = $usergroups[$id]["totalmaxtime"];
			$data["maxextend"] = $usergroups[$id]["maxextendtime"];
			$data["overlap"] = $usergroups[$id]["overlapResCount"];
			$tmp = explode('@', $data['name']);
			$data['name'] = $tmp[0];
			if($user['showallgroups'] ||
				(array_key_exists(1, $tmp) && $tmp[1] != $user['affiliation']))
				$selectAffil = 1;
			else
				$selectAffil = 0;
		}
		else {
			list($grouptype, $data["name"]) = 
			   explode('/', $resourcegroups[$id]["name"]);
			$ownerid = $resourcegroups[$id]["ownerid"];
		}
	}

	$editusergroup = 0;
	if($data['type'] != 'user')
		print "<FORM action=\"" . BASEURL . SCRIPT . "#resources\" method=post>\n";
	else
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<DIV align=center>\n";
	if($state) {
		if($data["type"] == "user")
			print "<H2>Add User Group</H2>\n";
		else
			print "<H2>Add Resource Group</H2>\n";
	}
	else {
		if($data["type"] == "user") {
			print "<H2>Edit User Group</H2>\n";
			print "{$usergroups[$data['groupid']]['name']}<br>\n";
			$editusergroup = 1;
		}
		else
			print "<H2>Edit Resource Group</H2>\n";
	}
	if(($state && $data["type"] == "user") || $data["isowner"] ||
		$data["type"] == "resource") {
		print "<TABLE>\n";
		if($data["type"] == "resource") {
			print "  <TR>\n";
			print "    <TH align=right>Type:</TH>\n";
			print "    <TD>\n";
			if($state && $submitErr)
				$resourcetypeid = $data['resourcetypeid'];
			else
				$resourcetypeid = array_search($grouptype, $resourcetypes["resources"]);
			if($state)
				printSelectInput("resourcetypeid", $resourcetypes["resources"], $resourcetypeid);
			else
				print "      $grouptype\n";
			print "    </TD>\n";
			print "    <TD></TD>\n";
			print "  </TR>\n";
		}
		print "  <TR>\n";
		print "    <TH align=right>Name:</TH>\n";
		print "    <TD><INPUT type=text name=name value=\"{$data['name']}\" ";
		print "maxlength=30>";
		if($data['type'] == 'user' && $selectAffil) {
			print "@";
			printSelectInput('affiliationid', $affils, $data['affiliationid']);
		}
		print "</TD>\n";
		print "    <TD>";
		printSubmitErr(GRPNAMEERR);
		print "</TD>\n";
		print "  </TR>\n";
		if($data["type"] == "user") {
			print "  <TR>\n";
			print "    <TH align=right>Owner:</TH>\n";
			print "    <TD><INPUT type=text name=owner value=\"" . $data["owner"];
			print "\"></TD>\n";
			print "    <TD>";
			printSubmitErr(GRPOWNER);
			print "</TD>\n";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>Editable by:</TH>\n";
			print "    <TD>\n";
			if(! empty($data['editgroupid']) &&
			   ! array_key_exists($data['editgroupid'], $affilusergroups)) {
				$affilusergroups[$data['editgroupid']] =
				      array('name' => getUserGroupName($data['editgroupid'], 1));
				uasort($affilusergroups, "sortKeepIndex");
			}
			printSelectInput("editgroupid", $affilusergroups, $data["editgroupid"]);
			print "    </TD>\n";
			print "    <TD></TD>";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>Initial Max Time (minutes):</TH>\n";
			print "    <TD><INPUT type=text name=initialmax value=\"";
			print $data["initialmax"] . "\" maxlength=4></TD>\n";
			print "    <TD>";
			printSubmitErr(INITIALMAXERR);
			print "</TD>\n";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>Total Max Time (minutes):</TH>\n";
			print "    <TD><INPUT type=text name=totalmax value=\"";
			print $data["totalmax"] . "\" maxlength=4></TD>\n";
			print "    <TD>";
			printSubmitErr(TOTALMAXERR);
			print "</TD>\n";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>Max Extend Time (minutes):</TH>\n";
			print "    <TD><INPUT type=text name=maxextend value=\"";
			print $data["maxextend"] . "\" maxlength=4></TD>\n";
			print "    <TD>";
			printSubmitErr(MAXEXTENDERR);
			print "</TD>\n";
			print "  </TR>\n";
			if($viewmode == ADMIN_DEVELOPER) {
				print "  <TR>\n";
				print "    <TH align=right>Max Overlapping Reservations:</TH>\n";
				print "    <TD><INPUT type=text name=overlap value=\"";
				print $data["overlap"] . "\" maxlength=4></TD>\n";
				print "    <TD>";
				printSubmitErr(MAXOVERLAPERR);
				print "</TD>\n";
				print "  </TR>\n";
			}
		}
		else {
			print "  <TR>\n";
			print "    <TH align=right>Owning User Group:</TH>\n";
			print "    <TD>\n";
			if(! array_key_exists($ownerid, $affilusergroups)) {
				$affilusergroups[$ownerid] = $usergroups[$ownerid];
				uasort($affilusergroups, "sortKeepIndex");
			}
			printSelectInput("ownergroup", $affilusergroups, $ownerid);
			print "    </TD>\n";
			print "    <TD></TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
		print "<TABLE>\n";
		print "  <TR valign=top>\n";
		print "    <TD>\n";
		if($state) {
			$cdata = array('type' => $data['type'],
			               'isowner' => $data['isowner']);
			$cont = addContinuationsEntry('submitAddGroup', $cdata);
			print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
			print "      <INPUT type=submit value=\"Add Group\">\n";
		}
		else {
			$cdata = array('type' => $data['type'],
			               'groupid' => $data['groupid'],
			               'isowner' => $data['isowner']);
			if($data['type'] == 'resource')
				$cdata['resourcetypeid'] = $resourcetypeid;
			else
				$cdata['selectAffil'] = $selectAffil;
			$cont = addContinuationsEntry('confirmEditGroup', $cdata);
			print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
			print "      <INPUT type=submit value=\"Confirm Changes\">\n";
		}
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "      <INPUT type=hidden name=mode value=viewGroups>\n";
		print "      <INPUT type=submit value=Cancel>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "  </TR>\n";
		print "</TABLE>\n";
	}

	if($data["type"] != "user")
		return;
	if($editusergroup) {
		print "<H3>Group Membership</H3>\n";
		if($mode == "addGroupUser" && ! ($submitErr & IDNAMEERR)) {
			print "<font color=\"#008000\">$newuser successfully added to group";
			print "</font><br><br>\n";
		}
		if($mode == "deleteGroupUser") {
			print "<font color=\"#008000\">$newuser successfully deleted from ";
			print "group</font><br><br>\n";
		}
		$groupmembers = getUserGroupMembers($data["groupid"]);
		print "<TABLE border=1>\n";
		print "  <TR>\n";
		print "  <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "    <TD align=right><INPUT type=submit value=Add></TD>\n";
		print "    <TD><INPUT type=text name=newuser maxlength=80 size=40 ";
		if($submitErr & IDNAMEERR)
			print "value=\"$newuser\"></TD>\n";
		else 
			print "></TD>\n";
		if($submitErr) {
			print "    <TD>\n";
			printSubmitErr(IDNAMEERR);
			print "    </TD>\n";
		}
		$cont = addContinuationsEntry('addGroupUser', $data);
		print "  <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "  </FORM>\n";
		print "  </TR>\n";
		foreach($groupmembers as $id => $login) {
			print "  <TR>\n";
			print "    <TD>\n";
			print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
			print "      <INPUT type=submit value=Delete>\n";
			$data['userid'] = $id;
			$data['newuser'] = $login;
			$cont = addContinuationsEntry('deleteGroupUser', $data);
			print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
			print "      </FORM>\n";
			print "    </TD>\n";
			print "    <TD>$login</TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processGroupInput($checks)
///
/// \param $checks - (optional) 1 to perform validation, 0 not to
///
/// \return an array with the following indexes:\n
/// groupid, name, prettyname, platformid, osid
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processGroupInput($checks=1) {
	global $submitErr, $submitErrMsg, $user, $viewmode;
	$return = array();
	$return["groupid"] = getContinuationVar("groupid");
	$return["type"] = getContinuationVar("type");
	$return["name"] = getContinuationVar('name', processInputVar("name", ARG_STRING));
	$return["affiliationid"] = getContinuationVar('affiliationid', processInputVar("affiliationid", ARG_NUMERIC, $user['affiliationid']));
	$return["resourcetypeid"] = getContinuationVar('resourcetypeid', processInputVar("resourcetypeid", ARG_NUMERIC));
	$return["owner"] = getContinuationVar('owner', processInputVar("owner", ARG_STRING));
	$return["ownergroup"] = processInputVar("ownergroup", ARG_NUMERIC);
	$return["editgroupid"] = getContinuationVar('editgroupid', processInputVar("editgroupid", ARG_NUMERIC));
	$return["isowner"] = getContinuationVar("isowner");
	$return["initialmax"] = getContinuationVar('initialmax', processInputVar("initialmax", ARG_NUMERIC));
	$return["totalmax"] = getContinuationVar('totalmax', processInputVar("totalmax", ARG_NUMERIC));
	$return["maxextend"] = getContinuationVar('maxextend', processInputVar("maxextend", ARG_NUMERIC));
	$return["overlap"] = getContinuationVar('overlap', processInputVar("overlap", ARG_NUMERIC, 0));

	$affils = getAffiliations();
	if(! array_key_exists($return['affiliationid'], $affils))
		$return['affiliationid'] = $user['affiliationid'];

	if(! $checks) {
		return $return;
	}
	
	if(! ereg('^[-a-zA-Z0-9_\.: ]{3,30}$', $return["name"])) {
	   $submitErr |= GRPNAMEERR;
	   $submitErrMsg[GRPNAMEERR] = "Name must be between 3 and 30 characters "
		                       . "and can only contain letters, numbers, and "
		                       . "these characters: - _ . :";
	}
	if($return['type'] == 'user')
		$extraid = $return['affiliationid'];
	else
		$extraid = $return['resourcetypeid'];
	if(! empty($return["type"]) && ! empty($return["name"]) && 
	   ! ($submitErr & GRPNAMEERR) && 
	   checkForGroupName($return["name"], $return["type"], $return["groupid"],
		                  $extraid)) {
	   $submitErr |= GRPNAMEERR;
	   $submitErrMsg[GRPNAMEERR] = "A group already exists with this name.";
	}
	if($return["type"] == "user" && ! validateUserid($return["owner"])) {
		$submitErr |= GRPOWNER;
	   $submitErrMsg[GRPOWNER] = "Submitted ID is not valid";
	}
	if($return["type"] == "user" && $return["initialmax"] < 30) {
		$submitErr |= INITIALMAXERR;
		$submitErrMsg[INITIALMAXERR] = "Initial max time must be at least 30 "
		                             . "minutes";
	}
	if($return["type"] == "user" && $return["totalmax"] < 30) {
		$submitErr |= TOTALMAXERR;
		$submitErrMsg[TOTALMAXERR] = "Total max time must be at least 30 "
		                           . "minutes";
	}
	if($return["type"] == "user" && $return["maxextend"] < 15) {
		$submitErr |= MAXEXTENDERR;
		$submitErrMsg[MAXEXTENDERR] = "Max extend time must be at least 15 "
		                            . "minutes";
	}
	if($viewmode == ADMIN_DEVELOPER &&
	   $return["type"] == "user" &&
	   ($return["overlap"] < 0 ||
	   $return["overlap"] == 1)) {
		$submitErr |= MAXOVERLAPERR;
		$submitErrMsg[MAXOVERLAPERR] = "Overlap can be 0 or greater than or equal to 2";
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForGroupName($name, $type, $id, $extraid)
///
/// \param $name - the name of a group
/// \param $type - user or resource
/// \param $id - id of a group to ignore
/// \param $extraid - if $type is resource, this is a resource type id; if
///                   $type is user, this is an affiliation id
///
/// \return 1 if $name is already in the associated table, 0 if not
///
/// \brief checks for $name being in usergroup/resource group (based on $type)
/// except for $id
///
////////////////////////////////////////////////////////////////////////////////
function checkForGroupName($name, $type, $id, $extraid) {
	if($type == "user")
		$query = "SELECT id FROM usergroup "
		       . "WHERE name = '$name' AND "
		       .       "affiliationid = $extraid";
	else
		$query = "SELECT id FROM resourcegroup "
		       . "WHERE name = '$name' AND "
		       .       "resourcetypeid = $extraid";
	if(! empty($id))
		$query .= " AND id != $id";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateGroup($data)
///
/// \param $data - an array returned from processGroupInput
///
/// \return number of rows affected by the update\n
/// \b NOTE: mysql reports that no rows were affected if none of the fields
/// were actually changed even if the update matched a row
///
/// \brief performs a query to update the group with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function updateGroup($data) {
	global $viewmode;
	if($data["type"] == "user") {
		$ownerid = getUserlistID($data["owner"]);
		$query = "UPDATE usergroup "
		       . "SET name = '{$data["name"]}', "
		       .     "affiliationid = {$data['affiliationid']}, "
		       .     "ownerid = $ownerid, "
		       .     "editusergroupid = {$data["editgroupid"]}, "
		       .     "initialmaxtime = {$data["initialmax"]}, "
		       .     "totalmaxtime = {$data["totalmax"]}, ";
		if($viewmode == ADMIN_DEVELOPER)
			$query .= "overlapResCount = {$data["overlap"]}, ";
		$query .=    "maxextendtime = {$data["maxextend"]} "
		       . "WHERE id = {$data["groupid"]}";
	}
	else {
		$query = "UPDATE resourcegroup "
		       . "SET name = '{$data["name"]}', "
		       .     "ownerusergroupid = {$data["ownergroup"]} "
		       . "WHERE id = {$data["groupid"]}";
	}
	$qh = doQuery($query, 300);
	return mysql_affected_rows($GLOBALS["mysql_link_vcl"]);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addGroup($data)
///
/// \param $data - an array returned from processGroupInput
///
/// \return number of rows affected by the insert\n
///
/// \brief performs a query to insert the group with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function addGroup($data) {
	global $viewmode;
	if($data["type"] == "user") {
		$ownerid = getUserlistID($data["owner"]);
		$query = "INSERT INTO usergroup "
				 .         "(name, "
				 .         "affiliationid, "
				 .         "ownerid, "
				 .         "editusergroupid, "
		       .         "custom, "
		       .         "initialmaxtime, "
		       .         "totalmaxtime, ";
		if($viewmode == ADMIN_DEVELOPER)
			$query .=     "overlapResCount, ";
		$query .=        "maxextendtime) "
				 . "VALUES ('{$data["name"]}', "
				 .        "{$data["affiliationid"]}, "
				 .        "$ownerid, "
				 .        "{$data["editgroupid"]}, "
		       .        "1, "
		       .        "{$data["initialmax"]}, "
		       .        "{$data["totalmax"]}, ";
		if($viewmode == ADMIN_DEVELOPER)
			$query .=    "{$data["overlap"]}, ";
		$query .=       "{$data["maxextend"]})";
	}
	else {
		$query = "INSERT INTO resourcegroup "
				 .         "(name, "
				 .         "ownerusergroupid, "
		       .         "resourcetypeid) "
				 . "VALUES ('" . $data["name"] . "', "
		       .         $data["ownergroup"] . ", "
		       .         "'" . $data["resourcetypeid"] . "')";
	}
	$qh = doQuery($query, 305);
	clearPrivCache();
	return mysql_affected_rows($GLOBALS["mysql_link_vcl"]);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForGroupUsage($groupid, $type)
///
/// \param $groupid - id of an group
/// \param $type - group type: "user" or "resource"
///
/// \return 0 if group is not used, 1 if it is
///
/// \brief checks for $groupid being in the priv table corresponding to $type
///
////////////////////////////////////////////////////////////////////////////////
function checkForGroupUsage($groupid, $type) {
	if($type == "user")
		$query = "SELECT id FROM userpriv WHERE usergroupid = $groupid";
	else
		$query = "SELECT id FROM resourcepriv WHERE resourcegroupid = $groupid";
	$qh = doQuery($query, 310);
	if(mysql_num_rows($qh)) {
		return 1;
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmEditOrAddGroup($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a form for confirming changes to an group
///
////////////////////////////////////////////////////////////////////////////////
function confirmEditOrAddGroup($state) {
	global $submitErr, $user, $viewmode;

	$data = processGroupInput(1);

	if($submitErr) {
		editOrAddGroup($state);
		return;
	}

	$resourcetypes = getTypes("resources");
	$usergroups = getUserGroups(1);
	$affils = getAffiliations();

	if($state) {
		if($data["type"] == "user") {
			$title = "Add User Group";
			$question = "Add the following user group?";
			$target = "";
		}
		else {
			$title = "Add Resource Group";
			$question = "Add the following resource group?";
			$target = "#resources";
		}
		$nextmode = "submitAddGroup";
	}
	else {
		if($data["type"] == "user") {
			$title = "Edit User Group";
			$question = "Submit changes to the user group?";
			$target = "";
		}
		else {
			$title = "Edit Resource Group";
			$question = "Submit changes to the resource group?";
			$target = "#resources";
		}
		$nextmode = "submitEditGroup";
	}

	print "<DIV align=center>\n";
	print "<H2>$title</H2>\n";
	print "$question<br><br>\n";
	print "<TABLE>\n";
	if($data["type"] == "resource") {
		print "  <TR>\n";
		print "    <TH align=right>Type:</TH>\n";
		print "    <TD>" . $resourcetypes["resources"][$data["resourcetypeid"]];
		print "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Name:</TH>\n";
	if($data['type'] == 'user' && ($user['showallgroups'] ||
	   $data['affiliationid'] != $user['affiliationid']))
		print "    <TD>{$data["name"]}@{$affils[$data['affiliationid']]}</TD>\n";
	else
		print "    <TD>{$data["name"]}</TD>\n";
	print "  </TR>\n";
	if($data["type"] == "user") {
		print "  <TR>\n";
		print "    <TH align=right>Owner:</TH>\n";
		print "    <TD>" . $data["owner"] . "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Editable by:</TH>\n";
		if(! $user['showallgroups']) {
			$tmp = explode('@', $usergroups[$data["editgroupid"]]["name"]);
			if($tmp[1] == $user['affiliation'])
				$usergroups[$data["editgroupid"]]["name"] = $tmp[0];
		}
		print "    <TD>" . $usergroups[$data["editgroupid"]]["name"] . "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Initial Max Time (minutes):</TH>\n";
		print "    <TD>{$data["initialmax"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n"; print "    <TH align=right>Total Max Time (minutes):</TH>\n";
		print "    <TD>{$data["totalmax"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Max Extend Time (minutes):</TH>\n";
		print "    <TD>{$data["maxextend"]}</TD>\n";
		print "  </TR>\n";
		if($viewmode == ADMIN_DEVELOPER) {
			print "  <TR>\n";
			print "    <TH align=right>Max Overlapping Reservations:</TH>\n";
			print "    <TD>{$data["overlap"]}</TD>\n";
			print "  </TR>\n";
		}
	}
	else {
		print "  <TR>\n";
		print "    <TH align=right>Owning User Group:</TH>\n";
		if(! $user['showallgroups'] &&
		   preg_match("/^(.+)@{$user['affiliation']}$/",
			           $usergroups[$data['ownergroup']]['name'], $matches))
			print "    <TD>{$matches[1]}";
		else
			print "    <TD>" . $usergroups[$data["ownergroup"]]["name"];
		print "</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "$target\" method=post>\n";
	$cont = addContinuationsEntry($nextmode, $data, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=viewGroups>\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditGroup()
///
/// \brief submits changes to group and notifies user
///
////////////////////////////////////////////////////////////////////////////////
function submitEditGroup() {
	$data = getContinuationVar();
	updateGroup($data);
	$_SESSION['userresources'] = array();
	$_SESSION['nodeprivileges'] = array();
	#$_SESSION['cascadenodeprivileges'] = array(); // might need this uncommented
	viewGroups();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddGroup()
///
/// \brief adds the group and notifies user
///
////////////////////////////////////////////////////////////////////////////////
function submitAddGroup() {
	global $submitErr;
	$data = processGroupInput(1);
	if($submitErr) {
		editOrAddGroup(1);
		return;
	}
	if(! addGroup($data))
		abort(10);
	viewGroups();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteGroup()
///
/// \brief prints a form to confirm the deletion of an group
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteGroup() {
	$groupid = getContinuationVar("groupid");
	$type = getContinuationVar("type");

	$usergroups = getUserGroups(1);
	$resourcegroups = getResourceGroups();

	if($type == "user") {
		$title = "Delete User Group";
		$question = "Delete the following user group?";
		$name = $usergroups[$groupid]["name"];
		$target = "";
	}
	else {
		$title = "Delete Resource Group";
		$question = "Delete the following resource group?";
		list($resourcetype, $name) = 
			split('/', $resourcegroups[$groupid]["name"]);
		$target = "#resources";
	}

	if(checkForGroupUsage($groupid, $type)) {
		print "<H2 align=center>$title</H2>\n";
		print "This group is currently assigned to at least one node in the ";
		print "privilege tree.  You cannot delete it until it is no longer ";
		print "in use.";
		return;
	}

	print "<DIV align=center>\n";
	print "<H2>$title</H2>\n";
	print "$question<br><br>\n";
	print "<TABLE>\n";
	if($type == "resource") {
		print "  <TR>\n";
		print "    <TH align=right>Type:</TH>\n";
		print "    <TD>$resourcetype</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Name:</TH>\n";
	print "    <TD>$name</TD>\n";
	print "  </TR>\n";
	if($type == "resource") {
		print "  <TR>\n";
		print "    <TH align=right>Owning User Group:</TH>\n";
		print "    <TD>" . $resourcegroups[$groupid]["owner"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "$target\" method=post>\n";
	$cdata = array('groupid' => $groupid,
	               'type' => $type);
	$cont = addContinuationsEntry('submitDeleteGroup', $cdata);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=viewGroups>\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteGroup()
///
/// \brief deletes an group from the database and notifies the user
///
////////////////////////////////////////////////////////////////////////////////
function submitDeleteGroup() {
	$groupid = getContinuationVar("groupid");
	$type = getContinuationVar("type");
	if($type == "user")
		$table = "usergroup";
	else
		$table = "resourcegroup";
	$query = "DELETE FROM $table "
			 . "WHERE id = $groupid";
	doQuery($query, 315);
	clearPrivCache();
	viewGroups();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addGroupUser()
///
/// \brief adds a user to a group
///
////////////////////////////////////////////////////////////////////////////////
function addGroupUser() {
	global $submitErr, $submitErrMsg;
	$groupid = getContinuationVar("groupid");
	$newuser = processInputVar("newuser", ARG_STRING);
	if(! validateUserid($newuser)) {
		$submitErr |= IDNAMEERR;
		$submitErrMsg[IDNAMEERR] = "Invalid login ID";
		editOrAddGroup(0);
		return;
	}
	addUserGroupMember($newuser, $groupid);
	editOrAddGroup(0);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deleteGroupUser()
///
/// \brief deletes a user from a group
///
////////////////////////////////////////////////////////////////////////////////
function deleteGroupUser() {
	$groupid = getContinuationVar("groupid");
	$userid = getContinuationVar("userid");
	$test = getUserUnityID($userid);
	if(! empty($test))
		deleteUserGroupMember($userid, $groupid);
	editOrAddGroup(0);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonGetGroupInfo()
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function jsonGetGroupInfo() {
	$groupid = processInputVar('groupid', ARG_NUMERIC);
	$mousex = processInputVar('mousex', ARG_NUMERIC);
	$mousey = processInputVar('mousey', ARG_NUMERIC);
	$userresources = getUserResources(array("groupAdmin"), 
	                                  array("manageGroup"), 1);
	$found = 0;
	foreach(array_keys($userresources) as $type) {
		if(array_key_exists($groupid, $userresources[$type])) {
			$found = 1;
			break;
		}
	}
	if(! $found || $mousex < 0 || $mousex > 5000 || $mousey < 0 || $mousey > 500000) {
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode(array()) . '}*/';
		return;
	}
	$members = getResourceGroupMembers($type);
	$data = array();
	if(! empty($members[$type][$groupid])) {
		uasort($members[$type][$groupid], "sortKeepIndex");
		foreach($members[$type][$groupid] as $mem) {
			$data[] = $mem['name'];
		}
	}
	else
		$data[] = '(empty group)';
	$arr = array('members' => $data, 'x' => $mousex, 'y' => $mousey);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

?>
