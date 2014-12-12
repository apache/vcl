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

class Config extends Resource {
	function __construct() {
		parent::__construct();
		$this->restype = 'config';
		$this->restypename = 'Config';
		$this->namefield = 'name';
		$this->defaultGetDataArgs = array('rscid' => 0,
		                                  'includedeleted' => 0);
		$this->basecdata['obj'] = $this;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function getData($args) {
		return $this->_getData($args['rscid'], $args['includedeleted']);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function _getData($id=0, $includedeleted=0) {
		# config variables
		$query = "SELECT cv.id, "
		       .        "cv.name, "
		       .        "cv.configid, "
		       .        "cv.defaultvalue, "
		       .        "cv.required, "
		       .        "cv.ask, "
		       .        "cv.identifier, "
		       .        "cv.datatypeid, "
		       .        "0 AS deleted, "
		       .        "d.name AS datatype "
				 . "FROM configvariable cv, "
				 .      "datatype d "
				 . "WHERE cv.datatypeid = d.id ";
		if($id != 0)
			$query .= "AND cv.configid = $id ";
		$query .= "ORDER BY cv.configid, cv.name";
		$variables = array();
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$variables[$row['configid']][$row['id']] = $row;

		# config subimages
		$query = "SELECT s.id, "
		       .        "s.configid, "
		       .        "s.imageid, "
		       .        "i.prettyname AS name, "
		       .        "s.mininstance AS min, "
		       .        "s.maxinstance AS max, "
		       .        "s.description, "
		       .        "0 AS deleted "
				 . "FROM configsubimage s, "
				 .      "image i "
				 . "WHERE s.imageid = i.id AND "
				 .       "i.deleted = 0 ";
		if($id != 0)
			$query .= "AND configid = $id ";
		$query .= "ORDER BY s.configid, i.prettyname";
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$variables[$row['configid']][$row['id']] = $row;

		# configs
		$query = "SELECT c.id, "
		       .        "c.name, "
		       .        "c.description AS description, "
		       .        "c.configtypeid, "
		       .        "ct.prettyname AS configtype, "
		       .        "ct.configstageid AS configstageid, "
		       .        "cs.name AS stage, "
		       .        "c.data, "
		       .        "c.ownerid, "
		       .        "CONCAT(u.unityid, '@', a.name) AS owner, "
		       .        "c.optional, "
		       .        "c.deleted, "
		       .        "r.id AS resourceid "
		       . "FROM config c, "
		       .      "resource r, "
		       .      "resourcetype t, "
		       .      "user u, "
		       .      "affiliation a, "
		       .      "configtype ct "
		       . "LEFT JOIN configstage cs ON (ct.configstageid = cs.id) "
		       . "WHERE c.configtypeid = ct.id AND "
		       .       "c.ownerid = u.id AND "
		       .       "u.affiliationid = a.id AND "
		       .       "c.id = r.subid AND "
		       .       "r.resourcetypeid = t.id AND "
		       .       "t.name = 'config'";
		if($id != 0)
			$query .= " AND c.id = $id";
		if(! $includedeleted)
			$query .= " AND c.deleted = 0";
		$qh = doQuery($query);
		$configs = array();
		while($row = mysql_fetch_assoc($qh)) {
			if(array_key_exists($row['id'], $variables))
				$row['variables'] = $variables[$row['id']];
			else
				$row['variables'] = array();
			$configs[$row['id']] = $row;
		}
		return $configs;
	}


	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function getConfigMapData($configmapid) {
		$query = "SELECT cm.configid, "
		       .        "c.name AS configname, "
		       .        "ct.prettyname AS configtype, "
		       .        "cm.subid, "
		       .        "cm.configmaptypeid, "
		       .        "cmt.name AS configmaptype, "
		       .        "cmt.prettyname AS prettyconfigmaptype, "
		       .        "cm.affiliationid, "
		       .        "a.name AS affiliation, "
		       .        "cm.disabled, "
		       .        "cm.configstageid AS stageid, "
		       .        "cs.name AS stage "
		       . "FROM configmaptype cmt, "
		       .      "config c, "
		       .      "affiliation a, "
		       .      "configstage cs, "
		       .      "configtype ct, "
		       .      "configmap cm "
		       . "WHERE cm.configmaptypeid = cmt.id AND "
		       .       "cm.affiliationid = a.id AND "
		       .       "cm.configstageid = cs.id AND "
		       .       "cm.id = $configmapid AND "
		       .       "cm.configid = c.id AND "
		       .       "c.configtypeid = ct.id AND "
		       .       "c.deleted = 0";
		$qh = doQuery($query);
		if($row = mysql_fetch_assoc($qh))
			return $row;
		else
			return NULL;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function extraSelectAdminOptions() {
		$h = '';
		$cont = addContinuationsEntry("editConfigMap", $this->basecdata);
		$h .= "<INPUT type=radio name=continuation value=\"$cont\" id=\"";
		$h .= "configmap\"><label for=\"configmap\">Edit Mapping</label><br>\n";
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJeditResource() {
		# TODO see if base AJeditResource will work
		$configid = processInputVar('rscid', ARG_NUMERIC);
		$configs = getUserResources(array("configAdmin"), array('administer'), 0, 1);
		if(! array_key_exists($configid, $configs['config'])) {
			$ret = array('status' => 'noaccess');
			sendJSON($ret);
			return;
		}
		$tmp = $this->_getData($configid);
		$data = $tmp[$configid];
		$data['variables'] = array_splice($data['variables'], 0);
		$cdata = $this->basecdata;
		$cdata['configid'] = $configid;
		$cdata['configdata'] = $data;
		$cont = addContinuationsEntry('AJsaveResource', $cdata);
		# TODO SECURITY - is there a chance of an XSS attack from value of data
		#$data['data'] = htmlspecialchars($data['data']);
		$ret = array('title' => "Edit {$this->restypename}",
		             'cont' => $cont,
		             'resid' => $configid,
		             'data' => $data,
		             'status' => 'success');
		sendJSON($ret);
	}


	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJsaveResource() {
		$curdata = getContinuationVar('configdata');
		$add = getContinuationVar('add', 0);
		if($add)
			$configid = 0;
		else
			$configid = $curdata['id'];
		if(! $vars = $this->processInput($configid)) {
			sendJSON(array('status' => 'error', 'msg' => $this->errmsg));
			return;
		}
		if($add) {
			$this->addResource($vars);
			return;
		}
		$sets = array();
		if($curdata['name'] != $vars['name']) {
			$name = mysql_real_escape_string($vars['name']);
			$sets[] = "name = '$name'";
		}
		if($curdata['data'] != $vars['data']) {
			$data = mysql_real_escape_string($vars['data']);
			$sets[] = "data = '$data'";
		}
		if($curdata['ownerid'] != $vars['ownerid'])
			$sets[] = "ownerid = {$vars['ownerid']}";
		if($curdata['optional'] != $vars['optional'])
			$sets[] = "optional = {$vars['optional']}";
		if(count($sets)) {
			$allsets = implode(',', $sets);
			$query = "UPDATE config SET $allsets WHERE id = $configid";
			doQuery($query);
		}
		if($curdata['configtype'] == 'Cluster') {
			$cursubs = $curdata['variables'];
			$newsubs = $vars['subimages'];
			$dels = array();
			foreach($cursubs as $sub) {
				$id = $sub['id'];
				if($newsubs[$id]['deleted'])
					$dels[] = $id;
				$sets = array();
				if($newsubs[$id]['min'] != $sub['min'])
					$sets[] = "mininstance = {$newsubs[$id]['min']}";
				if($newsubs[$id]['max'] != $sub['max'])
					$sets[] = "maxinstance = {$newsubs[$id]['max']}";
				if(! empty($sets)) {
					$allsets = implode(',', $sets);
					$query = "UPDATE configsubimage "
					       . "SET $allsets "
							 . "WHERE id = $id";
					doQuery($query);
				}
				unset($newsubs[$id]);
			}
			if(! empty($dels)) {
				$alldels = implode(',', $dels);
				$query = "DELETE FROM configsubimage "
						 . "WHERE id IN ($alldels)";
				doQuery($query);
			}
			$vals = array();
			foreach($newsubs as $sub) {
				$item = "($configid, {$sub['imageid']}, {$sub['min']}, {$sub['max']})";
				$vals[] = $item;
			}
			if(! empty($vals)) {
				$allvals = implode(',', $vals);
				$query = "INSERT INTO configsubimage "
				       .        "(configid, "
				       .        "imageid, "
				       .        "mininstance, "
				       .        "maxinstance) "
				       . "VALUES $allvals";
				doQuery($query);
			}
		}
		else {
			$newvars = $vars['configvariables'];
			$cfgvars = $curdata['variables'];
			$deletes = array();
			$datatypes = getConfigDataTypes();
			foreach($cfgvars as $vardata) {
				$id = $vardata['id'];
				if($newvars[$id]['deleted'] == 1) {
					$deletes[] = $id;
					unset($newvars[$id]);
					continue;
				}
				$sets = array();
				if($vardata['name'] != $newvars[$id]['name']) {
					$name = mysql_real_escape_string($newvars[$id]['name']);
					$sets[] = "name = '$name'";
				}
				if($vardata['identifier'] != $newvars[$id]['identifier']) {
					$identifier = mysql_real_escape_string($newvars[$id]['identifier']);
					$sets[] = "identifier = '$identifier'";
				}
				if($vardata['datatypeid'] != $newvars[$id]['datatypeid']) {
					if(! array_key_exists($newvars[$id]['datatypeid'], $datatypes))
						$newvars[$id]['datatypeid'] = $this->findDataTypeID($newvars[$id]['defaultvalue'], $datatypes);
					$sets[] = "datatypeid = '{$newvars[$id]['datatypeid']}'";
				}
				if($vardata['defaultvalue'] != $newvars[$id]['defaultvalue']) {
					$defaultvalue = mysql_real_escape_string($newvars[$id]['defaultvalue']);
					$sets[] = "defaultvalue = '$defaultvalue'";
				}
				if($vardata['required'] != $newvars[$id]['required']) {
					if($newvars[$id]['required'] == 0 ||
						$newvars[$id]['required'] == 1)
						$sets[] = "required = '{$newvars[$id]['required']}'";
				}
				if($vardata['ask'] != $newvars[$id]['ask']) {
					if($newvars[$id]['ask'] == 0 ||
						$newvars[$id]['ask'] == 1)
						$sets[] = "ask = '{$newvars[$id]['ask']}'";
				}
				if(count($sets)) {
					$allsets = implode(',', $sets);
					$query = "UPDATE configvariable SET $allsets WHERE id = $id";
					doQuery($query);
				}
				unset($newvars[$id]);
			}
			if(count($deletes)) {
				$alldels = implode(',', $deletes);
				$query = "DELETE FROM configvariable WHERE id IN ($alldels)";
				doQuery($query);
			}
			if(count($newvars))
				$this->addNewConfigVars($newvars, $configid);
		}
		$vars['id'] = $configid;
		$ret = array('status' => 'success', 'data' => $vars, 'action' => 'update');
		sendJSON($ret);
	}


	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function addNewConfigVars($newvars, $configid) {
		$inserts = array();
		$datatypes = getConfigDataTypes();
		foreach($newvars as $var) {
			$name = mysql_real_escape_string($var['name']);
			$identifier = mysql_real_escape_string($var['identifier']);
			$defaultvalue = mysql_real_escape_string($var['defaultvalue']);
			if(! array_key_exists($var['datatypeid'], $datatypes))
				$var['datatypeid'] = $this->findDataTypeID($var['defaultvalue'], $datatypes);
			$inserts[] = "('$name', "
			           . "$configid, "
			           . "'user', "
			           . "'$defaultvalue', "
			           . "{$var['required']}, "
			           . "{$var['ask']}, "
			           . "'$identifier', "
			           . "'{$var['datatypeid']}')";
		}
		$allvars = implode(',', $inserts);
		$query = "INSERT INTO configvariable "
		       . "(name, configid, `type`, defaultvalue, required, ask, identifier, datatypeid) "
		       . "VALUES $allvars";
		doQuery($query);
	}


	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function addResource($vars) {
		$name = mysql_real_escape_string($vars['name']);
		if($vars['type'] == 'Cluster') {
			$query = "INSERT INTO config "
			       .        "(name, "
			       .        "ownerid, "
			       .        "configtypeid, "
			       .        "optional) "
			       . "VALUES "
			       .        "('$name', "
			       .        "{$vars['ownerid']}, "
			       .        "(SELECT id FROM configtype WHERE prettyname = '{$vars['type']}'), "
			       .        "{$vars['optional']})";
			doQuery($query);
			$id = dbLastInsertID();
			$vals = array();
			foreach($vars['subimages'] as $sub) {
				$item = "($id, {$sub['imageid']}, {$sub['min']}, {$sub['max']})";
				$vals[] = $item;
			}
			$allvals = implode(',', $vals);
			$query = "INSERT INTO configsubimage "
			       .        "(configid, "
			       .        "imageid, "
			       .        "mininstance, "
			       .        "maxinstance) "
			       . "VALUES $allvals";
			doQuery($query);
		}
		else {
			$data = mysql_real_escape_string($vars['data']);
			$query = "INSERT INTO config "
			       .        "(name, "
			       .        "configtypeid, "
			       .        "ownerid, "
			       .        "optional, "
			       .        "data) "
			       . "VALUES "
			       .        "('$name', "
			       .        "{$vars['typeid']}, "
			       .        "{$vars['ownerid']}, "
			       .        "{$vars['optional']}, "
			       .        "'$data')";
			doQuery($query);
			$id = dbLastInsertID();
			if(count($vars['configvariables']))
				$this->addNewConfigVars($vars['configvariables'], $id);
		}
		$query = "INSERT INTO resource "
		       .        "(resourcetypeid, "
		       .        "subid) "
		       . "VALUES "
		       .        "((SELECT id FROM resourcetype WHERE name = 'config'), "
		       .        "$id)";
		doQuery($query);
		$key = getKey(array(array("{$this->restype}Admin"), array("administer"), 0, 1, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$key = getKey(array(array("{$this->restype}Admin"), array("administer"), 0, 0, 0, 0));
		unset($_SESSION['userresources'][$key]);
		$ret = array('status' => 'success', 'action' => 'add');
		$ret['item'] = array('id' => $id,
		                     'name' => $vars['name'],
		                     'configtypeid' => $vars['typeid'],
		                     'configtype' => $vars['type'],
		                     'data' => $vars['data'],
		                     'ownerid' => $vars['ownerid'],
		                     'owner' => $vars['owner'],
		                     'optional' => $vars['optional'],
		                     'deleted' => 0);
		sendJSON($ret);
	}


	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function processInput($configid) {
		$return = array();
		$configtypes = getConfigTypes();
		$return['typeid'] = processInputVar('typeid', ARG_NUMERIC);
		if(! array_key_exists($return['typeid'], $configtypes)) {
			$this->errmsg = "Invalid type submitted";
			return 0;
		}
		$return['name'] = processInputVar('name', ARG_STRING);
		if(! preg_match('/^([-a-zA-Z0-9\. ]){3,80}$/', $return['name'])) {
			$this->errmsg = "The name can only contain letters, numbers, spaces, dashes(-),"
				  . "\\nand periods(.) and can be from 3 to 80 characters long";
			return 0;
		}
		# check for existance of name
		$name = mysql_real_escape_string($return['name']);
		$query = "SELECT id FROM config WHERE name = '$name' AND id != $configid";
		$qh = doQuery($query);
		if(mysql_num_rows($qh)) {
			$this->errmsg = "Another config with this name already exists.";
			return 0;
		}
		# owner
		$return['owner'] = processInputVar('owner', ARG_STRING);
		if(! validateUserid($return['owner'])) {
			$this->errmsg = "Invalid user submitted for owner";
			return 0;
		}
		$return['ownerid'] = getUserlistID($return['owner']);
		if(is_null($return['owner'])) {
			$this->errmsg = "Invalid user submitted for owner";
			return 0;
		}
		# optional
		$return['optional'] = processInputVar('optional', ARG_NUMERIC);
		if($return['optional'] !== '0' && $return['optional'] !== '1') {
			$this->errmsg = "Invalid data submitted";
			return 0;
		}
		# type
		$return['type'] = $configtypes[$return['typeid']];
		# cluster
		if($return['type'] == 'Cluster') {
			if(get_magic_quotes_gpc())
				$tmp = stripslashes($_POST['subimages']);
			else
				$tmp = $_POST['subimages'];
			$tmp = json_decode($tmp, 1);
			if(is_null($tmp)) {
				$this->errmsg = "Invalid data submitted";
				return 0;
			}
			$resources = getUserResources(array("imageAdmin"));
			$return['subimages'] = $tmp['items'];
			foreach($return['subimages'] as $key => $sub) {
				if(! array_key_exists($sub['imageid'], $resources['image'])) {
					$this->errmsg = "Invalid subimage submitted";
					return 0;
				}
				elseif(! is_numeric($sub['min']) || $sub['min'] < 1 || $sub['min'] > MAXSUBIMAGES ||
				       ! is_numeric($sub['max']) || $sub['max'] < 1 || $sub['max'] > MAXSUBIMAGES ||
						 $sub['min'] > $sub['max']) {
					$this->errmsg = "Invalid min/max value submitted for {$resources['image'][$sub['imageid']]}";
					return 0;
				}
				elseif($sub['deleted'] != 0 && $sub['deleted'] != 1) {
					if($sub['id'] > 15000000)
						unset($return['subimages'][$key]);
					else
						$return['subimages'][$key]['deleted'] = 0;
				}
			}
			$return['data'] = '';
		}
		# vlan
		elseif($return['type'] == 'VLAN') {
			$tmp = getContinuationVar('configdata');
			$vdata = $tmp['variables'][0];
			$return['data'] = processInputVar('vlanid', ARG_NUMERIC);
			if($return['data'] < 1 || $return['data'] > 4095) {
				$this->errmsg = "VLAN ID must be between 1 and 4095";
				return 0;
			}
			$var = array($vdata['id'] =>
			             array('id' => $vdata['id'],
			                   'name' => 'VLAN',
			                   'identifier' => $vdata['identifier'],
			                   'datatypeid' => $vdata['datatypeid'],
			                   'defaultvalue' => $return['data'],
			                   'required' => '1',
			                   'ask' => '0',
			                   'deleted' => '0'));
			$return['configvariables'] = $var;
		}
		# other
		else {
			# TODO may need more validation on data
			$return['data'] = trim($_POST['data']);
			if(get_magic_quotes_gpc())
				$return['data'] = stripslashes($return['data']);
			if(! is_string($return['data']) || $return['data'] == '') {
				$this->errmsg = "cannot be empty";
				return 0;
			}
			# TODO validate configvariable input
			if(get_magic_quotes_gpc())
				$tmp = stripslashes($_POST['configvariables']);
			else
				$tmp = $_POST['configvariables'];
			$tmp = json_decode($tmp, 1);
			$return['configvariables'] = $tmp['items'];
		}
		return $return;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function addEditDialogHTML() {
		# TODO add places for description fields
		global $user;
		# dialog for on page editing
		$configtypes = getConfigTypes();
		$h = '';
		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"addeditdlg\"\n";
		$h .= "      title=\"Edit {$this->restypename}\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"addeditdlgcontent\">\n";
		# id
		$h .= "<input type=\"hidden\" id=\"editresid\">\n";
		# type
		$h .= "<label for=\"type\">Type:</label><span class=\"labeledform\">\n";
		$h .= selectInputHTML('', $configtypes, 'type', 'dojoType="dijit.form.Select" maxHeight="250" onChange="configSetType();"');
		$h .= "</span><br>\n";
		# config name
		$h .= "<label for=\"name\">Name:</label><span class=\"labeledform\"><input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
		$h .= "id=\"name\" required=\"true\" invalidMessage=\"Name can only contain letters, numbers, ";
		$h .= "spaces, dashes(-), parenthesis, <br>and periods(.) and can be from 3 to 80 characters long\" ";
		$h .= "regExp=\"^([-a-zA-Z0-9\. \(\)]){3,80}$\" style=\"width: 300px\"></span><br>\n";
		# owner
		$h .= "<label for=\"owner\">Owner:</label><span class=\"labeledform\"><input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
		$h .= "id=\"owner\" required=\"true\" invalidMessage=\"Unknown user\" style=\"width: 300px\" ";
		$h .= "validator=\"checkOwner\" onKeyPress=\"setOwnerChecking\" value=\"{$user['unityid']}@{$user['affiliation']}\"></span><br>\n";
		$cont = addContinuationsEntry('AJvalidateUserid');
		$h .= "<input type=\"hidden\" id=\"valuseridcont\" value=\"$cont\">\n";
		# optional
		$h .= "<label for=\"optionalchk\">Optional:</label>\n";
		$h .= "<span class=\"labeledform\"><input type=checkbox dojoType=dijit.form.CheckBox id=\"optionalchk\"></span><br>\n";
		# config data
		$h .= "<div id=\"configdatadiv\">\n";
		$h .= "<span id=\"datalabel\" style=\"font-weight: bold;\"></span>:<br>\n";
		$h .= "<textarea id=\"data\" style=\"width: 40em; height: 10em;\"></textarea>\n";
		$h .= "</div>\n"; #configdatadiv

		# subimage extra
		$h .= "<div id=\"subimageextradiv\" class=\"hidden\"><br>\n";
		# subimage
		$h .= "<b>Subimages</b>:<br>\n";
		$resources = getUserResources(array("imageAdmin"));
		# TODO possibly populate this after page load
		if(USEFILTERINGSELECT && count($resources['image']) < FILTERINGSELECTTHRESHOLD)
			$h .= selectInputHTML('', $resources['image'], 'subimageid', 'dojoType="dijit.form.FilteringSelect"');
		else
			$h .= selectInputHTML('', $resources['image'], 'subimageid', 'dojoType="dijit.form.Select" maxHeight="250"');
		# add subimage button
		$h .= "<button dojoType=\"dijit.form.Button\" id=\"addsubimagebtn\">\n";
		$h .= "  Add Subimage\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    addCfgSubimage();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		# list of subimages
		$h .= "<div id=\"subimagegriddiv\">\n";
		# TODO - figure out how to get an embedded widget in a cell
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"subimagegrid\" ";
		$h .= "style=\"width: 350px; height: 300px;\" ";
		$h .= "selectionMode=\"extended\" ";
		$h .= "sortInfo=\"1\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"270px\"></th>\n";
		$h .= "<th field=\"min\" width=\"30px\" editable=\"true\"></th>\n";
		$h .= "<th field=\"max\" width=\"30px\" editable=\"true\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</div>\n"; # subimagegriddiv
		# remove subimages button
		$h .= "<button dojoType=\"dijit.form.Button\" id=\"remsubimagebtn\">\n";
		$h .= "  Remove Selected Subimage(s)\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    removeSubimages();\n";
		$h .= "  </script>\n";
		$h .= "</button><br><br>\n";
		$h .= "</div>\n"; #subimageextradiv

		# vlan extra
		$h .= "<div id=\"vlanextradiv\" class=\"hidden\">\n";
		# vlan id
		$h .= "<label for=\"vlanid\">VLAN ID:</label>\n";
		$h .= "<span class=\"labeledform\"><input dojoType=\"dijit.form.NumberSpinner\" value=\"1\" ";
		$h .= "smallDelta=1 largeDelta=5 ";
		$h .= "constraints=\"{min:1, max:4095}\" id=\"vlanid\" required=\"true\" ";
		$h .= "style=\"width: 70px\"/></span><br>\n";
		$h .= "</div>\n"; #vlanextradiv

		# config variables
		#$h .= "<div id=\"configvariables\" class=\"hidden\">\n";
		$h .= "<div id=\"configvariables\">\n";
		$h .= "<h3 align=\"center\">Config Variables</h3>\n";
		$h .= "<table summary=\"\"><tr valign=\"top\"><td>\n";
		# list of variables
		$h .= "<div id=\"configvariablegriddiv\">\n";
		$h .= "Select a variable:<br>\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"configvariablegrid\" ";
		$h .= "style=\"width: 150px; height: 125px;\" query=\"{inout: 1}\" ";
		$h .= "selectionMode=\"single\" ";
		$h .= "onSelected=\"configVarSelected\" ";
		$h .= "onCanSelect=\"configVarAllowSelection\" ";
		$h .= "sortInfo=\"1\">\n";
		$h .= "  <script type=\"dojo/connect\" event=\"onStyleRow\" args=\"row\">\n";
		$h .= "    configVarListStyle(row);\n";
		$h .= "  </script>\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		$h .= "<th field=\"name\" width=\"150px\"></th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</div>\n";
		$h .= "<button dojoType=\"dijit.form.Button\" id=\"newcfgvarbtn\">\n";
		$h .= "  Add New Variable\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    addNewConfigVar();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		$h .= "</td><td>\n";
		# edit variable
		$h .= "<div id=\"editcfgvardiv\" class=\"hidden\">\n";
		# id
		$h .= "<input type=\"hidden\" id=\"varid\">\n";
		# name
		$h .= "<label for=\"varname\">Name:</label><span class=\"labeledform\">\n";
		$h .= "<input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
		$h .= "id=\"varname\" required=\"true\" invalidMessage=\"Name can only contain letters, numbers, ";
		$h .= "spaces, dashes(-), parenthesis, <br>and periods(.) and can be from 3 to 80 characters long\" ";
		$h .= "regExp=\"^([-a-zA-Z0-9\. \(\)]){3,80}$\" style=\"width: 120px\" ";
		$h .= "onKeyPress=\"delayedUpdateConfigVariable\"></span><br>\n";
		# key
		$h .= "<label for=\"varidentifier\">Identifier:</label><span class=\"labeledform\">\n";
		$h .= "<input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
		$h .= "id=\"varidentifier\" invalidMessage=\"Key can only contain letters, numbers, "; # TODO determine constraints, if any
		$h .= "dashes(-), underscores(_), <br>and percents(%) and can be from 3 to 20 characters long\" ";
		$h .= "regExp=\"^([-_A-Za-z0-9%]){3,20}$\" style=\"width: 120px\" ";
		$h .= "onKeyPress=\"delayedUpdateConfigVariable\"></span><br>\n";
		# type
		$h .= "<label id=\"cfgvartypelbl\" for=\"vartypespan\">Type:</label><span class=\"labeledform\" id=\"vartypespan\">";
		$datatypes = getConfigDataTypes();
		$h .= selectInputHTML('', $datatypes, 'cfgvartype', 'dojoType="dijit.form.Select" maxHeight="250" onChange="setCfgVarType();"');
		$h .= "</span><br>\n";
		# value - bool
		$h .= "<span id=\"vartypeboolspan\">\n";
		$h .= "<label for=\"vartypebool\">Value:</label>\n";
		$h .= "<span class=\"labeledform\">";
		$h .= selectInputAutoDijitHTML('', array('true', 'false'), 'vartypebool', 'onChange="delayedUpdateConfigVariable();"');
		$h .= "</span><br>\n";
		$h .= "</span>\n"; # vartypeboolspan
		# value - int
		$h .= "<span id=\"vartypeintspan\">\n";
		$h .= "<label for=\"vartypeint\">Value:</label>\n";
		$h .= "<span class=\"labeledform\"><input dojoType=\"dijit.form.NumberSpinner\" value=\"1\" ";
		$h .= "id=\"vartypeint\" intermediateChanges=\"true\" constraints=\"{places:0}\" ";
		$h .= "onChange=\"delayedUpdateConfigVariable\" style=\"width: 70px\"/>";
		$h .= "</span><br>\n";
		$h .= "</span>\n"; # vartypeintspan
		# value - float
		$h .= "<span id=\"vartypefloatspan\">\n";
		$h .= "<label for=\"vartypefloat\">Value:</label>\n";
		$h .= "<span class=\"labeledform\"><input dojoType=\"dijit.form.NumberSpinner\" value=\"1\" ";
		$h .= "id=\"vartypefloat\" intermediateChanges=\"true\" ";
		$h .= "onChange=\"delayedUpdateConfigVariable\" style=\"width: 70px\"/>";
		$h .= "</span><br>\n";
		$h .= "</span>\n"; # vartypefloatspan
		# value - string
		$h .= "<span id=\"vartypestringspan\" class=\"hidden\">\n";
		$h .= "<label for=\"vartypestring\">Value:</label><span class=\"labeledform\">\n";
		$h .= "<input type=\"text\" dojoType=\"dijit.form.ValidationTextBox\" ";
		$h .= "id=\"vartypestring\" invalidMessage=\"Value can only contain letters, numbers, "; # TODO determine constraints, if any, also update in requests.php
		$h .= "spaces, dashes(-), parenthesis, <br>slashes(/) and periods(.) and can be from 3 to 255 characters long\" ";
		$h .= "regExp=\"^([-a-zA-Z0-9\. \(\)/]){3,255}$\" style=\"width: 120px\" ";
		$h .= "onKeyPress=\"delayedUpdateConfigVariable\"></span><br>\n";
		$h .= "</span>\n"; # vartypestringspan
		# value - text
		$h .= "<span id=\"vartypetextspan\" class=\"hidden\">\n";
		$h .= "<label for=\"vartypetext\">Value:</label><span class=\"labeledform\">\n";
		$h .= "<div dojoType=\"dijit.form.Textarea\" ";
		$h .= "id=\"vartypetext\" style=\"width: 240px\" "; # TODO determine constraints, if any
		$h .= "onKeyPress=\"delayedUpdateConfigVariable\"></div></span><br>\n";
		$h .= "</span>\n"; # vartypetextspan
		# required
		$h .= "<label for=\"varrequired\">Required:</label>\n";
		$h .= "<span class=\"labeledform\"><input dojoType=\"dijit.form.CheckBox\" ";
		$h .= "type=\"checkbox\" id=\"varrequired\" onChange=\"updateConfigVariable\"></span><br>\n";
		# ask
		$h .= "<label for=\"varask\">Prompt for Value:</label>\n"; # TODO need better label name
		$h .= "<span class=\"labeledform\"><input dojoType=\"dijit.form.CheckBox\" ";
		$h .= "type=\"checkbox\" id=\"varask\" onChange=\"updateConfigVariable\"></span><br>\n";
		# delete button
		$h .= "<span class=\"labeledform\">\n";
		$h .= "<button dojoType=\"dijit.form.Button\" disabled=\"true\" id=\"deletecfgvarbtn\">\n";
		$h .= "  Delete Variable\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    deleteConfigVariable();\n";
		$h .= "  </script>\n";
		$h .= "</button></span>\n";
		$h .= "</div>\n"; # editcfgvardiv
		# undelete button
		$h .= "<div id=\"undeletecfgvardiv\" class=\"hidden labeledform\">\n";
		$h .= "<button dojoType=\"dijit.form.Button\">\n";
		$h .= "  Undelete Variable\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    undeleteConfigVariable();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		$h .= "</div>\n"; # undeletecfgvardiv

		$h .= "</td></tr></table>\n";

		$h .= "</div>\n"; # configvariables

		$h .= "</div>\n"; # addeditdlgcontent


		$h .= "<div id=\"addeditdlgerrmsg\" class=\"nperrormsg\"></div>\n";
		$h .= "<div id=\"editdlgbtns\" align=\"center\">\n";
		$h .= "<button dojoType=\"dijit.form.Button\" id=\"addeditbtn\">\n";
		$h .= "  Confirm\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    saveResource();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		$h .= "<button dojoType=\"dijit.form.Button\">\n";
		$h .= "  Cancel\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    dijit.byId('addeditdlg').hide();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		$h .= "</div>\n"; # editdlgbtns
		$h .= "</div>\n";
		return $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function editConfigMap() {
		$h = '';
		$h = "<h2>Config Mapping</h2>\n";

		$cont = addContinuationsEntry('AJeditConfigMapping', $this->basecdata);
		$h .= "<input type=\"hidden\" id=\"editcfgmapcont\" value=\"$cont\">\n";
		$cdata = $this->basecdata;
		$cdata['add'] = 1;
		$cont = addContinuationsEntry('AJsaveConfigMapping', $cdata);
		$h .= "<input type=\"hidden\" id=\"addcfgmapcont\" value=\"$cont\">\n";
		$h .= "<input type=\"hidden\" id=\"savecfgmapcont\">\n";
		$cont = addContinuationsEntry('AJdeleteConfigMapping', $this->basecdata);
		$h .= "<input type=\"hidden\" id=\"deletecfgmapcont\" value=\"$cont\">\n";

		$h .= "<button dojoType=\"dijit.form.Button\">\n";
		$h .= "  Add New Config Mapping\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    addConfigMapping();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";

		# filters
		$h .= "<div dojoType=\"dijit.TitlePane\" title=\"Filters (click to expand)\" ";
		$h .= "open=\"false\">\n";
		$h .= "<strong>Config Name</strong>:\n";
		$h .= "<div dojoType=\"dijit.form.TextBox\" id=\"confignamefilter\" length=\"80\">";
		$h .= "  <script type=\"dojo/connect\" event=\"onKeyUp\" args=\"event\">\n";
		$h .= "    if(event.keyCode == 13) configmapGridFilter();\n";
		$h .= "  </script>\n";
		$h .= "</div>\n";
		$h .= "<button dojoType=\"dijit.form.Button\">\n";
		$h .= "  Apply Name Filter\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    configmapGridFilter();\n";
		$h .= "  </script>\n";
		$h .= "</button><br>\n";
		$h .= "<strong>Displayed Fields</strong>:<br>\n";
		$h .= "<input type=\"checkbox\" id=\"chkmtype\" checked onClick=\"toggleCmapFieldDisplay(this, 'configmaptype')\">";
		$h .= "<label for=\"chkmtype\">Map Type</label><br>\n";
		$h .= "<input type=\"checkbox\" id=\"chkname\" checked onClick=\"toggleCmapFieldDisplay(this, 'configname')\">";
		$h .= "<label for=\"chkname\">Config Name</label><br>\n";
		$h .= "<input type=\"checkbox\" id=\"chkctype\" checked onClick=\"toggleCmapFieldDisplay(this, 'configtype')\">";
		$h .= "<label for=\"chkctype\">Config Type</label><br>\n";
		$h .= "<input type=\"checkbox\" id=\"chkmto\" checked onClick=\"toggleCmapFieldDisplay(this, 'mapto')\">";
		$h .= "<label for=\"chkmto\">Map To</label><br>\n";
		$h .= "<input type=\"checkbox\" id=\"chkaffil\" onClick=\"toggleCmapFieldDisplay(this, 'affiliation')\">";
		$h .= "<label for=\"chkaffil\">Affiliation</label><br>\n";
		$h .= "<input type=\"checkbox\" id=\"chkdisabled\" onClick=\"toggleCmapFieldDisplay(this, 'disabled')\">";
		$h .= "<label for=\"chkdisabled\">Disabled</label><br>\n";
		$h .= "<input type=\"checkbox\" id=\"chkstage\" onClick=\"toggleCmapFieldDisplay(this, 'configstage')\">";
		$h .= "<label for=\"chkstage\">Stage</label><br>\n";
		/*$h .= "<strong>Owner</strong>:\n";
		$h .= "<select dojoType=\"dijit.form.Select\" id=\"ownerfilter\" ";
		$h .= "onChange=\"usergroupGridFilter();\" maxHeight=\"250\"></select><br>\n";
		if($showusergrouptype) {
			$h .= "<strong>Type</strong>:\n";
			$h .= "<label for=\"shownormal\">Normal</label>\n";
			$h .= "<input type=\"checkbox\" dojoType=\"dijit.form.CheckBox\" ";
			$h .= "id=\"shownormal\" onChange=\"usergroupGridFilter();\" ";
			$h .= "checked=\"checked\"> | \n";
			$h .= "<label for=\"showfederated\">Federated</label>\n";
			$h .= "<input type=\"checkbox\" dojoType=\"dijit.form.CheckBox\" ";
			$h .= "id=\"showfederated\" onChange=\"usergroupGridFilter();\" ";
			$h .= "checked=\"checked\"> | \n";
			$h .= "<label for=\"showcourseroll\">Course Roll</label>\n";
			$h .= "<input type=\"checkbox\" dojoType=\"dijit.form.CheckBox\" ";
			$h .= "id=\"showcourseroll\" onChange=\"usergroupGridFilter();\" ";
			$h .= "checked=\"checked\"><br>\n";
		}
		$h .= "<strong>Editable by</strong>:\n";
		$h .= "<select dojoType=\"dijit.form.Select\" id=\"editgroupfilter\" ";
		$h .= "onChange=\"usergroupGridFilter();\" maxHeight=\"250\"></select><br>\n";*/
		$h .= "</div>\n";

		$cont = addContinuationsEntry('jsonConfigMapStore', $this->basecdata);
		$h .= "<div dojoType=\"dojo.data.ItemFileWriteStore\" url=\"" . BASEURL;
		$h .= SCRIPT . "?continuation=$cont\" jsid=\"configmapstore\"></div>\n";

		$h .= "<div id=\"gridcontainer\">\n";
		$h .= "<table dojoType=\"dojox.grid.DataGrid\" jsId=\"configmapgrid\" ";
		$h .= "sortInfo=3 store=\"configmapstore\" autoWidth=\"true\" style=\"";
		#$h .= "height: 580px;\" query=\"{type: new RegExp('normal|federated|courseroll')}\">\n";
		$h .= "height: 580px;\">\n";
		$h .= "<thead>\n";
		$h .= "<tr>\n";
		if(preg_match('/MSIE/i', $_SERVER['HTTP_USER_AGENT']))
			$w = array('64px', '38px', '70px', '170px', '80px', '120px', '100px', '59px', '85px');
		else
			$w = array('5em', '3em', '6em', '14em', '7em', '11em', '9em', '5em', '7.2em');
		$h .= "<th field=\"id\" width=\"{$w[0]}\" formatter=\"fmtConfigMapDeleteBtn\">&nbsp;</th>\n";
		$h .= "<th field=\"id\" width=\"{$w[1]}\" formatter=\"fmtConfigMapEditBtn\">&nbsp;</th>\n";
		$h .= "<th field=\"configmaptype\" width=\"{$w[2]}\">Map Type</th>\n";
		$h .= "<th field=\"configname\" width=\"{$w[3]}\">Config Name</th>\n";
		$h .= "<th field=\"configtype\" width=\"{$w[4]}\">Config Type</th>\n";
		$h .= "<th field=\"mapto\" width=\"{$w[5]}\">Map To</th>\n";
		$h .= "<th field=\"affiliation\" width=\"{$w[6]}\" hidden=\"true\">Affiliation</th>\n";
		$h .= "<th field=\"disabled\" width=\"{$w[7]}\" hidden=\"true\">Disabled</th>\n";
		$h .= "<th field=\"configstage\" width=\"{$w[8]}\" hidden=\"true\">Stage</th>\n";
		$h .= "</tr>\n";
		$h .= "</thead>\n";
		$h .= "</table>\n";
		$h .= "</div>\n";

		# add/edit dialog
		$configs = $this->_getData();
		$maptypes = getConfigMapTypes(1);
		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"addeditcfgmapdlg\"\n";
		$h .= "      title=\"Add Config Mapping\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"addeditcfgmapdlgcontent\">\n";
		$h .= "<input type=\"hidden\" id=\"editcfgmapid\" />\n";
		# config
		$cont = addContinuationsEntry('jsonResourceStore', $this->basecdata);
		$h .= "<div dojoType=\"dojo.data.ItemFileReadStore\" url=\"" . BASEURL;
		$h .= SCRIPT . "?continuation=$cont\" jsid=\"mapconfigliststore\"></div>\n";
		$h .= "<label for=\"config\">Config:</label>\n"; # TODO may want to present configs with config types
		if(USEFILTERINGSELECT && count($configs) < FILTERINGSELECTTHRESHOLD)
			$dtype = 'dijit.form.FilteringSelect';
		else
			$dtype = 'dijit.form.Select';
		$h .= "<select id=\"config\" dojoType=\"$dtype\" ";
		$h .= "onChange=\"configMapSetConfig();\" store=\"mapconfigliststore\" ";
		$h .= "fetchProperties=\"{sort: [{attribute: 'name'}]}\" "; # TODO ignore case
		$h .= "query=\"{deleted: '0'}\" queryExpr=\"*\${0}*\">\n";
		$h .= "</select>\n";
		$h .= "<br>\n";
		# type
		$h .= "Type: <span id=\"mapconfigtype\"></span><br><br>\n";
		# maps to
		$h .= "<strong><big>Maps to:</big></strong><br>\n";
		# map type
		$h .= "<script>\n";
		$h .= "var maptypedata = {identifier: 'id', label: 'name', items: [\n";
		$types = array();
		foreach($maptypes as $id => $name) {
			$t = "  {id: '$id', name: '$name', ";
			if($name == 'Image' || $name == 'Subimage')
				$t .= "clusterok: '1'}";
			else
				$t .= "clusterok: '0'}";
			$types[] = $t;
		}
		$h .= implode(",\n", $types);
		$h .= "\n]}\n";
		$h .= "</script>\n";
		$h .= "<div dojoType=\"dojo.data.ItemFileReadStore\" data=\"maptypedata\" ";
		$h .= "jsid=\"maptypestore\"></div>\n";
		$h .= "<br>Map type: ";
		$h .= "<select id=\"maptype\" dojoType=\"dijit.form.Select\" store=\"maptypestore\" ";
		$h .= "onChange=\"editConfigMapSetMapType();\" query=\"{id: '*'}\"></select>\n";

		# image
		$h .= "<div id=\"imagetypediv\" class=\"hidden\">\n";
		$tmp = getUserResources(array("imageAdmin"), array("administer")); # TODO is this the criteria we want for which images can be selected?
		$images = $tmp['image'];
		$h .= "<label for=\"image\">Image:</label>\n";
		$h .= selectInputAutoDijitHTML('', $images, 'image');
		$h .= "</div>\n"; # imagetypediv
		# os type
		$ostypes = getOStypes();
		$h .= "<div id=\"ostypediv\" class=\"hidden\">\n";
		$h .= "<label for=\"ostype\">OS Type:</label>\n";
		$h .= selectInputAutoDijitHTML('', $ostypes, 'ostype');
		$h .= "</div>\n"; # ostypediv
		# os
		$oses = getOSList();
		$h .= "<div id=\"osdiv\" class=\"hidden\">\n";
		$h .= "<label for=\"os\">OS:</label>\n";
		$h .= selectInputAutoDijitHTML('', $oses, 'os');
		$h .= "</div>\n"; # osdiv
		# config
		$tmp = getUserResources(array("configAdmin"), array("administer")); # TODO is this the criteria we want for which configs can be selected?
		$configs = $this->getUserConfigsNoCluster($tmp['config']);
		$h .= "<div id=\"configdiv\" class=\"hidden\">\n";
		$h .= "<label for=\"mapconfig\">Config:</label>\n";
		$h .= selectInputAutoDijitHTML('', $configs, 'mapconfig');
		$h .= "</div>\n"; # configdiv
		# configsubimage
		$configsubimages = getConfigSubimages($tmp['config']);
		$h .= "<div id=\"configsubimagediv\" class=\"hidden\">\n";
		$h .= "<label for=\"configsubimage\">Cluster:</label>\n";
		$h .= selectInputAutoDijitHTML('', $configsubimages, 'configsubimage');
		$h .= "</div>\n"; # configsubimagediv
		# managementnode
		$managementnodes = getManagementNodes();
		$h .= "<div id=\"managementnodediv\" class=\"hidden\">\n";
		$h .= "<label for=\"managementnode\">Management Node:</label>\n";
		$h .= selectInputAutoDijitHTML('', $managementnodes, 'managementnode');
		$h .= "</div>\n"; # managementnodediv

		$h .= "<br><strong><big>Additional options:</big></strong><br>\n";
		# affiliation
		$affils = getAffiliations();
		$h .= "<br><label for=\"affil\">Affiliation:</label>\n";
		$h .= selectInputAutoDijitHTML('', $affils, 'affil');
		# stage
		$stages = $this->getConfigMapStages();
		$h .= "<div id=\"stagediv\" class=\"hidden\">\n";
		$h .= "<label for=\"stage\">Stage:</label>\n";
		$h .= selectInputAutoDijitHTML('', $stages, 'stage');
		$h .= "</div>\n"; # stagediv
		$h .= "</div>\n"; # addeditcfgmapdlgcontent

		$h .= "<div id=\"addeditcfgmapdlgerrmsg\" class=\"nperrormsg\"></div>\n";
		$h .= "<div id=\"editdlgbtns\" align=\"center\">\n";
		$h .= "<button dojoType=\"dijit.form.Button\" id=\"addeditcfgmapbtn\">\n";
		$h .= "  Confirm\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    saveConfigMapping();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		$h .= "<button dojoType=\"dijit.form.Button\">\n";
		$h .= "  Cancel\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    dijit.byId('addeditcfgmapdlg').hide();\n";
		$h .= "    resetConfigMappingFields();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		$h .= "</div>\n"; # editdlgbtns
		$h .= "</div>\n";

		# delete dialog
		$h .= "<div dojoType=dijit.Dialog\n";
		$h .= "      id=\"delcfgmapdlg\"\n";
		$h .= "      title=\"Delete Config Mapping\"\n";
		$h .= "      duration=250\n";
		$h .= "      draggable=true>\n";
		$h .= "<div id=\"delcfgmapdlgcontent\"></div><br>\n";
		$h .= "<input type=\"hidden\" id=\"submitdeletecfgmapcont\">\n";
		$h .= "<div id=\"delcfgmapdlgerrmsg\" class=\"nperrormsg\"></div>\n";
		$h .= "<div id=\"delcfgmapdlgbtns\" align=\"center\">\n";
		$h .= "<button dojoType=\"dijit.form.Button\" id=\"delcfgmapbtn\">\n";
		$h .= "  Delete Mapping\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    submitDeleteConfigMapping();\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		$h .= "<button dojoType=\"dijit.form.Button\">\n";
		$h .= "  Cancel\n";
		$h .= "  <script type=\"dojo/method\" event=\"onClick\">\n";
		$h .= "    dijit.byId('delcfgmapdlg').hide();\n";
		$h .= "    dojo.byId('delcfgmapdlgcontent').innerHTML = '';\n";
		$h .= "    dojo.byId('delcfgmapdlgerrmsg').innerHTML = '';\n";
		$h .= "  </script>\n";
		$h .= "</button>\n";
		$h .= "</div>\n"; # delcfgmapdlgbtns
		$h .= "</div>\n";

		print $h;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function jsonConfigMapStore() {
		global $user;
		$query = "SELECT cm.id AS id, "
		       .        "c.id as configid, "
		       .        "c.name as configname, "
		       .        "c.description as description, "
		       .        "c.configtypeid AS configtypeid, "
		       .        "ct.prettyname AS configtype, "
		       .        "cm.configmaptypeid, "
		       .        "cmt.prettyname AS configmaptype, "
		       .        "cm.affiliationid, "
		       .        "a.name AS affiliation, "
		       .        "cm.disabled, "
		       .        "cm.configstageid, "
		       .        "cms.name AS configstage, "
		       .        "i.prettyname AS image, "
		       .        "c2.name AS maptoconfig, "
		       .        "i2.prettyname AS subimage, "
		       .        "c3.name AS subimageconfig, "
		       .        "o.prettyname AS os, "
		       .        "ot.name AS ostype "
		       . "FROM config c, "
		       .      "configtype ct, "
		       .      "configmaptype cmt, "
		       .      "configstage cms, "
		       .      "configmap cm "
		       . "LEFT JOIN affiliation a ON (cm.affiliationid = a.id) "
		       . "LEFT JOIN image i ON (cm.subid = i.id) "
		       . "LEFT JOIN config c2 ON (cm.subid = c2.id) "
		       . "LEFT JOIN configsubimage csi ON (cm.subid = csi.id) "
		       . "LEFT JOIN config c3 ON (csi.configid = c3.id) "
		       . "LEFT JOIN image i2 ON (csi.imageid = i2.id) "
		       . "LEFT JOIN OS o ON (cm.subid = o.id) "
		       . "LEFT JOIN OStype ot ON (cm.subid = ot.id) "
		       . "WHERE cm.configid = c.id AND "
		       .       "c.configtypeid = ct.id AND "
		       .       "cm.configmaptypeid = cmt.id AND "
		       .       "cm.configstageid = cms.id AND "
		       .       "c.deleted = 0";
		$configmaps = array();
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh)) {
			switch($row['configmaptype']) {
				case "Image":
					$row['mapto'] = $row['image'];
					break;
				case "Config":
					$row['mapto'] = $row['maptoconfig'];
					break;
				case "Subimage":
					$row['mapto'] = "{$row['subimageconfig']} - {$row['subimage']}";
					break;
				case "OS":
					$row['mapto'] = $row['os'];
					break;
				case "OS Type":
					$row['mapto'] = $row['ostype'];
					break;
			}
			unset($row['image']);
			unset($row['maptoconfig']);
			unset($row['subimage']);
			unset($row['subimagesubimage']);
			unset($row['os']);
			unset($row['ostype']);
			$configmaps[] = $row;
		}
		sendJSON($configmaps, 'id');
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJeditConfigMapping() {
		$configmapid = processInputVar('configmapid', ARG_NUMERIC);
		# TODO check access - who is allowed to map/unmap?
		$data = $this->getConfigMapData($configmapid);
		if(is_null($data)) {
			$ret = array('status' => 'notfound');
			sendJSON($ret);
			return;
		}
		$cdata = $this->basecdata;
		$cdata['configmapid'] = $configmapid;
		$cdata['mapdata'] = $data;
		$cont = addContinuationsEntry('AJsaveConfigMapping', $cdata);
		$ret = array('status' => 'success', 'data' => $data, 'cont' => $cont);
		sendJSON($ret);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJsaveConfigMapping() {
		$add = getContinuationVar('add', 0);
		$maptypes = getConfigMapTypes(1);
		if(! $data = $this->processMappingInput($maptypes)) {
			sendJSON(array('status' => 'error', 'msg' => $this->errmsg));
			return;
		}
		if($add) {
			$this->addConfigMapping($data, $maptypes);
			return;
		}
		$configmapid = getContinuationVar('configmapid', 0);
		$id = $data['configid'];
		$configdata = $this->_getData($id);
		$curdata = getContinuationVar('mapdata');
		$sets = array();
		if($curdata['configid'] != $data['configid'])
			$sets[] = "configid = {$data['configid']}";
		if($curdata['configmaptypeid'] != $data['maptypeid'])
			$sets[] = "configmaptypeid = {$data['maptypeid']}";
		if($curdata['subid'] != $data['subid'])
			$sets[] = "subid = {$data['subid']}";
		if($curdata['affiliationid'] != $data['affiliationid'])
			$sets[] = "affiliationid = {$data['affiliationid']}";
		if(is_null($configdata[$id]['configstageid'])) {
			if($curdata['stageid'] != $data['stageid'])
				$sets[] = "configstageid = {$data['stageid']}";
		}
		else
			$sets[] = "configstageid = {$configdata[$id]['configstageid']}";
		if(count($sets)) {
			$allsets = implode(',', $sets);
			$query = "UPDATE configmap SET $allsets WHERE id = $configmapid";
			doQuery($query);
		}
		$stages = $this->getConfigMapStages();
		$item = array('id' => $configmapid,
		              'configid' => $id,
		              'configname' => $configdata[$id]['name'],
		              'configtypeid' => $configdata[$id]['configtypeid'],
		              'configtype' => $configdata[$id]['configtype'],
		              'configmaptypeid' => $data['maptypeid'],
		              'configmaptype' => $maptypes[$data['maptypeid']],
		              'mapto' => $data['mapto'],
		              'affiliationid' => $data['affiliationid'],
		              'affiliation' => getAffiliationName($data['affiliationid']),
		              'disabled' => $curdata['disabled'],
		              'stageid' => $data['stageid'],
		              'configstage' => $stages[$data['stageid']]);
		$ret = array('status' => 'success', 'data' => $item, 'action' => 'update');
		sendJSON($ret);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function addConfigMapping($data, $maptypes) {
		$configdata = $this->_getData($data['configid']);
		if(is_null($configdata[$data['configid']]['configstageid']))
			$stageid = $data['stageid'];
		else
			$stageid = $configdata[$data['configid']]['configstageid'];
		$query = "INSERT INTO configmap "
		       .        "(configid, " 
		       .        "configmaptypeid, "
		       .        "subid, "
		       .        "affiliationid, "
		       .        "disabled, "
		       .        "configstageid) "
		       . "VALUES "
		       .        "({$data['configid']}, "
		       .        "{$data['maptypeid']}, "
		       .        "{$data['subid']}, "
		       .        "{$data['affiliationid']}, "
		       .        "0, "
		       .        "$stageid)";
		doQuery($query);
		$configmapid = dbLastInsertID();
		$id = $data['configid'];
		$configdata = $this->_getData($id);
		$stages = $this->getConfigMapStages();
		$item = array('id' => $configmapid,
		              'configid' => $id,
		              'configname' => $configdata[$id]['name'],
		              'description' => $configdata[$id]['description'],
		              'configtypeid' => $configdata[$id]['configtypeid'],
		              'configtype' => $configdata[$id]['configtype'],
		              'configmaptypeid' => $data['maptypeid'],
		              'configmaptype' => $maptypes[$data['maptypeid']],
		              'affiliationid' => $data['affiliationid'],
		              'mapto' => $data['mapto'],
		              'affiliation' => getAffiliationName($data['affiliationid']),
		              'disabled' => 0,
		              'stageid' => $data['stageid'],
		              'configstage' => $stages[$data['stageid']]);
		$ret = array('status' => 'success', 'item' => $item, 'action' => 'add');
		sendJSON($ret);
		return;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJdeleteConfigMapping() {
		$configmapid = processInputVar('configmapid', ARG_NUMERIC);
		# TODO check access - who is allowed to map/unmap?
		$data = $this->getConfigMapData($configmapid);
		if(is_null($data)) {
			$ret = array('status' => 'notfound');
			sendJSON($ret);
			return;
		}
		$h = '';
		$h .= "Delete the following config mapping?<br><br>";
		$h .= "<strong>Config</strong>: {$data['configname']}<br><br>";
		$subname = $this->getMapSubName($data['prettyconfigmaptype'], $data['subid']);
		$h .= "<strong>{$data['prettyconfigmaptype']}</strong>: $subname<br><br>";
		$h .= "<strong>Additional options</strong>:<br>";
		$h .= "Affiliation: {$data['affiliation']}<br>";
		$h .= "Stage: {$data['stage']}";
		$cdata = $this->basecdata;
		$cdata['configmapid'] = $configmapid;
		$cont = addContinuationsEntry('AJsubmitDeleteConfigMapping', $cdata, SECINDAY, 1, 0);
		$ret = array('status' => 'success', 'html' => $h, 'cont' => $cont);
		sendJSON($ret);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function AJsubmitDeleteConfigMapping() {
		$configmapid = getContinuationVar('configmapid');
		$query = "DELETE FROM configmap "
		       . "WHERE id = $configmapid";
		doQuery($query);
		$ret = array('status' => 'success', 'configmapid' => $configmapid);
		sendJSON($ret);
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function processMappingInput($maptypes) {
		# configid
		$return['configid'] = processInputVar('configid', ARG_NUMERIC);
		$tmp = getUserResources(array("configAdmin"), array("administer")); # TODO is this the criteria we want for which configs can be selected?
		if(! array_key_exists($return['configid'], $tmp['config'])) {
			$this->errmsg = "Invalid config submitted";
			return 0;
		}

		# maptypeid
		$return['maptypeid'] = processInputVar('maptypeid', ARG_NUMERIC);
		if(! array_key_exists($return['maptypeid'], $maptypes)) {
			$this->errmsg = "Invalid map type submitted";
			return 0;
		}
		
		# subid
		$return['subid'] = processInputVar('subid', ARG_NUMERIC);
		if($maptypes[$return['maptypeid']] == 'Image') {
			$tmp = getUserResources(array("imageAdmin"), array("administer")); # TODO is this the criteria we want for which images can be selected?
			if(! array_key_exists($return['subid'], $tmp['image'])) {
				$this->errmsg = "Invalid image submitted";
				return 0;
			}
			$return['mapto'] = $tmp['image'][$return['subid']];
		}
		elseif($maptypes[$return['maptypeid']] == 'OS Type') {
			$ostypes = getOStypes();
			if(! array_key_exists($return['subid'], $ostypes)) {
				$this->errmsg = "Invalid os type submitted";
				return 0;
			}
			$return['mapto'] = $ostypes[$return['subid']];
		}
		elseif($maptypes[$return['maptypeid']] == 'OS') {
			$oses = getOSList();
			if(! array_key_exists($return['subid'], $oses)) {
				$this->errmsg = "Invalid OS submitted";
				return 0;
			}
			$return['mapto'] = $oses[$return['subid']]['prettyname'];
		}
		elseif($maptypes[$return['maptypeid']] == 'Config') {
			$tmp = getUserResources(array("configAdmin"), array("administer")); # TODO is this the criteria we want for which configs can be selected?
			$configs = $this->getUserConfigsNoCluster($tmp['config']);
			if(! array_key_exists($return['subid'], $configs)) {
				$this->errmsg = "Invalid config submitted";
				return 0;
			}
			$return['mapto'] = $configs[$return['subid']];
		}
		elseif($maptypes[$return['maptypeid']] == 'Subimage') {
			$configsubimages = getConfigSubimages($tmp['config']);
			if(! array_key_exists($return['subid'], $configsubimages)) {
				$this->errmsg = "Invalid cluster submitted";
				return 0;
			}
			$return['mapto'] = $configsubimages[$return['subid']];
		}
		elseif($maptypes[$return['maptypeid']] == 'Management Node') {
			$managementnodes = getManagementNodes();
			if(! array_key_exists($return['subid'], $managementnodes)) {
				$this->errmsg = "Invalid managementnode submitted";
				return 0;
			}
			$return['mapto'] = $managementnodes[$return['subid']]['hostname'];
		}

		# check for creating a loop - cannot have a parent that maps to 
		#   submitted config
		if($maptypes[$return['maptypeid']] == 'Config' ||
			$maptypes[$return['maptypeid']] == 'Subimage') {
		   $rc = $this->mappingLoopCheck($maptypes[$return['maptypeid']], $return['configid'], $return['subid']);
			if($rc != '') {
				$this->errmsg = "This mapping would create a loop. $rc is a<br>"
				              . "parent/grandparent and is mapped to the selected config.";
				return 0;
			}
		}

		# affiliationid
		$return['affiliationid'] = processInputVar('affiliationid', ARG_NUMERIC);
		$affils = getAffiliations();
		if(! array_key_exists($return['affiliationid'], $affils)) {
			$this->errmsg = "Invalid affiliation submitted";
			return 0;
		}

		# stageid
		$return['stageid'] = processInputVar('stageid', ARG_NUMERIC);
		$stages = $this->getConfigMapStages();
		if(! array_key_exists($return['stageid'], $stages)) {
			$this->errmsg = "Invalid stage submitted";
			return 0;
		}

		# duplicate check
		# TODO do we also need to check the disabled field?
		$configmapid = getContinuationVar('configmapid', 0);
		$query = "SELECT id "
		       . "FROM configmap "
		       . "WHERE configid = {$return['configid']} AND "
		       .       "configmaptypeid = {$return['maptypeid']} AND "
		       .       "subid = {$return['subid']} AND "
		       .       "affiliationid = {$return['affiliationid']} AND "
		       .       "configstageid = {$return['stageid']} AND "
		       .       "id != $configmapid";
		$qh = doQuery($query);
		if(mysql_num_rows($qh)) {
			$this->errmsg = "The specified mapping already exists.";
			return 0;
		}
		return $return;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function findDataTypeID($data, $datatypes) {
		$flip = array_flip($datatypes);
		if($data == 'true' || $data == 'false')
			return $flip['bool'];
		elseif(is_int($data))
			return $flip['int'];
		elseif(is_float($data))
			return $flip['float'];
		elseif(strlen($data) < 60)
			return $flip['string'];
		else
			return $flip['text'];
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function getUserConfigsNoCluster($userconfigs) {
		if(empty($userconfigs))
			return array();
		$inlist = implode(',', array_keys($userconfigs));
		$query = "SELECT c.id, "
		       .        "c.name "
		       . "FROM config c, "
		       .      "configtype ct "
		       . "WHERE c.configtypeid = ct.id AND "
		       .       "ct.name != 'cluster' AND "
		       .       "c.id in ($inlist)";
		$configs = array();
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$configs[$row['id']] = $row['name'];
		return $configs;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function getConfigMapStages() {
		$query = "SELECT id, name FROM configstage ORDER BY name";
		$stages = array();
		$qh = doQuery($query);
		while($row = mysql_fetch_assoc($qh))
			$stages[$row['id']] = $row['name'];
		return $stages;
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function getMapSubName($maptype, $subid) {
		switch($maptype) {
			case "Image":
				$data = getImages(0, $subid);
				return $data[$subid]['prettyname'];
			case "OS Type":
				$ostypes = getOStypes();
				return $ostypes[$subid];
			case "OS":
				$oses = getOSList();
				return $oses[$subid]['prettyname'];
			case "Config":
			case "Cluster":
				$data = $this->_getData($subid);
				return $data[$subid]['name'];
			case "Management Node":
				$managementnodes = getManagementNodes('neither', 0, $subid);
				return $managementnodes[$subid]['hostname'];
				break;
		}
	}

	////////////////////////////////////////////////////////////////////////////////
	///
	/// \fn 
	///
	/// \brief Config
	///
	////////////////////////////////////////////////////////////////////////////////
	function mappingLoopCheck($maptype, $configid, $subid, $reccnt=0) {
		if($maptype == 'Config') {
			$query = "SELECT cm.configid, "
			       .        "ct.prettyname AS maptype, "
			       .        "cm.subid, "
			       .        "c.name AS config "
			       . "FROM configmap cm, "
			       .      "configmaptype ct, "
			       .      "config c "
			       . "WHERE cm.configid = $subid AND "
			       .       "cm.configmaptypeid = ct.id AND "
			       .       "ct.prettyname = 'Config' AND "
			       .       "cm.configid = c.id";
			$qh = doQuery($query);
			while($row = mysql_fetch_assoc($qh)) {
				if($row['subid'] == $configid)
					return $row['config'];
				if($reccnt < 20) {
					$rc = $this->mappingLoopCheck($row['maptype'], $configid, $row['subid'], ++$reccnt);
					if($rc != '')
						return $rc;
				}
			}
		}
		elseif($maptype == 'Subimage') {
			$query = "SELECT cs2.configid, "
			       .        "ct.prettyname AS maptype, "
			       .        "cm.subid, "
			       .        "c.name AS config "
			       . "FROM configmap cm, "
			       .      "configmaptype ct, "
			       .      "configsubimage cs, "
			       .      "configsubimage cs2, "
			       .      "config c "
			       . "WHERE cs.id = $subid AND "
			       .       "cs.configid = cm.configid AND "
			       .       "cs2.id = cm.subid AND "
			       .       "cm.configmaptypeid = ct.id AND "
			       .       "ct.prettyname = 'Subimage' AND "
			       .       "cm.configid = c.id";
			$qh = doQuery($query);
			while($row = mysql_fetch_assoc($qh)) {
				if($row['configid'] == $configid)
					return $row['config'];
				if($reccnt < 20) {
					$rc = $this->mappingLoopCheck($row['maptype'], $configid, $row['subid'], ++$reccnt);
					if($rc != '')
						return $rc;
				}
			}
		}
		return '';
	}
}
?>
