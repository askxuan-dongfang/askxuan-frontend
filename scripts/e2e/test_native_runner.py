import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('runner', Path(__file__).with_name('run-native-tests.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class NativeRunnerTests(unittest.TestCase):
    def test_exit_code_and_timeout_cleanup(self):
        with tempfile.TemporaryFile() as log:
            self.assertEqual(runner.run_bounded([sys.executable, '-c', 'raise SystemExit(3)'], log, 5), 3)
            self.assertEqual(runner.run_bounded([sys.executable, '-c', 'import time; time.sleep(60)'], log, 0.1), 124)
            # Timeout leaves no child to wait for.
            with self.assertRaises(ChildProcessError):
                runner.os.waitpid(-1, runner.os.WNOHANG)

    def test_rejects_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / 'fixture.xctestrun'
            fixture.touch()
            result = subprocess.run([sys.executable, str(Path(__file__).with_name('run-native-tests.py')),
                                     '--xctestrun', str(fixture), '--destination', 'platform=macOS',
                                     '--output', directory, '--only-testing', 'Tests'], capture_output=True)
            self.assertEqual(result.returncode, 2)


if __name__ == '__main__':
    unittest.main()
