/// Converts words (keywords like `PRIMARY KEY`, or symbols like `collation-name`) to Swift identifiers.
enum Naming {

    static func words(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " }).map { $0.lowercased() }
    }

    static func lowerCamel(_ words: [String]) -> String {
        guard let first = words.first else { return "" }
        return first + words.dropFirst().map(capitalized).joined()
    }

    static func upperCamel(_ words: [String]) -> String {
        words.map(capitalized).joined()
    }

    static func capitalized(_ w: String) -> String {
        w.prefix(1).uppercased() + w.dropFirst()
    }

    static func lowerFirst(_ s: String) -> String {
        s.prefix(1).lowercased() + s.dropFirst()
    }

    /// Keyword words from fixed tokens, skipping punctuation.
    static func keywordWords(_ texts: [String]) -> [String] {
        texts.filter { $0.unicodeScalars.contains { $0.properties.isAlphabetic } }.flatMap(words)
    }

    static let punctuation: [String: String] = [
        ",": "comma", "(": "leftParen", ")": "rightParen", "+": "plus", "-": "minus", "*": "star",
        ".": "dot", ";": "semicolon", "=": "equals", "~": "tilde",
    ]

    /// A name for a run of fixed tokens: its keywords, or else its punctuation.
    static func name(forTexts texts: [String]) -> String? {
        let keywords = keywordWords(texts)
        if !keywords.isEmpty { return lowerCamel(keywords) }
        let names = texts.compactMap { punctuation[$0] }
        return names.isEmpty ? nil : lowerCamel(names.flatMap { words(splitCamel($0)) })
    }

    private static func splitCamel(_ s: String) -> String {
        var out = ""
        for c in s {
            if c.isUppercase { out += " " }
            out.append(c)
        }
        return out
    }

    /// The Swift type name for a rule, e.g. `frame-spec` -> `FrameSpec`, `select-stmt` -> `SelectStatement`.
    static func typeName(forRule rule: String) -> String {
        let expansions = ["stmt": "statement", "expr": "expression", "defn": "definition", "cte": "CTE"]
        return words(rule).map { w in expansions[w].map(capitalized) ?? capitalized(w) }.joined()
    }

    static let reservedWords: Set<String> = [
        "as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer", "deinit",
        "do", "else", "enum", "extension", "fallthrough", "false", "fileprivate", "for", "func", "guard", "if",
        "import", "in", "init", "inout", "internal", "is", "let", "nil", "open", "operator", "private",
        "protocol", "public", "repeat", "rethrows", "return", "self", "Self", "static", "struct", "subscript",
        "super", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while", "Type",
    ]

    /// An identifier, backtick-escaped if it is a Swift keyword.
    static func identifier(_ name: String) -> String {
        reservedWords.contains(name) ? "`\(name)`" : name
    }
}
