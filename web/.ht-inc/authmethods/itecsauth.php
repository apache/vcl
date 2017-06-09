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

@include_once("itecsauth/itecsauth.php");

/**
 * \file
 */

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addITECSUser($loginid)
///
/// \param $loginid - email address of user
///
/// \return new id from user table or NULL if there was a problem
///
/// \brief looks up a user's info in the accounts database and adds the user to
/// our database
///
////////////////////////////////////////////////////////////////////////////////
function addITECSUser($loginid) {
	global $mysql_link_vcl, $ENABLE_ITECSAUTH;
	if(! $ENABLE_ITECSAUTH)
		return NULL;
	$esc_loginid = mysql_real_escape_string($loginid);
	$query = "SELECT id AS uid, "
	       .        "first, " 
	       .        "last, "
	       .        "email, "
	       .        "created, "
	       .        "active, "
	       .        "lockedout "
	       . "FROM user "
	       . "WHERE email = '$esc_loginid'";
	$qh = doQuery($query, 101, "accounts");
	if($row = mysql_fetch_assoc($qh)) {
		// FIXME test replacing ''s
		// FIXME do we care if the account is active?
		$first = mysql_real_escape_string($row['first']);
		$last = mysql_real_escape_string($row['last']);
		$loweruser = mysql_real_escape_string(strtolower($row['email']));
		$email = mysql_real_escape_string($row['email']);
		$query = "INSERT INTO user ("
		       .        "uid, "
		       .        "unityid, "
		       .        "affiliationid, "
		       .        "firstname, "
		       .        "lastname, "
		       .        "email, "
		       .        "emailnotices, "
		       .        "showallgroups, "
		       .        "lastupdated) "
		       . "VALUES ("
		       .        "{$row['uid']}, "
		       .        "'$loweruser', "
		       .        "2, "
		       .        "'$first', "
		       .        "'$last', "
		       .        "'$email', "
		       .        "0, "
		       .        "1, "
		       .        "NOW())";
		// FIXME might want this logged
		doQuery($query, 101, 'vcl', 1);
	}
	if(mysql_affected_rows($mysql_link_vcl)) {
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM user", 101);
		if(! $row = mysql_fetch_row($qh)) {
			abort(101);
		}
		return $row[0];
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn validateITECSUser($loginid)
///
/// \param $loginid - email address for user
///
/// \return 1 if account exists and is active or not yet activated, 0 otherwise
///
/// \brief looks up $loginid in accounts db
///
////////////////////////////////////////////////////////////////////////////////
function validateITECSUser($loginid) {
	global $ENABLE_ITECSAUTH;
	if(! $ENABLE_ITECSAUTH)
		return 0;
	$loginid = mysql_real_escape_string($loginid);
	$query = "SELECT email "
	       . "FROM user "
	       . "WHERE email = '$loginid' AND "
	       .       "(active = 1 OR "
	       .       "activated = 0)";
	$qh = doQuery($query, 101, "accounts");
	if(mysql_num_rows($qh))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateITECSUser($userid)
///
/// \param $userid - email address for user
///
/// \return NULL if fail to update data or an array with these elements:\n
/// \b id - user's numeric from user table\n
/// \b uid - user's numeric unity id\n
/// \b unityid - unity ID for the user\n
/// \b affiliation - user's affiliation\n
/// \b affiliationid - user's affiliation id\n
/// \b firstname - user's first name\n
/// \b preferredname - user's preferred name\n
/// \b lastname - user's last name\n
/// \b email - user's preferred email address\n
/// \b IMtype - user's preferred IM protocol\n
/// \b IMid - user's IM id\n
/// \b width - rdp file width\n
/// \b height - rdp file height\n
/// \b bpp - rdp file bpp\n
/// \b audiomode - rdp file audio mode\n
/// \b mapdrives - rdp file drive mapping\n
/// \b mapprinters - rdp file printer mapping\n
/// \b mapserial - rdp file serial port mapping\n
/// \b showallgroups - show all user groups or not\n
/// \b lastupdated - datetime the information was last updated
///
/// \brief updates user's info in the user table; adds user if not already in
/// table
///
////////////////////////////////////////////////////////////////////////////////
function updateITECSUser($userid) {
	global $ENABLE_ITECSAUTH;
	if(! $ENABLE_ITECSAUTH)
		return NULL;
	$query = "SELECT id AS uid, "
	       .        "first, " 
	       .        "last, "
	       .        "email, "
	       .        "created "
	       . "FROM user "
	       . "WHERE email = '$userid'";
	$qh = doQuery($query, 101, "accounts");
	if(! ($userData = mysql_fetch_assoc($qh)))
		return NULL;

	$now = unixToDatetime(time());

	// select desired data from db
	$query = "SELECT i.name AS IMtype, "
	       .        "u.IMid AS IMid, "
	       .        "u.affiliationid, "
	       .        "af.name AS affiliation, "
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
	       . "WHERE u.affiliationid = af.id AND "
	       .       "u.uid = {$userData['uid']}";
	$qh = doQuery($query, 255);
	// if get a row
	//    update db
	//    update results from select
	$esc_userid = mysql_real_escape_string($userid);
	$first = mysql_real_escape_string($userData['first']);
	$last = mysql_real_escape_string($userData['last']);
	$email = mysql_real_escape_string($userData['email']);
	if($user = mysql_fetch_assoc($qh)) {
		$user["unityid"] = $userid;
		$user["firstname"] = $userData['first'];
		$user["lastname"] = $userData["last"];
		$user["email"] = $userData["email"];
		$user["lastupdated"] = $now;
		$query = "UPDATE user "
		       . "SET unityid = '$esc_userid', "
		       .     "firstname = '$first', "
		       .     "lastname = '$last', "
		       .     "email = '$email', "
		       .     "lastupdated = '$now' "
		       . "WHERE uid = {$userData['uid']}";
		doQuery($query, 256, 'vcl', 1);
	}
	else {
	//    call addITECSUser
		$id = addITECSUser($userid);
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
		       .        "u.lastupdated AS lastupdated "
		       . "FROM affiliation af, "
		       .      "user u "
		       . "LEFT JOIN IMtype i ON (u.IMtypeid = i.id) "
		       . "WHERE u.affiliationid = af.id AND "
		       .       "u.id = $id";
		$qh = doQuery($query, 101);
		$user = mysql_fetch_assoc($qh);

		# add account to demo group
		#$demoid = getUserGroupID('demo', getAffiliationID('ITECS'));
		#updateGroups(array($demoid), $user['id']);
	}

	$user["groups"] = getUsersGroups($user["id"], 1);
	$user["groupperms"] = getUsersGroupPerms(array_keys($user['groups']));

	checkExpiredDemoUser($user['id'], $user['groups']);

	$user["privileges"] = getOverallUserPrivs($user["id"]);
	$tmparr = explode('@', $user['unityid']);
	$user['login'] = $tmparr[0];
	return $user;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn testITECSAffiliation(&$login, &$affilid)
///
/// \param $login - (pass by ref) a login id with affiliation
/// \param $affilid - (pass by ref) gets overwritten
///
/// \return - 1 if successfully found affiliation id, 0 if failed 
///
/// \brief changes $login to be without affiliation and sticks the associated
/// affiliation id for ITECS in $affilid
///
////////////////////////////////////////////////////////////////////////////////
function testITECSAffiliation(&$login, &$affilid) {
	if(preg_match('/^([^@]*@[^@]*\.[^@]*)@ITECS$/', $login, $matches) ||
	   preg_match('/^([^@]*@[^@]*\.[^@]*)$/', $login, $matches)) {
		$login = $matches[1];
		$affilid = getAffiliationID('ITECS');
		return 1;
	}
	return 0;
}

array_push($findAffilFuncs, "testITECSAffiliation");
?>
