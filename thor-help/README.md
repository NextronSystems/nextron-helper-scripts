# THOR Command Line Flags

This help reflects the scan parameters of THOR 10.6 TechPreview.

## Scan Options

```help
      --alldrives                   (Windows Only) Scan all local drives, including network drives and ROM drives (default: only the system drive)
      --allhds                      (Windows Only) Scan all local hard drives (default: only the system drive)
      --ca strings                  Root CA for host certificate verification during TLS handshakes
      --cross-platform              Apply IOCs with path separators platform independently.
  -f, --epoch strings               Specify days with attacker activity. Files created/modified on these days will receive an extra score. Example: -f 2009-10-09 -f 2009-10-10
      --epochscore int              Score to add for files that were created/modified on days with attacker activity (see --epoch parameter) (default 35)
      --generate-config             Print a YAML config from the given parameters and exit
      --insecure                    Skip TLS host verification (insecure)
      --max_file_size int           Max. file size to check (larger files are ignored). Increasing this limit will also increase memory usage of THOR. (default 12000000)
      --max_file_size_intense int   Max. file size to check in intense mode. See --intense and --max_file_size. (default 30000000)
      --max_log_lines int           Maximum amount of lines to check in a log file before skipping the remaining lines (default 1000000)
      --max_runtime int             Maximum runtime in hours. THOR will stop once this time has run out. 0 means no maximum runtime. (default 72)
      --nodoublecheck               Don't check whether another THOR instance is running (e.g. in Lab use cases when several mounted images are scanned simultaneously on a single system)
  -p, --path strings                Scan a specific file path. Define multiple paths by specifying this option multiple times. Append ':NOWALK' to the path for non-recursive scanning (default: only the system drive)
  -t, --template string             Process default scan parameters from this YAML file
```

## Scan Modes

```help
      --diff                       Set lookback time (see --lookback) for each module to the last time the module ran successfully and activates --all-module-lookback.
                                   Effectively, this means that only elements that changed since the last scan are examined. (only works if ThorDB has been active)
      --force-aptdir-lookback      Enforce lookback application on all files in the FileScan module. By default, especially endangered directories ignore the lookback value.
      --global-lookback            Apply Lookback to all modules that support it (not only Eventlog). See also --lookback and --lookback-modules.
                                   Warning: Timestomping or similar methods of antivirus evasion may result in elements not being examined.
      --intense                    Disable soft mode, activate dump file analysis, MFT analysis and sigma rules, and don't skip registry keys with less relevance.
                                   WARNING: This scan mode performs tasks that affect systems stability. Do not use this mode in live scanning unless you accept the risk.
      --lab                        Lab scan mode - scan only the file system, disable resource checks and quick mode, activate intense mode, disable ThorDB, apply IOCs platform independently and use all CPU cores.
                                   This option scans all drives by default, but is often used with -p to scan only a single path.
      --lookback int               Specify how many past days shall be analyzed. Event log entries from before this point will be ignored. 0 means no limit (default 0).
      --lookback-modules strings   Apply Lookback to the given modules. See also --lookback and --modules.
                                   Warning: Timestomping or similar methods of antivirus evasion may result in elements not being examined.
      --quick                      Activate a number of flags to speed up the scan at cost of some detection.
                                   This is equivalent to: --noeventlog --nofirewall --noprofiles --nowebdirscan --nologscan --noevtx --nohotfixes --nomft --lookback 3 --lookback-modules filescan
      --soft                       Skip CPU and RAM intensive modules (Mutexes, Firewall, Logons, Network sessions and shares, LSA sessions, open files, hosts file), don't decompress executables and doesn't perform a DoublePulsar backdoor check, lower max CPU usage to 70% and set low priority for THOR.
                                   This mode activates automatically on systems with 1 CPU core or less than 1024 MB RAM.
      --virtual-map strings        Rewrite found file paths to use a different prefix.
                                   This can be useful for mounted images, where the current location of files does not match the original location and therefore references might be out of date.
                                   Specify the original and current path as --virtual-map path/to/current/location:path/to/original/location.
                                   On Windows, drive names are also supported, e.g. specify --virtual-map F:C if the drive on F: was originally used as C:.
```

