// The Swift Programming Language
// https://docs.swift.org/swift-book

public struct SQLStatement: Syntax {
    
    public var explain: Bool
    public var queryPlan: Bool
    
    public var statement: Statement
    
    public enum Statement: Syntax {
        case alterTable(AlterTableStatement)
        case analyze(AnalyzeStatement)
        case attach(AttachStatement)
        case begin(BeginStatement)
        case commit(CommitStatement)
        case createIndex(CreateIndexStatement)
        case createTable(CreateTableStatement)
        case createTrigger(CreateTriggerStatement)
        case createView(CreateViewStatement)
        case createVirtualTable(CreateVirtualTableStatement)
        case delete(DeleteStatement)
        case detach(DetachStatement)
        case dropIndex(DropIndexStatement)
        case dropTable(DropTableStatement)
        case dropTrigger(DropTriggerStatement)
        case dropView(DropViewStatement)
        case insert(InsertStatement)
        case pragma(PragmaStatement)
        case reindex(ReindexStatement)
        case release(ReleaseStatement)
        case rollback(RollbackStatement)
        case savepoint(SavepointStatement)
        case select(SelectStatement)
        case update(UpdateStatement)
        case vacuum(VacuumStatement)
        
        public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
            switch self {
                case .alterTable(let s): try builder.add(s)
                case .analyze(let s): try builder.add(s)
                case .attach(let s): try builder.add(s)
                case .begin(let s): try builder.add(s)
                case .commit(let s): try builder.add(s)
                case .createIndex(let s): try builder.add(s)
                case .createTable(let s): try builder.add(s)
                case .createTrigger(let s): try builder.add(s)
                case .createView(let s): try builder.add(s)
                case .createVirtualTable(let s): try builder.add(s)
                case .delete(let s): try builder.add(s)
                case .detach(let s): try builder.add(s)
                case .dropIndex(let s): try builder.add(s)
                case .dropTable(let s): try builder.add(s)
                case .dropTrigger(let s): try builder.add(s)
                case .dropView(let s): try builder.add(s)
                case .insert(let s): try builder.add(s)
                case .pragma(let s): try builder.add(s)
                case .reindex(let s): try builder.add(s)
                case .release(let s): try builder.add(s)
                case .rollback(let s): try builder.add(s)
                case .savepoint(let s): try builder.add(s)
                case .select(let s): try builder.add(s)
                case .update(let s): try builder.add(s)
                case .vacuum(let s): try builder.add(s)
            }
        }
    }
    
    public init(explain: Bool, queryPlan: Bool, statement: Statement) {
        self.explain = explain
        self.queryPlan = queryPlan
        self.statement = statement
    }
    
    public func build(using builder: inout SyntaxBuilder) throws(SyntaxError) {
        if explain { builder.add("EXPLAIN") }
        if queryPlan { builder.add("QUERY", "PLAN") }
        try builder.add(statement)
    }
}
