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
	global $mysql_link_vcl;
	$rc = getAffilidAndLogin($userid, $affilid);
	if($rc == -1)
		return NULL;

	$displast = '';
	if(array_key_exists('displayName', $_SERVER) &&
	   ! empty($_SERVER['displayName'])) {
		# split displayName into first and last names
		if(preg_match('/,/', $_SERVER['displayName'])) {
			$names = explode(',', $_SERVER['displayName']);
			$user['firstname'] = preg_replace('/^\s+/', '', $names[1]);
			$user['firstname'] = preg_replace('/\s+$/', '', $user['firstname']);
			$displast = preg_replace('/^\s+/', '', $names[0]);
			$displast = preg_replace('/\s+$/', '', $displast);
		}
		else {
			$names = explode(' ', $_SERVER['displayName']);
			$displast = array_pop($names);
			$user['firstname'] = array_shift($names);
		}
	}
	elseif(array_key_exists('givenName', $_SERVER) &&
	   ! empty($_SERVER['givenName']))
		$user['firstname'] = $_SERVER['givenName'];
	else
		$user['firstname'] = '';

	if(array_key_exists('sn', $_SERVER) &&
	   ! empty($_SERVER['sn']))
		$user["lastname"] = $_SERVER['sn'];
	else
		$user['lastname'] = $displast;
	if(array_key_exists('mail', $_SERVER))
		$user["email"] = $_SERVER['mail'];
	$user['unityid'] = $userid;
	$user['affilid'] = $affilid;

	# check to see if this user already exists in our db
	$query = "SELECT id "
	       . "FROM user "
	       . "WHERE unityid = '$userid' AND "
	       .       "affiliationid = $affilid";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		# add user to our db
		$user['id'] = addShibUser($user);
		return $user;
	}

	# update user's data in db
	$user['id'] = $row['id'];
	$first = mysql_real_escape_string($user['firstname']);
	$last = mysql_real_escape_string($user['lastname']);
	$query = "UPDATE user "
	       . "SET firstname = '$first', "
	       .     "lastname = '$last', ";
	if(array_key_exists('email', $user)) {
		$email = mysql_real_escape_string($user['email']);
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
	global $mysql_link_vcl;
	$unityid = mysql_real_escape_string($user['unityid']);
	$first = mysql_real_escape_string($user['firstname']);
	$last = mysql_real_escape_string($user['lastname']);
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
		$email = mysql_real_escape_string($user['email']);
		$query .=    "'$email', ";
	}
	$query .=       "0, "
	       .        "NOW())";
	doQuery($query, 101, 'vcl', 1);
	if(mysql_affected_rows($mysql_link_vcl)) {
		$user['id'] = mysql_insert_id($mysql_link_vcl);
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
		$row = mysql_fetch_assoc($qh);
		$affilid = $row['id'];
		# prepend shib- and escape it for mysql
		$grp = mysql_real_escape_string("shib-" . $name);
		array_push($newusergroups, getUserGroupID($grp, $affilid));
	}

	$query = "SELECT id, name FROM affiliation WHERE shibname = '$shibaffil'";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	$affilid = $row['id'];
	$grp = mysql_real_escape_string("All {$row['name']} Users");
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
	global $mysql_link_vcl;
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
	if(mysql_affected_rows($mysql_link_vcl))
		return dbLastInsertID();
	else
		return NULL;
}

?>
