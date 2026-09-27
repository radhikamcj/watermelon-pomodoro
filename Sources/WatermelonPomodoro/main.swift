import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// No Dock icon: the widget lives only as a floating window.
app.setActivationPolicy(.accessory)
app.run()
