/// Renders `TypeDecl`s as Swift source.
struct Emitter {
    var lines: [String] = []
    var indent = 0

    mutating func line(_ s: String = "") {
        lines.append(s.isEmpty ? "" : String(repeating: "    ", count: indent) + s)
    }

    mutating func block(_ header: String, _ body: (inout Emitter) -> Void) {
        line(header + " {")
        indent += 1
        body(&self)
        indent -= 1
        line("}")
    }

    static func quoted(_ texts: [String]) -> String {
        texts.map { "\"\($0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\"" }
            .joined(separator: ", ")
    }

    mutating func emit(_ decl: TypeDecl) {
        line("/// `\(decl.grammar)`")
        switch decl.kind {
            case .structure(let fields, let body):
                block("struct \(decl.name): Syntax") { e in
                    for f in fields {
                        let value = f.defaultValue.map { " = \($0)" } ?? ""
                        e.line("\(f.boxed ? "@Indirect " : "")var \(Naming.identifier(f.name)): \(f.type)\(value)")
                    }
                    let nonEmpty = fields.filter(\.nonEmptyList)
                    if !nonEmpty.isEmpty {
                        e.line()
                        e.block("func validate() throws(SyntaxError)") { e in
                            for f in nonEmpty {
                                e.line("try require(!\(Naming.identifier(f.name)).isEmpty, reason: \"\(decl.name).\(f.name) must not be empty\")")
                            }
                        }
                    }
                    e.line()
                    e.block("func build(using builder: inout SyntaxBuilder) throws(SyntaxError)") { e in
                        if body.isEmpty { e.line("// nothing to emit") }
                        e.emit(body)
                    }
                    for n in decl.nested { e.line(); e.emit(n) }
                }

            case .enumeration(let cases, let prefix, let suffix):
                let conformances = cases.allSatisfy(\.payload.isEmpty) ? "Syntax, CaseIterable" : "Syntax"
                block("\(decl.isIndirect ? "indirect " : "")enum \(decl.name): \(conformances)") { e in
                    for c in cases {
                        e.line("/// `\(c.grammar)`")
                        if c.payload.isEmpty {
                            e.line("case \(Naming.identifier(c.name))")
                        } else {
                            let params = c.payload.map { f -> String in
                                let value = f.defaultValue.map { " = \($0)" } ?? ""
                                return c.labelled ? "\(f.name): \(f.type)\(value)" : "\(f.type)\(value)"
                            }
                            e.line("case \(Naming.identifier(c.name))(\(params.joined(separator: ", ")))")
                        }
                    }
                    let validating = cases.filter { $0.payload.contains(where: \.nonEmptyList) }
                    if !validating.isEmpty {
                        e.line()
                        e.block("func validate() throws(SyntaxError)") { e in
                            e.block("switch self") { e in
                                for c in validating {
                                    e.line("case \(Emitter.pattern(c)):")
                                    e.indent += 1
                                    for f in c.payload where f.nonEmptyList {
                                        e.line("try require(!\(Naming.identifier(f.name)).isEmpty, reason: \"\(decl.name).\(c.name) list must not be empty\")")
                                    }
                                    e.indent -= 1
                                }
                                e.line("default:")
                                e.line("    break")
                            }
                        }
                    }
                    e.line()
                    e.block("func build(using builder: inout SyntaxBuilder) throws(SyntaxError)") { e in
                        if !prefix.isEmpty { e.line("builder.add(\(Emitter.quoted(prefix)))") }
                        e.block("switch self") { e in
                            for c in cases {
                                e.line("case \(Emitter.pattern(c)):")
                                e.indent += 1
                                if c.body.isEmpty { e.line("break") }
                                e.emit(c.body)
                                e.indent -= 1
                            }
                        }
                        if !suffix.isEmpty { e.line("builder.add(\(Emitter.quoted(suffix)))") }
                    }
                    for n in decl.nested { e.line(); e.emit(n) }
                }
        }
    }

    static func pattern(_ c: Case) -> String {
        if c.payload.isEmpty { return ".\(Naming.identifier(c.name))" }
        return ".\(Naming.identifier(c.name))(" + c.payload.map { "let \(Naming.identifier($0.name))" }.joined(separator: ", ") + ")"
    }

    mutating func emit(_ body: [Template]) {
        for t in body {
            switch t {
                case .text(let texts):
                    line("builder.add(\(Emitter.quoted(texts)))")
                case .value(let name):
                    line("try builder.add(\(Naming.identifier(name)))")
                case .flag(let name, let texts):
                    line("if \(Naming.identifier(name)) { builder.add(\(Emitter.quoted(texts))) }")
                case .optional(let name, let inner):
                    block("if let \(Naming.identifier(name))") { e in e.emit(inner) }
                case .list(let name, let separator, let nonEmpty):
                    let items = Naming.identifier(name) + (nonEmpty ? ".items" : "")
                    let delimiter = separator.map { ", delimiter: \(Emitter.quoted([$0]))" } ?? ""
                    line("try builder.addList(\(items)\(delimiter))")
            }
        }
    }
}
