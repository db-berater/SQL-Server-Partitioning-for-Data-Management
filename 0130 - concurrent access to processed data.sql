/*============================================================================
	File:		0030 - concurrent access to processed data.sql

	Summary:	This script demonstrates the optimization of big data management
				in Microsoft SQL Server

	Simulation:	The customer is a bank that recalculates the valuation of its
				funds every night. During the calculation, the reports for BaFIN
				must be created for processed funds because of timeline restrictions.

				THIS SCRIPT IS PART OF THE TRACK:
				"Database Partitioning"

	Date:		May 2020

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

EXEC dbo.sp_create_demo_db;
GO

USE demo_db;
GO

/*
	Before the demo we need to update the dbo.CustomerOrders-table
	because the demo data are a little bit crappy :)

	UPDATE	CustomerOrders.dbo.CustomerOrders
	SET		Employee_Id = Employee_Id % 150 + 1
	WHERE	Employee_Id > 150;
*/

-- Create a schema for saving the data from the Cash Desks (Staging)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'staging')
	EXEC sp_executesql N'CREATE SCHEMA staging AUTHORIZATION dbo;'
	GO

SELECT	CO.Employee_Id		AS	Fonds_Id,
		COD.Article_Id		AS	Asset_Id,
		CO.OrderDate		AS	Valued_Date,
		COUNT_BIG(*)		AS	Inventory,
		COD.Price			AS	Asset_Price
INTO	dbo.Transactions
FROM	CustomerOrders.dbo.CustomerOrders AS CO
		INNER JOIN CustomerOrders.dbo.CustomerOrderDetails AS COD
		ON CO.Id = COD.Order_Id
		INNER JOIN CustomerOrders.dbo.Articles AS A
		ON (COD.Article_Id = A.Id)
GROUP BY
		CO.Employee_Id,
		COD.Article_Id,
		CO.OrderDate,
		COD.Price;

-- Create random buy/sell activities
BEGIN
	RAISERROR (N'Changing the INVENTORY to random values...', 0, 1) WITH NOWAIT;
	UPDATE	dbo.Transactions WITH (TABLOCK)
	SET		Inventory = CHECKSUM(Asset_Price);

	UPDATE	dbo.Transactions WITH (TABLOCK)
	SET		Inventory = (RAND(Inventory) * 1200) - 600;
END
GO

-- Create a nonclustered index for better import performance
RAISERROR (N'Creating clustered index on Fonds, Asset, Date...', 0, 1) WITH NOWAIT;
CREATE CLUSTERED INDEX cix_Transactions_Fonds_Asset_Date
ON dbo.Transactions
(
	Fonds_Id,
	Asset_Id,
	Valued_Date
);
GO

SELECT TOP (1000) * FROM dbo.Transactions;
GO

-- Let's create the table for the calculation of the portfolio
IF OBJECT_ID(N'dbo.FondsCalculation', N'U') IS NOT NULL
	DROP TABLE dbo.FondsCalculation;
	GO

CREATE TABLE dbo.FondsCalculation
(
	Fonds_Id		INT				NOT NULL,
	Asset_Id		INT				NOT NULL,
	Value_Date		DATE			NOT NULL,
	Current_Stock	INT				NOT NULL,
	Asset_Value		NUMERIC(10, 2)	NOT NULL
);
GO

CREATE UNIQUE CLUSTERED INDEX cuix_FondsCalculation_01
ON dbo.FondsCalculation
(
	Fonds_Id,
	Asset_Id,
	Value_Date
);
GO

-- Put a "simple" math in a stored proc for the execution of each fonds
CREATE OR ALTER PROCEDURE dbo.CalculateFonds
	@Fonds_Id	INT
