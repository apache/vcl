-- # $Id$
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

-- ========================================================

use `phpmyadmin`;

INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'config', 'name');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configinstance', 'reservationid');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configinstancesubimage', 'configinstanceid');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configinstancevariable', 'configinstanceid');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configmaptype', 'name');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configstage', 'name');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configsubimage', 'configid');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configtype', 'name');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configvariable', 'identifier');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configmap', 'configid');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'configinstancestatus', 'name');
INSERT IGNORE INTO `pma_table_info` (`db_name`, `table_name`, `display_field`) VALUES('vcl', 'datatype', 'name');
