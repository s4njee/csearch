# PostgreSQL Research Topics

This note tracks future Postgres work that could make CSearch more robust, easier to operate, and more feature complete without pushing as much logic into the scraper or API layers.

Current baseline in this repo already includes:

- Declarative partitioning for `bills` by `congress`
- Generated `tsvector` columns for bill and vote search
- GIN indexes for full-text search
- Trigram support via `pg_trgm`
- Foreign keys and cascading deletes across core bill tables

## Highest-value research areas

### 1. Automate partition lifecycle for new congresses

`bills` already uses list partitioning, but new congresses currently fall into `bills_default` until a real partition is created.

- Why it matters: relying on the default partition too long can reduce partition-pruning benefits and make future maintenance noisier.
- Research goal: define a repeatable migration or bootstrap routine that creates the next congress partition before ingest begins.
- Prototype ideas:
  - add a small SQL migration that creates `bills_<next_congress>` during deploy
  - add a DB-side function that safely creates the next partition if it does not exist
  - document an index template so every new partition stays consistent

### 2. Partition `votes` natively as the dataset grows

`votes` and `vote_members` are currently unpartitioned even though they are naturally grouped by congress and date.

- Why it matters: large historical vote scans, deletes, and reingest operations will get more expensive over time.
- Research goal: compare partitioning `votes` by `congress` versus `votedate`, then align `vote_members` maintenance with that design.
- Prototype ideas:
  - benchmark current `GET /votes` and search queries against a partitioned copy
  - test partition pruning for recent-only and congress-specific queries
  - measure ingest cost for upserts into partitioned vote tables

### 3. Materialized views for expensive browse and analytics endpoints

Several API and explore queries are good candidates for precomputed views.

- Why it matters: endpoints like latest activity, subject summaries, sponsor rankings, and committee analytics are read-heavy and mostly derived from stable historical data.
- Research goal: identify which `explore.sql` queries and `/latest/:billtype` patterns benefit from materialized views.
- Prototype ideas:
  - create a materialized view for recent bills ordered by `latest_action_date`
  - create refreshable summary views for sponsor, subject, and committee rollups
  - test `REFRESH MATERIALIZED VIEW CONCURRENTLY` with the unique indexes it requires

### 4. Tighten data integrity with native domains, checks, and reference tables

The schema already has solid primary/foreign key coverage, but several columns still accept broad free-form values.

- Why it matters: ingest is easier to trust when chamber, party, status, and vote-position values are validated at write time.
- Research goal: move repeated string categories into stricter database rules.
- Prototype ideas:
  - add `CHECK` constraints for congress ranges and known chamber values
  - evaluate domains or enums for vote position, chamber, and party fields
  - normalize more descriptive fields into small reference tables where values are stable

### 5. Add audit/history tables with triggers

The current schema stores the latest normalized state, but it does not keep a built-in record of what changed over time during reingest.

- Why it matters: auditability helps debug parser changes, upstream source changes, and accidental regressions.
- Research goal: capture row-level history for core entities without rewriting the ingest pipeline.
- Prototype ideas:
  - add append-only history tables for `bills`, `votes`, and key child tables
  - use triggers to store old/new row snapshots plus `changed_at`
  - record `first_seen_at` and `last_seen_at` on primary tables for longitudinal analysis

### 6. Improve search quality with more native text search features

CSearch already has a strong base with generated `tsvector` columns, but ranking and result presentation can go further.

- Why it matters: better relevance and better snippets improve search UX without bringing in a separate search engine.
- Research goal: improve search recall, ranking, and explainability inside Postgres first.
- Prototype ideas:
  - compare `websearch_to_tsquery` with phrase and prefix search variants
  - add `ts_headline(...)` snippets for result previews
  - evaluate a custom text search configuration for congressional vocabulary
  - optionally test core extensions like `unaccent` only if the deployment image supports them cleanly

### 7. Use covering, partial, and expression indexes for API hot paths

There are already several helpful indexes, but the API now has enough clear access patterns to tune more aggressively.

