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

if($phpVer == 5) {
require_once(".ht-inc/jpgraph/jpgraph.php");
require_once(".ht-inc/jpgraph/jpgraph_bar.php");
require_once(".ht-inc/jpgraph/jpgraph_line.php");
}
else {
require_once(".ht-inc/jpgraph.old/jpgraph.php");
require_once(".ht-inc/jpgraph.old/jpgraph_bar.php");
require_once(".ht-inc/jpgraph.old/jpgraph_line.php");
}

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
	global $submitErr, $viewmode, $user;
	list($month1, $day1, $year1) = explode(',', date('F,j,Y', time() - 
	                                    (SECINDAY * 6)));
	list($month2, $day2, $year2) = explode(',', date('F,j,Y', time()));
	print "<H2>Statistic Information</H2>\n";
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
	print "Select a starting date:<br>\n";
	$months = array("",
	                "January",
	                "February",
	                "March",
	                "April",
	                "May",
	                "June",
	                "July",
	                "August",
	                "September",
	                "October",
	                "November",
	                "December");
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
		$monthkey1 = array_search($month1, $months);
		$daykey1 = array_search($day1, $days);
		$yearkey1 = array_search($year1, $years);
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	printSelectInput("month1", $months, $monthkey1);
	printSelectInput("day1", $days, $daykey1);
	printSelectInput("year1", $years, $yearkey1);
	print "<br>\n";
	print "Select a ending date:<br>\n";
	if(! $submitErr) {
		$monthkey2 = array_search($month2, $months);
		$daykey2 = array_search($day2, $days);
		$yearkey2 = array_search($year2, $years);
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	printSelectInput("month2", $months, $monthkey2);
	printSelectInput("day2", $days, $daykey2);
	printSelectInput("year2", $years, $yearkey2);
	print "<br>\n";
	if($viewmode >= ADMIN_FULL) {
		print "Select an affiliation:<br>\n";
		$affils = getAffiliations();
		if(! array_key_exists($affilid, $affils))
			$affilid = $user['affiliationid'];
		$affils = array_reverse($affils, TRUE);
		$affils[0] = "All";
		$affils = array_reverse($affils, TRUE);
		printSelectInput("affilid", $affils, $affilid);
		print "<br>\n";
	}
	$cont = addContinuationsEntry('viewstats');
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=Submit>\n";
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
	global $submitErr, $submitErrMsg, $user, $viewmode;
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

	$affils = getAffiliations();
	if($viewmode < ADMIN_FULL ||
	   ($affilid != 0 && ! array_key_exists($affilid, $affils)))
		$affilid = $user['affiliationid'];

	$start = "$year1-$month1-$day1 00:00:00";
	$end = "$year2-$month2-$day2 23:59:59";
	if(! checkdate($month1, $day1, $year1)) {
		$submitErr |= STARTERR;
		$submitErrMsg[STARTERR] = "The selected start date is not valid. Please "
		                        . "select a valid date.<br>\n";
	}
	if(! checkdate($month2, $day2, $year2)) {
		$submitErr |= ENDERR;
		$submitErrMsg[ENDERR] = "The selected end date is not valid. Please "
		                      . "select a valid date.<br>\n";
	}
	if(datetimeToUnix($start) > datetimeToUnix($end)) {
		$submitErr |= ORDERERR;
		$submitErrMsg[ORDERERR] = "The selected end date is before the selected "
		                        . "start date.  Please select an end date equal "
		                        . "to or greater than the start date.<br>\n";
	}
	if($submitErr) {
		selectStatistics();
		return;
	}

	$timestart = microtime(1);
	print "<H2>Statistic Information</H2>\n";
	print "<H3>Reservation information between $month1/$day1/$year1 and ";
	print "$month2/$day2/$year2:\n";
	print "</H3>\n";
	$reloadid = getUserlistID('vclreload');
	$query = "SELECT l.userid, "
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
	$loadtimes = array("2less" => 0, "2more" => 0);
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
	$imageload2more = array();
	$lengths = array("30min" => 0,
	                 "1hour" => 0,
	                 "2hours" => 0,
	                 "4hours" => 0,
	                 "4hrsplus" => 0);
	$totalhours = 0;
	$osusers = array();
	while($row = mysql_fetch_assoc($qh)) {
		if(! array_key_exists($row["prettyname"], $imageload2less))
			$imageload2less[$row["prettyname"]] = 0;
		if(! array_key_exists($row["prettyname"], $imageload2more))
			$imageload2more[$row["prettyname"]] = 0;

		# notavailable
		if($row["wasavailable"] == 0) {
			$notavailable++;
		}
		else {
			$totalreservations++;

			# load times
			if($row['loadtime'] < 120) {
				$loadtimes['2less']++;
				# imageload2less
				$imageload2less[$row['prettyname']]++;
			}
			else {
				$loadtimes['2more']++;
				# imageload2more
				$imageload2more[$row['prettyname']]++;
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
		if($length <= 1800)
			$lengths["30min"]++;
		elseif($length <= 3600)
			$lengths["1hour"]++;
		elseif($length <= 7200)
			$lengths["2hours"]++;
		elseif($length <= 14400)
			$lengths["4hours"]++;
		else
			$lengths["4hrsplus"]++;

		# imagehours
		if(! array_key_exists($row["prettyname"], $imagehours))
			$imagehours[$row["prettyname"]] = 0;
		$imagehours[$row["prettyname"]] += ($length / 3600);

		# total hours
		$totalhours += ($length / 3600);

		# osusers
		if(! array_key_exists($row["OS"], $osusers))
			$osusers[$row["OS"]] = array();
		$osusers[$row['OS']][$row['userid']] = 1;
	}
	print "<DIV align=center>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Total Reservations:</TH>\n";
	print "    <TD>$totalreservations</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Total Hours Used:</TH>\n";
	print "    <TD>" . (int)$totalhours . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>\"Now\" Reservations:</TH>\n";
	print "    <TD>$nows</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>\"Later\" Reservations:</TH>\n";
	print "    <TD>$futures</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Unavailable:</TH>\n";
	print "    <TD>$notavailable</TD>\n";
	print "  </TR>\n";
	if($viewmode >= ADMIN_FULL) {
		print "  <TR>\n";
		print "    <TH align=right>Load times &lt; 2 minutes:</TH>\n";
		print "    <TD>{$loadtimes['2less']}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Load times &gt;= 2 minutes:</TH>\n";
		print "    <TD>{$loadtimes['2more']}</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Total Unique Users:</TH>\n";
	print "    <TD>" . count($users) . "</TD>\n";
	print "  </TR>\n";
	foreach(array_keys($osusers) as $key) {
		print "  <TR>\n";
		print "    <TH align=right>Unique Users of $key:</TH>\n";
		print "    <TD>" . count($osusers[$key]) . "</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";

	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH>Reservations</TH>\n";
	print "    <TH>Unique Users</TH>\n";
	print "    <TH>Hours Used</TH>\n";
	if($viewmode >= ADMIN_FULL) {
		print "    <TH>&lt; 2 min load time</TH>\n";
		print "    <TH>&gt;= 2 min load time</TH>\n";
	}
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
		if($viewmode >= ADMIN_FULL) {
			print "    <TD align=center>{$imageload2less[$key]}</TD>\n";
			print "    <TD align=center>{$imageload2more[$key]}</TD>\n";
		}
		print "  </TR>\n";
	}
	print "</TABLE>\n";

	print "<H3>Durations:</H3>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>0 - 30 Min:</TH>\n";
	print "    <TD>" . $lengths["30min"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>30 Min - 1 Hour:</TH>\n";
	print "    <TD>" . $lengths["1hour"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>1 Hour - 2 Hours:</TH>\n";
	print "    <TD>" . $lengths["2hours"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>2 Hours - 4 Hours:</TH>\n";
	print "    <TD>" . $lengths["4hours"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>&gt; 4 Hours:</TH>\n";
	print "    <TD>" . $lengths["4hrsplus"] . "</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";

	print "<H3>Ending information:</H3>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Deleted:</TH>\n";
	print "    <TD>" . $ending["deleted"] . "</TD>\n";
	print "    <TD rowspan=7><img src=\"images/blank.gif\" width=5></TD>\n";
	print "    <TD>(Future reservation deleted before start time reached)</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Released:</TH>\n";
	print "    <TD>" . $ending["released"] . "</TD>\n";
	print "    <TD>(Reservation released before end time reached)</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Not Acknowledged:</TH>\n";
	print "    <TD>" . $ending["noack"] . "</TD>\n";
	print "    <TD>(\"Connect!\" button never clicked)</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>No Login:</TH>\n";
	print "    <TD>" . $ending["nologin"] . "</TD>\n";
	print "    <TD>(User never logged in)</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>End of Reservation:</TH>\n";
	print "    <TD>" . $ending["EOR"] . "</TD>\n";
	print "    <TD>(End of reservation reached)</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Timed Out:</TH>\n";
	print "    <TD>" . $ending["timeout"] . "</TD>\n";
	print "    <TD>(Disconnect and no reconnection within 15 minutes)</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Failed:</TH>\n";
	print "    <TD>" . $ending["failed"] . "</TD>\n";
	print "    <TD>(Reserved computer failed to get prepared for user)</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<br>\n";

	$unixstart = datetimeToUnix($start);
	$unixend = datetimeToUnix($end);
	$start = date('Y-m-d', $unixstart);
	$end = date('Y-m-d', $unixend);
	$cdata = array('start' => $start,
	               'end' => $end,
	               'affilid' => $affilid);
	print "<H2>Reservations by Day</H2>\n";
	$cont = addContinuationsEntry('statgraphday', $cdata);
	print "<img src=" . BASEURL . SCRIPT . "?continuation=$cont>";

	print "<H2>Max Concurrent Reservations By Day</H2>\n";
	if($unixend - $unixstart > SECINMONTH)
		print "(this graph only available for up to a month of data)<br>\n";
	else {
		$cont = addContinuationsEntry('statgraphdayconcuruser', $cdata);
		print "<img src=" . BASEURL . SCRIPT . "?continuation=$cont>";
	}

	print "<H2>Max Concurrent Blade Reservations By Day</H2>\n";
	if($unixend - $unixstart > SECINMONTH)
		print "(this graph only available for up to a month of data)<br>\n";
	else {
		$cont = addContinuationsEntry('statgraphdayconcurblade', $cdata);
		print "<img src=" . BASEURL . SCRIPT . "?continuation=$cont>";
	}

	print "<H2>Reservations by Hour</H2>\n";
	print "(Averaged over the time period)<br><br>\n";
	$cont = addContinuationsEntry('statgraphhour', $cdata);
	print "<img src=" . BASEURL . SCRIPT . "?continuation=$cont>";
	print "</div>\n";

	$endtime = microtime(1);
	$end = $endtime - $timestart;
	#print "running time: $endtime - $timestart = $end<br>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sendStatGraphDay()
///
/// \brief sends a graph image
///
////////////////////////////////////////////////////////////////////////////////
function sendStatGraphDay() {
	global $xaxislabels, $inContinuation;
	if(! $inContinuation)
		return;
	$start = getContinuationVar("start");
	$end = getContinuationVar("end");
	$affilid = getContinuationVar("affilid");
	$graphdata = getStatGraphDayData($start, $end, $affilid);
	$count = count($graphdata["labels"]);
	if($count < 8)
		$labelinterval = 1;
	else
		$labelinterval = $count / 7;
	$xaxislabels = $graphdata["labels"];
	$graph = new Graph(300, 300, "auto");
	$graph->SetScale("textlin");
	$plot = new BarPlot($graphdata["points"]);
	$graph->Add($plot);
	$graph->xaxis->SetLabelFormatCallback('statXaxisDayCallback');
	$graph->xaxis->SetLabelAngle(90);
	$graph->xaxis->SetTextLabelInterval($labelinterval);
	$graph->yaxis->SetTitle('Reservations with start time on given day', 
	                        'high');
	$graph->SetMargin(40,40,20,80);
	$graph->Stroke();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphDayData($start, $end, $affilid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
///
/// \return an array whose keys are the days (in YYYY-MM-DD format) between
/// $start and $end, inclusive, and whose values are the number of reservations
/// on each day
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the number of reservations on each day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphDayData($start, $end, $affilid) {
	$startunix = datetimeToUnix($start . " 00:00:00");
	$endunix = datetimeToUnix($end . " 23:59:59");

	$data = array();
	$data["points"] = array();
	$data["labels"] = array();
	$reloadid = getUserlistID('vclreload');
	for($i = $startunix; $i < $endunix; $i += SECINDAY) {
		array_push($data["labels"], date('Y-m-d', $i));
		$startdt = unixToDatetime($i);
		$enddt = unixToDatetime($i + SECINDAY);
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
			$query = "SELECT count(l.id) "
			       . "FROM log l "
			       . "WHERE l.start >= '$startdt' AND "
			       .       "l.start < '$enddt' AND "
			       .       "l.userid != $reloadid AND "
			       .       "l.wasavailable = 1";
		}
		$qh = doQuery($query, 295);
		if($row = mysql_fetch_row($qh))
			array_push($data["points"], $row[0]);
		else
			array_push($data["points"], 0);
	}
	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn statXaxisDayCallback($val)
///
/// \param $val - value passed in by SetLabelFormatCallback
///
/// \return day of week
///
/// \brief formats $val into day of week
///
////////////////////////////////////////////////////////////////////////////////
function statXaxisDayCallback($val) {
	global $xaxislabels;
	if(array_key_exists((int)$val, $xaxislabels)) {
		return date('n/d/Y', datetimeToUnix($xaxislabels[$val] . " 00:00:00")) . " ";
	}
	else {
		return $val;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sendStatGraphHour()
///
/// \brief sends a graph image
///
////////////////////////////////////////////////////////////////////////////////
function sendStatGraphHour() {
	global $xaxislabels, $inContinuation;
	if(! $inContinuation)
		return;
	$start = getContinuationVar("start");
	$end = getContinuationVar("end");
	$affilid = getContinuationVar("affilid");
	$graphdata = getStatGraphHourData($start, $end, $affilid);
	$graph = new Graph(300, 300, "auto");
	$graph->SetScale("textlin");
	$plot = new LinePlot($graphdata["points"]);
	$graph->Add($plot);
	$graph->xaxis->SetLabelFormatCallback('statXaxisHourCallback');
	$graph->xaxis->SetLabelAngle(90);
	$graph->xaxis->SetTextLabelInterval(2);
	$graph->yaxis->SetTitle('Active reservations during given hour', 'high');
	$graph->SetMargin(40,40,20,80);
	$graph->Stroke();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphHourData($start, $end, $affilid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
///
/// \return an array whose keys are the days (in YYYY-MM-DD format) between
/// $start and $end, inclusive, and whose values are the number of reservations
/// on each day
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the number of reservations on each day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphHourData($start, $end, $affilid) {
	$startdt = $start . " 00:00:00";
	$enddt = $end . " 23:59:59";
	$startunix = datetimeToUnix($startdt);
	$endunix = datetimeToUnix($enddt) + 1;
	$enddt = unixToDatetime($endunix);
	$days = ($endunix - $startunix) / SECINDAY;

	$data = array();
	$data["points"] = array();
	for($i = 0; $i < 24; $i++) {
		$data["points"][$i] = 0;
	}

	$reloadid = getUserlistID('vclreload');
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
	$qh = doQuery($query, 296);
	$count = 0;
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
				$data["points"][$binindex]++;
			}
			elseif($binstart >= $endmin)
				break;
		}
	}

	# comment this to change graph to be aggregate instead of average
	foreach($data["points"] as $key => $val)
		$data["points"][$key] = $val / $days;

	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn statXaxisHourCallback($val)
///
/// \param $val - value passed in by SetLabelFormatCallback
///
/// \return day of week
///
/// \brief formats $val into day of week
///
////////////////////////////////////////////////////////////////////////////////
function statXaxisHourCallback($val) {
	if($val == 0) {
		return "12 am ";
	}
	elseif($val < 12) {
		return "$val am ";
	}
	elseif($val == 12) {
		return "$val pm ";
	}
	else {
		return $val - 12 . " pm ";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sendStatGraphDayConUsers()
///
/// \brief sends a graph image
///
////////////////////////////////////////////////////////////////////////////////
function sendStatGraphDayConUsers() {
	global $xaxislabels, $inContinuation;
	if(! $inContinuation)
		return;
	$start = getContinuationVar("start");
	$end = getContinuationVar("end");
	$affilid = getContinuationVar("affilid");
	$graphdata = getStatGraphDayConUsersData($start, $end, $affilid);
	$count = count($graphdata["labels"]);
	if($count < 8)
		$labelinterval = 1;
	else
		$labelinterval = $count / 7;
	$xaxislabels = $graphdata["labels"];
	$graph = new Graph(300, 300, "auto");
	$graph->SetScale("textlin");
	$plot = new BarPlot($graphdata["points"]);
	$graph->Add($plot);
	$graph->xaxis->SetLabelFormatCallback('statXaxisDayConUsersCallback');
	$graph->xaxis->SetLabelAngle(90);
	$graph->xaxis->SetTextLabelInterval($labelinterval);
	$graph->yaxis->SetTitle('Maximum concurrent reservations per day', 
	                        'high');
	$graph->SetMargin(40,40,20,80);
	$graph->Stroke();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphDayConUsersData($start, $end, $affilid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
///
/// \return an array whose keys are the days (in YYYY-MM-DD format) between
/// $start and $end, inclusive, and whose values are the max concurrent users
/// on each day
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the max concurrent users per day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphDayConUsersData($start, $end, $affilid) {
	$startdt = $start . " 00:00:00";
	$enddt = $end . " 23:59:59";
	$startunix = datetimeToUnix($startdt);
	$endunix = datetimeToUnix($enddt) + 1;
	$days = ($endunix - $startunix) / SECINDAY;

	$data = array();
	$data["points"] = array();
	$data["labels"] = array();

	$reloadid = getUserlistID('vclreload');
	for($daystart = $startunix; $daystart < $endunix; $daystart += SECINDAY) {
		array_push($data["labels"], date('Y-m-d', $daystart));
		$count = array();
		for($j = 0; $j < 24; $j++) {
			$count[$j] = 0;
		}

		$startdt = unixToDatetime($daystart);
		$enddt = unixToDatetime($daystart + SECINDAY);
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
			$query = "SELECT UNIX_TIMESTAMP(l.start) AS start, "
			       .        "UNIX_TIMESTAMP(l.finalend) AS end "
			       . "FROM log l "
			       . "WHERE l.start < '$enddt' AND "
			       .       "l.finalend > '$startdt' AND "
			       .       "l.userid != $reloadid";
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
		array_push($data["points"], $count[0]);
	}
	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn statXaxisDayConUsersCallback($val)
///
/// \param $val - value passed in by SetLabelFormatCallback
///
/// \return day of week
///
/// \brief formats $val into day of week
///
////////////////////////////////////////////////////////////////////////////////
function statXaxisDayConUsersCallback($val) {
	global $xaxislabels;
	if(array_key_exists((int)$val, $xaxislabels)) {
		return date('n/d/Y', datetimeToUnix($xaxislabels[$val] . " 00:00:00")) . " ";
	}
	else {
		return $val;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sendStatGraphConBladeUser()
///
/// \brief sends a graph image of max concurrent users of blades per day
///
////////////////////////////////////////////////////////////////////////////////
function sendStatGraphConBladeUser() {
	global $xaxislabels, $inContinuation;
	if(! $inContinuation)
		return;
	$start = getContinuationVar("start");
	$end = getContinuationVar("end");
	$affilid = getContinuationVar("affilid");
	$graphdata = getStatGraphConBladeUserData($start, $end, $affilid);
	$count = count($graphdata["labels"]);
	if($count < 8)
		$labelinterval = 1;
	else
		$labelinterval = $count / 7;
	$xaxislabels = $graphdata["labels"];
	$graph = new Graph(300, 300, "auto");
	$graph->SetScale("textlin");
	$plot = new BarPlot($graphdata["points"]);
	$graph->Add($plot);
	$graph->xaxis->SetLabelFormatCallback('statXaxisDayConUsersCallback');
	$graph->xaxis->SetLabelAngle(90);
	$graph->xaxis->SetTextLabelInterval($labelinterval);
	$graph->yaxis->SetTitle('Maximum concurrent reservations per day', 
	                        'high');
	$graph->SetMargin(40,40,20,80);
	$graph->Stroke();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatGraphConBladeUserData($start, $end, $affilid)
///
/// \param $start - starting day in YYYY-MM-DD format
/// \param $end - ending day in YYYY-MM-DD format
/// \param $affilid - affiliationid of data to gather
///
/// \return an array whose keys are the days (in YYYY-MM-DD format) between
/// $start and $end, inclusive, and whose values are the max concurrent users
/// of blades on each day
///
/// \brief queries the log table to get reservations between $start and $end
/// and creates an array with the max concurrent users of blades per day
///
////////////////////////////////////////////////////////////////////////////////
function getStatGraphConBladeUserData($start, $end, $affilid) {
	$startdt = $start . " 00:00:00";
	$enddt = $end . " 23:59:59";
	$startunix = datetimeToUnix($startdt);
	$endunix = datetimeToUnix($enddt) + 1;
	$days = ($endunix - $startunix) / SECINDAY;

	$data = array();
	$data["points"] = array();
	$data["labels"] = array();

	$reloadid = getUserlistID('vclreload');
	for($daystart = $startunix; $daystart < $endunix; $daystart += SECINDAY) {
		array_push($data["labels"], date('Y-m-d', $daystart));
		$count = array();
		for($j = 0; $j < 24; $j++) {
			$count[$j] = 0;
		}
		$startdt = unixToDatetime($daystart);
		$enddt = unixToDatetime($daystart + SECINDAY);
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
			       .       "c.type = 'blade' AND "
			       .       "l.userid != $reloadid AND "
			       .       "u.affiliationid = $affilid";
		}
		else {
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
			       .       "c.type = 'blade' AND "
			       .       "l.userid != $reloadid";
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
		array_push($data["points"], $count[0]);
	}
	return($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn statXaxisConBladeUserCallback($val)
///
/// \param $val - value passed in by SetLabelFormatCallback
///
/// \return day of week
///
/// \brief formats $val into day of week
///
////////////////////////////////////////////////////////////////////////////////
function statXaxisConBladeUserCallback($val) {
	global $xaxislabels;
	if(array_key_exists((int)$val, $xaxislabels)) {
		return date('n/d/Y', datetimeToUnix($xaxislabels[$val] . " 00:00:00")) . " ";
	}
	else {
		return $val;
	}
}
?>
