import GrammarExtraction

/// Syntax SQLite accepts but its diagrams don't draw (from parse.y), added to a rule by replacing one
/// fragment with a wider one. Configured in `codegen.json` `grammarPatches`; the extracted grammar file
/// stays faithful to the diagrams.
public struct GrammarPatch: Decodable, Sendable {
    /// The diagram rule to patch, e.g. `pragma-value`.
    public var rule: String
    /// The fragment to replace, in the grammar file's EBNF (e.g. `'NOT', 'NULL', conflict_clause`).
    public var find: String
    /// What replaces it; should describe a superset of `find`'s syntax.
    public var replace: String
    /// Why: which SQLite syntax this admits.
    public var reason: String
}

enum GrammarPatching {

    static func fragment(_ text: String, defined: Set<String>) throws -> (GrammarExpression, [String: GrammarRule.SymbolKind]) {
        let rule = try GrammarFile.rules(from: "fragment = \(text);")[0]
        var kinds = rule.symbolKinds
        for symbol in kinds.keys where defined.contains(symbol) { kinds[symbol] = .reference }
        return (rule.expression, kinds)
    }

    /// Applies `patch` to `rule`; returns nil if the fragment was not found exactly once.
    static func apply(_ patch: GrammarPatch, to rule: GrammarRule, defined: Set<String>) throws -> GrammarRule? {
        let (find, _) = try fragment(patch.find, defined: defined)
        let (replacement, kinds) = try fragment(patch.replace, defined: defined)
        var count = 0
        func same(_ e: GrammarExpression) -> Bool {
            e == find || (e.symbols == find.symbols && e.symbolCount > 1 && e.isEquivalent(to: find))
        }
        func rewrite(_ e: GrammarExpression) -> GrammarExpression {
            if same(e) { count += 1; return replacement }
            switch e {
                case .empty, .symbol: return e
                case .repetition(let body): return .repetition(rewrite(body))
                case .choice(let items): return .choice(items.map(rewrite))
                case .sequence(let items):
                    // A contiguous run of a sequence may be the fragment.
                    let parts: [GrammarExpression]
                    if case .sequence(let p) = find { parts = p } else { parts = [find] }
                    var out: [GrammarExpression] = []
                    var i = 0
                    while i < items.count {
                        if parts.count > 1, i + parts.count <= items.count, Array(items[i..<(i + parts.count)]) == parts {
                            count += 1
                            if case .sequence(let r) = replacement { out += r } else { out.append(replacement) }
                            i += parts.count
                        } else {
                            out.append(rewrite(items[i])); i += 1
                        }
                    }
                    return .sequence(out)
            }
        }
        var patched = rule
        patched.expression = rewrite(rule.expression)
        guard count == 1 else { return nil }
        for (symbol, kind) in kinds where patched.symbolKinds[symbol] == nil { patched.symbolKinds[symbol] = kind }
        return patched
    }
}
