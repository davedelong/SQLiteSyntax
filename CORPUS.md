# Agreement with SQLite's test suite

`CorpusTests` extracts the SQL from SQLite's own test suite (`sqlite/test/*.test`), splits it into
statements with `sqlite3_complete`, and compares the parser's verdict with SQLite's
(`sqlite3_prepare_v2` against an empty database; only syntax errors, and errors raised by parse.y's
own rule actions, count as rejections). Statements both accept must also round-trip: SQLite accepts
the re-printed SQL, and parsing it again reproduces it.

    SQLITE_CORPUS=1 swift test -c release --filter CorpusTests

## Result (SQLite 3.51.0 linked; docs as of 2026-11)

| | Statements |
|---|---:|
| Distinct statements | 47,745 |
| Agree | 47,666 (99.83%) |
| SQLite accepts, parser rejects | 30 |
| SQLite rejects, parser accepts | 49 |
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

Hand-written parsing follows parse.y the same way: `CAST(x AS )` with an empty type, string literals
as parts of a column name (`'t'.'c'`), empty module arguments beside a comma (`fts4(a, )`), and
`over`/`window` as names next to the `OVER`/`WINDOW` keywords (`sum(x) over over`), using
tokenize.c's rule for what counts as a name when deciding whether they are keywords.

## Remaining disagreements

### Parser accepts, SQLite rejects (49)

| Count | Reason | Assessment |
|---:|---|---|
| 43 | `ALTER TABLE … ADD/DROP CONSTRAINT`, `ALTER COLUMN … SET/DROP NOT NULL`: in the 2025-11 docs, newer than the linked SQLite 3.51.0 | Correct per the docs |
| 2 | 50+ levels of nested subqueries/functions exceed SQLite's parser stack | Implementation limit, not syntax |
| 2 | `RANGE BETWEEN UNBOUNDED FOLLOWING …`: `UNBOUNDED` is read as a column name | Known limit of the keyword-fallback approximation in the hand-written expression parser |
| 1 | `PRAGMA compile_options(NULL)`: the diagram's `signed-literal` admits NULL, parse.y does not | Diagram vs parse.y |
| 1 | `-0x08000000000000000`: SQLite rejects the 17-digit hex literal | Edge case |

### SQLite accepts, parser rejects (30)

| Count | Reason | Assessment |
|---:|---|---|
| 14 | SQLite stops at a missing table or database before the real error. With the tables created, SQLite rejects them too: syntax errors (`ALTER TABLE t ADD COLUMN (…`, `SELECT * FROM;` and `#N` parameters in trigger bodies, `#2` in `ADD CONSTRAINT`, trailing `%WO%`), `count(DISTINCT)` ×3, `DELETE … ORDER BY` without `LIMIT` ×2, `RETURNING t.*`, and oversized hex literals ×2 (in a trigger body SQLite only notices when the trigger runs) | Parser is right; the test's empty database hides SQLite's error |
| 11 | Legacy constraint lists: a standalone or chained `CONSTRAINT name`, table constraints without commas between them, `[NOT] DEFERRABLE …` as a column constraint on its own | parse.y legacy, not in the diagrams; not supported yet |
| 5 | Join keywords in any order or combination: `OUTER LEFT NATURAL JOIN`, `LEFT RIGHT JOIN` (= `FULL`), `NATURAL LEFT FULL JOIN`. parse.y accepts `JOIN_KW [nm [nm]] JOIN` and sqlite3JoinType() accepts any consistent set of keywords | SQLite accepts them; not supported yet |

No remaining disagreement is an unexplained parser bug. One known approximation remains: keyword
fallback in frame bounds (`RANGE BETWEEN UNBOUNDED FOLLOWING`), documented above.
