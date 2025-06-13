IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = N'01 - High Transactional Workload')
	DROP EVENT SESSION [01 - High Transactional Workload] ON SERVER;
	GO

EXEC dbo.sp_delete_xevent_files @pattern = N'T:\Tracefiles\*.xel';
GO

CREATE EVENT SESSION [01 - High Transactional Workload]
ON SERVER
ADD EVENT sqlserver.page_split
(
	WHERE
	(
		database_name = N'ERP_Demo'
		AND
		(
			splitOperation = 0
			OR splitOperation = 3
		)
	)
)
ADD TARGET package0.event_file
(
	SET filename = N'T:\TraceFiles\01 - High Transactional Workload'
)
WITH
(
	MAX_MEMORY = 4096KB ,
	EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS ,
	MAX_DISPATCH_LATENCY = 10 SECONDS ,
	MAX_EVENT_SIZE = 0KB ,
	MEMORY_PARTITION_MODE = NONE ,
	TRACK_CAUSALITY = OFF ,
	STARTUP_STATE = OFF
)
GO

ALTER EVENT SESSION [01 - High Transactional Workload] ON SERVER
STATE = START;
GO