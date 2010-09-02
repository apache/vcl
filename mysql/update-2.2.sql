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

-- Apache VCL version 2.1 to 2.2 database schema changes

-- --------------------------------------------------------

DELIMITER $$

/*
Procedure   : AddColumnIfNotExists
Parameters  : tableName, columnName, columnDefinition
Description : Adds a column to an existing table if a column with the same name
              does not already exist.
*/

DROP PROCEDURE IF EXISTS `AddColumnIfNotExists`$$
CREATE PROCEDURE `AddColumnIfNotExists`(
  IN tableName tinytext,
  IN columnName tinytext,
  IN columnDefinition text
)
BEGIN
  IF NOT EXISTS (
    SELECT * FROM information_schema.COLUMNS WHERE
    TABLE_SCHEMA=Database()
    AND COLUMN_NAME=columnName
    AND TABLE_NAME=tableName
  )
  THEN
    SET @statement_array = CONCAT('ALTER TABLE ', Database(), '.', tableName, ' ADD COLUMN ', columnName, ' ', columnDefinition);
    PREPARE statement_string FROM @statement_array;
    EXECUTE statement_string;
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : DropColumnIfExists
Parameters  : tableName, columnName
Description : Drops a column from an existing table.
*/

DROP PROCEDURE IF EXISTS `DropColumnIfExists`$$
CREATE PROCEDURE `DropColumnIfExists`(
  IN tableName tinytext,
  IN columnName tinytext
)
BEGIN
  IF EXISTS (
    SELECT * FROM information_schema.COLUMNS WHERE
    TABLE_SCHEMA=Database()
    AND COLUMN_NAME=columnName
    AND TABLE_NAME=tableName
  )
  THEN
    SET @statement_array = CONCAT('ALTER TABLE ', Database(), '.', tableName, ' DROP COLUMN ', columnName);
    PREPARE statement_string FROM @statement_array;
    EXECUTE statement_string;
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : AddIndexIfNotExists
Parameters  : tableName, columnName
Description : Adds an index to an existing table if an index for the column does
              not already exist.
*/

DROP PROCEDURE IF EXISTS `AddIndexIfNotExists`$$
CREATE PROCEDURE `AddIndexIfNotExists`(
  IN tableName tinytext,
  IN columnName tinytext
)
BEGIN
  IF NOT EXISTS (
    SELECT * FROM information_schema.KEY_COLUMN_USAGE WHERE
    TABLE_SCHEMA=Database()
    AND COLUMN_NAME=columnName
    AND TABLE_NAME=tableName
  )
  THEN
    SET @statement_array = CONCAT('ALTER TABLE ', Database(), '.', tableName, ' ADD INDEX (', columnName, ')');
    PREPARE statement_string FROM @statement_array;
    EXECUTE statement_string;
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : AddUniqueIndex
Parameters  : tableName, columnName
Description : Adds a unique index to an existing table if a primary or unique
              index does not already exist for the column. Any non-unique
              indices are dropped before the unique index is added.
*/

DROP PROCEDURE IF EXISTS `AddUniqueIndex`$$
CREATE PROCEDURE `AddUniqueIndex`(
  IN tableName tinytext,
  IN columnName tinytext
)
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE nonunique_index_name CHAR(16);
  
  DECLARE select_nonunique_index_names CURSOR FOR
    SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE
    TABLE_SCHEMA = Database()
    AND TABLE_NAME = tableName
    AND COLUMN_NAME = columnName
    AND NON_UNIQUE = 1;
  
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN select_nonunique_index_names;
  
  REPEAT
    FETCH select_nonunique_index_names INTO nonunique_index_name;
    IF NOT done THEN
      SET @drop_nonunique_index = CONCAT('ALTER TABLE ', Database(), '.', tableName, ' DROP INDEX ', nonunique_index_name);
      PREPARE drop_nonunique_index FROM @drop_nonunique_index;
      EXECUTE drop_nonunique_index;
    END IF;
  UNTIL done END REPEAT;
  
  CLOSE select_nonunique_index_names;
  
  IF NOT EXISTS (
    SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE
    TABLE_SCHEMA = Database()
    AND TABLE_NAME = tableName
    AND COLUMN_NAME = columnName
    AND NON_UNIQUE = 0
  )
  THEN
    SET @add_unique_index = CONCAT('ALTER TABLE ', Database(), '.', tableName, ' ADD UNIQUE (', columnName, ')');
    PREPARE add_unique_index FROM @add_unique_index;
    EXECUTE add_unique_index;
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : AddConstraintIfNotExists
Parameters  : tableName, columnName, referencedTableName, referencedColumnName
Description : Adds a foreign key constraint to an existing table if the
              constraint does not already exist.
*/

