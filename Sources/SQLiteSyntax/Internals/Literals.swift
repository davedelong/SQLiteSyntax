//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 5/2/25.
//

import Foundation

internal enum Literals {
    
    static func string(_ s: String) -> String {
        // A string constant is formed by enclosing the string in single quotes (').
        // A single quote within the string can be encoded by putting two single quotes in a row - as in Pascal.
        // C-style escapes using the backslash character are not supported because they are not standard SQL.
        var final = s
        if final.contains("'") {
            final = final.replacingOccurrences(of: "'", with: "''")
        }
        return "'" + final + "'"
    }
    
    static func integer(_ i: Int64) -> String {
        // SQLite reads minus applied directly to 9223372036854775808 as the smallest INTEGER (expr.c).
        String(i)
    }
    
    static func real(_ d: Double) -> String {
        // Swift's description is the shortest text that reads back as the same Double, and always
        // contains "." or an exponent ("1.0", "0.1", "1e+16"), so SQLite reads it as REAL.
        if d.isNaN { return "NULL" }                    // SQLite stores NaN as NULL
        if d.isInfinite { return d < 0 ? "-9e999" : "9e999" }   // SQLite's spelling of ±Inf
        return d.description
    }
    
    static func identifier(_ s: String) -> String {
        // An identifier is quoted with double quotes ("). A double quote within it is written as two
        // double quotes. (Single quotes would make it a string literal.)
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    
    static func blob(_ d: Data) -> String {
        // BLOB literals are string literals containing hexadecimal data and preceded by a single "x" or "X" character. Example: X'53514C697465'
        let hex = d.map { ($0 < 0x10 ? "0" : "") + String($0, radix: 16, uppercase: true) }.joined()
        return "X'\(hex)'"
    }
    
}
