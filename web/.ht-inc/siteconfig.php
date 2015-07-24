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
	$h = '';
	#$h .= "<div id=\"globalopts\" dojoType=\"dijit.layout.ContentPane\" title=\"Global Options\">\n";

	# -------- full width -----------
	$h .= timeSourceHTML($globalopts);
	# ------ end full width ---------

	$h .= "<table summary=\"\" id=siteconfig>\n";
	$h .= "<tr>\n";

	# -------- left column ---------
	$h .= "<td style=\"vertical-align: top;\">\n";
	$obj = new connectedUserCheck();
	$h .= $obj->getHTML($globalopts);
	$obj = new acknowledge();
	$h .= $obj->getHTML($globalopts);
	$obj = new initialconnecttimeout();
	$h .= $obj->getHTML($globalopts);
	$obj = new reconnecttimeout();
	$h .= $obj->getHTML($globalopts);
	if($globalopts) {
		$obj = new userPasswordLength();
		$h .= $obj->getHTML();
		$obj = new userPasswordSpecialChar();
		$h .= $obj->getHTML();
	}
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
	if($globalopts) {
		$obj = new NATportRange();
		$h .= $obj->getHTML();
	}
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
	$h .= "<h3>" . i("Time Source") . "</h3>\n";
	$h .= "<span class=\"siteconfigdesc\">\n";
	$h .= i("Set the default list of time servers to be used on installed nodes. These can be overridden for each management node under the settings for a given management node. Separate hostnames using a comma (,).") . "<br><br>\n";
	$h .= "</span>\n";
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
		$this->name = i('Re-connect To Reservation Timeout');
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
		$h .= "<span class=\"siteconfigdesc\">\n";
		$h .= $this->desc;
		$h .= "<br><br></span>\n";
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
		$this->key = 'nat_port_range';
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

?>
