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
	if(! empty($_COOKIE["VCLACTIVENODE"]) &&
		nodeExists($_COOKIE['VCLACTIVENODE']))
		$activeNode = $_COOKIE["VCLACTIVENODE"];
	else {
		$topNodes = getChildNodes();
		if(! count($topNodes))
			abort(53);
		$keys = array_keys($topNodes);
		$defaultActive = array_shift($keys);
		$activeNode = $defaultActive;
	}

	$hasNodeAdmin = checkUserHasPriv("nodeAdmin", $user["id"], $activeNode);
	$hasManagePerms = checkUserHasPerm('Manage Additional User Group Permissions');

	# tree
	if($hasManagePerms) {
		print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
		print "     style=\"width:750px;height:600px\">\n";
		print "<div id=\"privtreetab\" dojoType=\"dijit.layout.ContentPane\" title=\"Privilege Tree\">\n";
	}
	print "<H2>Privilege Tree</H2>\n";
	$cont = addContinuationsEntry('AJrefreshNodeDropData');
	print "<INPUT type=hidden id=refreshnodedropdatacont value=\"$cont\"\n>";
	$cont = addContinuationsEntry('JSONprivnodelist');
	print "<div dojoType=\"dojo.data.ItemFileWriteStore\" url=\"" . BASEURL . SCRIPT . "?continuation=$cont\" jsId=\"nodestore\" id=\"nodestore\">\n";
	print "  <script type=\"dojo/connect\" event=\"onSet\" args=\"node\">\n";
	print "     moveNode(node);\n";
	print "  </script>\n";
	print "</div>\n";
	$cont = addContinuationsEntry('AJmoveNode');
	print "<INPUT type=hidden id=movenodecont value=\"$cont\"\n>";
	print "<div class=privtreediv>\n";
	print "<div dojoType=\"dijit.tree.ForestStoreModel\" jsId=\"nodemodel\" store=\"nodestore\" query=\"{name: '*'}\"></div>\n";
	print "<div id=\"privtreeparent\">\n";
	print "<div dojoType=\"dijit.Tree\" model=\"nodemodel\" showRoot=\"false\" id=privtree dndController=\"dijit.tree.dndSource\">\n";
	print "  <script type=\"dojo/connect\" event=\"focusNode\" args=\"node\">\n";
	print "    nodeSelect(node);\n";
	print "  </script>\n";
	print "  <script type=\"dojo/method\" event=\"_onExpandoClick\" args=\"message\">\n";
	print "    var node = message.node;\n";
	print "    var addclass = 0;\n";
	print "    var focusid = node.tree.lastFocused.item.name;\n";
	print "    if(node.isExpanded){\n";
	print "      if(isChildFocused(focusid, node.item.children)) {\n";
	print "        this.focusNode(node);\n";
	print "        addclass = 1;\n";
	print "      }\n";
	print "      this._collapseNode(node);\n";
	print "    }else{\n";
	print "      this._expandNode(node);\n";
	print "    }\n";
	print "  </script>\n";
	print "  <script type=\"dojo/connect\" event=\"startup\" args=\"item\">\n";
	print "    focusFirstNode($activeNode);\n";
	print "  </script>\n";
	print "  <script type=\"dojo/method\" event=\"checkAcceptance\" args=\"tree, domnodes\">\n";
	print "    return checkCanMove(tree, domnodes);\n";
	print "  </script>\n";
	print "  <script type=\"dojo/method\" event=\"checkItemAcceptance\" args=\"domnode, tree, position\">\n";
	print "    return checkNodeDrop(domnode, tree, position);\n";
	print "  </script>\n";
	print "  <script type=\"dojo/connect\" event=\"_onNodeMouseEnter\" args=\"item, evt\">\n";
	print "    dragnode.hoverid = item.item.name[0];\n";
	print "  </script>\n";
	print "  <script type=\"dojo/connect\" event=\"_onNodeMouseLeave\" args=\"item, evt\">\n";
	print "    dragnode.hoverid = 0;\n";
	print "  </script>\n";
	print "  <script type=\"dojo/connect\" event=\"onMouseDown\" args=\"evt\">\n";
	print "    mouseDown(evt);\n";
	print "  </script>\n";
	print "  <script type=\"dojo/connect\" event=\"onMouseUp\" args=\"evt\">\n";
	print "    mouseRelease(evt);\n";
	print "  </script>\n";
	print "  <script type=\"dojo/connect\" event=\"onMouseLeave\" args=\"evt\">\n";
	print "    mouseontree = 0;\n";
	print "  </script>\n";
	print "  <script type=\"dojo/connect\" event=\"onMouseEnter\" args=\"evt\">\n";
	print "    mouseontree = 1;\n";
	print "  </script>\n";
	print "</div>\n";
	print "</div>\n"; # privtreeparent
	print "</div>\n";
	print "<div id=ddloading>Loading Drag and Drop data...</div>\n";
	print "<div id=treebuttons>\n";
	print "<TABLE summary=\"\" cellspacing=\"\" cellpadding=\"\">\n";
	print "  <TR valign=top>\n";
	if($hasNodeAdmin) {
		print "    <TD>\n";
		print "    <button id=addNodeBtn dojoType=\"dijit.form.Button\" disabled=\"true\">\n";
		print "      Add Child\n";
		print "      <script type=\"dojo/method\" event=onClick>\n";
		print "        showPrivPane('addNodePane');\n";
		print "        return false;\n";
		print "      </script>\n";
		print "    </button>\n";
		print "    </TD>\n";
		print "    <TD>\n";
		print "    <button id=deleteNodeBtn dojoType=\"dijit.form.Button\">\n";
		print "      Delete Node and Children\n";
		print "      <script type=\"dojo/method\" event=onClick>\n";
		print "        dijit.byId('deleteDialog').show();\n";
		print "        return false;\n";
		print "      </script>\n";
		print "    </button>\n";
		print "    </TD>\n";
		print "    <TD>\n";
		print "    <button id=renameNodeBtn dojoType=\"dijit.form.Button\">\n";
		print "      Rename Node\n";
		print "      <script type=\"dojo/method\" event=onClick>\n";
		print "        dijit.byId('renameDialog').show();\n";
		print "        return false;\n";
		print "      </script>\n";
		print "    </button>\n";
		print "    </TD>\n";
	}
	print "    <td>\n";
	print "    <button id=\"revertMoveNodeBtn\" dojoType=\"dijit.form.Button\" disabled=\"true\">\n";
	print "      Undo Move\n";
	print "      <script type=\"dojo/method\" event=onClick>\n";
	print "        dijit.byId('revertMoveNodeDlg').show();\n";
	print "      </script>\n";
	print "    </button>\n";
	print "    </td>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "</div>\n";
	$cont = addContinuationsEntry('selectNode');
	print "<INPUT type=hidden id=nodecont value=\"$cont\">\n";

	# privileges
	print "<H2>Privileges at Selected Node</H2>\n";
	$node = $activeNode;
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
		print "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
		print "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
		foreach($usertypes["users"] as $type) {
			if($type == 'configAdmin')
				continue;
			print "    <TH class=\"privheader\"><div><span>$type</span></div></TH>\n";
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
		print "<button id=addUserBtn dojoType=\"dijit.form.Button\">\n";
		print "  Add User\n";
		print "  <script type=\"dojo/method\" event=onClick>\n";
		print "    showPrivPane('addUserPane');\n";
		print "    return false;\n";
		print "  </script>\n";
		print "</button>\n";
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
		print "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
		print "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
		foreach($usertypes["users"] as $type) {
			if($type == 'configAdmin')
				continue;
			print "    <TH class=\"privheader\"><div><span>$type</span></div></TH>\n";
		}
		print "  </TR>\n";
		$groupids = array_unique(array_merge(array_keys($privs["usergroups"]), 
		                         array_keys($cascadePrivs["usergroups"])));
		$allids = implode(',', $groupids);
		$query = "SELECT id "
		       . "FROM usergroup "
		       . "WHERE id IN ($allids) "
		       . "ORDER BY name";
		$qh = doQuery($query);
		$orderedgroups = array();
		while($row = mysql_fetch_assoc($qh))
			$orderedgroups[] = $row['id'];
		foreach($orderedgroups as $id) {
			printUserPrivRow($id, $i, $privs["usergroups"], $usertypes["users"],
			                $cascadePrivs["usergroups"], 'group', ! $hasUserGrant);
			$i++;
		}
		print "</TABLE>\n";
		print "<div id=lastUserGroupNum class=hidden>" . ($i - 1) . "</div>";
		if($hasUserGrant) {
			$cont = addContinuationsEntry('AJchangeUserGroupPrivs');
			print "<INPUT type=hidden id=changeusergroupprivcont value=\"$cont\">\n";
		}
		$cont = addContinuationsEntry('jsonGetUserGroupMembers');
		print "<INPUT type=hidden id=ugmcont value=\"$cont\">\n";
	}
	else {
		print "There are no user group privileges at the selected node.<br>\n";
		$groups = array();
	}
	if($hasUserGrant) {
		print "<button id=addGroupBtn dojoType=\"dijit.form.Button\">\n";
		print "  Add Group\n";
		print "  <script type=\"dojo/method\" event=onClick>\n";
		print "    showPrivPane('addUserGroupPane');\n";
		print "    return false;\n";
		print "  </script>\n";
		print "</button>\n";
	}
	print "</FORM>\n";
	print "</div>\n";

	# resources
	$resourcetypes = getResourcePrivs();
	print "<A name=\"resources\"></a>\n";
	print "<div id=resourcesDiv>\n";
	print "<H3>Resources</H3>\n";
	print "<FORM id=resourceForm action=\"" . BASEURL . SCRIPT . "#resources\" method=post>\n";
	if(count($privs["resources"]) || count($cascadePrivs["resources"])) {
		print "<TABLE border=1 summary=\"\">\n";
		print "  <TR>\n";
		print "    <TH>Group<br>Name</TH>\n";
		print "    <TH>Group<br>Type</TH>\n";
		print "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
		print "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
		foreach($resourcetypes as $type) {
			if($type == 'block' || $type == 'cascade')
				continue;
			print "    <TH class=\"privheader\"><div><span>$type</span></div></TH>\n";
		}
		print "  </TR>\n";
		$resources = array_unique(array_merge(array_keys($privs["resources"]), 
		                          array_keys($cascadePrivs["resources"])));
		sort($resources);
		$resourcegroups = getResourceGroups();
		$resgroupmembers = getResourceGroupMembers();
		foreach($resources as $resource) {
			$data = getResourcePrivRowHTML($resource, $i, $privs["resources"],
			                               $resourcetypes, $resourcegroups,
			                               $resgroupmembers, $cascadePrivs["resources"],
			                               ! $hasResourceGrant);
			print $data['html'];
			print "<script language=\"Javascript\">\n";
			print "dojo.addOnLoad(function () {setTimeout(\"{$data['javascript']}\", 500)});\n";
			print "</script>\n";
			$i++;
		}
		print "</TABLE>\n";
		if($hasResourceGrant) {
			$cont = addContinuationsEntry('AJchangeResourcePrivs');
			print "<INPUT type=hidden id=changeresourceprivcont value=\"$cont\">\n";
		}
		$cont = addContinuationsEntry('jsonGetResourceGroupMembers');
		print "<INPUT type=hidden id=rgmcont value=\"$cont\">\n";
	}
	else {
		print "There are no resource group privileges at the selected node.<br>\n";
		$resources = array();
	}
	if($hasResourceGrant) {
		print "<button id=addResourceBtn dojoType=\"dijit.form.Button\">\n";
		print "  Add Resource Group\n";
		print "  <script type=\"dojo/method\" event=onClick>\n";
		print "    showPrivPane('addResourceGroupPane');\n";
		print "    return false;\n";
		print "  </script>\n";
		print "</button>\n";
	}
	print "</FORM>\n";
	print "</div>\n";
	print "</div>\n";

	# ----------------------------- dialogs ----------------------------
	print "<div dojoType=dijit.Dialog\n";
	print "      id=addUserPane\n";
	print "      title=\"Add User Permission\"\n";
	print "      duration=250\n";
	print "      draggable=true>\n";
	print "    <script type=\"dojo/connect\" event=onCancel>\n";
	print "      addUserPaneHide();\n";
	print "    </script>\n";
	print "<H2>Add User</H2>\n";
	print "<div id=addPaneNodeName></div>\n";
	print "<TABLE border=1 summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
	print "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
	foreach($usertypes["users"] as $type) {
		if($type == 'configAdmin')
			continue;
		print "    <TH class=\"privheader\"><div><span>$type</span></div></TH>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD><INPUT type=text id=newuser name=newuser size=15";
	print "></TD>\n";

	# block rights
	$count = count($usertypes) + 1;
	print "    <TD class=\"privBlock\" align=center bgcolor=gray><INPUT type=checkbox ";
	print "dojoType=dijit.form.CheckBox id=blockchk name=block></TD>\n";

	#cascade rights
	print "    <TD class=\"privCascade\" align=center bgcolor=\"#008000\" id=usercell0:0>";
	print "<INPUT type=checkbox dojoType=dijit.form.CheckBox id=userck0:0 ";
	print "name=cascade></TD>\n";

	# normal rights
	$j = 1;
	foreach($usertypes["users"] as $type) {
		if($type == 'configAdmin')
			continue;
		print "    <TD align=center id=usercell0:$j><INPUT type=checkbox ";
		print "dojoType=dijit.form.CheckBox name=\"$type\" id=userck0:$j></TD>\n";
		$j++;
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<div id=addUserPrivStatus></div>\n";
	print "<TABLE class=\"noborder\" summary=\"\"><TR>\n";
	print "<TD>\n";
	print "  <button id=submitAddUserBtn dojoType=\"dijit.form.Button\">\n";
	print "    Submit New User\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      submitAddUser();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "<TD>\n";
	print "  <button id=cancelAddUserBtn dojoType=\"dijit.form.Button\">\n";
	print "    Cancel\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      addUserPaneHide();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitAddUserPriv');
	print "<INPUT type=hidden id=addusercont value=\"$cont\">\n";
	print "</div>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "      id=addUserGroupPane\n";
	print "      title=\"Add User Group Permission\"\n";
	print "      duration=250\n";
	print "      draggable=true>\n";
	print "    <script type=\"dojo/connect\" event=onCancel>\n";
	print "      addUserGroupPaneHide();\n";
	print "    </script>\n";
	print "<H2>Add User Group</H2>\n";
	print "<div id=addGroupPaneNodeName></div>\n";
	print "<TABLE border=1 summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
	print "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
	foreach($usertypes["users"] as $type) {
		if($type == 'configAdmin')
			continue;
		print "    <TH class=\"privheader\"><div><span>$type</span></div></TH>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	# FIXME should $groups be only the user's groups?
	$groups = getUserGroups(0, $user['affiliationid']);
	printSelectInput("newgroupid", $groups, -1, 0, 0, 'newgroupid');
	print "    </TD>\n";

	# block rights
	print "    <TD class=\"privBlock\" align=center bgcolor=gray><INPUT type=checkbox ";
	print "dojoType=dijit.form.CheckBox id=blockgrpchk name=blockgrp></TD>\n";

	#cascade rights
	print "    <TD class=\"privCascade\" align=center bgcolor=\"#008000\" id=grpcell0:0>";
	print "<INPUT type=checkbox dojoType=dijit.form.CheckBox id=usergrpck0:0 ";
	print "name=cascadegrp></TD>\n";

	# normal rights
	$j = 1;
	foreach($usertypes["users"] as $type) {
		if($type == 'configAdmin')
			continue;
		print "    <TD align=center id=usergrpcell0:$j><INPUT type=checkbox ";
		print "dojoType=dijit.form.CheckBox name=\"$type\" id=usergrpck0:$j></TD>\n";
		$j++;
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<div id=addUserGroupPrivStatus></div>\n";
	print "<TABLE class=\"noborder\" summary=\"\"><TR>\n";
	print "<TD>\n";
	print "  <button id=submitAddGroupBtn dojoType=\"dijit.form.Button\">\n";
	print "    Submit New User Group\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      submitAddUserGroup();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "<TD>\n";
	print "  <button id=cancelAddGroupBtn dojoType=\"dijit.form.Button\">\n";
	print "    Cancel\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      addUserGroupPaneHide();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitAddUserGroupPriv');
	print "<INPUT type=hidden id=addusergroupcont value=\"$cont\">\n";
	print "</div>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "      id=addResourceGroupPane\n";
	print "      title=\"Add Resource Group Permission\"\n";
	print "      duration=250\n";
	print "      draggable=true>\n";
	print "    <script type=\"dojo/connect\" event=onCancel>\n";
	print "      addResourceGroupPaneHide();\n";
	print "    </script>\n";
	print "<H2>Add Resource Group</H2>\n";
	print "<div id=addResourceGroupPaneNodeName></div>\n";
	print "<TABLE border=1 summary=\"\">\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>\n";
	print "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>\n";
	foreach($resourcetypes as $type) {
		if($type == 'block' || $type == 'cascade')
			continue;
		print "    <TH class=\"privheader\"><div><span>$type</span></div></TH>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	$resources = array();
	$privs = array("computerAdmin", "mgmtNodeAdmin", "imageAdmin",
	               "scheduleAdmin", "serverProfileAdmin");
	$resourcesgroups = getUserResources($privs, array("manageGroup"), 1);
	foreach(array_keys($resourcesgroups) as $type) {
		foreach($resourcesgroups[$type] as $id => $group) {
			$resources[$id] = $type . "/" . $group;
		}
	}
	printSelectInput("newresourcegroupid", $resources, -1, 0, 0, 'newresourcegroupid');
	print "    </TD>\n";

	# block rights
	print "    <TD class=\"privBlock\" align=center bgcolor=gray><INPUT type=checkbox ";
	print "dojoType=dijit.form.CheckBox id=blockresgrpck name=blockresgrp></TD>\n";

	#cascade rights
	print "    <TD class=\"privCascade\" align=center bgcolor=\"#008000\" id=resgrpcell0:0>";
	print "<INPUT type=checkbox dojoType=dijit.form.CheckBox id=resgrpck0:0 ";
	print "name=cascaderesgrp></TD>\n";

	# normal rights
	$i = 1;
	foreach($resourcetypes as $type) {
		if($type == 'block' || $type == 'cascade')
			continue;
		print "    <TD align=center id=resgrpcell0:$i><INPUT type=checkbox ";
		print "dojoType=dijit.form.CheckBox name=$type id=resgrpck0:$i></TD>\n";
		$i++;
	}
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<div id=addResourceGroupPrivStatus></div>\n";
	print "<TABLE class=\"noborder\" summary=\"\"><TR>\n";
	print "<TD>\n";
	print "  <button dojoType=\"dijit.form.Button\">\n";
	print "    Submit New Resource Group\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      submitAddResourceGroup();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "<TD>\n";
	print "  <button dojoType=\"dijit.form.Button\">\n";
	print "    Cancel\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      addResourceGroupPaneHide();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitAddResourcePriv');
	print "<INPUT type=hidden id=addresourcegroupcont value=\"$cont\">\n";
	print "</div>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "     id=addNodePane\n";
	print "     title=\"Add Child Node\"\n";
	print "     duration=250\n";
	print "     draggable=true>\n";
	print "<H2>Add Child Node</H2>\n";
	print "<div id=addChildNodeName></div>\n";
	print "<strong>New Node:</strong>\n";
	print "<input type=text id=childNodeName dojoType=dijit.form.TextBox>\n";
	print "  <script type=\"dojo/connect\" event=onKeyPress args=\"e\">\n";
	print "    if(e.keyCode == dojo.keys.ENTER) {\n";
	print "      submitAddChildNode();\n";
	print "    }\n";
	print "  </script>\n";
	print "</input>\n";
	print "<div id=addChildNodeStatus></div>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD>\n";
	print "  <button id=submitAddNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Create Child\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      submitAddChildNode();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "<TD>\n";
	print "  <button id=cancelAddNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Cancel\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      dojo.byId('childNodeName').value = '';\n";
	print "      dojo.byId('addChildNodeStatus').innerHTML = '';\n";
	print "      dijit.byId('addNodePane').hide();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitAddChildNode');
	print "<INPUT type=hidden id=addchildcont value=\"$cont\"\n>";
	print "</div>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "     id=deleteDialog\n";
	print "     title=\"Delete Node(s)\"\n";
	print "     duration=250\n";
	print "     draggable=true>\n";
	print "Delete the following node and all of its children?<br><br>\n";
	print "<div id=deleteNodeName></div><br>\n";
	print "<div align=center>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD>\n";
	print "  <button id=submitDeleteNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Delete Nodes\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      deleteNodes();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "<TD>\n";
	print "  <button id=cancelDeleteNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Cancel\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      dijit.byId('deleteDialog').hide();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitDeleteNode');
	print "<INPUT type=hidden id=delchildcont value=\"$cont\"\n>";
	print "</div>\n";
	print "</div>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "     id=renameDialog\n";
	print "     title=\"Rename Node\"\n";
	print "     duration=250\n";
	print "     draggable=true>\n";
	print "Enter a new name for the selected node:<br><br>\n";
	print "<div id=renameNodeName></div><br>\n";
	print "<strong>New Name:</strong>\n";
	print "<input type=text id=newNodeName dojoType=dijit.form.TextBox>\n";
	print "  <script type=\"dojo/connect\" event=onKeyPress args=\"e\">\n";
	print "    if(e.keyCode == dojo.keys.ENTER) {\n";
	print "      renameNode();\n";
	print "    }\n";
	print "  </script>\n";
	print "</input>\n";
	print "<div id=renameNodeStatus></div>\n";
	print "<div align=center>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD>\n";
	print "  <button id=submitRenameNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Rename Node\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      renameNode();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "<TD>\n";
	print "  <button id=cancelRenameNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Cancel\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      dijit.byId('renameDialog').hide();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	$cont = addContinuationsEntry('AJsubmitRenameNode');
	print "<INPUT type=hidden id=renamecont value=\"$cont\"\n>";
	print "</div>\n";
	print "</div>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "     id=moveDialog\n";
	print "     title=\"Move Node(s)\"\n";
	print "     duration=250\n";
	print "     draggable=true>\n";
	print "Move the following node and all of its children?<br><br>\n";
	print "<label for=moveNodeName>Node:</label>\n";
	print "<span id=moveNodeName></span><br>\n";
	print "<label for=moveNodeOldParentName>Old Parent:</label>\n";
	print "<span id=moveNodeOldParentName></span><br>\n";
	print "<label for=moveNodeNewParentName>New Parent:</label>\n";
	print "<span id=moveNodeNewParentName></span><br><br>\n";
	print "<div align=center>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD>\n";
	print "  <button id=submitMoveNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Move Node(s)\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      submitMoveNode();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "<TD>\n";
	print "  <button id=cancelMoveNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Cancel\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      revertNodeMove();\n";
	print "      dijit.byId('moveDialog').hide();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	print "<INPUT type=hidden id=movenodesubmitcont>\n";
	print "</div>\n";
	print "</div>\n";

	print "<div dojoType=dijit.Dialog\n";
	print "     id=revertMoveNodeDlg\n";
	print "     title=\"Undo Move Node(s)\"\n";
	print "     duration=250\n";
	print "     draggable=true>\n";
	print "Undo the previous node move?<br><br>\n";
	print "<div align=center>\n";
	print "<TABLE summary=\"\"><TR>\n";
	print "<TD>\n";
	print "  <button id=submitRevertMoveNodeBtn dojoType=\"dijit.form.Button\">\n";
	print "    Undo Move\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      submitRevertMoveNode();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "<TD>\n";
	print "  <button dojoType=\"dijit.form.Button\">\n";
	print "    Cancel\n";
	print "    <script type=\"dojo/method\" event=onClick>\n";
	print "      dijit.byId('revertMoveNodeDlg').hide();\n";
	print "    </script>\n";
	print "  </button>\n";
	print "</TD>\n";
	print "</TR></TABLE>\n";
	print "<INPUT type=\"hidden\" id=\"revertmovenodecont\">\n";
	print "</div>\n";
	print "</div>\n";

	print "<div dojoType=dijit.Dialog id=workingDialog duration=250 refocus=False>\n";
	print "Loading...\n";
	print "  <script type=\"dojo/connect\" event=_setup>\n";
	print "    dojo.addClass(dijit.byId('workingDialog').titleBar, 'hidden');\n";
	print "  </script>\n";
	print "</div>\n";
	if(! $hasManagePerms)
		return;
	print "</div>\n"; # end privtree tab

	print "<div id=\"userpermtab\" dojoType=\"dijit.layout.ContentPane\" title=\"Additional User Permissions\">\n";
	print "<h2>Additional User Group Permissions</h2>\n";
	print "There are additional permisssions that can be assigned to user<br>\n";
	print "groups that are not specific to any nodes in the privilege tree.<br>\n";
	print "Use this portion of the site to manage those permissions.<br><br>\n";
	printSelectInput("editusergroupid", $groups, -1, 0, 0, 'editusergroupid', 'onChange="hideUserGroupPrivs();"');
	$cont = addContinuationsEntry('AJpermSelectUserGroup');
	print "<button dojoType=\"dijit.form.Button\">\n";
	print "  Manage User Group Permissions\n";
	print "  <script type=\"dojo/method\" event=onClick>\n";
	print "    selectUserGroup('$cont');\n";
	print "  </script>\n";
	print "</button>\n";
	print "<div id=\"extrapermsdiv\">\n";
	print "<table summary=\"\">\n";
	print "<tr>\n";
	print "<td nowrap>\n";
	print "<div id=\"usergroupprivs\" class=\"groupprivshidden\">\n";
	$privtypes = getUserGroupPrivTypes();
	foreach($privtypes as $id => $type) {
		print "<span onMouseOver=\"showUserGroupPrivHelp('{$type['help']}', $id);\" \n";
		print "onMouseOut=\"clearUserGroupPrivHelp($id);\" id=\"grouptypespan$id\">\n";
		print "<input id=\"grouptype$id\" dojoType=\"dijit.form.CheckBox\" ";
		print "value=\"1\" name=\"$id\"><label for=\"grouptype$id\">{$type['name']}";
		print "</label></span><br>\n";
	}
	print "</div>\n";
	print "</td>\n";
	print "<td id=\"groupprivhelpcell\">\n";
	print "<fieldset style=\"height: 100%\";>\n";
	print "<legend>Permission Description</legend>\n";
	print "<div id=\"groupprivhelp\"></div>\n";
	print "</fieldset>\n";
	print "</td>\n";
	print "</tr>\n";
	print "</table><br><br>\n";
	print "Copy permissions from user group: ";
	printSelectInput("copyusergroupid", $groups, -1, 0, 0, 'copyusergroupid');
	$cont = addContinuationsEntry('AJpermSelectUserGroup');
	print "<button dojoType=\"dijit.form.Button\" id=\"usergroupcopyprivsbtn\" disabled>\n";
	print "  Copy Permissions\n";
	print "  <script type=\"dojo/method\" event=onClick>\n";
	print "    copyUserGroupPrivs('$cont');\n";
	print "  </script>\n";
	print "</button><br><br>\n";
	$cont = addContinuationsEntry('AJsaveUserGroupPrivs');
	print "<button dojoType=\"dijit.form.Button\" id=\"usergroupsaveprivsbtn\" disabled>\n";
	print "  Save Selected Permissions\n";
	print "  <script type=\"dojo/method\" event=onClick>\n";
	print "    saveUserGroupPrivs('$cont');\n";
	print "  </script>\n";
	print "</button><br>\n";
	print "<span id=\"userpermsubmitstatus\"></span>\n";
	print "</div>\n";
	print "</div>\n"; # end userperm tab

	print "</div>\n"; # end tab container
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
	if(empty($node))
		return;
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

	$text .= "<TABLE>";
	$text .= "  <TR valign=top>";
	if($hasNodeAdmin) {
		$text .= "    <TD><FORM action=\"" . BASEURL . SCRIPT . "\" method=post>";
		$text .= "    <button id=addNodeBtn dojoType=\"dijit.form.Button\">";
		$text .= "      Add Child";
		$text .= "      <script type=\"dojo/method\" event=onClick>";
		$text .= "        showPrivPane(\"addNodePane\");";
		$text .= "        return false;";
		$text .= "      </script>";
		$text .= "    </button>";
		$text .= "    </FORM></TD>";
		$text .= "    <TD><FORM action=\"" . BASEURL . SCRIPT . "\" method=post>";
		$text .= "    <button id=deleteNodeBtn dojoType=\"dijit.form.Button\">";
		$text .= "      Delete Node and Children";
		$text .= "      <script type=\"dojo/method\" event=onClick>";
		$text .= "        dijit.byId(\"deleteDialog\").show();";
		$text .= "        return false;";
		$text .= "      </script>";
		$text .= "    </button>";
		$text .= "    </FORM></TD>";
		$text .= "    <TD><FORM action=\"" . BASEURL . SCRIPT . "\" method=post>";
		$text .= "    <button id=renameNodeBtn dojoType=\"dijit.form.Button\">";
		$text .= "      Rename Node";
		$text .= "      <script type=\"dojo/method\" event=onClick>";
		$text .= "        dijit.byId(\"renameDialog\").show();";
		$text .= "        return false;";
		$text .= "      </script>";
		$text .= "    </button>";
		$text .= "    </FORM></TD>";
	}
	$text .= "    <td>";
	$text .= "    <button id=\"revertMoveNodeBtn\" dojoType=\"dijit.form.Button\" disabled=\"true\">";
	$text .= "      Undo Move";
	$text .= "      <script type=\"dojo/method\" event=onClick>";
	$text .= "        dijit.byId(\"revertMoveNodeDlg\").show();";
	$text .= "      </script>";
	$text .= "    </button>";
	$text .= "    </td>";
	$text .= "  </TR>";
	$text .= "</TABLE>";
	$return .= "if(dijit.byId('addNodeBtn')) dijit.byId('addNodeBtn').destroy();";
	$return .= "if(dijit.byId('deleteNodeBtn')) dijit.byId('deleteNodeBtn').destroy();";
	$return .= "if(dijit.byId('renameNodeBtn')) dijit.byId('renameNodeBtn').destroy();";
	$return .= "if(dijit.byId('revertMoveNodeBtn')) dijit.byId('revertMoveNodeBtn').destroy();";
	$return .= setAttribute('treebuttons', 'innerHTML', $text);
	$return .= "AJdojoCreate('treebuttons');";

	# privileges
	$return .= "dojo.query('*', 'nodePerms').forEach(function(item){if(dijit.byId(item.id)) dijit.byId(item.id).destroy();});";
	$text = "";
	$text .= "<H3>Users</H3>";
	$users = array();
	if(count($privs["users"]) || count($cascadePrivs["users"])) {
		$text .= "<FORM id=usersform action=\"" . BASEURL . SCRIPT . "#users\" method=post>";
		$text .= "<TABLE border=1 summary=\"\">";
		$text .= "  <TR>";
		$text .= "    <TD></TD>";
		$text .= "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>";
		$text .= "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>";
		foreach($usertypes["users"] as $type) {
			if($type == 'configAdmin')
				continue;
			$text .= "    <TH class=\"privheader\"><div><span>$type</span></div></TH>";
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
		$text .= "<button id=addUserBtn dojoType=\"dijit.form.Button\">";
		$text .= "  Add User";
		$text .= "  <script type=\"dojo/method\" event=onClick>";
		$text .= "    showPrivPane(\"addUserPane\");";
		$text .= "    return false;";
		$text .= "  </script>";
		$text .= "</button>";
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
		$text .= "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>";
		$text .= "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>";
		foreach($usertypes["users"] as $type) {
			if($type == 'configAdmin')
				continue;
			$text .= "    <TH class=\"privheader\"><div><span>$type</span></div></TH>";
		}
		$text .= "  </TR>";
		$groupids = array_unique(array_merge(array_keys($privs["usergroups"]), 
		                         array_keys($cascadePrivs["usergroups"])));
		$allids = implode(',', $groupids);
		$query = "SELECT id "
		       . "FROM usergroup "
		       . "WHERE id IN ($allids) "
		       . "ORDER BY name";
		$qh = doQuery($query);
		$orderedgroups = array();
		while($row = mysql_fetch_assoc($qh))
			$orderedgroups[] = $row['id'];
		foreach($orderedgroups as $id) {
			$tmpArr = getUserPrivRowHTML($id, $i, $privs["usergroups"],
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
		$cont = addContinuationsEntry('jsonGetUserGroupMembers');
		$text .= "<INPUT type=hidden id=ugmcont value=\"$cont\">";
	}
	else {
		$text .= "There are no user group privileges at the selected node.<br>";
		$groups = array();
	}
	if($hasUserGrant) {
		$text .= "<button id=addGroupBtn dojoType=\"dijit.form.Button\">";
		$text .= "  Add Group";
		$text .= "  <script type=\"dojo/method\" event=onClick>";
		$text .= "    showPrivPane(\"addUserGroupPane\");";
		$text .= "    return false;";
		$text .= "  </script>";
		$text .= "</button>";
	}
	$text .= "</FORM>";
	$return .= setAttribute('usergroupsDiv', 'innerHTML', $text);
	$return .= "AJdojoCreate('usergroupsDiv');";

	# resources
	$text = "";
	$resourcetypes = getResourcePrivs();
	$text .= "<H3>Resources</H3>";
	$text .= "<FORM id=resourceForm action=\"" . BASEURL . SCRIPT . "#resources\" method=post>";
	if(count($privs["resources"]) || count($cascadePrivs["resources"])) {
		$text .= "<TABLE border=1 summary=\"\">";
		$text .= "  <TR>";
		$text .= "    <TH>Group<br>Name</TH>";
		$text .= "    <TH>Group<br>Type</TH>";
		$text .= "    <TH class=\"privBlock\" bgcolor=gray style=\"color: black;\">Block<br>Cascaded<br>Rights</TH>";
		$text .= "    <TH class=\"privCascade\" bgcolor=\"#008000\" style=\"color: black;\">Cascade<br>to Child<br>Nodes</TH>";
		foreach($resourcetypes as $type) {
			if($type == 'block' || $type == 'cascade')
				continue;
			$text .= "    <TH class=\"privheader\"><div><span>$type</span></div></TH>";
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
			$html = str_replace("\n", '', $tmpArr['html']);
			$html = str_replace("'", "\'", $html);
			$html = preg_replace("/>\s*</", "><", $html);
			$text .= $html;
			$js .= $tmpArr['javascript'];
			$i++;
		}
		$text .= "</TABLE>";
		if($hasResourceGrant) {
			$cont = addContinuationsEntry('AJchangeResourcePrivs');
			$text .= "<INPUT type=hidden id=changeresourceprivcont value=\"$cont\">";
		}
		$cont = addContinuationsEntry('jsonGetResourceGroupMembers');
		$text .= "<INPUT type=hidden id=rgmcont value=\"$cont\">";
	}
	else {
		$text .= "There are no resource group privileges at the selected node.<br>";
		$resources = array();
	}
	if($hasResourceGrant) {
		$text .= "<button id=addResourceBtn dojoType=\"dijit.form.Button\">";
		$text .= "  Add Resource Group";
		$text .= "  <script type=\"dojo/method\" event=onClick>";
		$text .= "    showPrivPane(\"addResourceGroupPane\");";
		$text .= "    return false;";
		$text .= "  </script>";
		$text .= "</button>";
	}
	$text .= "</FORM>";
	$return .= setAttribute('resourcesDiv', 'innerHTML', $text);
	$return .= "AJdojoCreate('resourcesDiv');";

	$js .= "if(typeof moveitem != 'undefined') ";
	$js .= "{dijit.byId('revertMoveNodeBtn').set('disabled', false);}";

	print $return;
	print $js;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn JSONprivnodelist()
///
/// \brief prints a json list of privilege nodes
///
////////////////////////////////////////////////////////////////////////////////
function JSONprivnodelist() {
	$nodes = getChildNodes();
	$data = JSONprivnodelist2($nodes);
	header('Content-Type: text/json; charset=utf-8');
	$data = "{} && {label:'display',identifier:'name',items:[$data]}";
	print $data;
}


////////////////////////////////////////////////////////////////////////////////
///
/// \fn JSONprivnodelist2($nodelist)
///
/// \param $nodelist - an array of nodes as returned from getChildNodes
///
/// \return partial json data to build list for JSONprivnodelist
///
/// \brief sub function for JSONprivnodelist to help build json node data
///
////////////////////////////////////////////////////////////////////////////////
function JSONprivnodelist2($nodelist) {
	$data = '';
	foreach(array_keys($nodelist) as $id) {
		$nodeinfo = getNodeInfo($id);
		$data .= "{name:'$id', display:'{$nodelist[$id]['name']}', parent:'{$nodeinfo['parent']}'";
		$children = getChildNodes($id);
		if(count($children))
			$data .= ", children: [ " . JSONprivnodelist2($children) . "]},";
		else
			$data .= "},";
	}
	$data = rtrim($data, ',');
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn nodeDropData()
///
/// \return string for setting value of nodedropdata to a javascript object
///
/// \brief generates a string to define a javascript object that contains all
/// privtree node ids with each having a value of 0 or 1 depending on whether or
/// not they can be moved and dropped on
///
////////////////////////////////////////////////////////////////////////////////
function nodeDropData() {
	global $user;
	$query = "SELECT id, parent FROM privnode WHERE id > " . DEFAULT_PRIVNODE;
	$qh = doQuery($query);
	$data = 'nodedropdata = {';
	while($row = mysql_fetch_assoc($qh))
		if(checkUserHasPriv('nodeAdmin', $user['id'], $row['id']) &&
		   ($row['parent'] == DEFAULT_PRIVNODE || checkUserHasPriv('nodeAdmin', $user['id'], $row['parent'])))
			$data .= "{$row['id']}: '1',";
		else
			$data .= "{$row['id']}: '0',";
	rtrim($data, ',');
	$data .= '}';
	return $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJrefreshNodeDropData()
///
/// \brief prints output from nodeDropData
///
////////////////////////////////////////////////////////////////////////////////
function AJrefreshNodeDropData() {
	print "if(typeof(nodedropdata) == 'number') {initDropData();}";
	print nodeDropData();
}

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
		print "dojo.byId('childNodeName').value = ''; ";
		print "dijit.byId('addNodePane').hide(); ";
		print "alert('$text');";
		return;
	}
	$newnode = processInputVar("newnode", ARG_STRING);
	$errmsg = '';
	if(! validateNodeName($newnode, $errmsg)) {
		print "dojo.byId('addChildNodeStatus').innerHTML = '$errmsg';";
		return;
	}

	$nodeInfo = getNodeInfo($parent);

	# check to see if a node with the submitted name already exists
	$query = "SELECT id "
	       . "FROM privnode "
	       . "WHERE name = '$newnode' AND "
	       .       "parent = $parent";
	$qh = doQuery($query, 335);
	if(mysql_num_rows($qh)) {
		$text = "A node of that name already exists "
		      . "under " . $nodeInfo["name"];
		print "dojo.byId('addChildNodeStatus').innerHTML = '$text';";
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
	if(! $row = mysql_fetch_row($qh))
		abort(101);
	$nodeid = $row[0];

	$privs = array();
	foreach(array("nodeAdmin", "userGrant", "resourceGrant") as $type) {
		if(! checkUserHasPriv($type, $user["id"], $nodeid))
			array_push($privs, $type);
	}
	if(count($privs)) {
		array_push($privs, "cascade");
		updateUserOrGroupPrivs($user["id"], $nodeid, $privs, array(), "user");
	}
	print "addChildNode('$newnode', $nodeid, $parent);";
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
/// \fn validateNodeName($name, &$errmsg)
///
/// \param $name - name for a node
/// \param $errmsg - variable into which an error message will be placed if
/// $name is not valid
///
/// \return 1 if name is okay, 0 if not; if 0, $errmsg is populated with an
/// error message
///
/// \brief validates that a name for a node is okay
///
////////////////////////////////////////////////////////////////////////////////
function validateNodeName($name, &$errmsg) {
	if(preg_match('/^[-A-Za-z0-9_\. ]+$/', $name))
		return 1;
	$errmsg = i("Node names can only contain letters, numbers, spaces,<br>dashes(-), dots(.), and underscores(_).");
	return 0;
}

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
	if(empty($activeNode))
		return;
	if(! checkUserHasPriv("nodeAdmin", $user["id"], $activeNode)) {
		$text = "You do not have rights to delete this node.";
		print "alert('$text');";
		return;
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
	print "setSelectedPrivNode('$parent'); ";
	print "removeNodesFromTree('$deleteNodes', $activeNode); ";
	print "dijit.byId('deleteDialog').hide(); ";
	print "var workingobj = dijit.byId('workingDialog'); ";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitRenameNode()
///
/// \brief deletes a node and its children; calls viewNodes when finished
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitRenameNode() {
	global $user;
	$activeNode = processInputVar("activeNode", ARG_NUMERIC);
	if(empty($activeNode))
		return;
	if(! checkUserHasPriv("nodeAdmin", $user["id"], $activeNode)) {
		$msg = "You do not have rights to rename this node.";
		$arr = array('error' => 1, 'message' => $msg);
		sendJSON($arr);
		return;
	}
	$newname = processInputVar('newname', ARG_STRING);
	$errmsg = '';
	if(! validateNodeName($newname, $errmsg)) {
		$arr = array('error' => 2, 'message' => $errmsg);
		sendJSON($arr);
		return;
	}
	# check if node matching new name already exists at parent
	$_newname = mysql_real_escape_string($newname);
	$query = "SELECT id "
	       . "FROM privnode "
	       . "WHERE parent = (SELECT parent FROM privnode WHERE id = $activeNode) AND "
	       .       "name = '$_newname'";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh)) {
		$msg = i("A sibling node of that name currently exists");
		$arr = array('error' => 2, 'message' => $msg);
		sendJSON($arr);
		return;
	}

	$query = "UPDATE privnode "
	       . "SET name = '$_newname' " 
	       . "WHERE id = $activeNode";
	doQuery($query, 101);
	$arr = array('newname' => $newname, 'node' => $activeNode);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJmoveNode()
///
/// \brief handles saving a moved node
///
////////////////////////////////////////////////////////////////////////////////
function AJmoveNode() {
	global $user;
	$moveid = processInputVar('moveid', ARG_NUMERIC);
	$oldparentid = processInputVar('oldparentid', ARG_NUMERIC);
	$newparentid = processInputVar('newparentid', ARG_NUMERIC);

	if(! checkUserHasPriv("nodeAdmin", $user["id"], $moveid) ||
	   ! checkUserHasPriv("nodeAdmin", $user["id"], $newparentid) ||
	   ! checkUserHasPriv("nodeAdmin", $user["id"], $oldparentid)) {
		$arr = array('status' => 'noaccess',
		             'moveid' => $moveid,
		             'oldparentid' => $oldparentid,
		             'newparentid' => $newparentid);
		sendJSON($arr);
		return;
	}

	if($oldparentid == $newparentid) {
		$arr = array('status' => 'nochange');
		sendJSON($arr);
		return;
	}

	# check for name collision at parent
	$query = "SELECT p2.id "
	       . "FROM privnode p1, "
	       .      "privnode p2 "
	       . "WHERE p1.id = $moveid AND "
	       .       "p2.parent = $newparentid AND "
	       .       "p2.name = p1.name";
	$qh = doQuery($query);
	if($row = mysql_num_rows($qh)) {
		$arr = array('status' => 'collision',
		             'moveid' => $moveid,
		             'oldparentid' => $oldparentid,
		             'newparentid' => $newparentid);
		sendJSON($arr);
		return;
	}

	$nodeinfo = getNodeInfo($moveid);
	$oldnodeinfo = getNodeInfo($oldparentid);
	$newnodeinfo = getNodeInfo($newparentid);
	$cdata = array('moveid' => $moveid,
	               'newparentid' => $newparentid,
	               'oldparentid' => $oldparentid);
	$cont = addContinuationsEntry('AJsubmitMoveNode', $cdata, 300);
	$revertcont = addContinuationsEntry('AJrevertMoveNode', $cdata);
	$arr = array('status' => 'success',
	             'movename' => $nodeinfo['name'],
	             'oldparent' => $oldnodeinfo['name'],
	             'newparent' => $newnodeinfo['name'],
	             'moveid' => $moveid,
	             'oldparentid' => $oldparentid,
	             'newparentid' => $newparentid,
	             'continuation' => $cont,
	             'revertcont' => $revertcont);
	sendJSON($arr);
	return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitMoveNode()
///
/// \brief handles saving a moved node
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitMoveNode() {
	$moveid = getContinuationVar('moveid');
	$newparentid = getContinuationVar('newparentid');
	$oldparentid = getContinuationVar('oldparentid');

	$query = "UPDATE privnode "
	       . "SET parent = $newparentid "
	       . "WHERE id = $moveid AND "
	       .       "parent = $oldparentid";
	doQuery($query);

	clearPrivCache();

	$arr = array('status' => 'success',
	             'newparentid' => $newparentid);
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJrevertMoveNode()
///
/// \brief handles reverting a moved node
///
////////////////////////////////////////////////////////////////////////////////
function AJrevertMoveNode() {
	$moveid = getContinuationVar('moveid');
	$newparentid = getContinuationVar('newparentid');
	$oldparentid = getContinuationVar('oldparentid');

	$query = "UPDATE privnode "
	       . "SET parent = $oldparentid "
	       . "WHERE id = $moveid AND "
	       .       "parent = $newparentid";
	doQuery($query);

	clearPrivCache();

	$arr = array('status' => 'success');
	sendJSON($arr);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn userLookup()
///
/// \brief prints a page to display a user's privileges
///
////////////////////////////////////////////////////////////////////////////////
function userLookup() {
	global $user;
	$userid = processInputVar("userid", ARG_STRING);
	if(get_magic_quotes_gpc())
		$userid = stripslashes($userid);
	$affilid = processInputVar('affiliationid', ARG_NUMERIC, $user['affiliationid']);
	$force = processInputVar('force', ARG_NUMERIC, 0);
	print "<div align=center>\n";
	print "<H2>User Lookup</H2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH>Name (last, first) or User ID:</TH>\n";
	print "    <TD><INPUT type=text name=userid value=\"$userid\" size=25></TD>\n";
	if(checkUserHasPerm('User Lookup (global)')) {
		$affils = getAffiliations();
		print "    <TD>\n";
		print "@";
		printSelectInput("affiliationid", $affils, $affilid);
		print "    </TD>\n";
	}
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD colspan=2>\n";
	print "      <input type=checkbox id=force name=force value=1>\n";
	print "      <label for=force>Attempt forcing an update from LDAP (User ID only)</label>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD colspan=3 align=center><INPUT type=submit value=Submit>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	$cont = addContinuationsEntry('submitUserLookup');
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM><br>\n";
	if(! empty($userid)) {
		$esc_userid = mysql_real_escape_string($userid);
		if(preg_match('/,/', $userid)) {
			$mode = 'name';
			$force = 0;
		}
		else
			$mode = 'userid';
		if(! checkUserHasPerm('User Lookup (global)') &&
		   $user['affiliationid'] != $affilid) {
			print "<font color=red>$userid not found</font><br>\n";
			return;
		}
		if($mode == 'userid') {
			$query = "SELECT id "
			       . "FROM user "
			       . "WHERE unityid = '$esc_userid' AND "
			       .       "affiliationid = $affilid";
			$affilname = getAffiliationName($affilid);
			$userid = "$userid@$affilname";
			$esc_userid = "$esc_userid@$affilname";
		}
		else {
			$tmp = explode(',', $userid);
			$last = mysql_real_escape_string(trim($tmp[0]));
			$first = mysql_real_escape_string(trim($tmp[1]));
			$query = "SELECT CONCAT(u.unityid, '@', a.name) AS unityid "
			       . "FROM user u, "
			       .      "affiliation a "
			       . "WHERE u.firstname = '$first' AND "
			       .       "u.lastname = '$last' AND "
			       .       "u.affiliationid = $affilid AND "
			       .       "a.id = $affilid";
		}
		$qh = doQuery($query, 101);
		if(! mysql_num_rows($qh)) {
			if($mode == 'name') {
				print "<font color=red>User not found</font><br>\n";
				return;
			}
			else
				print "<font color=red>$userid not currently found in VCL user database, will try to add...</font><br>\n";
		}
		elseif($force) {
			$_SESSION['userresources'] = array();
			$row = mysql_fetch_assoc($qh);
			$newtime = unixToDatetime(time() - SECINDAY - 5);
			$query = "UPDATE user SET lastupdated = '$newtime' WHERE id = {$row['id']}";
			doQuery($query, 101);
		}
		elseif($mode == 'name') {
			$row = mysql_fetch_assoc($qh);
			$userid = $row['unityid'];
			$esc_userid = $row['unityid'];
		}

		$userdata = getUserInfo($esc_userid);
		if(is_null($userdata)) {
			$userdata = getUserInfo($esc_userid, 1);
			if(is_null($userdata)) {
				print "<font color=red>$userid not found</font><br>\n";
				return;
			}
		}
		$userdata["groups"] = getUsersGroups($userdata["id"], 1, 1);
		print "<div id=\"userlookupdata\">\n";
		print "<TABLE>\n";
		if(! empty($userdata['unityid'])) {
			print "  <TR>\n";
			print "    <TH align=right>User ID:</TH>\n";
			print "    <TD>{$userdata["unityid"]}</TD>\n";
			print "  </TR>\n";
		}
		if(! empty($userdata['firstname'])) {
			print "  <TR>\n";
			print "    <TH align=right>First Name:</TH>\n";
			print "    <TD>{$userdata["firstname"]}</TD>\n";
			print "  </TR>\n";
		}
		if(! empty($userdata['lastname'])) {
			print "  <TR>\n";
			print "    <TH align=right>Last Name:</TH>\n";
			print "    <TD>{$userdata["lastname"]}</TD>\n";
			print "  </TR>\n";
		}
		if(! empty($userdata['preferredname'])) {
			print "  <TR>\n";
			print "    <TH align=right>Preferred Name:</TH>\n";
			print "    <TD>{$userdata["preferredname"]}</TD>\n";
			print "  </TR>\n";
		}
		if(! empty($userdata['affiliation'])) {
			print "  <TR>\n";
			print "    <TH align=right>Affiliation:</TH>\n";
			print "    <TD>{$userdata["affiliation"]}</TD>\n";
			print "  </TR>\n";
		}
		if(! empty($userdata['email'])) {
			print "  <TR>\n";
			print "    <TH align=right>Email:</TH>\n";
			print "    <TD>{$userdata["email"]}</TD>\n";
			print "  </TR>\n";
		}
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
		print "    <TH align=right style=\"vertical-align: top\">User Group Permissions:</TH>\n";
		print "    <TD>\n";
		if(count($userdata['groupperms'])) {
			foreach($userdata['groupperms'] as $perm)
				print "      $perm<br>\n";
		}
		else
			print "      No additional user group permissions\n";
		print "    </TD>\n";
		print "  </TR>\n";

		$times = getUserMaxTimes($userdata['id']);
		$times['initial'] = getReservationLength($times['initial']);
		$times['extend'] = getReservationLength($times['extend']);
		$times['total'] = getReservationLength($times['total']);
		print "  <TR>\n";
		print "    <TH align=right style=\"vertical-align: top\">User Max Times:</TH>\n";
		print "    <TD>\n";
		print "      Initial: {$times['initial']}<br>\n";
		print "      Extend: {$times['extend']}<br>\n";
		print "      Total: {$times['total']}<br>\n";
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
		       .       "upt.name NOT IN ('configAdmin', 'serverProfileAdmin') AND "
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
					$path = getNodePath($privnodeid);
					print "    <TH align=right>$path</TH>\n";
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
			       .       "upt.name NOT IN ('configAdmin', 'serverProfileAdmin') AND "
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
						$path = getNodePath($privnodeid);
						print "    <TH align=right>$path</TH>\n";
						print "    <TD>\n";
					}
					print "      {$row['userprivtype']}<br>\n";
				}
				print "    </TD>\n";
				print "  </TR>\n";
				print "</TABLE>\n";
			}
		}
		print "</div>\n";

		# image access
		print "<table>\n";
		print "  <tr>\n";
		print "    <th style=\"vertical-align: top;\">Images User Has Access To:<th>\n";
		print "    <td>\n";
		foreach($userResources['image'] as $img)
			print "      $img<br>\n";
		print "    </td>\n";
		print "  </tr>\n";
		print "</table>\n";

		# login history
		$query = "SELECT authmech, "
		       .        "timestamp, "
		       .        "passfail, "
		       .        "remoteIP, "
		       .        "code "
		       . "FROM loginlog "
		       . "WHERE (user = '{$userdata['unityid']}' OR "
		       .       "user = '{$userdata['unityid']}@{$userdata['affiliation']}') AND "
		       .       "affiliationid = {$userdata['affiliationid']} "
		       . "ORDER BY timestamp DESC "
		       . "LIMIT 8";
		$logins = array();
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$logins[] = $row;
		if(count($logins)) {
			$logins = array_reverse($logins);
			print "<h3>Login History (last 8 attempts)</h3>\n";
			print "<table summary=\"login attempts\">\n";
			print "<colgroup>\n";
			print "<col class=\"logincol\" />\n";
			print "<col class=\"logincol\" />\n";
			print "<col class=\"logincol\" />\n";
			print "<col class=\"logincol\" />\n";
			print "<col />\n";
			print "</colgroup>\n";
			print "  <tr>\n";
			print "    <th>Authentication Method</th>\n";
			print "    <th>Timestamp</th>\n";
			print "    <th>Result</th>\n";
			print "    <th>Remote IP</th>\n";
			print "    <th>Extra Info</th>\n";
			print "  </tr>\n";
			foreach($logins as $login) {
				print "  <tr>\n";
				print "    <td class=\"logincell\">{$login['authmech']}</td>\n";
				$ts = prettyDatetime($login['timestamp'], 1) . '&nbsp;' . date('T');
				print "    <td class=\"logincell\">$ts</td>\n";
				if($login['passfail'])
					print "    <td class=\"logincell\"><font color=\"#008000\">Pass</font></td>\n";
				else
					print "    <td class=\"logincell\"><font color=\"red\">Fail</font></td>\n";
				print "    <td class=\"logincell\">{$login['remoteIP']}</td>\n";
				print "    <td class=\"logincell\">{$login['code']}</td>\n";
				print "  </tr>\n";
			}
			print "</table>\n";
		}
		else {
			print "<h3>Login History</h3>\n";
			print "There are no login attempts by this user.<br>\n";
		}

		# reservation history
		$requests = array();
		$query = "SELECT DATE_FORMAT(l.start, '%W, %b %D, %Y, %h:%i %p') AS start, "
		       .        "DATE_FORMAT(l.finalend, '%W, %b %D, %Y, %h:%i %p') AS end, "
		       .        "c.hostname, "
		       .        "i.prettyname AS prettyimage, "
		       .        "l.remoteIP AS userIP, "
		       .        "s.IPaddress, "
		       .        "l.ending, "
		       .        "l.requestid, "
		       .        "m.hostname AS managementnode, "
		       .        "ch.hostname AS vmhost "
		       . "FROM log l, "
		       .      "image i, "
		       .      "sublog s "
		       . "LEFT JOIN managementnode m ON (s.managementnodeid = m.id) "
		       . "LEFT JOIN computer c ON (s.computerid = c.id) "
		       . "LEFT JOIN vmhost vh ON (c.vmhostid = vh.id) "
		       . "LEFT JOIN computer ch ON (vh.computerid = ch.id) "
		       . "WHERE l.userid = {$userdata['id']} AND "
		       .        "s.logid = l.id AND "
		       .        "i.id = s.imageid "
		       . "ORDER BY l.start DESC "
		       . "LIMIT 5";
		$qh = doQuery($query, 290);
		while($row = mysql_fetch_assoc($qh))
			array_push($requests, $row);
		$requests = array_reverse($requests);
		if(! empty($requests)) {
			print "<h3>User's last " . count($requests) . " reservations:</h3>\n";
			print "<div id=\"userlookupresdata\">\n";
			print "<table>\n";
			$first = 1;
			foreach($requests as $req) {
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
				if($req['vmhost'] != '') {
					print "  <tr>\n";
					print "    <th align=right>VM Host:</th>\n";
					print "    <td>{$req['vmhost']}</td>\n";
					print "  </tr>\n";
				}
				print "  <tr>\n";
				print "    <th align=right>Start:</th>\n";
				print "    <td>{$req['start']} " . date('T') . "</td>\n";
				print "  </tr>\n";
				print "  <tr>\n";
				print "    <th align=right>End:</th>\n";
				print "    <td>{$req['end']} " . date('T') . "</td>\n";
				print "  </tr>\n";
				if($req['IPaddress'] != '') {
					print "  <tr>\n";
					print "    <th align=right>Node's IP Address:</th>\n";
					print "    <td>{$req['IPaddress']}</td>\n";
					print "  </tr>\n";
				}
				if($req['userIP'] != '') {
					print "  <tr>\n";
					print "    <th align=right>User's IP Address:</th>\n";
					print "    <td>{$req['userIP']}</td>\n";
					print "  </tr>\n";
				}
				print "  <tr>\n";
				print "    <th align=right>Ending:</th>\n";
				print "    <td>{$req['ending']}</td>\n";
				print "  </tr>\n";
				if($req['requestid'] != '') {
					print "  <tr>\n";
					print "    <th align=right>Request ID:</th>\n";
					print "    <td>{$req['requestid']}</td>\n";
					print "  </tr>\n";
				}
				if($req['managementnode'] != '') {
					print "  <tr>\n";
					print "    <th align=right>Management Node:</th>\n";
					print "    <td>{$req['managementnode']}</td>\n";
					print "  </tr>\n";
				}
			}
			print "</table>\n";
			print "</div>\n";
		}
		else
			print "User has made no reservations.<br>\n";

		# current reservations
		$requests = array();
		$query = "SELECT DATE_FORMAT(rq.start, '%W, %b %D, %Y, %h:%i %p') AS start, "
		       .        "DATE_FORMAT(rq.end, '%W, %b %D, %Y, %h:%i %p') AS end, "
		       .        "rq.id AS requestid, "
		       .        "MIN(rs.id) AS reservationid, "
		       .        "c.hostname AS computer, "
		       .        "i.prettyname AS prettyimage, "
		       .        "c.IPaddress AS compIP, "
		       .        "rs.remoteIP AS userIP, "
		       .        "ch.hostname AS vmhost, "
		       .        "mn.hostname AS managementnode, "
		       .        "srq.name AS servername, "
		       .        "CONCAT(aug.name, '@', auga.name) AS admingroup, "
		       .        "CONCAT(lug.name, '@', luga.name) AS logingroup, "
		       .        "s1.name AS state, "
		       .        "s2.name AS laststate "
		       . "FROM image i, "
		       .      "managementnode mn, "
		       .      "request rq "
		       . "LEFT JOIN reservation rs ON (rs.requestid = rq.id) "
		       . "LEFT JOIN computer c ON (rs.computerid = c.id) "
		       . "LEFT JOIN vmhost vh ON (c.vmhostid = vh.id) "
		       . "LEFT JOIN computer ch ON (vh.computerid = ch.id) "
		       . "LEFT JOIN serverrequest srq ON (srq.requestid = rq.id) "
		       . "LEFT JOIN usergroup aug ON (aug.id = srq.admingroupid) "
		       . "LEFT JOIN affiliation auga ON (aug.affiliationid = auga.id) "
		       . "LEFT JOIN usergroup lug ON (lug.id = srq.logingroupid) "
		       . "LEFT JOIN affiliation luga ON (lug.affiliationid = luga.id) "
		       . "LEFT JOIN state s1 ON (s1.id = rq.stateid) "
		       . "LEFT JOIN state s2 ON (s2.id = rq.laststateid) "
		       . "WHERE rq.userid = {$userdata['id']} AND "
		       .        "i.id = rs.imageid AND "
		       .        "mn.id = rs.managementnodeid "
		       . "GROUP BY rq.id "
		       . "ORDER BY rq.start";
		$qh = doQuery($query, 290);
		while($row = mysql_fetch_assoc($qh))
			array_push($requests, $row);
		$requests = array_reverse($requests);
		if(! empty($requests)) {
			print "<h3>User's current reservations:</h3>\n";
			print "<table>\n";
			$first = 1;
			foreach($requests as $req) {
				if($first)
					$first = 0;
				else {
					print "  <tr>\n";
					print "    <td colspan=2><hr></td>\n";
					print "  </tr>\n";
				}
				print "  <tr>\n";
				print "    <th align=right>Request ID:</th>\n";
				print "    <td>{$req['requestid']}</td>\n";
				print "  </tr>\n";
				if($req['servername'] != '') {
					print "  <tr>\n";
					print "    <th align=right>Reservation Name:</th>\n";
					print "    <td>{$req['servername']}</td>\n";
					print "  </tr>\n";
				}
				print "  <tr>\n";
				print "    <th align=right>Image:</th>\n";
				print "    <td>{$req['prettyimage']}</td>\n";
				print "  </tr>\n";
				print "  <tr>\n";
				print "    <th align=right>State:</th>\n";
				if($req['state'] == 'pending')
					print "    <td>{$req['laststate']}</td>\n";
				else
					print "    <td>{$req['state']}</td>\n";
				print "  </tr>\n";
				print "  <tr>\n";
				print "    <th align=right>Computer:</th>\n";
				print "    <td>{$req['computer']}</td>\n";
				print "  </tr>\n";
				if(! empty($req['vmhost'])) {
					print "  <tr>\n";
					print "    <th align=right>VM Host:</th>\n";
					print "    <td>{$req['vmhost']}</td>\n";
					print "  </tr>\n";
				}
				print "  <tr>\n";
				print "    <th align=right>Start:</th>\n";
				print "    <td>{$req['start']} " . date('T') . "</td>\n";
				print "  </tr>\n";
				print "  <tr>\n";
				print "    <th align=right>End:</th>\n";
				if($req['end'] == 'Friday, Jan 1st, 2038, 12:00 AM')
					print "    <td>(indefinite)</td>\n";
				else
					print "    <td>{$req['end']} " . date('T') . "</td>\n";
				print "  </tr>\n";
				if($req['compIP'] != '') {
					print "  <tr>\n";
					print "    <th align=right>Node's IP Address:</th>\n";
					print "    <td>{$req['compIP']}</td>\n";
					print "  </tr>\n";
				}
				if($req['userIP'] != '') {
					print "  <tr>\n";
					print "    <th align=right>User's IP Address:</th>\n";
					print "    <td>{$req['userIP']}</td>\n";
					print "  </tr>\n";
				}
				if($req['admingroup'] != '') {
					print "  <tr>\n";
					print "    <th align=right>Admin Group:</th>\n";
					print "    <td>{$req['admingroup']}</td>\n";
					print "  </tr>\n";
				}
				if($req['logingroup'] != '') {
					print "  <tr>\n";
					print "    <th align=right>Access Group:</th>\n";
					print "    <td>{$req['logingroup']}</td>\n";
					print "  </tr>\n";
				}
				print "  <tr>\n";
				print "    <th align=right>Management Node:</th>\n";
				print "    <td>{$req['managementnode']}</td>\n";
				print "  </tr>\n";
			}
			print "</table>\n";
		}
		else
			print "User does not have any current reservations.<br>\n";

		# reservation access
		if(! empty($userdata['groups'])) {
			$requests = array();
			$query = "SELECT DATE_FORMAT(rq.start, '%W, %b %D, %Y, %h:%i %p') AS start, "
			       .        "DATE_FORMAT(rq.end, '%W, %b %D, %Y, %h:%i %p') AS end, "
			       .        "rq.id AS requestid, "
			       .        "MIN(rs.id) AS reservationid, "
			       .        "c.hostname AS computer, "
			       .        "i.prettyname AS prettyimage, "
			       .        "c.IPaddress AS compIP, "
			       .        "ch.hostname AS vmhost, "
			       .        "mn.hostname AS managementnode, "
			       .        "srq.name AS servername, "
			       .        "CONCAT(aug.name, '@', auga.name) AS admingroup, "
			       .        "CONCAT(lug.name, '@', luga.name) AS logingroup, "
			       .        "s1.name AS state, "
			       .        "s2.name AS laststate "
			       . "FROM image i, "
			       .      "managementnode mn, "
			       .      "request rq "
			       . "LEFT JOIN reservation rs ON (rs.requestid = rq.id) "
			       . "LEFT JOIN computer c ON (rs.computerid = c.id) "
			       . "LEFT JOIN vmhost vh ON (c.vmhostid = vh.id) "
			       . "LEFT JOIN computer ch ON (vh.computerid = ch.id) "
			       . "LEFT JOIN serverrequest srq ON (srq.requestid = rq.id) "
			       . "LEFT JOIN usergroup aug ON (aug.id = srq.admingroupid) "
			       . "LEFT JOIN affiliation auga ON (aug.affiliationid = auga.id) "
			       . "LEFT JOIN usergroup lug ON (lug.id = srq.logingroupid) "
			       . "LEFT JOIN affiliation luga ON (lug.affiliationid = luga.id) "
			       . "LEFT JOIN state s1 ON (s1.id = rq.stateid) "
			       . "LEFT JOIN state s2 ON (s2.id = rq.laststateid) "
			       . "WHERE (srq.admingroupid IN (" . implode(',', array_keys($userdata['groups'])) . ") OR "
			       .        "srq.logingroupid IN (" . implode(',', array_keys($userdata['groups'])) . ")) AND "
			       .        "i.id = rs.imageid AND "
			       .        "mn.id = rs.managementnodeid AND "
			       .        "rq.userid != {$userdata['id']} "
			       . "GROUP BY rq.id "
			       . "ORDER BY rq.start";
			$qh = doQuery($query, 290);
			while($row = mysql_fetch_assoc($qh))
				array_push($requests, $row);
			$requests = array_reverse($requests);
			if(! empty($requests)) {
				print "<h3>Server Reservations User Can Use:</h3>\n";
				print "<table>\n";
				$first = 1;
				foreach($requests as $req) {
					if($first)
						$first = 0;
					else {
						print "  <tr>\n";
						print "    <td colspan=2><hr></td>\n";
						print "  </tr>\n";
					}
					print "  <tr>\n";
					print "    <th align=right>Request ID:</th>\n";
					print "    <td>{$req['requestid']}</td>\n";
					print "  </tr>\n";
					if($req['servername'] != '') {
						print "  <tr>\n";
						print "    <th align=right>Reservation Name:</th>\n";
						print "    <td>{$req['servername']}</td>\n";
						print "  </tr>\n";
					}
					print "  <tr>\n";
					print "    <th align=right>Image:</th>\n";
					print "    <td>{$req['prettyimage']}</td>\n";
					print "  </tr>\n";
					print "  <tr>\n";
					print "    <th align=right>State:</th>\n";
					if($req['state'] == 'pending')
						print "    <td>{$req['laststate']}</td>\n";
					else
						print "    <td>{$req['state']}</td>\n";
					print "  </tr>\n";
					print "  <tr>\n";
					print "    <th align=right>Computer:</th>\n";
					print "    <td>{$req['computer']}</td>\n";
					print "  </tr>\n";
					if(! empty($req['vmhost'])) {
						print "  <tr>\n";
						print "    <th align=right>VM Host:</th>\n";
						print "    <td>{$req['vmhost']}</td>\n";
						print "  </tr>\n";
					}
					print "  <tr>\n";
					print "    <th align=right>Start:</th>\n";
					print "    <td>{$req['start']} " . date('T') . "</td>\n";
					print "  </tr>\n";
					print "  <tr>\n";
					print "    <th align=right>End:</th>\n";
					if($req['end'] == 'Friday, Jan 1st, 2038, 12:00 AM')
						print "    <td>(indefinite)</td>\n";
					else
						print "    <td>{$req['end']} " . date('T') . "</td>\n";
					print "  </tr>\n";
					if($req['compIP'] != '') {
						print "  <tr>\n";
						print "    <th align=right>Node's IP Address:</th>\n";
						print "    <td>{$req['compIP']}</td>\n";
						print "  </tr>\n";
					}
					if($req['admingroup'] != '') {
						print "  <tr>\n";
						print "    <th align=right>Admin Group:</th>\n";
						print "    <td>{$req['admingroup']}</td>\n";
						print "  </tr>\n";
					}
					if($req['logingroup'] != '') {
						print "  <tr>\n";
						print "    <th align=right>Access Group:</th>\n";
						print "    <td>{$req['logingroup']}</td>\n";
						print "  </tr>\n";
					}
					print "  <tr>\n";
					print "    <th align=right>Management Node:</th>\n";
					print "    <td>{$req['managementnode']}</td>\n";
					print "  </tr>\n";
				}
				print "</table>\n";
			}
		}
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
	if($usergroup == 'group') {
		print "    <TH><span id=\"usergrp$privname\" onmouseover=getGroupMembers(";
		print "\"$privname\",\"usergrp$privname\",\"ugmcont\"); onmouseout=";
		print "getGroupMembersCancel(\"usergrp$privname\");>{$allprivs[$privname]['name']}";
		if(! empty($allprivs[$privname]['affiliation']))
			print "@{$allprivs[$privname]['affiliation']}";
		print "</span></TH>\n";
	}
	else
		print "<TH>$privname</TH>\n";

	if($disabled)
		$disabled = 'disabled=disabled';
	else
		$disabled = '';

	# block rights
	if(isset($privs[$privname]) && 
	   (($usergroup == 'user' &&
	   isset($privs[$privname]['block'])) ||
	   ($usergroup == 'group' &&
	   isset($privs[$privname]['privs']['block'])))) {
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
		$name = "privrow[$privname:block]";
	}
	print "    <TD class=\"privBlock\" align=center bgcolor=gray>\n";
	print "<INPUT type=checkbox dojoType=dijit.form.CheckBox id=ck$rownum:block ";
	print "name=\"$name\" onClick=\"changeCascadedRights(this.checked, $rownum, ";
	print "$count, 1, $usergroup);\" $checked $disabled></TD>\n";

	#cascade rights
	if(isset($privs[$privname]) && 
	   (($usergroup == 1 &&
	   isset($privs[$privname]['cascade'])) ||
	   ($usergroup == 2 &&
	   isset($privs[$privname]['privs']['cascade']))))
		$checked = "checked";
	else
		$checked = "";
	$name = "privrow[$privname:cascade]";
	print "    <TD class=\"privCascade\" align=center bgcolor=\"#008000\" id=cell$rownum:0>";
	print "<INPUT type=checkbox dojoType=dijit.form.CheckBox id=ck$rownum:0 ";
	print "name=\"$name\" onClick=\"privChange(this.checked, $rownum, 0, ";
	print "$usergroup);\" $checked $disabled></TD>\n";

	# normal rights
	$j = 1;
	foreach($types as $type) {
		if($type == 'configAdmin')
			continue;
		$bgcolor = "";
		$checked = "";
		$value = "";
		$cascaded = 0;
		if(isset($cascadeprivs[$privname]) && 
		   (($usergroup == 1 &&
		   isset($cascadeprivs[$privname][$type])) ||
		   ($usergroup == 2 &&
		   isset($cascadeprivs[$privname]['privs'][$type])))) {
			$bgcolor = "class=\"privCascade\"";
			$checked = "checked";
			$value = "value=cascade";
			$cascaded = 1;
		}
		if(isset($privs[$privname]) && 
		   (($usergroup == 1 &&
		   isset($privs[$privname][$type])) ||
		   ($usergroup == 2 &&
		   isset($privs[$privname]['privs'][$type])))) {
			if($cascaded) {
				$value = "value=cascadesingle";
			}
			else {
				$checked = "checked";
				$value = "value=single";
			}
		}
		$name = "privrow[$privname:$type]";
		print "    <TD align=center id=cell$rownum:$j $bgcolor><INPUT ";
		print "type=checkbox dojoType=dijit.form.CheckBox name=\"$name\" ";
		print "id=ck$rownum:$j $checked $value $disabled ";
		print "onClick=\"nodeCheck(this.checked, $rownum, $j, $usergroup)\">";
		#print "onBlur=\"nodeCheck(this.checked, $rownum, $j, $usergroup)\">";
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
	$text .= "<TR>";
	if($usergroup == 'group') {
		$text .= "<TH><span id=\"usergrp$privname\" onmouseover=getGroupMembers(";
		$text .= "\"$privname\",\"usergrp$privname\",\"ugmcont\"); onmouseout=";
		$text .= "getGroupMembersCancel(\"usergrp$privname\");>{$allprivs[$privname]['name']}";
		if(! empty($allprivs[$privname]['affiliation']))
			$text .= "@{$allprivs[$privname]['affiliation']}";
		$text .= "</span></TH>";
	}
	else
		$text .= "<TH>$privname</TH>";

	if($disabled)
		$disabled = 'disabled=disabled';
	else
		$disabled = '';

	# block rights
	if(isset($privs[$privname]) && 
	   (($usergroup == 'user' &&
	   isset($privs[$privname]["block"])) ||
	   ($usergroup == 'group' &&
	   isset($privs[$privname]['privs']["block"])))) {
		$checked = "checked";
		$blocked = 1;
	}
	else {
		$checked = "";
		$blocked = 0;
	}
	$count = count($types) + 1;
	if($usergroup == 'user')
		$usergroup = 1;
	elseif($usergroup == 'group')
		$usergroup = 2;
	$name = "privrow[$privname:block]";
	$text .= "    <TD class=\"privBlock\" align=center bgcolor=gray><INPUT type=checkbox ";
	$text .= "dojoType=dijit.form.CheckBox id=ck$rownum:block name=\"$name\" ";
	$text .= "$checked $disabled onClick=\"changeCascadedRights";
	$text .= "(this.checked, $rownum, $count, 1, $usergroup)\"></TD>";

	#cascade rights
	if(isset($privs[$privname]) && 
	   (($usergroup == 1 &&
	   isset($privs[$privname]["cascade"])) ||
	   ($usergroup == 2 &&
	   isset($privs[$privname]['privs']["cascade"]))))
		$checked = "checked";
	else
		$checked = "";
	$name = "privrow[$privname:cascade]";
	$text .= "    <TD class=\"privCascade\" align=center bgcolor=\"#008000\" id=cell$rownum:0>";
	$text .= "<INPUT type=checkbox dojoType=dijit.form.CheckBox id=ck$rownum:0 ";
	$text .= "name=\"$name\" onClick=\"privChange(this.checked, $rownum, 0, ";
	$text .= "$usergroup);\" $checked $disabled></TD>";

	# normal rights
	$j = 1;
	foreach($types as $type) {
		if($type == 'configAdmin')
			continue;
		$bgcolor = "";
		$checked = "";
		$value = "";
		$cascaded = 0;
		if(isset($cascadeprivs[$privname]) && 
		   (($usergroup == 1 &&
		   isset($cascadeprivs[$privname][$type])) ||
		   ($usergroup == 2 &&
		   isset($cascadeprivs[$privname]['privs'][$type])))) {
			$bgcolor = "class=\"privCascade\"";
			$checked = "checked";
			$value = "value=cascade";
			$cascaded = 1;
		}
		if(isset($privs[$privname]) && 
		   (($usergroup == 1 &&
		   isset($privs[$privname][$type])) ||
		   ($usergroup == 2 &&
		   isset($privs[$privname]['privs'][$type])))) {
			if($cascaded) {
				$value = "value=cascadesingle";
			}
			else {
				$checked = "checked";
				$value = "value=single";
			}
		}
		$name = "privrow[$privname:$type]";
		$text .= "    <TD align=center id=cell$rownum:$j $bgcolor><INPUT ";
		$text .= "type=checkbox dojoType=dijit.form.CheckBox name=\"$name\" ";
		$text .= "id=ck$rownum:$j $checked $value $disabled ";
		$text .= "onClick=\"nodeCheck(this.checked, $rownum, $j, $usergroup)\">";
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
/// \fn jsonGetUserGroupMembers()
///
/// \brief accepts a user group id and dom id and prints a json array with 2
/// elements: members - a <br> separated string of user group members, and
/// domid - the passed in domid
///
////////////////////////////////////////////////////////////////////////////////
function jsonGetUserGroupMembers() {
	global $user;
	$usergrpid = processInputVar('groupid', ARG_NUMERIC);
	$domid = processInputVar('domid', ARG_STRING);
	$query = "SELECT g.ownerid, "
	       .        "g.affiliationid, "
	       .        "g.custom, "
	       .        "g.courseroll, "
	       .        "g2.name AS editgroup, "
	       .        "g2.editusergroupid AS editgroupid "
	       . "FROM usergroup g "
	       . "LEFT JOIN usergroup g2 ON (g.editusergroupid = g2.id) "
	       . "WHERE g.id = $usergrpid";
	$qh = doQuery($query, 101);
	if(! ($grpdata = mysql_fetch_assoc($qh))) {
		# problem getting group members
		$msg = 'failed to fetch group members';
		$arr = array('members' => $msg, 'domid' => $domid);
		sendJSON($arr);
		return;
	}
	if(($grpdata['custom'] == 1 && $user['id'] != $grpdata['ownerid'] &&
	   ! array_key_exists($grpdata['editgroupid'], $user['groups'])) ||
	   (($grpdata['custom'] == 0 || $grpdata['courseroll'] == 1) &&
	   ! checkUserHasPerm('Manage Federated User Groups (global)') &&
	   (! checkUserHasPerm('Manage Federated User Groups (affiliation only)') ||
	   $grpdata['affiliationid'] != $user['affiliationid']))) {
		# user doesn't have access to view membership
		$msg = '(not authorized to view membership)';
		$arr = array('members' => $msg, 'domid' => $domid);
		sendJSON($arr);
		return;
	}

	$grpmembers = getUserGroupMembers($usergrpid);
	$members = '';
	foreach($grpmembers as $group)
		$members .= "$group<br>";
	if($members == '')
		$members = '(empty group)';
	$arr = array('members' => $members, 'domid' => $domid);
	sendJSON($arr);
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
	$text .= "  <TR>\n";
	list($grptype, $name, $id) = explode('/', $privname);
	$text .= "    <TH>\n";
	$text .= "      <span id=\"resgrp$id\" onmouseover=getGroupMembers(\"$id\",";
	$text .= "\"resgrp$id\",\"rgmcont\"); onmouseout=getGroupMembersCancel";
	$text .= "(\"resgrp$id\");>$name</span>\n";
	$text .= "    </TH>\n";
	$text .= "    <TH>$grptype</TH>\n";

	if($disabled)
		$disabled = 'disabled=disabled';
	else
		$disabled = '';

	# block rights
	if(isset($privs[$privname]["block"])) {
		$checked = "checked";
		$blocked = 1;
	}
	else {
		$checked = "";
		$blocked = 0;
	}
	$count = count($types) + 1;
	$name = "privrow[" . $privname . ":block]";
	$text .= "    <TD class=\"privBlock\" align=center bgcolor=gray><INPUT type=checkbox ";
	$text .= "dojoType=dijit.form.CheckBox id=ck$rownum:block name=\"$name\" ";
	$text .= "$checked $disabled onClick=\"changeCascadedRights";
	$text .= "(this.checked, $rownum, $count, 1, 3)\"></TD>\n";

	#cascade rights
	if(isset($privs[$privname]["cascade"]))
		$checked = "checked";
	else
		$checked = "";
	$name = "privrow[" . $privname . ":cascade]";
	$text .= "    <TD class=\"privCascade\" align=center bgcolor=\"#008000\" id=cell$rownum:0>";
	$text .= "<INPUT type=checkbox dojoType=dijit.form.CheckBox id=ck$rownum:0 ";
	$text .= "onClick=\"privChange(this.checked, $rownum, 0, 3);\" ";
	$text .= "name=\"$name\" $checked $disabled></TD>\n";

	# normal rights
	$j = 1;
	foreach($types as $type) {
		if($type == 'block' || $type == 'cascade')
			continue;
		$bgcolor = "";
		$checked = "";
		$value = "";
		$cascaded = 0;
		if(isset($cascadeprivs[$privname][$type])) {
			$bgcolor = "class=\"privCascade\"";
			$checked = "checked";
			$value = "value=cascade";
			$cascaded = 1;
		}
		if(isset($privs[$privname][$type])) {
			if($cascaded) {
				$value = "value=cascadesingle";
			}
			else {
				$checked = "checked";
				$value = "value=single";
			}
		}
		// if $type is administer, manageGroup, or manageMapping, and it is not
		# checked, and the user is not in the resource owner group, don't print
		# the checkbox
		if(($type == "administer" || $type == "manageGroup" || $type == "manageMapping") &&
		   $checked != "checked" && 
		   ! array_key_exists($resourcegroups[$id]["ownerid"], $user["groups"])) {
			$text .= "<TD><img src=images/blank.gif></TD>\n";
		}
		// if group type is schedule, don't print available or manageMapping checkboxes
		// if group type is addomain, don't print available or manageMapping checkboxes
		// if group type is managementnode, don't print available checkbox
		// if group type is serverprofile, don't print manageMapping checkbox
		elseif(($grptype == 'schedule' && ($type == 'available' || $type == 'manageMapping')) ||
		      ($grptype == 'addomain' && ($type == 'available' || $type == 'manageMapping')) ||
		      ($grptype == 'managementnode' && $type == 'available') ||
		      ($grptype == 'serverprofile' && $type == 'manageMapping')) {
			$text .= "<TD><img src=images/blank.gif></TD>\n";
		}
		else {
			$name = "privrow[" . $privname . ":" . $type . "]";
			$text .= "    <TD align=center id=cell$rownum:$j $bgcolor><INPUT ";
			$text .= "type=checkbox dojoType=dijit.form.CheckBox name=\"$name\" ";
			$text .= "id=ck$rownum:$j $checked $value $disabled ";
			$text .= "onClick=\"nodeCheck(this.checked, $rownum, $j, 3)\">";
			$text .= "</TD>\n";
		}
		$j++;
	}
	$text .= "  </TR>\n";
	$count = count($types) + 1;
	if($blocked) {
		$js .= "changeCascadedRights(true, $rownum, $count, 0, 0);";
	}
	return array('html' => $text,
	             'javascript' => $js);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonGetResourceGroupMembers()
///
/// \brief accepts a resource group id and dom id and prints a json array with 2
/// elements: members - a <br> separated string of resource group members, and
/// domid - the passed in domid
///
////////////////////////////////////////////////////////////////////////////////
function jsonGetResourceGroupMembers() {
	$resgrpid = processInputVar('groupid', ARG_NUMERIC);
	$domid = processInputVar('domid', ARG_STRING);
	$query = "SELECT rt.name "
	       . "FROM resourcegroup rg, "
	       .      "resourcetype rt "
	       . "WHERE rg.id = $resgrpid AND "
	       .       "rg.resourcetypeid = rt.id";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh)) {
		$type = $row['name'];
		if($type == 'computer' || $type == 'managementnode')
			$field = 'hostname';
		elseif($type == 'image')
			$field = 'prettyname';
		else
			$field = 'name';
		$query = "SELECT t.$field AS item "
		       . "FROM $type t, "
		       .      "resource r, "
		       .      "resourcegroupmembers rgm "
		       . "WHERE rgm.resourcegroupid = $resgrpid AND "
		       .       "rgm.resourceid = r.id AND "
		       .       "r.subid = t.id";
		if($type == 'computer' || $type == 'image')
			$query .= " AND t.deleted = 0";
		$qh = doQuery($query, 101);
		$members = '';
		while($row = mysql_fetch_assoc($qh))
			$members .= "{$row['item']}<br>";
		if($members == '')
			$members = '(empty group)';
		$arr = array('members' => $members, 'domid' => $domid);
		sendJSON($arr);
	}
	else {
		$members = '(failed to lookup members)';
		$arr = array('members' => $members, 'domid' => $domid);
		sendJSON($arr);
	}
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
///                    [priv0] => 1\n
///                        ...\n
///                    [privN] => 1\n
///                )\n
///                ...\n
///            [useridN] => Array()\n
///        )\n
///    [usergroups] => Array\n
///        (\n
///            [group0 id] => Array\n
///                (\n
///                    [priv0] => 1\n
///                        ...\n
///                    [privN] => 1\n
///                )\n
///                ...\n
///            [groupN id] => Array()\n
///        )\n
///)
///
/// \brief gets the requested privileges at the specified node
///
////////////////////////////////////////////////////////////////////////////////
function getNodePrivileges($node, $type="all", $privs=0) {
	global $user;
	$key = getKey(array($node, $type, $privs));
	if(isset($_SESSION['nodeprivileges'][$key]))
		return $_SESSION['nodeprivileges'][$key];
	if(! $privs)
		$privs = array("resources" => array(),
		               "users" => array(),
		               "usergroups" => array());
	static $resourcedata = array();
	if(empty($resourcedata)) {
		$query = "SELECT g.id AS id, "
		       .        "p.type AS privtype, "
		       .        "g.name AS name, "
		       .        "t.name AS type, "
		       .        "p.privnodeid "
		       . "FROM resourcepriv p, "
		       .      "resourcetype t, "
		       .      "resourcegroup g "
		       . "WHERE p.resourcegroupid = g.id AND "
		       .       "g.resourcetypeid = t.id "
		       . "ORDER BY p.privnodeid";
		$qh = doQuery($query, 350);
		while($row = mysql_fetch_assoc($qh)) {
			$resourcedata[$row['privnodeid']][] = $row;
		}
	}
	if($type == "resources" || $type == "all") {
		if(isset($resourcedata[$node])) {
			foreach($resourcedata[$node] as $data) {
				$name = "{$data["type"]}/{$data["name"]}/{$data["id"]}";
				$privs["resources"][$name][$data["privtype"]] = 1;
			}
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
		       .       "t.name NOT IN ('configAdmin', 'serverProfileAdmin') AND "
		       .       "up.userid = u.id AND "
		       .       "up.userid IS NOT NULL AND "
		       .       "u.affiliationid = a.id "
		       . "ORDER BY u.unityid";
		$qh = doQuery($query, 351);
		while($row = mysql_fetch_assoc($qh))
			$privs['users'][$row['unityid']][$row['name']] = 1;
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
		       .       "t.name NOT IN ('configAdmin', 'serverProfileAdmin') AND "
		       .       "up.usergroupid = g.id AND "
		       .       "up.usergroupid IS NOT NULL "
		       . "ORDER BY g.name";
		$qh = doQuery($query, 352);
		while($row = mysql_fetch_assoc($qh)) {
			if(isset($privs["usergroups"][$row["id"]]))
				$privs["usergroups"][$row["id"]]['privs'][$row['priv']] = 1;
			else
				$privs["usergroups"][$row["id"]] = array('id' => $row['id'],
				                                         'name' => $row['groupname'],
				                                         'affiliationid' => $row['affiliationid'],
				                                         'affiliation' => $row['affiliation'],
				                                         'privs' => array($row['priv'] => 1));
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
/// getNodePrivileges
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
///                    [priv0] => 1\n
///                        ...\n
///                    [privN] => 1\n
///                )\n
///                ...\n
///            [useridN] => Array()\n
///        )\n
///    [usergroups] => Array\n
///        (\n
///            [group0 id] => Array\n
///                (\n
///                    [priv0] => 1\n
///                        ...\n
///                    [privN] => 1\n
///                )\n
///                ...\n
///            [groupN id] => Array()\n
///        )\n
///)
///
/// \brief gets the requested cascaded privileges for the specified node
///
////////////////////////////////////////////////////////////////////////////////
function getNodeCascadePrivileges($node, $type="all", $privs=0) {
	$key = getKey(array($node, $type, $privs));
	if(isset($_SESSION['cascadenodeprivileges'][$key]))
		return $_SESSION['cascadenodeprivileges'][$key];
	if(! $privs)
		$privs = array("resources" => array(),
		               "users" => array(),
		               "usergroups" => array());

	# get node's parents
	$nodelist = getParentNodes($node);

	# get all block data
	static $allblockdata = array();
	if(empty($allblockdata)) {
		$query = "SELECT g.id, "
		       .        "g.name, "
		       .        "t.name AS type, "
		       .        "p.privnodeid "
		       . "FROM resourcepriv p, "
		       .      "resourcetype t, "
		       .      "resourcegroup g "
		       . "WHERE p.resourcegroupid = g.id AND "
		       .       "g.resourcetypeid = t.id AND "
		       .       "p.type = 'block'";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh)) {
			if(! isset($allblockdata[$row['privnodeid']]))
				$allblockdata[$row['privnodeid']] = array();
			# TODO adding the id at the end will fix the bug where blocking cascaded resource
			#   privileges are only blocked at the node and the block is not cascaded to
			#   child nodes
			$allblockdata[$row['privnodeid']][] = "{$row["type"]}/{$row["name"]}";
			#$allblockdata[$row['privnodeid']][] = "{$row["type"]}/{$row["name"]}/{$row['id']}";
		}
	}

	# get resource group block data
	$inlist = implode(',', $nodelist);
	$blockdata = array();
	foreach($nodelist as $nodeid) {
		if(isset($allblockdata[$nodeid]))
			$blockdata[$nodeid] = $allblockdata[$nodeid];
	}

	# get all cascade data
	static $allcascadedata = array();
	if(empty($allcascadedata)) {
		$query = "SELECT g.id AS id, "
		       .        "p.type AS privtype, "
		       .        "g.name AS name, "
		       .        "t.name AS type, "
		       .        "p.privnodeid "
		       . "FROM resourcepriv p, "
		       .      "resourcetype t, "
		       .      "resourcegroup g, "
		       .      "resourcepriv p2 "
		       . "WHERE p.resourcegroupid = g.id AND "
		       .       "g.resourcetypeid = t.id AND "
		       .       "p.type != 'block' AND "
		       .       "p.type != 'cascade' AND "
		       .       "p.resourcegroupid = p2.resourcegroupid AND "
		       .       "p.privnodeid = p2.privnodeid AND "
		       .       "p2.type = 'cascade'";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh)) {
			if(! isset($allcascadedata[$row['privnodeid']]))
				$allcascadedata[$row['privnodeid']] = array();
			$allcascadedata[$row['privnodeid']][] =
			   array('name' => "{$row["type"]}/{$row["name"]}/{$row["id"]}",
			         'type' => $row['privtype']);
		}
	}

	# get all privs for users with cascaded privs
	$cascadedata = array();
	foreach($nodelist as $nodeid) {
		if(isset($allcascadedata[$nodeid]))
			$cascadedata[$nodeid] = $allcascadedata[$nodeid];
	}

	if($type == "resources" || $type == "all") {
		$mynodelist = $nodelist;
		# loop through each node, starting at the root
		while(count($mynodelist)) {
			$mynode = array_pop($mynodelist);
			# get all resource groups with block set at this node and remove any cascaded privs
			if(isset($blockdata[$mynode])) {
				foreach($blockdata[$mynode] as $name)
					unset($privs["resources"][$name]);
			}

			# get all privs for users with cascaded privs
			if(isset($cascadedata[$mynode])) {
				foreach($cascadedata[$mynode] as $data) {
					$privs["resources"][$data['name']][$data["type"]] = 1;
				}
			}
		}
	}
	if($type == "users" || $type == "all") {
		static $nodeuserblock = array();
		if(empty($nodeuserblock)) {
			$query = "SELECT up.privnodeid, "
			       .        "CONCAT(u.unityid, '@', a.name) AS unityid "
			       . "FROM user u, "
			       .      "userpriv up, "
			       .      "userprivtype t, "
			       .      "affiliation a "
			       . "WHERE up.userprivtypeid = t.id AND "
			       .       "t.name NOT IN ('configAdmin', 'serverProfileAdmin') AND "
			       .       "up.userid = u.id AND "
			       .       "up.userid IS NOT NULL AND "
			       .       "t.name = 'block' AND "
			       .       "u.affiliationid = a.id";
			$qh = doQuery($query, 355);
			while($row = mysql_fetch_row($qh))
				$nodeuserblock[$row[0]][$row[1]] = 1;
		}
		static $nodeusercasade;
		if(empty($nodeusercascade)) {
			# get all privs for users with cascaded privs
			$query = "SELECT up.privnodeid, "
			       .        "CONCAT(u.unityid, '@', a.name) AS unityid, "
			       .        "t.name AS name "
			       . "FROM user u, "
			       .      "userpriv up, "
			       .      "userprivtype t, "
			       . 	  "affiliation a, "
			       . 	  "userpriv Cup, "
			       . 	  "userprivtype Ct "
			       . "WHERE up.userprivtypeid = t.id AND "
			       .       "up.userid = u.id AND "
			       .       "u.affiliationid = a.id AND "
			       .       "up.userid IS NOT NULL AND "
			       .       "t.name != 'cascade' AND "
			       .       "t.name != 'block' AND "
			       .       "t.name NOT IN ('configAdmin', 'serverProfileAdmin') AND "
			       . 		"Cup.userprivtypeid = Ct.id AND "
			       . 		"Ct.name = 'cascade' AND "
			       . 		"Cup.privnodeid = up.privnodeid AND "
			       . 		"up.userid = Cup.userid "
			       . "ORDER BY up.privnodeid, u.unityid, t.name";
			$qh = doQuery($query, 356);
			while($row = mysql_fetch_row($qh))
				$nodeusercascade[$row[0]][$row[1]][$row[2]] = 1;
		}
		$mynodelist = $nodelist;
		# loop through each node, starting at the root
		while(count($mynodelist)) {
			$mynode = array_pop($mynodelist);
			# get all users with block set at this node and remove any cascaded privs
			if(isset($nodeuserblock[$mynode])) {
				foreach($nodeuserblock[$mynode] as $unityid => $tmp)
					unset($privs['users'][$unityid]);
			}

			# get all privs for users with cascaded privs
			if(isset($nodeusercascade[$mynode])) {
				foreach($nodeusercascade[$mynode] as $unityid => $vals) {
					if(isset($privs['users'][$unityid]))
						$privs["users"][$unityid] += $vals;
					else
						$privs["users"][$unityid] = $vals;
				}
			}
		}
	}
	if($type == "usergroups" || $type == "all") {
		static $nodegroupblock = array();
		if(empty($nodegroupblock)) {
			$query = "SELECT up.privnodeid, "
			       .        "g.id "
			       . "FROM usergroup g, "
			       .      "userpriv up, "
			       .      "userprivtype t "
			       . "WHERE up.userprivtypeid = t.id AND "
			       .       "t.name NOT IN ('configAdmin', 'serverProfileAdmin') AND "
			       .       "up.usergroupid = g.id AND "
			       .       "up.usergroupid IS NOT NULL AND "
			       .       "t.name = 'block'";
			$qh = doQuery($query, 357);
			while($row = mysql_fetch_row($qh))
				$nodegroupblock[$row[0]][$row[1]] = 1;
		}
		static $nodegroupcascade;
		if(empty($nodegroupcascade)) {
			# get all privs for users with cascaded privs
			$query = "SELECT up.privnodeid, "
			       .        "g.id, "
			       .        "g.name AS groupname, "
			       .        "g.affiliationid, "
			       .        "a.name AS affiliation, "
			       .        "t.name AS priv "
			       . "FROM userpriv up, "
			       .      "userprivtype t, "
			       . 	  "userpriv Cup, "
			       . 	  "userprivtype Ct, "
			       . 	  "usergroup g "
			       . "LEFT JOIN affiliation a ON (g.affiliationid = a.id) "
			       . "WHERE up.userprivtypeid = t.id AND "
			       .       "up.usergroupid = g.id AND "
			       .       "up.usergroupid IS NOT NULL AND "
			       .       "t.name != 'cascade' AND "
			       .       "t.name != 'block' AND "
			       .       "t.name NOT IN ('configAdmin', 'serverProfileAdmin') AND "
			       . 		"Cup.userprivtypeid = Ct.id AND "
			       . 		"Ct.name = 'cascade' AND "
			       . 		"Cup.privnodeid = up.privnodeid AND "
			       . 		"up.usergroupid = Cup.usergroupid "
			       . "ORDER BY up.privnodeid, g.id, t.name";
			$qh = doQuery($query, 356);
			while($row = mysql_fetch_row($qh)) {
				if(! isset($nodegroupcascade[$row[0]][$row[1]])) {
					$nodegroupcascade[$row[0]][$row[1]] = array('id' => $row[1],
						                                         'name' => $row[2],
						                                         'affiliationid' => $row[3],
						                                         'affiliation' => $row[4],
						                                         'privs' => array($row[5] => 1));
				}
				else
					$nodegroupcascade[$row[0]][$row[1]]['privs'][$row[5]] = 1;
			}
		}
		$mynodelist = $nodelist;
		# loop through each node, starting at the root
		while(count($mynodelist)) {
			$mynode = array_pop($mynodelist);
			# get all groups with block set at this node and remove any cascaded privs
			if(isset($nodegroupblock[$mynode])) {
				foreach($nodegroupblock[$mynode] as $groupid => $tmp)
					unset($privs['usergroups'][$groupid]);
			}

			# get all privs for groups with cascaded privs
			if(isset($nodegroupcascade[$mynode])) {
				foreach($nodegroupcascade[$mynode] as $groupid => $data) {
					if(isset($privs['usergroups'][$groupid]))
						$privs["usergroups"][$groupid]['privs'] += $data['privs'];
					else
						$privs["usergroups"][$groupid] = $data;
				}
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
/// submits the changes to the database
///
////////////////////////////////////////////////////////////////////////////////
function AJchangeUserPrivs() {
	global $user;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("userGrant", $user["id"], $node)) {
		$text = "You do not have rights to modify user privileges at this node.";
		print "alert('$text');";
		return;
	}
	$newuser = processInputVar("item", ARG_STRING);
	$newpriv = processInputVar('priv', ARG_STRING);
	$newprivval = processInputVar('value', ARG_STRING);

	if(! validateUserid($newuser)) {
		$text = "Invalid user submitted.";
		print "alert('$text');";
		return;
	}

	$privid = getUserPrivTypeID($newpriv);
	if(is_null($privid)) {
		$text = "Invalid user privilege submitted.";
		print "alert('$text');";
		return;
	}

	# get cascade privs at this node
	$cascadePrivs = getNodeCascadePrivileges($node, "users");

	if($newprivval == 'true') {
		// if $newuser already has $newpriv cascaded to it, do nothing
		if(isset($cascadePrivs['users'][$newuser][$newpriv]))
			return;
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
	$userid = getUserlistID($newuser);
	if($userid == $user['id'] && in_array($newpriv, array('nodeAdmin', 'block', 'cascade')))
		print "refreshNodeDropData();";
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
		return;
	}
	$newusergrpid = processInputVar("item", ARG_NUMERIC);
	$newpriv = processInputVar('priv', ARG_STRING);
	$newprivval = processInputVar('value', ARG_STRING);

	$newusergrp = getUserGroupName($newusergrpid);
	if($newusergrp === 0) {
		$text = "Invalid user group submitted.";
		print "alert('$text');";
		return;
	}

	$privid = getUserPrivTypeID($newpriv);
	if(is_null($privid)) {
		$text = "Invalid user privilege submitted.";
		print "alert('$text');";
		return;
	}

	# get cascade privs at this node
	$cascadePrivs = getNodeCascadePrivileges($node, "usergroups");

	if($newprivval == 'true') {
		// if $newusergrp already has $newpriv cascaded to it, do nothing
		if(isset($cascadePrivs['usergroups'][$newusergrp]['privs'][$newpriv]))
			return;
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
	if(isset($user['groups'][$newusergrpid]) &&
	   in_array($newpriv, array('nodeAdmin', 'block', 'cascade')))
		print "refreshNodeDropData();";
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
		return;
	}
	$resourcegrp = processInputVar("item", ARG_STRING);
	$newpriv = processInputVar('priv', ARG_STRING);
	$newprivval = processInputVar('value', ARG_STRING);

	$allprivs = getResourcePrivs();
	if(! in_array($newpriv, $allprivs)) {
		$text = "Invalid resource privilege submitted.";
		print "alert('$text');";
		return;
	}

	$resourcetypes = getTypes('resources');
	$types = implode('|', $resourcetypes['resources']);
	if(! preg_match("@($types)/([^/]+)/([0-9]+)@", $resourcegrp, $matches)) {
		$text = "Invalid resource group submitted.";
		print "alert('$text');";
		return;
	}

	$type = $matches[1];
	$groupid = $matches[3];

	$groupdata = getResourceGroups($type, $groupid);
	if(empty($groupdata)) {
		$text = "Invalid resource group submitted.";
		print "alert('$text');";
		return;
	}

	// if $type is administer, manageGroup, or manageMapping, and it is not
	# checked, and the user is not in the resource owner group, don't allow
	# the change
	if($newpriv != "block" && $newpriv != "cascade" && $newpriv != "available" &&
	   ! array_key_exists($groupdata[$groupid]["ownerid"], $user["groups"]) &&
	   $newprivval == 'true') {
		$text = "You do not have rights to modify the submitted privilege for the submitted group.";
		print "alert('$text');";
		return;
	}

	# get privs at this node
	$privs = getNodePrivileges($node, 'resources');
	$cascadePrivs = getNodeCascadePrivileges($node, "resources");

	if($newprivval == 'true') {
		// if $resourcegrp already has $newpriv cascaded to it, do nothing
		if(isset($cascadePrivs['resources'][$resourcegrp][$newpriv]) &&
		   ! isset($privs['resources'][$resourcegrp]['block']))
			return;
		// add priv
		$adds = array($newpriv);
		$removes = array();
	}
	else {
		// remove priv
		$adds = array();
		$removes = array($newpriv);
	}
	updateResourcePrivs($groupid, $node, $adds, $removes);
	$_SESSION['dirtyprivs'] = 1;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsubmitAddUserPriv()
///
/// \brief processes input for adding privileges to a node for a user; adds the
/// privileges
///
////////////////////////////////////////////////////////////////////////////////
function AJsubmitAddUserPriv() {
	global $user;
	$node = processInputVar("activeNode", ARG_NUMERIC);
	if(! checkUserHasPriv("userGrant", $user["id"], $node)) {
		$text = "You do not have rights to add new users at this node.";
		print "addUserPaneHide(); ";
		print "alert('$text');";
		return;
	}
	$newuser = processInputVar("newuser", ARG_STRING);
	if(! validateUserid($newuser)) {
		$text = "<font color=red>$newuser is not a valid userid</font>";
		print setAttribute('addUserPrivStatus', 'innerHTML', $text);
		return;
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
	   isset($newuserprivs["cascade"]))) {
		$text = "<font color=red>No user privileges were specified</font>";
		print setAttribute('addUserPrivStatus', 'innerHTML', $text);
		return;
	}

	updateUserOrGroupPrivs($newuser, $node, $newuserprivs, array(), "user");
	clearPrivCache();
	print "refreshPerms(); ";
	print "addUserPaneHide(); ";
	$userid = getUserlistID($newuser);
	if($userid == $user['id'] && 
	   (isset($perms['nodeAdmin']) ||
	   isset($perms['cascade']) ||
	   isset($perms['block'])))
		print nodeDropData();
}

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
		return;
	}
	$newgroupid = processInputVar("newgroupid", ARG_NUMERIC);

	$newgroup = getUserGroupName($newgroupid);
	if($newgroup === 0) {
		$text = "Invalid user group submitted.";
		print "alert('$text');";
		return;
	}

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
	   isset($newgroupprivs["cascade"]))) {
		$text = "<font color=red>No user group privileges were specified</font>";
		print setAttribute('addUserGroupPrivStatus', 'innerHTML', $text);
		return;
	}

	updateUserOrGroupPrivs($newgroupid, $node, $newgroupprivs, array(), "group");
	clearPrivCache();
	print "refreshPerms(); ";
	print "addUserGroupPaneHide(); ";
	if(isset($user['groups'][$newgroupid]) &&
	   (isset($perms['nodeAdmin']) ||
	   isset($perms['cascade']) ||
	   isset($perms['block'])))
		print nodeDropData();
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
		print "addResourceGroupPaneHide(); ";
		print "alert('$text');";
		return;
	}
	$newgroupid = processInputVar("newgroupid", ARG_NUMERIC);
	$privs = array("computerAdmin", "mgmtNodeAdmin", "imageAdmin",
	               "scheduleAdmin", "serverProfileAdmin");
	$resourcegroups = getUserResources($privs, array("manageGroup"), 1);

	$groupdata = getResourceGroups('', $newgroupid);

	if(empty($groupdata)) {
		$text = "Invalid resource group submitted.";
		print "addResourceGroupPaneHide(); ";
		print "alert('$text');";
		return;
	}

	list($newtype, $tmp) = explode('/', $groupdata[$newgroupid]['name']);
	if(! isset($resourcegroups[$newtype][$newgroupid])) {
		$text = "You do not have rights to manage the specified resource group.";
		print "addResourceGroupPaneHide(); ";
		print "alert('$text');";
		return;
	}

	$perms = explode(':', processInputVar('perms', ARG_STRING));
	$privtypes = getResourcePrivs();
	$newgroupprivs = array();
	foreach($privtypes as $type) {
		if(($newtype == 'addomain' && ($type == 'available' || $type == 'manageMapping')) ||
		   ($newtype == 'schedule' && ($type == 'available' || $type == 'manageMapping')) ||
		   ($newtype == 'managementnode' && $type == 'available'))
			continue;
		if(in_array($type, $perms))
			array_push($newgroupprivs, $type);
	}
	if(empty($newgroupprivs) || (count($newgroupprivs) == 1 && 
	   in_array("cascade", $newgroupprivs))) {
		$text = "<font color=red>No resource group privileges were specified or privileges do not<br>apply to the specified type</font>";
		print setAttribute('addResourceGroupPrivStatus', 'innerHTML', $text);
		return;
	}

	updateResourcePrivs($newgroupid, $node, $newgroupprivs, array());
	clearPrivCache();
	print "refreshPerms(); ";
	print "addResourceGroupPaneHide(); ";
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
	if(isset($_SESSION['userhaspriv'][$key]))
		return $_SESSION['userhaspriv'][$key];
	if($user["id"] != $uid) {
		$_user = getUserInfo($uid, 0, 1);
		if(is_null($user))
			return 0;
	}
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
	if(isset($privs["users"][$affilUserid][$priv]) ||
	   (isset($cascadePrivs["users"][$affilUserid][$priv]) &&
	   ! isset($privs["users"][$affilUserid]['block']))) {
		$_SESSION['userhaspriv'][$key] = 1;
		return 1;
	}

	foreach($_user["groups"] as $groupid => $groupname) {
		// if group (has $priv at this node) ||
		# (has cascaded $priv && ! have block at this node) return 1
		if(isset($privs["usergroups"][$groupid]['privs'][$priv]) ||
		   (isset($cascadePrivs["usergroups"][$groupid]['privs'][$priv]) &&
		   ! isset($privs["usergroups"][$groupid]['privs']['block']))) {
			$_SESSION['userhaspriv'][$key] = 1;
			return 1;
		}
	}
	$_SESSION['userhaspriv'][$key] = 0;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJpermSelectUserGroup()
///
/// \brief gets permissions granted to a user group and sends it in JSON format
///
////////////////////////////////////////////////////////////////////////////////
function AJpermSelectUserGroup() {
	global $user;
	$groups = getUserGroups(0, $user['affiliationid']);
	$groupid = processInputVar('groupid', ARG_NUMERIC);
	if(! array_key_exists($groupid, $groups)) {
		sendJSON(array('failed' => 'noaccess'));
		return;
	}
	$permdata = getUserGroupPrivs($groupid);
	$perms = array();
	foreach($permdata as $perm)
		$perms[] = $perm['permid'];
	sendJSON(array('perms' => $perms));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJsaveUserGroupPrivs()
///
/// \brief saves submitted permissions for user group
///
////////////////////////////////////////////////////////////////////////////////
function AJsaveUserGroupPrivs() {
	global $user;
	$groups = getUserGroups(0, $user['affiliationid']);
	$groupid = processInputVar('groupid', ARG_NUMERIC);
	if(! array_key_exists($groupid, $groups)) {
		sendJSON(array('failed' => 'noaccess'));
		return;
	}
	$permids = processInputVar('permids', ARG_STRING);
	if(! preg_match('/^[0-9,]*$/', $permids)) {
		sendJSON(array('failed' => 'invalid input'));
		return;
	}
	$perms = explode(',', $permids);
	$query = "DELETE FROM usergrouppriv WHERE usergroupid = $groupid";
	doQuery($query, 101);
	if(empty($perms[0])) {
		sendJSON(array('success' => 1));
		return;
	}
	$values = array();
	foreach($perms as $permid)
		$values[] = "($groupid, $permid)";
	$allvals = implode(',', $values);
	$query = "INSERT INTO usergrouppriv "
	       .        "(usergroupid, "
	       .        "userprivtypeid) "
	       . "VALUES $allvals";
	doQuery($query, 101);
	sendJSON(array('success' => 1));
	$_SESSION['user']["groupperms"] = getUsersGroupPerms(array_keys($user['groups']));
}

?>
