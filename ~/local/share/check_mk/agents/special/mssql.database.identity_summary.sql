/*
    https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-identity-columns-transact-sql
    https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-columns-transact-sql
    https://learn.microsoft.com/en-us/sql/t-sql/data-types/int-bigint-smallint-and-tinyint-transact-sql
    https://learn.microsoft.com/en-us/sql/t-sql/functions/type-id-transact-sql
*/
-- exclude databases
if db_name() IN ('master','msdb','model','Resource','tempdb','DBADatabase','dba_database') or db_name() LIKE '%ReportServer%' or db_name() LIKE '%_APARENTEMENTE_NAO_USADA_%'
    return;

set nocount on;
select '<<<mssql_identity_summary:sep(124)>>>';

declare @ColumnMaxSize table (
    ColumnID tinyint,
    ColumnMaxSize bigint
);
insert into @ColumnMaxSize(ColumnID,ColumnMaxSize) values(127,9223372036854775807);
insert into @ColumnMaxSize(ColumnID,ColumnMaxSize) values(56,2147483647);
insert into @ColumnMaxSize(ColumnID,ColumnMaxSize) values(52,32767);
insert into @ColumnMaxSize(ColumnID,ColumnMaxSize) values(48,255);

declare @MSSQLIdentity table (
    SchemaName varchar(max),
    TableName varchar(max),
    ColumnName varchar(max),
    IdentityLastValue bigint,
    IdentityMaxValue bigint,
    IdentityPercentageUsage tinyint
);
insert into @MSSQLIdentity (SchemaName,TableName,ColumnName,IdentityLastValue,IdentityMaxValue,IdentityPercentageUsage)
select
    cast(schema_name(t.schema_id) as varchar(max)),
    cast(t.name as varchar(max)),
    cast(c.name as varchar(max)),
    cast(c.last_value as bigint),
    cs.ColumnMaxSize,
    (1.0 * cast(c.last_value as float) / cs.ColumnMaxSize * 100.0)
from
    sys.identity_columns as c
    inner join sys.tables as t on t.object_id = c.object_id
    join @ColumnMaxSize cs on cs.ColumnID = c.system_type_id
where
    c.last_value is not null
    and c.system_type_id is not null
    and c.is_identity = 1
    and t.type = 'u';

declare @TotalIdentity int, @TotalIdentityOver80Percent int, @TotalIdentityOver90Percent int;
select @TotalIdentity = count(*) from @MSSQLIdentity;
select @TotalIdentityOver80Percent = count(*) from @MSSQLIdentity where IdentityPercentageUsage >= 80 and IdentityPercentageUsage < 90;
select @TotalIdentityOver90Percent = count(*) from @MSSQLIdentity where IdentityPercentageUsage >= 90;

declare
    @SummaryIdentityOver80Percent varchar(max),
    @SummaryIdentityOver90Percent varchar(max),
    @SchemaName varchar(max),
    @TableName varchar(max),
    @ColumnName varchar(max),
    @IdentityLastValue bigint;
set @SummaryIdentityOver80Percent = ''
set @SummaryIdentityOver90Percent = ''

declare idd cursor for
    select top 10 SchemaName,TableName,ColumnName,IdentityLastValue
    from @MSSQLIdentity
    where IdentityPercentageUsage >= 80 and IdentityPercentageUsage < 90;
OPEN idd
FETCH NEXT FROM idd 
INTO @SchemaName,@TableName,@ColumnName,@IdentityLastValue
WHILE @@FETCH_STATUS = 0
BEGIN
    set @SummaryIdentityOver80Percent = @SummaryIdentityOver80Percent + @SchemaName + '.' + @TableName + '.' + @ColumnName + ': ' + cast(@IdentityLastValue as varchar);
    FETCH NEXT FROM idd INTO @SchemaName,@TableName,@ColumnName,@IdentityLastValue
END
CLOSE idd
DEALLOCATE idd

declare idd cursor for
    select top 10 SchemaName,TableName,ColumnName,IdentityLastValue
    from @MSSQLIdentity
    where IdentityPercentageUsage >= 90;
OPEN idd
FETCH NEXT FROM idd 
INTO @SchemaName,@TableName,@ColumnName,@IdentityLastValue
WHILE @@FETCH_STATUS = 0
BEGIN
    set @SummaryIdentityOver90Percent = @SummaryIdentityOver90Percent + @SchemaName + '.' + @TableName + '.' + @ColumnName + ': ' + cast(@IdentityLastValue as varchar);
    FETCH NEXT FROM idd INTO @SchemaName,@TableName,@ColumnName,@IdentityLastValue
END
CLOSE idd
DEALLOCATE idd

if @SummaryIdentityOver80Percent is null
    set @SummaryIdentityOver80Percent = ''
if @SummaryIdentityOver90Percent is null
    set @SummaryIdentityOver90Percent = ''

select serverproperty('instancename'),db_name(),@TotalIdentity,@TotalIdentityOver80Percent,@TotalIdentityOver90Percent,@SummaryIdentityOver80Percent,@SummaryIdentityOver90Percent
