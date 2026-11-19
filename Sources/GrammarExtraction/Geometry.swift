import Foundation

struct Point: Equatable {
    var x: Double
    var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }

    func distance(to other: Point) -> Double { hypot(x - other.x, y - other.y) }
    static func - (a: Point, b: Point) -> Point { Point(a.x - b.x, a.y - b.y) }

    var unit: Point {
        let length = hypot(x, y)
        return length == 0 ? Point(0, 0) : Point(x / length, y / length)
    }
    func dot(_ other: Point) -> Double { x * other.x + y * other.y }
}

/// Distance from `p` to segment `ab`, and the clamped parameter along it.
func project(_ p: Point, onto a: Point, _ b: Point) -> (distance: Double, t: Double) {
    let vx = b.x - a.x, vy = b.y - a.y
    let lengthSquared = vx * vx + vy * vy
    if lengthSquared == 0 { return (p.distance(to: a), 0) }
    let t = max(0, min(1, ((p.x - a.x) * vx + (p.y - a.y) * vy) / lengthSquared))
    return (p.distance(to: Point(a.x + t * vx, a.y + t * vy)), t)
}

/// Polyline tracks with arc-length parameterisation.
struct TrackGeometry {
    let tracks: [[Point]]
    let lengths: [[Double]]   // cumulative arc length at each vertex

    init(_ tracks: [[Point]]) {
        self.tracks = tracks
        self.lengths = tracks.map { t in
            var acc = [0.0]
            for (a, b) in zip(t, t.dropFirst()) { acc.append(acc.last! + a.distance(to: b)) }
            return acc
        }
    }

    func totalLength(_ ti: Int) -> Double { lengths[ti].last! }

    func point(on ti: Int, at s: Double) -> Point {
        let t = tracks[ti], L = lengths[ti]
        for k in 0..<(t.count - 1) where L[k + 1] >= s {
            let segment = L[k + 1] - L[k]
            let u = segment == 0 ? 0 : (s - L[k]) / segment
            return Point(t[k].x + u * (t[k + 1].x - t[k].x), t[k].y + u * (t[k + 1].y - t[k].y))
        }
        return t.last!
    }

    /// Arc-length position and tangent of the point of track `ti` closest to `p`, if within tolerance.
    func locate(_ p: Point, on ti: Int) -> (position: Double, tangent: Point)? {
        let t = tracks[ti]
        var best: (d: Double, pos: Double, tangent: Point)?
        for k in 0..<(t.count - 1) {
            let a = t[k], b = t[k + 1]
            let (d, u) = project(p, onto: a, b)
            if d < tolerance, best == nil || d < best!.d {
                best = (d, lengths[ti][k] + u * a.distance(to: b), (b - a).unit)
            }
        }
        return best.map { ($0.pos, $0.tangent) }
    }

    func endTangent(_ ti: Int, atEnd: Bool) -> Point {
        let t = tracks[ti]
        return atEnd ? (t[t.count - 1] - t[t.count - 2]).unit : (t[1] - t[0]).unit
    }
}

/// Matching tolerance, in SVG pixels.
let tolerance = 1.2
