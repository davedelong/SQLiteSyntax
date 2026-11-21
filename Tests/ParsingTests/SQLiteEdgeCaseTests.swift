import Testing
@testable import SQLiteSyntax

/// Edge cases where SQLite's parser decides differently from what the grammar alone suggests.
struct SQLiteEdgeCaseTests {

    static func database() -> Database {
        let db = Database()
        db.execute("CREATE TABLE w(a, unbounded)")
        return db
    }

    @Test(arguments: [
        // UNBOUNDED at the start of a frame bound is always the keyword.
        "SELECT sum(a) OVER (ORDER BY a RANGE BETWEEN UNBOUNDED FOLLOWING AND CURRENT ROW) FROM w",
        "SELECT sum(a) OVER (ORDER BY a ROWS BETWEEN 1 PRECEDING AND UNBOUNDED PRECEDING) FROM w",
        // Negating a hex literal that reads as Int64.min.
        "SELECT -0x8000000000000000",
        "SELECT -0x08000000000000000",
        "SELECT -((0x8000000000000000))",
        // Pragma values are names, numbers and ON/DELETE/DEFAULT.
        "PRAGMA compile_options(NULL)",
        "PRAGMA user_version = X'01'",
    ])
    func rejectedLikeSQLite(_ sql: String) {
        #expect(throws: ParseError.self) { try SQLStatement(parsing: sql) }
        #expect(Self.database().prepareError(sql) != nil)
    }

    @Test(arguments: [
        "SELECT unbounded FROM w WHERE a BETWEEN unbounded AND 5",
        "SELECT sum(a) OVER (ORDER BY a ROWS BETWEEN \"unbounded\" FOLLOWING AND UNBOUNDED FOLLOWING) FROM w",
        "SELECT sum(a) OVER (ORDER BY a ROWS UNBOUNDED PRECEDING) FROM w",
        "SELECT -9223372036854775808, -(-9223372036854775808), -(0x8000000000000000 + 0), -0x7FFFFFFFFFFFFFFF",
        "PRAGMA application_id = 'x'",
        "PRAGMA user_version = -1",
        "PRAGMA foreign_keys = ON",
    ])
    func acceptedLikeSQLite(_ sql: String) throws {
        _ = try SQLStatement(parsing: sql)
        #expect(Self.database().prepareError(sql) == nil)
    }
}
