import AppKit
import SwiftUI

// MARK: - Art

/// Loads the hand-drawn images exported by scripts/export_art.swift.
enum Art {
    private static let directory: URL = {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Art"),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        // `swift run` during development: <root>/Sources/WatermelonPomodoro/WidgetView.swift -> <root>/Resources/Art
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Art")
    }()

    private static var cache: [String: NSImage] = [:]

    static func image(_ name: String) -> NSImage {
        if let cached = cache[name] { return cached }
        let image = NSImage(contentsOf: directory.appendingPathComponent("\(name).png")) ?? NSImage()
        cache[name] = image
        return image
    }

    /// Size in design pixels (the 1000 x 560 canvas the art was drawn on).
    static func size(_ name: String) -> CGSize {
        guard let rep = image(name).representations.first else { return .zero }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    static func glyphName(for character: Character) -> String {
        character == ":" ? "colon" : String(character)
    }
}

/// Positions on the design canvas, in design pixels.
enum Layout {
    static let canvas = CGSize(width: 1000, height: 560)
    /// Design pixels -> points. 1000 x 560 art becomes a 250 x 140 widget.
    static let scale: CGFloat = 0.25
    static var widgetSize: CGSize { CGSize(width: canvas.width * scale, height: canvas.height * scale) }
    /// Room around the art for the soft pink shadow, in points.
    static let shadowPadding: CGFloat = 18
    /// Extra room on the left: the watermelon's rind hangs past the card's edge (more so mid-shake).
    static let leftOverhang: CGFloat = 24
    static var windowSize: CGSize {
        CGSize(width: widgetSize.width + shadowPadding * 2 + leftOverhang,
               height: widgetSize.height + shadowPadding * 2)
    }
    /// Average color of pink_bg.png.
    static let pink = Color(red: 1, green: 0xB0 / 255, blue: 0xB0 / 255)

    // Watermelon, placed as in the Figma frame: the left 469 x 560 of its canvas,
    // turned 42.44° clockwise so it stands upright. Keep in sync with scripts/export_art.swift.
    static let watermelonSize = CGSize(width: 469, height: 560)
    static let watermelonCenter = CGPoint(x: 138, y: 279.9)
    static let watermelonAngle: Double = 42.44
    /// The watermelon's center as a fraction of the canvas, for rotating and scaling around it.
    static var watermelonAnchor: UnitPoint {
        UnitPoint(x: watermelonCenter.x / canvas.width, y: watermelonCenter.y / canvas.height)
    }

    // Time: sized so the widest format (HH:MM:SS) fits between the watermelon's cut edge
    // (x ~ 190 at this height) and ~5pt before the border's inner edge (x = 931).
    static let timeCenter = CGPoint(x: 570, y: 185)
    static let glyphScale: CGFloat = 0.7
    /// Every digit gets the same width, like a digital clock, so nothing shifts as seconds tick.
    static let digitSlot: CGFloat = 142

    // Controls: one fixed row  –  ▶  ❚❚  +  that never moves.
    static let controlsCenter = CGPoint(x: 570, y: 405)
    static let signScale: CGFloat = 0.6
    static let minusScale: CGFloat = 0.7
    static let playPauseScale: CGFloat = 0.9
    static let signToPlayPause: CGFloat = 40
    static let playToPause: CGFloat = 50

    /// Middle of the watermelon's red flesh once it's turned upright, in design pixels.
    static let fleshCenter = CGPoint(x: 134, y: 256)

    /// The part of the canvas kept on screen when collapsed: the watermelon plus room to sway,
    /// shake and hop (the rind reaches x ~ -73; mid-shake it grows ~16%). Multiples of 4 so it
    /// lands on whole points and the window doesn't creep from rounding as it collapses/expands.
    static let collapsedRect = CGRect(x: -116, y: -32, width: 412, height: 576)

    static func windowSize(collapsed: Bool) -> CGSize {
        collapsed ? CGSize(width: collapsedRect.width * scale, height: collapsedRect.height * scale) : windowSize
    }

    /// Where the canvas's top-left corner sits in the window, in points.
    static func canvasOrigin(collapsed: Bool) -> CGPoint {
        collapsed
            ? CGPoint(x: -collapsedRect.minX * scale, y: -collapsedRect.minY * scale)
            : CGPoint(x: shadowPadding + leftOverhang, y: shadowPadding)
    }

