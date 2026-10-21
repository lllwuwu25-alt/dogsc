import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("xcrun"), "Requires the macOS Swift toolchain")
class MainActorTimerTests(unittest.TestCase):
    def test_foundation_callback_enters_actor_without_assuming_its_executor(self):
        with tempfile.TemporaryDirectory(prefix="dogsc timer ") as temp:
            executable = pathlib.Path(temp) / "timer-probe"
            compiled = subprocess.run([
                "xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
                str(ROOT / "Sources/DogSCApp/MainActorTimerCallback.swift"),
                str(ROOT / "tests/fixtures/MainActorTimerCallbackProbe.swift"),
                "-o", str(executable),
            ], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Timer callback reached MainActor", result.stdout)
