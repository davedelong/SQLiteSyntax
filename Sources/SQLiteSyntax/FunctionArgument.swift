//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum FunctionArgument: Syntax {
    
    case expression(distinct: Bool, Array<Expression>, OrderBy?)
    case wildcard(Wildcard?)
    
    public func validate() throws(SyntaxError) {
        switch self {
            case .expression(distinct: _, let expressions, _):
                try require(expressions.count > 0, reason: "A function argument must specify at least one expression")
            default:
                break
        }
    }
    
}
