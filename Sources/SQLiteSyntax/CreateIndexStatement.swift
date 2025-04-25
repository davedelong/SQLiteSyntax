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
    
    public var schemaName: SchemaName?
    public var indexName: IndexName
    public var on: TableName
    
    public var indexedColumns: Array<IndexedColumn>
    
    public var `where`: Expression?
    
    public init(unique: Bool, ifNotExists: Bool, schemaName: SchemaName? = nil, indexName: IndexName, on: TableName, indexedColumns: Array<IndexedColumn>) {
        self.unique = unique
        self.ifNotExists = ifNotExists
        self.schemaName = schemaName
        self.indexName = indexName
        self.on = on
        self.indexedColumns = indexedColumns
    }
    
    public func validate() throws(SyntaxError) {
        try require(indexedColumns.count > 0, reason: "\(Self.self) must have at least one indexed column")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("CREATE")
        if unique { builder.add("UNIQUE") }
        builder.add("INDEX")
        if ifNotExists { builder.add("IF", "NOT", "EXISTS") }
        try builder.add(name: schemaName, indexName)
        builder.add("ON")
        try builder.add(on)
        builder.add("(")
        try builder.addList(indexedColumns, delimiter: ",")
        builder.add(")")
        if let `where` {
            builder.add("WHERE")
            try builder.add(`where`)
        }
    }
    
}
