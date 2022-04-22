@{
    ModuleVersion     = "0.4.1"
    RootModule        = "CCMLogs.psm1"
    GUID              = "d2ec31cb-f08f-46d3-9e79-6ba5b73adfdd"
    Author            = "Phil Carney"
    CompanyName       = "N/A"
    Copyright         = "(c) Phil Carney. All rights reserved."
    Description       = "A simple utility for viewing Configuration Manager logs in Powershell"
    FunctionsToExport = @("Get-CCMLog")
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags = @(
                "ccm"
                "cmtrace"
                "logs"
                "mecm"
                "sccm"
            )
            LicenseUri   = "https://github.com/phlcrny/CCMLogs/blob/master/licence.md"
            ProjectUri   = "https://github.com/phlcrny/CCMLogs"
            ReleaseNotes = "https://github.com/phlcrny/CCMLogs/blob/master/changelog.md"
        }
    }
}