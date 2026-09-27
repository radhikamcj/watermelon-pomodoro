import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private let timer = PomodoroTimer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: 260, height: 104)
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))

        let hosting = FirstClickHostingView(rootView: WidgetView().environmentObject(timer))
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting

        // Remember where the widget was dragged to between launches.
        if !panel.setFrameUsingName("WatermelonPanel") {
            placeInTopRightCorner()
        }
        panel.setFrameAutosaveName("WatermelonPanel")
        panel.orderFrontRegardless()
    }

    private func placeInTopRightCorner() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - 24,
            y: visible.maxY - panel.frame.height - 24
        )
        panel.setFrameOrigin(origin)
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
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Reacts to the very first click even when another app is focused.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
