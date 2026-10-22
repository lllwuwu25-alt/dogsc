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
        let center = NotificationCenter()
        let name = Notification.Name("DogSC.MainActorCallback.Regression")
        let token = center.addObserver(forName: name, object: nil, queue: nil) { _ in
            MainActorCallback.perform {
                precondition(Thread.isMainThread)
                probe.calls += 1
            }
        }
        defer { center.removeObserver(token) }
        // Foundation, like AppKit on Ventura, owns the delivery context. The
        // notification object itself is never sent into the UI actor task.
        await Task.detached { center.post(name: name, object: nil) }.value
        for _ in 0..<200 where probe.calls == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(probe.calls == 1)
        print("Notification callback reached MainActor exactly once")
    }
}
