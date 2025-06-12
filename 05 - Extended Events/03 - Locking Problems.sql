/*============================================================================
	File:		0002 - XEvent for Lock Escalation.sql

	Summary:	This script implements an XEvent and starts it automatically
				after the implementation. It tracks every lock escalation
				in the demo_db database!

				THIS SCRIPT IS PART OF THE TRACK:
				"Database Partitioning"

	Date:		December 2020

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

IF EXISTS (SELECT * FROM sys.dm_xe_sessions WHERE name = N'03 - Locking Problems')
	DROP EVENT SESSION [03 - Locking Problems] ON SERVER;
	GO

CREATE EVENT SESSION [03 - Locking Problems] ON SERVER
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
		AND 
		(
			resource_type = N'OBJECT'
			OR resource_type = N'HoBT'
		)
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
	ACTION
	(
		sqlserver.session_id,
		sqlserver.sql_text
	)
	WHERE	sqlserver.database_name = N'ERP_Demo'
)
WITH
(
	MAX_MEMORY = 4096KB,
	EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
	MAX_DISPATCH_LATENCY = 5 SECONDS,
	MAX_EVENT_SIZE = 0KB,
	MEMORY_PARTITION_MODE = NONE,
	TRACK_CAUSALITY = OFF,
	STARTUP_STATE = OFF
);

ALTER EVENT SESSION [03 - Locking Problems] ON SERVER STATE = START;
GO
