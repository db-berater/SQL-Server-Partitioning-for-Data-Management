/*============================================================================
	File:		0040 - 01 - Piecemeal-Restore.sql

	Summary:	This script demonstrates the benefits of partitioning for VLDB systems

	Simulation:	A large company's administrator must re-create indexes and statistics
				from a 4TB database every night. The time window is limited and a way
				must be found to limit maintenance to the time window.
				Furthermore the SLA determines a downtime for “hot” data for max 60 Minutes!


				THIS SCRIPT IS PART OF THE TRACK:
				"Database Partitioning"

	Date:		May 2020

	SQL Server Version: 2012 / 2014 / 2016 / 2017 / 2019
------------------------------------------------------------------------------
	Written by Uwe Ricken, db Berater GmbH

	This script is intended only as a supplement to demos and lectures
	given by Uwe Ricken.  
  
	THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
	TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.
============================================================================*/
USE master;
GO

EXEC dbo.sp_create_demo_db;
GO

USE demo_db;
GO

-- Create a demo table in the database with 20 partitions.
SELECT * INTO demo_db.dbo.CustomerOrders
FROM CustomerOrders.dbo.CustomerOrders;
GO

-- Create the partition function for the partitioning
CREATE PARTITION FUNCTION pf_OrderDate(DATE)
AS RANGE LEFT FOR VALUES
(
	'2000-12-31', '2001-12-31', '2002-12-31', '2003-12-31', '20041231',
	'20051231', '20061231', '20071231', '20081231', '20091231',
	'20101231', '20111231', '20121231', '20131231', '20141231',
	'20151231', '20161231', '20171231', '20181231', '20191231'
);
GO

-- Create additional filegroups for the partitioned database
DECLARE	@DataPath	NVARCHAR(256) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(256));

DECLARE	@stmt	NVARCHAR(1024);
DECLARE	@Year	INT	=	2000;
WHILE @Year <= 2019
BEGIN
	SET	@stmt = N'ALTER DATABASE demo_db ADD FileGroup ' + QUOTENAME(N'P_' + CAST(@Year AS NCHAR(4))) + N';';
	RAISERROR ('Statement: %s', 0, 1, @stmt);
	EXEC sys.sp_executeSQL @stmt;

	SET @stmt = N'ALTER DATABASE demo_db
ADD FILE
(
	NAME = ' + QUOTENAME(N'Orders_' + CAST(@Year AS NCHAR(4)), '''') + N',
	FILENAME = ''' + @DataPath + N'ORDERS_' + CAST(@Year AS NCHAR(4)) + N'.ndf'',
	SIZE = 128MB,
	FILEGROWTH = 128MB
)
TO FILEGROUP ' + QUOTENAME(N'P_' + CAST(@Year AS NCHAR(4))) + N';';
	RAISERROR ('Statement: %s', 0, 1, @stmt);
	EXEC sys.sp_executeSQL @stmt;

	SET	@Year += 1;
END
GO

-- Create the partition schema to bound the function to the filegroups
CREATE PARTITION SCHEME [OrderDates]
AS PARTITION pf_OrderDate
TO
(
	[P_2000], [P_2001], [P_2002], [P_2003], [P_2004],
	[P_2005], [P_2006], [P_2007], [P_2008], [P_2009],
	[P_2010], [P_2011], [P_2012], [P_2013], [P_2014],
	[P_2015], [P_2016], [P_2017], [P_2018], [P_2019]
	,[PRIMARY]
)
GO

-- Move the table into the partitioned filegroups
CREATE UNIQUE CLUSTERED INDEX cix_CustomerOrders_OrderDate
ON dbo.CustomerOrders (Id, OrderDate)
ON OrderDates(OrderDate)
GO

SELECT * FROM master.dbo.view_PartitionInformation;
GO

-- Filegroups 2000 - 2018 will be marked as READ_ONLY
ALTER DATABASE demo_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

DECLARE @I INT = 2000;
DECLARE @stmt NVARCHAR(2000);
WHILE @I < 2018
BEGIN
	SET @stmt = N'ALTER DATABASE [demo_db] MODIFY FILEGROUP P_' + CAST(@I AS NVARCHAR(4)) + N' READONLY;';
	EXEC sp_executesql @stmt;
	SET @I += 1;
END
GO

ALTER DATABASE demo_db SET MULTI_USER;
GO

SELECT	name,
		data_space_id,
		type,
		CASE WHEN is_read_only = 1
			 THEN 'read-only'
			 ELSE 'read-write'
		END		AS	[status]
