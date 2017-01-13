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
/// \class Schedule
///
/// \brief extends Resource class to add things specific to resources of the
/// schedule type
///
////////////////////////////////////////////////////////////////////////////////
class Schedule extends Resource {
	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief calls parent constructor; initializes things for Schedule class
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		parent::__construct();
		$this->restype = 'schedule';
		$this->restypename = 'Schedule';
		$this->namefield = 'name';
		$this->basecdata['obj'] = $this;
		$this->deletable = 1;
		$this->deletetoggled = 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getData($args)
	///
	/// \param $args - unused in this class
	///
	/// \return array of data as returned from getSchedules
	///
	/// \brief wrapper for calling getSchedules
	///
	/////////////////////////////////////////////////////////////////////////////
	function getData($args) {
		return getSchedules();
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addEditDialogHTML()
	///
	/// \param $add - unused for this class
	///
	/// \brief generates HTML for dialog used to edit resource
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
		$h .= "      style=\"width: 70%;\"\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"addeditdlgcontent\">\n";
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
		#$h .= labeledFormItem('owner', i('Owner'), 'text', '{$user['unityid']}@{$user['affiliation']}',
		#                      1, '', i('Unknown user'), 'checkOwner', 'onKeyPress', 'setOwnerChecking');
		$cont = addContinuationsEntry('AJvalidateUserid');
		$h .= "<input type=\"hidden\" id=\"valuseridcont\" value=\"$cont\">\n";

		# table of times
		$h .= "<br>";
		$h .= "<span style=\"text-align: center;\"><h3>Schedule Times</h3></span>\n";
		$h .= "The start and end day/times are based on a week's time period with ";
		$h .= "the start/end point being 'Sunday 12:00&nbsp;am'. i.e. The earliest ";
		$h .= "start day/time is 'Sunday 12:00&nbsp;am' and the latest end day/";
		$h .= "time is 'Sunday 12:00&nbsp;am'<br><br>\n";
		$h .= "Start:";
		$h .= selectInputAutoDijitHTML('startday', $days, 'startday');
		$h .= "<input type=\"text\" id=\"starttime\" dojoType=\"dijit.form.TimeTextBox\" ";
		$h .= "required=\"true\" value=\"T00:00:00\"/>\n";
		$h .= "<small>(" . date('T') . ")</small>\n";
		$h .= "&nbsp;|&nbsp;&nbsp;";
		$h .= "End:";
		$h .= selectInputAutoDijitHTML('endday', $days, 'endday');
		$h .= "<input type=\"text\" id=\"endtime\" dojoType=\"dijit.form.TimeTextBox\" ";
		$h .= "required=\"true\" value=\"T00:00:00\" />\n";
		$h .= "<small>(" . date('T') . ")</small>\n";
		$h .= dijitButton('addTimeBtn', "Add", "addTime();");
		$h .= "</div>\n"; # text-align: center
		$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"scheduleStore\" ";
		$h .= "data=\"scheduleTimeData\"></div>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"scheduleGrid\" sortInfo=1 ";
		$h .= "store=\"scheduleStore\" style=\"width: 520px; height: 165px;\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"startday\" width=\"94px\" formatter=\"formatDay\">Start Day</th>\n";
		$h .= "<th field=\"startday\" width=\"94px\" formatter=\"formatTime\">Start Time</th>\n";
		$h .= "<th field=\"endday\" width=\"94px\" formatter=\"formatDay\">End Day</th>\n";
		$h .= "<th field=\"endday\" width=\"94px\" formatter=\"formatTime\">End Time</th>\n";
		$h .= "<th field=\"remove\" width=\"80px\">Remove</th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</div>\n"; # addeditdlgcontent

		$h .= "<div id=\"addeditdlgerrmsg\" class=\"nperrormsg\"></div>\n";
		$h .= "<div id=\"editdlgbtns\" align=\"center\">\n";
		$h .= dijitButton('addeditbtn', "Confirm", "saveResource();");
		$h .= dijitButton('', _("Cancel"), "addEditDlgHide();");
		$h .= "</div>\n"; # editdlgbtns
		$h .= "</div>\n"; # addeditdlg

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"groupingnote\"\n";
		$h .= "      title=\"Schedule Grouping\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "Each schedule should be a member of a schedule<br>resource group. The following dialog will allow you<br>to add the new schedule to a group.<br><br>\n";
		$h .= "<div align=\"center\">\n";
		$h .= dijitButton('', "Close", "dijit.byId('groupingnote').hide();");
		$h .= "</div>\n"; # btn div
		$h .= "</div>\n"; # groupingnote

		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"groupdlg\"\n";
		$h .= "      title=\"Schedule Grouping\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"groupdlgcontent\"></div>\n";
		$h .= "<div align=\"center\">\n";
		$script  = "    dijit.byId('groupdlg').hide();\n";
		$script .= "    checkFirstAdd();\n";
		$h .= dijitButton('', "Close", $script);
		$h .= "</div>\n"; # btn div
		$h .= "</div>\n"; # groupdlg

		$h .= "<input type=\"hidden\" id=\"timezonevalue\" value=\"" . date('T') . "\">\n";

		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkResourceInUse($rscid)
	///
	/// \param $rscid - id of schedule
	///
	/// \return empty string if not being used; string of where resource is
	/// being used if being used
	///
	/// \brief checks to see if a schedule is being used
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkResourceInUse($rscid) {
		$msg = '';

		$query = "SELECT hostname "
		       . "FROM computer "
		       . "WHERE scheduleid = $rscid AND "
		       .       "deleted = 0";
		$qh = doQuery($query);
		$comps = array();
		while($row = mysql_fetch_assoc($qh))
			$comps[] = $row['hostname'];
		if(count($comps))
			$msg = "This schedule cannot be deleted because the following <strong>computers</strong> have it selected as their schedule:<br><br>\n" . implode("<br>\n", $comps);

		return $msg;
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
				               'errormsg' => 'Error encountered while trying to create new schedule.<br>Please contact an admin for assistance.'));
				return;
			}
		}
		else {
			$ownerid = getUserlistID($data['owner']);
			$query = "UPDATE schedule "
			       . "SET name = '{$data['name']}', "
			       .     "ownerid = $ownerid "
			       . "WHERE id = {$data['rscid']}";
			doQuery($query);
		}

		if(! $add) {
			$query = "DELETE FROM scheduletimes WHERE scheduleid = {$data['rscid']}";
			doQuery($query, 101);
		}
		$qvals = array();
		foreach($data['times'] as $time)
			$qvals[] = "({$data['rscid']}, {$time['start']}, {$time['end']})";
		$allvals = implode(',', $qvals);
		$query = "INSERT INTO scheduletimes "
		       .        "(scheduleid, start, end) "
				 . "VALUES $allvals";
		doQuery($query, 101);

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("manageGroup"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("manageGroup"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);

		$tmp = $this->getData(array('includedeleted' => 0, 'rscid' => $data['rscid']));
		$data = $tmp[$data['rscid']];
		$arr = array('status' => 'success');
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
		$arr['data'] = $data;
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addResource($data)
	///
	/// \param $data - array of needed data for adding a new resource
	///
	/// \return id of new resource
	///
	/// \brief handles adding a new schedule and other associated data to the
	/// database
	///
	/////////////////////////////////////////////////////////////////////////////
	function addResource($data) {
		global $user;

		$ownerid = getUserlistID($data['owner']);
		$query = "INSERT INTO schedule "
		       .         "(name, "
		       .         "ownerid) "
		       . "VALUES ('{$data['name']}', "
		       .         "$ownerid)";
		doQuery($query);

		$rscid = dbLastInsertID();
		if($rscid == 0) {
			return 0;
		}

		$query = "INSERT INTO resource "
				 .        "(resourcetypeid, "
				 .        "subid) "
				 . "VALUES (15, "
				 .         "$rscid)";
		doQuery($query, 223);
	
		return $rscid;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn validateResourceData()
	///
	/// \return array with these fields:\n
	/// \b rscid - id of resource (from schedule table)\n
	/// \b name\n
	/// \b owner\n
	/// \b times - array of arrays, each having 2 keys: start and end, each in
	///    unix timestamp format\n
	/// \b error - 0 if submitted data validates; 1 if anything is invalid\n
	/// \b errormsg - if error = 1; string of error messages separated by html
	///    break tags
	///
	/// \brief validates form input from editing or adding a schedule
	///
	/////////////////////////////////////////////////////////////////////////////
	function validateResourceData() {
		global $user;

		$return = array('error' => 0);
		$errormsg = array();

		$return['rscid'] = getContinuationVar('rscid', 0);
		$return["name"] = processInputVar("name", ARG_STRING);
		$return["owner"] = processInputVar("owner", ARG_STRING, "{$user["unityid"]}@{$user['affiliation']}");
		$times = processInputVar('times', ARG_STRING);

		if(! preg_match("/^([A-Za-z0-9-!@#$%^&\*\(\)_=\+\[\]{}\\\|:;,\.\/\?~` ]){2,30}$/", $return['name'])) {
			$return['error'] = 1;
			$errormsg[] = "Name cannot contain single (') or double (&quot;) quotes, "
			            . "less than (&lt;), or greater than (&gt;) and can be from 2 to 30 "
			            . "characters long";
		}
		elseif($this->checkForScheduleName($return['name'], $return['rscid'])) {
			$return['error'] = 1;
			$errormsg[] = "A schedule already exists with this name.";
		}
		if(! validateUserid($return['owner'])) {
			$return['error'] = 1;
			$errormsg[] = "Submitted owner is not valid";
		}
		if(! preg_match('/^([0-9]+:[0-9]+,)*([0-9]+:[0-9]+){1}$/', $times)) {
			$return['error'] = 1;
			$errormsg[] = "Invalid time data submitted";
		}

		if(! $return['error']) {
			$times = explode(',', $times);
			$return['times'] = array();
			foreach($times as $pair) {
				list($start, $end) = explode(':', $pair);
				foreach($return['times'] as $check) {
					if($start < $check['end'] && $end > $check['start']) {
						$return['error'] = 1;
						$errormsg[] = "Two sets of times are overlapping - please correct and save again";
						break(2);
					}
				}
				$return['times'][] = array('start' => $start, 'end' => $end);
			}
		}

		if($return['error'])
			$return['errormsg'] = implode('<br>', $errormsg);

		return $return;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn toggleDeleteResourceExtra()
	///
	/// \return html
	///
	/// \brief generates additional HTML to be included at the end of the confirm
	/// toggle delete resource page
	///
	/////////////////////////////////////////////////////////////////////////////
	function toggleDeleteResourceExtra() {
		$rscid = processInputVar('rscid', ARG_NUMERIC);
		$data = $this->getData('');
		$h = '';
		if(count($data[$rscid]["times"])) {
			$h .= "<br><TABLE>\n";
			$h .= "  <TR>\n";
			$h .= "    <TH>Start</TH>\n";
			$h .= "    <TD>&nbsp;</TD>\n";
			$h .= "    <TH>End</TH>\n";
			$h .= "  <TR>\n";
			foreach($data[$rscid]["times"] as $time) {
				$h .= "  <TR>\n";
				$h .= "    <TD>" . $this->minToDaytime($time["start"]) . "</TD>\n";
				$h .= "    <TD>&nbsp;</TD>\n";
				$h .= "    <TD>" . $this->minToDaytime($time["end"]) . "</TD>\n";
				$h .= "  </TR>\n";
			}
			$h .= "</TABLE><br>\n";
		}
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn submitToggleDeleteResourceExtra($rscid, $deleted)
	///
	/// \param $rscid - id of a resource (from schedule table)
	/// \param $deleted - (optional, default=0) 1 if resource was previously
	/// deleted; 0 if not
	///
	/// \brief handles deleting associated entries from scheduletimes table
	///
	/////////////////////////////////////////////////////////////////////////////
	function submitToggleDeleteResourceExtra($rscid, $deleted=0) {
		$query = "DELETE FROM scheduletimes "
		       . "WHERE scheduleid = $rscid";
		doQuery($query);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkForScheduleName($name, $id)
	///
	/// \param $name - the name of a schedule
	/// \param $id - id of a schedule to ignore
	///
	/// \return 1 if $name is already in the schedule table, 0 if not
	///
	/// \brief checks for $name being in the schedule table except for $id
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkForScheduleName($name, $id) {
		$query = "SELECT id FROM schedule "
				 . "WHERE name = '$name'";
		
		if(! empty($id))
			$query .= " AND id != $id";
		$qh = doQuery($query, 101);
		if(mysql_num_rows($qh))
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn minToDaytime($min)
	///
	/// \param $min - minute of the week
	///
	/// \return day of week and time of day
	///
	/// \brief calculates day of week and time of day from $min and returns a
	/// nicely formatted string of "Weekday&nbsp;HH:MM am/pm"
	///
	/////////////////////////////////////////////////////////////////////////////
	function minToDaytime($min) {
		$days = array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
						  "Friday", "Saturday");
		$time = minuteToTime($min % 1440);
		if((int)($min / 1440) == 0) {
			$day = 0;
		}
		elseif((int)($min / 1440) == 1) {
			$day = 1;
		}
		elseif((int)($min / 1440) == 2) {
			$day = 2;
		}
		elseif((int)($min / 1440) == 3) {
			$day = 3;
		}
		elseif((int)($min / 1440) == 4) {
			$day = 4;
		}
		elseif((int)($min / 1440) == 5) {
			$day = 5;
		}
		elseif((int)($min / 1440) == 6) {
			$day = 6;
		}
		elseif((int)($min / 1440) > 6) {
			$day = 0;
		}
		return $days[$day] . "&nbsp;$time";
	}
}
?>
