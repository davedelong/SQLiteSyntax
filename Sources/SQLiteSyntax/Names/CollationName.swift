//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct CollationName: Syntax {
    
    public var value: String
    
    public init(value: String) {
        self.value = value
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add(value)
    }
}
