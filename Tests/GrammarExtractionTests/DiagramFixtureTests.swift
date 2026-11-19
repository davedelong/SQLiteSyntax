import Foundation
import Testing
@testable import GrammarExtraction

/// Real syntax diagrams from the SQLite docs, each exercising a drawing convention the reader must handle.
struct DiagramFixtureTests {

    static let expected: [(name: String, ebnf: String, why: String)] = [
        ("compound-operator",
         "( 'EXCEPT' | 'INTERSECT' | 'UNION' [ 'ALL' ] )",
         "branches that join part-way along another line"),
        ("drop-index-stmt",
         "'DROP' 'INDEX' [ 'IF' 'EXISTS' ] [ schema-name '.' ] index-name",
         "a merge and a branch that overlap on the same stretch of line"),
        ("vacuum-stmt",
         "'VACUUM' [ schema-name ] [ 'INTO' filename ]",
         "two arrows meeting end-to-end on top of a third line"),
        ("ordering-term",
         "expr [ 'COLLATE' collation-name ] [ ( 'ASC' | 'DESC' ) ] [ 'NULLS' ( 'FIRST' | 'LAST' ) ]",
         "no exit circle; the exit is a dangling arrow"),
        ("indexed-column",
         "( column-name | expr ) [ 'COLLATE' collation-name ] [ ( 'ASC' | 'DESC' ) ]",
         "a line that touches the main line mid-way and leaves again"),
        ("join-operator",
         "( ',' | ( 'CROSS' | [ 'NATURAL' ] [ ( 'FULL' | 'INNER' | 'LEFT' | 'RIGHT' | ( 'FULL' | 'LEFT' | 'RIGHT' ) 'OUTER' ) ] ) 'JOIN' )",
         "an arrowhead where two lines end at the same point"),
        ("delete-stmt",
         "[ 'WITH' [ 'RECURSIVE' ] common-table-expression { ',' common-table-expression } ] 'DELETE' 'FROM' qualified-table-name [ 'WHERE' expr ] [ returning-clause ]",
         "a row drawn right-to-left, including lines without arrowheads"),
        ("table-options",
         "( 'STRICT' | 'WITHOUT' 'ROWID' ) { ',' ( 'STRICT' | 'WITHOUT' 'ROWID' ) }",
         "a loop back through a separator"),
        ("select-core",
         "( 'SELECT' [ ( 'ALL' | 'DISTINCT' ) ] result-column { ',' result-column } [ ( 'FROM' ( join-clause | table-or-subquery { ',' table-or-subquery } ) [ 'WHERE' expr ] | 'WHERE' expr ) ] [ 'GROUP' 'BY' expr { ',' expr } ] [ 'HAVING' expr ] [ 'WINDOW' window-name 'AS' window-defn { ',' window-name 'AS' window-defn } ] | 'VALUES' '(' expr { ',' expr } ')' { ',' '(' expr { ',' expr } ')' } )",
         "a dashed grouping box and annotation text that must be ignored"),
    ]

    static func source(_ name: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "pikchr", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test(arguments: expected.map(\.name))
    func extractsRule(_ name: String) throws {
        let entry = try #require(Self.expected.first { $0.name == name })
        let rule = try GrammarExtractor.rule(named: name, pikchrSource: try Self.source(name))
        #expect(rule.expression.ebnf == entry.ebnf, "\(name): \(entry.why)")
    }

    @Test func symbolKinds() throws {
        let rule = try GrammarExtractor.rule(named: "delete-stmt", pikchrSource: try Self.source("delete-stmt"))
        #expect(rule.symbolKinds["DELETE"] == .terminal)
        #expect(rule.symbolKinds["qualified-table-name"] == .reference)
        #expect(rule.symbolKinds["returning-clause"] == .reference)
    }

    @Test func extractionIsDeterministic() throws {
        let source = try Self.source("join-operator")
        let first = try GrammarExtractor.rule(named: "join-operator", pikchrSource: source).ebnf
        for _ in 0..<3 {
            #expect(try GrammarExtractor.rule(named: "join-operator", pikchrSource: source).ebnf == first)
        }
    }

    @Test func renderErrorsAreReported() {
        #expect(throws: GrammarExtractionError.self) {
            try GrammarExtractor.rule(named: "broken", pikchrSource: "box \"unterminated")
        }
    }
}
