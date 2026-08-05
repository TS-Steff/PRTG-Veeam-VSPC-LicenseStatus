function Invoke-VspcGet($Path) {
    $uri = $VeeamBaseUri.TrimEnd('/') + '/' + $Path.TrimStart('/')
    try {
        $response = Invoke-WebRequest -Uri $uri -Method GET -Headers $veeamHeader -MaximumRedirection 0 -ErrorAction Stop
    }
    catch {
        $webResponse = $_.Exception.Response
        if ($null -ne $webResponse) {
            $statusCode = [int]$webResponse.StatusCode
            $location = $webResponse.Headers['Location']
            if ($location) {
                throw "VSPC request to '$uri' returned HTTP $statusCode and redirected to '$location'."
            }

            throw "VSPC request to '$uri' returned HTTP $statusCode."
        }

        throw
    }

    if (-not $response.Content) {
        return @()
    }

    return Get-VspcResponseData $response.Content
}

function Get-VspcResponseData($Response) {
    if ($null -eq $Response) {
        return @()
    }

    if ($Response -is [string]) {
        $trimmedResponse = $Response.Trim()

        if ($trimmedResponse.StartsWith('{') -or $trimmedResponse.StartsWith('[')) {
            try {
                $Response = $trimmedResponse | ConvertFrom-Json -Depth 100
            }
            catch {
                throw "VSPC API returned a JSON string that could not be parsed: $($_.Exception.Message)"
            }
        }
        else {
            $preview = if ($trimmedResponse.Length -gt 240) { $trimmedResponse.Substring(0, 240) + '...' } else { $trimmedResponse }
            throw "VSPC API returned a plain text response: $preview"
        }
    }

    $property = $Response.PSObject.Properties['data']
    if ($null -ne $property) {
        return $property.Value
    }

    $errorProperty = $Response.PSObject.Properties['errors']
    if ($null -ne $errorProperty -and $errorProperty.Value) {
        $messages = @($errorProperty.Value | ForEach-Object { $_.message }) -join '; '
        throw "VSPC API returned errors: $messages"
    }

    $responseType = $Response.GetType().FullName
    throw "VSPC API response does not contain a 'data' property. Response type: $responseType"
}

# ORG
function get-OrgByName($orgName){
    write-debug "get-OrgByName"
    $queryPath = 'organizations/companies?filter=[{"property":"name","operation":"equals","value":"' + $orgName + '"}]'
    return Invoke-VspcGet $queryPath
}

# AGENTS
function get-AgentsByOrgUID($orgUID){
    $queryPath = 'infrastructure/backupAgents?filter=[{"property":"organizationUid","operation":"equals","value":"' + $orgUID + '"}]'
    return Invoke-VspcGet $queryPath
}

function get-BackupAgentByUid($backupAgentUid){
    return Invoke-VspcGet ('infrastructure/backupAgents/' + $backupAgentUid)
}

# SERVERS
function get-ServersByOrgUID($orgUID){
    $queryPath = 'infrastructure/backupServers?filter=[{"property":"organizationUid","operation":"equals","value":"' + $orgUID + '"}]'
    return Invoke-VspcGet $queryPath
}

function get-BackupServerLicenseByUid($backupServerUid){
    return Invoke-VspcGet ('licensing/backupServers/' + $backupServerUid)
}

function get-Vb365ServersByOrgUID($orgUID){
    $queryPath = 'infrastructure/vb365Servers?filter=[{"property":"organizationUid","operation":"equals","value":"' + $orgUID + '"}]'
    return Invoke-VspcGet $queryPath
}

function get-Vb365LicenseByUid($vb365ServerUid){
    return Invoke-VspcGet ('licensing/vb365Servers/' + $vb365ServerUid)
}

function get-CloudConnectSites{
    return Invoke-VspcGet 'infrastructure/sites'
}

function get-CloudConnectSiteByUid($siteUid){
    return Invoke-VspcGet ('infrastructure/sites/' + $siteUid)
}

function get-CloudConnectSiteLicenseByUid($siteUid){
    return Invoke-VspcGet ('licensing/sites/' + $siteUid)
}

function get-CloudConnectTenantsByOrgUID($orgUID){
    $queryPath = 'infrastructure/sites/tenants?filter=[{"property":"assignedForCompany","operation":"equals","value":"' + $orgUID + '"}]'
    return Invoke-VspcGet $queryPath
}

