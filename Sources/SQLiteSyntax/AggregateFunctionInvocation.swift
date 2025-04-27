//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct AggregateFunctionInvocation: Syntax {
    
    public var functionName: Name<Function>
    public var definition: Definition
    public var filterClause: FilterClause?
    
    public enum Definition: Syntax {
        case expression(Expression)
        case wildcard(Wildcard?)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .expression(let e): try e.build(using: &builder)
                case .wildcard(let w): try w?.build(using: &builder)
            }
        }
    }
    
    public struct Expression: Syntax {
        public var distinct: Bool
        public var expressions: List<Expression>
        public var orderBy: OrderBy?
        
        public init(distinct: Bool, expressions: List<Expression>, orderBy: OrderBy? = nil) {
            self.distinct = distinct
            self.expressions = expressions
            self.orderBy = orderBy
        }
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            if distinct { builder.add("DISTINCT") }
            try builder.add(expressions)
            try builder.add(orderBy)
        }
    }
    
    public init(functionName: Name<Function>, definition: Definition, filterClause: FilterClause?) {
        self.functionName = functionName
        self.definition = definition
        self.filterClause = filterClause
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(functionName)
        try builder.add(group: definition)
        try builder.add(filterClause)
    }
}
