import Foundation

/// Reads a Pikchr-rendered railroad diagram and produces an automaton over its bubble labels.
///
/// 1. SVG primitives: closed paths are bubbles (oval or box), open paths are tracks,
///    polygons are arrowheads, circles are the entry/exit terminals, text labels bubbles.
/// 2. Arrowheads are attached to track ends (extending the track to the tip and fixing its direction).
/// 3. Every track endpoint's contact is found: a terminal circle, a bubble port, or another track.
/// 4. The travel direction of every track and bubble is inferred by solving parity constraints
///    (arrowheads, terminals, bubble in/out consistency, tangent continuity at junctions, shared tracks).
/// 5. An epsilon-automaton is built: bubbles are labelled edges, track pieces are epsilon edges.

struct Bubble {
    enum Kind: String { case oval, box }
    var minX, maxX, minY, maxY: Double
    var kind: Kind
    var texts: [(x: Double, text: String)] = []

    init(points: [Point], kind: Kind) {
        minX = points.map(\.x).min()!; maxX = points.map(\.x).max()!
        minY = points.map(\.y).min()!; maxY = points.map(\.y).max()!
        self.kind = kind
    }

    func contains(_ p: Point) -> Bool {
        minX - 0.5 <= p.x && p.x <= maxX + 0.5 && minY - 0.5 <= p.y && p.y <= maxY + 0.5
    }

    func encloses(_ other: Bubble) -> Bool {
        minX <= other.minX + 0.5 && maxX >= other.maxX - 0.5 && minY <= other.minY + 0.5 && maxY >= other.maxY - 0.5
    }

    var area: Double { (maxX - minX) * (maxY - minY) }

    var label: String {
        texts.sorted { $0.x != $1.x ? $0.x < $1.x : $0.text.utf8.lexicographicallyPrecedes($1.text.utf8) }
            .map(\.text).joined(separator: " ")
    }

    enum Side { case west, east }

    func port(_ p: Point) -> Side? {
        guard minY - tolerance <= p.y && p.y <= maxY + tolerance else { return nil }
        if abs(p.x - minX) < tolerance * 2 { return .west }
        if abs(p.x - maxX) < tolerance * 2 { return .east }
        return nil
    }
}

struct Terminal {
    var center: Point
    var radius: Double
}

/// What a track endpoint touches.
enum Contact {
    case entry
    case exit
    case bubble(Int, Bubble.Side)
    case track(Int, position: Double, tangent: Point, ownTangent: Point)
    case none
}

struct EndpointKey: Hashable {
    var track: Int
    var atEnd: Bool
}

public struct DiagramDiagnostics: Sendable {
    /// Track endpoints that touch nothing.
    public var unresolvedEndpoints: Int
    /// Tracks whose direction could not be inferred (defaulted to drawing order).
    public var undeterminedTracks: Int
    /// Direction constraints that contradicted earlier ones (and were ignored).
    public var directionConflicts: [String]
    /// Number of terminal circles found.
    public var terminals: Int
}

struct DiagramReader {

    var bubbles: [Bubble] = []
    var tracks: [[Point]] = []
    var terminals: [Terminal] = []
    /// Tracks whose direction is fixed by an arrowhead, in the order discovered.
    var arrowed: [Int] = []

