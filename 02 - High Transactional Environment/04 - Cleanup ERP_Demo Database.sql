/*
	============================================================================
	File:		02 - cleanup ERP_Demo database.sql

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

/*
	Before we can remove the filegroups and files we must
	eliminiate the table schema and partition function
*/
DROP PROCEDURE IF EXISTS demo.send_machine_data;
DROP TABLE IF EXISTS demo.machine_protocol;
GO

IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = N'ps_machine_id')
	DROP PARTITION SCHEME ps_machine_id;
GO

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_machine_id')
	DROP PARTITION FUNCTION pf_machine_id;
GO


DECLARE	@filegroup_name			NVARCHAR(128);
DECLARE	@file_name				NVARCHAR(128);
DECLARE	@sql_remove_file		NVARCHAR(1024);
DECLARE	@sql_remove_filegroup	NVARCHAR(1024);

DECLARE	c CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR
	SELECT	fg.name	AS	filegroup_name,
			f.name	AS	file_name
	FROM sys.filegroups AS fg
	LEFT JOIN sys.sysfiles AS f
	ON (fg.data_space_id = f.groupid)
	WHERE fg.name <> N'PRIMARY';

OPEN c;

FETCH NEXT FROM c INTO @filegroup_name, @file_name;
WHILE @@FETCH_STATUS <> -1
BEGIN
	IF @file_name IS NOT NULL
	BEGIN
		SET	@sql_remove_file = N'DBCC SHRINKFILE (' + QUOTENAME(@file_name) + N'EMPTY_FILE'')';
		PRINT @sql_remove_file;
		EXEC sp_executesql @sql_remove_file;

		SET @sql_remove_file = N'ALTER DATABASE ERP_Demo REMOVE FILE ' + QUOTENAME(@file_name) + N';';
		PRINT @sql_remove_file;
		EXEC sp_executesql @sql_remove_file;
	END

	IF @filegroup_name IS NOT NULL
	BEGIN
		SET	@sql_remove_filegroup = N'ALTER DATABASE ERP_Demo REMOVE FILEGROUP ' + QUOTENAME(@filegroup_name) + N';';
		PRINT @sql_remove_filegroup;
		EXEC sp_executesql @sql_remove_filegroup;
	END

	SET	@sql_remove_file = NULL;
	SET @sql_remove_filegroup = NULL;

	FETCH NEXT FROM c INTO @filegroup_name, @file_name;
END

CLOSE c;
DEALLOCATE c;
GO

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = N'01 - High Transactional Workload')
	DROP EVENT SESSION [01 - High Transactional Workload] ON SERVER;
	GO

-- Delete existing trace files from the xevent session...
EXEC sp_configure N'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_configure N'xp_cmdshell', 1;
RECONFIGURE WITH OVERRIDE;
GO

EXEC xp_cmdshell N'DEL T:\TraceFiles\*.* /q', no_output;
GO

DROP TABLE IF EXISTS demo.machine_protocol;
DROP SCHEMA IF EXISTS demo;
GO