##################################################
# Script Title: THOR Download and Execute Script
# Script File Name: thor-seed.ps1
# Author: Florian Roth
# Version: 2.0.0
# Date Created: 13.07.2020
# Last Modified: 11.02.2026
##################################################

#Requires -Version 3

<#
    .SYNOPSIS
        The "thor-seed" script downloads THOR and executes it
    .DESCRIPTION
        The "thor-seed" script downloads THOR from an ASGARD instance, the Nextron cloud or a custom URL and executes THOR on the local system writing log files or transmitting syslog messages to a remote system
    .PARAMETER AsgardServer
        Enter the server name (FQDN) or IP address of your ASGARD instance.
    .PARAMETER UseCloud
        Use the official Nextron cloud systems instead of an ASGARD instance.
    .PARAMETER Token
        Download token used when connecting to Nextron's cloud service instead of an ASGARD instance.
    .PARAMETER Comment
        A comment that will be transmitted to the Nextron cloud servers and shown in the customer portal for the generated license (only used with -UseCloud).
    .PARAMETER CustomUrl
        Allows you to define a custom URL from which the THOR package is retrieved. Make sure that the package contains the full program folder, provide it as ZIP archive and add valid licenses (Incident Response license, THOR Lite license). THOR Seed will automatically find the THOR binaries in the extracted archive.
    .PARAMETER Cockpit
        Use this Analysis Cockpit to upload the THOR results
    .PARAMETER CockpitKey
        Use this API key for the upload to the Analysis Cockpit (Create a new user and role in your Analysis Cockpit. The role should only include the "Upload Events" permissions)
    .PARAMETER RandomDelay
        A random delay in seconds before the scan starts. This is helpful when you start the script on thousands of end systems to avoid system (VM host) or network (package retrieval) overload by distributing the load over a defined time range.
    .PARAMETER CpuLimit
        Limit THOR CPU usage by passing --cpulimit <value> (1-100)
    .PARAMETER OutputPath
        Directory to write all output files to (default is script directory)
    .PARAMETER NoLog
        Do not write a log file in the current working directory of the PowerShell script named thor-seed.log.
    .PARAMETER Debugging
        Do not remove temporary files and show some debug outputs for debugging purposes.
    .PARAMETER Cleanup
        Removes all log and report files of previous scans
    .PARAMETER IgnoreSSLErrors
        Ignore connection errors caused by self-signed certificates
    .PARAMETER NoResControl
        Disable THOR resource safeguards by passing --norescontrol (can increase risk of swapping and performance impact)
    .PARAMETER ProxyAddress
        Proxy address to use format: http://host:port
    .PARAMETER ProxyCredentials
        Proxy credentials to authenticate. Bye default Empty.
    .EXAMPLE
        ASGARD examples

        # ASGARD without token (if token enforcement is disabled)
        thor-seed -AsgardServer asgard1.intranet.local

        # ASGARD with token (if token enforcement is enabled)
        thor-seed -AsgardServer asgard1.intranet.local -Token 6Nf0Qv8F4jA2sZ9pHk1wY

        # ASGARD with token and self-signed TLS cert in lab environments
        thor-seed -AsgardServer asgard1.intranet.local -Token 6Nf0Qv8F4jA2sZ9pHk1wY -IgnoreSSLErrors

        # ASGARD with Analysis Cockpit upload
        thor-seed -AsgardServer asgard1.intranet.local -Token 6Nf0Qv8F4jA2sZ9pHk1wY -Cockpit cockpit1.intranet.local -CockpitKey YOUR_API_KEY
    .EXAMPLE
        Nextron cloud examples

        # Cloud download with token
        thor-seed -UseCloud -Token wWfC0A0kMziG7GRJ5XEcGdZKw3BrigavxAdw9C9yxJX

        # Cloud download with token and comment
        thor-seed -UseCloud -Token wWfC0A0kMziG7GRJ5XEcGdZKw3BrigavxAdw9C9yxJX -Comment "IR Case 2026-02-10"
    .EXAMPLE
        Custom package and maintenance examples

        # Download THOR or THOR Lite package from a custom URL and execute it
        thor-seed -CustomUrl https://web1.server.local/thor/mythor-pack.zip

        # Start a scan with custom output path and random delay window
        thor-seed -AsgardServer asgard1.intranet.local -OutputPath C:\Windows\Temp\thor -RandomDelay 300

        # Limit THOR CPU usage to reduce user impact and fan noise
        thor-seed -AsgardServer asgard1.intranet.local -Token 6Nf0Qv8F4jA2sZ9pHk1wY -CpuLimit 40

        # Disable THOR resource safeguards (advanced use only)
        thor-seed -AsgardServer asgard1.intranet.local -Token 6Nf0Qv8F4jA2sZ9pHk1wY -NoResControl

        # Remove THOR output files from previous runs
        thor-seed -Cleanup
    .NOTES
        You can set a static download token and ASGARD server in this file (see below in the parameters)

        We recommend using the configuration sections in this script to adjust the scan settings.
        It includes presets for scan configs and false positive filters.
        See the $PresetConfig.. and $PresetFalsePositiveFilters below.

#>

# #####################################################################
# Parameters ----------------------------------------------------------
# #####################################################################

[CmdletBinding(PositionalBinding = $false)]
param
(
    [Parameter(
               HelpMessage = 'The ASGARD instance to download THOR from (license will be generated on that instance)')]
    [ValidateNotNullOrEmpty()]
    [Alias('AMC')]
    [string]$AsgardServer,

    [Parameter(HelpMessage = "Use Nextron's cloud to download THOR and generate a license")]
    [ValidateNotNullOrEmpty()]
    [Alias('CP')]
    [switch]$UseCloud,

    [Parameter(HelpMessage = "Set a download token (used with ASGARD and Nextron cloud servers)")]
    [ValidateNotNullOrEmpty()]
    [Alias('T')]
    [string]$Token,

    [Parameter(HelpMessage = 'Add a comment that will be shown in the customer portal for the generated license (only used with -UseCloud)')]
    [ValidateNotNullOrEmpty()]
    [Alias('Co')]
    [string]$Comment,

    [Parameter(HelpMessage = 'Allows you to define a Analysis Cockpit to upload the scan results')]
    [ValidateNotNullOrEmpty()]
    [Alias('AC')]
    [string]$Cockpit,

    [Parameter(HelpMessage = "Set the API key (used with your Analysis Cockpit)")]
    [ValidateNotNullOrEmpty()]
    [Alias('CK')]
    [string]$CockpitKey,

    [Parameter(HelpMessage = 'Allows you to define a custom URL from which the THOR package is retrieved (must start with http:// or https://)')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if ($_ -match '^https?://') { $true }
        else { throw "CustomUrl must start with http:// or https://" }
    })]
    [Alias('CU')]
    [string]$CustomUrl,

    [Parameter(HelpMessage = 'Add a random sleep delay in seconds (0-3600, i.e. 0-60 minutes) to the scan start to avoid all scripts starting at the exact same second')]
    [ValidateRange(0, 3600)]
    [Alias('RD')]
    [int]$RandomDelay = 10,

    [Parameter(HelpMessage = 'Limit THOR CPU usage by passing --cpulimit <value> (1-100)')]
    [ValidateRange(1, 100)]
    [Alias('CL')]
    [int]$CpuLimit = 0,

    [Parameter(HelpMessage = 'Directory to write all output files to (default is script directory)')]
    [ValidateNotNullOrEmpty()]
    [Alias('OP')]
    [string]$OutputPath,

    [Parameter(HelpMessage = 'Deactivates log file for this PowerShell script (thor-run.log)')]
    [ValidateNotNullOrEmpty()]
    [Alias('NL')]
    [switch]$NoLog,

    [Parameter(HelpMessage = 'Enables debug output and skips cleanup at the end of the scan')]
    [ValidateNotNullOrEmpty()]
    [Alias('D')]
    [switch]$Debugging,

    [Parameter(HelpMessage = 'Removes all log and report files of previous scans')]
    [ValidateNotNullOrEmpty()]
    [Alias('C')]
    [switch]$Cleanup,

    [Parameter(HelpMessage = 'Ignore connection errors caused by self-signed certificates')]
    [ValidateNotNullOrEmpty()]
    [Alias('I')]
    [switch]$IgnoreSSLErrors,

    [Parameter(HelpMessage = 'Disable THOR resource safeguards by passing --norescontrol (advanced use only; may increase swapping and performance impact)')]
    [ValidateNotNullOrEmpty()]
    [Alias('NRC')]
    [switch]$NoResControl,

    [Parameter(HelpMessage = 'Proxy Address')]
    [ValidateNotNullOrEmpty()]
    [Alias('P')]
    [string]$ProxyAddress,

    [Parameter(HelpMessage = 'Proxy Credentials')]
    [ValidateNotNullOrEmpty()]
    [Alias('PC')]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential][System.Management.Automation.Credential()]
    $ProxyCredentials = [System.Management.Automation.PSCredential]::Empty
)

