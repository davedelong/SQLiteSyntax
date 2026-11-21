//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

/// A prefix operator. Not `Syntax` by itself: it's printed together with its operand, as part of
/// `Expression.unaryOperator`. (`COLLATE`, `ISNULL` and `NOTNULL` have their own `Expression` cases.)
public enum UnaryOperator: Sendable {
    case bitwiseNot
    case plus
    case negate
    case not
    
    /// Prints the operator with its operand, parenthesized if it binds less tightly than the operator.
    internal func build(using builder: inout SyntaxBuilder, operand: Expression) throws(SyntaxError) {
        switch self {
            case .bitwiseNot:
                builder.add("~")
                try builder.addOperand(operand, minimum: precedence)
            case .plus:
                builder.add("+")
                try builder.addOperand(operand, minimum: precedence)
            case .negate:
                builder.add("-")
                try builder.addOperand(operand, minimum: precedence)
            case .not:
                builder.add("NOT")
                try builder.addOperand(operand, minimum: precedence)
        }
    }
}

/// An operator between two operands, printed between them. Operators with their own form in `Expression`
/// aren't here: `IS [NOT] [DISTINCT FROM]` is `.equals`, `[NOT] IN` is `.inExpression`, `.inStatement`,
/// `.inTable` or `.inTableFunction`, and `[NOT] LIKE`, `GLOB`, `REGEXP` and `MATCH` have a case each.
public enum BinaryOperator: Syntax {
    case concat
    case extractJSON
    case extractValue
    case multiply
    case divide
    case modulo
    case add
    case subtract
    case bitwiseAnd
    case bitwiseOr
    case leftShift
    case rightShift
    case lessThan
    case greaterThan
    case lessThanOrEqual
    case greaterThanOrEqual
    case equals
    case notEquals
    case and
    case or
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .extractJSON, .extractValue: try builder.require(SQLiteVersion(3, 38, 0), for: self)
            default: break
        }
        switch self {
            case .concat: builder.add("||")
            case .extractJSON: builder.add("->")
            case .extractValue: builder.add("->>")
            case .multiply: builder.add("*")
            case .divide: builder.add("/")
            case .modulo: builder.add("%")
            case .add: builder.add("+")
            case .subtract: builder.add("-")
            case .bitwiseAnd: builder.add("&")
            case .bitwiseOr: builder.add("|")
            case .leftShift: builder.add("<<")
            case .rightShift: builder.add(">>")
            case .lessThan: builder.add("<")
            case .greaterThan: builder.add(">")
            case .lessThanOrEqual: builder.add("<=")
            case .greaterThanOrEqual: builder.add(">=")
            case .equals: builder.add("==")
            case .notEquals: builder.add("!=")
            case .and: builder.add("AND")
            case .or: builder.add("OR")
        }
    }

    /// The operator as `build(using:)` prints it, e.g. `||`, `->>`, `AND`.
    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        if let (_, op) = p.binaryOperator(p.current) {
            _ = p.advance()
            return op
        }
        if p.accept(keyword: "AND") { return .and }
        if p.accept(keyword: "OR") { return .or }
        let e = p.unexpected(expected: "a binary operator")
        p.state.record(e)
        throw e
    }
}
