//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct AggregateFunctionInvocation: Syntax {
    
    public var functionName: FunctionName
    public var definition: Definition
    public var filterClause: FilterClause
    
    public enum Definition: Syntax {
        case expression(Expression)
        case wildcard(Wildcard?)
    }
    
    public struct Expression: Syntax {
        public var distinct: Bool
        public var expressions: Array<SQLiteSyntax.Expression>
        public var orderBy: OrderBy?
        
        public init(distinct: Bool, expressions: Array<SQLiteSyntax.Expression>, orderBy: OrderBy? = nil) {
            self.distinct = distinct
            self.expressions = expressions
            self.orderBy = orderBy
        }
    }
    
    public init(functionName: FunctionName, definition: Definition, filterClause: FilterClause) {
        self.functionName = functionName
        self.definition = definition
        self.filterClause = filterClause
    }
}
