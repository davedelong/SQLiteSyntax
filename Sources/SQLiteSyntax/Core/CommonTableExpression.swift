//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CommonTableExpression: Syntax {
    
    public struct Name<Table>: Syntax {
        public var tableName: SQLiteSyntax.Name<Table>
        public var columnNames: List<Name<Column>>?
        
        public init(tableName: SQLiteSyntax.Name<Table>, columnNames: List<Name<Column>>?) {
            self.tableName = tableName
            self.columnNames = columnNames
        }
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            try builder.add(tableName)
            try builder.add(group: columnNames)
        }
    }
    
    public var tableName: Name<Table>
    
    public var not: Bool
    public var materialized: Bool
    public var selectStatement: SelectStatement
    
    public init(tableName: Name<Table>, not: Bool, materialized: Bool, selectStatement: SelectStatement) {
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
        try builder.add(group: selectStatement)
    }
}
