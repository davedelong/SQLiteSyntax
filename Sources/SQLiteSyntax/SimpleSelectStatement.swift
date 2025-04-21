//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct SimpleSelectStatement: Syntax {
    
    public var with: With?
    public var select: SelectCore?
    public var orderBy: OrderBy?
    public var limit: Limit?
    
    public init(with: With? = nil, select: SelectCore? = nil, orderBy: OrderBy? = nil, limit: Limit? = nil) {
        self.with = with
        self.select = select
        self.orderBy = orderBy
        self.limit = limit
    }
    
}
