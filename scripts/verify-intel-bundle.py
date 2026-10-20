#!/usr/bin/env python3
"""Reject wrong-CPU builds, broken code signatures, or embedded code that
raises the deployment floor."""
import pathlib
import plistlib
import re
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


def signature_summary(path):
    """Return (TeamIdentifier, set of code directory flags) for signed code."""
    result = subprocess.run(
        ["codesign", "-d", "--verbose=4", str(path)],
        capture_output=True,
        text=True,
    )
    text = result.stderr
    team = re.search(r"^TeamIdentifier=(.+)$", text, re.MULTILINE)
    flags = re.search(
        r"^CodeDirectory .*?flags=0x[0-9a-f]+\(([^)]*)\)", text, re.MULTILINE
    )
    return (
        team.group(1).strip() if team else "unknown",
        {flag for flag in flags.group(1).split(",")} if flags and flags.group(1) else set(),
    )


def entitlements(path):
    """Return the entitlements of signed code as a dictionary."""
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(path)],
        capture_output=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return {}
    try:
        return plistlib.loads(result.stdout)
    except plistlib.InvalidFileException:
        return {}


def verify_signatures(bundle):
    """Catch the ad-hoc + hardened-runtime mix that dyld refuses to load.

    Hardened runtime sets CS_REQUIRE_LV, so dyld only loads libraries carrying
    the process's Team ID. An ad-hoc process has no Team ID, so the bundled
    Sparkle.framework is rejected at launch with "mapped file has no Team ID
    and is not a platform binary" and the app dies before main(). Opting out
    with com.apple.security.cs.disable-library-validation is accepted.
    """
    team, flags = signature_summary(bundle)
    library_validation_disabled = entitlements(bundle).get(
        "com.apple.security.cs.disable-library-validation"
    ) is True
    if (
        team in ("not set", "unknown")
        and "runtime" in flags
        and not library_validation_disabled
    ):
        raise ValueError(
            "Ad-hoc signature carries the hardened runtime, which blocks dyld "
            "from loading the bundled Sparkle.framework at launch. Sign ad-hoc "
            "without --options runtime, or use a Developer ID identity for "
            "every component."
        )
    sparkle = bundle / "Contents/Frameworks/Sparkle.framework"
    if not sparkle.is_dir() or team in ("not set", "unknown"):
        return
    for path in sorted(sparkle.rglob("*")):
        if not path.is_file() or "Mach-O" not in run("file", "-b", str(path)):
            continue
        component_team, _ = signature_summary(path)
        if component_team != team:
            raise ValueError(
                f"Bundled code is not signed by the app's team "
                f"({component_team!r} vs {team!r}): {path}"
            )


def team_description(bundle):
    team, _ = signature_summary(bundle)
    return "ad-hoc" if team in ("not set", "unknown") else team


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
    verify_signatures(bundle)
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
    print(
        f"Verified {count} Intel Mach-O files; deployment floor <= macOS 13.0; "
        f"update feed isolated; signing identity {team_description(bundle)}."
    )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: verify-intel-bundle.py /path/to/DogSC-Intel.app")
    try:
        verify(pathlib.Path(sys.argv[1]))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
