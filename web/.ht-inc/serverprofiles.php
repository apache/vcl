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
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"profilesstore\" ";
	print "data=\"profilesstoredata\"></div>\n";
	print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	print "     style=\"width:630px;height:600px\">\n";
	print "<div id=\"deploytab\" dojoType=\"dijit.layout.ContentPane\" title=\"Shake &amp; Bake\" selected=\"true\">\n";
	$data = deployHTML();
	print $data['html'];
	print "</div>\n"; # deploy tab

	print "<div id=\"manageprofiles\" dojoType=\"dijit.layout.ContentPane\" title=\"Manage Profiles\">\n";
	$data = manageProfilesHTML();
	print $data['html'];
	print "</div>\n"; # manageprofiles tab

	print "<div id=\"grouping\" dojoType=\"dijit.layout.ContentPane\" title=\"Manage Grouping\">\n";
	$data = manageGroupingHTML();
	print $data['html'];
	print "</div>\n"; # grouping tab

	print "</div>\n"; # tab container
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deployHTML()
///
/// \return an array with one element with a key of 'html' whose value is the
/// html content for the deploy tab
///
/// \brief builds the html for the deploy tab
///
////////////////////////////////////////////////////////////////////////////////
function deployHTML() {
	global $user;
	$profiles = getServerProfiles();

	$h = '';
	$h .= "<h2>Shake &amp; Bake</h2>\n";
	$h .= "<span id=\"deployprofileslist\"";
	if(! count($profiles))
		$h .= " class=\"hidden\"";
	$h .= ">\n";
	$h .= "Profile: ";
	$h .= "<select dojoType=\"dijit.form.Select\" id=\"deployprofileid\" ";
	$h .= "onChange=\"deployProfileChanged();\" sortByLabel=\"true\"></select><br>\n";
	$h .= "<fieldset>\n";
	$h .= "<legend>Description:</legend>\n";
	$h .= "<div id=\"deploydesc\"></div>\n";
	$h .= "</fieldset>\n";
	$cont = addContinuationsEntry('AJserverProfileData');
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"deployFetchProfilesBtn\">\n";
	$h .= "	Apply Profile\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		getServerProfileData('$cont', 'deployprofileid', getServerProfileDataDeployCB);\n";
	$h .= "	</script>\n";
	$h .= "</button>";
	$h .= "<br><hr><br>\n";
	$h .= "</span>\n"; # deployprofileslist

	$h .= "<div id=\"deployprofilediv\">\n";
	$h .= "<table summary=\"\">\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Environment:</th>\n";
	$h .= "    <td>\n";
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources["image"]);
	if(USEFILTERINGSELECT && count($images) < FILTERINGSELECTTHRESHOLD) {
		$h .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=\"deployimage\" ";
		$h .= "style=\"width: 400px\" queryExpr=\"*\${0}*\" required=\"true\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "      <select dojoType=\"dijit.form.Select\" id=\"deployimage\">\n";
	foreach($images as $id => $image) {
		$image = preg_replace('/&/', '&amp;', $image);
		$h .= "        <option value=\"$id\">$image</option>\n";
	}
	$h .= "      </select>\n";
	$h .= "    </td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Fixed IP Address:</th>\n";
	$h .= "    <td><input type=\"text\" id=\"deployfixedIP\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"([0-9]{1,3}\\.){3}([0-9]{1,3})\">(optional)</td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Fixed MAC Address:</th>\n";
	$h .= "    <td><input type=\"text\" id=\"deployfixedMAC\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"([0-9a-fA-F]{2}:){5}([0-9a-fA-F]{2})\">(optional)</td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Admin User Group:</th>\n";
	$usergroups = getUserEditGroups($user['id']);
	$h .= "    <td>\n";
	if(USEFILTERINGSELECT && count($usergroups) < FILTERINGSELECTTHRESHOLD) {
		$h .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=\"deployadmingroup\" ";
		$h .= "style=\"width: 400px\" queryExpr=\"*\${0}*\" required=\"true\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "      <select dojoType=\"dijit.form.Select\" id=\"deployadmingroup\">\n";
	$h .= "        <option value=\"0\">None</option>\n";
	foreach($usergroups as $id => $group)
		$h .= "        <option value=\"$id\">$group</option>\n";
	$h .= "      </select>\n";
	$h .= "    </td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Access User Group:</th>\n";
	$h .= "    <td>\n";
	if(USEFILTERINGSELECT && count($usergroups) < FILTERINGSELECTTHRESHOLD) {
		$h .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=\"deploylogingroup\" ";
		$h .= "style=\"width: 400px\" queryExpr=\"*\${0}*\" required=\"true\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "      <select dojoType=\"dijit.form.Select\" id=\"deploylogingroup\">\n";
	$h .= "        <option value=\"0\">None</option>\n";
	foreach($usergroups as $id => $group)
		$h .= "        <option value=\"$id\">$group</option>\n";
	$h .= "      </select>\n";
	$h .= "    </td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr class=\"hidden\">\n";
	$h .= "    <th align=right>Monitored:</th>\n";
	$h .= "    <td><input type=\"checkbox\" ";
	$h .= "id=\"deploymonitored\" dojoType=\"dijit.form.CheckBox\"></td>\n";
	$h .= "  </tr>\n";
	$h .= "</table><br><br>\n";
	$h .= "When would you like to Shake &amp; Bake the server?<br>\n";
	$h .= "&nbsp;&nbsp;&nbsp;";
	$h .= "<input type=\"radio\" id=\"startnow\" name=\"deploystart\" ";
	$h .= "onclick=\"setStartNow();\" checked>\n";
	$h .= "<label for=\"startnow\">Now</label><br>\n";
	$h .= "&nbsp;&nbsp;&nbsp;";
	$h .= "<input type=\"radio\" id=\"startlater\" name=\"deploystart\" ";
	$h .= "onclick=\"setStartLater();\">\n";
	$h .= "<label for=\"startlater\">Later:</label>\n";
	$h .= "<div dojoType=\"dijit.form.DateTextBox\" ";
	$h .= "id=\"deploystartdate\" onChange=\"setStartLater();\" ";
	$h .= "style=\"width: 78px\"></div>\n";
	$h .= "<div id=\"deploystarttime\" dojoType=\"dijit.form.TimeTextBox\" ";
	$h .= "style=\"width: 78px\" onChange=\"setStartLater();\"></div>\n";
	$h .= "<small>(" . date('T') . ")</small><br><br>\n";
	$h .= "Ending for server:<br>\n";
	$h .= "&nbsp;&nbsp;&nbsp;";
	$h .= "<input type=\"radio\" id=\"endindef\" name=\"deployend\" ";
	$h .= "onclick=\"setEndIndef();\" checked>\n"; # todo should this 'checked' be hard coded?
	$h .= "<label for=\"endindef\">Indefinite</label><br>\n";
	$h .= "&nbsp;&nbsp;&nbsp;";
	$h .= "<input type=\"radio\" id=\"endat\" name=\"deployend\" ";
	$h .= "onclick=\"setEndAt();\">\n";
	$h .= "<label for=\"endat\">At this time:</label>\n";
	$h .= "<div type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
	$h .= "id=\"deployenddate\" onChange=\"setEndAt();\" ";
	$h .= "style=\"width: 78px\"></div>\n";
	$h .= "<div type=\"text\" id=\"deployendtime\" dojoType=\"dijit.form.TimeTextBox\" ";
	$h .= "style=\"width: 78px\" onChange=\"setEndAt();\"></div>\n";
	$h .= "<small>(" . date('T') . ")</small><br><br>\n";
	$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
	$h .= "<button dojoType=\"dijit.form.Button\">\n";
	$h .= "	Shake &amp; Bake Server\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		submitDeploy();\n";
	$h .= "	</script>\n";
	$h .= "</button><br><br>\n";
	$h .= "<input type=\"hidden\" id=\"deploycont\" value=\"$cont\">\n";
	$h .= "</div>\n"; # serverprofilediv
	return array('html' => $h);
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
	$profiles = getServerProfiles();

	$h = '';
	$h .= "<h2>Manage Server Profiles</h2>\n";
	$h .= "<span id=\"profileslist\"";
	if(! count($profiles))
		$h .= " class=\"hidden\"";
	$h .= ">\n";
	$h .= "Profile: ";
	$h .= "<select dojoType=\"dijit.form.Select\" id=\"profileid\" ";
	$h .= "onChange=\"selectProfileChanged();\" sortByLabel=\"true\"></select>\n";
	$cont = addContinuationsEntry('AJserverProfileData');
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
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Fixed IP Address:</th>\n";
	$h .= "    <td><input type=\"text\" name=\"profilefixedIP\" id=\"profilefixedIP\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"([0-9]{1,3}\\.){3}([0-9]{1,3})\">(optional)</td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Fixed MAC Address:</th>\n";
	$h .= "    <td><input type=\"text\" name=\"profilefixedMAC\" id=\"profilefixedMAC\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"([0-9a-fA-F]{2}:){5}([0-9a-fA-F]{2})\">(optional)</td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Admin User Group:</th>\n";
	$usergroups = getUserEditGroups($user['id']);
	$h .= "    <td>\n";
	if(USEFILTERINGSELECT && count($usergroups) < FILTERINGSELECTTHRESHOLD) {
		$h .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=\"profileadmingroup\" ";
		$h .= "style=\"width: 400px\" name=\"profileadmingroup\" queryExpr=\"*\${0}*\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "      <select dojoType=\"dijit.form.Select\" name=\"profileadmingroup\" id=\"profileadmingroup\">\n";
	$h .= "        <option value=\"0\">None</option>\n";
	foreach($usergroups as $id => $group)
		$h .= "        <option value=\"$id\">$group</option>\n";
	$h .= "      </select>\n";
	$h .= "    </td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr>\n";
	$h .= "    <th align=right>Access User Group:</th>\n";
	$h .= "    <td>\n";
	if(USEFILTERINGSELECT && count($usergroups) < FILTERINGSELECTTHRESHOLD) {
		$h .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=\"profilelogingroup\" ";
		$h .= "style=\"width: 400px\" name=\"profilelogingroup\" queryExpr=\"*\${0}*\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "      <select dojoType=\"dijit.form.Select\" name=\"profilelogingroup\" id=\"profilelogingroup\">\n";
	$h .= "        <option value=\"0\">None</option>\n";
	foreach($usergroups as $id => $group)
		$h .= "        <option value=\"$id\">$group</option>\n";
	$h .= "      </select>\n";
	$h .= "    </td>\n";
	$h .= "  </tr>\n";
	$h .= "  <tr class=\"hidden\">\n";
	$h .= "    <th align=right>Monitored:</th>\n";
	$h .= "    <td><input type=\"checkbox\" name=\"profilemonitored\" ";
	$h .= "id=\"profilemonitored\" dojoType=\"dijit.form.CheckBox\"></td>\n";
	$h .= "  </tr>\n";
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
	$h = '';
	if($mode == 'submitServerProfileGroups')
		$gridSelected = "selected=\"true\"";
	else
		$gridSelected = "";
	
	$h .= "<H2>Server Profile Grouping</H2>\n";
	$h .= "<span id=\"noprofilegroupsspan\"";
	if(count($resources["serverprofile"]))
		$h .= " class=\"hidden\"";
	$h .= ">\n";
	$h .= "You don't have access to modify any server profile groups.<br>\n";
	$h .= "</span>\n";
	$h .= "<span id=\"groupprofilesspan\"";
	if(! count($resources["serverprofile"]))
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
	$resources = getUserResources(array("serverProfileAdmin"), array("administer"));
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
	if($data['fixedIP'] == 'NULL')
		$data['fixedIP'] = '';
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
	$resources = getUserResources(array("serverProfileAdmin"), array("administer"));
	$profiles = getServerProfiles();
	$data = array();
	foreach($resources['serverprofile'] as $id => $name)
		$data[] = array('id' => $id,
		                'name' => $name,
		                'desc' => preg_replace("/\n/", "<br>", $profiles[$id]['description']));
	$data[] = array('id' => 70000,
	                'name' => '(New Profile)',
	                'desc' => '');
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJdeployServer()
///
/// \brief processes request information and creates reservation if everything
/// ok
///
////////////////////////////////////////////////////////////////////////////////
function AJdeployServer() {
	global $user;
	$imageid = processInputVar('imageid', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources["image"]);
	if(! array_key_exists($imageid, $images)) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => 'You do not have access to use this environment.');
		// TODO deal with problem of having access to a profile with an image user doesn't have access to
		sendJSON($data);
		return;
	}
	$ipaddr = processInputVar('ipaddr', ARG_STRING);
	$ipaddrArr = explode('.', $ipaddr);
	if($ipaddr != '' && (! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $ipaddr) ||
		$ipaddrArr[0] < 1 || $ipaddrArr[0] > 255 ||
		$ipaddrArr[1] < 0 || $ipaddrArr[1] > 255 ||
		$ipaddrArr[2] < 0 || $ipaddrArr[2] > 255 ||
		$ipaddrArr[3] < 1 || $ipaddrArr[3] > 255)) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => "Invalid IP address. Must be w.x.y.z with each of "
		                    . "w, x, y, and z being between 1 and 255 (inclusive)");
		sendJSON($data);
		return;
	}
	$macaddr = processInputVar('macaddr', ARG_STRING);
	if($macaddr != '' && ! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $macaddr)) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => "Invalid MAC address.  Must be XX:XX:XX:XX:XX:XX "
		                    . "with each pair of XX being from 00 to FF (inclusive)");
		sendJSON($data);
		return;
	}
	$admingroupid = processInputVar('admingroupid', ARG_NUMERIC);
	$usergroups = getUserEditGroups($user['id']);
	if($admingroupid != 0 && ! array_key_exists($admingroupid, $usergroups)) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => "You do not have access to use the specified admin user group.");
		sendJSON($data);
		return;
	}
	$logingroupid = processInputVar('logingroupid', ARG_NUMERIC);
	if($logingroupid != 0 && ! array_key_exists($logingroupid, $usergroups)) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => "You do not have access to use the specified access user group.");
		sendJSON($data);
		return;
	}
	$monitored = processInputVar('monitored', ARG_NUMERIC);
	if($monitored != 0 && $monitored != 1)
		$monitored = 0;
	$startmode = processInputVar('startmode', ARG_NUMERIC);
	if($startmode != 0 && $startmode != 1) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => "Invalid start information submitted");
		sendJSON($data);
		return;
	}
	$endmode = processInputVar('endmode', ARG_NUMERIC);
	if($endmode != 0 && $endmode != 1) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => "Invalid end information submitted");
		sendJSON($data);
		return;
	}
	if($startmode == 1) {
		$tmp = processInputVar('start', ARG_NUMERIC);
		if(! preg_match('/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$/', $tmp, $matches)) {
			$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
			$data = array('error' => 1,
			              'cont' => $cont,
			              'msg' => "Invalid start date/time submitted");
			sendJSON($data);
			return;
		}
		$startts = datetimeToUnix("{$matches[1]}-{$matches[2]}-{$matches[3]} {$matches[4]}:{$matches[5]}:00");
	}
	else {
		$tmp = time();
		$startts = unixFloor15();
	}
	if($endmode == 1) {
		$tmp = processInputVar('end', ARG_NUMERIC);
		if(! preg_match('/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$/', $tmp, $matches)) {
			$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
			$data = array('error' => 1,
			              'cont' => $cont,
			              'msg' => "Invalid end date/time submitted");
			sendJSON($data);
			return;
		}
		$endts = datetimeToUnix("{$matches[1]}-{$matches[2]}-{$matches[3]} {$matches[4]}:{$matches[5]}:00");
	}
	else {
		$tmp = time();
		$endts = datetimeToUnix("2038-01-01 00:00:00");
	}

	// TODO handle selection of multiple revisions

	// get semaphore lock
	if(! semLock())
		abort(3);

	$revisionid = getProductionRevisionid($imageid);
	$images = getImages(0, $imageid);
	$availablerc = isAvailable($images, $imageid, $revisionid, $startts, $endts);
	$max = getMaxOverlap($user['id']);
	if($availablerc != 0 && checkOverlap($startts, $endts, $max)) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		if($max == 0)
			$msg = "The time you specified overlaps with another reservation you "
			     . "currently have. You are only allowed to have a single "
			     . "reservation at a time. You either need to end your existing "
			     . "reservation or specify a time for this one that does not "
			     . "overlap with your other reservation.";
		else
			$msg = "The time you specified overlaps with other reservations you "
			     . "currently have. You are allowed to have $max overlapping "
			     . "reservations at a time. You either need to end an existing "
			     . "reservation or specify a time for this one that does not "
			     . "overlap with your other reservations.";
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => $msg);
		sendJSON($data);
		return;
	}
	if($availablerc == -1) {
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$msg = "You have requested an environment that is limited in the number "
		     . "of concurrent reservations that can be made. No further "
		     . "reservations for the environment can be made for the time you "
		     . "have selected. Please select another time to use the "
		     . "environment.";
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => $msg);
		sendJSON($data);
		return;
	}
	if($availablerc == 0) {
		// TODO what about timetable?
		$cont = addContinuationsEntry('AJdeployServer', array(), SECINDAY, 1, 0);
		$msg = "The requested time period is not available. Please select a "
		     . "different time.";
		$data = array('error' => 1,
		              'cont' => $cont,
		              'msg' => $msg);
		sendJSON($data);
		return;
	}
	$requestid = addRequest();
	$fields = array('requestid');
	$values = array($requestid);
	if($ipaddr != '') {
		$fields[] = 'fixedIP';
		$values[] = "'$ipaddr'";
	}
	if($macaddr != '') {
		$fields[] = 'fixedMAC';
		$values[] = "'$macaddr'";
	}
	if($admingroupid != 0) {
		$fields[] = 'admingroupid';
		$values[] = $admingroupid;
	}
	if($logingroupid != 0) {
		$fields[] = 'logingroupid';
		$values[] = $logingroupid;
	}
	if($monitored != 0) {
		$fields[] = 'monitored';
		$values[] = 1;
	}
	$allfields = implode(',', $fields);
	$allvalues = implode(',', $values);
	$query = "INSERT INTO serverrequest ($allfields) VALUES ($allvalues)";
	doQuery($query, 101);
	$ret['success'] = 1;
	$ret['redirecturl'] = BASEURL . SCRIPT . "?mode=viewRequests";
	sendJSON($ret);
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
	}
	else {
		$query = "UPDATE serverprofile SET "
		       .        "name = '$name', "
		       .        "description = '$desc', "
		       .        "imageid = {$data['imageid']}, "
		       .        "fixedIP = '{$data['fixedIP']}', "
		       .        "fixedMAC = '{$data['fixedMAC']}', "
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
	$ret['fixedIP'] = processInputVar('fixedIP', ARG_STRING);
	$ret['fixedMAC'] = processInputVar('fixedMAC', ARG_STRING);
	$ret['admingroupid'] = processInputVar('admingroupid', ARG_NUMERIC);
	$ret['logingroupid'] = processInputVar('logingroupid', ARG_NUMERIC);
	$monitored = processInputVar('monitored', ARG_STRING);

	$err = array();

	# validate access to this profile
	$resources = getUserResources(array("serverProfileAdmin"), array("administer"));
	if($ret['profileid'] != 70000 && ! array_key_exists($ret['profileid'], $resources['serverprofile'])) {
		$err['msg'] = "You do not have access to administer this server profile.";
		$err['field'] = 'profileid';
		$err['error'] = 1;
		return $err;
	}

	if(! preg_match('/^([-a-zA-Z0-9\. ]){3,255}$/', $ret['name'])) {
		$err['msg'] = "The name can only contain letters, numbers, spaces, dashes(-), "
		            . "and periods(.) and can be from 3 to 255 characters long";
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
	elseif(! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $ret['fixedIP']) ||
		$addrArr[0] < 1 || $addrArr[0] > 255 ||
		$addrArr[1] < 0 || $addrArr[1] > 255 ||
		$addrArr[2] < 0 || $addrArr[2] > 255 ||
		$addrArr[3] < 1 || $addrArr[3] > 255) {
	   $err['msg'] = "Invalid value for Fixed IP Address. Must be w.x.y.z with each of "
		        . "w, x, y, and z being between 1 and 255 (inclusive)";
		$err['field'] = 'fixedIP';
		$err['error'] = 1;
		return $err;
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

	$usergroups = getUserEditGroups($user['id']);
	if($ret['admingroupid'] == 0)
		$ret['admingroupid'] = 'NULL';
	elseif(! array_key_exists($ret['admingroupid'], $usergroups)) {
	   $err['msg'] = "Invalid Admin User Group selected";
		$err['field'] = 'admingroupid';
		$err['error'] = 1;
		return $err;
	}
	if($ret['logingroupid'] == 0)
		$ret['logingroupid'] = 'NULL';
	elseif(! array_key_exists($ret['logingroupid'], $usergroups)) {
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
/// \fn getServerProfiles($id)
///
/// \param $id - (optional) if specified, only return data for specified profile
///
/// \return an array where each key is a profile id whose value is an array with
/// these values:\n
/// \b name - profile name\n
/// \b description - profile description\n
/// \b imageid - id of image associated with profile\n
/// \b image - pretty name of image associated with profile\n
/// \b ownerid - user id of owner of profile\n
/// \b owner - unityid of owner of profile\n
/// \b fixedIP - IP address to be used with deployed profile\n
/// \b fixedMAC - MAC address to be used with deployed profile\n
/// \b admingroupid - id of admin user group associated with profile\n
/// \b admingroup - name of admin user group associated with profile\n
/// \b logingroupid - id of login user group associated with profile\n
/// \b logingroup - name of login user group associated with profile\n
/// \b monitored - whether or not deployed profile should be monitored\n
/// \b resourceid - resource id of profile
///
/// \brief gets information about server profiles
///
////////////////////////////////////////////////////////////////////////////////
function getServerProfiles($id=0) {
	$key = getKey(array('getServerProfiles', $id));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	$query = "SELECT s.id, "
	       .        "s.name, "
	       .        "s.description, "
	       .        "s.imageid, "
	       .        "i.prettyname AS image, "
	       .        "s.ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "s.fixedIP, "
	       .        "s.fixedMAC, "
	       .        "s.admingroupid, "
	       .        "CONCAT(ga.name, '@', aa.name) AS admingroup, "
	       .        "s.logingroupid, "
	       .        "CONCAT(gl.name, '@', al.name) AS logingroup, "
	       .        "s.monitored, "
	       .        "r.id AS resourceid "
	       . "FROM serverprofile s "
	       . "LEFT JOIN image i ON (i.id = s.imageid) "
	       . "LEFT JOIN user u ON (u.id = s.ownerid) "
	       . "LEFT JOIN affiliation a ON (a.id = u.affiliationid) "
	       . "LEFT JOIN usergroup ga ON (ga.id = s.admingroupid) "
	       . "LEFT JOIN affiliation aa ON (aa.id = ga.affiliationid) "
	       . "LEFT JOIN usergroup gl ON (gl.id = s.logingroupid) "
	       . "LEFT JOIN affiliation al ON (al.id = gl.affiliationid) "
	       . "LEFT JOIN resource r ON (r.subid = s.id) "
	       . "WHERE r.resourcetypeid = 17 ";
	if($id != 0)
		$query .= "AND s.id = $id";
	else
		$query .= "ORDER BY name";
	$qh = doQuery($query, 101);
	$profiles = array();
	while($row = mysql_fetch_assoc($qh))
		$profiles[$row['id']] = $row;
	$_SESSION['usersessiondata'][$key] = $profiles;
	return $profiles;
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
	if(! array_key_exists($groupid, $groups['serverprofile'])) {
		$arr = array('inprofiles' => array(), 'outprofiles' => array(), 'all' => array());
		sendJSON($arr);
		return;
	}

	$resources = getUserResources(array('serverProfileAdmin'), array('manageGroup'));
	uasort($resources['serverprofile'], 'sortKeepIndex');
	$memberships = getResourceGroupMemberships('serverprofile');
	$all = array();
	$in = array();
	$out = array();
	foreach($resources['serverprofile'] as $id => $profile) {
		if(array_key_exists($id, $memberships['serverprofile']) &&
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
	$resources = getUserResources(array("serverProfileAdmin"), array("manageGroup"));
	foreach($profileids as $id) {
		if(! array_key_exists($id, $resources['serverprofile'])) {
			$arr['removedaccess'] = 1;
			$arr['remprofileids'][] = $id;
		}
	}
	sendJSON($arr);
}
?>
