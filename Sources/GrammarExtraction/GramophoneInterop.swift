import Gramophone

// Conversion between `GrammarExpression` and Gramophone's `Rule.Kind`, and reading/writing grammar
// files through Gramophone's EBNF printer and parser.
//
// Naming: diagram names use hyphens (`frame-spec`), which Gramophone's lexer reads as the exception
// operator, so names are written with underscores (`frame_spec`) and converted back on read.
// Keywords and punctuation are quoted terminals; diagram and token names are references.

extension GrammarExpression {

    /// The expression as a Gramophone rule body.
    ///
    /// - Parameter isFixedToken: whether a symbol is a keyword or punctuation (written as a quoted terminal).
    public func gramophoneKind(isFixedToken: (String) -> Bool) -> Rule.Kind {
        switch self {
            case .empty:
                return .epsilon
            case .symbol(let s):
                return isFixedToken(s) ? .terminalString(s) : .reference(GrammarFile.fileName(for: s))
            case .sequence(let items):
                return .concatenation(items.map { $0.gramophoneKind(isFixedToken: isFixedToken) })
            case .choice(let items):
                let rest = items.filter { $0 != .empty }
                let kinds = rest.map { $0.gramophoneKind(isFixedToken: isFixedToken) }
                let body: Rule.Kind = kinds.count == 1 ? kinds[0] : .alternation(kinds)
                return items.contains(.empty) ? .optional(body) : body
            case .repetition(let body):
                return .occurrence(body.gramophoneKind(isFixedToken: isFixedToken), frequency: .zeroOrMore)
        }
    }

    /// Converts a Gramophone rule body back. Only the constructs this module writes are supported.
    public init(gramophone kind: Rule.Kind) throws(GrammarFile.Error) {
        switch kind {
            case .terminalString(""):
                self = .empty
            case .terminalString(let s):
                self = .symbol(s)
            case .reference(let name):
                self = .symbol(GrammarFile.diagramName(for: name))
            case .grouping(let inner):
                self = try GrammarExpression(gramophone: inner)
            case .concatenation(let items):
                var parts: [GrammarExpression] = []
                for item in items {
                    let x = try GrammarExpression(gramophone: item)
                    if case .sequence(let nested) = x { parts += nested } else if x != .empty { parts.append(x) }
                }
                self = parts.isEmpty ? .empty : parts.count == 1 ? parts[0] : .sequence(parts)
            case .alternation(let items):
                var alternatives: [GrammarExpression] = []
                for item in items {
                    let x = try GrammarExpression(gramophone: item)
                    if case .choice(let nested) = x { alternatives += nested } else { alternatives.append(x) }
                }
                self = .choice(alternatives)
            case .occurrence(let inner, let frequency):
                let x = try GrammarExpression(gramophone: inner)
                switch frequency {
                    case .zeroOrOne:
                        if case .choice(let alternatives) = x { self = .choice([.empty] + alternatives.filter { $0 != .empty }) }
                        else { self = .choice([.empty, x]) }
                    case .zeroOrMore:
                        self = .repetition(x)
                    case .oneOrMore:
                        self = .sequence([x, .repetition(x)])
                }
            default:
                throw .unsupported(String(describing: kind))
        }
    }

    /// Whether two expressions describe exactly the same sequences of symbols.
    public func isEquivalent(to other: GrammarExpression) -> Bool {
        Language.equivalent(language, other.language)
    }
}

/// A grammar file (`Grammar/sqlite.ebnf`), written and read with Gramophone.
public enum GrammarFile {

    public enum Error: Swift.Error, CustomStringConvertible {
        case parse(String)
        case unsupported(String)
        /// A rule read back from the file differs from the rule that was written.
        case roundTrip(rule: String)

        public var description: String {
            switch self {
                case .parse(let message): return "could not parse grammar: \(message)"
                case .unsupported(let construct): return "unsupported EBNF construct: \(construct)"
                case .roundTrip(let rule): return "\(rule): the rule read back from the EBNF differs from the extracted rule"
            }
        }
    }

