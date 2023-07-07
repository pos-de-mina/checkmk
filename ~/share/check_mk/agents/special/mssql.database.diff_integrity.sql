-- exclusions
if db_name() in ('tempdb') return;

set nocount on;
select '<<<mssql_diff_integrity:sep(124)>>>';

declare @dbinfo table (
    [ParentObject] varchar(255),
	[Object] varchar(255),
	[Field] varchar(255),
	[Value] varchar(255)
);

insert into @dbinfo
    exec('DBCC DBINFO() WITH TABLERESULTS, NO_INFOMSGS;');

select
    cast(isnull(serverproperty('InstanceName'),'MSSQLSERVER') as varchar) + " " + cast(db_name() as varchar),
    datediff(d, Value, GETDATE()) as last_dbcc_date
from
    @dbinfo
where
    Field = 'dbi_dbccLastKnownGood';
