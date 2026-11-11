#!/usr/bin/env python3
"""Tests for thor-split-scan.py. Run: python3 -m unittest -v test_thor_split_scan.py

The run tests use a stand-in for THOR (written into a temporary folder) that behaves like THOR 10
where the script depends on it: -p values are CSV lists, $NAME in them is replaced from the
environment, ":NOWALK" scans only the files directly in a folder, the text log and stats.csv
have THOR's lines, and SIGTERM ends it with exit code 1. They need a POSIX system."""
import collections
import csv
import importlib.util
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'thor-split-scan.py')
_spec = importlib.util.spec_from_file_location('thor_split_scan', SCRIPT)
tss = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tss)


def make_tree(base, files=(), dirs=()):
    for d in dirs:
        os.makedirs(os.path.join(base, d), exist_ok=True)
    for f in files:
        p = os.path.join(base, f)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w') as fh:
            fh.write(f + '\n')


def all_files(base):
    out = []
    for d, subdirs, files in os.walk(base):
        for f in files:
            p = os.path.join(d, f)
            if not os.path.islink(p):
                out.append(os.path.relpath(p, base).replace(os.sep, '/'))
    return sorted(out)


def covered(base, jobs):
    """How often each file is scanned by the jobs."""
    c = collections.Counter()
    for j in jobs:
        if j.files_only:
            for e in os.scandir(j.path):
                if e.is_file(follow_symlinks=False):
                    c[os.path.relpath(e.path, base).replace(os.sep, '/')] += 1
        else:
            for f in all_files(j.path):
                c[os.path.relpath(os.path.join(j.path, f), base).replace(os.sep, '/')] += 1
    return c


SHARE = ['readme.txt', 'Sales/budget.csv', 'Sales/WKS1/Users/a.txt', 'Sales/WKS1/b.txt', 'Sales/WKS2/c.txt',
         'IT/SRV1/d/e/f.txt', 'IT/SRV2/g.txt', 'Scans/scan1.txt', '.snapshot/hourly/old.txt',
         'Deep/L2/L3/L4/deep.txt', 'Deep/L2/L3/own3.txt']


class SplitTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.root = os.path.join(self.tmp, 'share')
        make_tree(self.root, SHARE, dirs=['Empty', 'Sales/EmptyToo'])

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_every_file_once_at_every_level(self):
        for level in (1, 2, 3, 4, 5):
            jobs, info = tss.split_folder(self.root, level)
            c = covered(self.root, jobs)
            self.assertEqual(sorted(c), all_files(self.root), 'level %d' % level)
            self.assertEqual(set(c.values()), {1}, 'level %d' % level)
            keys = [j.key for j in jobs]
            self.assertEqual(len(keys), len(set(keys)))

    def test_shape_at_level_2(self):
        jobs, info = tss.split_folder(self.root, 2)
        self.assertEqual([j.label for j in jobs], [
            '. (files directly in it)', '.snapshot/hourly', 'Deep/L2', 'IT/SRV1', 'IT/SRV2',
            'Sales (files directly in it)', 'Sales/EmptyToo', 'Sales/WKS1', 'Sales/WKS2', 'Scans'])
        self.assertEqual(info['empty'], 1)   # Empty; Sales/EmptyToo is at level 2 and is listed

    def test_shape_at_level_1(self):
        jobs, _ = tss.split_folder(self.root, 1)
        self.assertEqual([j.label for j in jobs], [
            '. (files directly in it)', '.snapshot', 'Deep', 'Empty', 'IT', 'Sales', 'Scans'])

    def test_excludes(self):
        jobs, info = tss.split_folder(self.root, 2, ['.snapshot', 'IT/SRV2'])
        labels = [j.label for j in jobs]
        self.assertNotIn('.snapshot/hourly', labels)
        self.assertNotIn('IT/SRV2', labels)
        self.assertIn('IT/SRV1', labels)
        self.assertEqual(info['excluded'], 2)
        c = covered(self.root, jobs)
        self.assertNotIn('.snapshot/hourly/old.txt', c)
        self.assertNotIn('IT/SRV2/g.txt', c)
        self.assertEqual(set(c.values()), {1})

    def test_excluded_subfolder_keeps_its_parent_from_being_scanned_whole(self):
        root = os.path.join(self.tmp, 'x')
        make_tree(root, ['A/own.txt', 'A/skip/secret.txt'])
        jobs, _ = tss.split_folder(root, 2, ['skip'])
        self.assertEqual([j.label for j in jobs], ['A (files directly in it)'])

    def test_folder_with_only_files(self):
        root = os.path.join(self.tmp, 'flat')
        make_tree(root, ['a.txt', 'b.txt'])
        jobs, _ = tss.split_folder(root, 2)
        self.assertEqual([(j.rel, j.files_only) for j in jobs], [('.', False)])

    @unittest.skipIf(os.name == 'nt', 'symbolic links')
    def test_links_to_folders_are_not_followed(self):
        os.symlink(os.path.join(self.root, 'Sales'), os.path.join(self.root, 'IT', 'link'))
        jobs, _ = tss.split_folder(self.root, 2)
        self.assertNotIn('IT/link', [j.label for j in jobs])
        self.assertEqual(set(covered(self.root, jobs).values()), {1})

    def test_names_are_unique_and_kept(self):
        jobs = [tss.Job('A/x', False, ''), tss.Job('A__x', False, ''), tss.Job('a', False, ''),
                tss.Job('A', False, ''), tss.Job('A', True, ''), tss.Job('.', True, ''), tss.Job('Ä ö', False, '')]
        tss.assign_names(jobs)
        self.assertEqual([j.name for j in jobs], ['A__x', 'A__x-2', 'a', 'A-2', 'A__files', 'root__files', '_'])
        again = [tss.Job('new', False, ''), tss.Job('A__x', False, '')]
        tss.assign_names(again, {'D A__x': 'A__x-2'})
        self.assertEqual([j.name for j in again], ['new', 'A__x-2'])

    def test_hostname_level(self):
        self.assertEqual(tss.hostname_for(tss.Job('HOST1/Users', False, ''), 1), 'HOST1')
        self.assertEqual(tss.hostname_for(tss.Job('HOST1', True, ''), 1), 'HOST1')
        self.assertIsNone(tss.hostname_for(tss.Job('.', True, ''), 1))
        self.assertIsNone(tss.hostname_for(tss.Job('HOST1', True, ''), 2))
        self.assertIsNone(tss.hostname_for(tss.Job('HOST1/x', False, ''), 0))


class ThorPathTests(unittest.TestCase):
    def expand(self, s, env):
        return tss.go_expand(s, lambda n: env.get(n, ''))

    def test_go_expand(self):
        env = {'HOME': '/h', 'X': 'x', '1': 'one'}
        self.assertEqual(self.expand('$HOME/a', env), '/h/a')
        self.assertEqual(self.expand('a${X}b', env), 'axb')
        self.assertEqual(self.expand('/$RECYCLE.BIN', env), '/.BIN')
        self.assertEqual(self.expand('$1x', env), 'onex')
        self.assertEqual(self.expand('a$', env), 'a$')
        self.assertEqual(self.expand('a$.b', env), 'a$.b')
        self.assertEqual(self.expand('a${}b', env), 'ab')
        self.assertEqual(self.expand('a${b', env), 'ab')

    def test_env_keeps_paths(self):
        for value in ('/s/$RECYCLE.BIN', '/s/a${X}b', '/s/$1/$$', '/s/$Windows.~BT:NOWALK', '/plain', '/s/a$.b'):
            env, problem = tss.env_for_path(value, environ={})
            self.assertIsNone(problem, value)
            self.assertEqual(self.expand(value, env), value)
            self.assertEqual(self.expand(self.expand(value, env), env), value)
        self.assertEqual(tss.env_for_path('/s/$RECYCLE.BIN', environ={})[0], {'RECYCLE': '$RECYCLE'})
        self.assertEqual(tss.env_for_path('/plain', environ={})[0], {})

    def test_env_refuses(self):
        self.assertIsNone(tss.env_for_path('/s/$HOME', environ={'HOME': '/h'})[0])
        self.assertIsNone(tss.env_for_path('/s/$X/${X}', environ={})[0])
        self.assertIsNone(tss.env_for_path('/s/a${}b', environ={})[0])

    def test_list_value(self):
        self.assertEqual(tss.thor_list_value('/mnt/a b'), '/mnt/a b')
        self.assertEqual(tss.thor_list_value('/mnt/Case 12, laptop:NOWALK'), '"/mnt/Case 12, laptop:NOWALK"')
        self.assertEqual(tss.thor_list_value('/mnt/say "hi"'), '"/mnt/say ""hi"""')
        self.assertEqual(next(csv.reader([tss.thor_list_value('/a, "b"')])), ['/a, "b"'])

    def test_extra_flags(self):
        self.assertEqual(tss.check_extra(['--max_file_size', '50MB', '-a', 'Filescan', '--jsonv2'], 0), [])
        bad = tss.check_extra(['-p', '/x', '--rebase-dir=/o', '-e/o', '--threads', '4', '--resume'], 0)
        self.assertEqual([b.split(':')[0] for b in bad], ['-p', '--rebase-dir=/o', '-e/o', '--threads', '--resume'])
        self.assertEqual(tss.check_extra(['-j', 'x'], 0), [])
        self.assertEqual(len(tss.check_extra(['-j', 'x'], 1)), 1)


class ResultTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dir)

    def write(self, name, text):
        with open(os.path.join(self.dir, name), 'w') as f:
            f.write(text)

    def test_finished_scan(self):
        self.write('thor.txt', 'Nov 11 22:45:25 h/1.2.3.4 THOR: Info: MODULE: Filescan MESSAGE: Scanning /s/A NON RECURSIVE SCANID: S-1\n'
                               'Nov 11 22:45:25 h/1.2.3.4 THOR: Info: MODULE: Report MESSAGE: Thor Scan finished SCANID: S-1 '
                               'END_TIME: x ALERTS: 1 WARNINGS: 2 NOTICES: 3 ERRORS: 4\n')
        r = tss.read_results(self.dir)
        self.assertTrue(r['finished'] and r['scanned'])
        self.assertEqual(r['counts'], [1, 2, 3, 4])
        self.write('stats.csv', 'h,2026-11-11 22:45:19,2026-11-11 22:45:25,10.7.30,--lab -p "/s/B, c" -e /o,5,6,7,8\n')
        self.assertEqual(tss.read_results(self.dir)['counts'], [5, 6, 7, 8])

    def test_license_error(self):
        self.write('thor.txt', 'Nov 11 22:46:47 ion.local/1.2.3.4 THOR: Error: MODULE: Init MESSAGE: No valid license file '
                               'found SCANID: S-X HOSTNAME: ion.local\n')
        r = tss.read_results(self.dir)
        self.assertEqual(r['error'], 'No valid license file found')
        self.assertTrue(r['license_error'])
        self.assertFalse(r['finished'])