function Get-CloudConnectLicenseOverview {
    $cloudConnectLicenses = @(
        foreach ($site in @(get-CloudConnectSites | Sort-Object siteName)) {
            $siteUid = [string](Get-OptionalPropertyValue $site @('siteUid', 'backupServerUid', 'instanceUid'))
            if ([string]::IsNullOrWhiteSpace($siteUid)) {
                continue
            }

            $license = get-CloudConnectSiteLicenseByUid $siteUid

            [pscustomobject]@{
                Status               = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('status'))
                Hostname             = ConvertTo-DisplayValue (Get-OptionalPropertyValue $site @('siteName', 'name', 'hostName'))
                'Cloud Connect'      = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('cloudConnect'))
                'License Expiration' = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('expirationDate'))
                Units                = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('units'))
                'Used Units'         = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('usedUnits'))
                'License ID'         = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('licenseId', 'licenseIds'))
            }
        }
    )

    return [pscustomobject]@{
        CloudConnectLicenses = $cloudConnectLicenses
    }
}

function Get-OptionalPropertyValue {
    param(
        $InputObject,
        [string[]]$PropertyNames
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($propertyName in $PropertyNames) {
        $property = $InputObject.PSObject.Properties[$propertyName]
        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function ConvertTo-DisplayValue {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Array]) {
        return ($Value -join ', ')
    }

    return $Value
}

function ConvertTo-XmlSafeText {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return [System.Security.SecurityElement]::Escape($Value)
}

function Get-NullableDouble {
    param($Value)

    if ($null -eq $Value -or $Value -eq '') {
        return $null
    }

    try {
        return [double]$Value
    }
    catch {
        return $null
    }
}

function Get-NullableDateTime {
    param($Value)

    if ($null -eq $Value -or $Value -eq '') {
        return $null
    }

    $stringValue = [string]$Value
    $formats = @(
        'dd.MM.yyyy HH:mm:ss',
        'd.MM.yyyy HH:mm:ss',
        'yyyy-MM-ddTHH:mm:ss',
        'yyyy-MM-ddTHH:mm:ssK',
        'yyyy-MM-dd HH:mm:ss',
        'M/d/yyyy h:mm:ss tt',
        'MM/dd/yyyy HH:mm:ss'
    )

    foreach ($format in $formats) {
        try {
            return [datetimeoffset]::ParseExact(
                $stringValue,
                $format,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeLocal
            )
        }
        catch {
        }
    }

    try {
        return [datetimeoffset]::Parse(
            $stringValue,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeLocal
        )
    }
    catch {
        try {
            return [datetimeoffset]::Parse($stringValue)
        }
        catch {
            return $null
        }
    }
}

function Get-VbrPrtgStatusCode {
    param($License)

    $status = [string](Get-OptionalPropertyValue $License @('Status'))
    $units = Get-NullableDouble (Get-OptionalPropertyValue $License @('Units'))
    $usedUnits = Get-NullableDouble (Get-OptionalPropertyValue $License @('Used Units'))
    $expirationDate = Get-NullableDateTime (Get-OptionalPropertyValue $License @('License Expiration'))

    if ($status -ne 'Valid') {
        return 4
    }

    if ($null -ne $units -and $null -ne $usedUnits -and $usedUnits -gt $units) {
        return 3
    }

    if ($null -ne $expirationDate) {
        $daysRemaining = [math]::Floor(($expirationDate.UtcDateTime - (Get-Date).ToUniversalTime()).TotalDays)
        if ($daysRemaining -le 15) {
            return 2
        }

        if ($daysRemaining -le 60) {
            return 1
        }
    }

    return 0
}

function Get-AgentPrtgStatusCode {
    param($License)

    $licenseStatus = [string](Get-OptionalPropertyValue $License @('License Status'))

    if ([string]::IsNullOrWhiteSpace($licenseStatus)) {
        return 2
    }

    $normalizedStatus = $licenseStatus.Trim().ToLowerInvariant()
    if ($normalizedStatus -in @('licensed', 'valid', 'active', 'ok')) {
        return 0
    }

    return 1
}

function Get-Ms365PrtgStatusCode {
    param($License)

    $status = [string](Get-OptionalPropertyValue $License @('Status'))
    $units = Get-NullableDouble (Get-OptionalPropertyValue $License @('Units'))
    $usedUnits = Get-NullableDouble (Get-OptionalPropertyValue $License @('Used Units'))

    if ($null -ne $units -and $null -ne $usedUnits -and $usedUnits -gt $units) {
        return 2
    }

    if ($status -ne 'Valid') {
        return 1
    }

    return 0
}

function Get-CloudConnectPrtgStatusCode {
    param($License)

    $status = [string](Get-OptionalPropertyValue $License @('Status'))
    $units = Get-NullableDouble (Get-OptionalPropertyValue $License @('Units'))
    $usedUnits = Get-NullableDouble (Get-OptionalPropertyValue $License @('Used Units'))
    $expirationDate = Get-NullableDateTime (Get-OptionalPropertyValue $License @('License Expiration'))

    if ($status -ne 'Valid') {
        return 4
    }

    if ($null -ne $units -and $null -ne $usedUnits -and $usedUnits -gt $units) {
        return 3
    }

    if ($null -ne $expirationDate) {
        $daysRemaining = [math]::Floor(($expirationDate.UtcDateTime - (Get-Date).ToUniversalTime()).TotalDays)
        if ($daysRemaining -le 15) {
            return 2
        }

        if ($daysRemaining -le 60) {
            return 1
        }
    }

    return 0
}

function New-PrtgResultXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Channel,
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [string]$Unit,
        [string]$CustomUnit,
        [string]$ValueLookup,
        [string]$Mode = 'Absolute',
        [Nullable[int]]$Float = 0,
        [Nullable[double]]$LimitMaxError,
        [Nullable[double]]$LimitMaxWarning,
        [Nullable[double]]$LimitMinError,
        [Nullable[double]]$LimitMinWarning,
        [string]$LimitErrorMsg,
        [string]$LimitWarningMsg
    )

    $xml = [System.Text.StringBuilder]::new()
    [void]$xml.AppendLine('  <result>')
    [void]$xml.AppendLine(("    <channel>{0}</channel>" -f (ConvertTo-XmlSafeText $Channel)))
    [void]$xml.AppendLine(("    <value>{0}</value>" -f (ConvertTo-XmlSafeText $Value)))
    if ($Unit) {
        [void]$xml.AppendLine(("    <unit>{0}</unit>" -f (ConvertTo-XmlSafeText $Unit)))
    }
    if ($CustomUnit) {
        [void]$xml.AppendLine(("    <customunit>{0}</customunit>" -f (ConvertTo-XmlSafeText $CustomUnit)))
    }
    if ($Mode) {
        [void]$xml.AppendLine(("    <mode>{0}</mode>" -f (ConvertTo-XmlSafeText $Mode)))
    }
    [void]$xml.AppendLine(("    <float>{0}</float>" -f $Float))
    [void]$xml.AppendLine('    <showchart>1</showchart>')
    [void]$xml.AppendLine('    <showtable>1</showtable>')
    if ($ValueLookup) {
        [void]$xml.AppendLine(("    <ValueLookup>{0}</ValueLookup>" -f (ConvertTo-XmlSafeText $ValueLookup)))
    }

    $hasLimits = $false
    if ($null -ne $LimitMaxError) {
        [void]$xml.AppendLine(("    <LimitMaxError>{0}</LimitMaxError>" -f $LimitMaxError))
        $hasLimits = $true
    }
    if ($null -ne $LimitMaxWarning) {
        [void]$xml.AppendLine(("    <LimitMaxWarning>{0}</LimitMaxWarning>" -f $LimitMaxWarning))
        $hasLimits = $true
    }
    if ($null -ne $LimitMinError) {
        [void]$xml.AppendLine(("    <LimitMinError>{0}</LimitMinError>" -f $LimitMinError))
        $hasLimits = $true
    }
    if ($null -ne $LimitMinWarning) {
        [void]$xml.AppendLine(("    <LimitMinWarning>{0}</LimitMinWarning>" -f $LimitMinWarning))
        $hasLimits = $true
    }
    if ($LimitErrorMsg) {
        [void]$xml.AppendLine(("    <LimitErrorMsg>{0}</LimitErrorMsg>" -f (ConvertTo-XmlSafeText $LimitErrorMsg)))
    }
    if ($LimitWarningMsg) {
        [void]$xml.AppendLine(("    <LimitWarningMsg>{0}</LimitWarningMsg>" -f (ConvertTo-XmlSafeText $LimitWarningMsg)))
    }
    if ($hasLimits) {
        [void]$xml.AppendLine('    <LimitMode>1</LimitMode>')
    }

    [void]$xml.AppendLine('  </result>')
    return $xml.ToString()
}

