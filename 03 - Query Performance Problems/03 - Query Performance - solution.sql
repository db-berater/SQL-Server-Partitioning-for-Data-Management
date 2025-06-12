/*
	============================================================================
	File:		03 - query performance solution.sql

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

SET STATISTICS IO, TIME ON;
GO

/*
	Instead of searching for a date range let's search by the "leading"
	partition_id column!
*/
SELECT	$PARTITION.pf_o_orderdate('2020-01-01');
GO

SELECT	MAX(o_orderkey)
FROM	demo.orders
WHERE	$PARTITION.pf_o_orderdate(o_orderdate) = 1;
GO

/*
	Let's get a list of all available partitions for the table
	demo.orders
*/
SELECT	DISTINCT
		p.partition_number
FROM	sys.partitions AS p
WHERE	p.object_id = OBJECT_ID(N'demo.orders', N'U');
GO

/*
	And combine the available partition numbers with a 
	CROSS APPLY over the demo.orders table to recieve
	the MAX o_orderkey for each partition!
*/
SELECT	DISTINCT
		p.partition_number,
		agg.o_orderkey
FROM	sys.partitions AS p
		CROSS APPLY
		(
			SELECT	MAX(o_orderkey)	AS	o_orderkey
			FROM	demo.orders
			WHERE	$PARTITION.pf_o_orderdate(o_orderdate) = p.partition_number
		) AS agg
WHERE	p.object_id = OBJECT_ID(N'demo.orders', N'U');
GO

/*
	The final result must be the aggregation over all partition evaluation values
*/;
SELECT	MAX(agg.o_orderkey)	AS	max_orderkey
FROM	sys.partitions AS p
		CROSS APPLY
		(
			SELECT	MAX(o_orderkey)	AS	o_orderkey
			FROM	demo.orders
			WHERE	$PARTITION.pf_o_orderdate(o_orderdate) = p.partition_number
		) AS agg
WHERE	p.object_id = OBJECT_ID(N'demo.orders', N'U');
GO
