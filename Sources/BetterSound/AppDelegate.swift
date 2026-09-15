import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar utility: never show a Dock icon or an app switcher entry.
        NSApp.setActivationPolicy(.accessory)
    }
}
