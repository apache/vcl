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
	print "<h2>Manage Virtual Hosts</h2>\n";

	$profiles = getVMProfiles();
	uasort($profiles, 'sortKeepIndex');
	if(checkUserHasPerm('Manage VM Profiles')) {
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
	}
	else {
		print $newmsg;
		print "Select a Virtual Host:<br>\n";
		printSelectInput("vmhostid", $vmhosts, -1, 0, 0, 'vmhostid', 'onChange="dojo.byId(\'vmhostdata\').className = \'hidden\';"');
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
		print "    <th align=right>VM Profile:</th>\n";
		print "    <td>\n";
		print "      <div dojoType=\"dijit.TitlePane\" id=vmprofile></div>\n";
		print "    </td>\n";
		print "  </tr>\n";
		print "</table><br><br>\n";

		print "<div id=movevms class=hidden>\n";
		print "The following VM(s) will removed from this host at the listed ";
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
		print "Assigned VMs: <span id=\"assignedcnt\">0</span><br>\n";
		print "State of selected vm:<br>\n";
		print "<span id=vmstate></span>\n";
		print "<div id=\"noaccessdiv\" class=\"hidden\"><hr>VMs assigned to ";
		print "host that you<br>do not have access to remove:<br><br>\n";
		print "<div id=\"noaccess\"></div>\n";
		print "</div>\n";
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
	}
	print "</div>\n";

	if(! checkUserHasPerm('Manage VM Profiles'))
		return;
	$imagetypes = getImageTypes();
	print "<div id=\"vmprofiles\" dojoType=\"dijit.layout.ContentPane\" title=\"VM Host Profiles\">\n";
	if(count($profiles))
		print "<span id=\"selectprofilediv\">";
	else
		print "<span id=\"selectprofilediv\" class=\"hidden\">";
	print "<br>Select a profile to configure:<br>\n";
	print "<select name=\"profileid\" id=\"profileid\" onChange=\"dojo.byId('vmprofiledata').className = 'hidden';\">\n";
	foreach($profiles as $id => $item)
		print "  <option value=\"$id\">{$item['profilename']}</option>\n";
	print "</select>\n";
	$cont = addContinuationsEntry('AJprofiledata');
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchProfilesBtn\">\n";
	print "	Configure Profile\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getVMprofileData('$cont');\n";
	print "	</script>\n";
	print "</button>\n";
	print "</span>\n";
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
	print "(* denotes required fields)<br>\n";
	print "<input type=hidden id=pcont value=\"$cont\">\n";
	print "<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <th align=right>Name:*</th>\n";
	print "    <td><span id=pname dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pname', 'profilename');\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Image:</th>\n";
	print "    <td><span id=pimage dojoType=\"dijit.form.FilteringSelect\" searchAttr=\"name\" onchange=\"updateProfile('pimage', 'imageid');\" style=\"width: 420px\" required=\"false\"></span></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Resource Path:</th>\n";
	print "    <td><span id=presourcepath dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('presourcepath', 'resourcepath');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"resourcepathhelp\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Folder Path:</th>\n";
	print "    <td><span id=pfolderpath dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pfolderpath', 'folderpath');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"folderpathhelp\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Repository Path:</th>\n";
	print "    <td><span id=prepositorypath dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('prepositorypath', 'repositorypath');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"repositorypathhelp\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Repository Image Type:</th>\n";
	print "    <td>\n";
	printSelectInput("", $imagetypes, -1, 0, 0, 'prepositoryimgtype', 'dojoType="dijit.form.Select" onChange="updateProfile(\'prepositoryimgtype\', \'repositoryimagetypeid\');"');
	print "    <img tabindex=0 src=\"images/helpicon.png\" id=\"repositoryimgtypehelp\" />\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Virtual Disk Path:*</th>\n";
	print "    <td><span id=pdspath dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pdspath', 'datastorepath');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"dspathhelp\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Virtual Disk Image Type:*</th>\n";
	print "    <td>\n";
	printSelectInput("", $imagetypes, -1, 0, 0, 'pdatastoreimgtype', 'dojoType="dijit.form.Select" onChange="updateProfile(\'pdatastoreimgtype\', \'datastoreimagetypeid\');"');
	print "    <img tabindex=0 src=\"images/helpicon.png\" id=\"datastoreimgtypehelp\" />\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Virtual Disk Mode:*</th>\n";
	print "    <td><select id=pvmdisk dojoType=\"dijit.form.FilteringSelect\" searchAttr=\"name\" onchange=\"updateProfile('pvmdisk', 'vmdisk');\"></select><img tabindex=0 src=\"images/helpicon.png\" id=\"vmdiskhelp\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>VM Working Directory Path:</th>\n";
	print "    <td><span id=pvmpath dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pvmpath', 'vmpath');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"vmpathhelp\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>VM Network 0:*</th>\n";
	print "    <td><span id=pvs0 dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pvs0', 'virtualswitch0');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"vs0help\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>VM Network 1:*</th>\n";
	print "    <td><span id=pvs1 dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pvs1', 'virtualswitch1');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"vs1help\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>VM Network 2:</th>\n";
	print "    <td><span id=pvs2 dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pvs2', 'virtualswitch2');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"vs2help\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>VM Network 3:</th>\n";
	print "    <td><span id=pvs3 dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pvs3', 'virtualswitch3');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"vs3help\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Generate eth0 MAC:*</th>\n";
	print "    <td><select id=pgenmac0 dojoType=\"dijit.form.Select\" onchange=\"updateProfile('pgenmac0', 'eth0generated');\">\n";
	print "    <option value=\"1\">Yes</option>\n";
	print "    <option value=\"0\">No</option>\n";
	print "    </select><img tabindex=0 src=\"images/helpicon.png\" id=\"genmac0help\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Generate eth1 MAC:*</th>\n";
	print "    <td><select id=pgenmac1 dojoType=\"dijit.form.Select\" onchange=\"updateProfile('pgenmac1', 'eth1generated');\">\n";
	print "    <option value=\"1\">Yes</option>\n";
	print "    <option value=\"0\">No</option>\n";
	print "    </select><img tabindex=0 src=\"images/helpicon.png\" id=\"genmac1help\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Username:</th>\n";
	print "    <td><span id=pusername dojoType=\"dijit.InlineEditBox\" onChange=\"updateProfile('pusername', 'username');\"></span><img tabindex=0 src=\"images/helpicon.png\" id=\"usernamehelp\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Password:</th>\n";
	print "    <td><input type=password id=ppassword onkeyup=\"checkProfilePassword();\"></input><img tabindex=0 src=\"images/helpicon.png\" id=\"passwordhelp\" /></td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <th align=right>Confirm:</th>\n";
	print "    <td>\n";
	print "      <input type=password id=ppwdconfirm onkeyup=\"checkProfilePassword();\"></input>\n";
	print "      <span id=ppwdmatch></span>\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "  <tr>\n";
	print "    <td></td>\n";
	print "    <td>\n";
	print "      <button dojoType=\"dijit.form.Button\" id=\"savePwdBtn\">\n";
	print "        Save Password\n";
	print "        <script type=\"dojo/method\" event=onClick>\n";
	print "        updateProfile('ppassword', 'password');\n";
	print "        </script>\n";
	print "      </button>\n";
	print "      <span id=savestatus></span>\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "</table>\n";
	print "</div>\n";
	print "</div>\n";

	print "</div>\n";

	print "<div dojoType=\"dijit.Tooltip\" connectId=\"resourcepathhelp\">\n";
	print i("Resource Path only needs to be configured if VMware vCenter is used. It defines the location where VMs will be created in the vCenter inventory tree. The inventory tree contains at least one Datacenter, and may also contain Folders, Clusters, and Resource Pools.<br>Example: /DatacenterA/Folder1/Cluster2/ResourcePool3");
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"folderpathhelp\">\n";
	print i("Folder Path only needs to be configured if VMware vCenter is used. It defines the location where VMs will reside according to the vSphere Client's 'VMs and Templates' inventory view. This view will contain at least 1 Datacenter at the root level of the tree. Underneath each Datacenter, VMs may optionally be organized into VM Folders. Example: /DatacenterA/VCL_VMs");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"repositorypathhelp\">\n";
	print i("(Optional) The path where master copies of images are stored which are used to transfer images to VM host datastores or to other repositories. This is required if multiple management nodes need to share images. VMs do not run directly off of the images stored in the repository. It can refer to and be mounted on either the management node or VM host.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"repositoryimgtypehelp\">\n";
	print i("Virtual disk type of the images stored here.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"dspathhelp\">\n";
	print i("The location where master copies of images are stored which are used by running VMs. It can be either on local or network storge. If on network storage, it can be shared among multiple hosts.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"datastoreimgtypehelp\">\n";
	print i("Virtual disk type of the images stored here.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"vmdiskhelp\">\n";
	print i("Defines whether the Virtual Disk Path storage is dedicated to a single host or shared among multiple hosts. If set to dedicated, Repository Path must be definied and VCL will remove copies of images in the Virtual Disk Path to free up space if they are not being used.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"vmpathhelp\">\n";
	print i("(Optional) This is the path on VM host where VM working directories will reside. If not configured, the Datastore Path location will be used. It can be either on local or network storge. It should be dedicated for each VM host and should be optimized for read-write performance.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"vs0help\">\n";
	print i("The VM Network parameters should match the network names configured on the VM host. For ESXi, the Virtual Switch parameters must match the Virtual Machine Port Group Network Labels configured in the vSphere Client. VM Network 0 should be your public or private network.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"vs1help\">\n";
	print i("The VM Network parameters should match the network names configured on the VM host. For ESXi, the Virtual Switch parameters must match the Virtual Machine Port Group Network Labels configured in the vSphere Client. VM Network 1 should be your public or private network.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"vs2help\">\n";
	print i("(Optional) The VM Network parameters should match the network names configured on the VM host. For ESXi, the Virtual Switch parameters must match the Virtual Machine Port Group Network Labels configured in the vSphere Client. VM Network 2 is optional for connecting the VM to additional networks.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"vs3help\">\n";
	print i("(Optional) The VM Network parameters should match the network names configured on the VM host. For ESXi, the Virtual Switch parameters must match the Virtual Machine Port Group Network Labels configured in the vSphere Client. VM Network 3 is optional for connecting the VM to additional networks.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"genmac0help\">\n";
	print i("Specifies whether VMs are assigned MAC addresses defined in the VCL database or if random MAC addresses should be assigned.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"genmac1help\">\n";
	print i("Specifies whether VMs are assigned MAC addresses defined in the VCL database or if random MAC addresses should be assigned.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"usernamehelp\">\n";
	print i("Name of the administrative or root user residing on the VM host.");
	print "</div>\n";
	print "<div dojoType=\"dijit.Tooltip\" connectId=\"passwordhelp\">\n";
	print i("Password of the administrative or root user residing on the VM host.");
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
		sendJSON(array('failed' => 'noaccess'));
		return;
	}
	$computers = $resources['computer'];

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
	       .       "c.vmhostid = $vmhostid) AND "
	       .       "c.deleted = 0 "
	       . "ORDER BY c.hostname";
	$qh = doQuery($query, 101);
	$ids = array();
	$allvms = array();
	$currvms = array();
	$noaccess = array();
	$freevms = array();
	while($row = mysql_fetch_assoc($qh)) {
		if($row['vmhostid'] == $vmhostid) {
			$ids[$row['id']] = $row['hostname'];
			if(array_key_exists($row['id'], $computers))
				$currvms[$row['id']] = array('id' => $row['id'],
				                             'name' => $row['hostname'],
				                             'state' => $row['state']);
			else
				$noaccess[$row['id']] = array('id' => $row['id'],
				                              'name' => $row['hostname'],
				                              'state' => $row['state']);
			$allvms[] = array('id' => $row['id'],
			                  'name' => $row['hostname'],
			                  'inout' => 1);
		}
		elseif(array_key_exists($row['id'], $computers)) {
			$freevms[] = array('id' => $row['id'],
			                   'name' => $row['hostname']);
			$allvms[] = array('id' => $row['id'],
			                  'name' => $row['hostname'],
			                  'inout' => 0);
		}
	}
	uasort($allvms, "sortKeepIndex");
	uasort($currvms, "sortKeepIndex");
	uasort($noaccess, "sortKeepIndex");
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
			                 'time' => strtolower($row['start']) . ' ' . date('T'),
			                 'hostname' => $currvms[$row['computerid']]['name']);
			unset($currvms[$row['computerid']]);
		}
		uasort($movevms, "sortKeepIndex");
		$movevms = array_merge($movevms);
	}

	$allvms = array_merge($allvms);
	$currvms = array_merge($currvms);
	$noaccess = array_merge($noaccess);
	$freevms = array_merge($freevms);
	$cont = addContinuationsEntry('AJchangeVMprofile', array(), 3600, 1, 0);
	$arr = array('profile' => $data[$vmhostid]['vmprofiledata'],
	             'continuation' => $cont,
	             'allvms' => $allvms,
	             'currvms' => $currvms,
	             'noaccess' => $noaccess,
	             'freevms' => $freevms,
	             'movevms' => $movevms);
	sendJSON($arr);
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
/// \b vmprofileid - id of vm profile\n
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
	       .        "vh.vmprofileid "
	       . "FROM vmhost vh, " 
	       .      "computer c "
	       . "WHERE vh.computerid = c.id";
	if(! empty($id))
		$query .= " AND vh.id = $id";
	$qh = doQuery($query, 101);
	$ret = array();
	while($row = mysql_fetch_assoc($qh)) {
		$ret[$row['id']] = $row;
		foreach($profiles[$row['vmprofileid']] AS $key => $value) {
			if(is_null($value))
				$profiles[$row['vmprofileid']][$key] = '';
		}
		$ret[$row['id']]['vmprofiledata'] = $profiles[$row['vmprofileid']];
	}
	uasort($ret, 'sortKeepIndex');
	return $ret;
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
		sendJSON(array('failed' => 'nohostaccess'));
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
	$arr = array('vms' => $adds, 'fails' => $fails, 'addrem' => 1);
	sendJSON($arr);
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
		sendJSON(array('failed' => 'nohostaccess'));
		return;
	}

	$fails = array();
	$vmlistids = processInputVar('listids', ARG_STRING);
	$vmids = explode(',', $vmlistids);
	$rems = array();
	$checks = array();
	$vclreloadid = getUserlistID('vclreload@Local');
	$imageid = getImageId('noimage');
	$imagerevisionid = getProductionRevisionid($imageid);
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
		moveReservationsOffComputer($compid);
		cleanSemaphore();

		# check for unmovable or active reservations
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
			                  'end' => strtolower($row['end']) . ' ' . date('T'),
			                  'end2' => $row['end2']);
		}
		else {
			// if no reservations on computer, submit reload 
			#    reservation so vm gets stopped on host
			$reqid = simpleAddRequest($compid, $imageid, $imagerevisionid, $start, $end, 18, $vclreloadid);
			if($reqid == 0) {
				$fails[] = array('id' => $compid,
				                 'name' => $compdata[$compid]['hostname'],
				                 'reason' => 'nomgtnode');
			}
			else {
				$rems[] = array('id' => $compid,
				                'hostname' => $compdata[$compid]['hostname'],
				                'reqid' => $reqid,
				                'time' => 'immediately');
			}
		}
	}
	if(count($checks))
		$cont = addContinuationsEntry('AJvmFromHostDelayed', $checks, 120, 1, 0);
	else
		$cont = '';
	$arr = array('vms' => $rems,
	             'checks' => $checks,
	             'fails' => $fails,
	             'addrem' => 0,
	             'cont' => $cont);
	sendJSON($arr);
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
	$imageid = getImageId('noimage');
	$imagerevisionid = getProductionRevisionid($imageid);
	$fails = array();
	foreach($data as $comp) {
		$end = datetimeToUnix($comp['end2']) + SECINMONTH;
		$end = unixToDatetime($end);
		if(! simpleAddRequest($comp['id'], $imageid, $imagerevisionid, $comp['end2'], $end, 18, $vclreloadid))
			$fails[] = array('name' => $comp['hostname'],
			                 'reason' => 'nomgtnode');
	}
	$cont = addContinuationsEntry('vmhostdata');
	$arr = array('msg' => 'SUCCESS', 'cont' => $cont, 'fails' => $fails);
	sendJSON($arr);
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
	$cont = addContinuationsEntry('AJchangeVMprofile', array(), 3600, 1, 0);
	$arr = array('msg' => 'function not implemented', 'continuation' => $cont);
	sendJSON($arr);
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
		sendJSON(array('failed' => 'nohostaccess'));
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
	
	$cont = addContinuationsEntry('vmhostdata');
	$arr = array('msg' => $msg, 'cont' => $cont, 'fails' => $fails);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJprofileData()
///
/// \param $profileid - (optional) id of a vm profile
///
/// \brief prints json data about a submitted or passed in vm profile with these
/// fields:\n
/// \b profile - array returned from getVMProfiles\n
/// \b vmdisk - array of vm disk options\n
/// \b images - array of images
///
////////////////////////////////////////////////////////////////////////////////
function AJprofileData($profileid="") {
	if(! checkUserHasPerm('Manage VM Profiles')) {
		sendJSON(array('failed' => 'noaccess'));
		return;
	}
	$profileid = processInputVar('profileid', ARG_NUMERIC, $profileid);
	$profiledata = getVMProfiles($profileid);
	foreach($profiledata[$profileid] AS $key => $value) {
		if(is_null($value))
			$profiledata[$profileid][$key] = '';
	}
	$allimages = getImages();
	$images = array();
	foreach($allimages as $key => $image) {
		if($image['name'] == 'noimage')
			continue;
		$images[] = array('id' => $key, 'name' => $image['prettyname']);
	}
	$imagedata = array('identifier' => 'id', 'items' => $images);
	
	$vmdiskitems = array();
	$vmdisks = getENUMvalues('vmprofile', 'vmdisk');
	foreach($vmdisks as $val)
		$vmdiskitems[] = array('id' => $val, 'name' => $val);
	$vmdisk = array('identifier' => 'id', 'items' => $vmdiskitems);

	$arr = array('profile' => $profiledata[$profileid],
	             'vmdisk' => $vmdisk,
	             'images' => $imagedata);
	sendJSON($arr);
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
	if(! checkUserHasPerm('Manage VM Profiles')) {
		print "alert('You do not have access to manage this vm profile.');";
		return;
	}
	$profileid = processInputVar('profileid', ARG_NUMERIC);
	$item = processInputVar('item', ARG_STRING);
	if(! preg_match('/^(profilename|imageid|resourcepath|folderpath|repositorypath|repositoryimagetypeid|datastorepath|datastoreimagetypeid|vmdisk|vmpath|virtualswitch[0-3]|username|password|eth0generated|eth1generated)$/', $item)) {
		print "alert('Invalid data submitted.');";
		return;
	}
	if(preg_match('/^eth[01]generated$/', $item)) {
		$newvalue = processInputVar('newvalue', ARG_NUMERIC);
		if($newvalue != 0 && $newvalue != 1)
			$newvalue = 0;
	}
	elseif(preg_match('/imagetypeid$/', $item)) {
		$newvalue = processInputVar('newvalue', ARG_STRING);
		$imagetypes = getImageTypes();
		if(! array_key_exists($newvalue, $imagetypes))
			$newvalue = 1;
	}
	elseif($item == 'vmdisk') {
		$newvalue = processInputVar('newvalue', ARG_STRING);
		$vmdisks = getENUMvalues('vmprofile', 'vmdisk');
		if(! in_array($newvalue, $vmdisks))
			$newvalue = $vmdisks[0];
	}
	elseif($item == 'password')
		$newvalue = $_POST['newvalue'];
	else
		$newvalue = processInputVar('newvalue', ARG_STRING);
	if($newvalue == '')
		$newvalue2 = 'NULL';
	else {
		if(get_magic_quotes_gpc())
			$newvalue = stripslashes($newvalue);
		$newvalue2 = mysql_real_escape_string($newvalue);
		$newvalue2 = "'$newvalue2'";
	}

	$item = mysql_real_escape_string($item);
	$profile = getVMProfiles($profileid);
	if($item == 'password') {
		$pwdlen = strlen($newvalue);
		if($pwdlen == 0) {
			if($profile[$profileid]['pwdlength'] != 0) {
				$secretid = getSecretKeyID('vmprofile', 'secretid', $profileid);
				if($secretid === NULL) {
					print "dojo.byId('savestatus').innerHTML = '';";
					print "alert('Error saving password');";
					return;
				}
				deleteSecretKeys($secretid);
				$query = "UPDATE vmprofile "
				       . "SET password = NULL, "
				       .     "secretid = NULL "
				       . "WHERE id = $profileid";
				doQuery($query);
			}
		}
		else {
			$secretid = getSecretKeyID('vmprofile', 'secretid', $profileid);
			# check that we have a cryptsecret entry for this secret
			$cryptkeyid = getCryptKeyID();
			if($cryptkeyid === NULL) {
				print "dojo.byId('savestatus').innerHTML = '';";
				print "alert('Error saving password');";
				return;
			}
			$query = "SELECT cryptsecret "
			       . "FROM cryptsecret "
			       . "WHERE cryptkeyid = $cryptkeyid AND "
			       .       "secretid = $secretid";
			$qh = doQuery($query);
			if(! ($row = mysql_fetch_assoc($qh))) {
				# generate a new secret
				$newsecretid = getSecretKeyID('vmprofile', 'secretid', 0);
				$delids = array($secretid);
				if($newsecretid == $secretid) {
					$delids[] = $secretid;
					$newsecretid = getSecretKeyID('addomain', 'secretid', 0);
				}
				$delids = implode(',', $delids);
				# encrypt new secret with any management node keys
				$secretidset = array();
				$query = "SELECT ck.hostid AS mnid "
				       . "FROM cryptkey ck "
				       . "JOIN cryptsecret cs ON (ck.id = cs.cryptkeyid) "
				       . "WHERE cs.secretid = $secretid AND "
				       .       "ck.hosttype = 'managementnode'";
				$qh = doQuery($query);
				while($row = mysql_fetch_assoc($qh))
					$secretidset[$row['mnid']][$newsecretid] = 1;
				$values = getMNcryptkeyUpdates($secretidset, $cryptkeyid);
				addCryptSecretKeyUpdates($values);
				$secretid = $newsecretid;
				# clean up old cryptsecret entries for management nodes
				$query = "DELETE FROM cryptsecret WHERE secretid IN ($delids)";
				doQuery($query);
			}
			if($secretid === NULL) {
				print "dojo.byId('savestatus').innerHTML = '';";
				print "alert('Error saving password');";
				return;
			}
			$encpass = encryptDBdata($newvalue, $secretid);
			$query = "UPDATE vmprofile "
			       . "SET password = '$encpass', "
			       .     "secretid = '$secretid', "
			       .     "rsapub = NULL, "
			       .     "rsakey = NULL, "
			       .     "encryptedpasswd = NULL "
			       . "WHERE id = $profileid";
			doQuery($query);
		}
		print "dojo.byId('savestatus').innerHTML = 'Saved'; ";
		print "setTimeout(function() {dojo.byId('savestatus').innerHTML = '';}, 3000); ";
		print "curprofile.pwdlength = $pwdlen;";
		return;
	}
	elseif($profile[$profileid][$item] == $newvalue)
		return;
	$query = "UPDATE vmprofile "
	       . "SET `$item` = $newvalue2 "
	       . "WHERE id = $profileid";
	doQuery($query, 101);
	$newvalue = preg_replace("/'/", "\\'", $newvalue);
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
		$newprofile = mysql_real_escape_string($newprofile);
	}
	$query = "SELECT id FROM vmprofile WHERE profilename = '$newprofile'";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		sendJSON(array('failed' => 'exists'));
		return;
	}
	$imageid = getImageId('noimage');
	$query = "INSERT INTO vmprofile "
	       .        "(profilename, "
	       .        "imageid, "
	       .        "repositoryimagetypeid, "
	       .        "datastoreimagetypeid) "
	       . "VALUES "
	       .       "('$newprofile', "
	       .       "$imageid, "
	       .       "(SELECT id FROM imagetype WHERE name = 'vmdk'), "
	       .       "(SELECT id FROM imagetype WHERE name = 'vmdk'))";
	doQuery($query, 101);
	$newid = dbLastInsertID();
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
	if(! checkUserHasPerm('Manage VM Profiles')) {
		sendJSON(array('failed' => 'noaccess'));
		return;
	}
	$profileid = processInputVar('profileid', ARG_NUMERIC);
	# check to see if profile is in use
	$query = "SELECT vh.computerid, "
	       .        "s.name "
	       . "FROM vmhost vh, "
	       .      "computer c, "
	       .      "state s "
	       . "WHERE vh.computerid = c.id AND " 
	       .       "c.stateid = s.id AND "
	       .       "s.name IN ('vmhostinuse', 'tovmhostinuse') AND " 
	       .       "vh.vmprofileid = $profileid";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		sendJSON(array('failed' => 'inuse'));
		return;
	}
	$query = "DELETE FROM vmprofile WHERE id = $profileid";
	doQuery($query, 101);
	sendJSON(array('SUCCESS'));
}

?>