## Resource Options

```help
  -c, --cpulimit float                  Limit CPU usage to this level (in percent). Minimum is 15% (default 95)
      --lowprio                         Reduce the priority of the THOR process to a lower level
      --minmem uint                     Cancel the running scan if the amount of free physical memory drops below this value (in MB) (default 50)
      --nocpulimit                      Disable cpulimit check
      --nolockthread                    Do not lock calls to C libraries to main thread (this may increase performance at the cost of memory usage)
      --nolowprio                       Do not reduce the priority of the THOR process to a lower level due to soft mode (see --soft)
      --norescontrol                    Do not check whether the system is running out of resources. Use this option to enforce scans that have been canceled due to resource scarcity. (use with care!)
      --nosoft                          Disable automatic activation of soft mode (see --soft)
      --threads uint16                  Run this amount of THOR threads in parallel
      --verylowprio                     Reduce the pirority of the THOR process to a very low level
      --yara-max-strings-per-rule int   Allow this amount of strings per YARA rule. Increasing this limit will allow more IOCs to be present. (default 1073741824)
      --yara-stack-size int             Allocate this number of slots for the YARA stack. Default: 16384. Increasing this limit will allow you to use larger rules, albeit with more memory overhead. (default 16384)
      --yara-timeout int                Cancel any YARA checks that take longer this amount of time (in seconds) (default 60)
```

## Special Scan Modes

```help
      --image-chunk-size uint      Scan image / dump files in chunks of this size (default 12000000)
  -m, --image_file string          Scan only the given single memory image / dump file (don't use for disk images, scan them mounted with --lab)
  -r, --restore_directory string   Restore PE files with YARA rule matches during the DeepDive into the given folder
      --restore_score int          Restore only chunks with a total match score higher than the given value (default 50)
```

## Dropzone Mode

```help
      --dropdelete    Delete all files dropped to the drop zone after the scan.
      --dropzone      Watch and scan all files dropped to a certain directory (which must be passed with -p). Disable resource checks and quick mode, activate intense mode, disable ThorDB and apply IOCs platform independently.
      --showdeleted   Show deleted files found in the MFT as 'info' messages.
```

## Thor Thunderstorm Service

```help
      --pure-yara                         Only scan files using YARA signatures (disables all programmatic checks, STIX, Sigma, IOCs, as well as most features and modules)
      --server-cert string                TLS certificate that THOR's server should use. If left empty, TLS is not used.
      --server-host string                IP address that THOR's server should bind to. (default "127.0.0.1")
      --server-key string                 Private key for the TLS certificate that THOR's server should use. Required if --server-cert is specified.
      --server-port uint16                TCP port that THOR's server should bind to. (default 8080)
      --server-result-cache-size uint32   Size of the cache that is used to store results of asynchronous requests temporarily.
                                          If set to 0, the cache is disabled and asynchronous results are not stored. (default 250000)
      --server-store-samples string       Sets whether samples should be stored permanently in the folder specified with --server-upload-dir.
                                          Specify "all" to store all samples, or "malicious" to store only samples that generated a warning or an alert. (default "none")
      --server-upload-dir string          Path to a directory where THOR drops uploaded files.
                                          If this path does not exist, THOR tries to create it. (default "/var/folders/wf/74mtjd112gdbybts4zwt0d0m0000gn/T/thor-uploads")
      --sync-only-threads uint16          Reserve this amount of THOR threads for synchronous requests
      --thunderstorm                      Watch and scan all files sent to a specific port (see --server-port). Disable resource checks and quick mode, activate intense mode, disable ThorDB and apply IOCs platform independently.
```

## License Retrieval

