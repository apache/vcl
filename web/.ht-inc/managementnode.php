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
/// \class ManagementNode
///
/// \brief extends Resource class to add things specific to resources of the
/// managementnode type
///
////////////////////////////////////////////////////////////////////////////////
class ManagementNode extends Resource {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief calls parent constructor; initializes things for ManagementNode
	/// class
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		global $user;
		parent::__construct();
		$this->restype = 'managementnode';
		$this->restypename = 'Management Node';
		$this->namefield = 'hostname';
		$this->hasmapping = 1;
		$this->maptype = 'computer';
		$this->maptypename = 'Computer';
		$this->defaultGetDataArgs = array('alive' => 'neither',
		                                  'includedeleted' => 0,
		                                  'rscid' => 0);
		$this->basecdata['obj'] = $this;
		$this->deletetoggled = 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getData($args)
	///
	/// \param $args - array of arguments that determine what data gets returned;
	/// must include:\n
	/// \b alive - 'now', 'future', or 'neither'
	/// \b includedeleted - 0 or 1; include deleted images\n
	/// \b rscid - only return data for resource with this id; pass 0 for all
	/// (from managementnode table)
	///
	/// \return array of data as returned from getManagementNodes
	///
	/// \brief wrapper for calling getManagementNodes
	///
	/////////////////////////////////////////////////////////////////////////////
	function getData($args) {
		return getManagementNodes($args['alive'], $args['includedeleted'], $args['rscid']);
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
			case 'IPaddress':
			case 'publicIPconfig':
			case 'publicnetmask':
			case 'publicgateway':
			case 'natpublicIPaddress':
			case 'natinternalIPaddress':
				$w = 8;
				break;
			case 'installpath':
			case 'publicdnsserver':
				$w = 11;
				break;
			case 'imagelibgroup':
			case 'imagelibkey':
			case 'federatedauth':
				$w = 9.5;
				break;
			case 'keys':
			case 'owner':
			case 'sharedmailbox':
				$w = 12;
				break;
			case 'keys':
			case 'sysadminemail':
			case 'timeservers':
				$w = 18;
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
			case 'IPaddress':
				return 'IP Address';
			case 'lastcheckin':
				return 'Last Check-in';
			case 'checkininterval':
				return 'Check-in interval';
			case 'installpath':
				return 'Install Path';
			case 'imagelibenable':
				return 'Enable Image Library';
			case 'imagelibgroup':
				return 'Image Library Group';
			case 'imagelibuser':
				return 'Image Library User';
			case 'imagelibkey':
				return 'Image Library Key';
			case 'sshport':
				return 'Image Library SSH Port';
			case 'publicIPconfig':
				return 'Public NIC Config.';
			case 'publicnetmask':
				return 'Public Netmask';
			case 'publicgateway':
				return 'Public Gateway';
			case 'publicdnsserver':
				return 'Public DNS Server';
			case 'sysadminemail':
				return 'Sysadmin Email Address';
			case 'sharedmailbox':
				return 'Shadow Email Address';
			case 'federatedauth':
				return 'Federated Auth. Affiliations';
			case 'timeservers':
				return 'Time Servers';
			case 'nathostenabled':
				return 'Use as NAT Host';
			case 'natpublicIPaddress':
				return 'NAT Public IP Address';
			case 'natinternalIPaddress':
				return 'NAT Internal IP Address';
		}
		return ucfirst($field);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkResourceInUse($rscid)
	///
	/// \return empty string if not being used; string of where resource is
	/// being used if being used
	///
	/// \brief checks to see if a management node is being used
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkResourceInUse($rscid) {
		$msgs = array();

		# check reservations
		$query = "SELECT rq.end "
		       . "FROM request rq, "
		       .      "reservation rs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.managementnodeid = $rscid AND "
		       .       "rq.stateid NOT IN (1, 12) AND "
		       .       "rq.end > NOW() "
		       . "ORDER BY rq.end DESC "
		       . "LIMIT 1";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh))
			$msgs[] = "There is at least one <strong>reservation</strong> being processed by this management node. The latest end time is " . prettyDatetime($row['end'], 1) . '.';

		# check blockRequest
		$query = "SELECT br.name, "
		       .        "bt.end " 
		       . "FROM blockRequest br, " 
		       .      "blockTimes bt "
		       . "WHERE br.managementnodeid = $rscid AND "
		       .       "bt.blockRequestid = br.id AND "
		       .       "bt.end > NOW() AND "
		       .       "bt.skip = 0 AND "
		       .       "br.status = 'accepted' "
		       . "ORDER BY bt.end DESC "
		       . "LIMIT 1";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh))
			$msgs[] = "There is at least one <strong>Block Allocation</strong> being handled by this management node. Block Allocation \"{$row['name']}\" has the latest end time which is " . prettyDatetime($row['end'], 1) . '.';


		if(empty($msgs))
			return '';

		$msg = "The selected management node is currently being used in the following ways and cannot be deleted at this time.<br><br>\n";
		$msg .= implode("<br><br>\n", $msgs) . "<br><br>\n";
		return $msg;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn toggleDeleteResource($rscid)
	///
	/// \param $rscid - id of a resource (from managementnode table)
	///
	/// \return 1 on success, 0 on failure
	///
	/// \brief uses state of management node to flag as deleted or not; if
	/// undeleting, sets state to maintenance
	///
	/////////////////////////////////////////////////////////////////////////////
	function toggleDeleteResource($rscid) {
		$query = "SELECT stateid FROM managementnode WHERE id = $rscid";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh)) {
			if($row['stateid'] == 1)
				$query = "UPDATE managementnode SET stateid = 10 WHERE id = $rscid";
			else
				$query = "UPDATE managementnode SET stateid = 1 WHERE id = $rscid";
			doQuery($query);
		}
		else
			return 0;

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin", 'mgmtnodeAdmin'), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin", 'mgmtnodeAdmin'), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);

		return 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addEditDialogHTML($add)
	///
	/// \param $add - unused for this class
	///
	/// \brief generates HTML for dialog used to edit resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function addEditDialogHTML($add=0) {
		global $user;
		# dialog for on page editing
		$h = '';
		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"addeditdlg\"\n";
		$h .= "      title=\"Edit {$this->restypename}\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"addeditdlgcontent\">\n";
		$h .= "<div id=\"mgmtnodedlgcontent\">\n";
		$h .= "<div style=\"text-align: center;\">\n";
		$h .= "<small>* denotes required fields</small><br><br>\n";
		$h .= "</div>\n";
		# id
		$h .= "<input type=\"hidden\" id=\"editresid\">\n";

		#$h .= "<div style=\"width: 80%; margin-left: 10%;\">\n";
		# name
		$errmsg = i("Name can only contain letters, numbers, dashes(-), periods(.), and underscores(_). It can be from 1 to 50 characters long.");
		$h .= labeledFormItem('name', i('Name') . '*', 'text', '^([a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,49})$',
		                      1, '', $errmsg); 
		# owner
		$extra = array('onKeyPress' => 'setOwnerChecking');
		$h .= labeledFormItem('owner', i('Owner') . '*', 'text', '', 1,
		                      "{$user['unityid']}@{$user['affiliation']}", i('Unknown user'),
		                      'checkOwner', $extra);
		$cont = addContinuationsEntry('AJvalidateUserid');
		$h .= "<input type=\"hidden\" id=\"valuseridcont\" value=\"$cont\">\n";

		# IP address
		$ipreg = '(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)';
		$ipreg1 = "^$ipreg$";
		$errmsg = i("Invalid IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('ipaddress', i('IP Address') . '*', 'text', $ipreg1, 1, '', $errmsg); 

		# State
		$vals = array(2 => "available", 10 => "maintenance", 5 => "failed");
		$h .= labeledFormItem('stateid', i('State'), 'select', $vals);

		# sysadmin email
		$reg = '^([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4},)*([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})$';
		$errmsg = i("Invalid email address(es) specified");
		$h .= labeledFormItem('sysadminemail', i("SysAdmin Email Address(es)"), 'text', $reg, 0, '',
		                      $errmsg, '', '', '', helpIcon('sysadminemailhelp')); 

		# shared mailbox
		$reg = '^([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})$';
		$errmsg = i("Invalid email address specified");
		$h .= labeledFormItem('sharedmailbox', i('Address for Shadow Emails'), 'text', $reg, 0, '',
		                      $errmsg, '', '', '', helpIcon('sharedmailboxhelp')); 

		# checkininterval
		$extra = array('smallDelta' => 1, 'largeDelta' => 2);
		$h .= labeledFormItem('checkininterval', i('Check-in Interval (sec)'), 'spinner', '{min:5,max:30,places:0}',
		                      1, '6', '', '', $extra, '', helpIcon('checkinhelp'));

		# installpath
		$reg = '^([-a-zA-Z0-9_\.\/]){2,100}$';
		$errmsg = i("Invalid install path specified");
		$h .= labeledFormItem('installpath', i('Install Path'), 'text', $reg, 0, '', $errmsg,
		                      '', '', '', helpIcon('installpathhelp')); 

		# timeserver list
		$reg = '^(([a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,49})(,?)){1,5}$';
		$errmsg = i("Invalid time server(s) specified. Must be comman delimited list of hostnames or IP addresses, with up to 5 allowed");
		$val = getVariable('timesource|global');
		$h .= labeledFormItem('timeservers', i('Time Server(s)'), 'text', $reg, 0, $val, $errmsg,
		                      '', '', '', helpIcon('timeservershelp')); 

		# keys
		$reg = '^([-a-zA-Z0-9_\.\/,]){2,1024}$';
		$errmsg = i("Invalid path to identity key files");
		$h .= labeledFormItem('keys', i('End Node SSH Identity Key Files'), 'text', $reg, 0, '', $errmsg,
		                      '', '', '', helpIcon('identityhelp')); 

		# sshport
		$extra = array('smallDelta' => 1, 'largeDelta' => 2);
		$h .= labeledFormItem('sshport', i('SSH Port for this Node'), 'spinner', '{min:1,max:65535,places:0}',
		                      1, '22', '', '', $extra, '', helpIcon('sshporthelp'));

		# image library
		$h .= "<div class=\"boxedoptions\">\n";
		# imagelibenable
		$extra = array('onChange' => 'toggleImageLibrary();');
		$h .= labeledFormItem('imagelibenable', i('Enable Image Library'), 'check', '', '', '', '', '',
		                      $extra, '', helpIcon('imagelibhelp'));

		# imagelibgroupid
		$disabled = array('disabled' => 'true');
		$vals = getUserResources(array('mgmtNodeAdmin'), array("manageGroup"), 1);
		$h .= labeledFormItem('imagelibgroupid', i('Image Library Management Node Group'), 'select',
		                      $vals['managementnode'], '', '', '', '', $disabled, '', helpIcon('imagelibgrouphelp'));

		# imagelibuser
		$reg = '^([-a-zA-Z0-9_\.\/,]){2,20}$';
		$errmsg = i("Invalid image library user");
		$h .= labeledFormItem('imagelibuser', i('Image Library User'), 'text', $reg, 0, '', $errmsg,
		                      '', $disabled, '', helpIcon('imagelibuserhelp')); 

		# imagelibkey
		$reg = '^([-a-zA-Z0-9_\.\/,]){2,100}$';
		$errmsg = i("Invalid image library identity key");
		$h .= labeledFormItem('imagelibkey', i('Image Library SSH Identity Key File'), 'text', $reg, 0, '', $errmsg,
		                      '', $disabled, '', helpIcon('imagelibkeyhelp')); 
		$h .= "</div>\n"; # image library

		# IP config method
		$h .= "<div class=\"boxedoptions\">\n";
		# publicIPconfig
		$extra = array('onChange' => 'togglePublic();');
		$vals = array('dynamicDHCP' => 'Dynamic DHCP',
		              'manualDHCP' => 'Manual DHCP',
		              'static' => 'Static');
		$h .= labeledFormItem('publicIPconfig', i('Public NIC Configuration Method'), 'select', $vals,
		                      '', '', '', '', $extra, '', helpIcon('ipconfighelp'));

		# netmask
		$errmsg = i("Invalid public netmask");
		$h .= labeledFormItem('publicnetmask', i('Public Netmask'), 'text', $ipreg1, 0, '', $errmsg,
		                      '', $disabled, '', helpIcon('netmaskhelp')); 

		# gateway
		$reg = '^[a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,56}$';
		$errmsg = i("Invalid public gateway");
		$h .= labeledFormItem('publicgateway', i('Public Gateway'), 'text', $reg, 0, '', $errmsg,
		                      '', $disabled, '', helpIcon('gatewayhelp')); 

		# dnsserver
		$reg = "^($ipreg,)*($ipreg)$";
		$errmsg = i("Invalid public DNS server");
		$h .= labeledFormItem('publicdnsserver', i('Public DNS Server'), 'text', $reg, 0, '', $errmsg,
		                      '', $disabled, '', helpIcon('dnsserverhelp')); 
		$h .= "</div>\n"; # IP config method

		# available public networks
		$h .= labeledFormItem('availablenetworks', i('Available Public Networks'), 'textarea', '', 1,
		                      '', '', '', '', '', helpIcon('availnetshelp'));

		# federated auth
		$h .= labeledFormItem('federatedauth', i('Affiliations Using Federated Authentication for Linux Images'),
		                      'textarea', '', 1, '', '', '', '', '', helpIcon('federatedauthhelp'));

		# NAT Host
		$h .= "<div id=\"nathost\" class=\"boxedoptions\">\n";
		# use as NAT host
		$extra = array('onChange' => "toggleNAThost();");
		$h .= labeledFormItem('nathostenabled', i('Use as NAT Host'), 'check', '', '', '1', '', '', $extra);
		# public IP
		$errmsg = i("Invalid NAT Public IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('natpublicipaddress', i('NAT Public IP Address'), 'text', $ipreg1, 1, '', $errmsg,
		                      '', '', '', helpIcon('natpubliciphelp')); 
		# internal IP
		$errmsg = i("Invalid NAT Internal IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('natinternalipaddress', i('NAT Internal IP Address'), 'text', $ipreg1, 1, '', $errmsg,
		                      '', '', '', helpIcon('natinternaliphelp')); 
		$h .= "</div>\n"; # NAT Host

		$h .= "</div>\n"; # mgmtnodedlgcontent
		$h .= "</div>\n"; # addeditdlgcontent

		$h .= "<div id=\"addeditdlgerrmsg\" class=\"nperrormsg\"></div>\n";
		$h .= "<div id=\"editdlgbtns\" align=\"center\">\n";
		$h .= dijitButton('addeditbtn', "Confirm", "saveResource();");
		$h .= dijitButton('', "Cancel", "dijit.byId('addeditdlg').hide();");
		$h .= "</div>\n"; # editdlgbtns
		$h .= "</div>\n"; # addeditdlg

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"groupingnote\"\n";
		$h .= "      title=\"Management Node Grouping\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "Each managemente node needs to be a member of a<br>management node resource group. The following dialog<br>will allow you to add the new management node to a group.<br><br>\n";
		$h .= "<div align=\"center\">\n";
		$h .= dijitButton('', "Close", "dijit.byId('groupingnote').hide();");
		$h .= "</div>\n"; # btn div
		$h .= "</div>\n"; # groupingnote

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"groupdlg\"\n";
		$h .= "      title=\"Management Node Grouping\"\n";
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
		$h .= helpTooltip('sysadminemailhelp', i("Comma delimited list of email addresses for sysadmins who should receive error emails from this management node. Leave empty to disable this feature."));
		$h .= helpTooltip('sharedmailboxhelp', i("Single email address to which copies of all user emails should be sent. This is a high traffic set of emails. Leave empty to disable this feature."));
		$h .= helpTooltip('checkinhelp', i("the number of seconds that this management node will wait before checking the database for tasks."));
		$h .= helpTooltip('installpathhelp', i("path to parent directory of image repository directories (typically /install) - only needed with bare metal installs or VMWare with local disk"));
		$h .= helpTooltip('timeservershelp', i("comma delimited list of time servers for this management node"));
		$h .= helpTooltip('identityhelp', i("comma delimited list of full paths to ssh identity keys to try when connecting to end nodes (optional)"));
		$h .= helpTooltip('sshporthelp', i("SSH port this node is listening on for image file transfers"));
		$h .= helpTooltip('imagelibhelp', i("Enable sharing of images between management nodes. This allows a management node to attempt fetching files for a requested image from other management nodes if it does not have them."));
		$h .= helpTooltip('imagelibgrouphelp', i("This management node will try to get image files from other nodes in the selected group."));
		$h .= helpTooltip('imagelibuserhelp', i("userid to use for scp when copying image files from another management node"));
		$h .= helpTooltip('imagelibkeyhelp', i("path to ssh identity key file to use for scp when copying image files from another management node"));
		$h .= helpTooltip('ipconfighelp', i("Method by which public NIC on nodes controlled by this management node receive their network configuration <ul><li>Dynamic DHCP - nodes receive an address via DHCP from a pool of addresses</li><li>Manual DHCP - nodes always receive the same address via DHCP</li><li>Static - VCL will configure the public address of the node</li></ul>"));
		$h .= helpTooltip('netmaskhelp', i("Netmask for public NIC"));
		$h .= helpTooltip('gatewayhelp', i("IP address of gateway for public NIC"));
		$h .= helpTooltip('dnsserverhelp', i("comma delimited list of IP addresses of DNS servers for public network"));
		$h .= helpTooltip('availnetshelp', i("This is a list of IP networks, one per line, available to nodes deployed by this management node. Networks should be specified in x.x.x.x/yy form.  It is for deploying servers having a fixed IP address to ensure a node is selected that can actually be on the specified network."));
		$h .= helpTooltip('federatedauthhelp', i("Comma delimited list of affiliations for which user passwords are not set for Linux image reservations under this management node. Each Linux image is then required to have federated authentication set up so that users' passwords are passed along to the federated authentication system when a user attempts to log in. (for clarity, not set setting user passwords does not mean users have an empty password, but that a federated system must authenticate the users)"));
		$h .= helpTooltip('natpubliciphelp', i("This is the IP address on the NAT host of the network adapter that is public facing. Users will connect to this IP address."));
		$h .= helpTooltip('natinternaliphelp', i("This is the IP address on the NAT host of the network adapter that is facing the internal network. This is how the NAT host will pass traffic to the VCL nodes."));
		$h .= "</div>\n"; # tooltips
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsaveResource()
	///
	/// \brief saves changes to resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsaveResource() {
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
				               'errormsg' => 'Error encountered while trying to create new management node.<br>Please contact an admin for assistance.'));
				return;
			}
		}
		else {
			$esc = array('sysadminemail' => mysql_real_escape_string($data['sysadminemail']),
			             'sharedmailbox' => mysql_real_escape_string($data['sharedmailbox']));

			$olddata = getContinuationVar('olddata');
			$updates = array();
			# hostname
			if($data['name'] != $olddata['hostname'])
				$updates[] = "hostname = '{$data['name']}'";
			$tmp = getVariable("timesource|{$olddata['hostname']}", "<unset>");
			if($tmp != "<unset>") {
				$query = "UPDATE variable "
				       . "SET name = 'timesource|{$data['name']}' " 
				       . "WHERE name = 'timesource|{$olddata['hostname']}'";
				doQuery($query);
			}
			# IPaddress
			if($data['ipaddress'] != $olddata['IPaddress'])
				$updates[] = "IPaddress = '{$data['ipaddress']}'";
			# ownerid
			$ownerid = getUserlistID($data['owner']);
			if($ownerid != $olddata['ownerid'])
				$updates[] = "ownerid = $ownerid";
			# stateid
			if($data['stateid'] != $olddata['stateid'])
				$updates[] = "stateid = '{$data['stateid']}'";
			# checkininterval
			if($data['checkininterval'] != $olddata['checkininterval'])
				$updates[] = "checkininterval = '{$data['checkininterval']}'";
			# installpath
			if($data['installpath'] != $olddata['installpath'])
				$updates[] = "installpath = '{$data['installpath']}'";
			# imagelibenable
			if($data['imagelibenable'] != $olddata['imagelibenable'])
				$updates[] = "imagelibenable = '{$data['imagelibenable']}'";
			# imagelibgroupid
			if($data['imagelibgroupid'] != $olddata['imagelibgroupid']) {
				if(is_null($data['imagelibgroupid']))
					$updates[] = "imagelibgroupid = NULL";
				else
					$updates[] = "imagelibgroupid = '{$data['imagelibgroupid']}'";
			}
			# imagelibuser
			if($data['imagelibuser'] != $olddata['imagelibuser'])
				$updates[] = "imagelibuser = '{$data['imagelibuser']}'";
			# imagelibkey
			if($data['imagelibkey'] != $olddata['imagelibkey'])
				$updates[] = "imagelibkey = '{$data['imagelibkey']}'";
			# keys
			if($data['keys'] != $olddata['keys'])
				$updates[] = "`keys` = '{$data['keys']}'";
			# sshport
			if($data['sshport'] != $olddata['sshport'])
				$updates[] = "sshport = '{$data['sshport']}'";
			# publicIPconfiguration
			if($data['publicIPconfig'] != $olddata['publicIPconfig'])
				$updates[] = "publicIPconfiguration = '{$data['publicIPconfig']}'";
			# publicSubnetMask
			if($data['publicnetmask'] != $olddata['publicnetmask'])
				$updates[] = "publicSubnetMask = '{$data['publicnetmask']}'";
			# publicDefaultGateway
			if($data['publicgateway'] != $olddata['publicgateway'])
				$updates[] = "publicDefaultGateway = '{$data['publicgateway']}'";
			# publicDNSserver
			if($data['publicdnsserver'] != $olddata['publicdnsserver'])
				$updates[] = "publicDNSserver = '{$data['publicdnsserver']}'";
			# sysadminEmailAddress
			if($data['sysadminemail'] != $olddata['sysadminemail'])
				$updates[] = "sysadminEmailAddress = '{$esc['sysadminemail']}'";
			# sharedMailBox
			if($data['sharedmailbox'] != $olddata['sharedmailbox'])
				$updates[] = "sharedMailBox = '{$esc['sharedmailbox']}'";
			# availablenetworks
			if($data['availablenetworks'] != implode(',', $olddata['availablenetworks']))
				$updates[] = "availablenetworks = '{$data['availablenetworks']}'";
			# federatedauth
			if($data['federatedauth'] != $olddata['federatedauth'])
				$updates[] = "NOT_STANDALONE = '{$data['federatedauth']}'";
			if(count($updates)) {
				$query = "UPDATE managementnode SET "
				       . implode(', ', $updates)
				       . " WHERE id = {$data['rscid']}";
				doQuery($query);
			}
			# time servers
			if($data['timeservers'] != $olddata['timeservers']) {
				$globalval = getVariable('timesource|global');
				if($data['timeservers'] == '' || $data['timeservers'] == $globalval)
					deleteVariable("timesource|{$data['name']}");
				else
					setVariable("timesource|{$data['name']}", $data['timeservers'], 'none');
			}

			# NAT host
			if($data['nathostenabled'] != $olddata['nathostenabled']) {
				if($data['nathostenabled']) {
					$query = "INSERT INTO nathost "
					       .       "(resourceid, "
					       .       "publicIPaddress, "
					       .       "internalIPaddress) "
					       . "VALUES "
					       .       "({$olddata['resourceid']}, "
					       .       "'{$data['natpublicIPaddress']}', "
					       .       "'{$data['natinternalIPaddress']}') "
					       . "ON DUPLICATE KEY UPDATE "
					       . "publicIPaddress = '{$data['natpublicIPaddress']}', "
					       . "internalIPaddress = '{$data['natinternalIPaddress']}'";
					doQuery($query);
				}
				else {
					$query = "DELETE FROM nathost "
					       . "WHERE resourceid = {$olddata['resourceid']}";
					doQuery($query);
				}
			}
			elseif($data['nathostenabled'] &&
			       ($olddata['natpublicIPaddress'] != $data['natpublicIPaddress'] ||
					 $olddata['natinternalIPaddress'] != $data['natinternalIPaddress'])) {
				$query = "UPDATE nathost "
				       . "SET publicIPaddress = '{$data['natpublicIPaddress']}', "
				       .     "internalIPaddress = '{$data['natinternalIPaddress']}' "
				       . "WHERE resourceid = {$olddata['resourceid']}";
				doQuery($query);
			}
		}

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin", 'mgmtnodeAdmin'), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin", 'mgmtnodeAdmin'), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin", 'mgmtnodeAdmin'), array("manageGroup"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin", 'mgmtnodeAdmin'), array("manageGroup"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);

		$tmp = $this->getData(array('includedeleted' => 1, 'rscid' => $data['rscid'], 'alive' => 'neither'));
		$data = $tmp[$data['rscid']];
		$arr = array('status' => 'success');
		$arr['data'] = $data;
		if($add) {
			$arr['action'] = 'add';
			$arr['data']['name'] = $arr['data']['hostname'];
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
	/// \fn validateResourceData()
	///
	/// \return array with these fields:\n
	/// \b rscid - id of resource (from managementnode table)\n
	/// \b name - hostname of managementnode\n
	/// \b owner\n
	/// \b ipaddress\n
	/// \b stateid\n
	/// \b sysadminemail - email address for sysadmins\n
	/// \b sharedmailbox - email address for shadow emails\n
	/// \b installpath\n
	/// \b timeservers - comma delimited list of time servers to be used on
	///    installed nodes\n
	/// \b keys - paths to identity keys for connecting to nodes\n
	/// \b sshport - port SSHD is listening on for this management node\n
	/// \b imagelibenable - 0 or 1, enable image library sharing\n
	/// \b imagelibgroupid - id of management node group for sharing images\n
	/// \b imagelibuser - user for logging in to other management nodes for
	//     sharing images\n
	/// \b imagelibkey - path to identity key for logging in to other management
	///    nodes for sharing images\n
	/// \b publicIPconfig - public IP config method\n
	/// \b publicnetmask - public netmask if doing static configuration\n
	/// \b publicgateway - public gateway if doing static configuration\n
	/// \b publicdnsserver - public DNS server if doing static configuration\n
	/// \b checkininterval - time in seconds between database checkins\n
	/// \b availablenetworks - networks available to nodes managed by this
	///    management node when requesting a fixed IP address\n
	/// \b federatedauth - comma delimited list of affiliations\n
	/// \b error - 0 if submitted data validates; 1 if anything is invalid\n
	/// \b errormsg - if error = 1; string of error messages separated by html
	///    break tags
	///
	/// \brief validates form input from editing or adding a management node
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateResourceData() {
		global $user;

		$return = array('error' => 0);

		$return['rscid'] = getContinuationVar('rscid', 0);
		$return['name'] = processInputVar('name', ARG_STRING);
		$return['owner'] = processInputVar('owner', ARG_STRING, "{$user['unityid']}@{$user['affiliation']}");
		$return['ipaddress'] = processInputVar('ipaddress', ARG_STRING);
		$return['stateid'] = processInputVar('stateid', ARG_NUMERIC);
		$return['sysadminemail'] = processInputVar('sysadminemail', ARG_STRING);
		$return['sharedmailbox'] = processInputVar('sharedmailbox', ARG_STRING);
		$return['installpath'] = processInputVar('installpath', ARG_STRING);
		$return['timeservers'] = processInputVar('timeservers', ARG_STRING);
		$return['keys'] = processInputVar('keys', ARG_STRING);
		$return['sshport'] = processInputVar('sshport', ARG_NUMERIC);
		$return['imagelibenable'] = processInputVar('imagelibenable', ARG_NUMERIC);
		$return['imagelibgroupid'] = processInputVar('imagelibgroupid', ARG_NUMERIC);
		$return['imagelibuser'] = processInputVar('imagelibuser', ARG_STRING);
		$return['imagelibkey'] = processInputVar('imagelibkey', ARG_STRING);
		$return['publicIPconfig'] = processInputVar('publicIPconfig', ARG_STRING);
		$return['publicnetmask'] = processInputVar('publicnetmask', ARG_STRING);
		$return['publicgateway'] = processInputVar('publicgateway', ARG_STRING);
		$return['publicdnsserver'] = processInputVar('publicdnsserver', ARG_STRING);
		$return['checkininterval'] = processInputVar('checkininterval', ARG_NUMERIC);
		$return['availablenetworks'] = processInputVar('availablenetworks', ARG_STRING);
		$return['federatedauth'] = processInputVar('federatedauth', ARG_STRING);
		$return['nathostenabled'] = processInputVar('nathostenabled', ARG_NUMERIC);
		$return['natpublicIPaddress'] = processInputVar('natpublicipaddress', ARG_STRING);
		$return['natinternalIPaddress'] = processInputVar('natinternalipaddress', ARG_STRING);

		if(get_magic_quotes_gpc()) {
			$return['sysadminemail'] = stripslashes($return['sysadminemail']);
			$return['sharedmailbox'] = stripslashes($return['sharedmailbox']);
		}

		$olddata = getContinuationVar('olddata');

		if($return['rscid'] == 0)
			$return['mode'] = 'add';
		else
			$return['mode'] = 'edit';

		$errormsg = array();

		# hostname
		if(! preg_match('/^[a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,49}$/', $return['name'])) {
			$return['error'] = 1;
			$errormsg[] = "Hostname can only contain letters, numbers, dashes(-), periods(.), and underscores(_). It can be from 1 to 50 characters long";
		}
		elseif($this->checkForMgmtnodeHostname($return['name'], $return['rscid'])) {
			$return['error'] = 1;
			$errormsg[] = "A node already exists with this hostname.";
		}
		# owner
		if(! validateUserid($return['owner'])) {
			$return['error'] = 1;
			$errormsg[] = "Submitted owner is not valid";
		}
		# ipaddress
		if(! validateIPv4addr($return['ipaddress'])) {
			$return['error'] = 1;
			$errormsg[] = "Invalid IP address. Must be w.x.y.z with each of "
		               . "w, x, y, and z being between 1 and 255 (inclusive)";
		}
		# sysadminemail
		if($return['sysadminemail'] != '') {
			$addrs = explode(',', $return['sysadminemail']);
			foreach($addrs as $addr) {
		  		if(! validateEmailAddress($addr)) {
					$return['error'] = 1;
					$errormsg[] = "Invalid email address entered for SysAdmin Email Address(es)";
					break;
				}
			}
		}
		# sharedmailbox
		if($return['sharedmailbox'] != '' &&
		   ! validateEmailAddress($return['sharedmailbox'])) {
			$return['error'] = 1;
			$errormsg[] = "Invalid email address entered for Shadow Emails";
		}
		# installpath
		if($return['installpath'] != '' &&
		   ! preg_match('/^([-a-zA-Z0-9_\.\/]){2,100}$/', $return['installpath'])) {
			$return['error'] = 1;
			$errormsg[] = "Install Path must be empty or only contain letters, numbers, dashes(-), periods(.), underscores(_), and forward slashes(/) and be from 2 to 100 characters long";
		}
		# timeservers
		if($return['timeservers'] != '') {
			if(strlen($return['timeservers']) > 1000) {
				$return['error'] = 1;
				$errormsg[] = "Too much data entered for Time Server(s)";
			}
			else {
				$hosts = explode(',', $return['timeservers']);
				foreach($hosts as $host) {
					if((preg_match('/^([0-9]{1,3}(\.?))+$/', $host) &&
					   ! validateIPv4addr($host)) ||
					   ! preg_match('/^[a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,50}$/', $host)) {
						$return['error'] = 1;
						$errormsg[] = "Time servers must be an IP address or a hostname containing only letters, numbers, dashes(-), periods(.), and underscores(_). Each host can be up to 50 characters long";
						break;
					}
				}
			}
		}
		# keys
		if($return['keys'] != '' &&
		   ! preg_match('/^([-a-zA-Z0-9_\.\/,]){2,1024}$/', $return['keys'])) {
			$return['error'] = 1;
			$errormsg[] = "End Node SSH Identity Key Files can only contain letters, numbers, dashes(-), periods(.), underscores(_), forward slashes(/), and commas(,). It can be from 2 to 1024 characters long";
		}
		# imagelibenable
		if($return['imagelibenable'] == 1) {
			# imagelibgroupid
			$validgroups = getUserResources(array('mgmtNodeAdmin'), array('manageGroup'), 1);
			if(! array_key_exists($return['imagelibgroupid'], $validgroups['managementnode'])) {
				$return['error'] = 1;
				$errormsg[] = "The group selected for Image Library Management Node Group is not valid";
			}
			# imagelibuser
			if(! preg_match('/^([-a-zA-Z0-9_\.\/,]){2,20}$/', $return['imagelibuser'])) {
				$return['error'] = 1;
				$errormsg[] = "Image Library User can only contain letters, numbers, and dashes(-) and can be from 2 to 20 characters long";
			}
			# imagelibkey
			if(! preg_match('/^([-a-zA-Z0-9_\.\/,]){2,100}$/', $return['imagelibkey'])) {
				$return['error'] = 1;
				$errormsg[] = "Image Library SSH Identity Key File can only contain letters, numbers, dashes(-), periods(.), underscores(_), and forward slashes(/). It can be from 2 to 100 characters long";
			}
		}
		else {
			$return['imagelibenable'] = 0;
			if($return['mode'] == 'edit') {
				$return['imagelibgroupid'] = NULL;
				$return['imagelibuser'] = $olddata['imagelibuser'];
				$return['imagelibkey'] = $olddata['imagelibkey'];
			}
			else {
				$return['imagelibgroupid'] = '';
				$return['imagelibuser'] = '';
				$return['imagelibkey'] = '';
			}
		}

		# publicIPconfig
		if(! preg_match('/^(dynamicDHCP|manualDHCP|static)$/', $return['publicIPconfig']))
			$return['publicIPconfig'] = 'dynamicDHCP';
		if($return['publicIPconfig'] == 'static') {
			# publicnetmask
			$bnetmask = ip2long($return['publicnetmask']);
			if(! preg_match('/^[1]+0[^1]+$/', sprintf('%032b', $bnetmask))) {
				$return['error'] = 1;
				$errormsg[] = "Invalid value specified for Public Netmask";
			}
			# publicgateway
			if(preg_match('/^([0-9]{1,3}(\.?))+$/', $return['publicgateway']) &&
			   ! validateIPv4addr($return['publicgateway'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid value specified for Public Gateway";
			}
			elseif(! preg_match('/^[a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,56}$/', $return["publicgateway"])) {
				$return['error'] = 1;
				$errormsg[] = "Public gateway must be an IP address or a hostname containing only letters, numbers, dashes(-), periods(.), and underscores(_). It can be up to 56 characters long";
			}
			# publicdnsserver
			$servers = explode(',', $return['publicdnsserver']);
			if(empty($servers)) {
				$return['error'] = 1;
				$errormsg[] = "Please enter at least one Public DNS server";
			}
			else {
				foreach($servers as $server) {
					if(! validateIPv4addr($server)) {
						$return['error'] = 1;
						$errormsg[] = "Invalid IP address entered for Public DNS Server";
						break;
					}
				}
			}
		}
		else {
			$return['publicnetmask'] = $olddata['publicnetmask'];
			$return['publicgateway'] = $olddata['publicgateway'];
		}
		# stateid  2 - available, 5 - failed, 10 - maintenance
		if(! preg_match('/^(2|5|10)$/', $return['stateid'])) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for State";
		}
		# checkininterval
		if($return['checkininterval'] < 5)
			$return['checkininterval'] = 5;
		elseif($return['checkininterval'] > 30)
			$return['checkininterval'] = 30;
		# sshport
		if($return['sshport'] < 1 || $return['sshport'] > 65535)
			$return['sshport'] = 22;
		# availablenetworks
		if($return['availablenetworks'] != '') {
			if(strpos("\n", $return['availablenetworks']))
				$return['availablenetworks'] = preg_replace("/(\r)?\n/", ',', $return['availablenetworks']);
			$return['availablenetworks2'] = explode(',', $return['availablenetworks']);
			foreach($return['availablenetworks2'] as $key => $net) {
				$net = trim($net);
				if($net == '') {
					unset($return['availablenetworks2'][$key]);
					$return['availablenetworks'] = implode("\n", $return['availablenetworks2']);
					continue;
				}
				$return['availablenetworks2'][$key] = $net;
				if(! preg_match('/^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\/([0-9]{2})$/', $net, $matches) ||
					$matches[1] < 0 || $matches[1] > 255 ||
					$matches[2] < 0 || $matches[2] > 255 ||
					$matches[3] < 0 || $matches[3] > 255 ||
					$matches[4] < 0 || $matches[4] > 255 ||
					$matches[5] < 1 || $matches[5] > 32) {
					$return['error'] = 1;
					$errormsg[] = "Invalid network entered for Available Public Networks; must be comma delimited list of valid networks in the form of x.x.x.x/yy";
				}
			}
		}
		# federatedauth
		if($return['federatedauth'] != '') {
			$affils = getAffiliations();
			$fedarr = explode(',', $return['federatedauth']);
			$test = array_udiff($fedarr, $affils, 'strcasecmp');
			if(! empty($test)) {
				$new = array();
				foreach($test as $affil) {
					if(preg_match('/^[-0-9a-zA-Z_\.:;,]*$/', $affil))
						$new[] = $affil;
				}
				if(count($test) == count($new))
					$errormsg[] = "These affiliations do not exist: " . implode(', ', $new);
				else
					$errormsg[] = "Invalid data entered for Affiliations Using Federated Authentication for Linux Images";
				$return['error'] = 1;
			}
		}

		$nathosterror = 0;
		# nathostenabled
		if($return['nathostenabled'] != 0 && $return['nathostenabled'] != 1) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value for Use as NAT Host";
			$nathosterror = 1;
		}
		# natpublicIPaddress
		if($return['nathostenabled']) {
			if(! validateIPv4addr($return['natpublicIPaddress'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid NAT Public IP address. Must be w.x.y.z with each of "
			               . "w, x, y, and z being between 1 and 255 (inclusive)";
				$nathosterror = 1;
			}
			# natinternalIPaddress
			if(! validateIPv4addr($return['natinternalIPaddress'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid NAT Internal IP address. Must be w.x.y.z with each of "
			               . "w, x, y, and z being between 1 and 255 (inclusive)";
				$nathosterror = 1;
			}
		}
		# nat host change - check for active reservations
		if(! $nathosterror && $return['mode'] == 'edit') {
			if($olddata['nathostenabled'] != $return['nathostenabled'] ||
			   $olddata['natpublicIPaddress'] != $return['natpublicIPaddress'] ||
				$olddata['natinternalIPaddress'] != $return['natinternalIPaddress']) {
				$vclreloadid = getUserlistID('vclreload@Local');
				$query = "SELECT rq.id "
				       . "FROM request rq, "
				       .      "reservation rs, "
				       .      "nathostcomputermap nhcm, "
				       .      "nathost nh "
				       . "WHERE rs.requestid = rq.id AND "
				       .       "rs.computerid = nhcm.computerid AND "
				       .       "nhcm.nathostid = nh.id AND "
				       .       "nh.resourceid = {$olddata['resourceid']} AND "
				       .       "rq.start <= NOW() AND "
				       .       "rq.end > NOW() AND "
				       .       "rq.stateid NOT IN (1,5,11,12) AND "
				       .       "rq.laststateid NOT IN (1,5,11,12) AND "
				       .       "rq.userid != $vclreloadid";
				$qh = doQuery($query);
				if(mysql_num_rows($qh)) {
					$return['error'] = 1;
					$errormsg[] = "This management node is the NAT host for computers that have active reservations. NAT host<br>settings cannot be changed while providing NAT for active reservations.";
				}
			}
		}

		if($return['error'])
			$return['errormsg'] = implode('<br>', $errormsg);

		return $return;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addResource($data)
	///
	/// \param $data - array of needed data for adding a new resource
	///
	/// \return id of new resource
	///
	/// \brief handles adding a new management node and other associated data to
	/// the database
	///
	/////////////////////////////////////////////////////////////////////////////
	function addResource($data) {
		global $user;
		$ownerid = getUserlistID($data['owner']);
		$esc = array('sysadminemail' => mysql_real_escape_string($data['sysadminemail']),
		             'sharedmailbox' => mysql_real_escape_string($data['sharedmailbox']));
		$keys = array('IPaddress',            'hostname',
		              'ownerid',              'stateid',
		              'checkininterval',      'installpath',
		              '`keys`',               'sshport',
		              'sysadminEmailAddress', 'sharedMailBox',
		              'availablenetworks',    'NOT_STANDALONE',
		              'imagelibenable',       'publicIPconfiguration',
		              'imagelibgroupid',      'imagelibuser',
		              'imagelibkey',          'publicSubnetMask',
		              'publicDefaultGateway', 'publicDNSserver');
		$values = array("'{$data['ipaddress']}'",        "'{$data['name']}'",
		                   $ownerid,                        $data['stateid'],
		                   $data['checkininterval'],     "'{$data['installpath']}'",
		                "'{$data['keys']}'",                $data['sshport'],
		                 "'{$esc['sysadminemail']}'",     "'{$esc['sharedmailbox']}'",
		                "'{$data['availablenetworks']}'","'{$data['federatedauth']}'",
		                   $data['imagelibenable'],      "'{$data['publicIPconfig']}'");
		if($data['imagelibenable'] == 1) {
			$values[] = $data['imagelibgroupid'];
			$values[] = "'{$data['imagelibuser']}'";
			$values[] = "'{$data['imagelibkey']}'";
		}
		else {
			$values[] = 'NULL';
			$values[] = 'NULL';
			$values[] = 'NULL';
		}
		if($data['publicIPconfig'] == 'static') {
			$values[] = "'{$data['publicnetmask']}'";
			$values[] = "'{$data['publicgateway']}'";
			$values[] = "'{$data['publicdnsserver']}'";
		}
		else {
			$values[] = 'NULL';
			$values[] = 'NULL';
			$values[] = 'NULL';
		}
		$query = "INSERT INTO managementnode ("
		       . implode(', ', $keys) . ") VALUES ("
		       . implode(', ', $values) . ")";
		doQuery($query);

		$rscid = dbLastInsertID();
	
		// add entry in resource table
		$query = "INSERT INTO resource "
				 .        "(resourcetypeid, "
				 .        "subid) "
				 . "VALUES (16, "
				 .         "$rscid)";
		doQuery($query);

		$resourceid = dbLastInsertID();

		# NAT host
		if($data['nathostenabled']) {
			$query = "INSERT INTO nathost "
			       .       "(resourceid, "
			       .       "publicIPaddress, "
			       .       "internalIPaddress) "
			       . "VALUES "
			       .       "($resourceid, "
			       .       "'{$data['natpublicIPaddress']}', "
			       .       "'{$data['natinternalIPaddress']}')";
			doQuery($query);
		}

		# time server
		$globalval = getVariable('timesource|global');
		if($data['timeservers'] != $globalval)
			setVariable("timesource|{$data['name']}", $data['timeservers'], 'none');
	
		return $rscid;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkForMgmtnodeHostname($hostname, $id)
	///
	/// \param $hostname - a computer hostname
	/// \param $id - id of managementnode to be skipped
	///
	/// \return 0 if $hostname is not in managementnode table, 1 if it is
	///
	/// \brief checks for the existance of $hostname in the managementnode table
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkForMgmtnodeHostname($hostname, $id=0) {
		$query = "SELECT id "
		       . "FROM managementnode "
		       . "WHERE hostname = '$hostname'";
		if($id != 0)
			$query .= " AND id != $id";
		$qh = doQuery($query);
		return mysql_num_rows($qh);
	}
}
?>
