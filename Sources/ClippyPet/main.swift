import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()

application.delegate = delegate
_ = application.setActivationPolicy(.accessory)
application.run()
