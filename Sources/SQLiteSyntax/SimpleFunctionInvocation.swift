//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct SimpleFunctionInvocation: Syntax {
    
    public enum Arguments: Syntax {
        case expressions(Array<Expression>)
        case wildcard
    }
    
    public var name: Name
    
    public var arguments: Arguments
    
    public init(name: Name, arguments: Arguments) {
        self.name = name
        self.arguments = arguments
    }
}
