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

chdir("..");
require_once('.ht-inc/conf.php');

require_once('.ht-inc/utils.php');
require_once('.ht-inc/errors.php');
function getFooter() {}
$noHTMLwrappers = array();

dbConnect();

header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 1 Jan 2000 00:00:00 GMT");

/*
	# check for eppn; if there, see if it is a user we already have
	if(array_key_exists('eppn', $_SERVER)) {
		#$tmp = explode('@', $_SERVER['eppn']);
		$tmp = explode(';', $_SERVER['eppn']);
		$tmp = explode('@', $tmp[0]);
		$query = "SELECT u.firstname, "
				 .        "u.lastname "
				 . "FROM user u, "
				 .      "affiliation a "
				 . "WHERE u.unityid = '{$tmp[0]}' AND "
				 .       "a.shibname = '{$tmp[1]}' AND "
				 .       "u.affiliationid = a.id";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh)) {
			$_SERVER['sn'] = $row['lastname'];
			$_SERVER['givenName'] = $row['firstname'];
		}
		else {
*/

if(! array_key_exists('eppn', $_SERVER)) {
	# check to see if any shib stuff in $_SERVER, if not redirect
	$keys = array_keys($_SERVER);
	$allkeys = '{' . implode('{', $keys);
	if(! preg_match('/\{Shib-/', $allkeys)) {
		# no shib data, clear _shibsession cookie
		#print "$allkeys<br>\n";
		foreach(array_keys($_COOKIE) as $key) {
			if(preg_match('/^_shibsession[_0-9a-fA-F]+$/', $key))
				setcookie($key, "", time() - 10, "/", $_SERVER['SERVER_NAME']);
		}
		# redirect to main select auth page
		header("Location: " . BASEURL . SCRIPT . "?mode=selectauth");
		dbDisconnect();
		exit;
	}
	print "<h2>Error with Shibboleth authentication</h2>\n";
	print "You have attempted to log in using Shibboleth from an<br>\n";
	print "institution that does not allow VCL to see your<br><br>\n";
	print "eduPersonPrincipalName.<br><br>\n";
	print "You need to contact the administrator of your institution's<br>\n";
	print "IdP to have eduPersonPrincipalName made available to VCL in<br>\n";
	print "order to log in using Shibboleth.\n";

	$msg = "Someone tried to log in to VCL using Shibboleth from an IdP "
	     . "that does not release eppn to us.\n\n"
	     . "The following data was in \$_SERVER:\n\n";
	foreach($_SERVER as $key => $val)
		$msg .= "$key => $val\n";
	$mailParams = "-f" . ENVELOPESENDER;
	mail(ERROREMAIL, "Error with VCL pages (eppn not provided)", $msg, '', $mailParams);
	dbDisconnect();
	exit;
}

// open keys
$fp = fopen(".ht-inc/keys.pem", "r");
$key = fread($fp, 8192);
fclose($fp);
$keys["private"] = openssl_pkey_get_private($key, $pemkey);
if(! $keys['private'])
	abort(6);
$fp = fopen(".ht-inc/pubkey.pem", "r");
$key = fread($fp, 8192);
fclose($fp);
$keys["public"] = openssl_pkey_get_public($key);
if(! $keys['public'])
	abort(7);

# get VCL affiliation from shib affiliation
$tmp = explode(';', $_SERVER['eppn']);
$tmp = explode('@', $tmp[0]);
$username = strtolower($tmp[0]);
$tmp1 = mysql_escape_string(strtolower($tmp[1]));
$query = "SELECT name, shibonly FROM affiliation WHERE shibname = '$tmp1'";
$qh = doQuery($query, 101);
# if shib affiliation not already in VCL, create affiliation
if(! ($row = mysql_fetch_assoc($qh))) {
	$affil = strtolower($tmp[1]);
	$tmp = explode('.', $affil);
	array_pop($tmp);
	$affilname = strtoupper(implode('', $tmp));
	$affilname = preg_replace('/[^A-Z0-9]/', '', $affilname);
	$query = "SELECT name, "
	       .        "shibname "
	       . "FROM affiliation "
	       . "WHERE name LIKE '$affilname%' "
	       . "ORDER BY name DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		if(preg_match("/$affilname([0-9]+)/", $row['name'], $matches)) {
			$cnt = $matches[1];
			$cnt++;
			$newaffilname = $affilname . $cnt;
		}
		elseif($affilname != $row['name'] && $affil != $row['shibname']) {
			$newaffilname = $affilname;
		}
		else {
			$msg = "Someone tried to log in to VCL using Shibboleth from an IdP "
			     . "affiliation that could not be automatically added.\n\n"
			     . "eppn: {$_SERVER['eppn']}\n"
			     . "givenName: {$_SERVER['givenName']}\n"
			     . "sn: {$_SERVER['sn']}\n";
			if(array_key_exists('mail', $_SERVER))
				$msg .= "mail: {$_SERVER['mail']}\n\n";
			$msg .="tried to add VCL affiliation name \"$affilname\" with "
			     . "shibname \"$affil\"";
			$mailParams = "-f" . ENVELOPESENDER;
			mail(ERROREMAIL, "Error with VCL pages (problem adding shib affil)", $msg, '', $mailParams);
			print "<html><head></head><body>\n";
			print "<h2>Error encountered</h2>\n";
			print "You have attempted to log in to VCL using a Shibboleth<br>\n";
			print "Identity Provider that VCL has not been configured to<br>\n";
			print "work with.  VCL administrators have been notified of the<br>\n";
			print "problem.<br>\n";
			print "</body></html>\n";
			dbDisconnect();
			exit;
		}
	}
	else
		$newaffilname = $affilname;
	$query = "INSERT INTO affiliation "
	       .        "(name, "
	       .        "shibname, "
	       .        "shibonly) "
	       . "VALUES "
	       .        "('$newaffilname', "
	       .        "'" . mysql_escape_string($affil) . "', "
	       .        "1)";
	doQuery($query, 101, 'vcl', 1);
	unset($row);
	$row = array('name' => $newaffilname, 'shibonly' => 1);
}
$affil = $row['name'];
# create VCL userid
$userid = "$username@$affil";

