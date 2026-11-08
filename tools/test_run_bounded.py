import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


class BoundedCommandTests(unittest.TestCase):
    def run_owned_command(self, source, deadline):
        temporary = tempfile.TemporaryDirectory(prefix="tessera-bounded-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        script = root / "command.py"
        script.write_text(source)
        log = root / "command.log"
        result = subprocess.run(
            [sys.executable, str(Path(__file__).with_name("run_bounded.py")),
             "--timeout", str(deadline), "--log", str(log), "--", sys.executable, str(script)],
            capture_output=True, text=True, timeout=10)
        self.assertFalse(log.with_suffix(".log.pid").exists(),
                         f"Runner exited {result.returncode}: {result.stdout}{result.stderr}")
        return root, result

    def test_deadline_stops_the_command(self):
        _, result = self.run_owned_command("import time\ntime.sleep(30)\n", 0.1)
        self.assertEqual(result.returncode, 124)

    def test_successful_leader_cannot_leave_a_running_child(self):
        source = """import pathlib, subprocess, sys
root = pathlib.Path(__file__).parent
child = 'import pathlib,time; time.sleep(0.8); pathlib.Path(' + repr(str(root / 'escaped')) + ').touch()'
subprocess.Popen([sys.executable, '-c', child])
"""
        root, result = self.run_owned_command(source, 3)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        time.sleep(1)
        self.assertFalse((root / "escaped").exists(), "The child survived its owned command")


if __name__ == "__main__":
    unittest.main()
