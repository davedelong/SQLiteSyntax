//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CreateVirtualTableStatement: Syntax {
    
    public var ifNotExists: Bool
    public var schemaName: SchemaName?
    public var tableName: TableName
    
    public var moduleName: ModuleName
    public var moduleArguments: Array<String>
    
    public init(ifNotExists: Bool, schemaName: SchemaName? = nil, tableName: TableName, moduleName: ModuleName, moduleArguments: Array<String>) {
        self.ifNotExists = ifNotExists
        self.schemaName = schemaName
        self.tableName = tableName
        self.moduleName = moduleName
        self.moduleArguments = moduleArguments
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("CREATE", "VIRTUAL", "TABLE")
        if ifNotExists { builder.add("IF", "NOT", "EXISTS") }
        try builder.add(name: schemaName, tableName)
        builder.add("USING")
        try builder.add(moduleName)
        
        if moduleArguments.count > 0 {
            builder.add("(")
            try builder.addList(moduleArguments, delimiter: ",")
            builder.add(")")
        }
    }
    
}
