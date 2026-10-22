import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("xcrun"), "Requires the macOS Swift toolchain")
class MainActorNotificationTests(unittest.TestCase):
    def test_notification_callback_enters_actor_without_assuming_executor(self):
        with tempfile.TemporaryDirectory(prefix="dogsc notification ") as temp:
            executable = pathlib.Path(temp) / "notification-probe"
            compiled = subprocess.run([
                "xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
                str(ROOT / "Sources/DogSCApp/MainActorCallback.swift"),
                str(ROOT / "tests/fixtures/MainActorNotificationProbe.swift"),
                "-o", str(executable),
            ], capture_output=True, text=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Notification callback reached MainActor exactly once", result.stdout)
            rejected = subprocess.run([str(executable), "--reject-background"],
                capture_output=True, text=True, timeout=10)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("AppKit synchronous callback requires the main thread", rejected.stderr)
