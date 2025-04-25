//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DropTableStatement: Syntax {
    
    public var ifExists: Bool
    public var schemaName: SchemaName?
    public var tableName: TableName
    
    public init(ifExists: Bool, schemaName: SchemaName? = nil, tableName: TableName) {
        self.ifExists = ifExists
        self.schemaName = schemaName
        self.tableName = tableName
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("DROP", "TABLE")
        if ifExists { builder.add("IF", "EXISTS") }
        try builder.add(name: schemaName, tableName)
    }
    
}
