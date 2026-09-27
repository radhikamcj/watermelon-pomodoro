import AppKit
import SwiftUI

/// Renders the widget offscreen so the layout can be checked without screen-recording permission.
enum Snapshot {
    /// With `seeds`, also draws one frame of the celebration, laid out exactly like the seed overlay window.
    @MainActor
    static func write(to path: String, seeds: Bool = false, minutes: Int = 0) {
        let timer = PomodoroTimer()
        timer.setMinutes(minutes, for: .focus)
        let margin = SeedPanel.margin
        let origin = CGPoint(x: margin + Layout.seedOrigin.x, y: margin + Layout.seedOrigin.y)
        let content = ZStack(alignment: .topLeading) {
            WidgetView().environmentObject(timer)
                .padding(seeds ? margin : 0)
            if seeds {
                SeedBurstView(seeds: Seed.bursts(from: origin), startDate: Date().addingTimeInterval(-0.3))
                    .frame(width: Layout.windowSize.width + margin * 2, height: Layout.windowSize.height + margin * 2)
            }
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 4
        guard let cgImage = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
