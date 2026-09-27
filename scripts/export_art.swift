// Turns the full-canvas design layers in PNGs/ (1000 x 560) into the images the app uses.
// Background layers are copied as-is; glyphs are cropped tight so they can be laid out live.
// Run from the project root: swift scripts/export_art.swift
import AppKit

let src = URL(fileURLWithPath: "PNGs")
let dst = URL(fileURLWithPath: "Resources/Art")
try? FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)

func load(_ name: String) -> CGImage {
    NSBitmapImageRep(data: try! Data(contentsOf: src.appendingPathComponent("\(name).png")))!.cgImage!
}

func save(_ image: CGImage, _ name: String) {
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! data.write(to: dst.appendingPathComponent("\(name).png"))
}

/// Bounding box (top-left origin) of pixels that are meaningfully visible.
func visibleBounds(_ image: CGImage, padding: Int = 4) -> CGRect {
    let w = image.width, h = image.height
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let d = ctx.data!.assumingMemoryBound(to: UInt8.self)
    var x0 = w, x1 = 0, y0 = h, y1 = 0
    for y in 0..<h { for x in 0..<w where d[(y * w + x) * 4 + 3] > 40 {
        x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
    }}
    return CGRect(x: max(0, x0 - padding), y: max(0, y0 - padding),
                  width: min(w, x1 + padding + 1) - max(0, x0 - padding),
                  height: min(h, y1 + padding + 1) - max(0, y0 - padding))
}

/// Makes a stroke bolder by stamping it around a small circle (a soft "dilate"),
/// which keeps the crayon grain on the edges.
func thicken(_ image: CGImage, by radius: Int) -> CGImage {
    let w = image.width + radius * 2, h = image.height + radius * 2
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let r = CGFloat(radius)
    for ring in [r, r * 0.5] {
        for step in 0..<24 {
            let a = CGFloat(step) / 24 * 2 * .pi
            ctx.draw(image, in: CGRect(x: r + cos(a) * ring, y: r + sin(a) * ring,
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        }
    }
    ctx.draw(image, in: CGRect(x: r, y: r, width: CGFloat(image.width), height: CGFloat(image.height)))
    return ctx.makeImage()!
}

/// How much bolder the numbers and controls are than the original drawings, in design pixels.
let strokeBoost = 6

/// The smoothed border: a rounded rectangle fitted to the median of the hand-drawn stroke on each side.
enum Outline {
    static let left = 36.0, right = 948.0, top = 45.5, bottom = 530.5
    static let radius = 58.0, thickness = 26.0
    static let cx = (left + right) / 2, cy = (top + bottom) / 2
    static let hx = (right - left) / 2, hy = (bottom - top) / 2

    /// Signed distance to the stroke's centerline (negative inside the card).
    static func sdf(_ x: Double, _ y: Double) -> Double {
        let qx = abs(x - cx) - (hx - radius), qy = abs(y - cy) - (hy - radius)
        let outside = (max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0)).squareRoot()
        return outside + min(max(qx, qy), 0) - radius
    }
}

/// Pixel access for an image, top-left origin, premultiplied RGBA 0...255.
struct Pixels {
    let w: Int, h: Int
    let data: UnsafeMutablePointer<UInt8>
    let context: CGContext

    init(_ image: CGImage) { self.init(width: image.width, height: image.height); context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h)) }

    init(width: Int, height: Int) {
        w = width; h = height
        context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Bitmap memory is top-down, so rows here match the image's top-left origin.
        data = context.data!.assumingMemoryBound(to: UInt8.self)
    }

    /// Bilinear sample at a point in pixel coordinates.
    func sample(_ x: Double, _ y: Double) -> (Double, Double, Double, Double) {
        let x0 = Int(floor(x - 0.5)), y0 = Int(floor(y - 0.5))
        let fx = x - 0.5 - Double(x0), fy = y - 0.5 - Double(y0)
        var out = (0.0, 0.0, 0.0, 0.0)
        for (dx, dy, wt) in [(0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)] {
            let sx = x0 + dx, sy = y0 + dy
            guard sx >= 0, sx < w, sy >= 0, sy < h, wt > 0 else { continue }
            let i = (sy * w + sx) * 4
            out.0 += Double(data[i]) * wt; out.1 += Double(data[i + 1]) * wt
            out.2 += Double(data[i + 2]) * wt; out.3 += Double(data[i + 3]) * wt
        }
        return out
    }

    func set(_ x: Int, _ y: Int, _ c: (Double, Double, Double, Double)) {
        let i = (y * w + x) * 4
        data[i] = UInt8(max(0, min(255, c.0.rounded()))); data[i + 1] = UInt8(max(0, min(255, c.1.rounded())))
        data[i + 2] = UInt8(max(0, min(255, c.2.rounded()))); data[i + 3] = UInt8(max(0, min(255, c.3.rounded())))
    }

    var image: CGImage { context.makeImage()! }
}

/// Smooth random value in 0...1 that varies over roughly `scale` pixels (value noise).
func noise(_ x: Double, _ y: Double, scale: Double, seed: UInt64) -> Double {
    func hash(_ ix: Int, _ iy: Int) -> Double {
        var z = UInt64(bitPattern: Int64(ix &* 73856093 ^ iy &* 19349663)) &+ seed
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) &* 0x94d049bb133111eb; z ^= z >> 31
        return Double(z % 10_000) / 10_000
    }
    let sx = x / scale, sy = y / scale
    let ix = Int(floor(sx)), iy = Int(floor(sy))
    var fx = sx - Double(ix), fy = sy - Double(iy)
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    let top = hash(ix, iy) * (1 - fx) + hash(ix + 1, iy) * fx
    let bottom = hash(ix, iy + 1) * (1 - fx) + hash(ix + 1, iy + 1) * fx
    return top * (1 - fy) + bottom * fy
}

