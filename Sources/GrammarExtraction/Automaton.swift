/// A fixed-width set of small integers.
struct BitSet: Hashable {
    private(set) var words: [UInt64]

    init(capacity: Int) { words = Array(repeating: 0, count: (capacity + 63) / 64) }

    func contains(_ i: Int) -> Bool { words[i >> 6] & (1 << UInt64(i & 63)) != 0 }

    @discardableResult
    mutating func insert(_ i: Int) -> Bool {
        let mask: UInt64 = 1 << UInt64(i & 63)
        if words[i >> 6] & mask != 0 { return false }
        words[i >> 6] |= mask
        return true
    }

    var isEmpty: Bool { words.allSatisfy { $0 == 0 } }

    func forEach(_ body: (Int) -> Void) {
        for (w, word) in words.enumerated() where word != 0 {
            var bits = word
            while bits != 0 {
                let b = bits.trailingZeroBitCount
                body(w * 64 + b)
                bits &= bits - 1
            }
        }
    }
}

/// A nondeterministic automaton with epsilon moves over string labels.
struct Automaton {
    private(set) var stateCount = 0
    /// epsilon[a] = targets, kept sorted and unique
    private(set) var epsilon: [[Int]] = []
    /// transitions[a] = (label, target), unique
    private(set) var transitions: [[(label: String, target: Int)]] = []

    mutating func newState() -> Int {
        epsilon.append([]); transitions.append([])
        stateCount += 1
        return stateCount - 1
    }

    mutating func addEpsilon(_ a: Int, _ b: Int) {
        guard !epsilon[a].contains(b) else { return }
        epsilon[a].append(b)
        epsilon[a].sort()
    }

    mutating func removeEpsilon(_ a: Int, _ b: Int) {
        epsilon[a].removeAll { $0 == b }
    }

    mutating func add(_ a: Int, label: String, _ b: Int) {
        guard !transitions[a].contains(where: { $0.label == label && $0.target == b }) else { return }
        transitions[a].append((label, b))
    }

    var alphabet: Set<String> {
        Set(transitions.flatMap { $0.map(\.label) })
    }

    var epsilonEdges: [(Int, Int)] {
        epsilon.enumerated().flatMap { (a, bs) in bs.map { (a, $0) } }
    }

    func closure(_ seed: [Int]) -> BitSet {
        var set = BitSet(capacity: stateCount)
        var stack: [Int] = []
        for s in seed where set.insert(s) { stack.append(s) }
        while let x = stack.popLast() {
            for y in epsilon[x] where set.insert(y) { stack.append(y) }
        }
        return set
    }

    func step(_ set: BitSet, _ label: String) -> BitSet {
        var next: [Int] = []
        set.forEach { x in
            for t in transitions[x] where t.label == label { next.append(t.target) }
        }
        return closure(next)
    }
}

/// An automaton together with its start and accepting state.
struct Language {
    var automaton: Automaton
    var start: Int
    var accept: Int

    /// The shortest label sequence accepted by exactly one of the two languages, or nil if they are equal.
    static func difference(_ l1: Language, _ l2: Language) -> [String]? {
        let sigma = l1.automaton.alphabet.union(l2.automaton.alphabet).sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        struct Pair: Hashable { var a: BitSet; var b: BitSet }
        let initial = Pair(a: l1.automaton.closure([l1.start]), b: l2.automaton.closure([l2.start]))
        var seen: Set<Pair> = [initial]
        var queue: [(Pair, [String])] = [(initial, [])]
        var head = 0
        while head < queue.count {
            let (pair, word) = queue[head]; head += 1
            if pair.a.contains(l1.accept) != pair.b.contains(l2.accept) { return word }
            for c in sigma {
                let next = Pair(a: l1.automaton.step(pair.a, c), b: l2.automaton.step(pair.b, c))
                if next.a.isEmpty && next.b.isEmpty { continue }
                if seen.insert(next).inserted { queue.append((next, word + [c])) }
            }
        }
        return nil
    }

    static func equivalent(_ l1: Language, _ l2: Language) -> Bool { difference(l1, l2) == nil }

    /// Greedily drops epsilon edges whose removal leaves the language unchanged.
    func pruned(reverseOrder: Bool = false) -> Language {
        var current = self
        let edges = automaton.epsilonEdges
        for (a, b) in reverseOrder ? edges.reversed() : edges {
            current.automaton.removeEpsilon(a, b)
            if !Language.equivalent(self, current) {
                current.automaton.addEpsilon(a, b)
            }
        }
        return current
    }
}
