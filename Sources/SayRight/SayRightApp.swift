import AppKit
import SwiftUI

@main
struct SayRightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("SayRight",
                     systemImage: Coordinator.shared.isBusy ? "ellipsis.circle" : "text.badge.checkmark") {
            if !Permissions.shared.isTrusted {
                Button("Grant Accessibility Access…") { AppDelegate.showOnboarding() }
                Divider()
            }
            Button("Fix Selected Text…") { Coordinator.shared.triggerManually() }
                .help("Show the action bar for whatever is selected right now, same as the hotkey.")
            Divider()
            Button("Settings…") { AppDelegate.showSettings() }
            Button("About SayRight") { AppDelegate.showOnboarding() }
            Divider()
            Button("Quit SayRight") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            removeLegacyLog()
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            dbg("SayRight \(version) launched, accessibility trusted=\(Permissions.shared.isTrusted)")
            Permissions.shared.startPolling()
            if Permissions.shared.isTrusted {
                Coordinator.shared.start()
            } else {
                AppDelegate.showOnboarding()
                // Start as soon as the user grants access, without a relaunch.
                Permissions.shared.onTrusted = { Coordinator.shared.start() }
            }
        }
    }

    @MainActor
    static func showOnboarding() {
        WindowHost.show("onboarding", title: "SayRight", content: OnboardingView())
    }

    @MainActor
    static func showSettings() {
        WindowHost.show("settings", title: "SayRight Settings", content: SettingsView())
    }
}
