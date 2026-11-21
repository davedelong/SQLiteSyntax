import Testing
import Foundation
import SQLiteSyntax

/// Values whose text is written into the SQL as it is must not build if SQLite would read them as
/// something else; values just inside the rules must still build, and SQLite must accept them.
@Suite struct ValidationTests {

    func virtualTable(_ arguments: [ModuleArgument]) -> CreateVirtualTableStatement {
        CreateVirtualTableStatement(tableName: "v", moduleName: "m", arguments: .init(moduleArguments: List(arguments)))
    }

    @Test(arguments: [
        "a", "", "a b c", "x INTEGER PRIMARY KEY", "tokenize = 'porter ascii'", "f(a, b)", "'it''s, ok)'",
        "\"quoted, name\"", "a(b(c))",
    ])
    func moduleArgumentsThatReadBackAsOneArgument(_ text: String) throws {
        let statement = virtualTable([ModuleArgument(text), "z"])
        let sql = try statement.sql()
        let back = try CreateVirtualTableStatement(parsing: sql)
        #expect(back.arguments?.moduleArguments?.map(\.text) == [text, "z"])
    }

    @Test(arguments: [
        "a); DROP TABLE t; --", "a, b", "a)", "(a", "a; b", "a -- comment", "a /* comment */", "'unterminated",
        "a\u{0}b", "a ` b",
    ])
    func moduleArgumentsThatDoNot(_ text: String) {
        #expect(throws: SyntaxError.self) { try virtualTable([ModuleArgument(text)]).sql() }
    }

    @Test func namesWithNulDoNotBuild() {
        #expect(throws: SyntaxError.self) { try Name<Column>("a\u{0}b").sql() }
        #expect(throws: SyntaxError.self) { try Expr.literalValue(.string("a\u{0}b")).sql() }
    }

    @Test func controlCharactersAreQuoted() throws {
        let name = Name<Column>("a\u{1}b")
        let sql = "SELECT 1 AS " + (try name.sql())
        #expect(try name.sql() == "\"a\u{1}b\"")
        #expect(Database().prepareError(sql) == nil)
        #expect(try Name<Column>(parsing: try name.sql()).value == name.value)
    }

    @Test func numericLiteralsHaveNoSign() throws {
        #expect(throws: SyntaxError.self) { try SignedNumber(sign: .minus, numericLiteral: .real(-5)).sql() }
        #expect(throws: SyntaxError.self) { try SignedNumber(numericLiteral: .real(-0.0)).sql() }
        #expect(throws: SyntaxError.self) { try SignedNumber(numericLiteral: .real(.nan)).sql() }
        #expect(try SignedNumber(sign: .minus, numericLiteral: 5).sql() == "- 5")
        #expect(try SignedNumber(numericLiteral: 0.5).sql() == "0.5")
        #expect(try SignedNumber(numericLiteral: .real(.infinity)).sql() == "9e999")
        // A negative integer is written as the hex literal SQLite reads as that value.
        let negative = try SignedNumber(numericLiteral: .integer(-5)).sql()
        #expect(negative == "0xFFFFFFFFFFFFFFFB")
        #expect(Database().evaluate(negative) == Database().evaluate("-5"))
        #expect(try SignedNumber(parsing: "0x10").sql() == "16")
    }

    @Test func columnAndTableNamesAreComplete() throws {
        #expect(throws: SyntaxError.self) { try Expr.columnName("main", nil, "a").sql() }
        #expect(try Expr.columnName("main", "t", "a").sql() == "main.t.a")
        #expect(try Expr.inTable(.column("a"), negated: true, "main", "t").sql() == "a NOT IN main.t")
    }

    @Test func matchOperatorUsesTheMatchCase() throws {
        #expect(try (Expr.column("a") ~= "x").sql() == "a MATCH 'x'")
    }
}
