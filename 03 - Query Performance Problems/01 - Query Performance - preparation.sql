/*
	============================================================================
	File:		01 - query performance issues.sql

	Summary:	This script demonstrates the optimization of querys when it comes
				to problematic aggregation runtimes

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
BEGIN
	RAISERROR ('Creating schema [demo]', 0, 1) WITH NOWAIT;
	EXEC sp_executesql N'CREATE SCHEMA demo AUTHORIZATION dbo;';
END
GO

-- Let's create the demo table for the machine protocol
RAISERROR ('Creating table [demo].[orders]', 0, 1) WITH NOWAIT;
DROP TABLE IF EXISTS demo.orders;
GO

SELECT * INTO demo.orders FROM dbo.orders WHERE 1 = 0;
GO

/* Remove existing partition environment */
IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = N'ps_o_orderdate')
	DROP PARTITION SCHEME ps_o_orderdate;
GO

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_o_orderdate')
	DROP PARTITION FUNCTION pf_o_orderdate;
GO

/* Now we create the partition function for the last 3 years */
CREATE PARTITION FUNCTION pf_o_orderdate (DATE)
AS RANGE LEFT FOR VALUES
(
	'2019-12-31',
	'2020-12-31',
	'2021-12-31',
	'2022-12-31'
);
GO

/* And a partition scheme for the given partition function */
CREATE PARTITION SCHEME ps_o_orderdate
AS PARTITION pf_o_orderdate
ALL TO ([PRIMARY]);
GO

/* Add the partition scheme to the newly created table */
ALTER TABLE demo.orders
ADD CONSTRAINT pk_demo_orders PRIMARY KEY CLUSTERED
(
	o_orderkey,
	o_orderdate
)
WITH (DATA_COMPRESSION = PAGE)
ON ps_o_orderdate(o_orderdate);
GO

/* ... and fill the last 4 years into the table */
INSERT INTO demo.orders WITH (TABLOCK)
SELECT * FROM dbo.orders
WHERE	o_orderdate >= '2019-01-01';
GO

SELECT	[Index ID],
        [Index],
        rows,
        [In-Row MB],
        [Partition #],
        [Boundary Type],
        [Boundary Point]
FROM	dbo.get_partition_layout_info(N'demo.orders', 1);
GO