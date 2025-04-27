//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct QualifiedTableName: Syntax {
    
    public enum Index: Syntax {
        case notIndexed
        case indexed(by: Name<Index>)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .notIndexed:
                    builder.add("NOT", "INDEXED")
                case .indexed(by: let i):
                    builder.add("INDEXED", "BY")
                    try builder.add(i)
            }
        }
    }
    
    public var schemaName: Name<Schema>?
    public var tableName: Name<Table>
    public var `as`: Name<Table>?
    public var index: Index?
    
    public init(schemaName: Name<Schema>? = nil, tableName: Name<Table>, index: Index? = nil) {
        self.schemaName = schemaName
        self.tableName = tableName
        self.index = index
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(name: schemaName, tableName)
        try builder.addAlias(`as`)
        try builder.add(index)
    }
    
}
