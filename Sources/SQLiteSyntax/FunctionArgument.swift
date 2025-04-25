//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct FunctionArgumentList: Syntax {
    
    public var arguments: Array<FunctionArgument>
    
    public init(arguments: Array<FunctionArgument>) {
        self.arguments = arguments
    }
    
    public func validate() throws(SyntaxError) {
        try require(arguments.count > 0, reason: "An argument list must specify at least one argument")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.addList(arguments, delimiter: ",")
    }
    
}

public enum FunctionArgument: Syntax {
    
    case expression(distinct: Bool, ExpressionList, OrderBy?)
    case wildcard(Wildcard?)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .expression(distinct: let distinct, let list, let order):
                if distinct { builder.add("DISTINCT") }
                try builder.add(list)
                try builder.add(order)
            case .wildcard(let w):
                try builder.add(w)
        }
    }
}
