import AppKit
import SwiftUI
import XCTest
@testable import DogSCApp

final class LegacyNotificationTests: XCTestCase {
    @MainActor
    func testMountedGuideSurvivesApplicationAndWindowNotificationsAfterRebinding() async throws {
        _ = NSApplication.shared
        let guide = FirstUseTourController.controller(for: .recorder)
        guide.prepareReplay()
        let first = mountGuide()
        // Posting after mounting exercises the controller's actual observers,
        // including the exact app-deactivation callback in the Ventura report.
        for name in [NSApplication.didResignActiveNotification,
                     NSApplication.didHideNotification,
                     NSApplication.didBecomeActiveNotification,
                     NSWindow.didResizeNotification] {
            NotificationCenter.default.post(name: name,
                object: name == NSWindow.didResizeNotification ? first : NSApp)
        }
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: first)
        // Dismantle the host before queued resume work runs, then bind a new owner.
        first.contentView = nil
        first.close()
        let second = mountGuide()
        defer { second.contentView = nil; second.close() }
        guide.suspend()
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        try await Task.sleep(for: .milliseconds(100))
        // No new activation has occurred. A stale old-owner resume must not
        // unsuspend the replacement. Reflection keeps test probes out of the app.
        let suspended = Mirror(reflecting: guide).children.first { $0.label == "isSuspended" }?.value as? Bool
        XCTAssertEqual(suspended, true)
        XCTAssertNotNil(second.contentView)
        XCTAssertTrue(second.contentView?.window === second)
    }

    @MainActor
    func testQueuedOwnerNotificationCannotDismissReplacementPopover() async throws {
        _ = NSApplication.shared
        let owner = NSWindow(contentRect: NSRect(x: 50, y: 50, width: 200, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        let anchor = NSView(frame: NSRect(x: 10, y: 10, width: 40, height: 30))
        owner.contentView = anchor
        owner.orderFront(nil)
        let presenter = RecorderPopoverPresenter()
        defer { presenter.dismiss(); owner.close() }
        presenter.toggle(id: "regression.first", anchor: anchor, content: AnyView(Text("First")), width: 180)
        XCTAssertTrue(owner.childWindows?.contains { $0.identifier?.rawValue == "recorder.popover.regression.first" } == true)
        NotificationCenter.default.post(name: NSWindow.didMoveNotification, object: owner)
        presenter.toggle(id: "regression.replacement", anchor: anchor, content: AnyView(Text("Replacement")), width: 180)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(owner.childWindows?.contains { $0.identifier?.rawValue == "recorder.popover.regression.replacement" && $0.isVisible } == true)
    }

    @MainActor
    private func mountGuide() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView:
            Color.clear.frame(width: 200, height: 100).firstUseTour(.recorder, enabled: false))
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }
}
