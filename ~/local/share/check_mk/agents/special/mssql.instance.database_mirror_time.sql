-- 
-- 
-- 
set nocount on;

IF OBJECT_ID('msdb.dbo.dbm_monitor_data') IS NULL return;

select '<<<mssql_databasemirrortime:sep(124)>>>';

SELECT
    ISNULL(SERVERPROPERTY('InstanceName'),'MSSQLSERVER'),
    d.name [DBName],
    DATEDIFF(second, mon.Time, GETUTCDATE()) [MirroringDelaySeconds]
FROM
    master.sys.databases d
    inner join (
        select database_id, max(time) [Time]
        from msdb.dbo.dbm_monitor_data
        group by database_id
    ) mon on mon.database_id = d.database_id
    left join master.sys.database_mirroring m ON m.database_id = d.database_id
