/*============================================================================
	File:		0120 - speed up your data loads into a DWH - preparation.sql

	Summary:	This script demonstrates the optimization of parallel data loads
				into a DWH environment by multiple threads

				This code runs the preparation for the demo and requires
				the database ERP_Demo which can be downloaded here:
				https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK

	Simulation:	The customer is a retail company that loads the key figures
				(product / sales) of all cash registers into the Date Warehouse
				every night so that they can create reliable plans for supplying
				the stores.

				THIS SCRIPT IS PART OF THE TRACK:
				"Partitioning for Data Management Tasks"

	Date:		May 2020
	Review		December 2023

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

/* We create our demo database which holds the objects and data */
EXEC dbo.sp_create_demo_db;
GO

USE demo_db;
GO

/*
	The first preparation covers the implementation of 16 new
	filegroups to hold the data from each warehouse in a dedicated
	filegroup.
*/
DECLARE	@DataPath	NVARCHAR(256) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(256));

DECLARE	@stmt	NVARCHAR(1024);
DECLARE	@warehouse_Id	INT	=	1;
WHILE @warehouse_Id <= 16
BEGIN
	SET	@stmt = N'ALTER DATABASE demo_db ADD FileGroup ' + QUOTENAME(N'warehouse_' + RIGHT('0000' + CAST(@Warehouse_Id AS NVARCHAR(4)), 3)) + N';';
	EXEC sys.sp_executeSQL @stmt;

	SET @stmt = N'ALTER DATABASE demo_db
ADD FILE
(
	NAME = ' + QUOTENAME(N'Warehouse_' + RIGHT('000' + CAST(@warehouse_Id AS NVARCHAR(4)), 3), '''') + N',
	FILENAME = ''' + @DataPath + N'warehouse_' + RIGHT('000' + CAST(@warehouse_Id AS NVARCHAR(4)), 3) + N'.ndf'',
	SIZE = 1024MB,
	FILEGROWTH = 1024MB
)
TO FILEGROUP ' + QUOTENAME(N'warehouse_' + RIGHT('000' + CAST(@warehouse_Id AS NVARCHAR(4)), 3)) + N';';
	EXEC sys.sp_executeSQL @stmt;

	SET	@Warehouse_Id += 1;
END
GO

