//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct InsertStatement: Syntax {
    
    public enum Action: Syntax {
        case replace
        case insert(InsertAction?)
    }
    
    public enum InsertAction: Syntax {
        case abort
        case fail
        case ignore
        case replace
        case rollback
    }
    
    public enum Values: Syntax {
        case values(Array<Expression>, UpsertClause?)
        case select(SelectStatement, UpsertClause?)
        case defaultValues
    }
    
    public var with: With?
    
    public var action: Action
    
    public var schemaName: SchemaName?
    
    public var tableName: TableName
    
    public var `as`: TableName?
    
    public var columns: Array<ColumnName>
    
    public var values: Values
    
    public var returning: ReturningClause?
    
    public init(with: With? = nil, action: Action, schemaName: SchemaName? = nil, tableName: TableName, columns: Array<ColumnName>, values: Values, returning: ReturningClause? = nil) {
        self.with = with
        self.action = action
        self.schemaName = schemaName
        self.tableName = tableName
        self.columns = columns
        self.values = values
        self.returning = returning
    }
}
