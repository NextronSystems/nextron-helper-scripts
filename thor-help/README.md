# THOR Scan Parameters

THOR APT Scanner Scan Parameters

## Flags for Scan Options

```
      --alldrives                   (Windows Only) Scan all local drives, including network drives and ROM drives (default: only the system drive)
      --allhds                      (Windows Only) Scan all local hard drives (default: only the system drive)
      --asgard string               Get a license from this asgard.
      --ca strings                  Path to root ca to verify host certificate
      --cross-platform              Duplicates IOCs with os-specific separators to match paths cross-platform.
  -f, --epoch strings               Days with attacker activity. Files created on these days will receive an extra score. (Format: yyyy-mm-dd). e.g. -f 2009-10-09 -f 2009-10-10
      --epochscore int              Score to add on files that were created/modified/accessed on days with attacker activity (combined with '-f' parameter) (default 35)
  -n, --eventlog-target strings     Scan an Eventlog (e.g. 'Security' or 'Microsoft-Windows-Sysmon/Operational')
      --insecure                    Skip TLS host verification (insecure)
  -q, --license-path string         Location of license (default is application directory)
      --lookback int                time to look back into the eventlog / log files in days
      --max_file_size int           max. file size to check. Warning: Increasing this limit will also increase memory usage of THOR. (default 4500000)
      --max_file_size_intense int   max. file size to check (in intense mode) (default 16500000)
      --max_log_lines int           maximum amount of log lines in LogScan to check before skipping remaining lines of a log file (default 1000000)
      --max_runtime int             Maximum runtime in hours. THOR kills himself, if the maximum runtime has exceeded. Use 0 for no maximum runtime. (default 72)
      --nodoublecheck               Don't perform a check if another THOR instance is running (e.g. in Lab use cases in which several mounted images are scanned on a single system)
      --noimphash                   Do not calculate imp hash for EXE files
  -p, --path strings                Scan Path (define multiple targets by -p target1 -p target2) (use ':NOWALK' suffix for non-recursive scanning or a path)
      --process ints                Processes to be scanned (multiple with --process <id1> --process <id2> ...)
  -t, --template string             Template configuration (yaml) for scan parameters
      --version                     Show version only
```

## Flags for Scan Modes

```
      --diff      The fastest scan mode that skips all elements that were present during the last scan run (Currently applies to modules: Filesystem, Registry, Eventlog)
      --fsonly    Scan only the file system (often used with '-p scanpath')
      --intense   WARNING: This scan mode performs tasks that affect systems stability. Do not use this mode in live scanning unless you accept the risk. Intense scanning mode is automatically activated in lab scanning mode (--fsonly).
      --quick     Quick mode skips Eventlog module and selects only APT relevant directories for file system scan
      --soft      Soft Scan Mode - skips CPU and RAM intensive modules (i.e. process memory check, archive check); Use this mode on systems with minimum hardware resources
```

## Flags for Resource Options

```
  -c, --cpulimit float        Pause if system CPU reaches this value, in percent (default 95)
      --lowprio               Reduce the priority of the THOR process to a lower level
      --minmem uint           The minimum amount of free physical memory to proceed (in MB) (default 50)
      --nocpulimit            Disable cpulimit check
      --nolockthread          Do not lock calls to c libraries to main thread (this may increase performance at the cost of memory usage)
      --nolowprio             Do not reduce the priority of the THOR process to a lower level on single core systems
      --norescontrol          Don't perform a resource check during file system scan. Use this option to avoid bottlenecks and system stability problems
      --nosoft                If the total memory of the system is lower than 512 MB, then soft mode will be activated automatically, if --nosoft is not set
      --verylowprio           Reduce the pirority of the THOR process to a very low level
      --yara-stack-size int   Allocate a stack size of “slots” number of slots. Default: 16384. This will allow you to use larger rules, albeit with more memory overhead (default 16384)
      --yara-timeout int      Timeout for yara checks in seconds (default 60)
```

## Flags for Special Scan Modes

```
      --dropdelete                 Delete all files dropped to the dropzone after the scan
      --dropzone                   Watch and scan all files dropped to a certain directory (-p directory)
  -m, --image_file string          Single (Memory) Image / Dump File Scan
  -r, --restore_directory string   Restore files found during the surface scan to a specific folder
      --restore_score int          Restore only files with a match score higher than X (default 50)
      --showdeleted                Show deleted files on file system (will be 'info' messages)
```

## Flags for Active Modules

