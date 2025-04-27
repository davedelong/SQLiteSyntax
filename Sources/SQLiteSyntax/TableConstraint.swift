//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct TableConstraint: Syntax {
    
    public enum Constraint: Syntax {
        case primaryKey(List<IndexedColumn>, ConflictClause)
        case unique(List<IndexedColumn>, ConflictClause)
        case check(Expression)
        case foreignKey(List<Name<Column>>, ForeignKeyClause)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .primaryKey(let columns, let conflict):
                    builder.add("PRIMARY", "KEY", "(")
                    try builder.add(columns)
                    builder.add(")")
                    try builder.add(conflict)
                case .unique(let columns, let conflict):
                    builder.add("UNIQUE", "(")
                    try builder.add(columns)
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
    
    public var name: Name<Any>?
    
    public var constraint: Constraint
    
    public init(name: Name<Any>? = nil, constraint: Constraint) {
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
