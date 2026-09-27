import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var seedPanel: SeedPanel!
    private let timer = PomodoroTimer()
    private var celebrationWatch: AnyCancellable?
    private var hideSeeds: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = Layout.windowSize
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))

        let hosting = FirstClickHostingView(rootView: WidgetView().environmentObject(timer))
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting

        // Remember where the widget was dragged to between launches (position only; size comes from the art).
        if panel.setFrameUsingName("WatermelonWidget") {
            panel.setContentSize(size)
        } else {
            placeInTopRightCorner()
        }
        panel.setFrameAutosaveName("WatermelonWidget")
        panel.orderFrontRegardless()

        seedPanel = SeedPanel()
        celebrationWatch = timer.$celebrationCount
            .dropFirst()
            .sink { [weak self] _ in self?.popSeeds() }
    }

    private func placeInTopRightCorner() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - panel.frame.width - 24,
            y: visible.maxY - panel.frame.height - 24
        ))
    }

    /// Shows the seed overlay around the widget for as long as the seeds are flying.
    private func popSeeds() {
        let margin = SeedPanel.margin
        seedPanel.setFrame(panel.frame.insetBy(dx: -margin, dy: -margin), display: false)

        let origin = CGPoint(x: margin + Layout.seedOrigin.x, y: margin + Layout.seedOrigin.y)
        let seeds = Seed.bursts(from: origin)
        let hosting = NSHostingView(rootView: SeedBurstView(seeds: seeds, startDate: Date()))
        // Don't let SwiftUI resize the overlay to fit; it must line up exactly with the widget.
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: seedPanel.frame.size)
        seedPanel.contentView = hosting
        seedPanel.orderFrontRegardless()

        hideSeeds?.cancel()
        let hide = DispatchWorkItem { [weak self] in
            self?.seedPanel.orderOut(nil)
            self?.seedPanel.contentView = nil
        }
        hideSeeds = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + Seed.duration(of: seeds) + 0.1, execute: hide)
    }
}

/// A borderless panel that floats above every app, on every Space, even over full-screen apps.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        // The widget draws its own pink shadow instead of the standard gray one.
        hasShadow = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Transparent, click-through window just above the widget where the seeds fly.
final class SeedPanel: NSPanel {
    static let margin: CGFloat = 160

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
    }

    // macOS normally nudges windows down so they don't overlap the menu bar. This overlay
    // extends past the widget on every side, so that nudge would shift all the seeds.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Reacts to the very first click even when another app is focused.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