    /// Where seeds pop from, in points from the window's top-left corner.
    static func seedOrigin(collapsed: Bool) -> CGPoint {
        let origin = canvasOrigin(collapsed: collapsed)
        return CGPoint(x: origin.x + fleshCenter.x * scale, y: origin.y + fleshCenter.y * scale)
    }
}

// MARK: - Widget

struct WidgetView: View {
    @EnvironmentObject private var timer: PomodoroTimer
    @EnvironmentObject private var loginItem: LoginItem
    @EnvironmentObject private var state: WidgetState
    @State private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    var body: some View {
        let origin = Layout.canvasOrigin(collapsed: state.isCollapsed)
        let window = Layout.windowSize(collapsed: state.isCollapsed)

        ZStack(alignment: .topLeading) {
            // The background is what you grab to drag and right-click; everything drawn
            // on top of it (except the buttons) lets the mouse fall through to it.
            ZStack {
                layer("white_bg")
                    .shadow(color: Layout.pink.opacity(0.9), radius: 40, x: 0, y: 14)
                layer("pink_bg")
            }
            .contentShape(Rectangle())
            .gesture(windowDrag())
            .contextMenu { menu }
            .card(visible: state.cardVisible)

            layer("border").allowsHitTesting(false).card(visible: state.cardVisible)
            watermelon
            watermelonHitArea
            time.position(Layout.timeCenter).card(visible: state.cardVisible)
            controls.position(Layout.controlsCenter).card(visible: state.cardVisible)
        }
        .frame(width: Layout.canvas.width, height: Layout.canvas.height, alignment: .topLeading)
        .scaleEffect(Layout.scale, anchor: .topLeading)
        .frame(width: Layout.widgetSize.width, height: Layout.widgetSize.height, alignment: .topLeading)
        // Collapsed, the window shrinks around the watermelon and the canvas shifts so the
        // watermelon stays on the same spot on screen.
        .offset(x: origin.x, y: origin.y)
        .frame(width: window.width, height: window.height, alignment: .topLeading)
        // Collapsed, the whole (small) window is the watermelon's click target; an almost
        // invisible fill keeps macOS from passing clicks through its transparent corners.
        .background(state.isCollapsed ? Color.black.opacity(0.01) : Color.clear)
    }

    /// Clicking the watermelon (the slice's own outline, not its square frame) tucks the
    /// widget away or brings it back; dragging it moves the widget as usual.
    private var watermelonHitArea: some View {
        let shape = RindShape.outer
        return Color.clear
            .frame(width: shape.size.width, height: shape.size.height)
            .contentShape(shape)
            .onTapGesture { state.toggle() }
            .gesture(windowDrag(minimumDistance: 3))
            .contextMenu { menu }
            .help(state.isCollapsed ? "Show timer" : "Tuck away")
            .offset(x: shape.origin.x, y: shape.origin.y)
    }

    private func layer(_ name: String) -> some View {
        Image(nsImage: Art.image(name))
            .resizable()
            .interpolation(.high)
            .frame(width: Layout.canvas.width, height: Layout.canvas.height)
    }

    // MARK: Watermelon

