//
//  NumericLiteral.swift
//  SQLiteSyntax
//

/// A `numeric-literal` token: an unsigned number. `signed-number` adds the sign. Used by generated types
/// (see `tokens` in SQLiteSyntaxGenerator/Grammar/codegen.json).
public enum NumericLiteral: Syntax, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {

    /// An INTEGER, e.g. `10` or `0x10`. A negative value is written as the hex literal SQLite reads as it
    /// (`0xFFFFFFFFFFFFFFFF` is -1), since a numeric literal has no sign.
    case integer(Int64)

    /// A REAL, e.g. `1.5` or `1e3`; it must not be negative or NaN.
    case real(Double)

    public init(integerLiteral value: Int64) {
        self = .integer(value)
    }

    public init(floatLiteral value: Double) {
        self = .real(value)
    }

    public func validate() throws(SyntaxError) {
        if case .real(let d) = self {
            try require(!d.isNaN, reason: "A numeric literal must be a number")
            try require(d.sign == .plus, reason: "A numeric literal cannot be negative; give SignedNumber a sign instead")
        }
    }

    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        switch self {
            case .integer(let i) where i < 0:
                builder.add("0x" + String(UInt64(bitPattern: i), radix: 16, uppercase: true))
            case .integer(let i):
                builder.add(LiteralValue.integer(i).text)
            case .real(let d):
                builder.add(LiteralValue.real(d).text)
        }
    }

    public static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        let token = p.current
        guard case .number = token.kind else {
            let e = p.unexpected(expected: "a number")
            p.state.record(e)
            throw e
        }
        _ = p.advance()
        switch try p.numericLiteral(token.string, token: token) {
            case .integer(let i): return .integer(i)
            case .real(let d): return .real(d)
            default: fatalError("numericLiteral returns only integers and reals")
        }
    }
}
