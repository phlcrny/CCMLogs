# CCMLogs

[![PowerShell Gallery][psgallery-badge]][psgallery]

CCMLogs is intended as a simple module to make it easier to interact with Configuration Manager logs in Powershell.

## Getting Started

### Installing

```Powershell
Install-Module -Name "CCMLogs"
```

### Usage

```Powershell
Get-CCMLog -LogName "AppDiscovery"
# Retrieves the AppDiscovery log of the local machine

Get-CCMLog -LogName "AppEnforce" -Count 10
# Retrieves 10 entries from the AppEnforce log of the local machine

Get-CCMLog -LogName "AppIntentEval", "AppDiscovery", "AppEnforce" | Out-GridView
# Retrieves the 'AppIntentEval', 'AppDiscovery' and 'AppEnforce' log entries and outputs to Out-GridView for interactive search, sorting etc.

Get-CCMLog -LogName "AppIntentEval", "AppDiscovery", "AppEnforce" -After (Get-Date).AddDays(-1)
# Retrieves the 'AppIntentEval', 'AppDiscovery' and 'AppEnforce' log entries for the last 24 hours
```

[psgallery-badge]: https://img.shields.io/powershellgallery/dt/ccmlogs.svg
[psgallery]: https://www.powershellgallery.com/packages/ccmlogs