function Get-TenantLicenseOverview {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        [ValidateSet('VBR', 'Agent', 'MS365', 'CC')]
        [string[]]$LicenseType
    )

    $tenantMatches = @(get-OrgByName $TenantName)
    if ($tenantMatches.Count -eq 0) {
        throw "Tenant '$TenantName' was not found."
    }

    if ($tenantMatches.Count -gt 1) {
        throw "Tenant '$TenantName' returned multiple matches."
    }

    $tenant = $tenantMatches[0]
    $tenantUid = $tenant.instanceUid

    $selectedTypes = @($LicenseType)
    $includeAllTypes = $selectedTypes.Count -eq 0
    $includeVbr = $includeAllTypes -or $selectedTypes -contains 'VBR'
    $includeAgent = $includeAllTypes -or $selectedTypes -contains 'Agent'
    $includeMs365 = $includeAllTypes -or $selectedTypes -contains 'MS365'

    $vbrLicenses = @()
    if ($includeVbr) {
        $vbrLicenses = @(
            foreach ($server in @(get-ServersByOrgUID $tenantUid)) {
                $license = get-BackupServerLicenseByUid $server.instanceUid

                [pscustomobject]@{
                    Status               = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('status'))
                    Hostname             = ConvertTo-DisplayValue (Get-OptionalPropertyValue $server @('hostName', 'name'))
                    'License Expiration' = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('expirationDate'))
                    Units                = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('units'))
                    'Used Units'         = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('usedUnits'))
                    'License ID'         = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('licenseId', 'licenseIds'))
                }
            }
        )
    }

    $agentLicenses = @()
    if ($includeAgent) {
        $agentLicenses = @(
            foreach ($agent in @(get-AgentsByOrgUID $tenantUid)) {
                $agentDetails = get-BackupAgentByUid $agent.instanceUid

                [pscustomobject]@{
                    'License Status' = ConvertTo-DisplayValue (Get-OptionalPropertyValue $agentDetails @('licenseStatus', 'status'))
                    Hostname         = ConvertTo-DisplayValue (Get-OptionalPropertyValue $agentDetails @('hostName', 'name'))
                    'Operation Mode' = ConvertTo-DisplayValue (Get-OptionalPropertyValue $agentDetails @('operationMode'))
                }
            }
        )
    }

    $vb365Licenses = @()
    if ($includeMs365) {
        $vb365Licenses = @(
            foreach ($server in @(get-Vb365ServersByOrgUID $tenantUid)) {
                $license = get-Vb365LicenseByUid $server.instanceUid

                [pscustomobject]@{
                    Status                = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('status'))
                    'License Auto Update' = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('autoUpdateEnabled', 'isAutoUpdateEnabled'))
                    Hostname              = ConvertTo-DisplayValue (Get-OptionalPropertyValue $server @('hostName', 'name'))
                    Units                 = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('licensedUsers', 'units'))
                    'Used Units'          = ConvertTo-DisplayValue (Get-OptionalPropertyValue $license @('protectedUsers', 'usedUnits'))
                }
            }
        )
    }

    return [pscustomobject]@{
        TenantUid            = $tenantUid
        TenantName           = $tenant.name
        VbrLicenses          = $vbrLicenses
        AgentLicenses        = $agentLicenses
        Vb365Licenses        = $vb365Licenses
        CloudConnectLicenses = @()
    }
}

