//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct IndexedColumn: Syntax {
    
    public enum Name: Syntax {
        case columnName(SQLiteSyntax.Name<Column>)
        case expression(Expression)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .columnName(let n):
                    try builder.add(n)
                case .expression(let e):
                    try builder.add(e)
            }
        }
    }
    
    public var name: Name
    
    public var collationName: SQLiteSyntax.Name<Collation>?
    
    public var sortOrder: SortDirection?
    
    public init(name: Name, collationName: SQLiteSyntax.Name<Collation>? = nil, sortOrder: SortDirection? = nil) {
        self.name = name
        self.collationName = collationName
        self.sortOrder = sortOrder
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(name)
        if let collationName {
            builder.add("COLLATE")
            try builder.add(collationName)
        }
        try builder.add(sortOrder)
    }
    
}
