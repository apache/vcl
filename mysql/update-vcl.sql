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

-- Apache VCL version 2.1 to 2.2.1 database schema changes

-- --------------------------------------------------------

DELIMITER $$

-- --------------------------------------------------------

/*
Procedure   : AddOrRenameColumn
Parameters  : tableName, oldColumnName, newColumnName, columnDefinition
Description : If oldColumnName already exists in the table, it is renamed to
              newColumnName and its definition is updated. If it doesn't exist,
              a new column is added.
*/

DROP PROCEDURE IF EXISTS `AddOrRenameColumn`$$
CREATE PROCEDURE `AddOrRenameColumn`(
  IN tableName tinytext,
  IN oldColumnName tinytext,
  IN newColumnName tinytext,
  IN columnDefinition text
)
BEGIN
  IF EXISTS (
    SELECT * FROM information_schema.COLUMNS WHERE
    TABLE_SCHEMA=Database()
    AND TABLE_NAME=tableName
    AND COLUMN_NAME=oldColumnName
  )
  THEN
    SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' CHANGE ', oldColumnName , ' ', newColumnName, ' ', columnDefinition);
  ELSEIF EXISTS (
    SELECT * FROM information_schema.COLUMNS WHERE
    TABLE_SCHEMA=Database()
    AND TABLE_NAME=tableName
    AND COLUMN_NAME=newColumnName
  )
  THEN
    SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' CHANGE ', newColumnName , ' ', newColumnName, ' ', columnDefinition);
  ELSE
    SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD COLUMN ', newColumnName, ' ', columnDefinition);
  END IF;
  
  PREPARE statement_string FROM @statement_array;
  EXECUTE statement_string;
END$$

-- --------------------------------------------------------

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
    SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD COLUMN ', columnName, ' ', columnDefinition);
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
    CALL DropExistingConstraints(tableName, columnName);
    CALL DropExistingIndices(tableName, columnName);
  
    SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' DROP COLUMN ', columnName);
    PREPARE statement_string FROM @statement_array;
    EXECUTE statement_string;
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : DropExistingConstraints
Parameters  : tableName, columnName
Description : Drops all constraints set for an existing column.
*/

DROP PROCEDURE IF EXISTS `DropExistingConstraints`$$
CREATE PROCEDURE `DropExistingConstraints`(
  IN tableName tinytext,
  IN columnName tinytext
)
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE existing_constraint_name CHAR(16);
  DECLARE database_name CHAR(16);

  DECLARE select_existing_constraint_names CURSOR FOR
    SELECT CONSTRAINT_NAME, TABLE_SCHEMA FROM information_schema.KEY_COLUMN_USAGE WHERE
    TABLE_SCHEMA = Database()
    AND TABLE_NAME = tableName
    AND COLUMN_NAME = columnName;
  
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
  OPEN select_existing_constraint_names;

  REPEAT
    FETCH select_existing_constraint_names INTO existing_constraint_name, database_name;
    -- SELECT existing_constraint_name, database_name;
    IF NOT done THEN
      SET @drop_existing_constraint = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' DROP FOREIGN KEY ', existing_constraint_name);
      PREPARE drop_existing_constraint FROM @drop_existing_constraint;
      EXECUTE drop_existing_constraint;
    END IF;
  UNTIL done END REPEAT;

  CLOSE select_existing_constraint_names;
END$$

-- --------------------------------------------------------

/*
Procedure   : DropExistingIndices
Parameters  : tableName, columnName
Description : Drops all indices set for an existing column.
*/

DROP PROCEDURE IF EXISTS `DropExistingIndices`$$
CREATE PROCEDURE `DropExistingIndices`(
  IN tableName tinytext,
  IN columnName tinytext
)
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE existing_index_name CHAR(16);
  DECLARE database_name CHAR(16);
  
  DECLARE select_existing_index_names CURSOR FOR
    SELECT INDEX_NAME, TABLE_SCHEMA FROM information_schema.STATISTICS WHERE
    TABLE_SCHEMA = Database()
    AND TABLE_NAME = tableName
    AND COLUMN_NAME = columnName;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
  OPEN select_existing_index_names;

  REPEAT
    FETCH select_existing_index_names INTO existing_index_name, database_name;
    -- SELECT existing_index_name, database_name;
    IF NOT done THEN
      SET @drop_existing_index = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' DROP INDEX ', existing_index_name);
      PREPARE drop_existing_index FROM @drop_existing_index;
      EXECUTE drop_existing_index;
    END IF;
  UNTIL done END REPEAT;

  CLOSE select_existing_index_names;
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
    SELECT * FROM information_schema.STATISTICS WHERE
    TABLE_SCHEMA=Database()
    AND TABLE_NAME=tableName
    AND COLUMN_NAME=columnName
  )
  THEN
    SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD INDEX (', columnName, ')');
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
      SET @drop_nonunique_index = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' DROP INDEX ', nonunique_index_name);
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
    SET @add_unique_index = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD UNIQUE (', columnName, ')');
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
  IN referencedColumnName tinytext,
  IN constraintType tinytext,
  IN constraintAction tinytext
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
    IF constraintType = 'update' THEN
      SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD FOREIGN KEY (', columnName, ') REFERENCES `', Database(), '`.', referencedTableName, ' (', referencedColumnName, ') ON UPDATE ', constraintAction);
    ELSEIF constraintType = 'delete' THEN
      SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD FOREIGN KEY (', columnName, ') REFERENCES `', Database(), '`.', referencedTableName, ' (', referencedColumnName, ') ON DELETE ', constraintAction);
    ELSEIF constraintType = 'both' THEN
      SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD FOREIGN KEY (', columnName, ') REFERENCES `', Database(), '`.', referencedTableName, ' (', referencedColumnName, ') ON DELETE ', constraintAction, ' ON UPDATE ', constraintAction);
    ELSE
      SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD FOREIGN KEY (', columnName, ') REFERENCES `', Database(), '`.', referencedTableName, ' (', referencedColumnName, ')');
    END IF;
    PREPARE statement_string FROM @statement_array;
    EXECUTE statement_string;
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : AddConnectMethodMapIfNotExists
Parameters  : myconnectmethod, myOStype, myOS, myimagerevisionid, mydisabled, myautoprovisioned
Description : Adds an entry to the connectmethodmap table if it does not already exist
              For myOStype, myOS, and myimagerevisionid set to 0 if NULL should be inserted
              For myautoprovisioned set to 2 if NULL should be inserted
