#!/usr/bin/env python3
"""Give a staged app its own identity; never edit the upstream source plist."""
import pathlib
import plistlib
import re
import sys


def prepare(bundle):
    contents = bundle / "Contents"
    path = contents / "Info.plist"
    if not path.is_file():
        raise ValueError(f"Missing app Info.plist: {path}")
    info = plistlib.loads(path.read_bytes())
    identity = {
        "CFBundleIdentifier": "cn.laogou.dogsc.intel",
        "CFBundleName": "DogSC Intel",
        "CFBundleDisplayName": "DogSC Intel",
    }
    info.update(identity)
    info.update({
        "CFBundleVersion": "20",
        "LSMinimumSystemVersion": "13.0",
        "SUEnableAutomaticChecks": False,
        "SUAllowsAutomaticUpdates": False,
        "SUAutomaticallyUpdate": False,
    })
    for key in ("SUFeedURL", "SUPublicEDKey", "SUScheduledCheckInterval"):
        info.pop(key, None)
    path.write_bytes(plistlib.dumps(info, sort_keys=False))
    for localized in (contents / "Resources").glob("*.lproj/InfoPlist.strings"):
        data = localized.read_bytes()
        if data.startswith(b"bplist"):
            strings = plistlib.loads(data)
            strings.update({k: v for k, v in identity.items() if k in strings})
            localized.write_bytes(plistlib.dumps(strings, fmt=plistlib.FMT_BINARY))
        else:
            encoding = "utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8"
            strings = data.decode(encoding)
            for key, value in identity.items():
                strings = re.sub(
                    rf'("?{key}"?\s*=\s*)"(?:\\.|[^"\\])*"\s*;',
                    lambda match: match[1] + '"' + value + '";', strings,
                )
            localized.write_bytes(strings.encode(encoding))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: prepare-intel-bundle.py /path/to/DogSC-Intel.app")
    try:
        prepare(pathlib.Path(sys.argv[1]))
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        sys.exit(str(error))
