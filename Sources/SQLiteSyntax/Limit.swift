//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct Limit: Syntax {
    
    public enum LimitTerm: Syntax {
        case offset(Expression)
        case additional(Expression)
    }
    
    public var expression: Expression
    
    public var term: LimitTerm?
    
    public init(expression: Expression, term: LimitTerm? = nil) {
        self.expression = expression
        self.term = term
    }
}
