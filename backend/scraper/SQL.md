# SQL Features Reference

This document covers every PostgreSQL feature used in the scraper's `db.rs` module. Each section explains what the feature does, why we use it, and shows the actual query pattern from the codebase.

---

## Table of Contents

1. [Parameterized Queries ($1, $2, ...)](#parameterized-queries)
2. [UPSERT (INSERT ... ON CONFLICT)](#upsert)
3. [Transactions (BEGIN / COMMIT / ROLLBACK)](#transactions)
4. [Common Table Expressions (CTEs)](#common-table-expressions)
5. [UNNEST — Expanding Arrays into Rows](#unnest)
6. [RETURNING — Getting Back Inserted Data](#returning)
7. [Array Types ($1::text[], $2::date[])](#array-type-casts)
8. [DELETE in a CTE](#delete-in-a-cte)
9. [UPDATE in a CTE](#update-in-a-cte)
10. [UPDATE ... FROM (Joining an Update)](#update-from)
11. [CREATE TABLE IF NOT EXISTS](#create-table-if-not-exists)
12. [CREATE INDEX IF NOT EXISTS](#create-index-if-not-exists)
13. [PL/pgSQL DO Blocks](#plpgsql-do-blocks)
14. [DISTINCT ON](#distinct-on)
15. [COALESCE and NULLIF](#coalesce-and-nullif)
16. [ORDER BY Boolean Expression](#order-by-boolean-expression)
17. [Connection Pooling](#connection-pooling)
18. [Performance: Before & After](#performance-before--after)

---

## Parameterized Queries

**What:** Using `$1`, `$2`, etc. as placeholders for values instead of string interpolation.

**Why:** Prevents SQL injection. The database engine receives the query structure and values separately, so user-controlled data can never be interpreted as SQL.

```sql
INSERT INTO votes (voteid, bill_type, congress)
VALUES ($1, $2, $3)
```

In Rust (sqlx), values are bound with `.bind()`:
```rust
sqlx::query("INSERT INTO votes (voteid) VALUES ($1)")
    .bind(&vote.voteid)   // binds to $1
    .execute(&mut **tx)
    .await?;
```

**Equivalent in other languages:**
- Python (asyncpg): `await conn.execute("... VALUES ($1)", vote_id)`
- Node (pg): `await pool.query("... VALUES ($1)", [voteId])`

---

## UPSERT

**What:** `INSERT ... ON CONFLICT ... DO UPDATE SET` — inserts a row, or updates it if a row with the same unique key already exists.

**Why:** We re-process data files that may have been seen before. Upsert lets us idempotently write data without checking first whether the row exists.

### Pattern 1: Upsert by primary key

```sql
INSERT INTO votes (
    voteid, bill_type, bill_number, congress, ...
) VALUES ($1, $2, $3, $4, ...)
ON CONFLICT (voteid) DO UPDATE SET
    bill_type   = excluded.bill_type,
    bill_number = excluded.bill_number,
    congress    = excluded.congress
```

`excluded` is a special table alias that refers to the row that *would have been* inserted. So `excluded.bill_type` is the new value we're trying to insert.

### Pattern 2: Upsert with composite key

```sql
INSERT INTO bills (...) VALUES (...)
ON CONFLICT (billtype, billnumber, congress) DO UPDATE SET
    summary_text = excluded.summary_text,
    ...
```

### Pattern 3: Skip duplicates silently

```sql
INSERT INTO vote_members (voteid, bioguide_id, ...)
VALUES ($1, $2, ...)
ON CONFLICT ON CONSTRAINT vote_members_pkey DO NOTHING
```

`DO NOTHING` means "if a conflict occurs, silently skip this row." Used when duplicate entries are harmless.

---

## Transactions

**What:** A group of SQL statements that execute atomically — either ALL succeed, or NONE take effect.

**Why:** When inserting a bill, we write to 5+ tables (bills, bill_actions, bill_cosponsors, bill_committees, bill_subjects). If one fails midway, we don't want a half-written bill in the database.

```rust
let mut tx = pool.begin().await?;     // BEGIN

db::insert_bill(&mut tx, bill).await?;
db::replace_bill_actions(&mut tx, ...).await?;
// ... more operations ...

tx.commit().await?;                    // COMMIT
// If any `?` triggers an early return, `tx` is dropped,
// which automatically issues ROLLBACK.
```

**Key behavior:**
- `pool.begin()` issues `BEGIN` and returns a `Transaction` object
- All queries on `tx` run within that transaction
- `tx.commit()` issues `COMMIT`
- If `tx` is dropped without commit (e.g., due to an error), PostgreSQL rolls back

---

## Common Table Expressions

**What:** `WITH name AS (...)` — named sub-queries that execute as part of a single statement. Multiple CTEs can be chained.

**Why:** We use CTEs to combine multiple operations (DELETE + INSERT + UPDATE) into a single network round-trip. Previously each was a separate query.

```sql
WITH clear_latest AS (
    UPDATE bills SET latest_action_id = NULL
    WHERE billtype = $1 AND billnumber = $2 AND congress = $3
),
deleted AS (
    DELETE FROM bill_actions
    WHERE billtype = $1 AND billnumber = $2 AND congress = $3
),
inserted AS (
    INSERT INTO bill_actions (...)
    SELECT $1, $2, $3, * FROM UNNEST(...)
    RETURNING id, acted_at, action_text
),
best AS (
    SELECT id FROM inserted
    WHERE acted_at = $9
    ORDER BY (action_text = $10) DESC
    LIMIT 1
)
UPDATE bills
SET latest_action_id = best.id, latest_action_date = $9
FROM best
WHERE billtype = $1 AND billnumber = $2 AND congress = $3
```

**Execution order:** PostgreSQL executes all CTEs and the final statement as a single atomic operation. The CTEs logically execute in order — each can reference results from previous CTEs.

**Performance impact:** This single statement replaces what was previously ~25 sequential round-trips (1 update + 1 delete + N inserts + 1 update) for a bill with 20 actions.

---

## UNNEST

**What:** `UNNEST(array)` expands a PostgreSQL array into a set of rows. When given multiple arrays, it expands them in parallel (like `zip()` in Python).

**Why:** Batch inserts. Instead of N individual INSERT statements, we pass N values as arrays and let UNNEST expand them into N rows for a single INSERT.

```sql
INSERT INTO bill_actions
    (billtype, billnumber, congress, acted_at, action_text, action_type, action_code, source_system_code)
SELECT $1, $2, $3, *
FROM UNNEST($4::date[], $5::text[], $6::text[], $7::text[], $8::text[])
```

**How it works:**

Given these arrays:
```
$4 = ARRAY['2024-01-10', '2024-01-12']   -- dates
$5 = ARRAY['Introduced', 'Passed House']  -- texts
```

`UNNEST($4, $5)` produces:

| column1    | column2       |
|------------|---------------|
| 2024-01-10 | Introduced    |
| 2024-01-12 | Passed House  |

The `SELECT $1, $2, $3, *` prepends the constant bill identifiers to each row.

**In Rust (sqlx):** `Vec<T>` is automatically bound as a PostgreSQL array:
```rust
let dates: Vec<chrono::NaiveDate> = actions.iter().map(|a| a.acted_at).collect();
let texts: Vec<Option<String>> = actions.iter().map(|a| a.action_text.clone()).collect();
sqlx::query("... FROM UNNEST($1::date[], $2::text[])")
    .bind(&dates)
    .bind(&texts)
    ...
```

---

## RETURNING

**What:** `RETURNING column1, column2, ...` — returns data from rows affected by INSERT, UPDATE, or DELETE.

**Why:** After inserting bill actions, we need the auto-generated `id` of the "latest" action to link it back to the bill. `RETURNING` gets these IDs without a separate SELECT.

```sql
INSERT INTO bill_actions (...)
SELECT ...
FROM UNNEST(...)
RETURNING id, acted_at, action_text
```

This returns one row per inserted action, each with its generated `id`. A subsequent CTE then finds the best match:

```sql
best AS (
    SELECT id FROM inserted
    WHERE acted_at = $9
    ORDER BY (action_text = $10) DESC
    LIMIT 1
)
```

---

## Array Type Casts

**What:** `$1::text[]`, `$2::date[]`, `$3::bool[]` — explicit type casts telling PostgreSQL what type the parameter arrays contain.

**Why:** When using UNNEST with parameterized queries, PostgreSQL needs to know the array element type at parse time. Without the cast, it sees an untyped parameter and can't plan the query.

```sql
FROM UNNEST($4::date[], $5::text[], $6::text[], $7::text[], $8::text[])
```

Common type casts used:
- `::text[]` — array of strings
- `::date[]` — array of dates
- `::bool[]` — array of booleans
- `::int[]` — array of integers (not used here but common)

---

## DELETE in a CTE

**What:** A `DELETE` statement inside a `WITH` clause, so it runs as part of a larger statement.

**Why:** We need to delete old rows before inserting new ones (to handle removals). Doing it in a CTE means one round-trip instead of two.

```sql
WITH deleted AS (
    DELETE FROM bill_cosponsors
    WHERE billtype = $1 AND billnumber = $2 AND congress = $3
)
INSERT INTO bill_cosponsors (...)
SELECT ...
FROM UNNEST(...)
```

**Important:** The DELETE and INSERT are part of the same statement snapshot. The INSERT doesn't see the deleted rows — PostgreSQL handles the ordering correctly.

---

## UPDATE in a CTE

**What:** An `UPDATE` statement inside a `WITH` clause.

**Why:** We need to NULL out the `latest_action_id` foreign key before deleting actions (to avoid FK constraint violations), and later set it to the new value. Both are done in the same CTE chain.

```sql
WITH clear_latest AS (
    UPDATE bills
    SET latest_action_id = NULL
    WHERE billtype = $1 AND billnumber = $2 AND congress = $3
),
...
```

---

## UPDATE ... FROM

**What:** `UPDATE table SET ... FROM other_table WHERE ...` — updates rows by joining with another table or CTE.

**Why:** After inserting actions and finding the "best" one in a CTE, we need to set the bill's `latest_action_id` to that action's ID. `UPDATE ... FROM` joins the `bills` table with the `best` CTE.

```sql
UPDATE bills
SET latest_action_id   = best.id,
    latest_action_date = $9
FROM best
WHERE billtype = $1 AND billnumber = $2 AND congress = $3
```

This is PostgreSQL-specific syntax. In standard SQL you'd use a correlated subquery instead.

---

## CREATE TABLE IF NOT EXISTS

**What:** Creates a table only if it doesn't already exist. Idempotent.

**Why:** Used in the schema compatibility migration that runs on startup. Safe to run repeatedly.

```sql
CREATE TABLE IF NOT EXISTS committees (
    committee_code text PRIMARY KEY,
    committee_name text,
    chamber        text
);
```

---

## CREATE INDEX IF NOT EXISTS

**What:** Creates an index only if it doesn't already exist.

**Why:** Same as above — idempotent startup migration.

```sql
CREATE INDEX IF NOT EXISTS committees_chamber_idx
    ON committees (chamber);
```

---

## PL/pgSQL DO Blocks

**What:** `DO $$ ... END $$` — anonymous PL/pgSQL code blocks that execute procedural logic directly.

**Why:** Our schema migration needs conditional logic: "IF the old column exists, migrate data." Plain SQL can't do conditionals, so we use PL/pgSQL.

```sql
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'bill_committees'
          AND column_name = 'committee_name'
    ) THEN
        INSERT INTO committees (...)
        SELECT DISTINCT ON (committee_code) ...
        FROM bill_committees
        ON CONFLICT (committee_code) DO UPDATE SET ...;
    END IF;
END $$;
```

**Key features used:**
- `IF EXISTS (subquery) THEN ... END IF` — conditional execution
- `information_schema.columns` — PostgreSQL's catalog of table columns
- `$$` delimiters — avoids escaping single quotes inside the block

---

## DISTINCT ON

**What:** `DISTINCT ON (column)` — PostgreSQL-specific extension that returns one row per unique value of `column`, keeping the first row according to `ORDER BY`.

**Why:** When migrating committee data, a committee code might appear multiple times. We want one row per code, preferring rows with non-null names.

```sql
SELECT DISTINCT ON (committee_code)
    committee_code,
    NULLIF(committee_name, ''),
    NULLIF(chamber, '')
FROM bill_committees
WHERE committee_code IS NOT NULL
ORDER BY committee_code, committee_name NULLS LAST, chamber NULLS LAST
```

`ORDER BY ... NULLS LAST` ensures rows with non-null values are preferred.

---

## COALESCE and NULLIF

### COALESCE

**What:** `COALESCE(a, b, c)` — returns the first non-NULL argument.

**Why:** When upserting committees, we want to keep the existing name if the new one is NULL.

```sql
ON CONFLICT (committee_code) DO UPDATE SET
    committee_name = COALESCE(excluded.committee_name, committees.committee_name),
    chamber = COALESCE(excluded.chamber, committees.chamber)
```

This means: "use the new name if provided, otherwise keep the old one."

### NULLIF

**What:** `NULLIF(value, '')` — returns NULL if `value` equals the second argument, otherwise returns `value`.

**Why:** Converts empty strings to NULL for cleaner data storage.

```sql
NULLIF(committee_name, '')
```

---

## ORDER BY Boolean Expression

**What:** `ORDER BY (expression) DESC` where the expression evaluates to a boolean.

**Why:** In PostgreSQL, `true > false`. So `ORDER BY (action_text = $10) DESC` sorts rows where the text matches first.

```sql
SELECT id FROM inserted
WHERE acted_at = $9
ORDER BY (action_text = $10) DESC
LIMIT 1
```

This finds the action on the latest date, preferring the one whose text matches. It's a concise alternative to a `CASE WHEN` expression.

---

## Connection Pooling

**What:** A pool of reusable database connections managed by sqlx.

**Why:** Opening a new TCP connection for every query is expensive (~50-100ms). A pool keeps connections open and reuses them across requests.

```rust
let pool = PgPoolOptions::new()
    .max_connections(4)
    .connect(&dsn)
    .await?;
```

**Configuration:** Max 4 connections, matching the `DB_WRITE_CONCURRENCY` semaphore that limits parallel writes. This means every write task is guaranteed a connection without waiting.

---

## Performance: Before & After

### Before (per bill, ~40 round-trips)

| Operation | Round-trips |
|---|---|
| `INSERT bill` | 1 |
| `UPDATE clear latest_action_id` | 1 |
| `DELETE bill_actions` | 1 |
| `INSERT bill_action` x N | N (e.g., 20) |
| `UPDATE latest_action_id` | 1 |
| `DELETE bill_cosponsors` | 1 |
| `INSERT bill_cosponsor` x M | M (e.g., 5) |
| `INSERT committee` x K | K (e.g., 3) |
| `DELETE bill_committees` | 1 |
| `INSERT bill_committee` x K | K (e.g., 3) |
| `DELETE bill_subjects` | 1 |
| `INSERT bill_subject` x J | J (e.g., 4) |
| **Total** | **~42** |

### After (per bill, 5 round-trips)

| Operation | Round-trips |
|---|---|
| `INSERT bill` (upsert) | 1 |
| `replace_bill_actions` (CTE: clear + delete + UNNEST insert + update) | 1 |
| `replace_bill_cosponsors` (CTE: delete + UNNEST insert) | 1 |
| `replace_bill_committees` (CTE: upsert committees + delete + UNNEST insert) | 1 |
| `replace_bill_subjects` (CTE: delete + UNNEST insert) | 1 |
| **Total** | **5** |

**~8x fewer round-trips per bill.** For votes, the improvement is from N+2 to 2 (upsert vote + replace members).
