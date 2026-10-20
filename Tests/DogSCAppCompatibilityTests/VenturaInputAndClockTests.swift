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
        let churn = Timer(timeInterval: 0.002, repeats: true) { _ in
            MainActor.assumeIsolated {
                probe.updates += 1
                clock.isPaused = false
                clock.preferredFramesPerSecond = 60
            }
        }
        RunLoop.main.add(churn, forMode: .common)
        defer { churn.invalidate(); clock.invalidate() }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertGreaterThan(probe.updates, 5)
        XCTAssertGreaterThanOrEqual(probe.frames, 2)
    }
}

@MainActor
private final class FrameProbe {
    var frames = 0
    var updates = 0
}