FAKE_THOR = r'''#!%(python)s
import csv, importlib.util, json, os, signal, sys, time
spec = importlib.util.spec_from_file_location('tss', %(script)r)
tss = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tss)

args = sys.argv[1:]
if args == ['--version']:
    print(os.environ.get('FAKE_VERSION', 'THOR 10.7.30'))
    sys.exit(0)
opts = {'paths': [], 'flags': []}
with_value = {'-p': 'paths', '-e': 'out', '-l': 'log', '--htmlfile': 'html', '--threads': 'threads', '-j': 'host'}
i = 0
while i < len(args):
    a = args[i]
    if a in with_value:
        if with_value[a] == 'paths':
            opts['paths'].append(args[i + 1])
        else:
            opts[with_value[a]] = args[i + 1]
        i += 2
        continue
    if a.startswith('--stats-file=') or a.startswith('--jsonfile='):
        opts[a[2:a.index('=')]] = a.split('=', 1)[1]
    elif a in ('--lab', '--alldrives', '--silent', '--jsonv2'):
        opts['flags'].append(a)
    else:
        print('unknown flag: %%s' %% a)
        sys.exit(1)
    i += 1
out = opts['out']
os.makedirs(out, exist_ok=True)
log = open(os.path.join(out, opts.get('log', 'thor.txt')), 'w')
host = opts.get('host', 'scanner')
def line(level, module, message):
    log.write('Nov 11 22:45:25 %%s/1.2.3.4 THOR: %%s: MODULE: %%s MESSAGE: %%s SCANID: S-1\n' %% (host, level, module, message))
    log.flush()
def stop(signum, frame):
    line('Error', 'SignalHandler', 'Received shutdown signal, exiting.')
    if os.path.exists(mark):
        os.remove(mark)
    sys.exit(1)
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
record = open(os.environ['FAKE_RECORD'], 'a')
running = os.environ['FAKE_RUNNING']
mark = os.path.join(running, str(os.getpid()))
open(mark, 'w').close()
record.write(json.dumps({'args': args, 'running': len(os.listdir(running))}) + '\n')
record.flush()
if os.environ.get('FAKE_LICENSE'):
    line('Error', 'Init', 'No valid license file found')
    os.remove(mark)
    sys.exit(1)
time.sleep(float(os.environ.get('FAKE_SLEEP', '0')))
warnings = 0
for raw in opts['paths']:
    for value in next(csv.reader([raw])):
        nowalk = value.endswith(':NOWALK')
        path = tss.go_expand(value[:-7] if nowalk else value, lambda n: os.environ.get(n, ''))
        fail = os.environ.get('FAKE_FAIL')
        if fail and fail in path:
            line('Error', 'Filescan', 'Could not scan %%s' %% path)
            os.remove(mark)
            sys.exit(2)
        if not os.path.isdir(path):
            continue
        line('Info', 'Filescan', 'Scanning %%s %%s' %% (path, 'NON RECURSIVE' if nowalk else 'RECURSIVE'))
        if nowalk:
            files = [e.path for e in os.scandir(path) if e.is_file(follow_symlinks=False)]
        else:
            files = [os.path.join(d, f) for d, _, fs in os.walk(path) for f in fs]
        for f in files:
            record.write(json.dumps({'file': f}) + '\n')
            if 'evil' in f:
                warnings += 1
                line('Warning', 'Filescan', 'Malware file found FILE: %%s' %% f)
record.close()
line('Info', 'Report', 'Thor Scan finished END_TIME: x ALERTS: 0 WARNINGS: %%d NOTICES: 1 ERRORS: 0' %% warnings)
if 'stats-file' in opts:
    with open(os.path.join(out, opts['stats-file']), 'w') as f:
        f.write('%%s,2026-11-11 22:45:19,2026-11-11 22:45:25,10.7.30,%%s,0,%%d,1,0\n' %% (host, ' '.join(args), warnings))
open(os.path.join(out, opts.get('html', 'thor.html')), 'w').close()
os.remove(mark)
'''


