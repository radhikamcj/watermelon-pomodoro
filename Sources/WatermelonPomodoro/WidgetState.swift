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
    /// Drives the card's fade/shrink animation.
    @Published private(set) var cardVisible: Bool

    private var animating = false
    private static let fadeOut = 0.18

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
        withAnimation(.easeIn(duration: Self.fadeOut)) { cardVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeOut) {
            self.isCollapsed = true
            self.animating = false
        }
    }

    func expand() {
        guard isCollapsed, !animating else { return }
        isCollapsed = false
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { self.cardVisible = true }
        }
    }
}
