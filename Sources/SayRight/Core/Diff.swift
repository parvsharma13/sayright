import Foundation

/// A word-level diff of the model's answer against what the user had, so a
/// grammar fix can show exactly which words it touched.
enum Diff {
    struct Token {
        let text: String
        let changed: Bool
    }

    /// Splits into alternating runs of whitespace and non-whitespace, so joining
    /// the tokens back together reproduces the input exactly.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentIsWhitespace: Bool?

        for character in text {
            let isWhitespace = character.isWhitespace
            if currentIsWhitespace == nil || isWhitespace == currentIsWhitespace {
                current.append(character)
            } else {
                tokens.append(current)
                current = String(character)
            }
            currentIsWhitespace = isWhitespace
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Tokens of `revised`, each flagged if it is new or reworded. Rebuilding the
    /// string from `text` always yields `revised` untouched - the flags are the
    /// only thing added.
    static func changes(from original: String, to revised: String) -> [Token] {
        let old = tokenize(original)
        let new = tokenize(revised)

        // Stdlib Myers diff: insertions are offsets into `new`.
        var inserted = Set<Int>()
        for change in new.difference(from: old).insertions {
            if case let .insert(offset, _, _) = change { inserted.insert(offset) }
        }

        return new.enumerated().map { offset, token in
            // Whitespace-only differences are noise, not an edit worth pointing at.
            let isWhitespace = token.allSatisfy(\.isWhitespace)
            return Token(text: token, changed: inserted.contains(offset) && !isWhitespace)
        }
    }
}
