# SQLiteSyntax: Remaining Implementation Plan

Goal: the library's syntax types are generated from SQLite's own syntax diagrams, cover the
whole grammar, and work in both directions — building SQL (`sql()`) and parsing it
(`init(parsing:)`) — with SQLite itself as the test oracle.

## Where things stand (2026-11-20)

| Piece | State |
|---|---|
| Grammar extraction (`GrammarExtraction`, `sqlite-grammar`, `generate-grammar` plugin) | Done. 71 diagrams → `Grammar/sqlite.ebnf`, each rule verified equal to its diagram, written/read with Gramophone, round-trip checked. |
| Type generation (`SyntaxGeneration`, `Grammar/codegen.json`) | Prototype. 10 rules generated into `Sources/SQLiteSyntax/Generated` (internal `Generated` namespace). All 66 rules (SELECT family included) generate and compile in a scratch run; reference cycles are broken with `indirect enum`. |
| Expression parser (`SQLiteParser`) | Prototype. Full expression grammar except subqueries and `WITHIN GROUP`; agrees with SQLite on all tested inputs and all 147 keywords. |
| Hand-written fixes | Done: `FILTER … WHERE`, `t.a` dots, blob zero-padding, identifier quoting, operator parentheses. |
| Known issues | None. |
| Uncommitted | Everything since "first pass at generating an ebnf". |

## Phase 0 — Commit (now)

- Commit the current work on `grammar-extraction`, including `Package.resolved`.
- Decide later (before tagging a release) whether the tooling moves to its own package; the
  Gramophone/Flexer branch dependencies block versioned consumers. See "Open decisions".

## Phase 1 — Literal fidelity ✅ done

Done: `LiteralValue.number(Decimal)` was replaced by `.integer(Int64)` and `.real(Double)`; the
parser follows SQLite's INTEGER/REAL rules (including hex and `-9223372036854775808`), and
`numericLiteralsKeepTheirType` checks results against SQLite. Original notes:

`LiteralValue.number(Decimal)` cannot distinguish `1`, `1.0`, `1e3`, so REAL literals become
INTEGER and results change (`1.0 / 2` → `1 / 2` = 0).

- Change `LiteralValue` to keep the kind: e.g. `.integer(Int64)` and `.real(Double)`, or keep
  `.number` but store the literal's spelling (`.numeric(String)`) so hex and exponents survive.
  Public API change; update `Convenience/LiteralValue+Convenience.swift` and literal conformances
  (`ExpressibleByIntegerLiteral` → integer, `ExpressibleByFloatLiteral` → real).
- Parser: produce the new cases.
- Done when: `realLiteralsKeepTheirType` passes without `withKnownIssue`.

## Phase 2 — Generator: recursive types ✅ done

Done: `SyntaxGeneration/Recursion.swift` finds cycles of inline references (Tarjan SCCs; lists and
arrays don't count) and marks every enum on a cycle `indirect`. A struct-only cycle boxes one field
at a time with the generated `@Indirect` property wrapper (a one-case `indirect enum`) until none
remain. For SQLite's grammar, five enums become indirect (`TableOrSubquery`, `SelectStatement.Option`
and its nested `From` chain) and no fields need boxing. All 66 rules compile; SELECT statements built
with them (subquery, CTE, compound, VALUES) are accepted by SQLite (scratch run).
`SyntaxGenerationTests/RecursionTests` covers both strategies. Original notes:

The SELECT rules reference each other (`select-stmt` → `table-or-subquery` → `select-stmt`)
as plain structs; Swift needs indirection, and today the compiler crashes instead of erroring.

- Build the reference graph of generated rules; find strongly connected components.
- Within a cycle: emit enums as `indirect enum`; for struct fields that point into the cycle,
  store through a generated copy-on-write `Box`/property wrapper (keeps value semantics and
  the memberwise API).
- Done when: generating all 66 non-hand-written rules (the scratch config) compiles and the
  `GeneratedSyntaxTests` pattern passes for the SELECT family.

## Phase 3 — Generator: complete the configuration ✅ done

Done: all 67 diagram rules (everything except the hand-written `expr`, `literal-value`,
`numeric-literal`, and `comment-syntax`) plus 5 helper rules generate into `Generated/` and compile
with zero warnings (`ConfigurationTests`). New generator features: rule recognition (a fragment with
exactly another rule's syntax references that rule, e.g. select-stmt → select-core,
`( col, … )` → column-name-list), helper rules in `codegen.json` (`extraRules`: `Limit`,
`OrderBy`, `With`, `ValuesClause`, `IndexHint`), and better default names (nearest keywords,
first value, acronyms). Original notes:

From the full scratch run: ~84 unmapped-token warnings, 78 fallback names, 4 duplicate members.

- `tokens`: map every lexical token (`table-name` → `Name<Table>`, `schema-name` → `Name<Schema>`,
  `alias`/`column-alias`/`table-alias`, `signed-literal`, `module-argument`, `filename`, …).
- `names`: add overrides, matching existing hand-written names where they exist to minimise
  churn (e.g. `FrameSpec.Unit` → `Target`).
- Review each generated shape against its hand-written counterpart; add generator rules
  (not overrides) where the same fix recurs.
- Done when: a full generation run prints no warnings.

## Phase 4 — Migrate to generated types ✅ done

