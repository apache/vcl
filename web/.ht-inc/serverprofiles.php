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
/// \fn serverProfiles()
///
/// \brief prints server profile page
///
////////////////////////////////////////////////////////////////////////////////
function serverProfiles() {
	global $user;
	/*if(! in_array("serverProfileAdmin", $user["privileges"])) {
		print "No access to manage server profiles.<br>\n";
		return;
	}*/
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"profilesstore\" ";
	print "data=\"profilesstoredata\"></div>\n";
	print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	print "     style=\"width:630px;height:600px\">\n";

	print "<div id=\"deploytab\" dojoType=\"dijit.layout.ContentPane\" title=\"Deploy Server\">\n";
	print "<h2>Deploy Server</h2>\n";
	print "Server deployment has been incorporated into the <strong>Reservations</strong>";
	print " part of the site. To deploy a server<br>\n";
	print "<ol style=\"list-style: decimal;\">\n";
	print "<li>Click <strong>Reservations</strong></li>\n";
	print "<li>Click the <strong>New Reservation</strong> button</li>\n";
	print "<li>Select the <strong>Server Reservation</strong> radio button at the top of the dialog box</li>\n";
	print "</ol>\n";
	print "</div>\n"; # deploytab

	if(in_array("serverProfileAdmin", $user["privileges"])) {
		print "<div id=\"manageprofiles\" dojoType=\"dijit.layout.ContentPane\" title=\"Manage Profiles\">\n";
		$data = manageProfilesHTML();
		print $data['html'];
		print "</div>\n"; # manageprofiles tab

		print "<div id=\"grouping\" dojoType=\"dijit.layout.ContentPane\" title=\"Manage Grouping\">\n";
		$data = manageGroupingHTML();
		print $data['html'];
		print "</div>\n"; # grouping tab
	}

	print "</div>\n"; # tab container
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn manageProfilesHTML()
///
/// \return an array with one element with a key of 'html' whose value is the
/// html content for the manage tab
///
/// \brief builds the html for the manage tab
///
////////////////////////////////////////////////////////////////////////////////
function manageProfilesHTML() {
	global $user;
	$profiles = getUserResources(array("serverProfileAdmin"), array("administer"));

	$h = '';
	$h .= "<h2>Manage Server Profiles</h2>\n";
	$h .= "<span id=\"profileslist\"";
	if(! count($profiles['serverprofile']))
		$h .= " class=\"hidden\"";
	$h .= ">\n";
	$h .= "Profile: ";
	$h .= "<select dojoType=\"dijit.form.Select\" id=\"profileid\" ";
	$h .= "onChange=\"selectProfileChanged();\" sortByLabel=\"true\"></select>\n";
	$cont = addContinuationsEntry('AJserverProfileData', array('mode' => 'admin'));
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"fetchProfilesBtn\">\n";
	$h .= "	Configure Profile\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		getServerProfileData('$cont', 'profileid', getServerProfileDataManageCB);\n";
	$h .= "	</script>\n";
	$h .= "</button>";
	$h .= "</span>\n"; # profileslist
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"newProfilesBtn\">\n";
	$h .= "	New Profile...\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		newServerProfile();\n";
	$h .= "	</script>\n";
	$h .= "</button>";
	$h .= "<br><br>\n";
	$h .= "<span id=\"savestatus\" class=\"hidden\">Profile successfully updated</span>\n";

	$h .= "<div id=\"serverprofiledata\" class=\"hidden\">\n";
	$cont = addContinuationsEntry('AJdelServerProfile');
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"delProfilesBtn\">\n";
	$h .= "	Delete this Profile\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		confirmDelServerProfile('$cont');\n";
	$h .= "	</script>\n";
	$h .= "</button><br><br>\n";
	$h .= "<table summary=\"\">\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Name:</th>\n";
	$h .= "    <td><input type=\"text\" name=\"profilename\" id=\"profilename\" ";
	$h .= "dojoType=\"dijit.form.TextBox\" style=\"width: 400px\"></td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Description:</th>\n";
	$h .= "    <td><textarea name=\"profiledesc\" id=\"profiledesc\" ";
	$h .= "dojoType=\"dijit.form.Textarea\" style=\"width: 400px\"></textarea></td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Environment:</th>\n";
	$h .= "    <td>\n";
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources["image"]);
	if(USEFILTERINGSELECT && count($images) < FILTERINGSELECTTHRESHOLD) {
		$h .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=\"profileimage\" ";
		$h .= "style=\"width: 400px\" name=\"profileimage\" queryExpr=\"*\${0}*\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "      <select dojoType=\"dijit.form.Select\" name=\"profileimage\" id=\"profileimage\">\n";
	foreach($images as $id => $image)
		$h .= "        <option value=\"$id\">$image</option>\n";
	$h .= "      </select>\n";
	$h .= "    </td>\n";
	$h .= "  </tr>\n";
	/*$h .= "  <tr>\n";
	$h .= "    <th align=right>Fixed MAC Address:</th>\n";
	$h .= "    <td><input type=\"text\" name=\"profilefixedMAC\" id=\"profilefixedMAC\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"([0-9a-fA-F]{2}:){5}([0-9a-fA-F]{2})\">(optional)</td>\n";
	$h .= "  </tr>\n";*/
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Admin User Group:</th>\n";
	$h .= "    <td>\n";
	if($user['showallgroups'])
		$admingroups = getUserGroups();
	else
		$admingroups = getUserGroups(0, $user['affiliationid']);
	$logingroups = $admingroups;
	/*$admingroups = getUserEditGroups($user['id']);
	$logingroups = $admingroups;
	$extraadmingroups = getServerProfileGroups($user['id'], 'admin');
	foreach($extraadmingroups as $id => $group)
		$admingroups[$id] = $group;
	uasort($admingroups, 'sortKeepIndex');*/
	if(USEFILTERINGSELECT && count($admingroups) < FILTERINGSELECTTHRESHOLD) {
		$h .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=\"profileadmingroup\" ";
		$h .= "style=\"width: 400px\" name=\"profileadmingroup\" queryExpr=\"*\${0}*\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "      <select name=\"profileadmingroup\" id=\"profileadmingroup\">\n";
	$h .= "        <option value=\"0\">None</option>\n";
	foreach($admingroups as $id => $group) {
		if($group['name'] == 'None' || preg_match('/^None@.*$/', $group['name']))
			continue;
		$h .= "        <option value=\"$id\">{$group['name']}</option>\n";
	}
	#foreach($admingroups as $id => $group) {
	#	$h .= "        <option value=\"$id\">$group</option>\n";
	$h .= "      </select>\n";
	$h .= "    </td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Access User Group:</th>\n";
	$h .= "    <td>\n";
	/*$extralogingroups = getServerProfileGroups($user['id'], 'login');
	foreach($extralogingroups as $id => $group)
		$logingroups[$id] = $group;
	uasort($logingroups, 'sortKeepIndex');*/
	if(USEFILTERINGSELECT && count($logingroups) < FILTERINGSELECTTHRESHOLD) {
		$h .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=\"profilelogingroup\" ";
		$h .= "style=\"width: 400px\" name=\"profilelogingroup\" queryExpr=\"*\${0}*\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "      <select name=\"profilelogingroup\" id=\"profilelogingroup\">\n";
	$h .= "        <option value=\"0\">None</option>\n";
	foreach($logingroups as $id => $group) {
		if($group['name'] == 'None' || preg_match('/^None@.*$/', $group['name']))
			continue;
		$h .= "        <option value=\"$id\">{$group['name']}</option>\n";
	}
	#foreach($logingroups as $id => $group)
	#	$h .= "        <option value=\"$id\">$group</option>\n";
	$h .= "      </select>\n";
	$h .= "    </td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr class=\"hidden\">\n";
	$h .= "    <th align=right>Monitored:</th>\n";
	$h .= "    <td><input type=\"checkbox\" name=\"profilemonitored\" ";
	$h .= "id=\"profilemonitored\" dojoType=\"dijit.form.CheckBox\"></td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tbody class=\"boxedtablerows\">\n";
	$regip1 = "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)";
	$regip4 = "$regip1\\.$regip1\\.$regip1\\.$regip1";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Fixed IP Address:</th>\n";
	$h .= "    <td><input type=\"text\" name=\"profilefixedIP\" id=\"profilefixedIP\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"$regip4\" onKeyUp=\"checkFixedSet('profile');\">(optional)</td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Netmask:</th>\n";
	$h .= "    <td><input type=\"text\" id=\"profilenetmask\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"$regip4\" validator=\"validateNetmask\" ";
	$h .= "onKeyUp=\"fetchRouterDNS('profile');\" disabled>";
	$h .= "</td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Router:</th>\n";
	$h .= "    <td><input type=\"text\" id=\"profilerouter\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"$regip4\" disabled></td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>DNS Server(s):</th>\n";
	$h .= "    <td><input type=\"text\" id=\"profiledns\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"($regip4)(,$regip4){0,2}\" disabled></td>\n";
	$h .= "  </tr>\n";
	$h .= "  </tbody>\n";
	$h .= "</table>\n";
	$cont = addContinuationsEntry('AJsaveServerProfile');
	$h .= "<br><br>\n";
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"saveProfilesBtn\">\n";
	$h .= "	Save Profile\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		saveServerProfile('$cont');\n";
	$h .= "	</script>\n";
	$h .= "</button><br><br>\n";
	$h .= "</div>\n"; # serverprofiledata

	$h .= "<div id=\"confirmDeleteProfile\" dojoType=\"dijit.Dialog\" ";
	$h .= "title=\"Confirm Delete Server Profile\">\n";
	$h .= "Are you sure you want to delete this Server Profile?<br><br>\n";
	$h .= "<div align=\"center\">\n";
	$h .= "<button dojoType=\"dijit.form.Button\">\n";
	$h .= "	Delete Server Profile\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		delServerProfile();\n";
	$h .= "	</script>\n";
	$h .= "</button>\n";
	$h .= "<button dojoType=\"dijit.form.Button\">\n";
	$h .= "	Cancel\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		dojo.byId('delcont').value = '';\n";
	$h .= "		dijit.byId('confirmDeleteProfile').hide();\n";
	$h .= "	</script>\n";
	$h .= "</button>\n";
	$h .= "</div>\n"; # center aligned div
	$h .= "<input type=\"hidden\" id=\"delcont\"></input>\n";
	$h .= "</div>\n"; # confirmDeleteProfile
	return array('html' => $h);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn manageGroupingHTML()
///
/// \return an array with one element with a key of 'html' whose value is the
/// html content for the grouping tab
///
/// \brief builds the html for the grouping tab
///
////////////////////////////////////////////////////////////////////////////////
function manageGroupingHTML() {
	global $mode;
	$resources = getUserResources(array("serverProfileAdmin"),
	                              array("manageGroup"));
	$resourcegroups = getUserResources(array("serverProfileAdmin"),
	                                   array("manageGroup"), 1);
	$h = '';
	if($mode == 'submitServerProfileGroups')
		$gridSelected = "selected=\"true\"";
	else
		$gridSelected = "";
	
	$h .= "<H2>Server Profile Grouping</H2>\n";
	$h .= "<span id=\"noprofilegroupsspan\"";
	if(count($resources["serverprofile"]) && count($resourcegroups['serverprofile']))
		$h .= " class=\"hidden\"";
	$h .= ">\n";
	$h .= "You don't have access to modify any server profile groups.<br>\n";
	$h .= "</span>\n";
	$h .= "<span id=\"groupprofilesspan\"";
	if(! count($resources["serverprofile"]) || ! count($resourcegroups['serverprofile']))
		$h .= " class=\"hidden\"";
	$h .= ">\n";
	$h .= "<div id=\"groupTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	$h .= "     style=\"width:600px;height:400px\">\n";

	# by profile tab
	$h .= "<div id=\"resource\" dojoType=\"dijit.layout.ContentPane\" title=\"By Server Profile\">\n";
	$h .= "Select a server profile and click \"Get Groups\" to see all of the groups ";
	$h .= "it is in. Then,<br>select a group it is in and click the Remove ";
	$h .= "button to remove it from that group,<br>or select a group it is not ";
	$h .= "in and click the Add button to add it to that group.<br><br>\n";
	$h .= "Server Profile:<select dojoType=\"dijit.form.Select\" id=\"profiles\" ";
	$h .= "sortByLabel=\"true\" onChange=\"dojo.addClass('groupsdiv', 'hidden');";
	$h .= "\"></select>\n";
	# build list of profiles
	/*$profiles = $resources['serverprofile'];
	uasort($profiles, 'sortKeepIndex');
	foreach($profiles as $id => $profile) {
		$h .= "<option value=$id>$profile</option>\n";
	}
	$h .= "</select>\n";*/
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"fetchGrpsButton\">\n";
	$h .= "	Get Groups\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		getGroups();\n";
	$h .= "	</script>\n";
	$h .= "</button>\n";
	$h .= "<div id=\"groupsdiv\" class=\"hidden\">\n";
	$h .= "<table><tbody><tr>\n";
	# select for groups profile is in
	$h .= "<td valign=top>\n";
	$h .= "Groups <span style=\"font-weight: bold;\" id=inprofilename></span> is in:<br>\n";
	$h .= "<select name=ingroups multiple id=ingroups size=15>\n";
	$h .= "</select>\n";
	$h .= "</td>\n";
	# transfer buttons
	$h .= "<td style=\"vertical-align: middle;\">\n";
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"addBtn1\">\n";
	$h .= "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJaddGroupToProfile');
	$h .= "		addRemItem('$cont', 'profiles', 'outgroups', addRemProfileCB);\n";
	$h .= "	</script>\n";
	$h .= "</button>\n";
	$h .= "<br>\n";
	$h .= "<br>\n";
	$h .= "<br>\n";
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"remBtn1\">\n";
	$h .= "	<div style=\"width: 50px;\">Remove-&gt;</div>\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJremGroupFromProfile');
	$h .= "		addRemItem('$cont', 'profiles', 'ingroups', addRemProfileCB);\n";
	$h .= "	</script>\n";
	$h .= "</button>\n";
	$h .= "</td>\n";
	# select for groups profile is not in
	$h .= "<td valign=top>\n";
	$h .= "Groups <span style=\"font-weight: bold;\" id=outprofilename></span> is not in:<br>\n";
	$h .= "<select name=outgroups multiple id=outgroups size=15>\n";
	$h .= "</select>\n";
	$h .= "</td>\n";
	$h .= "</tr><tbody/></table>\n";
	$h .= "</div>\n"; # groupsdiv
	$h .= "</div>\n"; # resource

	# by group tab
	$h .= "<div id=\"group\" dojoType=\"dijit.layout.ContentPane\" title=\"By Group\">\n";
	$h .= "Select a group and click \"Get Server Profiles\" to see all of the server profiles ";
	$h .= "in it. Then,<br>select a server profile in it and click the Remove ";
	$h .= "button to remove it from the group,<br>or select a server profile that is not ";
	$h .= "in it and click the Add button to add it to the group.<br><br>\n";
	$h .= "Group:<select dojoType=\"dijit.form.Select\" id=\"profileGroups\" ";
	$h .= "onChange=\"dojo.addClass('profilesdiv', 'hidden');\">\n";
	# build list of groups
	$tmp = getUserResources(array('serverProfileAdmin'), array('manageGroup'), 1);
	$groups = $tmp['serverprofile'];
	uasort($groups, 'sortKeepIndex');
	foreach($groups as $id => $group) {
		$h .= "<option value=$id>$group</option>\n";
	}
	$h .= "</select>\n";
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"fetchImgsButton\">\n";
	$h .= "	Get Server Profiles\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		getProfiles();\n";
	$h .= "	</script>\n";
	$h .= "</button>\n";
	$h .= "<div id=\"profilesdiv\" class=\"hidden\">\n";
	$h .= "<table><tbody><tr>\n";
	# select for profiles in group
	$h .= "<td valign=top>\n";
	$h .= "Server Profiles in <span style=\"font-weight: bold;\" id=ingroupname></span>:<br>\n";
	$h .= "<select name=inprofiles multiple id=inprofiles size=15>\n";
	$h .= "</select>\n";
	$h .= "</td>\n";
	# transfer buttons
	$h .= "<td style=\"vertical-align: middle;\">\n";
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"addBtn2\">\n";
	$h .= "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJaddProfileToGroup');
	$h .= "		addRemItem('$cont', 'profileGroups', 'outprofiles', addRemGroupCB);\n";
	$h .= "	</script>\n";
	$h .= "</button>\n";
	$h .= "<br>\n";
	$h .= "<br>\n";
	$h .= "<br>\n";
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"remBtn2\">\n";
	$h .= "	<div style=\"width: 50px;\">Remove-&gt;</div>\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJremProfileFromGroup');
	$h .= "		addRemItem('$cont', 'profileGroups', 'inprofiles', addRemGroupCB);\n";
	$h .= "	</script>\n";
	$h .= "</button>\n";
	$h .= "</td>\n";
	# profiles not in group select
	$h .= "<td valign=top>\n";
	$h .= "Server Profiles not in <span style=\"font-weight: bold;\" id=outgroupname></span>:<br>\n";
	$h .= "<select name=outprofiles multiple id=outprofiles size=15>\n";
	$h .= "</select>\n";
	$h .= "</td>\n";
	$h .= "</tr><tbody/></table>\n";
	$h .= "</div>\n"; # profilesdiv
	$h .= "</div>\n"; # group

	$h .= "</div>\n"; # end of main tab container
	$h .= "</span>\n";
	$cont = addContinuationsEntry('jsonProfileGroupingProfiles');
	$h .= "<input type=hidden id=profilecont value=\"$cont\">\n";
	$cont = addContinuationsEntry('jsonProfileGroupingGroups');
	$h .= "<input type=hidden id=grpcont value=\"$cont\">\n";
	return array('html' => $h);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJserverProfileData()
///
/// \brief sends information about a specified server profile in json format
///
////////////////////////////////////////////////////////////////////////////////
function AJserverProfileData() {
	$profileid = processInputVar('id', ARG_NUMERIC);
	$mode = getContinuationVar('mode');
	if($mode == 'admin')
		$resources = getUserResources(array("serverProfileAdmin"), array("administer"));
	else
		$resources = getUserResources(array("serverCheckOut", "serverProfileAdmin"),
		                              array("available","administer"));
	if(! array_key_exists($profileid, $resources['serverprofile'])) {
		sendJSON(array('error' => 1, 'msg' => 'noaccess'));
		return;
	}

	$data = getServerProfiles($profileid);
	$data = $data[$profileid];
	unset($data['image']);
	unset($data['ownerid']);
	unset($data['owner']);
	unset($data['admingroup']);
	unset($data['logingroup']);
	if($data['fixedIP'] == 'NULL') {
		$data['fixedIP'] = '';
		$data['netmask'] = '';
		$data['router'] = '';
		$data['dns'] = '';
	}
	if($data['fixedMAC'] == 'NULL')
		$data['fixedMAC'] = '';
	if(is_null($data['admingroupid']))
		$data['admingroupid'] = 0;
	if(is_null($data['logingroupid']))
		$data['logingroupid'] = 0;
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJserverProfileStoreData()
///
/// \brief sends information about server profiles in json format
///
////////////////////////////////////////////////////////////////////////////////
function AJserverProfileStoreData() {
	$profiles = getServerProfiles();
	$data = array();
	$resources = getUserResources(array("serverCheckOut"), array("available"));
	foreach($resources['serverprofile'] as $id => $name)
		$data[$id] = array('id' => $id,
		                   'name' => $name,
		                   'access' => 'checkout',
		                   'desc' => preg_replace("/\n/", "<br>", $profiles[$id]['description']));
	$resources = getUserResources(array("serverProfileAdmin"), array("administer"));
	foreach($resources['serverprofile'] as $id => $name)
		$data[$id] = array('id' => $id,
		                   'name' => $name,
		                   'access' => 'admin',
		                   'desc' => preg_replace("/\n/", "<br>", $profiles[$id]['description']));
	$data = array_values($data);
	$data[] = array('id' => 70000,
	                'name' => '(New Profile)',
	                'access' => 'admin',
	                'desc' => '');
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsaveServerProfile
///
/// \brief updates server profile information
///
////////////////////////////////////////////////////////////////////////////////
function AJsaveServerProfile() {
	global $user;
	$data = processProfileInput();
	if(array_key_exists('error', $data)) {
		sendJSON($data);
		return;
	}
	$name = mysql_real_escape_string($data['name']);
	$desc = mysql_real_escape_string($data['desc']);
	$fixedIP = mysql_real_escape_string($data['fixedIP']);
	$fixedMAC = mysql_real_escape_string($data['fixedMAC']);
	$ret = array();
	if($data['profileid'] == 70000) {
		$query = "INSERT INTO serverprofile "
		       .        "(name, "
		       .        "description, "
		       .        "imageid, "
		       .        "ownerid, "
		       .        "fixedIP, "
		       .        "fixedMAC, "
		       .        "admingroupid, "
		       .        "logingroupid, "
		       .        "monitored) "
		       . "VALUES "
		       .        "('$name', "
		       .        "'$desc', "
		       .        "{$data['imageid']}, "
		       .        "{$user['id']}, "
		       .        "'$fixedIP', "
		       .        "'$fixedMAC', "
		       .        "{$data['admingroupid']}, "
		       .        "{$data['logingroupid']}, "
		       .        "{$data['monitored']})";
		doQuery($query, 101);
		$id = dbLastInsertID();
		$query = "INSERT INTO resource "
		       .        "(resourcetypeid, "
		       .        "subid) "
		       . "VALUES "
		       .        "(17, "
		       .        "$id)";
		doQuery($query, 101);
		$ret['success'] = 1;
		$ret['name'] = $data['name'];
		$ret['id'] = $id;
		$ret['newprofile'] = 1;
		if($fixedIP != '') {
			$vdata = array('netmask' => $data['netmask'],
			               'router' => $data['router'],
			               'dns' => $data['dnsArr']);
			setVariable("fixedIPsp$id", $vdata, 'yaml');
		}
	}
	else {
		$query = "UPDATE serverprofile SET "
		       .        "name = '$name', "
		       .        "description = '$desc', "
		       .        "imageid = {$data['imageid']}, "
		       .        "fixedIP = '$fixedIP', "
		       .        "fixedMAC = '$fixedMAC', "
		       .        "admingroupid = {$data['admingroupid']}, "
		       .        "logingroupid = {$data['logingroupid']}, "
		       .        "monitored = {$data['monitored']} "
		       . "WHERE id = {$data['profileid']}";
		doQuery($query, 101);
		$ret['success'] = 1;
		$ret['name'] = $data['name'];
		$ret['id'] = $data['profileid'];
		$ret['newprofile'] = 0;
	}
	if($data['fixedIP'] != '') {
		$vdata = array('netmask' => $data['netmask'],
		               'router' => $data['router'],
		               'dns' => $data['dnsArr']);
		setVariable("fixedIPsp{$ret['id']}", $vdata, 'yaml');
		$ret['netmask'] = $data['netmask'];
		$ret['router'] = $data['router'];
		$ret['dns'] = $data['dns'];
		$allnets = getVariable('fixedIPavailnetworks', array());
		$network = ip2long($data['fixedIP']) & ip2long($data['netmask']);
		$key = long2ip($network) . "/{$data['netmask']}";
		$allnets[$key] = array('router' => $data['router'],
		                       'dns' => $data['dnsArr']);
		setVariable('fixedIPavailnetworks', $allnets, 'yaml');
	}
	$ret['access'] = 'admin';
	$ret['desc'] = preg_replace("/\n/", "<br>", $data['desc']);
	$_SESSION['usersessiondata'] = array();
	$_SESSION['userresources'] = array();
	sendJSON($ret);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJdelServerProfile()
///
/// \brief deletes a server profile
///
////////////////////////////////////////////////////////////////////////////////
function AJdelServerProfile() {
	$profileid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("serverProfileAdmin"), array("administer"));
	if(! array_key_exists($profileid, $resources['serverprofile'])) {
		$data = array('error' => 1,
		              'msg' => 'You do not have access to delete this profile.');
		sendJSON($data);
		return;
	}
	$query = "DELETE FROM serverprofile WHERE id = $profileid";
	doQuery($query, 101);
	$rows = mysql_affected_rows();
	if($rows == 0) {
		$data = array('error' => 1,
		              'msg' => 'Failed to delete selected server profile');
		sendJSON($data);
		return;
	}
	$query = "DELETE FROM resource WHERE subid = $profileid AND resourcetypeid = 17";
	doQuery($query, 101);
	$_SESSION['usersessiondata'] = array();
	$_SESSION['userresources'] = array();
	sendJSON(array('success' => 1, 'id' => $profileid));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processProfileInput()
///
/// \return array with these values:\n
/// \b profileid - id of profile\n
/// \b name - name of profile\n
/// \b desc - description of profile\n
/// \b imageid - id associated with profile\n
/// \b fixedIP - IP address to be assigned to profile\n
/// \b fixedMAC - MAC address to be assigned to profile\n
/// \b admingroupid - admin user group associated with profile\n
/// \b logingroupid - login user group associated with profile\n
/// \b monitored - whether or not the profile should be monitored
///
/// \brief process submitted profile information
///
////////////////////////////////////////////////////////////////////////////////
function processProfileInput() {
	global $user;
	$ret = array();
	$ret['profileid'] = processInputVar('id', ARG_NUMERIC);
	$ret['name'] = processInputVar('name', ARG_STRING);
	$ret['desc'] = processInputVar('desc', ARG_STRING);
	$ret['imageid'] = processInputVar('imageid', ARG_NUMERIC);
	$ret['fixedMAC'] = processInputVar('fixedMAC', ARG_STRING);
	$ret['admingroupid'] = processInputVar('admingroupid', ARG_NUMERIC);
	$ret['logingroupid'] = processInputVar('logingroupid', ARG_NUMERIC);
	$monitored = processInputVar('monitored', ARG_STRING);
	$ret['fixedIP'] = processInputVar('fixedIP', ARG_STRING);
	$ret['netmask'] = processInputVar('netmask', ARG_STRING);
	$ret['router'] = processInputVar('router', ARG_STRING);
	$ret['dns'] = processInputVar('dns', ARG_STRING);
	$ret['dnsArr'] = array();

	$err = array();

	# validate access to this profile
	$resources = getUserResources(array("serverProfileAdmin"), array("administer"));
	if($ret['profileid'] != 70000 && ! array_key_exists($ret['profileid'], $resources['serverprofile'])) {
		$err['msg'] = "You do not have access to administer this server profile.";
		$err['field'] = 'profileid';
		$err['error'] = 1;
		return $err;
	}

	if(! preg_match('/^([-a-zA-Z0-9_\. ]){3,255}$/', $ret['name'])) {
		$err['msg'] = "The name can only contain letters, numbers, spaces, dashes(-), "
		            . "underscores(_), and periods(.) and can be from 3 to 255 characters long";
		$err['field'] = 'name';
		$err['error'] = 1;
		return $err;
	}
	if(! preg_match("/^([-a-zA-Z0-9\. ,;:@#&\(\)_+\/?\n]){0,1000}$/", $ret['desc'])) {
		$err['msg'] = "The description can only contain letters, numbers, spaces, and "
		            . "these characters: - , ; . : @ # & ( ) _ + / ? and can be from "
		            . "3 to 1000 characters long";
		$err['field'] = 'desc';
		$err['error'] = 1;
		return $err;
	}

	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources['image']);
	if(! array_key_exists($ret['imageid'], $images)) {
	   $err['msg'] = "Invalid image selected";
		$err['field'] = 'imageid';
		$err['error'] = 1;
		return $err;
	}

	$addrArr = explode('.', $ret['fixedIP']);
	if($ret['fixedIP'] == '')
		$ret['fixedIP'] = 'NULL';
	elseif(! validateIPv4addr($ret['fixedIP'])) {
		$err['msg'] = "Invalid value for Fixed IP Address. Must be w.x.y.z with each of "
		            . "w, x, y, and z being between 1 and 255 (inclusive)";
		$err['field'] = 'fixedIP';
		$err['error'] = 1;
		return $err;
	}
	elseif(! preg_match('/^[1]+0[^1]+$/', sprintf('%032b', ip2long($ret['netmask'])))) {
		$err['msg'] = "Invalid netmask specified";
		$err['field'] = 'netmask';
		$err['error'] = 1;
		return $err;
	}
	elseif(! validateIPv4addr($ret['router'])) {
		$err['msg'] = "Invalid value for Router. Must be w.x.y.z with each of "
		            . "w, x, y, and z being between 1 and 255 (inclusive)";
		$err['field'] = 'router';
		$err['error'] = 1;
		return $err;
	}
	elseif((ip2long($ret['fixedIP']) & ip2long($ret['netmask'])) !=
	       (ip2long($ret['router']) & ip2long($ret['netmask']))) {
		$err['msg'] = "IP address and router are not on the same subnet "
		            . "based on the specified netmask.";
		$err['field'] = 'router';
		$err['error'] = 1;
		return $err;
	}
	if($ret['fixedIP'] != 'NULL') {
		$tmp = explode(',', $ret['dns']);
		$cnt = 0;
		foreach($tmp as $dnsaddr) {
			if($cnt && $dnsaddr == '')
				continue;
			if($cnt == 3) {
				$err['msg'] = "Too many DNS servers specified - up to 3 are allowed.";
				$err['field'] = 'dns';
				$err['error'] = 1;
				return $err;
			}
			if(! validateIPv4addr($dnsaddr)) {
				$err['msg'] = "Invalid DNS server specified";
				$err['field'] = 'dns';
				$err['error'] = 1;
				return $err;
			}
			$ret['dnsArr'][] = $dnsaddr;
			$cnt++;
		}
	}

	if($ret['fixedMAC'] == '')
		$ret['fixedMAC'] = 'NULL';
	elseif(! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $ret['fixedMAC'])) {
		$err['msg'] = "Invalid MAC address.  Must be XX:XX:XX:XX:XX:XX with each pair of "
		        . "XX being from 00 to FF (inclusive)";
		$err['field'] = 'fixedMAC';
		$err['error'] = 1;
		return $err;
	}

	$usergroups = getUserGroups();
	/*$usergroups = getUserEditGroups($user['id']);
	$extraadmingroups = getServerProfileGroups($user['id'], 'admin');*/
	if($ret['admingroupid'] == 0)
		$ret['admingroupid'] = 'NULL';
	elseif(! array_key_exists($ret['admingroupid'], $usergroups) /*&&
	       ! array_key_exists($ret['admingroupid'], $extraadmingroups)*/) {
	   $err['msg'] = "Invalid Admin User Group selected";
		$err['field'] = 'admingroupid';
		$err['error'] = 1;
		return $err;
	}
	#$extralogingroups = getServerProfileGroups($user['id'], 'login');
	if($ret['logingroupid'] == 0)
		$ret['logingroupid'] = 'NULL';
	elseif(! array_key_exists($ret['logingroupid'], $usergroups) /*&&
	       ! array_key_exists($ret['logingroupid'], $extralogingroups)*/) {
	   $err['msg'] = "Invalid Access User Group selected";
		$err['field'] = 'logingroupid';
		$err['error'] = 1;
		return $err;
	}

	if(! preg_match('/^(false|on)$/', $monitored)) {
	   $err['msg'] = "Invalid value submitted for Monitored";
		$err['field'] = 'monitored';
		$err['error'] = 1;
		return $err;
	}
	if($monitored == 'on')
		$ret['monitored'] = 1;
	else
		$ret['monitored'] = 0;
	return $ret;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getServerProfileGroups($userid, $type)
///
/// \param $userid - id from user table
/// \param $type - 'admin' or 'user'
///
/// \return array where the key is the id of the user group and the value is the
/// name of the user group
///
/// \brief builds an array of user group that user has access to via server
/// profiles
///
////////////////////////////////////////////////////////////////////////////////
function getServerProfileGroups($userid, $type) {
	global $user;
	$key = getKey(array('getServerProfileAdminGroups', $userid, $type));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	$resources = getUserResources(array('serverCheckOut', 'serverProfileAdmin'),
	                              array('available', 'administer'));
	$ids = array_keys($resources['serverprofile']);
	$inids = implode(',', $ids);
	if(empty($inids)) {
		$_SESSION['usersessiondata'][$key] = array();
		return array();
	}
	if($type == 'admin')
		$field = 'admingroupid';
	else
		$field = 'logingroupid';
	if($user['showallgroups']) {
		$query = "SELECT DISTINCT(u.id), "
		       .        "CONCAT(u.name, '@', a.name) AS name "
		       . "FROM serverprofile s, "
		       .      "usergroup u, "
		       .      "affiliation a "
		       . "WHERE s.$field = u.id AND "
		       .       "u.affiliationid = a.id AND "
		       .       "s.id IN ($inids) "
		       . "ORDER BY name";
	}
	else {
		$query = "SELECT DISTINCT(u.id), "
		       .        "u.name "
		       . "FROM serverprofile s, "
		       .      "usergroup u "
		       . "WHERE s.$field = u.id AND "
		       .       "s.id IN ($inids) "
		       . "ORDER BY name";
	}
	$qh = doQuery($query, 101);
	$groups = array();
	while($row = mysql_fetch_assoc($qh))
		$groups[$row['id']] = $row['name'];
	$_SESSION['usersessiondata'][$key] = $groups;
	return $groups;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonProfileGroupingGroups()
///
/// \brief sends data about which profile groups are assigned to a profile
///
////////////////////////////////////////////////////////////////////////////////
function jsonProfileGroupingGroups() {
	$profileid = processInputVar('profileid', ARG_NUMERIC);
	$resources = getUserResources(array("serverProfileAdmin"), array("manageGroup"));
	if(! array_key_exists($profileid, $resources['serverprofile'])) {
		$arr = array('ingroups' => array(), 'outgroups' => array(), 'all' => array());
		sendJSON($arr);
		return;
	}
	$groups = getUserResources(array('serverProfileAdmin'), array('manageGroup'), 1);
	$memberships = getResourceGroupMemberships('serverprofile');
	$in = array();
	$out = array();
	$all = array();
	foreach($groups['serverprofile'] as $id => $group) {
		if(array_key_exists($profileid, $memberships['serverprofile']) &&
			in_array($id, $memberships['serverprofile'][$profileid])) {
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
/// \fn jsonProfileGroupingProfiles()
///
/// \brief sends data about which profiles are assigned to a profile group
///
////////////////////////////////////////////////////////////////////////////////
function jsonProfileGroupingProfiles() {
	$groupid = processInputVar('groupid', ARG_NUMERIC);
	$groups = getUserResources(array("serverProfileAdmin"), array("manageGroup"), 1);
	$emptyinout = 0;
	if(! array_key_exists($groupid, $groups['serverprofile']))
		$emptyinout = 1;

	$resources = getUserResources(array('serverProfileAdmin'), array('manageGroup'));
	uasort($resources['serverprofile'], 'sortKeepIndex');
	$memberships = getResourceGroupMemberships('serverprofile');
	$all = array();
	$in = array();
	$out = array();
	foreach($resources['serverprofile'] as $id => $profile) {
		if($emptyinout)
			$all[] = array('inout' => 0, 'id' => $id, 'name' => $profile);
		elseif(array_key_exists($id, $memberships['serverprofile']) &&
			in_array($groupid, $memberships['serverprofile'][$id])) {
			$all[] = array('inout' => 1, 'id' => $id, 'name' => $profile);
			$in[] = array('name' => $profile, 'id' => $id);
		}
		else {
			$all[] = array('inout' => 0, 'id' => $id, 'name' => $profile);
			$out[] = array('name' => $profile, 'id' => $id);
		}
	}
	$arr = array('inprofiles' => $in, 'outprofiles' => $out, 'all' => $all);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJaddGroupToProfile()
///
/// \brief adds a profile group to a profile
///
////////////////////////////////////////////////////////////////////////////////
function AJaddGroupToProfile() {
	$profileid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("serverProfileAdmin"), array("manageGroup"));
	// check access to profile
	if(! array_key_exists($profileid, $resources['serverprofile'])) {
		$arr = array('groups' => array(), 'addrem' => 1);
		sendJSON($arr);
		return;
	}

	// check access to groups
	$groups = getUserResources(array("serverProfileAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$groupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $groups['serverprofile'])) {
			$arr = array('groups' => array(), 'addrem' => 1);
			sendJSON($arr);
			return;
		}
		$groupids[] = $id;
	}

	$profile = getServerProfiles($profileid);
	$adds = array();
	foreach($groupids as $id) {
		$adds[] = "({$profile[$profileid]['resourceid']}, $id)";
	}
	$query = "INSERT IGNORE INTO resourcegroupmembers "
			 . "(resourceid, resourcegroupid) VALUES ";
	$query .= implode(',', $adds);
	doQuery($query, 101);
	$_SESSION['userresources'] = array();
	$_SESSION['usersessiondata'] = array();
	$arr = array('groups' => $groupids, 'addrem' => 1);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJremGroupFromProfile()
///
/// \brief removes a profile group from a profile
///
////////////////////////////////////////////////////////////////////////////////
function AJremGroupFromProfile() {
	$profileid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("serverProfileAdmin"), array("manageGroup"));
	if(! array_key_exists($profileid, $resources['serverprofile'])) {
		$arr = array('groups' => array(), 'addrem' => 0);
		sendJSON($arr);
		return;
	}

	$groups = getUserResources(array("serverProfileAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$groupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $groups['serverprofile'])) {
			$arr = array('groups' => array(), 'addrem' => 0);
			sendJSON($arr);
			return;
		}
		$groupids[] = $id;
	}

	$profile = getServerProfiles($profileid);
	foreach($groupids as $id) {
		$query = "DELETE FROM resourcegroupmembers "
				 . "WHERE resourceid = {$profile[$profileid]['resourceid']} AND "
				 .       "resourcegroupid = $id";
		doQuery($query, 288);
	}
	$arr = array('groups' => $groupids, 'addrem' => 0, 'removedaccess' => 0);
	$_SESSION['userresources'] = array();
	$_SESSION['usersessiondata'] = array();
	$resources = getUserResources(array("serverProfileAdmin"), array("manageGroup"));
	if(! array_key_exists($profileid, $resources['serverprofile'])) {
		$arr['removedaccess'] = 1;
		$arr['profileid'] = $profileid;
	}
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJaddProfileToGroup()
///
/// \brief adds a profile to a profile group
///
////////////////////////////////////////////////////////////////////////////////
function AJaddProfileToGroup() {
	$groupid = processInputVar('id', ARG_NUMERIC);
	$groups = getUserResources(array("serverProfileAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($groupid, $groups['serverprofile'])) {
		$arr = array('profiles' => array(), 'addrem' => 1);
		sendJSON($arr);
		return;
	}

	$resources = getUserResources(array("serverProfileAdmin"), array("manageGroup"));
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$profileids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $resources['serverprofile'])) {
			$arr = array('profiles' => array(), 'addrem' => 1);
			sendJSON($arr);
			return;
		}
		$profileids[] = $id;
	}

	$allprofiles = getServerProfiles();
	$adds = array();
	foreach($profileids as $id) {
		$adds[] = "({$allprofiles[$id]['resourceid']}, $groupid)";
	}
	$query = "INSERT IGNORE INTO resourcegroupmembers "
			 . "(resourceid, resourcegroupid) VALUES ";
	$query .= implode(',', $adds);
	doQuery($query, 287);
	$_SESSION['userresources'] = array();
	$_SESSION['usersessiondata'] = array();
	$arr = array('profiles' => $profileids, 'addrem' => 1);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJremProfileFromGroup()
///
/// \brief removes a profile from a profile group
///
////////////////////////////////////////////////////////////////////////////////
function AJremProfileFromGroup() {
	$groupid = processInputVar('id', ARG_NUMERIC);
	$groups = getUserResources(array("serverProfileAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($groupid, $groups['serverprofile'])) {
		$arr = array('profiles' => array(), 'addrem' => 0);
		sendJSON($arr);
		return;
	}

	$resources = getUserResources(array("serverProfileAdmin"), array("manageGroup"));
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$profileids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $resources['serverprofile'])) {
			$arr = array('profiles' => array(), 'addrem' => 0, 'id' => $id, 'extra' => $resources['serverprofile']);
			sendJSON($arr);
			return;
		}
		$profileids[] = $id;
	}

	$allprofiles = getServerProfiles();
	foreach($profileids as $id) {
		$query = "DELETE FROM resourcegroupmembers "
				 . "WHERE resourceid = {$allprofiles[$id]['resourceid']} AND "
				 .       "resourcegroupid = $groupid";
		doQuery($query, 288);
	}
	$arr = array('profiles' => $profileids,
	             'addrem' => 0,
	             'removedaccess' => 0);
	$_SESSION['userresources'] = array();
	$_SESSION['usersessiondata'] = array();
	$resources = getUserResources(array("serverProfileAdmin"), array("manageGroup"));
	foreach($profileids as $id) {
		if(! array_key_exists($id, $resources['serverprofile'])) {
			$arr['removedaccess'] = 1;
			$arr['remprofileids'][] = $id;
		}
	}
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJfetchRouterDNS()
///
/// \brief get router and dns information for a given IP address
///
////////////////////////////////////////////////////////////////////////////////
function AJfetchRouterDNS() {
	$data = array('status' => 'none');
	$page = processInputVar('page', ARG_STRING);
	if($page != 'deploy' && $page != 'profile') {
		sendJSON($data);
		return;
	}
	$ipaddr = processInputVar('ipaddr', ARG_STRING);
	# validate fixed IP address
	if(! validateIPv4addr($ipaddr)) {
		sendJSON($data);
		return;
	}
	# validate netmask
	$netmask = processInputVar('netmask', ARG_STRING);
	$bnetmask = ip2long($netmask);
	if(! preg_match('/^[1]+0[^1]+$/', sprintf('%032b', $bnetmask))) {
		sendJSON($data);
		return;
	}
	$network = ip2long($ipaddr) & $bnetmask;
	$availnets = getVariable('fixedIPavailnetworks', array());
	$key = long2ip($network) . "/$netmask";
	if(array_key_exists($key, $availnets)) {
		$data = array('status' => 'success',
		              'page' => $page,
		              'router' => $availnets[$key]['router'],
		              'dns' => implode(',', $availnets[$key]['dns']));
	}
	sendJSON($data);
}

?>
