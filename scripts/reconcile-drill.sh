#!/usr/bin/env bash
# V2 reconciler drill (docs/V2-REFACTOR-PLAN.md Phase 3): proves the
# declarative reconcile on an ephemeral DB with fake embeddings, exercising
# every path deliberately:
#
#   1. cold start     -> plan adds everything, executes, verifies
#   2. same corpus    -> ZERO plan (hash fidelity)
#   3. add/update/del -> delete-threshold ABORTS first, then applies with the
#                        threshold raised; unchanged chunks REUSE embeddings
#   4. kill mid-run   -> invariants stay green; next run supersedes the
#                        abandoned audit row and converges
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"

CONTAINER="csearch-reconcile-drill-$$"
TMP="$(mktemp -d)"
cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT

docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=csearch \
  -p 55436:5432 pgvector/pgvector:pg18 >/dev/null
DSN="postgresql://postgres:postgres@localhost:55436/csearch"
for i in $(seq 1 60); do psql "$DSN" -tAc "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done
python3 db/migrate.py --dsn "$DSN" >/dev/null
echo "ephemeral DB migrated (chain incl. v2 stage)"

# --- fixtures ---------------------------------------------------------------
python3 - "$TMP" <<'PY'
import json, sys
tmp = sys.argv[1]
def chunk(bill, idx, text, doc="d1"):
    return {
        "bill_id": bill, "canonical_bill_id": bill, "congress": 119,
        "type": bill.rstrip("0123456789-19").replace("-", "") or "hr",
        "number": "".join(ch for ch in bill.split("-")[0] if ch.isdigit()),
        "chunk_index": idx, "original_chunk_index": idx,
        "text": text, "tokens": max(1, len(text.split())),
        "short_title": f"Fixture {bill}", "status": "test", "version": "ih",
        "section_enum": f"S{idx}", "section_header": f"Section {idx}",
        "document_text_hash": doc, "section_text_hash": f"{doc}-s{idx}",
        "document_text_hashes": [doc],
    }
v1 = [chunk("hr1-119", 0, "solar tax credits for homeowners"),
      chunk("hr1-119", 1, "wind farm permitting on federal land"),
      chunk("s2-119", 0, "rural broadband grant program"),
      chunk("s2-119", 1, "spectrum auction proceeds")]
# v2: hr1 chunk 1 modified (doc hash changes), s2 DELETED, s3 added
v2 = [chunk("hr1-119", 0, "solar tax credits for homeowners"),
      chunk("hr1-119", 1, "wind farm permitting on federal land AMENDED", doc="d2"),
      chunk("s3-119", 0, "cybersecurity standards for utilities")]
# v3: hr1 chunk 0 modified + s4 added (for the crash drill: 2 bills to touch)
v3 = [chunk("hr1-119", 0, "solar tax credits EXPANDED", doc="d3"),
      chunk("hr1-119", 1, "wind farm permitting on federal land AMENDED", doc="d2"),
      chunk("s3-119", 0, "cybersecurity standards for utilities"),
      chunk("s4-119", 0, "grid resilience block grants")]
for name, data in [("v1", v1), ("v2", v2), ("v3", v3)]:
    with open(f"{tmp}/{name}.json", "w") as f: json.dump(data, f)
print("fixtures written")
PY

if python3 -c "import psycopg2" >/dev/null 2>&1; then
  R() { python3 backend/nlp/project-tarp/reconciler.py --dsn "$DSN" --backend fake "$@"; }
else
  R() { uv run backend/nlp/project-tarp/reconciler.py --dsn "$DSN" --backend fake "$@"; }
fi
COUNT() { psql "$DSN" -tAc "SELECT count(*) FROM nlp_stage.chunks"; }

echo ""
echo "--- 1. cold start: everything is an add ---"
R --desired-json "$TMP/v1.json"
[ "$(COUNT)" = "4" ] || { echo "FAIL: expected 4 chunks"; exit 1; }

