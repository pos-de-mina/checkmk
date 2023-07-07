set nocount on;
:setvar SQLCMDHEADERS -1
:setvar SQLCMDCOLSEP |
select '<<<mssql_jobstatus:sep(124)>>>';

select
    isnull(serverproperty('InstanceName'),'MSSQLSERVER'),
    j.[name] as [JobName] ,
    case h.run_status
        when 0 then 'Failed'
        when 1 then 'Succeeded'
        when 2 then 'Retry'
        when 3 then 'Canceled'
        when 4 then 'In progress'
    end as run_status ,
    h.run_date as LastRunDate ,
    h.run_time as LastRunTime
from
    msdb.dbo.sysjobhistory h
    inner join msdb.dbo.sysjobs j
        on h.job_id = j.job_id
where
    j.enabled = 1
    and h.instance_id in (
        select
            max(h.instance_id)
        from
            msdb.dbo.sysjobhistory h
        group by
            (h.job_id)
    )