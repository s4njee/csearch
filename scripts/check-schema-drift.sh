#!/usr/bin/env bash
# Fail if the public-schema bootstrap copies drift from each other or from the
# authoritative migration 0001. See db/README.md.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

fail=0

bootstraps=(
  "backend/scraper/schema.sql"
  "k8s/netcup-db/001-schema.sql"
  "k8s/freya-db/001-schema.sql"
)

# 1. All live bootstrap copies must be byte-identical.
reference="${bootstraps[0]}"
for f in "${bootstraps[@]:1}"; do
  if ! diff -q "$reference" "$f" >/dev/null; then
    fail=1
    printf '\nBootstrap schema drift: %s differs from %s\n' "$f" "$reference" >&2
    diff "$reference" "$f" | head -40 >&2
  fi
done

# 2. Migration 0001 must match the bootstrap below its provenance header. The
#    header ends at the first "-- Fresh database bootstrap" marker line.
migration="db/migrations/0001_initial_public_schema.sql"
marker_line="$(grep -n -- '-- Fresh database bootstrap' "$migration" | head -1 | cut -d: -f1 || true)"
if [[ -z "${marker_line}" ]]; then
  fail=1
  printf '\n%s is missing its bootstrap marker comment.\n' "$migration" >&2
else
  if ! diff -q <(tail -n +"${marker_line}" "$migration") "$reference" >/dev/null; then
    fail=1
    printf '\nMigration 0001 has drifted from the bootstrap schema (%s).\n' "$reference" >&2
    printf 'Regenerate by copying %s into the body of %s.\n' "$reference" "$migration" >&2
    diff "$reference" <(tail -n +"${marker_line}" "$migration") | head -40 >&2
  fi
fi

if (( fail )); then
  printf '\nSchema drift check failed.\n' >&2
  exit 1
fi

printf 'Schema drift check passed.\n'
