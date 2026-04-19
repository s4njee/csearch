-- Freya-only audit/history support for normalized congressional data.
--
-- This migration is intentionally idempotent so it can be run against an
-- existing Freya database and also embedded in fresh bootstrap SQL.

SET ROLE csearch;

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.row_history (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_schema text NOT NULL,
    table_name   text NOT NULL,
    operation    text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    row_pk       jsonb NOT NULL,
    old_row      jsonb,
    new_row      jsonb,
    changed_at   timestamptz NOT NULL DEFAULT now(),
    changed_by   text NOT NULL DEFAULT current_user
);

CREATE INDEX IF NOT EXISTS row_history_table_changed_at_idx
    ON audit.row_history (table_schema, table_name, changed_at DESC);

CREATE INDEX IF NOT EXISTS row_history_row_pk_idx
    ON audit.row_history USING GIN (row_pk);

CREATE OR REPLACE FUNCTION audit.prevent_row_history_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'audit.row_history is append-only';
END;
$$;

DROP TRIGGER IF EXISTS row_history_append_only_trigger ON audit.row_history;
CREATE TRIGGER row_history_append_only_trigger
    BEFORE UPDATE OR DELETE ON audit.row_history
    FOR EACH ROW
    EXECUTE FUNCTION audit.prevent_row_history_mutation();

ALTER TABLE bills
    ADD COLUMN IF NOT EXISTS first_seen_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

UPDATE bills
SET first_seen_at = COALESCE(first_seen_at, now()),
    last_seen_at = COALESCE(last_seen_at, first_seen_at, now())
WHERE first_seen_at IS NULL
   OR last_seen_at IS NULL;

ALTER TABLE bills
    ALTER COLUMN first_seen_at SET DEFAULT now(),
    ALTER COLUMN last_seen_at SET DEFAULT now(),
    ALTER COLUMN first_seen_at SET NOT NULL,
    ALTER COLUMN last_seen_at SET NOT NULL;

ALTER TABLE votes
    ADD COLUMN IF NOT EXISTS first_seen_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

UPDATE votes
SET first_seen_at = COALESCE(first_seen_at, now()),
    last_seen_at = COALESCE(last_seen_at, first_seen_at, now())
WHERE first_seen_at IS NULL
   OR last_seen_at IS NULL;

ALTER TABLE votes
    ALTER COLUMN first_seen_at SET DEFAULT now(),
    ALTER COLUMN last_seen_at SET DEFAULT now(),
    ALTER COLUMN first_seen_at SET NOT NULL,
    ALTER COLUMN last_seen_at SET NOT NULL;

CREATE OR REPLACE FUNCTION audit.touch_seen_timestamps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.first_seen_at = COALESCE(NEW.first_seen_at, now());
        NEW.last_seen_at = COALESCE(NEW.last_seen_at, NEW.first_seen_at, now());
    ELSE
        NEW.first_seen_at = COALESCE(NEW.first_seen_at, OLD.first_seen_at, now());
        NEW.last_seen_at = now();
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS bills_touch_seen_timestamps_trigger ON bills;
CREATE TRIGGER bills_touch_seen_timestamps_trigger
    BEFORE INSERT OR UPDATE ON bills
    FOR EACH ROW
    EXECUTE FUNCTION audit.touch_seen_timestamps();

DROP TRIGGER IF EXISTS votes_touch_seen_timestamps_trigger ON votes;
CREATE TRIGGER votes_touch_seen_timestamps_trigger
    BEFORE INSERT OR UPDATE ON votes
    FOR EACH ROW
    EXECUTE FUNCTION audit.touch_seen_timestamps();

CREATE OR REPLACE FUNCTION audit.capture_row_history()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    key_name text;
    row_snapshot jsonb;
    row_pk jsonb := '{}'::jsonb;
    old_snapshot jsonb;
    new_snapshot jsonb;
BEGIN
    IF TG_OP = 'DELETE' THEN
        old_snapshot := to_jsonb(OLD);
        row_snapshot := old_snapshot;
    ELSIF TG_OP = 'INSERT' THEN
        new_snapshot := to_jsonb(NEW);
        row_snapshot := new_snapshot;
    ELSE
        old_snapshot := to_jsonb(OLD);
        new_snapshot := to_jsonb(NEW);

        -- Ignore no-op upserts where only longitudinal bookkeeping changed.
        IF (old_snapshot - 'last_seen_at') = (new_snapshot - 'last_seen_at') THEN
            RETURN NEW;
        END IF;

        row_snapshot := new_snapshot;
    END IF;

    FOREACH key_name IN ARRAY TG_ARGV LOOP
        row_pk := row_pk || jsonb_build_object(key_name, row_snapshot -> key_name);
    END LOOP;

    INSERT INTO audit.row_history (
        table_schema,
        table_name,
        operation,
        row_pk,
        old_row,
        new_row
    ) VALUES (
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        TG_OP,
        row_pk,
        old_snapshot,
        new_snapshot
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS bills_audit_history_trigger ON bills;
CREATE TRIGGER bills_audit_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON bills
    FOR EACH ROW
    EXECUTE FUNCTION audit.capture_row_history('billtype', 'billnumber', 'congress');

DROP TRIGGER IF EXISTS bill_actions_audit_history_trigger ON bill_actions;
CREATE TRIGGER bill_actions_audit_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON bill_actions
    FOR EACH ROW
    EXECUTE FUNCTION audit.capture_row_history('id');

DROP TRIGGER IF EXISTS bill_cosponsors_audit_history_trigger ON bill_cosponsors;
CREATE TRIGGER bill_cosponsors_audit_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON bill_cosponsors
    FOR EACH ROW
    EXECUTE FUNCTION audit.capture_row_history('billtype', 'billnumber', 'congress', 'bioguide_id');

DROP TRIGGER IF EXISTS bill_committees_audit_history_trigger ON bill_committees;
CREATE TRIGGER bill_committees_audit_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON bill_committees
    FOR EACH ROW
    EXECUTE FUNCTION audit.capture_row_history('billtype', 'billnumber', 'congress', 'committee_code');

DROP TRIGGER IF EXISTS bill_subjects_audit_history_trigger ON bill_subjects;
CREATE TRIGGER bill_subjects_audit_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON bill_subjects
    FOR EACH ROW
    EXECUTE FUNCTION audit.capture_row_history('billtype', 'billnumber', 'congress', 'subject');

DROP TRIGGER IF EXISTS committees_audit_history_trigger ON committees;
CREATE TRIGGER committees_audit_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON committees
    FOR EACH ROW
    EXECUTE FUNCTION audit.capture_row_history('committee_code');

DROP TRIGGER IF EXISTS votes_audit_history_trigger ON votes;
CREATE TRIGGER votes_audit_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON votes
    FOR EACH ROW
    EXECUTE FUNCTION audit.capture_row_history('voteid');

DROP TRIGGER IF EXISTS vote_members_audit_history_trigger ON vote_members;
CREATE TRIGGER vote_members_audit_history_trigger
    AFTER INSERT OR UPDATE OR DELETE ON vote_members
    FOR EACH ROW
    EXECUTE FUNCTION audit.capture_row_history('voteid', 'bioguide_id');

RESET ROLE;
