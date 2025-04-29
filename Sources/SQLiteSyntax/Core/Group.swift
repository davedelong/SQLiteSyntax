//
//  Group.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/29/25.
//

public struct Group<T: Syntax>: Syntax {
    
    public var contents: T
    
    public init(contents: T) {
        self.contents = contents
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(group: contents)
    }
}
