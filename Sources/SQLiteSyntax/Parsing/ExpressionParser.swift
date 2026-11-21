import Foundation
typealias Expr = SQLiteSyntax.Expression

extension SQLiteSyntax.Expression {

    /// Parses SQL text containing a single SQLite expression, e.g. `a + 1 BETWEEN 0 AND 10`.
    ///
    /// Not yet supported: `WITHIN GROUP`, and `ESCAPE` on GLOB (which `Expression` cannot represent).
    public init(parsing sql: String) throws(ParseError) {
        self = try Parser.parseAll(sql) { (p: inout Parser) throws(ParseError) in try p.parseExpression() }
    }
}

extension Parser {

    // MARK: Precedence climbing

    mutating func parseExpression(_ minimum: Int = 0) throws(ParseError) -> Expr {
        var left = try parsePrefix()
        while true {
            let token = current
            if let (level, op) = binaryOperator(token) {
                guard level >= minimum else { break }
                _ = advance()
                let right = try parseExpression(level + 1)      // all binary operators are left-associative
                left = .binaryOperator(left, op, right)
                continue
            }
            guard let keyword = token.keyword else { break }
            switch keyword {
                case "OR", "AND":
                    let level = keyword == "OR" ? ExpressionPrecedence.or : ExpressionPrecedence.and
                    guard level >= minimum else { return left }
                    _ = advance()
                    left = .binaryOperator(left, keyword == "OR" ? .or : .and, try parseExpression(level + 1))
                case "COLLATE":
                    guard ExpressionPrecedence.collate >= minimum else { return left }
                    _ = advance()
                    left = .collate(left, Name<Collation>(value: try parseName(allowString: true)))
                case "ISNULL", "NOTNULL":
                    guard ExpressionPrecedence.equality >= minimum else { return left }
                    _ = advance()
                    left = keyword == "ISNULL" ? .isNull(left) : .notNull(left)
                case "IS":
                    guard ExpressionPrecedence.equality >= minimum else { return left }
                    _ = advance()
                    let negated = accept(keyword: "NOT")
                    let distinct = accept(keywords: "DISTINCT", "FROM")
                    left = .equals(left, negated: negated, distinct: distinct, from: try parseExpression(ExpressionPrecedence.equality + 1))
                case "NOT", "IN", "LIKE", "GLOB", "REGEXP", "MATCH", "BETWEEN":
                    guard ExpressionPrecedence.equality >= minimum else { return left }
                    if keyword == "NOT" {
                        let next = peek().keyword ?? ""
                        if next == "NULL" { position += 2; left = .notNull(left); continue }
                        guard ["IN", "LIKE", "GLOB", "REGEXP", "MATCH", "BETWEEN"].contains(next) else { return left }
                        _ = advance()
                    }
                    let negated = keyword == "NOT"
                    left = try parseNegatable(left, negated: negated)
                default:
                    return left
            }
        }
        return left
    }

    func binaryOperator(_ token: Token) -> (Int, BinaryOperator)? {
        guard case .symbol = token.kind else { return nil }
        switch token.string {
            case "=": return (ExpressionPrecedence.equality, .equals)
            case "!=", "<>": return (ExpressionPrecedence.equality, .notEquals)
            case "<": return (ExpressionPrecedence.comparison, .lessThan)
            case "<=": return (ExpressionPrecedence.comparison, .lessThanOrEqual)
            case ">": return (ExpressionPrecedence.comparison, .greaterThan)
            case ">=": return (ExpressionPrecedence.comparison, .greaterThanOrEqual)
            case "&": return (ExpressionPrecedence.bitwise, .bitwiseAnd)
            case "|": return (ExpressionPrecedence.bitwise, .bitwiseOr)
            case "<<": return (ExpressionPrecedence.bitwise, .leftShift)
            case ">>": return (ExpressionPrecedence.bitwise, .rightShift)
            case "+": return (ExpressionPrecedence.additive, .add)
            case "-": return (ExpressionPrecedence.additive, .subtract)
            case "*": return (ExpressionPrecedence.multiplicative, .multiply)
            case "/": return (ExpressionPrecedence.multiplicative, .divide)
            case "%": return (ExpressionPrecedence.multiplicative, .modulo)
            case "||": return (ExpressionPrecedence.concatenation, .concat)
            case "->": return (ExpressionPrecedence.concatenation, .extractJSON)
            case "->>": return (ExpressionPrecedence.concatenation, .extractValue)
            default: return nil
        }
    }

