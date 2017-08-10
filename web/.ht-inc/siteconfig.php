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
		print "<h2>" . i("Site Configuration") . "</h2>\n";
		print "You do not have access to this part of the site.<br>\n";
		return;
	}
	$h = '';
	$h .= "<h2>" . i("Site Configuration") . "</h2>\n";

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
	global $user;
	$h = '';
	#$h .= "<div id=\"globalopts\" dojoType=\"dijit.layout.ContentPane\" title=\"Global Options\">\n";

	# -------- full width -----------
	$h .= timeSourceHTML($globalopts);
	if($globalopts) {
		$obj = new NFSmounts();
		$h .= $obj->getHTML();
	}
	$obj = new Messages($globalopts);
	$h .= $obj->getHTML();
	# ------ end full width ---------

	$h .= "<div id=\"siteconfiglayout\">\n";

	# -------- left column ---------
	$h .= "<div id=\"siteconfigleftcol\">\n";
	if($globalopts) {
		$obj = new userPasswordLength();
		$h .= $obj->getHTML();
		$obj = new userPasswordSpecialChar();
		$h .= $obj->getHTML();
		$obj = new Affiliations();
		$h .= $obj->getHTML($globalopts);
	}
	$obj = new AffilHelpAddress();
	$h .= $obj->getHTML($globalopts);
	$obj = new AffilWebAddress();
	$h .= $obj->getHTML($globalopts);
	$obj = new AffilTheme();
	$h .= $obj->getHTML($globalopts);
	if($globalopts) {
		$obj = new AffilShibOnly();
		$h .= $obj->getHTML($globalopts);
	}
	if($globalopts || $user['affiliationid'] != getAffiliationID('Local')) {
		$obj = new AffilShibName();
		$h .= $obj->getHTML($globalopts);
	}
	$obj = new AffilKMSserver();
	$h .= $obj->getHTML($globalopts);
	$h .= "</div>\n"; # siteconfigleftcol
	# -------- end left column ---------


	# ---------- right column ---------
	$h .= "<div id=\"siteconfigrightcol\">\n";
	$obj = new connectedUserCheck();
	$h .= $obj->getHTML($globalopts);
	$obj = new acknowledge();
	$h .= $obj->getHTML($globalopts);
	$obj = new initialconnecttimeout();
	$h .= $obj->getHTML($globalopts);
	$obj = new reconnecttimeout();
	$h .= $obj->getHTML($globalopts);
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
	if($globalopts) {
		$obj = new NATportRange();
		$h .= $obj->getHTML();
	}
	$h .= "</div>\n"; # siteconfigrightcol
	# -------- end right column --------

	$h .= "</div>\n"; # siteconfiglayout

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
	$h .= "<h3>" . i("Time Source") . "</h3>\n";
	$h .= "<div class=\"siteconfigdesc\">\n";
	$h .= i("Set the default list of time servers to be used on installed nodes. These can be overridden for each management node under the settings for a given management node. Separate hostnames using a comma (,).") . "<br><br>\n";
	$h .= "</div>\n";
	$val = getVariable('timesource|global', '', 1);
	$hostreg = '(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])';
	$h .= labeledFormItem('timesource', i('Time Servers'), 'text', "^($hostreg){1}(,$hostreg)*$", '', $val['value']);
	$h .= "<div id=\"timesourcemsg\"></div>\n";
	$h .= dijitButton('timesourcebtn', i('Submit Changes'), "saveTimeSource();", 1);
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
		             'msg' => i('You do not have access to set the global Time Server setting.'));
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
				             'errmsg' => i('Invalid server(s) specified.'));
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
	             'msg' => i('Time Server successfully updated'));
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
	var $minval;
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
		$this->addmsg = i("Time out for %s added");
		$this->updatemsg = i("Time out values saved");
		$this->delmsg = i("Time out for %s deleted");
		$this->minval = 5;
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
		$h .= "<div class=\"siteconfigdesc\">\n";
		$h .= $this->desc;
		$h .= "<br><br></div>\n";

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
			$label = i('Global');
			unset_by_val(i('Global'), $affils);
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
		$h .= labeledFormItem($key, $label, 'spinner', "{min:{$this->minval}, max:{$this->maxval}}", 1, $dispval, '', '', $extra, '', '', 0);
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
				$h .= labeledFormItem($key, $label, 'spinner', "{min:{$this->minval}, max:{$this->maxval}}", 1, $dispval, '', '', $extra, '', '', 0);
				$h .= dijitButton("{$key}delbtn", i("Delete"), "{$this->jsname}.deleteAffiliationSetting('$key', '{$this->domidbase}');") . "<br>\n";
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
			$h .= selectInputHTML('', $affils, "{$this->domidbase}newaffilid",
			                      "dojoType=\"dijit.form.Select\" maxHeight=\"250\"");
			$h .= "<input dojoType=\"dijit.form.NumberSpinner\" ";
			$h .=        "required=\"1\" ";
			$h .=        "style=\"width: 70px;\" ";
			$h .=        "value=\"$newval\" ";
			$h .=        "constraints=\"{min:{$this->minval}, max:{$this->maxval}}\" ";
			$h .=        "smallDelta=\"1\" ";
			$h .=        "largeDelta=\"10\" ";
			$h .=        "id=\"{$this->domidbase}newval\">\n";
			$h .= dijitButton("{$this->domidbase}addbtn", i('Add'), "{$this->jsname}.addAffiliationSetting();");
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
		$h .= dijitButton("{$this->domidbase}btn", i('Submit Changes'), "{$this->jsname}.saveSettings();", 1);
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
			             'msg' => i('You do not have access to modify settings for other affiliations.'));
			sendJSON($arr);
			return;
		}
		$affilid = processInputVar('affilid', ARG_NUMERIC);
		$affils = getAffiliations();
		if(! array_key_exists($affilid, $affils)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => i('Invalid affiliation submitted.'));
			sendJSON($arr);
			return;
		}
		$value = processInputVar('value', ARG_NUMERIC);
		if($value < $this->minval || $value > $this->maxval) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => i('Invalid value submitted.'));
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
		             'minval' => $this->minval,
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
			             'msg' => i('You do not have access to modify the submitted settings.'));
			sendJSON($arr);
			return;
		}
		$origvals = getContinuationVar('origvals');
		$newvals = array();
		foreach($origvals as $id => $arr) {
			$tmp = processInputVar($id, ARG_NUMERIC);
			if($tmp < $this->minval || $tmp > $this->maxval) {
				if($id == $this->key)
					$affil = 'global';
				else {
					$tmp = explode('|', $arr['key']);
					$affil = $tmp[1];
				}
				$arr = array('status' => 'failed',
				             'msgid' => "{$this->domidbase}msg",
				             'btn' => "{$this->domidbase}btn",
				             'errmsg' => i("Invalid value submitted for ") . $affil);
				sendJSON($arr);
				return;
			}
			$newval = $tmp;
			if($this->scale60)
				$newval = $newval * 60;
			if($newval != $arr['val'])
				$newvals[$arr['key']] = $newval;
			$origvals[$id]['val'] = $newval;
		}
		foreach($newvals as $key => $val)
			setVariable($key, $val, 'none');

		$cdata = $this->basecdata;
		$cdata['origvals'] = $origvals;
		$savecont = addContinuationsEntry('AJupdateAllSettings', $cdata);

		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'btn' => "{$this->domidbase}btn",
		             'msg' => $this->updatemsg,
		             'contid' => "{$this->domidbase}cont",
		             'savecont' => $savecont);
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
			             'msg' => i('You do not have access to delete the submitted setting.'));
			sendJSON($arr);
			return;
		}
		$key = processInputVar('key', ARG_STRING);
		$origvals = getContinuationVar('origvals');
		if(! array_key_exists($key, $origvals)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'msg' => i('Invalid data submitted.'));
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
		$this->name = i('Connected User Check Threshold');
		$this->key = 'ignore_connections_gte';
		$this->desc = i("Do not perform user-logged-in time out checks if reservation duration is greater than the specified value (in hours).");
		$this->domidbase = 'connectedusercheck';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'connectedUserCheck';
		$this->scale60 = 1;
		$this->defaultval = 1440;
		$this->minval = 0;
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
		$this->name = i('Acknowledge Reservation Timeout');
		$this->key = 'acknowledgetimeout';
		$this->desc = i("Once a reservation is ready, users have this long to click the Connect button before the reservation is timed out (in minutes, does not apply to Server Reservations).");
		$this->domidbase = 'acknowledge';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'acknowledge';
		$this->scale60 = 1;
		$this->maxval = 60;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class initialconnecttimeout
///
/// \brief extends TimeVariable class to implement initialconnecttimeout
///
////////////////////////////////////////////////////////////////////////////////
class initialconnecttimeout extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i('Connect To Reservation Timeout');
		$this->key = 'initialconnecttimeout';
		$this->desc = i("After clicking the Connect button for a reservation, users have this long to connect to a reserved node before the reservation is timed out (in minutes, does not apply to Server Reservations).");
		$this->domidbase = 'initialconnecttimeout';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'initialconnecttimeout';
		$this->scale60 = 1;
		$this->maxval = 60;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class reconnecttimeout
