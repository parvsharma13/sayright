import AppKit
import Observation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
private final class SettingsUIState {
    enum Outcome { case idle, running, ok(String), failed(String) }
    var outcome: Outcome = .idle
    /// Registering a login item can fail; saying nothing leaves a toggle that
    /// silently snaps back.
    var loginItemError: String?
}

struct SettingsView: View {
    private let test = SettingsUIState()

    private var settings: Settings { .shared }
    private var keys: KeyStore { .shared }
    private var hotkey: HotkeyStore { .shared }

    private static let languages = ["Same as input", "English (US)", "English (UK)", "French", "German",
                                    "Spanish", "Italian", "Portuguese", "Dutch", "Hindi", "Japanese",
                                    "Korean", "Chinese (Simplified)"]

    var body: some View {
        Form {
            Section("Model") {
                Picker("Provider", selection: bind(\.provider)) {
                    ForEach(ProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                .help("Where your text is sent. Apple (on-device) never sends it anywhere; the others use your own API key.")

                if settings.provider.needsAPIKey {
                    SecureField("API key", text: Binding(
                        get: { keys.key(for: settings.provider) },
                        set: { keys.setKey($0, for: settings.provider) }
                    ))
                    .help("Stored in your macOS Keychain, separately for each provider. Never written to a file.")
                    keyStatus
                }

                if settings.provider == .custom {
                    TextField("Base URL", text: bind(\.customBaseURL))
                        .help("Anything that speaks the OpenAI chat-completions API: Ollama, LM Studio, OpenRouter, vLLM.")

                    if OpenAICompatibleProvider.isPlaintextRemote(settings.customBaseURL) {
                        Label("macOS blocks plain http to remote hosts, and it would send your key in cleartext. Use https, or a server on this machine.",
                              systemImage: "lock.open.trianglebadge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if settings.provider != .apple {
                    LabeledContent("Model") {
                        VStack(alignment: .leading, spacing: 4) {
                            ModelComboBox(options: settings.provider.knownModels,
                                          value: settings.model(for: settings.provider)) { model in
                                settings.setModel(model, for: settings.provider)
                            }
                            .frame(height: 24)
                            .help("Pick a model or type any name your provider accepts.")
                            Text(settings.provider.modelHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Button("Test") { runTest() }
                        .help("Send one short sentence to this provider and show what comes back.")
                    switch test.outcome {
                    case .idle:
                        EmptyView()
                    case .running:
                        ProgressView().controlSize(.small)
                    case .ok(let text):
                        Label(text, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).lineLimit(1)
                    case .failed(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).lineLimit(2)
                    }
                }
            }

            Section("Writing") {
                Picker("Output language", selection: Binding(
                    get: { settings.outputLanguage.isEmpty ? Self.languages[0] : settings.outputLanguage },
                    set: { settings.outputLanguage = $0 == Self.languages[0] ? "" : $0 }
                )) {
                    ForEach(Self.languages, id: \.self) { Text($0).tag($0) }
                }
                .help("What language results come back in. \"Same as input\" leaves your language alone; anything else also translates.")
            }

            Section("Where not to appear") {
                Stepper(value: bind(\.minimumSelectionLength), in: 1...200) {
                    Text("Ignore selections under \(settings.minimumSelectionLength) characters")
                }
                .help("Stops the bar appearing on a stray double-click. The hotkey still works on any selection.")

                ForEach(settings.ignoredApps.sorted(), id: \.self) { bundleID in
                    HStack {
                        Text(Self.appName(for: bundleID))
                        Spacer()
                        Button("Remove") { settings.ignoredApps.remove(bundleID) }
                            .buttonStyle(.accessoryBar)
                            .help("Let SayRight work in this app again")
                    }
                }

                HStack {
                    Button("Add App…") { addIgnoredApp() }
                        .help("SayRight will not read anything in the app you choose.")
                    Spacer()
                    if settings.ignoredApps != Settings.defaultIgnoredApps {
                        Button("Restore defaults") { settings.ignoredApps = Settings.defaultIgnoredApps }
                    }
                }

                Text("SayRight never reads anything in these apps. Password and card fields are skipped everywhere, always. Address bars, search fields and very short selections are skipped automatically but still reachable with the hotkey.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Behaviour") {
                LabeledContent("Hotkey") {
                    VStack(alignment: .leading, spacing: 4) {
                        HotkeyRecorder { keyCode, modifiers in
                            hotkey.apply(keyCode: keyCode, modifiers: modifiers)
                        }
                        .frame(width: 120, height: 24)
                        .help("Click, then press a combination including ⌃, ⌥ or ⌘. Runs SayRight on the current selection from anywhere, including apps where the bar does not appear.")

                        if let error = hotkey.lastError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Toggle("Use the clipboard when an app blocks Accessibility", isOn: bind(\.clipboardFallback))
                    .help("Needed for Chrome, Electron apps and Word. SayRight copies the selection and puts your clipboard back.")

                Toggle("Launch at login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { enabled in setLaunchAtLogin(enabled) }
                ))
                .help("Start SayRight automatically when you log in.")

                if let error = test.loginItemError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                Text("Your text is only sent when you pick an action, and only to the provider above. Apple (on-device) sends nothing anywhere. SayRight has no telemetry.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Keys are per provider, and pasting one into the wrong provider is an easy
    /// mistake to make silently - so name the provider it was stored against.
    @ViewBuilder
    private var keyStatus: some View {
        let provider = settings.provider
        if keys.saveFailed(for: provider) {
            Label("macOS refused to store this key in the Keychain.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
        } else if keys.key(for: provider).isEmpty {
            Text("No key saved for \(provider.displayName).")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Label("Saved in your Keychain for \(provider.displayName).", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        }
    }

    /// Hand-rolled because @State and friends need the SwiftUIMacros plugin, which
    /// only ships with Xcode. See README.
    private func bind<Value>(_ keyPath: ReferenceWritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(get: { Settings.shared[keyPath: keyPath] },
                set: { Settings.shared[keyPath: keyPath] = $0 })
    }

    /// Bundle identifiers mean nothing to most people, so show the app's real name
    /// when it is installed.
    private static func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func addIgnoredApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Ignore"
        panel.message = "SayRight will not read selections in the apps you choose."
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier {
                settings.ignoredApps.insert(bundleID)
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            test.loginItemError = nil
        } catch {
            test.loginItemError = "Could not \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
        }
    }

    private func runTest() {
        test.outcome = .running
        Task {
            do {
                let provider = try ProviderFactory.make(settings)
                let result = try await provider.complete(
                    system: Action.fixGrammar.systemPrompt(outputLanguage: settings.outputLanguage),
                    user: "she dont like apple's"
                )
                test.outcome = .ok(result.text)
            } catch {
                test.outcome = .failed(error.localizedDescription)
            }
        }
    }
}
