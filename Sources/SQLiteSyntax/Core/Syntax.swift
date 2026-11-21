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

    /// The compile-time options SQLite needs to run this syntax, counting only the parts that are present
    /// (e.g. `ENABLE_UPDATE_DELETE_LIMIT` for `DELETE … LIMIT`). Empty if a default build can run it.
    var requiredOptions: Set<SQLiteOption> { get }

    /// The compile-time options that leave out part of this syntax (`OMIT_…`), counting only the parts that
    /// are present: SQLite built with any of them can't run it. Empty if every build can.
    var disallowedOptions: Set<SQLiteOption> { get }

}

extension Syntax {

    /// Parses SQL text that consists of exactly one of this syntax (a trailing `;` is allowed).
    public init(parsing sql: String) throws(ParseError) {
        self = try Parser.parseAll(sql) { (p: inout Parser) throws(ParseError) in try
            Self.parse(&p)
        }
    }

    public func validate() throws(SyntaxError) { }

    public var minimumRequiredVersion: SQLiteVersion { recordedRequirements.minimumRequiredVersion }

    public var requiredOptions: Set<SQLiteOption> { recordedRequirements.requiredOptions }

    public var disallowedOptions: Set<SQLiteOption> { recordedRequirements.disallowedOptions }

    /// Builds the syntax without checking a release or options, recording what its parts require.
    /// Validation is skipped, so an incomplete value still reports what its present parts need.
    private var recordedRequirements: SyntaxBuilder {
        var builder = SyntaxBuilder(sqliteVersion: nil, options: nil)
        builder.validates = false
        try? build(using: &builder)
        return builder
    }

    /// The SQL for this syntax.
    ///
    /// - Parameters:
    ///   - sqliteVersion: the SQLite release the SQL is for: by default the SQLite this process links
    ///     (`SQLiteVersion.linked`). Building throws `SyntaxError.unsupportedVersion` if the syntax needs a later
    ///     release. nil checks nothing.
    ///   - options: the compile-time options that SQLite was built with: by default the linked SQLite's
    ///     (`SQLiteOption.linkedOptions`). Building throws `SyntaxError.unsupportedOption` if the syntax needs
    ///     one that's missing, or one of them leaves it out (`OMIT_…`). nil checks nothing.
    public func sql(sqliteVersion: SQLiteVersion? = .linked,
                    options: Set<SQLiteOption>? = SQLiteOption.linkedOptions) throws(SyntaxError) -> String {
        try validate()
        var builder = SyntaxBuilder(sqliteVersion: sqliteVersion, options: options)
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

    /// The compile-time options SQLite was built with; syntax that needs another fails to build. By default
    /// the linked SQLite's (`SQLiteOption.linkedOptions`); nil checks nothing.
    public var options: Set<SQLiteOption>?

    /// The latest release required by anything built so far; 3.0.0 if nothing needed a later one.
    public private(set) var minimumRequiredVersion = SQLiteVersion(3, 0, 0)

    /// The compile-time options required by anything built so far.
    public private(set) var requiredOptions = Set<SQLiteOption>()

    /// The compile-time options that must not be set (`OMIT_…`) for anything built so far.
    public private(set) var disallowedOptions = Set<SQLiteOption>()

    /// Whether parts are validated as they are added (off when only collecting requirements).
    var validates = true

    public init(sqliteVersion: SQLiteVersion? = .linked, options: Set<SQLiteOption>? = SQLiteOption.linkedOptions) {
        self.sqliteVersion = sqliteVersion
        self.options = options
    }

    /// Records that the syntax being built needs `version`, and throws `SyntaxError.unsupportedVersion` if that's
    /// later than the release being built for.
    public mutating func require(_ version: SQLiteVersion, for syntax: any Syntax) throws(SyntaxError) {
        minimumRequiredVersion = max(minimumRequiredVersion, version)
        if let sqliteVersion, sqliteVersion < version {
            throw SyntaxError.unsupportedVersion(syntax, requires: version, sqliteVersion: sqliteVersion)
        }
    }

    /// Records that the syntax being built needs `option`, and throws `SyntaxError.unsupportedOption` if the
    /// options being built for don't include it.
    public mutating func require(_ option: SQLiteOption, for syntax: any Syntax) throws(SyntaxError) {
        requiredOptions.insert(option)
        if let options, options.contains(option) == false {
            throw SyntaxError.unsupportedOption(syntax, requires: option, current: options)
        }
    }

    /// Records that the syntax being built is left out by `option` (an `OMIT_…` option), and throws
    /// `SyntaxError.unsupportedOption` if the options being built for include it.
    public mutating func disallow(_ option: SQLiteOption, for syntax: any Syntax) throws(SyntaxError) {
        disallowedOptions.insert(option)
        if let options, options.contains(option) == true {
            throw SyntaxError.unsupportedOption(syntax, requires: option, current: options)
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
        guard Thread.current.hasRemainingStackSpace else { throw SyntaxError.nestedTooDeeply }
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
    case unsupportedVersion(any Syntax, requires: SQLiteVersion, sqliteVersion: SQLiteVersion)
    /// The syntax needs different SQLite options than the ones currently available.
    case unsupportedOption(any Syntax, requires: SQLiteOption, current: Set<SQLiteOption>)
    /// The syntax is nested too deeply to build with the stack this thread has left. (It doesn't carry
    /// the syntax: describing a value that deep would overflow the stack too.)
    case nestedTooDeeply
}
