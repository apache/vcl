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
 * The URL you will use to submit RPC calls is\n\n
 * https://vcl.ncsu.edu/scheduling/index.php?mode=xmlrpccall\n\n
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
 * example: myuserid\@NCSU -
 * currently, you need to  contact vcl_help@ncsu.edu to find out your
 * affiliation, but in the future there will be an API method of obtaining
 * this\n
 * \b X-Pass - the password you would use to log in to the VCL site\n
 * \n
 * There is one other additional HTTP header you must send:\n
 * \b X-APIVERSION - set this to 2\n\n
 * 
 * <h2>API Version 1</h2>
 * This version is being phased out in favor of version 2. Documentation is
 * provided for those currently using version 1 who are not ready to switch
 * to using version 2.\n\n
 * To connect to VCL with XML RPC, you will need to obtain a key. Contact
 * vcl_help@ncsu.edu to get one.\n
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
/// \brief gets all of the affilations for which users can log in to VCL
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
