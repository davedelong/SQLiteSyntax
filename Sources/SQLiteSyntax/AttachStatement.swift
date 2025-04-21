//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct AttachStatement: Syntax {
    
    public var expression: Expression
    public var asSchemaName: SchemaName
    
    public init(expression: Expression, asSchemaName: SchemaName) {
        self.expression = expression
        self.asSchemaName = asSchemaName
    }
    
}
