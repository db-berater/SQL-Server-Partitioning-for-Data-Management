/*============================================================================
	File:		0040 - 03 - Statistic updates on partitions.sql

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

SELECT	Id,
        Customer_Id,
        OrderNumber,
        InvoiceNumber,
        OrderDate,
        OrderStatus_Id,
        Employee_Id,
        InsertUser,
        InsertDate
INTO	dbo.CustomerOrders
FROM	CustomerOrders.dbo.CustomerOrders;
GO

-- Create the partition function for the partitioning
CREATE PARTITION FUNCTION pf_OrderDate(DATE)
AS RANGE LEFT FOR VALUES
(
	'20001231', '20011231', '20021231', '20031231', '20041231',
	'20051231', '20061231', '20071231', '20081231', '20091231',
	'20101231', '20111231', '20121231', '20131231', '20141231',
	'20151231', '20161231', '20171231', '20181231', '20191231',
	'20201231'
);
GO

-- Create additional filegroups for the partitioned database
DECLARE	@DataPath	NVARCHAR(256) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(256));

DECLARE	@stmt	NVARCHAR(1024);
DECLARE	@Year	INT	=	2000;
WHILE @Year <= 2020
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
	[P_2015], [P_2016], [P_2017], [P_2018], [P_2019],
	[P_2020],[PRIMARY]
)
GO

-- Move the table into the partitioned filegroups
CREATE UNIQUE CLUSTERED INDEX cix_CustomerOrders_OrderDate
ON dbo.CustomerOrders (Id, OrderDate)
WITH (DATA_COMPRESSION = PAGE)
ON OrderDates(OrderDate)
GO

-- and we create a nonclustered index on the order date only
CREATE NONCLUSTERED INDEX nix_CustomerOrders_OrderDate
ON dbo.CustomerOrders(OrderDate)
WITH (DATA_COMPRESSION = PAGE)
ON OrderDates(OrderDate)
GO

SELECT	P.index_id,
		P.partition_number,
		P.rows
FROM	sys.partitions AS P
WHERE	P.object_id = OBJECT_ID(N'dbo.CustomerOrders')
		AND P.index_id = 1;
GO

-- Statistics are not automatically incremental!
SELECT	object_id,
		name,
		stats_id,
		is_incremental
FROM	sys.stats
WHERE	object_id = OBJECT_ID(N'dbo.CustomerOrders', N'U');
GO

-- we have to make them incremental by using the option INCREMENTAL!
UPDATE STATISTICS dbo.CustomerOrders nix_CustomerOrders_OrderDate
WITH FULLSCAN, INCREMENTAL = ON;
GO

SELECT	object_id,
		name,
		stats_id,
		is_incremental
FROM	sys.stats
WHERE	object_id = OBJECT_ID(N'dbo.CustomerOrders', N'U');
GO

-- Check the statistics for a specific date
SELECT * FROM dbo.CustomerOrders
WHERE	OrderDate = '2019-07-26';
GO

-- Where does the estimates come from
SELECT	DDSH.object_id,
		DDSH.stats_id,
		DDSH.step_number,
		DDSH.range_high_key,
		DDSH.range_rows,
		DDSH.equal_rows,
		DDSH.distinct_range_rows,
		DDSH.average_range_rows
FROM	sys.stats AS S
		CROSS APPLY sys.dm_db_stats_histogram
		(
			S.object_id,
			S.stats_id
		) AS DDSH
WHERE	S.object_id = OBJECT_ID(N'dbo.CustomerOrders', N'U')
		AND s.name = N'nix_CustomerOrders_OrderDate';
GO

SELECT	OBJECT_NAME(s.object_id) TblName
		, s.stats_id
		, isp.partition_number
		, isp.last_updated
		, isp.rows
		, isp.rows_sampled
		, isp.steps
FROM	sys.stats AS s
		CROSS APPLY sys.dm_db_incremental_stats_properties
		(
			s.object_id,
			s.stats_id
		) AS isp
WHERE	s.object_id = OBJECT_ID(N'dbo.CustomerOrders', N'U')
ORDER BY
		isp.partition_number DESC;
GO

SELECT	object_id
	  , stats_id
	  , last_updated
	  , rows
	  , rows_sampled
	  , steps
	  , unfiltered_rows
	  , modification_counter
	  , node_id
	  , first_child
	  , next_sibling
	  , left_boundary
	  , right_boundary
	  , partition_number
FROM	sys.dm_db_stats_properties_internal
		(
			OBJECT_ID('dbo.CustomerOrders'),
			2
		)
ORDER BY
		node_id;
GO

DBCC TRACEON(2309);
GO
DBCC SHOW_STATISTICS('dbo.CustomerOrders','nix_CustomerOrders_OrderDate', 21);
GO
