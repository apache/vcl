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

// docreaders:
// 1 - admin

$docreaders = array(1);
$doceditors = array(1);
$actions['mode']['viewdocs'] = "viewDocs";

////////////////////////////////////////////////////////////////////////////////
///
/// \fn viewDocs()
///
/// \brief prints a page to select which VCL docs to view
///
////////////////////////////////////////////////////////////////////////////////
function viewDocs() {
	global $user, $docreaders, $viewmode;
	if(! (in_array("userGrant", $user["privileges"]) ||
		in_array("resourceGrant", $user["privileges"]) ||
		in_array("nodeAdmin", $user["privileges"]) ||
		in_array($user['id'], $docreaders)))
		return;
	$item = getContinuationVar("item", processInputVar('item', ARG_STRING));

	switch($item) {
	case "xmlrpcapi":
		showXmlrpcapi();
		return;
	case "xmlrpcexample":
		showXmlrpcExample();
		return;
	default:
		if(! empty($item)) {
			showDatabaseDoc($item);
			return;
		}
	}

	$query = "SELECT name, title FROM documentation ORDER BY title";
	$qh = doQuery($query, 101);
	$docs = array();
	while($row = mysql_fetch_assoc($qh))
		$docs[$row['name']] = $row['title'];

	if($viewmode == ADMIN_DEVELOPER || in_array($user['id'], $doceditors)) {
		$cdata = array('submode' => 'newpage');
		$cont = addContinuationsEntry('editdoc', $cdata);
		print "[ <a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "New page</a> ";
		print "]<br>\n";
	}
	if(count($docs)) {
		print "<h2>Main Documentation</h2>\n";
		foreach($docs as $key => $val) {
			print "<a href=\"" . BASEURL . SCRIPT . "?mode=viewdocs&item=$key\">";
			print "$val</a><br>\n";
		}
	}
	if(in_array($user['id'], $docreaders)) {
		print "<h2>API Documentation</h2>\n";
		print "<a href=\"" . BASEURL . SCRIPT . "?mode=viewdocs&item=xmlrpcapi\">";
		print "XML RPC API</a><br>\n";
		print "<a href=\"" . BASEURL . SCRIPT . "?mode=viewdocs&item=xmlrpcexample\">";
		print "XML RPC API Example Code</a><br>\n";
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn showXmlrpcapi()
///
/// \brief prints XML RPC API docs
///
////////////////////////////////////////////////////////////////////////////////
function showXmlrpcapi() {
	$text = file_get_contents(".ht-inc/xmlrpcdocs/xmlrpcWrappers_8php.html");
	$text = preg_replace('/xmlrpcWrappers_8php.html/', '', $text);
	$replace = BASEURL . SCRIPT . "?mode=viewdocs&item=xmlrpcexample";
	$text = preg_replace('/xmlrpc__example_8php-example.html/', $replace, $text);
	$text = preg_replace('~^<\!DOCTYPE.*</head><body>~s', '', $text);
	$text = preg_replace('~<h1>/afs.*</h1>~', '', $text);
	$text = preg_replace('~</body>\n</html>$~', '', $text);
	print $text;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn showXmlrpcExample()
///
/// \brief prints XML RPC API example
///
////////////////////////////////////////////////////////////////////////////////
function showXmlrpcExample() {
	$text = file_get_contents(".ht-inc/xmlrpcdocs/xmlrpc__example_8php-example.html");
	$replace = BASEURL . SCRIPT . "?mode=viewdocs&item=xmlrpcapi";
	$text = preg_replace('/xmlrpcWrappers_8php.html/', $replace, $text);
	$text = preg_replace('~^<\!DOCTYPE.*</head><body>~s', '', $text);
	$text = preg_replace('~<h1>xmlrpc_example\.php</h1>~', '', $text);
	$text = preg_replace('~</body>\n</html>$~', '', $text);
	print $text;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn showDatabaseDoc($item)
///
/// \param $item - name of a documentation item
///
/// \brief prints out documentation for $item
///
////////////////////////////////////////////////////////////////////////////////
function showDatabaseDoc($item) {
	global $viewmode, $user;
	$query = "SELECT title, data FROM documentation WHERE name = '$item'";
	$qh = doQuery($query, 101);
	if(! ($row = mysql_fetch_assoc($qh))) {
		print "<h2>Online Documentation</h2>\n";
		print "Failed to retrieve documentation for \"$item\".<br>\n";
		return;
	}
	if($viewmode == ADMIN_DEVELOPER || in_array($user['id'], $doceditors)) {
		$cdata = array('item' => $item,
		               'submode' => 'newpage');
		$cont = addContinuationsEntry('editdoc', $cdata);
		print "[ <a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "New page</a> ";
		$cdata = array('item' => $item,
		               'submode' => 'editpage');
		$cont = addContinuationsEntry('editdoc', $cdata);
		print "| <a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "Edit page</a> ";
		$cdata = array('item' => $item);
		$cont = addContinuationsEntry('confirmdeletedoc', $cdata);
		print "| <a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
		print "Delete page</a> ";
		print "]<br>\n";
	}
	print "<div class=vcldocpage>\n";
	print "<h2>{$row['title']}</h2>\n";
	print $row['data'];
	print "</div\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn editDoc()
///
/// \brief prints a page for editing a documentation item
///
////////////////////////////////////////////////////////////////////////////////
function editDoc() {
	global $viewmode, $user;
	$item = getContinuationVar('item');
	if($viewmode != ADMIN_DEVELOPER && ! in_array($user['id'], $doceditors)) {
		showDatabaseDoc($item);
		return;
	}
	$submode = getContinuationVar('submode');
	if($submode == 'editfurther' || $submode == 'titleerror') {
		$row['title'] = getContinuationVar('title');
		$row['data'] = rawurldecode(getContinuationVar('data'));
		$newedit = getContinuationVar('newedit');
	}
	elseif($submode == 'editpage') {
		$query = "SELECT title, data FROM documentation WHERE name = '$item'";
		$qh = doQuery($query, 101);
		if(! ($row = mysql_fetch_assoc($qh))) {
			print "<h2>Online Documentation</h2>\n";
			print "Failed to retrieve documentation for \"$item\".<br>\n";
			return;
		}
		$newedit = 'edit';
	}
	else {
		$row['title'] = "";
		$row['data'] = "";
		$newedit = 'new';
	}
	print "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	print "<INPUT type=submit value=\"Confirm Changes\"><br><br>\n";
	print "<big>Title</big>:<INPUT type=text name=title value=\"{$row['title']}\">";
	if($submode == 'titleerror') {
		print "<font color=red>Title cannot be empty</font>";
	}
	print "<br>\n";
	$edit = new FCKeditor('data');
	$edit->BasePath = BASEURL . '/fckeditor/';
	$edit->Value = $row['data'];
	$edit->Height = '600';
	$edit->ToolbarSet = 'VCLDocs';
	$edit->Create();
	$cdata = array('item' => $item,
	               'newedit' => $newedit);
	$cont = addContinuationsEntry('confirmeditdoc', $cdata);
	print "<INPUT type=hidden name=continuation value=\"$cont\">\n";
	print "<INPUT type=submit value=\"Confirm Changes\">\n";
	print "</FORM>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmEditDoc()
///
/// \brief prints a page asking the user to confirm the changes to the page; 
/// includes a link to go back and edit further
///
////////////////////////////////////////////////////////////////////////////////
function confirmEditDoc() {
	global $viewmode, $mysql_link_vcl, $contdata;
	$item = getContinuationVar('item');
	$newedit = getContinuationVar('newedit');
	if($viewmode != ADMIN_DEVELOPER && ! in_array($user['id'], $doceditors)) {
		showDatabaseDoc($item);
		return;
	}
	$title = processInputVar('title', ARG_STRING);
	if(get_magic_quotes_gpc()) {
		$data = stripslashes($_POST['data']);
		$submitdata = rawurlencode(mysql_real_escape_string($data, $mysql_link_vcl));
	}
	else {
		$submitdata = rawurlencode(mysql_real_escape_string($_POST['data'], $mysql_link_vcl));
		$data = $_POST['data'];
	}
	if(empty($title)) {
		$contdata['title'] = "";
		$contdata['data'] = rawurlencode($data);
		$contdata['submode'] = 'titleerror';
		editDoc();
		return;
	}
	$cdata = array('item' => $item,
	               'title' => $title,
	               'data' => $submitdata,
	               'newedit' => $newedit);
	$cont = addContinuationsEntry('submiteditdoc', $cdata, SECINDAY, 0, 0);
	print "[ <a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
	print "Save Changes</a> ";
	$cdata['data'] = rawurlencode($data);
	$cdata['submode'] = 'editfurther';
	$cont = addContinuationsEntry('editdoc', $cdata, SECINDAY, 0, 0);
	print "| <a href=\"" . BASEURL . SCRIPT . "?continuation=$cont\">";
	print "Edit Further</a> ]<br>\n";

	print "<h2>$title</h2>\n";
	print $data;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitEditDoc()
///
/// \brief saves submitted changes to a documentation item
///
////////////////////////////////////////////////////////////////////////////////
function submitEditDoc() {
	global $viewmode, $mysql_link_vcl;
	$item = getContinuationVar('item');
	$newedit = getContinuationVar('newedit');
	if($viewmode != ADMIN_DEVELOPER && ! in_array($user['id'], $doceditors)) {
		showDatabaseDoc($item);
		return;
	}
	$title = getContinuationVar('title');
	$data = rawurldecode(getContinuationVar('data'));
	$name = ereg_replace('[^-A-Za-z0-9_]', '', $title);
	$query = "SELECT name FROM documentation WHERE name = '$name'";
	$qh = doQuery($query, 101);
	$count = 1;
	$basename = $name;
	while(mysql_num_rows($qh)) {
		$name = $basename . $count;
		$count++;
		$query = "SELECT name FROM documentation WHERE name = '$name'";
		$qh = doQuery($query, 101);
	}
	if($newedit == 'edit') {
		$query = "SELECT name FROM documentation WHERE name = '$item'";
		$qh = doQuery($query, 101);
		if(! ($row = mysql_fetch_assoc($qh))) {
			print "<h2>Online Documentation</h2>\n";
			print "Failed to retrieve documentation for \"$item\".<br>\n";
			return;
		}
		$query = "UPDATE documentation "
		       . "SET name = '$name', "
		       .     "title = '$title', "
		       .     "data = '$data' "
		       . "WHERE name = '$item'";
	}
	else {
		$query = "INSERT INTO documentation "
		       .        "(name, "
		       .        "title, "
		       .        "data) "
		       . "VALUES "
		       .        "('$name', "
		       .        "'$title', "
		       .        "'$data')";
	}
	doQuery($query, 101);
	if(mysql_affected_rows($mysql_link_vcl)) {
		print "Page successfully updated.<br>\n";
	}
	else
		print "No changes were made to the page.<br>\n";
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn confirmDeleteDoc()
///
/// \brief prints a confirmation page about deleting a documentation item
///
////////////////////////////////////////////////////////////////////////////////
function confirmDeleteDoc() {
	global $viewmode;
	$item = getContinuationVar('item');
	if($viewmode != ADMIN_DEVELOPER && ! in_array($user['id'], $doceditors)) {
		showDatabaseDoc($item);
		return;
	}
	$query = "SELECT title, data FROM documentation WHERE name = '$item'";
	$qh = doQuery($query, 101);
	if(! ($row = mysql_fetch_assoc($qh))) {
		print "<h2>Online Documentation</h2>\n";
		print "Failed to retrieve documentation for \"$item\".<br>\n";
		return;
	}
	print "Are you sure you want to delete the following documentation ";
	print "page?<br>\n";
	print "<font color=red>Note: the document will be unrecoverable</font>";
	print "<br>\n";
	print "<table>\n";
	print "<tr><td>\n";
	print "<form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cdata = array('item' => $item);
	$cont = addContinuationsEntry('submitdeletedoc', $cdata, SECINDAY, 0, 0);
	print "<input type=hidden name=continuation value=$cont>\n";
	print "<input type=submit value=\"Delete Page\">\n";
	print "</form>\n";
	print "</td><td>\n";
	print "<form action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
	$cont = addContinuationsEntry('viewdocs', $cdata);
	print "<input type=hidden name=continuation value=$cont>\n";
	print "<input type=submit value=\"View Page\">\n";
	print "</form>\n";
	print "</td></tr>\n";
	print "</table>\n";
	print "<h2>{$row['title']}</h2>\n";
	print $row['data'];
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn submitDeleteDoc()
///
/// \brief deletes a documentation item
///
////////////////////////////////////////////////////////////////////////////////
function submitDeleteDoc() {
	global $viewmode;
	$item = getContinuationVar('item');
	if($viewmode != ADMIN_DEVELOPER && ! in_array($user['id'], $doceditors)) {
		showDatabaseDoc($item);
		return;
	}
	$query = "SELECT title FROM documentation WHERE name = '$item'";
	$qh = doQuery($query, 101);
	if(! ($row = mysql_fetch_assoc($qh))) {
		print "<h2>Online Documentation</h2>\n";
		print "Failed to retrieve documentation for \"$item\".<br>\n";
		return;
	}
	$query = "DELETE FROM documentation WHERE name = '$item'";
	doQuery($query, 101);
	print "The page titled <strong>{$row['title']}</strong> has been deleted.";
	print "<br>\n";
}
?>
