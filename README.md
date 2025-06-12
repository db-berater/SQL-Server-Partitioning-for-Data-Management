<a href="URL_REDIRECT" target="blank"><img align="center" src="https://www.db-berater.de/wp-content/uploads/2015/03/db-berater-gmbh-logo.jpg" height="100" /></a>
# Session - Partitioning for Data Management
This repository contains all codes for my session "Partitioning for Data Management". The target group for this session are experienced database programmers who want to use partitioning for their databases.

This session provides real world scenarios of partitioning with Microsoft SQL Server. The session is always run with the latest version of Microsoft SQL Server.
The repository consists of several folders that are split up by topic.

All scripts are created for the use of Microsoft SQL Server (Version 2016 or higher)
To work with the scripts it is required to have the workshop database [ERP_Demo](https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK) installed on your SQL Server Instance.
The last version of the demo database can be downloaded here:

**https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK**

> Written by
>	[Uwe Ricken](https://www.db-berater.de/uwe-ricken/), 
>	[db Berater GmbH](https://db-berater.de)
> 
> All scripts are intended only as a supplement to demos and lectures
> given by Uwe Ricken.  
>   
> **THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
> ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
> TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
> PARTICULAR PURPOSE.**

**Note**
The demo database contains a framework for all workshops / sessions from db Berater GmbH
+ Stored Procedures
+ User Definied Inline Functions

**Version:** 2025-06-12

# Folder structure
+ Each topic is stored in a separate folder (e.g. 01 - Documents and Preparation)
+ All scripts have numbers and basically the script with the prefix 01 is for the preparation of the environment
+ The folder **SQL ostress** contains .cmd files as substitute for SQL Query Stress.
   To use ostress you must download and install the **[RML Utilities](https://learn.microsoft.com/en-us/troubleshoot/sql/tools/replay-markup-language-utility)**
   
+ The folder **Windows Admin Center** contains json files with the configuration of performance counter. These files can only be used with Windows Admin Center
  - [Windows Admin Center](https://www.microsoft.com/en-us/windows-server/windows-admin-center)
+ The folder **SQL Query Stress** contains prepared configuration settings for each scenario which produce load test with SQLQueryStress from Adam Machanic
  - [SQLQueryStress](https://github.com/ErikEJ/SqlQueryStress)
+ The folder **SQL Extended Events** contains scripts for the implementation of extended events for the different scenarios
  All extended events are written for "LIVE WATCHING" and will have target file for saving the results.

# 01 - Documents and Preparation
This folder contains the accompanying PowerPoint presentation for the session. Script 00 - dbo.sp_restore_erp_demo.sql can also be used to install a stored procedure in the master database that is used in the scripts for restoring the database.
Script 01 - Preparation of demo database.sql restores the database on the local Microsoft SQL Server and resets the server's properties to the default settings.

# 02 - Hig Transactional Environment
All scripts in this folder demonstrate a simulation of a High transactional production environment
The customer is a pharmaceutical company that produces drugs on various (20) production lines. Every drug has to go through a QA check that stores the data in the SQL Server.

# 03 - Query Performance Problems
This folder demonstrate the problems with aggregated queries against a partitioned table.
The customer must evaluate the last imported o_orderkey before new data are inserted.
The evaluation of the MAX(o_orderdate) takes to long and scans the whole table!_

# 04 - Lockig Problem
The demo in this folder simulates a workload which transfers data from a staging environment into a data warehouse.
Staging and prod tables are partitioned but the import into the data warehouse cannot scale.

# 05 - Extended Events
This folder contains all scripts for the creation of Extended Events for the demos.

# ß6 - Batch Files
This folder contains all .bat files which are dedicated to run simultanious processes with the same character.
For an easy use of the batch files it is recommended to use a SQL Alias with the name "SQLServer".
Otherwise you have to change the parameter -S in the script to your SQL Server Instance Name.