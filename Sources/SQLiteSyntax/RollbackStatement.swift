//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct RollbackStatement: Syntax {
    
    public var transaction: Bool
    
    public var savepointName: SavepointName?
    
    public init(transaction: Bool, savepointName: SavepointName? = nil) {
        self.transaction = transaction
        self.savepointName = savepointName
    }
    
}
