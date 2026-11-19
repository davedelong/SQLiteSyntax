import Foundation

/// The elements of the SVG that Pikchr emits, read with `XMLDocument`.
/// Only the handful of elements Pikchr produces for syntax diagrams are kept.
///
/// `XMLDocument` is macOS-only; the grammar tooling only runs on macOS.
struct SVGDocument {

    struct Element {
        var tag: String
        var attributes: [String: String]
        var text: String?
    }

    struct ParseError: Error, CustomStringConvertible {
        var message: String
        var description: String { message }
    }

    /// Elements in document order (the reader relies on it: the first circle is the entry).
    var elements: [Element] = []

    init(_ svg: String) throws(ParseError) {
        #if os(macOS)
        let document: XMLDocument
        do { document = try XMLDocument(xmlString: svg) } catch { throw ParseError(message: "\(error)") }
        guard let root = document.rootElement() else { throw ParseError(message: "SVG has no root element") }
        let wanted: Set<String> = ["path", "polygon", "circle", "text"]
        var found: [Element] = []
        func visit(_ element: XMLElement) {
            let tag = element.localName ?? element.name ?? ""
            if wanted.contains(tag) {
                var attributes: [String: String] = [:]
                for attribute in element.attributes ?? [] {
                    if let name = attribute.localName ?? attribute.name { attributes[name] = attribute.stringValue ?? "" }
                }
                found.append(Element(tag: tag, attributes: attributes, text: tag == "text" ? element.stringValue : nil))
            }
            for case let child as XMLElement in element.children ?? [] { visit(child) }
        }
        visit(root)
        elements = found
        #else
        throw ParseError(message: "reading SVG requires XMLDocument, which is only available on macOS")
        #endif
    }
}

/// Scans the numbers out of a string (e.g. polygon points).
func scanNumbers(_ s: String) -> [Double] {
    var result: [Double] = []
    let chars = Array(s.utf8)
    var i = 0
    while i < chars.count {
        let start = i
        if chars[i] == UInt8(ascii: "-"), i + 1 < chars.count, isDigit(chars[i + 1]) { i += 1 }
        guard i < chars.count, isDigit(chars[i]) else { i = start + 1; continue }
        while i < chars.count, isDigit(chars[i]) { i += 1 }
        if i + 1 < chars.count, chars[i] == UInt8(ascii: "."), isDigit(chars[i + 1]) {
            i += 1
            while i < chars.count, isDigit(chars[i]) { i += 1 }
        }
        if i + 1 < chars.count, chars[i] == UInt8(ascii: "e") {
            var k = i + 1
            if k < chars.count, chars[k] == UInt8(ascii: "-") { k += 1 }
            if k < chars.count, isDigit(chars[k]) {
                i = k
                while i < chars.count, isDigit(chars[i]) { i += 1 }
            }
        }
        result.append(Double(String(decoding: chars[start..<i], as: UTF8.self))!)
    }
    return result
}

private func isDigit(_ c: UInt8) -> Bool { c >= UInt8(ascii: "0") && c <= UInt8(ascii: "9") }

/// Parses an SVG path `d` attribute into points. Quadratic curves are sampled;
/// arcs contribute only their end points (they only occur in closed bubble outlines).
func parsePath(_ d: String) -> (points: [Point], closed: Bool) {
    enum Token { case command(UInt8), number(Double) }
    var tokens: [Token] = []
    let chars = Array(d.utf8)
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if "MLQAZ".utf8.contains(c) { tokens.append(.command(c)); i += 1; continue }
        let start = i
        if c == UInt8(ascii: "-"), i + 1 < chars.count, isDigit(chars[i + 1]) { i += 1 }
        if i < chars.count, isDigit(chars[i]) {
            while i < chars.count, isDigit(chars[i]) { i += 1 }
            if i + 1 < chars.count, chars[i] == UInt8(ascii: "."), isDigit(chars[i + 1]) {
                i += 1
                while i < chars.count, isDigit(chars[i]) { i += 1 }
            }
            tokens.append(.number(Double(String(decoding: chars[start..<i], as: UTF8.self))!))
        } else {
            i = start + 1
        }
    }

    var points: [Point] = []
    var closed = false
    var command: UInt8 = 0
    var t = 0
    func number() -> Double {
        if case .number(let v) = tokens[t] { t += 1; return v }
        t += 1; return 0
    }
    while t < tokens.count {
        if case .command(let c) = tokens[t] {
            command = c; t += 1
            if c == UInt8(ascii: "Z") { closed = true }
            continue
        }
        switch command {
            case UInt8(ascii: "M"), UInt8(ascii: "L"):
                let x = number(), y = number()
                points.append(Point(x, y))
            case UInt8(ascii: "Q"):
                let cx = number(), cy = number(), x = number(), y = number()
                let p0 = points.last ?? Point(x, y)
                for k in 1...8 {
                    let u = Double(k) / 8
                    let a = (1 - u) * (1 - u), b = 2 * (1 - u) * u, c = u * u
                    points.append(Point(a * p0.x + b * cx + c * x, a * p0.y + b * cy + c * y))
                }
            case UInt8(ascii: "A"):
                for _ in 0..<5 { _ = number() }
                let x = number(), y = number()
                points.append(Point(x, y))
            default:
                t += 1
        }
    }
    var deduplicated: [Point] = []
    for p in points where deduplicated.last.map({ $0.distance(to: p) > 1e-6 }) ?? true {
        deduplicated.append(p)
    }
    return (deduplicated, closed)
}
