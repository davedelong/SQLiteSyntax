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
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            builder.add("OR")
            switch self {
                case .abort: builder.add("ABORT")
                case .fail: builder.add("FAIL")
                case .ignore: builder.add("IGNORE")
                case .replace: builder.add("REPLACE")
                case .rollback: builder.add("ROLLBACK")
            }
        }
    }
    
    public struct Values: Syntax {
        
        public var values: Array<(List<Name<Column>>, Expression)>
        
        public init(values: Array<(List<Name<Column>>, Expression)>) {
            self.values = values
        }
        
        public func validate() throws(SyntaxError) {
            try require(values.count > 0, reason: "Updating values requires at least one value to set")
        }
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            var needsComma = false
            for (name, expr) in values {
                if needsComma { builder.add(",") }
                try builder.add(name)
                builder.add("=")
                try builder.add(expr)
                needsComma = true
            }
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
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            builder.add("FROM")
            switch self {
                case .tableOrSubquery(let list):
                    try builder.addList(list, delimiter: ",")
                case .join(let join):
                    try builder.add(join)
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
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(with)
        builder.add("UPDATE")
        try builder.add(or)
        try builder.add(tableName)
        builder.add("SET")
        try builder.add(`set`)
        try builder.add(from)
        if let `where` {
            builder.add("WHERE")
            try builder.add(`where`)
        }
        try builder.add(returning)
        try builder.add(orderBy)
        try builder.add(limit)
    }
}
