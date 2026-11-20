import GrammarExtraction

/// What `build(using:)` emits, in order.
indirect enum Template {
    /// Fixed keywords/punctuation.
    case text([String])
    /// A stored `Syntax` value (possibly optional).
    case value(String)
    /// A `Bool` that emits fixed tokens when true.
    case flag(String, [String])
    /// `if let name { … }`: an optional group with fixed tokens around one stored value.
    case optional(String, [Template])
    /// A list of `Syntax` values joined by a separator (or, if `leading`, with it before each value).
    case list(String, separator: String?, nonEmpty: Bool, leading: Bool = false)
}

struct Field {
    var name: String
    var type: String
    var defaultValue: String?
    var nonEmptyList = false
    /// The path of the generated type this field stores inline (not through a list), if any.
    /// Used to find reference cycles.
    var target: String? = nil
    /// Stored through the `Indirect` property wrapper to break a cycle between structs.
    var boxed = false
}

struct Case {
    var name: String
    var payload: [Field]
    var body: [Template]
    var grammar: String
    var labelled: Bool { payload.count > 1 || payload.contains { $0.type == "Bool" } }
}

final class TypeDecl {
    enum Kind {
        case structure(fields: [Field], body: [Template])
        /// An enum, with fixed tokens emitted before and after the case's own tokens.
        case enumeration(cases: [Case], prefix: [String], suffix: [String])
    }
    let name: String
    let path: String
    var kind: Kind = .structure(fields: [], body: [])
    var nested: [TypeDecl] = []
    var grammar: String
    /// Emitted as `indirect enum` because the type is part of a reference cycle.
    var isIndirect = false

    init(name: String, path: String, grammar: String) {
        self.name = name
        self.path = path
        self.grammar = grammar
    }
}

/// Derives Swift types from lowered grammar rules.
final class TypeBuilder {
    let configuration: CodegenConfiguration
    /// Rules being generated, by grammar name.
    let generatedRules: Set<String>
    /// Generated rules whose whole diagram is optional; references to them are `Optional`.
    var nullableRules: Set<String> = []
    var warnings: [String] = []
    /// Type names that nested types must not shadow.
    var reservedTypeNames: Set<String>

    init(configuration: CodegenConfiguration) {
        self.configuration = configuration
        self.generatedRules = Set(configuration.rules)
        reservedTypeNames = ["Expression", "Name", "List", "String", "Bool", "Optional", "Array", "Decimal", "Data",
                             "Table", "Schema", "Column", "Function", "Index", "Trigger", "View", "Module",
                             "Collation", "Window", "Savepoint", "Syntax", "SyntaxBuilder", "SyntaxError"]
        reservedTypeNames.formUnion(configuration.references.values)
        reservedTypeNames.formUnion(configuration.keywordEnums.values)
        reservedTypeNames.formUnion(configuration.rules.map(typeName(forRule:)))
    }

    func typeName(forRule rule: String) -> String {
        configuration.names["type:\(rule)"] ?? Naming.typeName(forRule: rule)
    }

    // MARK: Rules

    func declaration(forRule name: String, node rawNode: Node, grammar: String) -> TypeDecl {
        var node = rawNode
        if case .optional(let inner) = node { node = inner }   // nullability is expressed at use sites
        let typeName = typeName(forRule: name)
        let decl = TypeDecl(name: typeName, path: typeName, grammar: grammar)
        let items = node.items
        let stored = items.filter(\.isStored)

        if case .choice(let alternatives) = node {
            decl.kind = enumeration(alternatives, in: decl, prefix: [], suffix: [])
        } else if stored.count == 1, case .choice(let alternatives) = stored[0],
                  keywordEnum(for: alternatives) == nil,
                  let index = items.firstIndex(of: stored[0]) {
            // fixed tokens around a single choice: the type *is* the choice
            let prefix = items[..<index].flatMap(\.allTexts), suffix = items[(index + 1)...].flatMap(\.allTexts)
            decl.kind = enumeration(alternatives, in: decl, prefix: prefix, suffix: suffix)
        } else {
            var scope = Scope(owner: decl)
            let (fields, body) = members(items, scope: &scope)
            decl.kind = .structure(fields: fields, body: body)
        }
        return decl
    }

    // MARK: Members

    /// Names already used within one struct or enum case.
    struct Scope {
        let owner: TypeDecl
        /// Qualifies override keys, e.g. `FrameSpec` or `FrameSpec.Scope.between` for a case's payload.
        var path: String
        var used: Set<String> = []
        var fallbackCount = 0

