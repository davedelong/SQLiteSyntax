import Foundation
import Testing
@testable import GrammarExtraction

/// Runs the extractor over every diagram in a sibling `sqlite-docsrc-git` checkout.
///
/// Opt-in, because it takes about two minutes in a debug build (a few seconds with `-c release`):
///
///     SQLITE_GRAMMAR_DOCS_TESTS=1 swift test -c release --filter DocsCheckoutTests
struct DocsCheckoutTests {

    static let docs = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("sqlite-docsrc-git")

    static var enabled: Bool {
        ProcessInfo.processInfo.environment["SQLITE_GRAMMAR_DOCS_TESTS"] == "1"
            && FileManager.default.fileExists(atPath: docs.appendingPathComponent("art/syntax").path)
    }

    @Test(.enabled(if: enabled, "set SQLITE_GRAMMAR_DOCS_TESTS=1 and provide ../sqlite-docsrc-git"))
    func everyDiagramExtractsAndVerifies() throws {
        // `rules` throws if any rule fails its equivalence check against its diagram.
        let rules = try GrammarExtractor.rules(docsDirectory: Self.docs)
        #expect(rules.count >= 70)
        // Every rule survives Gramophone's EBNF printer and parser unchanged.
        _ = try GrammarFile.roundTrip(rules)
        for rule in rules {
            #expect(rule.diagnostics.terminals >= 1, "\(rule.name)")
            #expect(rule.diagnostics.undeterminedTracks == 0, "\(rule.name)")
        }
    }
}
