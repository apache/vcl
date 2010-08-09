 -- 2.1 to 2.2 schema changes
 --  Computer table
ALTER TABLE `computer` DROP `preferredimageid` ;

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
-- Table structure change for table `managementnode`
-- 

ALTER TABLE `managementnode` ADD `publicIPconfiguration` enum('dynamicDHCP','manualDHCP','static') NOT NULL default 'dynamicDHCP';
ALTER TABLE `managementnode` ADD `publicSubnetMask` varchar(56) default NULL;
ALTER TABLE `managementnode` ADD `publicDefaultGateway` varchar(56) default NULL;
ALTER TABLE `managementnode` ADD `publicDNSserver` varchar(56) default NULL;
ALTER TABLE `managementnode` ADD `sysadminEmailAddress` varchar(128) default NULL;
ALTER TABLE `managementnode` ADD `sharedMailBox` varchar(128) default NULL;
ALTER TABLE `managementnode` ADD `NOT_STANDALONE` varchar(128) default NULL;

 -- --------------------------------------------------------

-- 
-- Table structure change for table `request`
-- 

ALTER TABLE `request` ADD `checkuser` tinyint(1) unsigned NOT NULL default '1';

 -- --------------------------------------------------------

-- 
-- Table structure change for table `vmprofile`
-- 

ALTER TABLE `vmprofile` ADD `virtualswitch2` varchar(80) NULL default NULL;
ALTER TABLE `vmprofile` ADD `virtualswitch3` varchar(80) NULL default NULL;
ALTER TABLE `vmprofile` ADD `vmware_mac_eth0_generated` tinyint(1) NOT NULL default '0';
ALTER TABLE `vmprofile` ADD `vmware_mac_eth1_generated` tinyint(1) NOT NULL default '0';

 -- --------------------------------------------------------

-- 
-- Inserts for table `module`
-- 

INSERT INTO `module` (`id`, `name`, `prettyname`, `description`, `perlpackage`) VALUES
(17, 'os_win7', 'Windows 7 OS Module', '', 'VCL::Module::OS::Windows::Version_7::7'),
(20, 'provisioning_xCAT_2x', 'xCAT 2x provisioning module', '', 'VCL::Module::Provisioning::xCAT2');

 -- --------------------------------------------------------

-- 
-- Inserts for table `affiliation`
-- 

INSERT INTO `affiliation` (`id`, `name`, `dataUpdateText`) VALUES (2, 'Global', '');

 -- --------------------------------------------------------

-- 
-- Update change for table `image`
-- 

UPDATE `image` SET `name` = 'vmwarewinxp-base7-v0' WHERE `image`.`id` =7 LIMIT 1 ;

 -- --------------------------------------------------------

--
-- Inserts for table `provisioning`
--

INSERT INTO `provisioning` (`id`, `name`, `prettyname`, `moduleid`) VALUES
(7, 'xCAT_2x', 'xCAT 2.x', 20);

 -- --------------------------------------------------------

-- 
-- Inserts for table `OS`
-- 

INSERT INTO `OS` (`id`, `name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES
(34, 'win7', 'Windows 7', 'windows', 'partimage', 'image', 17),
(35, 'vmwarewin7', 'VMware Windows 7', 'windows', 'vmware', 'vmware_images', 17),
(36, 'vmwarelinux', 'VMware Generic Linux', 'linux', 'vmware', 'vmware_images', 5);

 -- --------------------------------------------------------

--
-- Constraints for table `winKMS`
--
ALTER TABLE `winKMS` ADD CONSTRAINT `winKMS_ibfk_1` FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;
 
 -- --------------------------------------------------------
--
-- Constraints for table `winProductKey`
--
ALTER TABLE `winProductKey` ADD CONSTRAINT `winProductKey_ibfk_1` FOREIGN KEY (`affiliationid`) REFERENCES `affiliation` (`id`) ON UPDATE CASCADE;
