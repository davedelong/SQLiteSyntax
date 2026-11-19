//
//  NumericLiteral.swift
//  SQLiteSyntax
//

import Foundation

/// A `numeric-literal` token. Used by generated types (see Grammar/codegen.json `tokens`).
struct NumericLiteral: Syntax, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    var value: Decimal

    init(_ value: Decimal) { self.value = value }
    init(integerLiteral value: Int) { self.value = Decimal(value) }
    init(floatLiteral value: Double) { self.value = Decimal(value) }

    func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add(value.description)
    }
}
