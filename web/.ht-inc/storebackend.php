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

require_once('.ht-inc/resource.php');

$RESTresponsecodes = array(
	200 => 'OK',  
	201 => 'Created',  
	202 => 'Accepted',  
	203 => 'Non-Authoritative Information',  
	204 => 'No Content',  
	205 => 'Reset Content',  
	206 => 'Partial Content',  
	300 => 'Multiple Choices',  
	301 => 'Moved Permanently',  
	302 => 'Found',  
	303 => 'See Other',  
	304 => 'Not Modified',  
	305 => 'Use Proxy',  
	307 => 'Temporary Redirect',  
	400 => 'Bad Request',  
	401 => 'Unauthorized',  
	402 => 'Payment Required',  
	403 => 'Forbidden',  
	404 => 'Not Found',  
	405 => 'Method Not Allowed',  
	406 => 'Not Acceptable',  
	407 => 'Proxy Authentication Required',  
	408 => 'Request Timeout',  
	409 => 'Conflict',  
	410 => 'Gone',  
	411 => 'Length Required',  
	412 => 'Precondition Failed',  
	413 => 'Request Entity Too Large',  
	414 => 'Request-URI Too Long',  
	415 => 'Unsupported Media Type',  
	416 => 'Requested Range Not Satisfiable',  
	417 => 'Expectation Failed',  
);

/*function testDojoREST() {
	#$images = getImages(0, 1997);
	#$a = dataToJSON($images[1997], 1);
	#printArray($images[1997]);
	#printArray($a);

	#$obj = new Config();
	#$data = $obj->getData($obj->defaultGetDataArgs);
	#printArray($data);



	print resourceStore('config', 1, 'datastore', 1);

	print "<select dojoType=\"dijit.form.FilteringSelect\" id=\"deployimage\" ";
	print "style=\"width: 400px\" required=\"true\" searchAttr=\"name\" ";
	print "query=\"{deleted: 0}\" queryExpr=\".*\${0}.*\" ";
	print "highlightMatch=\"all\" autoComplete=\"false\" store=\"datastore\">\n";
	print "</select><br>\n";

	print "<button id=\"testbtn\" dojoType=\"dijit.form.Button\">\n";
	print "  Toggle Deleted Flag\n";
	print "  <script type=\"dojo/method\" event=\"onClick\">\n";
	print <<<END
var id = dijit.byId('deployimage').get('value');
console.log('id to delete: ' + id);
storedatastore.remove(id);
console.log('here');
END;
	#print "    showNewResDlg();\n";
	print "  </script>\n";
	print "</button><br><br>\n";
}*/

