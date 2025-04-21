//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct With: Syntax {
    public var recursive: Bool
    public var commonTableExpressions: Array<CommonTableExpression>
    
    public init(recursive: Bool, commonTableExpressions: Array<CommonTableExpression>) {
        self.recursive = recursive
        self.commonTableExpressions = commonTableExpressions
    }
    
    public func validate() throws(SyntaxError) {
        try require(commonTableExpressions.count > 0, reason: "'With' clauses must specify at least one CommonTableExpression")
    }
}
