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
    
    /// The SQL for this syntax.
    ///
    /// - Parameter sqliteVersion: the SQLite release the SQL is for. Building throws
    ///   `SyntaxError.unsupported` if the syntax needs a later release. nil (the default) checks nothing.
    public func sql(sqliteVersion: SQLiteVersion? = nil) throws(SyntaxError) -> String {
        try validate()
        var builder = SyntaxBuilder(sqliteVersion: sqliteVersion)
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

    /// The SQLite release being built for; syntax introduced after it fails to build.
    /// nil means the release is unknown, and nothing is checked.
    public var sqliteVersion: SQLiteVersion?

    public init(sqliteVersion: SQLiteVersion? = nil) {
        self.sqliteVersion = sqliteVersion
    }

    /// Throws `SyntaxError.unsupported` if `version` is later than the release being built for.
    public func require(_ version: SQLiteVersion, for syntax: any Syntax) throws(SyntaxError) {
        if let sqliteVersion, sqliteVersion < version {
            throw SyntaxError.unsupported(syntax, requires: version, sqliteVersion: sqliteVersion)
        }
    }
    
    var sql: String { terms.joined(separator: " ") }

    /// Set after a `.`, so the next term joins it: `schema` `.` `table` reads `schema.table`.
    private var joinsNext = false

    mutating func add(_ terms: String?...) {
        self.add(terms)
    }

    /// Adds fixed tokens. A `.` joins the terms on either side (qualified names: `main.t.a`, `t.*`).
    mutating func add(_ terms: Array<String?>?) {
        for term in terms ?? [] {
            guard let term, term.isEmpty == false else { continue }
            if (term == "." || joinsNext), let last = self.terms.indices.last {
                self.terms[last] += term
            } else {
                self.terms.append(term)
            }
            joinsNext = term == "."
        }
    }

    /// Validates and adds a syntax value; nothing if it's nil.
    mutating func add(_ part: (any Syntax)?) throws(SyntaxError) {
        guard let part else { return }
        try part.validate()
        try part.build(using: &self)
    }

    mutating func add<T: Syntax>(group: T?) throws(SyntaxError) {
        guard let group else { return }
        add("(")
        try add(group)
        add(")")
    }

    /// Adds a list; nothing if it's nil or empty.
    mutating func add<T: Syntax>(_ list: List<T>?) throws(SyntaxError) {
        guard let list, list.items.isEmpty == false else { return }
        try add(list as any Syntax)
    }

    mutating func add<T: Syntax>(_ list: List<T>) throws(SyntaxError) {
        guard list.items.isEmpty == false else { return }
        try add(list as any Syntax)
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
    /// The syntax needs a later SQLite release than the one being built for.
    case unsupported(any Syntax, requires: SQLiteVersion, sqliteVersion: SQLiteVersion)
}