```help
      --asgard string           Request a license from the given asgard server
      --asgard-token string     Use this token to authenticate with the License API of the asgard server. The token can be found in the 'Downloads' or 'Licensing' section in the ASGARD. This requires ASGARD 2.5+.
  -q, --license-path string     Path containing the THOR license (default is application directory)
      --portal-contracts ints   Use these contracts for license generation. If no contract is specified, the portal selects a contract by itself. See --portal-key.
      --portal-key string       Get a license for this host from portal.nextron-systems.com using this API Key.
                                This feature is only supported for host-based server / workstation contracts.
      --portal-nonewlic         Only use an existing license from the portal. If none exists, exit. See --portal-key.
```

## Active Modules

```help
      --mft                 Analyze the drive's MFT
  -a, --module strings      Activate the following modules only (Specify multiple modules with -a Module1 -a Module2 ... -a ModuleN).
                            Valid modules are: Thunderstorm, Filescan, Timestomp, ServiceCheck, Autoruns, DeepDive, Dropzone, EnvCheck, Firewall, Hosts, LoggedIn, OpenFiles, ProcessCheck, UserDir, Users, KnowledgeDB
      --noatjobs            Do not analyze jobs scheduled with the 'at' tool
      --noautoruns          Do not analyse autorun elements
      --nodnscache          Do not analyze the local DNS cache
      --noenv               Do not analyze environment variables
      --noeventlog          Do not analyse the eventlog
      --noevents            Do not check for malicious events
      --nofilesystem        Do not scan the file system
      --nofirewall          Do not analyze the local Firewall
      --nohosts             Do not analyze the hosts file
      --nohotfixes          Do not analyze Hotfixes
      --nointegritycheck    Do not check with the package manager for package integrity on Linux
      --nologons            Do not show currently logged in users
      --nolsasessions       Do not analyze lsa sessions
      --nomft               Do not analyze the drive's MFT (default, unless in intense mode)
      --nomutex             Do not check for malicious mutexes
      --nonetworksessions   Do not analyze network sessions
      --nonetworkshares     Do not analyze network shares
      --noopenfiles         Do not analyse opened files
      --nopipes             Do not analyze named pipes
      --noprocs             Do not analyze Processes
      --noprofiles          Do not analyze profile directories
      --noreg               Do not analyze the registry
      --norootkits          Do not check for rootkits
      --noservices          Do not analyze services
      --noshimcache         Do not analyze SHIM Cache entries
      --notasks             Do not analyse scheduled tasks
      --nousers             Do not analyze user accounts
      --nowmi               Disable all checks with WMI functions
      --nowmistartup        Do not analyze startup elements using WMI
```

## Module Extras

```help
      --dump-procs                Generate process dumps for suspicious or malicious processes (Module: ProcessCheck)
  -n, --eventlog-target strings   Scan specific Eventlogs (e.g. 'Security' or 'Microsoft-Windows-Sysmon/Operational') (Module: Eventlog)
      --full-registry             Do not skip registry hives keys with less relevance (Module: Registry)
      --max-procdumps uint        Create at most this many process dumps (Module: ProcessCheck) (default 10)
      --nodoublepulsar            Do not check for DoublePulsar Backdoor (Module: Rootkit)
      --procdump-dir string       Store process dumps of suspicious processes in this directory (Module: ProcessCheck) (default "/var/lib/thor")
      --process ints              Process IDs to be scanned. Define multiple processes by specifying this option multiple times (default: all processes) (Module: ProcessCheck)
```

## Active Features

```help
      --dumpscan               Scan memory dumps
      --noamcache              Do not analyze Amcache files
      --noarchive              Do not scan contents of archives
      --noc2                   Disable checks for known C2 Domains
      --noevtx                 Do not analyze EVTX files
      --noexedecompress        Do not decompress and scan portable executables
      --nogroupsxml            Do not analyze groups.xml
      --noimphash              Do not calculate imphash for suspicious EXE files (Windows only)
      --noknowledgedb          Do not check Knowledge DB on Mac OS
      --nolnk                  Do not analyze LNK files
      --nologscan              Do not scan log files (identified by .log extension or location)
      --noprefetch             Do not analyze prefetch directory
      --noprocconnections      Do not analyze process connections
      --noprochandles          Do not analyze process handles
      --noregistryhive         Do not analyze Registry Hive files
      --noregwalk              Do not scan the whole registry during the registry scan
      --nostix                 Disable checks with STIX
      --nothordb               Do not use or create ThorDB database for holding scan information
      --novulnerabilitycheck   Do not analyze system for vulnerabilities
      --nowebdirscan           Do not analyze web directories that were found in process handles
      --nower                  Do not analyze .wer files
      --nowmipersistence       Do not check WMI Persistence
      --noyara                 Disable checks with YARA
      --sigma                  Scan with Sigma signatures
      --timestomp              Activate timestomping detection (experimental, may take some time)
```

