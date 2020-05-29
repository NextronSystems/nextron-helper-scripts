# THOR Seed

A THOR and THOR Lite PowerShell Launcher

## What is THOR Seed

THOR Seed is a lightweight PowerShell script that facilitates the deployment of THOR in cases in which you can't or don't want to use an agent for a continous compromise assessment.

It retrieves a THOR package from a remote source, extracts it, runs it with certain settings and removes the temporary files afterwards.

You can decide if you want to send the logs to a remote log server, write them to a network share or write them to a local directory for later dispatching and collection.

The script itself writes an extensive log named `thor-seed.log`. You can deactivate the log with the `-NoLog` parameter or a preset in the respective script section.

## Screenshot

![THOR Seed Screenshot](https://raw.githubusercontent.com/NextronSystems/nextron-helper-scripts/master/images/thor_seed_old_os.png "THOR Seed running with PowerShell 3 on Windows 2008 R2")

## Requirements

- PowerShell version 3
- 70 MB of temporary disk space
- Network connection to a THOR source (ASGARD, THOR Cloud, THOR/THOR Lite as ZIP on a web server)

## THOR Sources

THOR Seed retrieves the THOR program package from different locations:

### From an on-premise ASGARD server

For details on ASGARD see [ASGARD's product page](https://www.nextron-systems.com/asgard-management-center/).

```console
thor-seed.ps1 -AsgardServer asgard1.internal
```

### From THOR Cloud

```console
thor-seed.ps1 -UseThorCloud -ApiKey 12345678
```

### From a custom THOR or THOR Lite package 

For details on how to create such a package, see [custom THOR package](#custom-thor-package).

```console
thor-seed.ps1 -CustomUrl https://web1.internal/thor/mythor-pack.zip
```

## Parameters

### -AsgardServer

Enter the server name or IP address of your ASGARD instance.

### -UseThorCloud

Use the official Nextron THOR Cloud instead of an ASGARD instance. 

### -Token

Download token used when connecting to Nextron's customer portal or an ASGARD instance.

### -CustomUrl

Allows you to define a custom URL from which the THOR package is retrieved. Make sure that the package contains the full program folder, provide it as ZIP archive and add valid licenses (Incident Response license, THOR Lite license). THOR Seed will automaticall find the THOR binaries in the extracted archive.

### -RandomDelay

A random delay in seconds before the scan starts. This is helpful when you start the script on thousands of end systems to avoid system (VM host) or network  (package retrieval) overload by distributing the load over a defined time range.

### -NoLog

Do not write a log file in the current working directory of the PowerShell script named thor-seed.log.

## Preconfigured Variables

Sometimes you may not be able to pass the command line parameters or want to ship a preconfigured version of the script that just has to be run. In that case you can use the respective section in the PowerShell script and the so-called "config templates" that can be passed to a THOR scan using the `-t` parameter.

THOR Seed contains such a template as an inline string that can be modified by you before the scan. THOR Seed will eventually write the config as file into the temporary directory and pass it as parameter to the extracted THOR binary.

The config files have a YAML format. It is easy to read and write. All command line options that you can see when you run `thor64.exe --help` can be used in these config templates, but you have to use their long form, e.g. instead of using `-p C:\Windows` you have to use `path: C:\Windows` or instead of `-c 50` you'll have to use `cpulimit: 50`.

```powershell
# Predefined YAML Config
$UsePresetConfig = $True
# Lines with '#' are commented and inactive. We decided to give you 
# some examples for your convenience. You can see all possible command 
# line parameters running `thor64.exe --help` or on this web page: 
# https://github.com/NextronSystems/nextron-helper-scripts/tree/master/thor-help 
# Only the long forms of the parameters are accepted in the YAML config. 

# PRESET CONFIGS

# SELECTIVE
# Preset template for a selective scan
# Run time: 1 to 3 minutes
# Specifics:
#   - runs a reduced quick scan
#   - skips Registry and Process memory checks
$PresetConfig_Selective = @"
# syslog: 10.0.0.1:514      # Syslog server to send the log data to
rebase-dir: $($OutputPath)  # Path to store all output files (default: script location)
module:
  - Autoruns
  - Rootkit
  - ShimCache
  - DNSCache 
# - RegistryChecks
  - ScheduledTasks
  - FileScan
  - ProcessCheck
  - Eventlog
nosoft: true       # Don't trottle the scan, even on single core systems
lookback: 1        # Log and Eventlog look back time in days
sigma: true        # Activate Sigma scanning on Eventlogs
quick: true        # Quick scan mode
nofserrors: true   # Don't print an error for non-existing directories selected in quick scan 
nocsv: true        # Don't create CSV output file with all suspicious files
noscanid: true     # Don't print a scan ID at the end of each line (only useful in SIEM import use cases)
nothordb: true     # Don't create a local SQLite database for differential analysis of multiple scans
"@
```

## THOR Lite

THOR Lite is a trimmed-down free version of our scanner THOR. Your can find more information and a download form [here](https://www.nextron-systems.com/thor-lite/). THOR Seed works with a THOR Lite package provided as ZIP archive on a web server. Make sure to add a valid THOR Lite license to that ZIP archive.

The cutoms THOR Lite package can be used as follows: 

```console
thor-seed.ps1 -CustomUrl https://web1.internal/thor/thor10lite-with-lic.zip
```

Note that settings in the `$PresetConfig` section in THOR Seed overwrite the settings provided in the `.\config\thor.yml` file located in the ZIP package. Make sure to configure everything in the respective section in THOR Seed.

![THOR Seed running THOR Lite](https://raw.githubusercontent.com/NextronSystems/nextron-helper-scripts/master/images/thor_seed_thor_lite.png "THOR Seed running THOR Lite")

## Custom THOR Package

In order to prepare a custom package you have to repack the THOR package that you've downloaded. Extract it, add a license file (`.lic`) and then create a ZIP archive from that program folder.

![THOR Seed Custom Package](https://raw.githubusercontent.com/NextronSystems/nextron-helper-scripts/master/images/thor_seed_custom_zip.png "Prepare a custom THOR package with license")

Make sure to check the description on [preconfigured variables](#preconfigured-variables) and the YAML config templates.

You can remove some folders to save disk space and reduce network load when running the script on thousands of systems. The required files and directories are the following. You can safely remove all other files and directories.

```console
.
├── config
│   ├── directory-excludes.cfg
│   ├── false_positive_filters.cfg
│   ├── thor.yml
├── custom-signatures
│   ...
├── signatures
│   ├── iocs
│   │   ├── custom-evil-hashes.dat
│   │   ├── filename-characteristics.dat
│   │   ├── keywords.dat
│   │   ├── malicious-events.dat
│   │   ├── malicious-mutexes.dat
│   │   ├── malware-domains.dat
│   │   └── trusted-md5s.dat
│   ├── misc
│   │   └── file-type-signatures.cfg
│   ├── sigma
│   │   ...
│   ├── sigrev
│   └── yara
│       ├── thor-all.yas
│       ├── thor-keywords.yas
│       ├── thor-log-sigs.yas
│       ├── thor-process-memory-sigs.yas
│       └── thor-registry.yas
├── thor.exe
├── thor.exe.sig
├── thor64.exe
├── thor64.exe.sig
└── tools
    ├── UnRAR.exe
    ├── UnRAR.exe.sig
    ├── upx.exe
    └── upx.exe.sig
```

Importan: The listing above does not include the license file, which is obviously also required.

## Microsoft Defender ATP

We use THOR Seed with [Microsoft Defender ATP](https://docs.microsoft.com/en-us/windows/security/threat-protection/microsoft-defender-atp/microsoft-defender-advanced-threat-protection) as described with a very early version in this [blog post](https://www.nextron-systems.com/2020/01/07/thor-integration-into-windows-defender-atp/).

### Issue with Live Response Session in Microsoft Defender ATP

There are some pitfalls that I'd like to highlight when running THOR in live response sessions. The first problem is the different command line. All parameters for THOR Seed have to be passed as string of a seperate parameter of the tool "run".

```console
run thor-seed.ps1 -parameters "-CustomUrl https://my.server.local/share/thor-pack.zip"
```

Another issue is the short timeout period for script runs within live response sessions. Until May 2020 it had been a timeout of 10 minutes. Since May 2020 the timeout has been increased to 30 minutes. Since full THOR scans take between 30 minutes and 4 hours, this timeout is still to small to run complete THOR scans. Microsoft plans to allow users set custom timeout values. Scripts executed via API have a 4 hour timeout.

To work around that problem, I recommend using a quick scan (`--quick`) or a global module lookback (`--global-lookback --lookback X`). This should help reducing the scan runtime below 30 minutes. A quick scan skips the Eventlog module and scans only a set of ~25 blacklisted folders of the target system. A global module lookback (available with version 10.5 of THOR) instructs THOR to scan only elements changed or created within the last X days. You can use these params in THOR Seed' config section.

```yml
quick: true
```

```yml
global-lookback: true
lookback: 2  # scan only elements created or changed within the last 2 days
```

## Helpful Hints

### Execution

If you get the following error message `cannot be loaded because the execution of scripts is disabled on this system` you may run the script as follows:

```console
powershell.exe -ExecutionPolicy Bypass .\thor-seed.ps1 -CustomUrl https://my-webserver.internal/thor/thor-packed.zip
```

### Quick Web Server Setup

To provide a THOR package for a quick PoC you could use Python's `http.server` module.

```console
workstation:/temp/thor user$ ls
thorlite.zip
workstation:/temp/thor user$ python3 -m http.server
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
192.168.1.20 - - [31/Mar/2020 17:46:32] "GET /thorlite.zip HTTP/1.1" 200 -
```
