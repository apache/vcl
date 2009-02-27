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
 * \file
 */

/// signifies an error with submitted hostname
define("MNHOSTNAMEERR", 1);
/// signifies an error with submitted IP address
define("IPADDRESSERR", 1 << 1);
/// signifies an error with submitted owner
define("MNOWNERERR", 1 << 2);
/// signifies an error with submitted install path
define("MNINSTPATHERR", 1 << 3);
/// signifies an error with submitted image library user
define("MNIMGLIBUSERERR", 1 << 4);
/// signifies an error with submitted image library key
define("MNIMGLIBKEYERR", 1 << 5);
/// signifies an error with submitted SSH port
define("MNSSHPORTERR", 1 << 6);
/// signifies an error with submitted SSH identity keys
define("MNSSHIDKEYSERR", 1 << 7);
/// signifies an error with submitted image library group id
define("MNIMGLIBGRPIDERR", 1 << 8);


////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectMgmtnodeOption()
///
/// \brief prints a page for the user to select which management node operation
/// they want to perform; if they only have access to a few options or only a
/// few management nodes, just send them straight to viewImagesAll
///
////////////////////////////////////////////////////////////////////////////////
function selectMgmtnodeOption() {
	# get all management nodes
	$nodes = getManagementNodes();
	if(empty($nodes)) {
		viewMgmtnodes();
		return;
	}

	# get a count of management nodes user can administer
	$tmp = getUserResources(array("mgmtNodeAdmin"), array("administer"));
	$mnAdminCnt = count($tmp['managementnode']);

	# get a count of management node groups user can manage
	$tmp = getUserResources(array("mgmtNodeAdmin"), array("manageGroup"), 1);
	$mnGroupCnt = count($tmp['managementnode']);

	# get a count of computer groups user can manage
	$tmp = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	$compGroupCnt = count($tmp['computer']);

	print "<H2>Manage Management Nodes</H2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	if($mnAdminCnt) {
		$cont = addContinuationsEntry('viewMgmtnodes');
		print "<INPUT type=radio name=continuation value=\"$cont\" checked>Edit ";
		print "Management Node Information<br>\n";
	}
	if($mnGroupCnt) {
		$cont = addContinuationsEntry('viewMgmtnodeGrouping');
		print "<INPUT type=radio name=continuation value=\"$cont\">Edit ";
		print "Management Node Grouping<br>\n";
		if($compGroupCnt) {
			$cont = addContinuationsEntry('viewMgmtnodeMapping');
			print "<INPUT type=radio name=continuation value=\"$cont\">Edit ";
			print "Management Node Mapping<br>\n";
		}
	}
	if($mnAdminCnt || $mnGroupCnt)
		print "<INPUT type=submit value=Submit>\n";
	else {
		print "You do not have access to manage any management nodes.<br>\n";
	}
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewMgmtnodes()
///
/// \brief prints a page to view management node information
///
////////////////////////////////////////////////////////////////////////////////
function viewMgmtnodes() {
	global $viewmode, $user, $mode;

	$mgmtnodes = getManagementNodes();
	$resources = getUserResources(array("mgmtNodeAdmin"), array("administer"));
	$userMgmtnodeIDs = array_keys($resources["managementnode"]);
	$premodules = getPredictiveModules();

	print "<H2>Management Node Information</H2>\n";
	if($mode == "submitAddMgmtnode") {
		print "<font color=\"#008000\">Management node successfully added";
		print "</font><br><br>\n";
	}
	elseif($mode == "submitEditMgmtnode") {
		print "<font color=\"#008000\">Management node successfully updated";
		print "</font><br><br>\n";
	}
	elseif($mode == "submitDeleteMgmtnode") {
		print "<font color=\"#008000\">Management node successfully deleted";
		print "</font><br><br>\n";
	}
	print "<TABLE border=1>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TD></TD>\n";
	print "    <TH>Hostname</TH>\n";
	print "    <TH>IP address</TH>\n";
	print "    <TH>Owner</TH>\n";
	print "    <TH>State</TH>\n";
	print "    <TH>Predictive Loading Module</TH>\n";
	print "    <TH>Last Check In</TH>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "    <TD><INPUT type=submit value=Add></TD>\n";
	print "    <TD><INPUT type=text name=hostname maxlength=50 size=15></TD>\n";
	print "    <TD><INPUT type=text name=IPaddress maxlength=15 size=15></TD>\n";
	print "    <TD><INPUT type=text name=owner size=15 value=\"";
	print "{$user["unityid"]}@{$user['affiliation']}\"></TD>\n";
	print "    <TD>\n";
	$mgmtnodestates = array(2 => "available", 1 => "deleted", 10 => "maintenance");
	printSelectInput("stateid", $mgmtnodestates);
	print "    </TD>\n";
	print "    <TD>\n";
	printSelectInput('premoduleid', $premodules);
	print "    </TD>\n";
	print "    <TD align=center>N/A</TD>\n";
	$cont = addContinuationsEntry('addMgmtNode');
	print "    <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "    </FORM>\n";
	print "  </TR>\n";
	foreach(array_keys($mgmtnodes) as $id) {
		if(! in_array($id, $userMgmtnodeIDs))
			continue;
		print "  <TR align=center>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('mgmtnodeid' => $id);
		$cont = addContinuationsEntry('confirmDeleteMgmtnode', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=Delete>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('mgmtnodeid' => $id);
		$cont = addContinuationsEntry('editMgmtNode', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=Edit>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD>{$mgmtnodes[$id]["hostname"]}</TD>\n";
		print "    <TD>{$mgmtnodes[$id]["IPaddress"]}</TD>\n";
		print "    <TD>{$mgmtnodes[$id]["owner"]}</TD>\n";
		print "    <TD>{$mgmtnodes[$id]["state"]}</TD>\n";
		print "    <TD>{$mgmtnodes[$id]["predictivemodule"]}</TD>\n";
		if($mgmtnodes[$id]["lastcheckin"] == "")
			print "    <TD>never</TD>\n";
		else
			print "    <TD>" . $mgmtnodes[$id]["lastcheckin"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editOrAddMgmtnode($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a form for editing an image
///
////////////////////////////////////////////////////////////////////////////////
function editOrAddMgmtnode($state) {
	global $submitErr;

	$mgmtnodes = getManagementNodes();
	$premodules = getPredictiveModules();

	if($submitErr || $state == 1) {
		$data = processMgmtnodeInput(0);
	}
	else {
		$data["mgmtnodeid"] = getContinuationVar("mgmtnodeid");
		$id = $data["mgmtnodeid"];
		$data["hostname"] = $mgmtnodes[$id]["hostname"];
		$data["IPaddress"] = $mgmtnodes[$id]["IPaddress"];
		$data["owner"] = $mgmtnodes[$id]["owner"];
		$data["stateid"] = $mgmtnodes[$id]["stateid"];
		$data["premoduleid"] = $mgmtnodes[$id]["predictivemoduleid"];
		$data["checkininterval"] = $mgmtnodes[$id]["checkininterval"];
		$data["installpath"] = $mgmtnodes[$id]["installpath"];
		if($mgmtnodes[$id]['imagelibenable'])
			$data['imagelibenable'] = "checked";
		else
			$data['imagelibenable'] = "";
		$data['imagelibgroupid'] = $mgmtnodes[$id]['imagelibgroupid'];
		$data['imagelibgroup'] = $mgmtnodes[$id]['imagelibgroup']; # TODO this can be removed
		$data['imagelibuser'] = $mgmtnodes[$id]['imagelibuser'];
		$data['imagelibkey'] = $mgmtnodes[$id]['imagelibkey'];
		$data['keys'] = $mgmtnodes[$id]['keys'];
		$data['sshport'] = $mgmtnodes[$id]['sshport'];
	}
	$disabled = '';
	if(! $data['imagelibenable'])
		$disabled = 'disabled';

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<DIV align=center>\n";
	if($state) {
		print "<H2>Add Management Node</H2>\n";
	}
	else {
		print "<H2>Edit Management Node</H2>\n";
	}
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname:</TH>\n";
	print "    <TD><INPUT type=text name=hostname value=\"{$data["hostname"]}\" ";
	print "maxlength=50></TD>\n";
	print "    <TD>";
	printSubmitErr(MNHOSTNAMEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>IP address:</TH>\n";
	print "    <TD><INPUT type=text name=IPaddress value=\"";
	print $data["IPaddress"] . "\" maxlength=15></TD>\n";
	print "    <TD>";
	printSubmitErr(IPADDRESSERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD><INPUT type=text name=owner value=\"" . $data["owner"];
	print "\"></TD>\n";
	print "    <TD>";
	printSubmitErr(MNOWNERERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>State:</TH>\n";
	print "    <TD>\n";
	$mgmtnodestates = array(2 => "available", 1 => "deleted", 10 => "maintenance",
	                        5 => "failed");
	printSelectInput("stateid", $mgmtnodestates, $data["stateid"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Predictive Loading Module:</TH>\n";
	print "    <TD>\n";
	printSelectInput("premoduleid", $premodules, $data["premoduleid"]);
	print "    </TD>\n";
	print "  </TR>\n";

	# checkininterval
	print "  <TR>\n";
	print "    <TH id=th1 align=right\n";
	print "        onmouseover=\"showHelp('interval between database checks for new tasks', 'th1');\"\n";
	print "        onmouseout=\"clearHelpbox();\">\n";
	print "      Check-in Interval (sec):\n";
	print "    </TH>\n";
	print "    <TD>\n";
	print "      <input dojoType=\"dijit.form.NumberSpinner\"\n";
	print "                value=\"{$data['checkininterval']}\"\n";
	print "                constraints=\"{min:5,max:30,places:0}\"\n";
	print "                maxlength=\"2\"\n";
	print "                id=\"checkininterval\"\n";
	print "                name=\"checkininterval\">\n";
	print "    </TD>\n";
	print "    <TD></TD>";
	print "  </TR>\n";
	# installpath
	print "  <TR>\n";
	print "    <TH id=th2 align=right\n";
	print "        onmouseover=\"showHelp('path to parent directory of image repository directories', 'th2');\"\n";
	print "        onmouseout=\"clearHelpbox();\">\n";
	print "      Install Path:</TH>\n";
	print "    <TD><INPUT type=text name=installpath value=\"";
	print $data["installpath"] . "\" maxlength=100></TD>\n";
	print "    <TD>";
	printSubmitErr(MNINSTPATHERR);
	print "</TD>\n";
	print "  </TR>\n";
	# keys
	print "  <TR>\n";
	print "    <TH id=th5 align=right\n";
	print "        onmouseover=\"showHelp('comma delimited list of full paths to ssh identity keys to try when connecting to end nodes (optional)', 'th5');\"\n";
	print "        onmouseout=\"clearHelpbox();\">\n";
	print "      End Node SSH Identity Key Files:</TH>\n";
	print "    <TD><INPUT type=text name=keys value=\"";
	print $data["keys"] . "\" maxlength=1024></TD>\n";
	print "    <TD>";
	printSubmitErr(MNSSHIDKEYSERR);
	print "</TD>\n";
	print "  </TR>\n";
	# sshport
	print "  <TR>\n";
	print "    <TH id=th6 align=right\n";
	print "        onmouseover=\"showHelp('SSH port this node is listening on for image file transfers', 'th6');\"\n";
	print "        onmouseout=\"clearHelpbox();\">\n";
	print "      SSH Port for this node:\n";
	print "    </TH>\n";
	print "    <TD>\n";
	print "      <input dojoType=\"dijit.form.NumberSpinner\"\n";
	print "                value=\"{$data['sshport']}\"\n";
	print "                constraints=\"{min:1,max:65535,places:0}\"\n";
	print "                maxlength=\"5\"\n";
	print "                id=\"sshport\"\n";
	print "                name=\"sshport\">\n";
	print "    </TD>\n";
	print "    <TD>";
	printSubmitErr(MNSSHPORTERR);
	print "</TD>\n";
	print "  </TR>\n";
	# imagelibenable
	print "  <TR>\n";
	print "    <TH id=th7 align=right\n";
	print "        onmouseover=\"showHelp('path to parent directory of image repository directories', 'th7');\"\n";
	print "        onmouseout=\"clearHelpbox();\">\n";
	print "      Enable Image Library:</TH>\n";
	print "    <TD><input type=checkbox name=imagelibenable value=1 ";
	print $data["imagelibenable"] . " onchange=\"toggleImageLibrary();\" \n";
	if($data['imagelibenable'])
		print "id=imagelibenable checked></TD>\n";
	else
		print "id=imagelibenable></TD>\n";
	print "    <TD></TD>\n";
	print "  </TR>\n";
	# imagelibgroupid
	print "  <TR>\n";
	print "    <TH id=th8 align=right\n";
	print "        onmouseover=\"showHelp('this management node will try to get image files from other nodes in the selected group', 'th8');\"\n";
	print "        onmouseout=\"clearHelpbox();\">\n";
	print "      Image Library Management Node Group:</TH>\n";
	print "    <TD>";
	$mgmtnodegroups = getUserResources(array('mgmtNodeAdmin'), array("manageGroup"), 1);
	printSelectInput("imagelibgroupid", $mgmtnodegroups['managementnode'], -1, 0, 0, 'imagelibgroupid', $disabled);
	print "    </TD>\n";
	print "    <TD>";
	printSubmitErr(MNIMGLIBGRPIDERR);
	print "</TD>\n";
	print "  </TR>\n";
	# imagelibuser
	print "  <TR>\n";
	print "    <TH id=th3 align=right\n";
	print "        onmouseover=\"showHelp('userid to use when scp\'ing image files from another management node', 'th3');\"\n";
	print "        onmouseout=\"clearHelpbox();\">\n";
	print "      Image Library User:</TH>\n";
	print "    <TD><INPUT type=text name=imagelibuser value=\"";
	print $data["imagelibuser"] . "\" $disabled id=imagelibuser></TD>\n";
	print "    <TD>";
	printSubmitErr(MNIMGLIBUSERERR);
	print "</TD>\n";
	print "  </TR>\n";
	# imagelibkey
	print "  <TR>\n";
	print "    <TH id=th4 align=right\n";
	print "        onmouseover=\"showHelp('path to ssh identity key file to use when scp\'ing image files from another management node', 'th4');\"\n";
	print "        onmouseout=\"clearHelpbox();\">\n";
	print "      Image Library SSH Identity Key File:</TH>\n";
	print "    <TD><INPUT type=text name=imagelibkey value=\"";
	print $data["imagelibkey"] . "\" maxlength=100 $disabled id=imagelibkey></TD>\n";
	print "    <TD>";
	printSubmitErr(MNIMGLIBKEYERR);
	print "</TD>\n";
	print "  </TR>\n";

	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	if($state) {
		$cdata = array('mgmtgroups' => $mgmtnodegroups['managementnode']);
		$cont = addContinuationsEntry('confirmAddMgmtnode', $cdata, SECINDAY, 0, 1, 1);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=\"Confirm Management Node\">\n";
	}
	else {
		$cdata = array('mgmtnodeid' => $data['mgmtnodeid'],
		               'mgmtgroups' => $mgmtnodegroups['managementnode']);
		$cont = addContinuationsEntry('confirmEditMgmtnode', $cdata, SECINDAY, 0, 1, 1);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "      <INPUT type=submit value=\"Confirm Changes\">\n";
	}
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewMgmtnodes');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<div id=helpbox onmouseover=\"blockClear();\" onmouseout=\"clearHelpbox2(0);\"></div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmEditOrAddMgmtnode($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a form for confirming changes to an image
///
////////////////////////////////////////////////////////////////////////////////
function confirmEditOrAddMgmtnode($state) {
	global $submitErr;

	$data = processMgmtnodeInput(1);
	$premodules = getPredictiveModules();

	if($submitErr) {
		editOrAddMgmtnode($state);
		return;
	}

	if($state) {
		$nextmode = "submitAddMgmtnode";
		$title = "Add Management Node";
		$question = "Add the following management node?";
	}
	else {
		$nextmode = "submitEditMgmtnode";
		$title = "Edit Management Node";
		$question = "Submit changes to the management node?";
	}
	$mgmtnodestates = array(2 => "available", 1 => "deleted", 10 => "maintenance");

	print "<DIV align=center>\n";
	print "<H2>$title</H2>\n";
	print "$question<br><br>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname:</TH>\n";
	print "    <TD>{$data["hostname"]}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>IP&nbsp;address:</TH>\n";
	print "    <TD>{$data["IPaddress"]}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>{$data["owner"]}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>State:</TH>\n";
	print "    <TD>{$mgmtnodestates[$data["stateid"]]}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Predictive Loading Module:</TH>\n";
	print "    <TD>{$premodules[$data["premoduleid"]]['prettyname']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Check-in Interval(sec):</TH>\n";
	print "    <TD>{$data["checkininterval"]}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Install Path:</TH>\n";
	print "    <TD>{$data["installpath"]}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>End node SSH Identity Key Files:</TH>\n";
	print "    <TD>{$data["keys"]}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>SSH Port for this node:</TH>\n";
	print "    <TD>{$data["sshport"]}</TD>\n";
	print "  </TR>\n";
	if($data['imagelibenable']) {
		print "  <TR>\n";
		print "    <TH align=right>Image Library:</TH>\n";
		print "    <TD>enabled</TD>\n";
		print "  </TR>\n";
		$mgmtgroups = getContinuationVar('mgmtgroups');
		print "  <TR>\n";
		print "    <TH align=right>Image Library Management Node Group:</TH>\n";
		print "    <TD>{$mgmtgroups[$data["imagelibgroupid"]]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Image Library User:</TH>\n";
		print "    <TD>{$data["imagelibuser"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Image Library SSH Identity Key File:</TH>\n";
		print "    <TD>{$data["imagelibkey"]}</TD>\n";
		print "  </TR>\n";
	}
	else {
		print "  <TR>\n";
		print "    <TH align=right>Image Library:</TH>\n";
		print "    <TD>disabled</TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry($nextmode, $data, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewMgmtnodes');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditMgmtnode()
///
/// \brief submits changes to management node and notifies user
///
////////////////////////////////////////////////////////////////////////////////
function submitEditMgmtnode() {
	$data = processMgmtnodeInput(0);
	updateMgmtnode($data);
	viewMgmtnodes();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddMgmtnode()
///
/// \brief processes form to add the management node
///
////////////////////////////////////////////////////////////////////////////////
function submitAddMgmtnode() {
	$data = processMgmtnodeInput(0);
	addMgmtnode($data);
	clearPrivCache();
	viewMgmtnodes();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteMgmtnode()
///
/// \brief prints a page confirming deletion of a management node
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteMgmtnode() {
	$mgmtnodeid = getContinuationVar("mgmtnodeid");
	$nodes = getManagementNodes();

	print "<DIV align=center>\n";
	print "<H2>Delete Management Node</H2>\n";
	print "Delete the following management node?<br><br>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Hostname:</TH>\n";
	print "    <TD>{$nodes[$mgmtnodeid]['hostname']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>IP address:</TH>\n";
	print "    <TD>{$nodes[$mgmtnodeid]['IPaddress']}</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>{$nodes[$mgmtnodeid]['owner']}</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('mgmtnodeid' => $mgmtnodeid);
	$cont = addContinuationsEntry('submitDeleteMgmtnode', $cdata, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewMgmtnodes');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteMgmtnode()
///
/// \brief deletes a management node and calls viewMgmtnodes
///
////////////////////////////////////////////////////////////////////////////////
function submitDeleteMgmtnode() {
	$mgmtnodeid = getContinuationVar("mgmtnodeid");
	doQuery("DELETE FROM managementnode WHERE id = $mgmtnodeid", 385);
	doQuery("DELETE FROM resource WHERE resourcetypeid = 16 AND subid = $mgmtnodeid", 385);
	$_SESSION['userresources'] = array();
	$_SESSION['usersessiondata'] = array();
	viewMgmtnodes();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewMgmtnodeGrouping()
///
/// \brief prints a page to view and modify management node grouping
///
////////////////////////////////////////////////////////////////////////////////
function viewMgmtnodeGrouping() {
	global $mode;
	$mgmtnodemembership = getResourceGroupMemberships("managementnode");
	$resources = getUserResources(array("mgmtNodeAdmin"), 
	                              array("manageGroup"));
	$tmp = getUserResources(array("mgmtNodeAdmin"), 
	                              array("manageGroup"), 1);
	$mgmtnodegroups = $tmp["managementnode"];
	uasort($mgmtnodegroups, "sortKeepIndex");
	uasort($resources["managementnode"], "sortKeepIndex");
	if(count($resources["managementnode"])) {
		print "<H2>Management Node Grouping</H2>\n";
		if($mode == "submitMgmtnodeGroups") {
			print "<font color=\"#008000\">Management Node groups successfully updated";
			print "</font><br><br>\n";
		}
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "<TABLE border=1>\n";
		print "  <TR>\n";
		print "    <TH rowspan=2>Management Node</TH>\n";
		print "    <TH colspan=" . count($mgmtnodegroups) . ">Groups</TH>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		foreach($mgmtnodegroups as $group) {
			print "    <TH>$group</TH>\n";
		}
		print "  </TR>\n";
		$count = 1;
		foreach($resources["managementnode"] as $mgmtnodeid => $mgmtnode) {
			if($count % 8 == 0) {
				print "  <TR>\n";
				print "    <TH><img src=images/blank.gif></TH>\n";
				foreach($mgmtnodegroups as $group) {
					print "    <TH>$group</TH>\n";
				}
				print "  </TR>\n";
			}
			print "  <TR>\n";
			print "    <TH align=right>$mgmtnode</TH>\n";
			foreach(array_keys($mgmtnodegroups) as $groupid) {
				$name = "mgmtnodegroup[" . $mgmtnodeid . ":" . $groupid . "]";
				if(array_key_exists($mgmtnodeid, $mgmtnodemembership["managementnode"]) &&
					in_array($groupid, $mgmtnodemembership["managementnode"][$mgmtnodeid])) {
					$checked = "checked";
				}
				else {
					$checked = "";
				}
				print "    <TD align=center>\n";
				print "      <INPUT type=checkbox name=\"$name\" $checked>\n";
				print "    </TD>\n";
			}
			print "  </TR>\n";
			$count++;
		}
		print "</TABLE>\n";
		$cont = addContinuationsEntry('submitMgmtnodeGroups', array(), SECINDAY, 1, 0);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=\"Submit Changes\">\n";
		print "<INPUT type=reset value=Reset>\n";
		print "</FORM>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitMgmtnodeGroups
///
/// \brief updates image groupings
///
////////////////////////////////////////////////////////////////////////////////
function submitMgmtnodeGroups() {
	$groupinput = processInputVar("mgmtnodegroup", ARG_MULTINUMERIC);

	$mgmtnodes = getManagementNodes();

	# build an array of memberships currently in the db
	$tmp = getUserResources(array("groupAdmin"), array("manageGroup"), 1);
	$mgmtnodegroupsIDs = array_keys($tmp["managementnode"]);  // ids of groups that user can manage
	$resources = getUserResources(array("mgmtNodeAdmin"), 
	                              array("manageGroup"));
	$userMgmtnodeIDs = array_keys($resources["managementnode"]); // ids of images that user can manage
	$mgmtnodemembership = getResourceGroupMemberships("managementnode");
	$basemgmtnodegroups = $mgmtnodemembership["managementnode"]; // all image group memberships
	$mgmtnodegroups = array();
	foreach(array_keys($basemgmtnodegroups) as $mgmtnodeid) {
		if(in_array($mgmtnodeid, $userMgmtnodeIDs)) {
			foreach($basemgmtnodegroups[$mgmtnodeid] as $grpid) {
				if(in_array($grpid, $mgmtnodegroupsIDs)) {
					if(array_key_exists($mgmtnodeid, $mgmtnodegroups))
						array_push($mgmtnodegroups[$mgmtnodeid], $grpid);
					else
						$mgmtnodegroups[$mgmtnodeid] = array($grpid);
				}
			}
		}
	}

	# build an array of posted in memberships
	$newmembers = array();
	foreach(array_keys($groupinput) as $key) {
		list($mgmtnodeid, $grpid) = explode(':', $key);
		if(array_key_exists($mgmtnodeid, $newmembers)) {
			array_push($newmembers[$mgmtnodeid], $grpid);
		}
		else {
			$newmembers[$mgmtnodeid] = array($grpid);
		}
	}

	$adds = array();
	$removes = array();
	foreach(array_keys($mgmtnodes) as $mgmtnodeid) {
		$id = $mgmtnodes[$mgmtnodeid]["resourceid"];
		// if $mgmtnodeid not in $userMgmtnodeIds, don't bother with it
		if(! in_array($mgmtnodeid, $userMgmtnodeIDs))
			continue;
		// if $mgmtnodeid is not in $newmembers and not in $mgmtnodegroups, do nothing
		if(! array_key_exists($mgmtnodeid, $newmembers) &&
		   ! array_key_exists($mgmtnodeid, $mgmtnodegroups)) {
			continue;
		}
		// check that $mgmtnodeid is in $newmembers, if not, remove it from all groups
		// user has access to
		if(! array_key_exists($mgmtnodeid, $newmembers)) {
			$removes[$id] = $mgmtnodegroups[$mgmtnodeid];
			continue;
		}
		// check that $mgmtnodeid is in $mgmtnodegroups, if not, add all groups in
		// $newmembers
		if(! array_key_exists($mgmtnodeid, $mgmtnodegroups)) {
			$adds[$id] = $newmembers[$mgmtnodeid];
			continue;
		}
		// adds are groupids that are in $newmembers, but not in $mgmtnodegroups
		$adds[$id] = array_diff($newmembers[$mgmtnodeid], $mgmtnodegroups[$mgmtnodeid]);
		if(count($adds[$id]) == 0) {
			unset($adds[$id]); 
		}
		// removes are groupids that are in $mgmtnodegroups, but not in $newmembers
		$removes[$id] = array_diff($mgmtnodegroups[$mgmtnodeid], $newmembers[$mgmtnodeid]);
		if(count($removes[$id]) == 0) {
			unset($removes[$id]);
		}
	}

	foreach(array_keys($adds) as $mgmtnodeid) {
		foreach($adds[$mgmtnodeid] as $grpid) {
			$query = "INSERT INTO resourcegroupmembers "
			       . "(resourceid, resourcegroupid) "
			       . "VALUES ($mgmtnodeid, $grpid)";
			doQuery($query, 287);
		}
	}

	foreach(array_keys($removes) as $mgmtnodeid) {
		foreach($removes[$mgmtnodeid] as $grpid) {
			$query = "DELETE FROM resourcegroupmembers "
			       . "WHERE resourceid = $mgmtnodeid AND "
			       .       "resourcegroupid = $grpid";
			doQuery($query, 288);
		}
	}

	viewMgmtnodeGrouping();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewMgmtnodeMapping($mngroups)
///
/// \param $mngroups - (optional) array of mngroups as returned by
/// getUserResources
///
/// \brief prints a page to view and edit management node to computer group
/// mappings
///
////////////////////////////////////////////////////////////////////////////////
function viewMgmtnodeMapping($mngroups=0) {
	global $mode;
	if(! is_array($mngroups)) {
		$tmp = getUserResources(array("mgmtNodeAdmin"), 
	                           array("manageGroup"), 1);
		$mngroups = $tmp["managementnode"];
	}
	$mapping = getResourceMapping("managementnode", "computer");
	$resources2 = getUserResources(array("computerAdmin"),
	                               array("manageGroup"), 1);
	$compgroups = $resources2["computer"];
	uasort($compgroups, "sortKeepIndex");

	if(count($mngroups) && count($compgroups)) {
		print "<H2>Management Node Group to Computer Group Mapping</H2>\n";
		if($mode == "submitMgmtnodeMapping") {
			print "<font color=\"#008000\">Management node group to computer ";
			print "group mapping successfully updated";
			print "</font><br><br>\n";
		}
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "<TABLE border=1>\n";
		print "  <col>\n";
		foreach(array_keys($compgroups) as $id) {
			print "  <col id=compgrp$id>\n";
		}
		print "  <TR>\n";
		print "    <TH rowspan=2>Management Node Group</TH>\n";
		print "    <TH class=nohlcol colspan=" . count($compgroups) . ">Computer Groups</TH>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		foreach($compgroups as $id => $group) {
			print "    <TH onclick=\"toggleColSelect('compgrp$id');\">$group</TH>\n";
		}
		print "  </TR>\n";
		$count = 1;
		foreach($mngroups as $mnid => $mnname) {
			if($count % 12 == 0) {
				print "  <TR>\n";
				print "    <TH><img src=images/blank.gif></TH>\n";
				foreach($compgroups as $id => $group) {
					print "    <TH onclick=\"toggleColSelect('compgrp$id');\">$group</TH>\n";
				}
				print "  </TR>\n";
			}
			print "  <TR id=mngrpid$mnid>\n";
			print "    <TH align=right onclick=\"toggleRowSelect('mngrpid$mnid');\">$mnname</TH>\n";
			foreach($compgroups as $compid => $compname) {
				$name = "mapping[" . $mnid . ":" . $compid . "]";
				if(array_key_exists($mnid, $mapping) &&
					in_array($compid, $mapping[$mnid])) {
					$checked = "checked";
				}
				else
					$checked = "";
				print "    <TD align=center>\n";
				print "      <INPUT type=checkbox name=\"$name\" $checked>\n";
				print "    </TD>\n";
			}
			print "  </TR>\n";
			$count++;
		}
		print "</TABLE>\n";
		$cont = addContinuationsEntry('submitMgmtnodeMapping', array(), SECINDAY, 1, 0);
		print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=\"Submit Changes\">\n";
		print "<INPUT type=reset value=Reset>\n";
		print "</FORM>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitMgmtnodeMapping
///
/// \brief updates management node group to computer group mapping
///
////////////////////////////////////////////////////////////////////////////////
function submitMgmtnodeMapping() {
	$mapinput = processInputVar("mapping", ARG_MULTINUMERIC);
	$mntypeid = getResourceTypeID("managementnode");
	$comptypeid = getResourceTypeID("computer");

	# build an array of memberships currently in the db
	$tmp = getUserResources(array("mgmtNodeAdmin"),
	                        array("manageGroup"), 1);
	$mngroups = $tmp["managementnode"];
	$tmp = getUserResources(array("computerAdmin"),
	                        array("manageGroup"), 1);
	$compgroups = $tmp["computer"];
	$mninlist = implode(',', array_keys($mngroups));
	$compinlist = implode(',', array_keys($compgroups));
	$mapping = getResourceMapping("managementnode", "computer", $mninlist, 
	                              $compinlist);

	# build an array of posted in memberships
	$newmembers = array();
	foreach(array_keys($mapinput) as $key) {
		list($mnid, $compid) = explode(':', $key);
		if(array_key_exists($mnid, $newmembers))
			array_push($newmembers[$mnid], $compid);
		else
			$newmembers[$mnid] = array($compid);
	}

	$adds = array();
	$removes = array();
	foreach(array_keys($mngroups) as $mnid) {
		// if $mnid is not in $newmembers and not in $mapping, do nothing
		if(! array_key_exists($mnid, $newmembers) &&
		   ! array_key_exists($mnid, $mapping)) {
			continue;
		}
		// check that $mnid is in $newmembers, if not, remove it from all groups
		// user has access to
		if(! array_key_exists($mnid, $newmembers)) {
			$removes[$mnid] = $mapping[$mnid];
			continue;
		}
		// check that $mnid is in $mapping, if not, add all groups in
		// $newmembers
		if(! array_key_exists($mnid, $mapping)) {
			$adds[$mnid] = $newmembers[$mnid];
			continue;
		}
		// adds are groupids that are in $newmembers, but not in $mapping
		$adds[$mnid] = array_diff($newmembers[$mnid], $mapping[$mnid]);
		if(count($adds[$mnid]) == 0) {
			unset($adds[$mnid]); 
		}
		// removes are groupids that are in $mapping, but not in $newmembers
		$removes[$mnid] = array_diff($mapping[$mnid], $newmembers[$mnid]);
		if(count($removes[$mnid]) == 0) {
			unset($removes[$mnid]);
		}
	}

	foreach(array_keys($adds) as $mnid) {
		foreach($adds[$mnid] as $compid) {
			$query = "INSERT INTO resourcemap "
			       .             "(resourcegroupid1, "
			       .             "resourcetypeid1, "
			       .             "resourcegroupid2, "
			       .             "resourcetypeid2) "
			       . "VALUES ($mnid, "
			       .        "$mntypeid, "
			       .        "$compid, "
			       .        "$comptypeid)";
			doQuery($query, 101);
		}
	}

	foreach(array_keys($removes) as $mnid) {
		foreach($removes[$mnid] as $compid) {
			$query = "DELETE FROM resourcemap "
			       . "WHERE resourcegroupid1 = $mnid AND "
			       .       "resourcetypeid1 = $mntypeid AND "
			       .       "resourcegroupid2 = $compid AND "
			       .       "resourcetypeid2 = $comptypeid";
			doQuery($query, 101);
		}
	}

	viewMgmtnodeMapping();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateMgmtnode($data)
///
/// \param $data - an array returned from processMgmtnodeInput
///
/// \return number of rows affected by the update\n
/// \b NOTE: mysql reports that no rows were affected if none of the fields
/// were actually changed even if the update matched a row
///
/// \brief performs a query to update the management node with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function updateMgmtnode($data) {
	$ownerid = getUserlistID($data["owner"]);
	$data['installpath'] = mysql_escape_string($data['installpath']);
	$data['keys'] = mysql_escape_string($data['keys']);
	$data['imagelibuser'] = mysql_escape_string($data['imagelibuser']);
	if($data['imagelibuser'] != 'NULL')
		$data['imagelibuser'] = "'{$data['imagelibuser']}'";
	$data['imagelibkey'] = mysql_escape_string($data['imagelibkey']);
	if($data['imagelibkey'] != 'NULL')
		$data['imagelibkey'] = "'{$data['imagelibkey']}'";
	if($data['imagelibenable'] != 1)
		$data['imagelibenable'] = 0;
	if($data['keys'] == '')
		$data['keys'] = 'NULL';
	else
		$data['keys'] = "'{$data['keys']}'";
	$query = "UPDATE managementnode "
	       . "SET hostname = '{$data["hostname"]}', "
	       .     "IPaddress = '{$data["IPaddress"]}', "
	       .     "ownerid = $ownerid, "
	       .     "stateid = {$data["stateid"]}, "
	       .     "predictivemoduleid = {$data["premoduleid"]}, "
	       .     "checkininterval = {$data["checkininterval"]}, "
	       .     "installpath = '{$data["installpath"]}', "
	       .     "`keys` = {$data["keys"]}, "
	       .     "sshport = {$data["sshport"]}, "
	       .     "imagelibenable = {$data["imagelibenable"]}, "
	       .     "imagelibgroupid = {$data["imagelibgroupid"]}, "
	       .     "imagelibuser = {$data["imagelibuser"]}, "
	       .     "imagelibkey = {$data["imagelibkey"]} "
	       . "WHERE id = " . $data["mgmtnodeid"];
	$qh = doQuery($query, 101);
	return mysql_affected_rows($GLOBALS["mysql_link_vcl"]);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addMgmtnode($data)
///
/// \param $data - an array returned from processMgmtnodeInput
///
/// \return number of rows affected by the insert\n
///
/// \brief performs a query to insert the management node with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function addMgmtnode($data) {
	$ownerid = getUserlistID($data["owner"]);
	$data['installpath'] = mysql_escape_string($data['installpath']);
	$data['keys'] = mysql_escape_string($data['keys']);
	$data['imagelibuser'] = mysql_escape_string($data['imagelibuser']);
	if($data['imagelibuser'] != 'NULL')
		$data['imagelibuser'] = "'{$data['imagelibuser']}'";
	$data['imagelibkey'] = mysql_escape_string($data['imagelibkey']);
	if($data['imagelibkey'] != 'NULL')
		$data['imagelibkey'] = "'{$data['imagelibkey']}'";
	if($data['imagelibenable'] != 1)
		$data['imagelibenable'] = 0;
	if($data['keys'] == '')
		$data['keys'] = 'NULL';
	else
		$data['keys'] = "'{$data['keys']}'";
	$query = "INSERT INTO managementnode "
	       .         "(hostname, "
	       .         "IPaddress, "
	       .         "ownerid, "
	       .         "stateid, "
	       .         "checkininterval, "
	       .         "installpath, "
	       .         "imagelibenable, "
	       .         "imagelibgroupid, "
	       .         "imagelibuser, "
	       .         "imagelibkey, "
	       .         "`keys`, "
	       .         "predictivemoduleid, "
	       .         "sshport) "
	       . "VALUES ('{$data["hostname"]}', "
	       .         "'{$data["IPaddress"]}', "
	       .         "$ownerid, "
	       .         "{$data["stateid"]}, "
	       .         "{$data["checkininterval"]}, "
	       .         "'{$data["installpath"]}', "
	       .         "{$data["imagelibenable"]}, "
	       .         "{$data["imagelibgroupid"]}, "
	       .         "{$data["imagelibuser"]}, "
	       .         "{$data["imagelibkey"]}, "
	       .         "{$data["keys"]}, "
	       .         "{$data["premoduleid"]}, "
	       .         "{$data["sshport"]}) ";
	doQuery($query, 205);

	// get last insert id
	$qh = doQuery("SELECT LAST_INSERT_ID() FROM managementnode", 101);
	if(! $row = mysql_fetch_row($qh)) {
		abort(101);
	}
	$id = $row[0];

	// add entry in resource table
	$query = "INSERT INTO resource "
	       .        "(resourcetypeid, "
	       .        "subid) "
	       . "VALUES (16, "
	       .         "$id)";
	doQuery($query, 209);

	return $id;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processMgmtnodeInput($checks)
///
/// \param $checks - (optional) 1 to perform validation, 0 not to
///
/// \return an array with the following indexes:\n
/// mgmtnodeid, hostname, IPaddress, owner, stateid
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processMgmtnodeInput($checks=1) {
	global $submitErr, $submitErrMsg, $user, $mode;
	$return = array();
	$mgmtnodes = getManagementNodes();
	$return["mgmtnodeid"] = getContinuationVar("mgmtnodeid");
	$return["hostname"] = getContinuationVar("hostname", processInputVar("hostname" , ARG_STRING));
	$return["IPaddress"] = getContinuationVar("IPaddress", processInputVar("IPaddress", ARG_STRING));
	$return["owner"] = getContinuationVar("owner", processInputVar("owner", ARG_STRING, $user["unityid"]));
	$return["stateid"] = getContinuationVar("stateid", processInputVar("stateid", ARG_STRING));
	$return["premoduleid"] = getContinuationVar("premoduleid", processInputVar("premoduleid", ARG_NUMERIC));

	$return["checkininterval"] = getContinuationVar("checkininterval", processInputVar("checkininterval", ARG_NUMERIC));
	$return["installpath"] = getContinuationVar("installpath", processInputVar("installpath", ARG_STRING));
	$return["keys"] = getContinuationVar("keys", processInputVar("keys", ARG_STRING));
	$return["sshport"] = getContinuationVar("sshport", processInputVar("sshport", ARG_NUMERIC));
	$return["imagelibenable"] = getContinuationVar("imagelibenable", processInputVar("imagelibenable", ARG_NUMERIC));
	$return["imagelibgroupid"] = getContinuationVar("imagelibgroupid", processInputVar("imagelibgroupid", ARG_NUMERIC));
	$return["imagelibuser"] = getContinuationVar("imagelibuser", processInputVar("imagelibuser", ARG_STRING));
	$return["imagelibkey"] = getContinuationVar("imagelibkey", processInputVar("imagelibkey", ARG_STRING));

	if($return['checkininterval'] < 5)
		$return['checkininterval'] = 5;
	if($return['checkininterval'] > 30)
		$return['checkininterval'] = 30;
	if($return['sshport'] < 1 || $return['sshport'] > 65535)
		$return['sshport'] = 22;
	if($return['imagelibenable'] != '' && $return['imagelibenable'] != 1)
		$return['imagelibenable'] = '';
	if($return['imagelibenable'] != 1) {
		$return["imagelibgroupid"] = 'NULL';
		$return["imagelibuser"] = 'NULL';
		$return["imagelibkey"] = 'NULL';
	}

	if(! $checks)
		return $return;
	
	if(! ereg('^[a-zA-Z0-9_][-a-zA-Z0-9_\.]{1,49}$', $return["hostname"])) {
	   $submitErr |= MNHOSTNAMEERR;
	   $submitErrMsg[MNHOSTNAMEERR] = "Hostname can only contain letters, numbers, dashes(-), periods(.), and underscores(_). It can be from 1 to 50 characters long";
	}
	if(! ($submitErr & MNHOSTNAMEERR) &&
	   $mode != "confirmEditMgmtnode" &&
	   checkForMgmtnodeHostname($return["hostname"])) {
		$submitErr |= MNHOSTNAMEERR;
		$submitErrMsg[MNHOSTNAMEERR] = "A node already exists with this hostname.";
	}
	$ipaddrArr = explode('.', $return["IPaddress"]);
	if(! ereg('^(([0-9]){1,3}\.){3}([0-9]){1,3}$', $return["IPaddress"]) ||
	   $ipaddrArr[0] < 1 || $ipaddrArr[0] > 255 ||
	   $ipaddrArr[1] < 0 || $ipaddrArr[1] > 255 ||
	   $ipaddrArr[2] < 0 || $ipaddrArr[2] > 255 ||
	   $ipaddrArr[3] < 1 || $ipaddrArr[3] > 255) {
		$submitErr |= IPADDRESSERR;
	   $submitErrMsg[IPADDRESSERR] = "Invalid IP address. Must be w.x.y.z with each of "
		                             . "w, x, y, and z being between 1 and 255 (inclusive)";
	}
	if($mode != "confirmEditMgmtnode" &&
	   ! ($submitErr & IPADDRESSERR) &&
	   checkForMgmtnodeIPaddress($return["IPaddress"])) {
		$submitErr |= IPADDRESSERR;
		$submitErrMsg[IPADDRESSERR] = "A node already exists with this IP address.";
	}
	if(! validateUserid($return["owner"])) {
		$submitErr |= MNOWNERERR;
		$submitErrMsg[MNOWNERERR] = "Submitted ID is not valid";
	}

	if(! preg_match('/^([-a-zA-Z0-9_\.\/]){2,100}$/', $return["installpath"])) {
	   $submitErr |= MNINSTPATHERR;
	   $submitErrMsg[MNINSTPATHERR] = "This can only contain letters, numbers, dashes(-), periods(.), underscores(_), and forward slashes(/). It can be from 2 to 100 characters long";
	}
	if(! empty($return['keys']) && ! preg_match('/^([-a-zA-Z0-9_\.\/,]){2,1024}$/', $return["keys"])) {
	   $submitErr |= MNSSHIDKEYSERR;
	   $submitErrMsg[MNSSHIDKEYSERR] = "This can only contain letters, numbers, dashes(-), periods(.), underscores(_), forward slashes(/), and commas(,). It can be from 2 to 1024 characters long";
	}

	if($return['imagelibenable'] == 1) {
		$validgroups = getUserResources(array('mgmtNodeAdmin'), array("manageGroup"), 1);
		if(! in_array($return['imagelibgroupid'], array_keys($validgroups['managementnode']))) {
			$submitErr |= MNIMGLIBGRPIDERR;
			$submitErrMsg[MNIMGLIBGRPIDERR] = "The selected group was invalid";
		}
		if(! preg_match('/^([-a-zA-Z0-9_\.\/,]){2,20}$/', $return["imagelibuser"])) {
			$submitErr |= MNIMGLIBUSERERR;
			$submitErrMsg[MNIMGLIBUSERERR] = "This can only contain letters, numbers, and dashes(-) and can be from 2 to 20 characters long";
		}
		if(! preg_match('/^([-a-zA-Z0-9_\.\/,]){2,100}$/', $return["imagelibkey"])) {
			$submitErr |= MNIMGLIBKEYERR;
			$submitErrMsg[MNIMGLIBKEYERR] = "This can only contain letters, numbers, dashes(-), periods(.), underscores(_), and forward slashes(/). It can be from 2 to 100 characters long";
		}
	}
	else {
		$return["imagelibgroupid"] = 'NULL';
		$return["imagelibuser"] = 'NULL';
		$return["imagelibkey"] = 'NULL';
	}

	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForMgmtnodeHostname($hostname)
///
/// \param $hostname - a computer hostname
///
/// \return 0 if $hostname is not in managementnode table, 1 if it is
///
/// \brief checks for the existance of $hostname in the managementnode table
///
////////////////////////////////////////////////////////////////////////////////
function checkForMgmtnodeHostname($hostname) {
	$query = "SELECT id FROM managementnode WHERE hostname = '$hostname'";
	$qh = doQuery($query, 101);
	return mysql_num_rows($qh);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForMgmtnodeIPaddress($addr)
///
/// \param $addr - a computer ip address
///
/// \return 0 if $addr is not in managementnode table, 1 if it is
///
/// \brief checks for the existance of $addr in the managementnode table
///
////////////////////////////////////////////////////////////////////////////////
function checkForMgmtnodeIPaddress($addr) {
	$query = "SELECT id FROM managementnode WHERE IPaddress = '$addr'";
	$qh = doQuery($query, 101);
	return mysql_num_rows($qh);
}

?>
