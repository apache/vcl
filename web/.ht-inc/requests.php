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
/// signifies an error with the submitted start date
define("STARTDAYERR", 1);
/// signifies an error with the submitted start hour
define("STARTHOURERR", 1 << 1);
/// signifies an error with the submitted start minute
define("STARTMINUTEERR", 1 << 2);
/// signifies an error with the submitted end date
//define("ENDDAYERR", 1 << 2);
/// signifies an error with the submitted end hour
//define("ENDHOURERR", 1 << 3);
/// signifies an error with the submitted endding date and time
define("ENDDATEERR", 1 << 4);
/// signifies an error with the submitted image id
define("IMAGEIDERR", 1 << 5);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn newReservation()
///
/// \brief prints form for submitting a new reservation
///
////////////////////////////////////////////////////////////////////////////////
function newReservation() {
	global $submitErr, $user, $mode, $skin;
	$timestamp = processInputVar("stamp", ARG_NUMERIC);
	$imageid = processInputVar("imageid", ARG_STRING, getUsersLastImage($user['id']));
	$length = processInputVar("length", ARG_NUMERIC);
	$day = processInputVar("day", ARG_STRING);
	$hour = processInputVar("hour", ARG_NUMERIC);
	$minute = processInputVar("minute", ARG_NUMERIC);
	$meridian = processInputVar("meridian", ARG_STRING);
	$imaging = getContinuationVar('imaging', processInputVar('imaging', ARG_NUMERIC, 0));

	if(! $submitErr) {
		if($imaging)
			print "<H2>Create / Update an Image</H2>\n";
		else
			print _("<H2>New Reservation</H2><br>\n");
	}

	if($imaging) {
		$resources = getUserResources(array("imageAdmin"));
		if(empty($resources['image'])) {
			print "You don't have access to any base images from which to create ";
			print "new images.<br>\n";
			return;
		}
		if($length == '')
			$length = 480;
	}
	else {
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
		$resources["image"] = removeNoCheckout($resources["image"]);
	}

	if((! in_array("imageCheckOut", $user["privileges"]) &&
	   ! in_array("imageAdmin", $user["privileges"])) ||
	   empty($resources['image'])) {
		print _("You don't have access to any environments and, therefore, cannot ");
		print _("make any reservations.<br>\n");
		return;
	}
	if($imaging) {
		print "Please select the environment you will be updating or using as a ";
		print "base for a new image:<br>\n";
	}
	else
		print _("Please select the environment you want to use from the list:<br>\n");

	$images = getImages();
	$maxTimes = getUserMaxTimes();
	if(! $imaging) {
		print "<script language=javascript>\n";
		print "var defaultMaxTime = {$maxTimes['initial']};\n";
		print "var maxTimes = {\n";
		foreach(array_keys($resources['image']) as $imgid) {
			if(array_key_exists($imgid, $images))
				print "   $imgid: {$images[$imgid]['maxinitialtime']},\n";
		}
		print "   0: 0\n"; // this is because IE doesn't like the last item having a ',' after it
		print "};\n";
		print "</script>\n";
	}

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	// list of images
	uasort($resources["image"], "sortKeepIndex");
	printSubmitErr(IMAGEIDERR);
	if($submitErr & IMAGEIDERR)
		print "<br>\n";
	if($imaging) {
		if(USEFILTERINGSELECT && count($resources['image']) < FILTERINGSELECTTHRESHOLD) {
			print "      <select dojoType=\"dijit.form.FilteringSelect\" id=imagesel ";
			print "onChange=\"updateWaitTime(1);\" tabIndex=1 style=\"width: 400px\" ";
			print "queryExpr=\"*\${0}*\" highlightMatch=\"all\" autoComplete=\"false\" ";
			print "name=imageid>\n";
			foreach($resources['image'] as $id => $image) {
				if($image == 'No Image')
					continue;
				if($id == $imageid)
					print "        <option value=\"$id\" selected>$image</option>\n";
				else
					print "        <option value=\"$id\">$image</option>\n";
			}
			print "      </select>\n";
		}
		else
			printSelectInput('imageid', $resources['image'], $imageid, 1, 0, 'imagesel', "onChange=\"updateWaitTime(1);\"");
	}
	else {
		if(USEFILTERINGSELECT && count($resources['image']) < FILTERINGSELECTTHRESHOLD) {
			print "      <select dojoType=\"dijit.form.FilteringSelect\" id=imagesel ";
			print "onChange=\"selectEnvironment();\" tabIndex=1 style=\"width: 400px\" ";
			print "queryExpr=\"*\${0}*\" highlightMatch=\"all\" autoComplete=\"false\" ";
			print "name=imageid>\n";
			foreach($resources['image'] as $id => $image) {
				if($image == 'No Image')
					continue;
				if($id == $imageid)
					print "        <option value=\"$id\" selected>$image</option>\n";
				else
					print "        <option value=\"$id\">$image</option>\n";
			}
			print "      </select>\n";
		}
		else
			printSelectInput('imageid', $resources['image'], $imageid, 1, 0, 'imagesel', "onChange=\"selectEnvironment();\"");
	}
	print "<br><br>\n";

	$imagenotes = getImageNotes($imageid);
	$desc = '';
	if(! preg_match('/^\s*$/', $imagenotes['description'])) {
		$desc = preg_replace("/\n/", '<br>', $imagenotes['description']);
		$desc = preg_replace("/\r/", '', $desc);
		$desc = _("<strong>Image Description</strong>:<br>\n") . "$desc<br><br>\n";
	}
	print "<div id=imgdesc>$desc</div>\n";

	print "<fieldset id=whenuse class=whenusefieldset>\n";
	if($imaging)
		print "<legend>When would you like to start the imaging process?</legend>\n";
	else
		print _("<legend>When would you like to use the application?</legend>\n");
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time id=timenow ";
	print "onclick='updateWaitTime(0);' value=now checked>";
	print _("<label for=\"timenow\">Now</label><br>\n");
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time value=future ";
	print "onclick='updateWaitTime(0);' id=\"laterradio\">";
	print _("<label for=\"laterradio\">Later:</label>\n");
	if(array_key_exists($imageid, $images))
		$maxlen = $images[$imageid]['maxinitialtime'];
	else
		$maxlen = 0;
	if($submitErr) {
		$hour24 = $hour;
		if($hour24 == 12) {
			if($meridian == "am") {
				$hour24 = 0;
			}
		}
		elseif($meridian == "pm") {
			$hour24 += 12;
		}
		list($month, $day, $year) = explode('/', $day);
		$stamp = datetimeToUnix("$year-$month-$day $hour24:$minute:00");
		$day = date('l', $stamp);
		printReserveItems(1, $imaging, $length, $maxlen, $day, $hour, $minute, $meridian);
	}
	else {
		if(empty($timestamp))
			$timestamp = unixFloor15(time() + 4500);
		$timeArr = explode(',', date('l,g,i,a', $timestamp));
		printReserveItems(1, $imaging, $length, $maxlen, $timeArr[0], $timeArr[1], $timeArr[2], $timeArr[3]);
	}
	print "</fieldset>\n";

	print "<div id=waittime class=hidden></div><br>\n";
	$cont = addContinuationsEntry('submitRequest', array('imaging' => $imaging), SECINDAY, 1, 0);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	if($imaging)
		print "<INPUT id=newsubmit type=submit value=\"Create Imaging Reservation\" ";
	else
		print _("<INPUT id=newsubmit type=submit value=\"Create Reservation\" ");
	print "onClick=\"return checkValidImage();\">\n";
	print "<INPUT type=hidden id=testjavascript value=0>\n";
	print "</FORM>\n";
	$cont = addContinuationsEntry('AJupdateWaitTime', array('imaging' => $imaging));
	print "<INPUT type=hidden name=waitcontinuation id=waitcontinuation value=\"$cont\">\n";

	print "<div dojoType=dijit.Dialog\n";
	print "      id=\"suggestedTimes\"\n";
	print "      title=\"" . _("Available Times") . "\"\n";
	print "      duration=250\n";
	print "      draggable=true>\n";
	print "   <div id=\"suggestloading\" style=\"text-align: center\">";
	print "<img src=\"themes/$skin/css/dojo/images/loading.gif\" ";
	print "style=\"vertical-align: middle;\"> " . _("Loading...") . "</div>\n";
	print "   <div id=\"suggestContent\"></div>\n";
	print "   <input type=\"hidden\" id=\"suggestcont\">\n";
	print "   <input type=\"hidden\" id=\"selectedslot\">\n";
	print "   <div align=\"center\">\n";
	print "   <button id=\"suggestDlgBtn\" dojoType=\"dijit.form.Button\" disabled>\n";
	print "     " . _("Use Selected Time") . "\n";
	print "	   <script type=\"dojo/method\" event=\"onClick\">\n";
	print "       useSuggestedSlot();\n";
	print "     </script>\n";
	print "   </button>\n";
	print "   <button id=\"suggestDlgCancelBtn\" dojoType=\"dijit.form.Button\">\n";
	print "     " . _("Cancel") . "\n";
	print "	   <script type=\"dojo/method\" event=\"onClick\">\n";
	print "       dijit.byId('suggestDlgBtn').set('disabled', true);\n";
	print "       showDijitButton('suggestDlgBtn');\n";
	print "       dijit.byId('suggestDlgCancelBtn').set('label', '" . _("Cancel") . "');\n";
	print "       dijit.byId('suggestedTimes').hide();\n";
	print "       dojo.byId('suggestContent').innerHTML = '';\n";
	print "     </script>\n";
	print "   </button>\n";
	print "   </div>\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJupdateWaitTime()
///
/// \brief generates html update for ajax call to display estimated wait time
/// for current selection on new reservation page
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateWaitTime() {
	global $user, $requestInfo;
	# proccess length
	$length = processInputVar('length', ARG_NUMERIC);
	$times = getUserMaxTimes();
	$imaging = getContinuationVar('imaging');
	if(empty($length) ||
	   ($length > $times['initial'] && ! $imaging ) ||
		($length > $times['initial'] && $imaging && $length > 720)) {
		return;
	}
	# process imageid
	$imageid = processInputVar('imageid', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$validImageids = array_keys($resources['image']);
	if(! in_array($imageid, $validImageids))
		return;

	$desconly = processInputVar('desconly', ARG_NUMERIC, 1);

	$imagenotes = getImageNotes($imageid);
	if(! preg_match('/^\s*$/', $imagenotes['description'])) {
		$desc = preg_replace("/\n/", '<br>', $imagenotes['description']);
		$desc = preg_replace("/\r/", '', $desc);
		$desc = preg_replace("/'/", '&#39;', $desc);
		print _("dojo.byId('imgdesc').innerHTML = '<strong>Image Description</strong>:<br>");
		print "$desc<br><br>'; ";
	}

	if($desconly) {
		if($imaging)
			print "if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'Create Imaging Reservation';";
		else
			print _("if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'Create Reservation';");
		return;
	}

	$images = getImages();
	$now = time();
	$start = unixFloor15($now);
	$end = $start + $length * 60;
	if($start < $now)
		$end += 15 * 60;
	$imagerevisionid = getProductionRevisionid($imageid);
	$rc = isAvailable($images, $imageid, $imagerevisionid, $start, $end);
	semUnlock();
	if($rc < 1) {
		$cdata = array('now' => 1,
		               'start' => $start, 
		               'end' => $end,
		               'server' => 0,
		               'imageid' => $imageid);
		$cont = addContinuationsEntry('AJshowRequestSuggestedTimes', $cdata);
		if(array_key_exists('subimages', $images[$imageid]) &&
		   count($images[$imageid]['subimages']))
			print "dojo.byId('suggestcont').value = 'cluster';";
		else
			print "dojo.byId('suggestcont').value = '$cont';";
		print "if(dojo.byId('newsubmit')) {";
		print "if(dojo.byId('newsubmit').value != _('View Available Times')) ";
		print "resbtntxt = dojo.byId('newsubmit').value; ";
		print "dojo.byId('newsubmit').value = _('View Available Times');";
		print "}";
	}
	print "dojo.byId('waittime').innerHTML = ";
	if($rc == -2)
		print _("'<font color=red>Selection not currently available due to scheduled system downtime for maintenance</font>'; ");
	elseif($rc < 1) {
		print _("'<font color=red>Selection not currently available</font>'; ");
		print "showSuggestedTimes(); ";
	}
	elseif(array_key_exists(0, $requestInfo['loaded']) &&
		   $requestInfo['loaded'][0]) {
			print _("'Estimated load time: &lt; 1 minute';");
	}
	else {
		$loadtime = (int)(getImageLoadEstimate($imageid) / 60);
		if($loadtime == 0)
			print _("'Estimated load time: &lt; ") . "{$images[$imageid]['reloadtime']}" . _(" minutes';");
		else
			printf(_("'Estimated load time: &lt; %2.0f minutes';"), $loadtime + 1);
	}
	if($rc > 0) {
		if($imaging)
			print "if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'Create Imaging Reservation';";
		else
			print _("if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'Create Reservation';");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJshowRequestSuggestedTimes()
///
/// \brief builds html to display list of available times the selected image
/// can be used
///
////////////////////////////////////////////////////////////////////////////////
function AJshowRequestSuggestedTimes() {
	global $user;
	$data = array();
	$start = getContinuationVar('start');
	$end = getContinuationVar('end');
	$imageid = getContinuationVar('imageid');
	$now = getContinuationVar('now');
	$server = getContinuationVar('server');
	$ip = getContinuationVar('ip', '');
	$mac = getContinuationVar('mac', '');
	$requestid = getContinuationVar('requestid', '');
	$extendonly = getContinuationVar('extendonly', 0);
	if($now && $start < time()) {
		# $start should have been decreased by 15 minutes
		$start = $start + 900;
	}
	if($server)
		$slots = findAvailableTimes($start, $end, $imageid, $user['id'], 0,
		                            $requestid, $extendonly, $ip, $mac);
	else
		$slots = findAvailableTimes($start, $end, $imageid, $user['id'], 1,
		                            $requestid, $extendonly);
	$data['status'] = 'success';
	if($requestid != '') {
		$reqdata = getRequestInfo($requestid, 0);
		if(is_null($reqdata)) {
			$data['status'] = 'resgone';
			sendJSON($data);
			return;
		}
	}
	if(empty($slots)) {
		$data['html'] = _("There are no available times that<br>the selected image can be used.<br><br>");
		$data['status'] = 'error';
		sendJSON($data);
		return;
	}

	$data['data'] = $slots;
	$html = '';
	$html .= "<table summary=\"available time slots\" class=\"collapsetable\">";
	if($extendonly) {
		$slot = array_pop($slots);
		$maxextend = $slot['duration'] - (datetimeToUnix($reqdata['end']) - datetimeToUnix($reqdata['start']));
		if($maxextend < 900) {
			$data['html'] = _('This reservation can no longer be extended due to<br>')
			              . _('a reservation immediately following yours.<br><br>');
			$data['status'] = 'noextend';
			sendJSON($data);
			return;
		}
		$html .= "<tr>";
		$html .= "<td></td>";
		$html .= "<th>" . _("End Time") . "</th>";
		$html .= "<th>" . _("Extend By") . "</th>";
		$html .= "</tr>";
		$cnt = 0;
		$e = datetimeToUnix($reqdata['end']);
		$slots = array();
		for($cnt = 0, $amount = 900, $e = datetimeToUnix($reqdata['end']) + 900;
		    $cnt < 15 && $amount <= $maxextend && $amount < 7200;
		    $cnt++, $amount += 900, $e += 900) {
			$end = strftime('%x %l:%M %P', $e);
			$extenstion = getReservationExtenstion($amount / 60);
			if($cnt % 2)
				$html .= "<tr class=\"tablerow0\">";
			else
				$html .= "<tr class=\"tablerow1\">";
			$html .= "<td><input type=\"radio\" name=\"slot\" value=\"$e\" ";
			$html .= "id=\"slot$amount\" onChange=\"setSuggestSlot('$e');\"></td>";
			$html .= "<td><label for=\"slot$amount\">$end</label></td>";
			$html .= "<td style=\"padding-left: 8px;\">";
			$html .= "<label for=\"slot$amount\">$extenstion</label></td></tr>";
			$slots[$e] = array('duration' => $amount,
			                   'startts' => $slot['startts']);
		}
		for(; $cnt < 15 && $amount <= $maxextend;
		    $cnt++, $amount += 3600, $e += 3600) {
			$end = strftime('%x %l:%M %P', $e);
			$extenstion = getReservationExtenstion($amount / 60);
			if($cnt % 2)
				$html .= "<tr class=\"tablerow0\">";
			else
				$html .= "<tr class=\"tablerow1\">";
			$html .= "<td><input type=\"radio\" name=\"slot\" value=\"$e\" ";
			$html .= "id=\"slot$amount\" onChange=\"setSuggestSlot('$e');\"></td>";
			$html .= "<td><label for=\"slot$amount\">$end</label></td>";
			$html .= "<td style=\"padding-left: 8px;\">";
			$html .= "<label for=\"slot$amount\">$extenstion</label></td></tr>";
			$slots[$e] = array('duration' => $amount,
			                   'startts' => $slot['startts']);
		}
		$data['data'] = $slots;
	}
	else {
		$html .= "<tr>";
		$html .= "<td></td>";
		$html .= "<th>" . _("Start Time") . "</th>";
		$html .= "<th>" . _("Duration") . "</th>";
		if(checkUserHasPerm('View Debug Information'))
			$html .= "<th>" . _("Comp. ID") . "</th>";
		$html .= "</tr>";
		$cnt = 0;
		foreach($slots as $key => $slot) {
			$cnt++;
			$start = strftime('%x %l:%M %P', $slot['startts']);
			if(($slot['startts'] - time()) + $slot['startts'] + $slot['duration'] >= 2114402400)
				# end time >= 2037-01-01 00:00:00
				$duration = 'indefinite';
			else
				$duration = getReservationLength($slot['duration'] / 60);
			if($cnt % 2)
				$html .= "<tr class=\"tablerow0\">";
			else
				$html .= "<tr class=\"tablerow1\">";
			$html .= "<td><input type=\"radio\" name=\"slot\" value=\"$key\" id=\"slot$key\" ";
			$html .= "onChange=\"setSuggestSlot('{$slot['startts']}');\"></td>";
			$html .= "<td><label for=\"slot$key\">$start</label></td>";
			$html .= "<td style=\"padding-left: 8px;\">";
			$html .= "<label for=\"slot$key\">$duration</label></td>";
			if(checkUserHasPerm('View Debug Information'))
				$html .= "<td style=\"padding-left: 8px;\">{$slot['compid']}</td>";
			$html .= "</tr>";
			if($cnt >= 15)
				break;
		}
	}
	$html .= "</table>";
	$data['html'] = $html;
	$cdata = array('slots' => $slots);
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitRequest()
///
/// \brief checks to see if the request can fit in the schedule; adds it if
/// it fits; notifies the user either way
///
////////////////////////////////////////////////////////////////////////////////
function submitRequest() {
	global $submitErr, $user, $HTMLheader, $mode, $printedHTMLheader;

	if($mode == 'submitTestProd') {
		$data = getContinuationVar();
		$data["revisionid"] = $_POST['revisionid'];
		# TODO check for valid revisionids for each image
		if(! empty($data["revisionid"])) {
			foreach($data['revisionid'] as $val) {
				foreach($val as $val2) {
					if(! is_numeric($val2) || $val2 < 0) {
						unset($data['revisionid']);
						break 2; // TODO make sure this breaks as far as needed
					}
				}
			}
		}
	}
	else {
		$data = processRequestInput(1);
	}
	$imaging = $data['imaging'];
	if($submitErr) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		if($imaging)
			print "<H2>Create / Update an Image</H2>\n";
		else
			print _("<H2>New Reservation</H2>\n");
		newReservation();
		print getFooter();
		return;
	}
	// if user attempts to make a reservation for an image he does not have
	//   access to, just make it for the first one he does have access to
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$validImageids = array_keys($resources['image']);
	if(! in_array($data['imageid'], $validImageids))
		$data['imageid'] = array_shift($validImageids);

	$showrevisions = 0;
	$subimages = 0;
	$images = getImages();
	$revcount = count($images[$data['imageid']]['imagerevision']);
	if($revcount > 1)
		$showrevisions = 1;
	if($images[$data['imageid']]['imagemetaid'] != NULL &&
	   count($images[$data['imageid']]['subimages'])) {
		$subimages = 1;
		foreach($images[$data['imageid']]['subimages'] as $subimage) {
			$revcount = count($images[$subimage]['imagerevision']);
			if($revcount > 1)
				$showrevisions = 1;
		}
	}

	if($data["time"] == "now") {
		$nowArr = getdate();
		if($nowArr["minutes"] == 0) {
			$subtract = 0;
			$add = 0;
		}
		elseif($nowArr["minutes"] < 15) {
			$subtract = $nowArr["minutes"] * 60;
			$add = 900;
		}
		elseif($nowArr["minutes"] < 30) {
			$subtract = ($nowArr["minutes"] - 15) * 60;
			$add = 900;
		}
		elseif($nowArr["minutes"] < 45) {
			$subtract = ($nowArr["minutes"] - 30) * 60;
			$add = 900;
		}
		elseif($nowArr["minutes"] < 60) {
			$subtract = ($nowArr["minutes"] - 45) * 60;
			$add = 900;
		}
		$start = time() - $subtract;
		$start -= $start % 60;
		$nowfuture = "now";
	}
	else {
		$add = 0;
		$hour = $data["hour"];
		if($data["hour"] == 12) {
			if($data["meridian"] == "am") {
				$hour = 0;
			}
		}
		elseif($data["meridian"] == "pm") {
			$hour = $data["hour"] + 12;
		}

		$tmp = explode('/', $data["day"]);
		$start = mktime($hour, $data["minute"], "0", $tmp[0], $tmp[1], $tmp[2]);
		if($start < time()) {
			$printedHTMLheader = 1;
			print $HTMLheader;
			if($imaging)
				print "<H2>Create / Update an Image</H2>\n";
			else
				print _("<H2>New Reservation</H2>\n");
			print _("<font color=\"#ff0000\">The time you requested is in the past.");
			print _(" Please select \"Now\" or use a time in the future.</font><br>\n");
			$submitErr = 5000;
			newReservation();
			print getFooter();
			return;
		}
		$nowfuture = "future";
	}
	if($data["ending"] == "length")
		$end = $start + $data["length"] * 60 + $add;
	else {
		$end = datetimeToUnix($data["enddate"]);
		if($end % (15 * 60))
			$end = unixFloor15($end) + (15 * 60);
	}

	// get semaphore lock
	if(! semLock())
		abort(3);

	if(array_key_exists('revisionid', $data) &&
	   array_key_exists($data['imageid'], $data['revisionid']) &&
	   array_key_exists(0, $data['revisionid'][$data['imageid']])) {
		$revisionid = $data['revisionid'][$data['imageid']][0];
	}
	else
		$revisionid = getProductionRevisionid($data['imageid']);
	$availablerc = isAvailable($images, $data["imageid"], $revisionid, $start,
	                           $end, 0, 0, 0, $imaging);

	$max = getMaxOverlap($user['id']);
	if($availablerc != 0 && checkOverlap($start, $end, $max)) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		if($imaging)
			print "<H2>Create / Update an Image</H2>\n";
		else
			print _("<H2>New Reservation</H2>\n");
		if($max == 0) {
			print _("<font color=\"#ff0000\">The time you requested overlaps with ");
			print _("another reservation you currently have.  You are only allowed ");
			print _("to have a single reservation at any given time. Please select ");
			print _("another time to use the application. If you are finished with ");
			print _("an active reservation, click \"Current Reservations\", ");
			print _("then click the \"End\" button of your active reservation.");
			print "</font><br><br>\n";
		}
		else {
			print _("<font color=\"#ff0000\">The time you requested overlaps with ");
			print _("another reservation you currently have.  You are allowed ");
			print _("to have ") . "$max" . _(" overlapping reservations at any given time. ");
			print _("Please select another time to use the application. If you are ");
			print _("finished with an active reservation, click \"Current ");
			print _("Reservations\", then click the \"End\" button of your active ");
			print _("reservation.</font><br><br>\n");
		}
		$submitErr = 5000;
		newReservation();
		print getFooter();
		return;
	}
	// if user is owner of the image and there is a test version of the image
	#   available, ask user if production or test image desired
	if($mode != "submitTestProd" && $showrevisions &&
	   ($images[$data["imageid"]]["ownerid"] == $user["id"] || checkUserHasPerm('View Debug Information'))) {
		#unset($data["testprod"]);
		$printedHTMLheader = 1;
		print $HTMLheader;
		if($imaging)
			print "<H2>Create / Update an Image</H2>\n";
		else
			print _("<H2>New Reservation</H2>\n");
		if($subimages) {
			print _("This is a cluster environment. At least one image in the ");
			print _("cluster has more than one version available. Please select ");
			print _("the version you desire for each image listed below:<br>\n");
		}
		else {
			print _("There are multiple versions of this environment available.  Please ");
			print _("select the version you would like to check out:<br>\n");
		}
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post><br>\n";
		if(! array_key_exists('subimages', $images[$data['imageid']]))
			$images[$data['imageid']]['subimages'] = array();
		array_unshift($images[$data['imageid']]['subimages'], $data['imageid']);
		$cnt = 0;
		foreach($images[$data['imageid']]['subimages'] as $subimage) {
			print "{$images[$subimage]['prettyname']}:<br>\n";
			print "<table summary=\"lists versions of the selected environment, one must be selected to continue\">\n";
			print "  <TR>\n";
			print "    <TD></TD>\n";
			print "    <TH>" . _("Version") . "</TH>\n";
			print "    <TH>" . _("Creator") . "</TH>\n";
			print "    <TH>" . _("Created") . "</TH>\n";
			print "    <TH>" . _("Currently in Production") . "</TH>\n";
			print "  </TR>\n";
			foreach($images[$subimage]['imagerevision'] as $revision) {
				print "  <TR>\n";
				// if revision was selected or it wasn't selected but it is the production revision, show checked
				if((array_key_exists('revisionid', $data) &&
				   array_key_exists($subimage, $data['revisionid']) &&
					array_key_exists($cnt, $data['revisionid'][$subimage]) &&
				   $data['revisionid'][$subimage][$cnt] == $revisionid['id']) ||
				   $revision['production'])
					print "    <TD align=center><INPUT type=radio name=revisionid[$subimage][$cnt] value={$revision['id']} checked></TD>\n";
				else
					print "    <TD align=center><INPUT type=radio name=revisionid[$subimage][$cnt] value={$revision['id']}></TD>\n";
				print "    <TD align=center>{$revision['revision']}</TD>\n";
				print "    <TD align=center>{$revision['user']}</TD>\n";
				print "    <TD align=center>{$revision['prettydate']}</TD>\n";
				if($revision['production'])
					print _("    <TD align=center>Yes</TD>\n");
				else
					print _("    <TD align=center>No</TD>\n");
				print "  </TR>\n";
			}
			print "</table>\n";
			$cnt++;
		}
		$cont = addContinuationsEntry('submitTestProd', $data);
		print "<br><INPUT type=hidden name=continuation value=\"$cont\">\n";
		if($imaging)
			print "<INPUT type=submit value=\"Create Imaging Reservation\">\n";
		else
			print _("<INPUT type=submit value=\"Create Reservation\">\n");
		print "</FORM>\n";
		print getFooter();
		return;
	}
	if($availablerc == -1) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		if($imaging)
			print _("<H2>Create / Update an Image</H2>\n");
		else
			print _("<H2>New Reservation</H2>\n");
		print _("You have requested an environment that is limited in the number ");
		print _("of concurrent reservations that can be made. No further ");
		print _("reservations for the environment can be made for the time you ");
		print _("have selected. Please select another time to use the ");
		print _("environment.<br>");
		addLogEntry($nowfuture, unixToDatetime($start), 
		            unixToDatetime($end), 0, $data["imageid"]);
		print getFooter();
	}
	elseif($availablerc > 0) {
		$requestid = addRequest($imaging, $data["revisionid"]);
		if($data["time"] == "now") {
			$cdata = array('lengthchanged' => $data['lengthchanged']);
			$cont = addContinuationsEntry('viewRequests', $cdata);
			header("Location: " . BASEURL . SCRIPT . "?continuation=$cont");
			return;
		}
		else {
			if($data["minute"] == 0)
				$data["minute"] = "00";
			$printedHTMLheader = 1;
			print $HTMLheader;
			if($imaging)
				print _("<H2>Create / Update an Image</H2>\n");
			else
				print _("<H2>New Reservation</H2>\n");
			if($data["ending"] == "length") {
				$time = prettyLength($data["length"]);
				if($data['testjavascript'] == 0 && $data['lengthchanged']) {
					print _("<font color=red>NOTE: The maximum allowed reservation ");
					print _("length for this environment is ") . "$time" . _(", and the length of ");
					print _("this reservation has been adjusted accordingly.</font>\n");
					print "<br><br>\n";
				}
				print _("Your request to use <b>") . $images[$data["imageid"]]["prettyname"];
				print _("</b> on ") . prettyDatetime($start) . _(" for ") . "$time" . _(" has been ");
				print _("accepted.<br><br>\n");
			}
			else {
				print _("Your request to use <b>") . $images[$data["imageid"]]["prettyname"];
				print _("</b> starting ") . prettyDatetime($start) . _(" and ending ");
				print prettyDatetime($end) . _(" has been accepted.<br><br>\n");
			}
			print _("When your reservation time has been reached, the <strong>");
			print _("Current Reservations</strong> page will have further ");
			print _("instructions on connecting to the reserved computer.  If you ");
			print _("would like to modify your reservation, you can do that from ");
			print _("the <b>Current Reservations</b> page as well.<br>\n");
			print getFooter();
		}
	}
	else {
		$cdata = array('imageid' => $data['imageid'],
		               'length' => $data['length'],
		               'showmessage' => 1,
		               'imaging' => $imaging);
		$cont = addContinuationsEntry('selectTimeTable', $cdata);
		addLogEntry($nowfuture, unixToDatetime($start), 
		            unixToDatetime($end), 0, $data["imageid"]);
		header("Location: " . BASEURL . SCRIPT . "?continuation=$cont");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewRequests
///
/// \brief prints user's reservations
///
////////////////////////////////////////////////////////////////////////////////
function viewRequests() {
	global $user, $inContinuation, $mode, $skin;
	if($inContinuation)
		$lengthchanged = getContinuationVar('lengthchanged', 0);
	else
		$lengthchanged = processInputVar('lengthchanged', ARG_NUMERIC, 0);
	$incPaneDetails = processInputVar('incdetails', ARG_NUMERIC, 0);
	$refreqid = processInputVar('reqid', ARG_NUMERIC, 0);
	$requests = getUserRequests("all");
	$images = getImages();
	$computers = getComputers();
	$resources = getUserResources(array("imageAdmin"));

	if(count($requests) == 0) {
		if($mode == 'AJviewRequests')
			print "document.body.style.cursor = 'default';";
		$text  = _("<H2>Current Reservations</H2>");
		$text .= _("You have no current reservations.<br>");
		if($mode == 'AJviewRequests')
			print(setAttribute('subcontent', 'innerHTML', $text));
		else
			print $text;
		return;
	}
	if($mode != 'AJviewRequests')
		print "<div id=subcontent>\n";

	$refresh = 0;
	$connect = 0;
	$failed = 0;

	$normal = '';
	$imaging = '';
	$long = '';
	$server = '';
	$reqids = array();
	if(checkUserHasPerm('View Debug Information'))
		$nodes = getManagementNodes();
	if($count = count($requests)) {
		$now = time();
		for($i = 0, $failed = 0, $timedout = 0, $text = '', $showcreateimage = 0, $cluster = 0;
		   $i < $count;
		   $i++, $failed = 0, $timedout = 0, $text = '', $cluster = 0) {
			if($requests[$i]['forcheckout'] == 0 &&
			   $requests[$i]['forimaging'] == 0)
				continue;
			if(count($requests[$i]['reservations']))
				$cluster = 1;
			$cdata = array('requestid' => $requests[$i]['id']);
			$reqids[] = $requests[$i]['id'];
			$imageid = $requests[$i]["imageid"];
			$text .= "  <TR valign=top id=reqrow{$requests[$i]['id']}>\n";
			if(requestIsReady($requests[$i]) && $requests[$i]['useraccountready']) {
				$connect = 1;
				# request is ready, print Connect! and End buttons
				$cont = addContinuationsEntry('connectRequest', $cdata, SECINDAY);
				$text .= getViewRequestHTMLitem('connectbtn', $cont);
				if($requests[$i]['serveradmin']) {
					$cont = addContinuationsEntry('AJconfirmDeleteRequest', $cdata, SECINDAY);
					$text .= getViewRequestHTMLitem('deletebtn', $cont);
				}
				else
					$text .= "    <TD></TD>\n";
			}
			elseif($requests[$i]["currstateid"] == 5) {
				# request has failed
				$text .= getViewRequestHTMLitem('failedblock', $requests[$i]['id']);
				if($requests[$i]['serveradmin']) {
					$cont = addContinuationsEntry('AJconfirmRemoveRequest', $cdata, SECINDAY);
					$text .= getViewRequestHTMLitem('removebtn', $cont);
				}
				else
					$text .= "    <TD></TD>\n";
				$failed = 1;
			}
			elseif(datetimeToUnix($requests[$i]["start"]) < $now) {
				# other cases where the reservation start time has been reached
				if(($requests[$i]["currstateid"] == 12 &&
				   $requests[$i]['laststateid'] == 11) ||
					$requests[$i]["currstateid"] == 11 ||
					($requests[$i]["currstateid"] == 14 &&
					$requests[$i]["laststateid"] == 11)) {
					# request has timed out
					$text .= getViewRequestHTMLitem('timeoutblock');
					$timedout = 1;
					if($requests[$i]['serveradmin']) {
						$cont = addContinuationsEntry('AJconfirmRemoveRequest', $cdata, SECINDAY);
						$text .= getViewRequestHTMLitem('removebtn', $cont);
					}
					else
						$text .= "    <TD></TD>\n";
				}
				else {
					# computer is loading, print Pending... and Delete button
					# TODO figure out a different way to estimate for reboot and reinstall states
					# TODO if user account not ready, print accurate information in details
					$remaining = 1;
					if(isComputerLoading($requests[$i], $computers)) {
						if(datetimeToUnix($requests[$i]["daterequested"]) >=
						   datetimeToUnix($requests[$i]["start"])) {
							$startload = datetimeToUnix($requests[$i]["daterequested"]);
						}
						else {
							$startload = datetimeToUnix($requests[$i]["start"]);
						}
						$imgLoadTime = getImageLoadEstimate($imageid);
						if($imgLoadTime == 0)
							$imgLoadTime = $images[$imageid]['reloadtime'] * 60;
						$tmp = ($imgLoadTime - ($now - $startload)) / 60;
						$remaining = sprintf("%d", $tmp) + 1;
						if($remaining < 1) {
							$remaining = 1;
						}
					}
					$data = array('text' => '');
					if($requests[$i]['currstateid'] != 26 &&
					   $requests[$i]['currstateid'] != 27 &&
					   $requests[$i]['currstateid'] != 28 &&
					   ($requests[$i]["currstateid"] != 14 ||
					   ($requests[$i]['laststateid'] != 26 &&
					    $requests[$i]['laststateid'] != 27 &&
					    $requests[$i]['laststateid'] != 28)))
						$data['text'] = _("<br>Est:&nbsp;") . $remaining . _("&nbsp;min remaining\n");
					$text .= getViewRequestHTMLitem('pendingblock', $requests[$i]['id'], $data);
					$refresh = 1;
					if($requests[$i]['serveradmin']) {
						$cont = addContinuationsEntry('AJconfirmDeleteRequest', $cdata, SECINDAY);
						$text .= getViewRequestHTMLitem('deletebtn', $cont);
					}
					else
						$text .= "    <TD></TD>\n";
				}
			}
			else {
				# reservation is in the future
				$text .= "    <TD></TD>\n";
				if($requests[$i]['serveradmin']) {
					$cont = addContinuationsEntry('AJconfirmDeleteRequest', $cdata, SECINDAY);
					$text .= getViewRequestHTMLitem('deletebtn', $cont);
				}
				else
					$text .= "    <TD></TD>\n";
			}
			if(! $failed && ! $timedout) {
				# print edit button
				$editcont = addContinuationsEntry('AJeditRequest', $cdata, SECINDAY);
				$imgcont = addContinuationsEntry('startImage', $cdata, SECINDAY);
				$imgurl = BASEURL . SCRIPT . "?continuation=$imgcont";
				if($requests[$i]['serveradmin']) {
					$text .= getViewRequestHTMLitem('openmoreoptions');
					$text .= getViewRequestHTMLitem('editoption', $editcont);
					if(array_key_exists($imageid, $resources['image']) && ! $cluster &&            # imageAdmin access, not a cluster,
					   ($requests[$i]['currstateid'] == 8 || $requests[$i]['laststateid'] == 8)) { # reservation has been in inuse state
						$data = array('doescape' => 0);
						if($mode == 'AJviewRequests')
							$data['doescape'] = 1;
						$text .= getViewRequestHTMLitem('endcreateoption', $imgurl, $data);
					}
					/*else
						$text .= getViewRequestHTMLitem('endcreateoptiondisable');*/
					// todo uncomment the following when live imaging works
					// todo add a check to ensure it is a VM
					/*if($requests[$i]['server'] && ($requests[$i]['currstateid'] == 8 ||
						($requests[$i]['currstateid'] == 14 && $requests[$i]['laststateid'] == 8))) {
						$cont = addContinuationsEntry('startCheckpoint', $cdata, SECINDAY);
						$url = BASEURL . SCRIPT . "?continuation=$cont";
						$data = array('doescape' => 0);
						if($mode == 'AJviewRequests')
							$data['doescape'] = 1;
						$text .= getViewRequestHTMLitem('checkpointoption', $imgurl, $data);
					}
					elseif($requests[$i]['server'] && $requests[$i]['currstateid'] == 24)
						$text .= getViewRequestHTMLitem('checkpointoptiondisable');*/
					if($requests[$i]['currstateid'] == 8 ||
					   (! $cluster &&
					   $requests[$i]['OSinstalltype'] != 'none' &&
					   $requests[$i]['currstateid'] != 3 &&
					   $requests[$i]['laststateid'] != 3 &&
					   $requests[$i]['currstateid'] != 13 &&
					   $requests[$i]['laststateid'] != 13 &&
					   $requests[$i]['currstateid'] != 24 &&
					   $requests[$i]['laststateid'] != 24 &&
					   $requests[$i]['currstateid'] != 16 &&
					   $requests[$i]['laststateid'] != 16 &&
					   $requests[$i]['currstateid'] != 26 &&
					   $requests[$i]['laststateid'] != 26 &&
					   $requests[$i]['currstateid'] != 28 &&
						$requests[$i]['laststateid'] != 28 &&
					   $requests[$i]['currstateid'] != 27 &&
					   $requests[$i]['laststateid'] != 27)) {
						$cont = addContinuationsEntry('AJrebootRequest', $cdata, SECINDAY);
						$text .= getViewRequestHTMLitem('rebootoption', $cont);
						$cont = addContinuationsEntry('AJshowReinstallRequest', $cdata, SECINDAY);
						$text .= getViewRequestHTMLitem('reinstalloption', $cont);
					}
					else {
						$text .= getViewRequestHTMLitem('rebootoptiondisable');
						$text .= getViewRequestHTMLitem('reinstalloptiondisable');
					}
					$text .= "       </div>\n";
					$text .= "     </div>\n";
					$text .= getViewRequestHTMLitem('timeoutdata', $requests[$i]['id'], $requests[$i]);
					$text .= "    </TD>\n";
				}
				else {
					$text .= "    <TD>";
					$text .= getViewRequestHTMLitem('timeoutdata', $requests[$i]['id'], $requests[$i]);
					$text .= "</TD>\n";
				}
			}
			else
				$text .= "    <TD></TD>\n";

			# print name of server request
			if($requests[$i]['server']) {
				if($requests[$i]['servername'] == '')
					$text .= getViewRequestHTMLitem('servername', $requests[$i]['prettyimage']);
				else
					$text .= getViewRequestHTMLitem('servername', $requests[$i]['servername']);
			}

			# print name of image, add (Testing) if it is the test version of an image
			if(!$requests[$i]['server']) {
				$data = array('addtest' => 0);
				if($requests[$i]["test"])
					$data['addtest'] = 1;
				$text .= getViewRequestHTMLitem('imagename', $requests[$i]['prettyimage'], $data);
			}

			# print start time
			if(! $requests[$i]['server']) {
				$data = array('start' => $requests[$i]['start'],
				              'requested' => $requests[$i]['daterequested']);
				$text .= getViewRequestHTMLitem('starttime', '', $data);
			}

			# print end time
			$data = array('end' => $requests[$i]['end']);
			$text .= getViewRequestHTMLitem('endtime', '', $data);

			# print date requested
			if(! $requests[$i]['server'])
				$text .= getViewRequestHTMLitem('requesttime', $requests[$i]['daterequested']);

			# print server request details
			if($requests[$i]['server']) {
				$data = array('owner' => getUserUnityID($requests[$i]['userid']),
				              'requesttime' => $requests[$i]['daterequested'],
				              'admingroup' => $requests[$i]['serveradmingroup'],
				              'logingroup' => $requests[$i]['serverlogingroup'],
				              'image' => $requests[$i]['prettyimage'],
				              'starttime' => $requests[$i]['start']);
				if($requests[$i]['currstateid'] == 14)
				  $data['stateid'] = $requests[$i]['laststateid'];
				else
				  $data['stateid'] = $requests[$i]['currstateid'];
				$text .= getViewRequestHTMLitem('serverdetails', $requests[$i]['id'], $data);
			}

			if(checkUserHasPerm('View Debug Information')) {
				if(! is_null($requests[$i]['vmhostid'])) {
					$query = "SELECT c.hostname "
					       . "FROM computer c, " 
					       .      "vmhost v "
					       . "WHERE v.id = {$requests[$i]['vmhostid']} AND "
					       .       "v.computerid = c.id";
					$qh = doQuery($query, 101);
					$row = mysql_fetch_assoc($qh);
					$vmhost = $row['hostname'];
				}
				$text .= "    <TD align=center><a id=\"req{$requests[$i]['id']}\" ";
				$text .= "tabindex=0>{$requests[$i]["id"]}</a>\n";
				$text .= "<div dojoType=\"vcldojo.HoverTooltip\" connectId=\"req{$requests[$i]['id']}\">";
				$text .= "<strong>Mgmt node</strong>: {$nodes[$requests[$i]["managementnodeid"]]['hostname']}<br>\n";
				$text .= "<strong>Computer ID</strong>: {$requests[$i]['computerid']}<br>\n";
				$text .= "<strong>Comp hostname</strong>: {$computers[$requests[$i]["computerid"]]["hostname"]}<br>\n";
				$text .= "<strong>Comp IP</strong>: {$requests[$i]["IPaddress"]}<br>\n";
				$text .= "<strong>Comp State ID</strong>: {$computers[$requests[$i]["computerid"]]["stateid"]}<br>\n";
				$text .= "<strong>Comp Type</strong>: {$requests[$i]['comptype']}<br>\n";
				if(! is_null($requests[$i]['vmhostid']))
					$text .= "<strong>VM Host</strong>: $vmhost<br>\n";
				$text .= "<strong>Current State ID</strong>: {$requests[$i]["currstateid"]}<br>\n";
				$text .= "<strong>Last State ID</strong>: {$requests[$i]["laststateid"]}<br>\n";
				$text .= "</div></TD>\n";
			}
			$text .= "  </TR>\n";
			if($requests[$i]['server'])
				$server .= $text;
			elseif($requests[$i]['forimaging'])
				$imaging .= $text;
			elseif($requests[$i]['longterm'])
				$long .= $text;
			else
				$normal .= $text;
		}
	}

	$text = _("<H2>Current Reservations</H2>\n");
	if(! empty($normal)) {
		if(! empty($imaging) || ! empty($long))
			$text .= _("You currently have the following <strong>normal</strong> reservations:<br>\n");
		else
			$text .= _("You currently have the following normal reservations:<br>\n");
		if($lengthchanged) {
			$text .= _("<font color=red>NOTE: The maximum allowed reservation ");
			$text .= _("length for one of these reservations was less than the ");
			$text .= _("length you submitted, and the length of that reservation ");
			$text .= _("has been adjusted accordingly.</font>\n");
		}
		$text .= "<table id=reslisttable summary=\"lists reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= _("    <TH>Environment</TH>\n");
		$text .= _("    <TH>Starting</TH>\n");
		$text .= _("    <TH>Ending</TH>\n");
		$text .= _("    <TH>Initially requested</TH>\n");
		if(checkUserHasPerm('View Debug Information'))
			$text .= _("    <TH>Req ID</TH>\n");
		$text .= "  </TR>\n";
		$text .= $normal;
		$text .= "</table>\n";
	}
	if(! empty($imaging)) {
		if(! empty($normal))
			$text .= "<hr>\n";
		$text .= _("You currently have the following <strong>imaging</strong> reservations:<br>\n");
		$text .= "<table id=imgreslisttable summary=\"lists imaging reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= _("    <TH>Environment</TH>\n");
		$text .= _("    <TH>Starting</TH>\n");
		$text .= _("    <TH>Ending</TH>\n");
		$text .= _("    <TH>Initially requested</TH>\n");
		$computers = getComputers();
		if(checkUserHasPerm('View Debug Information'))
			$text .= "    <TH>Req ID</TH>\n";
		$text .= "  </TR>\n";
		$text .= $imaging;
		$text .= "</table>\n";
	}
	if(! empty($long)) {
		if(! empty($normal) || ! empty($imaging))
			$text .= "<hr>\n";
		$text .= _("You currently have the following <strong>long term</strong> reservations:<br>\n");
		$text .= "<table id=\"longreslisttable\" summary=\"lists long term reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= _("    <TH>Environment</TH>\n");
		$text .= _("    <TH>Starting</TH>\n");
		$text .= _("    <TH>Ending</TH>\n");
		$text .= _("    <TH>Initially requested</TH>\n");
		$computers = getComputers();
		if(checkUserHasPerm('View Debug Information'))
			$text .= "    <TH>Req ID</TH>\n";
		$text .= "  </TR>\n";
		$text .= $long;
		$text .= "</table>\n";
	}
	if(! empty($server)) {
		if(! empty($normal) || ! empty($imaging) || ! empty($long))
			$text .= "<hr>\n";
		$text .= _("You currently have the following <strong>server</strong> reservations:<br>\n");
		$text .= "<table id=\"longreslisttable\" summary=\"lists server reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= "    <TH>" . _("Name") . "</TH>\n";
		$text .= _("    <TH>Ending</TH>\n");
		$computers = getComputers();
		$text .= "    <TH>" . _("Details") . "</TH>\n";
		if(checkUserHasPerm('View Debug Information'))
			$text .= "    <TH>" . _("Req ID") . "</TH>\n";
		$text .= "  </TR>\n";
		$text .= $server;
		$text .= "</table>\n";
	}

	# connect div
	if($connect) {
		$text .= _("<br><br>Click the <strong>");
		$text .= _("Connect!</strong> button to get further ");
		$text .= _("information about connecting to the reserved system. You must ");
		$text .= _("click the button from a web browser running on the same computer ");
		$text .= _("from which you will be connecting to the remote computer; ");
		$text .= _("otherwise, you may be denied access to the machine.\n");
	}

	if($refresh) {
		$text .= _("<br><br>This page will automatically update ");
		$text .= _("every 20 seconds until the <font color=red><i>Pending...</i>");
		$text .= _("</font> reservation is ready.\n");
	}

	if($failed) {
		$text .= _("<br><br>An error has occurred that has kept one of your reservations ");
		$text .= _("from being processed. We apologize for any inconvenience ");
		$text .= _("this may have caused.\n");
	}

	$cont = addContinuationsEntry('AJviewRequests', array(), SECINDAY);
	$text .= "<INPUT type=hidden id=resRefreshCont value=\"$cont\">\n";

	$text .= "</div>\n";
	if($mode != 'AJviewRequests') {
		$text .= "<div dojoType=dojox.layout.FloatingPane\n";
		$text .= "      id=resStatusPane\n";
		$text .= "      resizable=true\n";
		$text .= "      closable=true\n";
		$text .= "      title=\"" . _("Detailed Reservation Status") . "\"\n";
		$text .= "      style=\"width: 350px; ";
		$text .=               "height: 280px; ";
		$text .=               "position: absolute; ";
		$text .=               "left: 0px; ";
		$text .=               "top: 0px; ";
		$text .=               "visibility: hidden; ";
		$text .=               "border: solid 1px #7EABCD;\"\n";
		$text .= ">\n";
		$text .= "<script type=\"dojo/method\" event=minimize>\n";
		$text .= "  this.hide();\n";
		$text .= "</script>\n";
		$text .= "<script type=\"dojo/method\" event=close>\n";
		$text .= "  this.hide();\n";
		$text .= "  return false;\n";
		$text .= "</script>\n";
		$text .= "<div id=resStatusText></div>\n";
		$text .= "<input type=hidden id=detailreqid value=0>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"endResDlg\"\n";
		$text .= "      title=\"" . _("Delete Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "   <div id=\"endResDlgContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"endrescont\">\n";
		$text .= "   <input type=\"hidden\" id=\"endresid\">\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"endResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "    " . _("Delete Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitDeleteReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('endResDlg').hide();\n";
		$text .= "       dojo.byId('endResDlgContent').innerHTML = '';\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"remResDlg\"\n";
		$text .= "      title=\"" . _("Remove Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "   <div id=\"remResDlgContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"remrescont\">\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"remResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Remove Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitRemoveReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('remResDlg').hide();\n";
		$text .= "       dojo.byId('remResDlgContent').innerHTML = '';\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"editResDlg\"\n";
		$text .= "      title=\"" . _("Modify Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideEditResDlg();\n";
		$text .= "    </script>\n";
		$text .= "   <div id=\"editResDlgContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"editrescont\">\n";
		$text .= "   <input type=\"hidden\" id=\"editresid\">\n";
		$text .= "   <div id=\"editResDlgErrMsg\" class=\"rederrormsg\"></div>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"editResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Modify Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitEditReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\" id=\"editResCancelBtn\">\n";
		$text .= "     " . _("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('editResDlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"rebootdlg\"\n";
		$text .= "      title=\"" . _("Reboot Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideRebootResDlg();\n";
		$text .= "    </script>\n";
		$text .= "   <div id=\"rebootResDlgContent\">" . _("You can select either a ");
		$text .= _("soft or a hard reboot. A soft reboot<br>issues a reboot ");
		$text .= _("command to the operating system. A hard reboot<br>is akin to ");
		$text .= _("toggling the power switch on a computer. After<br>issuing the ");
		$text .= _("reboot, it may take several minutes before the<br>machine is ");
		$text .= _("available again. It is also possible that it will<br>not come ");
		$text .= _("back up at all. Are you sure you want to continue?") . "<br><br></div>\n";
		$text .= "   <div id=\"rebootRadios\" style=\"margin-left: 90px;\">\n";
		$text .= "   <input type=\"radio\" name=\"reboottype\" id=\"softreboot\" checked>\n";
		$text .= "   <label for=\"softreboot\">" . _("Soft Reboot") . "</label><br>\n";
		$text .= "   <input type=\"radio\" name=\"reboottype\" id=\"hardreboot\">\n";
		$text .= "   <label for=\"hardreboot\">" . _("Hard Reboot") . "</label><br><br>\n";
		$text .= "   </div>\n";
		$text .= "   <input type=\"hidden\" id=\"rebootrescont\">\n";
		$text .= "   <div id=\"rebootResDlgErrMsg\" class=\"rederrormsg\"></div>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"rebootResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Reboot Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitRebootReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('rebootdlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"reinstalldlg\"\n";
		$text .= "      title=\"" . _("Reinstall Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideReinstallResDlg();\n";
		$text .= "    </script>\n";
		$text .= "   <div id=\"reinstallloading\" style=\"text-align: center\">";
		$text .= "<img src=\"themes/$skin/css/dojo/images/loading.gif\" ";
		$text .= "style=\"vertical-align: middle;\"> " . _("Loading...") . "</div>\n";
		$text .= "   <div id=\"reinstallResDlgContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"reinstallrescont\">\n";
		$text .= "   <div id=\"reinstallResDlgErrMsg\" class=\"rederrormsg\"></div>\n";
		$text .= "   <div align=\"center\" id=\"reinstallbtns\" class=\"hidden\">\n";
		$text .= "   <button id=\"reinstallResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Reinstall Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitReinstallReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('reinstalldlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"suggestedTimes\"\n";
		$text .= "      title=\"" . _("Available Times") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "   <div id=\"suggestloading\" style=\"text-align: center\">";
		$text .= "<img src=\"themes/$skin/css/dojo/images/loading.gif\" ";
		$text .= "style=\"vertical-align: middle;\"> " . _("Loading...") . "</div>\n";
		$text .= "   <div id=\"suggestContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"suggestcont\">\n";
		$text .= "   <input type=\"hidden\" id=\"selectedslot\">\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"suggestDlgBtn\" dojoType=\"dijit.form.Button\" disabled>\n";
		$text .= "     " . _("Use Selected Time") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       useSuggestedEditSlot();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button id=\"suggestDlgCancelBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . _("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('suggestDlgBtn').set('disabled', true);\n";
		$text .= "       dojo.removeClass('suggestDlgBtn', 'hidden');\n";
		$text .= "       showDijitButton('suggestDlgBtn');\n";
		$text .= "       dijit.byId('suggestDlgCancelBtn').set('label', '" . _("Cancel") . "');\n";
		$text .= "       dijit.byId('suggestedTimes').hide();\n";
		$text .= "       dojo.byId('suggestContent').innerHTML = '';\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		print $text;
	}
	else {
		$text = str_replace("\n", ' ', $text);
		$text = str_replace("('", "(\'", $text);
		$text = str_replace("')", "\')", $text);
		print "document.body.style.cursor = 'default';";
		if($refresh)
			print "refresh_timer = setTimeout(resRefresh, 20000);\n";
		print(setAttribute('subcontent', 'innerHTML', $text));
		print "AJdojoCreate('subcontent');";
		if($incPaneDetails) {
			$text = detailStatusHTML($refreqid);
			print(setAttribute('resStatusText', 'innerHTML', $text));
		}
		print "checkResGone(" . json_encode($reqids) . ");";
		return;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getViewRequestHTMLitem($item, $var1, $data)
///
/// \param $item - name of HTML section to be generated
/// \param $var1 - generic variable to be used in HTML
/// \param $data - an array of any extra data to be used in HTML
///
/// \return a string of HTML
///
/// \brief generates HTML for a specific portion of the current reservations
/// page
///
////////////////////////////////////////////////////////////////////////////////
function getViewRequestHTMLitem($item, $var1='', $data=array()) {
	$r = '';
	if($item == 'connectbtn') {
		$r .= "    <TD>\n";
		$r .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$r .= "      <INPUT type=hidden name=continuation value=\"$var1\">\n";
		$r .= "      <button type=submit dojoType=\"dijit.form.Button\">\n";
		$r .= "      " . _("Connect!") . "\n";
		$r .= "      </button>\n";
		$r .= "      </FORM>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'deletebtn') {
		$r .= "    <TD>\n";
		$r .= "      <button dojoType=\"dijit.form.Button\">\n";
		$r .= _(        "Delete Reservation\n");
		$r .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$r .= "          endReservation('$var1');\n";
		$r .= "        </script>\n";
		$r .= "      </button>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'failedblock') {
		$r .= "    <TD nowrap>\n";
		$r .= "      <span class=scriptonly>\n";
		$r .= "      <span class=compstatelink>";
		$r .= "<a onClick=\"showResStatusPane($var1); return false;\" ";
		$r .= "href=\"#\">" . _("Reservation failed") . "</a></span>\n";
		$r .= "      </span>\n";
		$r .= "      <noscript>\n";
		$r .= "      <span class=scriptoff>\n";
		$r .= "      <span class=compstatelink>";
		$r .= _("Reservation failed") . "</span>\n";
		$r .= "      </span>\n";
		$r .= "      </noscript>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'removebtn') {
		$r .= "    <TD>\n";
		$r .= "      <button dojoType=\"dijit.form.Button\">\n";
		$r .= "        " . _("Remove") . "\n";
		$r .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$r .= "          removeReservation('$var1');\n";
		$r .= "        </script>\n";
		$r .= "      </button>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'timeoutblock') {
		$r .= "    <TD>\n";
		$r .= "      <span class=compstatelink>" . _("Reservation has timed out") . "</span>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'pendingblock') {
		$r .= "    <TD>\n";
		$r .= "      <span class=scriptonly>\n";
		$r .= "      <span class=compstatelink><i>";
		$r .= "<a onClick=\"showResStatusPane($var1); ";
		$r .= "return false;\" href=\"#\">" . _("Pending...") . "</a></i></span>\n";
		$r .= "      </span>\n";
		$r .= "      <noscript>\n";
		$r .= "      <span class=scriptoff>\n";
		$r .= "      <span class=compstatelink>";
		$r .= "<i>" . _("Pending...") . "</i></span>\n";
		$r .= "      </span>\n";
		$r .= "      </noscript>\n";
		if(! empty($data['text']))
			$r .= "      {$data['text']}";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'openmoreoptions') {
		$r .= "    <TD align=right>\n";
		$r .= "      <div dojoType=\"dijit.form.DropDownButton\">\n";
		$r .= "        <span>" . _("More Options") . "...</span>\n";
		$r .= "        <div dojoType=\"dijit.Menu\">\n";
		return $r;
	}
	if($item == 'editoption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("Edit") . "\"\n";
		$r .= "               onClick=\"editReservation('$var1');\">\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'endcreateoption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("End Reservation & Create Image") . "\"\n";
		if($data['doescape'])
			$r .= "               onClick=\"window.location.href=\'$var1\';\">\n";
		else
			$r .= "               onClick=\"window.location.href='$var1';\">\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'endcreateoptiondisable') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("End Reservation & Create Image") . "\" disabled\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'checkpointoption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("Create Image") . "\"\n";
		if($data['doescape'])
			$r .= "               onClick=\"window.location.href=\'$var1\';\">\n";
		else
			$r .= "               onClick=\"window.location.href='$var1';\">\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'checkpointoptiondisable') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("Create Image") . "\" disabled\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'rebootoption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("Reboot") . "\">\n";
		$r .= "            <script type=\"dojo/method\" event=\"onClick\">\n";
		$r .= "              rebootRequest('$var1');\n";
		$r .= "            </script>\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'rebootoptiondisable') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("Reboot") . "\" disabled>\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'reinstalloption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("Reinstall") . "\">\n";
		$r .= "            <script type=\"dojo/method\" event=\"onClick\">\n";
		$r .= "              showReinstallRequest('$var1');\n";
		$r .= "            </script>\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'reinstalloptiondisable') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . _("Reinstall") . "\" disabled>\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'imagename') {
		$r .= "    <TD>" . str_replace("'", "&#39;", $var1);
		if($data['addtest'])
			$r .= _(" (Testing)");
		$r .= "</TD>\n";
		return $r;
	}
	if($item == 'starttime') {
		if(datetimeToUnix($data['start']) < datetimeToUnix($data['requested']))
			$r .= "    <TD>" . prettyDatetime($data['requested'], 1) . "</TD>\n";
		else
			$r .= "    <TD>" . prettyDatetime($data['start'], 1) . "</TD>\n";
		return $r;
	}
	if($item == 'endtime') {
		if($data['end'] == '2038-01-01 00:00:00')
			$r .= "    <TD>" . _("(none)") . "</TD>\n";
		else
			$r .= "    <TD>" . prettyDatetime($data['end'], 1) . "</TD>\n";
		return $r;
	}
	if($item == 'requesttime') {
		$r .= "    <TD>" . prettyDatetime($var1, 1) . "</TD>\n";
		return $r;
	}
	if($item == 'servername') {
		$r .= "    <TD>$var1</TD>\n";
		return $r;
	}
	if($item == 'serverdetails') {
		$r .= "<TD>\n";
		$r .= "<a id=\"serverdetails$var1\" tabindex=0>";
		$r .= "<img alt=\"details\" src=\"images/list.gif\"></a>\n";
		$r .= "<div dojoType=\"vcldojo.HoverTooltip\" connectId=\"";
		$r .= "serverdetails$var1\">\n";
		$r .= "<strong>" . _("Owner") . "</strong>:" . " {$data['owner']}<br>\n";
		$r .= "<strong>" . _("Environment") . "</strong>:" . " {$data['image']}<br>\n";
		$r .= "<strong>" . _("Start Time") . "</strong>: " . prettyDatetime($data['starttime'], 1) . "<br>\n";
		$r .= "<strong>" . _("Initially Requested") . "</strong>: " . prettyDatetime($data['requesttime'], 1) . "<br>\n";
		if(empty($data['admingroup']))
			$r .= "<strong>" . _("Admin User Group") . "</strong>: (" . _("none") . ")<br>\n";
		else
			$r .= "<strong>" . _("Admin User Group") . "</strong>:" . " {$data['admingroup']}<br>\n";
		if(empty($data['logingroup']))
			$r .= "<strong>" . _("Access User Group") . "</strong>: " . _("(none)") . "<br>\n";
		else
			$r .= "<strong>" . _("Access User Group") . "</strong>:" . " {$data['logingroup']}<br>\n";
		if($data['stateid'] == 8)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("In Use") . "\n";
		elseif($data['stateid'] == 24)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("Checkpointing") . "\n";
		elseif($data['stateid'] == 5)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("Failed") . "\n";
		elseif($data['stateid'] == 13)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("New") . "\n";
		elseif($data['stateid'] == 28)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("Hard Rebooting") . "\n";
		elseif($data['stateid'] == 26)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("Soft Rebooting") . "\n";
		elseif($data['stateid'] == 27)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("Reinstalling") . "\n";
		elseif($data['stateid'] == 6)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("Loading") . "\n";
		elseif($data['stateid'] == 3)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("In Use") . "\n";
		elseif($data['stateid'] == 11)
			$r .= "<strong>" . _("Status") . "</strong>: " . _("Timed Out") . "\n";
		$r .= "</div>\n";
		$r .= "</TD>\n";
		return $r;
	}
	if($item == 'timeoutdata') {
		if($data['currstateid'] == 8 ||
		   ($data['currstateid'] == 14 && $data['laststateid'] == 8)) {
			$end = datetimeToUnix($data['end']) + 15;
			$r .= "     <input type=\"hidden\" class=\"timeoutvalue\" value=\"$end\">\n";
		}
		else {
			$timeout = getReservationNextTimeout($data['resid']);
			if(! is_null($timeout))
				$r .= "     <input type=\"hidden\" class=\"timeoutvalue\" value=\"$timeout\">\n";
		}
		return $r;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn detailStatusHTML($reqid)
///
/// \param $reqid - a request id
///
/// \return html text showing detailed status from computerloadlog for specified
/// request
///
/// \brief gathers information about the state flow for $reqid and formats it
/// nicely for a user to view
///
////////////////////////////////////////////////////////////////////////////////
function detailStatusHTML($reqid) {
	$requests = getUserRequests("all");
	$found = 0;
	foreach($requests as $request) {
		if($request['id'] == $reqid) {
			$found = 1;
			break;
		}
	}
	if(! $found) {
		$text  = _("The selected reservation is no longer available.  Go to ");
		$text .= "<a href=" . BASEURL . SCRIPT . "?mode=newRequest>";
		$text .= _("New Reservations</a> to request a new reservation or ");
		$text .= _("select another one that is available.");
		return $text;
	}
	if($request['imageid'] == $request['compimageid'])
		$nowreq = 1;
	else
		$nowreq = 0;
	$flow = getCompStateFlow($request['computerid']);

	# cluster reservations not supported here yet
	# info on reboots/reinstalls not available yet
	if(empty($flow) ||
		count($request['reservations']) > 0 ||
		($request['currstateid'] == 14 && $request['laststateid'] == 26) ||
		/*($request['currstateid'] == 14 && $request['laststateid'] == 27) ||*/
		($request['currstateid'] == 14 && $request['laststateid'] == 28)) {
		$noinfo =  _("No detailed loading information is available for this ");
		$noinfo .= _("reservation.");
		return $noinfo;
	}

	$logdata = getCompLoadLog($request['resid']);

	# determine an estimated load time for the image
	$imgLoadTime = getImageLoadEstimate($request['imageid']);
	if($imgLoadTime == 0) {
		$images = getImages(0, $request['imageid']);
		$imgLoadTime = $images[$request['imageid']]['reloadtime'] * 60;
	}
	$time = 0;
	$now = time();
	$text = "<table summary=\"displays a list of states the reservation must "
	      . "go through to become ready and how long each state will take or "
			. "has already taken\" id=resStatusTable>";
	$text .= "<colgroup>";
	$text .= "<col class=resStatusColState />";
	$text .= "<col class=resStatusColEst />";
	$text .= "<col class=resStatusColTotal />";
	$text .= "</colgroup>";
	$text .= "<tr>";
	$text .= _("<th align=right><br>State</th>");
	$text .= _("<th>Est/Act<br>Time</th>");
	$text .= _("<th>Total<br>Time</th>");
	$text .= "</tr>";

	$slash = "<font color=black>/</font>";
	$total = 0;
	$id = "";
	$last = array();
	$logstateids = array();
	$skippedstates = array();
	# loop through all states in the log data
	foreach($logdata as $data) {
		# keep track of the states in the log data
		array_push($logstateids, $data['loadstateid']);
		# keep track of any skipped states
		if(! empty($last) &&
			$last['loadstateid'] != $flow['repeatid'] &&
		   $data['loadstateid'] != $flow['data'][$last['loadstateid']]['nextstateid']) {
			array_push($skippedstates, $flow['data'][$last['loadstateid']]['nextstateid']);
		}
		// if we reach a repeat state, include a message about having to go back
		if($data['loadstateid'] == $flow['repeatid']) {
			if(empty($id))
				return $noinfo;
			$text .= "<tr>";
			$text .= _("<td colspan=3><hr>problem at state ");
			$text .= "\"{$flow['data'][$id]['nextstate']}\"";
			$query = "SELECT additionalinfo "
			       . "FROM computerloadlog "
			       . "WHERE loadstateid = {$flow['repeatid']} AND "
			       .       "reservationid = {$request['resid']} AND "
			       .       "timestamp = '" . unixToDatetime($data['ts']) . "'";
			$qh = doQuery($query, 101);
			if($row = mysql_fetch_assoc($qh)) {
				$reason = $row['additionalinfo'];
				$text .= _("<br>retrying at state \"") . "$reason\"";
			}
			$text .= "<hr></td></tr>";
			$total += $data['time'];
			$last = $data;
			continue;
		}
		$id = $data['loadstateid'];
		// if in post config state, compute estimated time for the state
		if($flow['data'][$id]['statename'] == 'loadimagecomplete') {
			$addtime = 0;
			foreach($skippedstates as $stateid)
				$addtime += $flow['data'][$stateid]['statetime'];
			# this state's time is (avg image load time - all other states time +
			#                       state time for any skipped states)
			$tmp = $imgLoadTime - $flow['totaltime'] + $addtime;
			if($tmp < 0)
				$flow['data'][$id]['statetime'] = 0;
			else
				$flow['data'][$id]['statetime'] = $tmp;
		}
		$total += $data['time'];
		$text .= "<tr>";
		$text .= "<td nowrap align=right><font color=green>";
		$text .= _($flow['data'][$id]['state']) . "($id)</font></td>";
		$text .= "<td nowrap align=center><font color=green>";
		$text .= secToMinSec($flow['data'][$id]['statetime']) . $slash;
		$text .= secToMinSec($data['time']) . "</font></td>";
		$text .= "<td nowrap align=center><font color=green>";
		$text .= secToMinSec($total) . "</font></td>";
		$text .= "</tr>";
		$last = $data;
	}
	# $id will be set if there was log data, use the first state in the flow
	//    if it isn't set
	if(! empty($id))
		$id = $flow['nextstates'][$id];
	else
		$id = $flow['stateids'][0];

	# determine any skipped states
	$matchingstates = array();
	foreach($flow['stateids'] as $stateid) {
		if($stateid == $id)
			break;
		array_push($matchingstates, $stateid);
	}
	$skippedstates = array_diff($matchingstates, $logstateids);
	$addtime = 0;
	foreach($skippedstates as $stateid)
		$addtime += $flow['data'][$stateid]['statetime'];

	$first = 1;
	$count = 0;
	# loop through the states in the flow that haven't been reached yet
	# $count is included to protect against an infinite loop
	while(! is_null($id) && $count < 100) {
		$count++;
		// if in post config state, compute estimated time for the state
		if($flow['data'][$id]['statename'] == 'loadimagecomplete') {
			# this state's time is (avg image load time - all other states time +
			#                       state time for any skipped states)
			$tmp = $imgLoadTime - $flow['totaltime'] + $addtime;
			if($tmp < 0)
				$flow['data'][$id]['statetime'] = 0;
			else
				$flow['data'][$id]['statetime'] = $tmp;
		}
		// if first time through this loop, this is the current state
		if($first) {
			// if request has failed, it was during this state, get reason
			if($request['currstateid'] == 5) {
				$query = "SELECT additionalInfo, "
				       .        "UNIX_TIMESTAMP(timestamp) AS ts "
				       . "FROM computerloadlog "
				       . "WHERE loadstateid = (SELECT id "
				       .                      "FROM computerloadstate "
				       .                      "WHERE loadstatename = 'failed') AND "
				       . "reservationid = {$request['resid']} "
				       . "ORDER BY id "
				       . "LIMIT 1";
				$qh = doQuery($query, 101);
				if($row = mysql_fetch_assoc($qh)) {
					$reason = $row['additionalInfo'];
					if(! empty($data))
						$currtime = $row['ts'] - $data['ts'];
					else
						$currtime = $row['ts'] -
						            datetimeToUnix($request['daterequested']);
				}
				else {
					$text  = _("No detailed information is available for this ");
					$text .= _("reservation.");
					return $text;
				}
				$text .= "<tr>";
				$text .= "<td nowrap align=right><font color=red>";
				$text .= _($flow['data'][$id]['state']) . "($id)</font></td>";
				$text .= "<td nowrap align=center><font color=red>";
				$text .= secToMinSec($flow['data'][$id]['statetime']);
				$text .= $slash . secToMinSec($currtime) . "</font></td>";
				$text .= "<td nowrap align=center><font color=red>";
				$text .= secToMinSec($total + $currtime) . "</font></td>";
				$text .= "</tr>";
				$text .= "</table>";
				if(strlen($reason))
					$text .= _("<br><font color=red>failed: ") . "$reason</font>";
				return $text;
			}
			# otherwise add text about current state
			else {
				if(! empty($data))
					$currtime = $now - $data['ts'];
				else
					$currtime = $now - datetimeToUnix($request['daterequested']);
				$text .= "<td nowrap align=right><font color=#CC8500>";
				$text .= _($flow['data'][$id]['state']) . "($id)</font></td>";
				$text .= "<td nowrap align=center><font color=#CC8500>";
				$text .= secToMinSec($flow['data'][$id]['statetime']);
				$text .= $slash . secToMinSec($currtime) . "</font></td>";
				$text .= "<td nowrap align=center><font color=#CC8500>";
				$text .= secToMinSec($total + $currtime) . "</font></td>";
				$text .= "</tr>";
				$first = 0;
			}
		}
		# add text about future states
		else {
			$text .= "<td nowrap align=right>";
			$text .= _($flow['data'][$id]['state']) . "($id)</td>";
			$text .= "<td nowrap align=center>";
			$text .= secToMinSec($flow['data'][$id]['statetime']) . "</td>";
			$text .= "<td></td>";
			$text .= "</tr>";
		}
		$id = $flow['nextstates'][$id];
	}
	$text .= "</table>";
	return $text;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewRequestInfo()
///
/// \brief prints a page with information about a specific request
///
////////////////////////////////////////////////////////////////////////////////
function viewRequestInfo() {
	$requestid = getContinuationVar('requestid');
	$request = getRequestInfo($requestid);
	if($request['forimaging'] || $request['stateid'] == 18 || $request['laststateid'] == 18)
		$reservation = $request['reservations'][0];
	else {
		foreach($request["reservations"] as $res) {
			if($res["forcheckout"]) {
				$reservation = $res;
				break;
			}
		}
	}
	$states = getStates();
	$userinfo = getUserInfo($request["userid"], 1, 1);
	print "<DIV align=center>\n";
	print "<H2>View Reservation</H2>\n";
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH align=right>User:</TH>\n";
	print "    <TD>" . $userinfo["unityid"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Start&nbsp;Time:</TH>\n";
	if(datetimeToUnix($request["start"]) < 
	   datetimeToUnix($request["daterequested"])) {
		print "    <TD>" . prettyDatetime($request["daterequested"]) . "</TD>\n";
	}
	else {
		print "    <TD>" . prettyDatetime($request["start"]) . "</TD>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>End&nbsp;Time:</TH>\n";
	print "    <TD>" . prettyDatetime($request["end"]) . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Request&nbsp;Time:</TH>\n";
	print "    <TD>" . prettyDatetime($request["daterequested"]) . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Last&nbsp;Modified:</TH>\n";
	if(! empty($request["datemodified"])) {
		print "    <TD>" . prettyDatetime($request["datemodified"]) . "</TD>\n";
	}
	else {
		print "    <TD>Never Modified</TD>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Current&nbsp;State:</TH>\n";
	print "    <TD>" . $states[$request["stateid"]] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Last&nbsp;State:</TH>\n";
	print "    <TD>";
	if($request["laststateid"]) {
		print $states[$request["laststateid"]];
	}
	else {
		print "None";
	}
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Image:</TH>\n";
	print "    <TD>{$reservation['prettyimage']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname:</TH>\n";
	print "    <TD>{$request['reservations'][0]["hostname"]}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>IP&nbsp;Address:</TH>\n";
	print "    <TD>{$request['reservations'][0]["reservedIP"]}</TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	if(count($request['reservations'] > 1)) {
		array_shift($request['reservations']);
		print "Subimages:<br>\n";
		print "<table summary=\"\">\n";
		foreach($request["reservations"] as $res) {
			print "  <TR>\n";
			print "    <TH align=right>Image:</TH>\n";
			print "    <TD>{$res["prettyimage"]}</TD>\n";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>Hostname:</TH>\n";
			print "    <TD>{$res["hostname"]}</TD>\n";
			print "  </TR>\n";
			print "  <TR>\n";
			print "    <TH align=right>IP&nbsp;Address:</TH>\n";
			print "    <TD>{$res["reservedIP"]}</TD>\n";
			print "  </TR>\n";
		}
		print "</table>\n";
	}
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	/*print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=adminEditRequest>\n";
	print "      <INPUT type=hidden name=requestid value=$requestid>\n";
	print "      <INPUT type=submit value=Modify>\n";
	print "      </FORM>\n";
	print "    </TD>\n";*/
	print "    <TD>\n";
	$cdata = array('requestid' => $requestid,
	               'notbyowner' => 1,
	               'ttdata' => getContinuationVar('ttdata'),
	               'fromtimetable' => 1);
	$cont = addContinuationsEntry('AJconfirmDeleteRequest', $cdata, SECINDAY);
	print "      <button dojoType=\"dijit.form.Button\">\n";
	print "        " . _("Delete Reservation") . "\n";
	print "	      <script type=\"dojo/method\" event=\"onClick\">\n";
	print "          endReservation('$cont');\n";
	print "        </script>\n";
	print "      </button>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "</DIV>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "      id=\"endResDlg\"\n";
	print "      title=\"" . _("Delete Reservation") . "\"\n";
	print "      duration=250\n";
	print "      draggable=true>\n";
	print "   <div id=\"endResDlgContent\"></div>\n";
	print "   <input type=\"hidden\" id=\"endrescont\">\n";
	print "   <input type=\"hidden\" id=\"endresid\">\n";
	print "   <div align=\"center\">\n";
	print "   <button id=\"endResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
	print "    " . _("Delete Reservation") . "\n";
	print "	   <script type=\"dojo/method\" event=\"onClick\">\n";
	print "       submitDeleteReservation();\n";
	print "     </script>\n";
	print "   </button>\n";
	print "   <button dojoType=\"dijit.form.Button\">\n";
	print "     " . _("Cancel") . "\n";
	print "	   <script type=\"dojo/method\" event=\"onClick\">\n";
	print "       dijit.byId('endResDlg').hide();\n";
	print "       dojo.byId('endResDlgContent').innerHTML = '';\n";
	print "     </script>\n";
	print "   </button>\n";
	print "   </div>\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJeditRequest()
///
/// \brief prints a page for a user to edit a previous request
///
////////////////////////////////////////////////////////////////////////////////
function AJeditRequest() {
	global $submitErr, $user;
	$requestid = getContinuationVar('requestid', 0);
	$request = getRequestInfo($requestid, 1);
	# check to see if reservation exists
	if(is_null($request)) {
		sendJSON(array('status' => 'resgone'));
		return;
	}
	$unixstart = datetimeToUnix($request["start"]);
	$unixend = datetimeToUnix($request["end"]);
	$duration = $unixend - $unixstart;
	$now = time();
	$maxtimes = getUserMaxTimes();
	$groupid = getUserGroupID('Specify End Time', 1);
	$members = getUserGroupMembers($groupid);
	if(array_key_exists($user['id'], $members) || $request['serverrequest'])
		$openend = 1;
	else
		$openend = 0;
	$h = '';

	# determine the current total length of the reservation
	$reslen = ($unixend - unixFloor15($unixstart)) / 60;
	$timeval = getdate($unixstart);
	if(($timeval["minutes"] % 15) != 0)
		$reslen -= 15;
	$cdata = array('requestid' => $requestid,
	               'openend' => $openend,
	               'modifystart' => 0,
	               'allowindefiniteend' => 0);
	if($request['serverrequest']) {
		if(empty($request['servername']))
			$request['servername'] = $request['reservations'][0]['prettyimage'];
		$h .= _("Name") . ": <input type=\"text\" name=\"servername\" id=\"servername\" ";
		$h .= "dojoType=\"dijit.form.TextBox\" style=\"width: 400px\" ";
		$h .= "value=\"{$request['servername']}\"><br>";
		if($user['showallgroups'])
			$groups = getUserGroups();
		else
			$groups = getUserGroups(0, $user['affiliationid']);
		$h .= _("Admin User Group") . ": ";
		if(USEFILTERINGSELECT && count($groups) < FILTERINGSELECTTHRESHOLD) {
			$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"admingrpsel\" ";
			$h .= "highlightMatch=\"all\" autoComplete=\"false\">";
		}
		else
			$h .= "<select id=\"admingrpsel\">";
		if(! empty($request['admingroupid']) &&
		   ! array_key_exists($request['admingroupid'], $groups)) {
			$id = $request['admingroupid'];
			$name = getUserGroupName($request['admingroupid'], 1);
			$h .= "<option value=\"$id\">$name</option>\n";
		}
		$h .= "<option value=\"0\">" . _("None") . "</option>\n";
		foreach($groups as $id => $group) {
			if($id == $request['admingroupid'])
				$h .= "<option value=\"$id\" selected>{$group['name']}</option>";
			else
				$h .= "<option value=\"$id\">{$group['name']}</option>";
		}
		$h .= "</select><br>";
		$h .= _("Access User Group") . ": ";
		if(USEFILTERINGSELECT && count($groups) < FILTERINGSELECTTHRESHOLD) {
			$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"logingrpsel\" ";
			$h .= "highlightMatch=\"all\" autoComplete=\"false\">";
		}
		else
			$h .= "<select id=\"logingrpsel\">";
		if(! empty($request['logingroupid']) &&
		   ! array_key_exists($request['logingroupid'], $groups)) {
			$id = $request['logingroupid'];
			$name = getUserGroupName($request['logingroupid'], 1);
			$h .= "<option value=\"$id\">$name</option>\n";
		}
		$h .= "<option value=\"0\">None</option>\n";
		foreach($groups as $id => $group) {
			if($id == $request['logingroupid'])
				$h .= "<option value=\"$id\" selected>{$group['name']}</option>";
			else
				$h .= "<option value=\"$id\">{$group['name']}</option>";
		}
		$h .= "</select><br><br>";
	}
	// if future, allow start to be modified
	if($unixstart > $now) {
		$cdata['modifystart'] = 1;
		$txt  = _("Modify reservation for") . " <b>{$request['reservations'][0]['prettyimage']}</b> "; 
		$txt .= _("starting ") . prettyDatetime($request["start"]) . ": <br>";
		$h .= preg_replace("/(.{1,60}[ \n])/", '\1<br>', $txt);
		$days = array();
		$startday = date('l', $unixstart);
		for($cur = time(), $end = $cur + DAYSAHEAD * SECINDAY; 
		    $cur < $end; 
		    $cur += SECINDAY) {
			$index = date('Ymd', $cur);
			$days[$index] = date('l', $cur);
		}
		$cdata['startdays'] = array_keys($days);
		$h .= _("Start") . ": <select dojoType=\"dijit.form.Select\" id=\"day\" ";
		$h .= "onChange=\"resetEditResBtn();\">";
		foreach($days as $id => $name) {
			if($name == $startday)
				$h .= "<option value=\"$id\" selected=\"selected\">$name</option>";
			else
				$h .= "<option value=\"$id\">$name</option>";
		}
		$h .= "</select>";
		$h .= _("&nbsp;At&nbsp;");
		$tmp = explode(' ' , $request['start']);
		$stime = $tmp[1];
		$h .= "<div type=\"text\" dojoType=\"dijit.form.TimeTextBox\" ";
		$h .= "id=\"editstarttime\" style=\"width: 78px\" value=\"T$stime\" ";
		$h .= "onChange=\"resetEditResBtn();\"></div>";
		$h .= "<small>(" . date('T') . ")</small><br><br>";
		$durationmatch = 0;
		if($request['serverrequest']) {
			$cdata['allowindefiniteend'] = 1;
			if($request['end'] == '2038-01-01 00:00:00') {
				$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"indefiniteradio\" ";
				$h .= "checked onChange=\"resetEditResBtn();\">";
			}
			else {
				$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"indefiniteradio\" ";
				$h .= "onChange=\"resetEditResBtn();\">";
			}
			$h .= _("<label for=\"indefiniteradio\">Indefinite Ending</label>");
		}
		else {
			$durationmin = $duration / 60;
			if($request['forimaging'] && $maxtimes['initial'] < 720) # make sure at least 12 hours available for imaging reservations
				$maxtimes['initial'] = 720;
			$imgdata = getImages(1, $request['reservations'][0]['imageid']);
			$maxlen = $imgdata[$request['reservations'][0]['imageid']]['maxinitialtime'];
			if($maxlen > 0 && $maxlen < $maxtimes['initial'])
				$maxtimes['initial'] = $maxlen;
			$lengths = array();
			if($maxtimes["initial"] >= 30) {
				$lengths["30"] = "30 " . _("minutes");
				if($durationmin == 30)
					$durationmatch = 1;
			}
			if($maxtimes["initial"] >= 45) {
				$lengths["45"] = "45 " . _("minutes");
				if($durationmin == 45)
					$durationmatch = 1;
			}
			if($maxtimes["initial"] >= 60) {
				$lengths["60"] = "1 " . _("hour");
				if($durationmin == 60)
					$durationmatch = 1;
			}
			for($i = 120; $i <= $maxtimes["initial"] && $i < 2880; $i += 120) {
				$lengths[$i] = $i / 60 . _(" hours");
				if($durationmin == $i)
					$durationmatch = 1;
			}
			for($i = 2880; $i <= $maxtimes["initial"]; $i += 1440) {
				$lengths[$i] = $i / 1440 . _(" days");
				if($durationmin == $i)
					$durationmatch = 1;
			}
			if($openend) {
				if($durationmatch) {
					$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"lengthradio\" ";
					$h .= "onChange=\"resetEditResBtn();\" checked>";
				}
				else {
					$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"lengthradio\" ";
					$h .= "onChange=\"resetEditResBtn();\">";
				}
				$h .= "<label for=\"lengthradio\">";
			}
			$h .= _("Duration") . ':';
			if($openend)
				$h .= "</label>";
			$h .= "<select dojoType=\"dijit.form.Select\" id=\"length\" ";
			$h .= "onChange=\"selectLength();\">";
			$cdata['lengths'] = array_keys($lengths);
			foreach($lengths as $id => $name) {
				if($id == $duration / 60)
					$h .= "<option value=\"$id\" selected=\"selected\">$name</option>";
				else
					$h .= "<option value=\"$id\">$name</option>";
			}
			$h .= "</select>";
		}
		if($openend) {
			if($request['serverrequest'] && $request['end'] == '2038-01-01 00:00:00') {
				$h .= "<br><INPUT type=\"radio\" name=\"ending\" id=\"dateradio\" ";
				$h .= "onChange=\"resetEditResBtn();\">";
				$edate = '';
				$etime = '';
			}
			else {
				if(! $request['serverrequest'] && $durationmatch) {
					$h .= "<br><INPUT type=\"radio\" name=\"ending\" id=\"dateradio\" ";
					$h .= "onChange=\"resetEditResBtn();\">";
				}
				else {
					$h .= "<br><INPUT type=\"radio\" name=\"ending\" id=\"dateradio\" ";
					$h .= "checked onChange=\"resetEditResBtn();\">";
				}
				$tmp = explode(' ', $request['end']);
				$edate = $tmp[0];
				$etime = $tmp[1];
			}
			$h .= "<label for=\"dateradio\">";
			$h .= _("End:");
			$h .= "</label>";
			$h .= "<div type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
			$h .= "id=\"openenddate\" style=\"width: 78px\" value=\"$edate\" ";
			$h .= "onChange=\"selectEnding();\"></div>";
			$h .= "<div type=\"text\" dojoType=\"dijit.form.TimeTextBox\" ";
			$h .= "id=\"openendtime\" style=\"width: 78px\" value=\"T$etime\" ";
			$h .= "onChange=\"selectEnding();\"></div>";
			$h .= "<small>(" . date('T') . ")</small>";
		}
		$h .= "<br><br>";
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data = array('status' => 'modify',
		              'html' => $h,
		              'requestid' => $requestid,
		              'cont' => $cont);
		sendJSON($data);
		return;
	}
	# check for max time being reached
	if($request['forimaging'] && $maxtimes['total'] < 720)
		$maxcheck = 720;
	else
		$maxcheck = $maxtimes['total'];
	if(! $openend && ($reslen >= $maxcheck)) {
		$h .= _("You are only allowed to extend your reservation such that it ");
		$h .= _("has a total length of ") . minToHourMin($maxcheck);
		$h .= _(". This reservation<br>already meets that length. Therefore, ");
		$h .= _("you are not allowed to extend your reservation any further.<br><br>");
		sendJSON(array('status' => 'nomodify', 'html' => $h));
		return;
	}
	// if started, only allow end to be modified
	# check for following reservations
	$timeToNext = timeToNextReservation($request);
	# check for 30 minutes because need 15 minute buffer and min can 
	# extend by is 15 min
	if($timeToNext < 30) {
		$movedall = 1;
		foreach($request["reservations"] as $res) {
			if(! moveReservationsOffComputer($res["computerid"], 1)) {
				$movedall = 0;
				break;
			}
		}
		if(! $movedall) {
			$h .= _("The computer you are using has another reservation<br>");
			$h .= _("immediately following yours. Therefore, you cannot<br>extend ");
			$h .= _("your reservation because it would overlap<br>with the next ");
			$h .= _("one.<br>");
			sendJSON(array('status' => 'nomodify', 'html' => $h));
			return;
		}
		$timeToNext = timeToNextReservation($request);
	}
	if($timeToNext >= 15)
		$timeToNext -= 15;
	//if have time left to extend it, create an array of lengths based on maxextend that has a cap
	# so we don't run into another reservation and we can't extend past the totalmax
	$lengths = array();
	if($request['forimaging'] && $maxtimes['total'] < 720) # make sure at least 12 hours available for imaging reservations
		$maxtimes['total'] = 720;
	if($timeToNext == -1) {
		// there is no following reservation
		if((($reslen + 15) <= $maxtimes["total"]) && (15 <= $maxtimes["extend"]))
			$lengths["15"] = "15 " . _("minutes");
		if((($reslen + 30) <= $maxtimes["total"]) && (30 <= $maxtimes["extend"]))
			$lengths["30"] = "30 " . _("minutes");
		if((($reslen + 45) <= $maxtimes["total"]) && (45 <= $maxtimes["extend"]))
			$lengths["45"] = "45 " . _("minutes");
		if((($reslen + 60) <= $maxtimes["total"]) && (60 <= $maxtimes["extend"]))
			$lengths["60"] = _("1 hour");
		for($i = 120; (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]) && $i < 2880; $i += 120)
			$lengths[$i] = $i / 60 . _(" hours");
		for($i = 2880; (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]); $i += 1440)
			$lengths[$i] = $i / 1440 . _(" days");
	}
	else {
		if($timeToNext >= 15 && (($reslen + 15) <= $maxtimes["total"]) && (15 <= $maxtimes["extend"]))
			$lengths["15"] = "15 " . _("minutes");
		if($timeToNext >= 30 && (($reslen + 30) <= $maxtimes["total"]) && (30 <= $maxtimes["extend"]))
			$lengths["30"] = "30 " . _("minutes");
		if($timeToNext >= 45 && (($reslen + 45) <= $maxtimes["total"]) && (45 <= $maxtimes["extend"]))
			$lengths["45"] = "45 " . _("minutes");
		if($timeToNext >= 60 && (($reslen + 60) <= $maxtimes["total"]) && (60 <= $maxtimes["extend"]))
			$lengths["60"] = _("1 hour");
		for($i = 120; ($i <= $timeToNext) && (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]) && $i < 2880; $i += 120)
			$lengths[$i] = $i / 60 . _(" hours");
		for($i = 2880; ($i <= $timeToNext) && (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]); $i += 1440)
			$lengths[$i] = $i / 1440 . _(" days");
	}
	$cdata['lengths'] = array_keys($lengths);
	if($timeToNext == -1 || $timeToNext >= $maxtimes['total']) {
		if($openend) {
			if(! empty($lengths)) {
				$h .= _("You can extend this reservation by a selected amount or<br>");
				$h .= _("change the end time to a specified date and time.<br><br>");
			}
			else
				$h .= _("Modify the end time for this reservation:<br><br>");
		}
		else {
			if($request['forimaging'] && $maxtimes['total'] < 720)
				$maxcheck = 720;
			else
				$maxcheck = $maxtimes['total'];
			$h .= _("You can extend this reservation by up to ");
			$h	.= minToHourMin($maxtimes["extend"]) . _(", but not<br>exceeding ");
			$h	.= minToHourMin($maxcheck) . _(" for your total reservation time.");
			$h .= "<br><br>";
		}
	}
	else {
		$t  = _("The computer you are using has another reservation following ");
		$t .= _("yours. Therefore, you can only extend this reservation for ");
		$t .= _("another ") . prettyLength($timeToNext) . ". <br>";
		$h .= preg_replace("/(.{1,60}[ ])/", '\1<br>', $t);
	}
	# extend by drop down
	# extend by specifying end time if $openend
	if($openend) {
		if($request['serverrequest']) {
			$cdata['allowindefiniteend'] = 1;
			$endchecked = 0;
			if($request['end'] == '2038-01-01 00:00:00') {
				$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"indefiniteradio\" ";
				$h .= "checked onChange=\"resetEditResBtn();\">";
				$h .= "<label for=\"indefiniteradio\">Indefinite Ending</label>";
				$h .= "<br><INPUT type=\"radio\" name=\"ending\" id=\"dateradio\" ";
				$h .= "onChange=\"resetEditResBtn();\">";
			}
			else {
				$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"indefiniteradio\" ";
				$h .= "onChange=\"resetEditResBtn();\">";
				$h .= "<label for=\"indefiniteradio\">Indefinite Ending</label>";
				$h .= "<br><INPUT type=\"radio\" name=\"ending\" id=\"dateradio\" ";
				$h .= "checked onChange=\"resetEditResBtn();\">";
				$endchecked = 1;
			}
			$h .= "<label for=\"dateradio\">";
		}
		elseif(! empty($lengths)) {
			$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"lengthradio\" ";
			$h .= "checked onChange=\"resetEditResBtn();\">";
			$h .= "<label for=\"lengthradio\">" . _("Extend reservation by:") . "</label>";
			$h .= "<select dojoType=\"dijit.form.Select\" id=\"length\" ";
			$h .= "onChange=\"selectLength();\" maxHeight=\"250\">";
			foreach($lengths as $id => $name)
				$h .= "<option value=\"$id\">$name</option>";
			$h .= "</select>";
			$h .= "<br><INPUT type=\"radio\" name=\"ending\" id=\"dateradio\" ";
			$h .= "onChange=\"resetEditResBtn();\">";
			$h .= "<label for=\"dateradio\">";
		}
		if($request['serverrequest']) {
			$h .= _("End:");
			if($endchecked) {
				$tmp = explode(' ', $request['end']);
				$edate = $tmp[0];
				$etime = $tmp[1];
			}
			else {
				$edate = '';
				$etime = '';
			}
		}
		else {
			$h .= _("Change ending to:");
			$tmp = explode(' ', $request['end']);
			$edate = $tmp[0];
			$etime = $tmp[1];
		}
		if(! empty($lengths) || $request['serverrequest'])
			$h .= "</label>";
		$h .= "<div type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
		$h .= "id=\"openenddate\" style=\"width: 78px\" value=\"$edate\" ";
		$h .= "onChange=\"selectEnding();\"></div>";
		$h .= "<div type=\"text\" dojoType=\"dijit.form.TimeTextBox\" ";
		$h .= "id=\"openendtime\" style=\"width: 78px\" value=\"T$etime\" ";
		$h .= "onChange=\"selectEnding();\"></div>";
		$h .= "<small>(" . date('T') . ")</small>";
		$h .= "<INPUT type=\"hidden\" name=\"enddate\" id=\"enddate\">";
		if($timeToNext > -1) {
			$extend = $unixend + ($timeToNext * 60);
			$extend = date('m/d/Y g:i A', $extend);
			$h .= _("<br><font color=red><strong>NOTE:</strong> Due to an upcoming ");
			$h .= _("reservation on the same computer,<br>");
			$h .= _("you can only extend this reservation until") . " $extend.</font>";
			$cdata['maxextend'] = $extend;
		}
	}
	else {
		$h .= _("Extend reservation by:");
		$h .= "<select dojoType=\"dijit.form.Select\" id=\"length\">";
		foreach($lengths as $id => $name)
			$h .= "<option value=\"$id\">$name</option>";
		$h .= "</select>";
	}
	$h .= "<br><br>";
	$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
	$data = array('status' => 'modify',
	              'html' => $h,
	              'requestid' => $requestid,
	              'cont' => $cont);
	sendJSON($data);
	return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitEditRequest()
///
/// \brief submits changes to a request and prints that it has been changed
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitEditRequest() {
	global $user;
	$requestid = getContinuationVar('requestid');
	$openend = getContinuationVar('openend');
	$modifystart = getContinuationVar('modifystart');
	$startdays = getContinuationVar('startdays');
	$lengths = getContinuationVar('lengths');
	$maxextend = getContinuationVar('maxextend');
	$allowindefiniteend = getContinuationVar('allowindefiniteend');

	$request = getRequestInfo($requestid, 1);
	if(is_null($request)) {
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		sendJSON(array('status' => 'norequest',
		               'html' => _('The selected reservation no longer exists.<br><br>'),
		               'cont' => $cont));
		return;
	}

	if($modifystart) {
		$day = processInputVar('day', ARG_NUMERIC, 0);
		if(! in_array($day, $startdays)) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => _('Invalid start day submitted'),
			               'cont' => $cont));
			return;
		}
		$starttime = processInputVar('starttime', ARG_STRING);
		if(! preg_match('/^(([01][0-9])|(2[0-3]))([0-5][0-9])$/', $starttime, $matches)) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => _("Invalid start time submitted"),
			               'cont' => $cont));
			return;
		}
		preg_match('/^([0-9]{4})([0-9]{2})([0-9]{2})$/', $day, $tmp);
		$startdt = "{$tmp[1]}-{$tmp[2]}-{$tmp[3]} {$matches[1]}:{$matches[4]}:00";
		$startts = datetimeToUnix($startdt);
	}
	else {
		$startdt = $request['start'];
		$startts = datetimeToUnix($startdt);
	}
	$endmode = processInputVar('endmode', ARG_STRING);
	if($endmode == 'length') {
		$length = processInputVar('length', ARG_NUMERIC);
		if(! in_array($length, $lengths)) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => _("Invalid duration submitted"),
			               'cont' => $cont));
			return;
		}
		if($modifystart)
			$endts = $startts + ($length * 60);
		else {
			$tmp = datetimeToUnix($request['end']);
			$endts = $tmp + ($length * 60);
		}
		$enddt = unixToDatetime($endts);
	}
	elseif($endmode == 'ending') {
		$ending = processInputVar('ending', ARG_NUMERIC);
		if(! preg_match('/^([0-9]{4})([0-9]{2})([0-9]{2})(([01][0-9])|(2[0-3]))([0-5][0-9])$/', $ending, $tmp) ||
		   ! checkdate($tmp[2], $tmp[3], $tmp[1])) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => _("Invalid end date/time submitted"),
			               'cont' => $cont));
			return;
		}
		$enddt = "{$tmp[1]}-{$tmp[2]}-{$tmp[3]} {$tmp[4]}:{$tmp[7]}:00";
		$endts = datetimeToUnix($enddt);
	}
	elseif($allowindefiniteend && $endmode == 'indefinite') {
		$endts = datetimeToUnix('2038-01-01 00:00:00');
		$enddt = unixToDatetime($endts);
	}
	else {
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		sendJSON(array('status' => 'error',
		               'errmsg' => _("Invalid data submitted"),
		               'cont' => $cont));
		return;
	}
	$updategroups = 0;
	$updateservername = 0;
	if($request['serverrequest']) {
		if($user['showallgroups'])
			$groups = getUserGroups(0);
		else
			$groups = getUserGroups(0, $user['affiliationid']);
		$admingroupid = processInputVar('admingroupid', ARG_NUMERIC);
		$logingroupid = processInputVar('logingroupid', ARG_NUMERIC);
		if(($admingroupid != 0 &&
		    ! array_key_exists($admingroupid, $groups) &&
		    $admingroupid != $request['admingroupid']) ||
		   ($logingroupid != 0 &&
		    ! array_key_exists($logingroupid, $groups) &&
		    $logingroupid != $request['logingroupid'])) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => _("Invalid user group submitted"),
			               'cont' => $cont));
			return;
		}
		$testadmingroupid = $admingroupid;
		if($admingroupid == 0)
			$testadmingroupid = '';
		$testlogingroupid = $logingroupid;
		if($logingroupid == 0)
			$testlogingroupid = '';
		if($testadmingroupid != $request['admingroupid'] ||
			$testlogingroupid != $request['logingroupid'])
			$updategroups = 1;
		$servername = processInputVar('servername', ARG_STRING);
		if(! preg_match('/^([-a-zA-Z0-9\.\(\)_ ]){3,255}$/', $servername)) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => _("The name can only contain letters, numbers, ")
			                        .  _("spaces, dashes(-), and periods(.) and can ")
			                        .  _("be from 3 to 255 characters long"),
			               'cont' => $cont));
			return;
		}
		if($servername != $request['servername']) {
			$servername = mysql_real_escape_string($servername);
			$updateservername = 1;
		}
	}

	// get semaphore lock
	if(! semLock())
		abort(3);

	$h = '';
	$max = getMaxOverlap($user['id']);
	if(checkOverlap($startts, $endts, $max, $requestid)) {
		if($max == 0) {
			$h .= _("The time you requested overlaps with another reservation<br>");
			$h .= _("you currently have. You are only allowed to have a single<br>");
			$h .= _("reservation at any given time. Please select another time<br>");
			$h .= _("for the reservation.<br><br>");
		}
		else {
			$h .= _("The time you requested overlaps with another reservation<br>");
			$h .= _("you currently have. You are allowed to have ") . $max . _("overlapping<br>");
			$h .= _("reservations at any given time. Please select another time<br>");
			$h .= _("for the reservation.<br><br>");
		}
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		sendJSON(array('status' => 'error', 'errmsg' => $h, 'cont' => $cont));
		semUnlock();
		return;
	}

	if($request['serverrequest'] &&
		(! empty($request['fixedIP']) || ! empty($request['fixedMAC']))) {
		$ip = $request['fixedIP'];
		$mac = $request['fixedMAC'];
	}
	else {
		$ip = '';
		$mac = '';
	}
	$imageid = $request['reservations'][0]['imageid'];
	$images = getImages();
	$rc = isAvailable($images, $imageid,
	                  $request['reservations'][0]['imagerevisionid'], $startts,
	                  $endts, $requestid, 0, 0, 0, $ip, $mac);
	$data = array();
	if($rc < 1) { 
		$cdata = array('now' => 0,
		               'start' => $startts, 
		               'end' => $endts,
		               'server' => $allowindefiniteend,
		               'imageid' => $imageid,
		               'requestid' => $requestid);
		if(! $modifystart)
			$cdata['extendonly'] = 1;
		$sugcont = addContinuationsEntry('AJshowRequestSuggestedTimes', $cdata);
		if(array_key_exists('subimages', $images[$imageid]) &&
		   count($images[$imageid]['subimages']))
			$data['sugcont'] = 'cluster';
		else
			$data['sugcont'] = $sugcont;
		addChangeLogEntry($request["logid"], NULL, $enddt, $startdt, NULL, NULL, 0);
	}
	if($rc == -3) {
		$msgip = '';
		$msgmac = '';
		if(! empty($ip))
			$msgip = " ($ip)";
		if(! empty($mac))
			$msgmac = " ($mac)";
		$h .= _("The reserved IP") . $msgip . _(" or MAC address") . $msgmac . _(" conflicts with another ");
		$h .= _("reservation using the same IP or MAC address. Please ");
		$h .= _("select a different time to use the image. ");
		$h = preg_replace("/(.{1,60}[ \n])/", '\1<br>', $h);
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data['status'] = 'conflict';
		$data['errmsg'] = $h;
		$data['cont'] = $cont;
		sendJSON($data);
		semUnlock();
		return;
	}
	elseif($rc == -2) {
		$h .= _("The time you requested overlaps with a maintenance window.<br>");
		$h .= _("Please select a different time to use the image.<br>");
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data['status'] = 'conflict';
		$data['errmsg'] = $h;
		$data['cont'] = $cont;
		sendJSON($data);
		semUnlock();
		return;
	}
	elseif($rc == -1) {
		$h .= _("You have requested an environment that is limited in the<br>");
		$h .= _("number of concurrent reservations that can be made. No further<br>");
		$h .= _("reservations for the environment can be made for the time you<br>");
		$h .= _("have selected. Please select another time for the reservation.<br><br>");
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data['status'] = 'conflict';
		$data['errmsg'] = $h;
		$data['cont'] = $cont;
		sendJSON($data);
		semUnlock();
		return;
	}
	elseif($rc > 0) {
		updateRequest($requestid);
		if($updategroups) {
			if($admingroupid == 0)
				$admingroupid = 'NULL';
			if($logingroupid == 0)
				$logingroupid = 'NULL';
			$query = "UPDATE serverrequest "
			       . "SET admingroupid = $admingroupid, "
			       .     "logingroupid = $logingroupid "
			       . "WHERE requestid = $requestid";
			doQuery($query, 101);
			addChangeLogEntryOther($request['logid'], "event:usergroups|admingroupid:$admingroupid|logingroupid:$logingroupid");
			$query = "UPDATE request "
			       . "SET stateid = 29 "
			       . "WHERE id = $requestid";
			doQuery($query, 101);
		}
		if($updateservername) {
			$query = "UPDATE serverrequest "
			       . "SET name = '$servername' "
			       . "WHERE requestid = $requestid";
			doQuery($query, 101);
		}
		sendJSON(array('status' => 'success'));
		semUnlock();
		return;
	}
	else {
		$h .= _("The time period you have requested is not available.<br>");
		$h .= _("Please select a different time.");
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data['status'] = 'conflict';
		$data['errmsg'] = $h;
		$data['cont'] = $cont;
		sendJSON($data);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJconfirmDeleteRequest()
///
/// \brief prints a confirmation page about deleting a request
///
////////////////////////////////////////////////////////////////////////////////
function AJconfirmDeleteRequest() {
	$requestid = getContinuationVar('requestid', 0);
	$notbyowner = getContinuationVar('notbyowner', 0);
	$fromtimetable = getContinuationVar('fromtimetable', 0);
	$request = getRequestInfo($requestid, 1);
	if(is_null($request)) {
		$data = array('error' => 1,
		              'msg' => _("The specified reservation no longer exists."));
		sendJSON($data);
		return;
	}
	if($request['forimaging'])
		$reservation = $request['reservations'][0];
	else {
		foreach($request["reservations"] as $res) {
			if($res["forcheckout"]) {
				$reservation = $res;
				break;
			}
		}
	}
	if(datetimeToUnix($request["start"]) > time()) {
		$text = _("Delete reservation for <b>") . $reservation["prettyimage"]
		      . _("</b> starting ") . prettyDatetime($request["start"]) . _("?<br>\n");
	}
	else {
		if($notbyowner == 0 && ! $reservation["production"]) {
			AJconfirmDeleteRequestProduction($request);
			return;
		}
		else {
			if($notbyowner == 0) {
				$text = _("Are you finished with your reservation for <strong>")
						. $reservation["prettyimage"] . _("</strong> that started ");
			}
			else {
				$userinfo = getUserInfo($request["userid"], 1, 1);
				$text = _("Delete reservation by") . " {$userinfo['unityid']}@"
				      . "{$userinfo['affiliation']} " . _("for <strong>")
				      . "{$reservation["prettyimage"]}</strong> " . _("that started ");
			}
			if(datetimeToUnix($request["start"]) <
				datetimeToUnix($request["daterequested"]))
				$text .= prettyDatetime($request["daterequested"]);
			else
				$text .= prettyDatetime($request["start"]);
			$text .= _("?<br>\n");
		}
	}
	$cdata = array('requestid' => $requestid,
	               'notbyowner' => $notbyowner,
	               'fromtimetable' => $fromtimetable);
	if($fromtimetable)
		$cdata['ttdata'] = getContinuationVar('ttdata');
	$cont = addContinuationsEntry('AJsubmitDeleteRequest', $cdata, SECINDAY, 0, 0);
	$text = preg_replace("/(.{1,60}[ \n])/", '\1<br>', $text);
	$data = array('content' => $text,
	              'cont' => $cont,
	              'requestid' => $requestid,
	              'btntxt' => _('Delete Reservation'));
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJconfirmDeleteRequestProduction($request)
///
/// \param $request - a request array as returend from getRequestInfo
///
/// \brief prints a page asking if the user is ready to make the image
/// production or just end this reservation
///
////////////////////////////////////////////////////////////////////////////////
function AJconfirmDeleteRequestProduction($request) {
	$cdata = array('requestid' => $request['id']);
	$text = '';
	$title = _("<big><strong>End Reservation/Make Production</strong></big><br><br>");
	$text .=	_("Are you satisfied that this environment is ready to be made production ");
	$text .= _("and replace the current production version, or would you just like to ");
	$text .= _("end this reservation and test it again later? ");

	if(isImageBlockTimeActive($request['reservations'][0]['imageid'])) {
		$text .= _("<br><font color=\"red\">\nWARNING: This environment is part of ");
		$text .= _("an active block allocation. Changing the production version of ");
		$text .= _("the environment at this time will result in new reservations ");
		$text .= _("under the block allocation to have full reload times instead of ");
		$text .= _("a &lt; 1 minutes wait. You can change the production version ");
		$text .= _("later by going to Manage Images-&gt;Edit Image Profiles and ");
		$text .= _("clicking Edit for this environment.</font><br>");
	}

	$cont = addContinuationsEntry('AJsetImageProduction', $cdata, SECINDAY, 0, 1);
	$radios = '';
	$radios .= "<br>&nbsp;&nbsp;&nbsp;<INPUT type=radio name=continuation ";
	$radios .= "value=\"$cont\" id=\"radioprod\"><label for=\"radioprod\">";
	$radios .= _("Make this the production version</label><br>");

	$cont = addContinuationsEntry('AJsubmitDeleteRequest', $cdata, SECINDAY, 0, 0);
	$radios .= "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=continuation ";
	$radios .= "value=\"$cont\" id=\"radioend\"><label for=\"radioend\">";
	$radios .= _("Just end the reservation</label><br><br>");
	$text = preg_replace("/(.{1,60}[ \n])/", '\1<br>', $text);
	$data = array('content' => $title . $text . $radios,
	              'cont' => $cont,
	              'btntxt' => _('Submit'));
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitDeleteRequest()
///
/// \brief submits deleting a request and prints that it has been deleted
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitDeleteRequest() {
	global $mode;
	$mode = 'AJviewRequests';
	$requestid = getContinuationVar('requestid', 0);
	$fromtimetable = getContinuationVar('fromtimetable', 0);
	$request = getRequestInfo($requestid);
	deleteRequest($request);
	if($fromtimetable) {
		$cdata = getContinuationVar('ttdata');
		$cont = addContinuationsEntry('showTimeTable', $cdata);
		print "window.location.href='" . BASEURL . SCRIPT . "?continuation=$cont';";
		return;
	}
	viewRequests();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJconfirmRemoveRequest()
///
/// \brief populates a confirmation dialog box
///
////////////////////////////////////////////////////////////////////////////////
function AJconfirmRemoveRequest() {
	$requestid = getContinuationVar('requestid', 0);
	$request = getRequestInfo($requestid, 1);
	if(is_null($request)) {
		$data = array('error' => 1,
		              'msg' => _("The specified reservation no longer exists."));
		sendJSON($data);
		return;
	}
	if($request['stateid'] != 11 && $request['laststateid'] != 11 &&
	   $request['stateid'] != 12 && $request['laststateid'] != 12 &&
	   $request['stateid'] !=  5 && $request['laststateid'] !=  5) {
		$data = array('error' => 2,
		              'msg' => _("The reservation is no longer failed or timed out."),
		              'url' => BASEURL . SCRIPT . "?mode=viewRequests");
		sendJSON($data);
		return;
	}
	if($request['stateid'] == 11 || $request['stateid'] == 12 ||
	   $request['stateid'] == 12 || $request['laststateid'] == 12) {
		$text  = _("Remove timed out reservation from list of current reservations?");
		$text .= "<br>\n";
	}
	else {
		$text  = _("Remove failed reservation from list of current reservations?");
		$text .= "<br>\n";
	}
	$cdata = array('requestid' => $requestid);
	$cont = addContinuationsEntry('AJsubmitRemoveRequest', $cdata, SECINDAY, 0, 0);
	$text = preg_replace("/(.{1,60}[ \n])/", '\1<br>', $text);
	$data = array('content' => $text,
	              'cont' => $cont);
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitRemoveRequest()
///
/// \brief submits deleting a request and prints that it has been deleted
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitRemoveRequest() {
	global $mode;
	$mode = 'AJviewRequests';
	$requestid = getContinuationVar('requestid', 0);
	$request = getRequestInfo($requestid, 1);
	if(is_null($requestid)) {
		viewRequests();
		return;
	}

	if($request['serverrequest']) {
		$query = "DELETE FROM serverrequest WHERE requestid = $requestid";
		doQuery($query, 152);
	}

	# TODO do these need to set state to complete?
	$query = "DELETE FROM request WHERE id = $requestid";
	doQuery($query, 153);

	$query = "DELETE FROM reservation WHERE requestid = $requestid";
	doQuery($query, 154);

	viewRequests();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJrebootRequest()
///
/// \brief sets a reservation to the reboot state and refreshes the Current
/// Reservations page
///
////////////////////////////////////////////////////////////////////////////////
function AJrebootRequest() {
	$requestid = getContinuationVar('requestid');
	$reqdata = getRequestInfo($requestid, 1);
	if(is_null($reqdata)) {
		print "resGone('reboot'); ";
		print "dijit.byId('editResDlg').show();";
		print "setTimeout(resRefresh, 1500);";
		return;
	}
	$reboottype = processInputVar('reboottype', ARG_NUMERIC);
	$newstateid = 26;
	if($reboottype == 1) {
		$newstateid = 28;
		addChangeLogEntryOther($reqdata['logid'], "event:reboothard");
	}
	else
		addChangeLogEntryOther($reqdata['logid'], "event:rebootsoft");
	$query = "UPDATE request SET stateid = $newstateid WHERE id = $requestid";
	doQuery($query, 101);
	print "resRefresh();";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJshowReinstallRequest()
///
/// \brief generates text for prompting user about reinstalling reservation
///
////////////////////////////////////////////////////////////////////////////////
function AJshowReinstallRequest() {
	global $user;
	$requestid = getContinuationVar('requestid');
	$reqdata = getRequestInfo($requestid, 1);
	if(is_null($reqdata)) {
		sendJSON(array('status' => 'resgone'));
		return;
	}
	$imageid = $reqdata['reservations'][0]['imageid'];
	$imgdata = getImages(0, $imageid);
	$t = '';
	$cdata = getContinuationVar();
	$cont = addContinuationsEntry('AJreinstallRequest', $cdata, 300, 1, 0);
	if(count($reqdata['reservations']) == 1 &&
		($imgdata[$imageid]['ownerid'] == $user['id'] ||
	   checkUserHasPerm('View Debug Information')) &&
	   count($imgdata[$imageid]['imagerevision']) > 1) {
		# prompt for which revision to use for reinstall
		$t .= _("This will cause the reserved machine to be reinstalled. ");
		$t .= _("You may select which version") . "<br>";
		$t .= _("of the environment you would like to use for the reinstall. The currently installed") . "<br>";
		$t .= _("version what is selected.") . "<br>";
		$t .= "<table summary=\"lists versions of the environment\">";
		$t .= "<TR>";
		$t .= "<TD></TD>";
		$t .= "<TH>" . _("Version") . "</TH>";
		$t .= "<TH>" . _("Creator") . "</TH>";
		$t .= "<TH>" . _("Created") . "</TH>";
		$t .= "<TH>" . _("Currently in Production") . "</TH>";
		$t .= "</TR>";
		foreach($imgdata[$imageid]['imagerevision'] as $revision) {
			$t .= "<TR>";
			// if revision was selected or it wasn't selected but it is the production revision, show checked
			if($reqdata['reservations'][0]['imagerevisionid'] == $revision['id'])
				$t .= "<TD align=center><INPUT type=radio name=revisionid value={$revision['id']} checked></TD>";
			else
				$t .= "<TD align=center><INPUT type=radio name=revisionid value={$revision['id']}></TD>";
			$t .= "<TD align=center>{$revision['revision']}</TD>";
			$t .= "<TD align=center>{$revision['user']}</TD>";
			$t .= "<TD align=center>{$revision['prettydate']}</TD>";
			if($revision['production'])
				$t .= "<TD align=center>" . _("Yes") . "</TD>";
			else
				$t .= "<TD align=center>" . _("No") . "</TD>";
			$t .= "</TR>";
		}
		$t .= "</table><br>";
		$t .= "<strong>" . _("NOTE") . "</strong>: ";
	}
	else
		$t .= _("This will cause the reserved machine to be reinstalled. ") . "<br>";
	$t .= _("Any data saved only to the reserved machine ") . "<strong>";
  	$t .= _("will be lost") . "</strong>.<br>";
	$t .= _("Are you sure you want to continue?") . "<br><br>";
	sendJSON(array('status' => 'success', 'txt' => $t, 'cont' => $cont));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJreinstallRequest()
///
/// \brief sets a reservation to the reinstall state and refreshes the Current
/// Reservations page
///
////////////////////////////////////////////////////////////////////////////////
function AJreinstallRequest() {
	$requestid = getContinuationVar('requestid');
	$reqdata = getRequestInfo($requestid, 1);
	if(is_null($reqdata)) {
		sendJSON(array('status' => 'resgone'));
		return;
	}
	$revisionid = processInputVar('revisionid', ARG_NUMERIC, 0);
	if($revisionid != 0) {
		$imageid = $reqdata['reservations'][0]['imageid'];
		$imgdata = getImages(0, $imageid);
		if(! array_key_exists($revisionid, $imgdata[$imageid]['imagerevision'])) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJreinstallRequest', $cdata, 300, 1, 0);
			sendJSON(array('status' => 'invalidrevisionid', 'cont' => $cont));
			return;
		}
		if($reqdata['reservations'][0]['imagerevisionid'] != $revisionid) {
			$query = "UPDATE reservation "
			       . "SET imagerevisionid = $revisionid "
			       . "WHERE id = {$reqdata['reservations'][0]['reservationid']}";
			doQuery($query, 101);
		}
		addChangeLogEntryOther($reqdata['logid'], "event:reinstall|revisionid:$revisionid");
	}
	else
		addChangeLogEntryOther($reqdata['logid'], "event:reinstall");
	$query = "UPDATE request SET stateid = 27 WHERE id = $requestid";
	doQuery($query, 101);
	sendJSON(array('status' => 'success'));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printReserveItems($modifystart, $imaging, $length, $maxlength, $day,
///                       $hour, $minute, $meridian, $oneline)
///
/// \param $modifystart - (optional) 1 to print form for modifying start time, 
/// 0 not to
/// \param $imaging - (optional) 1 if imaging reservation, 0 if not
/// \param $length - (optional) initial length (in minutes)
/// \param $maxlength - (optional) max initial length (in minutes)
/// \param $day - (optional) initial day of week (Sunday - Saturday)
/// \param $hour - (optional) initial hour (1-12)
/// \param $minute - (optional) initial minute (00-59)
/// \param $meridian - (optional) initial meridian (am/pm)
/// \param $oneline - (optional) print all items on one line
///
/// \brief prints reserve form data
///
////////////////////////////////////////////////////////////////////////////////
function printReserveItems($modifystart=1, $imaging=0, $length=60, $maxlength=0,
                           $day=NULL, $hour=NULL, $minute=NULL, $meridian=NULL,
                           $oneline=0) {
	global $user, $submitErr;
	if(! is_numeric($length))
		$length = 60;
	$ending = processInputVar("ending", ARG_STRING, "length");
	$enddate = processInputVar("enddate", ARG_STRING);
	$groupid = getUserGroupID('Specify End Time', 1);
	$members = getUserGroupMembers($groupid);
	if(array_key_exists($user['id'], $members))
		$openend = 1;
	else
		$openend = 0;
	$days = array();
	$inputday = "";
	for($cur = time(), $end = $cur + DAYSAHEAD * SECINDAY; 
	    $cur < $end; 
		 $cur += SECINDAY) {
		$tmp = getdate($cur);
		$index = $tmp["mon"] . "/" . $tmp["mday"] . "/" . $tmp["year"];
		$days[$index] = _($tmp["weekday"]);
		if($tmp["weekday"] == $day) {
			$inputday = $index;
		}
	}

	if($modifystart) {
		printSelectInput("day", $days, $inputday, 0, 0, 'reqday', "onChange='selectLater();'");
		print _("&nbsp;At&nbsp;\n");
		$tmpArr = array();
		for($i = 1; $i < 13; $i++) {
			$tmpArr[$i] = $i;
		}
		printSelectInput("hour", $tmpArr, $hour, 0, 0, 'reqhour', "onChange='selectLater();'");

		$minutes = array("zero" => "00",
							  "15" => "15",
							  "30" => "30", 
							  "45" => "45");
		printSelectInput("minute", $minutes, $minute, 0, 0, 'reqmin', "onChange='selectLater();'");
		printSelectInput("meridian", array("am" => "a.m.", "pm" => "p.m."), $meridian,
		                 0, 0, 'reqmeridian', "onChange='selectLater();'");
		print "<small>(" . date('T') . ")</small>";
		if($submitErr & STARTDAYERR)
			printSubmitErr(STARTDAYERR);
		elseif($submitErr & STARTHOURERR)
			printSubmitErr(STARTHOURERR);
		elseif($submitErr & STARTMINUTEERR)
			printSubmitErr(STARTMINUTEERR);
		print "<br><br>";
		if($openend) {
			if($ending != 'date')
				$checked = 'checked';
			else
				$checked = '';
			print "&nbsp;&nbsp;&nbsp;<INPUT type=\"radio\" name=\"ending\" ";
			print "onclick=\"updateWaitTime(0);\" value=\"length\" $checked ";
			print "id=\"durationradio\"><label for=\"durationradio\">";
		}
		print _("Duration") . ":&nbsp;\n";
		if($openend)
			print "</label>";
	}
	else {
		print "<INPUT type=hidden name=day value=$inputday>\n";
		print "<INPUT type=hidden name=hour value=$hour>\n";
		print "<INPUT type=hidden name=minute value=$minute>\n";
		print "<INPUT type=hidden name=meridian value=$meridian>\n";
	}
	// check for a "now" reservation that got 15 min added to it
	if($length % 30) {
		$length -= 15;
	}

	// if ! $modifystart, we return at this point because we don't
	# know enough about the current reservation to determine how
	# long they can extend it for, the calling function would have
	# to determine that and print a length dropdown box
	if(! $modifystart)
		return;

	# create an array of usage times based on the user's max times
	$maxtimes = getUserMaxTimes();
	if($maxlength > 0 && $maxlength < $maxtimes['initial'])
		$maxtimes['initial'] = $maxlength;
	if($imaging && $maxtimes['initial'] < 720) # make sure at least 12 hours available for imaging reservations
		$maxtimes['initial'] = 720;
	$lengths = getReservationLengths($maxtimes['initial']);

	printSelectInput("length", $lengths, $length, 0, 0, 'reqlength',
		"onChange='updateWaitTime(0); selectDuration();'");
	print "<br>\n";
	if($openend) {
		if($ending == 'date')
			$checked = 'checked';
		else
			$checked = '';
		print "&nbsp;&nbsp;&nbsp;<INPUT type=\"radio\" name=\"ending\" id=\"openend\" ";
		print "onclick=\"updateWaitTime(0);\" value=\"date\" $checked>";
		print _("<label for=\"openend\">Until</label>\n");

		if(preg_match('/^(20[0-9]{2}-[0-1][0-9]-[0-3][0-9]) ((([0-1][0-9])|(2[0-3])):([0-5][0-9]):([0-5][0-9]))$/', $enddate, $regs)) {
			$edate = $regs[1];
			$etime = $regs[2];
			$validendformat = 1;
		}
		else {
			$edate = '';
			$etime = '';
			$validendformat = 0;
		}
		print "<div type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
		print "id=\"openenddate\" onChange=\"setOpenEnd();\" ";
		print "style=\"width: 78px\" value=\"$edate\"></div>\n";
		print "<div type=\"text\" dojoType=\"dijit.form.TimeTextBox\" ";
		print "id=\"openendtime\" onChange=\"setOpenEnd();\" ";
		print "style=\"width: 78px\" value=\"T$etime\"></div>\n";
		print "<small>(" . date('T') . ")</small>\n";
		print "<noscript>";
		print _("(You must have javascript enabled to use the 'Until' option.)");
		print "<br></noscript>\n";
		printSubmitErr(ENDDATEERR);
		if($validendformat)
			print "<INPUT type=\"hidden\" name=\"enddate\" id=\"enddate\" value=\"$enddate\">\n";
		else
			print "<INPUT type=\"hidden\" name=\"enddate\" id=\"enddate\" value=\"\">\n";
		print "<br>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn connectRequest()
///
/// \brief sets IPaddress for the request; tells the user how to connect
///
////////////////////////////////////////////////////////////////////////////////
function connectRequest() {
	global $remoteIP, $user, $inContinuation;
	if($inContinuation)
		$requestid = getContinuationVar('requestid', 0);
	else
		$requestid = processInputVar("requestid", ARG_NUMERIC);
	$requestData = getRequestInfo($requestid);
	if($requestData['stateid'] == 11 || $requestData['stateid'] == 12 ||
	   ($requestData['stateid'] == 14 && 
	   ($requestData['laststateid'] == 11 || $requestData['laststateid'] == 12))) {
		print "<H2 align=center>" . _("Connect!") . "</H2>\n";
		print _("This reservation has timed out due to lack of user activity and ");
		print _("is no longer available.<br>\n");
		return;
	}
	$timeout = getReservationConnectTimeout($requestData['reservations'][0]['reservationid']);
	if(is_null($timeout))
		addConnectTimeout($requestData['reservations'][0]['reservationid'], 
		                  $requestData['reservations'][0]['computerid']);
	$now = time();
	if($requestData['reservations'][0]['remoteIP'] != $remoteIP) {
		$setback = unixToDatetime($now - 600);
		$query = "UPDATE reservation "
		       . "SET remoteIP = '$remoteIP', "
		       .     "lastcheck = '$setback' "
		       . "WHERE requestid = $requestid";
		$qh = doQuery($query, 226);

		addChangeLogEntry($requestData["logid"], $remoteIP);
	}

	if(! is_null($timeout))
		print "<input type=\"hidden\" id=\"timeoutvalue\" value=\"$timeout\">\n";

	print _("<H2 align=center>Connect!</H2>\n");
	if($requestData['forimaging']) {
		print _("<font color=red><big><strong>NOTICE:</strong> Later in this process, you must accept a ");
		print " <a href=\"" . BASEURL . SCRIPT . "?mode=imageClickThrough\">";
		print _("click-through agreement</a> about software licensing.</big></font><br><br>\n");
	}
	$imagenotes = getImageNotes($requestData['reservations'][0]['imageid']);
	if(! preg_match('/^\s*$/', $imagenotes['usage'])) {
		print _("<h3>Notes on using this environment:</h3>\n");
		print "{$imagenotes['usage']}<br><br><br>\n";
	}
	if(count($requestData["reservations"]) > 1)
		$cluster = 1;
	else
		$cluster = 0;
	if($cluster) {
		print _("<h2>Cluster Reservation</h2>\n");
		print _("This is a cluster reservation. Depending on the makeup of the ");
		print _("cluster, you may need to use different methods to connect to the ");
		print _("different environments in your cluster.<br><br>\n");
	}
	foreach($requestData["reservations"] as $key => $res) {
		$serverIP = $res["reservedIP"];
		$osname = $res["OS"];
		if(array_key_exists($user['id'], $requestData['passwds'][$res['reservationid']]))
			$passwd = $requestData['passwds'][$res['reservationid']][$user['id']];
		else
			$passwd = '';
		$connectData = getImageConnectMethodTexts($res['imageid'],
		                                          $res['imagerevisionid']);
		$first = 1;
		if($cluster) {
			print "<fieldset>\n";
			print "<legend><big><strong>{$res['prettyimage']}</strong></big></legend>\n";
		}
		foreach($connectData as $method) {
			if($first)
				$first = 0;
			else
				print "<hr>\n";
			if($requestData['forimaging'] && $res['OStype'] == 'windows')
				$conuser = 'Administrator';
			elseif(preg_match('/(.*)@(.*)/', $user['unityid'], $matches))
				$conuser = $matches[1];
			else
				$conuser = $user['unityid'];
			if(! strlen($passwd))
				$passwd = _('(use your campus password)');
			if($cluster)
				print "<h4>" . _("Connect to reservation using") . " {$method['description']}</h4>\n";
			else
				print "<h3>" . _("Connect to reservation using") . " {$method['description']}</h3>\n";
			$froms = array('/#userid#/',
			               '/#password#/',
			               '/#connectIP#/',
			               '/#connectport#/');
			if(empty($res['connectIP']))
				$res['connectIP'] = $serverIP; #TODO delete this when vcld is populating connectIP
			$tos = array($conuser,
			             $passwd,
			             $res['connectIP'], 
			             $res['connectport']);
			print preg_replace($froms, $tos, $method['connecttext']);
			if(preg_match('/remote desktop/i', $method['description'])) {
				print "<div id=\"counterdiv\" class=\"hidden\"></div>\n";
				print "<div id=\"connectdiv\">\n";
				print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cdata = array('requestid' => $requestid,
				               'resid' => $res['reservationid']);
				$expire = datetimeToUnix($requestData['end']) - $now + 1800; # remaining reservation time plus 30 min
				$cont = addContinuationsEntry('sendRDPfile', $cdata, $expire);
				print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
				print "<INPUT type=submit value=\"" . _("Get RDP File") . "\">\n";
				print "</FORM>\n";
				print "</div>\n";
			}
		}
		if($cluster)
			print "</fieldset><br>\n";
	}
	$cdata = array('requestid' => $requestid);
	$cont = addContinuationsEntry('AJcheckConnectTimeout', $cdata, SECINDAY);
	print "<input type=\"hidden\" id=\"refreshcont\" value=\"$cont\">\n";
	print "<div dojoType=dijit.Dialog\n";
	print "      id=\"timeoutdlg\"\n";
	print "      title=\"" . _("Reservation Timed Out") . "\"\n";
	print "      duration=250\n";
	print "      draggable=false>\n";
	print _("This reservation has timed out<br>and is no longer available.") . "<br><br>\n";
	print "   <div align=\"center\">\n";
	print "   <button dojoType=\"dijit.form.Button\">\n";
	print "     " . _("Okay") . "\n";
	print "	   <script type=\"dojo/method\" event=\"onClick\">\n";
	print "       dijit.byId('timeoutdlg').hide();\n";
	print "     </script>\n";
	print "   </button>\n";
	print "   </div>\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJcheckConnectTimeout()
///
/// \brief checks to see if a reservation has timed out
///
////////////////////////////////////////////////////////////////////////////////
function AJcheckConnectTimeout() {
	$requestid = getContinuationVar('requestid');
	$reqdata = getRequestInfo($requestid, 1);
	$stateid = $reqdata['stateid'];
	if($stateid == 14)
		$stateid == $reqdata['laststateid'];
	if(is_null($reqdata) ||
	   $stateid == 1 ||
	   $stateid == 11 ||
	   $stateid == 12 ||
	   $stateid == 16 ||
	   $stateid == 17) {
		$data['status'] = 'timeout';
		sendJSON($data);
		return;
	}
	$data['status'] = 'inuse';
	sendJSON($data);
	return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn connectRDPapplet()
///
/// \brief prints a page to launch the RDP java applet
///
////////////////////////////////////////////////////////////////////////////////
/*function connectRDPapplet() {
	global $user;
	$requestid = processInputVar("requestid", ARG_NUMERIC);
	$requestData = getRequestInfo($requestid);
	$server = processInputVar("reservedIP", ARG_STRING, $requestData["reservations"][0]["reservedIP"]);
	$password = "";
	foreach($requestData["reservations"] as $res) {
		if($res["reservedIP"] == $server) {
			$password = $res["password"];
			break;
		}
	}
	print "<div align=center>\n";
	print "<H2>Connect!</H2>\n";
	print "Launching applet.  You will have to grant it any permissions it requests.<br>\n";
	print "<APPLET CODE=\"net.propero.rdp.applet.RdpApplet.class\"\n";
	print "        ARCHIVE=\"properJavaRDP/properJavaRDP-1.1.jar,properJavaRDP/properJavaRDP14-1.1.jar,properJavaRDP/log4j-java1.1.jar,properJavaRDP/java-getopt-1.0.12.jar\" WIDTH=320 HEIGHT=240>\n";
	print "  <PARAM NAME=\"server\" VALUE=\"$server\">\n";
	print "  <PARAM NAME=\"port\" VALUE=\"3389\">\n";
	print "  <PARAM NAME=\"username\" VALUE=\"{$user["unityid"]}\">\n";
	print "  <PARAM NAME=\"password\" VALUE=\"$password\">\n";
	print "  <PARAM NAME=\"bpp\" VALUE=\"16\">\n";
	print "  <PARAM NAME=\"geometry\" VALUE=\"800x600\">\n";
	print "</APPLET>\n";
	print "</div>\n";
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn connectMindterm
///
/// \brief prints a page with an embedded mindterm client
///
////////////////////////////////////////////////////////////////////////////////
/*function connectMindterm() {
	global $user;
	$passwd = processInputVar("passwd", ARG_STRING);
	$serverIP = processInputVar("serverip", ARG_STRING);
	$requestid = processInputVar("requestid", ARG_NUMERIC);
	$requestData = getRequestInfo($requestid);
	$reserv = "";
	foreach($requestData["reservations"] as $key => $res) {
		if($res["reservedIP"] == $serverIP) {
			$reserv = $res;
			break;
		}
	}
	print "<H2 align=center>Connect!</H2>\n";
	print "<h3>{$reserv["prettyimage"]}</h3>\n";
	print "<UL>\n";
	print "<LI><b>Platform</b>: {$reserv["OS"]}</LI>\n";
	print "<LI><b>Remote Computer</b>: {$reserv["reservedIP"]}</LI>\n";
	print "<LI><b>User ID</b>: " . $user['unityid'] . "</LI>\n";
	if(strlen($reserv['password']))
		print "<LI><b>Password</b>: {$reserv['password']}<br></LI>\n";
	else
		print "<LI><b>Password</b>: (use your campus password)</LI>\n";
	print "</UL>\n";
	print "<APPLET CODE=\"com.mindbright.application.MindTerm.class\"\n";
	print "        ARCHIVE=\"mindterm-3.0/mindterm.jar\" WIDTH=0 HEIGHT=0>\n";
	print "  <PARAM NAME=\"server\" VALUE=\"$serverIP\">\n";
	print "  <PARAM NAME=\"port\" VALUE=\"22\">\n";
	print "  <PARAM NAME=\"username\" VALUE=\"{$user["unityid"]}\">\n";
	#print "  <PARAM NAME=\"password\" VALUE=\"$passwd\">\n";
	print "  <PARAM NAME=\"x11-forward\" VALUE=\"true\">\n";
	print "  <PARAM NAME=\"protocol\" VALUE=\"ssh2\">\n";
	print "  <PARAM NAME=\"sepframe\" VALUE=\"true\">\n";
	print "  <PARAM NAME=\"quiet\" VALUE=\"true\">\n";
	print "</APPLET>\n";
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processRequestInput($checks)
///
/// \param $checks - (optional) 1 to perform validation, 0 not to
///
/// \return an array with the following indexes (some may be empty):\n
/// requestid, day, hour, minute, meridian, length, started, os, imageid,
/// prettyimage, time, testjavascript, lengthchanged
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processRequestInput($checks=1) {
	global $submitErr, $submitErrMsg, $mode;
	$return = array();
	$return["requestid"] = processInputVar("requestid", ARG_NUMERIC);
	$return["day"] = preg_replace('[\s]', '', processInputVar("day", ARG_STRING));
	$return["hour"] = processInputVar("hour", ARG_NUMERIC);
	$return["minute"] = processInputVar("minute", ARG_STRING);
	$return["meridian"] = processInputVar("meridian", ARG_STRING);
	$return["endday"] = preg_replace('[\s]', '', processInputVar("endday", ARG_STRING));
	$return["endhour"] = processInputVar("endhour", ARG_NUMERIC);
	$return["endminute"] = processInputVar("endminute", ARG_STRING);
	$return["endmeridian"] = processInputVar("endmeridian", ARG_STRING);
	$return["length"] = processInputVar("length", ARG_NUMERIC);
	$return["started"] = getContinuationVar('started', processInputVar("started", ARG_NUMERIC));
	$return["os"] = processInputVar("os", ARG_STRING);
	$return["imageid"] = getContinuationVar('imageid', processInputVar("imageid", ARG_NUMERIC));
	$return["prettyimage"] = processInputVar("prettyimage", ARG_STRING);
	$return["time"] = processInputVar("time", ARG_STRING);
	$return["revisionid"] = processInputVar("revisionid", ARG_MULTINUMERIC);
	$return["ending"] = processInputVar("ending", ARG_STRING, "length");
	$return["enddate"] = processInputVar("enddate", ARG_STRING);
	$return["extend"] = processInputVar("extend", ARG_NUMERIC);
	$return["testjavascript"] = processInputVar("testjavascript", ARG_NUMERIC, 0);
	$return['imaging'] = getContinuationVar('imaging');
	$return['lengthchanged'] = 0;

	if($return["minute"] == 0) {
		$return["minute"] = "00";
	}
	if($return["endminute"] == 0) {
		$return["endminute"] = "00";
	}

	if(! $checks) {
		return $return;
	}

	$noimage = 0;
	if(empty($return['imageid'])) {
		$submitErr |= IMAGEIDERR;
		$submitErrMsg[IMAGEIDERR] = _("Please select a valid environment");
		$noimage = 1;
	}

	if(! $return["started"]) {
		$checkdateArr = explode('/', $return["day"]);
		if(! is_numeric($checkdateArr[0]) ||
		   ! is_numeric($checkdateArr[1]) ||
		   ! is_numeric($checkdateArr[2]) ||
		   ! checkdate($checkdateArr[0], $checkdateArr[1], $checkdateArr[2])) {
			$submitErr |= STARTDAYERR;
			$submitErrMsg[STARTDAYERR] = _("The submitted start date is invalid. ");
		}
		if(! preg_match('/^((0?[1-9])|(1[0-2]))$/', $return["hour"], $regs)) {
			$submitErr |= STARTHOURERR;
			$submitErrMsg[STARTHOURERR] = _("The submitted hour must be from 1 to 12.");
		}
		if(! preg_match('/^([0-5][0-9])$/', $return["minute"], $regs)) {
			$submitErr |= STARTMINUTEERR;
			$submitErrMsg[STARTMINUTEERR] = _("The submitted minute must be from 00 to 59.");
		}
		if(! preg_match('/^(am|pm)$/', $return["meridian"], $regs))
			$return['meridian'] = 'am';
		$checkstart = sprintf('%04d-%02d-%02d ', $checkdateArr[2], $checkdateArr[0],
		              $checkdateArr[1]);
		if($return['meridian'] == 'am') {
			if($return['hour'] == '12')
				$checkstart .= "00:{$return['minute']}:00";
			else
				$checkstart .= "{$return['hour']}:{$return['minute']}:00";
		}
		else {
			if($return['hour'] == '12')
				$checkstart .= "12:{$return['minute']}:00";
			else
				$checkstart .= ($return['hour'] + 12) . ":{$return['minute']}:00";
		}
	}

	# TODO check for valid revisionids for each image
	if(! empty($return["revisionid"])) {
		foreach($return['revisionid'] as $key => $val) {
			if(! is_numeric($val) || $val < 0)
				unset($return['revisionid']);
		}
	}

	// make sure user hasn't submitted something longer than their allowed max length
	$maxtimes = getUserMaxTimes();
	if($return['imaging']) {
		if($maxtimes['initial'] < 720) # make sure at least 12 hours available for imaging reservations
			$maxtimes['initial'] = 720;
	}
	if($maxtimes['initial'] < $return['length']) {
		$return['lengthchanged'] = 1;
		$return['length'] = $maxtimes['initial'];
	}
	if(! $noimage) {
		$imageData = getImages(0, $return['imageid']);
		if($imageData[$return['imageid']]['maxinitialtime'] > 0 &&
			$imageData[$return['imageid']]['maxinitialtime'] < $return['length']) {
			$return['lengthchanged'] = 1;
			$return['length'] = $imageData[$return['imageid']]['maxinitialtime'];
		}
	}

	if($return["ending"] != "length") {
		if(! preg_match('/^(20[0-9]{2})-([0-1][0-9])-([0-3][0-9]) (([0-1][0-9])|(2[0-3])):([0-5][0-9]):([0-5][0-9])$/', $return["enddate"], $regs)) {
			$submitErr |= ENDDATEERR;
			$submitErrMsg[ENDDATEERR] = _("The submitted date/time is invalid.");
		}
		elseif(! checkdate($regs[2], $regs[3], $regs[1])) {
			$submitErr |= ENDDATEERR;
			$submitErrMsg[ENDDATEERR] = _("The submitted date/time is invalid.");
		}
		elseif(! $return["started"] && datetimeToUnix($checkstart) >= datetimeToUnix($return['enddate'])) {
			$submitErr |= ENDDATEERR;
			$submitErrMsg[ENDDATEERR] = _("The end time must be later than the start time.");
		}
	}

	if($return["testjavascript"] != 0 && $return['testjavascript'] != 1)
		$return["testjavascript"] = 0;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getReservationNextTimeout($resid)
///
/// \param $resid - reservation id
///
/// \return unix timestamp
///
/// \brief determines the time at which the specified reservation will time out
/// if not acknowledged or NULL if there is no entry
///
////////////////////////////////////////////////////////////////////////////////
function getReservationNextTimeout($resid) {
	$query = "SELECT UNIX_TIMESTAMP(cll.timestamp) AS timestamp, "
	       .        "cll.loadstateid, "
	       .        "v1.value AS acknowledgetimeout, "
	       .        "v2.value AS connecttimeout "
	       . "FROM computerloadlog cll, "
	       .      "variable v1, "
	       .      "variable v2 "
	       . "WHERE cll.reservationid = $resid AND "
	       .       "(cll.loadstateid = 18 OR "
	       .       "cll.loadstateid = 55) AND "
	       .       "v1.name = 'acknowledgetimeout' AND "
	       .       "v2.name = 'connecttimeout' "
	       . "ORDER BY cll.timestamp DESC "
	       . "LIMIT 1";
	$qh = doQuery($query);
	if($row = mysql_fetch_assoc($qh)) {
		if(! is_numeric($row['timestamp']))
			return NULL;
		if($row['loadstateid'] == 18)
			return $row['timestamp'] + $row['acknowledgetimeout'] + 15;
		elseif($row['loadstateid'] == 55)
			return $row['timestamp'] + $row['connecttimeout'] + 15;
		else
			return NULL;
	}
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getReservationConnectTimeout($resid)
///
/// \param $resid - reservation id
///
/// \return unix timestamp
///
/// \brief determines the time at which the specified reservation will time out
/// if not connected or NULL if there is no entry
///
////////////////////////////////////////////////////////////////////////////////
function getReservationConnectTimeout($resid) {
	$query = "SELECT UNIX_TIMESTAMP(cll.timestamp) AS timestamp, "
	       .        "v.value AS connecttimeout "
	       . "FROM computerloadlog cll, "
	       .      "variable v "
	       . "WHERE cll.reservationid = $resid AND "
	       .       "cll.loadstateid = 55 AND "
	       .       "v.name = 'connecttimeout'";
	$qh = doQuery($query);
	if($row = mysql_fetch_assoc($qh)) {
		if(! is_numeric($row['timestamp']))
			return NULL;
		return $row['timestamp'] + $row['connecttimeout'] + 15;
	}
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addConnectTimeout($resid, $compid)
///
/// \param $resid - reservation id
/// \param $compid - computer id
///
/// \brief inserts a connecttimeout entry in computerloadlog for $resid/$compid
///
////////////////////////////////////////////////////////////////////////////////
function addConnectTimeout($resid, $compid) {
	$query = "INSERT INTO computerloadlog "
	       .        "(reservationid, "
	       .        "computerid, "
	       .        "loadstateid, "
	       .        "timestamp) "
	       . "VALUES "
	       .        "($resid, "
	       .        "$compid, "
	       .        "55, "
	       .        "NOW())";
	doQuery($query);
}
?>
