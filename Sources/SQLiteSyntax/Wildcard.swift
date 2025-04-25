//
//  Wildcard.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

public struct Wildcard: Syntax {
    public init() { }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add("*")
    }
}
