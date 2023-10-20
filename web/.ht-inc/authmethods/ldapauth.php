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

$authFuncs['ldap'] = array('test' => function() {return 0;},
                           'auth' => function() {return NULL;},
                           'unauth' => 'unauthLDAP');

////////////////////////////////////////////////////////////////////////////////
///
/// \fn unauthLDAP($mode)
///
/// \param $mode - headers or content
///
/// \brief for headers, simply returns; for content, prints information that
/// user has been logged out; VCLAUTH cookie is cleared elsewhere
///
////////////////////////////////////////////////////////////////////////////////
function unauthLDAP($mode) {
	if($mode == 'headers')
		return;
	print "<h2>" . _('Logout') . "</h2>\n";
	print _("You are now logged out of VCL.") . "<br><br>\n";
	print "<a href=\"" . BASEURL . SCRIPT . "?mode=selectauth\">" . _("Return to Login");
	print "</a><br><br><br>\n";
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
	$esc_userid = vcl_mysql_escape_string($userid);
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
		if(! mysqli_num_rows($qh)) {
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
		$cookie = getAuthCookieData("$userid@" . getAffiliationName($authMechs[$authtype]['affiliationid']), 'ldap');
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
/// \fn addLDAPUser($authtype, $userid)
///
/// \param $authtype - index from the $authMechs array
/// \param $userid - a userid without the affiliation part
///
/// \return id from the user table or NULL on failure
///
/// \brief looks up $userid in LDAP according to info in $authMechs array, adds
/// the user to the user table, and returns the new id from the table
///
////////////////////////////////////////////////////////////////////////////////
function addLDAPUser($authtype, $userid) {
	global $authMechs, $mysqli_link_vcl;
	$data = getLDAPUserData($authtype, $userid);
	if(is_null($data))
		return NULL;

	$loweruserid = strtolower($userid);
	$loweruserid = vcl_mysql_escape_string($loweruserid);

	# check for existance of an expired user if a numericid exists
	if(array_key_exists('numericid', $data)) {
		$query = "SELECT id, "
		       .        "unityid, "
		       .        "affiliationid "
		       . "FROM user "
		       . "WHERE lastupdated < DATE_SUB(NOW(), INTERVAL 1 YEAR) AND "
		       .       "uid = {$data['numericid']} AND "
		       .       "unityid != '$loweruserid'";
		       #.       "affiliationid = {$authMechs[$authtype]['affiliationid']}";
		$qh = doQuery($query, 101);
		if($row = mysqli_fetch_assoc($qh)) {
			# find the authtype for this user
			foreach($authMechs as $index => $auth) {
				if($auth['affiliationid'] == $row['affiliationid'] &&
				   $auth['type'] == 'ldap') {
					$checktype = $index;
					break;
				}
			}
			# see if user is still in ldap
			if(! empty($checktype)) {
				$testdata = getLDAPUserData($checktype, $row['unityid']);
				if(! is_null($testdata))
					abort(52);
				# if not, null the uid for the user
				$query = "UPDATE user SET uid = NULL WHERE id = {$row['id']}";
				doQuery($query, 101);
			}
		}
	}

	$query = "INSERT INTO user (";
	if(array_key_exists('numericid', $data))
		$query .=    "uid, ";
	$query .=       "unityid, "
	       .        "affiliationid, "
	       .        "firstname, "
	       .        "lastname, "
	       .        "email, "
	       .        "emailnotices, "
	       .        "lastupdated) "
	       . "VALUES (";
	if(array_key_exists('numericid', $data))
		$query .=    "{$data['numericid']}, ";
	$query .=       "'$loweruserid', "
	       .        "{$authMechs[$authtype]['affiliationid']}, "
	       .        "'{$data['first']}', "
	       .        "'{$data['last']}', "
	       .        "'{$data['email']}', "
	       .        "'{$data['emailnotices']}', "
	       .        "NOW())";
	doQuery($query, 101, 'vcl', 1);
	if(mysqli_affected_rows($mysqli_link_vcl)) {
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM user", 101);
		if(! $row = mysqli_fetch_row($qh)) {
			abort(101);
		}
		return $row[0];
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn validateLDAPUser($type, $loginid)
///
/// \param $type - an array from the $authMechs table
/// \param $loginid - a userid without the affiliation part
///
/// \return 1 if user was found in ldap, 0 if not, -1 on ldap error
///
/// \brief checks to see if a user is in ldap
///
////////////////////////////////////////////////////////////////////////////////
function validateLDAPUser($type, $loginid) {
	global $authMechs;
	$auth = $authMechs[$type];
	$savehdlr = set_error_handler(function() {});
	if(! ($fh = fsockopen($auth['server'], 636, $errno, $errstr, 5)))
		return -1;
	set_error_handler($savehdlr);
	fclose($fh);
	$ds = ldap_connect("ldaps://{$auth['server']}/");
	if(! $ds)
		return -1;
	ldap_set_option($ds, LDAP_OPT_PROTOCOL_VERSION, 3);
	ldap_set_option($ds, LDAP_OPT_REFERRALS, 0);

	if(array_key_exists('masterlogin', $auth) && strlen($auth['masterlogin']))
		$res = ldap_bind($ds, $auth['masterlogin'], $auth['masterpwd']);
	else 
		$res = ldap_bind($ds);

	if(! $res)
		return -1;

	$return = array('dn');

	$search = ldap_search($ds,
	                      $auth['binddn'], 
	                      "{$auth['unityid']}=$loginid",
	                      $return, 0, 3, 15);

	if(! $search)
		return -1;

	$data = ldap_get_entries($ds, $search);
	if($data['count'])
		return 1;

	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateLDAPUser($authtype, $userid)
///
/// \param $authtype - an array from the $authMechs table
/// \param $userid - a userid without the affiliation part
///
/// \return an array of user information or NULL on error
///
/// \brief pulls the user's information from ldap, updates it in the db, and 
/// returns an array of the information
///
////////////////////////////////////////////////////////////////////////////////
function updateLDAPUser($authtype, $userid) {
	global $authMechs;
	$esc_userid = vcl_mysql_escape_string($userid);
	$userData = getLDAPUserData($authtype, $userid);
	if(is_null($userData))
		return NULL;
	$affilid = $authMechs[$authtype]['affiliationid'];
	$now = unixToDatetime(time());

	// select desired data from db
	$qbase = "SELECT i.name AS IMtype, "
	       .        "u.IMid AS IMid, "
	       .        "u.affiliationid, "
	       .        "af.name AS affiliation, "
	       .        "af.shibonly, "
	       .        "u.emailnotices, "
	       .        "u.preferredname AS preferredname, "
	       .        "u.uid AS uid, "
	       .        "u.id AS id, "
	       .        "u.width AS width, "
	       .        "u.height AS height, "
	       .        "u.bpp AS bpp, "
	       .        "u.audiomode AS audiomode, "
	       .        "u.mapdrives AS mapdrives, "
	       .        "u.mapprinters AS mapprinters, "
	       .        "u.mapserial AS mapserial, "
	       .        "COALESCE(u.rdpport, 3389) AS rdpport, "
	       .        "u.showallgroups "
	       . "FROM affiliation af, "
	       .      "user u "
	       . "LEFT JOIN IMtype i ON (u.IMtypeid = i.id) "
	       . "WHERE af.id = $affilid AND ";
	if(array_key_exists('numericid', $userData) &&
	   is_numeric($userData['numericid']))
		$query = $qbase . "u.uid = {$userData['numericid']}";
	else {
		$query = $qbase . "u.unityid = '$esc_userid' AND "
		       .          "u.affiliationid = $affilid";
	}
	$qh = doQuery($query, 255);
	$updateuid = 0;
	# check to see if there is a matching entry where uid is NULL but unityid and affiliationid match
	if(array_key_exists('numericid', $userData) &&
	   is_numeric($userData['numericid']) &&
	   ! mysqli_num_rows($qh)) {
		$updateuid = 1;
		$query = $qbase . "u.unityid = '$esc_userid' AND "
		       .          "u.affiliationid = $affilid";
		$qh = doQuery($query, 255);
	}
	// if get a row
	//    update db
	//    update results from select
	if($user = mysqli_fetch_assoc($qh)) {
		$user["unityid"] = $userid;
		$user["firstname"] = $userData['first'];
		$user["lastname"] = $userData["last"];
		$user["email"] = $userData["email"];
		$user["lastupdated"] = $now;
		$query = "UPDATE user "
		       . "SET unityid = '$esc_userid', "
		       .     "firstname = '{$userData['first']}', "
		       .     "lastname = '{$userData['last']}', "
		       .     "email = '{$userData['email']}', ";
		if($updateuid)
			$query .= "uid = {$userData['numericid']}, ";
		$query .=    "lastupdated = '$now' ";
		if(array_key_exists('numericid', $userData) &&
		   is_numeric($userData['numericid']) &&
		   ! $updateuid)
			$query .= "WHERE uid = {$userData['numericid']}";
		else
			$query .= "WHERE unityid = '$esc_userid' AND "
			       .        "affiliationid = $affilid";
		doQuery($query, 256, 'vcl', 1);
	}
	else {
	//    call addLDAPUser
		$id = addLDAPUser($authtype, $userid);
		$query = "SELECT u.unityid AS unityid, "
		       .        "u.affiliationid, "
		       .        "af.name AS affiliation, "
		       .        "u.firstname AS firstname, "
		       .        "u.lastname AS lastname, "
		       .        "u.preferredname AS preferredname, "
		       .        "u.email AS email, "
		       .        "i.name AS IMtype, "
		       .        "u.IMid AS IMid, "
		       .        "u.uid AS uid, "
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
		       .        "u.usepublickeys, "
		       .        "u.sshpublickeys, "
		       .        "u.lastupdated AS lastupdated "
		       . "FROM affiliation af, "
		       .      "user u "
		       . "LEFT JOIN IMtype i ON (u.IMtypeid = i.id) "
		       . "WHERE u.affiliationid = af.id AND "
		       .       "u.id = $id";
		$qh = doQuery($query, 101);
		if(! $user = mysqli_fetch_assoc($qh))
			return NULL;
		$user['sshpublickeys'] = htmlspecialchars($user['sshpublickeys']);
	}

	// TODO handle generic updating of groups
	switch(getAffiliationName($affilid)) {
		case 'EXAMPLE1':
			updateEXAMPLE1Groups($user);
			break;
		default:
			//TODO possibly add to a default group
	}
	$user["groups"] = getUsersGroups($user["id"], 1);
	$user["groupperms"] = getUsersGroupPerms(array_keys($user['groups']));
	$user["privileges"] = getOverallUserPrivs($user["id"]);
	$user['login'] = $user['unityid'];
	return $user;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getLDAPUserData($authtype, $userid)
///
/// \param $authtype - an array from the $authMechs table
/// \param $userid - a userid without the affiliation part
///
/// \return an array of user information with the following keys:\n
/// \b first - first name of user (escaped with vcl_mysql_escape_string)\n
/// \b last - last name of user (escaped with vcl_mysql_escape_string)\n
/// \b email - email address of user (escaped with vcl_mysql_escape_string)\n
/// \b emailnotices - 0 or 1, whether or not emails should be sent to user\n
/// \b numericid - numeric id of user if $authtype is configured to include it
///
/// \brief gets user information from ldap
///
////////////////////////////////////////////////////////////////////////////////
function getLDAPUserData($authtype, $userid) {
	global $authMechs, $mysqli_link_vcl;
	$auth = $authMechs[$authtype];
	$donumericid = 0;
	if(array_key_exists('numericid', $auth))
		$donumericid = 1;

	$ds = ldap_connect("ldaps://{$auth['server']}/");
	// FIXME
	ldap_set_option($ds, LDAP_OPT_PROTOCOL_VERSION, 3);
	ldap_set_option($ds, LDAP_OPT_REFERRALS, 0);

	if(array_key_exists('masterlogin', $auth) && strlen($auth['masterlogin']))
		$res = ldap_bind($ds, $auth['masterlogin'], $auth['masterpwd']);
	else 
		$res = ldap_bind($ds);

	// FIXME

	$ldapsearch = array($auth['firstname'],
	                    $auth['lastname'],
	                    $auth['email']);
	if($donumericid)
		array_push($ldapsearch, $auth['numericid']);
	# FIXME hack
	array_push($ldapsearch, 'gecos');

	$searchuser = stripslashes($userid);

	$search = ldap_search($ds,
	                      $auth['binddn'], 
	                      "{$auth['unityid']}=$searchuser",
	                      $ldapsearch, 0, 3, 15);

	$return = array();
	if($search) {
		$tmpdata = ldap_get_entries($ds, $search);
		if(! $tmpdata['count'])
			return NULL;
		$data = array();
		for($i = 0; $i < $tmpdata['count']; $i++) {
			for($j = 0; $j < $tmpdata[$i]['count']; $j++) {
				if(is_array($tmpdata[$i][$tmpdata[$i][$j]]))
					$data[strtolower($tmpdata[$i][$j])] = $tmpdata[$i][$tmpdata[$i][$j]][0];
				else
					$data[strtolower($tmpdata[$i][$j])] = $tmpdata[$i][$tmpdata[$i][$j]];
			}
		}
		// FIXME hack to take care of users that don't have full info in ldap
		if(! array_key_exists($auth['firstname'], $data) &&
		   ! array_key_exists(strtolower($auth['firstname']), $data)) {
			if(array_key_exists('gecos', $data)) {
				$tmpArr = explode(' ', $data['gecos']);
				if(count($tmpArr) == 3) {
					$data[strtolower($auth['firstname'])] = $tmpArr[0];
					$data[strtolower($auth['lastname'])] = $tmpArr[2];
				}
				elseif(count($tmpArr) == 2) {
					$data[strtolower($auth['firstname'])] = $tmpArr[0];
					$data[strtolower($auth['lastname'])] = $tmpArr[1];
				}
				elseif(count($tmpArr) == 1) {
					$data[strtolower($auth['firstname'])] = '';
					$data[strtolower($auth['lastname'])] = $tmpArr[0];
				}
			}
			else {
				$data[strtolower($auth['firstname'])] = '';
				$data[strtolower($auth['lastname'])] = '';
			}
		}
		$return['emailnotices'] = 1;
		if(! array_key_exists($auth['email'], $data)) {
			$data[strtolower($auth['email'])] = $userid . $auth['defaultemail'];
			$return['emailnotices'] = 0;
		}

		if(array_key_exists(strtolower($auth['firstname']), $data))
			$return['first'] = vcl_mysql_escape_string($data[strtolower($auth['firstname'])]);
		else
			$return['first'] = '';
		if(array_key_exists(strtolower($auth['lastname']), $data))
			$return['last'] = vcl_mysql_escape_string($data[strtolower($auth['lastname'])]);
		else
			$return['last'] = '';
		if($donumericid && is_numeric($data[strtolower($auth['numericid'])]))
			$return['numericid'] = $data[strtolower($auth['numericid'])];
		$return['email'] = vcl_mysql_escape_string($data[strtolower($auth['email'])]);

		return $return;
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateEXAMPLE1Groups($user)
///
/// \param $user - an array of user data
///
/// \brief builds an array of memberof groups user is a member of and calls
/// updateGroups
///
////////////////////////////////////////////////////////////////////////////////
function updateEXAMPLE1Groups($user) {
	global $authMechs;
	$auth = $authMechs['EXAMPLE1 LDAP'];
	$ds = ldap_connect("ldaps://{$auth['server']}/");
	if(! $ds)
		return 0;
	ldap_set_option($ds, LDAP_OPT_PROTOCOL_VERSION, 3);
	ldap_set_option($ds, LDAP_OPT_REFERRALS, 0);

	$res = ldap_bind($ds, $auth['masterlogin'],
	                  $auth['masterpwd']);
	if(! $res)
		return 0;

	$search = ldap_search($ds,
	                      $auth['binddn'], 
	                      "{$auth['unityid']}={$user['unityid']}",
	                      array('memberof'), 0, 10, 15);
	if(! $search)
		return 0;

	$data = ldap_get_entries($ds, $search);
	$newusergroups = array();
	if(! array_key_exists('memberof', $data[0]))
		return;
	for($i = 0; $i < $data[0]['memberof']['count']; $i++) {
		if(preg_match('/^CN=(.+),OU=CourseRolls,DC=example1,DC=com/', $data[0]['memberof'][$i], $match) ||
		   preg_match('/^CN=(Students_Enrolled),OU=Students,DC=example1,DC=com$/', $data[0]['memberof'][$i], $match) ||
		   preg_match('/^CN=(Staff),OU=IT,DC=example1,DC=com$/', $data[0]['memberof'][$i], $match))
			array_push($newusergroups, getUserGroupID($match[1], $user['affiliationid']));
	}
	$newusergroups = array_unique($newusergroups);
	updateGroups($newusergroups, $user["id"]);
}
?>