# #####################################################################
# Presets -------------------------------------------------------------
# #####################################################################

# Write local log file for THOR Seed script activity
#[bool]$NoLog = $True

# ASGARD Server (IP or FQDN)
#[string]$AsgardServer = "asgard.beta.nextron-systems.com"

# Use Nextron cloud servers
#[bool]$UseCloud = $True

# Download Token
# usable with Nextron cloud servers and ASGARD
#[string]$Token = "YOUR DOWNLOAD TOKEN"

# Comment
# shown in the customer portal for the generated license (only used with -UseCloud)
#[string]$Comment = "Incident Response - yourcompany.local"

# Analysis Cockpit (IP or FQDN)
#[string]$Cockpit = "cockpit.beta.nextron-systems.com"

# Cockpit Key
# usable with your Analysis Cockpit
#[string]$CockpitKey = "YOUR ANALYSIS COCKPIT API TOKEN"

# Ignore SSL Errors
# Helpful when using a local ASGARD instance
#$IgnoreSSLErrors = $True

# Disable THOR resource safeguards (advanced use only)
# passes --norescontrol to THOR
#$NoResControl = $True

# Random Delay (added before the scan start to distribute the initial load)
#[int]$RandomDelay = 1

# THOR CPU limit (1-100, optional)
#[int]$CpuLimit = 40

# Custom URL with THOR package
#[string]$CustomUrl = "https://internal-webserver1.intranet.local"

# Custom Output Path
# Choose an output directory for all output files (log, HTML report)
#[string]$OutputPath = "C:\Windows\Temp"

# Fixing Certain Platform Environments --------------------------------
$AutoDetectPlatform = ""
if ($OutputPath -eq "")
{
    $OutputPath = $PSScriptRoot
}

# Microsoft Defender ATP - Live Response
# $PSScriptRoot is empty or contains path to Windows Defender
if ($OutputPath -eq "" -or $OutputPath.Contains("Windows Defender Advanced Threat Protection"))
{
    $AutoDetectPlatform = "MDATP"
    # Setting output path to easily accessible system root, e.g. C:
    if ($OutputPath -eq "")
    {
        $OutputPath = "$($env:ProgramData)\thor"
    }
}

# Predefined YAML Config
$UsePresetConfig = $True
# Lines with '#' are commented and inactive. We decided to give you
# some examples for your convenience. You can see all possible command
# line parameters running `thor64.exe --help` or on this web page:
# https://github.com/NextronSystems/nextron-helper-scripts/tree/master/thor-help
# Only the long forms of the parameters are accepted in the YAML config.

# PRESET CONFIGS

# FULL with Lookback
# Preset template for a complete scan with a lookback of 14 days
# Hint: lookback in conjunction with the global-lookback parameter applies the "lookback" value to all possible modules (e.g. Filescan, etc.). This reduces scan time significantly.
# Run time: 30 to 60 minutes
# Specifics:
#   - runs all default modules
#   - only scans elements that have been changed or created within the last 14 days
#   - applies Sigma rules
# cloudconf: [!]PresetConfig_FullLookback [Full Scan with Lookback] Performs a full disk scan with all modules but only checks elements changed or created within the last 14 days - best for SOC response to suspicious events (20 to 40 min)
$PresetConfig_FullLookback = @"
rebase-dir: $($OutputPath)  # Path to store all output files (default: script location)
nosoft: true           # Don't throttle the scan, even on single core systems
global-lookback: true  # Apply lookback to all possible modules
lookback: 14           # Log and Eventlog look back time in days
# cpulimit: 70         # Limit the CPU usage of the scan
sigma: true            # Activate Sigma scanning on Eventlogs
nofserrors: true       # Don't print an error for non-existing directories selected in quick scan
nocsv: true            # Don't create CSV output file with all suspicious files
noscanid: true         # Don't print a scan ID at the end of each line (only useful in SIEM import use cases)
nothordb: true         # Don't create a local SQLite database for differential analysis of multiple scans
"@

# QUICK
# Preset template for a quick scan
# Run time: 10 to 30 minutes
# Specifics:
#   - runs all default modules except Eventlog and a full file system scan
#   - in quick mode only a highly relevant subset of folders gets scanned
#   - skips Registry checks (keys with potential for persistence still get checked in Autoruns module)
# cloudconf: PresetConfig_Quick [Quick Scan] Performs a quick scan on processes, caches, persistence elements and selected highly relevant directories (10 to 20 min)
$PresetConfig_Quick = @"
rebase-dir: $($OutputPath)  # Path to store all output files (default: script location)
nosoft: true       # Don't throttle the scan, even on single core systems
quick: true        # Quick scan mode
nofserrors: true   # Don't print an error for non-existing directories selected in quick scan
nocsv: true        # Don't create CSV output file with all suspicious files
noscanid: true     # Don't print a scan ID at the end of each line (only useful in SIEM import use cases)
nothordb: true     # Don't create a local SQLite database for differential analysis of multiple scans
"@

# FULL
# Preset template for a complete scan
# Hint: lookback per default only applies to the Eventlog module, meaning no Eventlog entries older than 14 days get scanned, but all other modules scan the full system (e.g. Filescan, etc.). This will reduce scan time a little bit, especially on systems with many Eventlog entries.
# Run time: 40 minutes to 6 hours
# Specifics:
#   - runs all default modules
#   - only scans the last 14 days of the Eventlog
#   - applies Sigma rules
# cloudconf: PresetConfig_Full [Full Scan] Performs a full disk scan with all modules (40 min to 6 hours)
$PresetConfig_Full = @"
rebase-dir: $($OutputPath)  # Path to store all output files (default: script location)
nosoft: true       # Don't throttle the scan, even on single core systems
lookback: 14       # Log and Eventlog look back time in days
# cpulimit: 70     # Limit the CPU usage of the scan
sigma: true        # Activate Sigma scanning on Eventlogs
nofserrors: true   # Don't print an error for non-existing directories selected in quick scan
nocsv: true        # Don't create CSV output file with all suspicious files
noscanid: true     # Don't print a scan ID at the end of each line (only useful in SIEM import use cases)
nothordb: true     # Don't create a local SQLite database for differential analysis of multiple scans
"@

