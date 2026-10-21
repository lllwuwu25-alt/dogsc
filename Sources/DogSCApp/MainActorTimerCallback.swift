import Foundation

/// Foundation timers do not guarantee a Swift actor execution context.
/// Callers validate their current timer generation after this asynchronous hop.
enum MainActorTimerCallback {
    nonisolated static func make(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> @Sendable (Timer) -> Void {
        { _ in
            Task { @MainActor in action() }
        }
    }
}
