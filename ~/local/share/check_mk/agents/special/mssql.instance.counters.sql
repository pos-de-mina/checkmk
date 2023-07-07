/*
    https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql
    https://www.sqlshack.com/troubleshooting-sql-server-issues-sys-dm_os_performance_counters/
    https://www.red-gate.com/simple-talk/databases/sql-server/performance-sql-server/sql-server-performance-monitor-data-introduction-and-usage/
    https://www.mssqltips.com/sqlservertip/6945/windows-performance-monitor-counters-for-sql-server/
    https://www.mssqltips.com/sqlservertutorial/9191/windows-performance-monitor-template/
*/
set nocount on;

select 
    'None',
    'utc_time',
    'None',
    convert(varchar,getutcdate(),20);

select
    replace(replace(rtrim(object_name),'$',''),' ','_'),
    replace(lower(rtrim(counter_name)),' ','_'),
    case
        when instance_name in (null,'') then 'None'
        else replace(rtrim(instance_name),' ','_')
    end,
    cntr_value
from
    sys.dm_os_performance_counters
where
    object_name not like '%Deprecated%'
    -- white list
    and counter_name in (
        'Forwarded Records/sec',
        'Full scans/sec',
        'Page Splits/Sec',
        'Buffer Cache hit ratio',
        'Checkpoint Pages/Sec',
        'Page life expectancy',
        'User Connections',
        'Average Wait Time (ms)',
        'Lock Waits/Sec',
        'Memory Grants Pending',
        'Target Server Memory (KB)',
        'Total Server Memory (KB)',
        'Batch Requests/Sec',
        'SQL Compilations/Sec',
        'SQL Re-Compilations/Sec'
    );
