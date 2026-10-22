import Foundation

/// AppKit/Foundation callbacks can arrive on the main thread without a Swift
/// executor context on Ventura. Enter the actor instead of asserting one.
/// Notification payloads must be projected to Sendable values before this call.
enum MainActorCallback {
    nonisolated static func perform(
        _ action: @escaping @MainActor @Sendable () -> Void
    ) {
        Task { @MainActor in action() }
    }
}
