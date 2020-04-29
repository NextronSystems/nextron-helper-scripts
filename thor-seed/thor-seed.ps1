##################################################
# Script Title: THOR Download and Execute Script
# Script File Name: thor-seed.ps1  
# Author: Florian Roth 
# Version: 0.11.0
# Date Created: 29.04.2020  
################################################## 
 
#Requires -Version 3

<#   
    .SYNOPSIS   
        The "thor-seed" script downloads THOR and executes it
    .DESCRIPTION 
        The "thor-seed" script downloads THOR from an ASGARD instance, the Netxron cloud or a custom URL and executes THOR on the local system writing log files or transmitting syslog messages to a remote system
    .PARAMETER AsgardServer 
        Enter the server name or IP address of your ASGARD instance. 
    .PARAMETER UseThorCloud 
        Use the official Nextron cloud systems instead of an ASGARD instance. 
    .PARAMETER Token 
        Download token used when connecting to Nextron's cloud service instead of an ASGARD instance.
    .PARAMETER CustomUrl 
        Allows you to define a custom URL from which the THOR package is retrieved. Make sure that the package contains the full program folder, provide it as ZIP archive and add valid licenses (Incident Response license, THOR Lite license). THOR Seed will automaticall find the THOR binaries in the extracted archive. 
    .PARAMETER SyslogServer 
        Enter the server or IP address of your remote SYSLOG server to send the results to. 
    .PARAMETER OutputPath 
        A switching parameter that does not accept any value, but rather is used to tell the function to open the path location where the file was downloaded to.
    .PARAMETER RandomDelay
        A random delay in seconds before the scan starts. This is helpful when you start the script on thousands of end systems to avoid system (VM host) or network  (package retrieval) overload by distributing the load over a defined time range.
    .PARAMETER QuickScan 
        Perform a quick scan only. This reduces scan time by 80%, skipping "Eventlog" scan and checking the most relevant locations in "Filesystem" scan only. 
    .PARAMETER NoLog 
        Do not write a log file in the current working directory of the PowerShell script named thor-seed.log. 
    .EXAMPLE
        Download THOR from asgard1.intranet.local (download token isn't required in on-premise installations)
        
        thor-seed -AsgardServer asgard1.intranet.local
    .EXAMPLE
        Download THOR from asgard1.cloud.net using an download token and send the log to a remote SYSLOG system
        
        thor-seed -AsgardServer asgard1.intranet.local -Token wWfC0A0kMziG7GRJ5XEcGdZKw3BrigavxAdw9C9yxJX -SyslogServer siem-collector1.intranet.local
    .EXAMPLE
        Download THOR from asgard1.cloud.net using an download token and run a scan with a given config file
        
        thor-seed -AsgardServer asgard1.intranet.local -Token wWfC0A0kMziG7GRJ5XEcGdZKw3BrigavxAdw9C9yxJX -Config config.yml
    .EXAMPLE
        Download THOR from asgard1.intranet.local and save all output files to a writable network share
        
        thor-seed -AsgardServer asgard1.intranet.local -OutputPath \\server\share
    .EXAMPLE
        Download THOR or THOR Lite package from a custom URL and execute it. (this also works with THOR Lite)
         
        thor-seed -CustomUrl https://web1.server.local/thor/mythor-pack.zip
    .NOTES
        You can set a static download token and ASGARD server in this file (see below in the parameters)

        You can use YAML config files to pass parameters to the scan. Only the long form of the parameter is accepted. The contents of a config.yml could look like: 
        ```
        module:
            - Rootkit
            - Mutex
            - ShimCache
            - Eventlog
        nofast: true
        nocolor: true
        lookback: 3
        syslog:
            - siem1.local
        ```
        There is also a section in this script in which you can predefine a config. See the predefined variables  after the params section.
#>

# #####################################################################
# Parameters ----------------------------------------------------------
# #####################################################################

param  
( 
    [Parameter( 
        HelpMessage='The ASGARD instance to download THOR from (license will be generated on that instance)')] 
        [ValidateNotNullOrEmpty()] 
        [Alias('AMC')]
        [string]$AsgardServer,  

    [Parameter(HelpMessage="Use Nextron's cloud instead of an ASGARD instance to download THOR and generate a license")] 
        [ValidateNotNullOrEmpty()] 
        [Alias('CP')]    
        [switch]$UseThorCloud,

    [Parameter(HelpMessage="Set a download token (used with ASGARDs and THOR Cloud)")] 
        [ValidateNotNullOrEmpty()] 
        [Alias('T')]
        [string]$Token,
 
    [Parameter( 
        HelpMessage='Allows you to define a custom URL from which the THOR package is retrieved.')] 
        [ValidateNotNullOrEmpty()] 
        [Alias('CU')]       
        [string]$CustomUrl, 

    [Parameter(HelpMessage="Config YAML file to be used in the scan")] 
        [ValidateNotNullOrEmpty()] 
        [Alias('C')]    
        [string]$Config, 

    [Parameter(HelpMessage="Remote SYSLOG system that should receive THOR's log as SYSLOG messages")] 
        [ValidateNotNullOrEmpty()] 
        [Alias('SS')]    
        [string]$SyslogServer, 
 
    [Parameter(HelpMessage='Output path to write all output files to (can be a local directory or UNC path to a file share on a server)')] 
        [ValidateNotNullOrEmpty()] 
        [Alias('OP')]    
        [string]$OutputPath = $PSScriptRoot,

    [Parameter(HelpMessage='Add a random sleep delay to the scan start to avoid all scripts starting at the exact same second')] 
        [ValidateNotNullOrEmpty()] 
        [Alias('RD')]    
        [int]$RandomDelay = 20, 

    [Parameter(HelpMessage='Activates quick scan')] 
        [ValidateNotNullOrEmpty()] 
        [Alias('Q')]    
        [switch]$QuickScan,

    [Parameter(HelpMessage='Deactivates log file for this PowerShell script (thor-run.log)')] 
        [ValidateNotNullOrEmpty()] 
        [Alias('NL')]    
        [switch]$NoLog
)

# #####################################################################
# Presets -------------------------------------------------------------
# #####################################################################

# Write local log file for THOR Seed script activity
#[bool]$NoLog = $True

# ASGARD Server
#[string]$AsgardServer = "asgard.beta.nextron-systems.com"

# Use THOR Cloudselects only APT relevant directories for file system scan
#[bool]$UseThorCloud = $True

# Download Token
#[string]$Token = "YOUR DOWNLOAD TOKEN"

# Random Delay (added before the scan start to distribute the inital load)
#[int]$RandomDelay = 20

# Custom URL with THOR package
#[string]$CustomUrl = "https://internal-webserver1.intranet.local"

# Predefined YAML Config
$UsePresetConfig = $True
# Lines with '#' are commented and inactive. We decided to give you 
# some examples for your convenience. You can see all possible command 
# line parameters running `thor64.exe --help` or on this web page: 
# https://github.com/NextronSystems/nextron-helper-scripts/tree/master/thor-help 
# Only the long forms of the parameters are accepted in the YAML config. 
$PresetConfig = @"
module:
# - Autoruns
  - Rootkit
  - ShimCache
  - DNSCache 
# - RegistryChecks
  - ScheduledTasks
  - FileScan
# - ProcessCheck
# - Eventlog
nosoft: true       # Don't trottle the scan, even on single core systems
# nocolor: true    # Don't colorize the output
lookback: 3        # Log and Eventlog look back time in days
cpulimit: 70       # Limit the CPU usage of the scan
sigma: true        # Activate Sigma scanning on Eventlogs
quick: true        # Quick scan mode
# reduced: true    # Only show WARNING and ALERT level messages
nofserrors: true   # Don't print an error for non-existing directories selected in quick scan 
nocsv: true        # Don't create CSV output file with all suspicious files
noscanid: true     # Don't print a scan ID at the end of each line (only useful in SIEM import use cases)
nothordb: true     # Don't create a local SQLite database for differential analysis of multiple scans
# dumpscan: true   # Scan memory dump files found during Filescan
# printshim: true  # Output all SHIMCache entries
# nolog: true      # Don't write any file outputs (only makes sense when using SYSLOG)
# rebase-dir: \\server\share  # redirect all file outputs to this location
# path:
#     - C:\Temp
#     - C:\Users\Public
"@

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

# Show Help -----------------------------------------------------------
# No ASGARD server 
if ( $Args.Count -eq 0 -and $AsgardServer -eq "" -and $UseThorCloud -eq $False -and $CustomUrl -eq "" ) {
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    Write-Host -ForegroundColor Yellow 'Note: You must at least define an ASGARD server (-AsgardServer), use the Nextron cloud (-UseThorCloud) with an download token (-Token) or provide a custom URL to a THOR / THOR Lite ZIP package on a webserver (-CustomUrl)'
    return
}
# THOR Cloud but no download token
if ( $UseThorCloud -eq $True -and $Token -eq "" ) {
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    Write-Host -ForegroundColor Yellow 'Note: You must provide an download token via command line parameter -Token or as preset value in the "presets" section of this PowerShell script.'
    return
}

# #####################################################################
# Functions -----------------------------------------------------------
# #####################################################################

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

# Required for ZIP extraction in PowerShell version <5.0
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Expand-File {
    param([string]$ZipFile, [string]$OutPath)
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $OutPath)
}

