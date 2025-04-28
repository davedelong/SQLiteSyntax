//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct SelectStatement: Syntax {
    
    public var with: With?
    public var select: SelectCore
    public var additionalSelects: Array<(CompoundOperator, SelectCore)>
    public var orderBy: OrderBy?
    public var limit: Limit?
    
    public init(with: With? = nil, select: SelectCore, additionalSelects: Array<(CompoundOperator, SelectCore)> = [], orderBy: OrderBy? = nil, limit: Limit? = nil) {
        self.with = with
        self.select = select
        self.additionalSelects = additionalSelects
        self.orderBy = orderBy
        self.limit = limit
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(with)
        try builder.add(select)
        for (op, core) in additionalSelects {
            try builder.add(op)
            try builder.add(core)
        }
        try builder.add(orderBy)
        try builder.add(limit)
    }
    
}