# SELECT YOU CONFIG
# Select your preset config
# Choose between: $PresetConfig_Full, $PresetConfig_Quick, $PresetConfig_FullLookback
$PresetConfig = $PresetConfig_FullLookback

# False Positive Filters
$UseFalsePositiveFilters = $True
# The following new line separated false positive filters get
# applied to all log lines as regex values.
$PresetFalsePositiveFilters = @"
Could not get files of directory
Signature file is older than 60 days
\\Our-Custom-Software\\v1.[0-9]+\\
"@

# Global Variables ----------------------------------------------------
$global:NoLog = $NoLog
$script:ExecutionFailed = $False
$script:FailureReason = ""
$script:ExitCode = 0
$script:KeepTempArtifacts = $False
$script:ThorDirectory = $null
$script:TempPackage = $null
$script:CockpitUploadSucceeded = $False
$script:SummaryGuidance = @()

# Show Help -----------------------------------------------------------
# No ASGARD server
if ($Args.Count -eq 0 -and $AsgardServer -eq "" -and $UseCloud -eq $False -and $CustomUrl -eq "")
{
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    Write-Host -ForegroundColor Yellow 'Note: You must at least define an ASGARD server (-AsgardServer), use the Nextron cloud (-UseCloud) with an download token (-Token) or provide a custom URL to a THOR / THOR Lite ZIP package on a webserver (-CustomUrl)'
    return
}
# Nextron cloud servers but no download token
if ($UseCloud -eq $True -and $Token -eq "")
{
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    Write-Host -ForegroundColor Yellow 'Note: You must provide an download token via command line parameter -Token or as preset value in the "presets" section of this PowerShell script.'
    return
}

# Analysis Cockpit but no API key
if (!([string]::IsNullOrEmpty($Cockpit)) -and ([string]::IsNullOrEmpty($CockpitKey)))
{
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    Write-Host -ForegroundColor Yellow 'Note: You must provide an API key via command line parameter -CockpitKey or as preset value in the "presets" section of this PowerShell script.'
    return
}
# API key provided but no Analysis Cockpit host
if (([string]::IsNullOrEmpty($Cockpit)) -and !([string]::IsNullOrEmpty($CockpitKey)))
{
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    Write-Host -ForegroundColor Yellow 'Note: You must provide an Analysis Cockpit host via command line parameter -Cockpit when using -CockpitKey.'
    return
}
# Common typo guard (e.g. "--Cockpit" instead of "-Cockpit")
if (!([string]::IsNullOrEmpty($Cockpit)) -and $Cockpit -match '^-')
{
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    Write-Host -ForegroundColor Yellow "Note: Invalid -Cockpit value '$Cockpit'. Did you mean to use -Cockpit <host> (single dash), e.g. -Cockpit cockpit.example.local ?"
    return
}

# #####################################################################
# Functions -----------------------------------------------------------
# #####################################################################

function New-TemporaryDirectory
{
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

# Required for ZIP extraction in PowerShell version <5.0
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Expand-File
{
    param ([string]$ZipFile,
        [string]$OutPath)
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $OutPath)
}

function Write-Log
{
    param (
        [Parameter(Mandatory = $True, Position = 0, HelpMessage = "Log entry")]
        [ValidateNotNullOrEmpty()]
        [String]$Entry,
        [Parameter(Position = 1, HelpMessage = "Log file to write into")]
        [ValidateNotNullOrEmpty()]
        [Alias('SS')]
        [IO.FileInfo]$LogFile = "thor-seed.log",
        [Parameter(Position = 3, HelpMessage = "Level")]
        [ValidateNotNullOrEmpty()]
        [String]$Level = "Info"
    )

    # Indicator
    $Indicator = "[+] "
    if ($Level -eq "Warning")
    {
        $Indicator = "[!] "
    }
    elseif ($Level -eq "Error")
    {
        $Indicator = "[E] "
    }
    elseif ($Level -eq "Progress")
    {
        $Indicator = "[.] "
    }
    elseif ($Level -eq "Note")
    {
        $Indicator = "[i] "
    }
    elseif ($Level -eq "Help")
    {
        $Indicator = ""
    }

    # Output Pipe
    if ($Level -eq "Warning")
    {
        Write-Warning -Message "$($Indicator) $($Entry)"
    }
    elseif ($Level -eq "Error")
    {
        Write-Host "$($Indicator)$($Entry)" -ForegroundColor Red
    }
    else
    {
        Write-Host "$($Indicator)$($Entry)"
    }

    # Log File
    if ($global:NoLog -eq $False)
    {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $($env:COMPUTERNAME): $Entry" | Out-File -FilePath $LogFile -Append
    }
}

function Get-RedactedUrl
{
    param (
        [Parameter(Mandatory = $True)]
        [string]$Url
    )

    # Redact common credential query parameter values before writing URLs to logs.
    return ($Url -replace '(?i)([?&](?:token|access_token|apikey|api_key|authorization)=)[^&]*', '$1***')
}

function Set-ExecutionFailure
{
    param (
        [Parameter(Mandatory = $True)]
        [string]$Reason,
        [int]$Code = 1,
        [switch]$KeepArtifacts
    )

    if (-not $script:ExecutionFailed -and -not [string]::IsNullOrWhiteSpace($Reason))
    {
        $script:FailureReason = $Reason
    }
    $script:ExecutionFailed = $True
    if ($script:ExitCode -eq 0)
    {
        $script:ExitCode = $Code
    }
    if ($KeepArtifacts)
    {
        $script:KeepTempArtifacts = $True
    }
}

