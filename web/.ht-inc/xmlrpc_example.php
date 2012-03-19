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

session_start();

$url = "http://{$_SERVER['HTTP_HOST']}{$_SERVER['PHP_SELF']}";
print "<a href=\"$url?state=test\">Test</a><br>\n";
print "<a href=\"$url?state=listimages\">List Available Images</a><br>\n";
print "<a href=\"$url?state=addrequest\">Add request for Test Image 1</a><br>\n";
print "<a href=\"$url?state=requeststatus\">Get status of request</a><br>\n";
print "<a href=\"$url?state=connectdata\">Get connection data</a><br>\n";
print "<a href=\"$url?state=endrequest\">End request</a><br>\n";

print "<pre>\n";

// test
if($_GET['state'] == 'test') {
	$rc = remoteVCLCall('XMLRPCtest', array('foo'));
	print_r($rc);
}
// list images
elseif($_GET['state'] == 'listimages') {
	$rc = remoteVCLCall('XMLRPCgetImages', array());
	print_r($rc);
}
// add request
elseif($_GET['state'] == 'addrequest') {
	$rc = remoteVCLCall('XMLRPCaddRequest', array(98, 'now', 60));
	if($rc['status'] == 'success') {
		print "request id is {$rc['requestid']}<br>\n";
		$_SESSION['requestid'] = $rc['requestid'];
	}
	else {
		print_r($rc);
	}
}
// get request status
elseif($_GET['state'] == 'requeststatus') {
	if(! array_key_exists('requestid', $_SESSION)) {
		print "no request created<br>\n";
		exit;
	}
	$rc = remoteVCLCall('XMLRPCgetRequestStatus', array($_SESSION['requestid']));
	print "current status of request {$_SESSION['requestid']} is {$rc['status']}";
}
// get connection data
elseif($_GET['state'] == 'connectdata') {
	if(! array_key_exists('requestid', $_SESSION)) {
		print "no request created<br>\n";
		exit;
	}
	$rc = remoteVCLCall('XMLRPCgetRequestConnectData', array($_SESSION['requestid'], $_SERVER["REMOTE_ADDR"]));
	if($rc['status'] == 'ready')
		print_r($rc);
	else
		print "status of request is {$rc['status']}";
}
// end request
elseif($_GET['state'] == 'endrequest') {
	if(! array_key_exists('requestid', $_SESSION)) {
		print "no request created<br>\n";
		exit;
	}
	$rc = remoteVCLCall('XMLRPCendRequest', array($_SESSION['requestid']));
	if($rc['status'] == 'error')
		print_r($rc);
	else {
		print "request ended<br>\n";
		unset($_SESSION['requestid']);
	}
}
print "</pre>\n";

function remoteVCLCall($method, $args) {
	$request = xmlrpc_encode_request($method, $args);
	$header  = "Content-Type: text/xml\r\n";
	$header .= "X-User: userid\r\n";    // user your userid here
	$header .= "X-Pass: password\r\n";  // user your password here
	$header .= "X-APIVERSION: 2";       // this is to allow for future changes to the api
	$context = stream_context_create(
		array(
			'http' => array(
				'method' => "POST",
				'header' => $header,
				'content' => $request
			)
		)
	);
	$file = file_get_contents("https://vcl.ncsu.edu/scheduling/index.php?mode=xmlrpccall", false, $context);
	$response = xmlrpc_decode($file);
	if(xmlrpc_is_fault($response)) {
		trigger_error("xmlrpc: {$response['faultString']} ({$response['faultCode']})");
		exit;
	}
	return $response;
}
?>
