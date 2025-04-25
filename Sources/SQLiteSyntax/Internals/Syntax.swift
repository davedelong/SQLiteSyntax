//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public protocol Syntax: Sendable {
    
    func validate() throws(SyntaxError)
    func build(using builder: inout SyntaxBuilder) throws(SyntaxError)
    
}

public struct SyntaxBuilder {
    
    internal var terms: Array<String> = []
    
    mutating func add(_ terms: String?...) {
        self.add(terms)
    }
    
    mutating func add(_ terms: Array<String?>?) {
        for term in terms ?? [] {
            if let term, term.isEmpty == false { self.terms.append(term) }
        }
    }
    
    mutating func addAlias(name: SchemaName? = nil, _ part: (any Syntax)?) throws(SyntaxError) {
        if let part {
            add("AS")
            try add(first: name, second: part)
        }
    }
    
    mutating func add(name: SchemaName? = nil, _ part: (any Syntax)?) throws(SyntaxError) {
        try add(first: name, second: part)
    }
    
    mutating func add(name: TableName? = nil, _ wildcard: Wildcard) throws(SyntaxError) {
        try add(first: name, second: wildcard)
    }
    
    private mutating func add(first: (any Syntax)?, second: (any Syntax)?) throws(SyntaxError) {
        if let first, let second {
            var inner = SyntaxBuilder()
            try first.build(using: &inner)
            
            terms.append(contentsOf: inner.terms.dropLast())
            let finalName = inner.terms.last!
            inner.terms.removeAll()
            
            try second.build(using: &inner)
            let firstName = inner.terms.first!
            
            terms.append(finalName + "." + firstName)
            terms.append(contentsOf: inner.terms.dropFirst())
        } else if let first {
            try first.build(using: &self)
        } else if let second {
            try second.build(using: &self)
        }
    }
    
    mutating func addList<S: Syntax>(_ list: Array<S>, delimiter: String? = nil) throws(SyntaxError) {
        var needsDelimiter = false
        for item in list {
            if let delimiter, needsDelimiter == true { add(delimiter) }
            try add(item)
            needsDelimiter = true
        }
    }
    
    mutating func addList(_ list: Array<String>, delimiter: String? = nil) throws(SyntaxError) {
        var needsDelimiter = false
        for item in list {
            if let delimiter, needsDelimiter == true { add(delimiter) }
            add(item)
            needsDelimiter = true
        }
    }
}

public enum SyntaxError: Error {
    case invalidSyntax(any Syntax, reason: String)
}

extension Syntax {
    
    public func validate() throws(SyntaxError) { }
    
    public func build() throws(SyntaxError) -> String {
        var builder = SyntaxBuilder()
        try self.build(using: &builder)
        return builder.terms.joined(separator: " ")
    }
    
    internal func require(_ expression: Bool, reason: String) throws(SyntaxError) {
        if expression == false {
            throw SyntaxError.invalidSyntax(self, reason: reason)
        }
    }
    
}
