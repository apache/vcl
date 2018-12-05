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

require_once 'CAS.php';

// Enable debugging
phpCAS::setDebug();
// Enable verbose error messages. Disable in production!
phpCAS::setVerbose(FALSE);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn validateCASUser($type, $loginid)
///
/// \param $type - an array from the $authMechs table
///
/// \return 1 user redirectied to CAS server, 0 if not, -1 on CAS error
///
/// \brief forces CAS authentication
///
////////////////////////////////////////////////////////////////////////////////
function validateCASUser($type) {
	global $authMechs;
	$auth = $authMechs[$type];
	$callbackURL = BASEURL . "/casauth/index.php?authtype=" . $type;
	$casversion = ($auth['version'] == 2 ? CAS_VERSION_2_0 : CAS_VERSION_3_0);

	if($auth['cacertpath'] != null)
		if(file_exists($auth['cacertpath']))
			phpCAS::setCasServerCACert($auth['cacertpath']);

	phpCAS::client($casversion, $auth['host'], $auth['port'], $auth['context']);

	// Set the service URL to use custom casauth directly within the VCL website
	phpCAS::setFixedServiceURL($callbackURL);
	if($auth['validatecassslcerts'] != true)
		phpCAS::setNoCasServerValidation();

	phpCAS::forceAuthentication();

	# TODO - Check if server is available. 
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkCASUserInDatabase($userid)
///
/// \param $type - an array from the $authMechs table
/// \param $userid - a userid without the affiliation part
///
/// \return true if the user exists in the database, else false
///
/// \brief looks up $userid in VCL database
///
////////////////////////////////////////////////////////////////////////////////
function checkCASUserInDatabase($type, $userid) {
	global $authMechs, $mysql_link_vcl;
	$loweruserid = strtolower($userid);
	$loweruserid = mysql_real_escape_string($loweruserid);
	$query = "SELECT id "
	       . "FROM user "
	       . "WHERE unityid = '$userid' AND "
	       .       "affiliationid = {$authMechs[$type]['affiliationid']}";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		return TRUE;
	}
	return FALSE;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addCASUser($authtype, $userid)
///
/// \param $userinfo - an array with user information
///
/// \return id from the user table or NULL on failure
///
/// \brief looks up $userid in CAS according to info in $authMechs array, adds
/// the user to the user table, and returns the new id from the table
///
////////////////////////////////////////////////////////////////////////////////
function addCASUser($userinfo) {
	global $authMechs, $mysql_link_vcl;
	$now = unixToDatetime(time());
	if(array_key_exists('firstname', $userinfo))
		$esc_firstname = mysql_real_escape_string($userinfo['firstname']);
	if(array_key_exists('lastname', $userinfo))
		$esc_lastname = mysql_real_escape_string($userinfo['lastname']);
	if(array_key_exists('preferredname', $userinfo))
		$esc_preferredname = mysql_real_escape_string($userinfo['preferredname']);
	$query = "INSERT INTO user (unityid, affiliationid";
	if(array_key_exists('firstname', $userinfo))
		$query .= ", firstname";
	if(array_key_exists('lastname', $userinfo))
		$query .= ", lastname";
	if(array_key_exists('preferredname', $userinfo))
		$query .= ", preferredname";
	if(array_key_exists('email', $userinfo))
		$query .= ", email";
	$query .= ", lastupdated) VALUES ( '{$userinfo['unityid']}', {$userinfo['affiliationid']}";
	if(array_key_exists('firstname', $userinfo))
		$query .= ",'{$esc_firstname}'";
	if(array_key_exists('lastname', $userinfo))
		$query .= ",'{$esc_lastname}'";
	if(array_key_exists('preferredname', $userinfo))
		$query .= ",'{$esc_preferredname}'";
	if(array_key_exists('email', $userinfo))
		$query .= ",'{$userinfo['email']}'";
		$query .= ",'{$now}')";

	doQuery($query, 101, 'vcl', 1);
	if(mysql_affected_rows($mysql_link_vcl)) {
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM user", 101);
		if(! $row = mysql_fetch_row($qh)) {
			abort(101);
		}

		// Add to default group
		if($userinfo['defaultgroup'] != null) {
			$usergroups = array();
			array_push($usergroups, getUserGroupID($userinfo['defaultgroup'], $userinfo['affiliationid']));
			updateGroups($usergroups, $row[0]);
		}

		return $row[0];
	}
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateCASUser($authtype, $userid)
///
/// \param $userinfo - an array with user information
///
/// \return FALSE if update failed, else TRUE
///
/// \brief pulls the user's information from CAS, updates it in the db, and
/// returns an array of the information
///
////////////////////////////////////////////////////////////////////////////////
function updateCASUser($userinfo) {
	global $mysql_link_vcl;
	$now = unixToDatetime(time());
	$esc_userid = mysql_real_escape_string($userinfo['unityid']);
	if(array_key_exists('firstname', $userinfo))
		$esc_firstname = mysql_real_escape_string($userinfo['firstname']);
	if(array_key_exists('lastname', $userinfo))
		$esc_lastname = mysql_real_escape_string($userinfo['lastname']);
	if(array_key_exists('preferredname', $userinfo))
		$esc_preferredname = mysql_real_escape_string($userinfo['preferredname']);
	$query = "UPDATE user SET unityid = '{$userinfo['unityid']}', lastupdated = '{$now}'";
	if(array_key_exists('firstname', $userinfo))
		$query .= ", firstname = '{$esc_firstname}' ";
	if(array_key_exists('lastname', $userinfo))
		$query .= ", lastname = '{$esc_lastname}' ";
	if(array_key_exists('preferredname', $userinfo))
		$query .= ", preferredname = '{$esc_preferredname}' ";
	if(array_key_exists('email', $userinfo))
		$query .= ", email = '{$userinfo['email']}' ";
	$query .= "WHERE unityid = '{$esc_userid}' AND affiliationid = {$userinfo['affiliationid']}";
	doQuery($query, 256, 'vcl', 1);
	if(mysql_affected_rows($mysql_link_vcl) == -1) {
		error_log(mysql_error($mysql_link_vcl));
		error_log($query);
		return FALSE;
	}

	// get id of current user
	$query = "SELECT id FROM user WHERE unityid = '{$esc_userid}' AND affiliationid = {$userinfo['affiliationid']}";
	$qh = doQuery($query, 255);
	if($user = mysql_fetch_assoc($qh)) {
		// Add to default group
		if($userinfo['defaultgroup'] != null) {
			$usergroups = array();
			$newgroupid = getUserGroupID($userinfo['defaultgroup'], $userinfo['affiliationid']);
			array_push($usergroups, $newgroupid);
			$usergroups = array_unique($usergroups);
			if(! empty($usergroups))
				updateGroups($usergroups, $user["id"]);
		}
	}

	return TRUE;
}
?>