function Test-IsAdministrator
{
    try
    {
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch
    {
        return $False
    }
}

function Test-OutputPathWritable
{
    param (
        [Parameter(Mandatory = $True)]
        [string]$Path
    )

    try
    {
        if (-not (Test-Path -Path $Path))
        {
            New-Item -ItemType Directory -Force -Path $Path | Out-Null
            Write-Log "Output path $($Path) successfully created."
        }
        $WriteTestFile = Join-Path $Path "thor-seed-write-test-$([guid]::NewGuid().ToString()).tmp"
        Set-Content -Path $WriteTestFile -Value "thor-seed-write-test" -Encoding ASCII -ErrorAction Stop
        Remove-Item -LiteralPath $WriteTestFile -Force -Recurse -Confirm:$False -ErrorAction Stop
        return $True
    }
    catch
    {
        Write-Log "Output path '$Path' is not writable: $($_.Exception.Message)" -Level "Error"
        return $False
    }
}

function Get-ThorRunFailureAnalysis
{
    param (
        [Parameter(Mandatory = $True)]
        [string]$OutputPath,
        [Parameter(Mandatory = $True)]
        [string]$Hostname,
        [Parameter(Mandatory = $True)]
        [datetime]$RunStartTime
    )

    $Result = [ordered]@{
        Type = "Unknown"
        LogPath = ""
        Evidence = ""
    }

    $ThorTxtLogs = @(Get-ChildItem -Path "$($OutputPath)\*" -Filter "$($Hostname)_thor_*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($ThorTxtLogs.Count -lt 1)
    {
        $Result.Type = "NoLog"
        return [PSCustomObject]$Result
    }

    $SelectedLog = $ThorTxtLogs | Where-Object { $_.LastWriteTime -ge $RunStartTime.AddMinutes(-1) } | Select-Object -First 1
    if ($null -eq $SelectedLog)
    {
        $SelectedLog = $ThorTxtLogs[0]
    }
    $Result.LogPath = $SelectedLog.FullName

    try
    {
        $TailLines = @(Get-Content -Path $SelectedLog.FullName -Tail 1000 -ErrorAction Stop)
    }
    catch
    {
        $Result.Type = "LogReadError"
        $Result.Evidence = $_.Exception.Message
        return [PSCustomObject]$Result
    }

    $MemorySafeguardPattern = 'Available physical memory dropped below'
    $MemorySafeguardEvidence = $TailLines | Select-String -Pattern $MemorySafeguardPattern | Select-Object -First 1
    if ($null -ne $MemorySafeguardEvidence)
    {
        $Result.Type = "ResourceSafeguardMemory"
        $Result.Evidence = $MemorySafeguardEvidence.Line.Trim()
        return [PSCustomObject]$Result
    }

    $CrashPattern = 'panic: runtime error|fatal error: stack overflow|\[signal SIGSEGV|runtime stack:|goroutine\s+\d+\s+\[running\]'
    $CrashEvidence = $TailLines | Select-String -Pattern $CrashPattern | Select-Object -First 1
    if ($null -ne $CrashEvidence)
    {
        $Result.Type = "Crash"
        $Result.Evidence = $CrashEvidence.Line.Trim()
        return [PSCustomObject]$Result
    }

    $CompletedPattern = 'Thor Scan finished END_TIME|Info End Time:'
    $CompletedEvidence = $TailLines | Select-String -Pattern $CompletedPattern | Select-Object -First 1
    if ($null -ne $CompletedEvidence)
    {
        $Result.Type = "CompletedWithErrorCode"
        $Result.Evidence = $CompletedEvidence.Line.Trim()
        return [PSCustomObject]$Result
    }

    $Result.Type = "UnexpectedTermination"
    return [PSCustomObject]$Result
}

function Add-SummaryGuidance
{
    param (
        [Parameter(Mandatory = $True)]
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Message))
    {
        return
    }
    if ($script:SummaryGuidance -notcontains $Message)
    {
        $script:SummaryGuidance += $Message
    }
}

# #####################################################################
# Main Program --------------------------------------------------------
# #####################################################################

Write-Host "==========================================================="
Write-Host "   ________ ______  ___    ____           __    ___        "
Write-Host "  /_  __/ // / __ \/ _ \  / __/__ ___ ___/ /   /   \       "
Write-Host "   / / / _  / /_/ / , _/ _\ \/ -_) -_) _  /   /_\ /_\      "
Write-Host "  /_/ /_//_/\____/_/|_| /___/\__/\__/\_,_/    \ / \ /      "
Write-Host "                                               \   /       "
Write-Host "  Nextron Systems, by Florian Roth              \_/        "
Write-Host "  v2.0.0 - Last Modified: 11.02.2026                       "
Write-Host "==========================================================="

# Measure time
$DateStamp = Get-Date -f yyyy-MM-dd
$StartTime = $(Get-Date)

Write-Log "Started thor-seed with PowerShell v$($PSVersionTable.PSVersion)"

# ---------------------------------------------------------------------
# Evaluation ----------------------------------------------------------
# ---------------------------------------------------------------------

# Hostname
$Hostname = [System.Net.Dns]::GetHostName()
# Evaluate Architecture
$ThorArch = "64"
if ([System.Environment]::Is64BitOperatingSystem -eq $False)
{
    $ThorArch = ""
}
# License Type
$LicenseType = "server"
$PortalLicenseType = "server"
try
{
    $OsInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
}
catch
{
    # Fallback for older systems (Windows 7/2008 R2) or damaged WMI
    try
    {
        $OsInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
    }
    catch
    {
        Write-Log "Could not determine OS type, defaulting to server license" -Level "Warning"
        $OsInfo = $null
    }
}
if ($null -ne $OsInfo -and $OsInfo.ProductType -eq 1)
{
    $LicenseType = "client"
    $PortalLicenseType = "workstation"
}

# Output Info on Auto-Detection
if ($AutoDetectPlatform -ne "")
{
    Write-Log "Auto Detect Platform: $($AutoDetectPlatform)"
    Write-Log "Note: Some automatic changes have been applied"
}

# Report source precedence explicitly when more than one THOR source is configured.
$RequestedThorSources = @()
if (-not [string]::IsNullOrEmpty($AsgardServer))
{
    $RequestedThorSources += "ASGARD (-AsgardServer $AsgardServer)"
}
if ($UseCloud)
{
    $RequestedThorSources += "Nextron cloud (-UseCloud)"
}
if (-not [string]::IsNullOrEmpty($CustomUrl))
{
    $RequestedThorSources += "custom URL (-CustomUrl $(Get-RedactedUrl -Url $CustomUrl))"
}
if ($RequestedThorSources.Count -gt 1)
{
    $SelectedThorSource = "custom URL (-CustomUrl)"
    if (-not [string]::IsNullOrEmpty($AsgardServer))
    {
        $SelectedThorSource = "ASGARD (-AsgardServer $AsgardServer)"
    }
    elseif ($UseCloud)
    {
        $SelectedThorSource = "Nextron cloud (-UseCloud)"
    }
    Write-Log "Multiple THOR sources specified: $($RequestedThorSources -join ', '). Using $SelectedThorSource based on precedence: -AsgardServer, then -UseCloud, then -CustomUrl." -Level "Warning"
}

# ---------------------------------------------------------------------
# THOR still running --------------------------------------------------
# ---------------------------------------------------------------------
$ThorProcess = Get-Process -Name "thor64" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $ThorProcess)
{
    $ThorProcess = Get-Process -Name "thor" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($ThorProcess)
{
    Write-Log "A THOR process is still running ($($ThorProcess.Name))." -Level "Error"
}

# Output File Overview
$OutputFiles = @(Get-ChildItem -Path "$($OutputPath)\*" -Include "$($Hostname)_thor_*" -ErrorAction SilentlyContinue | Sort-Object CreationTime)
if (-not $Cleanup)
{
    # Give help depending on the auto-detected platform
    if ($AutoDetectPlatform -eq "MDATP")
    {
        Write-Log "Detected Platform: Microsoft Defender ATP"
        if ($ThorProcess)
        {
            if ($OutputFiles.Length -gt 0)
            {
                Write-Log "Hint: You can use the following commands to retrieve the scan logs"
                foreach ($OutFile in $OutputFiles)
                {
                    Write-Log "getfile `"$($OutFile.FullName)`"" -Level "Help"
                }
            }
            else
            {
                Write-Log "The scan hasn't produced any output files yet."
            }
        }
        # Cannot run new THOR instance as long as old log files are present
        if (-not $ThorProcess -and $OutputFiles.Length -gt 0)
        {
            Write-Log "Cannot start new THOR scan as long as old report files are present" -Level "Error"
            Write-Log "1.) Retrieve the available log files and HTML reports" -Level "Help"
            foreach ($OutFile in $OutputFiles)
            {
                Write-Log "    getfile `"$($OutFile.FullName)`"" -Level "Help"
            }
            Write-Log "2.) Use the following command to cleanup the output directory and remove all previous reports" -Level "Help"
            Write-Log "    run thor-seed.ps1 -parameters `"-Cleanup`"" -Level "Help"
            Write-Log "3.) Start a new THOR scan with" -Level "Help"
            Write-Log "    run thor-seed.ps1" -Level "Help"
            return
        }
        else
        {
            Write-Log "No logs found of a previous scan"
        }
    }
    else
    {
        Write-Log "Checking output folder: $($OutputPath)" -Level "Progress"
        if ($OutputFiles.Length -gt 0)
        {
            Write-Log "Output files that have been generated so far:"
            foreach ($OutFile in $OutputFiles)
            {
                Write-Log "$($OutFile.FullName)" -Level "Help"
            }
        }
    }
}

# Quit if THOR is still running
if ($ThorProcess -and $Cleanup)
{
    Write-Log "Please wait until the THOR scan is completed until you cleanup the logs (cleanup interrupted)" -Level "Error"
}
if ($ThorProcess)
{
    # Get current status
    $LastTxtFile = Get-ChildItem -Path "$($OutputPath)\*" -Include "$($Hostname)_thor_*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($null -eq $LastTxtFile)
    {
        Write-Log "No THOR text log found yet in output path $($OutputPath)." -Level "Warning"
        return
    }
    Write-Log "Last written log file is: $($LastTxtFile.FullName)"
    Write-Log "Trying to get the last 3 log lines" -Level "Progress"
    # Get last 3 lines
    $LastLines = Get-Content -Tail 3 $LastTxtFile.FullName -ErrorAction SilentlyContinue
    $OutLines = $LastLines -join "`r`n" | Out-String
    Write-Log "The last 3 log lines are:"
    Write-Log $OutLines

    # Quit
    return
}

# ---------------------------------------------------------------------
# Cleanup Only --------------------------------------------------------
# ---------------------------------------------------------------------
if ($Cleanup)
{
    Write-Log "Starting cleanup" -Level "Progress"
    # Remove logs and reports
    Remove-Item -Confirm:$False -Recurse -Force -Path "$($OutputPath)\*" -Include "$($Hostname)_thor_*"
    Write-Log "Cleanup complete"
    return
}

# ---------------------------------------------------------------------
# Preflight -----------------------------------------------------------
# ---------------------------------------------------------------------
Write-Log "Running preflight checks" -Level "Progress"
if (-not (Test-IsAdministrator))
{
    Write-Log "THOR requires an elevated PowerShell session (Run as Administrator)." -Level "Error"
    Write-Log "Please restart PowerShell as Administrator and run thor-seed again." -Level "Warning"
    Set-ExecutionFailure -Reason "Scan requires elevation (administrator privileges)." -Code 2
}
if (-not (Test-OutputPathWritable -Path $OutputPath))
{
    Set-ExecutionFailure -Reason "Output path is not writable: $OutputPath" -Code 3
}
if ($AsgardServer -and [string]::IsNullOrWhiteSpace($Token))
{
    Write-Log "No download token provided. This can work if your ASGARD does not require download tokens." -Level "Note"
    Write-Log "If the download fails with HTTP 401/403, rerun with -Token <download-token>." -Level "Note"
}

# ---------------------------------------------------------------------
# Get THOR ------------------------------------------------------------
# ---------------------------------------------------------------------
# Save original SSL certificate callback to restore later
$OriginalCertCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback

if (-not $script:ExecutionFailed)
{
    try
    {
        # Random Delay
        $LocalDelay = 0
        if ($RandomDelay -gt 0)
        {
            $LocalDelay = Get-Random -Minimum 0 -Maximum ($RandomDelay + 1)
        }
        Write-Log "Adding random delay to the scan start (max. $($RandomDelay)): sleeping for $($LocalDelay) seconds" -Level "Progress"
        Start-Sleep -Seconds $LocalDelay

        # Presets
        # Temporary directory for the THOR package
        $script:ThorDirectory = New-TemporaryDirectory
        $script:TempPackage = Join-Path $script:ThorDirectory "thor-package.zip"

        # Generate Download URL
        # Web Client
        try
        {
            # Web Client
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $WebClient = New-Object System.Net.WebClient
            if ($Token)
            {
                $WebClient.Headers.add('Authorization', $Token)
            }
            # Proxy Support
            if ($ProxyAddress)
            {
                $WebClient.Proxy = New-Object System.Net.WebProxy($ProxyAddress)
            }
            else
            {
                $WebClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
            }
            # https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/add-credentials-to-powershell-functions?view=powershell-5.1
            if ($ProxyCredentials -ne [System.Management.Automation.PSCredential]::Empty)
            {
                $WebClient.Proxy.Credentials = $ProxyCredentials
            }
            else
            {
                $WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            }
            # Download Source
            # Asgard Instance
            if ($AsgardServer -ne "")
            {
                Write-Log "Attempting to download THOR from $AsgardServer" -Level "Progress"
                # Generate download URL - pre ASGARD 2.11
                #$DownloadUrl = "https://$($AsgardServer):8443/api/v0/downloads/thor/thor10-win?hostname=$($Hostname)&type=$($LicenseType)&iocs=%5B%22default%22%5D&token="
                # Generate download URL - post ASGARD 2.11
                $DownloadUrl = "https://$($AsgardServer):8443/api/v1/downloads/thor?os=windows&type=$($LicenseType)&scanner=thor10%40latest&signatures=signatures&hostname=$($Hostname)&token=$($Token)"
            }
            # Netxron Customer Portal
            elseif ($UseCloud)
            {
                Write-Log 'Attempting to download THOR from Nextron cloud portal, please wait ...' -Level "Progress"
                $DownloadUrl = "https://cloud.nextron-systems.com/api/public/thor10"
                # Parameters
                $WebClient.Headers.add('X-OS', 'windows')
                $WebClient.Headers.add('X-Type', $PortalLicenseType)
                if ($ThorArch -eq "64")
                {
                    $WebClient.Headers.add('X-Arch', 'amd64')
                }
                else
                {
                    $WebClient.Headers.add('X-Arch', 'x86')
                }
                $WebClient.Headers.add('X-Token', $Token)
                $WebClient.Headers.add('X-Hostname', $Hostname)
                if ($Comment)
                {
                    $WebClient.Headers.add('X-Comment', $Comment)
                }
            }
            # Custom URL
            elseif ($CustomUrl -ne "")
            {
                $DownloadUrl = $CustomUrl
            }
            else
            {
                Write-Log 'Download URL cannot be generated (select one of the three options: $AsgardServer, $UseCloud or $CustomUrl)' -Level "Error"
                Set-ExecutionFailure -Reason "Download URL cannot be generated." -Code 4
                throw "Download URL cannot be generated."
            }
            # Actual Download with retry logic
            $SafeDownloadUrl = Get-RedactedUrl -Url $DownloadUrl
            Write-Log "Download URL: $($SafeDownloadUrl)"
            # Ignore SSL/TLS errors
            if ($IgnoreSSLErrors)
            {
                [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }
            $MaxRetries = 3
            $RetryDelay = 5
            for ($Attempt = 1; $Attempt -le $MaxRetries; $Attempt++)
            {
                try
                {
                    Write-Log "Download attempt $Attempt of $MaxRetries" -Level "Progress"
                    $WebClient.DownloadFile($DownloadUrl, $script:TempPackage)
                    break
                }
                catch [System.Net.WebException]
                {
                    $StatusCode = $null
                    if ($_.Exception.Response -and $_.Exception.Response.StatusCode)
                    {
                        $StatusCode = [int]$_.Exception.Response.StatusCode
                    }
                    $ErrorMessage = $_.Exception.Message

                    if ($StatusCode -eq 401 -or $StatusCode -eq 403)
                    {
                        Write-Log "Download failed: HTTP $StatusCode Unauthorized/Forbidden." -Level "Warning"
                        Write-Log "This usually means the download token is missing, invalid, or expired. Use -Token <download-token>." -Level "Warning"
                        throw
                    }
                    if ($ErrorMessage -match 'trust relationship for the SSL/TLS secure channel|Could not establish trust relationship|certificate')
                    {
                        Write-Log "Download failed: TLS certificate validation failed." -Level "Warning"
                        Write-Log "If this is an internal test/lab environment, rerun with -IgnoreSSLErrors to bypass certificate validation." -Level "Warning"
                        throw
                    }

                    if ($Attempt -eq $MaxRetries) { throw }
                    Write-Log "Download failed: $ErrorMessage" -Level "Warning"
                    Write-Log "Retrying in $RetryDelay seconds..." -Level "Warning"
                    Start-Sleep -Seconds $RetryDelay
                    $RetryDelay *= 2
                }
                catch
                {
                    if ($Attempt -eq $MaxRetries) { throw }
                    Write-Log "Download failed: $($_.Exception.Message)" -Level "Warning"
                    Write-Log "Retrying in $RetryDelay seconds..." -Level "Warning"
                    Start-Sleep -Seconds $RetryDelay
                    $RetryDelay *= 2
                }
            }
            Write-Log "Successfully downloaded THOR package to $($script:TempPackage)"
        }
        # HTTP Errors
        catch [System.Net.WebException] {
            Write-Log "The following error occurred: $($_.Exception.Message)" -Level "Error"
            $Response = $_.Exception.Response
            $StatusCode = $null
            if ($Response -and $Response.StatusCode)
            {
                $StatusCode = [int]$Response.StatusCode
            }
            $ExceptionMessage = $_.Exception.Message
            # 401 Unauthorized
            if ($StatusCode -eq 401 -or $StatusCode -eq 403)
            {
                Write-Log "The server returned HTTP $StatusCode (Unauthorized/Forbidden)." -Level "Warning"
                Write-Log "Set a valid download token using -Token <download-token> and try again." -Level "Warning"
                if ($UseCloud)
                {
                    Write-Log "Note: you can find your download token here: https://portal.nextron-systems.com/"
                }
                elseif ($AsgardServer)
                {
                    Write-Log "Note: ASGARD token settings and user token can be checked at: https://$($AsgardServer):8443/ui/user-settings#tab-Token"
                }
            }
            # 400
            elseif ($StatusCode -eq 400)
            {
                Write-Log "The request was rejected by the server (HTTP 400)." -Level "Warning"
                Write-Log "This can be caused by missing or malformed download parameters, including token settings." -Level "Warning"
            }
            # 409
            elseif ($StatusCode -eq 409 -and $UseCloud)
            {
                Write-Log "Your license pool has been exhausted (quota limit)." -Level "Warning"
            }
            # 500
            elseif ($StatusCode -ge 500)
            {
                Write-Log "Server internal error. Please report this error or try again later." -Level "Warning"
            }
            elseif ($ExceptionMessage -match 'trust relationship for the SSL/TLS secure channel|Could not establish trust relationship|certificate')
            {
                Write-Log "TLS certificate validation failed while connecting to $DownloadUrl" -Level "Warning"
                Write-Log "If this is an internal test/lab environment, rerun with -IgnoreSSLErrors to bypass certificate validation." -Level "Warning"
            }
            Set-ExecutionFailure -Reason "THOR package download failed." -Code 4 -KeepArtifacts
        }
        catch
        {
            Write-Log "The following error occurred: $($_.Exception.Message)" -Level "Error"
            Set-ExecutionFailure -Reason "THOR package download failed." -Code 4 -KeepArtifacts
        }
        if (-not $script:ExecutionFailed)
        {
            # Unzip
            try
            {
                Write-Log "Extracting THOR package" -Level "Progress"
                # Validate ZIP file before extraction
                if (-not (Test-Path $script:TempPackage))
                {
                    throw "Downloaded package not found at $($script:TempPackage)"
                }
                $FileSize = (Get-Item $script:TempPackage).Length
                if ($FileSize -lt 1000)
                {
                    throw "Downloaded package too small ($FileSize bytes) - likely corrupted or error response"
                }
                # Verify ZIP header (PK signature = 0x504B)
                $ZipHeader = New-Object byte[] 2
                $stream = [System.IO.File]::OpenRead($script:TempPackage)
                $null = $stream.Read($ZipHeader, 0, 2)
                $stream.Close()
                if ($ZipHeader[0] -ne 0x50 -or $ZipHeader[1] -ne 0x4B)
                {
                    throw "Downloaded file is not a valid ZIP archive (invalid header)"
                }
                Expand-File $script:TempPackage $script:ThorDirectory
            }
            catch
            {
                Write-Log "Error while expanding the THOR ZIP package: $($_.Exception.Message)" -Level "Error"
                Set-ExecutionFailure -Reason "THOR package extraction failed." -Code 4 -KeepArtifacts
            }
        }
    }
    catch
    {
        Write-Log "Download or extraction of THOR failed. $($_.Exception.Message)" -Level "Error"
        Set-ExecutionFailure -Reason "THOR package download or extraction failed." -Code 4 -KeepArtifacts
    }
}

# ---------------------------------------------------------------------
# Run THOR ------------------------------------------------------------
# ---------------------------------------------------------------------
if (-not $script:ExecutionFailed)
{
    try
    {
        # Finding THOR binaries in extracted package
        Write-Log "Trying to find THOR binary in location $($script:ThorDirectory)" -Level "Progress"
        $ThorLocations = Get-ChildItem -Path $script:ThorDirectory -Recurse -Filter thor*.exe
        # Error - not a single THOR binary found
        if ($ThorLocations.count -lt 1)
        {
            Write-Log "THOR binaries not found in directory $($script:ThorDirectory)" -Level "Error"
            if ($CustomUrl)
            {
                Write-Log 'When using a custom ZIP package, make sure that the THOR binaries are in the root of the archive and not any sub-folder. (e.g. ./thor64.exe and ./signatures)' -Level "Warning"
            }
            else
            {
                Write-Log "This seems to be a bug. You could check the temporary THOR package yourself in location $($script:ThorDirectory)." -Level "Warning"
            }
            Set-ExecutionFailure -Reason "THOR binaries were not found in the downloaded package." -Code 5 -KeepArtifacts
        }

        if (-not $script:ExecutionFailed)
        {
            # Selecting the first location with THOR binaries
            $LiteAddon = ""
            $ThorBinDirectory = $null
            foreach ($ThorLoc in $ThorLocations)
            {
                # Skip THOR Util findings
                if ($ThorLoc.Name -like "*-util*")
                {
                    continue
                }
                # Save the directory name of the found THOR binary
                $ThorBinDirectory = $ThorLoc.DirectoryName
                # Is it a Lite version
                if ($ThorLoc.Name -like "*-lite*")
                {
                    Write-Log "THOR Lite detected"
                    $LiteAddon = "-lite"
                }
                Write-Log "Using THOR binaries in location $($ThorBinDirectory)."
                break
            }
            if ([string]::IsNullOrWhiteSpace($ThorBinDirectory))
            {
                Set-ExecutionFailure -Reason "THOR binary location could not be determined." -Code 5 -KeepArtifacts
                throw "THOR binary location could not be determined."
            }
            $ThorBinaryName = "thor$($ThorArch)$($LiteAddon).exe"
            $ThorBinary = Join-Path $ThorBinDirectory $ThorBinaryName

            # Use Preset Config (instead of external .yml file)
            $Config = ""
            if ($UsePresetConfig)
            {
                Write-Log 'Using preset config defined in script header due to $UsePresetConfig = $True'
                $TempConfig = Join-Path $ThorBinDirectory "config.yml"
                Write-Log "Writing temporary config to $($TempConfig)" -Level "Progress"
                Out-File -FilePath $TempConfig -InputObject $PresetConfig -Encoding ASCII
                $Config = $TempConfig
            }

            # Use Preset False Positive Filters
            if ($UseFalsePositiveFilters)
            {
                Write-Log 'Using preset false positive filters due to $UseFalsePositiveFilters = $True'
                $ThorConfigDir = Join-Path $ThorBinDirectory "config"
                $TempFPFilter = Join-Path $ThorConfigDir "false_positive_filters.cfg"
                Write-Log "Writing temporary false positive filter file to $($TempFPFilter)" -Level "Progress"
                Out-File -FilePath $TempFPFilter -InputObject $PresetFalsePositiveFilters -Encoding ASCII
            }

            # Scan parameters
            [string[]]$ScanParameters = @()
            if ($Config)
            {
                $ScanParameters += "-t"
                $ScanParameters += "$($Config)"
            }
            if ($NoResControl)
            {
                Write-Log "THOR resource safeguards are disabled due to -NoResControl (passes --norescontrol)." -Level "Warning"
                $ScanParameters += "--norescontrol"
            }
            if ($CpuLimit -gt 0)
            {
                Write-Log "THOR CPU limit enabled due to -CpuLimit $CpuLimit (passes --cpulimit $CpuLimit)." -Level "Progress"
                $ScanParameters += "--cpulimit"
                $ScanParameters += "$CpuLimit"
            }

            # Run THOR
            Write-Log "Starting THOR scan ..." -Level "Progress"
            $ThorRunStartTime = Get-Date
            $ScanParametersForLog = $ScanParameters | ForEach-Object {
                if ($_ -match '\s')
                {
                    '"{0}"' -f $_
                }
                else
                {
                    $_
                }
            }
            Write-Log "Command Line: $($ThorBinary) $($ScanParametersForLog -join ' ')"
            Write-Log "Working Directory: $($ThorBinDirectory)"
            Write-Log "Writing output files to $($OutputPath)"
            if (-not (Test-Path -Path $OutputPath))
            {
                Write-Log "Output path does not exists yet. Trying to create it ..." -Level "Progress"
                try
                {
                    New-Item -ItemType Directory -Force -Path $OutputPath
                    Write-Log "Output path $($OutputPath) successfully created."
                }
                catch
                {
                    Write-Log "Output path set by $OutputPath variable doesn't exist and couldn't be created. You'll have to rely on the SYSLOG export or command line output only." -Level "Error"
                }
            }
            if ($ScanParameters.Count -gt 0)
            {
                # With Arguments
                $p = Start-Process -FilePath $ThorBinary -ArgumentList $ScanParameters -WorkingDirectory $ThorBinDirectory -NoNewWindow -PassThru
            }
            else
            {
                # Without Arguments
                $p = Start-Process -FilePath $ThorBinary -WorkingDirectory $ThorBinDirectory -NoNewWindow -PassThru
            }
            # Cache handle, required to access ExitCode, see https://stackoverflow.com/questions/10262231/obtaining-exitcode-using-start-process-and-waitforexit-instead-of-wait
            $handle = $p.Handle
            # Wait using WaitForExit, which handles CTRL+C delayed
            $p.WaitForExit()

            # ERROR -----------------------------------------------------------
            if ($p.ExitCode -ne 0)
            {
                $ExitCodeHex = "0x{0:X8}" -f ([uint32]$p.ExitCode)
                Write-Log "THOR scan terminated with error code $($p.ExitCode) ($ExitCodeHex)" -Level "Error"

                $FailureAnalysis = Get-ThorRunFailureAnalysis -OutputPath $OutputPath -Hostname $Hostname -RunStartTime $ThorRunStartTime
                if ($FailureAnalysis.LogPath)
                {
                    Write-Log "Last THOR text log considered for diagnosis: $($FailureAnalysis.LogPath)" -Level "Warning"
                }
                switch ($FailureAnalysis.Type)
                {
                    "Crash"
                    {
                        Write-Log "Detected scanner runtime panic/crash pattern in THOR output. This likely indicates a scanner bug." -Level "Warning"
                        if ($FailureAnalysis.Evidence)
                        {
                            Write-Log "Crash indicator: $($FailureAnalysis.Evidence)" -Level "Warning"
                        }
                        Set-ExecutionFailure -Reason "THOR runtime panic/crash detected during scan." -Code $p.ExitCode -KeepArtifacts
                    }
                    "ResourceSafeguardMemory"
                    {
                        Write-Log "THOR stopped due to low available physical memory safeguard." -Level "Warning"
                        if ($FailureAnalysis.Evidence)
                        {
                            Write-Log "Memory safeguard indicator: $($FailureAnalysis.Evidence)" -Level "Warning"
                        }
                        Write-Log "If you accept the risk, rerun with -NoResControl to pass --norescontrol and disable this safeguard." -Level "Warning"
                        Add-SummaryGuidance -Message "Low-memory safeguard triggered. If you accept the risk, rerun with -NoResControl (passes --norescontrol). Warning: disabling safeguards can cause swapping and significant performance impact."
                        Set-ExecutionFailure -Reason "THOR stopped by low-memory safeguard to avoid memory outage." -Code $p.ExitCode -KeepArtifacts
                    }
                    "UnexpectedTermination"
                    {
                        Write-Log "THOR process ended without panic signature or normal completion marker." -Level "Warning"
                        Write-Log "This likely indicates external termination (e.g. AV/EDR intervention or manual stop)." -Level "Warning"
                        Add-SummaryGuidance -Message "Unexpected process termination detected. Check AV/EDR policy and configure exclusions for THOR binaries/working directories."
                        Add-SummaryGuidance -Message "Unexpected process termination can also be user-initiated. Ask users not to kill thor64.exe, or rerun with -CpuLimit 30 to 50 to reduce system load and fan noise."
                        Set-ExecutionFailure -Reason "THOR process was terminated unexpectedly during scan." -Code $p.ExitCode -KeepArtifacts
                    }
                    "NoLog"
                    {
                        Write-Log "No THOR text log was found for this run. The process may have been terminated very early." -Level "Warning"
                        Add-SummaryGuidance -Message "Process may have been terminated very early. Check AV/EDR policy and configure exclusions for THOR binaries/working directories."
                        Add-SummaryGuidance -Message "Also verify users did not stop thor64.exe. Consider -CpuLimit 30 to 50 to lower system impact."
                        Set-ExecutionFailure -Reason "THOR process ended unexpectedly before writing scan logs." -Code $p.ExitCode -KeepArtifacts
                    }
                    "LogReadError"
                    {
                        Write-Log "Unable to read THOR text log for failure analysis: $($FailureAnalysis.Evidence)" -Level "Warning"
                        Set-ExecutionFailure -Reason "THOR scan terminated with non-zero exit code ($($p.ExitCode))." -Code $p.ExitCode -KeepArtifacts
                    }
                    default
                    {
                        Set-ExecutionFailure -Reason "THOR scan terminated with non-zero exit code ($($p.ExitCode))." -Code $p.ExitCode -KeepArtifacts
                    }
                }
            }
            else
            {
                # SUCCESS -----------------------------------------------------
                Write-Log "Successfully finished THOR scan"
                # Output File Info
                $OutputFiles = @(Get-ChildItem -Path "$($OutputPath)\*" -Include "$($Hostname)_thor_$($DateStamp)*" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $ThorRunStartTime.AddSeconds(-10) })
                if ($OutputFiles.Length -gt 0)
                {
                    foreach ($OutFile in $OutputFiles)
                    {
                        Write-Log "Generated output file: $($OutFile.FullName)"
                    }
                }
                # Give help depending on the auto-detected platform
                if ($AutoDetectPlatform -eq "MDATP" -and $OutputFiles.Length -gt 0)
                {
                    Write-Log "Hint (ATP): You can use the following commands to retrieve the scan logs"
                    foreach ($OutFile in $OutputFiles)
                    {
                        Write-Log "  getfile `"$($OutFile.FullName)`""
                    }
                    #Write-Log "Hint (ATP): You can remove them from the end system by using"
                    #foreach ( $OutFile in $OutputFiles ) {
                    #    Write-Log "  remediate file `"$($OutFile.FullName)`""
                    #}
                }
            }
        }
    }
    catch
    {
        $ScanExceptionMessage = $_.Exception.Message
        Write-Log "Unknown error during THOR scan $ScanExceptionMessage" -Level "Error"
        if ($ScanExceptionMessage -match 'requires elevation')
        {
            Write-Log "THOR must be started from an elevated PowerShell console. Start PowerShell with 'Run as administrator' and rerun thor-seed." -Level "Warning"
        }
        Set-ExecutionFailure -Reason "THOR scan failed to start or complete." -Code 5 -KeepArtifacts
    }
}

