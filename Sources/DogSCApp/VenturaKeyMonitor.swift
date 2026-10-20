import AppKit
import SwiftUI

@MainActor
struct VenturaKeyDispatch {
    let keys: Set<DogSCKeyEquivalent>
    let phases: DogSCKeyPress.Phases
    let action: (DogSCKeyPress) -> DogSCKeyPress.Result

    /// True means this exact handler consumed the key. Every other result
    /// leaves the original event in AppKit's responder chain.
    func handle(keyCode: UInt16, isRepeat: Bool, flags: NSEvent.ModifierFlags) -> Bool {
        if isRepeat && !phases.contains(.repeating) { return false }
        if !isRepeat && !phases.contains(.down) { return false }
        let key: DogSCKeyEquivalent
        switch keyCode {
        case 36, 76: key = .return
        case 123: key = .leftArrow
        case 124: key = .rightArrow
        case 125: key = .downArrow
        case 126: key = .upArrow
        default: return false
        }
        guard keys.contains(key) else { return false }
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return action(DogSCKeyPress(key: key, modifiers: modifiers)) == .handled
    }
}

/// A local monitor exists only while this control has keyboard focus. It
/// checks the owning window, ignores text editors, and returns unhandled
/// events unchanged. It neither reads characters nor observes other apps.
struct VenturaKeyMonitor: NSViewRepresentable {
    let active: Bool
    let dispatch: VenturaKeyDispatch

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView(frame: .zero)
        view.configure(active: active, dispatch: dispatch)
        return view
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.configure(active: active, dispatch: dispatch)
    }

    static func dismantleNSView(_ view: ObserverView, coordinator: ()) {
        view.disconnect()
    }

    final class ObserverView: NSView {
        private var active = false
        private var dispatch: VenturaKeyDispatch?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            refreshMonitor()
        }

        func configure(active: Bool, dispatch: VenturaKeyDispatch) {
            self.active = active
            self.dispatch = dispatch
            refreshMonitor()
        }

        func disconnect() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func refreshMonitor() {
            guard active, window != nil else { disconnect(); return }
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    guard let self, self.active, let window = self.window,
                          event.window === window,
                          !(window.firstResponder is NSTextView),
                          !event.targetsPresentedContent else { return false }
                    return self.dispatch?.handle(keyCode: event.keyCode,
                        isRepeat: event.isARepeat, flags: event.modifierFlags) ?? false
                }
                return handled ? nil : event
            }
        }
    }
}
