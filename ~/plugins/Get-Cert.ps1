 Get-ChildItem -Recurse Cert:\ | ? { $_.NotAfter -ne $null } | % {
    
    $cert = [PSCustomObject]@{
        CertFriendlyName = $_.Name + $_.FriendlyName;
        CertSubject = $_.Subject;
        CertPath = $_.PSPath;
        CertExpiresDate = $_.NotAfter;
        CertAgeInDays = (New-TimeSpan -End $_.NotAfter).Days
    }

    $AgeInDays = (New-TimeSpan -End $_.NotAfter).Days
    Write-Host "P`tCert $($_.FriendlyName)`tCertAge=$($AgeInDays);90;30`tSubject: $($_.Subject); Path: $($_.PSPath); Expires Date: $($_.NotAfter); Age In Days: $($AgeInDays)"
}
 
