//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DropIndexStatement: Syntax {
    
    public var ifExists: Bool
    
    public var schemaName: Name<Schema>?
    
    public var indexName: Name<Index>
    
    public init(ifExists: Bool, schemaName: Name<Schema>? = nil, indexName: Name<Index>) {
        self.ifExists = ifExists
        self.schemaName = schemaName
        self.indexName = indexName
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("DROP", "INDEX")
        if ifExists { builder.add("IF", "EXISTS") }
        try builder.add(name: schemaName, indexName)
    }
    
}
