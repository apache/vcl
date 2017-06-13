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
/// \fn getAuthCookieData($loginid, $valid)
///
/// \param $loginid - login id for user
/// \param $valid - (optional, default=600) - time in minutes the cookie
/// should be valid
///
/// \return on failure, an error message; on success, an array with 2 elements:\n
/// data - encrypted payload for auth cookie\n
/// ts - unix timestamp it will expire
///
/// \brief gets user's information and stores it along with their IP address and
/// a timestamp
///
////////////////////////////////////////////////////////////////////////////////
function getAuthCookieData($loginid, $valid=600, $shibauthid=0) {
	global $keys;
	$ts = time() + ($valid * 60);
	$remoteIP = $_SERVER["REMOTE_ADDR"];
	if(empty($remoteIP))
		return "Failed to obtain remote IP address for fixed cookie type";
	if($shibauthid)
		$cdata = "$loginid|$remoteIP|$ts|$shibauthid";
	else
		$cdata = "$loginid|$remoteIP|$ts";

	# 245 characters can be encrypted; anything over that, and
	#   openssl_private_encrypt will fail
	if(! openssl_private_encrypt($cdata, $cryptdata, $keys["private"]))
		return "Failed to encrypt cookie data";

	$cryptdata = base64_encode($cryptdata);

	return array("data" => $cryptdata, "ts" => $ts);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn readAuthCookie()
///
/// \return on success, userid of user in VCLAUTH cookie in user@affil form;
/// NULL on failure
///
/// \brief parses the VCLAUTH cookie to get the contained userid; also checks
/// that the contained remoteIP matches the current remoteIP and that the cookie
/// has not expired
///
////////////////////////////////////////////////////////////////////////////////
function readAuthCookie() {
	global $keys, $AUTHERROR, $shibauthed;
	if(get_magic_quotes_gpc())
		$cookie = stripslashes($_COOKIE["VCLAUTH"]);
	else
		$cookie = $_COOKIE["VCLAUTH"];
	$cookie = base64_decode($cookie);
   if(! openssl_public_decrypt($cookie, $tmp, $keys['public'])) {
      $AUTHERROR["code"] = 3;
      $AUTHERROR["message"] = "Failed to decrypt auth cookie";
      return NULL;
   }

   $tmparr = explode('|', $tmp);
	$loginid = $tmparr[0];
	$remoteIP = $tmparr[1];
	$ts = $tmparr[2];
	if(count($tmparr) > 3) {
		$shibauthed = $tmparr[3];
	
		# check to see if shibauth entry still exists for $shibauthed
		$query = "SELECT ts FROM shibauth WHERE id = $shibauthed";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh)) {
			$shibstart = $row['ts'];
			# TODO if $shibstart is too old, expire the login session
		}
		else {
			# user should have been logged out, log them out now
			setcookie("VCLAUTH", "", time() - 10, "/", COOKIEDOMAIN);
			stopSession();
			dbDisconnect();
			header("Location: " . BASEURL);
			exit;
		}
	}

   if($ts < time()) {
      $AUTHERROR["code"] = 4;
      $AUTHERROR["message"] = "Auth cookie has expired";
      return NULL;
   }
   if($_SERVER["REMOTE_ADDR"] != $remoteIP) {
      //setcookie("ITECSAUTH", "", time() - 10, "/", COOKIEDOMAIN);
      $AUTHERROR["code"] = 4;
      $AUTHERROR["message"] = "remote IP in auth cookie doesn't match user's remote IP";
      return NULL;
   }

   return $loginid;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectAuth()
