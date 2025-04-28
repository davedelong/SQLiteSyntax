//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct RollbackStatement: Syntax {
    
    public var transaction: Bool
    
    public var savepointName: Name<Savepoint>?
    
    public init(transaction: Bool, savepointName: Name<Savepoint>? = nil) {
        self.transaction = transaction
        self.savepointName = savepointName
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("ROLLBACK")
        if transaction { builder.add("TRANSACTION") }
        if let savepointName {
            builder.add("TO", "SAVEPOINT")
            try builder.add(savepointName)
        }
    }
}
