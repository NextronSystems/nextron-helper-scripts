#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
thor-split-scan.py - scan a large directory with THOR 10 as many smaller scans

Splits a directory (for example a mounted file share) at a chosen folder level
and runs one THOR scan per part, several at a time:

  * every folder at the chosen level gets a scan of the folder and its
    subfolders,
  * every folder above that level that holds files of its own gets a scan of
    only those files (THOR's ":NOWALK"),
  * a folder above that level without subfolders gets one scan.

So every file is scanned exactly once. Run the same command again to continue
after a stop or a crash: finished scans are skipped, interrupted ones start
over.

Needs Python 3.6 or newer (standard library only) and THOR 10 with a Forensic
Lab license. See README.md for the details.
"""
from __future__ import print_function

import sys

if sys.version_info < (3, 6):
    sys.stderr.write('thor-split-scan needs Python 3.6 or newer (this is Python %s).\n'
                     % sys.version.split()[0])
    sys.exit(2)

import argparse
import collections
import csv
import datetime
import fnmatch
import json
import os
import re
import signal
import subprocess
import time

VERSION = '1.0.0'
IS_WINDOWS = os.name == 'nt'

RUN_FILE = 'run.json'
WORKLIST_FILE = 'worklist.jsonl'
STATE_FILE = 'state.jsonl'
SUMMARY_FILE = 'summary.csv'
LOG_FILE = 'thor-split-scan.log'
LOCK_FILE = 'run.lock'
SCANS_DIR = 'scans'

EXIT_OK = 0        # every scan finished
EXIT_FAILED = 1    # some scans failed, or a problem stopped the run
EXIT_USAGE = 2     # bad arguments or setup
EXIT_STOPPED = 3   # stopped (Ctrl+C) before every scan ran

STARTUP_SECONDS = 15   # rough start-up time of one THOR 10 scan (loading signatures)
CANCEL_GRACE = 60      # seconds THOR gets to exit after it was told to stop

# THOR flags this script sets itself, so they cannot be passed after "--".
MANAGED_FLAGS = {
    '-p': 'the folders to scan come from the split',
    '--path': 'the folders to scan come from the split',
    '-e': 'every scan writes into its own folder in the output folder',
    '--rebase-dir': 'every scan writes into its own folder in the output folder',
    '-l': 'every scan writes thor.txt into its own folder',
    '--logfile': 'every scan writes thor.txt into its own folder',
    '--htmlfile': 'every scan writes thor.html into its own folder',
    '--stats-file': 'every scan writes stats.csv into its own folder',
    '--jsonfile': 'use --json of this script',
    '--threads': 'use --threads of this script',
    '--resume': '--lab turns ThorDB off, so THOR cannot resume; run this script again instead',
    '--resumeonly': '--lab turns ThorDB off, so THOR cannot resume; run this script again instead',
}
HOSTNAME_FLAGS = ('-j', '--overwrite-hostname')

# Lines in THOR's console output that mean THOR did not accept its command line.
USAGE_ERRORS = ('Positional arguments specified', 'unknown flag', 'unknown shorthand flag',
                'invalid argument', 'flag needs an argument', 'bad flag syntax')


# --------------------------------------------------------------------------------------------
# Splitting the directory

class Job(object):
    """One THOR scan: a folder with its subfolders, or only the files directly in a folder."""
    __slots__ = ('rel', 'files_only', 'path', 'name', 'index')

    def __init__(self, rel, files_only, path, name='', index=0):
        self.rel = rel                # path below the scanned folder, '/' separated, '.' for itself
        self.files_only = files_only  # True: only the files directly in it (THOR's :NOWALK)
        self.path = path
        self.name = name              # its folder in <output>/scans
        self.index = index            # 1-based position in the work list

    @property
    def key(self):
        return ('F ' if self.files_only else 'D ') + self.rel

    @property
    def label(self):
        return self.rel + (' (files directly in it)' if self.files_only else '')

    @property
    def scope(self):
        return 'only the files directly in it' if self.files_only else 'folder and subfolders'


def job_path(root, rel):
    return root if rel == '.' else os.path.join(root, *rel.split('/'))


def _is_dir(entry):
    try:
        return entry.is_dir(follow_symlinks=False)
    except OSError:
        return False


def _is_file(entry):
    try:
        return entry.is_file(follow_symlinks=False)
    except OSError:
        return False


def _entries(path):
    it = os.scandir(path)
    try:
        entries = list(it)
    finally:
        it.close()
    entries.sort(key=lambda e: e.name)
    return entries


def excluded(rel, name, patterns):
    for p in patterns:
        if fnmatch.fnmatch(name, p) or fnmatch.fnmatch(rel, p):
            return True
    return False


def split_folder(root, level, patterns=(), note=None):
    """The scans for `root` split at `level`, and what was left out.

    Symbolic links to folders are not followed (THOR does not follow them either). Folders
    matching an exclude pattern are left out with everything in them; the patterns are only
    tested on the folders down to `level`."""
    jobs = []
    info = {'listed': 0, 'empty': 0, 'excluded': 0, 'unlisted': []}

    def visit(path, rel, depth):
        if depth == level:
            jobs.append(Job(rel, False, path))
            return
        try:
            entries = _entries(path)
        except OSError as e:
            if depth == 0:
                raise
            # THOR gets the whole folder; it reports what it cannot read itself.
            info['unlisted'].append((rel, e.strerror or str(e)))
            jobs.append(Job(rel, False, path))
            return
        info['listed'] += 1
        if note:
            note(info['listed'], len(jobs))
        dirs = [e for e in entries if _is_dir(e)]
        has_files = any(_is_file(e) for e in entries)
        if not dirs:
            if has_files or depth == 0:
                jobs.append(Job(rel, False, path))
            else:
                info['empty'] += 1
            return
        if has_files:
            jobs.append(Job(rel, True, path))
        for e in dirs:
            r = e.name if rel == '.' else rel + '/' + e.name
            if excluded(r, e.name, patterns):
                info['excluded'] += 1
                continue
            visit(os.path.join(path, e.name), r, depth + 1)

    visit(root, '.', 0)
    return jobs, info


def _safe(text):
    return re.sub(r'[^A-Za-z0-9._-]+', '_', text).strip('._') or '_'


def base_name(job):
    name = 'root' if job.rel == '.' else '__'.join(_safe(c) for c in job.rel.split('/'))
    if job.files_only:
        name += '__files'
    return name[:100]


def assign_names(jobs, known=None):
    """Give every scan its own output folder name; names in `known` (key -> name) are kept."""
    known = known or {}
    taken = set(n.lower() for n in known.values())
    for i, job in enumerate(jobs):
        job.index = i + 1
        if job.key in known:
            job.name = known[job.key]
            continue
        base = base_name(job)
        name, n = base, 2
        while name.lower() in taken:
            name = '%s-%d' % (base, n)
            n += 1
        taken.add(name.lower())
        job.name = name


def hostname_for(job, level):
    """The name of the folder at `level` above the scan, used as THOR's hostname (-j)."""
    if not level or job.rel == '.':
        return None
    parts = job.rel.split('/')
    return _safe(parts[level - 1]) if len(parts) >= level else None


# --------------------------------------------------------------------------------------------
# What THOR does to -p values

def _special(c):
    return c in '*#$@!?-' or '0' <= c <= '9'


def _alnum(c):
    return c == '_' or '0' <= c <= '9' or 'a' <= c <= 'z' or 'A' <= c <= 'Z'


def _shell_name(s):
    """Go's os.getShellName: the variable name after a '$' and how many characters it takes."""
    if s[0] == '{':
        if len(s) > 2 and _special(s[1]) and s[2] == '}':
            return s[1:2], 3
        for i in range(1, len(s)):
            if s[i] == '}':
                if i == 1:
                    return '', 2
                return s[1:i], i + 1
        return '', 1
    if _special(s[0]):
        return s[0], 1
    i = 0
    while i < len(s) and _alnum(s[i]):
        i += 1
    return s[:i], i


def go_expand(s, lookup):
    """Go's os.Expand. THOR replaces $NAME and ${NAME} in -p values with environment variables."""
    out = None
    i = j = 0
    while j < len(s):
        if s[j] == '$' and j + 1 < len(s):
            if out is None:
                out = []
            out.append(s[i:j])
            name, w = _shell_name(s[j + 1:])
            if name == '' and w > 0:
                pass               # bad syntax: Go drops these characters
            elif name == '':
                out.append('$')    # a '$' without a name stays
            else:
                out.append(lookup(name))
            j += w
            i = j + 1
        j += 1
    if out is None:
        return s
    out.append(s[i:])
    return ''.join(out)


def env_for_path(value, environ=None):
    """Environment variables that make THOR keep `value` as it is, e.g. RECYCLE=$RECYCLE for
    a folder named $RECYCLE.BIN. Returns (variables, None), or (None, reason) when that is
    not possible."""
    environ = os.environ if environ is None else environ
    if '$' not in value:
        return {}, None
    fold = (lambda n: n.upper()) if IS_WINDOWS else (lambda n: n)
    tokens = collections.OrderedDict()
    j = 0
    while j < len(value):
        if value[j] == '$' and j + 1 < len(value):
            name, w = _shell_name(value[j + 1:])
            if name:
                tokens.setdefault(fold(name), set()).add((name, value[j:j + 1 + w]))
            j += w
        j += 1
    env = {}
    for key, found in tokens.items():
        texts = sorted(set(t for _, t in found))
        if len(texts) > 1:
            return None, 'its path contains both %s, which THOR treats as the same variable' % ' and '.join(texts)
        name = sorted(found)[0][0]
        if name in environ:
            return None, ('THOR would replace %s in its path with the value of the environment '
                          'variable %s' % (texts[0], name))
        env[name] = texts[0]
    folded = dict((fold(k), v) for k, v in env.items())
    once = go_expand(value, lambda n: folded.get(fold(n), ''))
    if once != value or go_expand(once, lambda n: folded.get(fold(n), '')) != value:
        return None, 'THOR would change the "$" characters in its path'
    return env, None


def thor_list_value(value):
    """THOR reads every -p value as a CSV list: quote a path with a comma or a quote in it."""
    if re.search(r'[,"\r\n]', value) or value != value.strip():
        return '"' + value.replace('"', '""') + '"'
    return value


def check_extra(extra, hostname_level):
    """Reasons why THOR flags given after "--" cannot be used."""
    problems = []
    for a in extra:
        if not a.startswith('-') or a == '-':
            continue
        name = a.split('=', 1)[0]
        if not name.startswith('--') and len(name) > 2:
            name = name[:2]
        if name in MANAGED_FLAGS:
            problems.append('%s: %s' % (a, MANAGED_FLAGS[name]))
        elif hostname_level and name in HOSTNAME_FLAGS:
            problems.append('%s: --hostname-level sets the hostname of every scan' % a)
    return problems


# --------------------------------------------------------------------------------------------
# THOR

def find_thor(path):
    """The THOR binary: `path` itself, or the one for this system in the folder `path`."""
    path = os.path.abspath(path)
    if os.path.isfile(path):
        return path
    if IS_WINDOWS:
        names = ['thor64.exe', 'thor.exe']
    elif sys.platform == 'darwin':
        names = ['thor-macosx']
    else:
        names = ['thor-linux-64', 'thor-linux']
    for n in names:
        p = os.path.join(path, n)
        if os.path.isfile(p):
            return p
    return None


def thor_version(binary):
    """THOR's version (e.g. '10.7.30'), or raise RuntimeError."""
    try:
        r = subprocess.run([binary, '--version'], cwd=os.path.dirname(binary), stdin=subprocess.DEVNULL,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300,
                           universal_newlines=True, errors='replace')
    except (OSError, subprocess.SubprocessError) as e:
        raise RuntimeError('cannot run %s: %s' % (binary, e))
    m = re.search(r'THOR (\d+\.\d+\.\d+\S*)', r.stdout or '')
    if not m:
        raise RuntimeError('%s --version did not print a THOR version (exit code %s)' % (binary, r.returncode))
    return m.group(1)


def _read_parts(path, head=4 << 20, tail=256 << 10):
    """The start and the end of a (possibly large) log file, as text."""
    try:
        size = os.path.getsize(path)
        with open(path, 'rb') as f:
            h = f.read(head)
            t = b''
            if size > head:
                f.seek(max(head, size - tail))
                t = f.read()
    except OSError:
        return None, None
    return h.decode('utf-8', 'replace'), (h[-tail:] + t).decode('utf-8', 'replace')


_COUNTS = re.compile(r'ALERTS: (\d+) WARNINGS: (\d+) NOTICES: (\d+) ERRORS: (\d+)')
_ERROR = re.compile(r'THOR: Error: MODULE: \S+ MESSAGE: (.*?)(?: SCANID: | [A-Z_]+: |$)', re.M)


def read_results(out_dir):
    """What a THOR scan wrote: {'log', 'finished', 'scanned', 'counts', 'error', 'license_error'}."""
    res = {'log': False, 'finished': False, 'scanned': False, 'counts': None, 'error': '', 'license_error': False}
    head, tail = _read_parts(os.path.join(out_dir, 'thor.txt'))
    if head is not None:
        res['log'] = True
        res['scanned'] = 'MODULE: Filescan MESSAGE: Scanning ' in head
        fin = [l for l in tail.splitlines() if 'MESSAGE: Thor Scan finished' in l]
        if fin:
            res['finished'] = True
            m = _COUNTS.search(fin[-1])
            if m:
                res['counts'] = [int(x) for x in m.groups()]
        errors = _ERROR.findall(head) + _ERROR.findall(tail)
        if errors:
            res['error'] = errors[-1].strip()
            res['license_error'] = any('licen' in e.lower() for e in errors)
    try:
        with open(os.path.join(out_dir, 'stats.csv'), encoding='utf-8', errors='replace') as f:
            last = [l for l in f.read().splitlines() if l.strip()][-1]
        fields = last.rsplit(',', 4)[-4:]
        if len(fields) == 4 and all(x.strip().isdigit() for x in fields):
            res['counts'] = [int(x) for x in fields]
    except (OSError, IndexError):
        pass
    return res


def usage_error(out_dir):
    try:
        with open(os.path.join(out_dir, 'console.txt'), encoding='utf-8', errors='replace') as f:
            text = f.read(1 << 20)
    except OSError:
        return ''
    for line in text.splitlines():
        if any(u in line for u in USAGE_ERRORS):
            return line.strip()
    return ''


# --------------------------------------------------------------------------------------------
# Output, state and summary

def now_text():
    return datetime.datetime.now().astimezone().replace(microsecond=0).isoformat()


def fmt_duration(seconds):
    s = int(round(seconds))
    d, s = divmod(s, 86400)
    h, s = divmod(s, 3600)
    m, s = divmod(s, 60)
    if d:
        return '%dd %dh' % (d, h)
    if h:
        return '%dh %02dm' % (h, m)
    if m:
        return '%dm %02ds' % (m, s)
    return '%ds' % s


def _write_console(text, stream):
    try:
        stream.write(text + '\n')
        stream.flush()
    except UnicodeEncodeError:
        enc = getattr(stream, 'encoding', None) or 'ascii'
        try:
            stream.write(text.encode(enc, 'replace').decode(enc) + '\n')
            stream.flush()
        except (OSError, ValueError):
            pass
    except (OSError, ValueError):
        pass   # the terminal is gone


class Output(object):
    """Messages to the terminal and to the run's log file."""

    def __init__(self):
        self.log = None
        self.console = True

    def open_log(self, path):
        self.log = open(path, 'a', encoding='utf-8')

    def __call__(self, text='', console=True, stream=None):
        stamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        for line in (text.splitlines() or ['']):
            if self.log:
                self.log.write('%s %s\n' % (stamp, line))
                self.log.flush()
            if console and self.console:
                _write_console(('%s  %s' % (stamp, line)) if line else '', stream or sys.stdout)


def _split_scan_running(pid):
    """Whether process `pid` on this system is a copy of this script (not on Windows)."""
    if IS_WINDOWS or pid == os.getpid():
        return False
    try:
        os.kill(pid, 0)
    except PermissionError:
        pass
    except OSError:
        return False
    try:
        with open('/proc/%d/cmdline' % pid, 'rb') as f:
            args = f.read().decode('utf-8', 'replace')
    except OSError:
        try:
            args = subprocess.run(['ps', '-p', str(pid), '-o', 'args='], stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, universal_newlines=True, timeout=10).stdout
        except (OSError, subprocess.SubprocessError):
            return False
    return 'thor-split-scan' in args


class RunLock(object):
    """Keeps a second copy of this script from working on the same output folder: a file lock,
    and the process ID and host name in the file for file systems where file locks do not reach
    other processes (some network shares, some container mounts)."""

    def __init__(self, path):
        self.path = path
        self.fh = None

    def owner(self):
        """The process ID written by a copy of this script that is still running on this system."""
        try:
            with open(self.path, encoding='utf-8') as f:
                parts = f.read().split()
            pid, host = int(parts[0]), parts[1]
        except (OSError, ValueError, IndexError):
            return None
        if host == _hostname() and _split_scan_running(pid):
            return pid
        return None

    def acquire(self, write=True):
        fh = open(self.path, 'a+', encoding='utf-8')
        try:
            if IS_WINDOWS:
                import msvcrt
                fh.seek(0)
                msvcrt.locking(fh.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (IOError, OSError):
            fh.close()
            return False
        if self.owner():
            fh.close()
            return False
        if write:
            fh.seek(0)
            fh.truncate()
            fh.write('%d %s\n' % (os.getpid(), _hostname()))
            fh.flush()
        self.fh = fh
        return True

    def release(self):
        if self.fh:
            self.fh.close()
            self.fh = None


def _hostname():
    import socket
    return socket.gethostname() or 'unknown'


def load_state(path):
    """The last record of every scan in the state file."""
    state = {}
    try:
        f = open(path, encoding='utf-8')
    except OSError:
        return state
    with f:
        for line in f:
            try:
                rec = json.loads(line)
            except ValueError:
                continue   # a line cut off by a crash
            if isinstance(rec, dict) and 'key' in rec:
                state[rec['key']] = rec
    return state


def status_of(rec, running_now=False):
    if rec is None:
        return 'not started'
    if rec.get('event') == 'start':
        return 'running' if running_now else 'interrupted'
    return rec.get('status', 'not started')


def write_jobs(path, jobs):
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        for j in jobs:
            f.write(json.dumps({'rel': j.rel, 'files_only': j.files_only, 'name': j.name},
                               ensure_ascii=False) + '\n')
    os.replace(tmp, path)


def read_jobs(path, root):
    jobs = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            if line.strip():
                d = json.loads(line)
                jobs.append(Job(d['rel'], d['files_only'], job_path(root, d['rel']), d['name']))
    for i, j in enumerate(jobs):
        j.index = i + 1
    return jobs


SUMMARY_COLUMNS = ['folder', 'scope', 'status', 'reason', 'started', 'finished', 'seconds', 'exit_code',
                   'alerts', 'warnings', 'notices', 'errors', 'output']


def write_summary(path, jobs, state, running_now=False):
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f)
        w.writerow(SUMMARY_COLUMNS)
        for j in jobs:
            rec = state.get(j.key) or {}
            st = status_of(state.get(j.key), running_now)
            counts = rec.get('counts') or ['', '', '', '']
            w.writerow([j.rel, j.scope, st, rec.get('reason', ''), rec.get('started', ''),
                        rec.get('finished', ''), rec.get('seconds', ''), rec.get('exit_code', '')]
                       + counts + [SCANS_DIR + '/' + j.name if rec else ''])
    try:
        os.replace(tmp, path)
    except OSError:
        # e.g. the summary is open in Excel on Windows
        alt = '%s-%s.csv' % (path[:-4], datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
        os.replace(tmp, alt)
        return alt
    return path


def count_statuses(jobs, state, running_now=False):
    c = collections.Counter(status_of(state.get(j.key), running_now) for j in jobs)
    return c


# --------------------------------------------------------------------------------------------
# Running the scans

class Control(object):
    """What Ctrl+C and other signals asked for. The handlers only set flags."""

    def __init__(self):
        self.presses = 0
        self.stop = False      # start no more scans
        self.cancel = False    # end the running scans
        self.kill = False      # end them without waiting
        self.why = ''
        self.console_gone = False

    def on_interrupt(self, signum, frame):
        self.presses += 1
        self.stop = True
        if self.presses == 2:
            self.cancel = True
        elif self.presses > 2:
            self.kill = True

    def on_terminate(self, signum, frame):
        self.stop = self.cancel = True
        self.why = 'the script was told to stop (signal %d)' % signum

    def on_hangup(self, signum, frame):
        self.console_gone = True

    def install(self):
        signal.signal(signal.SIGINT, self.on_interrupt)
        if IS_WINDOWS:
            signal.signal(signal.SIGBREAK, self.on_terminate)
        else:
            signal.signal(signal.SIGTERM, self.on_terminate)
            signal.signal(signal.SIGHUP, self.on_hangup)


def _parent_death_signal():
    """On Linux, let THOR get SIGTERM if this script dies (so no THOR runs on unnoticed)."""
    if not sys.platform.startswith('linux'):
        return None
    try:
        import ctypes
        libc = ctypes.CDLL(None, use_errno=True)
        prctl = libc.prctl
    except (OSError, AttributeError):
        return None

    def child():
        prctl(1, signal.SIGTERM)   # PR_SET_PDEATHSIG
    return child


class Running(object):
    __slots__ = ('job', 'proc', 'out_dir', 'started', 'started_text', 'console')

    def __init__(self, job, proc, out_dir, started, started_text, console):
        self.job, self.proc, self.out_dir = job, proc, out_dir
        self.started, self.started_text, self.console = started, started_text, console


class Runner(object):
    def __init__(self, opts, thor, root, out_dir, jobs, state, say, ctl):
        self.opts = opts
        self.thor = thor
        self.root = root
        self.out_dir = out_dir
        self.scans_dir = os.path.join(out_dir, SCANS_DIR)
        self.jobs = jobs
        self.state = state
        self.say = say
        self.ctl = ctl
        self.state_fh = open(os.path.join(out_dir, STATE_FILE), 'a', encoding='utf-8')
        self.preexec = _parent_death_signal()
        self.counts = count_statuses(jobs, state)
        self.running = []
        self.queue = collections.deque()
        self.in_a_row = 0
        self.fatal = ''
        self.durations = []
        self.noted_presses = 0
        self.noted_why = False
        self.cancel_sent = None
        self.killed = False

    # -- state

    def record(self, rec):
        self.counts[status_of(self.state.get(rec['key']))] -= 1
        self.counts[status_of(rec)] += 1
        self.state[rec['key']] = rec
        self.state_fh.write(json.dumps(rec, ensure_ascii=False) + '\n')
        self.state_fh.flush()
        try:
            os.fsync(self.state_fh.fileno())
        except OSError:
            pass

    def end(self, job, status, reason='', started_text='', seconds=None, exit_code=None, counts=None):
        rec = {'key': job.key, 'event': 'end', 'status': status, 'reason': reason, 'name': job.name,
               'started': started_text, 'finished': now_text()}
        if seconds is not None:
            rec['seconds'] = int(round(seconds))
        if exit_code is not None:
            rec['exit_code'] = exit_code
        if counts is not None:
            rec['counts'] = counts
        self.record(rec)

    # -- one scan

    def thor_args(self, job, out_dir):
        value = job.path + (':NOWALK' if job.files_only else '')
        args = [self.thor, '--lab', '--alldrives', '--threads', str(self.opts.threads),
                '-p', thor_list_value(value), '-e', out_dir,
                '-l', 'thor.txt', '--htmlfile', 'thor.html', '--stats-file=stats.csv', '--silent']
        if self.opts.json:
            args.append('--jsonfile=thor.json')
        host = hostname_for(job, self.opts.hostname_level)
        if host:
            args += ['-j', host]
        return args + self.opts.extra

    def move_old_output(self, job, out_dir):
        """Keep the output of an earlier attempt next to the new one."""
        if not os.path.exists(out_dir):
            return None
        old = status_of(self.state.get(job.key))
        tag = old if old in ('failed', 'interrupted') else 'old'
        n = 1
        while os.path.exists('%s.%s-%d' % (out_dir, tag, n)):
            n += 1
        target = '%s.%s-%d' % (out_dir, tag, n)
        os.rename(out_dir, target)
        return target

    def start(self, job):
        """Start THOR for `job`; False when the scan ended before THOR ran."""
        if not os.path.isdir(job.path):
            self.failed(job, 'folder not found (renamed, deleted, or the share is not mounted)', count=True)
            return False
        value = job.path + (':NOWALK' if job.files_only else '')
        extra_env, problem = env_for_path(value)
        if problem:
            self.failed(job, 'not scanned: %s; scan this folder by hand' % problem)
            return False
        out_dir = os.path.join(self.scans_dir, job.name)
        try:
            self.move_old_output(job, out_dir)
        except OSError as e:
            self.failed(job, 'cannot move the output of the earlier attempt out of the way (%s); '
                             'is an old THOR still running?' % (e.strerror or e))
            return False
        try:
            os.makedirs(out_dir)
            console = open(os.path.join(out_dir, 'console.txt'), 'wb')
        except OSError as e:
            self.end(job, 'failed', 'cannot create its output folder: %s' % (e.strerror or e))
            self.fatal = 'cannot write to %s: %s' % (out_dir, e.strerror or e)
            return False
        env = None
        if extra_env:
            env = dict(os.environ)
            env.update(extra_env)
        started_text = now_text()
        kwargs = {'cwd': os.path.dirname(self.thor), 'stdin': subprocess.DEVNULL, 'stdout': console,
                  'stderr': subprocess.STDOUT, 'env': env}
        if IS_WINDOWS:
            # Its own process group: Ctrl+C in this window does not reach THOR.
            kwargs['creationflags'] = subprocess.CREATE_NEW_PROCESS_GROUP
        else:
            kwargs['start_new_session'] = True
            if self.preexec:
                kwargs['preexec_fn'] = self.preexec
        self.record({'key': job.key, 'event': 'start', 'name': job.name, 'started': started_text})
        try:
            proc = subprocess.Popen(self.thor_args(job, out_dir), **kwargs)
        except OSError as e:
            console.close()
            self.end(job, 'failed', 'cannot start THOR: %s' % e, started_text)
            self.fatal = 'THOR could not be started: %s' % e
            return False
        self.running.append(Running(job, proc, out_dir, time.time(), started_text, console))
        self.say('start   [%s] %s' % (self.position(job), job.label))
        return True

    def failed(self, job, reason, count=False, **kw):
        self.end(job, 'failed', reason, **kw)
        self.say('FAILED  [%s] %s: %s' % (self.position(job), job.label, reason))
        if count:
            self.in_a_row += 1

    def position(self, job):
        width = len(str(len(self.jobs)))
        return '%*d/%d' % (width, job.index, len(self.jobs))

    def finish(self, r, rc):
        r.console.close()
        seconds = time.time() - r.started
        res = read_results(r.out_dir)
        kw = {'started_text': r.started_text, 'seconds': seconds, 'exit_code': rc, 'counts': res['counts']}
        job = r.job
        if self.cancel_sent is not None and not (rc == 0 and res['finished']):
            self.end(job, 'interrupted', 'stopped before it finished', **kw)
            self.say('stopped [%s] %s after %s' % (self.position(job), job.label, fmt_duration(seconds)))
            return
        reason = ''
        if rc != 0:
            if res['license_error']:
                self.fatal = 'THOR did not accept its license: %s. Scanning a directory this way needs ' \
                             'a Forensic Lab license in the THOR folder.' % res['error']
            else:
                bad = usage_error(r.out_dir)
                if bad:
                    self.fatal = 'THOR did not accept its command line: %s' % bad
            if rc < 0:
                reason = 'THOR was ended by signal %d' % -rc
            else:
                reason = res['error'] or 'THOR exited with code %d' % rc
                if res['error']:
                    reason += ' (exit code %d)' % rc
        elif res['log'] and not res['finished']:
            reason = 'THOR exited without finishing the scan'
        elif res['log'] and not res['scanned']:
            reason = 'THOR scanned nothing (the folder is missing, cannot be read, or THOR\'s own ' \
                     'excludes leave it out)'
        if reason:
            self.failed(job, reason, count=True, **kw)
            return
        self.end(job, 'done', **kw)
        self.in_a_row = 0
        self.durations.append(seconds)
        c = res['counts']
        found = ('alerts %d, warnings %d, notices %d' % tuple(c[:3])) if c else 'no counts'
        self.say('done    [%s] %s in %s: %s' % (self.position(job), job.label, fmt_duration(seconds), found))

    # -- the queue

    def note_signals(self):
        if self.ctl.console_gone and self.say.console:
            self.say.console = False
            self.say('The terminal was closed; the run goes on. Messages continue in %s.' % LOG_FILE,
                     console=False)
        if self.ctl.why and not self.noted_why:
            self.noted_why = True
            self.say('Stopping: %s. Ending the running scans; they start over on the next run.' % self.ctl.why)
        if self.ctl.presses == self.noted_presses:
            return
        self.noted_presses = self.ctl.presses
        if self.ctl.presses == 1:
            if self.running:
                self.say('Ctrl+C: no new scans start. Waiting for the %d running scan(s) to finish, which '
                         'can take a long time. Press Ctrl+C again to end them now; they start over on '
                         'the next run.' % len(self.running))
        elif self.ctl.presses == 2:
            self.say('Ctrl+C again: ending the running scans. Press Ctrl+C once more to end them at once.')
        else:
            self.say('Ending the running scans at once.')

    def progress(self):
        c = self.counts
        waiting = len(self.queue)
        if self.ctl.stop:
            self.say('        %d done, %d failed, %d running; %d left for the next run'
                     % (c['done'], c['failed'], len(self.running), waiting))
            return
        text = '%d done, %d failed, %d running, %d waiting' % (c['done'], c['failed'], len(self.running), waiting)
        if self.durations and (waiting or self.running):
            avg = sum(self.durations) / len(self.durations)
            left = avg * (waiting + len(self.running) * 0.5) / max(1, self.opts.parallel)
            text += '; about %s left' % fmt_duration(left)
        self.say('        ' + text)

    def run(self, todo):
        self.queue.extend(todo)
        while True:
            self.note_signals()
            if self.ctl.cancel and self.cancel_sent is None:
                self.cancel_sent = time.time()
                for r in self.running:
                    _terminate(r.proc)
            if self.cancel_sent is not None and not self.killed and \
                    (self.ctl.kill or time.time() - self.cancel_sent > CANCEL_GRACE):
                self.killed = True
                for r in self.running:
                    _kill(r.proc)
            if self.fatal and not self.ctl.stop:
                self.ctl.stop = True
                self.say('PROBLEM: %s' % self.fatal)
                if self.running:
                    self.say('No new scans start; waiting for the %d running scan(s).' % len(self.running))
            limit = self.opts.stop_after_failures
            if limit and self.in_a_row >= limit and not self.ctl.stop:
                self.ctl.stop = True
                self.fatal = '%d scans in a row failed. Check the folder (is the share still mounted?) ' \
                             'and the failed scans in %s, then run again.' % (self.in_a_row, SUMMARY_FILE)
                self.say('PROBLEM: %s' % self.fatal)
            while not self.ctl.stop and self.queue and len(self.running) < self.opts.parallel:
                job = self.queue.popleft()
                if not self.start(job):
                    self.progress()
                if self.fatal or (limit and self.in_a_row >= limit):
                    break
            for r in list(self.running):
                rc = r.proc.poll()
                if rc is None:
                    continue
                self.running.remove(r)
                self.finish(r, rc)
                self.progress()
            if not self.running and (self.ctl.stop or not self.queue):
                break
            time.sleep(0.5)
        self.state_fh.close()
        return len(self.queue)


def _terminate(proc):
    try:
        if IS_WINDOWS:
            proc.send_signal(signal.CTRL_BREAK_EVENT)
        else:
            os.killpg(proc.pid, signal.SIGTERM)
    except OSError:
        pass


def _kill(proc):
    try:
        if IS_WINDOWS:
            proc.kill()
        else:
            os.killpg(proc.pid, signal.SIGKILL)
    except OSError:
        pass


# --------------------------------------------------------------------------------------------
# Command line

EPILOG = '''examples:
  See how a share would be split at level 2, without scanning:
    python3 thor-split-scan.py --dry-run --level 2 /mnt/share

  Scan it, 4 scans at a time:
    python3 thor-split-scan.py --thor /opt/thor --output /data/split-scan --level 2 --parallel 4 /mnt/share

  Continue after a stop or a crash: run the same command again.
  See how far a run is, also while it runs, and write its summary.csv:
    python3 thor-split-scan.py --status --output /data/split-scan

  Pass more THOR flags after "--":
    python3 thor-split-scan.py --thor /opt/thor --output /data/split-scan /mnt/share -- --max_file_size 50MB

exit codes: 0 every scan finished, 1 scans failed or a problem stopped the run,
2 bad arguments, 3 stopped with Ctrl+C before every scan ran.'''


def parse_args(argv):
    if '--' in argv:
        i = argv.index('--')
        own, extra = argv[:i], argv[i + 1:]
    else:
        own, extra = argv, []
    p = argparse.ArgumentParser(
        prog='thor-split-scan.py',
        description='Scan a large directory with THOR 10 as many smaller scans: one per folder at a chosen '
                    'level, several at a time. Every file is scanned once. Run the same command again to '
                    'continue an interrupted run.',
        epilog=EPILOG, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('folder', nargs='?', help='the directory to scan (can be left out when continuing a run)')
    p.add_argument('--thor', metavar='PATH', help='the THOR folder, or the THOR binary in it')
    p.add_argument('-o', '--output', metavar='DIR',
                   help='folder for this run: one subfolder per scan, the summary and the progress. '
                        'Must not be inside the scanned directory')
    p.add_argument('--level', type=int, metavar='N',
                   help='the folder level to split at: 1 = the folders in the directory, 2 = the folders in '
                        'those, ... (default 1)')
    p.add_argument('--parallel', type=int, default=1, metavar='P', help='scans at a time (default 1)')
    p.add_argument('--threads', type=int, metavar='T',
                   help='THOR threads per scan (default: CPU cores divided by --parallel)')
    p.add_argument('--exclude', action='append', default=[], metavar='PATTERN',
                   help='leave out folders whose name or path below the directory matches this pattern '
                        '(*, ?, [abc]); can be given more than once; only for folders down to --level')
    p.add_argument('--json', action='store_true', help='also write THOR\'s JSON log (thor.json) per scan')
    p.add_argument('--hostname-level', type=int, default=0, metavar='N',
                   help='use the name of the folder at level N as THOR\'s hostname (-j), e.g. 1 when the '
                        'directory holds one folder per system')
    p.add_argument('--retry-failed', action='store_true', help='scan the folders whose scan failed again')
    p.add_argument('--relist', action='store_true',
                   help='when continuing a run, list the folders again to pick up new ones')
    p.add_argument('--stop-after-failures', type=int, default=10, metavar='N',
                   help='stop when N scans in a row fail, e.g. because the share is gone (default 10, 0 = never)')
    p.add_argument('--dry-run', action='store_true', help='list the scans and exit, scan nothing')
    p.add_argument('--status', action='store_true',
                   help='show how far the run in --output is and write its summary.csv, scan nothing')
    p.add_argument('--version', action='version', version='%(prog)s ' + VERSION)
    opts = p.parse_args(own)
    opts.extra = extra
    return p, opts


def plural(n, one, many=None):
    return '%s %s' % ('{:,}'.format(n), one if n == 1 else (many or one + 's'))


def describe_jobs(jobs):
    files_only = sum(1 for j in jobs if j.files_only)
    text = plural(len(jobs), 'scan')
    if files_only:
        text += ': %s with their subfolders, %s with only the files directly in them' % (
            plural(len(jobs) - files_only, 'folder'), '{:,}'.format(files_only))
    return text


def describe_left_out(info):
    parts = []
    if info['empty']:
        parts.append(plural(info['empty'], 'empty folder'))
    if info['excluded']:
        parts.append(plural(info['excluded'], 'excluded folder'))
    return ('Left out: %s.' % ', '.join(parts)) if parts else ''


def list_with_progress(root, level, patterns, say):
    last = [time.time()]

    def note(listed, found):
        if time.time() - last[0] >= 10:
            last[0] = time.time()
            say('Listing folders: %s listed, %s so far' % ('{:,}'.format(listed), plural(found, 'scan')))
    jobs, info = split_folder(root, level, patterns, note)
    for rel, err in info['unlisted']:
        say('Warning: cannot list %s (%s); it is scanned as one folder' % (rel, err))
    return jobs, info


def dry_run(opts, root, level, say):
    jobs, info = list_with_progress(root, level, opts.exclude, say)
    assign_names(jobs)
    say('Directory  %s, split at level %d' % (root, level))
    say(describe_jobs(jobs))
    left_out = describe_left_out(info)
    if left_out:
        say(left_out)
    startup = len(jobs) * STARTUP_SECONDS
    par = max(1, opts.parallel)
    say('THOR needs roughly %ds to start each scan (it loads its signatures): about %s for all of them, '
        '%s with %d at a time.' % (STARTUP_SECONDS, fmt_duration(startup), fmt_duration(startup / par), par))
    for j in jobs[:25]:
        say('  %s' % j.label)
    if len(jobs) > 25:
        say('  ... and %s more' % '{:,}'.format(len(jobs) - 25))
    if opts.output:
        os.makedirs(opts.output, exist_ok=True)
        path = os.path.join(opts.output, 'dry-run.csv')
        with open(path, 'w', encoding='utf-8-sig', newline='') as f:
            w = csv.writer(f)
            w.writerow(['folder', 'scope', 'output'])
            for j in jobs:
                w.writerow([j.rel, j.scope, SCANS_DIR + '/' + j.name])
        say('The full list is in %s' % path)
    return EXIT_OK


def show_status(out_dir, say):
    try:
        with open(os.path.join(out_dir, RUN_FILE), encoding='utf-8') as f:
            run = json.load(f)
        jobs = read_jobs(os.path.join(out_dir, WORKLIST_FILE), run['folder'])
    except (OSError, ValueError, KeyError) as e:
        say('No run found in %s (%s).' % (out_dir, e))
        return EXIT_USAGE
    lock = RunLock(os.path.join(out_dir, LOCK_FILE))
    active = not lock.acquire(write=False)
    lock.release()
    state = load_state(os.path.join(out_dir, STATE_FILE))
    c = count_statuses(jobs, state, active)
    say('Directory  %s, split at level %d%s' % (run['folder'], run['level'],
                                               ' (the run is going on)' if active else ''))
    order = ['done', 'failed', 'running', 'interrupted', 'not started']
    say('%s: %s' % (plural(len(jobs), 'scan'), ', '.join('%s %s' % ('{:,}'.format(c[k]), k) for k in order if c[k])))
    failed = [j for j in jobs if status_of(state.get(j.key), active) == 'failed']
    for j in failed[:20]:
        say('  failed: %s: %s' % (j.label, state[j.key].get('reason', '')))
    if len(failed) > 20:
        say('  ... and %s more failed' % '{:,}'.format(len(failed) - 20))
    path = write_summary(os.path.join(out_dir, SUMMARY_FILE), jobs, state, active)
    say('Summary: %s' % path)
    return EXIT_OK


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    parser, opts = parse_args(argv)
    say = Output()

    def usage(msg):
        parser.print_usage(sys.stderr)
        sys.stderr.write('thor-split-scan.py: error: %s\n' % msg)
        return EXIT_USAGE

    if opts.status:
        if not opts.output:
            return usage('--status needs --output')
        return show_status(os.path.abspath(opts.output), say)

    out_dir = os.path.abspath(opts.output) if opts.output else None
    run = None
    if out_dir and os.path.isfile(os.path.join(out_dir, RUN_FILE)) and not opts.dry_run:
        try:
            with open(os.path.join(out_dir, RUN_FILE), encoding='utf-8') as f:
                run = json.load(f)
        except (OSError, ValueError) as e:
            return usage('cannot read %s: %s' % (os.path.join(out_dir, RUN_FILE), e))
        diffs = []
        if opts.folder and os.path.abspath(opts.folder) != run['folder']:
            diffs.append('directory %s (this run: %s)' % (os.path.abspath(opts.folder), run['folder']))
        if opts.level is not None and opts.level != run['level']:
            diffs.append('level %d (this run: %d)' % (opts.level, run['level']))
        if opts.exclude and sorted(opts.exclude) != sorted(run['exclude']):
            diffs.append('excludes %s (this run: %s)' % (opts.exclude, run['exclude'] or 'none'))
        if diffs:
            return usage('%s holds a run with other settings: %s. Use another output folder for a new run.'
                         % (out_dir, '; '.join(diffs)))
        root, level, patterns = run['folder'], run['level'], run['exclude']
    else:
        if not opts.folder:
            return usage('name the directory to scan')
        root = os.path.abspath(opts.folder)
        level = 1 if opts.level is None else opts.level
        patterns = opts.exclude
    opts.exclude = patterns

    if level < 1:
        return usage('--level must be 1 or more')
    if not os.path.isdir(root):
        return usage('%s is not a directory' % root)

    if opts.dry_run:
        try:
            return dry_run(opts, root, level, say)
        except KeyboardInterrupt:
            say('Stopped.')
            return EXIT_STOPPED

    if not opts.thor:
        return usage('--thor is needed: the THOR folder or binary')
    if not out_dir:
        return usage('--output is needed: a folder for this run')
    if opts.parallel < 1:
        return usage('--parallel must be 1 or more')
    if opts.hostname_level < 0:
        return usage('--hostname-level must be 0 or more')
    if opts.threads is None:
        opts.threads = max(1, (os.cpu_count() or 1) // opts.parallel)
    norm = lambda p: os.path.normcase(os.path.realpath(p))
    if norm(out_dir) == norm(root) or norm(out_dir).startswith(norm(root).rstrip(os.sep) + os.sep):
        return usage('the output folder must not be inside the scanned directory (THOR would scan its own '
                     'results)')
    _, problem = env_for_path(root)
    if problem:
        return usage('%s cannot be scanned this way: %s' % (root, problem))
    if '$' in out_dir:
        return usage('THOR replaces $NAME in paths: use an output folder without "$" in its path')
    problems = check_extra(opts.extra, opts.hostname_level)
    if problems:
        return usage('these THOR flags cannot be used here:\n  ' + '\n  '.join(problems))

    thor = find_thor(opts.thor)
    if not thor:
        return usage('no THOR binary found in %s' % os.path.abspath(opts.thor))
    if '$' in thor:
        return usage('THOR replaces $NAME in paths: move THOR to a folder without "$" in its path')
    try:
        version = thor_version(thor)
    except RuntimeError as e:
        return usage(str(e))
    if not version.startswith('10.'):
        return usage('this script is made for THOR 10, and %s is THOR %s, whose command-line flags differ'
                     % (thor, version))

    os.makedirs(os.path.join(out_dir, SCANS_DIR), exist_ok=True)
    lock = RunLock(os.path.join(out_dir, LOCK_FILE))
    if not lock.acquire():
        return usage('another copy of this script is working on %s' % out_dir)
    try:
        say.open_log(os.path.join(out_dir, LOG_FILE))
        return run_scans(opts, thor, version, root, level, out_dir, run, say)
    finally:
        lock.release()


def run_scans(opts, thor, version, root, level, out_dir, run, say):
    say('thor-split-scan %s' % VERSION)
    worklist = os.path.join(out_dir, WORKLIST_FILE)
    try:
        if run is None or not os.path.isfile(worklist):
            if run is None:
                run = {'tool': 'thor-split-scan', 'version': VERSION, 'folder': root, 'level': level,
                       'exclude': opts.exclude, 'created': now_text()}
                with open(os.path.join(out_dir, RUN_FILE), 'w', encoding='utf-8') as f:
                    json.dump(run, f, indent=2, ensure_ascii=False)
            say('Listing the folders of %s down to level %d ...' % (root, level))
            jobs, info = list_with_progress(root, level, opts.exclude, say)
            assign_names(jobs)
            write_jobs(worklist, jobs)
            left_out = describe_left_out(info)
            if left_out:
                say(left_out)
        else:
            jobs = read_jobs(worklist, root)
            if opts.relist:
                say('Listing the folders of %s down to level %d again ...' % (root, level))
                known = dict((j.key, j.name) for j in jobs)
                new_jobs, info = list_with_progress(root, level, opts.exclude, say)
                assign_names(new_jobs, known)
                added = sum(1 for j in new_jobs if j.key not in known)
                gone = len(set(known) - set(j.key for j in new_jobs))
                write_jobs(worklist, new_jobs)
                jobs = new_jobs
                say('%s new, %s no longer there.' % (plural(added, 'scan'), '{:,}'.format(gone)))
    except KeyboardInterrupt:
        say('Stopped while listing the folders.')
        return EXIT_STOPPED
    except OSError as e:
        say('PROBLEM: cannot list %s: %s' % (root, e))
        return EXIT_FAILED

    state = load_state(os.path.join(out_dir, STATE_FILE))
    retry = ('failed', 'interrupted', 'not started') if opts.retry_failed else ('interrupted', 'not started')
    todo = [j for j in jobs if status_of(state.get(j.key)) in retry]
    c = count_statuses(jobs, state)

    say('THOR       %s (%s)' % (thor, version))
    say('Directory  %s, split at level %d%s' % (root, level,
                                               (', excluding ' + ', '.join(opts.exclude)) if opts.exclude else ''))
    say('Scans      %s' % describe_jobs(jobs))
    if c['done'] or c['failed'] or c['interrupted']:
        text = '%s done, %s failed, %s interrupted' % tuple('{:,}'.format(c[k]) for k in ('done', 'failed', 'interrupted'))
        if c['failed'] and not opts.retry_failed:
            text += ' (--retry-failed scans those again)'
        say('Earlier    %s' % text)
    say('To do      %s' % plural(len(todo), 'scan'))
    say('At once    %s with %s each' % (plural(opts.parallel, 'scan'), plural(opts.threads, 'thread')))
    say('Output     %s' % out_dir)
    if opts.extra:
        say('THOR flags %s' % ' '.join(opts.extra))
    say('Ctrl+C stops starting new scans; press it twice to end the running ones.')

    ctl = Control()
    ctl.install()
    runner = Runner(opts, thor, root, out_dir, jobs, state, say, ctl)
    not_started = runner.run(todo)

    summary = write_summary(os.path.join(out_dir, SUMMARY_FILE), jobs, state)
    c = count_statuses(jobs, state)
    left = c['interrupted'] + c['not started'] + (c['failed'] if opts.retry_failed else 0)
    say('%s done, %s failed, %s not finished. Summary: %s' % (
        '{:,}'.format(c['done']), '{:,}'.format(c['failed']), '{:,}'.format(c['interrupted'] + c['not started']),
        summary))
    if runner.fatal:
        say('Stopped: %s' % runner.fatal)
        return EXIT_FAILED
    if ctl.stop and (not_started or c['interrupted']):
        say('Stopped. Run the same command again to continue.')
        return EXIT_STOPPED
    if c['failed']:
        say('Some scans failed: see the "reason" column in the summary, then run again with --retry-failed.')
        return EXIT_FAILED
    if left:
        return EXIT_STOPPED
    return EXIT_OK


if __name__ == '__main__':
    sys.exit(main())