```
      --mft                 Analyze the drive's MFT
  -a, --module strings      Activate the following modules only (Specify multiple modules with -a Module1 -a Module2 ... -a ModuleN). Valid modules are: Autoruns, DeepDive, Dropzone, EnvCheck, Filescan, Firewall, Hosts, LoggedIn, OpenFiles, ProcessCheck, UserDir, ServiceCheck, Users, AtJobs, DNSCache, Eventlog, Events, HotfixCheck, LSASessions, MFT, Mutex, NetworkSessions, NetworkShares, RegistryChecks, Rootkit, SHIMCache, ScheduledTasks, WMIStartup
      --noatjobs            Do not analyze at jobs
      --noautoruns          Do not analyse autorun elements
      --nodnscache          Do not analyze local DNS cache
      --noenv               Do not analyze the environment variables
      --noeventlog          Do not analyse Eventlog
      --noevents            Do not check for malicious events
      --nofilesystem        Do not scan the file system
      --nofirewall          Do not analyze the local Firewall
      --nohosts             Do not analyze hosts file
      --nohotfixes          Do not analyze Hotfixes
      --nologons            Do not show currently logged in users
      --nolsasessions       Do not analyze lsa sessions
      --nomft               Do not analyze the drive's MFT in intense mode
      --nomutex             Do not check for malicious mutexes
      --nonetworksessions   Do not analyze network sessions
      --nonetworkshares     Do not analyze network shares
      --noopenfiles         Do not analyse Open Files (Network)
      --noprocs             Do not analyze Processes
      --noprofiles          Do not analyze Profile directories
      --noreg               Do not analyze Registry
      --norootkits          Do not check for rootkits
      --noservices          Do not analyze services
      --noshimcache         Do not analyze Shim Cache entries
      --notasks             Do not analyse Scheduled Tasks
      --nousers             Do not analyze User Accounts
      --nowmi               Disables all checks with WMI functions
      --nowmistartup        Do not analyze startup elements using WMI
```

## Flags for Active Features

```
      --customonly             Only use custom signatures
      --dumpscan               Scan memory dump files
      --full-registry          Do not skip registry hives keys with less relevance. This flag will be automatically set in intense mode.
      --noamcache              Do not analyze Amcache file
      --noarchive              Disable archive checks
      --noc2                   Disable C2 Domain checks
      --nodoublepulsar         Do not check for DoublePulsar Backdoor
      --noevtx                 Do not analyze EVTX files
      --noexedecompress        Do not decompress and scan portable executables
      --nogroupsxml            Do not analyze groups.xml
      --noknowledgedb          Do not check Knowledge DB on Mac OS
      --nologscan              Do not scan log files (.log)
      --noprefetch             Do not analyze prefetch directory
      --noprocconnections      Do not analyze Process connections
      --noprochandles          Do not analyze Process handles
      --noregistryhive         Do not analyze Registry Hive files
      --noregwalk              Do not walk through the registry during registry scan
      --nostix                 Disable STIX checks
      --nothordb               Do not use or create ThorDB database
      --novulnerabilitycheck   Do not analyze vulnerabilities
      --nowebdirscan           Do not analyze web directories that were found in Process handles
      --nower                  Do not analyze .wer files
      --nowmipersistence       Do not check WMI Persistence
      --noyara                 Disable YARA checks
      --sigma                  Scan with Sigma signatures
```

## Flags for Output Options

```
      --allreasons                  Show all reasons and not only the top 2
      --ascii                       Remove non-ASCII characters
      --brd                         Suppress all PI in log outputs to comply with German data protection policies
      --cmdjson                     Use json for commandline output
      --cmdkeyval                   Use key-values for commandline output
  -o, --csvfile string              MD5 List CSV of all relevant files (default ":hostname:_files_md5s.csv")
      --csvstats                    Generates a CSV file containing the system's statistics in a single line
      --encrypt                     Encrypt the logfile and csvfile
      --eventlog                    Log to windows application eventlog
      --genid                       Print an unique ID that is generated over the fields: MESSAGE, DESC, DESCRIPTION, KEYWORD, REASON_1, PATTERN
      --htmlfile string             Log file for html output (not in combination with --nolog) (default ":hostname:_thor_2020-04-24.html")
      --json                        Write json report file
      --jsonfile string             Log file for json output (default ":hostname:_thor_2020-04-24.json")
      --keyval                      Format output (logfile) with key value pairs to simplify the field extraction in SIEM systems (key='value')
      --local-syslog                Print THOR events to local syslog
  -l, --logfile string              Log file (default ":hostname:_thor_2020-04-24.txt")
  -x, --min int                     Minimum score to report (default 40)
      --mute-sigma-rule int         Mute following sigma rule matches for rules that matched more than X times. Use X = 0 to disable sigma rule muting. (default 10)
      --nocolor                     Do not use ansi escape sequences for colorized output
      --nocsv                       Do not write a CSV of all mentioned files with MD5 hash
      --nohtml                      Do not write html report file
      --nolog                       Do not generate log file
      --noscanid                    Do not automatically set a scan identifier
  -j, --overwrite-hostname string   Override the local hostname value with a static value (useful when scanning mounted images in the Lab (default "HYPERION")
      --print-rescontrol            Write rescontrol measurements to stdout
      --printamcache                Include all AmCache entries in the output as 'info' level messages
      --printlicenses               Print all licenses to command line, otherwise only 10 licenses will be printed
      --printshim                   Include all SHIM cache entries in the output as 'info' level messages
      --pubkey string               Use a RSA public key to encrypt the logfile and csvfile. (--pubkey="<key>" or --pubkey="<file>")
  -e, --rebase-dir string           Rebase the output directory (all output files will be written to this directory)
      --reduced                     Reduced output mode - only warnings, alerts and errors will be printed
      --registry_depth_print int    Maximum depth where THOR will print info messages (default 1)
      --rfc3339                     Print timestamps in RFC3339 (YYYY-MM-DD'T'HH:mm:ss'Z') format
  -i, --scanid string               Define a unique scan identifier (useful to filter on the scan ID) (default "S-Z3zbiVeA9oQ")
      --silent                      Do not print anything to command line
      --stats-file string           Set the name of the CSV stats file (default ":hostname:_stats.csv")
      --truncate int                Max. length per THOR value (0 = no truncate) (default 2048)
      --utc                         Print timestamps in UTC instead of local time zone
```

