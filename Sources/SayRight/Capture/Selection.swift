import AppKit
import ApplicationServices

struct TextSelection {
    let text: String
    /// Where the selection is on screen, AppKit coordinates. Used to place the icon.
    let rect: CGRect
    /// The element the text came from, so it can be written back later even if
    /// focus has moved on. Nil when the text came from the clipboard fallback.
    let element: AXUIElement?
    let range: CFRange?
    /// Whether the text can actually be written back. False for page text, code
    /// listings, chat transcripts - anything read-only.
    let isEditable: Bool
    /// The app the text came from, so focus can be handed back before pasting.
    let app: NSRunningApplication?
}

/// How the read was asked for. The automatic path is conservative because the user
/// did not ask for anything; the manual path is permissive because they did.
enum SelectionTrigger {
    case automatic
    case manual
}

enum SelectionReader {
    private enum Outcome {
        case selection(TextSelection)
        /// A password field. Distinct from `unavailable` on purpose: falling back to a
        /// synthetic Cmd+C here would copy the password out of the field.
        case refused
        case unavailable
    }

    /// Reads the current selection from the focused UI element of the frontmost app.
    ///
    /// The clipboard fallback only ever runs on the manual path: it synthesises a
    /// Cmd+C, which would be hostile on every mouse-up.
    @MainActor
    static func read(_ trigger: SelectionTrigger) -> TextSelection? {
        switch readViaAccessibility(trigger) {
        case .selection(let selection):
            return selection
        case .refused:
            return nil
        case .unavailable:
            break
        }

        guard trigger == .manual, Settings.shared.clipboardFallback,
              let text = ClipboardCapture.copySelection(), !text.isBlank else { return nil }

        // No element to inspect here, but the app and the text itself can still be
        // disqualifying, and those checks are the ones that matter most.
        let app = NSWorkspace.shared.frontmostApplication
        let field = FieldContext(bundleID: app?.bundleIdentifier, text: text)
        if case .block(let reason) = verdict(for: field) {
            dbg("blocked in \(app?.localizedName ?? "?"): \(reason)")
            return nil
        }
        return TextSelection(text: text, rect: cursorRect(), element: nil, range: nil,
                             isEditable: true, app: app)
    }

    @MainActor
    private static func verdict(for field: FieldContext) -> SelectionFilter.Verdict {
        SelectionFilter.verdict(for: field,
                                minimumCharacters: Settings.shared.minimumSelectionLength,
                                ignoredApps: Settings.shared.ignoredApps)
    }

    /// Everything the app has told us about the field, for the filters to judge.
    @MainActor
    private static func context(of element: AXUIElement, text: String) -> FieldContext {
        FieldContext(role: AX.string(element, kAXRoleAttribute as String),
                     subrole: AX.string(element, kAXSubroleAttribute as String),
                     identifier: AX.string(element, "AXIdentifier"),
                     title: AX.string(element, kAXTitleAttribute as String),
                     label: AX.string(element, kAXDescriptionAttribute as String),
                     placeholder: AX.string(element, "AXPlaceholderValue"),
                     bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                     text: text)
    }

    @MainActor
    private static func isSecure(_ element: AXUIElement) -> Bool {
        SelectionFilter.isSecureRole(role: AX.string(element, kAXRoleAttribute as String),
                                     subrole: AX.string(element, kAXSubroleAttribute as String))
    }

    /// Roles that are text inputs by definition. Used alongside the settability
    /// check because some apps refuse to report `AXSelectedText` as settable while
    /// still accepting a write.
    static func isEditableRole(_ role: String?) -> Bool {
        switch role {
        case "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField": true
        default: false
        }
    }

    @MainActor
    private static func readViaAccessibility(_ trigger: SelectionTrigger) -> Outcome {
        let systemWide = AXUIElementCreateSystemWide()
        guard var focused = AX.element(systemWide, kAXFocusedUIElementAttribute as String) else {
            enableManualAccessibilityForFrontmostApp()
            return .unavailable
        }

        // Never touch password fields.
        if isSecure(focused) { return .refused }

        var text = AX.string(focused, kAXSelectedTextAttribute as String)
        if text.isNilOrBlank {
            // Some apps (web content, Electron) expose the selection on a descendant.
            // The secure check has to run again here: a login form in Chrome reports
            // the web area as focused and the password field as its descendant, so
            // checking only the outer element would read the password.
            if let inner = AX.element(focused, "AXFocusedUIElement") {
                if isSecure(inner) { return .refused }
                if let innerText = AX.string(inner, kAXSelectedTextAttribute as String),
                   !innerText.isBlank {
                    focused = inner
                    text = innerText
                }
            }
        }
        guard let text, !text.isBlank else {
            enableManualAccessibilityForFrontmostApp()
            return .unavailable
        }

        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        let field = context(of: focused, text: text)

        switch verdict(for: field) {
        case .allow:
            break
        case .block(let reason):
            dbg("blocked in \(appName): \(reason)")
            return .refused
        case .skipAutomatic(let reason):
            guard trigger == .manual else {
                dbg("not shown automatically in \(appName): \(reason)")
                return .refused
            }
        }

        let range = AX.range(focused, kAXSelectedTextRangeAttribute as String)
        let editable = isEditable(focused)
        if !editable {
            dbg("read-only selection in \(appName): role=\(field.role ?? "nil")")
            guard trigger == .manual else { return .refused }
        }
        return .selection(TextSelection(text: text, rect: selectionRect(of: focused, range: range),
                                        element: focused, range: range,
                                        isEditable: editable,
                                        app: NSWorkspace.shared.frontmostApplication))
    }

    /// Can this text be replaced in place? Anything we cannot write to is page
    /// content, not a text box, so the bar has no business appearing over it.
    private static func isEditable(_ element: AXUIElement) -> Bool {
        if AX.isSettable(element, kAXSelectedTextAttribute as String) { return true }
        if AX.isSettable(element, kAXValueAttribute as String) { return true }
        return isEditableRole(AX.string(element, kAXRoleAttribute as String))
    }

    /// Best available rectangle: the selected glyphs, else the whole field, else the pointer.
    @MainActor
    private static func selectionRect(of element: AXUIElement, range: CFRange?) -> CGRect {
        if let range,
           let rect = AX.rect(element, parameterized: kAXBoundsForRangeParameterizedAttribute as String, range: range),
           rect.width > 0 || rect.height > 0 {
            return AX.flipToScreenCoordinates(rect)
        }
        if let frame = AX.frame(element), frame.width > 0 {
            return AX.flipToScreenCoordinates(frame)
        }
        return cursorRect()
    }

    private static func cursorRect() -> CGRect {
        CGRect(origin: NSEvent.mouseLocation, size: .zero)
    }

    /// Chrome and other Chromium apps only publish their accessibility tree once
    /// something asks for it. Harmless everywhere else, but this sits on the mouse-up
    /// path, so ask each process only once.
    @MainActor
    private static var manualAccessibilityAsked: Set<pid_t> = []

    @MainActor
    private static func enableManualAccessibilityForFrontmostApp() {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              !manualAccessibilityAsked.contains(pid) else { return }
        let app = AXUIElementCreateApplication(pid)
        // Only remember it once it worked: an app still launching refuses the write, and
        // caching that failure would disable Chromium accessibility for the whole session.
        if AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue) == .success {
            manualAccessibilityAsked.insert(pid)
        }
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

extension Optional where Wrapped == String {
    var isNilOrBlank: Bool { self?.isBlank ?? true }
}
