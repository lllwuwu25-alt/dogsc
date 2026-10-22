import Foundation

/// Boundary for UI side effects delivered by legacy framework callbacks.
enum MainActorCallback {
    nonisolated static func perform(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) {
        MainActor.assumeIsolated { action() }
    }
}
