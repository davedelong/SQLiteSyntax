//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct AttachStatement: Syntax {
    
    public var expression: Expression
    public var `as`: Name<Schema>
    
    public init(expression: Expression, `as`: Name<Schema>) {
        self.expression = expression
        self.as = `as`
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("ATTACH", "DATABASE")
        try builder.add(expression)
        try builder.addAlias(`as`)
    }
}
