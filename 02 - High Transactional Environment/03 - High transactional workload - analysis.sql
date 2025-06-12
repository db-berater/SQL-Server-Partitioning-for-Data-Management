/*
	============================================================================
	File:		02 - High transactional workload - analysis.sql

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
	- page splits

	01 - High transactional processes.sql
*/

-- Clean all wait counters before we start
DBCC SQLPERF(N'sys.dm_os_wait_stats', CLEAR);
GO

TRUNCATE TABLE demo.machine_protocol;
GO

SELECT machine_id,
		COUNT_BIG(*)
FROM demo.machine_protocol
GROUP BY
		machine_id;

/*
	Now we run ostress with 16 machines and 10,000 entries / machine
	with the file "Workload #1.bat" in the folder "06 - Batch Files"

	The demo should run between 30 - 60 seconds!

	CHECK THE WAITING TASKS WHILE THE PROCESS IS RUNNING
*/
SELECT	dowt.session_id,
        dowt.wait_duration_ms,
        dowt.wait_type,
        dowt.resource_address,
        dowt.blocking_session_id,
        dowt.resource_description
FROM	sys.dm_os_waiting_tasks AS dowt
		INNER JOIN sys.dm_exec_sessions AS des
		ON (dowt.session_id = des.session_id)
WHERE	des.is_user_process = 1;
GO

SELECT * FROM master.dbo.WaitStatsAnalysis
WHERE
	WaitType IN
	(
		N'WRITELOG',
		N'PAGELATCH_EX',
		N'PAGELATCH_SH',
		N'SOS_SCHEDULER_YIELD',
		N'PAGEIOLATCH_EX',
		N'PAGEIOLATCH_SH'
	);
GO

/* Let's check the runtime for the whole process */
;WITH D
AS
(
	SELECT	MIN(d1)			AS	StartTime,
			MAX(d1)			AS	EndTime,
			COUNT_BIG(*)	AS	NumOfRecords
	FROM	demo.machine_protocol
)
SELECT	StartTime,
		EndTime,
		FORMAT
		(
			DATEDIFF(SECOND, StartTime, EndTime),
			N'#,##0',
			N'en-us'
		)											AS Duration_sec,
		FORMAT(NumOfRecords, '#,##0', N'en-us')		AS NumOfRecords,
		FORMAT
		(
			DATEDIFF(MICROSECOND, StartTime, EndTime)
			/ CAST(NumOfRecords AS FLOAT),
			N'#,##0',
			N'en-us'
		)											AS InsertSpeed_mcs
FROM	D
GO

-- What fragmentation does the index have?
SELECT	partition_number,
        rows,
        total_pages,
        used_pages,
        data_pages,
        space_mb,
        root_page,
        first_iam_page
FROM	dbo.get_table_pages_info(N'demo.machine_protocol', NULL)
GO

SELECT	partition_number,
		index_level,
		avg_fragmentation_in_percent,
		avg_page_space_used_in_percent
FROM sys.dm_db_index_physical_stats
(
	DB_ID(),
	OBJECT_ID(N'demo.machine_protocol',N'U'),
	1,
	NULL,
	N'DETAILED'
)
WHERE	index_level = 0;
GO