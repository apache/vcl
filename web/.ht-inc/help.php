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
	}
	else {
		$name = $user["firstname"] . " " . $user["lastname"];
		$email = $user["email"];
		$summary = "";
		$text = "";
	}
	if(! in_array('helpform', $noHTMLwrappers))
		print "<H2>VCL Help</H2>\n";
	print "This form sends a request to the VCL support group.  Please provide ";
	print "as much information as possible.<br><br>\n";
	if(! in_array('helpform', $noHTMLwrappers))
		print "Please see our <a href=\"" . HELPFAQURL . "\">";
	else
		print "Please see our <a href=\"http://vcl.ncsu.edu/drupal/?q=faq\">";
	print "FAQ</a> Section before sending your request - it may be an easy ";
	print "fix!<br><br>\n";
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

	if(! ereg('^([A-Za-z]{1,}( )([A-Za-z]){2,})$', $name)) {
		$submitErr |= NAMEERR;
		$submitErrMsg[NAMEERR] = "You must submit your first and last name";
	}
	if(! eregi('^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,3})$',
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
	$requests = getUserRequests("all");
	$query = "SELECT l.start AS start, "
	       .        "l.finalend AS end, "
	       .        "l.computerid AS computerid, "
	       .        "i.prettyname AS prettyimage "
	       . "FROM log l, "
	       .      "image i "
	       . "WHERE l.userid = " . $user["id"] . " AND "
	       .        "i.id = l.imageid AND "
	       .        "(unix_timestamp(NOW()) - unix_timestamp(l.finalend)) < 14400";
	$qh = doQuery($query, 290);
	while($row = mysql_fetch_assoc($qh)) {
		array_push($requests, $row);
	}

	$from = $user["email"];
	if(get_magic_quotes_gpc())
		$text = stripslashes($text);
	$message = "Problem report submitted from VCL web form:\n\n"
	         . "User: " . $user["unityid"] . "\n"
	         . "Name: " . $name . "\n"
	         . "Email: " . $email . "\n"
	         . "Problem description:\n\n$text\n\n";
	$end = time();
	$start = $end - 14400;
	$recentrequests = "";
	foreach($requests as $request) {
		if(datetimeToUnix($request["end"]) > $start ||
		   datetimeToUnix($request["start"] < $end)) {
			$thisstart = str_replace('&nbsp;', ' ', 
			      prettyDatetime($request["start"]));
			$thisend = str_replace('&nbsp;', ' ', 
			      prettyDatetime($request["end"]));
			$recentrequests .= "Image: " . $request["prettyimage"] . "\n"
			   . "Computer: " . $computers[$request["computerid"]]["hostname"] . "\n"
			   . "Start: $thisstart\n"
			   . "End: $thisend\n\n";
		}
	}
	if(! empty($recentrequests)) {
		$message .= "-----------------------------------------------\n";
		$message .= "User's recent reservations:\n\n" . $recentrequests . "\n";
	}
	else {
		$message .= "User has no recent reservations\n";
	}


	$indrupal = getContinuationVar('indrupal', 0);
	if(! $indrupal)
		print "<H2>VCL Help</H2>\n";
	$mailParams = "-f" . ENVELOPESENDER;
	if(! mail(HELPEMAIL, "$summary", $message,
	   "From: $from\r\nReply-To: $email\r\n", $mailParams)){
		print "The Server was unable to send mail at this time. Please e-mail ";
		print "<a href=\"mailto:" . HELPEMAIL . "\">" . HELPEMAIL . "</a> for ";
		print "help with your problem.";
	}
	else {
		print "Your problem report has been submitted.  Thank you for letting ";
		print "us know of your problem so that we can improve this site.<br>\n";
	}
}

?>
