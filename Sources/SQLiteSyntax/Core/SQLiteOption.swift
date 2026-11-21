//
//  SQLiteOptions.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 11/21/26.
//

import SQLite3

public struct SQLiteOption: Hashable, Sendable {

    public static let orderedSetAggregates = SQLiteOption(name: "ENABLE_ORDERED_SET_AGGREGATES", value: nil)
    public static let updateDeleteLimit = SQLiteOption(name: "ENABLE_UPDATE_DELETE_LIMIT", value: nil)

    // Internal conveniences for every option the syntax checks (`.omitSubquery`, `.enableUpdateDeleteLimit`, …)
    // are generated into Generated/SQLiteOptions+Base.swift.

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.name == rhs.name
    }

    public static let linkedOptions: Set<SQLiteOption> = {
        var options: Set<SQLiteOption> = []
        var i: Int32 = 0
        while let option = sqlite3_compileoption_get(i) {
            let raw = String(cString: option)
            let pieces = raw.split(separator: "=", maxSplits: 2, omittingEmptySubsequences: false)
            if pieces.count == 2 {
                options.insert(SQLiteOption(name: String(pieces[0]), value: String(pieces[1])))
            } else {
                options.insert(SQLiteOption(name: String(pieces[0]), value: nil))
            }
            i += 1
        }
        return options
    }()

    public let name: String
    public let value: String?

    public var intValue: Int? { value.flatMap { Int($0) } }

    /// An option as `sqlite3_compileoption_get` reports it: its name without the `SQLITE_` prefix (e.g.
    /// `"OMIT_CTE"`, `"ENABLE_FTS5"`) and, for options with one, its value (`"THREADSAFE"`, `"2"`). Options
    /// compare by name alone.
    public init(name: String, value: String? = nil) {
        self.name = name
        self.value = value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

}
