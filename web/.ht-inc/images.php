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

/// signifies an error with the submitted name
define("NAMEERR", 1);
/// signifies an error with the submitted pretty name
define("PRETTYNAMEERR", 1 << 1);
/// signifies an error with the submitted minimum number amount of RAM
define("MINRAMERR", 1 << 2);
/// signifies an error with the submitted minimum processor speed
define("MINPROCSPEEDERR", 1 << 3);
/// signifies an error with the submitted estimated reload time
define("RELOADTIMEERR", 1 << 4);
/// signifies an error with the submitted owner
define("IMGOWNERERR", 1 << 5);
/// signifies an error with the submitted maximum concurrent usage
define("MAXCONCURRENTERR", 1 << 6);
/// signifies an error with the submitted image description
define("IMAGEDESCRIPTIONERR", 1 << 7);


////////////////////////////////////////////////////////////////////////////////
///
/// \fn selectImageOption()
///
/// \brief prints a page for the user to select which image operation they want
/// to perform; if they only have access to a few options or only a few images,
/// just send them straight to viewImagesAll
///
////////////////////////////////////////////////////////////////////////////////
function selectImageOption() {
	# get a count of images user can administer
	$tmp = getUserResources(array("imageAdmin"), array("administer"));
	$imgAdminCnt = count($tmp['image']);

	# get a count of images user has access to for creating new images
	$tmp = getUserResources(array("imageAdmin"), array("available"));
	$imgCnt = count($tmp['image']);

	# get a count of image groups user can manage
	$tmp = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	$imgGroupCnt = count($tmp['image']);

	# get a count of computer groups user can manage
	$tmp = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	$compGroupCnt = count($tmp['computer']);

	print "<H2>Manage Images</H2>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	if($imgAdminCnt) {
		$cont = addContinuationsEntry('viewImages');
		print "<INPUT type=radio name=continuation value=\"$cont\" checked>Edit ";
		print "Image Profiles<br>\n";
		print "<img src=images/blank.gif width=20><INPUT type=checkbox name=";
		print "details value=1>Include details<br>\n";
	}

	if($imgGroupCnt) {
		$cont = addContinuationsEntry('viewImageGrouping');
		print "<INPUT type=radio name=continuation value=\"$cont\">Edit ";
		print "Image Grouping<br>\n";

		if($compGroupCnt) {
			$cont = addContinuationsEntry('viewImageMapping');
			print "<INPUT type=radio name=continuation value=\"$cont\">Edit ";
			print "Image Mapping<br>\n";
		}
	}

	if($imgCnt) {
		$cont = addContinuationsEntry('createSelectImage');
		print "<INPUT type=radio name=continuation value=\"$cont\">Create&nbsp;/";
		print "&nbsp;Update an Image<br>\n";
	}

	if($imgAdminCnt || $imgGroupCnt || $imgCnt)
		print "<br><INPUT type=submit value=Submit>\n";
	else
		print "You don't have access to manage any images.<br>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewImages()
