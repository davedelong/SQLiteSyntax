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
| Agree | 47,656 (99.81%) |
| SQLite accepts, parser rejects | 40 |
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

## Remaining disagreements

### Parser accepts, SQLite rejects (49)

| Count | Reason | Assessment |
|---:|---|---|
| 43 | `ALTER TABLE … ADD/DROP CONSTRAINT`, `ALTER COLUMN … SET/DROP NOT NULL`: in the 2025-11 docs, newer than the linked SQLite 3.51.0 | Correct per the docs |
| 2 | 50+ levels of nested subqueries/functions exceed SQLite's parser stack | Implementation limit, not syntax |
| 2 | `RANGE BETWEEN UNBOUNDED FOLLOWING …`: `UNBOUNDED` is read as a column name | Known limit of the keyword-fallback approximation in the hand-written expression parser |
| 1 | `PRAGMA compile_options(NULL)`: the diagram's `signed-literal` admits NULL, parse.y does not | Diagram vs parse.y |
| 1 | `-0x08000000000000000`: SQLite rejects the 17-digit hex literal | Edge case |

### SQLite accepts, parser rejects (40)

| Count | Reason | Assessment |
|---:|---|---|
| 10 | Legacy constraint lists: chained or trailing `CONSTRAINT name`, table constraints without commas | parse.y legacy, not in the diagrams; not supported |
| 10 | Other legacy forms: standalone `DEFERRABLE`, `DEFAULT -'text'`, `RETURNING t.*`, string literals as qualified names (`'t'.'c'`), `DELETE … ORDER BY` without `LIMIT`, a trailing empty module argument, fuzz inputs | parse.y legacy; not supported |
| 5 | Empty argument or type lists: `count(DISTINCT)`, `count(ORDER BY a)`, `CAST(x AS )` | parse.y legacy; not supported |
| 5 | Invalid join types (`LEFT RIGHT JOIN`, `NATURAL LEFT FULL JOIN`, `INNER BOGUS CROSS JOIN`): parse.y accepts `JOIN_KW nm nm JOIN` and rejects them later ("unknown join type") | Parser is right |
| 4 | SQLite reports a missing table before reaching the syntax error (`SELECT * FROM;` in a trigger body, `#N` parameters, oversized hex literals) | Parser is right |
| 3 | `over`/`window` used as names right after `OVER`/`WINDOW` (`sum(x) over over`) | Contextual-keyword edge cases |
| 2 | `BEGIN/ROLLBACK TRANSACTION 'name'` | parse.y legacy; not supported |
| 1 | Garbage after a statement that SQLite reports differently (`… %WO%`) | Parser is right |

No remaining disagreement is an unexplained parser bug. The two known approximations (keyword
fallback in frame bounds, and `over`/`window` as names next to the keywords) are documented above.