function Show-TenantLicenseOverviewDebug {
    param(
        [Parameter(Mandatory = $true)]
        $LicenseOverview,
        [ValidateSet('VBR', 'Agent', 'MS365', 'CC')]
        [string[]]$LicenseType
    )

    $selectedTypes = @($LicenseType)
    $includeAllTypes = $selectedTypes.Count -eq 0
    $showVbr = $includeAllTypes -or $selectedTypes -contains 'VBR'
    $showAgent = $includeAllTypes -or $selectedTypes -contains 'Agent'
    $showMs365 = $includeAllTypes -or $selectedTypes -contains 'MS365'

    if ($showVbr -and $LicenseOverview.VbrLicenses.Count -gt 0) {
        Write-Host 'Veeam Backup & Replication'
        $LicenseOverview.VbrLicenses |
            Select-Object Status, Hostname, 'License Expiration', Units, 'Used Units', 'License ID' |
            Format-Table -AutoSize
        Write-Host ''
    }

    if ($showAgent -and $LicenseOverview.AgentLicenses.Count -gt 0) {
        Write-Host 'Veeam Agent'
        $LicenseOverview.AgentLicenses |
            Select-Object 'License Status', Hostname, 'Operation Mode' |
            Format-Table -AutoSize
        Write-Host ''
    }

    if ($showMs365 -and $LicenseOverview.Vb365Licenses.Count -gt 0) {
        Write-Host 'Veeam Backup for Microsoft 365'
        $LicenseOverview.Vb365Licenses |
            Select-Object Status, 'License Auto Update', Hostname, Units, 'Used Units' |
            Format-Table -AutoSize
        Write-Host ''
    }

}

