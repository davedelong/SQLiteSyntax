//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct FilterClause: Syntax {
    
    public var `where`: Expression
    
    public init(where: Expression) {
        self.where = `where`
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("FILTER", "(")
        try builder.add(`where`)
        builder.add(")")
    }
    
}
