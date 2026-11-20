//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public indirect enum Expression: Syntax {
    
    case literalValue(LiteralValue)
    case bindParameter(BindParameter)
    case columnName(Name<Schema>?, Name<Table>?, Name<Column>)
    case unaryOperator(UnaryOperator, Expression)
    case binaryOperator(Expression, BinaryOperator, Expression)
    /// `name ( arguments ) [ filter ] [ over ]`; `nil` arguments is `name ( )`.
    case function(Name<Function>, FunctionArguments?, FilterClause?, OverClause?)
    case expressionList(List<Expression>)
    case cast(Expression, as: TypeName)
    case collate(Expression, Name<Collation>)
    case like(Expression, negated: Bool, like: Expression, escape: Expression?)
    case glob(Expression, negated: Bool, glob: Expression)
    case regexp(Expression, negated: Bool, regexp: Expression)
    case match(Expression, negated: Bool, match: Expression)
    case isNull(Expression)
    case notNull(Expression)
    case equals(Expression, negated: Bool, distinct: Bool, from: Expression)
    case between(Expression, negated: Bool,lower: Expression, upper: Expression)
    case inStatement(Expression, negated: Bool, SelectStatement)
    case inExpression(Expression, negated: Bool, List<Expression>)
    case inTable(Expression, negated: Bool, Name<Schema>?, Name<Table>?)
    case inTableFunction(Expression, negated: Bool, Name<Schema>?, Name<Function>, [Expression])
    case select(SelectStatement)
    case exists(negated: Bool, SelectStatement)
    case when(Expression?, Array<(when: Expression, then: Expression)>, else: Expression?)
    case raise(RaiseFunction)
    
    public func validate() throws(SyntaxError) {
        switch self {
            case .when(_, let whens, else: _):
                try require(whens.count > 0, reason: "A CASE WHEN expression must have at least one when-then clausee")
            default:
                break
        }
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .literalValue(let v):
                try builder.add(v)
            case .bindParameter(let p):
                try builder.add(p)
            case .columnName(let s, let t, let c):
                try builder.addQualified(s, t, c)
            case .unaryOperator(let o, let e):
                let argument: any Syntax = e.precedence < o.precedence ? Group(contents: e) : e
                try o.build(using: &builder, argument: argument)
            case .binaryOperator(let left, let op, let right):
                // All binary operators are left-associative: an equal-precedence right operand needs parentheses.
                try builder.addOperand(left, minimum: op.precedence)
                try builder.add(op)
                try builder.addOperand(right, minimum: op.precedence + 1)
            case .function(let name, let args, let filter, let over):
                try builder.add(name)
                builder.add("(")
                try builder.add(args)
                builder.add(")")
                try builder.add(filter)
                try builder.add(over)
            case .expressionList(let list):
                try builder.add(group: list)
            case .cast(let val, as: let type):
                builder.add("CAST", "(")
                try builder.add(val)
                try builder.addAlias(type)
                builder.add(")")
            case .collate(let expr, let name):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.collate)
                builder.add("COLLATE")
                try builder.add(name);
            case .like(let expr, negated: let negated, like: let like, escape: let escape):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("LIKE")
                try builder.addOperand(like, minimum: ExpressionPrecedence.equality + 1)
                if let escape {
                    builder.add("ESCAPE")
                    try builder.addOperand(escape, minimum: ExpressionPrecedence.escape)
                }
            case .glob(let expr, negated: let negated, glob: let glob):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("GLOB")
                try builder.addOperand(glob, minimum: ExpressionPrecedence.equality + 1)
            case .regexp(let expr, negated: let negated, regexp: let regexp):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("REGEXP")
                try builder.addOperand(regexp, minimum: ExpressionPrecedence.equality + 1)
            case .match(let expr, negated: let negated, match: let match):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("MATCH")
                try builder.addOperand(match, minimum: ExpressionPrecedence.equality + 1)
            case .isNull(let expr):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                builder.add("ISNULL")
            case .notNull(let expr):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                builder.add("NOT", "NULL")
            case .equals(let expr, negated: let negated,distinct: let distinct, from: let from):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                builder.add("IS")
                if negated { builder.add("NOT") }
                if distinct { builder.add("DISTINCT", "FROM") }
                try builder.addOperand(from, minimum: ExpressionPrecedence.equality + 1)
            case .between(let expr, negated: let negated, lower: let lower, upper: let upper):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("BETWEEN")
                // The lower bound must not contain a bare AND; the upper bound binds tighter than BETWEEN.
                try builder.addOperand(lower, minimum: ExpressionPrecedence.equality)
                builder.add("AND")
                try builder.addOperand(upper, minimum: ExpressionPrecedence.equality + 1)
            case .inStatement(let expr, negated: let negated, let select):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("IN")
                builder.add("(")
                try builder.add(select)
                builder.add(")")
            case .inExpression(let expr, negated: let negated, let list):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("IN")
                try builder.add(group: list)
            case .inTable(let expr, negated: let negated, let schema, let table):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("IN")
                try builder.add(name: schema, table)
            case .inTableFunction(let expr, negated: let negated, let schema, let function, let args):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("IN")
                try builder.add(name: schema, function)
                builder.add("(")
                try builder.addList(args, delimiter: ",")
                builder.add(")")
            case .select(let select):
                try builder.add(group: select)
            case .exists(negated: let negated, let select):
                if negated { builder.add("NOT") }
                builder.add("EXISTS")
                try builder.add(group: select)
            case .when(let expr, let whenThens, else: let `else`):
                builder.add("CASE")
                try builder.add(expr)
                for (when, then) in whenThens {
                    builder.add("WHEN")
                    try builder.add(when)
                    builder.add("THEN")
                    try builder.add(then)
                }
                if let `else` {
                    builder.add("ELSE")
                    try builder.add(`else`)
                }
                builder.add("END")
            case .raise(let r):
                try builder.add(r)
        }
    }
}