function Write-Log {
    param (
        [Parameter(Mandatory=$True, Position=0, HelpMessage="Log entry")]
            [ValidateNotNullOrEmpty()] 
            [String]$Entry,

        [Parameter(Position=1, HelpMessage="Log file to write into")] 
            [ValidateNotNullOrEmpty()] 
            [Alias('SS')]    
            [IO.FileInfo]$LogFile = "thor-seed.log",

        [Parameter(Position=3, HelpMessage="Level")]
            [ValidateNotNullOrEmpty()] 
            [String]$Level = "Info"
    )
    
    # Indicator 
    $Indicator = "[+]"
    if ( $Level -eq "Warning" ) {
        $Indicator = "[!]"
    } elseif ( $Level -eq "Error" ) {
        $Indicator = "[E]"
    } elseif ( $Level -eq "Progress" ) {
        $Indicator = "[.]"
    } elseif ($Level -eq "Note" ) {
        $Indicator = "[i]"
    }

    # Output Pipe
    if ( $Level -eq "Warning" ) {
        Write-Warning -Message "$($Indicator) $($Entry)"
    } elseif ( $Level -eq "Error" ) {
        Write-Host "$($Indicator) $($Entry)" -ForegroundColor Red
    } else {
        Write-Host "$($Indicator) $($Entry)"
    }
    
    # Log File
    if ( $global:NoLog -eq $False ) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $($env:COMPUTERNAME): $Entry" | Out-File -FilePath $LogFile -Append
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
Write-Host "                                                           "
Write-Host "==========================================================="

# Measure time
$StartTime = $(get-date)

Write-Log "Started thor-seed with PowerShell v$($PSVersionTable.PSVersion)"

# ---------------------------------------------------------------------
# Evaluation ----------------------------------------------------------
# ---------------------------------------------------------------------
# Hostname
$Hostname = $env:COMPUTERNAME
# Evaluate Architecture 
$ThorArch = "64"
if ( [System.Environment]::Is64BitOperatingSystem -eq $False ) {
    $ThorArch = ""
}
# License Type
$LicenseType = "server"
$OsInfo = Get-CimInstance -ClassName Win32_OperatingSystem
if ( $osInfo.ProductType -eq 1 ) { 
    $LicenseType = "client"
}

# Fixing Certain Platform Environments --------------------------------
$AutoDetectPlatform = ""
# Microsoft Defender ATP - Live Response
# $PSScriptRoot is empty
if ( $OutputPath -eq "" ) {
    # Setting output path to easily accessible system root, e.g. C:
    $OutputPath = "$($env:ProgramData)\thor"
    $AutoDetectPlatform = "MDATP"
}

# Output Info on Auto-Detection 
if ( $AutoDetectPlatform -ne "" ) {
    Write-Log "Auto Detect Platform: $($AutoDetectPlatform)"
    Write-Log "Note: Some automatic changes have been applied"
}

# ---------------------------------------------------------------------
# Get THOR ------------------------------------------------------------
# ---------------------------------------------------------------------
try {
    # Random Delay
    $LocalDelay = Get-Random -Minimum 0 -Maximum $RandomDelay
    Write-Log "Adding random delay to the scan start (max. $($RandomDelay)): sleeping for $($LocalDelay) seconds" -Level "Progress"
    Start-Sleep -Seconds $LocalDelay

    # Presets
    # Temporary directory for the THOR package
    $ThorDirectory = New-TemporaryDirectory
    $TempPackage = Join-Path $ThorDirectory "thor-package.zip"

    # Generate Download URL
    # Web Client 
    try {
        # Web Client
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $WebClient = New-Object System.Net.WebClient 
        if ( $Token ) { 
            $WebClient.Headers.add('Authorization',$Token)
        }
        # Proxy Support
        $WebClient.Proxy = [System.Net.WebRequest]::DefaultWebProxy
        $WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

        # Download Source
        # Asgard Instance
        if ( $AsgardServer -ne "" ) {
            Write-Log "Attempting to download THOR from $AsgardServer" -Level "Progress"
            # Generate download URL 
            $DownloadUrl = "https://$($AsgardServer):8443/api/v0/downloads/thor/thor10-win?hostname=$($Hostname)&type=$($LicenseType)&iocs=%5B%22default%22%5D"
        }
        # Netxron Customer Portal
        elseif ( $UseThorCloud ) {
            Write-Log 'Attempting to download THOR from Nextron cloud portal, please wait ...' -Level "Progress"
            $DownloadUrl = "https://cloud.nextron-systems.com/api/public/thor10"
            # Parameters
            $WebClient.Headers.add('X-OS', 'windows')
            if ( $ThorArch -eq "64" ) {
                $WebClient.Headers.add('X-Arch', 'amd64')
            } else {
                $WebClient.Headers.add('X-Arch', 'x86')
            }
            $WebClient.Headers.add('X-Token', $Token)
            $WebClient.Headers.add('X-Hostname', $Hostname)
        } 
        # Custom URL 
        elseif ( $CustomUrl -ne "" ) {
            $DownloadUrl = $CustomUrl
        } else {
            Write-Log 'Download URL cannot be generated (select one of the three options: $AsgardServer, $UseThorCloud or $CustomUrl'
            break
        }
        # Actual Download
        Write-Log "Download URL: $($DownloadUrl)"
        $WebClient.DownloadFile($DownloadUrl, $TempPackage)
        Write-Log "Successfully downloaded THOR package to $($TempPackage)"
    }
    # HTTP Errors
    catch [System.Net.WebException] {
        Write-Log "The following error occurred: $_" -Level "Error"
        $Response = $_.Exception.Response
        # 401 Unauthorized
        if ( [int]$Response.StatusCode -eq 401 -or [int]$Response.StatusCode -eq 403 ) { 
            Write-Log "The server returned an 40X status code. Did you set an download token? (-Token key)" -Level "Warning"
            if ( $UseThorCloud ) { 
                Write-Log "Note: you can find your download token here: https://portal.nextron-systems.com/"
            } else {
                Write-Log "Note: you can find your download token here: https://$($AsgardServer):8443/ui/user-settings#tab-Token"
            }
        }
        if ( [int]$Response.StatusCode -eq 409 -and $UseThorCloud ) { 
            Write-Log "You license pool has been exhausted (quota limit)" -Level "Warning"
        }
        if ( [int]$Response.StatusCode -ge 500 ) { 
            Write-Log "THOR cloud internal error. Please report this error or try again later." -Level "Warning"
        }
        break
    }
    catch { 
        Write-Log "The following error occurred: $_" -Level "Error"
        break 
    } 

    # Unzip
    try {
        Write-Log "Extracting THOR package" -Level "Progress"
        Expand-File $TempPackage $ThorDirectory
    } catch {
        Write-Log "Error while expanding the THOR ZIP package $_" -Level "Error"  
        break
    }
} catch {
    Write-Log "Download or extraction of THOR failed. $_" -Level "Error"
    break
}

# ---------------------------------------------------------------------
# Run THOR ------------------------------------------------------------
# ---------------------------------------------------------------------
try {
    # Finding THOR binaries in extracted package
    Write-Log "Trying to find THOR binary in location $($ThorDirectory)" -Level "Progress"
    $ThorLocations = Get-ChildItem -Path $ThorDirectory -Recurse -Filter thor*.exe 
    # Error - not a single THOR binary found
    if ( $ThorLocations.count -lt 1 ) { 
        Write-Log "THOR binaries not found in directory $($ThorDirectory)" -Level "Error"
        if ( $CustomUrl ) {
            Write-Log 'When using a custom ZIP package, make sure that the THOR binaries are in the root of the archive and not any sub-folder. (e.g. ./thor64.exe and ./signatures)' -Level "Warning"
            break
        } else {
            Write-Log "This seems to be a bug. You could check the temporary THOR package yourself in location $($ThorDirectory)." -Level "Warning"
            break
        }
    }
    
    # Selecting the first location with THOR binaries
    $LiteAddon = ""
    foreach ( $ThorLoc in $ThorLocations ) {
        # Skip THOR Util findings
        if ( $ThorLoc.Name -like "*-util*" ) {
            continue
        }
        # Save the directory name of the found THOR binary
        $ThorBinDirectory = $ThorLoc.DirectoryName
        # Is it a Lite version
         if ( $ThorLoc.Name -like "*-lite*" ) { 
             Write-Log "THOR Lite detected"
             $LiteAddon = "-lite"
         }
        Write-Log "Using THOR binaries in location $($ThorBinDirectory)."
        break
    }
    $ThorBinaryName = "thor$($ThorArch)$($LiteAddon).exe"
    $ThorBinary = Join-Path $ThorBinDirectory $ThorBinaryName
        
    # Use Preset Config (instead of external .yml file)
    if ( $UsePresetConfig -and $Config -eq "" ) {
        Write-Log 'Using preset config defined in script header due to $UsePresetConfig = $True'
        $TempConfig = Join-Path $ThorDirectory "config.yml"
        Write-Log "Writing temporary config to $($TempConfig)" -Level "Progress"
        Out-File -FilePath $TempConfig -InputObject $PresetConfig -Encoding ASCII
        $Config = $TempConfig
    }

    # Use Preset False Positive Filters
    if ( $UseFalsePositiveFilters ) {
        Write-Log 'Using preset false positive filters due to $UseFalsePositiveFilters = $True'
        $ThorConfigDir = Join-Path $ThorDirectory "config"
        $TempFPFilter = Join-Path $ThorConfigDir "false_positive_filters.cfg"
        Write-Log "Writing temporary false positive filter file to $($TempFPFilter)" -Level "Progress"
        Out-File -FilePath $TempFPFilter -InputObject $PresetFalsePositiveFilters -Encoding ASCII      
    }

    # Scan parameters 
    [string[]]$ScanParameters = @()
    if ( $QuickScan ) {
        $ScanParameters += "--quick"
    }
    if ( $SyslogServer ) {
        $ScanParameters += "-s $($SyslogServer)"
    }
    if ( $OutputPath ) { 
        $ScanParameters += "-e $($OutputPath)"
    }
    if ( $Config ) {
        $ScanParameters += "-t $($Config)"
    }

    # Run THOR
    Write-Log "Starting THOR scan ..." -Level "Progress"
    Write-Log "Command Line: $($ThorBinary) $($ScanParameters)"
    Write-Log "Writing output files to $($OutputPath)"
    if (-not (Test-Path -Path $OutputPath) ) { 
        Write-Log "Output path does not exists yet. Trying to create it ..." -Level "Progress"
        try {
            New-Item -ItemType Directory -Force -Path $OutputPath 
            Write-Log "Output path $($OutputPath) successfully created."
        } catch {
            Write-Log "Output path set by $OutputPath variable doesn't exist and couldn't be created. You'll have to rely on the SYSLOG export or command line output only." -Level "Error"
        }
    }
    # With Arguments
    if ( $ScanParameters.Count -gt 0 ) {
        $p = Start-Process $ThorBinary -ArgumentList $ScanParameters -wait -NoNewWindow -PassThru
    } 
    # Without Arguments
    else { 
        $p = Start-Process $ThorBinary -wait -NoNewWindow -PassThru
    }

    # ERROR -----------------------------------------------------------
    if ( $p.ExitCode -ne 0 ) {
        Write-Log "THOR scan terminated with error code $($p.ExitCode)" -Level "Error" 
    } else {
        # SUCCESS -----------------------------------------------------
        Write-Log "Successfully finished THOR scan"
        # Output File Info
        $OutputFiles = Get-ChildItem -Path "$($OutputPath)\*" -Include *_thor_*
        if ( $OutputFiles.Length -gt 0 ) {
            foreach ( $OutFile in $OutputFiles ) {
                Write-Log "Generated output file: $($OutFile.FullName)"
            }
        }
        # Give help depending on the auto-detected platform 
        if ( $AutoDetectPlatform -eq "MDATP" -and $OutputFiles.Length -gt 0 ) {
            Write-Log "Hint (ATP): You can use the following commands to retrieve the scan logs"
            foreach ( $OutFile in $OutputFiles ) {
                Write-Log "  getfile $($OutFile.FullName) -auto"
            }
            Write-Log "Hint (ATP): You can remove them from the end system by using"
            foreach ( $OutFile in $OutputFiles ) {
                Write-Log "  remediate file $($OutFile.FullName) -auto"
            } 
        }
    }
} catch { 
    Write-Log "Unknown error during THOR scan $_" -Level "Error"   
}

# ---------------------------------------------------------------------
# Cleanup -------------------------------------------------------------
# ---------------------------------------------------------------------
try {
    Write-Log "Cleaning up temporary directory with THOR package ..." -Level Process
    # Delete THOR ZIP package
    Remove-Item -Confirm:$False -Force -Recurse $TempPackage -ErrorAction Ignore
    # Delete THOR Folder
    Remove-Item -Confirm:$False -Recurse -Force $ThorDirectory -ErrorAction Ignore
} catch {
    Write-Log "Cleanup of temp directory $($ThorDirectory) failed. $_" -Level "Error"
}

# ---------------------------------------------------------------------
# End -----------------------------------------------------------------
# ---------------------------------------------------------------------
$ElapsedTime = $(get-date) - $StartTime
$TotalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
Write-Log "Scan took $($TotalTime) to complete" -Level "Information"
