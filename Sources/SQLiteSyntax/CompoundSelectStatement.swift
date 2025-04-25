//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CompoundSelectStatement: Syntax {
    
    public var with: With?
    
    public var selectCore: SelectCore
    
    public var additionalSelects: Array<(CompoundOperator, SelectCore)>
    
    public var orderBy: OrderBy?
    
    public var limit: Limit?
    
    public init(with: With? = nil, selectCore: SelectCore, additionalSelects: Array<(CompoundOperator, SelectCore)>, orderBy: OrderBy? = nil, limit: Limit? = nil) {
        self.with = with
        self.selectCore = selectCore
        self.additionalSelects = additionalSelects
        self.orderBy = orderBy
        self.limit = limit
    }
    
    public func validate() throws(SyntaxError) {
        try require(additionalSelects.count > 0, reason: "CompoundSelectStatements must have at least one additional select core statement")
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(with)
        try builder.add(selectCore)
        for (op, select) in additionalSelects {
            try builder.add(op)
            try builder.add(select)
        }
        try builder.add(orderBy)
        try builder.add(limit)
    }
    
}
