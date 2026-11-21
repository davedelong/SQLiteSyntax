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

    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        let token = p.current
        guard case .number = token.kind else {
            let e = p.unexpected(expected: "a number")
            p.state.record(e)
            throw e
        }
        _ = p.advance()
        return NumericLiteral(try p.number(token.string, token: token))
    }
}
