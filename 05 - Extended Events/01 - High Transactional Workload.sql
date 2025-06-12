IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = N'0010 - XE - high Transactional Workload')
	DROP EVENT SESSION [01 - High Transactional Workload] ON SERVER;
	GO

CREATE EVENT SESSION [01 - High Transactional Workload]
ON SERVER
ADD EVENT sqlos.wait_info
(
	WHERE
	(
		duration >=  5
        AND sqlserver.database_id = 5
        AND
		(
			wait_type = 3
			OR wait_type = 4
			OR wait_type = 5
			OR wait_type = 36
            OR wait_type = 35
            OR wait_type = 34
		)
	)
),
ADD EVENT sqlserver.page_split
(
	WHERE
	(
		database_id = 5
		AND
		(
			splitOperation = 0
			OR splitOperation = 3
		)
	)
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