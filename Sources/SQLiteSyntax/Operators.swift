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
    case escape
    case isNull
    case notNull
    case not
}

public enum BinaryOperator: Syntax {
    case or
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
}
