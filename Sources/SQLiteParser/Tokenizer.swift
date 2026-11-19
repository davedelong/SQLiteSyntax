/// Splits SQL text into tokens, following `sqlite3GetToken` in SQLite's `src/tokenize.c`.
/// Whitespace and comments are skipped.
struct Tokenizer {

    let bytes: [UInt8]
    let source: String

    init(_ source: String) {
        self.source = source
        self.bytes = Array(source.utf8)
    }

    func tokenize() throws(ParseError) -> [Token] {
        var tokens: [Token] = []
        var i = 0
        while i < bytes.count {
            let start = i
            let c = bytes[i]
            func symbol(_ s: String) { tokens.append(Token(kind: .symbol(s), range: start..<i)) }

            switch c {
                case 0x20, 0x09, 0x0A, 0x0C, 0x0D:   // whitespace
                    i += 1
                case ch("-"):
                    if at(i + 1) == ch("-") {           // -- comment
                        while i < bytes.count, bytes[i] != 0x0A { i += 1 }
                    } else if at(i + 1) == ch(">") {
                        i += at(i + 2) == ch(">") ? 3 : 2
                        symbol(i - start == 3 ? "->>" : "->")
                    } else {
                        i += 1; symbol("-")
                    }
                case ch("/"):
                    if at(i + 1) == ch("*") {           // /* comment */ (may be unterminated at end of input)
                        i += 2
                        while i < bytes.count, !(bytes[i] == ch("*") && at(i + 1) == ch("/")) { i += 1 }
                        i = min(i + 2, bytes.count)
                    } else {
                        i += 1; symbol("/")
                    }
                case ch("("), ch(")"), ch(";"), ch("+"), ch("*"), ch("%"), ch(","), ch("&"), ch("~"):
                    i += 1; symbol(String(UnicodeScalar(c)))
                case ch("="):
                    i += at(i + 1) == ch("=") ? 2 : 1; symbol("=")
                case ch("<"):
                    switch at(i + 1) {
                        case ch("="): i += 2; symbol("<=")
                        case ch(">"): i += 2; symbol("<>")
                        case ch("<"): i += 2; symbol("<<")
                        default: i += 1; symbol("<")
                    }
                case ch(">"):
                    switch at(i + 1) {
                        case ch("="): i += 2; symbol(">=")
                        case ch(">"): i += 2; symbol(">>")
                        default: i += 1; symbol(">")
                    }
                case ch("!"):
                    guard at(i + 1) == ch("=") else { throw error("unexpected character '!'", at: i) }
                    i += 2; symbol("!=")
                case ch("|"):
                    if at(i + 1) == ch("|") { i += 2; symbol("||") } else { i += 1; symbol("|") }
                case ch("'"), ch("\""), ch("`"):
                    let (text, end) = try quoted(from: i, delimiter: c)
                    i = end
                    tokens.append(Token(kind: c == ch("'") ? .string(text) : .identifier(text, quoted: true), range: start..<i))
                case ch("["):
                    guard let close = bytes[(i + 1)...].firstIndex(of: ch("]")) else { throw error("unterminated [identifier]", at: i) }
                    let text = String(decoding: bytes[(i + 1)..<close], as: UTF8.self)
                    i = close + 1
                    tokens.append(Token(kind: .identifier(text, quoted: true), range: start..<i))
                case ch("."):
                    if isDigit(at(i + 1)) {
                        i = try number(from: i)
                        tokens.append(Token(kind: .number(text(start..<i)), range: start..<i))
                    } else {
                        i += 1; symbol(".")
                    }
                case ch("0")...ch("9"):
                    i = try number(from: i)
                    tokens.append(Token(kind: .number(text(start..<i)), range: start..<i))
                case ch("?"):
                    i += 1
                    while isDigit(at(i)) { i += 1 }
                    tokens.append(Token(kind: .variable(text(start..<i)), range: start..<i))
                case ch("$"), ch("@"), ch(":"), ch("#"):
                    i = try variable(from: i)
                    tokens.append(Token(kind: .variable(text(start..<i)), range: start..<i))
                case ch("x") where at(i + 1) == ch("'"), ch("X") where at(i + 1) == ch("'"):
                    var j = i + 2
                    while isHexDigit(at(j)) { j += 1 }
                    guard at(j) == ch("'"), (j - i - 2) % 2 == 0 else { throw error("malformed blob literal", at: i) }
                    tokens.append(Token(kind: .blob(text((i + 2)..<j)), range: start..<(j + 1)))
                    i = j + 1
                default:
                    guard isIdentifierCharacter(c) else {
                        throw error("unexpected character '\(String(decoding: [c], as: UTF8.self))'", at: i)
                    }
                    while i < bytes.count, isIdentifierCharacter(bytes[i]) { i += 1 }
                    let word = text(start..<i)
                    let upper = word.uppercased()
                    tokens.append(Token(kind: Keywords.all.contains(upper) ? .keyword(upper) : .identifier(word, quoted: false),
                                        range: start..<i))
            }
        }
        tokens.append(Token(kind: .endOfInput, range: bytes.count..<bytes.count))
        return tokens
    }

