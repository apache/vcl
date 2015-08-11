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

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

-- 
-- Version: 2.4.2
-- 

-- 
-- Database: `vcl`
-- 

-- --------------------------------------------------------

-- 
-- Table structure for table `adminlevel`
-- 

CREATE TABLE IF NOT EXISTS `adminlevel` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(10) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `affiliation`
-- 

CREATE TABLE IF NOT EXISTS `affiliation` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `name` varchar(40) NOT NULL,
  `shibname` varchar(60) default NULL,
  `dataUpdateText` text NOT NULL,
  `sitewwwaddress` varchar(128) default NULL,
  `helpaddress` varchar(32) default NULL,
  `shibonly` tinyint(1) unsigned NOT NULL default '0',
  `theme` varchar(50) NOT NULL default 'default',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `blockComputers`
-- 

CREATE TABLE IF NOT EXISTS `blockComputers` (
  `blockTimeid` mediumint(8) unsigned NOT NULL default '0',
  `computerid` smallint(5) unsigned NOT NULL default '0',
  `imageid` smallint(5) unsigned NOT NULL default '0',
  `reloadrequestid` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`blockTimeid`,`computerid`),
  KEY `computerid` (`computerid`),
  KEY `imageid` (`imageid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `blockRequest`
-- 

CREATE TABLE IF NOT EXISTS `blockRequest` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `name` varchar(80) NOT NULL,
  `imageid` smallint(5) unsigned NOT NULL,
  `numMachines` tinyint(3) unsigned NOT NULL,
  `groupid` smallint(5) unsigned default NULL,
  `repeating` enum('weekly','monthly','list') NOT NULL default 'weekly',
  `ownerid` mediumint(8) unsigned NOT NULL,
  `managementnodeid` smallint(5) unsigned default NULL,
  `expireTime` datetime NOT NULL,
  `processing` tinyint(1) unsigned NOT NULL,
  `status` enum('requested','accepted','completed','rejected','deleted') NOT NULL DEFAULT 'accepted',
  `comments` text,
  PRIMARY KEY  (`id`),
  KEY `imageid` (`imageid`),
  KEY `groupid` (`groupid`),
  KEY `ownerid` (`ownerid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `blockTimes`
-- 

CREATE TABLE IF NOT EXISTS `blockTimes` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `blockRequestid` mediumint(8) unsigned NOT NULL,
  `start` datetime NOT NULL,
  `end` datetime NOT NULL,
  `processed` tinyint(1) unsigned NOT NULL default '0',
  `skip` tinyint(1) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `start` (`start`),
  KEY `end` (`end`),
  KEY `blockRequestid` (`blockRequestid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `blockWebDate`
-- 

CREATE TABLE IF NOT EXISTS `blockWebDate` (
  `blockRequestid` mediumint(8) unsigned NOT NULL,
  `start` date NOT NULL,
  `end` date NOT NULL,
  `days` tinyint(3) unsigned default NULL,
  `weeknum` tinyint(1) unsigned default NULL,
  KEY `blockRequestid` (`blockRequestid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `blockWebTime`
-- 

CREATE TABLE IF NOT EXISTS `blockWebTime` (
  `blockRequestid` mediumint(8) unsigned NOT NULL,
  `starthour` tinyint(2) unsigned NOT NULL,
  `startminute` tinyint(2) unsigned NOT NULL,
  `startmeridian` enum('am','pm') NOT NULL,
  `endhour` tinyint(2) unsigned NOT NULL,
  `endminute` tinyint(2) unsigned NOT NULL,
  `endmeridian` enum('am','pm') NOT NULL,
  `order` tinyint(3) unsigned NOT NULL,
  KEY `blockRequestid` (`blockRequestid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `changelog`
-- 

CREATE TABLE IF NOT EXISTS `changelog` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `logid` int(10) unsigned NOT NULL default '0',
  `userid` mediumint(8) unsigned DEFAULT NULL,
  `reservationid` mediumint(8) unsigned default NULL,
  `start` datetime default NULL,
  `end` datetime default NULL,
  `computerid` smallint(5) unsigned default NULL,
  `remoteIP` varchar(15) default NULL,
  `wasavailable` tinyint(1) unsigned default NULL,
  `timestamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `other` varchar(255) default NULL,
  PRIMARY KEY  (`id`),
  KEY `logid` (`logid`),
  KEY `userid` (`userid`),
  KEY `reservationid` (`reservationid`),
  KEY `computerid` (`computerid`),
  UNIQUE KEY reservation_user_remoteIP (userid,reservationid,remoteIP)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `clickThroughs`
-- 

CREATE TABLE IF NOT EXISTS `clickThroughs` (
  `userid` mediumint(8) unsigned NOT NULL default '0',
  `imageid` smallint(5) unsigned NOT NULL default '0',
  `imagerevisionid` mediumint(8) unsigned default NULL,
  `accepted` datetime NOT NULL default '0000-00-00 00:00:00',
  `agreement` text NOT NULL,
  KEY `userid` (`userid`),
  KEY `imagerevisionid` (`imagerevisionid`),
  KEY `imageid` (`imageid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `computer`
-- 

CREATE TABLE IF NOT EXISTS `computer` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `stateid` tinyint(5) unsigned NOT NULL default '10',
  `ownerid` mediumint(8) unsigned default '1',
  `platformid` tinyint(3) unsigned NOT NULL default '1',
  `scheduleid` tinyint(3) unsigned default NULL,
  `vmhostid` smallint(5) unsigned default NULL,
  `currentimageid` smallint(5) unsigned NOT NULL default '1',
  `nextimageid` smallint(5) unsigned NOT NULL default '1',
  `imagerevisionid` mediumint(8) unsigned NOT NULL default '1',
  `RAM` mediumint(8) unsigned NOT NULL default '0',
  `procnumber` tinyint(5) unsigned NOT NULL default '1',
  `procspeed` smallint(5) unsigned NOT NULL default '0',
  `network` smallint(5) unsigned NOT NULL default '100',
  `hostname` varchar(36) NOT NULL default '',
  `IPaddress` varchar(15) NOT NULL default '',
  `privateIPaddress` varchar(15) default NULL,
  `eth0macaddress` varchar(17) default NULL,
  `eth1macaddress` varchar(17) default NULL,
  `type` enum('blade','lab','virtualmachine') NOT NULL default 'blade',
  `provisioningid` smallint(5) unsigned NOT NULL,
  `drivetype` varchar(4) NOT NULL default 'hda',
  `deleted` tinyint(1) unsigned NOT NULL default '0',
  `datedeleted` DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
  `notes` text,
  `lastcheck` datetime default NULL,
  `location` varchar(255) default NULL,
  `dsa` mediumtext,
  `dsapub` mediumtext,
  `rsa` mediumtext,
  `rsapub` mediumtext,
  `host` blob,
  `hostpub` mediumtext,
  `vmtypeid` tinyint(3) unsigned default NULL,
  `predictivemoduleid` smallint(5) unsigned NOT NULL default '9',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `hostname` (`hostname`, `datedeleted`),
  UNIQUE KEY `eth1macaddress` (`eth1macaddress`, `datedeleted`),
  UNIQUE KEY `eth0macaddress` (`eth0macaddress`, `datedeleted`),
  KEY `ownerid` (`ownerid`),
  KEY `stateid` (`stateid`),
  KEY `platformid` (`platformid`),
  KEY `scheduleid` (`scheduleid`),
  KEY `currentimageid` (`currentimageid`),
  KEY `predictivemoduleid` (`predictivemoduleid`),
  KEY `type` (`type`),
  KEY `vmhostid` (`vmhostid`),
  KEY `vmtypeid` (`vmtypeid`),
  KEY `deleted` (`deleted`),
  KEY `nextimageid` (`nextimageid`),
  KEY `provisioningid` (`provisioningid`),
  KEY `imagerevisionid` (`imagerevisionid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `computerloadflow`
-- 

CREATE TABLE IF NOT EXISTS `computerloadflow` (
  `computerloadstateid` smallint(8) unsigned NOT NULL,
  `nextstateid` smallint(8) unsigned default NULL,
  `type` enum('blade','lab','virtualmachine') default NULL,
  KEY `computerloadstateid` (`computerloadstateid`),
  KEY `nextstateid` (`nextstateid`),
  KEY `type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `computerloadlog`
-- 

CREATE TABLE IF NOT EXISTS `computerloadlog` (
  `id` int(12) unsigned NOT NULL auto_increment,
  `reservationid` mediumint(8) unsigned NOT NULL,
  `computerid` smallint(8) unsigned NOT NULL,
  `loadstateid` smallint(8) unsigned NOT NULL,
  `timestamp` datetime default NULL,
  `additionalinfo` text,
  PRIMARY KEY  (`id`),
  KEY `reservationid` (`reservationid`),
  KEY `loadstateid` (`loadstateid`),
  KEY `computerid` (`computerid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `computerloadstate`
-- 

CREATE TABLE IF NOT EXISTS `computerloadstate` (
  `id` smallint(8) unsigned NOT NULL auto_increment,
  `loadstatename` varchar(24) NOT NULL,
  `prettyname` varchar(50) default NULL,
  `est` tinyint(2) unsigned default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `loadstatename` (`loadstatename`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table 'connectlog'
--

CREATE TABLE IF NOT EXISTS connectlog (
  id int(10) unsigned NOT NULL AUTO_INCREMENT,
  logid int(10) unsigned NOT NULL,
  reservationid mediumint(8) unsigned NOT NULL,
  userid mediumint(8) unsigned DEFAULT NULL,
  remoteIP varchar(39) NOT NULL,
  verified tinyint(1) NOT NULL,
  `timestamp` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (id),
  UNIQUE KEY reservationid_1 (reservationid,userid,remoteIP),
  KEY reservationid (reservationid),
  KEY userid (userid),
  KEY logid (logid)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `connectmethod`
--

CREATE TABLE IF NOT EXISTS `connectmethod` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(80) NOT NULL,
  `description` varchar(255) NOT NULL,
  `connecttext` text NOT NULL,
  `servicename` varchar(32) NOT NULL,
  `startupscript` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`,`description`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `connectmethodmap`
--

CREATE TABLE IF NOT EXISTS `connectmethodmap` (
  `connectmethodid` tinyint(3) unsigned NOT NULL,
  `OStypeid` tinyint(3) unsigned default NULL,
  `OSid` tinyint(3) unsigned default NULL,
  `imagerevisionid` mediumint(8) unsigned default NULL,
  `disabled` tinyint(1) unsigned NOT NULL default '0',
  `autoprovisioned` tinyint(1) unsigned default NULL,
  KEY `connectmethodid` (`connectmethodid`),
  KEY `OStypeid` (`OStypeid`),
  KEY `OSid` (`OSid`),
  KEY `imagerevisionid` (`imagerevisionid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `connectmethodport`
--

CREATE TABLE IF NOT EXISTS `connectmethodport` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `connectmethodid` tinyint(3) unsigned NOT NULL,
  `port` mediumint(8) unsigned NOT NULL,
  `protocol` enum('TCP','UDP') NOT NULL default 'TCP',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `connectmethodid_port_protocol` (`connectmethodid`,`port`,`protocol`),
  KEY `connectmethodid` (`connectmethodid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `continuations`
-- 

CREATE TABLE IF NOT EXISTS `continuations` (
  `id` varchar(255) NOT NULL default '',
  `userid` mediumint(8) unsigned NOT NULL default '0',
  `expiretime` datetime NOT NULL default '0000-00-00 00:00:00',
  `frommode` varchar(50) NOT NULL default '',
  `tomode` varchar(50) NOT NULL default '',
  `data` text NOT NULL,
  `multicall` tinyint(1) unsigned NOT NULL default '1',
  `parentid` varchar(255) default NULL,
  `deletefromid` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `parentid` (`parentid`),
  KEY `userid` (`userid`),
  KEY `expiretime` (`expiretime`),
  KEY `deletefromid` (`deletefromid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


-- --------------------------------------------------------

-- 
-- Table structure for table `documentation`
-- 

CREATE TABLE IF NOT EXISTS `documentation` (
  `name` varchar(255) NOT NULL,
  `title` varchar(255) NOT NULL,
  `data` text NOT NULL,
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `image`
-- 

CREATE TABLE IF NOT EXISTS `image` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(70) NOT NULL default '',
  `prettyname` varchar(80) NOT NULL default '',
  `ownerid` mediumint(8) unsigned default '1',
  `imagetypeid` smallint(5) unsigned NOT NULL default '1',
  `platformid` tinyint(3) unsigned NOT NULL default '1',
  `OSid` tinyint(3) unsigned NOT NULL default '0',
  `imagemetaid` smallint(5) unsigned default NULL,
  `minram` mediumint(8) unsigned NOT NULL default '0',
  `minprocnumber` tinyint(3) unsigned NOT NULL default '0',
  `minprocspeed` smallint(5) unsigned NOT NULL default '0',
  `minnetwork` smallint(3) unsigned NOT NULL default '0',
  `maxconcurrent` tinyint(3) unsigned default NULL,
  `reloadtime` tinyint(3) unsigned NOT NULL default '10',
  `deleted` tinyint(1) unsigned NOT NULL default '0',
  `test` tinyint(1) unsigned NOT NULL default '0',
  `lastupdate` datetime default NULL,
  `forcheckout` tinyint(1) unsigned NOT NULL default '1',
  `maxinitialtime` smallint(5) unsigned NOT NULL default '0',
  `project` enum('vcl','hpc','vclhpc') NOT NULL default 'vcl',
  `size` smallint(5) unsigned NOT NULL default '0',
  `architecture` enum('x86','x86_64') NOT NULL default 'x86',
  `description` text,
  `usage` text,
  `basedoffrevisionid` mediumint(8) unsigned default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `prettyname` (`prettyname`),
  KEY `ownerid` (`ownerid`),
  KEY `platformid` (`platformid`),
  KEY `OSid` (`OSid`),
  KEY `imagemetaid` (`imagemetaid`),
  KEY `imagetypeid` (`imagetypeid`),
  KEY `basedoffrevisionid` (`basedoffrevisionid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `imagemeta`
-- 

CREATE TABLE IF NOT EXISTS `imagemeta` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `checkuser` tinyint(1) unsigned NOT NULL default '1',
  `subimages` tinyint(1) unsigned NOT NULL default '0',
  `sysprep` tinyint(1) unsigned NOT NULL default '1',
  `postoption` varchar(32) default NULL,
  `architecture` varchar(10) default NULL,
  `rootaccess` tinyint(1) unsigned NOT NULL default '1',
  `sethostname` tinyint(1) unsigned default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `imagerevision`
-- 

CREATE TABLE IF NOT EXISTS `imagerevision` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `imageid` smallint(5) unsigned NOT NULL,
  `revision` smallint(5) unsigned NOT NULL,
  `userid` mediumint(8) unsigned NOT NULL,
  `datecreated` datetime NOT NULL,
  `deleted` tinyint(1) unsigned NOT NULL,
  `datedeleted` datetime default NULL,
  `production` tinyint(1) unsigned NOT NULL,
  `comments` text,
  `imagename` varchar(75) NOT NULL,
  `autocaptured` tinyint(1) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `production` (`production`,`imagename`),
  UNIQUE KEY `imageid` (`imageid`,`revision`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `imagerevisioninfo`
--

CREATE TABLE IF NOT EXISTS `imagerevisioninfo` (
  `imagerevisionid` mediumint(8) unsigned NOT NULL,
  `usernames` varchar(512) DEFAULT NULL,
  `firewallenabled` varchar(20) NOT NULL,
  `timestamp` datetime NOT NULL,
  UNIQUE KEY `imagerevisionid` (`imagerevisionid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `imagetype`
--

CREATE TABLE IF NOT EXISTS `imagetype` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(16) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `IMtype`
-- 

CREATE TABLE IF NOT EXISTS `IMtype` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(20) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `localauth`
-- 

CREATE TABLE IF NOT EXISTS `localauth` (
  `userid` mediumint(8) unsigned NOT NULL default '0',
  `passhash` varchar(40) NOT NULL default '',
  `salt` varchar(8) NOT NULL default '',
  `lastupdated` datetime NOT NULL default '0000-00-00 00:00:00',
  `lockedout` tinyint(1) unsigned NOT NULL default '0',
  PRIMARY KEY  (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `log`
-- 

CREATE TABLE IF NOT EXISTS `log` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `userid` mediumint(8) unsigned NOT NULL default '0',
  `nowfuture` enum('now','future') NOT NULL default 'now',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `loaded` datetime default NULL,
  `initialend` datetime NOT NULL default '0000-00-00 00:00:00',
  `finalend` datetime NOT NULL default '0000-00-00 00:00:00',
  `wasavailable` tinyint(1) unsigned NOT NULL default '0',
  `ending` enum('deleted','released','failed','failedtest','noack','nologin','timeout','EOR','none') NOT NULL default 'none',
  `requestid` mediumint(8) unsigned default NULL,
  `computerid` smallint(5) unsigned default NULL,
  `remoteIP` varchar(15) default NULL,
  `imageid` smallint(5) unsigned NOT NULL default '0',
  `size` smallint(5) unsigned NOT NULL default '1450',
  PRIMARY KEY  (`id`),
  KEY `userid` (`userid`),
  KEY `computerid` (`computerid`),
  KEY `imageid` (`imageid`),
  KEY `finalend` (`finalend`),
  KEY `start` (`start`),
  KEY `wasavailable` (`wasavailable`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

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
  `code` enum('none','invalid credentials') NOT NULL DEFAULT 'none',
  KEY `user` (`user`),
  KEY `affiliationid` (`affiliationid`),
  KEY `timestamp` (`timestamp`),
  KEY `authmech` (`authmech`),
  KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `managementnode`
-- 

CREATE TABLE IF NOT EXISTS `managementnode` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `IPaddress` varchar(15) NOT NULL default '',
  `hostname` varchar(50) NOT NULL default '',
  `ownerid` mediumint(8) unsigned NOT NULL default '1',
  `stateid` tinyint(3) unsigned NOT NULL default '0',
  `lastcheckin` datetime default NULL,
  `checkininterval` tinyint(3) unsigned NOT NULL default '12',
  `installpath` varchar(100) NOT NULL default '/install',
  `imagelibenable` tinyint(1) unsigned NOT NULL default '0',
  `imagelibgroupid` smallint(5) unsigned default NULL,
  `imagelibuser` varchar(20) default 'vclstaff',
  `imagelibkey` varchar(100) default '/etc/vcl/imagelib.key',
  `keys` varchar(1024) default NULL,
  `sshport` smallint(5) unsigned NOT NULL default '22',
  `publicIPconfiguration` enum('dynamicDHCP','manualDHCP','static') NOT NULL default 'dynamicDHCP',
  `publicSubnetMask` varchar(56) default NULL,
  `publicDefaultGateway` varchar(56) default NULL,
  `publicDNSserver` varchar(56) default NULL,
  `sysadminEmailAddress` varchar(128) default NULL,
  `sharedMailBox` varchar(128) default NULL,
  `NOT_STANDALONE` varchar(128) default NULL,
  `availablenetworks` text NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `hostname` (`hostname`),
  KEY `stateid` (`stateid`),
  KEY `ownerid` (`ownerid`),
  KEY `imagelibgroupid` (`imagelibgroupid`),
  KEY `IPaddress` (`IPaddress`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `module`
--

CREATE TABLE IF NOT EXISTS `module` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(30) NOT NULL,
  `prettyname` varchar(70) NOT NULL,
  `description` varchar(255) NOT NULL,
  `perlpackage` varchar(150) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `nathost`
--

CREATE TABLE IF NOT EXISTS `nathost` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `resourceid` mediumint(8) unsigned NOT NULL,
  `publicIPaddress` varchar(15) NOT NULL,
  `internalIPaddress` varchar(15) DEFAULT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `resourceid` (`resourceid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `natlog`
-- 

CREATE TABLE IF NOT EXISTS `natlog` (
  `sublogid` int(10) unsigned NOT NULL,
  `nathostresourceid` mediumint(8) unsigned NOT NULL,
  `publicIPaddress` varchar(15) NOT NULL,
  `publicport` smallint(5) unsigned NOT NULL,
  `internalIPaddress` varchar(15) DEFAULT NULL,
  `internalport` smallint(5) unsigned NOT NULL,
  `protocol` enum('TCP','UDP') NOT NULL DEFAULT 'TCP',
  `timestamp` datetime NOT NULL,
  UNIQUE KEY `sublogid` (`sublogid`,`nathostresourceid`,`publicIPaddress`,`publicport`,`internalIPaddress`,`internalport`,`protocol`),
  KEY `logid` (`sublogid`),
  KEY `nathostid` (`nathostresourceid`),
  KEY `nathostresourceid` (`nathostresourceid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `nathostcomputermap`
-- 

CREATE TABLE IF NOT EXISTS `nathostcomputermap` (
  `nathostid` smallint(5) unsigned NOT NULL,
  `computerid` smallint(5) unsigned NOT NULL,
  UNIQUE KEY `computerid` (`computerid`,`nathostid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `natport`
--

CREATE TABLE IF NOT EXISTS `natport` (
  `reservationid` mediumint(8) unsigned NOT NULL,
  `nathostid` smallint(5) unsigned NOT NULL,
  `publicport` smallint(5) unsigned NOT NULL,
  `connectmethodportid` tinyint(3) unsigned NOT NULL,
  UNIQUE KEY `reservationid_connectmethodportid` (`reservationid`,`connectmethodportid`),
  UNIQUE KEY `nathostid_publicport` (`nathostid`,`publicport`),
  KEY `reservationid` (`reservationid`),
  KEY `connectmethodportid` (`connectmethodportid`),
  KEY `nathostid` (`nathostid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `openstackcomputermap`
--

CREATE TABLE IF NOT EXISTS `openstackcomputermap` (
  `instanceid` varchar(50) NOT NULL,
  `computerid` smallint(5) unsigned DEFAULT NULL,
  PRIMARY KEY (`instanceid`),
  UNIQUE KEY `computerid` (`computerid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `openstackimagerevision`
--

CREATE TABLE IF NOT EXISTS `openstackimagerevision` (
  `imagerevisionid` mediumint(8) unsigned NOT NULL,
  `imagedetails` text NOT NULL,
  `flavordetails` text NOT NULL,
  PRIMARY KEY (`imagerevisionid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `OS`
-- 

CREATE TABLE IF NOT EXISTS `OS` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(20) NOT NULL,
  `prettyname` varchar(64) NOT NULL default '',
  `type` varchar(30) NOT NULL,
  `installtype` varchar(30) NOT NULL default 'image',
  `minram` mediumint(8) unsigned NOT NULL DEFAULT '512',
  `sourcepath` varchar(30) default NULL,
  `moduleid` smallint(5) unsigned default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `prettyname` (`prettyname`),
  KEY `type` (`type`),
  KEY `installtype` (`installtype`),
  KEY `moduleid` (`moduleid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `OSinstalltype`
--

CREATE TABLE IF NOT EXISTS `OSinstalltype` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `OStype`
--

CREATE TABLE IF NOT EXISTS `OStype` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `platform`
-- 

CREATE TABLE IF NOT EXISTS `platform` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(20) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `privnode`
-- 

CREATE TABLE IF NOT EXISTS `privnode` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `parent` mediumint(8) unsigned NOT NULL default '0',
  `name` varchar(50) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `parent` (`parent`,`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 COMMENT='nodes for privilege tree';

-- --------------------------------------------------------

--
-- Table structure for table `provisioning`
--

CREATE TABLE IF NOT EXISTS `provisioning` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(30) NOT NULL,
  `prettyname` varchar(70) NOT NULL,
  `moduleid` smallint(5) unsigned NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `moduleid` (`moduleid`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `provisioningOSinstalltype`
--

CREATE TABLE IF NOT EXISTS `provisioningOSinstalltype` (
  `provisioningid` smallint(5) unsigned NOT NULL,
  `OSinstalltypeid` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY  (`provisioningid`,`OSinstalltypeid`),
  KEY `OSinstalltypeid` (`OSinstalltypeid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `querylog`
-- 

CREATE TABLE IF NOT EXISTS `querylog` (
  `userid` mediumint(8) unsigned NOT NULL default '0',
  `timestamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `mode` varchar(30) NOT NULL default '',
  `query` text NOT NULL,
  KEY `userid` (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `request`
-- 

CREATE TABLE IF NOT EXISTS `request` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `stateid` tinyint(3) unsigned NOT NULL default '0',
  `userid` mediumint(8) unsigned NOT NULL default '0',
  `laststateid` tinyint(3) unsigned NOT NULL default '0',
  `logid` int(10) unsigned NOT NULL default '0',
  `forimaging` tinyint(1) unsigned NOT NULL default '0',
  `test` tinyint(1) unsigned NOT NULL default '0',
  `preload` tinyint(1) unsigned NOT NULL default '0',
  `start` datetime NOT NULL default '0000-00-00 00:00:00',
  `end` datetime NOT NULL default '0000-00-00 00:00:00',
  `daterequested` datetime NOT NULL default '0000-00-00 00:00:00',
  `datemodified` datetime default NULL,
  `checkuser` tinyint(1) unsigned NOT NULL default '1',
  PRIMARY KEY  (`id`),
  KEY `userid` (`userid`),
  KEY `stateid` (`stateid`),
  KEY `laststateid` (`laststateid`),
  KEY `logid` (`logid`),
  KEY `start` (`start`),
  KEY `end` (`end`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `reservation`
-- 

CREATE TABLE IF NOT EXISTS `reservation` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `requestid` mediumint(8) unsigned NOT NULL default '0',
  `computerid` smallint(5) unsigned NOT NULL default '0',
  `imageid` smallint(5) unsigned NOT NULL default '0',
  `imagerevisionid` mediumint(8) unsigned NOT NULL default '0',
  `managementnodeid` smallint(5) unsigned NOT NULL default '1',
  `remoteIP` varchar(15) default NULL,
  `lastcheck` datetime default '0000-00-00 00:00:00',
  `pw` varchar(40) default NULL,
  `connectIP` varchar(15) default NULL,
  `connectport` smallint(5) unsigned default NULL,
  PRIMARY KEY  (`id`),
  KEY `managementnodeid` (`managementnodeid`),
  KEY `imageid` (`imageid`),
  KEY `requestid` (`requestid`),
  KEY `computerid` (`computerid`),
  KEY `imagerevisionid` (`imagerevisionid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `reservationaccounts`
--

CREATE TABLE IF NOT EXISTS `reservationaccounts` (
  `reservationid` mediumint(8) unsigned NOT NULL,
  `userid` mediumint(8) unsigned NOT NULL,
  `password` varchar(50) default NULL,
  UNIQUE KEY `reservationid` (`reservationid`,`userid`),
  KEY `userid` (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `resource`
-- 

CREATE TABLE IF NOT EXISTS `resource` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `resourcetypeid` tinyint(5) unsigned NOT NULL default '0',
  `subid` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `resourcetypeid` (`resourcetypeid`,`subid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `resourcegroup`
-- 

CREATE TABLE IF NOT EXISTS `resourcegroup` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(50) NOT NULL default '',
  `ownerusergroupid` smallint(5) unsigned NOT NULL default '39',
  `resourcetypeid` tinyint(3) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `resourcetypeid` (`resourcetypeid`,`name`),
  KEY `ownerusergroupid` (`ownerusergroupid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `resourcegroupmembers`
-- 

CREATE TABLE IF NOT EXISTS `resourcegroupmembers` (
  `resourceid` mediumint(8) unsigned NOT NULL default '0',
  `resourcegroupid` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`resourceid`,`resourcegroupid`),
  KEY `resourcegroupid` (`resourcegroupid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `resourcemap`
-- 

CREATE TABLE IF NOT EXISTS `resourcemap` (
  `resourcegroupid1` smallint(5) unsigned NOT NULL default '0',
  `resourcetypeid1` tinyint(3) unsigned NOT NULL default '13',
  `resourcegroupid2` smallint(5) unsigned NOT NULL default '0',
  `resourcetypeid2` tinyint(3) unsigned NOT NULL default '12',
  PRIMARY KEY  (`resourcegroupid1`,`resourcegroupid2`),
  KEY `resourcetypeid1` (`resourcetypeid1`),
  KEY `resourcetypeid2` (`resourcetypeid2`),
  KEY `resourcegroupid2` (`resourcegroupid2`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `resourcepriv`
-- 

CREATE TABLE IF NOT EXISTS `resourcepriv` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `resourcegroupid` smallint(5) unsigned NOT NULL default '0',
  `privnodeid` mediumint(8) unsigned NOT NULL default '0',
  `type` enum('block','cascade','available','administer','manageGroup','manageMapping') NOT NULL default 'block',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `resourcegroupid` (`resourcegroupid`,`privnodeid`,`type`),
  KEY `privnodeid` (`privnodeid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `resourcetype`
-- 

CREATE TABLE IF NOT EXISTS `resourcetype` (
  `id` tinyint(5) unsigned NOT NULL auto_increment,
  `name` varchar(50) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `schedule`
-- 

CREATE TABLE IF NOT EXISTS `schedule` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(25) NOT NULL default '',
  `ownerid` mediumint(8) unsigned NOT NULL default '1',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `ownerid` (`ownerid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `scheduletimes`
-- 

CREATE TABLE IF NOT EXISTS `scheduletimes` (
  `scheduleid` tinyint(3) unsigned NOT NULL default '0',
  `start` smallint(5) unsigned NOT NULL default '0',
  `end` smallint(5) unsigned NOT NULL default '0',
  KEY `scheduleid` (`scheduleid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `semaphore`
-- 

CREATE TABLE IF NOT EXISTS `semaphore` (
  `computerid` smallint(5) unsigned NOT NULL,
  `imageid` smallint(5) unsigned NOT NULL,
  `imagerevisionid` mediumint(8) unsigned NOT NULL,
  `managementnodeid` smallint(5) unsigned NOT NULL,
  `expires` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `procid` varchar(255) NOT NULL,
  KEY `computerid` (`computerid`),
  KEY `imageid` (`imageid`),
  KEY `imagerevisionid` (`imagerevisionid`),
  KEY `managementnodeid` (`managementnodeid`),
  KEY `expires` (`expires`),
  KEY `procid` (`procid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `serverprofile`
--

CREATE TABLE IF NOT EXISTS `serverprofile` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `description` text NOT NULL,
  `imageid` smallint(5) unsigned NOT NULL,
  `ownerid` mediumint(8) unsigned NOT NULL,
  `ending` enum('specified','indefinite') NOT NULL default 'specified',
  `fixedIP` varchar(15) default NULL,
  `fixedMAC` varchar(17) default NULL,
  `admingroupid` smallint(5) unsigned default NULL,
  `logingroupid` smallint(5) unsigned default NULL,
  `monitored` tinyint(1) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `ownerid` (`ownerid`),
  UNIQUE KEY `name` (`name`),
  KEY `admingroupid` (`admingroupid`),
  KEY `logingroupid` (`logingroupid`),
  KEY `imageid` (`imageid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `serverrequest`
--

CREATE TABLE IF NOT EXISTS `serverrequest` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `serverprofileid` smallint(5) unsigned NOT NULL default '0',
  `requestid` mediumint(8) unsigned NOT NULL,
  `fixedIP` varchar(15) default NULL,
  `fixedMAC` varchar(17) default NULL,
  `admingroupid` smallint(5) unsigned default NULL,
  `logingroupid` smallint(5) unsigned default NULL,
  `monitored` tinyint(1) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `requestid` (`requestid`),
  KEY `admingroupid` (`admingroupid`),
  KEY `logingroupid` (`logingroupid`),
  KEY `serverprofileid` (`serverprofileid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `shibauth`
--

CREATE TABLE IF NOT EXISTS `shibauth` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `userid` mediumint(8) unsigned NOT NULL,
  `ts` datetime NOT NULL,
  `sessid` varchar(80) NOT NULL,
  `data` text NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

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
-- Table structure for table `state`
-- 

CREATE TABLE IF NOT EXISTS `state` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(20) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `statgraphcache`
--

CREATE TABLE IF NOT EXISTS `statgraphcache` (
  `graphtype` enum('totalres','concurres','concurblade','concurvm') NOT NULL,
  `statdate` date NOT NULL,
  `affiliationid` mediumint(8) unsigned default NULL,
  `value` mediumint(8) unsigned NOT NULL,
  `provisioningid` smallint(5) unsigned default NULL,
  KEY `graphtype` (`graphtype`),
  KEY `statdate` (`statdate`),
  KEY `affiliationid` (`affiliationid`),
  KEY `provisioningid` (`provisioningid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `subimages`
-- 

CREATE TABLE IF NOT EXISTS `subimages` (
  `imagemetaid` smallint(5) unsigned NOT NULL default '0',
  `imageid` smallint(5) unsigned NOT NULL default '0',
  KEY `imagemetaid` (`imagemetaid`),
  KEY `imageid` (`imageid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `sublog`
-- 

CREATE TABLE IF NOT EXISTS `sublog` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `logid` int(10) unsigned NOT NULL default '0',
  `imageid` smallint(5) unsigned NOT NULL default '0',
  `imagerevisionid` mediumint(8) unsigned NOT NULL,
  `computerid` smallint(5) unsigned NOT NULL default '0',
  `IPaddress` varchar(15) default NULL,
  `managementnodeid` smallint(5) unsigned NOT NULL default '0',
  `predictivemoduleid` smallint(5) unsigned NOT NULL default '8',
  `hostcomputerid` smallint(5) unsigned default NULL,
  `blockRequestid` mediumint(8) unsigned default NULL,
  `blockStart` datetime default NULL,
  `blockEnd` datetime default NULL,
  PRIMARY KEY (`id`),
  KEY `logid` (`logid`),
  KEY `imageid` (`imageid`),
  KEY `imagerevisionid` (`imagerevisionid`),
  KEY `computerid` (`computerid`),
  KEY `managementnodeid` (`managementnodeid`),
  KEY `predictivemoduleid` (`predictivemoduleid`),
  KEY `hostcomputerid` (`hostcomputerid`),
  KEY `blockRequestid` (`blockRequestid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `user`
-- 

CREATE TABLE IF NOT EXISTS `user` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `uid` int(10) unsigned default NULL,
  `unityid` varchar(80) NOT NULL default '',
  `affiliationid` mediumint(8) unsigned NOT NULL default '1',
  `firstname` varchar(20) NOT NULL default '',
  `lastname` varchar(25) NOT NULL default '',
  `preferredname` varchar(25) default NULL,
  `email` varchar(80) NOT NULL,
  `emailnotices` tinyint(1) unsigned NOT NULL default '1',
  `IMtypeid` tinyint(3) unsigned default NULL,
  `IMid` varchar(80) default NULL,
  `adminlevelid` tinyint(3) unsigned NOT NULL default '1',
  `width` smallint(4) unsigned NOT NULL default '1024',
  `height` smallint(4) unsigned NOT NULL default '768',
  `bpp` tinyint(2) unsigned NOT NULL default '16',
  `audiomode` enum('none','local') NOT NULL default 'local',
  `mapdrives` tinyint(1) unsigned NOT NULL default '1',
  `mapprinters` tinyint(1) unsigned NOT NULL default '1',
  `mapserial` tinyint(1) unsigned NOT NULL default '0',
  `rdpport` smallint(5) unsigned default NULL,
  `showallgroups` tinyint(1) unsigned NOT NULL default '0',
  `lastupdated` datetime NOT NULL default '0000-00-00 00:00:00',
  `validated` tinyint(1) unsigned NOT NULL default '1',
  `usepublickeys` tinyint(1) unsigned NOT NULL default '0',
  `sshpublickeys` text,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `unityid` (`unityid`,`affiliationid`),
  UNIQUE KEY `uid` (`uid`),
  KEY `IMtypeid` (`IMtypeid`),
  KEY `affiliationid` (`affiliationid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `usergroup`
-- 

CREATE TABLE IF NOT EXISTS `usergroup` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(60) NOT NULL,
  `affiliationid` mediumint(8) unsigned default NULL,
  `ownerid` mediumint(8) unsigned default NULL,
  `editusergroupid` smallint(5) unsigned default NULL,
  `custom` tinyint(1) unsigned NOT NULL default '0',
  `courseroll` tinyint(1) unsigned NOT NULL default '0',
  `initialmaxtime` mediumint(8) unsigned NOT NULL default '240',
  `totalmaxtime` mediumint(8) unsigned NOT NULL default '360',
  `maxextendtime` mediumint(8) unsigned NOT NULL default '60',
  `overlapResCount` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`,`affiliationid`),
  KEY `ownerid` (`ownerid`),
  KEY `editusergroupid` (`editusergroupid`),
  KEY `affiliationid` (`affiliationid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `usergroupmembers`
-- 

CREATE TABLE IF NOT EXISTS `usergroupmembers` (
  `userid` mediumint(8) unsigned NOT NULL default '0',
  `usergroupid` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`userid`,`usergroupid`),
  KEY `usergroupid` (`usergroupid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `usergrouppriv`
-- 

CREATE TABLE IF NOT EXISTS `usergrouppriv` (
  `usergroupid` smallint(5) unsigned NOT NULL,
  `userprivtypeid` tinyint(3) unsigned NOT NULL,
  UNIQUE KEY `usergroupid` (`usergroupid`,`userprivtypeid`),
  KEY `userprivtypeid` (`userprivtypeid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `usergroupprivtype`
-- 

CREATE TABLE IF NOT EXISTS `usergroupprivtype` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(50) NOT NULL,
  `help` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `userpriv`
-- 

CREATE TABLE IF NOT EXISTS `userpriv` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `userid` mediumint(8) unsigned default NULL,
  `usergroupid` smallint(5) unsigned default NULL,
  `privnodeid` mediumint(8) unsigned NOT NULL default '0',
  `userprivtypeid` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`,`privnodeid`,`userprivtypeid`),
  UNIQUE KEY `userid` (`userid`,`privnodeid`,`userprivtypeid`),
  UNIQUE KEY `usergroupid` (`usergroupid`,`privnodeid`,`userprivtypeid`),
  KEY `privnodeid` (`privnodeid`),
  KEY `userprivtypeid` (`userprivtypeid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `userprivtype`
-- 

CREATE TABLE IF NOT EXISTS `userprivtype` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(50) NOT NULL default '',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `variable`
--

CREATE TABLE IF NOT EXISTS `variable` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `name` varchar(128) NOT NULL,
  `serialization` enum('none','yaml','phpserialize') NOT NULL default 'none',
  `value` longtext NOT NULL,
  `setby` varchar(128) default NULL,
  `timestamp` datetime NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `vmhost`
-- 

CREATE TABLE IF NOT EXISTS `vmhost` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `computerid` smallint(5) unsigned NOT NULL,
  `vmlimit` smallint(5) unsigned NOT NULL,
  `vmprofileid` smallint(5) unsigned NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `computerid_vmprofileid` (`computerid`,`vmprofileid`),
  KEY `vmprofileid` (`vmprofileid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `vmprofile`
-- 

CREATE TABLE IF NOT EXISTS `vmprofile` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `profilename` varchar(56) NOT NULL,
  `imageid` smallint(5) unsigned NOT NULL,
  `resourcepath` varchar(256) default NULL,
  `folderpath` varchar(256) default NULL,
  `repositorypath` varchar(128) default NULL,
  `repositoryimagetypeid` smallint(5) unsigned NOT NULL default '1',
  `datastorepath` varchar(128) NOT NULL,
  `datastoreimagetypeid` smallint(5) unsigned NOT NULL default '1',
  `vmpath` varchar(128) default NULL,
  `virtualswitch0` varchar(80) NOT NULL default 'VMnet0',
  `virtualswitch1` varchar(80) NOT NULL default 'VMnet2',
  `virtualswitch2` varchar(80) NULL default NULL,
  `virtualswitch3` varchar(80) NULL default NULL,
  `vmdisk` enum('dedicated','shared') NOT NULL default 'dedicated',
  `username` varchar(80) NULL default NULL,
  `password` varchar(256) NULL default NULL,
  `eth0generated` tinyint(1) unsigned NOT NULL default '0',
  `eth1generated` tinyint(1) unsigned NOT NULL default '0',
  `rsapub` text NULL default NULL,
  `rsakey` varchar(256) NULL default NULL,
  `encryptedpasswd` text NULL default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `profilename` (`profilename`),
  KEY `imageid` (`imageid`),
  KEY `repositoryimagetypeid` (`repositoryimagetypeid`),
  KEY `datastoreimagetypeid` (`datastoreimagetypeid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `vmtype`
-- 

CREATE TABLE IF NOT EXISTS `vmtype` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

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
-- Table structure for table `xmlrpcLog`
-- 

CREATE TABLE IF NOT EXISTS `xmlrpcLog` (
  `xmlrpcKeyid` mediumint(8) unsigned NOT NULL default '0' COMMENT 'this is the userid if apiversion greater than 1',
  `timestamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `IPaddress` varchar(15) default NULL,
  `method` varchar(60) default NULL,
  `apiversion` tinyint(3) unsigned NOT NULL default '1',
  `comments` text,
  KEY `xmlrpcKeyid` (`xmlrpcKeyid`),
  KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- =========================================================
-- Data

-- 
-- Dumping data for table `adminlevel`
-- 

INSERT IGNORE INTO `adminlevel` (`id`, `name`) VALUES 
(3, 'developer'),
(2, 'full'),
(1, 'none');

-- 
-- Dumping data for table `affiliation`
-- 

INSERT IGNORE INTO `affiliation` (`id`, `name`, `dataUpdateText`, `theme`) VALUES 
(1, 'Local', '', 'default'),
(2, 'Global', '', 'default');


-- 
-- Dumping data for table `computerloadstate`
-- 

INSERT IGNORE INTO `computerloadstate` (`loadstatename`, `prettyname`, `est`) VALUES 
('info', 'info', 2),
('loadimageblade', 'must reload computer', 0),
('loadimagevmware', 'loadimagevmware', 1),
('statuscheck', 'computer status check', 10),
('assign2project', 'changing VLAN setting ', 0),
('rinstall', 'starting install process', 1),
('dynamicDHCPaddress', 'detecting dynamic IP address', 2),
('staticIPaddress', 'setting static IP address', 2),
('loadimagecomplete', 'running post configuration', 0),
('loadimagefailed', 'preparing computer failed', 2),
('failed', 'reservation failed', 2),
('bootstate', 'image loading', 175),
('editnodetype', 'edit config file to load requested image', 1),
('xcatstage1', 'detected dhcp request from node', 2),
('xcatstage2', 'rebooting node for reinstall', 100),
('WARNING', 'WARNING', 2),
('xcatREADY', 'computer reported READY starting post configs', 2),
('reserved', 'ready for Connect', 0),
('xcatstage3', 'node starting to received install instructions', 93),
('xcatstage4', 'node received install instructions', 0),
('xcatstage5', 'starting reload process', 27),
('doesimageexists', 'confirming image exists locally', 4),
('vmround1', 'vmround1', 1),
('vmround2', 'vmround2', 186),
('transfervm', 'transferring image files to host server', 255),
('vmsetupconfig', 'creating configuration file', 2),
('vmstage1', 'detected stage 1 of 5 loading process', 22),
('vmstage2', 'detected stage 2 of 5 loading process', 120),
('vmstage3', 'detected stage 3 of 4 loading process', 0),
('xcatround2', 'waiting for image loading to complete', 0),
('xcatround3', 'loaded - start post configuration', 0),
('xcatround1', 'xcatround1', 2),
('timeout', 'timeout', 2),
('vmwareready', 'machine online', 3),
('startload', 'starting load process', 6),
('addinguser', 'adding user account', 18),
('connected', 'detected user connection', 2),
('nodeready', 'resource ready', 0),
('inuseend10', '10 minute warning ', 2),
('inuseend5', '5 minute warning', 2),
('machinebooted', 'machine booting', 68),
('checklabstatus', 'checking computer status', 2),
('startvm', 'starting virtual machine', 3),
('vmstage5', 'detected stage 5 of 5 loading process', 1),
('vmconfigcopy', 'copying vm config file', NULL),
('imageloadcomplete', 'node ready to add user', 0),
('repeat', 'repeat', 0),
('deleted', 'deleted', NULL),
('begin', 'beginning to process reservation', 0),
('exited', 'vcld process exited', 0),
('acknowledgetimeout', 'start acknowledge timeout', 0),
('noinitialconnection', 'initial user connection not detected', 0),
('initialconnecttimeout', 'initial user connection timeout', 0),
('reconnecttimeout', 'user reconnection timeout', 0),
('copyfrompartnerMN', 'copy image from partner management node', 0),
('postreserve', 'post reserve completed', 0);

-- 
-- Dumping data for table `computerloadflow`
-- 

INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'statuscheck'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'doesimageexists'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'doesimageexists'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'copyfrompartnerMN'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'copyfrompartnerMN'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'rinstall'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'rinstall'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'xcatstage2'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'xcatstage2'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'xcatstage5'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'xcatstage5'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'bootstate'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'bootstate'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'machinebooted'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'machinebooted'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'loadimagecomplete'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'loadimagecomplete'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'nodeready'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'nodeready'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'addinguser'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'addinguser'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'reserved'),"blade");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'reserved'),NULL,"blade");

INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'statuscheck'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'doesimageexists'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'doesimageexists'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'copyfrompartnerMN'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'copyfrompartnerMN'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'startload'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'startload'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'transfervm'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'transfervm'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'vmsetupconfig'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'vmsetupconfig'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'startvm'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'startvm'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'machinebooted'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'machinebooted'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'loadimagecomplete'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'loadimagecomplete'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'nodeready'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'nodeready'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'addinguser'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'addinguser'),(SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'reserved'),"virtualmachine");
INSERT IGNORE INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES ((SELECT `id` FROM `computerloadstate` WHERE `loadstatename` LIKE 'reserved'),NULL,"virtualmachine");

--
-- Dumping data for table `connectmethod`
--

INSERT IGNORE INTO `connectmethod` (`id`, `name`, `description`, `connecttext`, `servicename`, `startupscript`) VALUES
(1, 'SSH', 'SSH for Linux & Unix', 'You will need to have an X server running on your local computer and use an SSH client to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<strong><big>NOTE:</big> You cannot use the Windows Remote Desktop Connection to connect to this computer. You must use an ssh client.</strong>', 'ext_sshd', '/etc/init.d/ext_sshd'),
(2, 'RDP', 'Remote Desktop for Windows', 'You will need to use a Remote Desktop program to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\n\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<br>\r\nFor automatic connection, you can download an RDP file that can be opened by the Remote Desktop Connection program.<br><br>\r\n', 'TermService', NULL),
(3, 'iRAPP RDP', 'Remote Desktop for OS X', 'You will need to use a Remote Desktop program to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\n\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<br>\r\nFor automatic connection, you can download an RDP file that can be opened by the Remote Desktop Connection program.<br><br>\r\n', NULL, NULL);

--
-- Dumping data for table `connectmethodmap`
--

INSERT IGNORE INTO `connectmethodmap` (`connectmethodid`, `OStypeid`, `OSid`, `imagerevisionid`, `disabled`, `autoprovisioned`) VALUES
(1, 2, NULL, NULL, 0, 1),
(1, 3, NULL, NULL, 0, 1),
(2, 1, NULL, NULL, 0, 1),
(3, 4, NULL, NULL, 0, 1),
(1, 2, NULL, NULL, 0, NULL),
(1, 3, NULL, NULL, 0, NULL),
(2, 1, NULL, NULL, 0, NULL),
(3, 4, NULL, NULL, 0, NULL);

--
-- Dumping data for table `connectmethodport`
--

INSERT INTO `connectmethodport` (`id`, `connectmethodid`, `port`, `protocol`) VALUES
(1, 1, 22, 'TCP'),
(2, 2, 3389, 'TCP'),
(3, 3, 3389, 'TCP');

-- 
-- Dumping data for table `documentation`
-- 

INSERT IGNORE INTO `documentation` (`name`, `title`, `data`) VALUES 
('GrantingAccesstoaNewImageEnvironment1', 'Granting Access to a New Image/Environment', '<div id="docbullets">\r\n<h2>Overview</h2>\r\n<p>Once you have created a new image, there are a few things you have to do to allow other people to use it.&nbsp; If you don''t have access to do any of the following steps, you will need to get a VCL administrator to do them for you.</p>\r\n<p>When you create a new image, it is only available to you, and it is only allowed to be run on a few computers that have been set aside for the testing of new images.</p>\r\n<h2>Step 1: Image Mapping</h2>\r\n<p>Images are mapped to be run on a set of computers. See the documentation on <a href="index.php?mode=viewdocs&amp;item=Resources"><span style="color: rgb(255, 0, 0);"><b>Resources</b></span></a> to learn more about why this is done. For your new image to be able to run on more computers than just those designated for testing, you need to map it to a set of computers. There are a few steps to this process:</p>\r\n<ol>\r\n    <li>You need to make your image a member of an image group\r\n    <ul>\r\n        <li>Select <span style="color: rgb(0, 0, 255);">Manage Images</span>-&gt;<span style="color: rgb(0, 0, 255);">Edit Image Grouping</span></li>\r\n        <li>Select your image from the drop down box and click <span style="color: rgb(0, 0, 255);">Get Groups</span></li>\r\n        <li>Choose one or more image groups to which you would like to add the image from the box on the right</li>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">&lt;-Add</span> to make the image a member of the group(s)</li>\r\n    </ul>\r\n    </li>\r\n    <li>You need to map the image group(s) you selected in step 1 to one or more computer groups\r\n    <ul>\r\n        <li>Select <span style="color: rgb(0, 0, 255);">Manage Images</span>-&gt;<span style="color: rgb(0, 0, 255);">Edit Image Mapping</span></li>\r\n        <li>Do the following for each group from step 1:<br />\r\n        <ul>\r\n            <li>Select the image group from the drop down box and click <span style="color: rgb(0, 0, 255);">Get Computer Groups</span></li>\r\n            <li>Choose one or more computer groups to which you would like to map the image group from the box on the right</li>\r\n            <li>click <span style="color: rgb(0, 0, 255);">&lt;-Add</span> to make map the image group to the computer group(s)</li>\r\n        </ul>\r\n        </li>\r\n        <li>Note: there is an assumption here that the computer groups you selected already have computers that are in those groups</li>\r\n    </ul>\r\n    </li>\r\n</ol>\r\n<h2>Step 2: Privileges</h2>\r\n<p>Now, you need to grant access to use the image to a user or group of users under the Privileges section of the site.&nbsp; Here are the steps involved:</p>\r\n<ol>\r\n    <li>Select <span style="color: rgb(0, 0, 255);">Privileges</span></li>\r\n    <li>Choose an existing node or create a new node in the tree structure in the upper portion of the page where you would like to assign the user(s) access</li>\r\n    <li>Now, you need to grant the user <span style="color: rgb(0, 0, 255);">imageCheckOut</span> at the node.&nbsp; You can do this for an individual user or a group of users.\r\n    <ul>\r\n        <li>Individual User:\r\n        <ul>\r\n            <li>Click <span style="color: rgb(0, 0, 255);">Add User</span></li>\r\n            <li>Enter the user''s id in the text box and select the <span style="color: rgb(0, 0, 255);">imageCheckOut</span> checkbox</li>\r\n            <li>Click <span style="color: rgb(0, 0, 255);">Submit New User</span></li>\r\n        </ul>\r\n        </li>\r\n        <li>User Group:\r\n        <ul>\r\n            <li>Click <span style="color: rgb(0, 0, 255);">Add Group</span></li>\r\n            <li>Select the user group from the drop-down box and select the <span style="color: rgb(0, 0, 255);">imageCheckOut</span> checkbox</li>\r\n            <li>Click <span style="color: rgb(0, 0, 255);">Submit New User Group</span></li>\r\n        </ul>\r\n        </li>\r\n    </ul>\r\n    </li>\r\n    <li>Next, you need to make sure the image group in which you placed the image in step 1 of <b>Image Mapping</b> is available at this node. If it is, go on to the next step, if not:\r\n    <ul>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">Add Resource Group</span></li>\r\n        <li>Select the image group from the drop-down box and select the <span style="color: rgb(0, 0, 255);">available</span> checkbox</li>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">Submit New Resource Group</span></li>\r\n    </ul>\r\n    </li>\r\n    <li>Finally, you need to make sure the computer group(s) selected in step 2 of <b>Image Mapping</b> are also available here. If so, you are finished.&nbsp; If not:\r\n    <ul>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">Add Resource Group</span></li>\r\n        <li>Select the computer group from the drop-down box and select the <span style="color: rgb(0, 0, 255);">available</span> checkbox</li>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">Submit New Resource Group</span></li>\r\n    </ul>\r\n    </li>\r\n</ol>\r\n<p>Now, the user or user groups you have added to this node will be able to make reservations for the new image.</p>\r\n</div>'),
('OverviewofPrivileges-Whatpermissionsarerequiredtoaccesspartsofthesite', 'Overview of Privileges - What permissions are required to access parts of the site', '<p>These are the privileges a user needs to access various parts of the VCL site. Unless specifically specified, a user must have both the <span style="color: rgb(0, 0, 255);">user<span style="color: rgb(0, 0, 0);"> and the <span style="color: rgb(255, 102, 0);">resource</span> permissions granted at the same node in the privilege tree.</span></span> &quot;<span style="color: rgb(0, 0, 255);">user</span>&quot; refers to privileges granted on the Privileges page either specifically to a user or to a group of which a user is a member. &quot;<span style="color: rgb(255, 102, 0);">resource</span>&quot; refers to privileges granted on the Privileges page to a resource group. Privileges can only be granted to resource groups; there is no way to grant privileges to a specific resource (image, computer, etc).</p>\r\n<h2>New Reservation</h2>\r\n<p style="margin-left: 40px;">This shows up for everyone, but the following privileges must be granted to be able to actually make a reservation:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user<span style="color: rgb(0, 0, 0);"> - imageCheckOut</span></span><br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: available, computer group: available</p>\r\n<h2>Manage Groups</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user <span style="color: rgb(0, 0, 0);">- groupAdmin is required to make this link show up</span></span></p>\r\n<h3 style="margin-left: 40px;">User Groups</h3>\r\n<p style="margin-left: 80px;">Groups a user owns and groups that are editable by groups a user is a member of show up in this section.</p>\r\n<h3 style="margin-left: 40px;">Resource Groups</h3>\r\n<p style="margin-left: 80px;">Groups owned by user groups a user is a member of show up here.&nbsp; More groups show up when the following attribute is granted for a resource group:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(255, 102, 0);">resource<span style="color: rgb(0, 0, 0);"> - (any type) manageGroup</span></span></p>\r\n<h2>Manage Images</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin is required to make this link show up</p>\r\n<h3 style="margin-left: 40px;">Edit Image Information</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: administer</p>\r\n<h3 style="margin-left: 40px;">View Image Grouping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">View Image Mapping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: manageGroup</p>\r\n<p style="margin-left: 80px;">at same or different node:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">Create New Image</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: available, computer group: available</p>\r\n<h2>Manage Schedules</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin is required to make this link show up</p>\r\n<p style="margin-left: 40px;">All schedules owned by a user will show up by default.</p>\r\n<p style="margin-left: 40px;">To edit schedule information for other schedules, these permissions are required:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - schedule group: administer</p>\r\n<h3 style="margin-left: 40px;">Schedule Grouping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - schedule group: manageGroup</p>\r\n<h2>Manage Computers</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin is required to make this link show up</p>\r\n<p style="margin-left: 40px;">Selection boxes for platforms and schedules only show up if a user has access to more than one platform or schedule.</p>\r\n<h3 style="margin-left: 40px;">Edit Computer Grouping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">Computer Utilities</h3>\r\n<h4 style="margin-left: 80px;">Reload computers with image</h4>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: administer</p>\r\n<p style="margin-left: 120px;">and at same or different node:</p>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - imageCheckOut or imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: available</p>\r\n<h4 style="margin-left: 80px;">Change state of computers</h4>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: administer</p>\r\n<h4 style="margin-left: 80px;">Change schedule of computers</h4>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: administer</p>\r\n<p style="margin-left: 120px;">and at same or different node:</p>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - schedule group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">Edit Computer Information</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: administer</p>\r\n<p style="margin-left: 80px;">and at same or different node:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - schedule group: manageGroup</p>\r\n<p style="margin-left: 80px;">&nbsp;</p>\r\n<h2>Management Nodes</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - mgmtNodeAdmin is required to make this link show up</p>\r\n<h3 style="margin-left: 40px;">Edit Management Node Information</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - mgmtNodeAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - management node group: administer</p>\r\n<h3 style="margin-left: 40px;">Edit Management Node Grouping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - mgmtNodeAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - management node group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">Edit Management Node Mapping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - mgmtNodeAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - management node group: manageGroup</p>\r\n<p style="margin-left: 80px;">at same or different node:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: manageGroup</p>\r\n<h2>Privileges</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - nodeAdmin, userGrant, or resourceGrant is required to make this link show up</p>\r\n<h3 style="margin-left: 40px;">Add Child / Delete Node and Children</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - nodeAdmin</p>\r\n<h3 style="margin-left: 40px;">Add User / modify user privileges</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - userGrant</p>\r\n<h3 style="margin-left: 40px;">Add Group / modify user group privileges</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - userGrant</p>\r\n<h3 style="margin-left: 40px;">Add Resource Group / modify resource group privileges</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - resourceGrant</p>\r\n<p>&nbsp;</p>'),
('Resources', 'Resources', '<h2>Overview</h2>\r\n<p>Computers, images, management nodes, and schedules have some very similar characteristics in how they are handled within the VCL site. Therefore, there are times where it is easier to refer to them all together as <b><span style="color: rgb(255, 0, 0);">resources</span></b>. Here are some similarities between them:</p>\r\n<ul>\r\n    <li>They are all managed by adding them to <span style="color: rgb(255, 0, 0);"><b>resource groups</b></span>.&nbsp; All resource groups have a type associated with them such that only <span style="color: rgb(0, 0, 255);">images</span> can be part of an <span style="color: rgb(0, 0, 255);">image group</span>, only <span style="color: rgb(0, 0, 255);">computers</span> can be part of a <span style="color: rgb(0, 0, 255);">computer group</span>, etc.</li>\r\n    <li>Resources of one type can be related to resources of certain other types through <span style="color: rgb(255, 0, 0);"><b>resource mapping</b></span>. <span style="color: rgb(0, 0, 255);">Image groups</span> and <span style="color: rgb(0, 0, 255);">computer groups</span> can be mapped together, and <span style="color: rgb(0, 0, 255);">management node</span><span style="color: rgb(0, 0, 255);"> groups</span> and&nbsp;<span style="color: rgb(0, 0, 255);">computer</span><span style="color: rgb(0, 0, 255);"> groups</span> can be mapped together.</li>\r\n    <li>Privileges over resources are only granted through resource groups.&nbsp; Privileges cannot be granted directly to a resource.</li>\r\n    <li>There is an <span style="color: rgb(255, 0, 0);"><b>Admin</b></span> privilege that can be granted to users for each type of resource: computerAdmin, imageAdmin, mgmtNodeAdmin, and scheduleAdmin</li>\r\n</ul>\r\n<h2>Grouping</h2>\r\n<p>The amount of images and computers that become part of a VCL install can grow very rappidly. Because of this, it is much easier to deal with them in groups rather than individually. The amount of schedules and management nodes does not typically grow very large. However, due to other similarities as resources, they are handled in groups as well.</p>\r\n<h2>Mapping</h2>\r\n<p>Mapping allows for tight control over how resources can be used together. Through image to computer mapping, one has tight control over which computers an image could end up being run. This can be used to control things like platform dependencies, to ensure only vm images get run on the correct type of vm computer, and to ensure an image containing software purchased by a specific group only gets run on computers owned by the same group (this can be handled with resource privileges as well).</p>\r\n<p>Through management node to computer mapping, assignment of which management nodes control which computers is accomplished. One can quickly switch which management node is in control of a group of computers. Additionally, when management node redundancy is fully implemented, this is how management nodes will be able to control overlapping groups of computers.</p>\r\n<h2>Resource Privileges</h2>\r\n<p>There are three privileges that can be assigned to resource groups:</p>\r\n<ul>\r\n    <li>available</li>\r\n    <li>administer</li>\r\n    <li>manageGroup</li>\r\n</ul>\r\n<p><span style="color: rgb(0, 0, 255);">available</span> is only used for image and computer groups. If it is assigned to a schedule or management node group, it is simply ignored. This privilege correspondes to these user group privileges: imageCheckOut and imageAdmin. When a user has one of these two privileges at a node along with an image group or a computer group having the available privilege at the same node, then the user will have access to make a reservations for the images in the group (imageCheckOut) or make a new images based off of images in the group (imageAdmin). Note that both an image group and a computer group must have the available permission where a user has imageCheckOut for the user to make a reservation for an image in the image group. This is used to determine which computers are available at the node to go along with which images are also available at the node.</p>\r\n<p><span style="color: rgb(0, 0, 255);">administer</span> is used for all types of resources, and thus corresponds to all of the *Admin user privileges (computerAdmin, imageAdmin, mgmtNodeAdmin, and scheduleAdmin). Administer generally grants access to manage specific <i>characteristics</i> of resources in a group, but not to manage any grouping information. For example, if a user has the imageAdmin privilege at a node where an image group has the administer privilege, the user would then have access to modify <i>characteristics</i> of images in that group (name, owner, minimum specs required by the image, etc), but would <b>not</b> have access to edit which images are <i>in the group</i>.</p>\r\n<p><span style="color: rgb(0, 0, 255);">manageGroup</span> is also used for all types of resources. It grants access to a few different things. One is the ability to modify information about a group under <span style="color: rgb(0, 0, 255);">Manage Groups </span>(if a user also has the groupAdmin privilege). Another is the ability to manage membership of a group. Finally, it provides access for mapping one type of group to another (for this, manageGroup must be granted for both types of resources). Additionally, there is an extra way manageGroup is used specifically related to computer groups: a user must have scheduleAdmin and manageGroup over a schedule group to be able to change the schedule of a computer (both through Manage Computers-&gt;Edit Computer Information and Manage Computers-&gt;Computer Utilities-&gt;Change schedule of computers).</p>');

-- 
-- Dumping data for table `imagerevision`
-- 

INSERT IGNORE INTO `imagerevision` (`id`, `imageid`, `revision`, `userid`, `datecreated`, `deleted`, `production`, `comments`, `imagename`) VALUES 
(1, 1, 0, 1, '1980-01-01 00:00:00', 0, 1, NULL, 'noimage');

-- 
-- Dumping data for table `image`
-- 

INSERT IGNORE INTO `image` (`id`, `name`, `prettyname`, `ownerid`, `imagetypeid`, `platformid`, `OSid`, `imagemetaid`, `minram`, `minprocnumber`, `minprocspeed`, `minnetwork`, `maxconcurrent`, `reloadtime`, `deleted`, `test`, `lastupdate`, `forcheckout`, `maxinitialtime`, `project`, `size`, `basedoffrevisionid`) VALUES 
(1, 'noimage', 'No Image', 1, 1, 1, 2, NULL, 0, 1, 0, 10, NULL, 0, 0, 0, NULL, 0, 0, 'vcl', 0, NULL);

--
-- Dumping data for table `imagetype`
--

INSERT IGNORE INTO `imagetype` (`id`, `name`) VALUES
(1, 'none'),
(2, 'partimage'),
(3, 'partimage-ng'),
(4, 'lab'),
(5, 'kickstart'),
(6, 'vmdk'),
(7, 'qcow2'),
(8, 'vdi');

-- 
-- Dumping data for table `IMtype`
-- 

INSERT IGNORE INTO `IMtype` (`id`, `name`) VALUES 
(2, 'jabber'),
(1, 'none');

-- 
-- Dumping data for table `module`
-- 

INSERT IGNORE INTO `module` (`id`, `name`, `prettyname`, `description`, `perlpackage`) VALUES 
(1, 'provisioning_xcat', 'xCAT Provisioning Module', '', 'VCL::Module::Provisioning::xCAT'),
(3, 'provisioning_lab', 'Computing Lab Provisioning Module', '', 'VCL::Module::Provisioning::Lab'),
(4, 'os_windows', 'Windows OS Module', '', 'VCL::Module::OS::Windows'),
(5, 'os_linux', 'Linux OS Module', '', 'VCL::Module::OS::Linux'),
(6, 'os_unix', 'Unix OS Module', '', 'VCL::Module::OS'),
(7, 'os_winvista', 'Windows Vista OS Module', '', 'VCL::Module::OS::Windows::Version_6::Vista'),
(8, 'predictive_level_0', 'Reload with last image', 'Reloads node with same image as was just used on it.', 'VCL::Module::Predictive::Level_0'),
(9, 'predictive_level_1', 'Reload image based on recent user demand', 'Selects an image to load based on historical data. Loads the most popular image that can be run on the machine that is not currently loaded and available on another node.', 'VCL::Module::Predictive::Level_1'),
(12, 'os_winxp', 'Windows XP OS Module', '', 'VCL::Module::OS::Windows::Version_5::XP'),
(13, 'os_win2003', 'Windows Server 2003 OS Module', '', 'VCL::Module::OS::Windows::Version_5::2003'),
(14, 'os_linux_ubuntu', 'Ubuntu Linux OS Module', '', 'VCL::Module::OS::Linux::Ubuntu'),
(15, 'os_unix_lab', 'Unix Lab OS Module', 'Unix Lab OS support module', 'VCL::Module::OS::Linux::UnixLab'),
(16, 'os_win2008', 'Windows Server 2008 OS Module', '', 'VCL::Module::OS::Windows::Version_6::2008'),
(17, 'os_win7', 'Windows 7 OS Module', '', 'VCL::Module::OS::Windows::Version_6::7'),
(21, 'provisioning_vmware', 'VMware Provisioning Module', '', 'VCL::Module::Provisioning::VMware::VMware'),
(22, 'state_image', 'VCL Image State Module', '', 'VCL::image'),
(23, 'base_module', 'VCL Base Module', '', 'VCL::Module'),
(24, 'provisioning_vbox', 'Virtual Box Provisioning Module', '', 'VCL::Module::Provisioning::vbox'),
(25, 'os_esxi', 'VMware ESXi OS Module', '', 'VCL::Module::OS::Linux::ESXi'),
(26, 'os_osx', 'OSX OS Module', '', 'VCL::Module::OS::OSX'),
(27, 'provisioning_libvirt', 'Libvirt Provisioning Module', '', 'VCL::Module::Provisioning::libvirt'),
(28, 'os_linux_managementnode', 'Management Node Linux OS Module', '', 'VCL::Module::OS::Linux::ManagementNode'),
(29, 'os_win8', 'Windows 8.x OS Module', '', 'VCL::Module::OS::Windows::Version_6::8'),
(30, 'os_win2012', 'Windows Server 2012 OS Module', '', 'VCL::Module::OS::Windows::Version_6::2012'),
(31, 'predictive_level_2', 'Unload/power off after reservation', 'Power off computer. If a virtual machine, it will be also destroyed.', 'VCL::Module::Predictive::Level_2'),
(32, 'provisioning_openstack', 'OpenStack Provisioning Module', '', 'VCL::Module::Provisioning::openstack'),
(33, 'provisioning_one', 'OpenNebula Provisioning Module', '', 'VCL::Module::Provisioning::one'),
(34, 'os_win10', 'Windows 10.x OS Module', '', 'VCL::Module::OS::Windows::Version_10::10');

-- 
-- Dumping data for table `OStype`
-- 

INSERT IGNORE INTO `OStype` (`id`, `name`) VALUES
(2, 'linux'),
(3, 'unix'),
(1, 'windows'),
(4, 'osx');

-- 
-- Dumping data for table `OS`
-- 

INSERT IGNORE INTO `OS` (`id`, `name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES
(2, 'sun4x_58', 'Solaris 5.8 (Lab)', 'unix', 'none', NULL, 15),
(3, 'win2k', 'Windows 2000 (Bare Metal)', 'windows', 'partimage', 'image', 4),
(6, 'rhel3', 'Red Hat Enterprise Linux 3 (Kickstart)', 'linux', 'kickstart', 'rhas3', 5),
(7, 'winxp', 'Windows XP (Bare Metal)', 'windows', 'partimage', 'image', 12),
(8, 'realmrhel3', 'Red Hat Enterprise Linux 3 (Lab)', 'linux', 'none', NULL, 15),
(9, 'realmrhel4', 'Red Hat Enterprise Linux 4 (Lab)', 'linux', 'none', NULL, 15),
(10, 'win2003', 'Windows 2003 Server (Bare Metal)', 'windows', 'partimage', 'image', 13),
(11, 'rh3image', 'Red Hat Enterprise Linux 3 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(12, 'rhel4', 'Red Hat Enterprise Linux 4 (Kickstart)', 'linux', 'kickstart', 'rhas4', 5),
(13, 'rh4image', 'Red Hat Enterprise Linux 4 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(14, 'fc5image', 'Fedora Core 5 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(15, 'rhfc5', 'Fedora Core 5 (Kickstart)', 'linux', 'kickstart', 'rhfc5', 5),
(16, 'vmwarewinxp', 'Windows XP (VMware)', 'windows', 'vmware', 'vmware_images', 12),
(17, 'rhfc7', 'Fedora Core 7 (Kickstart)', 'linux', 'kickstart', 'rhfc7', 5),
(18, 'fc7image', 'Fedora Core 7 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(19, 'rhel5', 'Red Hat Enterprise Linux 5 (Kickstart)', 'linux', 'kickstart', 'rhas5', 5),
(20, 'esx35', 'VMware ESX 3.5 (Kickstart)', 'linux', 'kickstart', 'esx35', 5),
(21, 'vmwareesxwinxp', 'Windows XP (VMware ESX)', 'windows', 'vmware', 'vmware_images', 12),
(22, 'realmrhel5', 'Red Hat Enterprise Linux 5 (Lab)', 'linux', 'none', NULL, 15),
(23, 'sun4x_510', 'Solaris 10 (Lab)', 'unix', 'none', NULL, 15),
(24, 'centos5', 'CentOS 5 (Kickstart)', 'linux', 'kickstart', 'centos5', 5),
(25, 'rh5image', 'Red Hat Enterprise Linux 5 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(26, 'rhfc9', 'RedHat Fedora Core 9 (Kickstart)', 'linux', 'kickstart', 'rhfc9', 5),
(27, 'fc9image', 'Red Hat Fedora Core 9 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(28, 'winvista', 'Windows Vista (Bare Metal)', 'windows', 'partimage', 'image', 7),
(29, 'centos5image', 'CentOS 5 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(30, 'ubuntuimage', 'Ubuntu (Bare Metal)', 'linux', 'partimage', 'image', 14),
(31, 'vmwarewin2008', 'Windows Server 2008 (VMware)', 'windows', 'vmware', 'vmware_images', 16),
(32, 'win2008', 'Windows Server 2008 (Bare Metal)', 'windows', 'partimage', 'image', 16),
(33, 'vmwarewinvista', 'Windows Vista (VMware)', 'windows', 'vmware', 'vmware_images', 7),
(34, 'win7', 'Windows 7 (Bare Metal)', 'windows', 'partimage', 'image', 17),
(35, 'vmwarewin7', 'Windows 7 (VMware)', 'windows', 'vmware', 'vmware_images', 17),
(36, 'vmwarelinux', 'Generic Linux (VMware)', 'linux', 'vmware', 'vmware_images', 5),
(37, 'vmwarewin2003', 'Windows 2003 Server (VMware)', 'windows', 'vmware', 'vmware_images', 13),
(38, 'esxi4.1', 'VMware ESXi 4.1', 'linux', 'kickstart', 'esxi4.1', 25),
(39, 'vmwareosx', 'OSX Snow Leopard (VMware)', 'osx', 'vmware', 'vmware_images', 26),
(40, 'rhel6', 'Red Hat Enterprise 6 (Kickstart)', 'linux', 'kickstart', 'rhel6', 5),
(41, 'rh6image', 'Red Hat Enterprise 6 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(42, 'fedora16', 'Fedora 16 (Kickstart)', 'linux', 'kickstart', 'fedora16', 5),
(43, 'fedoraimage', 'Fedora 16 (Bare Metal)', 'linux', 'partimage', 'image', 5),
(44, 'vmwareubuntu', 'Ubuntu (VMware)', 'linux', 'vmware', 'vmware_images', 14),
(45, 'vmwarewin8', 'Windows 8.x (VMware)', 'windows', 'vmware', 'vmware_images', 29),
(46, 'win8', 'Windows 8.x (Bare Metal)', 'windows', 'partimage', 'image', 29),
(47, 'vmwarewin2012', 'Windows Server 2012 (VMware)', 'windows', 'vmware', 'vmware_images', 30),
(48, 'win2012', 'Windows Server 2012 (Bare Metal)', 'windows', 'partimage', 'image', 30),
(49, 'centos6', 'CentOS 6 (Kickstart)', 'linux', 'kickstart', 'centos6', 5),
(50, 'centos7', 'CentOS 7 (Kickstart)', 'linux', 'kickstart', 'centos7', 5),
(51, 'rhel7', 'Red Hat Enterprise 7 (Kickstart)', 'linux', 'kickstart', 'rhel7', 5),
(52, 'centos6image', 'CentOS 6 (Bare Metal) Image', 'linux', 'partimage', 'image', 5),
(53, 'centos7image', 'CentOS 7 (Bare Metal) Image', 'linux', 'partimage', 'image', 5),
(54, 'rhelimage', 'Red Hat Based Image', 'linux', 'partimage', 'image', 5),
(55, 'win10', 'Windows 10.x (Bare Metal)', 'windows', 'partimage', 'image', 34),
(56, 'vmwarewin10', 'Windows 10.x (VMware)', 'windows', 'vmware', 'vmware_images', 34);

UPDATE OS SET minram = 1024 WHERE name REGEXP 'win.*';
UPDATE OS SET minram = 2048 WHERE name REGEXP 'win.*(7|8|10|2008|2012)';
UPDATE OS SET minram = 1024 WHERE name REGEXP '(centos|rh|rhel)(5|6|7)';

-- 
-- Dumping data for table `OSinstalltype`
-- 

INSERT IGNORE INTO `OSinstalltype` (`id`, `name`) VALUES
(2, 'kickstart'),
(3, 'none'),
(1, 'partimage'),
(4, 'vmware'),
(5, 'vbox'),
(6, 'openstack');

-- 
-- Dumping data for table `platform`
-- 

INSERT IGNORE INTO `platform` (`id`, `name`) VALUES 
(1, 'i386'),
(4, 'i386_lab'),
(3, 'ultrasparc');

-- 
-- Dumping data for table `privnode`
-- 

INSERT IGNORE INTO `privnode` (`id`, `parent`, `name`) VALUES 
(2, 1, 'Developer'),
(1, 1, 'Root'),
(3, 2, 'VCL'),
(4, 3, 'admin'),
(5, 3, 'newimages');

-- 
-- Dumping data for table `privisioning`
-- 

INSERT IGNORE INTO `provisioning` (`id`, `name`, `prettyname`, `moduleid`) VALUES
(1, 'xcat', 'xCAT', 1),
(3, 'lab', 'Computing Lab', 3),
(7, 'vmware', 'VMware', 21),
(8, 'vbox', 'Virtual Box', 24),
(9, 'libvirt', 'Libvirt Virtualization API', 27),
(10, 'none', 'None', 23),
(11, 'openstack', 'openstack', 32),
(12, 'one', 'OpenNebula', 33);

--
-- Dumping data for table `provisioningOSinstalltype`
--

INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%xcat%' AND OSinstalltype.name = 'partimage';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%xcat%' AND OSinstalltype.name = 'kickstart';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%vmware%' AND OSinstalltype.name = 'vmware';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%esx%' AND OSinstalltype.name = 'vmware';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%vbox%' AND OSinstalltype.name = 'vbox';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%lab%' AND OSinstalltype.name = 'none';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%libvirt%' AND OSinstalltype.name = 'vmware';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%openstack%' AND OSinstalltype.name = 'openstack';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name='one' AND OSinstalltype.name = 'vmware';


-- 
-- Dumping data for table `resourcetype`
-- 

INSERT IGNORE INTO `resourcetype` (`id`, `name`) VALUES 
(12, 'computer'),
(13, 'image'),
(16, 'managementnode'),
(15, 'schedule'),
(17, 'serverprofile');

-- 
-- Dumping data for table `resource`
-- 

INSERT IGNORE INTO `resource` (`id`, `resourcetypeid`, `subid`) VALUES 
(4, 13, 1),
(8, 15, 1);

-- 
-- Dumping data for table `resourcegroup`
-- 

INSERT IGNORE INTO `resourcegroup` (`id`, `name`, `ownerusergroupid`, `resourcetypeid`) VALUES 
(1, 'allComputers', 3, 12),
(2, 'allImages', 3, 13),
(3, 'allManagementNodes', 3, 16),
(4, 'allSchedules', 3, 15),
(5, 'All VM Computers', 3, 12),
(8, 'newimages', 4, 12),
(9, 'newvmimages', 4, 12),
(10, 'allVMimages', 4, 13),
(11, 'all profiles', 3, 17);

-- 
-- Dumping data for table `resourcegroupmembers`
-- 

INSERT IGNORE INTO `resourcegroupmembers` (`resourceid`, `resourcegroupid`) VALUES 
(8, 4);

-- 
-- Dumping data for table `resourcemap`
-- 

INSERT IGNORE INTO `resourcemap` (`resourcegroupid1`, `resourcetypeid1`, `resourcegroupid2`, `resourcetypeid2`) VALUES 
(2, 13, 1, 12),
(3, 16, 1, 12),
(10, 13, 5, 12),
(3, 16, 8, 12),
(3, 16, 5, 12),
(3, 16, 9, 12);

-- 
-- Dumping data for table `resourcepriv`
-- 

INSERT IGNORE INTO `resourcepriv` (`id`, `resourcegroupid`, `privnodeid`, `type`) VALUES 
(1, 1, 4, 'available'),
(2, 1, 4, 'administer'),
(3, 1, 4, 'manageGroup'),
(4, 2, 4, 'available'),
(5, 2, 4, 'administer'),
(6, 2, 4, 'manageGroup'),
(7, 3, 4, 'available'),
(8, 3, 4, 'administer'),
(9, 3, 4, 'manageGroup'),
(10, 4, 4, 'available'),
(11, 4, 4, 'administer'),
(12, 4, 4, 'manageGroup'),
(15, 8, 5, 'cascade'),
(16, 8, 5, 'available'),
(17, 1, 4, 'manageMapping'),
(18, 2, 4, 'manageMapping'),
(19, 3, 4, 'manageMapping'),
(20, 4, 4, 'manageMapping'),
(21, 5, 4, 'available'),
(22, 5, 4, 'administer'),
(23, 5, 4, 'manageGroup'),
(24, 5, 4, 'manageMapping'),
(25, 10, 4, 'available'),
(26, 10, 4, 'administer'),
(27, 10, 4, 'manageGroup'),
(28, 10, 4, 'manageMapping'),
(29, 11, 4, 'available'),
(30, 11, 4, 'administer'),
(31, 11, 4, 'manageGroup'),
(32, 11, 4, 'manageMapping');

-- 
-- Dumping data for table `schedule`
-- 

INSERT IGNORE INTO `schedule` (`id`, `name`, `ownerid`) VALUES 
(1, 'VCL 24x7', 1);

-- 
-- Dumping data for table `scheduletimes`
-- 

INSERT IGNORE INTO `scheduletimes` (`scheduleid`, `start`, `end`) VALUES 
(1, 0, 10080);

-- 
-- Dumping data for table `state`
-- 

INSERT IGNORE INTO `state` (`id`, `name`) VALUES 
(2, 'available'),
(4, 'classreserved'),
(9, 'cleaning'),
(12, 'complete'),
(1, 'deleted'),
(5, 'failed'),
(23, 'hpc'),
(16, 'image'),
(7, 'imageinuse'),
(15, 'imageprep'),
(8, 'inuse'),
(10, 'maintenance'),
(17, 'makeproduction'),
(13, 'new'),
(14, 'pending'),
(19, 'reload'),
(6, 'reloading'),
(3, 'reserved'),
(11, 'timeout'),
(22, 'tohpc'),
(18, 'tomaintenance'),
(21, 'tovmhostinuse'),
(20, 'vmhostinuse'),
(24, 'checkpoint'),
(25, 'serverinuse'),
(26, 'rebootsoft'),
(27, 'reinstall'),
(28, 'reboothard'),
(29, 'servermodified');

-- 
-- Dumping data for table `user`
-- 

INSERT IGNORE INTO `user` (`id`, `uid`, `unityid`, `affiliationid`, `firstname`, `lastname`, `preferredname`, `email`, `emailnotices`, `IMtypeid`, `IMid`, `adminlevelid`, `width`, `height`, `bpp`, `audiomode`, `mapdrives`, `mapprinters`, `mapserial`, `showallgroups`, `lastupdated`) VALUES 
(1, 101, 'admin', 1, 'vcl', 'admin', '', 'root@localhost', 0, NULL, NULL, 3, 1024, 768, 16, 'local', 1, 1, 1, 1, '2007-05-17 09:58:39'),
(2, NULL, 'vclreload', 1, 'vcl', 'reload', NULL, '', 0, NULL, NULL, 1, 1024, 768, 16, 'local', 1, 1, 0, 0, '0000-00-00 00:00:00'),
(3, NULL, 'vclsystem', 1, 'vcl', 'system', NULL, '', 0, NULL, NULL, 1, 1024, 768, 16, 'local', 1, 1, 0, 0, '0000-00-00 00:00:00');

-- 
-- Dumping data for table `localauth`
-- 

INSERT IGNORE INTO `localauth` (`userid`, `passhash`, `salt`, `lastupdated`, `lockedout`) VALUES 
(1, 'd8c730cc269d3d6b6147a416fb49c2be1a70aefc', 'QwkCHLpY', '2007-05-17 09:56:01', 0),
(3, 'da60188ee483aa16eeb82d4969a0f79d0d177d99', '8ht2Pa55', '2007-05-17 09:56:01', 0);

-- 
-- Dumping data for table `usergroup`
-- 

INSERT IGNORE INTO `usergroup` (`id`, `name`, `affiliationid`, `ownerid`, `editusergroupid`, `custom`, `courseroll`, `initialmaxtime`, `totalmaxtime`, `maxextendtime`, `overlapResCount`) VALUES 
(1, 'global', 1, 1, 1, 1, 0, 240, 360, 30, 0),
(3, 'adminUsers', 1, 1, 1, 1, 0, 480, 600, 180, 50),
(4, 'manageNewImages', 1, 1, 3, 1, 0, 240, 360, 30, 0),
(5, 'Specify End Time', 1, 1, 3, 1, 0, 240, 360, 30, 0),
(6, 'Allow No User Check', 1, 1, 3, 1, 0, 240, 360, 30, 0),
(7, 'Default for Editable by', 1, 1, 3, 1, 0, 240, 360, 30, 0);

-- 
-- Dumping data for table `usergroupmembers`
-- 

INSERT IGNORE INTO `usergroupmembers` (`userid`, `usergroupid`) VALUES 
(1, 1),
(1, 3),
(1, 4),
(1, 5),
(1, 6),
(1, 7);

-- 
-- Dumping data for table `usergroupprivtype`
-- 

INSERT IGNORE INTO `usergroupprivtype` (`id`, `name`, `help`) VALUES
(1, 'Manage Additional User Group Permissions', 'This gives users in the group access to this portion of the site.'),
(2, 'Manage Block Allocations (global)', 'Grants the ability to create, accept, and reject block allocations for any affiliation.'),
(3, 'Set Overlapping Reservation Count', 'Grants the ability to control how many overlapping reservations users in a given user group can make.'),
(4, 'View Debug Information', 'Allows user to see various verbose/debugging information while using the web site.'),
(5, 'Manage VM Profiles', 'Grants the ability to manage VM profiles under the Virtual Hosts section of the site.'),
(6, 'Search Tools', 'Grants the ability to see the Search Tools section of the site.'),
(7, 'Schedule Site Maintenance', 'Grants the ability to schedule and manage site maintenance for the web site.'),
(8, 'View Dashboard (global)', 'The dashboard displays real time information about the VCL system. This option grants access to view the dashboard with information displayed for users from all affiliations.'),
(9, 'View Dashboard (affiliation only)', 'The dashboard displays real time information about the VCL system. This option grants access to view the dashboard with information displayed only about users matching the affiliation of the currently logged in user.'),
(10, 'User Lookup (global)', 'The User Lookup tool allows a user to see various information about VCL users. This grants the use of the tool for all affiliations.'),
(11, 'User Lookup (affiliation only)', 'The User Lookup tool allows a user to see various information about VCL users. This grants the use of the tool for looking up users of the same affiliation as the logged in user.'),
(12, 'View Statistics by Affiliation', 'Grants the ability to see statistics for affiliations that do not match the affiliation of the logged in user.'),
(13, 'Manage Block Allocations (affiliation only)', 'Grants the ability to create, accept, and reject block allocations owned by users matching your affiliation.'),
(14, 'Manage Federated User Groups (global)', 'Grants the ability to control attributes of user groups that are created through federated systems such as LDAP and Shibboleth. Does not grant control of user group membership.'),
(15, 'Manage Federated User Groups (affiliation only)', 'Grants the ability to control attributes of user groups that are created through federated systems such as LDAP and Shibboleth. Does not grant control of user group membership.'),
(16, 'Site Configuration (global)', 'Grants the ability to view the Site Configuration part of the site to manage site settings.'),
(17, 'Site Configuration (affiliation only)', 'Grants the ability to view the Site Configuration part of the site to manage site settings specific to the user''s own affiliation.');

-- 
-- Dumping data for table `usergrouppriv`
-- 

INSERT IGNORE INTO `usergrouppriv` (`usergroupid`, `userprivtypeid`) VALUES
(3, 1),
(3, 2),
(3, 3),
(3, 4),
(3, 5),
(3, 6),
(3, 7),
(3, 8),
(3, 9),
(3, 10),
(3, 11),
(3, 12),
(3, 14),
(3, 16);

-- 
-- Dumping data for table `userprivtype`
-- 

INSERT IGNORE INTO `userprivtype` (`id`, `name`) VALUES 
(1, 'block'),
(2, 'cascade'),
(4, 'computerAdmin'),
(11, 'groupAdmin'),
(5, 'imageAdmin'),
(6, 'imageCheckOut'),
(13, 'mgmtNodeAdmin'),
(3, 'nodeAdmin'),
(10, 'resourceGrant'),
(12, 'scheduleAdmin'),
(8, 'serverCheckOut'),
(9, 'serverProfileAdmin'),
(7, 'userGrant');

-- 
-- Dumping data for table `userpriv`
-- 

INSERT IGNORE INTO `userpriv` (`id`, `userid`, `usergroupid`, `privnodeid`, `userprivtypeid`) VALUES 
(24, NULL, 3, 3, 2),
(16, NULL, 3, 3, 3),
(11, NULL, 3, 3, 4),
(13, NULL, 3, 3, 5),
(14, NULL, 3, 3, 6),
(19, NULL, 3, 3, 7),
(20, NULL, 3, 3, 8),
(21, NULL, 3, 3, 9),
(17, NULL, 3, 3, 10),
(12, NULL, 3, 3, 11),
(18, NULL, 3, 3, 12),
(15, NULL, 3, 3, 13),
(1, 1, NULL, 3, 2),
(6, 1, NULL, 3, 3),
(2, 1, NULL, 3, 4),
(7, 1, NULL, 3, 5),
(3, 1, NULL, 3, 6),
(8, 1, NULL, 3, 7),
(22, 1, NULL, 3, 8),
(23, 1, NULL, 3, 9),
(4, 1, NULL, 3, 10),
(9, 1, NULL, 3, 11),
(5, 1, NULL, 3, 12),
(10, 1, NULL, 3, 13);

-- 
-- Dumping data for table `variable`
-- 

INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES
('schema-version', 'none', '1'),
('timesource|global', 'none','time.nist.gov,time-a.nist.gov,time-b.nist.gov,time.windows.com'),
('acknowledgetimeout', 'none', '900'),
('initialconnecttimeout', 'none', '900'),
('reconnecttimeout', 'none', '900'),
('general_inuse_check', 'none', '300'),
('server_inuse_check', 'none', '900'),
('general_end_notice_first', 'none', '600'),
('general_end_notice_second', 'none', '300'),
('ignore_connections_gte', 'none', '1440'),
('xcat|timeout_error_limit', 'none', '5'),
('xcat|rpower_error_limit', 'none', '3'),
('ignored_remote_ip_addresses', 'none', ''),
('natport_ranges', 'none', '5700-6500,9696-9701,49152-65535'),
('windows_ignore_users', 'none', 'Administrator,cyg_server,root,sshd,Guest'),
('windows_disable_users', 'none', '');

-- 
-- Dumping data for table `vmprofile`
-- 

INSERT IGNORE INTO `vmprofile` (`profilename`, `imageid`, `resourcepath`, `repositorypath`, `repositoryimagetypeid`, `datastorepath`, `datastoreimagetypeid`, `vmpath`, `virtualswitch0`, `virtualswitch1`, `vmdisk`, `username`, `password`) VALUES
('VMware ESXi - local storage', (SELECT `id` FROM `image` WHERE `name` = 'noimage'), NULL, NULL, (SELECT `id` FROM `imagetype` WHERE `name` = 'none'), 'datastore1', (SELECT `id` FROM `imagetype` WHERE `name` = 'vmdk'), 'datastore1', 'Private', 'Public', 'dedicated', NULL, NULL),
('VMware ESXi - network storage', (SELECT `id` FROM `image` WHERE `name` = 'noimage'), NULL, NULL, (SELECT `id` FROM `imagetype` WHERE `name` = 'none'), 'nfs-datastore', (SELECT `id` FROM `imagetype` WHERE `name` = 'vmdk'), 'nfs-datastore', 'Private', 'Public', 'shared', NULL, NULL),
('VMware ESXi - local & network storage', (SELECT `id` FROM `image` WHERE `name` = 'noimage'), NULL, NULL, (SELECT `id` FROM `imagetype` WHERE `name` = 'none'), 'nfs-datastore', (SELECT `id` FROM `imagetype` WHERE `name` = 'vmdk'), 'datastore1', 'Private', 'Public', 'shared', NULL, NULL),
('VMware vCenter', (SELECT `id` FROM `image` WHERE `name` = 'noimage'), '/DatacenterName/ClusterName/ResourcePoolName', 'repo-datastore', (SELECT `id` FROM `imagetype` WHERE `name` = 'vmdk'), 'nfs-datastore', (SELECT `id` FROM `imagetype` WHERE `name` = 'vmdk'), 'datastore1', 'Private', 'Public', 'shared', 'vcenter-admin', 'vcenter-password'),
('KVM - local storage', (SELECT `id` FROM `image` WHERE `name` = 'noimage'), NULL, NULL, (SELECT `id` FROM `imagetype` WHERE `name` = 'qcow2'), '/var/lib/libvirt/images', (SELECT `id` FROM `imagetype` WHERE `name` = 'qcow2'), '/var/lib/libvirt/images', 'br0', 'br1', 'dedicated', NULL, NULL);

-- 
-- Dumping data for table `vmtype`
-- 

INSERT IGNORE INTO `vmtype` (`id`, `name`) VALUES
(1, 'vmware'),
(2, 'xen'),
(3, 'vmwareGSX'),
(4, 'vmwarefreeserver'),
(5, 'vmwareESX3'),
(6, 'vmwareESXi');

-- =========================================================

-- Guidelines on constraints
-- * ids for individual resource tables (computer, image, etc) must not be updated; so, no ON UPDATE CASCADE based on them
-- * ON DELETE CASCADE should not be used for relating to resources that get marked as deleted
-- * ids for request and reservation tables must not be updated; so, no ON UPDATE CASCADE based on them
-- * ON DELETE SET NULL should not be used for foreign keys on request.id and reservation.id so values are retained
-- * ON UPDATE CASCADE should be used for dependencies on tables where records should not be deleted
-- * users must not be deleted; so, no ON DELETE CASCADE based on them

-- 
-- Constraints for dumped tables
-- 

-- 
-- Constraints for table `blockComputers`
-- 
ALTER TABLE `blockComputers` ADD CONSTRAINT FOREIGN KEY (`blockTimeid`) REFERENCES `blockTimes` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `blockComputers` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);
ALTER TABLE `blockComputers` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);
-- do not want foreign key on reloadrequestid so that the request entry can be deleted but request id is retained for each entry

-- 
-- Constraints for table `blockRequest`
-- 
ALTER TABLE `blockRequest` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);
ALTER TABLE `blockRequest` ADD CONSTRAINT FOREIGN KEY (`groupid`) REFERENCES `usergroup` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `blockRequest` ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `blockRequest` ADD CONSTRAINT FOREIGN KEY (`managementnodeid`) REFERENCES `managementnode` (`id`);

-- 
-- Constraints for table `blockTimes`
-- 
ALTER TABLE `blockTimes` ADD CONSTRAINT FOREIGN KEY (`blockRequestid`) REFERENCES `blockRequest` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `blockWebDate`
-- 
ALTER TABLE `blockWebDate` ADD CONSTRAINT FOREIGN KEY (`blockRequestid`) REFERENCES `blockRequest` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `blockWebTime`
-- 
ALTER TABLE `blockWebTime` ADD CONSTRAINT FOREIGN KEY (`blockRequestid`) REFERENCES `blockRequest` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `changelog`
--
ALTER TABLE `changelog` ADD CONSTRAINT FOREIGN KEY (`logid`) REFERENCES `log` (`id`) ON UPDATE CASCADE;
ALTER TABLE `changelog` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `changelog` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);
-- do not want foreign key on reservationid so that the reservation entry can be deleted but reservation id is retained for each entry

-- 
-- Constraints for table `clickThroughs`
--
ALTER TABLE `clickThroughs` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `clickThroughs` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);
ALTER TABLE `clickThroughs` ADD CONSTRAINT FOREIGN KEY (`imagerevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `computer`
-- 
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (vmhostid) REFERENCES `vmhost` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`scheduleid`) REFERENCES `schedule` (`id`) ON DELETE SET NULL;
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`stateid`) REFERENCES `state` (`id`) ON UPDATE CASCADE;
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`platformid`) REFERENCES `platform` (`id`) ON UPDATE CASCADE;
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`currentimageid`) REFERENCES `image` (`id`);
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`provisioningid`) REFERENCES `provisioning` (`id`) ON UPDATE CASCADE;
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`imagerevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`nextimageid`) REFERENCES `image` (`id`);
ALTER TABLE `computer` ADD CONSTRAINT FOREIGN KEY (`predictivemoduleid`) REFERENCES `module` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `computerloadflow`
--
ALTER TABLE `computerloadflow` ADD CONSTRAINT FOREIGN KEY (computerloadstateid) REFERENCES `computerloadstate` (`id`) ON UPDATE CASCADE;
ALTER TABLE `computerloadflow` ADD CONSTRAINT FOREIGN KEY (nextstateid) REFERENCES `computerloadstate` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `computerloadlog` 
-- 
ALTER TABLE `computerloadlog` ADD CONSTRAINT FOREIGN KEY (`reservationid`) REFERENCES `reservation` (`id`) ON DELETE CASCADE;
ALTER TABLE `computerloadlog` ADD CONSTRAINT FOREIGN KEY (`loadstateid`) REFERENCES `computerloadstate` (`id`) ON UPDATE CASCADE;
ALTER TABLE `computerloadlog` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);

--
-- Constraints for table `connectlog`
--
ALTER TABLE `connectlog` ADD CONSTRAINT FOREIGN KEY (`logid`) REFERENCES `log` (`id`) ON UPDATE CASCADE;
ALTER TABLE `connectlog` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
-- do not want foreign key on reservationid so that the reservation entry can be deleted but reservation id is retained for each entry

--
-- Constraints for table `connectmethodmap`
--
ALTER TABLE `connectmethodmap` ADD CONSTRAINT FOREIGN KEY (`connectmethodid`) REFERENCES `connectmethod` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `connectmethodmap` ADD CONSTRAINT FOREIGN KEY (`OStypeid`) REFERENCES `OStype` (`id`) ON UPDATE CASCADE;
ALTER TABLE `connectmethodmap` ADD CONSTRAINT FOREIGN KEY (`OSid`) REFERENCES `OS` (`id`) ON UPDATE CASCADE;
ALTER TABLE `connectmethodmap` ADD CONSTRAINT FOREIGN KEY (`imagerevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `connectmethodport`
--
ALTER TABLE `connectmethodport` ADD CONSTRAINT FOREIGN KEY (`connectmethodid`) REFERENCES `connectmethod` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `continuations`
-- 
ALTER TABLE `continuations` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `continuations` ADD CONSTRAINT FOREIGN KEY (`parentid`) REFERENCES `continuations` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `image`
-- 
ALTER TABLE `image` ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `image` ADD CONSTRAINT FOREIGN KEY (`platformid`) REFERENCES `platform` (`id`) ON UPDATE CASCADE;
ALTER TABLE `image` ADD CONSTRAINT FOREIGN KEY (`OSid`) REFERENCES `OS` (`id`) ON UPDATE CASCADE;
ALTER TABLE `image` ADD CONSTRAINT FOREIGN KEY (`imagetypeid`) REFERENCES `imagetype` (`id`) ON UPDATE CASCADE;
ALTER TABLE `image` ADD CONSTRAINT FOREIGN KEY (`imagemetaid`) REFERENCES `imagemeta` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `image` ADD CONSTRAINT FOREIGN KEY (`basedoffrevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `imagerevision`
-- 
ALTER TABLE `imagerevision` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);
ALTER TABLE `imagerevision` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `imagerevisioninfo`
-- 
ALTER TABLE `imagerevisioninfo` ADD CONSTRAINT FOREIGN KEY (`imagerevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `localauth`
-- 
ALTER TABLE `localauth` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `log`
-- 
ALTER TABLE `log` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `log` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);
ALTER TABLE `log` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);
-- do not want foreign key on requestid so that the request entry can be deleted but request id is retained for each entry

-- 
-- Constraints for table `loginlog`
--
ALTER TABLE `loginlog` ADD CONSTRAINT FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `managementnode`
-- 
ALTER TABLE `managementnode` ADD CONSTRAINT FOREIGN KEY (`imagelibgroupid`) REFERENCES `resourcegroup` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `managementnode` ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `managementnode` ADD CONSTRAINT FOREIGN KEY (`stateid`) REFERENCES `state` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `nathost`
-- 
ALTER TABLE `nathost` ADD CONSTRAINT FOREIGN KEY (`resourceid`) REFERENCES `resource` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `nathostcomputermap`
-- 
ALTER TABLE `nathostcomputermap` ADD CONSTRAINT FOREIGN KEY (`nathostid`) REFERENCES `nathost` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `nathostcomputermap` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);

-- 
-- Constraints for table `natlog`
--
ALTER TABLE `natlog` ADD CONSTRAINT FOREIGN KEY (`sublogid`) REFERENCES `sublog` (`id`) ON UPDATE CASCADE;
ALTER TABLE `natlog` ADD CONSTRAINT FOREIGN KEY (`nathostresourceid`) REFERENCES `resource` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `natport`
-- 
ALTER TABLE `natport` ADD CONSTRAINT FOREIGN KEY (`connectmethodportid`) REFERENCES `connectmethodport` (`id`) ON UPDATE CASCADE;
ALTER TABLE `natport` ADD CONSTRAINT FOREIGN KEY (`reservationid`) REFERENCES `reservation` (`id`) ON DELETE CASCADE;
ALTER TABLE `natport` ADD CONSTRAINT FOREIGN KEY (`nathostid`) REFERENCES `nathost` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `openstackcomputermap`
--
ALTER TABLE `openstackcomputermap` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);

-- 
-- Constraints for table `openstackimagerevision`
--
ALTER TABLE `openstackimagerevision` ADD CONSTRAINT FOREIGN KEY (`imagerevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `OS`
--
ALTER TABLE `OS` ADD CONSTRAINT FOREIGN KEY (`type`) REFERENCES `OStype` (`name`) ON UPDATE CASCADE;
ALTER TABLE `OS` ADD CONSTRAINT FOREIGN KEY (`installtype`) REFERENCES `OSinstalltype` (`name`) ON UPDATE CASCADE;
ALTER TABLE `OS` ADD CONSTRAINT FOREIGN KEY (`moduleid`) REFERENCES `module` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `privnode`
-- 
ALTER TABLE `privnode` ADD CONSTRAINT FOREIGN KEY (`parent`) REFERENCES `privnode` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `provisioning`
--
ALTER TABLE `provisioning` ADD CONSTRAINT FOREIGN KEY (`moduleid`) REFERENCES `module` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `provisioningOSinstalltype`
--
ALTER TABLE `provisioningOSinstalltype` ADD CONSTRAINT FOREIGN KEY (`OSinstalltypeid`) REFERENCES `OSinstalltype` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `provisioningOSinstalltype` ADD CONSTRAINT FOREIGN KEY (`provisioningid`) REFERENCES `provisioning` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `querylog`
-- 
ALTER TABLE `querylog` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `request`
-- 
ALTER TABLE `request` ADD CONSTRAINT FOREIGN KEY (`stateid`) REFERENCES `state` (`id`) ON UPDATE CASCADE;
ALTER TABLE `request` ADD CONSTRAINT FOREIGN KEY (`laststateid`) REFERENCES `state` (`id`) ON UPDATE CASCADE;
ALTER TABLE `request` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `request` ADD CONSTRAINT FOREIGN KEY (`logid`) REFERENCES `log` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `reservation`
-- 
ALTER TABLE `reservation` ADD CONSTRAINT FOREIGN KEY (`requestid`) REFERENCES `request` (`id`) ON DELETE CASCADE;
ALTER TABLE `reservation` ADD CONSTRAINT FOREIGN KEY (`managementnodeid`) REFERENCES `managementnode` (`id`);
ALTER TABLE `reservation` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);
ALTER TABLE `reservation` ADD CONSTRAINT FOREIGN KEY (`imagerevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;
ALTER TABLE `reservation` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);

--
-- Constraints for table `reservationaccounts`
--
ALTER TABLE `reservationaccounts` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `reservationaccounts` ADD CONSTRAINT FOREIGN KEY (`reservationid`) REFERENCES `reservation` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `resource`
-- 
ALTER TABLE `resource` ADD CONSTRAINT FOREIGN KEY (`resourcetypeid`) REFERENCES `resourcetype` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `resourcegroup`
-- 
-- TODO should we allow ON DELETE CASCADE for ownerusergroupid?
ALTER TABLE `resourcegroup` ADD CONSTRAINT FOREIGN KEY (`ownerusergroupid`) REFERENCES `usergroup` (`id`) ON UPDATE CASCADE;
ALTER TABLE `resourcegroup` ADD CONSTRAINT FOREIGN KEY (`resourcetypeid`) REFERENCES `resourcetype` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `resourcegroupmembers`
-- 
ALTER TABLE `resourcegroupmembers` ADD CONSTRAINT FOREIGN KEY (`resourceid`) REFERENCES `resource` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `resourcegroupmembers` ADD CONSTRAINT FOREIGN KEY (`resourcegroupid`) REFERENCES `resourcegroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `resourcemap`
-- 
ALTER TABLE `resourcemap` ADD CONSTRAINT FOREIGN KEY (`resourcegroupid1`) REFERENCES `resourcegroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `resourcemap` ADD CONSTRAINT FOREIGN KEY (`resourcegroupid2`) REFERENCES `resourcegroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `resourcemap` ADD CONSTRAINT FOREIGN KEY (`resourcetypeid1`) REFERENCES `resourcetype` (`id`) ON UPDATE CASCADE;
ALTER TABLE `resourcemap` ADD CONSTRAINT FOREIGN KEY (`resourcetypeid2`) REFERENCES `resourcetype` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `resourcepriv`
-- 
ALTER TABLE `resourcepriv` ADD CONSTRAINT FOREIGN KEY (`resourcegroupid`) REFERENCES `resourcegroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `resourcepriv` ADD CONSTRAINT FOREIGN KEY (`privnodeid`) REFERENCES `privnode` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `schedule`
-- 
ALTER TABLE `schedule` ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `scheduletimes`
-- 
ALTER TABLE `scheduletimes` ADD CONSTRAINT FOREIGN KEY (`scheduleid`) REFERENCES `schedule` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `semaphore`
-- 
ALTER TABLE `semaphore` ADD CONSTRAINT FOREIGN KEY (`managementnodeid`) REFERENCES `managementnode` (`id`);
ALTER TABLE `semaphore` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);
ALTER TABLE `semaphore` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);
ALTER TABLE `semaphore` ADD CONSTRAINT FOREIGN KEY (`imagerevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `serverprofile`
--
ALTER TABLE `serverprofile` ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `serverprofile` ADD CONSTRAINT FOREIGN KEY (`admingroupid`) REFERENCES `usergroup` (`id`) ON UPDATE CASCADE;
ALTER TABLE `serverprofile` ADD CONSTRAINT FOREIGN KEY (`logingroupid`) REFERENCES `usergroup` (`id`) ON UPDATE CASCADE;
ALTER TABLE `serverprofile` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);

--
-- Constraints for table `serverrequest`
--
ALTER TABLE `serverrequest` ADD CONSTRAINT FOREIGN KEY (`requestid`) REFERENCES `request` (`id`) ON DELETE CASCADE;
ALTER TABLE `serverrequest` ADD CONSTRAINT FOREIGN KEY (`admingroupid`) REFERENCES `usergroup` (`id`) ON UPDATE CASCADE;
ALTER TABLE `serverrequest` ADD CONSTRAINT FOREIGN KEY (`logingroupid`) REFERENCES `usergroup` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `shibauth`
--
ALTER TABLE `shibauth` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `statgraphcache`
--
ALTER TABLE `statgraphcache` ADD CONSTRAINT FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;
ALTER TABLE `statgraphcache` ADD CONSTRAINT FOREIGN KEY (`provisioningid`) REFERENCES `provisioning` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `subimages`
--
ALTER TABLE `subimages` ADD CONSTRAINT FOREIGN KEY (`imagemetaid`) REFERENCES `imagemeta` (`id`) ON UPDATE CASCADE;
ALTER TABLE `subimages` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);

--
-- Constraints for table `sublog`
--
ALTER TABLE `sublog` ADD CONSTRAINT FOREIGN KEY (`logid`) REFERENCES `log` (`id`) ON UPDATE CASCADE;
ALTER TABLE `sublog` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);
ALTER TABLE `sublog` ADD CONSTRAINT FOREIGN KEY (`imagerevisionid`) REFERENCES `imagerevision` (`id`) ON UPDATE CASCADE;
ALTER TABLE `sublog` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);
ALTER TABLE `sublog` ADD CONSTRAINT FOREIGN KEY (`managementnodeid`) REFERENCES `managementnode` (`id`);
ALTER TABLE `sublog` ADD CONSTRAINT FOREIGN KEY (`predictivemoduleid`) REFERENCES `module` (`id`) ON UPDATE CASCADE;
ALTER TABLE `sublog` ADD CONSTRAINT FOREIGN KEY (`hostcomputerid`) REFERENCES `computer` (`id`);
ALTER TABLE `sublog` ADD CONSTRAINT FOREIGN KEY (`blockRequestid`) REFERENCES `blockRequest` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `user`
-- 
ALTER TABLE `user` ADD CONSTRAINT FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;
ALTER TABLE `user` ADD CONSTRAINT FOREIGN KEY (`IMtypeid`) REFERENCES `IMtype` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- 
-- Constraints for table `usergroup`
-- 
ALTER TABLE `usergroup` ADD CONSTRAINT FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `usergroup` ADD CONSTRAINT FOREIGN KEY (`editusergroupid`) REFERENCES `usergroup` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE `usergroup` ADD CONSTRAINT FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `usergroupmembers`
-- 
ALTER TABLE `usergroupmembers` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `usergroupmembers` ADD CONSTRAINT FOREIGN KEY (`usergroupid`) REFERENCES `usergroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `usergrouppriv`
--
ALTER TABLE `usergrouppriv` ADD CONSTRAINT FOREIGN KEY (`userprivtypeid`) REFERENCES `usergroupprivtype` (`id`) ON UPDATE CASCADE;
ALTER TABLE `usergrouppriv` ADD CONSTRAINT FOREIGN KEY (`usergroupid`) REFERENCES `usergroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `userpriv`
-- 
ALTER TABLE `userpriv` ADD CONSTRAINT FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;
ALTER TABLE `userpriv` ADD CONSTRAINT FOREIGN KEY (`usergroupid`) REFERENCES `usergroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `userpriv` ADD CONSTRAINT FOREIGN KEY (`privnodeid`) REFERENCES `privnode` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `userpriv` ADD CONSTRAINT FOREIGN KEY (`userprivtypeid`) REFERENCES `userprivtype` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `vmhost`
--
ALTER TABLE `vmhost` ADD CONSTRAINT FOREIGN KEY (`vmprofileid`) REFERENCES `vmprofile` (`id`) ON UPDATE CASCADE;
ALTER TABLE `vmhost` ADD CONSTRAINT FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);

--
-- Constraints for table `vmprofile`
--
ALTER TABLE `vmprofile` ADD CONSTRAINT FOREIGN KEY (`imageid`) REFERENCES `image` (`id`);
ALTER TABLE `vmprofile` ADD CONSTRAINT FOREIGN KEY (`repositoryimagetypeid`) REFERENCES `imagetype` (`id`) ON UPDATE CASCADE;
ALTER TABLE `vmprofile` ADD CONSTRAINT FOREIGN KEY (`datastoreimagetypeid`) REFERENCES `imagetype` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `winKMS`
--
ALTER TABLE `winKMS` ADD CONSTRAINT FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `winProductKey`
--
ALTER TABLE `winProductKey` ADD CONSTRAINT FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;
  
--
-- Legacy columns to drop
--

ALTER TABLE `computer` ADD `deptid` bit(1) NULL default NULL;
ALTER TABLE `computer` DROP `deptid`;

ALTER TABLE `computer` ADD `preferredimageid` bit(1) NULL default NULL;
ALTER TABLE `computer` DROP `preferredimageid`;

ALTER TABLE `connectmethod` ADD `protocol` bit(1) NULL default NULL;
ALTER TABLE `connectmethod` DROP `protocol`;

ALTER TABLE `connectmethod` ADD `port` bit(1) NULL default NULL;
ALTER TABLE `connectmethod` DROP `port`;

ALTER TABLE `image` ADD `deptid` bit(1) NULL default NULL;
ALTER TABLE `image` DROP `deptid`;

ALTER TABLE `imagemeta` ADD `usergroupid` bit(1) NULL default NULL;
ALTER TABLE `imagemeta` DROP `usergroupid`;

ALTER TABLE `managementnode` ADD `predictivemoduleid` bit(1) NULL default NULL;
ALTER TABLE `managementnode` DROP `predictivemoduleid`;

ALTER TABLE `request` ADD `reservationid` bit(1) NULL default NULL;
ALTER TABLE `request` DROP `reservationid`;

ALTER TABLE `request` ADD `imageid` bit(1) NULL default NULL;
ALTER TABLE `request` DROP `imageid`;

ALTER TABLE `reservation` ADD `daterequested` bit(1) NULL default NULL;
ALTER TABLE `reservation` DROP `daterequested`;

ALTER TABLE `reservation` ADD `datemodified` bit(1) NULL default NULL;
ALTER TABLE `reservation` DROP `datemodified`;

ALTER TABLE `reservation` ADD `end` bit(1) NULL default NULL;
ALTER TABLE `reservation` DROP `end`;

ALTER TABLE `reservation` ADD `start` bit(1) NULL default NULL;
ALTER TABLE `reservation` DROP `start`;

ALTER TABLE `user` ADD `curriculumid` bit(1) NULL default NULL;
ALTER TABLE `user` DROP `curriculumid`;

ALTER TABLE `user` ADD `middlename` bit(1) NULL default NULL;
ALTER TABLE `user` DROP `middlename`;

ALTER TABLE `vmhost` ADD `vmwaredisk` bit(1) NULL default NULL;
ALTER TABLE `vmhost` DROP `vmwaredisk`;

ALTER TABLE `vmhost` ADD `vmkernalnic` bit(1) NULL default NULL;
ALTER TABLE `vmhost` DROP `vmkernalnic`;

ALTER TABLE `vmprofile` ADD `vmtypeid` bit(1) NULL default NULL;
ALTER TABLE `vmprofile` DROP `vmtypeid`;

ALTER TABLE `vmprofile` ADD `nasshare` bit(1) NULL default NULL;
ALTER TABLE `vmprofile` DROP `nasshare`;

--
-- Legacy tables to drop
--

DROP TABLE IF EXISTS `xmlrpcKey`;
DROP TABLE IF EXISTS `curriculum`;
DROP TABLE IF EXISTS `dept`;
