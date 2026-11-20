import SQLiteSyntax

/// A syntax type that can be read from tokens. Generated types conform in `Generated/`.
protocol SQLParsable {
    static func parse(_ p: inout Parser) throws(ParseError) -> Self
}

/// Which keywords may stand for a name at a given place (parse.y token classes).
enum NameClass {
    /// `nm`: identifiers, fallback keywords, JOIN_KW, INDEXED, and string literals.
    case name
    /// `ids`: identifiers, fallback keywords, and string literals (no JOIN_KW: `FROM a LEFT JOIN b`).
    case alias
}

/// Shared by all copies of a `Parser`: memoised results and the furthest error seen.
final class ParserState {
    struct Key: Hashable { var type: ObjectIdentifier; var position: Int }
    var memo: [Key: (value: Any, end: Int)?] = [:]
    var furthestError: ParseError?

    func record(_ error: ParseError) {
        if furthestError == nil || error.offset > furthestError!.offset { furthestError = error }
    }
}

extension Parser {

    // MARK: Entry points

    /// Parses all of `sql` with `body` (a trailing `;` is allowed). If input remains, reports the
    /// furthest problem seen, which is usually more useful than "expected end of input".
    static func parseAll<T>(_ sql: String, _ body: (inout Parser) throws(ParseError) -> T) throws(ParseError) -> T {
        var p = try Parser(sql)
        let value = try body(&p)
        _ = p.accept(symbol: ";")
        guard p.isAtEnd else {
            if let furthest = p.state.furthestError, furthest.offset > p.current.range.lowerBound { throw furthest }
            throw p.unexpected(expected: "end of input")
        }
        return value
    }

    // MARK: Fixed tokens

    /// Whether the current token is the grammar's fixed token `text`: a symbol, a keyword, or (for words
    /// SQLite does not reserve, like ROWID or STRICT) an unquoted identifier with that spelling.
    func matches(_ text: String) -> Bool { Self.token(current, matches: text) }

    static func token(_ token: Token, matches text: String) -> Bool {
        switch token.kind {
            case .symbol(let s): return s == text
            case .keyword(let k): return k == text
            case .identifier(let s, quoted: false): return text.first?.isLetter == true && s.uppercased() == text
            default: return false
        }
    }

    /// Accepts a sequence of fixed tokens only if all are present.
    mutating func accept(texts: [String]) -> Bool {
        for (i, text) in texts.enumerated() where !Self.token(peek(i), matches: text) { return false }
        position += texts.count
        return true
    }

    mutating func expect(texts: [String]) throws(ParseError) {
        for text in texts {
            guard matches(text) else {
                let e = unexpected(expected: text.first?.isLetter == true ? text : "'\(text)'")
                state.record(e)
                throw e
            }
            _ = advance()
        }
    }

    // MARK: Backtracking

    /// Runs `body`; on failure restores the position and returns nil.
    mutating func attempt<T>(_ body: (inout Parser) throws(ParseError) -> T) -> T? {
        let start = position
        do {
            return try body(&self)
        } catch {
            state.record(error)
            position = start
            return nil
        }
    }

    /// Tries every alternative from the current position and keeps the one that consumes the most
    /// tokens (the first, on a tie). Throws the furthest error if none matches.
    ///
    /// (Alternatives use untyped `throws`: storing typed-throws closures needs macOS 15's runtime.)
    mutating func longest<T>(_ alternatives: [(inout Parser) throws -> T]) throws(ParseError) -> T {
        let start = position
        var best: (value: T, end: Int)?
        for alternative in alternatives {
            position = start
            do {
                let value = try alternative(&self)
                if best == nil || position > best!.end { best = (value, position) }
            } catch {
                if let e = error as? ParseError { state.record(e) }
            }
        }
        guard let best else {
            position = start
            throw state.furthestError ?? unexpected(expected: "valid syntax")
        }
        position = best.end
        return best.value
    }

    /// Caches a type's parse result at this position, so alternatives sharing a prefix don't re-parse it.
    mutating func memoized<T>(_ type: T.Type, _ body: (inout Parser) throws(ParseError) -> T) throws(ParseError) -> T {
        let key = ParserState.Key(type: ObjectIdentifier(type), position: position)
        if let cached = state.memo[key] {
            guard let (value, end) = cached else { throw state.furthestError ?? unexpected(expected: "valid syntax") }
            position = end
            return value as! T
        }
        do {
            let value = try body(&self)
            state.memo[key] = (value, position)
            return value
        } catch {
            state.memo[key] = .some(nil)
            state.record(error)
            throw error
        }
    }

    // MARK: Lists

