/// A grammar expression over diagram bubble labels.
public indirect enum GrammarExpression: Hashable, Sendable {
    case empty
    case symbol(String)
    case sequence([GrammarExpression])
    case choice([GrammarExpression])
    case repetition(GrammarExpression)   // zero or more
}

// MARK: Smart constructors (simplifying)

extension GrammarExpression {

    /// The elements of a sequence (an empty expression has none; anything else is a 1-element sequence).
    var sequenceParts: [GrammarExpression] {
        switch self {
            case .sequence(let items): return items
            case .empty: return []
            default: return [self]
        }
    }

    static func makeSequence(_ xs: [GrammarExpression?]) -> GrammarExpression? {
        var out: [GrammarExpression] = []
        for x in xs {
            guard let x else { return nil }
            switch x {
                case .empty: continue
                case .sequence(let items): out.append(contentsOf: items)
                default: out.append(x)
            }
        }
        // { A s } A  ->  A { s A }
        var changed = true
        while changed {
            changed = false
            for i in 0..<max(0, out.count - 1) {
                guard case .repetition(let body) = out[i] else { continue }
                let bodyParts: [GrammarExpression]
                if case .sequence(let items) = body { bodyParts = items } else { bodyParts = [body] }
                let n = bodyParts.count
                guard n > 1 else { continue }
                for k in 1..<n {
                    let head = Array(bodyParts[..<k])
                    guard i + 1 + k <= out.count, Array(out[(i + 1)..<(i + 1 + k)]) == head else { continue }
                    let rotated = Array(bodyParts[k...]) + head
                    out.replaceSubrange(i..<(i + 1 + k), with: head + [.repetition(.sequence(rotated))])
                    changed = true
                    break
                }
                if changed { break }
            }
        }
        if out.isEmpty { return .empty }
        return out.count == 1 ? out[0] : .sequence(out)
    }

    static func makeChoice(_ xs: [GrammarExpression?]) -> GrammarExpression? {
        var items: [GrammarExpression] = []
        for x in xs {
            guard let x else { continue }
            let options: [GrammarExpression]
            if case .choice(let alternatives) = x { options = alternatives } else { options = [x] }
            for y in options where !items.contains(y) { items.append(y) }
        }
        if items.isEmpty { return nil }
        if items.count == 1 { return items[0] }

        // X | X Y  ->  X [ Y ]      and      Y X | X  ->  [ Y ] X
        for i in items.indices {
            for j in items.indices where i != j {
                let p = items[i].sequenceParts, q = items[j].sequenceParts
                let merged: GrammarExpression?
                if !p.isEmpty, q.count > p.count, Array(q[..<p.count]) == p {
                    merged = makeSequence(p.map(Optional.some) + [makeChoice([.empty, makeSequence(q[p.count...].map(Optional.some))])])
                } else if !p.isEmpty, q.count > p.count, Array(q[(q.count - p.count)...]) == p {
                    merged = makeSequence([makeChoice([.empty, makeSequence(q[..<(q.count - p.count)].map(Optional.some))])] + p.map(Optional.some))
                } else {
                    continue
                }
                let rest = items.enumerated().filter { $0.offset != i && $0.offset != j }.map { Optional($0.element) }
                return makeChoice([merged] + rest)
            }
        }

        items = items.map { (item: $0, key: $0.ebnf) }
            .sorted { a, b in
                let ae = a.item == .empty, be = b.item == .empty
                if ae != be { return ae }
                return a.key.utf8.lexicographicallyPrecedes(b.key.utf8)
            }
            .map(\.item)
        // factor a common prefix / suffix out of the alternatives
        let parts = items.map(\.sequenceParts)
        var k = 0
        while parts.allSatisfy({ $0.count > k }) && parts.allSatisfy({ $0[k] == parts[0][k] }) { k += 1 }
        if k > 0 {
            return makeSequence(parts[0][..<k].map(Optional.some) + [makeChoice(parts.map { makeSequence($0[k...].map(Optional.some)) })])
        }
        k = 0
        while parts.allSatisfy({ $0.count > k }) && parts.allSatisfy({ $0[$0.count - 1 - k] == parts[0][parts[0].count - 1 - k] }) { k += 1 }
        if k > 0 {
            return makeSequence([makeChoice(parts.map { makeSequence($0[..<($0.count - k)].map(Optional.some)) })]
                                + parts[0][(parts[0].count - k)...].map(Optional.some))
        }
        return .choice(items)
    }

    static func makeRepetition(_ x: GrammarExpression?) -> GrammarExpression {
        guard let x, x != .empty else { return .empty }
        if case .choice(let items) = x, items.contains(.empty) {
            return makeRepetition(makeChoice(items.filter { $0 != .empty }))
        }
        if case .repetition = x { return x }
        return .repetition(x)
    }
}

// MARK: EBNF rendering

extension GrammarExpression {

    /// EBNF text: `( a | b )` choice, `[ a ]` optional, `{ a }` zero-or-more, `a+` one-or-more.
    public var ebnf: String {
        switch self {
            case .empty:
                return "ε"
            case .symbol(let v):
                if let first = v.unicodeScalars.first, first.properties.isLowercase,
                   v.unicodeScalars.allSatisfy({ $0 == "-" || $0.properties.isAlphabetic || $0.properties.numericType != nil }),
                   v.unicodeScalars.contains(where: { $0 != "-" }) {
                    return v
                }
                if v.contains("'") { return "\"\(v)\"" }
                return "'" + v.replacingOccurrences(of: "\\", with: "\\\\") + "'"
            case .sequence(let parts):
                var out: [String] = []
                var i = 0
                while i < parts.count {
                    let p = parts[i]
                    if i + 1 < parts.count, case .repetition(let body) = parts[i + 1], body == p {
                        if case .symbol = p { out.append("\(p.ebnf)+") } else { out.append("(\(p.ebnf))+") }
                        i += 2
                        continue
                    }
                    out.append(p.ebnf)
                    i += 1
                }
                return out.joined(separator: " ")
            case .choice(let items):
                if items.contains(.empty) {
                    let rest = items.filter { $0 != .empty }
                    let inner = rest.count > 1 ? GrammarExpression.makeChoice(rest)!.ebnf : rest[0].ebnf
                    return "[ \(inner) ]"
                }
                return "( " + items.map(\.ebnf).joined(separator: " | ") + " )"
            case .repetition(let body):
                return "{ \(body.ebnf) }"
        }
    }
}

// MARK: Conversion back to an automaton (for verification)

extension GrammarExpression {

    var language: Language {
        var a = Automaton()
        func build(_ x: GrammarExpression, _ from: Int, _ to: Int) {
            switch x {
                case .empty: a.addEpsilon(from, to)
                case .symbol(let v): a.add(from, label: v, to)
                case .sequence(let items):
                    var current = from
                    for item in items {
                        let next = a.newState()
                        build(item, current, next)
                        current = next
                    }
                    a.addEpsilon(current, to)
                case .choice(let items):
                    for item in items { build(item, from, to) }
                case .repetition(let body):
                    let m = a.newState()
                    a.addEpsilon(from, m); a.addEpsilon(m, to)
                    build(body, m, m)
            }
        }
        let s = a.newState(), e = a.newState()
        build(self, s, e)
        return Language(automaton: a, start: s, accept: e)
    }
}
