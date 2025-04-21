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
    
}
