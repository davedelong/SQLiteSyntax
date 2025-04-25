//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct ColumnConstraint: Syntax {
    
    public enum Constraint: Syntax {
        
        case primaryKey(SortDirection?, ConflictClause, autoincrement: Bool)
        case notNull(ConflictClause)
        case unique(ConflictClause)
        case check(Expression)
        case `default`(DefaultValue)
        case collate(CollationName)
        case foreignKey(ForeignKeyClause)
        case generated(always: Bool, as: Expression, storage: GeneratedStorage?)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .primaryKey(let dir, let conflict, autoincrement: let auto):
                    builder.add("PRIMARY", "KEY")
                    try builder.add(dir)
                    try builder.add(conflict)
                    if auto { builder.add("AUTOINCREMENT") }
                case .notNull(let c):
                    builder.add("NOT", "NULL")
                    try builder.add(c)
                case .unique(let c):
                    builder.add("UNIQUE")
                    try builder.add(c)
                case .check(let e):
                    builder.add("CHECK", "(")
                    try builder.add(e)
                    builder.add(")")
                case .default(let val):
                    builder.add("DEFAULT")
                    try builder.add(val)
                case .collate(let n):
                    builder.add("COLLATE")
                    try builder.add(n)
                case .foreignKey(let c):
                    try builder.add(c)
                case .generated(always: let always, as: let e, storage: let s):
                    if always { builder.add("GENERATED", "ALWAYS") }
                    builder.add("AS", "(")
                    try builder.add(e)
                    builder.add(")")
                    try builder.add(s)
                    
            }
        }
        
    }
    
    public enum DefaultValue: Syntax {
        case expression(Expression)
        case literalValue(String)
        case signedNumber(Decimal)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .expression(let e):
                    builder.add("(")
                    try builder.add(e)
                    builder.add(")")
                case .literalValue(let s):
                    builder.add(s)
                case .signedNumber(let n):
                    builder.add(n.description)
            }
        }
    }
    
    public enum GeneratedStorage: Syntax {
        case stored
        case virtual
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .stored: builder.add("STORED")
                case .virtual: builder.add("VIRTUAL")
            }
        }
    }
    
    public var name: Name?
    public var constraint: Constraint
    
    public init(name: Name?, constraint: Constraint) {
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
