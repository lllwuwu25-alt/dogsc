# Intel compatibility validation record

Baseline: upstream v0.1.8, 567fd6ed3bf113227dcf3e815f87ce60f0b69497.
Target hardware: 2017 Intel MacBook Pro, Ventura 13.7.4.

## Executed in this session

- Packaging metadata integration tests: 2 passing. Before implementing the staging helper both tests failed because the helper did not exist.
- Shell syntax: build-intel.sh passes bash -n.
- Workflow YAML: parsed, target runner macos-15-intel, explicit Xcode 26.3, read-only repository permissions.
- Swift grammar comparison: source is checked against the upstream grammar baseline using tree-sitter-swift. This is a syntax check, not type checking or compilation; upstream Swift grammar constructs not understood by that parser remain baseline findings.
- Architecture/update/minimum-OS verification is implemented as a required macOS packaging step, not reported as executed here.

## Pending

- Swift/Xcode type checking and Release build; Linux has neither Xcode nor the Apple SDK.
- Core and app XCTest execution (Retina, mixed-display geometry, spring continuity and raw Quartz window-ID array representation).
- Actual Mach-O deployment-floor checks and codesign verification against a built app.
- Ventura hardware recording/audio/save/reopen/export and keyboard/localization checks from README-INTEL.md.

## Implementation decisions

- Use a separate cn.laogou.dogsc.intel app identity and remove upstream update credentials/feed in the staged bundle. This avoids automatically installing the upstream ARM build.
- Prefer native APIs on supported OS releases. On Ventura, install an app-local key monitor only while its control has focus. Scope it to the owning window, exclude text editors, and pass unrequested/ignored/repeating-down-only events through unchanged.
- Use a pausable 60 Hz run-loop clock where CADisplayLink is unavailable. Render/export resolution and export frame-rate controls remain separate.
- Visual cleanup completion uses bounded delays only on Ventura, with existing revision guards retained. Recording and project writes do not use these timers.
- Preserve explicit display, window and device identity. Legacy display selection affects pixel scale only.

No usable DMG or successful macOS build is claimed by this record.

Checkpoint after review fixes: 298 Swift files compared to upstream, no new parser issue groups; 2/2 Python integration tests pass; shell syntax and diff whitespace checks pass. Nine macOS XCTest cases are prepared but have not run.

Independent review found a Ventura thumbnail ABI issue in the first pass: an NSNumber array was passed to a Quartz API that expects raw window IDs. The source now constructs a nil-callback Core Foundation array of raw IDs. Two macOS regression tests pin the representation; they are pending the compiler run.

Independent review also identified timer deadline resets and key-event propagation issues. The timer now skips unchanged state/cadence assignments and is independently testable. Keyboard dispatch now preserves ignored results and repeat-phase filtering. Three additional macOS tests cover these behaviors; like the other Swift tests, they have not run in this Linux environment.
