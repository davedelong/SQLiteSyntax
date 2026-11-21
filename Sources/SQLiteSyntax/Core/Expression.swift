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
    case function(Name<Function>, FunctionArguments?, Filter?, Over?)
    /// An ordered-set aggregate, `name ( arguments ) WITHIN GROUP ( ORDER BY withinGroup ) [ filter ] [ over ]`,
    /// e.g. `percentile_cont(0.5) WITHIN GROUP (ORDER BY x)`. The arguments may be empty.
    ///
    /// Since SQLite 3.47.0, and only in builds compiled with `SQLITE_ENABLE_ORDERED_SET_AGGREGATES`.
    case orderedSetAggregate(Name<Function>, arguments: [Expression], withinGroup: Expression, filter: Filter? = nil, over: Over? = nil)
    case expressionList(List<Expression>)
    /// `CAST(x AS type)`; the type may be empty, `CAST(x AS )`, as parse.y allows.
    case cast(Expression, as: TypeName?)
    case collate(Expression, Name<Collation>)
    case like(Expression, negated: Bool, like: Expression, escape: Expression?)
    /// `x [NOT] GLOB pattern [ESCAPE e]`. SQLite passes the escape to the `glob` function as a third
    /// argument, so `ESCAPE` needs an application-defined three-argument `glob`.
    case glob(Expression, negated: Bool, glob: Expression, escape: Expression? = nil)
    /// `x [NOT] REGEXP pattern [ESCAPE e]`; as with GLOB, the escape is a third argument to `regexp`.
    case regexp(Expression, negated: Bool, regexp: Expression, escape: Expression? = nil)
    /// `x [NOT] MATCH pattern [ESCAPE e]`; as with GLOB, the escape is a third argument to `match`.
    case match(Expression, negated: Bool, match: Expression, escape: Expression? = nil)
    case isNull(Expression)
    case notNull(Expression)
    case equals(Expression, negated: Bool, distinct: Bool, from: Expression)
    case between(Expression, negated: Bool,lower: Expression, upper: Expression)
    case inStatement(Expression, negated: Bool, SelectStatement)
    /// `x [NOT] IN ( a , b … )`; the list may be empty (`x IN ()` is false).
    case inExpression(Expression, negated: Bool, [Expression])
    case inTable(Expression, negated: Bool, Name<Schema>?, Name<Table>)
    case inTableFunction(Expression, negated: Bool, Name<Schema>?, Name<Function>, [Expression])
    case select(SelectStatement)
    case exists(negated: Bool, SelectStatement)
    case when(Expression?, Array<(when: Expression, then: Expression)>, else: Expression?)
    case raise(RaiseFunction)
    
    public func validate() throws(SyntaxError) {
        switch self {
            case .when(_, let whens, else: _):
                try require(whens.count > 0, reason: "A CASE WHEN expression must have at least one when-then clause")
            case .columnName(let schema, let table, _):
                // `main.a` would read as table `main`, column `a`.
                try require(schema == nil || table != nil, reason: "A column with a schema name needs a table name")
            default:
                break
        }
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        // parse.y leaves these out with SQLITE_OMIT_SUBQUERY (all forms of IN included) and SQLITE_OMIT_CAST.
        switch self {
            case .select, .exists, .inStatement, .inExpression, .inTable, .inTableFunction:
                try builder.disallow(.omitSubquery, for: self)
            case .cast:
                try builder.disallow(.omitCast, for: self)
            default:
                break
        }
        switch self {
            case .literalValue(let v):
                try builder.add(v)
            case .bindParameter(let p):
                try builder.add(p)
            case .columnName(let s, let t, let c):
                if let s { try builder.add(s); builder.add(".") }
                if let t { try builder.add(t); builder.add(".") }
                try builder.add(c)
            case .unaryOperator(.negate, .literalValue(.integer(let i))) where i >= 0:
                builder.add("-" + LiteralValue.integer(i).text)          // prints as the literal it parses back as
            case .unaryOperator(.negate, .literalValue(.real(let d))) where d.sign == .plus && !d.isNaN:
                builder.add("-" + LiteralValue.real(d).text)
            case .unaryOperator(let o, let e):
                try o.build(using: &builder, operand: e)
            case .binaryOperator(let left, let op, let right):
                // All binary operators are left-associative: an equal-precedence right operand needs parentheses.
                try builder.addOperand(left, minimum: op.precedence)
                try builder.add(op)
                try builder.addOperand(right, minimum: op.precedence + 1)
            case .function(let name, let args, let filter, let over):
                // FILTER came with window functions (3.25.0), and to plain aggregates in 3.30.0.
                if filter != nil { try builder.require(over == nil ? SQLiteVersion(3, 30, 0) : SQLiteVersion(3, 25, 0), for: self) }
                try builder.add(name)
                builder.add("(")
                try builder.add(args)
                builder.add(")")
                try builder.add(filter)
                try builder.add(over)
            case .orderedSetAggregate(let name, let arguments, let orderBy, let filter, let over):
                try builder.require(SQLiteVersion(3, 47, 0), for: self)
                try builder.require(.orderedSetAggregates, for: self)
                try builder.add(name)
                builder.add("(")
                try builder.addList(arguments, delimiter: ",")
                builder.add(")", "WITHIN", "GROUP", "(", "ORDER", "BY")
                try builder.add(orderBy)
                builder.add(")")
                try builder.add(filter)
                try builder.add(over)
            case .expressionList(let list):
                try builder.add(group: list)
            case .cast(let val, as: let type):
                builder.add("CAST", "(")
                try builder.add(val)
                builder.add("AS")
                try builder.add(type)
                builder.add(")")
            case .collate(let expr, let name):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.collate)
                builder.add("COLLATE")
                try builder.add(name);
            case .like(let expr, negated: let negated, like: let pattern, escape: let escape):
                try builder.addPatternMatch("LIKE", expr, negated: negated, pattern: pattern, escape: escape)
            case .glob(let expr, negated: let negated, glob: let pattern, escape: let escape):
                try builder.addPatternMatch("GLOB", expr, negated: negated, pattern: pattern, escape: escape)
            case .regexp(let expr, negated: let negated, regexp: let pattern, escape: let escape):
                try builder.addPatternMatch("REGEXP", expr, negated: negated, pattern: pattern, escape: escape)
            case .match(let expr, negated: let negated, match: let pattern, escape: let escape):
                try builder.addPatternMatch("MATCH", expr, negated: negated, pattern: pattern, escape: escape)
            case .isNull(let expr):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                builder.add("ISNULL")
            case .notNull(let expr):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                builder.add("NOT", "NULL")
            case .equals(let expr, negated: let negated,distinct: let distinct, from: let from):
                if distinct { try builder.require(SQLiteVersion(3, 39, 0), for: self) }
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
                builder.add("IN", "(")
                try builder.addList(list, delimiter: ",")
                builder.add(")")
            case .inTable(let expr, negated: let negated, let schema, let table):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("IN")
                if let schema { try builder.add(schema); builder.add(".") }
                try builder.add(table)
            case .inTableFunction(let expr, negated: let negated, let schema, let function, let args):
                try builder.addOperand(expr, minimum: ExpressionPrecedence.equality)
                if negated { builder.add("NOT") }
                builder.add("IN")
                if let schema { try builder.add(schema); builder.add(".") }
                try builder.add(function)
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

    /// An expression, e.g. `a + 1 BETWEEN 0 AND 10`.
    ///
    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        try p.memoized(Self.self) { (p: inout Parser) throws(ParseError) in try p.parseExpression() }
    }
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
            case .equals, .notEquals: return ExpressionPrecedence.equality
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
            case .not: return ExpressionPrecedence.not
        }
    }
}

