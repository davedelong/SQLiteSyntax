//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct QualifiedTableName: Syntax {
    
    public enum Index: Syntax {
        case notIndexed
        case indexed(by: IndexName)
    }
    
    public var schemaName: SchemaName?
    public var tableName: TableName
    public var `as`: TableName?
    public var index: Index?
    
    public init(schemaName: SchemaName? = nil, tableName: TableName, index: Index? = nil) {
        self.schemaName = schemaName
        self.tableName = tableName
        self.index = index
    }
    
}
