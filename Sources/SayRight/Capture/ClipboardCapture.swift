import AppKit
import CoreGraphics

/// Last-resort selection reader for apps that refuse Accessibility text reads
/// (Chromium and Electron builds, Word, some Java apps): synthesise Cmd+C, take
/// the text, then put the user's clipboard back exactly as it was.
@MainActor
enum ClipboardCapture {
    /// A paste restores the previous clipboard after a delay, so the receiving app has
    /// time to read it. That pending restore must not fire inside the nested run loop
    /// below, or the change it makes would be mistaken for the copy we are waiting on.
    private static var pendingRestore: DispatchWorkItem?
    private static var pendingSnapshot: [[NSPasteboard.PasteboardType: Data]]?

    static func copySelection(timeout: TimeInterval = 0.4) -> String? {
        flushPendingRestore()
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        let countBefore = pasteboard.changeCount

        sendCommandKey(virtualKey: 0x08) // "c"

        let deadline = Date().addingTimeInterval(timeout)
        while pasteboard.changeCount == countBefore, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        let text = pasteboard.changeCount == countBefore ? nil : pasteboard.string(forType: .string)
        restore(saved, to: pasteboard)
        return text
    }

    /// Pastes `text` over the current selection in the frontmost app, restoring the clipboard after.
    static func paste(_ text: String) {
        flushPendingRestore()
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        sendCommandKey(virtualKey: 0x09) // "v"

        // The receiving app reads the pasteboard asynchronously; give it a beat.
        pendingSnapshot = saved
        let work = DispatchWorkItem { flushPendingRestore() }
        pendingRestore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Puts the user's clipboard back now, whether or not the timer has fired.
    private static func flushPendingRestore() {
        pendingRestore?.cancel()
        pendingRestore = nil
        guard let snapshot = pendingSnapshot else { return }
        pendingSnapshot = nil
        restore(snapshot, to: NSPasteboard.general)
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { contents[type] = data }
            }
            return contents
        }
    }

    private static func restore(_ snapshot: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        pasteboard.writeObjects(snapshot.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents { item.setData(data, forType: type) }
            return item
        })
    }

    private static func sendCommandKey(virtualKey: CGKeyCode) {
        // .privateState, not .combinedSessionState: the latter merges the modifiers the
        // user is physically holding into the synthetic event, so the Ctrl+Opt of the
        // hotkey would turn this into Ctrl+Opt+Cmd+C and the copy would not happen.
        let source = CGEventSource(stateID: .privateState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
