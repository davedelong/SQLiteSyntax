import Foundation
import Testing
import GrammarExtraction
@testable import SyntaxGeneration

/// Reference cycles between generated types must be broken, or the types have infinite size.
struct RecursionTests {

    func generate(_ ebnf: String, rules: [String], references: [String: String] = [:]) throws -> SyntaxGenerator.Output {
        let parsed = try GrammarFile.rules(from: ebnf)
        return SyntaxGenerator.generate(rules: parsed, configuration: CodegenConfiguration(rules: rules, references: references))
    }

    @Test func selfReferencingChoiceBecomesIndirectEnum() throws {
        let output = try generate("c = 'Z' | ('(', c, ')');", rules: ["c"])
        #expect(output.notes == ["indirect enum C"])
        #expect(output.files["Generated+C.swift"]!.contains("indirect enum C: Syntax"))
    }

    @Test func structOnlyCycleBoxesOneField() throws {
        let output = try generate("""
            a = 'X', b;
            b = 'Y', ['(', a, ')'];
            """, rules: ["a", "b"])
        #expect(output.notes == ["boxed field A.b"])
        #expect(output.files["Generated+A.swift"]!.contains("@Indirect var b: B"))
        #expect(!output.files["Generated+B.swift"]!.contains("@Indirect"))
        #expect(output.files["Generated.swift"]!.contains("indirect case value(Value)"))
    }

    @Test func optionalSelfReferenceIsBoxed() throws {
        // An Optional is stored inline, so `t` containing `t?` still has infinite size.
        let output = try generate("t = 'T', ['(', t, ')'];", rules: ["t"])
        #expect(output.notes == ["boxed field T.t"])
        #expect(output.files["Generated+T.swift"]!.contains("@Indirect var t: T? = nil"))
    }

    @Test func cyclesThroughListsAreLeftAlone() throws {
        // `{ … }` and `x { ',' x }` are stored as arrays, which already live on the heap.
        #expect(try generate("t = 'T', ['(', t, {',', t}, ')'];", rules: ["t"]).notes.isEmpty)
        #expect(try generate("u = 'U', {'(', u, ')'};", rules: ["u"]).notes.isEmpty)
    }

    @Test func acyclicTypesAreUnchanged() throws {
        let output = try generate("p = 'P', q; q = 'Q' | 'R';", rules: ["p", "q"])
        #expect(output.notes.isEmpty)
        #expect(!output.files.filter { $0.key != "Generated.swift" }.values.contains { $0.contains("indirect enum") || $0.contains("@Indirect var") })
    }

    /// The real SELECT family: every cycle passes through an enum, so no struct needs boxing.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: grammarFile.path)))
    func selectFamilyCyclesAreBrokenByIndirectEnums() throws {
        let rules = try GrammarFile.rules(from: String(contentsOf: Self.grammarFile, encoding: .utf8))
        let names = rules.map(\.name).filter { !["expr", "literal-value", "comment-syntax", "numeric-literal", "sql-stmt-list"].contains($0) }
        let output = SyntaxGenerator.generate(rules: rules, configuration: CodegenConfiguration(
            rules: names, references: ["expr": "Expression", "literal-value": "LiteralValue", "numeric-literal": "NumericLiteral"]))
        #expect(output.notes.contains("indirect enum TableOrSubquery"))
        // select-stmt draws select-core inline; recognition makes it reference SelectCore instead.
        #expect(output.notes.contains("indirect enum SelectCore"))
        #expect(!output.notes.contains { $0.hasPrefix("indirect enum SelectStatement.") })
        #expect(!output.notes.contains { $0.hasPrefix("boxed field") })
    }

    static let grammarFile = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Grammar/sqlite.ebnf")
}
