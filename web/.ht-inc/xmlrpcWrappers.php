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
 * The functions listed here are for making VCL requests from other applications.
 * They are implemented according to the XML RPC spec defined at 
 * http://www.xmlrpc.com/ \n
 * There is one function called \b XMLRPCtest() that can be used during 
 * initial development to get started without actually making a request.\n
 * \n
 * The URL you will use to submit RPC calls is the URL for your VCL site
 * followed by\n\n
 * index.php?mode=xmlrpccall\n\n
 * for example if the URL for your VCL site is\n\n
 * https://vcl.mysite.org/vcl/\n\n
 * the RPC URL would be\n\n
 * https://vcl.mysite.org/vcl/index.php?mode=xmlrpccall\n\n
 * There is one exception - when calling the XMLRPCaffiliations function, the
 * mode is xmlrpcaffiliations, for example:\n\n
 * https://vcl.mysite.org/vcl/index.php?mode=xmlrpcaffiliations\n\n
 * Your application must connect using HTTPS.\n\n
 * Internal to the VCL code, "Reservations" are called "Requests"; therefore,
 * "request" is used instead of "reservation" in this documentation and in the
 * RPC functions.
 * \n
 * <h2>API Version 2</h2>
 * This is the current version of the API. It should be used for any new code
 * development. Any older code needs to be migrated to this version.\n\n
 * Authentication is handled by 2 additional HTTP headers you will need to
 * send:\n
 * \b X-User - the userid you would use to log in to the VCL site, followed
 * by the at sign (@), followed by your affiliation\n
 * example: myuserid\@NCSU\n
 * You can obtain a list of the affiliations by using the XMLRPCaffiliations()
 * call\n\n
 * \b X-Pass - the password you would use to log in to the VCL site\n
 * \n
 * There is one other additional HTTP header you must send:\n
 * \b X-APIVERSION - set this to 2\n\n
 * The X-User and X-Pass HTTP headers do not need to be passed to call the
 * XMLRPCaffiliations() function.
 */

