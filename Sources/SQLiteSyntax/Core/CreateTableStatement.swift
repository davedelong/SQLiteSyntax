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
        case columns(List<ColumnDefinition>, List<TableConstraint>?, List<TableOption>?)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .select(let s):
                    try builder.addAlias(s)
                case .columns(let list, let con, let opt):
                    builder.add("(")
                    try builder.add(list)
                    
                    // because there's a list of columns before this,
                    // the conditions are preceded by the delimiter
                    var conditions = con
                    conditions?.includeLeadingDelimeter = true
                    try builder.add(conditions)
                    
                    builder.add(")")
                    try builder.add(opt)
            }
        }
    }
    
    public var temporary: Bool
    public var ifNotExists: Bool
    
    public var schemaName: Name<Schema>?
    public var tableName: Name<Table>
    
    public var contents: Contents
    
    public init(temporary: Bool, ifNotExists: Bool, schemaName: Name<Schema>? = nil, tableName: Name<Table>, contents: Contents) {
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
