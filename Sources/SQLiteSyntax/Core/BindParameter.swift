//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum BindParameter: Syntax {
    
    /// `?`
    case next
    /// `?N`; N must be at least 1. (Its upper limit is the database's variable limit, 32766 by default.)
    case nth(Int)
    /// `:name`
    case named(String)
    /// `@name`
    case atNamed(String)
    /// `$name`
    case tcl(String)

    /// A name must be one SQLite reads back as this whole parameter: at least one letter, digit, `_`, `$` or
    /// non-ASCII character, optionally with Tcl-style `::` separators and a trailing `(…)` suffix.
    public func validate() throws(SyntaxError) {
        switch self {
            case .next:
                break
            case .nth(let n):
                try require(n >= 1, reason: "A numbered parameter must be ?1 or higher")
            case .named(let name), .atNamed(let name), .tcl(let name):
                let text = String(prefix) + name
                let tokens = try? Tokenizer(text).tokenize()
                // One variable token spanning all of it, then the end of input.
                let whole = tokens.map { $0.count == 2 && $0[0].kind == .variable && $0[0].string == text } ?? false
                try require(whole, reason: "\(text) is not a valid parameter name")
        }
    }

    private var prefix: Character {
        switch self {
            case .next, .nth: return "?"
            case .named: return ":"
            case .atNamed: return "@"
            case .tcl: return "$"
        }
    }
 
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .next: builder.add("?")
            case .nth(let i): builder.add("?\(i)")
            case .named(let s), .atNamed(let s), .tcl(let s): builder.add("\(prefix)\(s)")
        }
    }

    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        let token = p.current
        guard case .variable = token.kind else {
            let e = p.unexpected(expected: "a bind parameter")
            p.state.record(e)
            throw e
        }
        _ = p.advance()
        return try p.bindParameter(token.string, token: token)
    }
}
