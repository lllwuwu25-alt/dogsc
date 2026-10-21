import Foundation

@MainActor
private final class Probe {
    var calls = 0
}

@main
private enum Main {
    @MainActor
    static func main() async throws {
        let probe = Probe()
        let callback = MainActorTimerCallback.make {
            precondition(Thread.isMainThread)
            probe.calls += 1
        }
        // Foundation owns the callback context, not a Swift actor. Invoke it
        // outside MainActor to expose any accidental assumeIsolated reliance.
        await Task.detached {
            let timer = Timer(timeInterval: 1, repeats: false) { _ in }
            callback(timer)
        }.value
        for _ in 0..<200 where probe.calls == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(probe.calls == 1)
        print("Timer callback reached MainActor")
    }
}
