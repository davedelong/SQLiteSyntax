//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation
import SQLite3

public struct Name<T>: Syntax {
    
    public var value: String
    
    public init(value: String) where T == Any {
        self.value = value
    }
    
    public init(value: String) where T: NamedStructure {
        self.value = value
    }
    
    public func validate() throws(SyntaxError) {
        // check validity
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        var needsEscaping = value.contains(where: \.isProbablySpecial)
        needsEscaping = needsEscaping || Name<Any>.keywords.contains(value.lowercased())
        
        if needsEscaping {
            let escaped = value.replacingOccurrences(of: #"""#, with: #"\""#)
            builder.add(#""\#(escaped)""#)
        } else {
            builder.add(value)
        }
    }
    
}

extension Name: ExpressibleByUnicodeScalarLiteral, ExpressibleByExtendedGraphemeClusterLiteral, ExpressibleByStringLiteral where T: NamedStructure {
    
    public init(stringLiteral value: String) {
        self.init(value: value)
    }
    
}

public protocol NamedStructure { }

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
        
        if isWhitespace { return true }
        if isPunctuation { return true }
        if isSymbol { return true }
        
        return false
    }
}

extension Name<Any> {
    fileprivate static let keywords: Set<String> = {
        var keywords = Set<String>()
        for i in 0 ..< sqlite3_keyword_count() {
            var chars: UnsafePointer<Int8>?
            var count = Int32(0)
            guard sqlite3_keyword_name(i, &chars, &count) == SQLITE_OK else { continue }
            guard let chars else { continue }
            
            let mutableChars = UnsafeMutablePointer(mutating: chars)
            let data = Data(bytesNoCopy: mutableChars, count: Int(count), deallocator: .none)
            let rawKeyword = String(decoding: data, as: UTF8.self)
            keywords.insert(rawKeyword.lowercased())
        }
        return keywords
    }()
}
