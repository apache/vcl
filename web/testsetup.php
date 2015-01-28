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

$header = "<html><head><title>VCL Setup Test Script</title>\n";
$header .= "<style type=\"text/css\">\n";
$header .= "ul {margin-top: 0;}\n";
$header .= "li {list-style-type: none;}\n";
$header .= ".pass {color: green;}\n";
$header .= ".fail {color: red;}\n";
$header .= ".title {font-weight: bold; font-style: italic;}\n";
$header .= "</style>\n";
$header .= "</head>\n";
if(isset($_GET['cookietest'])) {
	print $header;
	print "<body style=\"margin: 0; padding: 0;\">\n";
	if(isset($_COOKIE['cookietest']))
		print "<span class=pass>Successfully set a test cookie</span>\n";
	else
		print "<span class=fail>Failed to set a test cookie</span>\n";
	print "</body></html>\n";
	exit;
}
if(isset($_GET['includeconftest'])) {
	if(! is_readable('.ht-inc/conf.php')) {
		print "unreadable";
		exit;
	}
	if(include('.ht-inc/conf.php'))
		print 'worked';
	exit;
}
if(isset($_GET['includesecretstest'])) {
	if(! is_readable('.ht-inc/secrets.php')) {
		print "unreadable";
		exit;
	}
	if(include('.ht-inc/secrets.php'))
		print 'worked';
	exit;
}
$header .= "<body>\n";

function exHandler($errno, $errmsg) {
	print "Error: $errmsg<br>";
}
set_error_handler('exHandler');
function pass($msg) {
	print "<li><span class=pass>$msg</span></li>\n";
}

function fail($msg) {
	print "<li><span class=fail>$msg</span></li>\n";
}

function title($msg) {
	print "<span class=title>$msg ...</span><br>\n";
}

$myurl = "http://";
if(isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == "on")
	$myurl = "https://";
$myurl .= $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];

$includesecrets = 1;
$includeconf = 1;

if(! ip2long(getHostbyname($_SERVER['HTTP_HOST']))) {
	print $header;
	# php version
	print "PHP version: " . phpversion() . "<br><br>\n";
	title("Trying to resolve my hostname ({$_SERVER['HTTP_HOST']})");
	print "<ul>\n";
	fail("unable to resolve my hostname; ensure {$_SERVER['HTTP_HOST']} is in DNS or create an entry for it in /etc/hosts");
	print "</ul>\n";
	$includesecrets = 0;
	$includeconf = 0;
}

# test including secrets.php
$allowurlopen = ini_get('allow_url_fopen');
if($includesecrets) {
	$data = '';
	if($fp = fopen("$myurl?includesecretstest=1", 'r')) {
		$data = fread($fp, 100);
		fclose($fp);
	}
	if($allowurlopen && (empty($data) || $data == 'unreadable')) {
		print $header;
		# php version
		print "PHP version: " . phpversion() . "<br><br>\n";
		title("Including .ht-inc/secrets.php");
		print "<ul>\n";
		if($data == 'unreadable')
			fail("unable to read .ht-inc/secrets.php - check the permissions of the file");
		else
			fail("unable to include .ht-inc/secrets.php - this is probably due to a syntax error in .ht-inc/secrets.php");
		fail("skipping tests for contents of .ht-inc/secrets.php");
		print "</ul>\n";
		$includesecrets = 0;
		$includeconf = 0;
	}
}
else {
	title("Including .ht-inc/secrets.php");
	print "<ul>\n";
	fail("cannot include .ht-inc/secrets.php when hostname resolution fails");
	print "</ul>\n";
}

# conf.php test
if($includeconf) {
	$data = '';
	if($fp = fopen("$myurl?includeconftest=1", 'r')) {
		$data = fread($fp, 100);
		fclose($fp);
	}
	$allowurlopen = ini_get('allow_url_fopen');
	if($allowurlopen && (empty($data) || $data == 'unreadable')) {
		print $header;
		# php version
		print "PHP version: " . phpversion() . "<br><br>\n";
		title("Including .ht-inc/conf.php");
		print "<ul>\n";
		if($data == 'unreadable')
			fail("unable to read .ht-inc/conf.php - check the permissions of the file");
		else
			fail("unable to include .ht-inc/conf.php - this is probably due to a syntax error in .ht-inc/conf.php");
		fail("skipping tests for contents of .ht-inc/conf.php");
		print "</ul>\n";
		$includeconf = 0;
	}
}
else {
	title("Including .ht-inc/conf.php");
	print "<ul>\n";
	fail("cannot include .ht-inc/conf.php when including of .ht-inc/secrets.php fails");
	print "</ul>\n";
}

