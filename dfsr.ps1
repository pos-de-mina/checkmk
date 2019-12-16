<#
#>

Get-Module -ListAvailable DFSR -ErrorAction Stop | Import-Module

#
# verfiy if DFSR Role are installed
#
$x = Get-Service DFSR -ErrorAction Stop 
$x = Get-Process -Name dfsrs -ErrorAction Stop

# -------------------------------------
# DFSR metabase
# https://msdn.microsoft.com/en-us/library/bb540019%28v=vs.85%29.aspx

"<<<dfsr:sep(9)>>>"
Get-CimInstance -ClassName DfsrReplicatedFolderInfo -Namespace Root\MicrosoftDfs | select ReplicationGroupName,ReplicatedFolderName,State | % {
    $state=''
    
    switch ($_.State) {
        0 {$state='Uninitialized'}
        1 {$state='Initialized'}
        2 {$state='Initial Sync'}
        3 {$state='Auto Recovery'}
        4 {$state='Normal'}
        5 {$state='In Error'}
    }
    "$($_.ReplicationGroupName)\$($_.ReplicatedFolderName)`t$($state)"
}
