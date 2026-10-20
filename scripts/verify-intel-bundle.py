#!/usr/bin/env python3
"""Reject wrong-CPU builds or embedded code that raises the deployment floor."""
import pathlib
import plistlib
import subprocess
import sys


def run(*command):
    return subprocess.check_output(command, text=True).strip()


def minimum_versions(load_commands):
    command = None
    versions = []
    for line in load_commands.splitlines():
        line = line.strip()
        if line.startswith("cmd "):
            command = line.split(None, 1)[1]
        if command == "LC_BUILD_VERSION" and line.startswith("minos "):
            versions.append(line.split()[1])
        elif command == "LC_VERSION_MIN_MACOSX" and line.startswith("version "):
            versions.append(line.split()[1])
    return versions


def version_tuple(version):
    parts = tuple(int(piece) for piece in version.split("."))
    return (parts + (0, 0, 0))[:3]


def verify(bundle):
    info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
    expected = {
        "CFBundleIdentifier": "cn.laogou.dogsc.intel",
        "LSMinimumSystemVersion": "13.0",
        "SUEnableAutomaticChecks": False,
        "SUAllowsAutomaticUpdates": False,
    }
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError(f"Unexpected {key}: {info.get(key)!r}")
    if "SUFeedURL" in info:
        raise ValueError("Upstream automatic update feed must not be bundled")
    binary = bundle / "Contents/MacOS/DogSC"
    if run("lipo", "-archs", str(binary)).split() != ["x86_64"]:
        raise ValueError("The main executable must be Intel x86_64 only")
    seen = set()
    count = 0
    for path in bundle.rglob("*"):
        if not path.is_file() or path.resolve() in seen:
            continue
        seen.add(path.resolve())
        if "Mach-O" not in run("file", "-b", str(path)):
            continue
        subprocess.run(["lipo", str(path), "-verify_arch", "x86_64"], check=True)
        versions = minimum_versions(run("otool", "-arch", "x86_64", "-l", str(path)))
        if not versions:
            raise ValueError(f"Missing macOS deployment target: {path}")
        if any(version_tuple(value) > (13, 0, 0) for value in versions):
            raise ValueError(f"Embedded code requires macOS newer than 13.0: {path}: {versions}")
        count += 1
    if count == 0:
        raise ValueError("No Mach-O executables found")
    print(f"Verified {count} Intel Mach-O files; deployment floor <= macOS 13.0; update feed isolated.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: verify-intel-bundle.py /path/to/DogSC-Intel.app")
    try:
        verify(pathlib.Path(sys.argv[1]))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
