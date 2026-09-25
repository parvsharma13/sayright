import Foundation

/// Everything we know about the field a selection came from.
struct FieldContext {
    var role: String?
    var subrole: String?
    var identifier: String?
    var title: String?
    var label: String?
    var placeholder: String?
    var bundleID: String?
    var text: String = ""

    /// Everything an app might have used to name this field.
    var names: [String?] { [identifier, title, label, placeholder] }
}

/// Deciding where the bar has no business appearing.
///
/// "Editable" is necessary but nowhere near sufficient: a browser address bar, a
/// search box and a credit-card field are all editable text, and none of them wants
/// a grammar assistant.
enum SelectionFilter {
    enum Verdict: Equatable {
        /// Show the bar.
        case allow
        /// Never, on any path. Fields whose contents must not be sent anywhere.
        case block(String)
        /// Not automatically. The hotkey still works, because pressing it is a
        /// deliberate answer to "yes, I do mean this text".
        case skipAutomatic(String)
    }

    static func verdict(for field: FieldContext,
                        minimumCharacters: Int,
                        ignoredApps: Set<String>) -> Verdict {
        if isSecureRole(role: field.role, subrole: field.subrole) {
            return .block("password field")
        }
        if let bundleID = field.bundleID, ignoredApps.contains(bundleID) {
            return .block("app on the ignore list")
        }
        if matches(field.names, words: credentialWords, phrases: credentialPhrases) {
            return .block("field looks like a credential or card number")
        }
        if let reason = secretShape(of: field.text) {
            return .block(reason)
        }

        if matches(field.names, words: addressBarWords, phrases: addressBarPhrases) {
            return .skipAutomatic("address bar")
        }
        if field.role == "AXSearchField" || matches(field.names, words: ["search"], phrases: []) {
            return .skipAutomatic("search field")
        }
        if field.role == "AXComboBox" {
            return .skipAutomatic("combo box")
        }

        let trimmed = field.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < max(1, minimumCharacters) {
            return .skipAutomatic("shorter than \(minimumCharacters) characters")
        }
        if !trimmed.contains(where: \.isLetter) {
            return .skipAutomatic("no words in it")
        }
        if isSingleReference(trimmed) {
            return .skipAutomatic("a URL, path or address rather than prose")
        }
        return .allow
    }

    /// A password field, by role, subrole, or the way web content marks one up.
    static func isSecureRole(role: String?, subrole: String?) -> Bool {
        let secure = ["AXSecureTextField", "AXPasswordField"]
        if let role, secure.contains(role) { return true }
        if let subrole, secure.contains(subrole) { return true }
        return false
    }

    // MARK: - Field names

    /// Short enough to need whole-word matching: "pin" would otherwise hit "shipping".
    private static let credentialWords: Set<String> = [
        "password", "passwd", "passphrase", "pin", "cvv", "cvc", "otp", "secret",
        "token", "iban", "ssn", "seed", "mnemonic",
    ]
    private static let credentialPhrases = [
        "card number", "credit card", "cardnumber", "security code", "one-time",
        "one time code", "verification code", "2fa", "two-factor", "api key",
        "access key", "secret key", "license key", "licence key", "recovery key",
        "recovery code", "recovery phrase", "seed phrase", "account number", "sort code",
        "routing number",
    ]

    private static let addressBarWords: Set<String> = ["url", "uri", "omnibox"]
    private static let addressBarPhrases = [
        "address and search", "address bar", "addressbar", "location bar",
        "web browser address", "enter website", "search or enter", "type a url",
        "web address", "enter address", "go to address",
    ]

    private static func matches(_ haystacks: [String?], words: Set<String>, phrases: [String]) -> Bool {
        for case let text? in haystacks where !text.isEmpty {
            // Identifiers use underscores and hyphens where a label would use spaces,
            // so "api_key_field" has to match the phrase "api key".
            let lowered = text.lowercased()
                .map { $0 == "_" || $0 == "-" ? " " : $0 }
                .reduce(into: "") { $0.append($1) }
            if phrases.contains(where: lowered.contains) { return true }
            let tokens = Set(lowered.split { !$0.isLetter && !$0.isNumber }.map(String.init))
            if !tokens.isDisjoint(with: words) { return true }
        }
        return false
    }

    // MARK: - Content shape

    /// Things that must not be sent to a model even if the user asks, because the
    /// harm is in the sending. Deliberately narrow: each pattern is unmistakable.
    static func secretShape(of text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("-----BEGIN") { return "looks like a private key" }

        // Cards are often written in groups of four, so they are checked before the
        // single-token gate the other patterns rely on.
        if isPaymentCard(trimmed) { return "looks like a card number" }

        let singleToken = !trimmed.contains(where: \.isWhitespace)
        if singleToken, trimmed.hasPrefix("eyJ"), trimmed.filter({ $0 == "." }).count == 2 {
            return "looks like a JSON web token"
        }
        if singleToken, isAPIKey(trimmed) { return "looks like an API key" }
        return nil
    }

    /// 13–19 digits that pass Luhn — the same check a payment form runs.
    static func isPaymentCard(_ text: String) -> Bool {
        // Digits, optionally grouped with spaces or dashes, and nothing else.
        guard text.allSatisfy({ $0.isNumber || $0 == "-" || $0 == " " }) else { return false }
        let digits = text.filter(\.isNumber)
        guard (13...19).contains(digits.count) else { return false }
        return luhnPasses(digits)
    }

    private static func luhnPasses(_ digits: some StringProtocol) -> Bool {
        var sum = 0
        for (offset, character) in digits.reversed().enumerated() {
            guard let value = character.wholeNumberValue else { return false }
            if offset.isMultiple(of: 2) {
                sum += value
            } else {
                let doubled = value * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }
        return sum % 10 == 0
    }

    /// A long unbroken run of letters and digits with no vowels to speak of is a key,
    /// not a word. Requiring both letters and digits keeps long words out.
    static func isAPIKey(_ text: String) -> Bool {
        let known = ["sk-", "sk_", "pk_", "ghp_", "gho_", "github_pat_", "xoxb-", "xoxp-",
                     "AIza", "ya29.", "AKIA", "ASIA", "hf_", "glpat-"]
        if known.contains(where: text.hasPrefix) { return true }

        guard text.count >= 32,
              text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }),
              text.contains(where: \.isNumber),
              text.contains(where: \.isLetter) else { return false }

        // Prose has vowels; generated keys mostly do not.
        let letters = text.filter(\.isLetter)
        let vowels = letters.filter { "aeiouAEIOU".contains($0) }
        return Double(vowels.count) / Double(max(letters.count, 1)) < 0.25
    }

    /// One word that is a URL, a file path, or an email address — nothing to edit.
    static func isSingleReference(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace) else { return false }
        let lowered = text.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://")
            || lowered.hasPrefix("www.") || lowered.hasPrefix("file://") { return true }
        if text.hasPrefix("/") || text.hasPrefix("~/") || text.hasPrefix("./") { return true }
        // An email address: exactly one @, a dot after it, no spaces.
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        if parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") { return true }
        return false
    }
}