# conf.php tests
if($includeconf && include('.ht-inc/conf.php')) {
	$host = $_SERVER['HTTP_HOST'];
	if(! defined('COOKIEDOMAIN')) {
		print $header;
		# php version
		print "PHP version: " . phpversion() . "<br><br>\n";
		title("Including .ht-inc/conf.php");
		print "<ul>\n";
		pass("successfully included .ht-inc/conf.php");
		print "</ul>\n";
		title("Checking COOKIEDOMAIN setting in .ht-inc/conf.php");
		print "<ul>\n";
		fail("COOKIEDOMAIN is not defined in .ht-inc/conf.php");
		print "</ul>\n";
	}
	else {
		$len = strlen(COOKIEDOMAIN);
		if($len && substr_compare($host, COOKIEDOMAIN, 0 - $len, $len, true) != 0) {
			print $header;
			# php version
			print "PHP version: " . phpversion() . "<br><br>\n";
			title("Including .ht-inc/conf.php");
			print "<ul>\n";
			pass("successfully included .ht-inc/conf.php");
			print "</ul>\n";
			title("Checking COOKIEDOMAIN setting in .ht-inc/conf.php");
			print "<ul>\n";
			fail("COOKIEDOMAIN (" . COOKIEDOMAIN . ") does not match all of or ending of the hostname of this server ($host). This will prevent cookies from being set.");
			print "</ul>\n";
		}
		else {
			$expire = time() + 10;
			setcookie("cookietest", 1, $expire, '/', COOKIEDOMAIN);
			print $header;
			# php version
			print "PHP version: " . phpversion() . "<br><br>\n";
			title("Including .ht-inc/conf.php");
			print "<ul>\n";
			pass("successfully included .ht-inc/conf.php");
			print "</ul>\n";
			title("Checking COOKIEDOMAIN setting in .ht-inc/conf.php");
			print "<ul>\n";
			$test = COOKIEDOMAIN;
			if(empty($test))
				pass("COOKIEDOMAIN is set to empty string (this is valid and will result in the domain of cookies being set to $host)");
			else
				pass("COOKIEDOMAIN (" . COOKIEDOMAIN . ") appears to be set correctly");
			print "<iframe src=\"$myurl?cookietest=1\" width=200px height=20px scrolling=0 style=\"border: 0; padding: 0px\"></iframe><br>\n";
			print "</ul>\n";
		}
	}
	# check for BASEURL starting with https
	title("Checking that BASEURL in conf.php is set to use https");
	print "<ul>\n";
	if(! defined('BASEURL'))
		fail("BASEURL is not defined in .ht-inc/conf.php");
	else {
		if(substr_compare(BASEURL, 'https:', 0, 6, true) == 0)
			pass("BASEURL correctly set to use https");
		else
			fail("BASEURL is not set to use https. https is required.");
	}
	print "</ul>\n";

	# check for SCRIPT being set
	title("Checking that SCRIPT is set appropriately");
	print "<ul>\n";
	if(! defined('SCRIPT'))
		fail("SCRIPT is not defined in .ht-inc/conf.php");
	else {
		if(substr_compare(SCRIPT, '/', 0, 1, true) == 0 &&
		   substr_compare(SCRIPT, '.php', -4, 4, true) == 0)
			pass("SCRIPT appears to be set correctly");
		else
			fail("SCRIPT does not appear to be set correctly");
	}
	print "</ul>\n";

	# check for existance of maintenance directory
	title("Checking that .ht-inc/maintenance directory exists");
	print "<ul>\n";
	$file = preg_replace('|/testsetup.php|', '', $_SERVER['SCRIPT_FILENAME']);
	$file .= "/.ht-inc/maintenance";
	if(! is_dir($file))
		fail("/.ht-inc/maintenance directory does not exist. Please create it.");
	else {
		pass("/.ht-inc/maintenance directory exists");
		print "</ul>\n";
		# check that we can write files to maintenance directory
		title("Checking that .ht-inc/maintenance directory is writable");
		print "<ul>\n";
		if(! is_writable("$file"))
			fail("Maintenance directory is not writable");
		else {
			if(! $fh = @fopen("$file/testfile", 'w'))
				fail("Failed to open file in maintenance directory");
			else {
				if(! fwrite($fh, 'test') || ! fclose($fh))
					fail("Failed to write to file in maintenance directory");
				else {
					# check that we can remove files from maintenance directory
					if(! unlink("$file/testfile"))
						fail("Failed to remove file from maintenance directory");
					else
						pass("Maintenance directory is writable");
				}
			}
		}
	}
	print "</ul>\n";
}

