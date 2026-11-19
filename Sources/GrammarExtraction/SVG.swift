/// A minimal reader for the SVG that Pikchr emits. It only understands the
/// handful of elements Pikchr produces for syntax diagrams.
struct SVGDocument {

    struct Element {
        var tag: String
        var attributes: [String: String]
        var text: String?
    }

    var elements: [Element] = []

    init(_ svg: String) {
        let chars = Array(svg.unicodeScalars)
        var i = 0
        let wanted: Set<String> = ["path", "polygon", "circle", "text"]
        while i < chars.count {
            guard chars[i] == "<" else { i += 1; continue }
            var j = i + 1
            var name = ""
            while j < chars.count, chars[j].properties.isAlphabetic {
                name.unicodeScalars.append(chars[j]); j += 1
            }
            guard wanted.contains(name), j < chars.count, !chars[j].properties.isAlphabetic else { i += 1; continue }
            // attributes up to '>'
            var attrText = String.UnicodeScalarView()
            while j < chars.count, chars[j] != ">" { attrText.append(chars[j]); j += 1 }
            j += 1
            var element = Element(tag: name, attributes: SVGDocument.parseAttributes(String(attrText)), text: nil)
            if name == "text" {
                var body = String.UnicodeScalarView()
                while j < chars.count, chars[j] != "<" { body.append(chars[j]); j += 1 }
                element.text = SVGDocument.unescape(String(body))
            }
            elements.append(element)
            i = j
        }
    }

    static func parseAttributes(_ s: String) -> [String: String] {
        var result: [String: String] = [:]
        let chars = Array(s.unicodeScalars)
        var i = 0
        while i < chars.count {
            while i < chars.count, !isNameChar(chars[i]) { i += 1 }
            var name = String.UnicodeScalarView()
            while i < chars.count, isNameChar(chars[i]) { name.append(chars[i]); i += 1 }
            guard i < chars.count, chars[i] == "=" else { continue }
            i += 1
            guard i < chars.count, chars[i] == "\"" || chars[i] == "'" else { continue }
            let quote = chars[i]; i += 1
            var value = String.UnicodeScalarView()
            while i < chars.count, chars[i] != quote { value.append(chars[i]); i += 1 }
            i += 1
            result[String(name)] = String(value)
        }
        return result
    }

    private static func isNameChar(_ c: Unicode.Scalar) -> Bool {
        c.properties.isAlphabetic || c == "-" || c == ":" || c == "_" || ("0"..."9").contains(c)
    }

    static func unescape(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = ""
        var rest = Substring(s)
        while let amp = rest.firstIndex(of: "&") {
            out += rest[..<amp]
            guard let semi = rest[amp...].firstIndex(of: ";") else { break }
            let entity = rest[rest.index(after: amp)..<semi]
            var replacement: String?
            switch entity {
                case "lt": replacement = "<"
                case "gt": replacement = ">"
                case "amp": replacement = "&"
                case "quot": replacement = "\""
                case "apos": replacement = "'"
                default:
                    if entity.hasPrefix("#x") || entity.hasPrefix("#X"), let v = UInt32(entity.dropFirst(2), radix: 16), let u = Unicode.Scalar(v) {
                        replacement = String(Character(u))
                    } else if entity.hasPrefix("#"), let v = UInt32(entity.dropFirst()), let u = Unicode.Scalar(v) {
                        replacement = String(Character(u))
                    }
            }
            if let replacement {
                out += replacement
                rest = rest[rest.index(after: semi)...]
            } else {
                out += "&"
                rest = rest[rest.index(after: amp)...]
            }
        }
        return out + rest
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
