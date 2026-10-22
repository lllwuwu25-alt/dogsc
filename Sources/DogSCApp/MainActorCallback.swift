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

    /// Only for synchronous AppKit main-thread callbacks: event filtering and
    /// modal RunLoop entry cannot be deferred. Ventura does not reliably expose
    /// the executor identity there. Keep the main-thread precondition and the
    /// nonescaping closure-erasure pattern used by Swift's assumeIsolated.
    /// Never use this for callbacks without a documented main-thread contract.
    nonisolated static func syncOnMainThread<Result>(
        _ action: @MainActor () throws -> Result
    ) rethrows -> Result {
        precondition(Thread.isMainThread,
            "AppKit synchronous callback requires the main thread")
        return try withoutActuallyEscaping(action) { isolated in
            let synchronous = unsafeBitCast(isolated, to: (() throws -> Result).self)
            return try synchronous()
        }
    }
}
