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
    case function(Name<Function>, List<FunctionArgument>, FilterClause?, OverClause?)
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
    case inTableFunction(Expression, negated: Bool, Name<Schema>?, Name<Function>, List<FunctionArgument>)
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
                try builder.add(name: s, t)
                try builder.add(c)
            case .unaryOperator(let o, let e):
                try o.build(using: &builder, argument: e)
            case .binaryOperator(let left, let op, let right):
                try builder.add(left)
                try builder.add(op)
                try builder.add(right)
            case .function(let name, let args, let filter, let over):
                try builder.add(name)
                try builder.add(group: args)
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
                try builder.add(expr)
                builder.add("COLLATE")
                try builder.add(name);
            case .like(let expr, negated: let negated, like: let like, escape: let escape):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("LIKE")
                try builder.add(like)
                if let escape {
                    builder.add("ESCAPE")
                    try builder.add(escape)
                }
            case .glob(let expr, negated: let negated, glob: let glob):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("GLOB")
                try builder.add(glob)
            case .regexp(let expr, negated: let negated, regexp: let regexp):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("REGEXP")
                try builder.add(regexp)
            case .match(let expr, negated: let negated, match: let match):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("MATCH")
                try builder.add(match)
            case .isNull(let expr):
                try builder.add(expr)
                builder.add("ISNULL")
            case .notNull(let expr):
                try builder.add(expr)
                builder.add("NOT", "NULL")
            case .equals(let expr, negated: let negated,distinct: let distinct, from: let from):
                try builder.add(expr)
                builder.add("IS")
                if negated { builder.add("NOT") }
                if distinct { builder.add("DISTINCT", "FROM") }
                try builder.add(from)
            case .between(let expr, negated: let negated, lower: let lower, upper: let upper):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("BETWEEN")
                try builder.add(lower)
                builder.add("AND")
                try builder.add(upper)
            case .inStatement(let expr, negated: let negated, let select):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("IN")
                builder.add("(")
                try builder.add(select)
                builder.add(")")
            case .inExpression(let expr, negated: let negated, let list):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("IN")
                try builder.add(group: list)
            case .inTable(let expr, negated: let negated, let schema, let table):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("IN")
                try builder.add(name: schema, table)
            case .inTableFunction(let expr, negated: let negated, let schema, let function, let args):
                try builder.add(expr)
                if negated { builder.add("NOT") }
                builder.add("IN")
                try builder.add(name: schema, function)
                try builder.add(group: args)
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
