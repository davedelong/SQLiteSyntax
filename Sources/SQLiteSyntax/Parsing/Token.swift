/// A lexical token of SQL text.
struct Token: Equatable, Sendable {

    enum Kind: Equatable, Sendable {
        /// An SQL keyword, uppercased (e.g. `SELECT`). Some keywords may still be used as identifiers.
        case keyword
        /// An identifier, with quotes removed. `quoted` is true for `"x"`, `[x]` and `` `x` ``.
        case identifier(quoted: Bool)
        /// A string literal, with quotes removed and `''` unescaped.
        case string
        /// A blob literal's hex digits (`X'...'`).
        case blob
        /// A numeric literal as written (digit separators included).
        case number
        /// A bind parameter as written: `?`, `?NNN`, `:name`, `@name`, `#name`, `$name`.
        case variable
        /// Punctuation or an operator, e.g. `(`, `||`, `->>`, `<>`.
        case symbol
        case endOfInput
    }

    var kind: Kind
    /// The token's range in the source, as UTF-8 offsets.
    var range: Range<Int>

    var string: String

    init(kind: Kind, string: String, range: Range<Int>) {
        self.kind = kind
        self.string = string
        self.range = range
    }

    var keyword: String? {
        if case .keyword = kind { return string }
        return nil
    }

    func isSymbol(_ s: String) -> Bool {
        if case .symbol = kind { return string == s }
        return false
    }

    func isKeyword(_ k: String) -> Bool { keyword == k }

    /// A short description for error messages.
    var display: String {
        switch kind {
            case .keyword: return string
            case .identifier: return "identifier \"\(string)\""
            case .string: return "'\(string)'"
            case .blob: return "X'\(string)'"
            case .number: return string
            case .variable: return string
            case .symbol: return "'\(string)'"
            case .endOfInput: return "end of input"
        }
    }
}
