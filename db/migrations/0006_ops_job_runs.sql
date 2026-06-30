-- 0006 — ops job-run history.
--
-- Machine-readable run summaries for the scraper and frontend deploys so
-- operations does not depend on reading logs by hand. NLP pipeline runs are
-- recorded in nlp.ingest_runs (migration 0005); this schema covers the other
-- two job types. Powers the freshness alerts in k8s/logging/alerts/.

BEGIN;

CREATE SCHEMA IF NOT EXISTS ops;

CREATE TABLE IF NOT EXISTS ops.scraper_runs (
    id              BIGSERIAL PRIMARY KEY,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at     TIMESTAMPTZ,
    status          TEXT NOT NULL DEFAULT 'running'
                        CHECK (status IN ('running', 'success', 'failed')),
    ran_bills       BOOLEAN,
    ran_votes       BOOLEAN,
    processed_count INTEGER,
    changed_count   INTEGER,
    skipped_count   INTEGER,
    failed_count    INTEGER,
    duration_ms     BIGINT,
    git_sha         TEXT,
    error           TEXT
);

CREATE INDEX IF NOT EXISTS scraper_runs_started_at_idx ON ops.scraper_runs (started_at DESC);

CREATE TABLE IF NOT EXISTS ops.frontend_deploys (
    id           BIGSERIAL PRIMARY KEY,
    deployed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    commit_sha   TEXT,
    environment  TEXT,
    trigger      TEXT
);

CREATE INDEX IF NOT EXISTS frontend_deploys_deployed_at_idx ON ops.frontend_deploys (deployed_at DESC);

COMMIT;
