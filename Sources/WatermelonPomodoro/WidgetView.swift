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
    /// Room around the art for the soft pink glow, in points.
    static let shadowPadding: CGFloat = 18
    /// Extra room on the left: the watermelon's rind hangs past the card's edge (more so mid-shake).
    static let leftOverhang: CGFloat = 24
    static var windowSize: CGSize {
        CGSize(width: widgetSize.width + shadowPadding * 2 + leftOverhang,
               height: widgetSize.height + shadowPadding * 2)
    }
    /// Average color of base.png, for the glow around the card.
    static let glow = Color(red: 0xFE / 255, green: 0x87 / 255, blue: 0x86 / 255)

    // Watermelon, placed as in the Figma frame: the left 469 x 560 of its canvas, turned 42.44°
    // clockwise so it stands upright. Keep in sync with scripts/export_art.swift.
    static let watermelonSize = CGSize(width: 469, height: 560)
    static let watermelonCenter = CGPoint(x: 138, y: 279.9)
    static let watermelonAngle: Double = 42.44
    /// The watermelon's center as a fraction of the canvas, for rotating and scaling around it.
    static var watermelonAnchor: UnitPoint {
        UnitPoint(x: watermelonCenter.x / canvas.width, y: watermelonCenter.y / canvas.height)
    }
    /// Takes a point on the watermelon drawing (before it's turned upright) to the canvas.
    static func upright(_ p: CGPoint) -> CGPoint {
        let a = watermelonAngle * .pi / 180
        let dx = p.x - watermelonSize.width / 2, dy = p.y - watermelonSize.height / 2
        return CGPoint(x: watermelonCenter.x + dx * cos(a) - dy * sin(a),
                       y: watermelonCenter.y + dx * sin(a) + dy * cos(a))
    }
    /// Middle of the red flesh, where the celebration pops from.
    static let fleshCenter = upright(CGPoint(x: 240, y: 290))
    /// Where bites 1, 2 and 3 were taken (measured from the drawings), for their pops of seeds.
    static let biteCenters = [CGPoint(x: 250, y: 252), CGPoint(x: 319, y: 293), CGPoint(x: 139, y: 199)].map(upright)

    // Time: sized so the widest format (HH:MM:SS) fits between the watermelon's cut edge
    // (x ~ 190 at this height) and ~10pt inside the card's right edge (x = 952).
    static let timeCenter = CGPoint(x: 570, y: 185)
    static let glyphScale: CGFloat = 0.7
    /// Every digit gets the same width, like a digital clock, so nothing shifts as seconds tick.
    static let digitSlot: CGFloat = 142

    // Controls: one fixed row  –  ▶  ❚❚  +  that never moves (the watermelon reaches x ~ 256 here).
    static let controlsCenter = CGPoint(x: 570, y: 405)
    static let signScale: CGFloat = 0.6
    static let minusScale: CGFloat = 0.7
    static let playPauseScale: CGFloat = 0.9
    static let signToPlayPause: CGFloat = 40
    static let playToPause: CGFloat = 50

    /// The part of the canvas kept on screen when collapsed: the upright watermelon (x -86...260,
    /// y 59...504) plus room to sway, shake and hop (it grows ~16%). Multiples of 4 so it lands on
    /// whole points and the window doesn't creep from rounding as it collapses/expands.
    static let collapsedRect = CGRect(x: -128, y: -20, width: 412, height: 564)

    static func windowSize(collapsed: Bool) -> CGSize {
        collapsed ? CGSize(width: collapsedRect.width * scale, height: collapsedRect.height * scale) : windowSize
    }

    /// Where the canvas's top-left corner sits in the window, in points.
    static func canvasOrigin(collapsed: Bool) -> CGPoint {
        collapsed
            ? CGPoint(x: -collapsedRect.minX * scale, y: -collapsedRect.minY * scale)
            : CGPoint(x: shadowPadding + leftOverhang, y: shadowPadding)
    }

    /// A point on the canvas, in points from the window's top-left corner.
    static func windowPoint(_ canvasPoint: CGPoint, collapsed: Bool) -> CGPoint {
        let origin = canvasOrigin(collapsed: collapsed)
        return CGPoint(x: origin.x + canvasPoint.x * scale, y: origin.y + canvasPoint.y * scale)
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
            layer("base")
                .shadow(color: Layout.glow.opacity(0.9), radius: 40, x: 0, y: 14)
                .contentShape(Rectangle())
            .gesture(windowDrag())
            .contextMenu { menu }
            .card(visible: state.cardVisible)

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

    /// Clicking the watermelon (its own outline, not its square frame) tucks the widget away
    /// or brings it back; dragging it moves the widget as usual.
    private var watermelonHitArea: some View {
        Color.clear
            .frame(width: Layout.canvas.width, height: Layout.canvas.height)
            .contentShape(WatermelonOutline())
            .onTapGesture { state.toggle() }
            .gesture(windowDrag(minimumDistance: 3))
            .contextMenu { menu }
            .help(state.isCollapsed ? "Show timer" : "Tuck away")
    }

    private func layer(_ name: String) -> some View {
        Image(nsImage: Art.image(name))
            .resizable()
            .interpolation(.high)
            .frame(width: Layout.canvas.width, height: Layout.canvas.height)
    }

    // MARK: Watermelon

    /// The watermelon, with one more bite out of it for every half hour of the session.
    private var watermelon: some View {
        Image(nsImage: Art.image(timer.bites == 0 ? "watermelon" : "watermelon_bite\(timer.bites)"))
            .resizable()
            .interpolation(.high)
            .frame(width: Layout.watermelonSize.width, height: Layout.watermelonSize.height)
            .rotationEffect(.degrees(Layout.watermelonAngle))
            .position(Layout.watermelonCenter)
            .frame(width: Layout.canvas.width, height: Layout.canvas.height, alignment: .topLeading)
            // A quick chomp each time a bite is taken.
            .keyframeAnimator(initialValue: Shake(), trigger: timer.bites) { content, chomp in
                content
                    .rotationEffect(.degrees(chomp.angle), anchor: Layout.watermelonAnchor)
                    .scaleEffect(chomp.scale, anchor: Layout.watermelonAnchor)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.93, duration: 0.08)
                    SpringKeyframe(1.05, duration: 0.15)
                    SpringKeyframe(1.0, duration: 0.3)
                }
                KeyframeTrack(\.angle) {
                    CubicKeyframe(-4, duration: 0.08)
                    CubicKeyframe(3, duration: 0.12)
                    SpringKeyframe(0, duration: 0.3)
                }
            }
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

// MARK: - Outline

/// The watermelon's outline, traced from its drawing (left and right edges every 20px down) and
/// turned upright like the slice, so only the slice itself is clickable. Drawn in canvas
/// coordinates: give it a frame the size of the canvas.
struct WatermelonOutline: Shape {
    private static let points: [CGPoint] = [
        // down the right side: the cut edge, then the rind
        (70, 133), (86, 140), (122, 160), (165, 180), (202, 200), (246, 220), (278, 240), (313, 260),
        (349, 280), (384, 300), (424, 320), (455, 340), (449, 360), (439, 380), (427, 400), (411, 420),
        (392, 440), (367, 460), (339, 480), (294, 500), (230, 506),
        // back up the left side
        (163, 500), (121, 480), (96, 460), (77, 440), (62, 420), (48, 400), (37, 380), (29, 360),
        (22, 340), (18, 320), (15, 300), (15, 280), (15, 260), (18, 240), (23, 220), (28, 200),
        (37, 180), (47, 160), (61, 140),
    ].map { CGPoint(x: $0.0, y: $0.1) }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addLines(Self.points.map(Layout.upright).map { CGPoint(x: rect.minX + $0.x, y: rect.minY + $0.y) })
        p.closeSubpath()
        return p
    }
}
