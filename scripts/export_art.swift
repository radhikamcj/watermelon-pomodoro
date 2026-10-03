// Turns the full-canvas design layers in PNGs/ (1000 x 560) into the images the app uses.
// The base and watermelon layers are copied as-is; glyphs are cropped tight so they can be laid out live.
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

/// A cleaner play button in the same white crayon style: a rounded triangle about 0.88x as wide
/// as it is tall, with all three corners rounded alike (the hand-drawn one was long and pointy).
/// The edge gets a gentle crayon-like roughness.
func playGlyph() -> CGImage {
    // Size of the triangle before rounding; rounding trims the tips, and the result is cropped
    // to what's visible, landing at the same height as the pause bars (~115 tall x 104 wide).
    let height = 136.0, width = 117.0, cornerRadius = 15.5, pad = 10.0
    let out = Pixels(width: Int(width + pad * 2), height: Int(height + pad * 2))

    // Triangle pointing right, inset by the corner radius (scaled toward its incenter) so that
    // growing it back by the radius gives round corners at the original size.
    let a = (pad, pad), b = (pad, pad + height), c = (pad + width, pad + height / 2)
    func dist(_ p: (Double, Double), _ q: (Double, Double)) -> Double { ((p.0 - q.0) * (p.0 - q.0) + (p.1 - q.1) * (p.1 - q.1)).squareRoot() }
    let la = dist(b, c), lb = dist(c, a), lc = dist(a, b)
    let incenter = ((la * a.0 + lb * b.0 + lc * c.0) / (la + lb + lc), (la * a.1 + lb * b.1 + lc * c.1) / (la + lb + lc))
    let inradius = width * height / (la + lb + lc)
    let k = (inradius - cornerRadius) / inradius
    let tri = [a, b, c].map { (incenter.0 + ($0.0 - incenter.0) * k, incenter.1 + ($0.1 - incenter.1) * k) }

    /// Signed distance to a polygon (negative inside).
    func sdf(_ p: (Double, Double)) -> Double {
        var d = Double.infinity, inside = false
        for i in 0..<tri.count {
            let v = tri[i], w = tri[(i + tri.count - 1) % tri.count]
            let e = (w.0 - v.0, w.1 - v.1), q = (p.0 - v.0, p.1 - v.1)
            let t = max(0, min(1, (q.0 * e.0 + q.1 * e.1) / (e.0 * e.0 + e.1 * e.1)))
            d = min(d, dist(q, (e.0 * t, e.1 * t)))
            if (v.1 > p.1) != (w.1 > p.1), p.0 < (w.0 - v.0) * (p.1 - v.1) / (w.1 - v.1) + v.0 { inside.toggle() }
        }
        return inside ? -d : d
    }

    for y in 0..<out.h {
        for x in 0..<out.w {
            let fx = Double(x) + 0.5, fy = Double(y) + 0.5
            let wobble = (noise(fx, fy, scale: 5, seed: 41) - 0.5) * 2.4 + (noise(fx, fy, scale: 1.6, seed: 43) - 0.5) * 1.2
            let edge = cornerRadius - sdf((fx, fy)) + wobble
            let mask = min(1, max(0, edge / 1.4 + 0.5))
            guard mask > 0 else { continue }
            // Faint crayon grain inside.
            let alpha = 255 * mask * (0.94 + 0.06 * noise(fx, fy, scale: 1.2, seed: 47))
            out.set(x, y, (alpha, alpha, alpha, alpha))   // premultiplied white
        }
    }
    let image = out.image
    return image.cropping(to: visibleBounds(image, padding: 4))!
}

// The card: one hand-drawn base with its speckles built in.
save(load("New base"), "base")

let glyphs = (0...9).map(String.init) + ["colon", "minus", "plus", "pause"]
for name in glyphs {
    let image = load(name)
    // The minus is a single thin stroke, so it gets extra weight to hold its own next to ▶ and +.
    let boost = name == "minus" ? strokeBoost + 5 : strokeBoost
    save(thicken(image.cropping(to: visibleBounds(image))!, by: boost), name)
}

// The watermelon, whole and after each bite (one every half hour). Same crop as the Figma frame:
// the left 469 x 560 of the canvas; the app turns it upright. Keep in sync with Layout.watermelonSize.
let watermelonCrop = CGRect(x: 0, y: 0, width: 469, height: 560)
save(load("New watermelon").cropping(to: watermelonCrop)!, "watermelon")
for (k, name) in ["1 bite", "2 bites", "3 bites"].enumerated() {
    save(load(name).cropping(to: watermelonCrop)!, "watermelon_bite\(k + 1)")
}

save(playGlyph(), "play")

print("Exported art to \(dst.path)")