# ---------------------------------------------------------------------
# Analysis Cockpit Upload ---------------------------------------------
# ---------------------------------------------------------------------
if (!([string]::IsNullOrEmpty($Cockpit)) -and !([string]::IsNullOrEmpty($CockpitKey))) {
    if ($script:ExecutionFailed) {
        Write-Log "Skipping Analysis Cockpit upload because scan execution failed." -Level "Warning"
    }
    else {
        try {
            # Finding THOR Logs
            Write-Log "Trying to find the THOR Log in location $($OutputPath)" -Level "Progress"
            $AllLogFiles = @(Get-ChildItem -Path $OutputPath -Filter "$($Hostname)_thor_*.txt" -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending)

            # Check if any THOR logs were found
            if ($AllLogFiles.Count -gt 0) {
                # Select the newest THOR log
                $NewestLogFile = $AllLogFiles[0].FullName
                Write-Log "Found log file: $NewestLogFile" -Level "Progress"

                $Boundary = [System.Guid]::NewGuid().ToString()
                $ContentType = "multipart/form-data; boundary=$Boundary"

                $Headers = @{
                    'accept' = 'application/json'
                    'Authorization' = $CockpitKey
                    'Content-Type' = $ContentType
                }

                # Construct the multipart form data body - cant be indented because formatting of powershell
                $Body = @"
--$Boundary
Content-Disposition: form-data; name="file[]"; filename="$(Split-Path $NewestLogFile -Leaf)"
Content-Type: text/plain

$(Get-Content -Raw $NewestLogFile)
--$Boundary--
"@

                $CockpitURI = "https://$($Cockpit)/api/scans/upload"

                # Ignore self-signed certificates
                if ($IgnoreSSLErrors) {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
                }

                $Response = Invoke-WebRequest -Method Post -Uri $CockpitURI -Headers $Headers -Body $Body -UseBasicParsing -ErrorAction Stop
                Write-Log "Upload successful to Analysis Cockpit" -Level "Progress"
                $script:CockpitUploadSucceeded = $True
            }
            else {
                Write-Log "THOR Log not found in directory $($script:ThorDirectory)" -Level "Error"
                Set-ExecutionFailure -Reason "Analysis Cockpit upload requested but no THOR log file was found." -Code 6
            }
        }
        catch [System.Net.WebException] {
            $StatusCode = $null
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode)
            {
                $StatusCode = [int]$_.Exception.Response.StatusCode
            }
            switch ($StatusCode) {
                400 { Write-Log "Invalid parameters - check API documentation" -Level "Error" }
                403 { Write-Log "Insufficient permissions - verify API key has 'Upload Events' permission" -Level "Error" }
                500 { Write-Log "Internal server error on Analysis Cockpit" -Level "Error" }
                default { Write-Log "HTTP error $StatusCode during upload to Analysis Cockpit" -Level "Error" }
            }
            Write-Log "Upload failed: $($_.Exception.Message)" -Level "Error"
            Set-ExecutionFailure -Reason "Upload to Analysis Cockpit failed." -Code 6
        }
        catch {
            Write-Log "Error during THOR Log upload to Analysis Cockpit ($Cockpit): $($_.Exception.Message)" -Level "Error"
            Set-ExecutionFailure -Reason "Upload to Analysis Cockpit failed." -Code 6
        }
    }
}

