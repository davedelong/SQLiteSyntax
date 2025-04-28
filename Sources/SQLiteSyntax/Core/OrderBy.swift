//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct OrderBy: Syntax {
    
    public var terms: List<OrderingTerm>
    
    public init(terms: List<OrderingTerm>) {
        self.terms = terms
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("ORDER", "BY")
        try builder.add(terms)
    }
    
}
