import Foundation

/// Foundation timers do not guarantee a Swift actor execution context.
enum MainActorTimerCallback {
    nonisolated static func make(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> @Sendable (Timer) -> Void {
        { _ in
            MainActor.assumeIsolated { action() }
        }
    }
}
