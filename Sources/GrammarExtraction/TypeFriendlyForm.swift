extension GrammarExpression {

    /// A rewrite of the expression that maps more directly onto Swift types, with the same language.
    ///
    /// The default simplifier factors shared trailing keywords out of alternatives to keep the text short,
    /// e.g. `( 'CROSS' | [ 'NATURAL' ] … ) 'JOIN'`. For code generation each alternative should be one
    /// enum case, so a choice followed only by fixed tokens is distributed back over its alternatives:
    /// `'CROSS' 'JOIN' | [ 'NATURAL' ] … 'JOIN'`. Nested choices are flattened into their parent.
    ///
    /// - Parameter isFixedToken: whether a symbol is a keyword or punctuation (stores no value).
    public func typeFriendlyForm(isFixedToken: (String) -> Bool) -> GrammarExpression {
        let result = distributed(isFixedToken)
        precondition(Language.equivalent(language, result.language), "type-friendly rewrite changed the language")
        return result
    }

    private func distributed(_ fixed: (String) -> Bool) -> GrammarExpression {
        switch self {
            case .empty, .symbol:
                return self
            case .repetition(let body):
                return .repetition(body.distributed(fixed))
            case .choice(let items):
                let all = GrammarExpression.flattenedAlternatives(items.map { $0.distributed(fixed) })
                if all.contains(.empty) {
                    // [ … ]: factor the non-empty alternatives, keep the option of nothing
                    let rest = all.filter { $0 != .empty }
                    let inner = rest.count == 1 ? rest[0] : GrammarExpression.choice(rest).distributed(fixed)
                    return .choice([.empty, inner])
                }
                let alternatives = all
                // 'X' A | 'X' B  ->  'X' ( A | B )   when every alternative starts with the same fixed tokens
                let parts = alternatives.map(\.sequenceParts)
                var k = 0
                while alternatives.count > 1, parts.allSatisfy({ $0.count > k }),
                      parts[0][k].isFixed(fixed), parts.allSatisfy({ $0[k] == parts[0][k] }) {
                    k += 1
                }
                if k > 0 {
                    let rests = parts.map { p -> GrammarExpression in
                        let rest = Array(p[k...])
                        return rest.isEmpty ? .empty : rest.count == 1 ? rest[0] : .sequence(rest)
                    }
                    return .sequence(Array(parts[0][..<k]) + [GrammarExpression.choice(rests).distributed(fixed)])
                }
                return .choice(alternatives)
            case .sequence(let raw):
                let items = raw.map { $0.distributed(fixed) }
                // ( A | B ) 'X' 'Y'  ->  A 'X' 'Y' | B 'X' 'Y'
                if let first = items.first, case .choice(let alternatives) = first, !alternatives.contains(.empty),
                   items.count > 1, items.dropFirst().allSatisfy({ $0.isFixed(fixed) }) {
                    let tail = Array(items.dropFirst())
                    let expanded = alternatives.map { alternative -> GrammarExpression in
                        .sequence(alternative.sequenceParts + tail).distributed(fixed)
                    }
                    return .choice(GrammarExpression.flattenedAlternatives(expanded))
                }
                return .sequence(items)
        }
    }

    private static func flattenedAlternatives(_ items: [GrammarExpression]) -> [GrammarExpression] {
        var out: [GrammarExpression] = []
        for item in items {
            if case .choice(let nested) = item {
                for n in nested where !out.contains(n) { out.append(n) }
            } else if !out.contains(item) {
                out.append(item)
            }
        }
        return out
    }

    private func isFixed(_ fixed: (String) -> Bool) -> Bool {
        switch self {
            case .empty: return true
            case .symbol(let s): return fixed(s)
            case .sequence(let items): return items.allSatisfy { $0.isFixed(fixed) }
            default: return false
        }
    }
}