        init(owner: TypeDecl, path: String? = nil) {
            self.owner = owner
            self.path = path ?? owner.path
        }
    }

    func uniqueName(_ proposed: String, scope: inout Scope) -> String {
        var name = configuration.names["\(scope.path).\(proposed)"] ?? proposed
        if scope.used.contains(name) {
            var n = 2
            while scope.used.contains("\(name)\(n)") { n += 1 }
            let numbered = "\(name)\(n)"
            if let override = configuration.names["\(scope.path).\(numbered)"] {
                name = override
            } else {
                warnings.append("\(scope.path).\(numbered): duplicate member name; consider an override")
                name = numbered
            }
        }
        scope.used.insert(name)
        return name
    }

    func fallbackName(scope: inout Scope, for node: Node? = nil) -> String {
        scope.fallbackCount += 1
        let proposed = scope.fallbackCount == 1 ? "option" : "option\(scope.fallbackCount)"
        if configuration.names["\(scope.path).\(proposed)"] == nil {
            let context = node.map { "  — for: \($0.ebnf)" } ?? ""
            warnings.append("\(scope.path).\(proposed): no name could be derived; add an override to codegen.json\(context)")
        }
        return proposed
    }

    func nestedTypeName(forMember member: String, in owner: TypeDecl) -> String {
        var name = Naming.capitalized(member)
        if reservedTypeNames.contains(name) || name == owner.name || owner.nested.contains(where: { $0.name == name }) {
            name += "Kind"
        }
        return name
    }

    /// Fields and build template for a sequence of nodes.
    func members(_ items: [Node], scope: inout Scope, hintForSingleChoice: String? = nil) -> ([Field], [Template]) {
        var fields: [Field] = []
        var body: [Template] = []
        var precedingKeywords: [String] = []
        let storedCount = items.filter(\.isStored).count

        for item in items {
            switch item {
                case .text(let t):
                    body.append(.text(t))
                    // Name what follows after the closest keywords: `FILTER ( WHERE expr` -> `where`,
                    // `CHECK ( expr` -> `check`.
                    let afterPunctuation = t.reversed().prefix { Naming.keywordWords([$0]).count > 0 }.reversed()
                    precedingKeywords = Naming.keywordWords(afterPunctuation.isEmpty ? t : Array(afterPunctuation))
                    if afterPunctuation.isEmpty, let lastWordIndex = t.lastIndex(where: { !Naming.keywordWords([$0]).isEmpty }) {
                        let run = t[...lastWordIndex].reversed().prefix { !Naming.keywordWords([$0]).isEmpty }.reversed()
                        precedingKeywords = Naming.keywordWords(Array(run))
                    }
                    continue

                case .optional(let inner) where !inner.isStored:
                    let texts = inner.allTexts
                    let name = uniqueName(Naming.name(forTexts: texts) ?? fallbackName(scope: &scope), scope: &scope)
                    fields.append(Field(name: name, type: "Bool", defaultValue: "false"))
                    body.append(.flag(name, texts))

                case .optional(let inner):
                    let innerItems = inner.items
                    let innerStored = innerItems.filter(\.isStored)
                    let singleNonOptional: Bool = { if innerStored.count == 1, case .optional = innerStored[0] { return false }; return innerStored.count == 1 }()
                    if singleNonOptional, let index = innerItems.firstIndex(of: innerStored[0]) {
                        let leading = Naming.keywordWords(innerItems[..<index].flatMap(\.allTexts))
                        let hint = leading.isEmpty ? precedingKeywords : leading
                        let (name, type, target) = storage(for: innerStored[0], hint: hint, scope: &scope,
                                                           fallbackHint: storedCount == 1 ? hintForSingleChoice : nil)
                        let optionalType = type.hasSuffix("?") ? type : type + "?"
                        fields.append(Field(name: name, type: optionalType, defaultValue: "nil", target: target))
                        var innerBody: [Template] = []
                        for n in innerItems {
                            if case .text(let t) = n { innerBody.append(.text(t)) }
                            else if case .list(_, let sep, let nonEmpty, let leading) = n {
                                innerBody.append(.list(name, separator: sep.isEmpty ? nil : sep.joined(separator: " "), nonEmpty: nonEmpty, leading: leading))
                            } else { innerBody.append(.value(name)) }
                        }
                        body.append(.optional(name, innerBody))
                    } else {
                        // several stored values in an optional group: a nested struct
                        let leading = Naming.keywordWords(innerItems.prefix { !$0.isStored }.flatMap(\.allTexts))
                        let proposed = !leading.isEmpty ? Naming.lowerCamel(leading)
                            : !precedingKeywords.isEmpty ? Naming.lowerCamel(precedingKeywords)
                            : firstValueName(innerItems) ?? fallbackName(scope: &scope, for: item)
                        let name = uniqueName(proposed, scope: &scope)
                        let nested = nestedStruct(named: nestedTypeName(forMember: name, in: scope.owner), items: innerItems, in: scope.owner)
                        fields.append(Field(name: name, type: nested.name + "?", defaultValue: "nil", target: nested.path))
                        body.append(.value(name))
                    }

                case .list(_, let sep, let nonEmpty, let leading):
                    let (name, type, _) = storage(for: item, hint: precedingKeywords, scope: &scope, fallbackHint: nil)
                    fields.append(Field(name: name, type: type, defaultValue: nonEmpty ? nil : "[]", nonEmptyList: nonEmpty))
                    body.append(.list(name, separator: sep.isEmpty ? nil : sep.joined(separator: " "), nonEmpty: nonEmpty, leading: leading))

                default:
                    let (name, type, target) = storage(for: item, hint: precedingKeywords, scope: &scope,
                                                       fallbackHint: storedCount == 1 ? hintForSingleChoice : nil)
                    fields.append(Field(name: name, type: type, defaultValue: type.hasSuffix("?") ? "nil" : nil, target: target))
                    body.append(.value(name))
            }
            precedingKeywords = []
        }
        return (fields, body)
    }

