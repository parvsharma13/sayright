import Foundation

struct GeminiProvider: TextProvider {
    let apiKey: String
    let model: String

    func buildRequest(system: String, user: String) throws -> URLRequest {
        let path = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: path) else {
            throw ProviderError.http(status: 0, message: "Invalid model name: \(model)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Header rather than ?key= so the key never lands in a URL or a log.
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(Body(
            system_instruction: .init(parts: [.init(text: system)]),
            contents: [.init(role: "user", parts: [.init(text: user)])]
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
              let candidate = response.candidates.first else {
            throw ProviderError.malformedResponse
        }
        let text = candidate.content.parts.compactMap(\.text).joined()
        guard !text.isEmpty else { throw ProviderError.malformedResponse }
        return Completion(text, truncated: candidate.finishReason == "MAX_TOKENS")
    }

    struct Body: Encodable {
        struct Part: Encodable { let text: String }
        struct Content: Encodable { var role: String? = nil; let parts: [Part] }
        let system_instruction: Content
        let contents: [Content]
    }

    private struct Response: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable { struct Part: Decodable { let text: String? }; let parts: [Part] }
            let content: Content
            let finishReason: String?
        }
        let candidates: [Candidate]
    }
}
