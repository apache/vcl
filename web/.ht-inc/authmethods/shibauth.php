<?php
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
	getAffilidAndLogin($userid, $affilid);

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
			$user['firstname'] = implode(' ', $names);
		}
	}
	else
		$user['firstname'] = $_SERVER['givenName'];
	if(array_key_exists('sn', $_SERVER))
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
	if(! $row = mysql_fetch_assoc($qh))
		# add user to our db
		return addShibUser($user);

	# update user's data in db
	$user['id'] = $row['id'];
	$first = mysql_escape_string($user['firstname']);
	$last = mysql_escape_string($user['lastname']);
	$query = "UPDATE user "
	       . "SET firstname = '$first', "
	       .     "lastname = '$last', ";
	if(array_key_exists('email', $user)) {
		$email = mysql_escape_string($user['email']);
		$query .= "email = '$email', ";
	}
	$query .=    "emailnotices = 0, " 
	       .     "lastupdated = NOW() " 
	       . "WHERE uid = {$user['id']}";
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
/// \return an array with all of the values from $user along with an additional
/// key named 'id' that is the new user's id from the user table
///
/// \brief adds $user to the user table
///
////////////////////////////////////////////////////////////////////////////////
function addShibUser($user) {
	global $mysql_link_vcl;
	$unityid = mysql_escape_string($user['unityid']);
	$first = mysql_escape_string($user['firstname']);
	$last = mysql_escape_string($user['lastname']);
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
		$email = mysql_escape_string($user['email']);
		$query .=    "'$email', ";
	}
	$query .=       "0, "
	       .        "NOW())";
	doQuery($query, 101, 'vcl', 1);
	if(mysql_affected_rows($mysql_link_vcl)) {
		$user['id'] = mysql_insert_id($mysql_link_vcl);
		return $user;
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
///
/// \brief converts the shibboleth affiliation to VCL affiliation, prepends
/// 'shib-' to each of the group names and calls updateGroups to add the user
/// to each of the shibboleth groups
///
////////////////////////////////////////////////////////////////////////////////
function updateShibGroups($usernid, $groups) {
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
		$grp = mysql_escape_string("shib-" . $name);
		array_push($newusergroups, getUserGroupID($grp, $affilid));
	}
	$newusergroups = array_unique($newusergroups);
	if(! empty($newusergroups))
		updateGroups($newusergroups, $usernid);
}

?>