///
/// \brief prints a page for the user to select the authentication method to use
///
////////////////////////////////////////////////////////////////////////////////
function selectAuth() {
	global $HTMLheader, $printedHTMLheader, $authMechs, $skin;
	$authtype = getContinuationVar('authtype', processInputVar("authtype", ARG_STRING));
	if($authtype == '' && array_key_exists('VCLAUTHSEL', $_COOKIE))
		$authtype = $_COOKIE['VCLAUTHSEL'];
	if(array_key_exists('clearselection', $_GET) && $_GET['clearselection'] == 1) {
		setcookie("VCLAUTHSEL", '', time() - 10, "/", COOKIEDOMAIN);
		$authtype = '';
	}
	if(array_key_exists($authtype, $authMechs)) {
		if(array_key_exists('remsel', $_POST) && $_POST['remsel'] == 1)
			setcookie("VCLAUTHSEL", $authtype, time() + SECINYEAR, "/", COOKIEDOMAIN);
		if($authMechs[$authtype]['type'] == 'redirect') {
			header("Location: {$authMechs[$authtype]['URL']}");
			dbDisconnect();
			exit;
		}
		elseif($authMechs[$authtype]['type'] == 'ldap' ||
		       $authMechs[$authtype]['type'] == 'local') {
			printLoginPageWithSkin($authtype);
			return;
		}
	}
	require_once("themes/$skin/page.php");
	$HTMLheader = getHeader(0);
	print $HTMLheader;
	$printedHTMLheader = 1;
	print "<H2>" . i("Welcome to the Virtual Computing Lab") . "</H2>\n";
	print "<div id=\"loginlayout\">\n";
	print "<div id=\"loginform\">\n";
	print i("Please select an authentication method to use:") . "<br><br>\n";
	if(strlen($authtype))
		print "<font color=red>" . i("Selected method failed, please try again") . "</font><br>\n";
	$methods = array();
	foreach(array_keys($authMechs) as $mech)
		$methods["$mech"] = $mech;
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post name=loginform>\n";
	/*if($skin == 'example1')
		printSelectInput("authtype", $methods, 'EXAMPLE1 LDAP');
	elseif($skin == 'example2')
		printSelectInput("authtype", $methods, 'EXAMPLE2 LDAP');
	else*/
		printSelectInput("authtype", $methods, -1, 0, 0, '', 'tabindex=1');
	print "<br><INPUT type=hidden name=mode value=selectauth>\n";
	print "<input type=checkbox id=remsel name=remsel value=1 tabindex=2>\n";
	print "<label for=remsel>" . i("Remember my selection") . "</label><br>\n";
	print "<INPUT type=submit value=\"" . i("Proceed to Login") . "\" tabindex=3 name=userid>\n";
	print "</FORM>\n";
	print "</div>\n"; # loginform
	print "<div id=\"loginhelp\">\n";
	print "<h3>" . i("Explanation of authentication methods:") . "</h3>\n";
	print "<UL id=expauthul>\n";
	foreach($authMechs as $mech)
		print "<LI>{$mech['help']}</LI>\n";
	print "</UL>\n";
	print "</div>\n"; # loginhelp
	print "</div>\n"; # loginlayout
	print getFooter();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printLoginPageWithSkin($authtype, $servertimeout)
///
/// \param $authtype - and authentication type
/// \param $servertimeout - (optional, default=0) - set to 1 if calling because
/// connection to authentication server timed out, 0 otherwise
///
/// \brief sets up the skin for the page correctly, then calls printLoginPage
///
////////////////////////////////////////////////////////////////////////////////
function printLoginPageWithSkin($authtype, $servertimeout=0) {
	global $authMechs, $HTMLheader, $skin, $printedHTMLheader;
	$skin = getAffiliationTheme($authMechs[$authtype]['affiliationid']);
	require_once("themes/$skin/page.php");
	$HTMLheader = getHeader(0);
	printHTMLHeader();
	print $HTMLheader;
	$printedHTMLheader = 1;
	printLoginPage($servertimeout);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printLoginPage($servertimeout)
///
/// \param $servertimeout - (optional, default=0) - set to 1 if calling because
/// connection to authentication server timed out, 0 otherwise
///
/// \brief prints a page for a user to login
///
////////////////////////////////////////////////////////////////////////////////
function printLoginPage($servertimeout=0) {
	global $authMechs, $skin, $user;
	$user['id'] = 0;
	$authtype = getContinuationVar("authtype", processInputVar("authtype", ARG_STRING));
	if($authtype == '' && array_key_exists('VCLAUTHSEL', $_COOKIE))
		$authtype = $_COOKIE['VCLAUTHSEL'];
	if(isset($_GET['userid']))
		unset($_GET['userid']);
	$userid = processInputVar('userid', ARG_STRING, '');
	if($userid == i('Proceed to Login'))
		$userid = '';
	if(! array_key_exists($authtype, $authMechs)) {
		header("Location: " . BASEURL . SCRIPT);
		dbDisconnect();
		exit;
	}
	if(get_magic_quotes_gpc())
		$userid = stripslashes($userid);
	$userid = htmlspecialchars($userid);
	$extrafailedmsg = '';
	if($servertimeout)
		$extrafailedmsg = " " . i("(unable to connect to authentication server)");
	/*if($skin == 'example1') {
		$useridLabel = 'Pirateid';
		$passLabel = 'Passphrase';
		$text1 = 'Login with your Pirate ID';
		$text2 = "";
	}
	elseif($skin == 'example2') {
		print "<br>";
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post name=loginform>\n";
		if(strlen($userid))
			print "<font color=red>Login failed $extrafailedmsg</font>\n";
		print "<TABLE width=\"250\">\n";
		print "  <TR>\n";
		print "    <TH align=right>Key Account:</TH>\n";
		print "    <TD><INPUT type=text name=userid value=\"\"></TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Password:</TH>\n";
		print "    <TD><INPUT type=password name=password></TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TD colspan=2 align=right><INPUT type=submit value=Login class=button></TD>\n";
		print "  </TR>\n";
		print "</TABLE>\n";
		print "<div width=250 align=center>\n";
		print "<p>\n";
		$cdata = array('authtype' => $authtype);
		$cont = addContinuationsEntry('submitLogin', $cdata);
		print "  <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "  <br>\n";
		print "  </p>\n";
		print "</div>\n";
		print "</FORM>\n";
		print getFooter();
		return;
	}
	else {*/
		$useridLabel = i('Userid');
		$passLabel = i('Password');
		$text1 = i("Login with") . " $authtype";
		$text2 = "";
	#}
	print "<div id=\"loginbox\">\n";
	print "<H2 style=\"display: block\">$text1</H2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post name=loginform>\n";
	if(strlen($userid))
		print "<font color=red>" . i("Login failed") . " $extrafailedmsg</font>\n";
	print "<TABLE id=\"loginlayout\">\n";
	print "  <TR>\n";
	print "    <TH align=right>$useridLabel:</TH>\n";
	print "    <TD><INPUT type=text name=userid value=\"$userid\"></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>$passLabel:</TH>\n";
	print "    <TD><INPUT type=password name=password></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD colspan=2 align=right><INPUT type=submit value=\"" . i("Login") . "\"></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD colspan=2 align=center><br><br><small>";
	print "<a href=\"" . BASEURL . SCRIPT . "?mode=selectauth&clearselection=1\">";
	print i("Select a different authentication method") . "</a></small></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<input type=\"hidden\" name=\"mode\" value=\"submitLogin\">\n";
	print "<input type=\"hidden\" name=\"authtype\" value=\"$authtype\">\n";
	print "</FORM>\n";
	print "$text2<br>\n";
	print "</div>\n";
	print getFooter();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitLogin()
///
/// \brief processes a login page submission
///
////////////////////////////////////////////////////////////////////////////////
function submitLogin() {
	global $authMechs;
	$authtype = getContinuationVar("authtype", processInputVar('authtype', ARG_STRING));
	if(! array_key_exists($authtype, $authMechs)) {
		// FIXME - hackerish
		dbDisconnect();
		exit;
	}
	if(isset($_GET['userid']))
		unset($_GET['userid']);
	$userid = processInputVar('userid', ARG_STRING, '');
	$passwd = $_POST['password'];
	if(empty($userid) || empty($passwd)) {
		selectAuth();
		return;
	}
	if(get_magic_quotes_gpc()) {
		$userid = stripslashes($userid);
		$passwd = stripslashes($passwd);
	}
	if($authMechs[$authtype]['type'] == 'ldap')
		ldapLogin($authtype, $userid, $passwd);
	elseif($authMechs[$authtype]['type'] == 'local')
		localLogin($userid, $passwd, $authtype);
	else
		selectAuth();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn ldapLogin($authtype, $userid, $passwd)
///
/// \param $authtype - index from $authMechs array
/// \param $userid - userid without affiliation
/// \param $passwd - submitted password
///
/// \brief tries to authenticate user via ldap; calls printLoginPageWithSkin if
/// authentication fails
///
////////////////////////////////////////////////////////////////////////////////
function ldapLogin($authtype, $userid, $passwd) {
	global $HTMLheader, $printedHTMLheader, $authMechs, $phpVer;
	$esc_userid = mysql_real_escape_string($userid);
	if(! $fh = fsockopen($authMechs[$authtype]['server'], 636, $errno, $errstr, 5)) {
		printLoginPageWithSkin($authtype, 1);
		return;
	}
	fclose($fh);
	$ds = ldap_connect("ldaps://{$authMechs[$authtype]['server']}/");
	if(! $ds) {
		addLoginLog($userid, $authtype, $authMechs[$authtype]['affiliationid'], 0);
		print $HTMLheader;
		$printedHTMLheader = 1;
		selectAuth();
		return;
	}
	ldap_set_option($ds, LDAP_OPT_PROTOCOL_VERSION, 3);
	ldap_set_option($ds, LDAP_OPT_REFERRALS, 0);
	if(array_key_exists('lookupuserbeforeauth', $authMechs[$authtype]) &&
	   $authMechs[$authtype]['lookupuserbeforeauth'] &&
	   array_key_exists('lookupuserfield', $authMechs[$authtype])) {
		# in this case, we have to look up what part of the tree the user is in
		#   before we can actually look up the user
		$auth = $authMechs[$authtype];
		if(array_key_exists('masterlogin', $auth) && strlen($auth['masterlogin']))
			$res = ldap_bind($ds, $auth['masterlogin'], $auth['masterpwd']);
		else
			$res = ldap_bind($ds);
		if(! $res) {
			addLoginLog($userid, $authtype, $auth['affiliationid'], 0);
			printLoginPageWithSkin($authtype);
			return;
		}
		$search = ldap_search($ds,
		                      $auth['binddn'], 
		                      "{$auth['lookupuserfield']}=$userid",
		                      array('dn'), 0, 3, 15);
		if($search) {
			$tmpdata = ldap_get_entries($ds, $search);
			if(! $tmpdata['count'] || ! array_key_exists('dn', $tmpdata[0])) {
				addLoginLog($userid, $authtype, $auth['affiliationid'], 0);
				printLoginPageWithSkin($authtype);
				return;
			}
			$ldapuser = $tmpdata[0]['dn'];
		}
		else {
			addLoginLog($userid, $authtype, $auth['affiliationid'], 0);
			printLoginPageWithSkin($authtype);
			return;
		}
	}
	else
		$ldapuser = sprintf($authMechs[$authtype]['userid'], $userid);
	$res = ldap_bind($ds, $ldapuser, $passwd);
	if(! $res) {
		// login failed
		$err = ldap_error($ds);
		if($err == 'Invalid credentials')
			addLoginLog($userid, $authtype, $authMechs[$authtype]['affiliationid'], 0, $err);
		else
			addLoginLog($userid, $authtype, $authMechs[$authtype]['affiliationid'], 0);
		printLoginPageWithSkin($authtype);
		return;
	}
	else {
		addLoginLog($userid, $authtype, $authMechs[$authtype]['affiliationid'], 1);
		# used to rely on later code to update user info if update timestamp was expired
		// see if user in our db
		/*$query = "SELECT id "
		       . "FROM user "
		       . "WHERE unityid = '$esc_userid' AND "
		       .       "affiliationid = {$authMechs[$authtype]['affiliationid']}";
		$qh = doQuery($query, 101);
		if(! mysql_num_rows($qh)) {
			// if not, add user
			$newid = updateLDAPUser($authtype, $userid);
			if(is_null($newid))
				abort(8);
		}*/
		# now, we always update the user info
		$newid = updateLDAPUser($authtype, $userid);
		if(is_null($newid))
			abort(8);
		// get cookie data
		$cookie = getAuthCookieData("$userid@" . getAffiliationName($authMechs[$authtype]['affiliationid']));
		// set cookie
		if(version_compare(PHP_VERSION, "5.2", ">=") == true)
			setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN, 0, 1);
		else
			setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN, 0);
		# set skin cookie based on affiliation
		$skin = getAffiliationTheme($authMechs[$authtype]['affiliationid']);
		$ucskin = strtoupper($skin);
		setcookie("VCLSKIN", "$ucskin", (time() + (SECINDAY * 31)), "/", COOKIEDOMAIN);
		// redirect to main page
		header("Location: " . BASEURL . SCRIPT);
		dbDisconnect();
		exit;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn localLogin($userid, $passwd, $authtype)
///
/// \param $userid - userid without affiliation
/// \param $passwd - submitted password
/// \param $authtype - key from $authMechs array submitted to calling function
///
/// \brief tries to authenticate user locally; calls printLoginPageWithSkin if
/// authentication fails
///
////////////////////////////////////////////////////////////////////////////////
function localLogin($userid, $passwd, $authtype) {
	global $HTMLheader, $phpVer, $authMechs;
	if(validateLocalAccount($userid, $passwd)) {
		addLoginLog($userid, $authtype, $authMechs[$authtype]['affiliationid'], 1);
		//set cookie
		$cookie = getAuthCookieData("$userid@local");
		if(version_compare(PHP_VERSION, "5.2", ">=") == true)
			setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN, 0, 1);
		else
			setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN);
		//load main page
		$theme = getAffiliationTheme($authMechs[$authtype]['affiliationid']);
		setcookie("VCLSKIN", $theme, (time() + (SECINDAY * 31)), "/", COOKIEDOMAIN);
		header("Location: " . BASEURL . SCRIPT);
		dbDisconnect();
		exit;
	}
	else {
		addLoginLog($userid, $authtype, $authMechs[$authtype]['affiliationid'], 0);
		printLoginPageWithSkin($authtype);
		printHTMLFooter();
		dbDisconnect();
		exit;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn validateLocalAccount($user, $pass)
///
/// \param $user - unityid from user table
/// \param $pass - user's password
///
/// \return 1 if account exists in localauth table, 0 if it does not
///
/// \brief checks to see if $user has an entry in the localauth table
///
////////////////////////////////////////////////////////////////////////////////
function validateLocalAccount($user, $pass) {
	$user = mysql_real_escape_string($user);
	$query = "SELECT l.salt "
	       . "FROM localauth l, "
	       .      "user u, "
	       .      "affiliation a "
	       . "WHERE u.unityid = '$user' AND "
	       .       "u.affiliationid = a.id AND "
	       .       "a.name = 'Local' AND "
	       .       "l.userid = u.id";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh) != 1 ||
	   (! ($row = mysql_fetch_assoc($qh))))
		return 0;

	$passhash = sha1("$pass{$row['salt']}");
	$query = "SELECT u.id "
	       . "FROM user u, "
	       .      "localauth l, "
	       .      "affiliation a "
	       . "WHERE u.unityid = '$user' AND "
	       .       "l.userid = u.id AND "
	       .       "l.passhash = '$passhash' AND "
	       .       "u.affiliationid = a.id AND "
	       .       "a.name = 'Local'";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh) == 1)
		return 1;
	else
		return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addLoginLog($login, $mech, $affiliationid, $passfail, $code)
///
/// \param $login - user id entered in login screen
/// \param $mech - authentication mechanism used
/// \param $affiliationid - affiliation id of authentication mechanism
/// \param $passfail - 1 for successful login, 0 for failed login
/// \param $code - (optional, default='none') additional code to save
///
/// \brief adds an entry to the loginlog table
///
////////////////////////////////////////////////////////////////////////////////
function addLoginLog($login, $mech, $affiliationid, $passfail, $code='none') {
	$login = mysql_real_escape_string($login);
	$mech = mysql_real_escape_string($mech);
	$query = "INSERT INTO loginlog "
	       .        "(user, "
	       .        "authmech, "
	       .        "affiliationid, "
	       .        "passfail, "
	       .        "remoteIP, "
	       .        "code) "
	       . "VALUES "
	       .        "('$login', "
	       .        "'$mech', "
	       .        "$affiliationid, "
	       .        "$passfail, "
	       .        "'{$_SERVER['REMOTE_ADDR']}', "
	       .        "'$code')";
	doQuery($query, 101);
	if($passfail == 1)
		checkMissingWebSecretKeys();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkExpiredDemoUser($userid, $groups)
///
/// \param $userid - id from user table
/// \param $groups - (optional) array of user's groups as returned by
/// getUsersGroups
///
/// \brief checks to see if user is only in demo group and if so check to see
/// if it has been 3 days since start of first reservation or if user has made
/// 3 reservations; if so, moves user to nodemo group
///
////////////////////////////////////////////////////////////////////////////////
function checkExpiredDemoUser($userid, $groups=0) {
	global $mode, $skin, $noHTMLwrappers;
	if($groups == 0)
		$groups = getUsersGroups($userid, 1);

	if(count($groups) != 1)
		return;

	$tmp = array_values($groups);
	if($tmp[0] != 'demo')
		return;

	$query = "SELECT start "
	       . "FROM log "
	       . "WHERE userid = $userid "
	       .   "AND finalend < NOW() "
	       . "ORDER BY start "
	       . "LIMIT 3";
	$qh = doQuery($query, 101);
	$expire = time() - (SECINDAY * 3);
	$rows = mysql_num_rows($qh);
	if($row = mysql_fetch_assoc($qh)) {
		if($rows >= 3 || datetimeToUnix($row['start']) < $expire) {
			if(in_array($mode, $noHTMLwrappers))
				# do a redirect and handle removal on next page load so user can
				#   be notified - doesn't always work, but handles a few extra
				#   cases
				header("Location: " . BASEURL . SCRIPT);
			else {
				$nodemoid = getUserGroupID('nodemo', getAffiliationID('ITECS'));
				$query = "DELETE FROM usergroupmembers "  # have to do the delete here
				       . "WHERE userid = $userid";        # because updateGroups doesn't
				                                          # delete from custom groups
				doQuery($query, 101);
				updateGroups(array($nodemoid), $userid);
				checkUpdateServerRequestGroups($groupid);
				if(empty($skin)) {
					$skin = getAffiliationTheme(0);
					require_once("themes/$skin/page.php");
				}
				$mode = 'expiredemouser';
				printHTMLHeader();
				print "<h2>Account Expired</h2>\n";
				print "The account you are using is a demo account that has now expired. ";
				print "You cannot make any more reservations. Please contact <a href=\"";
				print "mailto:" . HELPEMAIL . "\">" . HELPEMAIL . "</a> if you need ";
				print "further access to VCL.<br>\n";
			}
			cleanSemaphore(); # probably not needed but ensures we do not leave stale entries
			printHTMLFooter();
			dbDisconnect();
			exit;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn testGeneralAffiliation(&$login, &$affilid)
///
/// \param $login - (pass by ref) a login id with affiliation
/// \param $affilid - (pass by ref) gets overwritten
///
/// \return - 1 if successfully found known affiliation id in $login, 0 if
/// failed, -1 if found an unknown affilation in $login
///
/// \brief changes $login to be without affiliation and sticks the associated
/// affiliation id in $affilid
///
////////////////////////////////////////////////////////////////////////////////
function testGeneralAffiliation(&$login, &$affilid) {
	if(preg_match('/^([^@]+)@([^@\.]*)$/', $login, $matches)) {
		$login = $matches[1];
		$affilid = getAffiliationID($matches[2]);
		if(is_null($affilid))
			return -1;
		return 1;
	}
	return 0;
}

?>
