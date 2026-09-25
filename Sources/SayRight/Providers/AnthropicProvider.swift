import Foundation

struct AnthropicProvider: TextProvider {
    let apiKey: String
    let model: String
    /// Generous enough that "make longer" on a large selection is not cut off, and
    /// within the output limit of every model in the picker.
    var maxTokens = 16_384

    func buildRequest(system: String, user: String) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(Body(
            model: model, max_tokens: maxTokens, system: system,
            messages: [.init(role: "user", content: user)]
        ))
        return request
    }

    func complete(system: String, user: String) async throws -> Completion {
        let data = try await HTTP.send(try buildRequest(system: system, user: user))
        let parsed = try Self.parse(data)
        return Completion(cleanCompletion(parsed.text), truncated: parsed.truncated)
    }

    static func parse(_ data: Data) throws -> Completion {
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw ProviderError.malformedResponse
        }
        let text = response.content.compactMap(\.text).joined()
        guard !text.isEmpty else { throw ProviderError.malformedResponse }
        return Completion(text, truncated: response.stop_reason == "max_tokens")
    }

    struct Body: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
    }

    private struct Response: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
        let stop_reason: String?
    }
}
