<#
# Custom made novobanco status for maintenance
#
# (c) 2022-02 António Pós-de-Mina
#>
param (
    # File needed 
    $ka = "D:\services\kalive\ka-all.txt",
    $active_dir = 'D:\Services\kalive\active',
    $inactive_dir = 'D:\Services\kalive\inactive'
)

try {
    # get sites
    Import-Module WebAdministration -ErrorAction Stop
    $iis_sites = Get-ChildItem -Path IIS:\Sites

    if (Test-Path -Path $ka) {

        '<<<iis_ka:sep(9)>>>'
        Import-Csv -Delimiter ' ' -Path $ka -ErrorAction Stop | % {

            $ka = [PSCustomObject]@{
                Site = $_.site
                Status = $null
                Active = $false
                Inactive = $false
            }

            # get site status
            $ka.Status = ($iis_sites | Where-Object { $_.Name -eq $ka.Site }).State

            # verify if file is in active directory
            if (Test-Path (Join-Path -Path $active_dir $_.ka)) {
                $ka.Active = $true
            }

            if (Test-Path (Join-Path -Path $inactive_dir $_.ka)) {
                $ka.Inactive = $true
            }

            # out result
            "$($ka.Site)`t$($ka.Status)`t$($ka.Active)`t$($ka.Inactive)"
        }
        '<<<>>>'
    }
}
catch {
    # nothing
}