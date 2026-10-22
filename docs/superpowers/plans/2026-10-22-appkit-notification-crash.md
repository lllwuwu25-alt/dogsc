# AppKit notification crash implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix build 20's confirmed Ventura SIGILL in FirstUseTourController.observe, retaining recording and keyboard behavior.

**Architecture:** Void AppKit/Foundation callbacks explicitly schedule their UI side effects on MainActor. Synchronous event filtering keeps its return-value contract and is audited separately. A standalone Swift regression drives the production boundary from a real Foundation notification posted outside an actor; AppKit XCTest covers the actual guide with a mounted host.

**Tech Stack:** Swift 6, AppKit, Foundation, Python unittest, GitHub macos-15-intel.

**Spec:** User's 2026-10-22 build 20 crash report and this plan. Existing authorization covers inline fixes and public fork builds; raw reports remain private.

## Global constraints

- Intel x86_64, macOS 13.0+, intended Ventura 13.7.4 hardware.
- Keep cn.laogou.dogsc.intel identity and existing ad-hoc signing repair.
- Do not infer that successful CI proves target-hardware recording.
- Do not disable actor checking globally or asynchronously replace event handlers that must return synchronously.

## Review focus

- App deactivation while capture startup is suspended must not crash.
- Window close/rebind must not apply an obsolete tour callback to a replacement host.
- Notification payloads must not cross the actor boundary without projection to Sendable values.
- Animation completion must still run exactly once; no reference cycle from a repeating callback.
- A modal dialog must continue processing AppKit actions rather than nesting under a Dispatch main-queue work item.

## Task 1: Notification/void callback boundary

- [ ] Add a standalone real-notification regression using the production boundary, preserving the old assertion behavior for its negative run.
- [ ] Run the probe on macOS and confirm SIGILL for the assertion implementation.
- [ ] Implement MainActorCallback.perform(_ action: @escaping @MainActor @Sendable () -> Void) using an explicit Task hop.
- [ ] Replace void actor assertions at legacy callback boundaries; keep synchronous return paths separate. Guard guide callbacks by observation generation.
- [ ] Add actual-guide AppKit regression for deactivation and close/rebind. Check all original XCTest and packaging tests, then Release compilation and bundle verification.
- [ ] Review, commit, publish build 21, verify downloaded installer metadata/digests and deliver with remaining hardware validation stated.
