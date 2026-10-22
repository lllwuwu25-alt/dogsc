# Intel compatibility validation record

Baseline: upstream v0.1.8, 567fd6ed3bf113227dcf3e815f87ce60f0b69497.
Target: Intel x86_64, macOS 13.0+; intended hardware is a 2017 Intel MacBook Pro on Ventura 13.7.4.

## Application build 21: AppKit notification crash repair

The target Ventura 13.7.4 report confirms application build 20 and identifies a
SIGILL in `FirstUseTourController.observe`, closure 5, while AppKit delivers
application deactivation. This is a legacy callback executor assertion; the
report does not identify a video encoder failure.

- Void Foundation/AppKit notification and animation callbacks now use an explicit MainActor task.
- Guide/window observer generations and originating popover identities discard obsolete queued callbacks after a window or panel is replaced.
- Synchronous event filters and RunLoop modal entry use a narrowly scoped main-thread-checked bridge, retaining their immediate return and modal-loop behavior. The bridge uses Swift's nonescaping closure-erasure pattern after its thread precondition; it is not available as an unchecked background-thread entry.
- The real-notification regression compiled successfully with the old assertion implementation and exited with SIGILL (-4) in run 19: https://github.com/lllwuwu25-alt/dogsc/actions/runs/39698352553.
- Positive notification delivery, background-thread rejection, guide rebind state, popover replacement, existing modal-loop and keyboard tests are included in the new validation run: https://github.com/lllwuwu25-alt/dogsc/actions/runs/39699546499.

Cloud validation succeeded for source `a60c381623aeb0dd0ebe669438e16cdf76d4bc3e`:
4 Python tests, 13 XCTest cases with zero failures, Release build and all bundle
checks passed. The downloaded DMG and application ZIP matched the published
SHA-256 digests. The application is x86_64, CFBundleVersion 21, minimum macOS 13.0,
with ad-hoc signature flags 2 (no hardened runtime).

Release: https://github.com/lllwuwu25-alt/dogsc/releases/tag/intel-app-build-21-source
DMG SHA-256: `7de34ac96991c66d700f4112b93e476eff9ae9ae211882f2c53e8638a1069bd1`.
ZIP SHA-256: `5a31618a8d55f317b2a6b0d9cb5d7ef320ec39dd1c3a424699d61c795960598d`.
The release tag is aligned to the validated source commit; application source
and the packaged build agree. Target Ventura recording, audio and export still
require the user's Mac.

## Recording-start timer crash: Intel application build 20

The Ventura report for application build 19 / workflow build 6 identifies a
SIGILL in `MainActor.assumeIsolated` from
`PointerEventRecorder.installCursorShapeTimer()`. Foundation invoked the timer
on the main thread without the Swift executor context that assertion required.

All four Foundation timer callbacks that used this assertion now enter an
explicit MainActor task: both pointer timers, the Ventura preview clock and the
settings height animation. Generation checks discard work queued before a
recording stops/restarts or a clock pauses/reschedules/invalidates.

The standalone regression compiles the real callback helper, invokes it from a
detached task and verifies delivery on MainActor. The original assertion-based
implementation reproducibly exited with SIGILL (-4) in workflow run 9:
https://github.com/lllwuwu25-alt/dogsc/actions/runs/39610188194.
After the explicit actor hop, the same probe passes in workflow run 16:
https://github.com/lllwuwu25-alt/dogsc/actions/runs/39613591663.

The Swift suite additionally checks stale queued ticks after pause/restart at a
new cadence, and real Ventura preview-clock ticks inside an AppKit modal loop.
Workflow run 16 completed successfully for source
`67f9fa62b5b77ba461ab3f9ef8ebb82f4290b13c` on macos-15-intel, Xcode 26.3:

- Python packaging and actual Swift actor-callback probe: 3 passed.
- Swift XCTest cases: 11 passed, zero failures, including both new clock lifecycle/modal-loop cases.
- Release compilation, deep/strict ad-hoc signature verification and validation of 6 Intel Mach-O files with deployment floor at or below macOS 13.0: passed.
- Public installer release: https://github.com/lllwuwu25-alt/dogsc/releases/tag/intel-build-16. Application CFBundleVersion is 20; the release tag identifies workflow run 16.

Ventura recording/export validation still requires the target Mac.

## Earlier successful macOS build (before the timer repair)

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
