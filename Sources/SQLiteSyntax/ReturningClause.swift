//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct ReturningClause: Syntax {
    
    public enum Value: Syntax {
        case wildcard
        case expression(Expression, alias: ColumnName?)
    }
    
    public var values: Array<Value>
    
    public init(values: Array<Value>) {
        self.values = values
    }
    
    public func validate() throws(SyntaxError) {
        try require(values.count > 0, reason: "Returning clauses must have at least one value")
    }
    
}
