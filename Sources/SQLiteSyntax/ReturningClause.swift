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
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .wildcard:
                    try builder.add(Wildcard())
                case .expression(let e, alias: let alias):
                    try builder.add(e)
                    try builder.addAlias(alias)
            }
        }
    }
    
    public var values: Array<Value>
    
    public init(values: Array<Value>) {
        self.values = values
    }
    
    public func validate() throws(SyntaxError) {
        try require(values.count > 0, reason: "Returning clauses must have at least one value")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("RETURNING")
        try builder.addList(values, delimiter: ",")
    }
    
}
