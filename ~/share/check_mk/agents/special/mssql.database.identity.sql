-- exclude databases
if db_name() IN ('master','msdb','model','Resource','tempdb','DBADatabase','dba_database') or db_name() LIKE '%ReportServer%' or db_name() LIKE '%_APARENTEMENTE_NAO_USADA_%'
    return;

set nocount on;
select '<<<mssql_identity:sep(124)>>>';

SELECT
    cast(serverproperty('instancename') as varchar) + '.' + cast(DB_NAME() as varchar) + '.' + cast(SCHEMA_NAME(t.schema_id) as varchar) + '.' + t.name + '.' + c.name,
    c.last_value as last_identity,
    CASE c.system_type_id
        WHEN 127 THEN '9223372036854775807' -- bigint
        WHEN 56 THEN '2147483647' -- int
        WHEN 52 THEN '32767' -- smallint
        WHEN 48 THEN '255' -- tinyint
    END AS max_identity
FROM
    sys.identity_columns AS c
    INNER JOIN sys.tables AS t ON t.object_id = c.object_id
WHERE
    c.last_value IS NOT NULL
    AND c.system_type_id IS NOT NULL
    AND c.is_identity = 1
    AND t.type = 'U'
    -- white list
    and t.name in ('')
ORDER BY 1;
