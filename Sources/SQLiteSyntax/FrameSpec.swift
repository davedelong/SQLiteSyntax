//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct FrameSpec: Syntax {
    
    public enum Target: Syntax {
        case range
        case rows
        case groups
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .range: builder.add("RANGE")
                case .rows: builder.add("ROWS")
                case .groups: builder.add("GROUPS")
            }
        }
    }
    
    public enum Scope: Syntax {
        
        public enum LowerBound: Syntax {
            case unboundedPreceding
            case preceding(Expression)
            case currentRow
            case following(Expression)
            
            public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
                switch self {
                    case .unboundedPreceding:
                        builder.add("UNBOUNDED", "PRECEDING")
                    case .preceding(let e):
                        try builder.add(e)
                        builder.add("PRECEDING")
                    case .currentRow:
                        builder.add("CURRENT", "ROW")
                    case .following(let e):
                        try builder.add(e)
                        builder.add("FOLLOWING")
                }
            }
        }
        
        public enum UpperBound: Syntax {
            case preceding(Expression)
            case currentRow
            case following(Expression)
            case unboundedFollowing
            
            public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
                switch self {
                    case .preceding(let e):
                        try builder.add(e)
                        builder.add("PRECEDING")
                    case .currentRow:
                        builder.add("CURRENT", "ROW")
                    case .following(let e):
                        try builder.add(e)
                        builder.add("FOLLOWING")
                    case .unboundedFollowing:
                        builder.add("UNBOUNDED", "FOLLOWING")
                }
            }
        }
        
        case between(LowerBound, UpperBound)
        case unboundedPreceding
        case preceding(Expression)
        case currentRow
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .between(let lower, let upper):
                    builder.add("BETWEEN")
                    try builder.add(lower)
                    builder.add("AND")
                    try builder.add(upper)
                case .unboundedPreceding:
                    builder.add("UNBOUNDED", "PRECEDING")
                case .preceding(let e):
                    try builder.add(e)
                    builder.add("PRECEDING")
                case .currentRow:
                    builder.add("CURRENT", "ROW")
            }
        }
    }
    
    public enum Exclude: Syntax {
        case noOthers
        case currentRow
        case group
        case ties
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            builder.add("EXCLUDE")
            switch self {
                case .noOthers: builder.add("NO", "OTHERS")
                case .currentRow: builder.add("CURRENT", "ROW")
                case .group: builder.add("GROUP")
                case .ties: builder.add("TIES")
            }
        }
    }
    
    public var target: Target
    
    public var scope: Scope
    
    public var exclude: Exclude?
    
    public init(target: Target, scope: Scope, exclude: Exclude? = nil) {
        self.target = target
        self.scope = scope
        self.exclude = exclude
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(target)
        try builder.add(scope)
        try builder.add(exclude)
    }
}
