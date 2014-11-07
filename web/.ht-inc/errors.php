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

// set the error reporting level for this script
error_reporting(E_ALL);

# 100 - 399: MySQL errors
/// array containing all the errors to be reported
$ERRORS = array (
	"1"   => "Failed to get user information from database",
	"2"   => "Failed to get semaphore resource",
	"3"   => "Failed to get acquire semaphore lock",
	"5"   => "Failed to update any rows while submitting image changes",
	"6"   => "Failed to open private key",
	"7"   => "Failed to open public key",
	"8"   => "Failed to add user to database",
	"9"   => 'getRequestInfo was called with an empty $id',
	"10"  => "Failed to insert row while submitting new image",
	"11"  => "getContinuationsData returned an empty array",
	"12"  => "Failed to determine affiliation id in getUserListID",
	"15"  => "Failed to insert row while submitting new schedule",
	"20"  => "There was an attempt submit data to the page, but the referrer was not the entry script.",
	"25"  => "Failed to get IPaddress of computer in acknowledgeRequest.",
	"30"  => "Failed to get log entry in addChangeLogEntry",
	"35"  => "Failed to retreive nisnetgroup memberships for user in updateNisNetGroups",
	"40"  => "Failed to find any usable management nodes",
	"45"  => "LDAP error",
	"50"  => "received invalid input",
	"51"  => "userid in continuation does not match logged in user",
	"52"  => "tried to add a user with the same uid as an existing user",
	"53"  => "No nodes to show on privilege tree",
	"101" => "General MySQL error",
	"104" => "Failed to select database",
	"105" => "Failed to execute query 1 in getUserInfo",
	"106" => "Failed to execute query 2 in getUserInfo",
	"107" => "Failed to execute query 1 in getOverallUserPrivs",
	"108" => "Failed to get deletefromid in addContinuationsEntry",
	"110" => "Failed to execute query 1 in showTimeTable",
	"111" => "Failed to execute query 2 in showTimeTable",
	"112" => "Failed to execute query 3 in showTimeTable",
	"113" => "Failed to get reservation data in getCompLoadLog",
	"114" => "Failed to get start date in getPendingBlockHTML",
	"115" => "Failed to execute query 1 in getOSList",
	"120" => "Failed to execute query 1 in getImages",
	"125" => "Failed to execute query 1 in isAvailable",
	"126" => "Failed to execute query 2 in isAvailable",
	"127" => "Failed to execute query 1 in getAvailableSchedules",
	"128" => "Failed to execute query 4 in isAvailable",
	"129" => "Failed to execute query 5 in isAvailable",
	"130" => "Failed to execute query 6 in isAvailable",
	"131" => "Failed to execute query 2 in addRequest",
	"132" => "Failed to fetch last insert id in addRequest",
	"133" => "Failed to execute query 3 in addRequest",
	"134" => "Failed to execute query 4 in addRequest",
	"135" => "Failed to fetch last insert id in addRequest",
	"136" => "Failed to execute query 5 in addRequest",
	"137" => "Failed to execute query 6 in addRequest",
	"138" => "Failed to fetch last insert id in addRequest",
	"140" => "Failed to execute query 1 in getUserlistID",
	"141" => "Failed to execute query 1 in getGroupID",
	"145" => "Failed to execute query 1 in updateRequest",
	"146" => "Failed to execute query 2 in updateRequest",
	"147" => "Failed to execute query 3 in updateRequest",
	"148" => "Failed to get reservationid in updateRequest",
	"150" => "Failed to execute query 1 in deleteRequest",
	"151" => "Failed to execute query 2 in deleteRequest",
	"152" => "Failed to execute query 3 in deleteRequest",
	"153" => "Failed to execute query 4 in deleteRequest",
	"154" => "Failed to execute query 5 in deleteRequest",
	"155" => "Failed to execute query 1 in getTimeSlots",
	"156" => "Failed to execute query 2 in getTimeSlots",
	"160" => "Failed to execute query 1 in getUserRequests",
	"165" => "Failed to execute query 1 in getRequestInfo",
	"170" => "Failed to execute query 1 in getImageId",
	"175" => "Failed to execute query 1 in getOSId",
	"176" => "Failed to execute query 1 in getStates",
	"178" => "Failed to execute query 1 in getPlatforms",
	"179" => "Failed to execute query 1 in getSchedules",
	"180" => "Failed to execute query 1 in listComputers",
	"185" => "Failed to execute query 1 in updateComputer",
	"190" => "Failed to execute query 1 in submitDeleteComputer",
	"191" => "Failed to execute query 2 in submitDeleteComputer",
	"195" => "Failed to execute query 1 in addComputer",
	"198" => "Failed to execute query 3 in addComputer",
	"200" => "Failed to execute query 1 in updateImage",
	"205" => "Failed to execute query 1 in Image::addResource",
	"206" => "Failed to execute query 2 in Image::addResource",
	"207" => "Failed to fetch last insert id in Image::addResource",
	"208" => "Failed to execute query 3 in Image::addResource",
	"209" => "Failed to execute query 4 in Image::addResource",
	"210" => "Failed to execute query 1 in submitDeleteImage",
	"211" => "Failed to execute query 2 in submitDeleteImage",
	"212" => "Failed to execute query 3 in submitDeleteImage",
	"215" => "Failed to execute query 1 in updateSchedule",
	"220" => "Failed to execute query 1 in addSchedule",
	"221" => "Failed to execute query 2 in addSchedule",
	"222" => "Failed to fetch last insert id in addSchedule",
	"223" => "Failed to execute query 3 in addSchedule",
	"225" => "Failed to execute query 1 in acknowledgeRequest",
	"226" => "Failed to execute query 2 in acknowledgeRequest",
	"227" => "Failed to execute query 3 in acknowledgeRequest",
	"228" => "Failed to execute query 4 in acknowledgeRequest",
	"229" => "Failed to execute query 5 in acknowledgeRequest",
	"235" => "Failed to execute query 1 in submitAddBulkComputers",
	"238" => "Failed to execute query 2 in submitAddBulkComputers",
	"240" => "Failed to execute query 1 in addUser",
	"241" => "Failed to execute query 2 in addUser",
	"242" => "Failed to fetch last insert id in addUser",
	"245" => "Failed to execute query 1 in addLoadTime",
	"250" => "Failed to execute query 1 in checkForImageUsage",
	"255" => "Failed to execute query 1 in updateUserData",
	"256" => "Failed to execute query 2 in updateUserData",
	"257" => "Failed to execute query 3 in updateUserData",
	"258" => "Failed to execute query 4 in updateUserData",
	"259" => "Failed to fetch last insert id in updateUserData",
	"260" => "Failed to execute query 1 in addLogEntry",
	"265" => "Failed to execute query 1 in addChangeLogEntry",
	"266" => "Failed to execute query 2 in addChangeLogEntry",
	"267" => "Failed to execute query 3 in addChangeLogEntry",
	"270" => "Failed to execute query 1 in updateUserPrefs",
	"275" => "Failed to execute query 1 in viewStatistics",
	"280" => "Failed to execute query 1 in getUserGroups",
	"281" => "Failed to execute query 1 in getResourceGroups",
	"282" => "Failed to execute query 1 in getResourceGroupMemberships",
	"285" => "Failed to execute query 1 in submitComputerGroups",
	"286" => "Failed to execute query 2 in submitComputerGroups",
	"287" => "Failed to execute query 1 in submitImageGroups",
	"288" => "Failed to execute query 2 in submitImageGroups",
	"290" => "Failed to execute query 1 in submitHelpForm",
	"291" => "Failed to execute query 1 in submitScheduleGroups",
	"292" => "Failed to execute query 2 in submitScheduleGroups",
	"295" => "Failed to execute query 1 in getGraphDataDay",
	"296" => "Failed to execute query 1 in getGraphDataHour",
	"300" => "Failed to execute query 1 in updateGroup",
	"301" => "Failed to execute query 2 in updateGroup",
	"305" => "Failed to execute query 1 in addGroup",
	"306" => "Failed to execute query 2 in updateNisNetGroups",
	"307" => "Failed to execute query 3 in updateNisNetGroups",
	"310" => "Failed to execute query 1 in checkForGroupUsage",
	"311" => "Failed to execute query 2 in checkForGroupUsage",
	"312" => "Failed to execute query 3 in checkForGroupUsage",
	"313" => "Failed to execute query 4 in checkForGroupUsage",
	"314" => "Failed to execute query 5 in checkForGroupUsage",
	"315" => "Failed to execute query 1 in submitDeleteGroup",
	"320" => "Failed to execute query 1 in getUserImages",
	"325" => "Failed to execute query 1 in getChildNodes",
	"330" => "Failed to execute query 1 in getNodeInfo",
	"335" => "Failed to execute query 1 in submitAddChildNode",
	"336" => "Failed to execute query 2 in submitAddChildNode",
	"340" => "Failed to execute query 1 in recurseGetChildren",
	"345" => "Failed to execute query 1 in submitDeleteNode",
	"350" => "Failed to execute query 1 in getNodePrivileges",
	"351" => "Failed to execute query 2 in getNodePrivileges",
	"352" => "Failed to execute query 3 in getNodePrivileges",
	"353" => "Failed to execute query 1 in getNodeCascadePrivileges",
	"354" => "Failed to execute query 2 in getNodeCascadePrivileges",
	"355" => "Failed to execute query 3 in getNodeCascadePrivileges",
	"356" => "Failed to execute query 4 in getNodeCascadePrivileges",
	"357" => "Failed to execute query 5 in getNodeCascadePrivileges",
	"358" => "Failed to execute query 6 in getNodeCascadePrivileges",
	"359" => "Failed to execute query 1 in computerGetResourceInfo",
	"360" => "Failed to execute query 1 in imageGetResourceInfo",
	"365" => "Failed to execute query 1 in getTypes",
	"366" => "Failed to execute query 2 in getTypes",
	"370" => "Failed to execute query 1 in getUserPrivTypeID",
	"371" => "Failed to execute query 1 in getResourceGroupID",
	"375" => "Failed to execute query 1 in updateUserGroupPrivs",
	"376" => "Failed to execute query 2 in updateUserGroupPrivs",
	"377" => "Failed to execute query 1 in updateResourcePrivs",
	"378" => "Failed to execute query 2 in updateResourcePrivs",
	"380" => "Failed to fetch last insert id in submitBlockRequest",
	"385" => "Failed to execute query in submitDeleteMgmtnode",
	"390" => "Failed to fetch salt while updating locally affiliated user password",
	"400" => "semaphore for computer(s) expired before adding entry to reservation table",
);

