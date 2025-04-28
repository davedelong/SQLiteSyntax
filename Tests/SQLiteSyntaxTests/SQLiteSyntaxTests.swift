import Testing
@testable import SQLiteSyntax

@Test func createTable() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    let create = CreateTableStatement(temporary: false,
                                      ifNotExists: true,
                                      tableName: "Test",
                                      contents: .columns([
                                        .init(name: "id",
                                              typeName: .init(names: [.init(value: "INT")]),
                                              constraints: [
                                                .init(name: nil, constraint: .primaryKey(nil, .abort, autoincrement: true))
                                              ])
                                      ], [], nil))
    
    let sql = try create.build()
    #expect(sql == "CREATE TABLE IF NOT EXISTS Test ( id INT PRIMARY KEY ON CONFLICT ABORT AUTOINCREMENT )")
}

@Test func invalidTable() async throws {
    let create = CreateTableStatement(temporary: false,
                                      ifNotExists: false,
                                      tableName: "Test",
                                      contents: .columns([], [], nil))
    
    #expect(throws: SyntaxError.self, performing: { try create.build() })
}

@Test func specialTableName() async throws {
    let create = CreateTableStatement(temporary: false,
                                      ifNotExists: false,
                                      tableName: "BEGIN",
                                      contents: .columns([
                                        .init(name: "END", constraints: nil)
                                      ], [], []))
    
    let sql = try create.build()
    #expect(sql == #"CREATE TABLE "BEGIN" ( "END" )"#)
}