## Feature Extras

```help
      --customonly            Use custom signatures only (disables all internal THOR signatures and detections)
      --full-proc-integrity   Increase sensitivity for process impersonation detection. Likely to cause false positives, but also better at detecting real threats.
      --processintegrity      Run PE-Sieve to check for process integrity (Windows only)
```

## Output Options

```help
      --allreasons                  Show all reasons why a match is considered dangerous (default: only the top 2 reasons are displayed)
      --appendlog                   Append text log to existing log instead of overwriting
      --ascii                       Don't print non-ASCII characters to command line and log files
      --brd                         Suppress all personal information in log outputs to comply with local data protection policies
      --cmdjson                     Format command line output as JSON
      --cmdkeyval                   Use key-value pairs for command line output, see --keyval
  -o, --csvfile string              Generate a CSV containing MD5,Filepath,Score for all files with at least the minimum score (default ":hostname:_files_md5s.csv")
      --csvstats                    Generate a CSV file containing the scan summary in a single line
      --encrypt                     Encrypt the generated log files and the MD5 csv file
      --eventlog                    Log to windows application eventlog
      --genid                       Print a unique ID for each log message. Identical log messages will have the same ID.
      --htmlfile string             Log file for HTML output (default ":hostname:_thor_:time:.html")
      --json                        Create a json report file
      --jsonfile string             Log file for JSON output, see --json (default ":hostname:_thor_:time:.json")
      --keyval                      Format text and HTML log files with key value pairs to simplify the field extraction in SIEM systems (key='value')
      --local-syslog                Print THOR events to local syslog
  -l, --logfile string              Log file for text output (default ":hostname:_thor_:time:.txt")
  -x, --min int                     Only report files with at least this score (default 40)
      --mute-sigma-rule int         Don't print sigma rule matches if that sigma rule already matched more than X times. 0 means that sigma rules will never be muted. (default 10)
      --nocolor                     Do not use ANSI escape sequences for colorized command line output
      --nocsv                       Do not write a CSV of all mentioned files with MD5 hash (see --csvstats)
      --nohtml                      Do not create an HTML report file
      --nolog                       Do not generate text or HTML log files
      --noscanid                    Do not automatically generate a scan identifier if none is specified
  -j, --overwrite-hostname string   Override the local hostname value with a static value (useful when scanning mounted images in the lab (default "prometheus.local")
      --print-rescontrol            Print THOR's resource threshold and usage when it is checked
      --printamcache                Include all AmCache entries in the output as 'info' level messages
      --printlicenses               Print all licenses to command line (default: only 10 licenses will be printed)
      --printshim                   Include all SHIM cache entries in the output as 'info' level messages
      --pubkey string               Use this RSA public key to encrypt the logfile and csvfile (see --encrypt). Both --pubkey="<key>" and --pubkey="<file>" are supported.
  -e, --rebase-dir string           Specify the output directory where all output files will be written. Defaults to the current working directory.
      --reduced                     Reduced output mode - only warnings, alerts and errors will be printed
      --registry_depth_print int    Don't print info messages when traversing registry keys at a higher depth than this (default 1)
      --rfc3339                     Print timestamps in RFC3339 (YYYY-MM-DD'T'HH:mm:ss'Z') format
  -i, --scanid string               Specify a scan identifier (useful to filter on the scan ID, should be unique)
      --scanid-prefix string        Specify a prefix for the scan ID that is concatenated with a random ID if neither --scanid nor --noscanid are specified (default "S-")
      --silent                      Do not print anything to command line
      --stats-file string           Set the name of the CSV stats file, see --csvstats (default ":hostname:_stats.csv")
      --string-context uint         When printing strings from YARA matches on files, include this many bytes surrounding the match (default 0)
      --truncate int                Max. length per THOR value (0 = no truncate) (default 2048)
      --utc                         Print timestamps in UTC instead of local time zone
```

