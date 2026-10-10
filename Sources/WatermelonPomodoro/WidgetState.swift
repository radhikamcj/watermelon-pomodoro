import Combine
import SwiftUI

/// Whether the widget shows the whole timer card or is tucked down to just the watermelon.
final class WidgetState: ObservableObject {
    /// Drives the window size. Changes after the card has faded out, and before it fades back in.
    @Published private(set) var isCollapsed: Bool {
        // Called once the new value is stored, so the window and SwiftUI agree on the layout.
        // (Resizing any earlier makes SwiftUI redraw with the old value and get stuck there.)
        didSet { if isCollapsed != oldValue { onLayoutChange?(isCollapsed) } }
    }
    /// Resizes the window to match; set by the app delegate.
    var onLayoutChange: ((Bool) -> Void)?
    /// Drives the collapse / expand animation (each part animates itself; see `Motion`).
    @Published private(set) var cardVisible: Bool

    private var animating = false

    /// Where a drag of the widget started (mouse and window origin, in screen coordinates).
    /// Kept here rather than in SwiftUI `@State`, which needs a compiler plugin the Command Line
    /// Tools don't ship with the macOS 27 SDK. Not published: it never changes what's drawn.
    var dragStart: (mouse: NSPoint, origin: NSPoint)?

    init(collapsed: Bool = false) {
        isCollapsed = collapsed
        cardVisible = !collapsed
    }

    func toggle() {
        isCollapsed ? expand() : collapse()
    }

    func collapse() {
        guard !isCollapsed, !animating else { return }
        animating = true
        cardVisible = false
        // Shrink the window once the card has retracted and the whole watermelon has spun in.
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.collapseDuration) {
            self.isCollapsed = true
            self.animating = false
        }
    }

    func expand() {
        guard isCollapsed, !animating else { return }
        animating = true
        // Grow the window first, then play the collapse in reverse inside it.
        isCollapsed = false
        DispatchQueue.main.async {
            self.cardVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + Motion.collapseDuration) { self.animating = false }
        }
    }
}
