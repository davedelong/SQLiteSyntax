//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/20/25.
//

import Foundation

public struct TypeName: Syntax {
    
    public enum Arguments: Syntax {
        case one(Decimal)
        case two(Decimal, Decimal)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            builder.add("(")
            switch self {
                case .one(let d): builder.add(d.description)
                case .two(let a, let b): builder.add(a.description, ",", b.description)
            }
            builder.add(")")
        }
    }
    
    public var names: List<Name<Any>>
    
    public var arguments: Arguments?
    
    public init(names: List<Name<Any>>, arguments: Arguments? = nil) {
        self.names = names
        self.arguments = arguments
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        try builder.add(names)
        try builder.add(arguments)
    }
}
