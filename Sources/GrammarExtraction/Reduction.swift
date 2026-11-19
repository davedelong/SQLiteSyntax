extension Language {

    /// Converts the automaton to a grammar expression by state elimination directly on
    /// the diagram's own graph, which preserves the nesting the diagram was drawn with.
    ///
    /// Elimination order is deterministic: cheapest state first (in-degree × out-degree,
    /// then states without self-loops), ties broken by state number (ascending, or
    /// descending when `preferHigherStates` is set).
    func structuralExpression(preferHigherStates: Bool = false) -> GrammarExpression? {
        let a = automaton
        let S = a.stateCount, F = a.stateCount + 1
        struct Edge: Hashable { var from: Int; var to: Int }
        var R: [Edge: GrammarExpression] = [:]
        var nodes = Set<Int>()
        for (from, targets) in a.epsilon.enumerated() {
            for to in targets {
                if from != to { R[Edge(from: from, to: to)] = GrammarExpression.makeChoice([R[Edge(from: from, to: to)], .empty]) }
                nodes.formUnion([from, to])
            }
        }
        for (from, ts) in a.transitions.enumerated() {
            for t in ts {
                let e = Edge(from: from, to: t.target)
                R[e] = GrammarExpression.makeChoice([R[e], .symbol(t.label)])
                nodes.formUnion([from, t.target])
            }
        }
        R[Edge(from: S, to: start)] = .empty
        R[Edge(from: accept, to: F)] = .empty
        nodes.formUnion([start, accept])

        // Drop states that are unreachable from S or cannot reach F.
        var succ: [Int: [Int]] = [:], pred: [Int: [Int]] = [:]
        for e in R.keys { succ[e.from, default: []].append(e.to); pred[e.to, default: []].append(e.from) }
        func reach(_ x: Int, _ next: [Int: [Int]]) -> Set<Int> {
            var seen: Set<Int> = [x], stack = [x]
            while let y = stack.popLast() {
                for z in next[y] ?? [] where seen.insert(z).inserted { stack.append(z) }
            }
            return seen
        }
        let live = reach(S, succ).intersection(reach(F, pred))
        R = R.filter { live.contains($0.key.from) && live.contains($0.key.to) }
        var remaining = nodes.filter { live.contains($0) }

        // Adjacency, kept in sync with R.
        var outgoing: [Int: Set<Int>] = [:], incoming: [Int: Set<Int>] = [:]
        for e in R.keys { outgoing[e.from, default: []].insert(e.to); incoming[e.to, default: []].insert(e.from) }
        func ins(_ k: Int) -> [Int] { (incoming[k] ?? []).filter { $0 != k }.sorted() }
        func outs(_ k: Int) -> [Int] { (outgoing[k] ?? []).filter { $0 != k }.sorted() }

        while !remaining.isEmpty {
            func degree(_ set: Set<Int>?, _ k: Int) -> Int { (set?.count ?? 0) - ((set?.contains(k) ?? false) ? 1 : 0) }
            var k = -1
            var bestKey = (cost: Int.max, loop: true)
            for x in remaining {
                let key = (cost: degree(incoming[x], x) * degree(outgoing[x], x), loop: R[Edge(from: x, to: x)] != nil)
                let better: Bool
                if k < 0 || key.cost != bestKey.cost { better = k < 0 || key.cost < bestKey.cost }
                else if key.loop != bestKey.loop { better = !key.loop }
                else { better = preferHigherStates ? x > k : x < k }
                if better { k = x; bestKey = key }
            }
            remaining.remove(k)
            let loop = GrammarExpression.makeRepetition(R[Edge(from: k, to: k)])
            let I = ins(k), O = outs(k)
            for from in I {
                for to in O {
                    let e = Edge(from: from, to: to)
                    let through = GrammarExpression.makeSequence([R[Edge(from: from, to: k)], loop, R[Edge(from: k, to: to)]])
                    if let value = GrammarExpression.makeChoice([R[e], through]) {
                        R[e] = value
                        outgoing[from, default: []].insert(to); incoming[to, default: []].insert(from)
                    }
                }
            }
            for x in outgoing[k] ?? [] { R[Edge(from: k, to: x)] = nil; incoming[x]?.remove(k) }
            for x in incoming[k] ?? [] { R[Edge(from: x, to: k)] = nil; outgoing[x]?.remove(k) }
            outgoing[k] = nil; incoming[k] = nil
        }
        return R[Edge(from: S, to: F)]
    }
}

extension GrammarExpression {

    /// Every `.choice` node, addressed by a path of child indexes.
    fileprivate func choicePaths(_ prefix: [Int] = []) -> [[Int]] {
        switch self {
            case .empty, .symbol: return []
            case .repetition(let body): return body.choicePaths(prefix + [0])
            case .sequence(let items):
                return items.enumerated().flatMap { $0.element.choicePaths(prefix + [$0.offset]) }
            case .choice(let items):
                return [prefix] + items.enumerated().flatMap { $0.element.choicePaths(prefix + [$0.offset]) }
        }
    }

    fileprivate func modifying(at path: ArraySlice<Int>, _ change: (GrammarExpression) -> GrammarExpression) -> GrammarExpression {
        guard let i = path.first else { return change(self) }
        switch self {
            case .repetition(let body): return .repetition(body.modifying(at: path.dropFirst(), change))
            case .sequence(var items): items[i] = items[i].modifying(at: path.dropFirst(), change); return .sequence(items)
            case .choice(var items): items[i] = items[i].modifying(at: path.dropFirst(), change); return .choice(items)
            default: return self
        }
    }

    /// Drops choice alternatives that the rest of the expression already covers, keeping `reference`'s language.
    func removingRedundantAlternatives(matching reference: Language) -> GrammarExpression {
        var current = self
        var changed = true
        while changed {
            changed = false
            search: for path in current.choicePaths() {
                guard case .choice(let items)? = current.node(at: path[...]) else { continue }
                for i in items.indices {
                    var rest = items; rest.remove(at: i)
                    let replacement: GrammarExpression = rest.count == 1 ? rest[0] : .choice(rest)
                    let candidate = current.modifying(at: path[...]) { _ in replacement }
                    if Language.equivalent(reference, candidate.language) {
                        current = candidate
                        changed = true
                        break search
                    }
                }
            }
        }
        return current
    }

    fileprivate func node(at path: ArraySlice<Int>) -> GrammarExpression? {
        guard let i = path.first else { return self }
        switch self {
            case .repetition(let body): return body.node(at: path.dropFirst())
            case .sequence(let items), .choice(let items): return items.indices.contains(i) ? items[i].node(at: path.dropFirst()) : nil
            default: return nil
        }
    }
}
