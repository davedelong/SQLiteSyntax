//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct OrderBy: Syntax {
    
    public var terms: Array<OrderingTerm>
    
    public init(terms: Array<OrderingTerm>) {
        self.terms = terms
    }
    
    public func validate() throws(SyntaxError) {
        try require(terms.count > 0, reason: "ORDER BY statements must have at least one ordering term")
    }
    
}
