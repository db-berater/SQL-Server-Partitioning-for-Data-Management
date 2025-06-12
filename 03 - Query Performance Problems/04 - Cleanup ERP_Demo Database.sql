/*
	============================================================================
	File:		04 - cleanup ERP_Demo database.sql

	Summary:	This script removes all partitioning elements from the
				demo database ERP_Demo!

	Simulation:	High transactional production environment
				The customer is a pharmaceutical company that produces drugs on
				various (16) production lines.
				Every drug has to go through a QA check that stores the data in
				the SQL Server.

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Partitioning for Data Management

	Date:		May 2025

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE ERP_Demo;
GO

/* Remove the demo.orders table */
DROP TABLE IF EXISTS demo.orders;
GO

/* Remove existing partition environment */
IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = N'ps_o_orderdate')
	DROP PARTITION SCHEME ps_o_orderdate;
GO

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_o_orderdate')
	DROP PARTITION FUNCTION pf_o_orderdate;
GO

DROP SCHEMA IF EXISTS demo;