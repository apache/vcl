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

require_once(".ht-inc/secrets.php");
@include_once("itecsauth/itecsauth.php");
require_once(".ht-inc/authentication.php");
if(file_exists(".ht-inc/vcldocs.php"))
	require_once(".ht-inc/vcldocs.php");

/**
 * \file
 */

/// used for processInputVar, means the input variable should be numeric
define("ARG_NUMERIC", 1);
/// used for processInputVar, means the input variable should be a string
define("ARG_STRING", 1 << 1);
/// used for processInputVar, means the input variable should be an array of numbers
define("ARG_MULTINUMERIC", 1 << 2);
/// used for processInputVar, means the input variable should be an array of strings
define("ARG_MULTISTRING", 1 << 3);
/// define adminlevel developer
define("ADMIN_DEVELOPER", 3);
/// define adminlevel full
define("ADMIN_FULL", 2);
/// define adminlevel none
define("ADMIN_NONE", 1);
/// define semaphore key
define("SEMKEY", 192365819256598);


/// global array used to hold request information between calling isAvailable
/// and addRequest
$requestInfo = array();
#$requestInfo["freeComputerids"] = array();
#$requestInfo["imageids"] = array();

/// global array to cache arrays of node parents for getNodeParents
$nodeparents = array();
/// global array to cache arrays of node children for getNodeChildren
$nodechildren = array();
/// global variable to store what needs to be printed in printHTMLHeader
$HTMLheader = "";
/// global variable to store if header has been printed
$printedHTMLheader = 0;

