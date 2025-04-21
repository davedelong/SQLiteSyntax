//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CreateTableStatement: Syntax {
    
    public enum Contents: Syntax {
        case select(SelectStatement)
        case columns(Array<ColumnDefinition>, Array<TableConstraint>, TableOptions?)
    }
    
    public var temporary: Bool
    public var ifNotExists: Bool
    
    public var schemaName: SchemaName?
    public var tableName: TableName
    
    public var contents: Contents
    
    public init(temporary: Bool, ifNotExists: Bool, schemaName: SchemaName? = nil, tableName: TableName, contents: Contents) {
        self.temporary = temporary
        self.ifNotExists = ifNotExists
        self.schemaName = schemaName
        self.tableName = tableName
        self.contents = contents
    }
    
}
