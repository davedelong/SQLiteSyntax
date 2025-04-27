//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CreateIndexStatement: Syntax {
    
    public var unique: Bool
    public var ifNotExists: Bool
    
    public var schemaName: Name<Schema>?
    public var indexName: Name<Index>
    public var on: Name<Table>
    
    public var indexedColumns: List<IndexedColumn>
    
    public var `where`: Expression?
    
    public init(unique: Bool, ifNotExists: Bool, schemaName: Name<Schema>? = nil, indexName: Name<Index>, on: Name<Table>, indexedColumns: List<IndexedColumn>) {
        self.unique = unique
        self.ifNotExists = ifNotExists
        self.schemaName = schemaName
        self.indexName = indexName
        self.on = on
        self.indexedColumns = indexedColumns
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("CREATE")
        if unique { builder.add("UNIQUE") }
        builder.add("INDEX")
        if ifNotExists { builder.add("IF", "NOT", "EXISTS") }
        try builder.add(name: schemaName, indexName)
        builder.add("ON")
        try builder.add(on)
        try builder.add(group: indexedColumns)
        if let `where` {
            builder.add("WHERE")
            try builder.add(`where`)
        }
    }
    
}