AS
BEGIN
	SET NOCOUNT ON;

	-- Delete the data from the FondsCalculation before we insert new records
	DELETE	dbo.FondsCalculation WHERE Fonds_Id = @Fonds_Id;

	WITH DateList
	AS
	(
		SELECT	CAST('20000101' AS DATE) AS Datum

		UNION ALL

		SELECT	DATEADD(DAY, 1, Datum)	AS Datum
		FROM	DateList
		WHERE	Datum < '20200630'
	)
	INSERT INTO dbo.FondsCalculation
	(Fonds_Id, Asset_Id, Value_Date, Current_Stock, Asset_Value)
	SELECT Result.Fonds_Id,
		   Result.Asset_Id,
		   Result.Datum,
		   SUM(Result.Current_Stock)		AS	Current_Stock,
		   AVG(Result.Current_Fonds_Value)	AS	Current_Fonds_Value
	FROM
	(
		SELECT	CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END AS Fonds_Id,
				Assets.Id		AS	Asset_Id,
				D.Datum,
				SUM
				(
					CASE WHEN T.Inventory IS NULL THEN 0 ELSE T.Inventory END
				) OVER
				(
					PARTITION BY
						CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END,
						Assets.Id
					ORDER BY
						D.Datum
				)	AS	Current_Stock,
				SUM
				(
					CASE WHEN T.Inventory IS NULL THEN 0 ELSE T.Inventory END *
					CASE WHEN T.Asset_Price	IS NULL THEN 0 ELSE T.Asset_Price END
				) OVER 
				(
					PARTITION BY
						CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END,
						Assets.Id
					ORDER BY
						D.Datum
				)	AS	Current_Fonds_Value
		FROM	(
					DateList AS D
					CROSS JOIN CustomerOrders.dbo.Articles AS Assets
				)
				LEFT JOIN dbo.Transactions AS T
				ON
				(
					D.Datum = T.Valued_Date
					AND Assets.Id = T.Asset_Id
					AND T.Fonds_Id = @Fonds_Id
				)
	) AS Result
	GROUP BY
		Result.Fonds_Id,
		Result.Asset_Id,
		Result.Datum
	ORDER BY
		Result.Fonds_Id,
		Result.Asset_Id,
		Result.Datum
	OPTION (MAXRECURSION 0, MAXDOP 1)
END
GO

-- What is the problem with this workload?
-- We have a close look to ONE single process!
BEGIN TRANSACTION
GO
	EXEC dbo.CalculateFonds @Fonds_Id = 1;
	GO

	SELECT * FROM master.dbo.DatabaseLocks(N'demo_db');
	GO
ROLLBACK TRANSACTION;
GO

-- Now we speed up the system by partitioning the table by fonds_id
CREATE PARTITION FUNCTION pf_Fonds_Id (INT)
AS RANGE LEFT FOR VALUES (1);
GO

DECLARE @I INT = 2;
WHILE @I <= 150
BEGIN
	ALTER PARTITION FUNCTION pf_Fonds_Id() SPLIT RANGE (@I);
	SET @I += 1;
END
GO

-- Now we create a dedicated filegroup fro each partition range
DECLARE	@DataPath	NVARCHAR(256) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(256));

DECLARE	@stmt		NVARCHAR(1024);
DECLARE	@Fonds_Id	INT	=	1;
WHILE @Fonds_Id <= 150
BEGIN
	SET	@stmt = N'ALTER DATABASE demo_db ADD FileGroup ' + QUOTENAME(N'F_' + RIGHT('000' + CAST(@Fonds_Id AS NVARCHAR(4)), 3)) + N';';
	RAISERROR ('Statement: %s', 0, 1, @stmt);
	EXEC sys.sp_executeSQL @stmt;

	SET @stmt = N'ALTER DATABASE demo_db
ADD FILE
(
	NAME = ' + QUOTENAME(N'Fonds_' + RIGHT('000' + CAST(@Fonds_Id AS NVARCHAR(4)), 4), '''') + N',
	FILENAME = ''' + @DataPath + N'Fonds_' + RIGHT('000' + CAST(@Fonds_Id AS NVARCHAR(4)), 3) + N'.ndf'',
	SIZE = 64MB,
	FILEGROWTH = 64MB
)
TO FILEGROUP ' + QUOTENAME(N'F_' + RIGHT('000' + CAST(@Fonds_Id AS NVARCHAR(4)), 3)) + N';';
	RAISERROR ('Statement: %s', 0, 1, @stmt);
	EXEC sys.sp_executeSQL @stmt;

	SET	@Fonds_Id += 1;
END
GO

--DECLARE	@output VARCHAR(8000) = '';
--DECLARE @I INT = 1;
--WHILE @I <= 150
--BEGIN
--	SET @output = @output + QUOTENAME('F_' + RIGHT('000' + CAST(@I AS VARCHAR(3)), 3)) + ', ';
--	SET @I += 1;
--END
--PRINT @output;
--GO