# required extentions
title("Testing for required php extensions");
if(version_compare(phpversion(), "5.2", "<"))
	$requiredexts = array('gd', 'mysql', 'openssl', 'xml', 'xmlrpc', 'session', 'pcre', 'sockets', 'ldap', 'gettext');
else
	$requiredexts = array('gd', 'mysql', 'openssl', 'xml', 'xmlrpc', 'session', 'pcre', 'sockets', 'ldap', 'gettext', 'json');
$exts = get_loaded_extensions();
$diff = array_diff($requiredexts, $exts);
print "<ul>\n";
if(count($diff)) {
	$missing = implode(', ', $diff);
	fail("Missing these extensions: $missing. Depending on the extension, some or all of VCL will not work.");
}
else
	pass("All required modules are installed");
if(! in_array('ldap', $exts)) {
	print "<li>NOTE: The <strong>ldap</strong> extension is only required if using LDAP authentication</li>\n";
}
print "</ul>\n";

# secrets.php file and mysql connection
if($includesecrets && include('.ht-inc/secrets.php')) {
	title("Checking values in .ht-inc/secrets.php");
	print "<ul>\n";
	$trymysqlconnect = 1;
	$allok = 1;
	if(empty($vclhost)) {
		fail("\$vclhost in .ht-inc/secrets.php is not set");
		$trymysqlconnect = 0;
		$allok = 0;
	}
	if(empty($vcldb)) {
		fail("\$vcldb in .ht-inc/secrets.php is not set");
		$trymysqlconnect = 0;
		$allok = 0;
	}
	if(empty($vclusername)) {
		fail("\$vclusername in .ht-inc/secrets.php is not set");
		$trymysqlconnect = 0;
		$allok = 0;
	}
	if(empty($vclpassword)) {
		fail("\$vclpassword in .ht-inc/secrets.php is not set");
		$trymysqlconnect = 0;
		$allok = 0;
	}
	if(empty($cryptkey)) {
		fail("\$cryptkey in .ht-inc/secrets.php is not set");
		$allok = 0;
	}
	if(empty($pemkey)) {
		fail("\$pemkey in .ht-inc/secrets.php is not set");
		$allok = 0;
	}
	if($allok)
		pass("all required values in .ht-inc/secrets.php appear to be set");
	print "</ul>\n";
	if($trymysqlconnect && in_array('mysql', $exts) && in_array('sockets', $exts)) {
		title("Testing mysql connection");
		print "<ul>\n";
		if($fp = fsockopen($vclhost, 3306, $errno, $errstr, 5)) {
			$link = mysql_connect($vclhost, $vclusername, $vclpassword);
			if(! $link)
				fail("Could not connect to mysql on $vclhost");
			else {
				pass("Successfully connected to mysql on $vclhost");
				if(mysql_select_db($vcldb, $link))
					pass("Successfully selected database ($vcldb) on $vclhost");
				else
					fail("Could not select database ($vcldb) on $vclhost");
			}
		}
		else
			fail("Could not connect to port 3306 on $vclhost");
		print "</ul>\n";
	}
}

# test mcrypt
title("Testing phpseclib");
require_once(".ht-inc/phpseclib/Crypt/AES.php");
print "<ul>\n";
if($includesecrets && ! empty($cryptkey)) {
	$teststring = 'testing';
	$aes = new Crypt_AES();
	$aes->setKey($cryptkey);
	if($cryptdata = $aes->encrypt($teststring)) {
		pass("Successfully encrypted test string");
		$decrypted = $aes->decrypt($cryptdata);
		if(trim($decrypted) == $teststring)
			pass("Successfully decrypted test string");
		else
			fail("Failed to decrypt test string");
	}
	else {
		fail("Failed to encrypt data with phpseclib");
	}
}
else
	fail("Cannot test encryption without \$cryptkey from .ht-inc/secrets.php");
print "</ul>\n";

