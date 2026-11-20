import Foundation
import GrammarExtraction
import SyntaxGeneration

let usage = """
    usage: sqlite-grammar (--docs <sqlite-docsrc checkout> | --grammar <file.ebnf>) [--output <file>]
                          [--codegen-config <codegen.json> --swift-output <directory>] [--verbose]

    With --docs, extracts the SQL grammar from the railroad diagrams in <docs>/art/syntax/*.pikchr
    and writes it as EBNF (to stdout when no --output is given). The EBNF is written and read back
    with Gramophone, and every rule is checked to round-trip unchanged.

    With --grammar, reads an existing EBNF grammar instead (no docs checkout needed).

    With --codegen-config and --swift-output, also generates Swift types for the rules listed
    in the config, and with --parser-output their parse functions (for the SQLiteParser module).
    Generated files in the output directories are replaced; other files are left alone.
    """

var docs: String?
var grammar: String?
var output: String?
var codegenConfig: String?
var swiftOutput: String?
var parserOutput: String?
var verbose = false
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
        case "--docs": docs = arguments.popFirst()
        case "--grammar": grammar = arguments.popFirst()
        case "--output": output = arguments.popFirst()
        case "--codegen-config": codegenConfig = arguments.popFirst()
        case "--swift-output": swiftOutput = arguments.popFirst()
        case "--parser-output": parserOutput = arguments.popFirst()
        case "--verbose", "-v": verbose = true
        case "--help", "-h": print(usage); exit(0)
        default:
            FileHandle.standardError.write(Data("unknown argument: \(argument)\n\(usage)\n".utf8)); exit(2)
    }
}

guard (docs == nil) != (grammar == nil) else {
    FileHandle.standardError.write(Data("pass exactly one of --docs or --grammar\n\(usage)\n".utf8)); exit(2)
}

func log(_ message: String) { FileHandle.standardError.write(Data((message + "\n").utf8)) }

do {
    let start = Date()
    // The rules code generation works from: always as read by Gramophone.
    let rules: [GrammarRule]
    if let docs {
        let extracted = try GrammarExtractor.rules(docsDirectory: URL(fileURLWithPath: docs))
        for rule in extracted {
            let d = rule.diagnostics
            let suspicious = d.unresolvedEndpoints > 0 || d.undeterminedTracks > 0 || !d.directionConflicts.isEmpty
            if verbose || suspicious {
                log("\(rule.name): unresolved=\(d.unresolvedEndpoints) undetermined=\(d.undeterminedTracks) conflicts=\(d.directionConflicts.count)")
            }
        }
        let (document, readBack) = try GrammarFile.roundTrip(extracted)
        rules = readBack
        if let output {
            try document.write(toFile: output, atomically: true, encoding: .utf8)
            log("wrote \(rules.count) rules to \(output) in \(String(format: "%.1f", Date().timeIntervalSince(start)))s")
        } else if swiftOutput == nil {
            print(document, terminator: "")
        }
    } else {
        rules = try GrammarFile.rules(from: String(contentsOfFile: grammar!, encoding: .utf8))
        log("read \(rules.count) rules from \(grammar!)")
    }
    if let codegenConfig, let swiftOutput {
        let configuration = try JSONDecoder().decode(CodegenConfiguration.self,
                                                     from: Data(contentsOf: URL(fileURLWithPath: codegenConfig)))
        let generated = SyntaxGenerator.generate(rules: rules, configuration: configuration)
        for warning in generated.warnings { log("warning: \(warning)") }
        if verbose { for note in generated.notes { log("note: \(note)") } }
        func replaceGenerated(in path: String, with files: [String: String]) throws {
            let directory = URL(fileURLWithPath: path)
            let fm = FileManager.default
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            // Remove files this tool generated earlier (recognised by their header), then write the new set.
            for url in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where url.pathExtension == "swift" {
                if let text = try? String(contentsOf: url, encoding: .utf8), text.hasPrefix(SyntaxGenerator.header) {
                    try fm.removeItem(at: url)
                }
            }
            for (name, source) in files.sorted(by: { $0.key < $1.key }) {
                try source.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
            }
        }
        try replaceGenerated(in: swiftOutput, with: generated.files)
        if let parserOutput {
            try replaceGenerated(in: parserOutput, with: generated.parserFiles)
            log("wrote \(generated.parserFiles.count) parser files to \(parserOutput)")
        }
        log("wrote \(generated.files.count) Swift files to \(swiftOutput)")
    }
} catch {
    log("error: \(error)")
    exit(1)
}
