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
        case foreignKey(ColumnNameList, ForeignKeyClause)
        
        public func validate() throws(SyntaxError) {
            switch self {
                case .primaryKey(let columns, _):
                    try require(columns.count > 0, reason: "A primary key constraint must specify at least one column")
                case .unique(let columns, _):
                    try require(columns.count > 0, reason: "A unique constraint must specify at least one column")
                default:
                    break
            }
        }
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .primaryKey(let columns, let conflict):
                    builder.add("PRIMARY", "KEY", "(")
                    try builder.addList(columns, delimiter: ",")
                    builder.add(")")
                    try builder.add(conflict)
                case .unique(let columns, let conflict):
                    builder.add("UNIQUE", "(")
                    try builder.addList(columns, delimiter: ",")
                    builder.add(")")
                    try builder.add(conflict)
                case .check(let expr):
                    builder.add("CHECK", "(")
                    try builder.add(expr)
                    builder.add(")")
                case .foreignKey(let columns, let clause):
                    builder.add("FOREIGN", "KEY", "(")
                    try builder.add(columns)
                    builder.add(")")
                    try builder.add(clause)
            }
        }
    }
    
    public var name: Name?
    
    public var constraint: Constraint
    
    public init(name: Name? = nil, constraint: Constraint) {
        self.name = name
        self.constraint = constraint
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        if let name {
            builder.add("CONSTRAINT")
            try builder.add(name)
        }
        try builder.add(constraint)
    }
}
