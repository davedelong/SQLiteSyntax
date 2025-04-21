//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct UpdateStatement: Syntax {
    
    public enum Action: Syntax {
        case abort
        case fail
        case ignore
        case replace
        case rollback
    }
    
    public struct Values: Syntax {
        
        public enum Set: Syntax {
            case columnName(ColumnName)
            case columnNameList(ColumnNameList)
        }
        
        public var values: Array<(Set, Expression)>
        
        public init(values: Array<(Set, Expression)>) {
            self.values = values
        }
        
        public func validate() throws(SyntaxError) {
            try require(values.count > 0, reason: "Updating values requires at least one value to set")
        }
        
    }
    
    public enum From: Syntax {
        case tableOrSubquery(Array<TableOrSubquery>)
        case join(JoinClause)
        
        public func validate() throws(SyntaxError) {
            switch self {
                case .tableOrSubquery(let values):
                    try require(values.count > 0, reason: "Updating a table or subquery requires at least one of them")
                default:
                    break
            }
        }
    }
    
    public var with: With?
    
    public var or: Action?
    
    public var tableName: QualifiedTableName
    
    public var `set`: Values
    
    public var from: From?
    public var `where`: Expression?
    public var returning: ReturningClause?
    public var orderBy: OrderBy?
    public var limit: Limit?
    
    public init(with: With? = nil, or: Action? = nil, tableName: QualifiedTableName, set: Values, from: From? = nil, `where`: Expression? = nil, returning: ReturningClause? = nil) {
        self.with = with
        self.or = or
        self.tableName = tableName
        self.set = set
        self.from = from
        self.where = `where`
        self.returning = returning
    }
}
