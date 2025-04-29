//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/28/25.
//

import Foundation

extension Expression {
    
    public static prefix func ~ (rhs: Self) -> Self {
        return .unaryOperator(.bitwiseNot, rhs)
    }
    
    public static prefix func + (rhs: Self) -> Self {
        return .unaryOperator(.plus, rhs)
    }
    
    public static prefix func - (rhs: Self) -> Self {
        return .unaryOperator(.negate, rhs)
    }
    
    public static prefix func ! (rhs: Self) -> Self {
        return .unaryOperator(.not, rhs)
    }
    
    public static func ~= (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .match, rhs)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .equals, rhs)
    }
    
    public static func != (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .notEquals, rhs)
    }
    
    public static func < (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .lessThan, rhs)
    }
    
    public static func <= (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .lessThanOrEqual, rhs)
    }
    
    public static func > (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .greaterThan, rhs)
    }
    
    public static func >= (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .greaterThanOrEqual, rhs)
    }
    
    public static func || (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .or, rhs)
    }
    
    public static func && (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .and, rhs)
    }
    
    public static func | (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .bitwiseOr, rhs)
    }
    
    public static func & (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .bitwiseAnd, rhs)
    }
    
    public static func << (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .leftShift, rhs)
    }
    
    public static func >> (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .rightShift, rhs)
    }
    
    public static func + (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .add, rhs)
    }
    
    public static func - (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .subtract, rhs)
    }
    
    public static func * (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .multiply, rhs)
    }
    
    public static func / (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .divide, rhs)
    }
    
    public static func % (lhs: Self, rhs: Self) -> Self {
        return .binaryOperator(lhs, .modulo, rhs)
    }
    
    public static var boundValue: Self {
        .bindParameter(.next)
    }
    
    public static func column(_ name: Name<Column>) -> Self {
        .columnName(nil, nil, name)
    }
    
    public static func column(_ table: Name<Table>, _ name: Name<Column>) -> Self {
        .columnName(nil, table, name)
    }
    
}

extension Expression: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByNilLiteral {
    
    
    public init(stringLiteral value: String) {
        self = .literalValue(.string(value))
    }
    
    public init(booleanLiteral value: Bool) {
        self = .literalValue(value ? .true : .false)
    }
    
    public init(integerLiteral value: Int) {
        self = .literalValue(.number(Decimal(value)))
    }
    
    public init(floatLiteral value: Double) {
        self = .literalValue(.number(Decimal(value)))
    }
    
    public init(nilLiteral: ()) {
        self = .literalValue(.null)
    }
    
}
