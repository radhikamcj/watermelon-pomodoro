import AppKit
import Combine

enum TimerMode {
    case focus
    case rest

    var label: String {
        switch self {
        case .focus: return "Focus"
        case .rest: return "Break"
        }
    }
}

final class PomodoroTimer: ObservableObject {
    /// – / + change the time by this much, between 0 and `maxSeconds`.
    static let stepSeconds = 15 * 60
    static let maxSeconds = 180 * 60

    @Published private(set) var mode: TimerMode = .focus
    @Published private(set) var remaining = 0
    @Published private(set) var isRunning = false
    @Published private(set) var slicesToday = 0
    /// Bumped every time a session ends, to kick off the celebration.
    @Published private(set) var celebrationCount = 0

    private var ticker: Timer?
    private var endDate: Date?
    /// What the timer was last set to, so Reset can go back to it.
    private var setSeconds = 0

    /// MM:SS under an hour, HH:MM:SS from an hour up.
    var timeText: String {
        let hours = remaining / 3600, minutes = remaining / 60 % 60, seconds = remaining % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Controls

    var canStart: Bool { !isRunning && remaining > 0 }

    func start() {
        guard canStart else { return }
        endDate = Date().addingTimeInterval(TimeInterval(remaining))
        isRunning = true
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    func pause() {
        ticker?.invalidate()
        ticker = nil
        isRunning = false
    }

    func reset() {
        pause()
        remaining = setSeconds
    }

    func setMinutes(_ minutes: Int, for target: TimerMode) {
        pause()
        mode = target
        setSeconds = minutes * 60
        remaining = setSeconds
    }

    var canAdjustDown: Bool {
        // While running, only take off time if there's more than a step left, so it doesn't end abruptly.
        isRunning ? remaining > Self.stepSeconds : remaining > 0
    }

    var canAdjustUp: Bool {
        remaining < Self.maxSeconds
    }

    /// – / + : move the time by 15 minutes, from 00:00 up to 180:00.
    func adjust(up: Bool) {
        guard up ? canAdjustUp : canAdjustDown else { return }
        let old = remaining
        remaining = up
            ? min(Self.maxSeconds, remaining + Self.stepSeconds)
            : max(0, remaining - Self.stepSeconds)

        if isRunning, let endDate {
            self.endDate = endDate.addingTimeInterval(TimeInterval(remaining - old))
        } else {
            setSeconds = remaining
        }
    }

    // MARK: - Ticking

    private func tick() {
        guard let endDate else { return }
        let left = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if left != remaining { remaining = left }
        if left == 0 { finish() }
    }

    /// Shake + seeds + chime, without touching the timer.
    func celebrate() {
        NSSound(named: "Glass")?.play()
        celebrationCount += 1
    }

    private func finish() {
        pause()
        if mode == .focus { slicesToday += 1 }
        mode = .focus
        setSeconds = 0
        remaining = 0
        celebrate()
    }
}
