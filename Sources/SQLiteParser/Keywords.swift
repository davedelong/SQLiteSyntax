import SQLiteSyntax

/// SQLite's keyword classes (generated into SQLiteSyntax's `SQLiteTables.swift` from parse.y and
/// mkkeywordhash.c), plus the parser's contextual rules.
enum Keywords {

    static let all = SQLiteKeywords.all
    static let fallbackToIdentifier = SQLiteKeywords.fallbackToIdentifier
    static let joinKeywords = SQLiteKeywords.joinKeywords
    static let timeLiterals = SQLiteKeywords.timeLiterals

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
}