@unittest.skipIf(os.name == 'nt', 'the stand-in for THOR needs a POSIX system')
class RunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.root = os.path.join(self.tmp, 'share')
        make_tree(self.root, SHARE + ['$RECYCLE.BIN/S-1-5-21/evil.exe', 'Sales/WKS2/evil.dll'], dirs=['Empty'])
        self.thor = os.path.join(self.tmp, 'thor', 'fake-thor')
        os.makedirs(os.path.dirname(self.thor))
        with open(self.thor, 'w') as f:
            f.write(FAKE_THOR % {'python': sys.executable, 'script': SCRIPT})
        os.chmod(self.thor, 0o755)
        self.out = os.path.join(self.tmp, 'out')
        self.record = os.path.join(self.tmp, 'record.jsonl')
        self.running = os.path.join(self.tmp, 'running')
        os.makedirs(self.running)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def env(self, **fake):
        env = dict(os.environ)
        env.pop('RECYCLE', None)
        env.update({'FAKE_RECORD': self.record, 'FAKE_RUNNING': self.running})
        env.update(dict(('FAKE_' + k.upper(), str(v)) for k, v in fake.items()))
        return env

    def args(self, *more, **kw):
        a = [sys.executable, SCRIPT, '--thor', self.thor, '--output', self.out]
        if kw.get('folder', True):
            a.append(self.root)
        return a + list(more)

    def run_script(self, *more, **fake):
        folder = fake.pop('folder', True)
        r = subprocess.run(self.args(*more, folder=folder), env=self.env(**fake), stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, universal_newlines=True, timeout=120)
        return r.returncode, r.stdout

    def recorded(self):
        if not os.path.exists(self.record):
            return [], collections.Counter()
        with open(self.record) as f:
            recs = [json.loads(l) for l in f]
        scans = [r for r in recs if 'args' in r]
        files = collections.Counter(os.path.relpath(r['file'], self.root).replace(os.sep, '/')
                                    for r in recs if 'file' in r)
        return scans, files

    def summary(self):
        with open(os.path.join(self.out, 'summary.csv'), encoding='utf-8-sig') as f:
            return list(csv.DictReader(f))

    def test_full_run(self):
        code, text = self.run_script('--level', '2', '--parallel', '3', '--threads', '2', sleep=0.5)
        self.assertEqual(code, 0, text)
        scans, files = self.recorded()
        self.assertEqual(sorted(files), all_files(self.root))
        self.assertEqual(set(files.values()), {1})
        self.assertEqual(max(s['running'] for s in scans), 3)
        rows = self.summary()
        self.assertEqual(set(r['status'] for r in rows), {'done'})
        self.assertEqual(len(rows), len(scans))
        by_folder = dict((r['folder'] + ('|f' if r['scope'].startswith('only') else ''), r) for r in rows)
        self.assertEqual(by_folder['Sales/WKS2']['warnings'], '1')
        self.assertEqual(by_folder['$RECYCLE.BIN/S-1-5-21']['warnings'], '1')
        nowalk = [s['args'][s['args'].index('-p') + 1] for s in scans if ':NOWALK' in ' '.join(s['args'])]
        self.assertEqual(sorted(os.path.relpath(v[:-7], self.root) for v in nowalk), ['.', 'Sales'])
        for s in scans:
            self.assertEqual(s['args'][s['args'].index('--threads') + 1], '2')
            self.assertIn('--lab', s['args'])
        self.assertTrue(os.path.isfile(os.path.join(self.out, 'scans', 'Sales__WKS2', 'thor.html')))
        self.assertIn('done', text)

    def test_resume_skips_finished_and_retries_failed_on_request(self):
        code, text = self.run_script('--level', '2', fail='/IT/')
        self.assertEqual(code, 1, text)
        failed = [r['folder'] for r in self.summary() if r['status'] == 'failed']
        self.assertEqual(failed, ['IT/SRV1', 'IT/SRV2'])
        self.assertTrue(all(r['reason'].startswith('Could not scan') for r in self.summary() if r['status'] == 'failed'))
        before = len(self.recorded()[0])
        code, text = self.run_script(folder=False)   # the same run, without naming the folder
        self.assertEqual(code, 1, text)
        self.assertEqual(len(self.recorded()[0]), before)
        code, text = self.run_script('--retry-failed', folder=False)
        self.assertEqual(code, 0, text)
        self.assertEqual(len(self.recorded()[0]), before + 2)
        self.assertTrue(os.path.isdir(os.path.join(self.out, 'scans', 'IT__SRV1.failed-1')))
        self.assertEqual(set(r['status'] for r in self.summary()), {'done'})
        _, files = self.recorded()
        self.assertEqual(files['IT/SRV2/g.txt'], 1)   # the failed attempt scanned nothing

    def test_license_problem_stops_the_run(self):
        code, text = self.run_script('--level', '2', '--parallel', '1', license=1)
        self.assertEqual(code, 1, text)
        self.assertIn('license', text)
        self.assertEqual(len(self.recorded()[0]), 1)
        statuses = collections.Counter(r['status'] for r in self.summary())
        self.assertEqual(statuses['failed'], 1)
        self.assertEqual(statuses['not started'], len(self.summary()) - 1)

    def start_and_wait_for_scans(self, n, sleep):
        proc = subprocess.Popen(self.args('--level', '2', '--parallel', str(n)), env=self.env(sleep=sleep),
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        deadline = time.time() + 30
        while time.time() < deadline:
            if len(self.recorded()[0]) >= n:
                return proc
            time.sleep(0.1)
        proc.kill()
        self.fail('the scans did not start')

    def test_ctrl_c_lets_running_scans_finish(self):
        proc = self.start_and_wait_for_scans(2, 2)
        proc.send_signal(signal.SIGINT)
        text, _ = proc.communicate(timeout=60)
        self.assertEqual(proc.returncode, 3, text)
        self.assertIn('no new scans start', text)
        statuses = collections.Counter(r['status'] for r in self.summary())
        self.assertEqual(statuses['done'], 2)
        self.assertEqual(statuses['done'] + statuses['not started'], len(self.summary()))

    def test_ctrl_c_twice_ends_running_scans_and_they_start_over(self):
        proc = self.start_and_wait_for_scans(2, 30)
        proc.send_signal(signal.SIGINT)
        time.sleep(0.3)
        proc.send_signal(signal.SIGINT)
        text, _ = proc.communicate(timeout=60)
        self.assertEqual(proc.returncode, 3, text)
        statuses = collections.Counter(r['status'] for r in self.summary())
        self.assertEqual(statuses['interrupted'], 2)
        interrupted = [r['output'] for r in self.summary() if r['status'] == 'interrupted']
        code, text = self.run_script(sleep=0, folder=False)
        self.assertEqual(code, 0, text)
        for o in interrupted:
            self.assertTrue(os.path.isdir(os.path.join(self.out, o + '.interrupted-1')), o)
        _, files = self.recorded()
        self.assertEqual(set(files.values()), {1})
        self.assertEqual(sorted(files), all_files(self.root))

    def test_missing_folders_stop_the_run(self):
        code, _ = self.run_script('--level', '2', '--parallel', '1', license=1)
        self.assertEqual(code, 1)
        for d in ('IT', 'Sales', 'Scans', 'Deep'):
            shutil.rmtree(os.path.join(self.root, d))
        code, text = self.run_script('--stop-after-failures', '2', folder=False)
        self.assertEqual(code, 1, text)
        self.assertIn('2 scans in a row failed', text)
        self.assertIn('folder not found', text)

    def test_settings_and_flag_checks(self):
        code, _ = self.run_script('--level', '2', license=1)
        self.assertEqual(code, 1)
        code, text = self.run_script('--level', '3')
        self.assertEqual(code, 2)
        self.assertIn('other settings', text)
        inside = subprocess.run([sys.executable, SCRIPT, '--thor', self.thor, '--output', os.path.join(self.root, 'out'),
                                 self.root], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(inside.returncode, 2)
        self.assertIn('must not be inside', inside.stdout)
        code, text = self.run_script('--', '--rebase-dir', '/x')
        self.assertEqual(code, 2)
        self.assertIn('--rebase-dir', text)
        code, text = self.run_script(version='THOR 11.0.0')
        self.assertEqual(code, 2)
        self.assertIn('THOR 10', text)

    def test_dry_run_and_status(self):
        code, text = self.run_script('--level', '2', '--dry-run')
        self.assertEqual(code, 0, text)
        self.assertIn('10 scans: 8 folders with their subfolders, 2 with only the files directly in them', text)
        self.assertIn('Left out: 1 empty folder', text)
        self.assertTrue(os.path.isfile(os.path.join(self.out, 'dry-run.csv')))
        self.assertFalse(os.path.exists(self.record))
        self.run_script('--level', '2', fail='Scans')
        status = subprocess.run([sys.executable, SCRIPT, '--status', '--output', self.out], stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(status.returncode, 0)
        self.assertIn('10 scans: 9 done, 1 failed', status.stdout)
        self.assertIn('failed: Scans: Could not scan', status.stdout)

    def test_lock_by_process_id(self):
        # File locks do not reach other processes on some network and container file systems:
        # a running copy is also recognised by the process ID and host name in run.lock.
        import socket
        os.makedirs(self.out)
        path = os.path.join(self.out, 'run.lock')
        sleeper = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)', 'thor-split-scan'])
        try:
            with open(path, 'w') as f:
                f.write('%d %s\n' % (sleeper.pid, socket.gethostname()))
            self.assertFalse(tss.RunLock(path).acquire())
            sleeper.kill()
            sleeper.wait()
            lock = tss.RunLock(path)
            self.assertTrue(lock.acquire())
            lock.release()
            with open(path) as f:
                self.assertEqual(f.read().split()[0], str(os.getpid()))
        finally:
            sleeper.kill()
            sleeper.wait()

    def test_hostname_level_and_json(self):
        code, text = self.run_script('--level', '2', '--hostname-level', '1', '--json')
        self.assertEqual(code, 0, text)
        scans, _ = self.recorded()
        hosts = sorted(set(s['args'][s['args'].index('-j') + 1] for s in scans if '-j' in s['args']))
        self.assertEqual(hosts, ['Deep', 'IT', 'RECYCLE.BIN', 'Sales', 'Scans', 'snapshot'])
        self.assertTrue(all('--jsonfile=thor.json' in s['args'] for s in scans))


if __name__ == '__main__':
    unittest.main()
