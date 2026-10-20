# Intel Ventura compatibility implementation plan

Goal: preserve DogSC v0.1.8 on x86_64 macOS 13.7.4, with a separate application identity.

Approved approach: the user said “开始吧” after reviewing the Intel + macOS 13 compatibility route. Work inline in the fresh `compat/intel-ventura` checkout. No upstream publishing or unrelated repository changes.

## Tasks

- [x] Add compatibility adapters for change observation, keyboard commands, focus styling, animation, rounded shapes and frame clocks. Keep native implementations when available.
- [x] Backport ScreenCaptureKit geometry, AVFoundation device discovery and language observation. Preserve explicit recording targets and the existing system-audio fallback.
- [x] Add a reproducible x86_64 build script and an Intel GitHub Actions workflow. Isolate bundle preferences, disable the upstream ARM update feed, sign locally, and verify architecture and deployment floor before packaging.
- [x] Run Linux-side packaging checks and source review. Provide macOS XCTest coverage for geometry and spring continuity, and make the macOS compiler/build a required workflow step.
- [x] Obtain a macOS build run before calling the app usable. This Linux environment cannot compile AppKit/SwiftUI or run Ventura. Browser fallback for creating a GitHub fork requires user approval because the connected GitHub plugin has no fork/create-repository capability.

## Validation

- Python tests exercise actual staging-plist conversion, preservation of unrelated metadata, repeatability, and missing-bundle handling.
- XCTest checks Retina and mixed-display geometry, invalid scale inputs, and retargetable spring motion.
- `bash -n`, Python tests, and `git diff --check` run here.
- The Intel macOS workflow must run `swift test`, build, verify x86_64 plus a 13.0 deployment target, and verify signing before uploading artifacts.
- A successful modern macOS build does not substitute for the user's Ventura recording/audio/save/reopen/export smoke test.

## Progress

Source baseline: tag v0.1.8, commit 567fd6ed3bf113227dcf3e815f87ce60f0b69497. No pre-existing changes or AGENTS.md. Swift/Xcode are unavailable in the current Linux runtime.

Independent review: three Important findings (Quartz array ABI, timer restarts, key propagation). Source fixes and macOS regression tests added; compiler and runtime validation remain gated on macOS.

Completed cloud build: https://github.com/lllwuwu25-alt/dogsc/actions/runs/39417629168 (2026-10-20). Release build, 9 Swift tests, 2 Python tests, signatures, Intel deployment floor and installer checks passed. Target Ventura hardware smoke testing remains manual.
