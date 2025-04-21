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
        case generated(as: Expression, storage: GeneratedStorage?)
        
    }
    
    public enum DefaultValue: Syntax {
        case expression(Expression)
        case literalValue(String)
        case signedNumber(Decimal)
    }
    
    public enum GeneratedStorage: Syntax {
        case stored
        case virtual
    }
    
    public var name: Name
    public var constraint: Constraint
    
    public init(name: Name, constraint: Constraint) {
        self.name = name
        self.constraint = constraint
    }
}