-- Now we create the schema for the binding of partition function to file groups!
CREATE PARTITION SCHEME ps_Fonds_Id
AS PARTITION pf_Fonds_Id
TO
(
	[F_001], [F_002], [F_003], [F_004], [F_005], [F_006], [F_007], [F_008], [F_009], [F_010],
	[F_011], [F_012], [F_013], [F_014], [F_015], [F_016], [F_017], [F_018], [F_019], [F_020],
	[F_021], [F_022], [F_023], [F_024], [F_025], [F_026], [F_027], [F_028], [F_029], [F_030],
	[F_031], [F_032], [F_033], [F_034], [F_035], [F_036], [F_037], [F_038], [F_039], [F_040],
	[F_041], [F_042], [F_043], [F_044], [F_045], [F_046], [F_047], [F_048], [F_049], [F_050],
	[F_051], [F_052], [F_053], [F_054], [F_055], [F_056], [F_057], [F_058], [F_059], [F_060],
	[F_061], [F_062], [F_063], [F_064], [F_065], [F_066], [F_067], [F_068], [F_069], [F_070],
	[F_071], [F_072], [F_073], [F_074], [F_075], [F_076], [F_077], [F_078], [F_079], [F_080],
	[F_081], [F_082], [F_083], [F_084], [F_085], [F_086], [F_087], [F_088], [F_089], [F_090],
	[F_091], [F_092], [F_093], [F_094], [F_095], [F_096], [F_097], [F_098], [F_099], [F_100],
	[F_101], [F_102], [F_103], [F_104], [F_105], [F_106], [F_107], [F_108], [F_109], [F_110],
	[F_111], [F_112], [F_113], [F_114], [F_115], [F_116], [F_117], [F_118], [F_119], [F_120],
	[F_121], [F_122], [F_123], [F_124], [F_125], [F_126], [F_127], [F_128], [F_129], [F_130],
	[F_131], [F_132], [F_133], [F_134], [F_135], [F_136], [F_137], [F_138], [F_139], [F_140],
	[F_141], [F_142], [F_143], [F_144], [F_145], [F_146], [F_147], [F_148], [F_149], [F_150],
	[PRIMARY]
);
GO

-- Now we partition the analytics table to the alignment of the partitions
CREATE UNIQUE CLUSTERED INDEX cuix_FondsCalculation_01
ON dbo.FondsCalculation
(
	Fonds_Id,
	Asset_Id,
	Value_Date
)
WITH DROP_EXISTING
ON ps_Fonds_Id(Fonds_Id);
GO

ALTER TABLE dbo.FondsCalculation SET (LOCK_ESCALATION = AUTO);
GO

-- Run the test again and check the wait stats afterwards
-- What is the problem with this workload?
-- We have a close look to ONE single process!
BEGIN TRANSACTION
GO
	EXEC dbo.CalculateFonds @Fonds_Id = 1;
	GO

	SELECT * FROM master.dbo.DatabaseLocks(N'demo_db');
	GO
ROLLBACK TRANSACTION;
GO

-- Problem is IN the Stored Proc.
-- Why deleting data from a partition when TRUNCATE is way faster?

SELECT * FROM sys.partition_range_values;
GO
SELECT	partition_id,
        index_id,
        partition_number,
        used_page_count,
        reserved_page_count,
        row_count
FROM	sys.dm_db_partition_stats
WHERE	object_id = OBJECT_ID(N'dbo.FondsCalculation', N'U');
GO

CREATE OR ALTER PROCEDURE dbo.CalculateFonds
	@Fonds_Id	INT
AS
BEGIN
	SET NOCOUNT ON;

	-- Delete the data from the FondsCalculation before we insert new records
	TRUNCATE TABLE dbo.FondsCalculation
	WITH (PARTITIONS($partition.pf_Fonds_Id (@Fonds_Id)));

	WITH DateList
	AS
	(
		SELECT	CAST('20000101' AS DATE) AS Datum

		UNION ALL

		SELECT	DATEADD(DAY, 1, Datum)	AS Datum
		FROM	DateList
		WHERE	Datum < '20200630'
	)
	INSERT INTO dbo.FondsCalculation
	(Fonds_Id, Asset_Id, Value_Date, Current_Stock, Asset_Value)
	SELECT Result.Fonds_Id,
		   Result.Asset_Id,
		   Result.Datum,
		   SUM(Result.Current_Stock)		AS	Current_Stock,
		   AVG(Result.Current_Fonds_Value)	AS	Current_Fonds_Value
	FROM
	(
		SELECT	CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END AS Fonds_Id,
				Assets.Id		AS	Asset_Id,
				D.Datum,
				SUM
				(
					CASE WHEN T.Inventory IS NULL THEN 0 ELSE T.Inventory END
				) OVER
				(
					PARTITION BY
						CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END,
						Assets.Id
					ORDER BY
						D.Datum
				)	AS	Current_Stock,
				SUM
				(
					CASE WHEN T.Inventory IS NULL THEN 0 ELSE T.Inventory END *
					CASE WHEN T.Asset_Price	IS NULL THEN 0 ELSE T.Asset_Price END
				) OVER 
				(
					PARTITION BY
						CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END,
						Assets.Id
					ORDER BY
						D.Datum
				)	AS	Current_Fonds_Value
		FROM	(
					DateList AS D
					CROSS JOIN CustomerOrders.dbo.Articles AS Assets
				)
				LEFT JOIN dbo.Transactions AS T
				ON
				(
					D.Datum = T.Valued_Date
					AND Assets.Id = T.Asset_Id
					AND T.Fonds_Id = @Fonds_Id
				)
	) AS Result
	GROUP BY
		Result.Fonds_Id,
		Result.Asset_Id,
		Result.Datum
	ORDER BY
		Result.Fonds_Id,
		Result.Asset_Id,
		Result.Datum
	OPTION (MAXRECURSION 0)

