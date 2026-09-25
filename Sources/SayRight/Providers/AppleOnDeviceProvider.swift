import FoundationModels

/// Apple Intelligence's on-device model: no key, no network, no cost.
struct AppleOnDeviceProvider: TextProvider {
    func complete(system: String, user: String) async throws -> Completion {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw ProviderError.appleModelUnavailable(Self.explain(reason))
        @unknown default:
            throw ProviderError.appleModelUnavailable("The on-device model is unavailable.")
        }
        let session = LanguageModelSession(model: model, instructions: system)
        let response = try await session.respond(to: user)
        // FoundationModels does not report a truncation reason.
        return Completion(cleanCompletion(response.content))
    }

    static func explain(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "This Mac does not support Apple Intelligence. Pick another provider in Settings."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in System Settings, or pick another provider."
        case .modelNotReady:
            "The on-device model is still downloading. Try again shortly."
        @unknown default:
            "The on-device model is unavailable. Pick another provider in Settings."
        }
    }
}
