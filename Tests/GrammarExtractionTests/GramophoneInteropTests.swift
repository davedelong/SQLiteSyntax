import Foundation
import Gramophone
import Testing
@testable import GrammarExtraction

/// Writing grammars with Gramophone's printer and reading them back with its parser.
struct GramophoneInteropTests {

    @Test(arguments: ["frame-spec", "select-stmt", "anything-except-*/", "x", "a-b-c"])
    func namesRoundTrip(_ name: String) {
        let encoded = GrammarFile.fileName(for: name)
        #expect(encoded.unicodeScalars.allSatisfy { $0 == "_" || ($0.isASCII && ($0.properties.isAlphabetic || ("0"..."9").contains($0))) })
        #expect(GrammarFile.diagramName(for: encoded) == name)
    }

    @Test func nameEncodingIsReadable() {
        #expect(GrammarFile.fileName(for: "frame-spec") == "frame_spec")
        #expect(GrammarFile.fileName(for: "anything-except-*/") == "anything_except__U002A__U002F_")
    }

    /// Every fixture diagram survives write -> Gramophone parse -> read with the same language.
    @Test func fixtureRulesRoundTrip() throws {
        let names = DiagramFixtureTests.expected.map(\.name)
        let rules = try names.map { try GrammarExtractor.rule(named: $0, pikchrSource: try DiagramFixtureTests.source($0)) }
        let (text, readBack) = try GrammarFile.roundTrip(rules)
        #expect(readBack.map(\.name) == names)
        #expect(text.contains("compound_operator = 'EXCEPT' | 'INTERSECT' | ('UNION', ['ALL']);"))
    }

    @Test func readingDerivesSymbolKinds() throws {
        let rules = try GrammarFile.rules(from: """
            ordering_term = expr, ['COLLATE', collation_name];
            expr = 'NULL' | column_name;
            """)
        #expect(rules.map(\.name) == ["ordering-term", "expr"])
        let kinds = rules[0].symbolKinds
        #expect(kinds["expr"] == .reference)             // defined in the file
        #expect(kinds["collation-name"] == .terminal)    // not defined: a lexical token
        #expect(rules[0].expression == .sequence([.symbol("expr"), .choice([.empty, .sequence([.symbol("COLLATE"), .symbol("collation-name")])])]))
    }

    /// Gramophone's parser treats each `|` alternative as a single item, so sequences inside
    /// alternatives must be parenthesized; its printer does this.
    @Test func sequencesInsideAlternativesAreGrouped() throws {
        let expression = GrammarExpression.choice([.sequence([.symbol("A"), .symbol("B")]), .symbol("C")])
        let kind = expression.gramophoneKind { $0.first!.isUppercase }
        #expect(Rule(name: "r", kind: kind).description == "r = ('A', 'B') | 'C';")
        let parsed = try #require(try BNFParser().parse("r = ('A', 'B') | 'C';").get().first)
        #expect(try GrammarExpression(gramophone: parsed.kind).isEquivalent(to: expression))
    }

    @Test func unparseableTextThrows() {
        #expect(throws: GrammarFile.Error.self) { try GrammarFile.rules(from: "r = ;") }
    }
}