*/

DROP PROCEDURE IF EXISTS `AddConnectMethodMapIfNotExists`$$
CREATE PROCEDURE `AddConnectMethodMapIfNotExists`(
  IN myconnectmethod tinytext,
  IN myOStype tinytext,
  IN myOS tinytext,
  IN myimagerevisionid mediumint unsigned,
  IN mydisabled tinyint unsigned,
  IN myautoprovisioned tinyint unsigned
)
BEGIN
  DECLARE query mediumtext;
  DECLARE insrt mediumtext;

  SET @connectmethodid = 0;

  SELECT id INTO @connectmethodid FROM connectmethod WHERE name = myconnectmethod;

  SET insrt = CONCAT('INSERT INTO connectmethodmap (connectmethodid, OStypeid, OSid, imagerevisionid, disabled, autoprovisioned) VALUES (', @connectmethodid);

  SET @cnt = 0;

  SET query = CONCAT('SELECT COUNT(*) INTO @cnt FROM connectmethodmap WHERE connectmethodid = ', @connectmethodid);
  IF NOT STRCMP(myOStype, 0) THEN
    SET query = CONCAT(query, ' AND OStypeid IS NULL');
    SET insrt = CONCAT(insrt, ',NULL');
  ELSE
    SET @OStypeid = 0;
    SELECT id INTO @OStypeid FROM OStype WHERE name = myOStype;
    SET query = CONCAT(query, ' AND OStypeid = ', @OStypeid);
    SET insrt = CONCAT(insrt, ',', @OStypeid);
  END IF;
  IF NOT STRCMP(myOS, 0) THEN
    SET query = CONCAT(query, ' AND OSid IS NULL');
    SET insrt = CONCAT(insrt, ',NULL');
  ELSE
    SET @OSid = 0;
    SELECT id INTO @OSid FROM OS WHERE name = myOS;
    SET query = CONCAT(query, ' AND OSid = ', @OSid);
    SET insrt = CONCAT(insrt, ',', @OSid);
  END IF;
  IF myimagerevisionid = 0 THEN
    SET query = CONCAT(query, ' AND imagerevisionid IS NULL');
    SET insrt = CONCAT(insrt, ',NULL');
  ELSE
    SET query = CONCAT(query, ' AND imagerevisionid = ', myimagerevisionid);
    SET insrt = CONCAT(insrt, ',', myimagerevisionid);
  END IF;
  SET insrt = CONCAT(insrt, ',', mydisabled);
  IF myautoprovisioned = 2 THEN
    SET query = CONCAT(query, ' AND autoprovisioned IS NULL');
    SET insrt = CONCAT(insrt, ',NULL');
  ELSE
    SET query = CONCAT(query, ' AND autoprovisioned = ', myautoprovisioned);
    SET insrt = CONCAT(insrt, ',', myautoprovisioned);
  END IF;
  SET @query = query;
  PREPARE query_string FROM @query;
  EXECUTE query_string;

  SET insrt = CONCAT(insrt, ')');

  IF @cnt = 0 THEN
    SET @insrt = insrt;
    PREPARE statement_string FROM @insrt;
    EXECUTE statement_string;
  END IF;

END$$

-- --------------------------------------------------------

/*
Procedure   : AlterVMDiskValues
Description : Changes vmprofile.vmdisk enum values from
              localdisk,networkdisk to dedicated,shared
*/

DROP PROCEDURE IF EXISTS `AlterVMDiskValues`$$
CREATE PROCEDURE `AlterVMDiskValues`()
BEGIN
  DECLARE data TEXT;
  SET data = (SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE
              TABLE_SCHEMA = Database()
              AND TABLE_NAME = 'vmprofile'
              AND COLUMN_NAME = 'vmdisk');
  SET data = SUBSTRING_INDEX(data, "enum(", -1);
  SET data = SUBSTRING_INDEX(data, ")", 1);
  IF NOT STRCMP(data, "'localdisk','networkdisk'") THEN
    ALTER TABLE vmprofile
    CHANGE vmdisk
    vmdisk ENUM('localdisk','networkdisk','dedicated','shared') NOT NULL DEFAULT 'dedicated';

    UPDATE vmprofile
    SET vmdisk = 'dedicated'
    WHERE vmdisk = 'localdisk';

    UPDATE vmprofile
    SET vmdisk = 'shared'
    WHERE vmdisk = 'networkdisk';

    ALTER TABLE vmprofile
    CHANGE vmdisk
    vmdisk ENUM('dedicated','shared') NOT NULL DEFAULT 'dedicated';
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : AddManageMapping
Description : adds the manageMapping resource attribute
              and assigns it everywhere manageGroup is
              assigned
