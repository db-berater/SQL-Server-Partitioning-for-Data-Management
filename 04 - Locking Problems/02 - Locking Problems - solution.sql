/*
	============================================================================
	File:		02 - Locking Problems - solution.sql

	Summary:	This script will be used to measure the workload with / without
				partitioning!

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
	If you want to insert data in a partitioned table you must
	avoid lock escalation up the table by setting the LOCK_ESCALATION
	option for the table.
*/
ALTER TABLE demo.sales_figures SET (LOCK_ESCALATION = AUTO);
GO

TRUNCATE TABLE demo.sales_figures;
GO

BEGIN TRANSACTION
GO
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
	WHERE	warehouse_id = 1
	GROUP BY
			import_date,
			warehouse_id,
			cash_id,
			article_id,
			article_name
	OPTION	(MAXDOP 1);

	SELECT	DISTINCT
			resource_type,
            resource_associated_entity_id,
            resource_lock_partition,
            request_mode,
            request_type,
            request_status
	FROM	sys.dm_tran_locks
	WHERE	request_session_id = @@SPID
			AND resource_type IN (N'OBJECT', N'HOBT');
ROLLBACK TRANSACTION;
GO