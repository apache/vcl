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

SET FOREIGN_KEY_CHECKS=0;

-- ========================================================

INSERT IGNORE INTO `module` (`name`, prettyname, perlpackage) VALUES ('provisioning_base', 'Base Provisioning Module', 'VCL::Module::Provisioning');

-- ========================================================

--
-- Table structure for table `config`
--

CREATE TABLE IF NOT EXISTS `config` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(60) NOT NULL,
  `description` text,
  `ownerid` mediumint(8) unsigned NOT NULL DEFAULT '1',
  `configtypeid` tinyint(4) unsigned NOT NULL,
  `data` text,
  `optional` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `deleted` tinyint(1) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `configtypeid` (`configtypeid`),
  KEY `ownerid` (`ownerid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='config templates';

-- --------------------------------------------------------

--
-- Table structure for table `configinstance`
--

CREATE TABLE IF NOT EXISTS `configinstance` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `reservationid` mediumint(8) unsigned NOT NULL,
  `configid` mediumint(8) unsigned NOT NULL,
  `configmapid` mediumint(8) unsigned NOT NULL,
  `configinstancestatusid` smallint(5) unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `configmapid` (`configmapid`),
  KEY `configinstancestatusid` (`configinstancestatusid`),
  KEY `reservationid` (`reservationid`),
  KEY `configid` (`configid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `configinstancestatus`
--

CREATE TABLE IF NOT EXISTS `configinstancestatus` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(45) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_UNIQUE` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

--
-- Dumping data for table `configinstancestatus`
--

INSERT IGNORE INTO `configinstancestatus` (`name`) VALUES('active');
INSERT IGNORE INTO `configinstancestatus` (`name`) VALUES('complete');
INSERT IGNORE INTO `configinstancestatus` (`name`) VALUES('failed');
INSERT IGNORE INTO `configinstancestatus` (`name`) VALUES('queued');

-- --------------------------------------------------------

--
-- Table structure for table `configinstancesubimage`
--

CREATE TABLE IF NOT EXISTS `configinstancesubimage` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `configinstanceid` mediumint(8) unsigned NOT NULL,
  `configsubimageid` mediumint(8) unsigned NOT NULL,
  `reservationid` mediumint(8) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `configinstanceid` (`configinstanceid`),
  KEY `configsubimageid` (`configsubimageid`),
  KEY `reservationid` (`reservationid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `configinstancevariable`
--

CREATE TABLE IF NOT EXISTS `configinstancevariable` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `configinstanceid` mediumint(8) unsigned NOT NULL,
  `configvariableid` mediumint(8) unsigned NOT NULL,
  `value` text,
  PRIMARY KEY (`id`),
  KEY `configvariableid` (`configvariableid`),
  KEY `configinstanceid` (`configinstanceid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `configmap`
--

CREATE TABLE IF NOT EXISTS `configmap` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `configid` mediumint(8) unsigned NOT NULL,
  `configmaptypeid` smallint(5) unsigned NOT NULL,
  `subid` mediumint(8) unsigned NOT NULL,
  `affiliationid` mediumint(8) unsigned DEFAULT NULL,
  `disabled` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `configstageid` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `configid_UNIQUE` (`configid`,`configmaptypeid`,`subid`,`affiliationid`),
  KEY `affiliationid` (`affiliationid`),
  KEY `configstageid` (`configstageid`),
  KEY `configmaptypeid` (`configmaptypeid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `configmaporder`
--

CREATE TABLE IF NOT EXISTS `configmaporder` (
  `configmapid1` mediumint(8) unsigned NOT NULL,
  `configmapid2` mediumint(8) unsigned NOT NULL,
  `checkallreservations` tinyint(1) unsigned NOT NULL DEFAULT '0',
  KEY `configmapid1` (`configmapid1`),
  KEY `configmapid2` (`configmapid2`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `configmaptype`
--

CREATE TABLE IF NOT EXISTS `configmaptype` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_UNIQUE` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

--
-- Dumping data for table `configmaptype`
--

INSERT IGNORE INTO `configmaptype` (`name`) VALUES('image');
INSERT IGNORE INTO `configmaptype` (`name`) VALUES('OS');
INSERT IGNORE INTO `configmaptype` (`name`) VALUES('OStype');
INSERT IGNORE INTO `configmaptype` (`name`) VALUES('reservation');
INSERT IGNORE INTO `configmaptype` (`name`) VALUES('config');
INSERT IGNORE INTO `configmaptype` (`name`) VALUES('configsubimage');
INSERT IGNORE INTO `configmaptype` (`name`) VALUES('managementnode');

-- --------------------------------------------------------

--
-- Table structure for table `configstage`
--

CREATE TABLE IF NOT EXISTS `configstage` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(45) NOT NULL,
  `description` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_UNIQUE` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

--
-- Dumping data for table `configstage`
--

INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('reservation_start', 'start of reservation') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('reservation_end', 'end of reservation') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('before_user_shutdown', 'before user-initiated computer shutdown') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('after_user_shutdown', 'after user-initiated computer shutdown') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('before_user_reboot', 'before user-initiated computer reboot') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('after_user_reboot', 'after user-initiated computer reboot') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('before_reserve', 'after image is loaded, before user accounts are added') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('after_reserve', 'after user accounts are added, before checking for acknowledgment by user') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('before_check_connection', 'after reservation has been acknowledged by user, before checking for user connection') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('after_user_connection', 'after user connects') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('after_timeout_noack', 'after reservation times out because user never acknowledged') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('after_timeout_disconnected', 'after reservation times out because user disconnected') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('before_sanitize', 'before computer is sanitized when being reclaimed') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('after_sanitize', 'after computer is sanitized when being reclaimed') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('before_os_pre_capture', 'before OS steps are performed during image capture') ON DUPLICATE KEY UPDATE description=VALUES(description);
INSERT IGNORE INTO `configstage` (`name`, `description`) VALUES('post_os_pre_capture', 'after OS steps are completed during image capture') ON DUPLICATE KEY UPDATE description=VALUES(description);

-- --------------------------------------------------------

--
-- Table structure for table `configsubimage`
--

CREATE TABLE IF NOT EXISTS `configsubimage` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `configid` mediumint(8) unsigned NOT NULL,
  `imageid` smallint(5) unsigned NOT NULL,
  `mininstance` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `maxinstance` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `description` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `imageid` (`imageid`),
  KEY `configid` (`configid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `configtype`
--

CREATE TABLE IF NOT EXISTS `configtype` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(128) NOT NULL,
  `prettyname` varchar(40) NOT NULL,
  `description` varchar(256) DEFAULT NULL,
  `moduleid` smallint(5) unsigned DEFAULT NULL,
  `function` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_UNIQUE` (`name`),
  KEY `moduleid` (`moduleid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

--
-- Dumping data for table `configtype`
--

INSERT IGNORE INTO `configtype` (`name`, `prettyname`, `description`, `moduleid`, `function`) VALUES('cluster', 'Cluster', NULL, NULL, NULL);
INSERT IGNORE INTO `configtype` (`name`, `prettyname`, `description`, `moduleid`, `function`) VALUES('os_command', 'OS Command', NULL, (SELECT `id` FROM `module` WHERE `perlpackage` = 'VCL::Module::OS'), 'execute');
INSERT IGNORE INTO `configtype` (`name`, `prettyname`, `description`, `moduleid`, `function`) VALUES('os_module_function', 'OS Module Function', NULL, (SELECT `id` FROM `module` WHERE `perlpackage` = 'VCL::Module::OS'), '<FUNCTION>');
INSERT IGNORE INTO `configtype` (`name`, `prettyname`, `description`, `moduleid`, `function`) VALUES('provisioning_module_function', 'Provisioning Module Function', NULL, (SELECT `id` FROM `module` WHERE `perlpackage` = 'VCL::Module::Provisioning'), '<FUNCTION>');

-- --------------------------------------------------------

--
-- Table structure for table `configvariable`
--

CREATE TABLE IF NOT EXISTS `configvariable` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `description` varchar(128) DEFAULT NULL,
  `configid` mediumint(8) unsigned NOT NULL,
  `type` enum('auto','user') NOT NULL DEFAULT 'user',
  `datatypeid` tinyint(3) unsigned NOT NULL,
  `defaultvalue` varchar(1024) DEFAULT NULL,
  `required` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `identifier` varchar(255) DEFAULT NULL,
  `ask` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `configid_name_UNIQUE` (`name`,`configid`),
  KEY `configid` (`configid`),
  KEY `datatypeid` (`datatypeid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Triggers `configvariable`
--
DROP TRIGGER IF EXISTS `set_configvariable_identifier`;
DELIMITER //
CREATE TRIGGER `set_configvariable_identifier` BEFORE INSERT ON `configvariable`
 FOR EACH ROW BEGIN
      SET NEW.identifier = CONCAT('<', REPLACE(NEW.name, ' ', ''), '-', NEW.configid, '>');
    END
//
DELIMITER ;
DROP TRIGGER IF EXISTS `update_configvariable_identifier`;
DELIMITER //
CREATE TRIGGER `update_configvariable_identifier` BEFORE UPDATE ON `configvariable`
 FOR EACH ROW BEGIN
      SET NEW.identifier = CONCAT('<', REPLACE(NEW.name, ' ', ''), '-', NEW.configid, '>');
    END
//
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `datatype`
--

CREATE TABLE IF NOT EXISTS `datatype` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `description` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name_UNIQUE` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

--
-- Dumping data for table `datatype`
--

INSERT IGNORE INTO `datatype` (`name`, `description`) VALUES('bool', NULL);
INSERT IGNORE INTO `datatype` (`name`, `description`) VALUES('int', NULL);
INSERT IGNORE INTO `datatype` (`name`, `description`) VALUES('float', NULL);
INSERT IGNORE INTO `datatype` (`name`, `description`) VALUES('string', NULL);
INSERT IGNORE INTO `datatype` (`name`, `description`) VALUES('text', NULL);

-- ========================================================

--
-- Constraints for dumped tables
--

ALTER TABLE `config`
  ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configtypeid`) REFERENCES `configtype` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configtypeid`) REFERENCES `configtype` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configtypeid`) REFERENCES `configtype` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configtypeid`) REFERENCES `configtype` (`id`) ON UPDATE CASCADE;

ALTER TABLE `configinstance`
  ADD CONSTRAINT FOREIGN KEY (`reservationid`) REFERENCES `reservation` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configid`) REFERENCES `config` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configmapid`) REFERENCES `configmap` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configinstancestatusid`) REFERENCES `configinstancestatus` (`id`) ON UPDATE CASCADE;

ALTER TABLE `configinstancesubimage`
  ADD CONSTRAINT FOREIGN KEY (`reservationid`) REFERENCES `reservation` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configinstanceid`) REFERENCES `configinstance` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configsubimageid`) REFERENCES `configsubimage` (`id`) ON UPDATE CASCADE;

ALTER TABLE `configinstancevariable`
  ADD CONSTRAINT FOREIGN KEY (`configvariableid`) REFERENCES `configvariable` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configinstanceid`) REFERENCES `configinstance` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `configmap`
  ADD CONSTRAINT FOREIGN KEY (`configstageid`) REFERENCES `configstage` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configid`) REFERENCES `config` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configmaptypeid`) REFERENCES `configmaptype` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;

ALTER TABLE `configmaporder`
  ADD CONSTRAINT FOREIGN KEY (`configmapid2`) REFERENCES `configmap` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configmapid1`) REFERENCES `configmap` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `configsubimage`
  ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configid`) REFERENCES `config` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `configtype`
  ADD CONSTRAINT FOREIGN KEY (`moduleid`) REFERENCES `module` (`id`) ON UPDATE CASCADE;

ALTER TABLE `configvariable`
  ADD CONSTRAINT FOREIGN KEY (`datatypeid`) REFERENCES `datatype` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT FOREIGN KEY (`configid`) REFERENCES `config` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- ========================================================

SET FOREIGN_KEY_CHECKS=1;