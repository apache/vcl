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

@include_once("fckeditor/fckeditor.php");
require_once(".ht-inc/conf.php");
if(! isset($_SERVER['HTTPS']) || $_SERVER['HTTPS'] != "on") {
	header("Location: " . BASEURL . "/");
	exit;
}

$user = '';
$mysql_link_vcl = '';
$mysql_link_acct = '';
$mode = '';
$oldmode = '';
$submitErr = '';
$submitErrMsg = '';
$remoteIP = '';
$authed = '';
$viewmode = '';
$semid = '';
$semislocked = '';
unset($GLOBALS['php_errormsg']);
$cache['nodes'] = array();
$cache['unityids'] = array();
$cache['nodeprivs']['resources'] = array();
$docreaders = array();
$shibauthed = 0;

require_once(".ht-inc/states.php");

require_once('.ht-inc/errors.php');

require_once('.ht-inc/utils.php');

dbConnect();

initGlobals();

$modes = array_keys($actions['mode']);
$args = array_keys($actions['args']);
$hasArg = 0;
if(in_array($mode, $modes)) {
	$actionFunction = $actions['mode'][$mode];
	if(in_array($mode, $args)) {
		$hasArg = 1;
		$arg = $actions['args'][$mode];
	}
}
else {
	$actionFunction = "main";
}

checkAccess();

sendHeaders();

printHTMLHeader();

if($viewmode == ADMIN_DEVELOPER) {
	set_error_handler("errorHandler");
}

if($hasArg) {
	$actionFunction($arg);
}
else {
	$actionFunction();
}
printHTMLFooter();

dbDisconnect();

semUnlock();
?>
