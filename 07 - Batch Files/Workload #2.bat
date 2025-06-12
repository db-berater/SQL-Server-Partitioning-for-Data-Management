ECHO OFF
(
	start "LoadProcess 1" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 1;" -dERP_Demo -q -oT:\temp\LoadProcess01
	start "LoadProcess 2" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 2;" -dERP_Demo -q -oT:\temp\LoadProcess02
	start "LoadProcess 3" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 3;" -dERP_Demo -q -oT:\temp\LoadProcess03
	start "LoadProcess 4" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 4;" -dERP_Demo -q -oT:\temp\LoadProcess04
	start "LoadProcess 5" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 5;" -dERP_Demo -q -oT:\temp\LoadProcess05
	start "LoadProcess 6" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 6;" -dERP_Demo -q -oT:\temp\LoadProcess06
	start "LoadProcess 7" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 7;" -dERP_Demo -q -oT:\temp\LoadProcess07
	start "LoadProcess 8" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 8;" -dERP_Demo -q -oT:\temp\LoadProcess08
	start "LoadProcess 9" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 9;" -dERP_Demo -q -oT:\temp\LoadProcess09
	start "LoadProcess 10" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 10;" -dERP_Demo -q -oT:\temp\LoadProcess10
	start "LoadProcess 11" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 11;" -dERP_Demo -q -oT:\temp\LoadProcess11
	start "LoadProcess 12" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 12;" -dERP_Demo -q -oT:\temp\LoadProcess12
	start "LoadProcess 13" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 13;" -dERP_Demo -q -oT:\temp\LoadProcess13
	start "LoadProcess 14" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 14;" -dERP_Demo -q -oT:\temp\LoadProcess14
	start "LoadProcess 15" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 15;" -dERP_Demo -q -oT:\temp\LoadProcess15
	start "LoadProcess 16" /b "ostress.exe" -E -SSQLServer -Q"EXEC dbo.import_datawarehouse @warehouse_id = 16;" -dERP_Demo -q -oT:\temp\LoadProcess16
)