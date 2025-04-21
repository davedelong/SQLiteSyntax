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
    }
    
    public init(explain: Bool, queryPlan: Bool, statement: Statement) {
        self.explain = explain
        self.queryPlan = queryPlan
        self.statement = statement
    }
}