function Get-AllLicenseOverview {
    param(
        [ValidateSet('VBR', 'Agent', 'MS365', 'CC')]
        [string[]]$LicenseType
    )

    $allVbrLicenses = @()
    $allAgentLicenses = @()
    $allVb365Licenses = @()
    $allCloudConnectLicenses = @()

    $selectedTypes = @($LicenseType)
    $includeAllTypes = $selectedTypes.Count -eq 0
    $includeCc = $includeAllTypes -or $selectedTypes -contains 'CC'

    foreach ($tenant in @(get-AllOrgs | Sort-Object name)) {
        $licenseOverview = Get-TenantLicenseOverview -TenantName $tenant.name -LicenseType $LicenseType

        foreach ($vbrLicense in @($licenseOverview.VbrLicenses)) {
            $allVbrLicenses += [pscustomobject]@{
                Tenant               = $licenseOverview.TenantName
                Status               = $vbrLicense.Status
                Hostname             = $vbrLicense.Hostname
                'License Expiration' = $vbrLicense.'License Expiration'
                Units                = $vbrLicense.Units
                'Used Units'         = $vbrLicense.'Used Units'
                'License ID'         = $vbrLicense.'License ID'
            }
        }

        foreach ($agentLicense in @($licenseOverview.AgentLicenses)) {
            $allAgentLicenses += [pscustomobject]@{
                Tenant           = $licenseOverview.TenantName
                'License Status' = $agentLicense.'License Status'
                Hostname         = $agentLicense.Hostname
                'Operation Mode' = $agentLicense.'Operation Mode'
            }
        }

        foreach ($vb365License in @($licenseOverview.Vb365Licenses)) {
            $allVb365Licenses += [pscustomobject]@{
                Tenant                = $licenseOverview.TenantName
                Status                = $vb365License.Status
                'License Auto Update' = $vb365License.'License Auto Update'
                Hostname              = $vb365License.Hostname
                Units                 = $vb365License.Units
                'Used Units'          = $vb365License.'Used Units'
            }
        }

    }

    if ($includeCc) {
        foreach ($cloudConnectLicense in @(Get-CloudConnectLicenseOverview).CloudConnectLicenses) {
            $allCloudConnectLicenses += [pscustomobject]@{
                Tenant               = 'Provider'
                Status               = $cloudConnectLicense.Status
                Hostname             = $cloudConnectLicense.Hostname
                'Cloud Connect'      = $cloudConnectLicense.'Cloud Connect'
                'License Expiration' = $cloudConnectLicense.'License Expiration'
                Units                = $cloudConnectLicense.Units
                'Used Units'         = $cloudConnectLicense.'Used Units'
                'License ID'         = $cloudConnectLicense.'License ID'
            }
        }
    }

    return [pscustomobject]@{
        VbrLicenses          = $allVbrLicenses
        AgentLicenses        = $allAgentLicenses
        Vb365Licenses        = $allVb365Licenses
        CloudConnectLicenses = $allCloudConnectLicenses
    }
}