    init(svg: String) {
        let document = SVGDocument(svg)
        var heads: [[Point]] = []
        var texts: [(Point, String)] = []
        for element in document.elements {
            switch element.tag {
                case "path":
                    let d = element.attributes["d"] ?? ""
                    let (points, closed) = parsePath(d)
                    if closed {
                        bubbles.append(Bubble(points: points, kind: d.contains("A") ? .oval : .box))
                    } else if points.count >= 2 {
                        tracks.append(points)
                    }
                case "polygon":
                    let n = scanNumbers(element.attributes["points"] ?? "")
                    if n.count >= 6 { heads.append([Point(n[0], n[1]), Point(n[2], n[3]), Point(n[4], n[5])]) }
                case "circle":
                    let value = { (k: String) in Double(element.attributes[k] ?? "") ?? 0 }
                    terminals.append(Terminal(center: Point(value("cx"), value("cy")), radius: value("r")))
                case "text":
                    let x = Double(element.attributes["x"] ?? "") ?? 0
                    let y = Double(element.attributes["y"] ?? "") ?? 0
                    texts.append((Point(x, y), (element.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)))
                default:
                    break
            }
        }

        // Closed shapes that enclose other shapes are decorations (e.g. dashed grouping boxes).
        let all = bubbles
        bubbles = all.enumerated().filter { (i, a) in
            !all.enumerated().contains { (j, b) in i != j && a.encloses(b) }
        }.map(\.element)
        for (p, text) in texts {
            // Text outside any bubble is an annotation and is ignored.
            let inside = bubbles.indices.filter { bubbles[$0].contains(p) }
            guard var best = inside.first else { continue }
            for i in inside.dropFirst() where bubbles[i].area < bubbles[best].area { best = i }
            bubbles[best].texts.append((p.x, text))
        }
        bubbles = bubbles.filter { !$0.texts.isEmpty }

        for head in heads {
            func spread(_ v: Point) -> Double { head.reduce(0) { $0 + v.distance(to: $1) } }
            var tipIndex = 0
            for i in 1..<3 where spread(head[i]) > spread(head[tipIndex]) { tipIndex = i }
            let tip = head[tipIndex]
            let base = head.enumerated().filter { $0.offset != tipIndex }.map(\.element)
            let mid = Point((base[0].x + base[1].x) / 2, (base[0].y + base[1].y) / 2)
            let length = tip.distance(to: mid)
            let direction = (tip - mid).unit
            var best: (d: Double, track: Int, atEnd: Bool)?
            for (ti, t) in tracks.enumerated() {
                for atEnd in [false, true] {
                    let p = atEnd ? t[t.count - 1] : t[0]
                    guard p.distance(to: tip) < length, p.distance(to: mid) < length else { continue }
                    // the track must arrive heading the way the arrow points
                    let q = atEnd ? t[t.count - 2] : t[1]
                    if (p - q).unit.dot(direction) < 0.7 { continue }
                    if best == nil || p.distance(to: tip) < best!.d { best = (p.distance(to: tip), ti, atEnd) }
                }
            }
            if let best {
                if best.atEnd {
                    tracks[best.track].append(tip)
                } else {
                    tracks[best.track] = ([tip] + tracks[best.track]).reversed()
                }
                if !arrowed.contains(best.track) { arrowed.append(best.track) }
            }
        }
    }

    // MARK: Contacts

    static func contacts(bubbles: [Bubble], tracks: [[Point]], terminals: [Terminal]) -> ([(EndpointKey, Contact)], TrackGeometry) {
        let g = TrackGeometry(tracks)
        var result: [(EndpointKey, Contact)] = []
        guard let entry = terminals.first, let exit = terminals.last else { return ([], g) }
        for ti in tracks.indices {
            for atEnd in [false, true] {
                let key = EndpointKey(track: ti, atEnd: atEnd)
                let t = tracks[ti]
                let p = atEnd ? t[t.count - 1] : t[0]
                if p.distance(to: entry.center) < entry.radius + tolerance * 2 { result.append((key, .entry)); continue }
                if terminals.count > 1, p.distance(to: exit.center) < exit.radius + tolerance * 2 { result.append((key, .exit)); continue }
                if let (bi, side) = bubbles.enumerated().lazy.compactMap({ (i, b) in b.port(p).map { (i, $0) } }).first {
                    result.append((key, .bubble(bi, side))); continue
                }
                // Other tracks through p; prefer the one this track runs alongside the longest.
                var best: (s: Double, track: Int, position: Double, tangent: Point)?
                for other in tracks.indices where other != ti {
                    guard var (position, tangent) = g.locate(p, on: other) else { continue }
                    let total = g.totalLength(ti)
                    var s = 0.0
                    while s < total {
                        s += 0.5
                        let q = g.point(on: ti, at: atEnd ? total - s : s)
                        guard let next = g.locate(q, on: other) else { break }
                        (position, tangent) = next
                    }
                    if best == nil || s > best!.s { best = (s, other, position, tangent) }
                }
                if let best {
                    result.append((key, .track(best.track, position: best.position, tangent: best.tangent,
                                               ownTangent: g.endTangent(ti, atEnd: atEnd))))
                } else {
                    result.append((key, .none))
                }
            }
        }
        if terminals.count == 1 {
            // Some diagrams omit the exit circle: the exit is the rightmost dangling endpoint.
            var chosen: Int?
            for (i, (key, contact)) in result.enumerated() {
                guard case .none = contact else { continue }
                let t = tracks[key.track]
                let x = (key.atEnd ? t[t.count - 1] : t[0]).x
                if chosen == nil { chosen = i; continue }
                let ck = result[chosen!].0, ct = tracks[ck.track]
                if x > (ck.atEnd ? ct[ct.count - 1] : ct[0]).x { chosen = i }
            }
            if let chosen { result[chosen].1 = .exit }
        }
        return (result, g)
    }

