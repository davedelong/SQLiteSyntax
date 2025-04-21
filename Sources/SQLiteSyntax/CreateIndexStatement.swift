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
    
}
