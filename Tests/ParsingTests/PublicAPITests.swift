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
        .greaterThanOrEqual, .equals, .notEquals, .is, .isNot, .isDistinctFrom, .isNotDistinctFrom, .in, .notIn,
        .match, .notMatch, .like, .notLike, .regexp, .notRegexp, .glob, .notGlob, .and, .or,
    ])
    func binaryOperatorsParseAsTheyPrint(_ op: BinaryOperator) throws {
        #expect(try BinaryOperator(parsing: op.sql()) == op)
    }

    @Test func parseAllExpressions() throws {
        #expect(try Expression.parseAll("a, b + 1, max(c, d), (SELECT 1), x IN (1, 2)").map { try $0.sql() }
                == ["a", "b + 1", "max ( c , d )", "( SELECT 1 )", "x IN ( 1 , 2 )"])
        #expect(try Expression.parseAll("42;").map { try $0.sql() } == ["42"])
        #expect(try Expression.parseAll("").isEmpty)
        #expect(try Expression.parseAll("  -- nothing here\n").isEmpty)
        #expect(try Expression.parseAll(";").isEmpty)
        for bad in ["a,", ", a", "a b", "a,,b", "a; b"] {
            #expect(throws: ParseError.self, "\(bad)") { try Expression.parseAll(bad) }
        }
    }
}
