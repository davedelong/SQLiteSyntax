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
    }
    
    public var names: Array<Name>
    
    public var arguments: Arguments?
    
    public init(names: Array<Name>, arguments: Arguments? = nil) {
        self.names = names
        self.arguments = arguments
    }
}
