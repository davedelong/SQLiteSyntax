//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct IndexedColumn: Syntax {
    
    public enum Name: Syntax {
        case columnName(ColumnName)
        case expression(Expression)
    }
    
    public var name: Name
    
    public var collationName: CollationName?
    
    public var sortOrder: SortDirection?
    
    public init(name: Name, collationName: CollationName? = nil, sortOrder: SortDirection? = nil) {
        self.name = name
        self.collationName = collationName
        self.sortOrder = sortOrder
    }
    
}
