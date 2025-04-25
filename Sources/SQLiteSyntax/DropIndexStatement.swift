//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DropIndexStatement: Syntax {
    
    public var ifExists: Bool
    
    public var schemaName: SchemaName?
    
    public var indexName: IndexName
    
    public init(ifExists: Bool, schemaName: SchemaName? = nil, indexName: IndexName) {
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