echo ""
echo "--- 2. identical corpus: zero plan ---"
out=$(R --desired-json "$TMP/v1.json" 2>&1); echo "$out" | tail -2
echo "$out" | grep -q "replace 0 bill(s), delete 0 bill(s), embed 0 new" \
  || { echo "FAIL: expected a zero plan"; exit 1; }

echo ""
echo "--- 3a. destructive plan must ABORT (deletes 1/2 bills > 20%) ---"
set +e
abort_out=$(R --desired-json "$TMP/v2.json" 2>&1); abort_rc=$?
set -e
echo "$abort_out" | tail -1
if [ "$abort_rc" != "0" ] && echo "$abort_out" | grep -q "refusing"; then
  echo "abort confirmed (rc=$abort_rc)"
else
  echo "FAIL: delete threshold did not trip cleanly (rc=$abort_rc)"; exit 1
fi

echo ""
echo "--- 3b. same plan applies with the threshold raised ---"
R --desired-json "$TMP/v2.json" --max-delete-frac 0.6
psql "$DSN" -v ON_ERROR_STOP=1 -q <<'SQL'
DO $$
DECLARE n int; reused int;
BEGIN
    SELECT count(*) INTO n FROM nlp_stage.chunks;
    IF n <> 3 THEN RAISE EXCEPTION 'expected 3 chunks after v2, got %', n; END IF;
    SELECT count(*) INTO n FROM nlp_stage.chunks WHERE bill_uid = 's2-119';
    IF n <> 0 THEN RAISE EXCEPTION 's2-119 should be deleted'; END IF;
    -- the unchanged hr1 chunk must have REUSED its embedding (executed_update)
    SELECT executed_update INTO reused FROM ops.reconcile_runs
     WHERE status = 'success' ORDER BY started_at DESC LIMIT 1;
    IF reused < 1 THEN RAISE EXCEPTION 'expected embedding reuse, executed_update=%', reused; END IF;
    RAISE NOTICE 'v2 state verified (reuse=%)', reused;
END $$;
SQL

echo ""
echo "--- 4. crash mid-run, then converge ---"
set +e
RECONCILE_CRASH_AFTER_BILLS=1 R --desired-json "$TMP/v3.json"
rc=$?
set -e
[ "$rc" != "0" ] || { echo "FAIL: crash drill exited 0"; exit 1; }
red=$(psql "$DSN" -tAc "SELECT count(*) FROM ops.check_invariants() WHERE NOT ok")
[ "$red" = "0" ] || { echo "FAIL: $red red invariant(s) after crash"; exit 1; }
echo "post-crash: invariants green, audit row left 'running' as expected:"
psql "$DSN" -tAc "SELECT run_id||' '||status FROM ops.reconcile_runs ORDER BY started_at DESC LIMIT 1"
echo "recovery run:"
R --desired-json "$TMP/v3.json"
psql "$DSN" -v ON_ERROR_STOP=1 -q <<'SQL'
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM nlp_stage.chunks;
    IF n <> 4 THEN RAISE EXCEPTION 'expected 4 chunks after v3, got %', n; END IF;
    SELECT count(*) INTO n FROM ops.reconcile_runs WHERE status = 'running';
    IF n <> 0 THEN RAISE EXCEPTION '% abandoned running row(s) not superseded', n; END IF;
    SELECT count(*) INTO n FROM ops.check_invariants() WHERE NOT ok;
    IF n <> 0 THEN RAISE EXCEPTION '% red invariant(s)', n; END IF;
    RAISE NOTICE 'crash recovery verified';
END $$;
SQL
echo ""
echo "--- audit trail ---"
psql "$DSN" -c "SELECT run_id, status, planned_add, executed_add, executed_update, executed_delete, error FROM ops.reconcile_runs ORDER BY started_at"
echo "Reconcile drill passed."
