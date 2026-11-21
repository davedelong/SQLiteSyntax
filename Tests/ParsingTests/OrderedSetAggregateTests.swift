import Testing
import SQLite3
import SQLiteSyntax

/// `f(args) WITHIN GROUP (ORDER BY x)` exists only in SQLite builds with SQLITE_ENABLE_ORDERED_SET_AGGREGATES
/// (since 3.47.0). Elsewhere WITHIN is an ordinary name, and must still parse as one.
@Suite struct OrderedSetAggregateTests {

    static let linkedHasThem = sqlite3_compileoption_used("ENABLE_ORDERED_SET_AGGREGATES") != 0

    @Test(arguments: [
        "percentile_cont(0.5) WITHIN GROUP (ORDER BY a)",
        "median() WITHIN GROUP (ORDER BY a + b COLLATE NOCASE)",
        "percentile(ALL 50) WITHIN GROUP (ORDER BY a) FILTER (WHERE b > 0)",
        "percentile_disc(0.25) WITHIN GROUP (ORDER BY a) OVER (PARTITION BY b)",
    ])
    func parsesAndRoundTrips(_ text: String) throws {
        let expression = try Expr(parsing: text)
        guard case .orderedSetAggregate = expression else {
            Issue.record("parsed as \(expression)")
            return
        }
        let output = try expression.sql(sqliteVersion: nil)
        #expect(try Expr(parsing: output).sql(sqliteVersion: nil) == output)
        #expect(expression.minimumRequiredVersion == SQLiteVersion(3, 47, 0))
        if Self.linkedHasThem {
            #expect(Database().prepareError("SELECT \(output) FROM t") == nil)
        }
    }

    @Test func buildsTheExpectedSQL() throws {
        let expression = Expr.orderedSetAggregate("percentile_cont", arguments: [0.5], withinGroup: .column("a"))
        #expect(try expression.sql(sqliteVersion: nil) == "percentile_cont ( 0.5 ) WITHIN GROUP ( ORDER BY a )")
        #expect(throws: SyntaxError.self) { try expression.sql(sqliteVersion: SQLiteVersion(3, 46, 0)) }
    }

    @Test(arguments: [
        "percentile(DISTINCT 50) WITHIN GROUP (ORDER BY a)",   // SQLite: DISTINCT not allowed on ordered-set aggregate
        "count(*) WITHIN GROUP (ORDER BY a)",
        "f(a ORDER BY b) WITHIN GROUP (ORDER BY a)",
        "f(a) WITHIN GROUP (ORDER BY a, b)",
        "f(a) WITHIN GROUP (ORDER BY a DESC)",
    ])
    func rejectsWhatSQLiteRejects(_ text: String) {
        #expect(throws: ParseError.self) { try Expr(parsing: text) }
        #expect(Database().prepareError("SELECT \(text) FROM t") != nil)
    }

    @Test func withinIsStillAName() throws {
        let db = Database()
        for sql in ["SELECT max(a) within FROM t", "SELECT a AS within FROM t", "SELECT within.a FROM t AS within"] {
            #expect(db.prepareError(sql) == nil, "SQLite rejects \(sql)")
            #expect(try SQLStatement(parsing: sql).sql() != "")
        }
    }
}