*/

DROP PROCEDURE IF EXISTS `AddManageMapping`$$
CREATE PROCEDURE `AddManageMapping`()
BEGIN
  DECLARE data TEXT;
  SET data = (SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE
              TABLE_SCHEMA = Database()
              AND TABLE_NAME = 'resourcepriv'
              AND COLUMN_NAME = 'type');
  IF NOT LOCATE('manageMapping', data) THEN
    /* add manageMapping attribute */
    ALTER TABLE resourcepriv
    CHANGE `type`
    `type` ENUM('block','cascade','available','administer','manageGroup','manageMapping') NOT NULL default 'block';

    /* grant manageMapping everywhere manageGroup is currently granted */
    INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, type)
    SELECT resourcegroupid, privnodeid, 'manageMapping'
    FROM resourcepriv WHERE `type` = 'manageGroup';
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : Add2ColUniqueIndexIfNotExist
Parameters  : tableName, columnName1, columnName2
Description : Adds a unique index to an existing table if a primary or unique
              index does not already exist for the column. Any non-unique
              indices are dropped before the unique index is added.
*/

DROP PROCEDURE IF EXISTS `Add2ColUniqueIndexIfNotExist`$$
CREATE PROCEDURE `Add2ColUniqueIndexIfNotExist`(
  IN tableName tinytext,
  IN columnName1 tinytext,
  IN columnName2 tinytext
)
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE nonunique_index_name CHAR(16);
  
  DECLARE select_index_names CURSOR FOR
    SELECT i1.INDEX_NAME FROM information_schema.STATISTICS i1
    LEFT JOIN
    (
    	SELECT INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME
    	FROM information_schema.STATISTICS
    	WHERE TABLE_SCHEMA = Database()
    	  AND TABLE_NAME = tableName
    	  AND SEQ_IN_INDEX = 2
    )
    i2 ON (i1.INDEX_NAME = i2.INDEX_NAME AND i1.SEQ_IN_INDEX = 1 AND i2.SEQ_IN_INDEX = 2)
    WHERE i1.TABLE_SCHEMA = Database()
      AND i1.TABLE_NAME = tableName
      AND i1.SEQ_IN_INDEX = 1
      AND i1.COLUMN_NAME = columnName1
      AND i2.COLUMN_NAME IS NULL;
  
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN select_index_names;
  
  REPEAT
    FETCH select_index_names INTO nonunique_index_name;
    IF NOT done THEN
      SET @drop_nonunique_index = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' DROP INDEX ', nonunique_index_name);
      PREPARE drop_nonunique_index FROM @drop_nonunique_index;
      EXECUTE drop_nonunique_index;
    END IF;
  UNTIL done END REPEAT;
  
  CLOSE select_index_names;
  
  IF NOT EXISTS (
    SELECT i1.INDEX_NAME
    FROM information_schema.STATISTICS i1, information_schema.STATISTICS i2
    WHERE i1.TABLE_SCHEMA = Database()
    AND i1.TABLE_NAME = tableName
    AND i2.TABLE_SCHEMA = Database()
    AND i2.TABLE_NAME = tableName
    AND i1.INDEX_NAME = i2.INDEX_NAME
    AND i1.COLUMN_NAME != i2.COLUMN_NAME
    AND i1.COLUMN_NAME = columnName1
  )
  THEN
    SET @add_unique_index = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD UNIQUE (', columnName1, ',', columnName2, ')');
    PREPARE add_unique_index FROM @add_unique_index;
    EXECUTE add_unique_index;
  END IF;
END$$

/* ============= End of Stored Procedures ===============*/

-- --------------------------------------------------------

--
--  Table structure for table `affiliation`
--

CALL AddUniqueIndex('affiliation', 'name');
CALL AddColumnIfNotExists('affiliation', 'theme', "varchar(50) NOT NULL default 'default'");

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
CALL AddColumnIfNotExists('blockRequest', 'comments', "text");

-- --------------------------------------------------------

--
--  Table structure for table `blockTimes`
--

CALL AddColumnIfNotExists('blockTimes', 'skip', "tinyint(1) unsigned NOT NULL default '0'");

-- --------------------------------------------------------

--
--  Table structure for table `changelog`
--

CALL AddColumnIfNotExists('changelog', 'other', "varchar(255) default NULL");

-- --------------------------------------------------------

-- 
--  Table structure for table `computer`
--

CALL AddColumnIfNotExists('computer', 'datedeleted', "DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00' AFTER `deleted`");

CALL DropColumnIfExists('computer', 'preferredimageid');
CALL AddIndexIfNotExists('computer', 'imagerevisionid');
CALL Add2ColUniqueIndexIfNotExist('computer', 'hostname', 'datedeleted');
CALL Add2ColUniqueIndexIfNotExist('computer', 'eth0macaddress', 'datedeleted');
CALL Add2ColUniqueIndexIfNotExist('computer', 'eth1macaddress', 'datedeleted');

-- Set the default values for the currentimage and next image columns to 'noimage'
SET @currentimageid_noimage = CONCAT('ALTER TABLE computer CHANGE currentimageid currentimageid SMALLINT(5) UNSIGNED NOT NULL DEFAULT ', (SELECT id FROM image WHERE name LIKE 'noimage'));
PREPARE currentimageid_noimage FROM @currentimageid_noimage;
EXECUTE currentimageid_noimage;

