import Testing
import SQLiteSyntax
import SQLiteParser   // not @testable: only the public API

/// The statement-level parsing API as a library user sees it.
struct PublicAPITests {

    @Test func readmeExample() throws {
        let statement = try SQLStatement(parsing: "SELECT a, b FROM t WHERE a > 1 ORDER BY b DESC")
        #expect(try statement.sql() == "SELECT a , b FROM t WHERE a > 1 ORDER BY b DESC")
        #expect(try Expression(parsing: "price * (1 + tax)").sql() == "price * ( 1 + tax )")
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
}
