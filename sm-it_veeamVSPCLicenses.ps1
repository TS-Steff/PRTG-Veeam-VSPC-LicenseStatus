param(
    [switch]$listTenants,
    [ValidateSet('VBR', 'Agent', 'MS365', 'CC')]
    [string[]]$allLicenses,
    [string]$TenantLicences,
    [ValidateSet('VBR', 'Agent', 'MS365', 'CC')]
    [string[]]$licenseType,
    [Alias('debug')]
    [switch]$DebugOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$includesPath = Join-Path $scriptRoot 'sm-it_veeamVSPCLicenses_Includes'

. (Join-Path $includesPath 'config.ps1')
. (Join-Path $includesPath 'functions.ps1')

if ($listTenants) {
    Write-Verbose ("Using VSPC endpoint: {0}" -f $VeeamBaseUri)
    $tenants = @(get-AllOrgs | Sort-Object name)

    if ($tenants.Count -eq 0) {
        Write-Error 'No tenants were returned by the VSPC API.'
    }

    $tenants |
        Select-Object name, instanceUid |
        Format-Table -AutoSize

    exit 0
}

if ($allLicenses) {
    Write-Verbose ("Using VSPC endpoint: {0}" -f $VeeamBaseUri)
    $allLicenseOverview = Get-AllLicenseOverview -LicenseType $allLicenses

    if ($DebugOutput) {
        Show-AllLicenseOverviewDebug -LicenseOverview $allLicenseOverview -LicenseType $allLicenses
    }
    else {
        $selectedTypes = @($allLicenses)
        if ($selectedTypes.Count -ne 1) {
            throw 'PRTG Advanced XML output for -allLicenses requires exactly one value.'
        }

        switch ($selectedTypes[0]) {
            'VBR' {
                Write-Output (Convert-VbrLicenseOverviewToPrtgXml -LicenseOverview $allLicenseOverview -IncludeText:$false -IncludeTenantInChannel)
            }
            'Agent' {
                Write-Output (Convert-AgentLicenseOverviewToPrtgXml -LicenseOverview $allLicenseOverview -IncludeText:$false -IncludeTenantInChannel)
            }
            'MS365' {
                Write-Output (Convert-Ms365LicenseOverviewToPrtgXml -LicenseOverview $allLicenseOverview -IncludeText:$false -IncludeTenantInChannel)
            }
            'CC' {
                Write-Output (Convert-CloudConnectLicenseOverviewToPrtgXml -LicenseOverview $allLicenseOverview -IncludeText:$false)
            }
        }
    }

    exit 0
}

if ($TenantLicences) {
    Write-Verbose ("Using VSPC endpoint: {0}" -f $VeeamBaseUri)
    $licenseOverview = Get-TenantLicenseOverview -TenantName $TenantLicences -LicenseType $licenseType

    if ($DebugOutput) {
        Show-TenantLicenseOverviewDebug -LicenseOverview $licenseOverview -LicenseType $licenseType
    }
    else {
        $selectedTypes = @($licenseType)
        if ($selectedTypes.Count -ne 1) {
            throw 'PRTG Advanced XML output requires exactly one value for -licenseType.'
        }

        if ($selectedTypes[0] -eq 'CC') {
            throw 'Cloud Connect licenses are provider-level. Use -allLicenses CC instead of -TenantLicences ... -licenseType CC.'
        }

        switch ($selectedTypes[0]) {
            'VBR' {
                Write-Output (Convert-VbrLicenseOverviewToPrtgXml -LicenseOverview $licenseOverview)
            }
            'Agent' {
                Write-Output (Convert-AgentLicenseOverviewToPrtgXml -LicenseOverview $licenseOverview)
            }
            'MS365' {
                Write-Output (Convert-Ms365LicenseOverviewToPrtgXml -LicenseOverview $licenseOverview)
            }
        }
    }

    exit 0
}