SET @nextimageid_noimage = CONCAT('ALTER TABLE computer CHANGE nextimageid nextimageid SMALLINT(5) UNSIGNED NOT NULL DEFAULT ', (SELECT id FROM image WHERE name LIKE 'noimage'));
PREPARE nextimageid_noimage FROM @nextimageid_noimage;
EXECUTE nextimageid_noimage;

-- change RAM to mediumint
ALTER TABLE `computer` CHANGE `RAM` `RAM` MEDIUMINT UNSIGNED NOT NULL DEFAULT '0';
ALTER TABLE `computer` CHANGE `location` `location` VARCHAR(255) NULL DEFAULT NULL;

-- set datedeleted for deleted computers
UPDATE computer SET datedeleted = NOW() WHERE deleted = 1 AND datedeleted = '0000-00-00 00:00:00';

-- --------------------------------------------------------

--
-- Table structure for table `connectmethod`
--

CREATE TABLE IF NOT EXISTS `connectmethod` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `name` varchar(80) NOT NULL,
  `description` varchar(255) NOT NULL,
  `protocol` varchar(32) NOT NULL,
  `port` smallint(5) unsigned NOT NULL,
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
--  Table structure for table `image`
--

-- change minram to mediumint
ALTER TABLE `image` CHANGE `minram` `minram` MEDIUMINT UNSIGNED NOT NULL DEFAULT '0';
CALL AddColumnIfNotExists('image', 'imagetypeid', "smallint(5) unsigned NOT NULL default '1' AFTER ownerid");
CALL AddIndexIfNotExists('image', 'imagetypeid');

-- --------------------------------------------------------

-- 
--  Table structure for table `imagerevision`
--