    /// The member name and Swift type that store one node, creating nested types as needed, and the
    /// path of the generated type stored inline (for cycle detection).
    func storage(for node: Node, hint: [String], scope: inout Scope, fallbackHint: String?) -> (String, String, String?) {
        switch node {
            case .value(let symbol, let isReference):
                let type = valueType(symbol: symbol, isReference: isReference)
                var base = isReference ? Naming.lowerFirst(baseName(type)) : Naming.lowerCamel(Naming.words(symbol))
                // `expression` says nothing; `WHERE expr` -> `where`, `HAVING expr` -> `having`.
                if baseName(type) == "Expression", !hint.isEmpty { base = Naming.lowerCamel(hint) }
                let target = isReference && generatedRules.contains(symbol) ? typeName(forRule: symbol) : nil
                return (uniqueName(base, scope: &scope), type, target)

            case .choice(let alternatives):
                if let existing = keywordEnum(for: alternatives) {
                    return (uniqueName(Naming.lowerFirst(existing), scope: &scope), existing, nil)
                }
                let proposed = !hint.isEmpty ? Naming.lowerCamel(hint) : (fallbackHint ?? fallbackName(scope: &scope, for: node))
                let name = uniqueName(proposed, scope: &scope)
                let nested = TypeDecl(name: nestedTypeName(forMember: name, in: scope.owner),
                                      path: "\(scope.owner.path).\(nestedTypeName(forMember: name, in: scope.owner))",
                                      grammar: node.ebnf)
                nested.kind = enumeration(alternatives, in: nested, prefix: [], suffix: [])
                scope.owner.nested.append(nested)
                return (name, nested.name, nested.path)

            case .list(let element, _, let nonEmpty, _):
                let elementType: String
                let name: String
                if case .value(let symbol, let isReference) = element {
                    elementType = valueType(symbol: symbol, isReference: isReference)
                    // A multi-word clause names the list (`GROUP BY` -> `groupBy`); otherwise the element type does.
                    let proposed = hint.count > 1 ? Naming.lowerCamel(hint)
                        : (isReference ? Naming.lowerFirst(baseName(elementType)) : Naming.lowerCamel(Naming.words(symbol))) + "s"
                    name = uniqueName(proposed, scope: &scope)
                } else {
                    name = uniqueName(!hint.isEmpty ? Naming.lowerCamel(hint) : fallbackName(scope: &scope, for: node), scope: &scope)
                    let elementName = nestedTypeName(forMember: name + "Element", in: scope.owner)
                    if case .choice(let alternatives) = element {
                        let nested = TypeDecl(name: elementName, path: "\(scope.owner.path).\(elementName)", grammar: element.ebnf)
                        nested.kind = enumeration(alternatives, in: nested, prefix: [], suffix: [])
                        scope.owner.nested.append(nested)
                    } else {
                        _ = nestedStruct(named: elementName, items: element.items, in: scope.owner)
                    }
                    elementType = elementName
                }
                // Lists store their elements on the heap, so they never close a cycle.
                return (name, nonEmpty ? "List<\(elementType)>" : "[\(elementType)]", nil)

            case .sequence(let items):
                let name = uniqueName(!hint.isEmpty ? Naming.lowerCamel(hint) : fallbackName(scope: &scope, for: node), scope: &scope)
                let nested = nestedStruct(named: nestedTypeName(forMember: name, in: scope.owner), items: items, in: scope.owner)
                return (name, nested.name, nested.path)

            case .optional, .text:
                fatalError("handled by members(_:scope:)")
        }
    }

