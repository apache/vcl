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

-- Apache VCL version 2.3.2 to 2.4.2 database schema changes

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
    -- CALL PrintMessage((SELECT CONCAT('adding column: ', @statement_array)));
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
  DECLARE existing_constraint_name CHAR(40);
  DECLARE database_name CHAR(25);

  DECLARE select_existing_constraint_names CURSOR FOR
    SELECT CONSTRAINT_NAME, TABLE_SCHEMA FROM information_schema.KEY_COLUMN_USAGE WHERE
    TABLE_SCHEMA = Database()
    AND TABLE_NAME = tableName
    AND COLUMN_NAME = columnName
    AND REFERENCED_TABLE_NAME IS NOT NULL;
  
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
  OPEN select_existing_constraint_names;
  
  -- CALL PrintMessage((SELECT CONCAT('DropExistingConstraints: ', tableName, '.', columnName)));

  REPEAT
    FETCH select_existing_constraint_names INTO existing_constraint_name, database_name;
    -- CALL PrintMessage((SELECT CONCAT('existing constraint: ', existing_constraint_name)));
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
  DECLARE existing_index_name CHAR(40);
  DECLARE database_name CHAR(25);
  
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
  DECLARE nonunique_index_name CHAR(40);
  
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
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SELECT CONCAT('WARNING: AddConstraintIfNotExists: ', tableName, '.', columnName, ' --> ', referencedTableName, '.', referencedColumnName) AS '';
    -- GET DIAGNOSTICS CONDITION 1 @sqlstate = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @text = MESSAGE_TEXT;
    -- SELECT CONCAT('ERROR ', @errno, ': ', @text) AS '';
	END;
  
  -- CALL PrintMessage((SELECT CONCAT('AddConstraintIfNotExists: ', tableName, '.', columnName, ' --> ', referencedTableName, '.', referencedColumnName)));
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
    ELSEIF constraintType = 'both' AND constraintAction = 'nullCASCADE' THEN
      SET @statement_array = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD FOREIGN KEY (', columnName, ') REFERENCES `', Database(), '`.', referencedTableName, ' (', referencedColumnName, ') ON DELETE SET NULL ON UPDATE CASCADE');
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
  DECLARE nonunique_index_name CHAR(40);
  
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

-- --------------------------------------------------------

/*
Procedure   : Add3ColUniqueIndexIfNotExist
Parameters  : tableName, columnName1, columnName2, columnName2
Description : Adds a unique index to an existing table if a primary or unique
              index does not already exist for the column. Any non-unique
              indices are dropped before the unique index is added. If 
              deleteduplicates is passed as 1, any duplicates in the table
              will be dropped. If any other value is passed and there are
              duplicates in the table, it will throw an error.
*/

DROP PROCEDURE IF EXISTS `Add3ColUniqueIndexIfNotExist`$$
CREATE PROCEDURE `Add3ColUniqueIndexIfNotExist`(
  IN tableName tinytext,
  IN columnName1 tinytext,
  IN columnName2 tinytext,
  IN columnName3 tinytext,
  IN deleteduplicates tinyint
)
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE nonunique_index_name CHAR(40);
  
  DECLARE select_index_names CURSOR FOR
    SELECT
    i1.INDEX_NAME
    FROM
    information_schema.STATISTICS i1,
    information_schema.STATISTICS i2
    LEFT JOIN information_schema.STATISTICS i3 ON (
      i3.TABLE_SCHEMA = i2.TABLE_SCHEMA
      AND i3.TABLE_NAME = i2.TABLE_NAME
      AND i3.INDEX_NAME = i2.INDEX_NAME
      AND i3.SEQ_IN_INDEX = 3
    )
    WHERE
    i1.TABLE_SCHEMA = Database()
    AND i1.TABLE_NAME = tableName
    AND i1.SEQ_IN_INDEX = 1
    AND i1.COLUMN_NAME IN (columnName1, columnName2, columnName3)
    AND i2.TABLE_SCHEMA = i1.TABLE_SCHEMA
    AND i2.TABLE_NAME = i1.TABLE_NAME
    AND i2.INDEX_NAME = i1.INDEX_NAME
    AND i2.SEQ_IN_INDEX = 2
    AND i2.COLUMN_NAME IN (columnName1, columnName2, columnName3)
    AND (i3.COLUMN_NAME IS NULL OR i3.COLUMN_NAME IN (columnName1, columnName2, columnName3))
    AND i1.NON_UNIQUE = 1;

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
    SELECT
    i1.INDEX_NAME,
    i1.COLUMN_NAME AS c1,
    i2.COLUMN_NAME AS c2,
    i3.COLUMN_NAME AS c3
    
    FROM
    information_schema.STATISTICS i1,
    information_schema.STATISTICS i2,
    information_schema.STATISTICS i3
    
    WHERE
    i1.TABLE_SCHEMA = Database()
    AND i1.TABLE_SCHEMA = i2.TABLE_SCHEMA
    AND i1.TABLE_SCHEMA = i3.TABLE_SCHEMA
    
    AND i1.TABLE_NAME = tableName
    AND i1.TABLE_NAME = i2.TABLE_NAME
    AND i1.TABLE_NAME = i3.TABLE_NAME
    
    AND i1.INDEX_NAME = i2.INDEX_NAME
    AND i1.INDEX_NAME = i3.INDEX_NAME
    
    AND i1.COLUMN_NAME != i2.COLUMN_NAME
    AND i1.COLUMN_NAME != i3.COLUMN_NAME
    
    AND i1.SEQ_IN_INDEX = 1
    AND i2.SEQ_IN_INDEX = 2
    AND i3.SEQ_IN_INDEX = 3
    
    AND i1.COLUMN_NAME IN (columnName1, columnName2, columnName3)
    AND i2.COLUMN_NAME IN (columnName1, columnName2, columnName3)
    AND i3.COLUMN_NAME IN (columnName1, columnName2, columnName3)
    AND i1.NON_UNIQUE = 0
  )
  THEN
    IF deleteduplicates = 1 THEN
      SET @add_unique_index = CONCAT('ALTER IGNORE TABLE `', Database(), '`.', tableName, ' ADD UNIQUE (', columnName1, ',', columnName2, ',', columnName3, ')');
    ELSE
      SET @add_unique_index = CONCAT('ALTER TABLE `', Database(), '`.', tableName, ' ADD UNIQUE (', columnName1, ',', columnName2, ',', columnName3, ')');
    END IF;
    PREPARE add_unique_index FROM @add_unique_index;
    EXECUTE add_unique_index;
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : moveConnectMethodPortProtocol
Description : Populates connectmethodport table from connectmethod table if it is empty
*/

