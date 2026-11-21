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
    
    /// SQLite reads SQL text only up to a NUL, so a string containing one would cut the statement short.
    /// (Use `.blob` for binary data.)
    public func validate() throws(SyntaxError) {
        if case .string(let s) = self {
            try require(!s.utf8.contains(0), reason: "A string literal cannot contain a NUL character; use a blob")
        }
    }

    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add(text)
    }

    /// The literal as SQLite source text.
    var text: String {
        switch self {
            case .integer(let i):
                // SQLite reads minus applied directly to 9223372036854775808 as the smallest INTEGER (expr.c).
                return String(i)
            case .real(let d):
                // Swift's description is the shortest text that reads back as the same Double, and always
                // contains "." or an exponent ("1.0", "0.1", "1e+16"), so SQLite reads it as REAL.
                if d.isNaN { return "NULL" }                            // SQLite stores NaN as NULL
                if d.isInfinite { return d < 0 ? "-9e999" : "9e999" }   // SQLite's spelling of ±Inf
                return d.description
            case .string(let s):
                // Enclosed in single quotes; a single quote inside is written as two. (SQL has no backslash escapes.)
                return "'" + s.replacingOccurrences(of: "'", with: "''") + "'"
            case .blob(let d):
                // A string of hexadecimal digits preceded by X, e.g. X'53514C697465'.
                let hex = d.map { ($0 < 0x10 ? "0" : "") + String($0, radix: 16, uppercase: true) }.joined()
                return "X'\(hex)'"
            case .null: return "NULL"
            case .true: return "TRUE"
            case .false: return "FALSE"
            case .currentTime: return "CURRENT_TIME"
            case .currentDate: return "CURRENT_DATE"
            case .currentTimestamp: return "CURRENT_TIMESTAMP"
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
