import GrammarExtraction

/// A grammar expression lowered into the shapes the type generator works with.
indirect enum Node: Equatable {
    /// Fixed keywords and punctuation; emitted by `build`, never stored.
    case text([String])
    /// A stored value: a lexical token (`collation-name`) or a reference to another rule (`expr`).
    case value(symbol: String, isReference: Bool)
    case sequence([Node])
    case optional(Node)
    case choice([Node])
    /// `x { sep x }` (non-empty, with separator), `{ x }` (possibly empty), or `{ sep x }`
    /// (possibly empty, separator written before every item: `leading`).
    case list(Node, separator: [String], nonEmpty: Bool, leading: Bool = false)

    var items: [Node] {
        if case .sequence(let items) = self { return items }
        return [self]
    }

    /// Whether the node holds any data (as opposed to only fixed tokens).
    var isStored: Bool {
        switch self {
            case .text: return false
            case .sequence(let items): return items.contains { $0.isStored }
            default: return true
        }
    }

    /// All fixed tokens, for a node that stores nothing.
    var allTexts: [String] {
        switch self {
            case .text(let t): return t
            case .sequence(let items): return items.flatMap(\.allTexts)
            default: return []
        }
    }

    /// EBNF-like rendering for doc comments.
    var ebnf: String {
        switch self {
            case .text(let t): return t.map { "'\($0)'" }.joined(separator: " ")
            case .value(let s, _): return s
            case .sequence(let items): return items.map(\.ebnf).joined(separator: " ")
            case .optional(let n): return "[ \(n.ebnf) ]"
            case .choice(let alternatives): return "( " + alternatives.map(\.ebnf).joined(separator: " | ") + " )"
            case .list(let e, let sep, let nonEmpty, let leading):
                let s = sep.map { "'\($0)' " }.joined()
                return nonEmpty ? "\(e.ebnf) { \(s)\(e.ebnf) }" : leading ? "{ \(s)\(e.ebnf) }" : "{ \(e.ebnf) }"
        }
    }
}

/// Whether a diagram symbol is a keyword or punctuation (as opposed to a token like `table-name`).
func isFixedToken(_ symbol: String) -> Bool {
    guard let first = symbol.unicodeScalars.first else { return true }
    return !first.properties.isLowercase
}

private func parts(_ e: GrammarExpression) -> [GrammarExpression] {
    switch e {
        case .sequence(let items): return items
        case .empty: return []
        default: return [e]
    }
}

private func isFixed(_ e: GrammarExpression, _ kinds: [String: GrammarRule.SymbolKind]) -> Bool {
    if case .symbol(let s) = e { return kinds[s] != .reference && isFixedToken(s) }
    return false
}

func lower(_ e: GrammarExpression, kinds: [String: GrammarRule.SymbolKind]) -> Node {
    switch e {
        case .empty:
            return .sequence([])
        case .symbol(let s):
            if kinds[s] == .reference { return .value(symbol: s, isReference: true) }
            return isFixedToken(s) ? .text([s]) : .value(symbol: s, isReference: false)
        case .repetition(let body):
            // { sep x }: a list of x with the separator before each item.
            let bodyParts = parts(body)
            if bodyParts.count >= 2, bodyParts.dropLast().allSatisfy({ isFixed($0, kinds) }),
               case .symbol(let last) = bodyParts.last!, !isFixed(bodyParts.last!, kinds) {
                let sep = bodyParts.dropLast().compactMap { if case .symbol(let s) = $0 { return s } else { return nil } }
                return .list(lower(.symbol(last), kinds: kinds), separator: sep, nonEmpty: false, leading: true)
            }
            return .list(lower(body, kinds: kinds), separator: [], nonEmpty: false)
        case .choice(let items):
            if items.contains(.empty) {
                let rest = items.filter { $0 != .empty }
                return .optional(rest.count == 1 ? lower(rest[0], kinds: kinds) : lower(.choice(rest), kinds: kinds))
            }
            var alternatives: [Node] = []
            for item in items {
                let n = lower(item, kinds: kinds)
                if case .choice(let nested) = n { alternatives += nested } else { alternatives.append(n) }
            }
            return .choice(alternatives)
        case .sequence(let items):
            var out: [Node] = []
            var i = 0
            outer: while i < items.count {
                // A { sep A }  where A may span several items  ->  list
                for k in stride(from: items.count - i - 1, through: 1, by: -1) {
                    guard i + k < items.count, case .repetition(let body) = items[i + k] else { continue }
                    let element = Array(items[i..<(i + k)])
                    let bodyParts = parts(body)
                    guard bodyParts.count >= k, Array(bodyParts.suffix(k)) == element else { continue }
                    let separator = bodyParts.prefix(bodyParts.count - k)
                    guard separator.allSatisfy({ isFixed($0, kinds) }) else { continue }
                    let elementNode = lower(element.count == 1 ? element[0] : .sequence(element), kinds: kinds)
                    let sep = separator.compactMap { if case .symbol(let s) = $0 { return s } else { return nil } }
                    out.append(.list(elementNode, separator: sep, nonEmpty: true))
                    i += k + 1
                    continue outer
                }
                out.append(lower(items[i], kinds: kinds))
                i += 1
            }
            // flatten and merge adjacent fixed tokens
            var merged: [Node] = []
            for n in out.flatMap(\.items) {
                if case .text(let t) = n, case .text(let previous)? = merged.last {
                    merged[merged.count - 1] = .text(previous + t)
                } else {
                    merged.append(n)
                }
            }
            return merged.count == 1 ? merged[0] : .sequence(merged)
    }
}
