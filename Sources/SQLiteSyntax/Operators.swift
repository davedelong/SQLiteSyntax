//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum UnaryOperator: Syntax {
    case bitwiseNot
    case plus
    case negate
    case collate(CollationName)
    case escape(Name)
    case isNull
    case notNull
    case not
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        fatalError()
    }
    
    internal func build(using builder: inout SyntaxBuilder, argument: any Syntax) throws(SyntaxError) {
        switch self {
            case .bitwiseNot:
                builder.add("~")
                try builder.add(argument)
            case .plus:
                builder.add("+")
                try builder.add(argument)
            case .negate:
                builder.add("-")
                try builder.add(argument)
            case .collate(let name):
                try builder.add(argument)
                builder.add("COLLATE")
                try builder.add(name)
            case .escape(let name):
                try builder.add(argument)
                builder.add("ESCAPE")
                try builder.add(name)
            case .isNull:
                try builder.add(argument)
                builder.add("IS", "NULL")
            case .notNull:
                try builder.add(argument)
                builder.add("NOT", "NULL")
            case .not:
                builder.add("NOT")
                try builder.add(argument)
        }
    }
}

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
    case `is`
    case isNot
    case isDistinctFrom
    case isNotDistinctFrom
    case `in`
    case notIn
    case match
    case notMatch
    case like
    case notLike
    case regexp
    case notRegexp
    case glob
    case notGlob
    case and
    case or
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
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
            case .is: builder.add("IS")
            case .isNot: builder.add("IS", "NOT")
            case .isDistinctFrom: builder.add("IS", "DISTINCT", "FROM")
            case .isNotDistinctFrom: builder.add("IS", "NOT", "DISTINCT", "FROM")
            case .in: builder.add("IN")
            case .notIn: builder.add("NOT", "IN")
            case .match: builder.add("MATCH")
            case .notMatch: builder.add("NOT", "MATCH")
            case .like: builder.add("LIKE")
            case .notLike: builder.add("NOT", "LIKE")
            case .regexp: builder.add("REGEXP")
            case .notRegexp: builder.add("NOT", "REGEXP")
            case .glob: builder.add("GLOB")
            case .notGlob: builder.add("NOT", "GLOB")
            case .and: builder.add("AND")
            case .or: builder.add("OR")
        }
    }
}
