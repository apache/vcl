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
/// signifies an error with the submitted editing user group
define("EDITGROUPERR", 1 << 7);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewGroups()
///
/// \brief prints a page to view group information
///
////////////////////////////////////////////////////////////////////////////////
function viewGroups() {
	global $user, $mode;
	$modetype = getContinuationVar("type");

	print "<H2>User Groups</H2>\n";
	if($modetype == "user") {
		if($mode == "submitAddGroup") {
			print "<font color=\"#008000\">User group successfully added";
			print "</font><br><br>\n";
		}
		elseif($mode == "submitEditGroup") {
			print "<font color=\"#008000\">User group successfully updated";
			print "</font><br><br>\n";
		}
	}
	$showusergrouptype = 0;
	if(checkUserHasPerm('Manage Federated User Groups (global)') ||
	   checkUserHasPerm('Manage Federated User Groups (affiliation only)'))
		$showusergrouptype = 1;
	$cdata = array('type' => 'user');
	$cont = addContinuationsEntry('addGroup', $cdata);
	print "<form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<button type=\"submit\" dojoType=\"dijit.form.Button\">\n";
	print "  Add New User Group\n";
	print "</button>\n";
	print "<input type=\"hidden\" name=\"continuation\" value=\"$cont\">\n";
	print "</form><br>\n";

	print "<div id=\"usergroupcontainer\">\n";

	# hidden elements
	$cont = addContinuationsEntry('editGroup', $cdata);
	print "<input type=\"hidden\" id=\"editgroupcont\" value=\"$cont\">\n";
	$cont = addContinuationsEntry('AJconfirmDeleteGroup', $cdata);
	print "<input type=\"hidden\" id=\"deletegroupcont\" value=\"$cont\">\n";
	$cont = addContinuationsEntry('jsonUserGroupStore');
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" url=\"" . BASEURL;
	print SCRIPT . "?continuation=$cont\" jsid=\"usergroupstore\" ";
	print "comparatorMap=\"\{\}\"></div>\n";
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\"\n";
	print "data=\"{'identifier':'id', 'label':'name', 'items':[]}\" \n";
	print "jsid=\"affiliationstore\"></div>\n";
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\"\n";
	print "data=\"{'identifier':'id', 'label':'name', 'items':[]}\" \n";
	print "jsid=\"ownerstore\"></div>\n";
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\"\n";
	print "data=\"{'identifier':'id', 'label':'name', 'items':[]}\" \n";
	print "jsid=\"editgroupstore\"></div>\n";

	# filters
	print "<div dojoType=\"dijit.TitlePane\" title=\"Filters (click to expand)\" ";
	print "open=\"false\">\n";
	print "<strong>Name</strong>:\n";
	print "<div dojoType=\"dijit.form.TextBox\" id=\"namefilter\" length=\"40\">";
	print "  <script type=\"dojo/connect\" event=\"onKeyUp\" args=\"event\">\n";
	print "    if(event.keyCode == 13) usergroupGridFilter();\n";
	print "  </script>\n";
	print "</div>\n";
	print "<button dojoType=\"dijit.form.Button\">\n";
	print "  Apply Name Filter\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    usergroupGridFilter();\n";
	print "  </script>\n";
	print "</button><br>\n";
	print "<strong>Affiliation</strong>:\n";
	print "<select dojoType=\"dijit.form.Select\" id=\"affiliationfilter\" ";
	print "onChange=\"usergroupGridFilter();\" maxHeight=\"250\"></select><br>\n";
	print "<strong>Owner</strong>:\n";
	print "<select dojoType=\"dijit.form.Select\" id=\"ownerfilter\" ";
	print "onChange=\"usergroupGridFilter();\" maxHeight=\"250\"></select><br>\n";
	if($showusergrouptype) {
		print "<strong>Type</strong>:\n";
		print "<label for=\"shownormal\">Normal</label>\n";
		print "<input type=\"checkbox\" dojoType=\"dijit.form.CheckBox\" ";
		print "id=\"shownormal\" onChange=\"usergroupGridFilter();\" ";
		print "checked=\"checked\"> | \n";
		print "<label for=\"showfederated\">Federated</label>\n";
		print "<input type=\"checkbox\" dojoType=\"dijit.form.CheckBox\" ";
		print "id=\"showfederated\" onChange=\"usergroupGridFilter();\" ";
		print "checked=\"checked\"> | \n";
		print "<label for=\"showcourseroll\">Course Roll</label>\n";
		print "<input type=\"checkbox\" dojoType=\"dijit.form.CheckBox\" ";
		print "id=\"showcourseroll\" onChange=\"usergroupGridFilter();\" ";
		print "checked=\"checked\"><br>\n";
	}
	print "<strong>Editable by</strong>:\n";
	print "<select dojoType=\"dijit.form.Select\" id=\"editgroupfilter\" ";
	print "onChange=\"usergroupGridFilter();\" maxHeight=\"250\"></select><br>\n";
	print "</div>\n";

	print "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"usergroupgrid\" ";
	print "sortInfo=3 store=\"usergroupstore\" autoWidth=\"true\" style=\"";
	print "height: 580px;\" query=\"{type: new RegExp('normal|federated|courseroll')}\">\n";
	print "<thead>\n";
	print "<tr>\n";
	if(preg_match('/MSIE/i', $_SERVER['HTTP_USER_AGENT']) ||
	   preg_match('/Trident/i', $_SERVER['HTTP_USER_AGENT']) ||
	   preg_match('/Edge/i', $_SERVER['HTTP_USER_AGENT']))
		$w = array('54px', '43px', '200px', '142px', '65px', '142px', '59px', '58px', '63px', '73px');
	else
		$w = array('4.8em', '3.5em', '17em', '12em', '5em', '12em', '5em', '5em', '5.6em', '6.3em');
	print "<th field=\"id\" width=\"{$w[0]}\" formatter=\"fmtUserGroupDeleteBtn\">&nbsp;</th>\n";
	print "<th field=\"id\" width=\"{$w[1]}\" formatter=\"fmtUserGroupEditBtn\">&nbsp;</th>\n";
	print "<th field=\"name\" width=\"{$w[2]}\">Name</th>\n";
	print "<th field=\"owner\" width=\"{$w[3]}\">Owner</th>\n";
	if($showusergrouptype)
		print "<th field=\"prettytype\" width=\"{$w[4]}\">Type</th>\n";
	print "<th field=\"editgroup\" width=\"{$w[5]}\">Editable by</th>\n";
	print "<th field=\"initialmaxtime\" width=\"{$w[6]}\" formatter=\"fmtDuration\">Initial Max<br>Time</th>\n";
	print "<th field=\"totalmaxtime\" width=\"{$w[7]}\" formatter=\"fmtDuration\">Total Max<br>Time</th>\n";
	print "<th field=\"maxextendtime\" width=\"{$w[8]}\" formatter=\"fmtDuration\">Max Extend<br>Time</th>\n";
	if(checkUserHasPerm('Set Overlapping Reservation Count'))
		print "<th field=\"overlapResCount\" width=\"{$w[9]}\">Max<br>Overlapping<br>Reservations</th>\n";
	print "</tr>\n";
	print "</thead>\n";
	print "</table>\n";
	print "</div>\n";

	print "<a name=resources></a>\n";
	print "<H2>Resource Groups</H2>\n";
	if($modetype == "resource") {
		if($mode == "submitAddGroup") {
			print "<font color=\"#008000\">Resource group successfully added";
			print "</font><br><br>\n";
		}
		elseif($mode == "submitEditGroup") {
			print "<font color=\"#008000\">Resource group successfully updated";
			print "</font><br><br>\n";
		}
	}

	$showaddresource = 0;
	$usergroups = getUserGroups(1);
	foreach(array_keys($usergroups) as $id) {
		if($usergroups[$id]["ownerid"] == $user["id"]) {
			$showaddresource = 1;
			break;
		}
		if(array_key_exists("editgroupid", $usergroups[$id]) &&
		   array_key_exists($usergroups[$id]["editgroupid"], $user["groups"])) {
			$showaddresource = 1;
			break;
		}
	}

	$cdata = array('type' => 'resource');

	if($showaddresource) {
		$cont = addContinuationsEntry('addGroup', $cdata);
		print "<form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "<button type=\"submit\" dojoType=\"dijit.form.Button\">\n";
		print "  Add New Resource Group\n";
		print "</button>\n";
		print "<input type=\"hidden\" name=\"continuation\" value=\"$cont\">\n";
		print "</form><br>\n";
	}

	print "<div id=\"resourcegroupcontainer\">\n";

	# hidden elements
	$cont = addContinuationsEntry('editGroup', $cdata);
	print "<input type=\"hidden\" id=\"editresgroupcont\" value=\"$cont\">\n";
	$cont = addContinuationsEntry('AJconfirmDeleteGroup', $cdata);
	print "<input type=\"hidden\" id=\"deleteresgroupcont\" value=\"$cont\">\n";
	$jscont = addContinuationsEntry('jsonGetGroupInfo');
	print "<input type=\"hidden\" id=\"jsongroupinfocont\" value=\"$jscont\">\n";
	$cont = addContinuationsEntry('jsonResourceGroupStore');
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" url=\"" . BASEURL;
	print SCRIPT . "?continuation=$cont\" jsid=\"resourcegroupstore\"></div>\n";
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\"\n";
	print "data=\"{'identifier':'id', 'label':'name', 'items':[]}\" \n";
	print "jsid=\"owninggroupstore\"></div>\n";

	# filters
	print "<div dojoType=\"dijit.TitlePane\" title=\"Filters (click to expand)\" ";
	print "open=\"false\">\n";
	print "<strong>Name</strong>:\n";
	print "<div dojoType=\"dijit.form.TextBox\" id=\"resnamefilter\" length=\"40\">";
	print "  <script type=\"dojo/connect\" event=\"onKeyUp\" args=\"event\">\n";
	print "    if(event.keyCode == 13) resourcegroupGridFilter();\n";
	print "  </script>\n";
	print "</div>\n";
	print "<button dojoType=\"dijit.form.Button\">\n";
	print "  Apply Name Filter\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    resourcegroupGridFilter();\n";
	print "  </script>\n";
	print "</button><br>\n";
	$resourcetypes = getTypes("resources");
	print "<strong>Type</strong>:\n";
	print "<span id=\"resourcetypes\">\n";
	$first = 1;
	foreach($resourcetypes['resources'] as $type) {
		if($first)
			$first = 0;
		else
			print ' | ';
		print "<label for=\"show$type\">$type</label>\n";
		print "<input type=\"checkbox\" dojoType=\"dijit.form.CheckBox\" ";
		print "id=\"show$type\" onChange=\"resourcegroupGridFilter();\" ";
		print "checked=\"checked\">\n";
	}
	print "</span>\n";
	print "<br>\n";
	print "<strong>Owning User Group</strong>:\n";
	print "<select dojoType=\"dijit.form.Select\" id=\"owninggroupfilter\" ";
	print "onChange=\"resourcegroupGridFilter();\" maxHeight=\"250\"></select><br>\n";
	print "</div>\n";

	print "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"resourcegroupgrid\" ";
	print "sortInfo=3 store=\"resourcegroupstore\" autoWidth=\"true\" style=\"";
	print "height: 580px;\" query=\"{type: new RegExp('.*')}\">\n";
	print "<thead>\n";
	print "<tr>\n";
	if(preg_match('/MSIE/i', $_SERVER['HTTP_USER_AGENT']) ||
	   preg_match('/Trident/i', $_SERVER['HTTP_USER_AGENT']) ||
	   preg_match('/Edge/i', $_SERVER['HTTP_USER_AGENT']))
		$w = array('54px', '43px', '108px', '240px', '250px', '24px');
	else
		$w = array('4.5em', '3.5em', '9em', '20em', '21em', '1.6em');

	print "<th field=\"id\" width=\"{$w[0]}\" formatter=\"fmtResourceGroupDeleteBtn\">&nbsp;</th>\n";
	print "<th field=\"id\" width=\"{$w[1]}\" formatter=\"fmtResourceGroupEditBtn\">&nbsp;</th>\n";
	print "<th field=\"type\" width=\"{$w[2]}\">Type</th>\n";
	print "<th field=\"name\" width=\"{$w[3]}\">Name</th>\n";
	print "<th field=\"owninggroup\" width=\"{$w[4]}\">Owning User Group</th>\n";
	print "<th field=\"id\" width=\"{$w[5]}\" formatter=\"fmtGroupInfo\">\n";
	print "<a onmouseover=\"mouseoverHelp();\" ";
	print "onmouseout=\"showGroupInfoCancel(0);\" id=\"listicon0\">\n";
	print "<img alt=\"\" src=\"images/list.gif\"></a></th>\n";
	print "</tr>\n";
	print "</thead>\n";
	print "</table>\n";
	print "</div>\n";

	print "<div id=\"confirmDeleteDialog\" dojoType=\"dijit.Dialog\">\n";
	print "<h2 id=\"confirmDeleteHeading\"></h2>\n";
	print "<div id=\"confirmDeleteQuestion\"></div><br>\n";
	print "<div id=\"confdelcontent\"></div><br>\n";
	print dijitButton('deleteBtn', i("Delete Group"), "submitDeleteGroup();");
	print dijitButton('', i("Cancel"), "clearHideConfirmDelete();");
	print "<input type=hidden id=\"submitdeletecont\">\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonUserGroupStore()
///
/// \brief generates json data for populating user group datagrid
///
////////////////////////////////////////////////////////////////////////////////
function jsonUserGroupStore() {
	global $user;
	$usergroups = getUserGroups();
	if($user['showallgroups'])
		$affilusergroups = $usergroups;
	else
		$affilusergroups = getUserGroups(0, $user['affiliationid']);

	$showfederatedall = 0;
	$showfederatedaffil = 0;
	if(checkUserHasPerm('Manage Federated User Groups (global)'))
		$showfederatedall = 1;
	elseif(checkUserHasPerm('Manage Federated User Groups (affiliation only)'))
		$showfederatedaffil = 1;
	$items = array();
	$lengths = getReservationLengths(201600);
	foreach($affilusergroups as $id => $group) {
		if($group['name'] == 'None' || preg_match('/^\s*None/', $group['name']))
			continue;
		$owner = 0;
		$editor = 0;
		if($group["ownerid"] == $user["id"])
			$owner = 1;
		if(array_key_exists("editgroupid", $group) &&
		   array_key_exists($group["editgroupid"], $user["groups"]))
			$editor = 1;
		if($showfederatedall && ($group['custom'] == 0 ||
		   $group['courseroll'] == 1))
			$owner = 1;
		elseif($showfederatedaffil && ($group['custom'] == 0 ||
		   $group['courseroll'] == 1) && 
		   $group['groupaffiliationid'] == $user['affiliationid'])
			$owner = 1;
		if(! $owner && ! $editor)
			continue;
		if(! array_key_exists($group['initialmaxtime'], $lengths))
			$group['initialmaxtime'] = getReservationLengthCeiling($group['initialmaxtime']);
		if(! array_key_exists($group['totalmaxtime'], $lengths))
			$group['totalmaxtime'] = getReservationLengthCeiling($group['totalmaxtime']);
		if(! array_key_exists($group['maxextendtime'], $lengths))
			$group['maxextendtime'] = getReservationLengthCeiling($group['maxextendtime']);
		$g = array('id' => $id,
		           'name' => $group['name'],
		           'owner' => $group['owner'],
		           'editgroup' => $group['editgroup'],
		           'editgroupid' => $group['editgroupid'],
		           'groupaffiliation' => $group['groupaffiliation'],
		           'groupaffiliationid' => $group['groupaffiliationid'],
		           'initialmaxtime' => intval($group['initialmaxtime']),
		           'initialmaxtimedisp' => $lengths[$group['initialmaxtime']],
		           'totalmaxtime' => intval($group['totalmaxtime']),
		           'totalmaxtimedisp' => $lengths[$group['totalmaxtime']],
		           'maxextendtime' => intval($group['maxextendtime']),
		           'maxextendtimedisp' => $lengths[$group['maxextendtime']],
		           'overlapResCount' => intval($group['overlapResCount']));
		if($group['courseroll']) {
			$g['type'] = 'courseroll';
			$g['prettytype'] = 'Course Roll';
			$g['owner'] = 'N/A';
			$g['editgroup'] = 'None';
			$g['editgroupid'] = 'NULL';
		}
		elseif($group['custom'] == 0) {
			$g['type'] = 'federated';
			$g['prettytype'] = 'Federated';
			$g['owner'] = 'N/A';
			$g['editgroup'] = 'None';
			$g['editgroupid'] = 'NULL';
		}
		else {
			$g['type'] = 'normal';
			$g['prettytype'] = 'Normal';
			$g['editgroup'] = "{$group['editgroup']}@{$group['editgroupaffiliation']}";
		}
		if($owner)
			$g['deletable'] = 1;
		else
			$g['deletable'] = 0;
		$items[] = $g;
	}
	sendJSON($items, 'id');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonResourceGroupStore()
///
/// \brief generates json data for populating resource group datagrid
///
////////////////////////////////////////////////////////////////////////////////
function jsonResourceGroupStore() {
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
				$resources[$id]["ownerid"] = $resourcegroups[$id]["ownerid"];
			}
		}
	}

	$items = array();
	foreach(array_keys($resources) as $id) {
		$g = array('id' => $id,
		           'type' => $resources[$id]['type'],
		           'name' => $resources[$id]['name'],
		           'owninggroup' => $resourcegroups[$id]['owner'],
		           'owninggroupid' => $resourcegroups[$id]['ownerid']);
		$items[] = $g;
	}
	sendJSON($items, 'id');
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
	global $submitErr, $user, $mode;

	$usergroups = getUserGroups();

	$type = getContinuationVar("type");
	if($state)
		$isowner = 1;
	elseif($type == 'resource') {
		$isowner = getContinuationVar('isowner');
	}
	if(! $state) {
		$groupid = getContinuationVar('groupid', processInputVar('groupid', ARG_NUMERIC));
		if($type == 'user') {
			if(! array_key_exists($groupid, $usergroups)) {
				print "<h2>Edit User Group</h2>\n";
				print "The selected user group does not exist.\n";
				return;
			}
			$isowner = 0;
			if($usergroups[$groupid]['ownerid'] != $user['id']) {
				if(($usergroups[$groupid]['custom'] == 0 ||
					$usergroups[$groupid]['courseroll'] == 1)) {
					if(! checkUserHasPerm('Manage Federated User Groups (global)') &&
						(! checkUserHasPerm('Manage Federated User Groups (affiliation only)') ||
						$usergroups[$groupid]['groupaffiliationid'] != $user['affiliationid'])) {
						print "<h2>Edit User Group</h2>\n";
						print "You do not have access to modify the selected user group.\n";
						return;
					}
					else
						$isowner = 1;
				}
				elseif(! array_key_exists("editgroupid", $usergroups[$groupid]) ||
					! array_key_exists($usergroups[$groupid]["editgroupid"], $user["groups"])) {
					print "<h2>Edit User Group</h2>\n";
					print "You do not have access to modify the selected user group.\n";
					return;
				}
			}
			else
				$isowner = 1;
		}
		else {
			$userresources = getUserResources(array("groupAdmin"), 
			                                  array("manageGroup"), 1);
			$noaccess = 1;
			foreach(array_keys($userresources) as $rtype) {
				if(array_key_exists($groupid, $userresources[$rtype])) {
					$noaccess = 0;
					break;
				}
			}
			if($noaccess) {
				print "<h2>Edit Resource Group</h2>\n";
				print "You do not have access to modify the selected resource group.\n";
				return;
			}
		}
	}

	$allcustomgroups = getUserGroups(1);
	if($user['showallgroups'])
		$affilusergroups = $allcustomgroups;
	else
		$affilusergroups = getUserGroups(1, $user['affiliationid']);
	$defaultusergroupid = getUserGroupID('Default for Editable by', 1);

	if($type == 'resource') {
		$dispUserGrpIDs = array();
		$dispUserGrpIDsAllAffils = array();
		foreach(array_keys($allcustomgroups) as $id) {
			# figure out if user is owner or in editor group
			$owner = 0;
			$editor = 0;
			if($allcustomgroups[$id]["ownerid"] == $user["id"])
				$owner = 1;
			if(array_key_exists("editgroupid", $allcustomgroups[$id]) &&
				array_key_exists($allcustomgroups[$id]["editgroupid"], $user["groups"]))
				$editor = 1;
			if(! $owner && ! $editor)
				continue;
			if($user['showallgroups'])
				$dispUserGrpIDs[$id] = $allcustomgroups[$id]['name'];
			elseif(array_key_exists($id, $affilusergroups) &&
			   $allcustomgroups[$id]['groupaffiliation'] == $user['affiliation'])
				$dispUserGrpIDs[$id] = $allcustomgroups[$id]['name'];
			$dispUserGrpIDsAllAffils[$id] = $allcustomgroups[$id]['name'];
		}
	}

	$resourcegroups = getResourceGroups();
	$affils = getAffiliations();
	$resourcetypes = getTypes("resources");

	if($submitErr) {
		$data = processGroupInput(0);
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
		$data["groupid"] = getContinuationVar("groupid");
		$data["type"] = getContinuationVar("type");
		$data["isowner"] = $isowner;
		if(! $state) {
			$id = $groupid;
			$data['groupid'] = $id;
		}
		else
			$id = $data["groupid"];
		if($data["type"] == "user") {
			if($state) {
				$data["name"] = '';
				$data["affiliationid"] = $user['affiliationid'];
				$data["owner"] = "{$user['unityid']}@{$user['affiliation']}";
				if(array_key_exists('VCLEDITGROUPID', $_COOKIE) &&
				   (array_key_exists($_COOKIE['VCLEDITGROUPID'], $affilusergroups) ||
				   $_COOKIE['VCLEDITGROUPID'] == $defaultusergroupid))
					$data["editgroupid"] = $_COOKIE['VCLEDITGROUPID'];
				else
					$data["editgroupid"] = $defaultusergroupid;
				if(! array_key_exists($data['editgroupid'], $affilusergroups)) {
					if($user['showallgroups']) {
						$affil = getAffiliationName(1);
						$affilusergroups[$data['editgroupid']]['name'] = "Default for Editable by@$affil";
					}
					else
						$affilusergroups[$data['editgroupid']]['name'] = 'Default for Editable by';
				}

				$data["initialmax"] = 240;
				$data["totalmax"] = 360;
				$data["maxextend"] = 30;
				$data["overlap"] = 0;
				$data["custom"] = 1;
				$data["courseroll"] = 0;
				$tmp = explode('@', $data['name']);
				$data['name'] = $tmp[0];
				if($user['showallgroups'])
					$selectAffil = 1;
				else
					$selectAffil = 0;
			}
			else {
				$data["name"] = $usergroups[$id]["name"];
				$data["affiliationid"] = $usergroups[$id]["groupaffiliationid"];
				$data["owner"] = $usergroups[$id]["owner"];
				$data["editgroupid"] = $usergroups[$id]["editgroupid"];
				$data["initialmax"] = $usergroups[$id]["initialmaxtime"];
				$data["totalmax"] = $usergroups[$id]["totalmaxtime"];
				$data["maxextend"] = $usergroups[$id]["maxextendtime"];
				$data["overlap"] = $usergroups[$id]["overlapResCount"];
				$data["custom"] = $usergroups[$id]["custom"];
				$data["courseroll"] = $usergroups[$id]["courseroll"];
				$tmp = explode('@', $data['name']);
				$data['name'] = $tmp[0];
				if($user['showallgroups'] ||
				   (array_key_exists(1, $tmp) && $tmp[1] != $user['affiliation']))
					$selectAffil = 1;
				else
					$selectAffil = 0;
			}
		}
		else {
			unset($affilusergroups[$defaultusergroupid]);
			if($state) {
				$grouptype = 'computer';
				$data['name'] = '';
				if(array_key_exists('VCLOWNERGROUPID', $_COOKIE) &&
				   array_key_exists($_COOKIE['VCLOWNERGROUPID'], $user['groups']))
					$ownerid = $_COOKIE['VCLOWNERGROUPID'];
				else {
					$ownerid = "";
					foreach(array_keys($user["groups"]) as $grpid) {
						if(array_key_exists($grpid, $dispUserGrpIDs)) {
							$ownerid = $grpid;
							break;
						}
					}
				}
			}
			else {
				list($grouptype, $data["name"]) = 
				   explode('/', $resourcegroups[$id]["name"]);
				$ownerid = $resourcegroups[$id]["ownerid"];
			}
		}
	}

	if($data['type'] == 'user' && ! array_key_exists($defaultusergroupid, $affilusergroups)) {
		if($user['showallgroups']) {
			$affil = getAffiliationName(1);
			$affilusergroups[$defaultusergroupid]['name'] = "Default for Editable by@$affil";
		}
		else
			$affilusergroups[$defaultusergroupid]['name'] = 'Default for Editable by';
		uasort($affilusergroups, "sortKeepIndex");
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
			print "{$usergroups[$data['groupid']]['name']}<br><br>\n";
			if($data['courseroll'] == 1)
				print "Type: Course Roll<br><br>\n";
			elseif($data['custom'] == 0)
				print "Type: Federated<br><br>\n";
			$editusergroup = 1;
		}
		else {
			print "<H2>Edit Resource Group</H2>\n";
			list($junk, $name) = explode('/', $resourcegroups[$data['groupid']]["name"]);
			print "$name<br><br>\n";
		}
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
		$editname = 1;
		if($data['type'] == 'user' && $state == 0 &&
		   $usergroups[$groupid]['groupaffiliationid'] == 1) {
			$tmp = explode('@', $usergroups[$groupid]['name']);
			if($tmp[0] == 'Specify End Time' ||
				$tmp[0] == 'Allow No User Check' ||
				$tmp[0] == 'Default for Editable by' ||
				$tmp[0] == 'manageNewImages')
				$editname = 0;
		}
		if($data['type'] == 'user' && $state == 0 &&
		   ($data['courseroll'] == 1 || $data['custom'] == 0)) {
			$editname = 0;
		}
		if($data['type'] == 'resource' && $state == 0 &&
		   ($resourcegroups[$groupid]['name'] == 'computer/newimages' ||
			$resourcegroups[$groupid]['name'] == 'computer/newvmimages')) {
			$editname = 0;
		}
		if($editname) {
			print "  <TR>\n";
			print "    <TH align=right>Name:</TH>\n";
			print "    <TD><INPUT type=text name=name value=\"{$data['name']}\" ";
			print "maxlength=60 size=60>";
			if($data['type'] == 'user' && $selectAffil) {
				print "@";
				printSelectInput('affiliationid', $affils, $data['affiliationid']);
			}
			print "</TD>\n";
			print "    <TD>";
			printSubmitErr(GRPNAMEERR);
			print "</TD>\n";
			print "  </TR>\n";
		}
		if($editname == 0) {
			print "<TR><TD colspan=2 align=\"center\">\n";
			print "(This is a system group whose name cannot be modified.)\n";
			print "</TD></TR>\n";
		}
		if($data["type"] == "user") {
		   if($data['courseroll'] == 0 && $data['custom'] == 1) {
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
				print "    <TD valign=\"top\">\n";
				$groupwasnone = 0;
				if($submitErr & EDITGROUPERR) {
					if($state == 0)
						$data['editgroupid'] = $usergroups[$data['groupid']]['editgroupid'];
					elseif(count($affilusergroups)) {
						$tmp = array_keys($affilusergroups);
						$data['editgroupid'] = $tmp[0];
					}
				}
				$notice = '';
				if($state == 0 && empty($usergroups[$data['groupid']]["editgroup"])) {
					$affilusergroups = array_reverse($affilusergroups, TRUE);
					$affilusergroups[0] = array('name' => 'None');
					$affilusergroups = array_reverse($affilusergroups, TRUE);
					$groupwasnone = 1;
					$notice = "<strong>Note:</strong> You are the only person that can<br>"
					        . "edit membership of this group. Select a<br>user group here "
					        . "to allow members of that<br>group to edit membership of this one.";
				}
				elseif(! array_key_exists($data['editgroupid'], $affilusergroups) &&
				       $data['editgroupid'] != 0) {
					$affilusergroups[$data['editgroupid']] =
					      array('name' => getUserGroupName($data['editgroupid'], 1));
					uasort($affilusergroups, "sortKeepIndex");
				}
				if($state == 1 && $data['editgroupid'] == 0)
					print "None\n";
				else
					printSelectInput("editgroupid", $affilusergroups, $data["editgroupid"]);
				print "    </TD>\n";
				print "    <TD>";
				if($submitErr & EDITGROUPERR)
					printSubmitErr(EDITGROUPERR);
				else
					print $notice;
				print "</TD>";
				print "  </TR>\n";
			}
			else
				$groupwasnone = 1;
			print "  <TR>\n";
			print "    <TH align=right>Initial Max Time:</TH>\n";
			print "    <TD>";
			$lengths = getReservationLengths(201600);
			if(! array_key_exists($data['initialmax'], $lengths))
				$data['initialmax'] = getReservationLengthCeiling($data['initialmax']);
			printSelectInput("initialmax", $lengths, $data['initialmax']);
			print "    </TD>";
			print "    <TD>";
			printSubmitErr(INITIALMAXERR);
			print "</TD>\n";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>Total Max Time:</TH>\n";
			print "    <TD>";
			if(! array_key_exists($data['totalmax'], $lengths))
				$data['totalmax'] = getReservationLengthCeiling($data['totalmax']);
			printSelectInput("totalmax", $lengths, $data['totalmax']);
			print "    </TD>\n";
			print "    <TD>";
			printSubmitErr(TOTALMAXERR);
			print "</TD>\n";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>Max Extend Time:</TH>\n";
			print "    <TD>";
			if(! array_key_exists($data['maxextend'], $lengths))
				$data['maxextend'] = getReservationLengthCeiling($data['maxextend']);
			printSelectInput("maxextend", $lengths, $data['maxextend']);
			print "    </TD>\n";
			print "    <TD>";
			printSubmitErr(MAXEXTENDERR);
			print "</TD>\n";
			print "  </TR>\n";
			if(checkUserHasPerm('Set Overlapping Reservation Count')) {
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
			if($submitErr & EDITGROUPERR)
				$ownerid = $resourcegroups[$groupid]['ownerid'];
			if($state == 0 && $ownerid != '' &&
			   ! array_key_exists($ownerid, $dispUserGrpIDs)) {
				$dispUserGrpIDs[$ownerid] = $usergroups[$ownerid]['name'];
				uasort($dispUserGrpIDs, "sortKeepIndex");
			}
			if(! empty($dispUserGrpIDs))
				printSelectInput("ownergroup", $dispUserGrpIDs, $ownerid);
			else
				printSelectInput("ownergroup", $dispUserGrpIDsAllAffils, $ownerid);
			print "    </TD>\n";
			print "    <TD>\n";
			if($submitErr & EDITGROUPERR)
				printSubmitErr(EDITGROUPERR);
			print "    </TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
		print "<TABLE>\n";
		print "  <TR valign=top>\n";
		print "    <TD>\n";
		if($state) {
			$cdata = array('type' => $data['type']);
			if($data['type'] == 'user') {
				$cdata['isowner'] = $data['isowner'];
				if($data['editgroupid'] == 0) {
					$cdata['editgroupid'] = 0;
					$cdata['groupwasnone'] = 1;
				}
				$cdata['editgroupids'] = implode(',', array_keys($affilusergroups));
			}
			else {
				if(! empty($dispUserGrpIDs))
					$cdata['ownergroupids'] = implode(',', array_keys($dispUserGrpIDs));
				else
					$cdata['ownergroupids'] = implode(',', array_keys($dispUserGrpIDsAllAffils));
			}
			$cont = addContinuationsEntry('submitAddGroup', $cdata);
			print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
			print "      <INPUT type=submit value=\"Add Group\">\n";
		}
		else {
			$cdata = array('type' => $data['type'],
			               'groupid' => $data['groupid'],
			               'isowner' => $data['isowner'],
			               'editname' => $editname);
			if($editname == 0)
				$cdata['name'] = $data['name'];
			if($data['type'] == 'resource') {
				$cdata['resourcetypeid'] = $resourcetypeid;
				if(! empty($dispUserGrpIDs))
					$cdata['ownergroupids'] = implode(',', array_keys($dispUserGrpIDs));
				else
					$cdata['ownergroupids'] = implode(',', array_keys($dispUserGrpIDsAllAffils));
			}
			else {
				if($editname == 0)
					$cdata['affiliationid'] = $data['affiliationid'];
				$cdata['selectAffil'] = $selectAffil;
				$cdata['groupwasnone'] = $groupwasnone;
				$cdata['custom'] = $data['custom'];
				$cdata['courseroll'] = $data['courseroll'];
				$cdata['editgroupids'] = implode(',', array_keys($affilusergroups));
			}
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

	if($data["type"] != "user") {
		print "</DIV>\n";
		return;
	}
	if($editusergroup) {
		$newuser = processInputVar("newuser", ARG_STRING);
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
		$edit = 1;
		if($data['courseroll'] == 1 || $data['custom'] == 0)
			$edit = 0;
		if(empty($groupmembers) && ! $edit)
			print "(empty group)<br>\n";
		print "<TABLE border=1 id=\"groupmembershiptbl\">\n";
		if($edit) {
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
		}
		foreach($groupmembers as $id => $login) {
			print "  <TR>\n";
			if($edit) {
				print "    <TD>\n";
				print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				print "      <INPUT type=submit value=Delete>\n";
				$data['userid'] = $id;
				$data['newuser'] = $login;
				$cont = addContinuationsEntry('deleteGroupUser', $data);
				print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
				print "      </FORM>\n";
				print "    </TD>\n";
			}
			print "    <TD>$login</TD>\n";
			print "  </TR>\n";
		}
		print "</TABLE>\n";
	}
	print "</DIV>\n";
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
	global $submitErr, $submitErrMsg, $user;
	$return = array();
	$return["groupid"] = getContinuationVar("groupid");
	$return["type"] = getContinuationVar("type");
	$return["custom"] = getContinuationVar("custom", 1);
	$return["courseroll"] = getContinuationVar("courseroll", 0);
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
	$return['editgroupids'] = getContinuationVar('editgroupids');
	$editgroupids = explode(',', $return['editgroupids']);
	$return['ownergroupids'] = getContinuationVar('ownergroupids');
	$ownergroupids = explode(',', $return['ownergroupids']);
	$groupwasnone = getContinuationVar('groupwasnone');
	$editname = getContinuationVar('editname', 1);

	$affils = getAffiliations();
	if(! array_key_exists($return['affiliationid'], $affils))
		$return['affiliationid'] = $user['affiliationid'];

	if(! $checks) {
		return $return;
	}
	
	if($return['custom'] == 1 && $return['courseroll'] == 0 && $editname) {
		if($return['type'] == 'user' &&
		   ! preg_match('/^[-a-zA-Z0-9_\.: ]{3,60}$/', $return["name"])) {
			$submitErr |= GRPNAMEERR;
			$submitErrMsg[GRPNAMEERR] = "Name must be between 3 and 60 characters "
			                          . "and can only contain letters, numbers, "
			                          . "spaces, and these characters: - . _ :";
		}
		elseif($return['type'] == 'resource' &&
		   ! preg_match('/^[-a-zA-Z0-9_\. ]{3,60}$/', $return["name"])) {
			$submitErr |= GRPNAMEERR;
			$submitErrMsg[GRPNAMEERR] = "Name must be between 3 and 60 characters "
			                          . "and can only contain letters, numbers, "
			                          . "spaces, and these characters: - . _";
		}
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
	if($return['custom'] == 1 && $return['courseroll'] == 0 &&
	   $return["type"] == "user" && ! validateUserid($return["owner"])) {
		$submitErr |= GRPOWNER;
	   $submitErrMsg[GRPOWNER] = "Submitted ID is not valid";
	}
	if(($return["type"] == "user" &&
	    $return["courseroll"] == 0 &&
	    $return["custom"] == 1 &&
		(($return['editgroupid'] == 0 && ! $groupwasnone) ||
	   (! in_array($return['editgroupid'], $editgroupids)))) ||
	   ($return['type'] == 'resource' && ! in_array($return['ownergroup'], $ownergroupids))) {
		$submitErr |= EDITGROUPERR;
		$submitErrMsg[EDITGROUPERR] = "Invalid group was selected";
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
	if(checkUserHasPerm('Set Overlapping Reservation Count') &&
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
	$name = mysql_real_escape_string($name);
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
	if($data['type'] == "user") {
		if($data['courseroll'] == 1 || $data['custom'] == 0) {
			$data['editgroupid'] = 'NULL';
			$ownerid = 'NULL';
		}
		else {
			if($data['editgroupid'] == 0)
				$data['editgroupid'] = 'NULL';
			$ownerid = getUserlistID($data['owner']);
		}
		$query = "UPDATE usergroup "
		       . "SET name = '{$data['name']}', "
		       .     "affiliationid = {$data['affiliationid']}, "
		       .     "ownerid = $ownerid, "
		       .     "editusergroupid = {$data['editgroupid']}, "
		       .     "initialmaxtime = {$data['initialmax']}, "
		       .     "totalmaxtime = {$data['totalmax']}, ";
		if(checkUserHasPerm('Set Overlapping Reservation Count'))
			$query .= "overlapResCount = {$data['overlap']}, ";
		$query .=    "maxextendtime = {$data['maxextend']} "
		       . "WHERE id = {$data['groupid']}";
	}
	else {
		$query = "UPDATE resourcegroup "
		       . "SET name = '{$data['name']}', "
		       .     "ownerusergroupid = {$data['ownergroup']} "
		       . "WHERE id = {$data['groupid']}";
	}
	doQuery($query, 300);
	return mysql_affected_rows($GLOBALS['mysql_link_vcl']);
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
	if($data['type'] == "user") {
		if($data['editgroupid'] == 0 || $data['editgroupid'] == '')
			$data['editgroupid'] = 'NULL';
		if(! array_key_exists('custom', $data))
			$data['custom'] = 1;
		elseif($data['custom'] == 0) {
			$ownerid = 'NULL';
			$data['editgroupid'] = 'NULL';
		}
		if($data['custom'])
			$ownerid = getUserlistID($data['owner']);
		$query = "INSERT INTO usergroup "
				 .         "(name, "
				 .         "affiliationid, "
				 .         "ownerid, "
				 .         "editusergroupid, "
		       .         "custom, "
		       .         "initialmaxtime, "
		       .         "totalmaxtime, ";
		if(checkUserHasPerm('Set Overlapping Reservation Count'))
			$query .=     "overlapResCount, ";
		$query .=        "maxextendtime) "
				 . "VALUES ('{$data['name']}', "
				 .        "{$data['affiliationid']}, "
				 .        "$ownerid, "
				 .        "{$data['editgroupid']}, "
		       .        "{$data['custom']}, "
		       .        "{$data['initialmax']}, "
		       .        "{$data['totalmax']}, ";
		if(checkUserHasPerm('Set Overlapping Reservation Count'))
			$query .=    "{$data['overlap']}, ";
		$query .=       "{$data['maxextend']})";
	}
	else {
		$query = "INSERT INTO resourcegroup "
				 .         "(name, "
				 .         "ownerusergroupid, "
		       .         "resourcetypeid) "
				 . "VALUES ('{$data['name']}', "
		       .         "{$data['ownergroup']}, "
		       .         "'{$data['resourcetypeid']}')";
	}
	$qh = doQuery($query, 305);
	clearPrivCache();
	return mysql_affected_rows($GLOBALS['mysql_link_vcl']);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForGroupUsage($groupid, $type, &$msg)
///
/// \param $groupid - id of a group
/// \param $type - group type: "user" or "resource"
/// \param $msg - (pass by ref, optional) reason why group is in use is placed
/// in this variable
///
/// \return 0 if group is not used, 1 if it is used
///
/// \brief checks for $groupid being in the priv table corresponding to $type;
/// if the group is in use, a reason why is placed in $msg
///
////////////////////////////////////////////////////////////////////////////////
function checkForGroupUsage($groupid, $type, &$msg='') {
	global $user;
	$msgs = array();
	if($type == "user") {
		$name = getUserGroupName($groupid, 1);
		if($name === 0)
			return 0;
		# resourcegroup.ownerusergroupid
		$query = "SELECT CONCAT(rt.name, '/', rg.name) AS name "
		       . "FROM resourcegroup rg, "
		       .      "resourcetype rt "
		       . "WHERE ownerusergroupid = $groupid AND "
		       .       "rg.resourcetypeid = rt.id";
		$usedby = array();
		$qh = doQuery($query, 310);
		while($row = mysql_fetch_assoc($qh))
			$usedby[] = $row['name'];
		if(count($usedby)) {
			$msgs[] = "<h3>Owning User Group for Resource Groups</h3>\n"
			        . implode("<br>\n", $usedby) . "<br>\n";
		}
		# usergroup.editusergroupid
		$query = "SELECT CONCAT(ug.name, '@', a.name) AS name "
		       . "FROM usergroup ug, "
		       .      "affiliation a "
				 . "WHERE ug.editusergroupid = $groupid AND "
				 .       "ug.id != $groupid AND "
				 .       "ug.affiliationid = a.id";
		$usedby = array();
		$qh = doQuery($query, 313);
		while($row = mysql_fetch_assoc($qh))
			$usedby[] = $row['name'];
		if(count($usedby)) {
			$msgs[] = "<h3>'Editable by' Group for User Groups</h3>\n"
			        . implode("<br>\n", $usedby) . "<br>\n";
		}
		# userpriv.usergroupid
		$query = "SELECT DISTINCT privnodeid "
		       . "FROM userpriv "
		       . "WHERE usergroupid = $groupid";
		$qh = doQuery($query);
		$usedby = array();
		while($row = mysql_fetch_assoc($qh))
			$usedby[] = getNodePath($row['privnodeid']);
		if(count($usedby)) {
			$msgs[] = "<h3>Assigned at Privilege Nodes</h3>\n"
			        . implode("<br>\n", $usedby) . "<br>\n";
		}
		# blockRequest.groupid
		$query = "SELECT name "
		       . "FROM blockRequest "
		       . "WHERE groupid = $groupid "
		       .   "AND status IN ('requested', 'accepted')";
		$qh = doQuery($query, 311);
		$usedby = array();
		while($row = mysql_fetch_assoc($qh))
			$usedby[] = $row['name'];
		if(count($usedby)) {
			$msgs[] = "<h3>Assigned for Block Allocations</h3>\n"
			        . implode("<br>\n", $usedby) . "<br>\n";
		}
		# serverprofile.admingroupid
		$query = "SELECT name FROM serverprofile WHERE admingroupid = $groupid";
		$qh = doQuery($query);
		$usedby = array();
		while($row = mysql_fetch_assoc($qh))
			$usedby[] = $row['name'];
		if(count($usedby)) {
			$msgs[] = "<h3>Admin User Group for Server Profiles</h3>\n"
			        . implode("<br>\n", $usedby) . "<br>\n";
		}
		# serverprofile.logingroupid
		$query = "SELECT name FROM serverprofile WHERE logingroupid = $groupid";
		$qh = doQuery($query);
		$usedby = array();
		while($row = mysql_fetch_assoc($qh))
			$usedby[] = $row['name'];
		if(count($usedby)) {
			$msgs[] = "<h3>Access User Group for Server Profiles</h3>\n"
			        . implode("<br>\n", $usedby) . "<br>\n";
		}
		# serverrequest.admingroupid
		$query = "SELECT s.name "
		       . "FROM serverrequest s, "
		       .      "request rq "
		       . "WHERE s.admingroupid = $groupid AND "
		       .       "s.requestid = rq.id";
		$qh = doQuery($query);
		$usedby = array();
		while($row = mysql_fetch_assoc($qh))
			$usedby[] = $row['name'];
		if(count($usedby)) {
			$msgs[] = "<h3>Admin User Group for Server Requests</h3>\n"
			        . implode("<br>\n", $usedby) . "<br>\n";
		}
		# serverrequest.logingroupid
		$query = "SELECT s.name "
		       . "FROM serverrequest s, "
		       .      "request rq "
		       . "WHERE s.logingroupid = $groupid AND "
		       .       "s.requestid = rq.id";
		$qh = doQuery($query);
		$usedby = array();
		while($row = mysql_fetch_assoc($qh))
			$usedby[] = $row['name'];
		if(count($usedby)) {
			$msgs[] = "<h3>Access User Group for Server Requests</h3>\n"
			        . implode("<br>\n", $usedby) . "<br>\n";
		}
		if(count($msgs)) {
			$msg = "$name is currently in use in the following ways. It "
			     . "cannot be deleted until it is no longer in use.<br><br>\n"
			     . implode("<br>\n", $msgs);
			$msg = wordwrap($msg, 75, "<br>");
			return 1;
		}
		return 0;
	}

	$name = getResourceGroupName($groupid);
	if(is_null($name))
		return 0;

	# managementnode.imagelibgroupid
	$query = "SELECT hostname FROM managementnode WHERE imagelibgroupid = $groupid";
	$qh = doQuery($query);
	$usedby = array();
	while($row = mysql_fetch_assoc($qh))
		$usedby[] = $row['hostname'];
	if(count($usedby)) {
		$msgs[] = "<h3>Management Node Image Library Group</h3>\n"
		        . implode("<br>\n", $usedby) . "<br>\n";
	}
	# resourcepriv.resourcegroupid
	$query = "SELECT DISTINCT privnodeid FROM resourcepriv WHERE resourcegroupid = $groupid";
	$qh = doQuery($query);
	$usedby = array();
	while($row = mysql_fetch_assoc($qh))
		$usedby[] = getNodePath($row['privnodeid']);
	if(count($usedby)) {
		$msgs[] = "<h3>Assigned at Privilege Nodes</h3>\n"
		        . implode("<br>\n", $usedby) . "<br>\n";
	}
	if(count($msgs)) {
		$msg = "$name is currently in use in the following ways. It "
		     . "cannot be deleted until it is no longer in use.<br><br>\n"
		     . implode("<br>\n", $msgs);
		$msg = wordwrap($msg, 75, "<br>");
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
	global $submitErr, $user;

	$data = processGroupInput(1);

	if($submitErr) {
		editOrAddGroup($state);
		return;
	}

	$resourcetypes = getTypes("resources");
	$usergroups = getUserGroups();
	$affils = getAffiliations();
	$editname = getContinuationVar('editname', 1);

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
	if($editname == 0) {
		if($data['type'] == 'user' && $user['showallgroups'])
			print "{$data['name']}@{$affils[$data['affiliationid']]}<br><br>\n";
		else
			print "{$data['name']}<br><br>\n";
	}
	print "<TABLE>\n";
	if($data["type"] == "resource") {
		print "  <TR>\n";
		print "    <TH align=right>Type:</TH>\n";
		print "    <TD>" . $resourcetypes["resources"][$data["resourcetypeid"]];
		print "</TD>\n";
		print "  </TR>\n";
	}
	if($data['courseroll'] == 0 && $data['custom'] == 1 && $editname == 1) {
		print "  <TR>\n";
		print "    <TH align=right>Name:</TH>\n";
		if($data['type'] == 'user' && ($user['showallgroups'] ||
		   $data['affiliationid'] != $user['affiliationid']))
			print "    <TD>{$data["name"]}@{$affils[$data['affiliationid']]}</TD>\n";
		else
			print "    <TD>{$data["name"]}</TD>\n";
		print "  </TR>\n";
	}
	if($data["type"] == "user") {
		if($data['courseroll'] == 0 && $data['custom'] == 1) {
			print "  <TR>\n";
			print "    <TH align=right>Owner:</TH>\n";
			print "    <TD>" . $data["owner"] . "</TD>\n";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>Editable by:</TH>\n";
			if($state == 0 && $data['editgroupid'] == 0)
				$usergroups[0]['name'] = 'None';
			elseif(! $user['showallgroups']) {
				$tmp = explode('@', $usergroups[$data["editgroupid"]]["name"]);
				if($tmp[1] == $user['affiliation'])
					$usergroups[$data["editgroupid"]]["name"] = $tmp[0];
			}
			print "    <TD>" . $usergroups[$data["editgroupid"]]["name"] . "</TD>\n";
			print "  </TR>\n";
		}
		$lengths = getReservationLengths(201600);
		print "  <TR>\n";
		print "    <TH align=right>Initial Max Time:</TH>\n";
		print "    <TD>{$lengths[$data["initialmax"]]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Total Max Time:</TH>\n";
		print "    <TD>{$lengths[$data["totalmax"]]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Max Extend Time:</TH>\n";
		print "    <TD>{$lengths[$data["maxextend"]]}</TD>\n";
		print "  </TR>\n";
		if(checkUserHasPerm('Set Overlapping Reservation Count')) {
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
	print "</DIV>\n";
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
	$_SESSION['usersessiondata'] = array();
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
/// \fn AJconfirmDeleteGroup()
///
/// \brief generates and sends content prompting user to confirm deletion of
/// group
///
////////////////////////////////////////////////////////////////////////////////
function AJconfirmDeleteGroup() {
	global $user;
	$type = getContinuationVar("type");

	$usergroups = getUserGroups();

	$groupid = processInputVar('groupid', ARG_NUMERIC);
	if($type == 'user') {
		if(! array_key_exists($groupid, $usergroups)) {
			$rt = array('status' => 'nogroup',
			            'title' => _('Delete User Group Error'),
			            'msg' => _('The selected user group was not found.'));
			sendJSON($rt);
			return;
		}
		if($usergroups[$groupid]['ownerid'] != $user['id']) {
			if(($usergroups[$groupid]['custom'] == 0 ||
			   $usergroups[$groupid]['courseroll'] == 1)) {
				if(! checkUserHasPerm('Manage Federated User Groups (global)') &&
				   (! checkUserHasPerm('Manage Federated User Groups (affiliation only)') ||
				   $usergroups[$groupid]['groupaffiliationid'] != $user['affiliationid'])) {
					$rt = array('status' => 'noaccess',
					            'title' => _('Delete User Group Error'),
					            'msg' => _('You do not have access to delete the selected user group.'));
					sendJSON($rt);
					return;
				}
			}
			else {
				$rt = array('status' => 'noaccess',
				            'title' => _('Delete User Group Error'),
				            'msg' => _('You do not have access to delete the selected user group.'));
				sendJSON($rt);
				return;
			}
		}
		$tmp = explode('@', $usergroups[$groupid]['name']);
		$checkname = $tmp[0];
		if($usergroups[$groupid]['groupaffiliationid'] == 1 &&
		   ($checkname == 'Specify End Time' ||
		   $checkname == 'Allow No User Check' ||
		   $checkname == 'Default for Editable by' ||
		   $checkname == 'manageNewImages')) {
			$rt = array('status' => 'noaccess',
			            'title' => _('Delete User Group Error'),
			            'msg' => sprintf(_('%s is a system group that cannot be deleted'), "<strong>{$usergroups[$groupid]['name']}</strong>"));
			sendJSON($rt);
			return;
		}
	}
	else {
		$userresources = getUserResources(array("groupAdmin"), 
		                                  array("manageGroup"), 1);
		$noaccess = 1;
		foreach(array_keys($userresources) as $rtype) {
			if(array_key_exists($groupid, $userresources[$rtype])) {
				$noaccess = 0;
				break;
			}
		}
		if($noaccess) {
			$rt = array('status' => 'noaccess',
			            'title' => _('Delete Resource Group Error'),
			            'msg' => _('You do not have access to delete the selected resource group.'));
			sendJSON($rt);
			return;
		}
	}

	$resourcegroups = getResourceGroups();

	if($type == "user") {
		$title = _("Delete User Group");
		$usemsg = wordwrap(_("This group is currently in use. You cannot delete it until it is no longer being used."), 75, "<br>");
		$question = _("Delete the following user group?");
		$name = $usergroups[$groupid]["name"];
		$target = "";
	}
	else {
		if($resourcegroups[$groupid]['name'] == 'computer/newimages' ||
			$resourcegroups[$groupid]['name'] == 'computer/newvmimages') {
			$rt = array('status' => 'noaccess',
			            'title' => _('Delete Resource Group Error'),
			            'msg' => _('The submitted resource group is a system group that cannot be deleted.'));
			sendJSON($rt);
			return;
		}

		$title = _("Delete Resource Group");
		$usemsg = wordwrap(_("This group is currently assigned to at least one node in the privilege tree. You cannot delete it until it is no longer in use."), 75, "<br>");
		$question = _("Delete the following resource group?");
		list($resourcetype, $name) = 
			explode('/', $resourcegroups[$groupid]["name"]);
		$target = "#resources";
	}

	if(checkForGroupUsage($groupid, $type, $usemsg)) {
		$rt = array('status' => 'inuse',
		            'title' => $title,
		            'msg' => $usemsg);
		sendJSON($rt);
		return;
	}

	$cdata = array('type' => $type,
	               'groupid' => $groupid);

	$cont = addContinuationsEntry('AJsubmitDeleteGroup', $cdata, 3600, 1, 0);

	$rt = array('status' => 'success',
	            'title' => $title,
	            'question' => $question,
	            'cont' => $cont);

	$h = "<TABLE>";
	if($type == "resource") {
		$h .= "<TR>";
		$h .= "<TH align=right>" . _("Type:") . "</TH>";
		$h .= "<TD>" . _($resourcetype) . "</TD>";
		$h .= "</TR>";
	}
	$h .= "<TR>";
	$h .= "<TH align=right>" . _("Name:") . "</TH>";
	$h .= "<TD>$name</TD>";
	$h .= "</TR>";
	if($type == "resource") {
		$h .= "<TR>";
		$h .= "<TH align=right>" . _("Owning User Group:") . "</TH>";
		$h .= "<TD>" . $resourcegroups[$groupid]["owner"] . "</TD>";
		$h .= "</TR>";
	}
	elseif($usergroups[$groupid]['courseroll'] == 1 ||
	   $usergroups[$groupid]['custom'] == 0) {
		$h .= "<TR>";
		$h .= "  <TH align=right>" . _("Type:") . "</TH>";
		if($usergroups[$groupid]['courseroll'] == 1)
			$h .= "  <TD>" . _("Course Roll") . "</TD>";
		elseif($usergroups[$groupid]['custom'] == 0)
			$h .= "  <TD>" . _("Federated") . "</TD>";
		$h .= "</TR>";
		$h .= "<TR>";
		$h .= "  <TD colspan=2><br><strong>" . _("Note") . "</strong>:";
		$h .= wordwrap(_("This type of group is created from external sources and could be recreated from those sources at any time."), 75, "<br>");
		$h .= "</TD>";
		$h .= "</TR>";
	}
	$h .= "</TABLE>";
	$rt['content'] = $h;
	sendJSON($rt);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitDeleteGroup()
///
/// \brief deletes a group from the database and notifies the user
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitDeleteGroup() {
	$groupid = getContinuationVar("groupid");
	$type = getContinuationVar("type");
	if($type == "user") {
		$query = "UPDATE blockRequest "
		       . "SET groupid = NULL "
		       . "WHERE groupid = $groupid";
		doQuery($query);
		$table = "usergroup";
	}
	else
		$table = "resourcegroup";
	$query = "DELETE FROM $table "
			 . "WHERE id = $groupid";
	doQuery($query, 315);
	clearPrivCache();
	$data = array('status' => 'success',
	              'type' => $type,
	              'id' => $groupid);
	sendJSON($data);
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
	if(validateUserid($newuser) != 1) {
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
/// \brief gets members of submitted resource group and returns in JSON format
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
		header('Content-Type: text/json; charset=utf-8');
		print '{} && {"items":' . json_encode(array()) . '}';
		return;
	}
	$members = getResourceGroupMembers($type);
	$data = '';
	if(! empty($members[$type][$groupid])) {
		uasort($members[$type][$groupid], "sortKeepIndex");
		foreach($members[$type][$groupid] as $mem) {
			$data .= "{$mem['name']}<br>";
		}
	}
	else
		$data = '(empty group)';
	$arr = array('members' => $data, 'x' => $mousex, 'y' => $mousey, 'groupid' => $groupid);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '{} && {"items":' . json_encode($arr) . '}';
}

?>
