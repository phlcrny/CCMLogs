function Read-LogEntry
{
    [CmdletBinding(ConfirmImpact = 'Low', SupportsShouldProcess = $False)]
    param
    (
        [Parameter(Mandatory = $True, HelpMessage = 'The log entry to be parsed')]
        [string] $InputObject,

        [Parameter(Mandatory = $False, HelpMessage = 'Drops entries that occurred after the specified date and time.')]
        [datetime] $After,

        [Parameter(Mandatory = $False, HelpMessage = 'Drops entries that occurred before the specified date and time.')]
        [datetime] $Before
    )

    if ($PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = 'Continue'
    }

    Write-Debug -Message "Processing log entry: '$InputObject'"
    try
    {
        Write-Debug -Message 'Processing message property.'
        [string] $Message = ($InputObject | Select-String -Pattern '\[LOG\[((.| )+)\]LOG\]').Matches.Value
        # Identifies the message sections of each line using the [LOG[] tags and removes them for us.
        if ($Log -like 'AppIntentEval')
        {
            Write-Debug -Message 'Parsing AppIntentEval message.'
            $Message = $Message -replace ':- |, ', "`n"
            # Lazy reformatting to key:value statements instead of in a line.
        }
        $Message = ($Message -replace '\[LOG\[|\]LOG\]').Trim()
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    if (-not ($Message))
    {
        Write-Debug -Message 'Unable to read blank message - skipping to next.'
        Continue
    }

    try
    {
        Write-Debug -Message 'Processing metadata block.'
        [string] $Metadata = ((($InputObject | Select-String -Pattern '<time((.| )+)>').Matches.Value -replace '<|>') -split ' ')
        # Identifies and isolates the metadata section
        # Includes the time and date which we want, but also other entries which we'll need to get rid of.
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    try
    {
        Write-Debug -Message 'Processing TimeStub block.'
        [string] $TimeStub = ((($Metadata -split ' ')[0] -replace 'time|=|"') -split '\.')[0]
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
        Write-Debug -Message 'Processing DateStub block.'
        [string] $DateStub = ((($Metadata -split ' ')[1] -replace 'date|=|"'))
        # Finding the date is similar but simpler.
        # We only need to remove 'date', '=', and '"'.
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }


    try
    {
        Write-Debug -Message 'Generating timestamp.'
        [datetime] $TimeStamp = "$DateStub $TimeStub"
        # At the end we add the two stubs together, and cast them as a [datetime] object
        # When the [datetime] object is constructed we can begin to filter based on a time range.
        if (($After) -or ($Before))
        {
            if ($Timestamp -lt $After)
            {
                Write-Debug -Message "Timestamp is before '$After' cut-off."
                Continue
            }

            if ($Timestamp -gt $Before)
            {
                Write-Debug -Message "Timestamp is after '$Before' cut-off."
                Continue
            }
        }

        [PSCustomObject]@{
            Timestamp = $TimeStamp
            Message   = $Message
        }
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

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
    .PARAMETER After
        Gets entries that occurred after a specified date and time.
    .PARAMETER Before
        Gets entries that occurred before a specified date and time.
    .PARAMETER Count
        The number of entries to be retrieved - this is calculated per computer/group of logs rather than per log.
    .EXAMPLE
        Get-CCMLog -LogName "AppDiscovery"

        Retrieves the AppDiscovery log of the local machine
    .EXAMPLE
        Get-CCMLog -LogName "AppDiscovery" -Count 10

        Retrieves a maximum of 10 entries from the AppDiscovery log of the local machine
    .EXAMPLE
        Get-CCMLog -LogName "AppDiscovery" -After (Get-Date).AddDays(-1)

        Retrieves the AppDiscovery log of the local machine for the last 24 hours
    .EXAMPLE
        Get-CCMLog -LogName AppEnforce -After "09:35:25 02 June 2020" -Before "11:35:28 02 June 2020"

        Retrieves the AppDiscovery log of the local machine for a specified 2 hour period
    .EXAMPLE
        Get-CCMLog -LogName "AppIntentEval", "AppDiscovery", "AppEnforce" | Out-GridView

        Retrieves the 'AppIntentEval', 'AppDiscovery' and 'AppEnforce' log entries and outputs to Out-GridView for interactive search and manipulation
    .EXAMPLE
        Get-CCMLog -LogName PolicyAgent, AppDiscovery, AppIntentEval, CAS, ContentTransferManager, DataTransferService, AppEnforce | Out-GridView

        Retrieves logs allowing for the tracing of a deployment from machine policy to app enforcement and outputs to Out-GridView again
    .INPUTS
        String
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(ConfirmImpact = "Low", SupportsShouldProcess = $True, DefaultParameterSetName = "NamedLogs")]
    [OutputType("PSCustomObject")]
    param
    (
        [Parameter(Position = 0, ParameterSetName = "NamedLogs" , HelpMessage = "The log(s) to be retrieved")]
        [alias("Name")]
        [ValidateSet("AlternateHandler", "AppDiscovery", "AppEnforce", "AppIntentEval", "AssetAdvisor", "CAS", "Ccm32BitLauncher", "CcmCloud",
            "CcmEval", "CcmEvalTask", "CcmExec", "CcmMessaging", "CcmNotificationAgent", "CcmRepair", "CcmRestart", "CCMSDKProvider",
            "CCMSetup", "CcmSqlCE", "CCMVDIProvider", "CertEnrollAgent", "CertificateMaintenance", "CIAgent", "CIDownloader", "CIStateStore",
            "CIStore", "CITaskMgr", "ClientIDManagerStartup", "ClientLocation", "Client.Msi", "ClientServicing", "CMBITSManager", "CmRcService",
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

        [Parameter(Position = 0, ParameterSetName = "AllLogs", HelpMessage = "Indicates that all *.log files in the Path directory will be parsed")]
        [switch] $AllLogs = $False,

        [Parameter(Position = 1, HelpMessage = "The path to the directory containing the logs")]
        [string] $Path = "C:\Windows\CCM\Logs",

        [Parameter(Position = 2, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, HelpMessage = "The computer whose logs will be parsed")]
        [alias("PSComputerName", "__SERVER", "CN", "IPAddress")]
        [string[]] $ComputerName = "localhost",

        [Parameter(HelpMessage = "Gets entries that occurred after a specified date and time.")]
        [datetime] $After,

        [Parameter(HelpMessage = "Gets entries that occurred before a specified date and time.")]
        [datetime] $Before,

        [Parameter(HelpMessage = "The number of entries to be retrieved.")]
        [int] $Count
    )

    BEGIN
    {
        if ($PSBoundParameters.ContainsKey("Debug"))
        {
            $DebugPreference = "Continue"
        }

        # A colleague encountered weird, broken behaviour if running this from a CMSite provider
        # To be safe, we're going to explicitly move to a FileSystem if not already in one
        if (($ExecutionContext.SessionState.Path.CurrentLocation).Provider.Name -ne "FileSystem")
        {
            Push-Location # So we can move back afterwards - hopefully seamlessly

            try
            {
                # Move to the root of the first file system available, usually C:\ but why assume.
                Set-Location -Path (Get-PSDrive -PSProvider "FileSystem" | Select-Object -ExpandProperty "Root" -First 1)
                $PoppedLocation = $True
                Remove-Variable -Name "PoppedLocation"
            }
            catch
            {
                # Revert location if this fails for some inexplicable reason (no file systems?)
                Pop-Location
            }
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

            if ($Count)
            {
                $EntryCounter = 1
            }

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
                $LogSearchSplat = $Null
                $LogSearchSplat = @{
                    Path = $LogRoot
                    File = $True
                }

                $LogFiles = $Null
                $LogFiles = if ($AllLogs)
                {
                    try
                    {
                        $LogSearchSplat.Add("Filter", "*.log")
                        Get-ChildItem @LogSearchSplat  | Select-Object -ExpandProperty "FullName"
                    }
                    catch
                    {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
                else
                {
                    forEach ($Log in ($LogName | Sort-Object -Unique))
                    {
                        try
                        {
                            Write-Verbose -Message "Locating '$Log' log(s)."
                            $LogSearchSplat.Remove("Filter")
                            $LogSearchSplat.Add("Filter", "$Log*.log")
                            Get-ChildItem @LogSearchSplat  | Select-Object -ExpandProperty "FullName"

                        }
                        catch
                        {
                            Write-Warning -Message "Problems were encountered '$Log' logs from '$LogRoot'"
                            $PSCmdlet.ThrowTerminatingError($_)
                        }
                    }
                }

                Write-Verbose -Message "'$($LogFiles.Count)' logs found."
                forEach ($LogFile in $LogFiles)
                {
                    if (Test-Path -Path $LogFile -ErrorAction "Stop")
                    {
                        $CurrentLog = ((Split-Path $LogFile -Leaf) -replace '^_') -split '-' | Select-Object -First 1

                        try
                        {
                            $Parameters = @{
                                Path        = $LogFile
                                Tail        = 2000     # I'm reluctant to read the entirety of the files by default and this seems likely to read most logs.
                                ErrorAction = "Stop"
                            }

                            Write-Verbose -Message "Reading log ($LogFile)."
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

                            $LogSplat = @{
                                InputObject = $LogEntry
                            }

                            if ($After)
                            {
                                $LogSplat.Add("After", $After)
                            }
                            if ($Before)
                            {
                                $LogSplat.Add("Before", $Before)
                            }

                            $ParsedEntry = Read-LogEntry @LogSplat

                            if (($Null -ne $Count) -and ($Null -ne $EntryCounter))
                            {
                                if ($EntryCounter -gt $Count)
                                {
                                    Write-Debug -Message "Count is: $EntryCounter/$Count"
                                    Break
                                }
                                else
                                {
                                    Write-Debug -Message "Incrementing counter ($EntryCounter)"
                                    $EntryCounter++
                                }
                            }

                            [PSCustomObject]@{
                                ComputerName = $Computer
                                Source       = $CurrentLog
                                Timestamp    = $ParsedEntry.TimeStamp
                                Message      = $ParsedEntry.Message
                                Path         = $LogFile
                            }
                        }
                    }
                }
            }
        }
    }

    END
    {
        if ($PoppedLocation)
        {
            Pop-Location # Revert to original location
        }
    }
}
