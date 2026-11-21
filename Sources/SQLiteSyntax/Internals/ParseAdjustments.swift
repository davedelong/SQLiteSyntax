// Hand-written steps after parsing, for what SQLite does outside its grammar. The generated parsers
// call these for the rules listed in codegen.json `parseAdjustments`.

extension ColumnDefinition {

    /// `GENERATED` and `ALWAYS` are keywords that may be names, so SQLite's parser (like ours) takes
    /// `b INT GENERATED ALWAYS AS (…)` as type name `INT GENERATED ALWAYS` followed by the short form
    /// `AS (…)` of a generated column. SQLite's build.c (`sqlite3AddColumn`) then drops a trailing
    /// "generated always" from the type name. Do the same, and keep the words on the generated-column
    /// constraint that follows, so the value says what the SQL means.
    func adjustedAfterParsing() -> ColumnDefinition {
        guard let typeName, typeName.arguments == nil else { return self }
        let words = typeName.typeWords.items
        guard words.count >= 2,
              words[words.count - 2].value.uppercased() == "GENERATED",
              words[words.count - 1].value.uppercased() == "ALWAYS" else { return self }
        var result = self
        var typeWords = typeName.typeWords
        typeWords.items.removeLast(2)
        result.typeName = typeWords.items.isEmpty ? nil : TypeName(typeWords: typeWords, arguments: nil)
        if var first = result.constraints.first, first.name == nil,
           case .generated(false, let expression, let storage) = first.constraint {
            first.constraint = .generated(generatedAlways: true, expression: expression, storage: storage)
            result.constraints[0] = first
        }
        return result
    }
}
