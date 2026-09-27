import AppKit
import Combine

enum TimerMode {
    case focus
    case rest

    var label: String {
        switch self {
        case .focus: return "focus time"
        case .rest: return "snack break"
        }
    }
}

final class PomodoroTimer: ObservableObject {
    @Published private(set) var mode: TimerMode = .focus
    @Published private(set) var remaining: Int
    @Published private(set) var isRunning = false
    @Published private(set) var slicesToday = 0
    @Published private(set) var justFinished = false

    @Published private(set) var focusMinutes: Int {
        didSet { UserDefaults.standard.set(focusMinutes, forKey: "focusMinutes") }
    }
    @Published private(set) var restMinutes: Int {
        didSet { UserDefaults.standard.set(restMinutes, forKey: "restMinutes") }
    }

    private var ticker: Timer?
    private var endDate: Date?

    init() {
        let defaults = UserDefaults.standard
        let focus = defaults.integer(forKey: "focusMinutes")
        let rest = defaults.integer(forKey: "restMinutes")
        focusMinutes = focus > 0 ? focus : 25
        restMinutes = rest > 0 ? rest : 5
        remaining = (focus > 0 ? focus : 25) * 60
    }

    var currentMinutes: Int { mode == .focus ? focusMinutes : restMinutes }

    var progress: Double {
        let total = Double(currentMinutes * 60)
        guard total > 0 else { return 0 }
        return 1 - Double(remaining) / total
    }

    var timeText: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    // MARK: - Controls

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        justFinished = false
        if remaining <= 0 { remaining = currentMinutes * 60 }
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
        justFinished = false
        remaining = currentMinutes * 60
    }

    func switchMode(to newMode: TimerMode) {
        pause()
        justFinished = false
        mode = newMode
        remaining = currentMinutes * 60
    }

    /// Change the length of the current mode. Only allowed while paused.
    func adjust(up: Bool) {
        guard !isRunning else { return }
        switch mode {
        case .focus:
            let step = 5
            focusMinutes = min(120, max(5, focusMinutes + (up ? step : -step)))
        case .rest:
            restMinutes = min(60, max(1, restMinutes + (up ? 1 : -1)))
        }
        remaining = currentMinutes * 60
    }

    func setMinutes(_ minutes: Int, for target: TimerMode) {
        if target == .focus { focusMinutes = minutes } else { restMinutes = minutes }
        switchMode(to: target)
    }

    // MARK: - Ticking

    private func tick() {
        guard let endDate else { return }
        let left = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if left != remaining { remaining = left }
        if left == 0 { finish() }
    }

    private func finish() {
        pause()
        NSSound(named: "Glass")?.play()
        if mode == .focus {
            slicesToday += 1
            mode = .rest
        } else {
            mode = .focus
        }
        remaining = currentMinutes * 60
        justFinished = true
    }
}
