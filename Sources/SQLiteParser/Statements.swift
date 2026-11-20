import SQLiteSyntax

extension SQLStatementList {
    /// The statements in the list, skipping empty ones (`;;`).
    public var allStatements: [SQLStatement] {
        statements.compactMap(\.sqlStatement)
    }
}
