//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public enum SelectCore: Syntax {
    
    public struct Core: Syntax {
        
        public enum Selection: Syntax {
            case distinct
            case all
        }
        
        public enum From: Syntax {
            case tableOrSubquery(Array<TableOrSubquery>)
            case join(JoinClause)
            
            public func validate() throws(SyntaxError) {
                switch self {
                    case .tableOrSubquery(let values):
                        try require(values.count > 0, reason: "Selecting from a table or subquery requires at least one of them")
                    default:
                        break
                }
            }
        }
        
        public var selection: Selection?
        
        public var columns: Array<ResultColumn>
        public var from: From?
        public var `where`: Expression?
        public var groupBy: Array<Expression>
        public var having: Expression?
        public var window: Array<(WindowName, WindowDefinition)>
        
        public init(selection: Selection? = nil, columns: Array<ResultColumn>, from: From? = nil, groupBy: Array<Expression>, having: Expression? = nil, window: Array<(WindowName, WindowDefinition)>) {
            self.selection = selection
            self.columns = columns
            self.from = from
            self.groupBy = groupBy
            self.having = having
            self.window = window
        }
        
        public func validate() throws(SyntaxError) {
            try require(columns.count > 0, reason: "Selecting values requires at least one column")
        }
        
    }
    
    case select(Core)
    case values(Array<Expression>)
    
    public func validate() throws(SyntaxError) {
        switch self {
            case .values(let expressions):
                try require(expressions.count > 0, reason: "Selecting expression values requires at least one expression")
            default:
                break
        }
    }
    
}
