//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum FunctionArgument: Syntax {
    
    case expression(distinct: Bool, List<Expression>, OrderBy?)
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
