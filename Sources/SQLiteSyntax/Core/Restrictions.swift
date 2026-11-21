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
        try require(update.returning == nil, reason: "cannot use RETURNING in a trigger")
    }

    private func check(_ delete: DeleteStatement) throws(SyntaxError) {
        try require(delete.with == nil, reason: "WITH is not allowed on INSERT, UPDATE or DELETE statements within triggers")
        try Self.check(delete.qualifiedTableName.indexHint, statement: self)
        try require(delete.returning == nil, reason: "cannot use RETURNING in a trigger")
    }

    private func check(_ insert: InsertStatement) throws(SyntaxError) {
        try require(insert.with == nil, reason: "WITH is not allowed on INSERT, UPDATE or DELETE statements within triggers")
        if case .defaultValues = insert.source {
            throw SyntaxError.invalidSyntax(self, reason: "DEFAULT VALUES is not allowed within triggers")
        }
        try require(insert.returning == nil, reason: "cannot use RETURNING in a trigger")
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

extension ColumnConstraint {
    /// A constraint is a `CONSTRAINT name` on its own (naming what follows, as in parse.y), a constraint,
    /// or both; not neither.
    func checkRestrictions() throws(SyntaxError) {
        try require(name != nil || constraint != nil, reason: "A column constraint needs a name or a constraint")
    }
}

extension TableConstraint {
    /// A constraint is a `CONSTRAINT name` on its own (naming what follows, as in parse.y), a constraint,
    /// or both; not neither.
    func checkRestrictions() throws(SyntaxError) {
        try require(name != nil || constraint != nil, reason: "A table constraint needs a name or a constraint")
    }
}

extension JoinOperator {
    /// Join keywords in any order are checked as sqlite3JoinType() does: at most three, and a type that
    /// makes sense (not INNER/CROSS with OUTER/LEFT/RIGHT/FULL, and OUTER only with LEFT, RIGHT or FULL).
    func checkRestrictions() throws(SyntaxError) {
        guard case .keywords(let keywords) = self else { return }
        try require(keywords.count <= 3, reason: "unknown join type: at most three join keywords")
        let words = Set(keywords.items)
        let inner = words.contains(.inner) || words.contains(.cross)
        let sided = words.contains(.left) || words.contains(.right) || words.contains(.full)
        let outer = sided || words.contains(.outer)
        try require(!(inner && outer), reason: "unknown join type: INNER or CROSS with an outer join")
        try require(!words.contains(.outer) || sided, reason: "unknown join type: OUTER needs LEFT, RIGHT or FULL")
    }
}