    /// `[NOT] IN …`, `[NOT] LIKE …`, `[NOT] BETWEEN …` (current token is the operator keyword).
    mutating func parseNegatable(_ left: Expr, negated: Bool) throws(ParseError) -> Expr {
        let operatorToken = advance()
        switch operatorToken.keyword! {
            case "BETWEEN":
                // The lower bound runs up to AND; the upper bound binds tighter than the BETWEEN itself.
                let lower = try parseExpression(ExpressionPrecedence.not)
                try expect(keyword: "AND")
                let upper = try parseExpression(ExpressionPrecedence.equality + 1)
                return .between(left, negated: negated, lower: lower, upper: upper)
            case "IN":
                return try parseIn(left, negated: negated)
            case let op:
                let pattern = try parseExpression(ExpressionPrecedence.equality + 1)
                var escape: Expr? = nil
                if accept(keyword: "ESCAPE") {
                    guard op == "LIKE" else { throw error("ESCAPE is only supported after LIKE", at: previous) }
                    escape = try parseExpression(ExpressionPrecedence.escape)
                }
                switch op {
                    case "LIKE": return .like(left, negated: negated, like: pattern, escape: escape)
                    case "GLOB": return .glob(left, negated: negated, glob: pattern)
                    case "REGEXP": return .regexp(left, negated: negated, regexp: pattern)
                    default: return .match(left, negated: negated, match: pattern)
                }
        }
    }

    mutating func parseIn(_ left: Expr, negated: Bool) throws(ParseError) -> Expr {
        if current.isSymbol("(") {
            let open = advance()
            if ["SELECT", "VALUES", "WITH"].contains(current.keyword ?? "") {
                let select = try SelectStatement.parse(&self)
                try expect(symbol: ")")
                return .inStatement(left, negated: negated, select)
            }
            _ = open
            let items = current.isSymbol(")") ? [] : try parseExpressionList()
            try expect(symbol: ")")
            return .inExpression(left, negated: negated, items)
        }
        // IN [schema.]table   or   IN [schema.]table-function(args)
        var first = try parseName()
        var schema: Name<Schema>?
        if accept(symbol: ".") {
            schema = Name<Schema>(value: first)
            first = try parseName()
        }
        if accept(symbol: "(") {
            let arguments = current.isSymbol(")") ? [] : try parseExpressionList()
            try expect(symbol: ")")
            return .inTableFunction(left, negated: negated, schema, Name<Function>(value: first), arguments)
        }
        return .inTable(left, negated: negated, schema, Name<Table>(value: first))
    }

    // MARK: Operands

