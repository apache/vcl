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
/// \fn viewRequests
///
/// \brief prints user's reservations
///
////////////////////////////////////////////////////////////////////////////////
function viewRequests() {
	global $user, $inContinuation, $mode, $skin;
	if(! $inContinuation && ! array_key_exists('tzoffset', $_SESSION['persistdata'])) {
		if(array_key_exists('offset', $_GET)) {
			AJsetTZoffset();
		}
		else {
			print "<script type=\"text/javascript\">\n";
			print "var now = new Date();\n";
			print "var offset = now.getTimezoneOffset();\n";
			print "var offsetreloading = 1;\n";
			print "setTimeout(function() {\n";
			print "   window.location = '" . BASEURL . SCRIPT . "?mode=$mode&offset=' + offset;\n";
			print "}, 1);\n";
			print "</script>\n";
			return;
		}
	}
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

	$text = '';

	$newbtnh = '';
	if(in_array("imageCheckOut", $user["privileges"]) ||
	   in_array("imageAdmin", $user["privileges"])) {
		$newbtnh .= "<button id=\"newrequestbtn\" dojoType=\"dijit.form.Button\">\n";
		$newbtnh .= "  " . i("New Reservation") . "\n";
		$newbtnh .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$newbtnh .= "    showNewResDlg();\n";
		$newbtnh .= "  </script>\n";
		$newbtnh .= "</button><br><br>\n";
	}

	if($mode != 'AJviewRequests') {
		print "<H2>" . i("Current Reservations") . "</H2>\n";
		if(count($requests) == 0)
			print "<span id=\"noresspan\">\n";
		else
			print "<span id=\"noresspan\" class=\"hidden\">\n";
		if($newbtnh == '')
			print i("You have no current reservations and do not have access to create new ones.") . "<br><br>\n";
		else
			print i("You have no current reservations.") . "<br><br>\n";
		print "</span>\n";
		print $newbtnh;
	}

	if($newbtnh == '' && count($requests) == 0)
		return;

	if($mode != 'AJviewRequests')
		print "<div id=subcontent>\n";

	$refresh = 0;
	$connect = 0;
	$failed = 0;

	$normal = '';
	$imaging = '';
	$long = '';
	$server = '';

	$pendingids = array(); # array of all currently pending ids
	$newreadys = array();# array of ids that were in pending and are now ready
	if(array_key_exists('pendingreqids', $_SESSION['usersessiondata']))
		$lastpendingids = $_SESSION['usersessiondata']['pendingreqids'];
	else
		$lastpendingids = array(); # array of ids that were pending last time (needs to get set from $pendingids at end of function)

	$reqids = array();
	if(checkUserHasPerm('View Debug Information'))
		$nodes = getManagementNodes();
	if($count = count($requests)) {
		$now = time();
		for($i = 0, $noedit = 0, $text = '', $showcreateimage = 0, $cluster = 0, $col3 = 0;
		   $i < $count;
		   $i++, $noedit = 0, $text = '', $cluster = 0, $col3 = 0) {
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
				if(in_array($requests[$i]['id'], $lastpendingids)) {
					if(! is_null($requests[$i]['servername']))
						$newreadys[] = $requests[$i]['servername'];
					else
						$newreadys[] = $requests[$i]['prettyimage'];
				}
				$connect = 1;
				# request is ready, print Connect! and End buttons
				$cont = addContinuationsEntry('AJconnectRequest', $cdata, SECINDAY);
				$text .= getViewRequestHTMLitem('connectbtn', $cont);
				if($requests[$i]['serveradmin']) {
					$cdata2 = $cdata;
					$cdata2['notbyowner'] = 0;
					if($user['id'] != $requests[$i]['userid'])
						$cdata2['notbyowner'] = 1;
					$cont = addContinuationsEntry('AJconfirmDeleteRequest', $cdata2, SECINDAY);
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
				$noedit = 1;
				$failed = 1;
			}
			elseif(datetimeToUnix($requests[$i]["start"]) < $now) {
				# other cases where the reservation start time has been reached
				if(($requests[$i]["currstate"] == 'complete' &&
				   $requests[$i]['laststate'] == 'timeout') ||
					$requests[$i]["currstate"] == 'timeout' ||
					($requests[$i]["currstate"] == 'pending' &&
					$requests[$i]["laststate"] == 'timeout')) {
					# request has timed out
					$text .= getViewRequestHTMLitem('timeoutblock');
					$noedit = 1;
					if($requests[$i]['serveradmin']) {
						$cont = addContinuationsEntry('AJconfirmRemoveRequest', $cdata, SECINDAY);
						$text .= getViewRequestHTMLitem('removebtn', $cont);
					}
					else
						$text .= "    <TD></TD>\n";
				}
				elseif($requests[$i]['currstate'] == 'maintenance' ||
				       ($requests[$i]['currstate'] == 'pending' &&
						 $requests[$i]['laststate'] == 'maintenance')) {
					# request is in maintenance
					$text .= getViewRequestHTMLitem('maintenanceblock');
					$noedit = 1;
					$col3 = 1;
				}
				elseif($requests[$i]['currstate'] == 'image' ||
				       $requests[$i]['currstate'] == 'checkpoint' ||
				       ($requests[$i]['currstate'] == 'pending' &&
						 ($requests[$i]['laststate'] == 'image' ||
						 $requests[$i]['laststate'] == 'checkpoint'))) {
					# request is in image
					$text .= getViewRequestHTMLitem('imageblock');
					$noedit = 1;
					$col3 = 1;
					$refresh = 1;
				}
				else {
					# computer is loading, print Pending... and Delete button
					# TODO figure out a different way to estimate for reboot and reinstall states
					# TODO if user account not ready, print accurate information in details
					$pendingids[] = $requests[$i]['id'];
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
					   $requests[$i]['currstateid'] != 24 &&
					   ($requests[$i]["currstateid"] != 14 ||
					   ($requests[$i]['laststateid'] != 26 &&
					    $requests[$i]['laststateid'] != 27 &&
					    $requests[$i]['laststateid'] != 28 &&
					    $requests[$i]['laststateid'] != 24)))
						$data['text'] = i("<br>Est:&nbsp;") . $remaining . i("&nbsp;min remaining\n");
					$text .= getViewRequestHTMLitem('pendingblock', $requests[$i]['id'], $data);
					$refresh = 1;
					if($requests[$i]['serveradmin'] && $requests[$i]['laststateid'] != 24) {
						$cdata2 = $cdata;
						$cdata2['notbyowner'] = 0;
						if($user['id'] != $requests[$i]['userid'])
							$cdata2['notbyowner'] = 1;
						$cont = addContinuationsEntry('AJconfirmDeleteRequest', $cdata2, SECINDAY);
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
					$cdata2 = $cdata;
					$cdata2['notbyowner'] = 0;
					if($user['id'] != $requests[$i]['userid'])
						$cdata2['notbyowner'] = 1;
					$cont = addContinuationsEntry('AJconfirmDeleteRequest', $cdata2, SECINDAY);
					$text .= getViewRequestHTMLitem('deletebtn', $cont);
				}
				else
					$text .= "    <TD></TD>\n";
			}
			if(! $noedit) {
				# print edit button
				$editcont = addContinuationsEntry('AJeditRequest', $cdata, SECINDAY);
				$imgcont = addContinuationsEntry('AJstartImage', $cdata, SECINDAY);
				if($requests[$i]['serveradmin']) {
					$text .= getViewRequestHTMLitem('openmoreoptions');
					$text .= getViewRequestHTMLitem('editoption', $editcont);
					if(array_key_exists($imageid, $resources['image']) && ! $cluster &&            # imageAdmin access, not a cluster,
					   ($requests[$i]['currstateid'] == 8 || $requests[$i]['laststateid'] == 8)) { # reservation has been in inuse state
						$text .= getViewRequestHTMLitem('endcreateoption', $imgcont);
					}
					/*else
						$text .= getViewRequestHTMLitem('endcreateoptiondisable');*/
					if(array_key_exists($imageid, $resources['image']) && ! $cluster &&
					   $requests[$i]['server'] && ($requests[$i]['currstateid'] == 8 ||
						($requests[$i]['currstateid'] == 14 && $requests[$i]['laststateid'] == 8))) {
						$chkcdata = $cdata;
						$chkcdata['checkpoint'] = 1;
						$imgcont = addContinuationsEntry('AJstartImage', $chkcdata, SECINDAY);
						$text .= getViewRequestHTMLitem('checkpointoption', $imgcont);
					}
					elseif($requests[$i]['server'] && $requests[$i]['currstateid'] == 24)
						$text .= getViewRequestHTMLitem('checkpointoptiondisable');
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
			elseif($col3 == 0)
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
				$text .= "<b>Mgmt node</b>: {$nodes[$requests[$i]["managementnodeid"]]['hostname']}<br>\n";
				$text .= "<b>Computer ID</b>: {$requests[$i]['computerid']}<br>\n";
				$text .= "<b>Comp hostname</b>: {$computers[$requests[$i]["computerid"]]["hostname"]}<br>\n";
				$text .= "<b>Comp IP</b>: {$requests[$i]["IPaddress"]}<br>\n";
				$text .= "<b>Comp State ID</b>: {$computers[$requests[$i]["computerid"]]["stateid"]}<br>\n";
				$text .= "<b>Comp Type</b>: {$requests[$i]['comptype']}<br>\n";
				if(! is_null($requests[$i]['vmhostid']))
					$text .= "<b>VM Host</b>: $vmhost<br>\n";
				$text .= "<b>Current State ID</b>: {$requests[$i]["currstateid"]}<br>\n";
				$text .= "<b>Last State ID</b>: {$requests[$i]["laststateid"]}<br>\n";
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

	if(! empty($normal)) {
		if(! empty($imaging) || ! empty($long))
			$text .= i("You currently have the following <strong>normal</strong> reservations:") . "<br>\n";
		else
			$text .= i("You currently have the following normal reservations:") . "<br>\n";
		if($lengthchanged) {
			$text .= "<font color=red>";
			$text .= i("NOTE: The maximum allowed reservation length for one of these reservations was less than the length you submitted, and the length of that reservation has been adjusted accordingly.");
			$text .= "</font>\n";
		}
		$text .= "<table id=reslisttable summary=\"lists reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= "    <TH>" . i("Environment") . "</TH>\n";
		$text .= "    <TH>" . i("Starting") . "</TH>\n";
		$text .= "    <TH>" . i("Ending") . "</TH>\n";
		$text .= "    <TH>" . i("Initially requested") . "</TH>\n";
		if(checkUserHasPerm('View Debug Information'))
			$text .= "    <TH>" . i("Req ID") . "</TH>\n";
		$text .= "  </TR>\n";
		$text .= $normal;
		$text .= "</table>\n";
	}
	if(! empty($imaging)) {
		if(! empty($normal))
			$text .= "<hr>\n";
		$text .= i("You currently have the following <strong>imaging</strong> reservations:") . "<br>\n";
		$text .= "<table id=imgreslisttable summary=\"lists imaging reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= "    <TH>" . i("Environment") . "</TH>\n";
		$text .= "    <TH>" . i("Starting") . "</TH>\n";
		$text .= "    <TH>" . i("Ending") . "</TH>\n";
		$text .= "    <TH>" . i("Initially requested") . "</TH>\n";
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
		$text .= i("You currently have the following <strong>long term</strong> reservations:") . "<br>\n";
		$text .= "<table id=\"longreslisttable\" summary=\"lists long term reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= "    <TH>" . i("Environment") . "</TH>\n";
		$text .= "    <TH>" . i("Starting") . "</TH>\n";
		$text .= "    <TH>" . i("Ending") . "</TH>\n";
		$text .= "    <TH>" . i("Initially requested") . "</TH>\n";
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
		$text .= i("You currently have the following <strong>server</strong> reservations:") . "<br>\n";
		$text .= "<table id=\"longreslisttable\" summary=\"lists server reservations you currently have\" cellpadding=5>\n";
		$text .= "  <TR>\n";
		$text .= "    <TD colspan=3></TD>\n";
		$text .= "    <TH>" . i("Name") . "</TH>\n";
		$text .= "    <TH>" . i("Ending") . "</TH>\n";
		$computers = getComputers();
		$text .= "    <TH>" . i("Details") . "</TH>\n";
		if(checkUserHasPerm('View Debug Information'))
			$text .= "    <TH>" . i("Req ID") . "</TH>\n";
		$text .= "  </TR>\n";
		$text .= $server;
		$text .= "</table>\n";
	}

	# connect div
	if($connect) {
		$text .= "<br><br>";
		$text .= i("Click the <b>Connect!</b> button to get further information about connecting to the reserved system. You must click the button from a web browser running on the same computer from which you will be connecting to the remote computer; otherwise, you may be denied access to the machine.") . "\n";
	}

	if($refresh) {
		$text .= "<br><br>";
		$text .= i("This page will automatically update every 20 seconds until the <font color=red><i>Pending...</i></font> reservation is ready.") . "\n";
	}

	if($failed) {
		$text .= "<br><br>";
		$text .= i("An error has occurred that has kept one of your reservations from being processed. We apologize for any inconvenience this may have caused.") . "\n";
	}

	$cont = addContinuationsEntry('AJviewRequests', array(), SECINDAY);
	$text .= "<INPUT type=hidden id=resRefreshCont value=\"$cont\">\n";

	$cont = addContinuationsEntry('AJpreviewClickThrough', array());
	$text .= "<INPUT type=hidden id=previewclickthroughcont value=\"$cont\">\n";

	$text .= "</div>\n";
	if($mode != 'AJviewRequests') {
		$text .= newReservationHTML();

		$text .= newReservationConfigHTML();

		/*$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"imageRevisionDlg\"\n";
		$text .= "      title=\"" . i("Select Image Revisions") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true\n";
		$text .= "      width=\"50%\"\n";
		#$text .= "      height=\"80%\">\n";
		#$text .= "      style=\"height: 80%; width: 50%;\">\n";
		$text .= "      style=\"width: 50%;\">\n";
		#$text .= "<div dojoType=\"dijit.layout.BorderContainer\" gutters=\"false\" style=\"width: 100%; height: 90%;\">\n";
		#$text .= "<div dojoType=\"dijit.layout.ContentPane\" region=\"top\" style=\"height: 25px;\">\n";
		$text .= i("There are multiple versions of this environment available.");
		$text .= "<br>" . i("Please select the version you would like to check out:");
		#$text .= "\n</div>\n"; # ContentPane
		#$text .= " <div dojoType=\"dijit.layout.ContentPane\" region=\"center\">\n";
		#$text .= "   <div id=\"imageRevisionContent\"></div>\n";
		$text .= "   <div id=\"imageRevisionContent\" style=\"height: 85%; overflow: auto;\"></div>\n";
		#$text .= "</div>\n"; # ContentPane
		#$text .= " <div dojoType=\"dijit.layout.ContentPane\" region=\"bottom\" style=\"height: 25px;\">\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"imageRevBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "    " . i("Create Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitNewReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('imageRevisionDlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n"; # center
		#$text .= "</div>\n"; # ContentPane
		#$text .= "</div>\n"; # BorderContainer
		$text .= "</div>\n"; # Dialog*/

		$text .= "<div dojoType=dojox.layout.FloatingPane\n";
		$text .= "      id=resStatusPane\n";
		$text .= "      resizable=true\n";
		$text .= "      closable=true\n";
		$text .= "      title=\"" . i("Detailed Reservation Status") . "\"\n";
		$text .= "      style=\"width: 380px; ";
		$text .=               "height: 300px; ";
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
		$text .= "      title=\"" . i("Delete Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true\n";
		$text .= "      style=\"width: 315px;\">\n";
		$text .= "   <div id=\"endResDlgContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"endrescont\">\n";
		$text .= "   <input type=\"hidden\" id=\"endresid\">\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"endResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "    " . i("Delete Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitDeleteReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('endResDlg').hide();\n";
		$text .= "       dojo.byId('endResDlgContent').innerHTML = '';\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"remResDlg\"\n";
		$text .= "      title=\"" . i("Remove Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "   <div id=\"remResDlgContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"remrescont\">\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"remResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Remove Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitRemoveReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('remResDlg').hide();\n";
		$text .= "       dojo.byId('remResDlgContent').innerHTML = '';\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"editResDlg\"\n";
		$text .= "      title=\"" . i("Modify Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideEditResDlg();\n";
		$text .= "    </script>\n";
		$text .= "   <div id=\"editResDlgContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"editrescont\">\n";
		$text .= "   <input type=\"hidden\" id=\"editresid\">\n";
		$text .= "   <div id=\"editResDlgPartialMsg\" class=\"ready\"></div>\n";
		$text .= "   <div id=\"editResDlgErrMsg\" class=\"rederrormsg\"></div>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"editResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Modify Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitEditReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\" id=\"editResCancelBtn\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('editResDlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"rebootdlg\"\n";
		$text .= "      title=\"" . i("Reboot Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideRebootResDlg();\n";
		$text .= "    </script>\n";
		$text .= "   <div id=\"rebootResDlgContent\">";
		$h = i("You can select either a soft or a hard reboot. A soft reboot issues a reboot command to the operating system. A hard reboot is akin to toggling the power switch on a computer. After issuing the reboot, it may take several minutes before the machine is available again. It is also possible that it will not come back up at all. Are you sure you want to continue?");
		$text .= preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $h);
		$text .= "<br><br></div>\n";
		$text .= "   <div id=\"rebootRadios\" style=\"margin-left: 90px;\">\n";
		$text .= "   <input type=\"radio\" name=\"reboottype\" id=\"softreboot\" checked>\n";
		$text .= "   <label for=\"softreboot\">" . i("Soft Reboot") . "</label><br>\n";
		$text .= "   <input type=\"radio\" name=\"reboottype\" id=\"hardreboot\">\n";
		$text .= "   <label for=\"hardreboot\">" . i("Hard Reboot") . "</label><br><br>\n";
		$text .= "   </div>\n";
		$text .= "   <input type=\"hidden\" id=\"rebootrescont\">\n";
		$text .= "   <div id=\"rebootResDlgErrMsg\" class=\"rederrormsg\"></div>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"rebootResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Reboot Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitRebootReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('rebootdlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"reinstalldlg\"\n";
		$text .= "      title=\"" . i("Reinstall Reservation") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideReinstallResDlg();\n";
		$text .= "    </script>\n";
		$text .= "   <div id=\"reinstallloading\" style=\"text-align: center\">";
		$text .= "<img src=\"themes/$skin/css/dojo/images/loading.gif\" ";
		$text .= "style=\"vertical-align: middle;\"> " . i("Loading...") . "</div>\n";
		$text .= "   <div id=\"reinstallResDlgContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"reinstallrescont\">\n";
		$text .= "   <div id=\"reinstallResDlgErrMsg\" class=\"rederrormsg\"></div>\n";
		$text .= "   <div align=\"center\" id=\"reinstallbtns\" class=\"hidden\">\n";
		$text .= "   <button id=\"reinstallResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Reinstall Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitReinstallReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('reinstalldlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"suggestedTimes\"\n";
		$text .= "      title=\"" . i("Available Times") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "   <div id=\"suggestloading\" style=\"text-align: center\">";
		$text .= "<img src=\"themes/$skin/css/dojo/images/loading.gif\" ";
		$text .= "style=\"vertical-align: middle;\"> " . i("Loading...") . "</div>\n";
		$text .= "   <div id=\"suggestContent\"></div>\n";
		$text .= "   <input type=\"hidden\" id=\"suggestcont\">\n";
		$text .= "   <input type=\"hidden\" id=\"selectedslot\">\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"suggestDlgBtn\" dojoType=\"dijit.form.Button\" disabled>\n";
		$text .= "     " . i("Use Selected Time") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       useSuggestedEditSlot();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button id=\"suggestDlgCancelBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('suggestDlgBtn').set('disabled', true);\n";
		$text .= "       dojo.removeClass('suggestDlgBtn', 'hidden');\n";
		$text .= "       showDijitButton('suggestDlgBtn');\n";
		$text .= "       dijit.byId('suggestDlgCancelBtn').set('label', '" . i("Cancel") . "');\n";
		$text .= "       dijit.byId('suggestedTimes').hide();\n";
		$text .= "       dojo.byId('suggestContent').innerHTML = '';\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"startimagedlg\"\n";
		$text .= "      title=\"" . i("Create / Update Image") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideStartImageDlg();\n";
		$text .= "    </script>\n";
		$text .= "<div id=\"imageendrescontent\">\n";
		$text .=   "<H2>" . i("Create / Update an Image") . "</H2>\n";
		$text .= "</div>\n"; # imageendrescontent
		$text .= "<div id=\"imagekeeprescontent\">\n";
		$text .=   "<H2>" . i("Keep Reservation &amp; Create / Update an Image") . "</H2>\n";
		$h  =   i("This process will create a new image or new revision of the image while allowing you to keep your reservation. The node will be taken <strong>offline</strong> during the image capture process.");
		$h .=   "\n \n";
		$h .=   "<strong>" . i("NOTE: The same sanitizing that occurs during normal image capture will take place. This includes things such as deleting temporary files, cleaning out firewall rules, removing user home space, and removing user accounts.");
		$h .=   "\n</strong> \n";
		$h .=   i("After the imaging occurs, you will be able to connect to the reservation again. The image will appear to you as if you had just made a new reservation for it.");
		$h .=   "\n \n";
		$text .= preg_replace("/(.{1,80}([ \n]|$))/", '\1<br>', $h);
		$text .= "</div>\n"; # imagekeeprescontent
		$text .=   i("Are you creating a new image or updating an existing image?") . "<br><br>\n";
		$text .= "<input type=radio name=imgmode id=newimage value=\"\" checked>\n";
		$text .= "<label for=newimage>" . i("Creating New Image") . "</label><br>\n";
		$text .= "<input type=radio name=imgmode id=updateimage value=\"\">\n";
		$text .= "<label for=updateimage id=\"updateimagelabel\">";
		$text .= i("Update Existing Image") . "</label>";
		$text .= "<br><br>\n";
		$text .= "   <div align=\"center\" id=\"imagebtns\">\n";
		$text .= "   <button id=\"imageDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Submit") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitCreateUpdateImage();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('startimagedlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"startimagedisableddlg\"\n";
		$text .= "      title=\"" . i("Create / Update Image") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      style=\"width: 30%;\"\n";
		$text .= "      draggable=true>\n";
		$text .=   "<H2>" . i("Create / Update an Image") . "</H2>\n";
		$text .= i("You cannot create new images from this image because the owner of the image has set \"Users have administrative access\" to No under the Advanced Options of the image.");
		$text .= "<br><br>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Close") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('startimagedisableddlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"connectDlg\"\n";
		$text .= "      title=\"" . i("Connect") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      autofocus=false\n";
		$text .= "      draggable=true>\n";
		$text .= "   <div dojoType=\"dijit.layout.ContentPane\" id=\"connectDlgContent\" ";
		$text .= "        style=\"overflow: auto; width: 500px;\"></div>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Close") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('connectDlg').hide();\n";
		$text .= "       dijit.byId('connectDlgContent').set('content', '');\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"timeoutdlg\"\n";
		$text .= "      title=\"" . i("Reservation Timed Out") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=false>\n";
		$h =     i("This reservation has timed out and is no longer available.");
		$text .= preg_replace("/(.{1,30}([ \n]|$))/", '\1<br>', $h);
		$text .= "<br><br>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Okay") . "\n";
		$text .= "	   <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('timeoutdlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<input type=hidden id=addresourcecont>\n";
		$obj = new Image();
		$text .= $obj->addEditDialogHTML(1);

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"updateimagedlg\"\n";
		$text .= "      title=\"" . i("Update Existing Image") . "\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideUpdateImageDlg();\n";
		$text .= "    </script>\n";
		$text .= "   <div id=\"updateimageDlgContent\">\n";
		$text .= "      <h3>" . i("New Revision Comments") . "</h3>\n";

		$h = i("Enter any notes for yourself and other admins about the current state of the image. These are optional and are not visible to end users:");
		$text .= preg_replace("/(.{1,85}([ \n]|$))/", '\1<br>', $h);

		$text .= "      <textarea dojoType=\"dijit.form.Textarea\" id=\"newcomments\" ";
		$text .= "      style=\"width: 400px; text-align: left;\">\n\n</textarea>\n";
		$text .= "      <h3>" . i("Previous Revision Comments") . "</h3>\n";
		$text .= "      <div id=\"previouscomments\"></div>\n";
		$text .= "   </div>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button id=\"updateImageDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Submit") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       submitUpdateImage();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('updateimagedlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"clickthroughdlg\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "    <script type=\"dojo/connect\" event=onHide>\n";
		$text .= "      hideClickThroughDlg();\n";
		$text .= "    </script>\n";
		$text .= "   <div id=\"clickthroughDlgContent\">\n";
		$text .= "   </div>\n";
		$text .= "   <div align=\"center\" id=\"imagebtns\">\n";
		$text .= "   <button id=\"clickthroughDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("I agree") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       clickThroughAgree();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("I do not agree") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('clickthroughdlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"clickthroughpreviewdlg\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "   <div id=\"clickthroughPreviewDlgContent\"></div>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Close") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('clickthroughpreviewdlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		$text .= "<div dojoType=dijit.Dialog\n";
		$text .= "      id=\"serverdeletedlg\"\n";
		$text .= "      duration=250\n";
		$text .= "      draggable=true>\n";
		$text .= "   <div id=\"serverDeleteDlgContent\">\n";
		$text .= "   <h2>Confirm Server Delete</h2>\n";
		$text .= "   <span class=\"rederrormsg\"><big>\n";
		$warn = i("WARNING: You are not the owner of this reservation. You have been granted access to manage this reservation by another user. Hover over the details icon to see who the owner is. You should not delete this reservation unless the owner is aware that you are deleting it.");
		$text .= preg_replace("/(.{1,80}([ \n]|$))/", '\1<br>', $warn);
		$text .= "   </big></span>\n";
		$text .= "   </div><br>\n";
		$text .= "   <div align=\"center\">\n";
		$text .= "   <input type=\"hidden\" id=\"deletecontholder\">\n";
		$text .= "   <button id=\"serverDeleteDlgBtn\" dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Confirm Delete Reservation") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       endServerReservation();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   <button dojoType=\"dijit.form.Button\">\n";
		$text .= "     " . i("Cancel") . "\n";
		$text .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$text .= "       dijit.byId('serverdeletedlg').hide();\n";
		$text .= "     </script>\n";
		$text .= "   </button>\n";
		$text .= "   </div>\n";
		$text .= "</div>\n";

		print $text;
		$_SESSION['usersessiondata']['pendingreqids'] = $pendingids;
	}
	else {
		$text = str_replace("\n", ' ', $text);
		$text = str_replace("('", "(\'", $text);
		$text = str_replace("')", "\')", $text);
		print "document.body.style.cursor = 'default';";
		if(count($requests) == 0)
			print "dojo.removeClass('noresspan', 'hidden');";
		else
			print "dojo.addClass('noresspan', 'hidden');";
		if($refresh)
			print "refresh_timer = setTimeout(resRefresh, 20000);\n";
		if(count($newreadys))
			print "notifyResReady('" . implode("\n", $newreadys) . "');";
		$_SESSION['usersessiondata']['pendingreqids'] = $pendingids;
		print(setAttribute('subcontent', 'innerHTML', $text));
		print "AJdojoCreate('subcontent');";
		if($incPaneDetails) {
			$text = detailStatusHTML($refreqid);
			print(setAttribute('resStatusText', 'innerHTML', $text));
		}
		print "checkResGone(" . json_encode($reqids) . ");";
		if(count($pendingids))
			print "document.title = '" . count($pendingids) . " Pending :: VCL :: Virtual Computing Lab';";
		else
			print "document.title = 'VCL :: Virtual Computing Lab';";
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
	global $user;
	$r = '';
	if($item == 'connectbtn') {
		$r .= "    <TD>\n";
		$r .= dijitButton('', i("Connect!"), "connectRequest('$var1');");
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'deletebtn') {
		$r .= "    <TD>\n";
		$r .= "      <button dojoType=\"dijit.form.Button\">\n";
		$r .= "        " . i("Delete Reservation") . "\n";
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
		$r .= "href=\"#\">" . i("Reservation failed") . "</a></span>\n";
		$r .= "      </span>\n";
		$r .= "      <noscript>\n";
		$r .= "      <span class=scriptoff>\n";
		$r .= "      <span class=compstatelink>";
		$r .= i("Reservation failed") . "</span>\n";
		$r .= "      </span>\n";
		$r .= "      </noscript>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'removebtn') {
		$r .= "    <TD>\n";
		$r .= "      <button dojoType=\"dijit.form.Button\">\n";
		$r .= "        " . i("Remove") . "\n";
		$r .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$r .= "          removeReservation('$var1');\n";
		$r .= "        </script>\n";
		$r .= "      </button>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'timeoutblock') {
		$r .= "    <TD>\n";
		$r .= "      <span class=compstatelink>" . i("Reservation has timed out") . "</span>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'maintenanceblock') {
		$r .= "    <TD colspan=\"3\">\n";
		$r .= "      <span class=compstatelink>" . i("Reservation is in maintenance - Contact admin for help") . "</span>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'imageblock') {
		$r .= "    <TD colspan=\"3\">\n";
		$r .= "      <span class=rescapture>" . i("Reservation is being captured") . "</span>\n";
		$r .= "    </TD>\n";
		return $r;
	}
	if($item == 'pendingblock') {
		$r .= "    <TD>\n";
		$r .= "      <span class=scriptonly>\n";
		$r .= "      <span class=compstatelink><i>";
		$r .= "<a onClick=\"showResStatusPane($var1); ";
		$r .= "return false;\" href=\"#\">" . i("Pending...") . "</a></i></span>\n";
		$r .= "      </span>\n";
		$r .= "      <noscript>\n";
		$r .= "      <span class=scriptoff>\n";
		$r .= "      <span class=compstatelink>";
		$r .= "<i>" . i("Pending...") . "</i></span>\n";
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
		$r .= "        <span>" . i("More Options") . "...</span>\n";
		$r .= "        <div dojoType=\"dijit.Menu\">\n";
		return $r;
	}
	if($item == 'editoption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("Edit") . "\"\n";
		$r .= "               onClick=\"editReservation('$var1');\">\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'endcreateoption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("End Reservation & Create Image") . "\"\n";
		$r .= "               onClick=\"startImage('$var1');\">\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'endcreateoptiondisable') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("End Reservation & Create Image") . "\" disabled\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'checkpointoption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("Keep Reservation & Create Image") . "\"\n";
		$r .= "               onClick=\"startImage('$var1');\">\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'checkpointoptiondisable') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("Keep Reservation & Create Image") . "\" disabled\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'rebootoption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("Reboot") . "\">\n";
		$r .= "            <script type=\"dojo/method\" event=\"onClick\">\n";
		$r .= "              rebootRequest('$var1');\n";
		$r .= "            </script>\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'rebootoptiondisable') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("Reboot") . "\" disabled>\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'reinstalloption') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("Reinstall") . "\">\n";
		$r .= "            <script type=\"dojo/method\" event=\"onClick\">\n";
		$r .= "              showReinstallRequest('$var1');\n";
		$r .= "            </script>\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'reinstalloptiondisable') {
		$r .= "          <div dojoType=\"dijit.MenuItem\"\n";
		$r .= "               iconClass=\"noicon\"\n";
		$r .= "               label=\"" . i("Reinstall") . "\" disabled>\n";
		$r .= "          </div>\n";
		return $r;
	}
	if($item == 'imagename') {
		$r .= "    <TD>" . str_replace("'", "&#39;", $var1);
		if($data['addtest'])
			$r .= " " . i("(Testing)");
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
			$r .= "    <TD>" . i("(none)") . "</TD>\n";
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
		$r .= "<b>" . i("Owner:") . "</b>" . " {$data['owner']}<br>\n";
		$r .= "<b>" . i("Environment:") . "</b>" . " {$data['image']}<br>\n";
		$r .= "<b>" . i("Start Time:") . "</b> " . prettyDatetime($data['starttime'], 1) . "<br>\n";
		$r .= "<b>" . i("Initially Requested:") . "</b> " . prettyDatetime($data['requesttime'], 1) . "<br>\n";
		if(empty($data['admingroup']))
			$r .= "<b>" . i("Admin User Group:") . "</b> (" . i("none") . ")<br>\n";
		else
			$r .= "<b>" . i("Admin User Group:") . "</b>" . " {$data['admingroup']}<br>\n";
		if(empty($data['logingroup']))
			$r .= "<b>" . i("Access User Group:") . "</b> " . i("(none)") . "<br>\n";
		else
			$r .= "<b>" . i("Access User Group:") . "</b>" . " {$data['logingroup']}<br>\n";
		if($data['stateid'] == 8)
			$r .= "<b>" . i("Status:") . "</b> " . i("In Use") . "\n";
		elseif($data['stateid'] == 24)
			$r .= "<b>" . i("Status:") . "</b> " . i("Checkpointing") . "\n";
		elseif($data['stateid'] == 5)
			$r .= "<b>" . i("Status:") . "</b> " . i("Failed") . "\n";
		elseif($data['stateid'] == 13)
			$r .= "<b>" . i("Status:") . "</b> " . i("New") . "\n";
		elseif($data['stateid'] == 28)
			$r .= "<b>" . i("Status:") . "</b> " . i("Hard Rebooting") . "\n";
		elseif($data['stateid'] == 26)
			$r .= "<b>" . i("Status:") . "</b> " . i("Soft Rebooting") . "\n";
		elseif($data['stateid'] == 27)
			$r .= "<b>" . i("Status:") . "</b> " . i("Reinstalling") . "\n";
		elseif($data['stateid'] == 6)
			$r .= "<b>" . i("Status:") . "</b> " . i("Loading") . "\n";
		elseif($data['stateid'] == 3)
			$r .= "<b>" . i("Status:") . "</b> " . i("In Use") . "\n";
		elseif($data['stateid'] == 11)
			$r .= "<b>" . i("Status:") . "</b> " . i("Timed Out") . "\n";
		$r .= "</div>\n";
		$r .= "</TD>\n";
		return $r;
	}
	if($item == 'timeoutdata') {
		$timeout = getReservationNextTimeout($data['resid']);
		$end = datetimeToUnix($data['end']);
		if(! is_null($timeout)) {
			if($timeout > $end)
				$timeout = $end;
			$r .= "     <input type=\"hidden\" class=\"timeoutvalue\" id=\"timeoutvalue|$var1\" value=\"$timeout\">\n";
		}
		else {
			$timeout = getVariable("reconnecttimeout|{$user['affiliation']}");
			if(is_null($timeout))
				$timeout = getVariable("reconnecttimeout", 900);
			$timeout = time() + $timeout + 15;
			if($timeout > $end)
				$timeout = $end;
			$r .= "     <input type=\"hidden\" class=\"timeoutvalue\" id=\"timeoutvalue|$var1\" value=\"$timeout\">\n";
		}
		return $r;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn newReservationHTML()
///
/// \return html
///
/// \brief generates HTML for dialog for creating new reservation
///
////////////////////////////////////////////////////////////////////////////////
function newReservationHTML() {
	global $user, $skin;

	$forimaging = getContinuationVar('imaging', processInputVar('imaging', ARG_NUMERIC, 0));
	$checkout = getUserResources(array("imageAdmin", "imageCheckOut"));
	$imaging = getUserResources(array("imageAdmin"));
	$server = getUserResources(array("serverCheckOut"), array("available"));

	$imagedata = getImages();
	$baseaccess = 0;
	$imagingaccess = 0;
	$serveraccess = 0;
	$images = array();
	$noimaging = array();
	$serverimages = array();
	$dorevisionscont = 0;
	if(in_array('imageAdmin', $user['privileges']) &&
	   count($imaging['image'])) {
		$imagingaccess = 1;
	}
	if(in_array('imageCheckOut', $user['privileges']) &&
	   count($checkout['image'])) {
		$baseaccess = 1;
		foreach($checkout['image'] as $id => $name) {
			$images[$id] = array('name' => $name,
			                     'basic' => 1,
			                     'imaging' => 0,
			                     'server' => 1,
			                     'checkout' => 1,
			                     'maxinitialtime' => 0,
			                     'revisions' => 0);
			if(array_key_exists($id, $imagedata) &&
			   ! $imagedata[$id]["forcheckout"])
				$images[$id]['checkout'] = 0;
			if(array_key_exists($id, $imagedata) &&
			   $imagingaccess && array_key_exists($id, $imaging['image'])) {
			   if($imagedata[$id]['rootaccess'] == 1 || $imagedata[$id]['ownerid'] == $user['id'])
					$images[$id]['imaging'] = 1;
				else
					$noimaging[$id] = 1;
			}
			if(array_key_exists($id, $imagedata) &&
			   $imagedata[$id]["maxinitialtime"] != 0)
				$images[$id]['maxinitialtime'] = $imagedata[$id]['maxinitialtime'];
			$subowner = 0;
			if(array_key_exists($id, $imagedata) &&
			   $imagedata[$id]['imagemetaid'] != NULL &&
				count($imagedata[$id]['subimages'])) {
				foreach($imagedata[$id]['subimages'] as $subid) {
					if(array_key_exists($subid, $imagedata) &&
					   $imagedata[$subid]['ownerid'] == $user['id'] &&
					   count($imagedata[$subid]['imagerevision']) > 1)
						$subowner = 1;
				}
			}
			if($subowner || 
			   (array_key_exists($id, $imagedata) &&
			   count($imagedata[$id]['imagerevision']) > 1 &&
			   ($imagedata[$id]['ownerid'] == $user['id'] ||
				checkUserHasPerm('View Debug Information')))) {
				$images[$id]['revisions'] = 1;
				$dorevisionscont = 1;
			}
		}
	}
	if(in_array('serverCheckOut', $user['privileges']) && 
	   count($checkout['image'])) {
		$serveraccess = 1;
		/*$extraimages = getServerProfileImages($user['id']);
		foreach($extraimages as $id => $name) {
			if(! array_key_exists($id, $images)) {
				$images[$id] = array('name' => $name,
				                     'basic' => 0,
				                     'imaging' => 0,
				                     'server' => 1,
				                     'checkout' => 1,
				                     'maxinitialtime' => 0,
				                     'revisions' => 0);
				if(array_key_exists($id, $imagedata) &&
				   ! $imagedata[$id]["forcheckout"])
					$images[$id]['checkout'] = 0;
				if(array_key_exists($id, $imagedata) &&
				   $imagedata[$id]["maxinitialtime"] != 0)
					$images[$id]['maxinitialtime'] = $imagedata[$id]['maxinitialtime'];
				$subowner = 0;
				if(array_key_exists($id, $imagedata) &&
				   $imagedata[$id]['imagemetaid'] != NULL &&
					count($imagedata[$id]['subimages'])) {
					foreach($imagedata[$id]['subimages'] as $subid) {
						if(array_key_exists($subid, $imagedata) &&
						   $imagedata[$subid]['ownerid'] == $user['id'] &&
						   count($imagedata[$subid]['imagerevision']) > 1)
							$subowner = 1;
					}
				}
				if($subowner || 
				   (array_key_exists($id, $imagedata) &&
				   count($imagedata[$id]['imagerevision']) > 1 &&
				   ($imagedata[$id]['ownerid'] == $user['id'] ||
					checkUserHasPerm('View Debug Information')))) {
					$images[$id]['revisions'] = 1;
					$dorevisionscont = 1;
				}
			}
		}*/
	}

	$imageid = getUsersLastImage($user['id']);
	if(is_null($imageid) && count($images)) {
		$tmp = array_keys($images);
		$imageid = $tmp[0];
	}

	uasort($images, "sortKeepIndex");

	$groupid = getUserGroupID('Specify End Time', 1);
	$members = getUserGroupMembers($groupid);
	if(array_key_exists($user['id'], $members))
		$openend = 1;
	else
		$openend = 0;

	$groupid = getUserGroupID('Allow No User Check', 1);
	$members = getUserGroupMembers($groupid);
	if(array_key_exists($user['id'], $members))
		$nousercheck = 1;
	else
		$nousercheck = 0;

	$cdata = array('baseaccess' => $baseaccess,
	               'imagingaccess' => $imagingaccess,
	               'serveraccess' => $serveraccess,
	               'openend' => $openend,
	               'nousercheck' => $nousercheck,
	               'imaging' => $forimaging,
	               'noimaging' => $noimaging);
	$debug = processInputVar('debug', ARG_NUMERIC, 0);
	if($debug && checkUserHasPerm('View Debug Information'))
		$cdata['debug'] = 1;

	$h = '';
	$h  = "<div dojoType=dijit.Dialog\n";
	$h .= "      id=\"newResDlg\"\n";
	$h .= "      title=\"" . i("New Reservation") . "\"\n";
	$h .= "      duration=250\n";
	$h .= "      draggable=true>\n";
	$h .= "   <input type=\"hidden\" id=\"openend\" value=\"$openend\">\n";
	$h .= "   <div id=\"newResDlgContent\">\n";

	/*$cbtn  = "   <div align=\"center\"><br>\n";
	$cbtn .= "   <button dojoType=\"dijit.form.Button\">\n";
	$cbtn .= "     " . i("Close") . "\n";
	$cbtn .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
	$cbtn .= "       dijit.byId('newResDlg').hide();\n";
	$cbtn .= "     </script>\n";
	$cbtn .= "   </button>\n";
	$cbtn .= "   </div>\n"; # center

	if($forimaging) {
		$h .= "<h2>" . i("Create / Update an Image") . "</h2>\n";
		if($imagingaccess == 0) {
			$h .= i("You don't have access to any base images from which to create new images.") . "<br>\n";
			return $h . $cbtn;
		}
	}
	else*/
		$h .= "<h2>" . i("New Reservation") . "</h2>\n";

	if(! count($images)) {
		$h .= i("You do not have access to any images.");
		$h .= "<br><br>\n";
		$h .= "   <div align=\"center\"><br>\n";
		$h .= "   <button dojoType=\"dijit.form.Button\">\n";
		$h .= "     " . i("Close") . "\n";
		$h .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "       dijit.byId('newResDlg').hide();\n";
		$h .= "     </script>\n";
		$h .= "   </button>\n";
		$h .= "   </div>\n"; # center
		$h .= "</div>\n"; # newResDlgContent
		$h .= "</div>\n"; # newResDlg
		return $h;
	}

	$chk = array('base' => '', 'imaging' => '', 'server' => '');
	if(! $baseaccess && $serveraccess)
		$chk['server'] = 'checked';
	elseif($forimaging)
		$chk['imaging'] = 'checked';
	else
		$chk['base'] = 'checked';

	$showradios = 0;
	if($baseaccess + $imagingaccess + $serveraccess > 1)
		$showradios = 1;
	if($showradios)
		$h .= i("Reservation type:") . "<br>\n";
	$h .= "<div";
	if(! $baseaccess || $showradios == 0)
		$h .= " style=\"display: none;\"";
	else
		$h .= " style=\"display: inline-block;\"";
	$h .= "><input type=\"radio\" id=\"basicrdo\" name=\"restype\" ";
	$h .= "onclick=\"selectResType();\" {$chk['base']}>\n";
	$h .= "<label for=\"basicrdo\">" . i("Basic Reservation");
	$h .= "</label></div>\n";
	$h .= "<div";
	if(! $imagingaccess || $showradios == 0)
		$h .= " style=\"display: none;\"";
	else
		$h .= " style=\"display: inline-block;\"";
	$h .= "><input type=\"radio\" id=\"imagingrdo\" name=\"restype\" ";
	$h .= "onclick=\"selectResType();\" {$chk['imaging']}>\n";
	$h .= "<label for=\"imagingrdo\">" . i("Imaging Reservation");
	$h .= "</label></div>\n";
	$h .= "<div";
	if(! $serveraccess || $showradios == 0)
		$h .= " style=\"display: none;\"";
	else
		$h .= " style=\"display: inline-block;\"";
	$h .= "><input type=\"radio\" id=\"serverrdo\" name=\"restype\" ";
	$h .= "onclick=\"selectResType();\" {$chk['server']}>\n";
	$h .= "<label for=\"serverrdo\">" . i("Server Reservation");
	$h .= "</label></div>\n";
	if($showradios)
		$h .= "<br><br>\n";

	/*$h .= "<span id=\"deployprofileslist\" class=\"hidden\">\n";
	$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"profilesstore\" ";
	$h .= "data=\"profilesstoredata\"></div>\n";
	$h .= i("Profile:") . " ";
	$h .= "<select dojoType=\"dijit.form.Select\" id=\"deployprofileid\" ";
	$h .= "onChange=\"deployProfileChanged();\" sortByLabel=\"true\"></select><br>\n";
	$h .= "<fieldset>\n";
	$h .= "<legend>" . i("Description:") . "</legend>\n";
	$h .= "<div id=\"deploydesc\"></div>\n";
	$h .= "</fieldset>\n";
	$cont = addContinuationsEntry('AJserverProfileData', array('mode' => 'checkout'));
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"deployFetchProfilesBtn\">\n";
	$h .= "	" . i("Apply Profile") . "\n";
	$h .= "	<script type=\"dojo/method\" event=onClick>\n";
	$h .= "		getServerProfileData('$cont', 'deployprofileid', getServerProfileDataDeployCB);\n";
	$h .= "	</script>\n";
	$h .= "</button>";
	$h .= "<br><br>\n";
	$h .= "<input type=\"hidden\" id=\"appliedprofileid\" value=\"0\">\n";
	$h .= "</span>\n"; # deployprofileslist*/

	$h .= "<div id=\"deployserverdiv\">\n";
	# directions
	$h .= "<span id=\"nrdirections\">";
	$h .= i("Please select the environment you want to use from the list:");
	$h .= "<br></span>\n";

	# javascript for max duration and image store
	$maxTimes = getUserMaxTimes();
	$maximaging = $maxTimes['initial'];
	if($imagingaccess && $maxTimes['initial'] < MAXINITIALIMAGINGTIME)
		$maximaging = MAXINITIALIMAGINGTIME;
	$h .= "<script type=\"text/javascript\">\n";
	$h .= "var defaultMaxTime = {$maxTimes['initial']};\n";
	$h .= "var maximaging = $maximaging;\n";
	$h .= "var images = {identifier: 'id',\n";
	$h .=     "label: 'name',\n";
	$h .=     "items: [\n";
	$lines = array();
	foreach($images as $id => $img) {
		$lines[] = "   {id: $id, name: '{$img['name']}', basic: {$img['basic']}, "
		         . "imaging: {$img['imaging']}, server: {$img['server']}, "
		         . "checkout: {$img['checkout']}, revisions: {$img['revisions']}, "
		         . "maxinitialtime: {$img['maxinitialtime']}}";
	}
	$h .= implode(",\n", $lines);
	$h .= "\n]};\n";
	$h .= "var lastimageid = $imageid;\n";
	$h .= "var imagingaccess = $imagingaccess;\n";
	$h .= "</script>\n";
	$cdata['maxinitial'] = $maxTimes['initial'];

	# image
	$h .= "<span class=\"labeledform\">";
	$h .= resourceStore('image', 1, 'detailimagestore');
	$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" data=\"images\" ";
	$h .= "jsId=\"imagestore\"></div>\n";
	$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"deployimage\" ";
	$h .= "style=\"width: 95%;\" required=\"true\" store=\"imagestore\" ";
	$h .= "queryExpr=\"*\${0}*\" ";
	if($forimaging)
		$h .= "query=\"{imaging: 1}\" ";
	else
		$h .= "query=\"{basic: 1, checkout: 1}\" ";
	$h .= "highlightMatch=\"all\" autoComplete=\"false\" ";
	$h .= "invalidMessage=\"" . i("Please select a valid environment");
	$h .= "\" onChange=\"selectEnvironment();\" tabIndex=1></select>\n";
	$h .= "</span><br><br>\n";
	$imagenotes = getImageNotes($imageid);
	$desc = '';
	if(! preg_match('/^\s*$/', $imagenotes['description'])) {
		$desc = preg_replace("/\n/", '<br>', $imagenotes['description']);
		$desc = preg_replace("/\r/", '', $desc);
		$desc = "<strong>" . i("Image Description") . "</strong>:<br>\n"
		      . "$desc<br><br>\n";
	}
	$h .= "<div id=imgdesc>$desc</div>\n";

	# name
	$h .= "<div id=\"newreslabelfields\" style=\"width: 47.5em; margin-right: 5px;\">\n";
	$h .= "<span id=\"nrnamespan\" class=\"hidden\">\n";
	$h .= "<label for=\"deployname\">" . i("Reservation Name:") . "</label>\n";
	$h .= "<span class=\"labeledform\">\n";
	$h .= "<input type=\"text\" id=\"deployname\" style=\"width: 31em\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"^([-a-zA-Z0-9_\. ]){0,255}$\" invalidMessage=\"";
	$h .= i('The reservation name can only contain letters, numbers, spaces, dashes(-), underscores(_), and periods(.) and can be up to 255 characters long');
	$h .= "\"></span><br></span>\n";

	$h .= "<span id=\"nrservergroupspan\" class=\"hidden\">";
	# admin group
	if($user['showallgroups'])
		$admingroups = getUserGroups();
	else
		$admingroups = getUserGroups(0, $user['affiliationid']);
	$h .= "<label for=\"deployadmingroup\">";
	$h .= i("Admin User Group:") . "</label><span class=\"labeledform\">";
	if(USEFILTERINGSELECT && count($admingroups) < FILTERINGSELECTTHRESHOLD) {
		$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"deployadmingroup\" ";
		$h .= "style=\"width: 31em\" queryExpr=\"*\${0}*\" required=\"true\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "<select id=\"deployadmingroup\">\n";
	$h .= "  <option value=\"0\">None</option>\n";
	foreach($admingroups as $id => $group) {
		if($group['name'] == 'None' || preg_match('/^None@.*$/', $group['name']))
			continue;
		$h .= "  <option value=\"$id\">{$group['name']}</option>\n";
	}
	$h .= "</select></span><br>\n";

	$h .= "<div id=\"admingrpnote\" class=\"hidden\" ";
	$h .= "style=\"width: 31em; margin: 3px 0 3px 10.5em; padding: 1px; border: 1px solid;\">";
	$h .= i("Administrative access has been disabled for this image. Users in the Admin User Group will have control of the reservaion on the Reservations page but will not have administrative access within the reservation.");
	$h .= "</div>\n";

	# login group
	$logingroups = $admingroups;
	$h .= "<label for=\"deploylogingroup\">";
	$h .= i("Access User Group:") . "</label><span class=\"labeledform\">";
	if(USEFILTERINGSELECT && count($logingroups) < FILTERINGSELECTTHRESHOLD) {
		$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"deploylogingroup\" ";
		$h .= "style=\"width: 31em\" queryExpr=\"*\${0}*\" required=\"true\" ";
		$h .= "highlightMatch=\"all\" autoComplete=\"false\">\n";
	}
	else
		$h .= "<select id=\"deploylogingroup\">\n";
	$h .= "  <option value=\"0\">None</option>\n";
	foreach($logingroups as $id => $group) {
		if($group['name'] == 'None' || preg_match('/^None@.*$/', $group['name']))
			continue;
		$h .= "  <option value=\"$id\">{$group['name']}</option>\n";
	}
	$h .= "</select></span><br></span>\n";

	# fixed MAC
	/*$h .= "<span id=\"nrmacaddrspan\">\n";
	$h .= "<label for=\"deployfixedMAC\">";
	$h .= i("Fixed MAC Address:") . "</label>\n";
	$h .= "<span class=\"labeledform\">\n";
	$h .= "<input type=\"text\" id=\"deployfixedMAC\" style=\"width: 200px\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"([0-9a-fA-F]{2}:){5}([0-9a-fA-F]{2})\">(optional)</span>";
	$h .= "<br></span>\n";*/

	# monitored
	/*$h .= "<span id=\"nrmonitoredspan\">\n";
	$h .= "<label for=\"deploymonitored\">" . i("Monitored:") . "</label>\n";
	$h .= "<span class=\"labeledform\"><input type=\"checkbox\" ";
	$h .= "id=\"deploymonitored\" dijit.form.CheckBox\"></span><br></span>\n";*/

	# fixed IP block
	$h .= "<div id=\"nrfixedipdiv2\" class=\"hidden\">\n";
	$h .= "<div id=\"nrfixedipdiv\">\n";
	# ip addr
	$regip1 = "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)";
	$regip4 = "$regip1\\.$regip1\\.$regip1\\.$regip1";
	$h .= "<label for=\"deployfixedIP\">" . i("Fixed IP Address:") . "</label>\n";
	$h .= "<span class=\"labeledform\"><input type=\"text\" ";
	$h .= "id=\"deployfixedIP\" style=\"width: 180px\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" regExp=\"$regip4\" ";
	$h .= "onKeyUp=\"checkFixedSet('deploy');\">" . i("(optional)") . "</span><br>\n";
	# netmask
	$h .= "<label for=\"deploynetmask\">" . i("Netmask:") . "</label>\n";
	$h .= "<span class=\"labeledform\"><input type=\"text\" ";
	$h .= "id=\"deploynetmask\" style=\"width: 180px\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" regExp=\"$regip4\" ";
	$h .= "validator=\"validateNetmask\" onKeyUp=\"fetchRouterDNS('deploy');\" ";
	$h .= "disabled></span><br>\n";
	# router
	$h .= "<label for=\"deployrouter\">" . i("Router:") . "</label>\n";
	$h .= "<span class=\"labeledform\"><input type=\"text\" ";
	$h .= "id=\"deployrouter\" style=\"width: 180px\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" regExp=\"$regip4\" ";
	$h .= "disabled></span><br>\n";
	# dns servers
	$h .= "<label for=\"deploydns\">" . i("DNS Server(s):") . "</label>\n";
	$h .= "<span class=\"labeledform\"><input type=\"text\" ";
	$h .= "id=\"deploydns\" style=\"width: 180px\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "regExp=\"($regip4)(,$regip4){0,2}\" disabled></span><br>\n";
	$h .= "</div>\n"; # nrfixedipdiv
	$h .= "<br><br>";
	$h .= "</div>\n"; # nrfixedipdiv2

	$h .= "</div>\n"; # newreslabelfields

	$h .= "<span id=\"nousercheckspan\"";
	if(! $nousercheck)
		$h .= " class=\"hidden\"";
	$h .= ">\n";
	if($nousercheck)
		$h .= labeledFormItem('nousercheck', i('Disable timeout for disconnected users'), 'check', '', '', '1');
	$h .= "<br></span>";

	$h .= "<span id=\"whentitlebasic\">";
	$h .= i("When would you like to use the environment?");
	$h .= "</span>\n";
	$h .= "<span id=\"whentitleimaging\" class=\"hidden\">";
	$h .= i("When would you like to start the imaging process?");
	$h .= "</span>\n";
	$h .= "<span id=\"whentitleserver\" class=\"hidden\">";
	$h .= i("When would you like to deploy the server?");
	$h .= "</span>";
	$h .= "<br>\n";

	# duration radios
	$h .= "&nbsp;&nbsp;&nbsp;";
	$h .= "<input type=\"radio\" id=\"startnow\" name=\"deploystart\" ";
	$h .= "onclick=\"setStartNow();\" checked>\n";
	$h .= "<label for=\"startnow\">" . i("Now") . "</label><br>\n";
	$h .= "&nbsp;&nbsp;&nbsp;";
	$h .= "<input type=\"radio\" id=\"startlater\" name=\"deploystart\" ";
	$h .= "onclick=\"setStartLater();\">\n";
	$h .= "<label for=\"startlater\">" . i("Later:") . "</label>\n";

	# limited start
	$days = getReserveDayData();
	$h .= "<span id=\"limitstart\">\n";
	$h .= selectInputHTML('day', $days, 'deploystartday', "onChange='setStartLater();'");
	$h .= "&nbsp;" . i("At") . "&nbsp;\n";
	$tmpArr = array();
	for($i = 1; $i < 13; $i++)
		$tmpArr[$i] = $i;

	$tmp = time() + ($_SESSION['persistdata']['tzoffset'] * 60);
	$timestamp = unixFloor15($tmp + 4500);
	$timeArr = explode(',', date('g,i,a', $timestamp));

	$h .= selectInputHTML('hour', $tmpArr, 'deployhour', "onChange='setStartLater();'", $timeArr[0]);
	$minutes = array("0" => "00", "15" => "15", "30" => "30", "45" => "45");
	$h .= selectInputHTML('minute', $minutes, 'deploymin', "onChange='setStartLater();'", $timeArr[1]);
	$h .= selectInputHTML('meridian', array("am" => "a.m.", "pm" => "p.m."),
	                      'deploymeridian', "onChange='setStartLater();'", $timeArr[2]);
	$h .= "</span>\n";

	# any start
	$h .= "<span id=\"anystart\" class=\"hidden\">\n";
	$h .= "<div dojoType=\"dijit.form.DateTextBox\" ";
	$h .= "id=\"deploystartdate\" onChange=\"setStartLater();\" ";
	$h .= "style=\"width: 88px;\"></div>\n";
	$h .= "<div id=\"deploystarttime\" dojoType=\"dijit.form.TimeTextBox\" ";
	$h .= "style=\"width: 88px\" onChange=\"setStartLater();\"></div>\n";
	$h .= "</span><br><br>\n";

	$h .= "<span id=\"endlbl\"";
	if(! $openend)
		$h .= " class=\"hidden\"";
	$h .= ">" . i("Ending:") . "<br></span>\n";

	# ending by duration
	$h .= "<span id=\"durationend\">\n";
	$h .= "&nbsp;&nbsp;&nbsp;";
	if($openend) {
		$h .= "<input type=\"radio\" id=\"endduration\" name=\"deployend\" ";
		$h .= "onclick=\"setEndDuration();\">\n";
		$h .= "<label for=\"endduration\">";
	}
	$h .= i("Duration");
	if($openend)
		$h .= ":&nbsp;</label>\n";
	$maxtimes = getUserMaxTimes();
	if($imaging && $maxtimes['initial'] < 720) # make sure at least 12 hours available for imaging reservations
		$maxtimes['initial'] = 720;
	$lengths = getReservationLengths($maxtimes['initial']);
	$h .= selectInputHTML('length', $lengths, 'reqlength',
	                      "onChange='updateWaitTime(0); setEndDuration(); durationChange();'", 60);
	$h .= "<br></span>\n";

	# ending is indefinite
	$h .= "<span id=\"indefiniteend\" class=\"hidden\">\n";
	if($serveraccess) {
		$h .= "&nbsp;&nbsp;&nbsp;";
		$h .= "<input type=\"radio\" id=\"endindef\" name=\"deployend\" ";
		$h .= "onclick=\"setEndIndef();\">\n";
		$h .= "<label for=\"endindef\">" . i("Indefinite") . "</label><br>\n";
	}
	$h .= "</span>\n";

	# ending by date/time
	$h .= "<span id=\"specifyend\"";
	if(! $openend)
		$h .= " class=\"hidden\"";
	$h .= ">\n";
	if($openend || $serveraccess) {
		$h .= "&nbsp;&nbsp;&nbsp;";
		$h .= "<input type=\"radio\" id=\"endat\" name=\"deployend\" ";
		$h .= "onclick=\"setEndAt();\">\n";
		$h .= "<label for=\"endat\">" . i("At this time:") . "</label>\n";
		$h .= "<div type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
		$h .= "id=\"deployenddate\" onChange=\"setEndAt();\" ";
		$h .= "style=\"width: 88px\"></div>\n";
		$h .= "<div type=\"text\" id=\"deployendtime\" dojoType=\"dijit.form.TimeTextBox\" ";
		$h .= "style=\"width: 88px\" onChange=\"setEndAt();\"></div><br>\n";
	}
	$h .= "</span><br>\n";

	$h .= "<div id=\"deployerr\" class=\"rederrormsg\"></div>\n";
	$h .= "<div id=\"waittime\"></div><br>\n";
	$h .= "</div>\n"; # deployserverdiv

	$h .= "   </div>\n";
	$h .= "   <input type=\"hidden\" id=\"newrescont\">\n";
	$h .= "   <div align=\"center\">\n";
	/*$h .= "   <button id=\"newResDlgShowConfigBtn\" dojoType=\"dijit.form.Button\" ";
	$h .= "class=\"hidden\">\n";
	$h .= "    " . i("Configure System") . "\n";
	$h .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
	$h .= "       showConfigureSystem();\n";
	$h .= "     </script>\n";
	$h .= "   </button>\n";*/
	$h .= dijitButton('newResDlgBtn', i("Create Reservation"), "submitNewReservation();");
	$h .= dijitButton('', i("Cancel"), "dijit.byId('newResDlg').hide();");
	$h .= "   </div>\n";
	$cont = addContinuationsEntry('AJnewRequest', $cdata, SECINDAY);
	$h .= "<input type=\"hidden\" id=\"deploycont\" value=\"$cont\">\n";
	if($serveraccess) {
		$cont = addContinuationsEntry('AJfetchRouterDNS');
		$h .= "<input type=\"hidden\" id=\"fetchrouterdns\" value=\"$cont\">\n";
	}
	$cont = addContinuationsEntry('AJupdateWaitTime', $cdata);
	$h .= "<INPUT type=\"hidden\" id=\"waitcontinuation\" value=\"$cont\">\n";
	$h .= "</div>\n";

	return $h;
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
	$imageid = processInputVar('imageid', ARG_NUMERIC);
	$baseaccess = getContinuationVar('baseaccess');
	$imagingaccess = getContinuationVar('imagingaccess');
	$serveraccess = getContinuationVar('serveraccess');
	$openend = getContinuationVar('openend');
	$imaging = getContinuationVar('imaging');
	$type = processInputVar('type', ARG_STRING);
	$desconly = processInputVar('desconly', ARG_NUMERIC, 0);

	# process imageid
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$validImageids = array_keys($resources['image']);
	/*if($type == 'server') {
		$extraimages = getServerProfileImages($user['id']);
		$validImageids = array_merge($validImageids, array_keys($extraimages));
	}*/
	if(! in_array($imageid, $validImageids))
		return;

	if($desconly) {
		printImageDescription($imageid);
		return;
	}

	# process type
	if(! preg_match('/^basic|imaging|server$/', $type))
		return;
	if(($type == 'basic' && ! $baseaccess) ||
	   ($type == 'imaging' && ! $imagingaccess) ||
	   ($type == 'server' && ! $serveraccess))
		return;
	if($type == 'imaging')
		$imaging = 1;

	# process start
	$start = processInputVar('start', ARG_NUMERIC);
	$now = time();
	if($start == 0) {
		$start = unixFloor15($now);
	}
	else {
		if($start < $now)
			$start = unixFloor15($now);
		if($type == 'basic' || $type == 'imaging') {
			# compute maxstart based on 11:45 pm on start day
			$tmp = $now + DAYSAHEAD * SECINDAY; 
			$maxstart = mktime(23, 45, 0, date('n', $tmp), date('j', $tmp), date('Y', $tmp));
			if($start > $maxstart)
				return;
		}
	}

	# process length/end
	$ending = processInputVar('ending', ARG_STRING);
	if(! preg_match('/^indefinite|endat|duration$/', $ending))
		return;
	if($ending == 'indefinite') {
		$end = datetimeToUnix('2038-01-01 00:00:00');
	}
	elseif($ending == 'endat') {
		$end = processInputVar('end', ARG_NUMERIC);
	}
	elseif($ending == 'duration') {
		$length = processInputVar('duration', ARG_NUMERIC);
		$maxinitial = getContinuationVar('maxinitial');
		if(($type == 'basic' || $type == 'imaging') && ! $openend) {
			if($length > $maxinitial)
				$length = $maxinitial;
		}
		$end = $start + $length * 60;
	}
	if($end < $start) {
		print "dojo.byId('deployerr').innerHTML = '";
		print i("The end time must be later than the start time.") . "';";
		print "dojo.removeClass('deployerr', 'hidden');";
		return;
	}
	if($start < $now)
		$end += 15 * 60;

	# process fixed IP
	$fixedIP = processInputVar('fixedIP', ARG_STRING, '');
	if($type == 'server' && $fixedIP != '') {
		if(! validateIPv4addr($fixedIP)) {
			print "dojo.byId('deployerr').innerHTML = '";
			print i("Invalid IP address specified.") . "';";
			print "dojo.removeClass('deployerr', 'hidden');";
			return;
		}
		$mappedmns = getMnsFromImage($imageid);
		$mnnets = checkAvailableNetworks($fixedIP);
		$intersect = array_intersect($mappedmns, $mnnets);
		if(empty($intersect)) {
			print "dojo.byId('deployerr').innerHTML = '";
			print i("There are no management nodes that can deploy the selected image with the specified IP address.") . "';";
			print "dojo.removeClass('deployerr', 'hidden');";
			return;
		}
	}

	printImageDescription($imageid);

	$images = getImages();
	$imagerevisionid = getProductionRevisionid($imageid);

	# TODO initially, this is a hack where we munge the datastructure
	# finishconfigs
	/*if($type == 'server') {
		$tmp = getConfigClusters($imageid, 1);
		if(count($tmp)) {
			$subimages = array();
			foreach($tmp as $cluster) {
				for($i = 0; $i < $cluster['maxinstance']; $i++)
					$subimages[] = $cluster['childimageid'];
			}
			$images[$imageid]['subimages'] = $subimages;
			if($images[$imageid]['imagemetaid'] == NULL)
				$images[$imageid]['imagemetaid'] = 1;
		}
		elseif($images[$imageid]['imagemetaid'] != NULL &&
			count($images[$imageid]['subimages'])) {
			$images[$imageid]['subimages'] = array();
		}
	}*/

	if($images[$imageid]['rootaccess'])
		print "dojo.addClass('admingrpnote', 'hidden');";
	else
		print "dojo.removeClass('admingrpnote', 'hidden');";

	# check for exceeding max overlaps
	$max = getMaxOverlap($user['id']);
	if(checkOverlap($start, $end, $max)) {
		print "dojo.byId('deployerr').innerHTML = '";
		print i("The selected time overlaps with another reservation you have.");
		print "<br>";
		if($max == 0)
			print i("You cannot have any overlapping reservations.");
		else
			printf(i("You can have up to %d overlapping reservations."), $max);
		print "'; dojo.removeClass('deployerr', 'hidden');";
		return;
	}

	$rc = isAvailable($images, $imageid, $imagerevisionid, $start, $end, 0, 0, 0, 0, $imaging, $fixedIP);
	if($rc < 1) {
		$cdata = array('now' => 0,
		               'start' => $start, 
		               'end' => $end,
		               'server' => 0,
		               'imageid' => $imageid);
		if($start < $now)
			$cdata['now'] = 1;
		$cont = addContinuationsEntry('AJshowRequestSuggestedTimes', $cdata);
		if(array_key_exists('subimages', $images[$imageid]) &&
		   count($images[$imageid]['subimages']) &&
		   $type != 'imaging') {
			print "dojo.byId('suggestcont').value = 'cluster';";
			print "dijit.byId('newResDlgBtn').set('disabled', true);";
		}
		else
			print "dojo.byId('suggestcont').value = '$cont';";
		print "if(dijit.byId('newResDlgBtn')) {";
		print "if(dijit.byId('newResDlgBtn').get('label') != _('View Available Times')) ";
		print "resbtntxt = dijit.byId('newResDlgBtn').get('label'); ";
		print "dijit.byId('newResDlgBtn').set('label', _('View Available Times'));";
		print "}";
	}
	if($rc < 1) {
		print "dojo.removeClass('deployerr', 'hidden');";
		print "showSuggestedTimes();";
		print "dojo.byId('deployerr').innerHTML = '";
	}
	else {
		print "dojo.removeClass('waittime', 'hidden');";
		print "dojo.addClass('deployerr', 'hidden');";
		print "dojo.byId('waittime').innerHTML = '";
	}
	if($rc == -2)
		print i("Selection not currently available due to scheduled system downtime for maintenance");
	elseif($rc == -3)
		print i("IP address not available for selected time");
	elseif($rc == -4)
		print i("IP address not available");
	elseif($rc < 1)
		if(array_key_exists('subimages', $images[$imageid]) &&
		   count($images[$imageid]['subimages']))
			print i("Selection not currently available. Times cannot be suggested for cluster reservations.");
		else
			print i("Selection not currently available");
	elseif(array_key_exists(0, $requestInfo['loaded']) &&
	       $requestInfo['loaded'][0]) {
		print i("Estimated load time:");
		if($start < $now) {
			print " &lt; ";
			print i("1 minute");
		}
		else
			print ' ' . i("Ready at start of reservation");
	}
	else {
		print i("Estimated load time:");
		$loadtime = getImageLoadEstimate($imageid);
		if($start < $now) {
			$loadtime = (int)($loadtime / 60);
			print " &lt; ";
			if($loadtime == 0)
				print $images[$imageid]['reloadtime'];
			else
				printf("%2.0f", $loadtime + 1);
			print " " . i("minutes");
		}
		elseif($loadtime != 0 && ($start - $now < $loadtime))
			print ' ' . i("Ready at") . date(" g:i a", ($now + $loadtime));
		else
			print ' ' . i("Ready at start of reservation");
	}
	print "';";
	if($requestInfo['ipwarning']) {
		print "dojo.removeClass('deployerr', 'hidden');";
		print "dojo.byId('deployerr').innerHTML = '";
		$h = i("WARNING: Current conflict with specified IP address. If the conflict is not resolved by the start of your reservation, the reservation will fail.");
		print preg_replace("/(.{1,68}([ ]|$))/", '\1<br>', $h);
		print "<br>';";
	}
	if($rc > 0)
		print "resetDeployBtnLabel();";
	print "resizeRecenterDijitDialog('newResDlg');";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printImageDescription($imageid)
///
/// \param $imageid - id of image
///
/// \brief prints the image description
///
////////////////////////////////////////////////////////////////////////////////
function printImageDescription($imageid) {
	$imagenotes = getImageNotes($imageid);
	if(! preg_match('/^\s*$/', $imagenotes['description'])) {
		$desc = preg_replace("/\n/", '<br>', $imagenotes['description']);
		$desc = preg_replace("/\r/", '', $desc);
		$desc = preg_replace("/'/", '&#39;', $desc);
		$desc = preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $desc);
		print "dojo.byId('imgdesc').innerHTML = '<b>";
		print i("Image Description") . "</b>:<br>";
		print "$desc<br>'; ";
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
	# TODO remove slots with overlapping IP address
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
		$h = i("There are no available times that the selected image can be used.");
		$data['html'] = preg_replace("/(.{1,33}([ \n]|$))/", '\1<br>', $h) . "<br>";
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
			$h = i('This reservation can no longer be extended due to a reservation immediately following yours.');
			$data['html'] = preg_replace("/(.{1,50}([ \n]|$))/", '\1<br>', $h) . "<br>";
			$data['status'] = 'noextend';
			sendJSON($data);
			return;
		}
		$html .= "<tr>";
		$html .= "<td></td>";
		$html .= "<th>" . i("End Time") . "</th>";
		$html .= "<th>" . i("Extend By") . "</th>";
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
		$html .= "<th>" . i("Start Time") . "</th>";
		$html .= "<th>" . i("Duration") . "</th>";
		if(checkUserHasPerm('View Debug Information'))
			$html .= "<th>" . i("Comp. ID") . "</th>";
		$html .= "</tr>";
		$cnt = 0;
		foreach($slots as $key => $slot) {
			$cnt++;
			$slot['startts'] += $_SESSION['persistdata']['tzoffset'] * 60;
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
			$html .= "onChange=\"setSuggestSlot('{$slots[$key]['startts']}');\"></td>";
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
/// \fn AJconfigSystem()
///
/// \brief generates data for setting up configs for server reservation
///
////////////////////////////////////////////////////////////////////////////////
function AJconfigSystem() {
	$imageid = processInputVar('imageid', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$validImageids = array_keys($resources['image']);
	if(! in_array($imageid, $validImageids)) {
		sendJSON(array('status' => 'noaccess'));
		return;
	}
	$configs = getMappedConfigs($imageid);
	$configs = array_values($configs);
	$configvars = getImageConfigVariables($configs);
	$configvars = array_values($configvars);
	$data = array('status' => 'success',
	              'configs' => $configs,
	              'variables' => $configvars,
	              'cluster' => 0);
	$subs = getConfigClusters($imageid);
	if(! empty($subs)) {
		$data['cluster'] = 1;
		$data['subimages'] = $subs;
	}
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJnewRequest()
///
/// \brief handles submitting a new reservation
///
////////////////////////////////////////////////////////////////////////////////
function AJnewRequest() {
	global $user, $remoteIP;

	$data = processRequestInput();

	#$data['err'] = 1;
	#$data['errmsg'] = 'none';

	if($data['err']) {
		sendJSON($data);
		return;
	}

	if($data['start'] == 0) {
		$nowfuture = 'now';
		$startts = unixFloor15();
		if($data['ending'] == 'duration') {
			$endts = $startts + ($data['duration'] * 60);
			$nowArr = getdate();
			if(($nowArr['minutes'] % 15) != 0)
				$endts += 900;
		}
	}
	else {
		$nowfuture = 'future';
		$startts = $data['start'];
		if($data['ending'] == 'duration')
			$endts = $startts + ($data['duration'] * 60);
	}
	if($data['ending'] == 'indefinite')
		$endts = datetimeToUnix('2038-01-01 00:00:00');
	elseif($data['ending'] == 'endat')
		$endts = $data['end'];

	$images = getImages();

	# TODO initially, this is a hack where we munge the datastructure
	# finishconfigs
	/*if($data['type'] == 'server') {
		$tmp = getConfigClusters($data['imageid'], 1);
		if(count($tmp)) {
			$subimages = array();
			foreach($tmp as $cluster) {
				for($i = 0; $i < $cluster['maxinstance']; $i++)
					$subimages[] = $cluster['childimageid'];
			}
			$images[$data['imageid']]['subimages'] = $subimages;
			if($images[$data['imageid']]['imagemetaid'] == NULL)
				$images[$data['imageid']]['imagemetaid'] = 1;
		}
		elseif($images[$data['imageid']]['imagemetaid'] != NULL &&
			count($images[$data['imageid']]['subimages'])) {
			$images[$data['imageid']]['subimages'] = array();
		}
	}*/

	# check for exceeding max overlaps
	$max = getMaxOverlap($user['id']);
	if(checkOverlap($startts, $endts, $max)) {
		print "dojo.byId('deployerr').innerHTML = '";
		print i("The selected time overlaps with another reservation you have.");
		print "<br>";
		if($max == 0)
			print i("You cannot have any overlapping reservations.");
		else
			printf(i("You can have up to %d overlapping reservations."), $max);
		print "'; dojo.removeClass('deployerr', 'hidden');";
		return;
	}

	$imaging = 0;
	if($data['type'] == 'imaging')
		$imaging = 1;

	$availablerc = isAvailable($images, $data['imageid'], $data['revisionids'],
	                           $startts, $endts, 1, 0, 0, 0, $imaging, $data['ipaddr'],
	                           $data['macaddr']);

	if($availablerc == -4) {
		$msg = i("The IP address you specified is assigned to another VCL node and cannot be used at this time. Submitting a time in the future may allow you to make the reservation, but if the IP remains assigned to the other node, the reservation will fail at deploy time.");
		$data = array('err' => 1,
		              'errmsg' => $msg);
		sendJSON($data);
		return;
	}
	elseif($availablerc == -3) {
		$msg = i("The IP or MAC address you specified overlaps with another reservation using the same IP or MAC address you specified. Please use a different IP or MAC or select a different time to deploy the server.");
		$data = array('err' => 1,
		              'errmsg' => $msg);
		sendJSON($data);
		return;
	}
	elseif($availablerc == -2) {
		$msg = i("The time you requested overlaps with a maintenance window.");
		$data = array('err' => 1,
		              'errmsg' => $msg);
		sendJSON($data);
		return;
	}
	elseif($availablerc == -1) {
		cleanSemaphore();
		$msg = i("You have requested an environment that is limited in the number of concurrent reservations that can be made. No further reservations for the environment can be made for the time you have selected.");
		$data = array('err' => 1,
		              'errmsg' => $msg);
		sendJSON($data);
		return;
	}
	elseif($availablerc == 0) {
		cleanSemaphore();
		$data = array('err' => 2);
		sendJSON($data);
		return;
	}
	$requestid = addRequest($imaging, $data['revisionids'], (1 - $data['nousercheck']));
	if($data['type'] == 'server') {
		if($data['ipaddr'] != '') {
			# save additional network info in variable table
			$allnets = getVariable('fixedIPavailnetworks', array());
			$key = long2ip($data['network']) . "/{$data['netmask']}";
			$allnets[$key] = array('router' => $data['router'],
										  'dns' => $data['dnsArr']);
			setVariable('fixedIPavailnetworks', $allnets, 'yaml');
		}
		$query = "UPDATE reservation "
		       . "SET remoteIP = '$remoteIP' "
		       . "WHERE requestid = $requestid";
		doQuery($query);

		$fields = array('requestid'/*, 'serverprofileid'*/);
		$values = array($requestid/*, $data['profileid']*/);
		if($data['name'] == '') {
			$fields[] = 'name';
			$name = $images[$data['imageid']]['prettyname'];
			$values[] = "'$name'";
		}
		else {
			$fields[] = 'name';
			$name = mysql_real_escape_string($data['name']);
			$values[] = "'$name'";
		}
		if($data['ipaddr'] != '') {
			$fields[] = 'fixedIP';
			$values[] = "'{$data['ipaddr']}'";
		}
		if($data['macaddr'] != '') {
			$fields[] = 'fixedMAC';
			$values[] = "'{$data['macaddr']}'";
		}
		if($data['admingroupid'] != 0) {
			$fields[] = 'admingroupid';
			$values[] = $data['admingroupid'];
		}
		if($data['logingroupid'] != 0) {
			$fields[] = 'logingroupid';
			$values[] = $data['logingroupid'];
		}
		if($data['monitored'] != 0) {
			$fields[] = 'monitored';
			$values[] = 1;
		}
		$allfields = implode(',', $fields);
		$allvalues = implode(',', $values);
		$query = "INSERT INTO serverrequest ($allfields) VALUES ($allvalues)";
		doQuery($query, 101);
		if($data['ipaddr'] != '') {
			$srqid = dbLastInsertID();
			$var = array('netmask' => $data['netmask'],
			              'router' => $data['router'],
			              'dns' => $data['dnsArr']);
			setVariable("fixedIPsr$srqid", $var, 'yaml');
		}
		# TODO configs
		//saveRequestConfigs($requestid, $data['imageid'], $data['configs'], $data['configvars']);
	}
	$data = array('err' => 0);
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn saveRequestConfigs($reqid, $imageid, $configs, $vars)
///
/// \param $reqid - id of request
/// \param $imageid - id of image of reservation
/// \param $configs - array of config data
/// \param $vars - array of config variable data
///
/// \brief creates config entries for reservation
///
////////////////////////////////////////////////////////////////////////////////
function saveRequestConfigs($reqid, $imageid, $configs, $vars) {
	global $user;
	$query = "SELECT id, "
	       .        "imageid "
	       . "FROM reservation "
	       . "WHERE requestid = $reqid "
	       . "ORDER BY id";
	$qh = doQuery($query);
	$resids = array();
	while($row = mysql_fetch_assoc($qh)) {
		if(! array_key_exists($row['imageid'], $resids))
			$resids[$row['imageid']] = array();
		$resids[$row['imageid']][] = $row['id'];
	}
	$bysubimage = array(0 => array('imageid' => $imageid));
	foreach($configs as $id => $cfg) {
		if(preg_match('|^([0-9]+)/([0-9]+)-([0-9]+)$|', $id, $keys)) {
			$bysubimage[$keys[1]][$keys[2]] = $cfg['configid'];
			$bysubimage[$keys[3]]['imageid'] = $cfg['imageid'];
		}
		elseif(preg_match('|^([0-9]+)/([-0-9]+)$|', $id, $keys)) {
			$bysubimage[$keys[1]][$keys[2]] = $cfg['configid'];
		}
	}
	$qbase = "INSERT INTO configinstance "
	       .        "(reservationid, " 
	       .        "configid, "
	       .        "configmapid, "
	       .        "configinstancestatusid) "
	       . "VALUES ";
	$qbase2 = "INSERT INTO configinstancevariable "
	        .        "(configinstanceid, "
	        .        "configvariableid, "
	        .        "value) "
	        . "VALUES ";
	$qbase3 = "INSERT INTO configmap "
	        .        "(configid, "
	        .        "configmaptypeid, "
	        .        "subid, "
	        .        "affiliationid, "
	        .        "disabled, "
	        .        "configstageid) "
	        . "VALUES ";
	$residmaps = array();
	foreach($bysubimage as $cfgsubimgid => $data) {
		$resid = array_pop($resids[$data['imageid']]);
		unset($data['imageid']);
		foreach($data as $mapid => $cfgid) {
			$insmapid = $mapid;
			if($mapid < 0) {
				$query = $qbase3;
				$query .= "($cfgid, ";
				$query .= "(SELECT id FROM configmaptype WHERE name = 'reservation'), ";
				$query .= "$resid, {$user['affiliationid']}, 0, ";
				$query .= $configs["$cfgsubimgid/$mapid"]['configstageid'] . ")";
				doQuery($query);
				$insmapid = dbLastInsertID();
			}
			$query = $qbase;
			$query .= "($resid, $cfgid, $insmapid, 1)";
			doQuery($query);
			$instid = dbLastInsertID();
			if(array_key_exists("$cfgsubimgid/$mapid", $vars)) {
				$sets = array();
				foreach($vars["$cfgsubimgid/$mapid"] as $varid => $varval) {
					$_val = mysql_real_escape_string($varval['value']);
					$sets[] = "($instid, $varid, '$_val')";
				}
				$query = $qbase2 . implode(',', $sets);
				doQuery($query);
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn newReservationConfigHTML()
///
/// \return html
///
/// \brief generates HTML for setting up configs for a server reservation
///
////////////////////////////////////////////////////////////////////////////////
function newReservationConfigHTML() {
	$h = '';
	$h  = "<div dojoType=dijit.Dialog\n";
	$h .= "      id=\"newResConfigDlg\"\n";
	$h .= "      title=\"" . i("Configure System") . "\"\n";
	$h .= "      duration=250\n";
	$h .= "      draggable=true>\n";
	$cont = addContinuationsEntry('AJconfigSystem');
	$h .= "   <input type=\"hidden\" id=\"configcont\" value=\"$cont\">\n";
	$h .= "<div id=\"newResConfigDlgContent\">\n";
	# cluster tree
	$h .= "<div id=\"clusterdiv\" class=\"hidden\">\n";
	$h .= "<b>Cluster</b>:<br>\n";
	$h .= "(select an image to configure any associated configs)<br>\n";
	$h .= "<div dojoType=\"dijit.layout.ContentPane\" ";
	$h .= "style=\"height: 150px; overflow: auto;\">\n";
	# TODO edit CSS to set icons for tree nodes
	$h .= "<span id=\"treeparent\"></span>\n";
	$h .= "</div>\n";
	$h .= "<hr>\n";
	$h .= "</div>\n"; # clusterdiv
	# configs

	$h .= "Add config for this reservation:<br>\n";
	$h .= resourceStore('config', 1, 'configdetailstore', 1);
	$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"addconfigsel\" ";
	$h .= "style=\"width: 200px\" searchAttr=\"name\" ";
	$h .= "query=\"{deleted: 0, cluster: 0}\" ";
	$h .= "highlightMatch=\"all\" autoComplete=\"false\" ";
	$h .= "queryExpr=\".*\${0}.*\" ";
	$h .= "store=\"configdetailstore\" ";
	$h .= "required=\"false\">\n";
	$h .= "</select>\n";
	$h .= "<button dojoType=\"dijit.form.Button\">\n";
	$h .= "  " . i("Add") . "\n";
	$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$h .= "    addReservationConfig();\n";
	$h .= "  </script>\n";
	$h .= "</button><br>\n";

	$h .= "<table summary=\"\">\n";
	$h .= "<tr>\n";
	$h .= "<td>\n"; # list of configs
	$h .= "Configs mapped to system:<br>\n";
	$h .= "<div id=\"systemconfigdiv\">\n";
	$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"configlist\" ";
	$h .= "style=\"width: 150px; height: 125px;\" ";
	$h .= "selectionMode=\"single\" ";
	$h .= "onSelected=\"configSelected\" ";
	$h .= "sortInfo=\"1\">\n";
	$h .= "<thead>\n";
	$h .= "<tr>\n";
	$h .= "<th field=\"config\" width=\"150px\"></th>\n";
	$h .= "</tr>\n";
	$h .= "</thead>\n";
	$h .= "</table>\n";
	$h .= "</div>\n";
	$h .= "</td>\n"; # end list of configs
	$h .= "<td>\n"; # config variables
	$h .= i("Type:") .  " <span id=\"configtype\"></span><br>\n";
	$h .= i("Apply this config:") . " <input type=\"checkbox\" id=\"configapplychk\" ";
	$h .= "disabled=\"true\" onClick=\"setApplyConfig();\"/><br>\n";
	$h .= "<div id=\"configdatadiv\" class=\"hidden\">\n";
	$h .= "<div id=\"viewconfigdatabtn\" dojoType=\"dijit.form.DropDownButton\" ";
	$h .= "onClick=\"showConfigData();\" disabled=\"true\">\n";
	$h .= "  <span>" . i("View Config Data") . "</span>\n";
	$h .= "  <div dojoType=\"dijit.TooltipDialog\" id=\"configdatadlg\" ";
	$h .= "style=\"width: 30em;\"></div>\n";
	$h .= "</div><br>\n";
	# variables
	$h .= "<div id=\"configvariablediv\">\n";
	$h .= i("Config variables:") . "<br>\n";
	# select
	$h .= "<select dojoType=\"dijit.form.Select\" id=\"configvariables\" ";
	$h .= "style=\"width: 150px\" queryExpr=\"*\${0}*\" ";
	$h .= "highlightMatch=\"all\" autoComplete=\"false\" ";
	$h .= "onChange=\"selectConfigVariable();\" disabled=\"true\"></select><br>\n";
	# key
	$h .= i("Key:") .  " <span id=\"configkey\"></span><br>\n";
	$h .= i("Value:");
	# bool
	$h .= "<span id=\"configvalbool\" class=\"hidden\">\n";
	$h .= selectInputAutoDijitHTML('', array('true', 'false'), 'configvaluebool', 'onChange="saveSelectedConfigVar();"');
	$h .= "</span>\n";
	# int
	$h .= "<span id=\"configvalint\" class=\"hidden\"><input id=\"configvalueint\" ";
	$h .= "style=\"width: 70px;\" dojoType=\"dijit.form.NumberSpinner\" ";
	$h .= "intermediateChanges=\"true\" onChange=\"saveSelectedConfigVar();\" ";
	$h .= "constraints=\"{places:0}\">";
	$h .= "</span>\n";
	# float
	$h .= "<span id=\"configvalfloat\" class=\"hidden\"><input id=\"configvaluefloat\" ";
	$h .= "style=\"width: 70px;\" dojoType=\"dijit.form.NumberSpinner\" ";
	$h .= "intermediateChanges=\"true\" onChange=\"saveSelectedConfigVar();\">";
	$h .= "</span>\n";
	# string
	$h	.= "<span id=\"configvalstring\" class=\"hidden\"><input type=\"text\" ";
	$h .= "id=\"configvaluestring\" style=\"width: 160px\" ";
	$h .= "dojoType=\"dijit.form.ValidationTextBox\" ";
	$h .= "invalidMessage=\"";
	$h .= i("Value can only contain letters, numbers, spaces, dashes(-), parenthesis, <br>slashes(/), and periods(.) and can be from 3 to 255 characters long"); # TODO determine constraints, if any
	$h .= "\" regExp=\"^([-a-zA-Z0-9\. \(\)/]){3,255}$\" onChange=\"saveSelectedConfigVar();\">";
	$h .= "</span>\n";
	# text
	$h .= "<span id=\"configvaltext\" class=\"hidden\">";
	$h .= "<div dojoType=\"dijit.form.Textarea\" ";
	$h .= "id=\"configvaluetext\" style=\"width: 240px\" "; # TODO determine constraints, if any
	$h .= "onKeyUp=\"saveSelectedConfigVar\"></div></span>\n";

	$h .= "<br>\n";
	$h .= i("Required:") .  " <span id=\"configrequired\"></span><br>\n";
	$h .= "</div>\n"; # configvariablediv
	$h .= "</div>\n"; # configdatadiv
	$h .= "</td>\n"; # end config variables
	$h .= "</tr>\n";
	$h .= "</table>\n";
	$h .= "</div>\n";

	$h .= "   <div align=\"center\">\n";
	$h .= "   <button dojoType=\"dijit.form.Button\">\n";
	$h .= "     " . i("Close") . "\n";
	$h .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
	$h .= "       closeConfigureSystem();\n";
	$h .= "     </script>\n";
	$h .= "   </button>\n";
	$h .= "   </div>\n";
	$h .= "</div>\n";
	return $h;
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
		$text = i("The selected reservation is no longer available. You can request a new reservation or select another one that is available.");
		return $text;
	}

	if($request['currstateid'] == 11 ||
	   ($request['currstateid'] == 12 && $request['laststateid'] == 11))
		return "<br><span class=\"rederrormsg\">" . 
		       i("The selected reservation has timed out and is no longer available.") . 
		       "</span>";

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
		($request['currstateid'] == 14 && $request['laststateid'] == 24) ||
		/*($request['currstateid'] == 14 && $request['laststateid'] == 27) ||*/
		($request['currstateid'] == 14 && $request['laststateid'] == 28)) {
		$noinfo =  i("No detailed loading information is available for this reservation.");
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
	$text .= "<th align=right><br>" . i("State") . "</th>";
	$text .= "<th>Est/Act<br>" . i("Time") . "</th>";
	$text .= "<th>Total<br>" . i("Time") . "</th>";
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
			$text .= "<td colspan=3><hr>" . i("problem at state");
			$text .= " \"{$flow['data'][$id]['nextstate']}\"";
			$query = "SELECT additionalinfo "
			       . "FROM computerloadlog "
			       . "WHERE loadstateid = {$flow['repeatid']} AND "
			       .       "reservationid = {$request['resid']} AND "
			       .       "timestamp = '" . unixToDatetime($data['ts']) . "'";
			$qh = doQuery($query, 101);
			if($row = mysql_fetch_assoc($qh)) {
				$reason = $row['additionalinfo'];
				$text .= "<br>" . i("retrying at state") . " \"$reason\"";
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
		$text .= i($flow['data'][$id]['state']) . "($id)</font></td>";
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
					$text = i("No detailed information is available for this reservation.");
					return $text;
				}
				$text .= "<tr>";
				$text .= "<td nowrap align=right><font color=red>";
				$text .= i($flow['data'][$id]['state']) . "($id)</font></td>";
				$text .= "<td nowrap align=center><font color=red>";
				$text .= secToMinSec($flow['data'][$id]['statetime']);
				$text .= $slash . secToMinSec($currtime) . "</font></td>";
				$text .= "<td nowrap align=center><font color=red>";
				$text .= secToMinSec($total + $currtime) . "</font></td>";
				$text .= "</tr>";
				$text .= "</table>";
				if(strlen($reason))
					$text .= "<br><font color=red>" . i("failed:") . " $reason</font>";
				return $text;
			}
			# otherwise add text about current state
			else {
				if(! empty($data))
					$currtime = $now - $data['ts'];
				else
					$currtime = $now - datetimeToUnix($request['daterequested']);
				$text .= "<td nowrap align=right><font color=#CC8500>";
				$text .= i($flow['data'][$id]['state']) . "($id)</font></td>";
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
			$text .= i($flow['data'][$id]['state']) . "($id)</td>";
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
	print "        " . i("Delete Reservation") . "\n";
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
	print "      title=\"" . i("Delete Reservation") . "\"\n";
	print "      duration=250\n";
	print "      draggable=true>\n";
	print "   <div id=\"endResDlgContent\"></div>\n";
	print "   <input type=\"hidden\" id=\"endrescont\">\n";
	print "   <input type=\"hidden\" id=\"endresid\">\n";
	print "   <div align=\"center\">\n";
	print "   <button id=\"endResDlgBtn\" dojoType=\"dijit.form.Button\">\n";
	print "    " . i("Delete Reservation") . "\n";
	print "	   <script type=\"dojo/method\" event=\"onClick\">\n";
	print "       submitDeleteReservation();\n";
	print "     </script>\n";
	print "   </button>\n";
	print "   <button dojoType=\"dijit.form.Button\">\n";
	print "     " . i("Cancel") . "\n";
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
	if(is_null($request) || $request['stateid'] == 11 || $request['stateid'] == 12 ||
	   ($request['stateid'] == 14 && 
	   ($request['laststateid'] == 11 || $request['laststateid'] == 12))) {
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
	$groupid = getUserGroupID('Allow No User Check', 1);
	$members = getUserGroupMembers($groupid);
	if(array_key_exists($user['id'], $members))
		$nousercheck = 1;
	else
		$nousercheck = 0;
	$h = '';

	# determine the current total length of the reservation
	$reslen = ($unixend - unixFloor15($unixstart)) / 60;
	$timeval = getdate($unixstart);
	if(($timeval["minutes"] % 15) != 0)
		$reslen -= 15;
	$cdata = array('requestid' => $requestid,
	               'openend' => $openend,
	               'nousercheck' => $nousercheck,
	               'modifystart' => 0,
	               'allowindefiniteend' => 0);
	# generate HTML
	if($request['serverrequest']) {
		if(empty($request['servername']))
			$request['servername'] = $request['reservations'][0]['prettyimage'];
		$h .= i("Name") . ": <input type=\"text\" name=\"servername\" id=\"servername\" ";
		$h .= "dojoType=\"dijit.form.TextBox\" style=\"width: 330px\" ";
		$h .= "value=\"{$request['servername']}\"><br>";
		if($user['showallgroups'])
			$groups = getUserGroups();
		else
			$groups = getUserGroups(0, $user['affiliationid']);
		$h .= "<div style=\"display: table-row;\">\n";
		$h .= "<div style=\"display: table-cell;\">\n";
		$h .= i("Admin User Group") . ": ";
		$h .= "</div>\n";
		$h .= "<div style=\"display: table-cell;\">\n";
		$disabled = '';
		if($request['stateid'] == 14 && $request['laststateid'] == 24)
			$disabled = "disabled=\"true\"";
		if(USEFILTERINGSELECT && count($groups) < FILTERINGSELECTTHRESHOLD) {
			$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"admingrpsel\" ";
			$h .= "$disabled highlightMatch=\"all\" autoComplete=\"false\">";
		}
		else
			$h .= "<select id=\"admingrpsel\" $disabled>";
		if(! empty($request['admingroupid']) &&
		   ! array_key_exists($request['admingroupid'], $groups)) {
			$id = $request['admingroupid'];
			$name = getUserGroupName($request['admingroupid'], 1);
			$h .= "<option value=\"$id\">$name</option>\n";
		}
		$h .= "<option value=\"0\">" . i("None") . "</option>\n";
		foreach($groups as $id => $group) {
			if($id == $request['admingroupid'])
				$h .= "<option value=\"$id\" selected>{$group['name']}</option>";
			else
				$h .= "<option value=\"$id\">{$group['name']}</option>";
		}
		$h .= "</select><br>";

		$imageinfo = getImages(0, $request['reservations'][0]['imageid']);
		if($imageinfo[$request['reservations'][0]['imageid']]['rootaccess'] == 0) {
			$h .= "<div style=\"width: 240px; margin: 3px 0 3px 0; padding: 1px; border: 1px solid;\">";
			$h .= i("Administrative access has been disabled for this image. Users in the Admin User Group will have control of the reservaion on the Reservations page but will not have administrative access within the reservation.");
			$h .= "</div>\n";
		}
		$h .= "</div>\n";
		$h .= "</div>\n";

		$h .= i("Access User Group") . ": ";
		if(USEFILTERINGSELECT && count($groups) < FILTERINGSELECTTHRESHOLD) {
			$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"logingrpsel\" ";
			$h .= "$disabled highlightMatch=\"all\" autoComplete=\"false\">";
		}
		else
			$h .= "<select id=\"logingrpsel\" $disabled>";
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
	elseif($nousercheck) {
		$extra = array();
		if($request['checkuser'] == 0)
			$extra['checked'] = 'checked';
		$h .= labeledFormItem('newnousercheck', i('Disable timeout for disconnected users'), 'check', '', '', '1', '', '', $extra);
		$h .= "<br>\n";
	}
	// if future, allow start to be modified
	if($unixstart > $now) {
		$tzunixstart = $unixstart + ($_SESSION['persistdata']['tzoffset'] * 60);
		$cdata['modifystart'] = 1;
		$txt  = i("Modify reservation for") . " <b>{$request['reservations'][0]['prettyimage']}</b> "; 
		$txt .= i("starting") . " " . prettyDatetime($request["start"]) . ": <br>";
		$h .= preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $txt);
		$days = array();
		$startday = date('l', $tzunixstart);
		$cur = time() + ($_SESSION['persistdata']['tzoffset'] * 60);
		for($end = $cur + DAYSAHEAD * SECINDAY; 
		    $cur < $end; 
		    $cur += SECINDAY) {
			$index = date('Ymd', $cur);
			$days[$index] = date('l', $cur);
		}
		$cdata['startdays'] = array_keys($days);
		$h .= i("Start") . ": <select dojoType=\"dijit.form.Select\" id=\"day\" ";
		$h .= "onChange=\"resetEditResBtn();\">";
		foreach($days as $id => $name) {
			if($name == $startday)
				$h .= "<option value=\"$id\" selected=\"selected\">$name</option>";
			else
				$h .= "<option value=\"$id\">$name</option>";
		}
		$h .= "</select>";
		$h .= i("&nbsp;At&nbsp;");
		$tmp = datetimeToUnix($request['start']) + ($_SESSION['persistdata']['tzoffset'] * 60);
		$tmp = unixToDatetime($tmp);
		$tmp = explode(' ' , $tmp);
		$stime = $tmp[1];
		$h .= "<div type=\"text\" dojoType=\"dijit.form.TimeTextBox\" ";
		$h .= "id=\"editstarttime\" style=\"width: 78px\" value=\"T$stime\" ";
		$h .= "onChange=\"resetEditResBtn();\"></div><br><br>";
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
			$h .= "<label for=\"indefiniteradio\">" . i("Indefinite Ending") . "</label>";
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
				$lengths["30"] = "30 " . i("minutes");
				if($durationmin == 30)
					$durationmatch = 1;
			}
			if($maxtimes["initial"] >= 45) {
				$lengths["45"] = "45 " . i("minutes");
				if($durationmin == 45)
					$durationmatch = 1;
			}
			if($maxtimes["initial"] >= 60) {
				$lengths["60"] = "1 " . i("hour");
				if($durationmin == 60)
					$durationmatch = 1;
			}
			for($i = 120; $i <= $maxtimes["initial"] && $i < 2880; $i += 120) {
				$lengths[$i] = $i / 60 . " " . i("hours");
				if($durationmin == $i)
					$durationmatch = 1;
			}
			for($i = 2880; $i <= $maxtimes["initial"]; $i += 1440) {
				$lengths[$i] = $i / 1440 . " " . i("days");
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
			$h .= i("Duration") . ':';
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

				$tmp = datetimeToUnix($request['end']) + ($_SESSION['persistdata']['tzoffset'] * 60);
				$tmp = unixToDatetime($tmp);
				$tmp = explode(' ', $tmp);
				$edate = $tmp[0];
				$etime = $tmp[1];
			}
			$h .= "<label for=\"dateradio\">";
			$h .= i("End:");
			$h .= "</label>";
			$h .= "<div type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
			$h .= "id=\"openenddate\" style=\"width: 78px\" value=\"$edate\" ";
			$h .= "onChange=\"selectEnding();\"></div>";
			$h .= "<div type=\"text\" dojoType=\"dijit.form.TimeTextBox\" ";
			$h .= "id=\"openendtime\" style=\"width: 78px\" value=\"T$etime\" ";
			$h .= "onChange=\"selectEnding();\"></div>";
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
		$h  = sprintf(i("You are only allowed to extend your reservation such that it has a total length of %s. "), minToHourMin($maxcheck));
		$h .= i("This reservation already meets that length. Therefore, you are not allowed to extend your reservation any further.");
		$h = preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $h) . "<br>";
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
		$lockedall = 1;
		if(count($request['reservations']) > 1) {
			# get semaphore on each existing node in cluster so that nothing 
			# can get moved to the nodes during this process

			$semimageid = getImageId('noimage');
			$semrevid = getProductionRevisionid($semimageid);
			$checkend = unixToDatetime($unixend + 900);
			foreach($request["reservations"] as $res) {
				if(! retryGetSemaphore($semimageid, $semrevid, $res['managementnodeid'], $res['computerid'], $request['start'], $checkend, $requestid)) {
					$lockedall = 0;
					break;
				}
			}
		}
		if($lockedall) {
			foreach($request["reservations"] as $res) {
				if(! moveReservationsOffComputer($res["computerid"], 1)) {
					$movedall = 0;
					break;
				}
			}
		}
		cleanSemaphore();
		if(! $request['serverrequest'] && (! $movedall || ! $lockedall)) {
			$msg = i("The computer you are using has another reservation immediately following yours. Therefore, you cannot extend your reservation because it would overlap with the next one.");
			$h  = preg_replace("/(.{1,60}( |$))/", '\1<br>', $msg) . "<br>";
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
		if($nousercheck)
			$lengths["0"] = "No change";
		// there is no following reservation
		if((($reslen + 15) <= $maxtimes["total"]) && (15 <= $maxtimes["extend"]))
			$lengths["15"] = "15 " . i("minutes");
		if((($reslen + 30) <= $maxtimes["total"]) && (30 <= $maxtimes["extend"]))
			$lengths["30"] = "30 " . i("minutes");
		if((($reslen + 45) <= $maxtimes["total"]) && (45 <= $maxtimes["extend"]))
			$lengths["45"] = "45 " . i("minutes");
		if((($reslen + 60) <= $maxtimes["total"]) && (60 <= $maxtimes["extend"]))
			$lengths["60"] = i("1 hour");
		for($i = 120; (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]) && $i < 2880; $i += 120)
			$lengths[$i] = $i / 60 . " " . i("hours");
		for($i = 2880; (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]) && $i < 64800; $i += 1440)
			$lengths[$i] = $i / 1440 . " " . i("days");
		for($i = 70560; (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]); $i += 10080)
			$lengths[$i] = $i / 10080 . " " . i("weeks");
	}
	else {
		if($nousercheck)
			$lengths["0"] = "No change";
		if($timeToNext >= 15 && (($reslen + 15) <= $maxtimes["total"]) && (15 <= $maxtimes["extend"]))
			$lengths["15"] = "15 " . i("minutes");
		if($timeToNext >= 30 && (($reslen + 30) <= $maxtimes["total"]) && (30 <= $maxtimes["extend"]))
			$lengths["30"] = "30 " . i("minutes");
		if($timeToNext >= 45 && (($reslen + 45) <= $maxtimes["total"]) && (45 <= $maxtimes["extend"]))
			$lengths["45"] = "45 " . i("minutes");
		if($timeToNext >= 60 && (($reslen + 60) <= $maxtimes["total"]) && (60 <= $maxtimes["extend"]))
			$lengths["60"] = i("1 hour");
		for($i = 120; ($i <= $timeToNext) && (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]) && $i < 2880; $i += 120)
			$lengths[$i] = $i / 60 . " " . i("hours");
		for($i = 2880; ($i <= $timeToNext) && (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]) && $i < 64800; $i += 1440)
			$lengths[$i] = $i / 1440 . " " . i("days");
		for($i = 70560; ($i <= $timeToNext) && (($reslen + $i) <= $maxtimes["total"]) && ($i <= $maxtimes["extend"]); $i += 10080)
			$lengths[$i] = $i / 10080 . " " . i("weeks");
	}
	$cdata['lengths'] = array_keys($lengths);
	if($timeToNext == -1 || $timeToNext >= $maxtimes['total']) {
		if($openend) {
			if(($nousercheck == 0 && ! empty($lengths)) || ($nousercheck == 1 && count($lengths) > 1)) {
				$m = i("You can extend this reservation by a selected amount or change the end time to a specified date and time.");
				$h .= preg_replace("/(.{1,55}([ \n]|$))/", '\1<br>', $m) . "<br>";
			}
			else
				$h .= i("Modify the end time for this reservation:") . "<br><br>";
		}
		else {
			if($request['forimaging'] && $maxtimes['total'] < 720)
				$maxcheck = 720;
			else
				$maxcheck = $maxtimes['total'];
			$m = sprintf(i("You can extend this reservation by up to %s but not exceeding %s for your total reservation time."),
			             minToHourMin($maxtimes['extend']), minToHourMin($maxcheck));
			$h .= preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $m) . "<br>";
		}
	}
	elseif(! $request['serverrequest']) {
		$m = sprintf(i("The computer you are using has another reservation following yours. Therefore, you can only extend this reservation for another %s."),
			          prettyLength($timeToNext));
		$h .= preg_replace("/(.{1,60}( |$))/", '\1<br>', $m);
	}
	# extend by drop down
	# extend by specifying end time if $openend
	$noindefinite = 0;
	if($openend) {
		if($request['serverrequest']) {
			$cdata['allowindefiniteend'] = 1;
			$endchecked = 0;
			if($request['end'] == '2038-01-01 00:00:00') {
				$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"indefiniteradio\" ";
				$h .= "checked onChange=\"resetEditResBtn();\">";
				$h .= "<label for=\"indefiniteradio\">" . i("Indefinite Ending") . "</label>";
				$h .= "<br><INPUT type=\"radio\" name=\"ending\" id=\"dateradio\" ";
				$h .= "onChange=\"resetEditResBtn();\">";
			}
			else {
				$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"indefiniteradio\" ";
				$h .= "onChange=\"resetEditResBtn();\">";
				$h .= "<label id=\"indefinitelabel\" for=\"indefiniteradio\">";
				$h .= i("Indefinite Ending") . "</label>";
				$h .= "<br><INPUT type=\"radio\" name=\"ending\" id=\"dateradio\" ";
				$h .= "checked onChange=\"resetEditResBtn();\">";
				$endchecked = 1;
			}
			$h .= "<label for=\"dateradio\">";
		}
		elseif(($nousercheck == 0 && ! empty($lengths)) || ($nousercheck == 1 && count($lengths) > 1)) {
			$h .= "<INPUT type=\"radio\" name=\"ending\" id=\"lengthradio\" ";
			$h .= "checked onChange=\"resetEditResBtn();\">";
			$h .= "<label for=\"lengthradio\">" . i("Extend reservation by:") . "</label>";
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
			$h .= i("End:");
			if($endchecked) {
				$tmp = datetimeToUnix($request['end']) + ($_SESSION['persistdata']['tzoffset'] * 60);
				$tmp = unixToDatetime($tmp);
				$tmp = explode(' ', $tmp);
				$edate = $tmp[0];
				$etime = $tmp[1];
			}
			else {
				$edate = '';
				$etime = '';
			}
		}
		else {
			$h .= i("Change ending to:");
			$tmp = datetimeToUnix($request['end']) + ($_SESSION['persistdata']['tzoffset'] * 60);
			$tmp = unixToDatetime($tmp);
			$tmp = explode(' ', $tmp);
			$edate = $tmp[0];
			$etime = $tmp[1];
		}
		if(($nousercheck == 0 && ! empty($lengths)) ||
		   ($nousercheck == 1 && count($lengths) > 1) ||
		   $request['serverrequest'])
			$h .= "</label>";
		$h .= "<div type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
		$h .= "id=\"openenddate\" style=\"width: 78px\" value=\"$edate\" ";
		$h .= "onChange=\"selectEnding();\"></div>";
		$h .= "<div type=\"text\" dojoType=\"dijit.form.TimeTextBox\" ";
		$h .= "id=\"openendtime\" style=\"width: 78px\" value=\"T$etime\" ";
		$h .= "onChange=\"selectEnding();\"></div>";
		$h .= "<INPUT type=\"hidden\" name=\"enddate\" id=\"enddate\">";
		if($request['serverrequest'] && $timeToNext == 0) {
			$h .= "<br><br><font color=red>";
			$m = "<strong>" . i("NOTE:") . "</strong> ";
			$m .=	i("Due to an upcoming reservation on the same computer, you cannot extend this reservation.");
			$h .= preg_replace("/(.{1,80}([ \n]|$))/", '\1<br>', $m);
			$h .= "</font>";
			$noindefinite = 1;
		}
		elseif($timeToNext > -1) {
			$extend = $unixend + ($timeToNext * 60);
			$extend = date('m/d/Y g:i A', $extend);
			$h .= "<br><br><font color=red>";
			$m = "<strong>" . i("NOTE:") . "</strong> ";
			$m .= sprintf(i("Due to an upcoming reservation on the same computer, you can only extend this reservation until %s."),
			              $extend);
			$h .= preg_replace("/(.{1,80}([ \n]|$))/", '\1<br>', $m);
			$h .= "</font>";
			$cdata['maxextend'] = $extend;
			$noindefinite = 1;
		}
	}
	else {
		$h .= i("Extend reservation by:");
		$h .= "<select dojoType=\"dijit.form.Select\" id=\"length\">";
		foreach($lengths as $id => $name)
			$h .= "<option value=\"$id\">$name</option>";
		$h .= "</select>";
	}
	$h .= "<br>";
	$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
	$data = array('status' => 'modify',
	              'html' => $h,
	              'requestid' => $requestid,
	              'cont' => $cont);
	if($noindefinite)
		$data['status'] = 'noindefinite';
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
	$allownousercheck = getContinuationVar('nousercheck');
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
		               'html' => i('The selected reservation no longer exists.') . '<br><br>',
		               'cont' => $cont));
		return;
	}

	if($modifystart) {
		$day = processInputVar('day', ARG_NUMERIC, 0);
		if(! in_array($day, $startdays)) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => i('Invalid start day submitted'),
			               'cont' => $cont));
			return;
		}
		$starttime = processInputVar('starttime', ARG_STRING);
		if(! preg_match('/^(([01][0-9])|(2[0-3]))([0-5][0-9])$/', $starttime, $matches)) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => i("Invalid start time submitted"),
			               'cont' => $cont));
			return;
		}
		preg_match('/^([0-9]{4})([0-9]{2})([0-9]{2})$/', $day, $tmp);
		$startdt = "{$tmp[1]}-{$tmp[2]}-{$tmp[3]} {$matches[1]}:{$matches[4]}:00";
		$startts = datetimeToUnix($startdt) - ($_SESSION['persistdata']['tzoffset'] * 60);
		if($startts < time()) {
			$cdata = getContinuationVar();
			$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
			sendJSON(array('status' => 'error',
			               'errmsg' => i('The submitted start time is in the past.'),
			               'cont' => $cont));
			return;
		}
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
			               'errmsg' => i("Invalid duration submitted"),
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
			               'errmsg' => i("Invalid end date/time submitted"),
			               'cont' => $cont));
			return;
		}
		$enddt = "{$tmp[1]}-{$tmp[2]}-{$tmp[3]} {$tmp[4]}:{$tmp[7]}:00";
		$endts = datetimeToUnix($enddt) - ($_SESSION['persistdata']['tzoffset'] * 60);;
	}
	elseif($allowindefiniteend && $endmode == 'indefinite') {
		$endts = datetimeToUnix('2038-01-01 00:00:00');
		$enddt = unixToDatetime($endts);
	}
	else {
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		sendJSON(array('status' => 'error',
		               'errmsg' => i("Invalid data submitted"),
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
			               'errmsg' => i("Invalid user group submitted"),
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
			               'errmsg' => i("The name can only contain letters, numbers, spaces, dashes(-), and periods(.) and can be from 3 to 255 characters long"),
			               'cont' => $cont));
			return;
		}
		if($servername != $request['servername']) {
			$servername = mysql_real_escape_string($servername);
			$updateservername = 1;
		}
	}

	$updateusercheck = 0;
	$otherupdatesokay = 0;
	if($updategroups || $updateservername || $allownousercheck) {
		$serversets = array();
		$reqsets = array();
		if($updategroups && $request['laststateid'] != 24) {
			if($admingroupid == 0)
				$admingroupid = 'NULL';
			if($logingroupid == 0)
				$logingroupid = 'NULL';
			$serversets[] = "admingroupid = $admingroupid";
			$serversets[] = "logingroupid = $logingroupid";
			addChangeLogEntryOther($request['logid'], "event:usergroups|admingroupid:$admingroupid|logingroupid:$logingroupid");
			$reqsets[] = "stateid = 29";
			$reqsets[] = "datemodified = NOW()";
		}

		if($updateservername)
			$serversets[] = "name = '$servername'";

		if($allownousercheck) {
			$newnousercheck = processInputVar('newnousercheck', ARG_NUMERIC);
			if(($newnousercheck == 1 || $newnousercheck == 0) &&
				($newnousercheck == $request['checkuser'])) {
				$reqsets[] = "checkuser = (1 - checkuser)";
				$updateusercheck = 1;
			}
		}

		if(count($serversets)) {
			$sets = implode(',', $serversets);
			$query = "UPDATE serverrequest "
			       . "SET $sets "
			       . "WHERE requestid = $requestid";
			doQuery($query);
			$otherupdatesokay = 1;
		}
		if(count($reqsets)) {
			$sets = implode(',', $reqsets);
			$query = "UPDATE request "
			       . "SET $sets "
			       . "WHERE id = $requestid";
			doQuery($query);
			$otherupdatesokay = 1;
		}
		if($startdt == $request['start'] && $enddt == $request['end']) {
			sendJSON(array('status' => 'success'));
			return;
		}
	}

	$h = '';
	$max = getMaxOverlap($user['id']);
	if(checkOverlap($startts, $endts, $max, $requestid)) {
		if($max == 0) {
			$m = i("The time you requested overlaps with another reservation you currently have. You are only allowed to have a single reservation at any given time. Please select another time for the reservation.");
			$h .= preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $m) . "<br>";
		}
		else {
			$m = sprintf(i("The time you requested overlaps with another reservation you currently have. You are allowed to have %s overlapping reservations at any given time. Please select another time for the reservation."),
			             $max);
			$h .= preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $m) . "<br>";
		}
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$arr = array('status' => 'error', 'errmsg' => $h, 'cont' => $cont);
		if($otherupdatesokay)
			$arr['partialupdate'] = i("Settings not related to start/end time were successfully updated.");
		sendJSON($arr);
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
	$revisions = array();
	foreach($request['reservations'] as $key => $res)
		$revisions[$res['imageid']][$key] = $res['imagerevisionid'];
	$rc = isAvailable($images, $imageid, $revisions, $startts,
	                  $endts, 1, $requestid, 0, 0, 0, $ip, $mac);
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
		$h .= sprintf(i("The reserved IP (%s) or MAC address (%s) conflicts with another reservation using the same IP or MAC address. Please select a different time to use the image."), $msgip, $msgmac);
		$h = preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $h);
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data['status'] = 'conflict';
		$data['errmsg'] = $h;
		$data['cont'] = $cont;
		if($otherupdatesokay)
			$data['partialupdate'] = i("Settings not related to start/end time were successfully updated.");
		sendJSON($data);
		return;
	}
	elseif($rc == -2) {
		$m = i("The time you requested overlaps with a maintenance window. Please select a different time to use the image.");
		$h .= preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $m) . "<br>";
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data['status'] = 'conflict';
		$data['errmsg'] = $h;
		$data['cont'] = $cont;
		if($otherupdatesokay)
			$data['partialupdate'] = i("Settings not related to start/end time were successfully updated.");
		sendJSON($data);
		return;
	}
	elseif($rc == -1) {
		$m = i("The reservation you are modifying is for an environment limited in the number of concurrent reservations that can be made. The time or duration you have requested overlaps with too many other reservations for the same image. Please select another time or duration for the reservation.");
		$h .= preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $m) . "<br>";
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data['status'] = 'conflict';
		$data['errmsg'] = $h;
		$data['cont'] = $cont;
		if($otherupdatesokay)
			$data['partialupdate'] = i("Settings not related to start/end time were successfully updated.");
		sendJSON($data);
		return;
	}
	elseif($rc > 0) {
		$oldstartts = datetimeToUnix($request['start']);
		$nowfuture = 'now';
		if($oldstartts > time())
			$nowfuture = 'future';
		updateRequest($requestid, $nowfuture);
		sendJSON(array('status' => 'success'));
		cleanSemaphore();
		return;
	}
	else {
		$m = i("The time period you have requested is not available. Please select a different time.");
		$h .= preg_replace("/(.{1,55}([ \n]|$))/", '\1<br>', $m) . "<br>";
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJsubmitEditRequest', $cdata, SECINDAY, 1, 0);
		$data['status'] = 'conflict';
		$data['errmsg'] = $h;
		$data['cont'] = $cont;
		if($otherupdatesokay)
			$data['partialupdate'] = i("Settings not related to start/end time were successfully updated.");
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
	global $user;
	$requestid = getContinuationVar('requestid', 0);
	$notbyowner = getContinuationVar('notbyowner', 0);
	$fromtimetable = getContinuationVar('fromtimetable', 0);
	$skipconfirm = processInputVar('skipconfirm', ARG_NUMERIC, 0);
	if($skipconfirm != 0 && $skipconfirm != 1)
		$skipconfirm = 0;
	$request = getRequestInfo($requestid, 1);
	if(is_null($request)) {
		$data = array('error' => 1,
		              'refresh' => 1,
		              'msg' => i("The specified reservation no longer exists."));
		sendJSON($data);
		return;
	}
	if($request['stateid'] == 11 || $request['stateid'] == 12 ||
	   ($request['stateid'] == 14 && 
	   ($request['laststateid'] == 11 || $request['laststateid'] == 12))) {
		$data = array('error' => 1,
		              'refresh' => 1,
		              'msg' => i("This reservation has timed out due to lack of user activity and is no longer available."));
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
	if(! $skipconfirm && $user['id'] != $request['userid']) {
		$data = array('status' => 'serverconfirm');
		sendJSON($data);
		return;
	}
	if(datetimeToUnix($request["start"]) > time()) {
		$text = sprintf(i("Delete reservation for %s starting %s?"),
		                "<b>{$reservation["prettyimage"]}</b>",
		                prettyDatetime($request["start"]));
	}
	else {
		if($notbyowner == 0 && ! $reservation["production"] && count($request['reservations']) == 1) {
			AJconfirmDeleteRequestProduction($request);
			return;
		}
		else {
			if(datetimeToUnix($request["start"]) <
				datetimeToUnix($request["daterequested"]))
				$dtstart = $request["daterequested"];
			else
				$dtstart = $request["start"];
			$tsstart = datetimeToUnix($dtstart);
			if($tsstart < time() - SECINMONTH * 6)
				$showstart = prettyDatetime($dtstart, 1);
			else
				$showstart = prettyDatetime($dtstart);
			if($notbyowner == 0) {
				$text = sprintf(i("Are you finished with your reservation for %s that started %s?"),
				                "<b>{$reservation["prettyimage"]}</b>", $showstart);
			}
			else {
				$userinfo = getUserInfo($request["userid"], 1, 1);
				$text = sprintf(i("Delete reservation by %s for %s that started %s?"),
				                "{$userinfo['unityid']}@{$userinfo['affiliation']}",
				                "<b>{$reservation["prettyimage"]}</b>",
				                $showstart);
			}
		}
	}
	$cdata = array('requestid' => $requestid,
	               'notbyowner' => $notbyowner,
	               'fromtimetable' => $fromtimetable);
	if($fromtimetable)
		$cdata['ttdata'] = getContinuationVar('ttdata');
	$cont = addContinuationsEntry('AJsubmitDeleteRequest', $cdata, SECINDAY, 0, 0);
	$text .= "<br><br>";
	$data = array('content' => $text,
	              'cont' => $cont,
	              'requestid' => $requestid,
	              'status' => 'success',
	              'btntxt' => i('Delete Reservation'));
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
	$title = "<big><b>" . i("End Reservation/Make Production") . "</b></big><br><br>";
	$text .=	i("Are you satisfied that this environment is ready to be made production and replace the current production version, or would you just like to end this reservation and test it again later?");

	if(isImageBlockTimeActive($request['reservations'][0]['imageid'])) {
		$text .= "<br><font color=\"red\">\n";
		$text .= i("WARNING: This environment is part of an active block allocation. Changing the production version of the environment at this time will result in new reservations under the block allocation to have full reload times instead of a &lt; 1 minutes wait. You can change the production version later by going to Manage Images-&gt;Edit Image Profiles and clicking Edit for this environment.");
		$text .= "</font><br>";
	}

	$cont = addContinuationsEntry('AJsetImageProduction', $cdata, SECINDAY, 0, 1);
	$radios = '';
	$radios .= "<br>&nbsp;&nbsp;&nbsp;<INPUT type=radio name=continuation ";
	$radios .= "value=\"$cont\" id=\"radioprod\"><label for=\"radioprod\">";
	$radios .= i("Make this the production version") . "</label><br>";

	$cont = addContinuationsEntry('AJsubmitDeleteRequest', $cdata, SECINDAY, 0, 0);
	$radios .= "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=continuation ";
	$radios .= "value=\"$cont\" id=\"radioend\"><label for=\"radioend\">";
	$radios .= i("Just end the reservation") . "</label><br><br>";
	$text = preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $text);
	$data = array('content' => $title . $text . $radios,
	              'cont' => $cont,
	              'btntxt' => i('Submit'));
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
		              'msg' => i("The specified reservation no longer exists."));
		sendJSON($data);
		return;
	}
	if($request['stateid'] != 11 && $request['laststateid'] != 11 &&
	   $request['stateid'] != 12 && $request['laststateid'] != 12 &&
	   $request['stateid'] !=  5 && $request['laststateid'] !=  5) {
		$data = array('error' => 2,
		              'msg' => i("The reservation is no longer failed or timed out."),
		              'url' => BASEURL . SCRIPT . "?mode=viewRequests");
		sendJSON($data);
		return;
	}
	if($request['stateid'] == 11 || $request['stateid'] == 12 ||
	   $request['stateid'] == 12 || $request['laststateid'] == 12) {
		$text  = i("Remove timed out reservation from list of current reservations?");
		$text .= "<br>\n";
	}
	else {
		$text  = i("Remove failed reservation from list of current reservations?");
		$text .= "<br>\n";
	}
	$cdata = array('requestid' => $requestid);
	$cont = addContinuationsEntry('AJsubmitRemoveRequest', $cdata, SECINDAY, 0, 0);
	$text = preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $text);
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
		$query = "SELECT id FROM serverrequest WHERE requestid = $requestid";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh)) {
			$query = "DELETE FROM serverrequest WHERE requestid = $requestid";
			doQuery($query, 152);
			deleteVariable("fixedIPsr{$row['id']}");
		}
	}

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
	if(is_null($reqdata) || $reqdata['stateid'] == 11 || $reqdata['stateid'] == 12 ||
	   ($reqdata['stateid'] == 14 && 
	   ($reqdata['laststateid'] == 11 || $reqdata['laststateid'] == 12))) {
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
	if(is_null($reqdata) || $reqdata['stateid'] == 11 || $reqdata['stateid'] == 12 ||
	   ($reqdata['stateid'] == 14 && 
	   ($reqdata['laststateid'] == 11 || $reqdata['laststateid'] == 12))) {
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
		$m = i("This will cause the reserved machine to be reinstalled. You may select which version of the environment you would like to use for the reinstall. The currently installed version is initally selected.");
		$t .= preg_replace("/(.{1,85}([ \n]|$))/", '\1<br>', $m) . "<br>";
		$t .= "<table summary=\"lists versions of the environment\">";
		$t .= "<TR>";
		$t .= "<TD></TD>";
		$t .= "<TH>" . i("Version") . "</TH>";
		$t .= "<TH>" . i("Creator") . "</TH>";
		$t .= "<TH>" . i("Created") . "</TH>";
		$t .= "<TH>" . i("Currently in Production") . "</TH>";
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
				$t .= "<TD align=center>" . i("Yes") . "</TD>";
			else
				$t .= "<TD align=center>" . i("No") . "</TD>";
			$t .= "</TR>";
		}
		$t .= "</table><br>";
		$t .= "<strong>" . i("NOTE:") . "</strong> ";
	}
	else
		$t .= i("This will cause the reserved machine to be reinstalled.") . "<br>";
	$t .= i("Any data saved only to the reserved machine <strong>will be lost</strong>.") . "<br>";
	$t .= i("Are you sure you want to continue?") . "<br><br>";
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
/// \fn AJconnectRequest()
///
/// \brief generates data to explain to user how to connect to a reservation;
/// sets IPaddress for the request
///
////////////////////////////////////////////////////////////////////////////////
function AJconnectRequest() {
	global $remoteIP, $user;
	$requestid = getContinuationVar('requestid');
	$requestData = getRequestInfo($requestid, 1);
	if(is_null($requestData)) {
		$h = i("This reservation is no longer available.");
		sendJSON(array('html' => $h, 'refresh' => 1));
		return;
	}
	if($requestData['stateid'] == 11 || $requestData['stateid'] == 12 ||
	   ($requestData['stateid'] == 14 && 
	   ($requestData['laststateid'] == 11 || $requestData['laststateid'] == 12))) {
		$h = i("This reservation has timed out due to lack of user activity and is no longer available.");
		sendJSON(array('html' => $h, 'refresh' => 1));
		return;
	}
	$h = '';
	$now = time();
	if($requestData['reservations'][0]['remoteIP'] != $remoteIP) {
		$query = "UPDATE reservation "
		       . "SET remoteIP = '$remoteIP' "
		       . "WHERE requestid = $requestid";
		$qh = doQuery($query, 226);

		addChangeLogEntry($requestData["logid"], $remoteIP);
		if($requestData['reservations'][0]['remoteIP'] == '')
			addConnectTimeout($requestData['reservations'][0]['reservationid'],
			                  $requestData['reservations'][0]['computerid']);
	}

	$timeout = getReservationNextTimeout($requestData['reservations'][0]['reservationid']);
	if(! is_null($timeout))
		$h .= "<input type=\"hidden\" id=\"connecttimeout\" value=\"$timeout\">\n";

	if($requestData['forimaging']) {
		$h .= "<font color=red><big>";
		$m = "<strong>" . i("NOTICE:") . "</strong> ";
		$m .= i("Later in this process, you must accept a <a>click-through agreement</a> about software licensing.");
		$h .= preg_replace('|<a>(.+)</a>|', '<a href="' . BASEURL . SCRIPT . '?mode=viewRequests#" onClick="previewClickThrough();">\1</a>', $m);
		$h .= "</big></font><br><br>\n";
	}
	$imagenotes = getImageNotes($requestData['reservations'][0]['imageid']);
	if(! preg_match('/^\s*$/', $imagenotes['usage'])) {
		$h .= "<h3>" . i("Notes on using this environment:") . "</h3>\n";
		$h .= "{$imagenotes['usage']}<br><br><br>\n";
	}
	if(count($requestData["reservations"]) > 1)
		$cluster = 1;
	else
		$cluster = 0;
	if($cluster) {
		$h .= "<h2>" . i("Cluster Reservation") . "</h2>\n";
		$h .= i("This is a cluster reservation. Depending on the makeup of the cluster, you may need to use different methods to connect to the different environments in your cluster.");
		$h .= "<br><br>\n";
	}
	foreach($requestData["reservations"] as $key => $res) {
		$osname = $res["OS"];
		if(array_key_exists($user['id'], $requestData['passwds'][$res['reservationid']]))
			$passwd = $requestData['passwds'][$res['reservationid']][$user['id']];
		else
			$passwd = '';
		$connectData = getImageConnectMethodTexts($res['imageid'],
		                                          $res['imagerevisionid']);
		$natports = getNATports($res['reservationid']);
		$usenat = 0;
		if(count($natports))
			$usenat = 1;
		$first = 1;
		if($cluster) {
			$h .= "<fieldset>\n";
			$h .= "<legend><big><b>{$res['prettyimage']}</b></big></legend>\n";
		}
		foreach($connectData as $cmid => $method) {
			if($first)
				$first = 0;
			else
				$h .= "<hr>\n";
			if(preg_match('/(.*)@(.*)/', $user['unityid'], $matches))
				$conuser = $matches[1];
			else
				$conuser = $user['unityid'];
			if($requestData['reservations'][0]['domainDNSName'] != '' && ! strlen($passwd))
				$conuser .= "@" . $requestData['reservations'][0]['domainDNSName'];
			if(! strlen($passwd))
				$passwd = i('(use your campus password)');
			if($cluster)
				$h .= "<h4>" . i("Connect to reservation using") . " {$method['description']}</h4>\n";
			else
				$h .= "<h3>" . i("Connect to reservation using") . " {$method['description']}</h3>\n";
			$froms = array('/#userid#/',
			               '/#password#/',
			               '/#connectIP#/');
			# check that connecttext includes port if nat is being used
			if($usenat) {
				$found = 0;
				foreach($method['ports'] as $port) {
					if(preg_match("/{$port['key']}/", $method['connecttext'])) {
						$found = 1;
						break;
					}
				}
				if(! $found) {
					# no port in connect text, assume first port will work
					$method['connecttext'] = preg_replace("/#connectIP#/", "#connectIP#:{$method['ports'][0]['key']}", $method['connecttext']);
				}
			}
			$tos = array($conuser,
			             $passwd,
			             $res['connectIP']);
			$msg = preg_replace($froms, $tos, $method['connecttext']); 
			foreach($method['ports'] as $port) {
				if($usenat && array_key_exists($port['key'], $natports[$cmid]))
					$msg = preg_replace("/{$port['key']}/", $natports[$cmid][$port['key']]['publicport'], $msg); 
				else {
					if((preg_match('/remote desktop/i', $method['description']) ||
					   preg_match('/RDP/i', $method['description'])) && 
					   $port['key'] == '#Port-TCP-3389#')
						$msg = preg_replace("/{$port['key']}/", $user['rdpport'], $msg); 
					else
						$msg = preg_replace("/{$port['key']}/", $port['port'], $msg); 
				}
			}
			#$h .= preg_replace("/(.{1,120}([ ]|$))/", '\1<br>', $msg);
			$h .= $msg;
			if(preg_match('/remote desktop/i', $method['description']) ||
			   preg_match('/RDP/i', $method['description'])) {
				#$h .= "<div id=\"counterdiv\" class=\"hidden\"></div>\n";
				#$h .= "<div id=\"connectdiv\">\n";
				$h .= "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
				$cdata = array('requestid' => $requestid,
				               'resid' => $res['reservationid']);
				$expire = datetimeToUnix($requestData['end']) - $now + 1800; # remaining reservation time plus 30 min
				$cont = addContinuationsEntry('sendRDPfile', $cdata, $expire);
				$h .= "<INPUT type=hidden name=continuation value=\"$cont\">\n";
				$h .= "<INPUT type=submit value=\"" . i("Get RDP File") . "\">\n";
				$h .= "</FORM>\n";
				#$h .= "</div>\n";
			}
		}
		if($cluster)
			$h .= "</fieldset><br>\n";
	}
	$cdata = array('requestid' => $requestid);
	$cont = addContinuationsEntry('AJcheckConnectTimeout', $cdata, SECINDAY);
	$h .= "<input type=\"hidden\" id=\"refreshcont\" value=\"$cont\">\n";
	$return = array('html' => $h);
	if(! is_null($timeout)) {
		$return['timeoutid'] = "timeoutvalue|$requestid";
		// if reservation in reserved state, set timeout to 1 minute later so that Reservation
		// contents get reloaded hopefully after the user has connected and the state has been
		// updated to inuse so that More Options items can bet updated accordingly
		if($requestData['laststateid'] == 3 && $requestData['stateid'] == 14)
			$timeout = time() + 60;
		$return['timeout'] = $timeout;
	}
	sendJSON($return);
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
		$stateid = $reqdata['laststateid'];
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
function processRequestInput() {
	global $user;
	$baseaccess = getContinuationVar('baseaccess', 0);
	$imagingaccess = getContinuationVar('imagingaccess', 0);
	$serveraccess = getContinuationVar('serveraccess', 0);
	$openend = getContinuationVar('openend', 0);
	$nousercheck = getContinuationVar('nousercheck', 0);
	$return['imaging'] = getContinuationVar('imaging', 0);
	$maxinitial = getContinuationVar('maxinitial', 0);
	$noimaging = getContinuationVar('noimaging', array());

	$return = array('err' => 0);

	# type
	$return['type'] = processInputVar('type', ARG_STRING);
	if(! preg_match('/^basic|imaging|server$/', $return['type'])) {
		$return['err'] = 1;
		$return['errmsg'] = i('Invalid data submitted');
		return $return;
	}
	if(($return['type'] == 'basic' && ! $baseaccess) ||
	   ($return['type'] == 'imaging' && ! $imagingaccess) ||
	   ($return['type'] == 'server' && ! $serveraccess)) {
		$return['err'] = 1;
		$return['errmsg'] = i('No access to submitted reservation type');
		return $return;
	}

	# ending
	$return['ending'] = processInputVar('ending', ARG_STRING);
	if(! preg_match('/^indefinite|endat|duration$/', $return['ending'])) {
		$return['err'] = 1;
		$return['errmsg'] = i('Invalid data submitted');
		return $return;
	}
	if(($return['ending'] == 'duration' && ! $baseaccess) ||
	   ($return['ending'] == 'indefinite' && ! $serveraccess) ||
		($return['ending'] == 'endat' && ! $openend && ! $serveraccess)) {
		$return['err'] = 1;
		$return['errmsg'] = i('No access to submitted end type');
		return $return;
	}

	# imageid
	$return['imageid'] = processInputVar('imageid', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$withnocheckout = $resources['image'];
	$images = removeNoCheckout($resources["image"]);
	#$extraimages = getServerProfileImages($user['id']);
	if((! array_key_exists($return['imageid'], $images) &&
	   /*($return['type'] != 'server' || 
		! array_key_exists($return['imageid'], $extraimages)) &&*/
	   ($return['type'] != 'imaging' ||
	   ! array_key_exists($return['imageid'], $withnocheckout))) ||
	   ($return['type'] == 'imaging' &&
	   array_key_exists($return['imageid'], $noimaging)))	{
		$return['err'] = 1;
		$return['errmsg'] = i('No access to submitted environment');
		return $return;
	}

	# nousercheck
	$return['nousercheck'] = processInputVar('nousercheck', ARG_NUMERIC);
	if(! $nousercheck || $return['nousercheck'] != 1)
		$return['nousercheck'] = 0;

	# revisionid
	$revids = processInputVar("revisionid", ARG_STRING);
	$revids = explode(':', $revids);
	$images = getImages(0, $return['imageid']);
	$return['revisionids'] = array();
	if(array_key_exists('subimages', $images[$return['imageid']])) {
		$subimages = $images[$return['imageid']]['subimages'];
		array_unshift($subimages, $return['imageid']);
		foreach($subimages as $key => $imgid) {
			$revisions = getImageRevisions($imgid);
			if(! array_key_exists($key, $revids) ||
				! is_numeric($revids[$key]) ||
				! array_key_exists($revids[$key], $revisions))
				$revid = getProductionRevisionid($imgid);
			else
				$revid = $revids[$key];
			if(! array_key_exists($imgid, $return['revisionids']))
				$return['revisionids'][$imgid] = array();
			$return['revisionids'][$imgid][] = $revid;
		}
	}
	elseif($revids[0] != '' && is_numeric($revids[0]))
		$return['revisionids'][$return['imageid']][] = $revids[0];
	else
		$return['revisionids'][$return['imageid']][] = getProductionRevisionid($return['imageid']);
	
	# duration
	if($return['ending'] == 'duration') {
		$return['duration'] = processInputVar('duration', ARG_NUMERIC, 0);
		if($return['duration'] > $maxinitial)
			$return['duration'] = $maxinitial;
	}

	# start/end
	$return['start'] = processInputVar('start', ARG_NUMERIC);
	$return['end'] = processInputVar('end', ARG_NUMERIC, 0);
	$now = time();
	if($return['start'] == 0)
		$start = $now;
	else
		$start = $return['start']; # don't need to tz offset conversion due to javascript date object handling it
	if($return['ending'] == 'endat')
		$end = $return['end'];
	if($return['ending'] == 'indefinite')
		$end = datetimeToUnix('2038-01-01 00:00:00');
	elseif($return['ending'] == 'duration')
		$end = $start + ($return['duration'] * 60);
	if($start < $now) {
		$return['err'] = 1;
		$return['errmsg'] = i('The submitted start time is in the past.');
		return $return;
	}
	if($start + 900 > $end) {
		$return['err'] = 1;
		$return['errmsg'] = i('The end time must be at least 15 minutes later than the start time.');
		return $return;
	}

	$return['ipaddr'] = '';
	$return['macaddr'] = '';

	# server specific input
	if($return['type'] == 'server') {
		# name
		$return['name'] = processInputVar('name', ARG_STRING);
		if(! preg_match('/^([-a-zA-Z0-9_\. ]){0,255}$/', $return['name'])) {
			$return['err'] = 1;
			$return['errmsg'] = i('The reservation name can only contain letters, numbers, spaces, dashes(-), underscores(_), and periods(.) and can be up to 255 characters long');
			return $return;
		}

		# ipaddr
		$return['ipaddr'] = processInputVar('ipaddr', ARG_STRING);
		if($return['ipaddr'] != '') {
			# validate fixed IP address
			if(! validateIPv4addr($return['ipaddr'])) {
				$return['err'] = 1;
				$return['errmsg'] = i('Invalid IP address. Must be w.x.y.z with each of w, x, y, and z being between 1 and 255 (inclusive)');
				return $return;
			}
			# validate netmask
			$return['netmask'] = processInputVar('netmask', ARG_STRING);
			$bnetmask = ip2long($return['netmask']);
			if(! preg_match('/^[1]+0[^1]+$/', sprintf('%032b', $bnetmask))) {
				$return['err'] = 1;
				$return['errmsg'] = i('Invalid netmask specified');
				return $return;
			}
			# validate router
			$return['router'] = processInputVar('router', ARG_STRING);
			if(! validateIPv4addr($return['router'])) {
				$return['err'] = 1;
				$return['errmsg'] = i('Invalid router address. Must be w.x.y.z with each of w, x, y, and z being between 1 and 255 (inclusive)');
				return $return;
			}
			$return['network'] = ip2long($return['ipaddr']) & $bnetmask;
			if($return['network'] != (ip2long($return['router']) & $bnetmask)) {
				$return['err'] = 1;
				$return['errmsg'] = i('IP address and router are not on the same subnet based on the specified netmask.');
				return $return;
			}
			# validate dns server(s)
			$dns = processInputVar('dns', ARG_STRING);
			$tmp = explode(',', $dns);
			$cnt = 0;
			$return['dnsArr'] = array();
			foreach($tmp as $dnsaddr) {
				if($cnt && $dnsaddr == '')
					continue;
				if($cnt == 3) {
					$return['err'] = 1;
					$return['errmsg'] = i('Too many DNS servers specified - up to 3 are allowed.');
					return $return;
				}
				if(! validateIPv4addr($dnsaddr)) {
					$return['err'] = 1;
					$return['errmsg'] = i('Invalid DNS server specified.');
					return $return;
				}
				$return['dnsArr'][] = $dnsaddr;
				$cnt++;
			}
	
			# check that a management node can handle the network
			$mappedmns = getMnsFromImage($return['imageid']);
			$mnnets = checkAvailableNetworks($return['ipaddr']);
			$intersect = array_intersect($mappedmns, $mnnets);
			if(empty($intersect)) {
				$return['err'] = 1;
				$return['errmsg'] = i('There are no management nodes that can deploy the selected image with the specified IP address.');
				return $return;
			}
		}

		# macaddr
		$return['macaddr'] = processInputVar('macaddr', ARG_STRING);
		if($return['macaddr'] != '' && ! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $return['macaddr'])) {
			$return['err'] = 1;
			$return['errmsg'] = i('Invalid MAC address. Must be XX:XX:XX:XX:XX:XX with each pair of XX being from 00 to FF (inclusive)');
			return $return;
		}

		# profileid
		/*$return['profileid'] = processInputVar('profileid', ARG_NUMERIC, 0);
		$resources = getUserResources(array("serverCheckOut", "serverProfileAdmin"),
		                              array("available","administer"));
		if(! array_key_exists($return['profileid'], $resources['serverprofile']))
			$return['profileid'] = 0;
		elseif($return['profileid'] != 0) {
			$tmp = getServerProfiles($return['profileid']);
			$tmp = $tmp[$return['profileid']];
			if($tmp['imageid'] != $return['imageid'] &&
			   (($tmp['fixedIP'] != $return['ipaddr'] && $tmp['fixedMAC'] != $return['macaddr']) ||
			   ($tmp['fixedIP'] == $return['ipaddr'] && $return['ipaddr'] == '' &&
			   $tmp['fixedMAC'] == $return['macaddr'] && $return['macaddr'] == '')))
				$return['profileid'] = 0;
		}*/

		# admingroupid
		$usergroups = getUserGroups();
		$return['admingroupid'] = processInputVar('admingroupid', ARG_NUMERIC);
		if($return['admingroupid'] != 0 && ! array_key_exists($return['admingroupid'], $usergroups)) {
			$return['err'] = 1;
			$return['errmsg'] = i('You do not have access to use the specified admin user group.');
			return $return;
		}

		# logingroupid
		$return['logingroupid'] = processInputVar('logingroupid', ARG_NUMERIC);
		if($return['logingroupid'] != 0 && ! array_key_exists($return['logingroupid'], $usergroups)) {
			$return['err'] = 1;
			$return['errmsg'] = i('You do not have access to use the specified access user group.');
			return $return;
		}

		# monitored
		$return['monitored'] = processInputVar('monitored', ARG_NUMERIC, 0);
		if($return['monitored'] != 0 && $return['monitored'] != 1)
			$return['monitored'] = 0;

		# configs
		# TODO configs
		/*$tmp = getUserResources(array("configAdmin"));
		$userconfigs = $tmp['config'];
		$initconfigs = getMappedConfigs($return['imageid']);
		if(array_key_exists('configdata', $_POST)) {
			if(get_magic_quotes_gpc())
				$_POST['configdata'] = stripslashes($_POST['configdata']);
			$configdata = json_decode($_POST['configdata']);
		}
		if(array_key_exists('configdata', $_POST) &&
			isset($configdata->configs))
			$configs = $configdata->configs;
		else
			$configs = (object)array();
		$return['configs'] = array();
		foreach($initconfigs as $id => $config) {
			if(isset($configs->{$id}) &&
				isset($configs->{$id}->applied) &&
			   $configs->{$config['id']}->applied != 'true' &&
				$configs->{$config['id']}->applied != 'false')
				unset($configs->{$config['id']});
			if($config['optional'] &&
			   (! isset($configs->{$id}) ||
			   ! $configs->{$id}->applied))
				continue;
			$return['configs'][$id] = array('configid' => $config['configid'],
			                                'configmapid' => $config['configmapid'],
			                                'imageid' => $config['subimageid']);
			if(isset($configs->{$id}))
				unset($configs->{$id});
		}
		$rescfgmapids = array();
		foreach($configs as $id => $config) {
			if(! array_key_exists($config->configid, $userconfigs))
				continue;
			$return['configs'][$id] = array('configid' => $config->configid,
			                                'configstageid' => $config->configstageid,
			                                'imageid' => $config->imageid);
			$tmp = explode('/', $id);
			$rescfgmapids[$tmp[1]] = 1;
		}

		# configvars
		$tmp = array_splice($initconfigs, 0);
		$initconfigvars = getImageConfigVariables($tmp);
		if(array_key_exists('configdata', $_POST) &&
			isset($configdata->configvars))
			$configvars = $configdata->configvars;
		else
			$configvars = (object)array();
		#print "/*";
		#printArray($initconfigvars);
		#printArray($configvars);
		#print "*" . "/";
		$return['configvars'] = array();
		foreach($initconfigvars as $id => $configvar) {
			$tmp = explode('/', $id);
			$cfgid = "{$tmp[0]}/{$tmp[1]}";
			$varid = $tmp[2];
			if($configvar['ask'] == 0 ||
			   ! isset($configvars->{$id}) ||
			   ! isset($configvars->{$id}->value)) {
				$return['configvars'][$cfgid][$varid] =
				         array('value' => $configvar['defaultvalue']);
			}
			else {
				switch($configvar['datatype']) {
					case 'bool':
					case 'int':
					case 'float':
						$value = processInputData($configvars->{$id}->value, ARG_NUMERIC);
						break;
					default:
						$value = processInputData($configvars->{$id}->value, ARG_STRING);
						break;
				}
				$return['configvars'][$cfgid][$varid] = array('value' => $value);
			}
			if(isset($configvars->{$id}))
				unset($configvars->{$id});
		}*/
		/*print "/*";
		printArray($rescfgmapids);
		foreach($configvars as $id => $var) {
			$cfgid = explode('/', $id);
			print "cfgid: {$cfgid[1]}\n";
			if(! array_key_exists($cfgid[1], $rescfgmapids))
				continue;
			// TODO validate based on var type
			$value = processInputData($configvars->{$id}->value, ARG_STRING);
			$return['configvars']["{$cfgid[0]}/{$cfgid[1]}"][$cfgid[2]] = array('value' => $value);
		}
		printArray($configvars);*/
		#print "*/";
	}
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
	global $user;
	$query = "SELECT UNIX_TIMESTAMP(cll.timestamp) AS timestamp, "
	       .        "cls.loadstatename, "
	       .        "COALESCE(v2.value, v1.value) AS acknowledgetimeout, "
	       .        "COALESCE(v4.value, v3.value) AS initialconnecttimeout, "
	       .        "COALESCE(v6.value, v5.value) AS reconnecttimeout "
	       . "FROM computerloadlog cll, "
	       .      "computerloadstate cls, "
	       .      "variable v1, "
	       .      "variable v3, "
	       .      "variable v5 "
	       . "LEFT JOIN variable v2 ON (v2.name = 'acknowledgetimeout|{$user['affiliation']}') "
	       . "LEFT JOIN variable v4 ON (v4.name = 'initialconnecttimeout|{$user['affiliation']}') "
	       . "LEFT JOIN variable v6 ON (v6.name = 'reconnecttimeout|{$user['affiliation']}') "
	       . "WHERE cll.reservationid = $resid AND "
	       .       "cll.loadstateid = cls.id AND "
	       .       "cll.loadstateid IN (SELECT id "
	       .                           "FROM computerloadstate "
	       .                           "WHERE loadstatename IN ('acknowledgetimeout', 'initialconnecttimeout', 'reconnecttimeout')) AND "
	       .       "v1.name = 'acknowledgetimeout' AND "
	       .       "v3.name = 'initialconnecttimeout' AND "
	       .       "v5.name = 'reconnecttimeout' "
	       . "ORDER BY cll.timestamp DESC "
	       . "LIMIT 1";
	$qh = doQuery($query);
	if($row = mysql_fetch_assoc($qh)) {
		if(! is_numeric($row['timestamp']))
			return NULL;
		if($row['loadstatename'] == 'acknowledgetimeout')
			return $row['timestamp'] + $row['acknowledgetimeout'] + 5;
		elseif($row['loadstatename'] == 'initialconnecttimeout')
			return $row['timestamp'] + $row['initialconnecttimeout'] + 5;
		elseif($row['loadstatename'] == 'reconnecttimeout')
			return $row['timestamp'] + $row['reconnecttimeout'] + 5;
		else
			return NULL;
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
	       . "SELECT $resid, "
	       .        "$compid, "
	       .        "id, "
	       .        "NOW() "
	       . "FROM computerloadstate "
	       . "WHERE loadstatename = 'initialconnecttimeout'";
	doQuery($query);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getReserveDayData()
///
/// \return array where each key is a unix timestamp, each value is a day of the
/// week
///
/// \brief generates days a user can select for making a future reservation
///
////////////////////////////////////////////////////////////////////////////////
function getReserveDayData() {
	$days = array();
	$cur = time();
	if(array_key_exists('tzoffset', $_SESSION['persistdata']))
		$cur += $_SESSION['persistdata']['tzoffset'] * 60;
	for($end = $cur + DAYSAHEAD * SECINDAY; 
	    $cur < $end; 
	    $cur += SECINDAY) {
		$tmp = getdate($cur);
		$index = $cur;
		$days[$index] = i($tmp["weekday"]);
	}
	return $days;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsetImageProduction()
///
/// \brief prompts user if really ready to set image to production
///
////////////////////////////////////////////////////////////////////////////////
function AJsetImageProduction() {
	$requestid = getContinuationVar('requestid');
	$data = getRequestInfo($requestid);
	foreach($data["reservations"] as $res) {
		if($res["forcheckout"]) {
			$prettyimage = $res["prettyimage"];
			break;
		}
	}
	$title = "<big><strong>" . i("Change Test Image to Production") . "</strong></big><br><br>\n";
	$text = sprintf(i("This will update %s so that new reservations for it will be for the newly created revision. Are you sure it works correctly and is ready to be made the production revision?"), "<b>$prettyimage</b>") . "<br>\n";
	$cdata = array('requestid' => $requestid);
	$cont = addContinuationsEntry('AJsubmitSetImageProduction', $cdata, SECINDAY, 0, 0);
	$text = preg_replace("/(.{1,60}[ \n])/", '\1<br>', $text);
	$data = array('content' => $title . $text,
	              'cont' => $cont,
	              'btntxt' => i('Make Production'));
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitSetImageProduction()
///
/// \brief sets request state to 'makeproduction', notifies user that
/// "productioning" process has started
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitSetImageProduction() {
	$requestid = getContinuationVar('requestid');
	$data = getRequestInfo($requestid);
	foreach($data["reservations"] as $res) {
		if($res["forcheckout"]) {
			$prettyimage = $res["prettyimage"];
			break;
		}
	}
	$query = "UPDATE request SET stateid = 17 WHERE id = $requestid";
	doQuery($query, 101);
	$content = sprintf(i("%s is now in the process of being updated to use the newly created revision."), "<b>$prettyimage</b>") . "<br>";
	$content = preg_replace("/(.{1,60}[ \n])/", '\1<br>', $content);
	$a = "var dlg = new dijit.Dialog({"
	   .    "title: \"" . i("Change Test Image to Production") . "\","
	   .    "id: \"toproddlg\""
	   . "});"
		. "var content = '$content"
	   . "<div align=\"center\">"
	   . "<button dojoType=\"dijit.form.Button\">"
	   .   i("Close")
	   .   "<script type=\"dojo/method\" event=\"onClick\">"
	   .   "dijit.byId(\"toproddlg\").destroy();"
	   .   "</script>"
		.   "</button>"
	   .   "</div>';"
	   . "dlg.set(\"content\", content);"
	   . "dlg.show();"
	   . "resRefresh();";
	print $a;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJpreviewClickThrough()
///
/// \brief prompts user if really ready to set image to production
///
////////////////////////////////////////////////////////////////////////////////
function AJpreviewClickThrough() {
	global $clickThroughText;
	$text = sprintf($clickThroughText, '');
	$text = preg_replace("/(.{1,80}([ \n]|$))/", '\1<br>', $text);
	$text = preg_replace("/<\/p>\n<br>/", '', $text);
	sendJSON(array('text' => $text));
}
?>
