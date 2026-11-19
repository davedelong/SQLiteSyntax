import Foundation
import PackagePlugin

/// `swift package generate-grammar [--docs <path>]`
///
/// Regenerates Grammar/sqlite.ebnf from the SQLite documentation's syntax diagrams.
/// The docs checkout defaults to `../sqlite-docsrc-git` next to this package.
@main
struct GenerateGrammar: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        var extractor = ArgumentExtractor(arguments)
        let packageDirectory = context.package.directoryURL
        let docs = extractor.extractOption(named: "docs").last
            .map { URL(fileURLWithPath: $0, relativeTo: packageDirectory) }
            ?? packageDirectory.deletingLastPathComponent().appendingPathComponent("sqlite-docsrc-git")
        let outputDirectory = packageDirectory.appendingPathComponent("Grammar")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let output = outputDirectory.appendingPathComponent("sqlite.ebnf")

        // Build the tool optimized: the default (debug) build is about 25x slower.
        let build = try packageManager.build(.product("sqlite-grammar"), parameters: .init(configuration: .release))
        guard build.succeeded, let tool = build.builtArtifacts.first(where: { $0.kind == .executable }) else {
            Diagnostics.error("building sqlite-grammar failed:\n\(build.logText)")
            return
        }
        let process = Process()
        process.executableURL = tool.url
        process.arguments = ["--docs", docs.path, "--output", output.path] + extractor.remainingArguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            Diagnostics.error("sqlite-grammar exited with status \(process.terminationStatus)")
        }
    }
}
