//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public protocol Syntax: Sendable {
    
    /// Validate that the syntax is correct and has everything it needs.
    ///
    /// This is called automatically as part of building.
    func validate() throws(SyntaxError)
    func build(using builder: inout SyntaxBuilder) throws(SyntaxError)
    
}

extension Syntax {
    
    public func validate() throws(SyntaxError) { }
    
    public func sql() throws(SyntaxError) -> String {
        var builder = SyntaxBuilder()
        try self.build(using: &builder)
        return builder.sql
    }
    
    internal func require(_ expression: Bool, reason: String) throws(SyntaxError) {
        if expression == false {
            throw SyntaxError.invalidSyntax(self, reason: reason)
        }
    }
    
}

public struct SyntaxBuilder {
    
    private var terms: Array<String> = []
    
    var sql: String { terms.joined(separator: " ") }
    
    mutating func add(_ terms: String?...) {
        self.add(terms)
    }
    
    mutating func add(_ terms: Array<String?>?) {
        for term in terms ?? [] {
            if let term, term.isEmpty == false { self.terms.append(term) }
        }
    }
    
    mutating func addAlias(name: Name<Schema>? = nil, _ part: (any Syntax)?) throws(SyntaxError) {
        if let part {
            add("AS")
            try add(first: name, second: part)
        }
    }
    
    @_disfavoredOverload
    mutating func add(name: Name<Schema>? = nil, _ part: (any Syntax)?) throws(SyntaxError) {
        try add(first: name, second: part)
    }
    
    mutating func add<T: Syntax>(group: T?) throws(SyntaxError) {
        guard let group else { return }
        add("(")
        try add(group)
        add(")")
    }
    
    mutating func add(name: Name<Table>? = nil, _ wildcard: Wildcard) throws(SyntaxError) {
        try add(first: name, second: wildcard)
    }
    
    mutating func add<T: Syntax>(_ list: List<T>?) throws(SyntaxError) {
        if let list, list.items.isEmpty { return }
        try add(name: nil, list)
    }
    
    mutating func add<T: Syntax>(_ list: List<T>) throws(SyntaxError) {
        try add(name: nil, list)
    }
    
    private mutating func add(first: (any Syntax)?, second: (any Syntax)?) throws(SyntaxError) {
        try first?.validate()
        try second?.validate()
        
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
