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
/// \fn dashboard()
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function dashboard() {
	print "<h2>VCL Dashboard</h2>\n";
	print "<table summary=\"\">\n";
	print "<tr>\n";

	# -------- left column ---------
	print "<td valign=\"top\">\n";
	print addWidget('status', 'Current Status');
	print addWidget('topimages', 'Top 5 Images in Use', '(Reservations &lt; 24 hours long)');
	print addWidget('toplongimages', 'Top 5 Long Term Images in Use', '(Reservations &gt; 24 hours long)');
	print addWidget('topfailedcomputers', 'Top Recent Computer Failures', '(Failed in the last 5 days)');
	print "</td>\n";
	# -------- end left column ---------

	# ---------- right column ---------
	print "<td valign=\"top\">\n";
	print addWidget('topfailed', 'Top Recent Image Failures', '(Failed in the last 5 days)');
	print addWidget('blockallocation', 'Block Allocation Status');
	print addLineChart('reschart', 'Past 12 Hours of Active Reservations');
	print "</td>\n";
	# -------- end right column --------

	print "</tr>\n";
	print "</table>\n";
	$cont = addContinuationsEntry('AJupdateDashboard', array('val' => 0), 60, 1, 0);
	print "<input type=\"hidden\" id=\"updatecont\" value=\"$cont\">\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn 
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateDashboard() {
	$data = array();
	$data['cont'] = addContinuationsEntry('AJupdateDashboard', array(), 60, 1, 0);
	$data['status'] = getStatusData();
	$data['topimages'] = getTopImageData();
	$data['toplongimages'] = getTopLongImageData();
	$data['topfailed'] = getTopFailedData();
	$data['topfailedcomputers'] = getTopFailedComputersData();
	$data['reschart'] = getActiveResChartData();
	$data['blockallocation'] = getBlockAllocationData();
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addWidget($id, $title)
///
/// \param 
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function addWidget($id, $title, $extra='') {
	$txt  = "<div class=\"dashwidget\">\n";
	$txt .= "<h3>$title</h3>\n";
	if($extra != '')
		$txt .= "<div class=\"extra\">$extra</div>\n";
	$txt .= "<div id=\"$id\"></div>\n";
	$txt .= "</div>\n";
	return $txt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addLineChart($id)
///
/// \param 
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function addLineChart($id, $title) {
	$txt  = "<div class=\"dashwidget\">\n";
	$txt .= "<h3>$title</h3>\n";
	$txt .= "<div dojoType=\"dojox.charting.widget.Chart2D\" id=\"$id\"\n";
	$txt .= "     theme=\"dojox.charting.themes.ThreeD\"\n";
	$txt .= "     style=\"width: 300px; height: 300px;\">\n";
	$txt .= "<div class=\"axis\"\n";
	$txt .= "     name=\"x\"\n";
	$txt .= "     labelFunc=\"timestampToTime\"\n";
	$txt .= "     maxLabelSize=\"35\"\n";
	$txt .= "     rotation=\"-90\"\n";
	$txt .= "     majorTickStep=\"4\"\n";
	$txt .= "     minorTickStep=\"1\">\n";
	$txt .= "     </div>\n";
	$txt .= "<div class=\"axis\" name=\"y\" vertical=\"true\" includeZero=\"true\"></div>\n";
	$txt .= "<div class=\"plot\" name=\"default\" type=\"Lines\" markers=\"true\"></div>\n";
	$txt .= "<div class=\"plot\" name=\"grid\" type=\"Grid\" vMajorLines=\"false\"></div>\n";
	$txt .= "<div class=\"series\" name=\"Main\" data=\"0\"></div>\n";
	$txt .= "<div class=\"action\" type=\"Tooltip\"></div>\n";
	$txt .= "<div class=\"action\" type=\"Magnify\"></div>\n";
	$txt .= "</div>\n";
	$txt .= "</div>\n";
	return $txt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStatusData()
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function getStatusData() {
	$data = array();
	$data[] = array('key' => 'Active Reservations', 'val' => 0);
	$data[] = array('key' => 'Online Computers', 'val' => 0, 'tooltip' => 'Computers in states available, reserved,<br>reloading, inuse, or timeout');
	$data[] = array('key' => 'Failed Computers', 'val' => 0);
	$reloadid = getUserlistID('vclreload@Local');
	$query = "SELECT COUNT(id) "
	       . "FROM request "
	       . "WHERE userid != $reloadid AND "
	       .       "stateid NOT IN (1, 5, 12) AND "
	       .       "start < NOW() AND "
			 .       "end > NOW()";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_row($qh))
		$data[0]['val'] = $row[0];

	$query = "SELECT COUNT(id) FROM computer WHERE stateid IN (2, 3, 6, 8, 11)";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_row($qh))
		$data[1]['val'] = $row[0];

	$query = "SELECT COUNT(id) FROM computer WHERE stateid = 5";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_row($qh))
		$data[2]['val'] = $row[0];
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn 
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function getTopImageData() {
	$query = "SELECT COUNT(c.currentimageid) AS count, "
	       .        "i.prettyname "
	       . "FROM computer c, "
	       .      "image i "
	       . "WHERE c.currentimageid = i.id AND "
			 .       "c.stateid = 8 "
	       . "GROUP BY c.currentimageid "
	       . "ORDER BY count DESC "
	       . "LIMIT 5";
	$query = "SELECT COUNT(rs.imageid) AS count, "
	       .        "i.prettyname "
	       . "FROM reservation rs, "
	       .      "request rq, "
	       .      "image i "
	       . "WHERE rs.imageid = i.id AND "
			 .       "rq.stateid = 8 AND "
			 .       "rs.requestid = rq.id AND "
			 .       "TIMESTAMPDIFF(HOUR, rq.start, rq.end) <= 24 "
	       . "GROUP BY rs.imageid "
	       . "ORDER BY count DESC "
	       . "LIMIT 5";
	$data = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$data[] = $row;
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn 
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function getTopLongImageData() {
	$query = "SELECT COUNT(rs.imageid) AS count, "
	       .        "i.prettyname, "
	       .        "TIMESTAMPDIFF(HOUR, rq.start, rq.end) AS reslen "
	       . "FROM reservation rs, "
	       .      "request rq, "
	       .      "image i "
	       . "WHERE rs.imageid = i.id AND "
			 .       "rq.stateid = 8 AND "
			 .       "rs.requestid = rq.id "
	       . "GROUP BY rs.imageid "
	       . "HAVING reslen > 24 "
	       . "ORDER BY count DESC "
	       . "LIMIT 5";
	$query = "SELECT COUNT(rs.imageid) AS count, "
	       .        "i.prettyname "
	       . "FROM reservation rs, "
	       .      "request rq, "
	       .      "image i "
	       . "WHERE rs.imageid = i.id AND "
			 .       "rq.stateid = 8 AND "
			 .       "rs.requestid = rq.id AND "
			 .       "TIMESTAMPDIFF(HOUR, rq.start, rq.end) > 24 "
	       . "GROUP BY rs.imageid "
	       . "ORDER BY count DESC "
	       . "LIMIT 5";
	$data = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$data[] = $row;
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getTopFailedData()
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function getTopFailedData() {
	$query = "SELECT COUNT(l.imageid) AS count, "
	       .        "i.prettyname "
	       . "FROM log l, "
	       .      "image i "
	       . "WHERE l.imageid = i.id AND "
	       .       "l.ending = 'failed' AND "
	       .       "l.start > DATE_SUB(NOW(), INTERVAL 5 DAY) "
	       . "GROUP BY l.imageid "
	       . "ORDER BY count DESC "
	       . "LIMIT 5";
	$data = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$data[] = $row;
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getTopFailedComputersData()
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function getTopFailedComputersData() {
	$query = "SELECT COUNT(s.computerid) AS count, "
	       .        "c.hostname "
	       . "FROM log l, "
	       .      "sublog s, "
	       .      "computer c "
	       . "WHERE s.logid = l.id AND "
	       .       "s.computerid = c.id AND "
	       .       "l.ending = 'failed' AND "
	       .       "l.start > DATE_SUB(NOW(), INTERVAL 5 DAY) "
	       . "GROUP BY s.computerid "
	       . "ORDER BY count DESC "
	       . "LIMIT 5";
	$data = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$data[] = $row;
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getActiveResChartData()
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function getActiveResChartData() {
	$data = array();
	$chartstart = unixFloor15(time() - (12 * 3600));
	$chartend = $chartstart + (12 * 3600) + 900;
	for($time = $chartstart, $i = 0; $time < $chartend; $time += 900, $i++) {
		$fmttime = date('g:i a', $time);
		$data["points"][$i] = array('x' => $i, 'y' => 0, 'value' => $i, 'text' => $fmttime);
	}
	$data['maxy'] = 0;
	$reloadid = getUserlistID('vclreload@Local');
	$query = "SELECT id, "
	       .        "UNIX_TIMESTAMP(start) AS start, "
	       .        "UNIX_TIMESTAMP(finalend) AS end "
	       . "FROM log "
	       . "WHERE start < NOW() AND "
	       .       "finalend > DATE_SUB(NOW(), INTERVAL 12 HOUR) AND "
	       .       "ending NOT IN ('failed', 'failedtest') AND "
	       .       "wasavailable = 1 AND "
	       .       "userid != $reloadid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		for($binstart = $chartstart, $binend = $chartstart + 900, $binindex = 0; 
		   $binend <= $chartend;
		   $binstart += 900, $binend += 900, $binindex++) {
			if($binend <= $row['start'])
				continue;
			elseif($row['start'] < $binend &&
				$row['end'] > $binstart) {
				$data["points"][$binindex]['y']++;
			}
			elseif($binstart >= $row['end'])
				break;
		}
	}
	for($time = $chartstart, $i = 0; $time < $chartend; $time += 900, $i++) {
		if($data["points"][$i]['y'] > $data['maxy'])
			$data['maxy'] = $data['points'][$i]['y'];
		$data["points"][$i]['tooltip'] = "{$data['points'][$i]['text']}: {$data['points'][$i]['y']}";
	}
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getBlockAllocationData()
///
/// \param 
///
/// \return
///
/// \brief 
///
////////////////////////////////////////////////////////////////////////////////
function getBlockAllocationData() {
	# active block allocation
	$query = "SELECT COUNT(id) "
	       . "FROM blockTimes "
	       . "WHERE skip = 0 AND "
	       .       "start < NOW() AND "
			 .       "end > NOW()";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_row($qh);
	$blockcount = $row[0];
	# computers in blockComputers for active allocations
	$query = "SELECT bc.computerid, "
	       .        "c.stateid "
	       . "FROM blockComputers bc "
	       . "LEFT JOIN computer c ON (c.id = bc.computerid) "
	       . "LEFT JOIN blockTimes bt ON (bt.id = bc.blockTimeid) "
	       . "WHERE c.stateid IN (2, 3, 6, 8, 19) AND "
	       .       "bt.start < NOW() AND "
	       .       "bt.end > NOW()";
	$qh = doQuery($query, 101);
	$total = 0;
	$used = 0;
	while($row = mysql_fetch_assoc($qh)) {
		$total++;
		if($row['stateid'] == 3 || $row['stateid'] == 8)
			$used++;
	}
	if($total)
		$compused = sprintf('%d / %d (%0.2f %%)', $used, $total, ($used / $total * 100));
	else
		$compused = 0;
	# number of computers that should be allocated
	$query = "SELECT br.numMachines "
	       . "FROM blockRequest br "
	       . "LEFT JOIN blockTimes bt ON (bt.blockRequestid = br.id) "
	       . "WHERE bt.start < NOW() AND "
	       .       "bt.end > NOW() AND "
	       .       "bt.skip = 0";
	$alloc = 0;
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$alloc += $row['numMachines'];
	if($alloc)
		$failed = sprintf('%d / %d (%0.2f %%)', ($alloc - $total), $alloc, (($alloc - $total) / $alloc * 100));
	else
		$failed = 0;
	$data = array();
	$data[] = array('title' => 'Active Block Allocations', 'val' => $blockcount);
	$data[] = array('title' => 'Block Computer Usage', 'val' => $compused);
	$data[] = array('title' => 'Failed Block Computers', 'val' => $failed);
	return $data;
}
?>
