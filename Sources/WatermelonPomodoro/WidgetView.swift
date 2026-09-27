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

    /// Where seeds pop from, in points from the window's top-left corner.
    static var seedOrigin: CGPoint {
        CGPoint(x: shadowPadding + leftOverhang + fleshCenter.x * scale,
                y: shadowPadding + fleshCenter.y * scale)
    }
}

// MARK: - Widget

struct WidgetView: View {
    @EnvironmentObject private var timer: PomodoroTimer
    @State private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The background is what you grab to drag and right-click; everything drawn
            // on top of it (except the buttons) lets the mouse fall through to it.
            ZStack {
                layer("white_bg")
                    .shadow(color: Layout.pink.opacity(0.9), radius: 40, x: 0, y: 14)
                layer("pink_bg")
            }
            .contentShape(Rectangle())
            .gesture(windowDrag)
            .contextMenu { menu }

            layer("border").allowsHitTesting(false)
            watermelon
            time.position(Layout.timeCenter)
            controls.position(Layout.controlsCenter)
        }
        .frame(width: Layout.canvas.width, height: Layout.canvas.height, alignment: .topLeading)
        .scaleEffect(Layout.scale, anchor: .topLeading)
        .frame(width: Layout.widgetSize.width, height: Layout.widgetSize.height, alignment: .topLeading)
        .padding(Layout.shadowPadding)
        .padding(.leading, Layout.leftOverhang)
    }

    private func layer(_ name: String) -> some View {
        Image(nsImage: Art.image(name))
            .resizable()
            .interpolation(.high)
            .frame(width: Layout.canvas.width, height: Layout.canvas.height)
    }

    // MARK: Watermelon

    private var watermelon: some View {
        Image(nsImage: Art.image("watermelon"))
            .resizable()
            .interpolation(.high)
            .frame(width: Layout.watermelonSize.width, height: Layout.watermelonSize.height)
            .rotationEffect(.degrees(Layout.watermelonAngle))
            // Gentle sway while focusing.
            .phaseAnimator([-2.5, 2.5]) { content, angle in
                content.rotationEffect(.degrees(timer.isRunning ? angle : 0))
            } animation: { _ in
                .easeInOut(duration: 1.4)
            }
            // Big happy shake when a session ends.
            .keyframeAnimator(initialValue: Shake(), trigger: timer.celebrationCount) { content, shake in
                content
                    .rotationEffect(.degrees(shake.angle))
                    .scaleEffect(shake.scale)
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
            .position(Layout.watermelonCenter)
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
    private var windowDrag: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
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
        Button("Reset") { timer.reset() }
        Button("Preview celebration 🎉") { timer.celebrate() }
        Button("Quit Watermelon") { NSApp.terminate(nil) }
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
