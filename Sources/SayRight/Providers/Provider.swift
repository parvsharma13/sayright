import Foundation

struct Completion: Sendable {
    let text: String
    /// The provider stopped because it ran out of output budget, so `text` is cut off
    /// mid-sentence. Replacing a document with a truncated answer loses the user's words,
    /// so this has to be surfaced rather than assumed away.
    let truncated: Bool

    init(_ text: String, truncated: Bool = false) {
        self.text = text
        self.truncated = truncated
    }
}

protocol TextProvider: Sendable {
    /// One-shot completion. No streaming yet; the panel shows a spinner meanwhile.
    func complete(system: String, user: String) async throws -> Completion
}

enum ProviderError: LocalizedError, Equatable {
    case missingAPIKey(String)
    case http(status: Int, message: String)
    case malformedResponse
    case appleModelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let name):
            "No API key for \(name). Add one in SayRight ▸ Settings."
        case .http(let status, let message):
            message.isEmpty ? "The provider returned HTTP \(status)." : "HTTP \(status): \(message)"
        case .malformedResponse:
            "The provider returned a response SayRight could not read."
        case .appleModelUnavailable(let reason):
            reason
        }
    }
}

enum ProviderFactory {
    @MainActor
    static func make(_ settings: Settings = .shared) throws -> any TextProvider {
        let kind = settings.provider
        let model = settings.model(for: kind)
        func key() throws -> String {
            guard let key = Keychain.get(kind.rawValue), !key.isBlank else {
                throw ProviderError.missingAPIKey(kind.displayName)
            }
            return key
        }
        switch kind {
        case .apple:
            return AppleOnDeviceProvider()
        case .openAI:
            return OpenAICompatibleProvider(baseURL: "https://api.openai.com/v1", apiKey: try key(), model: model)
        case .custom:
            return OpenAICompatibleProvider(baseURL: settings.customBaseURL,
                                            apiKey: Keychain.get(kind.rawValue) ?? "",
                                            model: model)
        case .anthropic:
            return AnthropicProvider(apiKey: try key(), model: model)
        case .gemini:
            return GeminiProvider(apiKey: try key(), model: model)
        }
    }
}

extension Error {
    /// Task cancellation surfaces as URLError(.cancelled) once it reaches URLSession.
    var isCancellation: Bool {
        self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}

enum HTTP {
    static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.http(status: http.statusCode, message: errorMessage(from: data))
        }
        return data
    }

    /// Providers all bury their message somewhere under "error"; pull out whatever is there.
    static func errorMessage(from data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(decoding: data.prefix(200), as: UTF8.self)
        }
        if let error = root["error"] as? [String: Any], let message = error["message"] as? String { return message }
        if let error = root["error"] as? String { return error }
        if let message = root["message"] as? String { return message }
        return String(decoding: data.prefix(200), as: UTF8.self)
    }
}

/// Models sometimes wrap the answer in quotes or a code fence despite being told not to.
func cleanCompletion(_ raw: String) -> String {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    if text.hasPrefix("```") {
        var lines = text.components(separatedBy: "\n")
        lines.removeFirst()
        if lines.last?.trimmingCharacters(in: .whitespaces) == "```" { lines.removeLast() }
        text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let pairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("'", "'")]
    for (open, close) in pairs where text.count > 1 && text.first == open && text.last == close {
        // Only unwrap when the quotes really are a wrapper, not part of the text.
        let inner = String(text.dropFirst().dropLast())
        if !inner.contains(close) { text = inner }
        break
    }
    return text
}
