//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct FilterClause: Syntax {
    
    public var `where`: Expression
    
    public init(where: Expression) {
        self.where = `where`
    }
    
}