    mutating func parsePrefix() throws(ParseError) -> Expr {
        let token = current
        switch token.kind {
            case .number:
                _ = advance()
                return .literalValue(try numericLiteral(token.string, token: token))
            case .string:
                _ = advance()
                return .literalValue(.string(token.string))
            case .blob:
                _ = advance()
                return .literalValue(.blob(blob(token.string)))
            case .variable:
                _ = advance()
                return .bindParameter(try bindParameter(token.string, token: token))
            case .symbol where token.string == "(":
                _ = advance()
                if ["SELECT", "VALUES", "WITH"].contains(current.keyword ?? "") {
                    let select = try SelectStatement.parse(&self)
                    try expect(symbol: ")")
                    return .select(select)
                }
                let items = try parseExpressionList()
                try expect(symbol: ")")
                return .expressionList(List(items))
            case .symbol where token.string == "-":
                _ = advance()
                // Like SQLite (expr.c codeInteger), minus applied directly to 9223372036854775808 is the
                // smallest INTEGER rather than the negation of an out-of-range (REAL) literal.
                if case .number = current.kind, token.string.replacingOccurrences(of: "_", with: "") == "9223372036854775808" {
                    _ = advance()
                    return .literalValue(.integer(.min))
                }
                // Minus directly before a number is a negative literal, so negative literals print and
                // re-parse as the same value (`-5`, `-1.5`). (Negating Int64.min stays an operation.)
                if case .number = current.kind {
                    let token = advance()
                    switch try numericLiteral(token.string, token: token) {
                        case .integer(let i) where i != .min && i != 0: return .literalValue(.integer(-i))   // no integer -0
                        case .real(let d): return .literalValue(.real(-d))
                        case let other: return .unaryOperator(.negate, .literalValue(other))
                    }
                }
                return .unaryOperator(.negate, try parseExpression(ExpressionPrecedence.unary))
            case .symbol where token.string == "+":
                _ = advance(); return .unaryOperator(.plus, try parseExpression(ExpressionPrecedence.unary))
            case .symbol where token.string == "~":
                _ = advance(); return .unaryOperator(.bitwiseNot, try parseExpression(ExpressionPrecedence.unary))
            case .keyword where token.string == "NOT":
                _ = advance()
                if accept(keyword: "EXISTS") { return .exists(negated: true, try parseParenthesizedSelect()) }
                return .unaryOperator(.not, try parseExpression(ExpressionPrecedence.not))
            case .keyword where token.string == "EXISTS":
                _ = advance()
                return .exists(negated: false, try parseParenthesizedSelect())
            case .keyword where token.string == "NULL":
                _ = advance(); return .literalValue(.null)
            case .keyword where token.string == "CURRENT_DATE":
                _ = advance(); return .literalValue(.currentDate)
            case .keyword where token.string == "CURRENT_TIME":
                _ = advance(); return .literalValue(.currentTime)
            case .keyword where token.string == "CURRENT_TIMESTAMP":
                _ = advance(); return .literalValue(.currentTimestamp)
            case .keyword where token.string == "CASE":
                return try parseCase()
            // CAST and RAISE fall back to identifiers elsewhere, but not here: in SQLite's parser
            // a keyword only becomes an identifier where the keyword itself cannot appear.
            case .keyword where token.string == "CAST":
                return try parseCast()
            case .keyword where token.string == "RAISE":
                return try parseRaise()
            default:
                guard isName(token) else { throw unexpected(expected: "an expression") }
                return try parseNameOrCall()
        }
    }

    func isName(_ token: Token) -> Bool {
        switch token.kind {
            case .identifier: return true
            case .keyword: return Keywords.usableAsName(token.string)
            default: return false
        }
    }

    /// An identifier (or a keyword usable as one). `allowString` also accepts a string literal (parse.y `ids`).
    mutating func parseName(allowString: Bool = false) throws(ParseError) -> String {
        let token = current
        switch token.kind {
            case .identifier: _ = advance(); return token.string
            case .keyword where Keywords.usableAsName(token.string): _ = advance(); return Self.sourceText(of: token, in: source)
            case .string where allowString: _ = advance(); return token.string
            default: throw unexpected(expected: "a name")
        }
    }

    /// The token's original spelling (keywords are stored uppercased).
    static func sourceText(of token: Token, in source: String) -> String {
        String(decoding: Array(source.utf8)[token.range], as: UTF8.self)
    }

    /// `column`, `table.column`, `schema.table.column`, a TRUE/FALSE literal, or a function call.
    mutating func parseNameOrCall() throws(ParseError) -> Expr {
        let token = current
        let first = try parseName()
        if current.isSymbol("(") {
            return try parseFunctionCall(name: first)
        }
        guard accept(symbol: ".") else {
            if case .identifier(quoted: false) = token.kind {
                switch token.string.uppercased() {
                    case "TRUE": return .literalValue(.true)
                    case "FALSE": return .literalValue(.false)
                    default: break
                }
            }
            return .columnName(nil, nil, Name<Column>(value: first))
        }
        let second = try parseName()
        guard accept(symbol: ".") else {
            return .columnName(nil, Name<Table>(value: first), Name<Column>(value: second))
        }
        let third = try parseName()
        return .columnName(Name<Schema>(value: first), Name<Table>(value: second), Name<Column>(value: third))
    }

    mutating func parseExpressionList() throws(ParseError) -> [Expr] {
        var items = [try parseExpression()]
        while accept(symbol: ",") { items.append(try parseExpression()) }
        return items
    }

    // MARK: Functions and windows

