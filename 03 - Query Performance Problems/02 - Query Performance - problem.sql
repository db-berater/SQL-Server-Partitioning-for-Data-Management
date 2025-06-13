/*
	============================================================================
	File:		02 - query performance - problem.sql

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
	The core query must find the last o_orderkey for new inserts
	NOTE: There is a clustered index on the o_orderkey attribute
*/
SELECT	MAX(o_orderkey)
FROM	demo.orders
OPTION	(MAXDOP 4);
GO

/*
	Let's have a look into the index to understand the problem
*/
SELECT	index_id,
        index_name,
        partition_number,
        type_desc,
        rows,
        total_pages,
        used_pages,
        data_pages,
        space_mb,
        root_page,
        first_iam_page
FROM	dbo.get_table_pages_info(N'demo.orders', 1);
GO

/*
	Let's have a look into the index!
	(1:880185:0)
*/
DBCC TRACEON (3604);
DBCC PAGE (0, 1, 880185, 3);
GO

/*
	In SQL Server, the internal representation of a partitioned table is changed 
	so that the table appears to the query processor to be a multicolumn index with 
	PartitionID as the leading column.
	PartitionID is a hidden computed column used internally to represent the ID of the 
	partition containing a specific row.
	
	For example, assume the table T, defined as T(a, b, c), is partitioned on column a,
	and has a clustered index on column b.
	
	In SQL Server, this partitioned table is treated internally as a nonpartitioned table
	with the schema T(PartitionID, a, b, c) and a clustered index on the composite key
	(PartitionID, b).
	
	This allows the Query Optimizer to perform seek operations based on PartitionID on any
	partitioned table or index.

	PARTITION ELIMINATION IS NOW DONE IN THIS SEEK OPERATION.

	In addition, the Query Optimizer is extended so that a seek or scan operation with 
	one condition can be done on PartitionID (as the logical leading column) and possibly
	other index key columns, and then a second-level seek, with a different condition, 
	can be done on one or more additional columns, for each distinct value that meets 
	the qualification for the first-level seek operation. 
	
	That is, this operation, called a skip scan, allows the Query Optimizer to perform 
	a seek or scan operation based on one condition to determine the partitions to be 
	accessed and a second-level index seek operation within that operator to return rows 
	from these partitions that meet a different condition. 
*/

/* Maybe we can get a better result by using the partition column? */
SELECT	MAX(o_orderkey)
FROM	demo.orders
WHERE	o_orderdate >= '2021-01-01'
		AND o_orderdate <= '2021-12-31'
OPTION	(MAXDOP 4);
GO

/*
	Follow the index, Luke!
	(1:82641:0)
*/
DBCC TRACEON (3604);
DBCC PAGE (0, 1, 880185, 3);
GO