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
            
            public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
                switch self {
                    case .distinct: builder.add("DISTINCT")
                    case .all: builder.add("ALL")
                }
            }
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
            
            public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
                builder.add("FROM")
                switch self {
                    case .tableOrSubquery(let list):
                        try builder.addList(list, delimiter: ",")
                    case .join(let join):
                        try builder.add(join)
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
        
        public init(selection: Selection? = nil, columns: Array<ResultColumn>, from: From? = nil, `where`: Expression? = nil, groupBy: Array<Expression>, having: Expression? = nil, window: Array<(WindowName, WindowDefinition)>) {
            self.selection = selection
            self.columns = columns
            self.from = from
            self.`where` = `where`
            self.groupBy = groupBy
            self.having = having
            self.window = window
        }
        
        public func validate() throws(SyntaxError) {
            try require(columns.count > 0, reason: "Selecting values requires at least one column")
        }
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            builder.add("SELECT")
            try builder.add(selection)
            try builder.addList(columns, delimiter: ",")
            try builder.add(from)
            try builder.add(`where`)
            if groupBy.count > 0 {
                builder.add("GROUP", "BY")
                try builder.addList(groupBy, delimiter: ",")
            }
            if let having {
                builder.add("HAVING")
                try builder.add(having)
            }
            if window.count > 0 {
                builder.add("WINDOW")
                var needsComma = false
                for (name, defn) in window {
                    if needsComma { builder.add(",") }
                    try builder.add(name)
                    try builder.addAlias(defn)
                    needsComma = true
                }
            }
        }
    }
    
    case select(Core)
    case values(ExpressionList)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .select(let core):
                try builder.add(core)
            case .values(let list):
                builder.add("VALUES", "(")
                try builder.add(list)
                builder.add(")")
        }
    }
    
}
