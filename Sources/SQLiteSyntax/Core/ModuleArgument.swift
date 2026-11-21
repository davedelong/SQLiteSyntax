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