/// Binding strengths from SQLite's parse.y (`%left OR.` … `%right BITNOT.`), weakest first.
/// Used to add parentheses only where an operand would otherwise bind differently.
enum ExpressionPrecedence {
    static let or = 1
    static let and = 2
    static let not = 3
    /// IS, IN, LIKE/GLOB/REGEXP/MATCH, BETWEEN, ISNULL/NOTNULL, =, ==, !=, <>
    static let equality = 4
    static let comparison = 5        // < <= > >=
    static let escape = 6
    static let bitwise = 7           // & | << >>
    static let additive = 8          // + -
    static let multiplicative = 9    // * / %
    static let concatenation = 10    // || -> ->>
    static let collate = 11
    static let unary = 12            // ~ and unary + -
    /// Literals, names, function calls, parenthesized and bracketed forms: never need parentheses.
    static let atom = 13
}

extension Expression {
    /// How tightly this expression binds when used as an operand.
    var precedence: Int {
        switch self {
            case .binaryOperator(_, let op, _): return op.precedence
            case .unaryOperator(let op, _): return op.precedence
            case .collate: return ExpressionPrecedence.collate
            case .like, .glob, .regexp, .match, .isNull, .notNull, .equals, .between,
                 .inStatement, .inExpression, .inTable, .inTableFunction:
                return ExpressionPrecedence.equality
            case .exists(negated: true, _): return ExpressionPrecedence.not
            default: return ExpressionPrecedence.atom
        }
    }
}

extension BinaryOperator {
    var precedence: Int {
        switch self {
            case .or: return ExpressionPrecedence.or
            case .and: return ExpressionPrecedence.and
            case .equals, .notEquals, .is, .isNot, .isDistinctFrom, .isNotDistinctFrom, .in, .notIn,
                 .match, .notMatch, .like, .notLike, .regexp, .notRegexp, .glob, .notGlob:
                return ExpressionPrecedence.equality
            case .lessThan, .greaterThan, .lessThanOrEqual, .greaterThanOrEqual: return ExpressionPrecedence.comparison
            case .bitwiseAnd, .bitwiseOr, .leftShift, .rightShift: return ExpressionPrecedence.bitwise
            case .add, .subtract: return ExpressionPrecedence.additive
            case .multiply, .divide, .modulo: return ExpressionPrecedence.multiplicative
            case .concat, .extractJSON, .extractValue: return ExpressionPrecedence.concatenation
        }
    }
}

extension UnaryOperator {
    var precedence: Int {
        switch self {
            case .bitwiseNot, .plus, .negate: return ExpressionPrecedence.unary
            case .collate: return ExpressionPrecedence.collate
            case .escape: return ExpressionPrecedence.escape
            case .isNull, .notNull: return ExpressionPrecedence.equality
            case .not: return ExpressionPrecedence.not
        }
    }
}

extension SyntaxBuilder {
    /// Adds an operand, parenthesized if it binds more loosely than `minimum`.
    mutating func addOperand(_ operand: Expression, minimum: Int) throws(SyntaxError) {
        if operand.precedence < minimum {
            try add(group: operand)
        } else {
            try add(operand)
        }
    }
}
