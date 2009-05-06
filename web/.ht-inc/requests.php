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
define("ENDDAYERR", 1 << 2);
/// signifies an error with the submitted end hour
define("ENDHOURERR", 1 << 3);
/// signifies an error with the submitted starting date
define("STARTDATEERR", 1 << 4);
/// signifies an error with the submitted endding date and time
define("ENDDATEERR", 1 << 5);
/// signifies an error with the selected imageid
define("IMAGEIDERR", 1 << 6);
/// signifies an error with the number of block machines
define("BLOCKCNTERR", 1 << 7);
/// signifies an error with the selected groupid
define("USERGROUPIDERR", 1 << 8);
/// signifies an error with the selected availibility time
define("AVAILABLEERR", 1 << 9);
/// signifies an error with the selected week number
define("WEEKNUMERR", 1 << 10);
/// signifies an error with the selected day of the week
define("DAYERR", 1 << 11);
/// signifies an error with the specified name
define("BLOCKNAMEERR", 1 << 12);
/// signifies an error with the selected admin groupid
define("ADMINGROUPIDERR", 1 << 13);


////////////////////////////////////////////////////////////////////////////////
///
/// \fn newReservation()
///
/// \brief prints form for submitting a new reservation
///
////////////////////////////////////////////////////////////////////////////////
function newReservation() {
	global $submitErr, $user;
	$timestamp = processInputVar("stamp", ARG_NUMERIC);
	$imageid = processInputVar("imageid", ARG_STRING, getUsersLastImage($user['id']));
	$length = processInputVar("length", ARG_NUMERIC);
	$day = processInputVar("day", ARG_STRING);
	$hour = processInputVar("hour", ARG_NUMERIC);
	$minute = processInputVar("minute", ARG_NUMERIC);
	$meridian = processInputVar("meridian", ARG_STRING);

	if(! $submitErr)
		print "<H2>New Reservation</H2><br>\n";

	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);

	if((! in_array("imageCheckOut", $user["privileges"]) &&
	   ! in_array("imageAdmin", $user["privileges"])) ||
	   empty($resources['image'])) {
		print "You don't have access to any environments and, therefore, cannot ";
		print "make any reservations.<br>\n";
		return;
	}
	print "Please select the environment you want to use from the list:<br>\n";

	$OSs = getOSList();

	$images = getImages();
	$maxTimes = getUserMaxTimes();
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

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	// list of images
	uasort($resources["image"], "sortKeepIndex");
	printSelectInput("imageid", $resources["image"], $imageid, 1, 0, 'imagesel', "onChange=\"selectEnvironment();\" tabIndex=1");
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
	print "<legend>When would you like to use the application?</legend>\n";
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time id=timenow ";
	print "onclick='updateWaitTime(0);' value=now>Now<br>\n";
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time value=future ";
	print "onclick='updateWaitTime(0);' checked>Later:\n";
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
		printReserveItems(1, $day, $hour, $minute, $meridian, $length);
	}
	elseif(empty($timestamp)) {
		printReserveItems();
	}
	else {
		$timeArr = explode(',', date('l,g,i,a', $timestamp));
		printReserveItems(1, $timeArr[0], $timeArr[1], $timeArr[2], $timeArr[3], $length);
	}
	print "</fieldset>\n";

	print "<div id=waittime class=hidden></div><br>\n";
	$cont = addContinuationsEntry('submitRequest');
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT id=newsubmit type=submit value=\"Create Reservation\">\n";
	print "<INPUT type=hidden id=testjavascript value=0>\n";
	print "</FORM>\n";
	$cont = addContinuationsEntry('AJupdateWaitTime');
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
	if(empty($length) || $length > $times['initial']) {
		dbDisconnect();
		exit;
	}
	# process imageid
	$imageid = processInputVar('imageid', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$validImageids = array_keys($resources['image']);
	if(! in_array($imageid, $validImageids)) {
		dbDisconnect();
		exit;
	}

	$desconly = processInputVar('desconly', ARG_NUMERIC, 1);

	$imagenotes = getImageNotes($imageid);
	if(preg_match('/\w/', $imagenotes['description'])) {
		$desc = preg_replace("/\n/", '<br>', $imagenotes['description']);
		$desc = preg_replace("/\r/", '', $desc);
		$desc = preg_replace("/'/", '&#39;', $desc);
		print "dojo.byId('imgdesc').innerHTML = '<strong>Image Description</strong>:<br>";
		print "$desc<br><br>'; ";
	}

	if($desconly)
		return;

	$images = getImages();
	$now = time();
	$start = unixFloor15($now);
	$end = $start + $length * 60;
	if($start < $now)
		$end += 15 * 60;
	$rc = isAvailable($images, $imageid, $start, $end, '');
	semUnlock();
	print "dojo.byId('waittime').innerHTML = ";
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
	else
		$data = processRequestInput(1);
	if($submitErr) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		print "<H2>New Reservation</H2>\n";
		newReservation();
		return;
	}
	// FIXME hack to make sure user didn't submit a request for an image he 
	// doesn't have access to
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
			print "<H2>New Reservation</H2>\n";
			print "<font color=\"#ff0000\">The time you requested is in the past.";
			print " Please select \"Now\" or use a time in the future.</font><br>\n";
			$submitErr = 1;
			newReservation();
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

	$max = getMaxOverlap($user['id']);
	if(checkOverlap($start, $end, $max)) {
		$printedHTMLheader = 1;
		print $HTMLheader;
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
		return;
	}
	// if user is owner of the image and there is a test version of the image
	#   available, ask user if production or test image desired
	if($mode != "submitTestProd" && $showrevisions &&
	   $images[$data["imageid"]]["ownerid"] == $user["id"]) {
		#unset($data["testprod"]);
		$printedHTMLheader = 1;
		print $HTMLheader;
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
		print "<INPUT type=submit value=\"Create Reservation\">\n";
		print "</FORM>\n";
		return;
	}
	$rc = isAvailable($images, $data["imageid"], $start, $end, $data["os"]);
	if($rc == -1) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		print "<H2>New Reservation</H2>\n";
		print "You have requested an environment that is limited in the number ";
		print "of concurrent reservations that can be made. No further ";
		print "reservations for the environment can be made for the time you ";
		print "have selected. Please select another time to use the ";
		print "environment.<br>";
		addLogEntry($nowfuture, unixToDatetime($start), 
		            unixToDatetime($end), 0, $data["imageid"]);
	}
	elseif($rc > 0) {
		$requestid = addRequest(0, $data["revisionid"]);
		$time = prettyLength($data["length"]);
		if($data["time"] == "now") {
			$cdata = array('lengthchanged' => $data['lengthchanged']);
			$cont = addContinuationsEntry('viewRequests', $cdata);
			header("Location: " . BASEURL . SCRIPT . "?continuation=$cont");
			dbDisconnect();
			exit;
		}
		else {
			if($data["minute"] == 0) {
				$data["minute"] = "00";
			}
			$printedHTMLheader = 1;
			print $HTMLheader;
			print "<H2>New Reservation</H2>\n";
			if($data["ending"] == "length") {
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
		}
	}
	else {
		$cdata = array('imageid' => $data['imageid'],
		               'length' => $data['length'],
		               'showmessage' => 1);
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
/// \fn blockRequest()
///
/// \brief prints a page for selecting block request stuff
///
////////////////////////////////////////////////////////////////////////////////
function blockRequest() {
	print "<H2>Block Reservation</H2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('newBlockRequest');
	print "<INPUT type=radio id=newblock name=continuation value=\"$cont\">\n";
	print "<label for=newblock>New Block Reservation</label><br>\n";
	$cont = addContinuationsEntry('selectEditBlockRequest');
	print "<INPUT type=radio id=editblock name=continuation value=\"$cont\" checked>\n";
	print "<label for=editblock>Edit/Delete Block Reservation</label><br>\n";
	print "<INPUT type=submit value=Submit>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn newBlockRequest()
///
/// \brief prints form for submitting a new block request
///
////////////////////////////////////////////////////////////////////////////////
function newBlockRequest() {
	global $submitErr, $user, $days;
	$data = processBlockRequestInput(0);

	if(! $submitErr) {
		if($data['state'])
			print "<H2>Edit Block Reservation</H2>\n";
		else {
			print "<H2>New Block Reservation</H2>\n";
			$data['machinecnt'] = '';
		}
	}
	else {
		foreach($days as $day) {
			if(in_array($day, $data['wdays']))
				$data['wdayschecked'][$day] = 'checked';
		}
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "Enter a name for the Block Reservation:<br>\n";
	print "<INPUT type=text name=blockname size=30 value=\"{$data['blockname']}\">";
	printSubmitErr(BLOCKNAMEERR);
	print "<br><br>\n";
	print "Select an environment from the list:<br>\n";
	printSubmitErr(IMAGEIDERR);

	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);
	$OSs = getOSList();

	// list of images
	uasort($resources["image"], "sortKeepIndex");
	printSelectInput("imageid", $resources["image"], $data['imageid'], 1);
	print "<br><br>\n";

	print "How many machines do you need for the block request?<br>\n";
	print "<INPUT type=text name=machinecnt size=3 value={$data['machinecnt']}>";
	printSubmitErr(BLOCKCNTERR);
	print "<br><br>\n";

	print "What user group should be allowed to check out machines in this ";
	print "block request?<br>\n";
	// FIXME should we limit the course groups that show up?
	$groups = getUserGroups(0, $user['affiliationid']);
	if(array_key_exists(82, $groups))
		unset($groups[82]); # remove None group
	if(! empty($data['usergroupid']) &&
	   ! array_key_exists($data['usergroupid'], $groups)) {
		$groups[$data['usergroupid']] =
		      array('name' => getUserGroupName($data['usergroupid'], 1));
		uasort($groups, "sortKeepIndex");
	}
	printSelectInput('usergroupid', $groups, $data['usergroupid']);
	printSubmitErr(USERGROUPIDERR);
	print "<br><br>\n";

	print "What user group should be allowed to manage (administer) this ";
	print "block request?<br>\n";
	if(! empty($data['admingroupid']) &&
	   ! array_key_exists($data['admingroupid'], $groups)) {
		$groups[$data['admingroupid']] =
		      array('name' => getUserGroupName($data['admingroupid'], 1));
		uasort($groups, "sortKeepIndex");
	}
	$nonegroups = array_reverse($groups, TRUE);
	$nonegroups[0] = array('name' => 'None (owner only)');
	$nonegroups = array_reverse($nonegroups, TRUE);
	printSelectInput('admingroupid', $nonegroups, $data['admingroupid']);
	printSubmitErr(ADMINGROUPIDERR);
	print "<br><br>\n";

	$checked = array('weekly' => '',
	                 'monthly' => '',
	                 'list' => '');
	if($data['available'] == "weekly")
		$checked['weekly'] = 'checked';
	elseif($data['available'] == 'monthly')
		$checked['monthly'] = 'checked';
	elseif($data['available'] == 'list')
		$checked['list'] = 'checked';
	print "When do you need the block of machines to be available?<br>\n";
	print "<INPUT type=radio name=available id=rweekly value=\"weekly\"";
	print "{$checked['weekly']} onclick=javascript:show('weekly');>";
	print "<label for=rweekly>Repeating Weekly</label>\n";
	print "<INPUT type=radio name=available id=rmonthly value=\"monthly\"";
	print "{$checked['monthly']} onclick=javascript:show('monthly');>";
	print "<label for=rmonthly>Repeating Monthly</label>\n";
	print "<INPUT type=radio name=available id=rlist value=\"list\"";
	print "{$checked['list']} onclick=javascript:show('list');>";
	print "<label for=rlist>List of dates/times</label><br>\n";

	print "<fieldset id=weekly class=shown>\n";
	print "<legend>Repeating Weekly</legend>\n";
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH>Day</TH>\n";
	print "    <TH>Time</TH>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	foreach($days as $day) {
		print "      <INPUT type=checkbox name=wdays[] value=$day {$data['wdayschecked'][$day]}>$day<br>\n";
	}
	printSubmitErr(STARTDAYERR);
	print "    </TD>\n";
	print "    <TD valign=top>\n";
	print "    <table summary=\"\">\n";
	print "      <TR>\n";
	print "        <TH>Start</TH>\n";
	print "        <TD></TD>\n";
	print "        <TH>End</TH>\n";
	print "      </TR>\n";
	for($i = 0; $i < 4; $i++) {
		if(count($data['swhour']) < 4) {
			$data['swhour'][$i] = 1;
			$data['swminute'][$i] = "zero";
			$data['swmeridian'][$i] = "am";
			$data['ewhour'][$i] = 1;
			$data['ewminute'][$i] = "zero";
			$data['ewmeridian'][$i] = "am";
		}
		print "      <TR>\n";
		print "        <TD nowrap>\n";
		print "          Slot" . ($i + 1) . ":\n";
		printBlockStartEnd($i, 'w', $data['swhour'],
		                   $data['swminute'],
		                   $data['swmeridian'],
		                   $data['ewhour'],
		                   $data['ewminute'],
		                   $data['ewmeridian']);
		print "        </TD>\n";
		print "        <TD>\n";
		if($data['available'] == 'weekly') {
			printSubmitErr(STARTHOURERR, $i);
			printSubmitErr(ENDHOURERR, $i);
		}
		print "        </TD>\n";
		print "      </TR>\n";
	}
	print "    </table>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH>Starting date:</TH>\n";
	print "    <TD><INPUT type=text name=swdate size=10 maxlength=8 value=\"{$data['swdate']}\"></TD>\n";
	print "    <TD><small>(mm/dd/yy) </small>";
	if($data['available'] == 'weekly')
		printSubmitErr(STARTDATEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH>Ending date:</TH>\n";
	print "    <TD><INPUT type=text name=ewdate size=10 maxlength=8 value=\"{$data['ewdate']}\"></TD>\n";
	print "    <TD><small>(mm/dd/yy) </small>";
	if($data['available'] == 'weekly')
		printSubmitErr(ENDDATEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "</fieldset>\n";

	print "<fieldset id=monthly class=shown>\n";
	print "<legend>Repeating Monthly</legend>\n";
	$weeknumArr = array(1 => "1st",
	                    2 => "2nd",
	                    3 => "3rd",
	                    4 => "4th",
	                    5 => "5th");
	$dayArr = array(1 => "Sunday",
	                2 => "Monday",
	                3 => "Tuesday",
	                4 => "Wednesday",
	                5 => "Thursday",
	                6 => "Friday",
	                7 => "Saturday");
	printSelectInput('weeknum', $weeknumArr, $data['weeknum']);
	printSelectInput('day', $dayArr, $data['day']);
	print " of every month<br>\n";
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH>Start</TH>\n";
	print "    <TD></TD>\n";
	print "    <TH>End</TH>\n";
	print "  </TR>\n";
	for($i = 0; $i < 4; $i++) {
		if(count($data['smhour']) < 4) {
			$data['smhour'][$i] = 1;
			$data['smminute'][$i] = "zero";
			$data['smmeridian'][$i] = "am";
			$data['emhour'][$i] = 1;
			$data['emminute'][$i] = "zero";
			$data['emmeridian'][$i] = "am";
		}
		print "  <TR>\n";
		print "    <TD nowrap>\n";
		print "      Slot" . ($i + 1) . ":\n";
		printBlockStartEnd($i, 'm', $data['smhour'],
		                   $data['smminute'],
		                   $data['smmeridian'],
		                   $data['emhour'],
		                   $data['emmeridian'],
		                   $data['emmeridian']);
		print "    </TD>\n";
		print "    <TD>\n";
		if($data['available'] == 'monthly') {
			printSubmitErr(STARTHOURERR, $i);
			printSubmitErr(ENDHOURERR, $i);
		}
		print "    </TD>\n";
		print "  </TR>\n";
	}
	print "</table>\n";
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH>Starting date:</TH>\n";
	print "    <TD><INPUT type=text name=smdate size=10 value=\"{$data['smdate']}\"></TD>\n";
	print "    <TD><small>(mm/dd/yy) </small>";
	if($data['available'] == 'monthly')
		printSubmitErr(STARTDATEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH>Ending date:</TH>\n";
	print "    <TD><INPUT type=text name=emdate size=10 value=\"{$data['emdate']}\"></TD>\n";
	print "    <TD><small>(mm/dd/yy) </small>\n";
	if($data['available'] == 'monthly')
		printSubmitErr(ENDDATEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "</fieldset>\n";

	print "<fieldset id=list class=shown>\n";
	print "<legend>List of dates/times</legend>\n";
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH nowrap>Date <small>(mm/dd/yy)</small></TH>\n";
	print "    <TH>Start</TH>\n";
	print "    <TD></TD>\n";
	print "    <TH>End</TH>\n";
	print "  </TR>\n";
	for($i = 0; $i < 4; $i++) {
		if(count($data['slhour']) < 4) {
			$data['slhour'][$i] = 1;
			$data['slminute'][$i] = "zero";
			$data['slmeridian'][$i] = "am";
			$data['elhour'][$i] = 1;
			$data['elminute'][$i] = "zero";
			$data['elmeridian'][$i] = "am";
			$data['date'][$i] = "";
		}
		print "  <TR>\n";
		$slot = $i + 1;
		print "    <TD nowrap>Slot $slot:<INPUT type=text name=date[] size=10 value={$data['date'][$i]}></TD>\n";
		print "    <TD nowrap>\n";
		printBlockStartEnd($i, 'l', $data['slhour'],
		                   $data['slminute'],
		                   $data['slmeridian'],
		                   $data['elhour'],
		                   $data['elminute'],
		                   $data['elmeridian']);
		print "    </TD>\n";
		print "    <TD>\n";
		if($data['available'] == 'list') {
			printSubmitErr(STARTDATEERR, $i);
			printSubmitErr(STARTHOURERR, $i);
			printSubmitErr(ENDHOURERR, $i);
		}
		print "    </TD>\n";
		print "  </TR>\n";
	}
	print "</table>\n";
	print "</fieldset>\n";

	$cdata = array('state' => $data['state'],
	               'blockRequestid' => $data['blockRequestid']);
	$cont = addContinuationsEntry('confirmBlockRequest', $cdata, SECINDAY, 0, 1, 1);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=Confirm>\n";
	print "</FORM>\n";
	printBlockRequestJavascript($data['available']);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectEditBlockRequest()
///
/// \brief prints a page with summary info on each block request allowing one
/// to be select for editing
///
////////////////////////////////////////////////////////////////////////////////
function selectEditBlockRequest() {
	global $user, $days;
	$groups = getUserEditGroups($user['id']);
	$groupids = implode(',', array_keys($groups));
	$query = "SELECT b.id, "
	       .        "b.name AS blockname, "
	       .        "b.imageid, "
	       .        "i.prettyname AS image, "
	       .        "b.numMachines AS machinecnt, "
	       .        "b.groupid as usergroupid, "
	       .        "CONCAT(g.name, '@', a.name) AS `group`, "
	       .        "b.admingroupid as admingroupid, "
	       .        "CONCAT(ga.name, '@', aa.name) AS `admingroup`, "
	       .        "b.repeating AS available "
	       . "FROM image i, "
	       .      "usergroup g, "
	       .      "affiliation a, "
	       .      "blockRequest b "
	       . "LEFT JOIN usergroup ga ON (b.admingroupid = ga.id) "
	       . "LEFT JOIN affiliation aa ON (ga.affiliationid = aa.id) "
	       . "WHERE (b.ownerid = {$user['id']} ";
	if(! empty($groupids))
		$query .=   "OR b.admingroupid IN ($groupids) ";
	$query .=      ") AND b.imageid = i.id AND "
	       .       "b.groupid = g.id AND "
	       .       "g.affiliationid = a.id "
	       . "ORDER BY b.name";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		$blockrequest[$row['id']] = $row;
		$query2 = "SELECT DATE_FORMAT(start, '%c/%e/%y<br>%l:%i %p') AS start1 "
		        . "FROM blockTimes "
		        . "WHERE blockRequestid = {$row['id']} "
		        . "ORDER BY start "
		        . "LIMIT 1";
		$qh2 = doQuery($query2, 101);
		if($row2 = mysql_fetch_assoc($qh2))
			$blockrequest[$row['id']]['nextstart'] = $row2['start1'];
		else
			$blockrequest[$row['id']]['nextstart'] = "none found";
	}
	print "<h2>Edit Block Reservation</h2>\n";
	if(empty($blockrequest)) {
		print "There are currently no block reservations.<br>\n";
		return;
	}
	foreach($blockrequest as $id => $request) {
		if($request['available'] == 'weekly') {
			$query = "SELECT DATE_FORMAT(start, '%m/%d/%y') AS swdate, "
			       .        "DATE_FORMAT(end, '%m/%d/%y')AS ewdate, " 
			       .        "days "
			       . "FROM blockWebDate "
			       . "WHERE blockRequestid = $id";
			$qh = doQuery($query, 101);
			if(! $row = mysql_fetch_assoc($qh))
				abort(101);
			$blockrequest[$id] = array_merge($request, $row);
			$wdays = array();
			for($i = 0; $i < 7; $i++) {
				if($row['days'] & (1 << $i))
					array_push($wdays, $days[$i]);
			}
			unset($blockrequest[$id]['days']);
			$blockrequest[$id]['wdays'] = $wdays;
			$query = "SELECT starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order` "
			       . "FROM blockWebTime "
			       . "WHERE blockRequestid = {$request['id']}";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$blockrequest[$id]['swhour'][$row['order']] = $row['starthour'];
				$blockrequest[$id]['swminute'][$row['order']] = $row['startminute'];
				$blockrequest[$id]['swmeridian'][$row['order']] = $row['startmeridian'];
				$blockrequest[$id]['ewhour'][$row['order']] = $row['endhour'];
				$blockrequest[$id]['ewminute'][$row['order']] = $row['endminute'];
				$blockrequest[$id]['ewmeridian'][$row['order']] = $row['endmeridian'];
			}
		}
		elseif($request['available'] == 'monthly') {
			$query = "SELECT DATE_FORMAT(start, '%m/%d/%y') AS smdate, "
			       .        "DATE_FORMAT(end, '%m/%d/%y')AS emdate, " 
			       .        "days AS day, "
			       .        "weeknum "
			       . "FROM blockWebDate "
			       . "WHERE blockRequestid = $id";
			$qh = doQuery($query, 101);
			if(! $row = mysql_fetch_assoc($qh))
				abort(101);
			$blockrequest[$id] = array_merge($request, $row);
			$query = "SELECT starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order` "
			       . "FROM blockWebTime "
			       . "WHERE blockRequestid = {$request['id']}";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$blockrequest[$id]['smhour'][$row['order']] = $row['starthour'];
				$blockrequest[$id]['smminute'][$row['order']] = $row['startminute'];
				$blockrequest[$id]['smmeridian'][$row['order']] = $row['startmeridian'];
				$blockrequest[$id]['emhour'][$row['order']] = $row['endhour'];
				$blockrequest[$id]['emminute'][$row['order']] = $row['endminute'];
				$blockrequest[$id]['emmeridian'][$row['order']] = $row['endmeridian'];
			}
		}
		elseif($request['available'] == 'list') {
			$query = "SELECT DATE_FORMAT(start, '%m/%d/%y') AS date, "
			       #.        "DATE_FORMAT(end, '%m/%d/%y')AS ewdate, " 
			       .        "days AS `order` "
			       . "FROM blockWebDate "
			       . "WHERE blockRequestid = $id";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				if($row['date'] == '00/00/00')
					$blockrequest[$id]['date'][$row['order']] = '';
				else
					$blockrequest[$id]['date'][$row['order']] = $row['date'];
			}
			$query = "SELECT starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order` "
			       . "FROM blockWebTime "
			       . "WHERE blockRequestid = {$request['id']}";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$blockrequest[$id]['slhour'][$row['order']] = $row['starthour'];
				$blockrequest[$id]['slminute'][$row['order']] = $row['startminute'];
				$blockrequest[$id]['slmeridian'][$row['order']] = $row['startmeridian'];
				$blockrequest[$id]['elhour'][$row['order']] = $row['endhour'];
				$blockrequest[$id]['elminute'][$row['order']] = $row['endminute'];
				$blockrequest[$id]['elmeridian'][$row['order']] = $row['endmeridian'];
			}
		}
	}
	print "Select a block reservation to edit:<br>\n";
	print "<table summary=\"lists current block reservations\">\n";
	print "  <TR align=center>\n";
	print "    <TD colspan=2></TD>\n";
	print "    <TH>Name</TH>\n";
	print "    <TH>Image</TH>\n";
	print "    <TH>Reserved<br>Machines</TH>\n";
	print "    <TH>Reserved<br>For</TH>\n";
	print "    <TH>Manageable<br>By</TH>\n";
	print "    <TH>Repeating</TH>\n";
	print "    <TH>Next Start Time</TH>\n";
	print "  </TR>\n";
	foreach($blockrequest as $request) {
		print "  <TR align=center>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "      <INPUT type=submit value=Edit>\n";
		$cdata = $request;
		$cdata['state'] = 1; # 1 = edit
		$cdata['blockRequestid'] = $request['id'];
		$cont = addContinuationsEntry('newBlockRequest', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "      <INPUT type=submit value=Delete>\n";
		$cdata = $request;
		$cdata['state'] = 2; # 2 = delete
		$cdata['blockRequestid'] = $request['id'];
		$cont = addContinuationsEntry('confirmBlockRequest', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD>{$request['blockname']}</TD>\n";
		print "    <TD>{$request['image']}</TD>\n";
		print "    <TD>{$request['machinecnt']}</TD>\n";
		print "    <TD>{$request['group']}</TD>\n";
		if(empty($request['admingroup']))
			print "    <TD>None (owner only)</TD>\n";
		else
			print "    <TD>{$request['admingroup']}</TD>\n";
		print "    <TD>{$request['available']}</TD>\n";
		print "    <TD>{$request['nextstart']}</TD>\n";
		print "  </TR>\n";
	}
	print "</table>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmBlockRequest()
///
/// \brief prints a confirmation page displaying information on submitted block
/// request
///
////////////////////////////////////////////////////////////////////////////////
function confirmBlockRequest() {
	global $submitErr, $user, $days, $mode;
	$data = processBlockRequestInput();
	if($submitErr) {
		newBlockRequest();
		return;
	}
	$images = getImages();
	// FIXME should we limit the course groups that show up?
	$groups = getUserGroups(0, $user['affiliationid']);
	if(! array_key_exists($data['usergroupid'], $groups))
		$groups[$data['usergroupid']] =
		      array('name' => getUserGroupName($data['usergroupid'], 1));
	if(! array_key_exists($data['admingroupid'], $groups))
		$groups[$data['admingroupid']] =
		      array('name' => getUserGroupName($data['admingroupid'], 1));
	$groups[0] = array('name' => 'None (owner only)');
	if($data['state'] == 2) {
		print "<H2>Delete Block Reservation</H2>\n";
		print "Delete the following block reservation?<br>\n";
	}
	elseif($data['state'] == 1) {
		print "<H2>Edit Block Reservation</H2>\n";
		print "Modify the following block reservation?<br>\n";
	}
	else {
		print "<H2>New Block Reservation</H2>\n";
		print "Create the following block reservation?<br>\n";
	}
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Name:</TH>\n";
	print "    <TD>{$data['blockname']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Image:</TH>\n";
	print "    <TD>{$images[$data['imageid']]['prettyname']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Reserved Machines:</TH>\n";
	print "    <TD>{$data['machinecnt']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Reserved for:</TH>\n";
	print "    <TD>{$groups[$data['usergroupid']]['name']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right nowrap>Manageable by:</TH>\n";
	print "    <TD>{$groups[$data['admingroupid']]['name']}</TD>\n";
	print "  </TR>\n";
	if($data['available'] == 'weekly') {
		print "  <TR>\n";
		print "    <TH align=right nowrap>Repeating:</TH>\n";
		print "    <TD>Weekly</TD>\n";
		print "  </TR>\n";
		print "  <TR valign='top'>\n";
		print "    <TH valign='top' align=right nowrap>On these days:</TH>\n";
		print "    <TD>";
		foreach($data['wdays'] as $day) {
			print "$day<br>";
		}
		print "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>For these timeslots on<br>each of the above days:</TH>\n";
		print "    <TD>";
		for($i = 0; $i < 4; $i++) {
			if($data['stime'][$i] == $data['etime'][$i])
				continue;
			if($data['swminute'][$i] == 0)
				$data['swminute'][$i] = "00";
			if($data['ewminute'][$i] == 0)
				$data['ewminute'][$i] = "00";
			print "{$data['swhour'][$i]}:{$data['swminute'][$i]} {$data['swmeridian'][$i]} - ";
			print "{$data['ewhour'][$i]}:{$data['ewminute'][$i]} {$data['ewmeridian'][$i]}<br>\n";
		}
		print "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right nowrap>Starting:</TH>\n";
		print "    <TD>{$data['swdate']}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right nowrap>Ending:</TH>\n";
		print "    <TD>{$data['ewdate']}</TD>\n";
		print "  </TR>\n";
	}
	elseif($data['available'] == 'monthly') {
		$weeknumArr = array(1 => "1st",
		                    2 => "2nd",
		                    3 => "3rd",
		                    4 => "4th",
		                    5 => "5th");
		print "  <TR>\n";
		print "    <TH align=right nowrap>Repeating:</TH>\n";
		print "    <TD>The {$weeknumArr[$data['weeknum']]} {$days[$data['day'] - 1]} of each month</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>For these timeslots on<br>the above day of the month:</TH>\n";
		print "    <TD>";
		for($i = 0; $i < 4; $i++) {
			if($data['stime'][$i] == $data['etime'][$i])
				continue;
			if($data['smminute'][$i] == 0)
				$data['smminute'][$i] = "00";
			if($data['emminute'][$i] == 0)
				$data['emminute'][$i] = "00";
			print "{$data['smhour'][$i]}:{$data['smminute'][$i]} {$data['smmeridian'][$i]} - ";
			print "{$data['emhour'][$i]}:{$data['emminute'][$i]} {$data['emmeridian'][$i]}<br>\n";
		}
		print "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right nowrap>Starting:</TH>\n";
		print "    <TD>{$data['smdate']}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right nowrap>Ending:</TH>\n";
		print "    <TD>{$data['emdate']}</TD>\n";
		print "  </TR>\n";
	}
	elseif($data['available'] == 'list') {
		print "  <TR valign=top>\n";
		print "    <TH align=right>For the following dates and times:</TH>\n";
		print "    <TD>\n";
		for($i = 0; $i < 4; $i++) {
			if($data['slhour'][$i] == $data['elhour'][$i] &&
			   $data['slminute'][$i] == $data['elminute'][$i] &&
			   $data['slmeridian'][$i] == $data['elmeridian'][$i])
				continue;
			if($data['slminute'][$i] == 0)
				$data['slminute'][$i] = '00';
			if($data['elminute'][$i] == 0)
				$data['elminute'][$i] = '00';
			print "{$data['date'][$i]} {$data['slhour'][$i]}:{$data['slminute'][$i]} {$data['slmeridian'][$i]} to {$data['elhour'][$i]}:{$data['elminute'][$i]} {$data['elmeridian'][$i]}<br>\n";
		}
		print "    </TD>\n";
		print "  </TR>\n";
	}
	print "</table>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	if($data['state'] == 2) {
		print "<INPUT type=submit value=Delete>\n";
		$cont = addContinuationsEntry('submitDeleteBlockRequest', $data, SECINDAY, 0, 0);
	}
	else {
		print "<INPUT type=submit value=Submit>\n";
		$cont = addContinuationsEntry('submitBlockRequest', $data, SECINDAY, 0, 0);
	}
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitBlockRequest()
///
/// \brief processes submitted block request information
///
////////////////////////////////////////////////////////////////////////////////
function submitBlockRequest() {
	global $submitErr, $user, $days;
	$data = processBlockRequestInput();
	if($submitErr) {
		newBlockRequest();
		return;
	}

	# FIXME need to handle creation of a block time that we're currently in the
	#    middle of if there wasn't already on we're in the middle of
	if($data['state'] == 1) {
		# get blockTime entry for this request if we're in the middle of one
		$checkCurBlockTime = 0;
		$query = "SELECT id, "
		       .        "start, "
		       .        "end "
		       . "FROM blockTimes "
		       . "WHERE start <= NOW() AND "
		       .       "end > NOW() AND "
		       .       "blockRequestid = {$data['blockRequestid']}";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh)) {
			$checkCurBlockTime = 1;
			$curBlockTime = $row;
		}
		# delete entries from blockTimes that start later than now
		$query = "DELETE FROM blockTimes "
		       . "WHERE blockRequestid = {$data['blockRequestid']} AND "
		       .       "start > NOW()";
		doQuery($query, 101);
		# delete entries from blockWebDate and blockWebTime
		$query = "DELETE FROM blockWebDate WHERE blockRequestid = {$data['blockRequestid']}";
		doQuery($query, 101);
		$query = "DELETE FROM blockWebTime WHERE blockRequestid = {$data['blockRequestid']}";
		doQuery($query, 101);
	}

	if($data['available'] == 'weekly') {
		$daymask = 0;
		$startarr = split('/', $data['swdate']);
		$startdate = "20{$startarr[2]}-{$startarr[0]}-{$startarr[1]}";
		$startts = datetimeToUnix("20{$startarr[2]}-{$startarr[0]}-{$startarr[1]} 00:00:00");
		$endarr = split('/', $data['ewdate']);
		$enddt = "20{$endarr[2]}-{$endarr[0]}-{$endarr[1]} 23:59:59";
		$enddate = "20{$endarr[2]}-{$endarr[0]}-{$endarr[1]}";
		$endts = datetimeToUnix($enddt);
		foreach($data['wdays'] as $day) {
			$key = array_search($day, $days);
			$daymask |= (1 << $key);
		}
	}
	elseif($data['available'] == 'monthly') {
		$startarr = split('/', $data['smdate']);
		$startdate = "20{$startarr[2]}-{$startarr[0]}-{$startarr[1]}";
		$startts = datetimeToUnix("20{$startarr[2]}-{$startarr[0]}-{$startarr[1]} 00:00:00");
		$endarr = split('/', $data['emdate']);
		$enddt = "20{$endarr[2]}-{$endarr[0]}-{$endarr[1]} 23:59:59";
		$enddate = "20{$endarr[2]}-{$endarr[0]}-{$endarr[1]}";
		$endts = datetimeToUnix($enddt);
		$selectedday = $data['day'];
	}
	elseif($data['available'] == 'list') {
		$last = -1;
		$enddtArr[-1] = '1970-01-01 00:00:00';
		for($i = 0; $i < 4; $i++) {
			$data['slhour24'][$i] = hour12to24($data['slhour'][$i], $data['slmeridian'][$i]);
			$data['elhour24'][$i] = hour12to24($data['elhour'][$i], $data['elmeridian'][$i]);
			if(empty($data['date'][$i])) {
				$startdtArr[$i] = "0000-00-00 00:00:00";
				$enddtArr[$i] = "0000-00-00 00:00:00";
			}
			else {
				$datearr = explode('/', $data['date'][$i]);
				$startdtArr[$i] = "20{$datearr[2]}-{$datearr[0]}-{$datearr[1]} {$data['slhour24'][$i]}:{$data['slminute'][$i]}:00";
				$enddtArr[$i] = "20{$datearr[2]}-{$datearr[0]}-{$datearr[1]} {$data['elhour24'][$i]}:{$data['elminute'][$i]}:00";
			}
			if($data['stime'][$i] == $data['etime'][$i])
				continue;
			if($startdtArr[$i] != $enddtArr[$i] &&
			   datetimeToUnix($enddtArr[$last]) < datetimeToUnix($enddtArr[$i])) {
				$last = $i;
			}
		}
		unset($enddtArr[-1]);
		$endts = datetimeToUnix($enddtArr[$last]);
		$enddt = $enddtArr[$last];
	}

	if($data['state'] == 1) {
		$query = "UPDATE blockRequest "
		       . "SET name = '{$data['blockname']}', " 
		       .     "imageid = {$data['imageid']}, "
		       .     "numMachines = {$data['machinecnt']}, "
		       .     "groupid = {$data['usergroupid']}, "
		       .     "admingroupid = {$data['admingroupid']}, "
		       .     "repeating = '{$data['available']}', "
		       .     "expireTime = '$enddt' "
		       . "WHERE  id = {$data['blockRequestid']}";
		doQuery($query, 101);
		$blockreqid = $data['blockRequestid'];
	}
	else {
		$managementnodes = getManagementNodes('future');
		if(empty($managementnodes))
			abort(40);
		$mnid = array_rand($managementnodes);
		$query = "INSERT INTO blockRequest "
		       .        "(name, "
		       .        "imageid, "
		       .        "numMachines, "
		       .        "groupid, "
		       .        "repeating, "
		       .        "ownerid, "
		       .        "admingroupid, "
		       .        "managementnodeid, "
		       .        "expireTime) "
		       . "VALUES "
		       .        "('{$data['blockname']}', "
		       .        "{$data['imageid']}, "
		       .        "{$data['machinecnt']}, "
		       .        "{$data['usergroupid']}, "
		       .        "'{$data['available']}', "
		       .        "{$user['id']}, "
		       .        "{$data['admingroupid']}, "
		       .        "$mnid, "
		       .        "'$enddt')";
		doQuery($query, 101);
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM blockRequest", 101);
		if(! $row = mysql_fetch_row($qh)) {
			abort(380);
		}
		$blockreqid = $row[0];
	}

	if($data['available'] == 'weekly') {
		$query = "INSERT INTO blockWebDate "
		       .        "(blockRequestid, "
		       .        "start, "
		       .        "end, "
		       .        "days) "
		       . "VALUES "
		       .        "($blockreqid, "
		       .        "'$startdate', "
		       .        "'$enddate', "
		       .        "$daymask)";
		doQuery($query, 101);
		for($i = 0; $i < 4; $i++) {
			$query = "INSERT INTO blockWebTime "
			       .        "(blockRequestid, "
			       .        "starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order`) "
			       . "VALUES "
			       .        "($blockreqid, "
			       .        "'{$data['swhour'][$i]}', "
			       .        "'{$data['swminute'][$i]}', "
			       .        "'{$data['swmeridian'][$i]}', "
			       .        "'{$data['ewhour'][$i]}', "
			       .        "'{$data['ewminute'][$i]}', "
			       .        "'{$data['ewmeridian'][$i]}', "
			       .        "$i)";
			doQuery($query, 101);
		}
		for($day = $startts; $day <= $endts; $day += SECINDAY) {
			if(! in_array(date('l', $day), $data['wdays']))
				continue;
			for($i = 0; $i < 4; $i++) {
				if($data['stime'][$i] == $data['etime'][$i])
					continue;
				$data['swhour'][$i] = hour12to24($data['swhour'][$i], $data['swmeridian'][$i]);
				$data['ewhour'][$i] = hour12to24($data['ewhour'][$i], $data['ewmeridian'][$i]);
				$start = date("Y-m-d", $day) . " {$data['swhour'][$i]}:{$data['swminute'][$i]}:00";
				$end = date("Y-m-d", $day) . " {$data['ewhour'][$i]}:{$data['ewminute'][$i]}:00";
				$query = "INSERT INTO blockTimes "
				       .        "(blockRequestid, "
				       .        "start, "
				       .        "end) "
				       . "VALUES "
				       .        "($blockreqid, "
				       .        "'$start', "
				       .        "'$end')";
				doQuery($query, 101);
			}
		}
	}
	elseif($data['available'] == 'monthly') {
		$query = "INSERT INTO blockWebDate "
		       .        "(blockRequestid, "
		       .        "start, "
		       .        "end, "
		       .        "days, "
		       .        "weeknum) "
		       . "VALUES "
		       .        "($blockreqid, "
		       .        "'$startdate', "
		       .        "'$enddate', "
		       .        "$selectedday, "
		       .        "{$data['weeknum']})";
		doQuery($query, 101);
		for($i = 0; $i < 4; $i++) {
			$query = "INSERT INTO blockWebTime "
			       .        "(blockRequestid, "
			       .        "starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order`) "
			       . "VALUES "
			       .        "($blockreqid, "
			       .        "'{$data['smhour'][$i]}', "
			       .        "'{$data['smminute'][$i]}', "
			       .        "'{$data['smmeridian'][$i]}', "
			       .        "'{$data['emhour'][$i]}', "
			       .        "'{$data['emminute'][$i]}', "
			       .        "'{$data['emmeridian'][$i]}', "
			       .        "$i)";
			doQuery($query, 101);
		}
		for($day = $startts; $day <= $endts; $day += SECINDAY) {
			if((date('w', $day) + 1) != $data['day'])
				continue;
			$dayofmon = date('j', $day);
			if(($data['weeknum'] == 1 && ($dayofmon < 8)) ||
			   ($data['weeknum'] == 2 && (7 < $dayofmon) && ($dayofmon < 15)) ||
			   ($data['weeknum'] == 3 && (14 < $dayofmon) && ($dayofmon < 22)) ||
			   ($data['weeknum'] == 4 && (21 < $dayofmon) && ($dayofmon < 29)) ||
			   ($data['weeknum'] == 5 && (28 < $dayofmon) && ($dayofmon < 32))) {
				$thedate = date("Y-m-d", $day);
				for($i = 0; $i < 4; $i++) {
					if($data['stime'][$i] == $data['etime'][$i])
						continue;
					$data['smhour'][$i] = hour12to24($data['smhour'][$i], $data['smmeridian'][$i]);
					$data['emhour'][$i] = hour12to24($data['emhour'][$i], $data['emmeridian'][$i]);
					$start = "$thedate {$data['smhour'][$i]}:{$data['smminute'][$i]}:00";
					$end = "$thedate {$data['emhour'][$i]}:{$data['emminute'][$i]}:00";
					$query = "INSERT INTO blockTimes "
							 .        "(blockRequestid, "
							 .        "start, "
							 .        "end) "
							 . "VALUES "
							 .        "($blockreqid, "
							 .        "'$start', "
							 .        "'$end')";
					doQuery($query, 101);
				}
			}
		}
	}
	elseif($data['available'] == 'list') {
		for($i = 0; $i < 4; $i++) {
			$query = "INSERT INTO blockWebDate "
			       .        "(blockRequestid, "
			       .        "start, "
			       .        "end, "
			       .        "days) "
			       . "VALUES "
			       .        "($blockreqid, "
					 .        "'{$startdtArr[$i]}', "
					 .        "'{$enddtArr[$i]}', "
			       .        "$i)";
			doQuery($query, 101);
			$query = "INSERT INTO blockWebTime "
			       .        "(blockRequestid, "
			       .        "starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order`) "
			       . "VALUES "
			       .        "($blockreqid, "
			       .        "'{$data['slhour'][$i]}', "
			       .        "'{$data['slminute'][$i]}', "
			       .        "'{$data['slmeridian'][$i]}', "
			       .        "'{$data['elhour'][$i]}', "
			       .        "'{$data['elminute'][$i]}', "
			       .        "'{$data['elmeridian'][$i]}', "
			       .        "$i)";
			doQuery($query, 101);
			if($data['stime'][$i] == $data['etime'][$i])
				continue;
			$query = "INSERT INTO blockTimes "
					 .        "(blockRequestid, "
					 .        "start, "
					 .        "end) "
					 . "VALUES "
					 .        "($blockreqid, "
					 .        "'{$startdtArr[$i]}', "
					 .        "'{$enddtArr[$i]}')";
			doQuery($query, 101);
		}
	}
	if($data['state'] == 1) {
		if($checkCurBlockTime) {
			$query = "SELECT id, "
			       .        "start, "
			       .        "end "
			       . "FROM blockTimes "
			       . "WHERE start <= NOW() AND "
			       .       "end > NOW() AND "
			       .       "blockRequestid = {$data['blockRequestid']} AND "
			       .       "id != {$curBlockTime['id']}";
			$qh = doQuery($query, 101);
			if($row = mysql_fetch_assoc($qh)) {
				if($curBlockTime['end'] != $row['end']) {
					# update old end time
					$query = "UPDATE blockTimes "
					       . "SET end = '{$row['end']}' " 
					       . "WHERE id = {$curBlockTime['id']}";
					doQuery($query, 101);
				}
				# delete $row entry
				doQuery("DELETE FROM blockTimes WHERE id = {$row['id']}", 101);
			}
			else {
				# the blockTime we were in the middle of was not recreated, so
				#    delete the old one
				doQuery("DELETE FROM blockTimes WHERE id = {$curBlockTime['id']}", 101);
			}
		}
		print "<H2>Edit Block Reservation</H2>\n";
		print "Block request has been updated<br>\n";
	}
	else {
		print "<H2>New Block Reservation</H2>\n";
		print "Block request added to database<br>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteBlockRequest()
///
/// \brief delete a block request
///
////////////////////////////////////////////////////////////////////////////////
function submitDeleteBlockRequest() {
	$data = processBlockRequestInput();
	$query = "DELETE FROM blockRequest WHERE id = {$data['blockRequestid']}";
	doQuery($query, 101);
	print "<H2>Delete Block Reservation</H2>\n";
	print "Block reservation <strong>{$data['blockname']}</strong> has been deleted.<br>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printBlockStartEnd($cnt, $type, $shour, $sminute, $smeridian, $ehour,
///                        $eminute, $emeridian)
///
/// \param $cnt - index number for row
/// \param $type - 'w', 'm', or 'l' to signify week, month, or list
/// \param $shour - array of input data
/// \param $sminute - array of input data
/// \param $smeridian - array of input data
/// \param $ehour - array of input data
/// \param $eminute - array of input data
/// \param $emeridian - array of input data
///
/// \brief prints 4 rows of select boxes for start and end times
///
////////////////////////////////////////////////////////////////////////////////
function printBlockStartEnd($cnt, $type, $shour, $sminute, $smeridian, $ehour, $eminute, $emeridian) {
	$hrArr = array();
	for($i = 1; $i < 13; $i++) {
		$hrArr[$i] = $i;
	}
	$minutes = array("zero" => "00",
	                 "15" => "15",
	                 "30" => "30", 
	                 "45" => "45");
	$t_shour = 's' . $type . 'hour[]';
	$t_sminute = 's' . $type . 'minute[]';
	$t_smeridian = 's' . $type . 'meridian[]';
	$t_ehour = 'e' . $type . 'hour[]';
	$t_eminute = 'e' . $type . 'minute[]';
	$t_emeridian = 'e' . $type . 'meridian[]';
	printSelectInput($t_shour, $hrArr, $shour[$cnt]);
	printSelectInput($t_sminute, $minutes, $sminute[$cnt]);
	printSelectInput($t_smeridian, array("am" => "am", "pm" => "pm"), $smeridian[$cnt]);
	print "        </TD>\n";
	print "        <TD nowrap width=5px></TD>\n";
	print "        <TD nowrap>\n";
	printSelectInput($t_ehour, $hrArr, $ehour[$cnt]);
	printSelectInput($t_eminute, $minutes, $eminute[$cnt]);
	printSelectInput($t_emeridian, array("am" => "am", "pm" => "pm"), $emeridian[$cnt]);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printBlockRequestJavascript($show)
///
/// \param $show - 'weekly', 'monthly', or 'list'
///
/// \brief prints javascript to display the right frameset
///
////////////////////////////////////////////////////////////////////////////////
function printBlockRequestJavascript($show) {
	print <<<HTMLdone
<script language="Javascript">
function show(id) {
	document.getElementById("weekly").className = "hidden";
	document.getElementById("monthly").className = "hidden";
	document.getElementById("list").className = "hidden";
	document.getElementById(id).className = "shown";
}
HTMLdone;
print "show(\"$show\")\n";
print "</script>\n";

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
					$text .= "return false;\" href=\"#\">Pending...</a></i></span>";
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
			$text .= "<div dojoType=FloatingPane\n";
			$text .= "      id=resStatusPane\n";
			$text .= "      constrainToContainer=false\n";
			$text .= "      hasShadow=true\n";
			$text .= "      resizable=true\n";
			$text .= "      windowState=minimized\n";
			$text .= "      displayMinimizeAction=true\n";
			$text .= "      style=\"width: 350px; height: 280px; position: absolute; left: 130; top: 0px;\"\n";
			$text .= ">\n";
			$text .= "<div id=resStatusText></div>\n";
			$text .= "<input type=hidden id=detailreqid value=0>\n";
			$text .= "</div>\n";
			$text .= "<script type=\"text/javascript\">\n";
			$text .= "dojo.addOnLoad(showScriptOnly);\n";
			$text .= "dojo.byId('resStatusPane').title = \"Detailed Reservation Status\";\n";
			$text .= "</script>\n";
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
			. "has already taken\">";
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
	$userinfo = getUserInfo($request["userid"]);
	print "<DIV align=center>\n";
	print "<H2>View Reservation</H2>\n";
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH align=right>Unity&nbsp;ID:</TH>\n";
	print "    <TD>" . $userinfo["unityid"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Requested&nbsp;Image:</TH>\n";
	print "    <TD>{$reservation['prettyimage']}</TD>\n";
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
	foreach($request["reservations"] as $res) {
		print "  <TR>\n";
		print "    <TH align=right>Computer&nbsp;ID:</TH>\n";
		print "    <TD>" . $res["computerid"] . "</TD>\n";
		print "  </TR>\n";
	}
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
	print "</table>\n";
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
	$cdata = array('requestid' => $requestid);
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
	$maxtimes = getUserMaxTimes("initialmaxtime");
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
				return;
			}
			$timeToNext = timeToNextReservation($request);
		}
		$started = 1;
		print "Because this reservation has already started, you can only ";
		print "extend the length of the reservation. ";
		if(! $openend) {
			print "If there are no reservations following yours, ";
			print "you can extend your reservation ";
			print "by up to " . minToHourMin($maxtimes["extend"]) . ", but not ";
			print "exceeding " . minToHourMin($maxtimes["total"]) . " for your ";
			print "total reservation time.<br><br>\n";
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
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		printReserveItems(1, $startArr[0], $startArr[1], $startArr[2], $startArr[3], $len, 1);
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
/// \fn adminEditRequest()
///
/// \brief prints a page for an admin to edit a user's request
///
////////////////////////////////////////////////////////////////////////////////
/*function adminEditRequest() {
	$requestid = processInputVar("requestid", ARG_NUMERIC);
	$request = getRequestInfo($requestid);
	foreach($request["reservations"] as $res) {
		if($res["forcheckout"]) {
			$reservation = $res;
			break;
		}
	}
	$userinfo = getUserInfo($request["userid"]);
	$images = getImages();
	$unixstart = datetimeToUnix($request["start"]);
	print "<H2>Modify Reservation</H2>\n";
	if($unixstart > time()) {
		$started = 0;
	}
	else {
		$started = 1;
		print "Because this reservation has already started, you can only ";
		print "modify the end time of the reservation.  You will only be able ";
		print "to extend the length if the computer the reservation is on ";
		print "has time available before the next reservation.<br><br>\n";
	}
	$start = date('n/j/y,g,i,a', datetimeToUnix($request["start"]));
	$startArr = explode(',', $start);

	$end = date('n/j/y,g,i,a', datetimeToUnix($request["end"]));
	$endArr = explode(',', $end);

	print "Modify reservation for ";
	if(! empty($userinfo["preferredname"])) {
		print $userinfo["preferredname"] . " ";
	}
	else {
		print $userinfo["firstname"] . " ";
	}
	print $userinfo["lastname"] . " (" . $userinfo["unityid"] . "):<br>\n";
	print "<DIV align=center>\n";
	print "<table summary=\"\" cellpadding=0>\n";
	print "  <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$minArr = array("zero" => "00", 
						 "15" => "15",
						 "30" => "30",
						 "45" => "45");
	if(! $started) {
		print "  <TR>\n";
		print "    <TH align=right>Requested&nbsp;Image:</TH>\n";
		print "    <TD colspan=6>\n";
		printSelectInput("imageid", $images, $reservation["imageid"]);
		print "    </TD>\n";
		print "  </TR>\n";
		print "  <TR valign=middle>\n";
		print "    <TH align=right>Start Time:</TH>\n";
		print "    <TD>\n";
		print "      <INPUT type=text name=day maxlength=8 size=8 ";
		print "value=\"" . $startArr[0] . "\">\n";
		print "    </TD>\n";
		print "    <TD>\n";
		print "      <INPUT type=text name=hour maxlength=2 size=2 ";
		print "value=" . $startArr[1] . ">\n";
		print "    <TD>:</TD>\n";
		print "    </TD>\n";
		print "    <TD>\n";
		printSelectInput("minute", $minArr, $startArr[2]);
		print "    </TD>\n";
		print "    <TD>\n";
		printSelectInput("meridian", array("am" => "am", "pm" => "pm"), $startArr[3]);
		print "    </TD>\n";
		print "    <TD>\n";
		printSubmitErr(STARTDAYERR);
		printSubmitErr(STARTHOURERR);
		print "    </TD>\n";
		print "  </TR>\n";
	}
	print "  <TR valign=middle>\n";
	print "    <TH align=right>End Time:</TH>\n";
	print "    <TD><INPUT type=text name=endday maxlength=8 size=8 ";
	print "value=\"" . $endArr[0] . "\"></TD>\n";
	print "    <TD><INPUT type=text name=endhour maxlength=2 size=2 ";
	print "value=" . $endArr[1] . "></TD>\n";
	print "    <TD>:</TD>\n";
	print "    <TD>\n";
	printSelectInput("endminute", $minArr, $endArr[2]);
	print "    </TD>\n";
	print "    <TD>\n";
	printSelectInput("endmeridian", array("am" => "am", "pm" => "pm"), $endArr[3]);
	print "    </TD>\n";
	print "    <TD>\n";
	printSubmitErr(ENDDAYERR);
	printSubmitErr(ENDHOURERR);
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "<table summary=\"\">\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <INPUT type=hidden name=mode value=confirmAdminEditRequest>\n";
	print "      <INPUT type=hidden name=requestid value=$requestid>\n";
	print "      <INPUT type=hidden name=started value=$started>\n";
	print "      <INPUT type=submit value=\"Confirm Changes\">\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=pickTimeTable>\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "</DIV>\n";
}*/

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
	$cdata['prettyimage'] = $reservation['prettyimage'];
	$cdata['os'] = $reservation['OS'];
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
/// \fn confirmAdminEditRequest()
///
/// \brief prints a page confirming the changes the admin requested for the
/// request
///
////////////////////////////////////////////////////////////////////////////////
/*function confirmAdminEditRequest() {
	global $submitErr;

	$data = processRequestInput(1);
	if($submitErr) {
		adminEditRequest();
		return;
	}
	$request = getRequestInfo($data["requestid"]);
	$userinfo = getUserInfo($request["userid"]);
	$images = getImages();

	print "<H2>Modify Reservation</H2>\n";
	print "Change reservation for ";
	if(! empty($userinfo["preferredname"])) {
		print $userinfo["preferredname"] . " ";
	}
	else {
		print $userinfo["firstname"] . " ";
	}
	print $userinfo["lastname"] . " (" . $userinfo["unityid"] . "):<br>\n";
	print "<table summary=\"\">\n";
	if(! $data["started"]) {
		print "  <TR>\n";
		print "    <TH align=right>Image:</TH>\n";
		print "    <TD>" . $images[$data["imageid"]]["prettyname"] . "</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Start Time:</TH>\n";
		print "    <TD>" . $data["day"] . "&nbsp;" . $data["hour"] . ":";
		print $data["minute"] . "&nbsp;" . $data["meridian"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>End Time:</TH>\n";
	print "    <TD>" . $data["endday"] . "&nbsp;" . $data["endhour"] . ":";
	print $data["endminute"] . "&nbsp;" . $data["endmeridian"] . "</TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	print "<table summary=\"\">\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=submitAdminEditRequest>\n";
	printHiddenInputs($data);
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=pickTimeTable>\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
}*/

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
	$rc = isAvailable(getImages(), $data["imageid"], $start, $end, $data["os"], $data["requestid"]);
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
				$remaining = ($end - time()) / 60;
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
		print "The time you have requested is not available. You may ";
		print "<a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "view a timetable</a> of free and reserved times to find ";
		print "a time that will work for you.<br>\n";
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($end),
		                  unixToDatetime($start), NULL, NULL, 0);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAdminEditRequest()
///
/// \brief submits changes to a request and prints that it has been changed
///
////////////////////////////////////////////////////////////////////////////////
/*function submitAdminEditRequest() {
	$data = processRequestInput(0);
	$request = getRequestInfo($data["requestid"]);
	$userinfo = getUserInfo($request["userid"]);
	$images = getImages();

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

	$endhour = $data["endhour"];
	if($data["endhour"] == 12) {
		if($data["endmeridian"] == "am") {
			$endhour = 0;
		}
	}
	elseif($data["endmeridian"] == "pm") {
		$endhour = $data["endhour"] + 12;
	}

	$tmp = explode('/', $data["day"]);
	$start = mktime($hour, $data["minute"], "0", $tmp[0], $tmp[1], $tmp[2]);
	$tmp = explode('/', $data["endday"]);
	$end = mktime($endhour, $data["endminute"], "0", $tmp[0], $tmp[1], $tmp[2]);

	$rc = isAvailable($images, $data["imageid"], $start, $end, $data["os"], $data["requestid"]);
	if($rc == -1) {
		print "Modified reservation time is not available<br>\n";
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($end),
		                  unixToDatetime($start), NULL, NULL, 0);
	}
	elseif($rc > 0) {
		updateRequest($data["requestid"]);
		print "Change reservation for ";
		if(! empty($userinfo["preferredname"])) {
			print $userinfo["preferredname"] . " ";
		}
		else {
			print $userinfo["firstname"] . " ";
		}
		print $userinfo["lastname"] . " (" . $userinfo["unityid"] . "):<br>\n";
		print "Reservation for " . $userinfo["firstname"] . " ";
		print $userinfo["lastname"] . "(" . $userinfo["unityid"] . ") has ";
		print "been updated to start at " . unixToDatetime($start) . " and ";
		print "end at " . unixToDatetime($end) . " using image ";
		print $images[$data["imageid"]]["prettyname"] . "<br>\n";
	}
	else {
		print "Modified reservation time is not available<br>\n";
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($end),
		                  unixToDatetime($start), NULL, NULL, 0);
	}
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteRequest()
///
/// \brief prints a confirmation page about deleting a request
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteRequest() {
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
	if(datetimeToUnix($request["start"]) > time()) {
		$title = "Delete Reservation";
		$text = "Delete your reservation for <b>" . $reservation["prettyimage"]
		      . "</b> starting " . prettyDatetime($request["start"]) . "?<br>\n";
	}
	else {
		if(! $reservation["production"]) {
			confirmDeleteRequestProduction($request);
			return;
		}
		else {
			$title = "End Reservation";
			$text = "Are you finished with your reservation for <b>"
					. $reservation["prettyimage"] . "</b> that started ";
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
	$cdata = array('requestid' => $requestid);
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
		print "Your reservation for <b>" . $reservation["prettyimage"];
		print "</b> starting " . prettyDatetime($request["start"]);
		print " has been deleted.<br>\n";
	}
	else {
		print "<H2>End Reservation</H2>";
		print "Your reservation for <b>" . $reservation["prettyimage"];
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
/// \fn printReserveItems($modifystart, $day, $hour, $minute, 
///                                $meridian, $length, $oneline, $nolength)
///
/// \param $modifystart - (optional) 1 to print form for modifying start time, 
/// 0 not to
/// \param $day - (optional) initial day of week (Sunday - Saturday)
/// \param $hour - (optional) initial hour (1-12)
/// \param $minute - (optional) initial minute (00-59)
/// \param $meridian - (optional) initial meridian (am/pm)
/// \param $length - (optional) initial length (in minutes)
/// \param $oneline - (optional) print all items on one line
/// \param $nolength - (optional) 0 to print length, 1 not to
///
/// \brief prints reserve form data
///
////////////////////////////////////////////////////////////////////////////////
function printReserveItems($modifystart=1, $day=NULL, $hour=NULL, $minute=NULL, 
                          $meridian=NULL, $length=60, $oneline=0, $nolength=0) {
	global $user;
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
		print "<small>(Eastern Time Zone)</small>";
		//if(! $oneline)
			print "<br><br>";
		/*else
			print "&nbsp;&nbsp;";*/
		if(! $nolength) {
			if($openend) {
				print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=ending ";
				print "onclick='updateWaitTime(0);' value=length checked>";
			}
			print "Duration:&nbsp;\n";
		}
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
	$maxtimes = getUserMaxTimes("initialmaxtime");
	$lengths = array();
	if($maxtimes["initial"] >= 30)
		$lengths["30"] = "30 minutes";
	if($maxtimes["initial"] >= 60)
		$lengths["60"] = "1 hour";
	for($i = 120; $i <= $maxtimes["initial"]; $i += 120) {
		$lengths[$i] = $i / 60 . " hours";
	}

	if($nolength)
		print "Reservation will be for 8 hours<br>\n";
	else {
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
		if(eregi("windows", $osname)) {
			print "You will need to use a ";
			print "Remote Desktop program to connect to the ";
			print "system. If you did not click on the <b>Connect!</b> button from ";
			print "the computer you will be using to access the VCL system, you ";
			print "will need to cancel this reservation, request a new one, and ";
			print "make sure you click the <strong>Connect!</strong> button in ";
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
			$cdata = array('requestid' => $requestid);
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
			print "click on the <b>Connect!</b> button from the computer you will ";
			print "need to cancel this reservation, request a new one, and ";
			print "make sure you click the <strong>Connect!</strong> button in ";
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
			/*if(eregi("windows", $_SERVER["HTTP_USER_AGENT"])) {
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
			print "<LI><b>User ID</b>: " . $user['unityid'] . "</LI>\n";
			if(eregi("windows", $res["OS"])) {
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
				/*if(eregi("windows", $_SERVER["HTTP_USER_AGENT"])) {
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
/// \fn removeNoCheckout($images)
///
/// \param $images - an array of images
///
/// \return an array of images with the images that have forcheckout == 0
/// removed
///
/// \brief removes any images in $images that have forcheckout == 0
///
////////////////////////////////////////////////////////////////////////////////
function removeNoCheckout($images) {
	$allimages = getImages();
	foreach(array_keys($images) as $id) {
		if(array_key_exists($id, $allimages) && ! $allimages[$id]["forcheckout"])
			unset($images[$id]);
	}
	return $images;
}

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

	if(! $return["started"]) {
		$checkdateArr = explode('/', $return["day"]);
		if(! is_numeric($checkdateArr[0]) ||
		   ! is_numeric($checkdateArr[1]) ||
		   ! is_numeric($checkdateArr[2]) ||
		   ! checkdate($checkdateArr[0], $checkdateArr[1], $checkdateArr[2])) {
			$submitErr |= STARTDAYERR;
			$submitErrMsg[STARTDAYERR] = "The submitted start date is invalid. ";
		}
		if(! ereg('^((0?[1-9])|(1[0-2]))$', $return["hour"], $regs)) {
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
		if(! ereg('^((0?[1-9])|(1[0-2]))$', $return["endhour"])) {
			$submitErr |= ENDHOURERR;
			$submitErrMsg[ENDHOURERR] = "The submitted hour must be from 1 to 12.";
		}
	}*/

	// make sure user hasn't submitted something longer than their allowed max length
	$imageData = getImages(0, $return['imageid']);
	$maxtimes = getUserMaxTimes();
	if($maxtimes['initial'] < $return['length']) {
		$return['lengthchanged'] = 1;
		$return['length'] = $maxtimes['initial'];
	}
	if($imageData[$return['imageid']]['maxinitialtime'] > 0 &&
	   $imageData[$return['imageid']]['maxinitialtime'] < $return['length']) {
		$return['lengthchanged'] = 1;
		$return['length'] = $imageData[$return['imageid']]['maxinitialtime'];
	}

	if($return["ending"] != "length") {
		if(! ereg('^(20[0-9]{2})-([0-1][0-9])-([0-3][0-9]) (([0-1][0-9])|(2[0-3])):([0-5][0-9]):([0-5][0-9])$', $return["enddate"], $regs)) {
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

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processBlockRequestInput($checks)
///
/// \param $checks - 1 to validate input, 0 to skip validation
///
/// \return an array with these keys:\n
/// \b blockname - name of block request\n
/// \b imageid - selected image id\n
/// \b machinecnt - number of machines to allocate\n
/// \b swhour - array of start hours for weekly available selection\n
/// \b swminute - array of start minutes for weekly available selection\n
/// \b swmeridian - array of start meridians for weekly available selection\n
/// \b ewhour - array of end hours for weekly available selection\n
/// \b ewminute - array of end minutes for weekly available selection\n
/// \b ewmeridian - array of end meridians for weekly available selection\n
/// \b smhour - array of start hours for monthly available selection\n
/// \b smminute - array of start minutes for monthly available selection\n
/// \b smmeridian - array of start meridians for monthly available selection\n
/// \b emhour - array of end hours for weekly monthly selection\n
/// \b emminute - array of end minutes for weekly monthly selection\n
/// \b emmeridian - array of end meridians for weekly monthly selection\n
/// \b slhour - array of start hours for list available selection\n
/// \b slminute - array of start minutes for list available selection\n
/// \b slmeridian - array of start meridians for list available selection\n
/// \b elhour - array of end hours for list available selection\n
/// \b elminute - array of end minutes for list available selection\n
/// \b elmeridian - array of end meridians for list available selection\n
/// \b weeknum - week of the month for monthly available selection\n
/// \b day - day of the week (1-7) for monthly available selection\n
/// \b date - array of start dates for list available selection\n
/// \b available - 'weekly', 'monthly', or 'list'\n
/// \b usergroupid - user group id\n
/// \b admingroupid - user group id for group that can edit this request\n
/// \b swdate - start date for weekly available selection\n
/// \b ewdate - end date for weekly available selection\n
/// \b smdate - start date for monthly available selection\n
/// \b emdate - end date for monthly available selection\n
/// \b wdays - array of selected days of the week for weekly available selection\n
/// \b state - 0 if submitted as a new request, 1 for edit, 2 for delete\n
/// \b blockRequestid - id of the request if editing\n
/// \b wdayschecked - array to help determine which days of the week should be
///                   checked for weekly available selection if printing the
///                   page with error messages
///
/// \brief processes input for blockrequests
///
////////////////////////////////////////////////////////////////////////////////
function processBlockRequestInput($checks=1) {
	global $submitErr, $submitErrMsg, $mode, $user, $days;
	$return = array();
	$return['blockname'] = getContinuationVar("blockname", processInputVar("blockname", ARG_STRING));
	$return['imageid'] = getContinuationVar("imageid", processInputVar("imageid", ARG_NUMERIC));
	$return['machinecnt'] = getContinuationVar("machinecnt", processInputVar("machinecnt", ARG_NUMERIC, 0));
	$return['swhour'] = getContinuationVar("swhour", processInputVar("swhour", ARG_MULTINUMERIC));
	$return['swminute'] = getContinuationVar("swminute", processInputVar("swminute", ARG_MULTINUMERIC));
	$return['swmeridian'] = getContinuationVar("swmeridian", processInputVar("swmeridian", ARG_MULTISTRING));
	$return['ewhour'] = getContinuationVar("ewhour", processInputVar("ewhour", ARG_MULTINUMERIC));
	$return['ewminute'] = getContinuationVar("ewminute", processInputVar("ewminute", ARG_MULTINUMERIC));
	$return['ewmeridian'] = getContinuationVar("ewmeridian", processInputVar("ewmeridian", ARG_MULTISTRING));
	$return['smhour'] = getContinuationVar("smhour", processInputVar("smhour", ARG_MULTINUMERIC));
	$return['smminute'] = getContinuationVar("smminute", processInputVar("smminute", ARG_MULTINUMERIC));
	$return['smmeridian'] = getContinuationVar("smmeridian", processInputVar("smmeridian", ARG_MULTISTRING));
	$return['emhour'] = getContinuationVar("emhour", processInputVar("emhour", ARG_MULTINUMERIC));
	$return['emminute'] = getContinuationVar("emminute", processInputVar("emminute", ARG_MULTINUMERIC));
	$return['emmeridian'] = getContinuationVar("emmeridian", processInputVar("emmeridian", ARG_MULTISTRING));
	$return['slhour'] = getContinuationVar("slhour", processInputVar("slhour", ARG_MULTINUMERIC));
	$return['slminute'] = getContinuationVar("slminute", processInputVar("slminute", ARG_MULTINUMERIC));
	$return['slmeridian'] = getContinuationVar("slmeridian", processInputVar("slmeridian", ARG_MULTISTRING));
	$return['elhour'] = getContinuationVar("elhour", processInputVar("elhour", ARG_MULTINUMERIC));
	$return['elminute'] = getContinuationVar("elminute", processInputVar("elminute", ARG_MULTINUMERIC));
	$return['elmeridian'] = getContinuationVar("elmeridian", processInputVar("elmeridian", ARG_MULTISTRING));
	$return['weeknum'] = getContinuationVar("weeknum", processInputVar("weeknum", ARG_NUMERIC));
	$return['day'] = getContinuationVar("day", processInputVar("day", ARG_NUMERIC));
	$return['date'] = getContinuationVar("date", processInputVar("date", ARG_MULTISTRING));
	$return['available'] = getContinuationVar("available", processInputVar("available", ARG_STRING, 'weekly'));
	$return['usergroupid'] = getContinuationVar("usergroupid", processInputVar("usergroupid", ARG_NUMERIC));
	$return['admingroupid'] = getContinuationVar("admingroupid", processInputVar("admingroupid", ARG_NUMERIC));
	$return['swdate'] = getContinuationVar("swdate", processInputVar("swdate", ARG_STRING));
	$return['ewdate'] = getContinuationVar("ewdate", processInputVar("ewdate", ARG_STRING));
	$return['smdate'] = getContinuationVar("smdate", processInputVar("smdate", ARG_STRING));
	$return['emdate'] = getContinuationVar("emdate", processInputVar("emdate", ARG_STRING));
	$return['wdays'] = getContinuationVar("wdays", processInputVar("wdays", ARG_MULTISTRING));
	$return['state'] = getContinuationVar("state", 0);
	$return['blockRequestid'] = getContinuationVar("blockRequestid", processInputVar("blockRequestid", ARG_NUMERIC));

	$return['wdayschecked'] = array();
	foreach($days as $day) {
		if(in_array($day, $return['wdays']))
			$return['wdayschecked'][$day] = 'checked';
		else
			$return['wdayschecked'][$day] = '';
	}
	if(! $checks)
		return $return;

	if(! preg_match('/^([-a-zA-Z0-9\. ]){3,80}$/', $return["blockname"])) {
	   $submitErr |= BLOCKNAMEERR;
	   $submitErrMsg[BLOCKNAMEERR] = "Name can only contain letters, numbers, spaces, dashes(-),<br>and periods(.) and can be from 3 to 80 characters long";
	}

	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);
	if(! in_array($return['imageid'], array_keys($resources['image']))) {
		$submitErr |= IMAGEIDERR;
		$submitErrMsg[IMAGEIDERR] = "The submitted image is invalid.";
	}

	if($return['machinecnt'] < MIN_BLOCK_MACHINES) {
		$submitErr |= BLOCKCNTERR;
		$submitErrMsg[BLOCKCNTERR] = "You must request at least " . MIN_BLOCK_MACHINES . " machines";
	}
	elseif($return['machinecnt'] > MAX_BLOCK_MACHINES) {
		$submitErr |= BLOCKCNTERR;
		$submitErrMsg[BLOCKCNTERR] = "You cannot request more than " . MAX_BLOCK_MACHINES . " machines";
	}

	// FIXME should we limit the course groups that show up?
	$groups = getUserGroups();
	if(! array_key_exists($return['usergroupid'], $groups)) {
		$submitErr |= USERGROUPIDERR;
		$submitErrMsg[USERGROUPIDERR] = "The submitted user group is invalid.";
	}

	if(! array_key_exists($return['admingroupid'], $groups) &&
	   $return['admingroupid'] != 0) {
		$submitErr |= ADMINGROUPIDERR;
		$submitErrMsg[ADMINGROUPIDERR] = "The submitted user group is invalid.";
	}

	if($return['available'] == 'weekly') {
		$keys = array('1' => 'swhour',
		              '2' => 'ewhour',
		              '3' => 'swminute',
		              '4' => 'ewminute',
		              '5' => 'swmeridian',
		              '6' => 'ewmeridian',
		              '7' => 'swdate',
		              '8' => 'ewdate');

		// check days of week
		foreach($return['wdays'] as $index => $day) {
			if(! in_array($day, $days))
				unset($return['wdays'][$index]);
		}
		/*foreach($days as $day) {
			if(in_array($day, $return['wdays']))
				$return['wdayschecked'][$day] = 'checked';
		}*/
		if(! count($return['wdays'])) {
			$submitErr |= STARTDAYERR;
			$submitErrMsg[STARTDAYERR] = "You must select at least one day of the week";
		}
	}
	elseif($return['available'] == 'monthly') {
		$keys = array('1' => 'smhour',
		              '2' => 'emhour',
		              '3' => 'smminute',
		              '4' => 'emminute',
		              '5' => 'smmeridian',
		              '6' => 'emmeridian',
		              '7' => 'smdate',
		              '8' => 'emdate');

		// check weeknum
		if($return['weeknum'] < 1 || $return['weeknum'] > 5) {
			$submitErr |= WEEKNUMERR;
			$submitErrMsg[WEEKNUMERR] = "Invalid week of the month submitted";
		}

		// check day
		if($return['day'] < 1 || $return['day'] > 7) {
			$submitErr |= DAYERR;
			$submitErrMsg[DAYERR] = "Invalid day of the week submitted";
		}

	}
	elseif($return['available'] == 'list') {
		$keys = array('1' => 'slhour',
		              '2' => 'elhour',
		              '3' => 'slminute',
		              '4' => 'elminute',
		              '5' => 'slmeridian',
		              '6' => 'elmeridian');
	}

	// check each timeslot
	for($i = 0; $i < 4; $i++) {
		$submitErrMsg[STARTHOURERR][$i] = "";
		$submitErrMsg[ENDHOURERR][$i] = "";
		// start hour
		if($return[$keys[1]][$i] < 1 || $return[$keys[1]][$i] > 12) {
			$submitErr |= STARTHOURERR;
			$submitErrMsg[STARTHOURERR][$i] = "The start hour must be between 1 and 12.";
		}
		// end hour
		if($return[$keys[2]][$i] < 1 || $return[$keys[2]][$i] > 12) {
			$submitErr |= ENDHOURERR;
			$submitErrMsg[ENDHOURERR][$i] = " The end hour must be between 1 and 12.";
		}
		// start minute
		if($return[$keys[3]][$i] < 0 || $return[$keys[3]][$i] > 59) {
			$submitErr |= STARTHOURERR; // we reuse STARTHOURERR here, it overwrites the last one, but oh well
			$submitErrMsg[STARTHOURERR][$i] = "The start minute must be between 0 and 59.";
		}
		// end minute
		if($return[$keys[4]][$i] < 0 || $return[$keys[4]][$i] > 59) {
			$submitErr |= ENDHOURERR;
			$submitErrMsg[ENDHOURERR][$i] = " The end minute must be between 0 and 59.";
		}
		// start meridian
		if($return[$keys[5]][$i] != 'am' && $return[$keys[5]][$i] != 'pm') {
			$return[$keys[5]][$i] = 'pm';  // just set it to one of them
		}
		// end meridian
		if($return[$keys[6]][$i] != 'am' && $return[$keys[6]][$i] != 'pm') {
			$return[$keys[6]][$i] = 'am';  // just set it to one of them
		}
		// check that start is before end
		$return['stime'][$i] = minuteOfDay2("{$return[$keys[1]][$i]}:{$return[$keys[3]][$i]} {$return[$keys[5]][$i]}");
		$return['etime'][$i] = minuteOfDay2("{$return[$keys[2]][$i]}:{$return[$keys[4]][$i]} {$return[$keys[6]][$i]}");
		if($return['stime'][$i] > $return['etime'][$i]) {
			$submitErr |= STARTHOURERR; // we reuse STARTHOURERR here, it overwrites the last one, but oh well
			$submitErrMsg[STARTHOURERR][$i] = "The start time must be before the end time (or be equal to ignore this slot)";
		}
	}
	if($return['available'] == 'weekly' ||
	   $return['available'] == 'monthly') {
		// check that timeslots do not overlap
		if(! ($submitErr & STARTHOURERR) && ! ($submitErr & ENDHOURERR)) {
			for($i = 0; $i < 4; $i++) {
				for($j = $i + 1; $j < 4; $j++) {
					if($return['etime'][$i] > $return['stime'][$j] &&
						$return['stime'][$i] < $return['etime'][$j]) {
						$submitErr |= STARTHOURERR;
						$submitErrMsg[STARTHOURERR][$i] = "This timeslot overlaps with Slot" . ($j + 1);
					}
				}
			}
		}
		// check that start date is valid
		$startarr = split('/', $return[$keys[7]]);
		if(! preg_match('/^((\d){1,2})\/((\d){1,2})\/(\d){2}$/', $return[$keys[7]])) {
			$submitErr |= STARTDATEERR;
			$submitErrMsg[STARTDATEERR] = "The start date must be in the form mm/dd/yy.";
		}
		elseif(! checkdate($startarr[0], $startarr[1], $startarr[2])) {
			$submitErr |= STARTDATEERR;
			$submitErrMsg[STARTDATEERR] = "This is an invalid date.";
		}
		elseif(datetimeToUnix("{$startarr[2]}-{$startarr[0]}-{$startarr[1]} 23:59:59") < time()) {
			$submitErr |= STARTDATEERR;
			$submitErrMsg[STARTDATEERR] = "The start date must be today or later.";
		}
		// check that end date is valid
		$endarr = split('/', $return[$keys[8]]);
		if(! preg_match('/^((\d){1,2})\/((\d){1,2})\/(\d){2}$/', $return[$keys[8]])) {
			$submitErr |= ENDDATEERR;
			$submitErrMsg[ENDDATEERR] = "The end date must be in the form mm/dd/yy.";
		}
		elseif(! checkdate($endarr[0], $endarr[1], $endarr[2])) {
			$submitErr |= ENDDATEERR;
			$submitErrMsg[ENDDATEERR] = "This is an invalid date.";
		}
		elseif(datetimeToUnix("{$startarr[2]}-{$startarr[0]}-{$startarr[1]} 00:00:00") >
		       datetimeToUnix("{$endarr[2]}-{$endarr[0]}-{$endarr[1]} 00:00:00")) {
			$submitErr |= ENDDATEERR;
			$submitErrMsg[ENDDATEERR] = "The end date must be later than the start date.";
		}
	}
	elseif($return['available'] == 'list') {
		if(! ($submitErr & STARTHOURERR) && ! ($submitErr & ENDHOURERR)) {
			// check date[1-n]
			for($i = 0; $i < 4; $i++) {
				$submitErrMsg[STARTDATEERR][$i] = "";
				if($return['stime'][$i] == $return['etime'][$i])
					continue;
				$submitErrMsg[STARTDATEERR][$i] = "";
				$datearr = split('/', $return['date'][$i]);
				if(! preg_match('/^((\d){1,2})\/((\d){1,2})\/(\d){2}$/', $return['date'][$i])) {
					$submitErr |= STARTDATEERR;
					$submitErrMsg[STARTDATEERR][$i] = "The date must be in the form mm/dd/yy.";
				}
				elseif(! checkdate($datearr[0], $datearr[1], $datearr[2])) {
					$submitErr |= STARTDATEERR;
					$submitErrMsg[STARTDATEERR][$i] = "Invalid date submitted.";
				}
				elseif(datetimeToUnix("{$datearr[2]}-{$datearr[0]}-{$datearr[1]} 23:59:59") < time()) {
					$submitErr |= STARTDATEERR;
					$submitErrMsg[STARTDATEERR][$i] = "The date must be today or later.";
				}
			}
		}
	}
	if(0) {
		# FIXME
		$submitErr |= AVAILABLEERR;
		$submitErrMsg[AVAILABLEERR] = "The submitted availability selection is invalid.";
	}
	return $return;
}
?>
