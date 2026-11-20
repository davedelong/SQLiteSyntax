//
//  NumericLiteral.swift
//  SQLiteSyntax
//

import Foundation

/// A `numeric-literal` token. Used by generated types (see `tokens` in SQLiteSyntaxGenerator/Grammar/codegen.json).
public struct NumericLiteral: Syntax, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public var value: Decimal

    public init(_ value: Decimal) { self.value = value }
    public init(integerLiteral value: Int) { self.value = Decimal(value) }
    public init(floatLiteral value: Double) { self.value = Decimal(value) }

    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add(value.description)
    }
}
