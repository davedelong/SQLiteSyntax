//
//  ModuleArgument.swift
//  SQLiteSyntax
//

/// A `module-argument` of `CREATE VIRTUAL TABLE … USING module(…)`: arbitrary SQL tokens, passed to the
/// module as text. Used by generated types (see Grammar/codegen.json `tokens`).
public struct ModuleArgument: Syntax, ExpressibleByStringLiteral {
    public var text: String

    public init(_ text: String) { self.text = text }
    public init(stringLiteral value: String) { self.text = value }

    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add(text)
    }
}
