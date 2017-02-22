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
/// \fn resource($type)
///
/// \param $type - type of resource
///
/// \brief wrapper to create appropriate object and call selectionText for that
/// object
///
////////////////////////////////////////////////////////////////////////////////
function resource($type) {
	switch($type) {
		case 'config':
			$obj = new Config();
			break;
		case 'image':
			$obj = new Image();
			break;
		case 'computer':
			$obj = new Computer();
			break;
		case 'managementnode':
			$obj = new ManagementNode();
			break;
		case 'schedule':
			$obj = new Schedule();
			break;
		case 'addomain':
			$obj = new ADdomain();
			break;
	}

	$html = $obj->selectionText();
	print $html;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \class Resource
///
/// \brief base class for all resources; provides functionality useful to all
/// types of resources
///
////////////////////////////////////////////////////////////////////////////////
class Resource {
	var $restype;
	var $restypename;
	var $hasmapping;
	var $maptype;
	var $maptypename;
	var $basecdata;
	var $defaultGetDataArgs;
	var $deletable;
	var $deletetoggled;
	var $errmsg;
	var $namefield;
	var $addable;
	var $jsondata;

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn __construct()
	///
	/// \brief class construstor
	///
	/////////////////////////////////////////////////////////////////////////////
	function __construct() {
		# defines if resource type is mapped to another type
		$this->hasmapping = 0;
		# type of resource this resource maps to
		$this->maptype = '';
		# display name for $this->maptype
		$this->maptypename = '';
		# can this resource type be deleted
		$this->deletable = 1;
		# can this resource type be flagged as deleted
		$this->deletetoggled = 1;
		# array of arguments and default values that should be passed to getData function
		$this->defaultGetDataArgs = array();
		# base data for continuations
		$this->basecdata = array('obj' => $this);
		# field in database table used for the name of this resource type
		$this->namefield = 'name';
		# can this resource have new resources directly added
		$this->addable = 1;
		# base data for sending JSON response to AJAX call; this allows an
		#   inheriting function to set some additional data before calling base
		#   function
		$this->jsondata = array();
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn getData($args)
	///
	/// \param $args - array of arguments that determine what data gets returned
	///
	/// \return empty array
	///
	/// \brief stub function; each inheriting class should implement this
	/// function
	///
	/////////////////////////////////////////////////////////////////////////////
	function getData($args) {
		return array();
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn selectionText()
	///
	/// \brief generates HTML to select what management function to perform
	///
	/////////////////////////////////////////////////////////////////////////////
	function selectionText() {
		global $user;
		# get a count of resources user can administer
		$tmp = getUserResources(array("{$this->restype}Admin"), array("administer"));
		$resAdminCnt = count($tmp[$this->restype]);

		# get a count of resources user has access to
		$tmp = getUserResources(array("{$this->restype}Admin"), array("available"));
		$resCnt = count($tmp[$this->restype]);

		# get a count of resource groups user can manage
		$tmp = getUserResources(array("{$this->restype}Admin"), array("manageGroup"), 1);
		$resGroupCnt = count($tmp[$this->restype]);

		if($this->hasmapping) {
			# get a count of $restype groups and $maptype groups user can map
			$tmp = getUserResources(array("{$this->restype}Admin"), array("manageMapping"), 1);
			$resMapCnt = count($tmp[$this->restype]);
			$tmp = getUserResources(array("{$this->maptype}Admin"), array("manageMapping"), 1);
			$maptypeMapCnt = count($tmp[$this->maptype]);
		}
		else {
			$resMapCnt = 0;
			$maptypeMapCnt = 0;
		}

		$h = '';

		$h .= "<H2>" . i("Manage {$this->restypename}s") . "</H2>\n";
		$h .= "<FORM action=\"" . BASEURL . SCRIPT . "\" method=post>\n";
		$showsubmit = 0;
		if(in_array("{$this->restype}Admin", $user["privileges"]) &&
		   ($this->addable == 1 || $resAdminCnt)) {
			$cont = addContinuationsEntry("viewResources", $this->basecdata);
			$h .= "<INPUT type=radio name=continuation value=\"$cont\" checked ";
			$h .= "id=\"{$this->restype}edit\"><label for=\"{$this->restype}edit\">";
			$h .= i("Edit {$this->restypename} Profiles") . "</label><br>\n";
			$showsubmit = 1;
		}

		if(($resAdminCnt && $resGroupCnt) || ($resMapCnt && $maptypeMapCnt)) {
			if($this->hasmapping)
				$label = i("Edit Grouping &amp; Mapping");
			else
				$label = i("Edit Grouping");
			$cont = addContinuationsEntry("groupMapHTML", $this->basecdata);
			$h .= "<INPUT type=radio name=continuation value=\"$cont\" id=\"";
			$h .= "resgroupmap\"><label for=\"resgroupmap\">$label</label><br>\n";
			$showsubmit = 1;
		}

		if($resAdminCnt)
			$h .= $this->extraSelectAdminOptions();

		if($showsubmit)
			$h .= "<br><INPUT type=submit value=" . i("Submit") . ">\n";
		else
			$h .= i("You don't have access to manage any {$this->restype}s.") . "<br>\n";
		$h .= "</FORM>\n";

		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn viewResources()
	///
	/// \brief prints a page to view resource information
	///
	/////////////////////////////////////////////////////////////////////////////
	function viewResources() {
		global $user, $mode;
		$h = '';
		$h .= "<h2>" . i("{$this->restypename} Profiles") . "</h2>\n";

		$resdata = $this->getData($this->defaultGetDataArgs);
		if(! empty($resdata)) {
			$tmp = array_keys($resdata);
			$testid = $tmp[0];
			$fields = array_keys($resdata[$testid]);
		}

		# hidden elements
		$cdata = $this->basecdata;
		$cdata['add'] = 1;
		$cont = addContinuationsEntry('AJsaveResource', $cdata);
		$h .= "<input type=\"hidden\" id=\"addresourcecont\" value=\"$cont\">\n";
		if(! empty($resdata)) {
			$h .= "<input type=\"hidden\" id=\"saveresourcecont\">\n";
			$cont = addContinuationsEntry('AJeditResource', $this->basecdata);
			$h .= "<input type=\"hidden\" id=\"editresourcecont\" value=\"$cont\">\n";
			if($this->deletable) {
				$cont = addContinuationsEntry('AJpromptToggleDeleteResource', $this->basecdata);
				$h .= "<input type=\"hidden\" id=\"deleteresourcecont\" value=\"$cont\">\n";
			}
			$cont = addContinuationsEntry('jsonResourceStore', $this->basecdata);
			$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" url=\"" . BASEURL;
			$h .= SCRIPT . "?continuation=$cont\" jsid=\"resourcestore\" ";
			$h .= "comparatorMap=\"\{\}\"></div>\n";
			/*$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\"\n";
			$h .= "data=\"{'identifier':'id', 'label':'name', 'items':[]}\" \n";
			$h .= "jsid=\"affiliationstore\"></div>\n";
			$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\"\n";
			$h .= "data=\"{'identifier':'id', 'label':'name', 'items':[]}\" \n";
			$h .= "jsid=\"ownerstore\"></div>\n";
			$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\"\n";
			$h .= "data=\"{'identifier':'id', 'label':'name', 'items':[]}\" \n";
			$h .= "jsid=\"editgroupstore\"></div>\n";*/
		}

		if($this->addable)
			$h .= dijitButton('', i("Add New {$this->restypename}"), "addNewResource('" . i("Add {$this->restypename}") . "');");

		if(empty($resdata)) {
			$h .= "<br><br>(" . i("No {$this->restypename}s found to which you have access.") . ")\n";
			$cont = addContinuationsEntry("viewResources", $this->basecdata);
			$url = BASEURL . SCRIPT . "?continuation=$cont";
			$h .= "<input type=\"hidden\" id=\"reloadpageurl\" value=\"$url\">\n";
		}

		$h .= $this->addEditDialogHTML(0);

		if(empty($resdata)) {
			print $h;
			return;
		}

		$selfields = array();
		if(array_key_exists("{$this->restype}selfields", $_COOKIE)) {
			$tmp = explode('|', $_COOKIE["{$this->restype}selfields"]);
			foreach($tmp as $pair) {
				$pair = explode(':', $pair);
				if(count($pair) != 2)
					continue;
				$field = $pair[0];
				$val = $pair[1];
				if(preg_match('/^[a-zA-Z0-9]+$/', $field) && ($val == 0 || $val == 1))
					$selfields[$field] = $val;
			}
		}

		# filters
		$h .= "<div dojoType=\"dijit.TitlePane\" title=\"" . i("Filters (click to expand)") . "\" ";
		$h .= "open=\"false\">\n";
		$h .= "<span id=\"namefilter\">\n";
		$h .= "<strong>" . i("Name") . "</strong>:\n";
		$h .= "<div dojoType=\"dijit.form.TextBox\" id=\"namefilter\" length=\"80\">";
		$h .= "  <script type=\"dojo/connect\" event=\"onKeyUp\" args=\"event\">\n";
		$h .= "    if(event.keyCode == 13) resource.GridFilter();\n";
		$h .= "  </script>\n";
		$h .= "</div>\n";

		$h .= dijitButton('', i("Apply Name Filter"), "resource.GridFilter();");
		$h .= "<br>\n";

		$h .= "</span>\n"; # namefilter
		$h .= "<strong>" . i("Displayed Fields") . "</strong>:<br>\n";
		$h .= $this->addDisplayCheckboxes($fields, $resdata[$testid], $selfields);
		if($this->deletetoggled) {
			$h .= "<label for=\"showdeleted\"><strong>";
			$h .= i("Include Deleted {$this->restypename}s:");
			$h .= "</strong></label>\n";
			$h .= "<input type=\"checkbox\" dojoType=\"dijit.form.CheckBox\" ";
			$h .= "id=\"showdeleted\" onChange=\"resource.GridFilter();\">\n";
		}
		$h .= "</div>\n";

		$h .= $this->extraResourceFilters();

		$h .= "<div id=\"gridcontainer\">\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"resourcegrid\" ";
		$h .= "sortInfo=3 store=\"resourcestore\" autoWidth=\"true\" style=\"";
		if($this->deletetoggled)
			$h .= "height: 580px;\" query=\"{deleted: '0'}\">\n";
		else
			$h .= "height: 580px;\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		if(preg_match('/MSIE/i', $_SERVER['HTTP_USER_AGENT']) ||
		   preg_match('/Trident/i', $_SERVER['HTTP_USER_AGENT']) ||
		   preg_match('/Edge/i', $_SERVER['HTTP_USER_AGENT']))
			$w = array('64px', '43px', '200px');
		else
			$w = array('5em', '3.5em', '17em');
		$h .= "<th field=\"id\" id=\"delcolth\" width=\"{$w[0]}\" formatter=\"resource.DeleteBtn\" styles=\"text-align: center;\">&nbsp;</th>\n";
		$h .= "<th field=\"id\" width=\"{$w[1]}\" formatter=\"resource.EditBtn\" styles=\"text-align: center;\">&nbsp;</th>\n";
		$h .= "<th field=\"name\" width=\"{$w[2]}\">" . i("Name") . "</th>\n";
		if(! array_key_exists('owner', $selfields))
			$selfields['owner'] = 1;
		foreach($fields as $field)
			$names[$field] = $this->fieldDisplayName($field);
		uasort($names, 'sortKeepIndex');
		foreach($names as $field => $name) {
			if($field == $this->namefield ||
			   $field == 'name' ||
			   is_array($resdata[$testid][$field]) ||
			   preg_match('/id$/', $field))
				continue;
			$w = $this->fieldWidth($field);
			if(array_key_exists($field, $selfields) && $selfields[$field])
				$h .= "<th field=\"$field\" $w formatter=\"resource.colformatter\">";
			else
				$h .= "<th field=\"$field\" $w hidden=\"true\" formatter=\"resource.colformatter\">";
			$h .= "$name</th>\n";
		}
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</div>\n";

		if($this->deletable) {
			# toggle delete dialog
			$h .= "<div id=\"toggleDeleteDialog\" dojoType=\"dijit.Dialog\">\n";
			$h .= "<h2 id=\"toggleDeleteHeading\"></h2>\n";
			$h .= "<span id=\"toggleDeleteQuestion\"></span><br>\n";
			$h .= "<div id=\"confdelrescontent\"></div>\n";
			$h .= dijitButton('toggleDeleteBtn', i("Delete {$this->restypename}"), "submitToggleDeleteResource();");
			$h .= dijitButton('', i("Cancel"), "clearHideConfirmDelete();");
			$h .= "<input type=hidden id=\"submitdeletecont\">\n";
			$h .= "</div>\n";
		}

		print $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addDisplayCheckboxes($allfields, $sample, $selfields)
	///
	/// \param $allfields - array of fields for which to generate checkboxes
	/// \param $sample - sample data item that is used to determine what fields
	/// to use for generating checkboxes
	/// \param $selfields - array of fields that should be selected
	///
	/// \return html
	///
	/// \brief generates checkboxes to be used as filters on the viewResources
	/// page
	///
	/////////////////////////////////////////////////////////////////////////////
	function addDisplayCheckboxes($allfields, $sample, $selfields) {
		$fields = array('owner');
		$names = array('owner' => $this->fieldDisplayName('owner'));
		foreach($allfields as $field) {
			if($field == $this->namefield ||
			   $field == 'name' ||
			   $field == 'owner' ||
			   is_array($sample[$field]) ||
			   preg_match('/id$/', $field))
				continue;
			$fields[] = $field;
			$names[$field] = $this->fieldDisplayName($field);
		}
		uasort($names, 'sortKeepIndex');
		$h = '';
		$fieldcnt = count($fields);
		$cols = $fieldcnt / 4;
		if($cols > 4)
			$cols = 4;
		if($fieldcnt < 6) {
			foreach($names as $field => $name) {
				if($field == 'owner' && (! array_key_exists('owner', $selfields) || $selfields['owner']))
					$h .= "<input type=checkbox id=chk$field checked onClick=\"resource.toggleResFieldDisplay(this, '$field')\">";
				elseif($field == 'name' || (array_key_exists($field, $selfields) && $selfields[$field]))
					$h .= "<input type=checkbox id=chk$field checked onClick=\"resource.toggleResFieldDisplay(this, '$field')\">";
				else
					$h .= "<input type=checkbox id=chk$field onClick=\"resource.toggleResFieldDisplay(this, '$field')\">";
				$h .= "<label for=chk$field>$name</label><br>\n";
			}
		}
		else {
			$h .= "<table>\n";
			$cnt = 0;
			foreach($names as $field => $name) {
				$mod = $cols;
				if($cnt % $mod == 0)
					$h .= "<tr>\n";
				if($field == 'owner' && (! array_key_exists('owner', $selfields) || $selfields['owner']))
					$h .= "  <td><input type=checkbox id=chk$field checked onClick=\"resource.toggleResFieldDisplay(this, '$field')\">";
				elseif($field == 'name' || (array_key_exists($field, $selfields) && $selfields[$field]))
					$h .= "  <td><input type=checkbox id=chk$field checked onClick=\"resource.toggleResFieldDisplay(this, '$field')\">";
				else
					$h .= "  <td><input type=checkbox id=chk$field onClick=\"resource.toggleResFieldDisplay(this, '$field')\">";
				$h .= "<label for=chk$field>$name</label><br></td>\n";
				$cnt++;
				if($cnt % $mod == 0)
					$h .= "</tr>\n";
			}
			if($cnt % $mod != 0)
				$h .= "</tr>\n";
			$h .= "</table>\n";
		}
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn fieldWidth($field)
	///
	/// \param $field - name of a resource field
	///
	/// \return string for setting width of field (includes width= part)
	///
	/// \brief generates the required width for the field; can return an empty
	/// string if field should default to auto width
	///
	/////////////////////////////////////////////////////////////////////////////
	function fieldWidth($field) {
		switch($field) {
			case 'owner':
				$w = 12;
				break;
			default:
				return '';
		}
		if(preg_match('/MSIE/i', $_SERVER['HTTP_USER_AGENT']) ||
		   preg_match('/Trident/i', $_SERVER['HTTP_USER_AGENT']) ||
		   preg_match('/Edge/i', $_SERVER['HTTP_USER_AGENT']))
			$w = round($w * 11.5) . 'px';
		else
			$w = "{$w}em";
		return "width=\"$w\"";
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn fieldDisplayName($field)
	///
	/// \param $field - name of a resource field
	///
	/// \return display value for $field
	///
	/// \brief generates the display value for $field; this base function just
	/// uppercases the first letter; each inheriting class should create its own
	/// function
	///
	/////////////////////////////////////////////////////////////////////////////
	function fieldDisplayName($field) {
		return ucfirst($field);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn extraResourceFilters()
	///
	/// \return empty string
	///
	/// \brief base function; allows inheriting classes to generate additional
	/// filters to be displayed on the viewResources page
	///
	/////////////////////////////////////////////////////////////////////////////
	function extraResourceFilters() {
		return '';
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn jsonResourceStore()
	///
	/// \brief generates and sends a JSON formatted store of resource data
	///
	/////////////////////////////////////////////////////////////////////////////
	function jsonResourceStore() {
		global $user;
		$args = $this->defaultGetDataArgs;
		$args['includedeleted'] = 1;
		$resdata = $this->getData($args);
		$resources = getUserResources(array($this->restype . "Admin"), array("administer"), 0, 1);
		foreach($resources as $type => $tmp) {
			if($type != $this->restype)
				unset($resources[$type]);
		}


		// this method may include fields for some records but not others
		/*$items = array();
		foreach($resdata as $id => $res) {
			if(! array_key_exists($id, $resources[$this->restype]))
				continue;
			$g = array('id' => $id);
			$g['name'] = $res[$this->namefield];
			$g['owner'] = $res['owner'];
			foreach($res as $key => $val) {
				if($key == 'name' ||
				   $key == 'owner' ||
				   $key == $this->namefield ||
				   is_array($val) ||
				   preg_match('/id$/', $key))
					continue;
				$g[$key] = $val;
			}
			$items[] = $g;
		}
		return $items;*/



		// this method only includes keys that exist in the first element
		reset($resdata);
		$id = key($resdata);
		$fields = array_keys($resdata[$id]);
		$items = array();
		foreach($resdata as $id => $res) {
			if(! array_key_exists($id, $resources[$this->restype]))
				continue;
			$item = array('id' => $id);
			$item['name'] = $res[$this->namefield];
			$item['owner'] = $res['owner'];
			foreach($fields as $field) {
				if($field == 'name' ||
				   $field == 'owner' ||
				   $field == $this->namefield ||
				   ! array_key_exists($field, $res) ||
				   is_array($res[$field]) ||
				   preg_match('/id$/', $field))
					continue;
				$item[$field] = $res[$field];
			}
			$items[] = $item;
			unset($resdata[$id]);
		}
		sendJSON($items, 'id');
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn toggleDeleteResource($rscid)
	///
	/// \param $rscid - id of a resource (from table specific to that resource,
	/// not from the resource table)
	///
	/// \return 1 on success, 0 on failure
	///
	/// \brief if resource type allows resources to be flagged as deleted;
	/// toggles the deleted flag; otherwise deletes the entry from that resources
	/// table and the general resource table
	///
	/////////////////////////////////////////////////////////////////////////////
	function toggleDeleteResource($rscid) {
		if($this->deletetoggled) {
			$query = "SELECT deleted "
			       . "FROM `{$this->restype}` "
			       . "WHERE id = $rscid";
			$qh = doQuery($query);
			if($row = mysql_fetch_assoc($qh)) {
				$newval = (int)(! (int)$row['deleted']);
				$query = "UPDATE {$this->restype} "
				       . "SET deleted = $newval "
				       . "WHERE id = $rscid";
				doQuery($query);
				$this->submitToggleDeleteResourceExtra($rscid, $row['deleted']);
			}
			else
				return 0;
		}
		else {
			$this->submitToggleDeleteResourceExtra($rscid);

			$query = "DELETE r "
			       . "FROM resource r, "
			       .      "resourcetype rt "
			       . "WHERE r.resourcetypeid = rt.id AND "
			       .       "rt.name = '{$this->restype}' AND "
			       .       "r.subid = $rscid";
			doQuery($query);
			$query = "DELETE FROM `{$this->restype}` "
			       . "WHERE id = $rscid";
			doQuery($query);
		}

		# clear user resource cache for this type
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array($this->restype . "Admin"), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);

		return 1;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJpromptToggleDeleteResource()
	///
	/// \brief generates and sends content prompting user to confirm deletion of
	/// resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJpromptToggleDeleteResource() {
		$rscid = processInputVar('rscid', ARG_NUMERIC);
		# check access to $rscid
		$resources = getUserResources(array("{$this->restype}Admin"), array("administer"), 0, 1);
		if(! array_key_exists($rscid, $resources[$this->restype])) {
			$type = strtolower($this->restypename);
			$rt = array('status' => 'noaccess',
			            'msg' => i("You do not have access to delete the selected $type."),
			            'rscid' => $rscid);
			sendJSON($rt);
			return;
		}
		# check usage of resource
		$msg = $this->checkResourceInUse($rscid);
		if($msg != '') {
			$rt = array('status' => 'inuse',
			            'msg' => $msg,
			            'rscid' => $rscid);
			sendJSON($rt);
			return;
		}
		$rt = array('title' => i("Confirm Delete {$this->restypename}"),
		            'question' => i("Delete the following {$this->restype}?"),
		            'btntxt' => i("Delete {$this->restypename}"),
		            'status' => 'success');
		$args = $this->defaultGetDataArgs;
		if($this->deletetoggled)
			$args['includedeleted'] = 1;
		$args['rscid'] = $rscid;
		$resdata = $this->getData($args);
		if($this->deletetoggled && $resdata[$rscid]['deleted']) {
			$rt['title'] = i("Confirm Undelete {$this->restypename}");
			$rt['question'] = i("Undelete the following {$this->restype}?");
			$rt['btntxt'] = i("Undelete {$this->restypename}");
		}
		$fields = array_keys($resdata[$rscid]);
		$rt['fields'] = array();
		$rt['fields'][] = array('field' => 'name',
		                        'name' => i('Name'),
		                        'value' => $resdata[$rscid][$this->namefield]);
		$rt['fields'][] = array('field' => 'owner',
		                        'name' => i('Owner'),
		                        'value' => $resdata[$rscid]['owner']);
		foreach($fields as $field) {
			if($field == $this->namefield ||
			   $field == 'name' ||
			   $field == 'owner' ||
			   is_array($resdata[$rscid][$field]) ||
			   preg_match('/id$/', $field))
				continue;
			$rt['fields'][] = array('field' => $field,
			                        'name' => $this->fieldDisplayName($field),
			                        'value' => $resdata[$rscid][$field]);
		}
		$rt['html'] = $this->toggleDeleteResourceExtra();

		$cdata = getContinuationVar();
		$cdata['rscid'] = $rscid;
		$cont = addContinuationsEntry('AJsubmitToggleDeleteResource', $cdata);
		$rt['cont'] = $cont;
		sendJSON($rt);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn toggleDeleteResourceExtra()
	///
	/// \return empty string
	///
	/// \brief allows inheriting class to generate additional information to be
	/// included on the confirm toggle delete resource page
	///
	/////////////////////////////////////////////////////////////////////////////
	function toggleDeleteResourceExtra() {
		return '';
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsubmitToggleDeleteResource()
	///
	/// \brief AJAX callable wrapper for toggleDeleteResource
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsubmitToggleDeleteResource() {
		$rscid = getContinuationVar('rscid');
		if($this->toggleDeleteResource($rscid))
			$rt = array('status' => 'success', 'rscid' => $rscid);
		else
			$rt = array('status' => 'failed', 'rscid' => $rscid);
		sendJSON($rt);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn submitToggleDeleteResourceExtra($rscid, $deleted)
	///
	/// \param $rscid - id of a resource (from table specific to that resource,
	/// not from the resource table)
	/// \param $deleted - (optional, default=0) 1 if resource was previously
	/// deleted; 0 if not
	///
	/// \brief function to do any extra stuff specific to a resource type when
	/// toggling delete for a resource; to be implemented by inheriting class if
	/// needed
	///
	/////////////////////////////////////////////////////////////////////////////
	function submitToggleDeleteResourceExtra($rscid, $deleted=0) {
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn groupMapHTML()
	///
	/// \brief prints HTML for groupping and mapping page
	///
	/////////////////////////////////////////////////////////////////////////////
	function groupMapHTML() {
		$h = '';
		$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"resourcetogroupsstore\" ";
		$h .= "data=\"resourcetogroupsdata\"></div>\n";
		$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"grouptoresourcesstore\" ";
		$h .= "data=\"grouptoresourcesdata\"></div>\n";
		$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"mapbyresgroupstore\" ";
		$h .= "data=\"mapbyresgroupdata\"></div>\n";
		$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" jsId=\"mapbymaptogroupstore\" ";
		$h .= "data=\"mapbymaptogroupdata\"></div>\n";
		$h .= "<div id=\"mainTabContainer\" dojoType=\"dijit.layout.TabContainer\"\n";
		$h .= "     style=\"width:600px;height:600px\">\n";
		$h .= $this->groupByResourceHTML();
		$h .= $this->groupByGroupHTML();
		if($this->hasmapping) {
			$h .= "<input type=\"hidden\" id=\"domapping\" value=\"1\">\n";
			$h .= $this->mapByResGroupHTML();
			$h .= $this->mapByMapToGroupHTML();
		}
		else
			$h .= "<input type=\"hidden\" id=\"domapping\" value=\"0\">\n";
		$h .= "</div>\n";
		print $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn groupByResourceHTML()
	///
	/// \return html
	///
	/// \brief generates HTML for resource grouping by selecting a resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function groupByResourceHTML() {
		# build list of resources
		$tmp = getUserResources(array($this->restype . "Admin"), array('manageGroup'));
		if(empty($tmp[$this->restype]))
			return '';
		$resources = $tmp[$this->restype];
		uasort($resources, 'sortKeepIndex');
		$h = '';
		$h .= "<div id=\"groupbyresourcediv\" dojoType=\"dijit.layout.ContentPane\" ";
		$h .= "title=\"" . i("Group By {$this->restypename}") . "\">\n";
		$h .= "<div id=\"groupbyresourcedesc\">\n";
		$h .= "<div style=\"width: 400px;\">\n";
		$h .= i("Select an item from the drop-down box and click \"Get Groups\" to see all of the groups it is in. Then, select a group it is in and click the Remove button to remove it from that group, or select a group it is not in and click the Add button to add it to that group.");
		$h .= "</div><br>\n";
		$h .= "</div>\n"; # groupbyresourcedesc
		$h .= "<div id=\"groupbyresourcesel\">\n";
		$h .= i($this->restypename) . ":<select id=\"resources\">\n";
		foreach($resources as $id => $res)
			$h .= "<option value=$id>$res</option>\n";
		$h .= "</select>\n";
		$h .= dijitButton('fetchGrpsButton', i("Get Groups"),
			               "populateLists('resources', 'ingroups', 'inresourcename', 'outresourcename', 'resgroupinggroupscont');");
		$h .= "</div>\n"; # groupbyresourcesel
		$h .= "<table><tbody><tr>\n";
		# select for groups resource is in
		$h .= "<td valign=top>\n";
		$h .= sprintf(i("Groups %s is in:"), "<span style=\"font-weight: bold;\" id=\"inresourcename\"></span>");
		$h .= "<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"ingroups\" ";
		$h .= "store=\"resourcetogroupsstore\" style=\"width: 240px; height: 250px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"extended\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"160px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</td>\n";
		# transfer buttons
		$h .= "<td style=\"vertical-align: middle;\">\n";
		$h .= dijitButton('', "<div style=\"width: 60px;\">&lt;-" . i("Add") . "</div>",
		                  "resource.addRemItem('addgrpcont', 'resources', 'outgroups');");
		$cdata = $this->basecdata;
		$cdata['mode'] = 'add';
		$cont = addContinuationsEntry('AJaddRemGroupResource', $cdata);
		$h .= "<input type=\"hidden\" id=\"addgrpcont\" value=\"$cont\">\n";
		$h .= "<br><br><br>\n";
		$h .= dijitButton('', "<div style=\"width: 60px;\">" . i("Remove") . "-&gt;</div>",
		                  "resource.addRemItem('remgrpcont', 'resources', 'ingroups');");
		$cdata['mode'] = 'remove';
		$cont = addContinuationsEntry('AJaddRemGroupResource', $cdata);
		$h .= "<input type=\"hidden\" id=\"remgrpcont\" value=\"$cont\">\n";
		$h .= "</td>\n";
		# select for groups resource is not in
		$h .= "<td valign=top>\n";
		$h .= sprintf(i("Groups %s is not in:"), "<span style=\"font-weight: bold;\" id=\"outresourcename\"></span>");
		$h .= "<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"outgroups\" ";
		$h .= "store=\"resourcetogroupsstore\" style=\"width: 240px; height: 250px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"extended\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"160px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</td>\n";
		$h .= "</tr></tbody></table>\n";
		$cdata = $this->basecdata;
		$cdata['store'] = 'resourcetogroupsstore';
		$cdata['intitle'] = 'ingroups';
		$cdata['outtitle'] = 'outgroups';
		$cont = addContinuationsEntry('jsonResourceGroupingGroups', $cdata);
		$h .= "<input type=hidden id=\"resgroupinggroupscont\" value=\"$cont\">\n";
		$h .= "</div>\n";
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn jsonResourceGroupingGroups()
	///
	/// \brief sends JSON of resource groups for resource grouping by selecting a
	/// resource page
	///
	/////////////////////////////////////////////////////////////////////////////
	function jsonResourceGroupingGroups() {
		$resid = processInputVar('id', ARG_NUMERIC);
		$resources = getUserResources(array($this->restype . "Admin"), array("manageGroup"));
		if(! array_key_exists($resid, $resources[$this->restype])) {
			sendJSON(array('status' => 'noaccess'));
			return;
		}
		$groups = getUserResources(array($this->restype . 'Admin'), array('manageGroup'), 1);
		$memberships = getResourceGroupMemberships($this->restype);
		$all = array();
		foreach($groups[$this->restype] as $id => $group) {
			if(array_key_exists($resid, $memberships[$this->restype]) &&
				in_array($id, $memberships[$this->restype][$resid]))
				$all[] = array('id' => $id, 'name' => $group, 'inout' => 1);
			else
				$all[] = array('id' => $id, 'name' => $group, 'inout' => 0);
		}
		$arr = array('items' => $all,
		             'intitle' => getContinuationVar('intitle'),
		             'outtitle' => getContinuationVar('outtitle'));
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddRemGroupResource()
	///
	/// \brief adds or removes groups for a resource and sends JSON response
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJaddRemGroupResource() {
		$rscid = processInputVar('id', ARG_NUMERIC);
		$resources = getUserResources(array($this->restype . "Admin"), array("manageGroup"));
		if(! array_key_exists($rscid, $resources[$this->restype])) {
			$arr = array('status' => 'noaccess');
			sendJSON($arr);
			return;
		}

		$groups = getUserResources(array($this->restype . "Admin"), array("manageGroup"), 1);
		$tmp = processInputVar('listids', ARG_STRING);
		$tmp = explode(',', $tmp);
		$groupids = array();
		foreach($tmp as $id) {
			if(! is_numeric($id))
				continue;
			if(! array_key_exists($id, $groups[$this->restype])) {
				$arr = array('status' => 'noaccess');
				sendJSON($arr);
				return;
			}
			$groupids[] = $id;
		}

		$mode = getContinuationVar('mode');

		$args = $this->defaultGetDataArgs;
		$args['rscid'] = $rscid;
		$resdata = $this->getData($args);

		if($mode == 'add') {
			$adds = array();
			foreach($groupids as $id)
				$adds[] = "({$resdata[$rscid]['resourceid']}, $id)";
			$query = "INSERT IGNORE INTO resourcegroupmembers "
					 . "(resourceid, resourcegroupid) VALUES ";
			$query .= implode(',', $adds);
			doQuery($query);
		}
		else {
			$rems = implode(',', $groupids);
			$query = "DELETE FROM resourcegroupmembers "
					 . "WHERE resourceid = {$resdata[$rscid]['resourceid']} AND "
					 .       "resourcegroupid IN ($rems)";
			doQuery($query);
		}

		$_SESSION['userresources'] = array();
		$regids = "^" . implode('$|^', $groupids) . "$";
		$arr = array('status' => 'success',
		             'regids' => $regids,
		             'inselobj' => 'ingroups',
		             'outselobj' => 'outgroups');
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn groupByGroupHTML()
	///
	/// \return html
	///
	/// \brief generates HTML for resource grouping by selecting a resource group
	///
	/////////////////////////////////////////////////////////////////////////////
	function groupByGroupHTML() {
		$resources = getUserResources(array($this->restype . 'Admin'), array('manageGroup'));
		if(empty($resources[$this->restype]))
			return '';
		$h = '';
		$h .= "<div id=\"groupbygroupdiv\" dojoType=\"dijit.layout.ContentPane\" ";
		$h .= "title=\"" . i("Group By Group") . "\">\n";
		$h .= "<div style=\"width: 420px;\">\n";
		$h .= i("Select a group from the drop-down box and click \"Get {$this->restypename}s\" to see all of the resources in it. Then, select a resource in it and click the Remove button to remove it from that group, or select a resource that is not in it and click the Add button to add it to that group.");
		$h .= "</div><br>\n";
		$h .= i("Group:") . "<select id=\"resgroups\">\n";
		# build list of groups
		$tmp = getUserResources(array($this->restype . "Admin"), array('manageGroup'), 1);
		$groups = $tmp[$this->restype];
		uasort($groups, 'sortKeepIndex');
		foreach($groups as $id => $group)
			$h .= "<option value=$id>$group</option>\n";
		$h .= "</select>\n";
		$h .= dijitButton('fetchResourcesButton', "Get {$this->restypename}s",
		                  "populateLists('resgroups', 'inresources', 'ingroupname', 'outgroupname', 'resgroupingresourcescont');");
		$h .= "<table><tbody><tr>\n";
		# select for resources in group
		$h .= "<td valign=top>\n";
		$h .= sprintf(i("{$this->restypename}s in %s:"), "<span style=\"font-weight: bold;\" id=\"ingroupname\"></span>");
		$h .= "<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"inresources\" ";
		$h .= "store=\"grouptoresourcesstore\" style=\"width: 240px; height: 250px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"extended\" sortInfo=\"1\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"160px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</td>\n";
		# transfer buttons
		$h .= "<td style=\"vertical-align: middle;\">\n";
		$h .= dijitButton('', "<div style=\"width: 60px;\">&lt;-" . i("Add") . "</div>",
		                  "resource.addRemItem('additemcont', 'resgroups', 'outresources');");
		$cdata = $this->basecdata;
		$cdata['mode'] = 'add';
		$cont = addContinuationsEntry('AJaddRemResourceGroup', $cdata);
		$h .= "<input type=\"hidden\" id=\"additemcont\" value=\"$cont\">\n";
		$h .= "<br><br><br>\n";
		$h .= dijitButton('', "<div style=\"width: 60px;\">" . i("Remove") . "-&gt;</div>",
		                  "resource.addRemItem('remitemcont', 'resgroups', 'inresources');");
		$cdata['mode'] = 'remove';
		$cont = addContinuationsEntry('AJaddRemResourceGroup', $cdata);
		$h .= "<input type=\"hidden\" id=\"remitemcont\" value=\"$cont\">\n";
		$h .= "</td>\n";
		# select for groups resource is not in
		$h .= "<td valign=top>\n";
		$h .= sprintf(i("{$this->restypename}s not in %s:"), "<span style=\"font-weight: bold;\" id=\"outgroupname\"></span>");
		$h .= "<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"outresources\" ";
		$h .= "store=\"grouptoresourcesstore\" style=\"width: 240px; height: 250px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"extended\" sortInfo=\"1\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"160px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</td>\n";
		$h .= "</tr></tbody></table>\n";
		$cdata = $this->basecdata;
		$cdata['store'] = 'grouptoresourcesstore';
		$cdata['intitle'] = 'inresources';
		$cdata['outtitle'] = 'outresources';
		$cont = addContinuationsEntry('jsonResourceGroupingResources', $cdata);
		$h .= "<input type=hidden id=\"resgroupingresourcescont\" value=\"$cont\">\n";
		$h .= "</div>\n";
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn jsonResourceGroupingResources()
	///
	/// \brief sends JSON of resources for resource grouping by selecting a
	/// resource group
	///
	/////////////////////////////////////////////////////////////////////////////
	function jsonResourceGroupingResources() {
		$groupid = processInputVar('id', ARG_NUMERIC);
		$groups = getUserResources(array($this->restype . "Admin"), array("manageGroup"), 1);
		if(! array_key_exists($groupid, $groups[$this->restype])) {
			sendJSON(array('status' => 'noaccess'));
			return;
		}
		$resources = getUserResources(array($this->restype . 'Admin'), array('manageGroup'));
		#uasort($resources[$this->restype], 'sortKeepIndex');
		$memberships = getResourceGroupMemberships($this->restype);
		$all = array();
		foreach($resources[$this->restype] as $id => $res) {
			if(array_key_exists($id, $memberships[$this->restype]) &&
				in_array($groupid, $memberships[$this->restype][$id]))
				$all[] = array('id' => $id, 'name' => $res, 'inout' => 1);
			else
				$all[] = array('id' => $id, 'name' => $res, 'inout' => 0);
		}
		$arr = array('items' => $all,
		             'intitle' => getContinuationVar('intitle'),
		             'outtitle' => getContinuationVar('outtitle'));
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddRemResourceGroup()
	///
	/// \brief adds or removes resources for a resource group and sends JSON
	/// response
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJaddRemResourceGroup() {
		$groupid = processInputVar('id', ARG_NUMERIC);
		$groups = getUserResources(array($this->restype . "Admin"), array("manageGroup"), 1);
		if(! array_key_exists($groupid, $groups[$this->restype])) {
			$arr = array('status' => 'noaccess');
			sendJSON($arr);
			return;
		}

		$resources = getUserResources(array($this->restype . "Admin"), array("manageGroup"));
		$tmp = processInputVar('listids', ARG_STRING);
		$tmp = explode(',', $tmp);
		$rscids = array();
		foreach($tmp as $id) {
			if(! is_numeric($id))
				continue;
			if(! array_key_exists($id, $resources[$this->restype])) {
				$arr = array('status' => 'noaccess');
				sendJSON($arr);
				return;
			}
			$rscids[] = $id;
		}

		$mode = getContinuationVar('mode');

		$resdata = $this->getData($this->defaultGetDataArgs);

		if($mode == 'add') {
			$adds = array();
			foreach($rscids as $id)
				$adds[] = "({$resdata[$id]['resourceid']}, $groupid)";
			$query = "INSERT IGNORE INTO resourcegroupmembers "
					 . "(resourceid, resourcegroupid) VALUES ";
			$query .= implode(',', $adds);
		}
		else {
			$delids = array();
			foreach($rscids as $id)
				$delids[] = $resdata[$id]['resourceid'];
			$inlist = implode(',', $delids);
			$query = "DELETE FROM resourcegroupmembers "
					 . "WHERE resourcegroupid = $groupid AND "
					 .       "resourceid IN ($inlist)";
			doQuery($query);
		}

		doQuery($query);
		$_SESSION['userresources'] = array();
		$regids = "^" . implode('$|^', $rscids) . "$";
		$arr = array('status' => 'success',
		             'regids' => $regids,
		             'inselobj' => 'inresources',
		             'outselobj' => 'outresources');
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function groupByGridHTML() {
		# TODO
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn mapByResGroupHTML()
	///
	/// \return html
	///
	/// \brief generates HTML for resource mapping by selecting a resource group
	/// of this type of resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function mapByResGroupHTML() {
		$tmp = getUserResources(array($this->restype . "Admin"),
		                        array("manageMapping"), 1);
		$groups = $tmp[$this->restype];
		uasort($groups, "sortKeepIndex");
		$tmp = getUserResources(array($this->maptype . "Admin"),
		                        array("manageMapping"), 1);
		$mapgroups = $tmp[$this->maptype];
		uasort($mapgroups, "sortKeepIndex");
		$h = '';

		if(! count($groups) || ! count($mapgroups)) {
			$h .= i("You don't have access to manage any mappings for this resource type.");
			return $h;
		}

		$h .= "<div id=\"mapbyresgroupdiv\" dojoType=\"dijit.layout.ContentPane\" ";
		$h .= "title=\"" . i("Map By {$this->restypename} Group") . "\">\n";
		$h .= "<div style=\"width: 390px;\">\n";
		$h .= i("Select an item from the drop-down box and click \"Get {$this->maptypename} Groups\" to see all of the groups it maps to. Then, select a group it does not map to and click the Add button to map it to that group, or select a group it maps to and click the Remove button to unmap it from that group.");
		$h .= "</div><br>\n";
		$h .= i("{$this->restypename} Group:") . "<select id=\"groups\">\n";
		foreach($groups as $id => $group)
			$h .= "<option value=$id>$group</option>\n";
		$h .= "</select>\n";
		$h .= dijitButton('', i("Get {$this->maptypename} Groups"),
		                  "populateLists('groups', 'inmapgroups', 'inmapgroupname', 'outmapgroupname', 'mapbyresgroupcont');");
		$h .= "<table><tbody><tr>\n";
		# select for groups mapped to
		$h .= "<td valign=top>\n";
		$h .= sprintf(i("{$this->maptypename} Groups %s maps to:"), "<span style=\"font-weight: bold;\" id=\"inmapgroupname\"></span>");
		$h .= "<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"inmapgroups\" ";
		$h .= "store=\"mapbyresgroupstore\" style=\"width: 240px; height: 250px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"extended\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"160px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</td>\n";
		# transfer buttons
		$h .= "<td style=\"vertical-align: middle;\">\n";
		$h .= dijitButton('', "<div style=\"width: 60px;\">&lt;-" . i("Add") . "</div>",
		                  "resource.addRemItem('addmapgrpcont', 'groups', 'outmapgroups');");
		$cdata = $this->basecdata;
		$cdata['mode'] = 'add';
		$cont = addContinuationsEntry('AJaddRemMapToGroup', $cdata);
		$h .= "<input type=\"hidden\" id=\"addmapgrpcont\" value=\"$cont\">\n";
		$h .= "<br>\n";
		$h .= "<br>\n";
		$h .= "<br>\n";
		$h .= dijitButton('', "<div style=\"width: 60px;\">" . i("Remove") . "-&gt;</div>",
		                  "resource.addRemItem('remmapgrpcont', 'groups', 'inmapgroups');");
		$cdata['mode'] = 'remove';
		$cont = addContinuationsEntry('AJaddRemMapToGroup', $cdata);
		$h .= "<input type=\"hidden\" id=\"remmapgrpcont\" value=\"$cont\">\n";
		$h .= "</td>\n";
		# select for groups resource is not in
		$h .= "<td valign=top>\n";
		$h .= sprintf(i("{$this->maptypename} Groups %s does not map to:"), "<span style=\"font-weight: bold;\" id=\"outmapgroupname\"></span>");
		$h .= "<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"outmapgroups\" ";
		$h .= "store=\"mapbyresgroupstore\" style=\"width: 240px; height: 250px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"extended\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"160px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</td>\n";
		$h .= "</tr></tbody></table>\n";
		$cdata = $this->basecdata;
		$cdata['store'] = 'mapbyresgroupstore';
		$cdata['intitle'] = 'inmapgroups';
		$cdata['outtitle'] = 'outmapgroups';
		$cont = addContinuationsEntry('jsonResourceMappingMapToGroups', $cdata);
		$h .= "<input type=hidden id=\"mapbyresgroupcont\" value=\"$cont\">\n";
		$h .= "</div>\n";
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn jsonResourceMappingMapToGroups()
	///
	/// \brief sends JSON of resource groups for resource mapping by selecting a
	/// resource group of this resource type
	///
	/////////////////////////////////////////////////////////////////////////////
	function jsonResourceMappingMapToGroups() {
		$resgrpid = processInputVar('id', ARG_NUMERIC);
		$resources = getUserResources(array($this->restype . "Admin"), array("manageMapping"), 1);
		if(! array_key_exists($resgrpid, $resources[$this->restype])) {
			sendJSON(array('status' => 'noaccess'));
			return;
		}
		$mapgroups = getUserResources(array($this->maptype . 'Admin'), array('manageMapping'), 1);
		$mapping = getResourceMapping($this->restype, $this->maptype);
		$all = array();

		foreach($mapgroups[$this->maptype] as $id => $group) {
			if(array_key_exists($resgrpid, $mapping) &&
				in_array($id, $mapping[$resgrpid]))
				$all[] = array('id' => $id, 'name' => $group, 'inout' => 1);
			else
				$all[] = array('id' => $id, 'name' => $group, 'inout' => 0);
		}
		$arr = array('items' => $all,
		             'intitle' => getContinuationVar('intitle'),
		             'outtitle' => getContinuationVar('outtitle'));
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddRemMapToGroup()
	///
	/// \brief adds or removes groups that map to a group of this resource type
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJaddRemMapToGroup() {
		$groupid = processInputVar('id', ARG_NUMERIC);
		$groups = getUserResources(array($this->restype . "Admin"),
		                           array("manageMapping"), 1);
		if(! array_key_exists($groupid, $groups[$this->restype])) {
			$arr = array('status' => 'noaccess');
			sendJSON($arr);
			return;
		}

		$mapgroups = getUserResources(array($this->maptype . "Admin"),
		                              array("manageMapping"), 1);
		$tmp = processInputVar('listids', ARG_STRING);
		$tmp = explode(',', $tmp);
		$mapids = array();
		foreach($tmp as $id) {
			if(! is_numeric($id))
				continue;
			if(! array_key_exists($id, $mapgroups[$this->maptype])) {
				$arr = array('status' => 'noaccess');
				sendJSON($arr);
				return;
			}
			$mapids[] = $id;
		}

		$mytypeid = getResourceTypeID($this->restype);
		$maptypeid = getResourceTypeID($this->maptype);

		$mode = getContinuationVar('mode');

		if($mode == 'add') {
			$adds = array();
			foreach($mapids as $id)
				$adds[] = "($groupid, $mytypeid, $id, $maptypeid)";
			$query = "INSERT IGNORE INTO resourcemap "
					 .        "(resourcegroupid1, resourcetypeid1, "
					 .         "resourcegroupid2, resourcetypeid2) "
					 . "VALUES ";
			$query .= implode(',', $adds);
			doQuery($query);
		}
		else {
			foreach($mapids as $id) {
				$query = "DELETE FROM resourcemap "
						 . "WHERE resourcegroupid1 = $groupid AND "
						 .       "resourcetypeid1 = $mytypeid AND "
						 .       "resourcegroupid2 = $id AND "
						 .       "resourcetypeid2 = $maptypeid";
				doQuery($query);
			}
		}
		$regids = "^" . implode('$|^', $mapids) . "$";
		$arr = array('status' => 'success',
		             'regids' => $regids,
		             'inselobj' => 'inmapgroups',
		             'outselobj' => 'outmapgroups');
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn mapByMapToGroupHTML()
	///
	/// \return html
	///
	/// \brief generates HTML for resource mapping by selecting a resource group
	/// of the type that this type maps to
	///
	/////////////////////////////////////////////////////////////////////////////
	function mapByMapToGroupHTML() {
		$tmp = getUserResources(array($this->maptype . "Admin"),
		                        array("manageMapping"), 1);
		$mapgroups = $tmp[$this->maptype];
		uasort($mapgroups, "sortKeepIndex");
		$tmp = getUserResources(array($this->restype . "Admin"),
		                        array("manageMapping"), 1);
		$groups = $tmp[$this->restype];
		uasort($groups, "sortKeepIndex");
		$h = '';

		if(! count($mapgroups) || ! count($groups)) {
			$h .= "You don't have access to manage any mappings for this resource ";
			$h .= "type.<br>\n";
			return $h;
		}

		$h .= "<div id=\"mapbymaptogroupdiv\" dojoType=\"dijit.layout.ContentPane\" ";
		$h .= "title=\"" . i("Map By {$this->maptypename} Group") . "\">\n";
		$h .= "<div style=\"width: 410px;\">\n";
		$h .= i("Select an item from the drop-down box and click \"Get {$this->restypename} Groups\" to see all of the groups it maps to. Then, select a group it does not map to and click the Add button to map it to that group, or select a group it maps to and click the Remove button to unmap it from that group.");
		$h .= "</div><br>\n";
		$h .= i("{$this->maptypename} Group:") . "<select id=\"maptogroups\">\n";
		foreach($mapgroups as $id => $group)
			$h .= "<option value=$id>$group</option>\n";
		$h .= "</select>\n";
		$h .= dijitButton('', i("Get {$this->restypename} Groups"),
		                  "populateLists('maptogroups', 'inmaptogroups', 'inmaptogroupname', 'outmaptogroupname', 'mapbymaptogroupcont');");
		$h .= "<table><tbody><tr>\n";
		# select for groups mapped to
		$h .= "<td valign=top>\n";
		$h .= sprintf(i("{$this->restypename} Groups %s maps to:"), "<span style=\"font-weight: bold;\" id=\"inmaptogroupname\"></span>");
		$h .= "<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"inmaptogroups\" ";
		$h .= "store=\"mapbymaptogroupstore\" style=\"width: 240px; height: 250px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"extended\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"160px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</td>\n";
		# transfer buttons
		$h .= "<td style=\"vertical-align: middle;\">\n";
		$h .= dijitButton('', "<div style=\"width: 60px;\">&lt;-" . i("Add") . "</div>",
		                  "resource.addRemItem('addmaptogrpcont', 'maptogroups', 'outmaptogroups');");
		$cdata = $this->basecdata;
		$cdata['mode'] = 'add';
		$cont = addContinuationsEntry('AJaddRemGroupMapTo', $cdata);
		$h .= "<input type=\"hidden\" id=\"addmaptogrpcont\" value=\"$cont\">\n";
		$h .= "<br><br><br>\n";
		$h .= dijitButton('', "<div style=\"width: 60px;\">" . i("Remove") . "-&gt;</div>",
		                  "resource.addRemItem('remmaptogrpcont', 'maptogroups', 'inmaptogroups');");
		$cdata['mode'] = 'remove';
		$cont = addContinuationsEntry('AJaddRemGroupMapTo', $cdata);
		$h .= "<input type=\"hidden\" id=\"remmaptogrpcont\" value=\"$cont\">\n";
		$h .= "</td>\n";
		# select for groups resource is not in
		$h .= "<td valign=top>\n";
		$h .= sprintf(i("{$this->restypename} Groups %s does not map to:"), "<span style=\"font-weight: bold;\" id=\"outmaptogroupname\"></span>");
		$h .= "<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"outmaptogroups\" ";
		$h .= "store=\"mapbymaptogroupstore\" style=\"width: 240px; height: 250px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"extended\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"160px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</td>\n";
		$h .= "</tr></tbody></table>\n";
		$cdata = $this->basecdata;
		$cdata['store'] = 'mapbymaptogroupstore';
		$cdata['intitle'] = 'inmaptogroups';
		$cdata['outtitle'] = 'outmaptogroups';
		$cont = addContinuationsEntry('jsonResourceMappingGroups', $cdata);
		$h .= "<input type=hidden id=\"mapbymaptogroupcont\" value=\"$cont\">\n";
		$h .= "</div>\n";
		return $h;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn jsonResourceMappingGroups()
	///
	/// \brief sends JSON of resource groups for resource mapping by selecting a
	/// resource group of the type this type maps to
	///
	/////////////////////////////////////////////////////////////////////////////
	function jsonResourceMappingGroups() {
		$resmaptogrpid = processInputVar('id', ARG_NUMERIC);
		$resources = getUserResources(array($this->maptype . "Admin"), array("manageMapping"), 1);
		if(! array_key_exists($resmaptogrpid, $resources[$this->maptype])) {
			sendJSON(array('status' => 'noaccess'));
			return;
		}
		$groups = getUserResources(array($this->restype . 'Admin'), array('manageMapping'), 1);
		$mapping = getResourceMapping($this->maptype, $this->restype);
		$all = array();

		foreach($groups[$this->restype] as $id => $group) {
			if(array_key_exists($resmaptogrpid, $mapping) &&
				in_array($id, $mapping[$resmaptogrpid]))
				$all[] = array('id' => $id, 'name' => $group, 'inout' => 1);
			else
				$all[] = array('id' => $id, 'name' => $group, 'inout' => 0);
		}
		$arr = array('items' => $all,
		             'intitle' => getContinuationVar('intitle'),
		             'outtitle' => getContinuationVar('outtitle'));
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJaddRemGroupMapTo()
	///
	/// \brief adds or removes groups that map to a group of the type this
	/// resource maps to
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJaddRemGroupMapTo() {
		$mapgroupid = processInputVar('id', ARG_NUMERIC);
		$mapgroups = getUserResources(array($this->maptype . "Admin"),
		                              array("manageMapping"), 1);
		if(! array_key_exists($mapgroupid, $mapgroups[$this->maptype])) {
			$arr = array('status' => 'noaccess');
			sendJSON($arr);
			return;
		}

		$groups = getUserResources(array($this->restype . "Admin"),
		                           array("manageMapping"), 1);
		$tmp = processInputVar('listids', ARG_STRING);
		$tmp = explode(',', $tmp);
		$groupids = array();
		foreach($tmp as $id) {
			if(! is_numeric($id))
				continue;
			if(! array_key_exists($id, $groups[$this->restype])) {
				$arr = array('status' => 'noaccess');
				sendJSON($arr);
				return;
			}
			$groupids[] = $id;
		}

		$mytypeid = getResourceTypeID($this->restype);
		$maptypeid = getResourceTypeID($this->maptype);

		$mode = getContinuationVar('mode');

		if($mode == 'add') {
			$adds = array();
			foreach($groupids as $id)
				$adds[] = "($id, $mytypeid, $mapgroupid, $maptypeid)";
			$query = "INSERT IGNORE INTO resourcemap "
					 .        "(resourcegroupid1, resourcetypeid1, "
					 .         "resourcegroupid2, resourcetypeid2) "
					 . "VALUES ";
			$query .= implode(',', $adds);
			doQuery($query);
		}
		else {
			foreach($groupids as $id) {
				$query = "DELETE FROM resourcemap "
						 . "WHERE resourcegroupid1 = $id AND "
						 .       "resourcetypeid1 = $mytypeid AND "
						 .       "resourcegroupid2 = $mapgroupid AND "
						 .       "resourcetypeid2 = $maptypeid";
				doQuery($query);
			}
		}
		$regids = "^" . implode('$|^', $groupids) . "$";
		$arr = array('status' => 'success',
		             'regids' => $regids,
		             'inselobj' => 'inmaptogroups',
		             'outselobj' => 'outmaptogroups');
		sendJSON($arr);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn mapByGridHTML()
	///
	/// \brief
	///
	/////////////////////////////////////////////////////////////////////////////
	function mapByGridHTML() {
		# TODO
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJsaveResource()
	///
	/// \brief saves changes to a resource; must be implemented by inheriting
	/// class
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJsaveResource() {
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn AJeditResource()
	///
	/// \brief sends data for editing a resource
	///
	/////////////////////////////////////////////////////////////////////////////
	function AJeditResource() {
		$rscid = processInputVar('rscid', ARG_NUMERIC);
		$resources = getUserResources(array($this->restype . 'Admin'), array('administer'), 0, 1);
		if(! array_key_exists($rscid, $resources[$this->restype])) {
			$ret = array('status' => 'noaccess');
			sendJSON($ret);
			return;
		}
		$args = $this->defaultGetDataArgs;
		$args['rscid'] = $rscid;
		$tmp = $this->getData($args);
		$data = $tmp[$rscid];
		$cdata = $this->basecdata;
		$cdata['rscid'] = $rscid;
		$cdata['olddata'] = $data;

		# save continuation
		$cont = addContinuationsEntry('AJsaveResource', $cdata);

		$ret = $this->jsondata;
		$ret['title'] = "Edit {$this->restypename}";
		$ret['cont'] = $cont;
		$ret['resid'] = $rscid;
		$ret['data'] = $data;
		$ret['status'] = 'success';
		sendJSON($ret);
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addResource($data)
	///
	/// \param $data - array of needed data for adding a new resource
	///
	/// \return id of new resource
	///
	/// \brief handles all parts of adding a new resource to the database; should
	/// be implemented by inheriting class, but not required since it is only
	/// called by functions in the inheriting class (nothing in this base class
	/// calls it directly)
	///
	/////////////////////////////////////////////////////////////////////////////
	function addResource($data) {
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn addEditDialogHTML($add)
	///
	/// \param $add (optional, defaul=0) - 0 for edit, 1 for add
	///
	/// \brief handles generating HTML for dialog used to edit resource; must be
	/// implemented by inheriting class
	///
	/////////////////////////////////////////////////////////////////////////////
	function addEditDialogHTML($add) {
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkExistingField($field, $value, $id=0)
	///
	/// \param $field - database field name
	/// \param $value - value for $field
	/// \param $id - (optional, default=0) if nonzero, ignore resource with this
	/// id
	///
	/// \return 1 if existing resource with $field set to $value, 0 if not
	///
	/// \brief checks to see if there is already a record in the database with
	/// $field set to $value
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkExistingField($field, $value, $id=0) {
		$query = "SELECT id FROM {$this->restype} "
		       . "WHERE `$field` = '$value'";
		if($this->deletetoggled)
			$query .= " AND deleted = 0";
		if($id)
			$query .= " AND id != $id";
		$qh = doQuery($query);
		if(mysql_num_rows($qh))
			return 1;
		return 0;
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn extraSelectAdminOptions()
	///
	/// \return html
	///
	/// \brief generates any HTML for additional options that should be shown on
	/// selectionText page
	///
	/////////////////////////////////////////////////////////////////////////////
	function extraSelectAdminOptions() {
	}

	/////////////////////////////////////////////////////////////////////////////
	///
	/// \fn checkResourceInUse($rscid)
	///
	/// \param $rscid - id of resource
	///
	/// \return empty string if not being used; string of where resource is
	/// being used if being used
	///
	/// \brief checks to see if a resource is being used; must be implemented in
	/// inheriting class
	///
	/////////////////////////////////////////////////////////////////////////////
	function checkResourceInUse($rscid) {
		return '';
	}
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn AJstartImage()
///
/// \brief starts the imaging process for a reservation
///
////////////////////////////////////////////////////////////////////////////////
function AJstartImage() {
	global $user;
	$requestid = getContinuationVar("requestid");
	$checkpoint = getContinuationVar("checkpoint", 0);

	$data = getRequestInfo($requestid, 1);
	if(is_null($data) || $data['stateid'] == 11 || $data['stateid'] == 12 ||
	   ($data['stateid'] == 14 && 
	   ($data['laststateid'] == 11 || $data['laststateid'] == 12))) {
		$ret = array('status' => 'resgone',
		             'errmsg' => i("The reservation you selected to image has expired."));
		sendJSON($ret);
		return;
	}
	$disableUpdate = 1;
	$imageid = '';
	if(count($data['reservations']) == 1) {
		$imageid = $data['reservations'][0]['imageid'];
		$revid = $data['reservations'][0]['imagerevisionid'];
	}
	else {
		foreach($data["reservations"] as $res) {
			if($res["forcheckout"]) {
				$imageid = $res["imageid"];
				$revid = $res['imagerevisionid'];
				break;
			}
		}
	}
	$ostype = 'windows';
	if(! empty($imageid)) {
		$imageData = getImages(0, $imageid);
		if($imageData[$imageid]['ownerid'] == $user['id'])
			$disableUpdate = 0;
		if($imageData[$imageid]['installtype'] == 'none' ||
		   $imageData[$imageid]['installtype'] == 'kickstart')
			$disableUpdate = 1;
		$ostype = $imageData[$imageid]['ostype'];
	}
	else {
		$data['status'] = 'error';
		$data['errmsg'] = i("There was an error in starting the imaging process. Please contact a system administrator.");
		sendJSON($data);
		return;
	}

	# check for root access being disabled
	if($imageData[$imageid]['rootaccess'] == 0 && $imageData[$imageid]['ownerid'] != $user['id']) {
		$ret = array('status' => 'rootaccessnoimage');
		sendJSON($ret);
		return;
	}

	$obj = new Image();
	$cdata = array('obj' => $obj,
	               'requestid' => $requestid,
	               'imageid' => $imageid,
	               'baserevisionid' => $revid,
	               'checkpoint' => $checkpoint,
	               'add' => 1);
	$cont = addContinuationsEntry('AJsaveResource', $cdata, SECINDAY, 0);
	$arr = array('newcont' => $cont,
	             'enableupdate' => 0,
	             'connectmethods' => $imageData[$imageid]['connectmethods'],
	             'owner' => "{$user['unityid']}@{$user['affiliation']}",
	             'checkpoint' => $checkpoint,
	             'ostype' => $ostype);

	$cdata = array('obj' => $obj,
	               'imageid' => $imageid,
	               'newimage' => 1,
	               'curmethods' => $imageData[$imageid]['connectmethods']);
	$cont = addContinuationsEntry('connectmethodDialogContent', $cdata);
	$arr['connectmethodurl'] = BASEURL . SCRIPT . "?continuation=$cont";

	if(! $disableUpdate) {
		$revisions = getImageRevisions($imageid, 1);
		if(array_key_exists($revid, $revisions))
			$comments = $revisions[$revid]['comments'];
		else {
			$keys = array_keys($revisions);
			if(count($keys)) {
				$key = array_pop($keys);
				$comments = $revisions[$key]['comments'];
			}
			else
				$comments = '';
		}
		if(preg_match('/\w/', $comments)) {
			$cmt  = sprintf(i("These are the comments from the previous revision (%s):"),
			                $revisions[$revid]['revision']);
			$cmt .= "<br>";
			$cmt .= "{$revisions[$revid]['comments']}<br><br>";
		}
		else
			$cmt = i("The previous revision did not have any comments.") . "<br><br>";
		$arr['comments'] = $cmt;
		$cdata = array('obj' => $obj,
		               'requestid' => $requestid,
		               'imageid' => $imageid,
		               'checkpoint' => $checkpoint,
		               'revisionid' => $revid);
		$cont = addContinuationsEntry('AJupdateImage', $cdata, SECINDAY, 0);
		$arr['updatecont'] = $cont;
		$arr['enableupdate'] = 1;
	}
	$arr['status'] = 'success';
	sendJSON($arr);
}

?>
