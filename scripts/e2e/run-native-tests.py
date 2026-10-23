#!/usr/bin/env python3
"""Run a previously built native test selection serially, with bounded cleanup."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile


def run_bounded(command, log, timeout):
    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        return process.wait(timeout=timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        # Only signal this runner's process group; never kill shared simulator services.
        os.killpg(process.pid, signal.SIGINT)
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        return 124


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--xctestrun', required=True, type=Path)
    parser.add_argument('--destination', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--only-testing', required=True, action='append')
    parser.add_argument('--timeout', type=int, default=240)
    args = parser.parse_args()
    if not args.xctestrun.is_file() or args.output.exists() or args.timeout <= 0:
        parser.error('Use an existing xctestrun, a new output directory, and a positive timeout.')
    with open(Path(tempfile.gettempdir()) / 'askxuan-native-test.lock', 'a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.error('Another native test runner is active. Wait for it to finish.')
        output = args.output.resolve()
        output.mkdir(parents=True)
        stream = output / 'result.stream'
        stream.touch()
        bundle = output / 'result.xcresult'
        command = ['nice', '-n', '10', 'xcodebuild', 'test-without-building',
                   '-xctestrun', str(args.xctestrun.resolve()), '-destination', args.destination,
                   '-parallel-testing-enabled', 'NO', '-maximum-concurrent-test-simulator-destinations', '1',
                   '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '90',
                   '-maximum-test-execution-time-allowance', '180', '-collect-test-diagnostics', 'never',
                   '-resultBundlePath', str(bundle), '-resultStreamPath', str(stream)]
        command += ['-only-testing:' + target for target in args.only_testing]
        with (output / 'xcodebuild.log').open('w') as log:
            code = run_bounded(command, log, args.timeout)
        (output / 'exit-code.txt').write_text(str(code) + '\n')
        if code:
            print(f'Native tests failed or timed out ({code}); see {output}')
            return code
        summary = subprocess.check_output(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary',
                                           '--path', str(bundle), '--compact'], timeout=30)
        (output / 'summary.json').write_bytes(summary)
        result = json.loads(summary)
        if result.get('result') != 'Passed' or result.get('skippedTests', 0) or not result.get('passedTests', 0):
            print('Acceptance requires passing tests with no skips; inspect summary.json.')
            return 1
        print(f"{result['passedTests']} tests passed; runner exited normally; {output}")
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
