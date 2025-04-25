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
    
    public var columnNames: ColumnNameList?
    public var `as`: SelectStatement
    
    public init(temporary: Bool, ifNotExists: Bool, schemaName: SchemaName? = nil, viewName: ViewName, columnNames: ColumnNameList? = nil, as: SelectStatement) {
        self.temporary = temporary
        self.ifNotExists = ifNotExists
        self.schemaName = schemaName
        self.viewName = viewName
        self.columnNames = columnNames
        self.as = `as`
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("CREATE")
        if temporary { builder.add("TEMPORARY") }
        builder.add("VIEW")
        if ifNotExists { builder.add("IF", "NOT", "EXISTS") }
        try builder.add(name: schemaName, viewName)
        if let columnNames {
            builder.add("(")
            try builder.add(columnNames)
            builder.add(")")
        }
        try builder.addAlias(`as`)
    }
    
}
