import Carbon.HIToolbox
import Foundation
import Testing
@testable import SayRight

@Test func systemPromptKeepsInputLanguageByDefault() {
    let prompt = Action.fixGrammar.systemPrompt(outputLanguage: "")
    #expect(prompt.contains("same language as the input"))
    #expect(prompt.contains("Return only the edited text"))
}

@Test func systemPromptHonoursLanguageOverride() {
    let prompt = Action.rewrite.systemPrompt(outputLanguage: "British English")
    #expect(prompt.contains("Reply in British English"))
    #expect(!prompt.contains("same language as the input"))
}

@Test func openAIRequestShape() throws {
    let provider = OpenAICompatibleProvider(baseURL: "https://api.openai.com/v1/", apiKey: "k", model: "m")
    let request = try provider.buildRequest(system: "sys", user: "hello")
    #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer k")
    let body = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: Any]
    let messages = body?["messages"] as? [[String: String]]
    #expect(messages?.first?["role"] == "system")
    #expect(messages?.last?["content"] == "hello")
}

@Test func localEndpointSendsNoAuthorizationHeader() throws {
    let provider = OpenAICompatibleProvider(baseURL: "http://localhost:11434/v1", apiKey: "", model: "llama3.1")
    let request = try provider.buildRequest(system: "s", user: "u")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
}

@Test func anthropicRequestShape() throws {
    let provider = AnthropicProvider(apiKey: "k", model: "claude-haiku-4-5-20251001")
    let request = try provider.buildRequest(system: "sys", user: "hello")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == "k")
    #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    let body = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: Any]
    #expect(body?["system"] as? String == "sys")
}

@Test func geminiKeyTravelsInHeaderNotURL() throws {
    let provider = GeminiProvider(apiKey: "secret", model: "gemini-2.5-flash")
    let request = try provider.buildRequest(system: "sys", user: "hello")
    #expect(request.url?.absoluteString.contains("secret") == false)
    #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "secret")
}

@Test func parsesEachProviderResponse() throws {
    let openAI = #"{"choices":[{"message":{"role":"assistant","content":"Fixed."}}]}"#
    #expect(try OpenAICompatibleProvider.parse(Data(openAI.utf8)).text == "Fixed.")

    let anthropic = #"{"content":[{"type":"text","text":"Fixed."}]}"#
    #expect(try AnthropicProvider.parse(Data(anthropic.utf8)).text == "Fixed.")

    let gemini = #"{"candidates":[{"content":{"parts":[{"text":"Fixed."}]}}]}"#
    #expect(try GeminiProvider.parse(Data(gemini.utf8)).text == "Fixed.")
}

