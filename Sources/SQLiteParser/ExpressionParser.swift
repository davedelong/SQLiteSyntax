import Foundation
import SQLiteSyntax

typealias Expr = SQLiteSyntax.Expression

extension SQLiteSyntax.Expression {

    /// Parses SQL text containing a single SQLite expression, e.g. `a + 1 BETWEEN 0 AND 10`.
    ///
    /// Not yet supported: subqueries (`(SELECT …)`, `EXISTS`, `IN (SELECT …)`), `WITHIN GROUP`,
    /// and a few forms `Expression` cannot represent (empty `IN ()`, `#name` parameters, `ESCAPE` on GLOB).
    public init(parsing sql: String) throws(ParseError) {
        var parser = try Parser(sql)
        self = try parser.parseExpression()
        guard parser.isAtEnd else { throw parser.unexpected(expected: "end of expression") }
    }
}

/// Binding strengths from parse.y (`%left OR.` … `%right BITNOT.`), weakest first.
enum Precedence {
    static let or = 1
    static let and = 2
    static let not = 3
    /// IS, IN, LIKE/GLOB/REGEXP/MATCH, BETWEEN, ISNULL/NOTNULL, =, ==, !=, <>
    static let equality = 4
    static let comparison = 5        // < <= > >=
    static let escape = 6
    static let bitwise = 7           // & | << >>
    static let additive = 8          // + -
    static let multiplicative = 9    // * / %
    static let concatenation = 10    // || -> ->>
    static let collate = 11
    static let unary = 12            // ~ and unary + -
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
                    let level = keyword == "OR" ? Precedence.or : Precedence.and
                    guard level >= minimum else { return left }
                    _ = advance()
                    left = .binaryOperator(left, keyword == "OR" ? .or : .and, try parseExpression(level + 1))
                case "COLLATE":
                    guard Precedence.collate >= minimum else { return left }
                    _ = advance()
                    left = .collate(left, Name<Collation>(value: try parseName(allowString: true)))
                case "ISNULL", "NOTNULL":
                    guard Precedence.equality >= minimum else { return left }
                    _ = advance()
                    left = keyword == "ISNULL" ? .isNull(left) : .notNull(left)
                case "IS":
                    guard Precedence.equality >= minimum else { return left }
                    _ = advance()
                    let negated = accept(keyword: "NOT")
                    let distinct = accept(keywords: "DISTINCT", "FROM")
                    left = .equals(left, negated: negated, distinct: distinct, from: try parseExpression(Precedence.equality + 1))
                case "NOT", "IN", "LIKE", "GLOB", "REGEXP", "MATCH", "BETWEEN":
                    guard Precedence.equality >= minimum else { return left }
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
        guard case .symbol(let s) = token.kind else { return nil }
        switch s {
            case "=": return (Precedence.equality, .equals)
            case "!=", "<>": return (Precedence.equality, .notEquals)
            case "<": return (Precedence.comparison, .lessThan)
            case "<=": return (Precedence.comparison, .lessThanOrEqual)
            case ">": return (Precedence.comparison, .greaterThan)
            case ">=": return (Precedence.comparison, .greaterThanOrEqual)
            case "&": return (Precedence.bitwise, .bitwiseAnd)
            case "|": return (Precedence.bitwise, .bitwiseOr)
            case "<<": return (Precedence.bitwise, .leftShift)
            case ">>": return (Precedence.bitwise, .rightShift)
            case "+": return (Precedence.additive, .add)
            case "-": return (Precedence.additive, .subtract)
            case "*": return (Precedence.multiplicative, .multiply)
            case "/": return (Precedence.multiplicative, .divide)
            case "%": return (Precedence.multiplicative, .modulo)
            case "||": return (Precedence.concatenation, .concat)
            case "->": return (Precedence.concatenation, .extractJSON)
            case "->>": return (Precedence.concatenation, .extractValue)
            default: return nil
        }
    }

    /// `[NOT] IN …`, `[NOT] LIKE …`, `[NOT] BETWEEN …` (current token is the operator keyword).
    mutating func parseNegatable(_ left: Expr, negated: Bool) throws(ParseError) -> Expr {
        let operatorToken = advance()
        switch operatorToken.keyword! {
            case "BETWEEN":
                // The lower bound runs up to AND; the upper bound binds tighter than the BETWEEN itself.
                let lower = try parseExpression(Precedence.not)
                try expect(keyword: "AND")
                let upper = try parseExpression(Precedence.equality + 1)
                return .between(left, negated: negated, lower: lower, upper: upper)
            case "IN":
                return try parseIn(left, negated: negated)
            case let op:
                let pattern = try parseExpression(Precedence.equality + 1)
                var escape: Expr? = Optional.none
                if accept(keyword: "ESCAPE") {
                    guard op == "LIKE" else { throw error("ESCAPE is only supported after LIKE", at: previous) }
                    escape = try parseExpression(Precedence.escape)
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
                throw error("subqueries are not supported yet", at: current)
            }
            if current.isSymbol(")") {
                throw error("an empty IN list cannot be represented by SQLiteSyntax.Expression", at: open)
            }
            let items = try parseExpressionList()
            try expect(symbol: ")")
            return .inExpression(left, negated: negated, List(items))
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
            let args: [FunctionArgument] = arguments.isEmpty ? [.wildcard(nil)] : [.expression(distinct: false, List(arguments), nil)]
            return .inTableFunction(left, negated: negated, schema, Name<Function>(value: first), List(args))
        }
        return .inTable(left, negated: negated, schema, Name<Table>(value: first))
    }

    // MARK: Operands

    mutating func parsePrefix() throws(ParseError) -> Expr {
        let token = current
        switch token.kind {
            case .number(let text):
                _ = advance()
                return .literalValue(try numericLiteral(text, token: token))
            case .string(let s):
                _ = advance()
                return .literalValue(.string(s))
            case .blob(let hex):
                _ = advance()
                return .literalValue(.blob(blob(hex)))
            case .variable(let v):
                _ = advance()
                return .bindParameter(try bindParameter(v, token: token))
            case .symbol("("):
                _ = advance()
                if ["SELECT", "VALUES", "WITH"].contains(current.keyword ?? "") {
                    throw error("subqueries are not supported yet")
                }
                let items = try parseExpressionList()
                try expect(symbol: ")")
                return .expressionList(List(items))
            case .symbol("-"):
                _ = advance()
                // Like SQLite (expr.c codeInteger), minus applied directly to 9223372036854775808 is the
                // smallest INTEGER rather than the negation of an out-of-range (REAL) literal.
                if case .number(let text) = current.kind, text.replacingOccurrences(of: "_", with: "") == "9223372036854775808" {
                    _ = advance()
                    return .literalValue(.integer(.min))
                }
                return .unaryOperator(.negate, try parseExpression(Precedence.unary))
            case .symbol("+"):
                _ = advance(); return .unaryOperator(.plus, try parseExpression(Precedence.unary))
            case .symbol("~"):
                _ = advance(); return .unaryOperator(.bitwiseNot, try parseExpression(Precedence.unary))
            case .keyword("NOT"):
                if peek().isKeyword("EXISTS") { throw error("subqueries are not supported yet", at: peek()) }
                _ = advance()
                return .unaryOperator(.not, try parseExpression(Precedence.not))
            case .keyword("EXISTS"):
                throw error("subqueries are not supported yet")
            case .keyword("NULL"):
                _ = advance(); return .literalValue(.null)
            case .keyword("CURRENT_DATE"):
                _ = advance(); return .literalValue(.currentDate)
            case .keyword("CURRENT_TIME"):
                _ = advance(); return .literalValue(.currentTime)
            case .keyword("CURRENT_TIMESTAMP"):
                _ = advance(); return .literalValue(.currentTimestamp)
            case .keyword("CASE"):
                return try parseCase()
            // CAST and RAISE fall back to identifiers elsewhere, but not here: in SQLite's parser
            // a keyword only becomes an identifier where the keyword itself cannot appear.
            case .keyword("CAST"):
                return try parseCast()
            case .keyword("RAISE"):
                return try parseRaise()
            default:
                guard isName(token) else { throw unexpected(expected: "an expression") }
                return try parseNameOrCall()
        }
    }

    func isName(_ token: Token) -> Bool {
        switch token.kind {
            case .identifier: return true
            case .keyword(let k): return Keywords.usableAsName(k)
            default: return false
        }
    }

    /// An identifier (or a keyword usable as one). `allowString` also accepts a string literal (parse.y `ids`).
    mutating func parseName(allowString: Bool = false) throws(ParseError) -> String {
        let token = current
        switch token.kind {
            case .identifier(let s, _): _ = advance(); return s
            case .keyword(let k) where Keywords.usableAsName(k): _ = advance(); return Self.sourceText(of: token, in: source)
            case .string(let s) where allowString: _ = advance(); return s
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
            if case .identifier(let s, quoted: false) = token.kind {
                switch s.uppercased() {
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
        let argument: FunctionArgument
        if accept(symbol: "*") {
            argument = .wildcard(Wildcard())
        } else if current.isSymbol(")") {
            argument = .wildcard(nil)       // f(): the empty argument list
        } else {
            let distinct = accept(keyword: "DISTINCT")
            if !distinct { _ = accept(keyword: "ALL") }
            let arguments = try parseExpressionList()
            let orderBy = current.isKeyword("ORDER") ? try parseOrderBy() : nil
            argument = .expression(distinct: distinct, List(arguments), orderBy)
        }
        try expect(symbol: ")")
        if current.isKeyword("WITHIN") { throw error("WITHIN GROUP is not supported yet") }

        var filter: FilterClause?
        if current.isKeyword("FILTER"), peek().isSymbol("(") {
            _ = advance()
            try expect(symbol: "(")
            try expect(keyword: "WHERE")
            filter = FilterClause(where: try parseExpression())
            try expect(symbol: ")")
        }
        var over: OverClause?
        if accept(keyword: "OVER") {
            over = try parseOver()
        }
        return .function(Name<Function>(value: name), List([argument]), filter, over)
    }

    mutating func parseOrderBy() throws(ParseError) -> OrderBy {
        try expect(keyword: "ORDER")
        try expect(keyword: "BY")
        var terms = [try parseOrderingTerm()]
        while accept(symbol: ",") { terms.append(try parseOrderingTerm()) }
        return OrderBy(terms: List(terms))
    }

    mutating func parseOrderingTerm() throws(ParseError) -> OrderingTerm {
        let expression = try parseExpression()     // a trailing COLLATE is parsed as part of the expression
        var direction: SortDirection?
        if accept(keyword: "ASC") { direction = .ascending } else if accept(keyword: "DESC") { direction = .descending }
        var nulls: OrderingTerm.Nulls?
        if accept(keywords: "NULLS", "FIRST") { nulls = .first } else if accept(keywords: "NULLS", "LAST") { nulls = .last }
        return OrderingTerm(expression: expression, sortDirection: direction, nulls: nulls)
    }

    mutating func parseOver() throws(ParseError) -> OverClause {
        guard accept(symbol: "(") else {
            return .windowName(Name<Window>(value: try parseName()))
        }
        var base: Name<Window>?
        let frameOrClauseStart: Set<String> = ["PARTITION", "ORDER", "RANGE", "ROWS", "GROUPS"]
        if isName(current), !frameOrClauseStart.contains(current.keyword ?? "") {
            base = Name<Window>(value: try parseName())
        }
        var partition: List<Expr>?
        if accept(keywords: "PARTITION", "BY") { partition = List(try parseExpressionList()) }
        let orderBy = current.isKeyword("ORDER") ? try parseOrderBy() : nil
        let frame = ["RANGE", "ROWS", "GROUPS"].contains(current.keyword ?? "") ? try parseFrameSpec() : nil
        try expect(symbol: ")")
        return .expression(base, partitionBy: partition, orderBy: orderBy, frameSpec: frame)
    }

    mutating func parseFrameSpec() throws(ParseError) -> FrameSpec {
        let target: FrameSpec.Target
        switch advance().keyword {
            case "RANGE": target = .range
            case "ROWS": target = .rows
            default: target = .groups
        }
        let scope: FrameSpec.Scope
        if accept(keyword: "BETWEEN") {
            let lower: FrameSpec.Scope.LowerBound
            if accept(keywords: "UNBOUNDED", "PRECEDING") { lower = .unboundedPreceding }
            else if accept(keywords: "CURRENT", "ROW") { lower = .currentRow }
            else {
                let e = try parseExpression(Precedence.not)
                if accept(keyword: "PRECEDING") { lower = .preceding(e) }
                else { try expect(keyword: "FOLLOWING"); lower = .following(e) }
            }
            try expect(keyword: "AND")
            let upper: FrameSpec.Scope.UpperBound
            if accept(keywords: "UNBOUNDED", "FOLLOWING") { upper = .unboundedFollowing }
            else if accept(keywords: "CURRENT", "ROW") { upper = .currentRow }
            else {
                let e = try parseExpression(Precedence.not)
                if accept(keyword: "PRECEDING") { upper = .preceding(e) }
                else { try expect(keyword: "FOLLOWING"); upper = .following(e) }
            }
            scope = .between(lower, upper)
        } else if accept(keywords: "UNBOUNDED", "PRECEDING") {
            scope = .unboundedPreceding
        } else if accept(keywords: "CURRENT", "ROW") {
            scope = .currentRow
        } else {
            let e = try parseExpression(Precedence.not)
            try expect(keyword: "PRECEDING")
            scope = .preceding(e)
        }
        var exclude: FrameSpec.Exclude?
        if accept(keyword: "EXCLUDE") {
            if accept(keywords: "NO", "OTHERS") { exclude = .noOthers }
            else if accept(keywords: "CURRENT", "ROW") { exclude = .currentRow }
            else if accept(keyword: "GROUP") { exclude = .group }
            else { try expect(keyword: "TIES"); exclude = .ties }
        }
        return FrameSpec(target: target, scope: scope, exclude: exclude)
    }

    // MARK: CASE, CAST, RAISE

    mutating func parseCase() throws(ParseError) -> Expr {
        try expect(keyword: "CASE")
        // Note: `Expression` is ExpressibleByNilLiteral (meaning SQL NULL), so `cond ? nil : expr`
        // would produce `.literalValue(.null)`, not `Optional.none`. Spell out the optionals.
        var base: Expr? = Optional.none
        if !current.isKeyword("WHEN") { base = try parseExpression() }
        var branches: [(when: Expr, then: Expr)] = []
        repeat {
            try expect(keyword: "WHEN")
            let condition = try parseExpression()
            try expect(keyword: "THEN")
            branches.append((condition, try parseExpression()))
        } while current.isKeyword("WHEN")
        var otherwise: Expr? = Optional.none
        if accept(keyword: "ELSE") { otherwise = try parseExpression() }
        try expect(keyword: "END")
        return .when(base, branches, else: otherwise)
    }

    mutating func parseCast() throws(ParseError) -> Expr {
        try expect(keyword: "CAST")
        try expect(symbol: "(")
        let value = try parseExpression()
        try expect(keyword: "AS")
        var names = [Name<Any>(value: try parseName(allowString: true))]
        while isName(current) || { if case .string = current.kind { return true } else { return false } }() {
            names.append(Name<Any>(value: try parseName(allowString: true)))
        }
        var arguments: TypeName.Arguments?
        if accept(symbol: "(") {
            let a = try parseSignedNumber()
            arguments = accept(symbol: ",") ? .two(a, try parseSignedNumber()) : .one(a)
            try expect(symbol: ")")
        }
        try expect(symbol: ")")
        return .cast(value, as: TypeName(names: List(names), arguments: arguments))
    }

    mutating func parseSignedNumber() throws(ParseError) -> Decimal {
        let negative = accept(symbol: "-")
        if !negative { _ = accept(symbol: "+") }
        let token = current
        guard case .number(let text) = token.kind else { throw unexpected(expected: "a number") }
        _ = advance()
        let value = try number(text, token: token)
        return negative ? -value : value
    }

    mutating func parseRaise() throws(ParseError) -> Expr {
        try expect(keyword: "RAISE")
        try expect(symbol: "(")
        let result: RaiseFunction
        if accept(keyword: "IGNORE") {
            result = .ignore
        } else {
            let kind = advance()
            try expect(symbol: ",")
            let message = try parseExpression()
            switch kind.keyword {
                case "ROLLBACK": result = .rollback(message)
                case "ABORT": result = .abort(message)
                case "FAIL": result = .fail(message)
                default: throw error("expected IGNORE, ROLLBACK, ABORT or FAIL", at: kind)
            }
        }
        try expect(symbol: ")")
        return .raise(result)
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
            default: throw error("\(text.prefix(1))-style parameters cannot be represented by SQLiteSyntax.BindParameter", at: token)
        }
    }
}
