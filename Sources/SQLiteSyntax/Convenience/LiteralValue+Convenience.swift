//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/29/25.
//

import Foundation

extension LiteralValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    
    public init(stringLiteral value: String) {
        self = .string(value)
    }
    
    public init(booleanLiteral value: Bool) {
        self = value ? .true : .false
    }
    
    public init(integerLiteral value: Int) {
        self = .integer(Int64(value))
    }
    
    public init(floatLiteral value: Double) {
        self = .real(value)
    }
    
}