@Test func rejectsResponsesItCannotRead() {
    #expect(throws: ProviderError.malformedResponse) {
        try OpenAICompatibleProvider.parse(Data(#"{"choices":[]}"#.utf8))
    }
    #expect(throws: ProviderError.malformedResponse) {
        try AnthropicProvider.parse(Data(#"{"content":[{"type":"thinking"}]}"#.utf8))
    }
}

@Test func surfacesProviderErrorMessages() {
    let body = Data(#"{"error":{"message":"Incorrect API key provided"}}"#.utf8)
    #expect(HTTP.errorMessage(from: body) == "Incorrect API key provided")
    #expect(HTTP.errorMessage(from: Data("not json".utf8)) == "not json")
}

@Test func stripsWrappersModelsAddAnyway() {
    #expect(cleanCompletion("  Hello there.  ") == "Hello there.")
    #expect(cleanCompletion("\"Hello there.\"") == "Hello there.")
    #expect(cleanCompletion("```\nlet x = 1\n```") == "let x = 1")
    // A quote that is part of the text must survive.
    #expect(cleanCompletion("She said \"hi\" and left.") == "She said \"hi\" and left.")
    #expect(cleanCompletion("\"Hi,\" she said, \"bye.\"") == "\"Hi,\" she said, \"bye.\"")
}

// MARK: - Panel placement

private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
private let panel = CGSize(width: 200, height: 40)

@Test func panelSitsAboveTheSelection() {
    let anchor = CGRect(x: 400, y: 300, width: 120, height: 20)
    let frame = PanelPlacement.frame(size: panel, anchor: anchor, screens: [screen])
    #expect(frame.minY == anchor.maxY + 8)
    #expect(frame.midX == anchor.midX)
}

@Test func panelFlipsBelowWhenItWouldLeaveTheScreen() {
    let anchor = CGRect(x: 400, y: 780, width: 120, height: 20)
    let frame = PanelPlacement.frame(size: panel, anchor: anchor, screens: [screen])
    #expect(frame.maxY <= anchor.minY)
    #expect(frame.minY >= screen.minY)
}

@Test func panelStaysOnScreenHorizontally() {
    let leftEdge = PanelPlacement.frame(size: panel, anchor: CGRect(x: 0, y: 400, width: 10, height: 20), screens: [screen])
    #expect(leftEdge.minX >= screen.minX)

    let rightEdge = PanelPlacement.frame(size: panel, anchor: CGRect(x: 995, y: 400, width: 10, height: 20), screens: [screen])
    #expect(rightEdge.maxX <= screen.maxX)
}

@Test func panelFollowsTheSelectionToASecondScreen() {
    let second = CGRect(x: 1000, y: 0, width: 1000, height: 800)
    let anchor = CGRect(x: 1400, y: 300, width: 120, height: 20)
    let frame = PanelPlacement.frame(size: panel, anchor: anchor, screens: [screen, second])
    #expect(second.contains(frame))
}

@Test func hotkeyRendersLikeAMenuShortcut() {
    #expect(HotkeyStore.describe(keyCode: 49, modifiers: UInt32(controlKey | optionKey)) == "⌃⌥Space")
}

// MARK: - Model lists

@Test func everyCloudProviderOffersModelsAndDefaultsToOne() {
    for kind in ProviderKind.allCases where kind != .apple {
        #expect(!kind.knownModels.isEmpty, "\(kind) has no suggested models")
        #expect(kind.knownModels.contains(kind.defaultModel),
                "\(kind) defaults to \(kind.defaultModel), which is not in its list")
        #expect(!kind.modelHint.isEmpty)
    }
    #expect(ProviderKind.apple.knownModels.isEmpty)
    #expect(ProviderKind.apple.defaultModel.isEmpty)
}

@Test func modelsAreUniqueAndLookLikeIdentifiers() {
    for kind in ProviderKind.allCases {
        #expect(Set(kind.knownModels).count == kind.knownModels.count, "\(kind) lists a duplicate")
        for model in kind.knownModels {
            #expect(!model.contains(" "), "\(model) is not a usable model id")
        }
    }
}

@MainActor
@Test func aTypedModelSurvivesSwitchingProviderAndBack() {
    let settings = Settings.shared
    let original = settings.model(for: .openAI)
    settings.setModel("gpt-experimental-9", for: .openAI)
    #expect(settings.model(for: .openAI) == "gpt-experimental-9")
    #expect(settings.model(for: .anthropic) == ProviderKind.anthropic.defaultModel)
    settings.setModel("", for: .openAI)
    #expect(settings.model(for: .openAI) == ProviderKind.openAI.defaultModel)
    settings.setModel(original, for: .openAI)
}

// MARK: - Help text

@Test func everyActionExplainsItself() {
    for action in Action.allCases {
        #expect(!action.title.isEmpty)
        #expect(!action.help.isEmpty, "\(action) has no hover text")
        #expect(action.help.hasSuffix("."), "\(action) help should read as a sentence")
        #expect(!action.symbol.isEmpty)
    }
    #expect(Set(Action.allCases.map(\.help)).count == Action.allCases.count)
}

@Test func everyActionHasAReadableBarLabel() {
    for action in Action.allCases {
        #expect(!action.shortTitle.isEmpty, "\(action) has no bar label")
        #expect(action.shortTitle.count <= 12, "\(action.shortTitle) is too long for the bar")
    }
    #expect(Set(Action.allCases.map(\.shortTitle)).count == Action.allCases.count,
            "two actions share a bar label")
}

// MARK: - Editability

@Test func onlyTextInputRolesCountAsEditable() {
    for role in ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"] {
        #expect(SelectionReader.isEditableRole(role), "\(role) should be editable")
    }
    // Page content, chat transcripts, code listings, labels.
    for role in ["AXStaticText", "AXWebArea", "AXGroup", "AXLink", "AXCell", "AXList",
                 "AXScrollArea", "AXHeading", "AXRow", "AXTable", "AXImage", "AXButton"] {
        #expect(!SelectionReader.isEditableRole(role), "\(role) should not be editable")
    }
    #expect(!SelectionReader.isEditableRole(nil))
    #expect(!SelectionReader.isEditableRole(""))
}

