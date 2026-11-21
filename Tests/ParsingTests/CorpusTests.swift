import Foundation
import SQLite3
import Testing
@testable import SQLiteSyntax

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
        try Self.onLargeStack(Self.compareWithSQLite)
    }

    /// Runs `body` on a thread with a 64 MB stack, waiting for it to finish.
    ///
    /// Swift Testing runs tests on the cooperative thread pool, whose threads have 512 KB stacks. The
    /// corpus includes fuzzed statements with subqueries nested dozens deep, which a debug build can't
    /// parse in 512 KB: the parser would reject them as too deeply nested (see `StackGuard`), and the
    /// results would depend on the build.
    static func onLargeStack(_ body: @escaping @Sendable () throws -> Void) throws {
        final class Result: @unchecked Sendable { var error: (any Error)? }
        let result = Result()
        let finished = DispatchSemaphore(value: 0)
        let thread = Thread {
            do { try body() } catch { result.error = error }
            finished.signal()
        }
        thread.stackSize = 64 << 20
        thread.start()
        finished.wait()
        if let error = result.error { throw error }
    }

    static func compareWithSQLite() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.testDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "test" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var seen = Set<String>()
        var outcomes: [Outcome] = []
        var roundTripFailures: [Outcome] = []
        for file in files {
            guard let text = (try? String(contentsOf: file, encoding: .utf8)) ?? (try? String(contentsOf: file, encoding: .isoLatin1)) else { continue }
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
                            // The linked SQLite accepted it, so building for its version must not object.
                            if case .failure(let error) = Result(catching: { () throws(SyntaxError) in
                                try parsed.sql(sqliteVersion: SQLiteVersion(number: sqlite3_libversion_number()))
                            }) {
                                roundTripFailures.append(Outcome(file: file.lastPathComponent, sql: statement, sqlite: sqlite, parser: parser,
                                                                 detail: "version check: \(error)"))
                            } else if Self.sqliteVerdict(output) != .accepted {
                                roundTripFailures.append(Outcome(file: file.lastPathComponent, sql: statement, sqlite: sqlite, parser: parser,
                                                                 detail: "SQLite rejects output: \(output)"))
                            } else if (try? SQLStatement(parsing: output).sql()) != output {
                                roundTripFailures.append(Outcome(file: file.lastPathComponent, sql: statement, sqlite: sqlite, parser: parser,
                                                                 detail: "re-parse differs: \(output)"))
                            }
                        }
                    } catch let error as ParseError {
                        let message = Self.sqliteMessage(statement)
                        detail = "parser: \(error) || sqlite: " + (message.isEmpty ? "prepares" : message)
                    } catch {
                        detail = "build: \(error)"   // building SQL failed
                    }
                    if sqlite == .rejected && parser == .accepted {
                        detail = "sqlite: " + Self.sqliteMessage(statement)
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
        print(Self.details("SQLite accepts, parser rejects", falseRejections))
        print(Self.details("SQLite rejects, parser accepts", falseAcceptances))
        print(Self.details("Round-trip failures", roundTripFailures))

        let reportPath = ProcessInfo.processInfo.environment["SQLITE_CORPUS_REPORT"]
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("sqlite-corpus-report.tsv").path
        let rows = (falseRejections.map { ("parser-rejects", $0) } + falseAcceptances.map { ("parser-accepts", $0) }
                    + roundTripFailures.map { ("round-trip", $0) })
            .map { kind, o in [kind, o.file, o.detail, o.sql].map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }.joined(separator: "\t") }
        try (["kind\tfile\tdetail\tsql"] + rows).joined(separator: "\n").write(toFile: reportPath, atomically: true, encoding: .utf8)
        print("report: \(reportPath)")
    }

    /// One entry per outcome: its file and statement, then each side's message on its own line.
    /// Statements longer than 300 characters are cut short; the report file has them in full.
    static func details(_ title: String, _ outcomes: [Outcome]) -> String {
        guard !outcomes.isEmpty else { return "" }
        let entries = outcomes.map { o in
            let flat = o.sql.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            let sql = flat.count > 300 ? flat.prefix(300) + "…" : flat
            let messages = o.detail.components(separatedBy: " || ").map { "      " + $0 }
            return (["  [\(o.file)] \(sql)"] + messages).joined(separator: "\n")
        }
        return "\n\(title) (\(outcomes.count)):\n" + entries.joined(separator: "\n")
    }

    // MARK: SQLite's verdict

    /// SQLite's prepare error, or "" if it prepares.
    ///
    /// The statements come from tests that set up their own schema first, and SQLite stops at a missing
    /// table or column before checking the rest. So when it reports one missing, that's created (a
    /// table, an attached in-memory database, or a column) and the statement is prepared again.
    static func sqliteMessage(_ sql: String) -> String {
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        defer { sqlite3_close(db) }
        var tables: [String] = []   // created so far, quoted
        var tried: Set<String> = []
        while true {
            var statement: OpaquePointer?
            let status = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            sqlite3_finalize(statement)
            if status == SQLITE_OK { return "" }
            let message = String(cString: sqlite3_errmsg(db))
            let setup = Self.setup(for: message, tables: tables).filter { tried.insert($0).inserted }
            // Statements that fail (a column already there, say) are fine as long as one does something.
            let succeeded = setup.filter { sqlite3_exec(db, $0, nil, nil, nil) == SQLITE_OK }
            guard !succeeded.isEmpty else { return message }
            tables += succeeded.compactMap { $0.hasPrefix("CREATE TABLE ") ? String($0.dropFirst(13).dropLast(3)) : nil }
        }
    }

    /// SQL that creates what `message` says is missing: a table, a database, or a column (added to the
    /// table it names, or to each table created so far).
    static func setup(for message: String, tables: [String]) -> [String] {
        func quoted<S: StringProtocol>(_ name: S) -> String { "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        func qualified(_ name: Substring) -> [String] { name.split(separator: ".").map(quoted) }
        if message.hasPrefix("no such table: ") {
            // `t1` or `main.t1`.
            return ["CREATE TABLE \(qualified(message.dropFirst("no such table: ".count)).joined(separator: "."))(x)"]
        }
        if message.hasPrefix("unknown database ") {
            return ["ATTACH ':memory:' AS \(quoted(message.dropFirst("unknown database ".count)))"]
        }
        if message.hasPrefix("no such column: ") {
            // `c`, `t.c` or `main.t.c`.
            let parts = qualified(message.dropFirst("no such column: ".count))
            let owners = parts.count > 1 ? [parts.dropLast().joined(separator: ".")] : tables
            return owners.map { "ALTER TABLE \($0) ADD COLUMN \(parts.last!)" }
        }
        return []
    }

    /// Accepted unless SQLite reports a syntax problem (unknown columns, functions etc. are fine).
    static func sqliteVerdict(_ sql: String) -> Verdict {
        let message = sqliteMessage(sql)
        if message.isEmpty { return .accepted }
        // Syntax errors, plus errors parse.y raises from its own rule actions (they are parse-time rejections).
        let syntax = ["syntax error", "incomplete input", "unrecognized token", "parser stack overflow",
                      "unterminated", "near \"", "unknown table option", "should come after", "not before",
                      "too many terms in compound SELECT", "is not an ordered-set aggregate",
                      "DISTINCT not allowed on ordered-set aggregate", "Recursion limit",
                      "clause is not allowed on UPDATE or DELETE statements within triggers",
                      "unknown join type", "hex literal too big", "a JOIN clause is required before", "unsupported use of NULLS",
                      "cannot use RETURNING in a trigger",
                      // Raised after parsing, but whatever the schema: the statement can never prepare.
                      "DISTINCT aggregates must have exactly one argument", "ORDER BY without LIMIT on",
                      "RETURNING may not use"]
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
