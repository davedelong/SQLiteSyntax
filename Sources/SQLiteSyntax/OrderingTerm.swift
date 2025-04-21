//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct OrderingTerm: Syntax {
    
    public enum Nulls: Syntax {
        case first
        case last
    }
    
    public var expression: Expression
    public var collationName: CollationName?
    public var sortDirection: SortDirection?
    public var nulls: Nulls?
    
    public init(expression: Expression, collationName: CollationName? = nil, sortDirection: SortDirection? = nil, nulls: Nulls? = nil) {
        self.expression = expression
        self.collationName = collationName
        self.sortDirection = sortDirection
        self.nulls = nulls
    }
}