// MARK: - Diff

private func rebuilt(_ tokens: [Diff.Token]) -> String {
    tokens.map(\.text).joined()
}

private func changedWords(_ tokens: [Diff.Token]) -> [String] {
    tokens.filter(\.changed).map(\.text)
}

@Test func tokenizingIsLossless() {
    for text in ["hello world", "  leading and trailing  ", "line\none\ttab",
                 "", "one", "punctuation, and: symbols!"] {
        #expect(Diff.tokenize(text).joined() == text)
    }
}

@Test func identicalTextHasNoChanges() {
    let tokens = Diff.changes(from: "She does not like apples.", to: "She does not like apples.")
    #expect(changedWords(tokens).isEmpty)
    #expect(rebuilt(tokens) == "She does not like apples.")
}

@Test func onlyTheCorrectedWordsAreFlagged() {
    let tokens = Diff.changes(from: "she dont like apples", to: "She doesn't like apples")
    #expect(changedWords(tokens) == ["She", "doesn't"])
    #expect(rebuilt(tokens) == "She doesn't like apples")
}

@Test func insertedWordsAreFlagged() {
    let tokens = Diff.changes(from: "We going to the shop", to: "We are going to the shop")
    #expect(changedWords(tokens) == ["are"])
}

@Test func deletionsLeaveNothingToHighlight() {
    let tokens = Diff.changes(from: "We are are going", to: "We are going")
    #expect(changedWords(tokens).isEmpty)
    #expect(rebuilt(tokens) == "We are going")
}

@Test func whitespaceOnlyDifferencesAreNotHighlighted() {
    let tokens = Diff.changes(from: "one  two", to: "one two")
    #expect(changedWords(tokens).isEmpty)
}

@Test func theResultIsAlwaysReproducedExactly() {
    let cases = [("she dont like apple's, and me neither", "She doesn't like apples, and neither do I"),
                 ("  keep   my spacing ", "  keep   my spacing "),
                 ("multi\nline\ntext", "Multi-line text.")]
    for (original, revised) in cases {
        #expect(rebuilt(Diff.changes(from: original, to: revised)) == revised)
    }
}

// MARK: - Secure fields

@Test func passwordFieldsAreRecognisedByRoleOrSubrole() {
    #expect(SelectionFilter.isSecureRole(role: "AXSecureTextField", subrole: nil))
    #expect(SelectionFilter.isSecureRole(role: nil, subrole: "AXSecureTextField"))
    #expect(SelectionFilter.isSecureRole(role: "AXPasswordField", subrole: nil))
    // Web content marks the field with the subrole while the role stays generic.
    #expect(SelectionFilter.isSecureRole(role: "AXTextField", subrole: "AXSecureTextField"))

    #expect(!SelectionFilter.isSecureRole(role: "AXTextField", subrole: nil))
    #expect(!SelectionFilter.isSecureRole(role: "AXTextArea", subrole: "AXContentEditable"))
    #expect(!SelectionFilter.isSecureRole(role: nil, subrole: nil))
}

// MARK: - Truncation

@Test func truncatedAnswersAreFlagged() throws {
    let openAI = #"{"choices":[{"message":{"content":"Cut off here"},"finish_reason":"length"}]}"#
    #expect(try OpenAICompatibleProvider.parse(Data(openAI.utf8)).truncated)

    let anthropic = #"{"content":[{"type":"text","text":"Cut off here"}],"stop_reason":"max_tokens"}"#
    #expect(try AnthropicProvider.parse(Data(anthropic.utf8)).truncated)

    let gemini = #"{"candidates":[{"content":{"parts":[{"text":"Cut off"}]},"finishReason":"MAX_TOKENS"}]}"#
    #expect(try GeminiProvider.parse(Data(gemini.utf8)).truncated)
}

