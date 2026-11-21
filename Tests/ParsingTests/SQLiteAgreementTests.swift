import Foundation
import Testing
@testable import SQLiteSyntax

/// Compares the parser with SQLite's own parser.
struct SQLiteAgreementTests {

    /// Constant expressions: SQLite evaluates the original text, our tree rendered with explicit
    /// parentheses, and our normal `sql()` output. All three must give the same value.
    static let constantExpressions = [
        "1 + 2 * 3", "(1 + 2) * 3", "1 - 2 - 3", "2 * 3 % 4", "7 / 2 * 2", "1 < 2 = 1", "2 = 2 < 3",
        "NOT 1 = 2", "NOT 0 AND 0", "1 OR 0 AND 0", "0 AND 0 OR 1", "-2 || 3", "'a' || 'b' || 'c'",
        "1 << 2 + 1", "5 & 3 | 8", "~1 + 1", "- - 1", "+1", "NOT NOT 1",
        "1 BETWEEN 0 AND 2 = 1", "2 NOT BETWEEN 3 AND 4", "1 + 2 BETWEEN 2 AND 3 + 1", "1 BETWEEN 0 AND 1 AND 0",
        "1 IN (1, 2, 3)", "4 NOT IN (1, 2)", "1 IN ()", "1 NOT IN ()", "1 IN (2) = 0", "(1, 2) = (1, 2)",
        "'abc' LIKE 'a%'", "'abc' NOT LIKE 'A_C'", "'a_c' LIKE 'a/_c' ESCAPE '/'", "'abc' GLOB 'a*'", "'x' NOT GLOB 'y'",
        "NULL IS NULL", "1 IS NOT 2", "1 IS DISTINCT FROM NULL", "1 IS NOT DISTINCT FROM 1", "NULL ISNULL", "1 NOTNULL", "1 NOT NULL",
        "1 = 1 IS 1", "1 IS 1 = 1", "1 < 2 IS 1",
        "CASE 1 WHEN 1 THEN 'one' ELSE 'other' END", "CASE WHEN 1 > 2 THEN 'a' WHEN 2 > 1 THEN 'b' END",
        "CAST('12' AS INTEGER) + 1", "CAST(3.7 AS INT)", "abs(-5) + length('hello')", "coalesce(NULL, 2, 3)",
        "max(1, 2, 3)", "'a' COLLATE NOCASE = 'A'", "'a' = 'A' COLLATE NOCASE", "x'414243'", "0x10 + 1", "1_000 + 1",
        ".5 + 1", "1e3 + 1", "json('{\"a\":1}') -> '$.a'", "json('{\"a\":1}') ->> '$.a'", "1 = 1 AND 2 = 2 OR 3 = 4",
        "upper('a') || lower('B')", "iif(1, 'a', 'b')", "CURRENT_DATE IS NOT NULL", "'5' + 5 * '2'",
        "(SELECT 1) + 1", "EXISTS (SELECT 1)", "NOT EXISTS (SELECT 1 WHERE 0)", "1 IN (SELECT 1 UNION SELECT 2)",
        "(SELECT max(x) FROM (SELECT 1 AS x UNION ALL SELECT 2))", "(VALUES (3), (4)) * 2",
        "(WITH c(n) AS (SELECT 5) SELECT n FROM c) - 1",
    ]

    @Test(arguments: constantExpressions)
    func constantExpressionsAgree(_ text: String) throws {
        let db = Database()
        let expression = try Expr(parsing: text)
        let expected = db.evaluate(text)
        #expect(!expected.hasPrefix("prepare error"), "test expression is invalid: \(expected)")
        #expect(db.evaluate(try parenthesized(expression)) == expected, "tree shape differs from SQLite's for: \(text)")
        #expect(db.evaluate(try expression.sql()) == expected, "sql() changes the meaning of: \(text)")
    }

    /// INTEGER and REAL literals keep their type through parse → `sql()`, so results don't change.
    @Test(arguments: ["1e3 + 1", "1.0 / 2", "typeof(2.0)", "typeof(1)", "typeof(1e3)", "typeof(9223372036854775807)",
                      "typeof(9223372036854775808)", "0x7FFFFFFFFFFFFFFF", "0xFFFFFFFFFFFFFFFF", "-9223372036854775808",
                      "1.5e-7 * 2", "0.1 + 0.2", "1e308 * 10", "1_000.000_5"])
    func numericLiteralsKeepTheirType(_ text: String) throws {
        let db = Database()
        let output = try Expr(parsing: text).sql()
        #expect(db.evaluate(output) == db.evaluate(text), "\(text) became \(output)")
    }

    @Test func numericLiteralRendering() throws {
        #expect(try LiteralValue.real(1).sql() == "1.0")
        #expect(try LiteralValue.real(1e16).sql() == "1e+16")
        #expect(try LiteralValue.real(.infinity).sql() == "9e999")
        #expect(try LiteralValue.real(-.infinity).sql() == "-9e999")
        #expect(try LiteralValue.real(.nan).sql() == "NULL")
        #expect(try LiteralValue.integer(42).sql() == "42")
        #expect(try LiteralValue.integer(.min).sql() == "-9223372036854775808")
        let db = Database()
        #expect(db.evaluate(try LiteralValue.integer(.min).sql()) == "integer -9223372036854775808")
        #expect(db.evaluate(try LiteralValue.real(.infinity).sql()) == "real Inf")
        // Swift literals map to the matching SQLite type.
        let one: Expr = 1, half: Expr = 0.5, whole: Expr = 2.0
        #expect(try [one.sql(), half.sql(), whole.sql()] == ["1", "0.5", "2.0"])
    }