///
/// \brief prints a page to view image information
///
////////////////////////////////////////////////////////////////////////////////
function viewImages() {
	global $viewmode, $user, $mode;
	$showdeleted = getContinuationVar("showdeleted", 0);
	$deleted = getContinuationVar("deleted");
	$details = processInputVar("details", ARG_NUMERIC);

	if($showdeleted) {
		$images = getImages(1);
		$resources = getUserResources(array("imageAdmin"), 
		                              array("administer"), 0, 1);
	}
	else {
		$images = getImages();
		$resources = getUserResources(array("imageAdmin"), array("administer"));
	}
	$userImageIDs = array_keys($resources["image"]);
	$platforms = getPlatforms();
	$oslist = getOSList();

	print "<H2>Image Profiles</H2>\n";
	if($mode == "submitDeleteImage") {
		if($deleted) {
			print "<font color=\"#008000\">Image successfully undeleted";
			print "</font><br><br>\n";
		}
		else {
			print "<font color=\"#008000\">Image successfully set to deleted ";
			print "state</font><br><br>\n";
		}
	}
	elseif($mode == "submitEditImage") {
		print "<font color=\"#008000\">Image successfully updated";
		print "</font><br><br>\n";
	}
	print "<TABLE border=1>\n";
	print "  <TR>\n";
	print "    <TD></TD>\n";
	print "    <TH><img src=images/blank.gif width=100 height=1><br>Name</TH>\n";
	print "    <TH>Owner</TH>\n";
	print "    <TH>Platform</TH>\n";
	print "    <TH><img src=images/blank.gif width=70 height=1><br>OS</TH>\n";
	print "    <TH>Estimated Reload Time (min)</TH>\n";
	if($details) {
		print "    <TH>Minimum RAM (MB)</TH>\n";
		print "    <TH>Minimum Num of Processors</TH>\n";
		print "    <TH>Minimum Processor Speed (MHz)</TH>\n";
		print "    <TH>Minimum Network Speed (Mbps)</TH>\n";
		print "    <TH>Maximum Concurrent Usage</TH>\n";
	}
	if($showdeleted) {
		print "    <TH>Deleted</TH>\n";
	}
	print "  </TR>\n";
	foreach(array_keys($images) as $id) {
		if(! in_array($id, $userImageIDs))
			continue;
		print "  <TR>\n";
		print "    <TD align=center>\n";
		print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$cdata = array('imageid' => $id);
		$cont = addContinuationsEntry('submitImageButton', $cdata);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
		if($showdeleted && $images[$id]["deleted"] == 1) {
			print "      <INPUT type=submit name=submode value=Undelete>\n";
		}
		else {
			print "      <INPUT type=submit name=submode value=Edit>\n";
			print "      <INPUT type=submit name=submode value=Delete><br>\n";
		}
		print "      <INPUT type=submit name=submode value=Details>\n";
		print "      </FORM>\n";
		print "    </TD>\n";
		print "    <TD align=center>" . $images[$id]["prettyname"] . "</TD>\n";
		print "    <TD align=center>" . $images[$id]["owner"] . "</TD>\n";
		print "    <TD align=center>" . $images[$id]["platform"] . "</TD>\n";
		print "    <TD align=center>" . $oslist[$images[$id]["osid"]]["prettyname"] . "</TD>\n";
		print "    <TD align=center>" . $images[$id]["reloadtime"] . "</TD>\n";
		if($details) {
			print "    <TD align=center>" . $images[$id]["minram"] . "</TD>\n";
			print "    <TD align=center>" . $images[$id]["minprocnumber"] . "</TD>\n";
			print "    <TD align=center>" . $images[$id]["minprocspeed"] . "</TD>\n";
			print "    <TD align=center>" . $images[$id]["minnetwork"] . "</TD>\n";
			if($images[$id]['maxconcurrent'] == '')
				print "    <TD align=center>N/A</TD>\n";
			else
				print "    <TD align=center>" . $images[$id]["maxconcurrent"] . "</TD>\n";
		}
		if($showdeleted) {
			print "    <TD align=center>" . $images[$id]["deleted"] . "</TD>\n";
		}
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	if($showdeleted) {
		$cdata = array('showdeleted' => 0);
		print "<INPUT type=submit value=\"Hide Deleted Images\">\n";
	}
	else {
		$cdata = array('showdeleted' => 1);
		print "<INPUT type=submit value=\"Include Deleted Images\">\n";
	}
	$cont = addContinuationsEntry('viewImages', $cdata);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewImageGrouping()
///
/// \brief prints a page to view and modify image grouping
///
////////////////////////////////////////////////////////////////////////////////
function viewImageGrouping() {
	global $mode;
	$resources = getUserResources(array("imageAdmin"), 
	                              array("manageGroup"));
	if(! count($resources["image"])) {
		print "<H2>Image Grouping</H2>\n";
		print "You don't have access to modify any image groups.<br>\n";
		return;
	}
	if($mode == 'submitImageGroups')
		$gridSelected = "selected=\"true\"";
	else
		$gridSelected = "";
	
	print "<H2>Image Grouping</H2>\n";
	print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	print "     style=\"width:800px;height:600px\">\n";

	# by image tab
	print "<div id=\"resource\" dojoType=\"dijit.layout.ContentPane\" title=\"By Image\">\n";
	print "Select an image and click \"Get Groups\" to see all of the groups ";
	print "it is in. Then,<br>select a group it is in and click the Remove ";
	print "button to remove it from that group,<br>or select a group it is not ";
	print "in and click the Add button to add it to that group.<br><br>\n";
	print "Image:<select name=images id=images>\n";
	# build list of images
	$tmp = getUserResources(array('imageAdmin'), array('manageGroup'));
	$images = $tmp['image'];
	uasort($images, 'sortKeepIndex');
	foreach($images as $id => $image) {
		print "<option value=$id>$image</option>\n";
	}
	print "</select>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchGrpsButton\">\n";
	print "	Get Groups\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getGroupsButton();\n";
	print "	</script>\n";
	print "</button>\n";
	print "<table><tbody><tr>\n";
	# select for groups image is in
	print "<td valign=top>\n";
	print "Groups <span style=\"font-weight: bold;\" id=inimagename></span> is in:<br>\n";
	print "<select name=ingroups multiple id=ingroups size=20>\n";
	print "</select>\n";
	print "</td>\n";
	# transfer buttons
	print "<td style=\"vertical-align: middle;\">\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"addBtn1\">\n";
	print "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJaddGroupToImage');
	print "		addRemItem('$cont', 'images', 'outgroups', addRemImage2);\n";
	print "	</script>\n";
	print "</button>\n";
	print "<br>\n";
	print "<br>\n";
	print "<br>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"remBtn1\">\n";
	print "	<div style=\"width: 50px;\">Remove-&gt;</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJremGroupFromImage');
	print "		addRemItem('$cont', 'images', 'ingroups', addRemImage2);\n";
	print "	</script>\n";
	print "</button>\n";
	print "</td>\n";
	# select for groups image is not in
	print "<td valign=top>\n";
	print "Groups <span style=\"font-weight: bold;\" id=outimagename></span> is not in:<br>\n";
	print "<select name=outgroups multiple id=outgroups size=20>\n";
	print "</select>\n";
	print "</td>\n";
	print "</tr><tbody/></table>\n";
	print "</div>\n";

	# by group tab
	print "<div id=\"group\" dojoType=\"dijit.layout.ContentPane\" title=\"By Group\">\n";
	print "Select a group and click \"Get Images\" to see all of the images ";
	print "in it. Then,<br>select an image in it and click the Remove ";
	print "button to remove it from the group,<br>or select an image that is not ";
	print "in it and click the Add button to add it to the group.<br><br>\n";
	print "Group:<select name=imgGroups id=imgGroups>\n";
	# build list of groups
	$tmp = getUserResources(array('imageAdmin'), array('manageGroup'), 1);
	$groups = $tmp['image'];
	uasort($groups, 'sortKeepIndex');
	foreach($groups as $id => $group) {
		print "<option value=$id>$group</option>\n";
	}
	print "</select>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchImgsButton\">\n";
	print "	Get Images\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getImagesButton();\n";
	print "	</script>\n";
	print "</button>\n";
	print "<table><tbody><tr>\n";
	# select for images in group
	print "<td valign=top>\n";
	print "Images in <span style=\"font-weight: bold;\" id=ingroupname></span>:<br>\n";
	print "<select name=inimages multiple id=inimages size=20>\n";
	print "</select>\n";
	print "</td>\n";
	# transfer buttons
	print "<td style=\"vertical-align: middle;\">\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"addBtn2\">\n";
	print "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJaddImageToGroup');
	print "		addRemItem('$cont', 'imgGroups', 'outimages', addRemGroup2);\n";
	print "	</script>\n";
	print "</button>\n";
	print "<br>\n";
	print "<br>\n";
	print "<br>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"remBtn2\">\n";
	print "	<div style=\"width: 50px;\">Remove-&gt;</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJremImageFromGroup');
	print "		addRemItem('$cont', 'imgGroups', 'inimages', addRemGroup2);\n";
	print "	</script>\n";
	print "</button>\n";
	print "</td>\n";
	# images not in group select
	print "<td valign=top>\n";
	print "Images not in <span style=\"font-weight: bold;\" id=outgroupname></span>:<br>\n";
	print "<select name=outimages multiple id=outimages size=20>\n";
	print "</select>\n";
	print "</td>\n";
	print "</tr><tbody/></table>\n";
	print "</div>\n";

	# grid tab
	$cont = addContinuationsEntry('imageGroupingGrid');
	$loadingmsg = "<span class=dijitContentPaneLoading>Loading page (this may take a really long time)</span>";
	print "<a jsId=\"checkboxpane\" dojoType=\"dijit.layout.LinkPane\"\n";
	print "   href=\"index.php?continuation=$cont\"\n";
	print "   loadingMessage=\"$loadingmsg\" $gridSelected>\n";
	print "   Checkbox Grid</a>\n";

	print "</div>\n"; # end of main tab container
	$cont = addContinuationsEntry('jsonImageGroupingImages');
	print "<input type=hidden id=imgcont value=\"$cont\">\n";
	$cont = addContinuationsEntry('jsonImageGroupingGroups');
	print "<input type=hidden id=grpcont value=\"$cont\">\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn imageGroupingGrid()
///
/// \brief prints a page to view and modify image grouping
///
////////////////////////////////////////////////////////////////////////////////
function imageGroupingGrid() {
	global $mode;
	$imagemembership = getResourceGroupMemberships("image");
	$resources = getUserResources(array("imageAdmin"), 
	                              array("manageGroup"));
	$tmp = getUserResources(array("imageAdmin"), 
	                        array("manageGroup"), 1);
	$imagegroups = $tmp["image"];
	uasort($imagegroups, "sortKeepIndex");
	uasort($resources["image"], "sortKeepIndex");

	print "<FORM id=gridform action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE border=1 summary=\"\">\n";
	print "  <col>\n";
	foreach(array_keys($imagegroups) as $id) {
		print "  <col id=imggrp$id>\n";
	}
	print "  <TR>\n";
	print "    <TH rowspan=2>Image</TH>\n";
	print "    <TH class=nohlcol colspan=" . count($imagegroups) . ">Groups</TH>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	foreach($imagegroups as $id => $group) {
		print "    <TH onclick=\"toggleColSelect('imggrp$id');\">$group</TH>\n";
	}
	print "  </TR>\n";
	$count = 1;
	foreach($resources["image"] as $imageid => $image) {
		if($image == "No Image")
			continue;
		if($count % 8 == 0) {
			print "  <TR>\n";
			print "    <TH><img src=images/blank.gif></TH>\n";
			foreach($imagegroups as $id => $group) {
				print "    <TH onclick=\"toggleColSelect('imggrp$id');\">$group</TH>\n";
			}
			print "  </TR>\n";
		}
		print "  <TR id=imageid$imageid>\n";
		print "    <TH align=right onclick=\"toggleRowSelect('imageid$imageid');\">$image</TH>\n";
		foreach(array_keys($imagegroups) as $groupid) {
			$name = "imagegroup[" . $imageid . ":" . $groupid . "]";
			if(array_key_exists($imageid, $imagemembership["image"]) &&
				in_array($groupid, $imagemembership["image"][$imageid])) {
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
	$cont = addContinuationsEntry('submitImageGroups', array(), SECINWEEK, 1, 0, 1);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=\"Submit Changes\">\n";
	print "<INPUT type=reset value=Reset>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewImageMapping()
///
/// \brief prints a page to modify image group to computer group mappings
///
////////////////////////////////////////////////////////////////////////////////
function viewImageMapping() {
	global $mode;
	$tmp = getUserResources(array("imageAdmin"), 
                           array("manageGroup"), 1);
	$imagegroups = $tmp["image"];
	uasort($imagegroups, "sortKeepIndex");
	$imagecompmapping = getResourceMapping("image", "computer");
	$resources = getUserResources(array("computerAdmin"),
	                              array("manageGroup"), 1);
	$compgroups = $resources["computer"];
	uasort($compgroups, "sortKeepIndex");
	if(! count($imagegroups) || ! count($compgroups)) {
		print "<H2>Image Group to Computer Group Mapping</H2>\n";
		print "You don't have access to manage any image group to computer ";
		print "group mappings.<br>\n";
		return;
	}
	if($mode == 'submitImageMapping')
		$gridSelected = "selected=\"true\"";
	else
		$gridSelected = "";
	
	print "<H2>Image Group to Computer Group Mapping</H2>\n";
	print "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
	print "     style=\"width:800px;height:600px\">\n";

	# by image group
	print "<div id=\"imagegrptab\" dojoType=\"dijit.layout.ContentPane\" ";
	print "title=\"By Image Group\">\n";
	print "Select an image group and click \"Get Computer Groups\" to see all ";
	print "of the computer groups it maps to. Then,<br>select a computer group ";
	print "it maps to and click the Remove button to unmap it from that group, ";
	print "or select a<br>computer group it does not map to and click the Add ";
	print "button to map it to that group.<br><br>\n";
	print "Image Group:<select name=imagegrps id=imagegrps>\n";
	foreach($imagegroups as $id => $group) {
		print "<option value=$id>$group</option>\n";
	}
	print "</select>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchCompGrpsButton\">\n";
	print "	Get Computer Groups\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getMapCompGroupsButton();\n";
	print "	</script>\n";
	print "</button>\n";
	print "<table><tbody><tr>\n";
	# select for comp groups image groups maps to
	print "<td valign=top>\n";
	print "Computer groups <span style=\"font-weight: bold;\" id=inimagegrpname></span> maps to:<br>\n";
	print "<select name=incompgroups multiple id=incompgroups size=20>\n";
	print "</select>\n";
	print "</td>\n";
	# transfer buttons
	print "<td style=\"vertical-align: middle;\">\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"addBtn1\">\n";
	print "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJaddCompGrpToImgGrp');
	print "		addRemItem('$cont', 'imagegrps', 'outcompgroups', addRemCompGrpImgGrp);\n";
	print "	</script>\n";
	print "</button>\n";
	print "<br>\n";
	print "<br>\n";
	print "<br>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"remBtn1\">\n";
	print "	<div style=\"width: 50px;\">Remove-&gt;</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJremCompGrpFromImgGrp');
	print "		addRemItem('$cont', 'imagegrps', 'incompgroups', addRemCompGrpImgGrp);\n";
	print "	</script>\n";
	print "</button>\n";
	print "</td>\n";
	# select for comp groups image groups does not map to
	print "<td valign=top>\n";
	print "Computer groups <span style=\"font-weight: bold;\" id=outimagegrpname></span> does not map to:<br>\n";
	print "<select name=outcompgroups multiple id=outcompgroups size=20>\n";
	print "</select>\n";
	print "</td>\n";
	print "</tr><tbody/></table>\n";
	print "</div>\n";

	# by computer group tab
	print "<div id=\"group\" dojoType=\"dijit.layout.ContentPane\" title=\"By Computer Group\">\n";
	print "Select a computer group and click \"Get Images Groups\" to see all ";
	print "of the image groups it maps to. Then,<br>select an image group ";
	print "it maps to and click the Remove button to unmap it from that group, ";
	print "or select an<br>image group it does not map to and click the Add ";
	print "button to map it to that group.<br><br>\n";
	print "Computer Group:<select name=compgroups id=compgroups>\n";
	# build list of groups
	$tmp = getUserResources(array('computerAdmin'), array('manageGroup'), 1);
	$groups = $tmp['computer'];
	uasort($groups, 'sortKeepIndex');
	foreach($groups as $id => $group) {
		print "<option value=$id>$group</option>\n";
	}
	print "</select>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"fetchCompsButton\">\n";
	print "	Get Image Groups\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	print "		getMapImgGroupsButton();\n";
	print "	</script>\n";
	print "</button>\n";
	print "<table><tbody><tr>\n";
	# select for image groups comp group maps to
	print "<td valign=top>\n";
	print "Image groups <span style=\"font-weight: bold;\" id=incompgroupname></span> maps to:<br>\n";
	print "<select name=inimggroups multiple id=inimggroups size=20>\n";
	print "</select>\n";
	print "</td>\n";
	# transfer buttons
	print "<td style=\"vertical-align: middle;\">\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"addBtn2\">\n";
	print "  <div style=\"width: 50px;\">&lt;-Add</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJaddImgGrpToCompGrp');
	print "		addRemItem('$cont', 'compgroups', 'outimggroups', addRemImgGrpCompGrp);\n";
	print "	</script>\n";
	print "</button>\n";
	print "<br>\n";
	print "<br>\n";
	print "<br>\n";
	print "<button dojoType=\"dijit.form.Button\" id=\"remBtn2\">\n";
	print "	<div style=\"width: 50px;\">Remove-&gt;</div>\n";
	print "	<script type=\"dojo/method\" event=onClick>\n";
	$cont = addContinuationsEntry('AJremImgGrpFromCompGrp');
	print "		addRemItem('$cont', 'compgroups', 'inimggroups', addRemImgGrpCompGrp);\n";
	print "	</script>\n";
	print "</button>\n";
	print "</td>\n";
	# select for image groups comp group does not map to
	print "<td valign=top>\n";
	print "Images groups <span style=\"font-weight: bold;\" id=outcompgroupname></span> does not map to:<br>\n";
	print "<select name=outimggroups multiple id=outimggroups size=20>\n";
	print "</select>\n";
	print "</td>\n";
	print "</tr><tbody/></table>\n";
	print "</div>\n";

	# grid tab
	$cont = addContinuationsEntry('imageMappingGrid');
	$loadingmsg = "<span class=dijitContentPaneLoading>Loading page (this may take a really long time)</span>";
	print "<a jsId=\"checkboxpane\" dojoType=\"dijit.layout.LinkPane\"\n";
	print "   href=\"index.php?continuation=$cont\"\n";
	print "   loadingMessage=\"$loadingmsg\" $gridSelected>\n";
	print "   Checkbox Grid</a>\n";

	print "</div>\n"; # end of main tab container
	$cont = addContinuationsEntry('jsonImageMapCompGroups');
	print "<input type=hidden id=compcont value=\"$cont\">\n";
	$cont = addContinuationsEntry('jsonImageMapImgGroups');
	print "<input type=hidden id=imgcont value=\"$cont\">\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn imageMappingGrid($imagegroups)
///
/// \param $imagegroups - (optional) array of imagegroups as returned by
/// getUserResources
///
/// \brief prints a page to view and edit image mapping
///
////////////////////////////////////////////////////////////////////////////////
function imageMappingGrid() {
	global $mode;
	$tmp = getUserResources(array("imageAdmin"), 
                           array("manageGroup"), 1);
	$imagegroups = $tmp["image"];
	uasort($imagegroups, "sortKeepIndex");
	$imagecompmapping = getResourceMapping("image", "computer");
	$resources2 = getUserResources(array("computerAdmin"),
	                               array("manageGroup"), 1);
	$compgroups = $resources2["computer"];
	uasort($compgroups, "sortKeepIndex");

	if(! count($imagegroups) || ! count($compgroups)) {
		print "You don't have access to manage any image group to computer group ";
		print "mappings.<br>\n";
		return;
	}

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<TABLE border=1>\n";
	print "  <col>\n";
	foreach(array_keys($compgroups) as $id) {
		print "  <col id=compgrp$id>\n";
	}
	print "  <TR>\n";
	print "    <TH rowspan=2>Image Group</TH>\n";
	print "    <TH class=nohlcol colspan=" . count($compgroups) . ">Computer Groups</TH>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	foreach($compgroups as $id => $group) {
		print "    <TH onclick=\"toggleColSelect('compgrp$id');\">$group</TH>\n";
	}
	print "  </TR>\n";
	$count = 1;
	foreach($imagegroups as $imgid => $imgname) {
		if($count % 12 == 0) {
			print "  <TR>\n";
			print "    <TH><img src=images/blank.gif></TH>\n";
			foreach($compgroups as $id => $group) {
				print "    <TH onclick=\"toggleColSelect('compgrp$id');\">$group</TH>\n";
			}
			print "  </TR>\n";
		}
		print "  <TR id=imggrpid$imgid>\n";
		print "    <TH align=right onclick=\"toggleRowSelect('imggrpid$imgid');\">$imgname</TH>\n";
		foreach($compgroups as $compid => $compname) {
			$name = "mapping[" . $imgid . ":" . $compid . "]";
			if(array_key_exists($imgid, $imagecompmapping) &&
				in_array($compid, $imagecompmapping[$imgid])) {
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
	$cont = addContinuationsEntry('submitImageMapping', array(), SECINWEEK, 1, 0, 1);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=\"Submit Changes\">\n";
	print "<INPUT type=reset value=Reset>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn createSelectImage()
///
/// \brief prints a page to select a base image for new image/image to update
///
////////////////////////////////////////////////////////////////////////////////
function createSelectImage() {
	global $submitErr, $user;
	$timestamp = processInputVar("stamp", ARG_NUMERIC);
	$imageid = processInputVar("imageid", ARG_STRING);
	$length = processInputVar("length", ARG_NUMERIC);
	$day = processInputVar("day", ARG_STRING);
	$hour = processInputVar("hour", ARG_NUMERIC);
	$minute = processInputVar("minute", ARG_NUMERIC);
	$meridian = processInputVar("meridian", ARG_STRING);

	if(! $submitErr) {
		print "<H2>Create / Update an Image</H2>\n";
	}
	$resources = getUserResources(array("imageAdmin"));
	if(empty($resources['image'])) {
		print "You don't have access to any base images from which to create ";
		print "new images.<br>\n";
		return;
	}
	print "Please select the environment you will be updating or using as a ";
	print "base for a new image:<br>\n";

	$OSs = getOSList();

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	// list of images
	uasort($resources["image"], "sortKeepIndex");
	#printSelectInput("imageid", $resources["image"], $imageid, 1);
	printSelectInput("imageid", $resources["image"], $imageid, 1, 0, 'imagesel', "onChange=\"updateWaitTime(1);\" tabIndex=1");
	print "<br><br>\n";

	$imagenotes = getImageNotes($imageid);
	$desc = '';
	if(preg_match('/\w/', $imagenotes['description'])) {
		$desc = preg_replace("/\n/", '<br>', $imagenotes['description']);
		$desc = preg_replace("/\r/", '', $desc);
		$desc = "<strong>Image Description</strong>:<br>\n$desc<br><br>\n";
	}
	print "<div id=imgdesc>$desc</div>\n";

	print "When would you like to start the imaging process?<br><br>\n";
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time id=timenow ";
	print "onclick='updateWaitTime(0);' value=now>Now<br>\n";
	print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time value=future ";
	print "onclick='updateWaitTime(0);' checked>Later:\n";

	#print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time value=now>Now<br>\n";
	#print "&nbsp;&nbsp;&nbsp;<INPUT type=radio name=time value=future checked>Later:\n";
	if($submitErr) {
		$hour24 = $hour;
		if($hour24 == 12) {
			if($meridian == "am") {
				$hour24 = 0;
			}
		}
		elseif($meridian == "pm") {
			$hour24 += 12;
		}
		list($month, $day, $year) = explode('/', $day);
		$stamp = datetimeToUnix("$year-$month-$day $hour24:$minute:00");
		$day = date('l', $stamp);
		printReserveItems(1, $day, $hour, $minute, $meridian, 0, 0, 1);
	}
	elseif(empty($timestamp)) {
		printReserveItems(1, NULL, NULL, NULL, NULL, 0, 0, 1);
	}
	else {
		$timeArr = explode(',', date('l,g,i,a', $timestamp));
		printReserveItems(1, $timeArr[0], $timeArr[1], $timeArr[2], $timeArr[3], 0, 0, 1);
	}

	print "<div id=waittime class=hidden></div><br>\n";

	$cdata = array('length' => 480);
	$cont = addContinuationsEntry('submitCreateImage', $cdata, SECINDAY, 1, 0);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=\"Create Imaging Reservation\">\n";
	print "</FORM>\n";
	$cont = addContinuationsEntry('AJupdateWaitTime');
	print "<INPUT type=hidden name=waitcontinuation id=waitcontinuation value=\"$cont\">\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitCreateImage()
///
/// \brief checks to see if the request can fit in the schedule; adds it if
/// it fits; notifies the user either way
///
////////////////////////////////////////////////////////////////////////////////
function submitCreateImage() {
	global $submitErr, $user, $viewmode, $HTMLheader, $printedHTMLheader, $mode;

	if($mode == 'submitCreateTestProd') {
		$data = getContinuationVar();
		$data["revisionid"] = processInputVar("revisionid", ARG_MULTINUMERIC);
		# TODO check for valid revisionid
	}
	else {
		$data = processRequestInput(0);
		$data['length'] = getContinuationVar('length');
	}

	$showrevisions = 0;
	$subimages = 0;
	$images = getImages();
	$revcount = count($images[$data['imageid']]['imagerevision']);
	if($revcount > 1)
		$showrevisions = 1;
	if($images[$data['imageid']]['imagemetaid'] != NULL &&
	   count($images[$data['imageid']]['subimages'])) {
		$subimages = 1;
		foreach($images[$data['imageid']]['subimages'] as $subimage) {
			$revcount = count($images[$subimage]['imagerevision']);
			if($revcount > 1)
				$showrevisions = 1;
		}
	}

	if($data["time"] == "now") {
		$nowArr = getdate();
		if($nowArr["minutes"] == 0) {
			$subtract = 0;
			$add = 0;
		}
		elseif($nowArr["minutes"] < 15) {
			$subtract = $nowArr["minutes"] * 60;
			$add = 900;
		}
		elseif($nowArr["minutes"] < 30) {
			$subtract = ($nowArr["minutes"] - 15) * 60;
			$add = 900;
		}
		elseif($nowArr["minutes"] < 45) {
			$subtract = ($nowArr["minutes"] - 30) * 60;
			$add = 900;
		}
		elseif($nowArr["minutes"] < 60) {
			$subtract = ($nowArr["minutes"] - 45) * 60;
			$add = 900;
		}
		$start = time() - $subtract;
		$start -= $start % 60;
		$nowfuture = "now";
	}
	else {
		$add = 0;
		$hour = $data["hour"];
		if($data["hour"] == 12) {
			if($data["meridian"] == "am") {
				$hour = 0;
			}
		}
		elseif($data["meridian"] == "pm") {
			$hour = $data["hour"] + 12;
		}

		$tmp = explode('/', $data["day"]);
		$start = mktime($hour, $data["minute"], "0", $tmp[0], $tmp[1], $tmp[2]);
		if($start < time()) {
			print $HTMLheader;
			print "<H2>Create / Update an Image</H2>\n";
			print "<font color=\"#ff0000\">The time you requested is in the past.";
			print " Please select \"Now\" or use a time in the future.</font><br>\n";
			$submitErr = 1;
			createSelectImage();
			return;
		}
		$nowfuture = "future";
	}
	// FIXME hard code length to 8 hours
	$data["length"] = 480;
	$end = $start + $data["length"] * 60 + $add;

	// get semaphore lock
	if(! semLock())
		abort(3);

	$max = getMaxOverlap($user['id']);
	if(checkOverlap($start, $end, $max)) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		print "<H2>New Reservation</H2>\n";
		if($max == 0) {
			print "<font color=\"#ff0000\">The time you requested overlaps with ";
			print "another reservation you currently have.  You are only allowed ";
			print "to have a single reservation at any given time. Please select ";
			print "another time to use the application. If you are finished with ";
			print "an active reservation, click \"Current Reservations\", ";
			print "then click the \"End\" button of your active reservation.";
			print "</font><br><br>\n";
		}
		else {
			print "<font color=\"#ff0000\">The time you requested overlaps with ";
			print "another reservation you currently have.  You are allowed ";
			print "to have $max overlapping reservations at any given time. ";
			print "Please select another time to use the application. If you are ";
			print "finished with an active reservation, click \"Current ";
			print "Reservations\", then click the \"End\" button of your active ";
			print "reservation.</font><br><br>\n";
		}
		$submitErr = 1;
		createSelectImage();
		return;
	}
	// if user is owner of the image and there is a test revision of the image
	#   available, ask user if production or test image desired
	if($mode != "submitCreateTestProd" && $showrevisions &&
	   $images[$data["imageid"]]["ownerid"] == $user["id"]) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		print "<H2>New Reservation</H2>\n";
		if($subimages) {
			print "This is a cluster environment. At least one image in the ";
			print "cluster has more than one revision available. Please select ";
			print "the revision you desire for each image listed below:<br>\n";
		}
		else {
			print "There are multiple revisions of this environment available.  Please ";
			print "select the revision you would like to check out:<br>\n";
		}
		print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post><br>\n";
		if(! array_key_exists('subimages', $images[$data['imageid']]))
			$images[$data['imageid']]['subimages'] = array();
		array_unshift($images[$data['imageid']]['subimages'], $data['imageid']);
		foreach($images[$data['imageid']]['subimages'] as $subimage) {
			print "{$images[$subimage]['prettyname']}:<br>\n";
			print "<table summary=\"lists revisions of the selected environment, one must be selected to continue\">\n";
			print "  <TR>\n";
			print "    <TD></TD>\n";
			print "    <TH>Revision</TH>\n";
			print "    <TH>Creator</TH>\n";
			print "    <TH>Created</TH>\n";
			print "    <TH>Currently in Production</TH>\n";
			print "  </TR>\n";
			foreach($images[$subimage]['imagerevision'] as $revision) {
				print "  <TR>\n";
				if(array_key_exists($subimage, $data['revisionid']) && 
				   $data['revisionid'][$subimage] == $revision['id'])
					print "    <TD align=center><INPUT type=radio name=revisionid[$subimage] value={$revision['id']} checked></TD>\n";
				elseif($revision['production'])
					print "    <TD align=center><INPUT type=radio name=revisionid[$subimage] value={$revision['id']} checked></TD>\n";
				else
					print "    <TD align=center><INPUT type=radio name=revisionid[$subimage] value={$revision['id']}></TD>\n";
				print "    <TD align=center>{$revision['revision']}</TD>\n";
				print "    <TD align=center>{$revision['user']}</TD>\n";
				print "    <TD align=center>{$revision['prettydate']}</TD>\n";
				if($revision['production'])
					print "    <TD align=center>Yes</TD>\n";
				else
					print "    <TD align=center>No</TD>\n";
				print "  </TR>\n";
			}
			print "</TABLE>\n";
		}
		addContinuationsEntry('submitCreateImage', array(), SECINDAY, 1, 0); // we add this continuation back
		                                                                     //   so the currently displayed
		                                                                     //   page can be reloaded
		$cont = addContinuationsEntry('submitCreateTestProd', $data);
		print "<br><INPUT type=hidden name=continuation value=\"$cont\">\n";
		print "<INPUT type=submit value=Submit>\n";
		print "</FORM>\n";
		return;
	}
	$rc = isAvailable($images, $data["imageid"], $start, $end, $data["os"], 0, 0, 0, 1);
	if($rc == -1) {
		$printedHTMLheader = 1;
		print $HTMLheader;
		print "<H2>Create / Update an Image</H2>\n";
		print "You have requested an environment that is limited in the number ";
		print "of concurrent reservations that can be made. No further ";
		print "reservations for the environment can be made for the time you ";
		print "have selected. Please select another time to use the ";
		print "environment.<br>";
	}
	elseif($rc > 0) {
		$requestid = addRequest(1, $data['revisionid']);
		if($data["time"] == "now") {
			header("Location: " . BASEURL . SCRIPT . "?mode=viewRequests");
			dbDisconnect();
			exit;
		}
		else {
			$time = prettyLength($data["length"]);
			if($data["minute"] == 0) {
				$data["minute"] = "00";
			}
			$printedHTMLheader = 1;
			print $HTMLheader;
			print "<H2>Create / Update an Image</H2>\n";
			print "Your request to use <b>" . $images[$data["imageid"]]["prettyname"];
			print "</b> on " . prettyDatetime($start) . " for $time has been ";
			print "accepted.<br><br>\n";
			print "When your reservation time has been reached, the ";
			print "<b>Current Reservations</b> page will give you more ";
			print "information on connecting to the reserved computer. If you ";
			print "would like to modify your reservation, you can do that from ";
			print "the <b>Current Reservations</b> page as well.<br>\n";
		}
	}
	else {
		$printedHTMLheader = 1;
		print $HTMLheader;
		$cdata = array('imageid' => $data['imageid'],
		               'length' => $data['length']);
		$cont = addContinuationsEntry('selectTimeTable', $cdata);
		print "<H2>Create / Update an Image</H2>\n";
		print "The reservation you have requested is not available. You may ";
		print "<a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "view a timetable</a> of free and reserved times to find ";
		print "a time that will work for you.<br>\n";
		#addLogEntry($nowfuture, unixToDatetime($start), 
		#            unixToDatetime($end), 0, $data["imageid"]);
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn startImage()
///
/// \brief prints page prompting user if updating existing image or creating a
/// new image
///
////////////////////////////////////////////////////////////////////////////////
function startImage() {
	global $user;
	$requestid = getContinuationVar("requestid");

	$data = getRequestInfo($requestid);
	$disableUpdate = 1;
	$imageid = '';
	foreach($data["reservations"] as $res) {
		if($res["forcheckout"]) {
			$imageid = $res["imageid"];
			break;
		}
	}
	if(! empty($imageid)) {
		$imageData = getImages(0, $imageid);
		if($imageData[$imageid]['ownerid'] == $user['id'])
			$disableUpdate = 0;
	}
	print "<H2>Create / Update an Image</H2>\n";
	print "Are you creating a new image from a base image or updating an ";
	print "existing image?<br><br>\n";
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('requestid' => $requestid);
	$cont = addContinuationsEntry('newImage', $cdata, SECINDAY, 0);
	print "<INPUT type=radio name=continuation value=\"$cont\" id=newimage checked>";
	print "<label for=newimage>Creating New Image</label><br>\n";
	if($disableUpdate) {
		print "<INPUT type=radio name=continuation value=\"$cont\" ";
		print "id=updateimage disabled><label for=updateimage><font color=gray>";
		print "Update Existing Image</font></label>";
	}
	else {
		$cdata['nextmode'] = 'updateExistingImageComments';
		$cdata['multicall'] = 1;
		$cont = addContinuationsEntry('imageClickThroughAgreement', $cdata, SECINDAY, 0);
		print "<INPUT type=radio name=continuation value=\"$cont\" ";
		print "id=updateimage><label for=updateimage>Update Existing Image";
		print "</label>";
	}
	print "<br><br>\n";
	print "<INPUT type=submit value=Submit>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitImageButton
///
/// \brief wrapper for confirmDeleteImage, editOrAddImage(0), and 
/// viewImageDetails
///
////////////////////////////////////////////////////////////////////////////////
function submitImageButton() {
	$submode = processInputVar("submode", ARG_STRING);
	if($submode == "Edit")
		editOrAddImage(0);
	elseif($submode == "Delete" || $submode == "Undelete")
		confirmDeleteImage();
	elseif($submode == "Details")
		viewImageDetails();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editOrAddImage($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a form for editing an image
///
////////////////////////////////////////////////////////////////////////////////
function editOrAddImage($state) {
	global $submitErr, $mode, $submode, $user;

	$images = getImages();
	$platforms = getPlatforms();
	$oslist = getOSList();
	$groups = getUserGroups(0, $user['affiliationid']);
	$groups = array_reverse($groups, TRUE);
	$groups[0] = array("name" => "Any");
	$groups = array_reverse($groups, TRUE);

	if($submitErr || $state == 1 || $mode == "submitEditImageButtons") {
		$data = processImageInput(0);
		if(get_magic_quotes_gpc()) {
			$data["description"] = stripslashes($data['description']);
			$data["usage"] = stripslashes($data['usage']);
			$data["comments"] = stripslashes($data['comments']);
		}
		$data['imageid'] = getContinuationVar('imageid');
		if($mode == "newImage") {
			$requestdata = getRequestInfo($data['requestid']);
			$imagedata = getImages(0, $requestdata["reservations"][0]["imageid"]);
			$data["platformid"] = $imagedata[$requestdata["reservations"][0]["imageid"]]["platformid"];
			$data["osid"] = $imagedata[$requestdata["reservations"][0]["imageid"]]["osid"];
		}
	}
	elseif($mode == 'submitAddSubimage')
		$data = getContinuationVar();
	else {
		$id = getContinuationVar("imageid");
		$data = $images[$id];
		$data["imageid"] = $id;
		$tmp = getImageNotes($id);
		$data['description'] = $tmp['description'];
		$data['usage'] = $tmp['usage'];
	}

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<DIV align=center>\n";
	if($state)
		print "<H2>Add Image</H2>\n";
	else
		print "<H2>Edit Image</H2>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TH align=right>Name:</TH>\n";
	print "    <TD><INPUT type=text name=prettyname value=\"";
	print $data["prettyname"] . "\" maxlength=60 size=40></TD>\n";
	print "    <TD>";
	printSubmitErr(PRETTYNAMEERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD><INPUT type=text name=owner value=\"" . $data["owner"];
	print "\" size=40></TD>\n";
	print "    <TD>";
	printSubmitErr(IMGOWNERERR);
	print "</TD>\n";
	print "  </TR>\n";
	/*print "  <TR>\n";
	print "    <TH align=right>Platform:</TH>\n";
	print "    <TD>\n";
	printSelectInput("platformid", $platforms, $data["platformid"]);
	print "    </TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>OS:</TH>\n";
	print "    <TD>\n";
	printSelectInput("osid", $oslist, $data["osid"]);
	print "    </TD>\n";
	print "  </TR>\n";*/
	print "  <TR>\n";
	print "    <TD colspan=3>\n";
	print "<fieldset>\n";
	print "<legend>Image Description</legend>\n";
	print "Description of image (required - users will<br>\nsee this on the <strong>";
	print "New Reservations</strong> page):<br>\n";
	printSubmitErr(IMAGEDESCRIPTIONERR);
	print "<textarea dojoType=\"dijit.form.Textarea\" name=description ";
	print "style=\"width: 400px; text-align: left;\">{$data['description']}\n\n";
	print "</textarea>\n";
	print "</fieldset>\n";
	print "<fieldset>\n";
	print "<legend>Usage Notes</legend>\n";
	print "Optional notes to the user explaining how to use the image<br>";
	print "(users will see this on the <strong>Connect!</strong> page):<br>\n";
	print "<textarea dojoType=\"dijit.form.Textarea\" name=usage ";
	print "style=\"width: 400px; text-align: left;\"\">{$data['usage']}\n\n";
	print "</textarea>\n";
	print "</fieldset>\n";
	if($state) {
		print "<fieldset>\n";
		print "<legend>Revision Comments</legend>\n";
		print "Notes for yourself and other admins about how the image ";
		print "was setup/installed.<br>\nThese are optional and not visible to end ";
		print "users.<br>\n";
		print "<textarea dojoType=\"dijit.form.Textarea\" name=comments ";
		print "style=\"width: 400px; text-align: left;\"\">{$data['comments']}\n\n";
		print "</textarea>\n";
		print "</fieldset>\n";
	}
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE><br>\n";
	print "<div dojoType=\"dijit.TitlePane\" title=\"Advanced Options - leave ";
	print "default values unless you really know what you are doing<br>(click to ";
	print "expand)\" open=false style=\"width: 500px\">\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD colspan=3 id=hide1><hr></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD colspan=3 id=hide2><strong>Advanced Options - leave default values unless you really know what you are doing</strong><br><br></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum RAM (MB):</TH>\n";
	print "    <TD><INPUT type=text name=minram value=\"";
	print $data["minram"] . "\" maxlength=5 size=6></TD>\n";
	print "    <TD>";
	printSubmitErr(MINRAMERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Num of Processors:</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("1" => "1", "2" => "2", "4" => "4", "8" => "8");
	printSelectInput("minprocnumber", $tmpArr, $data["minprocnumber"]);
	print "    </TD>\n";
	print "    <TD></TD>";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Processor Speed (MHz):</TH>\n";
	print "    <TD><INPUT type=text name=minprocspeed value=\"";
	print $data["minprocspeed"] . "\" maxlength=5 size=5></TD>\n";
	print "    <TD>";
	printSubmitErr(MINPROCSPEEDERR);
	print "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Network Speed (Mbps):</TH>\n";
	print "    <TD>\n";
	$tmpArr = array("10" => "10", "100" => "100", "1000" => "1000");
	printSelectInput("minnetwork", $tmpArr, $data["minnetwork"]);
	print "    </TD>\n";
	print "    <TD></TD>";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Maximum Concurrent Usage:</TH>\n";
	print "    <TD><INPUT type=text name=maxconcurrent value=\"";
	print $data["maxconcurrent"] . "\" maxlength=3 size=4>(leave empty for unlimited)</TD>\n";
	print "    <TD>";
	printSubmitErr(MAXCONCURRENTERR);
	print "</TD>\n";
	print "    <TD></TD>";
	print "  </TR>\n";
	if(! $state) {
		print "  <TR>\n";
		print "    <TH align=right>Estimated Reload Time (min):</TH>\n";
		print "    <TD><INPUT type=text name=reloadtime value=\"";
		print $data["reloadtime"] . "\" maxlength=3></TD>\n";
		print "    <TD>";
		printSubmitErr(RELOADTIMEERR);
		print "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Available for checkout:</TH>\n";
	print "    <TD>\n";
	$yesno = array(1 => "Yes", 0 => "No");
	printSelectInput("forcheckout", $yesno, $data["forcheckout"]);
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Check for logged in user:</TH>\n";
	if(array_key_exists("checkuser", $data) && ! $data["checkuser"])
	   $default = 0;
	else
		$default = 1;
	print "    <TD>\n";
	printSelectInput("checkuser", $yesno, $default);
	print "    </TD>\n";
	print "  </TR>\n";
	# finally just limited access so only high level access people see this
	# because it confused too many people
	if($user["adminlevel"] == "developer") {
		print "  <TR>\n";
		print "    <TH align=right>User group allowed to log in:<br>\n";
		print "    <small>(This does not grant permission to<br>\n";
		print "make a reservation for the image)</small></TH>\n";
		print "    <TD>\n";
		if(! empty($data["usergroupid"])) {
			$default = $data["usergroupid"];
			if(! array_key_exists($default, $groups)) {
				if($submitErr || $mode == 'submitEditImageButtons' || $mode == 'submitAddSubimage')
					$groups[$data['usergroupid']] = array('name' => $images[$data['imageid']]['usergroup']);
				else
					$groups[$data['usergroupid']] = array('name' => $data['usergroup']);
				uasort($groups, 'sortKeepIndex');
			}
		}
		else
			$default = 0;
		printSelectInput("usergroupid", $groups, $default);
		print "    </TD>\n";
		print "  </TR>\n";
	}
	if(! $state) {
		print "  <TR>\n";
		print "    <TH style=\"vertical-align:top; text-align:right;\">Subimages:</TH>\n";
		print "    <TD>\n";
		if(array_key_exists("subimages", $images[$data["imageid"]]) &&
			count($images[$data["imageid"]]["subimages"])) {
			foreach($images[$data["imageid"]]["subimages"] as $imgid) {
				print "<INPUT type=checkbox name=\"removeimgid[$imgid]\" value=$imgid>\n";
				print "{$images[$imgid]["prettyname"]}<br>\n";
			}
			print "<INPUT type=submit name=submode value=\"Remove Selected\"><br>\n"; # Remove Selected
		}
		print "    <INPUT type=submit name=submode value=\"Add Subimage\">\n"; # Add Subimage
		print "    </TD>\n";
		print "  </TR>\n";
	}
	else {
		if(array_key_exists("sysprep", $data) && ! $data["sysprep"])
			$default = 0;
		else
			$default = 1;
		print "  <TR>\n";
		print "    <TH style=\"vertical-align:top; text-align:right;\">Use sysprep:</TH>\n";
		print "    <TD>\n";
		printSelectInput("sysprep", $yesno, $default);
		print "    </TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TD colspan=3 id=hide3><hr></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "</div>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	if($state) {
		$cdata = array('requestid' => $data['requestid'],
		               'imageid' => $data['imageid']);
		$cont = addContinuationsEntry('submitEditImageButtons', $cdata, SECINDAY, 0);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n"; # confirmAddImage
		print "      <INPUT type=submit name=submode value=\"Confirm Image\">\n";
	}
	else {
		$cdata = array('imageid' => $data['imageid']);
		$cont = addContinuationsEntry('submitEditImageButtons', $cdata, SECINDAY, 0, 1, 1);
		print "      <INPUT type=hidden name=continuation value=\"$cont\">\n"; # confirmEditImage
		print "      <INPUT type=submit name=submode value=\"Confirm Changes\">\n";
	}
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	if($state)
		$cont = addContinuationsEntry('viewRequests');
	else
		$cont = addContinuationsEntry('viewImages');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";

	if($state)
		return;
	print "<div id=revisiondiv>\n";
	print getRevisionHTML($data['imageid']);
	print "</div>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getRevisionHTML($imageid)
///
/// \param $imageid - id of an image
///
/// \return string of HTML data
///
/// \brief builds HTML table for in place editing of image revision data
///
////////////////////////////////////////////////////////////////////////////////
function getRevisionHTML($imageid) {
	$rt = '';
	$rt .= "<h3>Revisions of this Image</h3>\n";
	$rt .= "<table summary=\"\"><tr><td>\n";
	$rt .= "<table summary=\"\" id=\"revisiontable\">\n";
	$rt .= "  <tr>\n";
	$rt .= "    <td></td>\n";
	$rt .= "    <th>Revision</th>\n";
	$rt .= "    <th>Creator</th>\n";
	$rt .= "    <th>Created</th>\n";
	$rt .= "    <th nowrap>In Production</th>\n";
	$rt .= "    <th>Comments (click to edit)</th>\n";
	$rt .= "  </tr>\n";
	$revisions = getImageRevisions($imageid);
	foreach($revisions AS $rev) {
		$rt .= "  <tr>\n";
		$rt .= "    <td><INPUT type=checkbox\n";
		$rt .= "              id=chkrev{$rev['id']}\n";
		$rt .= "              name=chkrev[{$rev['id']}]\n";
		$rt .= "              value=1></td>\n";
		$rt .= "    <td align=center>{$rev['revision']}</td>\n";
		$rt .= "    <td>{$rev['creator']}</td>\n";
		$created = date('g:ia n/j/Y', datetimeToUnix($rev['datecreated']));
		$rt .= "    <td>$created</td>\n";
		$cdata = array('imageid' => $imageid, 'revisionid' => $rev['id']);
		$cont = addContinuationsEntry('AJupdateRevisionProduction', $cdata);
		if($rev['production']) {
			$rt .= "    <td align=center><INPUT type=radio\n";
			$rt .= "           name=production\n";
			$rt .= "           value={$rev['id']}\n";
			$rt .= "           id=radrev{$rev['id']}\n";
			$rt .= "           onclick=\"updateRevisionProduction('$cont');\"\n";
			$rt .= "           checked></td>\n";
		}
		else {
			$rt .= "    <td align=center><INPUT type=radio\n";
			$rt .= "           name=production\n";
			$rt .= "           value={$rev['id']}\n";
			$rt .= "           id=radrev{$rev['id']}\n";
			$rt .= "           onclick=\"updateRevisionProduction('$cont');\">\n";
			$rt .= "           </td>\n";
		}
		$cdata = array('imageid' => $imageid, 'revisionid' => $rev['id']);
		$cont = addContinuationsEntry('AJupdateRevisionComments', $cdata);
		$rt .= "    <td width=200px><span id=comments{$rev['id']} \n";
		$rt .= "              dojoType=\"dijit.InlineEditBox\"\n";
		$rt .= "              editor=\"dijit.form.Textarea\"\n";
		$rt .= "              onChange=\"updateRevisionComments('comments{$rev['id']}', '$cont');\"\n";
		$rt .= "              noValueIndicator=\"(empty)\">\n";
		$rt .= "        {$rev['comments']}</span></td>\n";
		$rt .= "  </tr>\n";
	}
	$rt .= "</table>\n";
	$rt .= "<div align=left>\n";
	$keys = array_keys($revisions);
	$cdata = array('revids' => $keys, 'imageid' => $imageid);
	$cont = addContinuationsEntry('AJdeleteRevisions', $cdata);
	$ids = implode(',', $keys);
	$rt .= "<button onclick=\"deleteRevisions('$cont', '$ids'); return false;\">Delete selected revisions</button>\n";
	$rt .= "</div>\n";
	$rt .= "</td></tr></table>\n";
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditImageButtons()
///
/// \brief wrapper for confirmEditOrAddImage, addSubimage, and removeSubimages
///
////////////////////////////////////////////////////////////////////////////////
function submitEditImageButtons() {
	$submode = processInputVar("submode", ARG_STRING);
	if($submode == "Confirm Image") # confirmAddImage
		confirmEditOrAddImage(1);
	elseif($submode == "Confirm Changes") # confirmEditImage
		confirmEditOrAddImage(0);
	elseif($submode == "Remove Selected")
		removeSubImages();
	elseif($submode == "Add Subimage")
		printAddSubimage();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmEditOrAddImage($state)
///
/// \param $state - 0 for edit, 1 for add
///
/// \brief prints a form for confirming changes to an image
///
////////////////////////////////////////////////////////////////////////////////
function confirmEditOrAddImage($state) {
	global $submitErr, $user;

	$data = processImageInput(1);

	if($submitErr) {
		editOrAddImage($state);
		return;
	}

	if(get_magic_quotes_gpc()) {
		$data['description'] = stripslashes($data['description']);
		$data['usage'] = stripslashes($data['usage']);
		$data['comments'] = stripslashes($data['comments']);
	}

	$groups = getUserGroups();
	$groups[0] = array("name" => "Any");
	if(! $state)
		$images = getImages();

	if($state) {
		$nextmode = "imageClickThroughAgreement";
		$title = "Add Image";
		$question = "Add the following image?";
	}
	else {
		$nextmode = "submitEditImage";
		$title = "Edit Image";
		$question = "Submit changes to the image?";
	}

	$platforms = getPlatforms();
	$oslist = getOSList();

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<DIV align=center>\n";
	print "<H2>$title</H2>\n";
	print "$question<br><br>\n";
	print "<TABLE>\n";
	if(! $state) {
		/*print "  <TR>\n";
		print "    <TH align=right>Short Name:</TH>\n";
		print "    <TD>" . $data["name"] . "</TD>\n";
		print "  </TR>\n";*/
	}
	print "  <TR>\n";
	print "    <TH align=right>Name:</TH>\n";
	print "    <TD>" . $data["prettyname"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>" . $data["owner"] . "</TD>\n";
	print "  </TR>\n";
	/*print "  <TR>\n";
	print "    <TH align=right>Platform:</TH>\n";
	print "    <TD>" . $platforms[$data["platformid"]] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>OS:</TH>\n";
	print "    <TD>" . $oslist[$data["osid"]]["prettyname"] . "</TD>\n";
	print "  </TR>\n";*/
	print "  <TR>\n";
	print "    <TD colspan=2>\n";
	print "<br><strong>Image Description</strong>:<br>\n";
	print "{$data['description']}<br><br>\n";
	print "<strong>Usage Notes</strong>:<br>\n";
	print "{$data['usage']}<br><br>\n";
	if($state) {
		print "<strong>Revision Comments</strong>:<br>\n";
		print "{$data['comments']}<br><br>\n";
	}
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD colspan=2><strong>Advanced Options</strong>:</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TD colspan=2><hr></TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum RAM (MB):</TH>\n";
	print "    <TD>" . $data["minram"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Num of Processors:</TH>\n";
	print "    <TD>" . $data["minprocnumber"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Processor Speed (MHz):</TH>\n";
	print "    <TD>" . $data["minprocspeed"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Network Speed (Mbps):</TH>\n";
	print "    <TD>" . $data["minnetwork"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Maximum Concurrent Usage:</TH>\n";
	if($data['maxconcurrent'] == '')
		print "    <TD>N/A</TD>\n";
	else
		print "    <TD>" . $data["maxconcurrent"] . "</TD>\n";
	print "  </TR>\n";
	if(! $state) {
		print "  <TR>\n";
		print "    <TH align=right>Estimated Reload Time (min):</TH>\n";
		print "    <TD>" . $data["reloadtime"] . "</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TH align=right>Available for checkout:</TH>\n";
	if($data["forcheckout"])
		print "    <TD>Yes</TD>\n";
	else
		print "    <TD>No</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Check for logged in user:</TH>\n";
	if($data["checkuser"])
		print "    <TD>Yes</TD>\n";
	else
		print "    <TD>No</TD>\n";
	print "  </TR>\n";
	if($user["adminlevel"] == "developer" || $user['adminlevel'] == 'full') {
		print "  <TR>\n";
		print "    <TH align=right>User group allowed to log in:</TH>\n";
		$tmp = explode('@', $groups[$data["usergroupid"]]["name"]);
		if(array_key_exists(1, $tmp) && $tmp[1] != $user['affiliation'])
			print "    <TD>" . $groups[$data["usergroupid"]]["name"] . "</TD>\n";
		else
			print "    <TD>{$tmp[0]}</TD>\n";
		print "  </TR>\n";
	}
	if(! $state) {
		print "  <TR>\n";
		print "    <TH style=\"vertical-align:top; text-align:right;\">Subimages:</TH>\n";
		print "    <TD>\n";
		if(array_key_exists("subimages", $images[$data["imageid"]]) &&
			count($images[$data["imageid"]]["subimages"])) {
			foreach($images[$data["imageid"]]["subimages"] as $imgid) {
				print "{$images[$imgid]["prettyname"]}<br>\n";
			}
		}
		else
			print "None";
		print "    </TD>\n";
		print "  </TR>\n";
	}
	else {
		print "  <TR>\n";
		print "    <TH align=right>Use sysprep:</TH>\n";
		if($data["sysprep"])
			print "    <TD>Yes</TD>\n";
		else
			print "    <TD>No</TD>\n";
		print "  </TR>\n";
	}
	print "  <TR>\n";
	print "    <TD colspan=2><hr></TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	$data['description'] = mysql_escape_string($data['description']);
	$data['usage'] = mysql_escape_string($data['usage']);
	$data['comments'] = mysql_escape_string($data['comments']);

	if($state) {
		$data['nextmode'] = 'submitAddImage';
		$cont = addContinuationsEntry($nextmode, $data, SECINDAY, 0);
	}
	else
		$cont = addContinuationsEntry($nextmode, $data, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	if($state)
		print "      <INPUT type=submit value=\"Add Image\">\n";
	else
		print "      <INPUT type=submit value=\"Submit Changes\">\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	if($state)
		$cont = addContinuationsEntry('viewRequests');
	else
		$cont = addContinuationsEntry('viewImages');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditImage()
///
/// \brief submits changes to image and notifies user
///
////////////////////////////////////////////////////////////////////////////////
function submitEditImage() {
	$data = getContinuationVar();
	updateImage($data);
	viewImages();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn imageClickThrough()
///
/// \brief prints a page with the software license agreement
///
////////////////////////////////////////////////////////////////////////////////
function imageClickThrough() {
	global $clickThroughText;
	printf($clickThroughText, "");
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn imageClickThroughAgreement()
///
/// \brief prints a page where the user must agree to the software licensing
/// agreement before actually creating the new image
///
////////////////////////////////////////////////////////////////////////////////
function imageClickThroughAgreement() {
	global $clickThroughText;
	$data = getContinuationVar();
	$nextmode = $data['nextmode'];
	$multicall = getContinuationVar('multicall', 0);
	unset($data['nextmode']);
	$data['fromAgreement'] = 1;
	$buttons  = "<center>\n";
	$buttons .= "<table summary=\"\">\n";
	$buttons .= "  <tr>\n";
	$buttons .= "    <td>\n";
	$buttons .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry($nextmode, $data, SECINDAY, 0, $multicall);
	$buttons .= "      <input type=hidden name=continuation value=\"$cont\">\n";
	$buttons .= "      <input type=submit value=\"I agree\">\n";
	$buttons .= "      </FORM>\n";
	$buttons .= "    </td>\n";
	$buttons .= "    <td>\n";
	$buttons .= "      <img src=\"images/blank.gif\" alt=\"\" width=30px>\n";
	$buttons .= "    </td>\n";
	$buttons .= "    <td>\n";
	$buttons .= "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewRequests');
	$buttons .= "      <input type=hidden name=continuation value=\"$cont\">\n";
	$buttons .= "      <input type=submit value=\"I do not agree\">\n";
	$buttons .= "      </FORM>\n";
	$buttons .= "    </td>\n";
	$buttons .= "  </tr>\n";
	$buttons .= "  <tr>\n";
	$buttons .= "    <td colspan=3>\n";
	$buttons .= "      Clicking <b>I agree</b> will start the imaging process.\n";
	$buttons .= "    </td>\n";
	$buttons .= "  </tr>\n";
	$buttons .= "</table>\n";
	$buttons .= "</center>\n";
	printf($clickThroughText, "$buttons");
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddImage()
///
/// \brief adds the image and notifies user
///
////////////////////////////////////////////////////////////////////////////////
function submitAddImage() {
	global $user, $clickThroughText;
	$data = getContinuationVar();

	// get platformid and osid
	$requestdata = getRequestInfo($data['requestid']);
	$imagedata = getImages(0, $requestdata["reservations"][0]["imageid"]);
	$data["platformid"] = $imagedata[$requestdata["reservations"][0]["imageid"]]["platformid"];
	$data["osid"] = $imagedata[$requestdata["reservations"][0]["imageid"]]["osid"];
	$data["basedoffrevisionid"] = $requestdata["reservations"][0]["imagerevisionid"];

	// add estimated reload time
	$data["reloadtime"] = 20;

	// FIXME check for existance of image again
	if(! $imageid = addImage($data))
		abort(10);

	// change imageid in request and reservation table and set state to image(16)
	# FIXME will need to figure out which reservation to update for multi-image
	# requests

	// get imagerevisionid
	$query = "SELECT id "
	       . "FROM imagerevision "
	       . "WHERE imageid = $imageid";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	$imagerevisionid = $row['id'];

	$requestid = $data["requestid"];
	$query = "UPDATE request rq, "
	       .        "reservation rs "
	       . "SET rs.imageid = $imageid, "
	       .     "rs.imagerevisionid = $imagerevisionid, "
	       .     "rq.stateid = 16,"
	       .     "rq.forimaging = 1 "
	       . "WHERE rq.id = $requestid AND "
	       .       "rq.id = rs.requestid";
	doQuery($query, 101);

	if(array_key_exists('fromAgreement', $data) && $data['fromAgreement']) {
		$agreement = sprintf($clickThroughText, "");
		$query = "INSERT INTO clickThroughs "
		       .        "(userid, "
		       .        "imageid, "
		       .        "imagerevisionid, "
		       .        "accepted, "
		       .        "agreement) "
		       . "VALUES "
		       .        "({$user['id']}, "
		       .        "$imageid, "
		       .        "$imagerevisionid, "
		       .        "NOW(), "
		       .        "'$agreement')";
		doQuery($query, 101);
	}

	print "<H2>Add Image</H2>\n";
	print "The image creation process has been started.  It normally takes ";
	print "about 25 minutes to complete (though can sometimes be more than ";
	print "two hours).  You will be notified by email ";
	print "when the image has been created.  At that point, you will be able ";
	print "to make a new reservation for the image.  Once you have done so ";
	print "and tested that it works as expected, you can add it to an image ";
	print "group on the <a href=\"" . BASEURL . SCRIPT;
	print "?mode=viewImageOptions\">Manage Images</a> page if you have ";
	print "sufficient access or have your computing support add it for you.<br>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn removeSubImages()
///
/// \brief removes submitted subimages and calls editOrAddImage
///
////////////////////////////////////////////////////////////////////////////////
function removeSubImages() {
	$removeimgids = processInputVar("removeimgid", ARG_MULTINUMERIC);
	$imageid = getContinuationVar("imageid");
	$data = getImages(0, $imageid);
	if(count($removeimgids)) {
		# remove selected images
		$rmids = implode(',', $removeimgids);
		$query = "DELETE FROM subimages "
		       . "WHERE imagemetaid = {$data[$imageid]["imagemetaid"]} AND "
		       .       "imageid IN ($rmids)";
		doQuery($query, 101);

		# check to see if any subimages left; if not, set subimages to 0
		$query = "SELECT COUNT(imageid) "
		       . "FROM subimages "
		       . "WHERE imagemetaid = {$data[$imageid]["imagemetaid"]}";
		$qh = doQuery($query, 101);
		$row = mysql_fetch_row($qh);
		if($row[0] == 0) {
			$query = "UPDATE imagemeta "
			       . "SET subimages = 0 "
			       . "WHERE id = {$data[$imageid]["imagemetaid"]}";
			doQuery($query, 101);
		}
	}

	editOrAddImage(0);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn printAddSubimage()
///
/// \brief prints a page to add a subimage to an image
///
////////////////////////////////////////////////////////////////////////////////
function printAddSubimage() {
	# FIXME need to pass on form data so if something is changed in the edit
	# page, it remains changed when we get back there
	$imageid = getContinuationVar("imageid");
	$images = getImages();
	$data = processImageInput(0);
	print "<H2>Add Subimage</H2>\n";
	if(array_key_exists("subimages", $images[$imageid]) &&
	   count($images[$imageid]["subimages"])) {
		print "Current subimages for <strong>{$images[$imageid]["prettyname"]}:";
		print "</strong><br><br>\n";
		foreach($images[$imageid]["subimages"] as $imgid) {
			print "<img src=images/blank.gif width=25 height=1>\n";
			print "{$images[$imgid]["prettyname"]}<br>\n";
		}
		print "<br>Add additional subimage:<br><br>\n";
	}
	else {
		print "There are currently no subimages for <strong>";
		print "{$images[$imageid]["prettyname"]}</strong>.<br><br>";
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	printSelectInput("addimageid", $images, -1, 1);
	$cdata = $data;
	$cdata['imageid'] = $imageid;
	$cont = addContinuationsEntry('submitAddSubimage', $cdata, SECINDAY, 0, 1, 1);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<br><INPUT type=submit value=Add>\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitAddSubimage()
///
/// \brief adds a subimage to submitted image and calls editOrAddImage
///
////////////////////////////////////////////////////////////////////////////////
function submitAddSubimage() {
	$imageid = getContinuationVar("imageid");
	$addimageid = processInputVar("addimageid", ARG_NUMERIC);
	$data = getImages(0, $imageid);
	if(empty($data[$imageid]["imagemetaid"])) {
		$query = "INSERT INTO imagemeta "
		       .        "(subimages) "
		       . "VALUES (1)";
		doQuery($query, 101);
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM imagemeta", 101);
		if(! $row = mysql_fetch_row($qh))
			abort(101);
		$imagemetaid = $row[0];
		$query = "UPDATE image "
		       . "SET imagemetaid = $imagemetaid "
		       . "WHERE id = $imageid";
		doQuery($query, 101);
	}
	else {
		$imagemetaid = $data[$imageid]["imagemetaid"];
		if(! count($data[$imageid]["subimages"])) {
			$query = "UPDATE imagemeta "
			       . "SET subimages = 1 "
			       . "WHERE id = $imagemetaid";
			doQuery($query, 101);
		}
	}
	$query = "INSERT INTO subimages "
	       .        "(imagemetaid, "
	       .        "imageid) "
	       . "VALUES ($imagemetaid, "
	       .        "$addimageid)";
	doQuery($query, 101);
	editOrAddImage(0);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateExistingImageComments()
///
/// \brief prints a page for getting install comments about the revision before
/// continuing on to actually creating the revision
///
////////////////////////////////////////////////////////////////////////////////
function updateExistingImageComments() {
	$cdata = getContinuationVar();
	$data = getRequestInfo($cdata['requestid']);
	foreach($data["reservations"] as $res) {
		if($res["forcheckout"]) {
			$imageid = $res["imageid"];
			$revisionid = $res['imagerevisionid'];
			break;
		}
	}
	$revisions = getImageRevisions($imageid);
	print "<H2>Update Existing Image</H2>\n";
	print "<h3>New Revision Comments</h3>\n";
	print "Enter any notes for yourself and other admins about how the image ";
	print "was setup/installed.<br>\nThese are optional and not visible to end ";
	print "users:<br>\n";
	print "<form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<textarea dojoType=\"dijit.form.Textarea\" name=comments ";
	print "style=\"width: 400px; text-align: left;\"\">\n\n</textarea>\n";
	print "<h3>Previous Revision Comments</h3>\n";
	if(preg_match('/\w/', $revisions[$revisionid]['comments'])) {
		print "These are the comments from the previous revision ";
		print "({$revisions[$revisionid]['revision']}):<br>\n";
		print "{$revisions[$revisionid]['comments']}<br><br>\n";
	}
	else
		print "The previous revision did not have any comments.<br>\n";
	print "<table summary=\"\">\n";
	print "  <tr>\n";
	print "    <td>\n";
	$cont = addContinuationsEntry('updateExistingImage', $cdata, SECINDAY, 0, 0);
	print "      <input type=hidden name=continuation value=\"$cont\">\n";
	print "      <input type=submit value=\"Create New Revision\">\n";
	print "      </form>\n";
	print "    </td>\n";
	print "    <td>\n";
	print "      <form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewRequests');
	print "      <input type=hidden name=continuation value=\"$cont\">\n";
	print "      <input type=submit value=\"Cancel\">\n";
	print "      </form>\n";
	print "    </td>\n";
	print "  </tr>\n";
	print "</table>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateExistingImage()
///
/// \brief sets test flag on image to 1, sets state of request to 'image' and
/// notifies the user that the imaging process has started
///
////////////////////////////////////////////////////////////////////////////////
function updateExistingImage() {
	global $user, $clickThroughText;
	$requestid = getContinuationVar("requestid");
	$fromAgreement = getContinuationVar('fromAgreement', 0);
	$comments = processInputVar("comments", ARG_STRING);
	$comments = preg_replace("/\r/", '', $comments);
	$comments = htmlspecialchars($comments);
	#$comments = preg_replace("/\n/", '<br>', $comments);
	$comments = preg_replace("/\n/", '', $comments);
	if(get_magic_quotes_gpc())
		$comments = stripslashes($comments);
	$comments = mysql_escape_string($comments);

	$data = getRequestInfo($requestid);
	foreach($data["reservations"] as $res) {
		if($res["forcheckout"]) {
			$imageid = $res["imageid"];
			break;
		}
	}
	$imageData = getImages(0, $imageid);
	if($imageData[$imageid]['ownerid'] != $user['id']) {
		editOrAddImage(1);
		return;
	}
	// set the test flag on the image in the image table
	$query = "UPDATE image SET test = 1 WHERE id = $imageid";
	doQuery($query, 101);

	# add entry to imagerevision table
	$query = "SELECT revision, "
	       .        "imagename "
	       . "FROM imagerevision "
	       . "WHERE imageid = $imageid "
	       . "ORDER BY revision DESC "
	       . "LIMIT 1";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	$newrevision = $row['revision'] + 1;
	$newname = preg_replace("/{$row['revision']}$/",
	                        $newrevision, $row['imagename']);
	$query = "INSERT INTO imagerevision "
	       .        "(imageid, "
	       .        "revision, "
	       .        "userid, "
	       .        "datecreated, "
	       .        "deleted, "
	       .        "production, "
	       .        "comments, "
	       .        "imagename) "
	       . "VALUES ($imageid, "
	       .        "$newrevision, "
	       .        "{$user['id']}, "
	       .        "NOW(), "
	       .        "1, "
	       .        "0, "
	       .        "'$comments', "
	       .        "'$newname')";
	doQuery($query, 101);
	$qh = doQuery("SELECT LAST_INSERT_ID() FROM imagerevision", 101);
	$row = mysql_fetch_row($qh);
	$imagerevisionid = $row[0];

	# update request and reservation
	$query = "UPDATE request rq, "
	       .        "reservation rs "
	       . "SET rs.imagerevisionid = $imagerevisionid, "
	       .     "rq.stateid = 16,"
	       .     "rq.forimaging = 1 "
	       . "WHERE rq.id = $requestid AND "
	       .       "rq.id = rs.requestid AND "
	       .       "rs.imageid = $imageid";
	doQuery($query, 101);

	if($fromAgreement) {
		$agreement = strip_tags(sprintf($clickThroughText, ""));
		$query = "INSERT INTO clickThroughs "
		       .        "(userid, "
		       .        "imageid, "
		       .        "accepted, "
		       .        "agreement) "
		       . "VALUES "
		       .        "({$user['id']}, "
		       .        "$imageid, "
		       .        "NOW(), "
		       .        "'$agreement')";
		doQuery($query, 101);
	}

	print "<H2>Update Image</H2>\n";
	print "The image creation process has been started.  It normally takes ";
	print "about 20-25 minutes to complete.  You will be notified by email ";
	print "when the image has been created.  Afterward, there are a few steps ";
	print "you need to follow to make it the production revision of the image:";
	print "<ol class=numbers>\n";
	print "<li>Make a new reservation for the environment (it will have the ";
	print "same name in the drop-down list).</li>\n";
	print "<li>After clicking <strong>Submit</strong> on the New Reservations ";
	print "page, you will be prompted to select the revision of the environment ";
	print "you want</li>\n";
	print "<li>Select the most recent revision and click <strong>Submit</strong>";
	print "</li>\n";
	print "<li>Test the environment to make sure it works correctly</li>\n";
	print "<li>After you are satisfied that it works correctly, click the ";
	print "<strong>End</strong> button on the Current Reservations page</li>\n";
	print "<li>You will be prompted to make the revision production or just end ";
	print "the reservation</li>\n";
	print "<li>Select the <strong>Make this the production revision</strong> ";
	print "radio button</li> and click <strong>Submit</strong></li>\n";
	print "</ol>\n";
	print "Once the revision is made production, everyone that selects it will ";
	print "get the new revision<br>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn setImageProduction()
///
/// \brief prompts user if really ready to set image to production
///
////////////////////////////////////////////////////////////////////////////////
function setImageProduction() {
	$requestid = getContinuationVar('requestid');
	$data = getRequestInfo($requestid);
	foreach($data["reservations"] as $res) {
		if($res["forcheckout"]) {
			$prettyimage = $res["prettyimage"];
			break;
		}
	}
	print "<H2>Change Test Image to Production</H2>\n";
	print "This will update the <b>$prettyimage</b> ";
	print "environment to be the newly created revision so that people will ";
	print "start getting it when they checkout the environment.  It will also ";
	print "cause all the blades that currently have this image preloaded to be ";
	print "reloaded with this new image.  Are you sure the image works ";
	print "correctly?<br>\n";
	print "<TABLE>\n";
	print "  <TR>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('requestid' => $requestid);
	$cont = addContinuationsEntry('submitSetImageProduction', $cdata, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Yes>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewRequests');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=No>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitSetImageProduction()
///
/// \brief sets request state to 'makeproduction', notifies user that 
/// "productioning" process has started
///
////////////////////////////////////////////////////////////////////////////////
function submitSetImageProduction() {
	$requestid = getContinuationVar('requestid');
	$data = getRequestInfo($requestid);
	foreach($data["reservations"] as $res) {
		if($res["forcheckout"]) {
			$prettyimage = $res["prettyimage"];
			break;
		}
	}
	/*$regs = array();
	if(ereg('(.*)-v([0-9]){1,2}$', $data["image"], $regs)) {
		$newname = $regs[1] . "-v" . ++$regs[2];
		print "newname - $newname<br>\n";
	}
	else {
		$newname = $data["image"] . "-v0";
	}
	$query = "UPDATE image "
	       . "SET name = '$newname', "
	       .     "test = 0 "
	       . "WHERE id = " . $data["imageid"];*/
	$query = "UPDATE request SET stateid = 17 WHERE id = $requestid";
	doQuery($query, 101);
	//deleteRequest($data);
	print "<H2>Change Test Image to Production</H2>\n";
	print "<b>$prettyimage</b> is in the process of being ";
	print "updated to use the newly created image.<br>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteImage()
///
/// \brief prints a form to confirm the deletion of an image
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteImage() {
	$imageid = getContinuationVar("imageid");
	$images = getImages(1);
	if($images[$imageid]["deleted"] == 0) {
		$deleted = 0;
		$title = "Delete Image";
		$question = "Delete the following image?";
	}
	else {
		$deleted = 1;
		$title = "Undelete Image";
		$question = "Undelete the following image?";
	}

	if(! $deleted && checkForImageUsage($imageid)) {
		print "<H2 align=center>Delete Image</H2>\n";
		print "The image you selected is currently in use. You cannot delete ";
		print "the image until it is no longer being used.<br>\n";
		return;
	}

	$platforms = getPlatforms();
	$oslist = getOSList();

	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<DIV align=center>\n";
	print "<H2>$title</H2>\n";
	print "$question<br><br>\n";
	print "<TABLE>\n";
	/*print "  <TR>\n";
	print "    <TH align=right>Short Name:</TH>\n";
	print "    <TD>" . $images[$imageid]["name"] . "</TD>\n";
	print "  </TR>\n";*/
	print "  <TR>\n";
	print "    <TH align=right>Long Name:</TH>\n";
	print "    <TD>" . $images[$imageid]["prettyname"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>" . $images[$imageid]["owner"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Platform:</TH>\n";
	print "    <TD>" . $platforms[$images[$imageid]["platformid"]] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>OS:</TH>\n";
	print "    <TD>" . $oslist[$images[$imageid]["osid"]]["prettyname"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum RAM (MB):</TH>\n";
	print "    <TD>" . $images[$imageid]["minram"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Num of Processors:</TH>\n";
	print "    <TD>" . $images[$imageid]["minprocnumber"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Processor Speed (MHz):</TH>\n";
	print "    <TD>" . $images[$imageid]["minprocspeed"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Network Speed (Mbps):</TH>\n";
	print "    <TD>" . $images[$imageid]["minnetwork"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Estimated Reload Time (min):</TH>\n";
	print "    <TD>" . $images[$imageid]["reloadtime"] . "</TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
	print "<TABLE>\n";
	print "  <TR valign=top>\n";
	print "    <TD>\n";
	$cdata = array('deleted' => $deleted,
	               'imageid' => $imageid);
	$cont = addContinuationsEntry('submitDeleteImage', $cdata, SECINDAY, 0, 0);
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Submit>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "    <TD>\n";
	print "      <FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewImages');
	print "      <INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "      <INPUT type=submit value=Cancel>\n";
	print "      </FORM>\n";
	print "    </TD>\n";
	print "  </TR>\n";
	print "</TABLE>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteImage()
///
/// \brief deletes an image from the database and notifies the user
///
////////////////////////////////////////////////////////////////////////////////
function submitDeleteImage() {
	$imageid = getContinuationVar("imageid");
	$deleted = getContinuationVar("deleted");
	if($deleted) {
		$query = "UPDATE image "
				 . "SET deleted = 0 "
				 . "WHERE id = $imageid";
		$qh = doQuery($query, 210);
	}
	else {
		$query = "UPDATE image "
				 . "SET deleted = 1 "
				 . "WHERE id = $imageid";
		$qh = doQuery($query, 211);
		$query = "UPDATE computer "
				 . "SET nextimageid = 0 "
				 . "WHERE nextimageid = $imageid";
		doQuery($query, 212);
	}
	viewImages();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewImageDetails
///
/// \brief prints a page with all information about an image
///
////////////////////////////////////////////////////////////////////////////////
function viewImageDetails() {
	$imageid = getContinuationVar("imageid");
	$images = getImages(1);
	$platforms = getPlatforms();
	$oslist = getOSList();
	print "<DIV align=center>\n";
	print "<H2>Image Details</H2>\n";
	print "<TABLE>\n";
	/*print "  <TR>\n";
	print "    <TH align=right>Short Name:</TH>\n";
	print "    <TD>" . $images[$imageid]["name"] . "</TD>\n";
	print "  </TR>\n";*/
	print "  <TR>\n";
	print "    <TH align=right>Long Name:</TH>\n";
	print "    <TD>" . $images[$imageid]["prettyname"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Owner:</TH>\n";
	print "    <TD>" . $images[$imageid]["owner"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Platform:</TH>\n";
	print "    <TD>" . $platforms[$images[$imageid]["platformid"]] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>OS:</TH>\n";
	print "    <TD>" . $oslist[$images[$imageid]["osid"]]["prettyname"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum RAM (MB):</TH>\n";
	print "    <TD>" . $images[$imageid]["minram"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Num of Processors:</TH>\n";
	print "    <TD>" . $images[$imageid]["minprocnumber"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Processor Speed (MHz):</TH>\n";
	print "    <TD>" . $images[$imageid]["minprocspeed"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Minimum Network Speed (Mbps):</TH>\n";
	print "    <TD>" . $images[$imageid]["minnetwork"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Maximum Concurrent Usage:</TH>\n";
	if($images[$imageid]['maxconcurrent'] == '')
		print "    <TD>N/A</TD>\n";
	else
		print "    <TD>" . $images[$imageid]["maxconcurrent"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Estimated Reload Time (min):</TH>\n";
	print "    <TD>" . $images[$imageid]["reloadtime"] . "</TD>\n";
	print "  </TR>\n";
	print "  <TR>\n";
	print "    <TH align=right>Available for checkout:</TH>\n";
	if($images[$imageid]["forcheckout"])
		print "    <TD>yes</TD>\n";
	else
		print "    <TD>no</TD>\n";
	print "  </TR>\n";
	if(array_key_exists("checkuser", $images[$imageid])) {
		print "  <TR>\n";
		print "    <TH align=right>Check for logged in user:</TH>\n";
		if($images[$imageid]["checkuser"])
			print "    <TD>yes</TD>\n";
		else
			print "    <TD>no</TD>\n";
		print "  </TR>\n";
	}
	if(! empty($images[$imageid]["usergroupid"])) {
		print "  <TR>\n";
		print "    <TH align=right>User group allowed to log in:</TH>\n";
		print "    <TD>{$images[$imageid]["usergroup"]}</TD>\n";
		print "  </TR>\n";
	}
	if($oslist[$images[$imageid]["osid"]]["type"] == 'windows') {
		print "  <TR>\n";
		print "    <TH align=right>Use sysprep:</TH>\n";
		if(array_key_exists("sysprep", $images[$imageid]) &&
		   $images[$imageid]["sysprep"] == 0)
			print "    <TD>no</TD>\n";
		else
			print "    <TD>yes</TD>\n";
		print "  </TR>\n";
	}
	if(array_key_exists("subimages", $images[$imageid]) &&
	   count($images[$imageid]["subimages"])) {
		print "  <TR>\n";
		print "    <TH style=\"vertical-align:top; text-align:right;\">";
		print "Subimages:</TH>\n";
		print "    <TD>\n";
		foreach($images[$imageid]["subimages"] as $imgid) {
			print "{$images[$imgid]["prettyname"]}<br>\n";
		}
		print "    </TD>\n";
		print "  </TR>\n";
	}
	print "</TABLE>\n";
	print "</DIV>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitImageGroups
///
/// \brief updates image groupings
///
////////////////////////////////////////////////////////////////////////////////
function submitImageGroups() {
	$groupinput = processInputVar("imagegroup", ARG_MULTINUMERIC);

	$images = getImages();

	# build an array of memberships currently in the db
	$tmp = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	$imagegroupsIDs = array_keys($tmp["image"]);  // ids of groups that user can manage
	$resources = getUserResources(array("imageAdmin"), 
	                              array("manageGroup"));
	$userImageIDs = array_keys($resources["image"]); // ids of images that user can manage
	$imagemembership = getResourceGroupMemberships("image");
	$baseimagegroups = $imagemembership["image"]; // all image group memberships
	$imagegroups = array();
	foreach(array_keys($baseimagegroups) as $imageid) {
		if(in_array($imageid, $userImageIDs)) {
			foreach($baseimagegroups[$imageid] as $grpid) {
				if(in_array($grpid, $imagegroupsIDs)) {
					if(array_key_exists($imageid, $imagegroups))
						array_push($imagegroups[$imageid], $grpid);
					else
						$imagegroups[$imageid] = array($grpid);
				}
			}
		}
	}

	# build an array of posted in memberships
	$newmembers = array();
	foreach(array_keys($groupinput) as $key) {
		list($imageid, $grpid) = explode(':', $key);
		if(array_key_exists($imageid, $newmembers)) {
			array_push($newmembers[$imageid], $grpid);
		}
		else {
			$newmembers[$imageid] = array($grpid);
		}
	}

	$adds = array();
	$removes = array();
	foreach(array_keys($images) as $imageid) {
		$id = $images[$imageid]["resourceid"];
		// if $imageid not in $userImageIds, don't bother with it
		if(! in_array($imageid, $userImageIDs))
			continue;
		// if $imageid is not in $newmembers and not in $imagegroups, do nothing
		if(! array_key_exists($imageid, $newmembers) &&
		   ! array_key_exists($imageid, $imagegroups)) {
			continue;
		}
		// check that $imageid is in $newmembers, if not, remove it from all groups
		// user has access to
		if(! array_key_exists($imageid, $newmembers)) {
			$removes[$id] = $imagegroups[$imageid];
			continue;
		}
		// check that $imageid is in $imagegroups, if not, add all groups in
		// $newmembers
		if(! array_key_exists($imageid, $imagegroups)) {
			$adds[$id] = $newmembers[$imageid];
			continue;
		}
		// adds are groupids that are in $newmembers, but not in $imagegroups
		$adds[$id] = array_diff($newmembers[$imageid], $imagegroups[$imageid]);
		if(count($adds[$id]) == 0) {
			unset($adds[$id]); 
		}
		// removes are groupids that are in $imagegroups, but not in $newmembers
		$removes[$id] = array_diff($imagegroups[$imageid], $newmembers[$imageid]);
		if(count($removes[$id]) == 0) {
			unset($removes[$id]);
		}
	}

	foreach(array_keys($adds) as $imageid) {
		foreach($adds[$imageid] as $grpid) {
			$query = "INSERT IGNORE INTO resourcegroupmembers "
					 . "(resourceid, resourcegroupid) "
			       . "VALUES ($imageid, $grpid)";
			doQuery($query, 287);
		}
	}

	foreach(array_keys($removes) as $imageid) {
		foreach($removes[$imageid] as $grpid) {
			$query = "DELETE FROM resourcegroupmembers "
					 . "WHERE resourceid = $imageid AND "
					 .       "resourcegroupid = $grpid";
			doQuery($query, 288);
		}
	}

	viewImageGrouping();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitImageMapping
///
/// \brief updates image group to computer group mapping
///
////////////////////////////////////////////////////////////////////////////////
function submitImageMapping() {
	$mapinput = processInputVar("mapping", ARG_MULTINUMERIC);

	# build an array of memberships currently in the db
	$tmp = getUserResources(array("imageAdmin"), 
									array("manageGroup"), 1);
	$imagegroups = $tmp["image"];
	$tmp = getUserResources(array("computerAdmin"),
	                        array("manageGroup"), 1);
	$compgroups = $tmp["computer"];
	$imageinlist = implode(',', array_keys($imagegroups));
	$compinlist = implode(',', array_keys($compgroups));
	$mapping = getResourceMapping("image", "computer", $imageinlist, $compinlist);

	# build an array of posted in memberships
	$newmembers = array();
	foreach(array_keys($mapinput) as $key) {
		list($imageid, $compid) = explode(':', $key);
		if(array_key_exists($imageid, $newmembers))
			array_push($newmembers[$imageid], $compid);
		else
			$newmembers[$imageid] = array($compid);
	}

	$adds = array();
	$removes = array();
	foreach(array_keys($imagegroups) as $imageid) {
		// if $imageid is not in $newmembers and not in $mapping, do nothing
		if(! array_key_exists($imageid, $newmembers) &&
		   ! array_key_exists($imageid, $mapping)) {
			continue;
		}
		// check that $imageid is in $newmembers, if not, remove it from all groups
		// user has access to
		if(! array_key_exists($imageid, $newmembers)) {
			$removes[$imageid] = $mapping[$imageid];
			continue;
		}
		// check that $imageid is in $mapping, if not, add all groups in
		// $newmembers
		if(! array_key_exists($imageid, $mapping)) {
			$adds[$imageid] = $newmembers[$imageid];
			continue;
		}
		// adds are groupids that are in $newmembers, but not in $mapping
		$adds[$imageid] = array_diff($newmembers[$imageid], $mapping[$imageid]);
		if(count($adds[$imageid]) == 0) {
			unset($adds[$imageid]); 
		}
		// removes are groupids that are in $mapping, but not in $newmembers
		$removes[$imageid] = array_diff($mapping[$imageid], $newmembers[$imageid]);
		if(count($removes[$imageid]) == 0) {
			unset($removes[$imageid]);
		}
	}

	foreach(array_keys($adds) as $imageid) {
		foreach($adds[$imageid] as $compid) {
			$query = "INSERT INTO resourcemap "
					 .        "(resourcegroupid1, "
			       .        "resourcetypeid1, "
			       .        "resourcegroupid2, "
			       .        "resourcetypeid2) "
			       . "VALUES ($imageid, "
			       .         "13, "
			       .         "$compid, "
			       .         "12)";
			doQuery($query, 101);
		}
	}

	foreach(array_keys($removes) as $imageid) {
		foreach($removes[$imageid] as $compid) {
			$query = "DELETE FROM resourcemap "
					 . "WHERE resourcegroupid1 = $imageid AND "
					 .       "resourcetypeid1 = 13 AND "
					 .       "resourcegroupid2 = $compid AND "
					 .       "resourcetypeid2 = 12";
			doQuery($query, 101);
		}
	}

	viewImageMapping();
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processImageInput($checks)
///
/// \param $checks - (optional) 1 to perform validation, 0 not to
///
/// \return an array with the following indexes:\n
/// imageid, name, prettyname, platformid, osid
///
/// \brief validates input from the previous form; if anything was improperly
/// submitted, sets submitErr and submitErrMsg
///
////////////////////////////////////////////////////////////////////////////////
function processImageInput($checks=1) {
	global $submitErr, $submitErrMsg, $user;
	$return = array();
	$mode = processInputVar("mode", ARG_STRING);
	$return["imageid"] = processInputVar("imageid" , ARG_NUMERIC, getContinuationVar('imageid'));
	$return['requestid'] = getContinuationVar('requestid');
	#$return["name"] = processInputVar("name", ARG_STRING);
	$return["prettyname"] = processInputVar("prettyname", ARG_STRING);
	$return["owner"] = processInputVar("owner", ARG_STRING, "{$user["unityid"]}@{$user['affiliation']}");
	#$return["platformid"] = processInputVar("platformid", ARG_NUMERIC);
	#$return["osid"] = processInputVar("osid", ARG_NUMERIC);
	$return["minram"] = processInputVar("minram", ARG_NUMERIC, 64);
	$return["minprocnumber"] = processInputVar("minprocnumber", ARG_NUMERIC);
	$return["minprocspeed"] = processInputVar("minprocspeed", ARG_NUMERIC, 500);
	$return["minnetwork"] = processInputVar("minnetwork", ARG_NUMERIC);
	$return["maxconcurrent"] = processInputVar("maxconcurrent", ARG_NUMERIC);
	$return["reloadtime"] = processInputVar("reloadtime", ARG_NUMERIC, 10);
	$return["forcheckout"] = processInputVar("forcheckout", ARG_NUMERIC, 1);
	$return["checkuser"] = processInputVar("checkuser", ARG_NUMERIC, 1);
	$return["usergroupid"] = processInputVar("usergroupid", ARG_NUMERIC);
	$return["sysprep"] = processInputVar("sysprep", ARG_NUMERIC, 1);
	$return["description"] = processInputVar("description", ARG_STRING);
	$return["usage"] = processInputVar("usage", ARG_STRING);
	$return["comments"] = processInputVar("comments", ARG_STRING);

	$return['description'] = preg_replace("/[\n\s]*$/", '', $return['description']);
	$return['description'] = preg_replace("/\r/", '', $return['description']);
	$return['description'] = htmlspecialchars($return['description']);
	$return['description'] = preg_replace("/\n/", '<br>', $return['description']);
	$return['usage'] = preg_replace("/[\n\s]*$/", '', $return['usage']);
	$return['usage'] = preg_replace("/\r/", '', $return['usage']);
	$return['usage'] = htmlspecialchars($return['usage']);
	$return['usage'] = preg_replace("/\n/", '<br>', $return['usage']);
	$return['comments'] = preg_replace("/[\n\s]*$/", '', $return['comments']);
	$return['comments'] = preg_replace("/\r/", '', $return['comments']);
	$return['comments'] = htmlspecialchars($return['comments']);
	$return['comments'] = preg_replace("/\n/", '<br>', $return['comments']);

	if(! $checks) {
		return $return;
	}
	
	/*if($mode != "confirmAddImage" &&
	   (strlen($return["name"]) > 30 || strlen($return["name"]) < 2)) {
	   $submitErr |= NAMEERR;
	   $submitErrMsg[NAMEERR] = "Short Name must be from 2 to 30 characters";
	}
	if(! ($submitErr & NAMEERR) && 
	   checkForImageName($return["name"], "short", $return["imageid"])) {
	   $submitErr |= NAMEERR;
	   $submitErrMsg[NAMEERR] = "An image already exists with this name.";
	}*/
	if(ereg('-', $return["prettyname"]) ||
		strlen($return["prettyname"]) > 60 || strlen($return["prettyname"]) < 2) {
	   $submitErr |= PRETTYNAMEERR;
	   $submitErrMsg[PRETTYNAMEERR] = "Long Name must be from 2 to 60 characters "
		                             . "and cannot contain any dashes (-).";
	}
	if(! ($submitErr & PRETTYNAMEERR) && 
	   checkForImageName($return["prettyname"], "long", $return["imageid"])) {
	   $submitErr |= PRETTYNAMEERR;
	   $submitErrMsg[PRETTYNAMEERR] = "An image already exists with this name.";
	}
	if($return["minram"] < 0 || $return["minram"] > 20480) {
	   $submitErr |= MINRAMERR;
	   $submitErrMsg[MINRAMERR] = "RAM must be between 0 and 20480 MB";
	}
	if($return["minprocspeed"] < 0 || $return["minprocspeed"] > 20000) {
	   $submitErr |= MINPROCSPEEDERR;
	   $submitErrMsg[MINPROCSPEEDERR] = "Processor Speed must be between 0 and 20000";
	}
	if((! is_numeric($return['maxconcurrent']) && ! empty($return['maxconcurrent'])) ||
	   (is_numeric($return['maxconcurrent']) && ($return["maxconcurrent"] < 1 || $return["maxconcurrent"] > 255))) {
	   $submitErr |= MAXCONCURRENTERR;
	   $submitErrMsg[MAXCONCURRENTERR] = "Max concurrent usage must be blank or between 1 and 255";
	}
	if($return["reloadtime"] < 0 || $return["reloadtime"] > 120) {
	   $submitErr |= RELOADTIMEERR;
	   $submitErrMsg[RELOADTIMEERR] = "Estimated Reload Time must be between 0 and 120";
	}
	if(! validateUserid($return["owner"])) {
	   $submitErr |= IMGOWNERERR;
	   $submitErrMsg[IMGOWNERERR] = "Submitted ID is not valid";
	}
	if(empty($return['description'])) {
	   $submitErr |= IMAGEDESCRIPTIONERR;
	   $submitErrMsg[IMAGEDESCRIPTIONERR] = "You must include a description of the image<br>";
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForImageName($name, $longshort, $id)
///
/// \param $name - the name of an image
/// \param $longshort - "long" for long/pretty name, "short" for short/name
/// \param $id - id of an image to ignore
///
/// \return 1 if $name is already in the image table, 0 if not
///
/// \brief checks for $name being in the image table except for $id
///
////////////////////////////////////////////////////////////////////////////////
function checkForImageName($name, $longshort, $id) {
	if($longshort == "long")
		$field = "prettyname";
	else
		$field = "name";
	$query = "SELECT id FROM image "
	       . "WHERE $field = '$name'";
	if(! empty($id))
		$query .= " AND id != $id";
	$qh = doQuery($query, 101);
	if(mysql_num_rows($qh))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn updateImage($data)
///
/// \param $data - an array returned from processImageInput
///
/// \return number of rows affected by the update\n
/// \b NOTE: mysql reports that no rows were affected if none of the fields
/// were actually changed even if the update matched a row
///
/// \brief performs a query to update the image with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function updateImage($data) {
	$imgdata = getImages(0, $data["imageid"]);
	$imagenotes = getImageNotes($data['imageid']);
	$ownerid = getUserlistID($data["owner"]);
	if(empty($data['maxconcurrent']) || ! is_numeric($data['maxconcurrent']))
		$data['maxconcurrent'] = 'NULL';
	$query = "UPDATE image "
	       . "SET prettyname = '{$data["prettyname"]}', "
	       .     "ownerid = $ownerid, "
	       /*.     "platformid = {$data["platformid"]}, "
	       .     "OSid = {$data["osid"]}, "*/
	       .     "minram = {$data["minram"]}, "
	       .     "minprocnumber = {$data["minprocnumber"]}, "
	       .     "minprocspeed = {$data["minprocspeed"]}, "
	       .     "minnetwork = {$data["minnetwork"]}, "
	       .     "maxconcurrent = {$data["maxconcurrent"]}, "
	       .     "reloadtime = {$data["reloadtime"]}, "
	       .     "forcheckout = {$data["forcheckout"]}, "
	       .     "description = '{$data["description"]}', "
	       .     "`usage` = '{$data["usage"]}' "
	       . "WHERE id = {$data["imageid"]}";
	$qh = doQuery($query, 200);
	$return = mysql_affected_rows($GLOBALS["mysql_link_vcl"]);
	if(empty($imgdata[$data["imageid"]]["imagemetaid"]) &&
	   ($data["checkuser"] == 0 || $data["usergroupid"] != 0)) {
		if($data["usergroupid"] == 0)
			$data["usergroupid"] = "NULL";
		$query = "INSERT INTO imagemeta "
		       .        "(checkuser, "
		       .        "usergroupid) "
		       . "VALUES ({$data["checkuser"]}, "
		       .        "{$data["usergroupid"]})";
		doQuery($query, 101);
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM imagemeta", 101);
		if(! $row = mysql_fetch_row($qh))
			abort(101);
		$imagemetaid = $row[0];
		$query = "UPDATE image "
		       . "SET imagemetaid = $imagemetaid "
		       . "WHERE id = {$data["imageid"]}";
		doQuery($query, 101);
	}
	elseif(! empty($imgdata[$data["imageid"]]["imagemetaid"]) &&
	   ($data["checkuser"] != $imgdata[$data["imageid"]]["checkuser"] ||
	   $data["usergroupid"] != $imgdata[$data["imageid"]]["usergroupid"])) {
		if($data["usergroupid"] == 0)
			$data["usergroupid"] = "NULL";
		$query = "UPDATE imagemeta "
		       . "SET checkuser = {$data["checkuser"]}, "
		       .     "usergroupid = {$data["usergroupid"]} "
		       . "WHERE id = {$imgdata[$data["imageid"]]["imagemetaid"]}";
		doQuery($query, 101);
	}
	return $return;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn addImage($data)
///
/// \param $data - an array returned from processImageInput
///
/// \return number of rows affected by the insert\n
///
/// \brief performs a query to insert the image with data from $data
///
////////////////////////////////////////////////////////////////////////////////
function addImage($data) {
	global $user;
	if(get_magic_quotes_gpc()) {
		$data['description'] = stripslashes($data['description']);
		$data['usage'] = stripslashes($data['usage']);
	}
	$data['description'] = mysql_escape_string($data['description']);
	$data['usage'] = mysql_escape_string($data['usage']);

	$ownerdata = getUserInfo($data['owner']);
	$ownerid = $ownerdata['id'];
	if(empty($data['maxconcurrent']) || ! is_numeric($data['maxconcurrent']))
		$data['maxconcurrent'] = 'NULL';
	$query = "INSERT INTO image "
	       .         "(prettyname, "
	       .         "ownerid, "
	       .         "platformid, "
	       .         "OSid, "
	       .         "minram, "
	       .         "minprocnumber, "
	       .         "minprocspeed, "
	       .         "minnetwork, "
	       .         "maxconcurrent, "
	       .         "reloadtime, "
	       .         "deleted, "
	       .         "description, "
	       .         "`usage`, "
	       .         "basedoffrevisionid) "
	       . "VALUES ('{$data["prettyname"]}', "
	       .         "$ownerid, "
	       .         "{$data["platformid"]}, "
	       .         "{$data["osid"]}, "
	       .         "{$data["minram"]}, "
	       .         "{$data["minprocnumber"]}, "
	       .         "{$data["minprocspeed"]}, "
	       .         "{$data["minnetwork"]}, "
	       .         "{$data["maxconcurrent"]}, "
	       .         "{$data["reloadtime"]}, "
	       .         "1, "
	       .         "'{$data['description']}', "
	       .         "'{$data['usage']}', "
	       .         "{$data['basedoffrevisionid']})";
	doQuery($query, 205);

	// get last insert id
	$qh = doQuery("SELECT LAST_INSERT_ID() FROM image", 206);
	if(! $row = mysql_fetch_row($qh)) {
		abort(207);
	}
	$imageid = $row[0];

	// possibly add entry to imagemeta table
	$imagemetaid = 0;
	if($data['checkuser'] != 0 && $data['checkuser'] != 1)
		$data['checkuser'] = 1;
	if(! is_numeric($data['usergroupid']) || $data['usergroupid'] <= 0)
		$data['usergroupid'] = "NULL";
	if($data['sysprep'] != 0 && $data['sysprep'] != 1)
		$data['sysprep'] = 1;
	if($data['checkuser'] == 0 ||
	   (is_numeric($data['usergroupid']) && $data['usergroupid'] > 0) ||
	   $data['sysprep'] == 0) {
		$query = "INSERT INTO imagemeta "
		       .        "(checkuser, "
		       .        "usergroupid, "
		       .        "sysprep) "
		       . "VALUES "
		       .        "({$data['checkuser']}, "
		       .        "{$data['usergroupid']}, "
		       .        "{$data['sysprep']})";
		doQuery($query, 101);

		// get last insert id
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM imagemeta", 101);
		if(! $row = mysql_fetch_row($qh)) {
			abort(207);
		}
		$imagemetaid = $row[0];
	}

	// create name from pretty name, os, and last insert id
	$OSs = getOSList();
	$name = $OSs[$data["osid"]]["name"] . "-" . 
	        preg_replace('/\W/', '', $data["prettyname"]) . $imageid . "-v0";
	if($imagemetaid) {
		$query = "UPDATE image "
		       . "SET name = '$name', "
		       .     "imagemetaid = $imagemetaid "
		       . "WHERE id = $imageid";
	}
	else
		$query = "UPDATE image SET name = '$name' WHERE id = $imageid";
	doQuery($query, 208);

	$query = "INSERT INTO imagerevision "
	       .        "(imageid, "
	       .        "userid, "
	       .        "datecreated, "
	       .        "production, "
	       .        "imagename, "
	       .        "comments) "
	       . "VALUES ($imageid, "
	       .        "{$user['id']}, "
	       .        "NOW(), "
	       .        "1, "
	       .        "'$name', "
	       .        "'{$data['comments']}')";
	doQuery($query, 101);

	// add entry in resource table
	$query = "INSERT INTO resource "
			 .        "(resourcetypeid, "
			 .        "subid) "
			 . "VALUES (13, "
			 .         "$imageid)";
	doQuery($query, 209);
	$qh = doQuery("SELECT LAST_INSERT_ID() FROM resource", 101);
	$row = mysql_fetch_row($qh);
	$resourceid = $row[0];

	if(strncmp($OSs[$data['osid']]['name'], 'vmware', 6) == 0)
		$vmware = 1;
	else
		$vmware = 0;

	// create new node if it does not exist
	if($vmware)
		$nodename = 'newvmimages';
	else
		$nodename = 'newimages';
	$query = "SELECT id "
	        . "FROM privnode "
	        . "WHERE name = '$nodename' AND "
	        .       "parent = 3";
	$qh = doQuery($query, 101);
	if(! $row = mysql_fetch_assoc($qh)) {
		$query2 = "INSERT INTO privnode "
		        .        "(parent, "
		        .        "name) "
		        . "VALUES "
		        .        "(3, "
		        .        "'$nodename')";
		doQuery($query2, 101);
		$qh = doQuery($query, 101);
		$row = mysql_fetch_assoc($qh);
	}
	$parent = $row['id'];
	$query = "SELECT id "
	        . "FROM privnode "
	        . "WHERE name = '{$ownerdata['login']}-$ownerid' AND "
	        .       "parent = $parent";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		$newnode = $row['id'];
	else {
		$query = "INSERT INTO privnode "
		       .        "(parent, name) "
		       . "VALUES ($parent, '{$ownerdata['login']}-$ownerid')";
		doQuery($query, 101);
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM privnode", 101);
		$row = mysql_fetch_row($qh);
		$newnode = $row[0];
	}

	// give user imageCheckOut and imageAdmin at new node
	$newprivs = array('imageCheckOut', 'imageAdmin');
	updateUserOrGroupPrivs($ownerid, $newnode, $newprivs, array(), 'user');

	// create new image group if it does not exist
	$query = "SELECT id "
	        . "FROM usergroup "
	        . "WHERE name = 'manageNewImages'";
	$qh = doQuery($query, 101);
	$row = mysql_fetch_assoc($qh);
	$ownergroupid = $row['id'];
	if($vmware)
		$prefix = 'newvmimages';
	else
		$prefix = 'newimages';
	$query = "SELECT id "
	       . "FROM resourcegroup "
	       . "WHERE name = '$prefix-{$ownerdata['login']}-$ownerid' AND "
	       .       "ownerusergroupid = $ownergroupid AND "
	       .       "resourcetypeid = 13";
	$qh = doQuery($query, 101);
	if($row = mysql_fetch_assoc($qh))
		$resourcegroupid = $row['id'];
	else {
		$query = "INSERT INTO resourcegroup "
		       .         "(name, "
		       .         "ownerusergroupid, "
		       .         "resourcetypeid) "
		       . "VALUES ('$prefix-{$ownerdata['login']}-$ownerid', "
		       .         "$ownergroupid, "
		       .         "13)";
		doQuery($query, 305);
		$qh = doQuery("SELECT LAST_INSERT_ID() FROM resourcegroup", 101);
		$row = mysql_fetch_row($qh);
		$resourcegroupid = $row[0];

		// map group to newimages/newvmimages comp group
		if($vmware)
			$rgroupname = 'newvmimages';
		else
			$rgroupname = 'newimages';
		$query = "SELECT id "
		       . "FROM resourcegroup "
		       . "WHERE name = '$rgroupname' AND "
		       .       "resourcetypeid = 12";
		$qh = doQuery($query, 101);
		$row = mysql_fetch_assoc($qh);
		$compResGrpid = $row['id'];
		$query = "INSERT INTO resourcemap "
		       .        "(resourcegroupid1, "
		       .        "resourcetypeid1, "
		       .        "resourcegroupid2, "
		       .        "resourcetypeid2) "
		       . "VALUES ($resourcegroupid, "
		       .         "13, "
		       .         "$compResGrpid, "
		       .         "12)";
		doQuery($query, 101);
	}

	// make image group available at new node
	$adds = array('available', 'administer');
	if($vmware)
		updateResourcePrivs("image/newvmimages-{$ownerdata['login']}-$ownerid", $newnode, $adds, array());
	else
		updateResourcePrivs("image/newimages-{$ownerdata['login']}-$ownerid", $newnode, $adds, array());

	// add image to image group
	$query = "INSERT INTO resourcegroupmembers "
	       . "(resourceid, resourcegroupid) "
	       . "VALUES ($resourceid, $resourcegroupid)";
	doQuery($query, 101);

	return $imageid;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn checkForImageUsage($imageid)
///
/// \param $imageid - id of an image
///
/// \return 0 if image is not used on any computers, 1 if it is
///
/// \brief checks for $imageid being the current imageid for any computers in
/// the computer table or the imageid for any active reservations
///
////////////////////////////////////////////////////////////////////////////////
function checkForImageUsage($imageid) {
	$query = "SELECT id "
	       . "FROM computer "
	       . "WHERE currentimageid = $imageid";
	$qh = doQuery($query, 250);
	if(mysql_num_rows($qh))
		return 1;
	$query = "SELECT rs.id "
	       . "FROM reservation rs, "
	       .      "request rq "
	       . "WHERE rs.requestid = rq.id "
	       .   "AND rs.imageid = $imageid "
	       .   "AND rq.end > NOW() "
	       .   "AND rq.stateid NOT IN (1, 5, 12)";
	$qh = doQuery($query, 250);
	if(mysql_num_rows($qh))
		return 1;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonImageGroupingImages()
///
/// \brief accepts a groupid via form input and prints a json array with 3
/// arrays: an array of images that are in the group, an array of images
/// not in it, and an array of all images user has access to
///
////////////////////////////////////////////////////////////////////////////////
function jsonImageGroupingImages() {
	$groupid = processInputVar('groupid', ARG_NUMERIC);
	$groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($groupid, $groups['image'])) {
		$arr = array('inimages' => array(), 'outimages' => array(), 'all' => array());
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$resources = getUserResources(array('imageAdmin'), array('manageGroup'));
	uasort($resources['image'], 'sortKeepIndex');
	$memberships = getResourceGroupMemberships('image');
	$all = array();
	$in = array();
	$out = array();
	foreach($resources['image'] as $id => $image) {
		if($image == 'No Image')
			continue;
		if(array_key_exists($id, $memberships['image']) && 
			in_array($groupid, $memberships['image'][$id])) {
			$all[] = array('inout' => 1, 'id' => $id, 'name' => $image);
			$in[] = array('name' => $image, 'id' => $id);
		}
		else {
			$all[] = array('inout' => 0, 'id' => $id, 'name' => $image);
			$out[] = array('name' => $image, 'id' => $id);
		}
	}
	$arr = array('inimages' => $in, 'outimages' => $out, 'all' => $all);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonImageGroupingGroups()
///
/// \brief accepts an image id via form input and prints a json array with 3
/// arrays: an array of groups that the image is in, an array of groups it
/// is not in and an array of all groups user has access to
///
////////////////////////////////////////////////////////////////////////////////
function jsonImageGroupingGroups() {
	$imageid = processInputVar('imageid', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin"), array("manageGroup"));
	if(! array_key_exists($imageid, $resources['image'])) {
		$arr = array('ingroups' => array(), 'outgroups' => array(), 'all' => array());
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}
	$groups = getUserResources(array('imageAdmin'), array('manageGroup'), 1);
	$memberships = getResourceGroupMemberships('image');
	$in = array();
	$out = array();
	$all = array();
	foreach($groups['image'] as $id => $group) {
		if(array_key_exists($imageid, $memberships['image']) && 
			in_array($id, $memberships['image'][$imageid])) {
			$all[] = array('inout' => 1, 'id' => $id, 'name' => $group);
			$in[] = array('name' => $group, 'id' => $id);
		}
		else {
			$all[] = array('inout' => 0, 'id' => $id, 'name' => $group);
			$out[] = array('name' => $group, 'id' => $id);
		}
	}
	$arr = array('ingroups' => $in, 'outgroups' => $out, 'all' => $all);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonImageMapCompGroups()
///
/// \brief accepts a image groupid via form input and prints a json array with 3
/// arrays: an array of computer groups that are mapped to the group, an array
/// of computer groups not mapped to it, and an array of all computer groups 
/// the user has access to
///
////////////////////////////////////////////////////////////////////////////////
function jsonImageMapCompGroups() {
	$imagegrpid = processInputVar('imagegrpid', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($imagegrpid, $resources['image'])) {
		$arr = array('ingroups' => array(), 'outgroups' => array(), 'all' => array());
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}
	$compgroups = getUserResources(array('computerAdmin'), array('manageGroup'), 1);
	$mapping = getResourceMapping('image', 'computer');
	$in = array();
	$out = array();
	$all = array();
	foreach($compgroups['computer'] as $id => $group) {
		if(array_key_exists($imagegrpid, $mapping) && 
			in_array($id, $mapping[$imagegrpid])) {
			$all[] = array('inout' => 1, 'id' => $id, 'name' => $group);
			$in[] = array('name' => $group, 'id' => $id);
		}
		else {
			$all[] = array('inout' => 0, 'id' => $id, 'name' => $group);
			$out[] = array('name' => $group, 'id' => $id);
		}
	}
	$arr = array('ingroups' => $in, 'outgroups' => $out, 'all' => $all);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn jsonImageMapImgGroups()
///
/// \brief accepts a computer groupid via form input and prints a json array
/// with 3 arrays: an array of image groups that are mapped to the group, an
/// array of image groups not mapped to it, and an array of all image groups 
/// the user has access to
///
////////////////////////////////////////////////////////////////////////////////
function jsonImageMapImgGroups() {
	$compgrpid = processInputVar('compgrpid', ARG_NUMERIC);
	$resources = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($compgrpid, $resources['computer'])) {
		$arr = array('ingroups' => array(), 'outgroups' => array(), 'all' => array());
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}
	$imagegroups = getUserResources(array('imageAdmin'), array('manageGroup'), 1);
	$mapping = getResourceMapping('computer', 'image');
	$in = array();
	$out = array();
	$all = array();
	foreach($imagegroups['image'] as $id => $group) {
		if(array_key_exists($compgrpid, $mapping) && 
			in_array($id, $mapping[$compgrpid])) {
			$all[] = array('inout' => 1, 'id' => $id, 'name' => $group);
			$in[] = array('name' => $group, 'id' => $id);
		}
		else {
			$all[] = array('inout' => 0, 'id' => $id, 'name' => $group);
			$out[] = array('name' => $group, 'id' => $id);
		}
	}
	$arr = array('ingroups' => $in, 'outgroups' => $out, 'all' => $all);
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJaddImageToGroup()
///
/// \brief accepts a groupid and a comma delimited list of image ids to be
/// added to the group; adds them and returns an array of image ids that were
/// added
///
////////////////////////////////////////////////////////////////////////////////
function AJaddImageToGroup() {
	$groupid = processInputVar('id', ARG_NUMERIC);
	$groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($groupid, $groups['image'])) {
		$arr = array('images' => array(), 'addrem' => 1);
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$resources = getUserResources(array("imageAdmin"), array("manageGroup"));
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$imageids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $resources['image'])) {
			$arr = array('images' => array(), 'addrem' => 1);
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
			return;
		}
		$imageids[] = $id;
	}

	$allimages = getImages();
	$adds = array();
	foreach($imageids as $id) {
		$adds[] = "({$allimages[$id]['resourceid']}, $groupid)";
	}
	$query = "INSERT IGNORE INTO resourcegroupmembers "
			 . "(resourceid, resourcegroupid) VALUES ";
	$query .= implode(',', $adds);
	doQuery($query, 287);
	$_SESSION['userresources'] = array();
	$arr = array('images' => $imageids, 'addrem' => 1);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJremImageFromGroup()
///
/// \brief accepts a groupid and a comma delimited list of image ids to be
/// removed from the group; removes them and returns an array of image ids 
/// that were removed
///
////////////////////////////////////////////////////////////////////////////////
function AJremImageFromGroup() {
	$groupid = processInputVar('id', ARG_NUMERIC);
	$groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($groupid, $groups['image'])) {
		$arr = array('images' => array(), 'addrem' => 0);
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$resources = getUserResources(array("imageAdmin"), array("manageGroup"));
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$imageids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $resources['image'])) {
			$arr = array('images' => array(), 'addrem' => 0, 'id' => $id, 'extra' => $resources['image']);
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
			return;
		}
		$imageids[] = $id;
	}

	$allimages = getImages();
	foreach($imageids as $id) {
		$query = "DELETE FROM resourcegroupmembers "
				 . "WHERE resourceid = {$allimages[$id]['resourceid']} AND "
				 .       "resourcegroupid = $groupid";
		doQuery($query, 288);
	}
	$_SESSION['userresources'] = array();
	$arr = array('images' => $imageids, 'addrem' => 0);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJaddGroupToImage()
///
/// \brief accepts an image id and a comma delimited list of group ids that
/// the image should be added to; adds it to them and returns an array of
/// groups it was added to
///
////////////////////////////////////////////////////////////////////////////////
function AJaddGroupToImage() {
	$imageid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin"), array("manageGroup"));
	if(! array_key_exists($imageid, $resources['image'])) {
		$arr = array('groups' => array(), 'addrem' => 1);
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$groupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $groups['image'])) {
			$arr = array('groups' => array(), 'addrem' => 1);
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
			return;
		}
		$groupids[] = $id;
	}

	$img = getImages(0, $imageid);
	$adds = array();
	foreach($groupids as $id) {
		$adds[] = "({$img[$imageid]['resourceid']}, $id)";
	}
	$query = "INSERT IGNORE INTO resourcegroupmembers "
			 . "(resourceid, resourcegroupid) VALUES ";
	$query .= implode(',', $adds);
	doQuery($query, 101);
	$_SESSION['userresources'] = array();
	$arr = array('groups' => $groupids, 'addrem' => 1);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJremGroupFromImage()
///
/// \brief accepts an image id and a comma delimited list of group ids that
/// the image should be removed from; removes it from them and returns an 
/// array of groups it was removed from
///
////////////////////////////////////////////////////////////////////////////////
function AJremGroupFromImage() {
	$imageid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin"), array("manageGroup"));
	if(! array_key_exists($imageid, $resources['image'])) {
		$arr = array('groups' => array(), 'addrem' => 0);
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$groups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$groupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $groups['image'])) {
			$arr = array('groups' => array(), 'addrem' => 0);
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
			return;
		}
		$groupids[] = $id;
	}

	$img = getImages(0, $imageid);
	foreach($groupids as $id) {
		$query = "DELETE FROM resourcegroupmembers "
				 . "WHERE resourceid = {$img[$imageid]['resourceid']} AND "
				 .       "resourcegroupid = $id";
		doQuery($query, 288);
	}
	$_SESSION['userresources'] = array();
	$arr = array('groups' => $groupids, 'addrem' => 0);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJaddCompGrpToImgGrp()
///
/// \brief accepts an image group id and a comma delimited list of computer
/// group ids that the image group should be mapped to; maps it to them and
/// returns an array of groups it was mapped to
///
////////////////////////////////////////////////////////////////////////////////
function AJaddCompGrpToImgGrp() {
	$imagegrpid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($imagegrpid, $resources['image'])) {
		$arr = array('groups' => array(), 'addrem' => 1);
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$compgroups = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$compgroupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $compgroups['computer'])) {
			$arr = array('groups' => array(), 'addrem' => 1);
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
			return;
		}
		$compgroupids[] = $id;
	}

	$adds = array();
	foreach($compgroupids as $id) {
		$adds[] = "($imagegrpid, 13, $id, 12)";
	}
	$query = "INSERT IGNORE INTO resourcemap "
			 . "(resourcegroupid1, resourcetypeid1, resourcegroupid2, resourcetypeid2) VALUES ";
	$query .= implode(',', $adds);
	doQuery($query, 101);
	$_SESSION['userresources'] = array();
	$arr = array('groups' => $compgroupids, 'addrem' => 1);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJremCompGrpFromImgGrp()
///
/// \brief accepts an image group id and a comma delimited list of computer
/// group ids that the image group should be unmapped from; unmaps it from them
/// and returns an array of computer groups it was unmapped from
///
////////////////////////////////////////////////////////////////////////////////
function AJremCompGrpFromImgGrp() {
	$imagegrpid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($imagegrpid, $resources['image'])) {
		$arr = array('groups' => array(), 'addrem' => 0);
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$compgroups = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$compgroupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $compgroups['computer'])) {
			$arr = array('groups' => array(), 'addrem' => 0);
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
			return;
		}
		$compgroupids[] = $id;
	}

	foreach($compgroupids as $id) {
		$query = "DELETE FROM resourcemap "
				 . "WHERE resourcegroupid1 = $imagegrpid AND "
				 .       "resourcetypeid1 = 13 AND "
				 .       "resourcegroupid2 = $id AND "
				 .       "resourcetypeid2 = 12";
		doQuery($query, 288);
	}
	$_SESSION['userresources'] = array();
	$arr = array('groups' => $compgroupids, 'addrem' => 0);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJaddImgGrpToCompGrp()
///
/// \brief accepts a computer group id and a comma delimited list of image
/// group ids that the computer group should be mapped to; maps it to them and
/// returns an array of groups it was mapped to
///
////////////////////////////////////////////////////////////////////////////////
function AJaddImgGrpToCompGrp() {
	$compgrpid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($compgrpid, $resources['computer'])) {
		$arr = array('groups' => array(), 'addrem' => 1);
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$imagegroups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$imagegroupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $imagegroups['image'])) {
			$arr = array('groups' => array(), 'addrem' => 1);
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
			return;
		}
		$imagegroupids[] = $id;
	}

	$adds = array();
	foreach($imagegroupids as $id) {
		$adds[] = "($id, 13, $compgrpid, 12)";
	}
	$query = "INSERT IGNORE INTO resourcemap "
			 . "(resourcegroupid1, resourcetypeid1, resourcegroupid2, resourcetypeid2) VALUES ";
	$query .= implode(',', $adds);
	doQuery($query, 101);
	$_SESSION['userresources'] = array();
	$arr = array('groups' => $imagegroupids, 'addrem' => 1);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJremImgGrpFromCompGrp()
///
/// \brief accepts a computer group id and a comma delimited list of image group
/// ids that the computer group should be unmapped from; unmaps it from them
/// and returns an array of image groups it was unmapped from
///
////////////////////////////////////////////////////////////////////////////////
function AJremImgGrpFromCompGrp() {
	$compgrpid = processInputVar('id', ARG_NUMERIC);
	$resources = getUserResources(array("computerAdmin"), array("manageGroup"), 1);
	if(! array_key_exists($compgrpid, $resources['computer'])) {
		$arr = array('groups' => array(), 'addrem' => 0);
		header('Content-Type: text/json-comment-filtered; charset=utf-8');
		print '/*{"items":' . json_encode($arr) . '}*/';
		return;
	}

	$imagegroups = getUserResources(array("imageAdmin"), array("manageGroup"), 1);
	$tmp = processInputVar('listids', ARG_STRING);
	$tmp = explode(',', $tmp);
	$imagegroupids = array();
	foreach($tmp as $id) {
		if(! is_numeric($id))
			continue;
		if(! array_key_exists($id, $imagegroups['image'])) {
			$arr = array('groups' => array(), 'addrem' => 0);
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode($arr) . '}*/';
			return;
		}
		$imagegroupids[] = $id;
	}

	foreach($imagegroupids as $id) {
		$query = "DELETE FROM resourcemap "
				 . "WHERE resourcegroupid1 = $id AND "
				 .       "resourcetypeid1 = 13 AND "
				 .       "resourcegroupid2 = $compgrpid AND "
				 .       "resourcetypeid2 = 12";
		doQuery($query, 288);
	}
	$_SESSION['userresources'] = array();
	$arr = array('groups' => $imagegroupids, 'addrem' => 0);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJupdateRevisionProduction()
///
/// \brief updates which revision is set as the one in production
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateRevisionProduction() {
	$imageid = getContinuationVar('imageid');
	$revisionid = getContinuationVar('revisionid');
	$query = "UPDATE imagerevision "
	       . "SET production = 0 "
	       . "WHERE imageid = $imageid";
	doQuery($query, 101);
	$query = "UPDATE imagerevision "
	       . "SET production = 1 "
	       . "WHERE id = $revisionid";
	doQuery($query, 101);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJupdateRevisionComments()
///
/// \brief updates the comments for a revision
///
////////////////////////////////////////////////////////////////////////////////
function AJupdateRevisionComments() {
	$imageid = getContinuationVar('imageid');
	$revisionid = getContinuationVar('revisionid');
	$comments = processInputVar('comments', ARG_STRING);
	$comments = htmlspecialchars($comments);
	if(get_magic_quotes_gpc())
		$comments = stripslashes($comments);
	$comments = mysql_escape_string($comments);
	$query = "UPDATE imagerevision "
	       . "SET comments = '$comments' "
	       . "WHERE id = $revisionid";
	doQuery($query, 101);
	$arr = array('comments' => $comments, 'id' => $revisionid);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJdeleteRevisions()
///
/// \brief sets deleted flag for submitted revisions
///
////////////////////////////////////////////////////////////////////////////////
function AJdeleteRevisions() {
	$revids = getContinuationVar('revids');
	$imageid = getContinuationVar('imageid');
	$checkedids = processInputVar('checkedids', ARG_STRING);
	$ids = explode(',', $checkedids);
	foreach($ids as $id) {
		if(! is_numeric($id) || ! in_array($id, $revids)) {
			header('Content-Type: text/json-comment-filtered; charset=utf-8');
			print '/*{"items":' . json_encode(array()) . '}*/';
			return;
		}
	}
	$query = "UPDATE imagerevision "
	       . "SET deleted = 1 "
	       . "WHERE id IN ($checkedids) "
	       .   "AND production != 1";
	doQuery($query, 101);
	$html = getRevisionHTML($imageid);
	$arr = array('html' => $html);
	header('Content-Type: text/json-comment-filtered; charset=utf-8');
	print '/*{"items":' . json_encode($arr) . '}*/';
}

?>
