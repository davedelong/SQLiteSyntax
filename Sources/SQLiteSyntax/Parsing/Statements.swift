extension SQLStatementList {
    /// The statements in the list, skipping empty ones (`;;`).
    public var allStatements: [SQLStatement] {
        statements.compactMap(\.sqlStatement)
    }
}

extension SQLStatement {
    /// Parses SQL text that consists of statements separated by semicolons, e.g. a script.
    ///
    /// Empty statements (`;;`, a trailing `;`) are skipped, so empty input gives an empty array.
    public static func parseAll(_ sql: String) throws(ParseError) -> [Self] {
        try Parser.parseAll(sql) { (p: inout Parser) throws(ParseError) -> [Self] in
            var statements: [Self] = []
            while !p.isAtEnd {
                if p.accept(symbol: ";") { continue }
                statements.append(try Self.parse(&p))
                // Anything but `;` here is left for parseAll to report.
                guard p.current.isSymbol(";") else { break }
            }
            return statements
        }
    }
}
