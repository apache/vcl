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

////////////////////////////////////////////////////////////////////////////////
///
/// \class ADdomain
///
/// \brief extends Resource class to add things specific to resources of the
/// addomain type
///
////////////////////////////////////////////////////////////////////////////////
class ADdomain extends Resource {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief calls parent constructor; initializes things for Schedule class
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->restype = 'addomain';
		$this->restypename = 'AD Domain';
		$this->namefield = 'name';
		$this->basecdata['obj'] = $this;
		$this->deletable = 1;
		$this->deletetoggled = 0;
		$this->defaultGetDataArgs = array('rscid' => 0);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getData($args)
	///
	/// \param $args - array of arguments that determine what data gets returned;
	/// must include:\n
	/// \b rscid - only return data for resource with this id; pass 0 for all
	/// (from addomain table)
	///
	/// \return array of data as returned from getADdomains
	///
	/// \brief wrapper for calling getADdomains
	///
	/////////////////////////////////////////////////////////////////////////////
	function getData($args) {
		return getADdomains($args['rscid']);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn fieldWidth($field)
	///
	/// \param $field - name of a resource field
	///
	/// \return string for setting width of field (includes width= part)
	///
	/// \brief generates the required width for the field; can return an empty
	/// string if field should default to auto width
	///
	/////////////////////////////////////////////////////////////////////////////
	function fieldWidth($field) {
		switch($field) {
			case 'name':
				$w = 17;
				break;
			case 'owner':
				$w = 11;
				break;
			case 'domaindnsname':
				$w = 12;
				break;
			case 'username':
				$w = 9;
				break;
			case 'dnsservers':
				$w = 12;
				break;
			default:
				return '';
		}
		if(preg_match('/MSIE/i', $_SERVER['HTTP_USER_AGENT']) ||
		   preg_match('/Trident/i', $_SERVER['HTTP_USER_AGENT']) ||
		   preg_match('/Edge/i', $_SERVER['HTTP_USER_AGENT']))
			$w = round($w * 11.5) . 'px';
		else
			$w = "{$w}em";
		return "width=\"$w\"";
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn fieldDisplayName($field)
	///
	/// \param $field - name of a resource field
	///
	/// \return display value for $field
	///
	/// \brief generates the display value for $field
	///
	/////////////////////////////////////////////////////////////////////////////
	function fieldDisplayName($field) {
		switch($field) {
			case 'domaindnsname':
				return 'Domain DNS Name';
			case 'dnsservers':
				return 'DNS Server(s)';
		}
		return ucfirst($field);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn submitToggleDeleteResourceExtra($rscid, $deleted)
	///
	/// \param $rscid - id of a resource (from table specific to that resource,
	/// not from the resource table)
	/// \param $deleted - (optional, default=0) 1 if resource was previously
	/// deleted; 0 if not
	///
	/// \brief function to do any extra stuff specific to a resource type when
	/// toggling delete for a resource; to be implemented by inheriting class if
	/// needed
	///
	/////////////////////////////////////////////////////////////////////////////
	function submitToggleDeleteResourceExtra($rscid, $deleted=0) {
		$data = $this->getData(array('rscid' => $rscid));
		deleteSecretKeys($data[$rscid]['secretid']);

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin"), array("manageGroup"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("manageGroup"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsaveResource()
	///
	/// \brief saves changes to a resource; must be implemented by inheriting
	/// class
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsaveResource() {
		global $user;
		$add = getContinuationVar('add', 0);
		$data = $this->validateResourceData();
		if($data['error']) {
			$ret = array('status' => 'error', 'msg' => $data['errormsg']);
			sendJSON($ret);
			return;
		}

		if($add) {
			if(! $data['rscid'] = $this->addResource($data)) {
				sendJSON(array('status' => 'adderror',
				               'errormsg' => wordwrap(i('Error encountered while trying to create new AD domain. Please contact an admin for assistance.'), 75, "\n")));
				return;
			}
		}
		else {
			$olddata = getContinuationVar('olddata');
			$updates = array();
			# name
			if($data['name'] != $olddata['name'])
				$updates[] = "name = '{$data['name']}'";
			# ownerid
			$ownerid = getUserlistID($data['owner']);
			if($ownerid != $olddata['ownerid'])
				$updates[] = "ownerid = $ownerid";
			# domaindnsname
			if($data['domaindnsname'] != $olddata['domaindnsname'])
				$updates[] = "domainDNSName = '{$data['domaindnsname']}'";
			# username
			if($data['username'] != $olddata['username'])
				$updates[] = "username = '{$data['username']}'";
			# password
			if(strlen($data['password'])) {
				$oldsecretid = $olddata['secretid'];
				# check that we have a cryptsecret entry for this secret
				$cryptkeyid = getCryptKeyID();
				if($cryptkeyid == NULL) {
					$ret = array('status' => 'error', 'msg' => "Error encountered while updating password");
					sendJSON($ret);
					return;
				}
				$query = "SELECT cryptsecret "
				       . "FROM cryptsecret "
				       . "WHERE cryptkeyid = $cryptkeyid AND "
				       .       "secretid = $oldsecretid";
				$qh = doQuery($query);
				if(! ($row = mysql_fetch_assoc($qh))) {
					# generate a new secret
					$newsecretid = getSecretKeyID('addomain', 'secretid', 0);
					$delids = array($oldsecretid);
					if($newsecretid == $oldsecretid) {
						$delids[] = $newsecretid;
						$newsecretid = getSecretKeyID('addomain', 'secretid', 0);
					}
					$delids = implode(',', $delids);
					# encrypt new secret with any management node keys
					$secretidset = array();
					$query = "SELECT ck.hostid AS mnid "
					       . "FROM cryptkey ck "
					       . "JOIN cryptsecret cs ON (ck.id = cs.cryptkeyid) "
					       . "WHERE cs.secretid = $oldsecretid AND "
					       .       "ck.hosttype = 'managementnode'";
					$qh = doQuery($query);
					while($row = mysql_fetch_assoc($qh))
						$secretidset[$row['mnid']][$newsecretid] = 1;
					$values = getMNcryptkeyUpdates($secretidset, $cryptkeyid);
					addCryptSecretKeyUpdates($values);
					$olddata['secretid'] = $newsecretid;
					$updates[] = "secretid = $newsecretid";
					# clean up old cryptsecret entries for management nodes
					$query = "DELETE FROM cryptsecret WHERE secretid IN ($delids)";
					doQuery($query);
				}
				$encpass = encryptDBdata($data['password'], $olddata['secretid']);
				if($encpass == NULL) {
					$ret = array('status' => 'error', 'msg' => "Error encountered while updating password");
					sendJSON($ret);
					return;
				}
				$updates[] = "password = '$encpass'";
			}
			# dnsservers
			if($data['dnsservers'] != $olddata['dnsservers'])
				$updates[] = "dnsServers = '{$data['dnsservers']}'";
			if(count($updates)) {
				$query = "UPDATE addomain SET "
				       . implode(', ', $updates)
				       . " WHERE id = {$data['rscid']}";
				doQuery($query);
			}
		}

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("manageGroup"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("manageGroup"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);

		$tmp = $this->getData(array('rscid' => $data['rscid']));
		$data = $tmp[$data['rscid']];
		$arr = array('status' => 'success');
		$arr['data'] = $data;
		if($add) {
			$arr['action'] = 'add';
			$arr['nogroups'] = 0;
			$groups = getUserResources(array($this->restype . 'Admin'), array('manageGroup'), 1);
			if(count($groups[$this->restype]))
				$arr['groupingHTML'] = $this->groupByResourceHTML();
			else
				$arr['nogroups'] = 1;
		}
		else
			$arr['action'] = 'edit';
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJeditResource()
	///
	/// \brief sends data for editing a resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJeditResource() {
		$rscid = processInputVar('rscid', ARG_NUMERIC);
		$resources = getUserResources(array($this->restype . 'Admin'), array('administer'), 0, 1);
		if(! array_key_exists($rscid, $resources[$this->restype])) {
			$ret = array('status' => 'noaccess');
			sendJSON($ret);
			return;
		}
		$args = $this->defaultGetDataArgs;
		$args['rscid'] = $rscid;
		$tmp = $this->getData($args);
		$data = $tmp[$rscid];
		$cdata = $this->basecdata;
		$cdata['rscid'] = $rscid;
		$cdata['olddata'] = $data;

		# save continuation
		$cont = addContinuationsEntry('AJsaveResource', $cdata);

		$ret = $this->jsondata;
		$ret['title'] = "Edit {$this->restypename}";
		$ret['cont'] = $cont;
		$ret['resid'] = $rscid;
		$ret['data'] = $data;
		$ret['status'] = 'success';
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addResource($data)
	///
	/// \param $data - array of needed data for adding a new resource
	///
	/// \return id of new resource; NULL on failure
	///
	/// \brief handles all parts of adding a new resource to the database; should
	/// be implemented by inheriting class, but not required since it is only
	/// called by functions in the inheriting class (nothing in this base class
	/// calls it directly)
	///
	/////////////////////////////////////////////////////////////////////////////
	function addResource($data) {
		global $user;

		$ownerid = getUserlistID($data['owner']);

		$secretid = getSecretKeyID('addomain', 'secretid', 0);
		if($secretid === NULL)
			return NULL;
		$encpass = encryptDBdata($data['password'], $secretid);
		if($encpass === NULL)
			return NULL;
	
		$query = "INSERT INTO addomain"
				.	"(name, "
				.	"ownerid, "
				.	"domainDNSName, "
				.	"username, "
				.	"password, "
				.	"secretid, "
				.	"dnsServers) "
				.	"VALUES ('{$data['name']}', "
				.	"$ownerid, "
				.	"'{$data['domaindnsname']}', "
				.	"'{$data['username']}', "
				.	"'$encpass', "
				.	"$secretid, "
				.	"'{$data['dnsservers']}')";
		doQuery($query);

		$rscid = dbLastInsertID();
		if($rscid == 0) {
			$query = "DELETE FROM cryptsecret WHERE secretid = $secretid";
			doQuery($query);
			return NULL;
		}

		// add entry in resource table
		$query = "INSERT INTO resource "
				 .        "(resourcetypeid, "
				 .        "subid) "
				 . "VALUES ((SELECT id FROM resourcetype WHERE name = 'addomain'), "
				 .        "$rscid)";
		doQuery($query);

		return $rscid;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addEditDialogHTML($add)
	///
	/// \param $add - unused for this class
	///
	/// \brief handles generating HTML for dialog used to edit resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function addEditDialogHTML($add=0) {
		global $user, $days;
		# dialog for on page editing
		$h = '';
		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"addeditdlg\"\n";
		$h .= "      title=\"Edit {$this->restypename}\"\n";
		$h .= "      duration=250\n";
		#$h .= "      style=\"width: 70%;\"\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"addeditdlgcontent\">\n";
		$h .= "<div id=\"addomaindlgcontent\">\n";
		# id
		$h .= "<input type=\"hidden\" id=\"editresid\">\n";

		$h .= "<div style=\"text-align: center;\">\n";
		# name
		$errmsg = i("Name cannot contain single (') or double (&quot;) quotes, less than (&lt;), or greater than (&gt;) and can be from 2 to 30 characters long");
		$h .= labeledFormItem('name', i('Name'), 'text', '^([A-Za-z0-9-!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\./\?~` ]){2,30}$',
		                      1, '', $errmsg, '', '', '200px'); 
		# owner
		$extra = array('onKeyPress' => 'setOwnerChecking');
		$h .= labeledFormItem('owner', i('Owner'), 'text', '', 1,
		                      "{$user['unityid']}@{$user['affiliation']}", i('Unknown user'),
		                      'checkOwner', $extra, '200px');
		$cont = addContinuationsEntry('AJvalidateUserid');
		$h .= "<input type=\"hidden\" id=\"valuseridcont\" value=\"$cont\">\n";
		# domain dns name
		$hostbase = '([-A-Za-z0-9]{1,63})(\.[A-Za-z0-9-_]+)*(\.?[A-Za-z0-9])';
		$errmsg = i("Domain DNS Name should be in the format domain.tld and can only contain letters, numbers, dashes(-), periods(.), and underscores(_) (e.g. myuniversity.edu)");
		$h .= labeledFormItem('domaindnsname', i('Domain DNS Name'), 'text', "^$hostbase$",
		                      1, '', $errmsg, '', '', '200px', helpIcon('domaindnsnamehelp')); 
		# username
		$errmsg = i("Username cannot contain single (') or double (&quot;) quotes, less than (&lt;), or greater than (&gt;) and can be from 2 to 64 characters long");
		$h .= labeledFormItem('username', i('Username'), 'text', '^([A-Za-z0-9-!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\./\?~` ]){2,64}$',
		                      1, '', $errmsg, '', '', '200px', helpIcon('usernamehelp')); 
		# password
		$errmsg = i("Password must be at least 4 characters long");
		$h .= labeledFormItem('password', i('Password'), 'password', '^.{4,256}$', 1, '', $errmsg, '', '', '200px'); 
		# confirm password
		$h .= labeledFormItem('password2', i('Confirm Password'), 'password', '', 1, '', '', '', '', '200px'); 
		$h .= "<br>\n";
		# dns server list
		$ipreg = '(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)';
		$reg = "^($ipreg,)*($ipreg)$";
		$errmsg = i("Invalid IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('dnsservers', i('DNS Server(s)'), 'text', $reg, 0, '', $errmsg,
		                      '', '', '300px', helpIcon('dnsservershelp')); 

		$h .= "</div>\n"; # center
		$h .= "</div>\n"; # addomaindlgcontent
		$h .= "</div>\n"; # addeditdlgcontent

		$h .= "<div id=\"addeditdlgerrmsg\" class=\"nperrormsg\"></div>\n";
		$h .= "<div id=\"editdlgbtns\" align=\"center\">\n";
		$h .= dijitButton('addeditbtn', "Confirm", "saveResource();");
		$h .= dijitButton('', "Cancel", "dijit.byId('addeditdlg').hide();");
		$h .= "</div>\n"; # editdlgbtns
		$h .= "</div>\n"; # addeditdlg

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"groupingnote\"\n";
		$h .= "      title=\"AD Domain Grouping\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$msg = i("Each AD Domain should be a member of an AD Domain resource group. The following dialog will allow you to add the new AD Domain to a group.");
		$h .= wordwrap($msg, 75, '<br>');
		$h .= "<br><br>\n";
		$h .= "<div align=\"center\">\n";
		$h .= dijitButton('', "Close", "dijit.byId('groupingnote').hide();");
		$h .= "</div>\n"; # btn div
		$h .= "</div>\n"; # groupingnote

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"groupdlg\"\n";
		$h .= "      title=\"AD Domain Grouping\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"groupdlgcontent\"></div>\n";
		$h .= "<div align=\"center\">\n";
		$script  = "    dijit.byId('groupdlg').hide();\n";
		$script .= "    checkFirstAdd();\n";
		$h .= dijitButton('', "Close", $script);
		$h .= "</div>\n"; # btn div
		$h .= "</div>\n"; # groupdlg

		$h .= "<div id=\"tooltips\">\n";
		$h .= helpTooltip('domaindnsnamehelp', i("domain name registered in DNS for Active Directory Domain (ex: ad.example.com)"));
		$h .= helpTooltip('usernamehelp', i("These credentials will be used to register reserved computers with AD."));
		$h .= helpTooltip('dnsservershelp', i("comma delimited list of IP addresses for DNS servers that handle Domain DNS"));
		$h .= "</div>\n"; # tooltips

		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateResourceData()
	///
	/// \return array with these fields:\n
	/// \b rscid - id of resource (from addomain table)\n
	/// \b name\n
	/// \b owner\n
	/// \b times - array of arrays, each having 2 keys: start and end, each in
	///    unix timestamp format\n
	/// \b error - 0 if submitted data validates; 1 if anything is invalid\n
	/// \b errormsg - if error = 1; string of error messages separated by html
	///    break tags
	///
	/// \brief validates form input from editing or adding an AD domain
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateResourceData() {
		global $user;
		$add = getContinuationVar('add', 0);

		$return = array('error' => 0);
		$errormsg = array();

		$return['rscid'] = getContinuationVar('rscid', 0);
		$return["name"] = processInputVar("name", ARG_STRING);
		$return["owner"] = processInputVar("owner", ARG_STRING, "{$user["unityid"]}@{$user['affiliation']}");
		$return["domaindnsname"] = processInputVar("domaindnsname", ARG_STRING);
		$return["username"] = processInputVar("username", ARG_STRING);
		$return["password"] = $_POST['password'];
		$return["password2"] = $_POST['password2'];
		$return["dnsservers"] = processInputVar("dnsservers", ARG_STRING);

		if(! preg_match("/^([A-Za-z0-9-!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\.\/\?~` ]){2,30}$/", $return['name'])) {
			$return['error'] = 1;
			$errormsg[] = i("Name cannot contain single (') or double (&quot;) quotes, less than (&lt;), or greater than (&gt;) and can be from 2 to 30 characters long");
		}
		elseif($this->checkExistingField('name', $return['name'], $return['rscid'])) {
			$return['error'] = 1;
			$errormsg[] = i("An AD domain already exists with this name.");
		}
		elseif($this->checkExistingField('domainDNSName', $return['domaindnsname'], $return['rscid'])) {
			$return['error'] = 1;
			$errormsg[] = i("An AD domain already exists with this Domain DNS Name.");
		}
		if(! validateUserid($return['owner'])) {
			$return['error'] = 1;
			$errormsg[] = i("Submitted owner is not valid");
		}

		if(! preg_match('/^([A-Za-z0-9]{1,63})(\.[A-Za-z0-9-_]+)*(\.?[A-Za-z0-9])$/', $return['domaindnsname'])) {
			$return['error'] = 1;
			$errormsg[] = i("Domain DNS Name should be in the format domain.tld and can only contain letters, numbers, dashes(-), periods(.), and underscores(_) (e.g. myuniversity.edu)");
		}

		if(! preg_match('/^([A-Za-z0-9-!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\.\/\?~` ]){2,64}$/', $return['username'])) {
			$return['error'] = 1;
			$errormsg[] = i("Username cannot contain single (') or double (&quot;) quotes, less than (&lt;), or greater than (&gt;) and can be from 2 to 64 characters long");
		}

		$passlen = strlen($return['password']);
		if(($passlen < 4 || $passlen > 256) &&
		   ($add || ! (empty($return['password']) && empty($return['password2'])))) {
			$return['error'] = 1;
			$errormsg[] = i("Password must be at least 4 characters long");
		}
		elseif($return['password'] != $return['password2']) {
			$return['error'] = 1;
			$errormsg[] = i("Passwords do not match");
		}

		$ips = explode(',', $return['dnsservers']);
		foreach($ips as $ip) {
			if(! validateIPv4addr($ip)) {
				$return['error'] = 1;
				$errormsg[] = i("Invalid IP address specified for DNS Server - must be a valid IPV4 address");
				break;
			}
		}

		if($return['error'])
			$return['errormsg'] = implode('<br>', $errormsg);

		return $return;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkResourceInUse($rscid)
	///
	/// \param $rscid - id of AD domain
	///
	/// \return empty string if not being used; string of where resource is
	/// being used if being used
	///
	/// \brief checks to see if AD domain is being used
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkResourceInUse($rscid) {
		$msg = '';

		$query = "SELECT i.prettyname "
		       . "FROM imageaddomain ia, "
		       .      "image i "
		       . "WHERE ia.addomainid = $rscid AND "
		       .       "ia.imageid = i.id";
		$qh = doQuery($query);
		$images = array();
		while($row = mysql_fetch_assoc($qh))
			$images[] = $row['prettyname'];
		if(count($images))
			$msg = "This AD Domain cannot be deleted because the following <strong>images</strong> are using it:<br><br>\n" . implode("<br>\n", $images);

		return $msg;
	}
}

?>
