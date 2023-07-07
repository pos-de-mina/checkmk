-- https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-spaceused-transact-sql
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/string-functions-transact-sql?view=sql-server-ver16

-- ----------------------------------------------------------------------------
-- test version
-- https://learn.microsoft.com/en-us/troubleshoot/sql/releases/download-and-install-latest-updates
declare @ver varchar(16)
set @ver = cast(SERVERPROPERTY('ProductVersion') as varchar)
-- print @ver
declare @ver_major INT
set @ver_major = PARSENAME(@ver, 4)
-- print @ver_major
if @ver_major < 10 return;
-- ----------------------------------------------------------------------------

set nocount on;

declare  @spaceused table (
    database_name nvarchar(128),
    database_size varchar(18),
    unallocated_space varchar(18),
    reserved varchar(18),
    data varchar(18),
    index_size varchar(18),
    unused varchar(18)
)

insert into @spaceused
exec sp_spaceused @oneresultset = 1;
select
    'MSSQL_' + cast(isnull(serverproperty('InstanceName'),'MSSQLSERVER') as varchar),
    database_name,
    replace(database_size,' ','|'),
    replace(unallocated_space,' ','|'),
    replace(reserved,' ','|'),
    replace(data,' ','|'),
    replace(index_size,' ','|'),
    replace(unused,' ','|')
from @spaceused
