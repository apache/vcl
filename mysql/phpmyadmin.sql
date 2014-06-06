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

/*
DESCRIPTION

This file can be imported into the phpmyadmin database if phpMyAdmin is used
to access the VCL database. It adds rows to the pma_table_info table in the
phpmyadmin database. These rows cause the corresponding values to appear when
the mouse hovers over them if the column is linked to another column via a
constraint.

These columns are added when you manually configure the "Choose field to
display" value for a table:
-Select a table in phpMyAdmin
-Click the Structure tab
-Click Relation view
-Choose field to display
*/

--
-- Database: `phpmyadmin`
--

use `phpmyadmin`;

-- --------------------------------------------------------

--
-- Dumping data for table `pma_table_info`
--

INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES
('vcl', 'IMtype', 'name'),
('vcl', 'OS', 'prettyname'),
('vcl', 'OSinstalltype', 'name'),
('vcl', 'OStype', 'name'),
('vcl', 'adminlevel', 'name'),
('vcl', 'affiliation', 'name'),
('vcl', 'blockComputers', 'computerid'),
('vcl', 'blockRequest', 'name'),
('vcl', 'blockTimes', 'start'),
('vcl', 'computer', 'hostname'),
('vcl', 'computerloadstate', 'loadstatename'),
('vcl', 'connectlog', 'reservationid'),
('vcl', 'connectmethod', 'name'),
('vcl', 'image', 'prettyname'),
('vcl', 'imagerevision', 'imagename'),
('vcl', 'imagetype', 'name'),
('vcl', 'localauth', 'userid'),
('vcl', 'managementnode', 'hostname'),
('vcl', 'module', 'prettyname'),
('vcl', 'platform', 'name'),
('vcl', 'privnode', 'name'),
('vcl', 'provisioning', 'name'),
('vcl', 'request', 'userid'),
('vcl', 'reservation', 'requestid'),
('vcl', 'reservationaccounts', 'reservationid'),
('vcl', 'resource', 'subid'),
('vcl', 'resourcegroup', 'name'),
('vcl', 'resourcegroupmembers', 'resourcegroupid'),
('vcl', 'resourcepriv', 'type'),
('vcl', 'resourcetype', 'name'),
('vcl', 'schedule', 'name'),
('vcl', 'scheduletimes', 'scheduleid'),
('vcl', 'serverrequest', 'requestid'),
('vcl', 'shibauth', 'id'),
('vcl', 'state', 'name'),
('vcl', 'subimages', 'imagemetaid'),
('vcl', 'user', 'unityid'),
('vcl', 'usergroup', 'name'),
('vcl', 'usergroupmembers', 'usergroupid'),
('vcl', 'userpriv', 'userid'),
('vcl', 'userprivtype', 'name'),
('vcl', 'variable', 'name'),
('vcl', 'vmhost', 'computerid'),
('vcl', 'vmprofile', 'profilename'),
('vcl', 'vmtype', 'name');
