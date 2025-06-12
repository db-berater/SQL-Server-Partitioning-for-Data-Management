/*
	============================================================================
	File:		01 - speed up your high transactional workload.sql

	Summary:	This script demonstrates the optimization of heavy workloads
				with partitioning

	Simulation:	High transactional production environment
				The customer is a pharmaceutical company that produces drugs on
				various (20) production lines.
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

IF SCHEMA_ID(N'demo') IS NULL
	EXEC sp_executesql N'CREATE SCHEMA demo AUTHORIZATION dbo;';
	GO

-- Let's create the demo table for the machine protocol
DROP TABLE IF EXISTS demo.machine_protocol;
GO

CREATE TABLE demo.machine_protocol
(
	machine_id	SMALLINT		NOT NULL,
	d1			DATETIME2(7)	NOT NULL	CONSTRAINT df_machine_protocol_d1 DEFAULT (SYSDATETIME()),
	c1			CHAR(1024)		NOT NULL	CONSTRAINT df_machine_protocol_c1 DEFAULT ('Only text'),

	CONSTRAINT pk_machine_protocol PRIMARY KEY CLUSTERED
	(
		machine_id,
		d1
	)
);
GO

-- Create a stored proc for simulating the workload
CREATE OR ALTER PROCEDURE demo.send_machine_data
	@machine_id SMALLINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	INSERT INTO demo.machine_protocol
	(machine_id, c1)
	VALUES
	(@machine_id, 'For infomation only');
END
GO