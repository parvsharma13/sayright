import Foundation
import Observation

enum ProviderKind: String, CaseIterable, Identifiable {
    case apple, openAI, anthropic, gemini, custom
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apple (on-device)"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Google Gemini"
        case .custom: "OpenAI-compatible"
        }
    }

    var needsAPIKey: Bool { self != .apple }

    /// Suggestions for the model field, newest/most capable first. The field stays
    /// editable: a provider can ship a new model without SayRight needing a release.
    /// Checked against the provider docs on 2026-09-14.
    var knownModels: [String] {
        switch self {
        case .apple:
            []
        case .openAI:
            ["gpt-6-astra", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"]
        case .anthropic:
            ["claude-fable-5-1", "claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5"]
        case .gemini:
            ["gemini-3.8-flash", "gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-2.5-flash"]
        case .custom:
            ["llama3.1", "qwen2.5", "mistral", "gemma3"]
        }
    }

    /// Editing is short work, so the cheapest capable model is the right default.
    var defaultModel: String {
        switch self {
        case .apple: ""
        case .openAI: "gpt-5.6-luna"
        case .anthropic: "claude-haiku-4-5"
        case .gemini: "gemini-3.5-flash-lite"
        case .custom: "llama3.1"
        }
    }

    /// One line under the model field, so the list is not just opaque identifiers.
    var modelHint: String {
        switch self {
        case .apple:
            ""
        case .openAI:
            "luna is the cheapest, sol the flagship, astra the most capable."
        case .anthropic:
            "haiku is the fastest and cheapest, opus and fable the strongest."
        case .gemini:
            "flash-lite is the cheapest, 3.8-flash the most capable."
        case .custom:
            "Whatever your server has loaded - type any name it accepts."
        }
    }
}

/// User preferences. Plain UserDefaults; API keys live in the Keychain instead.
@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    var provider: ProviderKind { didSet { defaults.set(provider.rawValue, forKey: "provider") } }
    /// Empty means "reply in the same language as the input".
    var outputLanguage: String { didSet { defaults.set(outputLanguage, forKey: "outputLanguage") } }
    var clipboardFallback: Bool { didSet { defaults.set(clipboardFallback, forKey: "clipboardFallback") } }
    var customBaseURL: String { didSet { defaults.set(customBaseURL, forKey: "customBaseURL") } }
    /// Below this, a selection is almost always a stray double-click.
    var minimumSelectionLength: Int { didSet { defaults.set(minimumSelectionLength, forKey: "minimumSelectionLength") } }
    /// Bundle identifiers SayRight stays out of entirely.
    var ignoredApps: Set<String> { didSet { defaults.set(Array(ignoredApps).sorted(), forKey: "ignoredApps") } }
    private var models: [String: String] { didSet { defaults.set(models, forKey: "models") } }

    private init() {
        defaults.register(defaults: ["clipboardFallback": true])
        provider = ProviderKind(rawValue: defaults.string(forKey: "provider") ?? "") ?? .apple
        outputLanguage = defaults.string(forKey: "outputLanguage") ?? ""
        clipboardFallback = defaults.bool(forKey: "clipboardFallback")
        customBaseURL = defaults.string(forKey: "customBaseURL") ?? "http://localhost:11434/v1"
        models = defaults.dictionary(forKey: "models") as? [String: String] ?? [:]
        minimumSelectionLength = defaults.object(forKey: "minimumSelectionLength") as? Int ?? 3
        // nil means never configured, as opposed to deliberately emptied.
        ignoredApps = (defaults.array(forKey: "ignoredApps") as? [String]).map(Set.init)
            ?? Settings.defaultIgnoredApps
    }

    /// Apps where a writing assistant is never the right answer: secrets live in the
    /// first group, and the rest take commands rather than prose.
    nonisolated static let defaultIgnoredApps: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.runningwithcrayons.Alfred",
        "com.raycast.macos",
        "com.apple.Spotlight",
    ]

    func model(for kind: ProviderKind) -> String {
        let stored = models[kind.rawValue] ?? ""
        return stored.isEmpty ? kind.defaultModel : stored
    }

    func setModel(_ model: String, for kind: ProviderKind) {
        models[kind.rawValue] = model
    }
}
