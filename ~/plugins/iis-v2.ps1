<# Performance counter

get-counter -listset * | select -ExpandProperty Counter

CounterSetName
--------------
? HTTP Service
? HTTP Service Url Groups
HTTP Service Request Queues
APP_POOL_WAS
? Microsoft FTP Service
? IPHTTPS Global
? IPHTTPS Session
WAS_W3WP
W3SVC_W3WP
? Active Server Pages
? ASP.NET
? ASP.NET Applications
? ASP.NET State Service
#>
try {
    Import-Module WebAdministration -ErrorAction Stop

    '<<<local:sep(9)>>>'
    #'<<<>>>'
    # CMK service variables
    $cmk_service = @{
        # Unknown
        State = 3;
        Name = '';
        PerfData = '';
        Output = '';
    }
    $cmk_state = 3
    $cmk_name = ''
    $cmk_perfdata = ''
    $cmk_output = ''

    # get counters
    $counters = Get-Counter -Counter (
        "\W3SVC_W3WP(*)\% 500 HTTP Response Sent",
        "\W3SVC_W3WP(*)\% 404 HTTP Response Sent",
        "\W3SVC_W3WP(*)\% 403 HTTP Response Sent",
        "\W3SVC_W3WP(*)\% 401 HTTP Response Sent",
        "\ASP.NET Applications(*)\Requests/Sec",
        "\ASP.NET Applications(*)\Requests in Application Queue",
        "\.NET CLR Memory(*)\% Time in GC",
        "\.NET CLR Exceptions(*)\# of Exceps Thrown",
        "\ASP.NET Applications(*)\Errors Unhandled During Execution/sec",
        "\ASP.NET Applications(*)\Errors Total/Sec"
        ) -ErrorAction SilentlyContinue | 
    Select-Object -ExpandProperty CounterSamples

    # get AppPools e exclui os .NET
    Get-ChildItem IIS:\AppPools -Exclude '*.NET*' | ForEach-Object {
        $IISAppPool = $_.Name
        $cmk_perfdata = ''
        $i = 0

        $counters | Where-Object { $_.InstanceName -like "*$IISAppPool*" } | 
        ForEach-Object {
            # extract metric name only
            $counter = (($_.Path -replace ' ', '_') -split '\\')[-1]
            $value = $_.CookedValue
            if ($i -gt 0) {
                $cmk_perfdata += '|'
            }
            $cmk_perfdata += "$counter=$value"
            $i++
        }

        $cmk_state = 0
        if ($_.state -ne 'Started') {
            $cmk_state = 2
        }

        $cmk_name = "IIS AppPool $IISAppPool"
        $cmk_output = "State: $($_.state); QueueLength; $($_.queueLength); ManagedRuntimeVersion: $($_.managedRuntimeVersion);"
        "$cmk_state`t$cmk_name`t$cmk_perfdata`t$cmk_output"
    }


    # -------------------------------------
    # IIS Sites

    $cmk_state = 3
    $cmk_name = ''
    $cmk_perfdata = '-'
    $cmk_output = ''

    $counters = Get-Counter -Counter (
        "\Web Service(*)\bytes sent/sec", 
        "\Web Service(*)\bytes received/sec", 
        "\Web Service(*)\current connections"
        ) -ErrorAction SilentlyContinue | 
    Select-Object -ExpandProperty CounterSamples

    Get-ChildItem -Path IIS:\Sites | ForEach-Object {
        $IISAppPool = $_.Name
        $cmk_perfdata = '-'
        $i = 0

        $counters | Where-Object { $_.InstanceName -like "*$IISAppPool*" } | 
        ForEach-Object {
            # extract metric name only
            $counter = (($_.Path -replace ' ', '_') -split '\\')[-1]
            $value = $_.CookedValue
            if ($i -gt 0) {
                $cmk_perfdata += '|'
            }
            $cmk_perfdata += "$counter=$value"
            $i++
        }

        $cmk_state = 0
        if ($_.state -ne 'Started') {
            $cmk_state = 2
        }
        $cmk_name = "IIS Site $($_.name)"
        $cmk_output = "ApplicationPool: $($_.applicationPool); EnabledProtocols: $($_.enabledProtocols); PhysicalPath: $($_.physicalPath); State: $($_.state);"
        "$cmk_state`t$cmk_name`t$cmk_perfdata`t$cmk_output"
    }
    '<<<>>>'
}
catch {
    # nothing
}