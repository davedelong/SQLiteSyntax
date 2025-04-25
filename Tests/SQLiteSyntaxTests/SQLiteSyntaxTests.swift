import Testing
@testable import SQLiteSyntax

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    let create = CreateTableStatement(temporary: false,
                                      ifNotExists: true,
                                      tableName: .init(value: "Test"),
                                      contents: .columns([
                                        .init(name: .init(value: "id"),
                                              typeName: .init(names: [.init(value: "INT")]),
                                              constraints: [
                                                .init(name: nil, constraint: .primaryKey(nil, .abort, autoincrement: true))
                                              ])
                                      ], [], nil))
    
    let sql = try create.build()
    #expect(sql == "CREATE TABLE IF NOT EXISTS Test ( id INT PRIMARY KEY ON CONFLICT ABORT AUTOINCREMENT )")
}
