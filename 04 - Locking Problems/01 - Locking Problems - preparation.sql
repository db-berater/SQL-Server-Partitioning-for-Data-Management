/*
	============================================================================
	File:		01 - locking problems - preparation.sql

	Summary:	This script demonstrates the optimization of heavy workloads
				with partitioning

	Simulation:	The customer is a retail company that loads the key figures
				(product / sales) of all cash registers into the Date Warehouse
				every night so that they can create reliable plans for supplying
				the stores.

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

/* Let's create the tables for the demo(s) */
DROP TABLE IF EXISTS demo.raw_data;
DROP TABLE IF EXISTS demo.sales_figures;
DROP TABLE IF EXISTS demo.raw_data;
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
	BEGIN TRY
		SET	@stmt = N'ALTER DATABASE ERP_Demo ADD FileGroup ' + QUOTENAME(N'warehouse_' + RIGHT('0000' + CAST(@Warehouse_Id AS NVARCHAR(4)), 3)) + N';';
		EXEC sys.sp_executeSQL @stmt;
	END TRY
	BEGIN CATCH
		PRINT 'file group already exists!'
	END CATCH

	BEGIN TRY
		SET @stmt = N'ALTER DATABASE ERP_Demo
	ADD FILE
	(
		NAME = ' + QUOTENAME(N'warehouse_' + RIGHT('000' + CAST(@warehouse_Id AS NVARCHAR(4)), 3), '''') + N',
		FILENAME = ''' + @DataPath + N'warehouse_' + RIGHT('000' + CAST(@warehouse_Id AS NVARCHAR(4)), 3) + N'.ndf'',
		SIZE = 1024MB,
		FILEGROWTH = 1024MB
	)
	TO FILEGROUP ' + QUOTENAME(N'warehouse_' + RIGHT('000' + CAST(@warehouse_Id AS NVARCHAR(4)), 3)) + N';';
		EXEC sys.sp_executeSQL @stmt;
	END TRY
	BEGIN CATCH
		PRINT 'file name already exists'
	END CATCH

	SET	@Warehouse_Id += 1;
END
GO

/*
	Next preparation step is the creation of the partitioning infrastructure
	The infrastructure covers:
	- partition function:	pf_warehouses
	- partition scheme:		ps_warehouses
*/
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_warehouses')
	CREATE PARTITION FUNCTION pf_warehouses (INT)
	AS RANGE LEFT FOR VALUES (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
GO

IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = N'ps_warehouses')
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

/* Let's create the tables for the demo(s) */
DROP TABLE IF EXISTS demo.raw_data;
DROP TABLE IF EXISTS demo.sales_figures;
GO

CREATE TABLE demo.sales_figures
(
	import_date				DATE			NOT NULL,
	warehouse_id			INT				NOT NULL,
	cash_id					INT				NOT NULL,
	article_id				INT				NOT NULL,
	article_name			VARCHAR(128)	NOT NULL,
	article_quantity		INT				NOT NULL	CONSTRAINT df_sales_figures_quantity DEFAULT (0),
	article_sales_volume	MONEY			NOT NULL	CONSTRAINT df_sales_figures_price DEFAULT (0),

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

CREATE TABLE demo.raw_data
(
	import_date			DATE			NOT NULL,
	warehouse_id		INT				NOT NULL,
	cash_id				INT				NOT NULL,
	article_id			INT				NOT NULL,
	article_name		VARCHAR(128)	NOT NULL,
	article_quantity	INT				NOT NULL	CONSTRAINT df_raw_data_quantity DEFAULT (0),
	article_price		MONEY			NOT NULL	CONSTRAINT df_raw_data_price DEFAULT (0)
);
GO

CREATE CLUSTERED INDEX pk_raw_data
ON demo.raw_data
(
	warehouse_id,
	cash_id
)
ON ps_warehouses (warehouse_id);
GO

RAISERROR ('Generating sample data for the staging table', 0, 1) WITH NOWAIT;
INSERT INTO demo.raw_data WITH (TABLOCK)
(import_date, warehouse_id, cash_id, article_id, article_name, article_quantity, article_price)
SELECT	DATEFROMPARTS
		(
			YEAR(GETDATE()),
			MONTH(GETDATE()),
			CASE WHEN DAY(o_orderdate) = 31
				 THEN 30
				 ELSE DAY(o_orderdate)
			END
		)						AS	import_date,
		o.o_custkey % 16 + 1	AS	warehouse_id,
		li.l_suppkey % 5 + 1	AS	cash_id,
		li.l_partkey			AS	article_id,
		p.p_name				AS	article_name,
		li.l_quantity			AS	article_quantity,
		p.p_retailprice			AS	article_price
FROM	dbo.orders		AS o
		INNER JOIN dbo.lineitems AS li
		ON (o.o_orderkey = li.l_orderkey)
		INNER JOIN dbo.parts AS p
		ON (li.l_partkey = p.p_partkey)
WHERE	o_orderdate >= '2020-01-01';
GO

CREATE OR ALTER PROCEDURE dbo.import_datawarehouse
	@warehouse_id	INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE	@start_time	DATETIME2(3) = SYSDATETIME();
	DECLARE	@row_number	BIGINT = 0;
	DECLARE	@end_time	DATETIME2(3);

	INSERT INTO demo.sales_figures
	(import_date, warehouse_id, cash_id, article_id, article_name, article_quantity, article_sales_volume)
	SELECT	import_date,
			warehouse_id,
			cash_id,
			article_id,
			article_name,
			SUM(article_quantity)					AS	article_quantity,
			SUM(article_quantity * article_price)	AS	article_sales_volume
	FROM	demo.raw_data
	WHERE	warehouse_id = @warehouse_id
	GROUP BY
			import_date,
			warehouse_id,
			cash_id,
			article_id,
			article_name
	OPTION	(MAXDOP 1);

	SET	@row_number = @@ROWCOUNT;
	SET	@end_time = SYSDATETIME();

	INSERT INTO dbo.import_log
	(warehouse_id, start_date, end_date, row_number)
	VALUES
	(@warehouse_id, @start_time, @end_time, @row_number);
END
GO

SELECT	warehouse_id,
		COUNT_BIG(*)
FROM	demo.raw_data
GROUP BY
		warehouse_id;