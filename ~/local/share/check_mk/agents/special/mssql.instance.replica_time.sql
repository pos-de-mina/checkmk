/*
    https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/monitor-availability-groups-transact-sql
    https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-hadr-database-replica-states-transact-sql
*/

IF OBJECT_ID('dm_hadr_database_replica_states', 'V') IS NULL return;

set nocount on;
select '<<<mssql_replica_time:sep(124)>>>';

SELECT
    isnull(serverproperty('InstanceName'),'MSSQLSERVER'),
    CAST(DB_NAME(database_id)as VARCHAR(40)) database_name,
    (redo_queue_size/redo_rate) [estimated_recovery_time_seconds]
FROM
    sys.dm_hadr_database_replica_states drs
    INNER JOIN sys.availability_replicas ar on drs.replica_id = ar.replica_id AND drs.group_id = ar.group_id
WHERE
    last_redone_time is not null;
