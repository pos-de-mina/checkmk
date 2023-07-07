<#
    https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-spaceused-transact-sql
#>
function Get-MSSQLDatabaseTablespaces($Instance, $Database) {
    try {
        $cmd = @"
set nocount on;
:setvar SQLCMDHEADERS -1
:setvar SQLCMDCOLSEP |
select isnull(serverproperty('InstanceName'),'MSSQLSERVER');
exec sp_spaceused;
"@
        Set-Content -Value '<<<mssql_tablespaces:sep(124)>>>' -Path "C:\ProgramData\checkmk\agent\spool\mssql.database.tablespaces.$($Instance).$($Database).log"
        $out = $(&sqlcmd -S ".\$Instance", -d $Database -E -W -w 1024 -Q $cmd) -join '|'
        $out = $out -replace ' KB', '|KB'
        $out = $out -replace ' MB', '|MB'
        $out = $out -replace ' GB', '|GB'
        $out = $out -replace ' TB', '|TB'
        Add-Content -Value $out -Path "C:\ProgramData\checkmk\agent\spool\mssql.database.tablespaces.$($Instance).$($Database).log"
    }
    catch {
        Write-Host "<<<error>>>`nError in plugin: $PSCommandPath!`n$($Error)`n<<<>>>"
    }
}
