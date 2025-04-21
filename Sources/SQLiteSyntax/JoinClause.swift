//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct JoinClause: Syntax {
    
    public var tableOrSubquery: TableOrSubquery
    
    public var joins: Array<(JoinOperator?, TableOrSubquery, JoinConstraint?)>
    
    public init(tableOrSubquery: TableOrSubquery, joins: Array<(JoinOperator?, TableOrSubquery, JoinConstraint?)>) {
        self.tableOrSubquery = tableOrSubquery
        self.joins = joins
    }
    
}

public enum JoinConstraint: Syntax {
    case on(Expression)
    case using(Array<ColumnName>)
    
    public func validate() throws(SyntaxError) {
        switch self {
            case .using(let names):
                try require(names.count > 0, reason: "Joining using column names requires at least one column name")
            default:
                break
        }
    }
}

public enum JoinOperator: Syntax {
    
    public enum Style: Syntax {
        case left
        case leftOuter
        case right
        case rightOuter
        case full
        case fullOuter
        case inner
    }
    
    case normal(Style)
    case natural(Style)
    case cross
    
}
