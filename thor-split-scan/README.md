# THOR Split Scan

`thor-split-scan.py` scans a large directory, for example a mounted file share with many terabytes, with THOR 10 as many smaller scans. It starts one scan per folder at a level you choose and runs several of them at a time. Every file is scanned exactly once. If the run stops, run the same command again: finished scans are skipped and interrupted ones start over.

```bash
python3 thor-split-scan.py --thor /opt/thor --output /data/split-scan --level 2 --parallel 4 /mnt/share
```

## Requirements

- **THOR 10** with a **Forensic Lab license**. The scans use `--lab`, and only a Forensic Lab license allows several THOR scans on one system and the scanning of network shares. THOR 11 has other command-line flags and is refused.
- **Python 3.6 or newer.** The script uses only the standard library: copy the one file next to your THOR folder or anywhere else.

Tested with THOR 10.7.26 on Linux (Python 3.6) and THOR 10.7.30 on macOS (Python 3.8 and 3.14). It is written to run on Windows as well (`thor64.exe`, Ctrl+Break), but it has not been tested there yet.

## How the directory is split

Take this share:

```
/mnt/share
├── readme.txt
├── IT
│   ├── SRV1/...
│   └── SRV2/...
├── Sales
│   ├── budget.csv
│   ├── WKS1/...
│   └── WKS2/...
└── Scans
    └── scan1.txt
```

With `--level 2` the script starts these scans:

| Scan | THOR scans | Covers |
| --- | --- | --- |
| `. (files directly in it)` | `-p /mnt/share:NOWALK` | `readme.txt` |
| `IT/SRV1` | `-p /mnt/share/IT/SRV1` | everything in `SRV1` |
| `IT/SRV2` | `-p /mnt/share/IT/SRV2` | everything in `SRV2` |
| `Sales (files directly in it)` | `-p /mnt/share/Sales:NOWALK` | `budget.csv` |
| `Sales/WKS1` | `-p /mnt/share/Sales/WKS1` | everything in `WKS1` |
| `Sales/WKS2` | `-p /mnt/share/Sales/WKS2` | everything in `WKS2` |
| `Scans` | `-p /mnt/share/Scans` | `scan1.txt`: a folder without subfolders is scanned as a whole |

The rules are:

- Each folder at the chosen level gets a scan of that folder and its subfolders.
- Each folder above that level that holds files of its own gets a scan of only those files. This uses THOR's `:NOWALK`.
- A folder above that level that has no subfolders gets one scan of the whole folder. An empty folder gets no scan.

Each scan runs THOR like this:

```
thor-linux-64 --lab --alldrives --threads T -p <folder> -e <output>/scans/<name> \
  -l thor.txt --htmlfile thor.html --stats-file=stats.csv --silent [--jsonfile=thor.json] [-j <hostname>] [your flags]
```

`--alldrives` is there because THOR 10 on Linux skips NFS and SMB mounts without it. Together with `-p`, it scans only the given folder; this was checked on Linux and macOS.

## Quick start

1. See how the directory would be split, without scanning anything. Add `--output DIR` to get the full list as `DIR/dry-run.csv`:

   ```bash
   python3 thor-split-scan.py --dry-run --level 2 /mnt/share
   ```

2. Start the run. Run it in `tmux` or `screen` when it will take days:

   ```bash
   python3 thor-split-scan.py --thor /opt/thor --output /data/split-scan --level 2 --parallel 4 /mnt/share
   ```

3. See how far it is, from another terminal. This also writes `summary.csv`:

   ```bash
   python3 thor-split-scan.py --status --output /data/split-scan
   ```

4. If the run was stopped, continue it with the same command. The directory can be left out, since the output folder remembers it:

   ```bash
   python3 thor-split-scan.py --thor /opt/thor --output /data/split-scan --parallel 4
   ```

More THOR flags go after `--`:

```bash
python3 thor-split-scan.py --thor /opt/thor --output /data/split-scan --level 2 /mnt/share -- --max_file_size 50MB
```

## Choosing the level, the parallel scans and the threads

- **Start-up cost.** Each THOR scan spends roughly 10 to 20 seconds loading its signatures before it scans anything. Take a share of 1,000 folders with 1,000 folders each, split at level 2: that is a million scans and about 170 days of start-up alone. `--dry-run` shows the number of scans and the start-up time. Pick a level at which a typical scan runs for an hour or more.
- **Interrupted scans.** `--lab` turns off THOR's resume database, so an interrupted scan starts over from the beginning. Smaller scans lose less work and share the load between the parallel scans more evenly.
- **Parallel scans and threads.** By default each scan gets as many threads as there are CPU cores, divided by `--parallel`. Every thread needs memory. On a network share, the share's throughput is often the limit, not the CPU, so measure before raising `--parallel`.

