//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct JoinClause: Syntax {
    
    public var tableOrSubquery: TableOrSubquery
    
    public var joins: Array<(JoinOperator, TableOrSubquery, JoinConstraint?)>
    
    public init(tableOrSubquery: TableOrSubquery, joins: Array<(JoinOperator, TableOrSubquery, JoinConstraint?)>) {
        self.tableOrSubquery = tableOrSubquery
        self.joins = joins
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(tableOrSubquery)
        for (op, tos, c) in joins {
            try builder.add(op)
            try builder.add(tos)
            try builder.add(c)
        }
    }
    
}

public enum JoinConstraint: Syntax {
    case on(Expression)
    case using(List<Name<Column>>)
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .on(let e):
                builder.add("ON")
                try builder.add(e)
            case .using(let list):
                builder.add("USING", "(")
                try builder.add(list)
                builder.add(")")
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
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .left: builder.add("LEFT")
                case .leftOuter: builder.add("LEFT", "OUTER")
                case .right: builder.add("RIGHT")
                case .rightOuter: builder.add("RIGHT", "OUTER")
                case .full: builder.add("FULL")
                case .fullOuter: builder.add("FULL", "OUTER")
                case .inner: builder.add("INNER")
            }
        }
    }
    
    case `default`
    case normal(Style)
    case natural(Style)
    case cross
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .default:
                builder.add(",")
            case .normal(let s):
                try builder.add(s)
                builder.add("JOIN")
            case .natural(let s):
                builder.add("NATURAL")
                try builder.add(s)
                builder.add("JOIN")
            case .cross:
                builder.add("CROSS", "JOIN")
        }
    }
    
}