    /// `x { sep x }`: one or more items, separated (an incomplete trailing separator is not consumed).
    mutating func separated<T>(by separator: [String], _ item: (inout Parser) throws(ParseError) -> T) throws(ParseError) -> [T] {
        var items = [try item(&self)]
        while let next = attempt({ (p: inout Parser) throws(ParseError) -> T in
            try p.expect(texts: separator)
            return try item(&p)
        }) {
            items.append(next)
        }
        return items
    }

    /// `{ x }` or `{ sep x }`: zero or more items (each preceded by `separator` if given).
    mutating func repeated<T>(separator: [String] = [], _ item: (inout Parser) throws(ParseError) -> T) -> [T] {
        var items: [T] = []
        while true {
            let start = position
            guard let next = attempt({ (p: inout Parser) throws(ParseError) -> T in
                try p.expect(texts: separator)
                return try item(&p)
            }), position > start else {
                position = start
                break
            }
            items.append(next)
        }
        return items
    }

    // MARK: Names

    /// A name (identifier, a keyword allowed as a name, or a string literal), keeping its spelling.
    /// Keywords in `excluding` can come next at this point, so they are not taken as the name.
    mutating func parseName(class nameClass: NameClass, excluding: Set<String> = []) throws(ParseError) -> String {
        let token = current
        switch token.kind {
            case .identifier(let s, quoted: false) where excluding.contains(s.uppercased()):
                break
            case .identifier(let s, _):
                _ = advance(); return s
            case .string(let s):
                _ = advance(); return s
            case .keyword(let k) where Keywords.usableAsName(k, class: nameClass) && !excluding.contains(k):
                _ = advance(); return Self.sourceText(of: token, in: source)
            default:
                break
        }
        let e = unexpected(expected: "a name")
        state.record(e)
        throw e
    }
}

// MARK: Hand-written types

extension Name where T: NamedStructure {
    static func parse(_ p: inout Parser, class nameClass: NameClass = .name, excluding: Set<String> = []) throws(ParseError) -> Name<T> {
        Name<T>(value: try p.parseName(class: nameClass, excluding: excluding))
    }
}

extension Name where T == Any {
    static func parse(_ p: inout Parser, class nameClass: NameClass = .name, excluding: Set<String> = []) throws(ParseError) -> Name<T> {
        Name<Any>(value: try p.parseName(class: nameClass, excluding: excluding))
    }
}

extension SQLiteSyntax.Expression: SQLParsable {
    static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        try p.memoized(Self.self) { (p: inout Parser) throws(ParseError) in try p.parseExpression() }
    }
}

extension LiteralValue: SQLParsable {
    static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        let token = p.current
        switch token.kind {
            case .number(let text): _ = p.advance(); return try p.numericLiteral(text, token: token)
            case .string(let s): _ = p.advance(); return .string(s)
            case .blob(let hex): _ = p.advance(); return .blob(p.blob(hex))
            case .keyword("NULL"): _ = p.advance(); return .null
            case .keyword("CURRENT_DATE"): _ = p.advance(); return .currentDate
            case .keyword("CURRENT_TIME"): _ = p.advance(); return .currentTime
            case .keyword("CURRENT_TIMESTAMP"): _ = p.advance(); return .currentTimestamp
            case .identifier(let s, quoted: false) where s.uppercased() == "TRUE": _ = p.advance(); return .true
            case .identifier(let s, quoted: false) where s.uppercased() == "FALSE": _ = p.advance(); return .false
            default:
                let e = p.unexpected(expected: "a literal value")
                p.state.record(e)
                throw e
        }
    }
}

extension NumericLiteral: SQLParsable {
    static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        let token = p.current
        guard case .number(let text) = token.kind else {
            let e = p.unexpected(expected: "a number")
            p.state.record(e)
            throw e
        }
        _ = p.advance()
        return NumericLiteral(try p.number(text, token: token))
    }
}

extension SortDirection: SQLParsable {
    static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        if p.accept(keyword: "ASC") { return .ascending }
        try p.expect(keyword: "DESC")
        return .descending
    }
}

extension ModuleArgument: SQLParsable {
    /// Any tokens up to a `,` or `)` outside parentheses, kept as written.
    static func parse(_ p: inout Parser) throws(ParseError) -> Self {
        let start = p.current.range.lowerBound
        var depth = 0
        var end = start
        while !p.isAtEnd {
            if depth == 0, p.current.isSymbol(",") || p.current.isSymbol(")") { break }
            if p.current.isSymbol("(") { depth += 1 }
            if p.current.isSymbol(")") { depth -= 1 }
            end = p.advance().range.upperBound
        }
        guard end > start else {
            let e = p.unexpected(expected: "a module argument")
            p.state.record(e)
            throw e
        }
        return ModuleArgument(String(decoding: Array(p.source.utf8)[start..<end], as: UTF8.self))
    }
}
