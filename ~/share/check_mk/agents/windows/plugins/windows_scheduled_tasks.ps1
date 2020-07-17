<#
    Retrive all Scheduled Taks from Windows and format to Check_MK native output.

    Author: António Pós-de-Mina
    Release Date: 2015-07-08
#>

# service header
echo "<<<windows_scheduled_tasks:sep(9)>>>"

#
# Test OS version according official article
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms724832(v=vs.85).aspx
#
[float]$version = [System.Environment]::OSVersion.Version.Major + ([System.Environment]::OSVersion.Version.Minor * 0.1)

# Windows Server 2008, Windows Server 2008 R2, Windows Server 2012, Windows Server 2012 R2
if ($version -ge [float]6.0) {

    Get-ScheduledTask |
    Where-Object {
        $_.TaskPath -notlike '\Microsoft\Windows\*' -and $_.State -notin ('Disabled') -and $_.TaskName -notlike '*S-1-5-21*'
    } |
    Get-ScheduledTaskInfo |
    select TaskPath, TaskName, LastTaskResult, LastRunTime, NextRunTime |
    sort TaskPath, TaskName |
    ForEach-Object {
        #Write-Output ('{0}{1}`t{2}`t{3:s}`t{4:s}' -f $_.TaskPath, $_.TaskName.replace(' ', ''), $_.LastTaskResult, $_.LastRunTime,$_.NextRunTime)
        Write-Output "$($_.TaskPath)$($_.TaskName.replace(' ', '')) $($_.LastTaskResult) $($_.LastRunTime.toString('s')) $(if($_.NextRunTime){$_.NextRunTime.toString('s')}else{'-'})"
    }

<# Windows Server 2003, Windows Server 2003 R2
} elseif ($version -ge [float]5.2) {

    # Win32_ScheduledJob class: http://msdn.microsoft.com/en-us/library/aa394399(v=vs.85).aspx
    Get-WmiObject -Class Win32_ScheduledJob |
    Where-Object {
        $_.TaskName -notlike '\Microsoft\Windows\*'
    } |
    Format-Table Name, State -AutoSize -HideTableHeaders
#>
} else {
    echo 'NotSupported'
}
