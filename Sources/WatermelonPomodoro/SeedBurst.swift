import SwiftUI

/// One seed flying out of the watermelon.
struct Seed {
    var delay: Double        // seconds after the burst starts
    var start: CGPoint       // points, in the overlay's coordinates
    var velocity: CGVector   // points per second
    var spin: Double         // degrees per second
    var angle: Double        // starting rotation
    var size: CGFloat
    var life: Double         // seconds it stays visible

    static let gravity: CGFloat = 900

    /// A few quick volleys of seeds, timed to the watermelon's hops.
    static func bursts(from origin: CGPoint, volleys: Int = 3, perVolley: Int = 4) -> [Seed] {
        (0..<volleys).flatMap { volley in
            (0..<perVolley).map { _ in
                let heading = Double.random(in: -155 ... -25) * .pi / 180
                let speed = Double.random(in: 180...340)
                return Seed(
                    delay: Double(volley) * 0.45 + .random(in: 0...0.1),
                    start: CGPoint(x: origin.x + .random(in: -20...20), y: origin.y + .random(in: -8...8)),
                    velocity: CGVector(dx: cos(heading) * speed, dy: sin(heading) * speed),
                    spin: .random(in: -900...900),
                    angle: .random(in: 0...360),
                    size: .random(in: 10...13),
                    life: .random(in: 0.75...1.05)
                )
            }
        }
    }

    /// When the last seed has faded out.
    static func duration(of seeds: [Seed]) -> Double {
        seeds.map { $0.delay + $0.life }.max() ?? 0
    }
}

/// Draws the seeds popping, arcing under gravity, spinning and fading away.
struct SeedBurstView: View {
    let seeds: [Seed]
    let startDate: Date

    private let seedColor = Color(red: 0.24, green: 0.1, blue: 0.08)

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { gc, _ in
                let elapsed = context.date.timeIntervalSince(startDate)
                for seed in seeds {
                    let t = elapsed - seed.delay
                    guard t >= 0, t < seed.life else { continue }

                    let x = seed.start.x + seed.velocity.dx * t
                    let y = seed.start.y + seed.velocity.dy * t + 0.5 * Seed.gravity * t * t
                    // Pop in quickly, then fade over the last part of its life.
                    let grow = min(1, t / 0.08)
                    let fadeStart = seed.life * 0.55
                    let alpha = t < fadeStart ? 1 : 1 - (t - fadeStart) / (seed.life - fadeStart)

                    var g = gc
                    g.opacity = alpha
                    g.translateBy(x: x, y: y)
                    g.rotate(by: .degrees(seed.angle + seed.spin * t))
                    g.scaleBy(x: grow, y: grow)

                    let w = seed.size * 0.62, h = seed.size
                    g.fill(Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h)), with: .color(seedColor))
                    g.fill(Path(ellipseIn: CGRect(x: -w * 0.25, y: -h * 0.35, width: w * 0.3, height: h * 0.3)),
                           with: .color(.white.opacity(0.55)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
