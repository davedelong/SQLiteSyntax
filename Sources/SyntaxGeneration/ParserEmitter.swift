import Foundation

/// Renders a `parse(_:)` function for each generated type, from the same template as `build(using:)`.
/// The output belongs to the SQLiteParser module (it uses its `Parser` and `SQLParsable`).
struct ParserEmitter {
    var e = Emitter()
    /// Every generated type by Swift name and path, for computing which keywords can begin a type.
    var declarations: [String: TypeDecl] = [:]
    private var firstCache: [String: Set<String>] = [:]

    /// Tokens whose names follow parse.y's narrower `ids` class (no JOIN_KW): aliases.
    static let aliasSymbols: Set<String> = ["table-alias", "column-alias", "alias"]

    mutating func emit(_ decl: TypeDecl) {
        var out = e
        render(decl, into: &out)
        if !decl.path.contains(".") {
            // The public entry point for top-level types: parse a whole string.
            out.line()
            out.line("extension \(decl.path) {")
            out.indent += 1
            out.line("/// Parses SQL text that consists of exactly one `\(decl.path)`.")
            out.line("public init(parsing sql: String) throws(ParseError) {")
            out.line("    self = try Parser.parseAll(sql) { (p: inout Parser) throws(ParseError) in try \(decl.path).parse(&p) }")
            out.line("}")
            out.indent -= 1
            out.line("}")
        }
        e = out
    }

    private mutating func render(_ decl: TypeDecl, into e: inout Emitter) {
        e.line("extension \(decl.path): SQLParsable {")
        e.indent += 1
        e.line("static func parse(_ p: inout Parser) throws(ParseError) -> \(decl.path) {")
        e.indent += 1
        e.line("try p.memoized(Self.self) { (p: inout Parser) throws(ParseError) -> \(decl.path) in")
        e.indent += 1
        switch decl.kind {
            case .structure(let fields, let body):
                statements(body, fields: fields, in: decl, into: &e)
                e.line("return \(decl.path)(\(ParserEmitter.arguments(fields, labelled: true)))")
            case .enumeration(let cases, let prefix, let suffix):
                if !prefix.isEmpty { e.line("try p.expect(texts: \(Emitter.array(prefix)))") }
                e.line("let alternatives: [(inout Parser) throws -> \(decl.path)] = [")
                e.indent += 1
                for c in cases {
                    e.line("{ (p: inout Parser) throws -> \(decl.path) in")
                    e.indent += 1
                    statements(c.body, fields: c.payload, in: decl, into: &e)
                    let name = Naming.identifier(c.name)
                    e.line(c.payload.isEmpty ? "return .\(name)"
                           : "return .\(name)(\(ParserEmitter.arguments(c.payload, labelled: c.labelled)))")
                    e.indent -= 1
                    e.line("},")
                }
                e.indent -= 1
                e.line("]")
                e.line("let value = try p.longest(alternatives)")
                if !suffix.isEmpty { e.line("try p.expect(texts: \(Emitter.array(suffix)))") }
                e.line("return value")
        }
        e.indent -= 1
        e.line("}")
        e.indent -= 1
        e.line("}")
        e.indent -= 1
        e.line("}")
        for nested in decl.nested { e.line(); render(nested, into: &e) }
    }

    static func arguments(_ fields: [Field], labelled: Bool) -> String {
        fields.map { labelled ? "\($0.name): \(Naming.identifier($0.name))" : Naming.identifier($0.name) }.joined(separator: ", ")
    }

    /// Statements that parse `body`, binding each field to a local of the same name.
    mutating func statements(_ body: [Template], fields: [Field], in decl: TypeDecl, into e: inout Emitter) {
        // Which field each template stores (nil for fixed tokens), to look ahead at what follows.
        var fieldOf: [Field?] = []
        var i = 0
        for t in body {
            if case .text = t { fieldOf.append(nil) } else { fieldOf.append(fields[i]); i += 1 }
        }
        var index = 0
        func nextField() -> Field { defer { index += 1 }; return fields[index] }
        for (position, t) in body.enumerated() {
            // Keywords that may come next here can't be taken as a name (SQLite only lets a keyword be
            // a name where the keyword itself cannot appear): `OVER ( [name] PARTITION BY …`.
            let follow = followKeywords(after: position, in: body, fields: fieldOf, owner: decl)
            func call(_ type: String, symbol: String?) -> String { ParserEmitter.call(type, symbol: symbol, excluding: follow) }
            func listCall(_ type: String, separator: String?, leading: Bool, symbol: String?) -> String {
                ParserEmitter.listCall(type, separator: separator, leading: leading, symbol: symbol, excluding: follow)
            }
            switch t {
                case .text(let texts):
                    e.line("try p.expect(texts: \(Emitter.array(texts)))")
                case .flag(_, let texts):
                    let f = nextField()
                    e.line("let \(Naming.identifier(f.name)) = p.accept(texts: \(Emitter.array(texts)))")
                case .value:
                    let f = nextField()
                    if f.type.hasSuffix("?") {
                        let base = String(f.type.dropLast())
                        e.line("let \(Naming.identifier(f.name)) = p.attempt { (p: inout Parser) throws(ParseError) -> \(base) in \(call(base, symbol: f.symbol)) }")
                    } else {
                        e.line("let \(Naming.identifier(f.name)) = \(call(f.type, symbol: f.symbol))")
                    }
                case .list(_, let separator, _, let leading):
                    let f = nextField()
                    e.line("let \(Naming.identifier(f.name)) = \(listCall(f.type, separator: separator, leading: leading, symbol: f.symbol))")
                case .optional(_, let inner):
                    let f = nextField()
                    let base = String(f.type.dropLast())
                    e.closure("let \(Naming.identifier(f.name)) = p.attempt { (p: inout Parser) throws(ParseError) -> \(base) in") { e in
                        for t in inner {
                            switch t {
                                case .text(let texts): e.line("try p.expect(texts: \(Emitter.array(texts)))")
                                case .list(_, let separator, _, let leading):
                                    e.line("let value = \(listCall(base, separator: separator, leading: leading, symbol: f.symbol))")
                                default: e.line("let value = \(call(base, symbol: f.symbol))")
                            }
                        }
                        e.line("return value")
                    }
            }
        }
    }

