import Testing
import SQLiteSyntax

/// `BindParameter` names are written into the SQL as they are, so validation must reject any name SQLite
/// wouldn't read back as that one parameter.
@Suite struct BindParameterTests {

    @Test(arguments: [
        BindParameter.next, .nth(1), .nth(32766),
        .named("a"), .named("1abc"), .named("é"), .named("a_b$c"),
        .atNamed("x"), .tcl("ns::var"), .tcl("arr(key)"), .named("a::b(c)"),
    ])
    func validParametersBuildAndSQLiteAccepts(_ parameter: BindParameter) throws {
        let sql = try Expr.bindParameter(parameter).sql()
        #expect(Database().prepareError("SELECT " + sql) == nil, "SQLite rejects \(sql)")
        #expect(try BindParameter(parsing: sql).sql() == sql)
    }

    @Test(arguments: [
        BindParameter.nth(0), .nth(-1),
        .named(""), .atNamed(""), .tcl(""),
        .named("a b"), .named("x OR 1=1"), .named("x) OR 1=1 --"), .named("a--"), .named("a/*"),
        .atNamed("a.b"), .tcl("a(b c)"), .tcl("a(b"), .named("a(b)c"), .named(":a"), .named("a:b"),
    ])
    func invalidParametersDoNotBuild(_ parameter: BindParameter) {
        #expect(throws: SyntaxError.self) { try Expr.bindParameter(parameter).sql() }
    }

    @Test func parserRejectsParameterZero() {
        #expect(Database().prepareError("SELECT ?0") != nil)
        #expect(throws: ParseError.self) { try Expr(parsing: "?0") }
    }
}
