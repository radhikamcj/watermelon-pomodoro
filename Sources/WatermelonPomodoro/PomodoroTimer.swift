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
    /// One bite comes out of the watermelon for every half hour a session has been running.
    static let biteSeconds = 30 * 60
    static let maxBites = 3

    @Published private(set) var mode: TimerMode = .focus
    @Published private(set) var remaining = 0
    @Published private(set) var isRunning = false
    @Published private(set) var slicesToday = 0
    /// Bumped every time a session ends, to kick off the celebration.
    @Published private(set) var celebrationCount = 0
    /// Bites taken out of the watermelon so far this session (0...3).
    @Published private(set) var bites = 0

    private var ticker: Timer?
    private var endDate: Date?
    /// What the timer was last set to, so Reset can go back to it.
    private var setSeconds = 0
    /// The current session's full length, including any – / + along the way.
    private var sessionSeconds = 0 {
        didSet { updateBites() }
    }

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
        sessionSeconds = setSeconds
    }

    func setMinutes(_ minutes: Int, for target: TimerMode) {
        pause()
        mode = target
        setSeconds = minutes * 60
        remaining = setSeconds
        sessionSeconds = setSeconds
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
        sessionSeconds += remaining - old
    }

    private func updateBites() {
        let eaten = min(Self.maxBites, max(0, (sessionSeconds - remaining) / Self.biteSeconds))
        if eaten != bites { bites = eaten }
    }

    // MARK: - Ticking

    private func tick() {
        guard let endDate else { return }
        let left = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if left != remaining {
            remaining = left
            updateBites()
        }
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
        sessionSeconds = 0
        celebrate()
    }

    /// Dev helper for snapshots: a session of `total` minutes with `elapsed` minutes gone.
    func preview(total: Int, elapsed: Int) {
        setMinutes(total, for: .focus)
        remaining = (total - elapsed) * 60
        updateBites()
    }
}
