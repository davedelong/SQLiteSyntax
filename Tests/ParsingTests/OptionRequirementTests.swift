import Testing
import SQLite3
@testable import SQLiteSyntax   // SQLiteOption(name:value:) is internal

/// Syntax that only exists when SQLite is compiled with an option: building checks it against the options
/// being built for (by default the linked SQLite's), as it checks versions.
@Suite struct OptionRequirementTests {

    @Test(arguments: [
        ("DELETE FROM t ORDER BY a LIMIT 1", [SQLiteOption.updateDeleteLimit]),
        ("DELETE FROM t LIMIT 1 OFFSET 2", [.updateDeleteLimit]),
        ("UPDATE t SET a = 1 LIMIT 1", [.updateDeleteLimit]),
        ("UPDATE t SET a = 1 ORDER BY b LIMIT 1", [.updateDeleteLimit]),
        ("DELETE FROM t WHERE a = 1", []),
        ("UPDATE t SET a = 1", []),
        ("SELECT percentile(50) WITHIN GROUP (ORDER BY a) FROM t", [.orderedSetAggregates]),
    ])
    func optionsAreRequiredOnlyWherePresent(_ sql: String, _ required: [SQLiteOption]) throws {
        let statement = try SQLStatement(parsing: sql)
        #expect(statement.requiredOptions == Set(required))
        #expect(throws: Never.self) { try statement.sql(sqliteVersion: nil, options: Set(required)) }
        #expect(throws: Never.self) { try statement.sql(sqliteVersion: nil, options: nil) }   // nil: nothing is checked
        for option in required {
            do {
                _ = try statement.sql(sqliteVersion: nil, options: Set(required).subtracting([option]))
                Issue.record("\(sql) built without \(option.name)")
            } catch .unsupportedOption(_, requires: let missing, current: _) {
                #expect(missing == option)
            } catch {
                Issue.record("unexpected \(error)")
            }
        }
    }

    /// By default, building agrees with the linked SQLite: it builds what that SQLite's options allow.
    @Test func defaultsFollowTheLinkedSQLite() throws {
        let statement = try SQLStatement(parsing: "DELETE FROM t ORDER BY a LIMIT 1")
        let linkedHasIt = sqlite3_compileoption_used("ENABLE_UPDATE_DELETE_LIMIT") != 0
        #expect(SQLiteOption.linkedOptions.contains(.updateDeleteLimit) == linkedHasIt)
        let output = try statement.sql(sqliteVersion: nil, options: nil)
        if linkedHasIt {
            #expect(throws: Never.self) { try statement.sql() }
            #expect(Database().prepareError(output) == nil)
        } else {
            #expect(throws: SyntaxError.self) { try statement.sql() }
        }
    }

    /// Option requirements don't stop the version from being collected, and vice versa.
    @Test func requirementsAreCollectedTogether() throws {
        let statement = try SQLStatement(parsing: "DELETE FROM t RETURNING a ORDER BY a LIMIT 1")
        #expect(statement.minimumRequiredVersion == SQLiteVersion(3, 35, 0))
        #expect(statement.requiredOptions == [.updateDeleteLimit])
    }

    static func omit(_ name: String) -> SQLiteOption { SQLiteOption(name: "OMIT_" + name, value: nil) }

    /// Syntax parse.y leaves out with `SQLITE_OMIT_…`: building for a SQLite with any of those options throws.
    static let omittedSyntax: [(String, [String])] = [
        ("PRAGMA foreign_keys", ["PRAGMA"]),
        ("VACUUM", ["VACUUM", "ATTACH"]),
        ("ALTER TABLE t RENAME TO u", ["ALTERTABLE", "VIRTUALTABLE"]),
        ("ATTACH 'x.db' AS x", ["ATTACH"]),
        ("CREATE TEMP TABLE t(a)", ["TEMPDB"]),
        ("CREATE TABLE t(a, b AS (a + 1))", ["GENERATED_COLUMNS"]),
        ("CREATE VIEW v AS SELECT 1", ["VIEW"]),
        ("CREATE TRIGGER r AFTER INSERT ON t BEGIN SELECT RAISE(IGNORE); END", ["TRIGGER"]),
        ("CREATE VIRTUAL TABLE v USING m", ["VIRTUALTABLE"]),
        ("EXPLAIN SELECT 1", ["EXPLAIN"]),
        ("WITH c AS (SELECT 1) SELECT * FROM c", ["CTE"]),
        ("SELECT 1 UNION SELECT 2", ["COMPOUND_SELECT"]),
        ("SELECT sum(a) OVER w FROM t WINDOW w AS (ORDER BY a)", ["WINDOWFUNC"]),
        ("SELECT count(*) FILTER (WHERE a) FROM t", ["WINDOWFUNC"]),
        ("SELECT * FROM (SELECT 1)", ["SUBQUERY"]),
        ("SELECT a IN (1, 2), EXISTS (SELECT 1) FROM t", ["SUBQUERY"]),
        ("SELECT CAST(a AS TEXT) FROM t", ["CAST"]),
        ("SELECT a FROM t WHERE b = 1 ORDER BY a", []),
        ("CREATE TABLE t(a)", []),
    ]

    @Test(arguments: omittedSyntax)
    func omittedSyntaxIsDisallowed(_ sql: String, _ omitted: [String]) throws {
        let statement = try SQLStatement(parsing: sql)
        let options = Set(omitted.map(Self.omit))
        #expect(statement.disallowedOptions == options)
        #expect(throws: Never.self) { try statement.sql(sqliteVersion: nil, options: []) }
        for option in options {
            do {
                _ = try statement.sql(sqliteVersion: nil, options: [option])
                Issue.record("\(sql) built with \(option.name)")
            } catch .unsupportedOption(_, requires: let reported, current: _) {
                #expect(reported == option)
            } catch {
                Issue.record("unexpected \(error)")
            }
        }
        // The linked SQLite omits none of these, so building for it is unaffected.
        #expect(SQLiteOption.linkedOptions.isDisjoint(with: options))
    }

    /// Required, disallowed and version requirements are all collected from one value.
    @Test func everyKindOfRequirementIsCollected() throws {
        let statement = try SQLStatement(parsing: "WITH c AS (SELECT 1) DELETE FROM t RETURNING a ORDER BY a LIMIT 1")
        #expect(statement.minimumRequiredVersion == SQLiteVersion(3, 35, 0))
        #expect(statement.requiredOptions == [.updateDeleteLimit])
        #expect(statement.disallowedOptions == [Self.omit("CTE")])
    }
}