FROM	demo_db.sys.filegroups;
GO

-- Backup the database before we drop it
BACKUP DATABASE demo_db 
TO DISK = N'S:\Backup\demo_db_partitioned_full.bak'
WITH STATS, INIT, FORMAT, COMPRESSION;
GO

USE master;
GO

DROP DATABASE demo_db;
GO

-- How long will it take to bring the database online again?
SET STATISTICS TIME ON;
GO

RESTORE DATABASE demo_db
FROM DISK = N'S:\Backup\demo_db_partitioned_full.bak'
WITH
	RECOVERY;
GO

-- To make the most important filegroup available we have to restore PRIMARY 
-- and ALL readably Filgroups first!
RESTORE DATABASE demo_db READ_WRITE_FILEGROUPS
FROM DISK = N'S:\Backup\demo_db_partitioned_full.bak'
WITH
	PARTIAL,
	RECOVERY;
GO

SELECT file_id,
       type,
       type_desc,
       data_space_id,
       name,
       physical_name,
       state_desc,
       is_read_only,
       is_sparse,
       backup_lsn
FROM demo_db.sys.database_files;
GO

-- Work!
SELECT	Id,
        Customer_Id,
        OrderNumber,
        InvoiceNumber,
        OrderDate,
        OrderStatus_Id,
        Employee_Id,
        InsertUser,
        InsertDate
FROM	demo_db.dbo.CustomerOrders
WHERE	OrderDate >= '20190101'
		AND OrderDate < '20190201';
GO

SELECT	Id,
        Customer_Id,
        OrderNumber,
        InvoiceNumber,
        OrderDate,
        OrderStatus_Id,
        Employee_Id,
        InsertUser,
        InsertDate
FROM	demo_db.dbo.CustomerOrders
WHERE	Customer_Id = 10;
GO

-- Will not work if you do not cover the partition boundaries!
UPDATE	demo_db.dbo.CustomerOrders
SET		OrderNumber = 'ABCDE'
WHERE	
		OrderDate >= '20190101'
		AND OrderDate < '20190201'
		AND Id = 1000010;
GO

-- Now we can restore all other Filegroups
DECLARE @I INT = 2000;
DECLARE @stmt NVARCHAR(4000) = N'RESTORE DATABASE demo_db
FILEGROUP = N''P_' + CAST(@I AS NCHAR(4)) + N'''
FROM DISK = N''S:\Backup\demo_db_partitioned_full.bak''
WITH RECOVERY;'

WHILE @I <= 2017
BEGIN
	--PRINT @stmt;
	EXEC sp_executesql @stmt;
	SET @I += 1;
	SET @stmt = N'RESTORE DATABASE demo_db
FILEGROUP = N''P_' + CAST(@I AS NCHAR(4)) + N'''
FROM DISK = N''S:\Backup\demo_db_partitioned_full.bak''
WITH
	RECOVERY;';
END;
GO

SELECT file_id,
       type,
       type_desc,
       data_space_id,
       name,
       physical_name,
       state_desc,
       is_read_only,
       is_sparse,
       backup_lsn
FROM demo_db.sys.database_files;
GO

/*
	Lösche Daten aus 2000!
*/
ALTER DATABASE [demo_db] MODIFY FILEGROUP P_2000 READWRITE;
ALTER DATABASE [demo_db] MODIFY FILEGROUP P_2001 READWRITE;

BEGIN TRANSACTION
GO
	DELETE	dbo.CustomerOrders
	WHERE	OrderDate <= '2000-12-31';

	SELECT * FROM sys.dm_tran_locks
	WHERE	request_session_id = @@SPID;

	SELECT * FROM sys.dm_tran_database_transactions
	WHERE	database_id = DB_ID();
ROLLBACK

BEGIN TRANSACTION
GO
	TRUNCATE TABLE dbo.CustomerOrders WITH (PARTITIONS (1));
	SELECT * FROM sys.dm_tran_locks
	WHERE	request_session_id = @@SPID;

	SELECT * FROM sys.dm_tran_database_transactions
	WHERE	database_id = DB_ID();

	ALTER PARTITION FUNCTION pf_OrderDate()
	MERGE RANGE ('2000-12-31');
COMMIT;
GO

ALTER DATABASE [demo_db]  REMOVE FILE [Orders_2000]
ALTER DATABASE [demo_db] REMOVE FILEGROUP [P_2000]

ALTER DATABASE [demo_db] MODIFY FILEGROUP P_2001 READONLY;
GO  
ROLLBACK