DROP PROCEDURE IF EXISTS `moveConnectMethodPortProtocol`$$
CREATE PROCEDURE `moveConnectMethodPortProtocol`(
)
BEGIN
  IF EXISTS (
    SELECT id FROM connectmethod WHERE connecttext LIKE '#connectport#'
  )
  THEN
    UPDATE connectmethod SET connecttext = REPLACE(connecttext , '#connectport#', CONCAT('#Port-', protocol, '-', port, '#'));
  END IF;
  IF NOT EXISTS (
    SELECT id FROM connectmethodport
  )
  THEN
    IF EXISTS (
      SELECT * FROM information_schema.COLUMNS WHERE
      TABLE_SCHEMA=Database()
      AND COLUMN_NAME='port'
      AND TABLE_NAME='connectmethod'
    ) AND EXISTS (
      SELECT * FROM information_schema.COLUMNS WHERE
      TABLE_SCHEMA=Database()
      AND COLUMN_NAME='protocol'
      AND TABLE_NAME='connectmethod'
    )
    THEN
      INSERT INTO connectmethodport (connectmethodid, port, protocol) SELECT id, port, IFNULL(NULLIF(protocol,''),'TCP') FROM connectmethod;
      CALL DropColumnIfExists('connectmethod', 'port');
      CALL DropColumnIfExists('connectmethod', 'protocol');
    END IF;
  END IF;
END$$

-- --------------------------------------------------------

/*
Procedure   : AddUserGroup
Parameters  : name, grpaffiliation, ownername, owneraffiliation, editgroupname, editaffiliation
Description : Adds user group named "Allow No User Check"
*/

DROP PROCEDURE IF EXISTS `AddUserGroup`$$
CREATE PROCEDURE `AddUserGroup`(
  IN name tinytext,
  IN grpaffiliation tinytext,
  IN ownername tinytext,
  IN owneraffiliation tinytext,
  IN editgroupname tinytext,
  IN editaffiliation tinytext
)
BEGIN

  SELECT `affiliation`.id INTO @affiliationid FROM `affiliation` WHERE `affiliation`.`name` = grpaffiliation;
  SELECT `user`.id INTO @ownerid FROM `user`, `affiliation` WHERE `user`.unityid = ownername AND `user`.affiliationid = affiliation.id AND affiliation.name = owneraffiliation;
  SELECT `usergroup`.id INTO @editusergroupid FROM `usergroup`, `affiliation` WHERE `usergroup`.name = editgroupname AND `usergroup`.affiliationid = affiliation.id AND affiliation.name = editaffiliation;

  SET @insrt = CONCAT('INSERT IGNORE INTO `usergroup` (`name`, `affiliationid`, `ownerid`, `editusergroupid`, `custom`, `courseroll`, `overlapResCount`) VALUES (', QUOTE(name), ',', @affiliationid, ',', @ownerid, ',', @editusergroupid, ', 1, 0, 0)');
  PREPARE insrt FROM @insrt;
  EXECUTE insrt;

END$$

-- --------------------------------------------------------

/*
Procedure   : PrintMessage
Parameters  : message
Description : 
*/

DROP PROCEDURE IF EXISTS `PrintMessage`$$
CREATE PROCEDURE PrintMessage(
  IN message VARCHAR(255)
)
BEGIN
  SELECT CONCAT("** ", message) AS '';
END $$

/* ============= End of Stored Procedures ===============*/

-- --------------------------------------------------------

--
--  Table structure for table `affiliation`
--

ALTER TABLE `affiliation` CHANGE `sitewwwaddress` `sitewwwaddress` varchar(128) DEFAULT NULL;
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

CALL DropColumnIfExists('blockRequest', 'admingroupid');
ALTER TABLE `blockRequest` CHANGE `groupid` `groupid` smallint(5) unsigned DEFAULT NULL;
UPDATE blockRequest SET groupid = NULL WHERE groupid = 0;
ALTER TABLE `blockRequest` CHANGE `managementnodeid` `managementnodeid` smallint(5) unsigned DEFAULT NULL;
UPDATE blockRequest SET managementnodeid = NULL WHERE managementnodeid = 0;
-- --------------------------------------------------------

--
--  Table structure for table `blockTimes`
--

CALL AddColumnIfNotExists('blockTimes', 'skip', "tinyint(1) unsigned NOT NULL default '0'");

-- --------------------------------------------------------

--
--  Table structure for table `changelog`
--

CALL AddColumnIfNotExists('changelog', 'userid', "mediumint(8) unsigned default NULL AFTER `logid`");
CALL AddColumnIfNotExists('changelog', 'reservationid', "mediumint(8) unsigned default NULL AFTER `userid`");
CALL AddColumnIfNotExists('changelog', 'other', "varchar(255) default NULL AFTER `timestamp`");
CALL AddIndexIfNotExists('changelog', 'userid');
CALL AddIndexIfNotExists('changelog', 'reservationid');

CALL Add3ColUniqueIndexIfNotExist('changelog', 'userid', 'reservationid', 'remoteIP', 0);

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
CALL AddColumnIfNotExists('computer', 'predictivemoduleid', "SMALLINT(5) UNSIGNED NOT NULL DEFAULT '9'");

-- set datedeleted for deleted computers
UPDATE computer SET datedeleted = NOW() WHERE deleted = 1 AND datedeleted = '0000-00-00 00:00:00';

-- --------------------------------------------------------

-- 
--  Table structure for table `computerloadflow`
--

ALTER TABLE `computerloadflow` CHANGE `computerloadstateid` `computerloadstateid` smallint(8) unsigned NOT NULL;
ALTER TABLE `computerloadflow` CHANGE `nextstateid` `nextstateid` smallint(8) unsigned default NULL;

-- --------------------------------------------------------

-- 
--  Table structure for table `computerloadlog`
--

CALL AddIndexIfNotExists('computerloadlog', 'loadstateid');
CALL AddIndexIfNotExists('computerloadlog', 'computerid');

ALTER TABLE `computerloadlog` CHANGE `loadstateid` `loadstateid` SMALLINT( 8 ) UNSIGNED NOT NULL;

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
-- Table structure for table `connectmethodport`
--

