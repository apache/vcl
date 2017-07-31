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

/// signifies an error with submitted preferred name
define("PREFNAMEERR", 1);
/// signifies an error with submitted width
define("WIDTHERR", 1 << 1);
/// signifies an error with submitted height
define("HEIGHTERR", 1 << 2);
/// signifies an error with submitted new password
define("LOCALPASSWORDERR", 1 << 3);
/// signifies an error with submitted rdpport
define("RDPPORTERR", 1 << 4);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn userpreferences()
///
/// \brief prints a page for a user to edit his preferences
///
////////////////////////////////////////////////////////////////////////////////
function userpreferences() {
	global $user, $submitErr, $mode;
	if($submitErr) {
		$data = processUserPrefsInput(0);
		$data['affiliation'] = $user['affiliation'];
	}
	else {
		$data = $user;
		if($data["width"] == 0)
			$data["resolution"] = "Full Screen";
		else
			$data["resolution"] = $user["width"] . "x" . $user["height"];
	}

	print i("<H2 align=center>User Preferences</H2>\n");
	print "<div align=center id=status class=visible>\n";
	if($mode == "submituserprefs") {
		print "<font color=green>" . i("User preferences successfully updated") . "</font><br>\n";
	}
	print "</div>\n";
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD valign=top>\n";
	print "      <div id=preflinks class=hidden>\n";
	print "      <ul class=preferenceslist>\n";
	$showpersonal = 0;
	if(! empty($user['firstname']) || ! empty($user['lastname']) || ! empty($user['email']) ||
	   $user['affiliation'] == 'Local') {
		$showpersonal = 1;
		print "      <li><a href=#personal onclick=\"";
		print "show('personal'); return false;\">" . i("Personal Information") . "</a>";
		print "</li>\n";
	}
	print "      <li><a href=#rdpfile onclick=\"";
	print "show('rdpfile'); return false;\">" . i("RDP Preferences") . "</a>";
	print "</li>\n";
	print "      <li><a href=#uiprefs onclick=\"javascript:show('uiprefs'); ";
	print "return false\">" . i("General Preferences") . "</a></li>\n";
	print "      </ul>\n";
	print "      </div>\n";
	print "    </TD>\n";
	print "    <TD rowspan=2 style=\"width: 5em;\"></TD>\n";
	print "    <TD rowspan=2 id=\"uipreffieldsets\">\n";
	if($showpersonal) {
		print "      <fieldset id=personal class=shown>\n";
		print "      <legend>" . i("Personal") . "</legend>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "      <table summary=\"displays your personal information\">\n";
		$showsubmit = 0;
		if(! empty($user['firstname'])) {
			print "        <TR>\n";
			print "          <TH align=right>" . i("First Name:") . "<a href=#updateinfo>*</a></TH>\n";
			print "          <TD>" . $user["firstname"] . "</TD>\n";
			print "          <TD></TD>\n";
			print "        </TR>\n";
		}
		if(! empty($user['lastname'])) {
			print "        <TR>\n";
			print "          <TH align=right>" . i("Last Name:") . "<a href=#updateinfo>*</a></TH>\n";
			print "          <TD>" . $user["lastname"] . "</TD>\n";
			print "          <TD></TD>\n";
			print "        </TR>\n";
		}
		# preferred name is stored locally; allow setting preferred name if a firstname is defined
		if(! empty($user['firstname'])) {
			print "        <TR>\n";
			print "          <TH align=right>" . i("Preferred Name:") . "</TH>\n";
			print "          <TD><label class=hidden for=preferredname>Preferred Name</label>\n";
			print "              <INPUT type=text name=preferredname maxlength=100 ";
			print "size=15 value=\"" . $data["preferredname"] . "\"></TD>\n";
			print "          <TD>";
			printSubmitErr(PREFNAMEERR);
			print "</TD>\n";
			print "        </TR>\n";
			$showsubmit = 1;
		}
		if(! empty($user['email'])) {
			print "        <TR>\n";
			print "          <TH align=right>" . i("Email Address:") . "<a href=#updateinfo>*</a></TH>\n";
			print "          <TD>" . $user["email"] . "</TD>\n";
			print "          <TD></TD>\n";
			print "        </TR>\n";
		}
		if($user['affiliation'] == 'Local') {
			print "        <TR>\n";
			print "          <TD colspan=3 align=center><h3>" . i("Change Password") . "</h3></TD>\n";
			print "        </TR>\n";
			print "        <TR>\n";
			print "          <TH align=right>" . i("Current Password:") . "</TH>\n";
			print "          <TD>\n";
			print "            <label class=hidden for=currentpassword>Current Password</label>\n";
			print "            <INPUT type=password name=currentpassword maxlength=100 size=15>\n";
			print "          </TD>\n";
			print "          <TD>";
			printSubmitErr(LOCALPASSWORDERR);
			print "</TD>\n";
			print "        </TR>\n";
			print "        <TR>\n";
			print "          <TH align=right>" . i("New Password:") . "</TH>\n";
			print "          <TD>\n";
			print "            <label class=hidden for=newpassword>New Password</label>\n";
			print "            <INPUT type=password name=newpassword maxlength=100 ";
			print "id=newpassword onkeyup=\"checkNewLocalPassword();\" size=15>\n";
			print "          </TD>\n";
			print "          <TD></TD>\n";
			print "        </TR>\n";
			print "        <TR>\n";
			print "          <TH align=right>" . i("Confirm Password:") . "</TH>\n";
			print "          <TD>\n";
			print "            <label class=hidden for=confirmpassword>Confirm Password</label>\n";
			print "            <INPUT type=password name=confirmpassword maxlength=100 ";
			print "id=confirmpassword onkeyup=\"checkNewLocalPassword();\" size=15>\n";
			print "          </TD>\n";
			print "          <TD><span id=pwdstatus></span></TD>\n";
			print "        </TR>\n";
			$showsubmit = 1;
		}
		print "      </table>\n";
		$updateText = getAffiliationDataUpdateText($user['affiliationid']);
		print "<a name=updateinfo></a>\n";
		if(! empty($updateText[$user['affiliationid']]))
			print "{$updateText[$user['affiliationid']]}<br><br>";
		if($showsubmit) {
			$cont = addContinuationsEntry('confirmpersonalprefs', array(), SECINDAY, 1, 1, 1);
			print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
			print "      <div align=center>\n";
			print "      <INPUT type=submit value=\"" . i("Submit Changes") . "\">\n";
			print "      </div>\n";
		}
		print "      </FORM>\n";
		print "      </fieldset>\n";
	}

	print "      <fieldset id=rdpfile class=shown>\n";
	print "      <legend>" . i("RDP") . "</legend>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <table summary=\"lists adjustable preferences for the RDP ";
	print "file that is sent when you click the Get RDP File button on the ";
	print "Connect! page and the port on which RDP is listening\">\n";
	print "        <TR>\n";
	print "          <TD colspan=3><div style=\"width: 300px;\"><small>";
	print i("Try decreasing <em>Resolution</em> or <em>Color Depth</em> to speed up your connection if things seem slow when connected to a remote computer.");
	print "</div></small></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>" . i("Resolution:") . "</TH>\n";
	$resolutionArray = array("Full Screen" => "Full Screen",
	                         "1920x1440" => "1920x1440",
	                         "1600x1200" => "1600x1200",
	                         "1280x1024" => "1280x1024",
	                         "1152x864" => "1152x864",
	                         "1024x768" => "1024x768",
	                         "800x600" => "800x600",
	                         "640x480" => "640x480",
	                         "1680x1050" => "1680x1050",
	                         "1600x1024" => "1600x1024",
	                         "1440x900" => "1440x900",
	                         "1280x854" => "1280x854",
	                         "1280x768" => "1280x768",
	                         "1024x576" => "1024x576");
	print "          <TD>\n";
	printSelectInput("resolution", $resolutionArray, $data["resolution"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>" . i("Color Depth:") . "</TH>\n";
	print "          <TD>\n";
	$colordepth = array("8" => "8", "16" => "16", "24" => "24", "32" => "32");
	printSelectInput("bpp", $colordepth, $data["bpp"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>" . i("Audio:") . "</TH>\n";
	print "          <TD>\n";
	$audio = array("none" => i("None"), "local" => i("Use my speakers"));
	printSelectInput("audiomode", $audio, $data["audiomode"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>" . i("Map Local Drives:") . "</TH>\n";
	print "          <TD>\n";
	$yesno = array(1 => i("Yes"), 0 => i("No"));
	printSelectInput("mapdrives", $yesno, $data["mapdrives"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>" . i("Map Local Printers:") . "</TH>\n";
	print "          <TD>\n";
	printSelectInput("mapprinters", $yesno, $data["mapprinters"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>" . i("Map Local Serial Ports:") . "</TH>\n";
	print "          <TD>\n";
	printSelectInput("mapserial", $yesno, $data["mapserial"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>" . i("RDP Port") . ":</TH>\n";
	print "          <TD>\n";
	print "            <INPUT type=text name=rdpport maxlength=5 ";
	print "size=8 value=\"" . $data["rdpport"] . "\"></TD>\n";
	print "          </TD>\n";
	print "          <TD>\n";
	printSubmitErr(RDPPORTERR);
	print "          </TD>\n";
	print "        </TR>\n";
	print "      </table>\n";
	$cont = addContinuationsEntry('confirmrdpprefs', array(), SECINDAY, 1, 1, 1);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <div align=center>\n";
	print "      <INPUT type=submit value=\"" . i("Submit Changes") . "\">\n";
	print "      </div>\n";
	print "      </FORM>\n";
	print "      </fieldset>\n";

	print "      <div id=uiprefs class=shown>\n";
	print "      <fieldset>\n";
	print "      <legend>" . i("General Preferences") . "</legend>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post ";
	print "onsubmit=\"return validatePublicKeys();\">\n";
	$cdata = array();
	if($user['showallgroups']) {
		$selected['affiliation'] = '';
		$selected['allgroups'] = 'checked';
	}
	else {
		$selected['affiliation'] = 'checked';
		$selected['allgroups'] = '';
	}
	print "      <p>" . i("View User Groups:") . "<br>\n";
	print "      <INPUT type=radio id=r1 name=groupview value=affiliation ";
	print "{$selected['affiliation']}" . "><label for=r1>" . i("matching my affiliation");
	print "</label><br>\n";
	print "      <INPUT type=radio id=r2 name=groupview value=allgroups ";
	print "{$selected['allgroups']}" . "><label for=r2>" . i("from all affiliations");
	print "</label></p>\n";
	if($user['emailnotices']) {
		$selected['enabled'] = 'checked';
		$selected['disabled'] = '';
	}
	else {
		$selected['enabled'] = '';
		$selected['disabled'] = 'checked';
	}
	print "      <p>" . i("Send email notifications about reservations:") . "<br>\n";
	print "      <INPUT type=radio id=r3 name=emailnotify value=2 ";
	print "{$selected['enabled']}" . "><label for=r3>" . i("Enabled");
	print "</label><br>\n";
	print "      <INPUT type=radio id=r4 name=emailnotify value=1 ";
	print "{$selected['disabled']}" . "><label for=r4>" . i("Disabled");
	print "</label></p>\n";

	###########################
	# temporary
	if(! array_key_exists('usepublickeys', $user)) {
		$user['usepublickeys'] = 0;
		$_SESSION['user']['usepublickeys'] = 0;
		$user['sshpublickeys'] = '';
		$_SESSION['user']['sshpublickeys'] = '';
	}
	# end temporary
	###########################

	if($user['usepublickeys']) {
		$selected['enabled'] = 'checked';
		$selected['disabled'] = '';
	}
	else {
		$selected['enabled'] = '';
		$selected['disabled'] = 'checked';
	}
	print "      <p>" . i("Use public key authentication for SSH logins:") . "<br>\n";
	print "      <INPUT type=radio id=r5 name=pubkeyauth value=2 ";
	print "{$selected['enabled']} onclick=\"togglePubKeys(1);\"><label for=r5>";
	print i("Enabled") .  "</label><br>\n";
	print "      <INPUT type=radio id=r6 name=pubkeyauth value=1 ";
	print "{$selected['disabled']} onclick=\"togglePubKeys(0);\"><label for=r6>";
	print i("Disabled") . "</label><br><br>\n";
	print "      " . i("Public keys:") . "<br>\n";
	print "      <div style=\"width: 300px;\" id=\"pubkeyerr\" ";
	print "class=\"hidden\">";
	print "<font color=\"red\"><em>\n      ";
	print i("Public keys can only contain letters, numbers, spaces, and these characters: + / @ . =");
	print "</em></font></div>\n";
	print "      <textarea id=\"pubkeys\" dojoType=\"dijit.form.Textarea\" ";
	print "name=\"pubkeys\" style=\"width: 27em;\"";
	if(! $user['usepublickeys'])
		print " disabled=\"disabled\"";
	print ">{$user['sshpublickeys']}</textarea><br><br>\n";
	print "<strong>" . i("NOTE:") . "</strong> ";
	$h = "      " . i("Images using network storage (such as AFS) may not work well with public key authentication. In some cases, you may still be prompted for a password. In other cases, you may need to run additional commands after logging in to gain access to the network storage.");
	print preg_replace("/(.{1,55}([ \n]|$))/", '\1<br>', $h) . "\n";
	print "      </p>\n";

	$cont = addContinuationsEntry('submitgeneralprefs', $cdata, SECINDAY, 1, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=\"" . i("Submit General Preferences") . "\">\n";
	print "      </FORM>\n";
	print "      </fieldset>\n";
	print "      </div>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	printUserprefJavascript();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmUserPrefs($type)
///
/// \param $type - 0 for personal prefs, 1 for rdp prefs
///
/// \brief prints a page for user to confirm changes to preferences
///
////////////////////////////////////////////////////////////////////////////////
function confirmUserPrefs($type) {
	global $submitErr, $user;

	$data = processUserPrefsInput(1);

	if($submitErr) {
		userpreferences();
		return;
	}

	if($data["audiomode"] == "none")
		$audio = i("None");
	else
		$audio = i("Use my speakers");
	if($data["mapdrives"] == 0)
		$drives = i("No");
	else
		$drives = i("Yes");
	if($data["mapprinters"] == 0)
		$printers = i("No");
	else
		$printers = i("Yes");
	if($data["mapserial"] == 0)
		$serial = i("No");
	else
		$serial = i("Yes");

	print "<div align=center>\n";
	if($type == 0) {
		print "<H2>" . i("Personal Information") . "</H2>\n";
		print "<H3>" . i("Submit the following changes?") . "</H3>\n";
		print "<table>\n";
		print "  <TR>\n";
		print "    <TH align=right>" . i("Preferred Name:") . "</TH>\n";
		print "    <TD>" . $data["preferredname"] . "</TD>\n";
		print "  </TR>\n";
		print "</table>\n";
		if($user['affiliation'] == 'Local' &&
		   ! empty($data['newpassword'])) {
			print i("New password will be submitted") . "<br>\n";
		}
	}
	elseif($type == 1) {
		print "<H2>" . i("RDP Preferences") . "</H2>\n";
		print "<H3>" . i("Submit the following changes?") . "</H3>\n";
		print "<table>\n";
		print "  <TR>\n";
		print "    <TH align=right>" . i("Resolution:") . "</TH>\n";
		print "    <TD>" . $data["resolution"] . "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>" . i("Color Depth:") . "</TH>\n";
		$colordepth = array("8" => "8", "16" => "16", "24" => "24", "32" => "32");
		print "    <TD>" . $colordepth[$data["bpp"]] . "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>" . i("Audio:") . "</TH>\n";
		print "    <TD>$audio</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>" . i("Map Local Drives:") . "</TH>\n";
		print "    <TD>$drives</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>" . i("Map Local Printers:") . "</TH>\n";
		print "    <TD>$printers</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>" . i("Map Local Serial Ports:") . "</TH>\n";
		print "    <TD>$serial</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>" . i("RDP Port") . ":</TH>\n";
		print "    <TD>{$data['rdpport']}</TD>\n";
		print "  </TR>\n";
		print "</table>\n";
	}
	print "<table>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('submituserprefs', $data, SECINWEEK, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=" . i("Submit") . ">\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('userpreferences');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=" . i("Cancel") . ">\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitUserPrefs()
///
/// \brief updates user prefs and prints a page informing the user of success
///
////////////////////////////////////////////////////////////////////////////////
function submitUserPrefs() {
	global $user;
	$data = getContinuationVar();
	if($data["resolution"] == "Full Screen") {
		$width = 0;
		$height = 0;
	}
	else {
		list($width, $height) = explode('x', $data["resolution"]);
		if(! is_numeric($width) || ! is_numeric($height)) {
			$width = 0;
			$height = 0;
		}
	}
	updateUserPrefs($user['id'], $data["preferredname"], $width, $height, 
	                $data["bpp"], $data["audiomode"], $data["mapdrives"],
	                $data["mapprinters"], $data["mapserial"], $data['rdpport']);
	if($user['affiliation'] == 'Local' &&
	   ! empty($data['newpassword'])) {
		$query = "SELECT l.salt "
		       . "FROM localauth l, "
		       .      "user u "
		       . "WHERE u.id = '{$user['id']}' AND "
		       .       "l.userid = u.id";
		$qh = doQuery($query, 101);
		if(! ($row = mysql_fetch_assoc($qh)))
			abort();
		$passhash = sha1("{$data['newpassword']}{$row['salt']}");
		$query = "UPDATE localauth "
		       . "SET passhash = '$passhash' "
		       . "WHERE userid = {$user['id']}";
		doQuery($query, 101);
	}
	$user = getUserInfo($user["id"], 1, 1);
	$_SESSION['user'] = $user;
	userpreferences();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitGeneralPreferences()
///
/// \brief updates user general preferences and calls userpreferences
///
////////////////////////////////////////////////////////////////////////////////
function submitGeneralPreferences() {
	global $user, $HTMLheader, $printedHTMLheader, $mode;
	$groupview = getContinuationVar('groupview', processInputVar('groupview', ARG_STRING));
	$emailnotify = processInputVar('emailnotify', ARG_NUMERIC);
	$pubkeyauth = processInputVar('pubkeyauth', ARG_NUMERIC);
	$pubkeys = processInputVar('pubkeys', ARG_STRING);
	if($groupview != 'affiliation' && $groupview != 'allgroups') {
		$printedHTMLheader = 1;
		print $HTMLheader;
		userpreferences();
		return;
	}
	if($emailnotify != 1 && $emailnotify != 2) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		userpreferences();
		return;
	}
	if($pubkeyauth != 1 && $pubkeyauth != 2) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		userpreferences();
		return;
	}
	if(($groupview == 'allgroups' && $user['showallgroups'] == 0) ||
	   ($groupview == 'affiliation' && $user['showallgroups'] == 1)) {
		if($groupview == 'allgroups')
			$value = 1;
		else
			$value = 0;
		$query = "UPDATE user SET showallgroups = $value WHERE id = {$user['id']}";
		doQuery($query, 101);
		$_SESSION['user']['showallgroups'] = $value;
		$user['showallgroups'] = $value;
	}
	if(($user['emailnotices'] == 1 && $emailnotify == 1) ||
	   ($user['emailnotices'] == 0 && $emailnotify == 2)) {
		$newval = $emailnotify - 1;
		$query = "UPDATE user SET emailnotices = $newval WHERE id = {$user['id']}";
		doQuery($query, 101);
		$_SESSION['user']['emailnotices'] = $newval;
		$user['emailnotices'] = $newval;
	}
	if(($user['usepublickeys'] == 1 && $pubkeyauth == 1) ||
	   ($user['usepublickeys'] == 0 && $pubkeyauth == 2)) {
		$newval = $pubkeyauth - 1;
		$query = "UPDATE user SET usepublickeys = $newval WHERE id = {$user['id']}";
		doQuery($query);
		$_SESSION['user']['usepublickeys'] = $newval;
		$user['usepublickeys'] = $newval;
	}
	if($pubkeyauth == 2 && preg_match('|^[-a-zA-Z0-9\+/ @=\.\n\r]*$|', $pubkeys)) {
		if(get_magic_quotes_gpc())
			$pubkeys = stripslashes($pubkeys);
		$_pubkeys = mysql_real_escape_string($pubkeys);
		$query = "UPDATE user SET sshpublickeys = '$_pubkeys' WHERE id = {$user['id']}";
		doQuery($query);
		$_SESSION['user']['sshpublickeys'] = htmlspecialchars($pubkeys);
		$user['sshpublickeys'] = htmlspecialchars($pubkeys);
	}
	print $HTMLheader;
	$printedHTMLheader = 1;
	$mode = 'submituserprefs';
	# FIXME might need to clear some cache items for cached lists of groups
	userpreferences();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processUserPrefsInput($checks)
///
/// \param $checks - (optional) 1 to perform validation, 0 not to
///
/// \return an array with the following indexes:\n
/// preferredname, resolution, bpp, audiomode, mapdrives, mapprinters,
/// mapserial, unityid
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processUserPrefsInput($checks=1) {
	global $submitErr, $submitErrMsg, $user;
	$return = array();

	$defaultres = $user["width"] . 'x' . $user["height"];
	$return["preferredname"] = processInputVar("preferredname" , ARG_STRING, $user["preferredname"]);
	$return["resolution"] = processInputVar("resolution" , ARG_STRING, $defaultres);
	$return["bpp"] = processInputVar("bpp" , ARG_NUMERIC, $user["bpp"]);
	$return["audiomode"] = processInputVar("audiomode" , ARG_STRING, $user["audiomode"]);
	$return["mapdrives"] = processInputVar("mapdrives" , ARG_NUMERIC, $user["mapdrives"]);
	$return["mapprinters"] = processInputVar("mapprinters" , ARG_NUMERIC, $user["mapprinters"]);
	$return["mapserial"] = processInputVar("mapserial" , ARG_NUMERIC, $user["mapserial"]);
	$return["rdpport"] = processInputVar("rdpport" , ARG_NUMERIC, 3389);

	if(! $checks) {
		return $return;
	}

	if(strlen($return["preferredname"]) > 25) {
	   $submitErr |= PREFNAMEERR;
	   $submitErrMsg[PREFNAMEERR] = i("Preferred name can only be up to 25 characters");
	}
	if(! preg_match('/^[a-zA-Z ]*$/', $return["preferredname"])) {
	   $submitErr |= PREFNAMEERR;
	   $submitErrMsg[PREFNAMEERR] = i("Preferred name can only contain letters and spaces");
	}
	if($user['affiliation'] == 'Local' && array_key_exists('newpassword', $_POST)) {
		$return['newpassword'] = $_POST['newpassword'];
		$confirmpwd = $_POST['confirmpassword'];
		$curr = $_POST['currentpassword'];
		if(get_magic_quotes_gpc()) {
			$return['newpassword'] = stripslashes($return['newpassword']);
			$confirmpwd = stripslashes($confirmpwd);
			$curr = stripslashes($curr);
		}
		if(! empty($return['newpassword']) && ! empty($confirmpwd) &&
		   ! validateLocalAccount($user['unityid'], $curr)) {
			$submitErr |= LOCALPASSWORDERR;
			$submitErrMsg[LOCALPASSWORDERR] = i("Password incorrect");
		}
		elseif((empty($return['newpassword']) && ! empty($confirmpwd)) ||
		   (! empty($return['newpassword']) && empty($confirmpwd)) ||
		   ($return['newpassword'] != $confirmpwd)) {
			$submitErr |= LOCALPASSWORDERR;
			$submitErrMsg[LOCALPASSWORDERR] = i("Passwords do not match");
		}
	}
	if(array_key_exists('preferredname', $_POST) ||
		array_key_exists('newpassword', $_POST))
		$return['rdpport'] = $user['rdpport'];

	if($return['rdpport'] != $user['rdpport']) {
		$requests = getUserRequests('all');
		$nochange = 0;
		foreach($requests as $req) {
			if(preg_match('/^(3|8|10|24|25|26|27|28|29)$/', $req['currstateid']) ||
			   ($req['currstateid'] == 14 &&
				preg_match('/^(3|8|10|24|25|26|27|28|29)$/', $req['laststateid']))) {
				$nochange = 1;
				break;
			}
		}
		if($nochange) {
			$submitErr |= RDPPORTERR;
			$submitErrMsg[RDPPORTERR] = i("RDP Port cannot be changed while you have active reservations");
		}
	}
	if(! ($submitErr & RDPPORTERR) &&
	   ($return['rdpport'] < 1024 || $return['rdpport'] > 65535)) {
		$submitErr |= RDPPORTERR;
		$submitErrMsg[RDPPORTERR] = i("RDP Port must be between 1024 and 65535");
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printUserprefJavascript()
///
/// \brief prints javascript used in user preferences page
///
////////////////////////////////////////////////////////////////////////////////
function printUserprefJavascript() {
	global $submitErr;
	print <<<HTMLdone
<script type="text/javascript">
function show(id) {
	var obj = document.getElementById("personal");
	if(obj)
		obj.className = "hidden";
	document.getElementById("rdpfile").className = "hidden";
	document.getElementById("uiprefs").className = "hidden";
	document.getElementById("status").className = "hidden";
	if(id == 'personal' && ! obj)
		id = 'rdpfile';
	document.getElementById(id).className = "shown";
}
function validatePublicKeys() {
	var data = dijit.byId('pubkeys').value;
	var patt = /^[-a-zA-Z0-9\+/ @=\.\\n]{0,65535}$/;
	if(! patt.test(data)) {
		dojo.removeClass('pubkeyerr', 'hidden');
		return false;
	}
	dojo.addClass('pubkeyerr', 'hidden');
	return true;
}
function togglePubKeys(mode) {
	if(mode)
		dijit.byId('pubkeys').set('disabled', false);
	else
		dijit.byId('pubkeys').set('disabled', true);
}

HTMLdone;
	if(! ($submitErr & PREFNAMEERR) && 
		! ($submitErr & LOCALPASSWORDERR) &&
	   ($submitErr & RDPPORTERR))
		print "show(\"rdpfile\");\n";
	else
		print "show(\"personal\");\n";
	print <<<HTMLdone
document.getElementById("preflinks").className = "shown";
document.getElementById("status").className = "visible";
</script>

HTMLdone;
}
?>
