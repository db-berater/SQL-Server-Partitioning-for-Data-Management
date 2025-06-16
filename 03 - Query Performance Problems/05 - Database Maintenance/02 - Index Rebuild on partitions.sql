/*============================================================================
	File:		0040 - 02 - Index Rebuild on partitions.sql

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
CREATE TABLE dbo.CustomerOrders
(
	Id				UNIQUEIDENTIFIER NOT NULL DEFAULT (NEWID()),
	Customer_Id		INT NOT NULL,
	OrderNumber		CHAR(10) NOT NULL,
	InvoiceNumber	CHAR(10) NOT NULL,
	OrderDate		DATE NOT NULL,
	OrderStatus_Id	INT NOT NULL,
	Employee_Id		INT NOT NULL,
	InsertUser		NVARCHAR(128) NOT NULL,
	InsertDate		DATETIME NOT NULL
)
WITH (DATA_COMPRESSION = PAGE);
GO

INSERT INTO dbo.CustomerOrders WITH (TABLOCK)
(Customer_Id, OrderNumber, InvoiceNumber, OrderDate, OrderStatus_Id, Employee_Id, InsertUser, InsertDate)
SELECT	Customer_Id,
		OrderNumber,
		InvoiceNumber,
		OrderDate,
		OrderStatus_Id,
		Employee_Id,
		InsertUser,
		InsertDate
FROM	CustomerOrders.dbo.CustomerOrders;
GO

-- Create the partition function for the partitioning
CREATE PARTITION FUNCTION pf_OrderDate(DATE)
AS RANGE LEFT FOR VALUES
(
	'20001231', '20011231', '20021231', '20031231', '20041231',
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
WITH (DATA_COMPRESSION = PAGE)
ON OrderDates(OrderDate)
GO

-- Let's have a look to the indexes physical status
SELECT	partition_number,
        avg_fragmentation_in_percent,
        page_count,
        avg_page_space_used_in_percent,
        record_count
FROM	sys.dm_db_index_physical_stats
		(
			DB_ID(),
			OBJECT_ID(N'dbo.CustomerOrders', N'U'),
			1,
			NULL,
			N'DETAILED'
		)
WHERE	index_level = 0;
GO

-- Year 2019 is over and 2020 is starting right now.
-- we have to create a new file group and must change the parttion function
-- This job is running EVERY end of year before the new year starts
-- Add a new filegroup for the new data
ALTER DATABASE demo_db
ADD FILEGROUP [P_2020];
GO

-- Add a new file for the new data for the new filegroup
ALTER DATABASE demo_db
ADD FILE
(
	NAME = N'Orders_2020',
	FILENAME = N'F:\MSSQL15.SQL_2019\MSSQL\DATA\ORDERS_2020.ndf',
	SIZE = 128MB,
	FILEGROWTH = 128MB
)
TO FILEGROUP [P_2020];
GO

-- Alter the partition schema and add the new filegroup as USED NEXT
ALTER PARTITION SCHEME OrderDates NEXT USED [P_2020];
GO

-- Alter the partition function and add the new boundery value
ALTER PARTITION FUNCTION pf_OrderDate() SPLIT RANGE ('20201231');
GO

-- Let's have a look to the indexes physical status
SELECT	partition_number,
        avg_fragmentation_in_percent,
        page_count,
        avg_page_space_used_in_percent,
        record_count
FROM	sys.dm_db_index_physical_stats
		(
			DB_ID(),
			OBJECT_ID(N'dbo.CustomerOrders', N'U'),
			1,
			NULL,
			N'DETAILED'
		)
WHERE	index_level = 0;
GO

INSERT INTO dbo.CustomerOrders
(
	Customer_Id,
	OrderNumber,
	InvoiceNumber,
	OrderDate,
	OrderStatus_Id,
	Employee_Id,
	InsertUser,
	InsertDate
)
SELECT	Customer_Id,
		OrderNumber,
		InvoiceNumber,
		DATEADD(YEAR, 1, OrderDate),
		OrderStatus_Id,
		Employee_Id,
		InsertUser,
		InsertDate
FROM	CustomerOrders.dbo.CustomerOrders
WHERE	OrderDate >= '20190101'
		AND OrderDate < '20190201';
GO

SELECT	partition_number,
        avg_fragmentation_in_percent,
        page_count,
        avg_page_space_used_in_percent,
        record_count
FROM	sys.dm_db_index_physical_stats
		(
			DB_ID(),
			OBJECT_ID(N'dbo.CustomerOrders', N'U'),
			1,
			NULL,
			N'DETAILED'
		)
WHERE	index_level = 0
ORDER BY
		partition_number DESC;
GO

-- See how long it takes to rebuild the index
SET STATISTICS IO, TIME ON;
GO

BEGIN TRANSACTION;
GO
	ALTER INDEX cix_CustomerOrders_OrderDate ON dbo.CustomerOrders REBUILD;
	GO

	SELECT * FROM master.dbo.DatabaseLocks(N'demo_db')
	WHERE	resource_type IN (N'OBJECT', N'HOBT');
	GO
COMMIT TRANSACTION;
GO

-- Now we do it again for the next x month
DECLARE @month INT = 1;
WHILE @month <= 6
BEGIN
	INSERT INTO dbo.CustomerOrders
	(
		Customer_Id,
		OrderNumber,
		InvoiceNumber,
		OrderDate,
		OrderStatus_Id,
		Employee_Id,
		InsertUser,
		InsertDate
	)
	SELECT	Customer_Id,
			OrderNumber,
			InvoiceNumber,
			DATEADD(YEAR, 1, OrderDate),
			OrderStatus_Id,
			Employee_Id,
			InsertUser,
			InsertDate
	FROM	CustomerOrders.dbo.CustomerOrders
	WHERE	OrderDate >= DATEADD(MONTH, @month, '20190101')
			AND OrderDate < DATEADD(MONTH, @month, '20190201');

	SET @month += 1;
END
GO

SELECT	partition_number,
        avg_fragmentation_in_percent,
        page_count,
        avg_page_space_used_in_percent,
        record_count
FROM	sys.dm_db_index_physical_stats
		(
			DB_ID(),
			OBJECT_ID(N'dbo.CustomerOrders', N'U'),
			1,
			NULL,
			N'DETAILED'
		)
WHERE	index_level = 0
ORDER BY
		partition_number DESC;
GO

-- Only rebuild the index on the dedicated partition
-- where new data have been inserted
DECLARE @partition_id INT = $PARTITION.pf_OrderDate('20200101');
SELECT @partition_id;

BEGIN TRANSACTION;
	ALTER INDEX cix_CustomerOrders_OrderDate ON dbo.CustomerOrders
	REBUILD PARTITION = @partition_id;
	GO

	SELECT * FROM master.dbo.DatabaseLocks(N'demo_db')
	WHERE	resource_type IN (N'OBJECT', N'HOBT');
	GO

COMMIT TRANSACTION;
GO

SELECT	partition_number,
        index_type_desc,
        alloc_unit_type_desc,
        avg_fragmentation_in_percent,
        fragment_count,
        avg_fragment_size_in_pages,
        page_count,
        avg_page_space_used_in_percent,
        record_count
FROM	sys.dm_db_index_physical_stats
		(
			DB_ID(),
			OBJECT_ID(N'dbo.CustomerOrders', N'U'),
			1,
			NULL,
			N'DETAILED'
		)
WHERE	index_level = 0
ORDER BY
		partition_number DESC;
GO