# ---------------------------------------------------------------------
# Cleanup -------------------------------------------------------------
# ---------------------------------------------------------------------
try
{
    # Restore original SSL certificate validation callback
    if ($IgnoreSSLErrors)
    {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = $OriginalCertCallback
    }

    if ($Debugging -eq $False -and -not $script:KeepTempArtifacts)
    {
        $HasTempPackage = -not [string]::IsNullOrWhiteSpace($script:TempPackage) -and (Test-Path -LiteralPath $script:TempPackage -ErrorAction SilentlyContinue)
        $HasThorDirectory = -not [string]::IsNullOrWhiteSpace($script:ThorDirectory) -and (Test-Path -LiteralPath $script:ThorDirectory -ErrorAction SilentlyContinue)
        if ($HasTempPackage -or $HasThorDirectory)
        {
            Write-Log "Cleaning up temporary directory with THOR package ..." -Level "Progress"
            if ($HasTempPackage)
            {
                # Delete THOR ZIP package
                Remove-Item -LiteralPath $script:TempPackage -Confirm:$False -Force -Recurse -ErrorAction Ignore
            }
            if ($HasThorDirectory)
            {
                # Delete THOR Folder
                Remove-Item -LiteralPath $script:ThorDirectory -Confirm:$False -Recurse -Force -ErrorAction Ignore
            }
        }
    }
    elseif ($script:KeepTempArtifacts)
    {
        Write-Log "Keeping temporary THOR package directory for troubleshooting: $($script:ThorDirectory)" -Level "Warning"
    }
}
catch
{
    Write-Log "Cleanup of temp directory $($script:ThorDirectory) failed. $($_.Exception.Message)" -Level "Error"
}

