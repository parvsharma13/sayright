import AppKit
import SwiftUI

/// Shows SwiftUI views in ordinary windows from an agent (LSUIElement) app, where
/// SwiftUI's own `openWindow` has no scene to attach to at launch. One window per id.
@MainActor
enum WindowHost {
    private static var windows: [String: NSWindow] = [:]

    static func show(_ id: String, title: String, content: @autoclosure () -> some View) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