    /// `try T.parse(&p)` for a single (non-optional, non-list) type.
    static func call(_ type: String, symbol: String?, excluding: Set<String>) -> String {
        if type.hasPrefix("Name<") {
            let nameClass = symbol.map(aliasSymbols.contains) == true ? ".alias" : ".name"
            let exclusions = excluding.isEmpty ? "" : ", excluding: \(Emitter.array(excluding.sorted()))"
            return "try \(type).parse(&p, class: \(nameClass)\(exclusions))"
        }
        return "try \(type).parse(&p)"
    }

    static func listCall(_ type: String, separator: String?, leading: Bool, symbol: String?, excluding: Set<String>) -> String {
        let tokens = Emitter.array(separator.map { $0.split(separator: " ").map(String.init) } ?? [])
        if type.hasPrefix("List<") {
            let element = String(type.dropFirst(5).dropLast())
            return "List(try p.separated(by: \(tokens)) { (p: inout Parser) throws(ParseError) -> \(element) in \(call(element, symbol: symbol, excluding: excluding)) })"
        }
        let element = String(type.dropFirst().dropLast())   // [E]
        return "p.repeated(separator: \(leading ? tokens : "[]")) { (p: inout Parser) throws(ParseError) -> \(element) in \(call(element, symbol: symbol, excluding: excluding)) }"
    }

    // MARK: Lookahead

    /// Keywords that can begin whatever follows template `position` in this sequence (up to the first
    /// item that must be present).
    mutating func followKeywords(after position: Int, in body: [Template], fields: [Field?], owner: TypeDecl) -> Set<String> {
        var result: Set<String> = []
        for i in (position + 1)..<body.count {
            let (first, nullable) = firstKeywords(of: body[i], field: fields[i], owner: owner)
            result.formUnion(first)
            if !nullable { break }
        }
        return result
    }

    /// Keywords that can begin a template, and whether it can match nothing.
    mutating func firstKeywords(of template: Template, field: Field?, owner: TypeDecl) -> (Set<String>, Bool) {
        switch template {
            case .text(let texts): return (keywords(texts.prefix(1)), false)
            case .flag(_, let texts): return (keywords(texts.prefix(1)), true)
            case .optional(_, let inner):
                if case .text(let texts)? = inner.first { return (keywords(texts.prefix(1)), true) }
                return (firstKeywords(ofType: field!.type, owner: owner), true)
            case .value, .list:
                let type = field!.type
                let nullable = type.hasSuffix("?") || type.hasPrefix("[") || type == "Bool"
                return (firstKeywords(ofType: type, owner: owner), nullable)
        }
    }

    func keywords<S: Sequence>(_ texts: S) -> Set<String> where S.Element == String {
        Set(texts.filter { $0.first?.isLetter == true })
    }

    /// Keywords that can begin a value of a Swift type (generated types only; names, expressions and
    /// literals begin with no fixed keyword that matters here).
    mutating func firstKeywords(ofType type: String, owner: TypeDecl) -> Set<String> {
        var base = type
        if base.hasSuffix("?") { base.removeLast() }
        if base.hasPrefix("List<") { base = String(base.dropFirst(5).dropLast()) }
        if base.hasPrefix("[") { base = String(base.dropFirst().dropLast()) }
        // Nested types are named relative to their owner (or one of its ancestors).
        var scope = owner.path
        while declarations[scope + "." + base] == nil, let dot = scope.lastIndex(of: ".") { scope = String(scope[..<dot]) }
        if declarations[scope + "." + base] != nil { base = scope + "." + base }
        if let cached = firstCache[base] { return cached }
        guard let decl = declarations[base] else { return [] }
        firstCache[base] = []   // recursion guard
        var result: Set<String> = []
        switch decl.kind {
            case .structure(let fields, let body):
                result = firstKeywords(ofSequence: body, fields: fields, in: decl)
            case .enumeration(let cases, let prefix, _):
                if !prefix.isEmpty { result = keywords(prefix.prefix(1)) }
                else { for c in cases { result.formUnion(firstKeywords(ofSequence: c.body, fields: c.payload, in: decl)) } }
        }
        firstCache[base] = result
        return result
    }

    mutating func firstKeywords(ofSequence body: [Template], fields: [Field], in decl: TypeDecl) -> Set<String> {
        var result: Set<String> = []
        var index = 0
        for t in body {
            var field: Field? = nil
            if case .text = t {} else { field = fields[index]; index += 1 }
            let (first, nullable) = firstKeywords(of: t, field: field, owner: decl)
            result.formUnion(first)
            if !nullable { break }
        }
        return result
    }

}

extension Emitter {
    static func array(_ texts: [String]) -> String { "[" + quoted(texts) + "]" }

    /// Like `block`, for a header that already opens a closure (`… { (p: inout Parser) … in`).
    mutating func closure(_ header: String, _ body: (inout Emitter) -> Void) {
        line(header)
        indent += 1
        body(&self)
        indent -= 1
        line("}")
    }
}
