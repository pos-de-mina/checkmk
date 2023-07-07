-- exit if instance isn't part of an cluster
if SERVERPROPERTY('IsClustered') = 0 return;

set nocount on;

declare @nodes varchar(max)
SELECT @nodes = STUFF(
    (SELECT ', ' + nodename
     FROM sys.dm_os_cluster_nodes
     FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
-- print @nodes
SELECT 
    isnull(serverproperty('InstanceName'),'MSSQLSERVER'),
    replace(db_name(),' ', '_'),
    SERVERPROPERTY('ComputerNamePhysicalNetBIOS'),
    @nodes