@Test func completeAnswersAreNotFlagged() throws {
    let openAI = #"{"choices":[{"message":{"content":"Done."},"finish_reason":"stop"}]}"#
    #expect(try OpenAICompatibleProvider.parse(Data(openAI.utf8)).truncated == false)

    let anthropic = #"{"content":[{"type":"text","text":"Done."}],"stop_reason":"end_turn"}"#
    #expect(try AnthropicProvider.parse(Data(anthropic.utf8)).truncated == false)

    let gemini = #"{"candidates":[{"content":{"parts":[{"text":"Done."}]},"finishReason":"STOP"}]}"#
    #expect(try GeminiProvider.parse(Data(gemini.utf8)).truncated == false)

    // A provider that omits the field entirely must not be treated as truncated.
    #expect(try OpenAICompatibleProvider.parse(Data(#"{"choices":[{"message":{"content":"Hi"}}]}"#.utf8)).truncated == false)
}

@Test func anthropicAsksForEnoughRoomToExpandText() {
    #expect(AnthropicProvider(apiKey: "k", model: "m").maxTokens >= 8192)
}

// MARK: - Hotkeys

@Test func aHotkeyMustCarryARealModifier() {
    #expect(HotkeyStore.hasRequiredModifier(UInt32(controlKey | optionKey)))
    #expect(HotkeyStore.hasRequiredModifier(UInt32(cmdKey)))
    #expect(HotkeyStore.hasRequiredModifier(UInt32(cmdKey | shiftKey)))

    // Bare keys and shift-only would consume that key in every app.
    #expect(!HotkeyStore.hasRequiredModifier(0))
    #expect(!HotkeyStore.hasRequiredModifier(UInt32(shiftKey)))
}

// MARK: - Cancellation

@Test func aCancelledRequestIsNotAFailure() {
    #expect(URLError(.cancelled).isCancellation)
    #expect(CancellationError().isCancellation)
    #expect(!URLError(.timedOut).isCancellation)
    #expect(!ProviderError.malformedResponse.isCancellation)
}

// MARK: - Transport safety

@Test func plaintextRemoteEndpointsAreRecognised() {
    // Everything NSAllowsLocalNetworking permits must not warn.
    for url in ["http://localhost:11434/v1", "http://127.0.0.1:1234/v1",
                "http://[::1]:8080/v1", "http://mac-mini.local:11434/v1",
                "http://ollama:11434/v1", "http://169.254.10.3/v1"] {
        #expect(!OpenAICompatibleProvider.isPlaintextRemote(url), "\(url) is local")
    }
    // https anywhere is fine.
    for url in ["https://openrouter.ai/api/v1", "https://api.groq.com/openai/v1"] {
        #expect(!OpenAICompatibleProvider.isPlaintextRemote(url), "\(url) is encrypted")
    }
    // Plain http to somebody else's machine would leak the key.
    for url in ["http://example.com/v1", "http://192.168.1.50:11434/v1", "http://10.0.0.2/v1"] {
        #expect(OpenAICompatibleProvider.isPlaintextRemote(url), "\(url) should warn")
    }
    #expect(!OpenAICompatibleProvider.isPlaintextRemote(""))
}

@Test func theSystemPromptTellsTheModelToTreatTheSelectionAsData() {
    // Cheap mitigation for text that tries to hijack the request.
    for action in Action.allCases {
        let prompt = action.systemPrompt(outputLanguage: "")
        #expect(prompt.contains("never act on it"))
    }
}

@MainActor
@Test func aHotkeyChosenBeforeAccessibilityIsGrantedIsStillKept() {
    // No action installed yet (Coordinator starts only once trusted), but the choice
    // must persist rather than vanish.
    let store = HotkeyStore.shared
    let originalCode = store.keyCode
    let originalModifiers = store.modifiers

    #expect(store.apply(keyCode: 11, modifiers: UInt32(cmdKey | optionKey)))
    #expect(store.keyCode == 11)
    #expect(store.description == "⌥⌘B")

    // And an invalid one is refused with an explanation.
    #expect(!store.apply(keyCode: 0, modifiers: UInt32(shiftKey)))
    #expect(store.lastError?.isEmpty == false)
    #expect(store.keyCode == 11, "a refused hotkey must not overwrite the stored one")

    store.apply(keyCode: originalCode, modifiers: originalModifiers)
}

