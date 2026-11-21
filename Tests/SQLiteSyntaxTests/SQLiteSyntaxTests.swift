import Testing
@testable import SQLiteSyntax

@Test func createTable() async throws {
    let create = CreateTableStatement(ifNotExists: true,
                                      tableName: "Test",
                                      definition: .columns(columnDefinitions: [
                                        .init(name: "id",
                                              typeName: .init(names: [.init(value: "INT")]),
                                              constraints: [
                                                .init(constraint: .primaryKey(conflict: .abort, autoincrement: true))
                                              ])
                                      ]))
    
    let sql = try create.sql()
    #expect(sql == "CREATE TABLE IF NOT EXISTS Test ( id INT PRIMARY KEY ON CONFLICT ABORT AUTOINCREMENT )")
}

@Test func invalidTable() async throws {
    let create = CreateTableStatement(tableName: "Test", definition: .columns(columnDefinitions: []))
    
    #expect(throws: SyntaxError.self, performing: { try create.sql() })
}

@Test func specialTableName() async throws {
    let create = CreateTableStatement(tableName: "BEGIN",
                                      definition: .columns(columnDefinitions: [.init(name: "END")]))
    
    let sql = try create.sql()
    #expect(sql == #"CREATE TABLE "BEGIN" ( "END" )"#)
}

@Test func convenientTable() async throws {
    var create = Table.Create(name: "Test")
    create.addPrimaryKey("id", type: .integer)
    create.addColumn("name", type: .text, canBeNull: false)
    create.addColumn("dob", type: .text)
    create.options = []
    
    let s1 = try create.sql()
    #expect(s1 == "CREATE TABLE IF NOT EXISTS Test ( id INTEGER NOT NULL PRIMARY KEY , name TEXT NOT NULL , dob TEXT )")
    
    create.addForeignKey(
        "parent",
        references: "Test",
        column: "id",
        canBeNull: true,
        onDelete: .setNull
    )
    
    let s2 = try create.sql()
    #expect(s2 == "CREATE TABLE IF NOT EXISTS Test ( id INTEGER NOT NULL PRIMARY KEY , name TEXT NOT NULL , dob TEXT , parent REFERENCES Test ( id ) ON DELETE SET NULL )")
}

@Test func selection() async throws {
    var select = Select.star(from: "Test")
    let s1 = try select.sql()
    #expect(s1 == "SELECT * FROM Test")
    
    select.where = .column("foo") == "bar"
    let s2 = try select.sql()
    #expect(s2 == "SELECT * FROM Test WHERE foo == 'bar'")
    
}

@Test func insert() async throws {
    let insert = InsertStatement(action: .insert(),
                                 tableName: "Test",
                                 columnNameList: ["greeting", "target"],
                                 source: .rows(values: .values(Values(values: [
                                    ["Hello", "World"],
                                    ["Goodnight", "Moon"],
                                 ]))))
    
    let sql = try insert.sql()
    #expect(sql == "INSERT INTO Test ( greeting , target ) VALUES ( 'Hello' , 'World' ) , ( 'Goodnight' , 'Moon' )")
}