Done: generated types are public, top-level, with public memberwise initialisers (`codegen.json`
`"namespace": ""`, `"public": true`). 60 hand-written types were deleted; `Core/` keeps only
`Expression`, `LiteralValue`, `BindParameter`, `Name`, `List`, `Group`, operators, `SortDirection`,
`Syntax`, and the token types `NumericLiteral`/`ModuleArgument`. `Expression` now uses the generated
`FunctionArguments`, `FilterClause`, `OverClause`, `TypeName`, `RaiseFunction`, `SelectStatement`.
The `Convenience/` layer keeps its API (`Table.Create`, `Select.star(from:)`, `ColumnDefinition.primaryKey`…)
and the original tests pass with unchanged SQL. Generator: `{ sep x }` becomes `[X]` (separator before
each item). Original notes:

- Make generated types public with public memberwise initialisers; drop the `Generated`
  namespace as each type replaces its hand-written original.
- Order: leaf rules first (conflict-clause, ordering-term, frame-spec, join-operator, …),
  then clauses, then statements. One rule per change; delete the hand-written file each time.
- Keep hand-written: `Expression`, `LiteralValue`, `BindParameter`, `Name`, `List`, operators,
  and the `Convenience/` layer (adapted to the new types).
- Point `Expression`'s references (`SelectStatement`, `OverClause`, `FrameSpec`, …) at the
  generated types.
- Tests per migrated rule: exact SQL, and `sqlite3_prepare` acceptance in context (the
  `GeneratedSyntaxTests` pattern). Consider generating sample values from the grammar
  (the extractor can already enumerate sentences) to cover every case automatically.
- Done when: `Core/` contains only the intentionally hand-written types; all tests pass.

## Phase 5 — Generate parsers (3–5 days)

- Generator emits a parse function next to each `build(using:)`, from the same template:
  fixed tokens → expect; stored value → parse that type; flag → accept keywords;
  optional → try and rewind; list → separated items; enum → try cases.
- Emit them into `Sources/SQLiteParser/Generated/` (keeps parsing out of the core library;
  requires the public initialisers from Phase 4).
- Parser runtime: memoise (type, position) results (packrat) since alternatives often share
  long prefixes (`expr PRECEDING | expr FOLLOWING`); keep the farthest-failure error with the
  set of expected tokens.
- Names: extend `Keywords` from the single `idj` rule to parse.y's name classes per position
  (`nm` = ID|INDEXED|JOIN_KW|STRING, `ids`, `id`), so e.g. aliases reject reserved words.
- Replace the hand-written sub-parsers in `ExpressionParser` (window, frame, ordering term,
  type name, raise) with the generated ones; keep the precedence parser for `expr` itself.
- Subqueries now work: remove the "not supported yet" errors.
- Done when: `Expression(parsing:)` handles `(SELECT …)`, `EXISTS`, `IN (SELECT …)`, and
  statements parse via generated types.

## Phase 6 — Statement-level API (1 day)

- `SQLStatement(parsing:)` and a statement-list parser (`;`-separated, `EXPLAIN [QUERY PLAN]`).
- Consistent error type and positions across expression and statement parsing.

## Phase 7 — Corpus agreement testing (2–3 days)

- Extract SQL from SQLite's test suite (`sqlite/test/*.test`: `execsql {…}`, `catchsql {…}`),
  de-duplicate, and run each through our parser and `sqlite3_prepare` against a permissive
  schema (only syntax errors count).
- Known so far: SQLite rejects `ORDER BY`/`LIMIT` after a `VALUES` clause (explicit check in
  parse.y), although the select-stmt diagram allows it.
- Classify every disagreement: diagram vs parse.y differences (e.g. legacy `NULL` column
  constraint, `DEFAULT identifier`) to document or support; bugs to fix.
- Also round-trip each accepted statement: parse → `sql()` → SQLite accepts → parse again equal.
- Done when: all disagreements are classified and the bug list is empty.

## Phase 8 — Hardening and cleanup (2–3 days)

- Single source for the precedence and keyword tables: have `sqlite-grammar` extract them from
  `parse.y`/`mkkeywordhash.c` and generate them into both `SQLiteSyntax` and `SQLiteParser`
  (today the precedence table is duplicated; a test catches drift).
- `Expression: ExpressibleByNilLiteral` turns `nil` into SQL `NULL` in `Expression?` contexts
  (it caused a parser bug). Consider removing it or replacing with an explicit `.null`.
- `sql()` does not run `validate()` on the top-level value; decide whether it should.
- Portability: `SQLiteParser` reads the keyword list from the system SQLite at runtime; embed it
  (from Phase 8's generated table) if Linux or a bundled SQLite build matters.
- README: workflow for regenerating (`swift package --allow-writing-to-package-directory
  generate-grammar`), `codegen.json`, and how to migrate a rule.

## Open decisions

1. **Tooling package split.** Keep the grammar tooling in this package (current) or move it to a
   sibling package so library consumers never fetch Gramophone/Flexer/swift-markdown and the
   library can be tagged. Needed before the first release tag.
2. ~~**`LiteralValue` shape**~~ — decided: typed `.integer(Int64)` / `.real(Double)`.
3. **Generated naming policy** (Phase 3–4): match existing hand-written names, or accept
   grammar-derived names and update the `Convenience/` layer.
4. **Where generated parsers live** (Phase 5): `SQLiteParser` (planned) vs alongside the types.
5. **Grammar authority for validation**: the diagrams (current) or parse.y's broader legacy
   syntax; Phase 7 will show how much the difference matters in practice.

## Rough total

About 3–4 weeks of focused work: Phases 1–4 (~1.5–2 weeks) make the generated types the
library; Phases 5–7 (~1.5 weeks) make them parse and prove agreement with SQLite.
