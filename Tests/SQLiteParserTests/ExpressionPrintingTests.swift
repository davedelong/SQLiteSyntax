import Foundation
import Testing
import SQLiteSyntax
@testable import SQLiteParser

/// `Expression.sql()` must add parentheses wherever an operand would otherwise bind differently,
/// so that trees built in code mean what they say.
struct ExpressionPrintingTests {

    let a: Expr = .columnName(nil, nil, "a")
    let b: Expr = .columnName(nil, nil, "b")
    let c: Expr = .columnName(nil, nil, "c")

    @Test func parenthesesOnlyWhereNeeded() throws {
        #expect(try Expr.binaryOperator(.binaryOperator(a, .add, b), .multiply, c).sql() == "( a + b ) * c")
        #expect(try Expr.binaryOperator(a, .add, .binaryOperator(b, .multiply, c)).sql() == "a + b * c")
        #expect(try Expr.binaryOperator(.binaryOperator(a, .subtract, b), .subtract, c).sql() == "a - b - c")
        #expect(try Expr.binaryOperator(a, .subtract, .binaryOperator(b, .subtract, c)).sql() == "a - ( b - c )")
        #expect(try Expr.binaryOperator(a, .subtract, .binaryOperator(b, .add, c)).sql() == "a - ( b + c )")
        #expect(try Expr.unaryOperator(.negate, .binaryOperator(a, .add, b)).sql() == "- ( a + b )")
        #expect(try Expr.unaryOperator(.not, .binaryOperator(a, .or, b)).sql() == "NOT ( a OR b )")
        #expect(try Expr.binaryOperator(.unaryOperator(.not, a), .and, b).sql() == "NOT a AND b")
        #expect(try Expr.binaryOperator(.binaryOperator(a, .or, b), .and, c).sql() == "( a OR b ) AND c")
        #expect(try Expr.between(a, negated: false, lower: .binaryOperator(b, .and, c), upper: 3).sql()
                == "a BETWEEN ( b AND c ) AND 3")
        #expect(try Expr.collate(.binaryOperator(a, .concat, b), "NOCASE").sql() == "( a || b ) COLLATE NOCASE")
        #expect(try Expr.isNull(.binaryOperator(a, .equals, b)).sql() == "a == b ISNULL")
        #expect(try Expr.equals(a, negated: false, distinct: false, from: .binaryOperator(b, .equals, c)).sql() == "a IS ( b == c )")
        #expect(try Expr.like(.binaryOperator(a, .or, b), negated: true, like: c, escape: nil).sql() == "( a OR b ) NOT LIKE c")
    }

    /// Random operator trees: SQLite must give the same value for our `sql()` as for a fully
    /// parenthesized rendering of the same tree, and parsing `sql()` must reproduce it.
    @Test func randomTreesMeanWhatTheySay() throws {
        let db = Database()
        var random = SeededRandom(seed: 20261119)
        var failures: [String] = []
        for _ in 0..<2000 {
            let tree = random.expression(depth: 4)
            let explicit = try parenthesized(tree)
            let printed = try tree.sql()
            let expected = db.evaluate(explicit)
            if db.evaluate(printed) != expected {
                failures.append("\(explicit)  printed as  \(printed)")
                continue
            }
            let reparsed = try Expr(parsing: printed)
            if try reparsed.sql() != printed || db.evaluate(try parenthesized(reparsed)) != expected {
                failures.append("\(printed)  re-parsed as  \(try parenthesized(reparsed))")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) of 2000 differ, e.g.\n\(failures.prefix(5).joined(separator: "\n"))")
    }
}

/// A small deterministic generator (64-bit LCG) so failures are reproducible.
struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next(_ n: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(n))
    }

    mutating func bool() -> Bool { next(2) == 0 }

    mutating func leaf() -> Expr {
        switch next(6) {
            case 0: return .literalValue(.string(["a", "b", "ab", "A"][next(4)]))
            case 1: return .literalValue(.null)
            default: return .literalValue(.number(Decimal(next(10))))
        }
    }

    static let binaryOperators: [BinaryOperator] = [
        .or, .and, .equals, .notEquals, .lessThan, .greaterThan, .lessThanOrEqual, .greaterThanOrEqual,
        .bitwiseAnd, .bitwiseOr, .leftShift, .rightShift, .add, .subtract, .multiply, .divide, .modulo, .concat,
        .is, .isNot, .isDistinctFrom, .isNotDistinctFrom,
    ]

    mutating func expression(depth: Int) -> Expr {
        if depth == 0 || next(5) == 0 { return leaf() }
        let d = depth - 1
        switch next(12) {
            case 0...4:
                let op = Self.binaryOperators[next(Self.binaryOperators.count)]
                return .binaryOperator(expression(depth: d), op, expression(depth: d))
            case 5:
                let op: UnaryOperator = [.not, .negate, .plus, .bitwiseNot][next(4)]
                return .unaryOperator(op, expression(depth: d))
            case 6:
                return .between(expression(depth: d), negated: bool(), lower: expression(depth: d), upper: expression(depth: d))
            case 7:
                return bool() ? .like(expression(depth: d), negated: bool(), like: expression(depth: d), escape: nil)
                              : .glob(expression(depth: d), negated: bool(), glob: expression(depth: d))
            case 8:
                return .equals(expression(depth: d), negated: bool(), distinct: bool(), from: expression(depth: d))
            case 9:
                return bool() ? .isNull(expression(depth: d)) : .notNull(expression(depth: d))
            case 10:
                return .collate(expression(depth: d), bool() ? "NOCASE" : "BINARY")
            default:
                return .inExpression(expression(depth: d), negated: bool(), List([expression(depth: d), expression(depth: d)]))
        }
    }
}
