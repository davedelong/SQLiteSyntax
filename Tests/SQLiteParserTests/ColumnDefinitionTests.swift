import Foundation
import SQLite3
import Testing
import SQLiteSyntax
@testable import SQLiteParser

/// Column definitions mean what they mean to SQLite: the type name it records, and whether the column
/// is generated. `GENERATED ALWAYS` is the tricky part (see `ColumnDefinition.adjustedAfterParsing`).
struct ColumnDefinitionTests {

    static let definitions = [
        "a",
        "a INT",
        "a generated",
        "a generated always",
        "a always generated",
        "a INT generated",
        "a VARCHAR(10)",
        "a GENERATED ALWAYS AS (b)",
        "a INT GENERATED ALWAYS AS (b) STORED",
        "a INT(10) GENERATED ALWAYS AS (b) VIRTUAL",
        "a double precision generated always as (b * 2)",
        "a AS (b)",
        "a INT NOT NULL GENERATED ALWAYS AS (b)",
        "a CONSTRAINT g GENERATED ALWAYS AS (b)",
    ]

    /// SQLite's declared type and whether the column is generated, for `CREATE TABLE t(b, <definition>)`.
    static func sqlite(_ definition: String) throws -> (type: String, generated: Bool) {
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, "CREATE TABLE t(b, \(definition))", nil, nil, nil) == SQLITE_OK)
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        sqlite3_prepare_v2(db, "SELECT type, hidden FROM pragma_table_xinfo('t') WHERE name = 'a'", -1, &statement, nil)
        try #require(sqlite3_step(statement) == SQLITE_ROW)
        return (String(cString: sqlite3_column_text(statement, 0)), sqlite3_column_int(statement, 1) >= 2)
    }

    @Test(arguments: definitions)
    func typeAndGenerationAgreeWithSQLite(_ definition: String) throws {
        let expected = try Self.sqlite(definition)
        let column = try ColumnDefinition(parsing: definition)
        let type = column.typeName.map { $0.names.items.map(\.value).joined(separator: " ")
            + ($0.arguments.map { a in "(" + ((try? a.sql()) ?? "") + ")" } ?? "") } ?? ""
        let generated = column.constraints.contains { if case .generated = $0.constraint { return true } else { return false } }
        #expect(type.filter { !" ()".contains($0) } == expected.type.filter { !" ()".contains($0) })
        #expect(generated == expected.generated)
        // What we print means the same to SQLite (its type text keeps our quoting and spacing).
        func plain(_ type: String) -> String { type.lowercased().filter { !" \"()".contains($0) } }
        let reprinted = try Self.sqlite(column.sql())
        #expect(plain(reprinted.type) == plain(expected.type))
        #expect(reprinted.generated == expected.generated)
    }

    /// SQLite dequotes a declared type as a whole (`"always" "generated"` becomes `always`), so words it
    /// reads as identifiers are printed plain; other keywords still need quotes.
    @Test func typeWordsArePrintedAsSQLiteReadsThem() throws {
        #expect(try ColumnDefinition(parsing: "a always generated").sql() == "a always generated")
        #expect(try TypeName(names: ["DOUBLE", "precision"]).sql() == "DOUBLE precision")
        #expect(try TypeName(names: ["primary"]).sql() == "\"primary\"")
        #expect(try TypeName(names: ["my type"]).sql() == "\"my type\"")
        // Elsewhere keywords are still quoted.
        #expect(try Name<Column>("always").sql() == "\"always\"")
    }

    @Test func generatedAlwaysMovesFromTheTypeNameToTheConstraint() throws {
        let column = try ColumnDefinition(parsing: "a INT GENERATED ALWAYS AS (b) STORED")
        #expect(column.typeName?.names.items.map(\.value) == ["INT"])
        guard case .generated(let always, _, let storage)? = column.constraints.first?.constraint else {
            Issue.record("not a generated column: \(column)"); return
        }
        #expect(always && storage == .stored)
        #expect(try column.sql() == "a INT GENERATED ALWAYS AS ( b ) STORED")
    }
}
