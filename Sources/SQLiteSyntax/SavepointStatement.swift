//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct SavepointStatement: Syntax {
    
    public var savepointName: SavepointName
    
    public init(savepointName: SavepointName) {
        self.savepointName = savepointName
    }
    
}