extension SyntaxBuilder {
    /// `x [NOT] LIKE|GLOB|REGEXP|MATCH pattern [ESCAPE e]`.
    mutating func addPatternMatch(_ keyword: String, _ expr: Expression, negated: Bool, pattern: Expression, escape: Expression?) throws(SyntaxError) {
        try addOperand(expr, minimum: ExpressionPrecedence.equality)
        if negated { add("NOT") }
        add(keyword)
        try addOperand(pattern, minimum: ExpressionPrecedence.equality + 1)
        if let escape {
            add("ESCAPE")
            try addOperand(escape, minimum: ExpressionPrecedence.escape)
        }
    }

    /// Adds an operand, parenthesized if it binds more loosely than `minimum`.
    mutating func addOperand(_ operand: Expression, minimum: Int) throws(SyntaxError) {
        if operand.precedence < minimum {
            try add(group: operand)
        } else {
            try add(operand)
        }
    }
}

extension SQLiteOption {
    /// `SQLITE_OMIT_SUBQUERY`: no subqueries, `EXISTS` or `IN`.
    static let omitSubquery = SQLiteOption(name: "OMIT_SUBQUERY", value: nil)
    /// `SQLITE_OMIT_CAST`: no `CAST`.
    static let omitCast = SQLiteOption(name: "OMIT_CAST", value: nil)
}
