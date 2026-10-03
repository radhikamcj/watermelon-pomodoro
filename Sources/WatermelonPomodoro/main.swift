import AppKit

// Dev helper: `WatermelonPomodoro --snapshot out.png` renders the widget to an image and exits.
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
    let seeds = CommandLine.arguments.contains("--seeds")
    let minutes = CommandLine.arguments.firstIndex(of: "--minutes").flatMap { Int(CommandLine.arguments[$0 + 1]) } ?? 0
    let elapsed = CommandLine.arguments.firstIndex(of: "--elapsed").flatMap { Int(CommandLine.arguments[$0 + 1]) } ?? 0
    let collapsed = CommandLine.arguments.contains("--collapsed")
    MainActor.assumeIsolated {
        Snapshot.write(to: CommandLine.arguments[i + 1], seeds: seeds, minutes: minutes, elapsed: elapsed, collapsed: collapsed)
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// No Dock icon: the widget lives only as a floating window.
app.setActivationPolicy(.accessory)
app.run()
