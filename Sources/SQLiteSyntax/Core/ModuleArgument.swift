//
//  ModuleArgument.swift
//  SQLiteSyntax
//

/// A `module-argument` of `CREATE VIRTUAL TABLE … USING module(…)`: arbitrary SQL tokens, passed to the
/// module as text. Used by generated types (see `tokens` in SQLiteSyntaxGenerator/Grammar/codegen.json).
public struct ModuleArgument: Syntax, ExpressibleByStringLiteral {
    public var text: String

    public init(_ text: String) { self.text = text }
    public init(stringLiteral value: String) { self.text = value }

    /// The text is written into the SQL as it is, so it must read back as this one argument: complete
    /// tokens with balanced parentheses, and no `,` or `)` outside them, `;` or comment.
    public func validate() throws(SyntaxError) {
        let tokens: [Token]
        do { tokens = try Tokenizer(text).tokenize() } catch {
            throw SyntaxError.invalidSyntax(self, reason: "A module argument must be complete SQL tokens: \(error.message)")
        }
        // A comment would swallow what follows the argument (`a -- x )` loses its `)`). The tokenizer
        // skips comments, so anything between tokens other than whitespace is one.
        var covered = 0
        let bytes = Array(text.utf8)
        for token in tokens {
            let gap = bytes[covered..<token.range.lowerBound]
            try require(gap.allSatisfy { [0x20, 0x09, 0x0A, 0x0C, 0x0D].contains($0) }, reason: "A module argument cannot contain a comment")
            covered = max(covered, token.range.upperBound)
        }
        var depth = 0
        for token in tokens {
            try require(!token.isSymbol(";"), reason: "A module argument cannot contain ';'")
            if token.isSymbol("(") { depth += 1 }
            if token.isSymbol(")") { depth -= 1 }
            try require(depth >= 0, reason: "A module argument cannot close a parenthesis it didn't open")
            try require(depth > 0 || !token.isSymbol(","), reason: "A module argument cannot contain ',' outside parentheses")
        }
        try require(depth == 0, reason: "A module argument must close its parentheses")
    }

    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add(text)
    }

    /// Any tokens up to a `,` or `)` outside parentheses, kept as written.
    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        let start = p.current.range.lowerBound
        var depth = 0
        var end = start
        while !p.isAtEnd {
            if depth == 0, p.current.isSymbol(",") || p.current.isSymbol(")") { break }
            if p.current.isSymbol("(") { depth += 1 }
            if p.current.isSymbol(")") { depth -= 1 }
            end = p.advance().range.upperBound
        }
        // parse.y vtabarg may be empty. Allow that beside a comma (`fts4(a, )`), so `m()` stays "no arguments".
        guard end > start || p.current.isSymbol(",") || p.previous?.isSymbol(",") == true else {
            let e = p.unexpected(expected: "a module argument")
            p.state.record(e)
            throw e
        }
        return ModuleArgument(String(decoding: Array(p.source.utf8)[start..<end], as: UTF8.self))
    }
}
