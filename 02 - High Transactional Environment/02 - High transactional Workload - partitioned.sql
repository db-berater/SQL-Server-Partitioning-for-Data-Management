/*
	============================================================================
	File:		01 - speed up your high transactional workload.sql

	Summary:	This script demonstrates the optimization of heavy workloads
				with partitioning

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

/*
	We create for each machine one dedicated filegroup
	and add one file for each filegroup!
*/
DECLARE	@DataPath	NVARCHAR(256) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(256));
DECLARE	@stmt		NVARCHAR(1024);
DECLARE	@MachineId	INT	=	1;
WHILE @MachineId <= 16
BEGIN
	SET	@stmt = N'ALTER DATABASE ERP_Demo ADD FileGroup ' + QUOTENAME(N'machine_' + RIGHT('00' + CAST(@MachineId AS NVARCHAR(4)), 2)) + N';';
	RAISERROR ('Statement: %s', 0, 1, @stmt);
	EXEC sys.sp_executeSQL @stmt;

	SET @stmt = N'ALTER DATABASE ERP_Demo
ADD FILE
(
	NAME = ' + QUOTENAME(N'machine_' + RIGHT('00' + CAST(@MachineId AS NVARCHAR(4)), 2),  '''') + N',
	FILENAME = ''' + @DataPath + N'machine_' + RIGHT('00' + CAST(@MachineId AS NVARCHAR(4)), 2) + N'.ndf'',
	SIZE = 128MB,
	FILEGROWTH = 128MB
)
TO FILEGROUP ' + QUOTENAME(N'machine_' + RIGHT('00' + CAST(@MachineId AS NVARCHAR(4)), 2)) + N';';
	RAISERROR ('Statement: %s', 0, 1, @stmt);
	EXEC sys.sp_executeSQL @stmt;

	SET	@MachineId += 1;
END
GO

-- When the layout is ready we can now create our partition function
CREATE PARTITION FUNCTION pf_machine_Id(SMALLINT)
AS RANGE LEFT FOR VALUES
(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
GO

-- next step is the partition schema for the distribution of data
CREATE PARTITION SCHEME ps_machine_id
AS PARTITION pf_machine_id
TO
(
	[machine_01], [machine_02], [machine_03], [machine_04], [machine_05], 
	[machine_06], [machine_07], [machine_08], [machine_09], [machine_10],
	[machine_11], [machine_12], [machine_13], [machine_14], [machine_15],
	[machine_16], [PRIMARY]
)
GO

-- Now we distribute the MachineProtocol-Table over all partitions
-- and put a clustered index on MachineId, SeqId
ALTER TABLE demo.machine_protocol DROP CONSTRAINT pk_machine_protocol;
GO

ALTER TABLE demo.machine_protocol
ADD CONSTRAINT pk_machine_protocol
PRIMARY KEY CLUSTERED (machine_id, D1)
ON ps_machine_id(machine_id)
GO

-- Information about the partitioning infrastructure
SELECT	[Schema.Table],
        [Index ID],
        Structure,
        [Index],
        rows,
        [In-Row MB],
        [LOB MB],
        [Partition #],
        [Partition Function],
        [Boundary Type],
        [Boundary Point],
        Filegroup
FROM	dbo.get_partition_layout_info(N'demo.machine_protocol', 1)
ORDER BY
		[Partition #];
GO