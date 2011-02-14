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

-- Apache VCL version 2.2 to 2.2.1 database schema changes

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
    SELECT * FROM information_schema.STATISTICS WHERE
    TABLE_SCHEMA=Database()
    AND TABLE_NAME=tableName
    AND COLUMN_NAME=columnName
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
-- Create for table `provisioningOSinstalltype`
-- 

CREATE TABLE IF NOT EXISTS `provisioningOSinstalltype` (
  `provisioningid` smallint(5) unsigned NOT NULL,
  `OSinstalltypeid` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY  (`provisioningid`,`OSinstalltypeid`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

-- 
-- Inserts for table `module`
-- 

INSERT IGNORE INTO `module` (`name`, `prettyname`, `description`, `perlpackage`) VALUES ('provisioning_vbox', 'Virtual Box Provisioning Module', '', 'VCL::Module::Provisioning::vbox');

-- --------------------------------------------------------

--
-- Inserts for table `provisioning`
--

INSERT IGNORE INTO `provisioning` (`name`, `prettyname`, `moduleid`) VALUES ('vbox', 'Virtual Box', (SELECT `id` FROM `module` WHERE `name` LIKE 'provisioning_vbox'));

-- --------------------------------------------------------

--
-- Inserts for table `OSinstalltype`
--

INSERT IGNORE INTO `OSinstalltype` (`name`) VALUES ('vbox');

-- --------------------------------------------------------
-- --------------------------------------------------------

-- 
-- Inserts for table `provisioningOSinstalltype`
-- 

INSERT IGNORE INTO `provisioningOSinstalltype` (`provisioningid`, `OSinstalltypeid`) VALUES 
((SELECT `id` FROM `provisioning` WHERE `name` LIKE 'vbox' ), (SELECT `id` FROM `OSinstalltype` WHERE `name` LIKE 'vbox'`));

-- --------------------------------------------------------
--
-- Remove Procedures
--

DROP PROCEDURE IF EXISTS `AddColumnIfNotExists`;
DROP PROCEDURE IF EXISTS `DropColumnIfExists`;
DROP PROCEDURE IF EXISTS `AddIndexIfNotExists`;
DROP PROCEDURE IF EXISTS `AddConstraintIfNotExists`;
