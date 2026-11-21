import Testing
import SQLiteSyntax

/// The statement-level parsing API as a library user sees it.
struct PublicAPITests {

    @Test func readmeExample() throws {
        let statement = try SQLStatement(parsing: "SELECT a, b FROM t WHERE a > 1 ORDER BY b DESC")
        #expect(try statement.sql() == "SELECT a , b FROM t WHERE a > 1 ORDER BY b DESC")
        #expect(try Expression(parsing: "price * (1 + tax)").sql() == "price * ( 1 + tax )")
    }

    @Test func qualifiedNamesPrintWithoutSpaces() throws {
        #expect(try SQLStatement(parsing: "SELECT t.*, main.t.a FROM main.t WHERE a IN main.u").sql()
                == "SELECT t.* , main.t.a FROM main.t WHERE a IN main.u")
        #expect(try SQLStatement(parsing: "CREATE INDEX main.i ON t (a)").sql() == "CREATE INDEX main.i ON t ( a )")
        #expect(try SQLStatement(parsing: "PRAGMA main.journal_mode = WAL").sql() == "PRAGMA main.journal_mode = WAL")
        #expect(try Expression(parsing: "CAST(a AS INT)").sql() == "CAST ( a AS INT )")
    }

    @Test func theGeneratedAgainstReleaseIsPublic() {
        #expect(SQLiteVersion.generatedAgainst >= SQLiteVersion(3, 52, 0))   // the newest syntax it dates
    }

    @Test func minimumRequiredVersionCountsThePartsThatArePresent() throws {
        #expect(try SQLStatement(parsing: "DELETE FROM t").minimumRequiredVersion == SQLiteVersion(3, 0, 0))
        #expect(try SQLStatement(parsing: "DELETE FROM t RETURNING *").minimumRequiredVersion == SQLiteVersion(3, 35, 0))
        // The latest part wins, wherever it is nested.
        let select = try SelectStatement(parsing: "SELECT a -> '$' FROM t WHERE b IS NOT DISTINCT FROM c ORDER BY a NULLS LAST")
        #expect(select.minimumRequiredVersion == SQLiteVersion(3, 39, 0))
        #expect(try Expression(parsing: "a -> '$'").minimumRequiredVersion == SQLiteVersion(3, 38, 0))
        // Values made in code, even ones that don't validate (a FROM list needs at least one table).
        var statement = try UpdateStatement(parsing: "UPDATE t SET a = 1")
        #expect(statement.minimumRequiredVersion == SQLiteVersion(3, 0, 0))
        statement.from = .tables([])
        #expect(statement.minimumRequiredVersion == SQLiteVersion(3, 33, 0))
        #expect(throws: SyntaxError.self) { try statement.sql(sqliteVersion: nil) }
    }

    @Test func nullIsExplicit() throws {
        let value: Expression? = nil                      // Swift nil, not SQL NULL
        #expect(value.map { _ in true } == nil)
        #expect(try Expression.null.sql() == "NULL")
        if case .literalValue(.null) = try Expression(parsing: "NULL") {} else { Issue.record("NULL did not parse as a literal") }
    }

    @Test func sqlValidatesTheTopLevelValue() {
        #expect(throws: SyntaxError.self) { try Expression.when(nil, [], else: nil).sql() }
    }

    @Test func parseStatementList() throws {
        let script = try SQLStatementList(parsing: """
            CREATE TABLE t (a INTEGER PRIMARY KEY, b TEXT);
            INSERT INTO t (b) VALUES ('x');
            ;
            SELECT b FROM t WHERE a = 1;
            """)
        #expect(script.allStatements.count == 3)
        #expect(try script.allStatements.map { try $0.sql() } == [
            "CREATE TABLE t ( a INTEGER PRIMARY KEY , b TEXT )",
            "INSERT INTO t ( b ) VALUES ( 'x' )",
            "SELECT b FROM t WHERE a == 1",
        ])
    }

    @Test func parseSpecificStatementTypes() throws {
        let select = try SelectStatement(parsing: "SELECT a FROM t ORDER BY a LIMIT 3;")
        #expect(select.limit != nil && select.orderBy?.terms.count == 1)
        let statement = try SQLStatement(parsing: "EXPLAIN QUERY PLAN DELETE FROM t")
        #expect(try statement.sql() == "EXPLAIN QUERY PLAN DELETE FROM t")
        let constraint = try ColumnConstraint(parsing: "CONSTRAINT pk PRIMARY KEY DESC ON CONFLICT ROLLBACK")
        #expect(constraint.name?.value == "pk")
        // Values built by hand and parsed from text are the same kind of value.
        var create = Table.Create(name: "t")
        create.addColumn("a", type: .integer)
        #expect(try CreateTableStatement(parsing: try create.sql()).sql() == create.sql())
    }

    @Test func errorsPointAtTheProblem() {
        do {
            _ = try SQLStatement(parsing: "SELECT a FROM t\nWHERE a = ")
            Issue.record("expected an error")
        } catch {
            #expect(error.line == 2)
            #expect(error.column == 11)
        }
        #expect(throws: ParseError.self) { try SelectStatement(parsing: "SELECT a FROM t; SELECT b") }
        #expect(throws: ParseError.self) { try SQLStatement(parsing: "CREATE TABLE") }
    }

    @Test func everySyntaxTypeParses() throws {
        // Hand-written types, and a nested generated type, all get init(parsing:) from Syntax.
        #expect(try List<Name<Column>>(parsing: "a, \"b c\", key").map(\.value) == ["a", "b c", "key"])
        #expect(try Name<Table>(parsing: "[my table]").value == "my table")
        #expect(try BindParameter(parsing: "?3").sql() == "?3")
        #expect(try BindParameter(parsing: ":name").sql() == ":name")
        #expect(try SortDirection(parsing: "desc").sql() == "DESC")
        #expect(try LiteralValue(parsing: "X'0aff'").sql() == "X'0AFF'")
        #expect(try SelectStatement.CompoundsElement(parsing: "UNION ALL SELECT 1").sql() == "UNION ALL SELECT 1")
        #expect(throws: ParseError.self) { try List<Name<Column>>(parsing: "") }
        #expect(throws: ParseError.self) { try BindParameter(parsing: "a") }
    }

    @Test(arguments: [
        BinaryOperator.concat, .extractJSON, .extractValue, .multiply, .divide, .modulo, .add, .subtract,
        .bitwiseAnd, .bitwiseOr, .leftShift, .rightShift, .lessThan, .greaterThan, .lessThanOrEqual,
        .greaterThanOrEqual, .equals, .notEquals, .and, .or,
    ])
    func binaryOperatorsParseAsTheyPrint(_ op: BinaryOperator) throws {
        #expect(try BinaryOperator(parsing: op.sql()) == op)
    }

    /// Swift Testing runs this on a cooperative thread (512 KB stack), where this much nesting would
    /// overflow the stack if the parser didn't stop first.
    @Test func deepNestingThrowsInsteadOfCrashing() throws {
        let parentheses = String(repeating: "(", count: 20_000) + "1" + String(repeating: ")", count: 20_000)
        let subqueries = String(repeating: "(SELECT ", count: 5_000) + "1" + String(repeating: ")", count: 5_000)
        for sql in [parentheses, subqueries] {
            #expect {
                _ = try SQLStatementList(parsing: "SELECT " + sql)
            } throws: { error in
                (error as? ParseError)?.message == "SQL is nested too deeply to parse"
            }
        }
        // Moderate nesting still parses. (On a 512 KB stack a debug build manages about 38 levels of
        // parentheses and 16 of subqueries; a release build about 570 and 100.)
        let nested = String(repeating: "(", count: 10) + "1" + String(repeating: ")", count: 10)
        #expect(try Expression(parsing: nested).sql().filter { $0 != " " } == nested)
    }

    /// Values made in code can be nested more deeply than the parser allows; building them throws
    /// instead of overflowing the stack.
    @Test func deeplyNestedValuesThrowWhenBuilt() throws {
        var expression = Expression.literalValue(.integer(1))
        for _ in 0..<3_000 { expression = .unaryOperator(.negate, expression) }
        do {
            _ = try expression.sql()
            Issue.record("building should have thrown nestedTooDeeply")
        } catch .nestedTooDeeply {
        } catch {
            Issue.record("expected nestedTooDeeply")   // not printed: a description could be as deep as the value
        }
    }
}
