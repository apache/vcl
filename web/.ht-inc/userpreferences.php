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
/// signifies an error with submitted viewasuser id
define("VIEWASUSERERR", 1 << 3);
/// signifies an error with submitted new password
define("LOCALPASSWORDERR", 1 << 4);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn userpreferences()
///
/// \brief prints a page for a user to edit his preferences
///
////////////////////////////////////////////////////////////////////////////////
function userpreferences() {
	global $user, $submitErr, $viewmode, $mode;
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

	$adminleveldeveloper = 0;
	if($user['adminlevelid'] == ADMIN_DEVELOPER)
		$adminleveldeveloper = 1;


	print "<H2 align=center>User Preferences</H2>\n";
	print "<div align=center id=status class=visible>\n";
	if($mode == "submituserprefs") {
		print "<font color=green>User preferences successfully updated</font><br>\n";
	}
	print "</div>\n";
	print "<table id=layouttable summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD>\n";
	print "      <div id=preflinks class=hidden>\n";
	print "      <ul class=preferenceslist>\n";
	print "      <li><a href=#personal onclick=\"";
	print "show('personal'); return false;\">Personal&nbsp;Information</a>";
	print "</li>\n";
	print "      <li><a href=#rdpfile onclick=\"";
	print "show('rdpfile'); return false;\">RDP&nbsp;File&nbsp;Preferences</a>";
	print "</li>\n";
	print "      <li><a href=#uiprefs onclick=\"javascript:show('uiprefs'); ";
	print "return false\">General&nbsp;Preferences</a></li>\n";
	if($adminleveldeveloper) {
		print "      <li><a href=#viewmode onclick=\"javascript:";
		print "show('viewmode'); return false\">View&nbsp;Mode</a></li>\n";
	}
	print "      </ul>\n";
	print "      </div>\n";
	print "    </TD>\n";
	print "    <TD rowspan=2 width=50px></TD>\n";
	print "    <TD rowspan=2>\n";
	print "      <fieldset id=personal class=shown>\n";
	print "      <legend>Personal</legend>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <table summary=\"displays your personal information\">\n";
	print "        <TR>\n";
	print "          <TH align=right>First Name<a href=#updateinfo>*</a>:</TH>\n";
	print "          <TD>" . $user["firstname"] . "</TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>Last Name<a href=#updateinfo>*</a>:</TH>\n";
	print "          <TD>" . $user["lastname"] . "</TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>Preferred Name:</TH>\n";
	print "          <TD><label class=hidden for=preferredname>Preferred Name</label>\n";
	print "              <INPUT type=text name=preferredname maxlength=100 ";
	print "size=15 value=\"" . $data["preferredname"] . "\"></TD>\n";
	print "          <TD>";
	printSubmitErr(PREFNAMEERR);
	print "</TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>Email Address<a href=#updateinfo>*</a>:</TH>\n";
	print "          <TD>" . $user["email"] . "</TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	if($user['affiliation'] == 'Local') {
		print "        <TR>\n";
		print "          <TD colspan=3 align=center><h3>Change Password</h3></TD>\n";
		print "        </TR>\n";
		print "        <TR>\n";
		print "          <TH align=right>Current Password:</TH>\n";
		print "          <TD>\n";
		print "            <label class=hidden for=currentpassword>Current Password</label>\n";
		print "            <INPUT type=password name=currentpassword maxlength=100 size=15>\n";
		print "          </TD>\n";
		print "          <TD>";
		printSubmitErr(LOCALPASSWORDERR);
		print "</TD>\n";
		print "        </TR>\n";
		print "        <TR>\n";
		print "          <TH align=right>New Password:</TH>\n";
		print "          <TD>\n";
		print "            <label class=hidden for=newpassword>New Password</label>\n";
		print "            <INPUT type=password name=newpassword maxlength=100 ";
		print "id=newpassword onkeyup=\"checkNewLocalPassword();\" size=15>\n";
		print "          </TD>\n";
		print "          <TD></TD>\n";
		print "        </TR>\n";
		print "        <TR>\n";
		print "          <TH align=right>Confirm Password:</TH>\n";
		print "          <TD>\n";
		print "            <label class=hidden for=confirmpassword>Confirm Password</label>\n";
		print "            <INPUT type=password name=confirmpassword maxlength=100 ";
		print "id=confirmpassword onkeyup=\"checkNewLocalPassword();\" size=15>\n";
		print "          </TD>\n";
		print "          <TD><span id=pwdstatus></span></TD>\n";
		print "        </TR>\n";
	}
	print "      </table>\n";
	$updateText = getAffiliationDataUpdateText($user['affiliationid']);
	print "<a name=updateinfo></a>\n";
	if(! empty($updateText[$user['affiliationid']]))
		print "{$updateText[$user['affiliationid']]}<br><br>";
	$cont = addContinuationsEntry('confirmpersonalprefs', array(), SECINDAY, 1, 1, 1);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <div align=center>\n";
	print "      <INPUT type=submit value=\"Submit Changes\">\n";
	print "      </div>\n";
	print "      </FORM>\n";
	print "      </fieldset>\n";

	print "      <fieldset id=rdpfile class=visible>\n";
	print "      <legend>RDP</legend>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <table summary=\"lists adjustable preferences for the RDP ";
	print "file that is sent when you click the Get RDP File button on the ";
	print "Connect! page\">\n";
	print "        <TR>\n";
	print "          <TD colspan=3><small>Try decreasing <em>Resolution</em> or <em>";
	print "Color Depth</em> to<br>speed up your connection if things seem ";
	print "slow<br>when connected to a remote computer.</small></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>Resolution:</TH>\n";
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
	print "          <TH align=right>Color Depth:</TH>\n";
	print "          <TD>\n";
	#$colordepth = array("8" => "8", "16" => "16", "24" => "24");
	$colordepth = array("8" => "8", "16" => "16", "24" => "24", "32" => "32 (Vista only)");
	printSelectInput("bpp", $colordepth, $data["bpp"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>Audio:</TH>\n";
	print "          <TD>\n";
	$audio = array("none" => "None", "local" => "Use my speakers");
	printSelectInput("audiomode", $audio, $data["audiomode"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>Map Local Drives:</TH>\n";
	print "          <TD>\n";
	$yesno = array(1 => "Yes", 0 => "No");
	printSelectInput("mapdrives", $yesno, $data["mapdrives"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>Map Local Printers:</TH>\n";
	print "          <TD>\n";
	printSelectInput("mapprinters", $yesno, $data["mapprinters"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "        <TR>\n";
	print "          <TH align=right>Map Local Serial Ports:</TH>\n";
	print "          <TD>\n";
	printSelectInput("mapserial", $yesno, $data["mapserial"]);
	print "          </TD>\n";
	print "          <TD></TD>\n";
	print "        </TR>\n";
	print "      </table>\n";
	$cont = addContinuationsEntry('confirmrdpprefs', array(), SECINDAY, 1, 1, 1);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <div align=center>\n";
	print "      <INPUT type=submit value=\"Submit Changes\">\n";
	print "      </div>\n";
	print "      </FORM>\n";
	print "      </fieldset>\n";

	print "      <div id=uiprefs class=visible>\n";
	print "      <fieldset>\n";
	print "      <legend>General Preferences</legend>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array();
	if(in_array("userGrant", $user["privileges"])) {
		if($user['showallgroups']) {
			$selected['affiliation'] = '';
			$selected['allgroups'] = 'checked';
		}
		else {
			$selected['affiliation'] = 'checked';
			$selected['allgroups'] = '';
		}
		print "      <p>View User Groups:<br>\n";
		print "      <INPUT type=radio id=r1 name=groupview value=affiliation ";
		print "{$selected['affiliation']}><label for=r1>matching my affiliation";
		print "</label><br>\n";
		print "      <INPUT type=radio id=r2 name=groupview value=allgroups ";
		print "{$selected['allgroups']}><label for=r2>from all affiliations";
		print "</label></p>\n";
	}
	else
		$cdata['groupview'] = 'affiliation';
	if($user['emailnotices']) {
		$selected['enabled'] = 'checked';
		$selected['disabled'] = '';
	}
	else {
		$selected['enabled'] = '';
		$selected['disabled'] = 'checked';
	}
	print "      <p>Send email notifications about reservations:<br>\n";
	print "      <INPUT type=radio id=r3 name=emailnotify value=2 ";
	print "{$selected['enabled']}><label for=r3>Enabled";
	print "</label><br>\n";
	print "      <INPUT type=radio id=r4 name=emailnotify value=1 ";
	print "{$selected['disabled']}><label for=r4>Disabled";
	print "</label></p>\n";
	$cont = addContinuationsEntry('submitgeneralprefs', $cdata, SECINDAY, 1, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=\"Submit General Preferences\">\n";
	print "      </FORM>\n";
	print "      </fieldset>\n";
	print "      </div>\n";
	print "      <div id=viewmode class=visible>\n";
	if($adminleveldeveloper) {
		print "      <fieldset>\n";
		print "      <legend>View Mode</legend>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		if($viewmode == ADMIN_FULL) {
			$selected[ADMIN_NONE] = "";
			$selected[ADMIN_FULL] = "checked";
			$selected[ADMIN_DEVELOPER] = "";
		}
		elseif($viewmode == ADMIN_DEVELOPER) {
			$selected[ADMIN_NONE] = "";
			$selected[ADMIN_FULL] = "";
			$selected[ADMIN_DEVELOPER] = "checked";
		}
		else {
			$selected[ADMIN_NONE] = "checked";
			$selected[ADMIN_FULL] = "";
			$selected[ADMIN_DEVELOPER] = "";
		}
		if($user["adminlevelid"] != ADMIN_NONE) {
			print "      <p>View site as:<br>\n";
			print "      <INPUT type=radio name=viewmode value=" . ADMIN_NONE . " ";
			print $selected[ADMIN_NONE] . ">Normal User<br>\n";
			if($user["adminlevel"] == "full" || $user["adminlevel"] == "developer") {
				print "      <INPUT type=radio name=viewmode value=" . ADMIN_FULL . " ";
				print $selected[ADMIN_FULL] . ">Admin Level<br>\n";
			}
			if($user["adminlevel"] == "developer") {
				print "      <INPUT type=radio name=viewmode value=" . ADMIN_DEVELOPER . " ";
				print $selected[ADMIN_DEVELOPER] . ">Developer Level<br>\n";
			}
			print "      </p>\n";
		}
		print "      View As User: <INPUT type=text name=viewasuser  ";
		if(! array_key_exists('unityid', $data))
			print "size=20 value=\"{$user["unityid"]}@{$user['affiliation']}\">\n";
		else
			print "size=20 value=\"{$data["unityid"]}@{$data['affiliation']}\">\n";
		printSubmitErr(VIEWASUSERERR);
		print "<br>\n";
		$cont = addContinuationsEntry('submitviewmode', array(), SECINDAY, 1, 0);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=\"Submit View Mode\">\n";
		print "      </FORM>\n";
		print "      </fieldset>\n";
	}
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
		$audio = "None";
	else
		$audio = "Use my speakers";
	if($data["mapdrives"] == 0)
		$drives = "No";
	else
		$drives = "Yes";
	if($data["mapprinters"] == 0)
		$printers = "No";
	else
		$printers = "Yes";
	if($data["mapserial"] == 0)
		$serial = "No";
	else
		$serial = "Yes";

	print "<DIV align=center>\n";
	if($type == 0) {
		print "<H2>Personal Information</H2>\n";
		print "<H3>Submit the following changes?</H3>\n";
		print "<table>\n";
		print "  <TR>\n";
		print "    <TH align=right>Preferred Name:</TH>\n";
		print "    <TD>" . $data["preferredname"] . "</TD>\n";
		print "  </TR>\n";
		print "</table>\n";
		if($user['affiliation'] == 'Local' &&
		   ! empty($data['newpassword'])) {
			print "New password will be submitted<br>\n";
		}
	}
	elseif($type == 1) {
		print "<H2>RDP File Preferences</H2>\n";
		print "<H3>Submit the following changes?</H3>\n";
		print "<table>\n";
		print "  <TR>\n";
		print "    <TH align=right>Resolution:</TH>\n";
		print "    <TD>" . $data["resolution"] . "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Color Depth:</TH>\n";
		$colordepth = array("8" => "8", "16" => "16", "24" => "24", "32" => "32 (Vista only)");
		print "    <TD>" . $colordepth[$data["bpp"]] . "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Audio:</TH>\n";
		print "    <TD>$audio</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Map Local Drives:</TH>\n";
		print "    <TD>$drives</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Map Local Printers:</TH>\n";
		print "    <TD>$printers</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Map Local Serial Ports:</TH>\n";
		print "    <TD>$serial</TD>\n";
		print "  </TR>\n";
		print "</table>\n";
	}
	print "<table>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('submituserprefs', $data, SECINWEEK, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('userpreferences');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
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
	else
		list($width, $height) = explode('x', $data["resolution"]);
	if(updateUserPrefs($user['id'], $data["preferredname"], $width, $height, 
	                   $data["bpp"], $data["audiomode"], $data["mapdrives"],
	                   $data["mapprinters"], $data["mapserial"])) {
	}
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
	$user = getUserInfo($user["id"]);
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
	global $user, $HTMLheader, $printedHTMLheader, $mode, $viewmode;
	$groupview = getContinuationVar('groupview', processInputVar('groupview', ARG_STRING));
	$emailnotify = processInputVar('emailnotify', ARG_NUMERIC);
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
	if(array_key_exists('WRAP_USERID', $_SERVER) && ($user['unityid'] != $_SERVER["WRAP_USERID"]))
		$return["unityid"] = processInputVar("viewasuser" , ARG_STRING, "{$user["unityid"]}@{$user['affiliation']}");
	else
		$return['unityid'] = "{$user['unityid']}@{$user['affiliation']}";

	if(! $checks) {
		return $return;
	}

	if(strlen($return["preferredname"]) > 25) {
	   $submitErr |= PREFNAMEERR;
	   $submitErrMsg[PREFNAMEERR] = "Preferred name can only be up to 25 characters";
	}
	if(! ereg('^[a-zA-Z ]*$', $return["preferredname"])) {
	   $submitErr |= PREFNAMEERR;
	   $submitErrMsg[PREFNAMEERR] = "Preferred name can only contain letters and spaces";
	}
	if(array_key_exists('unityid', $return) &&
	   ! validateUserid($return['unityid'])) {
	   $submitErr |= VIEWASUSERERR;
	   $submitErrMsg[VIEWASUSERERR] = "Invalid user id";
	}
	if($user['affiliation'] == 'Local') {
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
			$submitErrMsg[LOCALPASSWORDERR] = "Password incorrect";
		}
		elseif((empty($return['newpassword']) && ! empty($confirmpwd)) ||
		   (! empty($return['newpassword']) && empty($confirmpwd)) ||
		   ($return['newpassword'] != $confirmpwd)) {
			$submitErr |= LOCALPASSWORDERR;
			$submitErrMsg[LOCALPASSWORDERR] = "Passwords do not match";
		}
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
	print <<<HTMLdone
<script type="text/javascript">
function show(id) {
	document.getElementById("personal").className = "hidden";
	document.getElementById("rdpfile").className = "hidden";
	document.getElementById("uiprefs").className = "hidden";
	document.getElementById("viewmode").className = "hidden";
	document.getElementById("status").className = "hidden";
	document.getElementById(id).className = "shown";
}
show("personal");
document.getElementById("preflinks").className = "shown";
document.getElementById("status").className = "visible";
</script>

HTMLdone;
}
?>
