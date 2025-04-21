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
    }
    
    public var behavior: Behavior?
    public var transaction: Bool
    
    public init(behavior: Behavior? = nil, transaction: Bool) {
        self.behavior = behavior
        self.transaction = transaction
    }
    
}
