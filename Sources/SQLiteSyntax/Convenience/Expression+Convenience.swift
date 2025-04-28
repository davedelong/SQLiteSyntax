//
//  File.swift
//  SQLiteSyntax
//
//  Created by Dave DeLong on 4/28/25.
//

import Foundation

extension Expression {
    
    public static func columnName(_ name: Name<Column>) -> Self {
        .columnName(nil, nil, name)
    }
    
}

extension LiteralValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByNilLiteral {
    
    public init(stringLiteral value: String) {
        self = .string(value)
    }
    
    public init(booleanLiteral value: Bool) {
        self = value ? .true : .false
    }
    
    public init(integerLiteral value: Int) {
        self = .number(Decimal(value))
    }
    
    public init(floatLiteral value: Double) {
        self = .number(Decimal(value))
    }
    
    public init(nilLiteral: ()) {
        self = .null
    }
    
}
