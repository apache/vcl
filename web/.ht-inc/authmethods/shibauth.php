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

$authFuncs['shibboleth'] = array('test' => 'testShibAuth',
                                 'auth' => 'processShibAuth',
                                 'unauth' => 'unauthShib');

////////////////////////////////////////////////////////////////////////////////
///
/// \fn testShibAuth()
///
/// \returns 1 if SHIB_EPPN found in $_SERVER; 0 otherwise
///
/// \brief checks for authentication information related to Shibboleth
///
////////////////////////////////////////////////////////////////////////////////
function testShibAuth() {
	// TODO check for other shib variables, if found but EPPN not found, alert user that EPPN is not being released
	if(array_key_exists('SHIB_EPPN', $_SERVER))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processShibAuth()
///
/// \returns userid in userid@AFFILIATION form
///
/// \brief processes Shibboleth authentication information
///
////////////////////////////////////////////////////////////////////////////////
function processShibAuth() {
	# get VCL affiliation from shib affiliation
	$tmp = explode(';', $_SERVER['SHIB_EPPN']);
	$tmp = explode('@', $tmp[0]);
	$username = strtolower($tmp[0]);
	$shibaffil = vcl_mysql_escape_string(strtolower($tmp[1]));
	$query = "SELECT name, shibonly FROM affiliation WHERE shibname = '$shibaffil'";
	$qh = doQuery($query, 101);
	# if shib affiliation not already in VCL, create affiliation
	if(! ($row = mysqli_fetch_assoc($qh))) {
		$affil = strtolower($tmp[1]);
		$tmp = explode('.', $affil);
		array_pop($tmp);
		$affilname = strtoupper(implode('', $tmp));
		$affilname = preg_replace('/[^A-Z0-9]/', '', $affilname);
		$query = "SELECT name, "
				 .        "shibname "
				 . "FROM affiliation "
				 . "WHERE name LIKE '$affilname%' "
				 . "ORDER BY name DESC "
				 . "LIMIT 1";
		$qh = doQuery($query, 101);
		if($row = mysqli_fetch_assoc($qh)) {
			if(preg_match("/$affilname([0-9]+)/", $row['name'], $matches)) {
				$cnt = $matches[1];
				$cnt++;
				$newaffilname = $affilname . $cnt;
			}
			elseif($affilname != strtoupper($row['name']) && $affil != $row['shibname']) {
				$newaffilname = $affilname;
			}
			else {
				$msg = "Someone tried to log in to VCL using Shibboleth from an IdP "
					  . "affiliation that could not be automatically added.\n\n"
					  . "eppn: {$_SERVER['SHIB_EPPN']}\n"
					  . "givenName: {$_SERVER['SHIB_GIVENNAME']}\n"
					  . "sn: {$_SERVER['SHIB_SN']}\n";
				if(array_key_exists('SHIB_MAIL', $_SERVER))
					$msg .= "mail: {$_SERVER['SHIB_MAIL']}\n\n";
				$msg .="tried to add VCL affiliation name \"$affilname\" with "
					  . "shibname \"$affil\"";
				$mailParams = "-f" . ENVELOPESENDER;
				mail(ERROREMAIL, "Error with VCL pages (problem adding shib affil)", $msg, '', $mailParams);
				print "<html><head></head><body>\n";
				print "<h2>Error encountered</h2>\n";
				print "You have attempted to log in to VCL using a Shibboleth<br>\n";
				print "Identity Provider that VCL has not been configured to<br>\n";
				print "work with. VCL administrators have been notified of the<br>\n";
				print "problem.<br>\n";
				print "</body></html>\n";
				dbDisconnect();
				exit;
			}
		}
		else
			$newaffilname = $affilname;
		$query = "INSERT INTO affiliation "
				 .        "(name, "
				 .        "shibname, "
				 .        "shibonly) "
				 . "VALUES "
				 .        "('$newaffilname', "
				 .        "'" . vcl_mysql_escape_string($affil) . "', "
				 .        "1)";
		doQuery($query, 101, 'vcl', 1);
		unset($row);
		$row = array('name' => $newaffilname, 'shibonly' => 1);
	}
	$affil = $row['name'];
	$affilid = getAffiliationID($affil);

	# create VCL userid
	$userid = "$username@$affil";

	if($row['shibonly']) {
		$userdata = updateShibUser($userid);
		if(array_key_exists('SHIB_AFFILIATION', $_SERVER))
			$groups = $_SERVER['SHIB_AFFILIATION'];
		else
			$groups = array('shibaffil' => $shibaffil);
		updateShibGroups($userdata['id'], $groups);
		$usernid = $userdata['id'];
	}
	else {
		$usernid = getUserlistID($userid, 1);
		# NCSU specific
		if(is_null($userid) && $affil == 'NCSU') {
			$tmp = updateLDAPUser('NCSU LDAP', $username);
			$usernid = $tmp['id'];
		}
		/*if($affil == 'NCSU') {
			if(array_key_exists('SHIB_AFFILIATION', $_SERVER))
				$groups = $_SERVER['SHIB_AFFILIATION'];
			else
				$groups = array('shibaffil' => $shibaffil);
			updateShibGroups($usernid, $groups);
		}*/
		# end NCSU specific
		if(is_null($usernid)) {
			$tmp = updateShibUser($userid);
			$usernid = $tmp['id'];
			# call this so that user groups get correctly populated
			updateUserData($usernid, "numeric", $affilid);
		}
	}

	addLoginLog($userid, 'shibboleth', $affilid, 1);

	if($affil == 'UNCG') {
		$gid = getUserGroupID('All UNCG Users', $affilid);
		$query = "INSERT IGNORE INTO usergroupmembers "
				 . "(userid, usergroupid) "
				 . "VALUES ($usernid, $gid)";
		doQuery($query, 307);
	}

	if(array_key_exists('SHIB_LOGOUTURL', $_SERVER))
		$logouturl = $_SERVER['SHIB_LOGOUTURL'];
	else
		$logouturl = '';

	# save data to shibauth table
	$shibdata = array('Shib-Application-ID' => $_SERVER['Shib-Application-ID'],
							'Shib-Identity-Provider' => $_SERVER['Shib-Identity-Provider'],
							#'Shib-AuthnContext-Dec' => $_SERVER['Shib-AuthnContext-Decl'],
							'SHIB_LOGOUTURL' => $logouturl,
							'SHIB_EPPN' => $_SERVER['SHIB_EPPN'],
							#'SHIB_UNAFFILIATION' => $_SERVER['SHIB_UNAFFILIATION'],
							'SHIB_AFFILIATION' => $_SERVER['SHIB_AFFILIATION'],
	);
	$serdata = vcl_mysql_escape_string(serialize($shibdata));
	$query = "SELECT id "
			 . "FROM shibauth "
			 . "WHERE sessid = '{$_SERVER['Shib-Session-ID']}'";
	$qh = doQuery($query, 101);
	if($row = mysqli_fetch_assoc($qh)) {
		$shibauthid = $row['id'];
	}
	else {
		$ts = strtotime($_SERVER['Shib-Authentication-Instant']);
		$ts = unixToDatetime($ts);
		$query = "INSERT INTO shibauth "
				 .        "(userid, " 
				 .        "ts, "
				 .        "sessid, "
				 .        "data) "
				 . "VALUES "
				 .        "($usernid, "
				 .        "'$ts', "
				 .        "'{$_SERVER['Shib-Session-ID']}', "
				 .        "'$serdata')";
		doQuery($query, 101);
		$qh = doQuery("SELECT LAST_INSERT_ID()", 101);
		if(! $row = mysqli_fetch_row($qh)) {
			# todo
		}
		$shibauthid = $row[0];
	}

	# get cookie data
	$cookie = getAuthCookieData($userid, 'shibboleth', 600, $shibauthid);
	# set cookie
	if(version_compare(PHP_VERSION, "5.2", ">=") == true)
		#setcookie("VCLAUTH", "{$cookie['data']}", $cookie['ts'], "/", COOKIEDOMAIN, 1, 1);
		setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN, 0, 1);
	else
		#setcookie("VCLAUTH", "{$cookie['data']}", $cookie['ts'], "/", COOKIEDOMAIN, 1);
		setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN);

	# TODO do something to set VCLSKIN cookie based on affiliation

	return $userid;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn unauthShib($mode)
