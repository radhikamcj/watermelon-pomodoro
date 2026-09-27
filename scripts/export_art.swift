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

for name in ["white_bg", "pink_bg", "border"] {
    save(load(name), name)
}

let glyphs = (0...9).map(String.init) + ["colon", "minus", "plus", "play", "pause"]
for name in glyphs {
    let image = load(name)
    save(thicken(image.cropping(to: visibleBounds(image))!, by: strokeBoost), name)
}

// The slice has a few pale smudges around it on the canvas; keep just the slice.
// Keep in sync with WidgetView.Layout.watermelonRect.
save(load("watermelon").cropping(to: CGRect(x: 14, y: 127, width: 443, height: 369))!, "watermelon")

print("Exported art to \(dst.path)")
