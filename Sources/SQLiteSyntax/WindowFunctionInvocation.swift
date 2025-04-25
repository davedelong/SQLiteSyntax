//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct WindowFunctionInvocation: Syntax {
    
    public enum Arguments: Syntax {
        case expressions(Array<Expression>)
        case wildcard
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .expressions(let exprs):
                    try builder.addList(exprs, delimiter: ",")
                case .wildcard:
                    try builder.add(Wildcard())
            }
        }
    }
    
    public enum Over: Syntax {
        case windowDefinition(WindowDefinition)
        case windowName(WindowName)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            builder.add("OVER")
            switch self {
                case .windowDefinition(let def): try builder.add(def)
                case .windowName(let name): try builder.add(name)
            }
        }
    }
    
    public var name: Name
    
    public var arguments: Arguments
    
    public var filterClause: FilterClause?
    
    public var over: Over
    
    public init(name: Name, arguments: Arguments, filterClause: FilterClause? = nil, over: Over) {
        self.name = name
        self.arguments = arguments
        self.filterClause = filterClause
        self.over = over
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(name)
        builder.add("(")
        try builder.add(arguments)
        try builder.add(filterClause)
        try builder.add(over)
    }
}
