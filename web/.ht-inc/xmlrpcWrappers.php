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
 * 
 * <h2>API Version 1</h2>
 * \b NOTICE: API version 1 will probably be removed in VCL 2.2.  If you are
 * still using API version 1, you need to update your code to use version 2.\n\n
 * This version is being phased out in favor of version 2. Documentation is
 * provided for those currently using version 1 who are not ready to switch
 * to using version 2.\n\n
 * 
 * Authentication is handled by 2 additional HTTP headers you will need to
 * send:\n
 * \b X-User - use the same id you would use to log in to the VCL site\n
 * \b X-Pass - the key mentioned above\n
 * \n
 * There is one other additional HTTP header you must send:\n
 * \b X-APIVERSION - set this to 1\n
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
/// \fn XMLRPCgetImages()
///
/// \return an array of image arrays, each with 2 indices:\n
/// \b id - id of the image\n
/// \b name - name of the image
///
/// \brief gets the images to which the user has acces
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetImages() {
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);
	$return = array();
	foreach($resources['image'] as $key => $val) {
		$tmp = array('id' => $key, 'name' => $val);
		array_push($return, $tmp);
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddRequest($imageid, $start, $length, $foruser)
///
/// \param $imageid - id of an image
/// \param $start - "now" or unix timestamp for start of reservation; will
/// use a floor function to round down to the nearest 15 minute increment
/// for actual reservation
/// \param $length - length of reservation in minutes (must be in 15 minute
/// increments)
/// \param $foruser - (optional) login to be used when setting up the account
/// on the reserved machine - CURRENTLY, THIS IS UNSUPPORTED
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
function XMLRPCaddRequest($imageid, $start, $length, $foruser='') {
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
		             'errormsg' => "received invalid input");
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

	$images = getImages();
	$rc = isAvailable($images, $imageid, $start, $end, '');
	if($rc < 1) {
		addLogEntry($nowfuture, unixToDatetime($start), 
		            unixToDatetime($end), 0, $imageid);
		return array('status' => 'notavailable');
	}
	$return['requestid']= addRequest();
	$return['status'] = 'success';
	return $return;
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
/// \b future - start time of request is in the future
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
/// array:
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
		$serverIP = $requestData["reservations"][0]["reservedIP"];
		$passwd = $requestData["reservations"][0]["password"];
		if($requestData["forimaging"])
			$thisuser = 'Administrator';
		else
			if(preg_match('/(.*)@(.*)/', $user['unityid'], $matches))
				$thisuser = $matches[1];
			else
				$thisuser = $user['unityid'];
		return array('status' => 'ready',
		             'serverIP' => $serverIP,
		             'user' => $thisuser,
		             'password' => $passwd);
	}
	return array('status' => 'notready');
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
/// \fn XMLRPCgetRequestIds()
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - request was successfully ended; there will be an additional
/// element whose index is 'requests' which is an array of arrays, each having
/// these elements (or empty if no existing requests):\n
/// \li \b requestid - id of the request\n
/// \li \b imageid - id of the image\n
/// \li \b imagename - name of the image\n
/// \li \b start - unix timestamp of start time\n
/// \li \b end - unix timestamp of end time
///
/// \brief gets information about all of user's requests
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetRequestIds() {
	global $user;
	$requests = getUserRequests("all");
	if(empty($requests))
		return array('status' => 'success', 'requests' => array());
	$ret = array();
	foreach($requests as $req) {
		$start = datetimeToUnix($req['start']);
		$end = datetimeToUnix($req['end']);
		$tmp = array('requestid' => $req['id'],
		             'imageid' => $req['imageid'],
		             'imagename' => $req['prettyimage'],
		             'start' => $start,
		             'end' => $end);
		array_push($ret, $tmp);
	}
	return array('status' => 'success', 'requests' => $ret);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCblockAllocation($imageid, $start, $end, $requestcount,
///                           $usergroupid, $ignoreprivileges)
///
/// \param $imageid - id of the image to be used
/// \param $start - mysql datetime for the start time (i.e. requests should be
/// prep'd and ready by this time)
/// \param $end - mysql datetime for the end time
/// \param $requestcount - number of computers to allocate
/// \param $usergroupid - id of user group for checking user access to machines
/// \param $ignoreprivileges (optional, default=0) - 0 (false) or 1 (true) - set
/// to 1 to select computers from any that are mapped to be able to run the
/// image; set to 0 to only select computers from ones that are both mapped and
/// that users in the usergroup assigned to this block request have been granted
/// access to through the privilege tree
///
/// \return an array with blockTimesid as an index with the value of the newly
/// created block time and at least one other index named 'status' which will
/// have one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - blockTimesid was processed; there will be two additional
/// elements in this case:
/// \li \b allocated - total number of desired requests that have been allocated
/// \li \b unallocated - total number of desired requests that have not been
/// allocated
///
/// \b warning - there was a non-fatal issue that occurred while processing
/// the call; there will be four additional elements in this case:
/// \li \b warningcode - warning number
/// \li \b warningmsg - warning string
/// \li \b allocated - total number of desired requests that have been allocated
/// \li \b unallocated - total number of desired requests that have not been
/// allocated
///
/// note that status may be warning, but allocated may be 0 indicating there
/// were no errors that occurred, but there simply were not any machines
/// available
///
/// \brief creates and processes a block reservation according to the passed
/// in criteria
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCblockAllocation($imageid, $start, $end, $requestcount,
                               $usergroupid, $ignoreprivileges=0) {
	global $user, $xmlrpcBlockAPIUsers;
	if(! in_array($user['id'], $xmlrpcBlockAPIUsers)) {
		return array('status' => 'error',
		             'errorcode' => 34,
		             'errormsg' => 'access denied for managing block allocations');
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
	       .        "admingroupid, "
	       .        "managementnodeid, "
	       .        "expireTime) "
	       . "VALUES "
	       .        "('$name', "
	       .        "$imageid, "
	       .        "$requestcount, "
	       .        "$usergroupid, "
	       .        "'list', "
	       .        "$ownerid, "
	       .        "0, "
	       .        "$mnid, "
	       .        "'$end')";
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
	$return = XMLRPCprocessBlockTime($btid, $ignoreprivileges);
	$return['blockTimesid'] = $btid;
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCprocessBlockTime($blockTimesid, $ignoreprivileges)
///
/// \param $blockTimesid - id from the blockTimes table
/// \param $ignoreprivileges (optional, default=0) - 0 (false) or 1 (true) - set
/// to 1 to select computers from any that are mapped to be able to run the
/// image; set to 0 to only select computers from ones that are both mapped and
/// that users in the usergroup assigned to this block request have been granted
/// access to through the privilege tree
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b completed - blockTimesid was previously successfully processed\n
/// \b success - blockTimesid was processed; there will be two additional
/// elements in this case:
/// \li \b allocated - total number of desired requests that have been allocated
/// \li \b unallocated - total number of desired requests that have not been
/// allocated
///
/// \b warning - there was a non-fatal issue that occurred while processing
/// the call; there will be four additional elements in this case:
/// \li \b warningcode - warning number
/// \li \b warningmsg - warning string
/// \li \b allocated - total number of desired requests that have been allocated
/// \li \b unallocated - total number of desired requests that have not been
/// allocated
///
/// note that status may be warning, but allocated may be 0 indicating there
/// were no errors that occurred, but there simply were not any machines
/// available
///
/// \brief processes a block reservation for the blockTimes entry associated
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
		             'errormsg' => 'expired block reservation');
	}

	$images = getImages(0, $rqdata['imageid']);
	if(empty($images)) {
		return array('status' => 'error',
		             'errorcode' => 10,
		             'errormsg' => 'invalid image associated with block request');
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
	$compsPerRequest = 1 + count($images[$rqdata['imageid']]['subimages']);
	$toallocate = ($rqdata['numMachines'] * $compsPerRequest) - $compCompleted;
	if($toallocate == 0)
		return array('status' => 'completed');
	$reqToAlloc = $toallocate / $compsPerRequest;

	if(! $ignoreprivileges) {
		# get userids in user group
		$tmp = getUserGroupMembers($rqdata['groupid']);
		if(empty($tmp)) {
			return array('status' => 'error',
			             'errorcode' => 11,
			             'errormsg' => 'empty user group and ignoreprivileges set to 0');
		}
		$userids = array_keys($tmp);
		# make length of $userids match $reqToAlloc by duplicating or trimming some users
		while($reqToAlloc > count($userids))
			$userids = array_merge($userids, $userids);
		if($reqToAlloc < count($userids))
			$userids = array_splice($userids, 0, $reqToAlloc);
	}

	# staggering: stagger start times for this round (ie, don't worry about
	#   previous processing of this block time) such that there is 1 minute
	#   between the start times for each request
	$stagExtra = $reqToAlloc * 60;

	# determine estimated load time
	$imgLoadTime = getImageLoadEstimate($rqdata['imageid']);
	if($imgLoadTime == 0)
		$imgLoadTime = $images[$rqdata['imageid']]['reloadtime'] * 60;
	$loadtime = $imgLoadTime + (10 * 60); # add 10 minute fudge factor
	$unixstart = datetimeToUnix($rqdata['start']);
	if((time() + $loadtime + $stagExtra) > $unixstart) {
		$return['status'] = 'warning';
		$return['warningcode'] = 13;
		$return['warningmsg'] = 'possibly insufficient time to load machines';
	}
	$start = unixToDatetime($unixstart - $loadtime);
	$unixend = datetimeToUnix($rqdata['end']);

	$userid = 0;
	$allocated = 0;
	$vclreloadid = getUserlistID('vclreload@Local');
	$revisionid = getProductionRevisionid($rqdata['imageid']);
	$blockCompVals = array();
	# FIXME (maybe) - if some subset of users in the user group have available
	# computers, but others do not, $allocated will be less than the desired
	# number of machines; however, calling this function enough times will
	# result in enough machines being allocated because they will continue to be
	# allocated based on the ones with machines available; this seems like odd
	# behavior
	$stagCnt = 0;
	for($i = 0; $i < $reqToAlloc; $i++) {
		$stagunixstart = $unixstart - $loadtime - ($stagCnt * 60);
		$stagstart = unixToDatetime($stagunixstart);
		if(! $ignoreprivileges)
			$userid = array_pop($userids);
		# use end of block time to find available computers, but...
		$rc = isAvailable($images, $rqdata['imageid'], $stagunixstart,
		                  $unixend, 0, 0, $userid, $ignoreprivileges);
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
		$blockCompVals[] = "($blockTimesid, $compid, {$rqdata['imageid']})";

		# process any subimages
		for($key = 1; $key < count($requestInfo['computers']); $key++) {
			$subimageid = $requestInfo['images'][$key];
			$subrevid = getProductionRevisionid($subimageid);
			$compid = $requestInfo['computers'][$key];
			$mgmtnodeid = $requestInfo['mgmtnodes'][$key];
			$blockCompVals[] = "($blockTimesid, $compid, $subimageid)";

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
		semUnlock();
		$blockComps = implode(',', $blockCompVals);
		$query = "INSERT INTO blockComputers "
		       .        "(blockTimeid, computerid, imageid) "
		       . "VALUES $blockComps";
		doQuery($query, 101);
		$blockCompVals = array();
	}
	if($allocated == 0) {
		$return['status'] = 'warning';
		$return['warningcode'] = 14;
		$return['warningmsg'] = 'unable to allocate any machines';
	}
	$return['allocated'] = ($compCompleted / $compsPerRequest) + $allocated;
	$return['unallocated'] = $rqdata['numMachines'] - $return['allocated'];
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCaddUserGroup($name, $affiliation, $owner, $managingGroup,
///                        $initialMaxTime, $totalMaxTime, $maxExtendTime)
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
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - user group was successfully created
///
/// \brief creates a new user group with the specified parameters
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddUserGroup($name, $affiliation, $owner, $managingGroup,
                            $initialMaxTime, $totalMaxTime, $maxExtendTime) {
	global $user;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing user groups');
	}
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation,
	                  'owner' => $owner,
	                  'managingGroup' => $managingGroup,
	                  'initialMaxTime' => $initialMaxTime,
	                  'totalMaxTime' => $totalMaxTime,
	                  'maxExtendTime' => $maxExtendTime);
	$rc = validateAPIgroupInput($validate, 0);
	if($rc['status'] == 'error')
		return $rc;
	$data = array('type' => 'user',
	              'owner' => $owner,
	              'name' => $name,
	              'affiliationid' => $rc['affiliationid'],
	              'editgroupid' => $rc['managingGroupID'],
	              'initialmax' => $initialMaxTime,
	              'totalmax' => $totalMaxTime,
	              'maxextend' => $maxExtendTime,
	              'overlap' => 0);
	if(! addGroup($data)) {
		return array('status' => 'error',
		             'errorcode' => 26,
		             'errormsg' => 'failure while adding group to database');
	}
	return array('status' => 'success');
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
/// \b success - there will be five additional elements in this case:
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
///
/// \brief gets information about a user group
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetUserGroupAttributes($name, $affiliation) {
	global $user;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing user groups');
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
	# if not owner and not member of managing group, no access
	if($user['id'] != $row['ownerid'] && 
	   ! array_key_exists($row['editgroupid'], $user['groups'])) {
		return array('status' => 'error',
		             'errorcode' => 28,
		             'errormsg' => 'access denied to user group with submitted name and affiliation');
	}
	return array('status' => 'success',
	             'owner' => $row['owner'],
	             'managingGroup' => "{$row['editgroup']}@{$row['editgroupaffiliation']}",
	             'initialMaxTime' => $row['initialmaxtime'],
	             'totalMaxTime' => $row['totalmaxtime'],
	             'maxExtendTime' => $row['maxextendtime']);
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
/// \b success - user group was successfully deleted
///
/// \brief deletes a user group along with all of its privileges
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCdeleteUserGroup($name, $affiliation) {
	global $user, $mysql_link_vcl;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing user groups');
	}
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;
	$query = "SELECT ownerid "
	       . "FROM usergroup "
	       . "WHERE id = {$rc['id']}";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 18,
		             'errormsg' => 'user group with submitted name and affiliation does not exist');
	}
	# if not owner no access to delete group
	if($user['id'] != $row['ownerid']) {
		return array('status' => 'error',
		             'errorcode' => 29,
		             'errormsg' => 'access denied to delete user group with submitted name and affiliation');
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
		             'errormsg' => 'access denied for managing user groups');
	}

	$updates = array();

	# validate group exists and new values other than newName and newAffiliation
	#   are valid
	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
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
	$query = "SELECT ownerid "
	       . "FROM usergroup "
	       . "WHERE id = {$rc['id']}";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		return array('status' => 'error',
		             'errorcode' => 18,
		             'errormsg' => 'user group with submitted name and affiliation does not exist');
	}
	# if not owner no access to edit group attributes
	if($user['id'] != $row['ownerid']) {
		return array('status' => 'error',
		             'errorcode' => 32,
		             'errormsg' => 'access denied to modify attributes for user group with submitted name and affiliation');
	}

	# validate that newName and newAffiliation are valid
	if(! empty($newName) || ! empty($newAffiliation)) {
		$validate = array('name' => $name,
		                  'affiliation' => $affiliation);
		if(! empty($newName)) {
			$validate['name'] = $newName;
			$tmp = mysql_escape_string($newName);
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

	if(! empty($newOwner)) {
		$newownerid = getUserlistID(mysql_escape_string($newOwner));
		$updates[] = "ownerid = $newownerid";
	}
	if(! empty($newManagingGroup)) {
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
/// \b Note: it is possible to have a group with no members in which case
/// success will be returned with an empty array for members
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetUserGroupMembers($name, $affiliation) {
	global $user;
	if(! in_array('groupAdmin', $user['privileges'])) {
		return array('status' => 'error',
		             'errorcode' => 16,
		             'errormsg' => 'access denied for managing user groups');
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
	# if not owner and not member of managing group, no access
	if($user['id'] != $row['ownerid'] && 
	   ! array_key_exists($row['editgroupid'], $user['groups'])) {
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
/// \b success - users successfully added to the group
///
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
		             'errormsg' => 'access denied for managing user groups');
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
	# if not owner and not member of managing group, no access
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
		$esc_user = mysql_escape_string($_user);
		if(validateUserid($esc_user) == 1)
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
/// \b success - users successfully removed from the group
///
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
		             'errormsg' => 'access denied for managing user groups');
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
	# if not owner and not member of managing group, no access
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
		$esc_user = mysql_escape_string($_user);
		# check that affiliation of user can be determined because getUserlistID
		#   will abort if it can't find it
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
?>
