-- https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-file-audits-transact-sql

IF OBJECT_ID('sys.server_file_audits') IS NULL return;

set nocount on;
select '<<<mssql_fileaudits:sep(124)>>>';

-- ------------------------------------
-- get file audits info

declare @audit_fileaudits table (
    audit_path varchar(max),
    audit_name varchar(max),
    audit_max_files int,
    audit_total_files int
)
insert into
    @audit_fileaudits(audit_path,audit_name,audit_max_files)
SELECT
    log_file_path, name, max_rollover_files
FROM
    sys.server_file_audits
WHERE 
    max_rollover_files < 2147483647 and is_state_enabled = 1


declare @audit_path varchar(8000), @audit_name varchar(max)
declare c cursor for
    SELECT audit_path, audit_name
    FROM @audit_fileaudits
open c
fetch next from c into @audit_path, @audit_name
while @@fetch_status = 0  
begin
    declare @filescount int
    declare @audit_files table (
        audit_filename varchar(MAX),
        x1 int,
        x2 int
    )
    INSERT @audit_files (audit_filename, x1, x2)
    exec master.sys.xp_dirtree @audit_path,1,1;

    select @filescount = count(*)
    from @audit_files
    where audit_filename like @audit_name + '%.sqlaudit'

    -----------------------------------
    update @audit_fileaudits
    set audit_total_files = @filescount
    where audit_path = @audit_path and audit_name = @audit_name

    fetch next from c into @audit_path, @audit_name
end
close c;
deallocate c; 

select
    cast(isnull(serverproperty('InstanceName'),'MSSQLSERVER') as varchar(max)) + ' ' + audit_path + audit_name, 
    audit_max_files, 
    audit_total_files
from
    @audit_fileaudits