if($row['shibonly']) {
	$userdata = updateShibUser($userid);
	updateShibGroups($userdata['id'], $_SERVER['affiliation']);
	$usernid = $userdata['id'];
}
else {
	$usernid = getUserlistID($userid, 1);
	if(is_null($usernid)) {
		$tmp = updateShibUser($userid);
		$usernid = $tmp['id'];
	}
}

$affilid = getAffiliationID($affil);
addLoginLog($userid, 'shibboleth', $affilid, 1);

# uncomment the following and change EXAMPLE1 to match your needs to add all
# users from a specific affiliation to a particular user group
/*if($affil == 'EXAMPLE1') {
	$gid = getUserGroupID('All EXAMPLE1 Users', $affilid);
	$query = "INSERT IGNORE INTO usergroupmembers "
	       . "(userid, usergroupid) "
	       . "VALUES ($usernid, $gid)";
	doQuery($query, 307);
}*/

if(array_key_exists('Shib-logouturl', $_SERVER))
	$logouturl = $_SERVER['Shib-logouturl'];
else
	$logouturl = '';

# save data to shibauth table
$shibdata = array('Shib-Application-ID' => $_SERVER['Shib-Application-ID'],
                  'Shib-Identity-Provider' => $_SERVER['Shib-Identity-Provider'],
                  #'Shib-AuthnContext-Dec' => $_SERVER['Shib-AuthnContext-Decl'],
                  'Shib-logouturl' => $logouturl,
                  'eppn' => $_SERVER['eppn'],
                  'unscoped-affiliation' => $_SERVER['unscoped-affiliation'],
                  'affiliation' => $_SERVER['affiliation'],
);
$serdata = mysql_escape_string(serialize($shibdata));
$query = "SELECT id "
       . "FROM shibauth "
       . "WHERE sessid = '{$_SERVER['Shib-Session-ID']}'";
$qh = doQuery($query, 101);
if($row = mysql_fetch_assoc($qh)) {
	$shibauthid = $row['id'];
}
else {
	$ts = strtotime($_SERVER['Shib-Authentication-Instant']);
	$ts = unixToDatetime($ts);
	$query = "INSERT INTO shibauth "
	       .        "(userid, " 
	       .        "ts, "
	       .        "sessid, "
	       .        "data) "
	       . "VALUES "
	       .        "($usernid, "
	       .        "'$ts', "
	       .        "'{$_SERVER['Shib-Session-ID']}', "
	       .        "'$serdata')";
	doQuery($query, 101);
	$qh = doQuery("SELECT LAST_INSERT_ID() FROM shibauth", 101);
	if(! $row = mysql_fetch_row($qh)) {
		# todo
	}
	$shibauthid = $row[0];
}

# get cookie data
$cookie = getAuthCookieData($userid, 600, $shibauthid);
# set cookie
if(version_compare(PHP_VERSION, "5.2", ">=") == true)
	#setcookie("VCLAUTH", "{$cookie['data']}", $cookie['ts'], "/", COOKIEDOMAIN, 1, 1);
	setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN, 0, 1);
else
	#setcookie("VCLAUTH", "{$cookie['data']}", $cookie['ts'], "/", COOKIEDOMAIN, 1);
	setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN);
# set skin cookie based on affiliation
switch($affil) {
	case 'Example1':
	case 'EXAMPLE2':
		$skin = strtoupper($affil);
		setcookie("VCLSKIN", $skin, (time() + 2678400), "/", COOKIEDOMAIN);
		break;
	default:
		setcookie("VCLSKIN", "default", (time() + 2678400), "/", COOKIEDOMAIN);
}
header("Location: " . BASEURL . "/");
dbDisconnect();
?>
