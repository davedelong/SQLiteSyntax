import Foundation
import Testing
import GrammarExtraction
@testable import SyntaxGeneration

/// The committed grammar and configuration generate every rule without guessed names or unmapped symbols.
struct ConfigurationTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func fullGenerationHasNoWarnings() throws {
        let rules = try GrammarFile.rules(from: String(contentsOf: Self.root.appendingPathComponent("Grammar/sqlite.ebnf"), encoding: .utf8))
        let configuration = try JSONDecoder().decode(CodegenConfiguration.self,
                                                     from: Data(contentsOf: Self.root.appendingPathComponent("Grammar/codegen.json")))
        let output = SyntaxGenerator.generate(rules: rules, configuration: configuration)
        #expect(output.warnings.isEmpty, "\(output.warnings.joined(separator: "\n"))")
        // Helper rules are recognised where diagrams draw them inline.
        let select = try #require(output.files["SelectStatement.swift"])
        #expect(select.contains("var limit: Limit?") && select.contains("var orderBy: OrderBy?"))
    }
}
