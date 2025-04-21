//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct SavepointName: Syntax {
    
    public var value: String
    
    public init(value: String) {
        self.value = value
    }
}
