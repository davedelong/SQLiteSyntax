// Restrictions SQLite enforces beyond its grammar diagrams (codegen.json `restrictions`). The generated
// `validate()` and parser of each type here call its `checkRestrictions()`.

extension CreateTriggerStatement {
    /// parse.y's `trigger_cmd` allows narrower statements in a trigger body than at the top level:
    /// no `WITH` before `INSERT`, `UPDATE` or `DELETE`, no `RETURNING`, no `INSERT … DEFAULT VALUES`,
    /// and no `INDEXED BY`/`NOT INDEXED`.
    func checkRestrictions() throws(SyntaxError) {
        // The first statement is `begin`, the rest are `statements`.
        switch begin {
            case .updateStatement(let update): try check(update)
            case .deleteStatement(let delete): try check(delete)
            case .insertStatement(let insert): try check(insert)
            case .selectStatement: break
        }
        for statement in statements {
            switch statement {
                case .updateStatement(let update): try check(update)
                case .deleteStatement(let delete): try check(delete)
                case .insertStatement(let insert): try check(insert)
                case .selectStatement: break
            }
        }
    }

    private func check(_ update: UpdateStatement) throws(SyntaxError) {
        try require(update.with == nil, reason: "WITH is not allowed on INSERT, UPDATE or DELETE statements within triggers")
        try Self.check(update.qualifiedTableName.indexHint, statement: self)
        try require(update.returningClause == nil, reason: "cannot use RETURNING in a trigger")
    }

    private func check(_ delete: DeleteStatement) throws(SyntaxError) {
        try require(delete.with == nil, reason: "WITH is not allowed on INSERT, UPDATE or DELETE statements within triggers")
        try Self.check(delete.qualifiedTableName.indexHint, statement: self)
        try require(delete.returningClause == nil, reason: "cannot use RETURNING in a trigger")
    }

    private func check(_ insert: InsertStatement) throws(SyntaxError) {
        try require(insert.with == nil, reason: "WITH is not allowed on INSERT, UPDATE or DELETE statements within triggers")
        if case .defaultValues = insert.source {
            throw SyntaxError.invalidSyntax(self, reason: "DEFAULT VALUES is not allowed within triggers")
        }
        try require(insert.returningClause == nil, reason: "cannot use RETURNING in a trigger")
    }

    /// SQLite's own messages (parse.y `tridxby`).
    private static func check(_ hint: IndexHint?, statement: CreateTriggerStatement) throws(SyntaxError) {
        switch hint {
            case .indexedBy?:
                throw SyntaxError.invalidSyntax(statement, reason: "the INDEXED BY clause is not allowed on UPDATE or DELETE statements within triggers")
            case .notIndexed?:
                throw SyntaxError.invalidSyntax(statement, reason: "the NOT INDEXED clause is not allowed on UPDATE or DELETE statements within triggers")
            case nil:
                break
        }
    }
}

extension FunctionArguments {
    /// SQLite rejects `DISTINCT` with more than one argument, whatever the function.
    func checkRestrictions() throws(SyntaxError) {
        if case .arguments(.distinct?, let expressions, _) = self {
            try require(expressions.count == 1, reason: "DISTINCT aggregates must have exactly one argument")
        }
    }
}
