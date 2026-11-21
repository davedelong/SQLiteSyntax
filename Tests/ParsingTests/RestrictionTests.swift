import Testing
@testable import SQLiteSyntax

/// Restrictions SQLite enforces beyond its grammar diagrams (`Core/Restrictions.swift`).
struct RestrictionTests {

    static let rejected: [(String, String)] = [
        ("CREATE TRIGGER r AFTER INSERT ON t BEGIN UPDATE u INDEXED BY i SET a = 1; END",
         "the INDEXED BY clause is not allowed on UPDATE or DELETE statements within triggers"),
        ("CREATE TRIGGER r AFTER INSERT ON t BEGIN DELETE FROM u NOT INDEXED WHERE a = 1; END",
         "the NOT INDEXED clause is not allowed on UPDATE or DELETE statements within triggers"),
        ("CREATE TRIGGER r AFTER INSERT ON t BEGIN INSERT INTO u DEFAULT VALUES; END",
         "DEFAULT VALUES is not allowed within triggers"),
        ("CREATE TRIGGER r AFTER INSERT ON t BEGIN WITH c AS (SELECT 1) DELETE FROM u; END",
         "WITH is not allowed on INSERT, UPDATE or DELETE statements within triggers"),
        ("CREATE TRIGGER r AFTER INSERT ON t BEGIN UPDATE u SET a = 1 RETURNING *; END",
         "cannot use RETURNING in a trigger"),
        ("SELECT string_agg(DISTINCT a, ',') FROM t", "DISTINCT aggregates must have exactly one argument"),
        ("SELECT * FROM t LEFT INNER JOIN u", "unknown join type: INNER or CROSS with an outer join"),
        ("SELECT * FROM t OUTER JOIN u", "unknown join type: OUTER needs LEFT, RIGHT or FULL"),
        ("SELECT * FROM t LEFT OUTER LEFT OUTER JOIN u", "unknown join type: at most three join keywords"),
    ]

    @Test(arguments: rejected)
    func rejectedWithSQLitesReason(_ sql: String, _ reason: String) {
        #expect {
            _ = try SQLStatement(parsing: sql)
        } throws: { error in
            (error as? ParseError)?.message == reason
        }
        // SQLite rejects them too, with the tables they use.
        let db = Database()
        db.execute("CREATE TABLE u(a); CREATE INDEX i ON u(a)")
        #expect(db.prepareError(sql) != nil)
    }

    @Test(arguments: [
        "CREATE TRIGGER r AFTER INSERT ON t BEGIN UPDATE u AS q SET a = q.a + 1; INSERT INTO u SELECT 1; INSERT INTO u VALUES (1); INSERT INTO u WITH c AS (SELECT 1) SELECT * FROM c; DELETE FROM u WHERE a = 1; SELECT 1; END",
        "SELECT count(DISTINCT a), group_concat(ALL a, ','), count(a, b) FROM t",
        "UPDATE t SET a = 1 ORDER BY a LIMIT 1",
    ])
    func allowed(_ sql: String) throws {
        _ = try SQLStatement(parsing: sql)
    }

    @Test func updateOrderByNeedsLimit() {
        #expect(throws: ParseError.self) { try SQLStatement(parsing: "UPDATE t SET a = 1 ORDER BY a") }
    }

    @Test func aConstraintNeedsANameOrABody() {
        let definition = ColumnDefinition(name: "a", constraints: [ColumnConstraint()])
        #expect(throws: SyntaxError.self) { try definition.sql() }
    }

    /// Values made in code are checked when building.
    @Test func buildingChecksTheRestrictions() throws {
        var trigger = try CreateTriggerStatement(parsing: "CREATE TRIGGER r AFTER INSERT ON t BEGIN INSERT INTO u SELECT 1; END")
        let insert = try InsertStatement(parsing: "INSERT INTO u DEFAULT VALUES")
        trigger.statements = [.insertStatement(insert)]
        #expect(throws: SyntaxError.self) { try trigger.sql() }
    }
}
