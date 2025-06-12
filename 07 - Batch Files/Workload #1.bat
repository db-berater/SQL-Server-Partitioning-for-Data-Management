ECHO OFF
(
	start "Machine 1" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 1;" -dERP_Demo -r10000 -q -oT:\temp\machine01
	start "Machine 2" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 2;" -dERP_Demo -r10000 -q -oT:\temp\machine02
	start "Machine 3" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 3;" -dERP_Demo -r10000 -q -oT:\temp\machine03
	start "Machine 4" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 4;" -dERP_Demo -r10000 -q -oT:\temp\machine04
	start "Machine 5" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 5;" -dERP_Demo -r10000 -q -oT:\temp\machine05
	start "Machine 6" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 6;" -dERP_Demo -r10000 -q -oT:\temp\machine06
	start "Machine 7" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 7;" -dERP_Demo -r10000 -q -oT:\temp\machine07
	start "Machine 8" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 8;" -dERP_Demo -r10000 -q -oT:\temp\machine08
	start "Machine 9" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 9;" -dERP_Demo -r10000 -q -oT:\temp\machine09
	start "Machine 10" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 10;" -dERP_Demo -r10000 -q -oT:\temp\machine10
	start "Machine 11" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 11;" -dERP_Demo -r10000 -q -oT:\temp\machine11
	start "Machine 12" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 12;" -dERP_Demo -r10000 -q -oT:\temp\machine12
	start "Machine 13" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 13;" -dERP_Demo -r10000 -q -oT:\temp\machine13
	start "Machine 14" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 14;" -dERP_Demo -r10000 -q -oT:\temp\machine14
	start "Machine 15" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 15;" -dERP_Demo -r10000 -q -oT:\temp\machine15
	start "Machine 16" /b "ostress.exe" -E -SSQLServer -Q"EXEC demo.send_machine_data @machine_id = 16;" -dERP_Demo -r10000 -q -oT:\temp\machine16
)