CALL AddColumnIfNotExists('imagerevision', 'autocaptured', "tinyint(1) unsigned NOT NULL default '0'");

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
  KEY `affiliationid` (`affiliationid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CALL AddColumnIfNotExists('loginlog', 'code', "enum('none','invalid credentials') NOT NULL DEFAULT 'none'");

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
-- Create table `provisioningOSinstalltype`
-- 

CREATE TABLE IF NOT EXISTS `provisioningOSinstalltype` (
  `provisioningid` smallint(5) unsigned NOT NULL,
  `OSinstalltypeid` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY  (`provisioningid`,`OSinstalltypeid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure change for table `reservation`
--

CALL AddColumnIfNotExists('reservation', 'connectIP', "varchar(15) default NULL");
CALL AddColumnIfNotExists('reservation', 'connectport', "smallint(5) unsigned default NULL");

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
-- Table structure for table `resourcepriv`
--
CALL AddManageMapping();

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
-- Table structure for table `statgraphcache`
--

CREATE TABLE IF NOT EXISTS `statgraphcache` (
  `graphtype` enum('totalres','concurres','concurblade','concurvm') NOT NULL,
  `statdate` date NOT NULL,
  `affiliationid` mediumint(8) unsigned NOT NULL,
  `value` mediumint(8) unsigned NOT NULL,
  `provisioningid` smallint(5) unsigned NOT NULL,
  KEY `graphtype` (`graphtype`),
  KEY `statdate` (`statdate`),
  KEY `affiliationid` (`affiliationid`),
  KEY `provisioningid` (`provisioningid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CALL AddColumnIfNotExists('statgraphcache', 'provisioningid', "smallint(5) unsigned default NULL");
CALL AddIndexIfNotExists('statgraphcache', 'provisioningid');

-- --------------------------------------------------------

--
-- Table structure change for table `sublog`
--

CALL AddColumnIfNotExists('sublog', 'hostcomputerid', "smallint(5) unsigned default NULL");
CALL AddColumnIfNotExists('sublog', 'blockRequestid', "mediumint(8) unsigned NOT NULL");
CALL AddColumnIfNotExists('sublog', 'blockStart', "datetime NOT NULL");
CALL AddColumnIfNotExists('sublog', 'blockEnd', "datetime NOT NULL");

-- --------------------------------------------------------

-- 
-- Table structure change for table `request`
-- 

CALL AddColumnIfNotExists('request', 'checkuser', "tinyint(1) unsigned NOT NULL default '1'");

-- --------------------------------------------------------

--
-- Table structure change for table `user`
--

-- --------------------------------------------------------

CALL AddColumnIfNotExists('user', 'validated', "tinyint(1) unsigned NOT NULL default '1'");

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
-- Table structure change for table `vmhost`
-- 

ALTER TABLE `vmhost` CHANGE `vmprofileid` `vmprofileid` SMALLINT(5) UNSIGNED NOT NULL DEFAULT '1';
CALL AddIndexIfNotExists('vmhost', 'vmprofileid');

-- --------------------------------------------------------

-- 
-- Table structure change for table `vmprofile`
-- 

CALL DropColumnIfExists('vmprofile', 'nasshare');
CALL DropColumnIfExists('vmprofile', 'vmtypeid');
CALL DropColumnIfExists('vmprofile', 'virtualdiskpath');

CALL AddColumnIfNotExists('vmprofile', 'resourcepath', "varchar(256) default NULL AFTER imageid");
CALL AddColumnIfNotExists('vmprofile', 'repositorypath', "varchar(128) default NULL AFTER resourcepath");
CALL AddColumnIfNotExists('vmprofile', 'repositoryimagetypeid', "smallint(5) unsigned NOT NULL default '1' AFTER repositorypath");
CALL AddColumnIfNotExists('vmprofile', 'datastoreimagetypeid', "smallint(5) unsigned NOT NULL default '1' AFTER datastorepath");
CALL AddColumnIfNotExists('vmprofile', 'virtualswitch2', "varchar(80) NULL default NULL AFTER `virtualswitch1`");
CALL AddColumnIfNotExists('vmprofile', 'virtualswitch3', "varchar(80) NULL default NULL AFTER `virtualswitch2`");

CALL AddOrRenameColumn('vmprofile', 'vmware_mac_eth0_generated', 'eth0generated', "tinyint(1) unsigned NOT NULL default '0'");
CALL AddOrRenameColumn('vmprofile', 'vmware_mac_eth1_generated', 'eth1generated', "tinyint(1) unsigned NOT NULL default '0'");

CALL AlterVMDiskValues();

CALL AddUniqueIndex('vmprofile', 'profilename');
CALL AddIndexIfNotExists('vmprofile', 'repositoryimagetypeid');
CALL AddIndexIfNotExists('vmprofile', 'datastoreimagetypeid');

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
-- Inserts for table `computer`
-- 

UPDATE `computer` SET `currentimageid` = (SELECT `id` FROM `image` WHERE `name` = 'noimage') WHERE NOT EXISTS (SELECT * FROM `image` WHERE `image`.`id` = `computer`.`currentimageid`);
UPDATE `computer` SET `nextimageid` = (SELECT `id` FROM `image` WHERE `name` = 'noimage') WHERE NOT EXISTS (SELECT * FROM `image` WHERE `image`.`id` = `computer`.`nextimageid`);
UPDATE `computer` SET `imagerevisionid` = (SELECT `id` FROM `imagerevision` WHERE `imagename` = 'noimage') WHERE NOT EXISTS (SELECT * FROM `imagerevision` WHERE `imagerevision`.`id` = `computer`.`imagerevisionid`);

-- --------------------------------------------------------

-- 
-- Inserts for table `imagetype`
-- 

INSERT IGNORE INTO `imagetype` (`name`) VALUES ('none');
INSERT IGNORE INTO `imagetype` (`name`) VALUES ('partimage');
INSERT IGNORE INTO `imagetype` (`name`) VALUES ('partimage-ng');
INSERT IGNORE INTO `imagetype` (`name`) VALUES ('lab');
INSERT IGNORE INTO `imagetype` (`name`) VALUES ('kickstart');
INSERT IGNORE INTO `imagetype` (`name`) VALUES ('vmdk');
INSERT IGNORE INTO `imagetype` (`name`) VALUES ('qcow2');
INSERT IGNORE INTO `imagetype` (`name`) VALUES ('vdi');

-- --------------------------------------------------------

-- 
-- Inserts for table `image`
-- 

UPDATE image SET image.imagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'none') WHERE image.name = 'noimage';
UPDATE image, OS SET image.imagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'vmdk') WHERE image.imagetypeid = 0 AND image.OSid = OS.id AND OS.installtype LIKE '%vmware%';
UPDATE image, OS SET image.imagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'partimage') WHERE image.imagetypeid = 0 AND image.OSid = OS.id AND OS.installtype LIKE '%partimage%';
UPDATE image, OS SET image.imagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'kickstart') WHERE image.imagetypeid = 0 AND image.OSid = OS.id AND OS.installtype LIKE '%kickstart%';
UPDATE image, OS SET image.imagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'vdi') WHERE image.imagetypeid = 0 AND image.OSid = OS.id AND OS.installtype LIKE '%vbox%';
UPDATE image, OS, module SET image.imagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'lab') WHERE image.imagetypeid = 0 AND image.OSid = OS.id AND OS.moduleid = module.id AND module.perlpackage LIKE '%lab%';
UPDATE image, OS, module SET image.imagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'vmdk') WHERE image.imagetypeid = 0 AND image.OSid = OS.id AND OS.moduleid = module.id AND module.perlpackage REGEXP 'vmware|esx';
UPDATE image SET image.imagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'none') WHERE image.imagetypeid = 0;

-- --------------------------------------------------------

-- 
-- Inserts for table `module`
-- 

UPDATE IGNORE `module` SET `name` = 'provisioning_vmware_1x', `prettyname` = 'VMware Server 1.x Provisioning Module' WHERE `name` = 'provisioning_vmware_gsx';
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_win7', 'Windows 7 OS Module', '', 'VCL::Module::OS::Windows::Version_6::7');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_xcat_2x', 'xCAT 2.x Provisioning Module', '', 'VCL::Module::Provisioning::xCAT2');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_vmware', 'VMware Provisioning Module', '', 'VCL::Module::Provisioning::VMware::VMware');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('state_image', 'VCL Image State Module', '', 'VCL::image');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('base_module', 'VCL Base Module', '', 'VCL::Module');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_vbox', 'Virtual Box Provisioning Module', '', 'VCL::Module::Provisioning::vbox');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_esxi', 'VMware ESXi OS Module', '', 'VCL::Module::OS::Linux::ESXi');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_osx', 'OSX OS Module', '', 'VCL::Module::OS::OSX');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_libvirt', 'Libvirt Provisioning Module', '', 'VCL::Module::Provisioning::libvirt');

-- --------------------------------------------------------

--
-- Inserts for table `OStype`
--

INSERT IGNORE INTO `OStype` (`name`) VALUES ('osx');

-- --------------------------------------------------------

-- 
-- Inserts for table `OS`
-- 

INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('win7', 'Windows 7 (Bare Metal)', 'windows', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win7'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarewin7', 'Windows 7 (VMware)', 'windows', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win7'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarelinux', 'Generic Linux (VMware)', 'linux', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarewin2003', 'Windows 2003 Server (VMware)', 'windows', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win2003'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('esxi4.1', 'VMware ESXi 4.1 (Kickstart)', 'linux', 'kickstart', 'esxi4.1', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_esxi'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwareosx', 'OSX Snow Leopard (VMware)', 'osx', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_osx'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('rhel6', 'Red Hat Enterprise 6 (Kickstart)', 'linux', 'kickstart', 'rhel6', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('rh6image', 'Red Hat Enterprise 6 (Bare Metal)', 'linux', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('fedora16', 'Fedora 16 (Kickstart)', 'linux', 'kickstart', 'fedora16', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('fedoraimage', 'Fedora 16 (Bare Metal)', 'linux', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwareubuntu', 'Ubuntu (VMware)', 'linux', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux_ubuntu'));

-- --------------------------------------------------------

--
-- Inserts for table `OSinstalltype`
--

INSERT IGNORE INTO `OSinstalltype` (`name`) VALUES ('vbox');

-- --------------------------------------------------------

--
-- Inserts for table `provisioning`
--

INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('xcat_2x', 'xCAT 2.x', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_xcat_2x'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('vmware', 'VMware', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_vmware'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('vbox', 'Virtual Box', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_vbox'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('libvirt','Libvirt Virtualization API', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_libvirt'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('none','None', (SELECT `id` FROM `module` WHERE `name` = 'base_module'));

-- --------------------------------------------------------

-- 
-- Inserts for table `provisioningOSinstalltype`
--

INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%xcat%' AND OSinstalltype.name = 'partimage';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%xcat%' AND OSinstalltype.name = 'kickstart';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%vmware%' AND OSinstalltype.name = 'vmware';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%esx%' AND OSinstalltype.name = 'vmware';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%vbox%' AND OSinstalltype.name = 'vbox';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%lab%' AND OSinstalltype.name = 'none';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%libvirt%' AND OSinstalltype.name = 'vmware';

-- --------------------------------------------------------

--
-- Inserts for table `connectmethod`
--

INSERT IGNORE INTO `connectmethod` (`name`, `description`, `port`, `connecttext`, `servicename`, `startupscript`) VALUES
('ssh', 'ssh on port 22', 22, 'You will need to have an X server running on your local computer and use an ssh client to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<strong><big>NOTE:</big> You cannot use the Windows Remote Desktop Connection to connect to this computer. You must use an ssh client.</strong>', 'ext_sshd', '/etc/init.d/ext_sshd');
INSERT IGNORE INTO `connectmethod` (`name`, `description`, `port`, `connecttext`, `servicename`, `startupscript`) VALUES
('RDP', 'Remote Desktop', 3389, 'You will need to use a Remote Desktop program to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\n\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<br>\r\nFor automatic connection, you can download an RDP file that can be opened by the Remote Desktop Connection program.<br><br>\r\n', 'TermService', NULL);
INSERT IGNORE INTO `connectmethod` (`name`, `description`, `port`, `connecttext`, `servicename`, `startupscript`) VALUES
('iRAPP RDP', 'Remote Desktop for OS X', 3389, 'You will need to use a Remote Desktop program to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\n\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<br>\r\nFor automatic connection, you can download an RDP file that can be opened by the Remote Desktop Connection program.<br><br>\r\n', NULL, NULL);

-- --------------------------------------------------------

--
-- Inserts for table `connectmethodmap`
--

CALL AddConnectMethodMapIfNotExists('ssh', 'linux', 0, 0, 0, 1);
CALL AddConnectMethodMapIfNotExists('ssh', 'unix', 0, 0, 0, 1);
CALL AddConnectMethodMapIfNotExists('RDP', 'windows', 0, 0, 0, 1);
CALL AddConnectMethodMapIfNotExists('iRAPP RDP', 'osx', 0, 0, 0, 1);
CALL AddConnectMethodMapIfNotExists('ssh', 'linux', 0, 0, 0, 2);
CALL AddConnectMethodMapIfNotExists('ssh', 'unix', 0, 0, 0, 2);
CALL AddConnectMethodMapIfNotExists('RDP', 'windows', 0, 0, 0, 2);
CALL AddConnectMethodMapIfNotExists('iRAPP RDP', 'osx', 0, 0, 0, 2);

-- --------------------------------------------------------

-- 
-- Inserts for table `resourcetype`
--

INSERT IGNORE INTO resourcetype (id, name) VALUES (17, 'serverprofile');

-- --------------------------------------------------------

-- 
-- Inserts for table `resourcegroup`
--

INSERT IGNORE INTO resourcegroup (name, ownerusergroupid, resourcetypeid) VALUES ('all profiles', 3, 17);

-- --------------------------------------------------------

-- 
-- Inserts for table `resourcepriv`
--

INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'available' FROM resourcegroup, privnode WHERE resourcegroup.name = 'all profiles' AND resourcegroup.resourcetypeid = 17 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'administer' FROM resourcegroup, privnode WHERE resourcegroup.name = 'all profiles' AND resourcegroup.resourcetypeid = 17 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'manageGroup' FROM resourcegroup, privnode WHERE resourcegroup.name = 'all profiles' AND resourcegroup.resourcetypeid = 17 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'manageMapping' FROM resourcegroup, privnode WHERE resourcegroup.name = 'all profiles' AND resourcegroup.resourcetypeid = 17 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'available' FROM resourcegroup, privnode WHERE resourcegroup.name = 'All VM Computers' AND resourcegroup.resourcetypeid = 12 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'administer' FROM resourcegroup, privnode WHERE resourcegroup.name = 'All VM Computers' AND resourcegroup.resourcetypeid = 12 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'manageGroup' FROM resourcegroup, privnode WHERE resourcegroup.name = 'All VM Computers' AND resourcegroup.resourcetypeid = 12 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'manageMapping' FROM resourcegroup, privnode WHERE resourcegroup.name = 'All VM Computers' AND resourcegroup.resourcetypeid = 12 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'available' FROM resourcegroup, privnode WHERE resourcegroup.name = 'allVMimages' AND resourcegroup.resourcetypeid = 13 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'administer' FROM resourcegroup, privnode WHERE resourcegroup.name = 'allVMimages' AND resourcegroup.resourcetypeid = 13 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'manageGroup' FROM resourcegroup, privnode WHERE resourcegroup.name = 'allVMimages' AND resourcegroup.resourcetypeid = 13 AND privnode.name = 'admin' AND privnode.parent = 3;
INSERT IGNORE INTO resourcepriv (resourcegroupid, privnodeid, `type`) SELECT resourcegroup.id, privnode.id, 'manageMapping' FROM resourcegroup, privnode WHERE resourcegroup.name = 'allVMimages' AND resourcegroup.resourcetypeid =137 AND privnode.name = 'admin' AND privnode.parent = 3;

-- --------------------------------------------------------

-- 
-- Inserts for table `state`
--

INSERT IGNORE INTO state (id, name) VALUES (24, 'checkpoint'), (25, 'serverinuse'), (26, 'rebootsoft'), (27, 'reinstall'), (28, 'reboothard'), (29, 'servermodified');

-- --------------------------------------------------------

-- 
-- Inserts for table `usergroup`
--

UPDATE IGNORE `usergroup` SET `overlapResCount` = '50' WHERE `usergroup`.`name` = 'adminUsers' AND `usergroup`.`overlapResCount` = 0;

-- --------------------------------------------------------

-- 
-- Inserts for table `usergroupmembers`
--

INSERT IGNORE INTO `usergroupmembers` (`userid`, `usergroupid`) VALUES
((SELECT `id` FROM `user` WHERE `unityid` = 'admin' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')), (SELECT `id` FROM `usergroup` WHERE `name` = 'adminUsers' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local'))),
((SELECT `id` FROM `user` WHERE `unityid` = 'admin' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')), (SELECT `id` FROM `usergroup` WHERE `name` = 'manageNewImages' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local'))),
((SELECT `id` FROM `user` WHERE `unityid` = 'admin' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')), (SELECT `id` FROM `usergroup` WHERE `name` = 'Specify End Time' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')));

-- --------------------------------------------------------

-- 
-- Inserts for table `usergroupprivtype`
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
(15, 'Manage Federated User Groups (affiliation only)', 'Grants the ability to control attributes of user groups that are created through federated systems such as LDAP and Shibboleth. Does not grant control of user group membership.');

UPDATE `usergroupprivtype` SET `name` = 'Manage Block Allocations (global)', `help` = 'Grants the ability to create, accept, and reject block allocations for any affiliation.' WHERE name = 'Manage Block Allocations';

-- --------------------------------------------------------

-- 
-- Inserts for table `usergrouppriv`
--

INSERT IGNORE usergrouppriv (usergroupid, userprivtypeid) SELECT usergroup.id, usergroupprivtype.id FROM usergroup, usergroupprivtype WHERE usergroup.name = 'adminUsers' AND usergroup.affiliationid = (SELECT id FROM affiliation WHERE name = 'Local');

-- --------------------------------------------------------

-- 
-- Inserts for table `userprivtype`
--

INSERT IGNORE INTO userprivtype (id, name) VALUES (8, 'serverCheckOut');
INSERT IGNORE INTO userprivtype (id, name) VALUES (9, 'serverProfileAdmin');

-- --------------------------------------------------------

-- 
-- Inserts for table `userpriv`
--

INSERT IGNORE userpriv (userid, privnodeid, userprivtypeid) SELECT user.id, privnode.id, userprivtype.id FROM user, privnode, userprivtype WHERE user.unityid = 'admin' AND user.affiliationid = (SELECT id FROM affiliation WHERE name = 'Local') AND privnode.name = 'admin' AND privnode.parent = 3 AND userprivtype.name = 'serverCheckOut';
INSERT IGNORE userpriv (userid, privnodeid, userprivtypeid) SELECT user.id, privnode.id, userprivtype.id FROM user, privnode, userprivtype WHERE user.unityid = 'admin' AND user.affiliationid = (SELECT id FROM affiliation WHERE name = 'Local') AND privnode.name = 'admin' AND privnode.parent = 3 AND userprivtype.name = 'serverProfileAdmin';
INSERT IGNORE userpriv (usergroupid, privnodeid, userprivtypeid) SELECT usergroup.id, privnode.id, userprivtype.id FROM usergroup, privnode, userprivtype WHERE usergroup.name = 'adminUsers' AND usergroup.affiliationid = (SELECT id FROM affiliation WHERE name = 'Local') AND privnode.name = 'admin' AND privnode.parent = 3 AND userprivtype.name = 'serverCheckOut';
INSERT IGNORE userpriv (usergroupid, privnodeid, userprivtypeid) SELECT usergroup.id, privnode.id, userprivtype.id FROM usergroup, privnode, userprivtype WHERE usergroup.name = 'adminUsers' AND usergroup.affiliationid = (SELECT id FROM affiliation WHERE name = 'Local') AND privnode.name = 'admin' AND privnode.parent = 3 AND userprivtype.name = 'serverProfileAdmin';


-- --------------------------------------------------------

-- 
-- Inserts for table `variable`
--

INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('schema-version', 'none', '1');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('timesource|global', 'none','time.nist.gov,time-a.nist.gov,time-b.nist.gov,time.windows.com');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('acknowledgetimeout', 'none', '900');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('connecttimeout', 'none', '900');

-- 
-- Inserts for table `vmprofile`
--

UPDATE vmprofile SET vmprofile.repositoryimagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'none') WHERE vmprofile.repositoryimagetypeid = 0;
UPDATE vmprofile SET vmprofile.datastoreimagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'none') WHERE vmprofile.datastoreimagetypeid = 0;

-- --------------------------------------------------------

--
-- Constraints for table `computer`
--

CALL AddConstraintIfNotExists('computer', 'currentimageid', 'image', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `connectmethodmap`
--

CALL AddConstraintIfNotExists('connectmethodmap', 'connectmethodid', 'connectmethod', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('connectmethodmap', 'OStypeid', 'OStype', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('connectmethodmap', 'OSid', 'OS', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('connectmethodmap', 'imagerevisionid', 'imagerevision', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `image`
--

CALL AddConstraintIfNotExists('image', 'imagetypeid', 'imagetype', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `provisioningOSinstalltype`
--
 
CALL AddConstraintIfNotExists('provisioningOSinstalltype', 'provisioningid', 'provisioning', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('provisioningOSinstalltype', 'OSinstalltypeid', 'OSinstalltype', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `reservationaccounts`
--

CALL AddConstraintIfNotExists('reservationaccounts', 'reservationid', 'reservation', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('reservationaccounts', 'userid', 'user', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `serverprofile`
--

CALL AddConstraintIfNotExists('serverprofile', 'ownerid', 'user', 'id', 'none', '');
CALL AddConstraintIfNotExists('serverprofile', 'admingroupid', 'usergroup', 'id', 'none', '');
CALL AddConstraintIfNotExists('serverprofile', 'logingroupid', 'usergroup', 'id', 'none', '');
CALL AddConstraintIfNotExists('serverprofile', 'imageid', 'image', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `serverrequest`
--

CALL AddConstraintIfNotExists('serverrequest', 'requestid', 'request', 'id', 'delete', 'CASCADE');
CALL AddConstraintIfNotExists('serverrequest', 'admingroupid', 'usergroup', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('serverrequest', 'logingroupid', 'usergroup', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `usergrouppriv`
--

CALL AddConstraintIfNotExists('usergrouppriv', 'usergroupid', 'usergroup', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('usergrouppriv', 'userprivtypeid', 'usergroupprivtype', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `vmhost`
--
 
CALL AddConstraintIfNotExists('vmhost', 'vmprofileid', 'vmprofile', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('vmhost', 'computerid', 'computer', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `vmprofile`
--

CALL AddConstraintIfNotExists('vmprofile', 'repositoryimagetypeid', 'imagetype', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('vmprofile', 'datastoreimagetypeid', 'imagetype', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `winKMS`
--

CALL AddConstraintIfNotExists('winKMS', 'affiliationid', 'affiliation', 'id', 'update', 'CASCADE');
 
-- --------------------------------------------------------

--
-- Constraints for table `winProductKey`
--

CALL AddConstraintIfNotExists('winProductKey', 'affiliationid', 'affiliation', 'id', 'update', 'CASCADE');
 
-- --------------------------------------------------------

--
-- remove table xmlrpcKey
--

DROP TABLE IF EXISTS `xmlrpcKey`;

-- --------------------------------------------------------

--
-- Remove references to legacy vmware.pm provisioning module
--

UPDATE IGNORE computer, provisioning SET
computer.provisioningid = (
  SELECT DISTINCT
  MIN(provisioning.id)
  FROM
  provisioning,
  module
  WHERE
  provisioning.moduleid = (SELECT MIN(module.id) FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::VMware::VMware')
)
WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::vmware');

UPDATE IGNORE statgraphcache, provisioning SET
statgraphcache.provisioningid = (
  SELECT DISTINCT
  MIN(provisioning.id)
  FROM
  provisioning,
  module
  WHERE
  provisioning.moduleid = (SELECT MIN(module.id) FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::VMware::VMware')
)
WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::vmware');

DELETE FROM provisioning WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::vmware');

DELETE FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::vmware';

--
-- Remove Procedures
--

DROP PROCEDURE IF EXISTS `AddColumnIfNotExists`;
DROP PROCEDURE IF EXISTS `DropColumnIfExists`;
DROP PROCEDURE IF EXISTS `AddIndexIfNotExists`;
DROP PROCEDURE IF EXISTS `AddUniqueIndex`;
DROP PROCEDURE IF EXISTS `AddConstraintIfNotExists`;
DROP PROCEDURE IF EXISTS `AddConnectMethodMapIfNotExists`;
DROP PROCEDURE IF EXISTS `AlterVMDiskValues`;
DROP PROCEDURE IF EXISTS `AddOrRenameColumn`;
DROP PROCEDURE IF EXISTS `DropExistingConstraints`;
DROP PROCEDURE IF EXISTS `DropExistingIndices`;
DROP PROCEDURE IF EXISTS `AddManageMapping`;
DROP PROCEDURE IF EXISTS `Add2ColUniqueIndexIfNotExist`;