    /// Runs where two tracks share geometry with parallel tangents.
    struct Overlap {
        var x: Int, y: Int
        var pairs: [(sx: Double, sy: Double)]
        var sameDirection: Bool
    }

    static func overlaps(_ g: TrackGeometry, step: Double = 1.0) -> [Overlap] {
        let tr = g.tracks
        let boxes = tr.map { t in
            (t.map(\.x).min()! - tolerance, t.map(\.x).max()! + tolerance,
             t.map(\.y).min()! - tolerance, t.map(\.y).max()! + tolerance)
        }
        var runs: [Overlap] = []
        for x in tr.indices {
            let L = g.totalLength(x)
            let samples = (0..<(Int(L / step) + 2)).map { min(L, Double($0) * step) }
            for y in tr.indices where y != x {
                let bx = boxes[x], by = boxes[y]
                if bx.1 < by.0 || by.1 < bx.0 || bx.3 < by.2 || by.3 < bx.2 { continue }
                var current: [(sx: Double, sy: Double)] = []
                var currentSign = false
                func flush() {
                    if !current.isEmpty { runs.append(Overlap(x: x, y: y, pairs: current, sameDirection: currentSign)) }
                    current.removeAll()
                }
                for sx in samples {
                    let q = g.point(on: x, at: sx)
                    var matched = false
                    if let (sy, ty) = g.locate(q, on: y) {
                        let a = g.point(on: x, at: max(0, sx - 0.75)), b = g.point(on: x, at: min(L, sx + 0.75))
                        let dot = (b - a).unit.dot(ty)
                        if abs(dot) > 0.9 {
                            let sign = dot > 0
                            if !current.isEmpty && sign != currentSign { flush() }
                            current.append((sx, sy)); currentSign = sign; matched = true
                        }
                    }
                    if !matched && !current.isEmpty { flush() }
                }
                flush()
            }
        }
        return runs
    }

    // MARK: Direction inference

    enum Variable: Hashable { case falseValue, track(Int), bubble(Int) }

    /// Union-find over boolean variables with XOR constraints.
    struct Parity {
        var parent: [Variable: Variable] = [:]
        var parity: [Variable: Bool] = [:]
        var conflicts: [String] = []

        mutating func find(_ a: Variable) -> (Variable, Bool) {
            if parent[a] == nil { parent[a] = a; parity[a] = false }
            if parent[a] == a { return (a, false) }
            let (root, p) = find(parent[a]!)
            parent[a] = root
            parity[a] = parity[a]! != p
            return (root, parity[a]!)
        }

        mutating func relate(_ a: Variable, _ b: Variable, differ: Bool, _ why: @autoclosure () -> String) {
            let (ra, xa) = find(a), (rb, xb) = find(b)
            if ra == rb {
                if (xa != xb) != differ { conflicts.append(why()) }
                return
            }
            parent[ra] = rb
            parity[ra] = (xa != xb) != differ
        }

        mutating func value(_ a: Variable) -> Bool? {
            let (r, xa) = find(a), (rf, xf) = find(.falseValue)
            return r == rf ? (xa != xf) : nil
        }
    }

