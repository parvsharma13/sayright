import AppKit
import Carbon.HIToolbox
import Observation

/// Persists the hotkey and renders it the way menus do (⌃⌥Space).
@MainActor
@Observable
final class HotkeyStore {
    static let shared = HotkeyStore()

    private let defaults = UserDefaults.standard

    private(set) var keyCode: UInt32 { didSet { defaults.set(Int(keyCode), forKey: "hotkeyCode") } }
    private(set) var modifiers: UInt32 { didSet { defaults.set(Int(modifiers), forKey: "hotkeyModifiers") } }
    /// Why the last attempt to change the hotkey did not take.
    private(set) var lastError: String?

    private var action: (() -> Void)?

    private init() {
        let storedCode = defaults.object(forKey: "hotkeyCode") as? Int
        let storedModifiers = defaults.object(forKey: "hotkeyModifiers") as? Int
        keyCode = UInt32(storedCode ?? Int(Hotkey.defaultKeyCode))
        modifiers = UInt32(storedModifiers ?? Int(Hotkey.defaultModifiers))
    }

    var description: String { Self.describe(keyCode: keyCode, modifiers: modifiers) }

    /// Registers the stored hotkey, falling back to the default if what was stored is
    /// no longer acceptable - an earlier build allowed modifier-free combinations.
    func install(_ action: @escaping () -> Void) {
        self.action = action
        if apply(keyCode: keyCode, modifiers: modifiers) { return }
        _ = apply(keyCode: Hotkey.defaultKeyCode, modifiers: Hotkey.defaultModifiers)
    }

    /// Validates, registers, and only then persists. Puts the previous hotkey back if
    /// the new one is refused, so there is never a window with no hotkey at all.
    @discardableResult
    func apply(keyCode newCode: UInt32, modifiers newModifiers: UInt32) -> Bool {
        guard Self.hasRequiredModifier(newModifiers) else {
            lastError = "Add ⌃, ⌥ or ⌘. Without one, SayRight would swallow that key in every app."
            return false
        }

        // Before Accessibility is granted there is nothing to register with yet; keep
        // the choice so `install` picks it up, rather than discarding it in silence.
        guard let action else {
            keyCode = newCode
            modifiers = newModifiers
            lastError = "Saved. It starts working once SayRight has Accessibility access."
            return true
        }

        let previousCode = keyCode
        let previousModifiers = modifiers

        if Hotkey.shared.register(keyCode: newCode, modifiers: newModifiers, action: action) {
            keyCode = newCode
            modifiers = newModifiers
            lastError = nil
            return true
        }

        lastError = "\(Self.describe(keyCode: newCode, modifiers: newModifiers)) is already taken by another app."
        Hotkey.shared.register(keyCode: previousCode, modifiers: previousModifiers, action: action)
        return false
    }

    /// Shift alone does not count: a global hotkey with no ⌃, ⌥ or ⌘ consumes that key
    /// system-wide, so typing it anywhere would stop working.
    nonisolated static func hasRequiredModifier(_ modifiers: UInt32) -> Bool {
        Int(modifiers) & (controlKey | optionKey | cmdKey) != 0
    }

    nonisolated static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: Int = 0
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.shift) { result |= shiftKey }
        if flags.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }

    nonisolated static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
        var text = ""
        let flags = Int(modifiers)
        if flags & controlKey != 0 { text += "⌃" }
        if flags & optionKey != 0 { text += "⌥" }
        if flags & shiftKey != 0 { text += "⇧" }
        if flags & cmdKey != 0 { text += "⌘" }
        return text + keyName(keyCode)
    }

    nonisolated private static func keyName(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Escape"
        default: break
        }
        // Ask the current keyboard layout what this key types.
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(keyCode)"
        }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        var deadKeys: UInt32 = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeys, characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}
