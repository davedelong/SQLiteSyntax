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
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .replace: builder.add("REPLACE")
                case .insert(let action):
                    builder.add("INSERT")
                    if let action {
                        builder.add("OR")
                        try builder.add(action)
                    }
            }
        }
    }
    
    public enum InsertAction: Syntax {
        case abort
        case fail
        case ignore
        case replace
        case rollback
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .abort: builder.add("ABORT")
                case .fail: builder.add("FAIL")
                case .ignore: builder.add("IGNORE")
                case .replace: builder.add("REPLACE")
                case .rollback: builder.add("ROLLBACK")
            }
        }
    }
    
    public enum Values: Syntax {
        case values(ExpressionList, UpsertClause?)
        case select(SelectStatement, UpsertClause?)
        case defaultValues
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .values(let list, let upsert):
                    builder.add("(")
                    try builder.add(list)
                    builder.add(")")
                    try builder.add(upsert)
                case .select(let select, let upsert):
                    try builder.add(select)
                    try builder.add(upsert)
                case .defaultValues:
                    builder.add("DEFAULT", "VALUES")
            }
        }
    }
    
    public var with: With?
    
    public var action: Action
    
    public var schemaName: SchemaName?
    
    public var tableName: TableName
    
    public var `as`: TableName?
    
    public var columns: ColumnNameList?
    
    public var values: Values
    
    public var returning: ReturningClause?
    
    public init(with: With? = nil, action: Action, schemaName: SchemaName? = nil, tableName: TableName, columns: ColumnNameList? = nil, values: Values, returning: ReturningClause? = nil) {
        self.with = with
        self.action = action
        self.schemaName = schemaName
        self.tableName = tableName
        self.columns = columns
        self.values = values
        self.returning = returning
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(with)
        try builder.add(action)
        builder.add("INTO")
        try builder.add(name: schemaName, tableName)
        try builder.addAlias(`as`)
        if let columns {
            builder.add("(")
            try builder.add(columns)
            builder.add(")")
        }
        try builder.add(values)
        try builder.add(returning)
    }
}
