//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct TableConstraint: Syntax {
    
    public enum Constraint: Syntax {
        case primaryKey(Array<IndexedColumn>, ConflictClause)
        case unique(Array<IndexedColumn>, ConflictClause)
        case check(Expression)
        case foreignKey(Array<ColumnName>, ForeignKeyClause)
        
        public func validate() throws(SyntaxError) {
            switch self {
                case .primaryKey(let columns, _):
                    try require(columns.count > 0, reason: "A primary key constraint must specify at least one column")
                case .unique(let columns, _):
                    try require(columns.count > 0, reason: "A unique constraint must specify at least one column")
                case .foreignKey(let columns, _):
                    try require(columns.count > 0, reason: "A foreign key constraint must specify at least one column")
                default:
                    break
            }
        }
    }
    
    public var name: Name?
    
    public var constraint: Constraint
    
    public init(name: Name? = nil, constraint: Constraint) {
        self.name = name
        self.constraint = constraint
    }
}
