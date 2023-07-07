-- https://learn.microsoft.com/en-us/sql/t-sql/functions/databasepropertyex-transact-sql
set nocount on;

SELECT
    'MSSQL_' + cast(isnull(serverproperty('InstanceName'),'MSSQLSERVER') as varchar),
    replace(name, ' ', '_'),
    DATABASEPROPERTYEX(name, 'Status') AS Status,
    DATABASEPROPERTYEX(name, 'Recovery') AS Recovery,
    DATABASEPROPERTYEX(name, 'IsAutoClose') AS auto_close,
    DATABASEPROPERTYEX(name, 'IsAutoShrink') AS auto_shrink
FROM master.dbo.sysdatabases;
