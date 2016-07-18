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
/// \fn blockAllocations()
///
/// \brief prints a page with block allocation request form for normal users and
/// a page with current block allocations and pending allocations for admin
/// users
///
////////////////////////////////////////////////////////////////////////////////
function blockAllocations() {
	global $user;
	if(! checkUserHasPerm('Manage Block Allocations (global)') &&
	   ! checkUserHasPerm('Manage Block Allocations (affiliation only)')) {
		print "<H2>" . i("Block Allocations") . "</H2>\n";
		print i("Block Allocations are a way to have a set of machines preloaded with a particular environment at specified times and made available to a specific group of users. This is very useful for classroom use and for workshops. They can be made available on a repeating schedule such as when a course meets each week. Block Allocations only allocate machines for the group of users - they do not create the actual, end user reservations for the machines. All users still must log in to the VCL web site and make their own reservations DURING the period a block allocation is active. The forms here provide a way for you to submit a request for a Block Allocation for review by a sysadmin. If you just need to use a machine through VCL, use the New Reservation page for that.");
		print "<br><br>";
		print i("Please submit Block Allocation requests at least one full business day in advance to allow time for them to be approved.") . "<br><br>\n";
		print "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
		print i(  "Request New Block Allocation") . "\n";
		print "  <script type=\"dojo/method\" event=\"onClick\">\n";
		print "    location.href = '" . BASEURL . SCRIPT . "?mode=requestBlockAllocation';\n";
		print "  </script>\n";
		print "</button>\n";
		print getUserCurrentBlockHTML();
	}
	else {
		print "<h2>" . i("Manage Block Allocations") . "</h2>\n";
		$cont = addContinuationsEntry('viewBlockAllocatedMachines');
		print "<a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print i("View Block Allocated Machines") . "</a>\n";
		print "<div id=\"blocklist\">\n";
		print getCurrentBlockHTML();
		print "</div>\n";
		print "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
		print "  " . i("Create New Block Allocation") . "\n";
		print "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$cont = addContinuationsEntry('newBlockAllocation');
		print "    location.href = '" . BASEURL . SCRIPT . "?continuation=$cont';\n";
		print "  </script>\n";
		print "</button>\n";
		print "<h2>" . i("Block Allocation Requests") . "</h2>\n";
		print "<div id=\"pendinglist\">\n";
		print getPendingBlockHTML();
		print "</div>\n";
	}
	$blockids = getBlockAllocationIDs($user);
	if(! count($blockids))
		return;
	$inids = implode(',', $blockids);
	$query = "SELECT id, "
	       .        "name "
	       . "FROM blockRequest "
	       . "WHERE id in ($inids) AND "
	       .       "status = 'accepted'";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$blocks[$row['id']] = $row['name'];
	print "<hr>\n";
	print "<h2>" . i("Your Active Block Allocations") . "</h2>\n";
	print i("You are currently a member of the following Block Allocations.") . "<br>\n";
	print i("Click an item to view its current status.") . "<br>\n";
	foreach($blocks as $id => $name) {
		$cont = addContinuationsEntry('viewBlockStatus', array('id' => $id));
		print "<a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "$name</a><br>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn blockAllocationForm()
///
/// \brief prints a page for submitting a new block allocation, editing an
/// existing block allocation, or requesting a new block allocation
///
////////////////////////////////////////////////////////////////////////////////
function blockAllocationForm() {
	global $user, $days, $mode;
	$blockid = getContinuationVar('blockid', '');
	$data = getBlockAllocationData($blockid);
	if(array_key_exists('tzoffset', $_SESSION['persistdata']))
		$now = time() - ($_SESSION['persistdata']['tzoffset'] * 60);
	else
		$now = time();
	print "<input type=\"hidden\" id=\"nowtimestamp\" value=\"$now\">\n";
	print "<input type=\"hidden\" id=\"timezone\" value=\"" . date('T') . "\">\n";
	if($mode == 'newBlockAllocation') {
		$brname = '';
		$imageid = '';
		print "<h2>" . i("New Block Allocation") . "</h2>\n";
	}
	elseif($mode == 'editBlockAllocation') {
		print "<h2>" . i("Edit Block Allocation") . "</h2>\n";
	}
	elseif($mode == 'requestBlockAllocation') {
		print "<h2>" . i("Request New Block Allocation") . "</h2>\n";
		print i("Complete the following form to request a new block allocation. Your request will need to be approved by a VCL admin before it is created.");
		print "<br><br>\n";
	}
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);
	print "<table summary=\"\">\n";
	if($mode != 'requestBlockAllocation') {
		print "  <tr>\n";
		print "    <th align=right>" . i("Name:") . "</th>\n";
		print "    <td>\n";
		print "      <input type=\"text\" value=\"{$data['name']}\" dojoType=\"dijit.form.ValidationTextBox\" ";
		print "id=\"brname\" required=\"true\" invalidMessage=\"";
		print i("Name can only contain letters, numbers, spaces, dashes(-), parenthesis, and periods(.) and can be from 3 to 80 characters long");
		print "\" regExp=\"^([-a-zA-Z0-9\. \(\)]){3,80}$\" style=\"width: 300px\" ";
		print "postCreate=\"dijit.byId('brname').focus();\">\n";
		print "    </td>\n";
		print "  </tr>\n";
		print "  <tr>\n";
		print "    <th align=right>" . i("Owner:") . "</th>\n";
		print "    <td>\n";
		$initval = $data['owner'];
		if(empty($initval))
			$initval = "{$user['unityid']}@{$user['affiliation']}";
		print "      <input type=\"text\" value=\"$initval\" dojoType=\"dijit.form.ValidationTextBox\" ";
		print "id=\"browner\" required=\"true\" invalidMessage=\"" . i("Unknown user") . "\" style=\"width: 300px\" ";
		print "validator=\"checkOwner\" onFocus=\"ownerFocus\">\n";
		print "    </td>\n";
		print "  </tr>\n";
	}
	print "  <tr>\n";
	print "    <th align=right>" . i("Environment") . ":</th>\n";
	print "    <td>\n";
	if(USEFILTERINGSELECT && count($resources['image']) < FILTERINGSELECTTHRESHOLD) {
		print "      <select dojoType=\"dijit.form.FilteringSelect\" id=imagesel style=\"width: 300px\" ";
		print "queryExpr=\"*\${0}*\" highlightMatch=\"all\" autoComplete=\"false\" ";
		print "onChange=\"clearCont2();\">\n";
	}
	else
		print "      <select id=imagesel onChange=\"clearCont2();\">";
	foreach($resources['image'] as $id => $name) {
		if($id == $data['imageid'])
			print "        <option value=\"$id\" selected>$name</option>\n";
		else
			print "        <option value=\"$id\">$name</option>\n";
	}
	print "      </select>\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>" . i("User group") . ":</th>\n";
	print "    <td>\n";
	$groups = getUserGroups(0, $user['affiliationid']);
	if(USEFILTERINGSELECT && count($groups) < FILTERINGSELECTTHRESHOLD) {
		print "      <select dojoType=\"dijit.form.FilteringSelect\" id=groupsel style=\"width: 300px\" ";
		print "queryExpr=\"*\${0}*\" highlightMatch=\"all\" autoComplete=\"false\" ";
		print "onChange=\"clearCont2();\">\n";
	}
	else
		print "      <select id=groupsel onChange=\"clearCont2();\">";
	$extragroups = array();
	if($mode == 'requestBlockAllocation')
		print "        <option value=\"0\">(" . i("group not listed") . ")</option>\n";
	if(! empty($data['usergroupid']) && ! array_key_exists($data['usergroupid'], $groups)) {
		$groups[$data['usergroupid']] = array('name' => getUserGroupName($data['usergroupid'], 1));
		$extragroups[$data['usergroupid']] = array('name' => getUserGroupName($data['usergroupid'], 1));
		uasort($groups, "sortKeepIndex");
	}
	foreach($groups as $id => $group) {
		if($group['name'] == ' None@')
			continue;
		if($id == $data['usergroupid'])
			print "        <option value=\"$id\" selected>{$group['name']}</option>\n";
		else
			print "        <option value=\"$id\">{$group['name']}</option>\n";
	}
	print "      </select>\n";
	print "      <img src=\"images/helpicon.png\" id=\"grouphelp\" />\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>" . i("Number of seats") . ":</th>\n";
	print "    <td>\n";
	print "      <input dojoType=\"dijit.form.NumberSpinner\" value=\"{$data['seats']}\" ";
	print "smallDelta=1 largeDelta=5 constraints=\"{min:" . MIN_BLOCK_MACHINES . ", max:";
	print MAX_BLOCK_MACHINES . "}\" id=machinecnt required=\"true\" style=\"width: 70px\" filter=\"machinecntfilter\"/>\n";
	print "      <img src=\"images/helpicon.png\" id=\"seathelp\" />\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "</table>\n";

	print i("Specify dates/times by:\n");
	print "<img src=\"images/helpicon.png\" id=\"repeattypehelp\" /><br>\n";
	print "<input type=\"radio\" name=\"datetime\" id=\"weeklyradio\" onClick=\"blockFormChangeTab('weekly');\" {$data['type']['weekly']} />\n";
	print "<label for=\"weeklyradio\">" . i("Repeating Weekly") . "</label><br>\n";
	print "<input type=\"radio\" name=\"datetime\" id=\"monthlyradio\" onClick=\"blockFormChangeTab('monthly');\" {$data['type']['monthly']} />\n";
	print "<label for=\"monthlyradio\">" . i("Repeating Monthly") . "</label><br>\n";
	print "<input type=\"radio\" name=\"datetime\" id=\"listradio\" onClick=\"blockFormChangeTab('list');\" {$data['type']['list']} />\n";
	print "<label for=\"listradio\">" . i("List of Dates/Times") . "</label><br><br>\n";

	print "<div style=\"border: 1px solid; margin-right: 8px;\">\n";
	print "<div id=\"timeTypeContainer\" dojoType=\"dijit.layout.StackContainer\"\n";
	print "     style=\"width:550px; height:240px; margin: 5px;\">\n";

	# repeating weekly
	print "<div id=\"weeklytab\" dojoType=\"dijit.layout.ContentPane\" ";
	print "title=\"" . i("Repeating Weekly") . "\" {$data['type2']['weekly']}>\n";
	print "<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <th align=right>" . i("First Date of Usage") . ":</th>\n";
	print "    <td>\n";
	print "      <input type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
	print "required=\"true\" id=\"wkfirstdate\" value=\"{$data['swdate']}\" />\n";
	print "    <small>(" . date('T') . ")</small>\n";
	print "    <img src=\"images/helpicon.png\" id=\"wkfdhelp\" />\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>" . i("Last Date of Usage") . ":</th>\n";
	print "    <td>\n";
	print "      <input type=\"text\" dojoType=\"dijit.form.DateTextBox\" ";
	print "required=\"true\" id=\"wklastdate\" value=\"{$data['ewdate']}\" />\n";
	print "    <small>(" . date('T') . ")</small>\n";
	print "    <img src=\"images/helpicon.png\" id=\"wkldhelp\" />\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "</table>\n";
	print "<table summary=\"\">\n";
	print "<tr>\n";
	print "<th>" . i("Days") . " <img src=\"images/helpicon.png\" id=\"wkdayshelp\" /></th>\n";
	print "<th>" . i("Times") . " <img src=\"images/helpicon.png\" id=\"wktimeshelp\" /></th>\n";
	print "</tr>\n";
	print "<tr>\n";
	print "<td valign=top>\n";
	foreach($days as $id => $day) {
		print "  <INPUT type=checkbox id=\"wdays$id\" value=\"$day\" {$data['wdayschecked'][$day]}>\n";
		print "  <label for=\"wdays$day\">" . i($day) . "</label><br>\n";
	}
	print "</td>\n";
	print "<td>\n";

	print i("Start") . ":<div type=\"text\" id=\"weeklyaddstart\" dojoType=\"dijit.form.TimeTextBox\" ";
	print "required=\"true\" onChange=\"blockFormWeeklyAddBtnCheck(1);\" style=\"width: 78px\"></div>\n";
	print "<small>(" . date('T') . ")</small>\n";
	print "&nbsp;|&nbsp;&nbsp;";
	print i("End") . ":<div type=\"text\" id=\"weeklyaddend\" dojoType=\"vcldojo.TimeTextBoxEnd\" ";
	print "required=\"true\" onChange=\"blockFormWeeklyAddBtnCheck(0);\" startid=\"weeklyaddstart\" ";
	print "style=\"width: 78px\"></div>\n";
	print "<small>(" . date('T') . ")</small>\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\" disabled=\"true\" ";
	print "id=\"requestBlockWeeklyAddBtn\">\n";
	print i("Add") . "\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    blockFormAddWeeklyTime();\n";
	print "  </script>\n";
	print "</button>\n";
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"requestBlockAddWeeklyStore\" ";
	print "data=\"blockFormAddWeeklyData\"></div>\n";
	print "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"requestBlockAddWeeklyGrid\" sortInfo=1 ";
	print "store=\"requestBlockAddWeeklyStore\" style=\"width: 330px; height: 120px;\">\n";
	print "<thead>\n";
	print "<tr>\n";
	print "<th field=\"start\" width=\"102px\" formatter=\"gridTimePrimary\">";
	print i("Start") . "</th>\n";
	print "<th field=\"end\" width=\"102px\" formatter=\"timeFromTextBox\">";
	print i("End") . "</th>\n";
	print "<th field=\"remove\" width=\"80px\">" . i("Remove") . "</th>\n";
	print "</tr>\n";
	print "</thead>\n";
	print "</table>\n";

	print "</td>\n";
	print "</tr>\n";
	print "</table>\n";
	print "</div>\n"; # repeating weekly

	# repeating monthly
	print "<div id=\"monthlytab\" dojoType=\"dijit.layout.ContentPane\" ";
	print "title=\"" . i("Repeating Monthly") . "\" {$data['type2']['monthly']}>\n";
	print "<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <th align=right>" . i("First Date of Usage") . ":</th>\n";
	print "    <td>\n";
	print "      <input type=\"text\" id=\"mnfirstdate\" dojoType=\"dijit.form.DateTextBox\" ";
	print "required=\"true\" value=\"{$data['smdate']}\"/>\n";
	print "    <small>(" . date('T') . ")</small>\n";
	print "    <img src=\"images/helpicon.png\" id=\"mnfdhelp\" />\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>" . i("Last Date of Usage") . ":</th>\n";
	print "    <td>\n";
	print "      <input type=\"text\" id=\"mnlastdate\" dojoType=\"dijit.form.DateTextBox\" ";
	print "required=\"true\" value=\"{$data['emdate']}\" />\n";
	print "    <small>(" . date('T') . ")</small>\n";
	print "    <img src=\"images/helpicon.png\" id=\"mnldhelp\" />\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "</table>\n";
	$weeknumArr = array(1 => i("1st"),
	                    2 => i("2nd"),
	                    3 => i("3rd"),
	                    4 => i("4th"),
	                    5 => i("5th"));
	$dayArr = array(1 => i("Sunday"),
	                2 => i("Monday"),
	                3 => i("Tuesday"),
	                4 => i("Wednesday"),
	                5 => i("Thursday"),
	                6 => i("Friday"),
	                7 => i("Saturday"));
	print i("Repeat on the") . " ";
	printSelectInput('weeknum', $weeknumArr, $data['mnweeknumid'], 0, 0, 'mnweeknum');
	printSelectInput('day', $dayArr, $data['mndayid'], 0, 0, 'mnday');
	print " " . i("of every month") . "<br><br>\n";
	print i("Start") . ":<div type=\"text\" id=\"monthlyaddstart\" dojoType=\"dijit.form.TimeTextBox\" ";
	print "required=\"true\" onChange=\"blockFormMonthlyAddBtnCheck(1)\" style=\"width: 78px\"></div>\n";
	print "<small>(" . date('T') . ")</small>\n";
	print "&nbsp;|&nbsp;&nbsp;";
	print i("End") . ":<div type=\"text\" id=\"monthlyaddend\" dojoType=\"vcldojo.TimeTextBoxEnd\" ";
	print "required=\"true\" onChange=\"blockFormMonthlyAddBtnCheck(0)\" startid=\"monthlyaddstart\" ";
	print "style=\"width: 78px\"></div>\n";
	print "<small>(" . date('T') . ")</small>\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\" disabled=\"true\" ";
	print "id=\"requestBlockMonthlyAddBtn\">\n";
	print i("Add") . "\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    blockFormAddMonthlyTime();\n";
	print "  </script>\n";
	print "</button>\n";
	print "<img src=\"images/helpicon.png\" id=\"mntimeshelp\" />\n";
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"requestBlockAddMonthlyStore\" ";
	print "data=\"blockFormAddMonthlyData\"></div>\n";
	print "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"requestBlockAddMonthlyGrid\" sortInfo=1 ";
	print "store=\"requestBlockAddMonthlyStore\" style=\"width: 330px; height: 120px;\">\n";
	print "<thead>\n";
	print "<tr>\n";
	print "<th field=\"start\" width=\"102px\" formatter=\"gridTimePrimary\">";
	print i("Start") . "</th>\n";
	print "<th field=\"end\" width=\"102px\" formatter=\"timeFromTextBox\">";
	print i("End") . "</th>\n";
	print "<th field=\"remove\" width=\"80px\">" . i("Remove") . "</th>\n";
	print "</tr>\n";
	print "</thead>\n";
	print "</table>\n";
	print "</div>\n"; # repeating monthly

	# list of times
	print "<div id=\"listtab\" dojoType=\"dijit.layout.ContentPane\" ";
	print "title=\"" . i("List of Times") . "\" {$data['type2']['list']}>\n";
	print i("Date") . ":<div type=\"text\" id=\"listadddate\" dojoType=\"dijit.form.DateTextBox\" ";
	print "required=\"true\" onChange=\"blockFormListAddBtnCheck\" style=\"width: 95px\"></div>\n";
	print "<small>(" . date('T') . ")</small>\n";
	print "&nbsp;|&nbsp;&nbsp;";
	print i("Start") . ":<input type=\"text\" id=\"listaddstart\" dojoType=\"dijit.form.TimeTextBox\" ";
	print "required=\"true\" onChange=\"blockFormListAddBtnCheck\" />\n";
	print "<small>(" . date('T') . ")</small>\n";
	print "&nbsp;|&nbsp;&nbsp;";
	print i("End") . ":<input type=\"text\" id=\"listaddend\" dojoType=\"vcldojo.TimeTextBoxEnd\" ";
	print "required=\"true\" onChange=\"blockFormListAddBtnCheck\" startid=\"listaddstart\" />\n";
	print "<small>(" . date('T') . ")</small>\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\" disabled=\"true\" ";
	print "id=\"requestBlockListAddBtn\">\n";
	print i("Add") . "\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    blockFormAddListSlot();\n";
	print "  </script>\n";
	print "</button>\n";
	print "<img src=\"images/helpicon.png\" id=\"listhelp\" />\n";
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"requestBlockAddListStore\" ";
	print "data=\"blockFormAddListData\"></div>\n";
	print "<div>\n"; # grid wrapper
	print "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"requestBlockAddListGrid\" sortInfo=1 ";
	print "store=\"requestBlockAddListStore\" style=\"width: 465px; height: 200px;\">\n";
	print "<thead>\n";
	print "<tr>\n";
	print "<th field=\"date1\" width=\"115px\" formatter=\"gridDateTimePrimary\">";
	print i("Date") . "</th>\n";
	print "<th field=\"start\" width=\"115px\" formatter=\"timeFromTextBox\">";
	print i("Start") . "</th>\n";
	print "<th field=\"end\" width=\"108px\" formatter=\"timeFromTextBox\">";
	print i("End") . "</th>\n";
	print "<th field=\"remove\" width=\"80px\">" . i("Remove") . "</th>\n";
	print "</tr>\n";
	print "</thead>\n";
	print "</table>\n";
	print "</div>\n"; # grid wrapper
	print "</div>\n"; # list of times

	print "</div>\n"; # tabcontainer
	print "</div><br>\n";

	if($mode == 'requestBlockAllocation') {
		print "<strong><big>" . i("Additional comments") . ":</big></strong>\n";
		print "<img src=\"images/helpicon.png\" id=\"commenthelp\" /><br>\n";
		print "<textarea id=\"comments\" dojoType=\"dijit.form.Textarea\" style=\"width: 400px;\">\n";
		print "</textarea><br><br>\n";
	}

	print "<button dojoType=\"dijit.form.Button\" type=\"button\" ";
	print "id=\"requestBlockSubmitBtn\">\n";
	if($mode == 'requestBlockAllocation') {
		$btntxt = i("Submit Block Allocation Request") . "\n";
		$arg = 'request';
	}
	elseif($mode == 'newBlockAllocation') {
		$btntxt = i("Submit New Block Allocation") . "\n";
		$arg = 'new';
	}
	elseif($mode == 'editBlockAllocation') {
		$btntxt = i("Submit Block Allocation Changes") . "\n";
		$arg = 'edit';
	}
	print "  $btntxt\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    blockFormConfirm('$arg');\n";
	print "  </script>\n";
	print "</button>\n";
	$cont = addContinuationsEntry('AJvalidateUserid');
	print "<input type=\"hidden\" id=\"valuseridcont\" value=\"$cont\">\n";

	print "<div id=\"confirmDialog\" dojoType=\"dijit.Dialog\" title=\"";
	print i("Confirm Block Allocation") . "\">\n";
	print "<h2>" . i("Confirm Block Allocation") . "</h2>\n";
	if($mode == 'requestBlockAllocation')
		print i("Please confirm the following values and then click <strong>Submit Block Allocation Request</strong>");
	else {
		printf(i("Please confirm the following values and then click <strong>%s</strong>"), $btntxt);
	}
	print "<br><br>\n<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <th align=\"right\"><span id=\"confnametitle\"></span></th>\n";
	print "    <td><span id=\"confname\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\"><span id=\"confownertitle\"></span></th>\n";
	print "    <td><span id=\"confowner\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\">" . i("Environment") . ":</th>\n";
	print "    <td><span id=\"confimage\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\">" . i("User group") . ":</th>\n";
	print "    <td><span id=\"confgroup\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\">" . i("Seats") . ":</th>\n";
	print "    <td><span id=\"confseats\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=\"right\">" . i("Repeating") . ":</th>\n";
	print "    <td><span id=\"confrepeat\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr valign=\"top\">\n";
	print "    <th align=\"right\"><span id=\"conftitle1\"></span></th>\n";
	print "    <td><span id=\"confvalue1\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr valign=\"top\">\n";
	print "    <th align=\"right\"><span id=\"conftitle2\"></span></th>\n";
	print "    <td><span id=\"confvalue2\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr valign=\"top\">\n";
	print "    <th align=\"right\"><span id=\"conftitle3\"></span></th>\n";
	print "    <td><span id=\"confvalue3\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr valign=\"top\">\n";
	print "    <th align=\"right\"><span id=\"conftitle4\"></span></th>\n";
	print "    <td><span id=\"confvalue4\"></span></td>\n";
	print "  </tr>\n";
	print "</table>\n";
	print "<span id=\"commentsnote\" class=\"hidden\">" . i("Your additional comments will be submitted.") . "<br><br></span>\n";
	$data = array('extragroups' => $extragroups);
	if($mode == 'newBlockAllocation')
		$data['method'] = 'new';
	elseif($mode == 'editBlockAllocation') {
		$data['method'] = 'edit';
		$data['blockid'] = $blockid;
	}
	elseif($mode == 'requestBlockAllocation')
		$data['method'] = 'request';
	$cont = addContinuationsEntry('AJblockAllocationSubmit', $data, SECINWEEK, 1, 0);
	print "<input type=\"hidden\" id=\"submitcont\" value=\"$cont\">\n";
	print "<input type=\"hidden\" id=\"submitcont2\">\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	print "  $btntxt\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    blockFormSubmit('$arg');\n";
	print "  </script>\n";
	print "</button>\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	print i("Cancel") . "\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    clearHideConfirmForm();\n";
	print "  </script>\n";
	print "</button>\n";
	print "</div>\n"; # confirm dialog

	# tooltips
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"seathelp\">\n";
	print "<div style=\"width: 440px;\">\n";
	print i("This is the number of environments that will be loaded for the Block Allocation.");
	print "</div></div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"grouphelp\">\n";
	print "<div style=\"width: 440px;\">\n";
	print i("Users in this user group will be able to make reservations for the computers set aside for this block allocation.  If you do not see an applicable user group listed, please select \"<font color=\"blue\">(group not listed)</font>\" and describe the group you need in the <strong>Additional Comments</strong> section at the bottom of the page. If this is for a class, make sure to list the course and section number.");
	print "</div></div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"repeattypehelp\">\n";
	print "<div style=\"width: 440px;\">\n";
	print i("For repeating block allocations, there are three ways you can enter the dates and times:") . "<br>\n";
	print "<ul>\n";
	print "<li>" . i("Repeating Weekly - Use this if the block allocation needs to occur every week.") . " ";
	print i("You can make it repeat on a single day each week or on multiple days.  The time(s) that it occurs will be the same on all days. You can list as many times as needed.") . "</li>\n";
	print "<li>" . i("Repeating Monthly - Use this if the block allocation needs to occur on a certain day of the month (i.e. 2nd Tuesday each month). You can list as many times as needed for that day of the month.") . "</li>\n";
	print "<li>" . i("List of Dates/Times - Use this to specify any other cases, including single events.") . " ";
	print i("You can specify as many date/time combinations as needed.") . "</li>\n";
	print "</ul>\n";
	print "</div></div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"wkfdhelp\">\n";
	print i("This is the first date the block allocation will be used.\n");
	print "</div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"wkldhelp\">\n";
	print i("This is the last date the block allocation will be used.\n");
	print "</div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"wkdayshelp\">\n";
	print "<div style=\"width: 340px;\">\n";
	print i("Select the checkbox for each of the days you would like the block allocation to occur. For example, check Monday, Wednesday, and Friday for a class that meets on those days.");
	print "</div></div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"wktimeshelp\">\n";
	print "<div style=\"width: 340px;\">\n";
	print i("Here you specify the start and end times of the block allocation. The times will occur on each of the selected days. You might specify more than one start/end combination if you had multiple sections that met on the same day.");
	print "</div></div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"mnfdhelp\">\n";
	print i("This is the first date the block allocation will be used.\n");
	print "</div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"mnldhelp\">\n";
	print i("This is the last date the block allocation will be used.\n");
	print "</div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"mntimeshelp\">\n";
	print "<div style=\"width: 340px;\">\n";
	print i("Here you specify the start and end times of the block allocation. You might specify more than one start/end combination if you had multiple sections that met on the same day.");
	print "</div></div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"listhelp\">\n";
	print "<div style=\"width: 300px;\">\n";
	print i("Specify individual dates and times during which the block allocation will occur.");
	print "</div></div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"commenthelp\">\n";
	print "<div style=\"width: 340px;\">\n";
	print i("Enter any additional information about this block allocation. &lt; and &gt; are not allowed. If you selected \"<font color=\"blue\">(group not listed)</font>\" as the User group, make sure to clearly describe the requirements of a new user group that will be created for this block allocation.");
	print "</div></div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJblockAllocationSubmit()
///
/// \brief ajax function to process the form displayed by blockAllocationForm
///
////////////////////////////////////////////////////////////////////////////////
function AJblockAllocationSubmit() {
	global $user;
	$data = processBlockAllocationInput();
	if($data['err'])
		return;
	$method = getContinuationVar('method');

	if($method == 'new') {
		$managementnodes = getManagementNodes('future');
		if(empty($managementnodes)) {
			print "alert('" . i("Error encountered while trying to create block allocation:") . "\\n";
			print i("No active management nodes were found. Please try creating the block allocation at a later time.") . "');";
			$data = array('extragroups' => getContinuationVar('extragroups'),
			              'method' => $method);
			if($method == 'edit')
				$data['blockid'] = getContinuationVar('blockid');
			$cont = addContinuationsEntry('AJblockAllocationSubmit', $data, SECINWEEK, 1, 0);
			print "dojo.byId('submitcont').value = '$cont';";
			return;
		}
		$mnid = array_rand($managementnodes);
		$escname = mysql_real_escape_string($data['name']);
		$query = "INSERT INTO blockRequest "
		       .        "(name, "
		       .        "imageid, "
		       .        "numMachines, "
		       .        "groupid, "
		       .        "repeating, "
		       .        "ownerid, "
		       .        "managementnodeid, "
		       .        "expireTime, "
		       .        "status) "
		       . "VALUES "
		       .        "('$escname', "
		       .        "{$data['imageid']}, "
		       .        "{$data['seats']}, "
		       .        "{$data['groupid']}, "
		       .        "'{$data['type']}', "
		       .        "{$data['ownerid']}, "
		       .        "$mnid, "
		       .        "'{$data['expiretime']}', "
		       .        "'accepted')";
		doQuery($query, 101);
		$blockreqid = dbLastInsertID();
	}
	elseif($method == 'edit') {
		$blockreqid = getContinuationVar('blockid');
		# FIXME need to handle creation of a block time that we're currently in the
		#    middle of if there wasn't already one we're in the middle of
		# get blockTime entry for this allocation if we're in the middle of one
		$checkCurBlockTime = 0;
		$query = "SELECT id, "
		       .        "start, "
		       .        "end "
		       . "FROM blockTimes "
		       . "WHERE start <= NOW() AND "
		       .       "end > NOW() AND "
		       .       "blockRequestid = $blockreqid";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh)) {
			$checkCurBlockTime = 1;
			$curBlockTime = $row;
		}
		# delete entries from blockTimes that start later than now
		$query = "DELETE FROM blockTimes "
		       . "WHERE blockRequestid = $blockreqid AND "
		       .       "start > NOW() AND "
		       .       "skip = 0";
		doQuery($query, 101);
		# delete entries from blockWebDate and blockWebTime
		$query = "DELETE FROM blockWebDate WHERE blockRequestid = $blockreqid";
		doQuery($query, 101);
		$query = "DELETE FROM blockWebTime WHERE blockRequestid = $blockreqid";
		doQuery($query, 101);

		$escname = mysql_real_escape_string($data['name']);
		$query = "UPDATE blockRequest "
		       . "SET name = '$escname', " 
		       .     "imageid = {$data['imageid']}, "
		       .     "numMachines = {$data['seats']}, "
		       .     "groupid = {$data['groupid']}, "
		       .     "ownerid = {$data['ownerid']}, "
		       .     "repeating = '{$data['type']}', "
		       .     "expireTime = '{$data['expiretime']}' "
		       . "WHERE  id = $blockreqid";
		doQuery($query, 101);
	}
	elseif($method == 'request') {
		$esccomments = mysql_real_escape_string($data['comments']);
		$query = "INSERT INTO blockRequest "
		       .        "(name, "
		       .        "imageid, "
		       .        "numMachines, "
		       .        "groupid, "
		       .        "repeating, "
		       .        "ownerid, "
		       .        "expireTime, "
		       .        "status, "
		       .        "comments) "
		       . "VALUES "
		       .        "('(" . i("awaiting approval") . ")', "
		       .        "{$data['imageid']}, "
		       .        "{$data['seats']}, "
		       .        "{$data['groupid']}, "
		       .        "'{$data['type']}', "
		       .        "{$user['id']}, "
		       .        "'{$data['expiretime']}', "
		       .        "'requested', "
		       .        "'$esccomments')";
		doQuery($query, 101);
		$blockreqid = dbLastInsertID();

		# send email notifying about a new block allocation request
		$imagedata = getImages(0, $data['imageid']);
		if($data['groupid'] == 0)
			$grpname = "(Unspecified)";
		else
			$grpname = getUserGroupName($data['groupid']);
		if(! empty($data['comments']))
			$comments = "Comments:\n{$data['comments']}\n";
		else
			$comments = '';
		$message = "A new block allocation request has been submitted by ";
		if(! empty($user['firstname']) && ! empty($user['lastname']) && ! empty($user['email']))
			$message .= "{$user['firstname']} {$user['lastname']} ({$user['email']}). ";
		elseif(! empty($user['email']))
			$message .= "{$user['email']}. ";
		else
			$message .= "{$user['unityid']}. ";
		$message .= "Please visit the following URL to accept or reject it:\n\n"
		         .  BASEURL . SCRIPT . "?mode=blockAllocations\n\n"
		         .  "Image: {$imagedata[$data['imageid']]['prettyname']}\n"
		         .  "Seats: {$data['seats']}\n"
		         .  "User Group: $grpname\n$comments\n\n"
		         .  "This is an automated message sent by VCL.\n"
		         .  "You are receiving this message because you have access "
		         .  "to create and approve block allocations.";
		$mailParams = "-f" . ENVELOPESENDER;
		$blockNotifyUsers = getBlockNotifyUsers($user['affiliationid']);
		mail($blockNotifyUsers, "VCL Block Allocation Request ({$user['unityid']})", $message, '', $mailParams);
	}

	if($data['type'] == 'weekly') {
		$query = "INSERT INTO blockWebDate "
		       .        "(blockRequestid, "
		       .        "start, "
		       .        "end, "
		       .        "days) "
		       . "VALUES "
		       .        "($blockreqid, "
		       .        "'{$data['startdate']}', "
		       .        "'{$data['enddate']}', "
		       .        "{$data['daymask']})";
		doQuery($query, 101);
		$today = mktime(0, 0, 0);
		if($method == 'edit' && $data['startts'] < $today)
			createWeeklyBlockTimes($blockreqid, $today, $data['endts'], $data['daymask'], $data['times']);
		elseif($method == 'new' || $method == 'edit')
			createWeeklyBlockTimes($blockreqid, $data['startts'], $data['endts'], $data['daymask'], $data['times']);
	}
	elseif($data['type'] == 'monthly') {
		$query = "INSERT INTO blockWebDate "
		       .        "(blockRequestid, "
		       .        "start, "
		       .        "end, "
		       .        "days, "
		       .        "weeknum) "
		       . "VALUES "
		       .        "($blockreqid, "
		       .        "'{$data['startdate']}', "
		       .        "'{$data['enddate']}', "
		       .        "{$data['day']}, "
		       .        "{$data['weeknum']})";
		doQuery($query, 101);
		$today = mktime(0, 0, 0);
		if($method == 'edit' && $data['startts'] < $today)
			createMonthlyBlockTimes($blockreqid, $today, $data['endts'], $data['day'], $data['weeknum'], $data['times']);
		elseif($method == 'new' || $method == 'edit')
			createMonthlyBlockTimes($blockreqid, $data['startts'], $data['endts'], $data['day'], $data['weeknum'], $data['times']);
	}
	if($data['type'] == 'weekly' || $data['type'] == 'monthly') {
		$vals = array();
		$i = 0;
		foreach($data['times'] as $time) {
			$tmp = explode('|', $time);
			$start = explode(':', $tmp[0]);
			$startmin = $start[1];
			list($starth, $startm) = hour24to12($start[0]);
			$end = explode(':', $tmp[1]);
			$endmin = $end[1];
			list($endh, $endm) = hour24to12($end[0]);
			$vals[] = "($blockreqid, "
			        . "'$starth', "
			        . "'$startmin', "
			        . "'$startm', "
			        . "'$endh', "
			        . "'$endmin', "
			        . "'$endm', "
			        . "$i)";
			$i++;
		}
		$allvals = implode(',', $vals);
		$query = "INSERT INTO blockWebTime "
		       .        "(blockRequestid, "
		       .        "starthour, "
		       .        "startminute, "
		       .        "startmeridian, "
		       .        "endhour, "
		       .        "endminute, "
		       .        "endmeridian, "
		       .        "`order`) "
		       . "VALUES $allvals";
		doQuery($query, 101);
	}
	if($data['type'] == 'list')
		createListBlockData($blockreqid, $data['slots'], $method);
	if($method == 'edit' && $checkCurBlockTime) {
		$query = "SELECT id, "
		       .        "start, "
		       .        "end "
		       . "FROM blockTimes "
		       . "WHERE start <= NOW() AND "
		       .       "end > NOW() AND "
		       .       "blockRequestid = $blockreqid AND "
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
	if($method == 'request') {
		print "clearHideConfirmForm();";
		$txt  = "<h2>" . i("Request New Block Allocation") . "</h2>";
		$txt .= i("Your request for a Block Allocation has been submitted for approval.") . " ";
		if(! empty($user['email'])) {
			$txt .= i("You should be notified within a few business days of its acceptance or rejection.");
		}
		else {
			$txt .= "<br><br><font color=\"red\"><strong>" . i("Note:") . "</strong> ";
			$h = "      " . i("You do not have an email address registered with VCL. Therefore, you will not receive automatic notification when this block allocation is accepted or rejected.");
			$txt .= preg_replace("/(.{1,50}([ \n]|$))/", '\1<br>', $h) . "</font>";
		}
		print "dojo.byId('content').innerHTML = '$txt';";
		print "scroll(0, 0);";
		return;
	}
	print "window.location.href = '" . BASEURL . SCRIPT . "?mode=blockAllocations';";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn createWeeklyBlockTimes($blockid, $startts, $endts, $daymask, $times)
///
/// \param $blockid - id of block allocation
/// \param $startts - unix timestamp for starting time
/// \param $endts - unix timestamp for ending time
/// \param $daymask - bitmask int of selected days
/// \param $times - array of times in HH:MM|HH:MM (start|end) format
///
/// \brief creates entries in the blockTimes table for a weekly repeating block
/// allocation
///
////////////////////////////////////////////////////////////////////////////////
function createWeeklyBlockTimes($blockid, $startts, $endts, $daymask, $times) {
	$vals = array();
	$startts += 3600; # This is a simple way to deal with DST; without it. We end
	                  # up starting at midnight.  When we go through the day DST
	                  # ends, += SECINDAY only gets us to 11pm instead of the
	                  # next day. Adding an hour to start with starts us at 1am
	                  # and += SECINDAY gets us to midnight the next day.
	$endts += 7200;   # Conversely, we pass $endts too soon when DST starts; so
	                  # we add 2 hours to it to make sure we don't pass it.
	for($day = $startts; $day <= $endts; $day += SECINDAY) {
		if(! ((1 << date('w', $day)) & $daymask))
			continue;
		foreach($times as $time) {
			$tmp = explode('|', $time);
			$start = date("Y-m-d", $day) . " {$tmp[0]}:00";
			$end = date("Y-m-d", $day) . " {$tmp[1]}:00";
			$vals[] = "($blockid, "
			        . "'$start', "
			        . "'$end')";
		}
	}
	$allvals = implode(',', $vals);
	$query = "INSERT INTO blockTimes "
	       .        "(blockRequestid, "
	       .        "start, "
	       .        "end) "
	       . "VALUES $allvals";
	doQuery($query, 101);
	deleteBlockSkipDuplicates($blockid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn createMonthlyBlockTimes($blockid, $startts, $endts, $dayweek, $weeknum,
///                             $times)
///
/// \param $blockid - id of block allocation
/// \param $startts - unix timestamp for starting time
/// \param $endts - unix timestamp for ending time
/// \param $dayweek - day of the week (1 to 7)
/// \param $weeknum - week of the month (1 to 5)
/// \param $times - array of times in HH:MM|HH:MM (start|end) format
///
/// \brief creates entries in the blockTimes table for a monthly repeating block
/// allocation
///
////////////////////////////////////////////////////////////////////////////////
function createMonthlyBlockTimes($blockid, $startts, $endts, $dayweek, $weeknum,
                                 $times) {
	$vals = getMonthlyBlockTimes($blockid, $startts, $endts, $dayweek, $weeknum,
	                             $times);
	$allvals = implode(',', $vals);
	$query = "INSERT INTO blockTimes "
			 .        "(blockRequestid, "
			 .        "start, "
			 .        "end) "
			 . "VALUES $allvals";
	doQuery($query, 101);
	deleteBlockSkipDuplicates($blockid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMonthlyBlockTimes($blockid, $startts, $endts, $dayweek, $weeknum,
///                          $times)
///
/// \param $blockid - id of block allocation
/// \param $startts - unix timestamp for starting time
/// \param $endts - unix timestamp for ending time
/// \param $dayweek - day of the week (1 to 7)
/// \param $weeknum - week of the month (1 to 5)
/// \param $times - array of times in HH:MM|HH:MM (start|end) format
///
/// \brief generates query values for creating entries in the blockTimes table
/// for a monthly repeating block allocation
///
////////////////////////////////////////////////////////////////////////////////
function getMonthlyBlockTimes($blockid, $startts, $endts, $dayweek, $weeknum,
                              $times) {
	$vals = array();
	$startts += 3600; # This is a simple way to deal with DST; without it. We end
	                  # up starting at midnight.  When we go through the day DST
	                  # ends, += SECINDAY only gets us to 11pm instead of the
	                  # next day. Adding an hour to start with starts us at 1am
	                  # and += SECINDAY gets us to midnight the next day.
	$endts += 7200;   # Conversely, we pass $endts too soon when DST starts; so
	                  # we add 2 hours to it to make sure we don't pass it.
	for($day = $startts; $day <= $endts; $day += SECINDAY) {
		if((date('w', $day) + 1) != $dayweek)
			continue;
		$dayofmon = date('j', $day);
		if(($weeknum == 1 && ($dayofmon < 8)) ||
			($weeknum == 2 && (7 < $dayofmon) && ($dayofmon < 15)) ||
			($weeknum == 3 && (14 < $dayofmon) && ($dayofmon < 22)) ||
			($weeknum == 4 && (21 < $dayofmon) && ($dayofmon < 29)) ||
			($weeknum == 5 && (28 < $dayofmon) && ($dayofmon < 32))) {
			$thedate = date("Y-m-d", $day);
			foreach($times as $time) {
				$tmp = explode('|', $time);
				$start = "$thedate {$tmp[0]}:00";
				$end = "$thedate {$tmp[1]}:00";
				$vals[] = "($blockid, "
				        . "'$start', "
				        . "'$end')";
			}
		}
	}
	return $vals;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn createListBlockData($blockid, $slots, $method)
///
/// \param $blockid - id of block allocation
/// \param $slots - array of date/time slots in 'YYYY-MM-DD|HH:MM|HH:MM' format
/// (date|start|end)
/// \param $method - new, edit, or accept
///
/// \brief creates entries in the blockTimes table for a list type block
/// allocation
///
////////////////////////////////////////////////////////////////////////////////
function createListBlockData($blockid, $slots, $method) {
	$dvals = array();
	$tvals = array();
	if($method == 'new' || $method == 'edit')
		$btvals = array();
	$i = 0;
	foreach($slots as $slot) {
		$tmp = explode('|', $slot);
		$date = $tmp[0];
		if($method == 'new' || $method == 'edit' || $method == 'accept') {
			$sdatets = strtotime("$date {$tmp[1]}:00");
			$sdatedt = unixToDatetime($sdatets);
			$edatets = strtotime("$date {$tmp[2]}:00");
			$edatedt = unixToDatetime($edatets);
			if($method != 'edit' || $edatets >= time()) {
				$btvals[] = "($blockid, "
				          . "'$sdatedt', "
				          . "'$edatedt')";
			}
		}
		if($method != 'accept') {
			$start = explode(':', $tmp[1]);
			$startmin = $start[1];
			list($starth, $startm) = hour24to12($start[0]);
			$end = explode(':', $tmp[2]);
			$endmin = $end[1];
			list($endh, $endm) = hour24to12($end[0]);
			$dvals[] = "($blockid, "
					   . "'$date', "
					   . "'$date', "
			         . "$i)";
			$tvals[] = "($blockid, "
			         . "'$starth', "
			         . "'$startmin', "
			         . "'$startm', "
			         . "'$endh', "
			         . "'$endmin', "
			         . "'$endm', "
			         . "$i)";
			$i++;
		}
	}
	if($method != 'accept') {
		$alldvals = implode(',', $dvals);
		$query = "INSERT INTO blockWebDate "
		       .        "(blockRequestid, "
		       .        "start, "
		       .        "end, "
		       .        "days) "
		       . "VALUES $alldvals";
		doQuery($query, 101);
		$alltvals = implode(',', $tvals);
		$query = "INSERT INTO blockWebTime "
		       .        "(blockRequestid, "
		       .        "starthour, "
		       .        "startminute, "
		       .        "startmeridian, "
		       .        "endhour, "
		       .        "endminute, "
		       .        "endmeridian, "
		       .        "`order`) "
		       . "VALUES $alltvals";
		doQuery($query, 101);
	}
	if($method == 'new' || $method == 'edit' || $method == 'accept') {
		$allbtvals = implode(',', $btvals);
		$query = "INSERT INTO blockTimes "
				 .        "(blockRequestid, "
				 .        "start, "
				 .        "end) "
				 . "VALUES $allbtvals";
		doQuery($query, 101);
		deleteBlockSkipDuplicates($blockid);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getBlockNotifyUsers($affiliationid)
///
/// \param $affiliationid - an affiliation id
///
/// \return string of comma delimited email addresses
///
/// \brief gets email addresses for all users that should be notified about a
/// block allocation
///
////////////////////////////////////////////////////////////////////////////////
function getBlockNotifyUsers($affiliationid) {
	$query = "SELECT DISTINCT(u.email) "
	       . "FROM user u, "
	       .      "usergroupmembers ugm, "
	       .      "usergroup ug, "
	       .      "usergrouppriv ugp, "
	       .      "usergroupprivtype ugpt "
	       . "WHERE ((ugpt.name = 'Manage Block Allocations (global)' AND "
	       .       "ugp.userprivtypeid = ugpt.id AND "
	       .       "ugp.usergroupid = ugm.usergroupid AND "
	       .       "ugp.usergroupid = ug.id AND "
	       .       "ugm.userid = u.id) OR "
	       .       "(ugpt.name = 'Manage Block Allocations (affiliation only)' AND "
	       .       "ugp.userprivtypeid = ugpt.id AND "
	       .       "ugp.usergroupid = ugm.usergroupid AND "
	       .       "ugm.userid = u.id AND "
	       .       "ugp.usergroupid = ug.id AND "
	       .       "ug.affiliationid = $affiliationid)) AND "
	       .       "u.email != ''";
	$qh = doQuery($query);
	$addrs = array();
	while($row = mysql_fetch_assoc($qh))
		$addrs[] = $row['email'];
	return implode(',', $addrs);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deleteBlockSkipDuplicates($blockid)
///
/// \param $blockid - id of a block allocation
///
/// \brief deletes any block times without skip set for which there is a
/// matching block time with skip set; deletes any with skip set where there is
/// not a matching time without skip set
///
////////////////////////////////////////////////////////////////////////////////
function deleteBlockSkipDuplicates($blockid) {
	$query = "SELECT id, "
	       .        "start, "
	       .        "end, "
	       .        "skip "
	       . "FROM blockTimes "
	       . "WHERE blockRequestid = $blockid";
	$qh = doQuery($query, 101);
	$skips = array();
	$noskips = array();
	while($row = mysql_fetch_assoc($qh)) {
		$key = "{$row['start']}:{$row['end']}";
		if($row['skip'])
			$skips[$key] = $row['id'];
		else
			$noskips[$key] = $row['id'];
	}
	$deleteids = array();
	foreach($skips as $key => $id) {
		if(array_key_exists($key, $noskips))
			$deleteids[] = $noskips[$key];
		else
			$deleteids[] = $id;
	}
	if(empty($deleteids))
		return;
	$inids = implode(',', $deleteids);
	$query = "DELETE FROM blockTimes "
	       . "WHERE id IN ($inids)";
	doQuery($query, 101);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getCurrentBlockHTML($listonly)
///
/// \param $listonly (optional, default=0) - 0 to return everything, 1 to only
/// return the table of block allocations (i.e. don't include the delete dialog)
///
/// \return HTML to display current block allocations
///
/// \brief generates the HTML to display a list of the current block allocations
/// and a dojo dialog for deleting them
///
////////////////////////////////////////////////////////////////////////////////
function getCurrentBlockHTML($listonly=0) {
	global $user, $days;
	$groupids = implode(',', array_keys($user['groups']));
	$query = "SELECT b.id, "
	       .        "b.name AS blockname, "
	       .        "b.ownerid, "
	       .        "CONCAT(u.unityid, '@', ua.name) AS owner, "
	       .        "b.imageid, "
	       .        "i.prettyname AS image, "
	       .        "b.numMachines AS machinecnt, "
	       .        "b.groupid as usergroupid, "
	       .        "CONCAT(g.name, '@', a.name) AS `group`, "
	       .        "b.repeating AS available "
	       . "FROM image i, "
	       .      "blockRequest b "
	       . "LEFT JOIN usergroup g ON (b.groupid = g.id) "
	       . "LEFT JOIN affiliation a ON (g.affiliationid = a.id) "
	       . "LEFT JOIN user u ON (b.ownerid = u.id) "
	       . "LEFT JOIN affiliation ua ON (u.affiliationid = ua.id) "
	       . "WHERE b.imageid = i.id AND ";
	if(! checkUserHasPerm('Manage Block Allocations (global)') && 
	   checkUserHasPerm('Manage Block Allocations (affiliation only)'))
		$query .=   "u.affiliationid = {$user['affiliationid']} AND ";
	$query .=      "b.status = 'accepted' "
	       . "ORDER BY b.name";
	$allblockids = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		if($row['group'] == '') {
			$query3 = "SELECT name FROM usergroup WHERE id = {$row['usergroupid']}";
			$qh3 = doQuery($query3, 101);
			if($row3 = mysql_fetch_assoc($qh3))
				$row['group'] = $row3['name'];
		}
		$allblockids[] = $row['id'];
		$blocks[$row['id']] = $row;
		$query2 = "SELECT DATE_FORMAT(start, '%c/%e/%y<br>%l:%i %p') AS start1, "
		        .        "UNIX_TIMESTAMP(start) AS unixstart, "
		        .        "UNIX_TIMESTAMP(end) AS unixend "
		        . "FROM blockTimes "
		        . "WHERE blockRequestid = {$row['id']} AND "
		        .       "end > NOW() AND "
		        .       "skip = 0 "
		        . "ORDER BY start "
		        . "LIMIT 1";
		$qh2 = doQuery($query2, 101);
		if($row2 = mysql_fetch_assoc($qh2)) {
			if(array_key_exists('tzoffset', $_SESSION['persistdata'])) {
				$tmp = date('n/j/y+g:i=A=T', $row2['unixstart']);
				$blocks[$row['id']]['nextstart'] = str_replace(array('+', '='), array('<br>', '&nbsp;'), $tmp);
			}
			else
				$blocks[$row['id']]['nextstart'] = $row2['start1'];
			if(time() > ($row2['unixstart'] - 1800) &&
			   time() < $row2['unixend'])
				$blocks[$row['id']]['nextstartactive'] = 1;
			else
				$blocks[$row['id']]['nextstartactive'] = 0;
		}
		else {
			$blocks[$row['id']]['nextstart'] = i("none found");
			$blocks[$row['id']]['nextstartactive'] = 0;
		}
	}
	if(empty($blocks)) {
		return "There are currently no block allocations.<br>\n";
	}
	foreach($blocks as $id => $request) {
		if($request['available'] == 'weekly') {
			$query = "SELECT DATE_FORMAT(start, '%m/%d/%Y') AS swdate, "
			       .        "DATE_FORMAT(end, '%m/%d/%Y')AS ewdate, " 
			       .        "days "
			       . "FROM blockWebDate "
			       . "WHERE blockRequestid = $id";
			$qh = doQuery($query, 101);
			if(! $row = mysql_fetch_assoc($qh))
				abort(101);
			$blocks[$id] = array_merge($request, $row);
			$wdays = array();
			for($i = 0; $i < 7; $i++) {
				if($row['days'] & (1 << $i))
					array_push($wdays, $days[$i]);
			}
			unset($blocks[$id]['days']);
			$blocks[$id]['wdays'] = $wdays;
			$query = "SELECT starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order` "
			       . "FROM blockWebTime "
			       . "WHERE blockRequestid = {$request['id']} "
			       . "ORDER BY startmeridian, starthour, startminute";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$blocks[$id]['swhour'][$row['order']] = $row['starthour'];
				$blocks[$id]['swminute'][$row['order']] = $row['startminute'];
				$blocks[$id]['swmeridian'][$row['order']] = $row['startmeridian'];
				$blocks[$id]['ewhour'][$row['order']] = $row['endhour'];
				$blocks[$id]['ewminute'][$row['order']] = $row['endminute'];
				$blocks[$id]['ewmeridian'][$row['order']] = $row['endmeridian'];
			}
		}
		elseif($request['available'] == 'monthly') {
			$query = "SELECT DATE_FORMAT(start, '%m/%d/%Y') AS smdate, "
			       .        "DATE_FORMAT(end, '%m/%d/%Y')AS emdate, " 
			       .        "days AS day, "
			       .        "weeknum "
			       . "FROM blockWebDate "
			       . "WHERE blockRequestid = $id";
			$qh = doQuery($query, 101);
			if(! $row = mysql_fetch_assoc($qh))
				abort(101);
			$blocks[$id] = array_merge($request, $row);
			$query = "SELECT starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order` "
			       . "FROM blockWebTime "
			       . "WHERE blockRequestid = {$request['id']} "
			       . "ORDER BY startmeridian, starthour, startminute";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$blocks[$id]['smhour'][$row['order']] = $row['starthour'];
				$blocks[$id]['smminute'][$row['order']] = $row['startminute'];
				$blocks[$id]['smmeridian'][$row['order']] = $row['startmeridian'];
				$blocks[$id]['emhour'][$row['order']] = $row['endhour'];
				$blocks[$id]['emminute'][$row['order']] = $row['endminute'];
				$blocks[$id]['emmeridian'][$row['order']] = $row['endmeridian'];
			}
		}
		elseif($request['available'] == 'list') {
			$query = "SELECT DATE_FORMAT(start, '%m/%d/%Y') AS date, "
			       .        "days AS `order` "
			       . "FROM blockWebDate "
			       . "WHERE blockRequestid = $id "
			       . "ORDER BY start";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				if($row['date'] == '00/00/00')
					$blocks[$id]['date'][$row['order']] = '';
				else
					$blocks[$id]['date'][$row['order']] = $row['date'];
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
				$blocks[$id]['slhour'][$row['order']] = $row['starthour'];
				$blocks[$id]['slminute'][$row['order']] = $row['startminute'];
				$blocks[$id]['slmeridian'][$row['order']] = $row['startmeridian'];
				$blocks[$id]['elhour'][$row['order']] = $row['endhour'];
				$blocks[$id]['elminute'][$row['order']] = $row['endminute'];
				$blocks[$id]['elmeridian'][$row['order']] = $row['endmeridian'];
			}
		}
	}
	$rt = '';
	$rt .= "<input type=\"hidden\" id=\"timezone\" value=\"" . date('T') . "\">\n";
	$rt .= "<table summary=\"lists current block allocations\">\n";
	$rt .= "  <TR align=center>\n";
	$rt .= "    <TD colspan=3></TD>\n";
	$rt .= "    <TH>" . i("Name") . "</TH>\n";
	$rt .= "    <TH>" . i("Environment") . "</TH>\n";
	$rt .= "    <TH>" . i("Reserved<br>Machines") . "</TH>\n";
	$rt .= "    <TH>" . i("Reserved<br>For") . "</TH>\n";
	$rt .= "    <TH>" . i("Repeating") . "</TH>\n";
	$rt .= "    <TH>" . i("Next Start Time") . "</TH>\n";
	$rt .= "  </TR>\n";
	foreach($blocks as $block) {
		$rt .= "  <TR align=center>\n";
		$rt .= "    <TD>\n";
		$rt .= "      <button dojoType=\"dijit.form.Button\" type=\"button\">\n";
		$rt .= i(      "Edit") . "\n";
		$rt .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$cont = addContinuationsEntry('editBlockAllocation', array('blockid' => $block['id']));
		$rt .= "          location.href = '" . BASEURL . SCRIPT . "?continuation=$cont';\n";
		$rt .= "        </script>\n";
		$rt .= "      </button>\n";
		$rt .= "    </TD>\n";
		$rt .= "    <TD>\n";
		$rt .= "      <button dojoType=\"dijit.form.Button\" type=\"button\">\n";
		$rt .= i(      "Delete") . "\n";
		$rt .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$cont = addContinuationsEntry('AJdeleteBlockAllocationConfirm', $block, SECINDAY);
		$rt .= "          deleteBlockConfirm('$cont');\n";
		$rt .= "        </script>\n";
		$rt .= "      </button>\n";
		$rt .= "    </TD>\n";
		$rt .= "    <TD>\n";
		$rt .= "      <button dojoType=\"dijit.form.Button\" type=\"button\">\n";
		$rt .= i(      "View Times") . "\n";
		$rt .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$cont = addContinuationsEntry('AJviewBlockAllocationTimes', array('blockid' => $block['id']), SECINDAY);
		$rt .= "          viewBlockTimes('$cont');\n";
		$rt .= "        </script>\n";
		$rt .= "      </button>\n";
		$rt .= "    </TD>\n";
		$rt .= "    <TD>{$block['blockname']}</TD>\n";
		$rt .= "    <TD>{$block['image']}</TD>\n";
		$rt .= "    <TD><a href=\"javascript:void(0)\" onclick=\"viewBlockUsage({$block['id']});\">{$block['machinecnt']}</a></TD>\n";
		$rt .= "    <TD>{$block['group']}</TD>\n";
		$rt .= "    <TD>" . i($block['available']) . "</TD>\n";
		if($block['nextstartactive']) {
			$cont = addContinuationsEntry('viewBlockStatus', array('id' => $block['id']));
			$rt .= "    <TD><a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
			$rt .= "{$block['nextstart']}</a></TD>\n";
		}
		else
			$rt .= "    <TD>{$block['nextstart']}</TD>\n";
		$rt .= "  </TR>\n";
	}
	$rt .= "</table>\n";
	if($listonly)
		return $rt;

	$rt .= "<div id=\"confirmDialog\" dojoType=\"dijit.Dialog\" ";
	$rt .= "title=\"" . i("Confirm Delete Block Allocation") . "\">\n";
	$rt .= "<h2>" . i("Confirm Delete Block Allocation") . "</h2>\n";
	$h = i("Please confirm the following values and then click <strong>Delete Block Allocation</strong>");
	$rt .= preg_replace("/(.{1,50}([ \n]|$))/", '\1<br>', $h) . "<br>\n";
	$rt .= "<table summary=\"\">\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Name:") . "</th>\n";
	$rt .= "    <td><span id=\"confname\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Owner:") . "</th>\n";
	$rt .= "    <td><span id=\"confowner\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Environment:") . "</th>\n";
	$rt .= "    <td><span id=\"confimage\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("User Group:") . "</th>\n";
	$rt .= "    <td><span id=\"confgroup\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Seats:") . "</th>\n";
	$rt .= "    <td><span id=\"confseats\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Repeating:") . "</th>\n";
	$rt .= "    <td><span id=\"confrepeat\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"conftitle1\"></span></th>\n";
	$rt .= "    <td><span id=\"confvalue1\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"conftitle2\"></span></th>\n";
	$rt .= "    <td><span id=\"confvalue2\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"conftitle3\"></span></th>\n";
	$rt .= "    <td><span id=\"confvalue3\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"conftitle4\"></span></th>\n";
	$rt .= "    <td><span id=\"confvalue4\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "</table>\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i("Delete Block Allocation") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    deleteBlockSubmit();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i("Cancel") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    clearHideConfirmDelete();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "<input type=hidden id=submitdeletecont>\n";
	$rt .= "</div>\n"; # confirm dialog

	$rt .= "<div id=\"viewtimesDialog\" dojoType=\"dijit.Dialog\" ";
	$rt .= "title=\"" . i("Block Allocation Times") . "\">\n";
	$rt .= "<h2>" . i("Block Allocation Times") . "</h2>\n";
	$rt .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"blockTimesGrid\" sortInfo=1 ";
	$rt .= "style=\"width: 278px; height: 200px;\">\n";
	$rt .= "<script type=\"dojo/method\" event=\"onStyleRow\" args=\"row\">\n";
	$rt .= "blockTimeRowStyle(row);\n";
	$rt .= "</script>\n";
	$rt .= "<thead>\n";
	$rt .= "<tr>\n";
	$rt .= "<th field=\"start\" width=\"65px\" formatter=\"blockTimesGridDate\">" . i("Date") . "</th>\n";
	$rt .= "<th field=\"start\" width=\"54px\" formatter=\"blockTimesGridStart\">" . i("Start") . "</th>\n";
	$rt .= "<th field=\"end\" width=\"54px\" formatter=\"blockTimesGridEnd\">" . i("End") . "</th>\n";
	$rt .= "<th field=\"delbtn\" width=\"60px\">" . i("Skip") . "</th>\n";
	$rt .= "</tr>\n";
	$rt .= "</thead>\n";
	$rt .= "</table>\n";
	$rt .= "<div align=\"center\">\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i("Close") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    dijit.byId('viewtimesDialog').hide();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "</div>\n";
	$rt .= "<input type=hidden id=toggletimecont>\n";
	$rt .= "</div>\n"; # times dialog

	$rt .= "<div id=\"viewUsageDialog\" dojoType=\"dijit.Dialog\" ";
	$rt .= "title=\"" . i("Block Allocation Usage") . "\">\n";
	$rt .= "<div id=\"blockusagechartdiv\" class=\"hidden\"></div>\n";
	$rt .= "<div id=\"blockusageemptydiv\" class=\"hidden\">";
	$rt .= i("This block allocation has never been used.") . "</div>\n";
	$rt .= "<div align=\"center\">\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i("Close") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    dijit.byId('viewUsageDialog').hide();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "</div>\n";
	$blockids = array_keys($blocks);
	$cont = addContinuationsEntry('AJviewBlockAllocationUsage', array('blockids' => $blockids), SECINDAY);
	$rt .= "<input type=hidden id=viewblockusagecont value=\"$cont\">\n";
	$rt .= "</div>\n"; # usage dialog
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserCurrentBlockHTML($listonly)
///
/// \param $listonly (optional, default=0) - 0 to return everything, 1 to only
/// return the table of block allocations (i.e. don't include the delete dialog)
///
/// \return HTML to display current block allocations
///
/// \brief generates the HTML to display a list of the current block allocations
/// and a dojo dialog for deleting them
///
////////////////////////////////////////////////////////////////////////////////
function getUserCurrentBlockHTML($listonly=0) {
	global $user, $days;
	$query = "SELECT b.id, "
	       .        "b.name AS blockname, "
	       .        "b.ownerid, "
	       .        "CONCAT(u.unityid, '@', ua.name) AS owner, "
	       .        "i.prettyname AS image, "
	       .        "b.numMachines AS machinecnt, "
	       .        "CONCAT(g.name, '@', a.name) AS `group`, "
	       .        "b.repeating AS available, "
	       .        "b.status "
	       . "FROM image i, "
	       .      "blockRequest b "
	       . "LEFT JOIN user u ON (b.ownerid = u.id) "
	       . "LEFT JOIN affiliation ua ON (u.affiliationid = ua.id) "
	       . "LEFT JOIN usergroup g ON (b.groupid = g.id) "
	       . "LEFT JOIN affiliation a ON (g.affiliationid = a.id) "
	       . "WHERE b.ownerid = {$user['id']} AND "
	       .       "b.imageid = i.id AND "
	       .       "b.status IN ('accepted', 'requested') "
	       . "ORDER BY b.name";
	$qh = doQuery($query, 101);
	$blocks = array();
	while($row = mysql_fetch_assoc($qh))
		$blocks[$row['id']] = $row;
	if(empty($blocks))
		return;

	foreach($blocks as $id => $request) {
		if($blocks[$id]['group'] == '')
			$blocks[$id]['group'] = i('(unspecified)');
		if($request['available'] == 'weekly') {
			$query = "SELECT DATE_FORMAT(start, '%m/%d/%y') AS swdate, "
			       .        "DATE_FORMAT(end, '%m/%d/%y')AS ewdate, " 
			       .        "days "
			       . "FROM blockWebDate "
			       . "WHERE blockRequestid = $id";
			$qh = doQuery($query, 101);
			if(! $row = mysql_fetch_assoc($qh))
				abort(101);
			$blocks[$id] = array_merge($request, $row);
			$wdays = array();
			for($i = 0; $i < 7; $i++) {
				if($row['days'] & (1 << $i))
					array_push($wdays, $days[$i]);
			}
			unset($blocks[$id]['days']);
			$blocks[$id]['wdays'] = $wdays;
			$query = "SELECT starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order` "
			       . "FROM blockWebTime "
			       . "WHERE blockRequestid = {$request['id']} "
			       . "ORDER BY startmeridian, starthour, startminute";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$blocks[$id]['swhour'][$row['order']] = $row['starthour'];
				$blocks[$id]['swminute'][$row['order']] = $row['startminute'];
				$blocks[$id]['swmeridian'][$row['order']] = $row['startmeridian'];
				$blocks[$id]['ewhour'][$row['order']] = $row['endhour'];
				$blocks[$id]['ewminute'][$row['order']] = $row['endminute'];
				$blocks[$id]['ewmeridian'][$row['order']] = $row['endmeridian'];
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
			$blocks[$id] = array_merge($request, $row);
			$query = "SELECT starthour, "
			       .        "startminute, "
			       .        "startmeridian, "
			       .        "endhour, "
			       .        "endminute, "
			       .        "endmeridian, "
			       .        "`order` "
			       . "FROM blockWebTime "
			       . "WHERE blockRequestid = {$request['id']} "
			       . "ORDER BY startmeridian, starthour, startminute";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$blocks[$id]['smhour'][$row['order']] = $row['starthour'];
				$blocks[$id]['smminute'][$row['order']] = $row['startminute'];
				$blocks[$id]['smmeridian'][$row['order']] = $row['startmeridian'];
				$blocks[$id]['emhour'][$row['order']] = $row['endhour'];
				$blocks[$id]['emminute'][$row['order']] = $row['endminute'];
				$blocks[$id]['emmeridian'][$row['order']] = $row['endmeridian'];
			}
		}
		elseif($request['available'] == 'list') {
			$query = "SELECT DATE_FORMAT(start, '%m/%d/%y') AS date, "
			       .        "days AS `order` "
			       . "FROM blockWebDate "
			       . "WHERE blockRequestid = $id "
			       . "ORDER BY start";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				if($row['date'] == '00/00/00')
					$blocks[$id]['date'][$row['order']] = '';
				else
					$blocks[$id]['date'][$row['order']] = $row['date'];
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
				$blocks[$id]['slhour'][$row['order']] = $row['starthour'];
				$blocks[$id]['slminute'][$row['order']] = $row['startminute'];
				$blocks[$id]['slmeridian'][$row['order']] = $row['startmeridian'];
				$blocks[$id]['elhour'][$row['order']] = $row['endhour'];
				$blocks[$id]['elminute'][$row['order']] = $row['endminute'];
				$blocks[$id]['elmeridian'][$row['order']] = $row['endmeridian'];
			}
		}
	}
	$rt = '';
	$rt .= "<h2>" . i("Manage Block Allocations") . "</h2>\n";
	$rt .= "<div id=\"blocklist\">\n";
	$rt .= "<table summary=\"lists current block allocations\">\n";
	$rt .= "  <TR align=center>\n";
	$rt .= "    <TD colspan=2></TD>\n";
	$rt .= "    <TH>" . i("Name") . "</TH>\n";
	$rt .= "    <TH>" . i("Environment") . "</TH>\n";
	$rt .= "    <TH>" . i("Reserved<br>Machines") . "</TH>\n";
	$rt .= "    <TH>" . i("Reserved<br>For") . "</TH>\n";
	$rt .= "    <TH>" . i("Repeating") . "</TH>\n";
	$rt .= "  </TR>\n";
	foreach($blocks as $block) {
		$rt .= "  <TR align=center>\n";
		$rt .= "    <TD>\n";
		$rt .= "      <button dojoType=\"dijit.form.Button\" type=\"button\">\n";
		$rt .= i(        "View") . "\n";
		$rt .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$cont = addContinuationsEntry('AJviewBlockAllocation', $block, SECINDAY);
		$rt .= "          viewBlockAllocation('$cont');\n";
		$rt .= "        </script>\n";
		$rt .= "      </button>\n";
		$rt .= "    </TD>\n";
		$rt .= "    <TD>\n";
		if($block['status'] == 'accepted') {
			$rt .= "      <button dojoType=\"dijit.form.Button\" type=\"button\">\n";
			$rt .= i(        "View Times") . "\n";
			$rt .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
			$cont = addContinuationsEntry('AJviewBlockAllocationTimes', array('blockid' => $block['id']), SECINDAY);
			$rt .= "          viewBlockTimes('$cont');\n";
			$rt .= "        </script>\n";
			$rt .= "      </button>\n";
		}
		$rt .= "    </TD>\n";
		$rt .= "    <TD>{$block['blockname']}</TD>\n";
		$rt .= "    <TD>{$block['image']}</TD>\n";
		$rt .= "    <TD>{$block['machinecnt']}</TD>\n";
		$rt .= "    <TD>{$block['group']}</TD>\n";
		$rt .= "    <TD>" . i($block['available']) . "</TD>\n";
		$rt .= "  </TR>\n";
	}
	$rt .= "</table>\n";
	$rt .= "</div>\n";
	if($listonly)
		return $rt;

	$rt .= "<div id=\"viewDialog\" dojoType=\"dijit.Dialog\" title=\"";
	$rt .= i("Block Allocation") . "\">\n";
	$rt .= "<table summary=\"\">\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Name") . ":</th>\n";
	$rt .= "    <td><span id=\"confname\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Owner") . ":</th>\n";
	$rt .= "    <td><span id=\"confowner\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Environment") . ":</th>\n";
	$rt .= "    <td><span id=\"confimage\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("User group") . ":</th>\n";
	$rt .= "    <td><span id=\"confgroup\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Seats") . ":</th>\n";
	$rt .= "    <td><span id=\"confseats\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Repeating") . ":</th>\n";
	$rt .= "    <td><span id=\"confrepeat\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"conftitle1\"></span></th>\n";
	$rt .= "    <td><span id=\"confvalue1\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"conftitle2\"></span></th>\n";
	$rt .= "    <td><span id=\"confvalue2\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"conftitle3\"></span></th>\n";
	$rt .= "    <td><span id=\"confvalue3\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"conftitle4\"></span></th>\n";
	$rt .= "    <td><span id=\"confvalue4\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "</table>\n";
	$rt .= "<div align=\"center\">\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i(  "Close") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    clearHideView();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "</div>\n";
	$rt .= "</div>\n"; # confirm dialog

	$rt .= "<div id=\"viewtimesDialog\" dojoType=\"dijit.Dialog\" title=\"";
	$rt .= i("Block Allocation Times") . "\">\n";
	$rt .= "<h2>" . i("Block Allocation Times") . "</h2>\n";
	$rt .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"blockTimesGrid\" sortInfo=1 ";
	$rt .= "style=\"width: 278px; height: 200px;\">\n";
	$rt .= "<script type=\"dojo/method\" event=\"onStyleRow\" args=\"row\">\n";
	$rt .= "blockTimeRowStyle(row);\n";
	$rt .= "</script>\n";
	$rt .= "<thead>\n";
	$rt .= "<tr>\n";
	$rt .= "<th field=\"start\" width=\"60px\" formatter=\"blockTimesGridDate\">";
	$rt .= i("Date") . "</th>\n";
	$rt .= "<th field=\"start\" width=\"54px\" formatter=\"blockTimesGridStart\">";
	$rt .= i("Start") . "</th>\n";
	$rt .= "<th field=\"end\" width=\"54px\" formatter=\"blockTimesGridEnd\">";
	$rt .= i("End") . "</th>\n";
	$rt .= "<th field=\"delbtn\" width=\"60px\">" . i("Skip") . "</th>\n";
	$rt .= "</tr>\n";
	$rt .= "</thead>\n";
	$rt .= "</table>\n";
	$rt .= "<div align=\"center\">\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i(  "Close") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    dijit.byId('viewtimesDialog').hide();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "</div>\n";
	$rt .= "<input type=hidden id=toggletimecont>\n";
	$rt .= "</div>\n"; # times dialog
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getPendingBlockHTML($listonly)
///
/// \param $listonly (optional, default=0) - 0 to return everything, 1 to only
/// return the table of block allocations (i.e. don't include the dojo dialogs)
///
/// \return HTML to display requested block allocations
///
/// \brief generates the HTML to display a list of the requested block
/// allocations and a dojo dialogs for accepting/rejecting them
///
////////////////////////////////////////////////////////////////////////////////
function getPendingBlockHTML($listonly=0) {
	global $days, $user;
	$query = "SELECT b.id, "
	       .        "b.imageid, "
	       .        "i.prettyname AS image, "
	       .        "b.numMachines, "
	       .        "b.groupid AS usergroupid, "
	       .        "CONCAT(ug.name, '@', a.name) AS `group`, "
	       .        "b.repeating, "
	       .        "b.ownerid, "
	       .        "u.unityid, "
	       .        "u.firstname, "
	       .        "u.lastname, "
	       .        "u.email, "
	       .        "DATE_FORMAT(b.expireTime, '%m/%d/%y') AS lastdate, "
	       .        "b.comments "
	       . "FROM image i, "
	       .      "user u, "
	       .      "blockRequest b "
	       . "LEFT JOIN usergroup ug ON (b.groupid = ug.id) "
	       . "LEFT JOIN affiliation a ON (ug.affiliationid = a.id) "
	       . "WHERE status = 'requested' AND "
	       .       "b.imageid = i.id AND "
	       .       "b.ownerid = u.id";
	if(! checkUserHasPerm('Manage Block Allocations (global)'))
		$query .= " AND u.affiliationid = {$user['affiliationid']}";
	$qh = doQuery($query, 101);
	$h  = "<table>\n";
	$h .= "  <tr align=center>\n";
	$h .= "    <td></td>\n";
	$h .= "    <td></td>\n";
	$h .= "    <th>" . i("Environment") . "</th>\n";
	$h .= "    <th>" . i("Requested by") . "</th>\n";
	$h .= "    <th>" . i("Reserved Machines") . "</th>\n";
	$h .= "    <th>" . i("Repeating") . "</th>\n";
	$h .= "    <th>" . i("Start Date") . "</th>\n";
	$h .= "    <th>" . i("End Date") . "</th>\n";
	$h .= "  </tr>\n";
	$d = '';
	$groups = getUserGroups(0, $user['affiliationid']);
	while($row = mysql_fetch_assoc($qh)) {
		if($row['repeating'] == 'weekly') {
			$query2 = "SELECT DATE_FORMAT(start, '%m/%d/%y') AS swdate, "
			        .        "DATE_FORMAT(end, '%m/%d/%y')AS ewdate, " 
			        .        "UNIX_TIMESTAMP(start) AS startts, " 
			        .        "UNIX_TIMESTAMP(end) AS endts, " 
			        .        "days "
			        . "FROM blockWebDate "
			        . "WHERE blockRequestid = {$row['id']}";
			$qh2 = doQuery($query2, 101);
			if(! $row2 = mysql_fetch_assoc($qh2))
				abort(101);
			$row = array_merge($row, $row2);
			$wdays = array();
			for($i = 0; $i < 7; $i++) {
				if($row['days'] & (1 << $i))
					array_push($wdays, $days[$i]);
			}
			$row['wdays'] = $wdays;
			$query2 = "SELECT starthour, "
			        .        "startminute, "
			        .        "startmeridian, "
			        .        "endhour, "
			        .        "endminute, "
			        .        "endmeridian, "
			        .        "`order` "
			        . "FROM blockWebTime "
			        . "WHERE blockRequestid = {$row['id']} "
			        . "ORDER BY startmeridian, starthour, startminute";
			$qh2 = doQuery($query2, 101);
			$row['times'] = array();
			while($row2 = mysql_fetch_assoc($qh2)) {
				$row['swhour'][$row2['order']] = $row2['starthour'];
				$row['swminute'][$row2['order']] = $row2['startminute'];
				$row['swmeridian'][$row2['order']] = $row2['startmeridian'];
				$row['ewhour'][$row2['order']] = $row2['endhour'];
				$row['ewminute'][$row2['order']] = $row2['endminute'];
				$row['ewmeridian'][$row2['order']] = $row2['endmeridian'];
				$row['times'][] = sprintf("%02d:%02d|%02d:%02d",
				                  hour12to24($row2['starthour'], $row2['startmeridian']),
				                  $row2['startminute'],
				                  hour12to24($row2['endhour'], $row2['endmeridian']),
				                  $row2['endminute']);
			}
		}
		elseif($row['repeating'] == 'monthly') {
			$query2 = "SELECT DATE_FORMAT(start, '%m/%d/%y') AS smdate, "
			        .        "DATE_FORMAT(end, '%m/%d/%y')AS emdate, " 
			        .        "UNIX_TIMESTAMP(start) AS startts, " 
			        .        "UNIX_TIMESTAMP(end) AS endts, " 
			        .        "days AS day, "
			        .        "weeknum "
			        . "FROM blockWebDate "
			        . "WHERE blockRequestid = {$row['id']}";
			$qh2 = doQuery($query2, 101);
			if(! $row2 = mysql_fetch_assoc($qh2))
				abort(101);
			$row = array_merge($row, $row2);
			$query2 = "SELECT starthour, "
			        .        "startminute, "
			        .        "startmeridian, "
			        .        "endhour, "
			        .        "endminute, "
			        .        "endmeridian, "
			        .        "`order` "
			        . "FROM blockWebTime "
			        . "WHERE blockRequestid = {$row['id']} "
			        . "ORDER BY startmeridian, starthour, startminute";
			$qh2 = doQuery($query2, 101);
			$row['times'] = array();
			while($row2 = mysql_fetch_assoc($qh2)) {
				$row['smhour'][$row2['order']] = $row2['starthour'];
				$row['smminute'][$row2['order']] = $row2['startminute'];
				$row['smmeridian'][$row2['order']] = $row2['startmeridian'];
				$row['emhour'][$row2['order']] = $row2['endhour'];
				$row['emminute'][$row2['order']] = $row2['endminute'];
				$row['emmeridian'][$row2['order']] = $row2['endmeridian'];
				$row['times'][] = sprintf("%02d:%02d|%02d:%02d",
				                  hour12to24($row2['starthour'], $row2['startmeridian']),
				                  $row2['startminute'],
				                  hour12to24($row2['endhour'], $row2['endmeridian']),
				                  $row2['endminute']);
			}
		}
		elseif($row['repeating'] == 'list') {
			$slotdates = array();
			$query2 = "SELECT DATE_FORMAT(start, '%m/%d/%y') AS date, "
			        .        "start AS slotdate, "
			        .        "days AS `order` "
			        . "FROM blockWebDate "
			        . "WHERE blockRequestid = {$row['id']} "
			        . "ORDER BY start";
			$qh2 = doQuery($query2, 101);
			while($row2 = mysql_fetch_assoc($qh2)) {
				if($row2['date'] == '00/00/00')
					$row['date'][$row2['order']] = '';
				else
					$row['date'][$row2['order']] = $row2['date'];
				$slotdates[$row2['order']] = $row2['slotdate'];
			}
			$query2 = "SELECT starthour, "
			        .        "startminute, "
			        .        "startmeridian, "
			        .        "endhour, "
			        .        "endminute, "
			        .        "endmeridian, "
			        .        "`order` "
			        . "FROM blockWebTime "
			        . "WHERE blockRequestid = {$row['id']}";
			$qh2 = doQuery($query2, 101);
			$row['slots'] = array(); # yyyy-mm-dd|hh:mm|hh:mm
			while($row2 = mysql_fetch_assoc($qh2)) {
				$row['slhour'][$row2['order']] = $row2['starthour'];
				$row['slminute'][$row2['order']] = $row2['startminute'];
				$row['slmeridian'][$row2['order']] = $row2['startmeridian'];
				$row['elhour'][$row2['order']] = $row2['endhour'];
				$row['elminute'][$row2['order']] = $row2['endminute'];
				$row['elmeridian'][$row2['order']] = $row2['endmeridian'];
				$row['slots'][] = sprintf("%s|%02d:%02d|%02d:%02d",
				                  $slotdates[$row2['order']],
				                  hour12to24($row2['starthour'], $row2['startmeridian']),
				                  $row2['startminute'],
				                  hour12to24($row2['endhour'], $row2['endmeridian']),
				                  $row2['endminute']);
			}
		}
		$d .= "  <tr align=center>\n";
		$d .= "    <td>\n";
		$d .= "      <button dojoType=\"dijit.form.Button\" type=\"button\">\n";
		$d .= i(      "Accept...") . "\n";
		$d .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$cont = addContinuationsEntry('AJacceptBlockAllocationConfirm', $row);
		$d .= "          acceptBlockConfirm('$cont');\n";
		$d .= "        </script>\n";
		$d .= "      </button>\n";
		$d .= "    </td>\n";
		$d .= "    <td>\n";
		$d .= "      <button dojoType=\"dijit.form.Button\" type=\"button\">\n";
		$d .= i(      "Reject...") . "\n";
		$d .= "        <script type=\"dojo/method\" event=\"onClick\">\n";
		$cont = addContinuationsEntry('AJrejectBlockAllocationConfirm', $row);
		$d .= "          rejectBlockConfirm('$cont');\n";
		$d .= "        </script>\n";
		$d .= "      </button>\n";
		$d .= "    </td>\n";
		$d .= "<td>{$row['image']}</td>\n";
		if(! empty($row['firstname']) && ! empty($row['lastname']))
			$d .= "<td>{$row['firstname']} {$row['lastname']} ({$row['unityid']})</td>\n";
		else
			$d .= "<td>{$row['unityid']}</td>\n";
		$d .= "<td>{$row['numMachines']}</td>\n";
		$d .= "<td>" . i($row['repeating']) . "</td>\n";
		$d .= "<td>{$row2['start']}</td>\n";
		$d .= "<td>{$row['lastdate']}</td>\n";
		$d .= "  </tr>\n";
	}
	if(empty($d))
		return i("There are currently no pending block allocation requests.");
	$rt = $h . $d . "</table>\n";

	if($listonly)
		return $rt;

	$rt .= "<div id=\"acceptDialog\" dojoType=\"dijit.Dialog\" ";
	$rt .= "title=\"" . i("Accept Block Allocation") . "\">\n";
	$rt .= "<h2>" . i("Accept Block Allocation") . "</h2>\n";
	$h = i("Please review the following information, fill in the additional fields, and click <strong>Accept Block Allocation</strong>.");
	$rt .= preg_replace("/(.{1,100}([ \n]|$))/", '\1<br>', $h) . "<br>";
	$rt .= "<table summary=\"\">\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Environment:") . "</th>\n";
	$rt .= "    <td><span id=\"acceptimage\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Seats:") . "</th>\n";
	$rt .= "    <td><span id=\"acceptseats\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Repeating:") . "</th>\n";
	$rt .= "    <td><span id=\"acceptrepeat\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"accepttitle1\"></span></th>\n";
	$rt .= "    <td><span id=\"acceptvalue1\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"accepttitle2\"></span></th>\n";
	$rt .= "    <td><span id=\"acceptvalue2\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"accepttitle3\"></span></th>\n";
	$rt .= "    <td><span id=\"acceptvalue3\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"accepttitle4\"></span></th>\n";
	$rt .= "    <td><span id=\"acceptvalue4\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"accepttitle5\"></span></th>\n";
	$rt .= "    <td><span id=\"acceptvalue5\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr id=\"staticusergroup\">\n";
	$rt .= "    <th align=\"right\">" . i("User Group:") . "</th>\n";
	$rt .= "    <td><span id=\"acceptgroup\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr id=\"warnmsgtr\" class=\"hidden\">\n";
	$rt .= "    <td colspan=2><span id=\"warnmsg\" class=\"rederrormsg\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <td colspan=2><hr></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr id=\"editusergroup\" class=\"hidden\">\n";
	$rt .= "    <th align=right>" . i("User Group:") . "</th>\n";
	$rt .= "    <td>\n";
	if(USEFILTERINGSELECT && count($groups) < FILTERINGSELECTTHRESHOLD) {
		$rt .= "      <select dojoType=\"dijit.form.FilteringSelect\" id=groupsel ";
		$rt .= "queryExpr=\"*\${0}*\" highlightMatch=\"all\" autoComplete=\"false\" ";
		$rt .= "onChange=\"clearCont2();\">\n";
	}
	else
		$rt .= "      <select id=groupsel onChange=\"clearCont2();\">\n";
	foreach($groups as $id => $group) {
		if($group['name'] == ' None@')
			continue;
		$rt .= "        <option value=\"$id\">{$group['name']}</option>\n";
	}
	$rt .= "      </select>\n";
	$rt .= "    </td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Name:") . "</th>\n";
	$rt .= "    <td>\n";
	$rt .= "      <input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
	$rt .= "id=\"brname\" required=\"true\" invalidMessage=\"";
	$h = i("Name can only contain letters, numbers, spaces, dashes(-), and periods(.) and can be from 3 to 80 characters long");
	$rt .= preg_replace("/(.{1,50}([ \n]|$))/", '\1<br>', $h) . "<br>";
	$rt .= "\" regExp=\"^([-a-zA-Z0-9\. ]){3,80}$\">\n";
	$rt .= "    </td>\n";
	$rt .= "  </tr>\n";
	$rt .= "</table><br>\n";
	$rt .= "<div id=\"acceptemailblock\">\n";
	$rt .= sprintf(i("The following text will be emailed to %s:"), "<span id=\"acceptemailuser\"></span>");
	$rt .= "<br><textarea id=\"acceptemailtext\" dojoType=\"dijit.form.Textarea\" style=\"width: 400px;\">\n";
	$rt .= "</textarea>\n";
	$rt .= "</div>\n";
	$rt .= "<div id=\"acceptemailwarning\" class=\"hidden\">\n";
	$rt .= "<strong>" . i("Note:") . "</strong> ";
	$h = i("The requesting user does not have an email address registered with VCL. Therefore, the user cannot be notified automatically.");
	$rt .= preg_replace("/(.{1,50}([ \n]|$))/", '\1<br>', $h) . "\n";
	$rt .= "</div>\n";
	$rt .= "<br>\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i("Accept Block Allocation") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    acceptBlockSubmit();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i("Cancel") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    clearHideConfirmAccept();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "<input type=hidden id=submitacceptcont>\n";
	$rt .= "<input type=hidden id=submitacceptcont2>\n";
	$rt .= "</div>\n"; # accept dialog

	$rt .= "<div id=\"rejectDialog\" dojoType=\"dijit.Dialog\" ";
	$rt .= "title=\"" . i("Reject Block Allocation") . "\">\n";
	$rt .= "<h2>" . i("Reject Block Allocation") . "</h2>\n";
	$h = i("Please review the following information, add a reason for rejecting the block allocation, and click <strong>Reject Block Allocation</strong>.");
	$rt .= preg_replace("/(.{1,100}([ \n]|$))/", '\1<br>', $h) . "<br>\n";
	$rt .= "<table summary=\"\">\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Environment:") . "</th>\n";
	$rt .= "    <td><span id=\"rejectimage\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr id=\"editusergroup\" class=\"hidden\">\n";
	$rt .= "    <th align=\"right\">" . i("User Group:") . "</th>\n";
	$rt .= "    <td><span id=\"rejectgroup\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Seats:") . "</th>\n";
	$rt .= "    <td><span id=\"rejectseats\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr>\n";
	$rt .= "    <th align=\"right\">" . i("Repeating:") . "</th>\n";
	$rt .= "    <td><span id=\"rejectrepeat\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"rejecttitle1\"></span></th>\n";
	$rt .= "    <td><span id=\"rejectvalue1\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"rejecttitle2\"></span></th>\n";
	$rt .= "    <td><span id=\"rejectvalue2\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"rejecttitle3\"></span></th>\n";
	$rt .= "    <td><span id=\"rejectvalue3\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"rejecttitle4\"></span></th>\n";
	$rt .= "    <td><span id=\"rejectvalue4\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "  <tr valign=\"top\">\n";
	$rt .= "    <th align=\"right\"><span id=\"rejecttitle5\"></span></th>\n";
	$rt .= "    <td><span id=\"rejectvalue5\"></span></td>\n";
	$rt .= "  </tr>\n";
	$rt .= "</table>\n";
	$rt .= "<div id=\"rejectemailblock\">\n";
	$rt .= sprintf(i("The following text will be emailed to %s:"), "<span id=\"rejectemailuser\"></span>");
	$rt .= "<br></div>\n";
	$rt .= "<div id=\"rejectemailwarning\" class=\"hidden\">\n";
	$h = i("The requesting user does not have an email address registered with VCL. Therefore, the user cannot be notified automatically. However, for archival purposes, fill in a reason for rejecting the request:");
	$rt .= preg_replace("/(.{1,60}([ \n]|$))/", '\1<br>', $h);
	$rt .= "\n</div><br>\n";
	$rt .= "<textarea id=\"rejectemailtext\" dojoType=\"dijit.form.Textarea\" style=\"width: 400px;\">\n";
	$rt .= "</textarea>\n";
	$rt .= "<br>\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i("Reject Block Allocation") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    rejectBlockSubmit();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "<button dojoType=\"dijit.form.Button\" type=\"button\">\n";
	$rt .= i("Cancel") . "\n";
	$rt .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
	$rt .= "    clearHideConfirmReject();\n";
	$rt .= "  </script>\n";
	$rt .= "</button>\n";
	$rt .= "<input type=hidden id=submitrejectcont>\n";
	$rt .= "</div>\n"; # reject dialog
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJdeleteBlockAllocationConfirm()
///
/// \brief ajax function to generate JSON data with information about a block
/// allocation to be used when filling in the delete confirmation dialog
///
////////////////////////////////////////////////////////////////////////////////
function AJdeleteBlockAllocationConfirm() {
	global $days;
	$data = getContinuationVar();
	if($data['available'] == 'weekly') {
		$rt = array('name' => $data['blockname'],
		            'ownerid' => $data['ownerid'],
		            'owner' => $data['owner'],
		            'image' => $data['image'],
		            'seats' => $data['machinecnt'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['available'],
		            'startdate' => $data['swdate'],
		            'lastdate' => $data['ewdate'],
		            'days' => $data['wdays']);
		$rt['times'] = array();
		foreach(array_keys($data['swhour']) as $key) {
			$rt['times'][] = sprintf("%d:%02d %s - %d:%02d %s", $data['swhour'][$key],
			                   $data['swminute'][$key], $data['swmeridian'][$key],
			                   $data['ewhour'][$key], $data['ewminute'][$key],
			                   $data['ewmeridian'][$key]);
		}
	}
	elseif($data['available'] == 'monthly') {
		$rt = array('name' => $data['blockname'],
		            'ownerid' => $data['ownerid'],
		            'owner' => $data['owner'],
		            'image' => $data['image'],
		            'seats' => $data['machinecnt'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['available'],
		            'startdate' => $data['smdate'],
		            'lastdate' => $data['emdate']);
		$weeknumArr = array(1 => i("1st"),
		                    2 => i("2nd"),
		                    3 => i("3rd"),
		                    4 => i("4th"),
		                    5 => i("5th"));
		$rt['date1'] = "{$weeknumArr[$data['weeknum']]} {$days[($data['day'] - 1)]}";
		$rt['times'] = array();
		foreach(array_keys($data['smhour']) as $key) {
			$rt['times'][] = sprintf("%d:%02d %s - %d:%02d %s", $data['smhour'][$key],
			                   $data['smminute'][$key], $data['smmeridian'][$key],
			                   $data['emhour'][$key], $data['emminute'][$key],
			                   $data['emmeridian'][$key]);
		}
	}
	elseif($data['available'] == 'list') {
		$rt = array('name' => $data['blockname'],
		            'ownerid' => $data['ownerid'],
		            'owner' => $data['owner'],
		            'image' => $data['image'],
		            'seats' => $data['machinecnt'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['available']);
		$slots = array();
		foreach($data['date'] as $key => $val) {
			$slots[] = sprintf("%s %d:%02d %s - %d:%02d %s", $val, $data['slhour'][$key],
			                   $data['slminute'][$key], $data['slmeridian'][$key],
			                   $data['elhour'][$key], $data['elminute'][$key],
			                   $data['elmeridian'][$key]);
		}
		$rt['slots'] = $slots;
	}
	$cont = addContinuationsEntry('AJdeleteBlockAllocationSubmit', array('blockid' => $data['id']), SECINDAY, 0, 0);
	$rt['cont'] = $cont;
	sendJSON($rt);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJdeleteBlockAllocationSubmit()
///
/// \brief ajax function to delete a block allocation and send updated list of
/// block allocations
///
////////////////////////////////////////////////////////////////////////////////
function AJdeleteBlockAllocationSubmit() {
	$blockid = getContinuationVar('blockid');
	$query = "UPDATE blockRequest SET status = 'deleted' WHERE id = $blockid";
	doQuery($query);
	$reloadid = getUserlistID('vclreload@Local');
	$query = "DELETE FROM request "
	       . "WHERE stateid = 19 AND "
	       .       "laststateid = 19 AND "
	       .       "userid = $reloadid AND "
	       .       "id IN (SELECT bc.reloadrequestid "
	       .              "FROM blockComputers bc, "
	       .                   "blockTimes bt "
	       .              "WHERE bt.blockRequestid = $blockid AND "
	       .                    "bt.id = bc.blockTimeid AND "
	       .                    "bc.reloadrequestid != 0)";
	doQuery($query);
	$query = "DELETE FROM blockTimes WHERE blockRequestid = $blockid";
	doQuery($query);
	$html = getCurrentBlockHTML(1);
	$html = str_replace("\n", '', $html);
	$html = str_replace("'", "\'", $html);
	$html = preg_replace("/>\s*</", "><", $html);
	print "dijit.byId('confirmDialog').hide();";
	print setAttribute('blocklist', 'innerHTML', $html);
	print "AJdojoCreate('blocklist');";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJviewBlockAllocation()
///
/// \brief ajax function to generate JSON data with information about a block
/// allocation to be used when filling in the delete confirmation dialog
///
////////////////////////////////////////////////////////////////////////////////
function AJviewBlockAllocation() {
	global $days;
	$data = getContinuationVar();
	if($data['available'] == 'weekly') {
		$rt = array('name' => $data['blockname'],
		            'ownerid' => $data['ownerid'],
		            'owner' => $data['owner'],
		            'image' => $data['image'],
		            'seats' => $data['machinecnt'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['available'],
		            'startdate' => $data['swdate'],
		            'lastdate' => $data['ewdate'],
		            'days' => $data['wdays']);
		$rt['times'] = array();
		foreach(array_keys($data['swhour']) as $key) {
			$rt['times'][] = sprintf("%d:%02d %s - %d:%02d %s", $data['swhour'][$key],
			                   $data['swminute'][$key], $data['swmeridian'][$key],
			                   $data['ewhour'][$key], $data['ewminute'][$key],
			                   $data['ewmeridian'][$key]);
		}
	}
	elseif($data['available'] == 'monthly') {
		$rt = array('name' => $data['blockname'],
		            'ownerid' => $data['ownerid'],
		            'owner' => $data['owner'],
		            'image' => $data['image'],
		            'seats' => $data['machinecnt'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['available'],
		            'startdate' => $data['smdate'],
		            'lastdate' => $data['emdate']);
		$weeknumArr = array(1 => i("1st"),
		                    2 => i("2nd"),
		                    3 => i("3rd"),
		                    4 => i("4th"),
		                    5 => i("5th"));
		$rt['date1'] = "{$weeknumArr[$data['weeknum']]} {$days[($data['day'] - 1)]}";
		$rt['times'] = array();
		foreach(array_keys($data['smhour']) as $key) {
			$rt['times'][] = sprintf("%d:%02d %s - %d:%02d %s", $data['smhour'][$key],
			                   $data['smminute'][$key], $data['smmeridian'][$key],
			                   $data['emhour'][$key], $data['emminute'][$key],
			                   $data['emmeridian'][$key]);
		}
	}
	elseif($data['available'] == 'list') {
		$rt = array('name' => $data['blockname'],
		            'ownerid' => $data['ownerid'],
		            'owner' => $data['owner'],
		            'image' => $data['image'],
		            'seats' => $data['machinecnt'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['available']);
		$slots = array();
		foreach($data['date'] as $key => $val) {
			$slots[] = sprintf("%s %d:%02d %s - %d:%02d %s", $val, $data['slhour'][$key],
			                   $data['slminute'][$key], $data['slmeridian'][$key],
			                   $data['elhour'][$key], $data['elminute'][$key],
			                   $data['elmeridian'][$key]);
		}
		$rt['slots'] = $slots;
	}
	sendJSON($rt);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJacceptBlockAllocationConfirm()
///
/// \brief ajax function to generate JSON data with information about a block
/// allocation to be used when filling in the accept confirmation dialog
///
////////////////////////////////////////////////////////////////////////////////
function AJacceptBlockAllocationConfirm() {
	global $days;
	$data = getContinuationVar();
	if($data['repeating'] == 'weekly') {
		$rt = array('image' => $data['image'],
		            'seats' => $data['numMachines'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['repeating'],
		            'startdate' => $data['swdate'],
		            'lastdate' => $data['ewdate'],
		            'days' => $data['wdays']);
		$rt['times'] = array();
		foreach(array_keys($data['swhour']) as $key) {
			$rt['times'][] = sprintf("%d:%02d %s - %d:%02d %s", $data['swhour'][$key],
			                   $data['swminute'][$key], $data['swmeridian'][$key],
			                   $data['ewhour'][$key], $data['ewminute'][$key],
			                   $data['ewmeridian'][$key]);
		}
		$rt['email'] = sprintf(i("The VCL Block Allocation you requested for %d seats of %s repeating on a weekly schedule has been accepted."), $data['numMachines'], $data['image']);
	}
	elseif($data['repeating'] == 'monthly') {
		$rt = array('image' => $data['image'],
		            'seats' => $data['numMachines'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['repeating'],
		            'startdate' => $data['smdate'],
		            'lastdate' => $data['emdate']);
		$weeknumArr = array(1 => i("1st"),
		                    2 => i("2nd"),
		                    3 => i("3rd"),
		                    4 => i("4th"),
		                    5 => i("5th"));
		$rt['date1'] = "{$weeknumArr[$data['weeknum']]} {$days[($data['day'] - 1)]}";
		$rt['times'] = array();
		foreach(array_keys($data['smhour']) as $key) {
			$rt['times'][] = sprintf("%d:%02d %s - %d:%02d %s", $data['smhour'][$key],
			                   $data['smminute'][$key], $data['smmeridian'][$key],
			                   $data['emhour'][$key], $data['emminute'][$key],
			                   $data['emmeridian'][$key]);
		}
		$rt['email'] = sprintf(i("The VCL Block Allocation you requested for %d seats of %s repeating on a monthly schedule has been accepted."), $data['numMachines'], $data['image']);
	}
	elseif($data['repeating'] == 'list') {
		$rt = array('image' => $data['image'],
		            'seats' => $data['numMachines'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['repeating']);
		$slots = array();
		foreach($data['date'] as $key => $val) {
			$slots[] = sprintf("%s %d:%02d %s - %d:%02d %s", $val, $data['slhour'][$key],
			                   $data['slminute'][$key], $data['slmeridian'][$key],
			                   $data['elhour'][$key], $data['elminute'][$key],
									 $data['elmeridian'][$key]);
		}
		$rt['slots'] = $slots;
		$rt['email'] = sprintf(i("The VCL Block Allocation you requested for %d seats of %s during the following time periods has been accepted:") . "\n" . implode("\n", $slots) . "\n", $data['numMachines'], $data['image']);
	}
	$rt['comments'] = preg_replace("/\n/", "<br>", $data['comments']);
	if($rt['comments'] == '')
		$rt['comments'] = '(none)';
	$rt['validemail'] = 1;
	if(! empty($data['firstname']) && ! empty($data['lastname']) && ! empty($data['email']))
		$rt['emailuser'] = "{$data['firstname']} {$data['lastname']} ({$data['email']})";
	elseif(! empty($data['email']))
		$rt['emailuser'] = "{$data['email']}";
	else
		$rt['validemail'] = 0;
	if(! is_null($rt['usergroup'])) {
		$groupresources = getUserResources(array("imageAdmin", "imageCheckOut"),
		                                   array("available"), 0, 0, 0,
		                                   $data['usergroupid']);
		if(! array_key_exists($data['imageid'], $groupresources['image']))
			$rt['warnmsg'] = i("Warning: The requested user group does not currently have access to the requested image.");
	}
	$cdata = array('blockid' => $data['id'],
	               'imageid' => $data['imageid']);
	if(empty($data['group']))
		$cdata['setusergroup'] = 1;
	else
		$cdata['setusergroup'] = 0;
	$cdata['validemail'] = $rt['validemail'];
	$cdata['emailuser'] = $data['email'];
	$cdata['repeating'] = $data['repeating'];
	$cdata['comments'] = $data['comments'];
	if($data['repeating'] == 'weekly') {
		$cdata['startts'] = $data['startts'];
		$cdata['endts'] = $data['endts'];
		$cdata['daymask'] = $data['days'];
		$cdata['times'] = $data['times'];
	}
	elseif($data['repeating'] == 'monthly') {
		$cdata['startts'] = $data['startts'];
		$cdata['endts'] = $data['endts'];
		$cdata['day'] = $data['day'];
		$cdata['weeknum'] = $data['weeknum'];
		$cdata['times'] = $data['times'];
	}
	elseif($data['repeating'] == 'list') {
		$cdata['slots'] = $data['slots'];
	}
	$cont = addContinuationsEntry('AJacceptBlockAllocationSubmit', $cdata, SECINDAY, 1, 0);
	$rt['cont'] = $cont;
	sendJSON($rt);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJacceptBlockAllocationSubmit()
///
/// \brief ajax function to accept a block allocation and send updated list of
/// current block allocations and pending block allocations
///
////////////////////////////////////////////////////////////////////////////////
function AJacceptBlockAllocationSubmit() {
	global $mysql_link_vcl, $user;
	$blockid = getContinuationVar('blockid');
	$comments = getContinuationVar('comments');
	$validemail = getContinuationVar('validemail');
	$emailuser = getContinuationVar('emailuser');
	$imageid = getContinuationVar('imageid');
	$setusergroup = getContinuationVar('setusergroup');
	if($setusergroup)
		$usergroupid = processInputVar('groupid', ARG_NUMERIC);
	$name = processInputVar('brname', ARG_STRING);
	$emailtext = processInputVar('emailtext', ARG_STRING);
	$override = getContinuationVar('override', 0);

	$err = 0;
	if(! preg_match('/^([-a-zA-Z0-9\. ]){3,80}$/', $name)) {
	   $errmsg = i("The name can only contain letters, numbers, spaces, dashes(-), and periods(.) and can be from 3 to 80 characters long");
		$err = 1;
	}
	if($validemail) {
		if(get_magic_quotes_gpc())
			$emailtext = stripslashes($emailtext);
		if(! $err && preg_match('/[<>|]/', $emailtext)) {
			$errmsg = i("<>\'s and pipes (|) are not allowed in the email text.");
			$err = 1;
		}
		if(! $err && ! preg_match('/[A-Za-z]{2,}/', $emailtext)) {
			$errmsg = i("Something must be filled in for the email text.");
			$err = 1;
		}
	}
	$groups = getUserGroups(0, $user['affiliationid']);
	if(! $err && $setusergroup && ! array_key_exists($usergroupid, $groups)) {
		$errmsg = i("Invalid user group submitted.");
		$err = 1;
	}
	$managementnodes = getManagementNodes('future');
	if(! $err && empty($managementnodes)) {
		$errmsg  = i("Error encountered while trying to create block allocation:") . "\\n\\n";
		$errmsg .= i("No active management nodes were found. Please try accepting the block allocation at a later time.");
		$err = 1;
	}
	$dooverride = 0;
	if(! $err && ! $override && $setusergroup) {
		$groupresources = getUserResources(array("imageAdmin", "imageCheckOut"),
		                                   array("available"), 0, 0, 0,
		                                   $usergroupid);
		if(! array_key_exists($imageid, $groupresources['image'])) {
			$errmsg  = i("Warning: The selected user group does not currently have access to the requested image. You can accept the Block Allocation again to ignore this warning.");
			$err = 1;
			$dooverride = 1;
		}
	}
	$mnid = array_rand($managementnodes);
	if(! $err) {
		# update values for block allocation
		if($validemail)
			$esccomments = mysql_real_escape_string("COMMENTS: $comments|EMAIL: $emailtext");
		else
			$esccomments = mysql_real_escape_string("COMMENTS: $comments|USER NOT EMAILED");
		$query = "UPDATE blockRequest "
				 . "SET name = '$name', ";
		if($setusergroup)
			$query .= "groupid = $usergroupid, ";
		$query .=    "status = 'accepted', "
			    .     "comments = '$esccomments', "
			    .     "managementnodeid = '$mnid' "
		       . "WHERE id = $blockid";
		doQuery($query, 101);
		if(! mysql_affected_rows($mysql_link_vcl)) {
			$errmsg = i("Error encountered while updating status of block allocation.");
			$err = 1;
		}
		else {
			$repeating = getContinuationVar('repeating');
			if($repeating == 'weekly') {
				$startts = getContinuationVar('startts');
				$endts = getContinuationVar('endts');
				$daymask = getContinuationVar('daymask');
				$times = getContinuationVar('times');
				createWeeklyBlockTimes($blockid, $startts, $endts, $daymask, $times);
			}
			elseif($repeating == 'monthly') {
				$startts = getContinuationVar('startts');
				$endts = getContinuationVar('endts');
				$day = getContinuationVar('day');
				$weeknum = getContinuationVar('weeknum');
				$times = getContinuationVar('times');
				createMonthlyBlockTimes($blockid, $startts, $endts, $day, $weeknum, $times);
			}
			elseif($repeating == 'list') {
				$slots = getContinuationVar('slots');
				createListBlockData($blockid, $slots, 'accept');
			}
		}
	}
	if($err) {
		print "alert('$errmsg');";
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJacceptBlockAllocationSubmit', $cdata, SECINDAY, 1, 0);
		print "dojo.byId('submitacceptcont').value = '$cont';";
		if($dooverride) {
			$cdata['override'] = 1;
			$cont = addContinuationsEntry('AJacceptBlockAllocationSubmit', $cdata, SECINDAY, 1, 0);
			print "dojo.byId('submitacceptcont2').value = '$cont';";
		}
		else
			print "dojo.byId('submitacceptcont2').value = '';";
		print "document.body.style.cursor = 'default';";
		return;
	}

	# send accept email to requestor
	$message = $emailtext . "\n\nVCL Admins";
	$mailParams = "-f" . HELPEMAIL;
	mail($emailuser, i("VCL Block Allocation Accepted"), $message, '', $mailParams);

	print "clearHideConfirmAccept();";

	$html = getPendingBlockHTML(1);
	$html = str_replace("\n", '', $html);
	$html = str_replace("'", "\'", $html);
	$html = preg_replace("/>\s*</", "><", $html);
	print setAttribute('pendinglist', 'innerHTML', $html);
	print "AJdojoCreate('pendinglist');";

	$html = getCurrentBlockHTML(1);
	$html = str_replace("\n", '', $html);
	$html = str_replace("'", "\'", $html);
	$html = preg_replace("/>\s*</", "><", $html);
	print setAttribute('blocklist', 'innerHTML', $html);
	print "AJdojoCreate('blocklist');";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJrejectBlockAllocationConfirm()
///
/// \brief ajax function to generate JSON data with information about a block
/// allocation to be used when filling in the reject confirmation dialog
///
////////////////////////////////////////////////////////////////////////////////
function AJrejectBlockAllocationConfirm() {
	global $days;
	$data = getContinuationVar();
	if($data['repeating'] == 'weekly') {
		$rt = array('image' => $data['image'],
		            'seats' => $data['numMachines'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['repeating'],
		            'startdate' => $data['swdate'],
		            'lastdate' => $data['ewdate'],
		            'days' => $data['wdays']);
		$rt['times'] = array();
		foreach(array_keys($data['swhour']) as $key) {
			$rt['times'][] = sprintf("%d:%02d %s - %d:%02d %s", $data['swhour'][$key],
			                   $data['swminute'][$key], $data['swmeridian'][$key],
			                   $data['ewhour'][$key], $data['ewminute'][$key],
			                   $data['ewmeridian'][$key]);
		}
		$rt['email'] = sprintf(i("The VCL Block Allocation you requested for %d seats of %s repeating on a weekly schedule has been rejected.") . " ", $data['numMachines'], $data['image']);
	}
	elseif($data['repeating'] == 'monthly') {
		$rt = array('image' => $data['image'],
		            'seats' => $data['numMachines'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['repeating'],
		            'startdate' => $data['smdate'],
		            'lastdate' => $data['emdate']);
		$weeknumArr = array(1 => i("1st"),
		                    2 => i("2nd"),
		                    3 => i("3rd"),
		                    4 => i("4th"),
		                    5 => i("5th"));
		$rt['date1'] = "{$weeknumArr[$data['weeknum']]} {$days[($data['day'] - 1)]}";
		$rt['times'] = array();
		foreach(array_keys($data['smhour']) as $key) {
			$rt['times'][] = sprintf("%d:%02d %s - %d:%02d %s", $data['smhour'][$key],
			                   $data['smminute'][$key], $data['smmeridian'][$key],
			                   $data['emhour'][$key], $data['emminute'][$key],
			                   $data['emmeridian'][$key]);
		}
		$rt['email'] = sprintf(i("The VCL Block Allocation you requested for %d seats of %s repeating on a monthly schedule has been rejected.") . " ", $data['numMachines'], $data['image']);
	}
	elseif($data['repeating'] == 'list') {
		$rt = array('image' => $data['image'],
		            'seats' => $data['numMachines'],
		            'usergroup' => $data['group'],
		            'repeating' => $data['repeating']);
		$slots = array();
		foreach($data['date'] as $key => $val) {
			$slots[] = sprintf("%s %d:%02d %s - %d:%02d %s", $val, $data['slhour'][$key],
			                   $data['slminute'][$key], $data['slmeridian'][$key],
			                   $data['elhour'][$key], $data['elminute'][$key],
									 $data['elmeridian'][$key]);
		}
		$rt['slots'] = $slots;
		$rt['email'] = sprintf(i("The VCL Block Allocation you requested for %d seats of %s during the following time periods has been rejected.") . "\n" . implode("\n", $slots) . "\n\n", $data['numMachines'], $data['image']);
	}
	$rt['comments'] = preg_replace("/\n/", "<br>", $data['comments']);
	if($rt['comments'] == '')
		$rt['comments'] = '(none)';
	$rt['validemail'] = 1;
	if(! empty($data['firstname']) && ! empty($data['lastname']) && ! empty($data['email']))
		$rt['emailuser'] = "{$data['firstname']} {$data['lastname']} ({$data['email']})";
	elseif(! empty($data['email']))
		$rt['emailuser'] = "{$data['email']}";
	else
		$rt['validemail'] = 0;
	$cdata = array('blockid' => $data['id']);
	$cdata['validemail'] = $rt['validemail'];
	$cdata['emailuser'] = $data['email'];
	$cdata['email'] = $rt['email'];
	$cdata['comments'] = $data['comments'];
	$cont = addContinuationsEntry('AJrejectBlockAllocationSubmit', $cdata, SECINDAY, 1, 0);
	$rt['cont'] = $cont;
	sendJSON($rt);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJrejectBlockAllocationSubmit()
///
/// \brief ajax function to reject a block allocation and send updated list of
/// pending block allocations
///
////////////////////////////////////////////////////////////////////////////////
function AJrejectBlockAllocationSubmit() {
	global $mysql_link_vcl;
	$blockid = getContinuationVar('blockid');
	$comments = getContinuationVar('comments');
	$validemail = getContinuationVar('validemail');
	$emailuser = getContinuationVar('emailuser');
	$email = getContinuationVar('email');
	$emailtext = processInputVar('emailtext', ARG_STRING);

	$err = 0;
	if($email == $emailtext) {
		$errmsg = i("Please include a reason for rejecting the block allocation in the email.");
		$err = 1;
	}
	if(get_magic_quotes_gpc())
		$emailtext = stripslashes($emailtext);
	if(! $err && preg_match('/[<>|]/', $emailtext)) {
		if($validemail)
			$errmsg = i("<>\'s and pipes (|) are not allowed in the email text.");
		else
			$errmsg = i("<>\'s and pipes (|) are not allowed in the reject reason.");
		$err = 1;
	}
	if(! $err && ! preg_match('/[A-Za-z]{2,}/', $emailtext)) {
		if($validemail)
			$errmsg = i("Something must be filled in for the email text.");
		else
			$errmsg = i("Something must be filled in for the reject reason.");
		$err = 1;
	}

	if(! $err) {
		# update values for block allocation
		if($validemail)
			$esccomments = mysql_real_escape_string("COMMENTS: $comments|EMAIL: $emailtext");
		else
			$esccomments = mysql_real_escape_string("COMMENTS: $comments|REJECTREASON: $emailtext");
		$query = "UPDATE blockRequest "
				 . "SET name = 'rejected', "
				 .     "status = 'rejected', "
				 .     "comments = '$esccomments' "
				 . "WHERE id = $blockid";
		doQuery($query, 101);
		if(! mysql_affected_rows($mysql_link_vcl)) {
			$errmsg = i("Error encountered while updating status of block allocation.");
			$err = 1;
		}
	}
	if($err) {
		print "alert('$errmsg');";
		$cdata = getContinuationVar();
		$cont = addContinuationsEntry('AJrejectBlockAllocationSubmit', $cdata, SECINDAY, 1, 0);
		print "dojo.byId('submitrejectcont').value = '$cont';";
		print "document.body.style.cursor = 'default';";
		return;
	}

	# send reject email to requestor
	$message = $emailtext . "\n\nVCL Admins";
	$mailParams = "-f" . HELPEMAIL;
	mail($emailuser, i("VCL Block Allocation Rejected"), $message, '', $mailParams);

	print "clearHideConfirmReject();";

	$html = getPendingBlockHTML(1);
	$html = str_replace("\n", '', $html);
	$html = str_replace("'", "\'", $html);
	$html = preg_replace("/>\s*</", "><", $html);
	print setAttribute('pendinglist', 'innerHTML', $html);
	print "AJdojoCreate('pendinglist');";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJviewBlockAllocationTimes()
///
/// \brief gets start/end data about a block time and sends it in json format
///
////////////////////////////////////////////////////////////////////////////////
function AJviewBlockAllocationTimes() {
	$blockid = getContinuationVar('blockid');
	$query = "SELECT id, "
	       .        "start, "
	       .        "end, "
	       .        "skip "
	       . "FROM blockTimes "
	       . "WHERE blockRequestid = $blockid AND "
	       .       "end > NOW() "
	       . "ORDER BY start";
	$qh = doQuery($query, 101);
	$data = array();
	$items = array();
	while($row = mysql_fetch_assoc($qh))
		$items[] = $row;
	$cont = addContinuationsEntry('AJtoggleBlockTime', array('blockid' => $blockid));
	$data['cont'] = $cont;
	$data['items'] = $items;
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJtoggleBlockTime()
///
/// \brief toggles the skip flag for a block time
///
////////////////////////////////////////////////////////////////////////////////
function AJtoggleBlockTime() {
	$blockid = getContinuationVar('blockid');
	$timeid = processInputVar('blocktimeid', ARG_NUMERIC);
	$query = "SELECT blockRequestid, "
	       .        "end, "
	       .        "skip "
	       . "FROM blockTimes "
	       . "WHERE id = $timeid";
	$qh = doQuery($query, 101);
	if(! ($row = mysql_fetch_assoc($qh)) || $row['blockRequestid'] != $blockid) {
		$data['error'] = i("Invalid block time submitted");
		sendJSON($data);
		return;
	}
	if(datetimeToUnix($row['end']) <= time()) {
		$data['error'] = i("The end time for the submitted block allocation time has passed. Therefore, it can no longer be modified.");
		sendJSON($data);
		return;
	}
	$reloadid = getUserlistID('vclreload@Local');
	$query = "DELETE FROM request "
	       . "WHERE id IN "
	       .    "(SELECT DISTINCT reloadrequestid "
	       .    "FROM blockComputers "
	       .    "WHERE blockTimeid = $timeid) AND "
	       .    "stateid = 19 AND "
	       .    "laststateid = 19 AND "
	       .    "userid = $reloadid";
	doQuery($query, 101);
	$query = "DELETE FROM blockComputers "
	       . "WHERE blockTimeid = $timeid";
	doQuery($query, 101);

	$skip = $row['skip'] ^ 1;
	$query = "UPDATE blockTimes "
	       . "SET skip = $skip ";
	if($skip == 0)
		$query .= ", processed = 0 ";
	$query .= "WHERE id = $timeid";
	doQuery($query, 101);
	$data['newval'] = $skip;
	$data['timeid'] = $timeid;
	sendJSON($data);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewBlockStatus()
///
/// \brief prints a page with information about an active block allocation
///
////////////////////////////////////////////////////////////////////////////////
function viewBlockStatus() {
	$blockid = getContinuationVar('id');
	print "<H2>" . i("Block Allocation") . "</H2>\n";
	$data = getBlockAllocationStatus($blockid);
	if(is_null($data)) {
		print i("The selected Block Allocation no longer exists.");
		return;
	}
	$startunix = datetimeToUnix($data['start']);
	$endunix = datetimeToUnix($data['end']);
	$start = strftime('%x %l:%M %P %Z', $startunix);
	$end = strftime('%x %l:%M %P %Z', $endunix);
	print "<div id=statusdiv>\n";
	print "<table class=blockStatusData summary=\"lists attributes of block allocation\">\n";
	print "  <tr>\n";
	print "    <th>" . i("Name") . ":</th>\n";
	print "    <td>{$data['name']}</td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th>" . i("Environment") . ":</th>\n";
	print "    <td>{$data['image']}</td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th>" . i("Resources") . ":</th>\n";
	if($data['subimages'])
		print "    <td>{$data['numMachines']} clusters</td>\n";
	else
		print "    <td>{$data['numMachines']} computers</td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th>" . i("Starting") . ":</th>\n";
	print "    <td>$start</td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th>" . i("Ending") . ":</th>\n";
	print "    <td>$end</td>\n";
	print "  </tr>\n";
	print "</table><br>\n";
	if(! $data['subimages']) {
		$available = 0;
		$reloading = 0;
		$used = 0;
		foreach($data['comps'] as $id => $comp) {
			if($comp['state'] == 'available')
				$available++;
			elseif($comp['state'] == 'reloading')
				$reloading++;
			elseif($comp['state'] == 'reserved' ||
			       $comp['state'] == 'inuse')
				$used++;
		}
		$failed = $data['numMachines'] - $available - $reloading - $used;
		print i("Current status of computers") . ":<br>\n";
	}
	else {
		$imgdata = getImages(0, $data['imageid']);
		$imageids = $imgdata[$data['imageid']]['subimages'];
		array_unshift($imageids, $data['imageid']);
		$imgavailable = array();
		$imgreloading = array();
		$imgused = array();
		$imgfailed = array();
		foreach($imageids AS $id) {
			$imgavailable[$id] = 0;
			$imgreloading[$id] = 0;
			$imgused[$id] = 0;
			$imgfailed[$id] = 0;
		}
		foreach($data['comps'] as $id => $comp) {
			if($comp['state'] == 'available')
				$imgavailable[$comp['designatedimageid']]++;
			elseif($comp['state'] == 'reloading')
				$imgreloading[$comp['designatedimageid']]++;
			elseif($comp['state'] == 'reserved' ||
			       $comp['state'] == 'inuse')
				$imgused[$comp['designatedimageid']]++;
		}
		$failed = 0;
		$available = $data['numMachines'];
		$used = $imgused[$data['imageid']];
		foreach($imageids AS $id) {
			$imgfailed[$id] = $data['numMachines'] - $imgavailable[$id] - $imgreloading[$id] - $used;
			if($failed < $imgfailed[$id])
				$failed = $imgfailed[$id];
			if($available > $imgavailable[$id])
				$available = $imgavailable[$id];
		}
		$reloading = $data['numMachines'] - $available - $used - $failed;
		print i("Current status of clusters:") . "<br>\n";
	}
	print "<table class=blockStatusData summary=\"lists status of block allocation\">\n";
	print "  <tr>\n";
	print "    <th><font color=green>" . i("Available") . ":</th>\n";
	print "    <td id=available>$available</td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th>" . i("Reloading") . ":</th>\n";
	print "    <td id=reloading>$reloading</td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th nowrap><font color=#e58304>" . i("Reserved/In use") . ":</th>\n";
	print "    <td id=used>$used</td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th><font color=red>" . i("Failed") . ":</th>\n";
	print "    <td id=failed>$failed</td>\n";
	print "  </tr>\n";
	print "</table>\n";
	print "</div>\n";
	$cont = addContinuationsEntry('AJupdateBlockStatus', array('id' => $blockid));
	print "<input type=hidden id=updatecont value=\"$cont\">\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJupdateBlockStatus()
///
/// \brief ajax function to send JSON data about the current status of a block
/// allocation
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateBlockStatus() {
	$id = getContinuationVar('id');
	$data = getBlockAllocationStatus($id);
	if(is_null($data)) {
		sendJSON(array('status' => 'gone'));
		return;
	}
	if(! $data['subimages']) {
		$available = 0;
		$reloading = 0;
		$used = 0;
		foreach($data['comps'] as $id => $comp) {
			if($comp['state'] == 'available')
				$available++;
			elseif($comp['state'] == 'reload' ||
			       $comp['state'] == 'reloading')
				$reloading++;
			elseif($comp['state'] == 'reserved' ||
			       $comp['state'] == 'inuse')
				$used++;
		}
		$failed = $data['numMachines'] - $available - $reloading - $used;
	}
	else {
		$imgdata = getImages(0, $data['imageid']);
		$imageids = $imgdata[$data['imageid']]['subimages'];
		array_unshift($imageids, $data['imageid']);
		$imgavailable = array();
		$imgreloading = array();
		$imgused = array();
		$imgfailed = array();
		foreach($imageids AS $id) {
			$imgavailable[$id] = 0;
			$imgreloading[$id] = 0;
			$imgused[$id] = 0;
			$imgfailed[$id] = 0;
		}
		foreach($data['comps'] as $id => $comp) {
			if($comp['state'] == 'available')
				$imgavailable[$comp['designatedimageid']]++;
			elseif($comp['state'] == 'reloading')
				$imgreloading[$comp['designatedimageid']]++;
			elseif($comp['state'] == 'reserved' ||
			       $comp['state'] == 'inuse')
				$imgused[$comp['designatedimageid']]++;
		}
		$failed = 0;
		$available = $data['numMachines'];
		$used = $imgused[$data['imageid']];
		foreach($imageids AS $id) {
			$imgfailed[$id] = $data['numMachines'] - $imgavailable[$id] - $imgreloading[$id] - $used;
			if($failed < $imgfailed[$id])
				$failed = $imgfailed[$id];
			if($available > $imgavailable[$id])
				$available = $imgavailable[$id];
		}
		$reloading = $data['numMachines'] - $available - $used - $failed;
	}
	$arr = array('available' => $available,
	             'reloading' => $reloading,
	             'used' => $used,
	             'failed' => $failed);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processBlockAllocationInput()
///
/// \return an array with these keys:\n
/// \b name - name of block allocation\n
/// \b imageid - selected image id\n
/// \b seats - number of machines to allocate\n
/// \b groupid - user group id for selected user group\n
/// \b type - 'weekly', 'monthly', or 'list'\n
/// \b slots - array of date/time slots in 'YYYY-MM-DD|HH:MM|HH:MM' format (date|start|end)\n
/// \b times - array of times in HH:MM|HH:MM format (start|end)\n
/// \b expiretime - datetime at which this block allocation will be completed\n
/// \b startdate - start date of block allocation (only valid for weekly and monthly)\n
/// \b enddate - end date of block allocation (only valid for weekly and monthly)\n
/// \b startts - unix timestamp for startdate\n
/// \b endts - unix timestamp for enddate\n
/// \b daymask - bitmask int for days of week (only valid for weekly)\n
/// \b weeknum - week of the month (from 1 to 5, only valid for monthly)\n
/// \b day - day of week (from 1 to 7, only valid for monthly)\n
/// \b comments - user submitted comments about this block allocation\n
/// \b err - 1 if error encountered, 0 if not
///
/// \brief processes input for blockallocations
///
////////////////////////////////////////////////////////////////////////////////
function processBlockAllocationInput() {
	global $user;
	$return = array();
	$method = getContinuationVar('method');
	$return['name'] = processInputVar('name', ARG_STRING);
	$return['owner'] = processInputVar('owner', ARG_STRING);
	$return['imageid'] = processInputVar('imageid', ARG_NUMERIC);
	$return['seats'] = processInputVar('seats', ARG_NUMERIC);
	$return['groupid'] = processInputVar('groupid', ARG_NUMERIC);
	$override = getContinuationVar('override', 0);
	$type = processInputVar('type', ARG_STRING);
	$err = 0;
	if($method != 'request' && ! preg_match('/^([-a-zA-Z0-9\. \(\)]){3,80}$/', $return['name'])) {
		$errmsg = i("The name can only contain letters, numbers, spaces, dashes(-), and periods(.) and can be from 3 to 80 characters long");
		$err = 1;
	}
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);
	if(! array_key_exists($return['imageid'], $resources['image'])) {
		$errmsg = i("The submitted image is invalid.");
		$err = 1;
	}
	if(! $err && $method != 'request' && ! validateUserid($return['owner'])) {
		$errmsg = i("The submitted owner is invalid.");
		$err = 1;
	}
	else
		$return['ownerid'] = getUserlistID($return['owner']);
	$groups = getUserGroups(0, $user['affiliationid']);
	$extragroups = getContinuationVar('extragroups');
	if(! $err && ! array_key_exists($return['groupid'], $groups) &&
	   ! array_key_exists($return['groupid'], $extragroups) &&
	   $return['groupid'] != 0) {
		$errmsg = i("The submitted user group is invalid.");
		$err = 1;
	}
	if(! $err && $return['groupid'] == 0)
		$return['groupid'] = 'NULL';
	if(! $err && ($return['seats'] < MIN_BLOCK_MACHINES || $return['seats'] > MAX_BLOCK_MACHINES)) {
		$errmsg = sprintf(i("The submitted number of seats must be between %d and %d."), MIN_BLOCK_MACHINES, MAX_BLOCK_MACHINES);
		$err = 1;
	}
	if(! $err) {
		$imgdata = getImages(0, $return['imageid']);
		$concur = $imgdata[$return['imageid']]['maxconcurrent'];
		if(! is_null($concur) && $concur != 0 && $return['seats'] > $concur) {
			$errmsg = sprintf(i("The selected image can only have %d concurrent reservations. Please reduce the number of requested seats to %d or less."), $concur, $concur);
			$err = 1;
		}
	}
	$dooverride = 0;
	# check user group access to image
	if(($method == 'new' || $method == 'edit') && ! $err && ! $override) {
		$groupresources = getUserResources(array("imageAdmin", "imageCheckOut"),
		                                   array("available"), 0, 0, 0,
		                                   $return['groupid']);
		if(! array_key_exists($return['imageid'], $groupresources['image'])) {
			$dooverride = 1;
			$errmsg = i("WARNING - The selected user group does not currently have access to the selected environment. You can submit the Block Allocation again to ignore this warning.");
			$err = 1;
		}
	}
	if(! $err && $type != 'weekly' && $type != 'monthly' && $type != 'list') {
		$errmsg = i("You must select one of \"Repeating Weekly\", \"Repeating Monthly\", or \"List of Dates/Times\".");
		$err = 1;
	}
	if(! $err) {
		if($type == 'list') {
			$slots = processInputVar('slots', ARG_STRING);
			$return['slots'] = explode(',', $slots);
			$return['times'] = array();
			$lastdate = array('day' => '', 'ts' => 0);
			foreach($return['slots'] as $slot) {
				$tmp = explode('|', $slot);
				if(count($tmp) != 3) {
					$errmsg = i("Invalid date/time submitted.");
					$err = 1;
					break;
				}
				$date = $tmp[0];
				if(! $err) {
					$datets = strtotime($date);
					if($method != 'edit' && $datets < (time() - SECINDAY)) {
						$errmsg = i("The date must be today or later.");
						$err = 1;
						break;
					}
				}
				$return['times'][] = "{$tmp[1]}|{$tmp[2]}";
				if($datets > $lastdate['ts']) {
					$lastdate['ts'] = $datets;
					$lastdate['day'] = $date;
				}
			}
			if(! $err) {
				$expirets = strtotime("{$lastdate['day']} 23:59:59");
				$return['expiretime'] = unixToDatetime($expirets);
			}
		}
		if($type == 'weekly' || $type == 'monthly') {
			$return['startdate'] = processInputVar('startdate', ARG_NUMERIC);
			$return['enddate'] = processInputVar('enddate', ARG_NUMERIC);
			$times = processInputVar('times', ARG_STRING);

			$return['startts'] = strtotime($return['startdate']);
			$return['endts'] = strtotime($return['enddate']);
			if($return['startts'] > $return['endts']) {
				$errmsg = i("The Last Date of Usage must be the same or later than the First Date of Usage.");
				$err = 1;
			}
			elseif($method != 'edit' && $return['startts'] < (time() - SECINDAY)) {
				$errmsg = i("The start date must be today or later.");
				$err = 1;
			}
			$expirets = strtotime("{$return['enddate']} 23:59:59");
			$return['expiretime'] = unixToDatetime($expirets);
			$return['times'] = explode(',', $times);
		}
		foreach($return['times'] as $time) {
			$tmp = explode('|', $time);
			if(count($tmp) != 2) {
				$errmsg = i("Invalid start/end time submitted");
				$err = 1;
				break;
			}
			$start = explode(':', $tmp[0]);
			if(count($start) != 2 || ! is_numeric($start[0]) || ! is_numeric($start[1]) ||
			   $start[0] < 0 || $start[0] > 23 || $start[1] < 0 || $start[1] > 59) {
				$errmsg = i("Invalid start time submitted");
				$err = 1;
				break;
			}
			$end = explode(':', $tmp[1]);
			if(count($end) != 2 || ! is_numeric($end[0]) || ! is_numeric($end[1]) ||
			   $end[0] < 0 || $end[0] > 23 || $end[1] < 0 || $end[1] > 59) {
				$errmsg = i("Invalid end time submitted");
				$err = 1;
				break;
			}
			$start = minuteOfDay($start[0], $start[1]);
			$end = minuteOfDay($end[0], $end[1]);
			if($start >= $end) {
				$errmsg = i("Each start time must be less than the corresponding end time.");
				$err = 1;
				break;
			}
		}
		if($type == 'weekly') {
			$validdays = 0;
			$errmsg = '';
			for($day = $return['startts'], $i = 0;
			   $i < 7, $day < ($return['endts'] + SECINDAY); 
			   $i++, $day += SECINDAY) {
				$daynum = date('w', $day);
				$validdays |= (1 << $daynum);
			}
			$days = processInputVar('days', ARG_STRING);
			$dayscheck = processInputVar('days', ARG_NUMERIC);
			if($days == '' && $dayscheck == '0')
				$days = 0;
			$return['daymask'] = 0;
			if(! $err) {
				foreach(explode(',', $days) as $day) {
					if($day == '' || $day < 0 || $day > 6) {
						$errmsg = i("Invalid day submitted.");
						$err = 1;
						break;
					}
					$return['daymask'] |= (1 << $day);
				}
			}
			if(! $err && ($return['daymask'] & $validdays) == 0) {
				$errmsg = i("No valid days submitted for the specified date range.");
				$err = 1;
			}
		}
		if($type == 'monthly') {
			$return['weeknum'] = processInputVar('weeknum', ARG_NUMERIC);
			$return['day'] = processInputVar('day', ARG_NUMERIC);
			if(! $err && ($return['weeknum'] < 1 || $return['weeknum'] > 5)) {
				$errmsg = i("Invalid week number submitted.");
				$err = 1;
			}
			if(! $err && ($return['day'] < 1 || $return['day'] > 7)) {
				$errmsg = i("Invalid day of week submitted.");
				$err = 1;
			}
			$times = getMonthlyBlockTimes('', $return['startts'], $return['endts'],
			                 $return['day'], $return['weeknum'], $return['times']);
			if(! $err && empty($times)) {
				$errmsg = i("Specified day of month not found in date range.");
				$err = 1;
			}
		}
	}
	if($method == 'request') {
		$return['comments'] = processInputVar('comments', ARG_STRING);
		if(get_magic_quotes_gpc())
			$return['comments'] = stripslashes($return['comments']);
		if(! $err && preg_match('/[<>]/', $return['comments'])) {
			$errmsg = i("<>\'s are not allowed in the comments.");
			$err = 1;
		}
	}
	if($err) {
		print "clearHideConfirmForm();";
		print "alert('$errmsg');";
		$data = array('extragroups' => $extragroups,
		              'method' => $method);
		if($method == 'edit')
			$data['blockid'] = getContinuationVar('blockid');
		$cont = addContinuationsEntry('AJblockAllocationSubmit', $data, SECINWEEK, 1, 0);
		print "dojo.byId('submitcont').value = '$cont';";
		if($dooverride) {
			$data['override'] = 1;
			$cont = addContinuationsEntry('AJblockAllocationSubmit', $data, SECINWEEK, 1, 0);
			print "dojo.byId('submitcont2').value = '$cont';";
		}
		else
			print "dojo.byId('submitcont2').value = '';";
	}
	$return['type'] = $type;
	$return['err'] = $err;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getBlockAllocationStatus($id)
///
/// \param $id - id of a block allocation
///
/// \return if $id, an array with these keys (NULL otherwise):\n
/// \b name - name of block allocation\n
/// \b imageid - id of image\n
/// \b image - pretty name of image\n
/// \b subimages - 0 or 1; if image has subimages\n
/// \b numMachines - number of machines allocated for block allocation\n
/// \b groupid - id of group associated with block allocation\n
/// \b group - name of group associated with block allocation\n
/// \b processing - flag from table\n
/// \b timeid - id of associated block time having earliest start time\n
/// \b start - start time of associated block time (datetime)\n
/// \b end - end time of associated block time (datetime)\n
/// \b processed - flag from table\n
/// \b comps - array of data from blockComputers with these keys:\n
/// \b id - id of computer\n
/// \b state - state of computer\n
/// \b currentimageid - current imageid of computer\n
/// \b curentimage - current image of computer\n
/// \b designatedimageid - id of image to be loaded on computer\n
/// \b designatedimage - image to be loaded on computer\n
/// \b hostname - hostname of computer\n
/// \b type - the computer type
///
/// \brief gets status information about the passed in block allocation id
///
////////////////////////////////////////////////////////////////////////////////
function getBlockAllocationStatus($id) {
	$query = "SELECT r.name, "
	       .        "r.imageid, "
	       .        "i.prettyname AS image, "
	       .        "im.subimages, "
	       .        "r.numMachines, "
	       .        "r.groupid, "
	       .        "g.name AS 'group', "
	       .        "r.processing, "
	       .        "t.id AS timeid, "
	       .        "t.start, "
	       .        "t.end, "
	       .        "t.processed "
	       . "FROM blockRequest r, "
	       .      "blockTimes t, "
	       .      "usergroup g, "
	       .      "image i "
	       . "LEFT JOIN imagemeta im ON (i.imagemetaid = im.id) "
	       . "WHERE t.blockRequestid = $id AND "
	       .       "r.id = $id AND "
	       .       "r.imageid = i.id AND "
	       .       "r.groupid = g.id "
	       . "ORDER BY t.start "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($data = mysql_fetch_assoc($qh)) {
		if(! is_numeric($data['subimages']))
			$data['subimages'] = 0;
		$query = "SELECT c.id, "
		       .        "s.name AS state, "
		       .        "c.currentimageid, "
		       .        "ci.prettyname AS curentimage, "
		       .        "bc.imageid AS designatedimageid, "
		       .        "di.prettyname AS designatedimage, "
		       .        "c.hostname, "
		       .        "c.type "
		       . "FROM blockComputers bc, "
		       .      "computer c, "
		       .      "state s, "
		       .      "image ci, "
		       .      "image di "
		       . "WHERE bc.blockTimeid = {$data['timeid']} AND "
		       .       "bc.computerid = c.id AND "
		       .       "c.currentimageid = ci.id AND "
		       .       "bc.imageid = di.id AND "
		       .       "c.stateid = s.id";
		$qh = doQuery($query, 101);
		$data['comps'] = array();
		while($row = mysql_fetch_assoc($qh))
			$data['comps'][$row['id']] = $row;
		return $data;
	}
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getBlockAllocationData($blockid)
///
/// \param $blockid - id of a block allocation
///
/// \return an array with these keys:\n
/// \b name - name of block allocation\n
/// \b imageid - id of image\n
/// \b seats - number of machines allocated for block allocation\n
/// \b ownerid - id from user table of block allocation owner\n
/// \b owner - block allocation owner\n
/// \b usergroupid - id of group associated with block allocation\n
/// \b repeating - weekly, monthly, or list\n
/// \b type - array with weekly, monthly, or list set to 'checked' and the
///    others set to an empty string\n
/// \b type2 - array with weekly, monthly, or list set to 'selected' and the
///    others set to an empty string\n
/// \b swdate - start date of associated block time (datetime)\n
/// \b ewdate - end date of associated block time (datetime)\n
/// \b smdate - start date of associated block time (datetime)\n
/// \b emdate - end date of associated block time (datetime)\n
/// \b wdayschecked - array where keys are days of the week and values are
///    either 'checked' or empty
/// \b mnweeknumid - week of the month (1 to 5)\n
/// \b mndayid - day of the week (1 to 7)
///
/// \brief gets information about a block allocation
///
////////////////////////////////////////////////////////////////////////////////
function getBlockAllocationData($blockid) {
	global $days;
	$rt = array('name' => '',
	            'imageid' => '',
	            'seats' => MIN_BLOCK_MACHINES,
	            'ownerid' => '',
	            'owner' => '',
	            'usergroupid' => '',
	            'repeating' => '',
	            'swdate' => '',
	            'ewdate' => '',
	            'wdayschecked' => array(),
	            'smdate' => '',
	            'emdate' => '',
	            'mnweeknumid' => '',
	            'mndayid' => '');
	foreach($days as $day)
		$rt['wdayschecked'][$day] = '';
	$rt['type'] = array('weekly' => 'checked',
	                    'monthly' => '',
	                    'list' => '');
	$rt['type2'] = array('weekly' => 'selected',
	                    'monthly' => '',
	                    'list' => '');
	if(empty($blockid))
		return $rt;
	$query = "SELECT b.name, "
	       .        "b.imageid, "
	       .        "b.numMachines AS seats, "
	       .        "b.ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "b.groupid AS usergroupid, "
	       .        "b.repeating, "
	       .        "d.start AS swdate, "
	       .        "d.end AS ewdate, "
	       .        "d.start AS smdate, "
	       .        "d.end AS emdate, "
	       .        "d.days AS mndayid, "
	       .        "d.weeknum AS mnweeknumid "
	       . "FROM blockWebDate d, "
	       .      "blockRequest b "
	       . "LEFT JOIN user u ON (b.ownerid = u.id) "
	       . "LEFT JOIN affiliation a ON (u.affiliationid = a.id) "
	       . "WHERE b.id = d.blockRequestid AND "
	       .       "b.id = $blockid";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	if(empty($row))
		return $rt;
	$row['wdayschecked'] = $rt['wdayschecked'];
	if($row['repeating'] == 'weekly') {
		$row['smdate'] = '';
		$row['emdate'] = '';
		for($i = 0; $i < 7; $i++) {
			if($row['mndayid'] & (1 << $i))
				$row['wdayschecked'][$days[$i]] = 'checked';
		}
		$row['type'] = $rt['type'];
		$row['type2'] = $rt['type2'];
	}
	elseif($row['repeating'] == 'monthly') {
		$row['swdate'] = '';
		$row['ewdate'] = '';
		$row['type'] = array('weekly' => '',
		                     'monthly' => 'checked',
		                     'list' => '');
		$row['type2'] = array('weekly' => '',
		                      'monthly' => 'selected',
		                      'list' => '');
	}
	elseif($row['repeating'] == 'list') {
		$row['smdate'] = '';
		$row['emdate'] = '';
		$row['swdate'] = '';
		$row['ewdate'] = '';
		$row['type'] = array('weekly' => '',
		                     'monthly' => '',
		                     'list' => 'checked');
		$row['type2'] = array('weekly' => '',
		                      'monthly' => '',
		                      'list' => 'selected');
	}
	return $row;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJpopulateBlockStore()
///
/// \brief ajax function to send JSON data for creating the dojo data store for
/// a block allocation set of times
///
////////////////////////////////////////////////////////////////////////////////
function AJpopulateBlockStore() {
	$blockid = getContinuationVar('blockid');
	$query = "SELECT repeating FROM blockRequest WHERE id = $blockid";
	$qh = doQuery($query, 101);
	if(! ($row = mysql_fetch_assoc($qh))) {
		sendJSON(array('error' => i("Error: Failed to fetch start/end times for block allocation.")));
		return;
	}
	if($row['repeating'] == 'weekly' || $row['repeating'] == 'monthly') {
		$type = $row['repeating'];
		$query = "SELECT starthour, "
		       .        "startminute, "
		       .        "startmeridian, "
		       .        "endhour, "
		       .        "endminute, "
		       .        "endmeridian "
		       . "FROM blockWebTime "
		       . "WHERE blockRequestid = $blockid";
		$qh = doQuery($query, 101);
		$starths = array();
		$startms = array();
		$endhs = array();
		$endms = array();
		while($row = mysql_fetch_assoc($qh)) {
			$starth = hour12to24($row['starthour'], $row['startmeridian']);
			$endh = hour12to24($row['endhour'], $row['endmeridian']);
			$starths[] = $starth;
			$startms[] = $row['startminute'];
			$endhs[] = $endh;
			$endms[] = $row['endminute'];
		}
		sendJSON(array('type' => $type,
		               'starths' => $starths,
		               'startms' => $startms,
		               'endhs' => $endhs,
		               'endms' => $endms));
	}
	elseif($row['repeating'] == 'list') {
		$query = "SELECT starthour, "
		       .        "startminute, "
		       .        "startmeridian, "
		       .        "endhour, "
		       .        "endminute, "
		       .        "endmeridian, "
		       .        "`order` "
		       . "FROM blockWebTime "
		       . "WHERE blockRequestid = $blockid";
		$qh = doQuery($query, 101);
		$data = array();
		while($row = mysql_fetch_assoc($qh))
			$data[$row['order']] = $row;
		$query = "SELECT MONTH(start) AS month, "
		       .        "DAY(start) AS day, "
		       .        "YEAR(start) AS year, "
		       .        "days "
		       . "FROM blockWebDate "
		       . "WHERE blockRequestid = $blockid";
		$qh = doQuery($query, 101);
		$months = array();
		$days = array();
		$years = array();
		$starths = array();
		$startms = array();
		$endhs = array();
		$endms = array();
		while($row = mysql_fetch_assoc($qh)) {
			$id = $row['days'];
			$months[] = $row['month'];
			$days[] = $row['day'];
			$years[] = $row['year'];
			$starth = hour12to24($data[$id]['starthour'], $data[$id]['startmeridian']);
			$endh = hour12to24($data[$id]['endhour'], $data[$id]['endmeridian']);
			$starths[] = $starth;
			$startms[] = $data[$id]['startminute'];
			$endhs[] = $endh;
			$endms[] = $data[$id]['endminute'];
		}
		sendJSON(array('type' => 'list',
		               'months' => $months,
		               'days' => $days,
		               'years' => $years,
		               'starths' => $starths,
		               'startms' => $startms,
		               'endhs' => $endhs,
		               'endms' => $endms));
	}

}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewBlockAllocatedMachines()
///
/// \brief prints a page that displays charts of machines allocated to block
/// allocations
///
////////////////////////////////////////////////////////////////////////////////
function viewBlockAllocatedMachines() {
	print "<h2>" . i("Block Allocated Machines") . "</h2>\n";
	print "(All times are in " . date('T') . ")<br><br>\n";
	print i("Start time:") . " \n";
	$start = unixToDatetime(unixFloor15(time() - 3600));
	list($sdate, $stime) = explode(' ', $start);
	print "<div type=\"text\" id=\"chartstartdate\" dojoType=\"dijit.form.DateTextBox\" ";
	print "required=\"true\" value=\"$sdate\"></div>\n";
	print "<div type=\"text\" id=\"chartstarttime\" dojoType=\"dijit.form.TimeTextBox\" ";
	print "required=\"true\" value=\"T$stime\" style=\"width: 78px\"></div>\n";
	print "<button dojoType=\"dijit.form.Button\" type=\"button\" ";
	print "id=\"updatechart\">\n";
	print i("Update Charts") . "\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print "    updateAllocatedMachines();\n";
	print "  </script>\n";
	print "</button>\n";
	print "<h3>" . i("Bare Machines") . "</h3>\n";
	print "<div id=\"totalbare\"></div>\n";
	print getChartHTML('allocatedBareMachines');
	print "<h3>" . i("Virtual Machines") . "</h3>\n";
	print "<div id=\"totalvirtual\"></div>\n";
	print getChartHTML('allocatedVirtualMachines');
	$cont = addContinuationsEntry('AJgetBlockAllocatedMachineData', array('val' => 0), SECINDAY, 1, 0);
	print "<input type=\"hidden\" id=\"updatecont\" value=\"$cont\">\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getChartHTML($id)
///
/// \param $id = js id for the dojo chart
///
/// \return html to build a dojo chart
///
/// \brief creates the html needed to generate a dojo chart
///
////////////////////////////////////////////////////////////////////////////////
function getChartHTML($id) {
	$txt  = "<div style=\"width:500px; height: 320px;\">\n";
	$txt .= "<div dojoType=\"dojox.charting.widget.Chart2D\" id=\"$id\"\n";
	$txt .= "     theme=\"dojox.charting.themes.ThreeD\"\n";
	$txt .= "     style=\"width: 500px; height: 300px;\">\n";
	$txt .= "<div class=\"axis\"\n";
	$txt .= "     name=\"x\"\n";
	if($id == 'allocatedBareMachines')
		$txt .= "     labelFunc=\"timestampToTimeBare\"\n";
	elseif($id == 'allocatedVirtualMachines')
		$txt .= "     labelFunc=\"timestampToTimeVirtual\"\n";
	$txt .= "     maxLabelSize=\"85\"\n";
	$txt .= "     maxLabelCharCount=\"8\"\n";
	$txt .= "     rotation=\"-90\"\n";
	$txt .= "     majorTickStep=\"4\"\n";
	$txt .= "     minorTickStep=\"1\">\n";
	$txt .= "     </div>\n";
	$txt .= "<div class=\"axis\" name=\"y\" vertical=\"true\" includeZero=\"true\"></div>\n";
	$txt .= "<div class=\"plot\" name=\"default\" type=\"Columns\"></div>\n";
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
/// \fn AJgetBlockAllocatedMachineData()
///
/// \brief gets data about machines allocated to block allocations for the time
/// period starting with submitted start and ending 12 hours later; sends data
/// in JSON format
///
////////////////////////////////////////////////////////////////////////////////
function AJgetBlockAllocatedMachineData() {
	global $user;
	$start = processInputVar('start', ARG_STRING);
	if(! preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/', $start)) {
		$start = unixFloor15(time() - 3600);
		$startdt = unixToDatetime($start);
	}
	else {
		$startdt = "$start:00";
		$start = datetimeToUnix($startdt);
	}
	$end = $start + (12 * 3600);
	$enddt = unixToDatetime($end);
	$alldata = array();

	# bare
	$data = array();
	if(checkUserHasPerm('Manage Block Allocations (global)')) {
		$query = "SELECT COUNT(id) "
		       . "FROM computer "
		       . "WHERE stateid IN (2, 3, 6, 8, 11) AND "
		       .       "type = 'blade'";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_row($qh))
			$data['total'] = $row[0];
	}
	else
		// TODO once we allow limiting total machines by affiliation, put that value here
		$data['total'] = 0;
	for($time = $start, $i = 0; $time < $end; $time += 900, $i++) {
		$fmttime = date('g:i a', $time);
		$data["points"][$i] = array('x' => $i, 'y' => 0, 'value' => $i, 'text' => $fmttime);
	}
	$data['maxy'] = 0;
	if(checkUserHasPerm('Manage Block Allocations (global)')) {
		$query = "SELECT UNIX_TIMESTAMP(bt.start) as start, "
		       .        "UNIX_TIMESTAMP(bt.end) as end, "
		       .        "br.numMachines "
		       . "FROM blockTimes bt, "
		       .      "blockRequest br, "
		       .      "image i, "
		       .      "OS o "
		       . "WHERE bt.blockRequestid = br.id AND "
		       .       "bt.skip = 0 AND "
		       .       "bt.start < '$enddt' AND "
		       .       "bt.end > '$startdt' AND "
		       .       "br.imageid = i.id AND "
		       .       "i.OSid = o.id AND "
		       .       "o.installtype != 'vmware'";
	}
	else {
		$query = "SELECT UNIX_TIMESTAMP(bt.start) as start, "
		       .        "UNIX_TIMESTAMP(bt.end) as end, "
		       .        "br.numMachines "
		       . "FROM blockTimes bt, "
		       .      "blockRequest br, "
		       .      "image i, "
		       .      "OS o, "
		       .      "user u "
		       . "WHERE bt.blockRequestid = br.id AND "
		       .       "bt.skip = 0 AND "
		       .       "bt.start < '$enddt' AND "
		       .       "bt.end > '$startdt' AND "
		       .       "br.imageid = i.id AND "
		       .       "i.OSid = o.id AND "
		       .       "o.installtype != 'vmware' AND "
		       .       "br.ownerid = u.id AND "
		       .       "u.affiliationid = {$user['affiliationid']}";
	}
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		for($binstart = $start, $binend = $start + 900, $binindex = 0; 
		   $binend <= $end;
		   $binstart += 900, $binend += 900, $binindex++) {
			if($binend <= $row['start'])
				continue;
			elseif($row['start'] < $binend && $row['end'] > $binstart)
				$data["points"][$binindex]['y'] += $row['numMachines'];
			elseif($binstart >= $row['end'])
				break;
		}
	}
	for($time = $start, $i = 0; $time < $end; $time += 900, $i++) {
		if($data["points"][$i]['y'] > $data['maxy'])
			$data['maxy'] = $data['points'][$i]['y'];
		$data["points"][$i]['tooltip'] = "{$data['points'][$i]['text']}: {$data['points'][$i]['y']}";
	}
	$alldata['bare'] = $data;

	# virtual
	$data = array();
	if(checkUserHasPerm('Manage Block Allocations (global)')) {
		$query = "SELECT COUNT(id) "
		       . "FROM computer "
		       . "WHERE stateid IN (2, 3, 6, 8, 11) AND "
		       .       "type = 'virtualmachine'";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_row($qh))
			$data['total'] = $row[0];
	}
	else
		// TODO once we allow limiting total machines by affiliation, put that value here
		$data['total'] = 0;
	for($time = $start, $i = 0; $time < $end; $time += 900, $i++) {
		$fmttime = date('g:i a', $time);
		$data["points"][$i] = array('x' => $i, 'y' => 0, 'value' => $i, 'text' => $fmttime);
	}
	$data['maxy'] = 0;
	if(checkUserHasPerm('Manage Block Allocations (global)')) {
		$query = "SELECT UNIX_TIMESTAMP(bt.start) as start, "
		       .        "UNIX_TIMESTAMP(bt.end) as end, "
		       .        "br.numMachines "
		       . "FROM blockTimes bt, "
		       .      "blockRequest br, "
		       .      "image i, "
		       .      "OS o "
		       . "WHERE bt.blockRequestid = br.id AND "
		       .       "bt.skip = 0 AND "
		       .       "bt.start < '$enddt' AND "
		       .       "bt.end > '$startdt' AND "
		       .       "br.imageid = i.id AND "
		       .       "i.OSid = o.id AND "
		       .       "o.installtype = 'vmware'";
	}
	else {
		$query = "SELECT UNIX_TIMESTAMP(bt.start) as start, "
		       .        "UNIX_TIMESTAMP(bt.end) as end, "
		       .        "br.numMachines "
		       . "FROM blockTimes bt, "
		       .      "blockRequest br, "
		       .      "image i, "
		       .      "OS o, "
		       .      "user u "
		       . "WHERE bt.blockRequestid = br.id AND "
		       .       "bt.skip = 0 AND "
		       .       "bt.start < '$enddt' AND "
		       .       "bt.end > '$startdt' AND "
		       .       "br.imageid = i.id AND "
		       .       "i.OSid = o.id AND "
		       .       "o.installtype = 'vmware' AND "
		       .       "br.ownerid = u.id AND "
		       .       "u.affiliationid = {$user['affiliationid']}";
	}
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		for($binstart = $start, $binend = $start + 900, $binindex = 0; 
		   $binend <= $end;
		   $binstart += 900, $binend += 900, $binindex++) {
			if($binend <= $row['start'])
				continue;
			elseif($row['start'] < $binend && $row['end'] > $binstart)
				$data["points"][$binindex]['y'] += $row['numMachines'];
			elseif($binstart >= $row['end'])
				break;
		}
	}
	for($time = $start, $i = 0; $time < $end; $time += 900, $i++) {
		if($data["points"][$i]['y'] > $data['maxy'])
			$data['maxy'] = $data['points'][$i]['y'];
		$data["points"][$i]['tooltip'] = "{$data['points'][$i]['text']}: {$data['points'][$i]['y']}";
	}
	$alldata['virtual'] = $data;

	$val = getContinuationVar('val') + 1;
	$cont = addContinuationsEntry('AJgetBlockAllocatedMachineData', array('val' => $val), SECINDAY, 1, 0);
	$alldata['cont'] = $cont;
	sendJSON($alldata);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJviewBlockAllocationUsage()
///
/// \brief generates graph data showing how usage of a block allocation
///
////////////////////////////////////////////////////////////////////////////////
function AJviewBlockAllocationUsage() {
	$blockid = processInputVar('blockid', ARG_NUMERIC);
	$allowedblockids = getContinuationVar('blockids');
	if(! in_array($blockid, $allowedblockids)) {
		sendJSON(array('status' => 'failed', 'message' => 'noaccess'));
		return;
	}
	$query = "SELECT COUNT(s.computerid) AS used, "
	       .        "br.numMachines AS allocated, "
	       .        "s.blockStart "
	       . "FROM blockRequest br "
	       . "LEFT JOIN sublog s ON (s.blockRequestid = br.id) "
	       . "WHERE br.id = $blockid "
	       . "GROUP BY s.blockRequestid, s.blockStart, s.blockEnd "
	       . "ORDER BY s.blockStart";
	$qh = doQuery($query);
	$usage = array();
	$first = 1;
	$firststart = '';
	$laststart = '';
	while($row = mysql_fetch_assoc($qh)) {
		if($first && ! is_null($row['blockStart'])) {
			$firststart = datetimeToUnix($row['blockStart']);
			$first = 0;
		}
		elseif(! is_null($row['blockStart']))
			$laststart = datetimeToUnix($row['blockStart']);
		if(is_null($row['blockStart']))
			continue;
		$percent = (int)($row['used'] / $row['allocated'] * 100);
		$startts = datetimeToUnix($row['blockStart']);
		$usage[$startts] = array('percent' => $percent,
		                         'label' => $row['blockStart']);
	}
	if($firststart == '') {
		sendJSON(array('status' => 'empty', 'message' => 'nousage'));
		return;
	}
	$data = array('points' => array(), 'xlabels' => array());
	$cnt = 0;
	$tmp = localtime($firststart, 1);
	$firstisdst = 0;
	if($tmp['tm_isdst'])
		$firstisdst = 1;
	for($i = $firststart; $i <= $laststart + 3600; $i += SECINDAY) {
		$tmp = localtime($i, 1);
		$time = $i;
		if($firstisdst && ! $tmp['tm_isdst'])
			$time += 3600;
		if(! $firstisdst && $tmp['tm_isdst'])
			$time -= 3600;
		$cnt++;
		$label = date('m/d g:i a', $time);
		if(array_key_exists($time, $usage))
			$data['points'][] = array('y' => $usage[$time]['percent'], 'tooltip' => "$label: " . $usage[$time]['percent'] . " %");
		else
			$data['points'][] = array('y' => 0, 'tooltip' => "$label: 0");
		$data['xlabels'][] = array('value' => $cnt, 'text' => $label);
	}
	sendJSON(array('status' => 'success',
	               'usage' => $data));
}
?>