/*
	Next preparation step is the creation of the partitioning infrastructure
	The infrastructure covers:
	- partition function:	pf_warehouses
	- partition scheme:		ps_warehouses
*/
CREATE PARTITION FUNCTION pf_warehouses (INT)
AS RANGE LEFT FOR VALUES (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
GO

CREATE PARTITION SCHEME ps_warehouses
AS PARTITION pf_warehouses
TO
(
	[warehouse_001], [warehouse_002], [warehouse_003], [warehouse_004],
	[warehouse_005], [warehouse_006], [warehouse_007], [warehouse_008],
	[warehouse_009], [warehouse_010], [warehouse_011], [warehouse_012],
	[warehouse_013], [warehouse_014], [warehouse_015], [warehouse_016],
	[PRIMARY]
);
GO

/*
	Now we can create the target table which holds the final data!

	This table contains the sales figures of all products in cumulative form
	for each warehouse and each cash register for each day.
*/
DROP TABLE IF EXISTS dbo.sales_figures;
GO

CREATE TABLE dbo.sales_figures
(
	import_date				DATE			NOT NULL,
	warehouse_id			INT				NOT NULL,
	cash_id					INT				NOT NULL,
	article_id				INT				NOT NULL,
	article_name			VARCHAR(128)	NOT NULL,
	article_quantity		INT				NOT NULL	CONSTRAINT chk_sales_figures_quantity DEFAULT (0),
	article_sales_volume	MONEY			NOT NULL	CONSTRAINT chk_sales_figures_price DEFAULT (0),

	CONSTRAINT pk_sales_figures PRIMARY KEY CLUSTERED
	(
		import_date,
		warehouse_id,
		cash_id,
		article_id
	)
	ON ps_warehouses (warehouse_id)
);
GO

/*
	For the demo we must have prepared data in a staging area.
	Therefore we create a new table staging.raw_data which is
	partitioned by the warehouse_id
*/
IF SCHEMA_ID(N'staging') IS NULL
	EXEC sys.sp_executesql N'CREATE SCHEMA [staging] AUTHORIZATION dbo;';
GO

DROP TABLE IF EXISTS staging.raw_data
GO

CREATE TABLE staging.raw_data
(
	import_date			DATE			NOT NULL,
	warehouse_id		INT				NOT NULL,
	cash_id				INT				NOT NULL,
	article_id			INT				NOT NULL,
	article_name		VARCHAR(128)	NOT NULL,
	article_quantity	INT				NOT NULL	CONSTRAINT chk_sales_figures_quantity DEFAULT (0),
	article_price		MONEY			NOT NULL	CONSTRAINT chk_sales_figures_price DEFAULT (0)
);
GO

CREATE CLUSTERED INDEX pk_raw_data
ON staging.raw_data
(
	warehouse_id,
	cash_id
)
ON ps_warehouses (warehouse_id);
GO

/*
	The source demo data are coming from ERP_Demo-Database which can be 
	downloaded from here:
	https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK
*/
RAISERROR ('Preparing staging.raw_data...', 0, 1) WITH NOWAIT;
GO
INSERT INTO staging.raw_data WITH (TABLOCK)
(import_date, warehouse_id, cash_id, article_id, article_name, article_quantity, article_price)
SELECT	DATEFROMPARTS
		(
			YEAR(GETDATE()),
			MONTH(GETDATE()),
			DAY(o_orderdate)
		)						AS	import_date,
		o.o_custkey % 16 + 1	AS	warehouse_id,
		li.l_suppkey % 4 + 1	AS	cash_id,
		li.l_partkey			AS	article_id,
		p.p_name				AS	article_name,
		li.l_quantity			AS	article_quantity,
		p.p_retailprice			AS	article_price
FROM	ERP_Demo.dbo.orders		AS o
		INNER JOIN ERP_Demo.dbo.lineitem AS li
		ON (o.o_orderkey = li.l_orderkey)
		INNER JOIN ERP_Demo.dbo.part AS p
		ON (li.l_partkey = p.p_partkey)
WHERE	o_orderdate >= '2019-01-01'
		AND o_orderdate < '2020-01-01';
GO

/*
	For the measurement of each transaction we create a logging table
	This logging table inserts a record with the Id of the warehouse
	and START and FINISH value
*/
DROP TABLE IF EXISTS dbo.import_log;
GO

CREATE TABLE dbo.import_log
(
	warehouse_id	INT				NOT NULL,
	start_date		DATETIME2(3)	NOT NULL	CONSTRAINT df_import_log_start_date DEFAULT (SYSDATETIME()),
	end_date		DATETIME2(3)	NULL,
	row_number		BIGINT			NOT NULL	CONSTRAINT df_import_log_row_number DEFAULT (0),
	duration_ms	AS
	DATEDIFF
	(
		MILLISECOND,
		start_date,
		end_date
	),

	CONSTRAINT pk_import_log PRIMARY KEY CLUSTERED
	(
		warehouse_id,
		start_date
	)
);
GO

/*
	The last required object is a wrapper procedure which 
	uses a parameter for the warehouse and transfer all 
	aggregated information from the staging into the business table
*/
CREATE OR ALTER PROCEDURE dbo.ImportWarehouseData
	@warehouse_id	INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE	@start_time	DATETIME2(3) = SYSDATETIME();
	DECLARE	@row_number	BIGINT = 0;
	DECLARE	@end_time	DATETIME2(3);

	INSERT INTO dbo.sales_figures
	(import_date, warehouse_id, cash_id, article_id, article_name, article_quantity, article_sales_volume)
	SELECT	import_date,
			warehouse_id,
			cash_id,
			article_id,
			article_name,
			SUM(article_quantity)					AS	article_quantity,
			SUM(article_quantity * article_price)	AS	article_sales_volume
	FROM	staging.raw_data
	WHERE	warehouse_id = @warehouse_id
	GROUP BY
			import_date,
			warehouse_id,
			cash_id,
			article_id,
			article_name
	ORDER BY
			cash_id,
			article_id;

	SET	@row_number = @@ROWCOUNT;
	SET	@end_time = SYSDATETIME();

	INSERT INTO dbo.import_log
	(warehouse_id, start_date, end_date, row_number)
	VALUES
	(@warehouse_id, @start_time, @end_time, @row_number);
END
GO

USE master;
GO

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = N'120 - object locks')
BEGIN
	RAISERROR (N'dropping existing extended event session [120 - object locks]...', 0, 1) WITH NOWAIT;
	DROP EVENT SESSION [120 - object locks] ON SERVER;
END
GO

CREATE EVENT SESSION [120 - object locks] ON SERVER 
ADD EVENT sqlserver.lock_acquired
(
	ACTION
	(
		sqlserver.session_id,
		sqlserver.sql_text
	)
	WHERE 
		sqlserver.is_system = 0
		AND object_id > 1000000
		AND sqlserver.database_name = N'ERP_Demo'
		AND resource_type = N'OBJECT'
		AND
		(
			mode = 3		-- S-Lock
			OR mode = 4		-- U-Lock
			OR mode = 5		-- X-Lock
			OR mode = 6		-- IS-Lock
			OR mode = 8		-- IX-Lock
		)
),
ADD EVENT sqlserver.lock_escalation
(
	WHERE	sqlserver.database_name = N'demo_db'
)
WITH
(
	MAX_MEMORY=4096 KB,
	EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
	MAX_DISPATCH_LATENCY=5 SECONDS,
	MAX_EVENT_SIZE=0 KB,
	MEMORY_PARTITION_MODE=NONE,
	TRACK_CAUSALITY=OFF,
	STARTUP_STATE=OFF
);
GO

ALTER EVENT SESSION [120 - object locks] ON SERVER STATE = START;
GO