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
    }
    
    public enum Over: Syntax {
        case windowDefinition(WindowDefinition)
        case windowName(WindowName)
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
}
