import Observation

/// Observable mirror of the Keychain, so SwiftUI can bind to API keys.
@MainActor
@Observable
final class KeyStore {
    static let shared = KeyStore()

    private var cache: [String: String] = [:]
    /// Set when the Keychain refused a write, so the UI can say so instead of lying.
    private(set) var failedToSave: Set<String> = []

    private init() {}

    func key(for kind: ProviderKind) -> String {
        if let cached = cache[kind.rawValue] { return cached }
        let stored = Keychain.get(kind.rawValue) ?? ""
        cache[kind.rawValue] = stored
        return stored
    }

    func setKey(_ value: String, for kind: ProviderKind) {
        cache[kind.rawValue] = value
        Keychain.set(value, for: kind.rawValue)
        // Read it straight back: a silent SecItemAdd failure would otherwise look
        // exactly like a saved key until the next request fails.
        if value.isEmpty || Keychain.get(kind.rawValue) == value {
            failedToSave.remove(kind.rawValue)
        } else {
            failedToSave.insert(kind.rawValue)
        }
    }

    func saveFailed(for kind: ProviderKind) -> Bool { failedToSave.contains(kind.rawValue) }
}
