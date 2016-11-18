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

/// global array for x axis labels
$xaxislabels = array();
/// signifies an error with the submitted start date
define("STARTERR", 1);
/// signifies an error with the submitted end date
define("ENDERR", 1 << 1);
/// signifies an error with the start date being after the end date
define("ORDERERR", 1 << 2);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectStatistics()
///
/// \brief prints a form for getting statistics
///
////////////////////////////////////////////////////////////////////////////////
function selectStatistics() {
	global $submitErr, $user;
	list($month1, $day1, $year1) = explode(',', date('n,j,Y', time() - 
	                                    (SECINDAY * 6)));
	list($month2, $day2, $year2) = explode(',', date('n,j,Y', time()));
	print "<H2>" . i("Statistic Information") . "</H2>\n";
	if($submitErr) {
		printSubmitErr(STARTERR);
		printSubmitErr(ENDERR);
		printSubmitErr(ORDERERR);
		$monthkey1 = processInputVar("month1", ARG_NUMERIC);
		$daykey1 = processInputVar("day1", ARG_NUMERIC);
		$yearkey1 = processInputVar("year1", ARG_NUMERIC);
		$monthkey2 = processInputVar("month2", ARG_NUMERIC);
		$daykey2 = processInputVar("day2", ARG_NUMERIC);
		$yearkey2 = processInputVar("year2", ARG_NUMERIC);
		$affilid = processInputVar("affilid", ARG_NUMERIC);
	}
	else
		$affilid = $user['affiliationid'];
	print i("Select a starting date:") . "<br>\n";
	$months = array('');
	for($i = 2 * SECINDAY, $cnt = 1; $cnt < 13; $i += SECINMONTH, $cnt++)
		$months[$cnt] = strftime('%B', $i);
	unset($months[0]);
	$days = array();
	for($i = 0; $i < 32; $i++) {
		array_push($days, $i);
	}
	unset($days[0]);
	$years = array();
	for($i = 2004; $i <= $year2; $i++) {
		$years[$i] = $i;
	}
	if(! $submitErr) {
		$monthkey1 = $month1;
		$daykey1 = array_search($day1, $days);
		$yearkey1 = array_search($year1, $years);
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	printSelectInput("month1", $months, $monthkey1);
	printSelectInput("day1", $days, $daykey1);
	printSelectInput("year1", $years, $yearkey1);
	print "<br>\n";
	print i("Select an ending date:") . "<br>\n";
	if(! $submitErr) {
		$monthkey2 = $month2;
		$daykey2 = array_search($day2, $days);
		$yearkey2 = array_search($year2, $years);
	}
	printSelectInput("month2", $months, $monthkey2);
	printSelectInput("day2", $days, $daykey2);
	printSelectInput("year2", $years, $yearkey2);
	print "<br>\n";
	$cont = addContinuationsEntry('viewstats');
	if(checkUserHasPerm('View Statistics by Affiliation')) {
		print "<input type=radio id=stattype1 name=continuation value=\"$cont\" checked>\n";
		print "<label for=stattype1>" . i("View General Statistics") . "</label> - \n";
		print i("Select an affiliation:") . "\n";
		$affils = getAffiliations();
		if(! array_key_exists($affilid, $affils))
			$affilid = $user['affiliationid'];
		$affils = array_reverse($affils, TRUE);
		$affils[0] = "All";
		$affils = array_reverse($affils, TRUE);
		printSelectInput("affilid", $affils, $affilid);
		print "<br>\n";

		$query = "SELECT id, "
		       .        "prettyname "
		       . "FROM provisioning "
		       . "ORDER BY prettyname";
		$qh = doQuery($query);
		$provs = array();
		while($row = mysql_fetch_assoc($qh))
			$provs[$row['id']] = $row['prettyname'];
		$cdata = array('mode' => 'provisioning',
		               'provs' => $provs);
		$cont2 = addContinuationsEntry('viewstats', $cdata);
		print "<input type=radio id=stattype3 name=continuation value=\"$cont2\">\n";
		print "<label for=stattype3>" . i("View Statistics by provisioning engine");
		print "</label>:\n";
		printSelectInput("provid", $provs);
		print "<br>\n";
	}
	else
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=" . i("Submit") . ">\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewStatistics
///
/// \brief prints statistic information
///
////////////////////////////////////////////////////////////////////////////////
function viewStatistics() {
	global $submitErr, $submitErrMsg, $user;
	define("30MIN", 1800);
	define("1HOUR", 3600);
	define("2HOURS", 7200);
	define("4HOURS", 14400);
	$month1 = processInputVar("month1", ARG_NUMERIC);
	$day1 = processInputVar("day1", ARG_NUMERIC);
	$year1 = processInputVar("year1", ARG_NUMERIC);
	$month2 = processInputVar("month2", ARG_NUMERIC);
	$day2 = processInputVar("day2", ARG_NUMERIC);
	$year2 = processInputVar("year2", ARG_NUMERIC);
	$affilid = processInputVar("affilid", ARG_NUMERIC, $user['affiliationid']);
	$mode2 = getContinuationVar('mode', 'default');
	$provid = processInputVar('provid', ARG_NUMERIC, 0);
	if($mode2 == 'provisioning') {
		$affilid = 0;
		$provs = getContinuationVar('provs');
		if(! array_key_exists($provid, $provs)) {
			$ids = array_keys($provs);
			$provid = $ids[0];
		}
	}
	else
		$provid = 0;

	$affils = getAffiliations();
	if(! checkUserHasPerm('View Statistics by Affiliation') ||
	   ($affilid != 0 && ! array_key_exists($affilid, $affils)))
		$affilid = $user['affiliationid'];

	if($affilid == 0)
		$statsfor = i("All Affiliations");
	else
		$statsfor = $affils[$affilid];

	$start = "$year1-$month1-$day1 00:00:00";
	$end = "$year2-$month2-$day2 23:59:59";
	if(! checkdate($month1, $day1, $year1)) {
		$submitErr |= STARTERR;
		$submitErrMsg[STARTERR] = i("The selected start date is not valid. Please select a valid date.") . "<br>\n";
	}
	if(! checkdate($month2, $day2, $year2)) {
		$submitErr |= ENDERR;
		$submitErrMsg[ENDERR] = i("The selected end date is not valid. Please select a valid date.") . "<br>\n";
	}
	if(datetimeToUnix($start) > datetimeToUnix($end)) {
		$submitErr |= ORDERERR;
		$submitErrMsg[ORDERERR] = i("The selected end date is before the selected start date. Please select an end date equal to or greater than the start date.") . "<br>\n";
	}
	if($submitErr) {
		selectStatistics();
		return;
	}

	$timestart = microtime(1);
	if($mode2 == 'default')
		print "<H2>" . i("Statistic Information for") . " $statsfor</H2>\n";
	elseif($mode2 == 'provisioning')
		print "<H2>" . i("Statistic Information for") . " {$provs[$provid]}</H2>\n";
	print "(Times and dates on this page are in " . date('T') . ")<br>\n";
	print "<H3>";
	$tmp = mktime(0, 0, 0, $month1, $day1, $year1);
	$starttime = strftime('%x', $tmp);
	$tmp = mktime(0, 0, 0, $month2, $day2, $year2);
	$endtime = strftime('%x', $tmp);
	printf(i("Reservation information between %s and %s:"), $starttime, $endtime);
	print "</H3>\n";
	$reloadid = getUserlistID('vclreload@Local');
	if($mode2 == 'default') {
		$query = "SELECT l.userid, "
		       .        "u.affiliationid, "
		       .        "l.nowfuture, "
		       .        "UNIX_TIMESTAMP(l.start) AS start, "
		       .        "(UNIX_TIMESTAMP(l.loaded) - UNIX_TIMESTAMP(l.start)) AS loadtime, "
		       .        "UNIX_TIMESTAMP(l.finalend) AS finalend, "
		       .        "l.wasavailable, "
		       .        "l.ending, "
		       .        "i.prettyname, "
		       .        "o.prettyname AS OS "
		       . "FROM log l, "
		       .      "image i, "
		       .      "user u, "
		       .      "OS o "
		       . "WHERE l.start >= '$start' AND "
		       .       "l.finalend <= '$end' AND "
		       .       "i.id = l.imageid AND "
		       .       "i.OSid = o.id AND "
		       .       "l.userid != $reloadid AND ";
	}
	elseif($mode2 == 'provisioning') {
		$query = "SELECT l.userid, "
		       .        "u.affiliationid, "
		       .        "l.nowfuture, "
		       .        "UNIX_TIMESTAMP(l.start) AS start, "
		       .        "(UNIX_TIMESTAMP(l.loaded) - UNIX_TIMESTAMP(l.start)) AS loadtime, "
		       .        "UNIX_TIMESTAMP(l.finalend) AS finalend, "
		       .        "l.wasavailable, "
		       .        "l.ending, "
		       .        "i.prettyname, "
		       .        "o.prettyname AS OS "
		       . "FROM image i, "
		       .      "user u, "
		       .      "OS o, "
		       .      "log l "
		       . "JOIN ("
		       .       "SELECT s.logid, "
		       .              "MIN(s.computerid) AS computerid "
		       .       "FROM sublog s, "
		       .            "computer c "
		       .       "WHERE s.computerid = c.id AND "
		       .             "c.provisioningid = $provid "
		       .       "GROUP BY logid "
		       .       ") AS s ON (s.logid = l.id) "
		       . "WHERE l.start >= '$start' AND "
		       .       "l.finalend <= '$end' AND "
		       .       "i.id = l.imageid AND "
		       .       "i.OSid = o.id AND "
		       .       "l.userid != $reloadid AND ";
	}
	if($affilid != 0)
		$query .=   "u.affiliationid = $affilid AND ";
	$query .=      "l.userid = u.id "
	       . "ORDER BY i.prettyname";
	$qh = doQuery($query, 275);

	$totalreservations = 0;
	$users = array();
	$nows = 0;
	$futures = 0;
	$notavailable = 0;
	$loadtimes = array("2less" => 0, "2to6" => 0, "6to8" => 0, "8more" => 0);
	$ending = array("deleted" => 0,
	                "released" => 0,
	                "failed" => 0,
	                "noack" => 0,
	                "nologin" => 0,
	                "timeout" => 0,
	                "EOR" => 0,
	                "none" => 0);
	$imagecount = array();
	$imageusers = array();
	$imagehours = array();
	$imageload2less = array();
	$imageload2to6 = array();
	$imageload6to8 = array();
	$imageload8more = array();
	$imagefails = array();
	$lengths = array("30min" => 0,
	                 "1hour" => 0,
	                 "2hours" => 0,
	                 "4hours" => 0,
	                 "6hours" => 0,
	                 "8hours" => 0,
	                 "10hours" => 0,
	                 "10hrsplus" => 0);
	$totalhours = 0;
	$osusers = array();
	while($row = mysql_fetch_assoc($qh)) {
		if(! array_key_exists($row["prettyname"], $imageload2less))
			$imageload2less[$row["prettyname"]] = 0;
		if(! array_key_exists($row["prettyname"], $imageload2to6))
			$imageload2to6[$row["prettyname"]] = 0;
		if(! array_key_exists($row["prettyname"], $imageload6to8))
			$imageload6to8[$row["prettyname"]] = 0;
		if(! array_key_exists($row["prettyname"], $imageload8more))
			$imageload8more[$row["prettyname"]] = 0;

		# notavailable
		if($row["wasavailable"] == 0) {
			$notavailable++;
		}
		else {
			$totalreservations++;

			# load times
			if($row['loadtime'] <= 120) {
				$loadtimes['2less']++;
				# imageload2less
				$imageload2less[$row['prettyname']]++;
			}
			elseif( ($row['loadtime'] > 120) && ($row['loadtime'] <= 360) ) {
				$loadtimes['2to6']++;
				$imageload2to6[$row['prettyname']]++;
			}
			elseif( ($row['loadtime'] > 360) && ($row['loadtime'] <= 480) ) {
				$loadtimes['6to8']++;
				$imageload6to8[$row['prettyname']]++;
			}
			else {
				$loadtimes['8more']++;
				$imageload8more[$row['prettyname']]++;
			}
		}

		# users
		$users[$row['userid']] = 1;

		# nowfuture
		if($row["nowfuture"] == "now")
			$nows++;
		else
			$futures++;

		# ending
		$ending[$row["ending"]]++;

		# imagecount
		if(! array_key_exists($row["prettyname"], $imagecount))
			$imagecount[$row["prettyname"]] = 0;
		$imagecount[$row["prettyname"]]++;

		# imageusers
		if(! array_key_exists($row["prettyname"], $imageusers))
			$imageusers[$row["prettyname"]] = array();
		$imageusers[$row['prettyname']][$row['userid']] = 1;

		# lengths
		$length = $row["finalend"] - $row["start"];
		if($length < 0)
			$length = 0;
		if($length <= 1800)
			$lengths["30min"]++;
		elseif($length <= 3600)
			$lengths["1hour"]++;
		elseif($length <= 7200)
			$lengths["2hours"]++;
		elseif($length <= 14400)
			$lengths["4hours"]++;
		elseif($length <= 21600)
			$lengths["6hours"]++;
		elseif($length <= 28800)
			$lengths["8hours"]++;
		elseif($length <= 36000)
			$lengths["10hours"]++;
		else
			$lengths["10hrsplus"]++;

		# imagehours
		if(! array_key_exists($row["prettyname"], $imagehours))
			$imagehours[$row["prettyname"]] = 0;
		$imagehours[$row["prettyname"]] += ($length / 3600);

		# imagefails
		if(! array_key_exists($row["prettyname"], $imagefails))
			$imagefails[$row["prettyname"]] = 0;
		if($row['ending'] == 'failed')
			$imagefails[$row["prettyname"]] += 1;

		# total hours
		$totalhours += $length;

		# osusers
		if(! array_key_exists($row["OS"], $osusers))
			$osusers[$row["OS"]] = array();
		$osusers[$row['OS']][$row['userid']] = 1;
	}
	print "<DIV align=center>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Total Reservations:") . "</TH>\n";
	print "    <TD>$totalreservations</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Total Hours Used:") . "</TH>\n";
	print "    <TD>" . (int)($totalhours / 3600) . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("\"Now\" Reservations:") . "</TH>\n";
	print "    <TD>$nows</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("\"Later\" Reservations:") . "</TH>\n";
	print "    <TD>$futures</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Unavailable:") . "</TH>\n";
	print "    <TD>$notavailable</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Load times &lt; 2 minutes:") . "</TH>\n";
	print "    <TD>{$loadtimes['2less']}</TD>\n";
	print "  </TR>\n";
	print "    <TH align=right>" . i("Load times 2-6 minutes:") . "</TH>\n";
	print "    <TD>{$loadtimes['2to6']}</TD>\n";
	print "  </TR>\n";
	print "    <TH align=right>" . i("Load times 6-8 minutes:") . "</TH>\n";
	print "    <TD>{$loadtimes['6to8']}</TD>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Load times &gt;= 8 minutes:") . "</TH>\n";
	print "    <TD>{$loadtimes['8more']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Total Unique Users:") . "</TH>\n";
	print "    <TD>" . count($users) . "</TD>\n";
	print "  </TR>\n";
	foreach(array_keys($osusers) as $key) {
		print "  <TR>\n";
		print "    <TH align=right>";
		printf(i("Unique Users of %s:"), $key);
		print "</TH>\n";
		print "    <TD>" . count($osusers[$key]) . "</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "<br>\n";

	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH>" . i("Reservations") . "</TH>\n";
	print "    <TH>" . i("Unique Users") . "</TH>\n";
	print "    <TH>" . i("Hours Used") . "</TH>\n";
	print "    <TH>" . i("&lt; 2 min wait") . "</TH>\n";
	print "    <TH>" . i("2-6 min wait") . "</TH>\n";
	print "    <TH>" . i("6-8 min wait") . "</TH>\n";
	print "    <TH>" . i("&gt;= 8 min wait") . "</TH>\n";
	print "    <TH>" . i("Failures") . "</TH>\n";
	print "  </TR>\n";
	foreach($imagecount as $key => $value) {
		print "  <TR>\n";
		print "    <TH align=right>$key:</TH>\n";
		print "    <TD align=center>$value</TD>\n";
		print "    <TD align=center>" . count($imageusers[$key]) . "</TD>\n";
		if(((int)$imagehours[$key]) == 0)
			print "    <TD align=center>1</TD>\n";
		else
			print "    <TD align=center>" . (int)$imagehours[$key] . "</TD>\n";
		print "    <TD align=center>{$imageload2less[$key]}</TD>\n";
		print "    <TD align=center>{$imageload2to6[$key]}</TD>\n";
		print "    <TD align=center>{$imageload6to8[$key]}</TD>\n";
		print "    <TD align=center>{$imageload8more[$key]}</TD>\n";
		if($imagefails[$key]) {
			$percent = $imagefails[$key] * 100 / $value;
			if($percent < 1)
				$percent = sprintf('%.1f%%', $percent);
			else
				$percent = sprintf('%d%%', $percent);
			print "    <TD align=center><font color=red>{$imagefails[$key]} ";
			print "($percent)</font></TD>\n";
		}
		else
			print "    <TD align=center>{$imagefails[$key]}</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";

	print "<H3>" . i("Durations:") . "</H3>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("0 - 30 Min:") . "</TH>\n";
	print "    <TD>" . $lengths["30min"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("30 Min - 1 Hour:") . "</TH>\n";
	print "    <TD>" . $lengths["1hour"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("1 Hour - 2 Hours:") . "</TH>\n";
	print "    <TD>" . $lengths["2hours"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("2 Hours - 4 Hours:") . "</TH>\n";
	print "    <TD>" . $lengths["4hours"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("4 Hours - 6 Hours:") . "</TH>\n";
	print "    <TD>" . $lengths["6hours"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("6 Hours - 8 Hours:") . "</TH>\n";
	print "    <TD>" . $lengths["8hours"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("8 Hours - 10 Hours:") . "</TH>\n";
	print "    <TD>" . $lengths["10hours"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("&gt; 10 Hours:") . "</TH>\n";
	print "    <TD>" . $lengths["10hrsplus"] . "</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";

	print "<H3>" . i("Ending information:") . "</H3>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Deleted:") . "</TH>\n";
	print "    <TD>" . $ending["deleted"] . "</TD>\n";
	print "    <TD rowspan=7><img src=\"images/blank.gif\" width=5></TD>\n";
	print "    <TD>" . i("(Future reservation deleted before start time reached)") . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Released:") . "</TH>\n";
	print "    <TD>" . $ending["released"] . "</TD>\n";
	print "    <TD>" . i("(Reservation released before end time reached)") . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Not Acknowledged:") . "</TH>\n";
	print "    <TD>" . $ending["noack"] . "</TD>\n";
	print "    <TD>" . i("(\"Connect!\" button never clicked)") . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("No Login:") . "</TH>\n";
	print "    <TD>" . $ending["nologin"] . "</TD>\n";
	print "    <TD>" . i("(User never logged in)") . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("End of Reservation:") . "</TH>\n";
	print "    <TD>" . $ending["EOR"] . "</TD>\n";
	print "    <TD>" . i("(End of reservation reached)") . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Timed Out:") . "</TH>\n";
	print "    <TD>" . $ending["timeout"] . "</TD>\n";
	print "    <TD>" . i("(Disconnect and no reconnection within 15 minutes)") . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>" . i("Failed:") . "</TH>\n";
	print "    <TD>" . $ending["failed"] . "</TD>\n";
	print "    <TD>" . i("(Reserved computer failed to get prepared for user)") . "</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<br>\n";
	print "</div>\n";

	$unixstart = datetimeToUnix($start);
	$unixend = datetimeToUnix($end);
	$start = date('Y-m-d', $unixstart);
	$end = date('Y-m-d', $unixend);
	$cdata = array('start' => $start,
	               'end' => $end,
	               'affilid' => $affilid,
	               'mode' => $mode2,
	               'provid' => $provid);
	print "<H2>" . i("Reservations by Day") . "</H2>\n";
	print "<small>" . i("(Reservations with start time on given day)") . "</small><br>\n";
	$cdata['divid'] = 'resbyday';
	$cont = addContinuationsEntry('AJgetStatData', $cdata);
	print "<input type=hidden id=statdaycont value=\"$cont\">\n";
	print "<div id=\"resbyday\" class=\"statgraph\">(Loading...)</div>\n";

	print "<H2>" . i("Max Concurrent Reservations By Day") . "</H2>\n";
	$cdata['divid'] = 'maxconcurresday';
	$cont = addContinuationsEntry('AJgetStatData', $cdata);
	print "<input type=hidden id=statconcurrescont value=\"$cont\">\n";
	print "<div id=\"maxconcurresday\" class=\"statgraph\">Loading graph data...</div>\n";

	print "<H2>" . i("Max Concurrent Blade Reservations By Day") . "</H2>\n";
	$cdata['divid'] = 'maxconcurbladeday';
	$cont = addContinuationsEntry('AJgetStatData', $cdata);
	print "<input type=hidden id=statconcurbladecont value=\"$cont\">\n";
	print "<div id=\"maxconcurbladeday\" class=\"statgraph\">Loading graph data...</div>\n";

	print "<H2>" . i("Max Concurrent Virtual Machine Reservations By Day") . "</H2>\n";
	$cdata['divid'] = 'maxconcurvmday';
	$cont = addContinuationsEntry('AJgetStatData', $cdata);
	print "<input type=hidden id=statconcurvmcont value=\"$cont\">\n";
	print "<div id=\"maxconcurvmday\" class=\"statgraph\">Loading graph data...</div>\n";

	print "<H2>" . i("Reservations by Hour") . "</H2>\n";
	print "<small>(" . i("Active reservations during given hour averaged over selected dates") . ")</small><br><br>\n";
	$cdata['divid'] = 'resbyhour';
	$cont = addContinuationsEntry('AJgetStatData', $cdata);
	print "<input type=hidden id=statreshourcont value=\"$cont\">\n";
	print "<div id=\"resbyhour\" class=\"statgraph\">Loading graph data...</div>\n";

	$endtime = microtime(1);
	$end = $endtime - $timestart;
	#print "running time: $endtime - $timestart = $end<br>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJgetStatData()
///
/// \brief gets statistical data for a dojox chart and returns it in json format
///
////////////////////////////////////////////////////////////////////////////////
function AJgetStatData() {
	$start = getContinuationVar("start");
	$end = getContinuationVar("end");
	$affilid = getContinuationVar("affilid");
	$divid = getContinuationVar('divid');
	$mode = getContinuationVar('mode');
	$provid = getContinuationVar('provid');
	if($divid == 'resbyday')
		$data = getStatGraphDayData($start, $end, $affilid, $mode, $provid);
	elseif($divid == 'maxconcurresday')
		$data = getStatGraphDayConUsersData($start, $end, $affilid, $mode, $provid);
	elseif($divid == 'maxconcurbladeday')
		$data = getStatGraphConBladeUserData($start, $end, $affilid, $mode, $provid);
	elseif($divid == 'maxconcurvmday')
		$data = getStatGraphConVMUserData($start, $end, $affilid, $mode, $provid);
	elseif($divid == 'resbyhour')
		$data = getStatGraphHourData($start, $end, $affilid, $mode, $provid);
	elseif(preg_match('/^resbyday/', $divid))
		$data = getStatGraphDayData($start, $end, $affilid, $mode, $provid);
	elseif(preg_match('/^maxconcurresday/', $divid))
		$data = getStatGraphDayConUsersData($start, $end, $affilid, $mode, $provid);
	elseif(preg_match('/^maxconcurbladeday/', $divid))
		$data = getStatGraphConBladeUserData($start, $end, $affilid, $mode, $provid);
	elseif(preg_match('/^maxconcurvmday/', $divid))
		$data = getStatGraphConVMUserData($start, $end, $affilid, $mode, $provid);
	$data['id'] = $divid;
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphDayData($start, $end, $affilid, $mode, $provid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
/// \param $mode - stat mode - 'default' or 'provisioning'
/// \param $provid - provisioning id - set to 0 for $mode = 'default', set to
/// > 0 otherwise
///
/// \return an array with three keys:\n
/// \b points - an array with y and tooltip keys that have the same value which
///             is the y value at that point\n
/// \b xlabels - an array with value and text keys, value's value is just an
///              increasing integer starting from 1, text's value is the label
///              to display on the x axis for the poing\n
/// \b maxy - the max y value of the data
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the number of reservations on each day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphDayData($start, $end, $affilid, $mode, $provid) {
	$startunix = datetimeToUnix($start . " 00:00:00");
	$endunix = datetimeToUnix($end . " 23:59:59");

	$data = array();
	$data["points"] = array();
	$data['xlabels'] = array();
	$data['maxy'] = 0;
	$cachepts = array();
	$addcache = array();
	$reloadid = getUserlistID('vclreload@Local');
	$cnt = 0;
	$query = "SELECT statdate, "
	       .        "value "
	       . "FROM statgraphcache "
	       . "WHERE graphtype = 'totalres' AND "
			 .       "affiliationid = $affilid AND "
	       .       "statdate >= '$start' AND "
	       .       "statdate <= '$end' AND "
	       .       "provisioningid = $provid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$cachepts[$row['statdate']] = $row['value'];
	for($i = $startunix; $i < $endunix; $i += SECINDAY) {
		$cnt++;
		$startdt = unixToDatetime($i);
		$enddt = unixToDatetime($i + SECINDAY);
		$tmp = explode(' ', $startdt);
		$key = $tmp[0];
		if(array_key_exists($key, $cachepts))
			$value = $cachepts[$key];
		else {
			if($affilid != 0) {
				$query = "SELECT count(l.id) "
				       . "FROM log l, "
				       .      "user u "
				       . "WHERE l.start >= '$startdt' AND "
				       .       "l.start < '$enddt' AND "
				       .       "l.userid != $reloadid AND "
				       .       "l.wasavailable = 1 AND "
				       .       "l.userid = u.id AND "
				       .       "u.affiliationid = $affilid";
			}
			else {
				if($mode == 'default') {
					$query = "SELECT count(l.id) "
					       . "FROM log l "
					       . "WHERE l.start >= '$startdt' AND "
					       .       "l.start < '$enddt' AND "
					       .       "l.userid != $reloadid AND "
					       .       "l.wasavailable = 1";
				}
				elseif($mode == 'provisioning') {
					$query = "SELECT count(l.id) "
					       . "FROM log l "
					       . "JOIN ("
					       .       "SELECT s.logid, "
					       .              "MIN(s.computerid) AS computerid "
					       .       "FROM sublog s, "
					       .            "computer c "
					       .       "WHERE s.computerid = c.id AND "
					       .             "c.provisioningid = $provid "
					       .       "GROUP BY logid "
					       .       ") AS s ON (s.logid = l.id) "
					       . "WHERE l.start >= '$startdt' AND "
					       .       "l.start < '$enddt' AND "
					       .       "l.userid != $reloadid AND "
					       .       "l.wasavailable = 1";
				}
			}
			$qh = doQuery($query, 295);
			if($row = mysql_fetch_row($qh))
				$value = $row[0];
			else
				$value = 0;
			$addcache[$startdt] = (int)$value;
		}
		$label = date('m/d/Y', $i);
		$data['points'][] = array('y' => (int)$value, 'tooltip' => "$label: " . (int)$value);
		if($value > $data['maxy'])
			$data['maxy'] = (int)$value;
		$data['xlabels'][] = array('value' => $cnt, 'text' => $label);
	}
	if(count($addcache))
		addToStatGraphCache('totalres', $addcache, $affilid, $provid);
	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphHourData($start, $end, $affilid, $mode, $provid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
/// \param $mode - stat mode - 'default' or 'provisioning'
/// \param $provid - provisioning id - ignored unless $mode is 'provisioning'
///
/// \return an array with two keys:\n
/// \b points - an array with 5 keys:\n
///             \t x - increasing integer starting from 1\n
///             \t y - y value for the point\n
///             \t value - same as x\n
///             \t text - label for x axis for the point\n
///             \t tooltip - tooltip to be displayed when point is hovered\n
/// \b maxy - the max y value of the data
///
/// \return an array whose keys are the days (in YYYY-MM-DD format) between
/// $start and $end, inclusive, and whose values are the number of reservations
/// on each day
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the number of reservations on each day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphHourData($start, $end, $affilid, $mode, $provid) {
	$startdt = $start . " 00:00:00";
	$enddt = $end . " 23:59:59";
	$startunix = datetimeToUnix($startdt);
	$endunix = datetimeToUnix($enddt) + 1;
	$enddt = unixToDatetime($endunix);
	$days = ($endunix - $startunix) / SECINDAY;

	$data = array();
	$data["points"] = array();
	for($i = 0; $i < 24; $i++) {
		$data["points"][$i] = array('x' => $i, 'y' => 0, 'value' => $i, 'text' => statHourFormatX($i), 'tooltip' => 0);
	}
	$data["maxy"] = 0;

	$reloadid = getUserlistID('vclreload@Local');
	if($affilid != 0) {
		$query = "SELECT DATE_FORMAT(l.start, '%k') AS shour, "
		       .        "DATE_FORMAT(l.start, '%i') AS smin, "
		       .        "DATE_FORMAT(l.finalend, '%k') AS ehour, "
		       .        "DATE_FORMAT(l.finalend, '%i') AS emin "
		       . "FROM log l, "
		       .      "user u "
		       . "WHERE l.start < '$enddt' AND "
		       .       "l.finalend > '$startdt' AND "
		       .       "l.userid != $reloadid AND "
		       .       "l.userid = u.id AND "
		       .       "l.wasavailable = 1 AND "
		       .       "u.affiliationid = $affilid";
	}
	else {
		if($mode == 'default') {
			$query = "SELECT DATE_FORMAT(l.start, '%k') AS shour, "
			       .        "DATE_FORMAT(l.start, '%i') AS smin, "
			       .        "DATE_FORMAT(l.finalend, '%k') AS ehour, "
			       .        "DATE_FORMAT(l.finalend, '%i') AS emin "
			       . "FROM log l "
			       . "WHERE l.start < '$enddt' AND "
			       .       "l.finalend > '$startdt' AND "
			       .       "l.userid != $reloadid AND "
			       .       "l.wasavailable = 1";
		}
		else {
			$query = "SELECT DATE_FORMAT(l.start, '%k') AS shour, "
			       .        "DATE_FORMAT(l.start, '%i') AS smin, "
			       .        "DATE_FORMAT(l.finalend, '%k') AS ehour, "
			       .        "DATE_FORMAT(l.finalend, '%i') AS emin "
			       . "FROM log l "
			       . "JOIN ("
			       .       "SELECT s.logid, "
			       .              "MIN(s.computerid) AS computerid "
			       .       "FROM sublog s, "
			       .            "computer c "
			       .       "WHERE s.computerid = c.id AND "
			       .             "c.provisioningid = $provid "
			       .       "GROUP BY logid "
			       .       ") AS s ON (s.logid = l.id) "
			       . "WHERE l.start < '$enddt' AND "
			       .       "l.finalend > '$startdt' AND "
			       .       "l.userid != $reloadid AND "
			       .       "l.wasavailable = 1";
		}
	}
	$qh = doQuery($query, 296);
	while($row = mysql_fetch_assoc($qh)) {
		$startmin = ($row['shour'] * 60) + $row['smin'];
		$endmin = ($row['ehour'] * 60) + $row['emin'];

		for($binstart = 0, $binend = 60, $binindex = 0; 
		   $binend <= 1440;
		   $binstart += 60, $binend += 60, $binindex++) {
			if($binend <= $startmin)
				continue;
			elseif($startmin < $binend &&
				$endmin > $binstart) {
				$data["points"][$binindex]['y']++;
			}
			elseif($binstart >= $endmin)
				break;
		}
	}

	# comment this to change graph to be aggregate instead of average
	foreach($data["points"] as $key => $val) {
		$newval = $val['y'] / $days;
		if($newval - (int)$newval != 0)
			$newval = sprintf('%.2f', $newval);
		$data['points'][$key]['y'] = $newval;
		$data['points'][$key]['tooltip'] = $newval;
		if($newval > $data['maxy'])
			$data['maxy'] = $newval;
	}

	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn statHourFormatX($val)
///
/// \param $val - hour of day (0-23)
///
/// \return day of week
///
/// \brief formats $val into "hour am/pm"
///
////////////////////////////////////////////////////////////////////////////////
function statHourFormatX($val) {
	if($val == 0)
		return "12 am ";
	elseif($val < 12)
		return "$val am ";
	elseif($val == 12)
		return "$val pm ";
	else
		return $val - 12 . " pm ";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphDayConUsersData($start, $end, $affilid, $mode, $provid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
/// \param $mode - stat mode - 'default' or 'provisioning'
/// \param $provid - provisioning id - ignored unless $mode is 'provisioning'
///
/// \return an array with three keys:\n
/// \b points - an array with y and tooltip keys that have the same value which
///             is the y value at that point\n
/// \b xlabels - an array with value and text keys, value's value is just an
///              increasing integer starting from 1, text's value is the label
///              to display on the x axis for the poing\n
/// \b maxy - the max y value of the data
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the max concurrent users per day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphDayConUsersData($start, $end, $affilid, $mode, $provid) {
	$startdt = $start . " 00:00:00";
	$enddt = $end . " 23:59:59";
	$startunix = datetimeToUnix($startdt);
	$endunix = datetimeToUnix($enddt) + 1;

	$daycnt = ($endunix - $startunix) / SECINDAY;
	if($daycnt - (int)$daycnt > 0.5)
		$daycnt = (int)$daycnt + 1;
	else
		$daycnt = (int)$daycnt;
	if($endunix >= time())
		$daycnt--;

	$data = array();
	$data["points"] = array();
	$data["xlabels"] = array();
	$data["maxy"] = 0;
	$cachepts = array();
	$addcache = array();

	$reloadid = getUserlistID('vclreload@Local');
	$cnt = 0;
	$query = "SELECT statdate, "
	       .        "value "
	       . "FROM statgraphcache "
	       . "WHERE graphtype = 'concurres' AND "
			 .       "affiliationid = $affilid AND "
	       .       "statdate >= '$start' AND "
	       .       "statdate <= '$end' AND "
	       .       "provisioningid = $provid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$cachepts[$row['statdate']] = $row['value'];
	if((count($cachepts) + 31) < $daycnt) {
		$data = array('nodata' => i('(too much computational time required to generate this graph)'));
		return $data;
	}
	for($daystart = $startunix; $daystart < $endunix; $daystart += SECINDAY) {
		$cnt++;
		$startdt = unixToDatetime($daystart);
		$enddt = unixToDatetime($daystart + SECINDAY);
		$tmp = explode(' ', $startdt);
		$key = $tmp[0];
		if(array_key_exists($key, $cachepts))
			$value = $cachepts[$key];
		else {
			$count = array();
			for($j = 0; $j < 24; $j++)
				$count[$j] = 0;
			if($affilid != 0) {
				$query = "SELECT UNIX_TIMESTAMP(l.start) AS start, "
				       .        "UNIX_TIMESTAMP(l.finalend) AS end "
				       . "FROM log l, "
				       .      "user u "
				       . "WHERE l.start < '$enddt' AND "
				       .       "l.finalend > '$startdt' AND "
				       .       "l.userid != $reloadid AND "
				       .       "l.userid = u.id AND "
					    .       "u.affiliationid = $affilid";
			}
			else {
				if($mode == 'default') {
					$query = "SELECT UNIX_TIMESTAMP(l.start) AS start, "
					       .        "UNIX_TIMESTAMP(l.finalend) AS end "
					       . "FROM log l "
					       . "WHERE l.start < '$enddt' AND "
					       .       "l.finalend > '$startdt' AND "
					       .       "l.userid != $reloadid";
				}
				elseif($mode == 'provisioning') {
					$query = "SELECT UNIX_TIMESTAMP(l.start) AS start, "
					       .        "UNIX_TIMESTAMP(l.finalend) AS end "
					       . "FROM log l "
					       . "JOIN ("
					       .       "SELECT s.logid, "
					       .              "MIN(s.computerid) AS computerid "
					       .       "FROM sublog s, "
					       .            "computer c "
					       .       "WHERE s.computerid = c.id AND "
					       .             "c.provisioningid = $provid "
					       .       "GROUP BY logid "
					       .       ") AS s ON (s.logid = l.id) "
					       . "WHERE l.start < '$enddt' AND "
					       .       "l.finalend > '$startdt' AND "
					       .       "l.userid != $reloadid";
				}
			}
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$unixstart = $row["start"];
				$unixend = $row["end"];
				for($binstart = $daystart, $binend = $daystart + 3600, $binindex = 0;
				   $binstart <= $unixend && $binend <= ($daystart + SECINDAY);
				   $binstart += 3600, $binend += 3600, $binindex++) {
					if($binend <= $unixstart) {
						continue;
					}
					elseif($unixstart < $binend &&
						$unixend > $binstart) {
						$count[$binindex]++;
					}
					elseif($binstart >= $unixend) {
						break;
					}
				}
			}
			rsort($count);
			$value = $count[0];
			$addcache[$startdt] = (int)$value;
		}
		$label = date('m/d/Y', $daystart);
		$data["points"][] = array('y' => $value, 'tooltip' => "$label: {$value}");
		if($value > $data['maxy'])
			$data['maxy'] = $value;
		$data['xlabels'][] = array('value' => $cnt, 'text' => $label);
	}
	if(count($addcache))
		addToStatGraphCache('concurres', $addcache, $affilid, $provid);
	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphConBladeUserData($start, $end, $affilid, $mode, $provid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
/// \param $mode - stat mode - 'default' or 'provisioning'
/// \param $provid - provisioning id - ignored unless $mode is 'provisioning'
///
/// \return an array with three keys:\n
/// \b points - an array with y and tooltip keys that have the same value which
///             is the y value at that point\n
/// \b xlabels - an array with value and text keys, value's value is just an
///              increasing integer starting from 1, text's value is the label
///              to display on the x axis for the poing\n
/// \b maxy - the max y value of the data
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the max concurrent users of blades per day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphConBladeUserData($start, $end, $affilid, $mode, $provid) {
	$startdt = $start . " 00:00:00";
	$enddt = $end . " 23:59:59";
	$startunix = datetimeToUnix($startdt);
	$endunix = datetimeToUnix($enddt) + 1;

	$daycnt = ($endunix - $startunix) / SECINDAY;
	if($daycnt - (int)$daycnt > 0.5)
		$daycnt = (int)$daycnt + 1;
	else
		$daycnt = (int)$daycnt;
	if($endunix >= time())
		$daycnt--;

	$data = array();
	$data["points"] = array();
	$data["xlabels"] = array();
	$data["maxy"] = 0;
	$cachepts = array();
	$addcache = array();

	$reloadid = getUserlistID('vclreload@Local');
	$cnt = 0;
	$query = "SELECT statdate, "
	       .        "value "
	       . "FROM statgraphcache "
	       . "WHERE graphtype = 'concurblade' AND "
			 .       "affiliationid = $affilid AND "
	       .       "statdate >= '$start' AND "
	       .       "statdate <= '$end' AND "
	       .       "provisioningid = $provid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$cachepts[$row['statdate']] = $row['value'];
	if((count($cachepts) + 31) < $daycnt) {
		$data = array('nodata' => i('(too much computational time required to generate this graph)'));
		return $data;
	}
	for($daystart = $startunix; $daystart < $endunix; $daystart += SECINDAY) {
		$cnt++;
		$startdt = unixToDatetime($daystart);
		$enddt = unixToDatetime($daystart + SECINDAY);
		$tmp = explode(' ', $startdt);
		$key = $tmp[0];
		if(array_key_exists($key, $cachepts))
			$value = $cachepts[$key];
		else {
			$count = array();
			for($j = 0; $j < 24; $j++)
				$count[$j] = 0;
			if($affilid != 0) {
				$query = "SELECT s.hostcomputerid, "
				       .        "l.start AS start, "
				       .        "l.finalend AS end, "
				       .        "c.type "
						 . "FROM log l, "
				       .      "user u, "
				       .      "sublog s "
				       . "LEFT JOIN computer c ON (s.computerid = c.id) "
				       . "LEFT JOIN computer c2 ON (s.hostcomputerid = c2.id) "
				       . "WHERE l.userid = u.id AND "
				       .       "l.start < '$enddt' AND "
				       .       "l.finalend > '$startdt' AND "
				       .       "s.logid = l.id AND "
				       .       "l.wasavailable = 1 AND "
				       .       "l.userid != $reloadid AND "
						 .       "(c.type = 'blade' OR "
				       .       " (c.type = 'virtualmachine' AND c2.type = 'blade')) AND "
						 .       "u.affiliationid = $affilid";
			}
			else {
				if($mode == 'default') {
					$query = "SELECT s.hostcomputerid, "
					       .        "l.start AS start, "
					       .        "l.finalend AS end, "
					       .        "c.type "
							 . "FROM log l, "
					       .      "sublog s "
					       . "LEFT JOIN computer c ON (s.computerid = c.id) "
					       . "LEFT JOIN computer c2 ON (s.hostcomputerid = c2.id) "
					       . "WHERE l.start < '$enddt' AND "
					       .       "l.finalend > '$startdt' AND "
					       .       "s.logid = l.id AND "
					       .       "l.wasavailable = 1 AND "
					       .       "l.userid != $reloadid AND "
							 .       "(c.type = 'blade' OR "
					       .       " (c.type = 'virtualmachine' AND c2.type = 'blade'))";
				}
				elseif($mode == 'provisioning') {
					$query = "SELECT s.hostcomputerid, "
					       .        "l.start AS start, "
					       .        "l.finalend AS end, "
					       .        "c.type "
							 . "FROM log l "
					       . "JOIN ("
					       .       "SELECT s.logid, "
					       .              "MIN(s.computerid) AS computerid "
					       .       "FROM sublog s, "
					       .            "computer c "
					       .       "WHERE s.computerid = c.id AND "
					       .             "c.provisioningid = $provid "
					       .       "GROUP BY logid "
					       .       ") AS s2 ON (s2.logid = l.id), "
					       .      "sublog s "
					       . "LEFT JOIN computer c ON (s.computerid = c.id) "
					       . "LEFT JOIN computer c2 ON (s.hostcomputerid = c2.id) "
					       . "WHERE l.start < '$enddt' AND "
					       .       "l.finalend > '$startdt' AND "
					       .       "s.logid = l.id AND "
					       .       "l.wasavailable = 1 AND "
					       .       "l.userid != $reloadid AND "
							 .       "(c.type = 'blade' OR "
					       .       " (c.type = 'virtualmachine' AND c2.type = 'blade'))";
				}
			}
			$qh = doQuery($query, 101);
			$comps = array();
			while($row = mysql_fetch_assoc($qh)) {
				$unixstart = datetimeToUnix($row["start"]);
				$unixend = datetimeToUnix($row["end"]);
				for($binstart = $daystart, $binend = $daystart + 3600, $binindex = 0;
				   $binstart <= $unixend && $binend <= ($daystart + SECINDAY);
				   $binstart += 3600, $binend += 3600, $binindex++) {
					if($row['type'] == 'virtualmachine') {
						if(array_key_exists($binindex, $comps) &&
						   array_key_exists($row['hostcomputerid'], $comps[$binindex]))
							continue;
						$comps[$binindex][$row['hostcomputerid']] = 1;
					}
					if($binend <= $unixstart) {
						continue;
					}
					elseif($unixstart < $binend &&
						$unixend > $binstart) {
						$count[$binindex]++;
					}
					elseif($binstart >= $unixend) {
						break;
					}
				}
			}
			rsort($count);
			$value = $count[0];
			$addcache[$startdt] = (int)$value;
		}
		$label = date('m/d/Y', $daystart);
		$data["points"][] = array('y' => $value, 'tooltip' => "$label: {$value}");
		if($value > $data['maxy'])
			$data['maxy'] = $value;
		$data['xlabels'][] = array('value' => $cnt, 'text' => $label);
	}
	if(count($addcache))
		addToStatGraphCache('concurblade', $addcache, $affilid, $provid);
	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphConVMUserData($start, $end, $affilid, $mode, $provid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
/// \param $mode - stat mode - 'default' or 'provisioning'
/// \param $provid - provisioning id - ignored unless $mode is 'provisioning'
///
/// \return an array with three keys:\n
/// \b points - an array with y and tooltip keys that have the same value which
///             is the y value at that point\n
/// \b xlabels - an array with value and text keys, value's value is just an
///              increasing integer starting from 1, text's value is the label
///              to display on the x axis for the poing\n
/// \b maxy - the max y value of the data
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the max concurrent users of vms per day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphConVMUserData($start, $end, $affilid, $mode, $provid) {
	$startdt = $start . " 00:00:00";
	$enddt = $end . " 23:59:59";
	$startunix = datetimeToUnix($startdt);
	$endunix = datetimeToUnix($enddt) + 1;

	$daycnt = ($endunix - $startunix) / SECINDAY;
	if($daycnt - (int)$daycnt > 0.5)
		$daycnt = (int)$daycnt + 1;
	else
		$daycnt = (int)$daycnt;
	if($endunix >= time())
		$daycnt--;

	$data = array();
	$data["points"] = array();
	$data["xlabels"] = array();
	$data["maxy"] = 0;
	$cachepts = array();
	$addcache = array();

	$reloadid = getUserlistID('vclreload@Local');
	$cnt = 0;
	$query = "SELECT statdate, "
	       .        "value "
	       . "FROM statgraphcache "
	       . "WHERE graphtype = 'concurvm' AND "
			 .       "affiliationid = $affilid AND "
	       .       "statdate >= '$start' AND "
	       .       "statdate <= '$end' AND "
	       .       "provisioningid = $provid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$cachepts[$row['statdate']] = $row['value'];
	if((count($cachepts) + 31) < $daycnt) {
		$data = array('nodata' => i('(too much computational time required to generate this graph)'));
		return $data;
	}
	for($daystart = $startunix; $daystart < $endunix; $daystart += SECINDAY) {
		$cnt++;
		$startdt = unixToDatetime($daystart);
		$enddt = unixToDatetime($daystart + SECINDAY);
		$tmp = explode(' ', $startdt);
		$key = $tmp[0];
		if(array_key_exists($key, $cachepts))
			$value = $cachepts[$key];
		else {
			$count = array();
			for($j = 0; $j < 24; $j++)
				$count[$j] = 0;
			if($affilid != 0) {
				$query = "SELECT l.start AS start, "
				       .        "l.finalend AS end "
				       . "FROM log l, "
				       .      "sublog s, "
				       .      "computer c, "
				       .      "user u "
				       . "WHERE l.userid = u.id AND "
				       .       "l.start < '$enddt' AND "
				       .       "l.finalend > '$startdt' AND "
				       .       "s.logid = l.id AND "
				       .       "s.computerid = c.id AND "
				       .       "l.wasavailable = 1 AND "
				       .       "c.type = 'virtualmachine' AND "
				       .       "l.userid != $reloadid AND "
						 .       "u.affiliationid = $affilid";
			}
			else {
				if($mode == 'default') {
					$query = "SELECT l.start AS start, "
					       .        "l.finalend AS end "
					       . "FROM log l, "
					       .      "sublog s, "
					       .      "computer c "
					       . "WHERE l.start < '$enddt' AND "
					       .       "l.finalend > '$startdt' AND "
					       .       "s.logid = l.id AND "
					       .       "s.computerid = c.id AND "
					       .       "l.wasavailable = 1 AND "
					       .       "c.type = 'virtualmachine' AND "
					       .       "l.userid != $reloadid";
				}
				elseif($mode == 'provisioning') {
					$query = "SELECT l.start AS start, "
					       .        "l.finalend AS end "
					       . "FROM computer c, "
					       .      "sublog s, "
					       .      "log l "
					       . "JOIN ("
					       .       "SELECT s.logid, "
					       .              "MIN(s.computerid) AS computerid "
					       .       "FROM sublog s, "
					       .            "computer c "
					       .       "WHERE s.computerid = c.id AND "
					       .             "c.provisioningid = $provid "
					       .       "GROUP BY logid "
					       .       ") AS s2 ON (s2.logid = l.id) "
					       . "WHERE l.start < '$enddt' AND "
					       .       "l.finalend > '$startdt' AND "
					       .       "s.logid = l.id AND "
					       .       "s.computerid = c.id AND "
					       .       "l.wasavailable = 1 AND "
					       .       "c.type = 'virtualmachine' AND "
					       .       "l.userid != $reloadid";
				}
			}
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$unixstart = datetimeToUnix($row["start"]);
				$unixend = datetimeToUnix($row["end"]);
				for($binstart = $daystart, $binend = $daystart + 3600, $binindex = 0;
				   $binstart <= $unixend && $binend <= ($daystart + SECINDAY);
				   $binstart += 3600, $binend += 3600, $binindex++) {
					if($binend <= $unixstart) {
						continue;
					}
					elseif($unixstart < $binend &&
						$unixend > $binstart) {
						$count[$binindex]++;
					}
					elseif($binstart >= $unixend) {
						break;
					}
				}
			}
			rsort($count);
			$value = $count[0];
			$addcache[$startdt] = (int)$value;
		}
		$label = date('m/d/Y', $daystart);
		$data["points"][] = array('y' => $value, 'tooltip' => "$label: {$value}");
		if($value > $data['maxy'])
			$data['maxy'] = $value;
		$data['xlabels'][] = array('value' => $cnt, 'text' => $label);
	}
	if(count($addcache))
		addToStatGraphCache('concurvm', $addcache, $affilid, $provid);
	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addToStatGraphCache($type, $addcache, $affilid, $provid)
///
/// \param $type - type of data to add, one of totalres, concurres, concurblade,
/// or concurvm
/// \param $addcache - array of data where the keys are a date and the values
/// are the stat value for that date
/// \param $affilid - affiliation id for which the data is associated
/// \param $provid - provisioning id - 0 for all provisioning ids, > 0 otherwise
///
/// \brief adds passed in data to statgraphcache table
///
////////////////////////////////////////////////////////////////////////////////
function addToStatGraphCache($type, $addcache, $affilid, $provid) {
	$nosave = time() - SECINDAY;
	$values = array();
	if($affilid == 0)
		$affilid = 'NULL';
	if($provid == 0)
		$provid = 'NULL';
	foreach($addcache as $date => $value) {
		$startts = datetimeToUnix($date);
		if($startts < $nosave) {
			$tmp = explode(' ', $date);
			$statdate = $tmp[0];
			$values[] = "('$type', '$statdate', $affilid, $value, $provid)";
		}
	}
	if(count($values)) {
		$insval = implode(',', $values);
		$query = "INSERT IGNORE INTO statgraphcache "
		       . "(graphtype, statdate, affiliationid, value, provisioningid) "
		       . "VALUES $insval";
		doQuery($query, 101);
	}
}
?>
