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
	global $submitErr, $user, $mode;
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
			print "<H2>New Reservation</H2><br>\n";
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
		print "You don't have access to any environments and, therefore, cannot ";
		print "make any reservations.<br>\n";
		return;
	}
	if($imaging) {
		print "Please select the environment you will be updating or using as a ";
		print "base for a new image:<br>\n";
	}
	else
		print "Please select the environment you want to use from the list:<br>\n";

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
			foreach($resources['image'] as $id => $image)
				if($id == $imageid)
					print "        <option value=\"$id\" selected>$image</option>\n";
				else
					print "        <option value=\"$id\">$image</option>\n";
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
			foreach($resources['image'] as $id => $image)
				if($id == $imageid)
					print "        <option value=\"$id\" selected>$image</option>\n";
				else
					print "        <option value=\"$id\">$image</option>\n";
			print "      </select>\n";
		}
		else
			printSelectInput('imageid', $resources['image'], $imageid, 1, 0, 'imagesel', "onChange=\"selectEnvironment();\"");
	}
	print "<br><br>\n";

	$imagenotes = getImageNotes($imageid);
	$desc = '';
	if(preg_match('/\w/', $imagenotes['description'])) {
		$desc = preg_replace("/\n/", '<br>', $imagenotes['description']);
		$desc = preg_replace("/\r/", '', $desc);
		$desc = "<strong>Image Description</strong>:<br>\n$desc<br><br>\n";
	}
	print "<div id=imgdesc>$desc</div>\n";

	print "<fieldset id=whenuse class=whenusefieldset>\n";
	if($imaging)
		print "<legend>When would you like to start the imaging process?</legend>\n";
	else
		print "<legend>When would you like to use the application?</legend>\n";
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time id=timenow ";
	print "onclick='updateWaitTime(0);' value=now checked>Now<br>\n";
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time value=future ";
	print "onclick='updateWaitTime(0);'>Later:\n";
	$maxlen = $images[$imageid]['maxinitialtime'];
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
		print "<INPUT id=newsubmit type=submit value=\"Create Reservation\" ";
	print "onClick=\"return checkValidImage();\">\n";
	print "<INPUT type=hidden id=testjavascript value=0>\n";
	print "</FORM>\n";
	$cont = addContinuationsEntry('AJupdateWaitTime', array('imaging' => $imaging));
	print "<INPUT type=hidden name=waitcontinuation id=waitcontinuation value=\"$cont\">\n";
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
	if(preg_match('/\w/', $imagenotes['description'])) {
		$desc = preg_replace("/\n/", '<br>', $imagenotes['description']);
		$desc = preg_replace("/\r/", '', $desc);
		$desc = preg_replace("/'/", '&#39;', $desc);
		print "dojo.byId('imgdesc').innerHTML = '<strong>Image Description</strong>:<br>";
		print "$desc<br><br>'; ";
	}

	if($desconly) {
		if($imaging)
			print "if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'Create Imaging Reservation';";
		else
			print "if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'Create Reservation';";
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
	print "dojo.byId('waittime').innerHTML = ";
	if($rc == -2) {
		print "'<font color=red>Selection not currently available due to scheduled system downtime for maintenance</font>'; ";
		print "if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'View Time Table';";
	}
	if($rc < 1) {
		print "'<font color=red>Selection not currently available</font>'; ";
		print "if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'View Time Table';";
	}
	elseif(array_key_exists(0, $requestInfo['loaded']) &&
		   $requestInfo['loaded'][0]) {
			print "'Estimated load time: &lt; 1 minute';";
	}
	else {
		$loadtime = (int)(getImageLoadEstimate($imageid) / 60);
		if($loadtime == 0)
			print "'Estimated load time: &lt; {$images[$imageid]['reloadtime']} minutes';";
		else
			printf("'Estimated load time: &lt; %2.0f minutes';", $loadtime + 1);
	}
	if($rc > 0) {
		if($imaging)
			print "if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'Create Imaging Reservation';";
		else
			print "if(dojo.byId('newsubmit')) dojo.byId('newsubmit').value = 'Create Reservation';";
	}
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
	global $submitErr, $user, $viewmode, $HTMLheader, $mode, $printedHTMLheader;

	if($mode == 'submitTestProd') {
		$data = getContinuationVar();
		$data["revisionid"] = processInputVar("revisionid", ARG_MULTINUMERIC);
		# TODO check for valid revisionids for each image
		if(! empty($data["revisionid"])) {
			foreach($data['revisionid'] as $key => $val) {
				if(! is_numeric($val) || $val < 0)
					unset($data['revisionid']);
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
			print "<H2>New Reservation</H2>\n";
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
				print "<H2>New Reservation</H2>\n";
			print "<font color=\"#ff0000\">The time you requested is in the past.";
			print " Please select \"Now\" or use a time in the future.</font><br>\n";
			$submitErr = 1;
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
		array_key_exists($data['imageid'], $data['revisionid']))
		$revisionid = $data['revisionid'][$data['imageid']];
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
			print "<H2>New Reservation</H2>\n";
		if($max == 0) {
			print "<font color=\"#ff0000\">The time you requested overlaps with ";
			print "another reservation you currently have.  You are only allowed ";
			print "to have a single reservation at any given time. Please select ";
			print "another time to use the application. If you are finished with ";
			print "an active reservation, click \"Current Reservations\", ";
			print "then click the \"End\" button of your active reservation.";
			print "</font><br><br>\n";
		}
		else {
			print "<font color=\"#ff0000\">The time you requested overlaps with ";
			print "another reservation you currently have.  You are allowed ";
			print "to have $max overlapping reservations at any given time. ";
			print "Please select another time to use the application. If you are ";
			print "finished with an active reservation, click \"Current ";
			print "Reservations\", then click the \"End\" button of your active ";
			print "reservation.</font><br><br>\n";
		}
		$submitErr = 1;
		newReservation();
		print getFooter();
		return;
	}
	// if user is owner of the image and there is a test version of the image
	#   available, ask user if production or test image desired
	if($mode != "submitTestProd" && $showrevisions &&
	   $images[$data["imageid"]]["ownerid"] == $user["id"]) {
		#unset($data["testprod"]);
		$printedHTMLheader = 1;
		print $HTMLheader;
		if($imaging)
			print "<H2>Create / Update an Image</H2>\n";
		else
			print "<H2>New Reservation</H2>\n";
		if($subimages) {
			print "This is a cluster environment. At least one image in the ";
			print "cluster has more than one version available. Please select ";
			print "the version you desire for each image listed below:<br>\n";
		}
		else {
			print "There are multiple versions of this environment available.  Please ";
			print "select the version you would like to check out:<br>\n";
		}
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post><br>\n";
		if(! array_key_exists('subimages', $images[$data['imageid']]))
			$images[$data['imageid']]['subimages'] = array();
		array_unshift($images[$data['imageid']]['subimages'], $data['imageid']);
		foreach($images[$data['imageid']]['subimages'] as $subimage) {
			print "{$images[$subimage]['prettyname']}:<br>\n";
			print "<table summary=\"lists versions of the selected environment, one must be selected to continue\">\n";
			print "  <TR>\n";
			print "    <TD></TD>\n";
			print "    <TH>Version</TH>\n";
			print "    <TH>Creator</TH>\n";
			print "    <TH>Created</TH>\n";
			print "    <TH>Currently in Production</TH>\n";
			print "  </TR>\n";
			foreach($images[$subimage]['imagerevision'] as $revision) {
				print "  <TR>\n";
				if(array_key_exists($subimage, $data['revisionid']) && 
				   $data['revisionid'][$subimage] == $revision['id'])
					print "    <TD align=center><INPUT type=radio name=revisionid[$subimage] value={$revision['id']} checked></TD>\n";
				elseif($revision['production'])
					print "    <TD align=center><INPUT type=radio name=revisionid[$subimage] value={$revision['id']} checked></TD>\n";
				else
					print "    <TD align=center><INPUT type=radio name=revisionid[$subimage] value={$revision['id']}></TD>\n";
				print "    <TD align=center>{$revision['revision']}</TD>\n";
				print "    <TD align=center>{$revision['user']}</TD>\n";
				print "    <TD align=center>{$revision['prettydate']}</TD>\n";
				if($revision['production'])
					print "    <TD align=center>Yes</TD>\n";
				else
					print "    <TD align=center>No</TD>\n";
				print "  </TR>\n";
			}
			print "</table>\n";
		}
		$cont = addContinuationsEntry('submitTestProd', $data);
		print "<br><INPUT type=hidden name=continuation value=\"$cont\">\n";
		if($imaging)
			print "<INPUT type=submit value=\"Create Imaging Reservation\">\n";
		else
			print "<INPUT type=submit value=\"Create Reservation\">\n";
		print "</FORM>\n";
		print getFooter();
		return;
	}
	if($availablerc == -1) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		if($imaging)
			print "<H2>Create / Update an Image</H2>\n";
		else
			print "<H2>New Reservation</H2>\n";
		print "You have requested an environment that is limited in the number ";
		print "of concurrent reservations that can be made. No further ";
		print "reservations for the environment can be made for the time you ";
		print "have selected. Please select another time to use the ";
		print "environment.<br>";
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
				print "<H2>Create / Update an Image</H2>\n";
			else
				print "<H2>New Reservation</H2>\n";
			if($data["ending"] == "length") {
				$time = prettyLength($data["length"]);
				if($data['testjavascript'] == 0 && $data['lengthchanged']) {
					print "<font color=red>NOTE: The maximum allowed reservation ";
					print "length for this environment is $time, and the length of ";
					print "this reservation has been adjusted accordingly.</font>\n";
					print "<br><br>\n";
				}
				print "Your request to use <b>" . $images[$data["imageid"]]["prettyname"];
				print "</b> on " . prettyDatetime($start) . " for $time has been ";
				print "accepted.<br><br>\n";
			}
			else {
				print "Your request to use <b>" . $images[$data["imageid"]]["prettyname"];
				print "</b> starting " . prettyDatetime($start) . " and ending ";
				print prettyDatetime($end) . " has been accepted.<br><br>\n";
			}
			print "When your reservation time has been reached, the <strong>";
			print "Current Reservations</strong> page will have further ";
			print "instructions on connecting to the reserved computer.  If you ";
			print "would like to modify your reservation, you can do that from ";
			print "the <b>Current Reservations</b> page as well.<br>\n";
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
		/*print "<H2>New Reservation</H2>\n";
		print "The reservation you have requested is not available. You may ";
		print "<a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "view a timetable</a> of free and reserved times to find ";
		print "a time that will work for you.<br>\n";*/
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
	global $user, $viewmode, $inContinuation, $mode;
	if($inContinuation)
		$lengthchanged = getContinuationVar('lengthchanged', 0);
	else
		$lengthchanged = processInputVar('lengthchanged', ARG_NUMERIC, 0);
	$incPaneDetails = processInputVar('incdetails', ARG_NUMERIC, 0);
	$refreqid = processInputVar('reqid', ARG_NUMERIC, 0);
	$requests = getUserRequests("all");
	$images = getImages();
	$computers = getComputers();

	if($mode != 'AJviewRequests')
		print "<div id=subcontent>\n";

	$refresh = 0;
	$failed = 0;
	$connect = 0;

	$normal = '';
	$imaging = '';
	$long = '';
	if($viewmode == ADMIN_DEVELOPER)
		$nodes = getManagementNodes();
	if($count = count($requests)) {
		$now = time();
		for($i = 0, $noedit = 0, $text = '';
		   $i < $count;
		   $i++, $noedit = 0, $text = '') {
			if($requests[$i]['forcheckout'] == 0 &&
			   $requests[$i]['forimaging'] == 0)
				continue;
			$imageid = $requests[$i]["imageid"];
			$text .= "  <TR valign=top id=reqrow{$requests[$i]['id']}>\n";
			if(requestIsReady($requests[$i])) {
				$connect = 1;
				# request is ready, print Connect! and End buttons
				$cdata = array('requestid' => $requests[$i]['id']);
				$text .= "    <TD>\n";
				$text .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cont = addContinuationsEntry('connectRequest', $cdata, SECINDAY);
				$text .= "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
				$text .= "      <INPUT type=submit value=\"Connect!\">\n";
				$text .= "      </FORM>\n";
				$text .= "    </TD>\n";
				if($requests[$i]['forimaging']) {
					# this is the imaging case, need to do sanity check here for if the request
					#   state currstateid or laststateid are "inuse", otherwise disable out the
					#   create image button					
					$noedit = 1;
					$text .= "    <TD>\n";
					if($requests[$i]['currstateid'] == 8 || $requests[$i]['laststateid'] == 8) {
						# the user has connected successfully so we will allow create image button
						#   to be displayed
						$text .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
						$cont = addContinuationsEntry('startImage', $cdata);
						$text .= "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
						$text .= "      <INPUT type=submit value=\"Create\nImage\">\n";
						$text .= "      </FORM>\n";
					}
					$text .= "    </TD>\n";
					$text .= "    <TD>\n";
					$text .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
					$cdata = array('requestid' => $requests[$i]['id']);
					$cont = addContinuationsEntry('confirmDeleteRequest', $cdata, SECINDAY);
					$text .= "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
					$text .= "      <INPUT type=submit value=Cancel>\n";
					$text .= "      </FORM>\n";
					$text .= "    </TD>\n";
				}
				else {
					$text .= "    <TD>\n";
					$text .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
					$cont = addContinuationsEntry('confirmDeleteRequest', $cdata, SECINDAY);
					$text .= "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
					$text .= "      <INPUT type=submit value=End>\n";
					$text .= "      </FORM>\n";
					$text .= "    </TD>\n";
				}
				$startstamp = datetimeToUnix($requests[$i]["start"]);
			}
			elseif($requests[$i]["currstateid"] == 5) {
				# request has failed
				$cdata = array('requestid' => $requests[$i]['id']);
				$text .= "    <TD colspan=2 nowrap>\n";
				$text .= "      <span class=scriptonly>\n";
				$text .= "      <span class=compstatelink>";
				$text .= "<a onClick=\"showResStatusPane({$requests[$i]['id']}); ";
				$text .= "return false;\" href=\"#\">Reservation failed</a></span>\n";
				$text .= "      </span>\n";
				$text .= "      <noscript>\n";
				$text .= "      <span class=scriptoff>\n";
				$text .= "      <span class=compstatelink>";
				$text .= "Reservation failed</span>\n";
				$text .= "      </span>\n";
				$text .= "      </noscript>\n";
				$text .= "    </TD>\n";
				$failed = 1;
				$noedit = 1;
			}
			elseif(datetimeToUnix($requests[$i]["start"]) < $now) {
				# other cases where the reservation start time has been reached
				if(($requests[$i]["currstateid"] == 12 &&
				   $requests[$i]['laststateid'] == 11) ||
					$requests[$i]["currstateid"] == 11 ||
					($requests[$i]["currstateid"] == 14 &&
					$requests[$i]["laststateid"] == 11)) {
					# request has timed out
					if($requests[$i]['forimaging'])
						$text .= "    <TD colspan=3>\n";
					else
						$text .= "    <TD colspan=2>\n";
					$text .= "      <span class=compstatelink>Reservation has ";
					$text .= "timed out</span>\n";
					$noedit = 1;
					$text .= "    </TD>\n";
				}
				else {
					# computer is loading, print Pending... and Delete button
					$remaining = 1;
					if($requests[$i]['forimaging'])
						$noedit = 1;
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
					# computer is loading, print Pending... and Delete button
					if($requests[$i]['forimaging'])
						$text .= "    <TD colspan=2>\n";
					else
						$text .= "    <TD>\n";
					$text .= "      <span class=scriptonly>\n";
					$text .= "      <span class=compstatelink><i>";
					$text .= "<a onClick=\"showResStatusPane({$requests[$i]['id']}); ";
					$text .= "return false;\" href=\"#\">Pending...</a></i></span>\n";
					$text .= "      </span>\n";
					$text .= "      <noscript>\n";
					$text .= "      <span class=scriptoff>\n";
					$text .= "      <span class=compstatelink>";
					$text .= "<i>Pending...</i></span>\n";
					$text .= "      </span>\n";
					$text .= "      </noscript>\n";
					$text .= "<br>Est:&nbsp;$remaining&nbsp;min remaining\n";
					$refresh = 1;
					$text .= "    </TD>\n";
					$text .= "    <TD>\n";
					$text .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
					$cdata = array('requestid' => $requests[$i]['id']);
					$cont = addContinuationsEntry('confirmDeleteRequest', $cdata, SECINDAY);
					$text .= "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
					$text .= "      <INPUT type=submit value=Delete>\n";
					$text .= "      </FORM>\n";
					$text .= "    </TD>\n";
				}
			}
			else {
				# reservation is in the future
				$text .= "    <TD></TD>\n";
				$text .= "    <TD>\n";
				$text .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cdata = array('requestid' => $requests[$i]['id']);
				$cont = addContinuationsEntry('confirmDeleteRequest', $cdata, SECINDAY);
				$text .= "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
				$text .= "      <INPUT type=submit value=Delete>\n";
				$text .= "      </FORM>\n";
				$text .= "    </TD>\n";
			}
			if(! $noedit) {
				# print edit button
				$text .= "    <TD align=right>\n";
				$text .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cdata = array('requestid' => $requests[$i]['id']);
				$cont = addContinuationsEntry('editRequest', $cdata);
				$text .= "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
				$text .= "      <INPUT type=submit value=Edit>\n";
				$text .= "      </FORM>\n";
				$text .= "    </TD>\n";
			}
			elseif($requests[$i]['forimaging'] == 0)
				$text .= "    <TD></TD>\n";

			# print name of image, add (Testing) if it is the test version of an image
			$text .= "    <TD>" . str_replace("'", "&#39;", $requests[$i]["prettyimage"]);
			if($requests[$i]["test"])
				$text .= " (Testing)";
			$text .= "</TD>\n";

			# print start time
			if(datetimeToUnix($requests[$i]["start"]) < 
			   datetimeToUnix($requests[$i]["daterequested"])) {
				$text .= "    <TD>" . prettyDatetime($requests[$i]["daterequested"]) . "</TD>\n";
			}
			else {
				$text .= "    <TD>" . prettyDatetime($requests[$i]["start"]) . "</TD>\n";
			}

			# print end time
			$text .= "    <TD>" . prettyDatetime($requests[$i]["end"]) . "</TD>\n";

			# print date requested
			$text .= "    <TD>" . prettyDatetime($requests[$i]["daterequested"]) . "</TD>\n";

			if($viewmode == ADMIN_DEVELOPER) {
				$text .= "    <TD align=center>" . $requests[$i]["id"] . "</TD>\n";
				$text .= "    <TD align=center>" . $requests[$i]["computerid"] . "</TD>\n";
				$text .= "    <TD align=center>" . $nodes[$requests[$i]["managementnodeid"]]['hostname'] . "</TD>\n";
				$text .= "    <TD>" . $requests[$i]["IPaddress"] . "</TD>\n";
				$text .= "    <TD align=center>" . $requests[$i]["currstateid"];
				$text .= "</TD>\n";
				$text .= "    <TD align=center>" . $requests[$i]["laststateid"];
				$text .= "</TD>\n";
				$text .= "    <TD align=center>";
				$text .= $computers[$requests[$i]["computerid"]]["stateid"] . "</TD>\n";
			}
			$text .= "  </TR>\n";
			if($requests[$i]['forimaging'])
				$imaging .= $text;
			elseif($requests[$i]['longterm'])
				$long .= $text;
			else
				$normal .= $text;
		}
	}

	$text = "<H2>Current Reservations</H2>\n";
	if(! empty($normal)) {
		if(! empty($imaging) || ! empty($long))
			$text .= "You currently have the following <strong>normal</strong> reservations:<br>\n";
		else
			$text .= "You currently have the following normal reservations:<br>\n";
		if($lengthchanged) {
			$text .= "<font color=red>NOTE: The maximum allowed reservation ";
			$text .= "length for one of these reservations was less than the ";
			$text .= "length you submitted, and the length of that reservation ";
			$text .= "has been adjusted accordingly.</font>\n";
		}
		$text .= "<table id=reslisttable summary=\"lists reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= "    <TH>Environment</TH>\n";
		$text .= "    <TH>Starting</TH>\n";
		$text .= "    <TH>Ending</TH>\n";
		$text .= "    <TH>Initially requested</TH>\n";
		if($viewmode == ADMIN_DEVELOPER) {
			$text .= "    <TH>Req ID</TH>\n";
			$text .= "    <TH>Comp ID</TH>\n";
			$text .= "    <TH>Management Node</TH>\n";
			$text .= "    <TH>IP address</TH>\n";
			$text .= "    <TH>Current State</TH>\n";
			$text .= "    <TH>Last State</TH>\n";
			$text .= "    <TH>Computer State</TH>\n";
		}
		$text .= "  </TR>\n";
		$text .= $normal;
		$text .= "</table>\n";
	}
	if(! empty($imaging)) {
		if(! empty($normal))
			$text .= "<hr>\n";
		$text .= "You currently have the following <strong>imaging</strong> reservations:<br>\n";
		$text .= "<table id=imgreslisttable summary=\"lists imaging reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= "    <TH>Environment</TH>\n";
		$text .= "    <TH>Starting</TH>\n";
		$text .= "    <TH>Ending</TH>\n";
		$text .= "    <TH>Initially requested</TH>\n";
		$computers = getComputers();
		if($viewmode == ADMIN_DEVELOPER) {
			$text .= "    <TH>Req ID</TH>\n";
			$text .= "    <TH>Comp ID</TH>\n";
			$text .= "    <TH>Management Node</TH>\n";
			$text .= "    <TH>IP address</TH>\n";
			$text .= "    <TH>Current State</TH>\n";
			$text .= "    <TH>Last State</TH>\n";
			$text .= "    <TH>Computer State</TH>\n";
		}
		$text .= "  </TR>\n";
		$text .= $imaging;
		$text .= "</table>\n";
	}
	if(! empty($long)) {
		if(! empty($normal) || ! empty($imaging))
			$text .= "<hr>\n";
		$text .= "You currently have the following <strong>long term</strong> reservations:<br>\n";
		$text .= "<table id=\"longreslisttable\" summary=\"lists long term reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= "    <TH>Environment</TH>\n";
		$text .= "    <TH>Starting</TH>\n";
		$text .= "    <TH>Ending</TH>\n";
		$text .= "    <TH>Initially requested</TH>\n";
		$computers = getComputers();
		if($viewmode == ADMIN_DEVELOPER) {
			$text .= "    <TH>Req ID</TH>\n";
			$text .= "    <TH>Comp ID</TH>\n";
			$text .= "    <TH>Management Node</TH>\n";
			$text .= "    <TH>IP address</TH>\n";
			$text .= "    <TH>Current State</TH>\n";
			$text .= "    <TH>Last State</TH>\n";
			$text .= "    <TH>Computer State</TH>\n";
		}
		$text .= "  </TR>\n";
		$text .= $long;
		$text .= "</table>\n";
	}

	# connect div
	if($connect) {
		$text .= "<br><br>Click the <strong>";
		$text .= "Connect!</strong> button to get further ";
		$text .= "information about connecting to the reserved system. You must ";
		$text .= "click the button from a web browser running on the same computer ";
		$text .= "from which you will be connecting to the remote computer; ";
		$text .= "otherwise, you may be denied access to the machine.\n";
	}

	if($refresh) {
		$text .= "<br><br>This page will automatically update ";
		$text .= "every 20 seconds until the <font color=red><i>Pending...</i>";
		#$text .= "</font> reservation is ready.<br></div>\n";
		$text .= "</font> reservation is ready.\n";
		$cont = addContinuationsEntry('AJviewRequests', $cdata, SECINDAY);
		$text .= "<INPUT type=hidden id=resRefreshCont value=\"$cont\">\n";
	}

	if($failed) {
		$text .= "<br><br>An error has occurred that has kept one of your reservations ";
		$text .= "from being processed. We apologize for any inconvenience ";
		$text .= "this may have caused.\n";
		if(! $refresh) {
			$cont = addContinuationsEntry('AJviewRequests', $cdata, SECINDAY);
			$text .= "<INPUT type=hidden id=resRefreshCont value=\"$cont\">\n";
		}
	}

	if(empty($normal) && empty($imaging) && empty($long))
		$text .= "You have no current reservations.<br>\n";

	$text .= "</div>\n";
	if($mode != 'AJviewRequests') {
		if($refresh || $failed) {
			$text .= "<div dojoType=dojox.layout.FloatingPane\n";
			$text .= "      id=resStatusPane\n";
			$text .= "      resizable=true\n";
			$text .= "      closable=false\n";
			$text .= "      title=\"Detailed Reservation Status\"\n";
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
			$text .= "<div id=resStatusText></div>\n";
			$text .= "<input type=hidden id=detailreqid value=0>\n";
			$text .= "</div>\n";
		}
		print $text;
	}
	else {
		$text = str_replace("\n", ' ', $text);
		if($refresh)
			print "refresh_timer = setTimeout(resRefresh, 20000);\n";
		print(setAttribute('subcontent', 'innerHTML', $text));
		print "AJdojoCreate('subcontent');";
		if($incPaneDetails) {
			$text = detailStatusHTML($refreqid);
			print(setAttribute('resStatusText', 'innerHTML', $text));
		}
		dbDisconnect();
		exit;
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
		$text  = "The selected reservation is no longer available.  Go to ";
		$text .= "<a href=" . BASEURL . SCRIPT . "?mode=newRequest>New ";
		$text .= "Reservations</a> to request a new reservation or ";
		$text .= "select another one that is available.";
		return $text;
	}
	if($request['imageid'] == $request['compimageid'])
		$nowreq = 1;
	else
		$nowreq = 0;
	$flow = getCompStateFlow($request['computerid']);

	# cluster reservations not supported here yet
	if(empty($flow) || count($request['reservations']) > 0) {
		$noinfo =  "No detailed loading information is available for this ";
		$noinfo .= "reservation.";
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
	$text .= "<th align=right><br>State</th>";
	$text .= "<th>Est/Act<br>Time</th>";
	$text .= "<th>Total<br>Time</th>";
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
			$text .= "<td colspan=3><hr>problem at state ";
			$text .= "\"{$flow['data'][$id]['nextstate']}\"";
			$query = "SELECT additionalinfo "
			       . "FROM computerloadlog "
			       . "WHERE loadstateid = {$flow['repeatid']} AND "
			       .       "reservationid = {$request['resid']} AND "
			       .       "timestamp = '" . unixToDatetime($data['ts']) . "'";
			$qh = doQuery($query, 101);
			if($row = mysql_fetch_assoc($qh)) {
				$reason = $row['additionalinfo'];
				$text .= "<br>retrying at state \"$reason\"";
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
		$text .= "{$flow['data'][$id]['state']}($id)</font></td>";
		$text .= "<td nowrap align=center><font color=green>";
		$text .= secToMinSec($flow['data'][$id]['statetime']) . $slash;
		$text .= secToMinSec($data['time']) . "</font></td>";
		$text .= "<td nowrap align=center><font color=green>";
		$text .= secToMinSec($total) . "</font></td>";
		$text .= "</tr>";
		$last = $data;
	}
	# $id will be set if there was log data, use the first state in the flow
	#    if it isn't set
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
					$text  = "No detailed information is available for this ";
					$text .= "reservation.";
					return $text;
				}
				$text .= "<tr>";
				$text .= "<td nowrap align=right><font color=red>";
				$text .= "{$flow['data'][$id]['state']}($id)</font></td>";
				$text .= "<td nowrap align=center><font color=red>";
				$text .= secToMinSec($flow['data'][$id]['statetime']);
				$text .= $slash . secToMinSec($currtime) . "</font></td>";
				$text .= "<td nowrap align=center><font color=red>";
				$text .= secToMinSec($total + $currtime) . "</font></td>";
				$text .= "</tr>";
				$text .= "</table>";
				if(strlen($reason))
					$text .= "<br><font color=red>failed: $reason</font>";
				return $text;
			}
			# otherwise add text about current state
			else {
				if(! empty($data))
					$currtime = $now - $data['ts'];
				else
					$currtime = $now - datetimeToUnix($request['daterequested']);
				$text .= "<td nowrap align=right><font color=#CC8500>";
				$text .= "{$flow['data'][$id]['state']}($id)</font></td>";
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
			$text .= "<td nowrap align=right>{$flow['data'][$id]['state']}($id)";
			$text .= "</td>";
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
	$requestid = getContinuationVar("requestid");
	$request = getRequestInfo($requestid);
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
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('requestid' => $requestid, 'notbyowner' => 1);
	$cont = addContinuationsEntry('confirmDeleteRequest', $cdata, SECINDAY);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=\"Delete Reservation\">\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "</DIV>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editRequest()
///
/// \brief prints a page for a user to edit a previous request
///
////////////////////////////////////////////////////////////////////////////////
function editRequest() {
	global $submitErr, $user;
	$requestid = getContinuationVar('requestid', 0);
	$request = getRequestInfo($requestid);
	if(! array_key_exists("stateid", $request)) {
		viewRequests();
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
	if($submitErr) {
		$data = processRequestInput(0);
	}
	$groupid = getUserGroupID('Specify End Time', 1);
	$members = getUserGroupMembers($groupid);
	if(array_key_exists($user['id'], $members))
		$openend = 1;
	else
		$openend = 0;
	$unixstart = datetimeToUnix($request["start"]);
	$unixend = datetimeToUnix($request["end"]);
	$maxtimes = getUserMaxTimes();
	$timeToNext = timeToNextReservation($request);

	print "<H2>Modify Reservation</H2>\n";
	$now = time();
	if($unixstart > $now)
		$started = 0;
	else {
		# \todo if $timeToNext is anything < 30, try moving reservations off until it is >= 30
		if($timeToNext == 0) {
			$movedall = 1;
			foreach($request["reservations"] as $res) {
				if(! moveReservationsOffComputer($res["computerid"], 1)) {
					$movedall = 0;
					break;
				}
			}
			if(! $movedall) {
				// cannot extend the reservation unless we move the next one to another computer
				print "The computer you are using has another reservation ";
				print "immediately following yours. Therefore, you cannot extend ";
				print "your reservation because it would overlap with the next ";
				print "one.<br>\n";
				printEditNewUpdate($request, $reservation);
				return;
			}
			$timeToNext = timeToNextReservation($request);
		}
		if($timeToNext >= 15)
			$timeToNext -= 15;
		$started = 1;
		if(! $openend) {
			if($timeToNext == -1) {
				print "Because this reservation has already started, you can only ";
				print "extend the length of the reservation. ";
				print "You can extend this reservation ";
				print "by up to " . minToHourMin($maxtimes["extend"]) . ", but not ";
				print "exceeding " . minToHourMin($maxtimes["total"]) . " for your ";
				print "total reservation time.<br><br>\n";
			}
			elseif($timeToNext < 15) {
				print "The computer you are using has another reservation ";
				print "immediately following yours. Therefore, you cannot extend ";
				print "your reservation because it would overlap with the next ";
				print "one.<br>\n";
				printEditNewUpdate($request, $reservation);
				return;
			}
			else {
				print "Because this reservation has already started, you can only ";
				print "extend the length of the reservation. ";
				print "The computer you are using has another reservation following ";
				print "yours. Therefore, you can only extend this reservation for ";
				print "another " . prettyLength($timeToNext) . ".<br><br>\n";
			}
		}
	}
	print "Modify reservation for <b>" . $reservation["prettyimage"];
	print "</b> starting ";
	if(datetimeToUnix($request["start"]) <
	   datetimeToUnix($request["daterequested"])) {
		print prettyDatetime($request["daterequested"]);
	}
	else {
		print prettyDatetime($request["start"]);
	}
	print ":<br><br>\n";
	$start = date('l,g,i,a', datetimeToUnix($request["start"]));
	$startArr = explode(',', $start);
	$len = ($unixend - $unixstart) / 60;
	$cdata = array();
	if($started) {
		$inputday = date('n/j/Y', datetimeToUnix($request["start"]));
		$cdata['day'] = $inputday;
		$cdata['hour'] = $startArr[1];
		$cdata['minute'] = $startArr[2];
		$cdata['meridian'] = $startArr[3];
		# determine the current total length of the reservation
		$reslen = ($unixend - unixFloor15($unixstart)) / 60;
		$timeval = getdate($unixstart);
		if(($timeval["minutes"] % 15) != 0) {
			$reslen -= 15;
		}
		if(! $openend && ($reslen >= $maxtimes["total"])) {
			print "You are only allowed to extend your reservation such that it ";
			print "has a total length of " . minToHourMin($maxtimes["total"]);
			print ". This reservation already meets that length. Therefore, ";
			print "you are not allowed to extend your reservation any further.<br><br>\n";
			printEditNewUpdate($request, $reservation);
			return;
		}
		//if have time left to extend it, create an array of lengths based on maxextend that has a cap
		# so we don't run into another reservation and we can't extend past the totalmax
		$lengths = array();
		if($timeToNext == -1) {
			// there is no following reservation
			if((($reslen + 15) <= $maxtimes["total"]) && (15 <= $maxtimes["extend"]))
				$lengths["15"] = "15 minutes";
			if((($reslen + 30) <= $maxtimes["total"]) && (30 <= $maxtimes["extend"]))
				$lengths["30"] = "30 minutes";
			if((($reslen + 60) <= $maxtimes["total"]) && (60 <= $maxtimes["extend"]))
				$lengths["60"] = "1 hour";
			for($i = 120;(($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]); $i += 60) {
				$lengths[$i] = $i / 60 . " hours";
			}
		}
		else {
			if($timeToNext >= 15 && (($reslen + 15) <= $maxtimes["total"]) && (15 <= $maxtimes["extend"]))
				$lengths["15"] = "15 minutes";
			if($timeToNext >= 30 && (($reslen + 30) <= $maxtimes["total"]) && (30 <= $maxtimes["extend"]))
				$lengths["30"] = "30 minutes";
			if($timeToNext >= 45 && (($reslen + 45) <= $maxtimes["total"]) && (45 <= $maxtimes["extend"]))
				$lengths["45"] = "45 minutes";
			if($timeToNext >= 60 && (($reslen + 60) <= $maxtimes["total"]) && (60 <= $maxtimes["extend"]))
				$lengths["60"] = "1 hour";
			for($i = 120; ($i <= $timeToNext) && (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]); $i += 60) {
				$lengths[$i] = $i / 60 . " hours";
			}
		}
		# do we need this?
		/*if($timeToNext > 60 && (($reslen + $timeToNext) <= $maxtimes["total"]) && ($timeToNext <= $maxtimes["extend"]))
			if($timeToNext % 60 == 0)
				$lengths[$timeToNext] = $timeToNext / 60 . " hours";
			else
				$lengths[$timeToNext] = sprintf("%.2f hours", $timeToNext / 60);*/
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		if($openend) {
			if(! empty($lengths)) {
				if($submitErr && $data['ending'] == 'date') {
					$chk['length'] = '';
					$chk['date'] = 'checked';
				}
				else {
					$chk['length'] = 'checked';
					$chk['date'] = '';
				}
				print "<INPUT type=radio name=ending value=length {$chk['length']}>";
				print "Extend reservation by:\n";
				if($submitErr)
					printSelectInput("length", $lengths, $data['length']);
				else
					printSelectInput("length", $lengths, 30);
				print "<br><INPUT type=radio name=ending value=date {$chk['date']}>";
			}
			else
					print "<INPUT type=hidden name=ending value=date>\n";
			print "Change ending to:\n";
			$enddate = $request['end'];
			if($submitErr)
				$enddate = $data['enddate'];
			print "<INPUT type=text name=enddate size=20 value=\"$enddate\">(YYYY-MM-DD HH:MM:SS)\n";
			printSubmitErr(ENDDATEERR);
			if($timeToNext > -1) {
				$extend = $unixend + (($timeToNext - 15) * 60);
				$extend = unixToDatetime($extend);
				print "<br><font color=red><strong>NOTE:</strong> Due to an upcoming ";
				print "reservation on the same computer,<br>\n";
				print "you can only extend this reservation until $extend.</font>\n";
			}
		}
		else {
			print "Extend reservation by: \n";
			printSelectInput("length", $lengths, 30);
		}
		print "<br>\n";
		$cdata['started'] = 1;
	}
	else {
		$imgdata = getImages(1, $reservation['imageid']);
		$maxlen = $imgdata[$reservation['imageid']]['maxinitialtime'];
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		printReserveItems(1, 0, $len, $maxlen, $startArr[0], $startArr[1], $startArr[2], $startArr[3], 1);
		$cdata['started'] = 0;
	}
	print "<br>\n";
	print "<table summary=\"\">\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	$cdata['requestid'] = $requestid;
	$cdata['openend'] = $openend;
	$cdata['imageid'] = $reservation['imageid'];
	$cont = addContinuationsEntry('confirmEditRequest', $cdata, SECINDAY, 0, 1, 1);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=\"Confirm Changes\">\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewRequests');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";

	printEditNewUpdate($request, $reservation);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printEditNewUpdate($request, $res)
///
/// \param $request - array of request data from getRequestInfo
/// \param $res - reservation part of $request array
///
/// \brief prints a form for allowing the user to save the current image as a
/// new image or update the existing image
///
////////////////////////////////////////////////////////////////////////////////
function printEditNewUpdate($request, $res) {
	global $user;
	# do not allow save/update for cluster images
	if(count($request['reservations']) > 1)
		return;

	# if already an imaging reservation, don't display update info here
	if($request['forimaging'])
		return;
	
	# don't allow save/update unless reservation has made inuse state
	if($request['stateid'] != 8 && $request['laststateid'] != 8)
		return;

	$resources = getUserResources(array("imageAdmin"));
	if(! array_key_exists($res['imageid'], $resources['image']))
		return;

	$compid = $request['reservations'][0]['computerid'];
	$comp = getComputers(0, 0, $compid);
	if($comp[$compid]['type'] != 'blade')
		return;

	print "<h2>Save as New Image / Update Image</h2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('requestid' => $request['id']);
	$cont = addContinuationsEntry('newImage', $cdata, SECINDAY, 0);
	print "<INPUT type=radio name=continuation value=\"$cont\" id=newimage checked>";
	print "<label for=newimage>Save as New Image</label><br>\n";
	$imageData = getImages(0, $res['imageid']);
	if($imageData[$res['imageid']]['ownerid'] != $user['id']) {
		print "<INPUT type=radio name=continuation value=\"$cont\" ";
		print "id=updateimage disabled><label for=updateimage><font color=gray>";
		print "Update Existing Image</font></label>";
	}
	else {
		$cdata['nextmode'] = 'updateExistingImage';
		$cont = addContinuationsEntry('imageClickThroughAgreement', $cdata, SECINDAY, 0);
		print "<INPUT type=radio name=continuation value=\"$cont\" ";
		print "id=updateimage><label for=updateimage>Update Existing Image";
		print "</label>";
	}
	print "<br><br>\n";
	print "<INPUT type=submit value=\"Save/Update\">\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmEditRequest()
///
/// \brief prints a page confirming the change the user requested for his
/// request
///
////////////////////////////////////////////////////////////////////////////////
function confirmEditRequest() {
	global $submitErr;
	$data = processRequestInput(1);
	if($submitErr) {
		editRequest();
		return;
	}
	$cdata = getContinuationVar();
	$request = getRequestInfo($cdata["requestid"]);
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
	print "<H2>Modify Reservation</H2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	if($cdata["started"]) {
		if($cdata['openend'] && $data['ending'] == 'date') {
			print "Change ending for <b>{$reservation["prettyimage"]}</b> ";
			print "to {$data['enddate']}?<br><br>\n";
		}
		else {
			print "Extend reservation for <b>{$reservation["prettyimage"]}</b> ";
			print "by " . prettyLength($data["length"]) . "?<br><br>\n";
		}

		$unixstart = datetimeToUnix($request["start"]);
		$curlen = (datetimeToUnix($request["end"]) - $unixstart) / 60;
		if($unixstart < datetimeToUnix($request["daterequested"])) {
			$curlen -= 15;
		}
		$cdata["extend"] = $data["length"];
		$cdata["length"] = $curlen + $data["length"];
	}
	else {
		print "Change reservation for <b>" . $reservation["prettyimage"];
		print "</b> starting ";
		if(datetimeToUnix($request["start"]) <
		   datetimeToUnix($request["daterequested"])) {
			print prettyDatetime($request["daterequested"]);
		}
		else {
			print prettyDatetime($request["start"]);
		}
		print "<br>\nto ";
		if($data['ending'] == 'date') {
			print "start {$data["day"]} at {$data["hour"]}:";
			if($data["minute"] == 0)
				print "00";
			else
				print $data["minute"];
			print " {$data["meridian"]} and end ";
			$tmp = date('n/j/Y-g:i a', datetimeToUnix($data["enddate"]));
			$tmp = explode('-', $tmp);
			print "{$tmp[0]} at {$tmp[1]}?<br><br>\n";
		}
		else {
			print "{$data["day"]}, at {$data["hour"]}:";
			if($data["minute"] == 0)
				print "00";
			else
				print $data["minute"];
			print " {$data["meridian"]} ";
			print "for " . prettyLength($data["length"]) . "?<br><br>\n";
		}
	}
	print "<table summary=\"\">\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	$cdata = array_merge($data, $cdata);
	$cdata['imageid'] = $reservation['imageid'];
	$cdata['imagerevisionid'] = $reservation['imagerevisionid'];
	$cdata['prettyimage'] = $reservation['prettyimage'];
	if($submitErr)
		$cont = addContinuationsEntry('submitEditRequest', $cdata, SECINDAY, 1, 0);
	else
		$cont = addContinuationsEntry('submitEditRequest', $cdata, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewRequests');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditRequest()
///
/// \brief submits changes to a request and prints that it has been changed
///
////////////////////////////////////////////////////////////////////////////////
function submitEditRequest() {
	global $user, $submitErr, $viewmode, $mode;
	$data = getContinuationVar();
	$request = getRequestInfo($data["requestid"]);

	print "<H2>Modify Reservation</H2>\n";

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
	if($data['openend'] && $data['ending'] == 'date')
		$end = datetimeToUnix($data['enddate']);
	else {
		if(datetimeToUnix($request["start"]) < datetimeToUnix($request["daterequested"]))
			$end = $start + $data["length"] * 60 + 900;
		else
			$end = $start + $data["length"] * 60;
	}

	// get semaphore lock
	if(! semLock())
		abort(3);

	$max = getMaxOverlap($user['id']);
	if(checkOverlap($start, $end, $max, $data["requestid"])) {
		if($max == 0) {
			print "<font color=\"#ff0000\">The time you requested overlaps with ";
			print "another reservation you currently have.  You are only allowed ";
			print "to have a single reservation at any given time. Please select ";
			print "another time to use the application.</font><br><br>\n";
		}
		else {
			print "<font color=\"#ff0000\">The time you requested overlaps with ";
			print "another reservation you currently have.  You are allowed ";
			print "to have $max overlapping reservations at any given time. ";
			print "Please select another time to use the application.</font><br>";
			print "<br>\n";
		}
		$submitErr = 1;
		editRequest();
		return;
	}
	$rc = isAvailable(getImages(), $data["imageid"], $data['imagerevisionid'],
	                  $start, $end, $data["requestid"]);
	if($rc == -1) {
		print "You have requested an environment that is limited in the number ";
		print "of concurrent reservations that can be made. No further ";
		print "reservations for the environment can be made for the time you ";
		print "have selected. Please select another time to use the ";
		print "environment.<br>";
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($end),
		                  unixToDatetime($start), NULL, NULL, 0);
	}
	elseif($rc > 0) {
		updateRequest($data["requestid"]);
		if($data["started"]) {
			if($data['openend'] && $data['ending'] == 'date') {
				print "Your request to change the ending of your reservation for <b>";
				print "{$data["prettyimage"]}</b> to {$data['enddate']} ";
				print "has been accepted.<br><br>\n";
			}
			else {
				$remaining = (int)(($end - time()) / 60);
				print "Your request to extend your reservation for <b>";
				print "{$data["prettyimage"]}</b> by " . prettyLength($data["extend"]);
				print " has been accepted.<br><br>\n";
				print "You now have " . prettyLength($remaining) . " remaining for ";
				print "your reservation<br>\n";
			}
		}
		else {
			print "Your request to use <b>" . $data["prettyimage"] . "</b> on ";
			if(datetimeToUnix($request["start"]) <
			   datetimeToUnix($request["daterequested"])) {
				print prettyDatetime($request["daterequested"]);
			}
			else
				print prettyDatetime($start);
			if($data['openend'] && $data['ending'] == 'date')
				print " until " . prettyDatetime($end);
			else
				print " for " . prettyLength($data["length"]);
			print " has been accepted.<br>\n";
		}
	}
	else {
		$cdata = array('imageid' => $data['imageid'],
		               'length' => $data['length'],
		               'requestid' => $data['requestid']);
		$cont = addContinuationsEntry('selectTimeTable', $cdata);
		if($rc == -2) {
			print "The time you have requested is not available due to scheduled ";
			print "system downtime for maintenance. ";
		}
		else
			print "The time you have requested is not available. ";
		print "You may <a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "view a timetable</a> of free and reserved times to find ";
		print "a time that will work for you.<br>\n";
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($end),
		                  unixToDatetime($start), NULL, NULL, 0);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteRequest()
///
/// \brief prints a confirmation page about deleting a request
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteRequest() {
	$requestid = getContinuationVar('requestid', 0);
	$notbyowner = getContinuationVar('notbyowner', 0);
	$request = getRequestInfo($requestid);
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
		$title = "Delete Reservation";
		$text = "Delete reservation for <b>" . $reservation["prettyimage"]
		      . "</b> starting " . prettyDatetime($request["start"]) . "?<br>\n";
	}
	else {
		if(! $reservation["production"]) {
			confirmDeleteRequestProduction($request);
			return;
		}
		else {
			$title = "End Reservation";
			if($notbyowner == 0) {
				$text = "Are you finished with your reservation for <strong>"
						. $reservation["prettyimage"] . "</strong> that started ";
			}
			else {
				$userinfo = getUserInfo($request["userid"], 1, 1);
				$text = "Delete reservation by {$userinfo['unityid']}@"
				      . "{$userinfo['affiliation']} for <strong>"
				      . "{$reservation["prettyimage"]}</strong> that started ";
			}
			if(datetimeToUnix($request["start"]) <
				datetimeToUnix($request["daterequested"])) {
				$text .= prettyDatetime($request["daterequested"]);
			}
			else {
				$text .= prettyDatetime($request["start"]);
			}
			$text .= "?<br>\n";
		}
	}
	print "<H2>$title</H2>\n";
	print $text;
	print "<table summary=\"\">\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('requestid' => $requestid, 'notbyowner' => $notbyowner);
	$cont = addContinuationsEntry('submitDeleteRequest', $cdata, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Yes>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewRequests');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=No>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteRequestProduction($request)
///
/// \param $request - a request array as returend from getRequestInfo
///
/// \brief prints a page asking if the user is ready to make the image
/// production or just end this reservation
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteRequestProduction($request) {
	$cdata = array('requestid' => $request['id']);
	print "<H2>End Reservation/Make Production</H2>\n";
	print	"Are you satisfied that this environment is ready to be made production ";
	print "and replace the current production version, or would you just like to ";
	print "end this reservation and test it again later?\n";

	if(isImageBlockTimeActive($request['reservations'][0]['imageid'])) {
		print "<br><br><font color=\"red\">WARNING: This environment is part of ";
		print "an active block allocation. Changing the production version of ";
		print "the environment at this time will result in new reservations ";
		print "under the block allocation to have full reload times instead of ";
		print "a &lt; 1 minutes wait. You can change the production version ";
		print "later by going to Manage Images-&gt;Edit Image Profiles and ";
		print "clicking Edit for this environment.</font><br>\n";
	}

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";

	$cont = addContinuationsEntry('setImageProduction', $cdata, SECINDAY, 0, 1);
	print "<br>&nbsp;&nbsp;&nbsp;<INPUT type=radio name=continuation ";
	print "value=\"$cont\">Make this the production version<br>\n";

	$cont = addContinuationsEntry('submitDeleteRequest', $cdata, SECINDAY, 0, 0);
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=continuation ";
	print "value=\"$cont\">Just end the reservation<br>\n";

	$cont = addContinuationsEntry('viewRequests');
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=continuation ";
	print "value=\"$cont\">Neither, go back to <strong>Current Reservations";
	print "</strong><br><br>\n";

	print "<INPUT type=submit value=Submit>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteRequest()
///
/// \brief submits deleting a request and prints that it has been deleted
///
////////////////////////////////////////////////////////////////////////////////
function submitDeleteRequest() {
	$requestid = getContinuationVar('requestid', 0);
	$request = getRequestInfo($requestid);
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
	deleteRequest($request);
	if(datetimeToUnix($request["start"]) > time()) {
		print "<H2>Delete Reservation</H2>";
		print "The reservation for <b>" . $reservation["prettyimage"];
		print "</b> starting " . prettyDatetime($request["start"]);
		print " has been deleted.<br>\n";
	}
	else {
		print "<H2>End Reservation</H2>";
		print "The reservation for <b>" . $reservation["prettyimage"];
		print "</b> starting ";
		if(datetimeToUnix($request["start"]) <
		   datetimeToUnix($request["daterequested"])) {
			print prettyDatetime($request["daterequested"]);
		}
		else {
			print prettyDatetime($request["start"]);
		}
		print " has been released.<br>\n";
	}
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
	global $user;
	if(! is_numeric($length))
		$length = 60;
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
		$days[$index] = $tmp["weekday"];
		if($tmp["weekday"] == $day) {
			$inputday = $index;
		}
	}

	if($modifystart) {
		printSelectInput("day", $days, $inputday);
		print "&nbsp;At&nbsp;\n";
		$tmpArr = array();
		for($i = 1; $i < 13; $i++) {
			$tmpArr[$i] = $i;
		}
		printSelectInput("hour", $tmpArr, $hour);

		$minutes = array("zero" => "00",
							  "15" => "15",
							  "30" => "30", 
							  "45" => "45");
		printSelectInput("minute", $minutes, $minute);
		printSelectInput("meridian", array("am" => "a.m.", "pm" => "p.m."), $meridian);
		print "<small>(" . date('T') . ")</small>";
		//if(! $oneline)
			print "<br><br>";
		/*else
			print "&nbsp;&nbsp;";*/
		if($openend) {
			print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=ending ";
			print "onclick='updateWaitTime(0);' value=length checked>";
		}
		print "Duration:&nbsp;\n";
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
	$lengths = array();
	if($maxtimes["initial"] >= 30)
		$lengths["30"] = "30 minutes";
	if($maxtimes["initial"] >= 60)
		$lengths["60"] = "1 hour";
	for($i = 120; $i <= $maxtimes["initial"] && $i < 2880; $i += 120)
		$lengths[$i] = $i / 60 . " hours";
	for($i = 2880; $i <= $maxtimes["initial"]; $i += 1440)
		$lengths[$i] = $i / 1440 . " days";

	printSelectInput("length", $lengths, $length, 0, 0, 'reqlength', "onChange='updateWaitTime(0);'");
	print "<br>\n";
	if($openend) {
		print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=ending id=openend ";
		print "onclick='updateWaitTime(0);' value=date>Until\n";
		print "<INPUT type=text name=enddate size=20 value=\"$enddate\">(YYYY-MM-DD HH:MM:SS)\n";
		printSubmitErr(ENDDATEERR);
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
	if($requestData['reservations'][0]['remoteIP'] != $remoteIP) {
		$setback = unixToDatetime(time() - 600);
		$query = "UPDATE reservation "
		       . "SET remoteIP = '$remoteIP', "
		       .     "lastcheck = '$setback' "
		       . "WHERE requestid = $requestid";
		$qh = doQuery($query, 226);

		addChangeLogEntry($requestData["logid"], $remoteIP);
	}

	print "<H2 align=center>Connect!</H2>\n";
	if($requestData['forimaging']) {
		print "<font color=red><big><strong>NOTICE:</strong> Later in this process, you must accept a
		<a href=\"" . BASEURL . SCRIPT . "?mode=imageClickThrough\">click-through agreement</a> about software licensing.</big></font><br><br>\n";
	}
	if(count($requestData["reservations"]) == 1) {
		$serverIP = $requestData["reservations"][0]["reservedIP"];
		$osname = $requestData["reservations"][0]["OS"];
		$passwd = $requestData["reservations"][0]["password"];
		if(preg_match("/windows/i", $osname)) {
			print "You will need to use a ";
			print "Remote Desktop program to connect to the ";
			print "system. If you did not click on the <b>Connect!</b> button from ";
			print "the computer you will be using to access the VCL system, you ";
			print "will need to return to the <strong>Current Reservations</strong> ";
			print "page and click the <strong>Connect!</strong> button from ";
			print "a web browser running on the same computer from which you will ";
			print "be connecting to the VCL system. Otherwise, you may be denied ";
			print "access to the remote computer.<br><br>\n";
			print "Use the following information when you are ready to connect:<br>\n";
			print "<UL>\n";
			print "<LI><b>Remote Computer</b>: $serverIP</LI>\n";
			if($requestData["forimaging"])
				print "<LI><b>User ID</b>: Administrator</LI>\n";
			else
				if(preg_match('/(.*)@(.*)/', $user['unityid'], $matches))
					print "<LI><b>User ID</b>: " . $matches[1] . "</LI>\n";
				else
					print "<LI><b>User ID</b>: " . $user['unityid'] . "</LI>\n";
			if(strlen($passwd)) {
				print "<LI><b>Password</b>: $passwd<br></LI>\n";
				print "</UL>\n";
				print "<b>NOTE</b>: The given password is for <i>this reservation ";
				print "only</i>. You will be given a different password for any other ";
				print "reservations.<br>\n";
			}
			else {
				print "<LI><b>Password</b>: (use your campus password)</LI>\n";
				print "</UL>\n";
			}
			/*print "<br>\n";
			print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
			print "<h3>NEW!</h3>\n";
			print "Connect to the server using a java applet:<br>\n";
			print "<INPUT type=submit value=\"Connect with Applet\">\n";
			print "<INPUT type=hidden name=mode value=connectRDPapplet>\n";
			print "<INPUT type=hidden name=requestid value=$requestid>\n";
			print "</FORM><br>\n";*/
			print "For automatic connection, you can download an RDP file that can ";
			print "be opened by the Remote Desktop Connection program.<br><br>\n";
			print "<table summary=\"\">\n";
			print "  <TR>\n";
			print "    <TD>\n";
			print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
			$cdata = array('requestid' => $requestid,
				            'resid' => $requestData['reservations'][0]['reservationid']);
			$expire = datetimeToUnix($requestData['end']) -
			          datetimeToUnix($requestData['start']) + 1800; # reservation time plus 30 min
			$cont = addContinuationsEntry('sendRDPfile', $cdata, $expire);
			print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
			print "      <INPUT type=submit value=\"Get RDP File\">\n";
			print "      </FORM>\n";
			print "    </TD>\n";
			print "  </TR>\n";
			print "</table>\n";
		}
		else {
			print "You will need to have an ";
			print "X server running on your local computer and use an ";
			print "ssh client to connect to the system. If you did not ";
			print "click on the <b>Connect!</b> button from ";
			print "the computer you will be using to access the VCL system, you ";
			print "will need to return to the <strong>Current Reservations</strong> ";
			print "page and click the <strong>Connect!</strong> button from ";
			print "a web browser running on the same computer from which you will ";
			print "be connecting to the VCL system. Otherwise, you may be denied ";
			print "access to the remote computer.<br><br>\n";
			print "Use the following information when you are ready to connect:<br>\n";
			print "<UL>\n";
			print "<LI><b>Remote Computer</b>: $serverIP</LI>\n";
			if(preg_match('/(.*)@(.*)/', $user['unityid'], $matches))
				print "<LI><b>User ID</b>: " . $matches[1] . "</LI>\n";
			else
				print "<LI><b>User ID</b>: " . $user['unityid'] . "</LI>\n";
			if(strlen($passwd)) {
				print "<LI><b>Password</b>: $passwd<br></LI>\n";
				print "</UL>\n";
				print "<b>NOTE</b>: The given password is for <i>this reservation ";
				print "only</i>. You will be given a different password for any other ";
				print "reservations.<br>\n";
			}
			else {
				print "<LI><b>Password</b>: (use your campus password)</LI>\n";
				print "</UL>\n";
			}
			print "<strong><big>NOTE:</big> You cannot use the Windows Remote ";
			print "Desktop Connection to connect to this computer. You must use an ";
			print "ssh client.</strong>\n";
			/*if(preg_match("/windows/i", $_SERVER["HTTP_USER_AGENT"])) {
				print "<br><br><h3>NEW!</h3>\n";
				print "Connect to the server using a java applet:<br>\n";
				print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				print "<INPUT type=submit value=\"Connect with Applet\">\n";
				print "<INPUT type=hidden name=mode value=connectMindterm>\n";
				print "<INPUT type=hidden name=serverip value=\"$serverIP\">\n";
				print "</FORM>\n";
			}*/
		}
	}
	else {
		print "You will need an ";
		print "ssh client to connect to any unix systems.<br>\n";
		print "You will need a ";
		print "Remote Desktop program</a> to connect to any windows systems.<br><br>\n";
		print "Use the following information when you are ready to connect:<br>\n";
		$total = count($requestData["reservations"]);
		$count = 0;
		foreach($requestData["reservations"] as $key => $res) {
			$count++;
			print "<h3>{$res["prettyimage"]}</h3>\n";
			print "<UL>\n";
			print "<LI><b>Platform</b>: {$res["OS"]}</LI>\n";
			print "<LI><b>Remote Computer</b>: {$res["reservedIP"]}</LI>\n";
			print "<LI><b>User ID</b>: " . $user['login'] . "</LI>\n";
			if(preg_match("/windows/i", $res["OS"])) {
				if(strlen($res['password'])) {
					print "<LI><b>Password</b>: {$res['password']}<br></LI>\n";
					print "</UL>\n";
					print "<b>NOTE</b>: The given password is for <i>this reservation ";
					print "only</i>. You will be given a different password for any other ";
					print "reservations.<br>\n";
				}
				else {
					print "<LI><b>Password</b>: (use your campus password)</LI>\n";
					print "</UL>\n";
				}
				/*print "Connect to the server using a java applet:<br>\n";
				print "<INPUT type=submit value=\"Connect with Applet\">\n";
				print "<INPUT type=hidden name=mode value=connectRDPapplet>\n";
				print "<INPUT type=hidden name=requestid value=$requestid>\n";
				print "<INPUT type=hidden name=reservedIP value=\"{$res["reservedIP"]}\">\n";
				print "</FORM><br><br>\n";*/
				print "Automatic connection using an RDP file:<br>\n";
				print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cdata = array('requestid' => $requestid,
				               'resid' => $res['reservationid'],
				               'reservedIP' => $res['reservedIP']);
				$expire = datetimeToUnix($requestData['end']) -
				          datetimeToUnix($requestData['start']) + 1800; # reservation time plus 30 min
				$cont = addContinuationsEntry('sendRDPfile', $cdata, $expire);
				print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
				print "<INPUT type=submit value=\"Get RDP File\">\n";
				print "</FORM>\n";
			}
			else {
				if(strlen($res['password'])) {
					print "<LI><b>Password</b>: {$res['password']}<br></LI>\n";
					print "</UL>\n";
					print "<b>NOTE</b>: The given password is for <i>this reservation ";
					print "only</i>. You will be given a different password for any other ";
					print "reservations.<br>\n";
				}
				else {
					print "<LI><b>Password</b>: (use your campus password)</LI>\n";
					print "</UL>\n";
				}
				/*if(preg_match("/windows/i", $_SERVER["HTTP_USER_AGENT"])) {
					print "Connect to the server using a java applet:<br>\n";
					print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
					print "<INPUT type=submit value=\"Connect with Applet\">\n";
					print "<INPUT type=hidden name=mode value=connectMindterm>\n";
					print "<INPUT type=hidden name=requestid value=$requestid>\n";
					print "<INPUT type=hidden name=serverip value=\"{$res["reservedIP"]}\">\n";
					print "</FORM>\n";
				}*/
			}
			if($count < $total)
				print "<hr>\n";
		}
	}
	foreach($requestData["reservations"] as $res) {
		if($res["forcheckout"]) {
			$imageid = $res["imageid"];
			break;
		}
	}
	$imagenotes = getImageNotes($imageid);
	if(preg_match('/\w/', $imagenotes['usage'])) {
		print "<h3>Notes on using this environment:</h3>\n";
		print "{$imagenotes['usage']}<br><br><br>\n";
	}
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
		$submitErrMsg[IMAGEIDERR] = "Please select a valid environment";
		$noimage = 1;
	}

	if(! $return["started"]) {
		$checkdateArr = explode('/', $return["day"]);
		if(! is_numeric($checkdateArr[0]) ||
		   ! is_numeric($checkdateArr[1]) ||
		   ! is_numeric($checkdateArr[2]) ||
		   ! checkdate($checkdateArr[0], $checkdateArr[1], $checkdateArr[2])) {
			$submitErr |= STARTDAYERR;
			$submitErrMsg[STARTDAYERR] = "The submitted start date is invalid. ";
		}
		if(! preg_match('/^((0?[1-9])|(1[0-2]))$/', $return["hour"], $regs)) {
			$submitErr |= STARTHOURERR;
			$submitErrMsg[STARTHOURERR] = "The submitted hour must be from 1 to 12.";
		}
	}

	# TODO check for valid revisionids for each image
	if(! empty($return["revisionid"])) {
		foreach($return['revisionid'] as $key => $val) {
			if(! is_numeric($val) || $val < 0)
				unset($return['revisionid']);
		}
	}

	/*if($mode == "confirmAdminEditRequest") {
		$checkdateArr = explode('/', $return["endday"]);
		if(! is_numeric($checkdateArr[0]) ||
		   ! is_numeric($checkdateArr[1]) ||
		   ! is_numeric($checkdateArr[2]) ||
		   ! checkdate($checkdateArr[0], $checkdateArr[1], $checkdateArr[2])) {
			$submitErr |= ENDDAYERR;
			$submitErrMsg[ENDDAYERR] = "The submitted end date is invalid. ";
		}
		if(! preg_match('/^((0?[1-9])|(1[0-2]))$/', $return["endhour"])) {
			$submitErr |= ENDHOURERR;
			$submitErrMsg[ENDHOURERR] = "The submitted hour must be from 1 to 12.";
		}
	}*/

	// make sure user hasn't submitted something longer than their allowed max length
	$maxtimes = getUserMaxTimes();
	if($mode != 'confirmEditRequest') {
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
	}
	else {
		if($maxtimes['extend'] < $return['length']) {
			$return['lengthchanged'] = 1;
			$return['length'] = $maxtimes['extend'];
		}
	}

	if($return["ending"] != "length") {
		if(! preg_match('/^(20[0-9]{2})-([0-1][0-9])-([0-3][0-9]) (([0-1][0-9])|(2[0-3])):([0-5][0-9]):([0-5][0-9])$/', $return["enddate"], $regs)) {
			$submitErr |= ENDDATEERR;
			$submitErrMsg[ENDDATEERR] = "The submitted date/time is invalid.";
		}
		elseif(! checkdate($regs[2], $regs[3], $regs[1])) {
			$submitErr |= ENDDATEERR;
			$submitErrMsg[ENDDATEERR] = "The submitted date/time is invalid.";
		}
	}

	if($return["testjavascript"] != 0 && $return['testjavascript'] != 1)
		$return["testjavascript"] = 0;
	return $return;
}
?>
