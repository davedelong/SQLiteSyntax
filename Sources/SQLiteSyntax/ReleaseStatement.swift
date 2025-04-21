//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct ReleaseStatement: Syntax {
    
    public var savepoint: Bool
    public var savepointName: SavepointName
    
    public init(savepoint: Bool, savepointName: SavepointName) {
        self.savepoint = savepoint
        self.savepointName = savepointName
    }
}