    /// Gramophone names may only contain letters, digits and `_`. Hyphens become `_`; any other
    /// character `c` becomes `_U` + four hex digits + `_` (e.g. `*` -> `_U002A_`). Diagram names are
    /// lowercase, so `_U` never arises from a hyphen and the encoding is reversible.
    static func fileName(for diagramName: String) -> String {
        var out = ""
        for scalar in diagramName.unicodeScalars {
            if scalar == "-" {
                out += "_"
            } else if scalar.isASCII, scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) {
                out.unicodeScalars.append(scalar)
            } else {
                let hex = String(scalar.value, radix: 16, uppercase: true)
                out += "_U" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex + "_"
            }
        }
        return out
    }

    static func diagramName(for fileName: String) -> String {
        let scalars = Array(fileName.unicodeScalars)
        var out = String.UnicodeScalarView()
        var i = 0
        while i < scalars.count {
            if scalars[i] == "_", i + 6 < scalars.count, scalars[i + 1] == "U", scalars[i + 6] == "_",
               let value = UInt32(String(String.UnicodeScalarView(scalars[(i + 2)..<(i + 6)])), radix: 16),
               let scalar = Unicode.Scalar(value) {
                out.append(scalar)
                i += 7
            } else {
                out.append(scalars[i] == "_" ? "-" : scalars[i])
                i += 1
            }
        }
        return String(out)
    }

    /// Renders rules as EBNF using Gramophone's printer: one `name = body;` rule per line.
    public static func text(for rules: [GrammarRule]) -> String {
        rules.map { rule -> String in
            let kind = rule.expression.gramophoneKind { symbol in rule.symbolKinds[symbol] != .reference && isFixed(symbol) }
            return Rule(name: fileName(for: rule.name), kind: kind).description + "\n\n"
        }.joined()
    }

    /// Parses EBNF with Gramophone. Symbols that name a rule in the file are references to it;
    /// other names are lexical tokens; quoted strings are keywords and punctuation.
    public static func rules(from text: String) throws(Error) -> [GrammarRule] {
        let parsed: [Rule]
        switch BNFParser().parse(text) {
            case .success(let rules): parsed = rules
            case .failure(let error): throw .parse(String(describing: error))
        }
        let defined = Set(parsed.map { diagramName(for: $0.name) })
        var result: [GrammarRule] = []
        for rule in parsed {
            let expression = try GrammarExpression(gramophone: rule.kind)
            var kinds: [String: GrammarRule.SymbolKind] = [:]
            collectReferences(rule.kind) { name in
                kinds[name] = defined.contains(name) ? .reference : .terminal
            }
            result.append(GrammarRule(name: diagramName(for: rule.name), expression: expression, symbolKinds: kinds))
        }
        return result
    }

    /// Writes `rules`, reads them back, and checks every rule round-trips to the same language.
    /// Returns the text and the rules as read back.
    public static func roundTrip(_ rules: [GrammarRule]) throws(Error) -> (text: String, rules: [GrammarRule]) {
        let text = text(for: rules)
        let readBack = try self.rules(from: text)
        let byName = Dictionary(uniqueKeysWithValues: readBack.map { ($0.name, $0) })
        for rule in rules {
            guard let other = byName[rule.name], rule.expression.isEquivalent(to: other.expression) else {
                throw .roundTrip(rule: rule.name)
            }
        }
        return (text, readBack)
    }

    private static func isFixed(_ symbol: String) -> Bool {
        guard let first = symbol.unicodeScalars.first else { return true }
        return !first.properties.isLowercase
    }

    private static func collectReferences(_ kind: Rule.Kind, _ body: (String) -> Void) {
        switch kind {
            case .reference(let name): body(diagramName(for: name))
            case .concatenation(let items), .alternation(let items): items.forEach { collectReferences($0, body) }
            case .occurrence(let inner, _), .grouping(let inner): collectReferences(inner, body)
            case .exception(let a, let b): collectReferences(a, body); collectReferences(b, body)
            default: break
        }
    }
}
