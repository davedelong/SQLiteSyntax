import Foundation
import PackagePlugin

/// `swift package --allow-writing-to-package-directory generate-grammar [--docs <path>]`
///
/// Regenerates Grammar/sqlite.ebnf from the SQLite documentation's syntax diagrams and, when
/// Grammar/codegen.json exists, the Swift types it lists into Sources/SQLiteSyntax/Generated/.
/// The docs checkout defaults to `../sqlite-docsrc-git` next to this package; the SQLite source checkout
/// (for precedence and keyword tables) to `../sqlite` (`--sqlite-source <path>`).
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
        var toolArguments = ["--docs", docs.path, "--output", output.path]
        let codegen = outputDirectory.appendingPathComponent("codegen.json")
        if FileManager.default.fileExists(atPath: codegen.path) {
            let swiftOutput = packageDirectory.appendingPathComponent("Sources/SQLiteSyntax/Generated")
            let parserOutput = packageDirectory.appendingPathComponent("Sources/SQLiteParser/Generated")
            toolArguments += ["--codegen-config", codegen.path, "--swift-output", swiftOutput.path,
                              "--parser-output", parserOutput.path]
        }
        // The precedence and keyword tables come from SQLite's own sources, when a checkout is next to us.
        let sqliteSource = extractor.extractOption(named: "sqlite-source").last
            .map { URL(fileURLWithPath: $0, relativeTo: packageDirectory) }
            ?? packageDirectory.deletingLastPathComponent().appendingPathComponent("sqlite")
        if FileManager.default.fileExists(atPath: sqliteSource.appendingPathComponent("src/parse.y").path) {
            toolArguments += ["--sqlite-source", sqliteSource.path]
        }
        process.arguments = toolArguments + extractor.remainingArguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            Diagnostics.error("sqlite-grammar exited with status \(process.terminationStatus)")
        }
    }
}
