//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct SimpleFunctionInvocation: Syntax {
    
    public enum Arguments: Syntax {
        case expressions(List<Expression>)
        case wildcard
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .expressions(let list): try builder.add(list)
                case .wildcard: try builder.add(Wildcard())
            }
        }
    }
    
    public var name: Name<Function>
    
    public var arguments: Arguments
    
    public init(name: Name<Function>, arguments: Arguments) {
        self.name = name
        self.arguments = arguments
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(name)
        try builder.add(group: arguments)
    }
}