DROP PROCEDURE IF EXISTS `AddConstraintIfNotExists`$$
CREATE PROCEDURE `AddConstraintIfNotExists`(
  IN tableName tinytext,
  IN columnName tinytext,
  IN referencedTableName tinytext,
  IN referencedColumnName tinytext
)
BEGIN
  IF NOT EXISTS (
    SELECT * FROM information_schema.KEY_COLUMN_USAGE WHERE
    TABLE_SCHEMA=Database()
    AND TABLE_NAME=tableName
    AND COLUMN_NAME=columnName
    AND REFERENCED_TABLE_NAME=referencedTableName
    AND REFERENCED_COLUMN_NAME=referencedColumnName
  )
  THEN
    SET @statement_array = CONCAT('ALTER TABLE ', Database(), '.', tableName, ' ADD FOREIGN KEY (', columnName, ') REFERENCES ', Database(), '.', referencedTableName, ' (', referencedColumnName, ') ON UPDATE CASCADE');
    PREPARE statement_string FROM @statement_array;
    EXECUTE statement_string;
  END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
--  Table structure for table `affiliation`
--

CALL AddUniqueIndex('affiliation', 'name');

-- --------------------------------------------------------

--
--  Table structure for table `blockComputers`
--

CALL AddColumnIfNotExists('blockComputers', 'reloadrequestid', "mediumint(8) unsigned NOT NULL default '0'");

-- --------------------------------------------------------

--
--  Table structure for table `blockRequest`
--

CALL AddColumnIfNotExists('blockRequest', 'status', "enum('requested','accepted','completed','rejected','deleted') NOT NULL DEFAULT 'accepted'");

-- --------------------------------------------------------

--
--  Table structure for table `blockTimes`
--

CALL AddColumnIfNotExists('blockTimes', 'skip', "tinyint(1) unsigned NOT NULL default '0'");

-- --------------------------------------------------------

-- 
--  Table structure for table `computer`
--

CALL DropColumnIfExists('computer', 'preferredimageid');
CALL AddIndexIfNotExists('computer', 'imagerevisionid');

-- Set the default values for the currentimage and next image columns to 'noimage'
SET @currentimageid_noimage = CONCAT('ALTER TABLE computer CHANGE currentimageid currentimageid SMALLINT(5) UNSIGNED NOT NULL DEFAULT ', (SELECT id FROM image WHERE name LIKE 'noimage'));
PREPARE currentimageid_noimage FROM @currentimageid_noimage;
EXECUTE currentimageid_noimage;

SET @nextimageid_noimage = CONCAT('ALTER TABLE computer CHANGE nextimageid nextimageid SMALLINT(5) UNSIGNED NOT NULL DEFAULT ', (SELECT id FROM image WHERE name LIKE 'noimage'));
PREPARE nextimageid_noimage FROM @nextimageid_noimage;
EXECUTE nextimageid_noimage;

-- --------------------------------------------------------

--
-- Table structure for table `loginlog`
--
 
