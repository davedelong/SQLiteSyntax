import Foundation
import SQLite3
import Testing
@testable import SQLiteSyntax

/// Builds SQL with the generated types (Sources/SQLiteSyntax/Generated) and checks that
/// SQLite's parser accepts it, embedded in a full statement.
///
/// Only *syntax* errors count as failures: the diagrams deliberately allow some combinations that
/// SQLite rejects for other reasons (e.g. "unsupported frame specification" for a frame that ends
/// before it starts), and those are outside what a grammar-derived type can enforce.
struct GeneratedSyntaxTests {

    /// Prepares `sql` against an in-memory database with tables `t(a, b)` and `u(a, b)`.
    /// Returns nil on success, or SQLite's error message.
    static func prepareError(_ sql: String) -> String? {
        var db: OpaquePointer?
        guard sqlite3_open(":memory:", &db) == SQLITE_OK else { return "cannot open database" }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "CREATE TABLE t(a, b); CREATE TABLE u(a, b);", nil, nil, nil)
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK { return nil }
        return String(cString: sqlite3_errmsg(db))
    }

    func expectAccepted(_ sql: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let error = Self.prepareError(sql)
        let isSyntaxError = error.map { $0.contains("syntax error") || $0.contains("incomplete input") } ?? false
        #expect(!isSyntaxError, "SQLite rejected: \(sql) — \(error ?? "")", sourceLocation: sourceLocation)
    }

    let a: SQLiteSyntax.Expression = .columnName(nil, nil, "a")

    // MARK: Exact SQL

    @Test func orderingTermSQL() throws {
        let term = OrderingTerm(expression: a, collationName: "NOCASE", sortDirection: .descending, nulls: .last)
        #expect(try term.sql() == "a COLLATE NOCASE DESC NULLS LAST")
        #expect(try OrderingTerm(expression: a).sql() == "a")
    }

    @Test func frameSpecSQL() throws {
        let frame = FrameSpec(unit: .rows, extent: .between(start: .preceding(1), end: .currentRow), exclude: .ties)
        #expect(try frame.sql() == "ROWS BETWEEN 1 PRECEDING AND CURRENT ROW EXCLUDE TIES")
    }

    @Test func joinOperatorSQL() throws {
        #expect(try JoinOperator.comma.sql() == ",")
        #expect(try JoinOperator.join().sql() == "JOIN")   // not expressible with the hand-written JoinOperator
        #expect(try JoinOperator.join(natural: true, kind: .leftOuter).sql() == "NATURAL LEFT OUTER JOIN")
    }

    @Test func columnConstraintSQL() throws {
        let pk = ColumnConstraint(name: Name(value: "pk"),
                                    constraint: .primaryKey(sortDirection: .ascending, conflict: .abort, autoincrement: true))
        #expect(try pk.sql() == "CONSTRAINT pk PRIMARY KEY ASC ON CONFLICT ABORT AUTOINCREMENT")
        let generated = ColumnConstraint(constraint: .generated(generatedAlways: true, expression: a, storage: .stored))
        #expect(try generated.sql() == "GENERATED ALWAYS AS ( a ) STORED")
        let negative = ColumnConstraint(constraint: .default(.signedNumber(SignedNumber(sign: .minus, numericLiteral: 5))))
        #expect(try negative.sql() == "DEFAULT - 5")
    }

    @Test func emptyUsingListIsRejected() {
        // The list lives in the nested ColumnNameList, which is validated when it is built.
        #expect(throws: SyntaxError.self) { try JoinConstraint.using(ColumnNameList(columnNames: [])).sql() }
    }

    // MARK: SELECT family (recursive types)

    @Test func selectStatementsParse() throws {
        func select(from table: TableOrSubquery) -> SelectStatement {
            SelectStatement(selectCore: .select(resultColumns: [.expression(expression: a)],
                                                source: .from(from: .tables([table]), where: .binaryOperator(a, .greaterThan, 1))))
        }
        let plain = select(from: .tableName(tableName: "t"))
        // FROM ( SELECT … ) AS s: recursion through the indirect TableOrSubquery
        let nested = select(from: .parenthesized(.aliasedSubquery(selectStatement: plain, as: true, tableAlias: "s")))
        // WITH c AS MATERIALIZED ( SELECT … ) SELECT a FROM c
        var withCTE = select(from: .tableName(tableName: "c"))
        withCTE.with = With(commonTableExpressions: [CommonTableExpression(cteTableName: CTETableName(tableName: "c"),
                                                                           materialized: .init(), selectStatement: plain)])
        // … UNION ALL VALUES (1), (2)   (SQLite rejects ORDER BY/LIMIT after VALUES, though the diagram allows it)
        var values = plain
        values.compounds = [.init(compoundOperator: .union(all: true), selectCore: .values(Values(values: [[1], [2]])))]
        // … EXCEPT SELECT a FROM t ORDER BY 1 DESC LIMIT 5 OFFSET 1
        var compound = plain
        compound.compounds = [.init(compoundOperator: .except, selectCore: plain.selectCore)]
        compound.orderBy = OrderBy(terms: [OrderingTerm(expression: 1, sortDirection: .descending)])
        compound.limit = Limit(limit: 5, offset: .offset(1))

        #expect(try nested.sql() == "SELECT a FROM ( SELECT a FROM t WHERE a > 1 ) AS s WHERE a > 1")
        #expect(try withCTE.sql() == "WITH c AS MATERIALIZED ( SELECT a FROM t WHERE a > 1 ) SELECT a FROM c WHERE a > 1")
        for statement in [plain, nested, withCTE, values, compound] {
            expectAccepted(try statement.sql())
        }
    }

    // MARK: Hand-written fixes found by the generated types

    @Test func handWrittenFilterClauseIncludesWhere() throws {
        let filter = Filter(where: .binaryOperator(a, .greaterThan, 1))
        #expect(try filter.sql() == "FILTER ( WHERE a > 1 )")
        expectAccepted("SELECT count(*) \(try filter.sql()) FROM t")
    }

    @Test func qualifiedColumnNamesUseDots() throws {
        #expect(try SQLiteSyntax.Expression.columnName(nil, nil, "a").sql() == "a")
        #expect(try SQLiteSyntax.Expression.columnName(nil, "t", "a").sql() == "t.a")
        #expect(try SQLiteSyntax.Expression.columnName("main", "t", "a").sql() == "main.t.a")
        #expect(try SQLiteSyntax.Expression.columnName(nil, "my table", "a").sql() == "\"my table\".a")
        for column in [SQLiteSyntax.Expression.columnName(nil, "t", "a"), .columnName("main", "t", "a")] {
            expectAccepted("SELECT \(try column.sql()) FROM t")
        }
    }

    // MARK: SQLite accepts every generated case

    @Test func conflictClausesParse() throws {
        for c in Conflict.allCases {
            expectAccepted("CREATE TABLE x (c INTEGER NOT NULL \(try c.sql()))")
            expectAccepted("CREATE TABLE x (c INTEGER \(try ColumnConstraint(constraint: .unique(c)).sql()))")
        }
    }

    @Test func columnConstraintsParse() throws {
        let constraints: [ColumnConstraint.Constraint] = [
            .check(.binaryOperator(.columnName(nil, nil, "c"), .greaterThan, 0)),
            .collate("NOCASE"),
            .default(.expression(1)),
            .default(.literalValue(.string("x"))),
            .default(.signedNumber(SignedNumber(sign: .plus, numericLiteral: 1.5))),
            .notNull(),
            .primaryKey(),
            .primaryKey(sortDirection: .descending, conflict: .replace, autoincrement: false),
            .unique(),
            .generated(expression: .columnName(nil, nil, "d")),
            .generated(generatedAlways: true, expression: .columnName(nil, nil, "d"), storage: .virtual),
        ] + ColumnConstraint.Constraint.Storage.allCases.map {
            .generated(generatedAlways: true, expression: .columnName(nil, nil, "d"), storage: $0)
        }
        for constraint in constraints {
            for name in [nil, Name<Any>(value: "named")] {
                let sql = try ColumnConstraint(name: name, constraint: constraint).sql()
                expectAccepted("CREATE TABLE x (c INTEGER \(sql), d INTEGER)")
            }
        }
        expectAccepted("CREATE TABLE x (c INTEGER PRIMARY KEY AUTOINCREMENT)")
    }

    @Test func orderingTermsParse() throws {
        for direction in [nil, SortDirection.ascending, .descending] {
            for nulls in [nil] + OrderingTerm.Nulls.allCases {
                for collation in [nil, Name<Collation>("NOCASE")] {
                    let term = OrderingTerm(expression: a, collationName: collation, sortDirection: direction, nulls: nulls)
                    expectAccepted("SELECT a FROM t ORDER BY \(try term.sql())")
                }
            }
        }
    }

    @Test func indexedColumnsParse() throws {
        for target in [IndexedColumn.Target.columnName("a"), .expression(.binaryOperator(a, .add, 1))] {
            for direction in [nil, SortDirection.ascending, .descending] {
                let column = IndexedColumn(target: target, collationName: "BINARY", sortDirection: direction)
                expectAccepted("CREATE INDEX i ON t (\(try column.sql()))")
            }
        }
    }

    @Test func frameSpecsParse() throws {
        let starts: [FrameSpec.Extent.Start] = [.currentRow, .unboundedPreceding, .following(1), .preceding(1)]
        let ends: [FrameSpec.Extent.End] = [.currentRow, .unboundedFollowing, .following(2), .preceding(0)]
        var extents: [FrameSpec.Extent] = [.currentRow, .unboundedPreceding, .preceding(1)]
        for s in starts { for e in ends { extents.append(.between(start: s, end: e)) } }
        for unit in FrameSpec.Unit.allCases {
            for extent in extents {
                for exclude in [nil] + FrameSpec.Exclude.allCases {
                    let frame = FrameSpec(unit: unit, extent: extent, exclude: exclude)
                    expectAccepted("SELECT sum(a) OVER (ORDER BY a \(try frame.sql())) FROM t")
                }
            }
        }
    }

    @Test func joinsParse() throws {
        expectAccepted("SELECT * FROM t \(try JoinOperator.comma.sql()) u")
        expectAccepted("SELECT * FROM t \(try JoinOperator.crossJoin().sql()) u")
        for kind in [nil] + JoinOperator.Kind.allCases {
            expectAccepted("SELECT * FROM t \(try JoinOperator.join(natural: true, kind: kind).sql()) u")
            let on = JoinConstraint.on(.binaryOperator(.columnName(nil, "t", "a"), .equals, .columnName(nil, "u", "a")))
            let using = JoinConstraint.using(ColumnNameList(columnNames: ["a"]))
            for constraint in [on, using] {
                expectAccepted("SELECT * FROM t \(try JoinOperator.join(kind: kind).sql()) u \(try constraint.sql())")
            }
        }
    }

    @Test func filterClauseIncludesWhere() throws {
        // The grammar is `'FILTER' '(' 'WHERE' expr ')'`.
        #expect(try Filter(where: a).sql() == "FILTER ( WHERE a )")
    }

    @Test func compoundOperatorsAndFiltersParse() throws {
        for op in [CompoundOperator.except, .intersect, .union(), .union(all: true)] {
            expectAccepted("SELECT a FROM t \(try op.sql()) SELECT b FROM u")
        }
        expectAccepted("SELECT count(*) \(try Filter(where: .binaryOperator(a, .greaterThan, 1)).sql()) FROM t")
    }
}
