import Foundation
import Testing
@testable import SQLiteSyntax

struct TokenizerTests {

    /// A token's kind and text, with constructors named like the kinds so expectations read naturally.
    struct Lexeme: Equatable, CustomStringConvertible {
        var kind: Token.Kind
        var string: String
        static func keyword(_ s: String) -> Lexeme { Lexeme(kind: .keyword, string: s) }
        static func identifier(_ s: String, quoted: Bool) -> Lexeme { Lexeme(kind: .identifier(quoted: quoted), string: s) }
        static func string(_ s: String) -> Lexeme { Lexeme(kind: .string, string: s) }
        static func blob(_ s: String) -> Lexeme { Lexeme(kind: .blob, string: s) }
        static func number(_ s: String) -> Lexeme { Lexeme(kind: .number, string: s) }
        static func variable(_ s: String) -> Lexeme { Lexeme(kind: .variable, string: s) }
        static func symbol(_ s: String) -> Lexeme { Lexeme(kind: .symbol, string: s) }
        static let endOfInput = Lexeme(kind: .endOfInput, string: "")
        var description: String { "\(kind) \(string.debugDescription)" }
    }

    func kinds(_ sql: String) throws -> [Lexeme] {
        try Tokenizer(sql).tokenize().map { Lexeme(kind: $0.kind, string: $0.string) }
    }

    @Test func tokens() throws {
        #expect(try kinds("a.b >= 1_000 -- comment\n|| 'it''s' /* c */ ->> ?3") == [
            .identifier("a", quoted: false), .symbol("."), .identifier("b", quoted: false), .symbol(">="),
            .number("1_000"), .symbol("||"), .string("it's"), .symbol("->>"), .variable("?3"), .endOfInput,
        ])
        #expect(try kinds("\"my col\" [x] `y` X'0aFF' select") == [
            .identifier("my col", quoted: true), .identifier("x", quoted: true), .identifier("y", quoted: true),
            .blob("0aFF"), .keyword("SELECT"), .endOfInput,
        ])
        #expect(try kinds("0x1F .5 1e-3 :a @b $c::d(e)") == [
            .number("0x1F"), .number(".5"), .number("1e-3"), .variable(":a"), .variable("@b"), .variable("$c::d(e)"), .endOfInput,
        ])
    }

    @Test func contextualKeywordsKeepTheirSpellingAsNames() throws {
        #expect(try kinds("filter, Over") == [
            .identifier("filter", quoted: false), .symbol(","), .identifier("Over", quoted: false), .endOfInput,
        ])
    }

    @Test(arguments: ["'open", "\"open", "[open", "X'abc'", "1_", "12abc", "a ! b", "$"])
    func lexicalErrors(_ sql: String) {
        #expect(throws: ParseError.self) { try Tokenizer(sql).tokenize() }
    }
}

struct ExpressionParserTests {

    func sql(_ text: String) throws -> String { try Expr(parsing: text).sql() }

    @Test func smallestIntegerLiteral() throws {
        guard case .literalValue(.integer(.min)) = try Expr(parsing: "-9223372036854775808") else {
            Issue.record("-9223372036854775808 should parse as Int64.min"); return
        }
    }

    @Test func rendering() throws {
        #expect(try sql("a+b*c") == "a + b * c")
        #expect(try sql("t.a = 'x'") == "t.a == 'x'")
        #expect(try sql("main.t.a <> ?") == "main.t.a != ?")
        #expect(try sql("count(*)") == "count ( * )")
        #expect(try sql("count(DISTINCT a)") == "count ( DISTINCT a )")
        #expect(try sql("random()") == "random ( )")
        #expect(try sql("sum(a) FILTER (WHERE b > 0) OVER (PARTITION BY c ORDER BY a DESC NULLS LAST ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)")
                == "sum ( a ) FILTER ( WHERE b > 0 ) OVER ( PARTITION BY c ORDER BY a DESC NULLS LAST ROWS BETWEEN 1 PRECEDING AND CURRENT ROW )")
        #expect(try sql("CASE a WHEN 1 THEN 'one' ELSE 'other' END") == "CASE a WHEN 1 THEN 'one' ELSE 'other' END")
        #expect(try sql("cast(a as varchar(10))") == "CAST ( a AS varchar ( 10 ) )")
        #expect(try sql("a not between 1 and 2") == "a NOT BETWEEN 1 AND 2")
        #expect(try sql("a is not distinct from b") == "a IS NOT DISTINCT FROM b")
        #expect(try sql("a LIKE '%x' ESCAPE '\\'") == "a LIKE '%x' ESCAPE '\\'")
        #expect(try sql("x'0102'") == "X'0102'")
        #expect(try sql("RAISE(ABORT, 'nope')") == "RAISE ( ABORT , 'nope' )")
    }

    @Test func precedenceShapes() throws {
        func shape(_ text: String) throws -> String { try parenthesized(Expr(parsing: text)) }
        #expect(try shape("1 + 2 * 3") == "(1 + (2 * 3))")
        #expect(try shape("1 - 2 - 3") == "((1 - 2) - 3)")
        #expect(try shape("NOT a = b AND c") == "((NOT (a == b)) AND c)")
        #expect(try shape("a OR b AND c") == "(a OR (b AND c))")
        #expect(try shape("-a || b") == "((- a) || b)")
        #expect(try shape("a BETWEEN 1 AND 2 AND c") == "((a BETWEEN 1 AND 2) AND c)")
        #expect(try shape("a = b IS NULL") == "((a == b) IS NULL)")
        #expect(try shape("a COLLATE NOCASE = b") == "((a COLLATE NOCASE) == b)")
    }

    @Test func errorsHaveLocations() {
        do {
            _ = try Expr(parsing: "a +\n  * b")
            Issue.record("expected an error")
        } catch {
            #expect(error.line == 2)
            #expect(error.column == 3)
            #expect(error.message == "expected an expression, found '*'")
        }
    }

    @Test(arguments: ["percentile(a) WITHIN GROUP (ORDER BY a)", "a GLOB b ESCAPE c", "#1"])
    func unsupportedForms(_ text: String) {
        #expect(throws: ParseError.self) { try Expr(parsing: text) }
    }
}
