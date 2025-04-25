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
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .offset(let e):
                    builder.add("OFFSET")
                    try builder.add(e)
                case .additional(let e):
                    builder.add(",")
                    try builder.add(e)
            }
        }
    }
    
    public var expression: Expression
    
    public var term: LimitTerm?
    
    public init(expression: Expression, term: LimitTerm? = nil) {
        self.expression = expression
        self.term = term
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("LIMIT")
        try builder.add(expression)
        try builder.add(term)
    }
}