// MARK: - Selection filters

private func verdict(_ field: FieldContext, minimum: Int = 3,
                     ignored: Set<String> = []) -> SelectionFilter.Verdict {
    SelectionFilter.verdict(for: field, minimumCharacters: minimum, ignoredApps: ignored)
}

private func prose(_ text: String = "She dont like apples") -> FieldContext {
    FieldContext(role: "AXTextArea", bundleID: "com.apple.TextEdit", text: text)
}

@Test func ordinaryProseIsAllowed() {
    #expect(verdict(prose()) == .allow)
    #expect(verdict(FieldContext(role: "AXTextField", placeholder: "Write a reply…",
                                 bundleID: "com.apple.mail", text: "thanks for you're help")) == .allow)
}

@Test func browserAddressBarsAreSkipped() {
    // Safari names it in the identifier, Chrome in the accessibility description.
    let safari = FieldContext(role: "AXTextField",
                              identifier: "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD",
                              bundleID: "com.apple.Safari", text: "example.com/some/page")
    let chrome = FieldContext(role: "AXTextField", label: "Address and search bar",
                              bundleID: "com.google.Chrome", text: "how to fix grammar")
    let firefox = FieldContext(role: "AXTextField", title: "Search with Google or enter address",
                               bundleID: "org.mozilla.firefox", text: "some search words")

    for field in [safari, chrome, firefox] {
        #expect(verdict(field) == .skipAutomatic("address bar"))
    }
}

@Test func searchFieldsAndComboBoxesAreSkipped() {
    #expect(verdict(FieldContext(role: "AXSearchField", bundleID: "com.apple.finder",
                                 text: "quarterly report")) == .skipAutomatic("search field"))
    #expect(verdict(FieldContext(role: "AXTextField", placeholder: "Search messages",
                                 bundleID: "com.tinyspeck.slackmacgap",
                                 text: "budget meeting")) == .skipAutomatic("search field"))
    #expect(verdict(FieldContext(role: "AXComboBox", bundleID: "com.apple.Pages",
                                 text: "Helvetica")) == .skipAutomatic("combo box"))
}

@Test func credentialFieldsAreBlockedOutright() {
    // Blocked, not merely skipped: the hotkey must not reach these either.
    let fields = [
        FieldContext(role: "AXTextField", placeholder: "Card number", text: "4111 1111 1111 1111"),
        FieldContext(role: "AXTextField", label: "CVV", text: "123"),
        FieldContext(role: "AXTextField", title: "One-time code", text: "492013"),
        FieldContext(role: "AXTextField", identifier: "api_key_field", text: "some value"),
        FieldContext(role: "AXTextField", placeholder: "Recovery phrase", text: "word word word"),
        FieldContext(role: "AXSecureTextField", text: "hunter2"),
    ]
    for field in fields {
        guard case .block = verdict(field) else {
            Issue.record("\(field.names) should be blocked")
            continue
        }
    }
}

@Test func shortNameKeywordsDoNotMatchInnocentWords() {
    // "pin" must not fire on "shipping", "url" must not fire on "curly".
    #expect(verdict(FieldContext(role: "AXTextField", placeholder: "Shipping address",
                                 text: "10 Downing Street, London")) == .allow)
    #expect(verdict(FieldContext(role: "AXTextArea", title: "Curly quotes",
                                 text: "some ordinary sentence")) == .allow)
    // "Tokenise" is a word containing "token", not the word "token".
    #expect(verdict(FieldContext(role: "AXTextArea", placeholder: "Tokenise the input",
                                 text: "this is ordinary prose")) == .allow)
    // The standalone word still blocks.
    guard case .block = verdict(FieldContext(role: "AXTextField", placeholder: "Access token",
                                             text: "abc")) else {
        Issue.record("a field labelled with the word token must be blocked")
        return
    }
}