    /// Names that are keywords, contain special characters, or start with a digit are double-quoted,
    /// so they stay identifiers (single quotes would turn them into string literals).
    @Test func specialNamesKeepTheirMeaning() throws {
        let db = Database()
        db.execute("CREATE TABLE k(\"key\", \"left\", \"my col\", \"1st\", \"a\"\"b\")")
        db.execute("INSERT INTO k VALUES (1, 'L', 2, 3, 4)")
        let cases: [(String, String)] = [
            ("key + 1", "\"key\" + 1"),
            ("left || 'x'", "\"left\" || 'x'"),
            ("\"my col\" * 2", "\"my col\" * 2"),
            ("[1st] - 1", "\"1st\" - 1"),
            ("\"a\"\"b\" + 0", "\"a\"\"b\" + 0"),
            ("replace('abc', 'b', 'x')", "\"replace\" ( 'abc' , 'b' , 'x' )"),
        ]
        for (text, expected) in cases {
            let output = try Expr(parsing: text).sql()
            #expect(output == expected)
            #expect(db.evaluate("\(output) FROM k") == db.evaluate("\(text) FROM k"), "\(text) became \(output)")
            #expect(!db.evaluate("\(output) FROM k").hasPrefix("prepare error"), "SQLite rejects \(output)")
        }
    }

    /// Expressions over columns: must parse, and our sql() output must also be accepted by SQLite.
    static let columnExpressions = [
        "a + b", "t.a", "main.t.a", "\"a\" + [b] + `c`", "count(*)", "count(DISTINCT a)", "sum(a) FILTER (WHERE b > 0)",
        "sum(a) OVER (PARTITION BY b ORDER BY c ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)",
        "sum(a) OVER (ORDER BY b RANGE UNBOUNDED PRECEDING EXCLUDE TIES)", "group_concat(a, ',' ORDER BY b DESC)",
        "a IN t", "a IN main.t", "a IN json_each('[1]')", "? + :name + @at + $tcl + ?2", "a COLLATE NOCASE",
        "a LIKE b ESCAPE '\\'", "a REGEXP b", "a MATCH b", "a GLOB b ESCAPE c", "a NOT REGEXP b ESCAPE '\\'",
        "a MATCH b ESCAPE c", "CASE WHEN a THEN b END", "CAST(a AS NUMERIC(10, 2))",
        "RAISE(IGNORE)", "RAISE(FAIL, 'x')",
        "a IN (SELECT b FROM t WHERE c > 1)", "EXISTS (SELECT 1 FROM t AS u WHERE u.a = t.a)",
        "(SELECT count(*) FROM t LEFT JOIN t AS t2 ON t.a = t2.b)", "a NOT IN (SELECT b FROM t ORDER BY b LIMIT 3)",
        "sum(a) OVER (PARTITION BY b ORDER BY c RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW EXCLUDE NO OTHERS)",
    ]

    @Test(arguments: columnExpressions)
    func columnExpressionsAgree(_ text: String) throws {
        let db = Database()
        #expect(!db.isSyntaxError("SELECT \(text) FROM t"), "test expression is invalid")
        let output = try Expr(parsing: text).sql()
        #expect(!db.isSyntaxError("SELECT \(output) FROM t"), "SQLite rejects our output: \(output)")
        #expect(try Expr(parsing: output).sql() == output, "re-parsing changes the output")
    }

    /// Syntax errors: SQLite and the parser must both reject these.
    static let invalidExpressions = [
        "1 +", "(1", "1 2", "CASE END", "a BETWEEN 1", "a NOT", "1 IN", "x'4'", "'unterminated", "1 = = 2", "a.", "f(,)",
        "CAST(1)", "1 ! 2", "a IS DISTINCT 1", "1 ESCAPE 2", "a b c", "(", ")", "1,", "a LIKE", "SELECT", "CASE 1 THEN 2 END",
        "a.b.c.d", "1 NOT", "count(DISTINCT *)",
    ]

    @Test(arguments: invalidExpressions)
    func invalidExpressionsAgree(_ text: String) {
        let db = Database()
        #expect(db.isSyntaxError("SELECT \(text) FROM t"), "SQLite accepts this, so it is not a useful test case")
        #expect(throws: ParseError.self) { try Expr(parsing: text) }
    }

    /// Every SQLite keyword, used on its own where a column name would go.
    @Test func keywordsUsedAsColumnNamesAgree() throws {
        var disagreements: [String] = []
        for keyword in Keywords.all.sorted() {
            let db = Database()
            db.execute("CREATE TABLE k(\"\(keyword)\")")
            let sqliteAccepts = !db.isSyntaxError("SELECT \(keyword) FROM k")
            let weAccept = (try? Expr(parsing: keyword)) != nil
            if sqliteAccepts != weAccept {
                disagreements.append("\(keyword): SQLite \(sqliteAccepts ? "accepts" : "rejects"), parser \(weAccept ? "accepts" : "rejects")")
            }
        }
        #expect(disagreements.isEmpty, "\(disagreements.joined(separator: "\n"))")
    }
}
