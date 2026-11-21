import Testing
import SQLite3
import SQLiteSyntax

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
}