END
GO

BEGIN TRANSACTION
GO
	EXEC dbo.CalculateFonds @Fonds_Id = 2;
	GO

	SELECT * FROM master.dbo.DatabaseLocks(N'demo_db')
	WHERE	request_session_id = @@SPID;
	GO
COMMIT TRANSACTION;
GO

-- IX lock prevents the TRUNCATE process of other processes
-- Therefor we need to switch out the partition before we 
-- process the data!
CREATE TABLE staging.FondsCalculation
(
	Fonds_Id		INT				NOT NULL,
	Asset_Id		INT				NOT NULL,
	Value_Date		DATE			NOT NULL,
	Current_Stock	INT				NOT NULL,
	Asset_Value		NUMERIC(10, 2)	NOT NULL
)
ON ps_Fonds_Id(Fonds_Id);
GO

CREATE UNIQUE CLUSTERED INDEX cuix_FondsCalculation_02
ON staging.FondsCalculation
(
	Fonds_Id,
	Asset_Id,
	Value_Date
)
ON ps_Fonds_Id(Fonds_Id);
GO

CREATE OR ALTER PROCEDURE dbo.CalculateFonds
	@Fonds_Id	INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @partition_id INT = $partition.pf_Fonds_Id (@Fonds_Id);

	-- Empty the fonds partition in the staging area
	RAISERROR('truncating partition %i in staging.FondsCalculation...', 0, 1, @partition_id) WITH NOWAIT;
	TRUNCATE TABLE staging.FondsCalculation WITH (PARTITIONS (@partition_id));

	-- fill the fonds partition in the staging area with recacluated values
	RAISERROR('filling partition %i in staging.FondsCalculation...', 0, 1, @partition_id) WITH NOWAIT;
	WITH DateList
	AS
	(
		SELECT	CAST('20000101' AS DATE) AS Datum

		UNION ALL

		SELECT	DATEADD(DAY, 1, Datum)	AS Datum
		FROM	DateList
		WHERE	Datum < '20200630'
	)
	INSERT INTO staging.FondsCalculation
	(Fonds_Id, Asset_Id, Value_Date, Current_Stock, Asset_Value)
	SELECT Result.Fonds_Id,
			Result.Asset_Id,
			Result.Datum,
			SUM(Result.Current_Stock)		AS	Current_Stock,
			AVG(Result.Current_Fonds_Value)	AS	Current_Fonds_Value
	FROM
	(
		SELECT	CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END AS Fonds_Id,
				Assets.Id		AS	Asset_Id,
				D.Datum,
				SUM
				(
					CASE WHEN T.Inventory IS NULL THEN 0 ELSE T.Inventory END
				) OVER
				(
					PARTITION BY
						CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END,
						Assets.Id
					ORDER BY
						D.Datum
				)	AS	Current_Stock,
				SUM
				(
					CASE WHEN T.Inventory IS NULL THEN 0 ELSE T.Inventory END *
					CASE WHEN T.Asset_Price	IS NULL THEN 0 ELSE T.Asset_Price END
				) OVER 
				(
					PARTITION BY
						CASE WHEN T.Fonds_Id IS NULL THEN @Fonds_Id ELSE T.Fonds_Id END,
						Assets.Id
					ORDER BY
						D.Datum
				)	AS	Current_Fonds_Value
		FROM	(
					DateList AS D
					CROSS JOIN CustomerOrders.dbo.Articles AS Assets
				)
				LEFT JOIN dbo.Transactions AS T
				ON
				(
					D.Datum = T.Valued_Date
					AND Assets.Id = T.Asset_Id
					AND T.Fonds_Id = @Fonds_Id
				)
	) AS Result
	GROUP BY
		Result.Fonds_Id,
		Result.Asset_Id,
		Result.Datum
	ORDER BY
		Result.Fonds_Id,
		Result.Asset_Id,
		Result.Datum
	OPTION (MAXRECURSION 0);

	-- Empty the production table
	RAISERROR('truncating partition %i in dbo.FondsCalculation', 0, 1, @partition_id) WITH NOWAIT;
	TRUNCATE TABLE dbo.FondsCalculation WITH (PARTITIONS (@partition_id));
	RAISERROR('switch partition %i from staging.FondsCalculation to dbo.FondsCalculation', 0, 1, @partition_id) WITH NOWAIT;
	ALTER TABLE staging.FondsCalculation SWITCH PARTITION @partition_id TO dbo.FondsCalculation PARTITION @partition_id;
END
GO

BEGIN TRANSACTION
GO
	EXEC dbo.CalculateFonds @Fonds_Id = 2;
	GO

	SELECT * FROM master.dbo.DatabaseLocks(N'demo_db')
	WHERE	request_session_id = @@SPID;
	GO
COMMIT TRANSACTION;
GO