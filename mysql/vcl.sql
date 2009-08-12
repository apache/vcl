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
  `sitewwwaddress` varchar(56) default NULL,
  `helpaddress` varchar(32) default NULL,
  `shibonly` tinyint(1) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `blockComputers`
-- 

CREATE TABLE IF NOT EXISTS `blockComputers` (
  `blockTimeid` mediumint(8) unsigned NOT NULL default '0',
  `computerid` smallint(5) unsigned NOT NULL default '0',
  `imageid` smallint(5) unsigned NOT NULL default '0',
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
  `groupid` smallint(5) unsigned NOT NULL,
  `repeating` enum('weekly','monthly','list') NOT NULL default 'weekly',
  `ownerid` mediumint(8) unsigned NOT NULL,
  `admingroupid` mediumint(8) unsigned NOT NULL,
  `managementnodeid` smallint(5) unsigned NOT NULL,
  `expireTime` datetime NOT NULL,
  `processing` tinyint(1) unsigned NOT NULL,
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
  `start` datetime default NULL,
  `end` datetime default NULL,
  `computerid` smallint(5) unsigned default NULL,
  `remoteIP` varchar(15) default NULL,
  `wasavailable` tinyint(1) unsigned default NULL,
  `timestamp` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  KEY `logid` (`logid`)
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
  `platformid` tinyint(3) unsigned NOT NULL default '0',
  `scheduleid` tinyint(3) unsigned default NULL,
  `currentimageid` smallint(5) unsigned NOT NULL default '0',
  `preferredimageid` smallint(5) unsigned NOT NULL default '0',
  `nextimageid` smallint(5) unsigned NOT NULL default '0',
  `imagerevisionid` mediumint(8) unsigned NOT NULL default '0',
  `RAM` smallint(5) unsigned NOT NULL default '0',
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
  `notes` text,
  `lastcheck` datetime default NULL,
  `location` varchar(10) default NULL,
  `dsa` mediumtext,
  `dsapub` mediumtext,
  `rsa` mediumtext,
  `rsapub` mediumtext,
  `host` blob,
  `hostpub` mediumtext,
  `vmhostid` smallint(5) unsigned default NULL,
  `vmtypeid` tinyint(3) unsigned default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `hostname` (`hostname`),
  UNIQUE KEY `eth1macaddress` (`eth1macaddress`),
  UNIQUE KEY `eth0macaddress` (`eth0macaddress`),
  KEY `ownerid` (`ownerid`),
  KEY `stateid` (`stateid`),
  KEY `platformid` (`platformid`),
  KEY `scheduleid` (`scheduleid`),
  KEY `currentimageid` (`currentimageid`),
  KEY `type` (`type`),
  KEY `vmhostid` (`vmhostid`),
  KEY `vmtypeid` (`vmtypeid`),
  KEY `deleted` (`deleted`),
  KEY `nextimageid` (`nextimageid`),
  KEY `provisioningid` (`provisioningid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `computerloadflow`
-- 

CREATE TABLE IF NOT EXISTS `computerloadflow` (
  `computerloadstateid` smallint(8) NOT NULL,
  `nextstateid` smallint(8) default NULL,
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
  `id` mediumint(12) unsigned NOT NULL auto_increment,
  `reservationid` mediumint(8) unsigned NOT NULL,
  `computerid` smallint(8) unsigned NOT NULL,
  `loadstateid` smallint(8) unsigned default NULL,
  `timestamp` datetime default NULL,
  `additionalinfo` text,
  PRIMARY KEY  (`id`),
  KEY `reservationid` (`reservationid`),
  KEY `loadstateid` (`loadstateid`)
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
  KEY `expiretime` (`expiretime`)
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
  `prettyname` varchar(60) NOT NULL default '',
  `ownerid` mediumint(8) unsigned default '1',
  `platformid` tinyint(3) unsigned NOT NULL default '0',
  `OSid` tinyint(3) unsigned NOT NULL default '0',
  `imagemetaid` smallint(5) unsigned default NULL,
  `minram` smallint(5) unsigned NOT NULL default '0',
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
  `size` smallint(5) unsigned NOT NULL default '1450',
  `architecture` enum('x86','x86_64') NOT NULL default 'x86',
  `description` text,
  `usage` text,
  `basedoffrevisionid` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `prettyname` (`prettyname`),
  KEY `ownerid` (`ownerid`),
  KEY `platformid` (`platformid`),
  KEY `OSid` (`OSid`),
  KEY `imagemetaid` (`imagemetaid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `imagemeta`
-- 

CREATE TABLE IF NOT EXISTS `imagemeta` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `checkuser` tinyint(1) unsigned NOT NULL default '1',
  `subimages` tinyint(1) unsigned NOT NULL default '0',
  `usergroupid` smallint(5) unsigned default NULL,
  `sysprep` tinyint(1) unsigned NOT NULL default '1',
  `postoption` varchar(32) default NULL,
  `architecture` varchar(10) default NULL,
  `rootaccess` tinyint(1) unsigned NOT NULL default '1',
  PRIMARY KEY  (`id`),
  KEY `usergroupid` (`usergroupid`)
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
  PRIMARY KEY  (`id`),
  UNIQUE KEY `production` (`production`,`imagename`),
  UNIQUE KEY `imageid` (`imageid`,`revision`),
  KEY `userid` (`userid`)
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
  `predictivemoduleid` smallint(5) unsigned NOT NULL default '1',
  `sshport` smallint(5) unsigned NOT NULL default '22',
  PRIMARY KEY  (`id`),
  KEY `stateid` (`stateid`),
  KEY `ownerid` (`ownerid`),
  KEY `imagelibgroupid` (`imagelibgroupid`),
  KEY `IPaddress` (`IPaddress`),
  KEY `predictivemoduleid` (`predictivemoduleid`)
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
  KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `OS`
-- 

CREATE TABLE IF NOT EXISTS `OS` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(20) NOT NULL,
  `prettyname` varchar(35) NOT NULL default '',
  `type` varchar(30) NOT NULL,
  `installtype` varchar(30) NOT NULL default 'image',
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
  KEY `moduleid` (`moduleid`)
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
  `pw` varchar(10) default NULL,
  PRIMARY KEY  (`id`),
  KEY `managementnodeid` (`managementnodeid`),
  KEY `imageid` (`imageid`),
  KEY `requestid` (`requestid`),
  KEY `computerid` (`computerid`),
  KEY `imagerevisionid` (`imagerevisionid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

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
  `type` enum('block','cascade','available','administer','manageGroup') NOT NULL default 'block',
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
  `logid` int(10) unsigned NOT NULL default '0',
  `imageid` smallint(5) unsigned NOT NULL default '0',
  `imagerevisionid` mediumint(8) unsigned NOT NULL,
  `computerid` smallint(5) unsigned NOT NULL default '0',
  `IPaddress` varchar(15) default NULL,
  `managementnodeid` smallint(5) unsigned NOT NULL default '0',
  `predictivemoduleid` smallint(5) unsigned NOT NULL default '8',
  KEY `logid` (`logid`),
  KEY `imageid` (`imageid`),
  KEY `imagerevisionid` (`imagerevisionid`),
  KEY `computerid` (`computerid`)
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
  `IMtypeid` tinyint(3) unsigned NOT NULL default '1',
  `IMid` varchar(80) default NULL,
  `adminlevelid` tinyint(3) unsigned NOT NULL default '1',
  `width` smallint(4) unsigned NOT NULL default '1024',
  `height` smallint(4) unsigned NOT NULL default '768',
  `bpp` tinyint(2) unsigned NOT NULL default '16',
  `audiomode` enum('none','local') NOT NULL default 'local',
  `mapdrives` tinyint(1) unsigned NOT NULL default '1',
  `mapprinters` tinyint(1) unsigned NOT NULL default '1',
  `mapserial` tinyint(1) unsigned NOT NULL default '0',
  `showallgroups` tinyint(1) unsigned NOT NULL default '0',
  `lastupdated` datetime NOT NULL default '0000-00-00 00:00:00',
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
  `initialmaxtime` smallint(5) unsigned NOT NULL default '240',
  `totalmaxtime` smallint(5) unsigned NOT NULL default '360',
  `maxextendtime` smallint(5) unsigned NOT NULL default '30',
  `overlapResCount` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`,`affiliationid`),
  KEY `ownerid` (`ownerid`),
  KEY `editusergroupid` (`editusergroupid`)
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
-- Table structure for table `userpriv`
-- 

CREATE TABLE IF NOT EXISTS `userpriv` (
  `id` mediumint(8) unsigned NOT NULL auto_increment,
  `userid` mediumint(8) unsigned default NULL,
  `usergroupid` smallint(5) unsigned default NULL,
  `privnodeid` mediumint(8) unsigned NOT NULL default '0',
  `userprivtypeid` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`,`privnodeid`,`userprivtypeid`),
  UNIQUE KEY `userid` (`userid`,`usergroupid`,`privnodeid`,`userprivtypeid`),
  KEY `privnodeid` (`privnodeid`),
  KEY `usergroupid` (`usergroupid`),
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
  `vmlimit` tinyint(3) unsigned NOT NULL,
  `vmprofileid` tinyint(5) unsigned NOT NULL default '1',
  `vmkernalnic` varchar(15) default NULL,
  `vmwaredisk` enum('localdisk','networkdisk') NOT NULL default 'localdisk',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `computerid` (`computerid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `vmprofile`
-- 

CREATE TABLE IF NOT EXISTS `vmprofile` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `profilename` varchar(56) NOT NULL,
  `vmtypeid` tinyint(3) unsigned NOT NULL,
  `imageid` smallint(5) unsigned NOT NULL,
  `nasshare` varchar(128) default NULL,
  `datastorepath` varchar(128) NOT NULL,
  `vmpath` varchar(128) default NULL,
  `virtualswitch0` varchar(80) NOT NULL default 'VMnet0',
  `virtualswitch1` varchar(80) NOT NULL default 'VMnet2',
  `vmdisk` enum('localdisk','networkdisk') NOT NULL default 'localdisk',
  `username` varchar(32) NULL default NULL,
  `password` varchar(128) NULL default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `vmtype`
-- 

CREATE TABLE IF NOT EXISTS `vmtype` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `xmlrpcKey`
-- 

CREATE TABLE IF NOT EXISTS `xmlrpcKey` (
  `id` smallint(5) unsigned NOT NULL auto_increment,
  `ownerid` mediumint(8) unsigned NOT NULL default '0',
  `key` varchar(255) NOT NULL default '',
  `active` tinyint(1) NOT NULL default '1',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Table structure for table `xmlrpcLog`
-- 

CREATE TABLE IF NOT EXISTS `xmlrpcLog` (
  `xmlrpcKeyid` smallint(5) unsigned NOT NULL default '0' COMMENT 'this is the userid if apiversion greater than 1',
  `timestamp` datetime NOT NULL default '0000-00-00 00:00:00',
  `IPaddress` varchar(15) default NULL,
  `method` varchar(60) default NULL,
  `apiversion` tinyint(3) unsigned NOT NULL default '1',
  `comments` text,
  KEY `xmlrpcKeyid` (`xmlrpcKeyid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- =========================================================
-- Data

-- 
-- Dumping data for table `adminlevel`
-- 

INSERT INTO `adminlevel` (`id`, `name`) VALUES 
(3, 'developer'),
(2, 'full'),
(1, 'none');

-- 
-- Dumping data for table `affiliation`
-- 

INSERT INTO `affiliation` (`id`, `name`, `dataUpdateText`) VALUES 
(1, 'Local', '');


-- 
-- Dumping data for table `computerloadflow`
-- 
INSERT INTO `computerloadflow` (`computerloadstateid`, `nextstateid`, `type`) VALUES 
(4, 22, 'blade'),
(6, 15, 'blade'),
(9, 43, 'blade'),
(12, 9, 'blade'),
(18, NULL, 'blade'),
(15, 21, 'blade'),
(21, 12, 'blade'),
(22, 6, 'blade'),
(22, 40, 'virtualmachine'),
(40, 27, 'virtualmachine'),
(27, 28, 'virtualmachine'),
(28, 48, 'virtualmachine'),
(48, 46, 'virtualmachine'),
(46, 9, 'virtualmachine'),
(41, 18, 'virtualmachine'),
(18, NULL, 'virtualmachine'),
(41, 18, 'blade'),
(9, 43, 'virtualmachine'),
(43, 41, 'blade'),
(43, 41, 'virtualmachine');
-- 
-- Dumping data for table `computerloadstate`
-- 

INSERT INTO `computerloadstate` (`id`, `loadstatename`, `prettyname`, `est`) VALUES 
(1, 'info', 'info', 2),
(2, 'loadimageblade', 'must reload computer', 0),
(3, 'loadimagevmware', 'loadimagevmware', 1),
(4, 'statuscheck', 'computer status check', 10),
(5, 'assign2project', 'changing VLAN setting ', 0),
(6, 'rinstall', 'starting install process', 1),
(7, 'dynamicDHCPaddress', 'detecting dynamic IP address', 2),
(8, 'staticIPaddress', 'setting static IP address', 2),
(9, 'loadimagecomplete', 'running post configuration', 0),
(10, 'loadimagefailed', 'preparing computer failed', 2),
(11, 'failed', 'reservation failed', 2),
(12, 'bootstate', 'image loading', 175),
(13, 'editnodetype', 'edit config file to load requested image', 1),
(14, 'xcatstage1', 'detected dhcp request from node', 2),
(15, 'xcatstage2', 'rebooting node for reinstall', 100),
(16, 'WARNING', 'WARNING', 2),
(17, 'xcatREADY', 'computer reported READY starting post configs', 2),
(18, 'reserved', 'ready for Connect', 0),
(19, 'xcatstage3', 'node starting to received install instructions', 93),
(20, 'xcatstage4', 'node received install instructions', 0),
(21, 'xcatstage5', 'starting reload process', 27),
(22, 'doesimageexists', 'confirming image exists', 4),
(23, 'vmround1', 'vmround1', 1),
(26, 'vmround2', 'vmround2', 186),
(27, 'transfervm', 'transferring image files to host server', 255),
(28, 'vmsetupconfig', 'creating configuration file', 2),
(29, 'vmstage1', 'detected stage 1 of 5 loading process', 22),
(30, 'vmstage2', 'detected stage 2 of 5 loading process', 120),
(31, 'vmstage3', 'detected stage 3 of 4 loading process', 0),
(33, 'xcatround2', 'waiting for image loading to complete', 0),
(34, 'xcatround3', 'loaded - start post configuration', 0),
(35, 'xcatround1', 'xcatround1', 2),
(38, 'timeout', 'timeout', 2),
(39, 'vmwareready', 'machine online', 3),
(40, 'startload', 'starting load process', 6),
(41, 'addinguser', 'adding user account', 18),
(42, 'connected', 'detected user connection', 2),
(43, 'nodeready', 'resource ready', 0),
(44, 'inuseend10', '10 minute warning ', 2),
(45, 'inuseend5', '5 minute warning', 2),
(46, 'vmstage4', 'machine booting', 68),
(47, 'checklabstatus', 'checking computer status', 2),
(48, 'startvm', 'starting virtual machine', 3),
(49, 'vmstage5', 'detected stage 5 of 5 loading process', 1),
(50, 'vmconfigcopy', 'copying vm config file', NULL),
(51, 'imageloadcomplete', 'node ready to add user', 0),
(52, 'repeat', 'repeat', 0),
(53, 'deleted', 'deleted', NULL),
(54, 'begin', 'beginning to process reservation', 0);

-- 
-- Dumping data for table `documentation`
-- 

INSERT INTO `documentation` (`name`, `title`, `data`) VALUES 
('GrantingAccesstoaNewImageEnvironment1', 'Granting Access to a New Image/Environment', '<div id="docbullets">\r\n<h2>Overview</h2>\r\n<p>Once you have created a new image, there are a few things you have to do to allow other people to use it.&nbsp; If you don''t have access to do any of the following steps, you will need to get a VCL administrator to do them for you.</p>\r\n<p>When you create a new image, it is only available to you, and it is only allowed to be run on a few computers that have been set aside for the testing of new images.</p>\r\n<h2>Step 1: Image Mapping</h2>\r\n<p>Images are mapped to be run on a set of computers. See the documentation on <a href="https://vcl.ncsu.edu/scheduling/index.php?mode=viewdocs&amp;item=Resources"><span style="color: rgb(255, 0, 0);"><b>Resources</b></span></a> to learn more about why this is done. For your new image to be able to run on more computers than just those designated for testing, you need to map it to a set of computers. There are a few steps to this process:</p>\r\n<ol>\r\n    <li>You need to make your image a member of an image group\r\n    <ul>\r\n        <li>Select <span style="color: rgb(0, 0, 255);">Manage Images</span>-&gt;<span style="color: rgb(0, 0, 255);">Edit Image Grouping</span></li>\r\n        <li>Select your image from the drop down box and click <span style="color: rgb(0, 0, 255);">Get Groups</span></li>\r\n        <li>Choose one or more image groups to which you would like to add the image from the box on the right</li>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">&lt;-Add</span> to make the image a member of the group(s)</li>\r\n    </ul>\r\n    </li>\r\n    <li>You need to map the image group(s) you selected in step 1 to one or more computer groups\r\n    <ul>\r\n        <li>Select <span style="color: rgb(0, 0, 255);">Manage Images</span>-&gt;<span style="color: rgb(0, 0, 255);">Edit Image Mapping</span></li>\r\n        <li>Do the following for each group from step 1:<br />\r\n        <ul>\r\n            <li>Select the image group from the drop down box and click <span style="color: rgb(0, 0, 255);">Get Computer Groups</span></li>\r\n            <li>Choose one or more computer groups to which you would like to map the image group from the box on the right</li>\r\n            <li>click <span style="color: rgb(0, 0, 255);">&lt;-Add</span> to make map the image group to the computer group(s)</li>\r\n        </ul>\r\n        </li>\r\n        <li>Note: there is an assumption here that the computer groups you selected already have computers that are in those groups</li>\r\n    </ul>\r\n    </li>\r\n</ol>\r\n<h2>Step 2: Privileges</h2>\r\n<p>Now, you need to grant access to use the image to a user or group of users under the Privileges section of the site.&nbsp; Here are the steps involved:</p>\r\n<ol>\r\n    <li>Select <span style="color: rgb(0, 0, 255);">Privileges</span></li>\r\n    <li>Choose an existing node or create a new node in the tree structure in the upper portion of the page where you would like to assign the user(s) access</li>\r\n    <li>Now, you need to grant the user <span style="color: rgb(0, 0, 255);">imageCheckOut</span> at the node.&nbsp; You can do this for an individual user or a group of users.\r\n    <ul>\r\n        <li>Individual User:\r\n        <ul>\r\n            <li>Click <span style="color: rgb(0, 0, 255);">Add User</span></li>\r\n            <li>Enter the user''s id in the text box and select the <span style="color: rgb(0, 0, 255);">imageCheckOut</span> checkbox</li>\r\n            <li>Click <span style="color: rgb(0, 0, 255);">Submit New User</span></li>\r\n        </ul>\r\n        </li>\r\n        <li>User Group:\r\n        <ul>\r\n            <li>Click <span style="color: rgb(0, 0, 255);">Add Group</span></li>\r\n            <li>Select the user group from the drop-down box and select the <span style="color: rgb(0, 0, 255);">imageCheckOut</span> checkbox</li>\r\n            <li>Click <span style="color: rgb(0, 0, 255);">Submit New User Group</span></li>\r\n        </ul>\r\n        </li>\r\n    </ul>\r\n    </li>\r\n    <li>Next, you need to make sure the image group in which you placed the image in step 1 of <b>Image Mapping</b> is available at this node. If it is, go on to the next step, if not:\r\n    <ul>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">Add Resource Group</span></li>\r\n        <li>Select the image group from the drop-down box and select the <span style="color: rgb(0, 0, 255);">available</span> checkbox</li>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">Submit New Resource Group</span></li>\r\n    </ul>\r\n    </li>\r\n    <li>Finally, you need to make sure the computer group(s) selected in step 2 of <b>Image Mapping</b> are also available here. If so, you are finished.&nbsp; If not:\r\n    <ul>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">Add Resource Group</span></li>\r\n        <li>Select the computer group from the drop-down box and select the <span style="color: rgb(0, 0, 255);">available</span> checkbox</li>\r\n        <li>Click <span style="color: rgb(0, 0, 255);">Submit New Resource Group</span></li>\r\n    </ul>\r\n    </li>\r\n</ol>\r\n<p>Now, the user or user groups you have added to this node will be able to make reservations for the new image.</p>\r\n</div>'),
('OverviewofPrivileges-Whatpermissionsarerequiredtoaccesspartsofthesite', 'Overview of Privileges - What permissions are required to access parts of the site', '<p>These are the privileges a user needs to access various parts of the VCL site. Unless specifically specified, a user must have both the <span style="color: rgb(0, 0, 255);">user<span style="color: rgb(0, 0, 0);"> and the <span style="color: rgb(255, 102, 0);">resource</span> permissions granted at the same node in the privilege tree.</span></span> &quot;<span style="color: rgb(0, 0, 255);">user</span>&quot; refers to privileges granted on the Privileges page either specifically to a user or to a group of which a user is a member. &quot;<span style="color: rgb(255, 102, 0);">resource</span>&quot; refers to privileges granted on the Privileges page to a resource group. Privileges can only be granted to resource groups; there is no way to grant privileges to a specific resource (image, computer, etc).</p>\r\n<h2>New Reservation</h2>\r\n<p style="margin-left: 40px;">This shows up for everyone, but the following privileges must be granted to be able to actually make a reservation:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user<span style="color: rgb(0, 0, 0);"> - imageCheckOut</span></span><br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: available, computer group: available</p>\r\n<h2>Manage Groups</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user <span style="color: rgb(0, 0, 0);">- groupAdmin is required to make this link show up</span></span></p>\r\n<h3 style="margin-left: 40px;">User Groups</h3>\r\n<p style="margin-left: 80px;">Groups a user owns and groups that are editable by groups a user is a member of show up in this section.</p>\r\n<h3 style="margin-left: 40px;">Resource Groups</h3>\r\n<p style="margin-left: 80px;">Groups owned by user groups a user is a member of show up here.&nbsp; More groups show up when the following attribute is granted for a resource group:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(255, 102, 0);">resource<span style="color: rgb(0, 0, 0);"> - (any type) manageGroup</span></span></p>\r\n<h2>Manage Images</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin is required to make this link show up</p>\r\n<h3 style="margin-left: 40px;">Edit Image Information</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: administer</p>\r\n<h3 style="margin-left: 40px;">View Image Grouping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">View Image Mapping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: manageGroup</p>\r\n<p style="margin-left: 80px;">at same or different node:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">Create New Image</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: available, computer group: available</p>\r\n<h2>Manage Schedules</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin is required to make this link show up</p>\r\n<p style="margin-left: 40px;">All schedules owned by a user will show up by default.</p>\r\n<p style="margin-left: 40px;">To edit schedule information for other schedules, these permissions are required:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - schedule group: administer</p>\r\n<h3 style="margin-left: 40px;">Schedule Grouping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - schedule group: manageGroup</p>\r\n<h2>Manage Computers</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin is required to make this link show up</p>\r\n<p style="margin-left: 40px;">Selection boxes for platforms and schedules only show up if a user has access to more than one platform or schedule.</p>\r\n<h3 style="margin-left: 40px;">Edit Computer Grouping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">Computer Utilities</h3>\r\n<h4 style="margin-left: 80px;">Reload computers with image</h4>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: administer</p>\r\n<p style="margin-left: 120px;">and at same or different node:</p>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - imageCheckOut or imageAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - image group: available</p>\r\n<h4 style="margin-left: 80px;">Change state of computers</h4>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: administer</p>\r\n<h4 style="margin-left: 80px;">Change schedule of computers</h4>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: administer</p>\r\n<p style="margin-left: 120px;">and at same or different node:</p>\r\n<p style="margin-left: 120px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - schedule group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">Edit Computer Information</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: administer</p>\r\n<p style="margin-left: 80px;">and at same or different node:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - scheduleAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - schedule group: manageGroup</p>\r\n<p style="margin-left: 80px;">&nbsp;</p>\r\n<h2>Management Nodes</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - mgmtNodeAdmin is required to make this link show up</p>\r\n<h3 style="margin-left: 40px;">Edit Management Node Information</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - mgmtNodeAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - management node group: administer</p>\r\n<h3 style="margin-left: 40px;">Edit Management Node Grouping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - mgmtNodeAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - management node group: manageGroup</p>\r\n<h3 style="margin-left: 40px;">Edit Management Node Mapping</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - mgmtNodeAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - management node group: manageGroup</p>\r\n<p style="margin-left: 80px;">at same or different node:</p>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - computerAdmin<br />\r\n<span style="color: rgb(255, 102, 0);">resource</span> - computer group: manageGroup</p>\r\n<h2>Privileges</h2>\r\n<p style="margin-left: 40px;"><span style="color: rgb(0, 0, 255);">user</span> - nodeAdmin, userGrant, or resourceGrant is required to make this link show up</p>\r\n<h3 style="margin-left: 40px;">Add Child / Delete Node and Children</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - nodeAdmin</p>\r\n<h3 style="margin-left: 40px;">Add User / modify user privileges</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - userGrant</p>\r\n<h3 style="margin-left: 40px;">Add Group / modify user group privileges</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - userGrant</p>\r\n<h3 style="margin-left: 40px;">Add Resource Group / modify resource group privileges</h3>\r\n<p style="margin-left: 80px;"><span style="color: rgb(0, 0, 255);">user</span> - resourceGrant</p>\r\n<p>&nbsp;</p>'),
('Resources', 'Resources', '<h2>Overview</h2>\r\n<p>Computers, images, management nodes, and schedules have some very similar characteristics in how they are handled within the VCL site. Therefore, there are times where it is easier to refer to them all together as <b><span style="color: rgb(255, 0, 0);">resources</span></b>. Here are some similarities between them:</p>\r\n<ul>\r\n    <li>They are all managed by adding them to <span style="color: rgb(255, 0, 0);"><b>resource groups</b></span>.&nbsp; All resource groups have a type associated with them such that only <span style="color: rgb(0, 0, 255);">images</span> can be part of an <span style="color: rgb(0, 0, 255);">image group</span>, only <span style="color: rgb(0, 0, 255);">computers</span> can be part of a <span style="color: rgb(0, 0, 255);">computer group</span>, etc.</li>\r\n    <li>Resources of one type can be related to resources of certain other types through <span style="color: rgb(255, 0, 0);"><b>resource mapping</b></span>. <span style="color: rgb(0, 0, 255);">Image groups</span> and <span style="color: rgb(0, 0, 255);">computer groups</span> can be mapped together, and <span style="color: rgb(0, 0, 255);">management node</span><span style="color: rgb(0, 0, 255);"> groups</span> and&nbsp;<span style="color: rgb(0, 0, 255);">computer</span><span style="color: rgb(0, 0, 255);"> groups</span> can be mapped together.</li>\r\n    <li>Privileges over resources are only granted through resource groups.&nbsp; Privileges cannot be granted directly to a resource.</li>\r\n    <li>There is an <span style="color: rgb(255, 0, 0);"><b>Admin</b></span> privilege that can be granted to users for each type of resource: computerAdmin, imageAdmin, mgmtNodeAdmin, and scheduleAdmin</li>\r\n</ul>\r\n<h2>Grouping</h2>\r\n<p>The amount of images and computers that become part of a VCL install can grow very rappidly. Because of this, it is much easier to deal with them in groups rather than individually. The amount of schedules and management nodes does not typically grow very large. However, due to other similarities as resources, they are handled in groups as well.</p>\r\n<h2>Mapping</h2>\r\n<p>Mapping allows for tight control over how resources can be used together. Through image to computer mapping, one has tight control over which computers an image could end up being run. This can be used to control things like platform dependencies, to ensure only vm images get run on the correct type of vm computer, and to ensure an image containing software purchased by a specific group only gets run on computers owned by the same group (this can be handled with resource privileges as well).</p>\r\n<p>Through management node to computer mapping, assignment of which management nodes control which computers is accomplished. One can quickly switch which management node is in control of a group of computers. Additionally, when management node redundancy is fully implemented, this is how management nodes will be able to control overlapping groups of computers.</p>\r\n<h2>Resource Privileges</h2>\r\n<p>There are three privileges that can be assigned to resource groups:</p>\r\n<ul>\r\n    <li>available</li>\r\n    <li>administer</li>\r\n    <li>manageGroup</li>\r\n</ul>\r\n<p><span style="color: rgb(0, 0, 255);">available</span> is only used for image and computer groups. If it is assigned to a schedule or management node group, it is simply ignored. This privilege correspondes to these user group privileges: imageCheckOut and imageAdmin. When a user has one of these two privileges at a node along with an image group or a computer group having the available privilege at the same node, then the user will have access to make a reservations for the images in the group (imageCheckOut) or make a new images based off of images in the group (imageAdmin). Note that both an image group and a computer group must have the available permission where a user has imageCheckOut for the user to make a reservation for an image in the image group. This is used to determine which computers are available at the node to go along with which images are also available at the node.</p>\r\n<p><span style="color: rgb(0, 0, 255);">administer</span> is used for all types of resources, and thus corresponds to all of the *Admin user privileges (computerAdmin, imageAdmin, mgmtNodeAdmin, and scheduleAdmin). Administer generally grants access to manage specific <i>characteristics</i> of resources in a group, but not to manage any grouping information. For example, if a user has the imageAdmin privilege at a node where an image group has the administer privilege, the user would then have access to modify <i>characteristics</i> of images in that group (name, owner, minimum specs required by the image, etc), but would <b>not</b> have access to edit which images are <i>in the group</i>.</p>\r\n<p><span style="color: rgb(0, 0, 255);">manageGroup</span> is also used for all types of resources. It grants access to a few different things. One is the ability to modify information about a group under <span style="color: rgb(0, 0, 255);">Manage Groups </span>(if a user also has the groupAdmin privilege). Another is the ability to manage membership of a group. Finally, it provides access for mapping one type of group to another (for this, manageGroup must be granted for both types of resources). Additionally, there is an extra way manageGroup is used specifically related to computer groups: a user must have scheduleAdmin and manageGroup over a schedule group to be able to change the schedule of a computer (both through Manage Computers-&gt;Edit Computer Information and Manage Computers-&gt;Computer Utilities-&gt;Change schedule of computers).</p>');

-- 
-- Dumping data for table `image`
-- 

INSERT INTO `image` (`id`, `name`, `prettyname`, `ownerid`, `platformid`, `OSid`, `imagemetaid`, `minram`, `minprocnumber`, `minprocspeed`, `minnetwork`, `maxconcurrent`, `reloadtime`, `deleted`, `test`, `lastupdate`, `forcheckout`, `maxinitialtime`, `project`, `size`) VALUES 
(1, 'winxp-base1-v0', 'No Apps (WinXP)', 1, 1, 7, NULL, 0, 1, 0, 10, NULL, 14, 0, 0, '2007-04-11 16:07:38', 1, 0, 'vcl', 1045),
(2, 'rhel4-base2-v0', 'Red Hat Enterprise Linux 4.4 Base (KS)', 1, 1, 12, NULL, 1024, 1, 1024, 100, NULL, 13, 0, 0, '2007-03-02 16:33:33', 1, 0, 'vcl', 0),
(3, 'rh4image-base3-v0', 'RHEL4 base (image)', 1, 1, 13, NULL, 10, 1, 1024, 100, NULL, 10, 0, 0, '2007-01-24 15:02:07', 1, 0, 'vcl', 1450),
(4, 'noimage', 'No Image', 1, 1, 2, NULL, 0, 1, 0, 10, NULL, 0, 0, 0, NULL, 1, 0, 'vcl', 1450),
(5, 'rhfc5-fc5base5-v0', 'Red Hat Fedora Core 5 base (KS)', 1, 1, 15, NULL, 1024, 1, 1024, 100, NULL, 13, 0, 0, '2006-10-02 10:04:24', 1, 0, 'vcl', 1450),
(6, 'fc5image-FC5baseRHFC56-v0', 'FC5base(RHFC5)', 1, 1, 14, NULL, 64, 1, 500, 10, NULL, 10, 0, 0, '2006-10-02 14:13:26', 1, 0, 'vcl', 0),
(7, 'vmwarewinxp-base7-v1', 'No Apps (WinXP vmware)', 1, 1, 16, NULL, 512, 1, 1024, 100, NULL, 5, 0, 0, '2007-04-04 09:45:38', 1, 0, 'vcl', 3244),
(8, 'rh4image-VMwareserverhostRHEL48-v3', 'VMware server host (RHEL4)', 1, 1, 13, NULL, 64, 1, 500, 10, NULL, 10, 0, 0, '2007-11-26 11:23:53', 1, 0, 'vcl', 1450),
(9, 'esx35-base-v0', 'VMware ESX 3.5 standard server', 1, 1, 20, NULL, 2048, 2, 2000, 100, NULL, 9, 0, 0, '2008-03-24 14:23:54', 1, 0, 'vcl', 1450);

-- 
-- Dumping data for table `imagerevision`
-- 

INSERT INTO `imagerevision` (`id`, `imageid`, `revision`, `userid`, `datecreated`, `deleted`, `production`, `comments`, `imagename`) VALUES 
(1, 1, 0, 1, '2007-03-01 14:46:26', 0, 1, NULL, 'winxp-base1-v0'),
(2, 2, 0, 1, '2006-09-22 16:33:24', 0, 1, NULL, 'rhel4-base2-v0'),
(3, 3, 0, 1, '2007-01-24 15:04:11', 0, 1, NULL, 'rh4image-base3-v0'),
(4, 4, 0, 1, '1980-01-01 00:00:00', 0, 1, NULL, 'noimage'),
(5, 5, 0, 1, '2006-10-02 10:04:24', 0, 1, NULL, 'rhfc5-fc5base5-v0'),
(6, 6, 0, 1, '2006-10-02 14:13:26', 0, 1, NULL, 'fc5image-FC5baseRHFC56-v0'),
(7, 7, 0, 1, '2007-04-03 11:24:12', 0, 1, NULL, 'vmwarewinxp-base7-v0'),
(8, 8, 0, 1, '2007-01-30 10:50:56', 0, 1, NULL, 'rh4image-VMwareserverhostRHEL48-v0'),
(9, 9, 0, 1, '2008-03-24 14:23:54', 0, 1, NULL, 'esx35-base-v0');

-- 
-- Dumping data for table `IMtype`
-- 

INSERT INTO `IMtype` (`id`, `name`) VALUES 
(2, 'jabber'),
(1, 'none');

-- 
-- Dumping data for table `localauth`
-- 

INSERT INTO `localauth` (`userid`, `passhash`, `salt`, `lastupdated`, `lockedout`) VALUES 
(1, 'd8c730cc269d3d6b6147a416fb49c2be1a70aefc', 'QwkCHLpY', '2007-05-17 09:56:01', 0),
(3, 'da60188ee483aa16eeb82d4969a0f79d0d177d99', '8ht2Pa55', '2007-05-17 09:56:01', 0);

-- 
-- Dumping data for table `module`
-- 

INSERT INTO `module` (`id`, `name`, `prettyname`, `description`, `perlpackage`) VALUES 
(1, 'provisioning_xcat_13', 'xCAT 1.3 Provisioning Module', '', 'VCL::Module::Provisioning::xCAT'),
(2, 'provisioning_vmware_gsx', 'VMware GSX Provisioning Module', '', 'VCL::Module::Provisioning::vmware'),
(3, 'provisioning_lab', 'Computing Lab Provisioning Module', '', 'VCL::Module::Provisioning::Lab'),
(4, 'os_windows', 'Windows OS Module', '', 'VCL::Module::OS::Windows'),
(5, 'os_linux', 'Linux OS Module', '', 'VCL::Module::OS::Linux'),
(6, 'os_unix', 'Unix OS Module', '', 'VCL::Module::OS'),
(7, 'os_winvista', 'Windows Vista OS Module', '', 'VCL::Module::OS::Windows::Version_6::Vista'),
(8, 'predictive_level_0', 'Predictive Loading Module Level 0', 'Selects an image to load based on upcoming reservations.', 'VCL::Module::Predictive::Level_0'),
(9, 'predictive_level_1', 'Predictive Loading Module Level 1', 'Selects an image to load based on historical data. Loads the most popular image that can be run on the machine that is not currently loaded and available on another node.', 'VCL::Module::Predictive::Level_1'),
(10, 'provisioning_vmware_esx', 'VMware ESX Provisioning Module', '', 'VCL::Module::Provisioning::esx'),
(11, 'provisioning_xcat_21', 'xCAT 2.1 Provisioning Module', '', 'VCL::Module::Provisioning::xCAT21'),
(12, 'os_winxp', 'Windows XP OS Module', '', 'VCL::Module::OS::Windows::Version_5::XP'),
(13, 'os_win2003', 'Windows Server 2003 OS Module', '', 'VCL::Module::OS::Windows::Version_5::2003'),
(14, 'os_linux_ubuntu', 'Ubuntu Linux OS Module', '', 'VCL::Module::OS::Linux::Ubuntu'),
(15, 'os_unix_lab', 'Unix Lab Module', 'Unix Lab OS support module', 'VCL::Module::OS::Linux::UnixLab');

-- 
-- Dumping data for table `OS`
-- 

INSERT INTO `OS` (`id`, `name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES
(2, 'sun4x_58', 'Solaris 5.8', 'unix', 'none', NULL, 15),
(3, 'win2k', 'Windows 2000', 'windows', 'partimage', 'image', 4),
(6, 'rhel3', 'Red Hat Enterprise Linux 3.0', 'linux', 'kickstart', 'rhas3', 5),
(7, 'winxp', 'Windows XP', 'windows', 'partimage', 'image', 12),
(8, 'realmrhel3', 'Realm Red Hat Enterprise Linux 3.0', 'linux', 'none', NULL, 15),
(9, 'realmrhel4', 'Realm Red Hat Enterprise Linux 4.0', 'linux', 'none', NULL, 15),
(10, 'win2003', 'Windows 2003 Server', 'windows', 'partimage', 'image', 13),
(11, 'rh3image', 'RHEL 3 image', 'linux', 'partimage', 'image', 5),
(12, 'rhel4', 'Red Hat Enterprise Linux 4', 'linux', 'kickstart', 'rhas4', 5),
(13, 'rh4image', 'RHEL4 image', 'linux', 'partimage', 'image', 5),
(14, 'fc5image', 'RH Fedora Core 5 image', 'linux', 'partimage', 'image', 5),
(15, 'rhfc5', 'Red Hat Fedora Core 5', 'linux', 'kickstart', 'rhfc5', 5),
(16, 'vmwarewinxp', 'VMware Windows XP', 'windows', 'vmware', 'vmware_images', 12),
(17, 'rhfc7', 'RH Fedora Core 7 KS', 'linux', 'kickstart', 'rhfc7', 5),
(18, 'fc7image', 'RH Fedora Core 7 image', 'linux', 'partimage', 'image', 5),
(19, 'rhel5', 'Red Hat Enterprise Linux 5', 'linux', 'kickstart', 'rhas5', 5),
(20, 'esx35', 'VMware ESX 3.5', 'linux', 'kickstart', 'esx35', 5),
(21, 'vmwareesxwinxp', 'VMware ESX Windows XP', 'windows', 'vmware', 'vmware_images', 12),
(22, 'realmrhel5', 'Realm Red Hat Enterprise Linux 5.0', 'linux', 'none', NULL, 15),
(23, 'sun4x_510  	', 'Solaris 10', 'unix', 'none', NULL, 15),
(24, 'centos5', 'CentOS 5', 'linux', 'kickstart', 'centos5', 5),
(25, 'rh5image', 'RedHat Enterprise Linux 5 (rhel5 im', 'linux', 'partimage', 'image', 5),
(26, 'rhfc9', 'RedHat Fedora Core 9 kickstart', 'linux', 'kickstart', 'rhfc9', 5),
(27, 'fc9image', 'RedHat Fedora Core 9 image', 'linux', 'partimage', 'image', 5),
(28, 'winvista', 'Windows Vista', 'windows', 'partimage', 'image', 7),
(29, 'centos5image', 'centos5image', 'linux', 'partimage', 'image', 5),
(30, 'ubuntuimage', 'Ubuntu image', 'linux', 'partimage', 'image', 14);

-- 
-- Dumping data for table `OSinstalltype`
-- 

INSERT INTO `OSinstalltype` (`id`, `name`) VALUES
(2, 'kickstart'),
(3, 'none'),
(1, 'partimage'),
(4, 'vmware');

-- 
-- Dumping data for table `OStype`
-- 

INSERT INTO `OStype` (`id`, `name`) VALUES
(2, 'linux'),
(3, 'unix'),
(1, 'windows');

-- 
-- Dumping data for table `platform`
-- 

INSERT INTO `platform` (`id`, `name`) VALUES 
(1, 'i386'),
(4, 'i386_lab'),
(3, 'ultrasparc');

-- 
-- Dumping data for table `privnode`
-- 

INSERT INTO `privnode` (`id`, `parent`, `name`) VALUES 
(2, 1, 'Developer'),
(1, 1, 'Root'),
(3, 2, 'VCL'),
(4, 3, 'admin'),
(5, 3, 'newimages');

-- 
-- Dumping data for table `privisioning`
-- 

INSERT INTO `provisioning` (`id`, `name`, `prettyname`, `moduleid`) VALUES
(1, 'xcat_13', 'xCAT 1.3', 1),
(2, 'vmware_server_gsx', 'VMware Server GSX', 2),
(3, 'lab', 'Computing Lab', 3),
(4, 'vmware_esx', 'VMware ESX', 10),
(5, 'xcat_21', 'xCAT 2.1', 11);

-- 
-- Dumping data for table `resource`
-- 

INSERT INTO `resource` (`id`, `resourcetypeid`, `subid`) VALUES 
(1, 13, 1),
(2, 13, 2),
(3, 13, 3),
(4, 13, 4),
(5, 13, 5),
(6, 13, 6),
(7, 13, 7),
(8, 15, 1),
(9, 13, 8),
(10, 13, 9);

-- 
-- Dumping data for table `resourcegroup`
-- 

INSERT INTO `resourcegroup` (`id`, `name`, `ownerusergroupid`, `resourcetypeid`) VALUES 
(1, 'allComputers', 3, 12),
(2, 'allImages', 3, 13),
(3, 'allManagementNodes', 3, 16),
(4, 'allSchedules', 3, 15),
(8, 'newimages', 4, 12),
(9, 'newvmimages', 4, 12),
(10, 'allVMimages', 4, 13);

-- 
-- Dumping data for table `resourcegroupmembers`
-- 

INSERT INTO `resourcegroupmembers` (`resourceid`, `resourcegroupid`) VALUES 
(1, 2),
(2, 2),
(3, 2),
(5, 2),
(6, 2),
(7, 10),
(8, 4),
(9, 2),
(10, 2);

-- 
-- Dumping data for table `resourcemap`
-- 

INSERT INTO `resourcemap` (`resourcegroupid1`, `resourcetypeid1`, `resourcegroupid2`, `resourcetypeid2`) VALUES 
(2, 13, 1, 12),
(3, 16, 1, 12),
(3, 16, 8, 12);

-- 
-- Dumping data for table `resourcepriv`
-- 

INSERT INTO `resourcepriv` (`id`, `resourcegroupid`, `privnodeid`, `type`) VALUES 
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
(16, 8, 5, 'available');

-- 
-- Dumping data for table `resourcetype`
-- 

INSERT INTO `resourcetype` (`id`, `name`) VALUES 
(12, 'computer'),
(13, 'image'),
(16, 'managementnode'),
(15, 'schedule');

-- 
-- Dumping data for table `schedule`
-- 

INSERT INTO `schedule` (`id`, `name`, `ownerid`) VALUES 
(1, 'VCL 24x7', 1);

-- 
-- Dumping data for table `scheduletimes`
-- 

INSERT INTO `scheduletimes` (`scheduleid`, `start`, `end`) VALUES 
(1, 0, 10080);

-- 
-- Dumping data for table `state`
-- 

INSERT INTO `state` (`id`, `name`) VALUES 
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
(20, 'vmhostinuse');

-- 
-- Dumping data for table `user`
-- 

INSERT INTO `user` (`id`, `uid`, `unityid`, `affiliationid`, `firstname`, `lastname`, `preferredname`, `email`, `emailnotices`, `IMtypeid`, `IMid`, `adminlevelid`, `width`, `height`, `bpp`, `audiomode`, `mapdrives`, `mapprinters`, `mapserial`, `showallgroups`, `lastupdated`) VALUES 
(1, 101, 'admin', 1, 'vcl', 'admin', '', 'root@localhost', 0, 1, NULL, 3, 1024, 768, 16, 'local', 1, 1, 1, 1, '2007-05-17 09:58:39'),
(2, NULL, 'vclreload', 1, 'vcl', 'reload', NULL, '', 0, 1, NULL, 1, 1024, 768, 16, 'local', 1, 1, 0, 0, '0000-00-00 00:00:00'),
(3, NULL, 'vclsystem', 1, 'vcl', 'system', NULL, '', 0, 1, NULL, 1, 1024, 768, 16, 'local', 1, 1, 0, 0, '0000-00-00 00:00:00');

-- 
-- Dumping data for table `usergroup`
-- 

INSERT INTO `usergroup` (`id`, `name`, `affiliationid`, `ownerid`, `editusergroupid`, `custom`, `courseroll`, `initialmaxtime`, `totalmaxtime`, `maxextendtime`) VALUES 
(1, 'global', 1, 1, 1, 1, 0, 240, 360, 30),
(3, 'adminUsers', 1, 1, 1, 1, 0, 480, 600, 180),
(4, 'manageNewImages', 1, 1, 3, 1, 0, 240, 360, 30),
(5, 'Specify End Time', 1, 1, 3, 1, 0, 240, 360, 30);

-- 
-- Dumping data for table `usergroupmembers`
-- 

INSERT INTO `usergroupmembers` (`userid`, `usergroupid`) VALUES 
(1, 1);

-- 
-- Dumping data for table `userpriv`
-- 

INSERT INTO `userpriv` (`id`, `userid`, `usergroupid`, `privnodeid`, `userprivtypeid`) VALUES 
(16, NULL, 3, 4, 3),
(11, NULL, 3, 4, 4),
(13, NULL, 3, 4, 5),
(14, NULL, 3, 4, 6),
(19, NULL, 3, 4, 7),
(17, NULL, 3, 4, 10),
(12, NULL, 3, 4, 11),
(18, NULL, 3, 4, 12),
(15, NULL, 3, 4, 13),
(1, 1, NULL, 3, 2),
(6, 1, NULL, 3, 3),
(2, 1, NULL, 3, 4),
(7, 1, NULL, 3, 5),
(3, 1, NULL, 3, 6),
(8, 1, NULL, 3, 7),
(4, 1, NULL, 3, 10),
(9, 1, NULL, 3, 11),
(5, 1, NULL, 3, 12),
(10, 1, NULL, 3, 13);

-- 
-- Dumping data for table `userprivtype`
-- 

INSERT INTO `userprivtype` (`id`, `name`) VALUES 
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
(7, 'userGrant');

-- 
-- Dumping data for table `vmprofile`
-- 

INSERT INTO `vmprofile` (`id`, `profilename`, `vmtypeid`, `imageid`, `nasshare`, `datastorepath`, `vmpath`, `virtualswitch0`, `virtualswitch1`, `vmdisk`) VALUES
(1, 'VMware GSX standard', 3, 8, NULL, '/var/lib/vmware/Virtual Machines', NULL, 'VMnet0', 'VMnet2', 'localdisk'),
(2, 'Vmware ESX standard network mounted share', 5, 9, NULL, '/vmfs/volumes/nfs1', '/vmfs/volumes/storage1', 'VM Network', 'Virtual Machine Public Network', 'networkdisk'),
(3, 'Vmware ESX standard localdisk', 5, 9, NULL, '/vmfs/volumes/storage1', NULL, 'VM Network', 'Virtual Machine Public Network', 'localdisk'),
(4, 'Vmware ESX SAN ', 6, 9, NULL, '/vmfs/volumes/NetApp', '/vmfs/volumes/storage1', 'Intranet2', 'MCNC Public', 'networkdisk');

-- 
-- Dumping data for table `vmtype`
-- 

INSERT INTO `vmtype` (`id`, `name`) VALUES
(1, 'vmware'),
(2, 'xen'),
(3, 'vmwareGSX'),
(4, 'vmwarefreeserver'),
(5, 'vmwareESX3'),
(6, 'vmwareESXi');

-- =========================================================

-- 
-- Constraints for dumped tables
-- 

-- 
-- Constraints for table `blockComputers`
-- 
ALTER TABLE `blockComputers`
  ADD CONSTRAINT `blockComputers_ibfk_1` FOREIGN KEY (`blockTimeid`) REFERENCES `blockTimes` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `blockComputers_ibfk_2` FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`);

-- 
-- Constraints for table `blockRequest`
-- 
ALTER TABLE `blockRequest`
  ADD CONSTRAINT `blockRequest_ibfk_4` FOREIGN KEY (`imageid`) REFERENCES `image` (`id`),
  ADD CONSTRAINT `blockRequest_ibfk_5` FOREIGN KEY (`groupid`) REFERENCES `usergroup` (`id`),
  ADD CONSTRAINT `blockRequest_ibfk_6` FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`);

-- 
-- Constraints for table `blockTimes`
-- 
ALTER TABLE `blockTimes`
  ADD CONSTRAINT `blockTimes_ibfk_1` FOREIGN KEY (`blockRequestid`) REFERENCES `blockRequest` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `blockWebDate`
-- 
ALTER TABLE `blockWebDate`
  ADD CONSTRAINT `blockWebDate_ibfk_1` FOREIGN KEY (`blockRequestid`) REFERENCES `blockRequest` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `blockWebTime`
-- 
ALTER TABLE `blockWebTime`
  ADD CONSTRAINT `blockWebTime_ibfk_1` FOREIGN KEY (`blockRequestid`) REFERENCES `blockRequest` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `computer`
-- 
ALTER TABLE `computer`
  ADD CONSTRAINT `computer_ibfk_37` FOREIGN KEY (`provisioningid`) REFERENCES `provisioning` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `computer_ibfk_12` FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `computer_ibfk_30` FOREIGN KEY (`scheduleid`) REFERENCES `schedule` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `computer_ibfk_33` FOREIGN KEY (`stateid`) REFERENCES `state` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `computer_ibfk_35` FOREIGN KEY (`platformid`) REFERENCES `platform` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `computer_ibfk_36` FOREIGN KEY (`currentimageid`) REFERENCES `image` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `computerloadlog`
-- 
ALTER TABLE `computerloadlog`
  ADD CONSTRAINT `computerloadlog_ibfk_1` FOREIGN KEY (`reservationid`) REFERENCES `reservation` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `continuations`
-- 
ALTER TABLE `continuations`
  ADD CONSTRAINT `continuations_ibfk_1` FOREIGN KEY (`parentid`) REFERENCES `continuations` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `image`
-- 
ALTER TABLE `image`
  ADD CONSTRAINT `image_ibfk_1` FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `image_ibfk_6` FOREIGN KEY (`platformid`) REFERENCES `platform` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `image_ibfk_7` FOREIGN KEY (`OSid`) REFERENCES `OS` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `imagerevision`
-- 
ALTER TABLE `imagerevision`
  ADD CONSTRAINT `imagerevision_ibfk_1` FOREIGN KEY (`imageid`) REFERENCES `image` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `imagerevision_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `localauth`
-- 
ALTER TABLE `localauth`
  ADD CONSTRAINT `localauth_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `log`
-- 
ALTER TABLE `log`
  ADD CONSTRAINT `log_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `log_ibfk_3` FOREIGN KEY (`imageid`) REFERENCES `image` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `managementnode`
-- 
ALTER TABLE `managementnode`
  ADD CONSTRAINT `managementnode_ibfk_6` FOREIGN KEY (`imagelibgroupid`) REFERENCES `resourcegroup` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `managementnode_ibfk_3` FOREIGN KEY (`predictivemoduleid`) REFERENCES `module` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `managementnode_ibfk_4` FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `managementnode_ibfk_5` FOREIGN KEY (`stateid`) REFERENCES `state` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `OS`
--
ALTER TABLE `OS`
  ADD CONSTRAINT `OS_ibfk_4` FOREIGN KEY (`moduleid`) REFERENCES `module` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `OS_ibfk_2` FOREIGN KEY (`type`) REFERENCES `OStype` (`name`) ON UPDATE CASCADE,
  ADD CONSTRAINT `OS_ibfk_3` FOREIGN KEY (`installtype`) REFERENCES `OSinstalltype` (`name`) ON UPDATE CASCADE;

--
-- Constraints for table `privnode`
-- 
ALTER TABLE `privnode`
  ADD CONSTRAINT `privnode_ibfk_1` FOREIGN KEY (`parent`) REFERENCES `privnode` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `provisioning`
--
ALTER TABLE `provisioning`
  ADD CONSTRAINT `provisioning_ibfk_1` FOREIGN KEY (`moduleid`) REFERENCES `module` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `querylog`
-- 
ALTER TABLE `querylog`
  ADD CONSTRAINT `querylog_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `user` (`id`);

-- 
-- Constraints for table `request`
-- 
ALTER TABLE `request`
  ADD CONSTRAINT `request_ibfk_15` FOREIGN KEY (`stateid`) REFERENCES `state` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `request_ibfk_16` FOREIGN KEY (`laststateid`) REFERENCES `state` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `request_ibfk_2` FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `reservation`
-- 
ALTER TABLE `reservation`
  ADD CONSTRAINT `reservation_ibfk_11` FOREIGN KEY (`requestid`) REFERENCES `request` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `reservation_ibfk_10` FOREIGN KEY (`managementnodeid`) REFERENCES `managementnode` (`id`),
  ADD CONSTRAINT `reservation_ibfk_9` FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `resource`
-- 
ALTER TABLE `resource`
  ADD CONSTRAINT `resource_ibfk_1` FOREIGN KEY (`resourcetypeid`) REFERENCES `resourcetype` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `resourcegroup`
-- 
ALTER TABLE `resourcegroup`
  ADD CONSTRAINT `resourcegroup_ibfk_2` FOREIGN KEY (`ownerusergroupid`) REFERENCES `usergroup` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `resourcegroup_ibfk_3` FOREIGN KEY (`resourcetypeid`) REFERENCES `resourcetype` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `resourcegroupmembers`
-- 
ALTER TABLE `resourcegroupmembers`
  ADD CONSTRAINT `resourcegroupmembers_ibfk_1` FOREIGN KEY (`resourceid`) REFERENCES `resource` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `resourcegroupmembers_ibfk_2` FOREIGN KEY (`resourcegroupid`) REFERENCES `resourcegroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `resourcemap`
-- 
ALTER TABLE `resourcemap`
  ADD CONSTRAINT `resourcemap_ibfk_1` FOREIGN KEY (`resourcegroupid1`) REFERENCES `resourcegroup` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `resourcemap_ibfk_2` FOREIGN KEY (`resourcegroupid2`) REFERENCES `resourcegroup` (`id`) ON DELETE CASCADE;

-- 
-- Constraints for table `resourcepriv`
-- 
ALTER TABLE `resourcepriv`
  ADD CONSTRAINT `resourcepriv_ibfk_1` FOREIGN KEY (`resourcegroupid`) REFERENCES `resourcegroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `resourcepriv_ibfk_2` FOREIGN KEY (`privnodeid`) REFERENCES `privnode` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `schedule`
-- 
ALTER TABLE `schedule`
  ADD CONSTRAINT `schedule_ibfk_1` FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `user`
-- 
ALTER TABLE `user`
  ADD CONSTRAINT `user_ibfk_2` FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`),
  ADD CONSTRAINT `user_ibfk_3` FOREIGN KEY (`IMtypeid`) REFERENCES `IMtype` (`id`) ON UPDATE CASCADE;

-- 
-- Constraints for table `usergroup`
-- 
ALTER TABLE `usergroup`
  ADD CONSTRAINT `usergroup_ibfk_1` FOREIGN KEY (`ownerid`) REFERENCES `user` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `usergroup_ibfk_2` FOREIGN KEY (`editusergroupid`) REFERENCES `usergroup` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- 
-- Constraints for table `usergroupmembers`
-- 
ALTER TABLE `usergroupmembers`
  ADD CONSTRAINT `usergroupmembers_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `usergroupmembers_ibfk_2` FOREIGN KEY (`usergroupid`) REFERENCES `usergroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- 
-- Constraints for table `userpriv`
-- 
ALTER TABLE `userpriv`
  ADD CONSTRAINT `userpriv_ibfk_1` FOREIGN KEY (`userid`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `userpriv_ibfk_2` FOREIGN KEY (`usergroupid`) REFERENCES `usergroup` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `userpriv_ibfk_3` FOREIGN KEY (`privnodeid`) REFERENCES `privnode` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `userpriv_ibfk_4` FOREIGN KEY (`userprivtypeid`) REFERENCES `userprivtype` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `vmhost`
--
ALTER TABLE `vmhost`
  ADD CONSTRAINT `vmhost_ibfk_1` FOREIGN KEY (`computerid`) REFERENCES `computer` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `vmprofile`
--
ALTER TABLE `vmprofile`
  ADD CONSTRAINT `vmprofile_ibfk_2` FOREIGN KEY (`vmtypeid`) REFERENCES `vmtype` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `vmprofile_ibfk_1` FOREIGN KEY (`imageid`) REFERENCES `image` (`id`) ON UPDATE CASCADE;