////////////////////////////////////////////////////////////////////////////////
///
/// \fn resourceStore($type, $detail, $jsid, $datawrapper=0)
///
/// \param $type - type of resource
/// \param $detail - whether to use RESTresourceDetail or RESTresourceBasic
/// \param $jsid - javascript id for store
/// \param $datawrapper - (optional, default=0) set to 1 to wrap JsonRest
/// store with a data ObjectStore
///
/// \return html
///
/// \brief generates HTML for a REST based resource store
///
////////////////////////////////////////////////////////////////////////////////
function resourceStore($type, $detail, $jsid, $datawrapper=0) {
	$h  =	"<div dojoType=\"dojo.store.JsonRest\" target=\"" . BASEURL;
	if($detail)
		$h .= "/index.php/RESTresourceDetail/$type/\" ";
	else
		$h .= "/index.php/RESTresourceBasic/$type/\" ";
	if($datawrapper == 1)
		$h .= "jsid=\"store$jsid\"></div>\n";
	else
		$h .= "jsid=\"$jsid\"></div>\n";
	if($datawrapper == 1) {
		$h .= "<div dojoType=\"dojo.data.ObjectStore\" objectStore=\"store$jsid\" ";
		$h .= "jsid=\"$jsid\"></div>\n";
	}
	return $h;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn RESTresourceBasic()
///
/// \brief sends REST formatted basic information for requested resource type
///
////////////////////////////////////////////////////////////////////////////////
function RESTresourceBasic() {
	$type = validatetype(processRESTarg(1, ARG_STRING));
	$deleted = processInputVar('deleted', ARG_NUMERIC, 0);
	if($deleted != 0 && $deleted != 1)
		$deleted = 0;
	$name = processInputVar('name', ARG_STRING, '*');
	if(is_null($type)) {
		RESTresponse(404, "invalid resource type");
		return;
	}
	$subid = processRESTarg(2, ARG_NUMERIC, 0);
	if($type == 'image')
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"),
		                              array('available'), 0, $deleted);
	elseif($type == 'computer')
		$resources = getUserResources(array("computerAdmin"), array("administer"),
		                              0, $deleted);
	elseif($type == 'config')
		$resources = getUserResources(array("configAdmin"), array('available'),
		                              0, $deleted);
	#elseif ...
	if($name != '*') {
		# TODO
		print '/*';
		print "name: |$name| ";
		foreach($resources[$type] as $id => $resname) {
			print "img: |$resname| ";
			if(! preg_match("/^$name$/i", $resname))
				unset($resources[$type][$id]);
		}
		print '*/';
	}
	if($subid == 0) {
		sendREST(dataToJSON($resources[$type]));
		return;
	}
	elseif(! array_key_exists($subid, $resources[$type])) {
		RESTresponse(404, "specified resource does not exist");
		return;
	}
	sendREST(array('id' => (int)$subid, 'name' => $resources[$type][$subid]));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn RESTresourceDetail
///
/// \brief sends REST formatted detailed information for requested resource type
///
////////////////////////////////////////////////////////////////////////////////
function RESTresourceDetail() {
	$type = validatetype(processRESTarg(1, ARG_STRING));
	$deleted = processInputVar('deleted', ARG_NUMERIC, 0);
	if($deleted != 0 && $deleted != 1)
		$deleted = 0;
	$name = processInputVar('name', ARG_STRING, '*');
	$tmp = processInputVar('prettyname', ARG_STRING, '*');
	if($name == '*' && $tmp != '*')
		$name = $tmp;
	if(is_null($type)) {
		RESTresponse(404, "invalid resource type");
		return;
	}
	$subid = processRESTarg(2, ARG_NUMERIC, 0);
	if($type == 'image')
		$resources = getUserResources(array("imageAdmin", "imageCheckOut"),
		                              array('available'), 0, $deleted);
	elseif($type == 'computer')
		$resources = getUserResources(array("computerAdmin"), array("administer"),
		                              0, $deleted);
	elseif($type == 'config')
		$resources = getUserResources(array("configAdmin"), array('available'),
		                              0, $deleted);
	# TODO
	#elseif ...
	if($subid && ! array_key_exists($subid, $resources[$type])) {
		RESTresponse(404, "specified resource does not exist");
		printArray($resources[$type]);
		return;
	}
	if($_SERVER['REQUEST_METHOD'] == 'DELETE') {
		if(RESTdeleteResource($type, $subid))
			RESTresponse(204);
		else
			RESTresponse(404, "specified resource does not exist 2");
		return;
	}
	if($type == 'image') {
		$items = getImages($deleted, $subid);
		$data = array();
		foreach(array_keys($resources[$type]) as $id) {
			if($name != '*' &&
			   ! preg_match("/^$name$/i", $items[$id]['prettyname']))
				continue;
			if(array_key_exists($id, $items))
				$data[$id] = $items[$id];
		}
	}
	elseif($type == 'computer')
		$data = getComputers(1, 0, $subid);
	elseif($type == 'config') {
		$cluster = processInputVar('cluster', ARG_NUMERIC, -1);
		$cfg = new Config();
		$items = $cfg->getData($cfg->defaultGetDataArgs);
		$data = array();
		foreach(array_keys($resources[$type]) as $id) {
			if($name != '*' &&
			   ! preg_match("/^$name$/i", $items[$id]['name']))
				continue;
			if(array_key_exists($id, $items)) {
				if($cluster == -1 ||
				   ($cluster == 0 && $items[$id]['configtype'] != 'Cluster') ||
				   ($cluster == 1 && $items[$id]['configtype'] == 'Cluster'))
					$data[$id] = $items[$id];
			}
		}
	}
	#elseif ...
	if($subid == 0) {
		sendREST(dataToJSON($data));
		return;
	}
	sendREST(dataToJSON($data[$subid], 1));
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn RESTdeleteResource($type, $subid)
///
/// \param $type - resource type
/// \param $subid - id of resource (from that resource's table, not the general
/// resource table)
///
/// \return 1 on success, 0 on failure
///
/// \brief toggles delete flag for a resource or deletes it if that type does
/// not handle being flagged as deleted
///
////////////////////////////////////////////////////////////////////////////////
function RESTdeleteResource($type, $subid) {
	switch($type) {
		case 'image':
			$obj = new Image();
			break;
		# TODO
	}
	$_SESSION['userresources'] = array();
	return $obj->toggleDeleteResource($subid);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn processRESTarg($index, $type, $defaultvalue=NULL)
///
/// \param $index - index in URL path
/// \param $type - tag type:\n
/// \b ARG_NUMERIC - numeric\n
/// \b ARG_STRING - string\n
/// \b ARG_MULTINUMERIC - an array of numbers
/// \param $defaultvalue - (optional, defaults to NULL) default value for the
/// variable
///
/// \return sanitized value
///
/// \brief wrapper for processInputData
///
////////////////////////////////////////////////////////////////////////////////
function processRESTarg($index, $type, $defaultvalue=NULL) {
	if(! array_key_exists("PATH_INFO", $_SERVER))
		return $defaultvalue;
	$pathdata = explode("/", $_SERVER["PATH_INFO"]);
	if(! array_key_exists($index + 1, $pathdata))
		return $defaultvalue;
	return processInputData($pathdata[$index + 1], $type, $defaultvalue);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn validatetype($type)
///
/// \param $type - resource type
///
/// \return $type if valid, NULL if not
///
/// \brief validates that $type is a know resource type
///
////////////////////////////////////////////////////////////////////////////////
function validatetype($type) {
	$types = getTypes('resources');
	if(! in_array($type, $types['resources']))
		return NULL;
	return $type;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn RESTresponse($code, $reason="")
///
/// \param $code - HTTP response code
/// \param $reason - (optional, default='') reason for given response; sets
/// X-Status-Reason response header
///
/// \brief sets the HTTP response header and reason for response if $reason is
/// not empty
///
////////////////////////////////////////////////////////////////////////////////
function RESTresponse($code, $reason="") {
	global $RESTresponsecodes;
	$response = "HTTP/1.1 $code {$RESTresponsecodes[$code]}";
	header($response);
	if($reason != "")
		header("X-Status-Reason: $reason");
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn sendREST($arr)
///
/// \param $arr - array of data
///
/// \brief sends $arr as JSON formatted data
///
////////////////////////////////////////////////////////////////////////////////
function sendREST($arr) {
	sendJSON($arr, '', 1);
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn dataToJSON($arr, $rec=0)
///
/// \param $arr - array of data
/// \param $rec - (optional, default=0) 
///
/// \return array
///
/// \brief formats an array for better encoding to JSON
///
////////////////////////////////////////////////////////////////////////////////
function dataToJSON($arr, $rec=0) {
	$jarr = array();
	foreach($arr as $key => $val) {
		if(is_array($val)) {
			if(empty($val)) {
				$jarr[$key] = $val;
				continue;
			}
			$tmp = array_keys($val);
			if(is_array($val[$tmp[0]])) {
				#printArray($val[$tmp[0]]);
				$jarr[$key] = dataToJSON($val, 1);
			}
			else {
				if(is_numeric($key)) {
					#print "key: $key - rec: $rec<br>\n";
					#printArray($val);
					$jarr[] = dataToJSON($val, 1);
				}
				else {
					$test = array_slice($val, 0);
					if($test === $val)
						$jarr[$key] = $val;
					else
						$jarr[$key] = dataToJSON($val);
				}
			}
			#$jarr[] = $val;
			#$jarr[$key] = dataToJSON($val, 1);
		}
		elseif($rec)
			$jarr[$key] = $val;
		else
			$jarr[] = array('id' => $key, 'name' => $val);
	}
	return $jarr;
}
?>
