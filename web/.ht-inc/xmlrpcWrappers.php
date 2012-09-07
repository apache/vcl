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
/// HTTP headers do not need to be passed\n
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
/// \brief gets the images to which the user has access\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetImages() {
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$resources["image"] = removeNoCheckout($resources["image"]);
	$return = array();
	foreach($resources['image'] as $key => $val) {
        $notes = getImageNotes($key);
        $tmp = array('id' => $key,
                     'name' => $val,
                     'description' => $notes['description'],
                     'usage' => $notes['usage']);
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
/// \brief tries to make a request\n
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

	$images = getImages();
	$revisionid = getProductionRevisionid($imageid);
	$rc = isAvailable($images, $imageid, $revisionid, $start, $end);
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
/// \fn XMLRPCaddRequestWithEnding($imageid, $start, $end, $foruser)
///
/// \param $imageid - id of an image
/// \param $start - "now" or unix timestamp for start of reservation; will
/// use a floor function to round down to the nearest 15 minute increment
/// for actual reservation
/// \param $end - unix timestamp for end of reservation; will be rounded up to
/// the nearest 15 minute increment
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
/// \brief tries to make a request with the specified ending time\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddRequestWithEnding($imageid, $start, $end, $foruser='') {
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

	$images = getImages();
	$revisionid = getProductionRevisionid($imageid);
	$rc = isAvailable($images, $imageid, $revisionid, $start, $end);
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
/// \b future - start time of request is in the future\n
///
/// \brief determines and returns the status of the request\n
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
/// \fn XMLRPCgetUserGroups()
///
/// \return an array listing all of the groups to which the given user
/// has read or write access. Each usergroup will be an array with the 
/// following keys:\n
/// id\n
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
/// maxextendtime\n
/// overlapResCount\n
///
/// \brief builds a list of user groups\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetUserGroups($groupType=0, $affiliationid=0) {
    global $user;
    $groups = getUserGroups($groupType, $affiliationid);

    // Filter out any groups to which the user does not have access.
    $usergroups = array();
    foreach($groups as $id => $group){
        if($group['ownerid'] == $user['id'] || 
            (array_key_exists("editgroupid", $group) &&
            array_key_exists($group['editgroupid'], $user["groups"])) || 
            (array_key_exists($id, $user["groups"]))){
            array_push($usergroups, $group);
        }
    }
    return array(
            "status" => "success",
            "groups" => $usergroups);
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
/// request and returns info about how to connect to the computer\n
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
        $connectport = $requestData["reservations"][0]["connectport"];
        $connectMethods = getImageConnectMethodTexts(
                $requestData["reservations"][0]["imageid"],
                $requestData["reservations"][0]["imagerevisionid"]);
		if($requestData["forimaging"])
			$thisuser = 'Administrator';
		else
			if(preg_match('/(.*)@(.*)/', $user['unityid'], $matches))
				$thisuser = $matches[1];
			else
				$thisuser = $user['unityid'];
        foreach($connectMethods as $key => $cm){
            $connecttext = $cm["connecttext"];
            $connecttext = preg_replace("/#userid#/", $thisuser, $connecttext); 
            $connecttext = preg_replace("/#password#/", $passwd, $connecttext); 
            $connecttext = preg_replace("/#connectIP#/", $serverIP, $connecttext); 
            $connecttext = preg_replace("/#connectport#/", $connectport, $connecttext); 
            $connectMethods[$key]["connecttext"] = $connecttext;
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
/// started needs to be extended, delete the request and submit a new one\n
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
	if($timeToNext > -1) {
		foreach($request["reservations"] as $res) {
			if(! moveReservationsOffComputer($res["computerid"])) {
				$movedall = 0;
				break;
			}
		}
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
	                  $startts, $newendts, $requestid);
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
	updateRequest($requestid);
	return array('status' => 'success');
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
/// \brief removes an image from a resource group\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveImageFromGroup($name, $imageid){
    $groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
    
    if($groupid = getResourceGroupID("image/$name")){
        if(!array_key_exists($groupid, $groups['image'])){
            return array('status' => 'error',
                         'errorcode' => 46,
                         'errormsg' => 'Unable to access image group');
        }
        $resources = getUserResources(array("imageAdmin"), array("manageGroup"));
        if(!array_key_exists($imageid, $resources['image'])){
            return array('status' => 'error',
                         'errorcode' => 47,
                         'errormsg' => 'Unable to access image');
        }

        $allimages = getImages();
        $query = "DELETE FROM resourcegroupmembers "
               . "WHERE resourceid={$allimages[$imageid]['resourceid']} "
               . "AND resourcegroupid=$groupid";
        doQuery($query, 287);
        return array('status' => 'success');
    } else {
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
/// \brief adds an image to a resource group\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddImageToGroup($name, $imageid){
    $groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
    
    if($groupid = getResourceGroupID("image/$name")){
        if(!array_key_exists($groupid, $groups['image'])){
            return array('status' => 'error',
                         'errorcode' => 46,
                         'errormsg' => 'Unable to access image group');
        }
        $resources = getUserResources(array("imageAdmin"), array("manageGroup"));
        if(!array_key_exists($imageid, $resources['image'])){
            return array('status' => 'error',
                         'errorcode' => 47,
                         'errormsg' => 'Unable to access image');
        }

        $allimages = getImages();
        $query = "INSERT IGNORE INTO resourcegroupmembers "
               . "(resourceid, resourcegroupid) VALUES "
               . "({$allimages[$imageid]['resourceid']}, $groupid)";
        doQuery($query, 287);
        return array('status' => 'success');
    } else {
        return array('status' => 'error',
                     'errorcode' => 83,
                     'errormsg' => 'invalid resource group name');
    }
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
/// \b success - returns an array of images\n
///
/// \brief gets a list of all images in a particular group\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetGroupImages($name){
    if($groupid = getResourceGroupID("image/$name")){
        $membership = getResourceGroupMemberships('image');
        $resources = getUserResources(array("imageAdmin"),
                                      array("manageGroup"));

        $images = array();
        foreach($resources['image'] as $imageid => $image){
            if(array_key_exists($imageid, $membership['image']) &&
                    in_array($groupid, $membership['image'][$imageid])){
                array_push($images, array('id' => $imageid, 'name' => $image));
            }
        }
        return array('status' => 'success',
                     'images' => $images);

    } else {
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
/// \brief map an image group to a computer group\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddImageGroupToComputerGroup($imageGroup, $computerGroup){
    $imageid = getResourceGroupID("image/$imageGroup");
    $compid = getResourceGroupID("computer/$computerGroup");
    if($imageid && $compid){
        $tmp = getUserResources(array("imageAdmin"),
                                array("manageMapping"), 1);
        $imagegroups = $tmp['image'];
        $tmp = getUserResources(array("computerAdmin"),
                                array("manageMapping"), 1);
        $computergroups = $tmp['computer'];

        if(array_key_exists($compid, $computergroups) &&
            array_key_exists($imageid, $imagegroups)){
            $mapping = getResourceMapping("image", "computer",
                                          $imageid,
                                          $compid);
            if(!array_key_exists($imageid, $mapping) ||
                !array_key_exists($compid, $mapping[$imageid])){
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
        } else {
            return array('status' => 'error',
                         'errorcode' => 84,
                         'errormsg' => 'cannot access computer and/or image group');
        }
    } else {
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
/// \b success - successfully removed the mapping from an 
///     image group to a computer group\n
///
/// \brief remove the mapping of an image group to a computer group\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveImageGroupFromComputerGroup($imageGroup, $computerGroup){
    $imageid = getResourceGroupID("image/$imageGroup");
    $compid = getResourceGroupID("computer/$computerGroup");
    if($imageid && $compid){
        $tmp = getUserResources(array("imageAdmin"),
                                array("manageMapping"), 1);
        $imagegroups = $tmp['image'];
        $tmp = getUserResources(array("computerAdmin"),
                                array("manageMapping"), 1);
        $computergroups = $tmp['computer'];

        if(array_key_exists($compid, $computergroups) &&
            array_key_exists($imageid, $imagegroups)){
            $mapping = getResourceMapping("image", "computer",
                                          $imageid,
                                          $compid);
            if(array_key_exists($imageid, $mapping) &&
                array_key_exists($compid, $mapping[$imageid])){
                $query = "DELETE FROM resourcemap "
					   . "WHERE resourcegroupid1 = $imageid AND "
					   .       "resourcetypeid1 = 13 AND "
					   .       "resourcegroupid2 = $compid AND "
					   .       "resourcetypeid2 = 12";
			    doQuery($query, 101);
            }
            return array('status' => 'success');
        } else {
            return array('status' => 'error',
                         'errorcode' => 84,
                         'errormsg' => 'cannot access computer and/or image group');
        }
    } else {
        return array('status' => 'error',
                     'errorcode' => 83,
                     'errormsg' => 'invalid resource group name');
    }
}


////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCgetNodes($root)
///
/// \param $root - (optional) the ID of the node forming the root of the hierarchy
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - returns an array of nodes\n
///
/// \brief gets a list of all nodes in the privilege tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetNodes($root=NULL){
    global $user;
    if(in_array("nodeAdmin", $user['privileges'])){
        $topNodes = $root ? getChildNodes($root) : getChildNodes();
        $nodes = array();
        $stack = array();
        foreach($topNodes as $id => $node){
            $node['id'] = $id;
            array_push($nodes, $node);
            array_push($stack, $node);
        } 
        while(count($stack)){
            $item = array_shift($stack);
            $children = getChildNodes($item['id']);
            foreach($children as $id => $node){
                $node['id'] = $id;
                array_push($nodes, $node);
                array_push($stack, $node);
            }
        }
        return array(
            'status' => 'success',
            'nodes' => $nodes);
    } else {
        return array(
            'status' => 'error',
            'errorcode' => 56,
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
///     location in the privilege tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCnodeExists($nodeName, $parentNode){
    global $user;
    if(in_array("nodeAdmin", $user['privileges'])){
        // does a node with this name already exist?
        $query = "SELECT id "
               . "FROM privnode "
               . "WHERE name = '$nodeName' AND parent = $parentNode";
        $qh = doQuery($query, 335);
        if(mysql_num_rows($qh)){
            return array('status' => 'success', 'exists' => TRUE);
        } else {
            return array('status' => 'success', 'exists' => FALSE);
        }
    } else {
        return array(
            'status' => 'error',
            'errorcode' => 56,
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
/// \brief delete a node in the privilege tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveNode($nodeID){
    require_once(".ht-inc/privileges.php");
    global $user;
    if(!in_array("nodeAdmin", $user['privileges'])){
        return array(
            'status' => 'error',
            'errorcode' => 56,
            'errormsg' => 'User cannot administer nodes');
    }
    if(!checkUserHasPriv("nodeAdmin", $user['id'], $nodeID)){
        return array(
            'status' => 'error',
            'errorcode' => 57,
            'errormsg' => 'User cannot edit this node');
    }
    $nodes = recurseGetChildren($nodeID);
    array_push($nodes, $nodeID);
    $deleteNodes = implode(',', $nodes);
    $query = "DELETE FROM privnode "
           . "WHERE id IN ($deleteNodes)";
    doQuery($query, 345);
    return array(
            'status' => 'success');
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
/// \brief add a node to the privilege tree as a child of the
///     specified parent node\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddNode($nodeName, $parentNode){
    require_once(".ht-inc/privileges.php");
    global $user;
    if(in_array("nodeAdmin", $user['privileges'])){
        if(!$parentNode){
            $topNodes = getChildNodes();
            $keys = array_keys($topNodes);
            $parentNode = array_shift($keys);
        }

        if(!preg_match("/^[-A-Za-z0-9_\. ]+$/", $nodeName)){
            return array('status' => 'error',
                         'errorcode' => 48,
                         'errormsg' => 'Invalid node name');
        }

        if(checkUserHasPriv("nodeAdmin", $user['id'], $parentNode)){
            $nodeInfo = getNodeInfo($parentNode);
            $query = "SELECT id "
                   . "FROM privnode "
                   . "WHERE name = '$nodeName' AND parent = $parentNode";
            $qh = doQuery($query, 335);
            if(mysql_num_rows($qh)){
                return array('status' => 'error',
                             'errorcode' => 50,
                             'errormsg' => 'A node of that name already exists under ' . $nodeInfo['name']);
            }
            $query = "INSERT IGNORE INTO privnode "
                   .        "(parent, name) "
                   . "VALUES "
                   .        "($parentNode, '$nodeName')";
            doQuery($query, 337);
            $qh = doQuery("SELECT LAST_INSERT_ID() FROM privnode", 101);
            if(!$row = mysql_fetch_row($qh)){
                return array('status' => 'error',
                             'errorcode' => 51,
                             'errormsg' => 'Could not add node to database');
            }
            $nodeid = $row[0];
            return array('status' => 'success',
                         'nodeid' => $nodeid);
        } else {
            return array('status' => 'error',
                         'errorcode' => 49,
                         'errormsg' => 'Unable to add node at this location');
        }
    } else {
        return array(
            'status' => 'error',
            'errorcode' => 56,
            'errormsg' => 'User cannot access node content');
    }
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
/// \brief remove privileges from a resource group in the privilege
///      node tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveResourceGroupPriv($name, $type, $nodeid, $permissions){
    require_once(".ht-inc/privileges.php");
    global $user;

    if(! checkUserHasPriv("resourceGrant", $user['id'], $nodeid)){
        return array('status' => 'error',
                     'errorcode' => 53,
                     'errormsg' => 'Unable to remove group privileges on this node');
    }
    if($typeid = getResourceTypeID($type)){
        if(!checkForGroupName($name, 'resource', '', $typeid)){
            return array('status' => 'error',
                         'errorcode' => 28,
                         'errormsg' => 'resource group does not exist');
        }
        $perms = explode(':', $permissions);
        updateResourcePrivs("$type/$name", $nodeid, array(), $perms);
        return array('status' => 'success');
    } else {
        return array('status' => 'error',
                     'errorcode' => 56,
                     'errormsg' => 'Invalid resource type');
    }
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
/// \b success - an additional element is returned:
/// \li \b privileges - a list of privileges available
///
/// \brief get a list of privileges for a user group at a particular
///     location in the privilege tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetUserGroupPrivs($name, $affiliation, $nodeid){
    require_once(".ht-inc/privileges.php");
    global $user;

    if(! checkUserHasPriv("userGrant", $user['id'], $nodeid)){
        return array('status' => 'error',
                     'errorcode' => 53,
                     'errormsg' => 'Unable to add resource group to this node');
    }

	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;

    $privileges = array();
    $nodePrivileges = getNodePrivileges($nodeid, 'usergroups');
    $cascadedNodePrivileges = getNodeCascadePrivileges($nodeid, 'usergroups'); 
    $cngp = $cascadedNodePrivileges['usergroups'];
    $ngp = $nodePrivileges['usergroups'];
    if(array_key_exists($name, $cngp)){
        foreach($cngp[$name]['privs'] as $p){
            if(! array_key_exists($name, $ngp) ||
                    ! in_array("block", $ngp[$name]['privs'])){
                array_push($privileges, $p);
            }
        }
    }
    if(array_key_exists($name, $ngp)){
        foreach($ngp[$name]['privs'] as $p){
            if($p != "block"){
                array_push($privileges, $p);
            }
        }
    }

    return array(
        'status' => 'success',
        'privileges' => array_unique($privileges));
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
/// \b success - an additional element is returned:
/// \li \b privileges - a list of privileges available
///
/// \brief get a list of privileges for a resource group at a particular
///     location in the privilege tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetResourceGroupPrivs($name, $type, $nodeid){
    require_once(".ht-inc/privileges.php");
    global $user;

    if(! checkUserHasPriv("resourceGrant", $user['id'], $nodeid)){
        return array('status' => 'error',
                     'errorcode' => 53,
                     'errormsg' => 'Unable to add resource group to this node');
    }

    if($typeid = getResourceTypeID($type)){
        if(!checkForGroupName($name, 'resource', '', $typeid)){
            return array('status' => 'error',
                         'errorcode' => 28,
                         'errormsg' => 'resource group does not exist');
        }
        $nodePrivileges = getNodePrivileges($nodeid, 'resources');
        $nodePrivileges = getNodeCascadePrivileges($nodeid, 'resources', $nodePrivileges); 
        foreach($nodePrivileges['resources'] as $resource => $privs){
            if(strstr($resource, "$type/$name")){
                return array(
                    'status' => 'success',
                    'privileges' => $privs);
            }
        }
        return array(
            'status' => 'error',
            'errorcode' => 29,
            'errormsg' => 'could not find resource name in privilege list');
    } else {
        return array('status' => 'error',
                     'errorcode' => 56,
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
/// \brief add privileges for a resource group at a particular
///     location in the privilege tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddResourceGroupPriv($name, $type, $nodeid, $permissions){
    require_once(".ht-inc/privileges.php");
    global $user;

    if(! checkUserHasPriv("resourceGrant", $user['id'], $nodeid)){
        return array('status' => 'error',
                     'errorcode' => 53,
                     'errormsg' => 'Unable to add resource group to this node');
    }

    if($typeid = getResourceTypeID($type)){
        if(!checkForGroupName($name, 'resource', '', $typeid)){
            return array('status' => 'error',
                         'errorcode' => 28,
                         'errormsg' => 'resource group does not exist');
        }
        $perms = explode(':', $permissions);
        updateResourcePrivs("$type/$name", $nodeid, $perms, array());
        return array('status' => 'success');
    } else {
        return array('status' => 'error',
                     'errorcode' => 56,
                     'errormsg' => 'Invalid resource type');
    }
}


////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveResourceGroupPriv($name, $type, $nodeid, $permissions)
///
/// \param $name - the name of the resource group
/// \param $type - the resource group type
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
/// \brief remove privileges for a resource group at a particular
///     location in the privilege tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveUserGroupPriv($name, $affiliation, $nodeid, $permissions){
    require_once(".ht-inc/privileges.php");
	global $user;

    if(! checkUserHasPriv("userGrant", $user['id'], $nodeid)){
		return array('status' => 'error',
                     'errorcode' => 53,
                     'errormsg' => 'Unable to remove group privileges on this node');
    }

	$validate = array('name' => $name,
	                  'affiliation' => $affiliation);
	$rc = validateAPIgroupInput($validate, 1);
	if($rc['status'] == 'error')
		return $rc;

    $groupid = $rc['id'];
    $groupname = "$name@$affiliation";
    $perms = explode(':', $permissions);
    $usertypes = getTypes('users');
    array_push($usertypes["users"], "block");
	array_push($usertypes["users"], "cascade");
    $cascadePrivs = getNodeCascadePriviliges($nodeid, "usergroups");
    $removegroupprivs = array();
    if(array_key_exists($groupname, $cascadePrivs['usergroups'])){
        foreach($perms as $permission){
            if(in_array($permission, $cascadePrivs['usergroups'][$groupname]['privs'])){
                array_push($removegroupprivs, $permission);
            }
        }
        $diff = array_diff($cascadePrivs['usergroups'][$groupname], $removegroupprivs);
        if(count($diff) == 1 && in_array("cascade", $diff)){
            array_push($removegroupprivs, "cascade");
	}
	}
    if(empty($removegroupprivs)){
		return array('status' => 'error',
                     'errorcode' => 53,
                     'errormsg' => 'Invalid or missing permissions list supplied');
	}

    updateUserOrGroupPrivs($groupid, $nodeid, array(), $removegroupprivs, "group");
    return array('status' => 'success');
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
/// \brief add privileges for a user group at a particular
///     location in the privilege tree\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddUserGroupPriv($name, $affiliation, $nodeid, $permissions){
    require_once(".ht-inc/privileges.php");
    global $user;

    if(! checkUserHasPriv("userGrant", $user['id'], $nodeid)){
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
	$newgroupprivs = array();
	foreach($usertypes["users"] as $type) {
		if(in_array($type, $perms))
			array_push($newgroupprivs, $type);
	}
	if(empty($newgroupprivs) || (count($newgroupprivs) == 1 && 
           in_array("cascade", $newgroupprivs))) {
		return array('status' => 'error',
                    'errorcode' => 53,
                    'errormsg' => 'Invalid or missing permissions list supplied');
	}
    updateUserOrGroupPrivs($groupid, $nodeid, $newgroupprivs, array(), "group");
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
/// started needs to be modifed, delete the request and submit a new one\n
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
		foreach($request["reservations"] as $res) {
			if(! moveReservationsOffComputer($res["computerid"])) {
				$movedall = 0;
				break;
			}
		}
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
	                  $startts, $end, $requestid);
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
	updateRequest($requestid);
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
/// \brief ends/deletes a request\n
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
/// \brief gets information about all of user's requests\n
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
/// \fn XMLRPCblockAllocation($imageid, $start, $end, $numMachines,
///                           $usergroupid, $ignoreprivileges)
///
/// \param $imageid - id of the image to be used
/// \param $start - mysql datetime for the start time (i.e. machines should be
/// prep'd and ready by this time)
/// \param $end - mysql datetime for the end time
/// \param $numMachines - number of computers to allocate
/// \param $usergroupid - id of user group for checking user access to machines
/// \param $ignoreprivileges (optional, default=0) - 0 (false) or 1 (true) - set
/// to 1 to select computers from any that are mapped to be able to run the
/// image; set to 0 to only select computers from ones that are both mapped and
/// that users in the usergroup assigned to this block allocation have been
/// granted access to through the privilege tree
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
/// \li \b allocated - total number of desired allocations that have been
/// processed
/// \li \b unallocated - total number of desired allocations that have not been
/// processed
///
/// \b warning - there was a non-fatal issue that occurred while processing
/// the call; there will be four additional elements in this case:
/// \li \b warningcode - warning number
/// \li \b warningmsg - warning string
/// \li \b allocated - total number of desired allocations that have been
/// processed
/// \li \b unallocated - total number of desired allocations that have not been
/// processed
///
/// note that status may be warning, but allocated may be 0 indicating there
/// were no errors that occurred, but there simply were not any machines
/// available
///
/// \brief creates and processes a block allocation according to the passed
/// in criteria\n
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
	       .        "expireTime, "
	       .        "status) "
	       . "VALUES "
	       .        "('$name', "
	       .        "$imageid, "
	       .        "$numMachines, "
	       .        "$usergroupid, "
	       .        "'list', "
	       .        "$ownerid, "
	       .        "0, "
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
/// elements in this case:
/// \li \b allocated - total number of desired allocations that have been
/// processed
/// \li \b unallocated - total number of desired allocations that have not been
/// processed
///
/// \b warning - there was a non-fatal issue that occurred while processing
/// the call; there will be four additional elements in this case:
/// \li \b warningcode - warning number
/// \li \b warningmsg - warning string
/// \li \b allocated - total number of desired allocations that have been
/// processed
/// \li \b unallocated - total number of desired allocations that have not been
/// processed
///
/// note that status may be warning, but allocated may be 0 indicating there
/// were no errors that occurred, but there simply were not any machines
/// available
///
/// \brief processes a block allocation for the blockTimes entry associated
/// with blockTimesid\n
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
			                  $unixend, $row['reqid'], $row['userid'],
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

	# staggering: stagger start times for this round (ie, don't worry about
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
		                  $unixend, 0, $userid, $ignoreprivileges);
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
		semUnlock();
		$blockComps = implode(',', $blockCompVals);
		$query = "INSERT INTO blockComputers "
		       .        "(blockTimeid, computerid, imageid, reloadrequestid) "
		       . "VALUES $blockComps";
		doQuery($query, 101);
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
/// \param $custom (optional, default=1) - set custom flag for user group; if
///                set to 0, $owner and $managingGroup will be ignored and group
///                membership will be managed via authentication protocol
///
/// \return an array with at least one index named 'status' which will have
/// one of these values:\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number
/// \li \b errormsg - error string
///
/// \b success - user group was successfully created
///
/// \brief creates a new user group with the specified parameters\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddUserGroup($name, $affiliation, $owner, $managingGroup,
                            $initialMaxTime, $totalMaxTime, $maxExtendTime,
                            $custom=1) {
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
	                  'maxExtendTime' => $maxExtendTime,
	                  'custom' => $custom);
	$rc = validateAPIgroupInput($validate, 0);
	if($rc['status'] == 'error')
		return $rc;
	if($custom != 0 && $custom != 1)
		$custom = 1;
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
/// \b success - an 'groups' element will contain a list of groups
///         of the given type.\n
///
/// \brief get a list of resource groups of a particular type\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCgetResourceGroups($type){
    global $user;
    $resources = getUserResources(array("groupAdmin"), array("manageGroup"), 1);
    if(array_key_exists($type, $resources)){
        return array(
            'status' => 'success',
            'groups' => $resources[$type]);
    } else {
        return array(
            'status' => 'error',
            'errorcode' => 29,
            'errormsg' => 'invalid resource group type');
    }
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
/// \brief remove a resource group\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveResourceGroup($name, $type){
    global $user;
    if(! in_array("groupAdmin", $user['privileges'])){
        return array('status' => 'error',
                     'errorcode' => 16,
                     'errormsg' => 'access denied for managing user groups');
    }

    if($groupid = getResourceGroupID("$type/$name")){
        $userresources = getUserResources(
            array("groupAdmin"),
            array("manageGroup"), 1);
        if(array_key_exists($type, $userresources)){
            if(array_key_exists($groupid, $userresources[$type])){
                $query = "DELETE FROM resourcegroup "
                       . "WHERE id = $groupid";
                doQuery($query, 315);
                return array('status' => 'success');
            }
        }
    }
    return array('status' => 'error',
                 'errorcode' => 39,
                 'errormsg' => 'invalid resource group name');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCremoveUserGroup($name, $affiliation)
///
/// \param $name - the name of the resource group
/// \param $affiliation - the affiliation of the user group
///
/// \return an array with at least one index named 'status' which will have
/// one of these values\n
/// \b error - error occurred; there will be 2 additional elements in the array:
/// \li \b errorcode - error number\n
/// \li \b errormsg - error string\n
///
/// \b success - the user group was removed\n
///
/// \brief remove a user group\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCremoveUserGroup($name, $affiliation){
    global $user;

    if(! in_array("groupAdmin", $user['privileges'])){
        return array('status' => 'error',
                     'errorcode' => 16,
                     'errormsg' => 'access denied for managing user groups');
    }

    $validate = array(
        'name' => $name,
        'affiliation' => $affiliation);

    $rc = validateAPIgroupInput($validate, 1);
    if($rc['status'] == 'error')
        return $rc;

    $groups = getUserGroups();
    $groupid = $rc['id'];
    if(array_key_exists($groupid, $groups)){
        $group = $groups[$groupid];
        if($group['ownerid'] == $user['id'] ||
                (array_key_exists("editgroupid", $group) &&
                array_key_exists($group['editgroupid'], $user["groups"])) || 
                (array_key_exists($groupid, $user["groups"]))){
            $query = "DELETE FROM usergroup "
                   . "WHERE id = $groupid";
            doQuery($query, 315);
            return array('status' => 'success');
        }
    }
    return array(
        'status' => 'error',
        'errorcode' => 17,
        'errormsg' => 'access denied for editing specified group');
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
/// \b success - the resource group was added\n
///
/// \brief add a resource group\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCaddResourceGroup($name, $managingGroup, $type){
    global $user;
    if(! in_array("groupAdmin", $user['privileges'])){
        return array('status' => 'error',
                     'errorcode' => 16,
                     'errormsg' => 'access denied for managing user groups');
    }

    $validate = array(
        'managingGroup' => $managingGroup);
    
    $rc = validateAPIgroupInput($validate, 0);
    if($rc['status'] == 'error')
        return $rc;

    if($typeid = getResourceTypeID($type)){
        if(checkForGroupName($name, 'resource', '', $typeid)){
            return array('status' => 'error',
                         'errorcode' => 28,
                         'errormsg' => 'resource group already exists');
        }
        $data = array(
            'type' => $type,
            'ownergroup' => $rc['managingGroupID'],
            'resourcetypeid' => $typeid,
            'name' => $name);
        if(! addGroup($data)){
            return array('status' => 'error',
                         'errorcode' => 26,
                         'errormsg' => 'failure while adding group to database');
        }
    } else {
        return array('status' => 'error',
                     'errorcode' => 68,
                     'errormsg' => 'invalid resource type');
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
/// \brief gets information about a user group\n
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
/// \brief deletes a user group along with all of its privileges\n
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
/// that item unchanged\n
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

	if(! empty($newOwner)) {
		$newownerid = getUserlistID(mysql_real_escape_string($newOwner));
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
/// success will be returned with an empty array for members\n
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
/// \brief adds users to a group\n
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
		$esc_user = mysql_real_escape_string($_user);
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
/// \brief removes users from a group\n
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
		$esc_user = mysql_real_escape_string($_user);
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
/// the request state to image\n
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
	require_once(".ht-inc/images.php");
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
		$rc = updateExistingImage($requestid, $reqData['userid'], $comments, 1);
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
		              'description' => $desc,
		              'usage' => '',
		              'owner' => "{$ownerdata['unityid']}@{$ownerdata['affiliation']}",
		              'prettyname' => "Autocaptured ({$ownerdata['unityid']} - $requestid)",
		              'minram' => 64,
		              'minprocnumber' => 1,
		              'minprocspeed' => 500,
		              'minnetwork' => 10,
		              'maxconcurrent' => '',
		              'checkuser' => 1,
		              'rootaccess' => 1,
		              'sysprep' => 1,
		              'comments' => $comments,
		              'connectmethodids' => implode(',', array_keys($connectmethods)));
		$rc = submitAddImage($data, 1);
		if($rc == 0) {
			return array('status' => 'error',
			             'errorcode' => 50,
			             'errormsg' => 'error encountered while attempting to create image');
		}
	}
	return array('status' => 'success');
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn XMLRPCdeployServer($imageid, $start, $end, $admingroup, $logingroup,
///                        $ipaddr, $macaddr, $monitored, $foruser)
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
/// \brief tries to make a server request\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCdeployServer($imageid, $start, $end, $admingroup='',
                            $logingroup='', $ipaddr='', $macaddr='',
                            $monitored=0, $foruser='') {
	global $user, $remoteIP;
	if(! in_array("serverProfileAdmin", $user["privileges"])) {
		return array('status' => 'error',
		             'errorcode' => 60,
		             'errormsg' => "access denied to deploy server");
	}
	$imageid = processInputData($imageid, ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
	$images = removeNoCheckout($resources["image"]);
	$extraimages = getServerProfileImages($user['id']);
	if(! array_key_exists($imageid, $images) &&
	   ! array_key_exists($imageid, $extraimages)) {
		return array('status' => 'error',
		             'errorcode' => 3,
		             'errormsg' => "access denied to $imageid");
	}
	if($admingroup != '' || $logingroup != '')
		$usergroups = getUserEditGroups($user['id']);
	if($admingroup != '') {
		$admingroup = processInputData($admingroup, ARG_STRING);
		if(preg_match('@', $admingroup)) {
			$tmp = explode('@', $admingroup);
			$escadmingroup = mysql_real_escape_string($tmp[0]);
			$affilid = getAffiliationID(mysql_real_escape_string($tmp[1]));
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
		$query = "SELECT id "
		       . "FROM usergroup "
		       . "WHERE name = '$escadmingroup' AND "
		       .       "affiliationid = $affilid";
		$qh = doQuery($query, 300);
		if($row = mysql_fetch_assoc($qh))
			$admingroupid = $row['id'];
		else {
			return array('status' => 'error',
			             'errorcode' => 52,
			             'errormsg' => "unknown admin user group: $admingroup");
		}
		if(! array_key_exists($admingroupid, $usergroups)) {
			return array('status' => 'error',
			             'errorcode' => 53,
			             'errormsg' => "access denied to admin user group: $admingroup");
		}
	}
	else
		$admingroupid = '';
	if($logingroup != '') {
		$logingroup = processInputData($logingroup, ARG_STRING);
		if(preg_match('@', $logingroup)) {
			$tmp = explode('@', $logingroup);
			$esclogingroup = mysql_real_escape_string($tmp[0]);
			$affilid = getAffiliationID(mysql_real_escape_string($tmp[1]));
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
		$query = "SELECT id "
		       . "FROM usergroup "
		       . "WHERE name = '$esclogingroup' AND "
		       .       "affiliationid = $affilid";
		$qh = doQuery($query, 300);
		if($row = mysql_fetch_assoc($qh))
			$logingroupid = $row['id'];
		else {
			return array('status' => 'error',
			             'errorcode' => 55,
			             'errormsg' => "unknown login user group: $logingroup");
		}
		if(! array_key_exists($logingroupid, $usergroups)) {
			return array('status' => 'error',
			             'errorcode' => 56,
			             'errormsg' => "access denied to login user group: $logingroup");
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
	                  0, 0, 0, 0, $ipaddr, $macaddr);
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
	$fields = array('requestid');
	$values = array($return['requestid']);
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
/// calls to this site to work\n
///
////////////////////////////////////////////////////////////////////////////////
function XMLRPCtest($string) {
	$string = processInputData($string, ARG_STRING);
	return array('status' => 'success',
	             'message' => 'RPC call worked successfully',
	             'string' => $string);
}
?>
