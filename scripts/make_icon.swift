// Renders Resources/AppIcon.icns: a watermelon emoji on a soft pink rounded square.
import AppKit

let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bg = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.23, yRadius: rect.width * 0.23)
    NSGradient(starting: NSColor(red: 1, green: 0.78, blue: 0.82, alpha: 1),
               ending: NSColor(red: 1, green: 0.55, blue: 0.64, alpha: 1))!.draw(in: bg, angle: -90)
    let emoji = "🍉" as NSString
    let font = NSFont.systemFont(ofSize: s * 0.52)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let size = emoji.size(withAttributes: attrs)
    emoji.draw(at: NSPoint(x: (s - size.width) / 2, y: (s - size.height) / 2), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