/// \example xmlrpc_example.php

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaffiliations()
///
/// \return an array of affiliation arrays, each with 2 indices:\n
/// \b id - id of the affiliation\n
/// \b name - name of the affiliation
///
/// \brief gets all of the affilations for which users can log in to VCL\n
/// \b NOTE: This is the only function available for which the X-User and X-Pass
/// HTTP headers do not need to be passed
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaffiliations() {
	$affils = getAffiliations();
	$return = array();
	foreach($affils as $key => $val) {
		$tmp = array('id' => $key, 'name' => $val);
		array_push($return, $tmp);
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCtest($string)
///
/// \param $string - a string
///
/// \return an array with 3 indices:\n
/// \b status - will be 'success'\n
/// \b message - will be 'RPC call worked successfully'\n
/// \b string - contents of $string (after being sanatized)
///
/// \brief this is a test function that call be called when getting XML RPC
/// calls to this site to work
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCtest($string) {
	$string = processInputData($string, ARG_STRING);
	return array('status' => 'success',
	             'message' => 'RPC call worked successfully',
	             'string' => $string);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetImages()
///
/// \return an array of image arrays, each with these indices:\n
/// \b id - id of the image\n
/// \b name - name of the image\n
/// \b description - description of image\n
/// \b usage - usage instructions for image
///
/// \brief gets the images to which the user has access
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetImages() {
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);
	$return = array();
	$images = getImages();
	foreach($resources['image'] as $key => $val) {
		$notes = getImageNotes($key);
		$tmp = array('id' => $key,
		             'name' => $val,
		             'description' => $notes['description'],
		             'usage' => $notes['usage'],
		             'ostype' => $images[$key]['ostype']);
		array_push($return, $tmp);
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddRequest($imageid, $start, $length, $foruser, $nousercheck)
///
/// \param $imageid - id of an image
/// \param $start - "now" or unix timestamp for start of reservation; will
/// use a floor function to round down to the nearest 15 minute increment
/// for actual reservation
/// \param $length - length of reservation in minutes (must be in 15 minute
/// increments)
/// \param $foruser - (optional) login to be used when setting up the account
/// on the reserved machine - CURRENTLY, THIS IS UNSUPPORTED
/// \param $nousercheck - (optional, default=0) set to 1 to disable timeout
/// when user is disconnected for too long
///
/// \return an array with at least one index named '\b status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b notavailable - no computers were available for the request\n
/// \b success - there will be an additional element in the array:
/// \li \b requestid - identifier that should be passed to later calls when
/// acting on the request
///
/// \brief tries to make a request
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddRequest($imageid, $start, $length, $foruser='',
                          $nousercheck=0) {
	global $user;
	$imageid = processInputData($imageid, ARG_NUMERIC);
	$start = processInputData($start, ARG_STRING, 1);
	$length = processInputData($length, ARG_NUMERIC);
	#$foruser = processInputData($foruser, ARG_STRING, 1);

	// make sure user didn't submit a request for an image he 
	// doesn't have access to
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$validImageids = array_keys($resources['image']);
	if(! in_array($imageid, $validImageids)) {
		return array('status' => 'error',
		             'errorcode' => 3,
		             'errormsg' => "access denied to $imageid");
	}

	# validate $start
	if($start != 'now' && ! is_numeric($start)) {
		return array('status' => 'error',
		             'errorcode' => 4,
		             'errormsg' => "received invalid input for start");
	}

	# validate $length
	$maxtimes = getUserMaxTimes();
	if($maxtimes['initial'] < $length) {
		return array('status' => 'error',
		             'errorcode' => 6,
		             'errormsg' => "max allowed initial length is {$maxtimes['initial']} minutes");
	}

	$nowfuture = 'future';
	if($start == 'now') {
		$start = time();
		$nowfuture = 'now';
	}
	else
		if($start < (time() - 30))
			return array('status' => 'error',
			             'errorcode' => 5,
			             'errormsg' => "start time is in the past");
	$start = unixFloor15($start);
	$end = $start + $length * 60;
	if($end % (15 * 60))
		$end = unixFloor15($end) + (15 * 60);

	$max = getMaxOverlap($user['id']);
	if(checkOverlap($start, $end, $max)) {
		return array('status' => 'error',
		             'errorcode' => 7,
		             'errormsg' => "reservation overlaps with another one you "
		                         . "have, and you are allowed $max "
		                         . "overlapping reservations at a time");
	}

	if($nousercheck == 1) {
		$groupid = getUserGroupID('Allow No User Check', 1);
		$members = getUserGroupMembers($groupid);
		if(! array_key_exists($user['id'], $members))
			$nousercheck = 0;
	}
	else
		$nousercheck = 0;

	$images = getImages();
	$revisionid = getProductionRevisionid($imageid);
	$rc = isAvailable($images, $imageid, $revisionid, $start, $end, 1);
	if($rc < 1) {
		addLogEntry($nowfuture, unixToDatetime($start), 
		            unixToDatetime($end), 0, $imageid);
		return array('status' => 'notavailable');
	}
	$return['requestid']= addRequest(0, array(), (1 - $nousercheck));
	$return['status'] = 'success';
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddRequestWithEnding($imageid, $start, $end, $foruser,
///                                $nousercheck)
///
/// \param $imageid - id of an image
/// \param $start - "now" or unix timestamp for start of reservation; will
/// use a floor function to round down to the nearest 15 minute increment
/// for actual reservation
/// \param $end - unix timestamp for end of reservation; will be rounded up to
/// the nearest 15 minute increment
/// \param $foruser - (optional) login to be used when setting up the account
/// on the reserved machine - CURRENTLY, THIS IS UNSUPPORTED
/// \param $nousercheck - (optional, default=0) set to 1 to disable timeout
/// when user is disconnected for too long
///
/// \return an array with at least one index named '\b status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b notavailable - no computers were available for the request\n
/// \b success - there will be an additional element in the array:
/// \li \b requestid - identifier that should be passed to later calls when
/// acting on the request
///
/// \brief tries to make a request with the specified ending time
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddRequestWithEnding($imageid, $start, $end, $foruser='',
                                    $nousercheck=0) {
	global $user;
	$imageid = processInputData($imageid, ARG_NUMERIC);
	$start = processInputData($start, ARG_STRING, 1);
	$end = processInputData($end, ARG_STRING);
	#$foruser = processInputData($foruser, ARG_STRING, 1);

	// make sure user is a member of the 'Specify End Time' group
	$groupid = getUserGroupID('Specify End Time');
	$members = getUserGroupMembers($groupid);
	if(! array_key_exists($user['id'], $members)) {
		return array('status' => 'error',
		             'errorcode' => 35,
		             'errormsg' => "access denied to specify end time");
	}

	// make sure user didn't submit a request for an image he
	// doesn't have access to
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$validImageids = array_keys($resources['image']);
	if(! in_array($imageid, $validImageids)) {
		return array('status' => 'error',
		             'errorcode' => 3,
		             'errormsg' => "access denied to $imageid");
	}

	# validate $start
	if($start != 'now' && ! is_numeric($start)) {
		return array('status' => 'error',
		             'errorcode' => 4,
		             'errormsg' => "received invalid input for start");
	}

	# validate $end
	if(! is_numeric($end)) {
		return array('status' => 'error',
		             'errorcode' => 36,
		             'errormsg' => "received invalid input for end");
	}
	if($start != 'now' && $start >= $end) {
		return array('status' => 'error',
		             'errorcode' => 37,
		             'errormsg' => "start must be less than end");
	}

	$nowfuture = 'future';
	if($start == 'now') {
		$start = time();
		$nowfuture = 'now';
	}
	else
		if($start < (time() - 30))
			return array('status' => 'error',
			             'errorcode' => 5,
			             'errormsg' => "start time is in the past");
	$start = unixFloor15($start);
	if($end % (15 * 60))
		$end = unixFloor15($end) + (15 * 60);

	$max = getMaxOverlap($user['id']);
	if(checkOverlap($start, $end, $max)) {
		return array('status' => 'error',
		             'errorcode' => 7,
		             'errormsg' => "reservation overlaps with another one you "
		                         . "have, and you are allowed $max "
		                         . "overlapping reservations at a time");
	}

	if($nousercheck == 1) {
		$groupid = getUserGroupID('Allow No User Check', 1);
		$members = getUserGroupMembers($groupid);
		if(! array_key_exists($user['id'], $members))
			$nousercheck = 0;
	}
	else
		$nousercheck = 0;

	$images = getImages();
	$revisionid = getProductionRevisionid($imageid);
	$rc = isAvailable($images, $imageid, $revisionid, $start, $end, 1);
	if($rc < 1) {
		addLogEntry($nowfuture, unixToDatetime($start), 
		            unixToDatetime($end), 0, $imageid);
		return array('status' => 'notavailable');
	}
	$return['requestid']= addRequest(0, array(), (1 - $nousercheck));
	$return['status'] = 'success';
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCdeployServer($imageid, $start, $end, $admingroup, $logingroup,
///                        $ipaddr, $macaddr, $monitored, $foruser, $name,
///                        $userdata)
///
/// \param $imageid - id of an image
/// \param $start - "now" or unix timestamp for start of reservation; will
/// use a floor function to round down to the nearest 15 minute increment
/// for actual reservation
/// \param $end - "indefinite" or unix timestamp for end of reservation; will
/// use a floor function to round up to the nearest 15 minute increment
/// for actual reservation
/// \param $admingroup - (optional, default='') admin user group for reservation
/// \param $logingroup - (optional, default='') login user group for reservation
/// \param $ipaddr - (optional, default='') IP address to use for public IP of
/// server
/// \param $macaddr - (optional, default='') MAC address to use for public NIC
/// of server
/// \param $monitored - (optional, default=0) whether or not the server should
/// be monitored - CURRENTLY, THIS IS UNSUPPORTED
/// \param $foruser - (optional) login to be used when setting up the account
/// on the reserved machine - CURRENTLY, THIS IS UNSUPPORTED
/// \param $name - (optional) name for reservation
/// \param $userdata - (optional) text that will be placed in 
/// /root/.vclcontrol/post_reserve_userdata on the reserved node
///
/// \return an array with at least one index named '\b status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b notavailable - no computers were available for the request\n
/// \b success - there will be an additional element in the array:
/// \li \b requestid - identifier that should be passed to later calls when
/// acting on the request
///
/// \brief tries to make a server request
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCdeployServer($imageid, $start, $end, $admingroup='',
                            $logingroup='', $ipaddr='', $macaddr='',
                            $monitored=0, $foruser='', $name='',
                            $userdata='') {
	global $user, $remoteIP;
	if(! in_array("serverCheckOut", $user["privileges"])) {
		return array('status' => 'error',
		             'errorcode' => 60,
		             'errormsg' => "access denied to deploy server");
	}
	$imageid = processInputData($imageid, ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources["image"]);
	#$extraimages = getServerProfileImages($user['id']);
	if(! array_key_exists($imageid, $images) /*&&
		! array_key_exists($imageid, $extraimages)*/) {
		return array('status' => 'error',
		             'errorcode' => 3,
		             'errormsg' => "access denied to $imageid");
	}
	if($admingroup != '') {
		$admingroup = processInputData($admingroup, ARG_STRING);
		if(get_magic_quotes_gpc())
			$admingroup = stripslashes($admingroup);
		if(preg_match('/@/', $admingroup)) {
			$tmp = explode('@', $admingroup);
			$escadmingroup = mysql_real_escape_string($tmp[0]);
			$affilid = getAffiliationID($tmp[1]);
			if(is_null($affilid)) {
				return array('status' => 'error',
				             'errorcode' => 51,
				             'errormsg' => "unknown affiliation for admin user group: {$tmp[1]}");
			}
		}
		else {
			$escadmingroup = mysql_real_escape_string($admingroup);
			$affilid = DEFAULT_AFFILID;
		}
		$admingroupid = getUserGroupID($escadmingroup, $affilid, 1);
		if(is_null($admingroupid)) {
			return array('status' => 'error',
			             'errorcode' => 52,
			             'errormsg' => "unknown admin user group: $admingroup");
		}
	}
	else
		$admingroupid = '';
	if($logingroup != '') {
		$logingroup = processInputData($logingroup, ARG_STRING);
		if(get_magic_quotes_gpc())
			$logingroup = stripslashes($logingroup);
		if(preg_match('/@/', $logingroup)) {
			$tmp = explode('@', $logingroup);
			$esclogingroup = mysql_real_escape_string($tmp[0]);
			$affilid = getAffiliationID($tmp[1]);
			if(is_null($affilid)) {
				return array('status' => 'error',
				             'errorcode' => 54,
				             'errormsg' => "unknown affiliation for login user group: {$tmp[1]}");
			}
		}
		else {
			$esclogingroup = mysql_real_escape_string($logingroup);
			$affilid = DEFAULT_AFFILID;
		}
		$logingroupid = getUserGroupID($esclogingroup, $affilid, 1);
		if(is_null($logingroupid)) {
			return array('status' => 'error',
			             'errorcode' => 55,
			             'errormsg' => "unknown login user group: $logingroup");
		}
	}
	else
		$logingroupid = '';
	$ipaddr = processInputData($ipaddr, ARG_STRING);
	$ipaddrArr = explode('.', $ipaddr);
	if($ipaddr != '' && (! preg_match('/^(([0-9]){1,3}\.){3}([0-9]){1,3}$/', $ipaddr) ||
		$ipaddrArr[0] < 1 || $ipaddrArr[0] > 255 ||
		$ipaddrArr[1] < 0 || $ipaddrArr[1] > 255 ||
		$ipaddrArr[2] < 0 || $ipaddrArr[2] > 255 ||
		$ipaddrArr[3] < 0 || $ipaddrArr[3] > 255)) {
		return array('status' => 'error',
		             'errorcode' => 57,
		             'errormsg' => "Invalid IP address. Must be w.x.y.z with each of "
		                         . "w, x, y, and z being between 1 and 255 (inclusive)");
	}
	$macaddr = processInputData($macaddr, ARG_STRING);
	if($macaddr != '' && ! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $macaddr)) {
		return array('status' => 'error',
		             'errorcode' => 58,
		             'errormsg' => "Invalid MAC address.  Must be XX:XX:XX:XX:XX:XX "
		                         . "with each pair of XX being from 00 to FF (inclusive)");
	}
	$monitored = processInputData($monitored, ARG_NUMERIC);
	if($monitored != 0 && $monitored != 1)
		$monitored = 0;
	$start = processInputData($start, ARG_STRING, 1);
	$end = processInputData($end, ARG_STRING, 1);
	#$foruser = processInputData($foruser, ARG_STRING, 1);

	$name = processInputData($name, ARG_STRING);
	if(get_magic_quotes_gpc())
		$name = stripslashes($name);
	if(! preg_match('/^([-a-zA-Z0-9_\. ]){0,255}$/', $name)) {
		return array('status' => 'error',
		             'errorcode' => 58,
						 'errormsg' => "Invalid name. Can only contain letters, numbers, "
		                         . "spaces, dashes(-), underscores(_), and periods(.) "
		                         . "and be up to 255 characters long");
	}
	$name = mysql_real_escape_string($name);

	# validate $start
	if($start != 'now' && ! is_numeric($start)) {
		return array('status' => 'error',
		             'errorcode' => 4,
		             'errormsg' => "received invalid input for start");
	}
	# validate $end
	if($end != 'indefinite' && ! is_numeric($end)) {
		return array('status' => 'error',
		             'errorcode' => 59,
		             'errormsg' => "received invalid input for end");
	}

	$nowfuture = 'future';
	if($start == 'now') {
		$start = unixFloor15(time());
		$nowfuture = 'now';
	}
	else
		if($start < (time() - 30))
			return array('status' => 'error',
			             'errorcode' => 5,
			             'errormsg' => "start time is in the past");
	if($end == 'indefinite')
		$end = datetimeToUnix("2038-01-01 00:00:00");
	elseif($end % (15 * 60))
		$end = unixFloor15($end) + (15 * 60);
	elseif($end < ($start + 900))
		return array('status' => 'error',
		             'errorcode' => 88,
		             'errormsg' => "end time must be at least 15 minutes after start time");

	$max = getMaxOverlap($user['id']);
	if(checkOverlap($start, $end, $max)) {
		return array('status' => 'error',
		             'errorcode' => 7,
		             'errormsg' => "reservation overlaps with another one you "
		                         . "have, and you are allowed $max "
		                         . "overlapping reservations at a time");
	}

	$images = getImages();
	$revisionid = getProductionRevisionid($imageid);
	$rc = isAvailable($images, $imageid, $revisionid, $start, $end,
	                  1, 0, 0, 0, 0, $ipaddr, $macaddr);
	if($rc < 1) {
		addLogEntry($nowfuture, unixToDatetime($start), 
		            unixToDatetime($end), 0, $imageid);
		return array('status' => 'notavailable');
	}
	$return['requestid']= addRequest();
	$query = "UPDATE reservation "
	       . "SET remoteIP = '$remoteIP' "
	       . "WHERE requestid = {$return['requestid']}";
	doQuery($query);
	if($userdata != '') {
		if(get_magic_quotes_gpc())
			$userdata = stripslashes($userdata);
		$esc_userdata = mysql_real_escape_string($userdata);
		$query = "INSERT INTO variable "
		       .        "(name, "
		       .        "serialization, "
		       .        "value, "
		       .        "setby, "
		       .        "timestamp) "
		       . "SELECT CONCAT('userdata|', id), "
		       .        "'none', "
		       .        "'$esc_userdata', "
		       .        "'webcode', "
		       .        "NOW() "
		       . "FROM reservation "
		       . "WHERE requestid = {$return['requestid']}";
		doQuery($query);
	}
	$fields = array('requestid');
	$values = array($return['requestid']);
	if($name != '') {
		$fields[] = 'name';
		$values[] = "'$name'";
	}
	if($ipaddr != '') {
		$fields[] = 'fixedIP';
		$values[] = "'$ipaddr'";
	}
	if($macaddr != '') {
		$fields[] = 'fixedMAC';
		$values[] = "'$macaddr'";
	}
	if($admingroupid != 0) {
		$fields[] = 'admingroupid';
		$values[] = $admingroupid;
	}
	if($logingroupid != 0) {
		$fields[] = 'logingroupid';
		$values[] = $logingroupid;
	}
	if($monitored != 0) {
		$fields[] = 'monitored';
		$values[] = 1;
	}
	$allfields = implode(',', $fields);
	$allvalues = implode(',', $values);
	$query = "INSERT INTO serverrequest ($allfields) VALUES ($allvalues)";
	doQuery($query, 101);
	$return['status'] = 'success';
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetRequestIds()
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - request was successfully found; there will be an additional
/// element whose index is 'requests' which is an array of arrays, each having
/// these elements (or empty if no existing requests):\n
/// \li \b requestid - id of the request\n
/// \li \b imageid - id of the image\n
/// \li \b imagename - name of the image\n
/// \li \b start - unix timestamp of start time\n
/// \li \b end - unix timestamp of end time\n
/// \li \b OS - name of OS used in image\n
/// \li \b isserver - 0 or 1 - whether or not this is a server reservation\n
/// \li \b state - current state of reservation\n
/// \li \b servername - only included if isserver == 1 - name of the reservation
///
/// \brief gets information about all of user's requests
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetRequestIds() {
	global $user;
	$requests = getUserRequests("all");
	if(empty($requests))
		return array('status' => 'success', 'requests' => array());
	$states = getStates();
	$ret = array();
	foreach($requests as $req) {
		$start = datetimeToUnix($req['start']);
		$end = datetimeToUnix($req['end']);
		$tmp = array('requestid' => $req['id'],
		             'imageid' => $req['imageid'],
		             'imagename' => $req['prettyimage'],
		             'start' => $start,
		             'end' => $end,
		             'OS' => $req['OS'],
		             'ostype' => $req['ostype'],
		             'isserver' => $req['server'],
		             'admin' => $req['serveradmin'],
		             'serverowner' => $req['serverowner']);
		if($req['currstateid'] == 14)
			$tmp['state'] = $states[$req['laststateid']];
		else
			$tmp['state'] = $states[$req['currstateid']];
		if($req['server'])
			$tmp['servername'] = $req['servername'];
		array_push($ret, $tmp);
	}
	return array('status' => 'success', 'requests' => $ret);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetRequestStatus($requestid)
///
/// \param $requestid - id of a request
///
/// \return an array with at least one index named '\b status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b ready - request is ready\n
/// \b failed - request failed to load properly\n
/// \b timedout - request timed out (user didn't connect before timeout
/// expired)\n
/// \b loading - request is still loading; there will be an additional element
/// in the array:
/// \li \b time - the estimated wait time (in minutes) for loading to complete\n
///
/// \b future - start time of request is in the future\n
///
/// \brief determines and returns the status of the request
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetRequestStatus($requestid) {
	global $user;
	$requestid = processInputData($requestid, ARG_NUMERIC);
	$userRequests = getUserRequests('all', $user['id']);
	$found = 0;
	foreach($userRequests as $req) {
		if($req['id'] == $requestid) {
			$request = $req;
			$found = 1;
			break;
		}
	}
	if(! $found)
		return array('status' => 'error',
		             'errorcode' => 1,
		             'errormsg' => 'unknown requestid');

	$now = time();
	# request is ready
	if(requestIsReady($request))
		return array('status' => 'ready');
	# request failed
	elseif($request["currstateid"] == 5)
		return array('status' => 'failed');
	# request maintenance
	elseif($request["currstateid"] == 10)
		return array('status' => 'maintenance');
	# request image
	elseif($request["currstateid"] == 16 ||
	       $request["currstateid"] == 24 ||
	       ($request["currstateid"] == 14 &&
	       ($request["laststateid"] == 16 ||
	       $request["laststateid"] == 24)))
		return array('status' => 'image');
	# other cases where the reservation start time has been reached
	elseif(datetimeToUnix($request["start"]) < $now) {
		# request has timed out
		if($request["currstateid"] == 12 ||
		   $request["currstateid"] == 11 ||
		   ($request["currstateid"] == 14 &&
		   $request["laststateid"] == 11)) {
			return array('status' => 'timedout');
		}
		# computer is loading
		else {
			$imageid = $request['imageid'];
			$images = getImages(0, $imageid);
			$remaining = 1;
			$computers = getComputers(0, 0, $request['computerid']);
			if(isComputerLoading($request, $computers)) {
				if(datetimeToUnix($request["daterequested"]) >=
					datetimeToUnix($request["start"]))
					$startload = datetimeToUnix($request["daterequested"]);
				else
					$startload = datetimeToUnix($request["start"]);
				$imgLoadTime = getImageLoadEstimate($imageid);
				if($imgLoadTime == 0)
					$imgLoadTime = $images[$imageid]['reloadtime'] * 60;
				$tmp = ($imgLoadTime - ($now - $startload)) / 60;
				$remaining = sprintf("%d", $tmp) + 1;
				if($remaining < 1) {
					$remaining = 1;
				}
			}
			return array('status' => 'loading', 'time' => $remaining);
		}
	}
	# reservation is in the future
	else
		return array('status' => 'future');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetRequestConnectData($requestid, $remoteIP)
///
/// \param $requestid - id of a request
/// \param $remoteIP - ip address of connecting user's computer
///
/// \return an array with at least one index named '\b status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b ready - request is ready; there will be 3 additional elements in the
/// array:\n
/// \li \b serverIP - address of the reserved machine
/// \li \b user - user to use when connecting to the machine
/// \li \b password - password to use when connecting to the machine
///
/// \b notready - request is not ready for connection
///
/// \brief if request is ready, adds the connecting user's computer to the
/// request and returns info about how to connect to the computer
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetRequestConnectData($requestid, $remoteIP) {
	global $user;
	$requestid = processInputData($requestid, ARG_NUMERIC);
	$remoteIP = processInputData($remoteIP, ARG_STRING, 1);
	if(! preg_match('/^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$/', $remoteIP, $matches) ||
	   $matches[1] < 1 || $matches[1] > 223 ||
	   $matches[2] > 255 ||
	   $matches[3] > 255 ||
	   $matches[4] > 255) {
		return array('status' => 'error',
		             'errorcode' => 2,
		             'errormsg' => 'invalid IP address');
	}
	$userRequests = getUserRequests('all', $user['id']);
	$found = 0;
	foreach($userRequests as $req) {
		if($req['id'] == $requestid) {
			$request = $req;
			$found = 1;
			break;
		}
	}
	if(! $found)
		return array('status' => 'error',
		             'errorcode' => 1,
		             'errormsg' => 'unknown requestid');

	// FIXME - add support for cluster requests
	if(requestIsReady($request)) {
		$requestData = getRequestInfo($requestid);
		$query = "UPDATE reservation "
		       . "SET remoteIP = '$remoteIP' "
		       . "WHERE requestid = $requestid";
		$qh = doQuery($query, 101);
		addChangeLogEntry($requestData["logid"], $remoteIP);
		$serverIP = $requestData["reservations"][0]["connectIP"];
		$passwd = $requestData["reservations"][0]["password"];
		$connectMethods = getImageConnectMethodTexts(
		                     $requestData["reservations"][0]["imageid"],
		                     $requestData["reservations"][0]["imagerevisionid"]);
		if(preg_match('/(.*)@(.*)/', $user['unityid'], $matches))
			$thisuser = $matches[1];
		else
			$thisuser = $user['unityid'];
		$natports = getNATports($requestData['reservations'][0]['reservationid']);
		$portdata = array();
		foreach($connectMethods as $key => $cm) {
			$connecttext = $cm["connecttext"];
			$connecttext = preg_replace("/#userid#/", $thisuser, $connecttext); 
			$connecttext = preg_replace("/#password#/", $passwd, $connecttext); 
			$connecttext = preg_replace("/#connectIP#/", $serverIP, $connecttext); 
			foreach($cm['ports'] as $port) {
				if(! empty($natports) && array_key_exists($port['key'], $natports[$key])) {
					$connecttext = preg_replace("/{$port['key']}/", $natports[$key][$port['key']]['publicport'], $connecttext); 
					$connectMethods[$key]['connectports'][] = "{$port['protocol']}:{$port['port']}:{$natports[$key][$port['key']]['publicport']}";
				}
				else {
					if((preg_match('/remote desktop/i', $cm['description']) ||
					   preg_match('/RDP/i', $cm['description'])) && 
					   $port['key'] == '#Port-TCP-3389#') {
						$connecttext = preg_replace("/{$port['key']}/", $user['rdpport'], $connecttext); 
						$connectMethods[$key]['connectports'][] = "{$port['protocol']}:{$port['port']}:{$user['rdpport']}";
					}
					else {
						$connecttext = preg_replace("/{$port['key']}/", $port['port'], $connecttext); 
						$connectMethods[$key]['connectports'][] = "{$port['protocol']}:{$port['port']}:{$port['port']}";
					}
				}
			}
			$connectMethods[$key]["connecttext"] = $connecttext;
			$portdata[$key] = $connectMethods[$key]['ports'];
			unset($connectMethods[$key]['ports']);
		}
		$tmp = array_keys($portdata);
		$cmid = $tmp[0];
		if(empty($natports))
			if((preg_match('/remote desktop/i', $connectMethods[$cmid]['description']) ||
			   preg_match('/RDP/i', $connectMethods[$cmid]['description'])) && 
				$portdata[$cmid][0]['port'] == 3389)
				$connectport = $user['rdpport'];
			else
				$connectport = $portdata[$cmid][0]['port'];
		else {
			$key = $portdata[$cmid][0]['key'];
			$connectport = $natports[$cmid][$key]['publicport'];
		}
		return array('status' => 'ready',
		             'serverIP' => $serverIP,
		             'user' => $thisuser,
		             'password' => $passwd,
		             'connectport' => $connectport,
		             'connectMethods' => $connectMethods);
	}
	return array('status' => 'notready');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCextendRequest($requestid, $extendtime)
///
/// \param $requestid - id of a request
/// \param $extendtime - time in minutes to extend reservation
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - request was successfully extended\n
///
/// \brief extends the length of an active request; if a request that has not
/// started needs to be extended, delete the request and submit a new one
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCextendRequest($requestid, $extendtime) {
	global $user;
	$requestid = processInputData($requestid, ARG_NUMERIC);
	$extendtime = processInputData($extendtime, ARG_NUMERIC);

	$userRequests = getUserRequests('all', $user['id']);
	$found = 0;
	foreach($userRequests as $req) {
		if($req['id'] == $requestid) {
			$request = getRequestInfo($requestid);
			$found = 1;
			break;
		}
	}
	if(! $found)
		return array('status' => 'error',
		             'errorcode' => 1,
		             'errormsg' => 'unknown requestid');

	$startts = datetimeToUnix($request['start']);
	$endts = datetimeToUnix($request['end']);
	$newendts = $endts + ($extendtime * 60);
	if($newendts % (15 * 60))
		$newendts= unixFloor15($newendts) + (15 * 60);

	// check for maintenance state
	if($request['stateid'] == 10 ||
	   ($request['stateid'] == 14 &&
	   $request['laststateid'] == 10)) {
		return array('status' => 'error',
		             'errorcode' => 103,
		             'errormsg' => 'reservation in maintenance state');
	}

	// check for image state
	if($request['stateid'] == 16 ||
	   $request['stateid'] == 24 ||
	   ($request['stateid'] == 14 &&
	   ($request['laststateid'] == 16 ||
	   $request['laststateid'] == 24))) {
		return array('status' => 'error',
		             'errorcode' => 104,
		             'errormsg' => 'reservation being captured');
	}

	// check that reservation has started
	if($startts > time()) {
		return array('status' => 'error',
		             'errorcode' => 38,
		             'errormsg' => 'reservation has not started');
	}

	// check for allowed extension length
	$maxtimes = getUserMaxTimes();
	if($extendtime > $maxtimes['extend']) {
		return array('status' => 'error',
		             'errorcode' => 39,
		             'errormsg' => 'extendtime exceeds allowable extension',
		             'allowed' => $maxtimes['extend']);
	}
	$newlength = ($endts - $startts) / 60 + $extendtime;
	if($newlength > $maxtimes['total']) {
		return array('status' => 'error',
		             'errorcode' => 40,
		             'errormsg' => 'new reservation length exceeds allowable length',
		             'allowed' => $maxtimes['total']);
	}

	// check for overlap
	$max = getMaxOverlap($user['id']);
	if(checkOverlap($startts, $newendts, $max, $requestid)) {
		return array('status' => 'error',
		             'errorcode' => 41,
		             'errormsg' => 'overlapping reservation restriction',
		             'maxoverlap' => $max);
	}

	// check for computer being available for extended time?
	$timeToNext = timeToNextReservation($request);
	$movedall = 1;
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$tmp = array_keys($resources['image']);
	$semimageid = $tmp[0];
	$semrevid = getProductionRevisionid($semimageid);
	if($timeToNext > -1) {
		$lockedall = 1;
		if(count($request['reservations']) > 1) {
			# get semaphore on each existing node in cluster so that nothing 
			# can get moved to the nodes during this process
			$checkend = unixToDatetime($endts + 900);
			foreach($request["reservations"] as $res) {
				if(! retryGetSemaphore($semimageid, $semrevid, $res['managementnodeid'], $res['computerid'], $request['start'], $checkend, $requestid)) {
					$lockedall = 0;
					break;
				}
			}
		}
		if($lockedall) {
			foreach($request["reservations"] as $res) {
				if(! moveReservationsOffComputer($res["computerid"])) {
					$movedall = 0;
					break;
				}
			}
		}
		else {
			cleanSemaphore();
			return array('status' => 'error',
			             'errorcode' => 42,
			             'errormsg' => 'cannot extend due to another reservation immediately after this one');
		}
		cleanSemaphore();
	}
	if(! $movedall) {
		$timeToNext = timeToNextReservation($request);
		if($timeToNext >= 15)
			$timeToNext -= 15;
		// reservation immediately after this one, cannot extend
		if($timeToNext < 15) {
			return array('status' => 'error',
			             'errorcode' => 42,
			             'errormsg' => 'cannot extend due to another reservation immediately after this one');
		}
		// check that requested extension < $timeToNext
		elseif($extendtime > $timeToNext) {
			$extra = $timeToNext - ($timeToNext % 15);
			return array('status' => 'error',
			             'errorcode' => 43,
			             'errormsg' => 'cannot extend by requested amount',
			             'availablelength' => $extra);
		}
	}
	$rc = isAvailable(getImages(), $request['reservations'][0]["imageid"],
	                  $request['reservations'][0]['imagerevisionid'],
	                  $startts, $newendts, 1, $requestid);
	// conflicts with scheduled maintenance
	if($rc == -2) {
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($newendts),
		                  $request['start'], NULL, NULL, 0);
		return array('status' => 'error',
		             'errorcode' => 46,
		             'errormsg' => 'requested time is during a maintenance window');
	}
	// concurrent license overlap
	elseif($rc == -1) {
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($newendts),
		                  $request['start'], NULL, NULL, 0);
		return array('status' => 'error',
		             'errorcode' => 44,
		             'errormsg' => 'concurrent license restriction');
	}
	// could not extend for some other reason
	elseif($rc == 0) {
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($newendts),
		                  $request['start'], NULL, NULL, 0);
		return array('status' => 'error',
		             'errorcode' => 45,
		             'errormsg' => 'cannot extend at this time');
	}
	// success
	updateRequest($requestid, 'now');
	cleanSemaphore();
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCsetRequestEnding($requestid, $end)
///
/// \param $requestid - id of a request
/// \param $end - unix timestamp for end of reservation; will be rounded up to
/// the nearest 15 minute increment
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - request was successfully extended\n
///
/// \brief modifies the end time of an active request; if a request that has not
/// started needs to be modifed, delete the request and submit a new one
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCsetRequestEnding($requestid, $end) {
	global $user;

	$requestid = processInputData($requestid, ARG_NUMERIC);
	$userRequests = getUserRequests('all', $user['id']);
	$found = 0;
	foreach($userRequests as $req) {
		if($req['id'] == $requestid) {
			$request = getRequestInfo($requestid);
			$found = 1;
			break;
		}
	}
	if(! $found)
		return array('status' => 'error',
		             'errorcode' => 1,
		             'errormsg' => 'unknown requestid');

	// make sure user is a member of the 'Specify End Time' group
	$groupid = getUserGroupID('Specify End Time');
	$members = getUserGroupMembers($groupid);
	if(! $request['serverrequest'] && ! array_key_exists($user['id'], $members)) {
		return array('status' => 'error',
		             'errorcode' => 35,
		             'errormsg' => "access denied to specify end time");
	}

	$end = processInputData($end, ARG_NUMERIC);

	$maxend = datetimeToUnix("2038-01-01 00:00:00");
	if($end < 0 || $end > $maxend) {
		return array('status' => 'error',
		             'errorcode' => 36,
		             'errormsg' => "received invalid input for end");
	}

	// check for maintenance state
	if($request['stateid'] == 10 ||
	   ($request['stateid'] == 14 &&
	   $request['laststateid'] == 10)) {
		return array('status' => 'error',
		             'errorcode' => 103,
		             'errormsg' => 'reservation in maintenance state');
	}

	// check for image state
	if($request['stateid'] == 16 ||
	   $request['stateid'] == 24 ||
	   ($request['stateid'] == 14 &&
	   ($request['laststateid'] == 16 ||
	   $request['laststateid'] == 24))) {
		return array('status' => 'error',
		             'errorcode' => 104,
		             'errormsg' => 'reservation being captured');
	}

	$startts = datetimeToUnix($request['start']);
	if($end % (15 * 60))
		$end= unixFloor15($end) + (15 * 60);

	// check that reservation has started
	if($startts > time()) {
		return array('status' => 'error',
		             'errorcode' => 38,
		             'errormsg' => 'reservation has not started');
	}

	// check for overlap
	$max = getMaxOverlap($user['id']);
	if(checkOverlap($startts, $end, $max, $requestid)) {
		return array('status' => 'error',
		             'errorcode' => 41,
		             'errormsg' => 'overlapping reservation restriction',
		             'maxoverlap' => $max);
	}

	// check for computer being available for extended time?
	$timeToNext = timeToNextReservation($request);
	$movedall = 1;
	if($timeToNext > -1) {
		$lockedall = 1;
		if(count($request['reservations']) > 1) {
			# get semaphore on each existing node in cluster so that nothing 
			# can get moved to the nodes during this process
			$unixend = datetimeToUnix($request['end']);
			$checkend = unixToDatetime($unixend + 900);
			$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
			$tmp = array_keys($resources['image']);
			$semimageid = $tmp[0];
			$semrevid = getProductionRevisionid($semimageid);
			foreach($request["reservations"] as $res) {
				if(! retryGetSemaphore($semimageid, $semrevid, $res['managementnodeid'], $res['computerid'], $request['start'], $checkend, $requestid)) {
					$lockedall = 0;
					break;
				}
			}
		}
		if($lockedall) {
			foreach($request["reservations"] as $res) {
				if(! moveReservationsOffComputer($res["computerid"])) {
					$movedall = 0;
					break;
				}
			}
		}
		else {
			cleanSemaphore();
			return array('status' => 'error',
			             'errorcode' => 42,
			             'errormsg' => 'cannot extend due to another reservation immediately after this one');
		}
		cleanSemaphore();
	}
	if(! $movedall) {
		$timeToNext = timeToNextReservation($request);
		if($timeToNext >= 15)
			$timeToNext -= 15;
		$oldendts = datetimeToUnix($request['end']);
		// reservation immediately after this one, cannot extend
		if($timeToNext < 15) {
			return array('status' => 'error',
			             'errorcode' => 42,
			             'errormsg' => 'cannot extend due to another reservation immediately after this one');
		}
		// check that requested extension < $timeToNext
		elseif((($end - $oldendts) / 60) > $timeToNext) {
			$maxend = $oldendts + ($timeToNext * 60);
			return array('status' => 'error',
			             'errorcode' => 43,
			             'errormsg' => 'cannot extend by requested amount due to another reservation',
			             'maxend' => $maxend);
		}
	}
	$rc = isAvailable(getImages(), $request['reservations'][0]["imageid"],
	                  $request['reservations'][0]['imagerevisionid'],
	                  $startts, $end, 1, $requestid);
	// conflicts with scheduled maintenance
	if($rc == -2) {
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($end),
		                  $request['start'], NULL, NULL, 0);
		return array('status' => 'error',
		             'errorcode' => 46,
		             'errormsg' => 'requested time is during a maintenance window');
	}
	// concurrent license overlap
	elseif($rc == -1) {
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($end),
		                  $request['start'], NULL, NULL, 0);
		return array('status' => 'error',
		             'errorcode' => 44,
		             'errormsg' => 'concurrent license restriction');
	}
	// could not extend for some other reason
	elseif($rc == 0) {
		addChangeLogEntry($request["logid"], NULL, unixToDatetime($end),
		                  $request['start'], NULL, NULL, 0);
		return array('status' => 'error',
		             'errorcode' => 45,
		             'errormsg' => 'cannot extend at this time');
	}
	// success
	updateRequest($requestid, 'now');
	cleanSemaphore();
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCendRequest($requestid)
///
/// \param $requestid - id of a request
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - request was successfully ended\n
///
/// \brief ends/deletes a request
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCendRequest($requestid) {
	global $user;
	$requestid = processInputData($requestid, ARG_NUMERIC);
	$userRequests = getUserRequests('all', $user['id']);
	$found = 0;
	foreach($userRequests as $req) {
		if($req['id'] == $requestid) {
			$request = getRequestInfo($requestid);
			$found = 1;
			break;
		}
	}
	if(! $found)
		return array('status' => 'error',
		             'errorcode' => 1,
		             'errormsg' => 'unknown requestid');

	deleteRequest($request);
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCautoCapture($requestid)
///
/// \param $requestid - id of request to be captured
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - image was successfully set to be captured
///
/// \brief creates entries in appropriate tables to capture an image and sets
/// the request state to image
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCautoCapture($requestid) {
	global $user, $xmlrpcBlockAPIUsers;
	if(! in_array($user['id'], $xmlrpcBlockAPIUsers)) {
		return array('status' => 'error',
		             'errorcode' => 47,
		             'errormsg' => 'access denied to XMLRPCautoCapture');
	}
	$query = "SELECT id FROM request WHERE id = $requestid";
	$qh = doQuery($query, 101);
	if(! mysql_num_rows($qh)) {
		return array('status' => 'error',
		             'errorcode' => 52,
		             'errormsg' => 'specified request does not exist');
	}
	$reqData = getRequestInfo($requestid);
	# check state of reservation
	if($reqData['stateid'] != 14 || $reqData['laststateid'] != 8) {
		return array('status' => 'error',
		             'errorcode' => 51,
		             'errormsg' => 'reservation not in valid state');
	}
	# check that not a cluster reservation
	if(count($reqData['reservations']) > 1) {
		return array('status' => 'error',
		             'errorcode' => 48,
		             'errormsg' => 'cannot image a cluster reservation');
	}
	require_once(".ht-inc/image.php");
	$imageid = $reqData['reservations'][0]['imageid'];
	$imageData = getImages(0, $imageid);
	$captime = unixToDatetime(time());
	$comments = "start: {$reqData['start']}<br>"
	          . "end: {$reqData['end']}<br>"
	          . "computer: {$reqData['reservations'][0]['reservedIP']}<br>"
	          . "capture time: $captime";
	# create new revision if requestor is owner and not a kickstart image
	if($imageData[$imageid]['installtype'] != 'kickstart' &&
	   $reqData['userid'] == $imageData[$imageid]['ownerid']) {
		$rc = Image::AJupdateImage($requestid, $reqData['userid'], $comments, 1);
		if($rc == 0) {
			return array('status' => 'error',
			             'errorcode' => 49,
			             'errormsg' => 'error encountered while attempting to create new revision');
		}
	}
	# create a new image if requestor is not owner or a kickstart image
	else {
		$ownerdata = getUserInfo($reqData['userid'], 1, 1);
		$desc = "This is an autocaptured image.<br>"
		      . "captured from image: {$reqData['reservations'][0]['prettyimage']}<br>"
		      . "captured on: $captime<br>"
		      . "owner: {$ownerdata['unityid']}@{$ownerdata['affiliation']}<br>";
		$connectmethods = getImageConnectMethods($imageid, $reqData['reservations'][0]['imagerevisionid']);
		$data = array('requestid' => $requestid,
		              'desc' => $desc,
		              'usage' => '',
		              'owner' => "{$ownerdata['unityid']}@{$ownerdata['affiliation']}",
		              'name' => "Autocaptured ({$ownerdata['unityid']} - $requestid)",
		              'ram' => 64,
		              'cores' => 1,
		              'cpuspeed' => 500,
		              'networkspeed' => 10,
		              'concurrent' => '',
		              'checkuser' => 1,
		              'rootaccess' => 1,
		              'checkout' => 1,
		              'sysprep' => 1,
		              'basedoffrevisionid' => $reqData['reservations'][0]['imagerevisionid'],
		              'platformid' => $imageData[$imageid]['platformid'],
		              'osid' => $imageData[$imageid]["osid"],
		              'ostype' => $imageData[$imageid]["ostype"],
		              'sethostname' => $imageData[$imageid]["sethostname"],
		              'reload' => 20,
		              'comments' => $comments,
		              'connectmethodids' => implode(',', array_keys($connectmethods)),
		              'adauthenabled' => $imageData[$imageid]['adauthenabled'],
		              'autocaptured' => 1);
		if($data['adauthenabled']) {
			$data['addomainid'] = $imageData[$imageid]['addomainid'];
			$data['baseou'] = $imageData[$imageid]['baseOU'];
		}
		$obj = new Image();
		$imageid = $obj->addResource($data);
		if($imageid == 0) {
			return array('status' => 'error',
			             'errorcode' => 50,
			             'errormsg' => 'error encountered while attempting to create image');
		}

		$query = "UPDATE request rq, "
		       .        "reservation rs "
		       . "SET rs.imageid = $imageid, "
		       .     "rs.imagerevisionid = {$obj->imagerevisionid}, "
		       .     "rq.stateid = 16  "
		       . "WHERE rq.id = $requestid AND "
		       .       "rq.id = rs.requestid";
		doQuery($query);
	}
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetGroupImages($name)
///
/// \param $name - the name of an imageGroup
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - returns an array of images; there will be an additional element
/// in the array with an index of 'images' that is an array of images with
/// each element having the following two keys:\n
/// \li \b id - id of the image\n
/// \li \b name - name of the image
///
/// \brief gets a list of all images in a particular group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetGroupImages($name) {
	if($groupid = getResourceGroupID("image/$name")) {
		$membership = getResourceGroupMemberships('image');
		$resources = getUserResources(array("imageAdmin"), array("manageGroup"));

		$images = array();
		foreach($resources['image'] as $imageid => $image) {
			if(array_key_exists($imageid, $membership['image']) &&
			   in_array($groupid, $membership['image'][$imageid]))
				array_push($images, array('id' => $imageid, 'name' => $image));
		}
		return array('status' => 'success',
		             'images' => $images);

	}
	else {
		return array('status' => 'error',
		             'errorcode' => 83,
		             'errormsg' => 'invalid resource group name');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddImageToGroup($name, $imageid)
///
/// \param $name - the name of an imageGroup
/// \param $imageid - the id of an image
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - image was added to the group\n
///
/// \brief adds an image to a resource group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddImageToGroup($name, $imageid) {
	if($groupid = getResourceGroupID("image/$name")) {
		$groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
		if(! array_key_exists($groupid, $groups['image'])) {
			return array('status' => 'error',
			             'errorcode' => 46,
			             'errormsg' => 'Unable to access image group');
		}
		$resources = getUserResources(array("imageAdmin"), array("manageGroup"));
		if(! array_key_exists($imageid, $resources['image'])) {
			return array('status' => 'error',
			             'errorcode' => 47,
			             'errormsg' => 'Unable to access image');
		}

		$allimages = getImages(0, $imageid);
		$query = "INSERT IGNORE INTO resourcegroupmembers "
		       .        "(resourceid, "
		       .        "resourcegroupid) "
		       . "VALUES "
		       .       "({$allimages[$imageid]['resourceid']}, "
		       .       "$groupid)";
		doQuery($query);
		return array('status' => 'success');
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 83,
		             'errormsg' => 'invalid resource group name');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveImageFromGroup($name, $imageid)
///
/// \param $name - the name of an imageGroup
/// \param $imageid - the id of an image
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - image was removed from the group\n
///
/// \brief removes an image from a resource group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveImageFromGroup($name, $imageid) {
	if($groupid = getResourceGroupID("image/$name")) {
		$groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
		if(! array_key_exists($groupid, $groups['image'])) {
			return array('status' => 'error',
			             'errorcode' => 46,
			             'errormsg' => 'Unable to access image group');
		}
		$resources = getUserResources(array("imageAdmin"), array("manageGroup"));
		if(! array_key_exists($imageid, $resources['image'])) {
			return array('status' => 'error',
			             'errorcode' => 47,
			             'errormsg' => 'Unable to access image');
		}

		$allimages = getImages(0, $imageid);
		$query = "DELETE FROM resourcegroupmembers "
		       . "WHERE resourceid = {$allimages[$imageid]['resourceid']} AND "
		       .       "resourcegroupid = $groupid";
		doQuery($query);
		return array('status' => 'success');
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 83,
		             'errormsg' => 'invalid resource group name');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddImageGroupToComputerGroup($imageGroup, $computerGroup)
///
/// \param $imageGroup - the name of an imageGroup
/// \param $computerGroup - the name of a computerGroup
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - successfully mapped an image group to a computer group\n
///
/// \brief map an image group to a computer group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddImageGroupToComputerGroup($imageGroup, $computerGroup) {
	$imageid = getResourceGroupID("image/$imageGroup");
	$compid = getResourceGroupID("computer/$computerGroup");
	if($imageid && $compid) {
		$tmp = getUserResources(array("imageAdmin"),
		                        array("manageMapping"), 1);
		$imagegroups = $tmp['image'];
		$tmp = getUserResources(array("computerAdmin"),
		                        array("manageMapping"), 1);
		$computergroups = $tmp['computer'];

		if(array_key_exists($compid, $computergroups) &&
			array_key_exists($imageid, $imagegroups)) {
			$mapping = getResourceMapping("image", "computer",
			                              $imageid, $compid);
			if(! array_key_exists($imageid, $mapping) ||
			   ! in_array($compid, $mapping[$imageid])) {
				$query = "INSERT INTO resourcemap "
				       .        "(resourcegroupid1, "
				       .        "resourcetypeid1, "
				       .        "resourcegroupid2, "
				       .        "resourcetypeid2) "
				       . "VALUES ($imageid, "
				       .         "13, "
				       .         "$compid, "
				       .         "12)";
				doQuery($query, 101);
			}
			return array('status' => 'success');
		}
		else {
			return array('status' => 'error',
			             'errorcode' => 84,
			             'errormsg' => 'cannot access computer and/or image group');
		}
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 83,
		             'errormsg' => 'invalid resource group name');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveImageGroupFromComputerGroup($imageGroup, $computerGroup)
///
/// \param $imageGroup - the name of an imageGroup
/// \param $computerGroup - the name of a computerGroup
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - successfully removed the mapping from an image group to a
/// computer group\n
///
/// \brief remove the mapping of an image group to a computer group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveImageGroupFromComputerGroup($imageGroup, $computerGroup) {
	$imageid = getResourceGroupID("image/$imageGroup");
	$compid = getResourceGroupID("computer/$computerGroup");
	if($imageid && $compid) {
		$tmp = getUserResources(array("imageAdmin"),
		                        array("manageMapping"), 1);
		$imagegroups = $tmp['image'];
		$tmp = getUserResources(array("computerAdmin"),
		                        array("manageMapping"), 1);
		$computergroups = $tmp['computer'];

		if(array_key_exists($compid, $computergroups) &&
			array_key_exists($imageid, $imagegroups)) {
			$mapping = getResourceMapping("image", "computer",
			                              $imageid, $compid);
			if(array_key_exists($imageid, $mapping) &&
			   in_array($compid, $mapping[$imageid])) {
				$query = "DELETE FROM resourcemap "
				       . "WHERE resourcegroupid1 = $imageid AND "
				       .       "resourcetypeid1 = 13 AND "
				       .       "resourcegroupid2 = $compid AND "
				       .       "resourcetypeid2 = 12";
				doQuery($query, 101);
			}
			return array('status' => 'success');
		}
		else {
			return array('status' => 'error',
			             'errorcode' => 84,
			             'errormsg' => 'cannot access computer and/or image group');
		}
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 83,
		             'errormsg' => 'invalid resource group name');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetNodes($root)
///
/// \param $root - (optional, default=top of tree) the ID of the node forming
/// the root of the hierarchy
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - returns an array of nodes; there will be an additional element
/// in the array with an index of 'nodes' that is an array of nodes with each
/// element having the following three keys:\n
/// \li \b id - id of the node\n
/// \li \b name - name of the node\n
/// \li \b parent - id of the parent node
///
/// \brief gets a list of all nodes in the privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetNodes($root=NULL) {
	global $user;
	if(in_array("userGrant", $user["privileges"]) ||
		in_array("resourceGrant", $user["privileges"]) ||
		in_array("nodeAdmin", $user["privileges"])) {
		$root = processInputData($root, ARG_NUMERIC);
		$topNodes = $root ? getChildNodes($root) : getChildNodes();
		$nodes = array();
		$stack = array();
		foreach($topNodes as $id => $node) {
			$node['id'] = $id;
			array_push($nodes, $node);
			array_push($stack, $node);
		} 
		while(count($stack)) {
			$item = array_shift($stack);
			$children = getChildNodes($item['id']);
			foreach($children as $id => $node) {
				$node['id'] = $id;
				array_push($nodes, $node);
				array_push($stack, $node);
			}
		}
		return array('status' => 'success',
		             'nodes' => $nodes);
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 70,
		             'errormsg' => 'User cannot access node content');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCnodeExists($nodeName, $parentNode)
///
/// \param $nodeName - the name of a node
/// \param $parentNode - the ID of the parent node
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - returns an 'exists' element set to either 1 or 0\n
///
/// \brief indicates whether a node with that name already exists at this
/// location in the privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCnodeExists($nodeName, $parentNode) {
	global $user;
	if(! is_numeric($parentNode)) {
		return array('status' => 'error',
		             'errorcode' => 78,
		             'errormsg' => 'Invalid nodeid specified');
	}
	if(in_array("userGrant", $user["privileges"]) ||
		in_array("resourceGrant", $user["privileges"]) ||
		in_array("nodeAdmin", $user["privileges"])) {
		if(get_magic_quotes_gpc())
			$nodeName = stripslashes($nodeName);
		$nodeName = mysql_real_escape_string($nodeName);
		// does a node with this name already exist?
		$query = "SELECT id "
		       . "FROM privnode "
		       . "WHERE name = '$nodeName' AND parent = $parentNode";
		$qh = doQuery($query, 335);
		if(mysql_num_rows($qh))
			return array('status' => 'success', 'exists' => TRUE);
		else
			return array('status' => 'success', 'exists' => FALSE);
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 70,
		             'errormsg' => 'User cannot access node content');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddNode($nodeName, $parentNode)
///
/// \param $nodeName - the name of the new node
/// \param $parentNode - the ID of the node parent
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - node was successfully added
///
/// \brief add a node to the privilege tree as a child of the specified parent
/// node
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddNode($nodeName, $parentNode) {
	require_once(".ht-inc/privileges.php");
	global $user;
	if(! is_numeric($parentNode)) {
		return array('status' => 'error',
		             'errorcode' => 78,
		             'errormsg' => 'Invalid nodeid specified');
	}
	if(in_array("nodeAdmin", $user['privileges'])) {
		$nodeInfo = getNodeInfo($parentNode);
		if(is_null($nodeInfo)) {
			return array('status' => 'error',
			             'errorcode' => 78,
			             'errormsg' => 'Invalid nodeid specified');
		}

		if(! validateNodeName($nodeName, $tmp)) {
			return array('status' => 'error',
			             'errorcode' => 81,
			             'errormsg' => 'Invalid node name');
		}

		if(checkUserHasPriv("nodeAdmin", $user['id'], $parentNode)) {
			$query = "SELECT id "
			       . "FROM privnode "
			       . "WHERE name = '$nodeName' AND parent = $parentNode";
			$qh = doQuery($query);
			if(mysql_num_rows($qh)) {
				return array('status' => 'error',
				             'errorcode' => 82,
				             'errormsg' => 'A node of that name already exists under ' . $nodeInfo['name']);
			}
			$query = "INSERT IGNORE INTO privnode "
			       .        "(parent, name) "
			       . "VALUES "
			       .        "($parentNode, '$nodeName')";
			doQuery($query);
			$qh = doQuery("SELECT LAST_INSERT_ID() FROM privnode", 101);
			if(! $row = mysql_fetch_row($qh)) {
				return array('status' => 'error',
				             'errorcode' => 85,
				             'errormsg' => 'Could not add node to database');
			}
			$nodeid = $row[0];
			return array('status' => 'success',
			             'nodeid' => $nodeid);
		}
		else {
			return array('status' => 'error',
			             'errorcode' => 49,
			             'errormsg' => 'Unable to add node at this location');
		}
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 70,
		             'errormsg' => 'User cannot access node content');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveNode($nodeID)
///
/// \param $nodeID - the ID of a node
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - node was successfully deleted
///
/// \brief delete a node from the privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveNode($nodeID) {
	require_once(".ht-inc/privileges.php");
	global $user;
	if(! is_numeric($nodeID)) {
		return array('status' => 'error',
		             'errorcode' => 78,
		             'errormsg' => 'Invalid nodeid specified');
	}
	if(! in_array("nodeAdmin", $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 70,
		             'errormsg' => 'User cannot administer nodes');
	}
	if(! checkUserHasPriv("nodeAdmin", $user['id'], $nodeID)) {
		return array('status' => 'error',
		             'errorcode' => 57,
		             'errormsg' => 'User cannot edit this node');
	}
	$nodes = recurseGetChildren($nodeID);
	array_push($nodes, $nodeID);
	$deleteNodes = implode(',', $nodes);
	$query = "DELETE FROM privnode "
	       . "WHERE id IN ($deleteNodes)";
	doQuery($query, 345);
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetUserGroupPrivs($name, $affiliation, $nodeid)
///
/// \param $name - the name of the user group
/// \param $affiliation - the affiliation of the group
/// \param $nodeid - the ID of the node in the privilege tree
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - an additional element is returned:\n
/// \li \b privileges - array of privileges assigned at the node
///
/// \brief get a list of privileges for a user group at a particular node in the
/// privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetUserGroupPrivs($name, $affiliation, $nodeid) {
	require_once(".ht-inc/privileges.php");
	global $user;

	if(! is_numeric($nodeid)) {
		return array('status' => 'error',
		             'errorcode' => 78,
		             'errormsg' => 'Invalid nodeid specified');
	}

	if(! in_array("userGrant", $user["privileges"]) &&
		! in_array("resourceGrant", $user["privileges"]) &&
		! in_array("nodeAdmin", $user["privileges"])) {
		return array('status' => 'error',
		             'errorcode' => 62,
		             'errormsg' => 'Unable to view user group privileges');
	}

	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;

	$groupid = $rc['id'];

	$privileges = array();
	$nodePrivileges = getNodePrivileges($nodeid, 'usergroups');
	$cascadedNodePrivileges = getNodeCascadePrivileges($nodeid, 'usergroups'); 
	$cngp = $cascadedNodePrivileges['usergroups'];
	$ngp = $nodePrivileges['usergroups'];
	if(array_key_exists($groupid, $cngp)) {
		foreach($cngp[$groupid]['privs'] as $p) {
			if(! array_key_exists($groupid, $ngp) ||
			   ! in_array("block", $ngp[$groupid]['privs']))
				array_push($privileges, $p);
		}
	}
	if(array_key_exists($groupid, $ngp)) {
		foreach($ngp[$groupid]['privs'] as $p) {
			if($p != "block")
				array_push($privileges, $p);
		}
	}

	return array('status' => 'success',
	              'privileges' => array_unique($privileges));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddUserGroupPriv($name, $affiliation, $nodeid, $permissions)
///
/// \param $name - the name of the user group
/// \param $affiliation - the affiliation of the user group
/// \param $nodeid - the ID of the node in the privilege tree
/// \param $permissions - a colon (:) delimited list of privileges to add
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - privileges were successfully added
///
/// \brief add privileges for a user group at a particular node in the
/// privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddUserGroupPriv($name, $affiliation, $nodeid, $permissions) {
	require_once(".ht-inc/privileges.php");
	global $user;

	if(! is_numeric($nodeid)) {
		return array('status' => 'error',
		             'errorcode' => 78,
		             'errormsg' => 'Invalid nodeid specified');
	}

	if(! checkUserHasPriv("userGrant", $user['id'], $nodeid)) {
		return array('status' => 'error',
		             'errorcode' => 52,
		             'errormsg' => 'Unable to add a user group to this node');
	}

	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;

	$groupid = $rc['id'];
	$perms = explode(':', $permissions);
	$usertypes = getTypes('users');
	array_push($usertypes["users"], "block");
	array_push($usertypes["users"], "cascade");

	$diff = array_diff($perms, $usertypes['users']);
	if(! count($perms) || count($diff) ||
	   (count($perms) == 1 && $perms[0] == 'cascade')) {
		return array('status' => 'error',
		             'errorcode' => 66,
		             'errormsg' => 'Invalid or missing permissions list supplied');
	}

	$cnp = getNodeCascadePrivileges($nodeid, "usergroups");
	$np = getNodePrivileges($nodeid, "usergroups", $cnp);

	if(array_key_exists($groupid, $np['usergroups'])) {
		$diff = array_diff($perms, $np['usergroups'][$groupid]['privs']);
		if(empty($diff))
			return array('status' => 'success');
	}
	else
		$diff = $perms;

	updateUserOrGroupPrivs($groupid, $nodeid, $diff, array(), "group");
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveUserGroupPriv($name, $affiliation, $nodeid,
///                                   $permissions)
///
/// \param $name - the name of the user group
/// \param $affiliation - the affiliation of the user group
/// \param $nodeid - the ID of the node in the privilege tree
/// \param $permissions - a colon (:) delimited list of privileges to remove
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - privileges were successfully removed
///
/// \brief remove privileges for a resource group at a particular node in the
/// privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveUserGroupPriv($name, $affiliation, $nodeid, $permissions) {
	require_once(".ht-inc/privileges.php");
	global $user;

	if(! is_numeric($nodeid)) {
		return array('status' => 'error',
		             'errorcode' => 78,
		             'errormsg' => 'Invalid nodeid specified');
	}

	if(! checkUserHasPriv("userGrant", $user['id'], $nodeid)) {
		return array('status' => 'error',
		             'errorcode' => 65,
		             'errormsg' => 'Unable to remove user group privileges on this node');
	}

	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;

	$groupid = $rc['id'];
	$perms = explode(':', $permissions);
	$usertypes = getTypes('users');
	array_push($usertypes["users"], "block");
	array_push($usertypes["users"], "cascade");

	$diff = array_diff($perms, $usertypes['users']);
	if(count($diff)) {
		return array('status' => 'error',
		             'errorcode' => 66,
		             'errormsg' => 'Invalid or missing permissions list supplied');
	}

	$cnp = getNodeCascadePrivileges($nodeid, "usergroups");
	$np = getNodePrivileges($nodeid, "usergroups");

	if(array_key_exists($groupid, $cnp['usergroups']) &&
	   (! array_key_exists($groupid, $np['usergroups']) ||
	   ! in_array('block', $np['usergroups'][$groupid]['privs']))) {
		$intersect = array_intersect($cnp['usergroups'][$groupid]['privs'], $perms);
		if(count($intersect)) {
			return array('status' => 'error',
			             'errorcode' => 80,
			             'errormsg' => 'Unable to modify privileges cascaded to this node');
		}
	}

	$diff = array_diff($np['usergroups'][$groupid]['privs'], $perms);
	if(count($diff) == 1 && in_array("cascade", $diff))
		array_push($perms, "cascade");

	updateUserOrGroupPrivs($groupid, $nodeid, array(), $perms, "group");
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetResourceGroupPrivs($name, $type, $nodeid)
///
/// \param $name - the name of the resource group
/// \param $type - the resource group type
/// \param $nodeid - the ID of the node in the privilege tree
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - an additional element is returned:\n
/// \li \b privileges - array of privileges assigned at the node
///
/// \brief get a list of privileges for a resource group at a particular node in
/// the privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetResourceGroupPrivs($name, $type, $nodeid) {
	require_once(".ht-inc/privileges.php");
	global $user;

	if(! is_numeric($nodeid)) {
		return array('status' => 'error',
		             'errorcode' => 78,
		             'errormsg' => 'Invalid nodeid specified');
	}

	if(! in_array("userGrant", $user["privileges"]) &&
		! in_array("resourceGrant", $user["privileges"]) &&
		! in_array("nodeAdmin", $user["privileges"])) {
		return array('status' => 'error',
		             'errorcode' => 63,
		             'errormsg' => 'Unable to view resource group privileges');
	}

	if($typeid = getResourceTypeID($type)) {
		if(! $groupid = getResourceGroupID("$type/$name")) {
			return array('status' => 'error',
			             'errorcode' => 74,
			             'errormsg' => 'resource group does not exist');
		}
		$np = getNodePrivileges($nodeid, 'resources');
		$cnp = getNodeCascadePrivileges($nodeid, 'resources'); 
		$key = "$type/$name/$groupid";
		if(isset($np['resources'][$key]['block']) || ! isset($cnp['resources'][$key]))
			$privs = array_keys($np['resources'][$key]);
		elseif(isset($cnp['resources'][$key]) && isset($np['resources'][$key])) {
			$allprivs = array_merge($cnp['resources'][$key], $np['resources'][$key]);
			$privs = array_keys($allprivs);
		}
		elseif(isset($cnp['resources'][$key]))
			$privs = array_keys($cnp['resources'][$key]);
		else
			$privs = array();
		return array('status' => 'success',
		             'privileges' => $privs);
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 71,
		             'errormsg' => 'Invalid resource type');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddResourceGroupPriv($name, $type, $nodeid, $permissions)
///
/// \param $name - the name of the resource group
/// \param $type - the resource group type
/// \param $nodeid - the ID of the node in the privilege tree
/// \param $permissions - a colon (:) delimited list of privileges to add
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - privileges were successfully added
///
/// \brief add privileges for a resource group at a particular node in the
/// privilege tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddResourceGroupPriv($name, $type, $nodeid, $permissions) {
	return _XMLRPCchangeResourceGroupPriv_sub('add', $name, $type, $nodeid,
	                                          $permissions);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveResourceGroupPriv($name, $type, $nodeid, $permissions)
///
/// \param $name - the name of the resource group
/// \param $type - the resource type
/// \param $nodeid - the ID of the node in the privilege tree
/// \param $permissions - a colon (:) delimited list of privileges to remove
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - privileges were successfully removed
///
/// \brief remove privileges for a resource group from a node in the privilege
/// tree
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveResourceGroupPriv($name, $type, $nodeid, $permissions) {
	return _XMLRPCchangeResourceGroupPriv_sub('remove', $name, $type, $nodeid,
	                                          $permissions);
}

##################################################################################
###
### fn _XMLRPCchangeResourceGroupPriv_sub($mode, $name, $type, $nodeid,
###                                       $permissions)
###
### param $mode - 'add' or 'remove'
### param $name - the name of the resource group
### param $type - the resource type
### param $nodeid - the ID of the node in the privilege tree
### param $permissions - a colon (:) delimited list of privileges to remove
###
### return an array with at least one index named 'status' which will have
### one of these values\n
### error - error occurred; there will be 2 additional elements in the array:
### * errorcode - error number\n
### * errormsg - error string\n
###
### success - privileges were successfully added or removed
###
### brief internal function to be called from XMLRPCremoveResourceGroupPriv and
### XMLRPCaddResourceGroupPriv - adds or removes privileges for a resource group
### from a node in the privilege tree
###
################################################################################
function _XMLRPCchangeResourceGroupPriv_sub($mode, $name, $type, $nodeid,
                                            $permissions) {
	require_once(".ht-inc/privileges.php");
	global $user;

	if(! is_numeric($nodeid)) {
		return array('status' => 'error',
		             'errorcode' => 78,
		             'errormsg' => 'Invalid nodeid specified');
	}

	if(! checkUserHasPriv("resourceGrant", $user['id'], $nodeid)) {
		return array('status' => 'error',
		             'errorcode' => 61,
		             'errormsg' => 'Unable to remove resource group privileges on this node');
	}

	$resourcetypes = getTypes('resources');
	if(! in_array($type, $resourcetypes['resources'])) {
		return array('status' => 'error',
		             'errorcode' => 71,
		             'errormsg' => 'Invalid resource type');
	}

	$groupid = getResourceGroupID("$type/$name");
	if(is_null($groupid)) {
		return array('status' => 'error',
		             'errorcode' => 74,
		             'errormsg' => 'resource group does not exist');
	}

	$changeperms = explode(':', $permissions);
	$allperms = getResourcePrivs();
	$diff = array_diff($changeperms, $allperms);
	if(count($diff)) {
		return array('status' => 'error',
		             'errorcode' => 66,
		             'errormsg' => 'Invalid or missing permissions list supplied');
	}

	$nocheckperms = array('block', 'cascade', 'available');
	$checkperms = array_diff($changeperms, $nocheckperms);

	$groupdata = getResourceGroups($type, $groupid);
	if(count($checkperms) &&
	   ! array_key_exists($groupdata[$groupid]["ownerid"], $user["groups"])) {
		return array('status' => 'error',
		             'errorcode' => 79,
		             'errormsg' => 'Unable to modify privilege set for resource group');
	}

	$key = "$type/$name/$groupid";
	$cnp = getNodeCascadePrivileges($nodeid, "resources");
	$np = getNodePrivileges($nodeid, 'resources');
	if(isset($cnp['resources'][$key]) && ! isset($np['resources'][$key]['block'])) {
		$intersect = array_intersect(array_keys($cnp['resources'][$key]), $changeperms);
		if(count($intersect)) {
			return array('status' => 'error',
			             'errorcode' => 80,
			             'errormsg' => 'Unable to modify privileges cascaded to this node');
		}
	}

	if($mode == 'remove') {
		if(! isset($np['resources'][$key]))
			return array('status' => 'success');
		$diff = array_diff(array_keys($np['resources'][$key]), $changeperms);
		if(count($diff) == 1 && in_array("cascade", $diff))
			$changeperms[] = 'cascade';
	}

	if($mode == 'add')
		updateResourcePrivs("$groupid", $nodeid, $changeperms, array());
	elseif($mode == 'remove')
		updateResourcePrivs("$groupid", $nodeid, array(), $changeperms);
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetUserGroups($groupType, $affiliationid)
///
/// \param $groupType - (optional, default=0) specify 0 for all groups, 1 for
/// only custom groups, 2 for only courseroll groups
/// \param $affiliationid - (optional, default=0) specifiy an affiliationid to
/// limit returned groups to only those matching the affiliation; pass 0 for
/// all affiliations
///
/// \return an array with two indices, one named 'status' which will have a
/// value of 'success', the other named 'groups' which will be an array of
/// arrays, each one having the following keys:\n
/// \li id\n
/// \li name\n
/// \li groupaffiliation\n
/// \li groupaffiliationid\n
/// \li ownerid\n
/// \li owner\n
/// \li affiliation\n
/// \li editgroupid\n
/// \li editgroup\n
/// \li editgroupaffiliationid\n
/// \li editgroupaffiliation\n
/// \li custom\n
/// \li courseroll\n
/// \li initialmaxtime\n
/// \li maxextendtime\n
/// \li overlapResCount
///
/// \brief builds a list of user groups
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetUserGroups($groupType=0, $affiliationid=0) {
	global $user;
	$groupType = processInputData($groupType, ARG_NUMERIC, 0, 0);
	$affiliationid = processInputData($affiliationid, ARG_NUMERIC, 0, 0);

	$groups = getUserGroups($groupType, $affiliationid);

	// Filter out any groups to which the user does not have access.
	$usergroups = array();
	foreach($groups as $id => $group) {
		if($group['ownerid'] == $user['id'] || 
		   (array_key_exists("editgroupid", $group) &&
		   array_key_exists($group['editgroupid'], $user["groups"])) || 
		   (array_key_exists($id, $user["groups"]))) {
			array_push($usergroups, $group);
		}
	}
	return array("status" => "success",
	             "groups" => $usergroups);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetUserGroupAttributes($name, $affiliation)
///
/// \param $name - name of user group
/// \param $affiliation - affiliation of user group
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - there will be six additional elements in this case:
/// \li \b owner - user that will be the owner of the group in
///                username\@affiliation form
/// \li \b managingGroup - user group that can manage membership of this one in
///                        groupname\@affiliation form
/// \li \b initialMaxTime - (minutes) max initial time users in this group can
///                         select for length of reservations
/// \li \b totalMaxTime - (minutes) total length users in the group can have for
///                       a reservation (including all extensions)
/// \li \b maxExtendTime - (minutes) max length of time users can request as an
///                        extension to a reservation at a time
/// \li \b overlapResCount - maximum allowed number of overlapping reservations
/// allowed for users in this group
///
/// \brief gets information about a user group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetUserGroupAttributes($name, $affiliation) {
	global $user;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;
	$query = "SELECT ug.id, "
	       .        "ug.ownerid, "
	       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
	       .        "ug.editusergroupid AS editgroupid, "
	       .        "eug.name AS editgroup, "
	       .        "eug.affiliationid AS editgroupaffiliationid, "
	       .        "euga.name AS editgroupaffiliation, "
	       .        "ug.initialmaxtime, "
	       .        "ug.totalmaxtime, "
	       .        "ug.maxextendtime, "
	       .        "ug.overlapResCount "
	       . "FROM usergroup ug "
	       . "LEFT JOIN user u ON (ug.ownerid = u.id) "
	       . "LEFT JOIN affiliation a ON (u.affiliationid = a.id) "
	       . "LEFT JOIN usergroup eug ON (ug.editusergroupid = eug.id) "
	       . "LEFT JOIN affiliation euga ON (eug.affiliationid = euga.id) "
	       . "WHERE ug.id = {$rc['id']}";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 18,
		             'errormsg' => 'user group with submitted name and affiliation does not exist');
	}
	// if not owner and not member of managing group, no access
	if($user['id'] != $row['ownerid'] && 
	   ! array_key_exists($row['editgroupid'], $user['groups'])) {
		return array('status' => 'error',
		             'errorcode' => 69,
		             'errormsg' => 'access denied to user group with submitted name and affiliation');
	}
	$ret = array('status' => 'success',
	             'owner' => $row['owner'],
	             'managingGroup' => "{$row['editgroup']}@{$row['editgroupaffiliation']}",
	             'initialMaxTime' => $row['initialmaxtime'],
	             'totalMaxTime' => $row['totalmaxtime'],
	             'maxExtendTime' => $row['maxextendtime'],
	             'overlapResCount' => $row['overlapResCount']);
	return $ret;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddUserGroup($name, $affiliation, $owner, $managingGroup,
///                        $initialMaxTime, $totalMaxTime, $maxExtendTime,
///                        $custom)
///
/// \param $name - name of user group
/// \param $affiliation - affiliation of user group
/// \param $owner - user that will be the owner of the group in
///                 username\@affiliation form
/// \param $managingGroup - user group that can manage membership of this one
/// \param $initialMaxTime - (minutes) max initial time users in this group can
///                          select for length of reservations
/// \param $totalMaxTime - (minutes) total length users in the group can have
///                        for a reservation (including all extensions)
/// \param $maxExtendTime - (minutes) max length of time users can request as an
///                         extension to a reservation at a time
/// \param $custom - (optional, default=1) set custom flag for user group; if
///                set to 0, $owner and $managingGroup will be ignored and group
///                membership will be managed via authentication protocol
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string
///
/// \b success - user group was successfully created
///
/// \brief creates a new user group with the specified parameters
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddUserGroup($name, $affiliation, $owner, $managingGroup,
                            $initialMaxTime, $totalMaxTime, $maxExtendTime,
                            $custom=1) {
	global $user;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation,
	                  'owner' => $owner,
	                  'managingGroup' => $managingGroup,
	                  'initialMaxTime' => $initialMaxTime,
	                  'totalMaxTime' => $totalMaxTime,
	                  'maxExtendTime' => $maxExtendTime,
	                  'custom' => $custom);
	$rc = validateAPIgroupInput($validate, 0);
	if($rc['status'] == 'error')
		return $rc;
	if($custom != 0 && $custom != 1)
		$custom = 1;
	if(! $custom)
		$rc['managingGroupID'] = NULL;
	$data = array('type' => 'user',
	              'owner' => $owner,
	              'name' => $name,
	              'affiliationid' => $rc['affiliationid'],
	              'editgroupid' => $rc['managingGroupID'],
	              'initialmax' => $initialMaxTime,
	              'totalmax' => $totalMaxTime,
	              'maxextend' => $maxExtendTime,
	              'overlap' => 0,
	              'custom' => $custom);
	if(! addGroup($data)) {
		return array('status' => 'error',
		             'errorcode' => 26,
		             'errormsg' => 'failure while adding group to database');
	}
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCeditUserGroup($name, $affiliation, $newName, $newAffiliation,
///                         $newOwner, $newManagingGroup, $newInitialMaxTime,
///                         $newTotalMaxTime, $newMaxExtendTime)
///
/// \param $name - name of user group
/// \param $affiliation - affiliation of user group
/// \param $newName - new name for user group
/// \param $newAffiliation - new affiliation for user group
/// \param $newOwner - (optional, default='') user that will be the owner of
///                    the group in username\@affiliation form
/// \param $newManagingGroup - (optional, default='') user group that can
///                            manage membership of this one
/// \param $newInitialMaxTime - (optional, default='') (minutes) max initial
///                             time users in this group can select for length
///                             of reservations
/// \param $newTotalMaxTime - (optional, default='') (minutes) total length
///                           users in the group can have for a reservation
///                           (including all extensions)
/// \param $newMaxExtendTime - (optional, default='') (minutes) max length of
///                            time users can request as an extension to a
///                            reservation at a time
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - user group was successfully updated
///
/// \brief modifies attributes of a user group\n
/// \b NOTE: an empty string may be passed for any of the new* fields to leave
/// that item unchanged
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCeditUserGroup($name, $affiliation, $newName, $newAffiliation,
                             $newOwner='', $newManagingGroup='',
                             $newInitialMaxTime='', $newTotalMaxTime='',
                             $newMaxExtendTime='') {
	global $user, $mysql_link_vcl;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}

	$updates = array();

	# validate group exists and new values other than newName and newAffiliation
	#   are valid
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	if(get_magic_quotes_gpc())
		$newOwner = stripslashes($newOwner);
	if(! empty($newOwner))
		$validate['owner'] = $newOwner;
	if(! empty($newManagingGroup))
		$validate['managingGroup'] = $newManagingGroup;
	if(! empty($newInitialMaxTime)) {
		$validate['initialMaxTime'] = $newInitialMaxTime;
		$updates[] = "initialmaxtime = $newInitialMaxTime";
	}
	if(! empty($newTotalMaxTime)) {
		$validate['totalMaxTime'] = $newTotalMaxTime;
		$updates[] = "totalmaxtime = $newTotalMaxTime";
	}
	if(! empty($newMaxExtendTime)) {
		$validate['maxExtendTime'] = $newMaxExtendTime;
		$updates[] = "maxextendtime = $newMaxExtendTime";
	}
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;

	# get info about group
	$query = "SELECT ownerid, "
	       .        "affiliationid, "
	       .        "custom, "
	       .        "courseroll "
	       . "FROM usergroup "
	       . "WHERE id = {$rc['id']}";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 18,
		             'errormsg' => 'user group with submitted name and affiliation does not exist');
	}
	// if custom and not owner or custom/courseroll and no federated user group access, no access to edit group
	if(($row['custom'] == 1 && $user['id'] != $row['ownerid']) ||
	   (($row['custom'] == 0 || $row['courseroll'] == 1) &&
	   ! checkUserHasPerm('Manage Federated User Groups (global)') &&
	   (! checkUserHasPerm('Manage Federated User Groups (affiliation only)') ||
	   $row['affiliationid'] != $user['affiliationid']))) {
		return array('status' => 'error',
		             'errorcode' => 32,
		             'errormsg' => 'access denied to modify attributes for user group with submitted name and affiliation');
	}

	# validate that newName and newAffiliation are valid
	if(($name != $newName || $affiliation != $newAffiliation) &&
	   (! empty($newName) || ! empty($newAffiliation))) {
		$validate = array('name' => $name,
		                  'affiliation' => $affiliation);
		if(! empty($newName)) {
			if(get_magic_quotes_gpc())
				$newName = stripslashes($newName);
			$validate['name'] = $newName;
			$tmp = mysql_real_escape_string($newName);
			$updates[] = "name = '$tmp'";
		}
		if(! empty($newAffiliation))
			$validate['affiliation'] = $newAffiliation;
		$rc2 = validateAPIgroupInput($validate, 0);
		if($rc2['status'] == 'error') {
			if($rc2['errorcode'] == 27) {
				$rc2['errorcode'] = 31;
				$rc2['errormsg'] = 'existing user group with new form of name@affiliation';
			}
			return $rc2;
		}
		if(! empty($newAffiliation))
			$updates[] = "affiliationid = {$rc2['affiliationid']}";
	}

	if($row['custom']) {
		if(! empty($newOwner)) {
			$newownerid = getUserlistID(mysql_real_escape_string($newOwner));
			$updates[] = "ownerid = $newownerid";
		}
		if(! empty($newManagingGroup))
			$updates[] = "editusergroupid = {$rc['managingGroupID']}";
	}
	$sets = implode(',', $updates);
	if(count($updates) == 0) {
		return array('status' => 'error',
		             'errorcode' => 33,
		             'errormsg' => 'no new values submitted');
	}
	$query = "UPDATE usergroup "
	       . "SET $sets "
	       . "WHERE id = {$rc['id']}";
	doQuery($query, 101);
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveUserGroup($name, $affiliation)
///
/// \param $name - name of user group
/// \param $affiliation - affiliation of user group
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - user group was successfully removed
///
/// \brief removes a user group along with all of its privileges
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveUserGroup($name, $affiliation) {
	global $user, $mysql_link_vcl;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;
	$query = "SELECT ownerid, "
	       .        "affiliationid, "
	       .        "custom, "
	       .        "courseroll "
	       . "FROM usergroup "
	       . "WHERE id = {$rc['id']}";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 18,
		             'errormsg' => 'user group with submitted name and affiliation does not exist');
	}

	// if custom and not owner or custom/courseroll and no federated user group access, no access to delete group
	if(($row['custom'] == 1 && $user['id'] != $row['ownerid']) ||
	   (($row['custom'] == 0 || $row['courseroll'] == 1) &&
	   ! checkUserHasPerm('Manage Federated User Groups (global)') &&
	   (! checkUserHasPerm('Manage Federated User Groups (affiliation only)') ||
	   $row['affiliationid'] != $user['affiliationid']))) {
		return array('status' => 'error',
		             'errorcode' => 29,
		             'errormsg' => 'access denied to delete user group with submitted name and affiliation');
	}
	if(checkForGroupUsage($rc['id'], 'user')) {
		return array('status' => 'error',
		             'errorcode' => 72,
		             'errormsg' => 'group currently in use and cannot be removed');
	}
	$query = "DELETE FROM usergroup "
	       . "WHERE id = {$rc['id']}";
	doQuery($query, 101);
	# validate something deleted
	if(mysql_affected_rows($mysql_link_vcl) == 0) {
		return array('status' => 'error',
		             'errorcode' => 30,
		             'errormsg' => 'failure while deleting group from database');
	}
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCdeleteUserGroup($name, $affiliation)
///
/// \param $name - name of user group
/// \param $affiliation - affiliation of user group
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - user group was successfully removed
///
/// \brief alias for XMLRPCremoveUserGroup
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCdeleteUserGroup($name, $affiliation) {
	# This was the original function. All other functions use 'remove' rather
	# than 'delete'. The function was renamed to XMLRPCremoveUserGroup. This was
	# kept for compatibility reasons
	return XMLRPCremoveUserGroup($name, $affiliation);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetUserGroupMembers($name, $affiliation)
///
/// \param $name - name of user group
/// \param $affiliation - affiliation of user group
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - there will be one additional element in this case:
/// \li \b members - array of members of the group in username\@affiliation form
///
/// \brief gets members of a user group\n
/// \b NOTE: it is possible to have a group with no members in which case
/// success will be returned with an empty array for members
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetUserGroupMembers($name, $affiliation) {
	global $user;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;
	$query = "SELECT ownerid, "
	       .        "editusergroupid AS editgroupid, "
	       .        "affiliationid, "
	       .        "custom, "
	       .        "courseroll "
	       . "FROM usergroup "
	       . "WHERE id = {$rc['id']}";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 18,
		             'errormsg' => 'user group with submitted name and affiliation does not exist');
	}
	// if custom and not owner and not member of managing group or 
	//    custom/courseroll and no federated user group access, no access to delete group
	if(($row['custom'] == 1 && $user['id'] != $row['ownerid'] &&
	   ! array_key_exists($row['editgroupid'], $user['groups'])) ||
	   (($row['custom'] == 0 || $row['courseroll'] == 1) &&
	   ! checkUserHasPerm('Manage Federated User Groups (global)') &&
	   (! checkUserHasPerm('Manage Federated User Groups (affiliation only)') ||
	   $row['affiliationid'] != $user['affiliationid']))) {
		return array('status' => 'error',
		             'errorcode' => 28,
		             'errormsg' => 'access denied to user group with submitted name and affiliation');
	}
	$query = "SELECT CONCAT(u.unityid, '@', a.name) AS member "
	       . "FROM usergroupmembers ugm, "
	       .      "user u, "
	       .      "affiliation a "
	       . "WHERE ugm.usergroupid = {$rc['id']} AND "
	       .       "ugm.userid = u.id AND "
	       .       "u.affiliationid = a.id";
	$qh = doQuery($query, 101);
	$members = array();
	while($row = mysql_fetch_assoc($qh))
		$members[] = $row['member'];
	return array('status' => 'success',
	             'members' => $members);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddUsersToGroup($name, $affiliation, $users)
///
/// \param $name - name of user group
/// \param $affiliation - affiliation of user group
/// \param $users - array of users in username\@affiliation form to be added to
///                 the group
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - users successfully added to the group\n
/// \b warning - there was a non-fatal issue that occurred while processing
/// the call; there will be three additional elements in this case:
/// \li \b warningcode - warning number
/// \li \b warningmsg - warning string
/// \li \b failedusers - array of users in username\@affiliation form that could
///                      not be added
///
/// \brief adds users to a group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddUsersToGroup($name, $affiliation, $users) {
	global $user;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;
	$query = "SELECT ownerid, "
	       .        "editusergroupid AS editgroupid "
	       . "FROM usergroup "
	       . "WHERE id = {$rc['id']}";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 18,
		             'errormsg' => 'user group with submitted name and affiliation does not exist');
	}
	// if not owner and not member of managing group, no access
	if($user['id'] != $row['ownerid'] && 
	   ! array_key_exists($row['editgroupid'], $user['groups'])) {
		return array('status' => 'error',
		             'errorcode' => 28,
		             'errormsg' => 'access denied to user group with submitted name and affiliation');
	}
	$fails = array();
	foreach($users as $_user) {
		if(empty($_user))
			continue;
		if(get_magic_quotes_gpc())
			$_user = stripslashes($_user);
		$esc_user = mysql_real_escape_string($_user);
		if(validateUserid($_user) == 1)
			addUserGroupMember($esc_user, $rc['id']);
		else
			$fails[] = $_user;
	}
	if(count($fails)) {
		$cnt = 'some';
		$code = 34;
		if(count($fails) == count($users)) {
			$cnt = 'all submitted';
			$code = 35;
		}
		return array('status' => 'warning',
		             'failedusers' => $fails,
		             'warningcode' => $code,
		             'warningmsg' => "failed to add $cnt users to user group");
	}
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveUsersFromGroup($name, $affiliation, $users)
///
/// \param $name - name of user group
/// \param $affiliation - affiliation of user group
/// \param $users - array of users in username\@affiliation form to be removed
///                 from the group
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - users successfully removed from the group\n
/// \b warning - there was a non-fatal issue that occurred while processing
/// the call; there will be three additional elements in this case:
/// \li \b warningcode - warning number
/// \li \b warningmsg - warning string
/// \li \b failedusers - array of users in username\@affiliation form that could
///                      not be removed
///
/// \brief removes users from a group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveUsersFromGroup($name, $affiliation, $users) {
	global $user, $findAffilFuncs;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;
	$query = "SELECT ownerid, "
	       .        "editusergroupid AS editgroupid "
	       . "FROM usergroup "
	       . "WHERE id = {$rc['id']}";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 18,
		             'errormsg' => 'user group with submitted name and affiliation does not exist');
	}
	// if not owner and not member of managing group, no access
	if($user['id'] != $row['ownerid'] && 
	   ! array_key_exists($row['editgroupid'], $user['groups'])) {
		return array('status' => 'error',
		             'errorcode' => 28,
		             'errormsg' => 'access denied to user group with submitted name and affiliation');
	}
	$fails = array();
	foreach($users as $_user) {
		if(empty($_user))
			continue;
		if(get_magic_quotes_gpc())
			$_user = stripslashes($_user);
		$esc_user = mysql_real_escape_string($_user);
		# check that affiliation of user can be determined because getUserlistID
		#   will abort if it cannot find it
		$affilok = 0;
		foreach($findAffilFuncs as $func) {
			if($func($_user, $dump))
				$affilok = 1;
		}
		if(! $affilok) {
			$fails[] = $_user;
			continue;
		}
		$userid = getUserlistID($esc_user, 1);
		if(is_null($userid))
			$fails[] = $_user;
		else
			deleteUserGroupMember($userid, $rc['id']);
	}
	if(count($fails)) {
		$cnt = 'some';
		$code = 36;
		if(count($fails) == count($users)) {
			$cnt = 'any';
			$code = 37;
		}
		return array('status' => 'warning',
		             'failedusers' => $fails,
		             'warningcode' => $code,
		             'warningmsg' => "failed to remove $cnt users from user group");
	}
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetResourceGroups($type)
///
/// \param $type - the resource group type
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - a 'groups' element will contain an array of groups of the given
/// type\n
///
/// \brief get a list of resource groups of a particular type
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetResourceGroups($type) {
	global $user;
	$resources = getUserResources(array("groupAdmin"), array("manageGroup"), 1);
	if(array_key_exists($type, $resources)) {
		return array('status' => 'success',
		             'groups' => $resources[$type]);
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 73,
		             'errormsg' => 'invalid resource group type');
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddResourceGroup($name, $managingGroup, $type)
///
/// \param $name - the name of the resource group
/// \param $managingGroup - the name of the managing group
/// \param $type - the type of resource group
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - the resource group was added
///
/// \brief add a resource group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddResourceGroup($name, $managingGroup, $type) {
	global $user;
	if(! in_array("groupAdmin", $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}

	$validate = array('managingGroup' => $managingGroup);

	$rc = validateAPIgroupInput($validate, 0);
	if($rc['status'] == 'error')
		return $rc;

	if($typeid = getResourceTypeID($type)) {
		if(checkForGroupName($name, 'resource', '', $typeid)) {
			return array('status' => 'error',
			             'errorcode' => 76,
			             'errormsg' => 'resource group already exists');
		}
		if(get_magic_quotes_gpc())
			$name = stripslashes($name);
		if(! preg_match('/^[-a-zA-Z0-9_\. ]{3,30}$/', $name)) {
			return array('status' => 'error',
			             'errorcode' => 87,
			             'errormsg' => 'Name must be between 3 and 30 characters and can only contain letters, numbers, spaces, and these characters: - . _');
		}
		$name = mysql_real_escape_string($name);
		$data = array('type' => 'resource',
		              'ownergroup' => $rc['managingGroupID'],
		              'resourcetypeid' => $typeid,
		              'name' => $name);
		if(! addGroup($data)) {
			return array('status' => 'error',
			             'errorcode' => 26,
			             'errormsg' => 'failure while adding group to database');
		}
	}
	else {
		return array('status' => 'error',
		             'errorcode' => 68,
		             'errormsg' => 'invalid resource type');
	}
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveResourceGroup($name, $type)
///
/// \param $name - the name of the resource group
/// \param $type - the resource group type
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - the resource group was removed\n
///
/// \brief remove a resource group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveResourceGroup($name, $type) {
	global $user;
	if(! in_array("groupAdmin", $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing groups');
	}

	if($groupid = getResourceGroupID("$type/$name")) {
		$userresources = getUserResources(array("groupAdmin"),
		                                  array("manageGroup"), 1);
		if(array_key_exists($type, $userresources)) {
			if(array_key_exists($groupid, $userresources[$type])) {
				if(checkForGroupUsage($groupid, 'resource')) {
					return array('status' => 'error',
					             'errorcode' => 72,
					             'errormsg' => 'group currently in use and cannot be removed');
				}
				$query = "DELETE FROM resourcegroup "
				       . "WHERE id = $groupid";
				doQuery($query, 315);
				return array('status' => 'success');
			}
			else
				return array('status' => 'error',
				             'errorcode' => 75,
				             'errormsg' => 'access denied to specified resource group');
		}
	}
	return array('status' => 'error',
	             'errorcode' => 83,
	             'errormsg' => 'invalid resource group name');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCblockAllocation($imageid, $start, $end, $numMachines,
///                           $usergroupid, $ignoreprivileges)
///
/// \param $imageid - id of the image to be used
/// \param $start - mysql datetime for the start time (i.e. machines should be
/// prep'd and ready by this time)
/// \param $end - mysql datetime for the end time
/// \param $numMachines - number of computers to allocate
/// \param $usergroupid - id of user group for checking user access to machines
/// \param $ignoreprivileges  - (optional, default=0) 0 (false) or 1 (true) - set
/// to 1 to select computers from any that are mapped to be able to run the
/// image; set to 0 to only select computers from ones that are both mapped and
/// that users in the usergroup assigned to this block allocation have been
/// granted access to through the privilege tree
///
/// \return an array with blockTimesid as an index with the value of the newly
/// created block time and at least one other index named 'status' which will
/// have one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the
/// array:\n
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - blockTimesid was processed; there will be two additional
/// elements in this case:\n
/// \li \b allocated - total number of desired allocations that have been
/// processed\n
/// \li \b unallocated - total number of desired allocations that have not been
/// processed\n
///
/// \b warning - there was a non-fatal issue that occurred while processing
/// the call; there will be four additional elements in this case:\n
/// \li \b warningcode - warning number\n
/// \li \b warningmsg - warning string\n
/// \li \b allocated - total number of desired allocations that have been
/// processed\n
/// \li \b unallocated - total number of desired allocations that have not been
/// processed\n\n
///
/// \b NOTE: status may be warning, but allocated may be 0 indicating there
/// were no errors that occurred, but there simply were not any machines
/// available
///
/// \brief creates and processes a block allocation according to the passed
/// in criteria
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCblockAllocation($imageid, $start, $end, $numMachines,
                               $usergroupid, $ignoreprivileges=0) {
	global $user, $xmlrpcBlockAPIUsers;
	if(! in_array($user['id'], $xmlrpcBlockAPIUsers)) {
		return array('status' => 'error',
		             'errorcode' => 34,
		             'errormsg' => 'access denied for managing block allocations');
	}

	# valid $imageid
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);
	if(! array_key_exists($imageid, $resources['image'])) {
		return array('status' => 'error',
		             'errorcode' => 3,
		             'errormsg' => "access denied to $imageid");
	}

	# validate $start and $end
	$dtreg = '([0-9]{4})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2})';
	$startts = datetimeToUnix($start);
	$endts = datetimeToUnix($end);
	$maxend = datetimeToUnix("2038-01-01 00:00:00");
	if(! preg_match("/^$dtreg$/", $start) || $startts < 0 ||
	   $startts > $maxend) {
		return array('status' => 'error',
		             'errorcode' => 4,
		             'errormsg' => "received invalid input for start");
	}
	if(! preg_match("/^$dtreg$/", $end) || $endts < 0 ||
	   $endts > $maxend) {
		return array('status' => 'error',
		             'errorcode' => 36,
		             'errormsg' => "received invalid input for end");
	}

	# validate $numMachines
	if(! is_numeric($numMachines) || $numMachines < MIN_BLOCK_MACHINES ||
	   $numMachines > MAX_BLOCK_MACHINES) {
		return array('status' => 'error',
		             'errorcode' => 64,
		             'errormsg' => 'The submitted number of seats must be between ' . MIN_BLOCK_MACHINES . ' and ' . MAX_BLOCK_MACHINES . '.');
	}

	# validate $usergroupid
	$groups = getUserGroups();
	if(! array_key_exists($usergroupid, $groups)) {
		return array('status' => 'error',
		             'errorcode' => 67,
		             'errormsg' => 'Submitted user group does not exist');
	}

	# validate ignoreprivileges
	if(! is_numeric($ignoreprivileges) ||
	   $ignoreprivileges < 0 ||
		$ignoreprivileges > 1) {
		return array('status' => 'error',
		             'errorcode' => 86,
		             'errormsg' => 'ignoreprivileges must be 0 or 1');
	}

	$ownerid = getUserlistID('vclreload@Local');
	$name = "API:$start";
	$managementnodes = getManagementNodes('future');
	if(empty($managementnodes)) {
		return array('status' => 'error',
		             'errorcode' => 12,
		             'errormsg' => 'could not allocate a management node to handle block allocation');
	}
	$mnid = array_rand($managementnodes);
	$query = "INSERT INTO blockRequest "
	       .        "(name, "
	       .        "imageid, "
	       .        "numMachines, "
	       .        "groupid, "
	       .        "repeating, "
	       .        "ownerid, "
	       .        "managementnodeid, "
	       .        "expireTime, "
	       .        "status) "
	       . "VALUES "
	       .        "('$name', "
	       .        "$imageid, "
	       .        "$numMachines, "
	       .        "$usergroupid, "
	       .        "'list', "
	       .        "$ownerid, "
	       .        "$mnid, "
	       .        "'$end', "
	       .        "'accepted')";
	doQuery($query, 101);
	$brid = dbLastInsertID();
	$query = "INSERT INTO blockTimes "
	       .        "(blockRequestid, "
	       .        "start, "
	       .        "end) "
	       . "VALUES "
	       .        "($brid, "
	       .        "'$start', "
	       .        "'$end')";
	doQuery($query, 101);
	$btid = dbLastInsertID();
	$query = "INSERT INTO blockWebDate "
	       .        "(blockRequestid, "
	       .        "start, "
	       .        "end, "
	       .        "days) "
	       . "VALUES "
	       .        "($brid, "
	       .        "'$start', "
	       .        "'$end', "
	       .        "0)";
	doQuery($query);
	$sh = date('g', $startts);
	$smi = date('i', $startts);
	$sme = date('a', $startts);
	$eh = date('g', $startts);
	$emi = date('i', $startts);
	$eme = date('a', $startts);
	$query = "INSERT INTO blockWebTime "
	       .        "(blockRequestid, "
	       .        "starthour, "
	       .        "startminute, "
	       .        "startmeridian, "
	       .        "endhour, "
	       .        "endminute, "
	       .        "endmeridian, "
	       .        "`order`) "
	       . "VALUES "
	       .        "($brid, "
	       .        "$sh,"
	       .        "$smi,"
	       .        "'$sme',"
	       .        "$eh,"
	       .        "$emi,"
	       .        "'$eme',"
	       .        "0)";
	doQuery($query);
	$return = XMLRPCprocessBlockTime($btid, $ignoreprivileges);
	$return['blockTimesid'] = $btid;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCprocessBlockTime($blockTimesid, $ignoreprivileges)
///
/// \param $blockTimesid - id from the blockTimes table
/// \param $ignoreprivileges - (optional, default=0) 0 (false) or 1 (true) - set
/// to 1 to select computers from any that are mapped to be able to run the
/// image; set to 0 to only select computers from ones that are both mapped and
/// that users in the usergroup assigned to this block allocation have been
/// granted access to through the privilege tree
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b completed - blockTimesid was previously successfully processed\n
/// \b success - blockTimesid was processed; there will be two additional
/// elements in this case:\n
/// \li \b allocated - total number of desired allocations that have been
/// processed\n
/// \li \b unallocated - total number of desired allocations that have not been
/// processed\n
///
/// \b warning - there was a non-fatal issue that occurred while processing
/// the call; there will be four additional elements in this case:\n
/// \li \b warningcode - warning number\n
/// \li \b warningmsg - warning string\n
/// \li \b allocated - total number of desired allocations that have been
/// processed\n
/// \li \b unallocated - total number of desired allocations that have not been
/// processed\n\n
///
/// \b NOTE: status may be warning, but allocated may be 0 indicating there
/// were no errors that occurred, but there simply were not any machines
/// available
///
/// \brief processes a block allocation for the blockTimes entry associated
/// with blockTimesid
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCprocessBlockTime($blockTimesid, $ignoreprivileges=0) {
	global $requestInfo, $user, $xmlrpcBlockAPIUsers;
	if(! in_array($user['id'], $xmlrpcBlockAPIUsers)) {
		return array('status' => 'error',
		             'errorcode' => 34,
		             'errormsg' => 'access denied for managing block allocations');
	}

	# validate $blockTimesid
	if(! is_numeric($blockTimesid)) {
		return array('status' => 'error',
		             'errorcode' => 77,
		             'errormsg' => 'Invalid blockTimesid specified');
	}

	# validate ignoreprivileges
	if(! is_numeric($ignoreprivileges) ||
	   $ignoreprivileges < 0 ||
		$ignoreprivileges > 1) {
		return array('status' => 'error',
		             'errorcode' => 86,
		             'errormsg' => 'ignoreprivileges must be 0 or 1');
	}

	$return = array('status' => 'success');
	$query = "SELECT bt.start, "
	       .        "bt.end, "
	       .        "br.imageid, "
	       .        "br.numMachines, "
	       .        "br.groupid, "
	       .        "br.expireTime "
	       . "FROM blockRequest br, "
	       .      "blockTimes bt "
	       . "WHERE bt.blockRequestid = br.id AND "
	       .       "bt.id = $blockTimesid";
	$qh = doQuery($query, 101);
	if(! $rqdata = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 8,
		             'errormsg' => 'unknown blockTimesid');
	}
	if(datetimeToUnix($rqdata['expireTime']) < time()) {
		return array('status' => 'error',
		             'errorcode' => 9,
		             'errormsg' => 'expired block allocation');
	}

	$images = getImages(0, $rqdata['imageid']);
	if(empty($images)) {
		return array('status' => 'error',
		             'errorcode' => 10,
		             'errormsg' => 'invalid image associated with block allocation');
	}

	$unixstart = datetimeToUnix($rqdata['start']);
	$unixend = datetimeToUnix($rqdata['end']);
	$revisionid = getProductionRevisionid($rqdata['imageid']);
	$imgLoadTime = getImageLoadEstimate($rqdata['imageid']);
	if($imgLoadTime == 0)
		$imgLoadTime = $images[$rqdata['imageid']]['reloadtime'] * 60;
	$vclreloadid = getUserlistID('vclreload@Local');
	$groupmembers = getUserGroupMembers($rqdata['groupid']);
	$userids = array_keys($groupmembers);

	# add any computers from future reservations users in the group made
	if(! empty($groupmembers)) {
		## find reservations by users
		$allids = implode(',', $userids);
		$query = "SELECT rq.id AS reqid, "
		       .        "UNIX_TIMESTAMP(rq.start) AS start, "
		       .        "rq.userid "
		       . "FROM request rq, "
		       .      "reservation rs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rq.userid IN ($allids) AND "
		       .       "rq.start < '{$rqdata['end']}' AND "
		       .       "rq.end > '{$rqdata['start']}' AND "
		       .       "rs.imageid = {$rqdata['imageid']} AND "
		       .       "rs.computerid NOT IN (SELECT computerid "
		       .                             "FROM blockComputers "
		       .                             "WHERE blockTimeid = $blockTimesid)";
		$qh = doQuery($query);
		$donereqids = array();
		$blockCompVals = array();
		$checkstartbase = $unixstart - $imgLoadTime - 300;
		$reloadstartbase = unixToDatetime($checkstartbase);
		$rows = mysql_num_rows($qh);
		while($row = mysql_fetch_assoc($qh)) {
			if(array_key_exists($row['reqid'], $donereqids))
				continue;
			$donereqids[$row['reqid']] = 1;
			if($row['start'] < datetimeToUnix($rqdata['start'])) {
				$checkstart = $row['start'] - $imgLoadTime - 300;
				$reloadstart = unixToDatetime($checkstart);
				$reloadend = unixToDatetime($row['start']);
			}
			else {
				$checkstart = $checkstartbase;
				$reloadstart = $reloadstartbase;
				$reloadend = $rqdata['start'];
			}
			# check to see if computer is available for whole block
			$rc = isAvailable($images, $rqdata['imageid'], $revisionid, $checkstart,
			                  $unixend, 1, $row['reqid'], $row['userid'],
			                  $ignoreprivileges, 0, '', '', 1);
			// if not available for whole block, just skip this one
			if($rc < 1)
				continue;
			$compid = $requestInfo['computers'][0];
			# create reload reservation
			$reqid = simpleAddRequest($compid, $rqdata['imageid'], $revisionid,
			                          $reloadstart, $reloadend, 19, $vclreloadid);
			if($reqid == 0)
				continue;
			# add to blockComputers
			$blockCompVals[] = "($blockTimesid, $compid, {$rqdata['imageid']}, $reqid)";
			# process any subimages
			for($key = 1; $key < count($requestInfo['computers']); $key++) {
				$subimageid = $requestInfo['images'][$key];
				$subrevid = getProductionRevisionid($subimageid);
				$compid = $requestInfo['computers'][$key];
				$mgmtnodeid = $requestInfo['mgmtnodes'][$key];
				$blockCompVals[] = "($blockTimesid, $compid, $subimageid, $reqid)";

				$query = "INSERT INTO reservation "
				       .        "(requestid, "
				       .        "computerid, "
				       .        "imageid, "
				       .        "imagerevisionid, "
				       .        "managementnodeid) "
				       . "VALUES "
				       .       "($reqid, "
				       .       "$compid, "
				       .       "$subimageid, "
				       .       "$subrevid, "
				       .       "$mgmtnodeid)";
				doQuery($query, 101);
			}
		}
		if(count($blockCompVals)) {
			$blockComps = implode(',', $blockCompVals);
			$query = "INSERT INTO blockComputers "
			       .        "(blockTimeid, computerid, imageid, reloadrequestid) "
			       . "VALUES $blockComps";
			doQuery($query);
		}
		cleanSemaphore();
	}

	# check to see if all computers have been allocated
	$query = "SELECT COUNT(computerid) AS allocated "
	       . "FROM blockComputers "
	       . "WHERE blockTimeid = $blockTimesid";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 15,
		             'errormsg' => 'failure to communicate with database');
	}
	$compCompleted = $row['allocated'];
	if(array_key_exists('subimages', $images[$rqdata['imageid']]))
		$compsPerAlloc = 1 + count($images[$rqdata['imageid']]['subimages']);
	else
		$compsPerAlloc = 1;
	$toallocate = ($rqdata['numMachines'] * $compsPerAlloc) - $compCompleted;
	if($toallocate == 0) {
		if(count($blockCompVals)) {
			return array('status' => 'success',
			             'allocated' => $rqdata['numMachines'],
			             'unallocated' => 0);
		}
		return array('status' => 'completed');
	}
	$reqToAlloc = $toallocate / $compsPerAlloc;

	if(! $ignoreprivileges) {
		# get userids in user group
		if(empty($groupmembers)) {
			return array('status' => 'error',
			             'errorcode' => 11,
			             'errormsg' => 'empty user group and ignoreprivileges set to 0');
		}
		# make length of $userids match $reqToAlloc by duplicating or trimming some users
		while($reqToAlloc > count($userids))
			$userids = array_merge($userids, $userids);
		if($reqToAlloc < count($userids))
			$userids = array_splice($userids, 0, $reqToAlloc);
	}

	# staggering: stagger start times for this round (ie, do not worry about
	#   previous processing of this block time) such that there is 1 minute
	#   between the start times for each allocation
	$stagExtra = $reqToAlloc * 60;

	# determine estimated load time
	$loadtime = $imgLoadTime + (10 * 60); # add 10 minute fudge factor
	if((time() + $loadtime + $stagExtra) > $unixstart) {
		$return['status'] = 'warning';
		$return['warningcode'] = 13;
		$return['warningmsg'] = 'possibly insufficient time to load machines';
	}
	$start = unixToDatetime($unixstart - $loadtime);

	$userid = 0;
	$allocated = 0;
	$blockCompVals = array();
	# FIXME (maybe) - if some subset of users in the user group have available
	# computers, but others do not, $allocated will be less than the desired
	# number of machines; however, calling this function enough times will
	# result in enough machines being allocated because they will continue to be
	# allocated based on the ones with machines available; this seems like odd
	# behavior
	$stagCnt = 0;
	$stagTime = 60;        # stagger reload reservations by 1 min
	if($imgLoadTime > 840) // if estimated load time is > 14 min
		$stagTime = 120;    #    stagger reload reservations by 2 min 
	for($i = 0; $i < $reqToAlloc; $i++) {
		$stagunixstart = $unixstart - $loadtime - ($stagCnt * $stagTime);
		$stagstart = unixToDatetime($stagunixstart);
		if(! $ignoreprivileges)
			$userid = array_pop($userids);
		# use end of block time to find available computers, but...
		$rc = isAvailable($images, $rqdata['imageid'], $revisionid, $stagunixstart,
		                  $unixend, 1, 0, $userid, $ignoreprivileges);
		if($rc < 1)
			continue;

		$compid = $requestInfo['computers'][0];
		# ...use start of block time as end of reload reservation
		$reqid = simpleAddRequest($compid, $rqdata['imageid'], $revisionid,
		                          $stagstart, $rqdata['start'], 19, $vclreloadid);
		if($reqid == 0)
			continue;

		$stagCnt++;
		$allocated++;
		$blockCompVals[] = "($blockTimesid, $compid, {$rqdata['imageid']}, $reqid)";

		# process any subimages
		for($key = 1; $key < count($requestInfo['computers']); $key++) {
			$subimageid = $requestInfo['images'][$key];
			$subrevid = getProductionRevisionid($subimageid);
			$compid = $requestInfo['computers'][$key];
			$mgmtnodeid = $requestInfo['mgmtnodes'][$key];
			$blockCompVals[] = "($blockTimesid, $compid, $subimageid, $reqid)";

			$query = "INSERT INTO reservation "
			       .        "(requestid, "
			       .        "computerid, "
			       .        "imageid, "
			       .        "imagerevisionid, "
			       .        "managementnodeid) "
			       . "VALUES "
			       .       "($reqid, "
			       .       "$compid, "
			       .       "$subimageid, "
			       .       "$subrevid, "
			       .       "$mgmtnodeid)";
			doQuery($query, 101);
		}
		$blockComps = implode(',', $blockCompVals);
		$query = "INSERT INTO blockComputers "
		       .        "(blockTimeid, computerid, imageid, reloadrequestid) "
		       . "VALUES $blockComps";
		doQuery($query, 101);
		cleanSemaphore();
		$blockCompVals = array();
	}
	if($allocated == 0) {
		$return['status'] = 'warning';
		$return['warningcode'] = 14;
		$return['warningmsg'] = 'unable to allocate any machines';
	}
	$return['allocated'] = ($compCompleted / $compsPerAlloc) + $allocated;
	$return['unallocated'] = $rqdata['numMachines'] - $return['allocated'];
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCfinishBaseImageCapture($ownerid, $resourceid, $virtual=1)
///
/// \param $ownerid - id of owner of image
/// \param $resourceid - id from resource table for the image
/// \param $virtual - (bool) 0 if bare metal image, 1 if virtual
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - the permissions, groupings, and mappings were set up
/// successfully
///
/// \brief calls addImagePermissions to create and set up permissions,
/// groupings, and mappings so that the owner of a new base image will be able
/// to make a reservation for it after capturing it using 'vcld -setup';
/// specifically designed to be called by vcld as part of the process of
/// capturing a new base image
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCfinishBaseImageCapture($ownerid, $resourceid, $virtual=1) {
	global $user, $xmlrpcBlockAPIUsers;
	if(! in_array($user['id'], $xmlrpcBlockAPIUsers)) {
		return array('status' => 'error',
		             'errorcode' => 89,
		             'errormsg' => 'access denied for call to XMLRPCfinishBaseImageCapture');
	}
	if(! is_numeric($ownerid)) {
		return array('status' => 'error',
		             'errorcode' => 90,
		             'errormsg' => 'Invalid ownerid submitted');
	}
	if(! is_numeric($resourceid)) {
		return array('status' => 'error',
		             'errorcode' => 91,
		             'errormsg' => 'Invalid resourceid submitted');
	}
	$ownerdata = getUserInfo($ownerid, 1, 1);
	if(is_null($ownerdata) || empty($ownerdata)) {
		return array('status' => 'error',
		             'errorcode' => 90,
		             'errormsg' => 'Invalid ownerid passed as second argument');
	}
	$query = "SELECT i.id "
	       . "FROM image i, "
	       .      "resource r "
	       . "WHERE r.id = $resourceid AND "
	       .       "r.subid = i.id AND "
	       .       "r.resourcetypeid = 13";
	$qh = doQuery($query);
	if(mysql_num_rows($qh) != 1) {
		return array('status' => 'error',
		             'errorcode' => 91,
		             'errormsg' => 'Invalid resourceid submitted');
	}
	require_once(".ht-inc/resource.php");
	require_once(".ht-inc/image.php");
	$obj = new Image();
	$obj->addImagePermissions($ownerdata, $resourceid, $virtual);
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCcheckCryptSecrets($reservationid)
///
/// \param $reservationid - id from reservation table
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:\n
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
/// \b success - indicates all secrets were successfully
/// updated\n
/// \b partial - indicates only some needed secrets were successfully updates\n
/// \b noupdate - indicates no missing values were found to be added to
/// cryptsecret table
///
/// \brief generates any missing entries in cryptsecret for calling management
/// node to be able to process $reservationid
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCcheckCryptSecrets($reservationid) {
	global $user, $xmlrpcBlockAPIUsers;

	if(! in_array($user['id'], $xmlrpcBlockAPIUsers)) {
		return array('status' => 'error',
		             'errorcode' => 99,
		             'errormsg' => 'access denied for call to XMLRPCcheckCryptSecrets');
	}
	# query to find any cryptkeys that don't have values in cryptsecret
	$mycryptkeyid = getCryptKeyID();
	if($mycryptkeyid === NULL) {
		return array('status' => 'error',
		             'errorcode' => 100,
		             'errormsg' => 'Encryption key missing for this web server');
	}
	# check for existance of $reservationid
	$query = "SELECT id FROM reservation WHERE id = $reservationid";
	$qh = doQuery($query);
	if(! ($row = mysql_fetch_assoc($qh))) {
		return array('status' => 'error',
		             'errorcode' => 101,
		             'errormsg' => 'Specified reservation does not exist');
	}
	# determine any secretids needed from addomain
	$secretids = array();
	$mnid = 0;
	$query = "SELECT ad.secretid, "
	       .        "rs.managementnodeid "
	       . "FROM reservation rs "
	       . "LEFT JOIN imageaddomain ia ON (rs.imageid = ia.imageid) "
	       . "LEFT JOIN addomain ad ON (ia.addomainid = ad.id) "
	       . "WHERE rs.id = $reservationid AND "
	       .       "ad.secretid IS NOT NULL";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		$secretids[] = $row['secretid'];
		$mnid = $row['managementnodeid'];
	}
	# determine any secretids needed from vmprofile
	$query = "SELECT vp.secretid, "
	       .        "rs.managementnodeid "
	       . "FROM reservation rs "
	       . "JOIN computer c ON (rs.computerid = c.id) "
	       . "LEFT JOIN vmhost vh ON (c.vmhostid = vh.id) "
	       . "LEFT JOIN vmprofile vp ON (vh.vmprofileid = vp.id) "
	       . "WHERE rs.id = $reservationid AND "
	       .       "vp.secretid IS NOT NULL";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		$secretids[] = $row['secretid'];
		$mnid = $row['managementnodeid'];
	}

	if(empty($secretids))
		return array('status' => 'noupdate');

	# find any missing secrets for management nodes
	$values = array();
	$fails = array();
	$secret1 = array_shift($secretids);
	$subquery = "SELECT $secret1 AS id";
	if(count($secretids) == 1)
		$subquery .= " UNION SELECT {$secretids[0]}";
	elseif(count($secretids) > 1)
		$subquery .= " UNION SELECT " . implode(' UNION SELECT ', $secretids);
	$query = "SELECT ck.id as cryptkeyid, "
	       .        "ck.pubkey as cryptkey, "
	       .        "s.id as secretid, "
	       .        "mycs.cryptsecret AS mycryptsecret "
	       . "FROM cryptkey ck "
	       . "JOIN ($subquery) AS s "
	       . "LEFT JOIN (SELECT cryptsecret, secretid "
	       .            "FROM cryptsecret "
	       .            "WHERE cryptkeyid = $mycryptkeyid) AS mycs ON (s.id = mycs.secretid) "
	       . "LEFT JOIN cryptsecret cs ON (s.id = cs.secretid AND ck.id = cs.cryptkeyid) "
	       . "WHERE ck.hostid = $mnid AND "
	       .       "ck.hosttype = 'managementnode' AND "
	       .       "cs.id IS NULL";
	$qh = doQuery($query);
	while($row = mysql_fetch_assoc($qh)) {
		if($row['mycryptsecret'] == NULL) {
			$fails[] = $row['secretid'];
			continue;
		}
		$secret = decryptSecretKey($row['mycryptsecret']);
		$encsecret = encryptSecretKey($secret, $row['cryptkey']);
		$values[] = "({$row['cryptkeyid']}, {$row['secretid']}, '$encsecret', '"
		          . SYMALGO . "', '" . SYMOPT . "', " . SYMLEN . ")";
	}
	if(empty($values) && empty($fails))
		return array('status' => 'noupdate');

	addCryptSecretKeyUpdates($values);

	if(count($values) && count($fails))
		return array('status' => 'partial');
	elseif(count($fails))
		return array('status' => 'error',
		             'errorcode' => 102,
		             'errormsg' => 'Encryption secret missing for this web server');

	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetOneClickParams($oneclickid)
///
/// \param $oneclickid - id of the one click
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - there will be these additional elements:
/// \li \b name - name of one click
/// \li \b imageid - id of image
/// \li \b imagename - name of image
/// \li \b ostype - type of OS in image
/// \li \b duration - duration for reservations for this one click
/// \li \b autologin - whether or not autologin should be used with this one
/// click
///
/// \brief returns the parameters for a one click configuration
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetOneClickParams($oneclickid) {
	global $user;
	$oneclickid = processInputData($oneclickid, ARG_NUMERIC);
	$query = "SELECT o.id, "
	       .        "o.userid, "
	       .        "o.imageid, "
	       .        "i.prettyname AS imagename, "
	       .        "os.`type` AS ostype, "
	       .        "o.name, "
	       .        "o.duration, "
	       .        "o.autologin "
	       . "FROM oneclick o "
	       . "LEFT JOIN image i ON (o.imageid = i.id) "
	       . "LEFT JOIN OS os ON (i.OSid = os.id) "
	       . "WHERE o.id = $oneclickid AND "
	       .       "o.status = 1 AND "
	       .       "o.userid = {$user['id']}";
	$qh = doQuery($query);
	//if nothing returned, oneclick does not exist
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 95,
		             'errormsg' => "The OneClick with ID $oneclickid does not exist.");
	}
	elseif($row['userid'] != $user['id']) {
		return array('status' => 'error',
		             'errorcode' => 90,
		             'errormsg' => "The OneClick with ID $oneclickid does not belong to the user that requested it.");
	}

	return array('status' => 'success',
	             'name' => $row['name'],
	             'imageid' => $row['imageid'],
	             'imagename' => $row['imagename'],
	             'ostype' => $row['ostype'],
	             'duration' => $row['duration'],
	             'autologin' => $row['autologin']);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetOneClicks()
///
/// \return an array with 2 indices:\n
/// \b status - will be 'success'\n
/// \b oneclicks - will be an array of oneclicks
///
/// \brief builds an array of one clicks belonging to user
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetOneClicks() {
	global $user;
	$states = "8,28,26,27,19,6,3,25,29";
	$query = "SELECT o.id oneclickid, "
	        .       "rq.requestid, "
	        .       "COALESCE(rq.reqcount, 0) AS reqcount, "
	        .       "o.userid, "
	        .       "o.imageid, "
	        .       "i.prettyname imagename, "
	        .       "os.`type` ostype, "
	        .       "o.name, "
	        .       "o.duration, "
	        .       "o.autologin, "
	        .       "rq2.stateid AS currstateid, "
	        .       "rq2.laststateid "
	        . "FROM oneclick o "
	        . "LEFT JOIN image i ON (o.imageid = i.id) "
	        . "LEFT JOIN OS os ON (i.OSid = os.id) "
	        . "LEFT JOIN ("
	        .      "SELECT rs.imageid, "
	        .             "MAX(rq.id) AS requestid, " 
	        .             "COUNT(rq.id) AS reqcount " 
	        .      "FROM reservation rs, "
	        .           "request rq "
	        .      "WHERE rs.requestid = rq.id AND "
	        .            "rq.userid = {$user['id']} AND "
	        .            "(rq.stateid IN ($states) OR "
	        .            "(rq.stateid = 14 AND "
	        .             "rq.laststateid IN (13,$states))) " // also include new state if in pending
	        .      "GROUP BY rs.imageid) AS rq ON (rq.imageid = i.id) "
	        . "LEFT JOIN request rq2 ON (rq.requestid = rq2.id) "
	        . "WHERE o.status = 1 AND "
	        .       "o.userid = {$user['id']} "
	        . "ORDER BY o.name";
	$qh = doQuery($query, 101);
	if(! $qh) {
		return array('status' => 'error',
		             'errorcode' => 94,
		             'errormsg' => "Unable to retrieve user's OneClicks.");
	}
	$result = array();
	$result['status'] = 'success';
	$result['oneclicks'] = array();
	#$allstates = getStates();
	while($row = mysql_fetch_assoc($qh)) {
		/*if($row['currstateid'] == 14)
			$state = $allstates[$row['laststateid']];
		elseif(! is_null($row['currstateid']))
			$state = $allstates[$row['currstateid']];
		else
			$state = 'none';*/
		$result['oneclicks'][] = array('oneclickid' => $row['oneclickid'],
		                               'name' => $row['name'],
		                               'imageid' => $row['imageid'],
		                               'imagename' => $row['imagename'],
		                               'ostype' => $row['ostype'],
		                               'duration' => $row['duration'],
		                               'autologin' => $row['autologin'],
		                               'requestid' => $row['requestid'],
		                               'reqcount' => $row['reqcount']/*,
		                               'state' => $state*/);
	}
	return $result;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddOneClick($name, $imageid, $duration, $autologin)
///
/// \param $name - name of new one click
/// \param $imageid - id of image for new one click
/// \param $duration - duration for reservations made for this one click
/// \param $autologin - (?) 1 for autologin, 0 to skip autologin
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - there will be one additional element in this case:
/// \li \b oneclickid - id of new one click
///
/// \brief adds a new one click to VCL
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddOneClick($name, $imageid, $duration, $autologin) {
	global $user;
	$userid = $user['id'];
	$imageid = processInputData($imageid, ARG_NUMERIC);
	$name = processInputData($name, ARG_STRING);
	$duration = processInputData($duration, ARG_NUMERIC);
	$autologin = processInputData($autologin, ARG_NUMERIC) == 1 ? 1 : 0;

	# validate $imageid
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources["image"]);
	if(! array_key_exists($imageid, $images)) {
		return array('status' => 'error',
		             'errorcode' => 93,
		             'errormsg' => "Unable to create OneClick.");
	}

	# validate $name
	if(! preg_match('/^([-a-zA-Z0-9\. \(\)]){3,70}$/', $name)) {
		return array('status' => 'error',
		             'errorcode' => 93,
		             'errormsg' => "Unable to create OneClick.");
	}

	# validate $duration
	$images = getImages(0, $imageid);
	$maxlength = $images[$imageid]['maxinitialtime'];
	$maxtimes = getUserMaxTimes();
	if($maxlength && $maxlength < $maxtimes['initial'])
		$maxduration = $maxlength;
	else
		$maxduration = $maxtimes['initial'];
	if($duration > $maxduration) {
		return array('status' => 'error',
		             'errorcode' => 93,
		             'errormsg' => "Unable to create OneClick.");
	}

	$query = "INSERT INTO oneclick"
	       .        "(userid, "
	       .        "imageid, "
	       .        "name, "
	       .        "duration, "
	       .        "autologin, "
	       .        "status) "
	       . "VALUES "
	       .        "($userid, "
	       .        "$imageid, "
	       .        "'$name', "
	       .        "$duration, "
	       .        "$autologin, "
	       .        "1) ";
	$qh = doQuery($query, 101);
	if(! $qh) {
		return array('status' => 'error',
		             'errorcode' => 93,
		             'errormsg' => "Unable to create OneClick.");
	}
	$return = array();
	$return['oneclickid']= dbLastInsertID();
	$return['status'] = 'success';
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCeditOneClick($oneclickid, $name, $imageid, $duration, $autologin)
///
/// \param $oneclickid - id of the one click
/// \param $name - name of new one click
/// \param $imageid - id of image for new one click
/// \param $duration - duration for reservations made for this one click
/// \param $autologin - (?) 1 for autologin, 0 to skip autologin
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - there will be these additional elements:
/// \li \b name - name of one click
/// \li \b imageid - id of image
/// \li \b imagename - name of image
/// \li \b ostype - type of OS in image
/// \li \b duration - duration for reservations for this one click
/// \li \b autologin - whether or not autologin should be used with this one
/// click
///
/// \brief edits the configuration of a one click
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCeditOneClick($oneclickid, $name, $imageid, $duration, $autologin) {
	global $user;
	$oneclickid = processInputData($oneclickid, ARG_NUMERIC);
	$imageid = processInputData($imageid, ARG_NUMERIC);
	$name = processInputData($name, ARG_STRING);
	$duration = processInputData($duration, ARG_NUMERIC);
	$autologin = processInputData($autologin, ARG_NUMERIC) == 1 ? 1 : 0;

	# validate $imageid
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources["image"]);
	if(! array_key_exists($imageid, $images)) {
		return array('status' => 'error',
		             'errorcode' => 92,
		             'errormsg' => "Invalid image specified");
	}

	# validate $name
	if(! preg_match('/^([-a-zA-Z0-9\. \(\)]){3,70}$/', $name)) {
		return array('status' => 'error',
		             'errorcode' => 96,
		             'errormsg' => "Invalid name specified - name can be from 3 to 70 characters long and can only contain letters, numbers, spaces, and these characters: - . ( )");
	}

	# validate $duration
	$images = getImages(0, $imageid);
	$maxlength = $images[$imageid]['maxinitialtime'];
	$maxtimes = getUserMaxTimes();
	if($maxlength && $maxlength < $maxtimes['initial'])
		$maxduration = $maxlength;
	else
		$maxduration = $maxtimes['initial'];
	if($duration > $maxduration) {
		$allowed = prettyLength($maxduration);
		return array('status' => 'error',
		             'errorcode' => 97,
		             'errormsg' => "Specified duration is too long",
		             'maxduration' => $allowed);
	}
	
	$query = "SELECT id "
	       . "FROM oneclick "
	       . "WHERE id = $oneclickid AND "
	       .       "status = 1 AND "
	       .       "userid = {$user['id']}";
	$qh = doQuery($query, 101);
	//if nothing returned, oneclick does not exist or belongs to another user
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 95,
		             'errormsg' => "The OneClick with ID $oneclickid does not exist.");
	}
	/*elseif($row['userid'] != $user['id']) {
		return array('status' => 'error',
		             'errorcode' => 90,
		             'errormsg' => "The OneClick with ID $oneclickid does not belong to the user that requested it.");
	}*/
	
	$query = "UPDATE oneclick "
	       . "SET imageid = $imageid, "
	       .     "name = '$name', "
	       .     "duration = $duration, "
	       .     "autologin = $autologin "
	       . "WHERE id = $oneclickid AND "
	       .       "userid = {$user['id']}";
	$qh = doQuery($query, 101);
	if(! $qh)
		return array('status' => 'error',
		             'errorcode' => 98,
		             'errormsg' => "Unable to update OneClick.");

	return XMLRPCgetOneClickParams($oneclickid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCdeleteOneClick($oneclickid) {
///
/// \param $oneclickid - id of the one click
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - one click was successfully deleted
///
/// \brief deletes a one click
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCdeleteOneClick($oneclickid) {
	global $user;
	$oneclickid = processInputData($oneclickid, ARG_NUMERIC);
	
	$query = "SELECT id "
	       . "FROM oneclick "
	       . "WHERE id = $oneclickid AND "
	       .       "userid = {$user['id']}";
	$qh = doQuery($query, 101);
	//if nothing returned, oneclick does not exist or belongs to another user
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 95,
		             'errormsg' => "The OneClick with ID $oneclickid does not exist.");
	}

	$query = "UPDATE oneclick "
	       . "SET status = 0 "
	       . "WHERE id = $oneclickid AND "
	       .       "userid = {$user['id']}";
	$qh = doQuery($query, 101);
	if(! $qh) {
		return array('status' => 'error',
		             'errorcode' => 91,
		             'errormsg' => "Unable to delete OneClick.");
	}
	$return = array();
	$return['status'] = 'success';
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetIP()
///
/// \return an array with 2 indices:\n
/// \b status - will be 'success'\n
/// \b ip - will be the client's IP address as seen by the server\n
///
/// \brief this is a function that returns the client's IP address as seen by
/// the server
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetIP() {
	return array('status' => 'success', 'ip' => $_SERVER['REMOTE_ADDR']);
}
?>
