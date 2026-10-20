# Intel compatibility validation record

Baseline: upstream v0.1.8, 567fd6ed3bf113227dcf3e815f87ce60f0b69497.
Target: Intel x86_64, macOS 13.0+; intended hardware is a 2017 Intel MacBook Pro on Ventura 13.7.4.

## Successful macOS build

- Workflow: https://github.com/lllwuwu25-alt/dogsc/actions/runs/39417629168
- Tested source: 655a4d4981df155bf2dbf0f5a97910e628606f5b.
- Host: GitHub macos-15-intel, Xcode 26.3, Swift 6.2.4.
- Python packaging integration tests: 2 passed.
- Swift XCTest cases: 9 passed, zero failures (geometry, spring continuity, raw Quartz window IDs, key propagation/repeat filtering, and timer cadence).
- Release compilation and linking: passed.
- Ad-hoc codesign verification with --deep --strict: passed.
- Architecture/deployment validation: 6 Intel Mach-O files checked; main executable is x86_64 only and all embedded Intel code has a deployment floor at or below macOS 13.0.
- Independent bundle identity and upstream ARM update-feed removal: verified.
- DMG and application ZIP produced. Downloaded artifact ZIP and both packaged files matched their SHA-256 checksums.

The compiler emits NSImage Sendable availability and SendableMetatypes warnings. These did not prevent compilation or the test suite; they are not evidence of Ventura runtime validation.

## Review fixes

Independent reviews identified and resolved the Quartz raw-ID array ABI, timer deadline resets, key-event propagation, and a main-actor-inherited modern camera closure. Native camera callbacks are now formed in an explicitly nonisolated factory; Ventura display-layer operations stay on main.

## Still requires target hardware

Follow README-INTEL.md for full-screen/window/region recording, system and microphone audio, camera/device capture, save/reopen/export, focus/keyboard handling, language refresh and preview lifecycle checks. A successful macOS 15 build does not substitute for Ventura hardware testing.
