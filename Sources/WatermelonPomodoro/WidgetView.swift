import AppKit
import SwiftUI

// MARK: - Palette

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private enum Melon {
    static let rindDark = Color(hex: 0x3E9B4F)
    static let rindLight = Color(hex: 0xD4F5B0)
    static let seed = Color(hex: 0x3A2A2E)
    static let blush = Color(hex: 0xFF9FB2)
    static let ink = Color(hex: 0xC4344F)

    static func flesh(_ mode: TimerMode) -> LinearGradient {
        let colors: [Color] = mode == .focus
            ? [Color(hex: 0xFF6B84), Color(hex: 0xFF8FA3)]
            : [Color(hex: 0xFF9DB0), Color(hex: 0xFFC4CF)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Widget

struct WidgetView: View {
    @EnvironmentObject private var timer: PomodoroTimer
    @State private var hovering = false
    @State private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    var body: some View {
        ZStack {
            rind
            HStack(spacing: 12) {
                SliceMascot(awake: timer.isRunning, celebrating: timer.justFinished)
                    .frame(width: 52, height: 40)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.timeText)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: Melon.ink.opacity(0.45), radius: 0, x: 0, y: 2)
                        .allowsHitTesting(false)
                    subtitle
                }

                Spacer(minLength: 0)

                controls
            }
            .padding(.leading, 18)
            .padding(.trailing, 16)
        }
        .frame(width: 260, height: 104)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hovering)
        .animation(.easeInOut(duration: 0.4), value: timer.mode)
    }

    // Layered rind: dark green edge, pale green stripe, pink flesh with seeds.
    private var rind: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Melon.rindDark)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Melon.rindLight)
                .padding(4)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Melon.flesh(timer.mode))
                .overlay(SeedScatter().opacity(0.5))
                .overlay(alignment: .bottom) { progressBar }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .gesture(windowDrag)
        .contextMenu { presetsMenu }
    }

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
    private var presetsMenu: some View {
        Button("🍉  Focus 25 min") { timer.setMinutes(25, for: .focus) }
        Button("🍉  Focus 50 min") { timer.setMinutes(50, for: .focus) }
        Button("☁️  Break 5 min") { timer.setMinutes(5, for: .rest) }
        Button("☁️  Break 15 min") { timer.setMinutes(15, for: .rest) }
        Divider()
        Button("Quit Watermelon") { NSApp.terminate(nil) }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.3))
                Capsule().fill(.white.opacity(0.95))
                    .frame(width: max(6, geo.size.width * timer.progress))
                    .animation(.linear(duration: 0.25), value: timer.progress)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 20)
        .padding(.bottom, 9)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var subtitle: some View {
        if hovering && !timer.isRunning {
            HStack(spacing: 6) {
                TinyButton(symbol: "minus") { timer.adjust(up: false) }
                Text("\(timer.currentMinutes) min")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 40)
                TinyButton(symbol: "plus") { timer.adjust(up: true) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
            HStack(spacing: 4) {
                Text(timer.justFinished ? "yay! slice done" : timer.mode.label)
                if timer.slicesToday > 0 {
                    Text("· \(timer.slicesToday) 🍉")
                }
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private var controls: some View {
        VStack(spacing: 6) {
            Button(action: timer.toggle) {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Melon.ink)
                    .offset(x: timer.isRunning ? 0 : 1)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white))
                    .shadow(color: Melon.ink.opacity(0.3), radius: 0, x: 0, y: 2)
            }
            .buttonStyle(SquishStyle())
            .help(timer.isRunning ? "Pause" : "Start")

            Button(action: timer.reset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Melon.ink)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.white.opacity(0.75)))
            }
            .buttonStyle(SquishStyle())
            .help("Reset")
        }
    }
}

// MARK: - Pieces

/// A little kawaii watermelon slice. Sleepy eyes when paused, open eyes while focusing.
struct SliceMascot: View {
    var awake: Bool
    var celebrating: Bool
    @State private var wobble = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                HalfDisc().fill(Melon.rindDark)
                HalfDisc().fill(Melon.rindLight).padding(.horizontal, w * 0.06).padding(.bottom, h * 0.08)
                HalfDisc().fill(Color(hex: 0xFF5A76)).padding(.horizontal, w * 0.12).padding(.bottom, h * 0.16)

                // seeds
                ForEach(Array([(0.3, 0.25), (0.5, 0.18), (0.7, 0.25)].enumerated()), id: \.offset) { _, p in
                    Capsule().fill(Melon.seed)
                        .frame(width: w * 0.045, height: h * 0.1)
                        .position(x: w * p.0, y: h * p.1)
                }

                // face
                Group {
                    eye.position(x: w * 0.38, y: h * 0.47)
                    eye.position(x: w * 0.62, y: h * 0.47)
                    Ellipse().fill(Melon.blush).frame(width: w * 0.12, height: h * 0.09)
                        .position(x: w * 0.27, y: h * 0.6)
                    Ellipse().fill(Melon.blush).frame(width: w * 0.12, height: h * 0.09)
                        .position(x: w * 0.73, y: h * 0.6)
                    Smile().stroke(Melon.seed, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: w * 0.1, height: h * 0.07)
                        .position(x: w * 0.5, y: h * 0.58)
                }

                if celebrating {
                    Text("✨").font(.system(size: 13)).position(x: w * 0.95, y: h * 0.05)
                }
            }
            .rotationEffect(.degrees(awake && wobble ? 4 : (awake ? -4 : 0)), anchor: .bottom)
            .scaleEffect(celebrating ? 1.08 : 1)
        }
        .onAppear { wobble = true }
        .animation(awake ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .spring(), value: wobble)
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: celebrating)
        .onChange(of: awake) { _ in wobble.toggle() }
    }

    @ViewBuilder
    private var eye: some View {
        if awake {
            Circle().fill(Melon.seed).frame(width: 4.5, height: 4.5)
        } else {
            Smile().stroke(Melon.seed, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 6, height: 3)
        }
    }
}

/// Flat side on top, round side at the bottom, like a slice seen from the front.
struct HalfDisc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width / 2, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.minY)
        p.move(to: CGPoint(x: center.x - r, y: center.y))
        p.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        return p
    }
}

struct SeedScatter: View {
    private let seeds: [(x: Double, y: Double, angle: Double)] = [
        (0.05, 0.22, -20), (0.03, 0.72, 15), (0.24, 0.1, 30), (0.43, 0.9, -10),
        (0.63, 0.1, 20), (0.78, 0.86, -25), (0.97, 0.3, 10), (0.96, 0.78, -15),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(seeds.indices, id: \.self) { i in
                let s = seeds[i]
                Ellipse()
                    .fill(Melon.seed)
                    .frame(width: 4, height: 7)
                    .rotationEffect(.degrees(s.angle))
                    .position(x: geo.size.width * s.x, y: geo.size.height * s.y)
            }
        }
        .allowsHitTesting(false)
    }
}

struct TinyButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(Melon.ink)
                .frame(width: 16, height: 16)
                .background(Circle().fill(.white))
        }
        .buttonStyle(SquishStyle())
    }
}

struct SquishStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
