# get-PRTGSQLBatchJob
PRTG sensor [Microsoft SQL v2 Sensor](https://www.paessler.com/manuals/prtg/microsoft_sql_v2_sensor) can define one (1)
imput parameter. 

## Alternative 1
Add split function in SQL query to get multiple variables from @prtg

## Alternative 2
Write a 'EXE/Script Advanced Sensor' sensor with use of [SQL Server Powershell](https://learn.microsoft.com/en-us/sql/powershell/sql-server-powershell?view=sql-server-ver16) commandlet. 
