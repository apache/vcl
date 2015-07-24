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
require_once(".ht-inc/phpseclib/Crypt/AES.php");
require_once(".ht-inc/spyc-0.5.1/Spyc.php");
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

/// global array used to hold request information between calling isAvailable
/// and addRequest
$requestInfo = array();

/// global array to cache arrays of node parents for getNodeParents
$nodeparents = array();
/// global array to cache various data
$cache = array();
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
	global $mode, $user, $remoteIP, $authed, $oldmode, $semid;
	global $days, $phpVer, $keys, $pemkey, $AUTHERROR;
	global $passwdArray, $skin, $contdata, $lastmode, $inContinuation;
	global $ERRORS, $actions;
	global $affilValFunc, $addUserFunc, $updateUserFunc, $addUserFuncArgs;
	global $uniqid;

	define("SECINDAY", 86400);
	define("SECINWEEK", 604800);
	define("SECINMONTH", 2678400);
	define("SECINYEAR", 31536000);
	# TODO validate security of this
	if(array_key_exists("PATH_INFO", $_SERVER)) {
		$pathdata = explode("/", $_SERVER["PATH_INFO"]);
		$tmp = explode('.', $pathdata[1]);
		$_GET["mode"] = $tmp[0];
	}
	$mode = processInputVar("mode", ARG_STRING, 'main');
	$inContinuation = 0;
	$contdata = array();
	$contuserid = '';
	$continuation = processInputVar('continuation', ARG_STRING);
	if(! empty($continuation)) {
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
	$days = array(i('Sunday'), i('Monday'), i('Tuesday'), i('Wednesday'), i('Thursday'), i('Friday'), i('Saturday'));
	$phpVerArr = explode('.', phpversion());
	$phpVer = $phpVerArr[0];
	$uniqid = uniqid($_SERVER['HTTP_HOST'] . "-" . getmypid() . "-");

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

	# start auth check
	$authed = 0;
	if(array_key_exists("VCLAUTH", $_COOKIE)) {
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
					$skin = DEFAULTTHEME;
					break;
			}
		}
		else
			$skin = DEFAULTTHEME;
		if($mode != 'selectauth' && $mode != 'submitLogin')
			require_once("themes/$skin/page.php");

		require_once(".ht-inc/requests.php");
		if($mode != "logout" &&
			$mode != "shiblogout" &&
			$mode != "xmlrpccall" &&
			$mode != "xmlrpcaffiliations" &&
			$mode != "selectauth" &&
			$mode != "submitLogin" &&
			$mode != "changeLocale") {
			$oldmode = $mode;
			$mode = "auth";
		}
		if($mode == 'xmlrpccall' || $mode == 'xmlrpcaffiliations') {
			require_once(".ht-inc/xmlrpcWrappers.php");
			require_once(".ht-inc/requests.php");
			require_once(".ht-inc/serverprofiles.php");
			require_once(".ht-inc/groups.php");
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
			// if first call to getUserInfo fails, try calling with $noupdate set
			if(! $user = getUserInfo($userid, 1)) {
				$ERRORS[1] = i("Failed to get user info from database. userid was ") . "$userid";
				abort(1);
			}
		}
		if(! empty($contuserid) &&
		   $user['id'] != $contuserid)
			abort(51);
		$_SESSION['user'] = $user;
	}

	# setskin
	$skin = getAffiliationTheme($user['affiliationid']);
	require_once("themes/$skin/page.php");

	$_SESSION['mode'] = $mode;

	// check for and possibly clear dirty permission cache
	$dontClearModes = array('AJchangeUserPrivs', 'AJchangeUserGroupPrivs', 'AJchangeResourcePrivs');
	if(! in_array($mode, $dontClearModes) &&
	   array_key_exists('dirtyprivs', $_SESSION) &&
	   $_SESSION['dirtyprivs']) {
		clearPrivCache();
		$_SESSION['dirtyprivs'] = 0;
	}

	# set up $affilValFunc, $addUserFunc, $updateUserFunc for any shibonly affiliations
	$query = "SELECT id FROM affiliation WHERE shibonly = 1";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		$id = $row['id'];
		if(! array_key_exists($id, $affilValFunc)) {
			if(ALLOWADDSHIBUSERS)
				$affilValFunc[$id] = create_function('', 'return 1;');
			else
				$affilValFunc[$id] = create_function('', 'return 0;');
		}
		if(! array_key_exists($id, $addUserFunc)) {
			if(ALLOWADDSHIBUSERS) {
				$addUserFunc[$id] = 'addShibUserStub';
				$addUserFuncArgs[$id] = $id;
			}
			else
				$addUserFunc[$id] = create_function('', 'return 0;');
		}
		if(! array_key_exists($id, $updateUserFunc))
			$updateUserFunc[$id] = create_function('', 'return NULL;');
	}

	# include appropriate files
	switch($actions['pages'][$mode]) {
		case 'blockAllocations':
			require_once(".ht-inc/blockallocations.php");
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
		case 'sitemaintenance':
			require_once(".ht-inc/sitemaintenance.php");
			break;
		case 'vm':
			require_once(".ht-inc/vm.php");
			break;
		case 'dashboard':
			require_once(".ht-inc/dashboard.php");
			break;
		case 'siteconfig':
			require_once(".ht-inc/siteconfig.php");
			break;
		case 'resource':
		case 'config':
		case 'image':
		case 'computer':
		case 'managementnode':
		case 'schedule':
			require_once(".ht-inc/resource.php");
			break;
		case 'storebackend':
			require_once(".ht-inc/storebackend.php");
			break;
		case 'serverProfiles':
			require_once(".ht-inc/serverprofiles.php");
			require_once(".ht-inc/requests.php");
			break;
		default:
			require_once(".ht-inc/requests.php");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn __autoload($class)
///
/// \param $class - name of a class
///
/// \brief handles loading class implementation file for a specified class
///
////////////////////////////////////////////////////////////////////////////////
function __autoload($class) {
	global $actions;
	$class = strtolower($class);
	if(array_key_exists($class, $actions['classmapping'])) {
		require_once(".ht-inc/{$actions['classmapping'][$class]}.php");
		return;
	}
	require_once(".ht-inc/resource.php");
	require_once(".ht-inc/$class.php");
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
	global $mode, $user, $actionFunction, $authMechs;
	global $itecsauthkey, $ENABLE_ITECSAUTH, $actions, $noHTMLwrappers;
	global $inContinuation, $docreaders, $apiValidateFunc;
	if($mode == 'xmlrpccall') {
		// double check for SSL
		if(! isset($_SERVER['HTTPS']) || $_SERVER['HTTPS'] != "on") {
			printXMLRPCerror(4);   # must have SSL enabled
			dbDisconnect();
			exit;
		}
		$xmluser = processInputData($_SERVER['HTTP_X_USER'], ARG_STRING, 1);
		if(! $user = getUserInfo($xmluser)) {
			// if first call to getUserInfo fails, try calling with $noupdate set
			if(! $user = getUserInfo($xmluser, 1)) {
				$testid = $xmluser;
				$affilid = DEFAULT_AFFILID;
				getAffilidAndLogin($testid, $affilid);
				addLoginLog($testid, 'unknown', $affilid, 0);
				printXMLRPCerror(3);   # access denied
				dbDisconnect();
				exit;
			}
		}
		if(! array_key_exists('HTTP_X_PASS', $_SERVER) || strlen($_SERVER['HTTP_X_PASS']) == 0) {
			printXMLRPCerror(3);   # access denied
			dbDisconnect();
			exit;
		}
		$xmlpass = $_SERVER['HTTP_X_PASS'];
		if(get_magic_quotes_gpc())
			$xmlpass = stripslashes($xmlpass);
		$apiver = processInputData($_SERVER['HTTP_X_APIVERSION'], ARG_NUMERIC, 1);
		if($apiver == 1) {
			printXMLRPCerror(8);   # unsupported API version
			dbDisconnect();
			exit;
		}
		elseif($apiver == 2) {
			$authtype = "";
			foreach($authMechs as $key => $authmech) {
				if($authmech['affiliationid'] == $user['affiliationid']) {
					$authtype = $key;
					break;
				}
			}
			if(empty($authtype)) {
				print "No authentication mechanism found for passed in X-User";
				dbDisconnect();
				exit;
			}
			if($authMechs[$authtype]['type'] == 'ldap') {
				$auth = $authMechs[$authtype];
				$ds = ldap_connect("ldaps://{$auth['server']}/");
				if(! $ds) {
					printXMLRPCerror(5);    # failed to connect to auth server
					dbDisconnect();
					exit;
				}
				ldap_set_option($ds, LDAP_OPT_PROTOCOL_VERSION, 3);
				ldap_set_option($ds, LDAP_OPT_REFERRALS, 0);
				if($auth['lookupuserbeforeauth']) {
					# in this case, we have to look up what part of the tree the user is in
					#   before we can actually look up the user
					if(array_key_exists('masterlogin', $auth) && strlen($auth['masterlogin']))
						$res = ldap_bind($ds, $auth['masterlogin'], $auth['masterpwd']);
					else
						$res = ldap_bind($ds);
					if(! $res) {
						addLoginLog($user['unityid'], $authtype, $user['affiliationid'], 0);
						printXMLRPCerror(5);    # failed to connect to auth server
						dbDisconnect();
						exit;
					}
					$search = ldap_search($ds,
					                      $auth['binddn'], 
					                      "{$auth['lookupuserfield']}={$user['unityid']}",
					                      array('dn'), 0, 3, 15);
					if($search) {
						$tmpdata = ldap_get_entries($ds, $search);
						if(! $tmpdata['count'] || ! array_key_exists('dn', $tmpdata[0])) {
							addLoginLog($user['unityid'], $authtype, $user['affiliationid'], 0);
							printXMLRPCerror(3);   # access denied
							dbDisconnect();
							exit;
						}
						$ldapuser = $tmpdata[0]['dn'];
					}
					else {
						addLoginLog($user['unityid'], $authtype, $user['affiliationid'], 0);
						printXMLRPCerror(3);   # access denied
						dbDisconnect();
						exit;
					}
				}
				else
					$ldapuser = sprintf($auth['userid'], $user['unityid']);
				$res = ldap_bind($ds, $ldapuser, $xmlpass);
				if(! $res) {
					addLoginLog($user['unityid'], $authtype, $user['affiliationid'], 0);
					printXMLRPCerror(3);   # access denied
					dbDisconnect();
					exit;
				}
				addLoginLog($user['unityid'], $authtype, $user['affiliationid'], 1);
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
			elseif($authMechs[$authtype]['type'] == 'redirect') {
				$affilid = $authMechs[$authtype]['affiliationid'];
				if(!(isset($apiValidateFunc) && is_array($apiValidateFunc) &&
				   array_key_exists($affilid, $apiValidateFunc) && 
				   $apiValidateFunc[$affilid]($xmluser, $xmlpass))) {
					printXMLRPCerror(3);    # access denied
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
		if($apiver == 1) {
			printXMLRPCerror(8);   # unsupported API version
			dbDisconnect();
			exit;
		}
		elseif($apiver != 2) {
			printXMLRPCerror(7);    # unknown API version
			dbDisconnect();
			exit;
		}
	}
	elseif(! empty($mode)) {
		if(! in_array($mode, $actions['entry']) &&
		   ! $inContinuation) {
			$mode = "main";
			$actionFunction = "main";
			return;
	   }
		else {
			if(! $inContinuation) {
				# check that user has access to this area
				switch($mode) {
					case 'viewGroups':
						if(! in_array("groupAdmin", $user["privileges"])) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'serverProfiles':
						if(! in_array("serverProfileAdmin", $user["privileges"]) &&
						   ! in_array("serverCheckOut", $user["privileges"])) {
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
						if(! checkUserHasPerm('User Lookup (global)') &&
						   ! checkUserHasPerm('User Lookup (affiliation only)')) {
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
					case 'siteMaintenance':
						if(! checkUserHasPerm('Schedule Site Maintenance')) {
							$mode = "";
							$actionFunction = "main";
							return;
						}
						break;
					case 'dashboard':
						if(! checkUserHasPerm('View Dashboard (global)') &&
						   ! checkUserHasPerm('View Dashboard (affiliation only)')) {
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
/// \fn maintenanceCheck()
///
/// \brief checks for site being in maintenance; if so, read user message from
/// current maintenance file; print site header, maintenance message, and site
/// foother; then exit; also removes any old maintenance files
///
////////////////////////////////////////////////////////////////////////////////
function maintenanceCheck() {
	global $authed, $mode, $user;
	$now = time();
	$reg = "|" . SCRIPT . "$|";
	$search = preg_replace($reg, '', $_SERVER['SCRIPT_FILENAME']);
	$search .= "/.ht-inc/maintenance/";
	$files = glob("{$search}[0-9]*");
	if(! is_array($files))
		return;
	if(empty($files)) {
		dbConnect();
		$query = "SELECT id "
		       . "FROM sitemaintenance "
		       . "WHERE start <= NOW() AND "
		       .       "end > NOW()";
		$qh = doQuery($query);
		$ids = array();
		while($row = mysql_fetch_assoc($qh))
			$ids[] = $row['id'];
		if(empty($ids)) {
			dbDisconnect();
			return;
		}
		$allids = implode(',', $ids);
		$query = "UPDATE sitemaintenance "
		       . "SET end = NOW() "
		       . "WHERE id IN ($allids)";
		doQuery($query, 101, 'vcl', 1);
		dbDisconnect();
		return;
	}  
	$inmaintenance = 0;
	foreach($files as $file) {
		if(! preg_match("|^$search([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})$|", $file, $matches))
			continue;
		#YYYYMMDDHHMM
		$tmp = "{$matches[1]}-{$matches[2]}-{$matches[3]} {$matches[4]}:{$matches[5]}:00";
		$start = datetimeToUnix($tmp);
		if($start < $now) {
			# check to see if end time has been reached
			$fh = fopen($file, 'r');
			$msg = '';
			while($line = fgetss($fh)) {
				if(preg_match("/^END=([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})$/", $line, $matches)) {
					$tmp = "{$matches[1]}-{$matches[2]}-{$matches[3]} {$matches[4]}:{$matches[5]}:00";
					$end = datetimeToUnix($tmp);
					if($end < $now) {
						fclose($fh);
						unlink($file);
						$_SESSION['usersessiondata'] = array();
						return;
					}
					else
						$inmaintenance = 1;
				}
				else
					$msg .= $line;
			}
			fclose($fh);
			if($inmaintenance)
				break;
		}
	}
	if($inmaintenance) {
		$authed = 0;
		$mode = 'inmaintenance';
		$user = array();
		if(array_key_exists('VCLSKIN', $_COOKIE))
			$skin = strtolower($_COOKIE['VCLSKIN']);
		else
			$skin = DEFAULTTHEME;
		setVCLLocale();
		require_once("themes/$skin/page.php");
		printHTMLHeader();
		print "<h2>" . i("Site Currently Under Maintenance") . "</h2>\n";
		if(! empty($msg)) {
			$msg = htmlentities($msg);
			$msg = preg_replace("/\n/", "<br>\n", $msg);
			print "$msg<br>\n";
		}
		else
			print i("This site is currently in maintenance.") . "<br>\n";
		$niceend = strftime('%A, %x, %l:%M %P', $end);
		printf(i("The maintenance is scheduled to end <strong>%s</strong>.") . "<br><br><br>\n", $niceend);
		printHTMLFooter();
		exit;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn maintenanceNotice()
///
/// \brief checks informhoursahead for upcoming maintenance items and prints
/// message about upcoming maintenance if currently within warning window
///
////////////////////////////////////////////////////////////////////////////////
function maintenanceNotice() {
	$items = getMaintItems();
	foreach($items as $item) {
		$start = datetimeToUnix($item['start']);
		$file = date('YmdHi', $start);
		$secahead = $item['informhoursahead'] * 3600;
		if($start - $secahead < time()) {
			$reg = "|" . SCRIPT . "$|";
			$search = preg_replace($reg, '', $_SERVER['SCRIPT_FILENAME']);
			$search .= "/.ht-inc/maintenance/$file";
			$files = glob("$search");
			if(empty($files)) {
				$_SESSION['usersessiondata'] = array();
				return;
			}
			$nicestart = strftime('%A, %x, %l:%M %P', $start);
			$niceend = strftime('%A, %x, %l:%M %P', datetimeToUnix($item['end']));
			print "<div id=\"maintenancenotice\">\n";
			print "<strong>" . i("NOTICE:") . "</strong> ";
			print i("This site will be down for maintenance during the following times:") . "<br><br>\n";
			print	i("Start:") . " $nicestart<br>\n";
			print i("End:") . " $niceend.<br><br>\n";
			if($item['allowreservations']) {
				print i("You will be able to access your reserved machines during this maintenance. However, you will not be able to access information on how to connect to them.") . "<br>\n";
			}
			else {
				print i("You will not be able to access any of your reservations during this maintenance.") . "<br>\n";
			}
			print "</div>\n";
			return;
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
	$_SESSION['variables'] = array();
	unset($_SESSION['user']);
	unset($_SESSION['locales']);
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
	if(! array_key_exists('variables', $_SESSION))
		$_SESSION['variables'] = array();
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
/// \fn main()
///
/// \brief prints a welcome screen
///
////////////////////////////////////////////////////////////////////////////////
function main() {
	global $user, $authed, $mode;
	print "<H2>" . i("Welcome to the Virtual Computing Lab") . "</H2>\n";
	if($authed) {
		if(! empty($user['lastname']) && ! empty($user['preferredname']))
			print i("Hello") . " {$user["preferredname"]} {$user['lastname']}<br><br>\n";
		elseif(! empty($user['lastname']) && ! empty($user['firstname']))
			print i("Hello") . " {$user["firstname"]} {$user['lastname']}<br><br>\n";
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
			if($num == 1)
				print i("You currently have 1 reservation.") . "<br>\n";
			else
				printf(i("You currently have %d reservations.") . "<br>\n", $num);
		}
		else {
			print i("You do not have any current reservations.") . "<br>\n";
		}
		print i("Please make a selection from the menu to continue.") . "<br>\n";
	}
	else {
		print i("Please log in to start using the VCL system.") . "<br>\n";
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
	global $ENABLE_ITECSAUTH, $requestInfo, $aborting;
	if(! isset($aborting))
		$aborting = 1;
	elseif($aborting == 1)
		return;
	if($mode == 'xmlrpccall')
		xmlRPCabort($errcode, $query);
	if(ONLINEDEBUG && checkUserHasPerm('View Debug Information')) {
		if($errcode >= 100 && $errcode < 400) {
			print "<font color=red>" . mysql_error($mysql_link_vcl) . "</font><br>\n";
			error_log(mysql_error($mysql_link_vcl));
			if($ENABLE_ITECSAUTH) {
				print "<font color=red>" . mysql_error($mysql_link_acct) . "</font><br>\n";
				error_log(mysql_error($mysql_link_acct));
			}
			print "$query<br>\n";
			error_log($query);
		}
		print "ERROR($errcode): " . $ERRORS["$errcode"] . "<BR>\n";
		error_log("ERROR($errcode): " . $ERRORS["$errcode"]);
		$backtrace = getBacktraceString(FALSE);
		print "<pre>\n";
		print $backtrace;
		print "</pre>\n";
		error_log($backtrace);
	}
	else {
		$message = "";
		if($errcode >= 100 && $errcode < 400) {
			$message .= mysql_error($mysql_link_vcl) . "\n";
			if($ENABLE_ITECSAUTH)
				$message .= mysql_error($mysql_link_acct) . "\n";
			$message .= $query . "\n";
		}
		$message .= "ERROR($errcode): " . $ERRORS["$errcode"] . "\n";
		if(is_array($user) && array_key_exists('unityid', $user))
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
		if($errcode == 8)
			$message = preg_replace("/Argument#: 3 => .*\n/", "Argument#: 3 => *********\n", $message);
		$mailParams = "-f" . ENVELOPESENDER;
		error_log($message);
		mail(ERROREMAIL, "Error with VCL pages ($errcode)", $message, '', $mailParams);
		$subj = rawurlencode(i("Problem With VCL"));
		$href = "<a href=\"mailto:" . HELPEMAIL . "?Subject=$subj\">" . HELPEMAIL . "</a>";
		printf(i("An error has occurred. If this problem persists, please email %s for further assistance. Please include the steps you took that led up to this problem in your email message."), $href);
	}

	// call clearPrivCache in case that helps clear up what caused the error
	clearPrivCache();

	// release semaphore lock
	cleanSemaphore();
	dbDisconnect();
	printHTMLFooter();
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
	
	$rc = getAffilidAndLogin($loginid, $affilid);
	if($rc == -1)
		return 0;

	if(empty($affilid))
		return 0;

	$escloginid = mysql_real_escape_string($loginid);
	$query = "SELECT id "
	       . "FROM user "
	       . "WHERE unityid = '$escloginid' AND "
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
/// \fn AJvalidateUserid()
///
/// \brief checks to see if submitted userid is valid
///
////////////////////////////////////////////////////////////////////////////////
function AJvalidateUserid() {
	$user = processInputVar('user', ARG_STRING);
	if(validateUserid($user))
		sendJSON(array('status' => 'valid'));
	else
		sendJSON(array('status' => 'invalid'));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAffilidAndLogin(&$login, &$affilid)
///
/// \param $login - login for user, may include \@affiliation
/// \param $affilid - variable in which to stick the affiliation id
///
/// \return 1 if $affilid set by a registered function, 0 if set to default,
/// -1 if @affiliation was part of $login but did not contain a known
/// affiliation
///
/// \brief tries registered affiliation lookup functions to determine the
/// affiliation id of the user; if it finds it, sticks the affiliationid in
/// $affilid and sets $login to not include \@affiliation if it did
///
////////////////////////////////////////////////////////////////////////////////
function getAffilidAndLogin(&$login, &$affilid) {
	global $findAffilFuncs;
	foreach($findAffilFuncs as $func) {
		$rc = $func($login, $affilid);
		if($rc)
			return $rc;
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

	if($ENABLE_ITECSAUTH) {
		// open a connection to mysql server for accounts
		if($mysql_link_acct = mysql_connect_plus($accthost, $acctusername, $acctpassword))
			mysql_select_db("accounts", $mysql_link_acct);
		else
			$ENABLE_ITECSAUTH = 0;
	}

	// open a connection to mysql server for vcl
	if(! $mysql_link_vcl = mysql_connect_plus($vclhost, $vclusername, $vclpassword)) {
		die("Error connecting to $vclhost.<br>\n");
	}
	// select the vcl database
	mysql_select_db($vcldb, $mysql_link_vcl) or abort(104);
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
function doQuery($query, $errcode=101, $db="vcl", $nolog=0) {
	global $mysql_link_vcl, $mysql_link_acct, $user, $mode, $ENABLE_ITECSAUTH;
	if($db == "vcl") {
		if((! defined('QUERYLOGGING') || QUERYLOGGING != 0) &&
		   (! $nolog) && preg_match('/^(UPDATE|INSERT|DELETE)/', $query) &&
		   strpos($query, 'UPDATE continuations SET expiretime = ') === FALSE) {
			$logquery = str_replace("'", "\'", $query);
			$logquery = str_replace('"', '\"', $logquery);
			if(isset($user['id']))
				$id = $user['id'];
			else
				$id = 0;
			$q = "INSERT INTO querylog "
			   .        "(userid, "
			   .        "timestamp, "
			   .        "mode, "
			   .        "query) "
			   . "VALUES "
			   .        "($id, "
			   .        "NOW(), "
			   .        "'$mode', "
			   .        "'$logquery')";
			mysql_query($q, $mysql_link_vcl);
		}
		for($i = 0; ! ($qh = mysql_query($query, $mysql_link_vcl)) && $i < 3; $i++) {
			if(mysql_errno() == '1213') # DEADLOCK, sleep and retry
				usleep(50);
			else
				abort($errcode, $query);
		}
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
	$query = "SELECT id, name, prettyname, type, installtype FROM OS ORDER BY prettyname";
	$qh = doQuery($query, "115");
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
/// \b ownerid - userid of owner\n
/// \b owner - unity id of owner\n
/// \b platformid - platformid for the platform the image if for\n
/// \b platform - platform the image is for\n
/// \b osid - osid for the os on the image\n
/// \b os - os the image contains\n
/// \b installtype - method used to install image\n
/// \b ostypeid - id of the OS type in the image\n
/// \b ostype - name of the OS type in the image\n
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
/// \b sysprep - whether or not to use sysprep on creation of the image\n
/// \b connectmethods - array of enabled connect methods\n
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
	# key in $imagelist is for $includedeleted
	static $imagelist = array(0 => array(), 1 => array());
	if(! empty($imagelist[$includedeleted])) {
		if($imageid == 0)
			return $imagelist[$includedeleted];
		else
			return array($imageid => $imagelist[$includedeleted][$imageid]);
	}
	# get all image meta data
	$allmetadata = array();
	$query = "SELECT checkuser, "
	       .        "rootaccess, "
	       .        "subimages, "
	       .        "sysprep, "
	       .        "sethostname, "
	       .        "id "
	       . "FROM imagemeta";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh))
		$allmetadata[$row['id']] = $row;

	# get all image revision data
	$allrevisiondata = array();
	$query = "SELECT i.id, "
	       .        "i.imageid, "
	       .        "i.revision, "
	       .        "i.userid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS user, "
	       .        "i.datecreated, "
	       .        "DATE_FORMAT(i.datecreated, '%c/%d/%y %l:%i %p') AS prettydate, "
	       .        "i.deleted, "
	       .        "i.datedeleted, "
	       .        "i.production, "
	       .        "i.imagename "
	       . "FROM imagerevision i, "
	       .      "affiliation a, "
	       .      "user u "
	       . "WHERE i.userid = u.id AND ";
	if(! $includedeleted)
		$query .=   "i.deleted = 0 AND ";
	$query .=      "u.affiliationid = a.id";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		$id = $row['imageid'];
		unset($row['imageid']);
		if(! array_key_exists($id, $allrevisiondata))
			$allrevisiondata[$id] = array();
		$allrevisiondata[$id][$row['id']] = $row;
	}
	$query = "SELECT i.id AS id,"
	       .        "i.name AS name, "
	       .        "i.prettyname AS prettyname, "
	       .        "i.ownerid AS ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "i.platformid AS platformid, "
	       .        "p.name AS platform, "
	       .        "i.OSid AS osid, "
	       .        "o.name AS os, "
	       .        "o.installtype, "
	       .        "ot.id AS ostypeid, "
	       .        "ot.name AS ostype, "
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
	       .      "OStype ot, "
	       .      "resource r, "
	       .      "resourcetype t, "
	       .      "user u, "
	       .      "affiliation a "
	       . "WHERE i.platformid = p.id AND "
	       .       "r.resourcetypeid = t.id AND "
	       .       "t.name = 'image' AND "
	       .       "r.subid = i.id AND "
	       .       "i.OSid = o.id AND "
	       .       "o.type = ot.name AND "
	       .       "i.ownerid = u.id AND "
	       .       "u.affiliationid = a.id ";
	if(! $includedeleted)
		$query .= "AND i.deleted = 0 ";
   $query .= "ORDER BY i.prettyname";
	$qh = doQuery($query, 120);
	while($row = mysql_fetch_assoc($qh)) {
		if(is_null($row['maxconcurrent']))
			$row['maxconcurrent'] = 0;
		$imagelist[$includedeleted][$row["id"]] = $row;
		$imagelist[$includedeleted][$row["id"]]['checkuser'] = 1;
		$imagelist[$includedeleted][$row["id"]]['rootaccess'] = 1;
		if($row['ostype'] == 'windows' || $row['ostype'] == 'osx')
			$imagelist[$includedeleted][$row['id']]['sethostname'] = 0;
		else
			$imagelist[$includedeleted][$row['id']]['sethostname'] = 1;
		if($row["imagemetaid"] != NULL) {
			if(array_key_exists($row['imagemetaid'], $allmetadata)) {
				$metaid = $row['imagemetaid'];
				$imagelist[$includedeleted][$row['id']]['checkuser'] = $allmetadata[$metaid]['checkuser'];
				$imagelist[$includedeleted][$row['id']]['rootaccess'] = $allmetadata[$metaid]['rootaccess'];
				$imagelist[$includedeleted][$row['id']]['sysprep'] = $allmetadata[$metaid]['sysprep'];
				if($allmetadata[$metaid]['sethostname'] != NULL)
					$imagelist[$includedeleted][$row['id']]['sethostname'] = $allmetadata[$metaid]['sethostname'];
				$imagelist[$includedeleted][$row["id"]]["subimages"] = array();
				if($allmetadata[$metaid]["subimages"]) {
					$query2 = "SELECT imageid "
				        . "FROM subimages "
				        . "WHERE imagemetaid = $metaid";
					$qh2 = doQuery($query2, 101);
					while($row2 = mysql_fetch_assoc($qh2))
						$imagelist[$includedeleted][$row["id"]]["subimages"][] =  $row2["imageid"];
				}
			}
			else
				$imagelist[$includedeleted][$row["id"]]["imagemetaid"] = NULL;
		}
		if(array_key_exists($row['id'], $allrevisiondata))
			$imagelist[$includedeleted][$row['id']]['imagerevision'] = $allrevisiondata[$row['id']];
		$imagelist[$includedeleted][$row['id']]['connectmethods'] = getImageConnectMethods($row['id']);
	}
	if($imageid != 0)
		return array($imageid => $imagelist[$includedeleted][$imageid]);
	return $imagelist[$includedeleted];
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getServerProfiles($id)
///
/// \param $id - (optional) if specified, only return data for specified profile
///
/// \return an array where each key is a profile id whose value is an array with
/// these values:\n
/// \b name - profile name\n
/// \b description - profile description\n
/// \b imageid - id of image associated with profile\n
/// \b image - pretty name of image associated with profile\n
/// \b ownerid - user id of owner of profile\n
/// \b owner - unityid of owner of profile\n
/// \b fixedIP - IP address to be used with deployed profile\n
/// \b fixedMAC - MAC address to be used with deployed profile\n
/// \b admingroupid - id of admin user group associated with profile\n
/// \b admingroup - name of admin user group associated with profile\n
/// \b logingroupid - id of login user group associated with profile\n
/// \b logingroup - name of login user group associated with profile\n
/// \b monitored - whether or not deployed profile should be monitored\n
/// \b resourceid - resource id of profile
///
/// \brief gets information about server profiles
///
////////////////////////////////////////////////////////////////////////////////
function getServerProfiles($id=0) {
	$key = getKey(array('getServerProfiles', $id));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];

	$fixeddata = array();
	$query = "SELECT name, value FROM variable WHERE name LIKE 'fixedIPsp%'";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		$spid = str_replace('fixedIPsp', '', $row['name']);
		$fixeddata[$spid] = Spyc::YAMLLoad($row['value']);
	}

	$query = "SELECT s.id, "
	       .        "s.name, "
	       .        "s.description, "
	       .        "s.imageid, "
	       .        "i.prettyname AS image, "
	       .        "s.ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "s.fixedIP, "
	       .        "s.fixedMAC, "
	       .        "s.admingroupid, "
	       .        "CONCAT(ga.name, '@', aa.name) AS admingroup, "
	       .        "s.logingroupid, "
	       .        "CONCAT(gl.name, '@', al.name) AS logingroup, "
	       .        "s.monitored, "
	       .        "r.id AS resourceid "
	       . "FROM serverprofile s "
	       . "LEFT JOIN image i ON (i.id = s.imageid) "
	       . "LEFT JOIN user u ON (u.id = s.ownerid) "
	       . "LEFT JOIN affiliation a ON (a.id = u.affiliationid) "
	       . "LEFT JOIN usergroup ga ON (ga.id = s.admingroupid) "
	       . "LEFT JOIN affiliation aa ON (aa.id = ga.affiliationid) "
	       . "LEFT JOIN usergroup gl ON (gl.id = s.logingroupid) "
	       . "LEFT JOIN affiliation al ON (al.id = gl.affiliationid) "
	       . "LEFT JOIN resource r ON (r.subid = s.id) "
	       . "WHERE r.resourcetypeid = 17 ";
	if($id != 0)
		$query .= "AND s.id = $id";
	else
		$query .= "ORDER BY name";
	$qh = doQuery($query, 101);
	$profiles = array();
	while($row = mysql_fetch_assoc($qh)) {
		$profiles[$row['id']] = $row;
		if(array_key_exists($row['id'], $fixeddata)) {
			$profiles[$row['id']]['netmask'] = $fixeddata[$row['id']]['netmask'];
			$profiles[$row['id']]['router'] = $fixeddata[$row['id']]['router'];
			$profiles[$row['id']]['dns'] = implode(',', $fixeddata[$row['id']]['dns']);
		}
		else {
			$profiles[$row['id']]['netmask'] = '';
			$profiles[$row['id']]['router'] = '';
			$profiles[$row['id']]['dns'] = '';
		}
	}
	$_SESSION['usersessiondata'][$key] = $profiles;
	return $profiles;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getServerProfileImages($userid)
///
/// \param $userid - id from user table
///
/// \return array where the key is the id of the image and the value is the
/// prettyname of the image
///
/// \brief builds an array of images that user has access to via server profiles
///
////////////////////////////////////////////////////////////////////////////////
function getServerProfileImages($userid) {
	$key = getKey(array('getServerProfileImages', $userid));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	$resources = getUserResources(array('serverCheckOut', 'serverProfileAdmin'),
	                              array('available', 'administer'));
	$ids = array_keys($resources['serverprofile']);
	$inids = implode(',', $ids);
	if(empty($inids)) {
		$_SESSION['usersessiondata'][$key] = array();
		return array();
	}
	$query = "SELECT i.id, "
	       .        "i.prettyname AS image "
	       . "FROM serverprofile s, "
	       .      "image i "
	       . "WHERE s.imageid = i.id AND "
	       .       "s.id IN ($inids)";
	$qh = doQuery($query, 101);
	$profiles = array();
	while($row = mysql_fetch_assoc($qh))
		$profiles[$row['id']] = $row['image'];
	$_SESSION['usersessiondata'][$key] = $profiles;
	return $profiles;
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
/// \fn getImageConnectMethods($imageid, $revisionid, $nostatic=0)
///
/// \param $imageid - id of an image
/// \param $revisionid - (optional, default=0) revision id of image
/// \param $nostatic - (optional, default=0) pass 1 to keep from using the
/// static variable defined in the function
///
/// \return an array of connect methods enabled for specified image where the
/// key is the id of the connect method and the value is the description
///
/// \brief builds an array of connect methods enabled for the image
///
////////////////////////////////////////////////////////////////////////////////
function getImageConnectMethods($imageid, $revisionid=0, $nostatic=0) {
	$key = getKey(array('getImageConnectMethods', (int)$imageid, (int)$revisionid));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	if($revisionid == 0)
		$revisionid = getProductionRevisionid($imageid, $nostatic);
	if($revisionid == '') {
		$_SESSION['usersessiondata'][$key] = array();
		return array();
	}

	static $allmethods = array();
	if($nostatic)
		$allmethods = array();
	if(empty($allmethods)) {
		$query = "SELECT DISTINCT c.id, "
		      .                  "c.description, "
		      .                  "cm.disabled, "
		      .                  "i.id AS imageid, "
		      .                  "cm.imagerevisionid AS cmimagerevisionid, "
		      .                  "ir.id AS imagerevisionid, "
		      .                  "ir.imagename "
		      . "FROM image i "
		      . "LEFT JOIN OS o ON (o.id = i.OSid) "
		      . "LEFT JOIN OStype ot ON (ot.name = o.type) "
		      . "LEFT JOIN imagerevision ir ON (ir.imageid = i.id) "
		      . "LEFT JOIN connectmethodmap cm ON (cm.OStypeid = ot.id OR "
		      .                                   "cm.OSid = o.id OR "
		      .                                   "cm.imagerevisionid = ir.id) "
		      . "LEFT JOIN connectmethod c ON (cm.connectmethodid = c.id) "
		      . "WHERE cm.autoprovisioned IS NULL  "
		      . "ORDER BY i.id, "
		      .          "cm.disabled, "
		      .          "c.description";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh)) {
			$_imageid = $row['imageid'];
			$_revid = $row['imagerevisionid'];
			unset($row['imageid']);
			unset($row['imagerevisionid']);
			if(! array_key_exists($_imageid, $allmethods))
				$allmethods[$_imageid] = array();
			if(! array_key_exists($_revid, $allmethods[$_imageid]))
				$allmethods[$_imageid][$_revid] = array();
			$allmethods[$_imageid][$_revid][] = $row;
		}
	}
	if(! array_key_exists($imageid, $allmethods) ||
	   ! array_key_exists($revisionid, $allmethods[$imageid])) {
		$_SESSION['usersessiondata'][$key] = array();
		return array();
	}
	$methods = array();
	foreach($allmethods[$imageid][$revisionid] as $data) {
		if($data['disabled']) {
		  if(array_key_exists($data['id'], $methods))
			unset($methods[$data['id']]);
		}
		else
			$methods[$data['id']] = $data['description'];
	}

	$_SESSION['usersessiondata'][$key] = $methods;
	return $methods;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImageConnectMethodTexts($imageid, $revisionid)
///
/// \param $imageid - id of an image
/// \param $revisionid - (optional, default=0) revision id of image
///
/// \return an array of connect method texts enabled for specified image where
/// the key is the id of the connect method and the value is the connecttext
///
/// \brief builds an array of connect methods enabled for the image
///
////////////////////////////////////////////////////////////////////////////////
function getImageConnectMethodTexts($imageid, $revisionid=0) {
	global $locale;
	$descfield = 'description';
	$textfield = 'connecttext';
	if(! preg_match('/^en/', $locale)) {
		$query = "DESC connectmethod";
		$qh = doQuery($query, 101);
		while($row = mysql_fetch_assoc($qh)) {
			if($row['Field'] == "description_$locale")
				$descfield = "description_$locale";
			if($row['Field'] == "connecttext_$locale")
				$textfield = "connecttext_$locale";
		}
	}
	$cmports = array();
	$query = "SELECT id, "
	       .        "connectmethodid, "
	       .        "port, "
	       .        "protocol "
	       . "FROM connectmethodport";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		$row['key'] = "#Port-{$row['protocol']}-{$row['port']}#";
		$cmports[$row['connectmethodid']][] = $row;
	}
	if($revisionid == 0)
		$revisionid = getProductionRevisionid($imageid);
	$query = "SELECT c.id, "
	       .        "c.`$descfield` AS description, "
	       .        "c.`$textfield` AS connecttext, "
	       .        "cm.disabled "
	       . "FROM connectmethod c, "
	       .      "connectmethodmap cm, "
	       .      "image i "
	       . "LEFT JOIN OS o ON (o.id = i.OSid) "
	       . "LEFT JOIN OStype ot ON (ot.name = o.type) "
	       . "WHERE i.id = $imageid AND "
	       .       "cm.connectmethodid = c.id AND "
	       .       "cm.autoprovisioned IS NULL AND "
	       .       "(cm.OStypeid = ot.id OR "
	       .        "cm.OSid = o.id OR "
	       .        "cm.imagerevisionid = $revisionid) "
	       . "ORDER BY cm.disabled, "
	       .          "c.`$descfield`";
	$methods = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		if($row['disabled']) {
		  if(array_key_exists($row['id'], $methods))
			unset($methods[$row['id']]);
		}
		else
			$methods[$row['id']] = array('description' => $row['description'],
			                             'connecttext' => $row['connecttext'],
			                             'ports' => $cmports[$row['id']]);
	}
	return $methods;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImageTypes()
///
/// \return array of image types where each key is the id and each value is the
/// name
///
/// \brief builds an array of image types from the imagetype table
///
////////////////////////////////////////////////////////////////////////////////
function getImageTypes() {
	$query = "SELECT id, name FROM imagetype ORDER BY name";
	$qh = doQuery($query);
	$data = array();
	while($row = mysql_fetch_assoc($qh))
		$data[$row['id']] = $row['name'];
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkClearImageMeta($imagemetaid, $imageid, $ignorefield)
///
/// \param $imagemetaid - id from imagemeta table
/// \param $imageid - id from image table
/// \param $ignorefield - (optional, default='') field to ignore being different
/// from default
///
/// \return 0 if imagemeta entry was not deleted, 1 if it was
///
/// \brief checks to see if all values of the imagemeta table are defaults, and
/// if so, deletes the entry and sets imagemetaid to NULL in image table
///
////////////////////////////////////////////////////////////////////////////////
function checkClearImageMeta($imagemetaid, $imageid, $ignorefield='') {
	# get defaults for imagemeta table
	$query = "DESC imagemeta";
	$qh = doQuery($query, 101);
	$defaults = array();
	while($row = mysql_fetch_assoc($qh))
		$defaults[$row['Field']] = $row['Default'];
	# get imagemeta data
	$query = "SELECT * FROM imagemeta WHERE id = $imagemetaid";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	$alldefaults = 1;
	if(mysql_num_rows($qh) == 0)
		# it is possible that the imagemeta record could have been deleted before
		#   this was submitted
		return 1;
	foreach($row as $field => $val) {
		if($field == 'id' || $field == $ignorefield)
			continue;
		if($defaults[$field] != $val) {
			$alldefaults = 0;
			break;
		}
	}
	// if all default values, delete imagemeta entry
	if($alldefaults) {
		$query = "DELETE FROM imagemeta WHERE id = $imagemetaid";
		doQuery($query, 101);
		$query = "UPDATE image SET imagemetaid = NULL WHERE id = $imageid";
		doQuery($query, 101);
		return 1;
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getProductionRevisionid($imageid, $nostatic=0)
///
/// \param $imageid
/// \param $nostatic - (optional, default=0) pass 1 to keep from using the
/// static variable defined in the function
///
/// \return the production revision id for $imageid
///
/// \brief gets the production revision id for $imageid from the imagerevision
/// table
///
////////////////////////////////////////////////////////////////////////////////
function getProductionRevisionid($imageid, $nostatic=0) {
	static $alldata = array();
	if($nostatic)
		$alldata = array();
	if(! empty($alldata))
		if(array_key_exists($imageid, $alldata))
			return $alldata[$imageid];
		else
			return '';
	$query = "SELECT id, "
	       .        "imageid "
	       . "FROM imagerevision  " 
	       . "WHERE production = 1";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$alldata[$row['imageid']] = $row['id'];
	return $alldata[$imageid];
}

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
/// \fn getUserResources($userprivs, $resourceprivs, $onlygroups,
///                               $includedeleted, $userid, $groupid)
///
/// \param $userprivs - array of privileges to look for (such as
/// imageAdmin, imageCheckOut, etc) - this is an OR list; don't include 'block'
/// or 'cascade'
/// \param $resourceprivs - array of privileges to look for (such as
/// available, administer, manageGroup) - this is an OR list; don't include
/// 'block' or 'cascade'
/// \param $onlygroups - (optional) if 1, return the resource groups instead
/// of the resources
/// \param $includedeleted - (optional) included deleted resources if 1,
/// don't if 0
/// \param $userid - (optional) id from the user table, if not given, use the
/// id of the currently logged in user
/// \param $groupid - (optional) id from the usergroup table, if not given, look
/// up by $userid; $userid must be 0 to look up by $groupid
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
                          $onlygroups=0, $includedeleted=0, $userid=0,
                          $groupid=0) {
	global $user;
	if(in_array('managementnodeAdmin', $userprivs))
		$userprivs[] = 'mgmtnodeAdmin';
	$key = getKey(array($userprivs, $resourceprivs, $onlygroups, $includedeleted, $userid, $groupid));
	if(array_key_exists($key, $_SESSION['userresources']))
		return $_SESSION['userresources'][$key];
	#FIXME this whole function could be much more efficient
	$bygroup = 0;
	if($userid == 0 && $groupid != 0)
		$bygroup = 1;
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
	       .       "t.name IN ($inlist) AND ";
	if(! $bygroup) {
		$query .=   "(u.userid = $userid OR "
		       .    "u.usergroupid IN (SELECT usergroupid "
		       .                      "FROM usergroupmembers "
		       .                      "WHERE userid = $userid))";
	}
	else
		$query .=   "u.usergroupid = $groupid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		array_push($startnodes, $row["privnodeid"]);
	}
	# build data array from userprivtype and userpriv tables to reduce queries
	# in addNodeUserResourcePrivs
	$privdataset = array('user' => array(), 'usergroup' => array());
	$query = "SELECT t.name, "
	       .        "u.privnodeid "
	       . "FROM userprivtype t, "
	       .      "userpriv u "
	       . "WHERE u.userprivtypeid = t.id AND "
	       .       "u.userid IS NOT NULL AND "
	       .       "u.userid = $userid AND "
	       .       "t.name IN ('block','cascade',$inlist)";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		if(! array_key_exists($row['privnodeid'], $privdataset['user']))
			$privdataset['user'][$row['privnodeid']] = array();
		$privdataset['user'][$row['privnodeid']][] = $row['name'];
	}
	$query = "SELECT t.name, "
	       .        "u.usergroupid, "
	       .        "u.privnodeid "
	       . "FROM userprivtype t, "
	       .      "userpriv u "
	       . "WHERE u.userprivtypeid = t.id AND "
			 .       "u.usergroupid IS NOT NULL AND ";
	if($bygroup)
		$query .=   "u.usergroupid = $groupid AND ";
	else
		$query .=   "u.usergroupid IN (SELECT usergroupid "
		       .                      "FROM usergroupmembers "
				 .                      "WHERE userid = $userid) AND ";
	$query .=      "t.name IN ('block','cascade',$inlist) "
	       . "ORDER BY u.privnodeid, "
	       .          "u.usergroupid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		if(! array_key_exists($row['privnodeid'], $privdataset['usergroup']))
			$privdataset['usergroup'][$row['privnodeid']] = array();
		$privdataset['usergroup'][$row['privnodeid']][] = array('name' => $row['name'], 'groupid' => $row['usergroupid']);
	}

	# travel up tree looking at privileges granted at parent nodes
	foreach($startnodes as $nodeid) {
		getUserResourcesUp($nodeprivs, $nodeid, $userid, $userprivs, $privdataset);
	}
	# travel down tree looking at privileges granted at child nodes if cascade privs at this node
	foreach($startnodes as $nodeid) {
		getUserResourcesDown($nodeprivs, $nodeid, $userid, $userprivs, $privdataset);
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
					list($type, $name, $id) = explode('/', $resourceid);
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
					list($type, $name, $id) = explode('/', $resourceid);
					if(! array_key_exists($type, $resourcegroups))
						$resourcegroups[$type] = array();
					if(! in_array($name, $resourcegroups[$type]))
						$resourcegroups[$type][$id] = $name;
				}
			}
		}
	}

	if(! $bygroup)
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
	if(! $bygroup)
		addOwnedResources($resources, $includedeleted, $userid);
	$noimageid = getImageId('noimage');
	if(array_key_exists($noimageid, $resources['image']))
		unset($resources['image'][$noimageid]);
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
                            $resourceprivs, $privdataset) {
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

		addNodeUserResourcePrivs($nodeprivs, $id, $lastid, $userid, $resourceprivs, $privdataset);
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
                              $resourceprivs, $privdataset) {
	# FIXME can we check for cascading and if not there, don't descend?
	$children = getChildNodes($nodeid);
	foreach(array_keys($children) as $id) {
		addNodeUserResourcePrivs($nodeprivs, $id, $nodeid, $userid, $resourceprivs, $privdataset);
		getUserResourcesDown($nodeprivs, $id, $userid, $resourceprivs, $privdataset);
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
                                  $resourceprivs, $privdataset) {
	$nodeprivs[$id]["user"] = array("cascade" => 0);
	foreach($resourceprivs as $priv) {
		$nodeprivs[$id]["user"][$priv] = 0;
	}

	# add permissions for user
	$block = 0;
	if(array_key_exists($id, $privdataset['user'])) {
		foreach($privdataset['user'][$id] as $name) {
			if($name != 'block')
				$nodeprivs[$id]['user'][$name] = 1;
			else
				$block = 1;
		}
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
	$basearray = array("cascade" => 0,
	                   "block" => 0);
	foreach($resourceprivs as $priv)
		$basearray[$priv] = 0;
	if(array_key_exists($id, $privdataset['usergroup'])) {
		foreach($privdataset['usergroup'][$id] as $data) {
			if(! array_key_exists($data["groupid"], $nodeprivs[$id]))
				$nodeprivs[$id][$data["groupid"]] = $basearray;
			$nodeprivs[$id][$data["groupid"]][$data["name"]] = 1;
		}
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
		# TODO make this get name field from classes
		switch($type) {
			case "image":
				$field = 'prettyname';
				break;
			case "computer":
			case "managementnode":
				$field = 'hostname';
				break;
			default:
				$field = 'name';
				break;
		}
		$query = "SELECT id, "
		       .        "$field "
		       . "FROM $type "
		       . "WHERE ownerid = $userid";
		if(! $includedeleted &&
		   ($type == "image" || $type == "computer" || $type == 'config'))
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
	if(! $user = getUserInfo($userid, 1, 1))
		return;
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
	switch($type) {
		case "image":
			$field = 'prettyname';
			break;
		case "computer":
		case "managementnode":
			$field = 'hostname';
			break;
		default:
			$field = 'name';
			break;
	}

	$groups = implode("','", $groups);
	$inlist = "'$groups'";

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
	if(! $includedeleted &&
	   ($type == "image" || $type == "computer" || $type == 'config')) {
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
/// \param $name - loginid, user id, or user group id
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
		$id = $name;
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
		$type = mysql_real_escape_string($type);
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
		$type = mysql_real_escape_string($type);
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
	return md5(serialize($data));
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
	global $cryptkey;
	if(! $data)
		return false;
	$aes = new Crypt_AES();
	$aes->setKey($cryptkey);
	$cryptdata = $aes->encrypt($data);
	return trim(base64_encode($cryptdata));
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
	global $cryptkey;
	if(! $data)
		return false;
	$aes = new Crypt_AES();
	$aes->setKey($cryptkey);
	$cryptdata = base64_decode($data);
	$decryptdata = $aes->decrypt($cryptdata);
	return trim($decryptdata);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn encryptDataAsymmetric($data, $public_key)
///
/// \param $data - a string
///
/// \param $public_key - either a filename for a public key or the public key
/// itself
///
/// \return hex-encoded, encrypted form of $data
///
/// \brief generate public key encrypted data
///
////////////////////////////////////////////////////////////////////////////////
function encryptDataAsymmetric($data, $public_key){
	if(file_exists($public_key)){
		$key = openssl_pkey_get_public(file_get_contents($public_key));
	} else {
		$key = openssl_pkey_get_public($public_key);
	}    

	openssl_public_encrypt($data, $encrypted, $key, OPENSSL_PKCS1_OAEP_PADDING);
	openssl_free_key($key);

	$hexformatted = unpack("H*hex", $encrypted);
	return $hexformatted['hex'];
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
	global $cache;
	if(! array_key_exists('nodes', $cache))
		# call getNodeInfo to populate $cache['nodes']
		getNodeInfo($parent);

	static $allnodes = array();
	if(empty($allnodes)) {
		foreach($cache['nodes'] as $id => $node) {
			unset($node['id']);
			if(! array_key_exists($node['parent'], $allnodes))
				$allnodes[$node['parent']] = array();
			$allnodes[$node['parent']][$id] = $node;
		}
	}
	if(array_key_exists($parent, $allnodes))
		return $allnodes[$parent];
	else
		return array();
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
/// groupaffiliation\n
/// groupaffiliationid\n
/// ownerid\n
/// owner\n
/// affiliation\n
/// editgroupid\n
/// editgroup\n
/// editgroupaffiliationid\n
/// editgroupaffiliation\n
/// custom\n
/// courseroll\n
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
	$key = getKey(array($groupType, $affiliationid, $user['showallgroups']));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
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
	$_SESSION['usersessiondata'][$key] = $return;
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
		       .       "(u.ownerid = $id OR m.userid = $id) "
		       . "ORDER BY name";
	}
	else {
		$query = "SELECT DISTINCT(u.id), "
		       .        "u.name "
		       . "FROM `usergroup` u, "
		       .      "`usergroupmembers` m "
		       . "WHERE u.editusergroupid = m.usergroupid AND "
		       .       "(u.ownerid = $id OR m.userid = $id) AND " 
		       .       "u.affiliationid = {$user['affiliationid']} "
		       . "ORDER BY name";
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
/// \fn getUserGroupPrivs($groupid='')
///
/// \param $groupid (optional, default='') - if specified, only get permissions
///        granted to this user group; if not specified, get information about
///        all groups
///
/// \return array of data about user group permissions where each element is an
/// array with these keys:\n
/// \b usergroup - name of user group\n
/// \b usergroupid - id of user group\n
/// \b permission - permission granted to user group\n
/// \b permid - id of permission granted to user group
///
/// \brief builds an array of data about permissions granted to user groups
///
////////////////////////////////////////////////////////////////////////////////
function getUserGroupPrivs($groupid='') {
	$data = array();
	$query = "SELECT ug.name AS usergroup, "
	       .        "ugp.usergroupid, "
	       .        "ugpt.name AS permission, "
	       .        "ugp.userprivtypeid AS permid "
	       . "FROM usergroup ug, "
	       .      "usergrouppriv ugp, "
	       .      "usergroupprivtype ugpt "
	       . "WHERE ugp.usergroupid = ug.id AND "
	       .       "ugp.userprivtypeid = ugpt.id ";
	if(! empty($groupid))
		$query .= "AND ugp.usergroupid = $groupid ";
	$query .= "ORDER BY ug.name, "
	       .           "ugpt.name";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$data[] = $row;
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserGroupPrivTypes()
///
/// \return array of information about user group permissions where each index
/// is the id of the permission and each element has these keys:\n
/// \b id - id of permission\n
/// \b name - name of permission\n
/// \b help - additional information about permission
///
/// \brief builds an array of information about the user group permissions
///
////////////////////////////////////////////////////////////////////////////////
function getUserGroupPrivTypes() {
	$data = array();
	$query = "SELECT id, name, help FROM usergroupprivtype ORDER BY name";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$data[$row['id']] = $row;
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourceGroups($type, $id)
///
/// \param $type - (optional) a name from the resourcetype table, defaults to
/// be empty
/// \param $id - (optional) id of a resource group
///
/// \return an array of resource groups where each key is a group id and each
/// value is an array with these elements:\n
/// \b name - type and name of group combined as type/name\n
/// \b ownerid - id of owning user group\n
/// \b owner - name of owning user group
///
/// \brief builds list of resource groups
///
////////////////////////////////////////////////////////////////////////////////
function getResourceGroups($type='', $id='') {
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

	if(! empty($id))
		$query .= "AND g.id = $id ";

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
/// \fn addUserGroupMember($loginid, $groupid)
///
/// \param $loginid - a user's loginid
/// \param $groupid - a usergroup id
///
/// \brief adds an entry to usergroupmembers for $unityid and $groupid
///
////////////////////////////////////////////////////////////////////////////////
function addUserGroupMember($loginid, $groupid) {
	$userid = getUserlistID($loginid);
	$groups = getUsersGroups($userid);

	if(in_array($groupid, array_keys($groups)))
		return;

	$query = "INSERT INTO usergroupmembers "
	       .        "(userid, " 
	       .        "usergroupid) "
	       . "VALUES "
	       .        "($userid, "
	       .        "$groupid)";
	doQuery($query, 101);
	checkUpdateServerRequestGroups($groupid);
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
	checkUpdateServerRequestGroups($groupid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserlistID($loginid, $noadd)
///
/// \param $loginid - login ID
/// \param $noadd - (optional, default=0) 0 to try to add user to database if
/// not there, 1 to only return the id if it already exists in the database
///
/// \return id from userlist table for the user
///
/// \brief gets id field from userlist table for $loginid; if it does not exist,
/// calls addUser to add it to the table
///
////////////////////////////////////////////////////////////////////////////////
function getUserlistID($loginid, $noadd=0) {
	$_loginid = $loginid;
	getAffilidAndLogin($loginid, $affilid);

	if(empty($affilid))
		abort(12);

	$query = "SELECT id "
	       . "FROM user "
	       . "WHERE unityid = '$loginid' AND "
	       .       "affiliationid = $affilid";
	$qh = doQuery($query, 140);
	if(mysql_num_rows($qh)) {
		$row = mysql_fetch_row($qh);
		return $row[0];
	}
	if($noadd)
		return NULL;
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
	       . "ORDER BY id DESC "
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
	if(! array_key_exists('unityids', $cache))
		$cache['unityids'] = array();
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
	$affil = mysql_real_escape_string($affil);
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
/// \fn getAffiliationTheme($affilid)
///
/// \param $affilid - id of an affiliation
///
/// \return name of the affiliations's theme
///
/// \brief gets affiliation.theme for the specified affiliation
///
////////////////////////////////////////////////////////////////////////////////
function getAffiliationTheme($affilid) {
	$query = "SELECT theme FROM affiliation WHERE id = $affilid";
	$qh = doQuery($query);
	if(($row = mysql_fetch_assoc($qh)) && ! empty($row['theme']))
		return $row['theme'];
	else
		return 'default';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processInputVar($vartag, $type, $defaultvalue, $stripwhitespace)
///
/// \param $vartag - name of GET or POST variable
/// \param $type - tag type:\n
/// \b ARG_NUMERIC - numeric\n
/// \b ARG_STRING - string\n
/// \b ARG_MULTINUMERIC - an array of numbers
/// \param $defaultvalue - default value for the variable (NULL if not passed in)
/// \param $stripwhitespace - (optional, default=0) - set to 1 to strip
/// whitespace from the beginning and end of the value
///
/// \return safe value for the GET or POST variable
///
/// \brief checks for $vartag in the $_POST array, then the $_GET array; then
/// sanitizes the variable to make sure it doesn't contain anything malicious
///
////////////////////////////////////////////////////////////////////////////////
function processInputVar($vartag, $type, $defaultvalue=NULL, $stripwhitespace=0) {
	if((array_key_exists($vartag, $_POST) &&
	   ! is_array($_POST[$vartag]) &&
	   strncmp("{$_POST[$vartag]}", "0", 1) == 0 &&
	   $type == ARG_NUMERIC &&
		strncmp("{$_POST[$vartag]}", "0x0", 3) != 0) ||
	   (array_key_exists($vartag, $_GET) && 
	   ! is_array($_GET[$vartag]) &&
	   strncmp("{$_GET[$vartag]}", "0", 1) == 0 &&
	   $type == ARG_NUMERIC &&
		strncmp("{$_GET[$vartag]}", "0x0", 3) != 0)) {
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
			if($stripwhitespace)
				$return[$index] = trim($return[$index]);
			if($return[$index] == 'zero')
				$return[$index] = '0';
		}
	}
	elseif($type == ARG_MULTISTRING) {
		foreach($return as $index => $value) {
			$return[$index] = strip_tags($value);
			if($stripwhitespace)
				$return[$index] = trim($return[$index]);
		}
	}
	else {
		$return = strip_tags($return);
		if($stripwhitespace)
			$return = trim($return);
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
			cleanSemaphore();
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
				cleanSemaphore();
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
		if(! is_object($contdata[$name]) && $contdata[$name] == 'zero')
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
				$return[$index] = mysql_real_escape_string($value);
		}
		return $return;
	}

	if(is_string($return)) {
		if(strlen($return) == 0)
			$return = $defaultvalue;
		elseif($addslashes)
			$return = mysql_real_escape_string($return);
	}

	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserInfo($id, $noupdate, $numeric)
///
/// \param $id - unity ID for the user or user's id from database
/// \param $noupdate - (optional, default=0) specify 1 to skip updating user's
/// data if lastupdated timestamp is expired
/// \param $numeric - (optional, default=0) 1 specifies $id corresponds to the
/// id field from the user table; 0 otherwise
///
/// \return 0 if fail to fetch data or $user - an array with these elements:\n
/// \b unityid - unity ID for the user\n
/// \b affiliationid - affiliation id of user\n
/// \b affiliation - affiliation of user\n
/// \b login - login ID for the user (unity ID or part before \@sign)\n
/// \b firstname - user's first name\n
/// \b lastname - user's last name\n
/// \b preferredname - user's preferred name\n
/// \b email - user's preferred email address\n
/// \b emailnotices - bool for sending email notices to user\n
/// \b IMtype - user's preferred IM protocol\n
/// \b IMid - user's IM id\n
/// \b id - user's id from database\n
/// \b width - pixel width for rdp files\n
/// \b height - pixel height for rdp files\n
/// \b bpp - color depth for rdp files\n
/// \b audiomode - 'none' or 'local' - audio mode for rdp files\n
/// \b mapdrives - 0 or 1 - map drives for rdp files; 1 means to map\n
/// \b mapprinters - 0 or 1 - map printers for rdp files; 1 means to map\n
/// \b mapserial - 0 or 1 - map serial ports for rdp files; 1 means to map\n
/// \b rdpport - preferred port for RDP\n
/// \b showallgroups - 0 or 1 - show only user groups matching user's
/// affiliation or show all user groups\n
/// \b lastupdated - datetime the information was last updated\n
/// \b groups - array of groups user is a member of where the index is the id
/// of the group and the value is the name of the group\n
/// \b privileges - array of privileges that the user has
///
/// \brief gets the user's information from the db and puts it into an array;
/// if the user is not in the db, query ldap and add them; if the user changed
/// their name and unity id; fix information in db based on numeric unity id;
/// returns NULL if could not get information about the user
///
////////////////////////////////////////////////////////////////////////////////
function getUserInfo($id, $noupdate=0, $numeric=0) {
	$affilid = DEFAULT_AFFILID;
	if(! $numeric) {
		$rc = getAffilidAndLogin($id, $affilid);
		if($rc == -1)
			return NULL;
	}

	$user = array();
	$query = "SELECT u.unityid AS unityid, "
	       .        "u.affiliationid, "
	       .        "af.name AS affiliation, "
	       .        "u.firstname AS firstname, "
	       .        "u.lastname AS lastname, "
	       .        "u.preferredname AS preferredname, "
	       .        "u.email AS email, "
	       .        "u.emailnotices, "
	       .        "i.name AS IMtype, "
	       .        "u.IMid AS IMid, "
	       .        "u.id AS id, "
	       .        "u.width AS width, "
	       .        "u.height AS height, "
	       .        "u.bpp AS bpp, "
	       .        "u.audiomode AS audiomode, "
	       .        "u.mapdrives AS mapdrives, "
	       .        "u.mapprinters AS mapprinters, "
	       .        "u.mapserial AS mapserial, "
	       .        "COALESCE(u.rdpport, 3389) AS rdpport, "
	       .        "u.showallgroups, "
	       .        "u.lastupdated AS lastupdated, "
	       .        "u.usepublickeys, "
	       .        "u.sshpublickeys, "
	       .        "af.shibonly "
	       . "FROM user u, "
	       .      "IMtype i, "
	       .      "affiliation af "
	       . "WHERE u.IMtypeid = i.id AND "
	       .       "u.affiliationid = af.id AND ";
	if($numeric)
		$query .= "u.id = $id";
	else
		$query .= "u.unityid = '$id' AND af.id = $affilid";

	$qh = doQuery($query, "105");
	if($user = mysql_fetch_assoc($qh)) {
		$user['sshpublickeys'] = htmlspecialchars($user['sshpublickeys']);
		if((datetimeToUnix($user["lastupdated"]) > time() - SECINDAY) ||
		   $user['unityid'] == 'vclreload' ||
		   $user['affiliation'] == 'Local' ||
		   $user['shibonly'] ||
		   $noupdate) {
			# get user's groups
			$user["groups"] = getUsersGroups($user["id"], 1);
			$user["groupperms"] = getUsersGroupPerms(array_keys($user['groups']));

			checkExpiredDemoUser($user['id'], $user['groups']);

			# get user's privileges
			$user["privileges"] = getOverallUserPrivs($user["id"]);

			if(preg_match('/@/', $user['unityid'])) {
				$tmparr = explode('@', $user['unityid']);
				$user['login'] = $tmparr[0];
			}
			else
				$user['login'] = $user['unityid'];

			$blockids = getBlockAllocationIDs($user);
			$user['memberCurrentBlock'] = count($blockids);
			return $user;
		}
	}
	if($numeric)
		$user = updateUserData($id, "numeric");
	else
		$user = updateUserData($id, "loginid", $affilid);
	if(! is_null($user)) {
		$blockids = getBlockAllocationIDs($user);
		$user['memberCurrentBlock'] = count($blockids);
	}
	return $user;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUsersGroups($userid, $includeowned, $includeaffil)
///
/// \param $userid - an id from the user table
/// \param $includeowned - (optional, default=0) include groups the user owns
///                        but is not in
/// \param $includeaffil - (optional, default=0) include @affiliation in name
///                        of group
///
/// \return an array of the user's groups where the index is the id of the
/// group
///
/// \brief builds a array of the groups the user is member of
///
////////////////////////////////////////////////////////////////////////////////
function getUsersGroups($userid, $includeowned=0, $includeaffil=0) {
	if($includeaffil) {
		$query = "SELECT m.usergroupid, "
		       .        "CONCAT(g.name, '@', a.name) AS name "
		       . "FROM usergroupmembers m, "
		       .      "usergroup g, "
		       .      "affiliation a "
		       . "WHERE m.userid = $userid AND "
		       .       "m.usergroupid = g.id AND "
		       .       "g.affiliationid = a.id";
	}
	else {
		$query = "SELECT m.usergroupid, "
		       .        "g.name "
		       . "FROM usergroupmembers m, "
		       .      "usergroup g "
		       . "WHERE m.userid = $userid AND "
		       .       "m.usergroupid = g.id";
	}
	$qh = doQuery($query, "101");
	$groups = array();
	while($row = mysql_fetch_assoc($qh)) {
		$groups[$row["usergroupid"]] = $row["name"];
	}
	if($includeowned) {
		if($includeaffil) {
			$query = "SELECT g.id AS usergroupid, "
			       .        "CONCAT(g.name, '@', a.name) AS name "
			       . "FROM usergroup g, "
			       .      "affiliation a "
			       . "WHERE g.ownerid = $userid AND "
			       .       "g.affiliationid = a.id";
		}
		else {
			$query = "SELECT id AS usergroupid, "
			       .        "name "
			       . "FROM usergroup "
			       . "WHERE ownerid = $userid";
		}
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
/// \fn getUsersGroupPerms($usergroupids)
///
/// \param $usergroupids - array of user group ids
///
/// \return array of permissions where each index is the permission id and each
/// element is the name of the permission
///
/// \brief builds an array of all permissions granted to a user via that user's
/// user groups
///
////////////////////////////////////////////////////////////////////////////////
function getUsersGroupPerms($usergroupids) {
	if(empty($usergroupids))
		return array();
	$inlist = implode(',', $usergroupids);
	if($inlist == '')
		return array();
	$query = "SELECT DISTINCT t.id, "
	       .        "t.name "
	       . "FROM usergroupprivtype t, "
	       .      "usergrouppriv u "
	       . "WHERE u.usergroupid IN ($inlist) AND "
	       .       "u.userprivtypeid = t.id "
	       . "ORDER BY t.name";
	$perms = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$perms[$row['id']] = $row['name'];
	return $perms;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkUserHasPerm($perm, $userid=0)
///
/// \param $perm - name of a user group permission
/// \param $userid (optional, default=0) - if specified, check for $userid
/// having $perm; otherwise, check logged in user
///
/// \return 1 if user has $perm, 0 otherwise
///
/// \brief checks to see if a user has been granted a permission through that
/// user's group memberships
///
////////////////////////////////////////////////////////////////////////////////
function checkUserHasPerm($perm, $userid=0) {
	global $user;
	if($userid == 0) {
		if(is_array($user) && array_key_exists('groupperms', $user))
			$perms = $user['groupperms'];
		else
			return 0;
	}
	else {
		$usersgroups = getUsersGroups($userid, 1);
		$perms = getUsersGroupPerms(array_keys($usersgroups));
	}
	if(is_array($perms) && in_array($perm, $perms))
		return 1;
	return 0;
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
/// \b firstname - user's first name\n
/// \b lastname - user's last name\n
/// \b email - user's preferred email address\n
/// \b IMtype - user's preferred IM protocol\n
/// \b IMid - user's IM id\n
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
/// \return id from user table for the user, NULL if userid not in table
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
/// \fn updateUserPrefs($userid, $preferredname, $width, $height, $bpp, $audio,
///                     $mapdrives, $mapprinters, $mapserial, $rdpport)
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
/// \param $rdpport - port for RDP to listen on
///
/// \return number of rows affected by update (\b NOTE: this may be 0 if none
/// of the values were actually changes
///
/// \brief updates the preferences for the user
///
////////////////////////////////////////////////////////////////////////////////
function updateUserPrefs($userid, $preferredname, $width, $height, $bpp, $audio,
                         $mapdrives, $mapprinters, $mapserial, $rdpport) {
	global $mysql_link_vcl;
	$preferredname = mysql_real_escape_string($preferredname);
	$audio = mysql_real_escape_string($audio);
	if($rdpport == 3389)
		$rdpport = 'NULL';
	$query = "UPDATE user SET "
	       .        "preferredname = '$preferredname', "
	       .        "width = '$width', "
	       .        "height = '$height', "
	       .        "bpp = $bpp, "
	       .        "audiomode = '$audio', "
	       .        "mapdrives = $mapdrives, "
	       .        "mapprinters = $mapprinters, "
	       .        "mapserial = $mapserial, "
	       .        "rdpport = $rdpport "
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
	while($row = mysql_fetch_row($qh))
		$privileges[] = $row[0];
	if(in_array("mgmtNodeAdmin", $privileges))
		$privileges[] = 'managementnodeAdmin';
	return $privileges;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getBlockAllocationIDs($user)
///
/// \param $user - array of user data
///
/// \return array of block allocation ids that are currently active for $user
///
/// \brief checks to see if $user is a member of an active block allocation
/// (active also includes allocations starting within 15 minutes)
///
////////////////////////////////////////////////////////////////////////////////
function getBlockAllocationIDs($user) {
	$groupids = array_keys($user['groups']);
	if(empty($groupids))
		return array();
	$inids = implode(',', $groupids);
	$query = "SELECT r.id "
	       . "FROM blockRequest r, "
	       .      "blockTimes t "
	       . "WHERE t.blockRequestid = r.id AND "
	       .       "r.status = 'accepted' AND "
	       .       "t.start <= DATE_ADD(NOW(), INTERVAL 15 MINUTE) AND "
	       .       "t.end > NOW() AND "
	       .       "t.skip = 0 AND "
	       .       "r.groupid IN ($inids)";
	$ids = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$ids[] = $row['id'];
	return $ids;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn isAvailable($images, $imageid, $imagerevisionid, $start, $end,
///                 $holdcomps, $requestid, $userid, $ignoreprivileges,
///                 $forimaging, $ip, $mac, $skipconcurrentcheck)
///
/// \param $images - array as returned from getImages
/// \param $imageid - imageid from the image table
/// \param $imagerevisionid - id of revision of image from imagerevision table
/// \param $start - unix timestamp for start of reservation
/// \param $end - unix timestamp for end of reservation
/// \param $holdcomps - bool - 1 to lock computers for later adding to
/// reservation, 0 not to; use 0 when just checking for estimated availability,
/// use 1 when finding computers to actually reserve
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
/// \param $ip - (optional, default='') ip address to be assigned; assumed to
/// be a server profile reservation if defined
/// \param $mac - (optional, default='') mac address to be assigned; assumed to
/// be a server profile reservation if defined
/// \param $skipconcurrentcheck (optional, default=0) - set to 1 to skip check
/// for concurrent use of image; useful for setting up reload reservations
///
/// \return -4 if unavailable due to an ip/mac conflict with another machine
///         -3 if unavailable due to an ip/mac conflict with another reservation
///         -2 if specified time period is during a maintenance window
///         -1 if $imageid is limited in the number of concurrent reservations
///         available, and the limit has been reached
///         0 if combination is not available\n
///         an integer >0 if it is available
///
/// \brief checks that the passed in arguments constitute an available request
///
////////////////////////////////////////////////////////////////////////////////
function isAvailable($images, $imageid, $imagerevisionid, $start, $end,
                     $holdcomps, $requestid=0, $userid=0, $ignoreprivileges=0,
                     $forimaging=0, $ip='', $mac='', $skipconcurrentcheck=0) {
	global $requestInfo, $user;
	$requestInfo["start"] = $start;
	$requestInfo["end"] = $end;
	$requestInfo["imageid"] = $imageid;
	$requestInfo["ipwarning"] = 0;
	$allocatedcompids = array(0);

	if(! is_array($imagerevisionid))
		$imagerevisionid = array($imageid => array($imagerevisionid));
	elseif(empty($imagerevisionid))
		$imagerevisionid = array($imageid => array(getProductionRevisionid($imageid)));

	if(schCheckMaintenance($start, $end))
		return debugIsAvailable(-2, 1, $start, $end, $imagerevisionid);

	if(! array_key_exists($imageid, $images))
		return debugIsAvailable(0, 20, $start, $end, $imagerevisionid);

	if($requestInfo["start"] <= time()) {
		$now = 1;
		$nowfuture = 'now';
	}
	else {
		$now = 0;
		$nowfuture = 'future';
	}

	$scheduleids = getAvailableSchedules($start, $end);

	$requestInfo["computers"] = array();
	$requestInfo["computers"][0] = 0;
	$requestInfo["images"][0] = $imageid;
	$requestInfo["imagerevisions"][0] = $imagerevisionid[$imageid][0];

	# build array of subimages
	# TODO handle mininstance
	if(! $forimaging && $images[$imageid]["imagemetaid"] != NULL) {
		$count = 1;
		foreach($images[$imageid]["subimages"] as $imgid) {
			$requestInfo['computers'][$count] = 0;
			$requestInfo['images'][$count] = $imgid;
			if(array_key_exists($imgid, $imagerevisionid) &&
			   array_key_exists($count, $imagerevisionid[$imgid]))
				$requestInfo['imagerevisions'][$count] = $imagerevisionid[$imgid][$count];
			else
				$requestInfo['imagerevisions'][$count] = getProductionRevisionid($imgid);
			$count++;
		}
	}

	$startstamp = unixToDatetime($start);
	$endstamp = unixToDatetime($end + 900);

	if(! empty($mac) || ! empty($ip)) {
		# check for overlapping use of mac or ip
		$query = "SELECT rq.id "
		       . "FROM reservation rs, "
		       .      "request rq, "
		       .      "serverrequest sr "
		       . "WHERE '$startstamp' < (rq.end + INTERVAL 900 SECOND) AND "
		       .       "'$endstamp' > rq.start AND "
		       .       "sr.requestid = rq.id AND "
		       .       "rs.requestid = rq.id AND "
		       .       "(sr.fixedIP = '$ip' OR "
		       .       "sr.fixedMAC = '$mac') AND "
		       .       "rq.stateid NOT IN (1,5,11,12) ";
		if($requestid)
			$query .=   "AND rq.id != $requestid ";
		$query .= "LIMIT 1";
		$qh = doQuery($query, 101);
		if(mysql_num_rows($qh)) {
			return debugIsAvailable(-3, 2, $start, $end, $imagerevisionid);
		}

		# check for IP being used by a management node
		$query = "SELECT id "
		       . "FROM managementnode "
		       . "WHERE IPaddress = '$ip' AND "
		       .       "stateid != 1";
		$qh = doQuery($query, 101);
		if(mysql_num_rows($qh)) {
			return debugIsAvailable(-4, 16, $start, $end, $imagerevisionid);
		}
	}

	if($requestid)
		$requestData = getRequestInfo($requestid);

	$vmhostcheckdone = 0;
	$ignorestates = "'maintenance','vmhostinuse','hpc','failed'";
	if($now)
		$ignorestates .= ",'reloading','reload','timeout','inuse'";

	foreach($requestInfo["images"] as $key => $imageid) {
		# check for max concurrent usage of image
		if(! $skipconcurrentcheck && 
		   $images[$imageid]['maxconcurrent'] != NULL) {
			if($userid == 0)
				$usersgroups = $user['groups'];
			else {
				$testuser = getUserInfo($userid, 0, 1);
				if(is_null($testuser))
					return debugIsAvailable(0, 17, $start, $end, $imagerevisionid);
				$usersgroups = $testuser['groups'];
			}
			$decforedit = 0;
			$compids = array();
			$reloadid = getUserlistID('vclreload@Local');
			$query = "SELECT rs.computerid, "
			       .        "rq.id AS reqid "
			       . "FROM reservation rs, "
			       .      "request rq "
			       . "WHERE '$startstamp' < (rq.end + INTERVAL 900 SECOND) AND "
			       .       "'$endstamp' > rq.start AND "
			       .       "rs.requestid = rq.id AND "
			       .       "rs.imageid = $imageid AND "
			       .       "rq.stateid NOT IN (1,5,11,12,16,17) AND "
			       .       "rq.userid != $reloadid";
			$qh = doQuery($query, 101);
			while($row = mysql_fetch_assoc($qh)) {
				$compids[] = $row['computerid'];
				if($row['reqid'] == $requestid)
					$decforedit = 1;
			}
			$usagecnt = count($compids);
			$allids = implode("','", $compids);
			$ignoregroups = implode("','", array_keys($usersgroups));
			$query = "SELECT COUNT(bc.imageid) AS currentusage "
			       . "FROM blockComputers bc, "
			       .      "blockRequest br, "
			       .      "blockTimes bt "
			       . "WHERE bc.blockTimeid = bt.id AND "
			       .       "bt.blockRequestid = br.id AND "
			       .       "bc.imageid = $imageid AND "
			       .       "bc.computerid NOT IN ('$allids') AND "
			       .       "br.groupid NOT IN ('$ignoregroups') AND "
			       .       "'$startstamp' < (bt.end + INTERVAL 900 SECOND) AND "
			       .       "'$endstamp' > bt.start AND "
			       .       "bt.skip != 1 AND "
			       .       "br.status != 'deleted'";
			$qh = doQuery($query);
			if(! $row = mysql_fetch_assoc($qh)) {
				cleanSemaphore();
				return debugIsAvailable(0, 3, $start, $end, $imagerevisionid);
			}
			if(($usagecnt + $row['currentusage'] - $decforedit) >= $images[$imageid]['maxconcurrent']) {
				cleanSemaphore();
				return debugIsAvailable(-1, 4, $start, $end, $imagerevisionid);
			}
		}

		$platformid = getImagePlatform($imageid);
		if(is_null($platformid)) {
			cleanSemaphore();
			return debugIsAvailable(0, 5, $start, $end, $imagerevisionid);
		}

		# get computers $imageid maps to
		$compids = getMappedResources($imageid, "image", "computer");
		if(! count($compids)) {
			cleanSemaphore();
			return debugIsAvailable(0, 6, $start, $end, $imagerevisionid);
		}
		$mappedcomputers = implode(',', $compids);

		// if $ip specified, only look at computers under management nodes that can
		#   handle that network
		if($ip != '') {
			$mappedmns = getMnsFromImage($imageid);
			$mnnets = checkAvailableNetworks($ip);
			$intersect = array_intersect($mappedmns, $mnnets);
			$tmpcompids = array();
			foreach($intersect as $mnid) {
				$tmp2 = getMappedResources($mnid, 'managementnode', 'computer');
				$tmpcompids = array_merge($tmpcompids, $tmp2);
			}
			$tmpcompids = array_unique($tmpcompids);
			$newcompids = array_intersect($compids, $tmpcompids);
			if(! count($newcompids)) {
				cleanSemaphore();
				return debugIsAvailable(0, 18, $start, $end, $imagerevisionid);
			}
			$mappedcomputers = implode(',', $newcompids);
		}

		#get computers for available schedules and platforms
		$computerids = array();
		$currentids = array();
		$blockids = array();
		$altRemoveBlockCheck = 0;
		// if we are modifying a request and it is after the start time, only allow
		// the scheduled computer(s) to be modified
		if($requestid && datetimeToUnix($requestData["start"]) <= time()) {
			$altRemoveBlockCheck = 1;
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
				cleanSemaphore();
				return debugIsAvailable(0, 7, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids);
			}
			// set $virtual to 0 so that it is defined later but skips the additional code
			$virtual = 0;
		}
		// otherwise, build a list of computers
		else {
			# determine if image is bare metal or virtual
			$query = "SELECT OS.installtype "
			       . "FROM image i "
			       . "LEFT JOIN OS ON (i.OSid = OS.id) "
			       . "WHERE i.id = $imageid";
			$qh = doQuery($query, 101);
			if(! ($row = mysql_fetch_assoc($qh))) {
				cleanSemaphore();
				return debugIsAvailable(0, 8, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids);
			}
			# TODO might need to check for other strings for KVM, OpenStack, etc
			if(preg_match('/(vmware)/', $row['installtype']))
				$virtual = 1;
			else
				$virtual = 0;

			# get list of available computers
			if(! $ignoreprivileges) {
				$resources = getUserResources(array("imageAdmin", "imageCheckOut"),
				                              array("available"), 0, 0, $userid);
				$usercomputers = implode("','", array_keys($resources["computer"]));
				$usercomputers = "'$usercomputers'";
			}
			$alloccompids = implode(",", $allocatedcompids);

			# get list of computers we can provision image to

			$schedules = implode(',', $scheduleids);

			#image.OSid->OS.installtype->OSinstalltype.id->provisioningOSinstalltype.provisioningid->computer.provisioningid
			$query = "SELECT DISTINCT c.id, "
			       .                 "c.currentimageid, "
			       .                 "c.imagerevisionid "
			       . "FROM state s, "
			       .      "image i "
			       . "LEFT JOIN OS o ON (o.id = i.OSid) "
			       . "LEFT JOIN OSinstalltype oi ON (oi.name = o.installtype) "
			       . "LEFT JOIN provisioningOSinstalltype poi ON (poi.OSinstalltypeid = oi.id) "
			       . "LEFT JOIN computer c ON (poi.provisioningid = c.provisioningid) "
			       . "LEFT JOIN semaphore se ON (c.id = se.computerid) "
			       . "WHERE i.id = $imageid AND "
			       .       "c.scheduleid IN ($schedules) AND "
			       .       "c.platformid = $platformid AND "
			       .       "c.stateid = s.id AND "
			       .       "s.name NOT IN ($ignorestates) AND "
			       .       "c.RAM >= i.minram AND "
			       .       "c.procnumber >= i.minprocnumber AND "
			       .       "c.procspeed >= i.minprocspeed AND "
			       .       "c.network >= i.minnetwork AND "
			       .       "c.deleted = 0 AND "
			       .       "(c.type != 'virtualmachine' OR c.vmhostid IS NOT NULL) AND ";
			if(! $ignoreprivileges)
				$query .=   "c.id IN ($usercomputers) AND ";
			$query .=      "c.id IN ($mappedcomputers) AND "
			       .       "c.id NOT IN ($alloccompids) AND "
			       .       "(se.expires IS NULL OR se.expires < NOW()) "
			       . "ORDER BY RAM, "
			       .          "(c.procspeed * c.procnumber), "
			       .          "network";

			$qh = doQuery($query, 129);
			while($row = mysql_fetch_assoc($qh)) {
				array_push($computerids, $row['id']);
				if($row['currentimageid'] == $imageid &&
				   $row['imagerevisionid'] == $requestInfo['imagerevisions'][$key]) {
					array_push($currentids, $row['id']);
				}
			}
			# get computer ids available from block allocations
			$blockdata = getAvailableBlockComputerids($imageid, $start, $end,
			                                          $allocatedcompids);
			$blockids = $blockdata['compids'];
		}

		# return 0 if no computers available
		if(empty($computerids) && empty($blockids))
			return debugIsAvailable(0, 21, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, array(), $virtual);

		#remove computers from list that are already scheduled
		$usedComputerids = array();
		$query = "SELECT DISTINCT rs.computerid "
		       . "FROM reservation rs, "
		       .      "request rq "
		       . "WHERE '$startstamp' < (rq.end + INTERVAL 900 SECOND) AND "
		       .       "'$endstamp' > rq.start AND "
		       .       "rq.id != $requestid AND "
		       .       "rs.requestid = rq.id AND "
		       .       "rq.stateid NOT IN (1, 5, 12)"; # deleted, failed, complete
		$qh = doQuery($query, 130);
		while($row = mysql_fetch_row($qh)) {
			array_push($usedComputerids, $row[0]);
		}

		$computerids = array_diff($computerids, $usedComputerids);
		$currentids = array_diff($currentids, $usedComputerids);
		$blockids = array_diff($blockids, $usedComputerids);

		// if modifying a reservation and $computerids is now empty, return 0
		if($requestid && empty($computerids)) {
			cleanSemaphore();
			return debugIsAvailable(0, 9, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, array(), $virtual);
		}

		# return 0 if no computers available
		if(empty($computerids) && empty($currentids) && empty($blockids))
			return debugIsAvailable(0, 19, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, array(), $virtual);

		# remove computers from list that are allocated to block allocations
		if($altRemoveBlockCheck) {
			if(editRequestBlockCheck($computerids[0], $imageid, $start, $end)) {
				cleanSemaphore();
				return debugIsAvailable(0, 10, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, array(), $virtual);
			}
		}
		elseif(! count($blockids)) {  # && ! $altRemoveBlockCheck
			$usedBlockCompids = getUsedBlockComputerids($start, $end);
			$computerids = array_diff($computerids, $usedBlockCompids);
			$currentids = array_diff($currentids, $usedBlockCompids);
		}

		if($virtual && empty($currentids) && ! empty($computerids)) {
			# find computers whose hosts can handle the required RAM - we don't
			#   need to do this if there are VMs with the requested image already
			#   available because they would already fit within the host's available
			#   RAM

			if(! $vmhostcheckdone) {
				$vmhostcheckdone = 1;
				$query = "DROP TEMPORARY TABLE IF EXISTS VMhostCheck";
				doQuery($query, 101);

				$query = "CREATE TEMPORARY TABLE VMhostCheck ( "
				       .    "RAM mediumint unsigned NOT NULL, "
				       .    "allocRAM mediumint unsigned NOT NULL, "
				       .    "vmhostid smallint unsigned NOT NULL "
				       . ") ENGINE=MEMORY";
				doQuery($query, 101);

				$query = "INSERT INTO VMhostCheck "
				       . "SELECT c.RAM, "
				       .        "SUM(i.minram), "
				       .        "v.id "
				       . "FROM vmhost v "
				       . "LEFT JOIN computer c ON (v.computerid = c.id) "
				       . "LEFT JOIN computer c2 ON (v.id = c2.vmhostid) "
				       . "LEFT JOIN image i ON (c2.currentimageid = i.id) "
				       . "WHERE c.stateid = 20 "
				       . "GROUP BY v.id";
				doQuery($query, 101);
			}

			$inids = implode(',', $computerids);
			// if want overbooking, modify the last part of the WHERE clause
			$query = "SELECT c.id "
			       . "FROM VMhostCheck v "
			       . "LEFT JOIN computer c ON (v.vmhostid = c.vmhostid) "
			       . "LEFT JOIN image i ON (c.currentimageid = i.id) "
			       . "WHERE c.id IN ($inids) AND "
			       .       "(v.allocRAM - i.minram + {$images[$imageid]['minram']}) < v.RAM "
			       . "ORDER BY c.RAM, "
			       .          "(c.procspeed * c.procnumber), "
			       .          "c.network";
			$qh = doQuery($query, 101);
			$newcompids = array();
			while($row = mysql_fetch_assoc($qh))
				$newcompids[] = $row['id'];
			$computerids = $newcompids;
		}

		# check for use of specified IP address, have to wait until here
		#   because there may be a computer already assigned the IP that
		#   can be used for this reservation
		if(! empty($ip) && $now) {
			$allcompids = array_merge($computerids, $blockids);
			if(empty($allcompids))
				return debugIsAvailable(0, 13, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, array(), $virtual);
			$inids = implode(',', $allcompids);
			$query = "SELECT id "
			       . "FROM computer "
			       . "WHERE id NOT IN ($inids) AND "
			       .       "deleted = 0 AND "
			       .       "stateid != 1 AND "
			       .       "IPaddress = '$ip' AND "
			       .       "(type != 'virtualmachine' OR "
			       .       "vmhostid IS NOT NULL)";
			$qh = doQuery($query);
			if(mysql_num_rows($qh)) {
				if($now)
					return debugIsAvailable(-4, 18, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, array(), $virtual);
				$requestInfo['ipwarning'] = 1;
			}
			$query = "SELECT id "
			       . "FROM computer "
			       . "WHERE id in ($inids) AND "
			       .       "IPaddress = '$ip'";
			if($requestid)
				$query .= " AND id != $compid"; # TODO test this
			$qh = doQuery($query);
			$cnt = mysql_num_rows($qh);
			if($cnt > 1) {
				if($now)
					return debugIsAvailable(-4, 19, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, array(), $virtual);
				$requestInfo['ipwarning'] = 1;
			}
			elseif($cnt == 1) {
				$row = mysql_fetch_assoc($qh);
				$computerids = array($row['id']);
				$blockids = array();
			}
		}

		# remove any recently reserved computers that could have been an
		#   undetected failure
		$failedids = getPossibleRecentFailures($userid, $imageid);
		$shortened = 0;
		if(! empty($failedids)) {
			$origcomputerids = $computerids;
			$origcurrentids = $currentids;
			$origblockids = $blockids;
			if(! empty($computerids)) {
				$testids = array_diff($computerids, $failedids);
				if(! empty($testids)) {
					$shortened = 1;
					$computerids = $testids;
					$currentids = array_diff($currentids, $failedids);
				}
			}
			if(! empty($blockids)) {
				$testids = array_diff($blockids, $failedids);
				if(! empty($testids)) {
					$shortened = 1;
					$blockids = $testids;
				}
			}
		}

		# allocate a computer
		$_imgrevid = $requestInfo['imagerevisions'][$key];
		$comparr = allocComputer($blockids, $currentids, $computerids,
		                         $startstamp, $endstamp, $nowfuture, $imageid, $_imgrevid,
		                         $holdcomps, $requestid);
		if(empty($comparr) && $shortened)
			$comparr = allocComputer($origblockids, $origcurrentids,
			                         $origcomputerids, $startstamp, $endstamp, $nowfuture,
			                         $imageid, $_imgrevid, $holdcomps, $requestid);
		if(empty($comparr)) {
			cleanSemaphore();
			return debugIsAvailable(0, 11, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, $failedids, $virtual);
		}

		$requestInfo["computers"][$key] = $comparr['compid'];
		$requestInfo["mgmtnodes"][$key] = $comparr['mgmtid'];
		$requestInfo["loaded"][$key] = $comparr['loaded'];
		$requestInfo['fromblock'][$key] = $comparr['fromblock'];
		if($comparr['fromblock'])
			$requestInfo['blockdata'][$key] = $blockdata[$comparr['compid']];
		array_push($allocatedcompids, $comparr['compid']);
	}

	return debugIsAvailable(1, 12, $start, $end, $imagerevisionid, $computerids, $currentids, $blockids, array(), $virtual);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn debugIsAvailable($rc, $loc, $start, $end, $imagerevisionid,
///                      $compids=array(), $currentids=array(),
///                      $blockids=array(), $failedids=array(), $virtual='')
///
/// \param $rc - return code
/// \param $loc - location from isAvailable function
/// \param $start - as passed to isAvailable function
/// \param $end - as passed to isAvailable function
/// \param $imagerevisionid - as passed to isAvailable function
/// \param $compids - $computerids from isAvailable
/// \param $currentids - $currentids from isAvailable
/// \param $blockids - $blockids from isAvailable
/// \param $failedids - $failedids from isAvailable
/// \param $virtual - $virtual from isAvailable
///
/// \return $rc as passed in
///
/// \brief prints debug line about why isAvailable returned specified return
/// code in javascript console if user has 'View Debug Information' user group
/// permission and has set the debug flag; most data passed in is currently
/// unused, but allows for a single place to add code for debugging
///
////////////////////////////////////////////////////////////////////////////////
function debugIsAvailable($rc, $loc, $start, $end, $imagerevisionid,
	                       $compids=array(), $currentids=array(),
	                       $blockids=array(), $failedids=array(), $virtual='') {
	global $user, $mode, $requestInfo;
	$debug = getContinuationVar('debug', 0);
	if(! $debug ||
	   $mode != 'AJupdateWaitTime' ||
	   ! checkUserHasPerm('View Debug Information'))
		return $rc;
	switch($loc) {
		case "1":
			$msg = "site maintenance is scheduled for the requested time";
			break;
		case "20":
			$msg = "invalid image id submitted - not found in images available to the user";
			break;
		case "2":
			$msg = "an overlapping server reservation has the same fixed IP or MAC address";
			break;
		case "16":
			$msg = "the requested fixed IP address is currently in use by a management node";
			break;
		case "17":
			$msg = "failed to look up information about the specified user";
			break;
		case "3":
			$msg = "failed to get image usage count for block allocations";
			break;
		case "4":
			$msg = "max concurrent usage of image exceeded (includes those set aside for block allocations)";
			break;
		case "5":
			$msg = "failed to get platform of image";
			break;
		case "6":
			$msg = "image is not mapped to any computers";
			break;
		case "18":
			$msg = "no available computers under a management node that can handle the specified IP address";
			break;
		case "7":
			$msg = "the schedule of the currently reserved computer does not allow for the requested time";
			break;
		case "8":
			$msg = "failed to get OSinstalltype for image";
			break;
		case "21":
			$msg = "no computers with a matching schedule and platform, and in an available state, and available to the user, and mapped to the image, and matching image resource requirements";
			break;
		case "9":
			$msg = "not able to change existing reservation time for currently reserved computer";
			break;
		case "19":
			$msg = "no computers available (after removing scheduled computers/before performing virtual host resource checks)";
			break;
		case "10":
			$msg = "modification time overlaps with time computer is set aside for block allocation";
			break;
		case "13":
			$msg = "no computers available (after virtual host resource checks/before performing overlapping IP address check)";
			break;
		case "18":
			$msg = "requested IP address in use by another computer";
			break;
		case "19":
			$msg = "at least 2 computers have the requested IP address assigned to them";
			break;
		case "11":
			$msg = "unable to get either a management node or semaphore for available computer";
			break;
		case "12":
			$msg = "successfully found a computer (id: {$requestInfo['computers'][0]})";
			break;
	}
	print "console.log('$msg');";
	return $rc;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getAvailableSchedules($start, $end)
///
/// \param $start - start time in unix timestamp form
/// \param $end - end time in unix timestamp form
///
/// \return array of schedule ids
///
/// \brief gets schedules available for given start and end time
///
////////////////////////////////////////////////////////////////////////////////
function getAvailableSchedules($start, $end) {
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
	return $scheduleids;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImagePlatform($imageid)
///
/// \param $imageid - id of an image
///
/// \return id of image's platform
///
/// \brief gets the platformid for $imageid
///
////////////////////////////////////////////////////////////////////////////////
function getImagePlatform($imageid) {
	$query = "SELECT platformid FROM image WHERE id = $imageid";
	$qh = doQuery($query, 125);
	if(! $row = mysql_fetch_assoc($qh))
		return NULL;
	return $row['platformid'];
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn schCheckMaintenance($start, $end)
///
/// \param $start - unix timestamp for start of reservation
/// \param $end - unix timestamp for end of reservation
///
/// \return true if time window conflicts with maintenance window; false if not
///
/// \brief checks to see if the specified window conflicts with a maintenance
/// window
///
////////////////////////////////////////////////////////////////////////////////
function schCheckMaintenance($start, $end) {
	$startdt = unixToDatetime($start);
	$enddt = unixToDatetime($end);
	$query = "SELECT id "
	       . "FROM sitemaintenance "
	       . "WHERE ((allowreservations = 0 AND "
	       .       "(('$enddt' > start) AND ('$startdt' < end))) OR "
	       .       "(('$startdt' > (start - INTERVAL 30 MINUTE)) AND ('$startdt' < end))) AND "
	       .       "end > NOW()";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_row($qh))
		return true;
	return false;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn allocComputer($blockids, $currentids, $computerids, $start, $end,
///                   $nowfuture, $imageid, $imagerevisionid, $holdcomps,
///                   $requestid)
///
/// \param $blockids - array of computer ids
/// \param $currentids - array of computer ids
/// \param $computerids - array of computer ids
/// \param $start - start time in datetime format
/// \param $start - end time in datetime format
/// \param $nowfuture - "now" or "future"
/// \param $holdcomps - bool - 1 to lock computers for later adding to
/// reservation, 0 not to; use 0 when just checking for estimated availability,
/// use 1 when finding computers to actually reserve
/// \param $requestid - id of request if called for editing an existing one
///
/// \return empty array if failed to allocate a computer; array with these keys
/// on success:\n
/// \b compid - id of computer\n
/// \b mgmtid - id of management node for computer\n
/// \b loaded - 0 or 1 - whether or not computer is loaded with desired image
///
/// \brief determines a computer to use from $blockids, $currentids,
/// and $computerids, looking at the arrays in that order and
/// tries to allocate a management node for it
///
////////////////////////////////////////////////////////////////////////////////
function allocComputer($blockids, $currentids, $computerids, $start, $end,
                       $nowfuture, $imageid, $imagerevisionid, $holdcomps,
                       $requestid) {
	global $requestInfo;
	$ret = array();
	if(SCHEDULER_ALLOCATE_RANDOM_COMPUTER) {
		shuffle($blockids);
		shuffle($currentids);
		shuffle($computerids);
	}
	foreach($blockids as $compid) {
		$mgmtnodeid = findManagementNode($compid, $start, $nowfuture);
		if($mgmtnodeid == 0)
			continue;
		if($holdcomps && ! getSemaphore($imageid, $imagerevisionid, $mgmtnodeid, $compid, $start, $end, $requestid))
			continue;
		$ret['compid'] = $compid;
		$ret['mgmtid'] = $mgmtnodeid;
		$ret['loaded'] = 1;
		$ret['fromblock'] = 1;
		return $ret;
	}
	foreach($currentids as $compid) {
		$mgmtnodeid = findManagementNode($compid, $start, $nowfuture);
		if($mgmtnodeid == 0)
			continue;
		if($holdcomps && ! getSemaphore($imageid, $imagerevisionid, $mgmtnodeid, $compid, $start, $end, $requestid))
			continue;
		$ret['compid'] = $compid;
		$ret['mgmtid'] = $mgmtnodeid;
		$ret['loaded'] = 1;
		$ret['fromblock'] = 0;
		return $ret;
	}
	foreach($computerids as $compid) {
		$mgmtnodeid = findManagementNode($compid, $start, $nowfuture);
		if($mgmtnodeid == 0)
			continue;
		if($holdcomps && ! getSemaphore($imageid, $imagerevisionid, $mgmtnodeid, $compid, $start, $end, $requestid))
			continue;
		$ret['compid'] = $compid;
		$ret['mgmtid'] = $mgmtnodeid;
		$ret['loaded'] = 0;
		$ret['fromblock'] = 0;
		return $ret;
	}
	return $ret;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getSemaphore($imageid, $imagerevisionid, $mgmtnodeid, $compid, $start,
///                  $end, $requestid=0)
///
/// \param $imageid - id of image
/// \param $imagerevisionid - id of image revision
/// \param $mgmtnodeid - id of management node
/// \param $compid - id of computer
/// \param $start - start of reservation in datetime format
/// \param $end - end of reservation in datetime format
/// \param $requestid - (optional) if passed, ignores checking for conflict
/// in request table for matching id
///
/// \return 0 on failure, 1 on success
///
/// \brief tries to get a semaphore for the requested computer
///
////////////////////////////////////////////////////////////////////////////////
function getSemaphore($imageid, $imagerevisionid, $mgmtnodeid, $compid, $start,
                      $end, $requestid=0) {
	global $mysql_link_vcl, $uniqid;
	$query = "INSERT INTO semaphore "
	       . "SELECT c.id, "
	       .        "$imageid, "
	       .        "$imagerevisionid, "
	       .        "$mgmtnodeid, "
	       .        "NOW() + INTERVAL " . SEMTIMEOUT . " SECOND, "
	       .        "'$uniqid' "
			 . "FROM computer c "
	       . "LEFT JOIN semaphore s ON (c.id = s.computerid) "
	       . "WHERE c.id = $compid AND "
	       .       "(s.expires IS NULL OR s.expires < NOW()) "
	       . "LIMIT 1";
	doQuery($query);
	$rc = mysql_affected_rows($mysql_link_vcl);

	# check to see if another process allocated this one
	if($rc) {
		$query = "SELECT rq.id "
		       . "FROM request rq, "
		       .      "reservation rs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid = $compid AND "
		       .       "rq.start < '$end' AND "
		       .       "rq.end > '$start' AND "
		       .       "rq.stateid NOT IN (1, 5, 12)";
		if($requestid)
			$query .= " AND rq.id != $requestid";
		$qh = doQuery($query);
		$rc2 = mysql_num_rows($qh);
		if($rc2) {
			$query = "DELETE FROM semaphore "
			       . "WHERE computerid = $compid AND "
			       .       "procid = '$uniqid'";
			doQuery($query);
			return 0;
		}
	}
	return $rc;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn retryGetSemaphore($imageid, $imagerevisionid, $mgmtnodeid, $compid,
///                       $start, $end, $requestid=0, $tries=5, $delay=200000)
///
/// \param $imageid - id of image
/// \param $imagerevisionid - id of image revision
/// \param $mgmtnodeid - id of management node
/// \param $compid - id of computer
/// \param $start - start of reservation in datetime format
/// \param $end - end of reservation in datetime format
/// \param $requestid - (optional) if passed, ignores checking for conflict
/// \param $tries - (optional, default=5) number of attempts to make for getting
/// a semaphore
/// \param $delay - (optional, default=200000) microseconds to wait between
/// tries
///
/// \return 0 on failure, 1 on success
///
/// \brief makes multiple attempts to get a semaphore for a computer; useful
/// when needing to do an operation on a specific computer
///
////////////////////////////////////////////////////////////////////////////////
function retryGetSemaphore($imageid, $imagerevisionid, $mgmtnodeid, $compid,
                           $start, $end, $requestid=0, $tries=5, $delay=200000) {
	for($i = 0; $i < $tries; $i++) {
		if(getSemaphore($imageid, $imagerevisionid, $mgmtnodeid, $compid, $start, $end, $requestid)) {
			return 1;
		}
		else
			usleep($delay);
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getPossibleRecentFailures($userid, $imageid)
///
/// \param $userid - check log data for this user; if $userid = 0, check for
///                  currently logged in user
/// \param $imageid - check log data for this image
///
/// \return array of computerids that may have recently given the user a problem
///
/// \brief checks for recent reservations by the user that were very short and
/// within a recent time frame in case there was a computer that gave a problem
/// that the backend did not pick up
///
////////////////////////////////////////////////////////////////////////////////
function getPossibleRecentFailures($userid, $imageid) {
	if($userid == 0) {
		global $user;
		$userid = $user['id'];
	}
	$comps = array();
	$query = "SELECT s.computerid "
	       . "FROM log l "
	       . "LEFT JOIN sublog s ON (s.logid = l.id) "
	       . "WHERE l.start > (NOW() - INTERVAL 90 MINUTE) AND "
	       .       "l.finalend < NOW() AND "
	       .       "l.userid = $userid AND "
	       .       "l.imageid = $imageid AND "
	       .       "l.wasavailable = 1 AND "
	       .       "l.ending != 'failed'";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$comps[] = $row['computerid'];
	return $comps;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMappedResources($resourcesubid, $resourcetype1, $resourcetype2)
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
		   $end > datetimeToUnix($requests[$id]["start"])) &&
		   $requests[$id]['serverowner'] == 1) {
			$count++;
			if($count > $max)
				return 1;
		}
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editRequestBlockCheck($compid, $imageid, $start, $end)
///
/// \param $compid - id of computer to check
/// \param $imageid - id of image being checked
/// \param $start - start of time period in unix timestamp format
/// \param $end - end of time period in unix timestamp format
///
/// \return 1 if time period overlaps with a block allocation unavailable to the
/// logged in user; 0 if not
///
/// \brief checks to see if $compid is part of a block allocation that the
/// current user is not part of or is set for a different image than what the
/// user is currently using on the computer
///
////////////////////////////////////////////////////////////////////////////////
function editRequestBlockCheck($compid, $imageid, $start, $end) {
	global $user;
	$groupids = implode(',', array_keys($user['groups']));
	if(! count($user['groups']))
		$groupids = "''";
	$startdt = unixToDatetime($start);
	$enddt = unixToDatetime($end);
	$query = "SELECT bc.computerid "
	       . "FROM blockComputers bc, "
	       .      "blockTimes bt, "
	       .      "blockRequest r "
	       . "WHERE bc.blockTimeid = bt.id AND "
	       .       "bt.blockRequestid = r.id AND "
	       .       "bc.computerid = $compid AND "
	       .       "(bt.start - INTERVAL 15 MINUTE) < '$enddt' AND "
	       .       "bt.end > '$startdt' AND "
	       .       "(r.groupid NOT IN ($groupids) OR "
	       .       "r.imageid != $imageid) AND "
	       .       "r.status = 'accepted'";
	$qh = doQuery($query, 101);
	return(mysql_num_rows($qh));
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
/// \fn addRequest($forimaging, $revisionid, $nousercheck)
///
/// \param $forimaging - (optional) 0 if a normal request, 1 if a request for
/// creating a new image
/// \param $revisionid - (optional) desired revision id of the image
/// \param $checkuser - (optional, default=1) 0 or 1 - value to set for
/// request.checkuser
///
/// \return id from request table that corresponds to the added entry
///
/// \brief adds an entry to the request and reservation tables
///
////////////////////////////////////////////////////////////////////////////////
function addRequest($forimaging=0, $revisionid=array(), $checkuser=1) {
	global $requestInfo, $user, $uniqid, $mysql_link_vcl;
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

	# add single entry to request table
	$query = "INSERT INTO request "
	       .        "(stateid, "
	       .        "userid, "
	       .        "laststateid, "
	       .        "logid, "
	       .        "forimaging, "
	       .        "start, "
	       .        "end, "
	       .        "daterequested, "
	       .        "checkuser) "
	       . "VALUES "
	       .       "(13, "
	       .       "{$user['id']}, "
	       .       "13, "
	       .       "$logid, "
	       .       "$forimaging, "
	       .       "'$startstamp', "
	       .       "'$endstamp', "
	       .       "NOW(), "
	       .       "$checkuser)";
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
			$imagerevisionid = array_shift($revisionid[$imageid]);
		else
			$imagerevisionid = getProductionRevisionid($imageid);
		$computerid = $requestInfo["computers"][$key];
		$mgmtnodeid = $requestInfo['mgmtnodes'][$key];
		$fromblock = $requestInfo['fromblock'][$key];
		if($fromblock)
			$blockdata = $requestInfo['blockdata'][$key];
		else
			$blockdata = array();

		addSublogEntry($logid, $imageid, $imagerevisionid, $computerid,
		               $mgmtnodeid, $fromblock, $blockdata);
	}

	$query = "INSERT INTO reservation "
	       .        "(requestid, "
	       .        "computerid, "
	       .        "imageid, "
	       .        "imagerevisionid, "
	       .        "managementnodeid) "
	       . "SELECT $requestid, "
	       .        "computerid, "
	       .        "imageid, "
	       .        "imagerevisionid, "
	       .        "managementnodeid " 
	       . "FROM semaphore "
	       . "WHERE expires > NOW() AND "
	       .       "procid = '$uniqid'";
	doQuery($query);
	$cnt = mysql_affected_rows($mysql_link_vcl);
	if($cnt == 0) {
		# reached this point SEMTIMEOUT seconds after getting semaphore, clean up and abort
		$query = "DELETE FROM request WHERE id = $requestid";
		doQuery($query);
		$query = "UPDATE log SET wasavailable = 0 WHERE id = $logid";
		doQuery($query);
		$query = "DELETE FROM sublog WHERE logid = $logid";
		doQuery($query);
		abort(400);
	}
	else {
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
	}
	// release semaphore lock
	cleanSemaphore();

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

	$requestid = dbLastInsertID();
	if($requestid == 0)
		abort(135);

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
	$testid = dbLastInsertID();
	if($testid == 0)
		abort(135);

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
	       .       "rs.requestid = rq.id AND "
	       .       "rq.start > '$start' AND "
	       .       "rq.start < '$end' "
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
/// \fn getRequestInfo($id, $returnNULL)
///
/// \param $id - id of request
/// \param $returnNULL - (optional, default=0) return NULL if reservation no
///                      longer exists
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
/// \b forimaging - 0 if request is normal, 1 if it is for imaging\n
/// \b checkuser - 1 if connected user timeout checks are enabled, 0 if not\n
/// \b serverrequest - 0 if request is normal, 1 if it is a server request\n
/// \b servername - name of server if server request\n
/// \b admingroupid - id of admin user group if server request\n
/// \b logingroupid - id of login user group if server request\n
/// \b fixedIP - possible fixed IP address if server request\n
/// \b fixedMAC - possible fixed MAC address if server request\n\n
/// an array of reservations associated with the request whose key is
/// 'reservations', each with the following items:\n
/// \b imageid - id of the image\n
/// \b imagerevisionid - id of the image revision\n
/// \b production - image revision production flag (0 or 1)\n
/// \b image - name of the image\n
/// \b prettyimage - pretty name of the image\n
/// \b OS - name of the os\n
/// \b OStype - type of the os\n
/// \b computerid - id of the computer\n
/// \b reservationid - id of the corresponding reservation\n
/// \b reservedIP - ip address of reserved computer\n
/// \b hostname - hostname of reserved computer\n
/// \b forcheckout - whether or not the image is intended for checkout\n
/// \b password - password for this computer\n
/// \b connectIP - IP to which user will connect\n
/// \b remoteIP - IP of remote user\n\n
/// an array of arrays of passwords whose key is 'passwds', with the next key
/// being the reservationid and the elements being the userid as a key and that
/// user's password as the value
///
/// \brief creates an array with info about request $id
///
////////////////////////////////////////////////////////////////////////////////
function getRequestInfo($id, $returnNULL=0) {
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
	       .        "forimaging, "
	       .        "checkuser "
	       . "FROM request "
	       . "WHERE id = $id";
	$qh = doQuery($query, 165);
	if(! ($data = mysql_fetch_assoc($qh))) {
		if($returnNULL)
			return NULL;
		# FIXME handle XMLRPC cases
		if(! $printedHTMLheader) 
			print $HTMLheader;
		print "<h1>" . i("OOPS! - Reservation Has Expired") . "</h1>\n";
		$h = i("The selected reservation is no longer available. Go to <a>Reservations</a> to request a new reservation or select another one that is available.");
		print preg_replace('|<a>(.+)</a>|', '<a href="' . BASEURL . SCRIPT . '?mode=viewRequests">\1</a>', $h);
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
	       .        "o.type AS OStype, "
	       .        "rs.computerid, "
	       .        "rs.id AS reservationid, "
	       .        "c.IPaddress AS reservedIP, "
	       .        "c.hostname, "
	       .        "i.forcheckout, "
	       .        "rs.pw AS password, "
	       .        "COALESCE(nh.publicIPaddress, c.IPaddress) AS connectIP, "
	       .        "rs.remoteIP "
	       . "FROM reservation rs, "
	       .      "image i, "
	       .      "imagerevision ir, "
	       .      "OS o, "
	       .      "computer c "
	       . "LEFT JOIN nathostcomputermap n ON (c.id = n.computerid) "
	       . "LEFT JOIN nathost nh ON (n.nathostid = nh.id) "
	       . "WHERE rs.requestid = $id AND "
	       .       "rs.imageid = i.id AND "
	       .       "rs.imagerevisionid = ir.id AND "
	       .       "i.OSid = o.id AND "
	       .       "rs.computerid = c.id "
	       . "ORDER BY rs.id";
	$qh = doQuery($query, 101);
	$data["reservations"] = array();
	$data['passwds'] = array();
	$resids = array();
	while($row = mysql_fetch_assoc($qh)) {
		array_push($data["reservations"], $row);
		$resids[] = $row['reservationid'];
		$data['passwds'][$row['reservationid']][$data['userid']] = $row['password'];
	}
	$query = "SELECT id, "
	       .        "name, "
	       .        "admingroupid, "
	       .        "logingroupid, "
	       .        "fixedIP, "
	       .        "fixedMAC "
	       . "FROM serverrequest "
	       . "WHERE requestid = $id";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		$data['serverrequest'] = 1;
		$data['servername'] = $row['name'];
		$data['admingroupid'] = $row['admingroupid'];
		$data['logingroupid'] = $row['logingroupid'];
		$data['fixedIP'] = $row['fixedIP'];
		$data['fixedMAC'] = $row['fixedMAC'];
		$inids = implode(',', $resids);
		$query = "SELECT reservationid, "
		       .        "userid, "
		       .        "password "
		       . "FROM reservationaccounts "
		       . "WHERE reservationid IN ($inids)";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$data['passwds'][$row['reservationid']][$row['userid']] = $row['password'];
	}
	else
		$data['serverrequest'] = 0;
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
	global $requestInfo;
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
		       .       "computerid = $oldCompid "
				 . "LIMIT 1"; # without this, it can update one row to have the
		                    # same computer as another row; then, the later row
		                    # could be updated, which would end up setting both
		                    # rows to the same computer
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
			       . "WHERE id = {$request['id']}";
		}
		# current: reserved, last: new OR
		# current: pending, last: reserved
		elseif(($request["stateid"] == 3 && $request["laststateid"] == 13) ||
		   ($request["stateid"] == 14 && $request["laststateid"] == 3)) {
			$query = "UPDATE request "
			       . "SET stateid = 1, "
			       .     "laststateid = 3 "
			       . "WHERE id = {$request['id']}";
		}
		# current: inuse, last: reserved OR
		# current: pending, last: inuse
		elseif(($request["stateid"] == 8 && $request["laststateid"] == 3) ||
		       ($request["stateid"] == 14 && $request["laststateid"] == 8)) {
			$query = "UPDATE request "
			       . "SET stateid = 1, "
			       .     "laststateid = 8 "
			       . "WHERE id = {$request['id']}";
		}
		# shouldn't happen, but if current: pending, set to deleted or
		// if not current: pending, set laststate to current state and
		# current state to deleted
		else {
			if($request["stateid"] == 14) {
				$query = "UPDATE request "
				       . "SET stateid = 1 "
				       . "WHERE id = {$request['id']}";
				}
			else {
				# somehow a user submitted a deleteRequest where the current
				# stateid was empty
				if(! is_numeric($request["stateid"]) || $request["stateid"] < 0)
					$request["stateid"] = 1;
				$query = "UPDATE request "
				       . "SET stateid = 1, "
				       .     "laststateid = {$request['stateid']} "
				       . "WHERE id = {$request['id']}";
			}
		}
		$qh = doQuery($query, 150);

		addChangeLogEntry($request["logid"], NULL, unixToDatetime($now), NULL,
		                  NULL, "released");
		return;
	}

	if($request['serverrequest']) {
		$query = "SELECT id FROM serverrequest WHERE requestid = {$request['id']}";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh)) {
			$query = "DELETE FROM serverrequest WHERE requestid = {$request['id']}";
			doQuery($query, 152);
			deleteVariable("fixedIPsr{$row['id']}");
		}
	}

	$query = "DELETE FROM request WHERE id = {$request['id']}";
	doQuery($query, 153);

	$query = "DELETE FROM reservation WHERE requestid = {$request['id']}";
	doQuery($query, 154);

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
/// given, removes all reservations from the computer with the least number;
/// NOTE - cleanSemaphore should be called after this by the calling function
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
	       .        "rs.imagerevisionid, "
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
	# TODO eventually, for clusters, there will probably be restrictions on how the computers
	# relate to each other; at that point, this will need to be updated to make sure the computer
	# a reservation is reassigned to meets the same restrictions
	foreach($resInfo as $res) {
		// pass forimaging = 1 so that isAvailable only looks at one computer
		$rc = isAvailable($images, $res["imageid"], $res['imagerevisionid'], 
		      datetimeToUnix($res["start"]), datetimeToUnix($res["end"]), 0,
		      0, $res["userid"], 0, 1);
		if($rc < 1) {
			$allmovable = 0;
			break;
		}
	}
	if(! $allmovable)
		return 0;
	foreach($resInfo as $res) {
		$rc = isAvailable($images, $res["imageid"], $res['imagerevisionid'],
		      datetimeToUnix($res["start"]), datetimeToUnix($res["end"]), 1, 
		      0, $res["userid"], 0, 1);
		if($rc > 0) {
			$newcompid = array_shift($requestInfo["computers"]);
			# get mgmt node for computer
			$mgmtnodeid = findManagementNode($newcompid, $res['start'], 'future');
			# update mgmt node and computer in reservation table
			$query = "UPDATE reservation "
			       . "SET computerid = $newcompid, "
			       .     "managementnodeid = $mgmtnodeid "
			       . "WHERE id = {$res['id']}";
			doQuery($query, 101);
			# add changelog entry
			addChangeLogEntry($res['logid'], NULL, NULL, NULL, $newcompid);
			# update sublog entry
			$query = "UPDATE sublog "
			       . "SET computerid = $newcompid, "
			       .     "managementnodeid = $mgmtnodeid "
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
/// \fn moveReservationsOffVMs($compid, $sem)
///
/// \param $compid - id of host computer from which to move
/// reservations
/// \param $sem - (optional) array of data to be used when getting a semaphore
/// for a VM after reservations have been moved off of it; must include these
/// keys: imageid, revid, mnid, start (datetime), end (datetime)
///
/// \return 0 if failed to move reservations, 1 if succeeded, -1 if no
/// reservations were found on $compid
///
/// \brief attempts to move reservations off of any VMs assigned to a $compid
/// NOTE - cleanSemaphore should be called after this by the calling function
///
////////////////////////////////////////////////////////////////////////////////
function moveReservationsOffVMs($compid, $sem=0) {
	if(! is_array($sem)) {
		$sem = array();
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
		$tmp = array_keys($resources['image']);
		$sem['imageid'] = $tmp[0];
		$sem['revid'] = getProductionRevisionid($sem['imageid']);
		$tmp = array_keys($resources['managementnode']);
		$sem['mnid'] = $tmp[0];
		$sem['start'] = unixToDatetime(time());
		$sem['end'] = '2038-01-01 00:00:00';
	}
	$query = "SELECT vm.id "
	       . "FROM computer vm, "
	       .      "vmhost v "
	       . "WHERE v.computerid = $compid AND "
	       .       "vm.vmhostid = v.id";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		$rc = moveReservationsOffComputer($row['id']);
		if($rc != 0)
			# lock computer so that reservations on other VMs on this host do not get moved to it
			getSemaphore($sem['imageid'], $sem['revid'], $sem['mnid'], $row['id'], $sem['start'], $sem['end']);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getCompFinalReservationTime($compid, $extraskipstate=0)
///
/// \param $compid - a computer id
/// \param $extraskipstate - (default=0) id of an additional request state to
/// ignore; if 0 passed, no additional states are ignored
///
/// \return unix timestamp of last end time of any reservations for $compid
///
/// \brief determines the final end time of all reservations on a computer
///
////////////////////////////////////////////////////////////////////////////////
function getCompFinalReservationTime($compid, $extraskipstate=0) {
	$end = 0;
	$skipstates = "1,5,12";
	if($extraskipstate)
		$skipstates .= ",$extraskipstate";
	$query = "SELECT UNIX_TIMESTAMP(rq.end) as end "
	       . "FROM request rq, "
	       .      "reservation rs "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "rs.computerid = $compid AND "
	       .       "rq.stateid NOT IN ($skipstates) "
	       . "ORDER BY rq.end DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		$end = $row['end'];
	$query = "SELECT UNIX_TIMESTAMP(t.end) as end "
	       . "FROM blockComputers c, "
	       .      "blockTimes t "
	       . "WHERE c.computerid = $compid AND "
	       .       "c.blockTimeid = t.id AND "
	       .       "t.end > NOW() "
	       . "ORDER BY t.end DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		if($row['end'] > $end)
			$end = $row['end'];
	return $end;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getCompFinalVMReservationTime($hostid, $addsemaphores, $notomaintenance)
///
/// \param $hostid - computer id of a vm host
/// \param $addsemaphores - (optional, default = 0) 1 to add semaphores for each
/// of the VMs
/// \param $notomaintenance - (optional, default = 0) 1 to ignore any
/// tomaintenance reservations
///
/// \return unix timestamp of last end time of any reservations for VMs on
/// $hostid; 0 if no reservations; -1 if $addsemaphores = 1 and failed to get
/// semaphores
///
/// \brief determines the final end time of all reservations of all VMs on a
/// VM host computer
///
////////////////////////////////////////////////////////////////////////////////
function getCompFinalVMReservationTime($hostid, $addsemaphores=0,
                                       $notomaintenance=0) {
	global $uniqid, $mysql_link_vcl;
	if($addsemaphores) {
		$query = "SELECT vm.id "
		       . "FROM computer vm, "
		       .      "vmhost v "
		       . "WHERE v.computerid = $hostid AND "
		       .       "vm.vmhostid = v.id";
		$qh = doQuery($query);
		$compids = array();
		while($row = mysql_fetch_assoc($qh))
			$compids[] = $row['id'];
		if(empty($compids))
			return 0;
		$allcompids = implode(',', $compids);
		$imageid = getImageId('noimage');
		$revid = getProductionRevisionid($imageid);
		$tmp = getManagementNodes();
		$tmp = array_keys($tmp);
		$mnid = $tmp[0];
		$query = "INSERT INTO semaphore "
		       . "SELECT c.id, "
		       .        "$imageid, "
		       .        "$revid, "
		       .        "$mnid, "
		       .        "NOW() + INTERVAL " . SEMTIMEOUT . " SECOND, "
		       .        "'$uniqid' "
				 . "FROM computer c "
		       . "LEFT JOIN semaphore s ON (c.id = s.computerid) "
		       . "WHERE c.id IN ($allcompids) AND "
		       .       "(s.expires IS NULL OR s.expires < NOW()) "
		       . "GROUP BY c.id";
		doQuery($query);
		$cnt = mysql_affected_rows($mysql_link_vcl);
		if($cnt != count($compids))
			return -1;
	}

	$end = 0;
	$skipstates = '1,5,12';
	if($notomaintenance)
		$skipstates .= ',18';
	$query = "SELECT UNIX_TIMESTAMP(rq.end) as end "
	       . "FROM request rq, "
	       .      "reservation rs "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "rq.stateid NOT IN ($skipstates) AND "
	       .       "rs.computerid IN (SELECT vm.id "
	       .                          "FROM computer vm, "
	       .                               "vmhost v "
	       .                          "WHERE v.computerid = $hostid AND "
	       .                                "vm.vmhostid = v.id) "
	       . "ORDER BY rq.end DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		$end = $row['end'];
	$query = "SELECT UNIX_TIMESTAMP(t.end) as end "
	       . "FROM blockComputers c, "
	       .      "blockTimes t "
	       . "WHERE c.blockTimeid = t.id AND "
	       .       "t.end > NOW() AND "
	       .       "c.computerid IN (SELECT vm.id "
	       .                        "FROM computer vm, "
	       .                             "vmhost v "
	       .                        "WHERE v.computerid = $hostid AND "
	       .                              "vm.vmhostid = v.id) "
	       . "ORDER BY t.end DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		if($row['end'] > $end)
			$end = $row['end'];
	return $end;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getExistingChangeStateStartTime($compid, $stateid)
///
/// \param $compid - computer id
/// \param $stateid - id of state of reservation
///
/// \return unix timestamp
///
/// \brief gets the start time for the earliest existing reservation for $compid
/// that has a state of $stateid
///
////////////////////////////////////////////////////////////////////////////////
function getExistingChangeStateStartTime($compid, $stateid) {
	$query = "SELECT rq.start "
	       . "FROM request rq, "
	       .      "reservation rs "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "rs.computerid = $compid AND "
	       .       "rq.stateid = $stateid AND "
	       .       "rq.start > NOW() "
	       . "ORDER BY rq.start "
	       . "LIMIT 1";
	$qh = doQuery($query);
	if($row = mysql_fetch_assoc($qh))
		return datetimeToUnix($row['start']);
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateExistingToState($compid, $start, $stateid)
///
/// \param $compid - computer id
/// \param $start - new start time in datetime format
/// \param $stateid - id of state for existing reservation
///
/// \brief updates the start time of an existing reservation for $compid with a
/// state of $stateid
///
////////////////////////////////////////////////////////////////////////////////
function updateExistingToState($compid, $start, $stateid) {
	$query = "UPDATE request rq, "
	       .        "reservation rs "
	       . "SET rq.start = '$start' "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "rq.stateid = $stateid AND "
	       .       "rq.start > '$start' AND "
	       .       "rs.computerid = $compid";
	doQuery($query);
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
/// \b userid - id of user owning request\n
/// \b imageid - id of requested image\n
/// \b imagerevisionid - revision id of requested image\n
/// \b image - name of requested image\n
/// \b prettyimage - pretty name of requested image\n
/// \b OS - name of the requested os\n
/// \b OSinstalltype - installtype for OS\n
/// \b start - start time of request\n
/// \b end - end time of request\n
/// \b daterequested - date request was made\n
/// \b currstateid - current stateid of request\n
/// \b laststateid - last stateid of request\n
/// \b forimaging - 0 if an normal request, 1 if imaging request\n
/// \b forcheckout - 1 if image is available for reservations, 0 if not\n
/// \b test - test flag - 0 or 1\n
/// \b longterm - 1 if request length is > 24 hours\n
/// \b server - 1 if corresponding entry in serverprofiles\n
/// \b serverowner - 1 user owns the reservation, 0 if not\n
/// \b resid - id of primary reservation\n
/// \b compimageid - currentimageid for primary computer\n
/// \b computerstateid - current stateid of primary computer\n
/// \b computerid - id of primary computer\n
/// \b IPaddress - IP address of primary computer\n
/// \b comptype - type of primary computer\n
/// \b vmhostid - if VM, id of host's entry in vmhost table, NULL otherwise\n
/// the following additional items if a server request (values will be NULL
/// if not a server request), some values can be NULL:\n
/// \b servername - name of server request\n
/// \b serverrequestid - from server request table\n
/// \b fixedIP - if specified for request\n
/// \b fixedMAC - if specified for request\n
/// \b serveradmingroupid - id of admin user group\n
/// \b serveradmingroup - name of admin user group\n
/// \b serverlogingroupid - id of login user group\n
/// \b serverlogingroup - name of login user group\n
/// \b monitored - whether or not request is to be monitored (0 or 1)\n
/// \b useraccountready - whether or not all accounts for this user have been
/// created on the reserved machine(s)\n
/// and an array of subimages named reservations with the following elements
/// for each subimage:\n
/// \b resid - id of reservation\n
/// \b imageid - id of requested image\n
/// \b imagerevisionid - revision id of requested image\n
/// \b image - name of requested image\n
/// \b prettyname - pretty name of requested image\n
/// \b OS - name of the requested os\n
/// \b compimageid - currentimageid for computer\n
/// \b computerstateid - current stateid of computer\n
/// \b computerid - id of reserved computer\n
/// \b IPaddress - IP address of reserved computer\n
/// \b type - type of computer\n
/// \b resacctuserid - empty if user account has not been created on this machine
/// yet, the user's numeric id if it has\n
/// \b password - password for this user on the machine; if it is empty but
/// resacctuserid is not empty, the user should use a federated password
///
/// \brief builds an array of current requests made by the user
///
////////////////////////////////////////////////////////////////////////////////
function getUserRequests($type, $id=0) {
	global $user;
	if($id == 0)
		$id = $user["id"];
	$includegroups = getUsersGroups($user["id"]);
	if(empty($includegroups))
		$ingroupids = "''";
	else
		$ingroupids = implode(',', array_keys($includegroups));
	$query = "SELECT i.name AS image, "
	       .        "i.prettyname AS prettyimage, "
	       .        "i.id AS imageid, "
	       .        "rq.userid, "
	       .        "rq.start, "
	       .        "rq.end, "
	       .        "rq.daterequested, "
	       .        "rq.id, "
	       .        "o.prettyname AS OS, "
	       .        "o.installtype AS OSinstalltype, "
	       .        "rq.stateid AS currstateid, "
	       .        "rq.laststateid, "
	       .        "rs.computerid, "
	       .        "rs.id AS resid, "
	       .        "c.currentimageid AS compimageid, "
	       .        "c.stateid AS computerstateid, "
	       .        "c.IPaddress, "
	       .        "c.type AS comptype, "
	       .        "c.vmhostid, "
	       .        "rq.forimaging, "
	       .        "i.forcheckout, "
	       .        "rs.managementnodeid, "
	       .        "rs.imagerevisionid, "
	       .        "rq.test,"
	       .        "sp.name AS servername, "
	       .        "sp.requestid AS serverrequestid, "
	       .        "sp.fixedIP, "
	       .        "sp.fixedMAC, "
	       .        "sp.admingroupid AS serveradmingroupid, "
	       .        "uga.name AS serveradmingroup, "
	       .        "sp.logingroupid AS serverlogingroupid, "
	       .        "ugl.name AS serverlogingroup, "
	       .        "sp.monitored, "
	       .        "ra.password, "
	       .        "ra.userid AS resacctuserid, "
	       .        "rs.pw "
	       . "FROM image i, "
	       .      "OS o, "
	       .      "computer c, "
	       .      "request rq "
	       . "LEFT JOIN serverrequest sp ON (sp.requestid = rq.id) "
	       . "LEFT JOIN usergroup uga ON (uga.id = sp.admingroupid) "
	       . "LEFT JOIN usergroup ugl ON (ugl.id = sp.logingroupid) "
	       . "LEFT JOIN reservation rs ON (rs.requestid = rq.id) "
	       . "LEFT JOIN reservationaccounts ra ON (ra.reservationid = rs.id AND ra.userid = $id) "
	       . "WHERE (rq.userid = $id OR "
	       .       "sp.admingroupid IN ($ingroupids) OR "
	       .       "sp.logingroupid IN ($ingroupids)) AND "
	       .       "rs.imageid = i.id AND "
	       .       "rq.end > NOW() AND "
	       .       "i.OSid = o.id AND "
	       .       "c.id = rs.computerid AND "
	       .       "rq.stateid NOT IN (1, 10, 16, 17) AND "      # deleted, maintenance, complete, image, makeproduction
	       .       "rq.laststateid NOT IN (1, 10, 16, 17) ";  # deleted, maintenance, complete, image, makeproduction
	if($type == "normal")
		$query .=   "AND rq.forimaging = 0 "
		       .    "AND i.forcheckout = 1 "
		       .    "AND sp.requestid IS NULL ";
	if($type == "forimaging")
		$query .=   "AND rq.forimaging = 1 "
		       .    "AND sp.requestid IS NULL ";
	if($type == "server")
		$query .=   "AND sp.requestid IS NOT NULL ";
	$query .= "ORDER BY rq.start, "
	       .           "rs.id";
	$qh = doQuery($query, 160);
	$count = -1;
	$data = array();
	$foundids = array();
	$lastreqid = 0;
	while($row = mysql_fetch_assoc($qh)) {
		if($row['id'] != $lastreqid) {
			$lastreqid = $row['id'];
			$count++;
			$data[$count] = $row;
			$data[$count]['useraccountready'] = 1;
			$data[$count]['reservations'] = array();
		}
		if(array_key_exists($row['id'], $foundids)) {
			$data[$count]['reservations'][] = array(
				'resid' => $row['resid'],
				'image' => $row['image'],
				'prettyname' => $row['prettyimage'],
				'imageid' => $row['imageid'],
				'imagerevisionid' => $row['imagerevisionid'],
				'OS' => $row['OS'],
				'computerid' => $row['computerid'],
				'compimageid' => $row['compimageid'],
				'computerstateid' => $row['computerstateid'],
				'IPaddress' => $row['IPaddress'],
				'comptype' => $row['comptype'],
				'password' => $row['password'],
				'resacctuserid' => $row['resacctuserid']
			);
			if($row['userid'] != $id && empty($row['resacctuserid']))
				$data[$count]['useraccountready'] = 0;
			continue;
		}
		$foundids[$row['id']] = 1;
		if(! is_null($row['serverrequestid'])) {
			$data[$count]['server'] = 1;
			$data[$count]['longterm'] = 0;
			if($row['userid'] == $user['id']) {
				$data[$count]['serverowner'] = 1;
				$data[$count]['serveradmin'] = 1;
			}
			else {
				$data[$count]['serverowner'] = 0;
				if(! empty($row['serveradmingroupid']) && 
				   array_key_exists($row['serveradmingroupid'], $user['groups']))
					$data[$count]['serveradmin'] = 1;
				else
					$data[$count]['serveradmin'] = 0;
			}
		}
		elseif((datetimeToUnix($row['end']) - datetimeToUnix($row['start'])) > SECINDAY) {
			$data[$count]['server'] = 0;
			$data[$count]['longterm'] = 1;
			$data[$count]['serverowner'] = 1;
			$data[$count]['serveradmin'] = 1;
		}
		else {
			$data[$count]['server'] = 0;
			$data[$count]['longterm'] = 0;
			$data[$count]['serverowner'] = 1;
			$data[$count]['serveradmin'] = 1;
		}
		if($row['userid'] != $id && empty($row['resacctuserid']))
			$data[$count]['useraccountready'] = 0;
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
	   $computers[$request["computerid"]]["imagerevisionid"] != $request["imagerevisionid"]))
		return 1;
	foreach($request["reservations"] as $res) {
		if($computers[$res["computerid"]]["stateid"] == 6 ||
		   ($computers[$res["computerid"]]["stateid"] == 2 &&
		   $computers[$res["computerid"]]["imagerevisionid"] != $res["imagerevisionid"]))
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
/// \fn numdatetimeToDatetime($numtime)
///
/// \param $numtime - date and time in YYYYMMDDHHMMSS format
///
/// \return a mysql datetime formatted string (YYYY-MM-DD HH:MM:SS)
///
/// \brief converts numeric date and time into datetime format
///
////////////////////////////////////////////////////////////////////////////////
function numdatetimeToDatetime($numtime) {
	$year = substr($numtime, 0, 4);
	$month = substr($numtime, 4, 2);
	$day = substr($numtime, 6, 2);
	$hour = substr($numtime, 8, 2);
	$min = substr($numtime, 10, 2);
	$sec = substr($numtime, 12, 2);
	return "$year-$month-$day $hour:$min:$sec";
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
/// \fn hour24to12($hour) {
///
/// \param $hour - hour of day in 24 hour format
///
/// \return array with two elements where the first item is the hour and the
//  second item is either 'am' or 'pm'
///
/// \brief converts 24 hour to 12 hour + am/pm
///
////////////////////////////////////////////////////////////////////////////////
function hour24to12($hour) {
	$m = 'am';
	if($hour == 0)
		$hour = 12;
	elseif($hour == 12)
		$m = 'pm';
	elseif($hour > 12) {
		$m = 'pm';
		$hour -= 12;
	}
	return array($hour, $m);
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
/// \fn getProvisioningTypes()
///
/// \return array of provisioning types allowed for each computer type of this
/// form:\n
/// {[blade] => {[id] => type,\n
///              [id] => type},\n
///  [lab] => {[id] => type}\n
///  [virtualmachine] => {[id] => type,\n
///                       [id] => type}\n
///
/// \brief generates an array of provisioning types allowed for each computer
/// type
///
////////////////////////////////////////////////////////////////////////////////
function getProvisioningTypes() {
	$query = "SELECT id, prettyname FROM provisioning WHERE name = 'none'";
	$qh = doQuery($query);
	$none = mysql_fetch_assoc($qh);
	$query = "SELECT p.id, "
	       .        "p.prettyname, "
	       .        "o.name AS `type` "
	       . "FROM provisioning p, "
	       .      "OSinstalltype o, "
	       .      "provisioningOSinstalltype po "
	       . "WHERE po.provisioningid = p.id AND "
	       .       "po.OSinstalltypeid = o.id "
	       . "ORDER BY o.name";
	$qh = doQuery($query);
	$types = array('blade' => array($none['id'] => $none['prettyname']),
	               'lab' => array(),
	               'virtualmachine' => array());
	while($row = mysql_fetch_assoc($qh)) {
		if($row['type'] == 'kickstart' || $row['type'] == 'partimage')
			$types['blade'][$row['id']] = $row['prettyname'];
		elseif($row['type'] == 'none')
			$types['lab'][$row['id']] = $row['prettyname'];
		else
			$types['virtualmachine'][$row['id']] = $row['prettyname'];
	}
	return $types;
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
/// \b resourceid - id from resource table\n
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
/// \fn getManagementNodes($alive, $includedeleted, $id)
///
/// \param $alive - (optional) if given, only return "alive" nodes, can be
///                 either "now" or "future" so we know how recently it must
///                 have checked in
/// \param $includedeleted - (optional, default=0) 1 to include management
///                 nodes with a state of deleted, 0 to leave them out
/// \param $id - (optional, default is all nodes) specify an id of a management
///                 node to only have data for that node returned
///
/// \return an array of management nodes where eash index is the id from the
/// managementnode table and each element is an array of data about the node
///
/// \brief builds an array of data about the management nodes\n
/// if $alive = now, must have checked in within 5 minutes\n
/// if $alive = future, must have checked in within 1 hour
///
////////////////////////////////////////////////////////////////////////////////
function getManagementNodes($alive="neither", $includedeleted=0, $id=0) {
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
	       .        "m.publicIPconfiguration AS publicIPconfig, "
	       .        "m.publicSubnetMask AS publicnetmask, "
	       .        "m.publicDefaultGateway AS publicgateway, "
	       .        "m.publicDNSserver AS publicdnsserver, "
	       .        "m.sysadminEmailAddress AS sysadminemail, "
	       .        "m.sharedMailBox AS sharedmailbox, "
	       .        "r.id as resourceid, "
	       .        "m.availablenetworks, "
	       .        "m.NOT_STANDALONE AS federatedauth, "
	       .        "nh.publicIPaddress AS natpublicIPaddress, "
	       .        "COALESCE(nh.internalIPaddress, '') AS natinternalIPaddress "
	       . "FROM user u, "
	       .      "state s, "
	       .      "affiliation a, "
	       .      "managementnode m "
	       . "LEFT JOIN resourcegroup rg ON (m.imagelibgroupid = rg.id) "
	       . "LEFT JOIN resourcetype rt ON (rt.name = 'managementnode') "
	       . "LEFT JOIN resource r ON (r.resourcetypeid = rt.id AND r.subid = m.id) "
	       . "LEFT JOIN nathost nh ON (r.id = nh.resourceid) "
	       . "WHERE m.ownerid = u.id AND "
	       .       "m.stateid = s.id AND "
	       .       "u.affiliationid = a.id";
	if($id != 0)
		$query .= " AND m.id = $id";
	if($includedeleted == 0)
		$query .= " AND s.name != 'deleted'";
	if($alive == "now" || $alive == "future") {
		$query .= " AND m.lastcheckin > '$lastcheckin'"
		       .  " AND s.name != 'maintenance'";
	}
	$qh = doQuery($query, 101);
	$return = array();
	while($row = mysql_fetch_assoc($qh)) {
		if(is_null($row['natpublicIPaddress'])) {
			$row['nathostenabled'] = 0;
			$row['natpublicIPaddress'] = '';
		}
		else
			$row['nathostenabled'] = 1;
		$return[$row["id"]] = $row;
		$return[$row['id']]['availablenetworks'] = explode(',', $row['availablenetworks']);
		if($row['state'] == 'deleted')
			$return[$row['id']]['deleted'] = 1;
		else
			$return[$row['id']]['deleted'] = 0;
	}

	# Get items from variable table for specific management node id
	foreach ($return as $mn_id => $value ) {
		if(array_key_exists("hostname", $value)) {
			$mn_hostname = $value['hostname'];
			$timeservers = getVariable('timesource|'.$mn_hostname);
			if($timeservers == NULL) {
				$timeservers = getVariable('timesource|global');
			}
			$return[$mn_id]['timeservers'] = $timeservers;
		}
	}
	
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMnsFromImage($imageid)
///
/// \param $imageid - id of an image
///
/// \return array of management node ids
///
/// \brief determines which management nodes can handle an image based on
/// image group to computer group, then computer group to management node group
/// mapping
///
////////////////////////////////////////////////////////////////////////////////
function getMnsFromImage($imageid) {
	$comps = getMappedResources($imageid, 'image', 'computer');
	if(empty($comps))
		return array();
	$inlist = implode(',', $comps);
	$query = "SELECT DISTINCT rgm.resourcegroupid "
	       . "FROM resourcegroupmembers rgm, "
	       .      "resource r, "
	       .      "computer c "
	       . "WHERE c.id = r.subid AND "
	       .       "r.resourcetypeid = 12 AND "
	       .       "r.id = rgm.resourceid AND "
	       .       "c.id in ($inlist)";
	$qh = doQuery($query);
	$compgroups = array();
	while($row = mysql_fetch_assoc($qh))
		$compgroups[] = $row['resourcegroupid'];
	$mngrps = array();
	foreach($compgroups as $grpid) {
		$mngrpset = getResourceMapping('managementnode', 'computer', '', implode(',', $compgroups));
		foreach($mngrpset as $mngrpid => $compgrpset)
			$mngrps[$mngrpid] = 1;
	}
	$mngrpnames = array();
	foreach(array_keys($mngrps) as $mnid) {
		$mngrpnames[] = getResourceGroupName($mnid);
	}
	$mns = getResourcesFromGroups($mngrpnames, 'managementnode', 0);
	$mnids = array();
	foreach($mns as $mnid => $name)
		$mnids[$mnid] = 1;
	return array_keys($mnids);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkAvailableNetworks($ip)
///
/// \param $ip - public ip address for a reservation
///
/// \return array of management node ids that can handle $ip
///
/// \brief finds any management nodes that can manage networks containing $ip
///
////////////////////////////////////////////////////////////////////////////////
function checkAvailableNetworks($ip) {
	$ip = ip2long($ip);
	$mnids = array();
	$mns = getManagementNodes();
	foreach($mns as $mn) {
		foreach($mn['availablenetworks'] as $net) {
			if($net == '')
				continue;
			list($net, $netmask) = explode('/', $net);
			$net = ip2long($net);
			$mask = pow(2, (32 - $netmask)) - 1;
			$mask = ~ $mask;
			if(($ip & $mask) == ($net & $mask))
				$mnids[$mn['id']] = 1;
		}
	}
	return array_keys($mnids);
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
/// \fn getTimeSlots($compids, $end, $start)
///
/// \param $compids - array of computer ids
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
	$maintItems = getMaintItemsForTimeTable($start, $endtime);
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
			$reserveInfo[$id][$current]['blockAllocation'] = 0;
			$reserveInfo[$id][$current]["inmaintenance"] = 0;
			if(scheduleClosed($id, $current, $schedules[$scheduleids[$id]])) {
				$reserveInfo[$id][$current]["available"] = 0;
				$reserveInfo[$id][$current]["scheduleclosed"] = 1;
				continue;
			}
			if(checkInMaintenanceForTimeTable($current, $current + 900, $maintItems)) {
				$reserveInfo[$id][$current]["available"] = 0;
				$reserveInfo[$id][$current]["inmaintenance"] = 1;
				continue;
			}
			if($blockid = isBlockAllocationTime($id, $current, $blockData)) {
				$reserveInfo[$id][$current]['blockAllocation'] = 1;
				$reserveInfo[$id][$current]['blockInfo']['groupid'] = $blockData[$blockid]['groupid'];
				$reserveInfo[$id][$current]['blockInfo']['imageid'] = $blockData[$blockid]['imageid'];
				$reserveInfo[$id][$current]['blockInfo']['name'] = $blockData[$blockid]['name'];
				$reserveInfo[$id][$current]['blockInfo']['image'] = $blockData[$blockid]['image'];
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
					# set the previous 15 minute block to show as busy to allow for load time
					$first = 0;
					$reserveInfo[$id][$current - 900]['blockAllocation'] = 0;
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
			if(checkUserHasPerm('View Debug Information')) {
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
	print "<table summary=\"\">\n";
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
	global $mode, $user;
	$imaging = getContinuationVar('imaging', 0);
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
	print "<H2>" . i("Time Table") . "</H2>\n";
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
			print i("There are currently no computers available that can run the application you selected.") . "\n";
		}
		else {
			print i("There are no computers that meet the specified criteria") . "\n";
		}
		return;
	}
	if($showmessage) {
		print i("The time you have requested to use the environment is not available. You may select from the green blocks of time to select an available time slot to make a reservation.") . "<br>\n";
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
		               'schedules' => $schedules,
		               'imaging' => $imaging);
		$cont = addContinuationsEntry($mode, $cdata, SECINDAY);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=" . i("Previous") . ">\n";
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
		               'schedules' => $schedules,
		               'imaging' => $imaging);
		$cont = addContinuationsEntry($mode, $cdata, SECINDAY);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=" . i("Next") . ">\n";
		print "</FORM>\n";
	}
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>\n";

	$tmpArr = array_keys($computers);
	$first = $computers[$tmpArr[0]];
	print "      <table id=ttlayout summary=\"\">\n";
	if(! $links || checkUserHasPerm('View Debug Information')) {
		print "        <TR>\n";
		print "          <TH align=right>Computer&nbsp;ID:</TH>\n";
		print $computeridrow;
		print "        </TR>\n";
	}
	$yesterday = "";
	foreach(array_keys($timeslots[$first]) as $stamp) {
		if($stamp < $now)
			continue;
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
			# maintenance window
			if($timeslots[$id][$stamp]["inmaintenance"] == 1) {
				print "          <TD bgcolor=\"#a0a0a0\"><img src=images/gray.jpg ";
				print "alt=sitemaintenance border=0></TD>\n";
			}
			# computer's schedule is currently closed
			elseif($timeslots[$id][$stamp]["scheduleclosed"] == 1) {
				print "          <TD bgcolor=\"#a0a0a0\"><img src=images/gray.jpg ";
				print "alt=scheduleclosed border=0></TD>\n";
			}
			# computer is in maintenance state
			elseif($computerData[$id]["stateid"] == 10) {
				print "          <TD bgcolor=\"#a0a0a0\"><img src=images/gray.jpg ";
				print "alt=maintenance border=0></TD>\n";
			}
			# computer is reserved for a block allocation that doesn't match this
			elseif($timeslots[$id][$stamp]['blockAllocation'] &&
			   ($timeslots[$id][$stamp]['blockInfo']['imageid'] != $imageid ||  # this line threw an error at one point, but we couldn't recreate it later
			   (! in_array($timeslots[$id][$stamp]['blockInfo']['groupid'], array_keys($user['groups'])))) &&
				$timeslots[$id][$stamp]['available']) {
				if($links) {
					print "          <TD bgcolor=\"#ff0000\"><img src=images/red.jpg ";
					print "alt=blockallocation border=0></TD>\n";
				}
				else {
					print "          <TD bgcolor=\"#e58304\"><img src=images/orange.jpg ";
					$title = "Block Allocation: {$timeslots[$id][$stamp]['blockInfo']['name']}\n"
					       . "Image: {$timeslots[$id][$stamp]['blockInfo']['image']}";
					print "alt=blockallocation border=0 title=\"$title\"></TD>\n";
				}
			}
			# computer is free
			elseif($timeslots[$id][$stamp]["available"]) {
				if($links) {
					print "          <TD bgcolor=\"#00ff00\"><a href=\"" . BASEURL . SCRIPT;
					print "?mode=viewRequests&stamp=$stamp&imageid=$imageid&length=$length&imaging=$imaging\"><img ";
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
					$title = i("User:") . " " . $timeslots[$id][$stamp]["unityid"]
					       . " " . i("Image:") . " " . $timeslots[$id][$stamp]["prettyimage"];
					$ttdata = array('start' => $argstart,
					                'end' => $argend,
					                'imageid' => $imageid,
					                'requestid' => $timeslots[$id][$stamp]["requestid"],
					                'length' => $length,
					                'platforms' => $platforms,
					                'schedules' => $schedules,
					                'imaging' => $imaging);
					$cdata = array('requestid' => $timeslots[$id][$stamp]["requestid"],
					               'ttdata' => $ttdata);
					$cont = addContinuationsEntry('viewRequestInfo', $cdata);
					print "          <TD bgcolor=\"#ff0000\"><a href=\"" . BASEURL;
					print SCRIPT . "?continuation=$cont\"><img src=images/red.jpg ";
					print "alt=used border=0 title=\"$title\"></a></TD>\n";
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
		               'schedules' => $schedules,
		               'imaging' => $imaging);
		$cont = addContinuationsEntry($mode, $cdata, SECINDAY);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=" . i("Previous") . ">\n";
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
		               'schedules' => $schedules,
		               'imaging' => $imaging);
		$cont = addContinuationsEntry($mode, $cdata, SECINDAY);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=" . i("Next") . ">\n";
		print "</FORM>\n";
	}
	print "</TD>\n";
	print "  </TR>\n";
	print "</table>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn findAvailableTimes($start, $end, $imageid, $userid, $usedaysahead,
//                         $reqid='', $extendonly=0, $ip='', $mac='')
///
/// \param $start - desired start time (epoch time)
/// \param $end - desired end time (epoch time)
/// \param $imageid - desired image
/// \param $userid - id of user to check for
/// \param $usedaysahead - 1 to limit suggested start time based on DAYSAHEAD,
/// 0 not to
/// \param $reqid - (optional, default='') id of a request to ignore - use this
/// when editing an existing reservation
/// \param $extendonly - (optional, default=0) if set to 1, only check for how
/// long this reservation can be extended; $reqid also be given a value and
/// function will only search for extensions to existing reservation on same
/// computer
/// \param $ip - (optional, default='') desired IP address
/// \param $mac - (optional, default='') desired MAC address
///
/// \return an array where each key is a unix timestamp for the start time of 
/// the available slot and each element is an array with these items:\n
/// \b start - start of slot in datetime format\n
/// \b startts - start of slot in unix timestamp format\n
/// \b duration - length of slot in minutes\n
/// \b compid - id of computer for slot
///
/// \brief builds an array of available time slots close to the submitted
/// parameters
///
////////////////////////////////////////////////////////////////////////////////
function findAvailableTimes($start, $end, $imageid, $userid, $usedaysahead,
                            $reqid='', $extendonly=0, $ip='', $mac='') {
	global $user;
	if($userid == $user['id'])
		$ingroups = implode(',', array_keys($user['groups']));
	else {
		$userdata = getUserInfo($userid, 0, 1);
		$ingroups = implode(',', array_keys($userdata['groups']));
	}
	# TODO make this work for cluster images
	if(! $extendonly) {
		$mappedcomputers = getMappedResources($imageid, 'image', 'computer');
		$resources = getUserResources(array('imageAdmin', 'imageCheckOut'),
		                              array('available'), 0, 0, $userid);
		$compids = array_intersect($mappedcomputers, array_keys($resources['computer']));
		if(! count($compids)) {
			return array();
		}
		$incompids = implode(',', $compids);
	}
	else {
		$request = getRequestInfo($reqid);
		$incompids = $request['reservations'][0]['computerid'];
	}
	$scheduleids = getAvailableSchedules($start, $end);
	if(empty($scheduleids))
		return array();
	$schedules = implode(',', $scheduleids);
	$platformid = getImagePlatform($imageid);
	if(is_null($platformid))
		return array();
	$reqduration = $end - $start;
	$startdt = unixToDatetime($start);
	$end += 900;
	$enddt = unixToDatetime($end);
	$ignorestates = "'maintenance','vmhostinuse','hpc','failed'";
	$nowignorestates = "$ignorestates,'timeout'";
	if(! $extendonly)
		$nowignorestates .= ",'reloading','reload','inuse'";
	$slots = array();
	$removes = array();
	$minstart = $start;
	$maxend = $start;
	$newcompids = array();
	$daysahead = time() + (DAYSAHEAD * SECINDAY);

	# add computers that are available now with no future reservations
	# restricting duration; we do this so that they'll be in our arrays to check
	# for concurrent image use, block allocations, ip/mac overlap, and
	# maintenance window overlap
	$query = "SELECT c.id AS compid "
	       . "FROM computer c, "
	       .      "image i, "
	       .      "state s, "
	       .      "provisioningOSinstalltype poi, "
	       .      "OSinstalltype oi, "
	       .      "OS o "
	       . "WHERE c.stateid = s.id AND "
	       .       "i.id = $imageid AND "
	       .       "s.name NOT IN ($nowignorestates) AND "
	       .       "c.platformid = $platformid AND "
	       .       "c.scheduleid IN ($schedules) AND "
	       .       "i.OSid = o.id AND "
	       .       "o.installtype = oi.name AND "
	       .       "oi.id = poi.OSinstalltypeid AND "
	       .       "poi.provisioningid = c.provisioningid AND "
	       .       "c.RAM >= i.minram AND "
	       .       "c.procnumber >= i.minprocnumber AND "
	       .       "c.procspeed >= i.minprocspeed AND "
	       .       "c.network >= i.minnetwork AND "
	       .       "c.id NOT IN (SELECT rs.computerid "
	       .                    "FROM reservation rs, "
	       .                         "request rq "
	       .                    "WHERE rs.requestid = rq.id AND ";
	if($reqid != '')
		$query .=                      "rq.id != $reqid AND ";
	$query .=                         "DATE_ADD(rq.end, INTERVAL 15 MINUTE) >= '$startdt' AND "
	       .                          "rs.computerid IN ($incompids)) AND "
	       .       "c.id IN ($incompids) "
	       . "ORDER BY RAM, "
	       .          "(c.procspeed * c.procnumber), "
	       .          "network";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		$row['duration'] = $reqduration;
		$row['startts'] = $start;
		$row['start'] = $startdt;
		$row['endts'] = $start + $reqduration;
		$slots[$row['compid']] = array();
		$slots[$row['compid']][] = $row;
		$newcompids[] = $row['compid'];
	}

	if(! $extendonly) {
		# find available timeslots based on spacing between existing reservations
		$query = "SELECT rs1.computerid AS compid, "
		       .        "DATE_ADD(rq1.end, INTERVAL 15 MINUTE) AS start, "
		       .        "MIN(UNIX_TIMESTAMP(rq2.start) - UNIX_TIMESTAMP(rq1.end) - 1800) AS duration " # 1800 is adding 15 min to end of rq1.end and end of requested reservation
		       . "FROM request rq1, "
		       .      "request rq2, "
		       .      "reservation rs1, "
		       .      "reservation rs2, "
		       .      "image i, "
		       .      "state s, "
		       .      "computer c, "
		       .      "provisioningOSinstalltype poi, "
		       .      "OSinstalltype oi, "
		       .      "OS o "
		       . "WHERE rq1.id = rs1.requestid AND "
		       .       "rs2.requestid = rq2.id AND "
		       .       "rq1.id != rq2.id AND "
		       .       "rq1.start < rq2.start AND "
		       .       "DATE_ADD(rq1.end, INTERVAL 15 MINUTE) >= '$startdt' AND "
		       .       "rs1.computerid = rs2.computerid AND "
		       .       "rs1.computerid IN ($incompids) AND "
		       .       "i.id = $imageid AND "
		       .       "c.id = rs1.computerid AND "
		       .       "c.platformid = $platformid AND "
		       .       "c.scheduleid IN ($schedules) AND "
		       .       "i.OSid = o.id AND "
		       .       "o.installtype = oi.name AND "
		       .       "oi.id = poi.OSinstalltypeid AND "
		       .       "poi.provisioningid = c.provisioningid AND "
		       .       "c.RAM >= i.minram AND "
		       .       "c.procnumber >= i.minprocnumber AND "
		       .       "c.procspeed >= i.minprocspeed AND "
		       .       "c.network >= i.minnetwork AND "
		       .       "c.stateid = s.id AND "
		       .       "s.name NOT IN ($ignorestates) AND ";
		if($reqid != '')
			$query .=   "rq1.id != $reqid AND "
			       .    "rq2.id != $reqid AND ";
		$query .=      "(c.type != 'virtualmachine' OR c.vmhostid IS NOT NULL) "
		       . "GROUP BY rq1.id ";
		$query .= "ORDER BY rs1.computerid, rq1.start, rq1.end";
		$qh = doQuery($query, 101);
		while($row = mysql_fetch_assoc($qh)) {
			$row['startts'] = datetimeToUnix($row['start']);
			if($row['startts'] % 900) {
				$row['startts'] = $row['startts'] - ($row['startts'] % 900) + 900;
				$row['start'] = unixToDatetime($row['startts']);
				$row['duration'] -= 900;
			}
			if($row['duration'] >= 1800) {
				if($usedaysahead && $row['startts'] > $daysahead)
					continue;
				if($row['duration'] > $reqduration)
					$row['duration'] = $reqduration;
				$row['endts'] = $row['startts'] + $row['duration'];
				if(! array_key_exists($row['compid'], $slots))
					$slots[$row['compid']] = array();
				$slots[$row['compid']][] = $row;
				if($row['startts'] < $minstart)
					$minstart = $row['startts'];
				if($row['endts'] > $maxend)
					$maxend = $row['endts'];
				$newcompids[] = $row['compid'];
			}
		}
	}

	# find slots that are available now
	$query = "SELECT UNIX_TIMESTAMP(MIN(rq.start)) - UNIX_TIMESTAMP('$startdt') - 900 AS duration, "
	       .        "UNIX_TIMESTAMP(MIN(rq.start)) AS endts, "
	       .        "rs.computerid AS compid "
	       . "FROM request rq, "
	       .      "reservation rs, "
	       .      "image i, "
	       .      "state s, "
	       .      "computer c, "
	       .      "provisioningOSinstalltype poi, "
	       .      "OSinstalltype oi, "
	       .      "OS o "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "(rq.start > '$startdt' OR "
	       .        "(DATE_ADD(rq.end, INTERVAL 15 MINUTE) > '$startdt' AND rq.start <= '$startdt')) AND "
	       .       "rs.computerid IN ($incompids) AND "
	       .       "i.id = $imageid AND "
	       .       "c.id = rs.computerid AND "
	       .       "c.platformid = $platformid AND "
	       .       "c.scheduleid IN ($schedules) AND "
	       .       "i.OSid = o.id AND "
	       .       "o.installtype = oi.name AND "
	       .       "oi.id = poi.OSinstalltypeid AND "
	       .       "poi.provisioningid = c.provisioningid AND "
	       .       "c.RAM >= i.minram AND "
	       .       "c.procnumber >= i.minprocnumber AND "
	       .       "c.procspeed >= i.minprocspeed AND "
	       .       "c.network >= i.minnetwork AND "
	       .       "c.stateid = s.id AND "
	       .       "s.name NOT IN ($nowignorestates) AND ";
	if($reqid != '')
		$query .=   "rq.id != $reqid AND ";
	$query .=      "(c.type != 'virtualmachine' OR c.vmhostid IS NOT NULL) "
	       . "GROUP BY rs.computerid";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		if($row['endts'] % 900) {
			$row['endts'] = $row['endts'] - ($row['endts'] % 900);
			$row['duration'] -= 900;
		}
		if($row['duration'] >= 1800) {
			if($row['duration'] > $reqduration)
				$row['duration'] = $reqduration;
			$row['start'] = $startdt;
			$row['startts'] = $start;
			if(! array_key_exists($row['compid'], $slots))
				$slots[$row['compid']] = array();
			$slots[$row['compid']][] = $row;
			if($row['endts'] > $maxend)
				$maxend = $row['endts'];
			$newcompids[] = $row['compid'];
		}
	}

	# find slots that are available after all reservations are over
	$query = "SELECT UNIX_TIMESTAMP(MAX(rq.end)) + 900 AS startts, "
	       .        "DATE_ADD(MAX(rq.end), INTERVAL 15 MINUTE) AS start, "
	       .        "rs.computerid AS compid "
	       . "FROM request rq, "
	       .      "reservation rs, "
	       .      "image i, "
	       .      "state s, "
	       .      "computer c, "
	       .      "provisioningOSinstalltype poi, "
	       .      "OSinstalltype oi, "
	       .      "OS o "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "(rq.start > '$startdt' OR "
	       .        "(DATE_ADD(rq.end, INTERVAL 15 MINUTE) > '$startdt' AND rq.start <= '$startdt')) AND "
	       .       "rs.computerid IN ($incompids) AND "
	       .       "i.id = $imageid AND "
	       .       "c.id = rs.computerid AND "
	       .       "c.platformid = $platformid AND "
	       .       "c.scheduleid IN ($schedules) AND "
	       .       "i.OSid = o.id AND "
	       .       "o.installtype = oi.name AND "
	       .       "oi.id = poi.OSinstalltypeid AND "
	       .       "poi.provisioningid = c.provisioningid AND "
	       .       "c.RAM >= i.minram AND "
	       .       "c.procnumber >= i.minprocnumber AND "
	       .       "c.procspeed >= i.minprocspeed AND "
	       .       "c.network >= i.minnetwork AND "
	       .       "c.deleted = 0 AND "
	       .       "c.stateid = s.id AND "
	       .       "s.name NOT IN ($ignorestates) AND ";
	if($reqid != '')
		$query .=   "rq.id != $reqid AND ";
	$query .=      "(c.type != 'virtualmachine' OR c.vmhostid IS NOT NULL) "
	       . "GROUP BY rs.computerid";
	if($extendonly)
		$query .= " HAVING start = '$startdt'";
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh)) {
		if($usedaysahead && $row['startts'] > $daysahead)
			continue;
		if($row['startts'] % 900) {
			$row['startts'] = $row['startts'] - ($row['startts'] % 900) + 900;
			$row['start'] = unixToDatetime($row['startts']);
		}
		$row['endts'] = $row['startts'] + $reqduration;
		$row['duration'] = $reqduration;
		if(! array_key_exists($row['compid'], $slots))
			$slots[$row['compid']] = array();
		$slots[$row['compid']][] = $row;
		if($row['endts'] > $maxend)
			$maxend = $row['endts'];
		$newcompids[] = $row['compid'];
	}
	if(empty($newcompids))
		return array();

	# remove block computers
	$minstartdt = unixToDatetime($minstart);
	$maxenddt = unixToDatetime($maxend);
	$newincompids = implode(',', $newcompids);
	$query = "SELECT bc.computerid AS compid, "
	       .        "UNIX_TIMESTAMP(bt.start) AS start, "
	       .        "UNIX_TIMESTAMP(bt.end) AS end "
	       . "FROM blockComputers bc, "
	       .      "blockTimes bt, "
	       .      "blockRequest br "
	       . "WHERE bt.id = bc.blockTimeid AND "
	       .       "br.id = bt.blockRequestid AND "
	       .       "bt.skip = 0 AND "
	       .       "bt.start < '$maxenddt' AND "
	       .       "bt.end > '$minstartdt' AND ";
	if($ingroups != '')
		$query .=   "(br.groupid NOT IN ($ingroups) OR "
		       .    "br.imageid != $imageid) AND ";
	$query .=      "bc.computerid IN ($newincompids)";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		if(array_key_exists($row['compid'], $slots))
			fATremoveOverlaps($slots, $row['compid'], $row['start'], $row['end'], 0);
	}

	# remove mac/ip overlaps
	$newcompids = array_keys($slots);
	$newincompids = implode(',', $newcompids);
	if(! empty($ip) || ! empty($mac)) {
		$query = "SELECT rs.computerid AS compid, "
		       .        "UNIX_TIMESTAMP(rq.start) AS start, "
		       .        "UNIX_TIMESTAMP(rq.end) AS end "
		       . "FROM serverrequest s, "
		       .      "request rq, "
		       .      "reservation rs "
		       . "WHERE s.requestid = rq.id AND "
		       .       "rs.requestid = rq.id AND "
		       .       "rq.start < '$maxenddt' AND "
		       .       "rq.end > '$minstartdt' AND "
		       .       "rs.computerid IN ($newincompids) AND ";
		if($reqid != '')
			$query .=   "rq.id != $reqid AND ";
		if(! empty($ip) && ! empty($mac))
			$query .=   "(s.fixedIP = '$ip' OR s.fixedMAC = '$mac')";
		elseif(! empty($ip))
			$query .=   "s.fixedIP = '$ip'";
		elseif(! empty($mac))
			$query .=   "s.fixedIP = '$mac'";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh)) {
			if(array_key_exists($row['compid'], $slots))
				fATremoveOverlaps($slots, $row['compid'], $row['start'], $row['end'], 0);
		}
	}

	# remove slots overlapping with scheduled maintenance
	$query = "SELECT UNIX_TIMESTAMP(start) AS start, "
	       .        "UNIX_TIMESTAMP(end) AS end, "
	       .        "allowreservations "
	       . "FROM sitemaintenance "
	       . "WHERE start < '$maxenddt' AND "
	       .       "end > '$minstartdt'";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		foreach(array_keys($slots) AS $compid)
			fATremoveOverlaps($slots, $compid, $row['start'], $row['end'],
			                  $row['allowreservations']);
	}

	$imgdata = getImages(0, $imageid);
	$options = array();
	foreach($slots AS $comp) {
		foreach($comp AS $data) {
			$data['duration'] = $data['duration'] - ($data['duration'] % 900);
			if(! $extendonly) {
				if($data['duration'] > 3600 && $data['duration'] < 7200)
					$data['duration'] = 3600;
				elseif($data['duration'] > 7200 && $data['duration'] < (SECINDAY * 2))
					$data['duration'] = $data['duration'] - ($data['duration'] % 7200);
				elseif($data['duration'] > (SECINDAY * 2))
					$data['duration'] = $data['duration'] - ($data['duration'] % SECINDAY);
			}
			# skip computers that have no controlling management node
			if(! findManagementNode($data['compid'], $data['start'], 'future'))
				continue;
			# skip slots that would cause a concurrent use violation
			if($imgdata[$imageid]['maxconcurrent'] != NULL &&
				fATconcurrentOverlap($data['startts'], $data['duration'], $imageid,
				                     $imgdata[$imageid]['maxconcurrent'], $ignorestates,
				                     $extendonly, $reqid))
				continue;
			if(array_key_exists($data['startts'], $options)) {
				if($data['duration'] > $options[$data['startts']]['duration']) {
					$options[$data['startts']]['duration'] = $data['duration'];
					if(checkUserHasPerm('View Debug Information'))
						$options[$data['startts']]['compid'] = $data['compid'];
				}
			}
			else {
				$options[$data['startts']] = array('start' => $data['start'],
				                                   'startts' => $data['startts'],
				                                   'duration' => $data['duration']);
				if(checkUserHasPerm('View Debug Information'))
					$options[$data['startts']]['compid'] = $data['compid'];
			}
		}
	}
	uasort($options, "sortAvailableTimesByStart");
	return $options;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn fATremoveOverlaps($array, $compid, $start, $end, $allowstart)
///
/// \param $array - array of time slots - pass by reference
/// \param $compid - id of computer to check
/// \param $start - start of time period
/// \param $end - end of time period
/// \param $allowstart - whether or not $start can be within $array time slot
///
/// \brief removes timeslots from $array that overlap with $start and $end
///
////////////////////////////////////////////////////////////////////////////////
function fATremoveOverlaps(&$array, $compid, $start, $end, $allowstart) {
	foreach($array[$compid] AS $key => $data) {
		if($data['startts'] < $end && $data['endts'] > $start) {
			# reservation within slot
			if($data['startts'] <= $start && $data['endts'] >= $end) {
				if($allowstart)
					continue;
				$test1 = $data['duration'] - ($data['endts'] - $start) - 900;
				$test2 = $data['duration'] - ($end - $data['startts']) - 900;
				if($test1 < 1800 && $test2 < 1800)
					unset($array[$compid][$key]);
				elseif($test1 >= 1800 && $test2 < 1800)
					$array[$compid][$key]['duration'] = $test1;
				elseif($test1 < 1800 && $test2 >= 1800) {
					$array[$compid][$key]['duration'] = $test2;
					$array[$compid][$key]['startts'] = $end + 900;
					$array[$compid][$key]['start'] = unixToDatetime($end + 900);
				}
				else {
					$array[$compid][$key]['duration'] = $test1;
					$new = array('duration' => $test2,
					             'endts' => $end + 900 + $test2,
					             'compid' => $compid,
					             'start' => unixToDatetime($end + 900),
					             'startts' => $end + 900);
					$array[$compid][] = $new;
				}
			}
			# start of reservation overlaps slot
			elseif($data['startts'] < $start && $data['endts'] > $start) {
				if($allowstart)
					continue;
				$test = $data['duration'] - ($data['endts'] - $start) - 900;
				if($test >= 1800)
					$array[$compid][$key]['duration'] = $test;
				else
					unset($array[$compid][$key]);
			}
			# end of reservation overlaps slot
			elseif($data['startts'] < $end && $data['endts'] > $end) {
				$test = $data['duration'] - ($end - $data['startts']) - 900;
				if($test >= 1800) {
					$array[$compid][$key]['duration'] = $test;
					$array[$compid][$key]['startts'] = $end + 900;
					$array[$compid][$key]['start'] = unixToDatetime($end + 900);
				}
				else
					unset($array[$compid][$key]);
			}
			# slot within reservation
			#if($data['startts'] >= $start && $data['endts'] <= $end)
			else
				unset($array[$compid][$key]);
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn fATconcurrentOverlap($start, $length, $imageid, $maxoverlap,
//                           $ignorestates, $extendonly, $reqid)
///
/// \param $start - start time (epoch time)
/// \param $length - desired duration in seconds
/// \param $imageid - id of image
/// \param $maxoverlap - max allowed overlapping reservations for image
/// \param $ignorestates - computers with these states should be ignored
/// \param $extendonly - 1 if this is an extension, 0 otherwise
/// \param $reqid - id of request if $extendonly is 1
///
/// \return 1 if this would violate max concurrent use of the image, 0 if not
///
/// \brief determines if a reservation during the specified time slot would
/// violate the max concurrent reservations for $imageid
///
////////////////////////////////////////////////////////////////////////////////
function fATconcurrentOverlap($start, $length, $imageid, $maxoverlap,
                              $ignorestates, $extendonly, $reqid) {
	$end = $start + $length;
	$query = "SELECT rq.start, "
	       .        "rq.end "
	       . "FROM request rq, "
	       .      "reservation rs, "
	       .      "state s, "
	       .      "computer c "
	       . "WHERE rs.requestid = rq.id AND "
	       .       "rs.computerid = c.id AND "
	       .       "rs.imageid = $imageid AND "
	       .       "UNIX_TIMESTAMP(rq.start) < $end AND "
	       .       "UNIX_TIMESTAMP(rq.end) > $start AND "
	       .       "c.stateid = s.id AND "
	       .       "s.name NOT IN ($ignorestates)";
	if($extendonly)
		$query .= " AND rq.id != $reqid";
	$qh = doQuery($query);
	if(mysql_num_rows($qh) >= $maxoverlap)
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sortAvailableTimesByStart($a, $b)
///
/// \param $a - first item
/// \param $b - second item
///
/// \return -1 if $a < $b, 0 if $a == $b, 1 if $a > $b
///
/// \brief used to sort suggested times in findAvailableTimes
///
////////////////////////////////////////////////////////////////////////////////
function sortAvailableTimesByStart($a, $b) {
	$ats = datetimeToUnix($a['start']);
	$bts = datetimeToUnix($b['start']);
	if($ats < $bts)
		return -1;
	if($ats > $bts)
		return 1;
	return 0;
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
/// \b owner - unity id of owner\n
/// \b ownerid - user id of owner\n
/// \b platform - computer's platform\n
/// \b platformid - id of computer's platform\n
/// \b schedule - computer's schedule\n
/// \b scheduleid - id of computer's schedule\n
/// \b currentimg - computer's current image\n
/// \b currentimgid - id of computer's current image\n
/// \b imagerevisionid - revision id of computer's current image\n
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
/// \b privateIPaddress - computer's private IP address\n
/// \b eth0macaddress - computer's eth0 mac address\n
/// \b eth1macaddress - computer's eth1 mac address\n
/// \b type - either 'blade' or 'lab' - used to determine what backend utilities\n
/// \b deleted - 0 or 1; whether or not this computer has been deleted\n
/// \b resourceid - computer's resource id from the resource table\n
/// \b location - computer's location\n
/// \b provisioningid - id of provisioning engine\n
/// \b provisioning - pretty name of provisioning engine\n
/// \b vmprofileid - if vmhost, id of vmprofile
/// need to be used to manage computer\n
/// \b natenabled - 0 or 1; if NAT is enabled for this computer\n
/// \b nathostid - id from nathost table if NAT is enabled or empty string if
/// not
///
/// \brief builds an array of computers
///
////////////////////////////////////////////////////////////////////////////////
function getComputers($sort=0, $includedeleted=0, $compid="") {
	$nathosts = getNAThosts();
	$return = array();
	$query = "SELECT c.id AS id, "
	       .        "st.name AS state, "
	       .        "c.stateid AS stateid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "u.id AS ownerid, "
	       .        "p.name AS platform, "
	       .        "c.platformid AS platformid, "
	       .        "sc.name AS schedule, "
	       .        "c.scheduleid AS scheduleid, "
	       .        "cur.prettyname AS currentimg, "
	       .        "c.currentimageid AS currentimgid, "
	       .        "c.imagerevisionid, "
	       .        "next.prettyname AS nextimg, "
	       .        "c.nextimageid AS nextimgid, "
	       .        "c.RAM AS ram, "
	       .        "c.procnumber AS procnumber, "
	       .        "c.procspeed AS procspeed, "
	       .        "c.network AS network, "
	       .        "c.hostname AS hostname, "
	       .        "c.IPaddress AS IPaddress, "
	       .        "c.privateIPaddress, "
	       .        "c.eth0macaddress, "
	       .        "c.eth1macaddress, "
	       .        "c.type AS type, "
	       .        "c.deleted AS deleted, "
	       .        "r.id AS resourceid, "
	       .        "c.notes, "
	       .        "c.vmhostid, "
	       .        "c2.hostname AS vmhost, "
	       .        "c2.id AS vmhostcomputerid, "
	       .        "c.location, "
	       .        "c.provisioningid, "
	       .        "pr.prettyname AS provisioning, "
	       .        "vh2.vmprofileid, "
	       .        "c.predictivemoduleid, "
	       .        "m.prettyname AS predictivemodule, "
	       .        "nh.id AS nathostid, "
	       .        "nh2.id AS nathostenabledid, "
	       .        "COALESCE(nh2.publicIPaddress, '') AS natpublicIPaddress, "
	       .        "COALESCE(nh2.internalIPaddress, '') AS natinternalIPaddress "
	       . "FROM state st, "
	       .      "platform p, "
	       .      "schedule sc, "
	       .      "image cur, "
	       .      "user u, "
	       .      "affiliation a, "
	       .      "module m, "
	       .      "computer c "
	       . "LEFT JOIN resourcetype t ON (t.name = 'computer') "
	       . "LEFT JOIN resource r ON (r.resourcetypeid = t.id AND r.subid = c.id) "
	       . "LEFT JOIN vmhost vh ON (c.vmhostid = vh.id) "
	       . "LEFT JOIN vmhost vh2 ON (c.id = vh2.computerid) "
	       . "LEFT JOIN computer c2 ON (c2.id = vh.computerid) "
	       . "LEFT JOIN image next ON (c.nextimageid = next.id) "
	       . "LEFT JOIN provisioning pr ON (c.provisioningid = pr.id) "
	       . "LEFT JOIN nathostcomputermap nm ON (nm.computerid = c.id) "
	       . "LEFT JOIN nathost nh ON (nm.nathostid = nh.id) "
	       . "LEFT JOIN nathost nh2 ON (r.id = nh2.resourceid) "
	       . "WHERE c.stateid = st.id AND "
	       .       "c.platformid = p.id AND "
	       .       "c.scheduleid = sc.id AND "
	       .       "c.currentimageid = cur.id AND "
	       .       "c.ownerid = u.id AND "
	       .       "u.affiliationid = a.id AND "
	       .       "c.predictivemoduleid = m.id ";
	if(! $includedeleted)
		$query .= "AND c.deleted = 0 ";
	if(! empty($compid))
		$query .= "AND c.id = $compid ";
	$query .= "ORDER BY c.hostname";
	$qh = doQuery($query, 180);
	while($row = mysql_fetch_assoc($qh)) {
		if(is_null($row['nathostid'])) {
			$row['natenabled'] = 0;
			$row['nathost'] = '';
		}
		else {
			$row['natenabled'] = 1;
			$row['nathost'] = $nathosts[$row['nathostid']]['hostname'];
		}
		if(is_null($row['nathostenabledid']))
			$row['nathostenabled'] = 0;
		else
			$row['nathostenabled'] = 1;
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
/// \return an array of 2 indices - platforms, schedules - where each
/// index's value is an array of user's computer's data
///
/// \brief builds an array of platforms and schedules for user's computers
///
////////////////////////////////////////////////////////////////////////////////
function getUserComputerMetaData() {
	$key = getKey(array('getUserComputerMetaData'));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	$computers = getComputers();
	$resources = getUserResources(array("computerAdmin"), 
	                              array("administer", "manageGroup"), 0, 1);
	$return = array("platforms" => array(),
	                "schedules" => array());
	foreach(array_keys($resources["computer"]) as $compid) {
		if(! array_key_exists($compid, $computers))
			continue;
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
	if($row['start'] < $row['reqtime']) {
		# now
		$reqtime = $row['reqtime'];
		$future = 0;
	}
	else
		$future = 1;
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
		if(empty($last)) {
			if($future)
				# just set to 10 sec for first state since we don't know when a preload started
				$data[$row['id']]['time'] = 10;
			else
				$data[$row['id']]['time'] = $row['ts'] - $reqtime;
		}
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

	$a['hostname'] = preg_replace('/-UNDELETED-[0-9]+$/', '', $a['hostname']);
	$b['hostname'] = preg_replace('/-UNDELETED-[0-9]+$/', '', $b['hostname']);

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
/// allocated while processing this reservation
///
/// \return an array with the key 'compids' that is an array of available
/// computerids; additional keys exist for each computerid that are arrays
/// of block data for that computer with these keys:\n
/// \b start - start of block time\n
/// \b end - end of block time\n
/// \b blockid - id of block request
///
/// \brief gets all computer ids that are part of a block allocation the logged
/// in user is a part of that are available between $start and $end
///
////////////////////////////////////////////////////////////////////////////////
function getAvailableBlockComputerids($imageid, $start, $end, $allocatedcompids) {
	global $user;
	$data = array('compids' => array());
	$groupids = implode(',', array_keys($user['groups']));
	if(! count($user['groups']))
		$groupids = "''";
	$startdt = unixToDatetime($start);
	$enddt = unixToDatetime($end);
	$alloccompids = implode(",", $allocatedcompids);
	$query = "SELECT c.computerid, "
	       .        "t.start, "
	       .        "t.end, "
	       .        "r.id AS blockid "
	       . "FROM blockComputers c, "
	       .      "blockRequest r, "
	       .      "blockTimes t, "
	       .      "state s, "
	       .      "computer c2 "
	       . "WHERE r.groupid IN ($groupids) AND "
	       .       "r.status = 'accepted' AND "
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
		$data['compids'][] = $row['computerid'];
		$data[$row['computerid']] = $row;
	}
	return $data;
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
/// allocations during the given times
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
/// \fn getNAThosts($id=0, $sort=0)
///
/// \param $id - (optional) only get info for this NAT host
/// \param $sort - (optional) 1 to sort; 0 not to
///
/// \return an array with info about the NAT hosts; each element's index is the
/// id from the table; each element has the following items\n
/// \b hostname\n
/// \b publicIPaddress - IP to which users will connect
///
/// \brief builds an array of NAT hosts
///
////////////////////////////////////////////////////////////////////////////////
function getNAThosts($id=0, $sort=0) {
	$nathosts = array();
	$query = "SELECT n.id, "
	       .        "n.publicIPaddress, "
	       .        "COALESCE(c.hostname, m.hostname) AS hostname "
	       . "FROM nathost n "
	       . "LEFT JOIN resource r ON (n.resourceid = r.id) "
	       . "LEFT JOIN resourcetype rt ON (r.resourcetypeid = rt.id) "
	       . "LEFT JOIN computer c ON (c.id = r.subid AND rt.name = 'computer') "
	       . "LEFT JOIN managementnode m ON (m.id = r.subid AND rt.name = 'managementnode') "
	       . "WHERE (c.deleted IS NULL OR c.deleted = 0) AND "
	       .       "(m.stateid IS NULL OR m.stateid != (SELECT id FROM state WHERE name = 'deleted'))";
	if($id)
		$query .= " WHERE n.id = $id";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh))
		$nathosts[$row['id']] = $row;
	if($sort)
		uasort($nathosts, "sortKeepIndex");
	return $nathosts;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getReservationNATports($resid)
///
/// \param $resid - id of a reservation
///
/// \return an array of arrays of NAT ports for $resid; the first level index
/// is the connectmethod id; the second level index is the key used for
/// substituting the port in the connectmethod text; each second level element
/// has the following items\n
/// \b publicport\n
/// \b connectmethodportid\n
/// \b privateport\n
/// \b protocol\n
/// \b connectmethodid
///
/// \brief builds an array of NAT port connection method data for a reservation
///
////////////////////////////////////////////////////////////////////////////////
function getNATports($resid) {
	$ports = array();
	$query = "SELECT n.publicport, "
	       .        "n.connectmethodportid, " 
	       .        "c.port AS privateport, " 
	       .        "c.protocol, "
	       .        "c.connectmethodid "
	       . "FROM natport n, "
	       .      "connectmethodport c "
	       . "WHERE n.connectmethodportid = c.id AND "
	       .       "n.reservationid = $resid";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh))
		$ports[$row['connectmethodid']]["#Port-{$row['protocol']}-{$row['privateport']}#"] = $row;
	return $ports;
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
/// \return an array of block allocation data where each index in a blockTime id
/// and the value is an array with these elements:\n
/// \b blockid - id of block allocation\n
/// \b name - name of block allocation\n
/// \b imageid - id of selected image\n
/// \b image - name of selected image\n
/// \b numMachines - number of machines allocated\n
/// \b groupid - user group associated with allocation\n
/// \b repeating - weekly, monthly, or list\n
/// \b ownerid - id from user table of the owner\n
/// \b managementnodeid - id of management node handling allocation\n
/// \b expireTime - time at which the allocation will be completely finished\n
/// \b timeid - id of blockTimes entry\n
/// \b start - dattime for starting time of block time\n
/// \b end - dattime for ending time of block time\n
/// \b unixstart - unix timestamp for starting time of block time\n
/// \b unixend - unix timestamp for ending time of block time\n
/// \b computerids - array of computer ids allocated for the block time
///
/// \brief builds an array of block allocation data
///
////////////////////////////////////////////////////////////////////////////////
function getBlockTimeData($start="", $end="") {
	$return = array();
	$query = "SELECT r.id AS blockid, "
	       .        "r.name, "
	       .        "r.imageid, "
	       .        "i.prettyname AS image, "
	       .        "r.numMachines, "
	       .        "r.groupid, "
	       .        "r.repeating, "
	       .        "r.ownerid, "
	       .        "r.managementnodeid, "
	       .        "r.expireTime, "
	       .        "t.id AS timeid, "
	       .        "t.start, "
	       .        "t.end "
	       . "FROM blockRequest r, "
	       .      "blockTimes t, "
	       .      "image i "
	       . "WHERE r.id = t.blockRequestid AND "
	       .       "r.status = 'accepted' AND "
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
/// \fn isBlockAllocationTime($compid, $ts, $blockData)
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
function isBlockAllocationTime($compid, $ts, $blockData) {
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
/// \fn isImageBlockTimeActive($imageid)
///
/// \param $imageid - id of an image
///
/// \return 1 if a block time for a block allocation for $imageid has had the
/// processed flag set and the end time has not been reached; 0 otherwise
///
/// \brief checks to see if a block time for $imageid has been processed but not
/// yet ended
///
////////////////////////////////////////////////////////////////////////////////
function isImageBlockTimeActive($imageid) {
	$now = time();
	$nowdt = unixToDatetime($now);
	$query = "SELECT bt.id "
	       . "FROM blockTimes bt, "
	       .      "blockRequest br "
	       . "WHERE bt.blockRequestid = br.id AND "
	       .       "bt.processed = 1 AND "
	       .       "bt.end > '$nowdt' AND "
	       .       "br.imageid = $imageid";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		return 1;
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
/// as $dataArr so we know to skip the 'No Image" element
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
	print selectInputHTML($name, $dataArr, $domid, $extra, $selectedid, $skip,
	                      $multiple);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectInputAutoDijitHTML($name, $dataArr, $domid='', $extra='',
///                              $selectedid=-1) {
///
/// \param $name - name of input element
/// \param $dataArr - array containing options
/// \param $domid - (optional) use this to pass in the javascript id to be used
/// for the select object
/// \param $extra - (optional) any extra attributes that need to be set
/// \param $selectedid - (optional) index of $dataArr to be initially selected;
/// use -1 for nothing to be selected
///
/// \return html
///
/// \brief wrapper for calling selectInputHTML with the resulting element
/// being a dijit.form.Select if number of items is <= 10 and being a
/// dijit.form.FilteringSelect if number of items is > 10
///
////////////////////////////////////////////////////////////////////////////////
function selectInputAutoDijitHTML($name, $dataArr, $domid='', $extra='',
                                  $selectedid=-1) {
	if(count($dataArr) > 10 &&
	   USEFILTERINGSELECT && count($dataArr) < FILTERINGSELECTTHRESHOLD)
		$type = 'dojoType="dijit.form.FilteringSelect" queryExpr="*${0}*"';
	else
		$type = 'dojoType="dijit.form.Select" maxHeight="250"';
	return selectInputHTML($name, $dataArr, $domid, "$type $extra", $selectedid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectInputHTML($name, $dataArr, $domid, $extra, $selectedid, $skip,
///                     $multiple)
///
/// \param $name - name of input element
/// \param $dataArr - array containing options
/// \param $domid - (optional) use this to pass in the javascript id to be used
/// for the select object
/// \param $extra - (optional) any extra attributes that need to be set
/// \param $selectedid - (optional) index of $dataArr to be initially selected;
/// use -1 for nothing to be selected
/// \param $skip - (optional) this is used if the array from getImages is passed
/// as $dataArr so we know to skip the 'No Image" element
/// \param $multiple - (optional) use this to print select input with the
/// multiple tag set
///
/// \brief generates HTML for select input
/// it is assumed that if $selectedid is left off, we assume $dataArr has no 
/// index '-1'\n
/// each OPTION's value is the index of that element of the array
///
////////////////////////////////////////////////////////////////////////////////
function selectInputHTML($name, $dataArr, $domid="", $extra="", $selectedid=-1,
                         $skip=0, $multiple=0) {
	$h = '';
	if(! empty($domid))
		$domid = "id=\"$domid\"";
	if($multiple)
		$multiple = "multiple";
	else
		$multiple = "";
	if($name != '')
		$h .= "      <select name=$name $multiple $domid $extra>\n";
	else
		$h .= "      <select $multiple $domid $extra>\n";
	foreach(array_keys($dataArr) as $id) {
		if(($dataArr[$id] != 0 && empty($dataArr[$id])))
			continue;
		if($id == $selectedid)
		   $h .= "        <option value=\"$id\" selected=\"selected\">";
		else
		   $h .= "        <option value=\"$id\">";
		if(is_array($dataArr[$id]) && array_key_exists("prettyname", $dataArr[$id]))
			$h .= $dataArr[$id]["prettyname"] . "</option>\n";
		elseif(is_array($dataArr[$id]) && array_key_exists("name", $dataArr[$id]))
			$h .= $dataArr[$id]["name"] . "</option>\n";
		elseif(is_array($dataArr[$id]) && array_key_exists("hostname", $dataArr[$id]))
			$h .= $dataArr[$id]["hostname"] . "</option>\n";
		else
			$h .= $dataArr[$id] . "</option>\n";
	}
	$h .= "      </select>\n";
	return $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn labeledFormItem($id, $label, $type, $constraints='', $required=1,
///                     $value='', $errmsg='', $validator='', $extra=array(),
///                     $width='', $help='', $addbr=1) {
///
/// \param $id - dom id of form element
/// \param $label - text for label of element
/// \param $type - type of element; one of: text, textarea, spinner, select,
/// selectonly, check (selectonly forces dijit.form.Select rather than
/// possibily being dijit.form.FilteringSelect based on number of elements)
/// \param $constraints - (optional, default='') constraints for element; if
/// a select element, the array of options
/// \param $required - (optional, default=1) whether or not the form element is
/// required
/// \param $value - (optional, default='') initial value of form element
/// \param $errmsg - (optional, default='') error message; only used for text
/// elements
/// \param $validator - (optional, default='') validation function; only used
/// for text elements
/// \param $extra - (optional, default=array()) array of additional attributes
/// to set for the element
/// \param $width - (optional, default varies per element) width of element;
/// must include units
/// \param $help - (optional, default='') text to display after the form
/// element
/// \param $addbr - (optional, default=1) add an html break tag after the
/// element
///
/// \return html
///
/// \brief generates HTML form element with a preceding label tag
///
////////////////////////////////////////////////////////////////////////////////
function labeledFormItem($id, $label, $type, $constraints='', $required=1,
                         $value='', $errmsg='', $validator='', $extra=array(),
                         $width='', $help='', $addbr=1) {
	if($extra == '')
		$extra = array();
	$h = '';
	if($required)
		$required = 'true';
	else
		$required = 'false';
	switch($type) {
		case 'text':
			if($width == '')
				$width = '300px';
			$h .= "<label for=\"$id\">$label:</label>\n";
			$h .= "<span class=\"labeledform\">\n";
			$h .= "<input type=\"text\" ";
			$h .=        "dojoType=\"dijit.form.ValidationTextBox\" ";
			$h .=        "required=\"$required\" ";
			if($constraints != '')
				$h .=     "regExp=\"$constraints\" ";
			if($errmsg != '')
				$h .=     "invalidMessage=\"$errmsg\" ";
			$h .=        "style=\"width: $width\" ";
			if($validator != '')
				$h .=     "validator=\"$validator\" ";
			if($value != '')
				$h .=     "value=\"$value\" ";
			foreach($extra as $key => $val)
				$h .=     "$key=\"$val\" ";
			$h .=        "id=\"$id\">";
			if($help != '')
				$h .= $help;
			$h .= "</span>";
			if($addbr)
				$h .= "<br>";
			$h .= "\n";
			break;
		case 'textarea':
			if($width == '')
				$width = '300px';
			$h .= "<label for=\"$id\">$label:</label>\n";
			$h .= "<span class=\"labeledform\">\n";
			$h .= "<textarea ";
			$h .=        "dojoType=\"dijit.form.Textarea\" ";
			$h .=        "style=\"width: $width; text-align: left;\" ";
			foreach($extra as $key => $val)
				$h .=     "$key=\"$val\" ";
			$h .=        "id=\"$id\">";
			$h .= $value;
			$h .= "</textarea>\n";
			if($help != '')
				$h .= $help;
			$h .= "</span>";
			if($addbr)
				$h .= "<br>";
			$h .= "\n";
			break;
		case 'spinner':
			if($width == '')
				$width = '70px';
			$h .= "<label for=\"$id\">$label:</label>\n";
			$h .= "<span class=\"labeledform\">\n";
			$h .= "<input dojoType=\"dijit.form.NumberSpinner\" ";
			$h .=        "required=\"$required\" ";
			$h .=        "style=\"width: $width\" ";
			if($value !== '')
				$h .=     "value=\"$value\" ";
			if($constraints != '')
				$h .=     "constraints=\"$constraints\" ";
			foreach($extra as $key => $val)
				$h .=     "$key=\"$val\" ";
			$h .=        "id=\"$id\">";
			if($help != '')
				$h .= $help;
			$h .= "</span>";
			if($addbr)
				$h .= "<br>";
			$h .= "\n";
			break;
		case 'select':
		case 'selectonly':
			if($value == '')
				$value = -1;
			$h .= "<label for=\"$id\">$label:</label>\n";
			$h .= "<span class=\"labeledform\">\n";
			$flat = '';
			foreach($extra as $key => $val)
				$flat .= "$key=\"$val\" ";
			if($type == 'selectonly')
				$h .= selectInputHTML('', $constraints, $id, "dojoType=\"dijit.form.Select\" maxHeight=\"250\" $flat", $value);
			else
				$h .= selectInputAutoDijitHTML('', $constraints, $id, $flat, $value);
			if($help != '')
				$h .= $help;
			$h .= "</span>";
			if($addbr)
				$h .= "<br>";
			$h .= "\n";
			break;
		case 'check':
			$h .= "<label for=\"$id\">$label:</label>\n";
			$h .= "<span class=\"labeledform\">\n";
			$h .= "<input dojoType=\"dijit.form.CheckBox\" ";
			if($value !== '')
				$h .=     "value=\"$value\" ";
			foreach($extra as $key => $val)
				$h .=     "$key=\"$val\" ";
			$h .=        "id=\"$id\">";
			if($help != '')
				$h .= $help;
			$h .= "</span>";
			if($addbr)
				$h .= "<br>";
			$h .= "\n";
			break;
	}
	return $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn dijitButton($id, $label, $onclick='', $wraprightdiv=0)
///
/// \param $id - dom id of button
/// \param $label - label for button
/// \param $onclick - javascript function to call when clicked including
/// parenthesis, arguments, and semicolon
/// \param $wraprightdiv - (optional, default=0) set to 1 to wrap button in
/// a div element set to right align text
///
/// \return html
///
/// \brief generates HTML for a dijit button
///
////////////////////////////////////////////////////////////////////////////////
function dijitButton($id, $label, $onclick='', $wraprightdiv=0) {
	$h = '';
	if($wraprightdiv)
		$h .= "<div style=\"text-align: right;\">\n";
	$h .= "<button dojoType=\"dijit.form.Button\" id=\"$id\">\n";
	$h .= "  $label\n";
	if($onclick != '') {
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    $onclick\n";
		$h .= "  </script>\n";
	}
	$h .= "</button>\n";
	if($wraprightdiv)
		$h .= "</div>\n";
	return $h;
}

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
	   ($request["currstateid"] == 29 &&      // request current state servermodified
	   $request["computerstateid"] == 8) ||   //   and computer state inuse
	   ($request["currstateid"] == 29 &&      // request current state servermodified
	   $request["computerstateid"] == 3) ||   //   and computer state reserved
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
/// \fn prettyDatetime($stamp, $showyear=0)
///
/// \param $stamp - a timestamp in unix or mysql datetime format
/// \param $showyear (optional, default=0) - set to 1 to include year
///
/// \return date/time in html format of [Day of week], [month] [day of month],
/// [HH:MM] [am/pm]
///
/// \brief reformats the datetime to look better
///
////////////////////////////////////////////////////////////////////////////////
function prettyDatetime($stamp, $showyear=0) {
	global $locale;
	if(! preg_match('/^[\d]+$/', $stamp))
		$stamp = datetimeToUnix($stamp);
	if($showyear)
		$return = strftime('%A, %b&nbsp;%-d,&nbsp;%Y, %l:%M %P', $stamp);
	else
		$return = strftime('%A, %b&nbsp;%-d, %l:%M %P', $stamp);
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
		return $min . " " . i("minutes");
	elseif($min == 60)
		return i("1 hour");
	elseif($min % 60 == 0)
		return sprintf("%d " . i("hours"), $min / 60);
	elseif($min % 30 == 0)
		return sprintf("%.1f " . i("hours"), $min / 60);
	else
		return sprintf("%.2f " . i("hours"), $min / 60);
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
		return (int)$minutes . " " . i("minutes");
	elseif($minutes == 60)
		return i("1 hour");
	elseif($minutes % 60 == 0)
		return $minutes / 60 . " " . i("hours");
	else {
		$hours = (int)($minutes / 60);
		$min = (int)($minutes % 60);
		if($hours == 1)
			return "$hours " . i("hour") . ", $min " . i("minutes");
		else
			return "$hours " . i("hours") . ", $min " . i("minutes");
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
/// \fn checkInMaintenanceForTimeTable($start, $end, $items)
///
/// \param $start - start time in unix timestamp format
/// \param $end - end time in unix timestamp format
/// \param $items - list of maintenance items as returned by
///                 getMaintItemsForTimeTable
///
/// \return 1 if specified time period falls in an maintenance window, 0 if not
///
/// \brief checks if the specified time period overlaps with a scheduled
/// maintenance window
///
////////////////////////////////////////////////////////////////////////////////
function checkInMaintenanceForTimeTable($start, $end, $items) {
	foreach($items as $item) {
		if($item['start'] < $end && $item['end'] > $start)
			return 1;
	}
	return 0;
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
			checkUpdateServerRequestGroups($id);
		}
	}
	return $newusergroups;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserGroupID($name, $affilid, $noadd)
///
/// \param $name - a group name
/// \param $affilid - (optional, defaults to DEFAULT_AFFILID) affiliation id
/// for $name
/// \param $noadd - (optional, defaults to 0) set to 1 to return NULL if group
/// does not exist instead of adding it to table
///
/// \return id for $name from group table
///
/// \brief looks up the id for $name in the group table; if the name is
/// not currently in the table, adds it and returns the new id
///
////////////////////////////////////////////////////////////////////////////////
function getUserGroupID($name, $affilid=DEFAULT_AFFILID, $noadd=0) {
	$query = "SELECT id "
	       . "FROM usergroup "
	       . "WHERE name = '$name' AND "
	       .       "affiliationid = $affilid";
	$qh = doQuery($query, 300);
	if($row = mysql_fetch_row($qh))
		return $row[0];
	elseif($noadd)
		return NULL;
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
/// \fn checkUpdateServerRequestGroups($groupid)
///
/// \param $groupid = id of a user group
///
/// \brief checks for any server requests with an admin or login group of
/// $groupid; if any exist, set request stateid to servermodified
///
////////////////////////////////////////////////////////////////////////////////
function checkUpdateServerRequestGroups($groupid) {
	$query = "UPDATE request "
	       . "SET stateid = 29 "
	       . "WHERE stateid IN (3, 7, 8, 14, 16, 24, 25, 26, 27, 28) AND "
	       .       "id IN "
	       .   "(SELECT requestid "
	       .   "FROM serverrequest "
	       .   "WHERE admingroupid = $groupid OR "
	       .         "logingroupid = $groupid)";
	doQuery($query, 101);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMaintItems($id)
///
/// \param $id (optional) - if specified, id of maintenance item to get info
///                         about
///
/// \return array of maintenance items where each id is a maintenance id and
/// each element is an array with these keys:\n
/// \b id - id of maintenance item\n
/// \b start - start of maintenance item (datetime)\n
/// \b end - end of maintenance item (datetime)\n
/// \b ownerid - id from user table of owner of this maintenance item\n
/// \b owner - unityid@affiliation of owner\n
/// \b created - date/time entry was created (or last modified)\n
/// \b reason - reason viewable by sysadmins for maintenance item\n
/// \b usermessage - message viewable by all users for maintenance item\n
/// \b informhoursahead - number of hours before start that a message will be
///    displayed to all site users about the upcoming maintenance\n
/// \b allowreservations - whether or not reservations can extend into this
///    maintenance window (0 or 1)
///
/// \brief builds a list of current maintenance items and returns them
///
////////////////////////////////////////////////////////////////////////////////
function getMaintItems($id=0) {
	$key = getKey(array('getMaintItems', $id));
	if(isset($_SESSION) && array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	$query = "SELECT m.id, "
	       .        "m.start, "
	       .        "m.end, "
	       .        "m.ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "m.created, "
	       .        "m.reason, "
	       .        "m.usermessage, "
	       .        "m.informhoursahead, "
	       .        "m.allowreservations "
	       . "FROM sitemaintenance m, "
	       .      "user u, "
	       .      "affiliation a "
	       . "WHERE m.ownerid = u.id AND "
	       .       "u.affiliationid = a.id AND "
	       .       "m.end > NOW() ";
	if($id)
		$query .= "AND m.id = $id ";
	$query .= "ORDER BY m.start";
	$qh = doQuery($query, 101);
	$data = array();
	while($row = mysql_fetch_assoc($qh))
		$data[$row['id']] = $row;
	$_SESSION['usersessiondata'][$key] = $data;
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMaintItemsForTimeTable($start, $end)
///
/// \param $start - start time in unix timestamp format
/// \param $end - end time in unix timestamp format
///
/// \return array of maintenance items that overlap with $start and $end where
/// each item has 2 keys:\n
/// \b start - start time in unix timestamp format\n
/// \b end - end time in unix timestamp format
///
/// \brief builds a simple list of maintenance items and returns them
///
////////////////////////////////////////////////////////////////////////////////
function getMaintItemsForTimeTable($start, $end) {
	$key = getKey(array('getMaintItemsForTimeTable', $start, $end));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	$startdt = unixToDatetime($start);
	$enddt = unixToDatetime($end);
	$query = "SELECT UNIX_TIMESTAMP(start - INTERVAL 30 MINUTE) AS start, "
	       .        "UNIX_TIMESTAMP(end) AS end "
	       . "FROM sitemaintenance "
	       . "WHERE end > '$startdt' AND "
	       .       "start < '$enddt' "
	       . "ORDER BY start";
	$qh = doQuery($query, 101);
	$data = array();
	while($row = mysql_fetch_assoc($qh))
		$data[] = $row;
	$_SESSION['usersessiondata'][$key] = $data;
	return $data;
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
	$resid = getContinuationVar("resid");
	$request = getRequestInfo("$requestid");
	if($request['stateid'] == 11 || $request['stateid'] == 12 ||
	   ($request['stateid'] == 14 && 
	   ($request['laststateid'] == 11 || $request['laststateid'] == 12))) {
		$cont = addContinuationsEntry('viewRequests');
		header("Location: " . BASEURL . SCRIPT . "?continuation=$cont");
		return;
	}
	foreach($request["reservations"] as $res) {
		if($res['reservationid'] == $resid) {
			$ipaddress = $res["connectIP"];
			break;
		}
	}
	if(empty($ipaddress))
		return;
	$passwd = $request['passwds'][$resid][$user['id']];

	$connectData = getImageConnectMethodTexts($res['imageid'],
	                                          $res['imagerevisionid']);
	$natports = getNATports($resid);
	$port = '';
	foreach($connectData as $cmid => $method) {
		if(preg_match('/remote desktop/i', $method['description']) ||
		   preg_match('/RDP/i', $method['description'])) {
			# assume index 0 of ports for nat
			if(! empty($natports) && array_key_exists($method['ports'][0]['key'], $natports[$cmid]))
				$port = ':' . $natports[$cmid][$method['ports'][0]['key']]['publicport'];
			else {
				if($method['ports'][0]['key'] == '#Port-TCP-3389#' &&
				   $user['rdpport'] != 3389)
					$port = ':' . $user['rdpport'];
				else
					$port = ':' . $method['ports'][0]['port'];
			}
			break;
		}
	}

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
	if($request['serverrequest']) {
		if(count($request['reservations']) == 1)
			header("Content-Disposition: inline; filename=\"{$request['servername']}.rdp\"");
		else
			header("Content-Disposition: inline; filename=\"{$request['servername']}-{$res['prettyimage']}.rdp\"");
	}
	else
		header("Content-Disposition: inline; filename=\"{$res['prettyimage']}.rdp\"");
	print "screen mode id:i:$screenmode\r\n";
	print "desktopwidth:i:$width\r\n";
	print "desktopheight:i:$height\r\n";
	print "session bpp:i:$bpp\r\n";
	print "winposstr:s:0,1,382,71,1182,671\r\n";
	print "full address:s:$ipaddress$port\r\n";
	print "compression:i:1\r\n";
	print "keyboardhook:i:2\r\n";
	print "audiomode:i:$audiomode\r\n";
	print "redirectdrives:i:$redirectdrives\r\n";
	print "redirectprinters:i:$redirectprinters\r\n";
	print "redirectcomports:i:$redirectcomports\r\n";
	print "redirectsmartcards:i:1\r\n";
	print "displayconnectionbar:i:1\r\n";
	print "autoreconnection enabled:i:1\r\n";
	if($request["forimaging"] && $res['OStype'] == 'windows')
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
	       .        "({$user['id']}, "
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
		if($wasavailable != 0 && datetimeToUnix($log['start']) > time())
			array_push($query2Arr, "start = '$start'");
		$changed = 1;
	}
	else {
		$query1 .= "NULL, ";
	}

	# end
	if($end != NULL && $end != $log["initialend"]) {
		$query1 .= "'$end', ";
		if($wasavailable != 0) {
			if(datetimeToUnix($log["start"]) > time())
				array_push($query2Arr, "initialend = '$end'");
			array_push($query2Arr, "finalend = '$end'");
		}
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
/// \fn addChangeLogEntryOther($logid, $data)
///
/// \param $logid - id matching entry in log table
/// \param $data - data to be inserted in the other field
///
/// \brief adds an entry to the other field in the changelog table
///
////////////////////////////////////////////////////////////////////////////////
function addChangeLogEntryOther($logid, $data) {
	$data = mysql_real_escape_string($data);
	$query = "INSERT INTO changelog "
	       .        "(logid, "
	       .        "timestamp, "
	       .        "other) "
	       . "VALUES "
	       .        "($logid, "
	       .        "NOW(), "
	       .        "'$data')";
	doQuery($query);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addSublogEntry($logid, $imageid, $imagerevisionid, $computerid,
///                    $mgmtnodeid, $fromblock, $blockdata)
///
/// \param $logid - id of parent log entry
/// \param $imageid - id of requested image
/// \param $imagerevisionid - revision id of requested image
/// \param $computerid - assigned computer id
/// \param $mgmtnodeid - id of management node handling this reservation
/// \param $fromblock - boolean telling if this computer is from a block
/// allocation
/// \param $blockdata - if $fromblock is 1, this contains data about the block
/// allocation
///
/// \brief adds an entry to the log table
///
////////////////////////////////////////////////////////////////////////////////
function addSublogEntry($logid, $imageid, $imagerevisionid, $computerid,
                        $mgmtnodeid, $fromblock, $blockdata) {
	$query = "SELECT predictivemoduleid "
	       . "FROM computer "
	       . "WHERE id = $computerid";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	$predictiveid = $row['predictivemoduleid'];
	$query = "SELECT c.type, "
	       .        "v.computerid AS hostid "
	       . "FROM computer c "
	       . "LEFT JOIN vmhost v ON (c.vmhostid = v.id) "
	       . "WHERE c.id = $computerid";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	if($row['type'] == 'virtualmachine')
		$hostcomputerid = $row['hostid'];
	else
		$hostcomputerid = 'NULL';
	$query = "INSERT INTO sublog "
	       .        "(logid, "
	       .        "imageid, "
	       .        "imagerevisionid, "
	       .        "computerid, "
	       .        "managementnodeid, "
			 .        "predictivemoduleid, ";
	if($fromblock) {
		$query .=    "blockRequestid, "
		       .     "blockStart, "
		       .     "blockEnd, ";
	}
	$query .=       "hostcomputerid) "
	       . "VALUES "
	       .        "($logid, "
	       .        "$imageid, "
	       .        "$imagerevisionid, "
	       .        "$computerid, "
	       .        "$mgmtnodeid, "
	       .        "$predictiveid, ";
	if($fromblock) {
		$query .=    "{$blockdata['blockid']}, "
		       .     "'{$blockdata['start']}', "
		       .     "'{$blockdata['end']}', ";
	}
	$query .=       "$hostcomputerid)";
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
		while($row = mysql_fetch_assoc($qh))
			$types["resources"][$row["id"]] = $row["name"];
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
/// \fn getReservationLengths($max)
///
/// \param $max - max allowed length in seconds
///
/// \return array of lengths up to $max starting with 30 minutes, 1 hour, 
/// 2 hours, then increasing by 2 hours up to 47 hours, then 2 days, then 
/// increasing by 1 day; indexes are the duration in minutes
///
/// \brief generates an array of reservation lengths
///
////////////////////////////////////////////////////////////////////////////////
function getReservationLengths($max) {
	$lengths = array();
	if($max >= 30)
		$lengths["30"] = "30 " . i("minutes");
	if($max >= 45)
		$lengths["45"] = "45 " . i("minutes");
	if($max >= 60)
		$lengths["60"] = i("1 hour");
	for($i = 120; $i <= $max && $i < 2880; $i += 120)
		$lengths[$i] = $i / 60 . " " . i("hours");
	for($i = 2880; $i <= $max; $i += 1440)
		$lengths[$i] = $i / 1440 . " " . i("days");
	return $lengths;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getReservationLength($length)
///
/// \param $length - reservation length to convert (in minutes)
///
/// \return human readable reservation length
///
/// \brief converts minutes to "## minutes", "## hours", or "## days"
///
////////////////////////////////////////////////////////////////////////////////
function getReservationLength($length) {
	if($length < 60)
		return ($length % 60) - ($length % 60 % 15) . " " . i("minutes");
	if($length < 120)
		return i("1 hour");
	if($length < 2880)
		return intval($length / 60) . " " . i("hours");
	return intval($length / 1440) . " " . i("days");
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getReservationExtenstion($length)
///
/// \param $length - reservation extension length to convert (in minutes)
///
/// \return human readable reservation extension length
///
/// \brief converts minutes to "## minutes", "## hours", or "## days"
///
////////////////////////////////////////////////////////////////////////////////
function getReservationExtenstion($length) {
	if($length < 60)
		return ($length % 60) - ($length % 60 % 15) . " " . i("minutes");
	if($length < 75)
		return i("1 hour");
	if($length < 120) {
		$min = ($length % 60) - ($length % 60 % 15);
		return sprintf('%d:%02d ' . i('hours'), intval($length / 60), $min);
	}
	if($length < 2880)
		return intval($length / 60) . " " . i("hours");
	return intval($length / 1440) . " " . i("days");
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getReservationLengthCeiling($length)
///
/// \param $length - a length in minutes
///
/// \return a length in minutes
///
/// \brief gets nearest, higher length that would be in array returned by
/// getReservationLengths
///
////////////////////////////////////////////////////////////////////////////////
function getReservationLengthCeiling($length) {
	if($length < 30)
		return 30;
	if($length < 45)
		return 45;
	if($length < 60)
		return 60;
	if($length < 2880) {
		for($i = 120; $i < 2880; $i += 120) {
			if($length < $i)
				return $i;
		}
	}
	for($i = 2880; $i <= 64800; $i += 1440) {
		if($length < $i)
			return $i;
	}
	return 64800;
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
function getResourceGroupID($groupname) {
	list($type, $name) = explode('/', $groupname);
	$type = mysql_real_escape_string($type);
	$name = mysql_real_escape_string($name);
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
/// \fn getResourceGroupName($groupid)
///
/// \param $groupid - resource group id
///
/// \return name of the group
///
/// \brief gets the name of a resource group from the resourcegroup table for
/// $id
///
////////////////////////////////////////////////////////////////////////////////
function getResourceGroupName($groupid) {
	$query = "SELECT name "
	       . "FROM resourcegroup "
	       . "WHERE id = $groupid";
	$qh = doQuery($query);
	if($row = mysql_fetch_assoc($qh))
		return $row['name'];
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
	$name = mysql_real_escape_string($name);
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
/// \fn getResourcePrivs()
///
/// \return an array of resource privileges
///
/// \brief gets the availabe resource privileges as defined in the resourcepriv
/// table
///
////////////////////////////////////////////////////////////////////////////////
function getResourcePrivs() {
	$query = "show columns from resourcepriv where field = 'type'";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	preg_match("/^enum\(([a-zA-Z0-9,']+)\)$/", $row['Type'], $matches);
	$tmp = str_replace("'", '', $matches[1]);
	return explode(',', $tmp);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getConfigTypes()
///
/// \return array of config types where each key is the id of the type and each
/// value is the prettyname of the type
///
/// \brief gets ids and names from configtype table
///
////////////////////////////////////////////////////////////////////////////////
function getConfigTypes() {
	$query = "SELECT id, prettyname FROM configtype ORDER BY name";
	$qh = doQuery($query);
	$types = array();
	while($row = mysql_fetch_assoc($qh))
		$types[$row['id']] = $row['prettyname'];
	return $types;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getConfigDataTypes()
///
/// \return array of config data types where each key is the id of the data type
/// and each value is the name of the data type
///
/// \brief gets ids and names from datatype table
///
////////////////////////////////////////////////////////////////////////////////
function getConfigDataTypes() {
	$query = "SELECT id, name FROM datatype ORDER BY name";
	$qh = doQuery($query);
	$types = array();
	while($row = mysql_fetch_assoc($qh))
		$types[$row['id']] = $row['name'];
	return $types;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getConfigMapTypes($skipreservation=0)
///
/// \param $skipreservation - (optional, default=0) pass 1 to skip the
/// 'reservation' config map type
///
/// \return array of config map types where each key is the id of the map type
/// and each value is the name of the map type
///
/// \brief gets ids and names from configmaptype table
///
////////////////////////////////////////////////////////////////////////////////
function getConfigMapTypes($skipreservation=0) {
	$query = "SELECT id, prettyname FROM configmaptype ";
	if($skipreservation)
		$query .= "WHERE name != 'reservation' ";
	$query .= "ORDER BY prettyname";
	$qh = doQuery($query);
	$types = array();
	while($row = mysql_fetch_assoc($qh))
		$types[$row['id']] = $row['prettyname'];
	return $types;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMappedConfigs($imageid)
///
/// \param $imageid - id of an image
///
/// \return array of configs
///
/// \brief generates an array of configs mapped to an image, including configs
/// mapped to any sub images
///
////////////////////////////////////////////////////////////////////////////////
function getMappedConfigs($imageid) {
	global $user;
	$imgdata = getImages(0, $imageid);
	$query = "SELECT cm.id, "
	       .        "cmt.prettyname AS configmaptype, "
	       .        "c.id AS configid, "
	       .        "c.name AS config, "
	       .        "c.data AS configdata, "
	       .        "c.ownerid, "
	       .        "CONCAT(u.unityid, '@', ua.name) AS owner, "
	       .        "c.configtypeid, "
	       .        "ct.prettyname AS configtype, "
	       .        "c.optional, "
	       .        "cm.configmaptypeid, "
	       .        "cm.subid, "
	       .        "cm.affiliationid, "
	       .        "a.name AS affiliation, "
	       .        "cm.configstageid, "
	       .        "cs.name AS configstage, "
	       .        "csi.imageid AS subimageid, "
	       .        "csi.id AS configsubimageid, "
	       .        "cm.disabled "
	       . "FROM configmap cm, "
	       .      "config c "
	       . "LEFT JOIN configsubimage csi ON (c.id = csi.configid), "
	       .      "user u, "
	       .      "affiliation ua, "
	       .      "configtype ct, "
	       .      "configmaptype cmt, " 
	       .      "affiliation a, "
	       .      "configstage cs "
	       . "WHERE cm.configid = c.id AND "
	       .       "c.ownerid = u.id AND "
	       .       "u.affiliationid = ua.id AND "
	       .       "c.configtypeid = ct.id AND "
	       .       "cm.configmaptypeid = cmt.id AND "
	       .       "cm.affiliationid = a.id AND "
	       .       "(cm.affiliationid = {$user['affiliationid']} OR "
	       .        "a.name = 'Global') AND "
	       .       "cm.configstageid = cs.id AND "
	       .       "((cmt.name = 'image' AND "
	       .         "cm.subid = $imageid) OR "
	       .        "(cmt.name = 'OStype' AND "
	       .         "cm.subid = {$imgdata[$imageid]['ostypeid']}) OR "
	       .        "(cmt.name = 'OS' AND "
	       .         "cm.subid = {$imgdata[$imageid]['osid']}))";
	$qh = doQuery($query);
	$configs = array();
	$configids = array();
	while($row = mysql_fetch_assoc($qh)) {
		$row['configmapid'] = $row['id'];
		if(is_null($row['subimageid']))
			$configids[] = $row['configid'];
		if($row['configtype'] == 'Cluster') {
			$row['id'] = "{$row['id']}-{$row['configsubimageid']}";
			$row['cluster'] = 1;
		}
		else
			$row['cluster'] = 0;
		$row['configdata'] = htmlspecialchars($row['configdata']);
		$row['optional'] = (int)$row['optional'];
		$row['applied'] = true;
		$row['disabled'] = (int)$row['disabled'];
		$row['id'] = "0/{$row['id']}";
		$configs[$row['id']] = $row;
		if($row['configtype'] == 'Cluster') {
			$subconfigs = getMappedSubConfigs(0, $row['configsubimageid'], $row['subimageid']);
			#printArray($subconfigs);
			#$configs = array_merge($configs, $subconfigs);
			$configs = $configs + $subconfigs;
		}
	}
	if(! empty($configids)) {
		$subconfigs = getMappedSubConfigs(1, $configids, 0);
		#printArray($subconfigs);
		#$configs = array_merge($configs, $subconfigs);
		$configs = $configs + $subconfigs;
	}
	return $configs;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getMappedSubConfigs($mode, $arg1, $arg2, $rec)
///
/// \param $mode - 0 for subimages, 1 for subconfigs
/// \param $arg1 - for subimages, config subimage id; for subconfigs, array of
/// configmap subids
/// \param $arg2 - for subimages, image id; for subconfigs, search id (TODO?)
/// \param $rec - always pass 0; used by function for recursive calls to itself
///
/// \return array of sub configs mapped to image
///
/// \brief generates array of configs mapped to sub images
///
////////////////////////////////////////////////////////////////////////////////
function getMappedSubConfigs($mode, $arg1, $arg2, $rec=0) {
	# $mode - 0: subimages, 1: subconfigs
	global $user;
	if($mode == 0) {
		$configsubimageid = $arg1;
		$imageid = $arg2;
		$imgdata = getImages(0, $imageid);
	}
	else {
		$inlist = implode(',', $arg1);
		$searchid = $arg2;
	}
	$query = "SELECT cm.id, "
	       .        "cmt.prettyname AS configmaptype, "
	       .        "c.id AS configid, "
	       .        "c.name AS config, "
	       .        "c.data AS configdata, "
	       .        "c.ownerid, "
	       .        "CONCAT(u.unityid, '@', ua.name) AS owner, "
	       .        "c.configtypeid, "
	       .        "ct.prettyname AS configtype, "
	       .        "c.optional, "
	       .        "cm.configmaptypeid, "
	       .        "cm.subid, "
	       .        "cm.affiliationid, "
	       .        "a.name AS affiliation, "
	       .        "cm.configstageid, "
	       .        "cs.name AS configstage, "
	       .        "csi.imageid AS subimageid, "
	       .        "csi.id AS configsubimageid, "
	       .        "cm.disabled "
	       . "FROM configmap cm, "
	       .      "config c "
	       . "LEFT JOIN configsubimage csi ON (c.id = csi.configid), "
	       .      "user u, "
	       .      "affiliation ua, "
	       .      "configtype ct, "
	       .      "configmaptype cmt, " 
	       .      "affiliation a, "
	       .      "configstage cs "
	       . "WHERE cm.configid = c.id AND "
	       .       "c.ownerid = u.id AND "
	       .       "u.affiliationid = ua.id AND "
	       .       "c.configtypeid = ct.id AND "
	       .       "cm.configmaptypeid = cmt.id AND "
	       .       "cm.affiliationid = a.id AND "
	       .       "(cm.affiliationid = {$user['affiliationid']} OR "
	       .        "a.name = 'Global') AND "
			 .       "cm.configstageid = cs.id AND ";
	if($mode) {
	$query .=      "cmt.name = 'config' AND "
	       .       " cm.subid IN ($inlist)";
	}
	else {
	$query .=      "((cmt.name = 'configsubimage' AND "
	       .       "  cm.subid = $configsubimageid) OR "
	       .       " (cmt.name = 'OStype' AND "
	       .       "  cm.subid = {$imgdata[$imageid]['ostypeid']}) OR "
	       .       " (cmt.name = 'OS' AND "
	       .       "  cm.subid = {$imgdata[$imageid]['osid']}))";
	}
	$qh = doQuery($query);
	$configs = array();
	$configids = array();
	while($row = mysql_fetch_assoc($qh)) {
		$row['configmapid'] = $row['id'];
		if(is_null($row['subimageid']))
			$configids[] = $row['configid'];
		if($row['configtype'] == 'Cluster') {
			$row['id'] = "{$row['id']}-{$row['configsubimageid']}";
			$row['cluster'] = 1;
		}
		else
			$row['cluster'] = 0;
		$row['configdata'] = htmlspecialchars($row['configdata']);
		$row['optional'] = (int)$row['optional'];
		$row['applied'] = true;
		$row['disabled'] = (int)$row['disabled'];
		if($mode == 0)
			$row['id'] = "$configsubimageid/{$row['id']}";
		else
			$row['id'] = "$searchid/{$row['id']}";
		$configs[$row['id']] = $row;
		if($rec < 20 && $row['configtype'] == 'Cluster') {
			$subconfigs = getMappedSubConfigs(0, $row['configsubimageid'], $row['subimageid'], ++$rec);
			$configs = $configs + $subconfigs;
		}
	}
	if($rec < 20 && ! empty($configids)) {
		if($mode == 0)
			$subconfigs = getMappedSubConfigs(1, $configids, $configsubimageid, ++$rec);
		else
			$subconfigs = getMappedSubConfigs(1, $configids, $searchid, ++$rec);
		$configs = $configs + $subconfigs;
	}
	return $configs;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getImageConfigVariables($configs)
///
/// \param $configs - array of configs
///
/// \return array of config variables for $configs
///
/// \brief builds array of config variables that corespond to $configs
///
////////////////////////////////////////////////////////////////////////////////
function getImageConfigVariables($configs) {
	if(empty($configs))
		return array();
	$configids = array();
	foreach($configs as $config)
		$configids[] = $config['configid'];
	$inlist = implode(',', $configids);
	$query = "SELECT cv.id, "
	       .        "cv.name, "
	       .        "cv.description, "
	       .        "cv.configid, "
	       .        "cv.`type`, "
	       .        "d.name AS datatype, "
	       .        "cv.datatypeid, "
	       .        "cv.defaultvalue, "
	       .        "cv.required, "
	       .        "cv.identifier, "
	       .        "cv.ask "
	       . "FROM configvariable cv, "
	       .      "datatype d "
	       . "WHERE cv.datatypeid = d.id AND "
	       .       "cv.configid IN ($inlist) "
	       . "ORDER BY cv.configid";
	$data = array();
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		$row['required'] = (int)$row['required'];
		$row['ask'] = (int)$row['ask'];
		#$row['defaultvalue'] = htmlspecialchars($row['defaultvalue']);
		$row['identifier'] = htmlspecialchars($row['identifier']);
		if(! array_key_exists($row['configid'], $data))
			$data[$row['configid']] = array();
		$data[$row['configid']][] = $row;
	}
	$vars = array();
	foreach($configs as $config) {
		if(array_key_exists($config['configid'], $data)) {
			foreach($data[$config['configid']] as $var) {
				$var['id'] = "{$config['id']}/{$var['id']}";
				$vars[$var['id']] = $var;
			}
		}
	}
	return $vars;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getConfigClusters($imageid, $flat=0)
///
/// \param $imageid - id of image
/// \param $flat - (optional, default=0) pass 1 to return a flat array instead
/// of a hierarchical array
///
/// \return array of cluster information
///
/// \brief builds an array of data of configs related to subimages assigned to
/// an image
///
////////////////////////////////////////////////////////////////////////////////
function getConfigClusters($imageid, $flat=0) {
	global $user;
	$query = "SELECT csi.id, "
	       .        "c.name, "
	       .        "cmt.name AS maptype, "
	       .        "cm.subid AS parentimageid, "
	       .        "csi.imageid AS childimageid, "
	       .        "csi.id AS configsubimageid, "
	       .        "i.prettyname AS image, "
	       .        "i.OSid AS osid, "
	       .        "ot.id AS ostypeid, "
	       .        "csi.mininstance, "
	       .        "csi.maxinstance "
	       . "FROM config c, "
	       .      "configtype ct, "
	       .      "configmap cm, "
	       .      "configmaptype cmt, "
	       .      "configsubimage csi, "
	       .      "image i, "
	       .      "OS o,  "
	       .      "OStype ot, "
	       .      "affiliation a "
	       . "WHERE ct.name = 'cluster' AND "
	       .       "c.configtypeid = ct.id AND "
	       .       "cm.configid = c.id AND "
	       .       "cm.configmaptypeid = cmt.id AND "
	       .       "cmt.name = 'image' AND "
	       .       "cm.subid = $imageid AND "
	       .       "csi.imageid = i.id AND "
	       .       "i.OSid = o.id AND "
	       .       "o.type = ot.name AND "
	       .       "csi.configid = c.id AND "
	       .       "cm.affiliationid = a.id AND "
	       .       "(cm.affiliationid = {$user['affiliationid']} OR "
	       .        "a.name = 'Global')";
	$qh = doQuery($query);
	$clusters = array();
	$subimageids = array();
	while($row = mysql_fetch_assoc($qh)) {
		$children = getConfigClustersRec($row['configsubimageid'], $flat);
		if(! empty($children)) {
			if($flat)
				$clusters = array_merge($clusters, $children);
			else
				$row['children'] = $children;
		}
		$clusters[] = $row;
	}
	return $clusters;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getConfigClustersRec($subimageid, $flat, $rec=0)
///
/// \param $subimageid - id of sub image
/// \param $flat - pass 1 to return a flat array instead of a hierarchical array
/// \param $rec - recursion count
///
/// \return array of cluster information
///
/// \brief recursive helper function for getConfigClusters
///
////////////////////////////////////////////////////////////////////////////////
function getConfigClustersRec($subimageid, $flat, $rec=0) {
	global $user;
	$query = "SELECT csi.id, "
	       .        "c.name, "
	       .        "cmt.name AS maptype, "
	       .        "cm.subid AS parentsubimageid, "
	       .        "csi.imageid AS childimageid, "
	       .        "csi.id AS configsubimageid, "
	       .        "i.prettyname AS image, "
	       .        "i.OSid AS osid, "
	       .        "ot.id AS ostypeid, "
	       .        "csi.mininstance, "
	       .        "csi.maxinstance "
	       . "FROM config c, "
	       .      "configtype ct, "
	       .      "configmap cm, "
	       .      "configmaptype cmt, "
	       .      "configsubimage csi, "
	       .      "image i, "
	       .      "OS o,  "
	       .      "OStype ot, "
	       .      "affiliation a "
	       . "WHERE ct.name = 'cluster' AND "
	       .       "c.configtypeid = ct.id AND "
	       .       "cm.configid = c.id AND "
	       .       "cm.configmaptypeid = cmt.id AND "
	       .       "cmt.name = 'configsubimage' AND "
	       .       "cm.subid = $subimageid AND "
	       .       "csi.imageid = i.id AND "
	       .       "i.OSid = o.id AND "
	       .       "o.type = ot.name AND "
	       .       "csi.configid = c.id AND "
	       .       "cm.affiliationid = a.id AND "
	       .       "(cm.affiliationid = {$user['affiliationid']} OR "
	       .        "a.name = 'Global')";
	$qh = doQuery($query);
	$clusters = array();
	while($row = mysql_fetch_assoc($qh)) {
		if($rec < 20)
			$children = getConfigClustersRec($row['configsubimageid'], $flat, ++$rec);
		if($rec < 20 && ! empty($children)) {
			if($flat)
				$clusters = array_merge($clusters, $children);
			else
				$row['children'] = $children;
		}
		$clusters[] = $row;
	}
	return $clusters;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getOStypes()
///
/// \return array of OS types where each key is the id of an OStype and each
/// value is the name
///
/// \brief gets data from the OStype table ordered by name
///
////////////////////////////////////////////////////////////////////////////////
function getOStypes() {
	$query = "SELECT id, name FROM OStype ORDER BY name";
	$qh = doQuery($query);
	$types = array();
	while($row = mysql_fetch_assoc($qh))
		$types[$row['id']] = $row['name'];
	return $types;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getConfigSubimages($configs)
///
/// \param $configs - array of configs
///
/// \return array of config subimages for $configs
///
/// \brief builds array of config information related to subimages of $configs
///
////////////////////////////////////////////////////////////////////////////////
function getConfigSubimages($configs) {
	if(empty($configs))
		return array();
	$inlist = implode(',', array_keys($configs));
	$query = "SELECT cs.id, "
	       .        "CONCAT(c.name, ' - ', i.prettyname) AS name "
	       . "FROM config c, "
	       .      "configtype ct, "
	       .      "configsubimage cs, "
	       .      "image i "
	       . "WHERE ct.name = 'cluster' AND "
	       .       "c.configtypeid = ct.id AND "
	       .       "cs.configid = c.id AND "
	       .       "cs.imageid = i.id AND "
	       .       "c.id IN ($inlist)";
	$configs = array();
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh))
		$configs[$row['id']] = $row['name'];
	return $configs;
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
	if(! array_key_exists('nodes', $cache))
		$cache['nodes'] = array();
	if(array_key_exists($nodeid, $cache['nodes']))
		return $cache['nodes'][$nodeid];
	$qh = doQuery("SELECT id, parent, name FROM privnode", 330);
	while($row = mysql_fetch_assoc($qh))
		$cache['nodes'][$row['id']] = $row;
	if(array_key_exists($nodeid, $cache['nodes']))
		return $cache['nodes'][$nodeid];
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getNodePath($nodeid)
///
/// \param $nodeid - an id from the privnode table
///
/// \return string containing node and all of its parents of the form:\n
/// VCL > node1 > node2 > node3
///
/// \brief gets the full path of a node
///
////////////////////////////////////////////////////////////////////////////////
function getNodePath($nodeid) {
	global $cache;
	getNodeInfo($nodeid);
	$path = '';
	do {
		$parent = $cache['nodes'][$nodeid]['parent'];
		if($path == '')
			$path = $cache['nodes'][$nodeid]['name'];
		else
			$path = "{$cache['nodes'][$nodeid]['name']} &gt; $path";
		$nodeid = $parent;
	} while($parent != DEFAULT_PRIVNODE);
	return $path;
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
			if(preg_match('/[0-9]-[0-9]/', $a['prettyname']) ||
			   preg_match('/\.edu$|\.com$|\.net$|\.org$/', $a['prettyname']) ||
			   preg_match('/[0-9]-[0-9]/', $b['prettyname']) ||
			   preg_match('/\.edu$|\.com$|\.net$|\.org$/', $b['prettyname']))
				return compareDashedNumbers($a["prettyname"], $b["prettyname"]);
			return strcasecmp($a["prettyname"], $b["prettyname"]);
		}
		elseif(array_key_exists("name", $a)) {
			if(preg_match('/[0-9]-[0-9]/', $a['name']) ||
			   preg_match('/\.edu$|\.com$|\.net$|\.org$/', $a['name']) ||
			   preg_match('/[0-9]-[0-9]/', $b['name']) ||
			   preg_match('/\.edu$|\.com$|\.net$|\.org$/', $b['name']))
				return compareDashedNumbers($a["name"], $b["name"]);
			return strcasecmp($a["name"], $b["name"]);
		}
		else
			return 0;
	}
	elseif(preg_match('/[0-9]-[0-9]/', $a) ||
	       preg_match('/\.edu$|\.com$|\.net$|\.org$/', $a) ||
	       preg_match('/[0-9]-[0-9]/', $b) ||
	       preg_match('/\.edu$|\.com$|\.net$|\.org$/', $b))
		return compareDashedNumbers($a, $b);

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
	$domain1 = implode('.', $tmp);
	$letters1 = preg_replace('([^a-zA-Z])', '', $h1);

	$tmp = explode('.', $b);
	$h2 = array_shift($tmp);
	$domain2 = implode('.', $tmp);
	$letters2 = preg_replace('([^a-zA-Z])', '', $h2);

	// if different domain names, return based on that
	/*$cmp = strcasecmp($domain1, $domain2);
	if($cmp) {
		return $cmp;
	}*/

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
///                        $resource1inlist, $resource2inlist)
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
/// \fn getConnectMethods($imageid)
///
/// \param $imageid - id of image for which to get available methods
///
/// \return an array of connect methods where the key is the id and the value is
/// an array with these items:\n
/// \b description - description of method\n
/// \b autoprovisioned - 0 or 1, whether or not the method can be automatically
/// provisioned by the backend
///
/// \brief get the available connection methods for a specific image
///
////////////////////////////////////////////////////////////////////////////////
function getConnectMethods($imageid) {
	$key = getKey(array('getConnectMethods', $imageid));
	if(array_key_exists($key, $_SESSION['usersessiondata']))
		return $_SESSION['usersessiondata'][$key];
	$query = "SELECT DISTINCT c.id, "
	       .        "c.description, "
	       .        "cm.autoprovisioned "
	       . "FROM connectmethod c, "
	       .      "connectmethodmap cm, "
	       .      "image i "
	       . "LEFT JOIN OS o ON (o.id = i.OSid) "
	       . "LEFT JOIN OStype ot ON (ot.name = o.type) "
	       . "WHERE i.id = $imageid AND "
	       .       "cm.connectmethodid = c.id AND "
	       .       "cm.autoprovisioned IS NOT NULL AND "
	       .       "(cm.OStypeid = ot.id OR "
	       .        "cm.OSid = o.id) "
	       . "ORDER BY c.description";
	$methods = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$methods[$row['id']] = $row;
	$_SESSION['usersessiondata'][$key] = $methods;
	return $methods;
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
	$comps = array();
	foreach($request['reservations'] as $res)
		$comps[] = $res['computerid'];
	$compids = implode(',', $comps);
	$res = array_shift($request["reservations"]);
	$query = "SELECT rq.start "
	       . "FROM reservation rs, "
	       .      "request rq "
	       . "WHERE rs.computerid IN ($compids) AND "
	       .       "rq.start >= '{$request['end']}' AND "
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
	return "<img alt=\"$text\" src=\"" . BASEURL . "/images/textimage.php?text=$text\">";
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
/// \fn cleanSemaphore()
///
/// \brief deletes any semaphore entries created by current instantiation of
/// this script
///
////////////////////////////////////////////////////////////////////////////////
function cleanSemaphore() {
	global $mysql_link_vcl, $uniqid;
	if(! is_resource($mysql_link_vcl) || ! get_resource_type($mysql_link_vcl) == 'mysql link')
		return;
	$query = "DELETE FROM semaphore "
	       . "WHERE procid = '$uniqid'";
	doQuery($query);
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
	return "if(dojo.byId('$objid')) {dojo.byId('$objid').$attrib = '$data';}; ";
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
/// \b profilename - name of profile\n
/// \b name - name of profile (so array can be passed to printSelectInput)\n
/// \b image - name of image used for this profile\n
/// \b imageid - id of image used for this profile\n
/// \b resourcepath\n
/// \b folderpath\n
/// \b repositorypath - share exported by nas to the vmhost\n
/// \b datastorepath - path to where vm data files are stored\n
/// \b vmpath - path to where vm configuration files are stored\n
/// \b virtualswitch0 - name of first virtual switch\n
/// \b virtualswitch1 - name of second virtual switch\n
/// \b vmdisk - "dedicated" or "shared" - whether or not vm files are
/// stored on local disk or network attached storage\n
/// \b username - username associated with this profile\n
/// \b password - password associated with this profile\n
/// \b eth0generated - boolean telling if the MAC address for eth0 should be
/// autogenerated\n
/// \b eth1generated - boolean telling if the MAC address for eth1 should be
/// autogenerated
///
/// \brief gets information about vm profiles and returns it as an array
///
////////////////////////////////////////////////////////////////////////////////
function getVMProfiles($id="") {
	$query = "SELECT vp.id, "
	       .        "vp.profilename, "
	       .        "vp.profilename AS name, "
	       .        "i.prettyname AS image, "
	       .        "vp.imageid, "
	       .        "vp.resourcepath, "
	       .        "vp.folderpath, "
	       .        "vp.repositorypath, "
	       .        "vp.repositoryimagetypeid, "
	       .        "t1.name AS repositoryimagetype, "
	       .        "vp.datastorepath, "
	       .        "vp.datastoreimagetypeid, "
	       .        "t2.name AS datastoreimagetype, "
	       .        "vp.vmpath, "
	       .        "vp.virtualswitch0, "
	       .        "vp.virtualswitch1, "
	       .        "vp.virtualswitch2, "
	       .        "vp.virtualswitch3, "
	       .        "vp.vmdisk, "
	       .        "vp.username, "
	       .        "vp.password, "
	       .        "vp.rsakey, "
	       .        "vp.rsapub, "
	       .        "vp.eth0generated, "
	       .        "vp.eth1generated "
	       . "FROM vmprofile vp "
	       . "LEFT JOIN image i ON (vp.imageid = i.id) "
	       . "LEFT JOIN imagetype t1 ON (vp.repositoryimagetypeid = t1.id) "
	       . "LEFT JOIN imagetype t2 ON (vp.datastoreimagetypeid = t2.id)";
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
/// \fn getENUMvalues($table, $field)
///
/// \param $table - name of a table from the database
/// \param $field - field in $table
///
/// \return array of valid values for $table.$field
///
/// \brief gets valid values for $table.$field
///
////////////////////////////////////////////////////////////////////////////////
function getENUMvalues($table, $field) {
	$query = "DESC $table";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		if($row['Field'] == "$field") {
			$data = preg_replace(array('/^enum\(/', "/'/", '/\)$/'), array('', '', ''), $row['Type']);
			$types = explode(',', $data);
			return $types;
		}
	}
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
	if(array_key_exists('HTTP_USER_AGENT', $_SERVER))
		$contid = md5($mode . $nextmode . $serdata . $user['id'] . $_SERVER['REMOTE_ADDR'] . $_SERVER['HTTP_USER_AGENT']);
	else
		$contid = md5($mode . $nextmode . $serdata . $user['id'] . $_SERVER['REMOTE_ADDR']);
	$serdata = mysql_real_escape_string($serdata);
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
	global $user, $continuationid, $noHTMLwrappers;
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
		$rt = array('error' => 'expired');
		if(in_array($row['tomode'], $noHTMLwrappers))
			$rt['noHTMLwrappers'] = 1;
		else
			$rt['noHTMLwrappers'] = 0;
		return $rt;
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
	if(! array_key_exists('noHTMLwrappers', $contdata) ||
		$contdata['noHTMLwrappers'] == 0) {
		if(empty($HTMLheader))
			printHTMLHeader();
		if(! $printedHTMLheader) {
			$printedHTMLheader = 1;
			print $HTMLheader;
		}
	}
	if(array_key_exists('error', $contdata)) {
		print "<!-- continuationserror -->\n";
		print "<div id=\"continuationserrormessage\">\n";
		$subj = rawurlencode(i("Problem With VCL"));
		$href = "<a href=\"mailto:" . HELPEMAIL . "?Subject=$subj\">" . HELPEMAIL . "</a>";
		switch($contdata['error']) {
		case 'invalid input':
			print "<h2>" . i("Error: Invalid Input") . "</h2><br>\n";
			printf(i("You submitted input invalid for this web site. If you have no idea why this happened and the problem persists, please email %s for further assistance. Please include the steps you took that led up to this problem in your email message."), $href);
			break;
		case 'continuation does not exist':
		case 'expired':
			print "<h2>" . i("Error: Invalid Input") . "</h2><br>\n";
			print i("You submitted expired data to this web site. Please restart the steps you were following without using your browser's <strong>Back</strong> button.");
			break;
		default:
			print "<h2>" . i("Error: Invalid Input") . "</h2><br>\n";
			printf(i("An error has occurred. If this problem persists, please email %s for further assistance. Please include the steps you took that led up to this problem in your email message."), $href);
		}
		print "</div>\n";
	}
	if(! array_key_exists('noHTMLwrappers', $contdata) ||
		$contdata['noHTMLwrappers'] == 0)
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
/// \fn getVariable($key, $default, $incparams=0)
///
/// \param $key - name in variable table
/// \param $default - (optional, default=NULL) value to return if $key not found
/// \param $incparams - (optional, default=0) return only value or return array
/// that includes additional variable parameters
///
/// \return value from variable table; $default if $key not found in table; if
/// $incparams is 1, returns array with these keys:\n
/// \b value - variable value\n
/// \b serialization - encoding used to store variable\n
/// \b setby - what last set the variable\n
/// \b timestamp - when variable was last set
///
/// \brief gets data from the variable table for $key
///
////////////////////////////////////////////////////////////////////////////////
function getVariable($key, $default=NULL, $incparams=0) {
	if(array_key_exists($key, $_SESSION['variables']))
		return $_SESSION['variables'][$key];
	$query = "SELECT serialization, ";
	if($incparams)
		$query .=    "setby, "
	       .        "timestamp, ";
	$query .=       "value ";
	$query .= "FROM variable "
	       .  "WHERE name = '$key'";
	$qh = doQuery($query);
	if($row = mysql_fetch_assoc($qh)) {
		if($incparams) {
			switch($row['serialization']) {
				case 'yaml':
					$row['value'] = Spyc::YAMLLoad($row['value']);
					break;
				case 'phpserialize':
					$row['value'] = unserialize($row['value']);
					break;
			}
			return $row;
		}
		else {
			switch($row['serialization']) {
				case 'none':
					return $row['value'];
				case 'yaml':
					return Spyc::YAMLLoad($row['value']);
				case 'phpserialize':
					return unserialize($row['value']);
			}
		}
	}
	elseif(! $incparams)
		return $default;
	return array('value' => $default,
	             'serialization' => 'none',
	             'setby' => 'none',
	             'timestamp' => NULL);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getVariablesRegex($pattern)
///
/// \param $pattern - pattern to match in variable table
///
/// \return array of values from variable table
///
/// \brief gets data from the variable table for $pattern matches 'name' from 
/// table
///
////////////////////////////////////////////////////////////////////////////////
function getVariablesRegex($pattern) {
	$query = "SELECT name, "
	       .        "serialization, "
	       .        "value "
	       . "FROM variable "
	       . "WHERE name REGEXP '$pattern'";
	$qh = doQuery($query);
	$ret = array();
	while($row = mysql_fetch_assoc($qh)) {
		switch($row['serialization']) {
			case 'none':
				$ret[$row['name']] = $row['value'];
				break;
			case 'yaml':
				$ret[$row['name']] = Spyc::YAMLLoad($row['value']);
				break;
			case 'phpserialize':
				$ret[$row['name']] = unserialize($row['value']);
				break;
		}
	}
	return $ret;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn setVariable($key, $data, $serialization)
///
/// \param $key - name in variable table
/// \param $data - data to save in variable table
/// \param $serialization - (optional, default=phpserialize) type of
/// serialization to use - none, yaml, or phpserialize
///
/// \brief sets data in the variable table for $key; if entry is already in
/// variable table and $serialization is not passed in, uses existing
/// serialization; if entry is already in variable table and $serialization is
/// passed in, uses $serialization; if entry is not already in variable table,
/// uses $serialization for serialization with a default of phpserialize
///
////////////////////////////////////////////////////////////////////////////////
function setVariable($key, $data, $serialization='') {
	$update = 0;
	$query = "SELECT serialization FROM variable WHERE name = '$key'";
	$qh = doQuery($query);
	if($row = mysql_fetch_assoc($qh)) {
		if($serialization == '')
			$serialization = $row['serialization'];
		$update = 1;
	}
	elseif($serialization == '')
		$serialization = 'phpserialize';
	$_SESSION['variables'][$key] = $data;
	switch($serialization) {
		case 'none':
			$qdata = mysql_real_escape_string($data);
			break;
		case 'yaml':
			$yaml = Spyc::YAMLDump($data);
			$qdata = mysql_real_escape_string($yaml);
			break;
		case 'phpserialize':
			$qdata = mysql_real_escape_string(serialize($data));
			break;
	}
	if($update)
		$query = "UPDATE variable "
		       . "SET value = '$qdata', " 
		       .     "serialization = '$serialization', "
		       .     "setby = 'webcode', "
		       .     "timestamp = NOW() "
		       . "WHERE name = '$key'";
	else
		$query = "INSERT INTO variable "
		       .        "(name, "
		       .        "serialization, "
		       .        "value, "
		       .        "setby, "
		       .        "timestamp) "
		       . "VALUES "
		       .        "('$key', "
		       .        "'$serialization', "
		       .        "'$qdata', "
		       .        "'webcode', "
		       .        "NOW())";
	doQuery($query);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deleteVariable($key)
///
/// \param $key - name in variable table
///
/// \brief deletes a record from the variable table having name $key
///
////////////////////////////////////////////////////////////////////////////////
function deleteVariable($key) {
	if(array_key_exists($key, $_SESSION['variables']))
		unset($_SESSION['variables'][$key]);
	$query = "DELETE FROM variable WHERE name = '$key'";
	doQuery($query);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn validateIPv4addr($ip)
///
/// \param $ip - an ip address
///
/// \return 1 if $ip is valid, 0 if not
///
/// \brief validates that $ip is a valid address
///
////////////////////////////////////////////////////////////////////////////////
function validateIPv4addr($ip) {
	$arr = explode('.', $ip);
	if($arr[0] == 0)
		return 0;
	$regip1 = "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)";
	$regip4 = "$regip1\.$regip1\.$regip1\.$regip1";
	return preg_match("/^$regip4$/", $ip);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn validateEmailAddress($addr)
///
/// \param $addr - an email address
///
/// \return 1 if $addr is valid, 0 if not
///
/// \brief validates that $addr is a valid email address using a regex
///
////////////////////////////////////////////////////////////////////////////////
function validateEmailAddress($addr) {
	return preg_match('/[a-z0-9!#$%&\'*+\/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&\'*+\/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?/', $addr);
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
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddRequestWithEnding", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetRequestStatus", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetRequestConnectData", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCextendRequest", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCsetRequestEnding", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCendRequest", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetRequestIds", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCblockAllocation", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCprocessBlockTime", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddUserGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetUserGroupAttributes", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCdeleteUserGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCeditUserGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetUserGroupMembers", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddUsersToGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCremoveUsersFromGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCautoCapture", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCdeployServer", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetNodes", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddNode", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCremoveNode", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCnodeExists", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddResourceGroupPriv", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCremoveResourceGroupPriv", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetResourceGroupPrivs", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddUserGroupPriv", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCremoveUserGroupPriv", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetUserGroupPrivs", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddResourceGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetResourceGroups", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCremoveResourceGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetUserGroups", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCremoveUserGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddImageToGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCremoveImageFromGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCgetGroupImages", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCaddImageGroupToComputerGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCremoveImageGroupFromComputerGroup", "xmlRPChandler");
	xmlrpc_server_register_method($xmlrpc_handle, "XMLRPCfinishBaseImageCapture", "xmlRPChandler");

	print xmlrpc_server_call_method($xmlrpc_handle, $HTTP_RAW_POST_DATA, '');
	xmlrpc_server_destroy($xmlrpc_handle);
	cleanSemaphore();
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
	else
		$keyid = $user['id'];
	if(function_exists($function)) {
		if(! defined('XMLRPCLOGGING') || XMLRPCLOGGING != 0) {
			$saveargs = mysql_real_escape_string(serialize($args));
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
	}
	else {
		printXMLRPCerror(2);
		dbDisconnect();
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
	if(ONLINEDEBUG && checkUserHasPerm('View Debug Information')) {
		$msg = '';
		if($errcode >= 100 && $errcode < 400) {
			$msg .= "ERROR (" . mysql_errno($mysql_link_vcl) . ") - ";
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
	cleanSemaphore();
	dbDisconnect();
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
	print "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?" . ">\n"; # splitting the ? and > makes vim syntax highlighting work correctly
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
/// \fn validateAPIgroupInput($items, $exists)
///
/// \param $items - array of data to validate; the following items can be
/// validated, if 'custom' is included and is 0, owner and managingGroup are
/// not validated:\n
/// \b name - if specified, affiliation must also be specified\n
/// \b affiliation - if specified, name must also be specified\n
/// \b owner \n
/// \b managingGroup \n
/// \b initialMaxTime \n
/// \b totalMaxTime \n
/// \b maxExtendTime
/// \param $exists - 1 to check if $name\@$affiliation exists, 0 to check that
///                  it does not exist
///
/// \return an array to be returned as an error status or $items with these
/// extra keys:\n
/// \b status - "success"\n
/// \b managingGroupID - (if managingGroup in $items) id of managingGroup
/// \b managingGroupName - (if managingGroup in $items) name of managingGroup
/// \b managingGroupAffilid - (if managingGroup in $items) affiliation id of
///                           managingGroup
/// \b affiliationid - (if affiliation in $items) affiliation id
///
/// \brief validates data in $items
///
////////////////////////////////////////////////////////////////////////////////
function validateAPIgroupInput($items, $exists) {
	$custom = 1;
	if(array_key_exists('custom', $items))
		$custom = $items['custom'];
	# initialMaxTime
	if(array_key_exists('initialMaxTime', $items)) {
		if(! is_numeric($items['initialMaxTime']) ||
		   $items['initialMaxTime'] < 1 ||
		   $items['initialMaxTime'] > 65535) {
			return array('status' => 'error',
			             'errorcode' => 21,
			             'errormsg' => 'submitted initialMaxTime is invalid');
		}
	}
	# totalMaxTime
	if(array_key_exists('totalMaxTime', $items)) {
		if(! is_numeric($items['totalMaxTime']) ||
		   $items['totalMaxTime'] < 1 ||
		   $items['totalMaxTime'] > 65535) {
			return array('status' => 'error',
			             'errorcode' => 22,
			             'errormsg' => 'submitted totalMaxTime is invalid');
		}
	}
	# maxExtendTime
	if(array_key_exists('maxExtendTime', $items)) {
		if(! is_numeric($items['maxExtendTime']) ||
		   $items['maxExtendTime'] < 1 ||
		   $items['maxExtendTime'] > 65535) {
			return array('status' => 'error',
			             'errorcode' => 23,
			             'errormsg' => 'submitted maxExtendTime is invalid');
		}
	}
	# affiliation
	if(array_key_exists('affiliation', $items)) {
		$affilid = getAffiliationID($items['affiliation']);
		if(is_null($affilid)) {
			return array('status' => 'error',
			             'errorcode' => 17,
			             'errormsg' => 'unknown affiliation');
		}
		$items['affiliationid'] = $affilid;
	}
	# name
	if(array_key_exists('name', $items)) {
		if(! preg_match('/^[-a-zA-Z0-9_\.: ]{3,30}$/', $items['name'])) {
			return array('status' => 'error',
			             'errorcode' => 19,
			             'errormsg' => 'Name must be between 3 and 30 characters '
			                         . 'and can only contain letters, numbers, and '
			                         . 'these characters: - _ . :');
		}
		$doesexist = checkForGroupName($items['name'], 'user', '', $affilid);
		if($exists && ! $doesexist) {
			return array('status' => 'error',
			             'errorcode' => 18,
			             'errormsg' => 'user group with submitted name and affiliation does not exist');
		}
		elseif(! $exists && $doesexist) {
			return array('status' => 'error',
			             'errorcode' => 27,
			             'errormsg' => 'existing user group with submitted name and affiliation');
		}
		elseif($exists && $doesexist) {
			$esc_name = mysql_real_escape_string($items['name']);
			$items['id'] = getUserGroupID($esc_name, $affilid);
		}
	}
	# owner
	if($custom && array_key_exists('owner', $items)) {
		if(! validateUserid($items['owner'])) {
			return array('status' => 'error',
			             'errorcode' => 20,
			             'errormsg' => 'submitted owner is invalid');
		}
	}
	# managingGroup
	if($custom && array_key_exists('managingGroup', $items)) {
		$parts = explode('@', $items['managingGroup']);
		if(count($parts) != 2) {
			return array('status' => 'error',
			             'errorcode' => 24,
			             'errormsg' => 'submitted managingGroup is invalid');
		}
		$mgaffilid = getAffiliationID($parts[1]);
		if(is_null($mgaffilid) ||
		   ! checkForGroupName($parts[0], 'user', '', $mgaffilid)) {
			return array('status' => 'error',
			             'errorcode' => 25,
			             'errormsg' => 'submitted managingGroup does not exist');
		}
		$items['managingGroupID'] = getUserGroupID($parts[0], $mgaffilid);
		$items['managingGroupName'] = $parts[0];
		$items['managingGroupAffilid'] = $mgaffilid;
	}
	$items['status'] = 'success';
	return $items;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn helpIcon($id)
///
/// \param $id - dom id for icon image
///
/// \brief returns HTML for a help icon with the dom id set to $id
///
////////////////////////////////////////////////////////////////////////////////
function helpIcon($id) {
	return "<img src=\"images/helpicon.png\" id=\"$id\" />";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn helpTooltip($id, $text, $width)
///
/// \param $id - dom id for Tooltip to connect to
/// \param $text - text of Tooltip
/// \param $width - (default=400) wrap text in a div with this width in pixels
///
/// \brief returns HTML for a dijit Tooltip
///
////////////////////////////////////////////////////////////////////////////////
function helpTooltip($id, $text, $width=400) {
	$h  = "<div dojoType=\"dijit.Tooltip\" connectId=\"$id\">\n";
	$h .= "<div style=\"max-width: {$width}px;\">\n";
	$h .= "$text\n</div>\n";
	$h .= "\n</div>\n";
	return $h;
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
/// \fn sendJSON($arr, $identifier='', $REST=0)
///
/// \param $arr - an array of data
/// \param $identifier - (optional, default='') set to non-empty string to have
/// $identifier printed as the identifier for a dojo datastore
/// \param $REST - (optional, default=0) pass 1 to strictly send json encoded
/// data with nothing wrapping it
///
/// \brief sets the content type and sends $arr in json format
///
////////////////////////////////////////////////////////////////////////////////
function sendJSON($arr, $identifier='', $REST=0) {
	#header('Content-Type: application/json; charset=utf-8');
	header('Content-Type: application/json');
	if($REST)
		print json_encode($arr);
	elseif(! empty($identifier))
		print "{} && {identifier: '$identifier', 'items':" . json_encode($arr) . '}';
	else
		print '{} && {"items":' . json_encode($arr) . '}';
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
	global $mode, $actions, $inContinuation;
	$mymode = $mode;
	if(empty($mymode))
		$mymode = "home";
	$testval = $actions['pages'][$mymode];
	if($inContinuation) {
		$obj = getContinuationVar('obj');
		if(! is_null($obj) && isset($obj->restype))
			$testval = $obj->restype;
	}
	if($testval == $page)
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
	global $mode, $user, $authed, $oldmode, $actionFunction;
	global $shibauthed;
	if(! $authed && $mode == "auth") {
		header("Location: " . BASEURL . SCRIPT . "?mode=selectauth");
		dbDisconnect();
		exit;
	}
	switch($mode) {
		case 'logout':
			if($shibauthed) {
				$shibdata = getShibauthData($shibauthed);
				// TODO make shib-logouturl comparison caseless
				if(array_key_exists('Shib-logouturl', $shibdata) &&
				   ! empty($shibdata['Shib-logouturl'])) {
					dbDisconnect();
					header("Location: {$shibdata['Shib-logouturl']}");
					exit;
				}
			}
		case 'shiblogout':
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
				if(array_key_exists('Shib-logouturl', $shibdata) &&
				   ! empty($shibdata['Shib-logouturl'])) {
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
					print "   </body>\n";
					print "</html>\n";
				}
				else {
					print "<html>\n";
					print "<head>\n";
					print "<META HTTP-EQUIV=REFRESH CONTENT=\"5;url=" . BASEURL . "\">\n";
					print "<style type=\"text/css\">\n";
					print "  .hidden {\n";
					print "    display: none;\n";
					print "  }\n";
					print "</style>\n";
					print "</head>\n";
					print "<body>\n";
					print "Logging out of VCL...";
					print "<iframe src=\"https://{$_SERVER['SERVER_NAME']}/Shibboleth.sso/Logout\" class=hidden>\n";
					print "</iframe>\n";
					if(array_key_exists('Shib-Identity-Provider', $shibdata) &&
					   ! empty($shibdata['Shib-Identity-Provider'])) {
						$tmp = explode('/', $shibdata['Shib-Identity-Provider']);
						$idp = "{$tmp[0]}//{$tmp[2]}";
						print "<iframe src=\"$idp/idp/logout.jsp\" class=hidden>\n";
						print "</iframe>\n";
					}
					print "</body>\n";
					print "</html>\n";
				}
				exit;
			}
			header("Location: " . HOMEURL);
			stopSession();
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
	if($mode == 'submitAddGroup' || $mode == 'submitEditGroup') {
		$data = getContinuationVar();
		if($data['type'] == 'resource') {
			if(! array_key_exists('ownergroup', $data))
				$data['ownergroup'] = processInputVar('ownergroup', ARG_NUMERIC, 0);
			$ownergroupids = explode(',', $data['ownergroupids']);
		   if(in_array($data['ownergroup'], $ownergroupids) &&
		      array_key_exists($data['ownergroup'], $user['groups'])) {
				$expire = time() + 31536000; //expire in 1 year
				setcookie("VCLOWNERGROUPID", $data['ownergroup'], $expire, "/", COOKIEDOMAIN);
			}
		}
		elseif($data['type'] == 'user') {
			if(! array_key_exists('editgroupid', $data))
				$data['editgroupid'] = processInputVar('editgroupid', ARG_NUMERIC, 0);
			$editgroupids = explode(',', $data['editgroupids']);
			if(in_array($data['editgroupid'], $editgroupids)) {
				$expire = time() + 31536000; //expire in 1 year
				setcookie("VCLEDITGROUPID", $data['editgroupid'], $expire, "/", COOKIEDOMAIN);
			}
		}
	}
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
	global $mode, $user, $authed, $oldmode, $HTMLheader, $contdata;
	global $printedHTMLheader, $docreaders, $noHTMLwrappers, $actions;
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
				   $requests[$i]["currstateid"] == 3 ||
				   ($requests[$i]["currstateid"] == 8 &&
				   ! $requests[$i]["useraccountready"]))) {
					$refresh = 1;
				}
			}
		}
	}

	if($mode != 'selectauth' && $mode != 'submitLogin')
		$HTMLheader .= getHeader($refresh);

	if(! in_array($mode, $noHTMLwrappers) &&
		(! is_array($contdata) ||
	    ! array_key_exists('noHTMLwrappers', $contdata) ||
	    $contdata['noHTMLwrappers'] == 0)) {
		print $HTMLheader;
		if($mode != 'inmaintenance')
			print maintenanceNotice();
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
	global $user, $docreaders, $authed, $mode;
	if($authed && $mode != 'expiredemouser') {
		$computermetadata = getUserComputerMetaData();
		$requests = getUserRequests("all", $user["id"]);
	}
	else
		$computermetadata = array("platforms" => array(),
		                          "schedules" => array());
	$rt = '';
	if($inchome) {
		$rt .= menulistLI('home');
		$rt .= "<a href=\"$homeurl\">" . i("HOME") . "</a></li>\n";
	}

	$rt .= menulistLI('reservations');
	$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=viewRequests\">";
	$rt .= i("Reservations") . "</a></li>\n";

	#$rt .= menulistLI('config');
	#$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=config\">";
	#$rt .= i("Manage Configs") . "</a></li>\n";

	$rt .= menulistLI('blockAllocations');
	$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=blockAllocations\">";
	$rt .= i("Block Allocations") . "</a></li>\n";
	$rt .= menulistLI('userPreferences');
	$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=userpreferences\">";
	$rt .= i("User Preferences") . "</a></li>\n";
	if(in_array("groupAdmin", $user["privileges"])) {
		$rt .= menulistLI('manageGroups');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=viewGroups\">";
		$rt .= i("Manage Groups") . "</a></li>\n";
	}
	if(in_array("imageAdmin", $user["privileges"])) {
		$rt .= menulistLI('image');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=image\">";
		$rt .= i("Manage Images") . "</a></li>\n";
	}
	if(in_array("scheduleAdmin", $user["privileges"])) {
		$rt .= menulistLI('schedule');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=schedule\">";
		$rt .= i("Manage Schedules") . "</a></li>\n";
	}
	if(in_array("computerAdmin", $user["privileges"])) {
		$rt .= menulistLI('computer');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=computer\">";
		$rt .= i("Manage Computers") . "</a></li>\n";
	}
	if(in_array("mgmtNodeAdmin", $user["privileges"])) {
		$rt .= menulistLI('managementnode');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=managementnode\">";
		$rt .= i("Management Nodes") . "</a></li>\n";
	}
	if(in_array("serverProfileAdmin", $user["privileges"]) ||
	   in_array("serverCheckOut", $user["privileges"])) {
		$rt .= menulistLI('serverProfiles');
		$rt .= "<a href=\"" . BASEURL . SCRIPT;
		$rt .= "?mode=serverProfiles\">" . i("Server Profiles") . "</a></li>\n";
	}
	if(count($computermetadata["platforms"]) &&
		count($computermetadata["schedules"])) {
		$rt .= menulistLI('timeTable');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=pickTimeTable\">";
		$rt .= i("View Time Table") . "</a></li>\n";
	}
	if(in_array("userGrant", $user["privileges"]) ||
		in_array("resourceGrant", $user["privileges"]) ||
		in_array("nodeAdmin", $user["privileges"])) {
		$rt .= menulistLI('privileges');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=viewNodes\">";
		$rt .= i("Privileges") . "</a></li>\n";
	}
	if(checkUserHasPerm('User Lookup (global)') ||
	   checkUserHasPerm('User Lookup (affiliation only)')) {
		$rt .= menulistLI('userLookup');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=userLookup\">";
		$rt .= i("User Lookup") . "</a></li>\n";
	}
	if(in_array("computerAdmin", $user["privileges"])) {
		$rt .= menulistLI('vm');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=editVMInfo\">";
		$rt .= i("Virtual Hosts") . "</a></li>\n";
	}
	if(checkUserHasPerm('Schedule Site Maintenance')) {
		$rt .= menulistLI('sitemaintenance');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=siteMaintenance\">";
		$rt .= i("Site Maintenance") . "</a></li>\n";
	}
	$rt .= menulistLI('statistics');
	$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=selectstats\">";
	$rt .= i("Statistics") . "</a></li>\n";
	if(checkUserHasPerm('View Dashboard (global)') ||
	   checkUserHasPerm('View Dashboard (affiliation only)')) {
		$rt .= menulistLI('dashboard');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=dashboard\">";
		$rt .= i("Dashboard") . "</a></li>\n";
	}
	if(checkUserHasPerm('Site Configuration (global)') ||
	   checkUserHasPerm('Site Configuration (affiliation only)')) {
		$rt .= menulistLI('siteconfig');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=siteconfig\">";
		$rt .= i("Site Configuration") . "</a></li>\n";
	}
	$rt .= menulistLI('codeDocumentation');
	$rt .= "<a href=\"" . DOCUMENTATIONURL . "\">";
	$rt .= i("Documentation") . "</a></li>\n";
	if($inclogout) {
		$rt .= menulistLI('authentication');
		$rt .= "<a href=\"" . BASEURL . SCRIPT . "?mode=logout\">";
		$rt .= i("Logout") . "</a></li>\n";
	}
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getExtraCSS()
///
/// \return an array of extra css files to include
///
/// \brief this function is to be called from the theme page.php files to get
/// a list of extra css files to be included based on the current mode
///
////////////////////////////////////////////////////////////////////////////////
function getExtraCSS() {
	global $mode;
	switch($mode) {
		case 'viewNodes':
		case 'changeUserPrivs':
		case 'submitAddResourcePriv':
		case 'changeResourcePrivs':
			return array('privileges.css');
		case 'viewdocs':
			return array('doxygen.css');
	}
	return array();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUsingVCL()
///
/// \return string of HTML
///
/// \brief generates HTML of list item links from $NOAUTH_HOMENAV in conf.php
///
////////////////////////////////////////////////////////////////////////////////
function getUsingVCL() {
	global $NOAUTH_HOMENAV;
	$rt = '';
	foreach($NOAUTH_HOMENAV as $name => $url)
		$rt .= "<li><a href=\"$url\">" .  i($name) . "</a></li>\n";
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
	global $mode, $actions, $skin, $locale, $VCLversion;
	$filename = '';
	$dojoRequires = array();

	# Below are START and END comments for parsing the content between the tags
	# to generate a dojo profile.js file for custom dojo layers for each section
	# of the site. The parser script is generateDojoProfile.js and can be found
	# in the vcl/sandbox/useful_scripts part of the ASF VCL subversion repo.
	# To run without the custom layer files, simply comment out the line after
	# the first switch statement below that sets $customfile to something other
	# than an empty string.

	# START DOJO PARSING
	switch($mode) {
		case 'viewNodes':
		case 'changeUserPrivs':
		case 'submitAddResourcePriv':
		case 'changeResourcePrivs':
			$filename = 'vclPrivs.js';
			$dojoRequires = array('dojo.parser',
			                      'dojo.data.ItemFileWriteStore',
			                      'dijit.Tree',
			                      'dijit.form.Button',
			                      'dijit.form.CheckBox',
			                      'dijit.form.TextBox',
			                      'dijit.Tooltip',
			                      'dijit.Dialog',
			                      'dijit.layout.ContentPane',
			                      'dijit.layout.TabContainer');
			break;
		case 'viewRequests':
			require_once('storebackend.php');
			$filename = 'vclViewRequests.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.form.DateTextBox',
			                      'dijit.form.TimeTextBox',
			                      'dijit.form.Select',
			                      'dijit.form.CheckBox',
			                      'dojox.string.sprintf',
			                      'dijit.Dialog',
			                      'dijit.layout.ContentPane',
			                      'dijit.Menu',
			                      'dijit.form.Button',
			                      'dijit.form.DropDownButton',
			                      'dijit.Tooltip',
			                      'vcldojo.HoverTooltip',
			                      'dojox.layout.FloatingPane',
			                      'dojox.grid.DataGrid',
			                      'dijit.form.FilteringSelect',
			                      'dijit.form.NumberSpinner',
			                      'dijit.form.Textarea',
			                      'dijit.Tree',
			                      'dojo.data.ItemFileWriteStore',
			                      'dojo.data.ObjectStore',
			                      'dojo.store.JsonRest',
			                      'dijit.TitlePane',
			                      'dijit.layout.BorderContainer',
			                      'dojo.store.Memory');
			break;
		case 'viewRequestInfo':
			$filename = 'vclConnectRequest.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.form.Button',
			                      'dijit.Dialog');
			break;
		case 'blockAllocations':
			$filename = 'vclViewBlockAllocations.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.form.Button',
			                      'dijit.form.ValidationTextBox',
			                      'dijit.form.FilteringSelect',
			                      'dijit.form.Textarea',
			                      'dojox.grid.DataGrid',
			                      'dijit.Dialog',
			                      'dojox.string.sprintf',
			                      'dojo.data.ItemFileWriteStore',
			                      'dojox.charting.widget.Chart2D',
			                      'dojox.charting.action2d.Tooltip',
			                      'dojox.charting.action2d.Magnify',
			                      'dojox.charting.themes.ThreeD');
			break;
		case 'requestBlockAllocation':
		case 'newBlockAllocation':
		case 'editBlockAllocation':
			$filename = 'vclEditBlockAllocation.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.layout.StackContainer',
			                      'dijit.layout.ContentPane',
			                      'dijit.form.DateTextBox',
			                      'dijit.form.TimeTextBox',
			                      'vcldojo.TimeTextBoxEnd',
			                      'dijit.form.Textarea',
			                      'dijit.form.FilteringSelect',
			                      'dijit.form.NumberSpinner',
			                      'dojox.grid.DataGrid',
			                      'dojox.string.sprintf',
			                      'dijit.Tooltip',
			                      'dijit.Dialog',
			                      'dojo.data.ItemFileWriteStore');
			break;
		case 'viewBlockStatus':
		case 'selectauth':
			$filename = 'vclBasic.js';
			$dojoRequires = array('dojo.parser');
			break;
		case 'viewBlockAllocatedMachines':
			$filename = 'vclBlockMachines.js';
			$dojoRequires = array('dojo.parser',
			                      'dojox.string.sprintf',
			                      'dijit.form.Button',
			                      'dijit.form.DateTextBox',
			                      'dijit.form.TimeTextBox',
			                      'dojox.charting.widget.Chart2D',
			                      'dojox.charting.action2d.Tooltip',
			                      'dojox.charting.action2d.Magnify',
			                      'dojox.charting.themes.ThreeD');
			break;
		case 'viewGroups':
		case 'submitEditGroup':
		case 'submitAddGroup':
		case 'submitDeleteGroup':
			$filename = 'vclManageGroups.js';
			$dojoRequires = array('dojo.parser',
			                      'dojo.data.ItemFileReadStore',
			                      'dojo.data.ItemFileWriteStore',
			                      'dijit.form.Select',
			                      'dijit.form.Button',
			                      'dijit.form.CheckBox',
			                      'dijit.form.TextBox',
			                      'dojox.grid.DataGrid',
			                      'dijit.TitlePane',
			                      'dijit.Tooltip');
			break;
		case 'viewResources':
		case 'editConfigMap':
			$filename = 'vclResources.js';
			$dojoRequires = array('dojo.parser',
			                      'dojo.data.ItemFileReadStore',
			                      'dojo.data.ItemFileWriteStore',
			                      'dijit.form.Select',
			                      'dijit.form.Button',
			                      'dijit.form.ValidationTextBox',
			                      'dijit.form.CheckBox',
			                      'dijit.form.TextBox',
			                      'dijit.form.NumberSpinner',
			                      'dijit.form.HorizontalSlider',
			                      'dojox.grid.DataGrid',
			                      'dijit.TitlePane',
			                      'dijit.form.FilteringSelect',
			                      'dijit.form.ComboBox',
			                      'dijit.form.Textarea',
			                      'dijit.InlineEditBox',
			                      'dijit.form.TimeTextBox',
			                      'dojox.string.sprintf',
			                      'dijit.form.CheckBox',
			                      'dijit.Tooltip',
			                      'dojox.grid._CheckBoxSelector',
			                      'dijit.Menu',
			                      'dojo.cookie',
			                      'dijit.Dialog');
			break;
		case 'groupMapHTML':
			$filename = 'vclResourceGroupMap.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.layout.LinkPane',
			                      'dijit.layout.ContentPane',
			                      'dijit.layout.TabContainer',
			                      'dojo.data.ItemFileWriteStore',
			                      'dojox.form.CheckedMultiSelect',
			                      'dojox.grid.DataGrid',
			                      'dijit.form.Button');
			break;
		case 'serverProfiles':
			$filename = 'vclServerProfiles.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.Dialog',
			                      'dijit.form.Button',
			                      'dijit.form.FilteringSelect',
			                      'dijit.form.Select',
			                      'dijit.form.TextBox',
			                      'dijit.form.ValidationTextBox',
			                      'dijit.form.CheckBox',
			                      'dijit.form.Textarea',
			                      'dijit.layout.ContentPane',
			                      'dijit.layout.TabContainer',
			                      'dojox.string.sprintf',
			                      'dojo.data.ItemFileWriteStore');
			break;
		case 'editVMInfo':
			$filename = 'vclVirtualHosts.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.InlineEditBox',
			                      'dijit.form.NumberSpinner',
			                      'dijit.form.Button',
			                      'dijit.form.TextBox',
			                      'dijit.form.Textarea',
			                      'dijit.form.FilteringSelect',
			                      'dijit.form.Select',
			                      'dijit.TitlePane',
			                      'dijit.layout.ContentPane',
			                      'dijit.layout.TabContainer',
			                      'dojo.data.ItemFileReadStore',
			                      'dijit.Tooltip',
			                      'dijit.Dialog');
			break;
		case 'siteMaintenance':
			$filename = 'vclMaintenance.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.form.Button',
			                      'dijit.form.NumberSpinner',
			                      'dijit.form.DateTextBox',
			                      'dijit.form.TimeTextBox',
			                      'dijit.form.TextBox',
			                      'dijit.form.Select',
			                      'dijit.form.Textarea',
			                      'dojox.string.sprintf',
			                      'dijit.Tooltip',
			                      'dijit.Dialog');
			break;
		case 'userpreferences':
		case 'submitgeneralprefs':
			$filename = 'vclUserPreferences.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.form.Textarea');
			break;
		case 'viewstats':
			$filename = 'vclStats.js';
			$dojoRequires = array('dojo.parser',
			                      'dojox.charting.Chart2D',
			                      'dojox.charting.action2d.Tooltip',
			                      'dojox.charting.action2d.Magnify',
			                      'dojox.charting.themes.ThreeD');
			break;
		case 'dashboard':
			$filename = 'vclDashboard.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.Tooltip',
			                      'dijit.form.Button',
			                      'dojox.charting.widget.Chart2D',
			                      'dojox.charting.action2d.Tooltip',
			                      'dojox.charting.action2d.Magnify',
			                      'dojox.charting.themes.ThreeD',
			                      'dojox.string.sprintf');
			break;
		case 'siteconfig':
			$filename = 'siteconfig.js';
			$dojoRequires = array('dojo.parser',
			                      'dijit.form.Button',
			                      'dijit.form.Textarea',
			                      'dijit.form.FilteringSelect',
			                      'dijit.form.Select',
			                      'dijit.form.NumberSpinner',
			                      'dijit.form.CheckBox',
			                      'dijit.form.ValidationTextBox',
			                      'dijit.layout.ContentPane',
			                      'dijit.layout.TabContainer');
			break;
		# TODO clean up
		/*case 'testDojoREST':
			$filename = '';
			$dojoRequires = array('dojo.parser',
			                      'dijit.form.FilteringSelect',
			                      'dijit.form.Button',
			                      'dojo.data.ObjectStore',
			                      'dojo.store.JsonRest');
			break;*/
	}
	# END DOJO PARSING
	if(empty($dojoRequires))
		return '';
	$customfile = '';
	$v = $VCLversion;
	if(! empty($filename))
		$customfile = sprintf("<script type=\"text/javascript\" src=\"dojo/dojo/%s?v=$v\"></script>\n", $filename);
	$rt = '';
	$jslocale = strtolower(str_replace('_', '-', $locale));
	switch($mode) {

		case "viewRequests":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "   @import \"dojo/dojox/layout/resources/FloatingPane.css\";\n";
			$rt .= "   @import \"dojo/dojox/layout/resources/ResizeHandle.css\";\n";
			$rt .= "   @import \"dojo/dojox/grid/resources/Grid.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/requests.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/resources.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/resources/image.js?v=$v\"></script>\n";
			# TODO keep this or move functions?
			$rt .= "<script type=\"text/javascript\" src=\"js/newresservercommon.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			$rt .= "      dojo.registerModulePath(\"vcldojo\", \"../../js/vcldojo\");\n";
			foreach($dojoRequires as $req)
				$rt .= "      dojo.require(\"$req\");\n";
			$rt .= "      testJS();\n";
			$rt .= "      document.onmousemove = updateMouseXY;\n";
			$rt .= "      showScriptOnly();\n";
			$cont = addContinuationsEntry('AJserverProfileStoreData', array(), 120, 1, 0);
			$rt .= "   populateProfileStore('$cont');\n";
			$rt .= "   });\n";
			if($refresh)
				$rt .= "   refresh_timer = setTimeout(resRefresh, 12000);\n";
			$rt .= "   check_timeout_timer = setTimeout(checkTimeouts, 15000);\n";
			$imaging = getContinuationVar('imaging', 0);
			$rt .= "   initViewRequests($imaging);\n";
			$rt .= "</script>\n";
			return $rt;

		case 'viewRequestInfo':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/requests.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;

		case 'requestBlockAllocation':
		case 'newBlockAllocation':
		case 'editBlockAllocation':
		case 'blockAllocations':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "   @import \"dojo/dojox/grid/resources/Grid.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/blockallocations.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			$rt .= "   dojo.registerModulePath(\"vcldojo\", \"../../js/vcldojo\");\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			if($mode == 'editBlockAllocation') {
				$blockid = getContinuationVar('blockid');
				$cont = addContinuationsEntry('AJpopulateBlockStore', array('blockid' => $blockid), SECINDAY, 1, 0);
				$rt .= "   populateBlockStore('$cont');\n";
			}
			$rt .= "   });\n";
			if($mode == 'editBlockAllocation')
				$rt .= "   var pagemode = 'edit';\n";
			else
				$rt .= "   var pagemode = 'new';\n";
			$rt .= "</script>\n";
			return $rt;

		case "viewBlockStatus":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/blockallocations.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   });\n";
			$rt .= "   setTimeout(updateBlockStatus, 30000);\n";
			$rt .= "</script>\n";
			return $rt;

		case 'viewBlockAllocatedMachines':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/blockallocations.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			$rt .= "      updateAllocatedMachines();\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;

		case 'groupMapHTML':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "   @import \"dojo/dojox/form/resources/CheckedMultiSelect.css\";\n";
			$rt .= "   @import \"dojo/dojox/grid/resources/Grid.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/resources.js?v=$v\"></script>\n";
			$cdata = getContinuationVar();
			switch($cdata['obj']->restype) {
				# could make it generic as follows, but consider security risk
				# of someone being able to get $cdata['obj']->restype set to anything
				#	$jsfile = "resources/{$cdata['obj']->restype}.js";
				#	break;
				case 'config':
					$jsfile = 'resources/config.js';
					break;
				case 'image':
					$jsfile = 'resources/image.js';
					break;
				case 'schedule':
					$jsfile = 'resources/schedule.js';
					break;
				case 'managementnode':
					$jsfile = 'resources/managementnode.js';
					break;
				case 'computer':
					$jsfile = 'resources/computer.js';
					break;
			}
			if(isset($jsfile))
				$rt .= "<script type=\"text/javascript\" src=\"js/$jsfile?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   });\n";
			$rt .= "   dojo.addOnLoad(editGroupMapInit);\n";
			$rt .= "</script>\n";
			return $rt;

		case 'viewGroups':
		case 'submitEditGroup':
		case 'submitAddGroup':
		case 'submitDeleteGroup':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "   @import \"dojo/dojox/grid/resources/Grid.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   });\n";
			$rt .= "   dojo.addOnLoad(function() {document.onmousemove = updateMouseXY;});\n";
			$rt .= "   dojo.ready(function() {\n";
			$rt .= "     buildUserFilterStores();\n";
			$rt .= "     buildResourceFilterStores();\n";
			$rt .= "     if(! usergroupstore.comparatorMap)\n";
			$rt .= "       usergroupstore.comparatorMap = {};\n";
			$rt .= "     usergroupstore.comparatorMap['name'] = nocasesort;\n";
			$rt .= "     if(! resourcegroupstore.comparatorMap)\n";
			$rt .= "       resourcegroupstore.comparatorMap = {};\n";
			$rt .= "     resourcegroupstore.comparatorMap['name'] = nocasesort;\n";
			$rt .= "   });\n";
			if($mode == 'viewGroups')
				$rt .= "  var firstscroll = 1;\n";
			else
				$rt .= " var firstscroll = 0;\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/groups.js?v=$v\"></script>\n";
			return $rt;

		case 'viewResources':
		case 'editConfigMap':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "   @import \"dojo/dojox/grid/resources/Grid.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$cdata = getContinuationVar();
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			$rt .= "      dojo.registerModulePath(\"vcldojo\", \"../../js/vcldojo\");\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "      setTimeout(initViewResources, 100);\n";
			if($cdata['obj']->restype == 'computer')
				$rt .= "      initPage();\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			switch($cdata['obj']->restype) {
				# could make it generic as follows, but consider security risk
				# of someone being able to get $cdata['obj']->restype set to anything
				#	$jsfile = "resources/{$cdata['obj']->restype}.js";
				#	break;
				case 'config':
					$jsfile = 'resources/config.js';
					break;
				case 'image':
					$jsfile = 'resources/image.js';
					break;
				case 'schedule':
					$jsfile = 'resources/schedule.js';
					break;
				case 'managementnode':
					$jsfile = 'resources/managementnode.js';
					break;
				case 'computer':
					$jsfile = 'resources/computer.js';
					break;
			}
			$rt .= "<script type=\"text/javascript\" src=\"js/resources.js?v=$v\"></script>\n";
			if(isset($jsfile))
				$rt .= "<script type=\"text/javascript\" src=\"js/$jsfile?v=$v\"></script>\n";
			return $rt;

		case "serverProfiles":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/serverprofiles.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/newresservercommon.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$cont = addContinuationsEntry('AJserverProfileStoreData', array(), 120, 1, 0);
			$rt .= "   populateProfileStore('$cont');\n";
			$rt .= "   });\n";
			$rt .= "   dojo.addOnLoad(getProfiles);\n";
			$rt .= "</script>\n";
			return $rt;

		case 'selectauth':
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"></script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$authtype = processInputVar("authtype", ARG_STRING);
			$rt .= "   dojo.addOnLoad(function() {document.loginform.userid.focus(); document.loginform.userid.select();});\n";
			$rt .= "</script>\n";
			return $rt;

		case "editVMInfo":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/vm.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   });\n";
			$rt .= "dojo.addOnLoad(function() {";
			$rt .=                   "var dialog = dijit.byId('profileDlg'); ";
			$rt .=                   "dojo.connect(dialog, 'hide', cancelVMprofileChange);});";
			$rt .= "</script>\n";
			return $rt;

		case "viewNodes":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/privileges.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "      document.onmousemove = updateMouseXY;\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;

		case "siteMaintenance":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/sitemaintenance.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;

		case "viewstats":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/statistics.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   generateGraphs();\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;

		case "dashboard":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "   @import \"css/dashboard.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/dashboard.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   updateDashboard();\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;

		case "siteconfig":
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "   @import \"css/siteconfig.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"js/siteconfig.js?v=$v\"></script>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;

		/*case 'testDojoREST':
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= "<script type=\"text/javascript\">\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "</script>\n";
			return $rt;*/

		default:
			$rt .= "<style type=\"text/css\">\n";
			$rt .= "   @import \"themes/$skin/css/dojo/$skin.css\";\n";
			$rt .= "</style>\n";
			$rt .= "<script type=\"text/javascript\" src=\"dojo/dojo/dojo.js\"\n";
			$rt .= "   djConfig=\"parseOnLoad: true, locale: '$jslocale'\">\n";
			$rt .= "</script>\n";
			$rt .= $customfile;
			$rt .= "<script type=\"text/javascript\">\n";
			$rt .= "   dojo.addOnLoad(function() {\n";
			foreach($dojoRequires as $req)
				$rt .= "   dojo.require(\"$req\");\n";
			$rt .= "   });\n";
			$rt .= "</script>\n";
			return $rt;
	}
	return '';
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

////////////////////////////////////////////////////////////////////////////////
///
/// \fn changeLocale()
///
/// \brief sets a cookie for the locale and redirects back to the site
///
////////////////////////////////////////////////////////////////////////////////
function changeLocale() {
	global $locale;
	$newlocale = getContinuationVar('locale');
	$oldmode = getContinuationVar('oldmode');
	$authtype = getContinuationVar('authtype', '');
	$locale = $newlocale;
	setcookie("VCLLOCALE", $locale, (time() + (86400 * 31)), "/", COOKIEDOMAIN);
	$extra = '';
	if($oldmode == 'selectauth' && ! empty($authtype))
		$extra = "&authtype=$authtype";
	header("Location: " . BASEURL . SCRIPT . "?mode=$oldmode$extra");
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn i($str)
///
/// \param $str - string
///
/// \return possibly translated $str with any single quotes changed to &#39;
///
/// \brief function name comes from first letter of "internationalize" - calls
/// _() on $str and converts any single quotes in returned string to &#39;
///
////////////////////////////////////////////////////////////////////////////////
function i($str) {
	return preg_replace("/'/", '&#39;', _($str));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn setVCLLocale()
///
/// \brief sets a cookie for the locale; configures php for the locale
///
////////////////////////////////////////////////////////////////////////////////
function setVCLLocale() {
	global $locale;
	# set a cookie for the locale if it has not been set already
	if(! array_key_exists('VCLLOCALE', $_COOKIE)) {
		setcookie("VCLLOCALE", 'en_US', (time() + (86400 * 31)), "/", COOKIEDOMAIN);
		$locale = DEFAULTLOCALE;
	}
	// if a cookie has already been set, just update the expiration time for it
	else {
		setcookie("VCLLOCALE", $_COOKIE['VCLLOCALE'], (time() + (86400 * 31)), "/", COOKIEDOMAIN);
		$locale = $_COOKIE['VCLLOCALE'];
	}
	
	#putenv('LC_ALL=' . $locale);
	# use UTF8 encoding for any locales other than English (we may just be able
	#   to always use UTF8)
	if(preg_match('/^en/', $locale))
		setlocale(LC_ALL,  $locale);
	else
		setlocale(LC_ALL,  $locale . '.UTF8');
	bindtextdomain('vcl', './locale');
	textdomain('vcl');
	bind_textdomain_codeset('vcl', 'UTF-8');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getSelectLanguagePulldown()
///
/// \return HTML for a select drop down
///
/// \brief generates HTML for a select drop down for changing the locale of
/// the site
///
////////////////////////////////////////////////////////////////////////////////
function getSelectLanguagePulldown() {
	global $locale, $user, $remoteIP, $mode, $authMechs;
	$tmp = explode('/', $_SERVER['SCRIPT_FILENAME']);
	array_pop($tmp);
	array_push($tmp, 'locale');

	$locales = getFSlocales();

	if(count($locales) < 1)
		return '';

	if(! is_array($user))
		$user['id'] = 0;

	$rt  = "<form name=\"localeform\" id=\"localeform\" action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$rt .= "<select name=\"continuation\" onChange=\"document.localeform.submit();\">\n";
	$cdata = array('IP' => $remoteIP, 'oldmode' => $mode);
	if($mode == 'selectauth') {
		$type = processInputVar('authtype', ARG_STRING);
		if(! empty($type) && array_key_exists($type, $authMechs))
			$cdata['authtype'] = $type;
	}
	foreach($locales as $dir => $lang) {
		$cdata['locale'] = $dir;
		$tmp = explode('/', $dir);
		$testlocale = array_pop($tmp);
		$cont = addContinuationsEntry('changeLocale', $cdata, 86400);
		if($locale == $testlocale)
			$rt .= "<option value=\"$cont\" selected>{$lang}</option>\n";
		else
			$rt .= "<option value=\"$cont\">{$lang}</option>\n";
	}
	$rt .= "</select>\n";
	$rt .= "</form> \n";
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getFSlocales()
///
/// \return an array of locales supported in the filesystem where the key is
/// the locale and the value is the name of the locale/language
///
/// \brief looks for supported locales in the filesystem and returns a list of
/// them
///
////////////////////////////////////////////////////////////////////////////////
function getFSlocales() {
	if(isset($_SESSION) && array_key_exists('locales', $_SESSION))
		return $_SESSION['locales'];
	$tmp = explode('/', $_SERVER['SCRIPT_FILENAME']);
	array_pop($tmp);
	$mainpath = implode('/', $tmp);
	array_push($tmp, 'locale');
	$localedir = implode('/', $tmp);
	$dirs = glob("{$localedir}/*");
	$locales = array('en_US' => 'English');
	foreach($dirs as $dir) {
		if(! file_exists("{$dir}/LC_MESSAGES/vcl.mo"))
			continue;
		if(! file_exists("{$dir}/language"))
			continue;
		$fh = fopen("{$dir}/language", 'r');
		while($line = fgetss($fh)) {
			if(preg_match('/(^#)|(^\s*$)/', $line)) {
				continue;
			}
			else
				break;
		}
		fclose($fh);
		if(! $line)
			continue;
		$lang = htmlspecialchars(strip_tags(trim($line)));
		$tmp = explode('/', $dir);
		$dir = array_pop($tmp);
		if($dir == 'po_files')
			continue;
		if(! file_exists("{$mainpath}/js/nls/{$dir}/messages.js"))
			continue;
		$locales[$dir] = $lang;
	}
	$_SESSION['locales'] = $locales;
	return $locales;
}
?>