# encryption keys
$privkeyok = 0;
$pubkeyok = 0;
if(in_array('openssl', $exts)) {
	title("checking openssl encryption keys");
	print "<ul>\n";
	if($includesecrets && ! empty($pemkey)) {
		if(is_readable(".ht-inc/keys.pem")) {
			$fp = fopen(".ht-inc/keys.pem", "r");
			$key = fread($fp, 8192);
			fclose($fp);
			$keys["private"] = openssl_pkey_get_private($key, $pemkey);
			if(! $keys['private'])
				fail("Could not create private key from private key file (.ht-inc/keys.pem). Try running .ht-inc/genkeys.sh again.");
			else {
				pass("successfully created private key from private key file");
				$privkeyok = 1;
			}
		}
		else
			fail("Could not read private key file (.ht-inc/keys.pem). Check permissions on the file.");
	}
	else
		fail("Cannot test private key file without \$pemkey from .ht-inc/secrets.php");

	if(is_readable(".ht-inc/pubkey.pem")) {
		$fp = fopen(".ht-inc/pubkey.pem", "r");
		$key = fread($fp, 8192);
		fclose($fp);
		$keys["public"] = openssl_pkey_get_public($key);
		if(! $keys['public'])
			fail("Could not create public key from public key file (.ht-inc/pubkey.pem). Try running .ht-inc/genkeys.sh again.");
		else {
			pass("successfully created public key from public key file");
			$pubkeyok = 1;
		}
	}
	else
		fail("Could not read public key file (.ht-inc/pubkey.pem). Check permissions on the file.");
	print "</ul>\n";

	title("Testing openssl encryption");
	print "<ul>\n";
	if(! $privkeyok)
		fail("cannot test encryption without a valid private key");
	else {
		if(openssl_private_encrypt('test string', $cryptdata, $keys["private"])) {
			pass("successfully encrypted test string");
			if(! $pubkeyok)
				fail("cannot test decryption without a valid public key");
			else {
				if(openssl_public_decrypt($cryptdata, $tmp, $keys['public'])) {
					if($tmp == 'test string')
						pass("successfully decrypted test string");
					else
						fail("failed to decrypt test string");
				}
				else
					fail("failed to decrypt test string");
			}
		}
		else
			fail("failed to encrypt test data");
	}
	print "</ul>\n";
}


# check dojo directories
title("Testing for existance of dojo directory");
print "<ul>\n";
if(is_dir('./dojo')) {
	pass("dojo directory exists");
	if(is_readable('./dojo'))
		pass("dojo directory is readable");
	else
		fail("dojo directory is not readable. Check permissions on this directory");
}
else
	fail("dojo directory does not exist. Download and install Dojo Toolkit 1.6.2");
print "</ul>\n";


# check for spyc
title("Testing for existance of spyc 0.5.1 and Spyc.php");
print "<ul>\n";
if(is_dir('./.ht-inc/spyc-0.5.1')) {
	pass("spyc directory exists");
	if(is_readable('./.ht-inc/spyc-0.5.1')) {
		pass("spyc directory is readable");
		if(is_file('./.ht-inc/spyc-0.5.1/Spyc.php')) {
			pass(".ht-inc/spyc-0.5.1/Spyc.php file exists");
			if(is_readable('.ht-inc/spyc-0.5.1/Spyc.php'))
				pass(".ht-inc/spyc-0.5.1/Spyc.php is readable");
			else
				fail(".ht-inc/spyc-0.5.1/Spyc.php is not readable. Check permissions on the file.");
		}
		else
			fail(".ht-inc/spyc-0.5.1/Spyc.php file does not exist.  Reinstall Spyc 0.5.1");
	}
	else
		fail("spyc-0.5.1 directory is not readable. Check permissions on this directory");
}
else
	fail(".ht-inc/spyc-0.5.1 directory does not exist. Download and install Spyc 0.5.1");
print "</ul>\n";

# check themes directories for dojo content having been copied in
title("Checking themes for dojo css");
$themes = scandir('themes');
foreach($themes as $theme) {
	if($theme == '.' || $theme == '..' || $theme == 'copydojocss.sh')
		continue;
	if(is_dir("themes/$theme/css/dojo") && is_file("themes/$theme/css/dojo/{$theme}.css"))
		pass("themes/$theme has had dojo css copied to it");
	else
		fail("themes/$theme is missing dojo css. Run themes/copydojocss.sh from the themes directory to correct this if you want to use this theme.");
}

# php display errors
title("Checking value of PHP display_errors");
$a = ini_get('display_errors');
print "<ul>\n";
if($a == 'Off' || $a == 'off' || $a == '')
	print "<li>display_errors: <strong>disabled</strong></li>\n";
elseif($a == 'On' || $a == 'on' || $a == 1)
	print "<li>display_errors: <strong>enabled</strong></li>\n";
else
	fail("failed to determine value of display_errors");
?>
<li>NOTE: Displaying errors in a production system is a security risk; however,<br>
while getting VCL up and running, having them displayed makes debugging<br>
a little easier. Edit your php.ini file to modify this setting.</li>
</ul>
<?php

print "Done";

print "</body></html>\n";
?>
