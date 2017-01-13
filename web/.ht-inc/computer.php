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
/// \class Computer
///
/// \brief extends Resource class to add things specific to resources of the
/// computer type
///
////////////////////////////////////////////////////////////////////////////////
class Computer extends Resource {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief calls parent constructor; initializes things for Computer class
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->restype = 'computer';
		$this->restypename = 'Computer';
		$this->namefield = 'hostname';
		$this->defaultGetDataArgs = array('sort' => 0,
		                                  'includedeleted' => 0,
		                                  'rscid' => '');
		$this->basecdata['obj'] = $this;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getData($args)
	///
	/// \param $args - array of arguments that determine what data gets returned;
	/// must include:\n
	/// \param $sort - (optional) 1 to sort computers; 0 not to
	/// \b includedeleted - 0 or 1; include deleted images\n
	/// \b rscid - only return data for resource with this id; pass 0 for all
	/// (from computer table)
	///
	/// \return array of data as returned from getImages
	///
	/// \brief wrapper for calling getImages
	///
	/////////////////////////////////////////////////////////////////////////////
	function getData($args) {
		return getComputers($args['sort'], $args['includedeleted'], $args['rscid']);
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
			case 'currentimg':
			case 'nextimg':
				$w = 17;
				break;
			case 'notes':
				$w = 14;
				break;
			case 'IPaddress':
			case 'privateIPaddress':
			case 'natpublicIPaddress':
			case 'natinternalIPaddress':
				$w = 8;
				break;
			case 'eth0macaddress':
			case 'eth1macaddress':
				$w = 8.5;
				break;
			case 'procnumber':
				$w = 3.5;
				break;
			case 'imagerevision':
			case 'ram':
				$w = 4.5;
				break;
			case 'vmhost':
			case 'nathost':
				$w = 8;
				break;
			case 'type':
				$w = 7;
				break;
			case 'location':
				$w = 9;
				break;
			case 'predictivemodule':
				$w = 10;
				break;
			case 'provisioning':
				$w = 11;
				break;
			case 'owner':
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
			case 'currentimg':
				return 'Current Image';
			case 'imagerevision':
				return 'Image Revision';
			case 'nextimg':
				return 'Next Image';
			case 'ram':
				return 'RAM';
			case 'procnumber':
				return 'Cores';
			case 'procspeed':
				return 'Processor speed';
			case 'network':
				return 'Network speed';
			case 'IPaddress':
				return 'Public IP Address';
			case 'privateIPaddress':
				return 'Private IP Address';
			case 'eth0macaddress':
				return 'Private MAC Address';
			case 'eth1macaddress':
				return 'Public MAC Address';
			case 'vmhost':
				return 'VM Host';
			case 'provisioning':
				return 'Provisioning Engine';
			case 'predictivemodule':
				return 'Predictive Loading Module';
			case 'natenabled':
				return 'Connect Using NAT';
			case 'nathost':
				return 'NAT Host';
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
	/// \fn extraSelectAdminOptions()
	///
	/// \return html
	///
	/// \brief generates HTML for option to create/update an image
	///
	/////////////////////////////////////////////////////////////////////////////
	function extraSelectAdminOptions() {
		$h = '';
		$h .= "<br>(Computer Utilities are now incorporated into Edit Computer ";
		$h .= "Profiles)<br>\n";
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn extraResourceFilters()
	///
	/// \return html
	///
	/// \brief generates HTML for computer utilities drop down and filtering by
	/// computer group
	///
	/////////////////////////////////////////////////////////////////////////////
	function extraResourceFilters() {
		$h = '';

		# selected items menu
		$h .= "<div dojoType=\"dijit.form.DropDownButton\">\n";
		$h .= "<span>" . i("Actions for selected computers") . "</span>\n";
		$h .= "<div dojoType=\"dijit.Menu\" id=\"actionmenu\">\n";

		# change NAT
		$h .= "  <div dojoType=\"dijit.PopupMenuItem\">\n";
		$h .= "    <span>Change NAT</span>\n";
		$h .= "    <div dojoType=\"dijit.layout.ContentPane\"\n";
		$h .= "         style=\"background-color: white; padding: 5px; border: 1px solid black;\">\n";
		$extra = array('onChange' => "toggleNAT('newnatenabled', 'newnathostid');");
		$h .= labeledFormItem('newnatenabled', i('Connect Using NAT'), 'check', '', '', '1', '', '', $extra);
		$nathosts = getNAThosts(0, 1);
		$disabled = array('disabled' => 'true');
		$h .= labeledFormItem('newnathostid', i('NAT Host'), 'select', $nathosts,
		                      '', '', '', '', $disabled);
		$cdata = $this->basecdata;
		$cont = addContinuationsEntry('AJcompNATchange', $cdata);
		$h .= "      <input type=\"hidden\" id=\"natchangecont\" value=\"$cont\"><br>\n";
		$h .= dijitButton('newnathostbtn', 'Confirm NAT Change', 'confirmNATchange();', 0);
		$h .= "    </div>\n";
		$h .= "  </div>\n";

		# change predictive loading module
		$premodules = getPredictiveModules();
		$h .= "  <div dojoType=\"dijit.PopupMenuItem\">\n";
		$h .= "    <span>Change Predictive Loading Module</span>\n";
		$h .= "    <div dojoType=\"dijit.layout.ContentPane\"\n";
		$h .= "         style=\"background-color: white; padding: 5px; border: 1px solid black;\">\n";
		$h .= "      Change Predictive Loading Module to:<br>\n";
		$h .= selectInputAutoDijitHTML('', $premodules, 'newpredictivemoduleid');
		$cdata = $this->basecdata;
		$cont = addContinuationsEntry('AJcompPredictiveModuleChange', $cdata);
		$h .= "      <input type=\"hidden\" id=\"predictivemodulechangecont\" value=\"$cont\"><br>\n";
		$h .= dijitButton('', 'Confirm Predictive Loading Module Change', 'confirmPredictiveModuleChange();', 0);
		$h .= "    </div>\n";
		$h .= "  </div>\n";

		# change provisioning engine
		$provisioning = getProvisioning();
		$h .= "  <div dojoType=\"dijit.PopupMenuItem\">\n";
		$h .= "    <span>Change Provisioning Engine</span>\n";
		$h .= "    <div dojoType=\"dijit.layout.ContentPane\"\n";
		$h .= "         style=\"background-color: white; padding: 5px; border: 1px solid black;\">\n";
		$h .= "      Change Provisioning Engine to:<br>\n";
		$h .= selectInputAutoDijitHTML('', $provisioning, 'newprovisioningid');
		$cdata = $this->basecdata;
		$cont = addContinuationsEntry('AJcompProvisioningChange', $cdata);
		$h .= "      <input type=\"hidden\" id=\"provisioningchangecont\" value=\"$cont\"><br>\n";
		$h .= dijitButton('', 'Confirm Provisioning Engine Change', 'confirmProvisioningChange();', 0);
		$h .= "    </div>\n";
		$h .= "  </div>\n";

		# change schedule
		$resources = getUserResources(array("scheduleAdmin"), array("manageGroup"));
		if(count($resources['schedule'])) {
			$h .= "  <div dojoType=\"dijit.PopupMenuItem\">\n";
			$h .= "    <span>Change Schedule</span>\n";
			$h .= "    <div dojoType=\"dijit.layout.ContentPane\"\n";
			$h .= "         style=\"background-color: white; padding: 5px; border: 1px solid black;\">\n";
			$h .= "      Change schedule to:<br>\n";
			$h .= selectInputAutoDijitHTML('', $resources['schedule'], 'newscheduleid');
			$cont = addContinuationsEntry('AJcompScheduleChange', $this->basecdata);
			$h .= "      <input type=\"hidden\" id=\"schedulecont\" value=\"$cont\"><br>\n";
			$h .= dijitButton('', 'Confirm Schedule Change', 'confirmScheduleChange();', 0);
			$h .= "    </div>\n";
			$h .= "  </div>\n";
		}

		# change state
		$states = array("2" => "available",
		                "23" => "hpc",
		                "10" => "maintenance",
		                "20" => "convert to vmhostinuse");
		$h .= "  <div dojoType=\"dijit.PopupMenuItem\">\n";
		$h .= "    <span>Change State</span>\n";
		$h .= "    <div dojoType=\"dijit.layout.ContentPane\"\n";
		$h .= "         style=\"background-color: white; padding: 5px; border: 1px solid black;\">\n";
		$h .= "      Change state to:<br>\n";
		$h .= selectInputAutoDijitHTML('', $states, 'newstateid');
		$cdata = $this->basecdata;
		$cdata['states'] = $states;
		$cont = addContinuationsEntry('AJcompStateChange', $cdata);
		$h .= "      <input type=\"hidden\" id=\"statechangecont\" value=\"$cont\"><br>\n";
		$h .= dijitButton('', 'Confirm State Change', 'confirmStateChange();', 0);
		$h .= "    </div>\n";
		$h .= "  </div>\n";

		# delete
		$h .= "  <div dojoType=\"dijit.MenuItem\"\n";
		$h .= "       onClick=\"confirmDelete\">\n";
		$h .= "    Delete Computers\n";
		$cont = addContinuationsEntry('AJdeleteComputers', $this->basecdata);
		$h .= "      <input type=\"hidden\" id=\"deletecont\" value=\"$cont\"><br>\n";
		$h .= "  </div>\n";

		# generate /etc/hosts data
		$h .= "  <div dojoType=\"dijit.MenuItem\"\n";
		$h .= "       onClick=\"hostsData\">\n";
		$h .= "    Generate /etc/hosts Data\n";
		$cont = addContinuationsEntry('AJhostsData', $this->basecdata);
		$h .= "      <input type=\"hidden\" id=\"hostsdatacont\" value=\"$cont\"><br>\n";
		$h .= "  </div>\n";

		# generate private dhcpd data
		$h .= "  <div dojoType=\"dijit.PopupMenuItem\">\n";
		$h .= "    <span>Generate Private dhcpd Data</span>\n";
		$h .= "    <div dojoType=\"dijit.layout.ContentPane\"\n";
		$h .= "         style=\"background-color: white; padding: 5px; border: 1px solid black;\">\n";
		$h .= "      Enter the Management Node Private IP Address:<br>\n";
		$h .= "      <input type=\"text\" dojoType=\"dijit.form.TextBox\" id=\"mnprivipaddr\" ";
		$h .= "required=\"false\"><br><br>\n";
		$h .= "      Select which NIC is used for the Private interface:<br>\n";
		$h .= "      <input type=\"radio\" name=\"prnic\" value=\"eth0\" id=\"preth0rdo\" ";
		$h .= "checked=\"checked\"><label for=\"eth0rdo\">eth0</label><br>\n";
		$h .= "      <input type=\"radio\" name=\"prnic\" value=\"eth1\" id=\"preth1rdo\">";
		$h .= "<label for=\"eth1rdo\">eth1</label><br>\n";
		$h .= dijitButton('', 'Generate Data', "generateDHCPdata('private');", 0);
		$cont = addContinuationsEntry('AJgenerateDHCPdata', $this->basecdata);
		$h .= "      <input type=\"hidden\" id=\"privatedhcpcont\" value=\"$cont\">\n";
		$h .= "    </div>\n";
		$h .= "  </div>\n";

		# generate public dhcpd data
		$h .= "  <div dojoType=\"dijit.PopupMenuItem\">\n";
		$h .= "    <span>Generate Public dhcpd Data</span>\n";
		$h .= "    <div dojoType=\"dijit.layout.ContentPane\"\n";
		$h .= "         style=\"background-color: white; padding: 5px; border: 1px solid black;\">\n";
		$h .= "      Select which NIC is used for the Public interface:<br>\n";
		$h .= "      <input type=\"radio\" name=\"punic\" value=\"eth0\" id=\"pueth0rdo\">";
		$h .= "<label for=\"eth0rdo\">eth0</label><br>\n";
		$h .= "      <input type=\"radio\" name=\"punic\" value=\"eth1\" id=\"pueth1rdo\" ";
		$h .= "checked=\"checked\"><label for=\"eth1rdo\">eth1</label><br>\n";
		$h .= dijitButton('', 'Generate Data', "generateDHCPdata('public');", 0);
		$h .= "      <input type=\"hidden\" id=\"publicdhcpcont\" value=\"$cont\">\n"; # use previous continuation
		$h .= "    </div>\n";
		$h .= "  </div>\n";

		# reload
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
		if(count($resources['image'])) {
			$h .= "  <div dojoType=\"dijit.PopupMenuItem\">\n";
			$h .= "    <span>Reload with an Image</span>\n";
			$h .= "    <div dojoType=\"dijit.layout.ContentPane\"\n";
			$h .= "         style=\"background-color: white; padding: 5px; border: 1px solid black;\">\n";
			$h .= "      Reload computers with the following image:<br>\n";
			$extra = 'autoComplete="false"';
			$h .= selectInputAutoDijitHTML('', $resources['image'], 'reloadimageid', $extra);
			$cont = addContinuationsEntry('AJreloadComputers', $this->basecdata);
			$h .= "      <input type=\"hidden\" id=\"reloadcont\" value=\"$cont\"><br>\n";
			$h .= dijitButton('', 'Confirm Reload Computers', 'confirmReload();', 0);
			$h .= "    </div>\n";
			$h .= "  </div>\n";
		}

		# show reservations
		$h .= "  <div dojoType=\"dijit.MenuItem\"\n";
		$h .= "       onClick=\"showReservations\">\n";
		$h .= "    Reservation Information\n";
		$cont = addContinuationsEntry('AJshowReservations', $this->basecdata);
		$h .= "      <input type=\"hidden\" id=\"showreservationscont\" value=\"$cont\"><br>\n";
		$h .= "  </div>\n";

		# show reservation history
		$h .= "  <div dojoType=\"dijit.MenuItem\"\n";
		$h .= "       onClick=\"showReservationHistory\">\n";
		$h .= "    Reservation History\n";
		$cont = addContinuationsEntry('AJshowReservationHistory', $this->basecdata);
		$h .= "      <input type=\"hidden\" id=\"showreservationhistorycont\" value=\"$cont\"><br>\n";
		$h .= "  </div>\n";

		$h .= "</div>\n"; # close Menu
		$h .= "</div>\n"; # close DropDownButton

		# computer groups
		$tmp = getUserResources(array($this->restype . 'Admin'), array('manageGroup'), 1);
		$groups = $tmp[$this->restype];
		$cont = addContinuationsEntry('AJfilterCompGroups', $this->basecdata);
		$h .= "<input type=\"hidden\" id=\"filtercompgroupscont\" value=\"$cont\">\n";
		$h .= "<div dojoType=\"dijit.form.DropDownButton\">\n";
		$h .= "  <span>Selected Computer Groups</span>\n";
		$h .= "  <div dojoType=\"dijit.TooltipDialog\" id=\"connectmethodttd\">\n";
		$size = 10;
		if(count($groups) < 10)
			$size = count($groups);
		$h .= selectInputHTML('', $groups, 'filtercompgroups',
		                      "onChange=\"delayedCompGroupFilterSelection();\" size=\"$size\"",
		                      -1, 0, 1);
		$h .= "  </div>\n"; # tooltip dialog
		$h .= "</div>\n"; # drop down button

		# refresh button
		$h .= dijitButton('', 'Refresh Computer Data', 'refreshcompdata(0);');

		# span to list count of computer in table
		$h .= "<span id=\"computercount\"></span>\n";

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"confirmactiondlg\"\n";
		$h .= "      duration=250\n";
		$h .= "      autofocus=false\n";
		$h .= "      draggable=true>\n";
		#$h .= "<div id=\"actionmsg\"></div>\n";
		$h .= "<div dojoType=\"dijit.layout.ContentPane\" id=\"actionmsg\"\n";
		$h .= "         style=\"background-color: white; padding: 5px;\">\n";
		$h .= "</div>\n";
		$h .= "<div id=\"complist\" style=\"overflow: auto;\"></div>\n";
		$h .= "<input type=\"hidden\" id=\"submitcont\">\n";
		$h .= "<div style=\"text-align: center;\">\n";
		$h .= "<span id=\"submitactionbtnspan\">\n";
		$h .= dijitButton('submitactionbtn', 'Submit', 'submitAction();', 0);
		$h .= "</span>\n";
		$h .= dijitButton('cancelactionbtn', 'Cancel', 'cancelAction();', 0);
		$h .= "</div>\n"; # btn div
		$h .= "</div>\n"; # confirmactiondlg

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"noschedulenoadd\"\n";
		$h .= "      title=\"Cannot Add Computers\"\n";
		$h .= "      duration=250\n";
		$h .= "      autofocus=false\n";
		$h .= "      draggable=true>\n";
		$h .= "All computers must have a schedule assigned to them. You do not<br>\n";
		$h .= "have to any schedules or no schedules exist. You must be granted<br>\n";
		$h .= "access to or create at least one schedule to be able to add computers.<br><br>\n";
		$h .= "<div style=\"text-align: center;\">\n";
		$h .= dijitButton('', 'Close', 'dijit.byId("noschedulenoadd").hide();', 0);
		$h .= "</div>\n"; # btn div
		$h .= "</div>\n"; # noschedulenoadd

		# filter table
		$h .= "<div id=\"extrafiltersdiv\" style=\"height: 65px;\"></div>\n";
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJfilterCompGroups
	///
	/// \brief generates regular expressions to match ids of all computers in the
	/// submitted computer groups
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJfilterCompGroups() {
		$groupids = processInputVar('groupids', ARG_STRING);
		if(! preg_match('/^[0-9,]+$/', $groupids)) {
			$ret = array('status' => 'error',
			             'errormsg' => "Invalid data submitted.");
			sendJSON($ret);
			return;
		}
		$groupids = explode(',', $groupids);
		$tmp = getUserResources(array($this->restype . 'Admin'), array('manageGroup'), 1);
		$groups = $tmp[$this->restype];
		$groupnames = array();
		foreach($groupids as $id) {
			if(array_key_exists($id, $groups))
				$groupnames[] = $groups[$id];
		}
		$comps = getResourcesFromGroups($groupnames, 'computer', 1);
		$regids = "^" . implode('$|^', array_keys($comps)) . "$";
		$arr = array('status' => 'success',
		             'regids' => $regids);
		sendJSON($arr);
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
	function addEditDialogHTML($add) {
		global $user;
		# dialog for on page editing
		$h = '';
		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"addeditdlg\"\n";
		$h .= "      title=\"Edit {$this->restypename}\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"addeditdlgcontent\">\n";
		$h .= "<div id=\"computerdlgcontent\">\n";
		# id
		$h .= "<input type=\"hidden\" id=\"editresid\">\n";

		$types = array("blade" => "Bare Metal", "lab" => "Lab", "virtualmachine" => "Virtual Machine");
		$provisioning = getProvisioning();
		$provtypes = getProvisioningTypes();
		$states = array('blade'          => array(2 => 'available',
		                                          10 => 'maintenance',
		                                          20 => 'vmhostinuse'),
		                'lab'            => array(2 => 'available',
		                                          10 => 'maintenance'),
		                'virtualmachine' => array(10 => 'maintenance'));

		$h .= "<script type=\"text/javascript\">\n";
		$h .= "var options = {\n";
		$options = array();
		foreach($types as $type => $tmp) {
			$opt = '';
			$opt .= "  $type: {\n";
			$opt .= "    provisioning: [\n";
			$arr = array();
			foreach($provtypes[$type] as $key => $val)
				$arr[] = "      {value: '$key', label: '$val'}";
			$opt .= implode(",\n", $arr);
			$opt .= "\n    ],\n";
			$opt .= "    states: [\n";
			$arr = array();
			foreach($states[$type] as $key => $val)
				$arr[] = "      {value: '$key', label: '$val'}";
			$opt .= implode(",\n", $arr);
			$opt .= "\n    ]\n";
			$opt .= "  }";
			$options[] = $opt;
		}
		$h .= implode(",\n", $options);
		$h .= "\n}\n";
		$h .= "</script>\n";

		# add single or multiple
		$h .= "<div id=\"singlemultiplediv\" class=\"hidden\">\n";
		/*$h .= "<label for=\"addsingle\">Add Single Computer</label><span ";
		$h .= "class=\"labeledform\"><input type=\"radio\" name=\"mode\" ";
		$h .= "id=\"addsingle\" checked=\"checked\" onclick=\"toggleAddSingle();\">";
		$h .= "</span><br><br>\n";
		$h .= "<label for=\"addmultiple\">Add Multiple Computers</label><span ";
		$h .= "class=\"labeledform\"><input type=\"radio\" name=\"mode\" ";
		$h .= "id=\"addmultiple\" onclick=\"toggleAddMultiple();\"><br><br>\n";*/
		$extra = array('onChange' => 'toggleSingleMultiple();');
		$modes = array('single' => 'Single Computer',
		               'multiple' => 'Multiple Computers');
		$h .= labeledFormItem('mode', i('Add') . ' ', 'select', $modes, 1, '', '', '', $extra);
		$h .= "<br>\n";
		$h .= "</div>\n"; # singlemultiplediv

		# add multiple note
		$h .= "<div id=\"multiplenotediv\" class=\"hidden\">\n";
		$h .= "<b>NOTE</b>: 'Start IP' and 'End IP' can only differ in the number ";
		$h .= "after the last '.'. The<br>hostnames will be generated from the ";
		$h .= "'Hostname' field. The hostnames for each<br>computer can only differ ";
		$h .= "by the value of a number in the first part of the hostname.<br>Place ";
		$h .= "a '%' character in the 'Hostname' field where that number will be. ";
		$h .= "Then fill in<br>'Start value' and 'End value' with the first and last ";
		$h .= "values to be used in the hostname.<br><br>";
		$h .= "</div>\n"; # multiplenotediv

		# div for canceling moving blade to vmhostinuse
		$h .= "<div class=\"highlightnoticewarn hidden\" id=\"cancelvmhostinusediv\">\n";
		$h .= "<span id=\"tohostfuturespan\">\n";
		$h .= "NOTICE: This computer is scheduled to start being reloaded as a vmhost at<br>";
		$h .= "<span id=\"tohostfuturetimespan\"></span>";
		$h .= ". You may cancel this scheduled<br>reload by clicking the button below.";
		$h .= "<br><br></span>\n";
		$h .= "<span id=\"tohostnowspan\">\n";
		$h .= "NOTICE: This computer is currently being reloaded as a vmhost. You may cancel this<br>";
		$h .= "process by clicking on the button below. After canceling the reload, it may take several<br>";
		$h .= "minutes for the cancellation process to complete.";
		$h .= "<br><br></span>\n";
		$h .= "<input type=\"hidden\" id=\"tohostcancelcont\">\n";
		$h .= "<button dojoType=\"dijit.form.Button\">\n";
		$h .= "	Cancel Scheduled Reload\n";
		$h .= "	<script type=\"dojo/method\" event=onClick>\n";
		$h .= "		cancelScheduledtovmhostinuse();\n";
		$h .= "	</script>\n";
		$h .= "</button>\n";
		$h .= "</div>\n"; # cancelvmhostinusediv
		$h .= "<div class=\"highlightnoticenotify hidden\" id=\"cancelvmhostinuseokdiv\"></div>\n";

		# hostname
		$errmsg = i("Name can only contain letters, numbers, dashes(-), periods(.), and underscores(_). It can be from 1 to 36 characters long.");
		$h .= labeledFormItem('name', i('Name') . '*', 'text', '^([a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,35})$',
		                      1, '', $errmsg); 

		# start/end
		$h .= "<div id=\"startenddiv\" class=\"hidden\">\n";
		$extra = array('smallDelta' => 1, 'largeDelta' => 10);
		$h .= labeledFormItem('startnum', i('Start') . '*', 'spinner', '{min:0,max:255,places:0}', 1);
		$h .= labeledFormItem('endnum', i('End') . '*', 'spinner', '{min:0,max:255,places:0}', 1);
		$h .= "</div>\n"; # startenddiv

		# owner
		$extra = array('onKeyPress' => 'setOwnerChecking');
		$h .= labeledFormItem('owner', i('Owner') . '*', 'text', '', 1,
		                      "{$user['unityid']}@{$user['affiliation']}", i('Unknown user'),
		                      'checkOwner', $extra);
		$cont = addContinuationsEntry('AJvalidateUserid');
		$h .= "<input type=\"hidden\" id=\"valuseridcont\" value=\"$cont\">\n";

		# type
		$extra = array('onChange' => 'selectType();');
		$h .= labeledFormItem('type', i('Type'), 'select', $types, 1, '', '', '', $extra);

		# single computer fields
		$h .= "<div id=\"singleipmacdiv\">\n";
		# public IP
		$ipreg = '(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)';
		$ipreg1 = "^$ipreg$";
		$errmsg = i("Invalid Public IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('ipaddress', i('Public IP Address') . '*', 'text', $ipreg1, 1, '', $errmsg); 

		# private IP
		$errmsg = i("Invalid Private IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('privateipaddress', i('Private IP Address'), 'text', $ipreg1, 0, '', $errmsg); 

		# Public MAC
		$macreg = '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$';
		$errmsg = i("Invalid Public MAC address specified");
		$h .= labeledFormItem('publicmac', i('Public MAC Address'), 'text', $macreg, 0, '', $errmsg); 

		# private MAC
		$errmsg = i("Invalid Private MAC address specified");
		$h .= labeledFormItem('privatemac', i('Private MAC Address'), 'text', $macreg, 0, '', $errmsg); 

		$h .= "</div>\n"; # singleipmacdiv

		# multi computer fields
		$h .= "<div id=\"multiipmacdiv\" class=\"hidden\">\n";
		# start public IP
		$errmsg = i("Invalid Start Public IP Address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('startpubipaddress', i('Start Public IP Address') . '*', 'text', $ipreg1, 1, '', $errmsg); 

		# end public IP
		$errmsg = i("Invalid End Public IP Address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('endpubipaddress', i('End Public IP Address') . '*', 'text', $ipreg1, 1, '', $errmsg); 

		# start private IP
		$errmsg = i("Invalid Start Private IP Address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('startprivipaddress', i('Start Private IP Address') . '*', 'text', $ipreg1, 1, '', $errmsg); 

		# end private IP
		$errmsg = i("Invalid End Private IP Address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('endprivipaddress', i('End Private IP Address') . '*', 'text', $ipreg1, 1, '', $errmsg); 

		# start MAC
		$errmsg = i("Invalid Start MAC Address specified");
		$h .= labeledFormItem('startmac', i('Start MAC Address'), 'text', $macreg, 0, '', $errmsg); 

		$h .= "</div>\n"; # multiipsdiv

		# provisioning engine
		$extra = array('onChange' => 'selectProvisioning();');
		$h .= labeledFormItem('provisioningid', i('Provisioning Engine'), 'selectonly', $provisioning, 1, '', '', '', $extra);

		# state
		$extra = array('onChange' => 'selectState();');
		$states = array(2 => 'available',
		                23 => 'hpc',
		                10 => 'maintenance',
		                20 => 'vmhostinuse');
		$h .= labeledFormItem('stateid', i('State'), 'selectonly', $states, 1, '', '', '', $extra);

		# maintenance notes
		$h .= "<div id=\"notesspan\">\n";
		$h .= labeledFormItem('notes', i('Reason for Maintenance'), 'textarea');
		$h .= "</div>\n";

		# VMhost profile
		$profiles = getVMProfiles();
		uasort($profiles, 'sortKeepIndex');
		$h .= "<div id=\"vmprofilespan\">\n";
		$h .= labeledFormItem('vmprofileid', i('VM Host Profile'), 'select', $profiles);
		$h .= "</div>\n";

		# platform
		$platforms = getPlatforms();
		$h .= labeledFormItem('platformid', i('Platform'), 'select', $platforms);

		# schedule
		$tmp = getUserResources(array("scheduleAdmin"), array("manageGroup"));
		$schedules = $tmp["schedule"];
		$h .= labeledFormItem('scheduleid', i('Schedule'), 'selectonly', $schedules);

		# current image
		$h .= "<div id=\"curimgspan\">\n";
		$h .= "<label for=\"curimg\">Current Image:</label>\n";
		$h .= "<span class=\"labeledform\" id=\"curimg\"></span><br>\n";
		$h .= "</div>\n";

		# ram
		$extra = array('smallDelta' => 1024, 'largeDelta' => 4096);
		$h .= labeledFormItem('ram', i('RAM (MB)') . '*', 'spinner', '{min:500,max:16777215,places:0}', 1);

		# cores
		$extra = array('smallDelta' => 1, 'largeDelta' => 4);
		$h .= labeledFormItem('cores', i('Cores') . '*', 'spinner', '{min:1,max:255,places:0}', 1);

		# proc speed
		$extra = array('smallDelta' => 100, 'largeDelta' => 1000);
		$h .= labeledFormItem('procspeed', i('Processor Speed (MHz)') . '*', 'spinner', '{min:500,max:10000,places:0}', 1);

		# network speed
		$tmpArr = array("10" => "10", "100" => "100", "1000" => "1000", "10000" => "10000", "100000" => "100000");
		$h .= labeledFormItem('network', i('Network'), 'select', $tmpArr);

		# predictive loading module
		$vals = getPredictiveModules();
		$h .= labeledFormItem('predictivemoduleid', i('Predictive Loading Module'), 'select', $vals);

		# NAT
		$h .= "<div class=\"boxedoptions\">\n";
		# use NAT
		$extra = array('onChange' => "toggleNAT('natenabled', 'nathostid');");
		$h .= labeledFormItem('natenabled', i('Connect Using NAT'), 'check', '', '', '1', '', '', $extra);
		# which NAT host
		$nathosts = getNAThosts(0, 1);
		$h .= labeledFormItem('nathostid', i('NAT Host'), 'selectonly', $nathosts);
		$h .= "</div>\n"; # NAT

		# NAT Host
		$h .= "<div id=\"nathost\" class=\"boxedoptions\">\n";
		# use as NAT host
		$extra = array('onChange' => "toggleNAThost();");
		$h .= labeledFormItem('nathostenabled', i('Use as NAT Host'), 'check', '', '', '1', '', '', $extra);
		# public IP
		$errmsg = i("Invalid NAT Public IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('natpublicipaddress', i('NAT Public IP Address'), 'text', $ipreg1, 1, '', $errmsg); 
		# internal IP
		$errmsg = i("Invalid NAT Internal IP address specified - must be a valid IPV4 address");
		$h .= labeledFormItem('natinternalipaddress', i('NAT Internal IP Address'), 'text', $ipreg1, 1, '', $errmsg); 
		$h .= "</div>\n"; # NAT Host

		# compid
		$h .= "<div id=\"compidspan\">\n";
		$h .= "<label for=\"compid\">Computer ID:</label>\n";
		$h .= "<span class=\"labeledform\" id=\"compid\"></span><br>\n";
		$h .= "</div>\n";

		# location
		$errmsg = i("Location can be up to 255 characters long and may contain letters, numbers, spaces, and these characters: - , . _ @ # ( )");
		$h .= labeledFormItem('location', i('Location'), 'text',
		                      '^([-a-zA-Z0-9_\. ,@#\(\)]{0,255})$', 0, '', $errmsg); 

		$h .= "</div>\n"; # computerdlgcontent
		$h .= "</div>\n"; # addeditdlgcontent

		$h .= "<div id=\"addeditdlgerrmsg\" class=\"nperrormsg\"></div>\n";

		$h .= "<div id=\"editdlgbtns\" align=\"center\">\n";
		$h .= dijitButton('addeditbtn', "Confirm", "saveResource();");
		$h .= dijitButton('', "Cancel", "dijit.byId('addeditdlg').hide();");
		$h .= "</div>\n"; # editdlgbtns
		$h .= "</div>\n"; # dialog

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"groupingnote\"\n";
		$h .= "      title=\"Computer Grouping\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "Computer(s) successfully added. Each computer needs<br>to be a member of a computer resource group. The<br>following dialog<br>will allow you to add the new<br>computer(s) to a group.<br><br>\n";
		$h .= "<div align=\"center\">\n";
		$h .= dijitButton('', "Close", "dijit.byId('groupingnote').hide();");
		$h .= "</div>\n"; # btn div
		$h .= "</div>\n"; # groupingnote

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"groupdlg\"\n";
		$h .= "      title=\"Computer Grouping\"\n";
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
		$this->jsondata['showcancel'] = 0;
		$query = "SELECT UNIX_TIMESTAMP(rq.start) AS start "
		       . "FROM request rq, "
		       .      "reservation rs, "
		       .      "state ls, "
		       .      "state cs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid = $rscid AND "
		       .       "rq.laststateid = ls.id AND "
		       .       "rq.stateid = cs.id AND "
		       .       "ls.name = 'tovmhostinuse' AND "
		       .       "cs.name NOT IN ('failed', 'maintenance', 'complete', 'deleted') AND "
		       .       "rq.end > NOW() "
		       . "ORDER BY rq.start "
		       . "LIMIT 1";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh)) {
			$cdata = $this->basecdata;
			$cdata['compid'] = $rscid;
			$cont = addContinuationsEntry('AJcanceltovmhostinuse', $cdata, 300, 1, 0);
			$this->jsondata['tohostcancelcont'] = $cont;
			$this->jsondata['showcancel'] = 1;
			$this->jsondata['tohoststart'] = date('g:i A \o\n l, F jS, Y', $row['start']);
			if($row['start'] > time())
				$this->jsondata['tohostfuture'] = 1;
			else
				$this->jsondata['tohostfuture'] = 0;
		}
		parent::AJeditResource();
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsaveResource()
	///
	/// \brief saves changes to resource
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

		$promptuser = 0;
		$promptuserfail = 0;
		$multirefresh = 0;

		if($add) {
			if(! $data['rscid'] = $this->addResource($data)) {
				sendJSON(array('status' => 'adderror',
				               'errormsg' => 'Error encountered while trying to create new computer(s).<br>Please contact an admin for assistance.'));
				return;
			}
		}
		else {
			$olddata = getContinuationVar('olddata');
			$updates = array();
			# hostname
			if($data['name'] != $olddata['hostname'])
				$updates[] = "hostname = '{$data['name']}'";

			# ownerid
			$ownerid = getUserlistID($data['owner']);
			if($ownerid != $olddata['ownerid'])
				$updates[] = "ownerid = $ownerid";

			# cores
			if($data['cores'] != $olddata['procnumber'])
				$updates[] = "procnumber = '{$data['cores']}'";

			# eth0macaddress
			if($data['eth0macaddress'] != $olddata['eth0macaddress']) {
				if($data['eth0macaddress'] == '')
					$updates[] = "eth0macaddress = NULL";
				else
					$updates[] = "eth0macaddress = '{$data['eth0macaddress']}'";
			}

			# eth1macaddress
			if($data['eth1macaddress'] != $olddata['eth1macaddress']) {
				if($data['eth1macaddress'] == '')
					$updates[] = "eth1macaddress = NULL";
				else
					$updates[] = "eth1macaddress = '{$data['eth1macaddress']}'";
			}

			# use NAT
			if($data['natenabled'] != $olddata['natenabled']) {
				if($data['natenabled']) {
					$query = "INSERT INTO nathostcomputermap "
					       .        "(computerid, "
					       .        "nathostid) "
					       . "VALUES ({$data['rscid']}, "
					       .        "{$data['nathostid']})";
					doQuery($query);
				}
				else {
					$query = "DELETE FROM nathostcomputermap "
					       . "WHERE computerid = {$data['rscid']}";
					doQuery($query);
				}
			}
			elseif($data['natenabled'] &&
			   $olddata['nathostid'] != $data['nathostid']) {
				$query = "UPDATE nathostcomputermap "
				       . "SET nathostid = {$data['nathostid']} "
				       . "WHERE computerid = {$data['rscid']}";
				doQuery($query);
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

			# other fields
			$fields = array('type', 'IPaddress', 'privateIPaddress',
			                'provisioningid', 'platformid', 'scheduleid', 'ram',
			                'procspeed', 'network', 'predictivemoduleid', 'location');
			foreach($fields as $field) {
				if($data[$field] != $olddata[$field])
					$updates[] = "`$field` = '{$data[$field]}'";
			}

			# stateid - if moving from vmhostinuse or reloading with a new image,
			#           make sure no reservations for VMs
			if($olddata['stateid'] == 10 && $data['stateid'] == 20) {
				$query = "SELECT vm.id "
				       . "FROM computer vm, "
				       .      "vmhost v "
				       . "WHERE v.computerid = {$data['rscid']} AND "
				       .       "vm.vmhostid = v.id AND "
				       .       "vm.notes = 'maintenance with host {$data['rscid']}' AND "
				       .       "vm.stateid = 10";
				$qh = doQuery($query);
				$vmids = array();
				while($row = mysql_fetch_assoc($qh))
					$vmids[] = $row['id'];
				$allids = implode(',', $vmids);
				if($data['provisioning'] != 'none')  {
					$profiles = getVMProfiles();
					if(! array_key_exists('vmprofileid', $olddata) ||
						$olddata['vmprofileid'] == '' || 
					   $profiles[$olddata['vmprofileid']]['imageid'] !=
						$profiles[$data['vmprofileid']]['imageid']) {
						# VCL provisioned, different image
						# schedule VM host to be reloaded
						$profiles = getVMProfiles($data['vmprofileid']);
						$imageid = $profiles[$data['vmprofileid']]['imageid'];
						$start = getReloadStartTime();
						$rc = $this->scheduleTovmhostinuse($data['rscid'], $imageid, $start,
						                                   $data['vmprofileid'], $olddata['vmprofileid']);
	
						if($rc == 0) {
							$msg = '';
							if(count($updates))
								$msg .= "Computer information changes were saved.<br>\nHowever, a ";
							else
								$msg .= "A ";
							$msg .= "problem was encountered while attempting to reload the ";
							$msg .= "computer with the selected VM Host Profile. Please try ";
							$msg .= "again at a later time.\n";
							$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
							$promptuserfail = 1;
							$title = 'VM Host Reload Failed';
						}
						else {
							if(count($vmids))
								$this->scheduleVMsToAvailable($vmids);
							$multirefresh = 3;
						}
					}
					else {
						# VCL provisioned, same image
						$msg = '';
						if(count($updates))
							$msg .= "Computer information changes saved.<br><br>\nHowever, this ";
						else
							$msg .= "This ";
						$msg .= "computer was previously in the vmhostinuse state. ";
						$msg .= "You can:<br><br>\n";
						$msg .= "<input type=\"radio\" name=\"mode\" value=\"vmhostinuse\" ";
						$msg .= "id=\"modedirect\" checked=\"checked\"><label ";
						$msg .= "for=\"modereload\">Move it directly back to vmhostinuse\n";
						$msg .= "</label><br>\n";
						$msg .= "<input type=\"radio\" name=\"mode\" value=\"reload\" ";
						$msg .= "id=\"modereload\"><label for=\"modereload\">Have it reloaded ";
						$msg .= "and then placed back into vmhostinuse</label><br><br>\n";
						$promptuser = 1;
						$cdata = $this->basecdata;
						$cdata['compid'] = $data['rscid'];
						$cdata['imageid'] = $profiles[$data['vmprofileid']]['imageid'];
						$cdata['oldprofileid'] = $olddata['vmprofileid'];
						$cdata['vmprofileid'] = $data['vmprofileid'];
						$cdata['newstateid'] = $data['stateid'];
						$cdata['oldstateid'] = $olddata['stateid'];
						$cdata['vmids'] = $vmids;
						$promptcont = addContinuationsEntry('AJsubmitComputerStateLater', $cdata, SECINDAY, 1, 0);
						$btntxt = 'Submit';
						$title = 'State Change Option';
					}
					$data['stateid'] = $olddata['stateid']; # prevent state from being updated directly
				}
				else {
					if(count($vmids)) {
						$query = "UPDATE computer "
						       . "SET stateid = 2, "
						       .     "notes = '' "
								 . "WHERE id in ($allids)";
						doQuery($query);
						$multirefresh = 1;
					}
					if(! array_key_exists('vmprofileid', $olddata) ||
						$olddata['vmprofileid'] == '') {
						$query = "INSERT INTO vmhost "
						       .        "(computerid, "
						       .        "vmprofileid) "
						       . "VALUES ({$data['rscid']}, "
						       .        "{$data['vmprofileid']})";
						doQuery($query);
					}
					elseif($olddata['vmprofileid'] != $data['vmprofileid']) {
						$query = "UPDATE vmhost "
						       . "SET vmprofileid = {$data['vmprofileid']} "
						       . "WHERE computerid = {$data['rscid']} AND "
						       .       "vmprofileid = {$olddata['vmprofileid']}";
						doQuery($query);
					}
				}
			}
			elseif($olddata['stateid'] != 20 && $data['stateid'] == 20) {
				# check for reservations
				moveReservationsOffComputer($data['rscid']);
				cleanSemaphore();
				$reloadstart = getCompFinalReservationTime($data['rscid'], 21);
				$checkstart = getExistingChangeStateStartTime($data['rscid'], 21);
				if($data['provisioning'] != 'none')  {
					# VCL provisioned
					$profiles = getVMProfiles($data['vmprofileid']);
					$imageid = $profiles[$data['vmprofileid']]['imageid'];
					if($reloadstart) {
						if($checkstart && $checkstart < $reloadstart)
							$reloadstart = $checkstart;
						# reservations, must wait until end time
						$end = date('n/j/y g:i a', $reloadstart);
						$msg = '';
						if(count($updates))
							$msg .= "Computer information changes saved.<br>\nHowever, this ";
						else
							$msg .= "This ";
						$msg .= "computer is currently allocated until $end and cannot ";
						$msg .= "be reloaded until then. You can:\n";
						$msg .= "<ul><li>Cancel and try later</li>\n";
						$msg .= "<li>Schedule the computer to be reloaded with the selected ";
						$msg .= "profile at $end</li></ul>\n";
						$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
						$msg = preg_replace("|$end|", "<strong>$end</strong>", $msg, 1);
						$promptuser = 1;
						$cdata = $this->basecdata;
						$cdata['maintenanceonly'] = 0;
						$cdata['compid'] = $data['rscid'];
						$cdata['reloadstart'] = $reloadstart;
						$cdata['imageid'] = $imageid;
						$cdata['oldprofileid'] = $olddata['vmprofileid'];
						$cdata['vmprofileid'] = $data['vmprofileid'];
						$cdata['newstateid'] = $data['stateid'];
						$cdata['oldstateid'] = $olddata['stateid'];
						$promptcont = addContinuationsEntry('AJsubmitComputerStateLater', $cdata, SECINDAY, 1, 0);
						$btntxt = 'Schedule Reload';
						$title = 'Delayed State Change';
					}
					else {
						# no reservations
						$start = getReloadStartTime();
						$checkstart = getExistingChangeStateStartTime($data['rscid'], 21);
						if($checkstart && $checkstart < $start)
							$start = $checkstart;
						$rc = $this->scheduleTovmhostinuse($data['rscid'], $imageid, $start,
						                                   $data['vmprofileid'], $olddata['vmprofileid']);
	
						if($rc == 0) {
							$msg = '';
							if(count($updates))
								$msg .= "Computer information changes were saved.<br>\nHowever, a ";
							else
								$msg .= "A ";
							$msg .= "problem was encountered while attempting to reload the ";
							$msg .= "computer with the selected VM Host Profile. Please try ";
							$msg .= "again at a later time.\n";
							$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
							$promptuserfail = 1;
							$title = 'VM Host Reload Failed';
						}
						else
							$multirefresh = 3;
					}
					$data['stateid'] = $olddata['stateid']; # prevent state from being updated directly
				}
				else {
					# manually provisioned
					if($reloadstart) {
						# reservations, must wait until end time
						$end = date('n/j/y g:i a', $reloadstart);
						$msg = '';
						if(count($updates))
							$msg .= "Computer information changes saved.<br>\nHowever, this ";
						else
							$msg .= "This ";
						$msg .= "computer is currently allocated until $end and cannot ";
						$msg .= "be converted to a VM host until then. You can:\n";
						$msg .= "<ul><li>Cancel and do nothing</li>\n";
						$msg .= "<li>Schedule the computer to go in to maintenance at $end ";
						$msg .= "and manually move it to vmhostinuse after that</li></ul>\n";
						$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
						$msg = preg_replace("|$end|", "<strong>$end</strong>", $msg, 1);
						$promptuser = 1;
						$cdata = $this->basecdata;
						$cdata['maintenanceonly'] = 1;
						$cdata['reloadstart'] = $reloadstart;
						$cdata['imageid'] = getImageId('noimage');
						$cdata['compid'] = $data['rscid'];
						$cdata['newstateid'] = $data['stateid'];
						$cdata['oldstateid'] = $olddata['stateid'];
						$promptcont = addContinuationsEntry('AJsubmitComputerStateLater', $cdata, SECINDAY, 1, 0);
						$btntxt = 'Schedule State Change';
						$title = 'Delayed State Change';
						$data['stateid'] = $olddata['stateid']; # prevent state from being updated yet
					}
					else {
						# no reservations
						$this->updateVmhostProfile($data['rscid'], $data['vmprofileid'], $olddata['vmprofileid']);
					}
				}
			}
			elseif($olddata['stateid'] == 20 && $data['stateid'] == 2) {
				# only valid condition for VCL provisioned
				# check for reservations
				moveReservationsOffVMs($data['rscid']);
				cleanSemaphore();
				$reloadstart = getCompFinalVMReservationTime($data['rscid'], 1);
				if($reloadstart == -1) {
					$msg = '';
					if(count($updates))
						$msg .= "Computer information changes were saved.<br>\nHowever, a ";
					else
						$msg .= "A ";
					$msg .= "problem was encountered while attempting to move VMs ";
					$msg .= "off of the computer. Please try again at a later time.\n";
					$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
					$promptuserfail = 1;
					$title = 'Change to Available Failed';
					$data['stateid'] = $olddata['stateid'];
				}
				elseif($reloadstart > 0) {
					cleanSemaphore();
					$end = date('n/j/y g:i a', $reloadstart);
					$msg = '';
					if(count($updates))
						$msg .= "Computer information changes saved.<br>\nHowever, this ";
					else
						$msg .= "This ";
					$msg .= "computer currently has VMs with reservations on them until ";
					$msg .= "$end and cannot be moved to the available state until then. ";
					$msg .= "You can:\n";
					$msg .= "<ul><li>Cancel and do nothing</li>\n";
					$msg .= "<li>Schedule the VMs to be removed at $end and the computer ";
					$msg .= "to be moved to available that</li></ul>\n";
					$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
					$msg = preg_replace("|$end|", "<strong>$end</strong>", $msg, 1);
					$promptuser = 1;
					$cdata = $this->basecdata;
					$cdata['reloadstart'] = $reloadstart;
					$cdata['imageid'] = getImageId('noimage');
					$cdata['compid'] = $data['rscid'];
					$cdata['newstateid'] = $data['stateid'];
					$cdata['oldstateid'] = $olddata['stateid'];
					$promptcont = addContinuationsEntry('AJsubmitComputerStateLater', $cdata, SECINDAY, 1, 0);
					$btntxt = 'Schedule State Change';
					$title = 'Delayed State Change';
					$data['stateid'] = $olddata['stateid']; # prevent state from being updated yet
				}
				else {
					# schedule tomaintenance reservations for VMs
					#   might be better to just directly move the VMs to the maintenance state
					$vclreloadid = getUserlistID('vclreload@Local');
					$imageid = getImageId('noimage');
					$revid = getProductionRevisionid($imageid);
					$start = getReloadStartTime();
					$end = $start + SECINMONTH;
					$startdt = unixToDatetime($start);
					$enddt = unixToDatetime($end);
					$query = "SELECT vm.id "
					       . "FROM computer vm, "
					       .      "vmhost v "
					       . "WHERE v.computerid = {$data['rscid']} AND "
					       .       "vm.vmhostid = v.id";
					$qh = doQuery($query);
					$fail = 0;
					while($row = mysql_fetch_assoc($qh)) {
						if(! simpleAddRequest($row['id'], $imageid, $revid, $startdt,
						                      $enddt, 18, $vclreloadid)) {
							$fail = 1;
							break;
						}
						else
							$multirefresh = 2;
					}
					cleanSemaphore();
					if($fail) {
						$data['stateid'] = $olddata['stateid']; # prevent state from being updated yet
						$msg = '';
						if(count($updates))
							$msg .= "Computer information changes were saved.<br>\nHowever, a ";
						else
							$msg .= "A ";
						$msg .= "problem was encountered while attempting to remove VMs ";
						$msg .= "from the computer. Please try again at a later time.\n";
						$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
						$promptuserfail = 1;
						$title = 'Change State to Available Failed';
					}
				}
			}
			elseif($olddata['stateid'] == 20 && $data['stateid'] == 10) {
				# VCL provisioned and manually provisioned are the same
				# check for reservations
				moveReservationsOffVMs($data['rscid']);
				cleanSemaphore();
				$reloadstart = getCompFinalVMReservationTime($data['rscid'], 1, 1);
				if($reloadstart == -1) {
					$msg = '';
					if(count($updates))
						$msg .= "Computer information changes were saved.<br>\nHowever, a ";
					else
						$msg .= "A ";
					$msg .= "problem was encountered while attempting to place assigned VMs ";
					$msg .= "into the maintenance state. Please try again at a later time.\n";
					$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
					$promptuserfail = 1;
					$title = 'Change to Maintenance Failed';
				}
				elseif($reloadstart > 0) {
					cleanSemaphore();
					if(unixToDatetime($reloadstart) == '2038-01-01 00:00:00') {
						$msg = '';
						if(count($updates))
							$msg .= "Computer information changes saved.<br>\nHowever, this ";
						else
							$msg .= "This ";
						$msg .= "computer currently has VMs assigned to it that have server ";
						$msg .= "reservations with indefinite endings. The computer cannot ";
						$msg .= "be moved to the maintenance state while these reservations exist.";
						$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
						$promptuserfail = 1;
						$title = 'Change to Maintenance Failed';
						$data['stateid'] = $olddata['stateid']; # prevent state from being updated
					}
					else {
						$end = date('n/j/y g:i a', $reloadstart);
						$msg = '';
						if(count($updates))
							$msg .= "Computer information changes saved.<br>\nHowever, this ";
						else
							$msg .= "This ";
						$msg .= "computer currently has VMs with reservations on them until ";
						$msg .= "$end and cannot be moved to the maintenance state until then. ";
						$msg .= "You can:\n";
						$msg .= "<ul><li>Cancel and do nothing</li>\n";
						$msg .= "<li>Schedule the computer and VMs to be moved into the ";
						$msg .= "maintenance state at $end</li></ul>\n";
						$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
						$msg = preg_replace("|$end|", "<strong>$end</strong>", $msg, 1);
						$promptuser = 1;
						$cdata = $this->basecdata;
						$cdata['reloadstart'] = $reloadstart;
						$cdata['imageid'] = getImageId('noimage');
						$cdata['compid'] = $data['rscid'];
						$cdata['newstateid'] = $data['stateid'];
						$cdata['oldstateid'] = $olddata['stateid'];
						$promptcont = addContinuationsEntry('AJsubmitComputerStateLater', $cdata, SECINDAY, 1, 0);
						$btntxt = 'Schedule State Change';
						$title = 'Delayed State Change';
						$data['stateid'] = $olddata['stateid']; # prevent state from being updated yet
					}
				}
				else {
					$query = "UPDATE computer c "
					       . "INNER JOIN vmhost v ON (c.vmhostid = v.id) "
					       . "SET c.stateid = 10, "
					       .     "c.notes = 'maintenance with host {$data['rscid']}' "
					       . "WHERE v.computerid = {$data['rscid']}";
					doQuery($query);
					cleanSemaphore();
					$multirefresh = 1;
				}
			}
			elseif($olddata['stateid'] == 10 && $data['stateid'] == 2) {
				if(is_numeric($olddata['vmprofileid'])) {
					$vclreloadid = getUserlistID('vclreload@Local');
					$imageid = getImageId('noimage');
					$revid = getProductionRevisionid($imageid);
					$start = getReloadStartTime();
					$end = $start + SECINMONTH;
					$startdt = unixToDatetime($start);
					$enddt = unixToDatetime($end);
					# move VMs to reload state so vcld will not skip them due to being in maintenance
					$query = "UPDATE computer c, "
					       .        "vmhost v "
					       . "SET c.stateid = 19, "
					       .     "c.notes = '' "
					       . "WHERE v.computerid = {$data['rscid']} AND "
					       .       "c.vmhostid = v.id";
					doQuery($query);
					$query = "SELECT vm.id "
					       . "FROM computer vm, "
					       .      "vmhost v "
					       . "WHERE v.computerid = {$data['rscid']} AND "
					       .       "vm.vmhostid = v.id";
					$qh = doQuery($query);
					$fails = array();
					while($row = mysql_fetch_assoc($qh)) {
						if(! simpleAddRequest($row['id'], $imageid, $revid, $startdt,
						                      $enddt, 18, $vclreloadid)) {
							$fails[] = $row['id'];
						}
						else
							$multirefresh = 2;
					}
					if(count($fails)) {
						# just directly remove any VMs that failed to be scheduled
						$query = "UPDATE computer "
						       . "SET stateid = 10, "
						       .     "vmhostid = NULL, "
						       .     "notes = '' "
						       . "WHERE id IN (" . implode(',', $fails) . ")";
						doQuery($query);
					}
				}
			}
			elseif($olddata['stateid'] == 20 && $data['stateid'] == 20 &&
			       $olddata['vmprofileid'] != $data['vmprofileid']) {
				if($data['provisioning'] != 'none')  {
					$profiles = getVMProfiles($data['vmprofileid']);
					if($profiles[$olddata['vmprofileid']]['imageid'] ==
					   $profiles[$data['vmprofileid']]['imageid']) {
						$query = "UPDATE vmhost "
						       . "SET vmprofileid = {$data['vmprofileid']} "
						       . "WHERE computerid = {$data['rscid']} AND "
						       .       "vmprofileid = {$olddata['vmprofileid']}";
						doQuery($query);
					}
					else {
						moveReservationsOffVMs($data['rscid']);
						cleanSemaphore();
						$reloadstart = getCompFinalVMReservationTime($data['rscid'], 1);
						if($reloadstart == -1) {
							$msg = '';
							if(count($updates))
								$msg .= "Computer information changes were saved.<br>\nHowever, a ";
							else
								$msg .= "A ";
							$msg .= "problem was encountered while attempting to place assigned ";
							$msg .= "VMs into the maintenance state while reloading the computer. ";
							$msg .= "Please try again at a later time.\n";
							$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
							$promptuserfail = 1;
							$title = 'Change VM Host Profile Failed';
						}
						elseif($reloadstart > 0) {
							cleanSemaphore();
							$end = date('n/j/y g:i a', $reloadstart);
							$msg = '';
							if(count($updates))
								$msg .= "Computer information changes saved.<br>\nHowever, this ";
							else
								$msg .= "This ";
							$msg .= "computer must be reloaded to change to the selected VM Host ";
							$msg .= "Profile and there are VMs on it with reservations until $end. ";
							$msg .= "You can:\n";
							$msg .= "<ul><li>Cancel and do nothing</li>\n";
							$msg .= "<li>Schedule the VMs to be removed and the computer to be ";
							$msg .= "reloaded at $end</li></ul>\n";
							$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
							$msg = preg_replace("|$end|", "<strong>$end</strong>", $msg, 1);
							$promptuser = 1;
							$cdata = $this->basecdata;
							$cdata['reloadstart'] = $reloadstart;
							$cdata['imageid'] = $profiles[$data['vmprofileid']]['imageid'];
							$cdata['compid'] = $data['rscid'];
							$cdata['newstateid'] = $data['stateid'];
							$cdata['oldstateid'] = $olddata['stateid'];
							$cdata['oldprofileid'] = $olddata['vmprofileid'];
							$cdata['vmprofileid'] = $data['vmprofileid'];
							$promptcont = addContinuationsEntry('AJsubmitComputerStateLater', $cdata, SECINDAY, 1, 0);
							$btntxt = 'Schedule Reload';
							$title = 'Delayed VM Host Profile Change';
						}
						else {
							# schedule VMs to be removed
							$vclreloadid = getUserlistID('vclreload@Local');
							$imageid = getImageId('noimage');
							$revid = getProductionRevisionid($imageid);
							$start = getReloadStartTime();
							$end = $start + SECINMONTH;
							$startdt = unixToDatetime($start);
							$enddt = unixToDatetime($end);
							$query = "SELECT vm.id "
							       . "FROM computer vm, "
							       .      "vmhost v "
							       . "WHERE v.computerid = {$data['rscid']} AND "
							       .       "vm.vmhostid = v.id";
							$qh = doQuery($query);
							$fails = array();
							$cnt = 0;
							while($row = mysql_fetch_assoc($qh)) {
								$cnt++;
								if(! simpleAddRequest($row['id'], $imageid, $revid, $startdt,
								                      $enddt, 18, $vclreloadid)) {
									$fails[] = $row['id'];
								}
							}
							if(count($fails)) {
								# just directly remove any VMs that failed to be scheduled
								$query = "UPDATE computer "
								       . "SET stateid = 10, "
								       .     "vmhostid = NULL, "
								       .     "notes = '' "
								       . "WHERE id IN (" . implode(',', $fails) . ")";
								doQuery($query);
							}
							cleanSemaphore();

							# schedule host to be reloaded
							if($cnt)
								$start = time() + 120; # allow 2 minutes for VMs to be removed
							$rc = $this->scheduleTovmhostinuse($data['rscid'],
							                                   $profiles[$data['vmprofileid']]['imageid'],
							                                   $start, $data['vmprofileid'],
							                                   $olddata['vmprofileid']);

							if($rc == 0) {
								$msg = '';
								if(count($updates))
									$msg .= "Computer information changes were saved.<br>\nHowever, a ";
								else
									$msg .= "A ";
								$msg .= "problem was encountered while attempting to reload the ";
								$msg .= "computer with the selected VM Host Profile. Please try ";
								$msg .= "again at a later time.\n";
								$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
								$promptuserfail = 1;
								$title = 'VM Host Reload Failed';
							}
							else
								$multirefresh = 3;
						}
					}
				}
				else {
					$query = "UPDATE vmhost "
					       . "SET vmprofileid = {$data['vmprofileid']} "
					       . "WHERE computerid = {$data['rscid']} AND "
					       .       "vmprofileid = {$olddata['vmprofileid']}";
					doQuery($query);
				}
			}
			elseif($olddata['stateid'] != 10 && $data['stateid'] == 10) {
				moveReservationsOffComputer($data['rscid']);
				cleanSemaphore();
				$reloadstart = getCompFinalReservationTime($data['rscid']);
				if($reloadstart) {
					$end = date('n/j/y g:i a', $reloadstart);
					$msg = '';
					if(count($updates))
						$msg .= "Computer information changes saved.<br>\nHowever, this ";
					else
						$msg .= "This ";
					$msg .= "computer has reservations on it until $end. You can:\n";
					$msg .= "<ul><li>Cancel and do nothing</li>\n";
					$msg .= "<li>Schedule the computer to be moved to maintenance at ";
					$msg .= "$end</li></ul>\n";
					$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);
					$msg = preg_replace("|$end|", "<strong>$end</strong>", $msg, 1);
					$promptuser = 1;
					$cdata = $this->basecdata;
					$cdata['reloadstart'] = $reloadstart;
					$cdata['imageid'] = getImageId('noimage');
					$cdata['compid'] = $data['rscid'];
					$cdata['newstateid'] = $data['stateid'];
					$cdata['oldstateid'] = $olddata['stateid'];
					$promptcont = addContinuationsEntry('AJsubmitComputerStateLater', $cdata, SECINDAY, 1, 0);
					$btntxt = 'Schedule Maintenance';
					$title = 'Delayed Maintenance';
				}
				# else let UPDATE move it to maintenance
			}

			# notes (do these at the end because we don't want to update notes if
			#    state prevented from being changed)
			# staying in maintenance
			if($olddata['stateid'] == 10 && $data['stateid'] == 10) {
				$testnotes = $olddata['notes'];
				# check for notes being changed
				if(strpos($testnotes, '@') === true) {
					$tmp = explode('@', $olddata['notes']);
					$testnotes = $tmp[1];
				}
				if($testnotes != $data['notes']) {
					$ts = unixToDatetime(time());
					$updates[] = "notes = '{$user['unityid']} $ts@{$data['notes']}'";
				}
			}
			# changing to maintenance
			elseif($data['stateid'] == 10) {
				$ts = unixToDatetime(time());
				$updates[] = "notes = '{$user['unityid']} $ts@{$data['notes']}'";
			}
			# removing from maintenance
			elseif($olddata['stateid'] == 10 && $data['stateid'] != 10) {
				$updates[] = "notes = ''";
			}

			# stateid
			if($data['stateid'] != $olddata['stateid'])
				$updates[] = "stateid = {$data['stateid']}";

			if(count($updates)) {
				$query = "UPDATE computer SET "
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

		$args = $this->defaultGetDataArgs;
		$arr = array('status' => 'success');
		if(is_array($data['rscid'])) {
			$tmp = $this->getData($args);
			$arr['addmode'] = 'multiple';
			$arr['data'] = array();
			foreach($data['rscid'] as $compid) {
				$tmp[$compid]['name'] = $tmp[$compid]['hostname'];
				$arr['data'][] = $tmp[$compid];
			}
			$arr['grouphelp'] = "Select groups from the list on the right and click the "
			                  . "Add button to add the new computer set to those groups.<br><br>";
			$cdata = $this->basecdata;
			$cdata['newids'] = $data['rscid'];
			$cdata['mode'] = 'add';
			$arr['addcont'] = addContinuationsEntry('AJaddRemGroupResource', $cdata);
			$cdata['mode'] = 'remove';
			$arr['remcont'] = addContinuationsEntry('AJaddRemGroupResource', $cdata);
		}
		else {
			if($add)
				$arr['addmode'] = 'single';
			$args['rscid'] = $data['rscid'];
			$tmp = $this->getData($args);
			$data = $tmp[$data['rscid']];
			$arr['data'] = $data;
			$arr['data']['name'] = $arr['data']['hostname'];
		}
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
		if($promptuser) {
			$arr['promptuser'] = 1;
			$arr['btntxt'] = $btntxt;
			$arr['title'] = $title;
			$arr['msg'] = $msg;
			$arr['cont'] = $promptcont;
		}
		elseif($promptuserfail) {
			$arr['promptuserfail'] = 1;
			$arr['title'] = $title;
			$arr['msg'] = $msg;
		}
		if($multirefresh)
			$arr['multirefresh'] = $multirefresh;
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateResourceData()
	///
	/// \return array with these fields:\n
	/// \b rscid - id of resource (from computer table)\n
	/// \b name - hostname of computer\n
	/// \b startnum - start number when doing multiple add\n
	/// \b endnum - end number when doing multiple add\n
	/// \b owner\n
	/// \b type - type of computer\n
	/// \b IPaddress - public IP address\n
	/// \b privateIPaddress - private IP address\n
	/// \b eth0macaddress - public MAC address\n
	/// \b eth1macaddress - private MAC address\n
	/// \b startpubipaddress - start public IP address when doing multiple add\n
	/// \b endpubipaddress - end public IP address when doing multiple add\n
	/// \b startprivipaddress - start private IP address when doing multiple
	///    add\n
	/// \b endprivipaddress - end private IP address when doing multiple add\n
	/// \b startmac - start MAC address when doing multiple add\n
	/// \b provisioningid - id of provisioning engine for computer(s)\n
	/// \b stateid - id for state of computer\n
	/// \b notes - maintenance notes when setting computer to maintenance state\n
	/// \b vmprofileid - id of vmprofile when setting to vmhostinuse state\n
	/// \b platformid - id of platform\n
	/// \b scheduleid - id of schedule\n
	/// \b ram\n
	/// \b cores\n
	/// \b procspeed\n
	/// \b network\n
	/// \b predictivemoduleid - id of module to use when preloading nodes\n
	/// \b natenabled - 1 to use NAT for this computer, 0 not to\n
	/// \b nathostid - id of NAT host for this computer\n
	/// \b location - free string describing location\n
	/// \b mode - 'edit' or 'add'\n
	/// \b addmode - 'single' or 'multiple'\n
	/// \b startpubiplong - numeric value for start public IP address when doing
	///    multiple add\n
	/// \b endpubiplong - numeric value for end public IP address when doing
	///    multiple add\n
	/// \b startpriviplong - numeric value for start private IP address when
	///    doing multiple add\n
	/// \b endpriviplong - numeric value for end private IP address when doing
	///    multiple add\n
	/// \b error - 0 if submitted data validates; 1 if anything is invalid\n
	/// \b errormsg - if error = 1; string of error messages separated by html
	///    break tags
	///
	/// \brief validates form input from editing or adding a computer
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateResourceData() {
		global $user;

		$return = array('error' => 0);

		$return['rscid'] = getContinuationVar('rscid', 0);
		$return['name'] = processInputVar('name', ARG_STRING);
		$return['startnum'] = processInputVar('startnum', ARG_NUMERIC);
		$return['endnum'] = processInputVar('endnum', ARG_NUMERIC);
		$return['owner'] = processInputVar('owner', ARG_STRING, "{$user['unityid']}@{$user['affiliation']}");
		$return['type'] = processInputVar('type', ARG_STRING);
		$return['IPaddress'] = processInputVar('ipaddress', ARG_STRING);
		$return['privateIPaddress'] = processInputVar('privateipaddress', ARG_STRING);
		$return['eth0macaddress'] = processInputVar('privatemac', ARG_STRING);
		$return['eth1macaddress'] = processInputVar('publicmac', ARG_STRING);
		$return['startpubipaddress'] = processInputVar('startpubipaddress', ARG_STRING);
		$return['endpubipaddress'] = processInputVar('endpubipaddress', ARG_STRING);
		$return['startprivipaddress'] = processInputVar('startprivipaddress', ARG_STRING);
		$return['endprivipaddress'] = processInputVar('endprivipaddress', ARG_STRING);
		$return['startmac'] = processInputVar('startmac', ARG_STRING);
		$return['provisioningid'] = processInputVar('provisioningid', ARG_NUMERIC);
		$return['stateid'] = processInputVar('stateid', ARG_NUMERIC);
		$return['notes'] = processInputVar('notes', ARG_STRING);
		$return['vmprofileid'] = processInputVar('vmprofileid', ARG_NUMERIC);
		$return['platformid'] = processInputVar('platformid', ARG_NUMERIC);
		$return['scheduleid'] = processInputVar('scheduleid', ARG_NUMERIC);
		$return['ram'] = processInputVar('ram', ARG_NUMERIC);
		$return['cores'] = processInputVar('cores', ARG_NUMERIC);
		$return['procspeed'] = processInputVar('procspeed', ARG_NUMERIC);
		$return['network'] = processInputVar('network', ARG_NUMERIC);
		$return['predictivemoduleid'] = processInputVar('predictivemoduleid', ARG_NUMERIC);
		$return['natenabled'] = processInputVar('natenabled', ARG_NUMERIC);
		$return['nathostid'] = processInputVar('nathostid', ARG_NUMERIC);
		$return['nathostenabled'] = processInputVar('nathostenabled', ARG_NUMERIC);
		$return['natpublicIPaddress'] = processInputVar('natpublicipaddress', ARG_STRING);
		$return['natinternalIPaddress'] = processInputVar('natinternalipaddress', ARG_STRING);
		$return['location'] = processInputVar('location', ARG_STRING);
		$addmode = processInputVar('addmode', ARG_STRING);

		if(! is_null($addmode) && $addmode != 'single' && $addmode != 'multiple') {
			$return['error'] = 1;
			$return['errormsg'] = "Invalid Add mode submitted";
			return $return;
		}

		$olddata = getContinuationVar('olddata');

		if($return['rscid'] == 0)
			$return['mode'] = 'add';
		else
			$return['mode'] = 'edit';

		$errormsg = array();

		# hostname
		$hostreg = '/^[a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,49}$/';
		if($return['mode'] == 'add' && $addmode == 'multiple')
			$hostreg = '/^[a-zA-Z0-9_%][-a-zA-Z0-9_\.%]{1,49}$/';
		if(! preg_match($hostreg, $return['name'])) {
			$return['error'] = 1;
			$errormsg[] = "Hostname can only contain letters, numbers, dashes(-), periods(.), and underscores(_). It can be from 1 to 50 characters long";
		}
		elseif($this->checkForHostname($return['name'], $return['rscid'])) {
			$return['error'] = 1;
			$errormsg[] = "A computer already exists with this hostname.";
		}
		# add multiple
		if($return['mode'] == 'add' && $addmode == 'multiple') {
			# startnum/endnum
			if($return['startnum'] < 0 || $return['startnum'] > 255) {
				$return['error'] = 1;
				$errormsg[] = "Start must be from 0 to 255";
			}
			if($return['endnum'] < 0 || $return['endnum'] > 255) {
				$return['error'] = 1;
				$errormsg[] = "End must be from 0 to 255";
			}
			if($return['startnum'] >= 0 && $return['startnum'] <= 255 &&
			   $return['endnum'] >= 0 && $return['endnum'] <= 255 &&
			   $return['startnum'] > $return['endnum']) {
				$return['error'] = 1;
				$errormsg[] = "Start must be &gt;= End";
			}
			$checkhosts = array();
			for($i = $return['startnum']; $i <= $return['endnum']; $i++)
				$checkhosts[] = str_replace('%', $i, $return['name']);
			$allhosts = implode("','", $checkhosts);
			$query = "SELECT hostname FROM computer "
			       . "WHERE hostname IN ('$allhosts') AND "
			       .       "deleted = 0";
			$qh = doQuery($query);
			$exists = array();
			while($row = mysql_fetch_assoc($qh))
				$exists[] = $row['hostname'];
			if(count($exists)) {
				$hosts = implode(', ', $exists);
				$return['error'] = 1;
				$errormsg[] = "There are already computers with these hostnames: $hosts";
			}
		}
		else {
			$return['startnum'] = 0;
			$return['endnum'] = 0;
		}
		# owner
		if(! validateUserid($return['owner'])) {
			$return['error'] = 1;
			$errormsg[] = "Submitted owner is not valid";
		}
		# type
		if(! preg_match('/^(blade|lab|virtualmachine)$/', $return['type'])) {
			$return['error'] = 1;
			$errormsg[] = "Submitted type is not valid";
		}
		# edit or add single
		if($return['rscid'] || ($return['mode'] == 'add' && $addmode == 'single')) {
			# ipaddress
			if(! validateIPv4addr($return['IPaddress'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid Public IP address. Must be w.x.y.z with each of "
			               . "w, x, y, and z being between 1 and 255 (inclusive)";
			}
			# private ipaddress
			if(strlen($return['privateIPaddress']) &&
			   ! validateIPv4addr($return['privateIPaddress'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid Private IP address. Must be w.x.y.z with each of "
			               . "w, x, y, and z being between 1 and 255 (inclusive)";
			}
			# eth0macaddress
			if(strlen($return['eth0macaddress'])) {
				if(! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $return["eth0macaddress"])) {
					$return['error'] = 1;
					$errormsg[] = "Invalid Private MAC address. Must be XX:XX:XX:XX:XX:XX "
					            . "with each pair of XX being from 00 to FF (inclusive)";
				}
				elseif($this->checkForMACaddress($return['eth0macaddress'], 0, $return['rscid'])) {
					$return['error'] = 1;
					$errormsg[] = "There is already a computer with this Private MAC address.";
				}
			}
			# eth1macaddress
			if(strlen($return['eth1macaddress'])) {
				if(! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $return["eth1macaddress"])) {
					$return['error'] = 1;
					$errormsg[] = "Invalid Public MAC address. Must be XX:XX:XX:XX:XX:XX "
					            . "with each pair of XX being from 00 to FF (inclusive)";
				}
				elseif($this->checkForMACaddress($return['eth1macaddress'], 1, $return['rscid'])) {
					$return['error'] = 1;
					$errormsg[] = "There is already a computer with this Public MAC address.";
				}
			}
		}
		else {
			$return['IPaddress'] = '';
			$return['privateIPaddress'] = '';
			$return['eth0macaddress'] = '';
			$return['eth1macaddress'] = '';
		}
		# add multiple
		if($return['mode'] == 'add' && $addmode == 'multiple') {
			if(! validateIPv4addr($return['startpubipaddress'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid Start Public IP address. Must be w.x.y.z with each of "
			               . "w, x, y, and z being between 1 and 255 (inclusive)";
			}
			if(! validateIPv4addr($return['endpubipaddress'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid End Public IP address. Must be w.x.y.z with each of "
			               . "w, x, y, and z being between 1 and 255 (inclusive)";
			}
			if(! validateIPv4addr($return['startprivipaddress'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid Start Private IP address. Must be w.x.y.z with each of "
			               . "w, x, y, and z being between 1 and 255 (inclusive)";
			}
			if(! validateIPv4addr($return['endprivipaddress'])) {
				$return['error'] = 1;
				$errormsg[] = "Invalid End Private IP address. Must be w.x.y.z with each of "
			               . "w, x, y, and z being between 1 and 255 (inclusive)";
			}
			$startpubiplong = ip2long($return['startpubipaddress']);
			$endpubiplong = ip2long($return['endpubipaddress']);
			if($startpubiplong > $endpubiplong) {
				$return['error'] = 1;
				$errormsg[] = "Start Public IP Address must be lower or equal to End Public IP Address";
			}
			elseif(($endpubiplong - $startpubiplong) != ($return['endnum'] - $return['startnum'])) {
				$return['error'] = 1;
				$errormsg[] = "Public IP Address range does not equal Start/End range";
			}
			$startpriviplong = ip2long($return['startprivipaddress']);
			$endpriviplong = ip2long($return['endprivipaddress']);
			if($startpriviplong > $endpriviplong) {
				$return['error'] = 1;
				$errormsg[] = "Start Private IP Address must be lower or equal to End Private IP Address";
			}
			elseif(($endpriviplong - $startpriviplong) != ($return['endnum'] - $return['startnum'])) {
				$return['error'] = 1;
				$errormsg[] = "Private IP Address range does not equal Start/End range";
			}
			$return['startpubiplong'] = $startpubiplong;
			$return['endpubiplong'] = $endpubiplong;
			$return['startpriviplong'] = $startpriviplong;
			$return['endpriviplong'] = $endpriviplong;
			$cnt = $endpubiplong - $startpubiplong + 1;
			if($return['startmac'] != '') {
				if(! preg_match('/^(([A-Fa-f0-9]){2}:){5}([A-Fa-f0-9]){2}$/', $return['startmac'])) {
					$return['error'] = 1;
					$errormsg[] = "Invalid Start MAC address. Must be XX:XX:XX:XX:XX:XX "
					            . "with each pair of XX being from 00 to FF (inclusive)";
				}
				elseif($this->checkMultiAddMacs($return['startmac'], $cnt, $msg, $macs)) {
					$return['error'] = 1;
					$errormsg[] = $msg;
				}
				$return['macs'] = $macs;
			}
			else
				$return['macs'] = array();
		}
		else {
			$return['startpubipaddress'] = '';
			$return['endpubipaddress'] = '';
			$return['startprivipaddress'] = '';
			$return['endprivipaddress'] = '';
			$return['startmac'] = '';
		}
		# provisioningid
		$provisioning = getProvisioning();
		if(! array_key_exists($return['provisioningid'], $provisioning)) {
			$return['error'] = 1;
			$errormsg[] = "Invalid Provisioning Engine selected";
		}
		else
			$return['provisioning'] = $provisioning[$return['provisioningid']]['name'];
		# stateid  2 - available, 10 - maintenance, 20 - vmhostinuse
		if(! preg_match('/^(2|10|20)$/', $return['stateid']) &&
		   ($return['mode'] == 'add' || $return['stateid'] != $olddata['stateid'])) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for State";
		}
		# validate type/provisioning combinations
		$provtypes = getProvisioningTypes();
		if(($return['mode'] == 'add' || $olddata['provisioningid'] != $return['provisioningid']) &&
		   ! array_key_exists($return['provisioningid'], $provtypes[$return['type']])) {
			$return['error'] = 1;
			$errormsg[] = "Invalid Provisioning Engine selected for computer type";
		}
		# validate type/provisioning/state combinations
		if($return['mode'] == 'add' || $olddata['stateid'] != $return['stateid']) {
			if($return['type'] == 'lab') {
				if($return['stateid'] != 2 && $return['stateid'] != 10) {
					$return['error'] = 1;
					$errormsg[] = "Invalid state submitted for computer type Lab";
				}
			}
			elseif($return['type'] == 'virtualmachine') {
				if($return['stateid'] != 10 &&
				   ($return['mode'] == 'add' || ! is_numeric($olddata['vmhostid']) || $return['stateid'] != 2)) {
					$return['error'] = 1;
					$errormsg[] = "Invalid state submitted for computer type Virtual Machine";
				}
			}
			elseif($return['type'] == 'blade') {
				if($provisioning[$return['provisioningid']]['name'] == 'none' &&
				   $return['stateid'] != 10 && $return['stateid'] != 20) {
					$return['error'] = 1;
					$errormsg[] = "Invalid state submitted for computer type Bare Metal";
				}
			}
		}
		# notes
		if($return['stateid'] == 10) {
			if(! preg_match('/^([-a-zA-Z0-9_\. ,#\(\)=\+:;]{0,5000})$/', $return['notes'])) {
				$return['error'] = 1;
				$errormsg[] = "Maintenance reason can be up to 5000 characters long and may only<br>contain letters, numbers, spaces and these characters: - , . _ # ( ) = + : ;";
			}
		}
		else
			$return['notes'] = '';
		# vmprofileid
		$profiles = getVMProfiles();
		if($return['type'] == 'blade' && $return['stateid'] == 20 &&
		   ! array_key_exists($return['vmprofileid'], $profiles)) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for VM Host Profile";
		}
		# platformid
		$platforms = getPlatforms();
		if(! array_key_exists($return['platformid'], $platforms)) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for Platform";
		}
		# scheduleid
		$schedules = getSchedules();
		if(! array_key_exists($return['scheduleid'], $schedules)) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for Schedule";
		}
		# ram
		if($return['ram'] < 500 || $return['ram'] > 16777215) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for RAM";
		}
		# cores
		if($return['cores'] < 1 || $return['cores'] > 255) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for Cores";
		}
		# procspeed
		if($return['procspeed'] < 500 || $return['procspeed'] > 10000) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for Processor Speed";
		}
		# network
		if(! preg_match('/^(10|100|1000|10000|100000)$/', $return['network'])) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for Network";
		}
		# predictivemoduleid
		$premodules = getPredictiveModules();
		if(! array_key_exists($return['predictivemoduleid'], $premodules)) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for Predictive Loading Module";
		}
		$naterror = 0;
		# natenabled
		if($return['natenabled'] != 0 && $return['natenabled'] != 1) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value for Connect Using NAT";
			$naterror = 1;
		}
		# nathostid
		$nathosts = getNAThosts();
		if(($return['natenabled'] && $return['nathostid'] == 0) ||
		   ($return['nathostid'] != 0 && ! array_key_exists($return['nathostid'], $nathosts))) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for NAT Host";
			$naterror = 1;
		}
		# nat change - check for active reservations
		$vclreloadid = getUserlistID('vclreload@Local');
		if($return['mode'] == 'edit') {
			if($olddata['nathostid'] == '')
				$olddata['nathostid'] = 0;
			if(! $naterror && ($olddata['natenabled'] != $return['natenabled'] ||
			   $olddata['nathostid'] != $return['nathostid'])) {
				$query = "SELECT rq.id "
				       . "FROM request rq, "
				       .      "reservation rs "
				       . "WHERE rs.requestid = rq.id AND "
				       .       "rs.computerid = {$return['rscid']} AND "
				       .       "rq.start <= NOW() AND "
				       .       "rq.end > NOW() AND "
				       .       "rq.stateid NOT IN (1,5,11,12) AND "
				       .       "rq.laststateid NOT IN (1,5,11,12) AND "
				       .       "rq.userid != $vclreloadid";
				$qh = doQuery($query);
				if(mysql_num_rows($qh)) {
					$return['error'] = 1;
					$errormsg[] = "This computer has an active reservation. NAT settings cannot be changed for computers having<br>active reservations.";
				}
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
		if($return['nathostenabled'] &&
		   ($return['mode'] == 'edit' || $addmode == 'single')) {
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
					$errormsg[] = "This computer is the NAT host for other computers that have active reservations. NAT host<br>settings cannot be changed while providing NAT for active reservations.";
				}
			}
		}
		# location
		if(! preg_match('/^([-a-zA-Z0-9_\. ,@#\(\)]{0,255})$/', $return['location'])) {
			$return['error'] = 1;
			$errormsg[] = "Invalid value submitted for Location";
		}

		if($return['mode'] == 'add')
			$return['addmode'] = $addmode;

		if($return['error'])
			$return['errormsg'] = implode('<br>', $errormsg);

		return $return;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkForHostname($hostname, $compid)
	///
	/// \param $hostname - a computer hostname
	/// \param $compid - (optional) a computer id to ignore
	///
	/// \return 1 if $hostname is already in the computer table, 0 if not
	///
	/// \brief checks for $hostname being somewhere in the computer table except
	/// for $compid
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkForHostname($hostname, $compid='') {
		$query = "SELECT id FROM computer "
		       . "WHERE hostname = '$hostname' AND "
		       .       "deleted = 0";
		if(! empty($compid))
			$query .= " AND id != $compid";
		$qh = doQuery($query);
		if(mysql_num_rows($qh))
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkForMACaddress($mac, $num, $compid)
	///
	/// \param $mac - computer mac address
	/// \param $num - which mac address to check - 0 or 1
	/// \param $compid - (optional) a computer id to ignore
	///
	/// \return 1 if $mac/$num is already in the computer table, 0 if not
	///
	/// \brief checks for $mac being somewhere in the computer table except
	/// for $compid
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkForMACaddress($mac, $num, $compid='') {
		if($num == 0)
			$field = 'eth0macaddress';
		else
			$field = 'eth1macaddress';
		$query = "SELECT id FROM computer "
		       . "WHERE $field = '$mac' AND "
		       .       "deleted = 0";
		if(! empty($compid))
			$query .= " AND id != $compid";
		$qh = doQuery($query);
		if(mysql_num_rows($qh))
			return 1;
		return 0;
	}
	
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkForIPaddress($ipaddress, $type, $compid)
	///
	/// \param $ipaddress - a computer ip address
	/// \param $type - 'public' or 'private' - which IP address to check
	/// \param $compid - (optional) a computer id to ignore
	///
	/// \return 1 if $ipaddress is already in the computer table, 0 if not
	///
	/// \brief checks for $ipaddress being somewhere in the computer table except
	/// for $compid
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkForIPaddress($ipaddress, $type, $compid='') {
		if($type == 'public')
			$field = 'IPaddress';
		else
			$field = 'privateIPaddress';
		$query = "SELECT id FROM computer "
		       . "WHERE $field = '$ipaddress'";
		if(! empty($compid))
			$query .= " AND id != $compid";
		$qh = doQuery($query);
		if(mysql_num_rows($qh))
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addResource($data)
	///
	/// \param $data - array of needed data for adding a new resource
	///
	/// \return id of new resource
	///
	/// \brief handles adding a new computer and other associated data to the
	/// database
	///
	/////////////////////////////////////////////////////////////////////////////
	function addResource($data) {
		global $user;
		$ownerid = getUserlistID($data['owner']);
		$noimageid = getImageId('noimage');
		$norevid = getProductionRevisionid($noimageid);
		$keys = array('hostname',         'ownerid',
		              'type',             'IPaddress',
		              'privateIPaddress', 'eth0macaddress',
		              'eth1macaddress',   'provisioningid',
		              'stateid',          'platformid',
		              'scheduleid',       'RAM',
		              'procnumber',       'procspeed',
		              'network',          'currentimageid',
		              'imagerevisionid',  'location',
		              'predictivemoduleid');
		if($data['addmode'] == 'single') {
			$eth0 = "'{$data['eth0macaddress']}'";
			if($data['eth0macaddress'] == '')
				$eth0 = 'NULL';
			$eth1 = "'{$data['eth1macaddress']}'";
			if($data['eth1macaddress'] == '')
				$eth1 = 'NULL';
			$values = array("'{$data['name']}'",             $ownerid,
			                "'{$data['type']}'",          "'{$data['IPaddress']}'",
			                "'{$data['privateIPaddress']}'", $eth0,
			                   $eth1,                        $data['provisioningid'],
			                   $data['stateid'],             $data['platformid'],
			                   $data['scheduleid'],          $data['ram'],
			                   $data['cores'],               $data['procspeed'],
			                   $data['network'],             $noimageid,
			                   $norevid,                  "'{$data['location']}'",
			                   $data['predictivemoduleid']);
	
			$query = "INSERT INTO computer ("
			       . implode(', ', $keys) . ") VALUES ("
			       . implode(', ', $values) . ")";
			doQuery($query);
	
			$rscid = dbLastInsertID();

			# vmhost entry
			if($data['stateid'] == '20') {
				$query = "INSERT INTO vmhost "
				       .        "(computerid, "
				       .        "vmprofileid) "
				       . "VALUES ($rscid, "
				       .        "{$data['vmprofileid']})";
				doQuery($query);
			}

			# NAT
			if($data['natenabled']) {
				$query = "INSERT INTO nathostcomputermap "
				       .        "(computerid, "
				       .        "nathostid) "
				       . "VALUES ($rscid, "
				       .        "{$data['nathostid']})";
				doQuery($query);
			}

			// add entry in resource table
			$query = "INSERT INTO resource "
					 .        "(resourcetypeid, "
					 .        "subid) "
					 . "VALUES (12, "
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

			return $rscid;
		}
		else {
			# add multiple computers
			$alldis = array();
			for($i = $data['startnum'], $cnt = 0; $i <= $data['endnum']; $i++, $cnt++) {
				$hostname = str_replace('%', $i, $data["name"]);
				$pubip = long2ip($data['startpubiplong'] + $cnt);
				$privip = long2ip($data['startpriviplong'] + $cnt);
				if(count($data['macs'])) {
					$eth0 = "'" . $data['macs'][$cnt * 2] . "'";
					$eth1 = "'" . $data['macs'][($cnt * 2) + 1] . "'";
				}
				else {
					$eth0 = 'NULL';
					$eth1 = 'NULL';
				}
				$values = array("'$hostname'",          $ownerid,
				                "'{$data['type']}'",  "'$pubip'",
				                 "'$privip'",           $eth0,
				                   $eth1,               $data['provisioningid'],
				                   $data['stateid'],    $data['platformid'],
				                   $data['scheduleid'], $data['ram'],
				                   $data['cores'],      $data['procspeed'],
				                   $data['network'],    $noimageid,
				                   $norevid,         "'{$data['location']}'",
				                   $data['predictivemoduleid']);
		
				$query = "INSERT INTO computer ("
				       . implode(', ', $keys) . ") VALUES ("
				       . implode(', ', $values) . ")";
				doQuery($query);
		
				$rscid = dbLastInsertID();
	
				# vmhost entry
				if($data['stateid'] == '20') {
					$query = "INSERT INTO vmhost "
					       .        "(computerid, "
					       .        "vmprofileid) "
					       . "VALUES ($rscid, "
					       .        "{$data['vmprofileid']})";
					doQuery($query);
				}

				# NAT
				if($data['natenabled']) {
					$query = "INSERT INTO nathostcomputermap "
					       .        "(computerid, "
					       .        "nathostid) "
					       . "VALUES ($rscid, "
					       .        "{$data['nathostid']})";
					doQuery($query);
				}
			
				// add entry in resource table
				$query = "INSERT INTO resource "
						 .        "(resourcetypeid, "
						 .        "subid) "
						 . "VALUES (12, "
						 .         "$rscid)";
				doQuery($query);

				$allids[] = $rscid;
			}
			return $allids;
		}
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJcanceltovmhostinuse()
	///
	/// \brief cancels any reservations to place the computer in the vmhostinuse
	/// state
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJcanceltovmhostinuse() {
		global $mysql_link_vcl;
		$compid = getContinuationVar('compid');
		$type = 'none';
		$query = "DELETE FROM request "
		       . "WHERE start > NOW() AND "
		       .       "stateid = 21 AND "
		       .       "id IN (SELECT requestid "
		       .              "FROM reservation "
		       .              "WHERE computerid = $compid)";
		doQuery($query);
		if(mysql_affected_rows($mysql_link_vcl))
			$type = 'future';
		$query = "UPDATE request rq, "
		       .         "reservation rs, "
		       .         "state ls "
		       . "SET rq.stateid = 1 "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid = $compid AND "
		       .       "rq.start <= NOW() AND "
		       .       "rq.laststateid = ls.id AND "
		       .       "ls.name = 'tovmhostinuse'";
		doQuery($query);
		if(mysql_affected_rows($mysql_link_vcl))
			$type = 'current';
		$query = "SELECT rq.start "
		       . "FROM request rq, "
		       .      "reservation rs, "
		       .      "state ls, "
		       .      "state cs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid = $compid AND "
		       .       "rq.laststateid = ls.id AND "
		       .       "rq.stateid = cs.id AND "
		       .       "ls.name = 'tovmhostinuse' AND "
		       .       "cs.name NOT IN ('failed', 'maintenance', 'complete', 'deleted') AND "
		       .       "rq.end > NOW() "
		       . "ORDER BY rq.start";
		$qh = doQuery($query);
		if(mysql_num_rows($qh))
			$arr = array('status' => 'failed');
		else {
			if($type == 'now')
				$msg = "The reservation currently being processed to place this "
				     . "computer in the vmhostinuse state has been flagged for "
				     . "deletion. As soon as the deletion can be processed, the "
				     . "computer will be set to the available state.";
			else
				$msg = "The reservation scheduled to place this computer in the "
				     . "vmhostinuse state has been deleted.";
			$arr = array('status' => 'success', 'msg' => $msg);
		}
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn scheduleTovmhostinuse($compid, $imageid, $start, $vmprofileid,
	///                           $oldvmprofileid)
	///
	/// \param $compid - id of a computer
	/// \param $imageid - id of an image
	/// \param $start - start time in unix timestamp format
	/// \param $vmprofileid - id of vmprofile
	/// \param $oldvmprofileid - id of possible previous vmprofile
	///
	/// \return 0 on failure, 1 on success
	///
	/// \brief schedules or updates a reservation to move a host to the
	/// vmhostinuse state
	///
	/////////////////////////////////////////////////////////////////////////////
	function scheduleTovmhostinuse($compid, $imageid, $start, $vmprofileid,
	                               $oldvmprofileid) {
		# create a reload reservation to load machine with image
		#   corresponding to selected vm profile
		$vclreloadid = getUserlistID('vclreload@Local');
		$revid = getProductionRevisionid($imageid);
		$end = $start + SECINYEAR; # don't want anyone making a future reservation for this machine
		$startdt = unixToDatetime($start);
		$enddt = unixToDatetime($end);
		$failed = 0;

		$mnid = findManagementNode($compid, $startdt, 'now');
		if($mnid == 0)
			return 0;

		# check for existing tovmhostinuse reservation
		$query = "SELECT rq.id, "
		       .        "rq.start, "
		       .        "rq.end, "
		       .        "rs.imageid "
		       . "FROM request rq, "
		       .      "reservation rs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid = $compid AND "
		       .       "rq.stateid = 21 AND "
		       .       "rq.start > NOW() "
		       . "ORDER BY rq.start "
		       . "LIMIT 1";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh)) {
			if(! retryGetSemaphore($imageid, $revid, $mnid, $compid, $startdt, $enddt, $row['id']))
				return 0;
			# update existing reservation
			$updates = array();
			$startts = datetimeToUnix($row['start']);
			if($start < $startts)
				$updates[] = "rq.start = '$startdt'";
			elseif($start > $startts)
				$this->startchange = $startts;
			if($row['imageid'] != $imageid)
				$updates[] = "rs.imageid = $imageid";
			if(count($updates)) {
				$query = "UPDATE request rq, "
				       .        "reservation rs "
				       . "SET " . implode(',', $updates) 
				       ." WHERE rs.requestid = rq.id AND "
				       .       "rq.id = {$row['id']}";
				doQuery($query);
			}
		}
		else {
			if(! retryGetSemaphore($imageid, $revid, $mnid, $compid, $startdt, $enddt))
				return 0;
			# add new reservation
			if(! (simpleAddRequest($compid, $imageid, $revid, $startdt, $enddt, 21,
			                       $vclreloadid)))
				return 0;
		}

		cleanSemaphore();

		$this->updateVmhostProfile($compid, $vmprofileid, $oldvmprofileid);

		return 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn updateVmhostProfile($compid, $newprofileid, $oldprofileid)
	///
	/// \param $compid - id of computer
	/// \param $newprofileid - id of new vmprofile
	/// \param $oldprofileid - id of possible previous vmprofile
	///
	/// \brief updates a vmhost entry's vmprofileid or creates a new vmhost entry
	///
	/////////////////////////////////////////////////////////////////////////////
	function updateVmhostProfile($compid, $newprofileid, $oldprofileid) {
		if(is_numeric($oldprofileid)) {
			if($oldprofileid != $newprofileid) {
				# update existing entry
				$query = "UPDATE vmhost "
				       . "SET vmprofileid = $newprofileid "
				       . "WHERE computerid = $compid AND "
				       .       "vmprofileid = $oldprofileid";
				doQuery($query);
			}
		}
		else {
			# create vmhost entry
			$query = "INSERT INTO vmhost "
			       .        "(computerid, "
			       .        "vmprofileid) "
			       . "VALUES ($compid, "
			       .        "$newprofileid)";
			doQuery($query);
		}
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitComputerStateLater()
	///
	/// \brief schedules a computer to be converted to another state at a future
	/// time
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitComputerStateLater() {
		$compid = getContinuationVar('compid');
		$maintenanceonly = getContinuationVar('maintenanceonly', 0);
		$start = getContinuationVar('reloadstart');
		$end = $start + SECINYEAR;
		$startdt = unixToDatetime($start);
		$enddt = unixToDatetime($end);
		$vmprofileid = getContinuationVar('vmprofileid', 0);
		$oldprofileid = getContinuationVar('oldprofileid', 0);
		$newstateid = getContinuationVar('newstateid', 0);
		$oldstateid = getContinuationVar('oldstateid', 0);
		$imageid = getContinuationVar('imageid');
		$revid = getProductionRevisionid($imageid);
		$mode = processInputVar('mode', ARG_STRING);
		$msg = '';
		$refreshcount = 0;

		if($oldstateid == 10 && $newstateid == 20 &&
		   ! is_null($mode) && $mode != 'direct' && $mode != 'reload') {
			$errmsg = "Invalid information submitted";
			$ret = array('status' => 'error',
			             'errormsg' => $errmsg);
			sendJSON($ret);
			return;
		}

		$delayed = 0;

		# maintenance directly back to vmhostinuse
		if($mode == 'direct') {
			$vmids = getContinuationVar('vmids');
			if(count($vmids)) {
				$allids = implode(',', $vmids);
				$query = "UPDATE computer "
				       . "SET stateid = 2, "
				       .     "notes = '' "
				       . "WHERE id in ($allids)";
				doQuery($query);
			}
			$query = "UPDATE computer "
			       . "SET stateid = 20, "
			       .     "notes = '' "
			       . "WHERE id = $compid";
			doQuery($query);
			$msg .= "The computer has been moved back to the vmhostinuse state and ";
			$msg .= "the appropriate VMs have been moved to the available state.";
			$title = "Change to vmhostinuse";
			$refreshcount = 1;
		}
		# maintenance back to vmhostinuse with a reload
		elseif($mode == 'reload') {
			$vmids = getContinuationVar('vmids');
			if(count($vmids))
				$this->scheduleVMsToAvailable($vmids);
			$start = getReloadStartTime();
			$rc = $this->scheduleTovmhostinuse($compid, $imageid, $start,
			                                   $vmprofileid, $oldprofileid);

			if($rc == 0) {
				$errmsg .= "A problem was encountered while attempting to reload the ";
				$errmsg .= "computer with the selected VM Host Profile. Please try ";
				$errmsg .= "again at a later time.\n";
				$errmsg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $errmsg);
				$ret = array('status' => 'error',
				             'errormsg' => $errmsg);
				sendJSON($ret);
				return;
			}
			$msg .= "The computer has been scheduled to go back to the vmhostinuse ";
			$msg .= "state and the appropriate VMs have been scheduled to go back ";
			$msg .= "to the available state at %s.";
			$title = "Change to vmhostinuse";
		}
		# anything else to vmhostinuse
		elseif($oldstateid != 20 && $newstateid == 20) {
			moveReservationsOffComputer($compid);
			cleanSemaphore();
	
			$mnid = findManagementNode($compid, unixToDatetime($start), 'future');
			$tmp = getCompFinalReservationTime($compid, 21);
			$checkstart = getExistingChangeStateStartTime($compid, 21);
			if(! $checkstart && $checkstart != $start && $tmp > $start) {
				$delayed = 1;
				$start = $tmp;
				$end = $start + SECINYEAR;
				$startdt = unixToDatetime($start);
				$enddt = unixToDatetime($end);
			}
			$vclreloadid = getUserlistID('vclreload@Local');
			if($maintenanceonly) {
				if(! retryGetSemaphore($imageid, $revid, $mnid, $compid, $start, $end)) {
					$errmsg  = "An error was encountered while trying to schedule this<br>\n";
					$errmsg .= "computer for the maintenance state. Please try again later.\n";
					$ret = array('status' => 'error',
					             'errormsg' => $errmsg);
					sendJSON($ret);
					return;
				}
				# create a tomaintenance reservation
				if(! (simpleAddRequest($compid, $imageid, $revid, $startdt, $enddt,
				                       18, $vclreloadid))) {
					$errmsg  = "An error was encountered while trying to schedule this<br>\n";
					$errmsg .= "computer for the maintenance state. Please try again later.\n";
					$ret = array('status' => 'error',
					             'errormsg' => $errmsg);
					sendJSON($ret);
					cleanSemaphore();
					return;
				}
				$msg .= "The computer has been scheduled to be moved to the ";
				$msg .= "maintenance state at %s.";
				$title = "Change to maintenance state";
			}
			else {
				# create a reload reservation to load machine with image
				#   corresponding to selected vm profile
				$rc = $this->scheduleTovmhostinuse($compid, $imageid, $start,
				                                   $vmprofileid, $oldprofileid);
				if(isset($this->startchange)) {
					$start = $this->startchange;
					$delayed = 1;
				}
				if($rc == 0) {
					$errmsg  = "An error was encountered while trying to convert this ";
					$errmsg .= "computer to a VM host server. Please try again later.";
					$errmsg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $errmsg);
					$ret = array('status' => 'error',
					             'errormsg' => $errmsg);
					sendJSON($ret);
					return;
				}
				$msg .= "The computer has been scheduled to be moved to the ";
				$msg .= "vmhostinuse state at %s.";
				$title = "Change to vmhostinuse state";
			}
			cleanSemaphore();
		}
		# vmhostinuse to available
		elseif($oldstateid == 20 && $newstateid == 2) {
			$tmp = getCompFinalVMReservationTime($compid, 1);
			if($tmp == -1) {
				$errmsg .= "A problem was encountered while attempting to schedule ";
				$errmsg .= "assigned VMs to be removed from the computer. Please ";
				$errmsg .= "try again at a later time.\n";
				$errmsg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $errmsg);
				$ret = array('status' => 'error',
				             'errormsg' => $errmsg);
				sendJSON($ret);
				return;
			}
			elseif($tmp > $start) {
				$delayed = 1;
				$start = $tmp;
				$end = $start + SECINYEAR;
				$startdt = unixToDatetime($start);
				$enddt = unixToDatetime($end);
			}
			$vclreloadid = getUserlistID('vclreload@Local');
			$query = "SELECT vm.id "
			       . "FROM computer vm, "
			       .      "vmhost v "
			       . "WHERE v.computerid = $compid AND "
			       .       "vm.vmhostid = v.id";
			$qh = doQuery($query);
			$fail = 0;
			while($row = mysql_fetch_assoc($qh)) {
				if(! simpleAddRequest($row['id'], $imageid, $revid, $startdt,
				                      $enddt, 18, $vclreloadid)) {
					$fail = 1;
					break;
				}
			}
			cleanSemaphore();
			if($fail) {
				$errmsg  = "A problem was encountered while attempting to remove VMs ";
				$errmsg .= "from the computer. Please try again at a later time.\n";
				$errmsg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $errmsg);
				$ret = array('status' => 'error',
				             'errormsg' => $errmsg);
				sendJSON($ret);
				return;
			}
			else {
				$start = $start + 300;
				$end = $start + SECINYEAR;
				$startdt = unixToDatetime($start);
				$enddt = unixToDatetime($end);
				if(! simpleAddRequest($compid, $imageid, $revid, $startdt,
				                      $enddt, 19, $vclreloadid)) {
					$errmsg  = "A problem was encountered while attempting to schedule ";
					$errmsg .= "the computer back to the available state. Please try ";
					$errmsg .= "again at a later time.\n";
					$errmsg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $errmsg);
					$title = 'Change State to Available Failed';
					$ret = array('status' => 'error',
					             'errormsg' => $errmsg);
					sendJSON($ret);
					return;
				}
				$msg .= "The computer has been scheduled to be moved to the ";
				$msg .= "available state at %s.";
				$title = "Change to available state";
			}
		}
		# vmhostinuse to maintenance
		# vmhostinuse to vmhostinuse with a profile change
		elseif(($oldstateid == 20 && $newstateid == 10) ||
		      ($oldstateid == 20 && $newstateid == 20 &&
		       $oldprofileid != $vmprofileid)) {

			if($newstateid == 10) {
				$tomaintenance = 1;
				$reloadstateid = 18;
			}
			else {
				$tomaintenance = 0;
				$reloadstateid = 21;
			}

			moveReservationsOffVMs($compid);
			cleanSemaphore();
	
			$mnid = findManagementNode($compid, unixToDatetime($start), 'future');
			$tmp = getCompFinalVMReservationTime($compid, 1, 1);
			if($tmp == -1) {
				if($tomaintenance) {
					$errmsg .= "A problem was encountered while attempting to schedule ";
					$errmsg .= "assigned VMs to be moved to the maintenance state. ";
					$errmsg .= "Please try again at a later time.\n";
				}
				else {
					$errmsg .= "A problem was encountered while attempting to schedule ";
					$errmsg .= "assigned VMs to be moved to the maintenance state while ";
					$errmsg .= "the computer is reloaded. Please try again at a later time.\n";
				}
				$errmsg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $errmsg);
				$ret = array('status' => 'error',
				             'errormsg' => $errmsg);
				sendJSON($ret);
				return;
			}
			elseif($tmp > $start)
				$delayed = 1;
			$vclreloadid = getUserlistID('vclreload@Local');
			$start = $tmp;
			$end = $start + SECINYEAR;
			$startdt = unixToDatetime($start);
			$enddt = unixToDatetime($end);
			$fail = 0;
			$vmids = array();
			$query = "SELECT vm.id "
			       . "FROM computer vm, "
			       .      "vmhost v "
			       . "WHERE v.computerid = $compid AND "
			       .       "vm.vmhostid = v.id";
			$qh = doQuery($query);
			while($row = mysql_fetch_assoc($qh)) {
				$checkstart = getExistingChangeStateStartTime($row['id'], 18);
				if($checkstart) {
					if($checkstart > $start)
						# update start time of existing tomaintenance reservation
						updateExistingToState($row['id'], $startdt, 18);
					# leave existing tomaintenance reservation as is
				}
				elseif(! simpleAddRequest($row['id'], $imageid, $revid, $startdt,
				                      $enddt, 18, $vclreloadid)) {
					$fail = 1;
					break;
				}
				$vmids[] = $row['id'];
			}
			if(count($vmids)) {
				$allids = implode(',', $vmids);
				$query = "UPDATE computer "
				       . "SET notes = 'maintenance with host $compid' "
				       . "WHERE id IN ($allids)";
				doQuery($query);
			}
			cleanSemaphore();
			if($fail) {
				$errmsg  = "A problem was encountered while attempting to schedule ";
				$errmsg .= "the VMs to the maintenance state. Please try ";
				$errmsg .= "again at a later time.\n";
				$errmsg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $errmsg);
				$ret = array('status' => 'error',
				             'errormsg' => $errmsg);
				sendJSON($ret);
				return;
			}
			else {
				$start = $start + 300;
				$end = $start + SECINYEAR;
				$startdt = unixToDatetime($start);
				$enddt = unixToDatetime($end);
				$checkstart = getExistingChangeStateStartTime($compid, 18);
				if($checkstart) {
					if($checkstart > $start)
						# update start time of existing tomaintenance reservation
						updateExistingToState($compid, $startdt, 18);
					# leave existing tomaintenance reservation as is
				}
				elseif(! simpleAddRequest($compid, $imageid, $revid, $startdt,
				                          $enddt, $reloadstateid, $vclreloadid)) {
					if($tomaintenance) {
						$errmsg  = "A problem was encountered while attempting to schedule ";
						$errmsg .= "the node to the maintenance state. Please try ";
						$errmsg .= "again at a later time.\n";
					}
					else {
						$errmsg  = "A problem was encountered while attempting to schedule ";
						$errmsg .= "the node to be reloaded. Please try again at a later time.\n";
					}
					$errmsg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $errmsg);
					$ret = array('status' => 'error',
					             'errormsg' => $errmsg);
					sendJSON($ret);
					return;
				}
				if($tomaintenance) {
					$msg .= "The computer has been scheduled to be moved to the ";
					$msg .= "maintenance state at %s.";
					$title = "Change to maintenance state";
				}
				else {
					$msg .= "The computer has been scheduled to be reloaded with ";
					$msg .= "the selected VM Host Profile at %s.";
					$title = "Reload Computer";
				}
			}
		}
		# anything else to maintenance
		elseif($oldstateid != 10 && $newstateid == 10) {
			$mnid = findManagementNode($compid, unixToDatetime($start), 'future');
			if(! retryGetSemaphore($imageid, $revid, $mnid, $compid, $start, $end)) {
				$errmsg  = "An error was encountered while trying to schedule this<br>\n";
				$errmsg .= "computer for the maintenance state. Please try again later.\n";
				$ret = array('status' => 'error',
				             'errormsg' => $errmsg);
				sendJSON($ret);
				return;
			}
			# create a tomaintenance reservation
			$vclreloadid = getUserlistID('vclreload@Local');
			if(! (simpleAddRequest($compid, $imageid, $revid, $startdt, $enddt,
			                       18, $vclreloadid))) {
				$errmsg  = "An error was encountered while trying to schedule this<br>\n";
				$errmsg .= "computer for the maintenance state. Please try again later.\n";
				$ret = array('status' => 'error',
				             'errormsg' => $errmsg);
				sendJSON($ret);
				cleanSemaphore();
				return;
			}
			$msg .= "The computer has been scheduled to be moved to the ";
			$msg .= "maintenance state at %s.";
			$title = "Change to maintenance state";
		}
		if($delayed) {
			$note  = "<strong>NOTE: The time for the scheduled change has been updated ";
			$note .= "from what was previously reported.</strong><br>\n";
			$msg = $note . $msg;
		}
		$schtime = date('g:i a \o\n n/j/y', $start);
		$msg = sprintf($msg, $schtime);
		$msg = preg_replace("/(.{1,76}([ \n]|$))/", '\1<br>', $msg);

		$ret = array('status' => 'success',
		             'title' => $title,
		             'clearselection' => 1,
		             'refreshcount' => $refreshcount,
		             'msg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJreloadComputers()
	///
	/// \brief confirms reloading of computers with specified image
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJreloadComputers() {
		$imageid = processInputVar('imageid', ARG_NUMERIC);
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"));
		if(! array_key_exists($imageid, $resources['image'])) {
			$ret = array('status' => 'noaccess');
			sendJSON($ret);
			return;
		}
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$computers = $this->getData($this->defaultGetDataArgs);
		$imagedata = getImages(0, $imageid);
		$reloadnow = array();
		$reloadasap = array();
		$noreload = array();
		foreach($compids as $compid) {
			switch($computers[$compid]['state']) {
				case "available":
				case "failed":
				case "reloading":
					$reloadnow[] = $compid;
					break;
				case "inuse":
				case "timeout":
				case "reserved":
					$reloadasap[] = $compid;
					break;
				case "maintenance":
					$noreload[] = $compid;
					break;
				default:
					$noreload[] = $compid;
					break;
			}
		}
		$msg = '';
		if(count($reloadnow)) {
			$msg .= "The following computers will be immediately reloaded with ";
			$msg .= "<strong>{$imagedata[$imageid]['prettyname']}</strong>:<br>\n";
			foreach($reloadnow as $compid)
				$msg .= "<span class=\"ready\">{$computers[$compid]['hostname']}</span><br>\n";
			$msg .= "<br>\n";
		}

		if(count($reloadasap)) {
			$msg .= "The following computers are currently in use and will have ";
			$msg .= "<strong>{$imagedata[$imageid]['prettyname']}</strong> set as ";
			$msg .= "a priority for reloading at the end of the existing reservation ";
			$msg .= "on each node:<br>\n";
			foreach($reloadasap as $compid)
				$msg .= "<span class=\"wait\">{$computers[$compid]['hostname']}</span><br>\n";
			$msg .= "<br>\n";
		}

		if(count($noreload)) {
			$msg .= "The following computers are currently in the maintenance ";
			$msg .= "state and therefore will have nothing done to them:<br>\n";
			foreach($noreload as $compid)
				$msg .= "<span class=\"rederrormsg\">{$computers[$compid]['hostname']}</span><br>\n";
			$msg .= "<br>\n";
		}

		$cdata = $this->basecdata;
		$cdata['imageid'] = $imageid;
		$cdata['imagename'] = $imagedata[$imageid]['prettyname'];
		$cdata['compids'] = $compids;
		$ret = array('status' => 'success',
		             'title' => "Reload Computers",
		             'btntxt' => 'Reload Computers',
		             'actionmsg' => $msg);
		if(count($reloadnow) || count($reloadasap)) {
			$cont = addContinuationsEntry('AJsubmitReloadComputers', $cdata, SECINDAY, 1, 0);
			$ret['cont'] = $cont;
		}
		else {
			$ret['cont'] = '';
			$ret['disablesubmit'] = 1;
		}
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitReloadComputers()
	///
	/// \brief reloads computers with specified image
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitReloadComputers() {
		$data = getContinuationVar(); # imageid, compids, imagename

		$start = getReloadStartTime();
		$end = $start + 1200; // + 20 minutes
		$startstamp = unixToDatetime($start);
		$endstamp = unixToDatetime($end);
		$imagerevisionid = getProductionRevisionid($data['imageid']);

		$computers = $this->getData($this->defaultGetDataArgs);
		$reloadnow = array();
		$reloadasap = array();
		$fails = array();
		$passes = array();

		foreach($data['compids'] as $compid) {
			if($computers[$compid]['state'] == 'available' ||
				$computers[$compid]['state'] == 'failed') {
				$mn = findManagementNode($compid, unixToDatetime($start), 1);
				if($mn == 0) {
					$fails[] = $compid;
					continue;
				}
				if(getSemaphore($data['imageid'], $imagerevisionid, $mn, $compid, $startstamp, $endstamp)) {
					$query = "SELECT rq.id "
							 . "FROM request rq, "
							 .      "reservation rs, "
							 .      "state s "
							 . "WHERE rs.requestid = rq.id AND "
							 .       "rq.stateid = s.id AND "
							 .       "rs.computerid = $compid AND "
							 .       "rq.start < '$endstamp' AND "
							 .       "rq.end > '$startstamp' AND "
							 .       "s.name NOT IN ('complete', 'deleted', 'failed', 'timeout')";
					$qh = doQuery($query);
					if(! mysql_num_rows($qh))
						$reloadnow[] = $compid;
					else
						$reloadasap[] = $compid;
				}
				else
					$reloadasap[] = $compid;
			}
		}

		$vclreloadid = getUserlistID('vclreload@Local');
		foreach($reloadnow as $compid) {
			if(simpleAddRequest($compid, $data['imageid'], $imagerevisionid, $startstamp, $endstamp, 19, $vclreloadid))
				$passes[] = $compid;
			else
				$fails[] = $compid;
		}
		// release semaphore lock on nodes
		cleanSemaphore();

		if(count($reloadasap)) {
			$compids = implode(',', $reloadasap);
			$query = "UPDATE computer "
					 . "SET nextimageid = {$data['imageid']} "
					 . "WHERE id IN ($compids)";
			doQuery($query, 101);
		}
		$msg = '';
		if(count($passes)) {
			$msg .= "The following computers are being immediately reloaded with ";
			$msg .= "<strong>{$data['imagename']}</strong>:<br>\n";
			foreach($passes as $compid)
				$msg .= "<span class=\"ready\">{$computers[$compid]['hostname']}</span><br>\n";
		}
		if(count($reloadasap)) {
			if(count($passes))
				$msg .= "<br>";
			$msg .= "The following computers have <strong>{$data['imagename']}</strong> ";
			$msg .= "set as a priority for reloading at the end of their existing ";
			$msg .= "reservations:<br>\n";
			foreach($reloadasap as $compid)
				$msg .= "<span class=\"wait\">{$computers[$compid]['hostname']}</span><br>\n";
		}
		if(count($fails)) {
			if(count($passes) || count($reloadasap))
				$msg .= "<br>";
			$msg .= "No functional management node was found for the following ";
			$msg .= "computers. They could not be reloaded at this time:<br>\n";
			foreach($fails as $compid)
				$msg .= "<span class=\"rederrormsg\">{$computers[$compid]['hostname']}</span><br>\n";
		}

		$ret = array('status' => 'success',
		             'title' => "Reload Computers",
		             'refreshcount' => 4,
		             'msg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJdeleteComputers()
	///
	/// \brief confirms deleting submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJdeleteComputers() {
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}
		$compdata = $this->getData($this->defaultGetDataArgs);
		$skipcompids = array();
		$allids = implode(',', $compids);
		$query = "SELECT rs.computerid "
		       . "FROM reservation rs, "
		       .      "request rq, "
		       .      "state s "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rq.stateid = s.id AND "
		       .       "rs.computerid in ($allids) AND "
		       .       "s.name NOT IN ('deleted', 'failed', 'complete') AND "
		       .       "rq.end > NOW()";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$skipcompids[] = $row['computerid'];
		$query = "SELECT DISTINCT bc.computerid "
		       . "FROM blockTimes bt, "
		       .      "blockComputers bc, "
		       .      "blockRequest br "
		       . "WHERE bc.computerid in ($allids) AND "
		       .       "bc.blockTimeid = bt.id AND "
		       .       "bt.blockRequestid = br.id AND "
		       .       "bt.end > NOW() AND "
		       .       "bt.skip = 0 AND "
		       .       "br.status = 'accepted'";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$skipcompids[] = $row['computerid'];
		$delids = array_diff($compids, $skipcompids);
		$msg = '';
		if(count($delids)) {
			$msg .= "Delete the following computers?<br><br>\n";
			foreach($delids as $id)
				$msg .= "{$compdata[$id]['hostname']}<br>\n";
			$msg .= '<br>';
		}
		if(count($skipcompids)) {
			$msg .= "The following computers are currently in use and cannot be ";
			$msg .= "deleted at this time:<br><br>\n";
			$msg .= "<span class=\"rederrormsg\">\n";
			foreach($skipcompids as $id)
				$msg .= "{$compdata[$id]['hostname']}<br>\n";
			$msg .= "</span>\n";
			$msg .= "<br>\n";
		}

		$cdata = $this->basecdata;
		$cdata['compids'] = $delids;
		$ret = array('status' => 'success',
		             'title' => "Delete Computers",
		             'btntxt' => 'Delete Computers',
		             'actionmsg' => $msg);
		if(count($delids)) {
			$cont = addContinuationsEntry('AJsubmitDeleteComputers', $cdata, SECINDAY, 1, 0);
			$ret['cont'] = $cont;
		}
		else {
			$ret['cont'] = '';
			$ret['disablesubmit'] = 1;
		}
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitDeleteComputers()
	///
	/// \brief flags submitted computers as deleted
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitDeleteComputers() {
		$compids = getContinuationVar('compids');

		$start = getReloadStartTime();
		$end = $start + 1200; // + 20 minutes
		$startstamp = unixToDatetime($start);
		$endstamp = unixToDatetime($end);

		$computers = $this->getData($this->defaultGetDataArgs);
		$fails = array();
		$passes = array();

		$imageid = getImageId('noimage');
		$revid = getProductionRevisionid($imageid);
		if(! ($mnid = getAnyManagementNodeID())) {
			$ret = array('status' => 'error', 'errormsg' => 'No management nodes are available for controlling the submitted computers.');
			sendJSON($ret);
			return;
		}

		foreach($compids as $compid) {
			if(retryGetSemaphore($imageid, $revid, $mnid, $compid, $startstamp, $endstamp))
				$passes[] = $compid;
			else
				$fails[] = $compid;
		}
		$allids = implode(',', $passes);
		$query = "SELECT rs.computerid "
		       . "FROM reservation rs, "
		       .      "request rq, "
		       .      "state s "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rq.stateid = s.id AND "
		       .       "rs.computerid in ($allids) AND "
		       .       "s.name NOT IN ('deleted', 'failed', 'complete') AND "
		       .       "rq.end > NOW()";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$fails[] = $row['computerid'];
		$delids = array_diff($compids, $fails);

		# FIXME this will throw an error if two computers will end up with the
		# same hostname after -UNDELETED-ID gets removed
		$allids = implode(',', $delids);
		$query = "UPDATE computer "
		       . "SET deleted = 1, "
		       .     "datedeleted = NOW(), "
		       .     "hostname = REPLACE(hostname, CONCAT('-UNDELETED-', id), ''), "
		       .     "vmhostid = NULL "
		       . "WHERE id IN ($allids)";
		doQuery($query);

		// release lock
		cleanSemaphore();

		if(count($delids)) {
			$msg  = "The following computers were deleted:<br><br>\n";
			foreach($delids as $compid)
				$msg .= "{$computers[$compid]['hostname']}<br>\n";
			$msg .= "<br>";
		}
		if(count($fails)) {
			$msg .= "The following computers are currently in use and could not be ";
			$msg .= "deleted at this time:<br><br>\n";
			$msg .= "<span class=\"rederrormsg\">\n";
			foreach($fails as $id)
				$msg .= "{$compdata[$id]['hostname']}<br>\n";
			$msg .= "<br>\n";
			$msg .= "</span>\n";
		}

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);

		$ret = array('status' => 'success',
		             'title' => "Delete Computers",
		             'clearselection' => 1,
		             'refreshcount' => 1,
		             'msg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJcompStateChange()
	///
	/// \brief confirms changing state of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJcompStateChange() {
		$newstateid = processInputVar('stateid', ARG_NUMERIC);
		$states = getContinuationVar('states');
		if(! array_key_exists($newstateid, $states)) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$cdata = $this->basecdata;
		$cdata['newstateid'] = $newstateid;

		$tmp = getUserResources(array($this->restype . "Admin"), array("administer"), 0, 1);
		$computers = $tmp['computer'];
		$msg = '';
		$complist = '';
		$compids = $this->validateCompIDs();
		if($newstateid == 2) {
			$msg .= "You are about to place the following computers into the ";
			$msg .= "available state:<br><br>\n";
			foreach($compids as $compid)
				$complist .= $computers[$compid] . "<br>\n";
			$complist .= "<br>\n";
			$cdata['compids'] = $compids;
		}
		elseif($newstateid == 10) {
			$msg .= "Please enter a reason you are changing the following computers to ";
			$msg .= "the maintenance state:<br><br>\n";
			$msg .= "<textarea ";
			$msg .=     "dojoType=\"dijit.form.Textarea\" ";
			$msg .=     "style=\"width: 30em; text-align: left;\" ";
			$msg .=     "_destroyOnRemove=\"true\" ";
			$msg .=     "id=\"utilnotes\">";
			$msg .= "</textarea><br><br>\n";
			$msg .= "These computers will be placed into the maintenance state:<br><br>\n";
			foreach($compids as $compid)
				$complist .= $computers[$compid] . "<br>\n";
			$complist .= "<br>\n";
			$cdata['compids'] = $compids;
		}
		elseif($newstateid == 20) {
			$profiles = getVMProfiles();
			$cdata['profiles'] = $profiles;
			$msg .= "Select a VM Host Profile to use on the selected computers:";
			$msg .= "<br><br>\n";
			$msg .= selectInputAutoDijitHTML('', $profiles, 'profileid');
			$msg .= "<br><br>\n";
			$msg .= "These computers will be deployed as VM Hosts:<br><br>\n";
			foreach($compids as $compid)
				$complist .= $computers[$compid] . "<br>\n";
			$complist .= "<br>\n";
			$cdata['compids'] = $compids;
		}
		elseif($newstateid == 23) {
			$msg .= "These computers will be placed into the hpc state:<br><br>\n";
			foreach($compids as $compid)
				$complist .= $computers[$compid] . "<br>\n";
			$complist .= "<br>\n";
			$cdata['compids'] = $compids;
		}

		$cont = addContinuationsEntry('AJsubmitCompStateChange', $cdata, SECINDAY, 1, 0);
		$ret = array('status' => 'success',
		             'title' => "State Change",
		             'btntxt' => 'Submit State Change',
		             'cont' => $cont,
		             'actionmsg' => $msg,
		             'complist' => $complist);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitCompStateChange()
	///
	/// \brief changes state of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitCompStateChange() {
		global $user;
		$newstateid = getContinuationVar('newstateid');
		$compids = getContinuationVar('compids');
	
		$states = getStates();
		$ret = array('status' => 'success',
		             'title' => "Change State",
		             'clearselection' => 0,
		             'newstate' => $states[$newstateid],
		             'refreshcount' => 1);
		$noimageid = getImageId('noimage');
		$norevid = getProductionRevisionid($noimageid);
		if(! ($semmnid = getAnyManagementNodeID())) {
			$ret = array('status' => 'error', 'errormsg' => 'No management nodes are available for controlling the submitted computers.');
			sendJSON($ret);
			return;
		}

		if($newstateid == 2) {
			$fails = array('provnone' => array(),
			               'reserved' => array(),
			               'hostfail' => array(),
			               'hasvms' => array());
			$availablenow = array();
			$checkvms = array();
			$checkhosts = array();
			$noaction = array();

			$computers = $this->getData($this->defaultGetDataArgs);

			$inusecompids = array();
			$allids = implode(',', $compids);
			$query = "SELECT rs.computerid "
			       . "FROM reservation rs, "
			       .      "request rq "
			       . "WHERE rs.requestid = rq.id AND "
			       .       "rq.end > NOW() AND "
			       .       "rq.start < NOW() AND "
			       .       "rq.stateid NOT IN (1, 5, 11, 12) AND " # TODO might not want 11 (timeout)
			       .       "rs.computerid IN ($allids)";
			$qh = doQuery($query);
			while($row = mysql_fetch_assoc($qh))
				$inusecompids[$row['computerid']] = 1;

			# check initial conditions
			foreach($compids as $compid) {
				# already in available
				if($computers[$compid]['state'] == 'available') {
					$noaction[] = $compid;
					continue;
				}
				# no provisioning engine
				if($computers[$compid]['provisioning'] == 'None') {
					$fails['provnone'][] = $compid;
					continue;
				}
				# non-VM in maintenance without a vmhost entry or in hpc
				if($computers[$compid]['state'] == 'hpc' ||
					($computers[$compid]['state'] == 'maintenance' &&
				    is_null($computers[$compid]['vmprofileid']) &&
				    $computers[$compid]['type'] != 'virtualmachine')) {
					$availablenow[] = $compid;
					continue;
				}
				# has active reservation
				if(array_key_exists($compid, $inusecompids)) {
					$fails['reserved'][] = $compid;
					continue;
				}
				# in reload, reloading, reserved, inuse, or failed with no active reservation
				if(preg_match('/^(reload|reloading|reserved|inuse|failed|timeout)$/',
				              $computers[$compid]['state'])) {
					$availablenow[] = $compid;
					continue;
				}
				# vmhostinuse - check for assigned VMs
				if($computers[$compid]['state'] == 'vmhostinuse') {
					$checkvms[] = $compid;
					continue;
				}
				# VM in maintenance
				if($computers[$compid]['state'] == 'maintenance' &&
				   $computers[$compid]['type'] == 'virtualmachine') {
					$checkhosts[] = $compid;
					continue;
				}
				# maintenance - check for previously being a vmhost
				if($computers[$compid]['state'] == 'maintenance' &&
				   ! is_null($computers[$compid]['vmprofileid'])) {
					$checkvms[] = $compid;
					continue;
				}
			}
			if(count($checkvms)) {
				$ids = implode(',', $checkvms);
				$query = "SELECT h.id, "
				       .        "COUNT(vm.id) AS count "
				       . "FROM computer h "
				       . "LEFT JOIN vmhost vh ON (h.id = vh.computerid) "
				       . "LEFT JOIN computer vm ON (vh.id = vm.vmhostid) "
				       . "WHERE h.id IN ($ids) "
				       . "GROUP BY vh.computerid";
				$qh = doQuery($query);
				while($row = mysql_fetch_assoc($qh)) {
					if($row['count'])
						$fails['hasvms'][] = $row['id'];
					else
						$availablenow[] = $row['id'];
				}
			}
			if(count($checkhosts)) {
				$ids = implode(',', $checkhosts);
				$query = "SELECT h.stateid, "
				       .        "vm.id "
				       . "FROM computer vm "
				       . "LEFT JOIN vmhost vh ON (vm.vmhostid = vh.id) "
				       . "LEFT JOIN computer h ON (vh.computerid = h.id) "
				       . "WHERE vm.id IN ($ids)";
				$qh = doQuery($query);
				while($row = mysql_fetch_assoc($qh)) {
					if($row['stateid'] != 20)
						$fails['hostfail'][] = $row['id'];
					else
						$availablenow[] = $row['id'];
				}
			}
			if(count($availablenow)) {
				$allids = implode(',', $availablenow);
				$query = "UPDATE computer "
						 . "SET stateid = 2, "
						 .     "notes = '' "
						 . "WHERE id IN ($allids)";
				doQuery($query);
			}

			$msg = '';
			if(count($noaction)) {
				$msg .= "The following computers were already in the available ";
				$msg .= "state:<br><br>\n";
				foreach($noaction as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "<br>\n";
			}
			if(count($availablenow)) {
				$msg .= "The following computers were changed to the available ";
				$msg .= "state:<br><br>\n";
				foreach($availablenow as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "<br>\n";
			}
			if(count($fails['provnone'])) {
				$msg .= "<span class=\"rederrormsg\">\n";
				$msg .= "The following computers cannot be in the available state ";
				$msg .= "because they have no provisioning engine:</span><br><br>\n";
				foreach($fails['provnone'] as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "<br>\n";
			}
			if(count($fails['reserved'])) {
				$msg .= "<span class=\"rederrormsg\">\n";
				$msg .= "The following computers are currently in use and could not have ";
				$msg .= "their states changed at this time:</span><br><br>\n";
				foreach($fails['reserved'] as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "<br>\n";
			}
			if(count($fails['hasvms'])) {
				$msg .= "<span class=\"rederrormsg\">\n";
				$msg .= "The following computers currently have VMs assigned to them ";
				$msg .= "and cannot be moved to available until the VMs are removed:";
				$msg .= "</span><br><br>\n";
				foreach($fails['hasvms'] as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "<br>\n";
			}
			if(count($fails['hostfail'])) {
				$msg .= "<span class=\"rederrormsg\">\n";
				$msg .= "The following VMs are not currently assigned to a host in ";
				$msg .= "the vmhostinuse state:</span><br><br>\n";
				foreach($fails['hostfail'] as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "<br>\n";
			}
		}
		# switching to maintenance or hpc
		elseif($newstateid == 10 || $newstateid == 23) {
			if($newstateid == 10) {
				$notes = processInputVar('notes', ARG_STRING);
				if(get_magic_quotes_gpc())
					$notes = stripslashes($notes);
				$notes = mysql_real_escape_string($notes);
				$notes = $user["unityid"] . " " . unixToDatetime(time()) . "@"
				       . $notes;
			}
			$vclreloadid = getUserlistID('vclreload@Local');
			$computers = $this->getData($this->defaultGetDataArgs);
			$noaction = array();
			$changenow = array();
			$changeasap = array();
			$changetimes = array();
			$vmwithhost = array();
			$fails = array();
			$semstart = unixToDatetime(time());
			$semend = '2038-01-01 00:00:00';
			foreach($compids as $compid) {
				if($newstateid == 10 &&
				   $computers[$compid]['type'] == 'virtualmachine' &&
				   in_array($computers[$compid]['vmhostcomputerid'], $compids))
					$vmwithhost[] = $compid;
				if(($newstateid == 10 && $computers[$compid]['state'] == 'maintenance') ||
				   ($newstateid == 23 && $computers[$compid]['state'] == 'hpc')) {
					$noaction[] = $compid;
					continue;
				}
				# try to move future reservations off of computer
				moveReservationsOffComputer($compid);
				cleanSemaphore();
				$reloadstart = getCompFinalReservationTime($compid);
				if($computers[$compid]['state'] == 'vmhostinuse') {
					$sem = array('imageid' => $noimageid, 'revid' => $norevid,
					             'mnid' => $semmnid, 'start' => $semstart, 'end' => $semend);
					moveReservationsOffVMs($compid, $sem);
					cleanSemaphore();
					$reloadstart = getCompFinalVMReservationTime($compid, 1, 1);
					if($reloadstart == -1) {
						cleanSemaphore();
						$fails[] = $compid;
						continue;
					}
					elseif($reloadstart > 0) {
						if(unixToDatetime($reloadstart) == '2038-01-01 00:00:00') {
							# host has a VM reserved indefintely
							$fails[] = $compid;
							continue;
						}
						# schedule tomaintenance/tohpc reservations for VMs and host
						$startdt = unixToDatetime($reloadstart);
						$end = $reloadstart + SECINMONTH;
						$enddt = unixToDatetime($end);
						$query = "SELECT vm.id "
						       . "FROM computer vm, "
						       .      "vmhost v "
						       . "WHERE v.computerid = $compid AND "
						       .       "vm.vmhostid = v.id";
						$qh = doQuery($query);
						$setnoteids = array();
						while($row = mysql_fetch_assoc($qh)) {
							$checkstart = getExistingChangeStateStartTime($row['id'], 18);
							if($checkstart) {
								if($checkstart > $reloadstart)
									# update start time of existing tomaintenance reservation
									updateExistingToState($row['id'], $startdt, 18);
								# leave existing tomaintenance reservation as is
							}
							# add tomaintenance reservation
							elseif(! simpleAddRequest($row['id'], $noimageid, $norevid, $startdt,
							                          $enddt, 18, $vclreloadid)) {
								cleanSemaphore();
								$fails[] = $compid;
								continue(2); # jump out of while, continue with foreach loop
							}
							$setnoteids[] = $row['id'];
						}
						if($newstateid == 10 && count($setnoteids)) {
							$inids = implode(',', $setnoteids);
							$query = "UPDATE computer "
							       . "SET notes = 'maintenance with host $compid' "
							       . "WHERE id IN ($inids)";
							doQuery($query);
						}
						$start = $reloadstart + 300; # allow 5 minutes for VMs to get removed
						$startdt = unixToDatetime($start);
						# lock this computer
						if(! retryGetSemaphore($noimageid, $norevid, $semmnid, $compid, $startdt, $enddt)) {
							cleanSemaphore();
							$fails[] = $compid;
							continue;
						}
						if($newstateid == 10)
							$tostateid = 18;
						else
							$tostateid = 22;
						$checkstart = getExistingChangeStateStartTime($compid, $tostateid);
						if($checkstart) {
							if($checkstart > $start)
								# update start time of existing tomaintenance/tohpc reservation
								updateExistingToState($compid, $startdt, $tostateid);
							# leave existing tomaintenance/tohpc reservation as is
						}
						elseif(! simpleAddRequest($compid, $noimageid, $norevid, $startdt,
						                          $enddt, $tostateid, $vclreloadid)) {
							cleanSemaphore();
							$fails[] = $compid;
							continue;
						}
						cleanSemaphore();
						$changetimes[$compid] = $start;
						$changeasap[] = $compid;
						continue;
					}
					else {
						if($newstateid == 10)
							$note = "maintenance with host $compid";
						else
							$note = "maintenance so $compid can go to hpc";
						# no VMs or no reservations on assigned VMs
						$query = "UPDATE computer c "
						       . "INNER JOIN vmhost v ON (c.vmhostid = v.id) "
						       . "SET c.stateid = 10, "
						       .     "c.notes = '$note' "
						       . "WHERE v.computerid = $compid";
						doQuery($query);
					}
				}
				elseif($reloadstart) {
					if(unixToDatetime($reloadstart) == '2038-01-01 00:00:00') {
						# node is reserved indefintely
						$fails[] = $compid;
						continue;
					}
					# computer has reservations, schedule tomaintenance
					$startdt = unixToDatetime($reloadstart);
					$end = $reloadstart + SECINMONTH;
					$enddt = unixToDatetime($end);
					# lock this computer
					if(! retryGetSemaphore($noimageid, $norevid, $semmnid, $compid, $startdt, $enddt)) {
						$fails[] = $compid;
						cleanSemaphore();
						continue;
					}
					if($newstateid == 10)
						$tostateid = 18;
					else
						$tostateid = 22;
					$checkstart = getExistingChangeStateStartTime($compid, $tostateid);
					if($checkstart) {
						if($checkstart > $reloadstart)
							# update start time of existing tomaintenance/tohpc reservation
							updateExistingToState($compid, $startdt, $tostateid);
						else
							# leave existing tomaintenance/tohpc reservation as is
							$reloadstart = $checkstart;
					}
					elseif(! simpleAddRequest($compid, $noimageid, $norevid, $startdt,
					                          $enddt, $tostateid, $vclreloadid)) {
						$fails[] = $compid;
						cleanSemaphore();
						continue;
					}
					cleanSemaphore();
					$changetimes[$compid] = $reloadstart;
					$changeasap[] = $compid;
					continue;
				}
				# change to maintenance/tohpc state and save in $changenow
				// if we wait and put them all in maintenance/hpc at the same time,
				# we may end up moving reservations to the computer later in the
				# loop
				# lock this computer
				if(! retryGetSemaphore($noimageid, $norevid, $semmnid, $compid, $semstart, $semend)) {
					$fails[] = $compid;
					cleanSemaphore();
					continue;
				}
				$query = "UPDATE computer "
				       . "SET stateid = $newstateid "
				       . "WHERE id = $compid";
				doQuery($query, 101);
				$changenow[] = $compid;
				cleanSemaphore();
			}
			if($newstateid == 10 && (count($noaction) || count($changeasap) || count($changenow))) {
				$comparr = array_merge($noaction, $changeasap, $changenow);
				$allids = implode(',', $comparr);
				if(count($vmwithhost))
					$skipids = implode(',', $vmwithhost);
				else
					$skipids = "''";
				$query = "UPDATE computer "
				       . "SET notes = '$notes' "
				       . "WHERE id IN ($allids) AND "
				       .       "id NOT IN ($skipids)";
				doQuery($query, 101);
				$updatevms = array_intersect($vmwithhost, $comparr);
				if(count($updatevms)) {
					$inids = implode(',', $updatevms);
					$query = "UPDATE computer vm "
					       . "INNER JOIN vmhost v ON (vm.vmhostid = v.id) "
					       . "SET vm.notes = CONCAT('maintenance with host ', v.computerid) "
					       . "WHERE vm.id IN ($inids)";
					doQuery($query);
				}
			}
			if($newstateid == 10)
				$newstate = 'maintenance';
			else
				$newstate = 'hpc';
			$msg = '';
			if(count($changenow)) {
				$msg .= "The following computers were immediately placed into the ";
				$msg .= "$newstate state:<br><br>\n";
				$msg .= "<span class=\"ready\">\n";
				foreach($changenow as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "</span><br>\n";
			}
			if(count($changeasap)) {
				$msg .= "The following computers are currently reserved ";
				$msg .= "and will be placed in the $newstate state at the time listed ";
				$msg .= "for each computer:\n";
				$msg .= "<table>\n";
				$msg .= "  <tr>\n";
				$msg .= "    <th>Computer</th>\n";
				$msg .= "    <th>Time</th>\n";
				$msg .= "  </tr>\n";
				foreach($changeasap as $compid) {
					$msg .= "  <tr>\n";
					$msg .= "    <td align=center><span class=\"wait\">{$computers[$compid]['hostname']}</span></td>\n";
					$time = date('n/j/y g:i a', $changetimes[$compid]);
					$msg .= "    <td align=center>$time</td>\n";
					$msg .= "  </tr>\n";
				}
				$msg .= "</table>\n";
				$msg .= "<br>\n";
			}
			if(count($fails)) {
				$msg .= "The following computers are currently reserved ";
				$msg .= "but could not be scheduled to be moved to the $newstate state ";
				$msg .= "at this time:<br><br>\n";
				$msg .= "<span class=\"rederrormsg\">\n";
				foreach($fails as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "</span><br>\n";
			}
			if(count($noaction)) {
				$msg .= "The following computers were already in the $newstate state";
				if($newstateid == 10)
					$msg .= " and had their notes on being in the maintenance state updated";
				$msg .= ":<br><br>\n";
				foreach($noaction as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "<br>\n";
			}
		}
		# switching to vmhostinuse
		elseif($newstateid == 20) {
			$profileid = processInputVar('profileid', ARG_NUMERIC);
			$profiles = getContinuationVar('profiles');
			if(! array_key_exists($profileid, $profiles)) {
				$ret = array('status' => 'error', 'errormsg' => 'Invalid profile submitted');
				sendJSON($ret);
				return;
			}
			$vclreloadid = getUserlistID('vclreload@Local');
			$imagerevisionid = getProductionRevisionid($profiles[$profileid]['imageid']);
			$computers = $this->getData($this->defaultGetDataArgs);
			$noaction = array();
			$changenow = array();
			$changenowreload = array();
			$changeasap = array();
			$changetimes = array();
			$fails = array();
			$semstart = unixToDatetime(time());
			$semend = '2038-01-01 00:00:00';
			$maintvmids = array();
			$vmnotallowed = array();
			$allvmids = array();
			$allids = implode(',', $compids);
			$query = "SELECT v.computerid AS compid, "
			       .        "vm.id AS vmid, "
			       .        "vm.notes, "
			       .        "vm.stateid AS vmstateid "
			       . "FROM computer vm, "
			       .      "vmhost v "
			       . "WHERE v.computerid IN ($allids) AND "
			       .       "vm.vmhostid = v.id";
			$qh = doQuery($query);
			while($row = mysql_fetch_assoc($qh)) {
				if(! array_key_exists($row['compid'], $maintvmids))
					$maintvmids[$row['compid']] = array();
				if($row['vmstateid'] == 10 &&
				   $row['notes'] == "maintenance with host {$row['compid']}")
					$maintvmids[$row['compid']][] = $row['vmid'];
				$allvmids[$row['compid']][] = $row['vmid'];
			}
			foreach($compids as $compid) {
				if($computers[$compid]['type'] == 'virtualmachine') {
					$vmnotallowed[] = $compid;
					continue;
				}
				# try to move future reservations off of computer
				moveReservationsOffComputer($compid);
				cleanSemaphore();
				if($computers[$compid]['state'] == 'maintenance') {
					if($computers[$compid]['provisioning'] != 'None') {
						# schedule tovmhostinuse
						$start = getReloadStartTime();
						# put computer in reload state so vcld will not ignore due to being in maintenance
						$query = "UPDATE computer "
						       . "SET stateid = 19 "
						       . "WHERE id = $compid";
						doQuery($query);
						$rc = $this->scheduleTovmhostinuse($compid, $profiles[$profileid]['imageid'],
						                                   $start, $profileid, $computers[$compid]['vmprofileid']);
						cleanSemaphore();
						if(! $rc) {
							$fails[] = $compid;
							continue;
						}
						if(! is_null($computers[$compid]['vmprofileid']) &&
						   array_key_exists($compid, $maintvmids) &&
						   count($maintvmids[$compid])) {
							$reloadstart = $start + 1800;
							$reloadstartdt = unixToDatetime($reloadstart);
							$end = $reloadstart + 3600;
							$enddt = unixToDatetime($end);
							foreach($maintvmids[$compid] as $vmid) {
								if(! retryGetSemaphore($noimageid, $norevid, $semmnid, $vmid, $reloadstartdt, $enddt))
									continue;
								simpleAddRequest($vmid, $noimageid, $norevid, $reloadstartdt,
								                 $enddt, 19, $vclreloadid);
								# continue even if failed to schedule VM to be reloaded
							}
							cleanSemaphore();
						}
						$changenowreload[] = $compid;
					}
					else {
						$query = "UPDATE computer "
						       . "SET stateid = 20, "
						       .     "notes = '' "
								 . "WHERE id = $compid";
						doQuery($query);
						$this->updateVmhostProfile($compid, $profileid, $computers[$compid]['vmprofileid']);
						if(array_key_exists($compid, $maintvmids) && count($maintvmids[$compid])) {
							$allids = implode(',', $maintvmids[$compid]);
							$query = "UPDATE computer "
							       . "SET stateid = 2, "
							       .     "notes = '' "
									 . "WHERE id in ($allids)";
							doQuery($query);
						}
						$changenow[] = $compid;
					}
				}
				elseif($computers[$compid]['state'] == 'hpc') {
					if($computers[$compid]['provisioning'] != 'None') {
						# schedule tovmhostinuse
						$start = getReloadStartTime();
						# put computer in reload state so vcld will not ignore due to being in maintenance
						$query = "UPDATE computer "
						       . "SET stateid = 19 "
						       . "WHERE id = $compid";
						doQuery($query);
						$rc = $this->scheduleTovmhostinuse($compid, $profiles[$profileid]['imageid'],
						                                   $start, $profileid, $computers[$compid]['vmprofileid']);
						cleanSemaphore();
						if(! $rc) {
							$fails[] = $compid;
							continue;
						}
						$changenowreload[] = $compid;
					}
					else {
						$query = "UPDATE computer "
						       . "SET stateid = 20, "
						       .     "notes = '' "
								 . "WHERE id = $compid";
						doQuery($query);
						$this->updateVmhostProfile($compid, $profileid, $computers[$compid]['vmprofileid']);
						$changenow[] = $compid;
					}
				}
				elseif($computers[$compid]['state'] == 'vmhostinuse') {
					if($profiles[$computers[$compid]['vmprofileid']]['imageid'] !=
					   $profiles[$profileid]['imageid']) {
						if($computers[$compid]['provisioning'] != 'None') {
							$sem = array('imageid' => $noimageid, 'revid' => $norevid,
							             'mnid' => $semmnid, 'start' => $semstart, 'end' => $semend);
							moveReservationsOffVMs($compid, $sem);
							cleanSemaphore();
							$reloadstart = getCompFinalVMReservationTime($compid, 1);
							if($reloadstart < 0) {
								$fails[] = $compid;
								cleanSemaphore();
								continue;
							}
							if($reloadstart == 0)
								$start = getReloadStartTime();
							else
								$start = $reloadstart;
							$startdt = unixToDatetime($start);
							$end = $start + SECINWEEK;
							$enddt = unixToDatetime($end);
							if($start == $reloadstart) {
								# check for existing reload reservations for all VMs and host
								$times = array();
								$reqids = array();
								$inids = implode(',', $allvmids[$compid]);
								$query = "SELECT UNIX_TIMESTAMP(MIN(rq.start)) AS start, "
								       .        "rs.computerid, "
								       .        "rq.id "
								       . "FROM request rq, "
								       .      "reservation rs "
								       . "WHERE rs.requestid = rq.id AND "
								       .       "rs.computerid IN ($inids) AND "
								       .       "rq.stateid = 19 AND "
								       .       "rs.imageid = $noimageid AND "
								       .       "rq.start > NOW() "
								       . "GROUP BY rs.computerid "
								       . "ORDER BY start";
								$qh = doQuery($query);
								if(mysql_num_rows($qh) == count($allvmids)) {
									while($row = mysql_fetch_assoc($qh)) {
										$times[$row['start']] = 1;
										$reqids[] = $row['id'];
									}
									if(count($times) == 1) {
										# found existing reload reservations for all VMs, now check host
										$hoststart = $times[0] + 300;
										$hoststartdt = unixToDatetime($hoststart);
										$hostend = $hoststart + SECINYEAR;
										$hostenddt = unixToDatetime($hostend);
										$query = "SELECT rq.id, "
										       .        "rq.start "
										       . "FROM request rq, "
										       .      "reservation rs "
										       . "WHERE rs.requestid = rq.id AND "
										       .       "rs.computerid = $compid AND "
										       .       "rq.start = '$hoststartdt' AND "
										       .       "rq.end = '$hostenddt' AND "
										       .       "rs.imageid = '{$profiles[$profileid]['imageid']}' AND "
										       .       "rq.stateid = 21";
										$qh = doQuery($query);
										if($row = mysql_fetch_assoc($qh)) {
											# node was previously scheduled to be reloaded for vmhostinuse
											if($times[0] > $start) {
												# update existing reservations
												$allreqids = implode(',', $reqids);
												$query1 = "UPDATE request "
												        . "SET start = '$startdt', "
												        .     "end = '$enddt' "
												        . "WHERE id IN ($allreqids)";
												# delay host by 5 minutes
												$start = $start + 300;
												$startdt = unixToDatetime($start);
												$end = $start + SECINYEAR;
												$enddt = unixToDatetime($end);
												# lock this computer
												if(! retryGetSemaphore($noimageid, $norevid, $semmnid, $compid, $startdt, $enddt)) {
													$fails[] = $compid;
													continue;
												}
												doQuery($query1);
												$query2 = "UPDATE request "
												        . "SET start = '$startdt', "
												        .     "end = '$enddt' "
												        . "WHERE id = {$row['id']}";
												doQuery($query2);
												$changeasap[] = $compid;
												$changetimes[$compid] = $start;
											}
											else {
												# just leave the existing ones there
												$changeasap[] = $compid;
												$changetimes[$compid] = $times[0] + 300;
											}
											cleanSemaphore();
											continue;
										}
									}
								}
							}
							if(array_key_exists($compid, $allvmids)) {
								foreach($allvmids[$compid] as $vmid) {
									$rc = simpleAddRequest($vmid, $noimageid, $norevid, $startdt,
									                       $enddt, 19, $vclreloadid);
									if(! $rc) {
										$fails[] = $compid;
										cleanSemaphore();
										continue(2); # jump out of this foreach to the bigger foreach
									}
								}
							}
							$start = $start + 300; # give 5 minutes for VMs
							$rc = $this->scheduleTovmhostinuse($compid, $profiles[$profileid]['imageid'],
							                                   $start, $profileid, $computers[$compid]['vmprofileid']);
							if(! $rc) {
								$fails[] = $compid;
								continue;
							}
							if($reloadstart) {
								$changeasap[] = $compid;
								$changetimes[$compid] = $reloadstart;
							}
							else
								$changenowreload[] = $compid;
						}
						else {
							$this->updateVmhostProfile($compid, $profileid, $computers[$compid]['vmprofileid']);
							$changenow[] = $compid;
						}
					}
					else
						$noaction[] = $compid;
				}
				elseif(($reloadstart = moveReservationsOffComputer($compid)) == 0) {
					$start = getCompFinalReservationTime($compid, 21);
					$rc = $this->scheduleTovmhostinuse($compid, $profiles[$profileid]['imageid'],
					                                   $start, $profileid, $computers[$compid]['vmprofileid']);
					if(! $rc) {
						$fails[] = $compid;
						continue;
					}
					$changeasap[] = $compid;
					if(isset($this->startchange))
						$start = $this->startchange;
					$changetimes[$compid] = $start;
				}
				else {
					if($computers[$compid]['provisioning'] != 'None') {
						$start = getCompFinalReservationTime($compid, 21);
						$now = 0;
						if($start == 0) {
							$start = getReloadStartTime();
							$now = 1;
						}
						$rc = $this->scheduleTovmhostinuse($compid, $profiles[$profileid]['imageid'],
						                                   $start, $profileid, $computers[$compid]['vmprofileid']);
						if(! $rc) {
							$fails[] = $compid;
							continue;
						}
						if($now)
							$changenowreload[] = $compid;
						else {
							$changeasap[] = $compid;
							$changetimes[$compid] = $start;
						}
					}
					else {
						$query = "UPDATE computer "
						       . "SET stateid = 20, "
						       .     "notes = '' "
								 . "WHERE id = $compid";
						doQuery($query);
						$this->updateVmhostProfile($compid, $profileid, $computers[$compid]['vmprofileid']);
						$changenow[] = $compid;
					}
				}
			}
			$msg = '';
			if(count($changenow)) {
				$msg .= "The following computers were placed into the vmhostinuse state ";
				$msg .= "or had their VM Host Profiles updated:<br><br>\n";
				foreach($changenow as $compid)
					$msg .= "<span class=\"ready\">{$computers[$compid]['hostname']}</span><br>\n";
				$msg .= "<br>\n";
				$ret['clearselection'] = 1;
				$ret['refreshcount'] = 5;
			}
			if(count($changenowreload)) {
				$msg .= "The following computers have been scheduled to be immediately reloaded<br>\n";
				$msg .= "and placed into the vmhostinuse state:<br><br>\n";
				foreach($changenowreload as $compid)
					$msg .= "<span class=\"ready\">{$computers[$compid]['hostname']}</span><br>\n";
				$msg .= "<br>\n";
				$ret['clearselection'] = 1;
				$ret['refreshcount'] = 5;
			}
			if(count($changeasap)) {
				$msg .= "The following computers are currently reserved and have been scheduled<br>\n";
				$msg .= "to be reloaded and placed into the vmhostinuse state at the time listed<br>\n";
				$msg .= "for each computers:<br><br>\n";
				$msg .= "<table>\n";
				$msg .= "  <tr>\n";
				$msg .= "    <th>Computer</th>\n";
				$msg .= "    <th>Reload time</th>\n";
				$msg .= "  </tr>\n";
				foreach($changeasap as $compid) {
					$msg .= "  <tr>\n";
					$msg .= "    <td align=center><span class=\"wait\">{$computers[$compid]['hostname']}</span></td>\n";
					$time = date('n/j/y g:i a', $changetimes[$compid]);
					$msg .= "    <td align=center>$time</td>\n";
					$msg .= "  </tr>\n";
				}
				$msg .= "</table>\n";
				$msg .= "<br>\n";
			}
			if(count($fails)) {
				$msg .= "Problems were encountered while trying to move the following computers<br>\n";
				$msg .= "to the vmhostinuse state:<br><br>\n";
				foreach($fails as $compid)
					$msg .= "<span class=\"rederrormsg\">{$computers[$compid]['hostname']}</span><br>\n";
				$msg .= "<br>\n";
			}
			if(count($vmnotallowed)) {
				$msg .= "The following computers are VMs which cannot be placed into the ";
				$msg .= "vmhostinuse state:<br><br>\n";
				foreach($vmnotallowed as $compid)
					$msg .= "<span class=\"rederrormsg\">{$computers[$compid]['hostname']}</span><br>\n";
				$msg .= "<br>\n";
			}
			if(count($noaction)) {
				$msg .= "The following computers were already in the vmhostinuse state:<br><br>\n";
				foreach($noaction as $compid)
					$msg .= "{$computers[$compid]['hostname']}<br>\n";
				$msg .= "<br>\n";
			}
		}

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);

		$ret['msg'] = $msg;
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJcompProvisioningChange()
	///
	/// \brief confirms changing provisioning engine of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJcompProvisioningChange() {
		$provisioningid = processInputVar('provisioningid', ARG_NUMERIC);
		$provisioning = getProvisioning();
		if(! array_key_exists($provisioningid, $provisioning)) {
			$ret = array('status' => 'error',
			             'errormsg' => 'Invalid Provisioning Engine submitted.');
			sendJSON($ret);
			return;
		}
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$tmp = getUserResources(array($this->restype . "Admin"), array("administer"), 0, 1);
		$computers = $tmp['computer'];

		$msg  = "Change the Provisioning Engine of the following<br>computers to ";
		$msg .= "<strong>{$provisioning[$provisioningid]['prettyname']}</strong>?<br><br>\n";
		$complist = '';
		foreach($compids as $compid)
			$complist .= $computers[$compid] . "<br>\n";
		$complist .= "<br>\n";

		$cdata = $this->basecdata;
		$cdata['compids'] = $compids;
		$cdata['provisioningid'] = $provisioningid;
		$cdata['provisioningname'] = $provisioning[$provisioningid]['prettyname'];
		$cont = addContinuationsEntry('AJsubmitCompProvisioningChange', $cdata, SECINDAY, 1, 0);
		$ret = array('status' => 'success',
		             'title' => "Provisioning Engine Change",
		             'btntxt' => 'Submit Provisioning Engine Change',
		             'cont' => $cont,
		             'actionmsg' => $msg,
		             'complist' => $complist);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitCompProvisioningChange
	///
	/// \brief changes provisioning engine of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitCompProvisioningChange() {
		$provisioningid = getContinuationVar('provisioningid');
		$provname = getContinuationVar('provisioningname');
		$compids = getContinuationVar('compids');

		$startcheck = time() + 900;
		$startcheckdt = unixToDatetime($startcheck);
		$allids = implode(',', $compids);
		$fails = array();

		$query = "SELECT rs.computerid "
		       . "FROM request rq, "
		       .      "reservation rs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid IN ($allids) AND "
		       .       "rq.start <= '$startcheckdt' AND "
		       .       "rq.end > NOW()";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$fails[] = $row['computerid'];

		$nowids = array_diff($compids, $fails);
		$allids = implode(',', $nowids);
		$query = "UPDATE computer "
		       . "SET provisioningid = $provisioningid "
		       . "WHERE id in ($allids)";
		doQuery($query);

		$resources = getUserResources(array($this->restype . "Admin"), array("administer"));
		$compdata = $resources[$this->restype];

		if(count($nowids)) {
			$msg  = "The following computers had their Provisioning Engine set to $provname:<br><br>\n";
			foreach($nowids as $compid)
				$msg .= "{$compdata[$compid]}<br>\n";
			$msg .= "<br>";
		}
		if(count($fails)) {
			$msg .= "The following computers have or will soon have reservations  ";
			$msg .= "on them and could not have their Provisioning Engine changed ";
			$msg .= "at this time:<br><br>\n";
			$msg .= "<span class=\"rederrormsg\">\n";
			foreach($fails as $id)
				$msg .= "{$compdata[$id]}<br>\n";
			$msg .= "<br>\n";
			$msg .= "</span>\n";
		}

		$ret = array('status' => 'success',
		             'title' => "Change Provisioning Engine",
		             'clearselection' => 1,
		             'refreshcount' => 1,
		             'msg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJcompPredictiveModuleChange()
	///
	/// \brief confirms changing provisioning engine of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJcompPredictiveModuleChange() {
		$predictivemoduleid = processInputVar('predictivemoduleid', ARG_NUMERIC);
		$premodules = getPredictiveModules();
		if(! array_key_exists($predictivemoduleid, $premodules)) {
			$ret = array('status' => 'error',
			             'errormsg' => 'Invalid Predictive Loading Module submitted.');
			sendJSON($ret);
			return;
		}
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$tmp = getUserResources(array($this->restype . "Admin"), array("administer"), 0, 1);
		$computers = $tmp['computer'];

		$msg  = "Change the Predictive Loading Module of the following<br>computers to ";
		$msg .= "<strong>{$premodules[$predictivemoduleid]['prettyname']}</strong>?<br><br>\n";
		$complist = '';
		foreach($compids as $compid)
			$complist .= $computers[$compid] . "<br>\n";
		$complist .= "<br>\n";

		$cdata = $this->basecdata;
		$cdata['compids'] = $compids;
		$cdata['predictivemoduleid'] = $predictivemoduleid;
		$cdata['predictivemodulename'] = $premodules[$predictivemoduleid]['prettyname'];
		$cont = addContinuationsEntry('AJsubmitCompPredictiveModuleChange', $cdata, SECINDAY, 1, 0);
		$ret = array('status' => 'success',
		             'title' => "Predictive Loading Module Change",
		             'btntxt' => 'Submit Predictive Loading Module Change',
		             'cont' => $cont,
		             'actionmsg' => $msg,
		             'complist' => $complist);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitCompPredictiveModuleChange
	///
	/// \brief changes provisioning engine of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitCompPredictiveModuleChange() {
		$predictivemoduleid = getContinuationVar('predictivemoduleid');
		$predictivename = getContinuationVar('predictivemodulename');
		$compids = getContinuationVar('compids');

		$allids = implode(',', $compids);
		$query = "UPDATE computer "
		       . "SET predictivemoduleid = $predictivemoduleid "
		       . "WHERE id in ($allids)";
		doQuery($query);

		$resources = getUserResources(array($this->restype . "Admin"), array("administer"));
		$compdata = $resources[$this->restype];

		$msg  = "The following computers had their Predictive Loading Module<br>set to $predictivename:<br><br>\n";
		foreach($compids as $compid)
			$msg .= "{$compdata[$compid]}<br>\n";
		$msg .= "<br>";

		$ret = array('status' => 'success',
		             'title' => "Change Predictive Loading Module",
		             'clearselection' => 0,
		             'refreshcount' => 1,
		             'msg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJcompNATchange()
	///
	/// \brief confirms changing provisioning engine of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJcompNATchange() {
		$natenabled = processInputVar('natenabled', ARG_NUMERIC);
		$nathostid = processInputVar('nathostid', ARG_NUMERIC);
		$nathosts = getNAThosts();
		if(($natenabled != 0 && $natenabled != 1) ||
		   ($nathostid != 0 && ! array_key_exists($nathostid, $nathosts))) {
			$ret = array('status' => 'error',
			             'errormsg' => 'Invalid value submitted.');
			sendJSON($ret);
			return;
		}
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$allids = implode(',', $compids);
		$inusecompids = array();
		$vclreloadid = getUserlistID('vclreload@Local');
		$query = "SELECT rs.computerid "
		       . "FROM request rq, "
		       .      "reservation rs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid IN ($allids) AND "
		       .       "rq.start <= NOW() AND "
		       .       "rq.end > NOW() AND "
		       .       "rq.stateid NOT IN (1,5,11,12) AND "
		       .       "rq.laststateid NOT IN (1,5,11,12) AND "
		       .       "rq.userid != $vclreloadid";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$inusecompids[] = $row['computerid'];

		$tmp = getUserResources(array($this->restype . "Admin"), array("administer"), 0, 1);
		$computers = $tmp['computer'];

		$msg = '';
		if(count($inusecompids)) {
			$msg .= "The following computers are currently in use and cannot have<br>";
			$msg .= "NAT settings changed at this time:<br><br>\n";
			$complist = '';
			foreach($inusecompids as $compid)
				$complist .= $computers[$compid] . "<br>\n";
			$msg .= "<div class=\"wait\">$complist<br></div>\n";
			$compids = array_diff($compids, $inusecompids);
		}

		if(count($compids)) {
			if($natenabled) {
				$msg .= "<strong>Enable</strong> Connect Using NAT and set the NAT ";
				$msg .= "host<br>to <strong>{$nathosts[$nathostid]['hostname']}";
				$msg .= "</strong> for the following computers?<br><br>";
			}
			else {
				$msg .= "<strong>Disable</strong> Connect Using NAT for the following ";
				$msg .= "computers?<br><br>";
			}
		}
		$complist = '';
		foreach($compids as $compid)
			$complist .= $computers[$compid] . "<br>\n";
		$complist .= "<br>\n";

		$cdata = $this->basecdata;
		$cdata['compids'] = $compids;
		$cdata['natenabled'] = $natenabled;
		$cdata['nathostid'] = $nathostid;
		$cont = addContinuationsEntry('AJsubmitCompNATchange', $cdata, SECINDAY, 1, 0);
		$ret = array('status' => 'success',
		             'title' => "Connect Using NAT Change",
		             'btntxt' => 'Submit Connect Using NAT Change',
		             'cont' => $cont,
		             'actionmsg' => $msg,
		             'complist' => $complist);
		if(empty($compids)) {
			$ret['status'] = 'error';
			$ret['errormsg'] = $ret['actionmsg'];
			unset($ret['actionmsg']);
		}
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitCompNATchange
	///
	/// \brief changes provisioning engine of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitCompNATchange() {
		$natenabled = getContinuationVar('natenabled');
		$nathostid = getContinuationVar('nathostid');
		$compids = getContinuationVar('compids');

		$allids = implode(',', $compids);
		$query = "DELETE FROM nathostcomputermap "
		       . "WHERE computerid IN ($allids)";
		doQuery($query);
		if($natenabled) {
			$query = "INSERT INTO nathostcomputermap "
			       . "SELECT $nathostid, "
			       .        "id "
			       . "FROM computer "
			       . "WHERE id IN ($allids)";
			doQuery($query);
		}

		$resources = getUserResources(array($this->restype . "Admin"), array("administer"));
		$compdata = $resources[$this->restype];

		$msg = "Connect Using NAT was <strong>";
		if($natenabled)
			$msg .= "Enabled";
		else
			$msg .= "Disabled";
		$msg .= "</strong> for the following computers:<br><br>\n";
		foreach($compids as $compid)
			$msg .= "{$compdata[$compid]}<br>\n";
		$msg .= "<br>";

		$ret = array('status' => 'success',
		             'title' => "Change Connect Using NAT",
		             'clearselection' => 0,
		             'refreshcount' => 1,
		             'nathostid' => $nathostid, # todo
		             'msg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJcompScheduleChange()
	///
	/// \brief confirms changing schedule of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJcompScheduleChange() {
		$schid = processInputVar('schid', ARG_NUMERIC);
		$resources = getUserResources(array("scheduleAdmin"), array("manageGroup"));
		if(! array_key_exists($schid, $resources['schedule'])) {
			$ret = array('status' => 'error',
			             'errormsg' => 'You do not have access to the selected schedule.');
			sendJSON($ret);
			return;
		}
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$tmp = getUserResources(array($this->restype . "Admin"), array("administer"), 0, 1);
		$computers = $tmp['computer'];

		$msg  = "Change the schedule of the following computers to ";
		$msg .= "<strong>{$resources['schedule'][$schid]}</strong>?<br><br>\n";
		$complist = '';
		foreach($compids as $compid)
			$complist .= $computers[$compid] . "<br>\n";
		$complist .= "<br>\n";

		$cdata = $this->basecdata;
		$cdata['compids'] = $compids;
		$cdata['schid'] = $schid;
		$cdata['schname'] = $resources['schedule'][$schid];
		$cdata['complist'] = $complist;
		$cont = addContinuationsEntry('AJsubmitCompScheduleChange', $cdata, SECINDAY, 1, 0);
		$ret = array('status' => 'success',
		             'title' => "Schedule Change",
		             'btntxt' => 'Submit Schedule Change',
		             'cont' => $cont,
		             'actionmsg' => $msg,
		             'complist' => $complist);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitCompScheduleChange()
	///
	/// \brief changes schedule of submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitCompScheduleChange() {
		$schid = getContinuationVar('schid');
		$schname = getContinuationVar('schname');
		$compids = getContinuationVar('compids');
		$complist = getContinuationVar('complist');

		$allids = implode(',', $compids);
		$query = "UPDATE computer "
		       . "SET scheduleid = $schid "
		       . "WHERE id in ($allids)";
		doQuery($query);

		$msg  = "The schedule for the following computer(s) was set to ";
		$msg .= "$schname:<br>$complist\n";

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);

		$ret = array('status' => 'success',
		             'title' => "Change Schedule",
		             'clearselection' => 1,
		             'refreshcount' => 1,
		             'msg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJgenerateDHCPdata()
	///
	/// \brief generates configuration data for dhcpd
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJgenerateDHCPdata() {
		$type = processInputVar('type', ARG_STRING);
		if($type != 'public' && $type != 'private') {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}
		if($type == 'private') {
			$mnip = processInputVar('mnip', ARG_STRING);
			if(! validateIPv4addr($mnip)) {
				sendJSON(array('status' => 'error', 'errormsg' => 'invalid IP address submitted'));
				return;
			}
			$ipprefix = 'private';
		}
		else
			$ipprefix = '';
		$nic = processInputVar('nic', ARG_STRING);
		if($nic != 'eth0' && $nic != 'eth1')
			$nic = 'eth0';

		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$comps = $this->getData($this->defaultGetDataArgs);
		if($type == 'private') {
			$octets = explode('.', $mnip);
			$hexmnip = sprintf('%02x:%02x:%02x:%02x', $octets[0], $octets[1], $octets[2], $octets[3]);
		}

		$noips = array();
		$dhcpd = '';
		$leases = '';
		foreach($compids as $id) {
			if(empty($comps[$id]["{$ipprefix}IPaddress"]) ||
			   empty($comps[$id]["{$nic}macaddress"])) {
				$noips[] = $comps[$id]['hostname'];
				continue;
			}
			$tmp = explode('.', $comps[$id]['hostname']);
			$dhcpd .= "\t\thost {$tmp[0]} {\n";
			$dhcpd .= "\t\t\toption host-name \"{$tmp[0]}\";\n";
			$dhcpd .= "\t\t\thardware ethernet {$comps[$id]["{$nic}macaddress"]};\n";
			$dhcpd .= "\t\t\tfixed-address {$comps[$id]["{$ipprefix}IPaddress"]};\n";
			if($type == 'private') {
				$dhcpd .= "\t\t\tfilename \"/tftpboot/pxelinux.0\";\n";
				$dhcpd .= "\t\t\toption dhcp-server-identifier $mnip;\n";
				$dhcpd .= "\t\t\tnext-server $mnip;\n";
			}
			$dhcpd .= "\t\t}\n\n";

			$leases .= "host {$tmp[0]} {\n";
			$leases .= "\tdynamic;\n";
			$leases .= "\thardware ethernet {$comps[$id]["{$nic}macaddress"]};\n";
			$leases .= "\tfixed-address {$comps[$id]["{$ipprefix}IPaddress"]};\n";
			$leases .= "\tsupersede server.ddns-hostname = \"{$tmp[0]}\";\n";
			$leases .= "\tsupersede host-name = \"{$tmp[0]}\";\n";
			if($type == 'private') {
				$leases .= "\tif option vendor-class-identifier = \"ScaleMP\" {\n";
				$leases .= "\t\tsupersede server.filename = \"vsmp/pxelinux.0\";\n";
				$leases .= "\t} else {\n";
				$leases .= "\t\tsupersede server.filename = \"pxelinux.0\";\n";
				$leases .= "\t}\n";
				$leases .= "\tsupersede server.next-server = $hexmnip;\n";
			}
			$leases .= "}\n";
		}
		$msg = '';
		if(! empty($noips)) {
			$msg .= "<span class=\"rederrormsg\">The following computers did not have ";
			$msg .= "a $type IP address or an $nic MAC address entry and therefore ";
			$msg .= "could not be included in the data below:</span><br><br>\n";
			$msg .= implode("<br>\n", $noips);
			$msg .= "<br><br>\n";
		}
		if(! empty($dhcpd)) {
			$msg .= "Data to be added to dhcpd.conf:<br>";
			$msg .= "<pre>$dhcpd</pre>";
			$msg .= "<br><hr><br>\n";
			$msg .= "Data to be added to dhcpd.leases:<br>";
			$msg .= "<pre>$leases</pre>";
		}

		$ret = array('status' => 'onestep',
		             'title' => ucfirst($type) . " dhcpd Data",
		             'actionmsg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJshowReservations()
	///
	/// \brief gets reservation information for submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJshowReservations() {
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$complist = implode(',', $compids);
		$query = "SELECT UNIX_TIMESTAMP(rq.start) AS start, "
		       .        "UNIX_TIMESTAMP(rq.daterequested) AS daterequested, "
		       .        "UNIX_TIMESTAMP(rq.end) AS end, "
		       .        "i.prettyname AS image, "
		       .        "ir.revision, "
		       .        "c.hostname AS hostname, "
		       .        "mn.hostname AS managementnode, "
		       .        "sr.name AS rqname, "
		       .        "aug.name AS admingroup, "
		       .        "lug.name AS logingroup, "
		       .        "CONCAT(u.unityid, '@', a.name) AS username, "
		       .        "rq.id AS requestid, "
		       .        "vh.hostname AS vmhost "
		       . "FROM computer c "
		       . "LEFT JOIN reservation rs ON (c.id = rs.computerid) "
		       . "LEFT JOIN image i ON (rs.imageid = i.id) "
		       . "LEFT JOIN imagerevision ir ON (rs.imagerevisionid = ir.id) "
		       . "LEFT JOIN managementnode mn ON (rs.managementnodeid = mn.id) "
		       . "LEFT JOIN request rq ON (rs.requestid = rq.id) "
		       . "LEFT JOIN serverrequest sr ON (sr.requestid = rq.id) "
		       . "LEFT JOIN usergroup aug ON (aug.id = sr.admingroupid) "
		       . "LEFT JOIN usergroup lug ON (lug.id = sr.logingroupid) "
		       . "LEFT JOIN user u ON (rq.userid = u.id) "
		       . "LEFT JOIN affiliation a ON (u.affiliationid = a.id) "
		       . "LEFT JOIN vmhost v ON (c.vmhostid = v.id) "
		       . "LEFT JOIN computer vh ON (v.computerid = vh.id) "
		       . "LEFT JOIN state s ON (rq.stateid = s.id) "
		       . "WHERE c.id IN ($complist) AND "
		       .       "s.name NOT IN ('timedout','deleted','complete')";
		$qh = doQuery($query);
		$data = array();
		while($row = mysql_fetch_assoc($qh)) {
			$msg = "<strong>{$row['hostname']}</strong><br>";
			if($row['start'] == '') {
				$msg .= "(No reservations)<br><hr>";
				$data[] = array('name' => $row['hostname'], 'msg' => $msg);
				continue;
			}
			$msg .= "User: {$row['username']}<br>";
			if($row['rqname'] != '')
				$msg .= "Name: {$row['rqname']}<br>";
			$msg .= "Image: {$row['image']}<br>";
			$msg .= "Revision: {$row['revision']}<br>";
			if($row['start'] < $row['daterequested'])
				$msg .= "Start: " . prettyDatetime($row['daterequested'], 1) . "<br>";
			else
				$msg .= "Start: " . prettyDatetime($row['start'], 1) . "<br>";
			if($row['end'] == datetimeToUnix('2038-01-01 00:00:00'))
				$msg .= "End: (indefinite)<br>";
			else
				$msg .= "End: " . prettyDatetime($row['end'], 1) . "<br>";
			$msg .= "Management Node: {$row['managementnode']}<br>";
			if(! is_null($row['vmhost']))
				$msg .= "VM Host: {$row['vmhost']}<br>";
			if($row['admingroup'] != '')
				$msg .= "Admin Group: {$row['admingroup']}<br>";
			if($row['logingroup'] != '')
				$msg .= "Access Group: {$row['logingroup']}<br>";
			$msg .= "Request ID: {$row['requestid']}<br>";
			$msg .= "<hr>";
			$data[] = array('name' => $row['hostname'], 'msg' => $msg);
		}
		uasort($data, 'sortKeepIndex');
		$msg = '';
		if(count($data) != 0) {
			foreach($data as $item)
				$msg .= $item['msg'];
			$msg = substr($msg, 0, -4);
		}
		else
			$msg = "No reservations for selected computer(s).";

		$ret = array('status' => 'onestep',
		             'title' => 'Reservation Information',
		             'actionmsg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJshowReservationHistory()
	///
	/// \brief gets reservation history for submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJshowReservationHistory() {
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$complist = implode(',', $compids);
		$query = "SELECT UNIX_TIMESTAMP(l.start) AS start, "
		       .        "UNIX_TIMESTAMP(l.finalend) AS end, "
		       .        "i.prettyname AS image, "
		       .        "ir.revision, "
		       .        "c.hostname AS hostname, "
		       .        "mn.hostname AS managementnode, "
		       .        "l.ending, "
		       .        "CONCAT(u.unityid, '@', a.name) AS username "
		       . "FROM computer c "
		       . "LEFT JOIN sublog s ON (c.id = s.computerid) "
		       . "LEFT JOIN image i ON (s.imageid = i.id) "
		       . "LEFT JOIN imagerevision ir ON (s.imagerevisionid = ir.id) "
		       . "LEFT JOIN managementnode mn ON (s.managementnodeid = mn.id) "
		       . "LEFT JOIN log l ON (s.logid = l.id) "
		       . "LEFT JOIN user u ON (l.userid = u.id) "
		       . "LEFT JOIN affiliation a ON (u.affiliationid = a.id) "
		       . "WHERE c.id IN ($complist) "
		       . "ORDER BY c.hostname, "
		       .          "l.start DESC";
		$qh = doQuery($query);
		$data = array();
		while($row = mysql_fetch_assoc($qh)) {
			if(! is_numeric($row['end']))
				continue;
			$msg = "<strong>{$row['hostname']}</strong><br>";
			if($row['start'] == '') {
				$msg .= "(No reservations)<br><hr>";
				$data[] = array('name' => $row['hostname'], 'msg' => $msg);
				continue;
			}
			$msg .= "User: {$row['username']}<br>";
			$msg .= "Image: {$row['image']}<br>";
			$msg .= "Revision: {$row['revision']}<br>";
			$msg .= "Start: " . prettyDatetime($row['start'], 1) . "<br>";
			if($row['end'] == datetimeToUnix('2038-01-01 00:00:00'))
				$msg .= "End: (indefinite)<br>";
			else
				$msg .= "End: " . prettyDatetime($row['end'], 1) . "<br>";
			$msg .= "Management Node: {$row['managementnode']}<br>";
			$msg .= "Ending: {$row['ending']}<br>";
			$msg .= "<hr>";
			$data[] = array('name' => $row['hostname'], 'msg' => $msg);
		}
		$msg = '';
		if(count($data) != 0) {
			foreach($data as $item)
				$msg .= $item['msg'];
			$msg = substr($msg, 0, -4);
		}
		else
			$msg = "No reservation history for selected computer(s).";

		$ret = array('status' => 'onestep',
		             'title' => 'Reservation History',
		             'actionmsg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJhostsData()
	///
	/// \brief generates /etc/hosts data for submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJhostsData() {
		$compids = $this->validateCompIDs();
		if(array_key_exists('error', $compids)) {
			$ret = array('status' => 'error', 'errormsg' => $compids['msg']);
			sendJSON($ret);
			return;
		}
		if(count($compids) == 0) {
			$ret = array('status' => 'noaction');
			sendJSON($ret);
			return;
		}

		$comps = $this->getData($this->defaultGetDataArgs);
		$hosts = '';
		foreach($compids as $id) {
			if(! empty($comps[$id]['privateIPaddress']))
				$hosts .= "{$comps[$id]['privateIPaddress']}\t{$comps[$id]['hostname']}\n";
			else
				$noips[] = $comps[$id]['hostname'];
		}
		$msg  = "Data to be added to /etc/hosts:<br><br>";
		$msg .= "<pre>$hosts</pre>";

		$ret = array('status' => 'onestep',
		             'title' => 'Generate /etc/hosts Data',
		             'actionmsg' => $msg);
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateCompIDs()
	///
	/// \return array of computerids; if user does not have access to any
	/// submitted computers, returns array with 'error' set to 1 and 'msg' set
	/// to an error message listing computers the user does not have access to
	///
	/// \brief validates user access to submitted computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateCompIDs() {
		$compids = processInputVar('compids', ARG_MULTINUMERIC);
		$resources = getUserResources(array($this->restype . "Admin"), array("administer"), 0, 1);
		$usercomps = $resources[$this->restype];
		$noaccess = array();
		foreach($compids as $id) {
			if(! array_key_exists($id, $usercomps))
				$noaccess[] = $usercomps[$id];
		}
		if(count($noaccess)) {
			$ret = array('error' => 1);
			$ret['msg'] = "Access denied to these computers:<br><br>" . implode('<br>', $noaccess) . "<br><br>";
			return $ret;
		}
		return $compids;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn scheduleVMsToAvailable()
	///
	/// \param $vmids - array of ids of VMs to set schedule to available state
	///
	/// \brief sets VMs to failed state so that they cannot be scheduled and
	/// creates a reload reservation for the noimage image
	///
	/////////////////////////////////////////////////////////////////////////////
	function scheduleVMsToAvailable($vmids) {
		# TODO test with vcld that will handle reservation for noimage okay
		# schedule $vmids to have noimage "loaded" on them in 15 minutes
		$allids = implode(',', $vmids);
		$query = "UPDATE computer "
		       . "SET stateid = 5, " # set to failed instead of available so cannot be scheduled by users
		       .     "notes = '' "
		       . "WHERE id IN ($allids)";
		doQuery($query);

		$imageid = getImageId('noimage');
		$revid = getProductionRevisionid($imageid);
		$start = time() + 900;
		$end = $start + 3600;
		$startdt = unixToDatetime($start);
		$enddt = unixToDatetime($end);
		$vclreloadid = getUserlistID('vclreload@Local');
		foreach($vmids as $vmid)
			// if simpleAddRequest fails, vm is left assigned and in failed state, which is fine
			simpleAddRequest($vmid, $imageid, $revid, $startdt,
	                       $enddt, 19, $vclreloadid);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkMultiAddMacs($startmac, $cnt, &$errmsg, &$macs)
	///
	/// \param $startmac - starting mac address
	/// \param $cnt - number of computers for which to generate addresses
	/// \param $errmsg - if conflict, error message is put in here
	/// \param $macs - array of generated addresses is put in here
	///
	/// \return 1 if error; 0 if success
	///
	/// \brief generates all required mac addresses for adding multiple
	/// computers; checks that there are no duplicates with existing computers
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkMultiAddMacs($startmac, $cnt, &$errmsg, &$macs) {
		$tmp = explode(':', $startmac);
		$topdec = hexdec($tmp[0] . $tmp[1] . $tmp[2]);
		$botdec = hexdec($tmp[3] . $tmp[4] . $tmp[5]);
		$topmac = "{$tmp[0]}:{$tmp[1]}:{$tmp[2]}";
		$topplus = implode(':', str_split(dechex($topdec + 1), 2));
		$start = $botdec;
		$macs = array();
		$eth0macs = array();
		$eth1macs = array();
		$toggle = 0;
		$end = $start + ($cnt * 2);
		for($i = $start; $i < $end; $i++) {
			if($i > 16777215) {
				$val = $i - 16777216;
				$tmp = sprintf('%06x', $val);
				$tmp2 = str_split($tmp, 2);
				$macs[] = $topplus . ':' . implode(':', $tmp2);
			}
			else {
				$tmp = sprintf('%06x', $i);
				$tmp2 = str_split($tmp, 2);
				$macs[] = $topmac . ':' . implode(':', $tmp2);
			}
			if($toggle % 2)
				$eth1macs[] = $topmac . ':' . implode(':', $tmp2);
			else
				$eth0macs[] = $topmac . ':' . implode(':', $tmp2);
			$toggle++;
		}
		$ineth0s = implode("','", $eth0macs);
		$ineth1s = implode("','", $eth1macs);
		$query = "SELECT id "
		       . "FROM computer "
		       . "WHERE eth0macaddress IN ('$ineth0s') OR "
		       .       "eth1macaddress IN ('$ineth1s')";
		$qh = doQuery($query);
		$errmsg = '';
		if(mysql_num_rows($qh)) {
			$errmsg .= "The specified starting MAC address combined with the number ";
			$errmsg .= "of computers entered will result in a MAC address already ";
			$errmsg .= "assigned to another computer.";
			return 1;
		}
		elseif($i > 16777215 && $topdec == 16777215) {
			$errmsg .= "Starting MAC address too large for given given number of machines";
			return 1;
		}
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddRemGroupResource()
	///
	/// \brief adds or removes groups for a computer and sends JSON response;
	/// overridden from base class to handle case of adding multiple computers
	/// and being able to assign them all to a computer group at once
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJaddRemGroupResource() {
		$newids = getContinuationVar('newids');
		if(is_null($newids)) {
			$rscid = processInputVar('id', ARG_NUMERIC);
			$resources = getUserResources(array($this->restype . "Admin"), array("manageGroup"));
			if(! array_key_exists($rscid, $resources[$this->restype])) {
				$arr = array('status' => 'noaccess');
				sendJSON($arr);
				return;
			}
		}

		$groups = getUserResources(array($this->restype . "Admin"), array("manageGroup"), 1);
		$tmp = processInputVar('listids', ARG_STRING);
		$tmp = explode(',', $tmp);
		$groupids = array();
		foreach($tmp as $id) {
			if(! is_numeric($id))
				continue;
			if(! array_key_exists($id, $groups[$this->restype])) {
				$arr = array('status' => 'noaccess');
				sendJSON($arr);
				return;
			}
			$groupids[] = $id;
		}

		$args = $this->defaultGetDataArgs;
		if(is_null($newids))
			$args['rscid'] = $rscid;
		$resdata = $this->getData($args);

		$mode = getContinuationVar('mode');

		if($mode == 'add') {
			$adds = array();
			if(is_null($newids)) {
				foreach($groupids as $id)
					$adds[] = "({$resdata[$rscid]['resourceid']}, $id)";
			}
			else {
				foreach($newids as $newrscid) {
					foreach($groupids as $id)
						$adds[] = "({$resdata[$newrscid]['resourceid']}, $id)";
				}
			}
			$query = "INSERT IGNORE INTO resourcegroupmembers "
					 . "(resourceid, resourcegroupid) VALUES ";
			$query .= implode(',', $adds);
			doQuery($query);
		}
		else {
			$rems = implode(',', $groupids);
			if(is_null($newids))
				$query = "DELETE FROM resourcegroupmembers "
						 . "WHERE resourceid = {$resdata[$rscid]['resourceid']} AND "
						 .       "resourcegroupid IN ($rems)";
			else {
				$allrscids = array();
				foreach($newids as $newrscid)
					$allrscids[] = $resdata[$newrscid]['resourceid'];
				$allrscids = implode(',', $allrscids);
				$query = "DELETE FROM resourcegroupmembers "
						 . "WHERE resourceid IN ($allrscids) AND "
						 .       "resourcegroupid IN ($rems)";
			}
			doQuery($query);
		}

		$_SESSION['userresources'] = array();
		$regids = "^" . implode('$|^', $groupids) . "$";
		$arr = array('status' => 'success',
		             'regids' => $regids,
		             'inselobj' => 'ingroups',
		             'outselobj' => 'outgroups');
		sendJSON($arr);
	}
}
?>
