# veeamVSPCLicenses.ps1

PowerShell script to query tenant and license information from the Veeam Service Provider Console REST API.

## Installation

1. Copy the repository contents to the target system.
2. Use `veeamVSCPtoPRTG_Includes/config.ps1.example` as template and create `veeamVSCPtoPRTG_Includes/config.ps1` with the correct VSPC base URL and API key.
3. Make sure the PRTG probe or execution account can run PowerShell scripts.
4. Copy the required lookup files from `lookups/custom/` to the PRTG server under `\lookups\custom\`.
5. Reload the lookup files in PRTG.
6. Configure the script as an `EXE/Script Advanced` sensor when using non-debug XML output.

Required lookup files:

- `sm-it.veeam.vspc.vbr.license.status.ovl`
- `sm-it.veeam.vspc.agent.license.status.ovl`
- `sm-it.veeam.vspc.ms365.license.status.ovl`
- `sm-it.veeam.vspc.ms365.autoupdate.status.ovl`

## Script

```powershell
.\veeamVSPCLicenses.ps1
```

## Current Parameter Set

```powershell
.\veeamVSPCLicenses.ps1 `
  [-listTenants] `
  [-allLicenses VBR|Agent|MS365] `
  [-TenantLicences "Tenant Name"] `
  [-licenseType VBR|Agent|MS365] `
  [-debug]
```

## Parameters

### `-listTenants`

Lists all tenants returned by the VSPC API.

Example:

```powershell
.\veeamVSPCLicenses.ps1 -listTenants
```

### `-allLicenses`

Queries licenses across all tenants.

Example:

```powershell
.\veeamVSPCLicenses.ps1 -allLicenses VBR
.\veeamVSPCLicenses.ps1 -allLicenses VBR -debug
.\veeamVSPCLicenses.ps1 -allLicenses VBR,MS365 -debug
```

Current behavior:

- Without `-debug`, no output is shown yet.
- With `-debug`, the collected data is shown as tables.

Allowed values:

- `VBR`
- `Agent`
- `MS365`

### `-TenantLicences`

Queries license information for the specified tenant.

Example:

```powershell
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name"
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType VBR
```

Current behavior:

- Without `-debug`, `PRTG Advanced XML` output is implemented for exactly one `-licenseType`.
- With `-debug`, the collected data is shown as tables.

### `-licenseType`

Filters which license types are queried for `-TenantLicences`.

Allowed values:

- `VBR`
- `Agent`
- `MS365`

Examples:

```powershell
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType VBR -debug
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType Agent -debug
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType MS365 -debug
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType VBR,MS365 -debug
```

If `-licenseType` is omitted, all currently implemented license types are queried.

For `PRTG Advanced XML` output, use exactly one license type:

```powershell
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType VBR
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType Agent
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType MS365
```

### `-debug`

Shows the collected tenant license information as tables.

Example:

```powershell
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -debug
.\veeamVSPCLicenses.ps1 -allLicenses VBR,Agent,MS365 -debug
```

## Current Debug Output

### `VBR`

Currently displayed columns:

- `Tenant`
- `Status`
- `Hostname`
- `License Expiration`
- `Units`
- `Used Units`
- `License ID`

### `Agent`

Currently displayed columns:

- `Tenant`
- `License Status`
- `Hostname`
- `Operation Mode`

### `MS365`

Currently displayed columns:

- `Tenant`
- `Status`
- `License Auto Update`
- `Hostname`
- `Units`
- `Used Units`

## Maintenance Note

When new script parameters are added, this `README.md` must be updated as part of the same change.

## PRTG Output

Current non-debug PRTG output is implemented for:

```powershell
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType VBR
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType Agent
.\veeamVSPCLicenses.ps1 -TenantLicences "Tenant Name" -licenseType MS365
```

The script returns `EXE/Script Advanced` XML.

### VBR Channels

One channel set per VBR host:

- `Status - <Hostname>`
- `Units - <Hostname>`
- `Used Units - <Hostname>`
- `Days Remaining - <Hostname>`

The sensor message text contains:

- `Hostname`
- `License ID`

### VBR Status Logic

The VBR `Status` channel uses the lookup file:

- `lookups/custom/sm-it.veeam.vspc.vbr.license.status.ovl`

Status mapping:

- `0` = `Valid`
- `1` = `Valid, expires in 60 days or less`
- `2` = `Valid, expires in 15 days or less`
- `3` = `Used units exceeded licensed units`
- `4` = `License status is not valid`

### VBR Limits

The XML output also initializes these channel limits in PRTG:

- `Used Units`: error if `Used Units > Units`
- `Days Remaining`: warning at `60`
- `Days Remaining`: error at `15`

To use the lookup in PRTG, copy the `.ovl` file to the PRTG server under `\lookups\custom\` and reload the lookup files in PRTG.

### Agent Channels

One status channel per Agent host:

- `Status - <Hostname>`

The sensor message text contains:

- `Hostname`
- `Operation Mode`

The Agent `Status` channel uses:

- `lookups/custom/sm-it.veeam.vspc.agent.license.status.ovl`

Status mapping:

- `0` = `License status is healthy`
- `1` = `License status requires attention`
- `2` = `License status is missing`

### MS365 Channels

One channel set per Microsoft 365 host:

- `Status - <Hostname>`
- `Units - <Hostname>`
- `Used Units - <Hostname>`
- `License Auto Update - <Hostname>`

The sensor message text contains:

- `Hostname`

The MS365 `Status` channel uses:

- `lookups/custom/sm-it.veeam.vspc.ms365.license.status.ovl`

Status mapping:

- `0` = `License status is valid`
- `1` = `License status is not valid`
- `2` = `Used units exceeded licensed units`

The MS365 `License Auto Update` channel uses:

- `lookups/custom/sm-it.veeam.vspc.ms365.autoupdate.status.ovl`

Status mapping:

- `0` = `Auto update disabled`
- `1` = `Auto update enabled`

MS365 limits:

- `Used Units`: error if `Used Units > Units`
