/// Breaks reference cycles between generated value types, which would otherwise have infinite size
/// (e.g. `select-stmt` → `select-core` → `table-or-subquery` → `select-stmt`).
///
/// Enums in a cycle become `indirect enum`, which stores their payloads on the heap. A cycle that runs
/// only through structs has no enum to mark, so one of its fields uses the `Indirect` property wrapper
/// (itself a one-case `indirect enum`).
enum Recursion {

    /// Marks indirect enums and boxed fields in place. Returns a description of each change.
    static func resolve(_ roots: [TypeDecl]) -> [String] {
        var all: [String: TypeDecl] = [:]
        func collect(_ d: TypeDecl) { all[d.path] = d; d.nested.forEach(collect) }
        roots.forEach(collect)
        var notes: [String] = []

        // 1. Enums on a cycle become indirect.
        for component in cyclicComponents(all, edges: { inlineTargets($0) }) {
            for path in component.sorted() {
                guard let decl = all[path], case .enumeration = decl.kind else { continue }
                decl.isIndirect = true
                notes.append("indirect enum \(path)")
            }
        }
        // 2. Indirect enums no longer contribute inline edges. Break any remaining (struct-only) cycle by
        //    boxing one closing field at a time, re-checking after each, so only what is needed is boxed.
        while let component = cyclicComponents(all, edges: { $0.isIndirect ? [] : inlineTargets($0) }).first {
            var boxedOne = false
            for path in component.sorted() {
                guard let decl = all[path], case .structure(var fields, let body) = decl.kind,
                      let i = fields.firstIndex(where: { !$0.boxed && $0.target.map(component.contains) == true }) else { continue }
                fields[i].boxed = true
                decl.kind = .structure(fields: fields, body: body)
                notes.append("boxed field \(path).\(fields[i].name)")
                boxedOne = true
                break
            }
            precondition(boxedOne, "cycle without a struct field to box: \(component.sorted())")
        }
        return notes
    }

    /// Paths of generated types a declaration stores inline.
    static func inlineTargets(_ decl: TypeDecl) -> [String] {
        switch decl.kind {
            case .structure(let fields, _): return fields.filter { !$0.boxed }.compactMap(\.target)
            case .enumeration(let cases, _, _): return cases.flatMap(\.payload).compactMap(\.target)
        }
    }

    /// Strongly connected components that contain a cycle (more than one node, or a self-edge).
    static func cyclicComponents(_ all: [String: TypeDecl], edges: (TypeDecl) -> [String]) -> [Set<String>] {
        var index = 0
        var indices: [String: Int] = [:], lowlinks: [String: Int] = [:]
        var stack: [String] = [], onStack: Set<String> = []
        var result: [Set<String>] = []

        func connect(_ v: String) {
            indices[v] = index; lowlinks[v] = index; index += 1
            stack.append(v); onStack.insert(v)
            let targets = edges(all[v]!).filter { all[$0] != nil }
            for w in targets {
                if indices[w] == nil {
                    connect(w)
                    lowlinks[v] = min(lowlinks[v]!, lowlinks[w]!)
                } else if onStack.contains(w) {
                    lowlinks[v] = min(lowlinks[v]!, indices[w]!)
                }
            }
            if lowlinks[v] == indices[v] {
                var component: Set<String> = []
                while let w = stack.popLast() {
                    onStack.remove(w); component.insert(w)
                    if w == v { break }
                }
                if component.count > 1 || targets.contains(v) { result.append(component) }
            }
        }
        for v in all.keys.sorted() where indices[v] == nil { connect(v) }
        return result
    }
}