- Why it matters: browse endpoints, recent views, and constrained searches can often avoid heap fetches with the right index shape.
- Research goal: tune indexes around actual query plans rather than only schema intuition.
- Prototype ideas:
  - use `INCLUDE` indexes for the exact columns returned by recent-bills style endpoints
  - add partial indexes for "recent congresses" or "recent activity" if those dominate traffic
  - benchmark expression indexes for common sort/filter combinations

### 8. Add extended statistics for correlated columns

Some important filters are naturally correlated, especially `billtype + congress`, `chamber + congress`, and status/date combinations.

- Why it matters: the planner can choose weaker plans when it underestimates correlated predicates.
- Research goal: use `CREATE STATISTICS` where selectivity is hard for the planner to infer from single-column stats.
- Prototype ideas:
  - test multivariate statistics on `bills (billtype, congress, bill_status)`
  - test multivariate statistics on `votes (congress, chamber, votedate)`
  - compare `EXPLAIN ANALYZE` plans before and after `ANALYZE`

### 9. Build native backup and recovery around WAL archiving

The project depends heavily on scraped historical data and normalized relational state, so recovery guarantees matter.

- Why it matters: robust operations need point-in-time recovery, not just ad hoc dumps.
- Research goal: design a Postgres-native backup story that works with the existing Kubernetes deployment.
- Prototype ideas:
  - enable WAL archiving to object storage
  - define restore runbooks for point-in-time recovery
  - test physical replica or standby options for faster recovery and safer upgrades

### 10. Store raw source payloads alongside normalized rows

The scraper already fetches XML and JSON files on disk, but keeping selected raw payloads or parsed fragments in Postgres may simplify reparsing and provenance work.

- Why it matters: source retention inside the database can support traceability, reparsing experiments, and future UI features that show source context.
- Research goal: decide whether a lightweight `jsonb` archive layer is worth the storage cost.
- Prototype ideas:
  - add a source table keyed by bill or vote identifiers plus scrape timestamp
  - keep normalized tables lean and archive only provenance-critical fields
  - test whether raw payload access speeds up debugging and schema migrations

### 11. Use `LISTEN`/`NOTIFY` or an outbox table for downstream events

Today the API mostly reads directly from Postgres, but future cache invalidation, analytics refreshes, or search warmups may benefit from DB-originated events.

- Why it matters: native event hooks can reduce lag between ingest completion and downstream refresh work.
- Research goal: evaluate whether simple Postgres-native notifications are enough before introducing external event infrastructure.
- Prototype ideas:
  - notify on successful bill/vote upsert batches
  - pair notifications with an outbox table for durable consumers
  - use this to drive materialized view refreshes or cache invalidation

## Lower-priority but useful future topics

### 12. Row-level security for future internal tooling

Not needed for the current public read-only API, but worth revisiting if the project adds internal dashboards, editorial tools, or operator write access.

- Research goal: evaluate RLS only if direct database access expands beyond the scraper and trusted API services.

### 13. Generated reporting tables for time-series analytics

If the explore surface grows, summary tables maintained by SQL alone may be simpler than heavier application-level analytics jobs.

- Research goal: compare materialized views versus trigger-maintained rollup tables for sponsor, committee, and vote trend analytics.

## Suggested rollout order

If this work is tackled incrementally, a practical order would be:

1. Partition lifecycle automation for `bills`
2. Backup/WAL archiving and recovery runbooks
3. Materialized views for hot read paths
4. Constraint tightening and integrity improvements
5. Vote partitioning benchmarks
6. Search relevance improvements
7. Index and statistics tuning
8. Audit/history tables
9. Raw payload archival
10. Native eventing with `LISTEN`/`NOTIFY`

## Success criteria for any experiment

Each research item should ideally answer the same questions:

- Does it lower query latency or operational risk in a measurable way?
- Does it keep the schema understandable for future maintenance?
- Does it avoid unnecessary complexity in the Go scraper and Node API?
- Does it fit the current Kubernetes deployment model without fragile one-off ops work?