    func solveDirections() -> (reversed: [Bool], undetermined: Int, conflicts: [String]) {
        let (contacts, g) = DiagramReader.contacts(bubbles: bubbles, tracks: tracks, terminals: terminals)
        var P = Parity()
        _ = P.find(.falseValue)
        for ti in arrowed { P.relate(.track(ti), .falseValue, differ: false, "arrow \(ti)") }
        for (key, contact) in contacts {
            let ti = key.track
            switch contact {
                case .entry, .exit:
                    // drawn end at the entry => reversed; drawn start at the exit => reversed
                    let isEntry: Bool = { if case .entry = contact { return true } else { return false } }()
                    P.relate(.track(ti), .falseValue, differ: isEntry == key.atEnd, "terminal \(ti)")
                case .bubble(let bi, let side):
                    let same = (side == .west) == key.atEnd
                    P.relate(.track(ti), .bubble(bi), differ: !same, "bubble \(ti)-\(bi)")
                case .track(let other, _, let tangent, let own):
                    let dot = own.dot(tangent)
                    if abs(dot) > 0.5 { P.relate(.track(ti), .track(other), differ: dot < 0, "junction \(ti)-\(other)") }
                case .none:
                    break
            }
        }
        for o in DiagramReader.overlaps(g) {
            P.relate(.track(o.x), .track(o.y), differ: !o.sameDirection, "overlap \(o.x)-\(o.y)")
        }
        var reversed: [Bool] = []
        var undetermined = 0
        for ti in tracks.indices {
            let v = P.value(.track(ti))
            if v == nil { undetermined += 1 }
            reversed.append(v ?? false)
        }
        return (reversed, undetermined, P.conflicts)
    }

    // MARK: Automaton

    struct Labelled {
        var automaton: Automaton
        var start: Int
        var accept: Int
        var kinds: [String: Bubble.Kind]
        var diagnostics: DiagramDiagnostics
    }

    func automaton() -> Labelled {
        let (reversed, undetermined, conflicts) = solveDirections()
        let directed = tracks.enumerated().map { reversed[$0.offset] ? Array($0.element.reversed()) : $0.element }
        let (contacts, g) = DiagramReader.contacts(bubbles: bubbles, tracks: directed, terminals: terminals)

        var a = Automaton()
        let start = a.newState(), accept = a.newState()
        var kinds: [String: Bubble.Kind] = [:]
        // ports: west-in, west-out, east-in, east-out
        var ports: [[Int]] = []
        for b in bubbles {
            let p = (0..<4).map { _ in a.newState() }
            ports.append(p)
            a.add(p[0], label: b.label, p[3])
            a.add(p[2], label: b.label, p[1])
            kinds[b.label] = b.kind
        }
        var attach: [[(position: Double, state: Int)]] = Array(repeating: [], count: directed.count)
        func attachState(_ ti: Int, _ position: Double) -> Int {
            if let existing = attach[ti].first(where: { abs($0.position - position) < tolerance }) { return existing.state }
            let s = a.newState()
            attach[ti].append((position, s))
            return s
        }
        var unresolved = 0
        for (key, contact) in contacts {
            let here = attachState(key.track, key.atEnd ? g.totalLength(key.track) : 0)
            let target: Int
            switch contact {
                case .entry: target = start
                case .exit: target = accept
                case .bubble(let bi, let side):
                    switch (side, key.atEnd) {
                        case (.west, false): target = ports[bi][1]
                        case (.west, true): target = ports[bi][0]
                        case (.east, false): target = ports[bi][3]
                        case (.east, true): target = ports[bi][2]
                    }
                case .track(let other, let position, _, _): target = attachState(other, position)
                case .none: unresolved += 1; continue
            }
            if key.atEnd { a.addEpsilon(here, target) } else { a.addEpsilon(target, here) }
        }
        for o in DiagramReader.overlaps(g) where o.sameDirection {
            let first = o.pairs.first!, last = o.pairs.last!
            a.addEpsilon(attachState(o.x, first.sx), attachState(o.y, first.sy))
            a.addEpsilon(attachState(o.y, last.sy), attachState(o.x, last.sx))
        }
        for points in attach {
            let ordered = points.sorted { $0.position != $1.position ? $0.position < $1.position : $0.state < $1.state }
            for (p, q) in zip(ordered, ordered.dropFirst()) { a.addEpsilon(p.state, q.state) }
        }
        let diagnostics = DiagramDiagnostics(unresolvedEndpoints: unresolved, undeterminedTracks: undetermined,
                                             directionConflicts: conflicts, terminals: terminals.count)
        return Labelled(automaton: a, start: start, accept: accept, kinds: kinds, diagnostics: diagnostics)
    }
}
