<?php

chdir("..");
require_once('.ht-inc/conf.php');
require_once('.ht-inc/utils.php');
require_once('.ht-inc/errors.php');

global $authMechs;
global $keys;

function getFooter() {}
$noHTMLwrappers = array();

dbConnect();

// Validate the Ticket
if(array_key_exists('ticket', $_GET)) {
	$serviceticket = $_GET['ticket'];
	if(array_key_exists('authtype', $_GET)) {
		$authtype = $_GET['authtype'];
		$auth = $authMechs[$authtype];
		$casversion = ($auth['version'] == 2 ? CAS_VERSION_2_0 : CAS_VERSION_3_0);
		$cashost = $auth['host'];
		$casport = $auth['port'];
		$cascontext = $auth['context'];
		$validatecassslcerts = $auth['validatecassslcerts'];
		$attributemap = $auth['attributemap'];

		if($auth['cacertpath'] != null)
			if(file_exists($auth['cacertpath']))
				phpCAS::setCasServerCACert($auth['cacertpath']);

		$serviceurl = BASEURL . '/casauth/index.php?authtype=' . $_GET['authtype'];
		if($casversion == CAS_VERSION_2_0)
			$servicevalidateurl = 'https://' . $cashost . ':' . $casport
			                    . $cascontext . '/serviceValidate' . '?' . 'service='
			                    . urlencode($serviceurl) . '&' . 'ticket=' . $serviceticket;
		else 
			$servicevalidateurl = 'https://' . $cashost . ':' . $casport . $cascontext
			                    . '/p3/serviceValidate' . '?' . 'service='
			                    . urlencode($serviceurl) . '&' . 'ticket=' . $serviceticket;

		$response = curlDoSSLWebRequest($servicevalidateurl, $validatecassslcerts);

		// check for authentication success
		$xmldata = new DOMDocument();
		$xmldata->loadXML($response);
		$xpath = new DOMXPath($xmldata);
		$authresults = $xpath->query('//cas:serviceResponse/cas:authenticationSuccess/cas:user');
		$userid = '';
		$userinfo = array();
		$vcluser = array();
		foreach($authresults as $authresult) {
			$userid = $authresult->nodeValue;
			$vcluser['unityid'] = $userid;
			$vcluser['affiliationid'] = $auth['affiliationid'];
			if($auth['defaultgroup'] != null)
				$vcluser['defaultgroup'] = $auth['defaultgroup'];
		}

		// extract user attributes provided by CAS
		$attributeresults = $xpath->query('//cas:serviceResponse/cas:authenticationSuccess/cas:attributes');
		if($attributeresults->length > 0) {
			$userattributeitems = $attributeresults->item(0);
			foreach($userattributeitems->childNodes as $userattributeitem) {
				$attributename = preg_replace('#^cas:#', '', $userattributeitem->nodeName);
				$userinfo[$attributename] = $userattributeitem->nodeValue;
			}
		}
		// convert CAS attributes to VCL user attributes
		foreach(array_keys($userinfo) as $attribute) {
			if(array_key_exists($attribute, $attributemap)) {
				$vcluser[$attributemap[$attribute]] = $userinfo[$attribute];
			}
		}

		unset($xmldata);
		unset($xpath);

		if($userid != '') {
			// read keys
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

			// valid user returned, login if user exists
			if(checkCASUserInDatabase($authtype, $userid) == TRUE) {
				updateCASUser($vcluser);
				# get cookie data
				$cookie = getAuthCookieData("$userid@" . getAffiliationName($auth['affiliationid']));
				if($cookie != "Failed to encrypt cookie data") {
					# set cookie
					if(version_compare(PHP_VERSION, "5.2", ">=") == true)
						setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN, 0, 1);
					else
						setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN);

					addLoginLog($userid, $authtype, $auth['affiliationid'], 1);
				}
			}
			else {
				// user does not exists in VCL database, so add user
				if(addCASUser($vcluser) != NULL) {
					# get cookie data
					$cookie = getAuthCookieData("$userid@" . getAffiliationName($auth['affiliationid']));
					if($cookie != "Failed to encrypt cookie data") {
						# set cookie
						if(version_compare(PHP_VERSION, "5.2", ">=") == true)
							setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN, 0, 1);
						else
							setcookie("VCLAUTH", "{$cookie['data']}", 0, "/", COOKIEDOMAIN);

						addLoginLog($userid, $authtype, $auth['affiliationid'], 1);
					}
				}
			}
			// Set theme
			$theme = getAffiliationTheme($auth['affiliationid']);
			setcookie("VCLSKIN", $theme, (time() + 2678400), "/", COOKIEDOMAIN);
		}
	}
}

// Redirect to homepage
header("Location: " . BASEURL . "/");
dbDisconnect();

?>