    mutating func parseFunctionCall(name: String) throws(ParseError) -> Expr {
        try expect(symbol: "(")
        // nil arguments: f()
        let arguments = current.isSymbol(")") ? nil : try FunctionArguments.parse(&self)
        try expect(symbol: ")")
        if current.isKeyword("WITHIN") { throw error("WITHIN GROUP is not supported yet") }
        let filter = current.isKeyword("FILTER") && peek().isSymbol("(") ? try FilterClause.parse(&self) : nil
        let over = current.isKeyword("OVER") ? try OverClause.parse(&self) : nil
        return .function(Name<Function>(value: name), arguments, filter, over)
    }

    mutating func parseParenthesizedSelect() throws(ParseError) -> SelectStatement {
        try expect(symbol: "(")
        let select = try SelectStatement.parse(&self)
        try expect(symbol: ")")
        return select
    }

    // MARK: CASE, CAST, RAISE

    mutating func parseCase() throws(ParseError) -> Expr {
        try expect(keyword: "CASE")
        var base: Expr? = nil
        if !current.isKeyword("WHEN") { base = try parseExpression() }
        var branches: [(when: Expr, then: Expr)] = []
        repeat {
            try expect(keyword: "WHEN")
            let condition = try parseExpression()
            try expect(keyword: "THEN")
            branches.append((condition, try parseExpression()))
        } while current.isKeyword("WHEN")
        var otherwise: Expr? = nil
        if accept(keyword: "ELSE") { otherwise = try parseExpression() }
        try expect(keyword: "END")
        return .when(base, branches, else: otherwise)
    }

    mutating func parseCast() throws(ParseError) -> Expr {
        try expect(keyword: "CAST")
        try expect(symbol: "(")
        let value = try parseExpression()
        try expect(keyword: "AS")
        let type = try TypeName.parse(&self)
        try expect(symbol: ")")
        return .cast(value, as: type)
    }

    mutating func parseRaise() throws(ParseError) -> Expr {
        .raise(try RaiseFunction.parse(&self))
    }

    // MARK: Literal values

    /// A numeric literal as SQLite reads it (tokenize.c): INTEGER unless it has a "." or an exponent;
    /// hex is 64-bit two's complement; a decimal integer too large for 64 bits is REAL.
    func numericLiteral(_ text: String, token: Token) throws(ParseError) -> LiteralValue {
        let digits = text.replacingOccurrences(of: "_", with: "")
        if digits.hasPrefix("0x") || digits.hasPrefix("0X") {
            guard let value = UInt64(digits.dropFirst(2), radix: 16) else { throw error("hex literal too big", at: token) }
            return .integer(Int64(bitPattern: value))
        }
        if !digits.contains(where: { $0 == "." || $0 == "e" || $0 == "E" }), let value = Int64(digits) {
            return .integer(value)
        }
        guard let value = Double(digits.hasPrefix(".") ? "0" + digits : digits) else { throw error("malformed number", at: token) }
        return .real(value)
    }

    func number(_ text: String, token: Token) throws(ParseError) -> Decimal {
        let digits = text.replacingOccurrences(of: "_", with: "")
        if digits.hasPrefix("0x") || digits.hasPrefix("0X") {
            guard let value = UInt64(digits.dropFirst(2), radix: 16) else { throw error("hex literal too large", at: token) }
            return Decimal(Int64(bitPattern: value))   // SQLite reads hex literals as 64-bit two's complement
        }
        guard let value = Decimal(string: digits.hasPrefix(".") ? "0" + digits : digits, locale: Locale(identifier: "en_US_POSIX")) else {
            throw error("malformed number", at: token)
        }
        return value
    }

    func blob(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return data
    }

    func bindParameter(_ text: String, token: Token) throws(ParseError) -> BindParameter {
        let name = String(text.dropFirst())
        switch text.first {
            case "?":
                guard !name.isEmpty else { return .next }
                guard let n = Int(name) else { throw error("malformed parameter", at: token) }
                return .nth(n)
            case ":": return .named(name)
            case "@": return .atNamed(name)
            case "$": return .tcl(name)
            // SQLite only accepts #name parameters in its own internal (nested) parsing.
            default: throw error("#-style parameters are not valid in SQL statements", at: token)
        }
    }
}
