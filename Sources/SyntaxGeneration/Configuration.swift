/// Hand-maintained input to the code generator (`Grammar/codegen.json`).
public struct CodegenConfiguration: Decodable, Sendable {

    /// Diagram rules to generate types for, e.g. `"frame-spec"`.
    public var rules: [String]

    /// Swift types for references to rules that are *not* generated (still hand-written),
    /// e.g. `"expr": "Expression"`.
    public var references: [String: String]

    /// Swift types for lexical tokens (lowercase ovals), e.g. `"collation-name": "Name<Collation>"`.
    public var tokens: [String: String]

    /// Existing Swift enums to reuse for keyword-only choices, keyed by their keywords joined with `|`
    /// in grammar order, e.g. `"ASC|DESC": "SortDirection"`.
    public var keywordEnums: [String: String]

    /// Name overrides, keyed by the generator's default name qualified by the owning type,
    /// e.g. `"FrameSpec.option": "unit"` (a field or case) or `"type:frame-spec": "WindowFrame"` (a rule's type).
    /// The generator lists every fallback name it had to invent, so they can be added here.
    public var names: [String: String]

    /// The namespace enum generated types are nested in; empty for top-level types.
    public var namespace: String

    /// Emit public types with public memberwise initialisers (for the library's API).
    public var isPublic: Bool

    /// Helper rules in the grammar file's EBNF format (Gramophone syntax, `_` for `-`), generated like
    /// diagram rules. Wherever a diagram contains a fragment with exactly the same syntax, it references
    /// the helper instead, so repeated fragments (e.g. `LIMIT …`) share one type.
    public var extraRules: String

    enum CodingKeys: String, CodingKey { case rules, references, tokens, keywordEnums, names, namespace, extraRules, isPublic = "public" }

    public init(rules: [String], references: [String: String] = [:], tokens: [String: String] = [:],
                keywordEnums: [String: String] = [:], names: [String: String] = [:], namespace: String = "Generated",
                extraRules: String = "", isPublic: Bool = false) {
        self.rules = rules
        self.references = references
        self.tokens = tokens
        self.keywordEnums = keywordEnums
        self.names = names
        self.namespace = namespace
        self.extraRules = extraRules
        self.isPublic = isPublic
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rules = try c.decode([String].self, forKey: .rules)
        references = try c.decodeIfPresent([String: String].self, forKey: .references) ?? [:]
        tokens = try c.decodeIfPresent([String: String].self, forKey: .tokens) ?? [:]
        keywordEnums = try c.decodeIfPresent([String: String].self, forKey: .keywordEnums) ?? [:]
        names = try c.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        namespace = try c.decodeIfPresent(String.self, forKey: .namespace) ?? "Generated"
        isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        // A string, or an array of lines (easier to read in JSON).
        if let lines = try? c.decodeIfPresent([String].self, forKey: .extraRules) {
            extraRules = lines.joined(separator: "\n")
        } else {
            extraRules = try c.decodeIfPresent(String.self, forKey: .extraRules) ?? ""
        }
    }
}
