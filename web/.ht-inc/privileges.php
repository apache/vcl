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

/// signifies an error with the submitted new node name
define("NEWNODENAMEERR", 1);
/// signifies an error with the submitted new user id
define("NEWUSERERR", 1);
/// signifies no privs were submitted with the new user
define("ADDUSERNOPRIVS", 1 << 1);

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewNodes()
///
/// \brief prints a node privilege tree and the privliges at the node
///
////////////////////////////////////////////////////////////////////////////////
function viewNodes() {
	global $user;
	# FIXME change activeNode if current one has been deleted
	$mode = processInputVar("mode", ARG_STRING);
	$tmp = processInputVar("openNodes", ARG_STRING);
	if($tmp != "")
		$openNodes = explode(":", $tmp);
	else {
		if(! empty($_COOKIE["VCLNODES"]))
			$openNodes = explode(":", $_COOKIE["VCLNODES"]);
		else
			$openNodes = array(DEFAULT_PRIVNODE);
	}
	$topNodes = getChildNodes();
	if(count($topNodes)) {
		$keys = array_keys($topNodes);
		$defaultActive = array_shift($keys);
	}
	$activeNode = processInputVar("activeNode", ARG_NUMERIC);
	if(empty($activeNode))
		if(! empty($_COOKIE["VCLACTIVENODE"]) &&
		   nodeExists($_COOKIE['VCLACTIVENODE']))
			$activeNode = $_COOKIE["VCLACTIVENODE"];
		else
			$activeNode = $defaultActive;

	$hasNodeAdmin = checkUserHasPriv("nodeAdmin", $user["id"], $activeNode);

	# tree
	print "<H2>Privilege Tree</H2>\n";
	/*if($mode == "submitAddChildNode") {
		print "<font color=\"#008000\">Node successfully added to tree";
		print "</font><br><br>\n";
	}
	if($mode == "submitDeleteNode") {
		print "<font color=\"#008000\">Nodes successfully deleted from tree";
		print "</font><br><br>\n";
	}*/
	print "<dojo:TreeSelector widgetId=treeSelector eventNames=select:nodeSelected></dojo:TreeSelector>\n";
	#print "<dojo:TreeRPCController RPCUrl=local widgetId=treeController></dojo:TreeRPCController>\n";
	print "<div dojoType=Tree widgetId=privTree selector=treeSelector>\n";
	recursivePrintNodes2($topNodes, $openNodes, $activeNode);
	print "</div>\n";

	print "<div id=treebuttons>\n";
	if($hasNodeAdmin) {
		$openNodes = implode(":", $openNodes);
		print "<TABLE>\n";
		print "  <TR valign=top>\n";
		print "    <TD><FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "    <button id=addNodeBtn dojoType=Button ";
		print "onClick=\"showAddNodePane(); return false;\">";
		print "Add Child</button>\n";
		print "    </FORM></TD>\n";
		print "    <TD><FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		print "    <button id=deleteNodeBtn dojoType=Button onClick=\"dojo.widget.byId('deleteDialog').show();\">";
		print "Delete Node and Children</button>\n";
		print "    </FORM></TD>\n";
		print "  </TR>\n";
		print "</TABLE>\n";
	}
	print "</div>\n";
	$cont = addContinuationsEntry('selectNode');
	print "<INPUT type=hidden id=nodecont value=\"$cont\">\n";

	# privileges
	print "<H2>Privileges at Selected Node</H2>\n";
	$node = $activeNode;
	if($openNodes == "")
		$openNodes = DEFAULT_PRIVNODE;

	$nodeInfo = getNodeInfo($node);
	$privs = getNodePrivileges($node);
	$cascadePrivs = getNodeCascadePrivileges($node);
	$usertypes = getTypes("users");
	$i = 0;
	$hasUserGrant = checkUserHasPriv("userGrant", $user["id"], $node,
	                                 $privs, $cascadePrivs);
	$hasResourceGrant = checkUserHasPriv("resourceGrant", $user["id"],
	                                     $node, $privs, $cascadePrivs);
	
	print "<div id=nodePerms>\n";

	# users
	print "<A name=\"users\"></a>\n";
	print "<div id=usersDiv>\n";
	print "<H3>Users</H3>\n";
	print "<FORM id=usersform action=\"" . BASEURL . SCRIPT . "#users\" method=post>\n";
	$users = array();
	if(count($privs["users"]) || count($cascadePrivs["users"])) {
		print "<TABLE border=1 summary=\"\">\n";
		print "  <TR>\n";
		print "    <TD></TD>\n";
		print "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
		print "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
		foreach($usertypes["users"] as $type) {
			$img = getImageText($type);
			print "    <TD>$img</TD>\n";
		}
		print "  </TR>\n";
		$users = array_unique(array_merge(array_keys($privs["users"]), 
		                      array_keys($cascadePrivs["users"])));
		sort($users);
		foreach($users as $_user) {
			printUserPrivRow($_user, $i, $privs["users"], $usertypes["users"],
			                 $cascadePrivs["users"], 'user', ! $hasUserGrant);
			$i++;
		}
		print "</TABLE>\n";
		print "<div id=lastUserNum class=hidden>" . ($i - 1) . "</div>\n";
		if($hasUserGrant) {
			$cont = addContinuationsEntry('AJchangeUserPrivs');
			print "<INPUT type=hidden id=changeuserprivcont value=\"$cont\">\n";
		}
	}
	else {
		print "There are no user privileges at the selected node.<br>\n";
	}
	if($hasUserGrant) {
		print "<BUTTON id=addUserBtn dojoType=Button onclick=\"showAddUserPane(); return false;\">";
		print "Add User</button>\n";
	}
	print "</FORM>\n";
	print "</div>\n";

	# groups
	print "<A name=\"groups\"></a>\n";
	print "<div id=usergroupsDiv>\n";
	print "<H3>User Groups</H3>\n";
	if(count($privs["usergroups"]) || count($cascadePrivs["usergroups"])) {
		print "<FORM action=\"" . BASEURL . SCRIPT . "#groups\" method=post>\n";
		print "<div id=firstUserGroupNum class=hidden>$i</div>";
		print "<TABLE border=1 summary=\"\">\n";
		print "  <TR>\n";
		print "    <TD></TD>\n";
		print "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
		#$img = getImageText("Block Cascaded Rights");
		#print "    <TD>$img</TD>\n";
		print "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
		#$img = getImageText("Cascade to Child Nodes");
		#print "    <TD>$img</TD>\n";
		foreach($usertypes["users"] as $type) {
			$img = getImageText($type);
			print "    <TH>$img</TH>\n";
		}
		print "  </TR>\n";
		$groups = array_unique(array_merge(array_keys($privs["usergroups"]), 
		                      array_keys($cascadePrivs["usergroups"])));
		sort($groups);
		foreach($groups as $group) {
			printUserPrivRow($group, $i, $privs["usergroups"], $usertypes["users"],
			                $cascadePrivs["usergroups"], 'group', ! $hasUserGrant);
			$i++;
		}
		print "</TABLE>\n";
		print "<div id=lastUserGroupNum class=hidden>" . ($i - 1) . "</div>";
		if($hasUserGrant) {
			$cont = addContinuationsEntry('AJchangeUserGroupPrivs');
			print "<INPUT type=hidden id=changeusergroupprivcont value=\"$cont\">\n";
		}
	}
	else {
		print "There are no user group privileges at the selected node.<br>\n";
		$groups = array();
	}
	if($hasUserGrant) {
		print "<BUTTON id=addGroupBtn dojoType=Button onclick=\"showAddUserGroupPane(); return false;\">";
		print "Add Group</button>\n";
	}
	print "</FORM>\n";
	print "</div>\n";

	# resources
	$resourcetypes = array("available", "administer", "manageGroup");
	print "<A name=\"resources\"></a>\n";
	print "<div id=resourcesDiv>\n";
	print "<H3>Resources</H3>\n";
	print "<FORM id=resourceForm action=\"" . BASEURL . SCRIPT . "#resources\" method=post>\n";
	if(count($privs["resources"]) || count($cascadePrivs["resources"])) {
		print "<TABLE border=1 summary=\"\">\n";
		print "  <TR>\n";
		print "    <TH>Group<br>Name</TH>\n";
		print "    <TH>Group<br>Type</TH>\n";
		print "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
		print "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
		foreach($resourcetypes as $type) {
			$img = getImageText("$type");
			print "    <TH>$img</TH>\n";
		}
		print "  </TR>\n";
		$resources = array_unique(array_merge(array_keys($privs["resources"]), 
		                          array_keys($cascadePrivs["resources"])));
		sort($resources);
		$resourcegroups = getResourceGroups();
		$resgroupmembers = getResourceGroupMembers();
		foreach($resources as $resource) {
			printResourcePrivRow($resource, $i, $privs["resources"], $resourcetypes,
			                     $resourcegroups, $resgroupmembers,
			                     $cascadePrivs["resources"], ! $hasResourceGrant);
			$i++;
		}
		print "</TABLE>\n";
		if($hasResourceGrant) {
			$cont = addContinuationsEntry('AJchangeResourcePrivs');
			print "<INPUT type=hidden id=changeresourceprivcont value=\"$cont\">\n";
		}
	}
	else {
		print "There are no resource group privileges at the selected node.<br>\n";
		$resources = array();
	}
	if($hasResourceGrant) {
		print "<BUTTON id=addResourceBtn dojoType=Button onclick=\"showAddResourceGroupPane(); return false;\">";
		print "Add Resource Group</button>\n";
	}
	print "</FORM>\n";
	print "</div>\n";
	print "</div>\n";

	print "<div dojoType=FloatingPane\n";
	print "      id=addUserPane\n";
	print "      title=\"Add User Permission\"\n";
	print "      constrainToContainer=false\n";
	print "      hasShadow=true\n";
	print "      resizable=true\n";
	print "      style=\"width: 520px; height: 410px; position: absolute; left: 15; top: 250px; display: none\"\n";
	print ">\n";
	print "<H2>Add User</H2>\n";
	print "<div id=addPaneNodeName></div>\n";
	print "<TABLE border=1 summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
	print "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
	foreach($usertypes["users"] as $type) {
		$img = getImageText($type);
		print "    <TD>$img</TD>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD><INPUT type=text id=newuser name=newuser size=15";
	print "></TD>\n";

	# block rights
	$count = count($usertypes) + 1;
	print "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	print "dojoType=Checkbox id=blockchk name=block></TD>\n";

	#cascade rights
	print "    <TD align=center bgcolor=\"#008000\" id=usercell0:0>";
	print "<INPUT type=checkbox dojoType=Checkbox id=userck0:0 name=cascade ";
	print "></TD>\n";

	# normal rights
	$j = 1;
	foreach($usertypes["users"] as $type) {
		print "    <TD align=center id=usercell0:$j><INPUT type=checkbox ";
		print "dojoType=Checkbox name=\"$type\" id=userck0:$j></TD>\n";
		$j++;
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<div id=addUserPrivStatus></div>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD><button id=submitAddUserBtn dojoType=Button onclick=\"submitAddUser();\">";
	print "Submit New User</button></TD>\n";
	print "<TD><button id=cancelAddUserBtn dojoType=Button onclick=\"addUserPaneHide();\">";
	print "Cancel</button></TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitAddUserPriv');
	print "<INPUT type=hidden id=addusercont value=\"$cont\">\n";
	print "</div>\n";

	print "<div dojoType=FloatingPane\n";
	print "      id=addUserGroupPane\n";
	print "      title=\"Add User Group Permission\"\n";
	print "      constrainToContainer=false\n";
	print "      hasShadow=true\n";
	print "      resizable=true\n";
	print "      style=\"width: 520px; height: 410px; position: absolute; left: 15; top: 450px; display: none\"\n";
	print ">\n";
	print "<H2>Add User Group</H2>\n";
	print "<div id=addGroupPaneNodeName></div>\n";
	print "<TABLE border=1 summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
	print "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
	foreach($usertypes["users"] as $type) {
		$img = getImageText($type);
		print "    <TD>$img</TD>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	# FIXME should $groups be only the user's groups?
	$groups = getUserGroups(0, $user['affiliationid']);
	if(array_key_exists(82, $groups))
		unset($groups[82]); # remove None group
	printSelectInput("newgroupid", $groups, -1, 0, 0, 'newgroupid');
	print "    </TD>\n";

	# block rights
	print "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	print "dojoType=Checkbox id=blockgrpchk name=blockgrp></TD>\n";

	#cascade rights
	print "    <TD align=center bgcolor=\"#008000\" id=grpcell0:0>";
	print "<INPUT type=checkbox dojoType=Checkbox id=usergrpck0:0 ";
	print "name=cascadegrp></TD>\n";

	# normal rights
	$j = 1;
	foreach($usertypes["users"] as $type) {
		print "    <TD align=center id=usergrpcell0:$j><INPUT type=checkbox ";
		print "dojoType=Checkbox name=\"$type\" id=usergrpck0:$j></TD>\n";
		$j++;
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<div id=addUserGroupPrivStatus></div>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD><button id=submitAddGroupBtn dojoType=Button onclick=\"submitAddUserGroup();\">";
	print "Submit New User Group</button></TD>\n";
	print "<TD><button id=cancelAddGroupBtn dojoType=Button onclick=\"addUserGroupPaneHide();\">";
	print "Cancel</button></TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitAddUserGroupPriv');
	print "<INPUT type=hidden id=addusergroupcont value=\"$cont\">\n";
	print "</div>\n";

	print "<div dojoType=FloatingPane\n";
	print "      id=addResourceGroupPane\n";
	print "      title=\"Add Resource Group Permission\"\n";
	print "      constrainToContainer=false\n";
	print "      hasShadow=true\n";
	print "      resizable=true\n";
	print "      style=\"width: 520px; height: 410px; position: absolute; left: 15; top: 450px; display: none\"\n";
	print ">\n";
	print "<H2>Add Resource Group</H2>\n";
	print "<div id=addResourceGroupPaneNodeName></div>\n";
	print "<TABLE border=1 summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
	print "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
	$resourcetypes = array("available", "administer", "manageGroup");
	foreach($resourcetypes as $type) {
		$img = getImageText("$type");
		print "    <TH>$img</TH>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	$resources = array();
	$privs = array("computerAdmin","mgmtNodeAdmin",  "imageAdmin", "scheduleAdmin");
	$resourcesgroups = getUserResources($privs, array("manageGroup"), 1);
	foreach(array_keys($resourcesgroups) as $type) {
		foreach($resourcesgroups[$type] as $id => $group) {
			$resources[$id] = $type . "/" . $group;
		}
	}
	printSelectInput("newresourcegroupid", $resources, -1, 0, 0, 'newresourcegroupid');
	print "    </TD>\n";

	# block rights
	print "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	print "dojoType=Checkbox id=blockresgrpck name=blockresgrp></TD>\n";

	#cascade rights
	print "    <TD align=center bgcolor=\"#008000\" id=resgrpcell0:0>";
	print "<INPUT type=checkbox dojoType=Checkbox id=resgrpck0:0 ";
	print "name=cascaderesgrp></TD>\n";

	# normal rights
	print "    <TD align=center id=resgrpcell0:1><INPUT type=checkbox ";
	print "dojoType=Checkbox name=available id=resgrpck0:1></TD>\n";
	print "    <TD align=center id=resgrpcell0:2><INPUT type=checkbox ";
	print "dojoType=Checkbox name=administer id=resgrpck0:2></TD>\n";
	print "    <TD align=center id=resgrpcell0:3><INPUT type=checkbox ";
	print "dojoType=Checkbox name=manageGroup id=resgrpck0:3></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<div id=addResourceGroupPrivStatus></div>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD><button dojoType=Button onclick=\"submitAddResourceGroup();\">";
	print "Submit New Resource Group</button></TD>\n";
	print "<TD><button dojoType=Button onclick=\"addResourceGroupPaneHide();\">";
	print "Cancel</button></TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitAddResourcePriv');
	print "<INPUT type=hidden id=addresourcegroupcont value=\"$cont\">\n";
	print "</div>\n";

	print "<div dojoType=FloatingPane\n";
	print "      id=addNodePane\n";
	print "      title=\"Add Child Node\"\n";
	print "      constrainToContainer=false\n";
	print "      hasShadow=true\n";
	print "      resizable=true\n";
	print "      style=\"width: 280px; height: 200px; position: absolute; left: 15; top: 150px; display: none\"\n";
	print ">\n";
	print "<H2>Add Child Node</H2>\n";
	print "<div id=addChildNodeName></div>\n";
	print "<strong>New Node:</strong> <INPUT type=text id=childNodeName>\n";
	print "<div id=addChildNodeStatus></div>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD><button id=submitAddNodeBtn dojoType=Button onclick=\"submitAddChildNode();\">";
	print "Create Child</button></TD>\n";
	print "<TD><button id=cancelAddNodeBtn dojoType=Button onclick=\"addNodePaneHide();\">";
	print "Cancel</button></TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitAddChildNode');
	print "<INPUT type=hidden id=addchildcont value=\"$cont\"\n>";
	print "</div>\n";

	print "<div dojoType=dialog id=deleteDialog bgColor=white bgOpacity=0.5 toggle=fade toggleDuration=250>\n";
	print "Delete the following node and all of its children?<br><br>\n";
	print "<div id=deleteNodeName></div><br>\n";
	print "<div align=center>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD><button id=submitDeleteNodeBtn dojoType=Button onClick=\"deleteNode();\">";
	print "Delete Nodes</button></TD>\n";
	print "<TD><button id=cancelDeleteNodeBtn dojoType=Button ";
	print "onClick=\"dojo.widget.byId('deleteDialog').hide();\">Cancel</button>";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitDeleteNode');
	print "<INPUT type=hidden id=delchildcont value=\"$cont\"\n>";
	print "</div>\n";
	print "</div>\n";

	print "<div dojoType=dialog id=workingDialog bgColor=white bgOpacity=0.5 toggle=fade toggleDuration=250>\n";
	print "Loading...\n";
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectNode()
///
/// \brief generates html for ajax update to privileges page when a node is
/// clicked
///
////////////////////////////////////////////////////////////////////////////////
function selectNode() {
	global $user;
	$node = processInputVar("node", ARG_NUMERIC);
	if(! empty($_COOKIE["VCLNODES"]))
		$openNodes = $_COOKIE["VCLNODES"];
	else
		$openNodes = DEFAULT_PRIVNODE;
	if(empty($node)) {
		dbDisconnect();
		exit;
	}
	$return = "";
	$text = "";
	$js = "";
	$privs = getNodePrivileges($node);
	$cascadePrivs = getNodeCascadePrivileges($node);
	$usertypes = getTypes("users");
	$i = 0;
	$hasUserGrant = checkUserHasPriv("userGrant", $user["id"], $node,
	                                 $privs, $cascadePrivs);
	$hasResourceGrant = checkUserHasPriv("resourceGrant", $user["id"],
	                                     $node, $privs, $cascadePrivs);
	$hasNodeAdmin = checkUserHasPriv("nodeAdmin", $user["id"], $node, $privs,
	                                 $cascadePrivs);

	if($hasNodeAdmin) {
		$text .= "<TABLE>";
		$text .= "  <TR valign=top>";
		$text .= "    <TD><FORM action=\"" . BASEURL . SCRIPT . "\" method=post>";
		$text .= "    <button id=addNodeBtn dojoType=Button ";
		$text .= "onClick=\"showAddNodePane(); return false;\">";
		$text .= "Add Child</button>";
		$text .= "    </FORM></TD>";
		$text .= "    <TD><FORM action=\"" . BASEURL . SCRIPT . "\" method=post>";
		$text .= "    <button id=deleteNodeBtn dojoType=Button onClick=\"showDeleteNodeDialog();\">";
		$text .= "Delete Node and Children</button>";
		$text .= "    </FORM></TD>";
		$text .= "  </TR>";
		$text .= "</TABLE>";
	}
	$return .= setAttribute('treebuttons', 'innerHTML', $text);
	$return .= "AJdojoCreate('treebuttons');";


	# privileges
	$text = "";
	$text .= "<H3>Users</H3>";
	$text .= "<FORM id=usersform action=\"" . BASEURL . SCRIPT . "#users\" method=post>";
	$users = array();
	if(count($privs["users"]) || count($cascadePrivs["users"])) {
		$text .= "<TABLE border=1 summary=\"\">";
		$text .= "  <TR>";
		$text .= "    <TD></TD>";
		$text .= "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>";
		$text .= "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>";
		foreach($usertypes["users"] as $type) {
			$img = getImageText($type);
			$text .= "    <TD>$img</TD>";
		}
		$text .= "  </TR>";
		$users = array_unique(array_merge(array_keys($privs["users"]), 
		                      array_keys($cascadePrivs["users"])));
		sort($users);
		foreach($users as $_user) {
			$tmpArr = getUserPrivRowHTML($_user, $i, $privs["users"],
			                 $usertypes["users"], $cascadePrivs["users"], 'user',
			                 ! $hasUserGrant);
			$text .= $tmpArr['html'];
			$js .= $tmpArr['javascript'];
			$i++;
		}
		$text .= "</TABLE>";
		$text .= "<div id=lastUserNum class=hidden>" . ($i - 1) . "</div>";
		if($hasUserGrant) {
			$cont = addContinuationsEntry('AJchangeUserPrivs');
			$text .= "<INPUT type=hidden id=changeuserprivcont value=\"$cont\">";
		}
	}
	else {
		$text .= "There are no user privileges at the selected node.<br>";
	}
	if($hasUserGrant) {
		$text .= "<BUTTON id=addUserBtn dojoType=Button onClick=\"showAddUserPane(); return false;\">";
		$text .= "Add User</button>";
	}
	$text .= "</FORM>";
	$return .= setAttribute('usersDiv', 'innerHTML', $text);
	$return .= "AJdojoCreate('usersDiv');";

	# groups
	$text = "";
	$text .= "<H3>User Groups</H3>";
	if(count($privs["usergroups"]) || count($cascadePrivs["usergroups"])) {
		$text .= "<FORM action=\"" . BASEURL . SCRIPT . "#groups\" method=post>";
		$text .= "<div id=firstUserGroupNum class=hidden>$i</div>";
		$text .= "<TABLE border=1 summary=\"\">";
		$text .= "  <TR>";
		$text .= "    <TD></TD>";
		$text .= "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>";
		#$img = getImageText("Block Cascaded Rights");
		#$text .= "    <TD>$img</TD>";
		$text .= "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>";
		#$img = getImageText("Cascade to Child Nodes");
		#$text .= "    <TD>$img</TD>";
		foreach($usertypes["users"] as $type) {
			$img = getImageText($type);
			$text .= "    <TH>$img</TH>";
		}
		$text .= "  </TR>";
		$groups = array_unique(array_merge(array_keys($privs["usergroups"]), 
		                      array_keys($cascadePrivs["usergroups"])));
		sort($groups);
		foreach($groups as $group) {
			$tmpArr = getUserPrivRowHTML($group, $i, $privs["usergroups"],
			                  $usertypes["users"], $cascadePrivs["usergroups"],
			                  'group', ! $hasUserGrant);
			$text .= $tmpArr['html'];
			$js .= $tmpArr['javascript'];
			$i++;
		}
		$text .= "</TABLE>";
		$text .= "<div id=lastUserGroupNum class=hidden>" . ($i - 1) . "</div>";
		if($hasUserGrant) {
			$cont = addContinuationsEntry('AJchangeUserGroupPrivs');
			$text .= "<INPUT type=hidden id=changeusergroupprivcont value=\"$cont\">";
		}
	}
	else {
		$text .= "There are no user group privileges at the selected node.<br>";
		$groups = array();
	}
	if($hasUserGrant) {
		$text .= "<BUTTON id=addGroupBtn dojoType=Button onclick=\"showAddUserGroupPane(); return false;\">";
		$text .= "Add Group</button>";
	}
	$text .= "</FORM>";
	$return .= setAttribute('usergroupsDiv', 'innerHTML', $text);
	$return .= "AJdojoCreate('usergroupsDiv');";

	# resources
	$text = "";
	$resourcetypes = array("available", "administer", "manageGroup");
	$text .= "<H3>Resources</H3>";
	$text .= "<FORM id=resourceForm action=\"" . BASEURL . SCRIPT . "#resources\" method=post>";
	if(count($privs["resources"]) || count($cascadePrivs["resources"])) {
		$text .= "<TABLE border=1 summary=\"\">";
		$text .= "  <TR>";
		$text .= "    <TH>Group<br>Name</TH>";
		$text .= "    <TH>Group<br>Type</TH>";
		$text .= "    <TH bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>";
		$text .= "    <TH bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>";
		foreach($resourcetypes as $type) {
			$img = getImageText("$type");
			$text .= "    <TH>$img</TH>";
		}
		$text .= "  </TR>";
		$resources = array_unique(array_merge(array_keys($privs["resources"]), 
		                          array_keys($cascadePrivs["resources"])));
		sort($resources);
		$resourcegroups = getResourceGroups();
		$resgroupmembers = getResourceGroupMembers();
		foreach($resources as $resource) {
			$tmpArr = getResourcePrivRowHTML($resource, $i, $privs["resources"],
			          $resourcetypes, $resourcegroups, $resgroupmembers,
			          $cascadePrivs["resources"], ! $hasResourceGrant);
			$text .= $tmpArr['html'];
			$js .= $tmpArr['javascript'];
			$i++;
		}
		$text .= "</TABLE>";
		if($hasResourceGrant) {
			$cont = addContinuationsEntry('AJchangeResourcePrivs');
			$text .= "<INPUT type=hidden id=changeresourceprivcont value=\"$cont\">";
		}
	}
	else {
		$text .= "There are no resource group privileges at the selected node.<br>";
		$resources = array();
	}
	if($hasResourceGrant) {
		$text .= "<BUTTON id=addResourceBtn dojoType=Button onclick=\"showAddResourceGroupPane(); return false;\">";
		$text .= "Add Resource Group</button>";
	}
	$text .= "</FORM>";
	$return .= setAttribute('resourcesDiv', 'innerHTML', $text);
	$return .= "AJdojoCreate('resourcesDiv');";

	$return .= "showPrivileges();";
	print $return;
	print $js;
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn recursivePrintNodes($nodelist, $openNodes, $activeNode)
///
/// \param $nodelist - array of nodes to print
/// \param $openNodes - array of nodes whose children should be printed
/// \param $activeNode - (optional) a selected node
///
/// \brief prints all nodes in $nodelist and any children of nodes in
/// $openNodes, if $activeNode is given, it is printed in red
///
////////////////////////////////////////////////////////////////////////////////
/*function recursivePrintNodes($nodelist, $openNodes, $activeNode="") {
	print "<UL>\n";
	foreach(array_keys($nodelist) as $id) {
		$children = getChildNodes($id);
		if(is_array($openNodes)) {
			$openNodes_enc = implode(":", $openNodes);
			if(! in_array($id, $openNodes))
				$openNodesNew = implode(":", $openNodes) . ":$id";
			else {
				$tmp = $openNodes;
				unset_by_val($id, $tmp);
				$openNodesNew = implode(":", $tmp);
			}
		}
		if(! is_array($openNodes) && $openNodes == "all") {
			print "  <img border=0 src=images/node.png> ";
			print $nodelist[$id]["name"] . "<br>\n";
		}
		elseif(count($children)) {
			if(in_array($id, $openNodes)) {
				print "  <a href=\"" . BASEURL . SCRIPT . "?mode=viewNodes&";
				print "activeNode=$activeNode&openNodes=$openNodesNew\">";
				print "<img border=0 src=images/collapse.png></a> ";
			}
			else {
				print "  <a href=\"" . BASEURL . SCRIPT . "?mode=viewNodes&";
				print "activeNode=$activeNode&openNodes=$openNodesNew\">";
				print "<img border=0 src=images/expand.png></a> ";
			}
			if($id == $activeNode) {
				print "<font color=red>" . $nodelist[$id]["name"] . "</font><br>\n";
			}
			else {
				print "<a href=\"" . BASEURL . SCRIPT . "?mode=viewNodes&";
				print "activeNode=$id&openNodes=$openNodes_enc\">";
				print "<font color=black>" . $nodelist[$id]["name"];
				print "</font></a><br>\n";
			}
		}
		else {
			print "  <img border=0 src=images/node.png> ";
			if($id == $activeNode) {
				print "<font color=red>" . $nodelist[$id]["name"] . "</font><br>\n";
			}
			else {
				print "<a href=\"" . BASEURL . SCRIPT . "?mode=viewNodes&";
				print "activeNode=$id&openNodes=$openNodes_enc\">";
				print "<font color=black>" . $nodelist[$id]["name"];
				print "</font></a><br>\n";
			}
		}
		if((! is_array($openNodes) && $openNodes == "all") || 
		   in_array($id, $openNodes)) {
			if(count($children)) {
				recursivePrintNodes($children, $openNodes, $activeNode);
			}
		}
	}
	print "</UL>\n";
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn recursivePrintNodes2($nodelist, $openNodes, $activeNode)
///
/// \param $nodelist - array of nodes to print
/// \param $openNodes - array of nodes whose children should be printed
/// \param $activeNode - (optional) a selected node
///
/// \brief prints all nodes in $nodelist and any children of nodes in
/// $openNodes, if $activeNode is given, it is printed in red
///
////////////////////////////////////////////////////////////////////////////////
function recursivePrintNodes2($nodelist, $openNodes, $activeNode="") {
	foreach(array_keys($nodelist) as $id) {
		$opentext = "";
		if(in_array($id, $openNodes))
			$opentext = "expandLevel=1";
		print "  <div dojoType=\"TreeNode\" title=\"{$nodelist[$id]['name']}\" widgetId=$id $opentext>\n";
		$children = getChildNodes($id);
		if(count($children))
			recursivePrintNodes2($children, $openNodes);
		print "  </div>\n";
	}
	return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addChildNode()
///
/// \brief prints a page for adding a child node
///
////////////////////////////////////////////////////////////////////////////////
/*function addChildNode() {
	global $submitErr;
	$parent = processInputVar("activeNode", ARG_NUMERIC);
	$nodeInfo = getNodeInfo($parent);
	$newnode = processInputVar("newnode", ARG_STRING);
	$openNodes = processInputVar("openNodes", ARG_STRING);
	print "<H2>Add Child Node</H2>\n";
	print "Add child to " . $nodeInfo["name"] . ":<br><br>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>New Node:</TH>\n";
	print "    <TD><INPUT type=text name=newnode value=\"$newnode\"></TD>\n";
	print "    <TD>";
	printSubmitErr($submitErr);
	print "</TD>";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD colspan=2 align=right><INPUT type=submit value=Submit>";
	print "</TD>\n";
	print "  <TD></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<INPUT type=hidden name=mode value=submitAddChildNode>\n";
	print "<INPUT type=hidden name=openNodes value=$openNodes>\n";
	print "<INPUT type=hidden name=activeNode value=$parent>\n";
	print "</FORM>\n";
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddChildNode()
///
/// \brief processes input for adding a child node; if all is ok, adds node
/// to privnode table; checks to see if submitting user has nodeAdmin,
/// userGrant, and resourceGrant cascaded to the node; adds any of the privs
/// that aren't cascaded; calls viewNodes when finished
///
////////////////////////////////////////////////////////////////////////////////
/*function submitAddChildNode() {
	global $submitErr, $submitErrMsg, $user, $nodechildren;
	$parent = processInputVar("activeNode", ARG_NUMERIC);
	$nodeInfo = getNodeInfo($parent);
	$newnode = processInputVar("newnode", ARG_STRING);
	$openNodes = processInputVar("openNodes", ARG_STRING);
	if(! ereg('^[-A-Za-z0-9_. ]+$', $newnode)) {
		$submitErr |= NEWNODENAMEERR;
		$submitErrMsg[NEWNODENAMEERR] = "You can only use letters, numbers, "
		      . "spaces, dashes(-), dots(.), underscores(_), and spaces.";
	}

	# check to see if a node with the submitted name already exists
	$query = "SELECT id "
	       . "FROM privnode "
	       . "WHERE name = '$newnode' AND "
	       .       "parent = $parent";
	$qh = doQuery($query, 335);
	if(mysql_num_rows($qh)) {
		$submitErr |= NEWNODENAMEERR;
		$submitErrMsg[NEWNODENAMEERR] = "A node of that name already exists "
		                              . "under " . $nodeInfo["name"];
	}
	if($submitErr) {
		addChildNode();
		return;
	}
	$query = "INSERT INTO privnode "
	       .         "(parent, "
	       .         "name) "
	       . "VALUES "
	       .         "($parent, "
	       .         "'$newnode')";
	doQuery($query, 336);

	$qh = doQuery("SELECT LAST_INSERT_ID() FROM privnode", 101);
	if(! $row = mysql_fetch_row($qh)) {
		abort(101);
	}
	$nodeid = $row[0];

	$privs = array();
	foreach(array("nodeAdmin", "userGrant", "resourceGrant") as $type) {
		if(! checkUserHasPriv($type, $user["id"], $nodeid))
			array_push($privs, $type);
	}
	if(count($privs))
		array_push($privs, "cascade");
	updateUserOrGroupPrivs($user["id"], $nodeid, $privs, array(), "user");
	$_POST["openNodes"] .= ":$parent";
	$nodechildren = array();
	viewNodes();
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitAddChildNode()
///
/// \brief processes input for adding a child node; if all is ok, adds node
/// to privnode table; checks to see if submitting user has nodeAdmin,
/// userGrant, and resourceGrant cascaded to the node; adds any of the privs
/// that aren't cascaded; calls viewNodes when finished
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitAddChildNode() {
	global $user;
	$parent = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("nodeAdmin", $user["id"], $parent)) {
		$text = "You do not have rights to add children to this node.";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	$nodeInfo = getNodeInfo($parent);
	$newnode = processInputVar("newnode", ARG_STRING);
	if(! ereg('^[-A-Za-z0-9_. ]+$', $newnode)) {
		$text = "You can only use letters, numbers, "
		      . "spaces, dashes(-), dots(.), underscores(_), and spaces.";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}

	# check to see if a node with the submitted name already exists
	$query = "SELECT id "
	       . "FROM privnode "
	       . "WHERE name = '$newnode' AND "
	       .       "parent = $parent";
	$qh = doQuery($query, 335);
	if(mysql_num_rows($qh)) {
		$text = "A node of that name already exists "
		      . "under " . $nodeInfo["name"];
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	$query = "INSERT INTO privnode "
	       .         "(parent, "
	       .         "name) "
	       . "VALUES "
	       .         "($parent, "
	       .         "'$newnode')";
	doQuery($query, 336);

	$qh = doQuery("SELECT LAST_INSERT_ID() FROM privnode", 101);
	if(! $row = mysql_fetch_row($qh)) {
		abort(101);
	}
	$nodeid = $row[0];

	$privs = array();
	foreach(array("nodeAdmin", "userGrant", "resourceGrant") as $type) {
		if(! checkUserHasPriv($type, $user["id"], $nodeid))
			array_push($privs, $type);
	}
	if(count($privs))
		array_push($privs, "cascade");
	updateUserOrGroupPrivs($user["id"], $nodeid, $privs, array(), "user");
	print "addChildNode('$newnode', $nodeid);";
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn nodeExists($node)
///
/// \param $node - the id of a node
///
/// \return 1 if exists, 0 if not
///
/// \brief checks to see if $node exists
///
////////////////////////////////////////////////////////////////////////////////
function nodeExists($node) {
	$query = "SELECT id FROM privnode WHERE id = $node";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh))
		return 1;
	else
		return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn deleteNode()
///
/// \brief prompts user for confirmation on deleting a node and its children
///
////////////////////////////////////////////////////////////////////////////////
/*function deleteNode() {
	$activeNode = processInputVar("activeNode", ARG_NUMERIC);
	$openNodes = processInputVar("openNodes", ARG_STRING);
	$nodeInfo = getNodeInfo($activeNode);
	$children = getChildNodes($activeNode);
	print "<H2>Delete Node and Children</H2>\n";
	if(count($children)) {
		print "Delete the following part of the privilege tree?<br><br>\n";
		recursivePrintNodes(array($activeNode => $nodeInfo), "all");
	}
	else {
		print "Delete " . $nodeInfo["name"] . " from the privilege ";
		print "tree?<br><br>\n";
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=submitDeleteNode>\n";
	print "      <INPUT type=hidden name=activeNode value=$activeNode>\n";
	print "      <INPUT type=hidden name=openNodes value=$openNodes>\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "      <INPUT type=hidden name=mode value=viewNodes>\n";
	print "      <INPUT type=hidden name=openNodes value=$openNodes>\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteNode()
///
/// \brief deletes a node and its children; calls viewNodes when finished
///
////////////////////////////////////////////////////////////////////////////////
/*function submitDeleteNode() {
	global $nodechildren;
	$activeNode = processInputVar("activeNode", ARG_NUMERIC);
	$nodeinfo = getNodeInfo($activeNode);
	$_POST["activeNode"] = $nodeinfo["parent"];
	$nodes = recurseGetChildren($activeNode);
	array_push($nodes, $activeNode);
	$deleteNodes = implode(',', $nodes);
	$query = "DELETE FROM privnode "
	       . "WHERE id IN ($deleteNodes)";
	doQuery($query, 345);
	$nodechildren = array();
	clearPrivCache();
	viewNodes();
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitDeleteNode()
///
/// \brief deletes a node and its children; calls viewNodes when finished
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitDeleteNode() {
	global $user;
	$activeNode = processInputVar("activeNode", ARG_NUMERIC);
	if(empty($activeNode)) {
		dbDisconnect();
		exit;
	}
	if(! checkUserHasPriv("nodeAdmin", $user["id"], $activeNode)) {
		$text = "You do not have rights to delete this node.";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	clearPrivCache();
	$nodes = recurseGetChildren($activeNode);
	$parents = getParentNodes($activeNode);
	$parent = $parents[0];
	array_push($nodes, $activeNode);
	$deleteNodes = implode(',', $nodes);
	$query = "DELETE FROM privnode "
	       . "WHERE id IN ($deleteNodes)";
	doQuery($query, 345);
	print "var obj = dojo.widget.byId('$activeNode'); ";
	print "dojo.widget.byId('$parent').removeNode(obj); ";
	print "setSelectedPrivNode('$parent'); ";
	print "refreshPerms(); ";
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn userLookup()
///
/// \brief prints a page to display a user's privileges
///
////////////////////////////////////////////////////////////////////////////////
function userLookup() {
	global $user, $viewmode;
	$userid = processInputVar("userid", ARG_STRING);
	print "<div align=center>\n";
	print "<H2>User Lookup</H2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH>User ID:</TH>\n";
	print "    <TD><INPUT type=text name=userid value=\"$userid\" size=25></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TD align=right><INPUT type=submit value=Submit>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	$cont = addContinuationsEntry('submitUserLookup');
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM>\n";
	if(! empty($userid)) {
		$loginid = $userid;
		getAffilidAndLogin($loginid, $affilid);
		if(empty($affilid)) {
			print "{$matches[2]} is an unknown affiliation<br>\n";
			return;
		}
		if($viewmode != ADMIN_DEVELOPER &&
		   $user['affiliationid'] != $affilid) {
			print "You are only allowed to look up users from your own affiliation.<br>\n";
			return;
		}
		$query = "SELECT id "
		       . "FROM user "
		       . "WHERE unityid = '$loginid' AND "
		       .       "affiliationid = $affilid";
		$qh = doQuery($query, 101);
		if(! mysql_num_rows($qh))
			print "<font color=red>$userid not currently found in VCL user database, will try to add...</font><br>\n";

		$userdata = getUserInfo($userid);
		if(is_null($userdata)) {
			print "<font color=red>$userid not found in any known systems</font><br>\n";
			return;
		}
		print "<TABLE>\n";
		print "  <TR>\n";
		print "    <TH align=right>First Name:</TH>\n";
		print "    <TD>{$userdata["firstname"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Middle Name:</TH>\n";
		print "    <TD>{$userdata["middlename"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Last Name:</TH>\n";
		print "    <TD>{$userdata["lastname"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Preferred Name:</TH>\n";
		print "    <TD>{$userdata["preferredname"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Email:</TH>\n";
		print "    <TD>{$userdata["email"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right>Admin Level:</TH>\n";
		print "    <TD>{$userdata["adminlevel"]}</TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right style=\"vertical-align: top\">Groups:</TH>\n";
		print "    <TD>\n";
		uasort($userdata["groups"], "sortKeepIndex");
		foreach($userdata["groups"] as $group) {
			print "      $group<br>\n";
		}
		print "    </TD>\n";
		print "  </TR>\n";
		print "  <TR>\n";
		print "    <TH align=right style=\"vertical-align: top\">Privileges (found somewhere in the tree):</TH>\n";
		print "    <TD>\n";
		uasort($userdata["privileges"], "sortKeepIndex");
		foreach($userdata["privileges"] as $priv) {
			if($priv == "block" || $priv == "cascade")
				continue;
			print "      $priv<br>\n";
		}
		print "    </TD>\n";
		print "  </TR>\n";
		print "</TABLE>\n";

		# get user's resources
		$userResources = getUserResources(array("imageCheckOut"), array("available"), 0, 0, $userdata['id']);

		# find nodes where user has privileges
		$query = "SELECT p.name AS privnode, "
		       .        "upt.name AS userprivtype, "
		       .        "up.privnodeid "
		       . "FROM userpriv up, "
		       .      "privnode p, "
		       .      "userprivtype upt "
		       . "WHERE up.privnodeid = p.id AND "
		       .       "up.userprivtypeid = upt.id AND "
		       .       "up.userid = {$userdata['id']} "
		       . "ORDER BY p.name, "
		       .          "upt.name";
		$qh = doQuery($query, 101);
		if(mysql_num_rows($qh)) {
			print "Nodes where user is granted privileges:<br>\n";
			print "<TABLE>\n";
			$privnodeid = 0;
			while($row = mysql_fetch_assoc($qh)) {
				if($privnodeid != $row['privnodeid']) {
					if($privnodeid) {
						print "    </TD>\n";
						print "  </TR>\n";
					}
					print "  <TR>\n";
					$privnodeid = $row['privnodeid'];
					print "    <TH align=right>{$row['privnode']}</TH>\n";
					print "    <TD>\n";
				}
				print "      {$row['userprivtype']}<br>\n";
			}
			print "    </TD>\n";
			print "  </TR>\n";
			print "</TABLE>\n";
		}

		# find nodes where user's groups have privileges
		if(! empty($userdata['groups'])) {
			$query = "SELECT DISTINCT p.name AS privnode, "
			       .        "upt.name AS userprivtype, "
			       .        "up.privnodeid "
			       . "FROM userpriv up, "
			       .      "privnode p, "
			       .      "userprivtype upt "
			       . "WHERE up.privnodeid = p.id AND "
			       .       "up.userprivtypeid = upt.id AND "
			       .       "upt.name != 'cascade' AND "
			       .       "upt.name != 'block' AND "
			       .       "up.usergroupid IN (" . implode(',', array_keys($userdata['groups'])) . ") "
			       . "ORDER BY p.name, "
			       .          "upt.name";
			$qh = doQuery($query, 101);
			if(mysql_num_rows($qh)) {
				print "Nodes where user's groups are granted privileges:<br>\n";
				print "<TABLE>\n";
				$privnodeid = 0;
				while($row = mysql_fetch_assoc($qh)) {
					if($privnodeid != $row['privnodeid']) {
						if($privnodeid) {
							print "    </TD>\n";
							print "  </TR>\n";
						}
						print "  <TR>\n";
						$privnodeid = $row['privnodeid'];
						print "    <TH align=right>{$row['privnode']}</TH>\n";
						print "    <TD>\n";
					}
					print "      {$row['userprivtype']}<br>\n";
				}
				print "    </TD>\n";
				print "  </TR>\n";
				print "</TABLE>\n";
			}
		}
		print "<table>\n";
		print "  <tr>\n";
		print "    <th>Images User Has Access To:<th>\n";
		print "    <td>\n";
		foreach($userResources['image'] as $img)
			print "      $img<br>\n";
		print "    </td>\n";
		print "  </tr>\n";
		print "</table>\n";

		$requests = array();
		$query = "SELECT l.start AS start, "
		       .        "l.finalend AS end, "
		       .        "c.hostname, "
		       .        "i.prettyname AS prettyimage, "
		       .        "l.ending "
		       . "FROM log l, "
		       .      "image i, "
		       .      "computer c, "
		       .      "sublog s "
		       . "WHERE l.userid = {$userdata["id"]} AND "
		       .        "s.logid = l.id AND "
		       .        "i.id = s.imageid AND "
		       .        "c.id = s.computerid "
		       . "ORDER BY l.start DESC "
		       . "LIMIT 5";
		$qh = doQuery($query, 290);
		while($row = mysql_fetch_assoc($qh))
			array_push($requests, $row);
		$requests = array_reverse($requests);
		if(! empty($requests)) {
			print "<h3>User's last " . count($requests) . " reservations:</h3>\n";
			print "<table>\n";
			$first = 1;
			foreach($requests as $req) {
				$thisstart = str_replace('&nbsp;', ' ', 
				      prettyDatetime($req["start"]));
				$thisend = str_replace('&nbsp;', ' ', 
				      prettyDatetime($req["end"]));
				if($first)
					$first = 0;
				else {
					print "  <tr>\n";
					print "    <td colspan=2><hr></td>\n";
					print "  </tr>\n";
				}
				print "  <tr>\n";
				print "    <th align=right>Image:</th>\n";
				print "    <td>{$req['prettyimage']}</td>\n";
				print "  </tr>\n";
				print "  <tr>\n";
				print "    <th align=right>Computer:</th>\n";
				print "    <td>{$req['hostname']}</td>\n";
				print "  </tr>\n";
				print "  <tr>\n";
				print "    <th align=right>Start:</th>\n";
				print "    <td>$thisstart</td>\n";
				print "  </tr>\n";
				print "  <tr>\n";
				print "    <th align=right>End:</th>\n";
				print "    <td>$thisend</td>\n";
				print "  </tr>\n";
				print "  <tr>\n";
				print "    <th align=right>Ending:</th>\n";
				print "    <td>{$req['ending']}</td>\n";
				print "  </tr>\n";
			}
			print "</table>\n";
		}
		else
			print "User made no reservations in the past week.<br>\n";
	}
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn recurseGetChildren($node)
///
/// \param $node - a node id
///
/// \return an array of nodes that are children of $node
///
/// \brief foreach child node of $node, adds it to an array and calls
/// self to add that child's children
///
////////////////////////////////////////////////////////////////////////////////
function recurseGetChildren($node) {
	$children = array();
	$qh = doQuery("SELECT id FROM privnode WHERE parent = $node", 340);
	while($row = mysql_fetch_row($qh)) {
		array_push($children, $row[0]);
		$children = array_merge($children, recurseGetChildren($row[0]));
	}
	return $children;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printUserPrivRow($privname, $rownum, $privs, $types,
///                               $cascadeprivs, $usergroup, $disabled)
///
/// \param $privname - privilege name
/// \param $rownum - number of the privilege row on this page
/// \param $privs - an array of user's privileges
/// \param $types - an array of privilege types
/// \param $cascadeprivs - an array of user's cascaded privileges
/// \param $usergroup - 'user' if this is a user row, or 'group' if this is a
/// group row
/// \param $disabled - 0 or 1; whether or not the checkboxes should be disabled
///
/// \brief prints a table row for this $privname
///
////////////////////////////////////////////////////////////////////////////////
function printUserPrivRow($privname, $rownum, $privs, $types, 
                          $cascadeprivs, $usergroup, $disabled) {
	$allprivs = $cascadeprivs + $privs;
	print "  <TR>\n";
	if($usergroup == 'group' && ! empty($allprivs[$privname]['affiliation']))
		print "    <TH>$privname@{$allprivs[$privname]['affiliation']}</TH>\n";
	else
		print "    <TH>$privname</TH>\n";

	if($disabled)
		$disabled = 'disabled=disabled';
	else
		$disabled = '';

	# block rights
	if(array_key_exists($privname, $privs) && 
	   (($usergroup == 'user' &&
	   in_array("block", $privs[$privname])) ||
	   ($usergroup == 'group' &&
	   in_array("block", $privs[$privname]['privs'])))) {
		$checked = "checked";
		$blocked = 1;
	}
	else {
		$checked = "";
		$blocked = 0;
	}
	$count = count($types) + 1;
	if($usergroup == 'user') {
		$usergroup = 1;
		$name = "privrow[$privname:block]";
	}
	elseif($usergroup == 'group') {
		$usergroup = 2;
		$name = "privrow[{$allprivs[$privname]['id']}:block]";
	}
	print "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	print "dojoType=Checkbox id=ck$rownum:block name=\"$name\" $checked ";
	print "onClick=\"javascript:changeCascadedRights(this.checked, $rownum, ";
	print "$count, 1, $usergroup);\" $disabled></TD>\n";

	#cascade rights
	if(array_key_exists($privname, $privs) && 
	   (($usergroup == 1 &&
	   in_array("cascade", $privs[$privname])) ||
		($usergroup == 2 &&
	   in_array("cascade", $privs[$privname]['privs']))))
		$checked = "checked";
	else
		$checked = "";
	if($usergroup == 1)
		$name = "privrow[$privname:cascade]";
	else
		$name = "privrow[{$allprivs[$privname]['id']}:cascade]";
	print "    <TD align=center bgcolor=\"#008000\" id=cell$rownum:0>";
	print "<INPUT type=checkbox dojoType=Checkbox id=ck$rownum:0 ";
	print "name=\"$name\" onClick=\"privChange(this.checked, $rownum, 0, ";
	print "$usergroup);\" $checked $disabled></TD>\n";

	# normal rights
	$j = 1;
	foreach($types as $type) {
		$bgcolor = "";
		$checked = "";
		$value = "";
		$cascaded = 0;
		if(array_key_exists($privname, $cascadeprivs) && 
		   (($usergroup == 1 &&
		   in_array($type, $cascadeprivs[$privname])) ||
		   ($usergroup == 2 &&
		   in_array($type, $cascadeprivs[$privname]['privs'])))) {
			$bgcolor = "bgcolor=\"#008000\"";
			$checked = "checked";
			$value = "value=cascade";
			$cascaded = 1;
		}
		if(array_key_exists($privname, $privs) && 
		   (($usergroup == 1 &&
		   in_array($type, $privs[$privname])) ||
		   ($usergroup == 2 &&
		   in_array($type, $privs[$privname]['privs'])))) {
			if($cascaded) {
				$value = "value=cascadesingle";
			}
			else {
				$checked = "checked";
				$value = "value=single";
			}
		}
		if($usergroup == 1)
			$name = "privrow[$privname:$type]";
		else
			$name = "privrow[{$allprivs[$privname]['id']}:$type]";
		print "    <TD align=center id=cell$rownum:$j $bgcolor><INPUT ";
		print "type=checkbox dojoType=Checkbox name=\"$name\" id=ck$rownum:$j ";
		print "$checked $value $disabled ";
		print "onClick=\"javascript:nodeCheck(this.checked, $rownum, $j, $usergroup)\" ";
		print "onBlur=\"javascript:nodeCheck(this.checked, $rownum, $j, $usergroup)\">";
		print "</TD>\n";
		$j++;
	}
	print "  </TR>\n";
	$count = count($types) + 1;
	if($blocked) {
		print "<script language=\"Javascript\">\n";
		print "dojo.addOnLoad(function() {setTimeout(\"changeCascadedRights(true, $rownum, $count, 0, 0)\", 500)});\n";
		print "</script>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getUserPrivRowHTML($privname, $rownum, $privs, $types,
///                                 $cascadeprivs, $usergroup, $disabled)
///
/// \param $privname - privilege name
/// \param $rownum - number of the privilege row on this page
/// \param $privs - an array of user's privileges
/// \param $types - an array of privilege types
/// \param $cascadeprivs - an array of user's cascaded privileges
/// \param $usergroup - 'user' if this is a user row, or 'group' if this is a
/// group row
/// \param $disabled - 0 or 1; whether or not the checkboxes should be disabled
///
/// \return a string of HTML code for a user privilege row
///
/// \brief creates HTML for a user privilege row and returns it 
///
////////////////////////////////////////////////////////////////////////////////
function getUserPrivRowHTML($privname, $rownum, $privs, $types, 
                            $cascadeprivs, $usergroup, $disabled) {
	$allprivs = $cascadeprivs + $privs;
	$text = "";
	$js = "";
	$text .= "  <TR>";
	if($usergroup == 'group' && ! empty($allprivs[$privname]['affiliation']))
		$text .= "    <TH>$privname@{$allprivs[$privname]['affiliation']}</TH>";
	else
		$text .= "    <TH>$privname</TH>";

	if($disabled)
		$disabled = 'disabled=disabled';
	else
		$disabled = '';

	# block rights
	if(array_key_exists($privname, $privs) && 
	   (($usergroup == 'user' &&
	   in_array("block", $privs[$privname])) ||
	   ($usergroup == 'group' &&
	   in_array("block", $privs[$privname]['privs'])))) {
		$checked = "checked";
		$blocked = 1;
	}
	else {
		$checked = "";
		$blocked = 0;
	}
	$count = count($types) + 1;
	if($usergroup == 'user') {
		$usergroup = 1;
		$name = "privrow[$privname:block]";
	}
	elseif($usergroup == 'group') {
		$usergroup = 2;
		$name = "privrow[{$allprivs[$privname]['id']}:block]";
	}
	$text .= "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	$text .= "dojoType=Checkbox id=ck$rownum:block name=\"$name\" $checked ";
	$text .= "$disabled onClick=\"javascript:";
	$text .= "changeCascadedRights(this.checked, $rownum, $count, 1, $usergroup)\"></TD>";

	#cascade rights
	if(array_key_exists($privname, $privs) && 
	   (($usergroup == 1 &&
	   in_array("cascade", $privs[$privname])) ||
		($usergroup == 2 &&
	   in_array("cascade", $privs[$privname]['privs']))))
		$checked = "checked";
	else
		$checked = "";
	if($usergroup == 1)
		$name = "privrow[$privname:cascade]";
	else
		$name = "privrow[{$allprivs[$privname]['id']}:cascade]";
	$text .= "    <TD align=center bgcolor=\"#008000\" id=cell$rownum:0>";
	$text .= "<INPUT type=checkbox dojoType=Checkbox id=ck$rownum:0 name=\"$name\" ";
	$text .= "onClick=\"privChange(this.checked, $rownum, 0, $usergroup);\" ";
	$text .= "$checked $disabled></TD>";

	# normal rights
	$j = 1;
	foreach($types as $type) {
		$bgcolor = "";
		$checked = "";
		$value = "";
		$cascaded = 0;
		if(array_key_exists($privname, $cascadeprivs) && 
		   (($usergroup == 1 &&
		   in_array($type, $cascadeprivs[$privname])) ||
		   ($usergroup == 2 &&
		   in_array($type, $cascadeprivs[$privname]['privs'])))) {
			$bgcolor = "bgcolor=\"#008000\"";
			$checked = "checked";
			$value = "value=cascade";
			$cascaded = 1;
		}
		if(array_key_exists($privname, $privs) && 
		   (($usergroup == 1 &&
		   in_array($type, $privs[$privname])) ||
		   ($usergroup == 2 &&
		   in_array($type, $privs[$privname]['privs'])))) {
			if($cascaded) {
				$value = "value=cascadesingle";
			}
			else {
				$checked = "checked";
				$value = "value=single";
			}
		}
		if($usergroup == 1)
			$name = "privrow[$privname:$type]";
		else
			$name = "privrow[{$allprivs[$privname]['id']}:$type]";
		$text .= "    <TD align=center id=cell$rownum:$j $bgcolor><INPUT ";
		$text .= "type=checkbox dojoType=Checkbox name=\"$name\" ";
		$text .= "id=ck$rownum:$j $checked $value $disabled ";
		$text .= "onClick=\"javascript:nodeCheck(this.checked, $rownum, $j, $usergroup)\" ";
		$text .= "onBlur=\"javascript:nodeCheck(this.checked, $rownum, $j, $usergroup)\">";
		$text .= "</TD>";
		$j++;
	}
	$text .= "  </TR>";
	$count = count($types) + 1;
	if($blocked) {
		$js .= "changeCascadedRights(true, $rownum, $count, 0, 0);";
	}
	return array('html' => $text,
	             'javascript' => $js);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printResourcePrivRow($privname, $rownum, $privs, $types,
///                          $resourcegroups, $resgroupmembers, $cascadeprivs,
///                          $disabled)
///
/// \param $privname - privilege name
/// \param $rownum - number of the privilege row on this page
/// \param $privs - an array of user's privileges
/// \param $types - an array of privilege types
/// \param $resourcegroups - array from getResourceGroups()
/// \param $resgroupmembers - array from getResourceGroupMembers()
/// \param $cascadeprivs - an array of user's cascaded privileges
/// \param $disabled - 0 or 1; whether or not the checkboxes should be disabled
///
/// \brief prints a table row for this $privname
///
////////////////////////////////////////////////////////////////////////////////
function printResourcePrivRow($privname, $rownum, $privs, $types, 
                              $resourcegroups, $resgroupmembers, $cascadeprivs,
                              $disabled) {
	global $user;
	print "  <TR>\n";
	list($type, $name, $id) = split('/', $privname);
	print "    <TH>\n";
	print "      <span id=\"resgrp$id\">$name</span>\n";
	print "      <span dojoType=\"tooltip\" connectId=\"resgrp$id\">\n";
	if(array_key_exists($id, $resgroupmembers[$type]) &&
	   is_array($resgroupmembers[$type][$id])) {
		foreach($resgroupmembers[$type][$id] as $resource)
			print "        {$resource['name']}<br>\n";
	}
	else
		print "(empty group)\n";
	print "      </span>\n";
	print "    </TH>\n";
	//print "    <TH>$name</TH>\n";
	print "    <TH>$type</TH>\n";

	if($disabled)
		$disabled = 'disabled=disabled';
	else
		$disabled = '';

	# block rights
	if(array_key_exists($privname, $privs) && 
	   in_array("block", $privs[$privname])) {
		$checked = "checked";
		$blocked = 1;
	}
	else {
		$checked = "";
		$blocked = 0;
	}
	$count = count($types) + 1;
	$name = "privrow[" . $privname . ":block]";
	print "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	print "dojoType=Checkbox id=ck$rownum:block name=\"$name\" $checked ";
	print "$disabled onClick=\"javascript:";
	print "changeCascadedRights(this.checked, $rownum, $count, 1, 3)\"></TD>\n";

	#cascade rights
	if(array_key_exists($privname, $privs) && 
	   in_array("cascade", $privs[$privname]))
		$checked = "checked";
	else
		$checked = "";
	$name = "privrow[" . $privname . ":cascade]";
	print "    <TD align=center bgcolor=\"#008000\" id=cell$rownum:0>";
	print "<INPUT type=checkbox dojoType=Checkbox id=ck$rownum:0 name=\"$name\" ";
	print "onClick=\"privChange(this.checked, $rownum, 0, 3);\" ";
	print "$checked $disabled></TD>\n";

	# normal rights
	$j = 1;
	foreach($types as $type) {
		$bgcolor = "";
		$checked = "";
		$value = "";
		$cascaded = 0;
		if(array_key_exists($privname, $cascadeprivs) && 
		   in_array($type, $cascadeprivs[$privname])) {
			$bgcolor = "bgcolor=\"#008000\"";
			$checked = "checked";
			$value = "value=cascade";
			$cascaded = 1;
		}
		if(array_key_exists($privname, $privs) && 
		       in_array($type, $privs[$privname])) {
			if($cascaded) {
				$value = "value=cascadesingle";
			}
			else {
				$checked = "checked";
				$value = "value=single";
			}
		}
		// if $type is administer or manageGroup, and it is not checked, and the
		# user is not in the resource owner group, don't print the checkbox
		if(($type == "administer" || $type == "manageGroup") &&
		   $checked != "checked" && 
		   ! array_key_exists($resourcegroups[$id]["ownerid"], $user["groups"])) {
			print "<TD><img src=images/blank.gif></TD>\n";
		}
		else {
			$name = "privrow[" . $privname . ":" . $type . "]";
			print "    <TD align=center id=cell$rownum:$j $bgcolor><INPUT ";
			print "type=checkbox dojoType=Checkbox name=\"$name\" ";
			print "id=ck$rownum:$j $checked $value $disabled ";
			print "onClick=\"javascript:nodeCheck(this.checked, $rownum, $j, 3)\" ";
			print "onBlur=\"javascript:nodeCheck(this.checked, $rownum, $j, 3)\">";
			print "</TD>\n";
		}
		$j++;
	}
	print "  </TR>\n";
	$count = count($types) + 1;
	if($blocked) {
		print "<script language=\"Javascript\">\n";
		print "dojo.addOnLoad(function () {setTimeout(\"changeCascadedRights(true, $rownum, $count, 0, 0)\", 500)});\n";
		print "</script>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getResourcePrivRowHTML($privname, $rownum, $privs, $types,
///                                     $resourcegroups, $resgroupmembers,
///                                     $cascadeprivs, $disabled)
///
/// \param $privname - privilege name
/// \param $rownum - number of the privilege row on this page
/// \param $privs - an array of user's privileges
/// \param $types - an array of privilege types
/// \param $resourcegroups - array from getResourceGroups()
/// \param $resgroupmembers - array from getResourceGroupMembers()
/// \param $cascadeprivs - an array of user's cascaded privileges
/// \param $disabled - 0 or 1; whether or not the checkboxes should be disabled
///
/// \return a string of HTML code for a resource row
///
/// \brief creates HTML for a resource privilege row and returns it 
///
////////////////////////////////////////////////////////////////////////////////
function getResourcePrivRowHTML($privname, $rownum, $privs, $types,
                                $resourcegroups, $resgroupmembers,
                                $cascadeprivs, $disabled) {
	global $user;
	$text = "";
	$js = "";
	$text .= "  <TR>";
	list($type, $name, $id) = split('/', $privname);
	$text .= "    <TH>";
	$text .= "      <span id=\"resgrp$id\">$name</span>";
	$text .= "      <span dojoType=\"tooltip\" connectId=\"resgrp$id\">";
	if(array_key_exists($type, $resgroupmembers) &&
	   array_key_exists($id, $resgroupmembers[$type]) &&
	   is_array($resgroupmembers[$type][$id])) {
		foreach($resgroupmembers[$type][$id] as $resource) {
			$text .= "        {$resource['name']}<br>";
		}
	}
	$text .= "      </span>";
	$text .= "    </TH>";
	//$text .= "    <TH>$name</TH>";
	$text .= "    <TH>$type</TH>";

	if($disabled)
		$disabled = 'disabled=disabled';
	else
		$disabled = '';

	# block rights
	if(array_key_exists($privname, $privs) && 
	   in_array("block", $privs[$privname])) {
		$checked = "checked";
		$blocked = 1;
	}
	else {
		$checked = "";
		$blocked = 0;
	}
	$count = count($types) + 1;
	$name = "privrow[" . $privname . ":block]";
	$text .= "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	$text .= "dojoType=Checkbox id=ck$rownum:block name=\"$name\" $checked ";
	$text .= "$disabled onClick=\"javascript:";
	$text .= "changeCascadedRights(this.checked, $rownum, $count, 1, 3)\"></TD>";

	#cascade rights
	if(array_key_exists($privname, $privs) && 
	   in_array("cascade", $privs[$privname]))
		$checked = "checked";
	else
		$checked = "";
	$name = "privrow[" . $privname . ":cascade]";
	$text .= "    <TD align=center bgcolor=\"#008000\" id=cell$rownum:0>";
	$text .= "<INPUT type=checkbox dojoType=Checkbox id=ck$rownum:0 name=\"$name\" ";
	$text .= "onClick=\"privChange(this.checked, $rownum, 0, 3);\" ";
	$text .= "$checked $disabled></TD>";

	# normal rights
	$j = 1;
	foreach($types as $type) {
		$bgcolor = "";
		$checked = "";
		$value = "";
		$cascaded = 0;
		if(array_key_exists($privname, $cascadeprivs) && 
		   in_array($type, $cascadeprivs[$privname])) {
			$bgcolor = "bgcolor=\"#008000\"";
			$checked = "checked";
			$value = "value=cascade";
			$cascaded = 1;
		}
		if(array_key_exists($privname, $privs) && 
		       in_array($type, $privs[$privname])) {
			if($cascaded) {
				$value = "value=cascadesingle";
			}
			else {
				$checked = "checked";
				$value = "value=single";
			}
		}
		// if $type is administer or manageGroup, and it is not checked, and the
		# user is not in the resource owner group, don't print the checkbox
		if(($type == "administer" || $type == "manageGroup") &&
		   $checked != "checked" && 
		   ! array_key_exists($resourcegroups[$id]["ownerid"], $user["groups"])) {
			$text .= "<TD><img src=images/blank.gif></TD>";
		}
		else {
			$name = "privrow[" . $privname . ":" . $type . "]";
			$text .= "    <TD align=center id=cell$rownum:$j $bgcolor><INPUT ";
			$text .= "type=checkbox dojoType=Checkbox name=\"$name\" ";
			$text .= "id=ck$rownum:$j $checked $value $disabled ";
			$text .= "onClick=\"javascript:nodeCheck(this.checked, $rownum, $j, 3)\" ";
			$text .= "onBlur=\"javascript:nodeCheck(this.checked, $rownum, $j, 3)\">";
			$text .= "</TD>";
		}
		$j++;
	}
	$text .= "  </TR>";
	$count = count($types) + 1;
	if($blocked) {
		$js .= "changeCascadedRights(true, $rownum, $count, 0, 0);";
	}
	$text = preg_replace("/'/", '&#39;', $text);
	return array('html' => $text,
	             'javascript' => $js);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getNodePrivileges($node, $type, $privs)
///
/// \param $node - id of node
/// \param $type - (optional) resources, users, usergroups, or all
/// \param $privs - (optional) privilege array as returned by this function or
/// getNodeCascadePrivileges
///
/// \return an array of privileges at the node:\n
///\pre
///Array\n
///(\n
///    [resources] => Array\n
///        (\n
///        )\n
///    [users] => Array\n
///        (\n
///            [userid0] => Array\n
///                (\n
///                    [0] => priv0\n
///                        ...\n
///                    [N] => privN\n
///                )\n
///                ...\n
///            [useridN] => Array()\n
///        )\n
///    [usergroups] => Array\n
///        (\n
///            [group0] => Array\n
///                (\n
///                    [0] => priv0\n
///                        ...\n
///                    [N] => privN\n
///                )\n
///                ...\n
///            [groupN] => Array()\n
///        )\n
///)
///
/// \brief gets the requested privileges at the specified node
///
////////////////////////////////////////////////////////////////////////////////
function getNodePrivileges($node, $type="all", $privs=0) {
	global $user;
	$key = getKey(array($node, $type, $privs));
	if(array_key_exists($key, $_SESSION['nodeprivileges']))
		return $_SESSION['nodeprivileges'][$key];
	if(! $privs)
		$privs = array("resources" => array(),
		               "users" => array(),
		               "usergroups" => array());
	if($type == "resources" || $type == "all") {
		$query = "SELECT g.id AS id, "
		       .        "p.type AS privtype, "
		       .        "g.name AS name, "
		       .        "t.name AS type "
		       . "FROM resourcepriv p, "
		       .      "resourcetype t, "
		       .      "resourcegroup g "
		       . "WHERE p.privnodeid = $node AND "
		       .       "p.resourcegroupid = g.id AND "
		       .       "g.resourcetypeid = t.id";
		$qh = doQuery($query, 350);
		while($row = mysql_fetch_assoc($qh)) {
			$name = $row["type"] . "/" . $row["name"] . "/" . $row["id"];
			if(array_key_exists($name, $privs["resources"]))
				array_push($privs["resources"][$name], $row["privtype"]);
			else
				$privs["resources"][$name] = array($row["privtype"]);
		}
	}
	if($type == "users" || $type == "all") {
		$query = "SELECT t.name AS name, "
		       .        "CONCAT(u.unityid, '@', a.name) AS unityid "
		       . "FROM user u, "
		       .      "userpriv up, "
		       .      "userprivtype t, "
		       .      "affiliation a "
		       . "WHERE up.privnodeid = $node AND "
		       .       "up.userprivtypeid = t.id AND "
		       .       "up.userid = u.id AND "
		       .       "up.userid IS NOT NULL AND "
		       .       "u.affiliationid = a.id "
		       . "ORDER BY u.unityid";
		$qh = doQuery($query, 351);
		while($row = mysql_fetch_assoc($qh)) {
			if(array_key_exists($row["unityid"], $privs["users"])) {
				array_push($privs["users"][$row["unityid"]], $row["name"]);
			}
			else {
				$privs["users"][$row["unityid"]] = array($row["name"]);
			}
		}
	}
	if($type == "usergroups" || $type == "all") {
		$query = "SELECT t.name AS priv, "
		       .        "g.name AS groupname, "
		       .        "g.affiliationid, "
		       .        "a.name AS affiliation, "
		       .        "g.id "
		       . "FROM userpriv up, "
		       .      "userprivtype t, "
		       .      "usergroup g "
		       . "LEFT JOIN affiliation a ON (g.affiliationid = a.id) "
		       . "WHERE up.privnodeid = $node AND "
		       .       "up.userprivtypeid = t.id AND "
		       .       "up.usergroupid = g.id AND "
		       .       "up.usergroupid IS NOT NULL "
		       . "ORDER BY g.name";
		$qh = doQuery($query, 352);
		while($row = mysql_fetch_assoc($qh)) {
			if(array_key_exists($row["groupname"], $privs["usergroups"]))
				array_push($privs["usergroups"][$row["groupname"]]['privs'], $row["priv"]);
			else
				$privs["usergroups"][$row["groupname"]] = array('id' => $row['id'],
				                                                'affiliationid' => $row['affiliationid'],
				                                                'affiliation' => $row['affiliation'],
				                                                'privs' => array($row['priv']));
		}
	}
	$_SESSION['nodeprivileges'][$key] = $privs;
	return $privs;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getNodeCascadePrivileges($node, $type="all", $privs=0)
///
/// \param $node - id of node
/// \param $type - (optional) resources, users, usergroups, or all
/// \param $privs - (optional) privilege array as returned by this function or
/// getNodeCascadePrivileges
///
/// \return an array of privileges cascaded to the node:\n
///Array\n
///(\n
///    [resources] => Array\n
///        (\n
///        )\n
///    [users] => Array\n
///        (\n
///            [userid0] => Array\n
///                (\n
///                    [0] => priv0\n
///                        ...\n
///                    [N] => privN\n
///                )\n
///                ...\n
///            [useridN] => Array()\n
///        )\n
///    [usergroups] => Array\n
///        (\n
///            [group0] => Array\n
///                (\n
///                    [0] => priv0\n
///                        ...\n
///                    [N] => privN\n
///                )\n
///                ...\n
///            [groupN] => Array()\n
///        )\n
///)
///
/// \brief gets the requested cascaded privileges for the specified node
///
////////////////////////////////////////////////////////////////////////////////
function getNodeCascadePrivileges($node, $type="all", $privs=0) {
	$key = getKey(array($node, $type, $privs));
	if(array_key_exists($key, $_SESSION['cascadenodeprivileges']))
		return $_SESSION['cascadenodeprivileges'][$key];
	if(! $privs)
		$privs = array("resources" => array(),
		               "users" => array(),
		               "usergroups" => array());

	# get node's parents
	$nodelist = getParentNodes($node);

	if($type == "resources" || $type == "all") {
		$mynodelist = $nodelist;
		# loop through each node, starting at the root
		while(count($mynodelist)) {
			$node = array_pop($mynodelist);
			# get all resource groups with block set at this node and remove any cascaded privs
			$query = "SELECT g.name AS name, "
			       .        "t.name AS type "
			       . "FROM resourcepriv p, "
			       .      "resourcetype t, "
			       .      "resourcegroup g "
			       . "WHERE p.privnodeid = $node AND "
			       .       "p.resourcegroupid = g.id AND "
			       .       "g.resourcetypeid = t.id AND "
			       .       "p.type = 'block'";

			$qh = doQuery($query, 353);
			while($row = mysql_fetch_assoc($qh)) {
				$name = $row["type"] . "/" . $row["name"];
				unset($privs["resources"][$name]);
			}

			# get all privs for users with cascaded privs
			$query = "SELECT g.id AS id, "
			       .        "p.type AS privtype, "
			       .        "g.name AS name, "
			       .        "t.name AS type "
			       . "FROM resourcepriv p, "
			       .      "resourcetype t, "
			       .      "resourcegroup g "
			       . "WHERE p.privnodeid = $node AND "
			       .       "p.resourcegroupid = g.id AND "
			       .       "g.resourcetypeid = t.id AND "
			       .       "p.type != 'block' AND "
			       .       "p.type != 'cascade' AND "
			       .       "p.resourcegroupid IN (SELECT resourcegroupid "
			       .                             "FROM resourcepriv "
			       .                             "WHERE type = 'cascade' AND "
			       .                                   "privnodeid = $node)";
			$qh = doQuery($query, 354);
			while($row = mysql_fetch_assoc($qh)) {
				$name = $row["type"] . "/" . $row["name"] . "/" . $row["id"];
				// if we've already seen this resource group, add it to the
				# resource group's privs
				if(array_key_exists($name, $privs["resources"]))
					array_push($privs["resources"][$name], $row["privtype"]);
				// if we haven't seen this resource group, create an array containing
				# this priv
				else
					$privs["resources"][$name] = array($row["privtype"]);
			}
		}
	}
	if($type == "users" || $type == "all") {
		$mynodelist = $nodelist;
		# loop through each node, starting at the root
		while(count($mynodelist)) {
			$node = array_pop($mynodelist);
			# get all users with block set at this node and remove any cascaded privs
			$query = "SELECT CONCAT(u.unityid, '@', a.name) AS unityid "
			       . "FROM user u, "
			       .      "userpriv up, "
			       .      "userprivtype t, "
			       .      "affiliation a "
			       . "WHERE up.privnodeid = $node AND "
			       .       "up.userprivtypeid = t.id AND "
			       .       "up.userid = u.id AND "
			       .       "up.userid IS NOT NULL AND "
			       .       "t.name = 'block' AND "
			       .       "u.affiliationid = a.id";
			$qh = doQuery($query, 355);
			while($row = mysql_fetch_assoc($qh)) {
				unset($privs["users"][$row["unityid"]]);
			}

			# get all privs for users with cascaded privs
			$query = "SELECT t.name AS name, "
			       .        "CONCAT(u.unityid, '@', a.name) AS unityid "
			       . "FROM user u, "
			       .      "userpriv up, "
			       .      "userprivtype t, "
			       .      "affiliation a "
			       . "WHERE up.privnodeid = $node AND "
			       .       "up.userprivtypeid = t.id AND "
			       .       "up.userid = u.id AND "
			       .       "u.affiliationid = a.id AND "
			       .       "up.userid IS NOT NULL AND "
			       .       "t.name != 'cascade' AND "
			       .       "t.name != 'block' AND "
			       .       "up.userid IN (SELECT up.userid "
			       .                     "FROM userpriv up, "
			       .                          "userprivtype t "
			       .                     "WHERE up.userprivtypeid = t.id AND "
			       .                           "t.name = 'cascade' AND "
			       .                           "up.privnodeid = $node) "
			       . "ORDER BY u.unityid";
			$qh = doQuery($query, 356);
			while($row = mysql_fetch_assoc($qh)) {
				// if we've already seen this user, add it to the user's privs
				if(array_key_exists($row["unityid"], $privs["users"])) {
					array_push($privs["users"][$row["unityid"]], $row["name"]);
				}
				// if we haven't seen this user, create an array containing this priv
				else {
					$privs["users"][$row["unityid"]] = array($row["name"]);
				}
			}
		}
	}
	if($type == "usergroups" || $type == "all") {
		$mynodelist = $nodelist;
		# loop through each node, starting at the root
		while(count($mynodelist)) {
			$node = array_pop($mynodelist);
			# get all groups with block set at this node and remove any cascaded privs
			$query = "SELECT g.name AS groupname "
			       . "FROM usergroup g, "
			       .      "userpriv up, "
			       .      "userprivtype t "
			       . "WHERE up.privnodeid = $node AND "
			       .       "up.userprivtypeid = t.id AND "
			       .       "up.usergroupid = g.id AND "
			       .       "up.usergroupid IS NOT NULL AND "
			       .       "t.name = 'block'";
			$qh = doQuery($query, 357);
			while($row = mysql_fetch_assoc($qh)) {
				unset($privs["usergroups"][$row["groupname"]]);
			}

			# get all privs for groups with cascaded privs
			$query = "SELECT t.name AS priv, "
			       .        "g.name AS groupname, "
			       .        "g.affiliationid, "
			       .        "a.name AS affiliation, "
			       .        "g.id "
			       . "FROM userpriv up, "
			       .      "userprivtype t, "
			       .      "usergroup g "
			       . "LEFT JOIN affiliation a ON (g.affiliationid = a.id) "
			       . "WHERE up.privnodeid = $node AND "
			       .       "up.userprivtypeid = t.id AND "
			       .       "up.usergroupid = g.id AND "
			       .       "up.usergroupid IS NOT NULL AND "
			       .       "t.name != 'cascade' AND "
			       .       "t.name != 'block' AND "
			       .       "up.usergroupid IN (SELECT up.usergroupid "
			       .                      "FROM userpriv up, "
			       .                           "userprivtype t "
			       .                      "WHERE up.userprivtypeid = t.id AND "
			       .                            "t.name = 'cascade' AND "
			       .                            "up.privnodeid = $node) "
			       . "ORDER BY g.name";
			$qh = doQuery($query, 358);
			while($row = mysql_fetch_assoc($qh)) {
				// if we've already seen this group, add it to the user's privs
				if(array_key_exists($row["groupname"], $privs["usergroups"]))
					array_push($privs["usergroups"][$row["groupname"]]['privs'], $row["priv"]);
				// if we haven't seen this group, create an array containing this priv
				else 
					$privs["usergroups"][$row["groupname"]] = array('id' => $row['id'],
					                                                'affiliationid' => $row['affiliationid'],
					                                                'affiliation' => $row['affiliation'],
					                                                'privs' => array($row['priv']));
			}
		}
	}
	$_SESSION['cascadenodeprivileges'][$key] = $privs;
	return $privs;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJchangeUserPrivs()
///
/// \brief processes input for changes in users' privileges at a specific node,
/// submits the changes to the database returns a call to refreshPerms()
///
////////////////////////////////////////////////////////////////////////////////
function AJchangeUserPrivs() {
	global $user;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("userGrant", $user["id"], $node)) {
		$text = "You do not have rights to modify user privileges at this node.";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	$newuser = processInputVar("item", ARG_STRING);
	$newpriv = processInputVar('priv', ARG_STRING);
	$newprivval = processInputVar('value', ARG_STRING);
	//print "alert('node: $node; newuser: $newuser; newpriv: $newpriv; newprivval: $newprivval');";

	# get cascade privs at this node
	$cascadePrivs = getNodeCascadePrivileges($node, "users");

	// if $newprivval is true and $newuser already has $newpriv
	//   cascaded to it, do nothing
	if($newprivval == 'true') {
		if(array_key_exists($newuser, $cascadePrivs['users']) &&
		   in_array($newpriv, $cascadePrivs['users'][$newuser])) {
			dbDisconnect();
			exit;
		}
		// add priv
		$adds = array($newpriv);
		$removes = array();
	}
	else {
		// remove priv
		$adds = array();
		$removes = array($newpriv);
	}
	updateUserOrGroupPrivs($newuser, $node, $adds, $removes, "user");
	$_SESSION['dirtyprivs'] = 1;
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJchangeUserGroupPrivs()
///
/// \brief processes input for changes in user group privileges at a specific
/// node, submits the changes to the database and calls viewNodes
///
////////////////////////////////////////////////////////////////////////////////
function AJchangeUserGroupPrivs() {
	global $user;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("userGrant", $user["id"], $node)) {
		$text = "You do not have rights to modify user privileges at this node.";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	$newusergrpid = processInputVar("item", ARG_NUMERIC);
	$newusergrp = getUserGroupName($newusergrpid);
	$newpriv = processInputVar('priv', ARG_STRING);
	$newprivval = processInputVar('value', ARG_STRING);
	//print "alert('node: $node; newuser:grp $newuser;grp newpriv: $newpriv; newprivval: $newprivval');";

	# get cascade privs at this node
	$cascadePrivs = getNodeCascadePrivileges($node, "usergroups");

	// if $newprivval is true and $newusergrp already has $newpriv
	//   cascaded to it, do nothing
	if($newprivval == 'true') {
		if(array_key_exists($newusergrp, $cascadePrivs['usergroups']) &&
		   in_array($newpriv, $cascadePrivs['usergroups'][$newusergrp]['privs'])) {
			dbDisconnect();
			exit;
		}
		// add priv
		$adds = array($newpriv);
		$removes = array();
	}
	else {
		// remove priv
		$adds = array();
		$removes = array($newpriv);
	}
	updateUserOrGroupPrivs($newusergrpid, $node, $adds, $removes, "group");
	$_SESSION['dirtyprivs'] = 1;
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJchangeResourcePrivs()
///
/// \brief processes input for changes in resource group privileges at a
/// specific node and submits the changes to the database
///
////////////////////////////////////////////////////////////////////////////////
function AJchangeResourcePrivs() {
	global $user;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("resourceGrant", $user["id"], $node)) {
		$text = "You do not have rights to modify resource privileges at this node.";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	$resourcegrp = processInputVar("item", ARG_STRING);
	$newpriv = processInputVar('priv', ARG_STRING);
	$newprivval = processInputVar('value', ARG_STRING);
	//print "alert('node: $node; resourcegrp: $resourcegrp; newpriv: $newpriv; newprivval: $newprivval');";

	# get cascade privs at this node
	$cascadePrivs = getNodeCascadePrivileges($node, "resources");

	// if $newprivval is true and $resourcegrp already has $newpriv
	//   cascaded to it, do nothing
	if($newprivval == 'true') {
		if(array_key_exists($resourcegrp, $cascadePrivs['resources']) &&
		   in_array($newpriv, $cascadePrivs['resources'][$resourcegrp])) {
			dbDisconnect();
			exit;
		}
		// add priv
		$adds = array($newpriv);
		$removes = array();
	}
	else {
		// remove priv
		$adds = array();
		$removes = array($newpriv);
	}
	$tmpArr = explode('/', $resourcegrp);
	updateResourcePrivs($tmpArr[2], $node, $adds, $removes);
	$_SESSION['dirtyprivs'] = 1;
	dbDisconnect();
	exit;
}
////////////////////////////////////////////////////////////////////////////////
///
/// \fn addUserPriv()
///
/// \brief prints a page for adding privileges to a node for a user
///
////////////////////////////////////////////////////////////////////////////////
/*function addUserPriv() {
	global $submitErr;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	$newuser = processInputVar("newuser", ARG_STRING);
	$tmp = processInputVar("openNodes", ARG_STRING);
	if($tmp != "")
		$openNodes = explode(":", $tmp);
	else
		$openNodes = array(DEFAULT_PRIVNODE);
	$usertypes = getTypes("users");

	$topNodes = getChildNodes();
	print "<H2>Add User</H2>\n";
	recursivePrintNodes($topNodes, $openNodes, $node);
	printSubmitErr(NEWUSERERR);
	printSubmitErr(ADDUSERNOPRIVS);
	print "<FORM action=\"" . BASEURL . SCRIPT . "#users\" method=post>\n";
	print "<TABLE border=1>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH bgcolor=gray>Block<br>Cascaded<br>Rights</TH>\n";
	print "    <TH bgcolor=\"#008000\">Cascade<br>to Child<br>Nodes</TH>\n";
	foreach($usertypes["users"] as $type) {
		$img = getImageText($type);
		print "    <TD>$img</TD>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD><INPUT type=text name=newuser value=\"$newuser\" size=8 ";
	print "maxlength=8></TD>\n";

	# block rights
	$count = count($usertypes) + 1;
	print "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	print "name=block></TD>\n";

	#cascade rights
	print "    <TD align=center bgcolor=\"#008000\" id=usercell0:0>";
	print "<INPUT type=checkbox id=userck0:0 name=cascade ";
	print "></TD>\n";

	# normal rights
	$j = 1;
	foreach($usertypes["users"] as $type) {
		print "    <TD align=center id=usercell0:$j><INPUT type=checkbox ";
		print "name=\"$type\" id=userck0:$j></TD>\n";
		$j++;
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	$openNodes = implode(':', $openNodes);
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD><INPUT type=submit value=\"Submit New User\"></TD>\n";
	print "  </TR>\n";
	# FIXME add javascript to reset button
	print "</TABLE>\n";
	print "<INPUT type=hidden name=mode value=submitAddUserPriv>\n";
	print "<INPUT type=hidden name=activeNode value=$node>\n";
	print "<INPUT type=hidden name=openNodes value=\"$openNodes \">\n";
	print "</FORM>\n";
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddUserPriv()
///
/// \brief processes input for adding privileges to a node for a user; adds the
/// privileges; calls viewNodes
///
////////////////////////////////////////////////////////////////////////////////
/*function submitAddUserPriv() {
	global $submitErr, $submitErrMsg;
	$newuser = processInputVar("newuser", ARG_STRING);
	if(! validateUserid($newuser)) {
		$submitErr |= NEWUSERERR;
		$submitErrMsg[NEWUSERERR] = "<strong>$newuser was not found</strong>";
		addUserPriv();
		return;
	}
	$usertypes = getTypes("users");
	array_push($usertypes["users"], "block");
	array_push($usertypes["users"], "cascade");
	$newuserprivs = array();
	foreach($usertypes["users"] as $type) {
		$tmp = processInputVar($type, ARG_STRING);
		if($tmp == "on")
			array_push($newuserprivs, $type);
	}
	if(empty($newuserprivs) || (count($newuserprivs) == 1 && 
	   in_array("cascade", $newuserprivs))) {
		$submitErr |= ADDUSERNOPRIVS;
		$submitErrMsg[ADDUSERNOPRIVS] = "No user privileges were specified";
		addUserPriv();
		return;
	}

	$node = processInputVar("activeNode", ARG_NUMERIC);
	updateUserOrGroupPrivs($newuser, $node, $newuserprivs, array(), "user");
	clearPrivCache();
	viewNodes();
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitAddUserPriv()
///
/// \brief processes input for adding privileges to a node for a user; adds the
/// privileges; returns call to refreshPerms()
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitAddUserPriv() {
	global $submitErr, $submitErrMsg, $user;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("userGrant", $user["id"], $node)) {
		$text = "You do not have rights to add new users at this node.";
		print "addUserPaneHide(); ";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	$newuser = processInputVar("newuser", ARG_STRING);
	if(! validateUserid($newuser)) {
		$text = "<font color=red>$newuser is not a valid userid</font>";
		print setAttribute('addUserPrivStatus', 'innerHTML', $text);
		dbDisconnect();
		exit;
	}

	$perms = explode(':', processInputVar('perms', ARG_STRING));
	$usertypes = getTypes("users");
	array_push($usertypes["users"], "block");
	array_push($usertypes["users"], "cascade");
	$newuserprivs = array();
	foreach($usertypes["users"] as $type) {
		if(in_array($type, $perms))
			array_push($newuserprivs, $type);
	}
	if(empty($newuserprivs) || (count($newuserprivs) == 1 && 
	   in_array("cascade", $newuserprivs))) {
		$text = "<font color=red>No user privileges were specified</font>";
		print setAttribute('addUserPrivStatus', 'innerHTML', $text);
		dbDisconnect();
		exit;
	}
	$node = processInputVar("activeNode", ARG_NUMERIC);

	updateUserOrGroupPrivs($newuser, $node, $newuserprivs, array(), "user");
	clearPrivCache();
	print "refreshPerms();";
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addUserGroupPriv()
///
/// \brief prints a page for adding privileges to a node for a user group
///
////////////////////////////////////////////////////////////////////////////////
/*function addUserGroupPriv() {
	global $submitErr;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	$newgroup = processInputVar("newgroup", ARG_STRING);
	$tmp = processInputVar("openNodes", ARG_STRING);
	if($tmp != "")
		$openNodes = explode(":", $tmp);
	else
		$openNodes = array(DEFAULT_PRIVNODE);
	$usertypes = getTypes("users");

	$groups = getUserGroups();
	unset($groups["82"]);   // remove the "None" group

	$topNodes = getChildNodes();
	print "<H2>Add User Group</H2>\n";
	recursivePrintNodes($topNodes, $openNodes, $node);
	printSubmitErr(ADDUSERNOPRIVS);
	print "<FORM action=\"" . BASEURL . SCRIPT . "#groups\" method=post>\n";
	print "<TABLE border=1>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH bgcolor=gray>Block<br>Cascaded<br>Rights</TH>\n";
	print "    <TH bgcolor=\"#008000\">Cascade<br>to Child<br>Nodes</TH>\n";
	foreach($usertypes["users"] as $type) {
		$img = getImageText($type);
		print "    <TD>$img</TD>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	printSelectInput("newgroupid", $groups);
	print "    </TD>\n";
	#print "</TD>\n";

	# block rights
	print "    <TD align=center bgcolor=gray><INPUT type=checkbox ";
	print "name=block></TD>\n";

	#cascade rights
	print "    <TD align=center bgcolor=\"#008000\"><INPUT type=checkbox ";
	print "name=cascade></TD>\n";

	# normal rights
	foreach($usertypes["users"] as $type) {
		print "    <TD align=center><INPUT type=checkbox ";
		print "name=\"$type\"></TD>\n";
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	$openNodes = implode(':', $openNodes);
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD><INPUT type=submit value=\"Submit New Group\"></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<INPUT type=hidden name=mode value=submitAddUserGroupPriv>\n";
	print "<INPUT type=hidden name=activeNode value=$node>\n";
	print "<INPUT type=hidden name=openNodes value=\"$openNodes \">\n";
	print "</FORM>\n";
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddUserGroupPriv()
///
/// \brief processes input for adding privileges to a node for a user group;
/// adds the privileges; calls viewNodes
///
////////////////////////////////////////////////////////////////////////////////
/*function submitAddUserGroupPriv() {
	global $submitErr, $submitErrMsg;
	$newgroupid = processInputVar("newgroupid", ARG_NUMERIC);
	$usertypes = getTypes("users");
	array_push($usertypes["users"], "block");
	array_push($usertypes["users"], "cascade");
	$newgroupprivs = array();
	foreach($usertypes["users"] as $type) {
		$tmp = processInputVar($type, ARG_STRING);
		if($tmp == "on")
			array_push($newgroupprivs, $type);
	}
	if(empty($newgroupprivs) || (count($newgroupprivs) == 1 && 
	   in_array("cascade", $newgroupprivs))) {
		$submitErr |= ADDUSERNOPRIVS;
		$submitErrMsg[ADDUSERNOPRIVS] = "No user group privileges were specified";
		addUserGroupPriv();
		return;
	}

	$node = processInputVar("activeNode", ARG_NUMERIC);
	updateUserOrGroupPrivs($newgroupid, $node, $newgroupprivs, array(), "group");
	clearPrivCache();
	viewNodes();
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitAddUserGroupPriv()
///
/// \brief processes input for adding privileges to a node for a user group;
/// adds the privileges; calls viewNodes
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitAddUserGroupPriv() {
	global $user;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("userGrant", $user["id"], $node)) {
		$text = "You do not have rights to add new user groups at this node.";
		print "addUserGroupPaneHide(); ";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	$newgroupid = processInputVar("newgroupid", ARG_NUMERIC);
	# FIXME validate newgroupid

	$perms = explode(':', processInputVar('perms', ARG_STRING));
	$usertypes = getTypes("users");
	array_push($usertypes["users"], "block");
	array_push($usertypes["users"], "cascade");
	$newgroupprivs = array();
	foreach($usertypes["users"] as $type) {
		if(in_array($type, $perms))
			array_push($newgroupprivs, $type);
	}
	if(empty($newgroupprivs) || (count($newgroupprivs) == 1 && 
	   in_array("cascade", $newgroupprivs))) {
		$text = "<font color=red>No user group privileges were specified</font>";
		print setAttribute('addUserGroupPrivStatus', 'innerHTML', $text);
		dbDisconnect();
		exit;
	}

	updateUserOrGroupPrivs($newgroupid, $node, $newgroupprivs, array(), "group");
	clearPrivCache();
	print "addUserGroupPaneHide(); ";
	print "refreshPerms(); ";
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitAddResourcePriv()
///
/// \brief processes input for adding privileges to a node for a resource group;
/// adds the privileges
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitAddResourcePriv() {
	global $user;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("resourceGrant", $user["id"], $node)) {
		$text = "You do not have rights to add new resource groups at this node.";
		print "addUserGroupPaneHide(); ";
		print "alert('$text');";
		dbDisconnect();
		exit;
	}
	$newgroupid = processInputVar("newgroupid", ARG_NUMERIC);
	# FIXME validate newgroupid

	$perms = explode(':', processInputVar('perms', ARG_STRING));
	$privtypes = array("block", "cascade", "available", "administer", "manageGroup");
	$newgroupprivs = array();
	foreach($privtypes as $type) {
		if(in_array($type, $perms))
			array_push($newgroupprivs, $type);
	}
	if(empty($newgroupprivs) || (count($newgroupprivs) == 1 && 
	   in_array("cascade", $newgroupprivs))) {
		$text = "<font color=red>No resource group privileges were specified</font>";
		print setAttribute('addResourceGroupPrivStatus', 'innerHTML', $text);
		dbDisconnect();
		exit;
	}

	updateResourcePrivs($newgroupid, $node, $newgroupprivs, array());
	clearPrivCache();
	print "addResourceGroupPaneHide(); ";
	print "refreshPerms(); ";
	dbDisconnect();
	exit;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkUserHasPriv($priv, $uid, $node, $privs, 
///                               $cascadePrivs)
///
/// \param $priv - privilege to check for
/// \param $uid - numeric id of user
/// \param $node - id of node
/// \param $privs - (optional) privileges at node
/// \param $cascadePrivs - (optional) privileges cascaded to node
///
/// \return 1 if the user has $priv at $node, 0 if not
///
/// \brief checks to see if the user has $priv at $node; if $privs
/// and $cascadePrivs are not passed in, they are looked up for $node
///
////////////////////////////////////////////////////////////////////////////////
function checkUserHasPriv($priv, $uid, $node, $privs=0, $cascadePrivs=0) {
	global $user;
	$key = getKey(array($priv, $uid, $node, $privs, $cascadePrivs));
	if(array_key_exists($key, $_SESSION['userhaspriv']))
		return $_SESSION['userhaspriv'][$key];
	if($user["id"] != $uid)
		$_user = getUserInfo($uid);
	else
		$_user = $user;
	$affilUserid = "{$_user['unityid']}@{$_user['affiliation']}";

	if(! is_array($privs)) {
		$privs = getNodePrivileges($node, 'users');
		$privs = getNodePrivileges($node, 'usergroups', $privs);
	}
	if(! is_array($cascadePrivs)) {
		$cascadePrivs = getNodeCascadePrivileges($node, 'users');
		$cascadePrivs = getNodeCascadePrivileges($node, 'usergroups', $cascadePrivs);
	}
	// if user (has $priv at this node) || 
	# (has cascaded $priv && ! have block at this node) return 1
	if((array_key_exists($affilUserid, $privs["users"]) &&
	   in_array($priv, $privs["users"][$affilUserid])) ||
	   ((array_key_exists($affilUserid, $cascadePrivs["users"]) &&
	   in_array($priv, $cascadePrivs["users"][$affilUserid])) &&
	   (! array_key_exists($affilUserid, $privs["users"]) ||
	   ! in_array("block", $privs["users"][$affilUserid])))) {
		$_SESSION['userhaspriv'][$key] = 1;
		return 1;
	}

	foreach($_user["groups"] as $groupname) {
		// if group (has $priv at this node) ||
		# (has cascaded $priv && ! have block at this node) return 1
		if((array_key_exists($groupname, $privs["usergroups"]) &&
		   in_array($priv, $privs["usergroups"][$groupname]['privs'])) ||
		   ((array_key_exists($groupname, $cascadePrivs["usergroups"]) &&
		   in_array($priv, $cascadePrivs["usergroups"][$groupname]['privs'])) &&
		   (! array_key_exists($groupname, $privs["usergroups"]) ||
		   ! in_array("block", $privs["usergroups"][$groupname]['privs'])))) {
			$_SESSION['userhaspriv'][$key] = 1;
			return 1;
		}
	}
	$_SESSION['userhaspriv'][$key] = 0;
	return 0;
}

?>
