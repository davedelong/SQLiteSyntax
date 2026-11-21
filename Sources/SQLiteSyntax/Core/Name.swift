//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct Name<T>: Syntax {
    
    public var value: String
    
    public init(value: String) where T == Any {
        self.value = value
    }
    
    public init(value: String) where T: NamedStructure {
        self.value = value
    }
    
    public init(_ value: String) where T: NamedStructure {
        self.value = value
    }

    /// For the parser, which reads names of every kind.
    init(parsed value: String) {
        self.value = value
    }
    
    public func validate() throws(SyntaxError) {
        // check validity
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        var needsEscaping = value.contains(where: \.isProbablySpecial)
        // A keyword is quoted, except a word of a declared type that SQLite reads as an identifier anyway:
        // SQLite dequotes a type as a whole, so `"always" "generated"` would become just `always`.
        let upper = value.uppercased()
        let plainTypeWord = T.self == TypeWord.self && SQLiteKeywords.fallbackToIdentifier.contains(upper)
        needsEscaping = needsEscaping || (SQLiteKeywords.all.contains(upper) && !plainTypeWord)
        // An unquoted name cannot be empty or start with a digit (it would read as a number).
        needsEscaping = needsEscaping || value.isEmpty || value.first!.isNumber
        
        if needsEscaping {
            // Quoted with double quotes, a double quote inside written as two. (Single quotes would make a string.)
            builder.add("\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"")
        } else {
            builder.add(value)
        }
    }

    /// A name in the `nm` class: an identifier, a string, or a keyword SQLite allows as a name.
    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        try parse(&p, class: .name, excluding: [])
    }

    static func parse(_ p: inout Parser, class nameClass: NameClass, excluding: Set<String> = []) throws(ParseError) -> Self {
        Name(parsed: try p.parseName(class: nameClass, excluding: excluding))
    }
    
}

extension Name: ExpressibleByUnicodeScalarLiteral, ExpressibleByExtendedGraphemeClusterLiteral, ExpressibleByStringLiteral where T: NamedStructure {
    
    public init(stringLiteral value: String) {
        self.init(value: value)
    }
    
}

public protocol NamedStructure { }

/// A word of a column's declared type, e.g. `VARCHAR` or each word of `DOUBLE PRECISION`.
public enum TypeWord: NamedStructure { }
public enum Table: NamedStructure { }
public enum Schema: NamedStructure { }
public enum Column: NamedStructure { }
public enum Function: NamedStructure { }
public enum Index: NamedStructure { }
public enum Trigger: NamedStructure { }
public enum View: NamedStructure { }
public enum Module: NamedStructure { }
public enum Collation: NamedStructure { }
public enum Window: NamedStructure { }
public enum Savepoint: NamedStructure { }

extension Character {
    fileprivate var isProbablySpecial: Bool {
        // underscores are allowed in names, but even though it's a symbol
        if self == "_" { return false }
        if self == "'" { return true }
        
        if isWhitespace { return true }
        if isPunctuation { return true }
        if isSymbol { return true }
        
        return false
    }
}
