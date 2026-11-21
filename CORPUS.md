# Agreement with SQLite's test suite

`CorpusTests` extracts the SQL from SQLite's own test suite (`sqlite/test/*.test`), splits it into
statements with `sqlite3_complete`, and compares the parser's verdict with SQLite's
(`sqlite3_prepare_v2`). Statements both accept must also round-trip: SQLite accepts the re-printed
SQL, and parsing it again reproduces it.

SQLite's verdict comes from an in-memory database. The tests set up their own schema first, and SQLite
stops at a missing table before checking the rest of a statement, so when it reports a missing table,
database or column, the test creates it (a one-column table, an attached in-memory database, or a new
column) and prepares the statement again. Only syntax errors, errors raised by parse.y's own rule
actions, and a few errors that no schema can avoid (`count(DISTINCT)`, `ORDER BY` without `LIMIT` on
`DELETE`/`UPDATE`, `RETURNING t.*`) count as rejections.

Some of these rules sit outside SQLite's grammar diagrams. The parser enforces them with hand-written
checks (`Core/Restrictions.swift`, codegen.json `restrictions`), which also run when building SQL:
statements in a trigger body can't have `WITH`, `RETURNING`, `INSERT … DEFAULT VALUES` or
`INDEXED BY`/`NOT INDEXED` (parse.y `trigger_cmd`), and `DISTINCT` takes exactly one argument.

    SQLITE_CORPUS=1 swift test -c release --filter CorpusTests

## Result (SQLite 3.51.0 linked; docs as of 2026-11)

| | Statements |
|---|---:|
| Distinct statements | 47,745 |
| Agree | 47,668 (99.84%) |
| SQLite accepts, parser rejects | 17 |
| SQLite rejects, parser accepts | 60 |
| Round-trip failures | 0 |

## Syntax added from parse.y (`codegen.json` `grammarPatches`)

The diagrams omit some syntax SQLite accepts. These patches widen the generated grammar (the
extracted `sqlite.ebnf` stays faithful to the diagrams):

- `PRAGMA x = ON | DELETE | DEFAULT`
- a bare `NULL` column constraint; `DEFAULT identifier`
- `USING module()` with no arguments
- `NATURAL CROSS JOIN`
- an alias after a parenthesized join or table list: `FROM (a, b) AS c`
- `ON schema.table` in `CREATE TRIGGER`
- `count(ALL x)`; table-valued functions with no arguments: `pragma_table_list()`
- `ON CONFLICT` after a table `CHECK` constraint
- any expression in `ATTACH … AS expr` and `DETACH expr` (e.g. bind parameters)
- a name after `TRANSACTION` in `BEGIN`, `COMMIT`/`END` and `ROLLBACK`: `BEGIN TRANSACTION 'foo'`
- a sign before any literal in `DEFAULT`: `DEFAULT -'hello'`
- `ORDER BY` with no arguments in a function call: `count(ORDER BY a)`
- (narrowing) `LIMIT` is required after `ORDER BY` in `UPDATE`, as the `DELETE` diagram already has it

Hand-written parsing follows parse.y the same way: `CAST(x AS )` with an empty type, string literals
as parts of a column name (`'t'.'c'`), empty module arguments beside a comma (`fts4(a, )`), and
`over`/`window` as names next to the `OVER`/`WINDOW` keywords (`sum(x) over over`), using
tokenize.c's rule for what counts as a name when deciding whether they are keywords.

## Remaining disagreements

### Parser accepts, SQLite rejects (60)

| Count | Reason | Assessment |
|---:|---|---|
| 53 | `ALTER TABLE … ADD [CONSTRAINT name] CHECK`, `DROP CONSTRAINT`, `ALTER COLUMN … SET/DROP NOT NULL`: in the 2025-11 docs, newer than the linked SQLite 3.51.0 | Correct per the docs |
| 1 | `UPDATE t AS alias` in a trigger body: allowed by the current parse.y (`xfullname`), not by the linked 3.51.0 | Correct per current SQLite |
| 2 | 50+ levels of nested subqueries/functions exceed SQLite's parser stack | Implementation limit, not syntax |
| 2 | `RANGE BETWEEN UNBOUNDED FOLLOWING …`: `UNBOUNDED` is read as a column name | Known limit of the keyword-fallback approximation in the hand-written expression parser |
| 1 | `PRAGMA compile_options(NULL)`: the diagram's `signed-literal` admits NULL, parse.y does not | Diagram vs parse.y |
| 1 | `-0x08000000000000000`: SQLite rejects the 17-digit hex literal | Edge case |

### SQLite accepts, parser rejects (17)

| Count | Reason | Assessment |
|---:|---|---|
| 11 | Legacy constraint lists: a standalone or chained `CONSTRAINT name`, table constraints without commas between them, `[NOT] DEFERRABLE …` as a column constraint on its own | parse.y legacy, not in the diagrams; not supported yet |
| 5 | Join keywords in any order or combination: `OUTER LEFT NATURAL JOIN`, `LEFT RIGHT JOIN` (= `FULL`), `NATURAL LEFT FULL JOIN`. parse.y accepts `JOIN_KW [nm [nm]] JOIN` and sqlite3JoinType() accepts any consistent set of keywords | SQLite accepts them; not supported yet |
| 1 | An oversized hex literal in a trigger body: SQLite only compiles the body when the trigger runs, so `CREATE TRIGGER` succeeds | Parser is stricter; the trigger could never run |

No remaining disagreement is unexplained. One known approximation remains: keyword fallback in frame
bounds (`RANGE BETWEEN UNBOUNDED FOLLOWING`).