///
/// \brief extends TimeVariable class to implement reconnecttimeout
///
////////////////////////////////////////////////////////////////////////////////
class reconnecttimeout extends TimeVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i('Reconnect To Reservation Timeout');
		$this->key = 'reconnecttimeout';
		$this->desc = i("After disconnecting from a reservation, users have this long to reconnect to a reserved node before the reservation is timed out (in minutes, does not apply to Server Reservations).");
		$this->domidbase = 'reconnecttimeout';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'reconnecttimeout';
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
		$this->name = i('In-Use Reservation Check');
		$this->key = 'general_inuse_check';
		$this->desc = i("Frequency at which a general check of each reservation is done (in minutes).");
		$this->domidbase = 'generalinuse';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'generalInuse';
		$this->scale60 = 1;
		$this->maxval = 60;
		$this->defaultval = 300;
		$this->addmsg = i("In-Use check for %s added");
		$this->updatemsg = i("In-Use check values saved");
		$this->delmsg = i("In-Use check for %s deleted");
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
		$this->name = i('In-Use Reservation Check (servers)');
		$this->key = 'server_inuse_check';
		$this->desc = i("Frequency at which a general check of each server reservation is done (in minutes).");
		$this->domidbase = 'serverinuse';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'serverInuse';
		$this->scale60 = 1;
		$this->maxval = 240;
		$this->defaultval = 900;
		$this->addmsg = i("In-Use check for %s added");
		$this->updatemsg = i("In-Use check values saved");
		$this->delmsg = i("In-Use check for %s deleted");
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
		$this->name = i('In-Use Reservation Check (clusters)');
		$this->key = 'cluster_inuse_check';
		$this->desc = i("Frequency at which a general check of each cluster reservation is done (in minutes).");
		$this->domidbase = 'clusterinuse';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'clusterInuse';
		$this->scale60 = 1;
		$this->maxval = 240;
		$this->defaultval = 900;
		$this->addmsg = i("In-Use check for %s added");
		$this->updatemsg = i("In-Use check values saved");
		$this->delmsg = i("In-Use check for %s deleted");
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
		$this->name = i('First Notice For Reservation Ending');
		$this->key = 'general_end_notice_first';
		$this->desc = i("Users are notified two times that their reservations are going to end when getting close to the end time. This is the time before the end that the first of those notices should be sent.");
		$this->domidbase = 'generalendnotice1';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'generalEndNotice1';
		$this->scale60 = 1;
		$this->maxval = 120;
		$this->defaultval = 600;
		$this->addmsg = i("End notice time for %s added");
		$this->updatemsg = i("End notice time values saved");
		$this->delmsg = i("End notice time for %s deleted");
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
		$this->name = i('Second Notice For Reservation Ending');
		$this->key = 'general_end_notice_second';
		$this->desc = i("Users are notified two times that their reservations are going to end when getting close to the end time. This is the time before the end that the second of those notices should be sent.");
		$this->domidbase = 'generalendnotice2';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'generalEndNotice2';
		$this->scale60 = 1;
		$this->maxval = 60;
		$this->defaultval = 300;
		$this->addmsg = i("End notice time for %s added");
		$this->updatemsg = i("End notice time values saved");
		$this->delmsg = i("End notice time for %s deleted");
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class AffilTextVariable
///
/// \brief base class for text variables assigned per affiliation
///
////////////////////////////////////////////////////////////////////////////////
class AffilTextVariable {
	var $basecdata;
	var $name;
	var $desc;
	var $values;
	var $constraints;
	var $errmsg;
	var $domidbase;
	var $jsname;
	var $addmsg;
	var $updatemsg;
	var $delmsg;
	var $width;
	var $vartype;
	var $allowdelete;
	var $updatefailmsg;
	var $affils;
	var $allowempty;
	var $allowglobalempty;
	var $globalid;

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		$this->basecdata = array('obj' => $this);
		$this->getValues();
		$this->width = '200px';
		$this->vartype = 'text';
		$this->allowdelete = 1;
		$this->updatefailmsg = i('Failed to update data for these affiliations:');
		$this->affils = getAffiliations();
		$this->allowempty = 0;
		$this->allowglobalempty = 0;
		$this->globalid = getAffiliationID('Global');
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getValues()
	///
	/// \brief gets assigned values from database and sets in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function getValues() {
		$this->values = array();
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValue($affilid, $value)
	///
	/// \param $affilid - affiliationid
	/// \param $value - value to be set for $affilid
	///
	/// \brief sets values in database
	///
	/// \return 1 if successfully set values, 0 if error encountered setting
	/// values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValue($affilid, $value) {
		return 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($affilid)
	///
	/// \param $affilid - affiliationid
	///
	/// \brief deletes a value from the database
	///
	/// \return 1 if successfully deleted value, 0 if error encountered
	///
	/////////////////////////////////////////////////////////////////////////////
	function deleteValue($affilid) {
		return 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateValue($value)
	///
	/// \param $value - value to be validated
	///
	/// \brief validates a submitted value
	///
	/// \return 1 if $value is valid, 0 if $value is not valid
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateValue($value) {
		$test = str_replace("/", "\/", $this->constraints);
		if(preg_match("/$test/", $value))
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getHTML()
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for setting text variables
	///
	/////////////////////////////////////////////////////////////////////////////
	function getHTML($globalopts) {
		global $user;
		$h  = "<div class=\"configwidget\" style=\"width: 100%;\">\n";
		$h .= "<h3>{$this->name}</h3>\n";
		$h .= "<div class=\"siteconfigdesc\">\n";
		$h .= $this->desc;
		$h .= "<br><br></div>\n";

		$affils = $this->affils;
		$saveids = array();

		$nooptions = 0;
		if(count($affils) == 0)
			$nooptions = 1;

		$required = 0;

		if($globalopts) {
			if(isset($this->values[$this->globalid])) {
				$key = "{$this->domidbase}_{$this->globalid}";
				$val = $this->values[$this->globalid];
				$label = i('Global');
				unset_by_val(i('Global'), $affils);
				$required = ! $this->allowglobalempty;
			}
		}
		else {
			if(isset($this->values[$this->globalid])) {
				$defaultval = $this->values[$this->globalid];
				$h .= i('Default value') . ": $defaultval<br>\n";
			}
			$key = "{$this->domidbase}_{$user['affiliationid']}";
			$val = $this->values[$user['affiliationid']];
			if($this->vartype != 'text' && $val === NULL)
				$val = $defaultval;
			$label = $user['affiliation'];
		}
		if(isset($key)) {
			$saveids[] = $key;
			$h .= labeledFormItem($key, $label, $this->vartype, $this->constraints, $required, $val, $this->errmsg, '', '', $this->width); 
		}
		if($globalopts) {
			$h .= "<div id=\"{$this->domidbase}affildiv\">\n";
			foreach($affils as $affil => $name) {
				if(! isset($this->values[$affil]))
					continue;
				if($this->values[$affil] === NULL || $this->values[$affil] === '')
					continue;
				$key = "{$this->domidbase}_$affil";
				$saveids[] = $key;
				$h .= "<span id=\"{$key}span\">\n";
				$h .= labeledFormItem($key, $name, $this->vartype, $this->constraints, 1, $this->values[$affil], $this->errmsg, '', '', $this->width, '', 0);
				if($this->allowdelete)
					$h .= dijitButton("{$key}delbtn", i("Delete"), "{$this->jsname}.deleteAffiliationSetting('$affil', '{$this->domidbase}');");
				$h .= "<br>\n";
				$h .= "</span>\n";
				unset_by_val($name, $affils);
			}
			$h .= "</div>\n";
			$h .= "<div id=\"{$this->domidbase}adddiv\"";
			if(! count($affils))
				$h .= " class=\"hidden\"";
			$h .= ">\n";
			$h .= selectInputHTML('', $affils, "{$this->domidbase}newaffilid",
										 "dojoType=\"dijit.form.Select\" maxHeight=\"250\"");
			switch($this->vartype) {
				case 'text':
					$h .= "<input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
					$h .= "id=\"{$this->domidbase}newval\" required=\"true\" invalidMessage=\"{$this->errmsg}\" ";
					$h .= "regExp=\"{$this->constraints}\" style=\"width: {$this->width};\">\n";
					break;
				case 'selectonly':
					$h .= selectInputHTML('', $this->constraints, "{$this->domidbase}newval", "dojoType=\"dijit.form.Select\" maxHeight=\"250\" style=\"width: {$this->width};\"");
					break;
			}
			$h .= dijitButton("{$this->domidbase}addbtn", i('Add'), "{$this->jsname}.addAffiliationSetting();");
			$cont = addContinuationsEntry('AJaddAffiliationSetting', $this->basecdata);
			$h .= "<input type=\"hidden\" id=\"{$this->domidbase}addcont\" value=\"$cont\">\n";
			$h .= "</div>\n";
			$cdata = $this->basecdata;
			$cdata['origvals'] = $this->values;
			if($this->allowdelete) {
				$cont = addContinuationsEntry('AJdeleteAffiliationSetting', $cdata);
				$h .= "<input type=\"hidden\" id=\"delete{$this->domidbase}cont\" value=\"$cont\">\n";
			}
		}
		$h .= "<div id=\"{$this->domidbase}msg\"></div>\n";
		$saveids = implode(',', $saveids);
		$h .= "<input type=\"hidden\" id=\"{$this->domidbase}savekeys\" value=\"$saveids\">\n";
		if($nooptions)
			$h .= "(There are currently no options that can be set in this section.)<br><br>";
		else {
			$h .= dijitButton("{$this->domidbase}btn", i('Submit Changes'), "{$this->jsname}.saveSettings();", 1);
			$cdata = $this->basecdata;
			$cdata['origvals'] = $this->values;
			$cont = addContinuationsEntry('AJupdateAllSettings', $cdata);
			$h .= "<input type=\"hidden\" id=\"{$this->domidbase}cont\" value=\"$cont\">\n";
		}
		$h .= "</div>\n";
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddAffiliationSetting()
	///
	/// \brief adds an affiliation specific text setting
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJaddAffiliationSetting() {
		global $user;
		if(! checkUserHasPerm('Site Configuration (global)') &&
		   ! checkUserHasPerm('Site Configuration (affiliation only)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => i('You do not have access to modify the submitted setting.'));
			sendJSON($arr);
			return;
		}
		$affilid = processInputVar('affilid', ARG_NUMERIC);
		$affils = $this->affils;
		if(! array_key_exists($affilid, $affils)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => i('Invalid affiliation submitted.'));
			sendJSON($arr);
			return;
		}
		$value = processInputVar('value', ARG_STRING);
		if(! $this->validateValue($value)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => i('Invalid value submitted.'),
			             'btn' => "{$this->domidbase}addbtn");
			sendJSON($arr);
			return;
		}

		if(! $this->setValue($affilid, $value)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => i('Failed to add submited value'),
			             'btn' => "{$this->domidbase}addbtn");
			sendJSON($arr);
			return;
		}

		# recreate delete and update continuations
		$this->getValues();
		$cdata = $this->basecdata;
		$cdata['origvals'] = $this->values;
		$delcont = addContinuationsEntry('AJdeleteAffiliationSetting', $cdata);
		$savecont = addContinuationsEntry('AJupdateAllSettings', $cdata);

		$affil = $affils[$affilid];
		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'btn' => "{$this->domidbase}addbtn",
		             'affil' => $affil,
		             'affilid' => $affilid,
		             'value' => $value,
		             'id' => "{$this->domidbase}_$affilid",
		             'extrafunc' => "{$this->jsname}.addAffiliationSettingCBextra",
		             'deletecont' => $delcont,
		             'savecont' => $savecont,
		             'constraints' => $this->constraints,
		             'invalidmsg' => $this->errmsg,
		             'msg' => sprintf($this->addmsg, $affil),
		             'vartype' => $this->vartype,
		             'allowdelete' => $this->allowdelete,
		             'width' => $this->width);
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJupdateAllSettings()
	///
	/// \brief updates all values for implemented type of AffilTextVariable
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJupdateAllSettings() {
		global $user;
		if(! checkUserHasPerm('Site Configuration (global)') &&
		   ! checkUserHasPerm('Site Configuration (affiliation only)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => i('You do not have access to modify the submitted settings.'));
			sendJSON($arr);
			return;
		}
		$affilonly = 0;
		if(! checkUserHasPerm('Site Configuration (global)'))
			$affilonly = 1;
		$origvals = getContinuationVar('origvals');
		$newvals = array();
		foreach($origvals as $affilid => $val) {
			if($affilonly && $affilid != $user['affiliationid'])
				continue;
			$id = "{$this->domidbase}_$affilid";
			$newval = processInputVar($id, ARG_STRING);
			if($newval !== NULL ||
			   ! $this->allowempty ||
			   ($affilid == $this->globalid && ! $this->allowglobalempty)) {
				if(! $this->validateValue($newval)) {
					$affil = getAffiliationName($affilid);
					$arr = array('status' => 'failed',
					             'msgid' => "{$this->domidbase}msg",
					             'btn' => "{$this->domidbase}btn",
					             'errmsg' => i("Invalid value submitted for ") . $affil);
					sendJSON($arr);
					return;
				}
			}
			if($newval != $val)
				$newvals[$affilid] = $newval;

		}
		$fails = array();
		foreach($newvals as $affilid => $val) {
			if(! $this->setValue($affilid, $val))
				$fails[] = getAffiliationName($affilid);
		}

		# recreate save continuation
		$cdata = $this->basecdata;
		$this->getValues();
		$cdata['origvals'] = $this->values;
		$savecont = addContinuationsEntry('AJupdateAllSettings', $cdata);

		if(count($fails)) {
			$msg = $this->updatefailmsg . ' ' . implode(', ', $fails);
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => $msg,
			             'btn' => "{$this->domidbase}btn",
			             'contid' => "{$this->domidbase}cont",
			             'savecont' => $savecont);
			sendJSON($arr);
			return;
		}

		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'msg' => $this->updatemsg,
		             'btn' => "{$this->domidbase}btn",
		             'contid' => "{$this->domidbase}cont",
		             'savecont' => $savecont);
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJdeleteAffiliationSetting()
	///
	/// \brief deletes a text variable for an affiliation
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJdeleteAffiliationSetting() {
		if(! checkUserHasPerm('Site Configuration (global)') &&
		   ! checkUserHasPerm('Site Configuration (affiliation only)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => i('You do not have access to delete the submitted setting.'));
			sendJSON($arr);
			return;
		}
		$affilid = processInputVar('affilid', ARG_NUMERIC);
		$origvals = getContinuationVar('origvals');
		if(! array_key_exists($affilid, $origvals)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'msg' => i('Invalid data submitted.'));
			sendJSON($arr);
			return;
		}

		$affil = getAffiliationName($affilid);
		if(! $this->deleteValue($affilid)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'errmsg' => sprintf(i("Failed to delete address for %s"), $affil),
			             'btn' => "{$this->domidbase}addbtn");
			sendJSON($arr);
			return;
		}

		# recreate delete and update continuations
		$this->getValues();
		$cdata = $this->basecdata;
		$cdata['origvals'] = $this->values;
		$delcont = addContinuationsEntry('AJdeleteAffiliationSetting', $cdata);
		$savecont = addContinuationsEntry('AJupdateAllSettings', $cdata);

		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'delid' => "{$this->domidbase}_$affilid",
		             'affil' => $affil,
		             'affilid' => $affilid,
		             'contid' => "{$this->domidbase}cont",
		             'savecont' => $savecont,
		             'delcont' => $delcont,
		             'extrafunc' => "{$this->jsname}.deleteAffiliationSettingCBextra",
		             'msg' => sprintf($this->delmsg, $affil));
		sendJSON($arr);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class AffilHelpAddress
///
/// \brief extends AffilTextVariable to implement AffilHelpAddress
///
////////////////////////////////////////////////////////////////////////////////
class AffilHelpAddress extends AffilTextVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i("Help Email Address");
		$this->desc = i("This is the email address used as the from address for emails sent by the VCL system to users.");
		$this->constraints = '^([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4},)*([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})$';
		$this->errmsg = i("Invalid email address(es) specified");
		$this->domidbase = "affilhelpaddr";
		$this->jsname = "affilhelpaddr";
		$this->addmsg = i("Help Email Address added for %s");
		$this->updatemsg = i("Update successful");
		$this->delmsg = i("Address for %s deleted");
		$this->allowempty = 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getValues()
	///
	/// \brief gets assigned values from database and sets in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function getValues() {
		$this->values = array();
		$query = "SELECT id, helpaddress FROM affiliation ORDER BY name";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$this->values[$row['id']] = $row['helpaddress'];
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValue($affilid, $value)
	///
	/// \param $affilid - affiliationid
	/// \param $value - value to be set for $affilid
	///
	/// \brief sets values in database
	///
	/// \return 1 if successfully set values, 0 if error encountered setting
	/// values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValue($affilid, $value) {
		global $mysql_link_vcl;
		if($value === NULL)
			$newval = 'NULL';
		else {
			$esc_value = mysql_real_escape_string($value);
			$newval = "'$esc_value'";
		}
		$query = "UPDATE affiliation "
		       . "SET helpaddress = $newval "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($affilid)
	///
	/// \param $affilid - affiliationid
	///
	/// \brief deletes a value from the database
	///
	/// \return 1 if successfully deleted value, 0 if error encountered
	///
	/////////////////////////////////////////////////////////////////////////////
	function deleteValue($affilid) {
		global $mysql_link_vcl;
		$query = "UPDATE affiliation "
		       . "SET helpaddress = NULL "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class AffilWebAddress
///
/// \brief extends AffilTextVariable to implement AffilWebAddress
///
////////////////////////////////////////////////////////////////////////////////
class AffilWebAddress extends AffilTextVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i("Site Web Address");
		$this->desc = i("This is the web address in emails sent by the VCL system to users.");
		$this->constraints = '^http(s)?://([-A-Za-z0-9]{1,63})(\.[A-Za-z0-9-_]+)*(\.?[A-Za-z0-9])(/[-a-zA-Z0-9\._~&\+,=:@]*)*$';
		$this->errmsg = i("Invalid web address(es) specified");
		$this->domidbase = "affilwebaddr";
		$this->jsname = "affilwebaddr";
		$this->addmsg = i("Web Address added for %s");
		$this->updatemsg = i("Update successful");
		$this->delmsg = i("Web Address for %s deleted");
		$this->allowempty = 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getValues()
	///
	/// \brief gets assigned values from database and sets in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function getValues() {
		$this->values = array();
		$query = "SELECT id, sitewwwaddress FROM affiliation ORDER BY name";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$this->values[$row['id']] = $row['sitewwwaddress'];
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValue($affilid, $value)
	///
	/// \param $affilid - affiliationid
	/// \param $value - value to be set for $affilid
	///
	/// \brief sets values in database
	///
	/// \return 1 if successfully set values, 0 if error encountered setting
	/// values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValue($affilid, $value) {
		global $mysql_link_vcl;
		if($value === NULL)
			$newval = 'NULL';
		else {
			$esc_value = mysql_real_escape_string($value);
			$newval = "'$esc_value'";
		}
		$query = "UPDATE affiliation "
		       . "SET sitewwwaddress = $newval "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($affilid)
	///
	/// \param $affilid - affiliationid
	///
	/// \brief deletes a value from the database
	///
	/// \return 1 if successfully deleted value, 0 if error encountered
	///
	/////////////////////////////////////////////////////////////////////////////
	function deleteValue($affilid) {
		global $mysql_link_vcl;
		$query = "UPDATE affiliation "
		       . "SET sitewwwaddress = NULL "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class AffilKMSserver
///
/// \brief extends AffilTextVariable to implement AffilKMSserver
///
////////////////////////////////////////////////////////////////////////////////
class AffilKMSserver extends AffilTextVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i("KMS Servers");
		$this->desc = i("These are the KMS servers for activating Windows licensing. Multiple servers are allowed, delimited with a comma (,). Non standard ports can be specified after the server delimited with a colon (:). (ex: kms.example.com,kms2.example.com:2000)");
		$regbase = '((((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))|([A-Za-z0-9\-\.]+))(:[0-9]{1,5})?';
		$this->constraints = "$regbase(,$regbase)*";
		$this->errmsg = i("Invalid IP or hostname specified");
		$this->domidbase = "affilkmsserver";
		$this->jsname = "affilkmsserver";
		$this->addmsg = i("KMS server added for %s");
		$this->updatemsg = i("Update successful");
		$this->delmsg = i("KMS server for %s deleted");
		$this->width = '350px';
		$this->allowempty = 1;
		$this->allowglobalempty = 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getValues()
	///
	/// \brief gets assigned values from database and sets in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function getValues() {
		$this->values = array();
		$query = "SELECT a.id, "
		       .        "k.address, "
		       .        "k.port "
		       . "FROM affiliation a "
		       . "LEFT JOIN winKMS k ON (k.affiliationid = a.id) "
		       . "ORDER BY a.id";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh)) {
			if(is_null($row['address']) && is_null($row['port'])) {
				$this->values[$row['id']] = NULL;
				continue;
			}
			if($row['port'] != 1688)
				$addr = "{$row['address']}:{$row['port']}";
			else
				$addr = $row['address'];
			if(array_key_exists($row['id'], $this->values))
				$this->values[$row['id']] .= ",$addr";
			else
				$this->values[$row['id']] = $addr;
		}
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValue($affilid, $value)
	///
	/// \param $affilid - affiliationid
	/// \param $value - must be IP address or hostname; optionally can have a
	/// port added to the end delimited with a colon
	///
	/// \brief sets values in database
	///
	/// \return 1 if successfully set values, 0 if error encountered setting
	/// values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValue($affilid, $value) {
		global $mysql_link_vcl;
		$this->getValues();
		$values = explode(',', $value);
		# create datastructure of newly submitted hosts
		$newhosts = array();
		foreach($values as $host) {
			if(strpos($host, ':') !== FALSE) {
				$tmp = explode(':', $host);
				$address = $tmp[0];
				$port = $tmp[1];
			}
			else {
				$address = $host;
				$port = 1688;
			}
			$newhosts[$address] = $port;
		}
		# create datastructure of old hosts
		$olddata = $this->values[$affilid];
		$oldhosts = array();
		if(! is_null($olddata)) {
			$oldvalues = explode(',', $olddata);
			foreach($oldvalues as $host) {
				if(strpos($host, ':') !== FALSE) {
					$tmp = explode(':', $host);
					$address = $tmp[0];
					$port = $tmp[1];
				}
				else {
					$address = $host;
					$port = 1688;
				}
				$oldhosts[$address] = $port;
			}
		}
		# build set of new hosts
		$adds = array();
		foreach($newhosts as $newhost => $port) {
			if(! array_key_exists($newhost, $oldhosts))
				$adds[$newhost] = $port;
		}
		# build set of hosts with changed port
		$changes = array();
		foreach($newhosts as $newhost => $port) {
			if(array_key_exists($newhost, $oldhosts) &&
			   $port != $oldhosts[$newhost])
				$changes[$newhost] = $port;
		}
		# build set of deleted hosts
		$rems = array();
		foreach($oldhosts as $oldhost => $port) {
			if(! array_key_exists($oldhost, $newhosts))
				$rems[$oldhost] = $port;
		}
		if(count($adds) == 0 && count($changes) == 0 && count($rems) == 0)
			return 1;
		# insert new hosts
		$values = array();
		foreach($adds as $host => $port) {
			$esc_host = mysql_real_escape_string($host);
			$values[] = "($affilid, '$esc_host', $port)";
		}
		$rc1 = 1;
		if(count($values)) {
			$query = "INSERT INTO winKMS "
			       . "(affiliationid, address, port) "
			       . "VALUES " . implode(',', $values);
			doQuery($query);
			$rc1 = mysql_affected_rows($mysql_link_vcl);
		}
		# make changes
		$rc2 = 1;
		foreach($changes as $host => $port) {
			$esc_host = mysql_real_escape_string($host);
			$query = "UPDATE winKMS "
			       . "SET port = $port "
			       . "WHERE address = '$esc_host' AND "
			       .       "affiliationid = $affilid";
			doQuery($query);
			$tmp = mysql_affected_rows($mysql_link_vcl);
			if($rc2)
				$rc2 = $tmp;
		}
		# delete old hosts
		$values = array();
		foreach($rems as $host => $port) {
			$esc_host = mysql_real_escape_string($host);
			$values[] = "(affiliationid = $affilid AND "
			          . "address = '$esc_host' AND "
			          . "port = $port)";
		}
		$rc3 = 1;
		if(count($values)) {
			$query = "DELETE FROM winKMS "
			       . "WHERE " . implode(' OR ', $values);
			doQuery($query);
			$rc3 = mysql_affected_rows($mysql_link_vcl);
		}
		if($rc1 == 0 || $rc2 == 0 || $rc3 == 0)
			return 0;
		return 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($affilid)
	///
	/// \param $affilid - affiliationid
	///
	/// \brief deletes a value from the database
	///
	/// \return 1 if successfully deleted value, 0 if error encountered
	///
	/////////////////////////////////////////////////////////////////////////////
	function deleteValue($affilid) {
		global $mysql_link_vcl;
		$query = "DELETE FROM winKMS "
		       . "WHERE affiliationid = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class AffilTheme
///
/// \brief extends AffilTextVariable to implement AffilTheme
///
////////////////////////////////////////////////////////////////////////////////
class AffilTheme extends AffilTextVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i("Site Theme");
		$this->desc = i("This controls the theme of the site displayed for each affiliation.");
		$this->errmsg = i("Invalid theme specified");
		$this->domidbase = "affiltheme";
		$this->jsname = "affiltheme";
		$this->addmsg = i("Theme setting added for %s");
		$this->updatemsg = i("Update successful");
		$this->delmsg = i("Theme setting for %s deleted");
		$this->getValidValues();
		$this->vartype = 'selectonly';
		$this->allowdelete = 1;
		$this->allowempty = 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getValidValues()
	///
	/// \brief builds an array of valid values into $this->constraints
	///
	/////////////////////////////////////////////////////////////////////////////
	function getValidValues() {
		$this->constraints = array();
		foreach(glob('themes/*') as $item) {
			if(! is_dir($item))
				continue;
			$tmp = explode('/', $item);
			$item = $tmp[1];
			$this->constraints[$item] = $item;
		}
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getValues()
	///
	/// \brief gets assigned values from database and sets in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function getValues() {
		$this->values = array();
		$query = "SELECT id, theme FROM affiliation ORDER BY name";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$this->values[$row['id']] = $row['theme'];
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValue($affilid, $value)
	///
	/// \param $affilid - affiliationid
	/// \param $value - value to be set for $affilid
	///
	/// \brief sets values in database
	///
	/// \return 1 if successfully set values, 0 if error encountered setting
	/// values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValue($affilid, $value) {
		global $mysql_link_vcl;
		$esc_value = mysql_real_escape_string($value);
		$query = "UPDATE affiliation "
		       . "SET theme = '$esc_value' "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($affilid)
	///
	/// \param $affilid - affiliationid
	///
	/// \brief deletes a value from the database
	///
	/// \return 1 if successfully deleted value, 0 if error encountered
	///
	/////////////////////////////////////////////////////////////////////////////
	function deleteValue($affilid) {
		global $mysql_link_vcl;
		$query = "UPDATE affiliation "
		       . "SET theme = NULL "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateValue($value)
	///
	/// \param $value - value to be validated
	///
	/// \brief validates a submitted value
	///
	/// \return 1 if $value is valid, 0 if $value is not valid
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateValue($value) {
		if(in_array($value, $this->constraints))
			return 1;
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class AffilShibOnly
///
/// \brief extends AffilTextVariable to implement AffilShibOnly
///
////////////////////////////////////////////////////////////////////////////////
class AffilShibOnly extends AffilTextVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		$this->constraints = array('False', 'True');
		parent::__construct();
		$this->name = i("LDAP Lookup for Shibboleth Authenticated Users");
		$this->desc = i("If an affiliation gets configured for Shibboleth authentication, this specifies that LDAP authentication has also been configured for that affiliation so that VCL can perform lookups for new users before they log in to VCL.");
		$this->errmsg = i("Invalid value submitted");
		$this->domidbase = "affilshibonly";
		$this->jsname = "affilshibonly";
		$this->addmsg = i("LDAP lookup setting added for %s");
		$this->updatemsg = i("Update successful");
		$this->delmsg = i("LDAP lookup setting for %s deleted");
		$this->vartype = 'selectonly';
		$this->allowdelete = 0;
		$this->allowempty = 1;
		unset_by_val(i('Global'), $this->affils);
		unset_by_val(i('Local'), $this->affils);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getValues()
	///
	/// \brief gets assigned values from database and sets in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function getValues() {
		$this->values = array();
		$query = "SELECT id, "
		       .        "shibonly "
		       . "FROM affiliation "
		       . "WHERE name NOT IN ('Global', 'Local') "
		       . "ORDER BY name";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$this->values[$row['id']] = (int)(! $row['shibonly']);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValue($affilid, $value)
	///
	/// \param $affilid - affiliationid
	/// \param $value - value to be set for $affilid
	///
	/// \brief sets values in database
	///
	/// \return 1 if successfully set values, 0 if error encountered setting
	/// values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValue($affilid, $value) {
		global $mysql_link_vcl;
		$value = (int)(! $value);
		$query = "UPDATE affiliation "
		       . "SET shibonly = $value "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($affilid)
	///
	/// \param $affilid - affiliationid
	///
	/// \brief deletes a value from the database
	///
	/// \return 1 if successfully deleted value, 0 if error encountered
	///
	/////////////////////////////////////////////////////////////////////////////
	function deleteValue($affilid) {
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateValue($value)
	///
	/// \param $value - value to be validated
	///
	/// \brief validates a submitted value
	///
	/// \return 1 if $value is valid, 0 if $value is not valid
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateValue($value) {
		if($value === 0 || $value == 1)
			return 1;
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class AffilShibName
///
/// \brief extends AffilTextVariable to implement AffilShibName
///
////////////////////////////////////////////////////////////////////////////////
class AffilShibName extends AffilTextVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i("Shibboleth Scope");
		$this->desc = i("This is the Shibboleth scope for an affiliation when Shibboleth authentication is enabled.");
		$this->errmsg = i("Invalid value submitted");
		$this->domidbase = "affilshibname";
		$this->jsname = "affilshibname";
		$this->addmsg = i("Shibboleth scope added for %s");
		$this->updatemsg = i("Update successful");
		$this->delmsg = i("Shibboleth scope for %s deleted");
		$this->vartype = 'text';
		$this->constraints = '^([-A-Za-z0-9]{1,63})(\.[A-Za-z0-9-_]+)*(\.?[A-Za-z0-9])$$';
		unset_by_val(i('Global'), $this->affils);
		unset_by_val(i('Local'), $this->affils);
		$this->allowempty = 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getValues()
	///
	/// \brief gets assigned values from database and sets in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function getValues() {
		$this->values = array();
		$query = "SELECT id, "
		       .        "shibname "
		       . "FROM affiliation "
		       . "WHERE name NOT IN ('Global', 'Local') "
		       . "ORDER BY name";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$this->values[$row['id']] = $row['shibname'];
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValue($affilid, $value)
	///
	/// \param $affilid - affiliationid
	/// \param $value - value to be set for $affilid
	///
	/// \brief sets values in database
	///
	/// \return 1 if successfully set values, 0 if error encountered setting
	/// values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValue($affilid, $value) {
		global $mysql_link_vcl;
		if($value === NULL)
			$newval = 'NULL';
		else {
			$esc_value = mysql_real_escape_string($value);
			$newval = "'$esc_value'";
		}
		$query = "UPDATE affiliation "
		       . "SET shibname = $newval "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($affilid)
	///
	/// \param $affilid - affiliationid
	///
	/// \brief deletes a value from the database
	///
	/// \return 1 if successfully deleted value, 0 if error encountered
	///
	/////////////////////////////////////////////////////////////////////////////
	function deleteValue($affilid) {
		global $mysql_link_vcl;
		$query = "UPDATE affiliation "
		       . "SET shibname = NULL "
		       . "WHERE id = $affilid";
		doQuery($query);
		$rc = mysql_affected_rows($mysql_link_vcl);
		if($rc == 1)
			return 1;
		return 0;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class GlobalSingleVariable
///
/// \brief base class for global single value variables
///
////////////////////////////////////////////////////////////////////////////////
class GlobalSingleVariable {
	var $name;
	var $key;
	var $label;
	var $desc;
	var $domidbase;
	var $basecdata;
	var $jsname;
	var $defaultval;
	var $updatemsg;
	var $type;

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		$this->basecdata = array('obj' => $this);
		$this->updatemsg = i("New value saved");
		$this->label = $this->name;
		$type = 'text';
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getHTML()
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for setting numeric variables
	///
	////////////////////////////////////////////////////////////////////////////////
	function getHTML() {
		global $user;
		$val = getVariable($this->key, $this->defaultval);
		$h  = "<div class=\"configwidget\" style=\"width: 100%;\">\n";
		$h .= "<h3>{$this->name}</h3>\n";
		$h .= "<div class=\"siteconfigdesc\">\n";
		$h .= $this->desc;
		$h .= "<br><br></div>\n";
		switch($this->type) {
			case 'numeric':
				$extra = array('smallDelta' => 1, 'largeDelta' => 10);
				$h .= labeledFormItem($this->domidbase, $this->label, 'spinner', "{min:{$this->minval}, max:{$this->maxval}}", 1, $val, '', '', $extra);
				break;
			case 'boolean':
				$extra = array();
				if($val == 1)
					$extra = array('checked' => 'checked');
				$h .= labeledFormItem($this->domidbase, $this->label, 'check', '', 1, 1, '', '', $extra);
				break;
			case 'textarea':
				$h .= labeledFormItem($this->domidbase, $this->label, 'textarea', '', 1, $val, '', '', '', '120px');
				break;
			default:
				$h .= labeledFormItem($this->domidbase, $this->label, 'text', '', 1, $val);
				break;
		}
		$h .= "<div id=\"{$this->domidbase}msg\"></div>\n";
		$h .= dijitButton("{$this->domidbase}btn", i('Submit Changes'), "{$this->jsname}.saveSettings();", 1);
		$cdata = $this->basecdata;
		$cont = addContinuationsEntry('AJupdateAllSettings', $cdata);
		$h .= "<input type=\"hidden\" id=\"{$this->domidbase}cont\" value=\"$cont\">\n";
		$h .= "</div>\n";
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJupdateAllSettings()
	///
	/// \brief updates all values for implemented type of timevariable
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJupdateAllSettings() {
		if(! checkUserHasPerm('Site Configuration (global)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => i('You do not have access to modify the submitted settings.'));
			sendJSON($arr);
			return;
		}
		switch($this->type) {
			case 'numeric':
				$newval = processInputVar('newval', ARG_NUMERIC); 
				if($newval < $this->minval || $newval > $this->maxval) {
					$arr = array('status' => 'failed',
					             'msgid' => "{$this->domidbase}msg",
					             'btn' => "{$this->domidbase}btn",
					             'errmsg' => i("Invalid value submitted"));
					sendJSON($arr);
					return;
				}
				break;
			case 'boolean':
				$newval = processInputVar('newval', ARG_NUMERIC); 
				if($newval !== '0' && $newval !== '1') {
					$arr = array('status' => 'failed',
					             'msgid' => "{$this->domidbase}msg",
					             'btn' => "{$this->domidbase}btn",
					             'errmsg' => i("Invalid value submitted"));
					sendJSON($arr);
					return;
				}
				break;
			case 'text':
				# TODO
				$newval = processInputVar('newval', ARG_STRING); 
				$arr = array('status' => 'failed',
				             'msgid' => "{$this->domidbase}msg",
				             'btn' => "{$this->domidbase}btn",
				             'errmsg' => i("unsupported type"));
				sendJSON($arr);
				return;
			case 'textarea':
				$newval = processInputVar('newval', ARG_STRING); 
				if(! $this->validateValue($newval)) {
					$arr = array('status' => 'failed',
					             'msgid' => "{$this->domidbase}msg",
					             'btn' => "{$this->domidbase}btn",
					             'errmsg' => i("Invalid value submitted"));
					if(isset($this->invalidvaluemsg))
						$arr['errmsg'] = $this->invalidvaluemsg;
					sendJSON($arr);
					return;
				}
				break;
			default:
				$arr = array('status' => 'failed',
				             'msgid' => "{$this->domidbase}msg",
				             'btn' => "{$this->domidbase}btn",
				             'errmsg' => i("Invalid value submitted"));
				sendJSON($arr);
				return;
		}
		setVariable($this->key, $newval, 'none');
		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'btn' => "{$this->domidbase}btn",
		             'msg' => $this->updatemsg);
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateValue($val)
	///
	/// \brief validates that a new value is okay; should be implemented in 
	/// inheriting class
	///
	////////////////////////////////////////////////////////////////////////////////
	function validateValue($val) {
		return 1;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class userPasswordLength
///
/// \brief extends GlobalSingleVariable class to implement userPasswordLength
///
////////////////////////////////////////////////////////////////////////////////
class userPasswordLength extends GlobalSingleVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i('User Reservation Password Length');
		$this->key = 'user_password_length';
		$this->label = i("Password Length");
		$this->desc = i("For reservations not using federated authentication, VCL generates random user passwords. This specifies how many characters should be in the password.");
		$this->domidbase = 'userpasswordlength';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'userPasswordLength';
		$this->defaultval = 6;
		$this->minval = 6;
		$this->maxval = 40;
		$this->type = 'numeric';
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class userPasswordSpecialChar
///
/// \brief extends GlobalSingleVariable class to implement
/// userPasswordSpecialChar
///
////////////////////////////////////////////////////////////////////////////////
class userPasswordSpecialChar extends GlobalSingleVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i('User Reservation Password Special Characters');
		$this->key = 'user_password_spchar';
		$this->label = i("Include Special Characters");
		$this->desc = i("For reservations not using federated authentication, VCL generates random user passwords. This specifies if characters other than letters and numbers should be included in the passwords.");
		$this->domidbase = 'userpasswordspchar';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'userPasswordSpecialChar';
		$this->defaultval = 0;
		$this->type = 'boolean';
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class NATportRange
///
/// \brief extends GlobalSingleVariable class to implement NATportRange
///
////////////////////////////////////////////////////////////////////////////////
class NATportRange extends GlobalSingleVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = i('NAT Port Ranges');
		$this->key = 'natport_ranges';
		$this->label = i("NAT Port Ranges");
		$this->desc = i("Port ranges available for use on NAT servers. Type of port (TCP/UDP) is not specified. List ranges one per line (ex: 10000-20000).");
		$this->domidbase = 'natportrange';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'natPortRange';
		$this->defaultval = '10000-60000';
		$this->type = 'textarea';
		$this->invalidvaluemsg = i("Invalid value submitted. Must be numeric ranges of ports of the form 10000-20000, one per line.");
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateValue($val)
	///
	/// \brief validates that a new value is okay
	///
	////////////////////////////////////////////////////////////////////////////////
	function validateValue($val) {
		$vals = explode("\n", $val);
		foreach($vals as $testval) {
			if(! preg_match('/^(\d+)-(\d+)$/', $testval, $matches))
				return 0;
			if($matches[1] >= $matches[2])
				return 0;
		}
		return 1;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class GlobalMultiVariable
///
/// \brief base class for global single value variables
///
////////////////////////////////////////////////////////////////////////////////
class GlobalMultiVariable {
	var $name;
	var $units; #array('id' => array('name' => 'razr-mgt', ...))
	var $values; #array('id' => '<IP>:/foo/bar,/mydata')
	var $desc;
	var $domidbase;
	var $basecdata;
	var $jsname;
	var $defaultval;
	var $updatemsg;
	var $type;
	var $width;
	var $addCBextra;
	var $deleteCBextra;
	var $saveCBextra;
	var $allowduplicates;

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		$this->basecdata = array('obj' => $this);
		$this->updatemsg = _("Values updated");
		$this->type = 'text';
		$this->addCBextra = 'addNewMultiValCBextra';
		$this->deleteCBextra = 'deleteMultiValCBextra';
		$this->saveCBextra = 'saveCBextra';
		$this->allowduplicates = 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValues
	///
	/// \brief sets values in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValues() {
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getHTML()
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for setting variables
	///
	////////////////////////////////////////////////////////////////////////////////
	function getHTML() {
		global $user;
		$h  = "<div class=\"configwidget\" style=\"width: 100%;\">\n";
		$h .= "<h3>{$this->name}</h3>\n";
		$h .= "<div class=\"GMV{$this->domidbase}wrapper\">\n"; # wrapper
		$h .= "<div class=\"siteconfigdesc\">\n";
		$h .= $this->desc;
		$h .= "<br><br></div>\n";
		$this->savekeys = array();
		$this->setkeys = array();

		$h .= $this->existingValuesHTML();

		$unitskeys = array_keys($this->units);
		$remainingkeys = array_diff($unitskeys, $this->setkeys);
		$remaining = array();
		foreach($remainingkeys as $key) {
			$remaining[$key] = $this->units[$key]['name'];
		}
		if(count($remaining) == 0)
			$h .= "<span id=\"{$this->domidbase}multivalnewspan\" class=\"hidden\">\n";
		else
			$h .= "<span id=\"{$this->domidbase}multivalnewspan\">\n";

		$h .= $this->newValueHTML($remaining);

		$h .= "</span>\n"; # multivalnewspan

		$h .= "<div id=\"{$this->domidbase}msg\"></div>\n";
		$h .= dijitButton("{$this->domidbase}btn", _('Submit Changes'), "{$this->jsname}.saveSettings();", 1);
		$cdata = $this->basecdata;
		$cont = addContinuationsEntry('AJupdateAllSettings', $cdata);
		$h .= "<input type=\"hidden\" id=\"{$this->domidbase}cont\" value=\"$cont\">\n";
		$this->savekeys = implode(',', $this->savekeys);
		$h .= "<input type=\"hidden\" id=\"{$this->domidbase}savekeys\" value=\"{$this->savekeys}\">\n";
		$cont = addContinuationsEntry('AJdeleteMultiSetting', $cdata);
		$h .= "<input type=\"hidden\" id=\"delete{$this->domidbase}cont\" value=\"$cont\">\n";
		$h .= "</div>\n"; # wrapper
		$h .= "</div>\n";
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn existingValuesHTML()
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for existing value forms
	///
	////////////////////////////////////////////////////////////////////////////////
	function existingValuesHTML() {
		$h = "<span id=\"{$this->domidbase}multivalspan\">\n";
		foreach($this->values as $key => $val) {
			if(! isset($this->units[$key]))
				continue;
			$this->savekeys[] = "{$this->domidbase}|$key";
			$this->setkeys[] = $key;
			$h .= "<span id=\"{$this->domidbase}|{$key}wrapspan\">\n";
			switch($this->type) {
				/*case 'numeric':
					$extra = array('smallDelta' => 1, 'largeDelta' => 10);
					$h .= labeledFormItem($this->domidbase, $this->label, 'spinner', "{min:{$this->minval}, max:{$this->maxval}}", 1, $val, '', '', $extra);
					break;
				case 'boolean':
					$extra = array();
					if($val == 1)
						$extra = array('checked' => 'checked');
					$h .= labeledFormItem($this->domidbase, $this->label, 'check', '', 1, 1, '', '', $extra);
					break;*/
				case 'textarea':
					$h .= labeledFormItem("{$this->domidbase}|$key", $this->units[$key]['name'], 'textarea', '', 1, $val, '', '', '', $this->width, '', 0);
					break;
				default:
					$h .= labeledFormItem("{$this->domidbase}|$key", $this->units[$key]['name'], 'text', "{$this->constraint}", 1, $val, "{$this->invalidmsg}", '', '', $this->width, '', 0);
					break;
			}
			$h .= dijitButton("{$this->domidbase}|{$key}delbtn", _('Delete'), "{$this->jsname}.deleteMultiVal('$key', '{$this->domidbase}');") . "<br></span>\n";
		}
		$h .= "</span>\n"; # multivalspan
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn newValueHTML($remaining)
	///
	/// \param $remaining - array of remaining units for which values can be added
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for new value form
	///
	////////////////////////////////////////////////////////////////////////////////
	function newValueHTML($remaining) {
		$h = selectInputHTML('', $remaining, "{$this->domidbase}newmultivalid", "dojoType=\"dijit.form.Select\"");

		switch($this->type) {
			case 'textarea':
				$h .= "<textarea ";
				$h .=   "dojoType=\"dijit.form.Textarea\" ";
				$h .=   "style=\"width: {$this->width}; text-align: left;\" ";
				$h .=   "id=\"{$this->domidbase}newmultival\">";
				$h .= "</textarea>\n";
				break;
			default:
				$h .= "<input type=\"text\" ";
				$h .=   "dojoType=\"dijit.form.ValidationTextBox\" ";
				$h .=   "regExp=\"{$this->constraint}\" ";
				$h .=   "invalidMessage=\"{$this->invalidmsg}\" ";
				$h .=   "style=\"width: {$this->width}\" ";
				$h .=   "id=\"{$this->domidbase}newmultival\">";
				break;
		}
		$h .= dijitButton("{$this->domidbase}addbtn", _('Add'), "{$this->jsname}.addNewMultiVal();");
		$cont = addContinuationsEntry('AJaddConfigMultiVal', $this->basecdata);
		$h .= "<input type=\"hidden\" id=\"{$this->domidbase}addcont\" value=\"$cont\">\n";
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddConfigMultiVal()
	///
	/// \brief adds a multi value setting
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJaddConfigMultiVal() {
		if(! checkUserHasPerm('Site Configuration (global)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => _('You do not have access to modify the submitted settings.'));
			sendJSON($arr);
			return;
		}
		$newkey = processInputVar('multivalid', ARG_NUMERIC);
		$newval = processInputVar('multival', ARG_STRING);
		if(! array_key_exists($newkey, $this->units)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'btn' => "{$this->domidbase}addbtn",
			             'errmsg' => _("Invalid item selected for new value"));
			sendJSON($arr);
			return;
		}
		if(! $this->validateValue($newval)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'btn' => "{$this->domidbase}addbtn",
			             'errmsg' => _("Invalid value submitted"));
			if(isset($this->invalidvaluemsg))
				$arr['errmsg'] = $this->invalidvaluemsg;
			sendJSON($arr);
			return;
		}
		setVariable("{$this->domidbase}|$newkey", $newval, 'none');
		$this->setValues();
		$addcont = addContinuationsEntry('AJaddConfigMultiVal', $this->basecdata);
		$delcont = addContinuationsEntry('AJdeleteMultiSetting', $this->basecdata);
		$savecont = addContinuationsEntry('AJupdateAllSettings', $this->basecdata);
		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'addid' => "{$this->domidbase}|$newkey",
		             'addname' => $this->units[$newkey]['name'],
		             'addval' => $newval,
		             'delkey' => $newkey,
		             'extrafunc' => "{$this->jsname}.{$this->addCBextra}",
		             'addcont' => $addcont,
		             'delcont' => $delcont,
		             'savecont' => $savecont,
		             'msg' => $this->addmsg,
		             'regexp' => $this->constraint,
		             'invalidmsg' => str_replace('&amp;', '&', $this->invalidmsg));
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJdeleteMultiSetting()
	///
	/// \brief processes deletion of a multi value setting
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJdeleteMultiSetting() {
		if(! checkUserHasPerm('Site Configuration (global)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => _('You do not have access to modify the submitted settings.'));
			sendJSON($arr);
			return;
		}
		$key = processInputVar('key', ARG_NUMERIC);
		if(! array_key_exists($key, $this->values)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'btn' => "{$this->domidbase}|{$key}delbtn",
			             'errmsg' => _("Invalid item submitted for deletion"));
			sendJSON($arr);
			return;
		}
		if(! $this->deleteValue($key)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'btn' => "{$this->domidbase}|{$key}delbtn",
			             'errmsg' => _("Invalid item submitted for deletion"));
			if(isset($this->invalidvaluemsg))
				$arr['errmsg'] = $this->invalidvaluemsg;
			sendJSON($arr);
			return;
		}
		$this->setValues();
		$savecont = addContinuationsEntry('AJupdateAllSettings', $this->basecdata);
		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'delid' => "{$this->domidbase}|$key",
		             'extrafunc' => "{$this->jsname}.{$this->deleteCBextra}",
		             'addid' => "$key",
		             'addname' => $this->units[$key]['name'],
		             'msg' => $this->delmsg,
		             'savecont' => $savecont);
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($key)
	///
	/// \param $key - key of value to delete from $this->values
	///
	/// \return 0 on fail, 1 on success
	///
	/// \brief deletes a multi value setting
	///
	////////////////////////////////////////////////////////////////////////////////
	function deleteValue($key) {
		deleteVariable("{$this->domidbase}|$key");
		return 1;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJupdateAllSettings()
	///
	/// \brief processes updating values for submitted variables
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJupdateAllSettings() {
		if(! checkUserHasPerm('Site Configuration (global)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => _('You do not have access to modify the submitted settings.'));
			sendJSON($arr);
			return;
		}
		$origvals = $this->values;
		$newvals = array();
		foreach($origvals as $key => $val) {
			switch($this->type) {
				/*case 'numeric':
					$newval = processInputVar('newval', ARG_NUMERIC); 
					if($newval < $this->minval || $newval > $this->maxval) {
						$arr = array('status' => 'failed',
						             'msgid' => "{$this->domidbase}msg",
						             'btn' => "{$this->domidbase}btn",
						             'errmsg' => _("Invalid value submitted"));
						sendJSON($arr);
						return;
					}
					break;
				case 'boolean':
					$newval = processInputVar('newval', ARG_NUMERIC); 
					if($newval !== '0' && $newval !== '1') {
						$arr = array('status' => 'failed',
						             'msgid' => "{$this->domidbase}msg",
						             'btn' => "{$this->domidbase}btn",
						             'errmsg' => _("Invalid value submitted"));
						sendJSON($arr);
						return;
					}
					break;*/
				case 'text':
				case 'textarea':
					$newval = processInputVar("{$this->domidbase}|$key", ARG_STRING); 
					if(! $this->validateValue($newval, $key)) {
						$arr = array('status' => 'failed',
						             'msgid' => "{$this->domidbase}msg",
						             'btn' => "{$this->domidbase}btn",
						             'errmsg' => _("Invalid value submitted for ") . $this->units[$key]['name']);
						if(isset($this->invalidvaluemsg))
							$arr['errmsg'] = $this->invalidvaluemsg;
						sendJSON($arr);
						return;
					}
					if(! $this->allowduplicates) {
						foreach($newvals as $testval) {
							if($newval == $testval) {
								$arr = array('status' => 'failed',
								             'msgid' => "{$this->domidbase}msg",
								             'btn' => "{$this->domidbase}btn",
								             'errmsg' => _("Duplicate new values submitted"));
								sendJSON($arr);
								return;
							}
						}
					}
					if($newval != $origvals[$key])
						$newvals["{$this->jsname}|$key"] = $newval;
					break;
				/*case 'textarea':
					$newval = processInputVar('newval', ARG_STRING); 
					if(! $this->validateValue($newval)) {
						$arr = array('status' => 'failed',
						             'msgid' => "{$this->domidbase}msg",
						             'btn' => "{$this->domidbase}btn",
						             'errmsg' => _("Invalid value submitted"));
						if(isset($this->invalidvaluemsg))
							$arr['errmsg'] = $this->invalidvaluemsg;
						sendJSON($arr);
						return;
					}
					break;*/
				default:
					$arr = array('status' => 'failed',
					             'msgid' => "{$this->domidbase}msg",
					             'btn' => "{$this->domidbase}btn",
					             'errmsg' => _("Invalid value submitted"));
					sendJSON($arr);
					return;
			}
		}
		if(empty($newvals)) {
			$arr = array('status' => 'noaction',
			             'msgid' => "{$this->domidbase}msg",
			             'btn' => "{$this->domidbase}btn");
			sendJSON($arr);
			return;
		}
		foreach($newvals as $key => $val)
			$this->updateValue($key, $val);
		$this->setValues();
		$savecont = addContinuationsEntry('AJupdateAllSettings', $this->basecdata);
		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'btn' => "{$this->domidbase}btn",
		             'msg' => $this->updatemsg,
		             'extrafunc' => "{$this->jsname}.{$this->saveCBextra}",
		             'savecont' => $savecont);
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn updateValue($key, $val)
	///
	/// \param $key - key of value to update from $this->values
	/// \param $val - new value for $key
	///
	/// \brief updates value for $key
	///
	////////////////////////////////////////////////////////////////////////////////
	function updateValue($key, $val) {
		setVariable($key, $val, 'none');
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateValue($val, $key)
	///
	/// \param $val - value to be validated
	/// \param $key - (optional, default=NULL) corresponding key if existing value
	///
	/// \return 0 if invalid, 1 if valid
	///
	/// \brief validates that a new value is okay
	///
	////////////////////////////////////////////////////////////////////////////////
	function validateValue($val, $key=NULL) {
		return 1;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class NFSmounts
///
/// \brief extends GlobalMultiVariable class to implement NFSmounts
///
////////////////////////////////////////////////////////////////////////////////
class NFSmounts extends GlobalMultiVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('NFS Mounts');
		$this->units = getManagementNodes();
		foreach($this->units as $key => $val) {
			$this->units[$key]['name'] = $val['hostname'];
		}
		$vals = getVariablesRegex('^nfsmount\\\|[0-9]+$');
		$this->values = array();
		foreach($vals as $key => $val) {
			$tmp = explode('|', $key);
			$id = $tmp[1];
			$this->values[$id] = $val;
		}
		$formbase = ' &lt;hostname or IP&gt;:&lt;export path&gt;,&lt;mount path&gt;';
		$this->desc = _("NFS Mounts are NFS exports that are to be mounted within each reservation deployed by a given management node.<br>Values must be like") . $formbase;
		$this->domidbase = 'nfsmount';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'nfsmount';
		$this->defaultval = '';
		$this->type = 'textarea';
		$this->addmsg = "NFS mount sucessfully added";
		$this->delmsg = "NFS mount sucessfully deleted";
		$this->constraint = '((((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))|([A-Za-z0-9\-\.]+)):\/[a-zA-Z0-9\.@#%\(\)-_=\+\/]+,\/[a-zA-Z0-9\.@#%\(\)-_=\+\/]+';
		$this->invalidmsg = _("Invalid value - must be in the form") . str_replace('&', '&amp;', $formbase);
		$this->invalidvaluemsg = html_entity_decode($this->invalidmsg);
		$this->width = '400px';
		$this->allowduplicates = 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValues
	///
	/// \brief sets values in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValues() {
		$vals = getVariablesRegex('^nfsmount\\\|[0-9]+$');
		$this->values = array();
		foreach($vals as $key => $val) {
			$tmp = explode('|', $key);
			$id = $tmp[1];
			$this->values[$id] = $val;
		}
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateValue($val, $key)
	///
	/// \param $val - value to be validated
	/// \param $key - (unused)
	///
	/// \return 0 if invalid, 1 if valid
	///
	/// \brief validates that a new value is okay
	///
	////////////////////////////////////////////////////////////////////////////////
	function validateValue($val, $key=NULL) {
		$vals = explode(";", $val);
		foreach($vals as $testval) {
			$tmp = explode(':', $testval);
			if(count($tmp) != 2)
				return 0;
			$iphost = $tmp[0];
			if(preg_match('/^[0-9\.]+$/', $iphost) && ! validateIPv4addr($iphost))
				return 0;
			elseif(! preg_match('/^[A-Za-z0-9\-\.]+$/', $iphost))
				return 0;
			$tmp = explode(',', $tmp[1]);
			if(count($tmp) != 2)
				return 0;
			$exportpath = $tmp[0];
			$mntpath = $tmp[1];
			if(! preg_match(':^/[a-zA-Z0-9\.@#%\(\)-_=\+/]+:', $exportpath))
				return 0;
			if(! preg_match(':^/[a-zA-Z0-9\.@#%\(\)-_=\+/]+:', $mntpath))
				return 0;
		}
		return 1;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class Affiliations
///
/// \brief extends GlobalMultiVariable class to implement Affiliations
///
////////////////////////////////////////////////////////////////////////////////
class Affiliations extends GlobalMultiVariable {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->name = _('Affiliations');
		$affils = getAffiliations();
		$this->units = array();
		$this->values = array();
		foreach($affils as $key => $val) {
			if($val == 'Global')
				continue;
			$this->units[$key]['name'] = $val;
			$this->values[$key] = $val;
		}
		$formbase = ' be a max of 40 characters and contain A-Z a-z 0-9 - _';
		$this->desc = _("Affiliation names can") . $formbase;
		$this->domidbase = 'affiliation';
		$this->basecdata['obj'] = $this;
		$this->jsname = 'affiliation';
		$this->defaultval = '';
		$this->type = 'text';
		$this->addmsg = i("Affiliation sucessfully added; reloading page");
		$this->delmsg = i("Affiliation sucessfully deleted; reloading page");
		$this->updatemsg = i("Values updated; reloading page");
		$this->constraint = '[-A-Za-z0-9_]{1,40}';
		$this->invalidmsg = i("Invalid value - must") . str_replace('&', '&amp;', $formbase);
		$this->invalidvaluemsg = html_entity_decode($this->invalidmsg);
		$this->width = '200px';
		$this->addCBextra = 'pagerefresh';
		$this->deleteCBextra = 'deleteMultiValCBextra';
		$this->saveCBextra = 'pagerefresh';
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn setValues
	///
	/// \brief sets values in $this->values
	///
	/////////////////////////////////////////////////////////////////////////////
	function setValues() {
		$affils = getAffiliations();
		$this->values = array();
		foreach($affils as $key => $val) {
			if($val == 'Global')
				continue;
			$this->values[$key] = $val;
		}
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn existingValuesHTML()
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for existing value forms
	///
	////////////////////////////////////////////////////////////////////////////////
	function existingValuesHTML() {
		$h = "<span id=\"{$this->domidbase}multivalspan\">\n";
		foreach($this->values as $key => $val) {
			if(! isset($this->units[$key]))
				continue;
			$this->savekeys[] = "{$this->domidbase}|$key";
			$h .= "<span id=\"{$this->domidbase}|{$key}wrapspan\">\n";
			$h .= "<input type=\"text\" ";
			$h .=        "dojoType=\"dijit.form.ValidationTextBox\" ";
			$h .=        "required=\"1\" ";
			$h .=        "regExp=\"{$this->constraint}\" ";
			$h .=        "invalidMessage=\"{$this->invalidmsg}\" ";
			$h .=        "style=\"width: {$this->width}\"; ";
			$h .=        "value=\"$val\" ";
			$h .=        "id=\"{$this->domidbase}|$key\">\n";
			$h .= dijitButton("{$this->domidbase}|{$key}delbtn", _('Delete'),
			                  "{$this->jsname}.deleteMultiVal('$key', '{$this->domidbase}');");
			$h .= "<br></span>\n";
		}
		$h .= "<div id=\"siteconfigconfirmoverlay\">\n";
		$h .= "</div>\n"; # overlay

		$h .= "<div id=\"affiliationconfirmbox\">\n";
		$h .= "<div id=\"affilconfbox-table\">\n";
		$h .= "<div id=\"affilconfbox-cell\">\n";
		$h .= "Delete <span id=\"affilconfirmname\"></span>?<br><br>\n";
		$h .= dijitButton('', 'Delete', 'affiliation.deleteMultiValSubmit();');
		$h .= dijitButton('', 'Cancel', 'affiliation.hideDelete();');
		$h .= "</div>\n"; # affilconfbox-cell
		$h .= "</div>\n"; # affilconfbox-table
		$h .= "</div>\n";
		$h .= "<input type=\"hidden\" id=\"delaffilkey\">\n";

		$h .= "</span>\n"; # multivalspan
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn newValueHTML($remaining)
	///
	/// \param $remaining - array of remaining units for which values can be added
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for new value form
	///
	////////////////////////////////////////////////////////////////////////////////
	function newValueHTML($remaining) {
		$h  = "<input type=\"text\" ";
		$h .=        "dojoType=\"dijit.form.ValidationTextBox\" ";
		$h .=        "required=\"1\" ";
		$h .=        "regExp=\"{$this->constraint}\" ";
		$h .=        "invalidMessage=\"{$this->invalidmsg}\" ";
		$h .=        "style=\"width: {$this->width}\"; ";
		$h .=        "id=\"{$this->domidbase}newmultival\">\n";
		$h .= dijitButton("{$this->domidbase}addbtn", _('Add'), "{$this->jsname}.addNewMultiVal();");
		$cont = addContinuationsEntry('AJaddConfigMultiVal', $this->basecdata);
		$h .= "<input type=\"hidden\" id=\"{$this->domidbase}addcont\" value=\"$cont\">\n";
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddConfigMultiVal()
	///
	/// \brief adds a multi value setting
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJaddConfigMultiVal() {
		if(! checkUserHasPerm('Site Configuration (global)')) {
			$arr = array('status' => 'noaccess',
			             'msg' => _('You do not have access to modify the submitted settings.'));
			sendJSON($arr);
			return;
		}
		$newval = processInputVar('multival', ARG_STRING);
		if(! $this->validateValue($newval)) {
			$arr = array('status' => 'failed',
			             'msgid' => "{$this->domidbase}msg",
			             'btn' => "{$this->domidbase}addbtn",
			             'errmsg' => _("Invalid value submitted"));
			if(isset($this->invalidvaluemsg))
				$arr['errmsg'] = $this->invalidvaluemsg;
			sendJSON($arr);
			return;
		}
		$_newval = mysql_real_escape_string($newval);
		$query = "INSERT INTO affiliation (name) VALUES ('$_newval')";
		doQuery($query);
		$arr = array('status' => 'success',
		             'msgid' => "{$this->domidbase}msg",
		             'extrafunc' => "{$this->jsname}.pagerefresh",
		             'msg' => $this->addmsg);
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn deleteValue($key)
	///
	/// \param $key - key of value to delete from $this->values
	///
	/// \brief deletes a multi value setting
	///
	////////////////////////////////////////////////////////////////////////////////
	function deleteValue($key) {
		$used = 0;
		$tables = array('loginlog', 'user', 'usergroup');
		foreach($tables as $table) {
			$query = "SELECT affiliationid FROM $table WHERE affiliationid = $key LIMIT 1";
			$qh = doQuery($query);
			if(mysql_num_rows($qh)) {
				$used = 1;
				break;
			}
		}
		if($used) {
			$this->invalidvaluemsg = "{$this->units[$key]['name']} has been used. Affiliations that have been used cannot be deleted.";
			return 0;
		}
		$affilname = getAffiliationName($key);
		$query = "DELETE FROM statgraphcache WHERE affiliationid = $key";
		doQuery($query);
		$query = "DELETE FROM winKMS WHERE affiliationid = $key";
		doQuery($query);
		$query = "DELETE FROM winProductKey WHERE affiliationid = $key";
		doQuery($query);
		$query = "DELETE FROM affiliation WHERE id = $key";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^usermessage\\\\|[^\\\\|]+\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^ignore_connections_gte\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^acknowledgetimeout\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^initialconnecttimeout\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^reconnecttimeout\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^general_inuse_check\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^server_inuse_check\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^cluster_inuse_check\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^general_end_notice_first\\\\|$affilname$'";
		doQuery($query);
		$query = "DELETE FROM variable WHERE name REGEXP '^general_end_notice_second\\\\|$affilname$'";
		doQuery($query);
		return 1;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn updateValue($key, $val)
	///
	/// \param $key - key of value to update from $this->values
	/// \param $val - new value for $key
	///
	/// \brief updates value for $key
	///
	////////////////////////////////////////////////////////////////////////////////
	function updateValue($key, $val) {
		$tmp = explode('|', $key);
		$key = $tmp[1];
		$_val = mysql_real_escape_string($val);
		$query = "UPDATE affiliation SET name = '$_val' WHERE id = $key";
		doQuery($query);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateValue($val, $key)
	///
	/// \param $val - value to be validated
	/// \param $key - (optional, default=NULL) corresponding key if existing value
	///
	/// \return 0 if invalid, 1 if valid
	///
	/// \brief validates that a new value is okay
	///
	////////////////////////////////////////////////////////////////////////////////
	function validateValue($val, $key=NULL) {
		if(! preg_match("/{$this->constraint}/", $val))
			return 0;
		$testid = getAffiliationID($val);
		if(is_null($key)) {
			if(! is_null($testid)) {
				$this->invalidvaluemsg = i('Affiliation already exists');
				return 0;
			}
		}
		else {
			if(! is_null($testid) && $testid != $key) {
				$this->invalidvaluemsg = i('Conflicting Affiliation submitted');
				return 0;
			}
		}
		return 1;
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class Messages
///
/// \brief class to handle configuration of Messages
///
////////////////////////////////////////////////////////////////////////////////
class Messages {
	var $basecdata;
	var $name;
	var $desc;
	var $affils;
	var $units;
	var $basekeys;
	var $globalopts;

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct($globalopts) {
		$this->basecdata['obj'] = $this;
		$this->name = _('Messages');
		$this->desc = sprintf(_("This section allows for configuration of messages that are sent to users and administrators about things such as reservations and image management. Every message has a default. Additionally, separate messages can be configured for each affiliation. Most of the messages will have parts that are in square brackets. These parts will have data substituted for them before the message is sent. A list of what can be used in squeare brackets can be found at the <a href=\"%s\">Apache VCL web site</a>. Some messages also have a short form that may be sent such as in the form of a popup within a reservation when the reservation is about to end."), "http://vcl.apache.org/docs/message_substitutions.html");
		$this->affils = getAffiliations();
		$this->units = array();
		$this->basekeys = array();
		$this->globalopts = $globalopts;

		if($this->globalopts)
			$data = getVariablesRegex('^(usermessage\\\||adminmessage\\\|)');
		else
			$data = getVariablesRegex('^usermessage\\\|');
		foreach($data as $key => $item) {
			# 0 - category, 1 - type, 2 - affil
			$keyparts = explode('|', $key);
			$k = "{$keyparts[0]}|{$keyparts[1]}";
			$kname = "{$keyparts[0]} -&gt; {$keyparts[1]}";
			$this->basekeys[$k] = $kname;

			if($keyparts[0] == 'adminmessage')
				$keyparts[2] = 'Global';
			$this->units[$k][$keyparts[2]] = $item;
		}
		uasort($this->basekeys, "sortKeepIndex");
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getHTML()
	///
	/// \return string of HTML
	///
	/// \brief generates HTML for setting variables
	///
	////////////////////////////////////////////////////////////////////////////////
	function getHTML() {
		global $user;
		$h  = "<div class=\"configwidget\" style=\"width: 100%;\">\n";
		$h .= "<h3>{$this->name}</h3>\n";
		$h .= "<div style=\"text-align: left; padding: 4px;\">\n";
		$h .= $this->desc;
		$h .= "<br><br></div>\n";

		$h .= "<script type=\"application/json\" id=\"messagesdata\">\n";
		$h .= json_encode($this->units); 
		$h .= "</script>\n";

		$h .= "<strong>Select Message</strong>:";
		$extra = "dojoType=\"dijit.form.FilteringSelect\" "
		       . "style=\"width: 300px\" "
		       . "onChange=\"messages.setContents(1);\"";
		$h .= selectInputHTML('', $this->basekeys, "messagesselid", $extra);
		$h .= "<br>\n";
		if($this->globalopts) {
			$h .= "<strong>Select Affiliation</strong>:";
			$h .= selectInputHTML('', $this->affils, "messagesaffilid", $extra);
		}
		else {
			$opts = array($user['affiliationid'] => $this->affils[$user['affiliationid']]);
			$h .= "<strong>Affiliation: {$this->affils[$user['affiliationid']]}</strong>";
			$h .= "<div class=\"hidden\">\n";
			$h .= selectInputHTML('', $opts, "messagesaffilid", $extra);
			$h .= "</div>\n";
		}

		$h .= "<div dojoType=dojox.layout.FloatingPane\n";
		$h .= "      id=\"invalidmsgfieldspane\"\n";
		$h .= "      resizable=\"true\"\n";
		$h .= "      closable=\"true\"\n";
		$h .= "      title=\"" . i("Invalid Message Fields") . "\"\n";
		$h .= "      style=\"width: 400px; ";
		$h .=               "height: 200px; ";
		$h .=               "visibility: hidden; ";
		$h .=               "text-align: left; ";
		$h .=               "border: solid 2px red;\"\n";
		$h .= ">\n";
		$h .= "<script type=\"dojo/method\" event=\"minimize\">\n";
		$h .= "  this.hide();\n";
		$h .= "</script>\n";
		$h .= "<script type=\"dojo/method\" event=\"close\">\n";
		$h .= "  this.hide();\n";
		$h .= "  return false;\n";
		$h .= "</script>\n";
		$h .= "<div style=\"padding: 4px;\">\n";
		$h .= _("The following messages have invalid items included for substitution. Please correct the message contents and save them again for the backend to validate.") . "<br><br>\n";
		$h .= "   <div id=\"invalidmsgfieldcontent\"></div>\n";
		$h .= "</div>\n";
		$h .= "</div>\n";

		$h .= "<br>\n";
		$h .= "<div id=\"defaultmessagesdiv\" class=\"hidden highlightnotice\"><br><strong>";
		$h .= i('There is no message set specifically for this affiliation. The default message is being used and is displayed below.');
		$h .= "</strong><br><br></div>\n";
		$h .= labeledFormItem("messagessubject", 'Subject', 'text', '', 1, '', '', '', '', '80ch');
		$h .= labeledFormItem("messagesbody", 'Message', 'textarea', '', 1, '', '', '', '', '80ch');
		$h .= labeledFormItem("messagesshortmsg", 'Short Message', 'textarea', '', 1, '', '', '', '', '80ch');

		$h .= "<span id=\"messagesaffil\" style=\"font-weight: bold;\"";
		if(! $this->globalopts)
			$h .= " class=\"hidden\"";
		$h .= ">Default message for any affiliation</span><br>\n";

		$h .= dijitButton("messagessavebtn", _('Save Message'), "messages.savemsg();");
		$h .= dijitButton("messagesdelbtn", _('Delete Message and Use Default'), "messages.confirmdeletemsg();");

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"deleteMessageDlg\"\n";
		$h .= "      title=\"" . i("Delete Message") . "\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true\n";
		$h .= "      style=\"width: 315px;\">\n";
		$h .= "Are you sure you want to delete the selected message for this affiliaton ";
		$h .= "and use the default message instead?<br><br>\n";
		$h .= "<span style=\"font-weight: bold\">Affiliation:</span> <span id=\"deleteMsgAffil\"></span><br>\n";
		$h .= "<span style=\"font-weight: bold\">Category:</span> <span id=\"deleteMsgCategory\"></span><br>\n";
		$h .= "<span style=\"font-weight: bold\">Type:</span> <span id=\"deleteMsgType\"></span><br><br>\n";
		$h .= "   <div align=\"center\">\n";
		$h .= "   <button id=\"deleteMessageDelBtn\" dojoType=\"dijit.form.Button\">\n";
		$h .= "    " . i("Delete Message") . "\n";
		$h .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "       messages.deletemsg();\n";
		$h .= "     </script>\n";
		$h .= "   </button>\n";
		$h .= "   <button dojoType=\"dijit.form.Button\">\n";
		$h .= "     " . i("Cancel") . "\n";
		$h .= "     <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "       dijit.byId('deleteMessageDlg').hide();\n";
		$h .= "     </script>\n";
		$h .= "   </button>\n";
		$h .= "   </div>\n";
		$h .= "</div>\n";

		$cdata = $this->basecdata;
		$h .= "<div id=\"messagesmsg\"></div>\n";
		$cont = addContinuationsEntry('AJsaveMessages', $cdata);
		$h .= "<input type=\"hidden\" id=\"savemessagescont\" value=\"$cont\">\n";
		$cont = addContinuationsEntry('AJdeleteMessages', $cdata);
		$h .= "<input type=\"hidden\" id=\"deletemessagescont\" value=\"$cont\">\n";

		$cont = addContinuationsEntry('AJvalidateMessagesPoll', $cdata);
		$h .= "<input type=\"hidden\" id=\"validatemessagespollcont\" value=\"$cont\">\n";

		$h .= "</div>\n";

		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJdeleteMessages()
	///
	/// \brief deletes an affiliation specific message
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJdeleteMessages() {
		global $user;
		$key = processInputVar('key', ARG_STRING);
		$affilid = processInputVar('affilid', ARG_NUMERIC);
		$keyparts = explode('|', $key);
		if(! array_key_exists($key, $this->basekeys) ||
		   ! array_key_exists($affilid, $this->affils) ||
		   count($keyparts) != 2 ||
		   $this->affils[$affilid] == 'Global' ||
		   ($this->globalopts == 0 && $affilid != $user['affiliationid'])) {
			$arr = array('status' => 'failed',
			             'msgid' => "messagesmsg",
			             'btn' => "messagesdelbtn",
			             'errmsg' => _("Invalid item submitted for deletion"));
			sendJSON($arr);
			return;
		}
		$affil = $this->affils[$affilid];
		$delkey = "$key|$affil";
		deleteVariable($delkey);
		$arr = array('status' => 'success',
		             'msgid' => "messagesmsg",
		             'key' => $key,
		             'affil' => $affil,
		             'extrafunc' => "messages.deleteMessagesCBextra",
		             'btn' => "messagesdelbtn",
		             'msg' => sprintf(_('Message type %s for affiliation %s successfully deleted'), $keyparts[1], $affil));
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsaveMessages()
	///
	/// \brief saves an affiliation specific message
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJsaveMessages() {
		global $user;
		$key = processInputVar('key', ARG_STRING);
		$affilid = processInputVar('affilid', ARG_NUMERIC);
		$subject = processInputVar('subject', ARG_STRING);
		$body = processInputVar('body', ARG_STRING);
		$shortmsg = processInputVar('shortmsg', ARG_STRING);

		$keyparts = explode('|', $key);

		if(! array_key_exists($key, $this->basekeys) ||
		   ! array_key_exists($affilid, $this->affils) ||
			count($keyparts) != 2 ||
		   ($this->globalopts == 0 && $keyparts[0] == 'adminmessage') ||
		   ($this->globalopts == 0 && $affilid != $user['affiliationid'])) {
			$arr = array('status' => 'failed',
			             'msgid' => "messagesmsg",
			             'btn' => "messagessavebtn",
			             'errmsg' => _("Invalid item submitted to save"));
			sendJSON($arr);
			return;
		}
		if(preg_match('/^\s*$/', $body)) {
			$arr = array('status' => 'failed',
			             'msgid' => "messagesmsg",
			             'btn' => "messagessavebtn",
			             'errmsg' => _("Message cannot be empty"));
			sendJSON($arr);
			return;
		}
		$affil = $this->affils[$affilid];
		$savekey = $key;
		if($keyparts[0] == 'usermessage')
			$savekey = "{$keyparts[0]}|{$keyparts[1]}|$affil";
		$data = getVariable($savekey);
		if(is_null($data))
			$data = array();
		$changed = 0;
		if(! array_key_exists('subject', $data) || $data['subject'] != $subject) {
			$data['subject'] = $subject;
			$changed = 1;
		}
		if(! array_key_exists('message', $data) || $data['message'] != $body) {
			$data['message'] = $body;
			$changed = 1;
		}
		if($keyparts[0] == 'usermessage' &&
			(! array_key_exists('usermessage', $data) ||
			$data['short_message'] != $shortmsg)) {
			$data['short_message'] = $shortmsg;
			$changed = 1;
		}
		if($changed) {
			if(preg_match('/\[.*\]/', $body) ||
			   preg_match('/\[.*\]/', $shortmsg))
				setVariable('usermessage_needs_validating', 1, 'none');
			unset($data['invalidfields']);
			setVariable($savekey, $data, 'yaml');
			$usermsg = _('Message successfully saved');
		}
		else
			$usermsg = _('No changes to submitted message. Nothing saved.');
		$arr = array('status' => 'success',
		             'msgid' => "messagesmsg",
		             'key' => $key,
		             'affil' => $affil,
		             'subject' => $subject,
		             'body' => $body,
		             'shortmsg' => $shortmsg,
		             'extrafunc' => "messages.saveMessagesCBextra",
		             'btn' => "messagessavebtn",
		             'msg' => $usermsg);
		sendJSON($arr);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJvalidateMessagesPoll()
	///
	/// \brief checks for errors found by vcld in any recently updated messages
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJvalidateMessagesPoll() {
		$query = "SELECT name, "
		       .        "value "
		       . "FROM variable "
		       . "WHERE setby != 'webcode' AND "
		       .       "setby IS NOT NULL AND "
		       .       "value LIKE '%invalidfields%'";
		$qh = doQuery($query);
		$invalids = array();
		while($row = mysql_fetch_assoc($qh)) {
			$data = Spyc::YAMLLoad($row['value']);
			if(array_key_exists('invalidfields', $data)) {
				$invalids[$row['name']] = $data['invalidfields'];
			}
		}
		if(count($invalids)) {
			sendJSON(array('status' => 'invalid', 'values' => $invalids));
			return;
		}
		sendJSON(array('status' => 'valid'));
	}
}

?>
