-- https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-files-transact-sql

set nocount on;

SELECT 
    cast(isnull(serverproperty('InstanceName'),'MSSQLSERVER') as varchar),
    replace(db_name(),' ','_'),
    replace(name,' ','_'), 
    replace(physical_name,' ','_'),
    cast(max_size/128 as bigint) as MaxSize,
    cast(size/128 as bigint) as AllocatedSize,
    cast(FILEPROPERTY (name, 'spaceused')/128 as bigint) as UsedSize,
    case when max_size = '-1' then '1' else '0' end as Unlimited
FROM sys.database_files 
WHERE type_desc = 'LOG'
