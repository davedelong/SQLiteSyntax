//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CreateVirtualTableStatement: Syntax {
    
    public var ifNotExists: Bool
    public var schemaName: Name<Schema>?
    public var tableName: Name<Table>
    
    public var moduleName: Name<Module>
    public var moduleArguments: List<Name<Any>>?
    
    public init(ifNotExists: Bool, schemaName: Name<Schema>? = nil, tableName: Name<Table>, moduleName: Name<Module>, moduleArguments: List<Name<Any>>? = nil) {
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
        try builder.add(group: moduleArguments)
    }
    
}
