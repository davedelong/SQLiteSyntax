/// An error in SQL text, with its location.
public struct ParseError: Error, CustomStringConvertible, Equatable, Sendable {
    public var message: String
    /// UTF-8 offset into the source.
    public var offset: Int
    /// 1-based line and column (column counted in characters).
    public var line: Int
    public var column: Int

    init(message: String, source: String, offset: Int) {
        self.message = message
        self.offset = offset
        let prefix = String(decoding: source.utf8.prefix(offset), as: UTF8.self)
        let lines = prefix.split(separator: "\n", omittingEmptySubsequences: false)
        self.line = lines.count
        self.column = (lines.last?.count ?? 0) + 1
    }

    public var description: String { "\(line):\(column): \(message)" }
}

/// A cursor over tokens, with backtracking.
///
/// It's public only because `Syntax.parse(_:)` mentions it; it has no public API. Parse strings with
/// `init(parsing:)`.
public struct Parser {
    let source: String
    let tokens: [Token]
    var position = 0
    /// Shared between copies: memoised results and the furthest error.
    let state = ParserState()

    init(_ source: String) throws(ParseError) {
        self.source = source
        self.tokens = try Tokenizer(source).tokenize()
    }

    var current: Token { tokens[position] }
    func peek(_ offset: Int = 1) -> Token { tokens[min(position + offset, tokens.count - 1)] }
    var previous: Token? { position > 0 ? tokens[position - 1] : nil }
    var isAtEnd: Bool { current.kind == .endOfInput }

    mutating func advance() -> Token {
        let t = tokens[position]
        if position < tokens.count - 1 { position += 1 }
        return t
    }

    // MARK: Matching

    mutating func accept(keyword k: String) -> Bool {
        guard current.isKeyword(k) else { return false }
        _ = advance(); return true
    }

    mutating func accept(symbol s: String) -> Bool {
        guard current.isSymbol(s) else { return false }
        _ = advance(); return true
    }

    /// Accepts a sequence of keywords only if all of them are present.
    mutating func accept(keywords ks: String...) -> Bool {
        for (i, k) in ks.enumerated() where !peek(i).isKeyword(k) { return false }
        position += ks.count
        return true
    }

    mutating func expect(keyword k: String) throws(ParseError) {
        guard accept(keyword: k) else { throw unexpected(expected: k) }
    }

    mutating func expect(symbol s: String) throws(ParseError) {
        guard accept(symbol: s) else { throw unexpected(expected: "'\(s)'") }
    }

    // MARK: Errors

    func unexpected(expected: String) -> ParseError {
        ParseError(message: "expected \(expected), found \(current.display)", source: source, offset: current.range.lowerBound)
    }

    func error(_ message: String, at token: Token? = nil) -> ParseError {
        ParseError(message: message, source: source, offset: (token ?? current).range.lowerBound)
    }
}
