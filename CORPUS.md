# Agreement with SQLite's test suite

`CorpusTests` extracts the SQL from SQLite's own test suite (`sqlite/test/*.test`), splits it into
statements with `sqlite3_complete`, and compares the parser's verdict with SQLite's
(`sqlite3_prepare_v2`). Statements both accept must also round-trip: SQLite accepts the re-printed
SQL, and parsing it again reproduces it.

Syntax newer than the linked SQLite counts as agreement when SQLite rejects it and building it for the
linked release throws `SyntaxError.unsupportedVersion`: the parser knows that SQLite can't run it. That covers
54 statements, the 3.52.0 `ALTER TABLE` constraint commands.

Ordered-set aggregates (`percentile(50) WITHIN GROUP (ORDER BY x)`, since 3.47.0) exist only in builds
compiled with `SQLITE_ENABLE_ORDERED_SET_AGGREGATES`; without it SQLite reads `WITHIN` as a name and fails at
`GROUP (`. The parser always accepts them, and building them for the linked SQLite throws
`SyntaxError.unsupportedOption` when it lacks the option, so the 19 such statements in `percentile.test`
count as agreement too. (The same check covers `ORDER BY`/`LIMIT` on `UPDATE` and `DELETE`, which need
`SQLITE_ENABLE_UPDATE_DELETE_LIMIT`; Apple's SQLite has it.)

SQLite's verdict comes from an in-memory database. The tests set up their own schema first, and SQLite
stops at a missing table before checking the rest of a statement, so when it reports a missing table,
database or column, the test creates it (a one-column table, an attached in-memory database, or a new
column) and prepares the statement again. Only syntax errors, errors raised by parse.y's own rule
actions, and a few errors that no schema can avoid (`count(DISTINCT)`, `ORDER BY` without `LIMIT` on
`DELETE`/`UPDATE`, `RETURNING t.*`) count as rejections.

Some of these rules sit outside SQLite's grammar diagrams. The parser enforces them with hand-written
checks (`Core/Restrictions.swift`, codegen.json `restrictions`), which also run when building SQL:
statements in a trigger body can't have `WITH`, `RETURNING`, `INSERT … DEFAULT VALUES` or
`INDEXED BY`/`NOT INDEXED` (parse.y `trigger_cmd`), `DISTINCT` takes exactly one argument, join
keywords must make a join type, and a constraint needs a name or a body.

    SQLITE_CORPUS=1 swift test -c release --filter CorpusTests

## Result (SQLite 3.51.0 linked; docs as of 2026-11)

| | Statements |
|---|---:|
| Distinct statements | 47,745 |
| Agree | 47,741 (99.99%) |
| SQLite accepts, parser rejects | 1 |
| SQLite rejects, parser accepts | 3 |
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
- (narrowing) pragma values are names, numbers and `ON`/`DELETE`/`DEFAULT` (parse.y `nmnum`), not other
  literals such as `NULL`
- `CONSTRAINT name` as a constraint of its own, in column and table constraint lists: names that chain
  (`CONSTRAINT a CONSTRAINT b CHECK (x)`) or trail (`UNIQUE (a) CONSTRAINT one`), as parse.y's
  `ccons`/`tcons` allow
- `[NOT] DEFERRABLE …` as a column constraint of its own
- no comma needed between table constraints after the first (parse.y `tconscomma`); the comma is always
  printed
- join keywords in any order or combination, up to three (`OUTER LEFT NATURAL JOIN`,
  `LEFT RIGHT JOIN`), checked as sqlite3JoinType() does; the usual forms keep their structured cases

Hand-written parsing follows parse.y the same way: `CAST(x AS )` with an empty type, string literals
as parts of a column name (`'t'.'c'`), empty module arguments beside a comma (`fts4(a, )`), and
`over`/`window` as names next to the `OVER`/`WINDOW` keywords (`sum(x) over over`), using
tokenize.c's rule for what counts as a name when deciding whether they are keywords. `UNBOUNDED` at the
start of a window frame bound is always the keyword (`RANGE BETWEEN UNBOUNDED FOLLOWING` is an error),
and negating a hex literal that reads as the smallest integer is "hex literal too big", as in expr.c.

## Remaining disagreements

### Parser accepts, SQLite rejects (3)

| Count | Reason | Assessment |
|---:|---|---|
| 2 | 50+ levels of nested subqueries/functions exceed SQLite's parser stack | Implementation limit, not syntax |
| 1 | `UPDATE t AS alias` in a trigger body: allowed since 3.52.0 (parse.y `xfullname`), and the version check can't see that it's in a trigger (it dates table aliases 3.24.0) | Correct per current SQLite |

### SQLite accepts, parser rejects (1)

| Count | Reason | Assessment |
|---:|---|---|
| 1 | An oversized hex literal in a trigger body: SQLite only compiles the body when the trigger runs, so `CREATE TRIGGER` succeeds | Parser is stricter; the trigger could never run |

No remaining disagreement is unexplained.
