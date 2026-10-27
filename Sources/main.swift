import AppKit

// Keep the delegate alive for the entire app lifetime.
let app = NSApplication.shared
let delegate = MenuBarApp()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Menu bar only: no Dock icon.
app.run()
