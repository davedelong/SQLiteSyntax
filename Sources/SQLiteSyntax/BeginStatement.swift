//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct BeginStatement: Syntax {
    
    public enum Behavior: Syntax {
        case deferred
        case immediate
        case exclusive
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .deferred: builder.add("DEFERRED")
                case .immediate: builder.add("IMMEDIATE")
                case .exclusive: builder.add("EXCLUSIVE")
            }
        }
    }
    
    public var behavior: Behavior?
    public var transaction: Bool
    
    public init(behavior: Behavior? = nil, transaction: Bool) {
        self.behavior = behavior
        self.transaction = transaction
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("BEGIN")
        try builder.add(behavior)
        if transaction { builder.add("TRANSACTION") }
    }
}
