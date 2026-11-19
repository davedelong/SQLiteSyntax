import Foundation
import SQLite3
import SQLiteSyntax

typealias Expr = SQLiteSyntax.Expression

/// A scratch in-memory database for checking SQL against SQLite itself.
final class Database {
    let handle: OpaquePointer

    init() {
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        handle = db!
        execute("CREATE TABLE t(a, b, c, x, y, z)")
    }

    deinit { sqlite3_close(handle) }

    @discardableResult
    func execute(_ sql: String) -> String? {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &message) != SQLITE_OK else { return nil }
        defer { sqlite3_free(message) }
        return message.map { String(cString: $0) }
    }

    /// nil if SQLite prepares `sql`, else its error message.
    func prepareError(_ sql: String) -> String? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        if sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK { return nil }
        return String(cString: sqlite3_errmsg(handle))
    }

    /// Whether SQLite reports a *syntax* problem (as opposed to e.g. an unknown function or column).
    func isSyntaxError(_ sql: String) -> Bool {
        guard let error = prepareError(sql) else { return false }
        return error.contains("syntax error") || error.contains("incomplete input") || error.contains("unrecognized token")
            || error.contains("unterminated")
    }

    /// Evaluates a constant expression: its type and text value, or the error.
    func evaluate(_ expression: String) -> String {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(handle, "SELECT \(expression)", -1, &statement, nil) == SQLITE_OK else {
            return "prepare error: \(String(cString: sqlite3_errmsg(handle)))"
        }
        guard sqlite3_step(statement) == SQLITE_ROW else { return "step error: \(String(cString: sqlite3_errmsg(handle)))" }
        let type = ["?", "integer", "real", "text", "blob", "null"][Int(sqlite3_column_type(statement, 0))]
        let text = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "NULL"
        return "\(type) \(text)"
    }
}

/// Renders an expression with explicit parentheses around every operator, to expose the tree's shape.
func parenthesized(_ e: Expr) throws -> String {
    func p(_ e: Expr) throws -> String { try parenthesized(e) }
    func not(_ negated: Bool) -> String { negated ? "NOT " : "" }
    switch e {
        case .binaryOperator(let l, let op, let r):
            return "(\(try p(l)) \(try op.sql()) \(try p(r)))"
        case .unaryOperator(let op, let x):
            let symbol: String
            switch op {
                case .negate: symbol = "-"
                case .plus: symbol = "+"
                case .bitwiseNot: symbol = "~"
                case .not: symbol = "NOT "
                default: return try e.sql()
            }
            return "(\(symbol)\(try p(x)))"
        case .between(let x, let negated, let lower, let upper):
            return "(\(try p(x)) \(not(negated))BETWEEN \(try p(lower)) AND \(try p(upper)))"
        case .like(let x, let negated, let pattern, let escape):
            return "(\(try p(x)) \(not(negated))LIKE \(try p(pattern))" + (try escape.map { " ESCAPE \(try p($0))" } ?? "") + ")"
        case .glob(let x, let negated, let pattern):
            return "(\(try p(x)) \(not(negated))GLOB \(try p(pattern)))"
        case .equals(let x, let negated, let distinct, let other):
            return "(\(try p(x)) IS \(not(negated))\(distinct ? "DISTINCT FROM " : "")\(try p(other)))"
        case .isNull(let x): return "(\(try p(x)) ISNULL)"
        case .notNull(let x): return "(\(try p(x)) NOTNULL)"
        case .collate(let x, let name): return "(\(try p(x)) COLLATE \(try name.sql()))"
        case .inExpression(let x, let negated, let list):
            return "(\(try p(x)) \(not(negated))IN (\(try list.map(p).joined(separator: ", "))))"
        case .expressionList(let list):
            return "(\(try list.map(p).joined(separator: ", ")))"
        default:
            return try e.sql()
    }
}
