import Foundation
import SQLite3
import Testing
@testable import SQLiteSyntax

/// Building for a SQLite release fails for syntax that release can't parse.
struct VersionRequirementTests {

    @Test func versionsParseAndCompare() {
        #expect(SQLiteVersion(number: 3_035_000) == SQLiteVersion(3, 35, 0))
        #expect(SQLiteVersion(3, 35, 0).number == 3_035_000)
        #expect(SQLiteVersion("3.35.0") == SQLiteVersion(3, 35))
        #expect(SQLiteVersion("3.9") == SQLiteVersion(3, 9, 0))
        #expect(SQLiteVersion(3, 9, 0) < SQLiteVersion(3, 10, 0))
        #expect(SQLiteVersion("3") == nil && SQLiteVersion("3.x") == nil && SQLiteVersion("3.1.2.3") == nil && SQLiteVersion("3.-1") == nil)
        #expect(SQLiteVersion(3, 8, 3).description == "3.8.3")
    }

    /// (SQL, the first release that can parse it).
    static let cases: [(String, SQLiteVersion)] = [
        ("SELECT a FROM t", SQLiteVersion(3, 0, 0)),
        ("SELECT a FROM t INDEXED BY i", SQLiteVersion(3, 6, 4)),
        ("WITH c AS (SELECT 1) SELECT * FROM c", SQLiteVersion(3, 8, 3)),
        ("CREATE TABLE t (a INTEGER PRIMARY KEY) WITHOUT ROWID", SQLiteVersion(3, 8, 2)),
        ("INSERT INTO t VALUES (1) ON CONFLICT DO NOTHING", SQLiteVersion(3, 24, 0)),
        ("SELECT a FROM t WINDOW w AS (ORDER BY a)", SQLiteVersion(3, 25, 0)),
        ("SELECT a FROM t ORDER BY a NULLS LAST", SQLiteVersion(3, 30, 0)),
        ("CREATE TABLE t (a, b AS (a * 2) STORED, CHECK (b > 0))", SQLiteVersion(3, 31, 0)),
        ("CREATE TABLE t (a, b GENERATED ALWAYS AS (a * 2))", SQLiteVersion(3, 31, 0)),
        ("CREATE TABLE t (a, b INT GENERATED ALWAYS AS (a * 2) STORED)", SQLiteVersion(3, 31, 0)),
        ("DELETE FROM t RETURNING *", SQLiteVersion(3, 35, 0)),
        ("WITH c AS MATERIALIZED (SELECT 1) SELECT * FROM c", SQLiteVersion(3, 35, 0)),
        // Dated by codegen.json `since` (the keywords are older than the syntax).
        ("ROLLBACK TO sp", SQLiteVersion(3, 6, 8)),
        ("UPDATE t SET a = 1 FROM u", SQLiteVersion(3, 33, 0)),
        ("ALTER TABLE t ADD CONSTRAINT c CHECK (a > 0)", SQLiteVersion(3, 52, 0)),
        ("ALTER TABLE t DROP CONSTRAINT c", SQLiteVersion(3, 52, 0)),
        ("ALTER TABLE t ALTER COLUMN a SET NOT NULL", SQLiteVersion(3, 52, 0)),
        // Hand-written expressions.
        ("SELECT count(a) FILTER (WHERE a > 0) FROM t", SQLiteVersion(3, 30, 0)),
        ("SELECT count(a) FILTER (WHERE a > 0) OVER () FROM t", SQLiteVersion(3, 25, 0)),
        ("SELECT a -> '$.x', a ->> '$.y' FROM t", SQLiteVersion(3, 38, 0)),
        ("SELECT a IS NOT DISTINCT FROM b FROM t", SQLiteVersion(3, 39, 0)),
    ]

    @Test(arguments: cases)
    func buildingRequiresTheReleaseThatIntroducedTheSyntax(_ sql: String, _ required: SQLiteVersion) throws {
        let statement = try SQLStatement(parsing: sql)
        #expect(throws: Never.self) { try statement.sql(sqliteVersion: required) }
        #expect(throws: Never.self) { try statement.sql() }   // no release given: nothing is checked
        guard required > SQLiteVersion(3, 0, 0) else { return }
        let earlier = SQLiteVersion(required.major, required.minor - 1, 99)
        do {
            _ = try statement.sql(sqliteVersion: earlier)
            Issue.record("\(sql) built for \(earlier)")
        } catch .unsupported(_, let requires, let sqliteVersion) {
            #expect(requires == required)
            #expect(sqliteVersion == earlier)
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test func theCheckReachesNestedValues() throws {
        // RETURNING is deep inside: SQLStatement -> DeleteStatement -> ReturningClause.
        let statement = try SQLStatement(parsing: "EXPLAIN DELETE FROM t RETURNING a")
        #expect(throws: SyntaxError.self) { try statement.sql(sqliteVersion: SQLiteVersion(3, 34, 1)) }
        // Including names built through a separate builder (`schema.table`).
        let builder = SyntaxBuilder(sqliteVersion: SQLiteVersion(3, 20, 0))
        #expect(builder.sqliteVersion == SQLiteVersion(3, 20, 0))
    }

    /// Everything the linked SQLite accepts builds for that SQLite's own version.
    @Test(arguments: StatementParserTests.statements)
    func statementsSQLiteAcceptsBuildForItsVersion(_ sql: String) throws {
        let linked = SQLiteVersion(number: sqlite3_libversion_number())
        #expect(throws: Never.self) { try SQLStatement(parsing: sql).sql(sqliteVersion: linked) }
    }
}
