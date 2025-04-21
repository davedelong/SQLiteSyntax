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
    case columnName(SchemaName?, TableName?, ColumnName)
    case unaryOperator(UnaryOperator, Expression)
    case binaryOperator(Expression, BinaryOperator, Expression)
    case function(FunctionName, Array<FunctionArgument>, FilterClause?, OverClause?)
    case expression(Array<Expression>)
    case cast(Expression, as: TypeName)
    case collate(Expression, CollationName)
    case like(negated: Bool, Expression, escape: Expression?)
    case glob(negated: Bool, Expression)
    case regexp(negated: Bool, Expression)
    case match(negated: Bool, Expression)
    case isNull(Expression)
    case notNull(Expression)
    case equals(negated: Bool, Expression, distinct: Bool, from: Expression)
    case between(negated: Bool, Expression, lower: Expression, upper: Expression)
    case inStatement(negated: Bool, Expression, SelectStatement)
    case inExpression(negated: Bool, Expression, Array<Expression>)
    case inTable(negated: Bool, Expression, SchemaName?, TableName?)
    case inTableFunction(negated: Bool, Expression, SchemaName?, FunctionName, Array<Expression>)
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
}
