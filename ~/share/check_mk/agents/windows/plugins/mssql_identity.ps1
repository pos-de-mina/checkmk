<#
 # Plugin for Inventory MSSQL IDENTITY Column
 #
 # ~/share/check_mk/agents/windows/plugins/mssql_identity.ps1
 # https://github.com/pos-de-mina
 #>

# field separator "|"
$field_separator = 124

function Get-MSSQLIdentity($Context, $Database) {
    $Command = $Context.Connection.CreateCommand()
    try {
        $Command.CommandText = @"
USE $($Database.DatabaseName)
SELECT
    serverproperty('instancename') as instance_name,
    DB_NAME () as db_name,
    SCHEMA_NAME(t.schema_id) as schema_name,
    t.name as table_name,
    c.name as column_name,
    c.last_value as last_identity,
    CASE c.system_type_id
        -- bigint
        WHEN 127 THEN '9223372036854775807'
        -- int
        WHEN 56 THEN '2147483647'
        -- smallint
        WHEN 52 THEN '32767'
        -- tinyint
        WHEN 48 THEN '255'
    END AS max_identity
FROM
    sys.identity_columns AS c
    INNER JOIN sys.tables AS t ON t.[object_id] = c.[object_id]
WHERE
    c.last_value IS NOT NULL
    AND c.system_type_id IS NOT NULL
    AND c.is_identity = 1
    AND t.type = 'U'
ORDER BY 2, 4
"@
        $Reader = $Command.ExecuteReader()
        try {
            $Reader | ForEach-Object {

                $_[0] + '.' + $_[1] + '.' + $_[2] + '.' + $_[3] + '.' + $_[4] + [char]$field_separator + $_[5] + [char]$field_separator + $_[6]
            }
        }
        catch {
            #$_
        }
        finally {
            if ($Reader) { $Reader.Dispose() }
        }
    }
    catch {
        #$_
    }
    finally {
        if ($Command) { $Command.Dispose() }
    }
}

function Get-MSSQLDatabases($Context) {
    $Command = $Context.Connection.CreateCommand()
    try {
        $Command.CommandText = @"
SELECT name AS database_name
FROM sys.databases AS d
WHERE
    d.name NOT IN ('master', 'msdb', 'model', 'Resource', 'tempdb')
    AND d.name NOT LIKE '%ReportServer%'
    AND d.name NOT IN ('DBADatabase', 'dba_database')
"@
        $Reader = $Command.ExecuteReader()
        try {
            $Reader |
            ForEach-Object {
                [PSCustomObject]@{
                    DatabaseName        = $_[0];
                    EscapedDatabaseName = $_[0] -replace ' ', '_'
                }
            }
        }
        catch {
        }
        finally {
            if ($Reader) { $Reader.Dispose() }
        }
    }
    catch {
    }
    finally {
        if ($Command) { $Command.Dispose() }
    }
}


# -----------------------------------------------------------------------------


# redifine screen buffer
try {
    (Get-Host).UI.RawUI.BufferSize = New-Object -TypeName System.Management.Automation.Host.Size(150, 9999)
} catch {}

# Inventory MSSQL Instances 
$Contexts = Get-WmiObject -ComputerName $env:COMPUTERNAME -Namespace root -Class __NAMESPACE -Property Name, __NAMESPACE | Where-Object {
    $_.Name -eq 'Microsoft'
} | ForEach-Object {
    Get-WmiObject -ComputerName $env:COMPUTERNAME -Namespace "$($_.__NAMESPACE)\$($_.Name)" -Class __NAMESPACE -Property Name, __NAMESPACE
} | Where-Object {
    $_.Name -eq 'SqlServer'
} | ForEach-Object {
    Get-WmiObject -ComputerName $env:COMPUTERNAME -Namespace "$($_.__NAMESPACE)\$($_.Name)" -Class __NAMESPACE -Property Name, __NAMESPACE
} | Where-Object {
    $_.Name -like 'ComputerManagement*'
} | ForEach-Object {
    Get-WmiObject -ComputerName $env:COMPUTERNAME -Namespace "$($_.__NAMESPACE)\$($_.Name)" -Class SqlServiceAdvancedProperty -Filter 'SQLServiceType = 1 AND PropertyName = "VERSION"' |
    % {
        $Context = [PSCustomObject]@{
            InstanceId          = $_.ServiceName -replace '\$', '_';
            ServiceName         = $_.ServiceName;
            InstanceName        = $null;
            DatabaseName        = $null;
            EscapedDatabaseName = $null;
            Connection          = $null;
            ComputerName        = $env:COMPUTERNAME;
            Version             = $_.PropertyStrValue
        }
        $Context.InstanceName = $(if ($_.ServiceName -eq 'MSSQLSERVER') { $null } else { ($_.ServiceName -split '\$' | Select-Object -Last 1) })

        $Context
    }
}

$Contexts | ForEach-Object {
    $Context = $_
    Get-WmiObject -ComputerName $Context.ComputerName -Class Win32_Service -Filter "Name = '$($Context.ServiceName)' and State = 'Running'" |
    ForEach-Object {
        $Context.Connection = New-Object -TypeName System.Data.SqlClient.SqlConnection "Data Source=$($Context.ComputerName)$(if($Context.InstanceName){"\$($Context.InstanceName)"});Integrated Security=True"
        try {
            #'<<<<' + $Context.InstanceName + '_' + $Context.ComputerName + '>>>>'
            $Context.Connection.Open()

            $Databases = Get-MSSQLDatabases -Context $Context

            '<<<mssql_identity:sep(' + $field_separator + ')>>>'
            $Databases | ForEach-Object {
                Get-MSSQLIdentity -Context $Context -Database $_
            }
            #'<<<<>>>>'
        }
        catch {
        }
        finally {
            if ($_.Connection) { $_.Connection.Dispose() }
        }
    }
}
