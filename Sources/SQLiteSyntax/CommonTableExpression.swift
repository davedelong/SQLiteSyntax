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
        public var columnNames: ColumnNameList?
        
        public init(tableName: SQLiteSyntax.TableName, columnNames: ColumnNameList?) {
            self.tableName = tableName
            self.columnNames = columnNames
        }
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            try builder.add(tableName)
            if let columnNames {
                builder.add("(")
                try builder.add(columnNames)
                builder.add(")")
            }
        }
    }
    
    public var tableName: TableName
    
    public var not: Bool
    public var materialized: Bool
    public var selectStatement: SelectStatement
    
    public init(tableName: TableName, not: Bool, materialized: Bool, selectStatement: SelectStatement) {
        self.tableName = tableName
        self.not = not
        self.materialized = materialized
        self.selectStatement = selectStatement
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(tableName)
        builder.add("AS")
        if not { builder.add("NOT") }
        if materialized { builder.add("MATERIALIZED") }
        builder.add("(")
        try builder.add(selectStatement)
        builder.add(")")
    }
}
