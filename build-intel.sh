#!/bin/bash
# Build on a Mac with Xcode 26.3+. The resulting app targets Intel Ventura.
set -euo pipefail
cd "$(dirname "$0")"
project_root="$PWD"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "A macOS/Xcode build host is required. Use the Intel Ventura GitHub Actions workflow." >&2
  exit 1
fi
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export MACOSX_DEPLOYMENT_TARGET=13.0
identity="${DOGSC_SIGNING_IDENTITY:--}"
output_dir="${DOGSC_OUTPUT_DIR:-$project_root/dist/intel}"
scratch_dir="$project_root/.build/intel"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp/}dogsc-intel.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
app="$staging_dir/DogSC Intel.app"

# The hardened runtime sets the library-validation flag, so dyld loads only
# libraries that carry the same Team ID. An ad-hoc signature ("-") has no Team
# ID at all, which makes dyld reject our own Sparkle.framework at launch:
#   Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle
#   mapped file has no Team ID and is not a platform binary
# so hardened runtime is requested only for a real identity, where every
# component is re-signed with that identity's Team ID anyway.
sign_code() {
  if [[ "$identity" == "-" ]]; then
    codesign --force --sign - "$@"
  else
    codesign --force --options runtime --timestamp --sign "$identity" "$@"
  fi
}

# Ventura ships an older Swift runtime than the one Xcode 26.3 compiles
# against. With the system dylib, MainActor.assumeIsolated traps inside AppKit
# callbacks ("Incorrect actor executor assumption") and the app dies on the
# first monitor/key/timer callback, e.g. the moment recording starts. Linking
# the toolchain's stdlib statically keeps compiler and runtime in sync.
xcrun swift build -c release --scratch-path "$scratch_dir" \
  --triple x86_64-apple-macosx13.0 --static-swift-stdlib --product DogSC
binary_dir="$(xcrun swift build -c release --scratch-path "$scratch_dir" \
  --triple x86_64-apple-macosx13.0 --show-bin-path)"
sparkle="$scratch_dir/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[[ -f "$binary_dir/DogSC" && -d "$sparkle" ]]

mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks" "$app/Contents/Resources"
cp "$binary_dir/DogSC" "$app/Contents/MacOS/DogSC"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
for resource in en.lproj zh-Hans.lproj Fonts Onboarding Support; do
  ditto "Resources/$resource" "$app/Contents/Resources/$resource"
done
(cd "$app/Contents/Resources/Fonts" && shasum -a 256 -c SHA256SUMS)
ditto "$sparkle" "$app/Contents/Frameworks/Sparkle.framework"
python3 scripts/prepare-intel-bundle.py "$app"

# Embed Swift back-deployment libraries, then verify their own architecture
# and minimum OS along with the rest of the bundle.
xcrun swift-stdlib-tool --copy --scan-executable "$app/Contents/MacOS/DogSC" \
  --scan-folder "$app/Contents/Frameworks" --platform macosx \
  --destination "$app/Contents/Frameworks"
for library in "$app/Contents/Frameworks/"*.dylib; do
  [[ -f "$library" ]] || continue
  sign_code "$library"
done
framework="$app/Contents/Frameworks/Sparkle.framework"
version="$framework/Versions/B"
sign_code "$version/XPCServices/Installer.xpc"
sign_code "$version/XPCServices/Downloader.xpc" --preserve-metadata=entitlements
for component in "$version/Autoupdate" "$version/Updater.app" "$framework"; do
  sign_code "$component"
done
sign_code "$app" --entitlements Resources/DogSC.entitlements
codesign --verify --deep --strict "$app"
python3 scripts/verify-intel-bundle.py "$app"

archive="$output_dir/DogSC-Intel-v0.1.8-macOS13.zip"
disk_image="$output_dir/DogSC-Intel-v0.1.8-macOS13.dmg"
ditto -c -k --keepParent "$app" "$archive"
mkdir "$staging_dir/dmg"
ditto "$app" "$staging_dir/dmg/DogSC Intel.app"
ln -s /Applications "$staging_dir/dmg/Applications"
hdiutil create -volname "DogSC Intel" -srcfolder "$staging_dir/dmg" \
  -ov -format UDZO "$disk_image"
{
  echo "DogSC Intel / upstream v0.1.8"
  echo "Target: x86_64-apple-macosx13.0"
  echo "Bundle: cn.laogou.dogsc.intel"
  echo "Signing identity: $identity"
  git rev-parse HEAD 2>/dev/null || echo "Source archive: upstream v0.1.8 with Intel compatibility changes"
  xcrun swift --version
  xcodebuild -version
  echo "A successful build still requires the Ventura hardware smoke test in README-INTEL.md."
} > "$output_dir/BUILD-INFO.txt"
(cd "$output_dir" && shasum -a 256 \
  DogSC-Intel-v0.1.8-macOS13.dmg DogSC-Intel-v0.1.8-macOS13.zip > SHA256SUMS)
printf 'Built: %s\n' "$disk_image"