## Options

| Option | Meaning |
| --- | --- |
| `FOLDER` | The directory to scan. Can be left out when continuing a run. |
| `--thor PATH` | The THOR folder, or the THOR binary in it. |
| `-o`, `--output DIR` | The folder for this run. It must not be inside the scanned directory. |
| `--level N` | The level to split at: 1 = the folders in the directory, 2 = the folders in those, and so on. Default 1. |
| `--parallel P` | How many scans run at a time. Default 1. |
| `--threads T` | THOR threads per scan. Default: CPU cores divided by `--parallel`. |
| `--exclude PATTERN` | Leave out folders whose name or path below the directory matches the pattern (`*`, `?`, `[abc]`), for example `--exclude .snapshot --exclude '~snapshot'`. Can be given more than once. It applies only to folders down to `--level`. Below that level THOR walks the folders itself, and THOR's own excludes (`config/directory-excludes.cfg`) apply. |
| `--json` | Also write THOR's JSON log (`thor.json`) for each scan. Add `-- --jsonv2` for the v2 format. |
| `--hostname-level N` | Use the name of the folder at level N as THOR's hostname (`-j`). For example, use 1 when the directory holds one folder per system. Scans of folders above that level keep the real hostname. |
| `--retry-failed` | Scan the folders whose scan failed again. |
| `--relist` | When continuing a run, list the folders again to pick up new ones. Without it, the list made at the start of the run is used. |
| `--stop-after-failures N` | Stop when N scans in a row fail, for example because the share is gone. Default 10; 0 never stops. |
| `--dry-run` | List the scans and exit. |
| `--status` | Show how far the run in `--output` is, also while it runs, and write its `summary.csv`. |

## Output

```
/data/split-scan
├── summary.csv            one row per scan
├── thor-split-scan.log    everything the script printed, with times
├── run.json               the directory, the level and the excludes of this run
├── worklist.jsonl         the list of scans, made at the start of the run
├── state.jsonl            progress: one line per started and per finished scan
└── scans
    ├── IT__SRV1           thor.txt, thor.html, stats.csv, console.txt (THOR's console output), thor.json
    ├── Sales__files       the scan of the files directly in Sales
    ├── root__files        the scan of the files directly in the directory
    └── ...
```

`summary.csv` has these columns:

- `folder` and `scope`
- `status`: done, failed, interrupted, running or not started
- `reason`: why a scan failed
- `started`, `finished` and `seconds`
- `exit_code`
- `alerts`, `warnings`, `notices` and `errors`, from THOR's stats file
- `output`: the scan's folder

The counts include THOR's start-up messages. For example, "Signature file is older than 60 days" is a warning in every scan.

## Stopping and continuing

- **Ctrl+C once:** no new scans start, and the running ones finish. That can take a long time.
- **Ctrl+C twice:** the running scans are ended. They are marked as interrupted and start over on the next run.
- **Ctrl+C a third time:** the running scans are killed without waiting.
- **Running again:** the same command continues the run.
  - Finished scans are skipped.
  - Interrupted scans start over. The output of the interrupted attempt is kept as `<name>.interrupted-1`.
  - Failed scans are left alone until you add `--retry-failed`. The old output is then kept as `<name>.failed-1`.
- **Closing the terminal (Linux, macOS):** the run goes on, and its messages continue in `thor-split-scan.log`.
- **Killing the script:** on Linux, the running THOR scans end with it.
- **When the script stops by itself:**
  - THOR does not accept its license or its command line, so every other scan would fail the same way.
  - `--stop-after-failures` scans fail in a row.
  - A folder that has disappeared since the list was made, for example because the share is no longer mounted, counts as a failure.

Exit codes:
- 0: every scan finished.
- 1: scans failed, or a problem stopped the run.
- 2: bad arguments.
- 3: stopped with Ctrl+C before every scan ran.

## Good to know

- **Folder names with `$`.** THOR replaces `$NAME` and `${NAME}` in `-p` paths with environment variables, so a folder named `$RECYCLE.BIN` would become `.BIN` and nothing would be scanned. The script prevents that by giving THOR `RECYCLE=$RECYCLE`. When such a name is a real environment variable, for example a folder named `$HOME`, the scan is marked as failed, and the reason says so. Scan that folder by hand.
- **Hidden folders** are scanned like any other. Exclude them with `--exclude`.
- **Symbolic links to folders** are not followed, and THOR does not follow them either.
- **Updates.** Update THOR and its signatures before a run, not during it.
- **Leftover THOR processes.** If the script is killed on Windows or macOS while scans run, those THOR processes keep running. Let them finish, or end them, before you continue the run.
- **Tests.** Run `python3 -m unittest -v test_thor_split_scan.py` in this folder. They use a stand-in for THOR and need Linux or macOS.
