-- https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-hadr-database-replica-states-transact-sql

IF OBJECT_ID('dm_hadr_database_replica_states', 'V') IS NULL return;
if serverproperty('InstanceName') is null return;

set nocount on;
select '<<<mssql_synchronizationhealth:sep(124)>>>';

SELECT DISTINCT 
    rcs.database_name,
    ar.replica_server_name,
    --drs.synchronization_state_desc,
    drs.synchronization_health_desc --,
    --CASE rcs.is_failover_ready
    --    WHEN 0 THEN 'Data Loss'
    --    WHEN 1 THEN 'No Data Loss'
    --    ELSE ''
    --END AS FailoverReady
FROM
    sys.dm_hadr_database_replica_states drs 
    INNER JOIN sys.availability_replicas ar on drs.replica_id = ar.replica_id AND drs.group_id = ar.group_id
    INNER JOIN sys.dm_hadr_database_replica_cluster_states rcs ON drs.replica_id = rcs.replica_id
ORDER BY
    replica_server_name;
