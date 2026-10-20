import pathlib
import plistlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
PREPARE = ROOT / "scripts" / "prepare-intel-bundle.py"


class IntelBundleTests(unittest.TestCase):
    def prepare(self, bundle):
        self.assertTrue(PREPARE.is_file(), "Intel bundle preparation is not implemented")
        return subprocess.run(
            ["python3", str(PREPARE), str(bundle)], capture_output=True, text=True
        )

    def test_personal_build_cannot_install_an_upstream_arm_update(self):
        with tempfile.TemporaryDirectory(prefix="dogsc bundle ") as temp:
            bundle = pathlib.Path(temp) / "DogSC Intel.app"
            contents = bundle / "Contents"
            contents.mkdir(parents=True)
            source = {
                "CFBundleIdentifier": "cn.laogou.dogsc",
                "CFBundleDisplayName": "DogSC",
                "CFBundleName": "DogSC",
                "LSMinimumSystemVersion": "14.0",
                "SUFeedURL": "https://example.invalid/arm-appcast.xml",
                "SUPublicEDKey": "upstream-key",
                "SUEnableAutomaticChecks": True,
                "SUAllowsAutomaticUpdates": True,
                "NSMicrophoneUsageDescription": "Record microphone",
                "CFBundleDocumentTypes": [{"CFBundleTypeName": "DogSC project"}],
            }
            (contents / "Info.plist").write_bytes(plistlib.dumps(source))
            locale = contents / "Resources" / "zh-Hans.lproj"
            locale.mkdir(parents=True)
            (locale / "InfoPlist.strings").write_text(
                '"CFBundleDisplayName" = "DogSC";\n"NSCameraUsageDescription" = "Camera";\n'
            )
            result = self.prepare(bundle)
            self.assertEqual(result.returncode, 0, result.stderr)
            info = plistlib.loads((contents / "Info.plist").read_bytes())
            self.assertEqual(info["CFBundleIdentifier"], "cn.laogou.dogsc.intel")
            self.assertEqual(info["CFBundleDisplayName"], "DogSC Intel")
            self.assertEqual(info["LSMinimumSystemVersion"], "13.0")
            self.assertFalse(info["SUEnableAutomaticChecks"])
            self.assertFalse(info["SUAllowsAutomaticUpdates"])
            self.assertNotIn("SUFeedURL", info)
            self.assertNotIn("SUPublicEDKey", info)
            self.assertEqual(info["CFBundleDocumentTypes"], source["CFBundleDocumentTypes"])
            self.assertEqual(info["NSMicrophoneUsageDescription"], "Record microphone")
            strings = (locale / "InfoPlist.strings").read_text()
            self.assertIn('"CFBundleDisplayName" = "DogSC Intel";', strings)
            self.assertIn('"NSCameraUsageDescription" = "Camera";', strings)
            before = (contents / "Info.plist").read_bytes()
            self.assertEqual(self.prepare(bundle).returncode, 0)
            self.assertEqual(before, (contents / "Info.plist").read_bytes())

    def test_missing_bundle_is_reported_without_creating_it(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = pathlib.Path(temp) / "missing.app"
            result = self.prepare(bundle)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(bundle.exists())


if __name__ == "__main__":
    unittest.main()
