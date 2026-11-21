//
//  LiteralValue.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum LiteralValue: Syntax {
    
    /// An INTEGER literal, e.g. `1`, `-5`, `0x10`.
    case integer(Int64)
    /// A REAL literal, e.g. `1.0`, `0.5`, `1e3`. Always written so SQLite reads it as REAL.
    case real(Double)
    case string(String)
    case blob(Data)
    case null
    case `true`
    case `false`
    case currentTime
    case currentDate
    case currentTimestamp
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .integer(let i):
                builder.add(Literals.integer(i))
            case .real(let d):
                builder.add(Literals.real(d))
            case .string(let s):
                builder.add(Literals.string(s))
            case .blob(let d):
                builder.add(Literals.blob(d))
            case .null:
                builder.add("NULL")
            case .true:
                builder.add("TRUE")
            case .false:
                builder.add("FALSE")
            case .currentTime:
                builder.add("CURRENT_TIME")
            case .currentDate:
                builder.add("CURRENT_DATE")
            case .currentTimestamp:
                builder.add("CURRENT_TIMESTAMP")
        }
    }

    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        let token = p.current
        switch token.kind {
            case .number: _ = p.advance(); return try p.numericLiteral(token.string, token: token)
            case .string: _ = p.advance(); return .string(token.string)
            case .blob: _ = p.advance(); return .blob(p.blob(token.string))
            case .keyword where token.string == "NULL": _ = p.advance(); return .null
            case .keyword where token.string == "CURRENT_DATE": _ = p.advance(); return .currentDate
            case .keyword where token.string == "CURRENT_TIME": _ = p.advance(); return .currentTime
            case .keyword where token.string == "CURRENT_TIMESTAMP": _ = p.advance(); return .currentTimestamp
            case .identifier(quoted: false) where token.string.uppercased() == "TRUE": _ = p.advance(); return .true
            case .identifier(quoted: false) where token.string.uppercased() == "FALSE": _ = p.advance(); return .false
            default:
                let e = p.unexpected(expected: "a literal value")
                p.state.record(e)
                throw e
        }
    }
    
}
