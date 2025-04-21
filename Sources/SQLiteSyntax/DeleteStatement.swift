//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct DeleteStatement: Syntax {
    
    public var with: With?
    
    public var qualifiedTableName: QualifiedTableName
    
    public var `where`: Expression?
    
    public var returning: ReturningClause?
    
    public var orderBy: OrderBy?
    
    public var limit: Limit?
    
    public init(with: With? = nil, qualifiedTableName: QualifiedTableName, returning: ReturningClause? = nil, orderBy: OrderBy? = nil, limit: Limit? = nil) {
        self.with = with
        self.qualifiedTableName = qualifiedTableName
        self.returning = returning
        self.orderBy = orderBy
        self.limit = limit
    }
    
}
