function Get-CCMLog
{
    <#
    .SYNOPSIS
        A simple utility to view Configuration Manager log files in Powershell.
    .DESCRIPTION
        Retrieves entries from Configuration Manager's log files (defaulting to the last 2000 lines per file) from a local or remote computer and converts them to objects.
    .PARAMETER LogName
        The name of the log(s) to be retrieved.
    .PARAMETER Path
        The directory the logs are stored in. UNC path's are assumed for use against remote machine but conversion from local drives is automatically attempted.
    .PARAMETER ComputerName
        The computer(s) whose logs will queried.
    .EXAMPLE
        Get-CCMLog -LogName "AppDiscovery"

        Retrieves the AppDiscovery log of the local machine
    .EXAMPLE
        Get-CCMLog -LogName "AppIntentEval", "AppDiscovery", "AppEnforce" | Out-GridView

        Retrieves the 'AppIntentEval', 'AppDiscovery' and 'AppEnforce' log entries and outputs to Out-GridView for interactive search and manipulation.
    .EXAMPLE
        Get-CCMLog -LogName PolicyAgent, AppDiscovery, AppIntentEval, CAS, ContentTransferManager, DataTransferService, AppEnforce | Out-GridView

        Retrieves logs allowing for the tracing of a deployment from machine policy to app enforcement and outputs to Out-GridView again.
    .INPUTS
        String
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(ConfirmImpact = "Low", SupportsShouldProcess = $True)]
    [OutputType("PSCustomObject")]
    param
    (
        [Parameter(Position = 0, HelpMessage = "The log(s) to be retrieved")]
        [alias("Name")]
        [ValidateSet("AlternateHandler", "AppDiscovery", "AppEnforce", "AppIntentEval", "AssetAdvisor", "CAS", "Ccm32BitLauncher", "CcmCloud",
            "CcmEval", "CcmEvalTask", "CcmExec", "CcmMessaging", "CcmNotificationAgent", "CcmRepair", "CcmRestart", "CCMSDKProvider",
            "CcmSqlCE", "CCMVDIProvider", "CertEnrollAgent", "CertificateMaintenance", "CIAgent", "CIDownloader", "CIStateStore",
            "CIStore", "CITaskMgr", "ClientIDManagerStartup", "ClientLocation", "ClientServicing", "CMBITSManager", "CmRcService",
            "CoManagementHandler", "ComplRelayAgent", "ContentTransferManager", "DataTransferService", "DCMAgent", "DCMReporting",
            "DcmWmiProvider", "DdrProvider", "DeltaDownload", "EndpointProtectionAgent", "execmgr", "ExpressionSolver",
            "ExternalEventAgent", "FileBITS", "FSPStateMessage", "InternetProxy", "InventoryAgent", "InventoryProvider",
            "LocationServices", "MaintenanceCoordinator", "ManagedProvider", "mtrmgr", "oobmgmt", "PeerDPAgent", "PolicyAgent",
            "PolicyAgentProvider", "PolicyEvaluator", "pwrmgmt", "PwrProvider", "RebootCoordinator", "ScanAgent", "Scheduler",
            "ServiceWindowManager", "SettingsAgent", "setuppolicyevaluator", "smscliui", "SoftwareCatalogUpdateEndpoint",
            "SoftwareCenterSystemTasks", "SrcUpdateMgr", "StateMessage", "StateMessageProvider", "StatusAgent", "SWMTRReportGen",
            "UpdatesDeployment", "UpdatesHandler", "UpdatesStore", "UpdateTrustedSites", "UserAffinity", "UserAffinityProvider",
            "VirtualApp", "wedmtrace", "WindowsAnalytics", "WUAHandler")]
        [string[]] $LogName = "AppEnforce",

        [Parameter(Position = 1, HelpMessage = "The path to the directory containing the logs")]
        [string] $Path = "C:\Windows\CCM\Logs",

        [Parameter(Position = 2, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, HelpMessage = "The computer whose logs will be parsed")]
        [alias("PSComputerName", "__SERVER", "CN", "IPAddress")]
        [string[]] $ComputerName = "localhost"
    )

    BEGIN
    {
        if ($PSBoundParameters.ContainsKey("Debug"))
        {
            $DebugPreference = "Continue"
        }
    }

    PROCESS
    {
        forEach ($Computer in $ComputerName)
        {
            if (($Computer -like "localhost") -or ($Computer -like "127.0.0.1"))
            {
                Write-Verbose -Message "Converting localhost to hostname"
                $Computer = [Environment]::MachineName
            }
            Write-Verbose -Message "Processing '$Computer'"

            try
            {
                $LogRoot = $Null
                if ($Null -ne $Path)
                {
                    $JoinSplat = @{
                        Path        = "\\$Computer\"
                        ChildPath   = ($Path -replace ":", "$")
                        ErrorAction = "Stop"
                    }

                    $UNCPath = Join-Path @JoinSplat
                    if (Test-Path -Path $UNCPath -ErrorAction "Stop")
                    {
                        $LogRoot = Resolve-Path -Path $UNCPath -ErrorAction "Stop"
                    }
                }
                else
                {
                    $LogRoot = Resolve-Path "\\$Computer\C$\Windows\CCM\Logs\" -ErrorAction "Stop"
                }

                if ($LogRoot -match "^Microsoft.Powershell")
                {
                    $LogRoot = $LogRoot -Split "::" | Select-Object -Last 1
                }
            }
            catch
            {
                Write-Warning -Message "Problems were encountered resolving '$LogRoot'"
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if (-not (Test-Path -Path $LogRoot))
            {
                Write-Warning -Message "Unable to resolve/access '$LogRoot'"
                Continue
            }

            Write-Verbose -Message "Testing for connectivity to '$Computer'"
            if (($Computer -eq [Environment]::MachineName) -or
                (Test-Connection -ComputerName $Computer -Quiet -Count 2))
            {
                forEach ($Log in $LogName)
                {
                    if ($PSCmdlet.ShouldProcess($LogRoot, "Retrieve '$Log' log entries"))
                    {
                        try
                        {
                            Write-Verbose -Message "Locating '$Log' log(s)."
                            $LogSearchSplat = $Null
                            $LogSearchSplat = @{
                                Path   = $LogRoot
                                Filter = "$Log*.log"
                                File   = $True
                            }

                            $LogPaths = $Null
                            $LogPaths = @(Get-ChildItem @LogSearchSplat  | Select-Object -ExpandProperty "FullName")
                            Write-Verbose -Message "'$($LogPaths.Count)' '$Log' logs found."
                        }
                        catch
                        {
                            Write-Warning -Message "Problems were encountered '$Log' logs from '$LogRoot'"
                            $PSCmdlet.ThrowTerminatingError($_)
                        }

                        forEach ($LogPath in $LogPaths)
                        {
                            if (Test-Path -Path $LogPath -ErrorAction "Stop")
                            {
                                try
                                {
                                    $Parameters = @{
                                        Path        = $LogPath
                                        Tail        = 2000     # I'm reluctant to read the entirety of the files by default and this seems likely to read most logs.
                                        ErrorAction = "Stop"
                                    }

                                    Write-Verbose -Message "Reading log ($LogPath)."
                                    $LogContents = Get-Content @Parameters
                                }
                                catch [System.UnauthorizedAccessException]
                                {
                                    Write-Warning -Message "Unable due to retrieve details to an 'Unauthorized Access' exception. Ensure you have the required permissions."
                                    $PSCmdlet.ThrowTerminatingError($_)
                                }
                                catch
                                {
                                    $PSCmdlet.ThrowTerminatingError($_)
                                }

                                forEach ($LogEntry in $LogContents)
                                {
                                    Write-Debug -Message "Processing log entry: '$LogEntry'"
                                    try
                                    {
                                        Write-Debug -Message "Processing message property."
                                        [string] $Message = ($LogEntry | Select-String -Pattern "\[LOG\[((.| )+)\]LOG\]").Matches.Value
                                        # Identifies the message sections of each line using the [LOG[] tags and removes them for us.
                                        if ($Log -like "AppIntentEval")
                                        {
                                            Write-Debug -Message "Parsing AppIntentEval message."
                                            $Message = $Message -replace ":- |, ", "`n"
                                            # Lazy reformatting to key:value statements instead of in a line.
                                        }
                                        $Message = ($Message -replace "\[LOG\[|\]LOG\]").Trim()
                                    }
                                    catch
                                    {
                                        $PSCmdlet.ThrowTerminatingError($_)
                                    }

                                    if (-not ($Message))
                                    {
                                        Write-Verbose -Message "Unable to read blank message - skipping to next."
                                        Continue
                                    }

                                    try
                                    {
                                        Write-Debug -Message "Processing metadata block."
                                        [string] $Metadata = ((($LogEntry | Select-String -Pattern "<time((.| )+)>").Matches.Value -replace "<|>") -split " ")
                                        # Identifies and isolates the metadata section
                                        # Includes the time and date which we want, but also other entries which we'll need to get rid of.
                                    }
                                    catch
                                    {
                                        $PSCmdlet.ThrowTerminatingError($_)
                                    }


                                    try
                                    {
                                        Write-Debug -Message "Processing TimeStub block."
                                        [string] $TimeStub = ((($Metadata -split " ")[0] -replace 'time|=|"') -split "\.")[0]
                                        # To find the time, we remove 'time', '=', and '"'
                                        # Split the remainder in two based on '.' and keep the first part.
                                        # This is a bit awkward but the casting is tricky without the split.
                                    }
                                    catch
                                    {
                                        $PSCmdlet.ThrowTerminatingError($_)
                                    }

                                    try
                                    {
                                        Write-Debug -Message "Processing DateStub block."
                                        [string] $DateStub = ((($Metadata -split " ")[1] -replace 'date|=|"'))
                                        # Finding the date is similar but simpler.
                                        # We only need to remove 'date', '=', and '"'.
                                    }
                                    catch
                                    {
                                        $PSCmdlet.ThrowTerminatingError($_)
                                    }


                                    try
                                    {
                                        Write-Debug -Message "Generating timestamp."
                                        [datetime] $TimeStamp = "$DateStub $TimeStub"
                                        # At the end we add the two stubs together, and cast them as a [datetime] object
                                    }
                                    catch
                                    {
                                        $PSCmdlet.ThrowTerminatingError($_)
                                    }

                                    [PSCustomObject]@{
                                        ComputerName = $Computer
                                        Source       = $Log
                                        Timestamp    = $TimeStamp
                                        Message      = $Message
                                        Path         = $LogPath
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    END
    {
    }
}