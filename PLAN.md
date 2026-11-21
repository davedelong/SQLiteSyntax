# SQLiteSyntax: Status

The goal: syntax types generated from SQLite's own syntax diagrams, covering the whole grammar, working
in both directions — building SQL (`sql()`) and parsing it (`init(parsing:)`) — with SQLite itself as
the test oracle. That's done. This page says what exists, how well it agrees with SQLite, what's
deliberately left out, and the decisions behind it. Detail lives in the READMEs, `CORPUS.md` and the
commit history.

## What exists

| Piece | Where | State |
|---|---|---|
| Grammar extraction | `SQLiteSyntaxGenerator` (`GrammarExtraction`, `sqlite-grammar` tool) | 71 diagrams → `Grammar/sqlite.ebnf`, each rule checked against its diagram. |
| Type generation | `SQLiteSyntaxGenerator` (`SyntaxGeneration`, `Grammar/codegen.json`) | 62 rules plus 5 helper rules (`extraRules`) → `Generated/` here, with no warnings. Also generates the precedence and keyword tables from `src/parse.y` and `tool/mkkeywordhash.c`. |
| Generated types | `Sources/SQLiteSyntax/Generated/` | Three files per type: `Base/` (the type), `Builder/` (`build(using:)`), `Parser/` (`parse(_:)`). Each type, case and optional part knows the release that introduced it. |
| Hand-written types | `Core/` | `Expression`, `LiteralValue`, `NumericLiteral`, `BindParameter`, `Name`, `List`, `ModuleArgument`, the operators, `SortDirection`, `SQLiteVersion`, `Syntax`/`SyntaxBuilder`, and the restriction checks (`Restrictions.swift`). |
| Parsing | `Internals/` | Tokenizer (following `sqlite3GetToken`), precedence-climbing expression parser, and the packrat runtime the generated parsers use. |
| Builder API | `Convenience/` | Operators, literal conformances, `Table.Create`, `Select.star(from:)` and friends. |

Every `Syntax` value can:

- **build SQL** for a target release (`sql(sqliteVersion:)`, by default the linked SQLite), throwing
  `SyntaxError.unsupported` for syntax that release can't run and `invalidSyntax` for values SQLite
  would misread (raw text that isn't one token, NUL characters, incomplete names, …);
- **parse** with `init(parsing:)`;
- report its **`minimumRequiredVersion`**.

## Agreement with SQLite

On SQLite's own test suite (47,745 distinct statements, SQLite 3.51.0 linked): **99.99% agreement, 0
round-trip failures.** The 4 disagreements are all explained in `CORPUS.md`: parser-stack limits, one
trigger alias valid only from 3.52.0, and one oversized hex literal in a trigger body. Syntax newer than
the linked SQLite (54 statements) and `WITHIN GROUP` without ordered-set aggregates (19) count as
agreement.

## Deliberately not done

- **Errors about meaning, not syntax.** SQLite reports these when preparing, and the library doesn't
  repeat them: `RAISE()` outside a trigger, function argument counts, the `?N` upper limit, unknown
  tables or columns.
- **Rare legacy syntax** that parse.y accepts but the diagrams don't draw is supported only where it
  matters in practice (`grammarPatches`); the rest is documented in `CORPUS.md`.
- **Build-option syntax.** The keyword tables follow SQLite's default build, so `WITHIN` is a name.
  `WITHIN GROUP` is still parsed, since a name can't be followed by `GROUP (`.

## Decisions

1. **Packages**: the generator lives in the sibling `SQLiteSyntaxGenerator`; this package has no
   dependencies.
2. **Literals**: typed. `LiteralValue.integer(Int64)` / `.real(Double)`, and `NumericLiteral` the same,
   following SQLite's INTEGER/REAL rules.
3. **Naming**: names come from the grammar, rewritten by `nameWords` rules in codegen.json (drop
   "Clause", "SQL" in capitals, "Def" → "Definition"). `names` overrides cover what the grammar can't
   name well (placeholders like `option`, misleading names) and the few places a shorter name reads
   better (`.with`, `ColumnDefinition.name`, `OrderBy.terms`). The generator warns about overrides
   that match nothing.
4. **Where parsers live**: generated next to each type in `Generated/Parser`, in the one library.
5. **Grammar authority**: the diagrams, plus targeted `grammarPatches` from parse.y and hand-written
   restrictions for rules SQLite enforces outside its grammar.
6. **One representation per form**: each piece of SQL has one shape in the types. Operators with their
   own `Expression` case (`IS`, `IN`, `LIKE`, `COLLATE`, …) aren't also `BinaryOperator`/`UnaryOperator`
   cases, and unused generated types (the function-invocation diagrams, `recursive-cte`, `with-clause`)
   aren't generated.

## Keeping it current

When SQLite adds syntax: update the `../sqlite` and docs checkouts, regenerate (see
`SQLiteSyntaxGenerator/README.md`), fix any generator warnings, and run the corpus test
(`SQLITE_CORPUS=1 swift test -c release --filter CorpusTests`). Classify any new disagreement in
`CORPUS.md`.
