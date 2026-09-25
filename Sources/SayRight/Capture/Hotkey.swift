import AppKit
import Carbon.HIToolbox

/// A single system-wide hotkey. Carbon's RegisterEventHotKey is used rather than
/// an NSEvent global monitor because it consumes the keystroke - a monitor would
/// let the key through and type stray characters into the user's document.
@MainActor
final class Hotkey {
    static let shared = Hotkey()

    /// Control-Option-Space by default.
    static let defaultKeyCode = UInt32(kVK_Space)
    static let defaultModifiers = UInt32(controlKey | optionKey)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    private init() {}

    /// Returns false when the system refuses the combination, usually because another
    /// app already owns it. The caller must then put back whatever was working before:
    /// this has already torn the old registration down.
    @discardableResult
    func register(keyCode: UInt32 = defaultKeyCode,
                  modifiers: UInt32 = defaultModifiers,
                  action: @escaping () -> Void) -> Bool {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotkeyEventHandler, 1, &eventType, nil, &eventHandler)

        let id = EventHotKeyID(signature: OSType(0x53595248), id: 1) // 'SYRH'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            dbg("RegisterEventHotKey failed with status \(status)")
            hotKeyRef = nil
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKeyRef = nil
        eventHandler = nil
    }

    fileprivate func fire() { action?() }
}

private func hotkeyEventHandler(_ next: EventHandlerCallRef?,
                                _ event: EventRef?,
                                _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    MainActor.assumeIsolated { Hotkey.shared.fire() }
    return noErr
}
