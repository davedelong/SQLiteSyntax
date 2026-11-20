import SQLite3

/// SQLite's keyword classes, following `src/parse.y` and `tool/mkkeywordhash.c` in the SQLite sources.
enum Keywords {

    /// Every keyword the linked SQLite library recognises (`sqlite3_keyword_name`).
    static let all: Set<String> = {
        var keywords = Set<String>()
        for i in 0..<sqlite3_keyword_count() {
            var chars: UnsafePointer<CChar>?
            var count: Int32 = 0
            guard sqlite3_keyword_name(i, &chars, &count) == SQLITE_OK, let chars else { continue }
            let bytes = UnsafeRawBufferPointer(start: chars, count: Int(count))
            keywords.insert(String(decoding: bytes, as: UTF8.self).uppercased())
        }
        return keywords
    }()

    /// Keywords that fall back to being identifiers where the keyword itself would not parse
    /// (`%fallback ID …` in parse.y, for a default build: window functions and generated columns enabled).
    static let fallbackToIdentifier: Set<String> = [
        "ABORT", "ACTION", "AFTER", "ANALYZE", "ASC", "ATTACH", "BEFORE", "BEGIN", "BY", "CASCADE", "CAST", "COLUMN",
        "CONFLICT", "DATABASE", "DEFERRED", "DESC", "DETACH", "DO",
        "EACH", "END", "EXCLUSIVE", "EXPLAIN", "FAIL", "FOR",
        "IGNORE", "IMMEDIATE", "INITIALLY", "INSTEAD", "LIKE", "GLOB", "REGEXP", "MATCH", "NO", "PLAN",
        "QUERY", "KEY", "OF", "OFFSET", "PRAGMA", "RAISE", "RECURSIVE", "RELEASE", "REPLACE", "RESTRICT", "ROW", "ROWS",
        "ROLLBACK", "SAVEPOINT", "TEMP", "TEMPORARY", "TRIGGER", "VACUUM", "VIEW", "VIRTUAL", "WITH", "WITHOUT",
        "NULLS", "FIRST", "LAST",
        "CURRENT", "FOLLOWING", "PARTITION", "PRECEDING", "RANGE", "UNBOUNDED",
        "EXCLUDE", "GROUPS", "OTHERS", "TIES",
        "GENERATED", "ALWAYS",
        "MATERIALIZED",
        "REINDEX", "RENAME", "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP", "IF",
    ]

    /// `JOIN_KW` keywords; usable as identifiers wherever parse.y accepts `idj`.
    static let joinKeywords: Set<String> = ["CROSS", "FULL", "INNER", "LEFT", "NATURAL", "OUTER", "RIGHT"]

    /// Keywords the tokenizer only treats as keywords in specific contexts (tokenize.c
    /// `analyzeWindowKeyword` etc.); elsewhere they are plain identifiers.
    static let contextual: Set<String> = ["WINDOW", "OVER", "FILTER"]

    /// Whether a keyword can stand for a name (column, table, function), i.e. parse.y's `idj` after
    /// fallback: ID | INDEXED | JOIN_KW. (Fallback is per token, so aliases like TEMPORARY -> TK_TEMP count.)
    /// Where a keyword can itself start an expression (CAST, RAISE, CURRENT_DATE…), it is not
    /// a name at the start of an operand; see `Parser.parsePrefix`.
    static func usableAsName(_ keyword: String) -> Bool {
        usableAsName(keyword, class: .name)
    }

    static func usableAsName(_ keyword: String, class nameClass: NameClass) -> Bool {
        switch nameClass {
            // WINDOW, OVER and FILTER are only left as keywords where they act as keywords (the
            // tokenizer turns other uses into identifiers), so as keywords they are never names.
            case .name:
                return fallbackToIdentifier.contains(keyword) || joinKeywords.contains(keyword) || keyword == "INDEXED"
            case .alias:
                // parse.y `ids` is ID|STRING: no JOIN_KW or INDEXED, so `FROM a LEFT JOIN b` has no alias.
                return fallbackToIdentifier.contains(keyword)
        }
    }

    /// `LIKE_KW`: the pattern-matching operators.
    static let likeOperators: Set<String> = ["LIKE", "GLOB", "REGEXP", "MATCH"]

    /// `CTIME_KW`: the current-time literals.
    static let timeLiterals: Set<String> = ["CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP"]
}
