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
define("NAMEERR", 1);
/// signifies an error with the submitted image
define("IMAGEERR", 1 << 1);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn newOneClick()
///
/// \brief prints form for submitting a new OneClick
///
////////////////////////////////////////////////////////////////////////////////
function newOneClick() {
	global $user, $mode, $submitErr;

	if($submitErr) {
		$imageid = processInputVar("imageid", ARG_NUMERIC);
		$length = processInputVar("length", ARG_NUMERIC);
		$autologin = processInputVar("autologin", ARG_NUMERIC) == 1 ? 1 : 0;
	}
	else {
		$imageid = getUsersLastImage($user['id']);
		$length = 120;
		$autologin = 0;
	}

	$query = "SELECT o.id, "
	       .        "o.name, "
	       .        "o.duration, "
	       .        "o.autologin, "
	       .        "i.prettyname AS imagename "
	       . "FROM oneclick o "
	       . "LEFT JOIN image i ON (o.imageid = i.id) "
	       . "WHERE o.status = 1 AND "
	       .       "o.userid = {$user['id']}";
	$oneclicks = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$oneclicks[$row['id']] = $row;

	print "<H2>" . i("VCL go Configurator") . "</H2>\n";

	printf(i("VCL gos are for use with the %sVCL iOS app%s. VCL gos can be managed here but can only be used from an iOS device.") . "<br><br>\n", "<a href=\"https://itunes.apple.com/us/app/vcl-go/id1068500147?mt=8\">", "</a>");

	if(count($oneclicks)) {
		if($mode == 'submitEditOneClick' || $mode == 'deleteOneClick') {
			$tab1sel = "";
			$tab2sel = "selected=\"true\"";
		}
		else {
			$tab1sel = "selected=\"true\"";
			$tab2sel = "";
		}
		print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
		print "     style=\"width:800px;height:600px\">\n";

		print "<div id=\"newOneClick\" dojoType=\"dijit.layout.ContentPane\" ";
		print "title=\"" . i("New VCL go Configuration") . "\" $tab1sel>\n";
	}

	if(! $submitErr && $mode == 'submitOneClick')
		print "<br><font color=\"#008000\">" . i("VCL go successfully created") . "</font><br>\n";

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post onsubmit=\"return validateForm(this);\" >\n";
	# name of OneClick
	print "<br>\n";
	print i("Choose a name for your new VCL go configuration") . "<br>\n";
	printSubmitErr(NAMEERR);
	print "<strong>" . i("Name:") . "</strong>\n";
	print "<input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
	print "id=\"newOneClickName\" name=\"newOneClickName\" required=\"true\" invalidMessage=\"";
	print i("Name can only contain letters, numbers, spaces, dashes(-), parenthesis, <br>and periods(.) and can be from 3 to 70 characters long");
	print "\" regExp=\"^([-a-zA-Z0-9\. \(\)]){3,70}$\" style=\"width: 300px\">";
	print "<br><br>\n";

	# resources; image types
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);

	print i("Please select the resource you want to use from the list:") . "<br>\n";
	printSubmitErr(IMAGEERR);
	print "<br>\n";
	$images = getImages();
	# list of images
	print "<select name=\"imageid\">\n";
	foreach($resources['image'] as $id => $image)
		if($id == $imageid)
			print "  <option value=\"$id\" selected>$image</option>\n";
		else
			print "  <option value=\"$id\">$image</option>\n";
	print "</select>\n";
	print "<br><br>\n";

	# list of duration of the reservation from this OneClick
	if(array_key_exists($imageid, $images))
		$maxlength = $images[$imageid]['maxinitialtime'];
	else
		$maxlength = 0;
	# create an array of usage times based on the user's max times
	$maxtimes = getUserMaxTimes();
	if($maxlength > 0 && $maxlength < $maxtimes['initial'])
		$maxtimes['initial'] = $maxlength;
	$lengths = array();
	if($maxtimes["initial"] >= 30)
		$lengths["30"] = "30 " . i("minutes");
	if($maxtimes["initial"] >= 60)
		$lengths["60"] = "1 " . i("hour");
	for($i = 120; $i <= $maxtimes["initial"] && $i < 2880; $i += 60)
		$lengths[$i] = $i / 60 . " " . i("hours");
	for($i = 2880; $i <= $maxtimes["initial"]; $i += 1440)
		$lengths[$i] = $i / 1440 . " " . i("days");
	$last = $i;
	print "<strong>" . i("Duration:") . "</strong>&nbsp;\n";
	printSelectInput("length", $lengths, $length, 0, 0, 'reqlength');
	print "<br><br>\n";

	# other choice
	print "<INPUT type=\"checkbox\" name=\"autologin\" value=\"1\"" . ($autologin == 1 ? "checked=\"checked\"" : "") . ">";
	print i("Auto Login");
	print "<br><br>\n";

	# submit button
	$cdata = array('maxlength' => $last);
	$cont = addContinuationsEntry('submitOneClick', $cdata, SECINDAY, 1, 0);
	print "<INPUT type=\"hidden\" name=\"continuation\" value=\"$cont\">\n";
	print "<INPUT type=\"submit\" value=\"" . i("Create VCL go Configuration") . "\">\n";

	print "</FORM>\n";
	# end of first tab
	print "</div>\n";

	if(count($oneclicks)) {
		# the tab that list all the OneClicks the user have
		print "<div id=\"listOneClick\" dojoType=\"dijit.layout.ContentPane\" ";
		print "title=\"" . i("List of VCL go Configurations") . "\" $tab2sel>\n";
		if($mode == 'submitEditOneClick') {
			print "<br><font color=\"#008000\">" . i("VCL go successfully updated");
			print "</font><br><br>\n";
		}
		elseif($mode == 'deleteOneClick') {
			print "<br><font color=\"#008000\">" . i("VCL go successfully deleted");
			print "</font><br><br>\n";
		}
	}

	foreach($oneclicks as $oneclick) {
		print "<fieldset id=\"list\" class=\"oneclicklist\">\n";

		print i("VCL go Name:") . "\n";
		$oneclickname = $oneclick['name'];
		print "<strong>" . htmlentities($oneclickname) . "</strong>\n";
		print "<br><br>\n";

		$oneclickid = $oneclick['id'];

		print i("Resource:") . " <strong>" . htmlentities($oneclick['imagename']) . "</strong><br>\n";
		# Duration
		$duration = $oneclick['duration'];
		if($duration < 60) {
			print i("Duration:") . " <strong>" . $duration . " " . i("minutes") . "</strong><br>\n";
		}
		else {
			if($duration < (60 * 24)) {
				$hourduration = (int) $duration / 60;
				print i("Duration:") . " <strong>" . $hourduration . " " . i("hour") . ($hourduration == 1 ? "" : "s") . "</strong><br>";
			}
			else {
				$dayduration = (int) $duration / (60 * 24);
				print i("Duration:") . " <strong>" . $dayduration . " " . i("day") . ($dayduration == 1 ? "" : "s") . "</strong><br>";
			}
		}
		print i("Auto Login") . ": <strong>" . ($oneclick['autologin'] == 1 ? i("Yes") : i("No")) . "</strong><br>\n";
		print "<br>\n";

		$cdata = array('oneclickid' => $oneclickid,
		               'oneclickname' => $oneclickname,
		               'maxlength' => $last);

		# edit button
		print "<form action=\"" . BASEURL . SCRIPT . "\" method=\"post\" style=\"display: inline;\">\n";
		$cont = addContinuationsEntry('editOneClick', $cdata, SECINDAY, 1);
		print "<input type=\"hidden\" name=\"continuation\" value=\"$cont\">\n";
		print "<input type=\"submit\" value=\"" . i("Edit VCL go") . "\">\n";
		print "</form>\n";

		# Delete button
		print "<form action=\"" . BASEURL . SCRIPT . "\" method=\"post\" style=\"display: inline;\">\n";
		$cont = addContinuationsEntry('deleteOneClick', $cdata, SECINDAY, 1);
		print "<input type=\"hidden\" name=\"continuation\" value=\"$cont\">\n";
		print "<input type=\"submit\" value=\"" . i("Delete") . "\">\n";
		print "</form>\n";

		print "</fieldset>\n";
		print "<br><br>\n";
	}
	if(count($oneclicks)) {
		print "</div>\n";
		print "</div>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitOneClick()
///
/// \to create one Button from Web Configurator
///
////////////////////////////////////////////////////////////////////////////////
function submitOneClick() {
	global $user, $submitErr, $submitErrMsg;
	$maxlength = getContinuationVar('maxlength');
	$imageid = processInputVar("imageid", ARG_NUMERIC);
	$name = processInputVar("newOneClickName", ARG_STRING);
	$duration = processInputVar("length", ARG_NUMERIC);
	$autologin = processInputVar("autologin", ARG_NUMERIC) == 1 ? 1 : 0;

	# validate access to $imageid
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources["image"]);
	if(! array_key_exists($imageid, $images)) {
	   $submitErr |= IMAGEERR;
	   $submitErrMsg[IMAGEERR] = i("Invalid image submitted.");
	}

	# validate $name
	if(! preg_match('/^([-a-zA-Z0-9\. \(\)]){3,70}$/', $name)) {
	   $submitErr |= NAMEERR;
	   $submitErrMsg[NAMEERR] = i("Name can only contain letters, numbers, spaces, dashes(-), parenthesis, <br>and periods(.) and can be from 3 to 70 characters long");
	}

	if($submitErr) {
		newOneClick();
		return;
	}

	if($duration > $maxlength)
		$duration = $maxlength;

	$query = "INSERT INTO oneclick"
	       .        "(userid, "
	       .        "imageid, "
	       .        "name, "
	       .        "duration, "
	       .        "autologin, "
	       .        "status) "
	       . "VALUES "
	       .        "({$user['id']}, "
	       .        "$imageid, "
	       .        "'$name', "
	       .        "$duration, "
	       .        "$autologin, "
	       .        "1) ";
	doQuery($query, 101);

	newOneClick();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deleteOneClick()
///
/// \to delete one Button from Web Configurator
///
////////////////////////////////////////////////////////////////////////////////
function deleteOneClick() {
	$oneclickid = getContinuationVar('oneclickid');
	$query = "UPDATE oneclick SET status = 0 WHERE id = $oneclickid";
	doQuery($query, 150);
	newOneClick();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editOneClick()
///
/// \to edit one Button from Web Configurator
///
////////////////////////////////////////////////////////////////////////////////
function editOneClick() {
	global $user, $submitErr;
	$oneclickid = getContinuationVar('oneclickid');

	if($submitErr)
		$delfromself = 1;
	else
		$delfromself = 0;

	$query = "SELECT o.imageid, "
	       .        "o.name, "
	       .        "o.duration, "
	       .        "o.autologin, "
	       .        "i.prettyname AS imagename, "
	       .        "i.id AS imageid "
	       . "FROM oneclick o "
	       . "LEFT JOIN image i ON (o.imageid = i.id) "
	       . "WHERE o.status = 1 AND "
	       .       "o.id = $oneclickid AND "
	       .       "o.userid = {$user['id']}";

	$qh = doQuery($query, 101);
	print "<form action=\"" . BASEURL . SCRIPT . "\" method=\"post\" style=\"display: inline;\" onsubmit=\"return validateForm(this);\">\n";

	if(! ($row = mysql_fetch_assoc($qh))) {
		print i("VCL go not found") . "\n";
		return NULL;
	}

	print "<h2>" . i("VCL go Editor") . "</h2>\n";

	print "<br>\n";
	# infomations
	# Name
	printSubmitErr(NAMEERR);
	print i("VCL go Name:") . " \n";
	print "<input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
	print "id=\"name\" name=\"name\" required=\"true\" invalidMessage=\"";
	print i("Name can only contain letters, numbers, spaces, dashes(-), parenthesis, <br>and periods(.) and can be from 3 to 70 characters long");
	print "\" regExp=\"^([-a-zA-Z0-9\. \(\)]){3,70}$\" style=\"width: 300px\" ";
	print "value=\"" . htmlentities($row['name']) . "\">\n";
	print "<br><br>\n";
	# Image
	print i("Resource:") . " <strong>" . htmlentities($row['imagename']) . "</strong><br>\n";
	print "<br>\n";

	# Duration
	$preduration = $row['duration'];
	$images = getImages(0, $row['imageid']);
	$maxlength = $images[$row['imageid']]['maxinitialtime'];
	$maxtimes = getUserMaxTimes();
	if($maxlength == 0 || $maxlength < 0)
		$maxlength = $maxtimes['initial'];
	else
		$maxlength = $maxtimes['initial'] > $maxlength ? $maxlength : $maxtimes['initial'];
	$iteri = 30;
	print "<strong>" . i("Duration:") . "</strong>\n";
	print "  <select name=\"duration\">\n";
	for($iteri = 30; $iteri <= $maxlength; $iteri+=60) {
		if($iteri == 30) {
			print "<option value=\"$iteri\" " . ($iteri == $preduration ? "selected" : "") . ">30 " . i("minutes") . "</option>\n";
			$iteri+=30;
		}
		if($iteri >= 60 && $iteri < 1440) {
			$temphour = (int) $iteri / 60;
			if($temphour == 1)
				print "<option value=\"$iteri\" " . ($iteri == $preduration ? "selected" : "") . ">$temphour " . i("hour") . "</option>\n";
			else
				print "<option value=\"$iteri\" " . ($iteri == $preduration ? "selected" : "") . ">$temphour " . i("hours") . "</option>\n";
			continue;
		}
		if($iteri > 1440) {
			$tempday = (int) $iteri / 1440;
			if($tempday == 1)
				print "<option value=\"$iteri\" " . ($iteri == $preduration ? "selected" : "") . ">$tempday " . i("day") . "</option>\n";
			else
				print "<option value=\"$iteri\" " . ($iteri == $preduration ? "selected" : "") . ">$tempday " . i("days") . "</option>\n";
			continue;
		}
	}
	print "  </select>\n";
	print "<br><br>\n";
	# Auto Login
	print "<INPUT type=\"checkbox\" name=\"autologin\" value=\"1\"" . ($row['autologin'] == 1 ? "checked=\"checked\"" : "") . ">";
	print i("Auto Login");
	print "<br><br>\n";
	# submit
	$cdata = array('oneclickid' => $oneclickid,
	               'maxlength' => $maxlength);
	$cont = addContinuationsEntry('submitEditOneClick', $cdata, SECINDAY, $delfromself, 0);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=\"" . i("Submit Changes") . "\">\n";
	print "</form>\n";
	# cancel
	print "<form action=\"" . BASEURL . SCRIPT . "\" method=\"post\" style=\"display: inline;\">\n";
	$cont = addContinuationsEntry('newOneClick', array(), SECINDAY);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=\"" . i("Cancel") . "\">\n";
	print "</form>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditOneClick()
///
/// \to submit the change to one Button
///
////////////////////////////////////////////////////////////////////////////////
function submitEditOneClick() {
	global $submitErr, $submitErrMsg;
	$oneclickid = getContinuationVar('oneclickid');
	$maxlength = getContinuationVar('maxlength');
	$name = processInputVar('name', ARG_STRING);
	$duration = processInputVar("duration", ARG_NUMERIC);
	$autologin = processInputVar("autologin", ARG_NUMERIC) == 1 ? 1 : 0;

	# validate $name
	if(! preg_match('/^([-a-zA-Z0-9\. \(\)]){3,70}$/', $name)) {
	   $submitErr |= NAMEERR;
	   $submitErrMsg[NAMEERR] = i("Name can only contain letters, numbers, spaces, dashes(-), parenthesis, <br>and periods(.) and can be from 3 to 70 characters long");
		editOneClick();
		return;
	}

	# validate $duration
	if($duration > $maxlength)
		$duration = $maxlength;

	$query = "UPDATE oneclick "
	       . "SET duration = $duration, "
	       .     "name = '$name', "
	       .     "autologin = $autologin "
	       . "WHERE id = $oneclickid";
	doQuery($query, 150);
	newOneClick();
}
?>
