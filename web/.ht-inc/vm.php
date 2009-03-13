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

/**
 * \file vm.php
 */

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editVMInfo()
///
/// \brief prints a page for editing VM Hosts and VM Host Profiles
///
////////////////////////////////////////////////////////////////////////////////
function editVMInfo() {
	global $viewmode;
	print "<h2>Manage Virtual Hosts</h2>\n";

	$profiles = getVMProfiles();
	if($viewmode == ADMIN_DEVELOPER) {
	print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	print "     style=\"width:650px;height:600px\">\n";

	print "<div id=\"vmhosts\" dojoType=\"dijit.layout.ContentPane\" title=\"VM Hosts\">\n";
	}

	print "<div dojoType=\"dijit.Dialog\"\n";
	print "     id=\"messages\">\n";
	print "<span id=messagestext></span>";
	print "<button id=\"messagesokbtn\"></button>\n";
	print "<button onclick=\"dijit.byId('messages').hide()\">Cancel</button>\n";
	print "</div>\n";

	$newmsg = "To create a new Virtual Host, change the state of a computer to<br>\n"
	        . "'vmhostinuse' under Manage Computers-&gt;Computer Utilities.<br><br>\n";
	$vmhosts = getVMHostData();
	$resources = getUserResources(array("computerAdmin"), array("administer"));
	foreach($vmhosts as $key => $value) {
		if(! array_key_exists($value['computerid'], $resources['computer']))
			unset($vmhosts[$key]);
	}
	if(empty($vmhosts)) {
		print "You do not have access to manage any existing virtual hosts.<br><br>\n";
		print $newmsg;
		return;
	}
	print $newmsg;
	print "Select a Virtual Host:<br>\n";
	printSelectInput("vmhostid", $vmhosts, -1, 0, 0, 'vmhostid');
	$cont = addContinuationsEntry('vmhostdata');
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchCompGrpsButton\">\n";
	print "	Configure Host\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getVMHostData('$cont');\n";
	print "	</script>\n";
	print "</button><br><br>\n";
	print "<div id=vmhostdata class=hidden>\n";
	print "<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <th align=right>VM limit:</th>\n";
	print "    <td>\n";
	$cont = addContinuationsEntry('updateVMlimit');
	print "      <input dojoType=\"dijit.form.NumberSpinner\"\n";
	print "             constraints=\"{min:1,max:" . MAXVMLIMIT . "}\"\n";
	print "             maxlength=\"3\"\n";
	print "             id=\"vmlimit\"\n";
	print "             onChange=\"updateVMlimit('$cont')\">\n";
	print "    </td>\n";
	print "  </tr>\n";
	#$cont = addContinuationsEntry('changeVMprofile');
	print "  <tr>\n";
	print "    <th align=right>VM Profile:</th>\n";
	print "    <td>\n";
	#printSelectInput("vmprofileid", $profiles, -1, 0, 0, 'vmprofileid', "onchange=changeVMprofile('$cont')");
	print "      <div dojoType=\"dijit.TitlePane\" id=vmprofile></div>\n";
	print "    </td>\n";
	print "  </tr>\n";
	/*if(! empty($data['vmkernalnic'])) {
		print "  <tr>\n";
		print "    <th align=right>VM Kernal NIC:</th>\n";
		print "    <td>{$data['vmkernalnic']}</td>\n";
		print "  </tr>\n";
	}*/
	print "</table><br><br>\n";

	print "<div id=movevms class=hidden>\n";
	print "The followig VM(s) will removed from this host at the listed ";
	print "time(s):<br>\n";
	print "<select name=movevmssel multiple id=movevmssel size=3>\n";
	print "</select><br>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"cancelBtn\">\n";
	print "	<div>Cancel Removing of Selected VMs</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJcancelVMmove');
	print "		cancelVMmove('$cont');\n";
	print "	</script>\n";
	print "</button>\n";
	print "<br><br></div>\n";

	print "<table summary=\"\"><tbody><tr>\n";

	# select for vms on host
	print "<td valign=top>\n";
	print "VMs assigned to host:<br>\n";
	print "<select name=currvms multiple id=currvms size=15 onChange=showVMstate()>\n";
	print "</select><br>\n";
	print "State of selected vm:<br>\n";
	print "<span id=vmstate></span>\n";
	print "</td>\n";
	# transfer buttons
	print "<td style=\"vertical-align: middle;\">\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"addBtn1\">\n";
	print "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJvmToHost');
	print "		vmToHost('$cont');\n";
	print "	</script>\n";
	print "</button>\n";
	print "<br>\n";
	print "<br>\n";
	print "<br>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"remBtn1\">\n";
	print "	<div style=\"width: 50px;\">Remove</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJvmFromHost');
	print "		vmFromHost('$cont');\n";
	print "	</script>\n";
	print "</button>\n";
	print "</td>\n";
	# select for unassigned vms
	print "<td valign=top>\n";
	print "Unassigned VMs:<br>\n";
	print "<select name=freevms multiple id=freevms size=20>\n";
	print "</select>\n";
	print "</td>\n";
	print "</tr><tbody/></table>\n";
	print "</div><br><br>\n";

	/*print "<div dojoType=\"dijit.Dialog\"\n";
	print "     id=\"profileDlg\"\n";
	print "     title=\"Change Profile\">\n";
	print "You have selected to change the VM Profile for this host.<br>\n";
	print "Doing this will attempt to move any future reservations on the<br>\n";
	print "host's VMs to other VMs and will submit a reload reservation for this<br>\n";
	print "host after any active reservations on its VMs.<br><br>\n";
	print "Are you sure you want to do this?<br><br>\n";
	print "<button onclick=\"submitChangeProfile()\">Update VM Profile</button>\n";
	print "<button onclick=\"dijit.byId('profileDlg').hide()\">Cancel</button>\n";
	print "<input type=hidden id=changevmcont>\n";
	print "</div>\n";*/
	print "</div>\n";

	if($viewmode != ADMIN_DEVELOPER)
		return;
	print "<div id=\"vmprofiles\" dojoType=\"dijit.layout.ContentPane\" title=\"VM Host Profiles\">\n";
	print "<br>Select a profile to configure:<br>\n";
	printSelectInput("profileid", $profiles, -1, 0, 0, 'profileid');
	$cont = addContinuationsEntry('AJprofiledata');
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchProfilesBtn\">\n";
	print "	Configure Profile\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getVMprofileData('$cont');\n";
	print "	</script>\n";
	print "</button>";
	$cont = addContinuationsEntry('AJnewProfile');
	print "<button dojoType=\"dijit.form.Button\" id=\"newProfilesBtn\">\n";
	print "	New Profile...\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		newProfile('$cont');\n";
	print "	</script>\n";
	print "</button>";
	print "<br><br>\n";

	print "<div id=vmprofiledata class=hidden>\n";
	$cont = addContinuationsEntry('AJdelProfile');
	print "<button dojoType=\"dijit.form.Button\" id=\"delProfilesBtn\">\n";
	print "	Delete this Profile\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		delProfile('$cont');\n";
	print "	</script>\n";
	print "</button><br><br>";
	$cont = addContinuationsEntry('AJupdateVMprofileItem');
	print "(Click a value to edit it)<br>\n";
	print "<input type=hidden id=pcont value=\"$cont\">\n";
	print "<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <th align=right>Name:</th>\n";
	print "    <td><span id=pname dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pname', 'name');\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Type:</th>\n";
	print "    <td><select id=ptype dojoType=\"dijit.form.FilteringSelect\" searchAttr=\"name\" onchange=\"updateProfile('ptype', 'vmtypeid');\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Image:</th>\n";
	print "    <td><span id=pimage dojoType=\"dijit.form.FilteringSelect\" searchAttr=\"name\" onchange=\"updateProfile('pimage', 'imageid');\" style=\"width: 420px\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>NAS Share:</th>\n";
	print "    <td><span id=pnasshare dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pnasshare', 'nasshare');\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Data Store Path:</th>\n";
	print "    <td><span id=pdspath dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pdspath', 'datastorepath');\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>VM Path:</th>\n";
	print "    <td><span id=pvmpath dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pvmpath', 'vmpath');\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Virtual Switch 0:</th>\n";
	print "    <td><span id=pvs0 dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pvs0', 'virtualswitch0');\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Virtual Switch 1:</th>\n";
	print "    <td><span id=pvs1 dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pvs1', 'virtualswitch1');\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>VM Disk:</th>\n";
	print "    <td><select id=pvmdisk dojoType=\"dijit.form.FilteringSelect\" searchAttr=\"name\" onchange=\"updateProfile('pvmdisk', 'vmdisk');\"></span></td>\n";
	print "  </tr>\n";
	print "</table>\n";
	print "</div>\n";
	print "</div>\n";

	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn vmhostdata()
///
/// \brief prints json formatted data with information about the submitted VM
/// host
///
////////////////////////////////////////////////////////////////////////////////
function vmhostdata() {
	$vmhostid = processInputVar('vmhostid', ARG_NUMERIC);
	$ret = '';
	$data = getVMHostData($vmhostid);

	$resources = getUserResources(array("computerAdmin"), array("administer"));
	if(! array_key_exists($data[$vmhostid]['computerid'], $resources['computer'])) {
		$arr = array('failed' => 'noaccess');
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	# get vms assigned to vmhost
	$query = "SELECT c.id, "
	       .        "c.hostname, "
	       .        "s.name AS state, "
	       .        "c.vmhostid "
	       . "FROM computer c, "
	       .      "state s "
	       . "WHERE c.type = 'virtualmachine' AND "
	       .       "c.stateid = s.id AND "
	       .       "(vmhostid IS NULL OR "
	       .       "vmhostid NOT IN (SELECT id FROM vmhost) OR "
	       .       "c.vmhostid = $vmhostid) "
	       . "ORDER BY c.hostname";
	$qh = doQuery($query, 101);
	$ids = array();
	$allvms = array();
	$currvms = array();
	$freevms = array();
	while($row = mysql_fetch_assoc($qh)) {
		if($row['vmhostid'] == $vmhostid) {
			$ids[$row['id']] = $row['hostname'];
			$currvms[$row['id']] = array('id' => $row['id'],
			                             'name' => $row['hostname'],
			                             'state' => $row['state']);
			$allvms[] = array('id' => $row['id'],
			                  'name' => $row['hostname'],
			                  'inout' => 1);
		}
		else {
			$freevms[] = array('id' => $row['id'],
			                   'name' => $row['hostname']);
			$allvms[] = array('id' => $row['id'],
			                  'name' => $row['hostname'],
			                  'inout' => 0);
		}
	}
	uasort($allvms, "sortKeepIndex");
	uasort($currvms, "sortKeepIndex");
	uasort($freevms, "sortKeepIndex");

	$keys = array_keys($ids);
	$movevms = array();
	if(! empty($keys)) {
		$keys = join(',', $keys);
		$query = "SELECT rq.id, "
		       .        "DATE_FORMAT(rq.start, '%l:%i%p %c/%e/%y') AS start, "
		       .        "rs.computerid "
		       . "FROM request rq, "
		       .      "reservation rs "
		       . "WHERE rs.requestid = rq.id AND "
		       .       "rs.computerid IN ($keys) AND "
		       .       "(rq.stateid = 18 OR "
		       .       "rq.laststateid = 18) AND "
		       .       "rq.start > NOW()";
		$qh = doQuery($query, 101);
		while($row = mysql_fetch_assoc($qh)) {
			$movevms[] = array('id' => $row['id'],
			                 'time' => strtolower($row['start']),
			                 'hostname' => $currvms[$row['computerid']]['name']);
			unset($currvms[$row['computerid']]);
		}
		uasort($movevms, "sortKeepIndex");
		$movevms = array_merge($movevms);
	}

	$allvms = array_merge($allvms);
	$currvms = array_merge($currvms);
	$freevms = array_merge($freevms);
	$cont = addContinuationsEntry('AJchangeVMprofile', array(), 3600, 1, 0);
	$arr = array('vmlimit' => $data[$vmhostid]['vmlimit'],
	             'profile' => $data[$vmhostid]['vmprofiledata'],
	             'continuation' => $cont,
	             'allvms' => $allvms,
	             'currvms' => $currvms,
	             'freevms' => $freevms,
	             'movevms' => $movevms);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getVMHostData($id)
///
/// \param $id - (optional) a host id about which to get data
///
/// \return an array where each key is a vmhost id and each element is an array
/// with these values:\n
/// \b computerid - id of computer\n
/// \b name - hostname of computer\n
/// \b hostname - hostname of computer\n
/// \b vmlimit - maximum number of vm's host can handle\n
/// \b vmprofileid - id of vm profile\n
/// \b vmkernalnic - name of kernel nic\n
/// \b vmprofiledata - array of data about the vm's profile as returned from
/// getVMProfiles
///
/// \brief builds a array of information about the vmhosts
///
////////////////////////////////////////////////////////////////////////////////
function getVMHostData($id='') {
	$profiles = getVMProfiles();
	$query = "SELECT vh.id, "
	       .        "vh.computerid, " 
	       .        "c.hostname AS name, "
	       .        "c.hostname, "
	       .        "vh.vmlimit, "
	       .        "vh.vmprofileid, "
	       #.        "vp.profilename, "
	       .        "vh.vmkernalnic "
	       . "FROM vmhost vh, " 
	       .      "vmprofile vp, "
	       .      "computer c "
	       . "WHERE vh.vmprofileid = vp.id AND "
	       .       "vh.computerid = c.id";
	if(! empty($id))
		$query .= " AND vh.id = $id";
	$qh = doQuery($query, 101);
	$ret = array();
	while($row = mysql_fetch_assoc($qh)) {
		$ret[$row['id']] = $row;
		$ret[$row['id']]['vmprofiledata'] = $profiles[$row['vmprofileid']];
	}
	uasort($ret, 'sortKeepIndex');
	return $ret;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateVMlimit()
///
/// \brief updates the vmlimit for the submitted vmhostid
///
////////////////////////////////////////////////////////////////////////////////
function updateVMlimit() {
	global $mysql_link_vcl;
	$vmhostid = processInputVar('vmhostid', ARG_NUMERIC);

	$data = getVMHostData($vmhostid);
	$resources = getUserResources(array("computerAdmin"), array("administer"));
	if(! array_key_exists($data[$vmhostid]['computerid'], $resources['computer'])) {
		print 'You do not have access to manage this host.';
		return;
	}

	$newlimit = processInputVar('newlimit', ARG_NUMERIC);
	if($newlimit < 0 || $newlimit > MAXVMLIMIT) {
		print "ERROR: newlimit out of range";
		return;
	}
	$query = "UPDATE vmhost SET vmlimit = $newlimit WHERE id = $vmhostid";
	$qh = doQuery($query, 101);
	if(mysql_affected_rows($mysql_link_vcl))
		print "SUCCESS";
	else
		print "ERROR: failed to update vmlimit";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJvmToHost()
///
/// \brief adds vm's to a vmhost; prints json data with:\n
/// \b vms - array of vm's successfully added\n
/// \b fails - array of vm's that couldn't be added for some reason\n
/// \b addrem - 1
///
////////////////////////////////////////////////////////////////////////////////
function AJvmToHost() {
	$hostid = processInputVar('hostid', ARG_NUMERIC);
	
	$hostdata = getVMHostData($hostid);
	$resources = getUserResources(array("computerAdmin"), array("administer"));
	if(! array_key_exists($hostdata[$hostid]['computerid'], $resources['computer'])) {
		$arr = array('failed' => 'nohostaccess');
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	# find out how many vms are currently on the host
	$query = "SELECT COUNT(id) "
	       . "FROM computer "
	       . "WHERE vmhostid = $hostid";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_row($qh);
	if($row[0] >= $hostdata[$hostid]['vmlimit']) {
		$arr = array('failed' => 'vmlimit');
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$adds = array();
	$fails = array();

	$vmlistids = processInputVar('listids', ARG_STRING);
	$vmids = explode(',', $vmlistids);

	# get data about submitted vms to add
	$query = "SELECT id, hostname, vmhostid "
	       . "FROM computer "
	       . "WHERE id in ($vmlistids)";
	$qh = doQuery($query, 101);
	$vmdata = array();
	while($row = mysql_fetch_assoc($qh)) {
		if(! array_key_exists($row['id'], $resources['computer'])) {
			$fails[] = array('id' => $row['id'], 'name' => $row['hostname'], 'reason' => 'noaccess');
			unset_by_val($row['id'], $vmids);
			continue;
		}
		$vmdata[$row['id']] = $row;
	}

	# build list of vm hosts
	$query = "SELECT id FROM vmhost";
	$vmhosts = array();
	$qh = doQuery($query, 101);
	while($row = mysql_fetch_assoc($qh))
		$vmhosts[$row['id']] = 1;

	# check to see if there any submitted vms have a hostid of an existing vm host
	foreach($vmids as $compid) {
		if(! array_key_exists($vmdata[$compid]['vmhostid'], $vmhosts)) {
			$query = "UPDATE computer "
			       . "SET vmhostid = $hostid, "
			       .     "stateid = 2 "
			       . "WHERE id = $compid";
			doQuery($query, 101);
			$adds[] = array('id' => $compid, 'name' => $vmdata[$compid]['hostname'], 'state' => 'available');
		}
		else
			$fails[] = array('id' => $compid, 'name' => $vmdata[$compid]['hostname'], 'reason' => 'otherhost');
	}
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	$arr = array('vms' => $adds, 'fails' => $fails, 'addrem' => 1);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJvmFromHost()
///
/// \brief removes vm's from a host by adding reservations for them in the
/// tomaintenance state; prints json data with:\n
/// \b vms - vm's that successfully had reservastions created to move them off\n
/// \b checks - vm's that have reservations on them that can be removed in the
/// future by adding a future tomaintenance reservation\n
/// \b addrem - 0\n
/// \b cont - a new continuation for submitting the future tomaintenance
/// reservations
///
////////////////////////////////////////////////////////////////////////////////
function AJvmFromHost() {
	$hostid = processInputVar('hostid', ARG_NUMERIC);
	
	$hostdata = getVMHostData($hostid);
	$resources = getUserResources(array("computerAdmin"), array("administer"));
	if(! array_key_exists($hostdata[$hostid]['computerid'], $resources['computer'])) {
		$arr = array('failed' => 'nohostaccess');
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$fails = array();
	$vmlistids = processInputVar('listids', ARG_STRING);
	$vmids = explode(',', $vmlistids);
	$rems = array();
	$checks = array();
	$vclreloadid = getUserlistID('vclreload@Local');
	$start = getReloadStartTime();
	$end = $start + SECINMONTH;
	$start = unixToDatetime($start);
	$end = unixToDatetime($end);
	foreach($vmids as $compid) {
		$compdata = getComputers(0, 0, $compid);
		if(! array_key_exists($compid, $resources['computer'])) {
			$fails[] = array('id' => $compid,
			                 'name' => $compdata[$compid]['hostname'],
			                 'reason' => 'noaccess');
			continue;
		}
		# try to remove reservations off of computer
		if(($compdata[$compid]['state'] == 'available' ||
			$compdata[$compid]['state'] == 'maintenance' ||
			$compdata[$compid]['state'] == 'failed') &&
			moveReservationsOffComputer($compid)) {
			// if no reservations on computer, submit reload 
			#    reservation so vm gets stopped on host
			$reqid = simpleAddRequest($compid, 4, 3, $start, $end, 18, $vclreloadid);
			$rems[] = array('id' => $compid,
			                'hostname' => $compdata[$compid]['hostname'],
			                'reqid' => $reqid,
			                'time' => 'immediately');
		}
		else {
			# existing reservation on computer, find end time and prompt user
			#   if ok to wait until then to move it
			$query = "SELECT DATE_FORMAT(rq.end, '%l:%i%p %c/%e/%y') AS end, "
			       .        "rq.end AS end2 "
			       . "FROM request rq, "
			       .      "reservation rs "
			       . "WHERE rs.requestid = rq.id AND "
			       .       "rs.computerid = $compid AND "
			       .       "rq.stateid NOT IN (1,5,12) "
			       . "ORDER BY end DESC "
			       . "LIMIT 1";
			$qh = doQuery($query, 101);
			if($row = mysql_fetch_assoc($qh)) {
				$checks[] = array('id' => $compid,
				                  'hostname' => $compdata[$compid]['hostname'],
				                  'end' => strtolower($row['end']),
				                  'end2' => $row['end2']);
			}
			else
				$rems[] = array('id' => $compid);
		}
	}
	if(count($checks))
		$cont = addContinuationsEntry('AJvmFromHostDelayed', $checks, 120, 1, 0);
	else
		$cont = '';
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	$arr = array('vms' => $rems,
	             'checks' => $checks,
	             'fails' => $fails,
	             'addrem' => 0,
	             'cont' => $cont);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJvmFromHostDelayed()
///
/// \brief submits future tomaintenance reservations for vm's saved in the
/// continuation
///
////////////////////////////////////////////////////////////////////////////////
function AJvmFromHostDelayed() {
	$data = getContinuationVar();
	$vclreloadid = getUserlistID('vclreload@Local');
	foreach($data as $comp) {
		$end = datetimeToUnix($comp['end2']) + SECINMONTH;
		$end = unixToDatetime($end);
		simpleAddRequest($comp['id'], 4, 3, $comp['end2'], $end, 18, $vclreloadid);
	}
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	$cont = addContinuationsEntry('vmhostdata');
	$arr = array('msg' => 'SUCCESS', 'cont' => $cont);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJchangeVMprofile()
///
/// \brief stub function for changing the vm profile of a vm host
///
////////////////////////////////////////////////////////////////////////////////
function AJchangeVMprofile() {
	$hostid = processInputVar('hostid', ARG_NUMERIC);
	$oldprofileid = processInputVar('oldprofileid', ARG_NUMERIC);
	$newprofileid = processInputVar('newprofileid', ARG_NUMERIC);
	# add security checks
	# try to remove reservations off of each vm
	// if no reservations on any vms, create reload reservation
	# else try to create reservation to handle in future
	# else return error message
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	$cont = addContinuationsEntry('AJchangeVMprofile', array(), 3600, 1, 0);
	$arr = array('msg' => 'function not implemented', 'continuation' => $cont);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJcancelVMmove()
///
/// \brief cancels tomaintenance reservations that had been submitted to move
/// a vm off of a vmhost
///
////////////////////////////////////////////////////////////////////////////////
function AJcancelVMmove() {
	$hostid = processInputVar('hostid', ARG_NUMERIC);
	
	$hostdata = getVMHostData($hostid);
	$resources = getUserResources(array("computerAdmin"), array("administer"));
	if(! array_key_exists($hostdata[$hostid]['computerid'], $resources['computer'])) {
		$arr = array('failed' => 'nohostaccess');
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$fails = array();
	$requestids = processInputVar('listids', ARG_STRING);
	$now = time();
	$msg = 'FAIL';
	foreach(explode(',', $requestids) AS $reqid) {
		$request = getRequestInfo($reqid);
		if(! array_key_exists($request['reservations'][0]['computerid'], $resources['computer'])) {
			$fails[] = array('id' => $request['reservations'][0]['computerid'],
			                 'name' => $request['reservations'][0]['hostname'],
			                 'reason' => 'noaccess');
			continue;
		}
		if(datetimeToUnix($request["start"]) < $now) {
			# set stateid and laststateid for each request to deleted
			$query = "UPDATE request "
			       . "SET stateid = 1, "
			       .     "laststateid = 1 "
			       . "WHERE id = $reqid";
			doQuery($query, 101);
		}
		else {
			$query = "DELETE FROM request WHERE id = $reqid";
			doQuery($query, 101);
			$query = "DELETE FROM reservation WHERE requestid = $reqid";
			doQuery($query, 101);
		}
		$msg = 'SUCCESS';
	}
	
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	$cont = addContinuationsEntry('vmhostdata');
	$arr = array('msg' => $msg, 'cont' => $cont, 'fails' => $fails);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJprofiledata()
///
/// \param $profileid - (optional) id of a vm profile
///
/// \brief prints json data about a submitted or passed in vm profile with these
/// fields:\n
/// \b profile - array returned from getVMProfiles\n
/// \b types - array of vm types\n
/// \b vmdisk - array of vm disk options\n
/// \b images - array of images
///
////////////////////////////////////////////////////////////////////////////////
function AJprofileData($profileid="") {
	global $viewmode;
	if($viewmode != ADMIN_DEVELOPER) {
		$arr = array('failed' => 'noaccess');
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}
	$profileid = processInputVar('profileid', ARG_NUMERIC, $profileid);
	$profiledata = getVMProfiles($profileid);
	foreach($profiledata[$profileid] AS $key => $value) {
		if(is_null($value))
			$profiledata[$profileid][$key] = '';
	}
	$types = getVMtypes();
	$allimages = getImages();
	$images = array();
	foreach($allimages as $key => $image)
		$images[] = array('id' => $key, 'name' => $image['prettyname']);
	$imagedata = array('identifier' => 'id', 'items' => $images);
	
	$types2 = array();
	foreach($types as $id => $val) {
		$types2[] = array('id' => $id, 'name' => $val);
	}
	$typedata = array('identifier' => 'id', 'items' => $types2);

	$vmdiskitems = array();
	$vmdiskitems[] = array('id' => 'localdisk', 'name' => 'localdisk');
	$vmdiskitems[] = array('id' => 'networkdisk', 'name' => 'networkdisk');
	$vmdisk = array('identifier' => 'id', 'items' => $vmdiskitems);
	
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	$arr = array('profile' => $profiledata[$profileid],
	             'types' => $typedata,
	             'vmdisk' => $vmdisk,
	             'images' => $imagedata);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJupdateVMprofileItem()
///
/// \brief updates the submitted item for the submitted vm profile and prints
/// javascript to keep the global curprofile object updated
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateVMprofileItem() {
	global $viewmode;
	if($viewmode != ADMIN_DEVELOPER) {
		print "alert('You do not have access to manage this vm profile.');";
		return;
	}
	$profileid = processInputVar('profileid', ARG_NUMERIC);
	$item = processInputVar('item', ARG_STRING);
	$newvalue = processInputVar('newvalue', ARG_STRING);
	if($newvalue == '')
		$newvalue2 = 'NULL';
	else {
		if(get_magic_quotes_gpc()) {
			$newvalue2 = stripslashes($newvalue);
			$newvalue2 = mysql_escape_string($newvalue2);
		}
		$newvalue2 = "'$newvalue2'";
	}

	$profile = getVMProfiles($profileid);
	if($profile[$profileid][$item] == $newvalue)
		return;
	$query = "UPDATE vmprofile "
	       . "SET `$item` = $newvalue2 "
	       . "WHERE id = $profileid";
	doQuery($query, 101);
	print "curprofile.$item = '$newvalue';";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJnewProfile()
///
/// \brief creates a new vmprofile entry using just the submitted new name and
/// the defaults for the rest of the fields; calls AJprofileData
///
////////////////////////////////////////////////////////////////////////////////
function AJnewProfile() {
	$newprofile = processInputVar('newname', ARG_STRING);
	if(get_magic_quotes_gpc()) {
		$newprofile = stripslashes($newprofile);
		$newprofile = mysql_escape_string($newprofile);
	}
	# TODO add check for existing name
	$query = "SELECT id FROM vmprofile WHERE profilename = '$newprofile'";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		$arr = array('failed' => 'exists');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}
	$query = "INSERT INTO vmprofile (profilename) VALUES ('$newprofile')";
	doQuery($query, 101);
	$qh = doQuery("SELECT LAST_INSERT_ID() FROM vmprofile", 101);
	$row = mysql_fetch_row($qh);
	$newid = $row[0];
	AJprofileData($newid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJdelProfile()
///
/// \brief deletes the submitted vm profile
///
////////////////////////////////////////////////////////////////////////////////
function AJdelProfile() {
	global $viewmode;
	if($viewmode != ADMIN_DEVELOPER) {
		$arr = array('failed' => 'noaccess');
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}
	$profileid = processInputVar('profileid', ARG_NUMERIC);
	$query = "DELETE FROM vmprofile WHERE id = $profileid";
	doQuery($query, 101);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	$arr = array('SUCCESS');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

?>