$XMLRPCERRORS = array(
	1 => 'Internal error while processing your method call. If the '
		. 'problem persists, please email ' . HELPEMAIL . ' for further '
		. 'assistance. In your email message, please include the time you '
		. 'made the call, the user you connected as, the method you '
		. 'called, and all passed in arguments.',
	2 => 'unknown function',
	3 => 'Access denied',
	4 => 'xmlrpccall requires SSL to be enabled - connection aborted',
	5 => 'Failed to connect to authentication server',
	6 => 'Unable to authenticate passed in X-User',
	7 => 'Unknown API version, cannot continue',
	8 => 'Unsupported API version, cannot continue',
	100 => 'overwrite this with a custom error message',
);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn errorHandler($errno, $errstr, $errfile, $errline, $errcontext)
///
/// \param $errno - level of the error raised
/// \param $errstr - error message
/// \param $errfile - (optional) filename where error occured
/// \param $errline - (optional) line number where error occured
/// \param $errcontext - (optional) array, active symbol table where error occurred
///
/// \brief reports errors
///
////////////////////////////////////////////////////////////////////////////////
function errorHandler($errno, $errstr, $errfile=NULL, $errline=NULL, $errcontext=NULL) {
	global $user;
	if(! ONLINEDEBUG || ! checkUserHasPerm('View Debug Information')) {
		cleanSemaphore();
		dbDisconnect();
		printHTMLFooter();
		exit();
	}
	print "Error encountered<br>\n";
	switch ($errno) {
	case E_USER_ERROR:
		echo "<b>FATAL</b> [$errno] $errstr<br />\n";
		echo "  Fatal error in line $errline of file $errfile";
		echo ", PHP " . PHP_VERSION . " (" . PHP_OS . ")<br />\n";
		echo "Aborting...<br />\n";
		cleanSemaphore();
		dbDisconnect();
		exit(1);
		break;
	case E_USER_WARNING:
		echo "<b>ERROR</b> [$errno] $errstr<br />\n";
		break;
	case E_USER_NOTICE:
		echo "<b>WARNING</b> [$errno] $errstr<br />\n";
		break;
	default:
		echo "Unkown error type: [$errno] $errstr<br />\n";
		break;
	}
	if(! empty($errfile) && ! empty($errline)) {
		print "Error at $errline in $errfile<br>\n";
	}
	if(! empty($errcontext)) {
		print "<pre>\n";
		print_r($errcontext);
		print "</pre>\n";
	}
	print "<br><br><br>\n";
	print "<pre>\n";
	print getBacktraceString();
	print "</pre>\n";
	cleanSemaphore();
	dbDisconnect();
	printHTMLFooter();
	exit();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getBacktraceString($includeCaller, $showArgs, $includeMe)
///
/// \param $includeCaller - show info about the calling function
/// \param $showArgs - show args passed to functions
/// \param $includeMe - show info about this function
///
/// \return a string of text with backtrace information
///
/// \brief calls debug_backtrace and nicely formats all of its information
///
////////////////////////////////////////////////////////////////////////////////
function getBacktraceString($includeCaller=TRUE, $showArgs=TRUE, $includeMe=FALSE) {
	$callArray = array();
	$argArray = array();

	$MAX_ARG_LENGTH = 64;

	$backtraceArray = debug_backtrace();
	$backtraceArray = array_reverse($backtraceArray);

	// pop last element off - 'me'
	if(! $includeMe)
		array_pop($backtraceArray);

	// includeCaller?
	if(! $includeCaller)
		array_pop($backtraceArray);

	$functionOrder = 0;
	foreach($backtraceArray as $backtraceEntry) {
		$functionOrder++;
		$callString  = "Call#:" . $functionOrder . " => ";
		if(isset($backtraceEntry["file"]))
			$callString .= basename($backtraceEntry["file"]) . ":";
		else
			$callString .= "unknown:";
		if(isset($backtraceEntry['class']))
			$callString .= $backtraceEntry['class'] . '.';
		$callString .= $backtraceEntry['function'] . '()';
		$callString .= " (line#:";
		if(isset($backtraceEntry['line']))
			$callString .= $backtraceEntry['line'] . ")";
		else
			$callString .= "unknown)";
		$callArray[] = $callString;

		if(!$showArgs)
			continue;

		$argString = "Arguments";

		if(! empty($backtraceEntry["args"])) {
			$argString .= "(" . count($backtraceEntry["args"]) . ")\n\n";
			$argNumber = 0;
			foreach($backtraceEntry["args"] as $argument) {
				$argNumber++;
				$argString .= "Argument#: $argNumber => ";
				if(is_null($argument))
					$argString .= " (null)\n";
				elseif(empty($argument))
					$argString .= " (empty " . gettype($argument) . ")\n";
				else
					$argString .= print_r($argument,TRUE) . "\n";
			}
		}
		else {
			$argString .= "(none):\n";
		}

		$argString .= "-----------------------";

		$argArray[] = $callString;
		$argArray[] = $argString;
	}

	$returnString = "\nBacktrace:\n";
	$returnString .= "=-=-=-=-=-=-=-=-=-=-=-=\n";
	foreach($callArray as $callString) {
		$returnString .= $callString . "\n";
	}

	if($showArgs) {
		$returnString .= "\nBacktrace with Arguments:\n";
		$returnString .= "=-=-=-=-=-=-=-=-=-=-=-=\n";
		foreach($argArray as $callString) {
			$returnString .= $callString . "\n";
		}
	}

	return $returnString;
}
?>