@Test func ignoredAppsAreBlockedEverywhere() {
    let field = FieldContext(role: "AXTextField", bundleID: "com.1password.1password",
                             text: "a note in my vault")
    guard case .block = verdict(field, ignored: Settings.defaultIgnoredApps) else {
        Issue.record("password managers must be blocked")
        return
    }
    // And the same app is fine once the user removes it from the list.
    #expect(verdict(field, ignored: []) == .allow)
}

@Test func defaultIgnoreListCoversSecretsAndCommandLines() {
    let defaults = Settings.defaultIgnoredApps
    #expect(defaults.contains("com.apple.keychainaccess"))
    #expect(defaults.contains("com.1password.1password"))
    #expect(defaults.contains("com.apple.Terminal"))
    #expect(defaults.contains("com.googlecode.iterm2"))
    #expect(defaults.contains("com.raycast.macos"))
}

@Test func tinySelectionsAndNonWordsAreSkipped() {
    #expect(verdict(prose("ok"), minimum: 3) == .skipAutomatic("shorter than 3 characters"))
    #expect(verdict(prose("ok"), minimum: 1) == .allow)
    #expect(verdict(prose("  a  "), minimum: 3) == .skipAutomatic("shorter than 3 characters"))

    // Spreadsheet cells, phone numbers, timestamps.
    #expect(verdict(prose("1,234.56")) == .skipAutomatic("no words in it"))
    #expect(verdict(prose("+44 20 7925 0918")) == .skipAutomatic("no words in it"))
    #expect(verdict(prose("---")) == .skipAutomatic("no words in it"))
}

@Test func loneURLsPathsAndEmailsAreSkipped() {
    for text in ["https://example.com/a/b?c=d", "www.example.com", "/Users/me/notes.txt",
                 "~/Documents", "./build.sh", "someone@example.com"] {
        #expect(verdict(prose(text)) == .skipAutomatic("a URL, path or address rather than prose"),
                "\(text) is a reference, not prose")
    }
    // A sentence that merely contains a URL is still prose.
    #expect(verdict(prose("see https://example.com for the details")) == .allow)
}

@Test func secretsInTheTextAreBlockedWhateverTheFieldClaims() {
    #expect(SelectionFilter.secretShape(of: "4111111111111111") == "looks like a card number")
    #expect(SelectionFilter.secretShape(of: "4111-1111-1111-1111") == "looks like a card number")
    // Deliberately invalid synthetic token: this tests shape detection, not JWT validity.
    #expect(SelectionFilter.secretShape(of: "eyJtest.payload.signature") == "looks like a JSON web token")
    #expect(SelectionFilter.secretShape(of: "-----BEGIN OPENSSH PRIVATE KEY-----") == "looks like a private key")
    #expect(SelectionFilter.secretShape(of: "sk-proj-abc123def456") == "looks like an API key")
    #expect(SelectionFilter.secretShape(of: "ghp_1234567890abcdefghij") == "looks like an API key")
    #expect(SelectionFilter.secretShape(of: "x7QK2mNbV9zRt4WcY8pLd3Fg6HjS1AkE") == "looks like an API key")

    // Prose and ordinary numbers must survive all of that.
    #expect(SelectionFilter.secretShape(of: "She doesn't like apples") == nil)
    #expect(SelectionFilter.secretShape(of: "1234") == nil)
    #expect(SelectionFilter.secretShape(of: "4111111111111112") == nil, "fails Luhn, so not a card")
    #expect(SelectionFilter.secretShape(of: "Unconscionable") == nil)
    #expect(SelectionFilter.secretShape(of: "internationalisation") == nil)
    #expect(SelectionFilter.secretShape(of: "antidisestablishmentarianism") == nil)
}

@Test func luhnIsActuallyChecked() {
    #expect(SelectionFilter.isPaymentCard("4242424242424242"))
    #expect(SelectionFilter.isPaymentCard("378282246310005"))     // Amex, 15 digits
    #expect(!SelectionFilter.isPaymentCard("4242424242424243"))   // one digit off
    #expect(!SelectionFilter.isPaymentCard("42424242"))           // too short
    #expect(!SelectionFilter.isPaymentCard("12345678901234567890")) // too long
}
