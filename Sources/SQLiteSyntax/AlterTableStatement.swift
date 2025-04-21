//
//  AlterTableStatement.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

public struct AlterTableStatement: Syntax {
    
    public var schemaName: SchemaName?
    public var tableName: TableName
    
    public var action: Action
    
    public enum Action: Syntax {
        case rename(TableName)
        case renameColumn(from: ColumnName, to: ColumnName)
        case addColumn(ColumnDefinition)
        case dropColumn(ColumnName)
    }
    
    public init(schemaName: SchemaName? = nil, tableName: TableName, action: Action) {
        self.schemaName = schemaName
        self.tableName = tableName
        self.action = action
    }
    
}
