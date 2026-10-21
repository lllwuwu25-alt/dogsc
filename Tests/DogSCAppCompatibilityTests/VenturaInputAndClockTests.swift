import AppKit
import SwiftUI
import XCTest
@testable import DogSCApp

final class VenturaInputAndClockTests: XCTestCase {
    @MainActor
    func testUnrequestedKeysAndIgnoredActionsPassThrough() {
        var calls = 0
        let dispatch = VenturaKeyDispatch(keys: [.upArrow, .downArrow], phases: .down) { _ in
            calls += 1
            return .ignored
        }
        XCTAssertFalse(dispatch.handle(keyCode: 123, isRepeat: false, flags: []))
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(dispatch.handle(keyCode: 126, isRepeat: false, flags: []))
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testDownOnlyHandlerRejectsRepeatedKeys() {
        var calls = 0
        let dispatch = VenturaKeyDispatch(keys: [.return], phases: .down) { _ in
            calls += 1
            return .handled
        }
        XCTAssertFalse(dispatch.handle(keyCode: 36, isRepeat: true, flags: []))
        XCTAssertEqual(calls, 0)
        XCTAssertTrue(dispatch.handle(keyCode: 36, isRepeat: false, flags: []))
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testUnchangedStateDoesNotStarveTheVenturaTimer() async throws {
        let clock = VenturaTimerFrameClock()
        let probe = FrameProbe()
        clock.onTick = { _, _ in probe.frames += 1 }
        clock.add(to: .main, forMode: .common)
        let churn = Timer(timeInterval: 0.002, repeats: true, block: MainActorTimerCallback.make {
            probe.updates += 1
            clock.isPaused = false
            clock.preferredFramesPerSecond = 60
        })
        RunLoop.main.add(churn, forMode: .common)
        defer { churn.invalidate(); clock.invalidate() }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertGreaterThan(probe.updates, 5)
        XCTAssertGreaterThanOrEqual(probe.frames, 2)
    }

    @MainActor
    func testRestartDiscardsTicksQueuedByAnOlderTimerGeneration() async throws {
        let clock = VenturaTimerFrameClock()
        let probe = FrameProbe()
        clock.onTick = { _, _ in probe.frames += 1 }
        clock.add(to: .main, forMode: .common)
        let raw = Timer(timeInterval: 0.005, target: probe,
            selector: #selector(FrameProbe.noteRawTick(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(raw, forMode: .common)
        defer { raw.invalidate(); clock.invalidate() }
        // Pump raw Foundation timers without yielding this actor job. Their
        // MainActor Tasks are pending when pause invalidates the generation.
        pumpFoundationTimers()
        XCTAssertGreaterThan(probe.updates, 0, "The raw timer must actually fire during the pump")
        clock.isPaused = true
        clock.preferredFramesPerSecond = 1
        clock.isPaused = false
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(probe.frames, 0)
    }

    @MainActor
    private func pumpFoundationTimers() {
        // Keep this deliberate test-only run-loop pump in a synchronous
        // boundary: CFRunLoopRunInMode is annotated noasync by the SDK.
        CFRunLoopRunInMode(.defaultMode, 0.06, false)
    }

    @MainActor
    func testVenturaClockTicksInsideAppKitModalLoop() async throws {
        let probe = ModalClockProbe()
        let entry = Timer(timeInterval: 0.01, target: probe,
            selector: #selector(ModalClockProbe.enterModal(_:)), userInfo: nil, repeats: false)
        RunLoop.main.add(entry, forMode: .default)
        defer { entry.invalidate(); probe.clock.invalidate() }
        for _ in 0..<300 where !probe.finished {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(probe.finished, "Modal-loop probe did not finish")
        XCTAssertGreaterThanOrEqual(probe.ticksInsideModalLoop, 3)
    }
}

@MainActor
private final class FrameProbe: NSObject {
    var frames = 0
    var updates = 0

    @objc func noteRawTick(_ timer: Timer) { updates += 1 }
}

@MainActor
private final class ModalClockProbe: NSObject {
    let clock = VenturaTimerFrameClock()
    var finished = false
    var ticksInsideModalLoop = 0

    @objc func enterModal(_ entry: Timer) {
        let app = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 160, height: 80),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        var ticks = 0
        clock.onTick = { _, _ in
            ticks += 1
            if ticks == 3 { app.stopModal() }
        }
        clock.add(to: .main, forMode: .modalPanel)
        let safety = Timer(timeInterval: 1.5, target: self,
            selector: #selector(timeout(_:)), userInfo: nil, repeats: false)
        RunLoop.main.add(safety, forMode: .modalPanel)
        app.runModal(for: window)
        ticksInsideModalLoop = ticks
        clock.invalidate()
        safety.invalidate()
        window.orderOut(nil)
        finished = true
    }

    @objc private func timeout(_ timer: Timer) {
        NSApplication.shared.stopModal()
    }
}
