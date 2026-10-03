import AppKit
import SwiftUI

/// Renders the widget offscreen so the layout can be checked without screen-recording permission.
enum Snapshot {
    /// With `seeds`, also draws one frame of the celebration, laid out exactly like the seed overlay window.
    @MainActor
    static func write(to path: String, seeds: Bool = false, minutes: Int = 0, elapsed: Int = 0, collapsed: Bool = false) {
        let timer = PomodoroTimer()
        timer.preview(total: minutes, elapsed: elapsed)
        let margin = SeedPanel.margin
        let start = Layout.windowPoint(Layout.burstCenter(collapsed: collapsed), collapsed: collapsed)
        let origin = CGPoint(x: margin + start.x, y: margin + start.y)
        let content = ZStack(alignment: .topLeading) {
            WidgetView().environmentObject(timer).environmentObject(LoginItem())
                .environmentObject(WidgetState(collapsed: collapsed))
                .padding(seeds ? margin : 0)
            if seeds {
                SeedBurstView(seeds: Seed.bursts(from: origin), startDate: Date().addingTimeInterval(-0.3))
                    .frame(width: Layout.windowSize(collapsed: collapsed).width + margin * 2,
                           height: Layout.windowSize(collapsed: collapsed).height + margin * 2)
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
