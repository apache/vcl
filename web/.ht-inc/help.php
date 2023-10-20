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
/// signifies an error with the submitted email address
define("EMAILERR", 1 << 1);
/// signifies an error with the submitted problem text
define("TEXTERR", 1 << 2);
/// signifies an error with the submitted problem summary
define("SUMMARYERR", 1 << 3);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printHelpForm()
///
/// \brief prints a form for a user to send in a help request
///
////////////////////////////////////////////////////////////////////////////////
function printHelpForm() {
	global $user, $submitErr, $noHTMLwrappers;
	if($submitErr) {
		$name = processInputVar("name", ARG_STRING);
		$email = processInputVar("email", ARG_STRING);
		$summary = processInputVar("summary", ARG_STRING);
		$text = processInputVar("comments", ARG_STRING);
		if(get_magic_quotes_gpc()) {
			$name = stripslashes($name);
			$summary = stripslashes($summary);
			$text = stripslashes($text);
		}
		$name = preg_replace(array('/"/', '/>/'), array('&quot;', '&gt;'), $name);
		$summary = preg_replace(array('/"/', '/>/'), array('&quot;', '&gt;'), $summary);
	}
	else {
		$name = '';
		if(! empty($user['lastname']) && ! empty($user['preferredname']))
			$name = "{$user["preferredname"]} {$user['lastname']}";
		elseif(! empty($user['lastname']) && ! empty($user['preferredname']))
			$name = "{$user["firstname"]} {$user['lastname']}";
		$email = $user["email"];
		$summary = "";
		$text = "";
	}
	if(! in_array('helpform', $noHTMLwrappers))
		print "<H2>VCL Help</H2>\n";
	print "This form sends a request to the VCL support group.  Please provide ";
	print "as much information as possible.<br><br>\n";
	if(HELPFAQURL != '') {
		print "Please see our <a href=\"" . HELPFAQURL . "\">";
		print "FAQ</a> Section before sending your request - it may be an easy ";
		print "fix!<br><br>\n";
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";

	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Name:</TH>\n";
	print "    <TD><INPUT type=text name=name size=25 value=\"$name\"></TD>\n";
	print "    <TD>";
	printSubmitErr(NAMEERR);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Email:</TH>\n";
	print "    <TD><INPUT type=text name=email size=25 value=\"$email\"></TD>\n";
	print "    <TD>";
	printSubmitErr(EMAILERR);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Summary:</TH>\n";
	print "    <TD><INPUT type=text name=summary size=25 value=\"$summary\"></TD>\n";
	print "    <TD>";
	printSubmitErr(SUMMARYERR);
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<br>\n";
	print "Please describe the problem you are having. Include a description ";
	print "of how you encountered the problem and any error messages you ";
	print "received:<br>\n";
	printSubmitErr(TEXTERR);
	print "<textarea tabindex=2 name=comments cols=50 rows=8>$text</textarea><br>\n";
	if(in_array('helpform', $noHTMLwrappers))
		$cdata = array('indrupal' => 1);
	else
		$cdata = array();
	$cont = addContinuationsEntry('submitHelpForm', $cdata, SECINDAY, 1, 0);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT tabindex=3 type=submit value=\"Submit Help Request\">\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitHelpForm()
///
/// \brief processes the help form and notifies the user that it was submitted
///
////////////////////////////////////////////////////////////////////////////////
function submitHelpForm() {
	global $user, $submitErr, $submitErrMsg;
	$name = processInputVar("name", ARG_STRING);
	$email = processInputVar("email", ARG_STRING);
	$summary = processInputVar("summary", ARG_STRING);
	$text = processInputVar("comments", ARG_STRING);

	$testname = $name;
	if(get_magic_quotes_gpc())
		$testname = stripslashes($name);
	if(! preg_match('/^([-A-Za-z \']{1,} [-A-Za-z \']{2,})*$/', $testname)) {
		$submitErr |= NAMEERR;
		$submitErrMsg[NAMEERR] = "Name can only contain letters, spaces, apostrophes ('), and dashes (-). Both first and last name must be specified.";
	}
	if(! preg_match('/^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,3})$/i',
	   $email)) {
		$submitErr |= EMAILERR;
		$submitErrMsg[EMAILERR] = "Invalid email address, please correct";
	}
	if(empty($summary)) {
		$submitErr |= SUMMARYERR;
		$submitErrMsg[SUMMARYERR] = "Please fill in a very short summary of the "
		                          . "problem";
	}
	if(empty($text)) {
		$submitErr |= TEXTERR;
		$submitErrMsg[TEXTERR] = "Please fill in your problem in the box below.<br>";
	}
	if($submitErr) {
		printHelpForm();
		return;
	}

	$computers = getComputers();
	$requests = array();
	$query = "SELECT l.id, "
	       .        "l.start, "
	       .        "l.finalend AS end, "
	       .        "s.computerid, "
	       .        "i.prettyname AS prettyimage "
	       . "FROM log l, "
	       .      "image i, "
	       .      "sublog s "
	       . "WHERE l.userid = {$user["id"]} AND "
	       .        "i.id = l.imageid AND "
	       .        "s.logid = l.id AND "
	       .        "l.finalend < DATE_ADD(NOW(), INTERVAL 1 DAY) "
	       . "ORDER BY l.finalend DESC "
	       . "LIMIT 5";
	$qh = doQuery($query, 290);
	while($row = mysqli_fetch_assoc($qh)) {
		# only include 1 computer from cluster reservations
		if(array_key_exists($row['id'], $requests))
			continue;
		$requests[$row['id']] =  $row;
	}

	$from = $user["email"];
	if(get_magic_quotes_gpc())
		$text = stripslashes($text);
	$message = "Problem report submitted from VCL web form:\n\n"
	         . "User: " . $user["unityid"] . "\n"
	         . "Name: " . $testname . "\n"
	         . "Email: " . $email . "\n"
	         . "Problem description:\n\n$text\n\n";
	$recentrequests = "";
	foreach($requests as $request) {
		$thisstart = str_replace('&nbsp;', ' ', 
				prettyDatetime($request["start"], 0, 1));
		$thisend = str_replace('&nbsp;', ' ', 
				prettyDatetime($request["end"], 0, 1));
		$recentrequests .= "Image: {$request["prettyimage"]}\n"
		                .  "Computer: {$computers[$request["computerid"]]["hostname"]}\n"
		                .  "Start: $thisstart\n"
		                .  "End: $thisend\n\n";
	}
	if(! empty($recentrequests)) {
		$message .= "-----------------------------------------------\n";
		$message .= "User's recent reservations:\n\n" . $recentrequests . "\n";
	}
	else {
		$message .= "User has no recent reservations\n";
	}

	# login history
	$query = "SELECT authmech, "
	       .        "timestamp, "
	       .        "passfail, "
	       .        "remoteIP, "
	       .        "code "
	       . "FROM loginlog "
	       . "WHERE (user = '{$user['unityid']}' OR "
	       .       "user = '{$user['unityid']}@{$user['affiliation']}') AND "
	       .       "affiliationid = {$user['affiliationid']} "
	       . "ORDER BY timestamp DESC "
	       . "LIMIT 5";
	$methodlen = strlen(i('Authentication Method'));
	$timelen = strlen(i('Timestamp'));
	$resultlen = strlen(i('Result'));
	$remoteiplen = strlen(i('Remote IP'));
	$extralen = strlen(i('Extra Info'));
	if(strlen(i('Pass')) > $resultlen)
		$resultlen = strlen(i('Pass'));
	if(strlen(i('Fail')) > $resultlen)
		$resultlen = strlen(i('Fail'));
	$qh = doQuery($query);
	$logins = array();
	while($row = mysql_fetch_assoc($qh)) {
		$tmp = prettyDatetime($row['timestamp'], 1, 1);
		$row['timestamp'] = str_replace('&nbsp;', ' ', $tmp);
		if($row['passfail'])
			$row['passfail'] = 'Pass';
		else
			$row['passfail'] = 'Fail';
		if(strlen($row['authmech']) > $methodlen)
			$methodlen = strlen($row['authmech']);
		if(strlen($row['timestamp']) > $timelen)
			$timelen = strlen($row['timestamp']);
		if(strlen($row['remoteIP']) > $remoteiplen)
			$remoteiplen = strlen($row['remoteIP']);
		if(strlen($row['code']) > $extralen)
			$extralen = strlen($row['code']);
		$logins[] = $row;
	}
	if(count($logins)) {
		$logins = array_reverse($logins);
		$message .= "-----------------------------------------------\n";
		$message .= "User's Login History (up to last 5 attempts):\n\n";
		$message .= sprintf("%-{$methodlen}s | ", i('Authentication Method'));
		$message .= sprintf("%-{$timelen}s | ", i('Timestamp'));
		$message .= sprintf("%-{$resultlen}s | ", i('Result'));
		$message .= sprintf("%-{$remoteiplen}s | ", i('Remote IP'));
		$message .= sprintf("%-{$extralen}s\n", i('Extra Info'));
		foreach($logins as $login) {
			$message .= sprintf("%-{$methodlen}s | ", $login['authmech']);
			$message .= sprintf("%-{$timelen}s | ", $login['timestamp']);
			$message .= sprintf("%-{$resultlen}s | ", $login['passfail']);
			$message .= sprintf("%-{$remoteiplen}s | ", $login['remoteIP']);
			$message .= sprintf("%-{$extralen}s\n", $login['code']);
		}
	}
	if(isset($_SERVER['HTTP_USER_AGENT'])) {
		$message .= "-----------------------------------------------\n";
		$message .= "User agent: {$_SERVER['HTTP_USER_AGENT']}\n";
	}

	$indrupal = getContinuationVar('indrupal', 0);
	if(! $indrupal)
		print "<H2>VCL Help</H2>\n";
	$mailParams = "-f" . ENVELOPESENDER;
	if(get_magic_quotes_gpc())
		$summary = stripslashes($summary);
	$helpemail = getHelpEmail($user['affiliationid']);
	if(! mail($helpemail, "$summary", $message,
	   "From: $from\r\nReply-To: $email\r\n", $mailParams)){
		print "The Server was unable to send mail at this time. Please e-mail ";
		print "<a href=\"mailto:$helpemail\">$helpemail</a> for ";
		print "help with your problem.";
	}
	else {
		print "Your problem report has been submitted.  Thank you for letting ";
		print "us know of your problem so that we can improve this site.<br>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getHelpEmail($affil)
///
/// \param $affil - id or name of an affiliation
///
/// \return email address for $affil or HELPEMAIL from conf.php if $affil does
/// not have a specific email address set
///
/// \brief gets the email address for support for a $affil
///
////////////////////////////////////////////////////////////////////////////////
function getHelpEmail($affil) {
	if(is_numeric($affil))
		$field = 'id';
	else
		$field = 'name';
	$query = "SELECT helpaddress FROM affiliation WHERE $field = '$affil'";
	$qh = doQuery($query);
	if($row = mysql_fetch_assoc($qh))
		if($row['helpaddress'] != '')
			return $row['helpaddress'];
	return HELPEMAIL;
}
?>
