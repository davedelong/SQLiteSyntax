//
//  ModuleArgument.swift
//  SQLiteSyntax
//

/// A `module-argument` of `CREATE VIRTUAL TABLE … USING module(…)`: arbitrary SQL tokens, passed to the
/// module as text. Used by generated types (see Grammar/codegen.json `tokens`).
struct ModuleArgument: Syntax, ExpressibleByStringLiteral {
    var text: String

    init(_ text: String) { self.text = text }
    init(stringLiteral value: String) { self.text = value }

    func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        builder.add(text)
    }
}