CREATE TABLE IF NOT EXISTS `connectmethodport` (
  `id` tinyint(3) unsigned NOT NULL auto_increment,
  `connectmethodid` tinyint(3) unsigned NOT NULL,
  `port` mediumint(8) unsigned NOT NULL,
  `protocol` enum('TCP','UDP') NOT NULL default 'TCP',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `connectmethodid_2` (`connectmethodid`,`port`,`protocol`),
  KEY `connectmethodid` (`connectmethodid`)
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
  UNIQUE KEY reservationid_2 (reservationid,userid,remoteIP),
  KEY reservationid (reservationid),
  KEY userid (userid),
  KEY logid (logid)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table 'continuations'
--

CALL AddIndexIfNotExists('continuations', 'deletefromid');

-- --------------------------------------------------------

-- 
--  Table structure for table `image`
--

ALTER TABLE `image` CHANGE `prettyname` `prettyname` varchar(80) NOT NULL default '';
ALTER TABLE `image` CHANGE `minram` `minram` MEDIUMINT UNSIGNED NOT NULL DEFAULT '0';
ALTER TABLE `image` CHANGE `platformid` `platformid` tinyint(3) unsigned NOT NULL default '1';
ALTER TABLE `image` CHANGE `size` `size` smallint(5) unsigned NOT NULL default '0';

CALL AddColumnIfNotExists('image', 'imagetypeid', "smallint(5) unsigned NOT NULL default '1' AFTER ownerid");
CALL AddIndexIfNotExists('image', 'imagetypeid');

ALTER TABLE `image` CHANGE `basedoffrevisionid` `basedoffrevisionid` mediumint(8) unsigned default NULL;
CALL AddIndexIfNotExists('image', 'basedoffrevisionid');

-- --------------------------------------------------------

-- 
--  Table structure for table `imagemeta`
--

CALL DropColumnIfExists('imagemeta', 'usergroupid');
CALL AddColumnIfNotExists('imagemeta', 'sethostname', "tinyint(1) unsigned default NULL AFTER rootaccess");

-- --------------------------------------------------------

-- 
--  Table structure for table `imagerevision`
--

CALL AddColumnIfNotExists('imagerevision', 'autocaptured', "tinyint(1) unsigned NOT NULL default '0'");


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

CALL AddColumnIfNotExists('loginlog', 'code', "enum('none','invalid credentials') NOT NULL DEFAULT 'none'");
CALL AddIndexIfNotExists('loginlog', 'timestamp');
CALL AddIndexIfNotExists('loginlog', 'authmech');
CALL AddIndexIfNotExists('loginlog', 'code');

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
CALL AddColumnIfNotExists('managementnode', 'availablenetworks', "text NOT NULL");
CALL DropColumnIfExists('managementnode', 'predictivemoduleid');
CALL AddUniqueIndex('managementnode', 'hostname');

-- --------------------------------------------------------

--
-- Table structure change for table `module`
--

CALL AddUniqueIndex('module', 'name');

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
-- Table structure change for table `OS`
--

ALTER TABLE `OS` CHANGE `prettyname` `prettyname` varchar(64) NOT NULL default '';
CALL AddColumnIfNotExists('OS', 'minram', "MEDIUMINT UNSIGNED NOT NULL DEFAULT '512' AFTER installtype");

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
ALTER TABLE `reservation` CHANGE `pw` `pw` VARCHAR(40) NULL DEFAULT NULL;

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
  `affiliationid` mediumint(8) unsigned default NULL,
  `value` mediumint(8) unsigned NOT NULL,
  `provisioningid` smallint(5) unsigned default NULL,
  KEY `graphtype` (`graphtype`),
  KEY `statdate` (`statdate`),
  KEY `affiliationid` (`affiliationid`),
  KEY `provisioningid` (`provisioningid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CALL AddColumnIfNotExists('statgraphcache', 'provisioningid', "smallint(5) unsigned default NULL");
CALL AddIndexIfNotExists('statgraphcache', 'provisioningid');

ALTER TABLE `statgraphcache` CHANGE `affiliationid` `affiliationid` mediumint(8) unsigned default NULL;
ALTER TABLE `statgraphcache` CHANGE `provisioningid` `provisioningid` smallint(5) unsigned default NULL;
UPDATE statgraphcache SET affiliationid = NULL WHERE affiliationid = 0;
UPDATE statgraphcache SET provisioningid = NULL WHERE provisioningid = 0;
DELETE FROM statgraphcache WHERE affiliationid IS NOT NULL AND affiliationid NOT IN (SELECT id FROM affiliation);
DELETE FROM statgraphcache WHERE provisioningid IS NOT NULL AND provisioningid NOT IN (SELECT id FROM provisioning);

-- --------------------------------------------------------

--
-- Table structure change for table `sublog`
--

CALL AddColumnIfNotExists('sublog', 'id', "int(10) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST");
CALL AddColumnIfNotExists('sublog', 'hostcomputerid', "smallint(5) unsigned default NULL");
CALL AddColumnIfNotExists('sublog', 'blockRequestid', "mediumint(8) unsigned default NULL");
CALL AddColumnIfNotExists('sublog', 'blockStart', "datetime default NULL");
CALL AddColumnIfNotExists('sublog', 'blockEnd', "datetime default NULL");
ALTER TABLE `sublog` CHANGE `blockRequestid` `blockRequestid` mediumint(8) unsigned default NULL;
ALTER TABLE `sublog` CHANGE `blockStart` `blockStart` datetime default NULL;
ALTER TABLE `sublog` CHANGE `blockEnd` `blockEnd` datetime default NULL;
CALL AddIndexIfNotExists('sublog', 'blockRequestid');

-- --------------------------------------------------------

-- 
-- Table structure change for table `request`
-- 

CALL AddColumnIfNotExists('request', 'checkuser', "tinyint(1) unsigned NOT NULL default '1'");

-- --------------------------------------------------------

--
-- Table structure change for table `user`
--

CALL AddColumnIfNotExists('user', 'validated', "tinyint(1) unsigned NOT NULL default '1'");
CALL AddColumnIfNotExists('user', 'usepublickeys', "tinyint(1) unsigned NOT NULL default '0'");
CALL AddColumnIfNotExists('user', 'sshpublickeys', "text");
CALL AddColumnIfNotExists('user', 'rdpport', "SMALLINT UNSIGNED NULL AFTER `mapserial`");
ALTER TABLE `user` CHANGE `IMtypeid` `IMtypeid` tinyint(3) unsigned default NULL;

-- --------------------------------------------------------

--
-- Table structure change for table `usergroup`
--

ALTER TABLE `usergroup` CHANGE `initialmaxtime` `initialmaxtime` mediumint(8) unsigned NOT NULL default '240';
ALTER TABLE `usergroup` CHANGE `totalmaxtime` `totalmaxtime` mediumint(8) unsigned NOT NULL default '360';
ALTER TABLE `usergroup` CHANGE `maxextendtime` `maxextendtime` mediumint(8) unsigned NOT NULL default '60';

-- --------------------------------------------------------

--
-- Table structure change for table `userpriv`
--

-- have to drop constraint before dropping index
CALL DropExistingConstraints('userpriv', 'userid');
CALL DropExistingConstraints('userpriv', 'usergroupid');

CALL DropExistingIndices('userpriv', 'userid');
CALL DropExistingIndices('userpriv', 'usergroupid');
CALL Add3ColUniqueIndexIfNotExist('userpriv', 'userid', 'privnodeid', 'userprivtypeid', 1);
CALL Add3ColUniqueIndexIfNotExist('userpriv', 'usergroupid', 'privnodeid', 'userprivtypeid', 1);

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

ALTER TABLE `vmhost` CHANGE `vmlimit` `vmlimit` smallint(5) unsigned NOT NULL;
ALTER TABLE `vmhost` CHANGE `vmprofileid` `vmprofileid` smallint(5) unsigned NOT NULL;
CALL AddIndexIfNotExists('vmhost', 'vmprofileid');
CALL DropColumnIfExists('vmhost', 'vmkernalnic');
CALL DropColumnIfExists('vmhost', 'vmwaredisk');
-- have to drop constraint before dropping index
CALL DropExistingConstraints('vmhost', 'computerid');
CALL DropExistingIndices('vmhost', 'computerid');
CALL Add2ColUniqueIndexIfNotExist('vmhost', 'computerid', 'vmprofileid');

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
CALL AddColumnIfNotExists('vmprofile', 'rsapub', "text NULL default NULL AFTER `virtualswitch3`");
CALL AddColumnIfNotExists('vmprofile', 'rsakey', "varchar(256) NULL default NULL AFTER `rsapub`");
CALL AddColumnIfNotExists('vmprofile', 'encryptedpasswd', "text NULL default NULL AFTER `rsakey`");
CALL AddColumnIfNotExists('vmprofile', 'folderpath', "varchar(256) default NULL AFTER resourcepath");

CALL AddOrRenameColumn('vmprofile', 'vmware_mac_eth0_generated', 'eth0generated', "tinyint(1) unsigned NOT NULL default '0'");
CALL AddOrRenameColumn('vmprofile', 'vmware_mac_eth1_generated', 'eth1generated', "tinyint(1) unsigned NOT NULL default '0'");

CALL AlterVMDiskValues();

CALL AddUniqueIndex('vmprofile', 'profilename');
CALL AddIndexIfNotExists('vmprofile', 'repositoryimagetypeid');
CALL AddIndexIfNotExists('vmprofile', 'datastoreimagetypeid');

-- --------------------------------------------------------

-- 
-- Table structure change for table `vmtype`
-- 

CALL AddUniqueIndex('vmtype', 'name');

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

ALTER TABLE `xmlrpcLog` CHANGE `xmlrpcKeyid` `xmlrpcKeyid` mediumint(8) unsigned NOT NULL default '0' COMMENT 'this is the userid if apiversion greater than 1';
CALL AddIndexIfNotExists('xmlrpcLog', 'timestamp');

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
-- Inserts for table `computerloadstate`
-- 

INSERT IGNORE INTO `computerloadstate` (`loadstatename`,`prettyname`) VALUES ('acknowledgetimeout','start acknowledge timeout');

INSERT IGNORE INTO `computerloadstate` (`loadstatename`,`prettyname`) VALUES ('noinitialconnection','initial user connection not detected');
INSERT IGNORE INTO `computerloadstate` (`loadstatename`,`prettyname`) VALUES ('initialconnecttimeout','initial user connection timeout');
INSERT IGNORE INTO `computerloadstate` (`loadstatename`,`prettyname`) VALUES ('reconnecttimeout','user reconnection timeout');
INSERT IGNORE INTO `computerloadstate` (`loadstatename`,`prettyname`,`est`) VALUES ('copyfrompartnerMN','copy image from partner management node','20');
INSERT IGNORE INTO `computerloadstate` (`loadstatename`,`prettyname`) VALUES ('postreserve','post reserve completed');
INSERT IGNORE INTO `computerloadstate` (`loadstatename`,`prettyname`,`est`) VALUES ('exited', 'vcl process exited', 0);

UPDATE `computerloadstate` SET loadstatename = 'machinebooted' WHERE loadstatename = 'vmstage4';
UPDATE `computerloadstate` SET prettyname = 'confirming image exists locally' WHERE loadstatename = 'doesimageexists';

-- --------------------------------------------------------

--
-- Inserts for computerloadflow
-- As the computerloadstatenames can change, tuncate table and rebuild the flow.
--

TRUNCATE TABLE `computerloadflow`;
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

UPDATE image SET imagemetaid = NULL WHERE NOT EXISTS (SELECT * FROM imagemeta WHERE image.imagemetaid = imagemeta.id);

-- --------------------------------------------------------

-- 
-- Inserts for table `module`
-- 

UPDATE IGNORE `module` SET `name` = 'provisioning_vmware_1x', `prettyname` = 'VMware Server 1.x Provisioning Module' WHERE `name` = 'provisioning_vmware_gsx';
UPDATE IGNORE `module` SET `name` = 'provisioning_xCAT', `prettyname` = 'xCAT' WHERE `name` = 'provisioning_xcat_13';
UPDATE IGNORE `module` SET `prettyname` = 'Reload with last image' WHERE `name` = 'predictive_level_0' AND `prettyname` = 'Predictive Loading Module Level 0';
UPDATE IGNORE `module` SET `prettyname` = 'Reload image based on recent user demand' WHERE `name` = 'predictive_level_1' AND `prettyname` = 'Predictive Loading Module Level 1';
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_win7', 'Windows 7 OS Module', '', 'VCL::Module::OS::Windows::Version_6::7');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_vmware', 'VMware Provisioning Module', '', 'VCL::Module::Provisioning::VMware::VMware');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('state_image', 'VCL Image State Module', '', 'VCL::image');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('base_module', 'VCL Base Module', '', 'VCL::Module');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_vbox', 'Virtual Box Provisioning Module', '', 'VCL::Module::Provisioning::vbox');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_esxi', 'VMware ESXi OS Module', '', 'VCL::Module::OS::Linux::ESXi');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_osx', 'OSX OS Module', '', 'VCL::Module::OS::OSX');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_libvirt', 'Libvirt Provisioning Module', '', 'VCL::Module::Provisioning::libvirt');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_linux_managementnode', 'Management Mode Linux OS Module', '', 'VCL::Module::OS::Linux::ManagementNode');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_win8', 'Windows 8.x OS Module', '', 'VCL::Module::OS::Windows::Version_6::8');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_win2012', 'Windows Server 2012 OS Module', '', 'VCL::Module::OS::Windows::Version_6::2012');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('predictive_level_2', 'Unload/power off after reservation', 'Power off computer. If a virtual machine, it will be also destroyed.', 'VCL::Module::Predictive::Level_2');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_openstack', 'OpenStack Provisioning Module', '', 'VCL::Module::Provisioning::openstack');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_one', 'OpenNebula Provisioning Module', '', 'VCL::Module::Provisioning::one');
INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('os_win10', 'Windows 10.x OS Module', '', 'VCL::Module::OS::Windows::Version_10::10');

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

INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarewin8', 'Windows 8.x (VMware)', 'windows', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win8'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('win8', 'Windows 8.x (Bare Metal)', 'windows', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win8'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarewin2012', 'Windows Server 2012 (VMware)', 'windows', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win2012'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('win2012', 'Windows Server 2012 (Bare Metal)', 'windows', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win2012'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('vmwarewin10', 'Windows 10.x (VMware)', 'windows', 'vmware', 'vmware_images', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win10'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('win10', 'Windows 10.x (Bare Metal)', 'windows', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_win10'));

INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('centos6', 'CentOS 6 (Kickstart)', 'linux', 'kickstart', 'centos6', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('centos7', 'CentOS 7 (Kickstart)', 'linux', 'kickstart', 'centos7', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('rhel7', 'Red Hat Enterprise 7 (Kickstart)', 'linux', 'kickstart', 'rhel7', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('rhel7image', 'CentOS 7 Image', 'linux', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('centos6image', 'CentOS 6 Image', 'linux', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('centos7image', 'CentOS 7 Image', 'linux', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));
INSERT IGNORE INTO `OS` (`name`, `prettyname`, `type`, `installtype`, `sourcepath`, `moduleid`) VALUES ('rhelimage', 'General Red Hat Based Image', 'linux', 'partimage', 'image', (SELECT `id` FROM `module` WHERE `name` LIKE 'os_linux'));

UPDATE OS SET minram = 1024 WHERE name REGEXP 'win.*';
UPDATE OS SET minram = 2048 WHERE name REGEXP 'win.*(7|8|10|2008|2012)';
UPDATE OS SET minram = 1024 WHERE name REGEXP '(centos|rh|rhel)(5|6|7)';

-- --------------------------------------------------------

--
-- Inserts for table `OSinstalltype`
--

INSERT IGNORE INTO `OSinstalltype` (`name`) VALUES ('vbox');
INSERT IGNORE INTO `OSinstalltype` (`name`) VALUES ('openstack');

-- --------------------------------------------------------

--
-- Inserts for table `provisioning`
--

INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('vmware', 'VMware', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_vmware'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('vbox', 'Virtual Box', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_vbox'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('libvirt','Libvirt Virtualization API', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_libvirt'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('none','None', (SELECT `id` FROM `module` WHERE `name` = 'base_module'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('openstack', 'OpenStack Provisioning', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_openstack'));
INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('one', 'OpenNebula', (SELECT id FROM module where name='provisioning_one'));

UPDATE IGNORE `provisioning` SET `name` = 'xcat', `prettyname` = 'xCAT' WHERE `name` = 'xcat_13'; 

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
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name LIKE '%openstack%' AND OSinstalltype.name = 'openstack';
INSERT IGNORE provisioningOSinstalltype (provisioningid, OSinstalltypeid) SELECT provisioning.id, OSinstalltype.id FROM provisioning, OSinstalltype WHERE provisioning.name='one' AND OSinstalltype.name = 'vmware';

DELETE FROM provisioningOSinstalltype WHERE provisioningOSinstalltype.provisioningid IN (SELECT provisioning.id FROM provisioning WHERE provisioning.name LIKE '%xcat_2%');

-- --------------------------------------------------------

--
-- Inserts for table `connectmethod`
--

UPDATE `connectmethod` SET name = 'SSH', description = 'SSH for Linux & Unix' WHERE name = 'ssh';
UPDATE `connectmethod` SET name = 'RDP', description = 'Remote Desktop for Windows' WHERE name = 'rdp';

INSERT IGNORE INTO `connectmethod` (`name`, `description`, `connecttext`, `servicename`, `startupscript`) VALUES
('SSH', 'SSH for Linux & Unix', 'You will need to have an X server running on your local computer and use an SSH client to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<strong><big>NOTE:</big> You cannot use the Windows Remote Desktop Connection to connect to this computer. You must use an ssh client.</strong>', 'ext_sshd', '/etc/init.d/ext_sshd');

INSERT IGNORE INTO `connectmethod` (`name`, `description`, `connecttext`, `servicename`, `startupscript`) VALUES
('RDP', 'Remote Desktop for Windows', 'You will need to use a Remote Desktop program to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\n\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<br>\r\nFor automatic connection, you can download an RDP file that can be opened by the Remote Desktop Connection program.<br><br>\r\n', 'TermService', NULL);

INSERT IGNORE INTO `connectmethod` (`name`, `description`, `connecttext`, `servicename`, `startupscript`) VALUES
('iRAPP RDP', 'Remote Desktop for OS X', 'You will need to use a Remote Desktop program to connect to the system. If you did not click on the <b>Connect!</b> button from the computer you will be using to access the VCL system, you will need to return to the <strong>Current Reservations</strong> page and click the <strong>Connect!</strong> button from a web browser running on the same computer from which you will be connecting to the VCL system. Otherwise, you may be denied access to the remote computer.<br><br>\r\n\r\nUse the following information when you are ready to connect:<br>\r\n<UL>\r\n<LI><b>Remote Computer</b>: #connectIP#</LI>\r\n<LI><b>User ID</b>: #userid#</LI>\r\n<LI><b>Password</b>: #password#<br></LI>\r\n</UL>\r\n<b>NOTE</b>: The given password is for <i>this reservation only</i>. You will be given a different password for any other reservations.<br>\r\n<br>\r\nFor automatic connection, you can download an RDP file that can be opened by the Remote Desktop Connection program.<br><br>\r\n', NULL, NULL);

-- --------------------------------------------------------

--
-- Inserts for table `connectmethodport`
--

CALL moveConnectMethodPortProtocol;

UPDATE connectmethodport SET protocol = 'TCP' WHERE protocol = '';

INSERT IGNORE INTO `connectmethodport` (`connectmethodid`, `port`, `protocol`) VALUES
((SELECT id FROM connectmethod WHERE name LIKE 'ssh'), 22, 'TCP'),
((SELECT id FROM connectmethod WHERE name = 'RDP'), 3389, 'TCP'),
((SELECT id FROM connectmethod WHERE name = 'iRAPP RDP'), 3389, 'TCP');

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
-- changes for table `user`
--

UPDATE user SET IMtypeid = NULL WHERE IMtypeid NOT IN (SELECT id FROM IMtype);

-- --------------------------------------------------------

-- 
-- Inserts for table `usergroup`
--

UPDATE IGNORE `usergroup` SET `overlapResCount` = '50' WHERE `usergroup`.`name` = 'adminUsers' AND `usergroup`.`overlapResCount` = 0;
CALL AddUserGroup('Allow No User Check', 'Local', 'admin', 'Local', 'adminUsers', 'Local');

-- --------------------------------------------------------

-- 
-- Inserts for table `usergroupmembers`
--

INSERT IGNORE INTO `usergroupmembers` (`userid`, `usergroupid`) VALUES
((SELECT `id` FROM `user` WHERE `unityid` = 'admin' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')), (SELECT `id` FROM `usergroup` WHERE `name` = 'adminUsers' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local'))),
((SELECT `id` FROM `user` WHERE `unityid` = 'admin' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')), (SELECT `id` FROM `usergroup` WHERE `name` = 'manageNewImages' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local'))),
((SELECT `id` FROM `user` WHERE `unityid` = 'admin' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')), (SELECT `id` FROM `usergroup` WHERE `name` = 'Specify End Time' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local'))),
((SELECT `id` FROM `user` WHERE `unityid` = 'admin' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')), (SELECT `id` FROM `usergroup` WHERE `name` = 'Allow No User Check' AND `affiliationid` = (SELECT `id` FROM `affiliation` WHERE `name` = 'Local')));

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
(15, 'Manage Federated User Groups (affiliation only)', 'Grants the ability to control attributes of user groups that are created through federated systems such as LDAP and Shibboleth. Does not grant control of user group membership.'),
(16, 'Site Configuration (global)', 'Grants the ability to view the Site Configuration part of the site to manage site settings.'),
(17, 'Site Configuration (affiliation only)', 'Grants the ability to view the Site Configuration part of the site to manage site settings specific to the user''s own affiliation.');


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
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('initialconnecttimeout', 'none', '900');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('reconnecttimeout', 'none', '900');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('general_inuse_check', 'none', '300');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('server_inuse_check', 'none', '900');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('general_end_notice_first', 'none', '600');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('general_end_notice_second', 'none', '300');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('ignore_connections_gte', 'none', '1440');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('ignored_remote_ip_addresses', 'none', '');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('natport_ranges', 'none', '5700-6500,9696-9701,49152-65535');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('windows_ignore_users', 'none', 'Administrator,cyg_server,root,sshd,Guest');
INSERT IGNORE INTO `variable` (`name`, `serialization`, `value`) VALUES ('windows_disable_users', 'none', '');

-- --------------------------------------------------------

-- 
-- Inserts for table `vmprofile`
--

UPDATE vmprofile SET vmprofile.repositoryimagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'none') WHERE vmprofile.repositoryimagetypeid = 0;
UPDATE vmprofile SET vmprofile.datastoreimagetypeid = (SELECT `id` FROM `imagetype` WHERE `name` = 'none') WHERE vmprofile.datastoreimagetypeid = 0;

-- --------------------------------------------------------

--
-- Constraints for table `blockComputers`
--

CALL DropExistingConstraints('blockComputers', 'computerid');
CALL DropExistingConstraints('blockComputers', 'imageid');

CALL AddConstraintIfNotExists('blockComputers', 'blockTimeid', 'blockTimes', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('blockComputers', 'computerid', 'computer', 'id', 'none', '');
CALL AddConstraintIfNotExists('blockComputers', 'imageid', 'image', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `blockRequest`
--

CALL DropExistingConstraints('blockRequest', 'imageid');
CALL DropExistingConstraints('blockRequest', 'groupid');
CALL DropExistingConstraints('blockRequest', 'ownerid');
CALL DropExistingConstraints('blockRequest', 'managementnodeid');

CALL AddConstraintIfNotExists('blockRequest', 'imageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('blockRequest', 'groupid', 'usergroup', 'id', 'both', 'nullCASCADE');
CALL AddConstraintIfNotExists('blockRequest', 'ownerid', 'user', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('blockRequest', 'managementnodeid', 'managementnode', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `blockTimes`
--

CALL DropExistingConstraints('blockTimes', 'blockRequestid');

CALL AddConstraintIfNotExists('blockTimes', 'blockRequestid', 'blockRequest', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `blockWebDate`
--

CALL DropExistingConstraints('blockWebDate', 'blockRequestid');

CALL AddConstraintIfNotExists('blockWebDate', 'blockRequestid', 'blockRequest', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `blockWebTime`
--

CALL DropExistingConstraints('blockWebTime', 'blockRequestid');

CALL AddConstraintIfNotExists('blockWebTime', 'blockRequestid', 'blockRequest', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `changelog`
--

CALL DropExistingConstraints('changelog', 'logid');
CALL DropExistingConstraints('changelog', 'userid');
CALL DropExistingConstraints('changelog', 'computerid');

CALL AddConstraintIfNotExists('changelog', 'computerid', 'computer', 'id', 'none', '');
CALL AddConstraintIfNotExists('changelog', 'logid', 'log', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('changelog', 'userid', 'user', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `clickThroughs`
--

CALL DropExistingConstraints('clickThroughs', 'userid');
CALL DropExistingConstraints('clickThroughs', 'imageid');
CALL DropExistingConstraints('clickThroughs', 'imagerevisionid');

CALL AddConstraintIfNotExists('clickThroughs', 'userid', 'user', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('clickThroughs', 'imageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('clickThroughs', 'imagerevisionid', 'imagerevision', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `computer`
--

CALL DropExistingConstraints('computer', 'vmhostid');
CALL DropExistingConstraints('computer', 'ownerid');
CALL DropExistingConstraints('computer', 'scheduleid');
CALL DropExistingConstraints('computer', 'currentimageid');
CALL DropExistingConstraints('computer', 'nextimageid');

CALL AddConstraintIfNotExists('computer', 'vmhostid', 'vmhost', 'id', 'both', 'nullCASCADE');
CALL AddConstraintIfNotExists('computer', 'ownerid', 'user', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('computer', 'scheduleid', 'schedule', 'id', 'delete', 'SET NULL');
CALL AddConstraintIfNotExists('computer', 'currentimageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('computer', 'imagerevisionid', 'imagerevision', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('computer', 'nextimageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('computer', 'predictivemoduleid', 'module', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `computerloadflow`
--

CALL AddConstraintIfNotExists('computerloadflow', 'computerloadstateid', 'computerloadstate', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('computerloadflow', 'nextstateid', 'computerloadstate', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `computerloadlog`
--

CALL DropExistingConstraints('computerloadlog', 'loadstateid');

CALL AddConstraintIfNotExists('computerloadlog', 'computerid', 'computer', 'id', 'none', '');
CALL AddConstraintIfNotExists('computerloadlog', 'loadstateid', 'computerloadstate', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('computerloadlog', 'reservationid', 'reservation', 'id', 'delete', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `connectlog`
--

CALL DropExistingConstraints('connectlog', 'logid');
CALL DropExistingConstraints('connectlog', 'userid');

CALL AddConstraintIfNotExists('connectlog', 'logid', 'log', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('connectlog', 'userid', 'user', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `connectmethodmap`
--

CALL DropExistingConstraints('connectmethodmap', 'OStypeid');
CALL DropExistingConstraints('connectmethodmap', 'OSid');
CALL DropExistingConstraints('connectmethodmap', 'imagerevisionid');

CALL AddConstraintIfNotExists('connectmethodmap', 'connectmethodid', 'connectmethod', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('connectmethodmap', 'OStypeid', 'OStype', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('connectmethodmap', 'OSid', 'OS', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('connectmethodmap', 'imagerevisionid', 'imagerevision', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `connectmethodport`
--

CALL AddConstraintIfNotExists('connectmethodport', 'connectmethodid', 'connectmethod', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `continuations`
--

CALL AddConstraintIfNotExists('continuations', 'userid', 'user', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `image`
--

CALL DropExistingConstraints('image', 'ownerid');

CALL AddConstraintIfNotExists('image', 'ownerid', 'user', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('image', 'imagetypeid', 'imagetype', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('image', 'imagemetaid', 'imagemeta', 'id', 'both', 'nullCASCADE');
UPDATE image SET basedoffrevisionid = NULL WHERE basedoffrevisionid NOT IN (SELECT id FROM imagerevision);
CALL AddConstraintIfNotExists('image', 'basedoffrevisionid', 'imagerevision', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `imagerevision`
--

CALL DropExistingConstraints('imagerevision', 'imageid');

CALL AddConstraintIfNotExists('imagerevision', 'imageid', 'image', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `imagerevisioninfo`
--

CALL DropExistingConstraints('imagerevisioninfo', 'imagerevisionid');

CALL AddConstraintIfNotExists('imagerevisioninfo', 'imagerevisionid', 'imagerevision', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `localauth`
--

CALL DropExistingConstraints('localauth', 'userid');

CALL AddConstraintIfNotExists('localauth', 'userid', 'user', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `log`
--

CALL DropExistingConstraints('log', 'imageid');
CALL DropExistingConstraints('log', 'computerid');

CALL AddConstraintIfNotExists('log', 'imageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('log', 'computerid', 'computer', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `loginlog`
--

CALL AddConstraintIfNotExists('loginlog', 'affiliationid', 'affiliation', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `managementnode`
--

CALL DropExistingConstraints('managementnode', 'imagelibgroupid');

CALL AddConstraintIfNotExists('managementnode', 'imagelibgroupid', 'resourcegroup', 'id', 'both', 'nullCASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `nathost`
--

CALL DropExistingConstraints('nathost', 'resourceid');

CALL AddConstraintIfNotExists('nathost', 'resourceid', 'resource', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `nathostcomputermap`
--

CALL DropExistingConstraints('nathostcomputermap', 'computerid');

CALL AddConstraintIfNotExists('nathostcomputermap', 'nathostid', 'nathost', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('nathostcomputermap', 'computerid', 'computer', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `natlog`
--

CALL DropExistingConstraints('natlog', 'sublogid');

CALL AddConstraintIfNotExists('natlog', 'sublogid', 'sublog', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('natlog', 'nathostresourceid', 'resource', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `natport`
--

CALL DropExistingConstraints('natport', 'connectmethodportid');
CALL DropExistingConstraints('natport', 'reservationid');
CALL DropExistingConstraints('natport', 'nathostid');

CALL AddConstraintIfNotExists('natport', 'connectmethodportid', 'connectmethodport', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('natport', 'reservationid', 'reservation', 'id', 'delete', 'CASCADE');
CALL AddConstraintIfNotExists('natport', 'nathostid', 'nathost', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `openstackcomputermap`
--

CALL DropExistingConstraints('openstackcomputermap', 'computerid');

CALL AddConstraintIfNotExists('openstackcomputermap', 'computerid', 'computer', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `openstackimagerevision`
--

CALL DropExistingConstraints('openstackimagerevision', 'imagerevisionid');

CALL AddConstraintIfNotExists('openstackimagerevision', 'imagerevisionid', 'imagerevision', 'id', 'update', 'CASCADE');
  
-- --------------------------------------------------------

--
-- Constraints for table `provisioningOSinstalltype`
--

CALL DropExistingConstraints('provisioningOSinstalltype', 'provisioningid');
CALL DropExistingConstraints('provisioningOSinstalltype', 'OSinstalltypeid');
 
CALL AddConstraintIfNotExists('provisioningOSinstalltype', 'provisioningid', 'provisioning', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('provisioningOSinstalltype', 'OSinstalltypeid', 'OSinstalltype', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `querylog`
--

CALL DropExistingConstraints('querylog', 'userid');

CALL AddConstraintIfNotExists('querylog', 'userid', 'user', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `request`
--

CALL DropExistingConstraints('request', 'userid');

CALL AddConstraintIfNotExists('request', 'userid', 'user', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('request', 'logid', 'log', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `reservation`
--

CALL DropExistingConstraints('reservation', 'computerid');
CALL DropExistingConstraints('reservation', 'imageid');

CALL AddConstraintIfNotExists('reservation', 'computerid', 'computer', 'id', 'none', '');
CALL AddConstraintIfNotExists('reservation', 'imageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('reservation', 'imagerevisionid', 'imagerevision', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `reservationaccounts`
--

CALL DropExistingConstraints('reservationaccounts', 'reservationid');
CALL DropExistingConstraints('reservationaccounts', 'userid');

CALL AddConstraintIfNotExists('reservationaccounts', 'reservationid', 'reservation', 'id', 'delete', 'CASCADE');
CALL AddConstraintIfNotExists('reservationaccounts', 'userid', 'user', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `resourcemap`
--

CALL DropExistingConstraints('resourcemap', 'resourcegroupid1');
CALL DropExistingConstraints('resourcemap', 'resourcegroupid2');
CALL DropExistingConstraints('resourcemap', 'resourcetypeid1');
CALL DropExistingConstraints('resourcemap', 'resourcetypeid2');

CALL AddConstraintIfNotExists('resourcemap', 'resourcegroupid1', 'resourcegroup', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('resourcemap', 'resourcegroupid2', 'resourcegroup', 'id', 'both', 'CASCADE');
CALL AddConstraintIfNotExists('resourcemap', 'resourcetypeid1', 'resourcetype', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('resourcemap', 'resourcetypeid2', 'resourcetype', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `scheduletimes`
--

CALL DropExistingConstraints('scheduletimes', 'scheduleid');

CALL AddConstraintIfNotExists('scheduletimes', 'scheduleid', 'schedule', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `semaphore`
--

CALL DropExistingConstraints('semaphore', 'computerid');
CALL DropExistingConstraints('semaphore', 'imageid');
CALL DropExistingConstraints('semaphore', 'imagerevisionid');
CALL DropExistingConstraints('semaphore', 'managementnodeid');

CALL AddConstraintIfNotExists('semaphore', 'computerid', 'computer', 'id', 'none', '');
CALL AddConstraintIfNotExists('semaphore', 'imageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('semaphore', 'imagerevisionid', 'imagerevision', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('semaphore', 'managementnodeid', 'managementnode', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `serverprofile`
--

CALL DropExistingConstraints('serverprofile', 'ownerid');
CALL DropExistingConstraints('serverprofile', 'admingroupid');
CALL DropExistingConstraints('serverprofile', 'logingroupid');

CALL AddConstraintIfNotExists('serverprofile', 'ownerid', 'user', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('serverprofile', 'admingroupid', 'usergroup', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('serverprofile', 'logingroupid', 'usergroup', 'id', 'update', 'CASCADE');
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
-- Constraints for table `shibauth`
--

CALL DropExistingConstraints('shibauth', 'userid');

CALL AddConstraintIfNotExists('shibauth', 'userid', 'user', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `statgraphcache`
--

CALL DropExistingConstraints('statgraphcache', 'affiliationid');
CALL DropExistingConstraints('statgraphcache', 'provisioningid');

CALL AddConstraintIfNotExists('statgraphcache', 'affiliationid', 'affiliation', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('statgraphcache', 'provisioningid', 'provisioning', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `subimages`
--

CALL DropExistingConstraints('subimages', 'imageid');
CALL DropExistingConstraints('subimages', 'imagemetaid');

CALL AddConstraintIfNotExists('subimages', 'imageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('subimages', 'imagemetaid', 'imagemeta', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `sublog`
--

CALL DropExistingConstraints('sublog', 'logid');
CALL DropExistingConstraints('sublog', 'blockRequestid');
CALL DropExistingConstraints('sublog', 'imageid');
CALL DropExistingConstraints('sublog', 'imagerevisionid');
CALL DropExistingConstraints('sublog', 'computerid');
CALL DropExistingConstraints('sublog', 'managementnodeid');
CALL DropExistingConstraints('sublog', 'predictivemoduleid');
CALL DropExistingConstraints('sublog', 'hostcomputerid');

CALL AddConstraintIfNotExists('sublog', 'logid', 'log', 'id', 'UPDATE', 'CASCADE');
CALL AddConstraintIfNotExists('sublog', 'imageid', 'image', 'id', 'none', '');
CALL AddConstraintIfNotExists('sublog', 'imagerevisionid', 'imagerevision', 'id', 'UPDATE', 'CASCADE');
CALL AddConstraintIfNotExists('sublog', 'computerid', 'computer', 'id', 'none', '');
CALL AddConstraintIfNotExists('sublog', 'managementnodeid', 'managementnode', 'id', 'none', '');
CALL AddConstraintIfNotExists('sublog', 'predictivemoduleid', 'module', 'id', 'UPDATE', 'CASCADE');
CALL AddConstraintIfNotExists('sublog', 'hostcomputerid', 'computer', 'id', 'none', '');
CALL AddConstraintIfNotExists('sublog', 'blockRequestid', 'blockRequest', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `user`
--

CALL DropExistingConstraints('user', 'affiliationid');
CALL DropExistingConstraints('user', 'IMtypeid');

CALL AddConstraintIfNotExists('user', 'affiliationid', 'affiliation', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('user', 'IMtypeid', 'IMtype', 'id', 'both', 'nullCASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `usergroup`
--

CALL DropExistingConstraints('usergroup', 'ownerid');
CALL DropExistingConstraints('usergroup', 'affiliationid');

CALL AddConstraintIfNotExists('usergroup', 'ownerid', 'user', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('usergroup', 'affiliationid', 'affiliation', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `usergroupmembers`
--

CALL DropExistingConstraints('usergroupmembers', 'userid');

CALL AddConstraintIfNotExists('usergroupmembers', 'userid', 'user', 'id', 'update', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `usergrouppriv`
--

CALL DropExistingConstraints('usergrouppriv', 'userprivtypeid');

CALL AddConstraintIfNotExists('usergrouppriv', 'userprivtypeid', 'usergroupprivtype', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('usergrouppriv', 'usergroupid', 'usergroup', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

-- 
-- Constraints for table `userpriv`
--

CALL DropExistingConstraints('userpriv', 'userid');
CALL DropExistingConstraints('userpriv', 'userprivtypeid');

CALL AddConstraintIfNotExists('userpriv', 'userid', 'user', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('userpriv', 'userprivtypeid', 'userprivtype', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('userpriv', 'usergroupid', 'usergroup', 'id', 'both', 'CASCADE');

-- --------------------------------------------------------

--
-- Constraints for table `vmhost`
--

CALL DropExistingConstraints('vmhost', 'computerid');
 
CALL AddConstraintIfNotExists('vmhost', 'vmprofileid', 'vmprofile', 'id', 'update', 'CASCADE');
CALL AddConstraintIfNotExists('vmhost', 'computerid', 'computer', 'id', 'none', '');

-- --------------------------------------------------------

--
-- Constraints for table `vmprofile`
--

CALL DropExistingConstraints('vmprofile', 'imageid');

CALL AddConstraintIfNotExists('vmprofile', 'imageid', 'image', 'id', 'none', '');
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
WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::vmware')
AND computer.provisioningid = provisioning.id;

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
WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::vmware')
AND statgraphcache.provisioningid = provisioning.id;

DELETE FROM provisioningOSinstalltype WHERE provisioningOSinstalltype.provisioningid IN (SELECT provisioning.id FROM provisioning, module WHERE provisioning.moduleid = module.id AND module.perlpackage = 'VCL::Module::Provisioning::vmware');

DELETE FROM provisioning WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::vmware');

DELETE FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::vmware';

--
-- Remove references to legacy xCAT2 provisioning module
--

UPDATE IGNORE computer, provisioning SET
computer.provisioningid = (
  SELECT DISTINCT
  MIN(provisioning.id)
  FROM
  provisioning,
  module
  WHERE
  provisioning.moduleid = (SELECT MIN(module.id) FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT')
)
WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT2')
AND computer.provisioningid = provisioning.id;

UPDATE IGNORE statgraphcache, provisioning SET
statgraphcache.provisioningid = (
  SELECT DISTINCT
  MIN(provisioning.id)
  FROM
  provisioning,
  module
  WHERE
  provisioning.moduleid = (SELECT MIN(module.id) FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT')
)
WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT2')
AND statgraphcache.provisioningid = provisioning.id;

DELETE FROM provisioningOSinstalltype WHERE provisioningOSinstalltype.provisioningid IN (SELECT provisioning.id FROM provisioning, module WHERE provisioning.moduleid = module.id AND module.perlpackage = 'VCL::Module::Provisioning::xCAT2');

DELETE FROM provisioning WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT2');

DELETE FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT2';

--
-- Remove references to legacy xCAT21 provisioning module
--

UPDATE IGNORE computer, provisioning SET
computer.provisioningid = (
  SELECT DISTINCT
  MIN(provisioning.id)
  FROM
  provisioning,
  module
  WHERE
  provisioning.moduleid = (SELECT MIN(module.id) FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT')
)
WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT21')
AND computer.provisioningid = provisioning.id;

UPDATE IGNORE statgraphcache, provisioning SET
statgraphcache.provisioningid = (
  SELECT DISTINCT
  MIN(provisioning.id)
  FROM
  provisioning,
  module
  WHERE
  provisioning.moduleid = (SELECT MIN(module.id) FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT')
)
WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT21')
AND statgraphcache.provisioningid = provisioning.id;

DELETE FROM provisioningOSinstalltype WHERE provisioningOSinstalltype.provisioningid IN (SELECT provisioning.id FROM provisioning, module WHERE provisioning.moduleid = module.id AND module.perlpackage = 'VCL::Module::Provisioning::xCAT21');

DELETE FROM provisioning WHERE provisioning.moduleid IN (SELECT module.id FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT21');

DELETE FROM module WHERE module.perlpackage = 'VCL::Module::Provisioning::xCAT21';

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
