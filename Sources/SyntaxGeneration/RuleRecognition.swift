import GrammarExtraction

/// Replaces parts of a rule that describe exactly the same syntax as another generated rule with a
/// reference to that rule. Diagrams sometimes draw another rule's contents inline (`select-stmt`
/// draws `select-core` twice); referencing the rule makes the generated types share one type.
enum RuleRecognition {

    struct Candidate {
        var name: String
        var expression: GrammarExpression
        var symbols: Set<String>
        var size: Int
    }

    /// - Returns: the rewritten expression and the names of the rules it now references.
    static func recognize(in expression: GrammarExpression, of rule: String, candidates: [Candidate])
        -> (GrammarExpression, Set<String>) {
        var used: Set<String> = []
        let ordered = candidates.filter { $0.name != rule && $0.size >= 2 }.sorted { $0.size > $1.size }
        func rewrite(_ e: GrammarExpression, whole: Bool = true) -> GrammarExpression {
            if whole, let match = matching(e) { used.insert(match); return .symbol(match) }
            switch e {
                case .empty, .symbol: return e
                case .repetition(let body): return .repetition(rewrite(body))
                case .choice(let items):
                    // A candidate that is itself a choice matches when each of its alternatives is one of ours.
                    var remaining = items
                    for c in ordered {
                        guard case .choice(let wanted) = c.expression, wanted.count >= 2, !wanted.contains(.empty) else { continue }
                        var taken: [Int] = []
                        for alternative in wanted {
                            guard let i = remaining.indices.first(where: { index in
                                !taken.contains(index) && remaining[index].symbols == alternative.symbols
                                    && remaining[index].isEquivalent(to: alternative)
                            }) else { taken = []; break }
                            taken.append(i)
                        }
                        guard !taken.isEmpty, whole || taken.count < remaining.count else { continue }
                        let first = taken.min()!
                        var next: [GrammarExpression] = []
                        for (i, item) in remaining.enumerated() where !taken.contains(i) || i == first {
                            next.append(i == first ? .symbol(c.name) : item)
                        }
                        used.insert(c.name)
                        remaining = next
                    }
                    let rewritten = remaining.map { $0 == .empty || isSymbol($0) ? $0 : rewrite($0) }
                    return rewritten.count == 1 ? rewritten[0] : .choice(rewritten)
                case .sequence(let items):
                    // Contiguous runs inside a sequence, longest first.
                    var out: [GrammarExpression] = []
                    var i = 0
                    outer: while i < items.count {
                        for length in stride(from: items.count - i, through: 2, by: -1) where whole || !(i == 0 && length == items.count) {
                            if let match = matching(.sequence(Array(items[i..<(i + length)]))) {
                                used.insert(match); out.append(.symbol(match)); i += length
                                continue outer
                            }
                        }
                        out.append(rewrite(items[i])); i += 1
                    }
                    return out.count == 1 ? out[0] : .sequence(out)
            }
        }
        func isSymbol(_ e: GrammarExpression) -> Bool { if case .symbol = e { return true } else { return false } }
        func matching(_ e: GrammarExpression) -> String? {
            guard case .symbol = e else {
                let symbols = e.symbols
                for c in ordered where c.symbols == symbols && e.isEquivalent(to: c.expression) { return c.name }
                return nil
            }
            return nil
        }
        // The whole rule matching another rule is an alias, not an inlined copy: leave the top level alone.
        return (rewrite(expression, whole: false), used)
    }

    static func candidate(_ rule: GrammarRule) -> Candidate {
        Candidate(name: rule.name, expression: rule.expression, symbols: rule.expression.symbols, size: rule.expression.symbolCount)
    }
}

extension GrammarExpression {
    var symbols: Set<String> {
        switch self {
            case .empty: return []
            case .symbol(let s): return [s]
            case .sequence(let items), .choice(let items): return items.reduce(into: []) { $0.formUnion($1.symbols) }
            case .repetition(let body): return body.symbols
        }
    }

    var symbolCount: Int {
        switch self {
            case .empty: return 0
            case .symbol: return 1
            case .sequence(let items), .choice(let items): return items.reduce(0) { $0 + $1.symbolCount }
            case .repetition(let body): return body.symbolCount
        }
    }
}