function Show-AllLicenseOverviewDebug {
    param(
        [Parameter(Mandatory = $true)]
        $LicenseOverview,
        [ValidateSet('VBR', 'Agent', 'MS365', 'CC')]
        [string[]]$LicenseType
    )

    $selectedTypes = @($LicenseType)
    $includeAllTypes = $selectedTypes.Count -eq 0
    $showVbr = $includeAllTypes -or $selectedTypes -contains 'VBR'
    $showAgent = $includeAllTypes -or $selectedTypes -contains 'Agent'
    $showMs365 = $includeAllTypes -or $selectedTypes -contains 'MS365'
    $showCc = $includeAllTypes -or $selectedTypes -contains 'CC'

    if ($showVbr -and $LicenseOverview.VbrLicenses.Count -gt 0) {
        Write-Host 'Veeam Backup & Replication'
        $LicenseOverview.VbrLicenses |
            Select-Object Tenant, Status, Hostname, 'License Expiration', Units, 'Used Units', 'License ID' |
            Format-Table -AutoSize
        Write-Host ''
    }

    if ($showAgent -and $LicenseOverview.AgentLicenses.Count -gt 0) {
        Write-Host 'Veeam Agent'
        $LicenseOverview.AgentLicenses |
            Select-Object Tenant, 'License Status', Hostname, 'Operation Mode' |
            Format-Table -AutoSize
        Write-Host ''
    }

    if ($showMs365 -and $LicenseOverview.Vb365Licenses.Count -gt 0) {
        Write-Host 'Veeam Backup for Microsoft 365'
        $LicenseOverview.Vb365Licenses |
            Select-Object Tenant, Status, 'License Auto Update', Hostname, Units, 'Used Units' |
            Format-Table -AutoSize
        Write-Host ''
    }

    if ($showCc -and $LicenseOverview.CloudConnectLicenses.Count -gt 0) {
        Write-Host 'Veeam Cloud Connect'
        $LicenseOverview.CloudConnectLicenses |
            Select-Object Tenant, Status, Hostname, 'Cloud Connect', 'License Expiration', Units, 'Used Units', 'License ID' |
            Format-Table -AutoSize
    }
}