    func nestedStruct(named name: String, items: [Node], in owner: TypeDecl) -> TypeDecl {
        let nested = TypeDecl(name: name, path: "\(owner.path).\(name)", grammar: Node.sequence(items).ebnf)
        var scope = Scope(owner: nested)
        let (fields, body) = members(items, scope: &scope)
        nested.kind = .structure(fields: fields, body: body)
        owner.nested.append(nested)
        return nested
    }

    // MARK: Enums

    func enumeration(_ alternatives: [Node], in decl: TypeDecl, prefix: [String], suffix: [String]) -> TypeDecl.Kind {
        var caseScope = Scope(owner: decl)
        var cases: [Case] = []
        for alternative in alternatives {
            let items = alternative.items
            let firstTexts = items.first { if case .text = $0 { return true } else { return false } }?.allTexts ?? []
            let stored = items.filter(\.isStored)
            var proposed = Naming.keywordWords(firstTexts).isEmpty ? nil : Naming.lowerCamel(Naming.keywordWords(firstTexts))
            if proposed == nil, stored.count == 1, case .value(let symbol, let isReference) = stored[0] {
                let type = valueType(symbol: symbol, isReference: isReference)
                proposed = isReference ? Naming.lowerFirst(baseName(type)) : Naming.lowerCamel(Naming.words(symbol))
            }
            if proposed == nil { proposed = firstValueName(items) }
            if proposed == nil { proposed = Naming.name(forTexts: alternative.allTexts) }
            let caseName = uniqueName(proposed ?? fallbackName(scope: &caseScope, for: alternative), scope: &caseScope)
            var payloadScope = Scope(owner: decl, path: "\(decl.path).\(caseName)")
            let (payload, body) = members(items, scope: &payloadScope, hintForSingleChoice: caseName)
            cases.append(Case(name: caseName, payload: payload, body: body, grammar: alternative.ebnf))
        }
        return .enumeration(cases: cases, prefix: prefix, suffix: suffix)
    }

    /// The member name of the first value in a sequence, preferring required values over optional ones,
    /// e.g. `expr [ [ 'AS' ] column-alias ]` -> `expression`, `[ 'AS' ] column-alias` -> `columnAlias`.
    func firstValueName(_ items: [Node]) -> String? {
        func name(_ n: Node) -> String? {
            guard case .value(let symbol, let isReference) = n else { return nil }
            if isReference {
                // Mapped references (e.g. `expr` -> `Expression`) are named after their type.
                if generatedRules.contains(symbol) { return Naming.lowerFirst(typeName(forRule: symbol)) }
                if let mapped = configuration.references[symbol] { return Naming.lowerFirst(baseName(mapped)) }
            }
            return Naming.lowerCamel(Naming.words(symbol))
        }
        if let required = items.lazy.compactMap(name).first { return required }
        for case .optional(let inner) in items { if let n = inner.items.lazy.compactMap(name).first { return n } }
        return nil
    }

    func keywordEnum(for alternatives: [Node]) -> String? {
        let keys = alternatives.map { $0.isStored ? nil : $0.allTexts.joined(separator: " ") }
        guard !keys.contains(nil) else { return nil }
        return configuration.keywordEnums[keys.map { $0! }.joined(separator: "|")]
    }

    // MARK: Values

    func valueType(symbol: String, isReference: Bool) -> String {
        if isReference {
            if generatedRules.contains(symbol) {
                return typeName(forRule: symbol) + (nullableRules.contains(symbol) ? "?" : "")
            }
            if let mapped = configuration.references[symbol] { return mapped }
            let guess = Naming.typeName(forRule: symbol)
            warnings.append("reference \(symbol): not generated and not in codegen.json references; assuming \(guess)")
            return guess
        }
        if let mapped = configuration.tokens[symbol] { return mapped }
        warnings.append("token \(symbol): not in codegen.json tokens; assuming Name<Any>")
        return "Name<Any>"
    }

    /// `Name<Collation>?` -> `Name`, `ConflictClause?` -> `ConflictClause`
    func baseName(_ type: String) -> String {
        var t = type
        if t.hasSuffix("?") { t.removeLast() }
        if let angle = t.firstIndex(of: "<") { t = String(t[..<angle]) }
        return t
    }
}
