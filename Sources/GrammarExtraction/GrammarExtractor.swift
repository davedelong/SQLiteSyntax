import Foundation

/// One grammar rule extracted from one syntax diagram.
public struct GrammarRule: Sendable {
    public enum SymbolKind: String, Sendable {
        /// Drawn as an oval: a keyword, punctuation, or a lexical token such as `table-name`.
        case terminal
        /// Drawn as a box: a reference to another diagram.
        case reference
    }

    public var name: String
    public var expression: GrammarExpression
    /// How each symbol appearing in `expression` was drawn.
    public var symbolKinds: [String: SymbolKind]
    /// Diagram-reading diagnostics (empty for rules read from a grammar file).
    public var diagnostics: DiagramDiagnostics

    public init(name: String, expression: GrammarExpression, symbolKinds: [String: SymbolKind],
                diagnostics: DiagramDiagnostics = DiagramDiagnostics()) {
        self.name = name
        self.expression = expression
        self.symbolKinds = symbolKinds
        self.diagnostics = diagnostics
    }

    public var ebnf: String { "\(name) ::= \(expression.ebnf)" }
}

public enum GrammarExtractionError: Error, CustomStringConvertible {
    case render(name: String, message: String)
    case svg(name: String, message: String)
    case noTerminals(name: String)
    case emptyLanguage(name: String)
    /// The simplified expression does not describe the same syntax as the diagram. Indicates a bug.
    case verificationFailed(name: String, witness: [String])

    public var description: String {
        switch self {
            case .render(let name, let message): return "\(name): pikchr failed: \(message)"
            case .svg(let name, let message): return "\(name): could not read SVG: \(message)"
            case .noTerminals(let name): return "\(name): no entry/exit circles found"
            case .emptyLanguage(let name): return "\(name): the diagram accepts nothing (no path from entry to exit)"
            case .verificationFailed(let name, let witness):
                return "\(name): extracted expression differs from the diagram; e.g. \"\(witness.joined(separator: " "))\""
        }
    }
}

public enum GrammarExtractor {

    /// Extracts the grammar rule drawn by one Pikchr syntax diagram.
    public static func rule(named name: String, pikchrSource: String) throws(GrammarExtractionError) -> GrammarRule {
        let svg: String
        do { svg = try Pikchr.svg(from: pikchrSource) } catch { throw .render(name: name, message: error.message) }
        return try rule(named: name, svg: svg)
    }

    /// Extracts the grammar rule drawn by Pikchr-rendered SVG.
    public static func rule(named name: String, svg: String) throws(GrammarExtractionError) -> GrammarRule {
        let reader: DiagramReader
        do { reader = try DiagramReader(svg: svg) } catch { throw .svg(name: name, message: error.message) }
        guard !reader.terminals.isEmpty else { throw .noTerminals(name: name) }
        let graph = reader.automaton()
        let diagram = Language(automaton: graph.automaton, start: graph.start, accept: graph.accept)
        // The shape of the result depends on the order redundant edges are pruned and states are
        // eliminated. Try a few fixed orders and keep the shortest rendering (first wins ties).
        var best: GrammarExpression?
        for reverseOrder in [false, true] {
            let pruned = diagram.pruned(reverseOrder: reverseOrder)
            for preferHigherStates in [false, true] {
                guard let raw = pruned.structuralExpression(preferHigherStates: preferHigherStates) else { continue }
                let candidate = raw.removingRedundantAlternatives(matching: diagram)
                if best == nil || candidate.ebnf.utf8.count < best!.ebnf.utf8.count { best = candidate }
            }
        }
        guard let expression = best else { throw .emptyLanguage(name: name) }
        if let witness = Language.difference(diagram, expression.language) {
            throw .verificationFailed(name: name, witness: witness)
        }
        let kinds = graph.kinds.mapValues { $0 == .box ? GrammarRule.SymbolKind.reference : .terminal }
        return GrammarRule(name: name, expression: expression, symbolKinds: kinds, diagnostics: graph.diagnostics)
    }

    /// Extracts every diagram in a sqlite-docsrc checkout (`art/syntax/*.pikchr`), sorted by name.
    public static func rules(docsDirectory: URL) throws -> [GrammarRule] {
        let syntax = docsDirectory.appendingPathComponent("art/syntax")
        let files = try FileManager.default.contentsOfDirectory(at: syntax, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "pikchr" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { url in
            let source = try String(contentsOf: url, encoding: .utf8)
            return try rule(named: url.deletingPathExtension().lastPathComponent, pikchrSource: source)
        }
    }

    /// The grammar file format, written with Gramophone (see `GrammarFile`).
    public static func ebnfDocument(_ rules: [GrammarRule]) -> String {
        GrammarFile.text(for: rules)
    }
}
