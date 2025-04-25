//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CreateTableStatement: Syntax {
    
    public enum Contents: Syntax {
        case select(SelectStatement)
        case columns(Array<ColumnDefinition>, Array<TableConstraint>, TableOptions?)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .select(let s):
                    try builder.addAlias(s)
                case .columns(let def, let con, let opt):
                    builder.add("(")
                    try builder.addList(def, delimiter: ",")
                    
                    for constraint in con {
                        builder.add(",")
                        try builder.add(constraint)
                    }
                    builder.add(")")
                    try builder.add(opt)
            }
        }
    }
    
    public var temporary: Bool
    public var ifNotExists: Bool
    
    public var schemaName: SchemaName?
    public var tableName: TableName
    
    public var contents: Contents
    
    public init(temporary: Bool, ifNotExists: Bool, schemaName: SchemaName? = nil, tableName: TableName, contents: Contents) {
        self.temporary = temporary
        self.ifNotExists = ifNotExists
        self.schemaName = schemaName
        self.tableName = tableName
        self.contents = contents
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("CREATE")
        if temporary { builder.add("TEMPORARY") }
        builder.add("TABLE")
        if ifNotExists { builder.add("IF", "NOT", "EXISTS") }
        try builder.add(name: schemaName, tableName)
        try builder.add(contents)
    }
    
}
