//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CommitStatement: Syntax {
    
    public enum Kind: Syntax {
        case commit
        case end
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .commit: builder.add("COMMIT")
                case .end: builder.add("END")
            }
        }
    }
    
    public var kind: Kind
    public var transaction: Bool
    
    public init(kind: Kind, transaction: Bool) {
        self.kind = kind
        self.transaction = transaction
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(kind)
        if transaction { builder.add("TRANSACTION") }
    }
    
}
