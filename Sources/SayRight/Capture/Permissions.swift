import AppKit
import ApplicationServices
import Observation

/// Accessibility (TCC) trust. Everything SayRight does in other apps depends on it.
@MainActor
@Observable
final class Permissions {
    static let shared = Permissions()

    private(set) var isTrusted = AXIsProcessTrusted()
    /// Called once, when access is granted while the app is already running.
    var onTrusted: (() -> Void)?
    private var timer: Timer?

    private init() {}

    /// Shows the system prompt the first time; afterwards macOS silently ignores it,
    /// which is why `openSystemSettings()` exists as the explicit path.
    func request() {
        // Literal rather than kAXTrustedCheckOptionPrompt: the CF global is a `var`,
        // which Swift 6 rejects as shared mutable state.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// There is no notification for a TCC change, so poll while the user is in Settings.
    func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                let trusted = AXIsProcessTrusted()
                guard trusted != self.isTrusted else { return }
                self.isTrusted = trusted
                if trusted {
                    self.onTrusted?()
                    self.onTrusted = nil
                    // Nothing left to watch for: revoking access kills the app anyway.
                    self.stopPolling()
                }
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
