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
    
    static func blob(_ d: Data) -> String {
        // BLOB literals are string literals containing hexadecimal data and preceded by a single "x" or "X" character. Example: X'53514C697465'
        let hex = d.map { String($0, radix: 16, uppercase: true) }.joined()
        return "X'\(hex)'"
    }
    
}