    // MARK: Pieces

    /// A quoted string or identifier; a doubled delimiter stands for one delimiter character.
    private func quoted(from start: Int, delimiter: UInt8) throws(ParseError) -> (String, Int) {
        var out: [UInt8] = []
        var i = start + 1
        while i < bytes.count {
            if bytes[i] == delimiter {
                if at(i + 1) == delimiter { out.append(delimiter); i += 2; continue }
                return (String(decoding: out, as: UTF8.self), i + 1)
            }
            out.append(bytes[i]); i += 1
        }
        throw error(delimiter == ch("'") ? "unterminated string literal" : "unterminated quoted identifier", at: start)
    }

    /// Decimal or hex number, with optional `_` digit separators between digits.
    private func number(from start: Int) throws(ParseError) -> Int {
        var i = start
        func digits(_ isValid: (UInt8) -> Bool) throws(ParseError) {
            while i < bytes.count {
                if isValid(bytes[i]) { i += 1; continue }
                if bytes[i] == ch("_") {
                    guard i > start, isValid(bytes[i - 1]), isValid(at(i + 1)) else { throw error("misplaced digit separator", at: i) }
                    i += 1; continue
                }
                break
            }
        }
        if bytes[i] == ch("0"), at(i + 1) == ch("x") || at(i + 1) == ch("X"), isHexDigit(at(i + 2)) {
            i += 2
            try digits(isHexDigit)
        } else {
            try digits(isDigit)
            if at(i) == ch(".") { i += 1; try digits(isDigit) }
            if at(i) == ch("e") || at(i) == ch("E") {
                if isDigit(at(i + 1)) { i += 1; try digits(isDigit) }
                else if (at(i + 1) == ch("+") || at(i + 1) == ch("-")) && isDigit(at(i + 2)) { i += 2; try digits(isDigit) }
            }
        }
        if i < bytes.count, isIdentifierCharacter(bytes[i]) { throw error("malformed number", at: start) }
        return i
    }

    /// `$name`, `@name`, `:name`, `#name`, including Tcl-style `::` and `(…)` suffixes.
    private func variable(from start: Int) throws(ParseError) -> Int {
        var i = start + 1
        var n = 0
        while i < bytes.count {
            let c = bytes[i]
            if isIdentifierCharacter(c) { n += 1; i += 1 }
            else if c == ch("("), n > 0 {
                while i < bytes.count, bytes[i] != ch(")"), !isSpace(bytes[i]) { i += 1 }
                guard at(i) == ch(")") else { throw error("malformed parameter", at: start) }
                i += 1; break
            }
            else if c == ch(":"), at(i + 1) == ch(":") { i += 2 }
            else { break }
        }
        guard n > 0 else { throw error("malformed parameter", at: start) }
        return i
    }

    // MARK: Helpers

    private func at(_ i: Int) -> UInt8 { i < bytes.count ? bytes[i] : 0 }
    private func text(_ r: Range<Int>) -> String { String(decoding: bytes[r], as: UTF8.self) }
    private func isDigit(_ c: UInt8) -> Bool { c >= ch("0") && c <= ch("9") }
    private func isHexDigit(_ c: UInt8) -> Bool { isDigit(c) || (c >= ch("a") && c <= ch("f")) || (c >= ch("A") && c <= ch("F")) }
    private func isSpace(_ c: UInt8) -> Bool { c == 0x20 || (c >= 0x09 && c <= 0x0D) }
    /// Letters, digits, `_`, `$`, and any non-ASCII byte (SQLite's `IdChar`).
    private func isIdentifierCharacter(_ c: UInt8) -> Bool {
        isDigit(c) || (c >= ch("a") && c <= ch("z")) || (c >= ch("A") && c <= ch("Z")) || c == ch("_") || c == ch("$") || c >= 0x80
    }

    func error(_ message: String, at offset: Int) -> ParseError {
        ParseError(message: message, source: source, offset: offset)
    }
}

private func ch(_ s: Unicode.Scalar) -> UInt8 { UInt8(s.value) }