/// Evens out the hand-drawn border: the stroke follows the smooth `Outline` at one thickness,
/// filled with the crayon texture copied from the middle of the original stroke. For each point
/// on the new outline it looks straight across the original stroke at that spot and stretches
/// that slice to the even thickness. The edges get a gentle crayon-like roughness of their own.
func smoothBorder(_ image: CGImage) -> CGImage {
    let src = Pixels(image), out = Pixels(width: image.width, height: image.height)
    let half = Outline.thickness / 2

    /// Where the original stroke starts and ends along a line (in steps from `origin`), if it's there.
    func strokeSpan(from origin: (Double, Double), along n: (Double, Double)) -> (Double, Double)? {
        var spans: [(Double, Double)] = []
        var start: Double?
        for step in stride(from: -48.0, through: 48.0, by: 1) {
            let solid = src.sample(origin.0 + n.0 * step, origin.1 + n.1 * step).3 > 90
            if solid, start == nil { start = step }
            if !solid, let s = start { spans.append((s, step - 1)); start = nil }
        }
        if let s = start { spans.append((s, 48)) }
        // The stroke closest to the new centerline, and only if it's substantial enough to stretch.
        return spans.filter { $0.1 - $0.0 >= 13 }.min { abs($0.0 + $0.1) < abs($1.0 + $1.1) }
    }

    /// Crayon texture for a point on the new stroke, borrowing from the mirrored side where the drawing has a gap.
    func texture(_ x: Double, _ y: Double, _ d: Double) -> (Double, Double, Double, Double)? {
        for (mx, my) in [(x, y), (2 * Outline.cx - x, y), (x, 2 * Outline.cy - y), (2 * Outline.cx - x, 2 * Outline.cy - y)] {
            let e = 0.25
            var n = (Outline.sdf(mx + e, my) - Outline.sdf(mx - e, my), Outline.sdf(mx, my + e) - Outline.sdf(mx, my - e))
            let len = (n.0 * n.0 + n.1 * n.1).squareRoot()
            guard len > 0 else { continue }
            n = (n.0 / len, n.1 / len)
            let onLine = (mx - d * n.0, my - d * n.1)
            guard let span = strokeSpan(from: onLine, along: n) else { continue }
            // Stay in the body of the original stroke; its ragged edges are what we're replacing.
            let u = min(0.88, max(0.12, (d + half) / Outline.thickness))
            let t = span.0 + u * (span.1 - span.0)
            return src.sample(onLine.0 + n.0 * t, onLine.1 + n.1 * t)
        }
        return nil
    }

    for y in 0..<out.h {
        for x in 0..<out.w {
            let fx = Double(x) + 0.5, fy = Double(y) + 0.5
            let d = Outline.sdf(fx, fy)
            guard abs(d) <= half + 4 else { continue }
            // Gentle wobble on each edge (a couple of pixels over a few px), plus fine grain.
            let wobble = (noise(fx, fy, scale: 5, seed: d < 0 ? 11 : 29) - 0.5) * 2.6
                + (noise(fx, fy, scale: 1.6, seed: d < 0 ? 5 : 7) - 0.5) * 1.4
            let edge = half - abs(d) + wobble
            let mask = min(1, max(0, edge / 1.4 + 0.5))
            guard mask > 0, let c = texture(fx, fy, d) else { continue }
            out.set(x, y, (c.0 * mask, c.1 * mask, c.2 * mask, c.3 * mask))
        }
    }
    return out.image
}

/// Fits a background layer to the smoothed border: trims anything poking outside it and, with
/// `fill`, paints the gaps between the background's hand-drawn edge and the border in that color.
func fitBackground(_ image: CGImage, fill: (Double, Double, Double)? = nil) -> CGImage {
    let src = Pixels(image), out = Pixels(width: image.width, height: image.height)
    let half = Outline.thickness / 2
    for y in 0..<out.h {
        for x in 0..<out.w {
            let fx = Double(x) + 0.5, fy = Double(y) + 0.5
            let d = Outline.sdf(fx, fy)
            guard d < 0 else { continue }   // under or outside the border's centerline: never visible
            var c = src.sample(fx, fy)
            // Near the border, fill whatever the drawing left uncovered (not the specks further in).
            if let fill, d > -(half + 30) {
                let gap = 1 - c.3 / 255
                c = (c.0 + fill.0 * gap, c.1 + fill.1 * gap, c.2 + fill.2 * gap, c.3 + 255 * gap)
            }
            out.set(x, y, c)
        }
    }
    return out.image
}

save(fitBackground(load("white_bg")), "white_bg")
save(fitBackground(load("pink_bg"), fill: (255, 176, 176)), "pink_bg")   // #FFB0B0, the background's average
save(smoothBorder(load("border")), "border")

let glyphs = (0...9).map(String.init) + ["colon", "minus", "plus", "play", "pause"]
for name in glyphs {
    let image = load(name)
    // The minus is a single thin stroke, so it gets extra weight to hold its own next to ▶ and +.
    let boost = name == "minus" ? strokeBoost + 5 : strokeBoost
    save(thicken(image.cropping(to: visibleBounds(image))!, by: boost), name)
}

// Same crop as the Figma frame: the left 469 x 560 of the canvas. The app rotates it upright.
// Keep in sync with WidgetView.Layout.watermelonSize.
save(load("watermelon").cropping(to: CGRect(x: 0, y: 0, width: 469, height: 560))!, "watermelon")

print("Exported art to \(dst.path)")
