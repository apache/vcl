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
/// \fn siteconfig()
///
/// \brief prints a page of site configuration options
///
////////////////////////////////////////////////////////////////////////////////
function siteconfig() {
	if(! checkUserHasPerm('Site Configuration (global)') &&
	   ! checkUserHasPerm('Site Configuration (affiliation only)')) {
		print "<h2>" . _("Site Configuration") . "</h2>\n";
		print "You do not have access to this part of the site.<br>\n";
		return;
	}
	$h = '';
	$h .= "<h2>" . _("Site Configuration") . "</h2>\n";

	$globalopts = 0;
	if(checkUserHasPerm('Site Configuration (global)'))
		$globalopts = 1;

	/*$h .= "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	$h .= "     doLayout=\"false\">\n";*/

	$h .= generalOptions($globalopts);

	#$h .= "</div>\n"; # mainTabContainer

	print $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn generalOptions()
///
/// \brief prints a page of site configuration options
///
////////////////////////////////////////////////////////////////////////////////
function generalOptions($globalopts) {
	$h = '';
	#$h .= "<div id=\"globalopts\" dojoType=\"dijit.layout.ContentPane\" title=\"Global Options\">\n";

	# -------- full width -----------
	$h .= timeSourceHTML($globalopts);
	# ------ end full width ---------

	$h .= "<table summary=\"\" id=dashboard>\n";
	$h .= "<tr>\n";

	# -------- left column ---------
	$h .= "<td style=\"vertical-align: top;\">\n";
	$obj = new connectedUserCheck();
	$h .= $obj->getHTML($globalopts);
	$obj = new acknowledge();
	$h .= $obj->getHTML($globalopts);
	$obj = new connect();
	$h .= $obj->getHTML($globalopts);
	$obj = new reconnect();
	$h .= $obj->getHTML($globalopts);
	$h .= "</td>\n";
	# -------- end left column ---------


	# ---------- right column ---------
	$h .= "<td style=\"vertical-align: top;\">\n";
	$obj = new generalInuse();
	$h .= $obj->getHTML($globalopts);
	$obj = new serverInuse();
	$h .= $obj->getHTML($globalopts);
	$obj = new clusterInuse();
	$h .= $obj->getHTML($globalopts);
	$obj = new generalEndNotice1();
	$h .= $obj->getHTML($globalopts);
	$obj = new generalEndNotice2();
	$h .= $obj->getHTML($globalopts);
	$h .= "</td>\n";
	# -------- end right column --------

	$h .= "</tr>\n";
	$h .= "</table>\n";

	#$h .= "</div>\n";
	return $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn timeSourceHTML($globalopts)
///
/// \param $globalopts - 1 if user has global access, 0 if not
///
/// \return string of HTML
///
/// \brief generates HTML for setting the global time servers
///
////////////////////////////////////////////////////////////////////////////////
function timeSourceHTML($globalopts) {
	if(! $globalopts)
		return '';
	$h  = "<div class=\"configwidget\">\n";
	$h .= "<h3>" . _("Time Source") . "</h3>\n";
	$h .= "<span class=\"siteconfigdesc\">\n";
	$h .= _("Set the default list of time servers to be used on installed nodes. These can be overridden for each management node under the settings for a given management node. Separate hostnames using a comma (,).") . "<br><br>\n";
	$h .= "</span>\n";
	$val = getVariable('timesource|global', '', 1);
	$hostreg = '(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])';
	$h .= labeledFormItem('timesource', _('Time Servers'), 'text', "^($hostreg){1}(,$hostreg)*$", '', $val['value']);
	$h .= "<div id=\"timesourcemsg\"></div>\n";
	$h .= dijitButton('timesourcebtn', _('Submit Changes'), "saveTimeSource();", 1);
	$cont = addContinuationsEntry('AJupdateTimeSource', array('origval' => $val));
	$h .= "<input type=hidden id=timesourcecont value=\"$cont\">\n";
	$h .= "</div>\n";
	return $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJupdateTimeSource()
///
/// \brief updates submitted time source data
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateTimeSource() {
	if(! checkUserHasPerm('Site Configuration (global)')) {
		$arr = array('status' => 'noaccess',
		             'msg' => _('You do not have access to set the global Time Server setting.'));
		sendJSON($arr);
		return;
	}
	$origval = getContinuationVar('origval');
	$val = processInputVar('timesource', ARG_STRING);
	$val = preg_replace('/\s+/', '', $val);
	if($origval != $val) {
		$servers = explode(',', $val);
		foreach($servers as $key => $server) {
			if($server == '') {
				unset($servers[$key]);
				continue;
			}
			if(! preg_match('/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/', $server)) {
				$arr = array('status' => 'failed',
				             'msgid' => 'timesourcemsg',
				             'btn' => 'timesourcebtn',
				             'errmsg' => _('Invalid server(s) specified.'));
				sendJSON($arr);
				return;
			}
		}
		$newval = implode(',', $servers);
		setVariable('timesource|global', $newval);
	}
	$arr = array('status' => 'success',
	             'msgid' => 'timesourcemsg',
	             'btn' => 'timesourcebtn',
	             'msg' => _('Time Server successfully updated'));
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class TimeVariable
///
/// \brief base class for time related variables related to when vcld takes
/// certaion actions for reservations
///
////////////////////////////////////////////////////////////////////////////////
class TimeVariable {
	var $name;
	var $key;
	var $desc;
	var $domidbase;
	var $basecdata;
	var $jsname;
	var $scale60;
	var $defaultval;
	var $maxval;
	var $addmsg;
	var $updatemsg;
	var $delmsg;

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		$this->basecdata = array();
		$this->scale60 = 0;
		$this->defaultval = 900;
		$this->addmsg = _("Time out for %s added");
		$this->updatemsg = _("Time out values saved");
		$this->delmsg = _("Time out for %s deleted");
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getHTML($globalopts)
	///
	/// \param $globalopts - 1 if user has global access, 0 if not
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for setting time variables
	///
	////////////////////////////////////////////////////////////////////////////////
	function getHTML($globalopts) {
		global $user;
		$data = getVariablesRegex("^{$this->key}.*");
		$h  = "<div class=\"configwidget\" style=\"width: 100%;\">\n";
		$h .= "<h3>{$this->name}</h3>\n";
		$h .= "<span class=\"siteconfigdesc\">\n";
		$h .= $this->desc;
		$h .= "<br><br></span>\n";

		$origvals = array();
		$affils = getAffiliations();

		if($globalopts) {
			$key = $this->key;
			$prekey = $key;
			if(array_key_exists($key, $data)) {
				$val = $data[$key];
				$dispval = $data[$key];
				if($this->scale60)
					$dispval = (int)($dispval / 60);
			}
			else {
				setVariable($key, $this->defaultval, 'none');
				$val = $this->defaultval;
				$dispval = $this->defaultval;
				if($this->scale60)
					$dispval = (int)($dispval / 60);
			}
			$label = _('Global');
			unset_by_val(_('Global'), $affils);
		}
		else {
			$key = "{$this->key}|{$user['affiliation']}";
			if(array_key_exists($key, $data)) {
				$val = $data[$key];
				$dispval = $data[$key];
				if($this->scale60)
					$dispval = (int)($dispval / 60);
			}
			elseif(array_key_exists($this->key, $data)) {
				$val = 0; # have to set it to something different so we recognize it changed when saving
				$dispval = $data[$this->key];
				if($this->scale60)
					$dispval = (int)($dispval / 60);
			}
			else {
				setVariable($this->key, $this->defaultval, 'none');
				$val = 0; # have to set it to something different so we recognize it changed when saving
				$dispval = $this->defaultval;
				if($this->scale60)
					$dispval = (int)($dispval / 60);
			}
			$label = $user['affiliation'];
			$prekey = $key;
			$key = str_replace('|', '_', $key);
		}
		$extra = array('smallDelta' => 1, 'largeDelta' => 10);
		$h .= labeledFormItem($key, $label, 'spinner', "{min:1, max:{$this->maxval}}", 1, $dispval, '', '', $extra, '', '', 0);
		$h .= "<br>\n";
		$origvals[$key] = array('key' => $prekey, 'val' => $val);

		if($globalopts) {
			$h .= "<div id=\"{$this->domidbase}affildiv\">\n";
			foreach($data as $prekey => $val) {
				if($prekey == $this->key)
					continue;
				$key = str_replace('|', '_', $prekey);
				$tmp = explode('|', $prekey);
				$label = $tmp[1];
				$dispval = $val;
				if($this->scale60)
					$dispval = (int)($dispval / 60);
				$h .= "<span id=\"{$key}span\">\n";
				$h .= labeledFormItem($key, $label, 'spinner', "{min:1, max:{$this->maxval}}", 1, $dispval, '', '', $extra, '', '', 0);
				$h .= dijitButton("{$key}delbtn", _("Delete"), "{$this->jsname}.deleteAffiliationSetting('$key', '{$this->domidbase}');") . "<br>\n";
				$h .= "</span>\n";
				$origvals[$key] = array('key' => $prekey, 'val' => $val);
				unset_by_val($label, $affils);
			}
			$h .= "</div>\n";
		
			$h .= "<div id=\"{$this->domidbase}adddiv\"";
			if(! count($affils))
				$h .= " class=\"hidden\"";
			$h .= ">\n";
			$newval = $this->defaultval;
			if($this->scale60)
				$newval = (int)($newval / 60);
			$h .= selectInputHTML('', $affils, "{$this->domidbase}newaffilid", "dojoType=\"dijit.form.Select\"");
			$h .= "<input dojoType=\"dijit.form.NumberSpinner\" ";
			$h .=        "required=\"1\" ";
			$h .=        "style=\"width: 70px;\" ";
			$h .=        "value=\"$newval\" ";
			$h .=        "constraints=\"{min:1, max:{$this->maxval}}\" ";
			$h .=        "smallDelta=\"1\" ";
			$h .=        "largeDelta=\"10\" ";
			$h .=        "id=\"{$this->domidbase}newval\">\n";
			$h .= dijitButton("{$this->domidbase}addbtn", _('Add'), "{$this->jsname}.addAffiliationSetting();");
			$cont = addContinuationsEntry('AJaddAffiliationSetting', $this->basecdata);
			$h .= "<input type=\"hidden\" id=\"{$this->domidbase}addcont\" value=\"$cont\">\n";
			$h .= "</div>\n";

			$cdata = $this->basecdata;
			$cdata['origvals'] = $origvals;
			$cont = addContinuationsEntry('AJdeleteAffiliationSetting', $cdata);
			$h .= "<input type=\"hidden\" id=\"delete{$this->domidbase}cont\" value=\"$cont\">\n";
		}

		$tmp = array_keys($origvals);
		$keys = implode(',', $tmp);
		$h .= "<div id=\"{$this->domidbase}msg\"></div>\n";
		$h .= "<input type=\"hidden\" id=\"{$this->domidbase}savekeys\" value=\"$keys\">\n";
		$h .= dijitButton("{$this->domidbase}btn", _('Submit Changes'), "{$this->jsname}.saveSettings();", 1);
		$cdata = $this->basecdata;
		$cdata['origvals'] = $origvals;
		$cont = addContinuationsEntry('AJupdateAllSettings', $cdata);
		$h .= "<input type=\"hidden\" id=\"{$this->domidbase}cont\" value=\"$cont\">\n";
		$h .= "</div>\n";
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddAffiliationSetting()
	///
	/// \brief adds an affiliation specific time variables
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJaddAffiliationSetting() {
		global $user;
		if(! checkUserHasPerm('Site Configuration (global)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => _('You do not have access to modify settings for other affiliations.'));
			sendJSON($arr);
			return;
		}
		$affilid = processInputVar('affilid', ARG_NUMERIC);
		$affils = getAffiliations();
		if(! array_key_exists($affilid, $affils)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => _('Invalid affiliation submitted.'));
			sendJSON($arr);
			return;
		}
		$value = processInputVar('value', ARG_NUMERIC);
		if($value < 1 || $value > $this->maxval) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => _('Invalid value submitted.'));
			sendJSON($arr);
			return;
		}
		$affil = $affils[$affilid];
		$newval = $value;
		if($this->scale60)
			$newval = $newval * 60;
		setVariable("{$this->key}|$affil", $newval, 'none');

		# recreate delete and update continuations
		$data = getVariablesRegex("^{$this->key}.*");
		$origvals = array();
		$origvals[$this->key] = array('key' => $this->key, 'val' => $data[$this->key]);
		foreach($data as $prekey => $val) {
			$key = str_replace('|', '_', $prekey);
			$origvals[$key] = array('key' => $prekey, 'val' => $val);
		}
		$cdata = $this->basecdata;
		$cdata['origvals'] = $origvals;
		$delcont = addContinuationsEntry('AJdeleteAffiliationSetting', $cdata);
		$savecont = addContinuationsEntry('AJupdateAllSettings', $cdata);

		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'btn' => "{$this->domidbase}addbtn",
		             'affil' => $affil,
		             'affilid' => $affilid,
		             'value' => $value,
		             'id' => "{$this->key}_$affil",
		             'extrafunc' => "{$this->jsname}.addAffiliationSettingCBextra",
		             'deletecont' => $delcont,
		             'savecont' => $savecont,
		             'maxval' => $this->maxval,
		             'msg' => sprintf($this->addmsg, $affil));
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJupdateAllSettings()
	///
	/// \brief updates all values for implemented type of timevariable
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJupdateAllSettings() {
		if(! checkUserHasPerm('Site Configuration (global)') &&
		   ! checkUserHasPerm('Site Configuration (affiliation only)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => _('You do not have access to modify the submitted settings.'));
			sendJSON($arr);
			return;
		}
		$origvals = getContinuationVar('origvals');
		$newvals = array();
		foreach($origvals as $id => $arr) {
			$tmp = processInputVar($id, ARG_NUMERIC);
			if($tmp < 1 || $tmp > $this->maxval) {
				if($id == $this->key)
					$affil = 'global';
				else {
					$tmp = explode('|', $arr['key']);
					$affil = $tmp[1];
				}
				$arr = array('status' => 'failed',
				             'msgid' => "{$this->domidbase}msg",
				             'btn' => "{$this->domidbase}btn",
				             'errmsg' => _("Invalid value submitted for ") . $affil);
				sendJSON($arr);
				return;
			}
			$newval = $tmp;
			if($this->scale60)
				$newval = $newval * 60;
			if($newval != $arr['val'])
				$newvals[$arr['key']] = $newval;
		}
		foreach($newvals as $key => $val)
			setVariable($key, $val, 'none');
		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'btn' => "{$this->domidbase}btn",
		             'msg' => $this->updatemsg);
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJdeleteAffiliationSetting()
	///
	/// \brief deletes an affiliation specific time variable
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJdeleteAffiliationSetting() {
		if(! checkUserHasPerm('Site Configuration (global)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => _('You do not have access to delete the submitted setting.'));
			sendJSON($arr);
			return;
		}
		$key = processInputVar('key', ARG_STRING);
		$origvals = getContinuationVar('origvals');
		if(! array_key_exists($key, $origvals)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'msg' => _('Invalid data submitted.'));
			sendJSON($arr);
			return;
		}
		$tmp = explode('|', $origvals[$key]['key']);
		$affil = $tmp[1];
		$affilid = getAffiliationID($affil);
		deleteVariable($origvals[$key]['key']);

		# recreate update continuation
		$data = getVariablesRegex("^{$this->key}.*");
		$origvals = array();
		$origvals[$this->key] = array('key' => $this->key, 'val' => $data[$this->key]);
		foreach($data as $prekey => $val) {
			$okey = str_replace('|', '_', $prekey);
			$origvals[$okey] = array('key' => $prekey, 'val' => $val);
		}
		$cdata = $this->basecdata;
		$cdata['origvals'] = $origvals;
		$savecont = addContinuationsEntry('AJupdateAllSettings', $cdata);

		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'delid' => $key,
		             'affil' => $affil,
		             'affilid' => $affilid,
		             'savecont' => $savecont,
		             'extrafunc' => "{$this->jsname}.deleteAffiliationSettingCBextra",
		             'msg' => sprintf($this->delmsg, $affil));
		sendJSON($arr);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class connectedUserCheck
///
/// \brief extends TimeVariable class to implement ignore_connections_gte
///
////////////////////////////////////////////////////////////////////////////////
class connectedUserCheck extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('Connected User Check Timeout');
		$this->key = 'ignore_connections_gte';
		$this->desc = _("Do not perform user-logged-in time out checks if reservation duration is greater than the specified value (in hours).");
		$this->domidbase = 'connectedusercheck';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'connectedUserCheck';
		$this->scale60 = 1;
		$this->defaultval = 1440;
		$this->maxval = 168;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class acknowledge
///
/// \brief extends TimeVariable class to implement acknowledgetimeout
///
////////////////////////////////////////////////////////////////////////////////
class acknowledge extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('Acknowledge Reservation Timeout');
		$this->key = 'acknowledgetimeout';
		$this->desc = _("Once a reservation is ready, users have this long to click the Connect button before the reservation is timed out (in minutes, does not apply to Server Reservations).");
		$this->domidbase = 'acknowledge';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'acknowledge';
		$this->scale60 = 1;
		$this->maxval = 60;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class connect
///
/// \brief extends TimeVariable class to implement connecttimeout
///
////////////////////////////////////////////////////////////////////////////////
class connect extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('Connect To Reservation Timeout');
		$this->key = 'connecttimeout';
		$this->desc = _("After clicking the Connect button for a reservation, users have this long to connect to a reserved node before the reservation is timed out (in minutes, does not apply to Server Reservations).");
		$this->domidbase = 'connect';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'connect';
		$this->scale60 = 1;
		$this->maxval = 60;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class reconnect
///
/// \brief extends TimeVariable class to implement wait_for_reconnect
///
////////////////////////////////////////////////////////////////////////////////
class reconnect extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('Re-connect To Reservation Timeout');
		$this->key = 'wait_for_reconnect';
		$this->desc = _("After disconnecting from a reservation, users have this long to reconnect to a reserved node before the reservation is timed out (in minutes, does not apply to Server Reservations).");
		$this->domidbase = 'reconnect';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'reconnect';
		$this->scale60 = 1;
		$this->maxval = 60;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class generalInuse
///
/// \brief extends TimeVariable class to implement general_inuse_check
///
////////////////////////////////////////////////////////////////////////////////
class generalInuse extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('In-Use Reservation Check');
		$this->key = 'general_inuse_check';
		$this->desc = _("Frequency at which a general check of each reservation is done (in minutes).");
		$this->domidbase = 'generalinuse';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'generalInuse';
		$this->scale60 = 1;
		$this->maxval = 60;
		$this->defaultval = 300;
		$this->addmsg = _("In-Use check for %s added");
		$this->updatemsg = _("In-Use check values saved");
		$this->delmsg = _("In-Use check for %s deleted");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class serverInuse
///
/// \brief extends TimeVariable class to implement server_inuse_check
///
////////////////////////////////////////////////////////////////////////////////
class serverInuse extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('In-Use Reservation Check (servers)');
		$this->key = 'server_inuse_check';
		$this->desc = _("Frequency at which a general check of each server reservation is done (in minutes).");
		$this->domidbase = 'serverinuse';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'serverInuse';
		$this->scale60 = 1;
		$this->maxval = 240;
		$this->defaultval = 900;
		$this->addmsg = _("In-Use check for %s added");
		$this->updatemsg = _("In-Use check values saved");
		$this->delmsg = _("In-Use check for %s deleted");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class clusterInuse
///
/// \brief extends TimeVariable class to implement cluster_inuse_check
///
////////////////////////////////////////////////////////////////////////////////
class clusterInuse extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('In-Use Reservation Check (clusters)');
		$this->key = 'cluster_inuse_check';
		$this->desc = _("Frequency at which a general check of each cluster reservation is done (in minutes).");
		$this->domidbase = 'clusterinuse';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'clusterInuse';
		$this->scale60 = 1;
		$this->maxval = 240;
		$this->defaultval = 900;
		$this->addmsg = _("In-Use check for %s added");
		$this->updatemsg = _("In-Use check values saved");
		$this->delmsg = _("In-Use check for %s deleted");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class generalEndNotice1
///
/// \brief extends TimeVariable class to implement general_end_notice_first
///
////////////////////////////////////////////////////////////////////////////////
class generalEndNotice1 extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('First Notice For Reservation Ending');
		$this->key = 'general_end_notice_first';
		$this->desc = _("Users are notified two times that their reservations are going to end when getting close to the end time. This is the time before the end that the first of those notices should be sent.");
		$this->domidbase = 'generalendnotice1';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'generalEndNotice1';
		$this->scale60 = 1;
		$this->maxval = 120;
		$this->defaultval = 600;
		$this->addmsg = _("End notice time for %s added");
		$this->updatemsg = _("End notice time values saved");
		$this->delmsg = _("End notice time for %s deleted");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class generalEndNotice2
///
/// \brief extends TimeVariable class to implement general_end_notice_second
///
////////////////////////////////////////////////////////////////////////////////
class generalEndNotice2 extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('Second Notice For Reservation Ending');
		$this->key = 'general_end_notice_second';
		$this->desc = _("Users are notified two times that their reservations are going to end when getting close to the end time. This is the time before the end that the second of those notices should be sent.");
		$this->domidbase = 'generalendnotice2';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'generalEndNotice2';
		$this->scale60 = 1;
		$this->maxval = 60;
		$this->defaultval = 300;
		$this->addmsg = _("End notice time for %s added");
		$this->updatemsg = _("End notice time values saved");
		$this->delmsg = _("End notice time for %s deleted");
	}
}

?>
