import Foundation
import GrammarExtraction

let usage = """
    usage: sqlite-grammar --docs <sqlite-docsrc checkout> [--output <file>] [--verbose]

    Extracts the SQL grammar from the railroad diagrams in <docs>/art/syntax/*.pikchr
    and writes it as EBNF (to stdout when no --output is given).
    """

var docs: String?
var output: String?
var verbose = false
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
        case "--docs": docs = arguments.popFirst()
        case "--output": output = arguments.popFirst()
        case "--verbose", "-v": verbose = true
        case "--help", "-h": print(usage); exit(0)
        default:
            FileHandle.standardError.write(Data("unknown argument: \(argument)\n\(usage)\n".utf8)); exit(2)
    }
}

guard let docs else {
    FileHandle.standardError.write(Data("\(usage)\n".utf8)); exit(2)
}

func log(_ message: String) { FileHandle.standardError.write(Data((message + "\n").utf8)) }

do {
    let start = Date()
    let rules = try GrammarExtractor.rules(docsDirectory: URL(fileURLWithPath: docs))
    for rule in rules {
        let d = rule.diagnostics
        let suspicious = d.unresolvedEndpoints > 0 || d.undeterminedTracks > 0 || !d.directionConflicts.isEmpty
        if verbose || suspicious {
            log("\(rule.name): unresolved=\(d.unresolvedEndpoints) undetermined=\(d.undeterminedTracks) conflicts=\(d.directionConflicts.count)")
        }
    }
    let document = GrammarExtractor.ebnfDocument(rules)
    if let output {
        try document.write(toFile: output, atomically: true, encoding: .utf8)
        log("wrote \(rules.count) rules to \(output) in \(String(format: "%.1f", Date().timeIntervalSince(start)))s")
    } else {
        print(document, terminator: "")
    }
} catch {
    log("error: \(error)")
    exit(1)
}
