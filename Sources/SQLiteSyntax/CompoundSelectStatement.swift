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
    
    public var orderTerms: Array<OrderingTerm>
    
    public var limit: Limit?
    
    public init(with: With? = nil, selectCore: SelectCore, additionalSelects: Array<(CompoundOperator, SelectCore)>, orderTerms: Array<OrderingTerm>, limit: Limit? = nil) {
        self.with = with
        self.selectCore = selectCore
        self.additionalSelects = additionalSelects
        self.orderTerms = orderTerms
        self.limit = limit
    }
    
    public func validate() throws(SyntaxError) {
        try require(additionalSelects.count > 0, reason: "CompoundSelectStatements must have at least one additional select core statement")
    }
    
}
