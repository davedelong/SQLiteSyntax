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
        case expression(Expression, alias: Name<Column>?)
        
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
    
    public var values: List<Value>
    
    public init(values: List<Value>) {
        self.values = values
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("RETURNING")
        try builder.add(values)
    }
    
}
