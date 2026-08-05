param(
    [switch]$listTenants,
    [ValidateSet('VBR', 'Agent', 'MS365')]
    [string[]]$allLicenses,
    [string]$TenantLicences,
    [ValidateSet('VBR', 'Agent', 'MS365')]
    [string[]]$licenseType,
    [Alias('debug')]
    [switch]$DebugOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$includesPath = Join-Path $scriptRoot 'veeamVSCPtoPRTG_Includes'

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
