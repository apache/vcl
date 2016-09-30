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
			case 'domainnetbiosname':
				$w = 12;
				break;
			case 'username':
				$w = 9;
				break;
			case 'dnsservers':
				$w = 12;
				break;
			case 'domaincontrollers':
				$w = 17;
				break;
			case 'logindescription':
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
			case 'domainnetbiosname':
				return 'Domain NetBIOS Name';
			case 'dnsservers':
				return 'DNS Server(s)';
			case 'domaincontrollers':
				return 'Domain Controller(s)';
			case 'logindescription':
				return 'Login Description';
		}
		return ucfirst($field);
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
			$esc_name = mysql_real_escape_string($data['name']);
			$query = "SELECT id FROM addomain WHERE name = '$esc_name'";
			$qh = doQuery($query);
			if($row = mysql_fetch_assoc($qh)) {
				sendJSON(array('status' => 'adderror',
				               'errormsg' => wordwrap(i('An AD Domain with this name already exists.'), 75, '<br>')));
				return;
			}
			if(! $data['rscid'] = $this->addResource($data)) {
				sendJSON(array('status' => 'adderror',
				               'errormsg' => wordwrap(i('Error encountered while trying to create new AD domain. Please contact an admin for assistance.'), 75, '<br>')));
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
			# domainnetbiosname
			if($data['domainnetbiosname'] != $olddata['domainnetbiosname'])
				$updates[] = "domainNetBIOSName = '{$data['domainnetbiosname']}'";
			# username
			if($data['username'] != $olddata['username'])
				$updates[] = "username = '{$data['username']}'";
			# password
			if(strlen($data['password'])) {
				$esc_pass = mysql_real_escape_string($data['password']);
				$updates[] = "password = '$esc_pass'";
			}
			# dnsservers
			if($data['dnsservers'] != $olddata['dnsservers'])
				$updates[] = "dnsServers = '{$data['dnsservers']}'";
			# domaincontrollers
			if($data['domaincontrollers'] != $olddata['domaincontrollers'])
				$updates[] = "domainControllers = '{$data['domaincontrollers']}'";
			# logindescription
			if($data['logindescription'] != $olddata['logindescription']) {
				$esc_desc = mysql_real_escape_string($data['logindescription']);
				$updates[] = "logindescription = '$esc_desc'";
			}
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
		$login = preg_replace("/<br>/", "\n", $data['logindescription']);
		$data['logindescription'] = htmlspecialchars_decode($login);
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
	/// \return id of new resource
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
		$esc_pass = mysql_real_escape_string($data['password']);
		$esc_desc = mysql_real_escape_string($data['logindescription']);
	
		$query = "INSERT INTO addomain"
				.	"(name,"
				.	"ownerid,"
				.	"domainDNSName,"
				.	"domainNetBIOSName,"
				.	"username,"
				.	"password,"
				.	"dnsServers,"
				.	"domainControllers,"
				.	"logindescription)"
				.	"VALUES ('{$data['name']}',"
				.	"$ownerid,"
				.	"'{$data['domaindnsname']}',"
				.	"'{$data['domainnetbiosname']}',"
				.	"'{$data['username']}',"
				.	"'$esc_pass',"
				.	"'{$data['dnsservers']}',"
				.	"'{$data['domaincontrollers']}',"
				.	"'$esc_desc')";
		doQuery($query);

		$rscid = dbLastInsertID();
		if($rscid == 0) {
			return 0;
		}
		// add entry in resource table
		$query = "INSERT INTO resource "
				 .        "(resourcetypeid, "
				 .        "subid) "
				 . "VALUES (19, "
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

		# todo consider adding help icons with popups

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
		$hostbase = '([A-Za-z0-9]{1,63})(\.[A-Za-z0-9-_]+)*(\.?[A-Za-z0-9])';
		$errmsg = i("Domain DNS Name should be in the format domain.tld and can only contain letters, numbers, dashes(-), periods(.), and underscores(_) (e.g. myuniversity.edu)");
		$h .= labeledFormItem('domaindnsname', i('Domain DNS Name'), 'text', "^$hostbase$",
		                      1, '', $errmsg, '', '', '200px'); 
		# domain netbios name
		$errmsg = i("Domain NetBIOS Name can only contain letters, numbers, dashes(-), periods(.), and underscores(_) and can be up to 15 characters long");
		$h .= labeledFormItem('domainnetbiosname', i('Domain NetBIOS Name'), 'text', '^[a-zA-Z0-9_][-a-zA-Z0-9_\.]{0,14}$',
		                      1, '', $errmsg, '', '', '200px'); 
		$h .= "<br>\n";
		# username
		$errmsg = i("Username cannot contain single (') or double (&quot;) quotes, less than (&lt;), or greater than (&gt;) and can be from 2 to 64 characters long");
		$h .= labeledFormItem('username', i('Username'), 'text', '^([A-Za-z0-9-!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\./\?~` ]){2,30}$',
		                      1, '', $errmsg, '', '', '200px'); 
		# password
		# todo make required for adding
		$errmsg = i("Password must be at least 4 characters long");
		$h .= labeledFormItem('password', i('Password'), 'password', '^.{4,256}$', 0, '', $errmsg, '', '', '200px'); 
		# confirm password
		$h .= labeledFormItem('password2', i('Confirm Password'), 'password', '', 0, '', '', '', '', '200px'); 
		$h .= "<br>\n";
		# dns server list
		$ipreg = '(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)';
		$reg = "^($ipreg,)*($ipreg)$";
		$errmsg = i("Invalid IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('dnsservers', i('DNS Server(s)'), 'text', $reg, 0, '', $errmsg,
		                      '', '', '300px'); 
		# domain controllers list
		$reg = "$hostbase(,$hostbase){0,4}";
		$errmsg = i("Invalid Domain Controller specified. Must be comma delimited list of hostnames or IP addresses, with up to 5 allowed");
		$h .= labeledFormItem('domaincontrollers', i('Domain Controller(s)'), 'text', $reg, 0, '', $errmsg,
		                      '', '', '300px'); 
		# login description
		$h .= labeledFormItem('logindescription', i('Login Description'), 'textarea', '',
		                      1, '', '', '', '', '300px'); 

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

		$return = array('error' => 0);
		$errormsg = array();

		$return['rscid'] = getContinuationVar('rscid', 0);
		$return["name"] = processInputVar("name", ARG_STRING);
		$return["owner"] = processInputVar("owner", ARG_STRING, "{$user["unityid"]}@{$user['affiliation']}");
		$return["domaindnsname"] = processInputVar("domaindnsname", ARG_STRING);
		$return["domainnetbiosname"] = processInputVar("domainnetbiosname", ARG_STRING);
		$return["username"] = processInputVar("username", ARG_STRING);
		$return["password"] = processInputVar("password", ARG_STRING);
		$return["password2"] = processInputVar("password2", ARG_STRING);
		$return["dnsservers"] = processInputVar("dnsservers", ARG_STRING);
		$return["domaincontrollers"] = processInputVar("domaincontrollers", ARG_STRING);
		$return["logindescription"] = processInputVar("logindescription", ARG_STRING);

		$return['logindescription'] = preg_replace("/[\n\s]*$/", '', $return['logindescription']);
		$return['logindescription'] = preg_replace("/\r/", '', $return['logindescription']);
		$return['logindescription'] = htmlspecialchars($return['logindescription']);
		$return['logindescription'] = preg_replace("/\n/", '<br>', $return['logindescription']);

		if(! preg_match("/^([A-Za-z0-9-!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\.\/\?~` ]){2,30}$/", $return['name'])) {
			$return['error'] = 1;
			$errormsg[] = i("Name cannot contain single (') or double (&quot;) quotes, less than (&lt;), or greater than (&gt;) and can be from 2 to 30 characters long");
		}
		elseif($this->checkExistingField('name', $return['name'], $return['rscid'])) {
			$return['error'] = 1;
			$errormsg[] = i("An AD domain already exists with this name.");
		}
		if(! validateUserid($return['owner'])) {
			$return['error'] = 1;
			$errormsg[] = i("Submitted owner is not valid");
		}

		if(! preg_match('/^([A-Za-z0-9]{1,63})(\.[A-Za-z0-9-_]+)*(\.?[A-Za-z0-9])$/', $return['domaindnsname'])) {
			$return['error'] = 1;
			$errormsg[] = i("Domain DNS Name should be in the format domain.tld and can only contain letters, numbers, dashes(-), periods(.), and underscores(_) (e.g. myuniversity.edu)");
		}
		if(! preg_match('/^[a-zA-Z0-9_][-a-zA-Z0-9_\.]{0,14}$/', $return['domainnetbiosname'])) {
			$return['error'] = 1;
			$errormsg[] = i("Domain NetBIOS Name can only contain letters, numbers, dashes(-), periods(.), and underscores(_) and can be up to 15 characters long");
		}

		if(! preg_match('/^([A-Za-z0-9-!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\.\/\?~` ]){2,30}$/', $return['username'])) {
			$return['error'] = 1;
			$errormsg[] = i("Username cannot contain single (') or double (&quot;) quotes, less than (&lt;), or greater than (&gt;) and can be from 2 to 64 characters long");
		}

		if((! empty($return['password']) ||
		   ! empty($return['password2'])) &&
		   ! preg_match('/^.{4,256}$/', $return['password'])) {
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

		$dcs = explode(',', $return['domaincontrollers']);
		if(count($dcs) > 5) {
			$return['error'] = 1;
			$errormsg[] = i("Too many Domain Controllers specified, up to 5 are allowed");
		}
		else {
			foreach($dcs as $dc) {
				if(! validateHostname($dc) && ! validateIPv4addr($dc)) {
					$return['error'] = 1;
					$errormsg[] = i("Invalid Domain Controller specified. Must be comman delimited list of hostnames or IP addresses, with up to 5 allowed");
				}
			}
		}

		/*if(! preg_match('/^$/', $return['logindescription'])) {
			$return['error'] = 1;
			$errormsg[] = i("");
		}*/

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

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkResourceInUse($rscid)
	///
	/// \param $rscid - id of resource
	///
	/// \return empty string if not being used; string of where resource is
	/// being used if being used
	///
	/// \brief checks to see if resource is being used
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkResourceInUse($rscid) {
		$msgs = array();

		/*
		# check reservations
		$query = "SELECT rq.end "
		       . "FROM request rq, "
		       .      "reservation rs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.imageid = $rscid AND "
		       .       "rq.stateid NOT IN (1, 12) AND "
		       .       "rq.end > NOW() "
		       . "ORDER BY rq.end DESC "
		       . "LIMIT 1";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh))
			$msgs[] = sprintf(i("There is at least one <strong>reservation</strong> for this image. The latest end time is %s."), prettyDatetime($row['end'], 1));;

		# check blockComputers
		$query = "SELECT br.name, "
		       .        "bt.end " 
		       . "FROM blockRequest br, " 
		       .      "blockTimes bt, "
		       .      "blockComputers bc "
		       . "WHERE bc.imageid = $rscid AND "
		       .       "bc.blockTimeid = bt.id AND "
		       .       "bt.blockRequestid = br.id AND "
		       .       "bt.end > NOW() AND "
		       .       "bt.skip = 0 AND "
		       .       "br.status = 'accepted' "
		       . "ORDER BY bt.end DESC "
		       . "LIMIT 1";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh))
			$msgs[] = sprintf(i("There is at least one <strong>Block Allocation</strong> with computers currently allocated with this image. Block Allocation %s has the latest end time which is %s."), $row['name'], prettyDatetime($row['end'], 1));

		if(empty($msgs))
			return '';

		$msg = i("The selected AD Domain is currently being used in the following ways and cannot be deleted at this time.") . "<br><br>\n";
		$msg .= implode("<br><br>\n", $msgs) . "<br><br>\n";
		return $msg;
		*/
		return '';
	}
}

?>
