DROP TABLE IF EXISTS `hopsworks`.`featurestore_statistic`;

CREATE TABLE `feature_store_statistic` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `commit_time` VARCHAR(20) COLLATE latin1_general_cs NOT NULL,
  `inode_pid` BIGINT(20) NOT NULL,
  `inode_name` VARCHAR(255) COLLATE latin1_general_cs NOT NULL,
  `partition_id` BIGINT(20) NOT NULL,
  `feature_group_id` INT(11),
  `training_dataset_id`INT(11),
  PRIMARY KEY (`id`),
  KEY `feature_group_id` (`feature_group_id`),
  KEY `training_dataset_id` (`training_dataset_id`),
  CONSTRAINT `fg_fk_fss` FOREIGN KEY (`feature_group_id`) REFERENCES `feature_group` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `td_fk_fss` FOREIGN KEY (`training_dataset_id`) REFERENCES `training_dataset` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `inode_fk` FOREIGN KEY (`inode_pid`,`inode_name`,`partition_id`) REFERENCES `hops`.`hdfs_inodes` (`parent_id`,`name`,`partition_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

ALTER TABLE `hopsworks`.`feature_group` DROP COLUMN `cluster_analysis_enabled`;
ALTER TABLE `hopsworks`.`feature_group` DROP COLUMN `num_clusters`;
ALTER TABLE `hopsworks`.`feature_group` DROP COLUMN `num_bins`;
ALTER TABLE `hopsworks`.`feature_group` DROP COLUMN `corr_method`;

ALTER TABLE `hopsworks`.`feature_store_s3_connector` DROP COLUMN `access_key`;
ALTER TABLE `hopsworks`.`feature_store_s3_connector` DROP COLUMN `secret_key`;

ALTER TABLE `hopsworks`.`feature_store_s3_connector` MODIFY `name` VARCHAR(150) COLLATE latin1_general_cs  NOT NULL;

ALTER TABLE `hopsworks`.`secrets` MODIFY `secret_name` VARCHAR(200) COLLATE latin1_general_cs  NOT NULL;

CREATE TABLE `training_dataset_join` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `training_dataset` int(11) NULL,
  `feature_group` int(11) NULL,
  `type` tinyint(5) NOT NULL DEFAULT 0,
  `idx` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `fg_key` (`feature_group`),
  CONSTRAINT `td_fk_tdj` FOREIGN KEY (`training_dataset`) REFERENCES `training_dataset` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fg_left` FOREIGN KEY (`feature_group`) REFERENCES `feature_group` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

CREATE TABLE `training_dataset_join_condition` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `td_join` int(11) NOT NULL,
  `left_feature` VARCHAR(1000) NOT NULL DEFAULT "",
  `right_feature` VARCHAR(1000) NOT NULL DEFAULT "",
  PRIMARY KEY (`id`),
  KEY `join_key` (`td_join`),
  CONSTRAINT `join_fk_tdjc` FOREIGN KEY (`td_join`) REFERENCES `training_dataset_join` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

RENAME TABLE `hopsworks`.`feature_store_feature` TO `hopsworks`.`on_demand_feature`;

CREATE TABLE `training_dataset_feature` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `training_dataset` int(11) NULL,
  `feature_group` int(11) NULL,
  `name` varchar(1000) COLLATE latin1_general_cs NOT NULL,
  `type` varchar(1000) COLLATE latin1_general_cs,
  `td_join`int(11) NULL,
  `idx` int(11) NULL,
  PRIMARY KEY (`id`),
  KEY `td_key` (`training_dataset`),
  KEY `fg_key` (`feature_group`),
  CONSTRAINT `join_fk_tdf` FOREIGN KEY (`td_join`) REFERENCES `training_dataset_join` (`id`) ON DELETE SET NULL ON UPDATE NO ACTION,
  CONSTRAINT `td_fk_tdf` FOREIGN KEY (`training_dataset`) REFERENCES `training_dataset` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `fg_fk_tdf` FOREIGN KEY (`feature_group`) REFERENCES `feature_group` (`id`) ON DELETE SET NULL ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

INSERT INTO `hopsworks`.`training_dataset_feature`(`training_dataset`, `name`, `type`)
SELECT `training_dataset_id`, `name`, `type` FROM `hopsworks`.`on_demand_feature`
WHERE `training_dataset_id` IS NOT NULL;

DELETE FROM `hopsworks`.`on_demand_feature` WHERE `training_dataset_id` IS NOT NULL;

SET @fk_name = (SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = "hopsworks" AND TABLE_NAME = "on_demand_feature" AND REFERENCED_TABLE_NAME="training_dataset");
SET @s := concat('ALTER TABLE hopsworks.on_demand_feature DROP FOREIGN KEY `', @fk_name, '`');
PREPARE stmt1 FROM @s;
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;

ALTER TABLE `hopsworks`.`on_demand_feature` DROP KEY `training_dataset_id`;
ALTER TABLE `hopsworks`.`on_demand_feature` DROP COLUMN `training_dataset_id`;

ALTER TABLE `hopsworks`.`training_dataset` ADD COLUMN `query` TINYINT(1) NOT NULL DEFAULT '0';

CREATE TABLE `feature_group_commit` (
  `feature_group_id` int(11) NOT NULL,
  `commit_id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `committed_on` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `num_rows_updated` int(11) DEFAULT '0',
  `num_rows_inserted` int(11) DEFAULT '0',
  `num_rows_deleted` int(11) DEFAULT '0',
  `inode_pid`                         BIGINT(20)      NOT NULL,
  `inode_name`                        VARCHAR(255)    NOT NULL,
  `partition_id`                      BIGINT(20)      NOT NULL,
  PRIMARY KEY (`feature_group_id`, `commit_id`),
  KEY `commit_id_idx` (`commit_id`),
  KEY `commit_date_idx` (`committed_on`),
  CONSTRAINT `feature_group_fk` FOREIGN KEY (`feature_group_id`) REFERENCES `feature_group` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `hopsfs_parquet_inode_fk` FOREIGN KEY (`inode_pid`, `inode_name`, `partition_id`) REFERENCES `hops`.`hdfs_inodes` (`parent_id`, `name`, `partition_id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

ALTER TABLE `hopsworks`.`cached_feature_group` ADD COLUMN `timetravel_format` INT NOT NULL DEFAULT 1;

ALTER TABLE `hopsworks`.`training_dataset_join` ADD COLUMN `feature_group_commit_id` BIGINT(20) NULL;

ALTER TABLE `hopsworks`.`python_dep` DROP COLUMN `base_env`;

ALTER TABLE `hopsworks`.`conda_commands` CHANGE `error_message` `error_message` VARCHAR(10000) COLLATE latin1_general_cs DEFAULT NULL;

ALTER TABLE `hopsworks`.`conda_commands` ADD COLUMN `git_api_key_name` VARCHAR(125) DEFAULT NULL;

ALTER TABLE `hopsworks`.`conda_commands` ADD COLUMN `git_backend` VARCHAR(45) DEFAULT NULL;

ALTER TABLE `hopsworks`.`on_demand_feature_group` 
    ADD COLUMN `inode_pid`  BIGINT(20) NOT NULL,
    ADD COLUMN `inode_name` VARCHAR(255) NOT NULL,
    ADD COLUMN `partition_id` BIGINT(20) NOT NULL,
    ADD CONSTRAINT `on_demand_inode_fk` FOREIGN KEY (`inode_pid`, `inode_name`, `partition_id`) REFERENCES `hops`.`hdfs_inodes` (`parent_id`, `name`, `partition_id`) ON DELETE CASCADE ON UPDATE NO ACTION;

SET @fk_name = (SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = "hopsworks" AND TABLE_NAME = "feature_group" AND REFERENCED_TABLE_NAME="hdfs_users");
SET @s := concat('ALTER TABLE hopsworks.feature_group DROP FOREIGN KEY `', @fk_name, '`');
PREPARE stmt1 FROM @s;
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;

ALTER TABLE `hopsworks`.`feature_group` DROP COLUMN `hdfs_user_id`;

/*
The following changes are related to Migration to NDB8
The following changes are implemented using procedures
so that database upgrades do not fail as these changes
might be applied twice. First at the time of manually
migrationg NDB and later by karamel.
*/
DELIMITER $$
/*
    DROP_FOREIGN_KEY_IF_EXISTS
*/

DROP PROCEDURE IF EXISTS DROP_FOREIGN_KEY_IF_EXISTS$$

CREATE PROCEDURE DROP_FOREIGN_KEY_IF_EXISTS(IN tableName VARCHAR(128), IN constraintName VARCHAR(128))
BEGIN
    IF EXISTS(
        SELECT * FROM information_schema.TABLE_CONSTRAINTS
        WHERE
            TABLE_SCHEMA    = DATABASE()     AND
            TABLE_NAME      = tableName      AND
            CONSTRAINT_NAME = constraintName AND
            CONSTRAINT_TYPE = 'FOREIGN KEY')
    THEN
        SET @query = CONCAT('ALTER TABLE ', DATABASE(), ".", tableName, ' DROP FOREIGN KEY ', constraintName);
        PREPARE stmt FROM @query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    ELSE
        SELECT concat('Unable to delete foreign key as it does not exist. Foreign Key: ', constraintName) AS ' ';
    END IF;
END$$

/*
    CREATE_FOREIGN_KEY_IF_NOT_EXISTS
*/
DROP PROCEDURE IF EXISTS CREATE_FOREIGN_KEY_IF_NOT_EXISTS$$

CREATE PROCEDURE CREATE_FOREIGN_KEY_IF_NOT_EXISTS(
    IN tableName VARCHAR(128),
    IN tableColumn VARCHAR(128),
    IN constraintName VARCHAR(128),
    IN constraintTable VARCHAR(128),
    IN contraintColumn VARCHAR(128))
BEGIN
    IF EXISTS(
        SELECT * FROM information_schema.TABLE_CONSTRAINTS
        WHERE
            TABLE_SCHEMA    = DATABASE()     AND
            TABLE_NAME      = tableName      AND
            CONSTRAINT_NAME = constraintName AND
            CONSTRAINT_TYPE = 'FOREIGN KEY')
    THEN
        SELECT concat('Unable to create foreign key as it already exists. Foreign Key: ', constraintName) AS ' ';
    ELSE
        SET @query = CONCAT('ALTER TABLE ', DATABASE(), ".", tableName, ' ADD CONSTRAINT ', constraintName, ' FOREIGN KEY (', tableColumn, ') REFERENCES ', constraintTable, '(', contraintColumn, ') ', '  ON DELETE CASCADE ON UPDATE NO ACTION '  );
        PREPARE stmt FROM @query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$


CALL DROP_FOREIGN_KEY_IF_EXISTS('conda_commands', 'user_fk')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('conda_commands', 'user_id', 'user_fk_conda', 'users', 'uid')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('feature_group', 'on_demand_feature_group_fk')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('feature_group', 'on_demand_feature_group_id', 'on_demand_feature_group_fk2', 'on_demand_feature_group', 'id')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('schemas', 'project_idx')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('schemas', 'project_id', 'project_idx_schemas', 'project', 'id')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('subjects', 'project_idx')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('subjects', 'project_id', 'project_idx_subjects', 'project', 'id')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('subjects_compatibility', 'project_idx')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('subjects_compatibility', 'project_id', 'project_idx_sub_comp', 'project', 'id')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('project_topics', 'project_idx')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('project_topics', 'project_id', 'project_idx_proj_topics', 'project', 'id')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('rstudio_settings', 'FK_262_309')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('rstudio_settings', 'team_member', 'RS_FK_USERS', 'users', 'email')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('rstudio_settings', 'FK_284_308')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('rstudio_settings', 'project_id', 'RS_FK_PROJS', 'project', 'id')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('serving', 'user_fk')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('serving', 'creator', 'user_fk_serving', 'users', 'uid')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('shared_topics', 'topic_idx')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('shared_topics', 'topic_name, owner_id', 'topic_idx_shared', 'project_topics', 'topic_name, project_id')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('topic_acls', 'topic_idx')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('topic_acls', 'topic_name, project_id', 'topic_idx_topic_acls', 'project_topics', 'topic_name, project_id')$$

CALL DROP_FOREIGN_KEY_IF_EXISTS('feature_store_feature', 'on_demand_feature_group_fk')$$
CALL CREATE_FOREIGN_KEY_IF_NOT_EXISTS('feature_store_feature', 'on_demand_feature_group_id', 'on_demand_feature_group_fk1', 'on_demand_feature_group', 'id')$$

DELIMITER ;

ALTER TABLE `hopsworks`.`cached_feature_group` DROP COLUMN `default_storage`;

CREATE TABLE `hopsworks`.`cloud_role_mapping` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `project_id` int(11) NOT NULL,
  `project_role` varchar(32) NOT NULL,
  `cloud_role` varchar(2048) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index3` (`project_id`,`cloud_role`),
  UNIQUE KEY `index4` (`id`,`project_id`,`project_role`),
  KEY `fk_cloud_role_mapping_1_idx` (`project_id`),
  CONSTRAINT `fk_cloud_role_mapping_1`
  FOREIGN KEY (`project_id`)
  REFERENCES `project` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

CREATE TABLE `cloud_role_mapping_default` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mapping_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL,
  `project_role` varchar(32) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index3` (`project_id`,`project_role`),
  UNIQUE KEY `index4` (`mapping_id`,`project_id`,`project_role`),
  KEY `fk_cloud_role_mapping_default_1_idx` (`mapping_id`,`project_id`,`project_role`),
  CONSTRAINT `fk_cloud_role_mapping_default_1`
  FOREIGN KEY (`mapping_id`,`project_id`,`project_role`)
  REFERENCES `cloud_role_mapping` (`id`,`project_id`,`project_role`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

CREATE TABLE `databricks_instance` (
  `id`              INT(11) NOT NULL AUTO_INCREMENT,
  `url`             VARCHAR(255) NOT NULL,
  `uid`             INT(11) NOT NULL,
  `secret_name`     VARCHAR(200) NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY `db_secret_fk` (`uid`, `secret_name`) REFERENCES `secrets` (`uid`, `secret_name`) ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY `db_user_fk` (`uid`) REFERENCES `users` (`uid`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=ndbcluster DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

ALTER TABLE `hopsworks`.`training_dataset_feature` ADD COLUMN `label` TINYINT(1) NOT NULL DEFAULT '0';
