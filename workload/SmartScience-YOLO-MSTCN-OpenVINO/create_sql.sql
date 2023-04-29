CREATE DATABASE IF NOT EXISTS smartlab;

USE smartlab;

CREATE TABLE IF NOT EXISTS `exp_score` (
	`exp_id` VARCHAR(128) NOT NULL,
	`initial_score_rider` CHAR(1) NOT NULL,
	`initial_score_balance` CHAR(1) NOT NULL,
	`measuring_score_rider_tweezers` CHAR(1) NOT NULL,
	`measuring_score_balance` CHAR(1) NOT NULL,
	`measuring_score_object_left` CHAR(1) NOT NULL,
	`measuring_score_weights_right` CHAR(1) NOT NULL,
	`measuring_score_weights_tweezers` CHAR(1) NOT NULL,
	`measuring_score_weights_order` CHAR(1) NOT NULL,
	`end_score_tidy` CHAR(1) NOT NULL,
	PRIMARY KEY (`exp_id`)
);
