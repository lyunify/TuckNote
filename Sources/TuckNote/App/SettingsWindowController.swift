import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private(set) var window: NSWindow?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func present() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "TuckNotes Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