## ThorDB

```help
      --dbfile string   Location of the thor.db file (default "/var/lib/thor/thor10.db")
      --resume          Store information while running that allows to resume an interrupted scan later. If a previous scan was interrupted, resume it instead of starting a new one.
      --resumeonly      Don't start a new scan, only finish an interrupted one. If no interrupted scan exists, nothing is done.
```

## Syslog

```help
      --cef_level int         Define the minimum severity level to log to CEF syslogs (Debug=1, Info=3, Notice=4, Error=5, Warning=8, Alarm=10) (default 4)
      --maxsysloglength int   Truncate Syslog messages to the given length (0 means no truncation) (default 2048)
      --rfc                   Use strict syslog according to RFC 3164 (simple host name, shortened message)
      --rfc3162               Truncate long Syslog messages to 1024 bytes
      --rfc5424               Truncate long Syslog messages to 2048 bytes
  -s, --syslog strings        Write output to the specified syslog server, format: server[:port[:syslogtype[:sockettype]]].
                              Supported syslog types: DEFAULT/CEF/JSON/SYSLOGJSON/SYSLOGKV
                              Supported socket types: UDP/TCP/TCPTLS
                              Examples: -s syslog1.dom.net, -s arcsight.dom.net:514:CEF:UDP, -s syslog2:4514:DEFAULT:TCP, -s syslog3:514:JSON:TCPTLS
```

## Reporting and Actions

```help
      --action_args strings     Arguments to pass to the command specified via --action_command.
                                The placeholders %filename%, %filepath%, %file%, %ext%, %md5%, %score% and %date% are replaced at execution time.
      --action_command string   Run this command for each file that has a score greater than the score from --action_level.
      --action_level int        Only run the command from --action_command for files with at least this score. (default 40)
      --alert int               Minimum score on which an alert is generated (default 100)
      --nofserrors              Silently ignore filesystem errors
      --notice int              Minimum score on which a notice is generated (default 40)
      --warning int             Minimum score on which a warning is generated (default 60)
```

## THOR Remote

```help
      --remote strings           Target host (use multiple --remote <host> statements for a set of hosts)
      --remote-debug             Debug Mode for THOR Remote
      --remote-dir string        Upload THOR to this remote directory
      --remote-password string   Password to be used to authenticate against remote hosts
      --remote-prompt            Prompt for password for remote hosts
      --remote-rate int          Number of seconds to wait between scan starts (default 30)
      --remote-user string       Username (if not specified, windows integrated authentication is used)
      --remote-workers int       Number of concurrent scans (default 25)
```

## Automatic Collection of Suspicious Files (Bifrost)

```help
      --bifrost2Score int       Send all files with at least this score to the Bifrost 2 quarantine service.
                                This flag is only usable when invoking THOR from ASGARD 2. (default 60)
      --bifrost2Server string   Server running the Bifrost 2 quarantine service. THOR will upload all suspicious files to this server.
                                This flag is only usable when invoking THOR from ASGARD 2.
      --bifrostPort int         Port where the Bifrost quarantine service is running (default 1400)
      --bifrostScore int        Minimum score to send file to the Bifrost quarantine service (default 60)
  -b, --bifrostServer string    Server running the Bifrost quarantine service. THOR will upload all suspicious files to this server.
```

## Debugging and Info

```help
      --debug              Show Debugging Output
  -h, --help               Show help and exit
      --print-signatures   Show THOR Signatures and exit
      --printall           Print all files that are checked (noisy)
      --trace              Show Tracing Output
      --version            Show THOR, signature and software versions and exit
```
