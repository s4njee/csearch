#!/usr/bin/env python3
"""Minimal forward-only SQL migration runner for CSearch.

Applies every ``db/migrations/NNNN_*.sql`` file that has not yet been recorded
in ``public.schema_migrations``, in filename order, each via ``psql`` so the
files' own BEGIN/COMMIT and SET ROLE statements work natively. There is no
down-migration path on purpose: rolls forward only, like Flyway.

Connection: pass ``--dsn`` (a libpq URL or key=value string) or rely on the
standard ``PGHOST``/``PGPORT``/``PGUSER``/``PGPASSWORD``/``PGDATABASE`` env
vars, or ``PG_CONNECTION_STRING``.

Usage:
    python db/migrate.py --status            # show applied / pending
    python db/migrate.py                     # apply all pending
    python db/migrate.py --dry-run           # list what would be applied
    python db/migrate.py --dsn postgresql://postgres:postgres@localhost:5432/csearch
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

MIGRATIONS_DIR = Path(__file__).resolve().parent / "migrations"
TRACKING_TABLE = "public.schema_migrations"

ENSURE_TRACKING_SQL = f"""
CREATE TABLE IF NOT EXISTS {TRACKING_TABLE} (
    version    text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
);
"""


def _psql_base(dsn: str | None) -> list[str]:
    cmd = ["psql", "-v", "ON_ERROR_STOP=1", "--no-psqlrc", "--quiet"]
    if dsn:
        cmd += ["-d", dsn]
    return cmd


def _run_sql(dsn: str | None, sql: str) -> None:
    subprocess.run(_psql_base(dsn) + ["-c", sql], check=True)


def _query_scalar_list(dsn: str | None, sql: str) -> list[str]:
    result = subprocess.run(
        _psql_base(dsn) + ["-tA", "-c", sql],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def _apply_file(dsn: str | None, path: Path) -> None:
    subprocess.run(_psql_base(dsn) + ["-f", str(path)], check=True)


def migrations() -> list[Path]:
    return sorted(MIGRATIONS_DIR.glob("*.sql"))


def applied_versions(dsn: str | None) -> set[str]:
    _run_sql(dsn, ENSURE_TRACKING_SQL)
    return set(_query_scalar_list(dsn, f"SELECT version FROM {TRACKING_TABLE}"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply CSearch SQL migrations")
    parser.add_argument("--dsn", default=os.environ.get("PG_CONNECTION_STRING") or None,
                        help="libpq connection string (else uses PG* env vars)")
    parser.add_argument("--status", action="store_true", help="show applied/pending and exit")
    parser.add_argument("--dry-run", action="store_true", help="list pending migrations without applying")
    args = parser.parse_args()

    files = migrations()
    if not files:
        print("No migration files found.", file=sys.stderr)
        return 1

    applied = applied_versions(args.dsn)
    pending = [f for f in files if f.stem not in applied]

    if args.status:
        for f in files:
            mark = "applied" if f.stem in applied else "PENDING"
            print(f"  [{mark}] {f.stem}")
        return 0

    if not pending:
        print("Database is up to date — no migrations to apply.")
        return 0

    if args.dry_run:
        print("Pending migrations:")
        for f in pending:
            print(f"  {f.stem}")
        return 0

    for f in pending:
        print(f"Applying {f.stem} ...")
        _apply_file(args.dsn, f)
        # Record only after the migration's own transaction has committed.
        _run_sql(args.dsn, f"INSERT INTO {TRACKING_TABLE} (version) VALUES ('{f.stem}')")
        print(f"  done: {f.stem}")

    print(f"Applied {len(pending)} migration(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
