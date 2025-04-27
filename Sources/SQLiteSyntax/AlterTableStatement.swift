//
//  AlterTableStatement.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

public struct AlterTableStatement: Syntax {
    
    public var schemaName: Name<Schema>?
    public var tableName: Name<Table>
    
    public var action: Action
    
    public enum Action: Syntax {
        case rename(Name<Table>)
        case renameColumn(from: Name<Column>, to: Name<Column>)
        case addColumn(ColumnDefinition)
        case dropColumn(Name<Column>)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .rename(let name):
                    builder.add("RENAME", "TO")
                    try builder.add(name)
                case .renameColumn(from: let old, to: let new):
                    builder.add("RENAME", "COLUMN")
                    try builder.add(old)
                    builder.add("TO")
                    try builder.add(new)
                case .addColumn(let column):
                    builder.add("ADD", "COLUMN")
                    try builder.add(column)
                case .dropColumn(let column):
                    builder.add("DROP", "COLUMN")
                    try builder.add(column)
            }
        }
    }
    
    public init(schemaName: Name<Schema>? = nil, tableName: Name<Table>, action: Action) {
        self.schemaName = schemaName
        self.tableName = tableName
        self.action = action
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("ALTER", "TABLE")
        try builder.add(name: schemaName, tableName)
        try builder.add(action)
    }
    
}
