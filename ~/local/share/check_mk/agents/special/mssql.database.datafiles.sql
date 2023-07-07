-- https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-files-transact-sql

set nocount on;

SELECT 
    isnull(serverproperty('InstanceName'),'MSSQLSERVER'),
    replace(db_name(),' ', '_'),
    replace(name,' ', '_'),
    replace(physical_name,' ', '_'),
    cast(max_size/128 as bigint),
    cast(size/128 as bigint) ,
    cast(FILEPROPERTY (name, 'spaceused')/128 as bigint),
    case when max_size = '-1' then '1' else '0' end
FROM sys.database_files
WHERE type_desc = 'ROWS'
