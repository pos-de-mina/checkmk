set nocount on;
select '<<<mssql_databaseavailabilitystate:sep(124)>>>';

SELECT
    isnull(serverproperty('InstanceName'),'MSSQLSERVER'),
    d.name,
    d.state_desc
FROM
    master.sys.databases d left join
    master.sys.database_mirroring m ON m.database_id = d.database_id
WHERE
    d.database_id > 4 AND m.mirroring_state_desc IS NULL;