////////////////////////////////////////////////////////////////////////////////
///
/// \fn initGlobals()
///
/// \brief this is where globals get initialized
///
////////////////////////////////////////////////////////////////////////////////
function initGlobals() {
	global $mode, $user, $remoteIP, $authed, $oldmode, $viewmode, $semid;
	global $semislocked, $days, $phpVer, $keys, $pemkey, $AUTHERROR;
	global $passwdArray, $skin, $contdata, $lastmode, $inContinuation;
	global $totalQueries, $ERRORS, $queryTimes, $actions;

	define("SECINDAY", 86400);
	define("SECINWEEK", 604800);
	define("SECINMONTH", 2678400);
	define("SECINYEAR", 31536000);
	$mode = processInputVar("mode", ARG_STRING, 'main');
	$totalQueries = 0;
	$inContinuation = 0;
	$contdata = array();
	$queryTimes = array();
	$contuserid = '';
	$continuation = processInputVar('continuation', ARG_STRING);
	if(! empty($continuation)) {
		# TODO handle AJ errors
		$tmp = getContinuationsData($continuation);
		if(empty($tmp))
			abort(11);
		elseif(array_key_exists('error', $tmp)) {
			$mode = "continuationsError";
			$contdata = $tmp;
		}
		else {
			$inContinuation = 1;
			$contuserid = $tmp['userid'];
			$lastmode = $tmp['frommode'];
			$mode = $tmp['nextmode'];
			$contdata = $tmp['data'];
		}
	}
	$submitErr = 0;
	$submitErrMsg = array();
	$remoteIP = $_SERVER["REMOTE_ADDR"];
	$days = array('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
	$phpVerArr = explode('.', phpversion());
	$phpVer = $phpVerArr[0];
	if($phpVer == 5)
		require_once(".ht-inc/php5extras.php");

	$passwdArray = array('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
	                     'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
	                     'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g',
	                     'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r',
	                     's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '1', '2', '3',
	                     '4', '5', '6', '7', '8', '9', '0');

	if(array_key_exists('VCLAUTH', $_COOKIE) || $mode == 'submitLogin') {
		// open keys
		$fp = fopen(".ht-inc/keys.pem", "r");
		$key = fread($fp, 8192);
		fclose($fp);
		$keys["private"] = openssl_pkey_get_private($key, $pemkey);
		if(! $keys['private'])
			abort(6);
		$fp = fopen(".ht-inc/pubkey.pem", "r");
		$key = fread($fp, 8192);
		fclose($fp);
		$keys["public"] = openssl_pkey_get_public($key);
		if(! $keys['public'])
			abort(7);
	}

	# USING A SINGLE USER WITHOUT LOGGING IN:
	# to automatically log in to vcl with the same user
	# every time, comment out from this comment block to
	# the 'end auth check' comment, then, right after
	# that, set $authed = 1 and $userid to the id from
	# the user table corresponding to the user you want
	# logged in

	$authed = 0;
	# check for being logged in to WRAP or ITECSAUTH
	if/*(array_key_exists("WRAP_AFFIL", $_SERVER) && 
	   $_SERVER["WRAP_AFFIL"] == "ncsu.edu" &&
	   $_SERVER['WRAP_USERID'] != 'Guest') {
		$authed = 1;
		$userid = "{$_SERVER["WRAP_USERID"]}@NCSU";
	}
	elseif(array_key_exists("ITECSAUTH", $_COOKIE)) {
		$authdata = authUser();
		if(! ($error = getAuthError())) {
			$authed = 1;
			$userid = "{$authdata["email"]}@ITECS";
		}
	}
	elseif*/(array_key_exists("VCLAUTH", $_COOKIE)) {
		$userid = readAuthCookie();
		if(! is_null($userid))
			$authed = 1;
	}
	elseif(preg_match('/_shibsession/', join(',', array_keys($_COOKIE)))) {
		# redirect to shibauth directory
		header('Location: ' . BASEURL . "/shibauth/");
		dbDisconnect();
		exit;
	}
	# end auth check

	if($authed && $mode == 'selectauth')
		$mode = 'home';

	if(! $authed) {
		# set $skin based on cookie (so it gets set before user logs in
		#   later, we set it by affiliation (helps with 'view as user')
		if(preg_match('/^152\.9\./', $_SERVER['REMOTE_ADDR']) ||
			(array_key_exists('VCLSKIN', $_COOKIE) && $_COOKIE['VCLSKIN'] == 'EXAMPLE1')) {
			$skin = 'example1';
		}
		elseif(array_key_exists('VCLSKIN', $_COOKIE)) {
			switch($_COOKIE['VCLSKIN']) {
				case 'EXAMPLE2':
					$skin = 'example2';
					break;
				default:
					$skin = 'default';
					break;
			}
		}
		else
			$skin = 'default';
		if($mode != 'selectauth' && $mode != 'submitLogin')
			require_once("themes/$skin/page.php");

		require_once(".ht-inc/requests.php");
		if($mode != "logout" &&
			$mode != "shiblogout" &&
			$mode != "vcldquery" &&
			$mode != "xmlrpccall" &&
			$mode != "xmlrpcaffiliations" &&
			$mode != "selectauth" &&
			$mode != "submitLogin") {
			$oldmode = $mode;
			$mode = "auth";
		}
		if($mode == "vcldquery" || $mode == 'xmlrpccall' || $mode == 'xmlrpcaffiliations') {
			// get the semaphore id
			if(! ($semid = sem_get(SEMKEY, 1, 0666, 1)))
				abort(2);
			$semislocked = 0;
			require_once(".ht-inc/xmlrpcWrappers.php");
			require_once(".ht-inc/requests.php");
			setupSession();
		}
		return;
	}
	setupSession();
	if(array_key_exists('user', $_SESSION)) {
		$user = $_SESSION['user'];
		if(! empty($contuserid) &&
		   $user['id'] != $contuserid)
			abort(51);
	}
	else {
		# get info about user
		if(! $user = getUserInfo($userid)) {
			$ERRORS[1] = "Failed to get user info from database.  userid was $userid";
			abort(1);
		}
		if($user['adminlevel'] == 'developer' &&
			array_key_exists('VCLTESTUSER', $_COOKIE)) {
			$userid = $_COOKIE['VCLTESTUSER'];
			if($userid != "{$user['unityid']}@{$user['affiliation']}") {
				if($testuser = getUserInfo($userid))
					$user = $testuser;
			}
		}
		if(! empty($contuserid) &&
		   $user['id'] != $contuserid)
			abort(51);
		$_SESSION['user'] = $user;
	}
	$viewmode = getViewMode($user);

	$affil = $user['affiliation'];

	# setskin
	switch($affil) {
		case 'EXAMPLE1':
			$skin = 'example1';
			require_once('themes/example1/page.php');
			break;

		case 'EXAMPLE2':
			$skin = 'example1';
			require_once('themes/example2/page.php');
			break;

		default:
			$skin = 'default';
			require_once('themes/default/page.php');
			break;

	}
	$_SESSION['mode'] = $mode;

	// check for and possibly clear dirty permission cache
	$dontClearModes = array('AJchangeUserPrivs', 'AJchangeUserGroupPrivs', 'AJchangeResourcePrivs');
	if(! in_array($mode, $dontClearModes) &&
	   array_key_exists('dirtyprivs', $_SESSION) &&
	   $_SESSION['dirtyprivs']) {
		clearPrivCache();
		$_SESSION['dirtyprivs'] = 0;
	}

	// get the semaphore id
	if(! ($semid = sem_get(SEMKEY, 1, 0666, 1)))
		abort(2);
	$semislocked = 0;

	# include appropriate files
	switch($actions['pages'][$mode]) {
		case 'manageComputers':
			require_once(".ht-inc/computers.php");
			break;
		case 'managementNodes':
			require_once(".ht-inc/managementnodes.php");
			break;
		case 'manageImages':
			require_once(".ht-inc/images.php");
			require_once(".ht-inc/requests.php");
			break;
		case 'manageSchedules':
			require_once(".ht-inc/schedules.php");
			break;
		case 'help':
			require_once(".ht-inc/help.php");
			break;
		case 'userPreferences':
			require_once(".ht-inc/userpreferences.php");
			break;
		case 'statistics':
			require_once(".ht-inc/statistics.php");
			break;
		case 'manageGroups':
			require_once(".ht-inc/groups.php");
			break;
		case 'privileges':
		case 'userLookup':
			require_once(".ht-inc/privileges.php");
			break;
		case 'vm':
			require_once(".ht-inc/vm.php");
			break;
		default:
			require_once(".ht-inc/requests.php");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkAccess()
///
/// \brief gets the user's access level to the locker from the ptsowner_admin
/// table
///
////////////////////////////////////////////////////////////////////////////////
function checkAccess() {
	global $mode, $user, $viewmode, $actionFunction, $vcldquerykey, $authMechs;
	global $itecsauthkey, $ENABLE_ITECSAUTH, $actions, $noHTMLwrappers;
	global $inContinuation, $docreaders, $userlookupUsers;
	if($mode == "vcldquery") {
		$key = processInputVar("key", ARG_STRING);
		if($key != $vcldquerykey) {
			print "Access denied\n";
			dbDisconnect();
			exit;
		}
	}
	elseif($mode == 'xmlrpccall') {
		// double check for SSL
		if(! isset($_SERVER['HTTPS']) || $_SERVER['HTTPS'] != "on") {
			printXMLRPCerror(4);   # must have SSL enabled
			dbDisconnect();
			exit;
		}
		$xmluser = processInputData($_SERVER['HTTP_X_USER'], ARG_STRING, 1);
		if(! $user = getUserInfo($xmluser)) {
			printXMLRPCerror(3);   # access denied
			dbDisconnect();
			exit;
		}
		$xmlpass = processInputData($_SERVER['HTTP_X_PASS'], ARG_STRING, 1);
		$apiver = processInputData($_SERVER['HTTP_X_APIVERSION'], ARG_NUMERIC, 1);
		if($apiver == 1) {
			$query = "SELECT x.id "
			       . "FROM xmlrpcKey x, "
			       .      "user u "
			       . "WHERE x.ownerid = u.id AND "
			       .       "u.unityid = '$xmluser' AND "
			       .       "x.key = '$xmlpass' AND "
			       .       "x.active = 1";
			$qh = doQuery($query, 101);
			if(! (mysql_num_rows($qh) == 1)) {
				printXMLRPCerror(3);   # access denied
				dbDisconnect();
				exit;
			}
			$row = mysql_fetch_assoc($qh);
			$user['xmlrpckeyid'] = $row['id'];
		}
		elseif($apiver == 2) {
			$authtype = "";
			foreach($authMechs as $key => $authmech) {
				/*if($key == "NCSU WRAP")
					continue;*/
				if($authmech['affiliationid'] == $user['affiliationid']) {
					$authtype = $key;
					break;
				}
			}
			/*if(empty($authtype)) {
				print "No authentication mechanism found for passed in X-User";
				dbDisconnect();
				exit;
			}*/
			if($authMechs[$authtype]['type'] == 'ldap') {
				$ds = ldap_connect("ldaps://{$authMechs[$authtype]['server']}/");
				if(! $ds) {
					printXMLRPCerror(5);    # failed to connect to auth server
					dbDisconnect();
					exit;
				}
				ldap_set_option($ds, LDAP_OPT_PROTOCOL_VERSION, 3);
				ldap_set_option($ds, LDAP_OPT_REFERRALS, 0);
				$ldapuser = sprintf($authMechs[$authtype]['userid'], $user['unityid']);
				$res = ldap_bind($ds, $ldapuser, $xmlpass);
				if(! $res) {
					printXMLRPCerror(3);   # access denied
					dbDisconnect();
					exit;
				}
			}
			elseif($ENABLE_ITECSAUTH &&
			   $authMechs[$authtype]['affiliationid'] == getAffiliationID('ITECS')) {
				$rc = ITECSAUTH_validateUser($itecsauthkey, $user['unityid'], $xmlpass);
				if(empty($rc) || $rc['passfail'] == 'fail') {
					printXMLRPCerror(3);   # access denied
					dbDisconnect();
					exit;
				}
			}
			elseif($authMechs[$authtype]['type'] == 'local') {
				if(! validateLocalAccount($user['unityid'], $xmlpass)) {
					printXMLRPCerror(3);   # access denied
					dbDisconnect();
					exit;
				}
			}
			else {
				printXMLRPCerror(6);    # unable to auth passed in X-User
				dbDisconnect();
				exit;
			}
		}
		else {
			printXMLRPCerror(7);    # unknown API version
			dbDisconnect();
			exit;
		}
	}
	elseif($mode == 'xmlrpcaffiliations') {
		// double check for SSL, not really required for this mode, but it keeps things consistant
		if(! isset($_SERVER['HTTPS']) || $_SERVER['HTTPS'] != "on") {
			printXMLRPCerror(4);   # must have SSL enabled
			dbDisconnect();
			exit;
		}
		$apiver = processInputData($_SERVER['HTTP_X_APIVERSION'], ARG_NUMERIC, 1);
		if($apiver != 1 && $apiver != 2) {
			printXMLRPCerror(7);    # unknown API version
			dbDisconnect();
			exit;
		}
	}
	# this protects against an attacker submitting data without coming from
	# our index.php page
	elseif(! empty($mode)) {
		/*if(empty($_SERVER["HTTP_REFERER"])) {
			# when firefox auto-reloads a page, it doesn't set HTTP_REFERER
			# since we are auto-reloading the 'Current Reservations' page if
			# there is a pending request, we can't abort
			if(in_array($mode, $actions['entry']) ||
			   $mode == "viewRequests" ||
			   $mode == "statgraphday" ||
			   $mode == "statgraphdayconcuruser" ||
			   $mode == "statgraphdayconcurblade" ||
			   $mode == "statgraphhour" ||
			   $mode == "selectauth" ||
			   $mode == "selectNode" ||
			   $mode == "AJsubmitAddUserPriv" ||
				$mode == "AJsubmitAddUserGroupPriv" ||
			   $mode == "AJchangeUserPrivs" ||
			   $mode == "AJchangeUserGroupPrivs" ||
			   $mode == "AJsubmitAddChildNode" ||
			   $mode == "AJsubmitDeleteNode" ||
			   $mode == "AJupdateWaitTime" ||
			   $mode == "clearCache" ||
			   $mode == "jsonImageInformation" ||
			   $mode == "helpform" ||
			   $mode == "auth") {
				return;
			}
			$mode = "";
			$actionFunction = "main";
			#$user["adminlevel"] = "none";
			#$viewmode = ADMIN_NONE;
			#abort(20);
			return;
		}
		$urlArray = explode('?', $_SERVER["HTTP_REFERER"]);
		#print "urlArray[0] - " . $urlArray[0] . "<BR>\n";
		#print "correct URL - " . BASEURL . "/<br>\n";
		if(($urlArray[0] != BASEURL . SCRIPT) &&
		   ($urlArray[0] != BASEURL . "/") &&
		   ($urlArray[0] != "https://webauth.ncsu.edu/wrap-bin/was16.cgi") &&
		   ($urlArray[0] != "http://vcl.ncsu.edu/index.php") &&
		   ($urlArray[0] != "http://vcl.ncsu.edu/") &&
		   ($urlArray[0] != "http://vcl.ncsu.edu/site/pages/help/vcl-help" &&
		   $urlArray[0] != "http://vcl.ncsu.edu/site/pages/help/default" &&
		   $urlArray[0] != "http://vcl.ncsu.edu/site/pages/default/default" &&
		   $urlArray[0] != "http://vcl.ncsu.edu/site.php" &&
		   $urlArray[0] != "http://vcl.ncsu.edu/site" &&
		   $urlArray[0] != "https://vcl.ncsu.edu/" &&
		   $urlArray[0] != "https://vcl.ncsu.edu/email-vcl-help-support" &&
		   $urlArray[0] != "http://vcl.ncsu.edu/email-vcl-help-support" &&
		   $mode == "helpform") &&
		   (($urlArray[0] != "http://vcl.ncsu.edu/site" &&
		   $urlArray[0] != "http://vcl.ncsu.edu/site/pages/default/default" &&
		   $urlArray[0] != "http://vcl.ncsu.edu/site/index/default") ||
		   $mode != "viewRequests")) {*/
		if(! in_array($mode, $actions['entry']) &&
		   ! $inContinuation) {
			$mode = "main";
			$actionFunction = "main";
			return;
			#$user["adminlevel"] = "none";
			#$viewmode = ADMIN_NONE;
			#abort(20);
	   }
		else {
			if(! $inContinuation) {
				# check that user has access to this area
				switch($mode) {
					case 'viewRequests':
						if(! in_array("imageCheckOut", $user["privileges"]) &&
							! in_array("imageAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'blockRequest':
						if($viewmode != ADMIN_DEVELOPER) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'viewGroups':
						if(! in_array("groupAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'selectImageOption':
						if(! in_array("imageAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'viewSchedules':
						if(! in_array("scheduleAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'selectComputers':
						if(! in_array("computerAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'selectMgmtnodeOption':
						if(! in_array("mgmtNodeAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'pickTimeTable':
						$computermetadata = getUserComputerMetaData();
						if(! count($computermetadata["platforms"]) ||
						   ! count($computermetadata["schedules"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'viewNodes':
						if(! in_array("userGrant", $user["privileges"]) &&
						   ! in_array("resourceGrant", $user["privileges"]) &&
						   ! in_array("nodeAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'userLookup':
						if($viewmode != ADMIN_DEVELOPER &&
						   ! in_array($user['id'], $userlookupUsers)) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'editVMInfo':
						if(! in_array("computerAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'viewdocs':
						if(! in_array("userGrant", $user["privileges"]) &&
						   ! in_array("resourceGrant", $user["privileges"]) &&
						   ! in_array("nodeAdmin", $user["privileges"]) &&
						   ! in_array($user['id'], $docreaders)) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
				}
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn clearPrivCache()
///
/// \brief sets userresources, nodeprivileges, cascadenodeprivileges, and
/// userhaspriv keys of $_SESSION array to empty arrays
///
////////////////////////////////////////////////////////////////////////////////
function clearPrivCache() {
	$_SESSION['userresources'] = array();
	$_SESSION['nodeprivileges'] = array();
	$_SESSION['cascadenodeprivileges'] = array();
	$_SESSION['userhaspriv'] = array();
	$_SESSION['compstateflow'] = array();
	$_SESSION['usersessiondata'] = array();
	unset($_SESSION['user']);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJclearPermCache()
///
/// \brief ajax wrapper for clearPrivCache
///
////////////////////////////////////////////////////////////////////////////////
function AJclearPermCache() {
	clearPrivCache();
	print "alert('Permission cache cleared');";
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn setupSession()
///
/// \brief starts php session and initializes useful variables
///
////////////////////////////////////////////////////////////////////////////////
function setupSession() {
	global $mode;
	if($mode == 'xmlrpccall')
		$_SESSION = array();
	else
		session_start();
	if(! array_key_exists('cachetimestamp', $_SESSION))
		$_SESSION['cachetimestamp'] = time();
	else {
		if(($_SESSION['cachetimestamp'] + (PRIV_CACHE_TIMEOUT * 60)) < time()) {
			clearPrivCache();
			$_SESSION['cachetimestamp'] = time();
			return;
		}
	}
	if(! array_key_exists('userresources', $_SESSION))
		$_SESSION['userresources'] = array();
	if(! array_key_exists('nodeprivileges', $_SESSION))
		$_SESSION['nodeprivileges'] = array();
	if(! array_key_exists('cascadenodeprivileges', $_SESSION))
		$_SESSION['cascadenodeprivileges'] = array();
	if(! array_key_exists('userhaspriv', $_SESSION))
		$_SESSION['userhaspriv'] = array();
	if(! array_key_exists('compstateflow', $_SESSION))
		$_SESSION['compstateflow'] = array();
	if(! array_key_exists('usersessiondata', $_SESSION))
		$_SESSION['usersessiondata'] = array();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn stopSession()
///
/// \brief ends the user's session and prints info to notify the user
///
////////////////////////////////////////////////////////////////////////////////
function stopSession() {
	$_SESSION = array();
	if(isset($_COOKIE[session_name()]))
		setcookie(session_name(), "", time()-42000, '/');
	session_destroy();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getViewMode($user)
///
/// \param $user - an array as returned from getUserInfo
///
/// \return user's viewmode level
///
/// \brief determines viewmode based on $_COOKIE["VCLVIEWMODE"] and user's
/// adminlevel
///
////////////////////////////////////////////////////////////////////////////////
function getViewMode($user) {
	if($user["adminlevelid"] == 1) {
		return 1;
	}
	if(empty($_COOKIE["VCLVIEWMODE"])) {
		return $user["adminlevelid"];
	}
	$tmpviewmode = $_COOKIE["VCLVIEWMODE"];
	if($user["adminlevel"] == "developer") {
		return $tmpviewmode;
	}
	elseif($user["adminlevel"] == "full") {
		if($tmpviewmode <= ADMIN_FULL) {
			return $tmpviewmode;
		}
		else {
			return ADMIN_FULL;
		}
	}
	return 1;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn main()
///
/// \brief prints a welcome screen
///
////////////////////////////////////////////////////////////////////////////////
function main() {
	global $user, $authed, $mode, $skin;
	print "<H2>Welcome to the Virtual Computing Lab</H2>\n";
	if($authed) {
		print "Hello ";
		if(! empty($user["preferredname"])) {
			print $user["preferredname"] . " ";
		}
		else {
			print $user["firstname"] . " ";
		}
		print $user["lastname"] . "<br><br>\n";
		$tmp = array_values($user['groups']);
		if(count($tmp) == 1 && $tmp[0] == 'nodemo') {
			print "Your account is a demo account that has expired. ";
			print "You cannot make any more reservations. Please contact <a href=\"";
			print "mailto:" . HELPEMAIL . "\">" . HELPEMAIL . "</a> if you need ";
			print "further access to VCL.<br>\n";
			return;
		}
		$requests = getUserRequests("all", $user["id"]);
		if($num = count($requests)) {
			if($num == 1) {
				print "You currently have $num reservation</a>.<br>\n";
			}
			else {
				print "You currently have $num reservations</a>.<br>\n";
			}
		}
		else {
			print "You do not have any current reservations.<br>\n";
		}
		print "Please make a selection from the menu on the left to continue.<br>\n";
	}
	else {
		print "Click the <b>Log in to VCL</b> button at the top right part of ";
		print "the page to start using the VCL system<br>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn abort($errcode, $query)
///
/// \param $errcode - error code
/// \param $query - a myql query
///
/// \brief prints out error message(s), closes db connection, prints footer
/// and exits
///
////////////////////////////////////////////////////////////////////////////////
function abort($errcode, $query="") {
	global $mysql_link_vcl, $mysql_link_acct, $ERRORS, $user, $mode;
	global $ENABLE_ITECSAUTH, $requestInfo;
	if($mode == 'xmlrpccall')
		xmlRPCabort($errcode, $query);
	if(ONLINEDEBUG && $user["adminlevel"] == "developer") {
		if($errcode >= 100 && $errcode < 400) {
			print "<font color=red>" . mysql_error($mysql_link_vcl) . "</font><br>\n";
			if($ENABLE_ITECSAUTH)
				print "<font color=red>" . mysql_error($mysql_link_acct) . "</font><br>\n";
			print "$query<br>\n";
		}
		print "ERROR($errcode): " . $ERRORS["$errcode"] . "<BR>\n";
		print "<pre>\n";
		print getBacktraceString(FALSE);
		print "</pre>\n";
	}
	else {
		$message = "";
		if($errcode >= 100 && $errcode < 400) {
			$message .= mysql_error($mysql_link_vcl) . "\n";
			$message .= mysql_error($mysql_link_acct) . "\n";
			$message .= $query . "\n";
		}
		$message .= "ERROR($errcode): " . $ERRORS["$errcode"] . "\n";
		$message .= "Logged in user was " . $user["unityid"] . "\n";
		$message .= "Mode was $mode\n\n";
		if($errcode == 20) {
			$urlArray = explode('?', $_SERVER["HTTP_REFERER"]);
			$message .= "HTTP_REFERER URL - " . $urlArray[0] . "\n";
			$message .= "correct URL - " . BASEURL . SCRIPT . "\n";
		}
		if($errcode == 40) {
			$message .= "One of the following computers didn't get a mgmt node:\n";
			foreach($requestInfo["images"] as $key => $imageid) {
				$message .= "imageid: $imageid\n";
				$message .= "compid: {$requestInfo['computers'][$key]}\n";
			}
		}
		$message .= getBacktraceString(FALSE);
		$mailParams = "-f" . ENVELOPESENDER;
		mail(ERROREMAIL, "Error with VCL pages ($errcode)", $message, '', $mailParams);
		print "An error has occurred.  If this problem persists, please email ";
		print "<a href=\"mailto:" . HELPEMAIL . "?Subject=Problem%20With%20VCL\">";
		print HELPEMAIL . "</a> for further assistance.  Please include the ";
		print "steps you took that led up to this problem in your email message.";
	}
	dbDisconnect();
	printHTMLFooter();
	// release semaphore lock
	semUnlock();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn errorrpt()
///
/// \brief takes input from ajax call and emails error to ERROREMAIL
///
////////////////////////////////////////////////////////////////////////////////
function errorrpt() {
	$mailParams = "-f" . ENVELOPESENDER;
	mail(ERROREMAIL, "Error with VCL pages (ajax sent html wrappers)", $_POST['data'], '', $mailParams);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn ldapUIDLookup($uid, &$userInfo, $doMerge)
///
/// \param $uid - userid to lookup
/// \param $userInfo - the following fields get populated if they are received
/// from the LDAP server:\n
/// \b uid - userid\n
/// \b info->has_account - TRUE/FALSE\n
/// \b info->is_employee - TRUE/FALSE\n
/// \b info->is_student - TRUE/FALSE\n
/// \b cn - full name\n
/// \b sn - surname\n
/// \b employeeType - SPA/EPA/GRAD/??\n
/// \b givenName - first name\n
/// \b ncsuMiddleName - middle name\n
/// \b initials \n
/// \b title \n
/// \b ncsuPreferredName \n
/// \b displayName \n
/// \b employeeNumber \n
/// \b departmentNumber \n
/// \b ncsuAffiliation - ??\n
/// \b mail - preferred email address\n
/// \b registeredAddress \n
/// \b telephoneNumber \n
/// \b facsimileTelephoneNumber \n
/// \b ou - department \n
/// \b gecos - ??\n
/// \b loginShell - preferred unix shell \n
/// \b uidNumber - numeric unix id \n
/// \b gidNumber - numeric unix groud id \n
/// \b homeDirectory \n
/// \b mailHost \n
/// \b ncsuMUAprotocol - POP/IMAP (not current??)\n
/// \b memberNisNetgroup - array of hesiod groups\n
/// \param $doMerge - (optional) ??
///
/// \return TRUE or FALSE
///
/// \brief looks up a userid on the LDAP server, populates $userInfo, returns
/// TRUE or FALSE
///
////////////////////////////////////////////////////////////////////////////////
function ldapUIDLookup($uid, &$userInfo, $doMerge=TRUE) {
	global $ldaprdn, $ldappass, $error;
	$userInfo = array("uid" => "",
	                  "cn" => "",
	                  "sn" => "",
	                  "employeeType" => "",
	                  "givenName" => "",
	                  "initials" => "",
	                  "title" => "",
	                  "ncsuPreferredName" => "",
	                  "displayName" => "",
	                  "employeeNumber" => "",
	                  "departmentNumber" => "",
	                  "ncsuAffiliation" => "",
	                  "mail" => "",
	                  "registeredAddress" => "",
	                  "telephoneNumber" => "",
	                  "facsimileTelephoneNumber" => "",
	                  "ou" => "",
	                  "gecos" => "",
	                  "loginShell" => "",
	                  "uidNumber" => "",
	                  "gidNumber" => "",
	                  "homeDirectory" => "",
	                  "mailHost" => "",
	                  "ncsuMUAprotocol" => "",
	                  "ncsuMiddleName" => "",
	                  "memberNisNetgroup" => array());
	
	$ldapConnect = ldap_connect("ldaps://ldap.ncsu.edu/");
	if(!$ldapConnect) {
		$error['op'] = "ldapUIDLookup";
		$error['shortmsg'] = "Could not connect to LDAP server: ";
		$error['shortmsg'] .= "ldap.ncsu.edu"; 
		return FALSE;
	}

	ldap_set_option($ldapConnect, LDAP_OPT_REFERRALS, 0);
	$result = ldap_bind($ldapConnect, $ldaprdn, $ldappass);
	if(!$result) {
		$error['op'] = "ldapUIDLookup";
		$error['shortmsg'] = "Could not create LDAP binding";   
		$error['syscode'] = ldap_errno($ldapConnect);
		$error['sysmsg'] = ldap_err2str($error['syscode']);     
		ldap_close($ldapConnect);
		return FALSE;
	}

	$context = "dc=ncsu,dc=edu";
	$searchstring = "uid=".$uid;
	$searchResult = 
	   ldap_search($ldapConnect,$context,$searchstring,array("*","+"));
	if(!$searchResult) {
		$error['op'] = "ldapUIDLookup";
		$error['shortmsg'] = "Could not execute LDAP search ";
		$error['shortmsg'] .= "($context => $searchstring)";
		$error['context'] = $context;
		$error['search'] = $searchstring;
		$error['syscode'] = ldap_errno($ldapConnect);
		$error['sysmsg'] = ldap_err2str($error['syscode']);
		ldap_close($ldapConnect);
		return FALSE;
	}

	if(ldap_count_entries($ldapConnect,$searchResult) == 0) {
		$error['op'] = "ldapUIDLookup";
		$error['shortmsg'] = "Specified uid: $uid not found";
		ldap_close($ldapConnect);
		return FALSE;
	}


	// basic information
	$haveuser = FALSE;      
	$userInfo['uid'] = $uid;
	$userInfo['info']['has_account'] = FALSE;
	$accountInfo = array();
	$userInfo['info']['is_employee'] = FALSE;
	$employeeInfo = array();
	$userInfo['info']['is_student'] = FALSE;
	$studentInfo = array();

	for($entryID = ldap_first_entry($ldapConnect,$searchResult);
		$entryID != FALSE;
		$entryID = ldap_next_entry($ldapConnect,$entryID)) {
		$thisEntry = array();
		$thisDN = '';
		$thisDN = ldap_get_dn($ldapConnect,$entryID);
		$thisEntry = ldap_get_attributes($ldapConnect,$entryID);

		if(!(isset($thisEntry))) continue;

		// parse dn
		$dnarray = explode(',',$thisDN);
		$checkou = $dnarray[1];
		switch($checkou) {

			case "ou=accounts":
				$haveuser = TRUE;
				$userInfo['info']['has_account'] = TRUE;
				$dataInfo = &$accountInfo;
				break;

			case "ou=employees":
				$haveuser = TRUE;
				$userInfo['info']['is_employee'] = TRUE;
				$dataInfo = &$employeeInfo;
				break;  

			case "ou=students":
				$haveuser = TRUE;
				$userInfo['info']['is_student'] = TRUE;
				$dataInfo = &$studentInfo;
				break;

			// not dealing with a group/printer/host/other
			// somehow (don't know how) keyed by identifier uid=$uid...
			default:
				continue 2;
		}

		foreach($thisEntry as $attribute => $value) {
			if(!(is_array($value))) continue;
			if($attribute == "uid") continue;
			if($attribute == "count") continue;

			if($value['count'] > 1) {
				$dataInfo[$attribute] = $value;
				unset($dataInfo[$attribute]['count']);
			}
			else {
				$dataInfo[$attribute] = $value[0];      
			}
		}       
	}

	if(!($haveuser)) {
		$error['op'] = "ldapUIDLookup";
		$error['shortmsg'] = "Specified uid: $uid is not a user account";
		ldap_close($ldapConnect);
		return FALSE;
	}

	// merge information student, then employee, then account

	if($userInfo['info']['is_student']) {
		if($doMerge) $userInfo = array_merge($userInfo,$studentInfo);
		$userInfo['info']['student'] = $studentInfo;
	}

	if($userInfo['info']['is_employee']) {
		if($doMerge) $userInfo = array_merge($userInfo,$employeeInfo);
		$userInfo['info']['employee'] = $employeeInfo;
	}

	if($userInfo['info']['has_account']) {
		if($doMerge) $userInfo = array_merge($userInfo,$accountInfo);
		$userInfo['info']['account'] = $accountInfo;
	}

	if($doMerge) {
		// merged values we don't care about:
		$noMergeAttribs = array('objectClass',
		                        'structuralObjectClass',
		                        'entryUUID',
		                        'creatorsName',
		                        'createTimestamp',
		                        'modifyTimestamp',
		                        'subschemaSubentry',
		                        'hasSubordinates',
		                        'modifiersName',
		                        'entryCSN');

		foreach($noMergeAttribs as $attribute) {
			unset($userInfo[$attribute]);
		}
	}

	if(! $userInfo["info"]["is_employee"] && ! $userInfo["info"]["is_student"] &&
	   $userInfo["info"]["has_account"]) {
		if(array_key_exists("gecos", $userInfo["info"]["account"])) {
			$name = explode(' ', $userInfo["info"]["account"]["gecos"]);
			if(count($name) == 3) {
				$userInfo["givenName"] = $name[0];
				$userInfo["ncsuMiddleName"] = $name[1];
				$userInfo["sn"] = $name[2];
			}
			elseif(count($name) == 2) {
				$userInfo["givenName"] = $name[0];
				$userInfo["sn"] = $name[1];
			}
			elseif(count($name) == 1) {
				$userInfo["sn"] = $name[0];
			}
		}
		$userInfo["mail"] = $userInfo["uid"] . "@ncsu.edu";
	}

	return TRUE;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn validateUserid($loginid)
///
/// \param $loginid - a submitted loginid
///
/// \return 0 if the loginid is not found in one of the authentications
/// systems, 1 if it is
///
/// \brief checks to see if $loginid is found in one of the authentication
/// systems
///
////////////////////////////////////////////////////////////////////////////////
function validateUserid($loginid) {
	global $affilValFuncArgs, $affilValFunc;
	if(empty($loginid))
		return 0;
	
	getAffilidAndLogin($loginid, $affilid);

	if(empty($affilid))
		return 0;

	$query = "SELECT id "
	       . "FROM user "
	       . "WHERE unityid = '$loginid' AND "
	       .       "affiliationid = $affilid";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh))
		return 1;

	$valfunc = $affilValFunc[$affilid];
	if(array_key_exists($affilid, $affilValFuncArgs))
		return $valfunc($affilValFuncArgs[$affilid], $loginid);
	else
		return $valfunc($loginid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAffilidAndLogin(&$login, &$affilid)
///
/// \param $login - login for user, may include \@affiliation
/// \param $affilid - variable in which to stick the affiliation id
///
/// \return 1 if $affilid set by a registered function, 0 if set to default
///
/// \brief tries registered affiliation lookup functions to determine the
/// affiliation id of the user; if it finds it, sticks the affiliationid in
/// $affilid and sets $login to not include \@affiliation if it did
///
////////////////////////////////////////////////////////////////////////////////
function getAffilidAndLogin(&$login, &$affilid) {
	global $findAffilFuncs;
	foreach($findAffilFuncs as $func) {
		if($func($login, $affilid))
			return 1;
	}
	$affilid = DEFAULT_AFFILID;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn mysql_connect_plus($host, $user, $pwd)
///
/// \param $host - mysql host
/// \param $user - userid to use for connection
/// \param $pwd - password to use for connection
///
/// \return mysql resource identifier, 0 if failure to connect
///
/// \brief opens a socket connection to $host, if it is not established in 5
/// seconds, returns an error, otherwise, opens a connection to the database
/// and returns the identifier
///
////////////////////////////////////////////////////////////////////////////////
function mysql_connect_plus($host, $user, $pwd) {
	$timeout = 5;             /* timeout in seconds */

	if($fp = @fsockopen($host, 3306, $errno, $errstr, $timeout)) {
		fclose($fp);
		return $link = mysql_connect($host, $user, $pwd);
	} else {
		#print "ERROR: socket timeout<BR>\n";
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn dbConnect()
///
/// \brief opens connections to database, the resource identifiers are\n
/// \b $mysql_link_vcl - for vcl database\n
/// \b $mysql_link_acct - for accounts database\n
///
////////////////////////////////////////////////////////////////////////////////
function dbConnect() {
	global $vclhost, $vcldb, $vclusername, $vclpassword, $mysql_link_vcl;
	global $accthost, $acctusername, $acctpassword, $mysql_link_acct;
	global $ENABLE_ITECSAUTH;

	// open a connection to mysql server for vcl
	if(! $mysql_link_vcl = mysql_connect_plus($vclhost, $vclusername, $vclpassword)) {
		die("Error connecting to $vclhost.<br>\n");
	}
	// select the vcl database
	mysql_select_db($vcldb, $mysql_link_vcl) or abort(104);

	if($ENABLE_ITECSAUTH) {
		// open a connection to mysql server for accounts
		if(! $mysql_link_acct = mysql_connect_plus($accthost, $acctusername, $acctpassword)) {
			$ENABLE_ITECSAUTH = 0;
			return;
		}
		// select the accounts database
		mysql_select_db("accounts", $mysql_link_acct);# or safeExit($RC["ERROR"], "Failed to select vcl database");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn dbDisconnect()
///
/// \brief closes connections to the database
///
////////////////////////////////////////////////////////////////////////////////
function dbDisconnect() {
	global $mysql_link_vcl, $mysql_link_acct, $ENABLE_ITECSAUTH;
	mysql_close($mysql_link_vcl);
	if($ENABLE_ITECSAUTH)
		mysql_close($mysql_link_acct);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn doQuery($query, $errcode, $db, $nolog)
///
/// \param $query - SQL statement
/// \param $errcode - error code
/// \param $db - (optional, defaul=vcl), database to query against
/// \param $nolog - (optional, defaul=0), don't log to queryLog table
///
/// \return $qh - query handle
///
/// \brief performs the query and returns $qh or aborts on error
///
////////////////////////////////////////////////////////////////////////////////
function doQuery($query, $errcode, $db="vcl", $nolog=0) {
	global $mysql_link_vcl, $mysql_link_acct, $user, $mode, $ENABLE_ITECSAUTH;
	global $totalQueries, $queryTimes;
	$totalQueries++;
	if($db == "vcl") {
		if((! $nolog) && ereg('^(UPDATE|INSERT|DELETE)', $query)) {
			$logquery = str_replace("'", "\'", $query);
			$logquery = str_replace('"', '\"', $logquery);
			$q = "INSERT INTO querylog "
			   .        "(userid, "
			   .        "timestamp, "
			   .        "mode, "
			   .        "query) "
			   . "VALUES "
			   .        "(" . $user["id"] . ", "
			   .        "NOW(), "
			   .        "'$mode', "
			   .        "'$logquery')";
			mysql_query($q, $mysql_link_vcl);
		}
		$qh = mysql_query($query, $mysql_link_vcl) or abort($errcode, $query);
	}
	elseif($db == "accounts") {
		if($ENABLE_ITECSAUTH)
			$qh = mysql_query($query, $mysql_link_acct) or abort($errcode, $query);
		else
			$qh = NULL;
	}
	return $qh;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn dbLastInsertID()
///
/// \return last insert id for $mysql_link_vcl
///
/// \brief calls mysql_insert_id for $mysql_link_vcl
///
////////////////////////////////////////////////////////////////////////////////
function dbLastInsertID() {
	global $mysql_link_vcl;
	return mysql_insert_id($mysql_link_vcl);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getOSList()
///
/// \return $oslist - array of OSs
///
/// \brief builds an array of OSs
///
////////////////////////////////////////////////////////////////////////////////
function getOSList() {
	$qh = doQuery("SELECT id, name, prettyname, type FROM OS", "115");
	$oslist = array();
	while($row = mysql_fetch_assoc($qh))
		$oslist[$row['id']] = $row;
	return $oslist;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImages($includedeleted=0, $imageid=0)
///
/// \param $includedeleted = (optional) 1 to show deleted images, 0 not to
/// \param $imageid = (optional) only get data for this image, defaults
/// to getting data for all images
///
/// \return $imagelist - array of images with the following elements:\n
/// \b name - name of image\n
/// \b prettyname - pretty name of image\n
/// \b deptid - dept id image belongs to\n
/// \b ownerid - userid of owner\n
/// \b owner - unity id of owner\n
/// \b platformid - platformid for the platform the image if for\n
/// \b platform - platform the image is for\n
/// \b osid - osid for the os on the image\n
/// \b os - os the image contains\n
/// \b minram - minimum amount of RAM needed for image\n
/// \b minprocnumber - minimum number of processors needed for image\n
/// \b minprocspeed - minimum speed of processor(s) needed for image\n
/// \b minnetwork - minimum speed of network needed for image\n
/// \b maxconcurrent - maximum concurrent usage of this iamge\n
/// \b reloadtime - time in minutes for image to be loaded\n
/// \b deleted - 'yes' or 'no'; whether or not this image has been deleted\n
/// \b test - 0 or 1; whether or not there is a test version of this image\n
/// \b resourceid - image's resource id from the resource table\n
/// \b lastupdate - datetime image was last updated\n
/// \b forcheckout - 0 or 1; whether or not the image is allowed to be directly
///                  checked out\n
/// \b maxinitialtime - maximum time (in minutes) to be shown when requesting
///                     a reservation that the image can reserved for\n
/// \b imagemetaid - NULL or corresponding id from imagemeta table and the 
/// following additional information:\n
/// \b checkuser - whether or not vcld should check for a logged in user\n
/// \b usergroupid - id of user group to use when creating local accounts\n
/// \b usergroup - user group to use when creating local accounts\n
/// \b sysprep - whether or not to use sysprep on creation of the image\n
/// \b subimages - an array of subimages to be loaded along with selected
/// image\n
/// \b imagerevision - an array of revision info about the image, it has these
/// keys: id, revision, userid, user, datecreated, prettydate, production,
/// imagename
///
/// \brief generates an array of images
///
////////////////////////////////////////////////////////////////////////////////
function getImages($includedeleted=0, $imageid=0) {
	$query = "SELECT i.id AS id,"
	       .        "i.name AS name, "
	       .        "i.prettyname AS prettyname, "
	       .        "i.deptid AS deptid, "
	       .        "i.ownerid AS ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "i.platformid AS platformid, "
	       .        "p.name AS platform, "
	       .        "i.OSid AS osid, "
	       .        "o.name AS os, "
	       .        "i.minram AS minram, "
	       .        "i.minprocnumber AS minprocnumber, "
	       .        "i.minprocspeed AS minprocspeed, "
	       .        "i.minnetwork AS minnetwork, "
	       .        "i.maxconcurrent AS maxconcurrent, "
	       .        "i.reloadtime AS reloadtime, "
	       .        "i.deleted AS deleted, "
	       .        "i.test AS test, "
	       .        "r.id AS resourceid, "
	       .        "i.lastupdate, "
	       .        "i.forcheckout, "
	       .        "i.maxinitialtime, "
	       .        "i.imagemetaid "
	       . "FROM image i, "
	       .      "platform p, "
	       .      "OS o, "
	       .      "resource r, "
	       .      "resourcetype t, "
	       .      "user u, "
	       .      "affiliation a "
	       . "WHERE i.platformid = p.id AND "
	       .       "r.resourcetypeid = t.id AND "
	       .       "t.name = 'image' AND "
	       .       "r.subid = i.id AND "
	       .       "i.OSid = o.id AND "
	       .       "i.ownerid = u.id AND "
	       .       "u.affiliationid = a.id ";
	if($imageid)
		$query .= "AND i.id = $imageid ";
	if(! $includedeleted) {
		$query .= "AND i.deleted = 0 ";
	}
   $query .= "ORDER BY i.prettyname";
	$qh = doQuery($query, 120);
	$imagelist = array();
	while($row = mysql_fetch_assoc($qh)) {
		$imagelist[$row["id"]] = $row;
		if($row["imagemetaid"] != NULL) {
			$query2 = "SELECT i.checkuser, "
			        .        "i.subimages, "
			        .        "i.usergroupid, "
			        .        "u.name AS usergroup, "
			        .        "a.name AS affiliation, "
			        .        "i.sysprep "
			        . "FROM imagemeta i "
			        . "LEFT JOIN usergroup u ON (i.usergroupid = u.id) "
			        . "LEFT JOIN affiliation a ON (u.affiliationid = a.id) "
			        . "WHERE i.id = {$row["imagemetaid"]}";
			$qh2 = doQuery($query2, 101);
			$row2 = mysql_fetch_assoc($qh2);
			$imagelist[$row["id"]]["checkuser"] = $row2["checkuser"];
			$imagelist[$row["id"]]["usergroupid"] = $row2["usergroupid"];
			if(! empty($row2['affiliation']))
				$imagelist[$row["id"]]["usergroup"] = "{$row2["usergroup"]}@{$row2['affiliation']}";
			else
				$imagelist[$row["id"]]["usergroup"] = $row2["usergroup"];
			$imagelist[$row['id']]['sysprep'] = $row2['sysprep'];
			$imagelist[$row["id"]]["subimages"] = array();
			if($row2["subimages"]) {
				$query2 = "SELECT imageid "
				        . "FROM subimages "
				        . "WHERE imagemetaid = {$row["imagemetaid"]}";
				$qh2 = doQuery($query2, 101);
				while($row2 = mysql_fetch_assoc($qh2)) {
					array_push($imagelist[$row["id"]]["subimages"], $row2["imageid"]);
				}
			}
		}
		$query3 = "SELECT i.id, "
		        .        "i.revision, "
		        .        "i.userid, "
		        .        "CONCAT(u.unityid, '@', a.name) AS user, "
		        .        "i.datecreated, "
		        .        "DATE_FORMAT(i.datecreated, '%c/%d/%y %l:%i %p') AS prettydate, "
		        .        "i.production, "
		        .        "i.imagename "
		        . "FROM imagerevision i, "
		        .      "affiliation a, "
		        .      "user u "
		        . "WHERE i.imageid = {$row['id']} AND "
		        .       "i.deleted = 0 AND "
		        .       "i.userid = u.id AND "
		        .       "u.affiliationid = a.id";
		$qh3 = doQuery($query3, 101);
		while($row3 = mysql_fetch_assoc($qh3))
			$imagelist[$row['id']]['imagerevision'][$row3['id']] = $row3;
	}
	return $imagelist;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImageRevisions($imageid, $incdeleted)
///
/// \param $imageid - id of an image
/// \param $incdeleted - (optional, defaults to 0) 1 to include deleted images
///
/// \return an array where each key is the id of the image revision and each
/// element has these values:\n
/// \b id - id of revision\n
/// \b revision - revision number\n
/// \b creatorid - user id of person that created the revision\n
/// \b creator - user@affiliation\n
/// \b datecreated - datetime of when revision was created\n
/// \b deleted - 1 if deleted, 0 if not\n
/// \b production - 1 if production revision, 0 if not\n
/// \b comments - comments about the revision\n
/// \b imagename - name for files related to revision
///
/// \brief gets image revision data related to $imageid
///
////////////////////////////////////////////////////////////////////////////////
function getImageRevisions($imageid, $incdeleted=0) {
	$query = "SELECT i.id, "
	       .        "i.revision, "
	       .        "i.userid AS creatorid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS creator, "
	       .        "i.datecreated, "
	       .        "i.deleted, "
	       .        "i.production, "
	       .        "i.comments, "
	       .        "i.imagename "
	       . "FROM imagerevision i, "
	       .      "user u, "
	       .      "affiliation a "
	       . "WHERE i.userid = u.id "
	       .   "AND u.affiliationid = a.id "
	       .   "AND i.imageid = $imageid";
	if(! $incdeleted)
		$query .= " AND i.deleted = 0";
	$query .= " ORDER BY revision";
	$qh = doQuery($query, 101);
	$return = array();
	while($row = mysql_fetch_assoc($qh))
		$return[$row['id']] = $row;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImageNotes($imageid)
///
/// \param $imageid - id of an image
/// \param $revisionid - image revision id
///
/// \return an array with these keys:\n
/// \b description - description of image\n
/// \b usage - notes on using the image
///
/// \brief gets data from the imageinfo table for $imageid and $revisionid
///
////////////////////////////////////////////////////////////////////////////////
function getImageNotes($imageid) {
	if(empty($imageid))
		$imageid = 0;
	$query = "SELECT description, "
	       .        "`usage` "
	       . "FROM image "
	       . "WHERE id = $imageid";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		return $row;
	else
		return array('description' => '', 'usage' => '');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getProductionRevisionid($imageid)
///
/// \param $imageid
///
/// \return the production revision id for $imageid
///
/// \brief gets the production revision id for $imageid from the imagerevision
/// table
///
////////////////////////////////////////////////////////////////////////////////
function getProductionRevisionid($imageid) {
	$query = "SELECT id "
	       . "FROM imagerevision  " 
	       . "WHERE imageid = $imageid AND "
	       .       "production = 1";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	return $row['id'];
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserResources($userprivs, $resourceprivs, $onlygroups,
///                               $includedeleted, $userid)
///
/// \param $userprivs - array of privileges to look for (such as
/// imageAdmin, imageCheckOut, etc) - this is an OR list; don't include 'block' or 'cascade'
/// \param $resourceprivs - array of privileges to look for (such as
/// available, administer, manageGroup) - this is an OR list; don't include 'block' or 'cascade'
/// \param $onlygroups - (optional) if 1, return the resource groups instead
/// of the resources
/// \param $includedeleted - (optional) included deleted resources if 1,
/// don't if 0
/// \param $userid - (optional) id from the user table, if not given, use the
/// id of the currently logged in user
///
/// \return an array of 2 arrays where the first indexes are resource types
/// and each one's arrays are a list of resources available to the user where
/// the index of each item is the id and the value is the name of the
/// resource\n
/// if $onlygroups == 1:\n
/// {[computer] => {[groupid] => "groupname",\n
///                 [groupid] => "groupname"},\n
///  [image] => {[groupid] => "groupname",\n
///              [groupid] => "groupname"},\n
///   ...}\n
/// if $onlygroups == 0:\n
/// {[computer] => {[compid] => "hostname",\n
///                 [compid] => "hosename"},\n
///  [image] => {[imageid] => "prettyname",\n
///              [imageid] => "prettyname"},\n
///   ...}
///
/// \brief builds a list of resources a user has access to and returns it
///
////////////////////////////////////////////////////////////////////////////////
function getUserResources($userprivs, $resourceprivs=array("available"),
                          $onlygroups=0, $includedeleted=0, $userid=0) {
	global $user, $viewmode;
	$key = getKey(array($userprivs, $resourceprivs, $onlygroups, $includedeleted, $userid));
	if(array_key_exists($key, $_SESSION['userresources']))
		return $_SESSION['userresources'][$key];
	#FIXME this whole function could be much more efficient
	if(! $userid)
		$userid = $user["id"];
	$return = array();

	$nodeprivs = array();
	$startnodes = array();
	# build a list of nodes where user is granted $userprivs
	$inlist = "'" . implode("','", $userprivs) . "'";
	$query = "SELECT u.privnodeid "
	       . "FROM userpriv u, "
	       .      "userprivtype t "
	       . "WHERE u.userprivtypeid = t.id AND "
	       .       "t.name IN ($inlist) AND "
	       .       "(u.userid = $userid OR "
	       .       "u.usergroupid IN (SELECT usergroupid "
	       .                         "FROM usergroupmembers "
	       .                         "WHERE userid = $userid))";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		array_push($startnodes, $row["privnodeid"]);
	}
	# travel up tree looking at privileges granted at parent nodes
	foreach($startnodes as $nodeid) {
		getUserResourcesUp($nodeprivs, $nodeid, $userid, $userprivs);
	}
	# travel down tree looking at privileges granted at child nodes if cascade privs at this node
	foreach($startnodes as $nodeid) {
		getUserResourcesDown($nodeprivs, $nodeid, $userid, $userprivs);
	}
	$nodeprivs = simplifyNodePrivs($nodeprivs, $userprivs); // call this before calling addUserResources
	addUserResources($nodeprivs, $userid);

	# build a list of resource groups user has access to
	$resourcegroups = array();
	$types = getTypes("resources");
	foreach($types["resources"] as $type) {
		$resourcegroups[$type] = array();
	}
	foreach(array_keys($nodeprivs) as $nodeid) {
		// if user doesn't have privs at this node, no need to look
		// at any resource groups here
		$haspriv = 0;
		foreach($userprivs as $priv) {
			if($nodeprivs[$nodeid][$priv])
				$haspriv = 1;
		}
		if(! $haspriv)
			continue;
		# check to see if resource groups has any of $resourceprivs at this node
		foreach(array_keys($nodeprivs[$nodeid]["resources"]) as $resourceid) {
			foreach($resourceprivs as $priv) {
				if(in_array($priv, $nodeprivs[$nodeid]["resources"][$resourceid])) {
					list($type, $name, $id) = split('/', $resourceid);
					if(! array_key_exists($type, $resourcegroups))
						$resourcegroups[$type] = array();
					if(! in_array($name, $resourcegroups[$type]))
						$resourcegroups[$type][$id] = $name;
				}
			}
		}
		# check to see if resource groups has any of $resourceprivs cascaded to this node
		foreach(array_keys($nodeprivs[$nodeid]["cascaderesources"]) as $resourceid) {
			foreach($resourceprivs as $priv) {
				if(in_array($priv, $nodeprivs[$nodeid]["cascaderesources"][$resourceid]) &&
					! (array_key_exists($resourceid, $nodeprivs[$nodeid]["resources"]) &&
					in_array("block", $nodeprivs[$nodeid]["resources"][$resourceid]))) {
					list($type, $name, $id) = split('/', $resourceid);
					if(! array_key_exists($type, $resourcegroups))
						$resourcegroups[$type] = array();
					if(! in_array($name, $resourcegroups[$type]))
						$resourcegroups[$type][$id] = $name;
				}
			}
		}
	}

	addOwnedResourceGroups($resourcegroups, $userid);
	if($onlygroups) {
		foreach(array_keys($resourcegroups) as $type)
			uasort($resourcegroups[$type], "sortKeepIndex");
		$_SESSION['userresources'][$key] = $resourcegroups;
		return $resourcegroups;
	}

	$resources = array();
	foreach(array_keys($resourcegroups) as $type) {
		$resources[$type] = 
		   getResourcesFromGroups($resourcegroups[$type], $type, $includedeleted);
	}
	addOwnedResources($resources, $includedeleted, $userid);
	$_SESSION['userresources'][$key] = $resources;
	return $resources;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserResourcesUp(&$nodeprivs, $nodeid, $userid,
///                                 $resourceprivs)
///
/// \param $nodeprivs - node privilege array used in getUserResources
/// \param $nodeid - an id from the nodepriv table
/// \param $userid - an id from the user table
/// \param $resourceprivs - array of privileges to look for (such as
/// imageAdmin, imageCheckOut, etc); don't include 'block' or 'cascade'
///
/// \return modifies $nodeprivs, but doesn't return anything
///
/// \brief adds resource privileges to $nodeprivs for the parents of $nodeid
///
////////////////////////////////////////////////////////////////////////////////
function getUserResourcesUp(&$nodeprivs, $nodeid, $userid, 
                                     $resourceprivs) {
	# build list of parent nodes
	# starting at top, get images available at that node and user privs there and
	# walk down to $nodeid
	$nodelist = getParentNodes($nodeid);
	array_unshift($nodelist, $nodeid);
	$lastid = 0;
	while(count($nodelist)) {
		$id = array_pop($nodelist);
		if(array_key_exists($id, $nodeprivs))
			continue;

		addNodeUserResourcePrivs($nodeprivs, $id, $lastid, $userid, $resourceprivs);
		$lastid = $id;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserResourcesDown(&$nodeprivs, $nodeid, $userid,
///                                   $resourceprivs)
///
/// \param $nodeprivs - node privilege array used in getUserResources
/// \param $nodeid - an id from the nodepriv table
/// \param $userid - an id from the user table
/// \param $resourceprivs - array of privileges to look for (such as
/// imageAdmin, imageCheckOut, etc); don't include 'block' or 'cascade'
///
/// \return modifies $nodeprivs, but doesn't return anything
///
/// \brief recursively adds resource privileges to $nodeprivs for any children
/// of $nodeid
///
////////////////////////////////////////////////////////////////////////////////
function getUserResourcesDown(&$nodeprivs, $nodeid, $userid, 
                              $resourceprivs) {
	# FIXME can we check for cascading and if not there, don't descend?
	$children = getChildNodes($nodeid);
	foreach(array_keys($children) as $id) {
		addNodeUserResourcePrivs($nodeprivs, $id, $nodeid, $userid, $resourceprivs);
		getUserResourcesDown($nodeprivs, $id, $userid, $resourceprivs);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addNodeUserResourcePrivs(&$nodeprivs, $id, $lastid, $userid,
///                                       $resourceprivs)
///
/// \param $nodeprivs - node privilege array used in getUserResources
/// \param $id - an id from the nodepriv table
/// \param $lastid - $id's parent, 0 if at the root
/// \param $userid - an id from the user table
/// \param $resourceprivs - array of privileges to look for (such as
/// imageAdmin, imageCheckOut, etc); don't include 'block' or 'cascade'
///
/// \return modifies $nodeprivs, but doesn't return anything
///
/// \brief for $id, gets privileges and cascaded privileges the user and any 
/// groups the user is and adds them to $nodeprivs
///
////////////////////////////////////////////////////////////////////////////////
function addNodeUserResourcePrivs(&$nodeprivs, $id, $lastid, $userid, 
                                  $resourceprivs) {
	$nodeprivs[$id]["user"] = array("cascade" => 0);
	foreach($resourceprivs as $priv) {
		$nodeprivs[$id]["user"][$priv] = 0;
	}

	# add permissions for user
	$inlist = "'" . implode("','", $resourceprivs) . "'";
	$query = "SELECT t.name "
	       . "FROM userprivtype t, "
	       .      "userpriv u "
	       . "WHERE u.userprivtypeid = t.id AND "
	       .       "u.privnodeid = $id AND "
	       .       "u.userid IS NOT NULL AND "
	       .       "u.userid = $userid AND "
	       .       "t.name IN ('block','cascade',$inlist)";
	$qh = doQuery($query, 101);
	$block = 0;
	while($row = mysql_fetch_assoc($qh)) {
		if($row["name"] != "block")
			$nodeprivs[$id]["user"][$row["name"]] = 1;
		else
			$block = 1;
	}
	// if don't have anything in $resourceprivs, set cascade = 0
	if($nodeprivs[$id]["user"]["cascade"]) {
		$noprivs = 1;
		foreach($resourceprivs as $priv) {
			if($nodeprivs[$id]["user"][$priv])
				$noprivs = 0;
		}
		if($noprivs)
			$nodeprivs[$id]["user"]["cascade"] = 0;
	}
	// if not blocking at this node, and previous node had cascade
	if($lastid && ! $block && $nodeprivs[$lastid]["user"]["cascade"]) {
		# set cascade = 1
		$nodeprivs[$id]["user"]["cascade"] = 1;
		# set each priv in $resourceprivs = 1
		foreach($resourceprivs as $priv) {
			if($nodeprivs[$lastid]["user"][$priv])
				$nodeprivs[$id]["user"][$priv] = 1;
		}
	}

	# add permissions for user's groups
	$query = "SELECT t.name, "
	       .        "u.usergroupid "
	       . "FROM userprivtype t, "
	       .      "userpriv u "
	       . "WHERE u.userprivtypeid = t.id AND "
	       .       "u.privnodeid = $id AND "
	       .       "u.usergroupid IS NOT NULL AND "
	       .       "u.usergroupid IN (SELECT usergroupid "
	       .                         "FROM usergroupmembers "
	       .                         "WHERE userid = $userid) AND "
	       .       "t.name IN ('block','cascade',$inlist) "
	       . "ORDER BY u.usergroupid";
	$qh = doQuery($query, 101);
	$basearray = array("cascade" => 0,
	                   "block" => 0);
	foreach($resourceprivs as $priv) {
		$basearray[$priv] = 0;
	}
	while($row = mysql_fetch_assoc($qh)) {
		if(! array_key_exists($row["usergroupid"], $nodeprivs[$id]))
			$nodeprivs[$id][$row["usergroupid"]] = $basearray;
		$nodeprivs[$id][$row["usergroupid"]][$row["name"]] = 1;
	}
	# add groups from $lastid if it is not 0
	$groupkeys = array_keys($nodeprivs[$id]);
	if($lastid) {
		foreach(array_keys($nodeprivs[$lastid]) as $groupid) {
			if(in_array($groupid, $groupkeys))
				continue;
			$nodeprivs[$id][$groupid] = $basearray;
		}
	}
	foreach(array_keys($nodeprivs[$id]) as $groupid) {
		if(! is_numeric($groupid))
			continue;
		// if don't have anything in $resourceprivs, set cascade = 0
		if($nodeprivs[$id][$groupid]["cascade"]) {
			$noprivs = 1;
			foreach($resourceprivs as $priv) {
				if($nodeprivs[$id][$groupid][$priv])
					$noprivs = 0;
			}
			if($noprivs)
				$nodeprivs[$id][$groupid]["cascade"] = 0;
		}
		// if group not blocking at this node, and group had cascade at previous 
		# node
		if($lastid && ! $nodeprivs[$id][$groupid]["block"] && 
		   array_key_exists($groupid, $nodeprivs[$lastid]) &&
		   $nodeprivs[$lastid][$groupid]["cascade"]) {
			# set cascade = 1
			$nodeprivs[$id][$groupid]["cascade"] = 1;
			# set each priv in $resourceprivs = 1
			foreach($resourceprivs as $priv) {
				if($nodeprivs[$lastid][$groupid][$priv])
					$nodeprivs[$id][$groupid][$priv] = 1;
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn simplifyNodePrivs($nodeprivs, $resourceprivs)
///
/// \param $nodeprivs - node privilege array used in getUserResources
/// \param $resourceprivs - array of privileges to look for (such as
/// imageAdmin, imageCheckOut, etc); don't include 'block' or 'cascade'
///
/// \return a simplified version of $nodeprivs
///
/// \brief checks the user and group privileges for each node in $nodeprivs and
/// creates a new privilege array that just shows if the user has that
/// permission (either directly or from a group)
///
////////////////////////////////////////////////////////////////////////////////
function simplifyNodePrivs($nodeprivs, $resourceprivs) {
	$return = array();
	$basearray = array();
	foreach($resourceprivs as $priv) {
		$basearray[$priv] = 0;
	}
	foreach(array_keys($nodeprivs) as $nodeid) {
		$return[$nodeid] = $basearray;
		foreach(array_keys($nodeprivs[$nodeid]) as $key) {
			foreach($resourceprivs as $priv) {
				if($nodeprivs[$nodeid][$key][$priv])
					$return[$nodeid][$priv] = 1;
			}
		}
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addUserResources(&$nodeprivs, $userid)
///
/// \param $nodeprivs - node privilege array used in getUserResources
/// \param $userid - an id from the user table
///
/// \return modifies $nodeprivs, but doesn't return anything
///
/// \brief for each node in $nodeprivs, adds any resources that are available
/// to $nodeprivs
///
////////////////////////////////////////////////////////////////////////////////
function addUserResources(&$nodeprivs, $userid) {
	require_once(".ht-inc/privileges.php");
	foreach(array_keys($nodeprivs) as $nodeid) {
		$privs = getNodePrivileges($nodeid, "resources");
		$nodeprivs[$nodeid]["resources"] = $privs["resources"];
		$privs = getNodeCascadePrivileges($nodeid, "resources");
		$nodeprivs[$nodeid]["cascaderesources"] = $privs["resources"];
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addOwnedResources(&$resources, $includedeleted, $userid)
///
/// \param $resources - array of resources from getUserResources
/// \param $includedeleted - 1 to include deleted resources, 0 not to
/// \param $userid - id from user table
///
/// \return modifies $resources, but doesn't return anything
///
/// \brief adds resources that the user owns
///
////////////////////////////////////////////////////////////////////////////////
function addOwnedResources(&$resources, $includedeleted, $userid) {
	foreach(array_keys($resources) as $type) {
		if($type == "image")
			$field = "prettyname";
		elseif($type == "computer")
			$field = "hostname";
		elseif($type == "schedule")
			$field = "name";
		elseif($type == "managementnode")
			$field = "hostname";
		else
			continue;
		$query = "SELECT id, "
		       .        "$field "
		       . "FROM $type "
		       . "WHERE ownerid = $userid";
		if(! $includedeleted && ($type == "image" || $type == "computer"))
			$query .= " AND deleted = 0";
		$qh = doQuery($query, 101);
		while($row = mysql_fetch_assoc($qh)) {
			if(! array_key_exists($row["id"], $resources[$type]))
				$resources[$type][$row["id"]] = $row[$field];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addOwnedResourceGroups(&$resourcegroups, $userid)
///
/// \param $resourcegroups - array of resources from getUserResources
/// \param $userid - id from user table
///
/// \return modifies $resources, but doesn't return anything
///
/// \brief adds resources that the user owns
///
////////////////////////////////////////////////////////////////////////////////
function addOwnedResourceGroups(&$resourcegroups, $userid) {
	$user = getUserInfo($userid);
	$userid = $user["id"];
	$groupids = implode(',', array_keys($user["groups"]));
	if(empty($groupids))
		$groupids = "''";
	$query = "SELECT g.id AS id, "
	       .        "g.name AS name, "
	       .        "t.name AS type "
	       . "FROM resourcegroup g, "
	       .      "resourcetype t "
	       . "WHERE g.resourcetypeid = t.id AND "
	       .       "g.ownerusergroupid IN ($groupids)";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		if(! array_key_exists($row["id"], $resourcegroups[$row["type"]]))
			$resourcegroups[$row["type"]][$row["id"]] = $row["name"];
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourcesFromGroups($groups, $type, $includedeleted)
///
/// \param $groups - an array of group names
/// \param $type - the type of the groups (from resourcetype table)
/// \param $includedeleted - 1 to include deleted resources, 0 not to
///
/// \return an array of resources where the index is the id of the resource and
/// the value is the name of the resource
///
/// \brief builds an array of resources from $groups
///
////////////////////////////////////////////////////////////////////////////////
function getResourcesFromGroups($groups, $type, $includedeleted) {
	$return = array();
	if($type == "image")
		$field = "prettyname";
	elseif($type == "computer")
		$field = "hostname";
	elseif($type == "schedule")
		$field = "name";
	elseif($type == "managementnode")
		$field = "hostname";
	else
		return array();

	$groups = implode("','", $groups);
	$inlist = "'$groups'";

	/*$query = "SELECT t.$field AS name, "
	       .        "r.subid AS id "
	       . "FROM $type t, "
	       .      "resource r, "
	       .      "resourcetype rt "
	       . "WHERE r.id IN (SELECT m.resourceid "
	       .                "FROM resourcegroupmembers m, "
	       .                     "resourcegroup g, "
	       .                     "resourcetype t "
	       .                "WHERE m.resourcegroupid = g.id AND "
	       .                      "g.name IN ($inlist) AND "
	       .                      "g.resourcetypeid = t.id AND "
	       .                      "t.name = '$type') AND "
	       .       "r.subid = t.id ";*/
	$query = "SELECT DISTINCT(r.subid) AS id, "
	       .       "t.$field AS name "
	       . "FROM $type t, "
	       .      "resource r, "
	       .      "resourcegroupmembers m, "
	       .      "resourcegroup g, "
	       .      "resourcetype rt "
	       . "WHERE r.subid = t.id AND "
	       .       "r.id = m.resourceid AND "
	       .       "m.resourcegroupid = g.id AND "
	       .       "g.name IN ($inlist) AND "
	       .       "g.resourcetypeid = rt.id AND "
	       .       "rt.name = '$type'";
	if(! $includedeleted && ($type == "image" || $type == "computer")) {
		$query .= "AND deleted = 0 ";
	}
	/*if($type == "image")
		$query .= "AND test = 0 ";*/
	$query .= "ORDER BY t.$field";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		$return[$row["id"]] = $row["name"];
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateUserOrGroupPrivs($name, $node, $adds, $removes, $mode)
///
/// \param $name - unityid, user id, user group name, or user group id
/// \param $node - id of the node
/// \param $adds - array of privs (the name, not the id) to add
/// \param $removes - array of privs (the name, not the id) to remove
/// \param $mode - "user" or "group"
///
/// \brief adds/removes $adds/$removes privs for $unityid to/from $node
///
////////////////////////////////////////////////////////////////////////////////
function updateUserOrGroupPrivs($name, $node, $adds, $removes, $mode) {
	if(! (count($adds) || count($removes))) {
		return;
	}
	if($mode == "user") {
		$field = "userid";
		if(is_numeric($name))
			$id = $name;
		else {
			$id = getUserlistID($name);
			if(! $id)
				$id = addUser($name);
		}
	}
	else {
		$field = "usergroupid";
		if(is_numeric($name))
			$id = $name;
		else
			$id = getUserGroupID($name);
	}
	foreach($adds as $type) {
		$typeid = getUserPrivTypeID($type);
		$query = "INSERT IGNORE INTO userpriv ("
		       .        "$field, "
		       .        "privnodeid, "
		       .        "userprivtypeid) "
		       . "VALUES ("
		       .        "$id, "
		       .        "$node, "
		       .        "$typeid)";
		doQuery($query, 375);
	}
	foreach($removes as $type) {
		$typeid = getUserPrivTypeID($type);
		$query = "DELETE FROM userpriv "
		       . "WHERE $field = $id AND "
		       .       "privnodeid = $node AND "
		       .       "userprivtypeid = $typeid";
		doQuery($query, 376);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateResourcePrivs($group, $node, $adds, $removes)
///
/// \param $group - id from resourcegroup table, or group name of the form
/// type/name
/// \param $node - id of the node
/// \param $adds - array of privs (the name, not the id) to add
/// \param $removes - array of privs (the name, not the id) to remove
///
/// \brief adds/removes $adds/$removes privs for $name to/from $node
///
////////////////////////////////////////////////////////////////////////////////
function updateResourcePrivs($group, $node, $adds, $removes) {
	if(! (count($adds) || count($removes))) {
		return;
	}
	if(is_numeric($group))
		$groupid = $group;
	else
		$groupid = getResourceGroupID($group);
	foreach($adds as $type) {
		$query = "INSERT IGNORE INTO resourcepriv ("
		       .        "resourcegroupid, "
		       .        "privnodeid, "
		       .        "type) "
		       . "VALUES ("
		       .        "$groupid, "
		       .        "$node, "
		       .        "'$type')";
		doQuery($query, 377);
	}
	foreach($removes as $type) {
		$query = "DELETE FROM resourcepriv "
		       . "WHERE resourcegroupid = $groupid AND "
		       .       "privnodeid = $node AND "
		       .       "type = '$type'";
		doQuery($query, 378);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getKey($data)
///
/// \param $data - an array
///
/// \return an md5 string that is unique for $data
///
/// \brief generates an md5sum for $data
///
////////////////////////////////////////////////////////////////////////////////
function getKey($data) {
	$newdata = array();
	foreach($data as $arr)
		if(is_array($arr))
			$newdata = array_merge_recursive($newdata, $arr);
		else
			array_push($newdata, $arr);
	$rc = '';
	foreach($newdata as $key => $val)
		$rc = md5("$rc$key$val");
	return $rc;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn encryptData($data)
///
/// \param $data - a string
///
/// \return an encrypted form of the string that has been base64 encoded
///
/// \brief encrypts $data with blowfish and base64 encodes it
///
////////////////////////////////////////////////////////////////////////////////
function encryptData($data) {
	global $mcryptkey, $mcryptiv;
	if(! $data)
		return false;

	$cryptdata = mcrypt_encrypt(MCRYPT_BLOWFISH, $mcryptkey, $data, MCRYPT_MODE_CBC, $mcryptiv);
	return trim(base64_encode($cryptdata));
	#return base64_encode($cryptdata);
}
 
////////////////////////////////////////////////////////////////////////////////
///
/// \fn decryptData($data)
///
/// \param $data - a string
///
/// \return decrypted form of $data
///
/// \brief base64 decodes $data and decrypts it
///
////////////////////////////////////////////////////////////////////////////////
function decryptData($data) {
	global $mcryptkey, $mcryptiv;
	if(! $data)
		return false;

	$cryptdata = base64_decode($data);
	$decryptdata = mcrypt_decrypt(MCRYPT_BLOWFISH, $mcryptkey, $cryptdata, MCRYPT_MODE_CBC, $mcryptiv);
	return trim($decryptdata);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getParentNodes($node)
///
/// \param $node - a privnode id
///
/// \return an array of parents of $node
///
/// \brief build array of node's parents with 0th index being immediate parent
///
////////////////////////////////////////////////////////////////////////////////
function getParentNodes($node) {
	global $nodeparents;
	if(array_key_exists($node, $nodeparents))
		return $nodeparents[$node];

	$nodelist = array();
	while($node != 1) {
		$nodeinfo = getNodeInfo($node);
		$node = $nodeinfo["parent"];
		if($node == NULL)
			break;
		array_push($nodelist, $node);
	}
	$nodeparents[$node] = $nodelist;
	return $nodelist;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getChildNodes($parent)
///
/// \param parent - (optional) the parent of all the children; defaults to 2
/// (the root node)
///
/// \return an array of nodes
///
/// \brief gets all children for $parent
///
////////////////////////////////////////////////////////////////////////////////
function getChildNodes($parent=DEFAULT_PRIVNODE) {
	global $nodechildren;
	if(array_key_exists($parent, $nodechildren))
		return $nodechildren[$parent];

	$query = "SELECT * FROM privnode WHERE parent = $parent ORDER BY name";
	$qh = doQuery($query, 325);
	$children = array();
	while($row = mysql_fetch_assoc($qh)) {
		if($row["name"] == "Root")
			continue;
		$children[$row["id"]]["parent"] = $row["parent"];
		$children[$row["id"]]["name"] = $row["name"];
	}
	$nodechildren[$parent] = $children;
	return $children;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserGroups($groupType, $affiliationid)
///
/// \param $groupType - (optional, default = 0) 0 for all groups, 1 for custom
/// groups, 2 for courseroll groups
/// \param $affiliationid - (optional, default = 0) 0 for groups of any
/// affiliation, or the id of an affiliation for only groups with that
/// affiliation
///
/// \return an array where each index is an id from usergroup and the values
/// are arrays with the indexes:\n
/// name\n
/// ownerid\n
/// owner\n
/// custom\n
/// initialmaxtime\n
/// totalmaxtime\n
/// maxextendtime\n
/// overlapResCount
///
/// \brief builds list of user groups\n
///
////////////////////////////////////////////////////////////////////////////////
function getUserGroups($groupType=0, $affiliationid=0) {
	global $user;
	$return = array();
	$query = "SELECT ug.id, "
	       .        "ug.name, "
	       .        "ga.name AS groupaffiliation, "
	       .        "ug.affiliationid AS groupaffiliationid, "
	       .        "ug.ownerid, "
	       .        "u.unityid AS owner, "
	       .        "a.name AS affiliation, "
	       .        "ug.editusergroupid AS editgroupid, "
	       .        "eug.name AS editgroup, "
	       .        "eug.affiliationid AS editgroupaffiliationid, "
	       .        "euga.name AS editgroupaffiliation, "
	       .        "ug.custom, "
	       .        "ug.courseroll, "
	       .        "ug.initialmaxtime, "
	       .        "ug.totalmaxtime, "
	       .        "ug.maxextendtime, "
	       .        "ug.overlapResCount "
	       . "FROM usergroup ug "
	       . "LEFT JOIN user u ON (ug.ownerid = u.id) "
	       . "LEFT JOIN usergroup eug ON (ug.editusergroupid = eug.id) "
	       . "LEFT JOIN affiliation a ON (u.affiliationid = a.id) "
	       . "LEFT JOIN affiliation ga ON (ug.affiliationid = ga.id) "
	       . "LEFT JOIN affiliation euga ON (eug.affiliationid = euga.id) "
	       . "WHERE 1 ";
	if($groupType == 1)
		$query .= "AND ug.custom = 1 ";
	elseif($groupType == 2)
		$query .= "AND ug.courseroll = 1 ";
	if(! $user['showallgroups'] && $affiliationid)
		$query .= "AND ug.affiliationid = $affiliationid ";
	$query .= "ORDER BY name";
	$qh = doQuery($query, 280);
	while($row = mysql_fetch_assoc($qh)) {
		if(! empty($row["owner"]) && ! empty($row['affiliation']))
			$row['owner'] = "{$row['owner']}@{$row['affiliation']}";
		if($user['showallgroups'] || $affiliationid == 0)
			$row['name'] = "{$row['name']}@{$row['groupaffiliation']}";
		$return[$row["id"]] = $row;
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserEditGroups($id)
///
/// \param $id - user id (string or numeric)
///
/// \return an array of groups where each key is the group id
///
/// \brief builds an array of groups for which $id can edit the membership
///
////////////////////////////////////////////////////////////////////////////////
function getUserEditGroups($id) {
	global $user;
	if(! is_numeric($id))
		$id = getUserlistID($id);
	if($user['showallgroups']) {
		$query = "SELECT DISTINCT(u.id), "
		       .        "CONCAT(u.name, '@', a.name) AS name "
		       . "FROM `usergroup` u, "
		       .      "`usergroupmembers` m, "
		       .      "affiliation a "
		       . "WHERE u.editusergroupid = m.usergroupid AND "
		       .       "u.affiliationid = a.id AND "
		       .       "(u.ownerid = $id OR m.userid = $id)"; 
	}
	else {
		$query = "SELECT DISTINCT(u.id), "
		       .        "u.name "
		       . "FROM `usergroup` u, "
		       .      "`usergroupmembers` m "
		       . "WHERE u.editusergroupid = m.usergroupid AND "
		       .       "(u.ownerid = $id OR m.userid = $id) AND " 
		       .       "u.affiliationid = {$user['affiliationid']}";
	}
	$qh = doQuery($query, 101);
	$groups = array();
	while($row = mysql_fetch_assoc($qh)) {
		$groups[$row['id']] = $row['name'];
	}
	return $groups;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourceGroups($type)
///
/// \param $type - (optional) a name from the resourcetype table, defaults to
/// be empty
///
/// \return an array of resource group names whose index values are the ids;
/// the names are the resource type and group name combined as 'type/name'
///
/// \brief builds list of resource groups
///
////////////////////////////////////////////////////////////////////////////////
function getResourceGroups($type="") {
	$return = array();
	$query = "SELECT g.id AS id, "
	       .        "g.name AS name, "
	       .        "t.name AS type, "
	       .        "g.ownerusergroupid AS ownerid, "
	       .        "CONCAT(u.name, '@', a.name) AS owner "
	       . "FROM resourcegroup g, "
	       .      "resourcetype t, "
	       .      "usergroup u, "
	       .      "affiliation a "
	       . "WHERE g.resourcetypeid = t.id AND "
	       .       "g.ownerusergroupid = u.id AND "
	       .       "u.affiliationid = a.id ";

	if(! empty($type))
		$query .= "AND t.name = '$type' ";

	$query .= "ORDER BY t.name, g.name";
	$qh = doQuery($query, 281);
	while($row = mysql_fetch_assoc($qh)) {
		if(empty($type))
			$return[$row["id"]]["name"] = $row["type"] . "/" . $row["name"];
		else
			$return[$row["id"]]["name"] = $row["name"];
		$return[$row["id"]]["ownerid"] = $row["ownerid"];
		$return[$row["id"]]["owner"] = $row["owner"];
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourceGroupMemberships($type)
///
/// \param $type - (optional) a name from the resourcetype table, defaults to
/// "all"
///
/// \return an array where each index is a resource type and the values are
/// arrays where each index is a resource id and its values are an array of
/// resource group ids that it is a member of
///
/// \brief builds an array of group memberships for resources
///
////////////////////////////////////////////////////////////////////////////////
function getResourceGroupMemberships($type="all") {
	$return = array();

	if($type == "all")
		$types = getTypes("resources");
	else
		$types = array("resources" => array($type));

	foreach($types["resources"] as $type) {
		$return[$type] = array();
		$query = "SELECT r.subid AS id, "
		       .        "gm.resourcegroupid AS groupid "
		       . "FROM resource r, "
		       .      "resourcegroupmembers gm, "
		       .      "resourcetype t "
		       . "where t.name = '$type' AND "
		       .       "gm.resourceid = r.id AND "
		       .       "r.resourcetypeid = t.id";
		$qh = doQuery($query, 282);
		while($row = mysql_fetch_assoc($qh)) {
			if(array_key_exists($row["id"], $return[$type])) {
				array_push($return[$type][$row["id"]], $row["groupid"]);
			}
			else {
				$return[$type][$row["id"]] = array($row["groupid"]);
			}
		}
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourceGroupMembers($type)
///
/// \param $type - (optional) a name from the resourcetype table, defaults to
/// "all"
///
/// \return an array where each index is a resource type and the values are
/// arrays where each index is a resourcegroup id and its values are an array of
/// resource ids that are each an array, resulting in this:\n
/// Array {\n
///    [resourcetype] => Array {\n
///       [resourcegroupid] => Array {\n
///          [resourceid] => Array {\n
///             [subid] => resource sub id\n
///             [name] => name of resource\n
///          }\n
///       }\n
///    }\n
/// }
///
/// \brief builds an array of resource group members that don't have the deleted
/// flag set
///
////////////////////////////////////////////////////////////////////////////////
function getResourceGroupMembers($type="all") {
	$key = getKey(array('getResourceGroupMembers', $type));
	if(array_key_exists($key, $_SESSION['userresources']))
		return $_SESSION['userresources'][$key];
	$return = array();

	if($type == "computer") {
		$names = "c.hostname AS computer, c.deleted ";
		$joins = "LEFT JOIN computer c ON (r.subid = c.id AND r.resourcetypeid = 12) ";
		$orders = "c.hostname";
		$types = "'computer'";
	}
	elseif($type == "image") {
		$names = "i.prettyname AS image, i.deleted ";
		$joins = "LEFT JOIN image i ON (r.subid = i.id AND r.resourcetypeid = 13) ";
		$orders = "i.prettyname";
		$types = "'image'";
	}
	elseif($type == "schedule") {
		$names = "s.name AS schedule ";
		$joins = "LEFT JOIN schedule s ON (r.subid = s.id AND r.resourcetypeid = 15) ";
		$orders = "s.name";
		$types = "'schedule'";
	}
	elseif($type == "managementnode") {
		$names = "m.hostname AS managementnode ";
		$joins = "LEFT JOIN managementnode m ON (r.subid = m.id AND r.resourcetypeid = 16) ";
		$orders = "m.hostname";
		$types = "'managementnode'";
	}
	else {
		$names = "c.hostname AS computer, "
		       . "c.deleted, "
		       . "i.prettyname AS image, "
		       . "i.deleted AS deleted2, "
		       . "s.name AS schedule, "
		       . "m.hostname AS managementnode ";
		$joins = "LEFT JOIN computer c ON (r.subid = c.id AND r.resourcetypeid = 12) "
		       . "LEFT JOIN image i ON (r.subid = i.id AND r.resourcetypeid = 13) "
		       . "LEFT JOIN schedule s ON (r.subid = s.id AND r.resourcetypeid = 15) "
		       . "LEFT JOIN managementnode m ON (r.subid = m.id AND r.resourcetypeid = 16) ";
		$orders = "c.hostname, "
		        . "i.prettyname, "
		        . "s.name, "
		        . "m.hostname";
		$types = "'computer','image','schedule','managementnode'";
	}

	$query = "SELECT rgm.resourcegroupid, "
	       .        "rgm.resourceid, "
	       .        "rt.name AS resourcetype, "
	       .        "r.subid, "
	       .        $names
	       . "FROM   resourcegroupmembers rgm, "
	       .        "resourcetype rt, "
	       .        "resource r "
	       .        $joins
	       . "WHERE  rgm.resourceid = r.id AND "
	       .        "r.resourcetypeid = rt.id AND "
	       .        "rt.name in ($types) "
	       . "ORDER BY rt.name, "
	       .          "rgm.resourcegroupid, "
	       .          $orders;
	$qh = doQuery($query, 282);
	while($row = mysql_fetch_assoc($qh)) {
		if(array_key_exists('deleted', $row) && $row['deleted'] == 1)
			continue;
		if(array_key_exists('deleted2', $row) && $row['deleted2'] == 1)
			continue;
		if(! array_key_exists($row['resourcetype'], $return))
			$return[$row['resourcetype']] = array();
		if(! array_key_exists($row['resourcegroupid'], $return[$row['resourcetype']]))
			$return[$row['resourcetype']][$row['resourcegroupid']] = array();
		$return[$row['resourcetype']][$row['resourcegroupid']][$row['resourceid']] =
		      array('subid' => $row['subid'],
		            'name' => $row[$row['resourcetype']]);
	}
	$_SESSION['userresources'][$key] = $return;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserGroupMembers($groupid)
///
/// \param $groupid - a usergroup id
///
/// \return an array of unityids where the index is the userid
///
/// \brief builds an array of user group memberships
///
////////////////////////////////////////////////////////////////////////////////
function getUserGroupMembers($groupid) {
	$return = array();

	$query = "SELECT m.userid AS id, "
	       .        "CONCAT(u.unityid, '@', a.name) AS user "
	       . "FROM usergroupmembers m, "
	       .      "affiliation a, "
	       .      "user u "
	       . "WHERE m.usergroupid = $groupid AND "
	       .       "m.userid = u.id AND "
	       .       "u.affiliationid = a.id "
	       . "ORDER BY u.unityid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		$return[$row["id"]] = $row['user'];
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addUserGroupMember($unityid, $groupid)
///
/// \param $unityid - a user's unityid
/// \param $groupid - a usergroup id
///
/// \brief adds an entry to usergroupmembers for $unityid and $groupid
///
////////////////////////////////////////////////////////////////////////////////
function addUserGroupMember($unityid, $groupid) {
	$userid = getUserlistID($unityid);
	$groups = getUsersGroups($userid);

	if(in_array($groupid, array_keys($groups)))
		return;

	//$userid = getUserlistID($unityid);
	$query = "INSERT INTO usergroupmembers "
	       .        "(userid, " 
	       .        "usergroupid) "
	       . "VALUES "
	       .        "($userid, "
	       .        "$groupid)";
	doQuery($query, 101);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deleteUserGroupMember($userid, $groupid)
///
/// \param $userid - a userid
/// \param $groupid - a usergroup id
///
/// \brief deletes an entry from usergroupmembers for $userid and $groupid
///
////////////////////////////////////////////////////////////////////////////////
function deleteUserGroupMember($userid, $groupid) {
	$query = "DELETE FROM usergroupmembers "
	       . "WHERE userid = $userid AND "
	       .       "usergroupid = $groupid";
	doQuery($query, 101);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserlistID($loginid)
///
/// \param $loginid - login ID
///
/// \return id from userlist table for the user
///
/// \brief gets id field from userlist table for $loginid; if it does not exist,
/// calls addUser to add it to the table
///
////////////////////////////////////////////////////////////////////////////////
function getUserlistID($loginid) {
	$_loginid = $loginid;
	getAffilidAndLogin($loginid, $affilid);

	if(empty($affilid))
		abort(11);

	$query = "SELECT id "
	       . "FROM user "
	       . "WHERE unityid = '$loginid' AND "
	       .       "affiliationid = $affilid";
	$qh = doQuery($query, 140);
	if(mysql_num_rows($qh)) {
		$row = mysql_fetch_row($qh);
		return $row[0];
	}
	return addUser($_loginid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUsersLastImage($userid)
///
/// \param $userid - a numeric user id
///
/// \return id of user's last used image or NULL if user has no entries in the
/// log table
///
/// \brief gets the user's last used image from the log table
///
////////////////////////////////////////////////////////////////////////////////
function getUsersLastImage($userid) {
	$query = "SELECT imageid "
	       . "FROM log "
	       . "WHERE userid = $userid "
	       . "ORDER BY start DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		return $row['imageid'];
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAffiliations()
///
/// \return an array of affiliations where each index is the id of the
/// affiliation
///
/// \brief gets a list of all affiliations
///
////////////////////////////////////////////////////////////////////////////////
function getAffiliations() {
	$query = "SELECT id, name FROM affiliation ORDER BY name";
	$qh = doQuery($query, 101);
	$return = array();
	while($row = mysql_fetch_assoc($qh))
		$return[$row['id']] = $row['name'];
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserUnityID($userid)
///
/// \param $userid - an id from the user table
///
/// \return unityid for $userid or NULL if $userid not found
///
/// \brief gets the unityid for $userid
///
////////////////////////////////////////////////////////////////////////////////
function getUserUnityID($userid) {
	global $cache;
	if(array_key_exists($userid, $cache['unityids']))
		return $cache['unityids'][$userid];
	$query = "SELECT unityid FROM user WHERE id = $userid";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh)) {
		$row = mysql_fetch_row($qh);
		$cache['unityids'][$userid] = $row[0];
		return $row[0];
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAffiliationID($affil)
///
/// \param $affil - name of an affiliation
///
/// \return id from affiliation table
///
/// \brief gets id field from affiliation table for $affil
///
////////////////////////////////////////////////////////////////////////////////
function getAffiliationID($affil) {
	$query = "SELECT id FROM affiliation WHERE name = '$affil'";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh)) {
		$row = mysql_fetch_row($qh);
		return $row[0];
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAffiliationName($affilid)
///
/// \param $affilid - id of an affiliation
///
/// \return name from affiliation table
///
/// \brief gets name field from affiliation table for $affilid
///
////////////////////////////////////////////////////////////////////////////////
function getAffiliationName($affilid) {
	$query = "SELECT name FROM affiliation WHERE id = $affilid";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh)) {
		$row = mysql_fetch_row($qh);
		return $row[0];
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAffiliationDataUpdateText($affilid)
///
/// \param $affilid - (optional) specify an affiliation id to get only the text
/// for that id
///
/// \return an array of the html text to display for updating user information
/// that is displayed on the User Preferences page
///
/// \brief gets dataUpdateText from affiliation table
///
////////////////////////////////////////////////////////////////////////////////
function getAffiliationDataUpdateText($affilid=0) {
	$query = "SELECT id, dataUpdateText FROM affiliation";
	if($affilid)
		$query .= " WHERE id = $affilid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$return[$row['id']] = $row['dataUpdateText'];
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processInputVar($vartag, $type, $defaultvalue)
///
/// \param $vartag - name of GET or POST variable
/// \param $type - tag type:\n
/// \b ARG_NUMERIC - numeric\n
/// \b ARG_STRING - string\n
/// \b ARG_MULTINUMERIC - an array of numbers
/// \param $defaultvalue - default value for the variable (NULL if not passed in)
///
/// \return safe value for the GET or POST variable
///
/// \brief checks for $vartag in the $_POST array, then the $_GET array; then
/// sanitizes the variable to make sure it doesn't contain anything malicious
///
////////////////////////////////////////////////////////////////////////////////
function processInputVar($vartag, $type, $defaultvalue=NULL) {
	if((array_key_exists($vartag, $_POST) &&
	   strncmp("$_POST[$vartag]", "0", 1) == 0 &&
	   $type == ARG_NUMERIC &&
		strncmp("$_POST[$vartag]", "0x0", 3) != 0) ||
	   (array_key_exists($vartag, $_GET) && 
	   strncmp("$_GET[$vartag]", "0", 1) == 0 &&
	   $type == ARG_NUMERIC &&
		strncmp("$_GET[$vartag]", "0x0", 3) != 0)) {
		$_POST[$vartag] = "zero";
	}
	if(!empty($_POST[$vartag])) {
		$return = $_POST[$vartag];
	}
	elseif(!empty($_GET[$vartag])) {
		$return = $_GET[$vartag];
	}
	else {
		if($type == ARG_MULTINUMERIC || $type == ARG_MULTISTRING) {
			$return = array();
		}
		else {
			$return = $defaultvalue;
		}
	}
	if($return == "zero") {
		$return = "0";
	}

	if($type == ARG_MULTINUMERIC) {
		foreach($return as $index => $value) {
			$return[$index] = strip_tags($value);
			if($return[$index] == 'zero')
				$return[$index] = '0';
		}
	}
	elseif($type == ARG_MULTISTRING) {
		foreach($return as $index => $value) {
			$return[$index] = strip_tags($value);
		}
	}
	else {
		$return = strip_tags($return);
	}

	if(! empty($return) && $type == ARG_NUMERIC) {
		if(! is_numeric($return)) {
			return preg_replace('([^\d])', '', $return);
		}
	}
	elseif(! empty($return) && $type == ARG_STRING) {
		if(! is_string($return)) {
			print "ERROR (code:3)<br>\n";
			printHTMLFooter();
			semUnlock();
			exit();
		}
		#print "before - $return<br>\n";
		#$return = addslashes($return);
		#$return = str_replace("\'", "", $return);
		#$return = str_replace("\"", "", $return);
		#print "after - $return<br>\n";
	}
	elseif(! empty($return) && $type == ARG_MULTINUMERIC) {
		foreach($return as $index => $value) {
			if(! is_numeric($value)) {
				$return[$index] = preg_replace('([^\d])', '', $value);
			}
		}
		return $return;
	}
	elseif(! empty($return) && $type == ARG_MULTISTRING) {
		foreach($return as $index => $value) {
			if(! is_string($value)) {
				print "ERROR (code:3)<br>\n";
				printHTMLFooter();
				semUnlock();
				exit();
			}
		}
		return $return;
	}

	if(is_string($return)) {
		if(strlen($return) == 0) {
			$return = $defaultvalue;
		}
	}

	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getContinuationVar($name, $defaultval)
///
/// \param $name (optional, default=NULL)- key of value to return from
/// $contdata or omit to get all of $contdata
/// \param $defaultval (optional, default=NULL) - default value in case $name
/// does not exist in $contdata
///
/// \return if $name is passed, $contdata[$name] or $defaultval; if $name is
/// omitted, $contdata
///
/// \brief returns the requested value from $contdata or a default value if
/// $name does not exist in $contdata; if both args are omitted, just return all
/// of $contdata
///
////////////////////////////////////////////////////////////////////////////////
function getContinuationVar($name=NULL, $defaultval=NULL) {
	global $contdata, $inContinuation;
	if($name === NULL) {
		return $contdata;
	}
	if(! $inContinuation)
		return $defaultval;
	if(array_key_exists($name, $contdata)) {
		if($contdata[$name] == 'zero')
			return 0;
		return $contdata[$name];
	}
	return $defaultval;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processInputData($data, $type, $addslashes, $defaultvalue)
///
/// \param $data - data to sanitize
/// \param $type - tag type:\n
/// \b ARG_NUMERIC - numeric\n
/// \b ARG_STRING - string\n
/// \b ARG_MULTINUMERIC - an array of numbers
/// \param $addslashes - (optional, defaults to 0) set to 1 if values should
/// have addslashes called to escape things
/// \param $defaultvalue - (optional, defaults to NULL) default value for the
/// variable
///
/// \return a sanitized version of $data
///
/// \brief sanitizes $data to keep bad stuff from being passed in
///
////////////////////////////////////////////////////////////////////////////////
function processInputData($data, $type, $addslashes=0, $defaultvalue=NULL) {
	if(strncmp("$data", "0", 1) == 0 &&
	   $type == ARG_NUMERIC &&
		strncmp("$data", "0x0", 3) != 0) {
		$data = "zero";
	}
	if(!empty($data))
		$return = $data;
	else {
		if($type == ARG_MULTINUMERIC || $type == ARG_MULTISTRING)
			$return = array();
		else
			$return = $defaultvalue;
	}
	if($return == "zero")
		$return = "0";

	if($type == ARG_MULTINUMERIC) {
		foreach($return as $index => $value) {
			$return[$index] = strip_tags($value);
			if($return[$index] == 'zero')
				$return[$index] = '0';
		}
	}
	elseif($type == ARG_MULTISTRING) {
		foreach($return as $index => $value) {
			$return[$index] = strip_tags($value);
		}
	}
	else
		$return = strip_tags($return);

	if(! empty($return) && $type == ARG_NUMERIC) {
		if(! is_numeric($return)) {
			return preg_replace('([^\d])', '', $return);
		}
	}
	elseif(! empty($return) && $type == ARG_STRING) {
		if(! is_string($return))
			$return = $defaultvalue;
	}
	elseif(! empty($return) && $type == ARG_MULTINUMERIC) {
		foreach($return as $index => $value) {
			if(! is_numeric($value)) {
				$return[$index] = preg_replace('([^\d])', '', $value);
			}
		}
		return $return;
	}
	elseif(! empty($return) && $type == ARG_MULTISTRING) {
		foreach($return as $index => $value) {
			if(! is_string($value))
				$return[$index] = $defaultvalue;
			elseif($addslashes)
				$return[$index] = addslashes($value);
		}
		return $return;
	}

	if(is_string($return)) {
		if(strlen($return) == 0)
			$return = $defaultvalue;
		elseif($addslashes)
			$return = addslashes($return);
	}

	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserInfo($id)
///
/// \param $id - unity ID for the user or user's id from database
///
/// \return 0 if fail to fetch data or $user - an array with these elements:\n
/// \b unityid - unity ID for the user\n
/// \b affiliationid - affiliation id of user\n
/// \b affiliation - affiliation of user\n
/// \b login - login ID for the user (unity ID or part before \@sign)\n
/// \b curriculum - curriculum user is in\n
/// \b firstname - user's first name\n
/// \b middlename - user's middle name\n
/// \b lastname - user's last name\n
/// \b preferredname - user's preferred name\n
/// \b email - user's preferred email address\n
/// \b emailnotices - bool for sending email notices to user\n
/// \b IMtype - user's preferred IM protocol\n
/// \b IMid - user's IM id\n
/// \b id - user's id from database\n
/// \b adminlevel - user's admin level (= 'none' if no admin access)\n
/// \b adminlevelid - id for user's adminlevel\n
/// \b width - pixel width for rdp files\n
/// \b height - pixel height for rdp files\n
/// \b bpp - color depth for rdp files\n
/// \b audiomode - 'none' or 'local' - audio mode for rdp files\n
/// \b mapdrives - 0 or 1 - map drives for rdp files; 1 means to map\n
/// \b mapprinters - 0 or 1 - map printers for rdp files; 1 means to map\n
/// \b mapserial - 0 or 1 - map serial ports for rdp files; 1 means to map\n
/// \b showallgroups - 0 or 1 - show only user groups matching user's
/// affiliation or show all user groups\n
/// \b lastupdated - datetime the information was last updated\n
/// \b groups - array of groups user is a member of where the index is the id
/// of the group and the value is the name of the group\n
/// \b privileges - array of privileges that the user has
///
/// \brief gets the user's information from the db and puts it into an array;
/// if the user is not in the db, query ldap and add them; if the user changed
/// their name and unity id; fix information in db based on numeric unity id
///
////////////////////////////////////////////////////////////////////////////////
function getUserInfo($id) {
	$affilid = DEFAULT_AFFILID;
	if(! is_numeric($id))
		getAffilidAndLogin($id, $affilid);

	$user = array();
	$query = "SELECT u.unityid AS unityid, "
	       .        "u.affiliationid, "
	       .        "af.name AS affiliation, "
	       .        "c.name AS curriculum, "
	       .        "u.firstname AS firstname, "
	       .        "u.middlename AS middlename, "
	       .        "u.lastname AS lastname, "
	       .        "u.preferredname AS preferredname, "
	       .        "u.email AS email, "
	       .        "u.emailnotices, "
	       .        "i.name AS IMtype, "
	       .        "u.IMid AS IMid, "
	       .        "u.id AS id, "
	       .        "a.name AS adminlevel, "
	       .        "a.id AS adminlevelid, "
	       .        "u.width AS width, "
	       .        "u.height AS height, "
	       .        "u.bpp AS bpp, "
	       .        "u.audiomode AS audiomode, "
	       .        "u.mapdrives AS mapdrives, "
	       .        "u.mapprinters AS mapprinters, "
	       .        "u.mapserial AS mapserial, "
	       .        "u.showallgroups, "
	       .        "u.lastupdated AS lastupdated, "
	       .        "af.shibonly "
	       . "FROM user u, "
	       .      "curriculum c, "
	       .      "IMtype i, "
	       .      "affiliation af, "
	       .      "adminlevel a "
	       . "WHERE u.curriculumid = c.id AND "
	       .       "u.IMtypeid = i.id AND "
	       .       "u.adminlevelid = a.id AND "
	       .       "u.affiliationid = af.id AND ";
	if(is_numeric($id))
		$query .= "u.id = $id";
	else
		$query .= "u.unityid = '$id' AND af.id = $affilid";

	$qh = doQuery($query, "105");
	if($user = mysql_fetch_assoc($qh)) {
		if((datetimeToUnix($user["lastupdated"]) > time() - SECINDAY) ||
		   $user['unityid'] == 'vclreload' ||
		   $user['affiliation'] == 'Local' ||
		   $user['shibonly']) {
			# get user's groups
			$user["groups"] = getUsersGroups($user["id"], 1);

			checkExpiredDemoUser($user['id'], $user['groups']);

			# get user's privileges
			$user["privileges"] = getOverallUserPrivs($user["id"]);

			if(preg_match('/@/', $user['unityid'])) {
				$tmparr = explode('@', $user['unityid']);
				$user['login'] = $tmparr[0];
			}
			else
				$user['login'] = $user['unityid'];

			return $user;
		}
	}
	if(is_numeric($id))
		return updateUserData($id, "numeric");
	return updateUserData($id, "loginid", $affilid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUsersGroups($userid, $includeowned)
///
/// \param $userid - an id from the user table
/// \param $includeowned - include groups the user owns but is not in
///
/// \return an array of the user's groups where the index is the id of the
/// group
///
/// \brief builds a array of the groups the user is member of
///
////////////////////////////////////////////////////////////////////////////////
function getUsersGroups($userid, $includeowned=0) {
	$query = "SELECT m.usergroupid, "
	       .        "g.name "
	       . "FROM usergroupmembers m, "
	       .      "usergroup g "
	       . "WHERE m.userid = $userid AND "
	       .       "m.usergroupid = g.id";
	$qh = doQuery($query, "101");
	$groups = array();
	while($row = mysql_fetch_assoc($qh)) {
		$groups[$row["usergroupid"]] = $row["name"];
	}
	if($includeowned) {
		$query = "SELECT id AS usergroupid, "
		       .        "name "
		       . "FROM usergroup "
		       . "WHERE ownerid = $userid";
		$qh = doQuery($query, "101");
		while($row = mysql_fetch_assoc($qh)) {
			$groups[$row["usergroupid"]] = $row["name"];
		}
	}
	uasort($groups, "sortKeepIndex");
	return $groups;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateUserData($id, $type, $affilid)
///
/// \param $id - user's unity id or id from user table
/// \param $type - (optional, default=loginid) - numericid or loginid
/// numericid is the user's numeric id; loginid is the other form (ie a unity
/// id)
/// \param $affilid - (optional, default=DEFAULT_AFFILID) - affiliation id
///
/// \return 0 if fail to update data or an array with these elements:\n
/// \b id - user's numeric unity id\n
/// \b unityid - unity ID for the user\n
/// \b affiliation - user's affiliation\n
/// \b affiliationid - user's affiliation id\n
/// \b curriculum - curriculum user is in\n
/// \b firstname - user's first name\n
/// \b middlename - user's middle name\n
/// \b lastname - user's last name\n
/// \b email - user's preferred email address\n
/// \b IMtype - user's preferred IM protocol\n
/// \b IMid - user's IM id\n
/// \b adminlevel - user's admin level (= 'none' if no admin access)\n
/// \b lastupdated - datetime the information was last updated
///
/// \brief looks up the logged in user's info in ldap and updates it in the db
/// or adds it to the db
///
////////////////////////////////////////////////////////////////////////////////
function updateUserData($id, $type="loginid", $affilid=DEFAULT_AFFILID) {
	global $updateUserFunc, $updateUserFuncArgs;
	if($type == 'numeric') {
		$query = "SELECT unityid, "
		       .        "affiliationid "
		       . "FROM user "
		       . "WHERE id = $id";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh)) {
			$id = $row['unityid'];
			$type = 'loginid';
			$affilid = $row['affiliationid'];
		}
		else
			abort(1);
	}
	$updateFunc = $updateUserFunc[$affilid];
	if(array_key_exists($affilid, $updateUserFuncArgs))
		return $updateFunc($updateUserFuncArgs[$affilid], $id);
	else
		return $updateFunc($id);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addUser($loginid)
///
/// \param $loginid - a login id
///
/// \return id from userlist table for the user, NULL if userid not in table
///
/// \brief looks up the user via LDAP and adds to DB
///
////////////////////////////////////////////////////////////////////////////////
function addUser($loginid) {
	global $addUserFuncArgs, $addUserFunc;
	getAffilidAndLogin($loginid, $affilid);
	if(empty($affilid))
		abort(11);
	$addfunc = $addUserFunc[$affilid];
	if(array_key_exists($affilid, $addUserFuncArgs))
		return $addfunc($addUserFuncArgs[$affilid], $loginid);
	else
		return $addfunc($loginid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateUserPrefs($userid, $preferredname, $width, $height, $bpp, 
///                              $audio, $mapdrives, $mapprinters, $mapserial)
///
/// \param $userid - id from user table
/// \param $preferredname - user's preferred name
/// \param $width - pixel width for rdp files
/// \param $height - pixel height for rdp files
/// \param $bpp - color depth for rdp files
/// \param $audio - 'none' or 'local' - audio preference for rdp files
/// \param $mapdrives - 0 or 1 - 1 to map local drives in rdp files
/// \param $mapprinters - 0 or 1 - 1 to map printers in rdp files
/// \param $mapserial - 0 or 1 - 1 to map serial ports in rdp files
///
/// \return number of rows affected by update (\b NOTE: this may be 0 if none
/// of the values were actually changes
///
/// \brief updates the preferences for the user
///
////////////////////////////////////////////////////////////////////////////////
function updateUserPrefs($userid, $preferredname, $width, $height,
                         $bpp, $audio, $mapdrives, $mapprinters, $mapserial) {
	global $mysql_link_vcl;
	$query = "UPDATE user SET "
	       .        "preferredname = '$preferredname', "
	       .        "width = '$width', "
	       .        "height = '$height', "
	       .        "bpp = $bpp, "
	       .        "audiomode = '$audio', "
	       .        "mapdrives = $mapdrives, "
	       .        "mapprinters = $mapprinters, "
	       .        "mapserial = $mapserial "
	       . "WHERE id = $userid";
	doQuery($query, 270);
	return mysql_affected_rows($mysql_link_vcl);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getOverallUserPrivs($userid)
///
/// \param $userid - an id from the user table
///
/// \return an array of privileges types that the user has somewhere in the 
/// privilege tree
///
/// \brief get the privilege types that the user has somewhere in the
/// privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function getOverallUserPrivs($userid) {
	$query = "SELECT DISTINCT t.name "
	       . "FROM userprivtype t, "
	       .      "userpriv u "
	       . "WHERE u.userprivtypeid = t.id AND "
	       .       "(u.userid = $userid OR "
	       .       "u.usergroupid IN (SELECT usergroupid "
	       .                         "FROM usergroupmembers "
	       .                         "WHERE userid = $userid) OR "
	       .       "u.usergroupid IN (SELECT id "
	       .                         "FROM usergroup "
	       .                         "WHERE ownerid = $userid))";
	$qh = doQuery($query, 107);
	$privileges = array();
	while($row = mysql_fetch_row($qh)) {
		array_push($privileges, $row[0]);
	}
	return $privileges;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn isAvailable($images, $imageid, $start, $end, $os, $requestid,
///                          $userid, $ignoreprivileges, $forimaging)
///
/// \param $images - array as returned from getImages
/// \param $imageid - imageid from the image table
/// \param $start - unix timestamp for start of reservation
/// \param $end - unix timestamp for end of reservation
/// \param $os - preferred OS that matches a name entry in the OS table
/// \param $requestid - (optional) a requestid; if checking for an available
/// timeslot to update a request, pass the request id that will be updated;
/// otherwise, don't pass this argument
/// \param $userid - (optional) id from user table
/// \param $ignoreprivileges (optional, default=0) - 0 (false) or 1 (true) - set
/// to 1 to look for computers from any that are mapped to be able to run the
/// image; set to 0 to only look for computers from ones that are both mapped
/// and that $userid has been granted access to through the privilege tree
/// \param $forimaging - (optional, default=0) - 0 if normal reservation, 1 if
/// an imaging reservation
///
/// \return -1 if $imageid is limited in the number of concurrent reservations
///         available, and the limit has been reached
///         0 if combination is not available\n
///         an integer >0 if it is available
///
/// \brief checks that the passed in arguments constitute an available request
///
////////////////////////////////////////////////////////////////////////////////
function isAvailable($images, $imageid, $start, $end, $os, $requestid=0,
                     $userid=0, $ignoreprivileges=0, $forimaging=0) {
	global $requestInfo;
	$requestInfo["start"] = $start;
	$requestInfo["end"] = $end;
	$requestInfo["imageid"] = $imageid;
	$allocatedcompids = array(0);

	if($requestInfo["start"] <= time()) {
		$now = 1;
		$nowfuture = 'now';
	}
	else {
		$now = 0;
		$nowfuture = 'future';
	}

	# get list of schedules
	$starttime = minuteOfWeek($start);
	$endtime = minuteOfWeek($end);

	# request is within a single week
	if(weekOfYear($start) == weekOfYear($end)) {
		$query = "SELECT scheduleid "
		       . "FROM scheduletimes "
		       . "WHERE start <= $starttime AND "
		       .       "end >= $endtime";
	}
	# request covers at least a week's worth of time
	elseif($end - $start >= SECINDAY * 7) {
		$query = "SELECT scheduleid "
		       . "FROM scheduletimes "
		       . "WHERE start = 0 AND "
		       .       "end = 10080";
	}
	# request starts in one week and ends in the following week
	else {
		$query = "SELECT s1.scheduleid "
		       . "FROM scheduletimes s1, "
		       .      "scheduletimes s2 "
		       . "WHERE s1.scheduleid = s2.scheduleid AND "
		       .       "s1.start <= $starttime AND "
		       .       "s1.end = 10080 AND "
		       .       "s2.start = 0 AND "
		       .       "s2.end >= $endtime";
	}

	$scheduleids = array();
	$qh = doQuery($query, 127);
	while($row = mysql_fetch_row($qh)) {
		array_push($scheduleids, $row[0]);
	}

	$requestInfo["computers"] = array();
	$requestInfo["computers"][0] = 0;
	$requestInfo["images"][0] = $imageid;

	# loop to check for available computers for all needed images
	if(! $forimaging && $images[$imageid]["imagemetaid"] != NULL) {
		$count = 1;
		foreach($images[$imageid]["subimages"] as $imgid) {
			$requestInfo['computers'][$count] = 0;
			$requestInfo['images'][$count] = $imgid;
			$count++;
		}
	}

	// get semaphore lock
	if(! semLock())
		abort(3);

	if($requestid)
		$requestData = getRequestInfo($requestid);
	$startstamp = unixToDatetime($start);
	$endstamp = unixToDatetime($end + 900);
	foreach($requestInfo["images"] as $key => $imageid) {
		#$osid = getOSid($os);
		# check for max concurrent usage of image
		if($images[$imageid]['maxconcurrent'] != NULL) {
			$query = "SELECT COUNT(rs.imageid) AS currentusage "
			       . "FROM reservation rs, "
			       .      "request rq "
			       . "WHERE '$startstamp' < (rq.end + INTERVAL 900 SECOND) AND "
			       .       "'$endstamp' > rq.start AND "
			       .       "rs.requestid = rq.id AND "
			       .       "rs.imageid = $imageid AND "
			       .       "rq.stateid NOT IN (1,5,11,12,16,17)";
			$qh = doQuery($query, 101);
			if(! $row = mysql_fetch_assoc($qh)) {
				semUnlock();
				return 0;
			}
			if($row['currentusage'] >= $images[$imageid]['maxconcurrent']) {
				semUnlock();
				return -1;
			}
		}

		# get platformid that matches $imageid
		$query = "SELECT platformid FROM image WHERE id = $imageid";
		$qh = doQuery($query, 125);
		if(! $row = mysql_fetch_row($qh)) {
			semUnlock();
			return 0;
		}
		$platformid = $row[0];

		# get computers $imageid maps to
		$tmp = getMappedResources($imageid, "image", "computer");
		if(! count($tmp)) {
			semUnlock();
			return 0;
		}
		$mappedcomputers = implode(',', $tmp);

		#get computers for available schedules and platforms
		$computerids = array();
		$currentids = array();
		$blockids = array();
		$skipRemoveUsedBlock = 0;
		// if we are modifying a request and it is after the start time, only allow
		// the scheduled computer(s) to be modified
		if($requestid && datetimeToUnix($requestData["start"]) <= time()) {
			$skipRemoveUsedBlock = 1;
			foreach($requestData["reservations"] as $key2 => $res) {
				if($res["imageid"] == $imageid) {
					$compid = $res["computerid"];
					unset($requestData['reservations'][$key2]);
					break;
				}
			}
			array_push($computerids, $compid);
			array_push($currentids, $compid);
			$query = "SELECT scheduleid "
			       . "FROM computer "
			       . "WHERE id = $compid";
			$qh = doQuery($query, 128);
			$row = mysql_fetch_row($qh);
			if(! in_array($row[0], $scheduleids)) {
				semUnlock();
				return 0;
			}
		}
		// otherwise, build a list of computers
		else {
			# get list of available computers
			if(! $ignoreprivileges) {
				$resources = getUserResources(array("imageAdmin", "imageCheckOut"),
				                              array("available"), 0, 0, $userid);
				$usercomputers = implode("','", array_keys($resources["computer"]));
				$usercomputers = "'$usercomputers'";
			}
			$alloccompids = implode(",", $allocatedcompids);

			$schedules = implode(',', $scheduleids);

			$query = "SELECT DISTINCT c.id, "
			       .                 "c.currentimageid "
			       . "FROM computer c, "
			       .      "image i, "
			       .      "state s "
			       . "WHERE c.scheduleid IN ($schedules) AND "
			       .       "c.platformid = $platformid AND "
			       .       "c.stateid = s.id AND "
			       .       "s.name != 'maintenance' AND "
			       .       "s.name != 'vmhostinuse' AND "
			       .       "s.name != 'hpc' AND "
			       .       "s.name != 'failed' AND ";
			if($now)
				$query .=   "s.name != 'reloading' AND "
				       .    "s.name != 'reload' AND "
				       .    "s.name != 'timeout' AND "
				       .    "s.name != 'inuse' AND ";
			$query .=      "i.id = $imageid AND "
			       .       "c.RAM >= i.minram AND "
			       .       "c.procnumber >= i.minprocnumber AND "
			       .       "c.procspeed >= i.minprocspeed AND "
			       .       "c.network >= i.minnetwork AND ";
			if(! $ignoreprivileges)
				$query .=   "c.id IN ($usercomputers) AND ";
			$query .=      "c.id IN ($mappedcomputers) AND "
			       .       "c.id NOT IN ($alloccompids) "
			       . "ORDER BY (c.procspeed * c.procnumber) DESC, "
			       .          "RAM DESC, "
			       .          "network DESC";
			$qh = doQuery($query, 129);
			while($row = mysql_fetch_assoc($qh)) {
				array_push($computerids, $row['id']);
				if($row['currentimageid'] == $imageid) {
					array_push($currentids, $row['id']);
				}
			}
			# get computer ids available from block reservations
			$blockids = getAvailableBlockComputerids($imageid, $start, $end,
			                                         $allocatedcompids);
		}

		#remove computers from list that are already scheduled
		$usedComputerids = array();
		$query = "SELECT DISTINCT rs.computerid "
		       . "FROM reservation rs, "
		       .      "request rq, "
		       .      "user u "
		       . "WHERE '$startstamp' < (rq.end + INTERVAL 900 SECOND) AND "
		       .       "'$endstamp' > rq.start AND "
		       .       "rq.id != $requestid AND "
		       .       "rs.requestid = rq.id AND "
		       .       "rq.stateid != 1 AND "
		       .       "rq.stateid != 5 AND "
		       .       "rq.stateid != 12 AND "
		       .       "rq.userid = u.id AND "
		       .       "u.unityid != 'vclreload'";
		$qh = doQuery($query, 130);
		while($row = mysql_fetch_row($qh)) {
			array_push($usedComputerids, $row[0]);
		}

		$computerids = array_diff($computerids, $usedComputerids);
		$currentids = array_diff($currentids, $usedComputerids);
		$blockids = array_diff($blockids, $usedComputerids);

		# remove computers from list that are allocated to block reservations
		if(! count($blockids) && ! $skipRemoveUsedBlock) {
			$usedBlockCompids = getUsedBlockComputerids($start, $end);
			$computerids = array_diff($computerids, $usedBlockCompids);
			$currentids = array_diff($currentids, $usedBlockCompids);
		}

		$comparr = allocComputer($blockids, $currentids, $computerids,
		                         $startstamp, $nowfuture);
		if(empty($comparr)) {
			semUnlock();
			return 0;
		}
		$requestInfo["computers"][$key] = $comparr['compid'];
		$requestInfo["mgmtnodes"][$key] = $comparr['mgmtid'];
		$requestInfo["loaded"][$key] = $comparr['loaded'];
		array_push($allocatedcompids, $comparr['compid']);
	}

	return 1;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn RPCisAvailable($imageid, $start, $end, $userid)
///
/// \param $imageid - imageid from the image table
/// \param $start - unix timestamp for start of reservation
/// \param $end - unix timestamp for end of reservation
/// \param $userid - id from user table
///
/// \return a computer id
///
/// \brief checks that the passed in arguments constitute an available request
///
////////////////////////////////////////////////////////////////////////////////
function RPCisAvailable($imageid, $start, $end, $userid) {
	#FIXME this function doesn't properly handle cluster reservations
	global $requestInfo;
	$images = getImages();

	$requestInfo["start"] = $start;
	$requestInfo["end"] = $end;
	$requestInfo["imageid"] = $imageid;
	$allocatedcompids = array(0);

	if($requestInfo["start"] <= time())
		$now = 1;
	else
		$now = 0;

	# get list of schedules
	$starttime = minuteOfWeek($start);
	$endtime = minuteOfWeek($end);

	# request is within a single week
	if(weekOfYear($start) == weekOfYear($end)) {
		$query = "SELECT scheduleid "
		       . "FROM scheduletimes "
		       . "WHERE start <= $starttime AND "
		       .       "end >= $endtime";
	}
	# request covers at least a week's worth of time
	elseif($end - $start >= SECINDAY * 7) {
		$query = "SELECT scheduleid "
		       . "FROM scheduletimes "
		       . "WHERE start = 0 AND "
		       .       "end = 10080";
	}
	# request starts in one week and ends in the following week
	else {
		$query = "SELECT s1.scheduleid "
		       . "FROM scheduletimes s1, "
		       .      "scheduletimes s2 "
		       . "WHERE s1.scheduleid = s2.scheduleid AND "
		       .       "s1.start <= $starttime AND "
		       .       "s1.end = 10080 AND "
		       .       "s2.start = 0 AND "
		       .       "s2.end >= $endtime";
	}

	$scheduleids = array();
	$qh = doQuery($query, 127);
	while($row = mysql_fetch_row($qh)) {
		array_push($scheduleids, $row[0]);
	}

	$requestInfo["computers"] = array();
	$requestInfo["computers"][0] = 0;
	$requestInfo["images"][0] = $imageid;

	# loop to check for available computers for all needed images
	if($images[$imageid]["imagemetaid"] != NULL) {
		$count = 1;
		foreach($images[$imageid]["subimages"] as $imgid) {
			$requestInfo['computers'][$count] = 0;
			$requestInfo['images'][$count] = $imgid;
			$count++;
		}
	}

	// get semaphore lock
	if(! semLock())
		abort(3);

	$startstamp = unixToDatetime($start);
	$endstamp = unixToDatetime($end + 900);
	foreach($requestInfo["images"] as $key => $imageid) {
		#$osid = getOSid($os);
		# check for max concurrent usage of image
		if($images[$imageid]['maxconcurrent'] != NULL) {
			$query = "SELECT COUNT(rs.imageid) AS currentusage "
			       . "FROM reservation rs, "
			       .      "request rq "
			       . "WHERE '$startstamp' < rq.end AND "
			       .       "'$endstamp' > (rq.start - INTERVAL 900 SECOND) AND "
			       .       "rs.requestid = rq.id AND "
			       .       "rs.imageid = $imageid AND "
			       .       "rq.stateid NOT IN (1,5,11,12,16,17)";
			$qh = doQuery($query, 101);
			if(! $row = mysql_fetch_assoc($qh)) {
				semUnlock();
				return 0;
			}
			if($row['currentusage'] >= $images[$imageid]['maxconcurrent']) {
				semUnlock();
				return -1;
			}
		}

		# get platformid that matches $imageid
		$query = "SELECT platformid FROM image WHERE id = $imageid";
		$qh = doQuery($query, 125);
		if(! $row = mysql_fetch_row($qh)) {
			semUnlock();
			return 0;
		}
		$platformid = $row[0];

		# get computers $imageid maps to
		$tmp = getMappedResources($imageid, "image", "computer");
		if(! count($tmp)) {
			semUnlock();
			return 0;
		}
		$mappedcomputers = implode(',', $tmp);

		# get computers for available schedules and platforms
		$computerids = array();
		$currentids = array();
		$blockids = array();
		# get list of available computers
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"),
												array("available"), 0, 0, $userid);
		$computers = implode("','", array_keys($resources["computer"]));
		$computers = "'$computers'";
		$alloccompids = implode(",", $allocatedcompids);

		$schedules = implode(',', $scheduleids);

		$query = "SELECT DISTINCT c.id, "
		       .                 "c.currentimageid "
		       . "FROM computer c, "
		       .      "image i, "
		       .      "state s "
		       . "WHERE c.scheduleid IN ($schedules) AND "
		       .       "c.platformid = $platformid AND "
		       .       "c.stateid = s.id AND "
		       .       "s.name != 'maintenance' AND "
		       .       "s.name != 'vmhostinuse' AND "
		       .       "s.name != 'hpc' AND "
		       .       "s.name != 'failed' AND ";
		if($now)
			$query .=   "s.name != 'reloading' AND "
			       .    "s.name != 'timeout' AND "
			       .    "s.name != 'inuse' AND ";
		$query .=      "i.id = $imageid AND "
		       .       "c.RAM >= i.minram AND "
		       .       "c.procnumber >= i.minprocnumber AND "
		       .       "c.procspeed >= i.minprocspeed AND "
		       .       "c.network >= i.minnetwork AND "
		       .       "c.id IN ($computers) AND "
		       .       "c.id IN ($mappedcomputers) AND "
		       .       "c.id NOT IN ($alloccompids) "
		       . "ORDER BY (c.procspeed * c.procnumber) DESC, "
		       .          "RAM DESC, "
		       .          "network DESC";
		$qh = doQuery($query, 129);
		while($row = mysql_fetch_assoc($qh)) {
			array_push($computerids, $row['id']);
			if($row['currentimageid'] == $imageid) {
				array_push($currentids, $row['id']);
			}
		}
		# get computer ids available from block reservations
		$blockids = getAvailableBlockComputerids($imageid, $start, $end,
		                                         $allocatedcompids);

		# remove computers from list that are already scheduled
		$usedComputerids = array();
		$query = "SELECT DISTINCT rs.computerid "
		       . "FROM reservation rs, "
		       .      "request rq, "
		       .      "user u "
		       . "WHERE '$startstamp' < rq.end AND "
		       .       "'$endstamp' > (rq.start - INTERVAL 900 SECOND) AND "
		       .       "rs.requestid = rq.id AND "
		       .       "rq.stateid != 1 AND "
		       .       "rq.stateid != 5 AND "
		       .       "rq.stateid != 12 AND "
		       .       "rq.userid = u.id AND "
		       .       "u.unityid != 'vclreload'";
		$qh = doQuery($query, 130);
		while($row = mysql_fetch_row($qh)) {
			array_push($usedComputerids, $row[0]);
		}

		$computerids = array_diff($computerids, $usedComputerids);
		$currentids = array_diff($currentids, $usedComputerids);
		$blockids = array_diff($blockids, $usedComputerids);

		if(count($currentids))
			$return = array_shift($currentids);
		elseif(count($computerids))
			$return = array_shift($computerids);
		else {
			$return = 0;
		}
	}
	semUnlock();

	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn allocComputer($blockids, $currentids, $computerids, $start,
///                   $nowfuture)
///
/// \param $blockids - array of computer ids
/// \param $currentids - array of computer ids
/// \param $computerids - array of computer ids
/// \param $start - start time in datetime format
/// \param $nowfuture - "now" or "future"
///
/// \return empty array if failed to allocate a computer; array with these keys
/// on success:\n
/// \b compid - id of computer\n
/// \b mgmtid - id of management node for computer\n
/// \b loaded - 0 or 1 - whether or not computer is loaded with desired image
///
/// \brief determines a computer to use from $blockids, $currentids,
/// $preferredids, and $computerids, looking at the arrays in that order and
/// tries to allocate a management node for it
///
////////////////////////////////////////////////////////////////////////////////
function allocComputer($blockids, $currentids, $computerids, $start,
                       $nowfuture) {
	$ret = array();
	foreach($blockids as $compid) {
		$mgmtnodeid = findManagementNode($compid, $start, $nowfuture);
		if($mgmtnodeid == 0)
			continue;
		$ret['compid'] = $compid;
		$ret['mgmtid'] = $mgmtnodeid;
		$ret['loaded'] = 1;
		return $ret;
	}
	foreach($currentids as $compid) {
		$mgmtnodeid = findManagementNode($compid, $start, $nowfuture);
		if($mgmtnodeid == 0)
			continue;
		$ret['compid'] = $compid;
		$ret['mgmtid'] = $mgmtnodeid;
		$ret['loaded'] = 1;
		return $ret;
	}
	foreach($computerids as $compid) {
		$mgmtnodeid = findManagementNode($compid, $start, $nowfuture);
		if($mgmtnodeid == 0)
			continue;
		$ret['compid'] = $compid;
		$ret['mgmtid'] = $mgmtnodeid;
		$ret['loaded'] = 0;
		return $ret;
	}
	return $ret;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMappedResources($resourcesubid, $resourcetype1,
///                                 $resourcetype2)
///
/// \param $resourcesubid - id of a resource from its table (ie an imageid)
/// \param $resourcetype1 - type of $resourcesubid (name or id)
/// \param $resourcetype2 - type of resource $resourcesubid maps to
///
/// \return an array of resource ids of type $resourcetype2
///
/// \brief gets a list of resources of type $resourcetype2 that $resourcesubid 
/// of type $resourcetype1 maps to based on the resourcemap table
///
////////////////////////////////////////////////////////////////////////////////
function getMappedResources($resourcesubid, $resourcetype1, $resourcetype2) {
	if(! is_numeric($resourcetype1))
		$resourcetype1 = getResourceTypeID($resourcetype1);
	if(! is_numeric($resourcetype2))
		$resourcetype2 = getResourceTypeID($resourcetype2);

	# get $resourcesubid's resource id
	$query = "SELECT id "
	       . "FROM resource "
	       . "WHERE subid = $resourcesubid AND "
	       .       "resourcetypeid = $resourcetype1";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_row($qh);
	$resourceid = $row[0];

	# get groups $resourceid is in
	$resourcegroupids = array();
	$query = "SELECT resourcegroupid "
	       . "FROM resourcegroupmembers "
	       . "WHERE resourceid = $resourceid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_row($qh)) {
		array_push($resourcegroupids, $row[0]);
	}

	# get $resourcetype2 groups that $resourcegroupids map to
	if(! count($resourcegroupids))
		return array();
	$inlist = implode(',', $resourcegroupids);
	$type2groupids = array();

	# get all mappings from resourcemap table where $resourcetype1 ==
	#   resourcemap.resourcetypeid1
	$query = "SELECT resourcegroupid2 "
	       . "FROM resourcemap "
	       . "WHERE resourcegroupid1 IN ($inlist) AND "
	       .       "resourcetypeid1 = $resourcetype1 AND "
	       .       "resourcetypeid2 = $resourcetype2";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_row($qh)) {
		array_push($type2groupids, $row[0]);
	}

	# get all mappings from resourcemap table where $resourcetype1 ==
	#   resourcemap.resourcetypeid2
	$query = "SELECT resourcegroupid1 "
	       . "FROM resourcemap "
	       . "WHERE resourcegroupid2 IN ($inlist) AND "
	       .       "resourcetypeid2 = $resourcetype1 AND "
	       .       "resourcetypeid1 = $resourcetype2";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_row($qh)) {
		array_push($type2groupids, $row[0]);
	}

	# get $resourcetype2 items in $type2groupids groups
	if(! count($type2groupids))
		return array();
	$inlist = implode(',', $type2groupids);
	$mappedresources = array();
	$query = "SELECT r.subid "
	       . "FROM resource r, "
	       .      "resourcegroupmembers m "
	       . "WHERE m.resourcegroupid IN ($inlist) AND "
	       .       "m.resourceid = r.id";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_row($qh)) {
		array_push($mappedresources, $row[0]);
	}
	return $mappedresources;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkOverlap($start, $end, $max, $requestid)
///
/// \param $start - unix timestamp for start of reservation
/// \param $end - unix timestamp for end of reservation
/// \param $max - max allowed overlapping reservations
/// \param $requestid - (optional) a requestid to ignore when checking for an
/// overlap; use this when changing an existing request
///
/// \return 0 if user doesn't have a reservation overlapping the time period
/// between $start and $end; 1 if the user does
///
/// \brief checks for a user having an overlapping reservation with the
/// specified time period
///
////////////////////////////////////////////////////////////////////////////////
function checkOverlap($start, $end, $max, $requestid=0) {
	global $user;
	$requests = getUserRequests("all");
	$count = 0;
	if($max > 0)
		$max--;
	foreach(array_keys($requests) as $id) {
		if(! (($requests[$id]["currstateid"] == 12 ||
		   $requests[$id]["currstateid"] == 14) &&
		   $requests[$id]["laststateid"] == 11) &&
		   $requests[$id]["currstateid"] != 5 &&
		   $requests[$id]["id"] != $requestid &&
		   ($start < datetimeToUnix($requests[$id]["end"]) &&
		   $end > datetimeToUnix($requests[$id]["start"]))) {
			$count++;
			if($count > $max)
				return 1;
		}
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getReloadStartTime()
///
/// \return unix timestamp
///
/// \brief determines the nearest 15 minute increment of an hour that is less
/// than the current time
///
////////////////////////////////////////////////////////////////////////////////
function getReloadStartTime() {
	$nowArr = getdate();
	if($nowArr["minutes"] == 0)
		$subtract = 0;
	elseif($nowArr["minutes"] < 15)
		$subtract = $nowArr["minutes"] * 60;
	elseif($nowArr["minutes"] < 30)
		$subtract = ($nowArr["minutes"] - 15) * 60;
	elseif($nowArr["minutes"] < 45)
		$subtract = ($nowArr["minutes"] - 30) * 60;
	elseif($nowArr["minutes"] < 60)
		$subtract = ($nowArr["minutes"] - 45) * 60;
	$start = time() - $subtract;
	$start -= $start % 60;
	return $start;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMaxOverlap($userid)
///
/// \param $userid - id from user table
///
/// \return max number of allowed overlapping reservations for user
///
/// \brief determines how many overlapping reservations $user can have based on
/// the groups $user is a member of
///
////////////////////////////////////////////////////////////////////////////////
function getMaxOverlap($userid) {
	$query = "SELECT u.overlapResCount "
	       . "FROM usergroup u, "
	       .      "usergroupmembers m "
	       . "WHERE m.usergroupid = u.id AND "
	       .       "m.userid = $userid "
	       . "ORDER BY u.overlapResCount DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		return $row['overlapResCount'];
	else
		return 1;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addRequest($forimaging, $revisionid)
///
/// \param $forimaging - (optional) 0 if a normal request, 1 if a request for
/// creating a new image
/// \param $revisionid - (optional) desired revision id of the image
///
/// \return id from request table that corresponds to the added entry
///
/// \brief adds an entry to the request and reservation tables
///
////////////////////////////////////////////////////////////////////////////////
function addRequest($forimaging=0, $revisionid=array()) {
	global $requestInfo, $user;
	$startstamp = unixToDatetime($requestInfo["start"]);
	$endstamp = unixToDatetime($requestInfo["end"]);
	$now = time();

	if($requestInfo["start"] <= $now) {
		$start = unixToDatetime($now);
		$nowfuture = "now";
	}
	else {
		$start = $startstamp;
		$nowfuture = "future";
	}

	addLogEntry($nowfuture, $start, $endstamp, 1, $requestInfo["imageid"]);

	$qh = doQuery("SELECT LAST_INSERT_ID() FROM log", 131);
	if(! $row = mysql_fetch_row($qh)) {
		abort(132);
	}
	$logid = $row[0];

	$query = "INSERT INTO changelog "
	       .        "(logid, "
	       .        "start, "
	       .        "end, "
	       .        "timestamp) "
	       . "VALUES "
	       .        "($logid, "
	       .        "'$start', "
	       .        "'$endstamp', "
	       .        "NOW())";
	doQuery($query, 136);

	# add single entry to request table
	$query = "INSERT INTO request "
	       .        "(stateid, "
	       .        "userid, "
	       .        "laststateid, "
	       .        "logid, "
	       .        "forimaging, "
			 .        "start, "
			 .        "end, "
			 .        "daterequested) "
	       . "VALUES "
	       .       "(13, "
	       .       "{$user['id']}, "
	       .       "13, "
	       .       "$logid, "
	       .       "$forimaging, "
			 .       "'$startstamp', "
			 .       "'$endstamp', "
			 .       "NOW())";
	$qh = doQuery($query, 136);

	$qh = doQuery("SELECT LAST_INSERT_ID() FROM request", 134);
	if(! $row = mysql_fetch_row($qh)) {
		abort(135);
	}
	$requestid = $row[0];

	# add requestid to log entry
	$query = "UPDATE log "
	       . "SET requestid = $requestid "
	       . "WHERE id = $logid";
	doQuery($query, 101);

	# add an entry to the reservation table for each image
	# NOTE: make sure parent image is the first entry we add
	#   so that it has the lowest reservationid
	foreach($requestInfo["images"] as $key => $imageid) {
		if(array_key_exists($imageid, $revisionid) &&
		   ! empty($revisionid[$imageid]))
			$imagerevisionid = $revisionid[$imageid];
		else
			$imagerevisionid = getProductionRevisionid($imageid);
		$computerid = $requestInfo["computers"][$key];

		$mgmtnodeid = $requestInfo['mgmtnodes'][$key];

		$query = "INSERT INTO reservation "
				 .        "(requestid, "
				 .        "computerid, "
				 .        "imageid, "
				 .        "imagerevisionid, "
				 .        "managementnodeid) "
				 . "VALUES "
				 .       "($requestid, "
				 .       "$computerid, "
				 .       "$imageid, "
				 .       "$imagerevisionid, "
				 .       "$mgmtnodeid)";
		doQuery($query, 133);
		addSublogEntry($logid, $imageid, $imagerevisionid, $computerid, $mgmtnodeid);
	}
	// release semaphore lock
	semUnlock();

	return $requestid;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn simpleAddRequest($compid, $imageid, $revisionid, $start, $end,
///                               $stateid, $userid) {
///
/// \param $compid - a computer id
/// \param $imageid - an iamge id
/// \param $revisionid - revisionid for $imageid
/// \param $start - starting time in datetime format
/// \param $end - ending time in datetime format
/// \param $stateid - state for request
/// \param $userid - userid for request
///
/// \return id for the request or 0 on failure
///
/// \brief adds an entry to the request and reservation tables
///
////////////////////////////////////////////////////////////////////////////////
function simpleAddRequest($compid, $imageid, $revisionid, $start, $end,
                          $stateid, $userid) {
	$mgmtnodeid = findManagementNode($compid, $start, 'now');
	if($mgmtnodeid == 0)
		return 0;

	$query = "INSERT INTO request "
	       .        "(stateid, "
	       .        "userid, "
	       .        "laststateid, "
			 .        "start, "
			 .        "end, "
			 .        "daterequested) "
	       . "VALUES "
	       .       "($stateid, "
	       .       "$userid, "
	       .       "$stateid, "
			 .       "'$start', "
			 .       "'$end', "
			 .       "NOW())";
	doQuery($query, 101);

	$qh = doQuery("SELECT LAST_INSERT_ID() FROM request", 101);
	if(! $row = mysql_fetch_row($qh)) {
		abort(135);
	}
	$requestid = $row[0];

	# add an entry to the reservation table for each image
	$query = "INSERT INTO reservation "
			 .        "(requestid, "
			 .        "computerid, "
			 .        "imageid, "
			 .        "imagerevisionid, "
			 .        "managementnodeid) "
			 . "VALUES "
			 .       "($requestid, "
			 .       "$compid, "
			 .       "$imageid, "
			 .       "$revisionid, "
			 .       "$mgmtnodeid)";
	doQuery($query, 101);
	return $requestid;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn findManagementNode($compid, $start, $nowfuture)
///
/// \param $compid - a computer id
/// \param $start - start time for the reservation (datetime format)
/// \param $nowfuture - type of reservation - "now" or "future"
///
/// \return a management node id
///
/// \brief finds a management node that can handle $compid, if none found,
/// returns 0
///
////////////////////////////////////////////////////////////////////////////////
function findManagementNode($compid, $start, $nowfuture) {
	global $HTMLheader;
	$allmgmtnodes = array_keys(getManagementNodes($nowfuture));
	$mapped = getMappedResources($compid, "computer", "managementnode");
	$usablemgmtnodes = array_intersect($allmgmtnodes, $mapped);
	$mgmtnodecnt = array();
	foreach($usablemgmtnodes as $id) {
		$mgmtnodecnt[$id] = 0;
	}
	if(! count($usablemgmtnodes))
		return 0;
	$inlist = implode(',', $usablemgmtnodes);
	$mystart = datetimeToUnix($start);
	$start = unixToDatetime($mystart - 1800);
	$end = unixToDatetime($mystart + 1800);
	$query = "SELECT DISTINCT COUNT(rs.managementnodeid) AS count, "
	       .        "rs.managementnodeid AS mnid "
	       . "FROM reservation rs, "
	       .      "request rq "
	       . "WHERE rs.managementnodeid IN ($inlist) AND "
	       .       "rq.start > \"$start\" AND "
	       .       "rq.start < \"$end\" "
	       . "GROUP BY rs.managementnodeid "
	       . "ORDER BY count";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		$mgmtnodecnt[$row["mnid"]] = $row["count"];
	}
	uasort($mgmtnodecnt, "sortKeepIndex");
	$keys = array_keys($mgmtnodecnt);
	return array_shift($keys);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getRequestInfo($id)
///
/// \param $id - id of request
///
/// \return an array containing the following elements:\n
/// \b stateid - stateid of the request\n
/// \b laststateid - laststateid of the request\n
/// \b userid - id from the db of the user\n
/// \b start - start of request\n
/// \b end - end of request\n
/// \b daterequested - date request was made\n
/// \b datemodified - date request was last modified\n
/// \b id - id of this request\n
/// \b logid - id from log table\n
/// \b test - test flag\n
/// \b forimaging - 0 if request is normal, 1 if it is for imaging\n\n
/// an array of reservations associated with the request whose key is
/// 'reservations', each with the following items:\n
/// \b imageid - id of the image\n
/// \b imagerevisionid - id of the image revision\n
/// \b production - image revision production flag (0 or 1)\n
/// \b image - name of the image\n
/// \b prettyimage - pretty name of the image\n
/// \b OS - name of the os\n
/// \b computerid - id of the computer\n
/// \b reservationid - id of the corresponding reservation\n
/// \b reservedIP - ip address of reserved computer\n
/// \b hostname - hostname of reserved computer\n
/// \b forcheckout - whether or not the image is intended for checkout\n
/// \b password - password for this computer\n
/// \b remoteIP - IP of remote user
///
/// \brief creates an array with info about request $id
///
////////////////////////////////////////////////////////////////////////////////
function getRequestInfo($id) {
	global $printedHTMLheader, $HTMLheader;
	if(empty($id))
		abort(9);
	$query = "SELECT stateid, "
	       .        "laststateid, "
	       .        "userid, "
	       .        "start, "
	       .        "end, "
	       .        "daterequested, "
	       .        "datemodified, "
	       .        "logid, "
	       .        "test, "
	       .        "forimaging "
	       . "FROM request "
	       . "WHERE id = $id";
	$qh = doQuery($query, 165);
	if(! ($data = mysql_fetch_assoc($qh))) {
		if(! $printedHTMLheader) 
			print $HTMLheader;
		print "<h1>OOPS! - Reservation Has Expired</h1>\n";
		print "The selected reservation is no longer available.  Go to ";
		print "<a href=" . BASEURL . SCRIPT . "?mode=newRequest>New ";
		print "Reservations</a><br>to request a new reservation or to ";
		print "<a href=" . BASEURL . SCRIPT . "?mode=viewRequests>Current ";
		print "Reservations</a> to select<br>another one that is available.";
		printHTMLFooter();
		dbDisconnect();
		exit;
	}
	$data["id"] = $id;
	$query = "SELECT rs.imageid, "
	       .        "rs.imagerevisionid, "
	       .        "rs.managementnodeid, "
	       .        "ir.production, "
	       .        "i.name AS image, "
	       .        "i.prettyname AS prettyimage, "
	       .        "o.prettyname AS OS, "
	       .        "rs.computerid, "
	       .        "rs.id AS reservationid, "
	       .        "c.IPaddress AS reservedIP, "
	       .        "c.hostname, "
	       .        "i.forcheckout, "
	       .        "rs.pw AS password, "
	       .        "rs.remoteIP "
	       . "FROM reservation rs, "
	       .      "image i, "
	       .      "imagerevision ir, "
	       .      "OS o, "
	       .      "computer c "
	       . "WHERE rs.requestid = $id AND "
	       .       "rs.imageid = i.id AND "
	       .       "rs.imagerevisionid = ir.id AND "
	       .       "i.OSid = o.id AND "
	       .       "rs.computerid = c.id";
	$qh = doQuery($query, 101);
	$data["reservations"] = array();
	while($row = mysql_fetch_assoc($qh)) {
		array_push($data["reservations"], $row);
	}
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateRequest($requestid)
///
/// \param $requestid - the id of the request to be updated
///
/// \brief updates an entry to the request and reservation tables
///
////////////////////////////////////////////////////////////////////////////////
function updateRequest($requestid) {
	global $requestInfo, $user;
	$userid = getUserlistID($user['unityid']);
	$startstamp = unixToDatetime($requestInfo["start"]);
	$endstamp = unixToDatetime($requestInfo["end"]);

	if($requestInfo["start"] <= time())
		$nowfuture = "now";
	else
		$nowfuture = "future";

	$query = "SELECT logid FROM request WHERE id = $requestid";
	$qh = doQuery($query, 146);
	if(! $row = mysql_fetch_row($qh)) {
		abort(148);
	}
	$logid = $row[0];

	$query = "UPDATE request "
	       . "SET start = '$startstamp', "
	       .     "end = '$endstamp', "
	       .     "datemodified = NOW() "
	       . "WHERE id = $requestid";
	doQuery($query, 101);

	if($nowfuture == 'now') {
		addChangeLogEntry($logid, NULL, $endstamp, $startstamp, NULL, NULL, 1);
		return;
	}

	$requestData = getRequestInfo($requestid);
	foreach($requestInfo["images"] as $key => $imgid) {
		foreach($requestData["reservations"] as $key2 => $res) {
			if($res["imageid"] == $imgid) {
				$oldCompid = $res["computerid"];
				unset($requestData['reservations'][$key2]);
				break;
			}
		}
		$computerid = $requestInfo["computers"][$key];
		$mgmtnodeid = $requestInfo['mgmtnodes'][$key];

		$query = "UPDATE reservation "
		       . "SET computerid = $computerid, "
		       .     "managementnodeid = $mgmtnodeid "
		       . "WHERE requestid = $requestid AND "
		       .       "imageid = $imgid AND "
		       .       "computerid = $oldCompid";
		doQuery($query, 147);
		addChangeLogEntry($logid, NULL, $endstamp, $startstamp, $computerid, NULL, 
		                  1);
		$query = "UPDATE sublog "
		       . "SET computerid = $computerid "
		       . "WHERE logid = $logid AND "
		       .       "imageid = $imgid AND "
		       .       "computerid = $oldCompid";
		doQuery($query, 101);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deleteRequest($request)
///
/// \param $request - an array from getRequestInfo
///
/// \brief removes a request from the request and reservation tables
///
////////////////////////////////////////////////////////////////////////////////
function deleteRequest($request) {
	# new - 13
	# deleted - 1
	# complete - 12
	# reserved - 3
	# inuse - 8
	# pending - 14
	# timeout - 11
	$now = time();
	if(datetimeToUnix($request["start"]) < $now) {
		# current: new, last: none OR
		# current: pending, last: new
		if($request["stateid"] == 13 ||
		   ($request["stateid"] == 14 && $request["laststateid"] == 13)) {
			$query = "UPDATE request "
			       . "SET stateid = 1, "
			       .     "laststateid = 3 "
			       . "WHERE id = " . $request["id"];
		}
		# current: reserved, last: new OR
		# current: pending, last: reserved
		elseif(($request["stateid"] == 3 && $request["laststateid"] == 13) ||
		   ($request["stateid"] == 14 && $request["laststateid"] == 3)) {
			$query = "UPDATE request "
			       . "SET stateid = 1, "
			       .     "laststateid = 3 "
			       . "WHERE id = " . $request["id"];
		}
		# current: inuse, last: reserved OR
		# current: pending, last: inuse
		elseif(($request["stateid"] == 8 && $request["laststateid"] == 3) ||
		       ($request["stateid"] == 14 && $request["laststateid"] == 8)) {
			$query = "UPDATE request "
			       . "SET stateid = 1, "
			       .     "laststateid = 8 "
			       . "WHERE id = " . $request["id"];
		}
		# shouldn't happen, but if current: pending, set to deleted or
		// if not current: pending, set laststate to current state and
		# current state to deleted
		else {
			if($request["stateid"] == 14) {
				$query = "UPDATE request "
				       . "SET stateid = 1 "
				       . "WHERE id = " . $request["id"];
				}
			else {
				# somehow a user submitted a deleteRequest where the current
				# stateid was empty
				if(! is_numeric($request["stateid"]) || $request["stateid"] < 0)
					$request["stateid"] = 1;
				$query = "UPDATE request "
				       . "SET stateid = 1, "
				       .     "laststateid = " . $request["stateid"] . " "
				       . "WHERE id = " . $request["id"];
			}
		}
		$qh = doQuery($query, 150);

		addChangeLogEntry($request["logid"], NULL, unixToDatetime($now), NULL,
		                  NULL, "released");
		return;
	}

	$query = "DELETE FROM request WHERE id = " . $request["id"];
	$qh = doQuery($query, 152);

	$query = "DELETE FROM reservation WHERE requestid = {$request["id"]}";
	doQuery($query, 153);

	addChangeLogEntry($request["logid"], NULL, NULL, NULL, NULL, "deleted");
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn moveReservationsOffComputer($compid, $count)
///
/// \param $compid - (optional) id of computer from which to move reservations
/// \param $count - (optional) number of reservations to move, defaults to
/// all of them
///
/// \return 0 if failed to move reservations, 1 if succeeded, -1 if no
/// reservations were found on $compid
///
/// \brief attempts to move reservations off of a $compid - if $compid is not
/// given, removes all reservations from the computer with the least number
///
////////////////////////////////////////////////////////////////////////////////
function moveReservationsOffComputer($compid=0, $count=0) {
	global $requestInfo, $user;
	$resInfo = array();
	$checkstart = unixToDatetime(time() + 180);
	if($compid == 0) {
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"),
			                           array("available"), 0, 0);
		$computers = implode("','", array_keys($resources["computer"]));
		$computers = "'$computers'";
		$query = "SELECT DISTINCT COUNT(rs.id) AS reservations, "
		       .        "rs.computerid "
		       . "FROM reservation rs, "
		       .      "request rq "
		       . "WHERE rq.start > '$checkstart' AND "
		       .       "rs.computerid IN ($computers) "
		       . "GROUP BY computerid "
		       . "ORDER BY reservations "
		       . "LIMIT 1";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh))
			$compid = $row["computerid"];
		else
			return -1;
	}
	# get all reservation info for $compid
	$query = "SELECT rs.id, "
	       .        "rs.requestid, "
	       .        "rs.imageid, "
	       .        "rq.logid, "
	       .        "rq.userid, "
	       .        "rq.start, "
	       .        "rq.end "
	       . "FROM reservation rs, "
	       .      "request rq "
	       . "WHERE rs.computerid = $compid AND "
	       .       "rs.requestid = rq.id AND "
	       .       "rq.start > '$checkstart' AND "
	       .       "rq.stateid NOT IN (1, 5, 11, 12) "
			 . "ORDER BY rq.start";
	if($count)
		$query .= " LIMIT $count";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		$resInfo[$row["id"]] = $row;
	}
	if(! count($resInfo))
		return -1;
	$images = getImages();
	$allmovable = 1;
	foreach($resInfo as $res) {
		$rc = isAvailable($images, $res["imageid"], datetimeToUnix($res["start"]),
		      datetimeToUnix($res["end"]), "dummy", 0, $res["userid"]);
		if($rc < 1) {
			$allmovable = 0;
			break;
		}
	}
	if(! $allmovable)
		return 0;
	foreach($resInfo as $res) {
		$rc = isAvailable($images, $res["imageid"], datetimeToUnix($res["start"]),
		      datetimeToUnix($res["end"]), "dummy", 0, $res["userid"]);
		if($rc > 0) {
			$newcompid = array_shift($requestInfo["computers"]);
			# get mgmt node for computer
			$mgmtnodeid = findManagementNode($newcompid, $res['start'], 'future');
			# update mgmt node and computer in reservation table
			$query = "UPDATE reservation "
			       . "SET computerid = $newcompid, "
			       .     "managementnodeid = $mgmtnodeid "
			       . "WHERE id = {$res["id"]}";
			doQuery($query, 101);
			# add changelog entry
			addChangeLogEntry($res['logid'], NULL, NULL, NULL, $newcompid);
			# update sublog entry
			$query = "UPDATE sublog "
			       . "SET computerid = $newcompid "
			       . "WHERE logid = {$res['logid']} AND "
			       .       "computerid = $compid";
			doQuery($query, 101);
		}
		else
			return 0;
	}
	return 1;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserRequests($type, $id)
///
/// \param $type - "normal", "forimaging", or "all"
/// \param $id - (optional) user's id from userlist table
///
/// \return an array of user's requests; the array has the following elements
/// for each entry where forcheckout == 1 for the image:\n
/// \b id - id of the request\n
/// \b imageid - id of requested image\n
/// \b image - name of requested image\n
/// \b prettyimage - pretty name of requested image\n
/// \b OS - name of the requested os\n
/// \b start - start time of request\n
/// \b end - end time of request\n
/// \b daterequested - date request was made\n
/// \b currstateid - current stateid of request\n
/// \b laststateid - last stateid of request\n
/// \b forimaging - 0 if an normal request, 1 if imaging request\n
/// \b forcheckout - 1 if image is available for reservations, 0 if not\n
/// \b test - test flag - 0 or 1\n
/// \b longterm - 1 if request length is > 24 hours\n
/// \b resid - id of primary reservation\n
/// \b compimageid - currentimageid for primary computer\n
/// \b computerstateid - current stateid of primary computer\n
/// \b computerid - id of primary computer\n
/// \b IPaddress - IP address of primary computer\n
/// \b comptype - type of primary computer\n
/// and an array of subimages named reservations with the following elements
/// for each subimage:\n
/// \b resid - id of reservation\n
/// \b imageid - id of requested image\n
/// \b image - name of requested image\n
/// \b prettyname - pretty name of requested image\n
/// \b OS - name of the requested os\n
/// \b compimageid - currentimageid for computer\n
/// \b computerstateid - current stateid of computer\n
/// \b computerid - id of reserved computer\n
/// \b IPaddress - IP address of reserved computer\n
/// \b type - type of computer
///
/// \brief builds an array of current requests made by the user
///
////////////////////////////////////////////////////////////////////////////////
function getUserRequests($type, $id=0) {
	global $user;
	if($id == 0) {
		$id = $user["id"];
	}
	$query = "SELECT i.name AS image, "
	       .        "i.prettyname AS prettyimage, "
	       .        "i.id AS imageid, "
	       .        "rq.start, "
	       .        "rq.end, "
	       .        "rq.daterequested, "
	       .        "rq.id, "
	       .        "o.prettyname AS OS, "
	       .        "rq.stateid AS currstateid, "
	       .        "rq.laststateid, "
	       .        "rs.computerid, "
	       .        "rs.id AS resid, "
	       .        "c.currentimageid AS compimageid, "
	       .        "c.stateid AS computerstateid, "
	       .        "c.IPaddress, "
	       .        "c.type AS comptype, "
	       .        "rq.forimaging, "
	       .        "i.forcheckout, "
	       .        "rq.test "
	       . "FROM request rq, "
	       .      "reservation rs, "
	       .      "image i, "
	       .      "OS o, "
	       .      "computer c "
	       . "WHERE rq.userid = $id AND "
	       .       "rs.requestid = rq.id AND "
	       .       "rs.imageid = i.id AND "
	       .       "rq.end > NOW() AND "
	       .       "i.OSid = o.id AND "
	       .       "c.id = rs.computerid AND "
	       .       "rq.stateid NOT IN (1, 10, 16, 17) AND "      # deleted, maintenance, complete, image, makeproduction
	       .       "rq.laststateid NOT IN (1, 10, 16, 17) ";  # deleted, maintenance, complete, image, makeproduction
	if($type == "normal")
		$query .=   "AND rq.forimaging = 0 "
		       .    "AND i.forcheckout = 1 ";
	if($type == "forimaging")
		$query .=   "AND rq.forimaging = 1 ";
	$query .= "ORDER BY rq.start, "
	       .           "rs.id";

	$qbase2 = "SELECT rs.id AS resid, "
	        .        "i.name AS image, "
	        .        "i.prettyname, "
	        .        "i.id AS imageid, "
	        .        "o.prettyname as OS, "
	        .        "rs.computerid, "
	        .        "c.currentimageid AS compimageid, "
	        .        "c.stateid AS computerstateid, "
	        .        "c.IPaddress, "
	        .        "c.type AS comptype "
	        . "FROM reservation rs, "
	        .      "image i, "
	        .      "OS o, "
	        .      "computer c "
	        . "WHERE rs.imageid = i.id AND "
	        .       "rs.computerid = c.id AND "
	        .       "i.OSid = o.id AND "
	        .       "rs.id != %d AND "
	        .       "rs.requestid = %d";
	$qh = doQuery($query, 160);
	$count = 0;
	$data = array();
	$foundids = array();
	while($row = mysql_fetch_assoc($qh)) {
		if(array_key_exists($row['id'], $foundids))
			continue;
		$foundids[$row['id']] = 1;
		$data[$count] = $row;
		if((datetimeToUnix($row['end']) - datetimeToUnix($row['start'])) > SECINDAY)
			$data[$count]['longterm'] = 1;
		else
			$data[$count]['longterm'] = 0;
		$data[$count]["reservations"] = array();
		$query2 = sprintf($qbase2, $row['resid'], $row['id']);
		$qh2 = doQuery($query2, 160);
		while($row2 = mysql_fetch_assoc($qh2)) {
			array_push($data[$count]["reservations"], $row2);
		}
		$count++;
	}
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn isComputerLoading($request, $computers)
///
/// \param $request - an element from the array returned from getUserRequests
/// \param $computers - array from getComputers
///
/// \return 1 if a computer is loading, 0 if not
///
/// \brief checks all computers associated with the request to see if they
/// are loading
///
////////////////////////////////////////////////////////////////////////////////
function isComputerLoading($request, $computers) {
	if($computers[$request["computerid"]]["stateid"] == 6 ||
	   ($computers[$request["computerid"]]["stateid"] == 2 &&
	   $computers[$request["computerid"]]["currentimgid"] != $request["imageid"]))
		return 1;
	foreach($request["reservations"] as $res) {
		if($computers[$res["computerid"]]["stateid"] == 6 ||
		   ($computers[$res["computerid"]]["stateid"] == 2 &&
		   $computers[$res["computerid"]]["currentimgid"] != $res["imageid"]))
			return 1;
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMaxReloadTime($request, $images)
///
/// \param $request - an element from the array returned from getUserRequests
/// \param $images - array returned from getImages
///
/// \return the max reload time for all images associated with $request
///
/// \brief looks at all the reload times for images associated with $request
/// and returns the longest one
///
////////////////////////////////////////////////////////////////////////////////
function getMaxReloadTime($request, $images) {
	$reloadtime = $images[$request["imageid"]]["reloadtime"];
	foreach($request["reservations"] as $res) {
		if($images[$res["imageid"]]["reloadtime"] > $reloadtime)
			$reloadtime = $images[$res["imageid"]]["reloadtime"];
	}
	return $reloadtime;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn datetimeToUnix($datetime)
///
/// \param $datetime - a mysql datetime
///
/// \return timestamp - a unix timestamp
///
/// \brief converts a mysql datetime to a unix timestamp
///
////////////////////////////////////////////////////////////////////////////////
function datetimeToUnix($datetime) {
	$tmp = explode(' ', $datetime);
	list($year, $month, $day) = explode('-', $tmp[0]);
	list($hour, $min, $sec) = explode(':', $tmp[1]);
	return mktime($hour, $min, $sec, $month, $day, $year, -1);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn unixToDatetime($timestamp)
///
/// \param $timestamp - a unix timestamp
///
/// \return datetime - a mysql datetime
///
/// \brief converts a unix timestamp to a mysql datetime
///
////////////////////////////////////////////////////////////////////////////////
function unixToDatetime($timestamp) {
	return date("Y-m-d H:i:s", $timestamp);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn minuteOfDay($hour, $min)
///
/// \param $hour - hour of the day (0 - 23)
/// \param $min - minute into the hour (0 - 59)
///
/// \return minutes into the day (0 - 1439)
///
/// \brief converts hour:min to minutes since midnight
///
////////////////////////////////////////////////////////////////////////////////
function minuteOfDay($hour, $min) {
	return ($hour * 60) + $min;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn minuteOfDay2($time)
///
/// \param $time - in format 'HH:MM (am|pm)'
///
/// \return minutes into the day (0 - 1439)
///
/// \brief converts 'HH:MM (am|pm)' to minutes since midnight
///
////////////////////////////////////////////////////////////////////////////////
function minuteOfDay2($time) {
	$timeArr = explode(':', $time);
	$hour = $timeArr[0];
	$timeArr = explode(' ', $timeArr[1]);
	$min = $timeArr[0];
	$meridian = $timeArr[1];
	if($meridian == "am" && $hour == 12) {
		return $min;
	}
	elseif($meridian == "pm" && $hour < 12) {
		$hour += 12;
	}
	return ($hour * 60) + $min;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn minuteOfWeek($ts)
///
/// \param $ts - a unix timestamp
///
/// \return minute of the week
///
/// \brief takes a unix timestamp and returns how many minutes into the week it
/// is with the week starting on Sunday at midnight
///
////////////////////////////////////////////////////////////////////////////////
function minuteOfWeek($ts) {
	# ((day of week (0-6)) * 1440) + ((hour in day) * 60) + (min in hour)
	return (date('w', $ts) * 1440) + (date('G', $ts) * 60) + date('i', $ts);
}


////////////////////////////////////////////////////////////////////////////////
///
/// \fn minuteToTime($minutes)
///
/// \param $minutes - minutes since midnight
///
/// \return time string in the form (H)H:MM (am/pm)
///
/// \brief converts "minutes since midnight" to time of day
///
////////////////////////////////////////////////////////////////////////////////
function minuteToTime($minutes) {
	$hour = sprintf("%d", $minutes / 60);
	$min = sprintf("%02d", $minutes % 60);
	$meridian = "am";
	if($hour == 0) {
		$hour = 12;
	}
	elseif($hour == 12) {
		$meridian = "pm";
	}
	elseif($hour > 12) {
		$hour -= 12;
		$meridian = "pm";
	}
	return "$hour:$min $meridian";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn hour12to24($hour, $meridian)
///
/// \param $hour - 1 to 12
/// \param $meridian - am or pm
///
/// \return 24 hour equivilent of $hour $meridian
///
/// \brief converts 12 hour format to 24 hour format
///
////////////////////////////////////////////////////////////////////////////////
function hour12to24($hour, $meridian) {
	if($meridian == 'pm' && $hour < 12)
		return $hour + 12;
	elseif($meridian == 'am' && $hour == 12)
		return 0;
	return $hour;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getDepartmentName($id)
///
/// \param $id - id for a department in the department table
///
/// \return if found, department name; if not, 0
///
/// \brief looks up the name field corresponding to $id in the department table
/// and returns it
///
////////////////////////////////////////////////////////////////////////////////
function getDepartmentName($id) {
	$query = "SELECT name FROM department WHERE id = '$id'";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_row($qh)) {
		return $row[0];
	}
	else {
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getDepartmentID($dept)
///
/// \param $dept - department name
///
/// \return id from department table for the department name
///
/// \brief gets id field from department table for $dept
///
////////////////////////////////////////////////////////////////////////////////
function getDepartmentID($dept) {
	$dept = strtolower($dept);
	$query = "SELECT id FROM department WHERE name = '$dept'";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh)) {
		$row = mysql_fetch_row($qh);
		return $row[0];
	}
	else {
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAppId($app)
///
/// \param $app - name of an app (must match name in the app table)
///
/// \return the id of matching $app in the app table or 0 if lookup fails
///
/// \brief looks up the id for $app and returns it
///
////////////////////////////////////////////////////////////////////////////////
function getAppId($app) {
	$qh = doQuery("SELECT id FROM app WHERE name = '$app'", 139);
	if($row = mysql_fetch_row($qh)) {
		return $row[0];
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImageId($image)
///
/// \param $image - name of an image (must match name (not prettyname) in the 
/// image table)
///
/// \return the id of matching $image in the image table or 0 if lookup fails
///
/// \brief looks up the id for $image and returns it
///
////////////////////////////////////////////////////////////////////////////////
function getImageId($image) {
	$qh = doQuery("SELECT id FROM image WHERE name = '$image'", 170);
	if($row = mysql_fetch_row($qh)) {
		return $row[0];
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getOSId($os)
///
/// \param $os - name of an os (must match name in the os table
///
/// \return the id of matching $os in the os table or 0 if lookup fails
///
/// \brief looks up the id for $os and returns it
///
////////////////////////////////////////////////////////////////////////////////
function getOSId($os) {
	$qh = doQuery("SELECT id FROM OS WHERE name = '$os'", 175);
	if($row = mysql_fetch_row($qh)) {
		return $row[0];
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getStates()
///
/// \return array of states where the index are the id from the state table
///
/// \brief gets names for states in state table
///
////////////////////////////////////////////////////////////////////////////////
function getStates() {
	$qh = doQuery("SELECT id, name FROM state", 176);
	$states = array();
	while($row = mysql_fetch_row($qh)) {
		$states[$row[0]] = $row[1];
	}
	return $states;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getDepartments()
///
/// \return array of departments where the index are the id from the dept table,
/// each index has the following elements:\n
/// \b name - short name of department\n
/// \b prettyname - nice looking name of department
///
/// \brief gets names for departments in dept table
///
////////////////////////////////////////////////////////////////////////////////
function getDepartments() {
	$qh = doQuery("SELECT id, name, prettyname FROM dept", 177);
	$depts = array();
	while($row = mysql_fetch_row($qh)) {
		$depts[$row[0]]["name"] = $row[1];
		$depts[$row[0]]["prettyname"] = $row[2];
	}
	return $depts;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getPlatforms()
///
/// \return array of platforms where the index are the id from the platform table
///
/// \brief gets names for platforms in platform table
///
////////////////////////////////////////////////////////////////////////////////
function getPlatforms() {
	$qh = doQuery("SELECT id, name FROM platform", 178);
	$platforms = array();
	while($row = mysql_fetch_row($qh)) {
		$platforms[$row[0]] = $row[1];
	}
	return $platforms;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getProvisioning()
///
/// \return array of provisioning engines where each index is the id and the
/// value is an array with these keys: name, prettyname, moduleid, modulename
///
/// \brief gets data from provisioning table
///
////////////////////////////////////////////////////////////////////////////////
function getProvisioning() {
	$query = "SELECT p.id, "
	       .        "p.name, "
	       .        "p.prettyname, "
	       .        "p.moduleid, "
	       .        "m.prettyname AS modulename "
	       . "FROM provisioning p, "
	       .      "module m "
	       . "WHERE p.moduleid = m.id "
	       . "ORDER BY p.prettyname";
	$qh = doQuery($query, 101);
	$provisioning = array();
	while($row = mysql_fetch_assoc($qh))
		$provisioning[$row['id']] = $row;
	return $provisioning;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getSchedules()
///
/// \return array of schedules where the index are the id from the schedule table,
/// each index has the following elements:\n
/// \b name - name of schedule\n
/// \b ownerid - user id of owner\n
/// \b owner - unity id of owner\n
/// \b times - array of start and end times for the schedule
///
/// \brief gets information for schedules in schedule table
///
////////////////////////////////////////////////////////////////////////////////
function getSchedules() {
	$query = "SELECT s.id, "
	       .        "s.name, "
	       .        "s.ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "r.id AS resourceid "
	       . "FROM schedule s, "
	       .      "resource r, "
	       .      "resourcetype t, "
	       .      "user u, "
	       .      "affiliation a "
	       . "WHERE r.subid = s.id AND "
	       .       "r.resourcetypeid = t.id AND "
	       .       "t.name = 'schedule' AND "
	       .       "s.ownerid = u.id AND "
	       .       "u.affiliationid = a.id "
	       . "ORDER BY s.name";
	$qh = doQuery($query, 179);
	$schedules = array();
	while($row = mysql_fetch_assoc($qh)) {
		$schedules[$row["id"]] = $row;
		$schedules[$row["id"]]["times"] = array();
	}
	$query = "SELECT scheduleid, "
	       .        "start, "
	       .        "end "
	       . "FROM scheduletimes "
	       . "ORDER BY scheduleid, "
	       .          "start";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		array_push($schedules[$row["scheduleid"]]["times"],
		           array("start" => $row["start"], "end" => $row["end"]));
	}
	return $schedules;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn formatMinOfWeek($min)
///
/// \param $min - minute of the week
///
/// \return a string with the day of week and time
///
/// \brief formats $min into something useful for printing
///
////////////////////////////////////////////////////////////////////////////////
function formatMinOfWeek($min) {
	$time = minuteToTime($min % 1440);
	if($min / 1440 == 0) {
		return "Sunday, $time";
	}
	elseif((int)($min / 1440) == 1) {
		return "Monday, $time";
	}
	elseif((int)($min / 1440) == 2) {
		return "Tuesday, $time";
	}
	elseif((int)($min / 1440) == 3) {
		return "Wednesday, $time";
	}
	elseif((int)($min / 1440) == 4) {
		return "Thursday, $time";
	}
	elseif((int)($min / 1440) == 5) {
		return "Friday, $time";
	}
	elseif((int)($min / 1440) == 6) {
		return "Saturday, $time";
	}
	elseif((int)($min / 1440) > 6) {
		return "Sunday, $time";
	}
	else {
		return "$time";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getManagementNodes($alive)
///
/// \param $alive - (optional) if given, only return "alive" nodes, can be
///                 either "now" or "future" so we know how recently it must
///                 have checked in
///
/// \return an array of management nodes where eash index is the id from the
/// managementnode table and each element is an array of data about the node
///
/// \brief builds an array of data about the management nodes\n
/// if $alive = now, must have checked in within 5 minutes\n
/// if $alive = future, must have checked in within 1 hour
///
////////////////////////////////////////////////////////////////////////////////
function getManagementNodes($alive="neither") {
	if($alive == "now")
		$lastcheckin = unixToDatetime(time() - 300);
	elseif($alive == "future")
		$lastcheckin = unixToDatetime(time() - 3600);

	$query = "SELECT m.id, "
	       .        "m.IPaddress, "
	       .        "m.hostname, "
	       .        "m.ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) as owner, "
	       .        "m.stateid, "
	       .        "s.name as state, "
	       .        "m.lastcheckin, "
	       .        "m.checkininterval, "
	       .        "m.installpath, "
	       .        "m.imagelibenable, "
	       .        "m.imagelibgroupid, "
	       .        "rg.name AS imagelibgroup, "
	       .        "m.imagelibuser, "
	       .        "m.imagelibkey, "
	       .        "m.keys, "
	       .        "m.sshport, "
	       .        "r.id as resourceid, "
	       .        "m.predictivemoduleid, "
	       .        "mo.prettyname AS predictivemodule "
	       . "FROM user u, "
	       .      "state s, "
	       .      "resource r, "
	       .      "resourcetype rt, "
	       .      "affiliation a, "
	       .      "module mo, "
	       .      "managementnode m "
	       . "LEFT JOIN resourcegroup rg ON (m.imagelibgroupid = rg.id) "
	       . "WHERE m.ownerid = u.id AND "
	       .       "m.stateid = s.id AND "
	       .       "m.id = r.subid AND "
	       .       "r.resourcetypeid = rt.id AND "
	       .       "rt.name = 'managementnode' AND "
	       .       "u.affiliationid = a.id AND "
	       .       "m.predictivemoduleid = mo.id";
	if($alive == "now" || $alive == "future") {
		$query .= " AND m.lastcheckin > '$lastcheckin'"
		       .  " AND s.name != 'maintenance'";
	}
	$qh = doQuery($query, 101);
	$return = array();
	while($row = mysql_fetch_assoc($qh)) {
		$return[$row["id"]] = $row;
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getPredictiveModules()
///
/// \return an array of predictive loading modules where the index is the module
/// id and the value is a row of data from the module table
///
/// \brief gets all the predictive loading modules from the module table
///
////////////////////////////////////////////////////////////////////////////////
function getPredictiveModules() {
	$query = "SELECT id, "
	       .        "name, "
	       .        "prettyname, "
	       .        "description, "
	       .        "perlpackage "
	       . "FROM module "
	       . "WHERE perlpackage LIKE 'VCL::Module::Predictive::%'";
	$qh = doQuery($query, 101);
	$modules = array();
	while($row = mysql_fetch_assoc($qh))
		$modules[$row['id']] = $row;
	return $modules;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getTimeSlots($end, $start)
///
/// \param $end - (optional) end time as unix timestamp
/// \param $start - (optional) start time as unix timestamp
///
/// \return array of free/used timeslotes
///
/// \brief generates an array of availability for computers where index is a
/// computerid with a value that is an array whose indexes are unix timestamps 
/// that increment by 15 minutes with a value that is an array with 2 indexes:
/// 'scheduleclosed' and 'available' that tell if the computer's schedule is
/// closed at that moment and if the computer is available at that moment\n
/// Array {\n
///    [computerid0] => Array {\n
///       [timeslot0] => Array {\n
///          [scheduleclosed] => (0/1)\n
///          [available] => (0/1)\n
///       }\n
///          ...\n
///       [timeslotN] => Array {...}\n
///    }\n
///         ...\n
///    [computeridN] => Array {...}\n
/// }
///
////////////////////////////////////////////////////////////////////////////////
function getTimeSlots($compids, $end=0, $start=0) {
	global $viewmode;
	if(empty($compids))
		return array();
	$requestid = processInputVar("requestid", ARG_NUMERIC, 0);

	$platsel = getContinuationVar("platforms");
	if(empty($platsel))
		$platsel = processInputVar("platforms", ARG_MULTINUMERIC);
	$schsel = getContinuationVar("schedules");
	if(empty($schsel))
		$schsel = processInputVar("schedules", ARG_MULTINUMERIC);

	# all computations done with unix timestamps
	if($end != 0) {
		$enddate = unixToDatetime($end);
	}
	if($start != 0) {
		$startdate = unixToDatetime($start);
	}

	$computerids = array();
	$reservedComputerids = array();
	$schedules = getSchedules();
	$times = array();
	$scheduleids = array();
	$compinlist = implode(",", $compids);
	$query = "SELECT id, scheduleid "
	       . "FROM computer "
	       . "WHERE scheduleid IS NOT NULL AND "
	       .       "scheduleid != 0 AND "
	       .       "id IN ($compinlist) ";
	if(! empty($schsel) && ! empty($platsel)) {
		$schinlist = implode(',', $schsel);
		$platinlist = implode(',', $platsel);
		$query .= "AND scheduleid IN ($schinlist) "
		       .  "AND platformid IN ($platinlist)";
	}
	$qh = doQuery($query, 155);
	while($row = mysql_fetch_row($qh)) {
		array_push($computerids, $row[0]);
		$times[$row[0]] = array();
		$scheduleids[$row[0]] = $row[1];
	}

	if($start != 0 && $end != 0) {
		$query = "SELECT rs.computerid, "
		       .        "rq.start, "
		       .        "rq.end + INTERVAL 900 SECOND AS end, "
		       .        "rq.id, "
		       .        "u.unityid, "
		       .        "i.prettyname "
		       . "FROM reservation rs, "
		       .      "request rq, "
		       .      "user u, "
		       .      "image i "
		       . "WHERE (rq.start < '$enddate' AND "
		       .       "rq.end > '$startdate') AND "
		       .       "rq.id = rs.requestid AND "
		       .       "u.id = rq.userid AND "
		       .       "i.id = rs.imageid AND "
		       .       "rq.stateid NOT IN (1,5,12) "
		       . "ORDER BY rs.computerid, "
		       .          "rq.start";
	}
	else {
		$query = "SELECT rs.computerid, "
		       .        "rq.start, "
		       .        "rq.end + INTERVAL 900 SECOND AS end, "
		       .        "rq.id, "
		       .        "u.unityid, "
		       .        "i.prettyname "
		       . "FROM reservation rs, "
		       .      "request rq, "
		       .      "user u, "
		       .      "image i "
		       . "WHERE rq.end > NOW() AND "
		       .       "rq.id = rs.requestid AND "
		       .       "u.id = rq.userid AND "
		       .       "i.id = rs.imageid AND "
		       .       "rq.stateid NOT IN (1,5,12) "
		       . "ORDER BY rs.computerid, "
		       .          "rq.start";
	}
	$qh = doQuery($query, 156);

	$id = "";
	while($row = mysql_fetch_row($qh)) {
		if($row[3] == $requestid) {
			continue;
		}
		if($id != $row[0]) {
			$count = 0;
			$id = $row[0];
			array_push($reservedComputerids, $id);
		}
		$times[$id][$count] = array();
		$times[$id][$count]["start"] = datetimeToUnix($row[1]);
		$times[$id][$count]["end"] = datetimeToUnix($row[2]);
		$times[$id][$count]["requestid"] = $row[3];
		$times[$id][$count]["unityid"] = $row[4];
		$times[$id][$count++]["prettyimage"] = $row[5];
	}

	# use floor function to get to a 15 min increment for start
	if($start != 0) {
		$start = unixFloor15($start);
	}
	else {
		$start = unixFloor15() + 900;
	}

	# last time to look at
	if($end != 0) {
		$endtime = $end;
	}
	else {
		$endtime = $start + (DAYSAHEAD * SECINDAY);
	}

	$blockData = getBlockTimeData($start, $endtime);
	$reserveInfo = array();    // 0 = reserved, 1 = available
	foreach($computerids as $id) {
		$reserveInfo[$id] = array();
		$first = 1;
		# loop from $start to $endtime by 15 minute increments
		for($current = $start, $count = 0, $max = count($times[$id]);
		    $current < $endtime;
		    $current += 900) {
			/*print "compid - $id<br>\n";
			print "count - $count<br>\n";
			print "current - " . unixToDatetime($current) . "<br>\n";
			if(array_key_exists($count, $times[$id])) {
				print "start - " . unixToDatetime($times[$id][$count]["start"]) . "<br>\n";
				print "end - " . unixToDatetime($times[$id][$count]["end"]) . "<br>\n";
			}
			print "-----------------------------------------------------<br>\n";*/
			$reserveInfo[$id][$current]['blockRequest'] = 0;
			if(scheduleClosed($id, $current, $schedules[$scheduleids[$id]])) {
				$reserveInfo[$id][$current]["available"] = 0;
				$reserveInfo[$id][$current]["scheduleclosed"] = 1;
				continue;
			}
			if($blockid = isBlockRequestTime($id, $current, $blockData)) {
				$reserveInfo[$id][$current]['blockRequest'] = 1;
				$reserveInfo[$id][$current]['blockRequestInfo']['groupid'] = $blockData[$blockid]['groupid'];
				$reserveInfo[$id][$current]['blockRequestInfo']['imageid'] = $blockData[$blockid]['imageid'];
				$reserveInfo[$id][$current]['blockRequestInfo']['name'] = $blockData[$blockid]['name'];
				$reserveInfo[$id][$current]['blockRequestInfo']['image'] = $blockData[$blockid]['image'];
			}
			$reserveInfo[$id][$current]["scheduleclosed"] = 0;
			//if computer not in $reservedComputerids, it is free
			if(! in_array($id, $reservedComputerids)) {
				$reserveInfo[$id][$current]["available"] = 1;
				continue;
			}
			//if past an end
			if($count != $max && $current >= $times[$id][$count]["end"]) {
				$count++;
			}
			# past the end of all reservations
			if($count == $max) {
				$reserveInfo[$id][$current]["available"] = 1;
				continue;
			}
			//if before any start times
			if($count == 0 && $current < $times[$id][0]["start"]) {
				$reserveInfo[$id][$current]["available"] = 1;
				continue;
			}
			//if between a start and end time
			if($current >= $times[$id][$count]["start"] && 
			   $current <  $times[$id][$count]["end"]) {
				if($first) {
					$first = 0;
					$reserveInfo[$id][$current - 900]['blockRequest'] = 0;
					$reserveInfo[$id][$current - 900]["scheduleclosed"] = 0;
					$reserveInfo[$id][$current - 900]["available"] = 0;
					$reserveInfo[$id][$current - 900]["requestid"] = $times[$id][$count]["requestid"];
					$reserveInfo[$id][$current - 900]["unityid"] = $times[$id][$count]["unityid"];
					$reserveInfo[$id][$current - 900]["prettyimage"] = $times[$id][$count]["prettyimage"];
				}
				$reserveInfo[$id][$current]["available"] = 0;
				$reserveInfo[$id][$current]["requestid"] = $times[$id][$count]["requestid"];
				$reserveInfo[$id][$current]["unityid"] = $times[$id][$count]["unityid"];
				$reserveInfo[$id][$current]["prettyimage"] = $times[$id][$count]["prettyimage"];
				continue;
			}
			//if after previous end but before this start
			if($current >= $times[$id][$count - 1]["end"] && 
			   $current <  $times[$id][$count]["start"]) {
				$reserveInfo[$id][$current]["available"] = 1;
				continue;
			}
			# shouldn't get here; print debug info if we do
			if($viewmode == ADMIN_DEVELOPER) {
				print "******************************************************<br>\n";
				print "current - " . unixToDatetime($current) . "<br>\n";
				print "endtime - " . unixToDatetime($endtime) . "<br>\n";
				print "count - $count<br>\n";
				print "max - $max<br>\n";
				print "start - " . unixToDatetime($times[$id][$count]["start"]) . "<br>\n";
				print "end - " . unixToDatetime($times[$id][$count]["end"]) . "<br>\n";
				print "------------------------------------------------------<br>\n";
			}
		}
	}
	return $reserveInfo;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn unixFloor15($timestamp)
///
/// \param $timestamp - (optional) unix timestamp, defaults to now
///
/// \return floored timestamp
///
/// \brief takes $timestamp and floors it to a 15 minute increment with 0 seconds
///
////////////////////////////////////////////////////////////////////////////////
function unixFloor15($timestamp=0) {
	if($timestamp == 0) {
		$timestamp = time();
	}
	$timeval = getdate($timestamp);
	if($timeval["minutes"] < 15) {
		$timeval["minutes"] = 0;
	}
	elseif($timeval["minutes"] < 30) {
		$timeval["minutes"] = 15;
	}
	elseif($timeval["minutes"] < 45) {
		$timeval["minutes"] = 30;
	}
	elseif($timeval["minutes"] < 60) {
		$timeval["minutes"] = 45;
	}
	return mktime($timeval["hours"],
	              $timeval["minutes"],
	              0,
	              $timeval["mon"],
	              $timeval["mday"],
	              $timeval["year"],
	              -1);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn pickTimeTable()
///
/// \brief prints a form for selecting what elements to show in the timetable
///
////////////////////////////////////////////////////////////////////////////////
function pickTimeTable() {
	$data = getUserComputerMetaData();
	print "<H2 align=center>Time Table</H2>\n";
	print "Select the criteria for the computers you want to have in the timetable:\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<table id=layouttable summary=\"\">\n";
	print "  <TR>\n";
	print "    <TH>Platforms:</TH>\n";
	print "    <TH>Schedules:</TH>\n";
	print "  </TR>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	printSelectInput("platforms[]", $data["platforms"], -1, 0, 1);
	print "    </TD>\n";
	print "    <TD>\n";
	printSelectInput("schedules[]", $data["schedules"], -1, 0, 1);
	print "    </TD>\n";
	print "  </TR>\n";
	print "</table>\n";
	$cont = addContinuationsEntry('showTimeTable');
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=Submit>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn showTimeTable($links)
///
/// \param $links - 1 to make free times links; 0 for no links
///
/// \brief prints out a timetable of free/used timeslots
///
////////////////////////////////////////////////////////////////////////////////
function showTimeTable($links) {
	global $mode, $viewmode, $user;
	if($links == 1) {
		$imageid = getContinuationVar('imageid');
		$length = getContinuationVar('length');
		$requestid = getContinuationVar('requestid', 0);
		$showmessage = getContinuationVar('showmessage', 0);
		$platforms = array();
		$schedules = array();
	}
	else {
		$imageid = 0;
		$length = 0;
		$requestid = 0;
		$showmessage = 0;
		$platforms = getContinuationVar("platforms");
		if(empty($platforms))
			$platforms = processInputVar("platforms", ARG_MULTINUMERIC);
		$schedules = getContinuationVar("schedules");
		if(empty($schedules))
			$schedules = processInputVar("schedules", ARG_MULTINUMERIC);
	}
	$argstart = getContinuationVar("start");
	$argend = getContinuationVar("end");

	$resources = getUserResources(array("computerAdmin"));
	$userCompIDs = array_keys($resources["computer"]);

	$computerData = getComputers();
	$imageData = getImages();
	$now = time();
	if($links) {
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
		$usercomputerids = array_keys($resources["computer"]);
		# get list of computers' platformids
		$qh = doQuery("SELECT platformid FROM image WHERE id = $imageid", 110);
		$row = mysql_fetch_row($qh);
		$platformid = $row[0];
		$computer_platformids = array();
		$qh = doQuery("SELECT id, platformid FROM computer", 111);
		while($row = mysql_fetch_row($qh)) {
			$computer_platformids[$row[0]] = $row[1];
		}
		$mappedcomputers = getMappedResources($imageid, "image", "computer");
		$compidlist = array_intersect($mappedcomputers, $usercomputerids);
	}
	else
		$compidlist = $userCompIDs;
	if(! empty($argstart) && ! empty($argend)) {
		$timeslots = getTimeSlots($compidlist, $argend, $argstart);
		$start = $argstart;
		$end = $argend;
	}
	else {
		$start = $now;
		$end = $start + (SECINDAY / 2);
		$timeslots = getTimeSlots($compidlist, $end);
	}

	print "<DIV align=center>\n";
	print "<H2>Time Table</H2>\n";
	print "</DIV>\n";
	$computeridrow = "";
	$displayedids = array();
	$computers = array_keys($timeslots);
	if($links) {
		$computers = array_intersect($computers, $usercomputerids);
	}
	foreach($computers as $id) {
		if($links) {
			# don't show computers that don't meet hardware criteria, are not
			# in the available state, are the wrong platform, or wrong group,
			# or aren't mapped in resourcemap
			if($computer_platformids[$id] != $platformid ||
			   ($computerData[$id]["stateid"] != 2 &&
				$computerData[$id]["stateid"] != 3 &&
				$computerData[$id]["stateid"] != 6 &&
				$computerData[$id]["stateid"] != 8) ||
			   $computerData[$id]["ram"] < $imageData[$imageid]["minram"] ||
			   $computerData[$id]["procnumber"] < $imageData[$imageid]["minprocnumber"] ||
			   $computerData[$id]["procspeed"] < $imageData[$imageid]["minprocspeed"] ||
			   $computerData[$id]["network"] < $imageData[$imageid]["minnetwork"] ||
			   ! in_array($id, $mappedcomputers)) {
				continue;
			}
		}
		elseif(! array_key_exists($id, $computerData) ||
		       ! in_array($computerData[$id]["platformid"], $platforms) ||
		       ! in_array($computerData[$id]["scheduleid"], $schedules) ||
		       ! in_array($id, $userCompIDs)) {
			continue;
		}
		$computeridrow .= "          <TH>$id</TH>\n";
		array_push($displayedids, $id);
	}
	if(empty($displayedids)) {
		if($links) {
			print "There are currently no computers available that can run the application you selected.\n";
		}
		else {
			print "There are no computers that meet the specified criteria\n";
		}
		return;
	}
	if($showmessage) {
		print "The time you have requested to use the environment is not ";
		print "available. You may select from the green blocks of time to ";
		print "select an available time slot to make a reservation.<br>\n";
	}
	print "<table summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD>";
	# print Previous/Next links
	if(! empty($argstart) && ($argstart - (SECINDAY / 2) > $now - 600)) {
		$prevstart = $start - (SECINDAY / 2);
		$prevend = $end - (SECINDAY / 2);
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('start' => $prevstart,
		               'end' => $prevend,
		               'imageid' => $imageid,
		               'requestid' => $requestid,
		               'length' => $length,
		               'platforms' => $platforms,
		               'schedules' => $schedules);
		$cont = addContinuationsEntry($mode, $cdata, SECINDAY);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=Previous>\n";
		print "</FORM>\n";
	}
	print "</TD>\n";
	print "    <TD>";
	if($end + (SECINDAY / 2) < $now + DAYSAHEAD * SECINDAY) {
		$nextstart = $start + (SECINDAY / 2);
		$nextend = $end + (SECINDAY / 2);
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('start' => $nextstart,
		               'end' => $nextend,
		               'imageid' => $imageid,
		               'requestid' => $requestid,
		               'length' => $length,
		               'platforms' => $platforms,
		               'schedules' => $schedules);
		$cont = addContinuationsEntry($mode, $cdata, SECINDAY);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=Next>\n";
		print "</FORM>\n";
	}
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>\n";

	$tmpArr = array_keys($computers);
	$first = $computers[$tmpArr[0]];
	print "      <table id=ttlayout summary=\"\">\n";
	if(! $links || $viewmode >= ADMIN_DEVELOPER) {
		print "        <TR>\n";
		print "          <TH align=right>Computer&nbsp;ID:</TH>\n";
		print $computeridrow;
		print "        </TR>\n";
	}
	$yesterday = "";
	foreach(array_keys($timeslots[$first]) as $stamp) {
		print "        <TR>\n";
		$stampArr = getdate($stamp);
		$label = "";
		if($stampArr["mday"] != $yesterday) {
			$label = date('n/d/Y+g:i+a', $stamp);
			$label = str_replace('+', '&nbsp;', $label);
			$yesterday = $stampArr["mday"];
		}
		elseif($stampArr["minutes"] == 0) {
			$label = date('g:i a', $stamp);
		}
		print "          <TH align=right>$label</TH>\n";
		$free = 0;
		# print the cells
		foreach($computers as $id) {
			if(! in_array($id, $displayedids)) {
				continue;
			}
			if($links && ($computer_platformids[$id] != $platformid ||
				$computerData[$id]["stateid"] == 10 ||
			   $computerData[$id]["stateid"] == 5)) {
				continue;
			}
			# computer's schedule is currently closed
			if($timeslots[$id][$stamp]["scheduleclosed"] == 1) {
				print "          <TD bgcolor=\"#a0a0a0\"><img src=images/gray.jpg ";
				print "alt=scheduleclosed border=0></TD>\n";
			}
			# computer is in maintenance state
			elseif($computerData[$id]["stateid"] == 10) {
				print "          <TD bgcolor=\"#a0a0a0\"><img src=images/gray.jpg ";
				print "alt=maintenance border=0></TD>\n";
			}
			# computer is reserved for a block request that doesn't match this
			elseif($timeslots[$id][$stamp]['blockRequest'] &&
			   ($timeslots[$id][$stamp]['blockRequestInfo']['imageid'] != $imageid ||  # this line threw an error at one point, but we couldn't recreate it later
			   (! in_array($timeslots[$id][$stamp]['blockRequestInfo']['groupid'], array_keys($user['groups'])))) &&
				$timeslots[$id][$stamp]['available']) {
				if($links) {
					print "          <TD bgcolor=\"#ff0000\"><img src=images/red.jpg ";
					print "alt=blockrequest border=0></TD>\n";
				}
				else {
					print "          <TD bgcolor=\"#e58304\"><img src=images/orange.jpg ";
					$title = "Block Request: {$timeslots[$id][$stamp]['blockRequestInfo']['name']}\n"
					       . "Image: {$timeslots[$id][$stamp]['blockRequestInfo']['image']}";
					print "alt=blockrequest border=0 title=\"$title\"></TD>\n";
				}
			}
			# computer is free
			elseif($timeslots[$id][$stamp]["available"]) {
				if($links) {
					print "          <TD bgcolor=\"#00ff00\"><a href=\"" . BASEURL . SCRIPT;
					print "?mode=newRequest&stamp=$stamp&imageid=$imageid&length=$length\"><img ";
					print "src=images/green.jpg alt=free border=0></a></TD>\n";
				}
				else {
					print "          <TD bgcolor=\"#00ff00\"><img src=images/green.jpg alt=free border=0></TD>\n";
				}
			}
			# computer is used
			else {
				if($links) {
					print "          <TD bgcolor=\"#ff0000\"><font color=\"#ff0000\">used</font></TD>\n";
				}
				else {
					$title = "User: " . $timeslots[$id][$stamp]["unityid"]
					       . " Image: " . $timeslots[$id][$stamp]["prettyimage"];
					print "          <TD bgcolor=\"#ff0000\"><a href=\"" . BASEURL . SCRIPT;
					print "?mode=viewRequestInfo&requestid=" . $timeslots[$id][$stamp]["requestid"] . "\"><img ";
					print "src=images/red.jpg alt=used border=0 title=\"$title\"></a></TD>\n";
				}
			}
		}
		print "        </TR>\n";
	}
	print "      </table>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>";
	# print Previous/Next links
	if(! empty($argstart) && ($argstart - (SECINDAY / 2) > $now - 600)) {
		$prevstart = $start - (SECINDAY / 2);
		$prevend = $end - (SECINDAY / 2);
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('start' => $prevstart,
		               'end' => $prevend,
		               'imageid' => $imageid,
		               'requestid' => $requestid,
		               'length' => $length,
		               'platforms' => $platforms,
		               'schedules' => $schedules);
		$cont = addContinuationsEntry($mode, $cdata, SECINDAY);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=Previous>\n";
		print "</FORM>\n";
	}
	print "</TD>\n";
	print "    <TD>";
	if($end + (SECINDAY / 2) < $now + DAYSAHEAD * SECINDAY) {
		$nextstart = $start + (SECINDAY / 2);
		$nextend = $end + (SECINDAY / 2);
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('start' => $nextstart,
		               'end' => $nextend,
		               'imageid' => $imageid,
		               'requestid' => $requestid,
		               'length' => $length,
		               'platforms' => $platforms,
		               'schedules' => $schedules);
		$cont = addContinuationsEntry($mode, $cdata, SECINDAY);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=Next>\n";
		print "</FORM>\n";
	}
	print "</TD>\n";
	print "  </TR>\n";
	print "</table>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getComputers($sort, $includedeleted, $compid)
///
/// \param $sort - (optional) 1 to sort; 0 not to
/// \param $includedeleted = (optional) 1 to show deleted images, 0 not to
/// \param $compid - (optional) only get info for this computer id
///
/// \return an array with info about the computers in the comptuer table; each
/// element's index is the id from the table; each element has the following
/// items\n
/// \b state - current state of the computer\n
/// \b stateid - id of current state\n
/// \b dept - department owning the computer\n
/// \b prettydept - pretty name of department owning the computer\n
/// \b deptid - id of department owning the computer\n
/// \b owner - unity id of owner\n
/// \b ownerid - user id of owner\n
/// \b platform - computer's platform\n
/// \b platformid - id of computer's platform\n
/// \b schedule - computer's schedule\n
/// \b scheduleid - id of computer's schedule\n
/// \b currentimg - computer's current image\n
/// \b currentimgid - id of computer's current image\n
/// \b nextimg - computer's next image\n
/// \b nextimgid - id of computer's next image\n
/// \b nextimg - computer's next image\n
/// \b nextimgid - id of computer's next image\n
/// \b ram - amount of RAM in computer in MB\n
/// \b procnumber - number of processors in computer\n
/// \b procspeed - speed of processor(s) in MHz\n
/// \b network - speed of computer's NIC\n
/// \b hostname - computer's hostname\n
/// \b IPaddress - computer's IP address\n
/// \b type - either 'blade' or 'lab' - used to determine what backend utilities\n
/// \b deleted - 0 or 1; whether or not this computer has been deleted\n
/// \b resourceid - computer's resource id from the resource table\n
/// \b provisioningid - id of provisioning engine\n
/// \b provisioning - pretty name of provisioning engine
/// need to be used to manage computer
///
/// \brief builds an array of computers
///
////////////////////////////////////////////////////////////////////////////////
function getComputers($sort=0, $includedeleted=0, $compid="") {
	$return = array();
	$query = "SELECT c.id AS id, "
	       .        "st.name AS state, "
	       .        "c.stateid AS stateid, "
	       .        "d.name AS dept, "
	       .        "d.prettyname AS prettydept, "
	       .        "c.deptid AS deptid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "u.id AS ownerid, "
	       .        "p.name AS platform, "
	       .        "c.platformid AS platformid, "
	       .        "sc.name AS schedule, "
	       .        "c.scheduleid AS scheduleid, "
	       .        "cur.name AS currentimg, "
	       .        "c.currentimageid AS currentimgid, "
	       .        "next.name AS nextimg, "
	       .        "c.nextimageid AS nextimgid, "
	       .        "c.RAM AS ram, "
	       .        "c.procnumber AS procnumber, "
	       .        "c.procspeed AS procspeed, "
	       .        "c.network AS network, "
	       .        "c.hostname AS hostname, "
	       .        "c.IPaddress AS IPaddress, "
	       .        "c.type AS type, "
	       .        "c.deleted AS deleted, "
	       .        "r.id AS resourceid, "
	       .        "c.notes, "
	       .        "c.vmhostid, "
	       .        "c.vmtypeid, "
	       .        "c2.hostname AS vmhost, "
	       .        "c.provisioningid, "
	       .        "pr.prettyname AS provisioning "
	       . "FROM state st, "
	       .      "dept d, "
	       .      "platform p, "
	       .      "schedule sc, "
	       .      "image cur, "
	       .      "resource r, "
	       .      "resourcetype t, "
	       .      "user u, "
	       .      "affiliation a, "
	       .      "computer c "
	       . "LEFT JOIN vmhost vh ON (c.vmhostid = vh.id) "
	       . "LEFT JOIN vmtype vt ON (c.vmtypeid = vt.id) "
	       . "LEFT JOIN computer c2 ON (c2.id = vh.computerid) "
	       . "LEFT JOIN image next ON (c.nextimageid = next.id) "
	       . "LEFT JOIN provisioning pr ON (c.provisioningid = pr.id) "
	       . "WHERE c.stateid = st.id AND "
	       .       "c.deptid = d.id AND "
	       .       "c.platformid = p.id AND "
	       .       "c.scheduleid = sc.id AND "
	       .       "c.currentimageid = cur.id AND "
	       .       "r.resourcetypeid = t.id AND "
	       .       "t.name = 'computer' AND "
	       .       "r.subid = c.id AND "
	       .       "c.ownerid = u.id AND "
	       .       "u.affiliationid = a.id ";
	if(! $includedeleted)
		$query .= "AND c.deleted = 0 ";
	if(! empty($compid))
		$query .= "AND c.id = $compid ";
	$query .= "ORDER BY c.hostname";
	$qh = doQuery($query, 180);
	while($row = mysql_fetch_assoc($qh)) {
		$return[$row['id']] = $row;
	}
	if($sort) {
		uasort($return, "sortComputers");
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserComputerMetaData()
///
/// \return an array of 3 indices - depts, platforms, schedules - where each
/// index's value is an array of user's computer's data
///
/// \brief builds an array of depts, platforms, and schedules for user's 
/// computers
///
////////////////////////////////////////////////////////////////////////////////
function getUserComputerMetaData() {
	$key = getKey(array('getUserComputerMetaData'));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	$computers = getComputers();
	$resources = getUserResources(array("computerAdmin"), 
	                              array("administer", "manageGroup"), 0, 1);
	$return = array("depts" => array(),
	                "platforms" => array(),
	                "schedules" => array());
	foreach(array_keys($resources["computer"]) as $compid) {
		if(! array_key_exists($compid, $computers))
			continue;
		/*if(! in_array($computers[$compid]["prettydept"], $return["depts"]))
			$return["depts"][$computers[$compid]["deptid"]] = 
			      $computers[$compid]["prettydept"];*/
		if(! in_array($computers[$compid]["platform"], $return["platforms"]))
			$return["platforms"][$computers[$compid]["platformid"]] =
			      $computers[$compid]["platform"];
		if(! in_array($computers[$compid]["schedule"], $return["schedules"]))
			$return["schedules"][$computers[$compid]["scheduleid"]] =
			      $computers[$compid]["schedule"];
	}
	uasort($return["platforms"], "sortKeepIndex");
	uasort($return["schedules"], "sortKeepIndex");
	$_SESSION['usersessiondata'][$key] = $return;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getCompStateFlow($compid)
///
/// \param $compid - a computer id
///
/// \return an array of data about the flow of states for $compid; the following
/// keys and elements are returned:\n
/// \b repeatid - id from computerloadstate for the repeat state\n
/// \b stateids - array of computerloadstate ids for this flow in the order
/// they occur\n
/// \b nextstates - array where each key is a computerloadstate id and its value
/// is that state's following state; the last state has a NULL value\n
/// \b totaltime - estimated time (in seconds) it takes for all states to 
/// complete\n
/// \b data - array where each key is is a computerloadstate id and each value
/// is an array with these elements:\n
/// \b stateid - same as key\n
/// \b state - name of this state\n
/// \b nextstateid - id of next state\n
/// \b nextstate - name of next state\n
/// \b statetime - estimated time it takes for this state to complete
///
/// \brief gathers information about the flow of states for $compid
///
////////////////////////////////////////////////////////////////////////////////
function getCompStateFlow($compid) {
	$key = getKey(array($compid));
	if(array_key_exists($key, $_SESSION['compstateflow']))
		return $_SESSION['compstateflow'][$key];

	# get id for repeat state, useful because several of the calling functions
	#   need this information
	$query = "SELECT id FROM computerloadstate WHERE loadstatename = 'repeat'";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh))
		return array();
	$loadstates['repeatid'] = $row['id'];

	$query = "SELECT `type` FROM computer WHERE id = $compid";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh))
		return array();

	$type = $row['type'];
	$query = "SELECT cf.computerloadstateid AS stateid, "
	       .        "cs1.prettyname AS state, "
	       .        "cs1.loadstatename AS statename, "
	       .        "cf.nextstateid, "
	       .        "cs2.prettyname AS nextstate, "
	       .        "cs1.est AS statetime "
	       . "FROM computerloadstate cs1, "
	       .      "computerloadflow cf "
	       . "LEFT JOIN computerloadstate cs2 ON (cf.nextstateid = cs2.id) "
	       . "WHERE cf.computerloadstateid = cs1.id AND "
	       .       "cf.type = '$type' ";
	$query2 = $query . "AND cf.computerloadstateid NOT IN "
	        . "(SELECT nextstateid FROM computerloadflow WHERE `type` = '$type' "
	        . "AND nextstateid IS NOT NULL)";
	$qh = doQuery($query2, 101);
	if(! $row = mysql_fetch_assoc($qh))
		return array();
	$loadstates['data'][$row['stateid']] = $row;
	$loadstates['stateids'] = array($row['stateid']);
	$loadstates['nextstates'] = array($row['stateid'] => $row['nextstateid']);
	$loadstates['totaltime'] = 0;
	for($i = 0; $i < 100; $i++) { # don't want an endless loop
		$query2 = $query . "AND cf.computerloadstateid = {$row['nextstateid']} "
		        . "AND `type` = '$type'";
		$qh = doQuery($query2, 101);
		if(! $row = mysql_fetch_assoc($qh)) {
			$_SESSION['compstateflow'][$key] = $loadstates;
			return $loadstates;
		}
		else {
			array_push($loadstates['stateids'], $row['stateid']);
			$loadstates['nextstates'][$row['stateid']] = $row['nextstateid'];
			$loadstates['totaltime'] += $row['statetime'];
			$loadstates['data'][$row['stateid']] = $row;
		}
		if(empty($row['nextstateid'])) {
			$_SESSION['compstateflow'][$key] = $loadstates;
			return $loadstates;
		}
	}
	$_SESSION['compstateflow'][$key] = $loadstates;
	return $loadstates;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getCompLoadLog($resid)
///
/// \param $resid - reservation id
///
/// \return an array where each key is an id from the computerloadlog table and
/// each element is an array with these items:\n
/// \b computerid - id of computer\n
/// \b loadstateid - load id of this state\n
/// \b ts - unix timestamp when item entered in log\n
/// \b time - actual time (in seconds) this state took
///
/// \brief gets information from the computerloadlog table for $resid
///
////////////////////////////////////////////////////////////////////////////////
function getCompLoadLog($resid) {
	$query = "SELECT UNIX_TIMESTAMP(rq.start) AS start, "
	       .        "UNIX_TIMESTAMP(rq.daterequested) AS reqtime, "
	       .        "rs.computerid "
	       . "FROM request rq, "
	       .      "reservation rs "
	       . "WHERE rs.id = $resid AND "
	       .       "rs.requestid = rq.id "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh))
		abort(113);
	if($row['start'] < $row['reqtime'])
		$firststart = $row['reqtime'];
	else
		$firststart = $row['start'];
	$flow = getCompStateFlow($row['computerid']);
	$instates = implode(',', $flow['stateids']);
	$query = "SELECT id, "
	       .        "computerid, "
	       .        "loadstateid, "
	       .        "UNIX_TIMESTAMP(timestamp) AS ts "
	       . "FROM computerloadlog "
	       . "WHERE reservationid = $resid AND "
	       .       "(loadstateid IN ($instates) OR "
	       .       "loadstateid = {$flow['repeatid']}) "
	       . "ORDER BY id";
	$qh = doQuery($query, 101);
	$last = array();
	$data = array();
	while($row = mysql_fetch_assoc($qh)) {
		$data[$row['id']] = $row;
		if(empty($last))
			$data[$row['id']]['time'] = $row['ts'] - $firststart;
		else
			$data[$row['id']]['time'] = $row['ts'] - $last['ts'];
		$last = $row;
	}
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImageLoadEstimate($imageid)
///
/// \param $imageid - id of an image
///
/// \return estimated time in seconds that it takes to load $imageid
///
/// \brief determines an estimated load time (in seconds) that it takes $imageid
/// to load based on the last 12 months of log data
///
////////////////////////////////////////////////////////////////////////////////
function getImageLoadEstimate($imageid) {
	$query = "SELECT AVG(UNIX_TIMESTAMP(loaded) - UNIX_TIMESTAMP(start)) AS avgloadtime "
	       . "FROM log "
	       . "WHERE imageid = $imageid AND "
	       .        "wasavailable = 1 AND "
	       .        "UNIX_TIMESTAMP(loaded) - UNIX_TIMESTAMP(start) > 120 AND "
	       .        "loaded > start AND "
	       .        "ending != 'failed' AND "
	       .        "nowfuture = 'now' AND "
	       .        "start > (NOW() - INTERVAL 12 MONTH) AND "
	       .        "UNIX_TIMESTAMP(loaded) - UNIX_TIMESTAMP(start) < 1800";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		if(! empty($row['avgloadtime']))
			return (int)$row['avgloadtime'];
		else
			return 0;
	}
	else
		return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getComputerCounts(&$computers)
///
/// \param $computers - array returned from getComputers
///
/// \brief adds a "counts" field for each computer in $computers that is the
/// total number of reservations that computer has had
///
////////////////////////////////////////////////////////////////////////////////
function getComputerCounts(&$computers) {
	foreach(array_keys($computers) as $compid) {
		$query = "SELECT COUNT(logid) "
		       . "FROM sublog "
		       . "WHERE computerid = $compid";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_row($qh))
			$computers[$compid]["counts"] = $row[0];
		else
			$computers[$compid]["counts"] = 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sortComputers($a, $b)
///
/// \param $a - first input passed in by uasort
/// \param $b - second input passed in by uasort
///
/// \return -1, 0, or 1 if $a < $b, $a == $b, $a > $b, respectively
///
/// \brief determines if $a should go before or after $b
///
////////////////////////////////////////////////////////////////////////////////
function sortComputers($a, $b) {
	//if somehow there are empty strings passed in, push them to the end
	if(empty($a)) {
		return 1;
	}
	if(empty($b)) {
		return -1;
	}

	# get hostname and first part of domain name
	$tmp = explode('.', $a["hostname"]);
	$h1 = array_shift($tmp);
	$domain1 = array_shift($tmp);
	$letters1 = preg_replace('([^a-zA-Z])', '', $h1);

	$tmp = explode('.', $b["hostname"]);
	$h2 = array_shift($tmp);
	$domain2 = array_shift($tmp);
	$letters2 = preg_replace('([^a-zA-Z])', '', $h2);

	// if different domain names, return based on that
	$cmp = strcasecmp($domain1, $domain2);
	if($cmp) {
		return $cmp;
	}

	// if non-numeric part is different, return based on that
	$cmp = strcasecmp($letters1, $letters2);
	if($cmp) {
		return $cmp;
	}

	// at this point, the only difference is in the numbers
	$digits1 = preg_replace('([^\d-])', '', $h1);
	$digits1Arr = explode('-', $digits1);
	$digits2 = preg_replace('([^\d-])', '', $h2);
	$digits2Arr = explode('-', $digits2);

	$len1 = count($digits1Arr);
	$len2 = count($digits2Arr);
	for($i = 0; $i < $len1 && $i < $len2; $i++) {
		if($digits1Arr[$i] < $digits2Arr[$i]) {
			return -1;
		}
		elseif($digits1Arr[$i] > $digits2Arr[$i]) {
			return 1;
		}
	}

	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAvailableBlockComputerids($imageid, $start, $end, $allocatedcompids)
///
/// \param $imageid - id of an image
/// \param $start - starting time in unix timestamp form
/// \param $end - ending time in unix timestamp form
/// \param $allocatedcompids - array of computer ids that have already been
/// allocated while processing this request
///
/// \return an array of computer ids
///
/// \brief gets all computer ids that are part of a block reservation the logged
/// in user is a part of that are available between $start and $end
///
////////////////////////////////////////////////////////////////////////////////
function getAvailableBlockComputerids($imageid, $start, $end, $allocatedcompids) {
	global $user;
	$compids = array();
	$groupids = implode(',', array_keys($user['groups']));
	if(! count($user['groups']))
		$groupids = "''";
	$startdt = unixToDatetime($start);
	$enddt = unixToDatetime($end);
	$alloccompids = implode(",", $allocatedcompids);
	$query = "SELECT c.computerid "
	       . "FROM blockComputers c, "
	       .      "blockRequest r, "
	       .      "blockTimes t, "
	       .      "state s, "
	       .      "computer c2 "
	       . "WHERE r.groupid IN ($groupids) AND "
	       .       "c.computerid = c2.id AND "
	       .       "c2.currentimageid = $imageid AND "
	       .       "r.expireTime > NOW() AND "
	       .       "t.blockRequestid = r.id AND "
	       .       "c.blockTimeid = t.id AND "
	       .       "t.start < '$enddt' AND "
	       .       "t.end > '$startdt' AND "
	       .       "c2.stateid = s.id AND "
	       .       "s.name != 'failed' AND "
	       .       "c2.id NOT IN ($alloccompids) "
	       . "ORDER BY s.name";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		array_push($compids, $row['computerid']);
	}
	return $compids;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUsedBlockComputerids($start, $end)
///
/// \param $start - starting time in unix timestamp form
/// \param $end - ending time in unix timestamp form
///
/// \return array of computer ids
///
/// \brief gets a list of all computerids that are allocated to block
/// reservations during the given times
///
////////////////////////////////////////////////////////////////////////////////
function getUsedBlockComputerids($start, $end) {
	$compids = array();
	$startdt = unixToDatetime($start);
	$enddt = unixToDatetime($end);
	$query = "SELECT c.computerid "
	       . "FROM blockComputers c, "
	       .      "blockTimes t "
	       . "WHERE t.end > '$startdt' AND "
	       .       "t.start < '$enddt' AND "
	       .       "c.blockTimeid = t.id";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		array_push($compids, $row['computerid']);
	}
	return $compids;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getBlockTimeData($start, $end)
///
/// \param $start - (optional) start time of blockTimes to get in unix timestamp
/// form
/// \param $end - (optional) end time of blockTimes to get in unix timestamp
/// form
///
/// \return an array of block request data where each index in a blockTime id
/// and the value is an array with these elements:\n
/// \b 
///
/// \brief builds an array of block request data
///
////////////////////////////////////////////////////////////////////////////////
function getBlockTimeData($start="", $end="") {
	$return = array();
	$query = "SELECT r.id AS requestid, "
	       .        "r.name, "
	       .        "r.imageid, "
	       .        "i.prettyname AS image, "
	       .        "r.numMachines, "
	       .        "r.groupid, "
	       .        "r.repeating, "
	       .        "r.ownerid, "
	       .        "r.admingroupid, "
	       .        "r.managementnodeid, "
	       .        "r.expireTime, "
	       .        "t.id AS timeid, "
	       .        "t.start, "
	       .        "t.end "
	       . "FROM blockRequest r, "
	       .      "blockTimes t, "
	       .      "image i "
	       . "WHERE r.id = t.blockRequestid AND "
	       .       "r.imageid = i.id";
	if(! empty($start))
		$query .= " AND t.start < '" . unixToDatetime($end) . "'";
	if(! empty($end))
		$query .= " AND t.end > '" . unixToDatetime($start) . "'";
	$query .= " ORDER BY t.start, t.end";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		$return[$row['timeid']] = $row;
		$return[$row['timeid']]['unixstart'] = datetimeToUnix($row['start']);
		$return[$row['timeid']]['unixend'] = datetimeToUnix($row['end']);
		$return[$row['timeid']]['computerids'] = array();
		$query2 = "SELECT computerid "
		        . "FROM blockComputers "
		        . "WHERE blockTimeid = {$row['timeid']}";
		$qh2 = doQuery($query2, 101);
		while($row2 = mysql_fetch_assoc($qh2))
			array_push($return[$row['timeid']]['computerids'], $row2['computerid']);
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn isBlockRequestTime($compid, $ts, $blockData)
///
/// \param $compid - a computer id
/// \param $ts - a timestamp
/// \param $blockData - an array as returned from getBlockTimeData
///
/// \return the blockTimeid $ts falls in to if it does; 0 if it doesn't fall
/// into any block times
///
/// \brief determines if $ts falls into a block time $compid is part of
///
////////////////////////////////////////////////////////////////////////////////
function isBlockRequestTime($compid, $ts, $blockData) {
	foreach(array_keys($blockData) as $timeid) {
		if(in_array($compid, $blockData[$timeid]['computerids']) &&
		   $ts >= $blockData[$timeid]['unixstart'] &&
		   $ts < $blockData[$timeid]['unixend'])
			return $timeid;
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printSelectInput($name, $dataArr, $selectedid, $skip, $multiple, $domid,
///                      $extra)
///
/// \param $name - name of input element
/// \param $dataArr - array containing options
/// \param $selectedid - (optional) index of $dataArr to be initially selected;
/// use -1 for nothing to be selected
/// \param $skip - (optional) this is used if the array from getImages is passed
/// as $dataArr so we know to skip index 4 since it is the noimage element
/// \param $multiple - (optional) use this to print select input with the
/// multiple tag set
/// \param $domid - (optional) use this to pass in the javascript id to be used
/// for the select object
/// \param $extra - (optional) any extra attributes that need to be set
///
/// \brief prints out a select input part of a form\n
/// it is assumed that if $selectedid is left off, we assume $dataArr has no 
/// index '-1'\n
/// each OPTION's value is the index of that element of the array
///
////////////////////////////////////////////////////////////////////////////////
function printSelectInput($name, $dataArr, $selectedid=-1, $skip=0, $multiple=0,
                          $domid="", $extra="") {
	if(! empty($domid))
		$domid = "id=\"$domid\"";
	if($multiple)
		$multiple = "multiple";
	else
		$multiple = "";
	print "      <SELECT name=$name $multiple $domid $extra>\n";
	foreach(array_keys($dataArr) as $id) {
		if(($skip && $id == 4) || ($dataArr[$id] != 0 && empty($dataArr[$id]))) {
			continue;
		}
		if($id == $selectedid) {
		   print "        <OPTION value=\"$id\" selected>";
		}
		else {
		   print "        <OPTION value=\"$id\">";
		}
		if(is_array($dataArr[$id]) && array_key_exists("prettyname", $dataArr[$id])) {
			print $dataArr[$id]["prettyname"] . "</OPTION>\n";
		}
		elseif(is_array($dataArr[$id]) && array_key_exists("name", $dataArr[$id])) {
			print $dataArr[$id]["name"] . "</OPTION>\n";
		}
		else {
			print $dataArr[$id] . "</OPTION>\n";
		}
	}
	print "      </SELECT>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printHiddenInputs($data)
///
/// \param $data - an array with index/value pairs that match the name/value
/// pairs that will be used in the form
///
/// \brief prints INPUT forms that are type hidden with the data from $data
///
////////////////////////////////////////////////////////////////////////////////
/*function printHiddenInputs($data) {
	foreach(array_keys($data) as $key) {
		if(is_array($data[$key])) {
			foreach(($data[$key]) as $index => $value) {
				print "      <INPUT type=hidden name=$key" . "[$index] value=";
				print "$value>\n";
			}
		}
		else {
			if($data[$key] != "") {
				print "      <INPUT type=hidden name=$key value=\"";
				print $data["$key"] . "\">\n";
			}
		}
	}
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn requestIsReady($request)
///
/// \param $request - a request element from the array returned by 
/// getUserRequests
///
/// \return 1 if request is ready for a user to connect, 0 if not
///
/// \brief checks to see if a request is 
///
////////////////////////////////////////////////////////////////////////////////
function requestIsReady($request) {
	foreach($request["reservations"] as $res) {
		if($res["computerstateid"] != 3 && $res["computerstateid"] != 8)
			return 0;
	}
	if(($request["currstateid"] == 14 &&      // request current state pending 
	   $request["laststateid"] == 3 &&        //   and last state reserved and
	   $request["computerstateid"] == 3) ||   //   computer reserved
	   ($request["currstateid"] == 8 &&       // request current state inuse
	   $request["computerstateid"] == 8) ||   //   and computer state inuse
	   ($request["currstateid"] == 14 &&      // request current state pending
	   $request["laststateid"] == 8 &&        //   and last state inuse and
	   $request["computerstateid"] == 8) ||   //   computer inuse
	   ($request["currstateid"] == 14 &&      // request current state pending
	   $request["laststateid"] == 8 &&        //   and last state inuse
	   $request["computerstateid"] == 3)) {   //   and computer reserved
		return 1;
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printSubmitErr($errno, $index, $errorDiv)
///
/// \param $errno - an error value, should correspond to an defined constant
/// \param $index - (optional) if $submitErrMsg will be an array, the index
/// of the element to print
/// \param $errorDiv - (optional, default=0), set to 1 to wrap the error in a
/// div with class of errormsg
///
/// \brief if the error is set, prints the corresponding error message
///
////////////////////////////////////////////////////////////////////////////////
function printSubmitErr($errno, $index=0, $errorDiv=0) {
	global $submitErr, $submitErrMsg;
	if($submitErr & $errno) {
		if($errorDiv)
			print "<p class=errormsg>";
		if(is_array($submitErrMsg[$errno]))
			print "<font color=red><em>{$submitErrMsg[$errno][$index]}</em></font>";
		else
			print "<font color=red><em>{$submitErrMsg[$errno]}</em></font>";
		if($errorDiv)
			print "</p>";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printArray($array)
///
/// \param $array - an array to print
///
/// \brief prints out an array in HTML friendly format
///
////////////////////////////////////////////////////////////////////////////////
function printArray($array) {
	print "<pre>\n";
	print_r($array);
	print "</pre>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn prettyDatetime($stamp)
///
/// \param $stamp - a timestamp in unix or mysql datetime format
///
/// \return date/time in html format of [Day of week], [month] [day of month],
/// [HH:MM] [am/pm]
///
/// \brief reformats the datetime to look better
///
////////////////////////////////////////////////////////////////////////////////
function prettyDatetime($stamp) {
	if(preg_match('/^[\d]+$/', $stamp)) {
		$return = date('l, M#jS, g:i a', $stamp);
	}
	else {
		$return = date('l, M#jS, g:i a', datetimeToUnix($stamp));
	}
	$return = str_replace('#', '&nbsp;', $return);
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn minToHourMin($min)
///
/// \param $min - minutes
///
/// \return a string value
///
/// \brief um, I don't know how to describe this, just look at the code
///
////////////////////////////////////////////////////////////////////////////////
function minToHourMin($min) {
	if($min < 60)
		return $min . " minutes";
	elseif($min == 60)
		return "1 hour";
	elseif($min % 60 == 0)
		return sprintf("%d hours", $min / 60);
	elseif($min % 30 == 0)
		return sprintf("%.1f hours", $min / 60);
	else
		return sprintf("%.2f hours", $min / 60);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn secToMinSec($sec)
///
/// \param $sec - seconds
///
/// \return a string value
///
/// \brief takes seconds and converts to min:sec
///
////////////////////////////////////////////////////////////////////////////////
function secToMinSec($sec) {
	if($sec < 60)
		return sprintf("0:%02d", $sec);
	elseif($sec == 60)
		return "1:00";
	elseif($sec % 60 == 0)
		return sprintf("%d:00", $sec / 60);
	else
		return sprintf("%d:%02d", $sec / 60, $sec % 60);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn prettyLength($minutes)
///
/// \param $minutes - a value in minutes
///
/// \return a string in the form of [length] [units]
///
/// \brief converts from $minutes to either "[minutes] minutes" or
/// "[hours] hour(s)
///
////////////////////////////////////////////////////////////////////////////////
function prettyLength($minutes) {
	if($minutes < 60)
		return (int)$minutes . " minutes";
	elseif($minutes == 60)
		return "1 hour";
	elseif($minutes % 60 == 0)
		return $minutes / 60 . " hours";
	else {
		$hours = (int)($minutes / 60);
		$min = (int)($minutes % 60);
		if($hours == 1)
			return "$hours hour, $min minutes";
		else
			return "$hours hours, $min minutes";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addLoadTime($imageid, $start, $loadtime)
///
/// \param $imageid - id of loaded image
/// \param $start - start time in unix timestamp format
/// \param $loadtime - time it took to load image in seconds
///
/// \brief adds an entry to the imageloadtimes table
///
////////////////////////////////////////////////////////////////////////////////
function addLoadTime($imageid, $start, $loadtime) {
	$query = "INSERT INTO imageloadtimes "
	       .        "(imageid, "
	       .        "starttime, "
	       .        "loadtimeseconds) "
	       . "VALUES "
	       .        "($imageid, "
	       .        "$start, "
	       .        "$loadtime)";
	doQuery($query, 245);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn scheduleClosed($computerid, $timestamp, $schedule)
///
/// \param $computerid - id of a computer
/// \param $timestamp - time to check
/// \param $schedule - an element from the array returned from getSchedules
///
/// \return 1 if schedule is closed at $timestamp, 0 if it is open
///
/// \brief checks to see if the computer's schedule is open or closed at 
/// $timestamp
///
////////////////////////////////////////////////////////////////////////////////
function scheduleClosed($computerid, $timestamp, $schedule) {
	$time = minuteOfWeek($timestamp);
	foreach($schedule["times"] as $schtime) {
		if($schtime["start"] <= $time && $time < $schtime["end"])
			return 0;
	}
	return 1;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateGroups($newusergroups, $userid)
///
/// \param $newusergroups - array of $userid's current set of user groups
/// \param $userid - id of user from user table
///
/// \brief updates user's groups and adds any new ones to the group
/// table
///
////////////////////////////////////////////////////////////////////////////////
function updateGroups($newusergroups, $userid) {
	$query = "SELECT m.usergroupid "
	       . "FROM usergroupmembers m, "
	       .      "usergroup u "
	       . "WHERE m.userid = $userid AND "
	       .       "m.usergroupid = u.id AND "
	       .       "u.custom = 0 AND "
	       .       "u.courseroll = 0";
	$qh = doQuery($query, 305);
	$oldusergroups = array();
	while($row = mysql_fetch_row($qh)) {
		array_push($oldusergroups, $row[0]);
	}
	if(count(array_diff($oldusergroups, $newusergroups)) ||
	   count(array_diff($newusergroups, $oldusergroups))) {
		$query = "DELETE m "
		       . "FROM usergroupmembers m, "
		       .             "usergroup u "
		       . "WHERE m.userid = $userid AND "
		       .       "m.usergroupid = u.id AND "
		       .       "u.custom = 0 AND "
		       .       "u.courseroll = 0";
		doQuery($query, 306);
		foreach($newusergroups as $id) {
			$query = "INSERT INTO usergroupmembers "
			       . "(userid, usergroupid) "
			       . "VALUES ($userid, $id) "
			       . "ON DUPLICATE KEY UPDATE "
			       . "userid = $userid, usergroupid = $id";
			doQuery($query, 307);
		}
	}
	return $newusergroups;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserGroupID($name, $affilid)
///
/// \param $name - a group name
/// \param $affilid - (optional, defaults to DEFAULT_AFFILID) affiliation id
/// for $name
///
/// \return id for $name from group table
///
/// \brief looks up the id for $name in the group table; if the name is
/// not currently in the table, adds it and returns the new id
///
////////////////////////////////////////////////////////////////////////////////
function getUserGroupID($name, $affilid=DEFAULT_AFFILID) {
	$query = "SELECT id "
	       . "FROM usergroup "
	       . "WHERE name = '$name' AND "
	       .       "((custom = 0 AND "
	       .       "courseroll = 0 AND "
	       .       "affiliationid = $affilid) OR "
	       .       "custom = 1 OR "
	       .       "courseroll = 1)";
	$qh = doQuery($query, 300);
	if($row = mysql_fetch_row($qh)) {
		return $row[0];
	}
	$query = "INSERT INTO usergroup "
	       .        "(name, "
	       .        "affiliationid, "
	       .        "custom, "
	       .        "courseroll) "
	       . "VALUES "
	       .        "('$name', "
	       .        "$affilid, "
	       .        "0, "
	       .        "0)";
	doQuery($query, 301);
	$qh = doQuery("SELECT LAST_INSERT_ID() FROM usergroup", 302);
	if(! $row = mysql_fetch_row($qh)) {
		abort(303);
	}
	return $row[0];
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserGroupName($id, $incAffil)
///
/// \param $id - id of a user group
/// \param $incAffil - 0 or 1 (optional, defaults to 0); include @ and 
/// affiliation at the end
///
/// \return name for $id from usergroup table or 0 if name not found
///
/// \brief looks up the name for $id in the group table
///
////////////////////////////////////////////////////////////////////////////////
function getUserGroupName($id, $incAffil=0) {
	if($incAffil) {
		$query = "SELECT CONCAT(u.name, '@', a.name) as name "
		       . "FROM usergroup u, "
		       .      "affiliation a "
		       . "WHERE u.id = $id AND "
		       .       "u.affiliationid = a.id";
	}
	else {
		$query = "SELECT name "
		       . "FROM usergroup "
		       . "WHERE id = $id";
	}
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_row($qh))
		return $row[0];
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn unset_by_val($needle, &$haystack)
///
/// \param $needle - value to remove from array
/// \param $haystack - array
///
/// \brief removes all entries from an array having $needle as their value
///
////////////////////////////////////////////////////////////////////////////////
function unset_by_val($needle, &$haystack) {
	while(($gotcha = array_search($needle,$haystack)) > -1) { 
		unset($haystack[$gotcha]);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sendRDPfile()
///
/// \brief generates and uploads a rdp file to the user
///
////////////////////////////////////////////////////////////////////////////////
function sendRDPfile() {
	global $user;
	# for more info on this file, see 
	# http://dev.remotenetworktechnology.com/ts/rdpfile.htm
	$requestid = getContinuationVar("requestid");
	$request = getRequestInfo("$requestid");
	foreach($request["reservations"] as $res) {
		if($res["forcheckout"]) {
			$ipaddress = $res["reservedIP"];
			$passwd = $res["password"];
			break;
		}
	}
	if(empty($ipaddress))
		return;

	$width = $user["width"];
	$height = $user["height"];
	if($width == 0) {
		$screenmode = 2;
		$width = 1024;
		$height = 768;
	}
	else
		$screenmode = 1;
	$bpp = $user["bpp"];
	if($user["audiomode"] == "none")
		$audiomode = 2;
	else
		$audiomode = 0;
	$redirectdrives = $user["mapdrives"];
	$redirectprinters = $user["mapprinters"];
	$redirectcomports = $user["mapserial"];

	header("Content-type: application/rdp");
	header("Content-Disposition: inline; filename=\"{$res['prettyimage']}.rdp\"");
	print "screen mode id:i:$screenmode\r\n";
	print "desktopwidth:i:$width\r\n";
	print "desktopheight:i:$height\r\n";
	print "session bpp:i:$bpp\r\n";
	print "winposstr:s:0,1,382,71,1182,671\r\n";
	print "full address:s:$ipaddress\r\n";
	print "compression:i:1\r\n";
	print "keyboardhook:i:2\r\n";
	print "audiomode:i:$audiomode\r\n";
	print "redirectdrives:i:$redirectdrives\r\n";
	print "redirectprinters:i:$redirectprinters\r\n";
	print "redirectcomports:i:$redirectcomports\r\n";
	print "redirectsmartcards:i:1\r\n";
	print "displayconnectionbar:i:1\r\n";
	print "autoreconnection enabled:i:1\r\n";
	if($request["forimaging"])
		print "username:s:Administrator\r\n";
	else {
		if(preg_match('/(.*)@(.*)/', $user['unityid'], $matches))
			print "username:s:" . $matches[1] . "\r\n";
		else
			print "username:s:" . $user["unityid"] . "\r\n";
	}
	print "clear password:s:$passwd\r\n";
	print "domain:s:\r\n";
	print "alternate shell:s:\r\n";
	print "shell working directory:s:\r\n";
	print "disable wallpaper:i:1\r\n";
	print "disable full window drag:i:1\r\n";
	print "disable menu anims:i:1\r\n";
	print "disable themes:i:0\r\n";
	print "disable cursor setting:i:0\r\n";
	print "bitmapcachepersistenable:i:1\r\n";
	//print "connect to console:i:1\r\n";
	exit(0);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addLogEntry($nowfuture, $start, $end, $wasavailable, $imageid)
///
/// \param $nowfuture - 'now' or 'future'
/// \param $start - mysql datetime for starting time
/// \param $end - mysql datetime for initialend and finalend
/// \param $wasavailable - 0 or 1, whether or not the request was available
/// when requested
/// \param $imageid - id of requested image
///
/// \brief adds an entry to the log table
///
////////////////////////////////////////////////////////////////////////////////
function addLogEntry($nowfuture, $start, $end, $wasavailable, $imageid) {
	global $user;
	$query = "INSERT INTO log "
	       .        "(userid, "
	       .        "nowfuture, "
	       .        "start, "
	       .        "initialend, "
	       .        "finalend, "
	       .        "wasavailable, "
	       .        "ending, "
	       .        "imageid) "
	       . "VALUES "
	       .        "(" . $user["id"] . ", "
	       .        "'$nowfuture', "
	       .        "'$start', "
	       .        "'$end', "
	       .        "'$end', "
	       .        "$wasavailable, "
	       .        "'none', "
	       .        "$imageid)";
	$qh = doQuery($query, 260);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addChangeLogEntry($logid, $remoteIP, $end, $start, $computerid,
///                                $ending, $wasavailable)
///
/// \param $logid - id matching entry in log table
/// \param $remoteIP - ip of remote computer (pass NULL if this isn't being
/// updated)
/// \param $end - (optional) ending time of request (mysql datetime)
/// \param $start - (optional) starting time of request (mysql datetime)
/// \param $computerid - (optional) id from computer table
/// \param $ending - (optional) 'deleted' or 'released' - how reservation ended
/// \param $wasavailable - (optional) 0 or 1 - if a newly requested time was
/// available; \b NOTE: pass -1 instead of NULL if you don't want this field
/// to be updated
///
/// \brief adds an entry to the changelog table and updates information in 
/// the log table
///
////////////////////////////////////////////////////////////////////////////////
function addChangeLogEntry($logid, $remoteIP, $end=NULL, $start=NULL, 
                           $computerid=NULL, $ending=NULL, $wasavailable=-1) {
	if($logid == 0) {
		return;
	}
	$query = "SELECT computerid, " 
	       .        "start, "
	       .        "initialend, "
	       .        "remoteIP, "
	       .        "wasavailable, "
	       .        "ending "
	       . "FROM log "
	       . "WHERE id = $logid";
	$qh = doQuery($query, 265);
	if(! $log = mysql_fetch_assoc($qh)) {
		abort(30);
	}
	$log["computerid"] = array();
	$query = "SELECT computerid FROM sublog WHERE logid = $logid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		array_push($log["computerid"], $row["computerid"]);
	}
	$changed = 0;

	$query1 = "INSERT INTO changelog "
	        .        "(logid, "
	        .        "start, "
	        .        "end, "
	        .        "computerid, "
	        .        "remoteIP, "
	        .        "wasavailable, "
	        .        "timestamp) "
	        . "VALUES "
	        .        "($logid, ";

	$query2Arr = array();

	# start
	if($start != NULL && $start != $log["start"]) {
		$query1 .= "'$start', ";
		# only update start time in log table if it is in the future
		if(datetimeToUnix($log['start']) > time())
			array_push($query2Arr, "start = '$start'");
		$changed = 1;
	}
	else {
		$query1 .= "NULL, ";
	}

	# end
	if($end != NULL && $end != $log["initialend"]) {
		$query1 .= "'$end', ";
		if(datetimeToUnix($log["start"]) > time()) {
			array_push($query2Arr, "initialend = '$end'");
		}
		array_push($query2Arr, "finalend = '$end'");
		$changed = 1;
	}
	else {
		$query1 .= "NULL, ";
	}

	# computerid
	if($computerid != NULL &&
	   ! in_array($computerid, $log["computerid"])) {
		$query1 .= "$computerid, ";
		$changed = 1;
	}
	else {
		$query1 .= "NULL, ";
	}

	# remoteIP
	if($remoteIP != NULL && $remoteIP != $log["remoteIP"]) {
		$query1 .= "'$remoteIP', ";
		array_push($query2Arr, "remoteIP = '$remoteIP'");
		$changed = 1;
	}
	else {
		$query1 .= "NULL, ";
	}

	# wasavailable
	if($wasavailable != -1 && $wasavailable != $log["wasavailable"]) {
		$query1 .= "$wasavailable, ";
		array_push($query2Arr, "wasavailable = $wasavailable");
		$changed = 1;
	}
	else {
		$query1 .= "NULL, ";
	}

	# ending
	if($ending != NULL && $ending != $log["ending"]) {
		array_push($query2Arr, "ending = '$ending'");
		$changed = 1;
	}
	$query1 .= "NOW())";

	if($changed) {
		doQuery($query1, 266);
		if(! empty($query2Arr)) {
			$query2 = "UPDATE log SET " . implode(', ', $query2Arr)
			        . " WHERE id = $logid";
			doQuery($query2, 267);
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addSublogEntry($logid, $imageid, $imagerevisionid, $computerid,
///                    $mgmtnodeid)
///
/// \param $logid - id of parent log entry
/// \param $imageid - id of requested image
/// \param $imagerevisionid - revision id of requested image
/// \param $computerid - assigned computer id
/// \param $mgmtnodeid - id of management node handling this reservation
///
/// \brief adds an entry to the log table
///
////////////////////////////////////////////////////////////////////////////////
function addSublogEntry($logid, $imageid, $imagerevisionid, $computerid,
                        $mgmtnodeid) {
	$query = "SELECT predictivemoduleid "
	       . "FROM managementnode "
	       . "WHERE id = $mgmtnodeid";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	$predictiveid = $row['predictivemoduleid'];
	$query = "INSERT INTO sublog "
	       .        "(logid, "
	       .        "imageid, "
	       .        "imagerevisionid, "
	       .        "computerid, "
	       .        "managementnodeid, "
	       .        "predictivemoduleid) "
	       . "VALUES "
	       .        "($logid, "
	       .        "$imageid, "
	       .        "$imagerevisionid, "
	       .        "$computerid, "
	       .        "$mgmtnodeid, "
	       .        "$predictiveid)";
	doQuery($query, 101);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getTypes($subtype)
///
/// \param $subtype - (optional) "users", "resources", or "both"
///
/// \return an array with 2 indexes: users and resources, each of which is an
/// array of those types
///
/// \brief returns an array of arrays of types
///
////////////////////////////////////////////////////////////////////////////////
function getTypes($subtype="both") {
	$types = array("users" => array(),
	               "resources" => array());
	if($subtype == "users" || $subtype == "both") {
		$query = "SELECT id, name FROM userprivtype";
		$qh = doQuery($query, 365);
		while($row = mysql_fetch_assoc($qh)) {
			if($row["name"] == "block" || $row["name"] == "cascade")
				continue;
			$types["users"][$row["id"]] = $row["name"];
		}
	}
	if($subtype == "resources" || $subtype == "both") {
		$query = "SELECT id, name FROM resourcetype";
		$qh = doQuery($query, 366);
		while($row = mysql_fetch_assoc($qh)) {
			if($row["name"] == "block" || $row["name"] == "cascade")
				continue;
			$types["resources"][$row["id"]] = $row["name"];
		}
	}
	return $types;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserPrivTypeID($type)
///
/// \param $type - type name
///
/// \return id of $type
///
/// \brief looks up the id for $type in the userprivtype table
///
////////////////////////////////////////////////////////////////////////////////
function getUserPrivTypeID($type) {
	$query = "SELECT id FROM userprivtype WHERE name = '$type'";
	$qh = doQuery($query, 370);
	if($row = mysql_fetch_row($qh))
		return $row[0];
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserMaxTimes($uid)
///
/// \param $uid - (optional) user's unityid or user table id
///
/// \return max time in minutes that the user can checkout a reservation
///
/// \brief looks through all of the user's groups to find the max checkout time
///
////////////////////////////////////////////////////////////////////////////////
function getUserMaxTimes($uid=0) {
	global $user;
	$return = array("initial" => 0,
	                "total" => 0,
	                "extend" => 0);
	if($uid == 0)
		$groupids = array_keys($user["groups"]);
	else {
		$groupids = array_keys(getUsersGroups($uid, 1));
	}
	if(! count($groupids))
		array_push($groupids, getUserGroupID(DEFAULTGROUP));


	$allgroups = getUserGroups();
	foreach($groupids as $id) {
		if($return["initial"] < $allgroups[$id]["initialmaxtime"])
			$return["initial"] = $allgroups[$id]["initialmaxtime"];
		if($return["total"] < $allgroups[$id]["totalmaxtime"])
			$return["total"] = $allgroups[$id]["totalmaxtime"];
		if($return["extend"] < $allgroups[$id]["maxextendtime"])
			$return["extend"] = $allgroups[$id]["maxextendtime"];
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourceGroupID($groupname)
///
/// \param $groupname - resource group name of the form type/name
///
/// \return id of the group
///
/// \brief gets the id from the resourcegroup table for $groupname
///
////////////////////////////////////////////////////////////////////////////////
function getResourceGroupID($groupdname) {
	list($type, $name) = split('/', $groupdname);
	$query = "SELECT g.id "
	       . "FROM resourcegroup g, "
	       .      "resourcetype t "
	       . "WHERE g.name = '$name' AND "
	       .       "t.name = '$type' AND "
	       .       "g.resourcetypeid = t.id";
	$qh = doQuery($query, 371);
	if($row = mysql_fetch_row($qh))
		return $row[0];
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourceTypeID($name)
///
/// \param $name - name of resource type
///
/// \return id of the resource type
///
/// \brief gets the id from the resourcetype table for $name
///
////////////////////////////////////////////////////////////////////////////////
function getResourceTypeID($name) {
	$query = "SELECT id "
	       . "FROM resourcetype "
	       . "WHERE name = '$name'";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_row($qh))
		return $row[0];
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getNodeInfo($nodeid)
///
/// \param $nodeid - an id from the privnode table
///
/// \return an array of the node's name and parent or NULL if node not found
///
/// \brief gets $nodeid's name and parent and sticks it in an array
///
////////////////////////////////////////////////////////////////////////////////
function getNodeInfo($nodeid) {
	global $cache;
	if(array_key_exists($nodeid, $cache['nodes']))
		return $cache['nodes'][$nodeid];
	$qh = doQuery("SELECT parent, name FROM privnode WHERE id = $nodeid", 330);
	if($row = mysql_fetch_assoc($qh)) {
		$return = array();
		$return["name"] = $row["name"];
		$return["parent"] = $row["parent"];
		$cache['nodes'][$nodeid] = $return;
		return $return;
	}
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sortKeepIndex($a, $b)
///
/// \param $a - first item
/// \param $b - second item
///
/// \return -1 if $a < $b, 0 if $a == $b, 1 if $a > $b
///
/// \brief this is just a normal sort, but it is for calling with uasort so
/// we don't lose our indices
///
////////////////////////////////////////////////////////////////////////////////
function sortKeepIndex($a, $b) {
	if(is_array($a)) {
		if(array_key_exists("prettyname", $a)) {
			if(preg_match('/[0-9]-[0-9]/', $a['prettyname']))
				return compareDashedNumbers($a["prettyname"], $b["prettyname"]);
			return strcasecmp($a["prettyname"], $b["prettyname"]);
		}
		elseif(array_key_exists("name", $a)) {
			if(preg_match('/[0-9]-[0-9]/', $a['name']))
				return compareDashedNumbers($a["name"], $b["name"]);
			return strcasecmp($a["name"], $b["name"]);
		}
		else
			return 0;
	}
	if(ereg('\.ncsu\.edu$', $a)) {
		return compareDashedNumbers($a, $b);
	}
	return strcasecmp($a, $b);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn compareDashedNumbers($a, $b)
///
/// \param $a - a string
/// \param $b - a string
///
/// \return -1, 0, 1 if numerical parts of $a <, =, or > $b
///
/// \brief compares $a and $b to determine which one should be ordered first; 
/// has some understand of numerical order in strings
///
////////////////////////////////////////////////////////////////////////////////
function compareDashedNumbers($a, $b) {
	# get hostname and first part of domain name
	$tmp = explode('.', $a);
	$h1 = array_shift($tmp);
	$domain1 = array_shift($tmp);
	$letters1 = preg_replace('([^a-zA-Z])', '', $h1);

	$tmp = explode('.', $b);
	$h2 = array_shift($tmp);
	$domain2 = array_shift($tmp);
	$letters2 = preg_replace('([^a-zA-Z])', '', $h2);

	// if different domain names, return based on that
	$cmp = strcasecmp($domain1, $domain2);
	if($cmp) {
		return $cmp;
	}

	// if non-numeric part is different, return based on that
	$cmp = strcasecmp($letters1, $letters2);
	if($cmp) {
		return $cmp;
	}

	// at this point, the only difference is in the numbers
	$digits1 = preg_replace('([^\d-])', '', $h1);
	$digits1Arr = explode('-', $digits1);
	$digits2 = preg_replace('([^\d-])', '', $h2);
	$digits2Arr = explode('-', $digits2);

	$len1 = count($digits1Arr);
	$len2 = count($digits2Arr);
	for($i = 0; $i < $len1 && $i < $len2; $i++) {
		if($digits1Arr[$i] < $digits2Arr[$i]) {
			return -1;
		}
		elseif($digits1Arr[$i] > $digits2Arr[$i]) {
			return 1;
		}
	}

	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourceMapping($resourcetype1, $resourcetype2,
///                                 $resource1inlist, $resource2inlist)
///
/// \param $resourcetype1 - get mapping between this type and $resourcetype2
/// \param $resourcetype2 - get mapping between this type and $resourcetype1
/// \param $resource1inlist - (optional) comma delimited list of resource groups
/// to limit query to
/// \param $resource2inlist - (optional) comma delimited list of resource groups
/// to limit query to
///
/// \return an array of $resourcetype1 group to $resourcetype2 group mappings 
/// where each index is a group id from $resourcetype1 and each value is an 
/// array of $resourcetype2 group ids
///
/// \brief builds an array of $resourcetype2 group ids for each $resourcetype1
/// group id
///
////////////////////////////////////////////////////////////////////////////////
function getResourceMapping($resourcetype1, $resourcetype2,
                            $resource1inlist="", $resource2inlist="") {
	if(! is_numeric($resourcetype1))
		$resourcetype1 = getResourceTypeID($resourcetype1);
	if(! is_numeric($resourcetype2))
		$resourcetype2 = getResourceTypeID($resourcetype2);

	$return = array();
	$query = "SELECT resourcegroupid1, "
	       .        "resourcetypeid1, "
	       .        "resourcegroupid2, "
	       .        "resourcetypeid2 "
	       . "FROM resourcemap "
	       . "WHERE ((resourcetypeid1 = $resourcetype1 AND "
	       .       "resourcetypeid2 = $resourcetype2) OR "
	       .       "(resourcetypeid1 = $resourcetype2 AND "
	       .       "resourcetypeid2 = $resourcetype1)) ";
	if(! empty($resource1inlist))
		$query .= "AND resourcegroupid1 IN ($resource1inlist) ";
	if(! empty($resource2inlist))
		$query .= "AND resourcegroupid2 IN ($resource2inlist) ";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		if($resourcetype1 == $row['resourcetypeid1']) {
			if(array_key_exists($row["resourcegroupid1"], $return))
				array_push($return[$row["resourcegroupid1"]], $row["resourcegroupid2"]);
			else
				$return[$row["resourcegroupid1"]] = array($row["resourcegroupid2"]);
		}
		else {
			if(array_key_exists($row["resourcegroupid2"], $return))
				array_push($return[$row["resourcegroupid2"]], $row["resourcegroupid1"]);
			else
				$return[$row["resourcegroupid2"]] = array($row["resourcegroupid1"]);
		}
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn timeToNextReservation($request)
///
/// \param $request - either a request id or an array returned from
/// getRequestInfo
///
/// \return minutes from the end of $request until the start of the next
/// reservation on the same computer, if there are no reservations following
/// this one, -1 is returned
///
/// \brief determines the number of minutes between the end of $request and
/// the beginning of the next request on the same computer
///
////////////////////////////////////////////////////////////////////////////////
function timeToNextReservation($request) {
	if(! is_array($request))
		$request = getRequestInfo($request);
	$res = array_shift($request["reservations"]);
	$query = "SELECT rq.start "
	       . "FROM reservation rs, "
	       .      "request rq "
	       . "WHERE rs.computerid = {$res["computerid"]} AND "
	       .       "rq.start >= '{$request["end"]}' AND "
	       .       "rs.requestid = rq.id "
	       . "ORDER BY start "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		$end = datetimeToUnix($request["end"]);
		$start = datetimeToUnix($row["start"]);
		return ($start - $end) / 60;
	}
	else
		return -1;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImageText($text)
///
/// \param $text - text to be in the image
///
/// \return a text string
///
/// \brief creates an image src line that calls textimage.php to print an
/// image with $text in it
///
////////////////////////////////////////////////////////////////////////////////
function getImageText($text) {
	return "<img src=\"" . BASEURL . "/images/textimage.php?text=$text\">";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn weekOfYear($ts)
///
/// \param $ts - unix timestamp
///
/// \return week number in the year that $ts falls in
///
/// \brief determines the week of the year $ts is in where week 0 is the week
/// containing Jan 1st
///
////////////////////////////////////////////////////////////////////////////////
function weekOfYear($ts) {
	$year = date('Y', time());
	for($i = 0; $i < 7; $i++) {
		$time = mktime(1, 0, 0, 1, $i + 1, $year);
		if(date('l', $time) == "Sunday") {
			if($i)
				$add = 7 - $i;
			else
				$add = 0;
			break;
		}
	}
	return (int)((date('z', $ts) + $add) / 7);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn semLock();
///
/// \return TRUE or FALSE
///
/// \brief tries to acquire a semaphore lock, and sets a global to know we
/// have acquired it
///
////////////////////////////////////////////////////////////////////////////////
function semLock() {
	global $semid, $semislocked;
	if($semislocked)
		return TRUE;

	if(sem_acquire($semid)) {
		$semislocked = 1;
		return TRUE;
	}
	else
		return FALSE;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn semUnlock()
///
/// \return TRUE or FALSE
///
/// \brief unlocks the semaphore and sets a global to know we have released it
///
////////////////////////////////////////////////////////////////////////////////
function semUnlock() {
	global $semid, $semislocked;
	if($semislocked) {
		if(sem_release($semid)) {
			$semislocked = 0;
			return TRUE;
		}
		else
			return FALSE;
	}
	return TRUE;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn setAttribute($objid, $attrib, $data)
///
/// \param $objid - a dom id
/// \param $attrib - attribute of dom object to set
/// \param $data - what to set $attrib to
///
/// \return dojo code to set $attrib to $data for $objid
///
/// \brief dojo code to set $attrib to $data for $objid
///
////////////////////////////////////////////////////////////////////////////////
function setAttribute($objid, $attrib, $data) {
	return "if(dojo.byId('$objid')) {dojo.byId('$objid').$attrib = '$data';};\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn generateString($length)
///
/// \param $length - (optional) length of the string, defaults to 8
///
/// \return a random string of upper and lower case letters and numbers
///
/// \brief generates a random string
///
////////////////////////////////////////////////////////////////////////////////
function generateString($length=8) {
   global $passwdArray;
   $tmp = array_flip($passwdArray);
   $tmp = array_rand($tmp, $length);
   return implode('', $tmp);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getVMProfiles(id)
///
/// \param $id (optional) - a profile id; if specified, only data about this
/// profile will be returned
///
/// \return an array of profiles where each key is the profile id and each 
/// element is an array with these keys:\n
/// \b name - name of profile\n
/// \b type - name of vm type\n
/// \b typeid - id of vm type\n
/// \b image - name of image used for this profile\n
/// \b imageid - id of image used for this profile\n
/// \b nasshare - share exported by nas to the vmhost\n
/// \b datastorepath - path to where vm data files are stored\n
/// \b vmpath - path to where vm configuration files are stored\n
/// \b virtualswitch0 - name of first virtual switch\n
/// \b virtualswitch1 - name of second virtual switch\n
/// \b vmdisk - "localdisk" or "networkdisk" - whether or not vm files are
/// stored on local disk or network attached storage
/// \b username - vmware username associated with this profile\n
/// \b password - vmware password associated with this profile
///
/// \brief gets information about vm profiles and returns it as an array
///
////////////////////////////////////////////////////////////////////////////////
function getVMProfiles($id="") {
	$query = "SELECT vp.id, "
	       .        "vp.profilename AS name, "
	       .        "vt.name AS type, "
	       .        "vp.vmtypeid, "
	       .        "i.prettyname AS image, "
	       .        "vp.imageid, "
	       .        "vp.nasshare, "
	       .        "vp.datastorepath, "
	       .        "vp.vmpath, "
	       .        "vp.virtualswitch0, "
	       .        "vp.virtualswitch1, "
	       .        "vp.vmdisk, "
	       .        "vp.username, "
	       .        "vp.password "
	       . "FROM vmprofile vp "
	       . "LEFT JOIN vmtype vt ON (vp.vmtypeid = vt.id) "
	       . "LEFT JOIN image i ON (vp.imageid = i.id)";
	if(! empty($id))
		$query .= " AND vp.id = $id";
	$qh = doQuery($query, 101);
	$ret = array();
	while($row = mysql_fetch_assoc($qh))
		$ret[$row['id']] = $row;
	return $ret;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getVMtypes()
///
/// \return an array where each key is the id of the type and each element is
/// the name of the type
///
/// \brief gets the entries from the vmtype table
///
////////////////////////////////////////////////////////////////////////////////
function getVMtypes() {
	$types = array();
	$qh = doQuery("SELECT id, name FROM vmtype", 101);
	while($row = mysql_fetch_assoc($qh))
		$types[$row['id']] = $row['name'];
	return $types;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addContinuationsEntry($nextmode, $data, $duration, $deleteFromSelf,
///                           $multicall, $repeatProtect)
///
/// \param $nextmode - next mode to go in to 
/// \param $data (optional, default=array())- array of data to make available
/// in $nextmode
/// \param $duration (optional, default=SECINWEEK)- how long this continuation
/// should be available (in seconds)
/// \param $deleteFromSelf (optional, default=1)- set the deletefromid to be
/// the id of this continuation
/// \param $multicall (optional, default=1) - boolean, if false, entry should be
/// deleted after being called once
/// \param $repeatProtect (optional, default=0) - boolean, if true, we add
/// the current continuationid to $data; this keeps us from having a tree
/// structure "loop" with the continuations; this situation occurs when we have
/// a page that can lead off in 2 directions, one of which ends up causing us
/// to come back to the page - then the continuation in the other direction
/// ends up having conflicting parents
///
/// \return an encrypted string that can be passed to the client as an
/// identifier for where to continue execution
///
/// \brief generates a continuation id based on $data and $nextmode; if the id
/// already exists in continuations, updates that entry's expiretime; if not,
/// adds an entry
///
////////////////////////////////////////////////////////////////////////////////
function addContinuationsEntry($nextmode, $data=array(), $duration=SECINWEEK,
                               $deleteFromSelf=1, $multicall=1,
                               $repeatProtect=0) {
	global $user, $mode, $inContinuation, $continuationid;
	if($repeatProtect)
		$data['______parent'] = $continuationid;
	$serdata = serialize($data);
	$contid = md5($mode . $nextmode . $serdata . $user['id']);
	$serdata = mysql_escape_string($serdata);
	$expiretime = unixToDatetime(time() + $duration);
	$query = "SELECT id, "
	       .        "parentid "
	       . "FROM continuations "
	       . "WHERE id = '$contid' AND "
	       .       "userid = {$user['id']}";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		# update expiretime
		$query = "UPDATE continuations "
		       . "SET expiretime = '$expiretime' "
		       . "WHERE id = '$contid' AND "
		       .       "userid = {$user['id']}";
		doQuery($query, 101);
	}
	else {
		if(! $inContinuation)
			$parent = 'NULL';
		else
			$parent = "'$continuationid'";
		if($deleteFromSelf || ! $inContinuation) {
			$deletefromid = $contid;
			$parent = 'NULL';
		}
		else {
			$query = "SELECT deletefromid "
			       . "FROM continuations "
			       . "WHERE id = '$continuationid' AND "
			       .       "userid = {$user['id']}";
			$qh = doQuery($query, 101);
			if(! $row = mysql_fetch_assoc($qh))
				abort(108);
			$deletefromid = $row['deletefromid'];
		}
		$query = "INSERT INTO continuations "
		       .        "(id, "
		       .        "userid, "
		       .        "expiretime, "
		       .        "frommode, "
		       .        "tomode, "
		       .        "data, "
		       .        "multicall, "
		       .        "parentid, "
		       .        "deletefromid) "
		       . "VALUES "
		       .        "('$contid', "
		       .        "{$user['id']}, "
		       .        "'$expiretime', "
		       .        "'$mode', "
		       .        "'$nextmode', "
		       .        "'$serdata', "
		       .        "$multicall, "
		       .        "$parent, "
		       .        "'$deletefromid')";
		doQuery($query, 101);
	}
	$salt = generateString(8);
	$now = time();
	$data = "$salt:$contid:{$user['id']}:$now";
	$edata = encryptData($data);
	$udata = urlencode($edata);
	return $udata;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getContinuationsData($data)
///
/// \param $data - data as returned by addContinuationsEntry
///
/// \return an array with these keys:\n
/// \b frommode - current mode\n
/// \b nextmode - mode to go to next\n
/// \b userid - id from user table\n
/// \b data - data saved in the db for this continuation
///
/// \brief gets data saved in continuations table associated with $data
///
////////////////////////////////////////////////////////////////////////////////
function getContinuationsData($data) {
	global $user, $continuationid;
	if(array_key_exists('continuation', $_POST))
		$edata = urldecode($data);
	else
		$edata = $data;
	if(! ($ddata = decryptData($edata)))
		return array('error' => 'invalid input');
	$items = explode(':', $ddata);
	$now = time();
	$continuationid = $items[1];

	# validate input
	if((count($items) != 4) ||
	   (! preg_match('/^[0-9a-fA-F]+$/', $continuationid)) ||
	   (! is_numeric($items[2])) ||
	   /*($items[1] != $user['id']) ||*/
	   (! is_numeric($items[3])) ||
	   ($items[3] > $now)) {
		return array('error' => 'invalid input');
	}

	# get continuation
	$query = "SELECT UNIX_TIMESTAMP(expiretime) AS expiretime, "
	       .        "frommode, "
	       .        "tomode, "
	       .        "data, "
	       .        "multicall, "
	       .        "deletefromid "
	       . "FROM continuations "
	       . "WHERE id = '$continuationid' AND "
	       .       "userid = {$items[2]}";
	$qh = doQuery($query, 101);

	# return error if it is not there
	if(! ($row = mysql_fetch_assoc($qh)))
		return array('error' => 'continuation does not exist');

	# return error if it is expired
	if($row['expiretime'] < $now) {
		$query = "DELETE FROM continuations "
		       . "WHERE id = '{$row['deletefromid']}' AND "
		       .       "userid = {$items[2]}";
		doQuery($query, 101, 'vcl', 1);
		return array('error' => 'expired');
	}

	# remove if multicall is 0
	if($row['multicall'] == 0) {
		$query = "DELETE FROM continuations "
		       . "WHERE id = '{$row['deletefromid']}' AND "
		       .       "userid = {$items[2]}";
		doQuery($query, 101, 'vcl', 1);
	}
	return array('frommode' => $row['frommode'],
	             'nextmode' => $row['tomode'],
	             'userid' => $items[2],
	             'data' => unserialize($row['data']));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn continuationsError()
///
/// \brief prints an error page related to a continuations problem
///
////////////////////////////////////////////////////////////////////////////////
function continuationsError() {
	global $contdata, $printedHTMLheader, $HTMLheader;
	if(empty($HTMLheader))
		printHTMLHeader();
	if(! $printedHTMLheader) {
		$printedHTMLheader = 1;
		print $HTMLheader;
	}
	if(array_key_exists('error', $contdata)) {
		switch($contdata['error']) {
		case 'invalid input':
			print "<h2>Error: Invalid Input</h2><br>\n";
			print "You submitted input invalid for this web site. If you have no ";
			print "idea why this happened and the problem persists, please email ";
			print "<a href=\"mailto:" . HELPEMAIL . "?Subject=Problem%20With%20VCL\">";
			print HELPEMAIL . "</a> for further assistance.  Please include the ";
			print "steps you took that led up to this problem in your email message.";
			break;
		case 'continuation does not exist':
		case 'expired':
			print "<h2>Error: Invalid Input</h2><br>\n";
			print "You submitted expired data to this web site. Please restart the ";
			print "steps you were following without using your browser's <strong>";
			print "Back</strong> button.";
			break;
		default:
			print "<h2>Error: Invalid Input</h2><br>\n";
			print "An error has occurred.  If this problem persists, please email ";
			print "<a href=\"mailto:" . HELPEMAIL . "?Subject=Problem%20With%20VCL\">";
			print HELPEMAIL . "</a> for further assistance.  Please include the ";
			print "steps you took that led up to this problem in your email message.";
		}
	}
	printHTMLFooter();
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getShibauthData($id)
///
/// \param $id - id for entry in shibauth table
///
/// \return NULL if id not found in table or array of data with these keys:\n
/// \b userid - id of user that data belongs to\n
/// \b ts - datetime of when authdata was created\n
/// \b sessid - shibboleth session id\n
/// \b Shib-Application-ID - ??\n
/// \b Shib-Identity-Provider - ??\n
/// \b Shib-AuthnContext-Dec - ??\n
/// \b Shib-logouturl - idp's logout url\n
/// \b eppn - edu person principal name for user\n
/// \b unscoped-affiliation - shibboleth unscoped affiliation\n
/// \b affiliation - shibboleth scoped affiliation
///
/// \brief gets entry from shibauth table
///
////////////////////////////////////////////////////////////////////////////////
function getShibauthData($id) {
	$query = "SELECT id, "
	       .        "userid, "
	       .        "ts, "
	       .        "sessid, "
	       .        "data "
	       . "FROM shibauth "
	       . "WHERE id = $id";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		$data = unserialize($row['data']);
		unset($row['data']);
		$data2 = array_merge($row, $data);
		return $data2;
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn xmlrpccall()
///
/// \brief registers all functions available to xmlrpc, handles the current
/// xmlrpc call
///
////////////////////////////////////////////////////////////////////////////////
function xmlrpccall() {
	global $xmlrpc_handle, $HTTP_RAW_POST_DATA, $user;
	# create xmlrpc handle
	$xmlrpc_handle = xmlrpc_server_create();
	# register functions available via rpc calls
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCtest", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetImages", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddRequest", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetRequestStatus", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetRequestConnectData", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCendRequest", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetRequestIds", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCblockAllocation", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCprocessBlockTime", "xmlRPChandler");

	print xmlrpc_server_call_method($xmlrpc_handle, $HTTP_RAW_POST_DATA, '');
	xmlrpc_server_destroy($xmlrpc_handle);
	semUnlock();
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn xmlrpcgetaffiliations()
///
/// \brief registers function to handle xmlrpcaffiliations and handles the call
///
////////////////////////////////////////////////////////////////////////////////
function xmlrpcgetaffiliations() {
	global $xmlrpc_handle, $HTTP_RAW_POST_DATA;
	# create xmlrpc handle
	$xmlrpc_handle = xmlrpc_server_create();
	# register functions available via rpc calls
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaffiliations", "xmlRPChandler");

	print xmlrpc_server_call_method($xmlrpc_handle, $HTTP_RAW_POST_DATA, '');
	xmlrpc_server_destroy($xmlrpc_handle);
	semUnlock();
	dbDisconnect();
	exit;
}
////////////////////////////////////////////////////////////////////////////////
///
/// \fn xmlRPChandler($function, $args, $blah)
///
/// \param $function - name of a function to call
/// \param $args - array of arguments to pass when calling $function, use empty
/// array if $function takes no args
/// \param $blah - not used, but required by xmlrpc_server_call_method
///
/// \return whatever $function returns
///
/// \brief calls $function with $args (if non-empty array) and returns whatever
/// $function returns
///
////////////////////////////////////////////////////////////////////////////////
function xmlRPChandler($function, $args, $blah) {
	global $user, $remoteIP;
	header("Content-type: text/xml");
	$apiversion = processInputData($_SERVER['HTTP_X_APIVERSION'], ARG_NUMERIC);
	if($function == 'XMLRPCaffiliations')
		$keyid = 0;
	elseif($apiversion == 1)
		$keyid = $user['xmlrpckeyid'];
	else
		$keyid = $user['id'];
	if(function_exists($function)) {
		$saveargs = serialize($args);
		$query = "INSERT INTO xmlrpcLog "
		       .        "(xmlrpcKeyid, " 
		       .        "timestamp, "
		       .        "IPaddress, "
		       .        "method, "
		       .        "apiversion, "
		       .        "comments) "
		       . "VALUES " 
		       .        "($keyid, "
		       .        "NOW(), "
		       .        "'$remoteIP', "
		       .        "'$function', "
		       .        "$apiversion, "
		       .        "'$saveargs')";
		doQuery($query, 101);
	}
	else {
		printXMLRPCerror(2);
		dbDisconnect();
		semUnlock();
		exit;
	}

	if(count($args))
		return call_user_func_array($function, $args);
	else
		return $function();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn xmlRPCabort($errcode, $query)
///
/// \param $errcode - an error code from $ERRORS
/// \param $query - (optional, default="") a query
///
/// \brief call this to handle errors for XML RPC connections
///
////////////////////////////////////////////////////////////////////////////////
function xmlRPCabort($errcode, $query='') {
	global $mysql_link_vcl, $mysql_link_acct, $ERRORS, $user, $mode;
	global $XMLRPCERRORS;
	if(ONLINEDEBUG && $user["adminlevel"] == "developer") {
		$msg = '';
		if($errcode >= 100 && $errcode < 400) {
			$msg .= mysql_error($mysql_link_vcl) . " $query ";
		}
		$msg .= $ERRORS["$errcode"];
		$XMLRPCERRORS[100] = $msg;
		$faultcode = 100;
	}
	else {
		$message = "";
		if($errcode >= 100 && $errcode < 400) {
			$message .= mysql_error($mysql_link_vcl) . "\n";
			$message .= mysql_error($mysql_link_acct) . "\n";
			$message .= $query . "\n";
		}
		$message .= "ERROR($errcode): " . $ERRORS["$errcode"] . "\n";
		$message .= "Logged in user was " . $user["unityid"] . "\n";
		$message .= "Mode was $mode\n\n";
		if($errcode == 20) {
			$urlArray = explode('?', $_SERVER["HTTP_REFERER"]);
			$message .= "HTTP_REFERER URL - " . $urlArray[0] . "\n";
			$message .= "correct URL - " . BASEURL . SCRIPT . "\n";
		}
		$message .= getBacktraceString(FALSE);
		$mailParams = "-f" . ENVELOPESENDER;
		mail(ERROREMAIL, "Error with VCL XMLRPC call", $message, '', $mailParams);
		$faultcode = 1;
	}
	printXMLRPCerror($faultcode);
	dbDisconnect();
	semUnlock();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printXMLRPCerror($errcode)
///
/// \param $errcode - an error code from $XMLRPCERRORS
///
/// \brief prints the XML for an RPC error
///
////////////////////////////////////////////////////////////////////////////////
function printXMLRPCerror($errcode) {
	global $XMLRPCERRORS;
	print "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?>\n";
	print "<methodResponse>\n";
	print "<fault>\n";
	print " <value>\n";
	print "  <struct>\n";
	print "   <member>\n";
	print "    <name>faultString</name>\n";
	print "    <value>\n";
	print "     <string>{$XMLRPCERRORS[$errcode]}</string>\n";
	print "    </value>\n";
	print "   </member>\n";
	print "   <member>\n";
	print "    <name>faultCode</name>\n";
	print "    <value>\n";
	print "     <int>$errcode</int>\n";
	print "    </value>\n";
	print "   </member>\n";
	print "  </struct>\n";
	print " </value>\n";
	print "</fault>\n";
	print "</methodResponse>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn json_encode()
///
/// \brief json_encode was introduced in php 5.2, this function was taked from
/// the comments of the help page for that function for php < 5.2
///
////////////////////////////////////////////////////////////////////////////////
if(! function_exists('json_encode')) {
function json_encode($a=false) {
	if(is_null($a))
		return 'null';
	if($a === false)
		return 'false';
	if($a === true)
		return 'true';
	if(is_scalar($a)) {
		if (is_float($a)) {
			 // Always use "." for floats.
			 return floatval(str_replace(",", ".", strval($a)));
		}
 
		if (is_string($a)) {
			 static $jsonReplaces = array(array("\\", "/", "\n", "\t", "\r", "\b", "\f", '"'), array('\\\\', '\\/', '\\n', '\\t', '\\r', '\\b', '\\f', '\"'));
			return '"' . str_replace($jsonReplaces[0], $jsonReplaces[1], $a) . '"';
		}
		else
			return $a;
	}
	$isList = true;
	for ($i = 0, reset($a); $i < count($a); $i++, next($a)) {
		if (key($a) !== $i) {
			$isList = false;
			break;
		}
	}
	$result = array();
	if ($isList) {
		foreach ($a as $v) $result[] = json_encode($v);
		return '[' . join(',', $result) . ']';
	}
	else {
		foreach($a as $k => $v)
			$result[] = json_encode($k).':'.json_encode($v);
		return '{' . join(',', $result) . '}';
	}
}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn vcldquery()
///
/// \brief this function is a sort of wrapper for a web API for vcld\n
/// \n
/// This allows the vcld daemon to call this web code so code does not
/// have to be developed in both perl and php.  The perl code needs to use
/// the \b LWP::Simple and \b WDDX libraries.  Data returned from the called function
/// is returned in a WDDX serialized structure.  To call a function, use the 
/// perl \c get function from \b LWP::Simple, calling \c index.php with \c mode=vcldquery,
/// \c key=&lt;shared \c key&gt;, \c query=&lt;comma \c delimited \c list&gt; where the first
/// item in the list is the function to call and the rest of the items in the
/// list are the arguments to the function.  If an argument needs to be an
/// array, use a colon delimited list for the elements of the array.  If you
/// need the array to have 0 or 1 items, either use just a : or add a : at the
/// end of the first element. Example:\n
/// \code
/// my $doc = get("http://..../index.php?mode=vcldquery&key=<key>&query=getOverallUserPrivs,1");
/// my $doc_id = new WDDX;
/// my $wddk_obj = $doc_id->deserialize($doc);
/// my $value = $wddx_obj->as_hasref();
/// $value->{"data"}; # will contain what the php function (getOverallUserPrivs) returned
/// \endcode
///
////////////////////////////////////////////////////////////////////////////////

/* /// \example vcldphpcall.pl */
function vcldquery() {
	$query = processInputVar("query", ARG_STRING);
	$arr = explode(',', $query);
	$function = array_shift($arr);
	$args = array();
	foreach($arr as $item) {
		if(ereg(':', $item)) {
			$item = array_diff(explode(':', $item), array(""));
		}
		array_push($args, $item);
	}
	require_once(".ht-inc/groups.php");
	require_once(".ht-inc/privileges.php");
	require_once(".ht-inc/requests.php");
	require_once(".ht-inc/schedules.php");
	require_once(".ht-inc/statistics.php");
	require_once(".ht-inc/userpreferences.php");

	if(count($args) == 0)
		$data = $function();
	elseif(count($args) == 1)
		$data = $function($args[0]);
	elseif(count($args) == 2)
		$data = $function($args[0], $args[1]);
	elseif(count($args) == 3)
		$data = $function($args[0], $args[1], $args[2]);
	elseif(count($args) == 4)
		$data = $function($args[0], $args[1], $args[2], $args[3]);
	elseif(count($args) == 5)
		$data = $function($args[0], $args[1], $args[2], $args[3], $args[4]);
	elseif(count($args) == 6)
		$data = $function($args[0], $args[1], $args[2], $args[3], $args[4], $args[5]);

	print wddx_serialize_vars("data");
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn menulistLI($page)
///
/// \param $page - name of a page
///
/// \return a list item tag, with the class set to selected if this mode belogs
/// to this page
///
/// \brief determines if the current mode is part of $page and returns a list
/// item tag with the class set if it is, or just a list item tag if it is not
///
////////////////////////////////////////////////////////////////////////////////
function menulistLI($page) {
	global $mode, $actions;
	$mymode = $mode;
	if(empty($mymode))
		$mymode = "home";
	if($actions['pages'][$mymode] == $page)
		return "<li class=selected>";
	else
		return "<li>";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sendHeaders()
///
/// \brief makes any needed header calls for the current mode
///
////////////////////////////////////////////////////////////////////////////////
function sendHeaders() {
	global $mode, $user, $authed, $oldmode, $viewmode, $actionFunction, $skin;
	global $shibauthed;
	$setwrapreferer = processInputVar('am', ARG_NUMERIC, 0);
	if(! $authed && $mode == "auth") {
		/*if($oldmode != "auth" && $oldmode != "" && array_key_exists('mode', $_GET)) {
			$cookieHeaderString = "WRAP_REFERER=" . BASEURL . SCRIPT . "?mode=$oldmode; path=/; domain=" . COOKIEDOMAIN;
			$itecscookie = BASEURL . SCRIPT . "?mode=$oldmode";
		}
		else {
			$cookieHeaderString = "WRAP_REFERER=" . BASEURL . "; path=/; domain=" . COOKIEDOMAIN;
			$itecscookie = BASEURL;
		}
		header("Set-Cookie: $cookieHeaderString");
		setcookie("ITECSAUTH_RETURN", "$itecscookie", 0, "/", COOKIEDOMAIN);
		setcookie("ITECSAUTH_CSS", "vcl.css", 0, "/", COOKIEDOMAIN);*/
		header("Location: " . BASEURL . SCRIPT . "?mode=selectauth");
		dbDisconnect();
		exit;
	}
	elseif(! $authed && $mode == 'selectauth' && $setwrapreferer == 1) {
		$tmp = explode('/', $_SERVER['HTTP_REFERER']);
		if($tmp[2] == 'vcl.ncsu.edu')
			$cookieHeaderString = "WRAP_REFERER={$_SERVER['HTTP_REFERER']}; path=/; domain=" . COOKIEDOMAIN;
		else
			$cookieHeaderString = "WRAP_REFERER=https://vcl.ncsu.edu/; path=/; domain=" . COOKIEDOMAIN;
		header("Set-Cookie: $cookieHeaderString");
	}
	switch($mode) {
		case 'logout':
			if($shibauthed) {
				$shibdata = getShibauthData($shibauthed);
				dbDisconnect();
				header("Location: {$shibdata['Shib-logouturl']}");
				exit;
			}
		case 'shiblogout':
			setcookie("WRAP16", "", time() - 10, "/", COOKIEDOMAIN);
			setcookie("WRAP_REFERER", "", time() - 10, "/", COOKIEDOMAIN);
			setcookie("ITECSAUTH", "", time() - 10, "/", COOKIEDOMAIN);
			setcookie("VCLAUTH", "", time() - 10, "/", COOKIEDOMAIN);
			if($shibauthed) {
				$msg = '';
				$shibdata = getShibauthData($shibauthed);
				# find and clear shib cookies
				/*foreach(array_keys($_COOKIE) as $key) {
					if(preg_match('/^_shibsession[_0-9a-fA-F]+$/', $key))
						setcookie($key, "", time() - 10, "/", $_SERVER['SERVER_NAME']);
					elseif(preg_match('/^_shibstate_/', $key))
						setcookie($key, "", time() - 10, "/", $_SERVER['SERVER_NAME']);
				}*/
				doQuery("DELETE FROM shibauth WHERE id = $shibauthed", 101);
				stopSession();
				dbDisconnect();
				print "<html>\n";
				print "   <head>\n";
				print "      <style type=\"text/css\">\n";
				print "         .red {\n";
				print "            color: red;\n";
				print "         }\n";
				print "         body{\n";
				print "            margin:0px; color: red;\n";
				print "         }\n";
				print "      </style>\n";
				print "   </head>\n";
				print "   <body>\n";
				print "      <span class=red>Done.</span>&nbsp;&nbsp;&nbsp;<a target=\"_top\" href=\"" . BASEURL . "/\">Return to VCL</a>\n";
				#print "      <iframe src=\"http://{$_SERVER['SERVER_NAME']}/Shibboleth.sso/Logout\" class=hidden>\n";
				#print "      </iframe>\n";
				/*if($mode == 'logout') {
					print "      <iframe src=\"{$shibdata['Shib-logouturl']}\" class=hidden>\n";
					print "      </iframe>\n";
				}*/
				print "   </body>\n";
				print "</html>\n";
				exit;
			}
			header("Location: " . HOMEURL);
			stopSession();
			dbDisconnect();
			exit;
	}
	if($mode == "submitviewmode") {
		$expire = time() + 31536000; //expire in 1 year
		/*if(array_key_exists('WRAP_USERID', $_SERVER)) {
			$testuser = getUserInfo("{$_SERVER['WRAP_USERID']}@NCSU");
			if($testuser['adminlevelid'] == ADMIN_DEVELOPER) {
				$viewasuser = processInputVar("viewasuser", ARG_STRING, $_SERVER['WRAP_USERID']);
				if(validateUserid($viewasuser)) {
					if($viewasuser == $_SERVER['WRAP_USERID'])
						setcookie("VCLTESTUSER", "", time() - 10, "/", COOKIEDOMAIN);
					else
						setcookie("VCLTESTUSER", $viewasuser, $expire, "/", COOKIEDOMAIN);
				}
			}
		}*/
		$newviewmode = processInputVar("viewmode", ARG_NUMERIC);
		if(! empty($newviewmode) && $newviewmode <= $user['adminlevelid'])
			setcookie("VCLVIEWMODE", $newviewmode, $expire, "/", COOKIEDOMAIN);
		stopSession();
		header("Location: " . BASEURL . SCRIPT);
		dbDisconnect();
		exit;
	}
	if($mode == "statgraphday" ||
	   $mode == "statgraphdayconcuruser" ||
	   $mode == "statgraphdayconcurblade" ||
	   $mode == "statgraphhour") {
		$actionFunction();
		dbDisconnect();
		exit;
	}
	if($mode == "viewNodes") {
		$openNodes = processInputVar("openNodes", ARG_STRING);
		$activeNode = processInputVar("activeNode", ARG_NUMERIC);
		if(! empty($openNodes)) {
			$expire = time() + 31536000; //expire in 1 year
			setcookie("VCLNODES", $openNodes, $expire, "/", COOKIEDOMAIN);
		}
		if(! empty($activeNode)) {
			$expire = time() + 31536000; //expire in 1 year
			setcookie("VCLACTIVENODE", $activeNode, $expire, "/", COOKIEDOMAIN);
		}
		return;
	}
	if($mode == "submitDeleteNode") {
		$activeNode = processInputVar("activeNode", ARG_NUMERIC);
		$nodeinfo = getNodeInfo($activeNode);
		$expire = time() + 31536000; //expire in 1 year
		setcookie("VCLACTIVENODE", $nodeinfo["parent"], $expire, "/", COOKIEDOMAIN);

	}
	if($mode == "sendRDPfile") {
		header("Cache-Control: max-age=5, must-revalidate");
		header('Pragma: cache');
	}
	else
		header("Cache-Control: no-cache, must-revalidate");
	header("Expires: Sat, 1 Jan 2000 00:00:00 GMT");
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printHTMLHeader()
///
/// \brief prints the header part of the template
///
////////////////////////////////////////////////////////////////////////////////
function printHTMLHeader() {
	global $mode, $user, $authed, $oldmode, $viewmode, $HTMLheader;
	global $printedHTMLheader, $docreaders, $skin, $noHTMLwrappers, $actions;
	if($printedHTMLheader)
		return;
	$refresh = 0;
	if($authed && $mode == "viewRequests") {
		$requests = getUserRequests("all", $user["id"]);
		if($count = count($requests)) {
			$now = time() + (15 * 60);
			for($i = 0; $i < $count; $i++) {
				if(datetimeToUnix($requests[$i]["start"]) < $now &&
					($requests[$i]["currstateid"] == 13 ||
					($requests[$i]["currstateid"] == 14 &&
					$requests[$i]["laststateid"] == 13) ||
					$requests[$i]["currstateid"] == 3)) {
					$refresh = 1;
				}
			}
		}
	}

	if($mode != 'selectauth' && $mode != 'submitLogin')
		$HTMLheader .= getHeader($refresh);

	if(! in_array($mode, $noHTMLwrappers)) {
		print $HTMLheader;
		$printedHTMLheader = 1;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getNavMenu($inclogout, $inchome, $homeurl)
///
/// \param $inclogout - bool flag for printing logout link
/// \param $inchome - bool flag for printing home link
/// \param $homeurl - (optional, defaults to HOMEURL) url for home link
/// to point to
///
/// \return string of html to display the navigation menu
///
/// \brief build the html for the navigation menu
///
////////////////////////////////////////////////////////////////////////////////
function getNavMenu($inclogout, $inchome, $homeurl=HOMEURL) {
	global $user, $viewmode, $docreaders, $authed, $userlookupUsers, $skin;
	global $mode;
	if($authed && $mode != 'expiredemouser')
		$computermetadata = getUserComputerMetaData();
	else
		$computermetadata = array("platforms" => array(),
		                          "schedules" => array());
	$rt = '';
	if($inchome) {
		$rt .= menulistLI('home');
		$rt .= "<a href=\"$homeurl\">HOME</a></li>\n";
	}
	$rt .= menulistLI('newReservations');
	$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=newRequest\">";
	$rt .= "New Reservation</a></li>\n";
	if(in_array("imageCheckOut", $user["privileges"]) ||
		in_array("imageAdmin", $user["privileges"])) {
		$rt .= menulistLI('currentReservations');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=viewRequests\">";
		$rt .= "Current Reservations</a></li>\n";
	}
	if($viewmode == ADMIN_DEVELOPER) {
		$rt .= menulistLI('blockReservations');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=blockRequest\">";
		$rt .= "Block Reservations</a></li>\n";
	}
	$rt .= menulistLI('userPreferences');
	$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=userpreferences\">";
	$rt .= "User Preferences</a></li>\n";
	if(in_array("groupAdmin", $user["privileges"])) {
		$rt .= menulistLI('manageGroups');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=viewGroups\">";
		$rt .= "Manage Groups</a></li>\n";
	}
	if(in_array("imageAdmin", $user["privileges"])) {
		$rt .= menulistLI('manageImages');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=selectImageOption\">";
		$rt .= "Manage Images</a></li>\n";
	}
	if(in_array("scheduleAdmin", $user["privileges"])) {
		$rt .= menulistLI('manageSchedules');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=viewSchedules\">";
		$rt .= "Manage Schedules</a></li>\n";
	}
	if(in_array("computerAdmin", $user["privileges"])) {
		$rt .= menulistLI('manageComputers');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=selectComputers\">";
		$rt .= "Manage Computers</a></li>\n";
	}
	if(in_array("mgmtNodeAdmin", $user["privileges"])) {
		$rt .= menulistLI('managementNodes');
		$rt .= "<a href=\"" . BASEURL . SCRIPT;
		$rt .= "?mode=selectMgmtnodeOption\">Management Nodes</a></li>\n";
	}
	if(count($computermetadata["platforms"]) &&
		count($computermetadata["schedules"])) {
		$rt .= menulistLI('timeTable');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=pickTimeTable\">";
		$rt .= "View Time Table</a></li>\n";
	}
	if(in_array("userGrant", $user["privileges"]) ||
		in_array("resourceGrant", $user["privileges"]) ||
		in_array("nodeAdmin", $user["privileges"])) {
		$rt .= menulistLI('privileges');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=viewNodes\">";
		$rt .= "Privileges</a></li>\n";
	}
	if($viewmode == ADMIN_DEVELOPER ||
	   in_array($user['id'], $userlookupUsers)) {
		$rt .= menulistLI('userLookup');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=userLookup\">";
		$rt .= "User Lookup</a></li>\n";
	}
	if(in_array("computerAdmin", $user["privileges"])) {
		$rt .= menulistLI('vm');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=editVMInfo\">";
		$rt .= "Virtual Hosts</a></li>\n";
	}
	$rt .= menulistLI('statistics');
	$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=selectstats\">";
	$rt .= "Statistics</a></li>\n";
	if($skin != 'ecu') {
		$rt .= menulistLI('help');
		$rt .= "<a href=\"" . HELPURL . "\">Help</a></li>\n";
	}
	if($skin == 'ecu') {
		$rt .= "<li><a href=\"http://www.ecu.edu/cs-itcs/vcl/connect.cfm\">Requirements</a></li>\n";
		$rt .= "<li><a href=\"http://www.ecu.edu/cs-itcs/vcl/save.cfm\">File Saving</a></li>\n";
		$rt .= "<li><a href=\"http://www.ecu.edu/cs-itcs/vcl/faqs.cfm\">Help</a></li>\n";
	}
	if(in_array("userGrant", $user["privileges"]) ||
		in_array("resourceGrant", $user["privileges"]) ||
		in_array("nodeAdmin", $user["privileges"]) ||
		in_array($user['id'], $docreaders)) {
		$rt .= menulistLI('codeDocumentation');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=viewdocs\">";
		$rt .= "Documentation</a></li>\n";
	}
	if($inclogout) {
		$rt .= menulistLI('authentication');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=logout\">";
		$rt .= "Logout</a></li>\n";
	}
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getDojoHTML($refresh)
///
/// \param $refresh - 1 to set page to refresh, 0 not to
///
/// \brief builds the header html for dojo related stuff
///
////////////////////////////////////////////////////////////////////////////////
function getDojoHTML($refresh) {
	global $mode, $actions, $skin;
	$rt = '';
	$dojoRequires = array();
	switch($mode) {
		case 'viewNodes':
		case 'changeUserPrivs':
		case 'submitAddResourcePriv':
		case 'changeResourcePrivs':
			$dojoRequires = array('dojo.io.*',
			                      'dojo.lfx.*',
			                      'dojo.html.*',
			                      'dojo.widget.*',
			                      'dojo.widget.Button',
			                      'dojo.widget.Tree',
			                      'dojo.widget.TreeSelector',
			                      'dojo.widget.FloatingPane');
			break;
		case 'newRequest':
		case 'submitRequest':
		case 'createSelectImage':
		case 'submitCreateImage':
			$dojoRequires = array('dojo.io.*',
			                      'dojo.widget.*',
			                      'dojo.html.*');
			break;
		case 'viewRequests':
			$dojoRequires = array('dojo.io.*',
			                      'dojo.html.*',
			                      'dojo.widget.*',
			                      'dojo.widget.FloatingPane');
			break;
		case 'viewImages':
			/*$dojoRequires = array('dojo.data.ItemFileWriteStore',
			                      'dojox.grid.Grid',
			                      'dojox.grid.data.model',
			                      'dojo.parser');*/
			break;
		case 'viewImageGrouping':
		case 'submitImageGroups':
		case 'viewImageMapping':
		case 'submitImageMapping':
			$dojoRequires = array('dojo.parser',
			                      'dijit.layout.LinkPane',
			                      'dijit.layout.ContentPane',
			                      'dijit.layout.TabContainer',
			                      'dijit.form.Button');
			break;
		case 'newImage':
		case 'submitImageButton':
		case 'confirmEditOrAddImage':
		case 'submitEditImageButtons':
		case 'submitAddSubimage':
		case 'updateExistingImageComments':
		case 'updateExistingImage':
			$dojoRequires = array('dojo.parser',
			                      'dijit.InlineEditBox',
			                      'dijit.form.Textarea',
			                      'dijit.TitlePane');
			break;
		case 'selectComputers':
		case 'viewComputerGroups':
		case 'submitComputerGroups':
			$dojoRequires = array('dojo.parser',
			                      'dijit.layout.LinkPane',
			                      'dijit.layout.ContentPane',
			                      'dijit.layout.TabContainer',
			                      'dijit.form.Button');
			break;
		case 'viewGroups':
		case 'submitEditGroup':
		case 'submitAddGroup':
		case 'submitDeleteGroup':
			$dojoRequires = array('dojo.parser');
			break;
		case 'editMgmtNode':
		case 'addMgmtNode':
		case 'confirmEditMgmtnode':
		case 'confirmAddMgmtnode':
			$dojoRequires = array('dojo.parser');
			$dojoRequires = array('dijit.form.NumberSpinner');
			break;
		case 'selectauth':
			$dojoRequires = array('dojo.parser');
			break;
		case 'editVMInfo':
			$dojoRequires = array('dojo.parser',
			                      'dijit.InlineEditBox',
			                      'dijit.form.NumberSpinner',
			                      'dijit.form.Button',
			                      'dijit.form.TextBox',
			                      'dijit.form.FilteringSelect',
			                      'dijit.TitlePane',
			                      'dijit.layout.ContentPane',
			                      'dijit.layout.TabContainer',
			                      'dojo.data.ItemFileReadStore',
			                      'dijit.Dialog');
			break;
	}
	if(empty($dojoRequires))
		return '';
	switch($mode) {
		case "viewImageGrouping":
		case "submitImageGroups":
		case "viewImageMapping":
		case "submitImageMapping":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			#$rt .= "   @import \"dojo/dojo/resources/dojo.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/images.js\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true\">\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req) {
				$rt .= "   dojo.require(\"$req\");\n";
			}
			$rt .= "   });\n";
			if($mode == "viewImageGrouping" ||
				$mode == "submitImageGroups") {
				$rt .= "   dojo.addOnLoad(getImagesButton);\n";
				$rt .= "   dojo.addOnLoad(getGroupsButton);\n";
			}
			elseif($mode == "viewImageMapping" ||
				$mode == "submitImageMapping") {
				$rt .= "   dojo.addOnLoad(getMapCompGroupsButton);\n";
				$rt .= "   dojo.addOnLoad(getMapImgGroupsButton);\n";
			}
			$rt .= "</script>\n";
			return $rt;

		case 'newImage':
		case 'submitImageButton':
		case 'confirmEditOrAddImage':
		case 'submitEditImageButtons':
		case 'submitAddSubimage':
		case 'updateExistingImageComments':
		case 'updateExistingImage':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			#$rt .= "   @import \"dojo/dojo/resources/dojo.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/images.js\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true\">\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req) {
				$rt .= "   dojo.require(\"$req\");\n";
			}
			$rt .= "   });\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			$rt .= "      if(document.getElementById('hide1')) {\n";
			$rt .= "         document.getElementById('hide1').className = 'hidden';\n";
			$rt .= "         document.getElementById('hide2').className = 'hidden';\n";
			$rt .= "         document.getElementById('hide3').className = 'hidden';\n";
			$rt .= "      }\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;

		case 'viewGroups':
		case 'submitEditGroup':
		case 'submitAddGroup':
		case 'submitDeleteGroup':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			#$rt .= "    @import \"dojo/dojo/resources/dojo.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"></script>\n";
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req) {
				$rt .= "   dojo.require(\"$req\");\n";
			}
			$rt .= "   });\n";
			$rt .= "   dojo.addOnLoad(function() {document.onmousemove = updateMouseXY;});\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/groups.js\"></script>\n";
			return $rt;

		case 'editMgmtNode':
		case 'addMgmtNode':
		case 'confirmEditMgmtnode':
		case 'confirmAddMgmtnode':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			#$rt .= "   @import \"dojo/dijit/themes/tundra/tundra.css\";\n";
			#$rt .= "    @import \"dojo/dojo/resources/dojo.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true\">\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req) {
				$rt .= "   dojo.require(\"$req\");\n";
			}
			$rt .= "   });\n";
			$rt .= "   dojo.addOnLoad(function() {document.onmousemove = updateMouseXY;});\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/managementnodes.js\"></script>\n";
			return $rt;

		case "selectComputers":
		case "viewComputerGroups":
		case "submitComputerGroups":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			#$rt .= "   @import \"dojo/dojo/resources/dojo.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/computers.js\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true\">\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req) {
				$rt .= "   dojo.require(\"$req\");\n";
			}
			$rt .= "   });\n";
			if($mode != 'selectComputers') {
				$rt .= "   dojo.addOnLoad(getCompsButton);\n";
				$rt .= "   dojo.addOnLoad(getGroupsButton);\n";
			}
			$rt .= "</script>\n";
			return $rt;
		case 'selectauth':
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"></script>\n";
			$rt .= "<script type=\"text/javascript\">\n";
			foreach($dojoRequires as $req) {
				$rt .= "   dojo.require(\"$req\");\n";
			}
			$authtype = processInputVar("authtype", ARG_STRING);
			$rt .= "   dojo.addOnLoad(function() {document.loginform.userid.focus(); document.loginform.userid.select();});\n";
			$rt .= "</script>\n";
			return $rt;
		case "editVMInfo":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			#$rt .= "   @import \"dojo/dojo/resources/dojo.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/vm.js\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true\">\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req) {
				$rt .= "   dojo.require(\"$req\");\n";
			}
			$rt .= "   });\n";
			$rt .= "dojo.addOnLoad(function() {";
			$rt .=                   "var dialog = dijit.byId('profileDlg'); ";
			$rt .=                   "dojo.connect(dialog, 'hide', cancelVMprofileChange);});";
			/*if($mode != 'selectComputers') {
				$rt .= "   dojo.addOnLoad(getCompsButton);\n";
				$rt .= "   dojo.addOnLoad(getGroupsButton);\n";
			}*/
			$rt .= "</script>\n";
			return $rt;
	}
	$rt .= "<script type=\"text/javascript\" src=\"dojoAjax/dojo.js\"></script>";
	$rt .= "<script type=\"text/javascript\">\n";
	foreach($dojoRequires as $req) {
		$rt .= "   dojo.require(\"$req\");\n";
	}
	$rt .= "   function RPCwrapper(data, callback) {\n";
	$rt .= "      dojo.io.bind({\n";
	$rt .= "         url: \"" . BASEURL . SCRIPT . "\",\n";
	$rt .= "         method: \"post\",\n";
	$rt .= "         content: data,\n";
	$rt .= "         load: callback,\n";
	$rt .= "         error: errorHandler\n";
	$rt .= "      });\n";
	$rt .= "   }\n";
	if($actions['pages'][$mode] == 'privileges') {
		$rt .= "   var treeListener = {\n";
		$rt .= "      nodeExpand: function(message) {\n";
		$rt .= "         var nodes = dojo.io.cookie.get('VCLNODES');\n";
		$rt .= "         if(nodes) {\n";
		$rt .= "            var nodesArr = nodes.split(':');\n";
		$rt .= "            if(! nodesArr.inArray(message.source.widgetId)) {\n";
		$rt .= "               nodesArr.push(message.source.widgetId);\n";
		$rt .= "               nodes = nodesArr.join(':');\n";
		$rt .= "            }\n";
		$rt .= "         }\n";
		$rt .= "         else {\n";
		$rt .= "            nodes = message.source.widgetId;\n";
		$rt .= "         }\n";
		$rt .= "         dojo.io.cookie.set('VCLNODES', nodes, 365, '/', '" . COOKIEDOMAIN . "');\n";
		$rt .= "      },\n";
		$rt .= "      nodeCollapse: function(message) {\n";
		$rt .= "         checkSelectParent(message);\n";
		$rt .= "         var nodes = dojo.io.cookie.get('VCLNODES');\n";
		$rt .= "         var nodesArr = nodes.split(':');\n";
		$rt .= "         var index;\n";
		$rt .= "         if(index = nodesArr.search(message.source.widgetId)) {\n";
		$rt .= "            nodesArr.splice(index, 1);\n";
		$rt .= "            nodes = nodesArr.join(':');\n";
		$rt .= "            dojo.io.cookie.set('VCLNODES', nodes, 365, '/', '" . COOKIEDOMAIN . "');\n";
		$rt .= "         }\n";
		$rt .= "      }\n";
		$rt .= "   };\n";
	}
	$rt .= "   dojo.addOnLoad(function() {\n";
	$rt .= "      testJS();\n";
	$rt .= "      document.onmousemove = updateMouseXY;\n";
	if($actions['pages'][$mode] == 'privileges')
		$rt .= "      initPrivTree();\n";
	if($mode == 'newRequest' || $mode == 'submitRequest') {
		$rt .= "   if(dojo.byId('waittime'))\n";
		$rt .= "      dojo.byId('waittime').className = 'shown';\n";
	}
	if($refresh && $mode == 'viewRequests') {
		$rt .= "   setTimeout(function() {if(! dojo.widget.byId('resStatusPane')) {AJdojoCreate('resStatusPane');}}, 1200);\n";
		$rt .= "   refresh_timer = setTimeout(resRefresh, 20000);\n";
	}
	$rt .= "   });\n";
	$rt .= "</script>\n";
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printHTMLFooter()
///
/// \brief prints the footer part of the html template
///
////////////////////////////////////////////////////////////////////////////////
function printHTMLFooter() {
	global $mode, $noHTMLwrappers;
	if(in_array($mode, $noHTMLwrappers))
		return;
	print getFooter();
}

?>
