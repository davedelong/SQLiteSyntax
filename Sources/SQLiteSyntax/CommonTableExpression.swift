//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CommonTableExpression: Syntax {
    
    public struct TableName: Syntax {
        public var tableName: SQLiteSyntax.TableName
        public var columnNames: Array<ColumnName>
        
        public init(tableName: SQLiteSyntax.TableName, columnNames: Array<ColumnName>) {
            self.tableName = tableName
            self.columnNames = columnNames
        }
    }
    
    public var tableName: TableName
    public var columnNames: Array<ColumnName>
    
    public var not: Bool
    public var materialized: Bool
    public var selectStatement: SelectStatement
    
    public init(tableName: TableName, columnNames: Array<ColumnName> = [], not: Bool, materialized: Bool, selectStatement: SelectStatement) {
        self.tableName = tableName
        self.columnNames = columnNames
        self.not = not
        self.materialized = materialized
        self.selectStatement = selectStatement
    }
    
}