CREATE TABLE IF NOT EXISTS `loginlog` (
  `user` varchar(50) NOT NULL,
  `authmech` varchar(30) NOT NULL,
  `affiliationid` mediumint(8) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP,
  `passfail` tinyint(1) unsigned NOT NULL default '0',
  `remoteIP` varchar(15) NOT NULL,
  KEY `user` (`user`),
  KEY `affiliationid` (`affiliationid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure change for table `managementnode`
-- 

CALL AddColumnIfNotExists('managementnode', 'publicIPconfiguration', "enum('dynamicDHCP','manualDHCP','static') NOT NULL default 'dynamicDHCP'");
CALL AddColumnIfNotExists('managementnode', 'publicSubnetMask', "varchar(56) default NULL");
CALL AddColumnIfNotExists('managementnode', 'publicDefaultGateway', "varchar(56) default NULL");
CALL AddColumnIfNotExists('managementnode', 'publicDNSserver', "varchar(56) default NULL");
CALL AddColumnIfNotExists('managementnode', 'sysadminEmailAddress', "varchar(128) default NULL");
CALL AddColumnIfNotExists('managementnode', 'sharedMailBox', "varchar(128) default NULL");
CALL AddColumnIfNotExists('managementnode', 'NOT_STANDALONE', "varchar(128) default NULL");

-- --------------------------------------------------------

--
-- Table structure change for table `module`
--

CALL AddUniqueIndex('module', 'name');

-- --------------------------------------------------------

--
-- Table structure change for table `OS`
--

ALTER TABLE `OS` CHANGE `prettyname` `prettyname` varchar(64) NOT NULL default '';

-- --------------------------------------------------------

--
-- Table structure change for table `provisioning`
--

CALL AddUniqueIndex('provisioning', 'name');

-- --------------------------------------------------------

--
-- Table structure for table `sitemaintenance`
--

CREATE TABLE IF NOT EXISTS `sitemaintenance` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `ownerid` mediumint(8) unsigned NOT NULL,
  `created` datetime NOT NULL,
  `reason` text,
  `usermessage` text NOT NULL,
  `informhoursahead` smallint(5) unsigned NOT NULL,
  `allowreservations` tinyint(1) unsigned NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `start` (`start`),
  KEY `end` (`end`),
  KEY `ownerid` (`ownerid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure change for table `request`
-- 

CALL AddColumnIfNotExists('request', 'checkuser', "tinyint(1) unsigned NOT NULL default '1'");

-- --------------------------------------------------------

-- 
-- Table structure change for table `vmhost`
-- 

ALTER TABLE `vmhost` CHANGE `vmprofileid` `vmprofileid` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '1';
CALL AddIndexIfNotExists('vmhost', 'vmprofileid');

-- --------------------------------------------------------

-- 
-- Table structure change for table `vmprofile`
-- 

CALL DropColumnIfExists('vmprofile', 'nasshare');
CALL AddColumnIfNotExists('vmprofile', 'repositorypath', "varchar(128) default NULL AFTER imageid");
CALL AddColumnIfNotExists('vmprofile', 'virtualswitch2', "varchar(80) NULL default NULL AFTER `virtualswitch1`");
CALL AddColumnIfNotExists('vmprofile', 'virtualswitch3', "varchar(80) NULL default NULL AFTER `virtualswitch2`");
CALL AddColumnIfNotExists('vmprofile', 'vmware_mac_eth0_generated', "tinyint(1) NOT NULL default '0'");
CALL AddColumnIfNotExists('vmprofile', 'vmware_mac_eth1_generated', "tinyint(1) NOT NULL default '0'");

-- --------------------------------------------------------

--
-- Table structure for table `winKMS`
--
CREATE TABLE IF NOT EXISTS `winKMS` (
  `affiliationid` mediumint(8) unsigned NOT NULL,
  `address` varchar(50) NOT NULL,
  `port` smallint(5) unsigned NOT NULL default '1688',
  UNIQUE KEY `affiliationid_address` (`affiliationid`,`address`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `winProductKey`
--

CREATE TABLE IF NOT EXISTS `winProductKey` (
  `affiliationid` mediumint(8) unsigned NOT NULL,
  `productname` varchar(100) NOT NULL,
  `productkey` varchar(100) NOT NULL,
  UNIQUE KEY `affiliationid_productname` (`affiliationid`,`productname`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Inserts for table `affiliation`
-- 

INSERT IGNORE INTO `affiliation` (`name`, `dataUpdateText`) VALUES ('Global', '');

-- --------------------------------------------------------

-- 
-- Inserts for table `module`
-- 

UPDATE IGNORE `module` SET `name` = 'provisioning_vmware_1x', `prettyname` = 'VMware Server 1.x Provisioning Module' WHERE `name` = 'provisioning_vmware_gsx';
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_win7', 'Windows 7 OS Module', '', 'VCL::Module::OS::Windows::Version_6::7');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_xcat_2x', 'xCAT 2.x Provisioning Module', '', 'VCL::Module::Provisioning::xCAT2');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_vmware_vsphere', 'VMware vSphere Provisioning Module', '', 'VCL::Module::Provisioning::VMware::VMware');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('state_image', 'VCL Image State Module', '', 'VCL::image');

-- --------------------------------------------------------

-- 
-- Inserts for table `OS`
-- 

INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('win7', 'Windows 7', 'windows', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win7'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarewin7', 'VMware Windows 7', 'windows', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win7'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarelinux', 'VMware Generic Linux', 'linux', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarewin2003', 'VMware Windows 2003 Server', 'windows', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win2003'));

-- --------------------------------------------------------

--
-- Inserts for table `provisioning`
--

INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('xcat_2x', 'xCAT 2.x', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_xcat_2x'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('vmware_vsphere', 'VMware vSphere', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_vmware_vsphere'));

-- --------------------------------------------------------

--
-- Constraints for table `vmhost`
--
 
CALL AddConstraintIfNotExists('vmhost', 'vmprofileid', 'vmprofile', 'id');

-- --------------------------------------------------------

--
-- Constraints for table `winKMS`
--

CALL AddConstraintIfNotExists('winKMS', 'affiliationid', 'affiliation', 'id');
 
-- --------------------------------------------------------

--
-- Constraints for table `winProductKey`
--

CALL AddConstraintIfNotExists('winProductKey', 'affiliationid', 'affiliation', 'id');
 
-- --------------------------------------------------------

--
-- remove table xmlrpcKey
--

DROP TABLE IF EXISTS `xmlrpcKey`;

-- --------------------------------------------------------

--
-- Remove Procedures
--

DROP PROCEDURE IF EXISTS `AddColumnIfNotExists`;
DROP PROCEDURE IF EXISTS `DropColumnIfExists`;
DROP PROCEDURE IF EXISTS `AddIndexIfNotExists`;
DROP PROCEDURE IF EXISTS `AddConstraintIfNotExists`;
