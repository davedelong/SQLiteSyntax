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

    /// Reads one value at the parser's position. Use `init(parsing:)` to parse a string.
    static func parse(_ parser: inout Parser) throws(ParseError) -> Self

    /// The earliest SQLite release that can run this syntax: the latest release that introduced any part of
    /// it that is present (an optional clause counts only when it is set). 3.0.0 if nothing needs a later one.
    var minimumRequiredVersion: SQLiteVersion { get }

}

extension Syntax {

    /// Parses SQL text that consists of exactly one of this syntax (a trailing `;` is allowed).
    public init(parsing sql: String) throws(ParseError) {
        self = try Parser.parseAll(sql) { (p: inout Parser) throws(ParseError) in try
            Self.parse(&p)
        }
    }

    public func validate() throws(SyntaxError) { }

    /// Builds the syntax without checking a release, recording the releases its parts require. Validation
    /// is skipped, so an incomplete value still reports what its present parts need.
    public var minimumRequiredVersion: SQLiteVersion {
        var builder = SyntaxBuilder(sqliteVersion: nil)
        builder.validates = false
        try? build(using: &builder)
        return builder.minimumRequiredVersion
    }
    
    /// The SQL for this syntax.
    ///
    /// - Parameter sqliteVersion: the SQLite release the SQL is for: by default the SQLite this process
    ///   links (`SQLiteVersion.linked`). Building throws `SyntaxError.unsupported` if the syntax needs a
    ///   later release. nil checks nothing.
    public func sql(sqliteVersion: SQLiteVersion? = .linked) throws(SyntaxError) -> String {
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

    /// The SQLite release being built for; syntax introduced after it fails to build. By default the SQLite
    /// this process links (`SQLiteVersion.linked`); nil checks nothing.
    public var sqliteVersion: SQLiteVersion?

    /// The latest release required by anything built so far; 3.0.0 if nothing needed a later one.
    public private(set) var minimumRequiredVersion = SQLiteVersion(3, 0, 0)

    /// Whether parts are validated as they are added (off when only collecting requirements).
    var validates = true

    public init(sqliteVersion: SQLiteVersion? = .linked) {
        self.sqliteVersion = sqliteVersion
    }

    /// Records that the syntax being built needs `version`, and throws `SyntaxError.unsupported` if that's
    /// later than the release being built for.
    public mutating func require(_ version: SQLiteVersion, for syntax: any Syntax) throws(SyntaxError) {
        minimumRequiredVersion = max(minimumRequiredVersion, version)
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
        // Every nested part is built through here, so this keeps deep nesting from overflowing the stack.
        guard StackGuard.hasRoom else { throw SyntaxError.nestedTooDeeply }
        if validates { try part.validate() }
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
    /// The syntax is nested too deeply to build with the stack this thread has left. (It doesn't carry
    /// the syntax: describing a value that deep would overflow the stack too.)
    case nestedTooDeeply
}
