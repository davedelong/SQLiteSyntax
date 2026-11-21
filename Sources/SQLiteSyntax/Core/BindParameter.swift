//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum BindParameter: Syntax {
    
    case next
    case nth(Int)
    case named(String)
    case atNamed(String)
    case tcl(String)
 
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .next: builder.add("?")
            case .nth(let i): builder.add("?\(i)")
            case .named(let s): builder.add(":\(s)")
            case .atNamed(let s): builder.add("@\(s)")
            case .tcl(let s): builder.add("$\(s)")
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
