import Foundation
import Testing
import SQLiteSyntax
@testable import SQLiteParser

/// Statements parsed by the generated parsers: the whole input is consumed, SQLite accepts the
/// re-printed SQL, and parsing that again gives the same SQL.
struct StatementParserTests {

    static let statements = [
        "SELECT * FROM t",
        "SELECT a, b AS c FROM t WHERE a > 1 GROUP BY b HAVING count(*) > 1 ORDER BY a DESC LIMIT 10 OFFSET 2",
        "SELECT DISTINCT t.a FROM t LEFT JOIN u ON t.a = u.a NATURAL JOIN t AS t2",
        "SELECT a FROM t AS x INDEXED BY i",
        "SELECT a FROM t NOT INDEXED",
        "SELECT x FROM (SELECT a AS x FROM t) AS s",
        "WITH RECURSIVE c(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM c WHERE n < 5) SELECT n FROM c",
        "SELECT a FROM t UNION SELECT b FROM u EXCEPT SELECT 1 ORDER BY 1",
        "VALUES (1, 2), (3, 4)",
        "SELECT sum(a) OVER w FROM t WINDOW w AS (PARTITION BY b ORDER BY a)",
        "INSERT INTO t (a, b) VALUES (1, 'x'), (2, 'y')",
        "INSERT OR REPLACE INTO main.t AS tt DEFAULT VALUES",
        "INSERT INTO t SELECT * FROM u WHERE true ON CONFLICT (a) DO UPDATE SET b = excluded.b WHERE b IS NULL RETURNING *",
        "REPLACE INTO t VALUES (1, 2)",
        "UPDATE t SET a = 1, (b, c) = (2, 3) FROM u WHERE t.a = u.a RETURNING a AS x",
        "UPDATE OR IGNORE t SET a = a + 1",
        "DELETE FROM t WHERE a IN (SELECT a FROM u) RETURNING *",
        "CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL DEFAULT 'x' COLLATE NOCASE, p REFERENCES t(id) ON DELETE CASCADE, CHECK (id > 0), UNIQUE (name)) STRICT",
        "CREATE TEMP TABLE t2 AS SELECT * FROM t",
        "CREATE TABLE g (a INT, b INT GENERATED ALWAYS AS (a * 2) STORED)",
        "CREATE UNIQUE INDEX IF NOT EXISTS i ON t (a COLLATE NOCASE DESC, b) WHERE a > 0",
        "CREATE VIEW v (x) AS SELECT a FROM t",
        "CREATE TRIGGER tr AFTER UPDATE OF a ON t FOR EACH ROW WHEN new.a > 0 BEGIN UPDATE u SET a = new.a; DELETE FROM u WHERE a = old.a; END",
        "CREATE VIRTUAL TABLE f USING fts5(content, tokenize = 'porter')",
        "ALTER TABLE t RENAME TO t3",
        "ALTER TABLE t ADD COLUMN z TEXT",
        "ALTER TABLE t RENAME COLUMN a TO aa",
        "DROP TABLE IF EXISTS main.t",
        "DROP INDEX i",
        "BEGIN IMMEDIATE TRANSACTION",
        "COMMIT",
        "ROLLBACK TO SAVEPOINT sp",
        "SAVEPOINT sp",
        "RELEASE sp",
        "PRAGMA main.journal_mode = WAL",
        "PRAGMA table_info(t)",
        "ANALYZE main.t",
        "REINDEX t",
        "VACUUM INTO 'backup.db'",
        "ATTACH DATABASE 'other.db' AS other",
        "DETACH other",
        "EXPLAIN QUERY PLAN SELECT * FROM t",
    ]

    @Test(arguments: statements)
    func statementRoundTrips(_ text: String) throws {
        var parser = try Parser(text)
        let statement = try SQLStatement.parse(&parser)
        #expect(parser.isAtEnd, "unparsed input from \(parser.current.display)")
        let output = try statement.sql()
        let db = Database()
        db.execute("CREATE TABLE u(a, b, c, x)")
        #expect(!db.isSyntaxError(output), "SQLite rejects: \(output)")
        var again = try Parser(output)
        #expect(try SQLStatement.parse(&again).sql() == output)
    }
}