# ---------------------------------------------------------------------
# End -----------------------------------------------------------------
# ---------------------------------------------------------------------
$ElapsedTime = $(Get-Date) - $StartTime
$TotalTime = "{0:HH:mm:ss}" -f ([datetime]$ElapsedTime.Ticks)

# Scan Summary
Write-Log "==========================================================="
Write-Log "THOR Seed Execution Summary"
Write-Log "==========================================================="
Write-Log "Hostname: $Hostname"
Write-Log "Duration: $TotalTime"
Write-Log "Output Path: $OutputPath"
if ($script:ExecutionFailed)
{
    Write-Log "Result: FAILED" -Level "Error"
    Write-Log "Failure Reason: $($script:FailureReason)"
}
else
{
    Write-Log "Result: SUCCESS"
}
Write-Log "Exit Code: $($script:ExitCode)"
$FinalOutputFiles = Get-ChildItem -Path "$($OutputPath)\*" -Include "$($Hostname)_thor_*" -ErrorAction SilentlyContinue
if ($FinalOutputFiles.Count -gt 0)
{
    Write-Log "Generated Files: $($FinalOutputFiles.Count)"
}
if ($script:CockpitUploadSucceeded)
{
    Write-Log "Results uploaded to: $Cockpit"
}
if ($script:SummaryGuidance.Count -gt 0)
{
    foreach ($GuidanceLine in $script:SummaryGuidance)
    {
        Write-Log "Guidance: $GuidanceLine" -Level "Warning"
    }
}
Write-Log "==========================================================="
[Environment]::ExitCode = $script:ExitCode
$global:LASTEXITCODE = $script:ExitCode
exit $script:ExitCode
