/*
	============================================================================
	File:		03 - Locking Problems - analysis.sql

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
	Before we start this process we implement an XEvent which
	monitors 
	- locks on objects

	03 - Locking Problems.sql
*/

-- Clean all wait counters before we start
DBCC SQLPERF(N'sys.dm_os_wait_stats', CLEAR);
GO

TRUNCATE TABLE dbo.import_log;
TRUNCATE TABLE demo.sales_figures;
GO

SELECT	DISTINCT * FROM sys.dm_os_waiting_tasks
WHERE	session_id >= 50;

/*
	Now we run ostress with 16 machines and 10,000 entries / machine
	with the file "Workload #2.bat" in the folder "06 - Batch Files"

	The demo should run between 30 - 60 seconds!

	CHECK THE WAITING TASKS WHILE THE PROCESS IS RUNNING
*/
SELECT	*
FROM	dbo.import_log
ORDER BY
		duration_ms;

/*
	How will it work if we do the import serialized?
*/
TRUNCATE TABLE dbo.import_log;
TRUNCATE TABLE demo.sales_figures;
GO

DECLARE @i INT = 1
WHILE @i <= 16
BEGIN
	EXEC dbo.ImportWarehouseData @warehouse_id = @i;
	SET @i += 1;
END
GO

SELECT	*
FROM	dbo.import_log
ORDER BY
		duration_ms;


/* What is the problem with it? */
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

	SELECT	resource_type,
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