///
/// \param $mode - headers or content
//
/// \brief for headers, simply returns; for content, prints information that
/// user has been logged out and an iframe to log user out of Shibboleth if
/// SHIB_LOGOUTURL was provided; VCLAUTH cookie is cleared elsewhere
///
////////////////////////////////////////////////////////////////////////////////
function unauthShib($mode) {
	global $user;
	if($mode == 'headers')
		return;

	print "<h2>Logout</h2>\n";
	print "You are now logged out of VCL and other Shibboleth authenticated web sites.<br><br>\n";
	print "<a href=\"" . BASEURL . SCRIPT . "?mode=selectauth\">Return to Login</a><br><br><br>\n";
	print "<iframe src=\"https://{$_SERVER['SERVER_NAME']}/Shibboleth.sso/Logout\" class=hidden>\n";
	print "</iframe>\n";
	if(array_key_exists('SHIB_LOGOUTURL', $_SERVER)) {
	  	print "<iframe src=\"{$_SERVER['SHIB_LOGOUTURL']}\" class=hidden>\n";
		print "</iframe>\n";
	}
	$shibdata = getShibauthDataByUser($user['id']);
	if(array_key_exists('Shib-Identity-Provider', $shibdata) &&
		! empty($shibdata['Shib-Identity-Provider'])) {
		$tmp = explode('/', $shibdata['Shib-Identity-Provider']);
		$idp = "{$tmp[0]}//{$tmp[2]}";
		print "<iframe src=\"$idp/idp/logout.jsp\" class=hidden>\n";
		print "</iframe>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getShibauthDataByUser($userid)
///
/// \param $userid - numeric id of a user
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
function getShibauthDataByUser($userid) {
	$query = "SELECT id, "
	       .        "userid, "
	       .        "ts, "
	       .        "sessid, "
	       .        "data "
	       . "FROM shibauth "
	       . "WHERE userid = $userid AND "
	       .       "ts > DATE_SUB(NOW(), INTERVAL 12 HOUR) "
	       . "ORDER BY ts DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysqli_fetch_assoc($qh)) {
		$data = unserialize($row['data']);
		unset($row['data']);
		$data2 = array_merge($row, $data);
		return $data2;
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateShibUser($userid)
///
/// \param $userid - id of a user in userid@affiliation form
///
/// \return an array with these keys:\n
/// \b firstname
/// \b lastname
/// \b email
/// \b unityid - userid for user
/// \b affilid - id from affiliation table for user's affiliation
/// \b id - id of user from user table
///
/// \brief updates user's first name, last name, and email address, and
/// lastupdated timestamp in the user table from data provided by shibboleth
///
////////////////////////////////////////////////////////////////////////////////
function updateShibUser($userid) {
	global $mysqli_link_vcl;
	$rc = getAffilidAndLogin($userid, $affilid);
	if($rc == -1)
		return NULL;

	$displast = '';

	$displayname = getShibVar('displayName');
	$givenname = getShibVar('givenName');
	$sn = getShibVar('sn');
	$mail = getShibVar('mail');

	if($displayname != '') {
		# split displayname into first and last names
		if(preg_match('/,/', $displayname)) {
			$names = explode(',', $displayname);
			$user['firstname'] = preg_replace('/^\s+/', '', $names[1]);
			$user['firstname'] = preg_replace('/\s+$/', '', $user['firstname']);
			$displast = preg_replace('/^\s+/', '', $names[0]);
			$displast = preg_replace('/\s+$/', '', $displast);
		}
		else {
			$names = explode(' ', $displayname);
			$displast = array_pop($names);
			$user['firstname'] = array_shift($names);
		}
	}
	elseif($givenname != '')
		$user['firstname'] = $givenname;
	else
		$user['firstname'] = '';

	if($sn != '')
		$user["lastname"] = $sn;
	else
		$user['lastname'] = $displast;

	if($mail != '')
		$user["email"] = $mail;

	$user['unityid'] = $userid;
	$user['affilid'] = $affilid;

	# check to see if this user already exists in our db
	$query = "SELECT id "
	       . "FROM user "
	       . "WHERE unityid = '$userid' AND "
	       .       "affiliationid = $affilid";
	$qh = doQuery($query, 101);
	if(! $row = mysqli_fetch_assoc($qh)) {
		# add user to our db
		$user['id'] = addShibUser($user);
		return $user;
	}

	# update user's data in db
	$user['id'] = $row['id'];
	$first = vcl_mysql_escape_string($user['firstname']);
	$last = vcl_mysql_escape_string($user['lastname']);
	$query = "UPDATE user "
	       . "SET firstname = '$first', "
	       .     "lastname = '$last', ";
	if(array_key_exists('email', $user)) {
		$email = vcl_mysql_escape_string($user['email']);
		$query .= "email = '$email', ";
	}
    $query .=    "lastupdated = NOW(), "
           . "validated = 1 " 
	       . "WHERE id = {$user['id']}";
	doQuery($query, 101, 'vcl', 1);
	return $user;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addShibUser($user)
///
/// \param $user - array of user data with these keys:\n
/// \b unityid - userid\n
/// \b affilid - id from affiliation table matching user's affiliation\n
/// \b firstname\n
/// \b lastname\n
/// \b email
///
/// \return id from user table for user
///
/// \brief adds $user to the user table
///
////////////////////////////////////////////////////////////////////////////////
function addShibUser($user) {
	global $mysqli_link_vcl;
	$unityid = vcl_mysql_escape_string($user['unityid']);
	$first = vcl_mysql_escape_string($user['firstname']);
	$last = vcl_mysql_escape_string($user['lastname']);
	$query = "INSERT INTO user "
	       .        "(unityid, "
	       .        "affiliationid, "
	       .        "firstname, "
	       .        "lastname, ";
	if(array_key_exists('email', $user))
		$query .=    "email, ";
	$query .=       "emailnotices, "
	       .        "lastupdated) "
	       . "VALUES ("
	       .        "'$unityid', "
	       .        "{$user['affilid']}, "
	       .        "'$first', "
	       .        "'$last', ";
	if(array_key_exists('email', $user)) {
		$email = vcl_mysql_escape_string($user['email']);
		$query .=    "'$email', ";
	}
	$query .=       "0, "
	       .        "NOW())";
	doQuery($query, 101, 'vcl', 1);
	if(mysqli_affected_rows($mysqli_link_vcl)) {
		$user['id'] = mysqli_insert_id($mysqli_link_vcl);
		return $user['id'];
	}
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateShibGroups($usernid, $groups)
///
/// \param $usernid - id from user table
/// \param $groups - data provided in the eduPersonScopedAffiliation attribute
/// or an array with a single element where the key is 'shibaffil' and the
/// value matches an entry for shibname from the affiliation table
///
/// \brief converts the shibboleth affiliation to VCL affiliation, prepends
/// 'shib-' to each of the group names and calls updateGroups to add the user
/// to each of the shibboleth groups; if $groups is the array option, user is
/// added to a single group named "All <affil name> users" where <affil name>
/// is the name field from the affiliation table
///
////////////////////////////////////////////////////////////////////////////////
function updateShibGroups($usernid, $groups) {
	if(is_array($groups) && array_key_exists('shibaffil', $groups)) {
		$shibaffil = $groups['shibaffil'];
		$groups = '';
	}
	$groups = explode(';', $groups);
	$newusergroups = array();
	foreach($groups as $group) {
		# make sure $group contains non-whitespace
		if(! preg_match('/\w/', $group))
			continue;
		list($name, $shibaffil) = explode('@', $group);
		# get id for the group's affiliation
		$query = "SELECT id FROM affiliation WHERE shibname = '$shibaffil'";
		$qh = doQuery($query, 101);
		if(! ($row = mysqli_fetch_assoc($qh))) {
			$query = "SELECT id FROM affiliation WHERE shibname LIKE '%.$shibaffil'";
			$qh = doQuery($query, 101);
			if(! ($row = mysqli_fetch_assoc($qh)))
				continue;
		}
		$affilid = $row['id'];
		# prepend shib- and escape it for mysql
		$grp = vcl_mysql_escape_string("shib-" . $name);
		array_push($newusergroups, getUserGroupID($grp, $affilid));
	}

	$query = "SELECT id, name FROM affiliation WHERE shibname = '$shibaffil'";
	$qh = doQuery($query, 101);
	$row = mysqli_fetch_assoc($qh);
	$affilid = $row['id'];
	$grp = vcl_mysql_escape_string("All {$row['name']} Users");
	array_push($newusergroups, getUserGroupID($grp, $affilid));

	$newusergroups = array_unique($newusergroups);
	if(! empty($newusergroups))
		updateGroups($newusergroups, $usernid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addShibUserStub($affilid, $userid)
///
/// \param $affilid - id of user's affiliation
/// \param $userid - user's login id
///
/// \return an array of user information with the following keys:\n
/// \b first - empty string\n
/// \b last - empty string\n
/// \b email - empty string\n
/// \b emailnotices - 0 or 1, whether or not emails should be sent to user
///
/// \brief adds $userid to database with both lastupdate and validated set to 0
///
////////////////////////////////////////////////////////////////////////////////
function addShibUserStub($affilid, $userid) {
	global $mysqli_link_vcl;
	$query = "INSERT INTO user "
	       .        "(unityid, "
	       .        "affiliationid, "
	       .        "emailnotices, "
	       .        "lastupdated, "
	       .        "validated) "
	       . "VALUES ("
	       .        "'$userid', "
	       .        "'$affilid', "
	       .        "0, "
	       .        "0, "
	       .        "0)";
	doQuery($query);
	if(mysqli_affected_rows($mysqli_link_vcl))
		return dbLastInsertID();
	else
		return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getShibVar($key)
///
/// \param $key - shib variable to check for
///
/// \return value of shib variable or empty string if not found
///
/// \brief checks for various forms of $key in $_SERVER
///
////////////////////////////////////////////////////////////////////////////////
function getShibVar($key) {
	$key2 = "SHIB_" . strtoupper($key);
	$val = '';
	if(isset($_SERVER[$key]) && ! empty($_SERVER[$key]))
		return $_SERVER[$key];
	elseif(isset($_SERVER[$key2]) && ! empty($_SERVER[$key2]))
		return $_SERVER[$key2];
}

?>
