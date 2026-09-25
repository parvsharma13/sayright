import AppKit
import ApplicationServices

enum TextWriter {
    /// Puts `text` where the selection was. Accessibility first because it is
    /// silent and precise; paste second because plenty of apps ignore the first.
    @MainActor
    static func replace(_ text: String, in selection: TextSelection) {
        // The accessibility write addresses the element directly, so it needs no
        // activation. Only the paste fallback cares which app is frontmost.
        if let element = selection.element,
           AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success,
           verify(element, matches: text) {
            return
        }
        paste(text, into: selection.app)
    }

    /// `NSRunningApplication.activate()` returns before the app is actually frontmost,
    /// so posting Cmd+V in the same run-loop turn can paste into the wrong window.
    @MainActor
    private static func paste(_ text: String, into app: NSRunningApplication?) {
        guard let app, !app.isActive else {
            ClipboardCapture.paste(text)
            return
        }
        app.activate()
        Task { @MainActor in
            var waited = 0
            while !app.isActive, waited < 20 {
                try? await Task.sleep(for: .milliseconds(50))
                waited += 1
            }
            guard app.isActive else {
                // Pasting now would land in whatever is frontmost instead. Leave the
                // result on the clipboard so it is one Cmd+V away rather than lost.
                dbg("\(app.localizedName ?? "app") did not reactivate; left the result on the clipboard")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                return
            }
            ClipboardCapture.paste(text)
        }
    }

    /// An app can return success and change nothing, so read the selection back.
    /// A shrunk or moved selection also counts as success - many apps collapse
    /// the caret after a programmatic edit.
    private static func verify(_ element: AXUIElement, matches text: String) -> Bool {
        guard let now = AX.string(element, kAXSelectedTextAttribute as String) else { return true }
        return now == text || now.isBlank
    }
}
