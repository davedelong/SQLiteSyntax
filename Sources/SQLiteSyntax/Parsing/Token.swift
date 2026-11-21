/// A lexical token of SQL text.
public struct Token: Equatable, Sendable {

    public enum Kind: Equatable, Sendable {
        /// An SQL keyword, uppercased (e.g. `SELECT`). Some keywords may still be used as identifiers.
        case keyword(String)
        /// An identifier, with quotes removed. `quoted` is true for `"x"`, `[x]` and `` `x` ``.
        case identifier(String, quoted: Bool)
        /// A string literal, with quotes removed and `''` unescaped.
        case string(String)
        /// A blob literal's hex digits (`X'...'`).
        case blob(String)
        /// A numeric literal as written (digit separators included).
        case number(String)
        /// A bind parameter as written: `?`, `?NNN`, `:name`, `@name`, `#name`, `$name`.
        case variable(String)
        /// Punctuation or an operator, e.g. `(`, `||`, `->>`, `<>`.
        case symbol(String)
        case endOfInput
    }

    public var kind: Kind
    /// The token's range in the source, as UTF-8 offsets.
    public var range: Range<Int>

    public init(kind: Kind, range: Range<Int>) {
        self.kind = kind
        self.range = range
    }

    var keyword: String? {
        if case .keyword(let k) = kind { return k }
        return nil
    }

    func isSymbol(_ s: String) -> Bool {
        if case .symbol(let x) = kind { return x == s }
        return false
    }

    func isKeyword(_ k: String) -> Bool { keyword == k }

    /// A short description for error messages.
    var display: String {
        switch kind {
            case .keyword(let k): return k
            case .identifier(let s, _): return "identifier \"\(s)\""
            case .string(let s): return "'\(s)'"
            case .blob(let s): return "X'\(s)'"
            case .number(let s): return s
            case .variable(let s): return s
            case .symbol(let s): return "'\(s)'"
            case .endOfInput: return "end of input"
        }
    }
}
