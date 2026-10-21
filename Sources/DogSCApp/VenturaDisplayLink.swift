import AppKit
import QuartzCore

/// Native display pacing on Sonoma+, and a bounded, pausable main-run-loop
/// clock on Ventura. Paused previews keep no repeating timer alive.
@MainActor
final class DogSCDisplayLink: NSObject {
    private weak var target: NSObject?
    private let selector: Selector
    private var native: AnyObject?
    private let legacy = VenturaTimerFrameClock()
    private var invalidated = false
    private(set) var timestamp: CFTimeInterval = 0
    private(set) var targetTimestamp: CFTimeInterval = 0

    var isPaused = false {
        didSet {
            guard oldValue != isPaused else { return }
            if #available(macOS 14.0, *), let link = native as? CADisplayLink {
                link.isPaused = isPaused
            } else {
                legacy.isPaused = isPaused
            }
        }
    }

    var preferredFramesPerSecond = 60 {
        didSet {
            guard oldValue != preferredFramesPerSecond else { return }
            if #available(macOS 14.0, *), let link = native as? CADisplayLink {
                let rate = Float(max(preferredFramesPerSecond, 1))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
            } else {
                legacy.preferredFramesPerSecond = preferredFramesPerSecond
            }
        }
    }

    init(window: NSWindow, target: NSObject, selector: Selector) {
        self.target = target
        self.selector = selector
        super.init()
        connectLegacyClock()
        if #available(macOS 14.0, *) {
            native = window.displayLink(target: self, selector: #selector(nativeTick(_:)))
        }
    }

    init(screen: NSScreen, target: NSObject, selector: Selector) {
        self.target = target
        self.selector = selector
        super.init()
        connectLegacyClock()
        if #available(macOS 14.0, *) {
            native = screen.displayLink(target: self, selector: #selector(nativeTick(_:)))
        }
    }

    func add(to runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        guard !invalidated else { return }
        if #available(macOS 14.0, *), let link = native as? CADisplayLink {
            link.add(to: runLoop, forMode: mode)
        } else {
            legacy.add(to: runLoop, forMode: mode)
        }
    }

    func invalidate() {
        invalidated = true
        if #available(macOS 14.0, *) { (native as? CADisplayLink)?.invalidate() }
        native = nil
        legacy.invalidate()
        target = nil
    }

    @available(macOS 14.0, *)
    @objc private func nativeTick(_ link: CADisplayLink) {
        timestamp = link.timestamp
        targetTimestamp = link.targetTimestamp
        fire()
    }

    private func connectLegacyClock() {
        legacy.onTick = { [weak self] timestamp, targetTimestamp in
            guard let self else { return }
            self.timestamp = timestamp
            self.targetTimestamp = targetTimestamp
            self.fire()
        }
    }

    private func fire() {
        guard !invalidated, !isPaused, let target else { return }
        _ = target.perform(selector, with: self)
    }
}

/// Independent of the modern display-link backend, so the actual Ventura
/// scheduler can also be exercised by tests on a newer macOS build host.
@MainActor
final class VenturaTimerFrameClock {
    var onTick: (@MainActor (CFTimeInterval, CFTimeInterval) -> Void)?
    private var timer: Timer?
    private var runLoop: RunLoop?
    private var modes = Set<RunLoop.Mode>()
    private var invalidated = false
    private var timerGeneration: UInt64 = 0

    var isPaused = false {
        didSet {
            guard oldValue != isPaused else { return }
            reschedule()
        }
    }

    var preferredFramesPerSecond = 60 {
        didSet {
            guard oldValue != preferredFramesPerSecond else { return }
            reschedule()
        }
    }

    func add(to runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        guard !invalidated else { return }
        if let previous = self.runLoop, previous !== runLoop {
            timer?.invalidate()
            timer = nil
            modes.removeAll()
        }
        self.runLoop = runLoop
        guard modes.insert(mode).inserted else { return }
        if let timer { runLoop.add(timer, forMode: mode) }
        else { reschedule() }
    }

    func invalidate() {
        timerGeneration &+= 1
        invalidated = true
        timer?.invalidate()
        timer = nil
        modes.removeAll()
        runLoop = nil
        onTick = nil
    }

    private func reschedule() {
        timerGeneration &+= 1
        timer?.invalidate()
        timer = nil
        guard !invalidated, !isPaused, let runLoop, !modes.isEmpty else { return }
        let interval = 1.0 / Double(min(max(preferredFramesPerSecond, 1), 60))
        let generation = timerGeneration
        let timer = Timer(timeInterval: interval, repeats: true, block: MainActorTimerCallback.make { [weak self] in
            guard let self, self.timerGeneration == generation,
                  !self.invalidated, !self.isPaused else { return }
            let timestamp = CACurrentMediaTime()
            self.onTick?(timestamp, timestamp + interval)
        })
        timer.tolerance = interval * 0.05
        for mode in modes { runLoop.add(timer, forMode: mode) }
        self.timer = timer
    }
}
