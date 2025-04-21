//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CreateViewStatement: Syntax {
    
    public var temporary: Bool
    public var ifNotExists: Bool
    
    public var schemaName: SchemaName?
    public var viewName: ViewName
    
    public var columnNames: Array<ColumnName>
    public var `as`: SelectStatement
    
    public init(temporary: Bool, ifNotExists: Bool, schemaName: SchemaName? = nil, viewName: ViewName, columnNames: Array<ColumnName>, as: SelectStatement) {
        self.temporary = temporary
        self.ifNotExists = ifNotExists
        self.schemaName = schemaName
        self.viewName = viewName
        self.columnNames = columnNames
        self.as = `as`
    }
    
}
