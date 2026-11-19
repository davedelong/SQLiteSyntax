import Foundation
import GrammarExtraction
import SyntaxGeneration

let usage = """
    usage: sqlite-grammar --docs <sqlite-docsrc checkout> [--output <file>]
                          [--codegen-config <codegen.json> --swift-output <directory>] [--verbose]

    Extracts the SQL grammar from the railroad diagrams in <docs>/art/syntax/*.pikchr
    and writes it as EBNF (to stdout when no --output is given).

    With --codegen-config and --swift-output, also generates Swift types for the rules listed
    in the config. Generated files in the output directory are replaced; other files are left alone.
    """

var docs: String?
var output: String?
var codegenConfig: String?
var swiftOutput: String?
var verbose = false
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
        case "--docs": docs = arguments.popFirst()
        case "--output": output = arguments.popFirst()
        case "--codegen-config": codegenConfig = arguments.popFirst()
        case "--swift-output": swiftOutput = arguments.popFirst()
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
    } else if swiftOutput == nil {
        print(document, terminator: "")
    }
    if let codegenConfig, let swiftOutput {
        let configuration = try JSONDecoder().decode(CodegenConfiguration.self,
                                                     from: Data(contentsOf: URL(fileURLWithPath: codegenConfig)))
        let generated = SyntaxGenerator.generate(rules: rules, configuration: configuration)
        for warning in generated.warnings { log("warning: \(warning)") }
        let directory = URL(fileURLWithPath: swiftOutput)
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        // Remove files this tool generated earlier (recognised by their header), then write the new set.
        for url in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where url.pathExtension == "swift" {
            if let text = try? String(contentsOf: url, encoding: .utf8), text.hasPrefix(SyntaxGenerator.header) {
                try fm.removeItem(at: url)
            }
        }
        for (name, source) in generated.files.sorted(by: { $0.key < $1.key }) {
            try source.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        log("wrote \(generated.files.count) Swift files to \(swiftOutput)")
    }
} catch {
    log("error: \(error)")
    exit(1)
}
