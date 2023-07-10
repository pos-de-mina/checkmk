-- https://learn.microsoft.com/en-us/sql/t-sql/functions/databasepropertyex-transact-sql
set nocount on;
SELECT '<<<mssql_backup:sep(124)>>>';

DECLARE @HADRStatus sql_variant; 
DECLARE @SQLCommand nvarchar(max);
declare @mssql_backup table (
    instance varchar(32),
    db_name varchar(32),
    last_backup_date varchar(32),
    last_backup_time varchar(32),
    backup_type varchar(16),
    backup_msg varchar(32)
);

INSERT INTO @mssql_backup(instance, db_name, last_backup_date, last_backup_time, backup_type, backup_msg)
SELECT
    'MSSQL_' + cast(isnull(serverproperty('InstanceName'),'MSSQLSERVER') as varchar),
    name,
    '-',
    '-',
    '-',
    'no backup found'
FROM sys.databases

SET @HADRStatus = (SELECT SERVERPROPERTY ('IsHadrEnabled'));
IF (@HADRStatus IS NULL or @HADRStatus <> 1)
BEGIN
    update @mssql_backup
    set 
        last_backup_date=bs_date,
        last_backup_time=bs_time,
        backup_type=bs_type,
        backup_msg=''
    FROM @mssql_backup 
        join (
            select
                CONVERT(VARCHAR, DATEADD(s, DATEDIFF(s, '19700101', MAX(backup_finish_date)), '19700101'), 23) bs_date,
                CONVERT(VARCHAR, DATEADD(s, DATEDIFF(s, '19700101', MAX(backup_finish_date)), '19700101'), 24) bs_time,
                type bs_type,
                database_name as bs_dbname
            FROM msdb.dbo.backupset
            WHERE  machine_name = SERVERPROPERTY('Machinename')
            GROUP BY type, database_name
        ) bs on bs_dbname = db_name
END
ELSE
BEGIN
    update @mssql_backup
    set 
        last_backup_date=bs_date,
        last_backup_time=bs_time,
        backup_type=bs_type,
        backup_msg=''
    FROM @mssql_backup 
        join (
            select
                CONVERT(VARCHAR, DATEADD(s, DATEDIFF(s, '19700101', MAX(backup_finish_date)), '19700101'), 23) bs_date,
                CONVERT(VARCHAR, DATEADD(s, DATEDIFF(s, '19700101', MAX(backup_finish_date)), '19700101'), 24) bs_time,
                type bs_type,
                database_name as bs_dbname
            FROM msdb.dbo.backupset b JOIN @mssql_backup on b.database_name = @mssql_backup.db_name
                LEFT OUTER JOIN sys.databases db ON b.database_name = db.name 
                LEFT OUTER JOIN sys.dm_hadr_database_replica_states rep ON db.database_id = rep.database_id 
            WHERE (rep.is_local is null or rep.is_local = 1) 
                AND (rep.is_primary_replica is null or rep.is_primary_replica = 'True') and b.machine_name = SERVERPROPERTY('Machinename')
            GROUP BY b.type, rep.replica_id, rep.is_primary_replica, rep.is_local, b.database_name, b.machine_name, rep.synchronization_state, rep.synchronization_health
        ) bs on bs_dbname = db_name
END

select * from @mssql_backup;