## Flags for ThorDB

```
      --dbfile string   Location of the thor.db file (default "%ProgramData%\\thor\\thor10.db")
      --resume          Resume
      --resumeonly      Resume only
```

## Flags for Syslog

```
      --cef_level int         Define the minimum severity level to log as CEF (Debug=1, Info=3, Notice=4, Error=5, Warning=8, Alarm=10) (default 4)
      --maxsysloglength int   Maximum length of SYSLOG messages (rest will be truncated, 0 equals no truncation) (default 2048)
      --rfc                   Use strict syslog according to RFC 3164 (simple host name, shortened message)
      --rfc3162               Truncate long Syslog messages to 1024 bytes
      --rfc5424               Truncate long Syslog messages to 2048 bytes
  -s, --syslog strings        Syslog server, target port, syslog type(DEFAULT/CEF/JSON/SYSLOGJSON/SYSLOGKV), socket type (UDP/TCP/TCPTLS); examples: -s syslog1.dom.net, -s arcsight.dom.net:514:CEF:UDP, -s syslog2:4514:DEFAULT:TCP, -s syslog3:514:JSON:TCPTLS
```

## Flags for Reporting and Actions

```
      --action_args strings     Arguments to pass to action command. Possible placeholders are %filename%, %filepath%, %file%, %ext%, %md5%, %score% and %date%.
      --action_command string   Run this command for all suspicious files
      --action_level int        Defines what score is needed to trigger the action (default 40)
      --alert int               Score on which a alert is generated (default 100)
      --notice int              Score on which a notice is generated (default 40)
      --warning int             Score on which a warning is generated (default 60)
```

## Flags for THOR Remote

```
      --remote strings           Target host (use multiple --remote <host> statements for a set of hosts)
      --remote-debug             Debug Mode for THOR Remote
      --remote-dir string        Upload THOR to this remote directory (default "C:\\WINDOWS\\TEMP\\thor10-remote")
      --remote-password string   Password to be used to authenticate against host
      --remote-prompt            Prompt for password
      --remote-rate int          Number of seconds to wait between scan starts (default 30)
      --remote-user string       Username (alternatively use windows integrated authentication)
      --remote-workers int       Number of concurrent scans (default 25)
```

## Flags for Automatic Collection of Suspicious Files (Bifrost)

```
      --bifrost2GRPC             Use gRPC protocol instead of https protocol (ASGARD 2 only)
      --bifrost2Ignore strings   Files that match this pattern are not collected with Bifrost 2. '*' matches any sequence of non-seperator characters, '?' matches any single non-seperator character.
      --bifrost2Key string       Bifrost 2 apikey
      --bifrost2Level int        Minimum score to send file to the Bifrost 2 server (default 60)
      --bifrost2Prompt           Prompt for Bifrost 2 apikey
      --bifrost2Server string    Bifrost 2 server IP
      --bifrostLevel int         Minimum score to send file to the Bifrost server (default 60)
      --bifrostPort int          Bifrost server port (default 1400)
  -b, --bifrostServer string     Bifrost server IP
```

## Flags for Debugging

```
      --debug      Debugging Output
      --printall   Print all files that are checked (noisy)
      --trace      Tracing Output
```