    /// The slice plus the two rind shapes behind it (Figma "Vector 1" and "Vector 2"),
    /// grouped so they sway and shake together.
    private var watermelon: some View {
        ZStack(alignment: .topLeading) {
            RindShape.outer
                .fill(RindShape.outerColor)
                .frame(width: RindShape.outer.size.width, height: RindShape.outer.size.height)
                .offset(x: RindShape.outer.origin.x, y: RindShape.outer.origin.y)
            RindShape.inner
                .fill(RindShape.innerColor)
                .frame(width: RindShape.inner.size.width, height: RindShape.inner.size.height)
                .offset(x: RindShape.inner.origin.x, y: RindShape.inner.origin.y)
            Image(nsImage: Art.image("watermelon"))
                .resizable()
                .interpolation(.high)
                .frame(width: Layout.watermelonSize.width, height: Layout.watermelonSize.height)
                .rotationEffect(.degrees(Layout.watermelonAngle))
                .position(Layout.watermelonCenter)
        }
        .frame(width: Layout.canvas.width, height: Layout.canvas.height, alignment: .topLeading)
            // Gentle sway while focusing.
            .phaseAnimator([-2.5, 2.5]) { content, angle in
                content.rotationEffect(.degrees(timer.isRunning ? angle : 0), anchor: Layout.watermelonAnchor)
            } animation: { _ in
                .easeInOut(duration: 1.4)
            }
            // Big happy shake when a session ends.
            .keyframeAnimator(initialValue: Shake(), trigger: timer.celebrationCount) { content, shake in
                content
                    .rotationEffect(.degrees(shake.angle), anchor: Layout.watermelonAnchor)
                    .scaleEffect(shake.scale, anchor: Layout.watermelonAnchor)
                    .offset(y: shake.lift)
            } keyframes: { _ in
                KeyframeTrack(\.angle) {
                    CubicKeyframe(-14, duration: 0.1)
                    CubicKeyframe(14, duration: 0.12)
                    CubicKeyframe(-13, duration: 0.12)
                    CubicKeyframe(13, duration: 0.12)
                    CubicKeyframe(-11, duration: 0.12)
                    CubicKeyframe(11, duration: 0.12)
                    CubicKeyframe(-9, duration: 0.12)
                    CubicKeyframe(9, duration: 0.12)
                    CubicKeyframe(-6, duration: 0.12)
                    CubicKeyframe(6, duration: 0.12)
                    CubicKeyframe(-3, duration: 0.12)
                    CubicKeyframe(0, duration: 0.2)
                }
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.16, duration: 0.2)
                    SpringKeyframe(0.95, duration: 0.25)
                    SpringKeyframe(1.12, duration: 0.2)
                    SpringKeyframe(0.97, duration: 0.25)
                    SpringKeyframe(1.08, duration: 0.2)
                    SpringKeyframe(1.0, duration: 0.4)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(-40, duration: 0.2)
                    CubicKeyframe(0, duration: 0.25)
                    CubicKeyframe(-30, duration: 0.2)
                    CubicKeyframe(0, duration: 0.25)
                    CubicKeyframe(-20, duration: 0.2)
                    CubicKeyframe(0, duration: 0.25)
                }
            }
            .allowsHitTesting(false)
    }

    // MARK: Time

    private var time: some View {
        let scale = Layout.glyphScale
        return HStack(spacing: 0) {
            ForEach(Array(timer.timeText.map(Art.glyphName(for:)).enumerated()), id: \.offset) { _, name in
                let size = Art.size(name)
                let slot = name == "colon" ? size.width : Layout.digitSlot
                Image(nsImage: Art.image(name))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.width * scale, height: size.height * scale)
                    .frame(width: slot * scale)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Controls:  –  ▶  ❚❚  +

    private var controls: some View {
        HStack(spacing: 0) {
            ArtButton(name: "minus", scale: Layout.minusScale, enabled: timer.canAdjustDown) {
                timer.adjust(up: false)
            }
            .help("15 minutes less")

            ArtButton(name: "play", scale: Layout.playPauseScale,
                      enabled: timer.isRunning || timer.canStart, dimmed: timer.isRunning) { timer.start() }
                .help("Start")
                .padding(.leading, Layout.signToPlayPause)

            ArtButton(name: "pause", scale: Layout.playPauseScale, dimmed: !timer.isRunning) { timer.pause() }
                .help("Pause")
                .padding(.leading, Layout.playToPause)

            ArtButton(name: "plus", scale: Layout.signScale, enabled: timer.canAdjustUp) {
                timer.adjust(up: true)
            }
            .help("15 minutes more")
            .padding(.leading, Layout.signToPlayPause)
        }
    }

    // MARK: Dragging + menu

    // Moves the floating window by tracking the mouse in screen coordinates,
    // so the window moving under the cursor doesn't feed back into the drag.
    private func windowDrag(minimumDistance: CGFloat = 1) -> some Gesture {
        DragGesture(minimumDistance: minimumDistance, coordinateSpace: .global)
            .onChanged { _ in
                guard let window = NSApp.windows.first(where: { $0 is FloatingPanel }) else { return }
                let mouse = NSEvent.mouseLocation
                if dragStart == nil {
                    dragStart = (mouse, window.frame.origin)
                }
                guard let start = dragStart else { return }
                window.setFrameOrigin(NSPoint(
                    x: start.origin.x + mouse.x - start.mouse.x,
                    y: start.origin.y + mouse.y - start.mouse.y
                ))
            }
            .onEnded { _ in dragStart = nil }
    }

    @ViewBuilder
    private var menu: some View {
        Text("Now: \(timer.mode.label)" + (timer.slicesToday > 0 ? " · \(timer.slicesToday) 🍉 today" : ""))
        Divider()
        Button("🍉  Focus 25 min") { timer.setMinutes(25, for: .focus) }
        Button("🍉  Focus 50 min") { timer.setMinutes(50, for: .focus) }
        Button("☁️  Break 5 min") { timer.setMinutes(5, for: .rest) }
        Button("☁️  Break 15 min") { timer.setMinutes(15, for: .rest) }
        Divider()
        Button(state.isCollapsed ? "Show timer" : "Tuck away") { state.toggle() }
        Button("Reset") { timer.reset() }
        Toggle("Open at login", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
        Button("Preview celebration 🎉") { timer.celebrate() }
        Button("Quit Watermelon") { NSApp.terminate(nil) }
    }
}

extension View {
    /// The timer card's parts fade and shrink toward the watermelon when it's tucked away.
    func card(visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.85, anchor: Layout.watermelonAnchor)
            .allowsHitTesting(visible)
    }
}

struct Shake {
    var angle: Double = 0
    var scale: CGFloat = 1
    var lift: CGFloat = 0
}

// MARK: - Buttons

/// A button drawn with one of the hand-drawn glyphs, with a generous click area.
struct ArtButton: View {
    /// Extra clickable area around the drawing, without taking up layout space.
    static let hitPadding: CGFloat = 22

    let name: String
    var scale: CGFloat = 1
    var enabled = true
    var dimmed = false
    let action: () -> Void

    var body: some View {
        let size = Art.size(name)
        Button(action: action) {
            Image(nsImage: Art.image(name))
                .resizable()
                .interpolation(.high)
                .frame(width: size.width * scale, height: size.height * scale)
                .padding(Self.hitPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(SquishStyle())
        .padding(-Self.hitPadding)
        .opacity(!enabled ? 0.35 : dimmed ? 0.5 : 1)
        .disabled(!enabled)
    }
}

struct SquishStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Rind

/// The flat rind shapes drawn behind the watermelon in the Figma frame: a dark green crescent
/// (Vector 1) with a salmon shape over it (Vector 2), so an even band of dark green shows.
/// Paths are copied from Figma's SVG export; `origin` is their spot on the design canvas.
struct RindShape: Shape {
    let origin: CGPoint
    let size: CGSize
    let draw: @Sendable (inout Path) -> Void

    static let outerColor = Color(red: 0x13 / 255, green: 0x43 / 255, blue: 0)          // #134300
    static let innerColor = Color(red: 1, green: 0xAE / 255, blue: 0x9B / 255)          // #FFAE9B

    // Figma positions are relative to the frame, whose canvas starts at (13, -24).
    static let outer = RindShape(origin: CGPoint(x: -60.11 - 13, y: 38 + 24),
                                 size: CGSize(width: 330.106, height: 438)) { p in
        p.move(to: CGPoint(x: 11.7834, y: 292.166))
        p.addCurve(to: CGPoint(x: 180.689, y: 0),
                   control1: CGPoint(x: -41.394, y: 104.5), control2: CGPoint(x: 97.9021, y: 17.48))
        p.addLine(to: CGPoint(x: 330.106, y: 410.53))
        p.addCurve(to: CGPoint(x: 11.7834, y: 292.166),
                   control1: CGPoint(x: 250.484, y: 450.984), control2: CGPoint(x: 71.0441, y: 470.961))
        p.closeSubpath()
    }

    static let inner = RindShape(origin: CGPoint(x: -23.45 - 13, y: 38 + 24),
                                 size: CGSize(width: 293.451, height: 436.119)) { p in
        p.move(to: CGPoint(x: 14.9508, y: 286))
        p.addCurve(to: CGPoint(x: 144.034, y: 0),
                   control1: CGPoint(x: -38.2266, y: 98.3342), control2: CGPoint(x: 61.2469, y: 17.48))
        p.addLine(to: CGPoint(x: 293.451, y: 410.53))
        p.addCurve(to: CGPoint(x: 14.9508, y: 286),
                   control1: CGPoint(x: 213.828, y: 450.984), control2: CGPoint(x: 74.2115, y: 464.795))
        p.closeSubpath()
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        draw(&p)
        // Stretch from the SVG's own size to whatever frame it's given (they match here).
        return p.applying(CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / size.width, y: rect.height / size.height))
    }
}
