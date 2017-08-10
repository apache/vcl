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
/// \class Image
///
/// \brief extends Resource class to add things specific to resources of the
/// image type
///
////////////////////////////////////////////////////////////////////////////////
class Image extends Resource {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief calls parent constructor; initializes things for Image class
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->restype = 'image';
		$this->restypename = 'Image';
		$this->namefield = 'prettyname';
		$this->hasmapping = 1;
		$this->maptype = 'computer';
		$this->maptypename = 'Computer';
		$this->defaultGetDataArgs = array('includedeleted' => 0,
		                                  'rscid' => 0);
		$this->basecdata['obj'] = $this;
		$this->addable = 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getData($args)
	///
	/// \param $args - array of arguments that determine what data gets returned;
	/// must include:\n
	/// \b includedeleted - 0 or 1; include deleted images\n
	/// \b rscid - only return data for resource with this id; pass 0 for all
	/// (from image table)
	///
	/// \return array of data as returned from getImages
	///
	/// \brief wrapper for calling getImages
	///
	/////////////////////////////////////////////////////////////////////////////
	function getData($args) {
		$data = getImages($args['includedeleted'], $args['rscid']);
		$noimageid = getImageId('noimage');
		if($noimageid)
			unset($data[$noimageid]);
		return $data;
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
			case 'owner':
				$w = 12;
				break;
			case 'os':
				$w = 8;
				break;
			case 'addomain':
				$w = 10;
				break;
			case 'baseOU':
				$w = 12;
				break;
			case 'adauthenabled':
				$w = 9;
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
			case 'os':
				return i("OS");
			case 'installtype':
				return i("Install Type");
			case 'ostype':
				return i("OS Type");
			case 'minram':
				return i("Required RAM");
			case 'minprocnumber':
				return i("Required Cores");
			case 'minprocspeed':
				return i("Processor Speed");
			case 'minnetwork':
				return i("Min. Network Speed");
			case 'maxconcurrent':
				return i("Max Concurrent Usage");
			case 'reloadtime':
				return i("Est. Reload Time");
			case 'lastupdate':
				return i("Last Updated");
			case 'forcheckout':
				return i("Available for Checkout");
			case 'maxinitialtime':
				return i("Max Initial Time");
			case 'checkuser':
				return i("Check Logged in User");
			case 'rootaccess':
				return i("Admin. Access");
			case 'sethostname':
				return i("Set Hostname");
			case 'adauthenabled':
				return i("Use AD Authentication");
			case 'addomain':
				return i("AD Domain");
			case 'baseOU':
				return i("Base OU");
		}
		return i(ucfirst($field));
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkResourceInUse($rscid)
	///
	/// \return empty string if not being used; string of where resource is
	/// being used if being used
	///
	/// \brief checks to see if an image is being used
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkResourceInUse($rscid) {
		$msgs = array();

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

		# check blockRequest
		$query = "SELECT br.name, "
		       .        "bt.end " 
		       . "FROM blockRequest br, " 
		       .      "blockTimes bt "
		       . "WHERE br.imageid = $rscid AND "
		       .       "bt.blockRequestid = br.id AND "
		       .       "bt.end > NOW() AND "
		       .       "bt.skip = 0 AND "
		       .       "br.status = 'accepted' "
		       . "ORDER BY bt.end DESC "
		       . "LIMIT 1";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh))
			$msgs[] = sprintf(i("There is at least one <strong>Block Allocation</strong> configured to use this image. Block Allocation %s has the latest end time which is %s."), $row['name'], prettyDatetime($row['end'], 1));

		# check serverprofile
		$query = "SELECT name "
		       . "FROM serverprofile "
		       . "WHERE imageid = $rscid";
		$qh = doQuery($query);
		$profiles = array();
		while($row = mysql_fetch_assoc($qh))
			$profiles[] = $row['name'];
		if(count($profiles))
			$msgs[] = i("The following <strong>Server Profiles</strong> are configured to use this image:") . "<br><br>\n" . implode("<br>\n", $profiles);

		# check subimages
		$query = "SELECT DISTINCT i.prettyname "
		       . "FROM image i, "
		       .      "imagemeta im, "
		       .      "subimages s "
		       . "WHERE i.imagemetaid = im.id AND "
		       .       "im.subimages = 1 AND "
		       .       "s.imagemetaid = im.id AND "
		       .       "s.imageid = $rscid";
		$images = array();
		while($row = mysql_fetch_assoc($qh))
			$images[] = $row['prettyname'];
		if(count($images))
			$msgs[] = i("The following <strong>images</strong> have the selected image assigned as a <strong>subimage</strong>:") . "<br><br>\n" . implode("<br>\n", $images);

		# check vmprofile
		$query = "SELECT profilename "
		       . "FROM vmprofile "
		       . "WHERE imageid = $rscid";
		$profiles = array();
		while($row = mysql_fetch_assoc($qh))
			$profiles[] = $row['profilename'];
		if(count($profiles))
			$msgs[] = i("The following <strong>VM Host Profiles</strong> have the this image selected:") . "<br><br>\n" . implode("<br>\n", $profiles);

		if(empty($msgs))
			return '';

		$msg = i("The selected image is currently being used in the following ways and cannot be deleted at this time.") . "<br><br>\n";
		$msg .= implode("<br><br>\n", $msgs) . "<br><br>\n";
		return $msg;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn submitToggleDeleteResourceExtra($rscid, $deleted)
	///
	/// \param $rscid - id of a resource (from image table)
	/// \param $deleted - (optional, default=0) 1 if resource was previously
	/// deleted; 0 if not
	///
	/// \brief handles deleted flag for cooresponding entries in imagerevision
	/// table
	///
	/////////////////////////////////////////////////////////////////////////////
	function submitToggleDeleteResourceExtra($rscid, $deleted=0) {
		if($deleted) {
			$query = "UPDATE imagerevision i1, "
			       .        "imagerevision i2 "
			       . "SET i1.deleted = 0, "
			       .     "i1.datedeleted = NULL "
			       . "WHERE i1.imageid = $rscid AND "
			       .       "i2.imageid = $rscid AND "
			       .       "i2.production = 1 AND "
			       .       "i1.datedeleted = i2.datedeleted";
		}
		else {
			$query = "UPDATE imagerevision "
					 . "SET deleted = 1, "
					 .     "datedeleted = NOW() "
					 . "WHERE imageid = $rscid AND "
					 .       "deleted = 0";
		}
		doQuery($query);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn extraSelectAdminOptions()
	///
	/// \return html
	///
	/// \brief generates HTML for option to create/update an image
	///
	/////////////////////////////////////////////////////////////////////////////
	function extraSelectAdminOptions() {
		$h = '';
		$cdata = array('imaging' => 1);
		$cont = addContinuationsEntry("viewRequests", $cdata);
		$h .= "<INPUT type=radio name=\"continuation\" value=\"$cont\" id=\"";
		$h .= "createimage\"><label for=\"createimage\">";
		$h .= i("Create / Update an Image");
		$h .= "</label><br>\n";
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addEditDialogHTML($add)
	///
	/// \param $add (optional, defaul=0) - 0 for edit, 1 for add
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
		if($add)
			$h .= "      title=\"" . i("Add {$this->restypename}") . "\"\n";
		else
			$h .= "      title=\"" . i("Edit {$this->restypename}") . "\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"addeditdlgcontent\">\n";
		# id
		$h .= "<input type=\"hidden\" id=\"editresid\">\n";

		if(! $add)
			$h .= "<div style=\"width: 80%; margin-left: 10%; overflow: auto; height: 80%;\">\n";
		# name
		$errmsg = i("Name cannot contain single (') or double (&quot;) quotes, less than (&lt;), or greater than (&gt;) and can be from 2 to 60 characters long");
		$h .= labeledFormItem('name', i('Name'), 'text', '^([-A-Za-z0-9!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\./\?~` ]){2,60}$',
		                      1, '', $errmsg); 
		# owner
		$extra = array('onKeyPress' => 'setOwnerChecking');
		$h .= labeledFormItem('owner', i('Owner'), 'text', '', 1, '', i('Unknown user'),
		                      'checkOwner', $extra);
		#$h .= labeledFormItem('owner', i('Owner'), 'text', '{$user['unityid']}@{$user['affiliation']}',
		#                      1, '', i('Unknown user'), 'checkOwner', 'onKeyPress', 'setOwnerChecking');
		$cont = addContinuationsEntry('AJvalidateUserid');
		$h .= "<input type=\"hidden\" id=\"valuseridcont\" value=\"$cont\">\n";
		# description
		$h .= "<fieldset>\n";
		$h .= "<legend>" . i("Image Description") . "</legend>\n";
		$h .= i("Description of image (required - users will see this on the <strong>New Reservations</strong> page):");
		$h .= "<br>\n";
		$h .= "<textarea dojoType=\"dijit.form.Textarea\" id=\"description\" ";
		$h .= "style=\"width: 400px; text-align: left;\"></textarea>\n";
		$h .= "</fieldset>\n";
		# usage notes
		$h .= "<fieldset>\n";
		$h .= "<legend>" . i("Usage Notes") . "</legend>\n";
		$msg = i("Optional notes to the user explaining how to use the image (users will see this on the <strong>Connect!</strong> page):");
		$h .= preg_replace("/(.{1,100}([ \n]|$))/", '\1<br>', $msg);
		$h .= "<textarea dojoType=\"dijit.form.Textarea\" id=\"usage\" ";
		$h .= "style=\"width: 400px; text-align: left;\"></textarea>\n";
		$h .= "</fieldset>\n";
		if($add) {
			$h .= "<fieldset>\n";
			$h .= "<legend>" . i("Revision Comments") . "</legend>\n";
			$msg = i("Notes for yourself and other admins about how the image was setup/installed. These are optional and are not visible to end users.");
			$h .= preg_replace("/(.{1,80}([ \n]|$))/", '\1<br>', $msg);
			$h .= "<textarea dojoType=\"dijit.form.Textarea\" id=\"imgcomments\" ";
			$h .= "style=\"width: 400px; text-align: left;\"></textarea>";
			$h .= "</fieldset>\n";
		}
		# advanced options
		$h .= "<div dojoType=\"dijit.TitlePane\" title=\"";
		$h .= i("Advanced Options - leave default values unless you really know what you are doing (click to expand)");
		$h .= "\" open=\"false\" style=\"width: 460px\" id=\"advancedoptions\" ";
		$h .= "onShow=\"delayedEditResize();\" onHide=\"delayedEditResize();\">\n";
		# RAM
		$extra = array('smallDelta' => 256, 'largeDelta' => 1024);
		$h .= labeledFormItem('ram', i('Required RAM'), 'spinner', '{min:512, max:8388607}',
		                      1, 1024, '', '', $extra);
		# cores
		$extra = array('smallDelta' => 1, 'largeDelta' => 2);
		$h .= labeledFormItem('cores', i('Required Cores'), 'spinner', '{min:1, max:255}',
		                      1, 1, '', '', $extra);
		# proc speed
		$extra = array('smallDelta' => 500, 'largeDelta' => 8000);
		$h .= labeledFormItem('cpuspeed', i('Processor Speed'), 'spinner', '{min:500, max:8000}',
		                      1, 1000, '', '', $extra);
		# network speed
		$vals = array('10' => '10 Mbps',
		              '100' => '100 Mbps',
		              '1000' => '1 Gbps',
		              '10000' => '10 Gbps',
		              '100000' => '100 Gbps');
		$h .= labeledFormItem('networkspeed', i('Minimum Network Speed'), 'select', $vals);
		# concurrent usage
		$extra = array('smallDelta' => 1, 'largeDelta' => 10);
		$h .= labeledFormItem('concurrent', i('Max Concurrent Usage'), 'spinner','{min:0, max:255}',
		                       1, 0, '', '', $extra, '', i('(0 = unlimited)'));
		# reload time
		if(! $add) {
			$extra = array('smallDelta' => 1, 'largeDelta' => 5);
			$h .= labeledFormItem('reload', i('Estimated Reload Time'), 'spinner',
			                      '{min:1, max:255}', 1, 5, '', '', $extra);
		}
		# for checkout
		$yesno = array('1' => 'Yes',
		              '0' => 'No');
		$h .= labeledFormItem('checkout', i('Available for Checkout'), 'select', $yesno);
		# check user
		$h .= labeledFormItem('checkuser', i('Check for Logged in User'), 'select', $yesno);
		# admin access
		$h .= labeledFormItem('rootaccess', i('Users Have Administrative Access'), 'select', $yesno);
		# set hostname
		$h .= "<div id=\"sethostnamediv\">\n";
		$h .= labeledFormItem('sethostname', i('Set Computer Hostname'), 'select', $yesno);
		$h .= "</div>\n";
		# sysprep
		if($add) {
			$h .= "<div id=\"sysprepdiv\">\n";
			$h .= labeledFormItem('sysprep', i('Use Sysprep'), 'select', $yesno);
			$h .= "</div>\n";
		}
		# connect methods
		$h .= "<label for=\"connectmethodlist\">" . i("Connect Methods:") . "</label>\n";
		$h .= "<div class=\"labeledform\"><span id=\"connectmethodlist\"></span><br>\n";
		$h .= "<div dojoType=\"dijit.form.DropDownButton\" id=\"connectmethoddlg\">\n";
		$h .= "  <span>" . i("Modify Connection Methods") . "</span>\n";
		// if leave off the href attribute, inital sizing of popup is wrong
		$h .= "  <div dojoType=\"dijit.TooltipDialog\" id=\"connectmethodttd\" href=\"\"></div>\n";
		$h .= "</div>\n";
		if($add) {
			$h .= "<input type=\"hidden\" name=\"connectmethodids\" ";
			$h .= "id=\"connectmethodids\">\n";
		}
		$h .= "</div>\n"; #labeledform

		# AD authentication
		$h .= "<div class=\"boxedoptions hidden\" id=\"imageadauthbox\">\n";
		# enable toggle
		$extra = array('onChange' => 'toggleADauth();');
		$h .= labeledFormItem('adauthenable', i('Use AD Authentication'), 'check', '', '', '', '', '', $extra);
		# AD domain
		$vals = getUserResources(array('addomainAdmin'), array("manageGroup"));
		$extra = array('onChange' => 'selectADauth();');
		$h .= labeledFormItem('addomainid', i('AD Domain'), 'select', $vals['addomain'], '', '', '', '', $extra);
		# base OU
		$reg = '^([Oo][Uu])=[^,]+(,([Oo][Uu])=[^,]+)*$';
		$errmsg = i("Invalid base OU; do not include DC components");
		$h .= labeledFormItem('baseou', i('Base OU'), 'text', $reg, 0, '', $errmsg, '', '', '230px', helpIcon('baseouhelp')); 
		$h .= "</div>\n"; # boxedoptions

		# subimages
		if(! $add) {
			$h .= "<br>\n";
			$h .= "<div align=\"center\">\n";
			$h .= "<div dojoType=\"dijit.form.DropDownButton\" id=\"subimagebtn\">";
			$h .= "  <span>" . i("Manage Subimages") . "</span>\n";
			// if leave off the href attribute, inital sizing of popup is wrong
			$h .= "  <div dojoType=\"dijit.TooltipDialog\" id=\"subimagedlg\" href=\"\"></div>\n";
			$h .= "</div>\n";
			$h .= "</div>\n";
		}

		if(! $add)
			$h .= "</div>\n";

		$h .= "</div>\n";

		$h .= "<div id=\"addeditdlgerrmsg\" class=\"nperrormsg\"></div>\n";

		$h .= "</div>\n"; # addeditdlgcontent

		$h .= "<div id=\"editdlgbtns\" align=\"center\">\n";
		$h .= dijitButton('addeditbtn', i("Confirm"), "saveResource();");
		$script  = "    dijit.byId('addeditdlg').hide();\n";
		$script .= "    dijit.registry.filter(function(widget, index){return widget.id.match(/^comments/);}).forEach(function(widget) {widget.destroy();});\n";
		$h .= dijitButton('', i("Close"), $script);
		$h .= "</div>\n"; # editdlgbtns

		if(! $add) {
			$h .= "<div id=revisiondiv>\n";
			$h .= "</div>\n";
		}

		$h .= "</div>\n"; # addeditdlg

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"autoconfirmdlg\"\n";
		$h .= "      title=\"" . i("Confirm Manual Install") . "\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<strong><span id=\"autoconfirmcontent\"></span></strong><br><br>\n";
		$h .= "<div style=\"width: 230px;\">\n";
		$h .= i("This method cannot be automatically added to the image by VCL. The image must be created with the software for this method already installed. If this image already has software for this method installed in it, please click <strong>Software is Manually Installed</strong>. Otherwise, click cancel.");
		$h .= "</div><br><br>\n";
		$h .= "   <div align=\"center\">\n";
		$script  = "       dijit.byId('autoconfirmdlg').hide();\n";
		$script .= "       addConnectMethod3();\n";
		$script .= "       dijit.byId('connectmethoddlg').openDropDown();\n";
		$h .= dijitButton('', i("Software is Manually Installed"), $script);
		$script  = "       dijit.byId('autoconfirmdlg').hide();\n";
		$script .= "       dijit.byId('connectmethoddlg').openDropDown();\n";
		$h .= dijitButton('', i("Cancel"), $script);
		$h .= "   </div>\n";
		$h .= "</div>\n"; # autoconfirmdlg

		$h .= helpTooltip('baseouhelp', i('OU where nodes deployed with this image will be registered. Do not enter the domain component (ex OU=Computers,OU=VCL)'));
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn connectmethodDialogContent
	///
	/// \brief prints HTML for connect method dialog available when
	/// editing/adding an image
	///
	/////////////////////////////////////////////////////////////////////////////
	function connectmethodDialogContent() {
		$imageid = getContinuationVar('imageid');
		$newimage = getContinuationVar('newimage', 0);
		$curmethods = getContinuationVar('curmethods');
		$methods = getConnectMethods($imageid);
		$revisions = getImageRevisions($imageid);
	
		$h  = "<h3>" . i("Modify Connection Methods") . "</h3>";
		if(! $newimage && count($revisions) > 1) {
			$h .= i("Selected Revision ID:") . " ";
			$cdata = $this->basecdata;
			$cdata['imageid'] = $imageid;
			$cdata['revids'] = array_keys($revisions);
			$cdata['curmethods'] = $curmethods;
			$cdata['newimage'] = $newimage;
			$cont = addContinuationsEntry('jsonImageConnectMethods', $cdata);
			$url = BASEURL . SCRIPT . "?continuation=$cont";
			$h .= "<select dojoType=\"dijit.form.Select\" id=\"conmethodrevid\" ";
			$h .= "onChange=\"selectConMethodRevision('$url');\">";
			foreach($revisions as $revid => $revision) {
				if($revision['production'])
					$h .= "<option value=\"$revid\" selected=\"true\">{$revision['revision']}</option>";
				else
					$h .= "<option value=\"$revid\">{$revision['revision']}</option>";
			}
			$h .= "</select>";
		}
		$cdata = $this->basecdata;
		$cdata['imageid'] = $imageid;
		$cdata['curmethods'] = $curmethods;
		$cdata['newimage'] = $newimage;
		$cont = addContinuationsEntry('jsonImageConnectMethods', $cdata);
		$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" url=\"" . BASEURL;
		$h .= SCRIPT . "?continuation=$cont\" jsid=\"cmstore\" id=\"cmstore\">";
		$h .= "</div>\n";
		$h .= "<div dojoType=\"dijit.form.Select\" id=\"addcmsel\" ";
		$h .= "store=\"cmstore\" query=\"{active: 0}\" ";
		$h .= "onSetStore=\"updateCurrentConMethods();\"></div>";
		$h .= dijitButton('addcmbtn', i("Add Method"), "addConnectMethod();");
		$h .= "<br>";
		$h .= "<h3>" . i("Current Methods") . "</h3>";
		$h .= "<select id=\"curmethodsel\" multiple size=\"5\">";
		$h .= "</select><br>";
		$h .= dijitButton('remcmbtn', i("Remove Selected Methods(s)"), "remConnectMethod();");
		$h .= "<br>";
		$h .= "<div id=\"cmerror\" class=\"rederrormsg\"></div>\n";
		$adminimages = getUserResources(array("imageAdmin"), array("administer"));
		$adminids = array_keys($adminimages["image"]);
		$cdata = $this->basecdata;
		$cdata['imageid'] = $imageid;
		$cdata['methods'] = $methods;
		$cdata['revids'] = array_keys($revisions);
		$cdata['newimage'] = $newimage;
		$cont = addContinuationsEntry('AJaddImageConnectMethod', $cdata, 3600, 1, 0);
		$h .= "<INPUT type=hidden id=addcmcont value=\"$cont\">";
		$cont = addContinuationsEntry('AJremImageConnectMethod', $cdata, 3600, 1, 0);
		$h .= "<INPUT type=hidden id=remcmcont value=\"$cont\">";
		if(! $newimage) {
			$h .= "<div style=\"width: 280px;\">\n";
			$h .= i("NOTE: Connection Method changes take effect immediately; you do <strong>not</strong> need to click \"Submit Changes\" to submit them.");
			$h .= "</div>\n";
		}
		print $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn subimageDialogContent()
	///
	/// \brief prints content to fill in the dialog for managing subimages
	///
	/////////////////////////////////////////////////////////////////////////////
	function subimageDialogContent() {
		$imageid = getContinuationVar('imageid');
		$images = getImages(0);
		$image = $images[$imageid];

		$resources = getUserResources(array("imageAdmin"));
		if(empty($resources['image'])) {
			print i("You do not have access to add any subimages to this image.");
			return;
		}

		$h  = "<h3>" . i("Add New Subimage") . "</h3>";
		$h .= "<select dojoType=\"dijit.form.FilteringSelect\" id=\"addsubimagesel\">";
		foreach($resources['image'] as $id => $name) {
			if($name == 'No Image')
				continue;
			$h .= "<option value=$id>$name</option>";
		}
		$h .= "</select>";
		$h .= dijitButton('addbtn', i("Add Subimage"), "addSubimage();");
		$h .= "<br>";
		$h .= "<h3>" . i("Current Subimages") . "</h3>";
		$subimgcnt = 0;
		if(array_key_exists("subimages", $image) && count($image["subimages"])) {
			$subimages = array();
			foreach($image["subimages"] as $imgid)
				$subimages[] = array('id' => $imgid,
											'name' => $images[$imgid]['prettyname']);
			uasort($subimages, "sortKeepIndex");
			$h .= "<select id=\"cursubimagesel\" multiple size=\"10\">";
			foreach($subimages as $img) {
				$h .= "<option value={$img['id']}>{$img['name']}</option>";
				$subimgcnt++;
			}
		}
		else {
			$h .= "<select id=\"cursubimagesel\" multiple size=\"10\" disabled>";
			$image['subimages'] = array();
			$h .= "<option value=\"none\">" . i("(None)") . "</option>";
		}
		$h .= "</select><br>";
		$h .= i("total subimages:") . " <span id=subimgcnt>$subimgcnt</span><br>";
		$h .= dijitButton('rembtn', i("Remove Selected Subimage(s)"), "remSubimages();");
		$h .= "<br>";
		$adminimages = getUserResources(array("imageAdmin"), array("administer"));
		$adminids = array_keys($adminimages["image"]);
		$cdata = $this->basecdata;
		$cdata['imageid'] = $imageid;
		$cdata['adminids'] = $adminids;
		$cdata['imagemetaid'] = $image['imagemetaid'];
		$cdata['userimageids'] = array_keys($resources['image']);
		$cdata['subimages'] = $image['subimages'];
		$cont = addContinuationsEntry('AJaddSubimage', $cdata, SECINDAY, 1, 0);
		$h .= "<INPUT type=\"hidden\" id=\"addsubimagecont\" value=\"$cont\">";
		$cont = addContinuationsEntry('AJremSubimage', $cdata, SECINDAY, 1, 0);
		$h .= "<INPUT type=\"hidden\" id=\"remsubimagecont\" value=\"$cont\">";
		$h .= "<div style=\"width: 320px;\">\n";
		$h .= i("NOTE: Subimage changes take effect immediately; you do <strong>not</strong> need to click \"Submit Changes\" to submit them.");
		$h .= "</div>\n";
		print $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJeditResource()
	///
	/// \brief sends data for editing a resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJeditResource() {
		global $user;
		$imageid = processInputVar('rscid', ARG_NUMERIC);
		$images = getUserResources(array("imageAdmin"), array('administer'), 0, 1);
		if(! array_key_exists($imageid, $images['image'])) {
			$ret = array('status' => 'noaccess');
			sendJSON($ret);
			return;
		}
		$tmp = $this->getData(array('includedeleted' => 0, 'rscid' => $imageid));
		$data = $tmp[$imageid];
		$extra = getImageNotes($imageid);
		$extra['description'] = preg_replace('/<br>/', "\n", $extra['description']);
		$extra['description'] = htmlspecialchars_decode($extra['description']);
		$extra['usage'] = htmlspecialchars_decode($extra['usage']);
		$data = array_merge($data, $extra);
		$cdata = $this->basecdata;
		$cdata['imageid'] = $imageid;
		$cdata['olddata'] = $data;
		if($data['minram'] < 512)
			$data['minram'] = 512;

		# addomain
		$cdata['addomainvals'] = array();
		if(in_array("addomainAdmin", $user["privileges"])) {
			$vals = getUserResources(array('addomainAdmin'), array("manageGroup"));
			$data['addomainvals'] = $vals['addomain'];
			$cdata['addomainvals'] = $data['addomainvals'];
			if(! is_null($data['addomain']) &&
				! in_array($data['addomain'], $data['addomainvals'])) {
				$data['addomainvals'][$data['addomainid']] = $data['addomain'];
				$data['extraaddomainid'] = $data['addomainid'];
				$data['extraaddomainou'] = $data['baseOU'];
				$cdata['extraaddomainid'] = $data['addomainid'];
				$cdata['extraaddomainou'] = $data['baseOU'];
			}
		}
		elseif(! is_null($data['addomain'])) {
				$data['addomainvals'][$data['addomainid']] = $data['addomain'];
				$data['extraaddomainid'] = $data['addomainid'];
				$data['extraaddomainou'] = $data['baseOU'];
				$cdata['extraaddomainid'] = $data['addomainid'];
		}

		# revisions
		$data['revisionHTML'] = $this->getRevisionHTML($imageid);

		# subimage url
		$cdata2 = array('obj' => $this,
		                'imageid' => $imageid);
		$cont = addContinuationsEntry('subimageDialogContent', $cdata2);
		$data['subimageurl'] = BASEURL . SCRIPT . "?continuation=$cont";
		# connect method url
		$cdata2['curmethods'] = $data['connectmethods'];
		#$cdata2['newimage'] = $state;
		$cont = addContinuationsEntry('connectmethodDialogContent', $cdata2);
		$data['connectmethodurl'] = BASEURL . SCRIPT . "?continuation=$cont";
		$data['connectmethods'] = array_values($data['connectmethods']);
		# save continuation
		$cont = addContinuationsEntry('AJsaveResource', $cdata);

		$ret = array('title' => i("Edit {$this->restypename}"),
		             'cont' => $cont,
		             'resid' => $imageid,
		             'data' => $data,
		             'status' => 'success');
		sendJSON($ret);
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
		if($add) {
			$this->createImage();
			return;
		}
		$data = $this->validateResourceData();
		if($data['error']) {
			$ret = array('status' => 'error', 'msg' => $data['errormsg']);
			sendJSON($ret);
			return;
		}
		$olddata = getContinuationVar('olddata');
		$imagenotes = getImageNotes($data['imageid']);
		$ownerid = getUserlistID($data['owner']);
		if(empty($data['concurrent']) || ! is_numeric($data['concurrent']))
			$data['concurrent'] = 'NULL';

		$updates = array();
		# name
		if($data['name'] != $olddata['prettyname'])
			$updates[] = "prettyname = '{$data['name']}'";
		# ownerid
		if($ownerid != $olddata['ownerid']) {
			$updates[] = "ownerid = $ownerid";
			# update newimages groups
			$this->changeOwnerPermissions($olddata['ownerid'], $ownerid, $data['imageid']);
		}
		# minram
		if($data['ram'] != $olddata['minram'])
			$updates[] = "minram = {$data['ram']}";
		# minprocnumber
		if($data['cores'] != $olddata['minprocnumber'])
			$updates[] = "minprocnumber = {$data['cores']}";
		# minprocspeed
		if($data['cpuspeed'] != $olddata['minprocspeed'])
			$updates[] = "minprocspeed = {$data['cpuspeed']}";
		# minnetwork
		if($data['networkspeed'] != $olddata['minnetwork'])
			$updates[] = "minnetwork = {$data['networkspeed']}";
		# maxconcurrent
		if($data['concurrent'] != $olddata['maxconcurrent'])
			$updates[] = "maxconcurrent = {$data['concurrent']}";
		# reloadtime
		if($data['reload'] != $olddata['reloadtime'])
			$updates[] = "reloadtime = {$data['reload']}";
		# forcheckout
		if($data['checkout'] != $olddata['forcheckout'])
			$updates[] = "forcheckout = {$data['checkout']}";
		# description
		if($data['desc'] != $olddata['description']) {
			$escdesc = mysql_real_escape_string($data['desc']);
			$updates[] = "description = '$escdesc'";
		}
		# usage
		if($data['usage'] != $olddata['usage']) {
			$escusage = mysql_real_escape_string($data['usage']);
			$updates[] = "`usage` = '$escusage'";
		}

		if(count($updates)) {
			$query = "UPDATE image SET "
			       . implode(', ', $updates)
			       . " WHERE id = {$data['imageid']}";
			doQuery($query);
		}

		# ad authentication
		if($olddata['ostype'] == 'windows') {
			if($data['adauthenabled'] != $olddata['adauthenabled']) {
				if($data['adauthenabled']) {
					$esc_baseou = mysql_real_escape_string($data['baseou']);
					$query = "INSERT INTO imageaddomain "
					       .        "(imageid, "
					       .        "addomainid, "
					       .        "baseOU) "
					       . "VALUES "
					       .        "({$data['imageid']}, "
					       .        "{$data['addomainid']}, "
					       .        "'$esc_baseou')";
					doQuery($query);
				}
				else {
					$query = "DELETE FROM imageaddomain "
					       . "WHERE imageid = {$data['imageid']}";
					doQuery($query);
				}
			}
			elseif($data['adauthenabled'] &&
			       ($data['addomainid'] != $olddata['addomainid'] ||
			       $data['baseou'] != $olddata['baseOU'])) {
				$esc_baseou = mysql_real_escape_string($data['baseou']);
				$query = "UPDATE imageaddomain "
				       . "SET addomainid = {$data['addomainid']}, "
				       .     "baseOU = '$esc_baseou' "
				       . "WHERE imageid = {$data['imageid']}";
				doQuery($query);
			}
		}

		# imagemeta
		if(empty($olddata['imagemetaid']) &&
		   ($data['checkuser'] == 0 || $data['rootaccess'] == 0 ||
		   ($olddata['ostype'] == 'windows' && $data['sethostname'] == 1) ||
		   ($olddata['ostype'] == 'linux' && $data['sethostname'] == 0))) {
			if(($olddata['ostype'] != 'windows' && $olddata['ostype'] != 'linux') ||
			   ($olddata['ostype'] == 'windows' && $data['sethostname'] == 0) ||
			   ($olddata['ostype'] == 'linux' && $data['sethostname'] == 1))
				$data['sethostname'] = 'NULL';
			$query = "INSERT INTO imagemeta "
					 .        "(checkuser, "
					 .        "rootaccess, "
					 .        "sethostname) "
					 . "VALUES ({$data['checkuser']}, "
					 .        "{$data['rootaccess']}, "
					 .        "{$data['sethostname']})";
			doQuery($query, 101);
			$qh = doQuery("SELECT LAST_INSERT_ID() FROM imagemeta", 101);
			if(! $row = mysql_fetch_row($qh))
				abort(101);
			$imagemetaid = $row[0];
			$query = "UPDATE image "
					 . "SET imagemetaid = $imagemetaid "
					 . "WHERE id = {$data['imageid']}";
			doQuery($query, 101);
		}
		elseif(! empty($olddata['imagemetaid'])) {
			if($data['checkuser'] != $olddata['checkuser'] ||
			   $data['rootaccess'] != $olddata['rootaccess'] ||
			   (($olddata['ostype'] == 'windows' || $olddata['ostype'] == 'linux') &&
			     $data['sethostname'] != $olddata['sethostname'])) {
				if(($olddata['ostype'] != 'windows' && $olddata['ostype'] != 'linux') ||
			      ($olddata['ostype'] == 'windows' && $data['sethostname'] == 0) ||
			      ($olddata['ostype'] == 'linux' && $data['sethostname'] == 1))
					$data['sethostname'] = 'NULL';
				$query = "UPDATE imagemeta "
						 . "SET checkuser = {$data['checkuser']}, "
						 .     "rootaccess = {$data['rootaccess']}, "
						 .     "sethostname = {$data['sethostname']} "
						 . "WHERE id = {$olddata['imagemetaid']}";
				doQuery($query, 101);
			}
		  checkClearImageMeta($olddata['imagemetaid'], $data['imageid']);
		}
		$args = $this->defaultGetDataArgs;
		$args['rscid'] = $data['imageid'];
		$tmp = $this->getData($args);
		$image = $tmp[$data['imageid']];
		$image['description'] = $data['desc'];
		$image['usage'] = $data['usage'];
		if(isset($imagemetaid))
			$image['imagemetaid'] = $imagemetaid;
		sendJSON(array('status' => 'success', 'data' => $image));
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn createImage()
	///
	/// \brief redirects user to clickthrough agreement page if it has not been 
	/// submitted; calls addResource to add a new image; updates request and
	/// reservation tables to put in imaging state
	///
	/////////////////////////////////////////////////////////////////////////////
	function createImage() {
		global $user, $clickThroughText;
		$fromclickthrough = getContinuationVar('fromclickthrough', 0);
		$checkpoint = getContinuationVar('checkpoint', 0);
		if($fromclickthrough)
			$data = getContinuationVar('data');
		else
			$data = $this->validateResourceData();
		if($data['error']) {
			$ret = array('status' => 'error', 'msg' => $data['errormsg']);
			sendJSON($ret);
			return;
		}
		if(! $fromclickthrough) {
			$agree = str_replace("\n", "<br>\n", sprintf($clickThroughText, ''));
			$agree = str_replace("<br>\n<br>\n", "<br>\n", $agree);
			$cdata = array('obj' => $this,
			               'data' => $data,
			               'agree' => $agree,
			               'add' => 1,
			               'checkpoint' => $checkpoint,
			               'fromclickthrough' => 1);
			$cont = addContinuationsEntry('AJsaveResource', $cdata, SECINDAY, 0, 0);
			$ret = array('status' => 'success',
			             'action' => 'clickthrough',
			             'agree' => $agree,
			             'cont' => $cont);
			sendJSON($ret);
			return;
		}

		// get extra data from base image
		$imagedata = getImages(0, $data["imageid"]);
		$data["platformid"] = $imagedata[$data["imageid"]]["platformid"];
		$data["osid"] = $imagedata[$data["imageid"]]["osid"];
		$data["ostype"] = $imagedata[$data["imageid"]]["ostype"];
		$data["basedoffrevisionid"] = $data["baserevisionid"];
		$data["reload"] = 10;
		$data["autocaptured"] = 0;

		# add the image
		if(! $imageid = $this->addResource($data)) {
			sendJSON(array('status' => 'adderror',
			               'errormsg' => i("Error encountered while trying to create new image.<br>Please contact an admin for assistance.")));
			return;
		}

		$sets = array("rs.imageid = $imageid",
		              "rs.imagerevisionid = {$this->imagerevisionid}");

		if($checkpoint)
			$sets[] = "rq.stateid = 24";
		else {
			$sets[] = "rq.stateid = 16";
			$sets[] = "rq.forimaging = 1";
		}

		$allsets = implode(', ', $sets);
		$query = "UPDATE request rq, "
		       .        "reservation rs "
		       . "SET $allsets "
		       . "WHERE rq.id = {$data['requestid']} AND "
		       .       "rq.id = rs.requestid";
		doQuery($query, 101);

		$agree = mysql_real_escape_string(getContinuationVar('agree'));
		$query = "INSERT INTO clickThroughs "
		       .        "(userid, "
		       .        "imageid, "
		       .        "imagerevisionid, "
		       .        "accepted, "
		       .        "agreement) "
		       . "VALUES "
		       .        "({$user['id']}, "
		       .        "$imageid, "
		       .        "{$this->imagerevisionid}, "
		       .        "NOW(), "
		       .        "'$agree')";
		doQuery($query, 101);

		sendJSON(array('status' => 'success', 'action' => 'add'));
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJupdateImage($requestid=0, $userid=0, $comments='', $autocaptured=0)
	///
	/// \param $requestid - required if $autocaptured = 1; id of request to be
	/// updated
	/// \param $userid - required if $autocaptured = 1; id of user updating image
	/// \param $comments - required if $autocaptured = 1; comments for image
	/// revision
	/// \param $autocaptured - required if $autocaptured = 1; 1 if calling from
	/// XMLRPCautoCapture, 0 otherwise
	///
	/// \brief handles creating a new image revision; if $autocaptured is 0,
	/// passed in arguments are ignored and obtained from continuation or user
	/// input
	///
	/////////////////////////////////////////////////////////////////////////////
	static function AJupdateImage($requestid=0, $userid=0, $comments='',
	                              $autocaptured=0) {
		global $user, $clickThroughText;
	
		if($userid == 0)
			$userid = $user['id'];

		if(! $autocaptured) {
			$imageid = getContinuationVar('imageid');
			$imageData = getImages(0, $imageid);
			if($imageData[$imageid]['ownerid'] != $userid) {
				$ret = array('status' => 'noaccess');
				sendJSON($ret);
				return 0;
			}
			$oldrevisionid = getContinuationVar('revisionid');
		}
		$fromclickthrough = getContinuationVar('fromclickthrough', 0);
		if($fromclickthrough)
			$comments = getContinuationVar('comments');
		elseif(! $autocaptured) {
			$comments = processInputVar('comments', ARG_STRING, '');
			$comments = htmlspecialchars($comments);
			if(get_magic_quotes_gpc())
				$comments = stripslashes($comments);
		}

		if(! $autocaptured)
			$requestid = getContinuationVar('requestid');

		$checkpoint = getContinuationVar('checkpoint', 0);

		if(! $autocaptured && ! $fromclickthrough) {
			$agree = str_replace("\n", "<br>\n", sprintf($clickThroughText, ''));
			$agree = str_replace("<br>\n<br>\n", "<br>\n", $agree);
			$obj = new Image();
			$cdata = array('obj' => $obj,
			               'comments' => $comments,
			               'agree' => $agree,
			               'requestid' => $requestid,
			               'imageid' => $imageid,
			               'revisionid' => $oldrevisionid,
			               'checkpoint' => $checkpoint,
			               'fromclickthrough' => 1);
			$cont = addContinuationsEntry('AJupdateImage', $cdata);
			$ret = array('status' => 'success',
			             'action' => 'clickthrough',
			             'agree' => $agree,
			             'cont' => $cont);
			sendJSON($ret);
			return;
		}
	
		if($autocaptured) {
			$data = getRequestInfo($requestid);
			if(count($data['reservations']) == 1) {
				$imageid = $data['reservations'][0]['imageid'];
				$oldrevisionid = $data['reservations'][0]['imagerevisionid'];
			}
			else {
				foreach($data["reservations"] as $res) {
					if($res["forcheckout"]) {
						$imageid = $res["imageid"];
						$oldrevisionid = $res['imagerevisionid'];
						break;
					}
				}
			}
		}
		// set the test flag on the image in the image table
		$query = "UPDATE image SET test = 1 WHERE id = $imageid";
		doQuery($query, 101);
	
		# add entry to imagerevision table
		$query = "SELECT revision, "
		       .        "imagename "
		       . "FROM imagerevision "
		       . "WHERE imageid = $imageid "
		       . "ORDER BY revision DESC "
		       . "LIMIT 1";
		$qh = doQuery($query, 101);
		$row = mysql_fetch_assoc($qh);
		$newrevision = $row['revision'] + 1;
		$newname = preg_replace("/{$row['revision']}$/", $newrevision, $row['imagename']);
		$comments = mysql_real_escape_string($comments);
		$query = "INSERT INTO imagerevision "
		       .        "(imageid, "
		       .        "revision, "
		       .        "userid, "
		       .        "datecreated, "
		       .        "deleted, "
		       .        "production, "
		       .        "comments, "
		       .        "imagename, "
		       .        "autocaptured) "
		       . "VALUES ($imageid, "
		       .        "$newrevision, "
		       .        "$userid, "
		       .        "NOW(), "
		       .        "1, "
		       .        "0, "
		       .        "'$comments', "
		       .        "'$newname', "
		       .        "$autocaptured)";
		doQuery($query, 101);
		$imagerevisionid = dbLastInsertID();
	
		# duplicate any entries in connectmethodmap for new revision
		$query = "INSERT INTO connectmethodmap "
		       . "SELECT connectmethodid, "
		       .        "OStypeid, "
		       .        "OSid, "
		       .        "$imagerevisionid, "
		       .        "disabled, "
		       .        "autoprovisioned "
		       . "FROM connectmethodmap "
		       . "WHERE imagerevisionid = $oldrevisionid";
		doQuery($query, 101);

		$sets = array("rs.imagerevisionid = $imagerevisionid");

		if($checkpoint)
			$sets[] = "rq.stateid = 24";
		else {
			$sets[] = "rq.stateid = 16";
			$sets[] = "rq.forimaging = 1";
		}
	
		# update request and reservation
		$allsets = implode(', ', $sets);
		$query = "UPDATE request rq, "
		       .        "reservation rs "
		       . "SET $allsets "
		       . "WHERE rq.id = $requestid AND "
		       .       "rq.id = rs.requestid AND "
		       .       "rs.imageid = $imageid";
		doQuery($query, 101);

		if($autocaptured)
			return 1;
	
		$agree = mysql_real_escape_string(getContinuationVar('agree'));
		$query = "INSERT INTO clickThroughs "
		       .        "(userid, "
		       .        "imageid, "
		       .        "accepted, "
		       .        "agreement) "
		       . "VALUES "
		       .        "($userid, "
		       .        "$imageid, "
		       .        "NOW(), "
		       .        "'$agree')";
		doQuery($query, 101);
	
		$return = array('status' => 'success',
		                'action' => 'update',
		                'imageid' => $imageid);
		sendJSON($return);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addResource($data)
	///
	/// \param $data - array of needed data for adding a new resource
	///
	/// \return id of new resource
	///
	/// \brief handles adding a new image and other associated data to the
	/// database
	///
	/////////////////////////////////////////////////////////////////////////////
	function addResource($data) {
		global $user;
		$data['desc'] = mysql_real_escape_string($data['desc']);
		$data['usage'] = mysql_real_escape_string($data['usage']);
		$data['comments'] = mysql_real_escape_string($data['comments']);
	
		# get architecture of base image
		$query = "SELECT i.architecture "
		       . "FROM image i, "
		       .      "imagerevision ir "
		       . "WHERE ir.imageid = i.id AND "
		       .       "ir.id = {$data['basedoffrevisionid']}";
		$qh = doQuery($query);
		$row = mysql_fetch_assoc($qh);
		$arch = $row['architecture'];
	
		$ownerdata = getUserInfo($data['owner'], 1);
		$ownerid = $ownerdata['id'];
		if(empty($data['concurrent']) || ! is_numeric($data['concurrent']))
			$data['concurrent'] = 'NULL';
		$query = "INSERT INTO image "
		       .         "(prettyname, "
		       .         "ownerid, "
		       .         "platformid, "
		       .         "OSid, "
		       .         "minram, "
		       .         "minprocnumber, "
		       .         "minprocspeed, "
		       .         "minnetwork, "
		       .         "maxconcurrent, "
		       .         "reloadtime, "
		       .         "deleted, "
		       .         "forcheckout, "
		       .         "architecture, "
		       .         "description, "
		       .         "`usage`, "
		       .         "basedoffrevisionid) "
		       . "VALUES ('{$data['name']}', "
		       .         "$ownerid, "
		       .         "{$data['platformid']}, "
		       .         "{$data['osid']}, "
		       .         "{$data['ram']}, "
		       .         "{$data['cores']}, "
		       .         "{$data['cpuspeed']}, "
		       .         "{$data['networkspeed']}, "
		       .         "{$data['concurrent']}, "
		       .         "{$data['reload']}, "
		       .         "1, "
		       .         "{$data['checkout']}, "
		       .         "'$arch', "
		       .         "'{$data['desc']}', "
		       .         "'{$data['usage']}', "
		       .         "{$data['basedoffrevisionid']})";
		doQuery($query, 205);
		$imageid = dbLastInsertID();

		# ad authentication
		if($data['adauthenabled']) {
			$esc_baseou = mysql_real_escape_string($data['baseou']);
			$query = "INSERT INTO imageaddomain "
			       .        "(imageid, "
			       .        "addomainid, "
			       .        "baseOU) "
			       . "VALUES "
			       .        "($imageid, "
			       .        "{$data['addomainid']}, "
			       .        "'$esc_baseou')";
			doQuery($query);
		}
	
		// possibly add entry to imagemeta table
		$imagemetaid = 0;
		if($data['checkuser'] == 0 ||
		   $data['rootaccess'] == 0 ||
			$data['sysprep'] == 0 ||
		   ($data['ostype'] == 'windows' && $data['sethostname'] == 1) ||
		   ($data['ostype'] == 'linux' && $data['sethostname'] == 0)) {
			if(($data['ostype'] != 'windows' && $data['ostype'] != 'linux') ||
		      ($data['ostype'] == 'windows' && $data['sethostname'] == 0) ||
		      ($data['ostype'] == 'linux' && $data['sethostname'] == 1))
				$data['sethostname'] = 'NULL';
			$query = "INSERT INTO imagemeta "
			       .        "(checkuser, "
			       .        "rootaccess, "
			       .        "sysprep, "
			       .        "sethostname) "
			       . "VALUES "
			       .        "({$data['checkuser']}, "
			       .        "{$data['rootaccess']}, "
			       .        "{$data['sysprep']}, "
			       .        "{$data['sethostname']})";
			doQuery($query, 101);
			$imagemetaid = dbLastInsertID();
		}
	
		// create name from pretty name, os, and last insert id
		$OSs = getOSList();
		$name = $OSs[$data['osid']]['name'] . "-" .
		        preg_replace('/\W/', '', $data['name']) . $imageid . "-v0";
		if($imagemetaid) {
			$query = "UPDATE image "
			       . "SET name = '$name', "
			       .     "imagemetaid = $imagemetaid "
			       . "WHERE id = $imageid";
		}
		else
			$query = "UPDATE image SET name = '$name' WHERE id = $imageid";
		doQuery($query, 208);
	
		$query = "INSERT INTO imagerevision "
		       .        "(imageid, "
		       .        "userid, "
		       .        "datecreated, "
		       .        "production, "
		       .        "imagename, "
		       .        "comments, "
		       .        "autocaptured) "
		       . "VALUES ($imageid, "
		       .        "{$user['id']}, "
		       .        "NOW(), "
		       .        "1, "
		       .        "'$name', "
		       .        "'{$data['comments']}', "
		       .        "{$data['autocaptured']})";
		doQuery($query, 101);
		$this->imagerevisionid = dbLastInsertID();
	
		// possibly add entries to connectmethodmap
		$baseconmethods = getImageConnectMethods($imageid, 0, 1);
		$baseids = array_keys($baseconmethods);
		$conmethodids = explode(',', $data['connectmethodids']);
		$adds = array_diff($conmethodids, $baseids);
		$rems = array_diff($baseids, $conmethodids);
		$vals = array();
		if(count($adds)) {
			foreach($adds as $id)
				$vals[] = "($id, $this->imagerevisionid, 0)";
		}
		if(count($rems)) {
			foreach($rems as $id)
				$vals[] = "($id, $this->imagerevisionid, 1)";
		}
		if(count($vals)) {
			$allvals = implode(',', $vals);
			$query = "INSERT INTO connectmethodmap "
			       .        "(connectmethodid, "
			       .        "imagerevisionid, "
			       .        "disabled) "
			       . "VALUES $allvals";
			doQuery($query, 101);
		}
	
		// add entry in resource table
		$query = "INSERT INTO resource "
				 .        "(resourcetypeid, "
				 .        "subid) "
				 . "VALUES (13, "
				 .         "$imageid)";
		doQuery($query, 209);
		$resourceid = dbLastInsertID();
	
		$installtype = $OSs[$data['osid']]['installtype'];
		if($installtype == 'none' ||
		   $installtype == 'partimage' ||
		   $installtype == 'kickstart')
			$virtual = 0;
		else
			$virtual = 1;
	
		$this->addImagePermissions($ownerdata, $resourceid, $virtual);
	
		return $imageid;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getRevisionHTML($imageid)
	///
	/// \param $imageid - id of an image
	///
	/// \return html
	///
	/// \brief builds HTML table for in place editing of image revision data
	///
	/////////////////////////////////////////////////////////////////////////////
	function getRevisionHTML($imageid) {
		$revisions = getImageRevisions($imageid);
		$rt = '';
		$rt .= "<h3>" . i("Revisions of this Image") . "</h3>\n";
		$rt .= "(" . i("Changes made in this section take effect immediately; you do <strong>not</strong> need to click \"Submit Changes\" to submit them.") . ")<br>\n";
		$rt .= "<table summary=\"\"><tr><td>\n";
		if(count($revisions) > 1 && isImageBlockTimeActive($imageid)) {
			$rt .= "<font color=\"red\">";
			$warn = i("WARNING: This image is part of an active block allocation. Changing the production revision of the image at this time will result in new reservations under the block allocation to have full reload times instead of a &lt; 1 minutes wait.");
			$rt .= preg_replace("/(.{1,100}([ \n]|$))/", '\1<br>', $warn);
			$rt .= "</font><br>\n";
		}
		$rt .= "<table summary=\"\" id=\"revisiontable\">\n";
		$rt .= "  <tr>\n";
		$rt .= "    <td></td>\n";
		$rt .= "    <th>" . i("Revision") . "</th>\n";
		$rt .= "    <th>" . i("Creator") . "</th>\n";
		$rt .= "    <th>" . i("Created") . "</th>\n";
		$rt .= "    <th nowrap>" . i("In Production") . "</th>\n";
		$rt .= "    <th>" . i("Comments (click to edit)") . "</th>\n";
		$rt .= "  </tr>\n";
		foreach($revisions AS $rev) {
			if($rev['deleted'] == 1)
				continue;
			$rt .= "  <tr>\n";
			$rt .= "    <td><INPUT type=checkbox\n";
			$rt .= "              id=chkrev{$rev['id']}\n";
			$rt .= "              name=chkrev[{$rev['id']}]\n";
			$rt .= "              value=1></td>\n";
			$rt .= "    <td align=center>{$rev['revision']}</td>\n";
			$rt .= "    <td>{$rev['creator']}</td>\n";
			$created = date('g:ia n/j/Y', datetimeToUnix($rev['datecreated']));
			$rt .= "    <td>$created</td>\n";
			$cdata = $this->basecdata;
			$cdata['imageid'] = $imageid;
			$cdata['revisionid'] = $rev['id'];
			$cont = addContinuationsEntry('AJupdateRevisionProduction', $cdata);
			$rt .= "    <td align=center><INPUT type=radio\n";
			$rt .= "           name=production\n";
			$rt .= "           value={$rev['id']}\n";
			$rt .= "           id=radrev{$rev['id']}\n";
			$rt .= "           onclick=\"updateRevisionProduction('$cont');\"\n";
			if($rev['production'])
				$rt .= "           checked\n";
			$rt .= "           ></td>\n";
			$cont = addContinuationsEntry('AJupdateRevisionComments', $cdata);
			$rt .= "    <td width=200px><span id=comments{$rev['id']} \n";
			$rt .= "              dojoType=\"dijit.InlineEditBox\"\n";
			$rt .= "              editor=\"dijit.form.Textarea\"\n";
			$rt .= "              onChange=\"updateRevisionComments('comments{$rev['id']}', '$cont');\"\n";
			$rt .= "              noValueIndicator=\"(empty)\">\n";
			$rt .= "        {$rev['comments']}</span></td>\n";
			$rt .= "  </tr>\n";
		}
		$rt .= "</table>\n";
		$rt .= "<div align=left>\n";
		$keys = array_keys($revisions);
		$cdata = $this->basecdata;
		$cdata['revids'] = $keys;
		$cdata['imageid'] = $imageid;
		$cont = addContinuationsEntry('AJdeleteRevisions', $cdata);
		$ids = implode(',', $keys);
		$rt .= "<button onclick=\"deleteRevisions('$cont', '$ids'); return false;\">";
		$rt .= i("Delete selected revisions") . "</button>\n";
		$rt .= "</div>\n";
		$rt .= "</td></tr></table>\n";
		return $rt;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddSubimage()
	///
	/// \brief adds a subimage to an image
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJaddSubimage() {
		$imageid = getContinuationVar('imageid');
		$adminids = getContinuationVar('adminids');
		$userimageids = getContinuationVar('userimageids');
		$subimages = getContinuationVar('subimages');
		$imagemetaid = getContinuationVar('imagemetaid');
		if(! in_array($imageid, $adminids)) {
			$arr = array('error' => 'noimageaccess',
		                'msg' => i("You do not have access to manage this image."));
			sendJSON($arr);
			return;
		}
		$newid = processInputVar('imageid', ARG_NUMERIC);
		if(! in_array($newid, $userimageids)) {
			$arr = array('error' => 'nosubimageaccess',
		                'msg' => i("You do not have access to add this subimage."));
			sendJSON($arr);
			return;
		}
		if(is_null($imagemetaid)) {
			$query = "INSERT INTO imagemeta "
			       .        "(subimages) "
			       . "VALUES (1)";
			doQuery($query, 101);
			$imagemetaid = dbLastInsertID();
			$query = "UPDATE image "
			       . "SET imagemetaid = $imagemetaid "
			       . "WHERE id = $imageid";
			doQuery($query, 101);
		}
		elseif(! count($subimages)) {
			$query = "UPDATE imagemeta "
			       . "SET subimages = 1 "
			       . "WHERE id = $imagemetaid";
			doQuery($query, 101);
		}
		$query = "INSERT INTO subimages "
		       .        "(imagemetaid, "
		       .        "imageid) "
		       . "VALUES ($imagemetaid, "
		       .        "$newid)";
		doQuery($query, 101);
		$subimages[] = $newid;
		$data = array('imageid' => $imageid,
		              'adminids' => $adminids,
		              'imagemetaid' => $imagemetaid,
		              'userimageids' => $userimageids,
		              'subimages' => $subimages,
		              'obj' => $this);
		$addcont = addContinuationsEntry('AJaddSubimage', $data, SECINDAY, 1, 0);
		$remcont = addContinuationsEntry('AJremSubimage', $data, SECINDAY, 1, 0);
		$image = getImages(0, $newid);
		$name = $image[$newid]['prettyname'];
		$arr = array('newid' => $newid,
		             'name' => $name,
		             'addcont' => $addcont,
		             'remcont' => $remcont);
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJremSubimage()
	///
	/// \brief removes subimages from an image
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJremSubimage() {
		$imageid = getContinuationVar('imageid');
		$adminids = getContinuationVar('adminids');
		$userimageids = getContinuationVar('userimageids');
		$subimages = getContinuationVar('subimages');
		$imagemetaid = getContinuationVar('imagemetaid');
		if(! in_array($imageid, $adminids)) {
			$arr = array('error' => 'noimageaccess',
		                'msg' => i("You do not have access to manage this image."));
			sendJSON($arr);
			return;
		}
		$remids = processInputVar('imageids', ARG_STRING);
		$remids = explode(',', $remids);
		foreach($remids as $id) {
			if(! is_numeric($id)) {
				$arr = array('error' => 'invalidinput',
				             'msg' => i("Non-numeric data was submitted for an image id."));
				sendJSON($arr);
				return;
			}
		}
		if(is_null($imagemetaid)) {
			$arr = array('error' => 'nullimagemetaid',
		                'msg' => i("Invalid infomation in database. Contact your system administrator."));
			sendJSON($arr);
			return;
		}
		foreach($remids as $id) {
			$query = "DELETE FROM subimages "
			       . "WHERE imagemetaid = $imagemetaid AND "
			       .       "imageid = $id "
			       . "LIMIT 1";
			doQuery($query, 101);
		}
		# check to see if any subimages left; if not, update imagemeta table
		$query = "SELECT COUNT(imageid) "
				 . "FROM subimages "
				 . "WHERE imagemetaid = $imagemetaid";
		$qh = doQuery($query, 101);
		$row = mysql_fetch_row($qh);
		if($row[0] == 0) {
			$rc = checkClearImageMeta($imagemetaid, $imageid, 'subimages');
			if($rc)
				$imagemetaid = NULL;
			else {
				$query = "UPDATE imagemeta SET subimages = 0 WHERE id = $imagemetaid";
				doQuery($query, 101);
			}
			$subimages = array();
		}
		# rebuild list of subimages
		else {
			$query = "SELECT imageid FROM subimages WHERE imagemetaid = $imagemetaid";
			$qh = doQuery($query, 101);
			$subimages = array();
			while($row = mysql_fetch_assoc($qh))
				$subimages[] = $row['imageid'];
		}
	
		$data = array('imageid' => $imageid,
		              'adminids' => $adminids,
		              'imagemetaid' => $imagemetaid,
		              'userimageids' => $userimageids,
		              'subimages' => $subimages,
		              'obj' => $this);
		$addcont = addContinuationsEntry('AJaddSubimage', $data, SECINDAY, 1, 0);
		$remcont = addContinuationsEntry('AJremSubimage', $data, SECINDAY, 1, 0);
		$arr = array('addcont' => $addcont,
		             'remcont' => $remcont);
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateResourceData()
	///
	/// \return array with these fields:\n
	/// \b name\n
	/// \b owner\n
	/// \b ram\n
	/// \b cores\n
	/// \b cpuspeed\n
	/// \b networkspeed\n
	/// \b concurrent - max concurrent allowed users (0 if unlimited)\n
	/// \b reload - estimated reload time in minutes\n
	/// \b checkout - image is available for checkout\n
	/// \b checkuser - reservations should be checked for a logged in user\n
	/// \b rootaccess\n
	/// \b sysprep - use sysprep when capturing revisions of this image\n
	/// \b connectmethodids - ids of assigned connect methods\n
	/// \b requestid - requestid associated with image capture\n
	/// \b imageid - id of base image\n
	/// \b desc - description of image\n
	/// \b usage - user usage information\n
	/// \b comments - image revision comments\n
	/// \b mode - 'add' or 'edit'\n
	/// \b error - 0 if submitted data validates; 1 if anything is invalid\n
	/// \b errormsg - if error = 1; string of error messages separated by html
	///    break tags
	///
	/// \brief validates form input from editing or adding an image
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateResourceData() {
		global $user;

		$return = array('error' => 0);

		$return["name"] = processInputVar("name", ARG_STRING);
		$return["owner"] = processInputVar("owner", ARG_STRING, "{$user["unityid"]}@{$user['affiliation']}");
		$return["ram"] = processInputVar("ram", ARG_NUMERIC, 512);
		$return["cores"] = processInputVar("cores", ARG_NUMERIC);
		$return["cpuspeed"] = processInputVar("cpuspeed", ARG_NUMERIC);
		$return["networkspeed"] = (int)processInputVar("networkspeed", ARG_NUMERIC);
		$return["concurrent"] = processInputVar("concurrent", ARG_NUMERIC, 0);
		$return["reload"] = processInputVar("reload", ARG_NUMERIC); # not in add
		$return["checkout"] = processInputVar("checkout", ARG_NUMERIC);
		$return["checkuser"] = processInputVar("checkuser", ARG_NUMERIC);
		$return["rootaccess"] = processInputVar("rootaccess", ARG_NUMERIC);
		$return["sethostname"] = processInputVar("sethostname", ARG_NUMERIC);
		$return["sysprep"] = processInputVar("sysprep", ARG_NUMERIC); # only in add
		$return["connectmethodids"] = processInputVar("connectmethodids", ARG_STRING); # only in add
		$return["adauthenabled"] = processInputVar("adauthenabled", ARG_NUMERIC);
		$return["addomainid"] = processInputVar("addomainid", ARG_NUMERIC);
		$return["baseou"] = processInputVar("baseou", ARG_STRING);

		$return['requestid'] = getContinuationVar('requestid'); # only in add
		$return["imageid"] = getContinuationVar('imageid');
		$return['baserevisionid'] = getContinuationVar('baserevisionid');

		$return["desc"] = processInputVar("desc", ARG_STRING);
		if(get_magic_quotes_gpc())
			$return["desc"] = stripslashes($return['desc']);
		$return['desc'] = preg_replace("/[\n\s]*$/", '', $return['desc']);
		$return['desc'] = preg_replace("/\r/", '', $return['desc']);
		$return['desc'] = htmlspecialchars($return['desc']);
		$return['desc'] = preg_replace("/\n/", '<br>', $return['desc']);

		$return["usage"] = processInputVar("usage", ARG_STRING);
		if(get_magic_quotes_gpc())
			$return["usage"] = stripslashes($return['usage']);
		$return['usage'] = preg_replace("/[\n\s]*$/", '', $return['usage']);
		$return['usage'] = preg_replace("/\r/", '', $return['usage']);
		$return['usage'] = htmlspecialchars($return['usage']);
		$return['usage'] = preg_replace("/\n/", '<br>', $return['usage']);

		$return["comments"] = processInputVar("imgcomments", ARG_STRING);
		if(get_magic_quotes_gpc())
			$return["comments"] = stripslashes($return['comments']);
		$return['comments'] = preg_replace("/[\n\s]*$/", '', $return['comments']);
		$return['comments'] = preg_replace("/\r/", '', $return['comments']);
		$return['comments'] = htmlspecialchars($return['comments']);
		$return['comments'] = preg_replace("/\n/", '<br>', $return['comments']);

		if($return['requestid'] != '')
			$return['mode'] = 'add';
		else
			$return['mode'] = 'edit';

		$errormsg = array();
		if(preg_match("/['\"]/", $return["name"]) ||
			strlen($return["name"]) > 60 || strlen($return["name"]) < 2) {
			$return['error'] = 1;
			$errormsg[] = i("Name must be from 2 to 60 characters and cannot contain any single (') or double (\") quotes.");
		}
		elseif(! preg_match('/^[\x20-\x7E]+$/', $return["name"])) {
			$return['error'] = 1;
			$errormsg[] = i("Name can only contain alphabets, numbers, signs, and spaces.");
		}
		else {
			if($return['mode'] == 'edit')
				$imageid = $return['imageid'];
			else
				$imageid = '';
			if($this->checkForImageName($return["name"], "long", $imageid)) {
				$return['error'] = 1;
				$errormsg[] = i("An image already exists with this name.");
			}
		}
		if($return["ram"] < 0 || $return["ram"] > 8388607) {
			$return['error'] = 1;
			$errormsg[] = i("RAM must be between 0 and 8388607");
		}
		if($return["cores"] < 0 || $return["cores"] > 255) {
			$return['error'] = 1;
			$errormsg[] = i("Cores must be between 0 and 255");
		}
		if($return["cpuspeed"] < 0 || $return["cpuspeed"] > 20000) {
			$return['error'] = 1;
			$errormsg[] = i("Processor Speed must be between 0 and 20000");
		}
		$lognetwork = log10($return['networkspeed']);
		if($lognetwork < 1 || $lognetwork > 5) {
			$return['error'] = 1;
			$errormsg[] = i("Invalid value submitted for network speed");
		}
		if((! is_numeric($return['concurrent']) && ! empty($return['concurrent'])) ||
			(is_numeric($return['concurrent']) && ($return["concurrent"] < 0 || $return["concurrent"] > 255))) {
			$return['error'] = 1;
			$errormsg[] = i("Max concurrent usage must be between 0 and 255");
		}
		if($return['mode'] == 'edit' && 
		   ($return["reload"] < 0 || $return["reload"] > 120)) {
			$return['error'] = 1;
			$errormsg[] = i("Estimated Reload Time must be between 0 and 120");
		}
		if(! validateUserid($return["owner"])) {
			$return['error'] = 1;
			$errormsg[] = i("Submitted ID is not valid");
		}
		if($return['checkout'] != 0 && $return['checkout'] != 1) {
			$return['error'] = 1;
			$errormsg[] = i("Available for Checkout must be Yes or No");
		}
		if($return['checkuser'] != 0 && $return['checkuser'] != 1) {
			$return['error'] = 1;
			$errormsg[] = i("Check for Logged in User must be Yes or No");
		}
		if($return['rootaccess'] != 0 && $return['rootaccess'] != 1) {
			$return['error'] = 1;
			$errormsg[] = i("Users Have Administrative Access must be Yes or No");
		}
		if($return['sethostname'] != 0 && $return['sethostname'] != 1) {
			$return['error'] = 1;
			$errormsg[] = i("Set Computer Hostname must be Yes or No");
		}
		if($return['mode'] == 'add' && $return['sysprep'] != 0 &&
		   $return['sysprep'] != 1) {
			$return['error'] = 1;
			$errormsg[] = i("Use Sysprep must be Yes or No");
		}
		if($return['adauthenabled'] != 0 && $return['adauthenabled'] != 1)
			$return['adauthenabled'] = 0;
		if($return['adauthenabled'] == 1) {
			$vals = getContinuationVar('addomainvals');
			$extraaddomainid = getContinuationVar('extraaddomainid', 0);
			$extraaddomainou = getContinuationVar('extraaddomainou', '');
			if(! array_key_exists($return['addomainid'], $vals) &&
			   $return['addomainid'] != $extraaddomainid) {
				$return['error'] = 1;
				$errormsg[] = i("Invalid AD Domain submitted");
			}
			if($extraaddomainid && $return['addomainid'] == $extraaddomainid &&
				$return['baseou'] != $extraaddomainou) {
				$return['error'] = 1;
				$errormsg[] = i("Base OU cannot be changed for the selected AD Domain");
			}
			elseif(! preg_match('/^([Oo][Uu])=[^,]+(,([Oo][Uu])=[^,]+)*$/', $return['baseou'])) {
				$return['error'] = 1;
				$errormsg[] = i("Invalid Base OU submitted, must start with OU=");
			}
			if(preg_match('/DC=.+(,DC=.+)*$/', $return['baseou'])) {
				$return['error'] = 1;
				$errormsg[] = i("Base OU must not contain DC= components");
			}
		}
		else {
			$return['addomainid'] = 0;
			$return['baseou'] = NULL;
		}
		if(empty($return['desc'])) {
			$return['error'] = 1;
			$errormsg[] = i("You must include a description of the image") . "<br>";
		}
		if($return['mode'] == 'add') {
			if(! preg_match('/^[,0-9]+$/', $return['connectmethodids'])) {
				$tmp = getImageConnectMethods($return['imageid'],
				         getContinuationVar('baserevisionid', 0));
				$return['connectmethodids'] = implode(',', array_keys($tmp));
			}
			else {
				$conmethods = getConnectMethods($return['imageid']);
				$ids = array();
				foreach(explode(',', $return['connectmethodids']) as $id) {
					if(array_key_exists($id, $conmethods))
						$ids[$id] = 1;
				}
				if(empty($ids))
					$ids = getImageConnectMethods($return['imageid'],
					         getContinuationVar('baserevisionid', 0));
				$return['connectmethodids'] = implode(',', array_keys($ids));
			}
		}

		if($return['error'])
			$return['errormsg'] = implode('<br>', $errormsg);
		return $return;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkForImageName($name, $longshort, $id)
	///
	/// \param $name - the name of an image
	/// \param $longshort - "long" for long/pretty name, "short" for short/name
	/// \param $id - id of an image to ignore
	///
	/// \return 1 if $name is already in the image table, 0 if not
	///
	/// \brief checks for $name being in the image table except for $id
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkForImageName($name, $longshort, $id) {
		if($longshort == "long")
			$field = "prettyname";
		else
			$field = "name";
		$query = "SELECT id FROM image "
				 . "WHERE $field = '$name'";
		if(! empty($id))
			$query .= " AND id != $id";
		$qh = doQuery($query, 101);
		if(mysql_num_rows($qh))
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addImagePermissions($ownerdata, $resourceid, $virtual)
	///
	/// \param $ownerdata - array of data returned from getUserInfo for the owner
	/// of the image
	/// \param $resourceid - id from resource table for the image
	/// \param $virtual - (bool) 0 if bare metal image, 1 if virtual
	///
	/// \brief sets up permissions, grouping, and mapping for the owner of the
	/// image to be able to make a reservation for it
	///
	/////////////////////////////////////////////////////////////////////////////
	function addImagePermissions($ownerdata, $resourceid, $virtual) {
		$ownerid = $ownerdata['id'];
		// create new node if it does not exist
		if($virtual)
			$nodename = 'newvmimages';
		else
			$nodename = 'newimages';
		$query = "SELECT id "
		        . "FROM privnode "
		        . "WHERE name = '$nodename' AND "
		        .       "parent = 3";
		$qh = doQuery($query, 101);
		if(! $row = mysql_fetch_assoc($qh)) {
			$query2 = "INSERT INTO privnode "
			        .        "(parent, "
			        .        "name) "
			        . "VALUES "
			        .        "(3, "
			        .        "'$nodename')";
			doQuery($query2, 101);
			$qh = doQuery($query, 101);
			$row = mysql_fetch_assoc($qh);
		}
		$parent = $row['id'];
		$query = "SELECT id "
		        . "FROM privnode "
		        . "WHERE name = '{$ownerdata['login']}-$ownerid' AND "
		        .       "parent = $parent";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh))
			$newnode = $row['id'];
		else {
			$query = "INSERT INTO privnode "
			       .        "(parent, name) "
			       . "VALUES ($parent, '{$ownerdata['login']}-$ownerid')";
			doQuery($query, 101);
			$qh = doQuery("SELECT LAST_INSERT_ID() FROM privnode", 101);
			$row = mysql_fetch_row($qh);
			$newnode = $row[0];
		}
	
		// give user imageCheckOut and imageAdmin at new node
		$newprivs = array('imageCheckOut', 'imageAdmin');
		updateUserOrGroupPrivs($ownerid, $newnode, $newprivs, array(), 'user');
	
		// create new image group if it does not exist
		$query = "SELECT id "
		        . "FROM usergroup "
		        . "WHERE name = 'manageNewImages'";
		$qh = doQuery($query, 101);
		$row = mysql_fetch_assoc($qh);
		$ownergroupid = $row['id'];
		if($virtual)
			$prefix = 'newvmimages';
		else
			$prefix = 'newimages';
		$query = "SELECT id "
		       . "FROM resourcegroup "
		       . "WHERE name = '$prefix-{$ownerdata['login']}-$ownerid' AND "
		       .       "ownerusergroupid = $ownergroupid AND "
		       .       "resourcetypeid = 13";
		$qh = doQuery($query, 101);
		if($row = mysql_fetch_assoc($qh))
			$resourcegroupid = $row['id'];
		else {
			$query = "INSERT INTO resourcegroup "
			       .         "(name, "
			       .         "ownerusergroupid, "
			       .         "resourcetypeid) "
			       . "VALUES ('$prefix-{$ownerdata['login']}-$ownerid', "
			       .         "$ownergroupid, "
			       .         "13)";
			doQuery($query, 305);
			$qh = doQuery("SELECT LAST_INSERT_ID() FROM resourcegroup", 101);
			$row = mysql_fetch_row($qh);
			$resourcegroupid = $row[0];
	
			// map group to newimages/newvmimages comp group
			if($virtual)
				$rgroupname = 'newvmimages';
			else
				$rgroupname = 'newimages';
			$query = "SELECT id "
			       . "FROM resourcegroup "
			       . "WHERE name = '$rgroupname' AND "
			       .       "resourcetypeid = 12";
			$qh = doQuery($query, 101);
			$row = mysql_fetch_assoc($qh);
			$compResGrpid = $row['id'];
			$query = "INSERT INTO resourcemap "
			       .        "(resourcegroupid1, "
			       .        "resourcetypeid1, "
			       .        "resourcegroupid2, "
			       .        "resourcetypeid2) "
			       . "VALUES ($resourcegroupid, "
			       .         "13, "
			       .         "$compResGrpid, "
			       .         "12)";
			doQuery($query, 101);
		}
	
		// make image group available at new node
		$adds = array('available', 'administer');
		if($virtual)
			updateResourcePrivs("image/newvmimages-{$ownerdata['login']}-$ownerid", $newnode, $adds, array());
		else
			updateResourcePrivs("image/newimages-{$ownerdata['login']}-$ownerid", $newnode, $adds, array());
	
		// add image to image group
		$query = "INSERT IGNORE INTO resourcegroupmembers "
		       . "(resourceid, resourcegroupid) "
		       . "VALUES ($resourceid, $resourcegroupid)";
		doQuery($query, 101);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn changeImagePermissions($ownerdata, $resourceid, $virtual)
	///
	/// \param $ownerdata - array of data returned from getUserInfo for the owner
	/// of the image
	/// \param $resourceid - id from resource table for the image
	/// \param $virtual - (bool) 0 if bare metal image, 1 if virtual
	///
	/// \brief sets up permissions, grouping, and mapping for the owner of the
	/// image to be able to make a reservation for it
	///
	/////////////////////////////////////////////////////////////////////////////
	function changeOwnerPermissions($oldownerid, $newownerid, $imageid) {
		# determine if currently in newimage group
		$query = "SELECT id "
		       . "FROM resource "
		       . "WHERE resourcetypeid = 13 AND "
		       .       "subid = $imageid";
		$qh = doQuery($query);
		if(! ($row = mysql_fetch_assoc($qh)))
			return;
		$resid = $row['id'];
		$olduserdata = getUserInfo($oldownerid, 1, 1);
		$oldgroups = "'newvmimages-{$olduserdata['login']}-$oldownerid',"
		           . "'newimages-{$olduserdata['login']}-$oldownerid'";
		$query = "SELECT rg.name, "
		       .        "rg.id "
		       . "FROM resourcegroup rg, "
		       .      "resourcegroupmembers rgm "
		       . "WHERE rgm.resourceid = $resid AND "
		       .       "rgm.resourcegroupid = rg.id AND "
		       .       "rg.name IN ($oldgroups)";
		$qh = doQuery($query);
		if(! ($row = mysql_fetch_assoc($qh)))
			return;
		$oldgroup = $row['name'];
		$oldgroupid = $row['id'];
		if(preg_match('/^newimages/', $oldgroup))
			$virtual = 0;
		else
			$virtual = 1;
		# call addImagePermissions for new owner
		$newuserdata = getUserInfo($newownerid, 1, 1);
		$this->addImagePermissions($newuserdata, $resid, $virtual);

		# remove from old owner newimages group
		$query = "DELETE FROM resourcegroupmembers "
		       . "WHERE resourcegroupid = $oldgroupid AND "
		       .       "resourceid = $resid";
		doQuery($query);

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . 'Admin'), array('manageGroup'), 1, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . 'Admin'), array('manageGroup'), 1, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn jsonImageConnectMethods()
	///
	/// \brief gets list of connect methods used for specified image and sends
	/// them in json format
	///
	/////////////////////////////////////////////////////////////////////////////
	function jsonImageConnectMethods() {
		$imageid = getContinuationVar('imageid');
		$newimage = getContinuationVar('newimage');
		$revid = processInputVar('revid', ARG_NUMERIC, 0);
		if($revid != 0) {
			$revids = getContinuationVar('revids');
			if(! in_array($revid, $revids))
				$revid = getProductionRevisionid($imageid);
		}
		if($newimage)
			$curmethods = getContinuationVar('curmethods');
		else
			$curmethods = getImageConnectMethods($imageid, $revid);
		$methods = getConnectMethods($imageid);
		$items = array();
		foreach($methods as $id => $method) {
			if(array_key_exists($id, $curmethods))
				$active = 1;
			else
				$active = 0;
			$items[] = "{name:'$id', "
			         .  "display:'{$method['description']}', "
			         .  "autoprovisioned:'{$method['autoprovisioned']}', "
			         .  "active:$active}";
		}
		$data = implode(',', $items);
		header('Content-Type: text/json; charset=utf-8');
		$data = "{} && {label:'display',identifier:'name',items:[$data]}";
		print $data;
	}
	
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddImageConnectMethod()
	///
	/// \brief adds a subimage to an image
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJaddImageConnectMethod() {
		$imageid = getContinuationVar('imageid');
		$methods = getContinuationVar('methods');
		$revids = getContinuationVar('revids');
		$curmethods = getImageConnectMethods($imageid);
		$newid = processInputVar('newid', ARG_NUMERIC);
		$revid = processInputVar('revid', ARG_NUMERIC);
		$newimage = getContinuationVar('newimage');
		if(! array_key_exists($newid, $methods)) {
			$arr = array('error' => 'invalidmethod',
		                'msg' => i("Invalid method submitted."));
			sendJSON($arr);
			return;
		}
		if($revid != 0 && ! in_array($revid, $revids)) {
			$arr = array('error' => 'invalidrevision',
		                'msg' => i("Invalid revision id submitted."));
			sendJSON($arr);
			return;
		}
		if(! $newimage) {
			if($revid == 0)
				$revid = getProductionRevisionid($imageid);
			# delete any current entries for method and image (including disabled)
			$query = "DELETE FROM connectmethodmap "
			       . "WHERE imagerevisionid = $revid AND "
			       .       "connectmethodid = $newid AND "
			       .       "autoprovisioned IS NULL";
			doQuery($query, 101);
		
			# check to see if enabled for OStype or OS
			$query = "SELECT cm.connectmethodid "
			       . "FROM connectmethodmap cm, "
			       .      "image i "
			       . "LEFT JOIN OS o ON (o.id = i.OSid) "
			       . "LEFT JOIN OStype ot ON (ot.name = o.type) "
			       . "WHERE i.id = $imageid AND "
			       .       "cm.autoprovisioned IS NULL AND "
			       .       "cm.connectmethodid = $newid AND "
			       .       "cm.disabled = 0 AND "
			       .       "(cm.OStypeid = ot.id OR "
			       .        "cm.OSid = o.id)";
			$qh = doQuery($query, 101);
			if(! (mysql_num_rows($qh))) {
				# not enabled, add entry for method and image revision
				$query = "INSERT INTO connectmethodmap "
				       .        "(connectmethodid, "
				       .        "imagerevisionid, "
				       .        "disabled) "
				       . "VALUES "
				       .        "($newid, "
				       .        "$revid, "
				       .        "0)";
				doQuery($query, 101);
			}
		}
	
		#   return success
		$subimages[] = $newid;
		$cdata = $this->basecdata;
		$cdata['imageid'] = $imageid;
		$cdata['methods'] = $methods;
		$cdata['revids'] = $revids;
		$cdata['newimage'] = $newimage;
		$addcont = addContinuationsEntry('AJaddImageConnectMethod', $cdata, 3600, 1, 0);
		$remcont = addContinuationsEntry('AJremImageConnectMethod', $cdata, 3600, 1, 0);
		$name = $methods[$newid]['description'];
		$arr = array('newid' => $newid,
		             'name' => $name,
		             'addcont' => $addcont,
		             'remcont' => $remcont);
		sendJSON($arr);
		$key = getKey(array('getImageConnectMethods', (int)$imageid, (int)$revid));
		if(array_key_exists($key, $_SESSION['usersessiondata']))
			unset($_SESSION['usersessiondata'][$key]);
		$key = getKey(array('getImageConnectMethods', (int)$imageid, 0));
		if(array_key_exists($key, $_SESSION['usersessiondata']))
			unset($_SESSION['usersessiondata'][$key]);
	}
	
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJremImageConnectMethod()
	///
	/// \brief removes subimages from an image
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJremImageConnectMethod() {
		$imageid = getContinuationVar('imageid');
		$methods = getContinuationVar('methods');
		$revids = getContinuationVar('revids');
		$curmethods = getImageConnectMethods($imageid);
		$remidlist = mysql_real_escape_string(processInputVar('ids', ARG_STRING));
		$remids = explode(',', $remidlist);
		$revid = processInputVar('revid', ARG_NUMERIC);
		$newimage = getContinuationVar('newimage');
		foreach($remids as $id) {
			if(! is_numeric($id)) {
				$arr = array('error' => 'invalidinput',
				             'msg' => i("Non-numeric data was submitted for a connection method id."));
				sendJSON($arr);
				return;
			}
		}
		if($revid != 0 && ! in_array($revid, $revids)) {
			$arr = array('error' => 'invalidrevision',
		                'msg' => i("Invalid revision id submitted."));
			sendJSON($arr);
			return;
		}
		if(! $newimage) {
			if($revid == 0)
				$revid = getProductionRevisionid($imageid);
			# delete any current entries for method and image
			$query = "DELETE FROM connectmethodmap "
			       . "WHERE imagerevisionid = $revid AND "
			       .       "connectmethodid IN ($remidlist) AND "
			       .       "autoprovisioned IS NULL";
			doQuery($query, 101);
			# query to see if enabled for OStype or OS
			$insvals = array();
			foreach($remids as $id) {
				$query = "SELECT cm.connectmethodid "
				       . "FROM connectmethodmap cm, "
				       .      "image i "
				       . "LEFT JOIN OS o ON (o.id = i.OSid) "
				       . "LEFT JOIN OStype ot ON (ot.name = o.type) "
				       . "WHERE i.id = $imageid AND "
				       .       "cm.autoprovisioned IS NULL AND "
				       .       "cm.connectmethodid = $id AND "
				       .       "cm.disabled = 0 AND "
				       .       "(cm.OStypeid = ot.id OR "
				       .        "cm.OSid = o.id)";
				$qh = doQuery($query, 101);
				if(mysql_num_rows($qh))
					# if so, add disabled entry for image revision and method
					$insvals[] = "($id, $revid, 1)";
			}
			if(count($insvals)) {
				$allinsvals = implode(',', $insvals);
				$query = "INSERT INTO connectmethodmap "
				       .        "(connectmethodid, " 
				       .        "imagerevisionid, "
				       .        "disabled) "
				       . "VALUES $allinsvals";
				doQuery($query, 101);
			}
		}
	
		$cdata = $this->basecdata;
		$cdata['imageid'] = $imageid;
		$cdata['methods'] = $methods;
		$cdata['revids'] = $revids;
		$cdata['newimage'] = $newimage;
		$addcont = addContinuationsEntry('AJaddImageConnectMethod', $cdata, 3600, 1, 0);
		$remcont = addContinuationsEntry('AJremImageConnectMethod', $cdata, 3600, 1, 0);
		$arr = array('addcont' => $addcont,
		             'remcont' => $remcont);
		sendJSON($arr);
		$key = getKey(array('getImageConnectMethods', (int)$imageid, (int)$revid));
		if(array_key_exists($key, $_SESSION['usersessiondata']))
			unset($_SESSION['usersessiondata'][$key]);
		$key = getKey(array('getImageConnectMethods', (int)$imageid, 0));
		if(array_key_exists($key, $_SESSION['usersessiondata']))
			unset($_SESSION['usersessiondata'][$key]);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJupdateRevisionComments()
	///
	/// \brief updates the comments for a revision
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJupdateRevisionComments() {
		$imageid = getContinuationVar('imageid');
		$revisionid = getContinuationVar('revisionid');
		$comments = processInputVar('comments', ARG_STRING);
		$comments = htmlspecialchars($comments);
		if(get_magic_quotes_gpc())
			$comments = stripslashes($comments);
		$comments = mysql_real_escape_string($comments);
		$query = "UPDATE imagerevision "
		       . "SET comments = '$comments' "
		       . "WHERE id = $revisionid";
		doQuery($query, 101);
		$arr = array('comments' => $comments, 'id' => $revisionid);
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJupdateRevisionProduction()
	///
	/// \brief updates which revision is set as the one in production
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJupdateRevisionProduction() {
		$imageid = getContinuationVar('imageid');
		$revisionid = getContinuationVar('revisionid');
		$query = "UPDATE imagerevision "
		       . "SET production = 0 "
		       . "WHERE imageid = $imageid";
		doQuery($query, 101);
		$query = "UPDATE imagerevision "
		       . "SET production = 1 "
		       . "WHERE id = $revisionid";
		doQuery($query, 101);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJdeleteRevisions()
	///
	/// \brief sets deleted flag for submitted revisions
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJdeleteRevisions() {
		$revids = getContinuationVar('revids');
		$imageid = getContinuationVar('imageid');
		$checkedids = processInputVar('checkedids', ARG_STRING);
		$ids = explode(',', $checkedids);
		if(empty($ids)) {
			sendJSON(array());
			return;
		}
		foreach($ids as $id) {
			if(! is_numeric($id) || ! in_array($id, $revids)) {
				sendJSON(array());
				return;
			}
		}
		$query = "SELECT DISTINCT ir.revision "
		       . "FROM request rq, "
		       .      "reservation rs, "
		       .      "imagerevision ir "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.imagerevisionid = ir.id AND "
		       .       "rs.imagerevisionid IN ($checkedids) AND "
		       .       "rq.stateid NOT IN (1, 5, 11, 12)";
		$qh = doQuery($query);
		if(mysql_num_rows($qh)) {
			$inuseids = array();
			while($row = mysql_fetch_assoc($qh))
				$inuseids[] = $row['revision'];
			$inuseids = implode(',', $inuseids);
			$rc = array('status' => 'error',
			            'msg' => i("The following revisions are in use and cannot be deleted at this time:") . " $inuseids");
			sendJSON($rc);
			return;
		}
		$query = "UPDATE imagerevision "
		       . "SET deleted = 1, "
		       .     "datedeleted = NOW() "
		       . "WHERE id IN ($checkedids) "
		       .   "AND production != 1";
		doQuery($query, 101);
		$html = $this->getRevisionHTML($imageid);
		$arr = array('html' => $html);
		sendJSON($arr);
	}
}
?>
