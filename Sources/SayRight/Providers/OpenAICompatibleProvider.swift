import Foundation

/// Covers OpenAI itself and everything that speaks its chat-completions dialect:
/// Ollama, LM Studio, OpenRouter, Groq, DeepSeek, vLLM, Azure-style gateways.
struct OpenAICompatibleProvider: TextProvider {
    let baseURL: String
    let apiKey: String
    let model: String

    /// macOS App Transport Security blocks plain http to anything but the local
    /// machine, so a remote http endpoint fails with a confusing error. Worth saying
    /// out loud, since the alternative is silently sending a key over cleartext.
    static func isPlaintextRemote(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              url.scheme?.lowercased() == "http",
              let host = url.host?.lowercased() else { return false }
        // Everything NSAllowsLocalNetworking permits: loopback, .local, link-local, and
        // unqualified single-label names like http://ollama:11434.
        let loopback = ["localhost", "127.0.0.1", "::1", "0.0.0.0"]
        if loopback.contains(host) { return false }
        if host.hasSuffix(".local") { return false }
        if !host.contains(".") { return false }
        if host.hasPrefix("169.254.") || host.hasPrefix("fe80:") { return false }
        return true
    }

    func buildRequest(system: String, user: String) throws -> URLRequest {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        guard let url = URL(string: trimmed + "/chat/completions") else {
            throw ProviderError.http(status: 0, message: "Invalid base URL: \(baseURL)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(Body(
            model: model,
            messages: [.init(role: "system", content: system), .init(role: "user", content: user)]
        ))
        return request
    }

    func complete(system: String, user: String) async throws -> Completion {
        let data = try await HTTP.send(try buildRequest(system: system, user: user))
        let parsed = try Self.parse(data)
        return Completion(cleanCompletion(parsed.text), truncated: parsed.truncated)
    }

    static func parse(_ data: Data) throws -> Completion {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              let choice = response.choices.first else {
            throw ProviderError.malformedResponse
        }
        return Completion(choice.message.content, truncated: choice.finish_reason == "length")
    }

    struct Body: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let messages: [Message]
        let stream = false
    }

    private struct Response: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
            let finish_reason: String?
        }
        let choices: [Choice]
    }
}
