import Foundation
import SQLite3
import Testing
import SQLiteSyntax
@testable import SQLiteParser

/// Agreement with SQLite on the SQL in SQLite's own test suite (`sqlite/test/*.test`).
///
/// Opt-in; run in release mode:
///
///     SQLITE_CORPUS=1 swift test -c release --filter CorpusTests
///
/// Writes a tab-separated report of every disagreement to `$SQLITE_CORPUS_REPORT` (default: the
/// system temporary directory).
struct CorpusTests {

    static let testDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("sqlite/test")

    static var enabled: Bool {
        ProcessInfo.processInfo.environment["SQLITE_CORPUS"] == "1"
            && FileManager.default.fileExists(atPath: testDirectory.path)
    }

    enum Verdict: String { case accepted, rejected }

    struct Outcome {
        var file: String
        var sql: String
        var sqlite: Verdict
        var parser: Verdict
        var detail: String
    }

    @Test(.enabled(if: enabled, "set SQLITE_CORPUS=1 and provide ../sqlite"))
    func agreesWithSQLiteOnItsTestSuite() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.testDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "test" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var seen = Set<String>()
        var outcomes: [Outcome] = []
        var roundTripFailures: [Outcome] = []
        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) ?? String(contentsOf: file, encoding: .isoLatin1) else { continue }
            for script in Self.sqlScripts(in: text) {
                for statement in Self.statements(in: script) where seen.insert(statement).inserted {
                    // Comment-only fragments are not statements.
                    guard let tokens = try? Tokenizer(statement).tokenize(), tokens.count > 1 else { continue }
                    let sqlite = Self.sqliteVerdict(statement)
                    var parser = Verdict.rejected
                    var detail = ""
                    do {
                        let parsed = try SQLStatement(parsing: statement)
                        parser = .accepted
                        if sqlite == .accepted {
                            let output = try parsed.sql()
                            if Self.sqliteVerdict(output) != .accepted {
                                roundTripFailures.append(Outcome(file: file.lastPathComponent, sql: statement, sqlite: sqlite, parser: parser,
                                                                 detail: "SQLite rejects output: \(output)"))
                            } else if (try? SQLStatement(parsing: output).sql()) != output {
                                roundTripFailures.append(Outcome(file: file.lastPathComponent, sql: statement, sqlite: sqlite, parser: parser,
                                                                 detail: "re-parse differs: \(output)"))
                            }
                        }
                    } catch let error as ParseError {
                        detail = error.description + " || sqlite: " + Self.sqliteMessage(statement)
                    } catch {
                        detail = "\(error)"   // building SQL failed
                    }
                    outcomes.append(Outcome(file: file.lastPathComponent, sql: statement, sqlite: sqlite, parser: parser, detail: detail))
                }
            }
        }

        let agree = outcomes.filter { $0.sqlite == $0.parser }
        let falseRejections = outcomes.filter { $0.sqlite == .accepted && $0.parser == .rejected }
        let falseAcceptances = outcomes.filter { $0.sqlite == .rejected && $0.parser == .accepted }
        let summary = """
            statements: \(outcomes.count)  agree: \(agree.count) (\(String(format: "%.2f", 100 * Double(agree.count) / Double(max(outcomes.count, 1))))%)
            SQLite accepts, parser rejects: \(falseRejections.count)
            SQLite rejects, parser accepts: \(falseAcceptances.count)
            round-trip failures: \(roundTripFailures.count)
            """
        print(summary)

        let reportPath = ProcessInfo.processInfo.environment["SQLITE_CORPUS_REPORT"]
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("sqlite-corpus-report.tsv").path
        let rows = (falseRejections.map { ("parser-rejects", $0) } + falseAcceptances.map { ("parser-accepts", $0) }
                    + roundTripFailures.map { ("round-trip", $0) })
            .map { kind, o in [kind, o.file, o.detail, o.sql].map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }.joined(separator: "\t") }
        try (["kind\tfile\tdetail\tsql"] + rows).joined(separator: "\n").write(toFile: reportPath, atomically: true, encoding: .utf8)
        print("report: \(reportPath)")
    }

    // MARK: SQLite's verdict

    /// SQLite's prepare error, or "" if it prepares.
    static func sqliteMessage(_ sql: String) -> String {
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        return sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK ? "" : String(cString: sqlite3_errmsg(db))
    }

    /// Accepted unless SQLite reports a syntax problem (unknown tables, functions etc. are fine).
    static func sqliteVerdict(_ sql: String) -> Verdict {
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK { return .accepted }
        let message = String(cString: sqlite3_errmsg(db))
        // Syntax errors, plus errors parse.y raises from its own rule actions (they are parse-time rejections).
        let syntax = ["syntax error", "incomplete input", "unrecognized token", "parser stack overflow",
                      "unterminated", "near \"", "unknown table option", "should come after", "not before",
                      "too many terms in compound SELECT", "is not an ordered-set aggregate",
                      "DISTINCT not allowed on ordered-set aggregate", "Recursion limit",
                      "clause is not allowed on UPDATE or DELETE statements within triggers",
                      "unknown join type", "hex literal too big", "a JOIN clause is required before", "unsupported use of NULLS"]
        return syntax.contains { message.contains($0) } ? .rejected : .accepted
    }

    // MARK: Extraction

    /// SQL passed to the test harness in braces: `execsql {…}`, `catchsql {…}`, `db eval {…}`,
    /// `do_execsql_test NAME {…}`, `do_catchsql_test NAME {…}`.
    static func sqlScripts(in tcl: String) -> [String] {
        let chars = Array(tcl.unicodeScalars)
        var scripts: [String] = []
        let markers = ["execsql", "catchsql", "db eval", "do_execsql_test", "do_catchsql_test"]
        var i = 0
        func matches(_ word: String, at index: Int) -> Bool {
            let w = Array(word.unicodeScalars)
            guard index + w.count <= chars.count, Array(chars[index..<(index + w.count)]) == w else { return false }
            let before = index == 0 ? " " : chars[index - 1]
            return !(before.properties.isAlphabetic || before == "_")
        }
        while i < chars.count {
            guard let marker = markers.first(where: { matches($0, at: i) }) else { i += 1; continue }
            var j = i + marker.unicodeScalars.count
            func skipSpaces() { while j < chars.count, chars[j] == " " || chars[j] == "\t" { j += 1 } }
            skipSpaces()
            if marker.hasPrefix("do_") {
                // test name: one word
                while j < chars.count, !(chars[j] == " " || chars[j] == "\t" || chars[j] == "\n") { j += 1 }
                skipSpaces()
            }
            guard j < chars.count, chars[j] == "{" else { i = j; continue }
            var depth = 0
            var k = j
            while k < chars.count {
                if chars[k] == "\\" { k += 2; continue }
                if chars[k] == "{" { depth += 1 }
                if chars[k] == "}" { depth -= 1; if depth == 0 { break } }
                k += 1
            }
            guard k < chars.count else { break }
            scripts.append(String(String.UnicodeScalarView(chars[(j + 1)..<k])))
            i = k + 1
        }
        return scripts
    }

    /// Splits a script into complete statements using SQLite's own `sqlite3_complete`.
    static func statements(in script: String) -> [String] {
        var result: [String] = []
        var current = ""
        for piece in script.split(separator: ";", omittingEmptySubsequences: false) {
            current += piece + ";"
            if sqlite3_complete(current) != 0 {
                let statement = current.trimmingCharacters(in: .whitespacesAndNewlines)
                let body = String(statement.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty, !body.hasPrefix("--") || body.contains("\n") { result.append(body) }
                current = ""
            }
        }
        return result
    }
}