function Convert-VbrLicenseOverviewToPrtgXml {
    param(
        [Parameter(Mandatory = $true)]
        $LicenseOverview
    )

    $lookupId = 'sm-it.veeam.vspc.vbr.license.status'
    $xml = [System.Text.StringBuilder]::new()
    [void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8" ?>')
    [void]$xml.AppendLine('<prtg>')

    $messageParts = @()

    foreach ($license in @($LicenseOverview.VbrLicenses)) {
        $hostname = [string](Get-OptionalPropertyValue $license @('Hostname'))
        $licenseId = [string](Get-OptionalPropertyValue $license @('License ID'))
        $statusCode = Get-VbrPrtgStatusCode -License $license
        $units = Get-NullableDouble (Get-OptionalPropertyValue $license @('Units'))
        $usedUnits = Get-NullableDouble (Get-OptionalPropertyValue $license @('Used Units'))
        $expirationDate = Get-NullableDateTime (Get-OptionalPropertyValue $license @('License Expiration'))
        $daysRemaining = $null
        if ($null -ne $expirationDate) {
            $daysRemaining = [math]::Floor(($expirationDate.UtcDateTime - (Get-Date).ToUniversalTime()).TotalDays)
        }

        $channelLabel = if ($hostname) { $hostname } else { 'Unknown Host' }
        $messageParts += "{0}: {1}" -f $channelLabel, ($(if ($licenseId) { $licenseId } else { 'No License ID' }))

        [void]$xml.Append(
            (New-PrtgResultXml `
                -Channel ("Status - {0}" -f $channelLabel) `
                -Value ([string]$statusCode) `
                -Unit 'Custom' `
                -CustomUnit 'State' `
                -ValueLookup $lookupId `
                -Float 0)
        )

        if ($null -ne $units) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Units - {0}" -f $channelLabel) `
                    -Value ([string]$units) `
                    -Unit 'Custom' `
                    -CustomUnit 'Units' `
                    -Float 0)
            )
        }

        if ($null -ne $usedUnits) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Used Units - {0}" -f $channelLabel) `
                    -Value ([string]$usedUnits) `
                    -Unit 'Custom' `
                    -CustomUnit 'Units' `
                    -Float 0 `
                    -LimitMaxError $units `
                    -LimitErrorMsg 'Used units exceeded licensed units.')
            )
        }

        if ($null -ne $daysRemaining) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Days Remaining - {0}" -f $channelLabel) `
                    -Value ([string]$daysRemaining) `
                    -Unit 'Custom' `
                    -CustomUnit 'Days' `
                    -Float 0 `
                    -LimitMinWarning 60 `
                    -LimitMinError 15 `
                    -LimitWarningMsg 'License expires within 60 days.' `
                    -LimitErrorMsg 'License expires within 15 days.')
            )
        }
    }

    $sensorMessage = if ($messageParts.Count -gt 0) {
        ($messageParts -join ' | ').Replace('#', '')
    }
    else {
        'No VBR licenses found.'.Replace('#', '')
    }

    [void]$xml.AppendLine(("  <text>{0}</text>" -f (ConvertTo-XmlSafeText $sensorMessage)))
    [void]$xml.AppendLine('</prtg>')
    return $xml.ToString()
}

function Convert-AgentLicenseOverviewToPrtgXml {
    param(
        [Parameter(Mandatory = $true)]
        $LicenseOverview
    )

    $lookupId = 'sm-it.veeam.vspc.agent.license.status'
    $xml = [System.Text.StringBuilder]::new()
    [void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8" ?>')
    [void]$xml.AppendLine('<prtg>')

    $messageParts = @()

    foreach ($license in @($LicenseOverview.AgentLicenses)) {
        $hostname = [string](Get-OptionalPropertyValue $license @('Hostname'))
        $operationMode = [string](Get-OptionalPropertyValue $license @('Operation Mode'))
        $statusCode = Get-AgentPrtgStatusCode -License $license

        $channelLabel = if ($hostname) { $hostname } else { 'Unknown Host' }
        $messageParts += if ($operationMode) {
            "{0}: {1}" -f $channelLabel, $operationMode
        }
        else {
            $channelLabel
        }

        [void]$xml.Append(
            (New-PrtgResultXml `
                -Channel ("Status - {0}" -f $channelLabel) `
                -Value ([string]$statusCode) `
                -Unit 'Custom' `
                -CustomUnit 'State' `
                -ValueLookup $lookupId `
                -Float 0)
        )
    }

    $sensorMessage = if ($messageParts.Count -gt 0) {
        ($messageParts -join ' | ').Replace('#', '')
    }
    else {
        'No Agent licenses found.'.Replace('#', '')
    }

    [void]$xml.AppendLine(("  <text>{0}</text>" -f (ConvertTo-XmlSafeText $sensorMessage)))
    [void]$xml.AppendLine('</prtg>')
    return $xml.ToString()
}

function Convert-Ms365LicenseOverviewToPrtgXml {
    param(
        [Parameter(Mandatory = $true)]
        $LicenseOverview
    )

    $lookupId = 'sm-it.veeam.vspc.ms365.license.status'
    $xml = [System.Text.StringBuilder]::new()
    [void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8" ?>')
    [void]$xml.AppendLine('<prtg>')

    $messageParts = @()

    foreach ($license in @($LicenseOverview.Vb365Licenses)) {
        $hostname = [string](Get-OptionalPropertyValue $license @('Hostname'))
        $statusCode = Get-Ms365PrtgStatusCode -License $license
        $units = Get-NullableDouble (Get-OptionalPropertyValue $license @('Units'))
        $usedUnits = Get-NullableDouble (Get-OptionalPropertyValue $license @('Used Units'))
        $autoUpdate = Get-OptionalPropertyValue $license @('License Auto Update')
        $autoUpdateValue = if ($null -eq $autoUpdate) { $null } elseif ([bool]$autoUpdate) { 1 } else { 0 }

        $channelLabel = if ($hostname) { $hostname } else { 'Unknown Host' }
        $messageParts += $channelLabel

        [void]$xml.Append(
            (New-PrtgResultXml `
                -Channel ("Status - {0}" -f $channelLabel) `
                -Value ([string]$statusCode) `
                -Unit 'Custom' `
                -CustomUnit 'State' `
                -ValueLookup $lookupId `
                -Float 0)
        )

        if ($null -ne $units) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Units - {0}" -f $channelLabel) `
                    -Value ([string]$units) `
                    -Unit 'Custom' `
                    -CustomUnit 'Units' `
                    -Float 0)
            )
        }

        if ($null -ne $usedUnits) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Used Units - {0}" -f $channelLabel) `
                    -Value ([string]$usedUnits) `
                    -Unit 'Custom' `
                    -CustomUnit 'Units' `
                    -Float 0 `
                    -LimitMaxError $units `
                    -LimitErrorMsg 'Used units exceeded licensed units.')
            )
        }

        if ($null -ne $autoUpdateValue) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("License Auto Update - {0}" -f $channelLabel) `
                    -Value ([string]$autoUpdateValue) `
                    -Unit 'Custom' `
                    -CustomUnit 'State' `
                    -ValueLookup 'sm-it.veeam.vspc.ms365.autoupdate.status' `
                    -Float 0)
            )
        }
    }

    $sensorMessage = if ($messageParts.Count -gt 0) {
        ($messageParts -join ' | ').Replace('#', '')
    }
    else {
        'No Microsoft 365 licenses found.'.Replace('#', '')
    }

    [void]$xml.AppendLine(("  <text>{0}</text>" -f (ConvertTo-XmlSafeText $sensorMessage)))
    [void]$xml.AppendLine('</prtg>')
    return $xml.ToString()
}

