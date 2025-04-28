//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DetachStatement: Syntax {
    
    public var schemaName: Name<Schema>
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("DETACH", "DATABASE")
        try builder.add(schemaName)
    }
    
}