function Convert-CloudConnectLicenseOverviewToPrtgXml {
    param(
        [Parameter(Mandatory = $true)]
        $LicenseOverview
    )

    $lookupId = 'sm-it.veeam.vspc.cc.license.status'
    $xml = [System.Text.StringBuilder]::new()
    [void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8" ?>')
    [void]$xml.AppendLine('<prtg>')

    $messageParts = @()

    foreach ($license in @($LicenseOverview.CloudConnectLicenses)) {
        $hostname = [string](Get-OptionalPropertyValue $license @('Hostname'))
        $licenseId = [string](Get-OptionalPropertyValue $license @('License ID'))
        $statusCode = Get-CloudConnectPrtgStatusCode -License $license
        $units = Get-NullableDouble (Get-OptionalPropertyValue $license @('Units'))
        $usedUnits = Get-NullableDouble (Get-OptionalPropertyValue $license @('Used Units'))
        $expirationDate = Get-NullableDateTime (Get-OptionalPropertyValue $license @('License Expiration'))
        $cloudConnect = [string](Get-OptionalPropertyValue $license @('Cloud Connect'))
        $daysRemaining = $null
        if ($null -ne $expirationDate) {
            $daysRemaining = [math]::Floor(($expirationDate.UtcDateTime - (Get-Date).ToUniversalTime()).TotalDays)
        }

        $channelLabel = if ($hostname) { $hostname } else { 'Unknown Host' }
        $messageParts += "{0}: {1}" -f $channelLabel, ($(if ($licenseId) { $licenseId } else { 'No License ID' }))

        [void]$xml.Append(
            (New-PrtgResultXml `
                -Channel ("Status - {0}" -f $channelLabel) `
                -Value ([string]$statusCode) `
                -Unit 'Custom' `
                -CustomUnit 'State' `
                -ValueLookup $lookupId `
                -Float 0)
        )

        if ($null -ne $units) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Units - {0}" -f $channelLabel) `
                    -Value ([string]$units) `
                    -Unit 'Custom' `
                    -CustomUnit 'Units' `
                    -Float 0)
            )
        }

        if ($null -ne $usedUnits) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Used Units - {0}" -f $channelLabel) `
                    -Value ([string]$usedUnits) `
                    -Unit 'Custom' `
                    -CustomUnit 'Units' `
                    -Float 0 `
                    -LimitMaxError $units `
                    -LimitErrorMsg 'Used units exceeded licensed units.')
            )
        }

        if ($null -ne $daysRemaining) {
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Days Remaining - {0}" -f $channelLabel) `
                    -Value ([string]$daysRemaining) `
                    -Unit 'Custom' `
                    -CustomUnit 'Days' `
                    -Float 0 `
                    -LimitMinWarning 60 `
                    -LimitMinError 15 `
                    -LimitWarningMsg 'License expires within 60 days.' `
                    -LimitErrorMsg 'License expires within 15 days.')
            )
        }

        if (-not [string]::IsNullOrWhiteSpace($cloudConnect)) {
            $cloudConnectValue = if ($cloudConnect -eq 'Yes') { 1 } else { 0 }
            [void]$xml.Append(
                (New-PrtgResultXml `
                    -Channel ("Cloud Connect - {0}" -f $channelLabel) `
                    -Value ([string]$cloudConnectValue) `
                    -Unit 'Custom' `
                    -CustomUnit 'State' `
                    -ValueLookup 'sm-it.veeam.vspc.cc.cloudconnect.status' `
                    -Float 0)
            )
        }
    }

    $sensorMessage = if ($messageParts.Count -gt 0) {
        ($messageParts -join ' | ').Replace('#', '')
    }
    else {
        'No Cloud Connect licenses found.'.Replace('#', '')
    }

    [void]$xml.AppendLine(("  <text>{0}</text>" -f (ConvertTo-XmlSafeText $sensorMessage)))
    [void]$xml.AppendLine('</prtg>')
    return $xml.ToString()
}
function get-AllOrgs{
    return Invoke-VspcGet 'organizations/companies'
}
